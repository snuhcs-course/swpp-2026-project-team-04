# Copies the push-up recordings made with lib/demo/rep_judge_demo.dart from
# the phone into gymrats_app/test/fixtures/pushup_cases/.
# Needs adb on PATH and a debug build of the demo (run-as only works there).
#   powershell tools/diagnose/Pull-PushupCases.ps1 [-Serial <id>] [-Force]
param(
    [string]$Serial,
    [string]$Package = 'com.gymrats.gymrats_app',
    [string]$OutDir = (Join-Path $PSScriptRoot '..\..\gymrats_app\test\fixtures\pushup_cases'),
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
$device = if ($Serial) { @('-s', $Serial) } else { @() }

function Invoke-Adb([string[]]$Arguments) {
    # adb writes progress to stderr; Windows PowerShell 5 would turn that
    # into a terminating error under 'Stop', so only the exit code counts.
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & adb @device @Arguments 2>&1 | ForEach-Object { "$_" }
    } finally {
        $ErrorActionPreference = $previous
    }
    if ($LASTEXITCODE -ne 0) { throw "adb $($Arguments -join ' ') failed: $output" }
    return $output
}

try {
    $listing = Invoke-Adb @('shell', "run-as $Package ls files/pushup_cases")
} catch {
    Write-Host "No recordings on the phone ($($_.Exception.Message))."
    return
}
$names = @($listing | ForEach-Object { "$_".Trim() } | Where-Object { $_ -match '\.json$' })
if ($names.Count -eq 0) { Write-Host 'No recordings on the phone.'; return }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
foreach ($name in $names) {
    if ($name -notmatch '^[A-Za-z0-9_.-]+\.json$') { Write-Warning "Skipped $name (unexpected name)"; continue }
    $target = Join-Path $OutDir $name
    if ((Test-Path -LiteralPath $target) -and -not $Force) { Write-Host "exists  $name"; continue }
    # run-as can read the app's files; the shell user writes the copy, so adb can pull it.
    $staging = "/data/local/tmp/$name"
    Invoke-Adb @('shell', "run-as $Package cat files/pushup_cases/$name > $staging") | Out-Null
    try {
        Invoke-Adb @('pull', $staging, $target) | Out-Null
    } finally {
        Invoke-Adb @('shell', "rm -f $staging") | Out-Null
    }
    Write-Host "copied  $name"
}
