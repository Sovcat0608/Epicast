$ErrorActionPreference='Stop'
$cache=Join-Path $PSScriptRoot '.cache'
New-Item -ItemType Directory -Force -Path $cache | Out-Null
$record=Join-Path $cache 'server.json'
if(Test-Path -LiteralPath $record){
 $old=Get-Content -LiteralPath $record -Raw | ConvertFrom-Json
 $process=Get-CimInstance Win32_Process -Filter ('ProcessId='+[int]$old.pid) -ErrorAction SilentlyContinue
 if($process -and $process.CommandLine.Contains((Join-Path $PSScriptRoot 'server.cjs'))){
  Write-Output 'Prototype already running: http://127.0.0.1:4318';return
 }
}
& (Join-Path $PSScriptRoot 'Setup.ps1')
node (Join-Path $PSScriptRoot 'native/build-manifest.cjs') --verify
if($LASTEXITCODE){throw 'Compile the calibrated renderer with ./Build-Renderer.ps1 first.'}
$node=(Get-Command node -ErrorAction Stop).Source
$server=Join-Path $PSScriptRoot 'server.cjs'
$process=Start-Process -FilePath $node -ArgumentList @('"'+$server+'"') -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $cache 'server.log') -RedirectStandardError (Join-Path $cache 'server-error.log') -PassThru
@{pid=$process.Id;script=$server;started=(Get-Date).ToUniversalTime().ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath $record
Write-Output ('Started prototype PID '+$process.Id+': http://127.0.0.1:4318')
