<#
.SYNOPSIS
  Lays down the standard folder tree, layer asmdefs, starter code, docs and rules
  into an existing Unity project. Never overwrites existing files and never writes .meta files.

.PARAMETER ProjectPath
  Root of an existing Unity project (must contain ProjectSettings/ProjectVersion.txt).
.PARAMETER Prefix
  PascalCase prefix for assembly names and root namespaces (Game -> Game.Core, Game.Gameplay, ...).
.PARAMETER Product
  Product name for Player Settings. Defaults to the project folder name.
.PARAMETER Company
  Company name for Player Settings.
.PARAMETER Orientation
  Portrait | PortraitUpsideDown | Landscape (LandscapeLeft) | LandscapeRight | AutoRotation.
.PARAMETER Skip
  Optional layers to leave out: Data, UI, Persistence (comma-separated or array).
.PARAMETER Urp
  true/false to force URP references on or off. Omit to auto-detect from Packages/manifest.json.
.PARAMETER FastPlayMode
  Opt in to fast Enter Play Mode: Apply Defaults turns Domain Reload off. Omit to keep Unity's default (reload on every Play).
.PARAMETER DryRun
  Print what would be created without writing anything.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scaffold.ps1 -ProjectPath C:\Dev\MyGame -Prefix Game -Product "My Game" -DryRun
