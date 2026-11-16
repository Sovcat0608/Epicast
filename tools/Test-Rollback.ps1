$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$sandbox=Join-Path $root ('artifacts\rollback-test-'+[Guid]::NewGuid().ToString('N'))
$target=Join-Path $sandbox 'AddOns\Epicast';$backup=Join-Path $sandbox 'artifacts\install-test';$tools=Join-Path $sandbox 'tools'
New-Item -ItemType Directory -Force -Path $target,$backup,$tools,(Join-Path $backup 'retired') | Out-Null
$original=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Rollback-Install.ps1') -Raw
$guard='$expected=''D:\World of Warcraft\_forever_\Interface\AddOns\Epicast'''
if(-not $original.Contains($guard)){throw 'Rollback guard changed; update isolated harness'}
$script=$original.Replace($guard,('$expected='''+$target+''''))
if($script.Contains('D:\World of Warcraft')){throw 'Isolated test still references game installation'}
$testScript=Join-Path $tools 'Rollback-Install.ps1'
[IO.File]::WriteAllText($testScript,$script,[Text.UTF8Encoding]::new($false))
$report=Join-Path $backup 'install-verification.json'
function Put([string]$base,[string]$name,[string]$content){[IO.File]::WriteAllText((Join-Path $base $name),$content,[Text.UTF8Encoding]::new($false))}
function Hash([string]$base,[string]$name){return (Get-FileHash -LiteralPath (Join-Path $base $name)).Hash}
function Check([bool]$condition,[string]$message){if(-not $condition){throw $message}}
Put $backup 'One.lua' 'old';Put (Join-Path $backup 'retired') 'Retired.lua' 'retired'
Put $target 'One.lua' 'new';Put $target 'Two.lua' 'added';Put $target 'Keep.lua' 'same'
$data=[PSCustomObject]@{Destination=$target;Backup=$backup;Payload=@(
 [PSCustomObject]@{Path='One.lua';OldSHA256=(Hash $backup 'One.lua');SHA256=(Hash $target 'One.lua')},
 [PSCustomObject]@{Path='Two.lua';OldSHA256=$null;SHA256=(Hash $target 'Two.lua')},
 [PSCustomObject]@{Path='Keep.lua';OldSHA256=(Hash $target 'Keep.lua');SHA256=(Hash $target 'Keep.lua')});Retired=@(
 [PSCustomObject]@{Path='Retired.lua';OldSHA256=(Hash (Join-Path $backup 'retired') 'Retired.lua')})}
$data | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $report
& $testScript -Report $report | Out-Null
Check ((Hash $target 'One.lua') -eq $data.Payload[0].SHA256) 'Dry run changed a file'
Check (Test-Path -LiteralPath (Join-Path $target 'Two.lua')) 'Dry run removed a file'
& $testScript -Report $report -Apply | Out-Null
Check ((Hash $target 'One.lua') -eq $data.Payload[0].OldSHA256) 'Original not restored'
Check (-not(Test-Path -LiteralPath (Join-Path $target 'Two.lua'))) 'Added file not removed'
Check ((Hash $target 'Retired.lua') -eq $data.Retired[0].OldSHA256) 'Retired file not restored'
& $testScript -Report $report -Apply | Out-Null
$repeat=Get-Content -LiteralPath (Join-Path $backup 'rollback-verification.json') -Raw | ConvertFrom-Json
Check ($repeat.Restore -eq 0 -and $repeat.Remove -eq 0) 'Rollback is not idempotent'
Put $target 'One.lua' 'new';Put $target 'Two.lua' 'later user edit'
$failed=$false;try{& $testScript -Report $report -Apply | Out-Null}catch{$failed=$true}
Check $failed 'Did not reject later edits'
Check ((Hash $target 'One.lua') -eq $data.Payload[0].SHA256) 'Drift was detected after mutation'
Put $target 'Two.lua' 'added';Put $backup 'One.lua' 'damaged backup'
$failed=$false;try{& $testScript -Report $report -Apply | Out-Null}catch{$failed=$true}
Check $failed 'Did not reject damaged backup'
Put $backup 'One.lua' 'old'
$data.Payload[0].Path='../SavedVariables/Epicast.lua'
$data | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $report
$failed=$false;try{& $testScript -Report $report -Apply | Out-Null}catch{$failed=$true}
Check $failed 'Did not reject unsafe path'
Check ((Hash $target 'One.lua') -eq $data.Payload[0].SHA256) 'Unsafe receipt caused mutation'
Write-Output 'PASS: isolated rollback dry-run, restore/remove/retired handling, repeat safety, later-edit refusal, backup corruption and unsafe-path rejection; no game files accessed.'
