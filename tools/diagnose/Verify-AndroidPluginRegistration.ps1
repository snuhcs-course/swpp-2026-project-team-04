param(
    [Parameter(Mandatory = $true)][string]$Apk,
    [string]$Dexdump = 'C:\Users\sangw\AppData\Local\Android\Sdk\build-tools\36.0.0\dexdump.exe'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$apkPath = (Resolve-Path -LiteralPath $Apk).Path
$audit = Join-Path ([IO.Path]::GetTempPath()) ('gymrats-apk-plugins-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $audit | Out-Null
$archive = [IO.Compression.ZipFile]::OpenRead($apkPath)
$registration = $null
try {
    foreach ($entry in ($archive.Entries | Where-Object FullName -match '^classes\d*\.dex$')) {
        $inputStream = $entry.Open()
        $memory = [IO.MemoryStream]::new()
        try {
            $inputStream.CopyTo($memory)
            $strings = [Text.Encoding]::Latin1.GetString($memory.ToArray())
        } finally {
            $inputStream.Dispose()
            $memory.Dispose()
        }
        if (-not $strings.Contains('Lio/flutter/plugins/GeneratedPluginRegistrant;')) { continue }
        $dexPath = Join-Path $audit $entry.FullName
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $dexPath)
        $dump = (& $Dexdump -d $dexPath) -join "`n"
        if ($LASTEXITCODE -ne 0) { throw 'DEX inspection failed' }
        $match = [regex]::Match($dump, "(?s)Class descriptor\s*:\s*'Lio/flutter/plugins/GeneratedPluginRegistrant;'(?<body>.*?)(?=\nClass #|\z)")
        if ($match.Success) { $registration = $match.Groups['body'].Value; break }
    }
} finally { $archive.Dispose() }
if (-not $registration) { throw 'Compiled GeneratedPluginRegistrant was not found in APK' }
$required = @(
    'com/it_nomads/fluttersecurestorage/FlutterSecureStoragePlugin',
    'com/github/dart_lang/jni/JniPlugin',
    'com/github/dart_lang/jni_flutter/JniFlutterPlugin',
    'io/flutter/plugins/camerax/CameraAndroidCameraxPlugin',
    'io/flutter/plugins/webviewflutter/WebViewFlutterPlugin'
)
foreach ($plugin in $required) {
    if ($registration -notmatch ('new-instance[^\n]*L' + [regex]::Escape($plugin) + ';')) {
        throw "APK plugin registration missing: $plugin"
    }
    Write-Output ('REGISTERED ' + ($plugin -split '/')[-1])
}
Write-Output ('APK_SHA256=' + (Get-FileHash -LiteralPath $apkPath -Algorithm SHA256).Hash)
Write-Output 'PLUGIN_REGISTRATION_CHECK_PASSED'
