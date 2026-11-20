$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$env:EMSDK_QUIET='1'
$env:PATH = "$PSScriptRoot/vendor/build-tools/cmake/data/bin;$PSScriptRoot/vendor/build-tools/bin;$env:PATH"
. ./vendor/emsdk/emsdk_env.ps1
node native/patch-source.cjs
if ($LASTEXITCODE) { throw 'Source patch failed' }
& ./vendor/emsdk/upstream/emscripten/emcmake.exe cmake -S vendor/source/emscripten_port -B vendor/build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS_RELEASE='-O2 -DNDEBUG' -DCMAKE_C_FLAGS_RELEASE='-O2 -DNDEBUG'
if ($LASTEXITCODE) { throw 'CMake configuration failed' }
cmake --build vendor/build --parallel 8 *> .cache/native-build.log
if ($LASTEXITCODE) { Get-Content .cache/native-build.log -Tail 60; throw 'Native renderer build failed' }
node native/build-manifest.cjs
if ($LASTEXITCODE) { throw 'Build manifest failed' }
Get-ChildItem vendor/build_packed/project.* | Select-Object Name,Length
