$ErrorActionPreference='Stop'
$revision='3b1df6a6908cd06629625cb55a900f3267895920'
$vendor=Join-Path $PSScriptRoot 'vendor'
New-Item -ItemType Directory -Force -Path $vendor | Out-Null
$files=@(
 @{Name='project.js';Path='wwwroot/mv/project.js';Hash='8A0A3E2A7670A70086B098CDFAA1A9CD2A07E0730F4978E1776B38888508DF5D'},
 @{Name='project.wasm';Path='wwwroot/mv/project.wasm';Hash='7275ACDA1B16BC11D989BBF3049D73EBDDE4A52BBAFFB53E22811F265AE30659'},
 @{Name='project.data';Path='wwwroot/mv/project.data';Hash='45192409CC7D8B045BF31351EF2AC9F433F1C5BF4F9B9EC065343DB099AADE89'},
 @{Name='LICENSE';Path='LICENSE';Hash='C5B56E72CDB0EC994652B3D16EDE9A41CD862CEAC2D387D7B4AC29A91E3A8584'}
)
foreach($file in $files){
 $target=Join-Path $vendor $file.Name
 if((Test-Path -LiteralPath $target) -and (Get-FileHash -LiteralPath $target).Hash -eq $file.Hash){continue}
 Invoke-WebRequest -Uri ('https://raw.githubusercontent.com/Marlamin/wow.tools.local/'+$revision+'/'+$file.Path) -OutFile $target
 if((Get-FileHash -LiteralPath $target).Hash -ne $file.Hash){throw ('Unexpected upstream bytes: '+$file.Name)}
}
Write-Output 'Pinned original renderer verified. The calibrated prototype also requires Build-Renderer.ps1 (see README).'
Write-Output 'For automated tests only: npm ci; $env:PLAYWRIGHT_BROWSERS_PATH="$PWD/.browsers"; npx playwright install chromium; npm test'
