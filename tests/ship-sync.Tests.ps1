# Checks the git steps of the generated ship-to-develop skill (steps 4-6) against throwaway repositories,
# with someone else's uncommitted work in the tree — the normal state of a shared working copy.
# Runs on Windows PowerShell 5.1 and PowerShell 7 (Windows, macOS, Linux):
#   pwsh -File tests/ship-sync.Tests.ps1
$ErrorActionPreference = "Stop"
$work = Join-Path ([IO.Path]::GetTempPath()) ("ship-sync-test-" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
$failures = New-Object System.Collections.Generic.List[string]

function Check([bool]$condition, [string]$message) {
    if ($condition) { Write-Output "PASS  $message" } else { Write-Output "FAIL  $message"; $failures.Add($message) }
}

# Runs git in the current directory (named Invoke-Git: a function called "Git" would shadow git.exe and call itself); returns output and exit code without throwing on expected failures.
function Invoke-Git {
    $ErrorActionPreference = "Continue"
    $out = & git -c user.name=test -c user.email=test@example.com -c core.autocrlf=false -c init.defaultBranch=main @args 2>&1 | Out-String
    return @{ Output = $out; ExitCode = $LASTEXITCODE }
}

function Write-File([string]$path, [string]$text) { Set-Content -LiteralPath $path -Value $text }

# Step 5's comparison: "<only local> <only remote>"
function Get-Ahead-Behind {
    $r = Invoke-Git rev-list --left-right --count "develop...origin/develop"
    $parts = $r.Output.Trim() -split '\s+'
    return @{ Local = [int]$parts[0]; Remote = [int]$parts[1] }
}

try {
    New-Item -ItemType Directory -Force $work | Out-Null
    Set-Location $work

    # A remote with main and develop, like a project after the skill's Step 4 and a first push.
    Invoke-Git init -q --bare origin.git | Out-Null
    Invoke-Git clone -q origin.git seed | Out-Null
    Set-Location seed
    Write-File "shared.txt" "base"
    Invoke-Git add shared.txt | Out-Null; Invoke-Git commit -q -m "chore: setup" | Out-Null
    Invoke-Git push -q origin HEAD:main | Out-Null; Invoke-Git push -q origin HEAD:develop | Out-Null
    Set-Location $work

    # 1. Fresh clone: only main is checked out, develop exists only as origin/develop (step 4)
    Invoke-Git clone -q origin.git dev | Out-Null
    Set-Location dev
    Check ((Invoke-Git rev-parse -q --verify refs/heads/develop).ExitCode -ne 0) "fresh clone has no local develop"
    Write-File "shared.txt" "someone else's work in progress"          # uncommitted, not ours
    Write-File "task-a.txt" "task a"
    Check ((Invoke-Git switch -c feat/a develop).ExitCode -ne 0) "creating feat/ from develop fails before the local branch exists"
    Invoke-Git branch develop origin/develop | Out-Null                        # step 4
    Check ((Invoke-Git switch -c feat/a develop).ExitCode -eq 0) "after 'git branch develop origin/develop', feat/ is created from develop"
    Invoke-Git add task-a.txt | Out-Null; Invoke-Git commit -q -m "feat: a" | Out-Null

    # 2. Behind only: someone pushed to develop meanwhile (step 5)
    Set-Location (Join-Path $work "seed")
    Invoke-Git pull -q origin develop | Out-Null
    Write-File "remote-1.txt" "r1"; Invoke-Git add remote-1.txt | Out-Null; Invoke-Git commit -q -m "feat: remote 1" | Out-Null
    Invoke-Git push -q origin HEAD:develop | Out-Null
    Set-Location (Join-Path $work "dev")
    Invoke-Git fetch -q origin | Out-Null
    $c = Get-Ahead-Behind
    Check ($c.Local -eq 0 -and $c.Remote -eq 1) "behind-only case reads 0 1"
    Check ((Invoke-Git pull --rebase origin develop).ExitCode -ne 0) "old step (pull --rebase with uncommitted work) is refused"
    Check ((Invoke-Git fetch origin develop:develop).ExitCode -eq 0) "fetch origin develop:develop fast-forwards from the task branch"
    $c = Get-Ahead-Behind
    Check ($c.Local -eq 0 -and $c.Remote -eq 0) "develop matches origin/develop after the fast-forward"
    Check ((Get-Content -Raw shared.txt).Trim() -eq "someone else's work in progress") "uncommitted work untouched by the sync"
    Check ((Invoke-Git switch develop).ExitCode -eq 0 -and (Invoke-Git merge --no-edit feat/a).ExitCode -eq 0) "step 6 merges the task into develop"
    Invoke-Git branch -d feat/a | Out-Null                                     # merge awaits push approval: not pushed

    # 3. Both sides moved: a local merge awaits push approval and the remote moved again (step 5 stops, step 6 with OK)
    Set-Location (Join-Path $work "seed")
    Write-File "remote-2.txt" "r2"; Invoke-Git add remote-2.txt | Out-Null; Invoke-Git commit -q -m "feat: remote 2" | Out-Null
    Invoke-Git push -q origin HEAD:develop | Out-Null
    Set-Location (Join-Path $work "dev")
    Invoke-Git switch -q -c feat/b | Out-Null
    Write-File "task-b.txt" "task b"; Invoke-Git add task-b.txt | Out-Null; Invoke-Git commit -q -m "feat: b" | Out-Null
    Invoke-Git fetch -q origin | Out-Null
    $c = Get-Ahead-Behind
    Check ($c.Local -gt 0 -and $c.Remote -gt 0) "diverged case reads N M"
    Check ((Invoke-Git fetch origin develop:develop).ExitCode -ne 0) "fast-forward is refused when both sides moved"
    $mergesBefore = [int](Invoke-Git rev-list --merges --count develop).Output.Trim()
    Invoke-Git switch -q develop | Out-Null
    $ok = (Invoke-Git merge --no-edit origin/develop).ExitCode -eq 0 -and (Invoke-Git merge --no-edit feat/b).ExitCode -eq 0
    Check $ok "with the user's OK, merging origin/develop then the task succeeds"
    $mergesAfter = [int](Invoke-Git rev-list --merges --count develop).Output.Trim()
    Check ($mergesAfter -eq $mergesBefore + 2) "earlier merge commit kept; two new merges added"
    Check ((Invoke-Git merge-base --is-ancestor origin/develop develop).ExitCode -eq 0) "develop now contains origin/develop (push would fast-forward)"
    Check ((Get-Content -Raw shared.txt).Trim() -eq "someone else's work in progress") "uncommitted work still untouched"
}
finally {
    Set-Location ([IO.Path]::GetTempPath())
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output ""
if ($failures.Count -gt 0) {
    Write-Output "$($failures.Count) check(s) failed."
    exit 1
}
Write-Output "All checks passed."
exit 0
