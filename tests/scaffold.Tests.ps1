# Checks scaffold.ps1 against throwaway Unity project skeletons.
# Runs on Windows PowerShell 5.1 and PowerShell 7 (Windows, macOS, Linux):
#   pwsh -File tests/scaffold.Tests.ps1
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$scaffold = Join-Path $repo "plugins/unity-project-setup/skills/unity-project-setup/scripts/scaffold.ps1"
$work = Join-Path ([IO.Path]::GetTempPath()) ("scaffold-test-" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
$failures = New-Object System.Collections.Generic.List[string]

function Check([bool]$condition, [string]$message) {
    if ($condition) { Write-Output "PASS  $message" } else { Write-Output "FAIL  $message"; $failures.Add($message) }
}

function New-FakeProject([string]$name, [string]$manifest) {
    $p = Join-Path $work $name
    New-Item -ItemType Directory -Force (Join-Path $p "ProjectSettings"), (Join-Path $p "Packages") | Out-Null
    Set-Content -LiteralPath (Join-Path $p "ProjectSettings/ProjectVersion.txt") "m_EditorVersion: 6000.3.0f1"
    Set-Content -LiteralPath (Join-Path $p "Packages/manifest.json") $manifest
    return $p
}

# Run the scaffold in a child process, as an agent would, and return its output.
function Invoke-Scaffold([string[]]$arguments) {
    $exe = (Get-Process -Id $PID).Path
    $all = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $scaffold) + $arguments
    # Windows PowerShell 5.1 turns native stderr into terminating errors under "Stop"; expected failures write to stderr.
    $ErrorActionPreference = "Continue"
    $out = & $exe @all 2>&1 | Out-String
    return @{ Output = $out; ExitCode = $LASTEXITCODE }
}

$full = '{"dependencies":{"com.unity.inputsystem":"1.20.1","com.unity.ugui":"2.0.0","com.unity.test-framework":"1.6.0","com.unity.render-pipelines.universal":"17.3.0"}}'

