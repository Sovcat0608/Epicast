$ErrorActionPreference='Stop'
$record=Join-Path $PSScriptRoot '.cache/server.json'
if(-not(Test-Path -LiteralPath $record)){Write-Output 'No recorded prototype process.';return}
$saved=Get-Content -LiteralPath $record -Raw | ConvertFrom-Json
$server=Join-Path $PSScriptRoot 'server.cjs'
$process=Get-CimInstance Win32_Process -Filter ('ProcessId='+[int]$saved.pid) -ErrorAction SilentlyContinue
if($process){
 if($saved.script -ne $server -or -not $process.CommandLine.Contains($server)){throw 'Recorded PID is no longer this prototype; refusing to stop it.'}
 Stop-Process -Id $process.ProcessId
}
Remove-Item -LiteralPath $record
Write-Output 'Prototype stopped.'
