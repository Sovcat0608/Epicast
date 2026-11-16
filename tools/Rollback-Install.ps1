param([Parameter(Mandatory=$true)][string]$Report,[switch]$Apply)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$expected='D:\World of Warcraft\_forever_\Interface\AddOns\Epicast'
$reportPath=[IO.Path]::GetFullPath($Report)
$backup=[IO.Path]::GetDirectoryName($reportPath)
if(-not $backup.StartsWith((Join-Path $root 'artifacts')+'\',[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($reportPath) -ne 'install-verification.json'){throw 'Rollback report must be an Epicast workspace install receipt'}
$data=Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
if($data.Destination -ne $expected -or $data.Backup -ne $backup){throw 'Rollback destination or backup does not match the receipt'}
function SafePath([string]$base,[string]$relative){
 if($relative -notmatch '^(?:retired/)?(?:Media/)?[A-Za-z0-9][A-Za-z0-9._-]*$' -or $relative -match 'SavedVariables|WTF'){throw 'Unsafe rollback payload path'}
 $resolved=[IO.Path]::GetFullPath((Join-Path $base $relative))
 if(-not $resolved.StartsWith($base+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Rollback path escapes its root'}
 $check=$resolved
 while($check -and $check.Length -ge $base.Length){
  if((Test-Path -LiteralPath $check) -and ((Get-Item -LiteralPath $check).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Rollback paths must not contain links'}
  if($check -eq $base){break};$check=Split-Path $check -Parent
 }
 return $resolved
}
function HashOrNull([string]$path){if(Test-Path -LiteralPath $path){if((Get-Item -LiteralPath $path).PSIsContainer){throw 'Expected a rollback file'};return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash};return $null}
$plan=@();$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach($item in @($data.Payload)+@($data.Retired)){
 if(-not $seen.Add($item.Path)){throw 'Duplicate rollback path'}
 $target=SafePath $expected $item.Path
 $previous=$item.OldSHA256;$installed=$item.SHA256
 foreach($hash in @($previous,$installed)){if($hash -and $hash -notmatch '^[A-Fa-f0-9]{64}$'){throw 'Invalid receipt digest'}}
 $actual=HashOrNull $target;$action='Keep';$source=$null
 if($actual -ne $previous){
  if($actual -ne $installed){throw "File changed since this installation; refusing rollback: $($item.Path)"}
  if($previous){
   $relative=if($installed){$item.Path}else{'retired/'+$item.Path}
   $source=SafePath $backup $relative
   if((HashOrNull $source) -ne $previous){throw "Rollback backup failed verification: $($item.Path)"}
   $action='Restore'
  }else{$action='Remove'}
 }
 $plan+=[PSCustomObject]@{Path=$item.Path;Target=$target;Source=$source;ExpectedBefore=$actual;ExpectedAfter=$previous;Action=$action}
}
if(-not $plan.Count){throw 'Empty rollback receipt'}
if($Apply){
 foreach($item in $plan){
  if((HashOrNull $item.Target) -ne $item.ExpectedBefore){throw 'Installed file changed during rollback'}
  if($item.Action -eq 'Restore'){
   if((HashOrNull $item.Source) -ne $item.ExpectedAfter){throw 'Backup changed during rollback'}
   New-Item -ItemType Directory -Force -Path (Split-Path $item.Target -Parent) | Out-Null
   Copy-Item -LiteralPath $item.Source -Destination $item.Target -Force
  }elseif($item.Action -eq 'Remove'){Remove-Item -LiteralPath $item.Target}
 }
 foreach($item in $plan){if((HashOrNull $item.Target) -ne $item.ExpectedAfter){throw "Rollback verification failed: $($item.Path)"}}
}
$result=[PSCustomObject]@{Destination=$expected;Files=$plan.Count;Restore=@($plan | Where-Object Action -eq 'Restore').Count;Remove=@($plan | Where-Object Action -eq 'Remove').Count;Applied=[bool]$Apply;SavedVariablesAccessed=$false;Report=$reportPath}
if($Apply){$result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $backup 'rollback-verification.json')}
$result | Format-List
