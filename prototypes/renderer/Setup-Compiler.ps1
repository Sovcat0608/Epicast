param([string]$Python = 'python')
$ErrorActionPreference='Stop'
Set-Location $PSScriptRoot
& ./Setup.ps1
function Check-Step { if ($LASTEXITCODE) { throw 'Local compiler setup failed; see output above.' } }
function Clone-Pinned($Url,$Target,$Revision) {
 if (!(Test-Path -LiteralPath $Target)) {
  git clone --depth 1 $Url $Target; Check-Step
  git -C $Target fetch --depth 1 origin $Revision; Check-Step
  git -C $Target checkout --detach $Revision; Check-Step
 }
 $actual=git -C $Target rev-parse HEAD; Check-Step
 if ($actual -ne $Revision) { throw "Unexpected checkout in $Target; refusing to change it." }
}
Clone-Pinned 'https://github.com/Marlamin/WebWowViewerCpp.git' 'vendor/source' '4017528a7edf10a06714643716cf4a5fc56854cf'
git -C vendor/source submodule update --init --recursive --depth 1 -- wowViewerLib/3rdparty/mathfu wowViewerLib/3rdparty/oneTbb
Check-Step
Clone-Pinned 'https://github.com/emscripten-core/emsdk.git' 'vendor/emsdk' '708dcbcc9ee23bc7d2dad44fc90db377e38b771c'
& $Python vendor/emsdk/emsdk.py install 6.0.11; Check-Step
& $Python vendor/emsdk/emsdk.py activate 6.0.11; Check-Step
# Local environment only. Never use --global, --permanent or --system.
& ./vendor/emsdk/python/3.13.3_64bit/python.exe -m pip install --target vendor/build-tools cmake==3.31.6 ninja==1.11.1.4
Check-Step
Write-Output 'Portable compiler ready. Run ./Build-Renderer.ps1.'
