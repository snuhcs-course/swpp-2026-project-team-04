$ErrorActionPreference = 'Stop'
$previewPython = 'C:\Users\sangw\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
if (-not (Test-Path -LiteralPath $previewPython)) { $previewPython = (Get-Command python -ErrorAction Stop).Source }
$previewPort = 8765
if (-not (Test-NetConnection 127.0.0.1 -Port $previewPort -InformationLevel Quiet -WarningAction SilentlyContinue)) {
    Start-Process -FilePath $previewPython -ArgumentList @('"' + (Join-Path $PSScriptRoot 'serve.py') + '"', '--port', $previewPort) -WindowStyle Hidden
    Start-Sleep -Seconds 2
}
Start-Process 'http://127.0.0.1:8765'