try {
    # 1. Dry run writes nothing
    $a = New-FakeProject "A" $full
    $r = Invoke-Scaffold @("-ProjectPath", $a, "-Prefix", "Orbit", "-DryRun")
    Check ($r.ExitCode -eq 0) "dry run exits 0"
    Check (-not (Test-Path -LiteralPath (Join-Path $a "Assets"))) "dry run writes nothing"

    # 2. Real run creates the expected tree
    $r = Invoke-Scaffold @("-ProjectPath", $a, "-Prefix", "Orbit", "-Product", "Orbit Run", "-Orientation", "Landscape")
    Check ($r.ExitCode -eq 0) "real run exits 0"
    Check ($r.Output -match "27 file\(s\) written") "real run writes 27 files"
    foreach ($d in "Art", "Audio", "Data", "Materials", "Prefabs", "Scenes", "Settings", "Shaders", "ThirdParty") {
        Check (Test-Path -LiteralPath (Join-Path $a "Assets/$d")) "folder Assets/$d exists"
    }
    Check (-not (Test-Path -LiteralPath (Join-Path $a "Assets/Resources"))) "no Assets/Resources"
    foreach ($l in @("Core/Orbit.Core", "Data/Orbit.Data", "Gameplay/Orbit.Gameplay", "UI/Orbit.UI", "Persistence/Orbit.Persistence",
                     "Bootstrap/Orbit.Bootstrap", "Editor/Orbit.Editor", "Core/Tests/EditMode/Orbit.Core.Tests")) {
        Check (Test-Path -LiteralPath (Join-Path $a "Assets/Scripts/$l.asmdef")) "asmdef $l.asmdef exists"
    }
    foreach ($f in ".gitattributes", ".gitignore", ".editorconfig", "AGENTS.md", "CLAUDE.md", "docs/README.md", "docs/workflow.md",
                   "docs/tasks/TEMPLATE.md", ".claude/skills/ship-to-develop/SKILL.md") {
        Check (Test-Path -LiteralPath (Join-Path $a $f)) "file $f exists"
    }
    $core = Get-Content -Raw -LiteralPath (Join-Path $a "Assets/Scripts/Core/Orbit.Core.asmdef") | ConvertFrom-Json
    Check ($core.noEngineReferences -eq $true -and @($core.references).Count -eq 0) "Core has noEngineReferences and no references"
    $ui = Get-Content -Raw -LiteralPath (Join-Path $a "Assets/Scripts/UI/Orbit.UI.asmdef") | ConvertFrom-Json
    Check (-not (@($ui.references) -contains "Orbit.Gameplay")) "UI does not reference Gameplay"
    Check (@($ui.references) -contains "Unity.RenderPipelines.Universal.Runtime") "URP detected from manifest"
    $settings = Get-Content -Raw -LiteralPath (Join-Path $a "Assets/Scripts/Editor/ProjectSetup/ApplyProjectSettings.cs")
    Check ($settings -match 'UIOrientation\.LandscapeLeft' -and $settings -match 'ProductName = "Orbit Run"') "orientation and product filled in"
    Check ($settings -match 'DisableDomainReload = false;') "fast Play Mode off by default"
    $leftover = Get-ChildItem -LiteralPath $a -Recurse -File | Select-String -Pattern '\{\{[A-Z_]+\}\}' -List
    Check (@($leftover).Count -eq 0) "no unfilled placeholders"
    Check (@(Get-ChildItem -LiteralPath $a -Recurse -File -Filter *.meta).Count -eq 0) "no .meta files written"

    # 3. Re-run skips everything
    $r = Invoke-Scaffold @("-ProjectPath", $a, "-Prefix", "Orbit")
    Check ($r.Output -match "0 file\(s\) written, 27 skipped") "re-run skips all 27 files"

    # 4. Skipped layers, URP off, fast Play Mode
    $b = New-FakeProject "B" $full
    $r = Invoke-Scaffold @("-ProjectPath", $b, "-Skip", "Persistence,UI", "-Urp", "false", "-FastPlayMode")
    Check ($r.ExitCode -eq 0) "skip run exits 0"
    Check (-not (Test-Path -LiteralPath (Join-Path $b "Assets/Scripts/UI"))) "UI layer skipped"
    $boot = Get-Content -Raw -LiteralPath (Join-Path $b "Assets/Scripts/Bootstrap/Game.Bootstrap.asmdef") | ConvertFrom-Json
    Check (-not (@($boot.references) -contains "Game.UI") -and -not (@($boot.references) -contains "Game.Persistence")) "skipped layers removed from references"
    $gp = Get-Content -Raw -LiteralPath (Join-Path $b "Assets/Scripts/Gameplay/Game.Gameplay.asmdef") | ConvertFrom-Json
    Check (-not (@($gp.references) -contains "Unity.RenderPipelines.Universal.Runtime")) "URP references off with -Urp false"
    $design = Get-Content -Raw -LiteralPath (Join-Path $b "docs/architecture-design.md")
    Check ($design -notmatch '\| `Game\.UI`' -and $design -cnotmatch '\bPERS\b') "skipped layers removed from docs table and diagram"
    $settingsB = Get-Content -Raw -LiteralPath (Join-Path $b "Assets/Scripts/Editor/ProjectSetup/ApplyProjectSettings.cs")
    Check ($settingsB -match 'DisableDomainReload = true;') "-FastPlayMode turns Domain Reload off"

    # 5. Missing packages warn
    $c = New-FakeProject "C" '{"dependencies":{}}'
    $r = Invoke-Scaffold @("-ProjectPath", $c, "-DryRun")
    Check ($r.Output -match "WARN.*inputsystem" -and $r.Output -match "WARN.*test-framework") "missing packages warn"

    # 6. Invalid input is rejected
    foreach ($bad in @(@("-Prefix", "game"), @("-Skip", "Core"), @("-Orientation", "Diagonal"))) {
        $r = Invoke-Scaffold (@("-ProjectPath", $c, "-DryRun") + $bad)
        Check ($r.ExitCode -ne 0) "rejects $($bad -join ' ')"
    }
    $r = Invoke-Scaffold @("-ProjectPath", $work, "-DryRun")
    Check ($r.ExitCode -ne 0 -and $r.Output -match "Not a Unity project") "rejects a non-Unity folder"
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output ""
if ($failures.Count -gt 0) {
    Write-Output "$($failures.Count) check(s) failed."
    exit 1
}
Write-Output "All checks passed."
exit 0 # the last child run was an expected failure; don't let its exit code leak out