#>
param(
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [string]$Prefix = "Game",
    [string]$Product = "",
    [string]$Company = "DefaultCompany",
    [string]$Orientation = "Portrait",
    [string[]]$Skip = @(),
    [object]$Urp = $null,
    [switch]$FastPlayMode,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$skillRoot = Split-Path -Parent $PSScriptRoot
$templates = Join-Path $skillRoot "templates"

# ---------- validate ----------
$ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path.TrimEnd('\', '/') # a trailing separator would cut the first letter off every reported path
if (-not (Test-Path -LiteralPath (Join-Path $ProjectPath "ProjectSettings/ProjectVersion.txt"))) {
    throw "Not a Unity project (ProjectSettings/ProjectVersion.txt missing): $ProjectPath"
}
if ($Prefix -cnotmatch '^[A-Z][A-Za-z0-9]*$') { throw "Prefix must be PascalCase letters/digits: $Prefix" }
if ([string]::IsNullOrWhiteSpace($Product)) { $Product = Split-Path -Leaf $ProjectPath }
foreach ($v in @($Product, $Company)) {
    if ($v -match '["\\]') { throw "Product/Company cannot contain a double quote or backslash (they go into a C# string): $v" }
}

$orientationMap = @{
    "portrait" = "Portrait"; "portraitupsidedown" = "PortraitUpsideDown";
    "landscape" = "LandscapeLeft"; "landscapeleft" = "LandscapeLeft"; "landscaperight" = "LandscapeRight";
    "auto" = "AutoRotation"; "autorotation" = "AutoRotation"
}
$key = $Orientation.ToLowerInvariant()
if (-not $orientationMap.ContainsKey($key)) { throw "Unknown orientation: $Orientation (Portrait | Landscape | AutoRotation)" }
$Orientation = $orientationMap[$key]

$Skip = @($Skip | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$skippable = @("Data", "UI", "Persistence")
foreach ($s in $Skip) {
    if ($skippable -notcontains $s) { throw "Cannot skip layer '$s'. Skippable: $($skippable -join ', ')" }
}

# ---------- packages ----------
$manifestPath = Join-Path $ProjectPath "Packages/manifest.json"
$manifest = if (Test-Path -LiteralPath $manifestPath) { [IO.File]::ReadAllText($manifestPath) } else { "" }
function Has-Package([string]$name) { return $manifest -match ('"' + [regex]::Escape($name) + '"') }

$hasInput = Has-Package "com.unity.inputsystem"
$hasUgui = Has-Package "com.unity.ugui"
$hasTests = Has-Package "com.unity.test-framework"
# -Urp arrives as a string when called through "powershell -File", so parse it instead of casting.
if ($null -eq $Urp -or "$Urp" -eq "") { $useUrp = Has-Package "com.unity.render-pipelines.universal" }
else { $useUrp = -not (@("false", "0", "no", "off", '$false') -contains "$Urp".Trim().ToLowerInvariant()) }

$warnings = New-Object System.Collections.Generic.List[string]
if (-not $hasInput) { $warnings.Add("com.unity.inputsystem not in manifest: install Input System (rules require it). Unity.InputSystem references left out.") }
if (-not $hasUgui) { $warnings.Add("com.unity.ugui not in manifest: uGUI/TextMeshPro references left out.") }
if (-not $hasTests) { $warnings.Add("com.unity.test-framework not in manifest: install Test Framework or the Core.Tests assembly will not compile.") }

$urpRefs = if ($useUrp) { @("Unity.RenderPipelines.Core.Runtime", "Unity.RenderPipelines.Universal.Runtime") } else { @() }
$inputRefs = if ($hasInput) { @("Unity.InputSystem") } else { @() }
$uiRefs = if ($hasUgui) { @("UnityEngine.UI", "Unity.TextMeshPro") } else { @() }
$tmpRefs = if ($hasUgui) { @("Unity.TextMeshPro") } else { @() }

# ---------- layer table (see templates/docs/architecture-design.md section 2) ----------
$layers = [ordered]@{
    "Core"        = @{ Dir = "Core"; Refs = @(); NoEngine = $true }
    "Data"        = @{ Dir = "Data"; Refs = @("Core") }
    "Gameplay"    = @{ Dir = "Gameplay"; Refs = @("Core", "Data") + $inputRefs + $tmpRefs + $urpRefs }
    "UI"          = @{ Dir = "UI"; Refs = @("Core") + $uiRefs + $inputRefs + $urpRefs }
    "Persistence" = @{ Dir = "Persistence"; Refs = @("Core") }
    "Bootstrap"   = @{ Dir = "Bootstrap"; Refs = @("Core", "Data", "Gameplay", "UI", "Persistence") }
    "Editor"      = @{ Dir = "Editor"; Refs = @("Core", "Data", "Gameplay", "UI", "Persistence", "Bootstrap") + $uiRefs + $urpRefs; EditorOnly = $true }
    "Core.Tests"  = @{ Dir = "Core/Tests/EditMode"; Refs = @("UnityEngine.TestRunner", "UnityEditor.TestRunner", "Core"); EditorOnly = $true; Test = $true }
}
$ourLayers = @($layers.Keys)

# Refuse to drop a new asmdef onto existing code: it would pull those scripts into the layer and can break compilation.
# A layer whose asmdef already exists (a re-run) is fine — that asmdef is skipped, not rewritten.
$occupied = @()
foreach ($name in $layers.Keys) {
    if ($Skip -contains $name) { continue }
    $dir = Join-Path (Join-Path $ProjectPath "Assets/Scripts") $layers[$name].Dir
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    if (Test-Path -LiteralPath (Join-Path $dir "$Prefix.$name.asmdef")) { continue }
    $existing = @(Get-ChildItem -LiteralPath $dir -Recurse -File -Include *.cs, *.asmdef, *.asmref -ErrorAction SilentlyContinue)
    if ($existing.Count -gt 0) { $occupied += "Assets/Scripts/$($layers[$name].Dir) ($($existing.Count) script/assembly file(s))" }
}
if ($occupied.Count -gt 0) {
    throw ("Layer folder(s) already contain code; a new asmdef would capture it and may break compilation:`n  " + ($occupied -join "`n  ") +
        "`nFollow 'Adopting in an existing project' in references/setup-decisions.md instead. Nothing was written.")
}

function Resolve-Ref([string]$r) {
    if ($ourLayers -contains $r) { return "$Prefix.$r" }
    return $r
}

function Json-Array([string[]]$items, [string]$indent) {
    if ($items.Count -eq 0) { return "[]" }
    $inner = ($items | ForEach-Object { "$indent    `"$_`"" }) -join ",`n"
    return "[`n$inner`n$indent]"
}

function Build-Asmdef([string]$name, $def) {
    $refs = @($def.Refs | Where-Object { $Skip -notcontains $_ } | ForEach-Object { Resolve-Ref $_ })
    $include = if ($def.EditorOnly) { @("Editor") } else { @() }
    $isTest = [bool]$def.Test
    $lines = @(
        "{",
        "    `"name`": `"$Prefix.$name`",",
        "    `"rootNamespace`": `"$Prefix.$name`",",
        "    `"references`": $(Json-Array $refs '    '),",
        "    `"includePlatforms`": $(Json-Array $include '    '),",
        "    `"excludePlatforms`": [],",
        "    `"allowUnsafeCode`": false,",
        "    `"overrideReferences`": $($isTest.ToString().ToLowerInvariant()),",
        "    `"precompiledReferences`": $(if ($isTest) { Json-Array @('nunit.framework.dll') '    ' } else { '[]' }),",
        "    `"autoReferenced`": $((-not $isTest).ToString().ToLowerInvariant()),",
        "    `"defineConstraints`": $(if ($isTest) { Json-Array @('UNITY_INCLUDE_TESTS') '    ' } else { '[]' }),",
        "    `"versionDefines`": [],",
        "    `"noEngineReferences`": $(([bool]$def.NoEngine).ToString().ToLowerInvariant())",
        "}"
    )
    return ($lines -join "`n") + "`n"
}

# ---------- output helpers ----------
$created = 0; $skipped = 0
function Ensure-Dir([string]$path) {
    if (Test-Path -LiteralPath $path) { return }
    Write-Output ("DIR    " + $path.Substring($ProjectPath.Length + 1))
    if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $path | Out-Null }
}
function Write-NewFile([string]$path, [string]$content) {
    $rel = $path.Substring($ProjectPath.Length + 1)
    if (Test-Path -LiteralPath $path) {
        Write-Output "SKIP   $rel (exists)"
        $script:skipped++
        return
    }
    Write-Output "WRITE  $rel"
    $script:created++
    if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
        [IO.File]::WriteAllText($path, $content, $utf8NoBom)
    }
}

$today = Get-Date -Format "yyyy-MM-dd"
function Fill([string]$text) {
    return $text.Replace("{{PREFIX}}", $Prefix).Replace("{{PRODUCT}}", $Product).Replace("{{COMPANY}}", $Company).Replace("{{ORIENTATION}}", $Orientation).Replace("{{DATE}}", $today).Replace("{{DISABLE_DOMAIN_RELOAD}}", $(if ($FastPlayMode) { "true" } else { "false" }))
}

# Remove table rows / mermaid lines that mention a skipped layer (docs only).
$mermaidIds = @{ "Data" = "DATA"; "UI" = "UI"; "Persistence" = "PERS" }
function Strip-Skipped([string]$text) {
    if ($Skip.Count -eq 0) { return $text }
    $out = New-Object System.Collections.Generic.List[string]
    $inMermaid = $false
    foreach ($line in ($text -split "`n")) {
        if ($line -match '^```mermaid') { $inMermaid = $true }
        elseif ($inMermaid -and $line -match '^```') { $inMermaid = $false }
        $drop = $false
        foreach ($s in $Skip) {
            if ($line -match ('^\|\s*`' + [regex]::Escape("$Prefix.$s") + '`')) { $drop = $true }
            if ($inMermaid -and $line -match ('\b' + $mermaidIds[$s] + '\b')) { $drop = $true }
        }
        if (-not $drop) { $out.Add($line) }
    }
    return ($out -join "`n")
}

if ($DryRun) { Write-Output "[dry run] nothing is written" }
Write-Output "Project : $ProjectPath"
Write-Output "Prefix  : $Prefix   Product: $Product   Company: $Company   Orientation: $Orientation"
Write-Output "URP     : $useUrp   Skip: $(if ($Skip.Count) { $Skip -join ', ' } else { '(none)' })   Fast Play Mode: $([bool]$FastPlayMode)"
Write-Output ""

# ---------- 1. asset folders ----------
$assets = Join-Path $ProjectPath "Assets"
foreach ($d in @("Art", "Audio", "Data", "Materials", "Prefabs", "Scenes", "Settings", "Shaders", "ThirdParty")) {
    Ensure-Dir (Join-Path $assets $d)
}

# ---------- 2. asmdefs ----------
$scripts = Join-Path $assets "Scripts"
foreach ($name in $layers.Keys) {
    if ($Skip -contains $name) { continue }
    $def = $layers[$name]
    $dir = Join-Path $scripts $def.Dir
    Ensure-Dir $dir
    Write-NewFile (Join-Path $dir "$Prefix.$name.asmdef") (Build-Asmdef $name $def)
}

# ---------- 3. template files ----------
$map = @(
    @{ Src = "gitattributes"; Dst = ".gitattributes" },
    @{ Src = "gitignore"; Dst = ".gitignore" },
    @{ Src = "editorconfig"; Dst = ".editorconfig" },
    @{ Src = "AGENTS.md"; Dst = "AGENTS.md" },
    @{ Src = "CLAUDE.md"; Dst = "CLAUDE.md" }
)
foreach ($m in $map) {
    $text = Fill ([IO.File]::ReadAllText((Join-Path $templates $m.Src), [Text.Encoding]::UTF8))
    Write-NewFile (Join-Path $ProjectPath $m.Dst) $text
}

function Copy-Tree([string]$srcRoot, [string]$dstRoot, [bool]$isDocs) {
    Get-ChildItem -LiteralPath $srcRoot -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($srcRoot.Length + 1)
        $text = Fill ([IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8))
        if ($isDocs) { $text = Strip-Skipped $text }
        Write-NewFile (Join-Path $dstRoot $rel) $text
    }
}
Copy-Tree (Join-Path $templates "docs") (Join-Path $ProjectPath "docs") $true
Copy-Tree (Join-Path $templates "code") $scripts $false
Copy-Tree (Join-Path $templates "claude") (Join-Path $ProjectPath ".claude") $false

# ---------- summary ----------
Write-Output ""
Write-Output "Done: $created file(s) $(if ($DryRun) { 'would be written' } else { 'written' }), $skipped skipped (already existed)."
foreach ($w in $warnings) { Write-Output "WARN   $w" }
Write-Output "Next   : let Unity compile, then run Tools > Project Setup > Apply Defaults, restart the editor, run EditMode tests."
