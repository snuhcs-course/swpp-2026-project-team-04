$ErrorActionPreference = 'Stop'
$avatarRepo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$avatarNpx = (Get-Command npx.cmd -ErrorAction Stop).Source
$avatarEntry = Join-Path $PSScriptRoot 'native-renderer.js'
$avatarThree = Join-Path $PSScriptRoot 'vendor\three\build\three.module.js'
$avatarOutput = Join-Path $avatarRepo 'gymrats_app\assets\avatar\avatar.bundle.js'
& $avatarNpx --yes --package=esbuild@0.25.12 esbuild $avatarEntry --bundle --format=iife --minify "--alias:three=$avatarThree" "--outfile=$avatarOutput"
if ($LASTEXITCODE -ne 0) { throw 'Avatar renderer build failed' }
