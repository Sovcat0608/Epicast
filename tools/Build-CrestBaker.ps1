$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
$output = Join-Path (Split-Path $PSScriptRoot -Parent) 'artifacts\crest-baker'
$destination = Join-Path $output 'Epicast Crest Baker - Bake and Reload.exe'
New-Item -ItemType Directory -Force -Path $output | Out-Null
& $compiler /nologo /target:winexe /optimize+ /reference:System.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll "/out:$destination" (Join-Path $PSScriptRoot 'CrestBaker.cs')
if ($LASTEXITCODE -ne 0) { throw 'Crest Baker compilation failed.' }
Write-Output $destination
