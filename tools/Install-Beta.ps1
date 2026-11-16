param([Parameter(Mandatory=$true)][string]$Archive,
 [string]$Destination='D:\World of Warcraft\_forever_\Interface\AddOns\Epicast',
 [switch]$VerifyOnly)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$destinationRoot=[IO.Path]::GetFullPath($Destination).TrimEnd('\')
$expected='D:\World of Warcraft\_forever_\Interface\AddOns\Epicast'
if($destinationRoot -ne $expected){throw 'Installer is restricted to the confirmed WoW Forever Epicast folder'}
if((Get-Item -LiteralPath $destinationRoot).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Unexpected destination link'}
$archivePath=[IO.Path]::GetFullPath($Archive)
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=[IO.Compression.ZipFile]::OpenRead($archivePath)
$items=@()
try {
 foreach($entry in $zip.Entries){
  if(-not $entry.FullName.StartsWith('Epicast/')){throw 'Unexpected archive root'}
  $relative=$entry.FullName.Substring(8)
  if($relative -match '(^|[/\\])\.\.([/\\]|$)|SavedVariables|(^|[/\\])WTF([/\\]|$)' -or $relative.EndsWith('/')){throw 'Unsafe archive path'}
  $target=[IO.Path]::GetFullPath((Join-Path $destinationRoot $relative))
  $source=[IO.Path]::GetFullPath((Join-Path $root $relative))
  if(-not $target.StartsWith($destinationRoot+'\',[StringComparison]::OrdinalIgnoreCase) -or -not $source.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Escaping archive path'}
  $stream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create()
  try {$hash=[Convert]::ToHexString($sha.ComputeHash($stream))}finally{$stream.Dispose();$sha.Dispose()}
  if($hash -ne (Get-FileHash -LiteralPath $source).Hash){throw "Archive/source mismatch: $relative"}
  $parent=Split-Path $target -Parent
  if((Test-Path -LiteralPath $parent) -and ((Get-Item -LiteralPath $parent).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Unexpected destination parent link'}
  if((Test-Path -LiteralPath $target) -and ((Get-Item -LiteralPath $target).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Unexpected destination file link'}
  $oldHash=if(Test-Path -LiteralPath $target){(Get-FileHash -LiteralPath $target).Hash}else{$null}
  $items+= [PSCustomObject]@{Path=$relative;Source=$source;Target=$target;SHA256=$hash;OldSHA256=$oldHash;Changed=$hash -ne $oldHash}
 }
}finally{$zip.Dispose()}
if(@($items.Path | Sort-Object -Unique).Count -ne $items.Count){throw 'Duplicate install path'}
$retired=@()
foreach($relative in (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'retired-mage-files.json') -Raw | ConvertFrom-Json)){
 if($relative -notmatch '^(?:[A-Za-z][A-Za-z0-9]*\.lua|Media/[A-Za-z][A-Za-z0-9]*\.tga)$' -or $items.Path -contains $relative){throw 'Unsafe or still-packaged retired path'}
 $target=[IO.Path]::GetFullPath((Join-Path $destinationRoot $relative))
 $source=[IO.Path]::GetFullPath((Join-Path $root $relative))
 if(-not $target.StartsWith($destinationRoot+'\',[StringComparison]::OrdinalIgnoreCase) -or -not $source.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Escaping retired path'}
 if(Test-Path -LiteralPath $source){throw "Retired file still exists in source: $relative"}
 $parent=Split-Path $target -Parent
 if((Test-Path -LiteralPath $parent) -and ((Get-Item -LiteralPath $parent).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Unexpected retired parent link'}
 if(Test-Path -LiteralPath $target){
  $file=Get-Item -LiteralPath $target
  if($file.PSIsContainer -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Unexpected retired target type'}
  $retired+=[PSCustomObject]@{Path=$relative;Target=$target;OldSHA256=(Get-FileHash -LiteralPath $target).Hash}
 }
}
if(@($retired.Path | Sort-Object -Unique).Count -ne $retired.Count){throw 'Duplicate retired path'}
if($VerifyOnly){
 [PSCustomObject]@{Archive=$archivePath;Destination=$destinationRoot;Files=$items.Count;Changed=@($items | Where-Object Changed).Count;Retired=$retired.Count;SavedVariablesAccessed=$false;WritesPerformed=$false} | Format-List
 return
}
$backup=Join-Path $root ('artifacts\install-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $backup | Out-Null
foreach($item in $items | Where-Object Changed){
 if($item.OldSHA256){
  $backupFile=Join-Path $backup $item.Path
  New-Item -ItemType Directory -Force -Path (Split-Path $backupFile -Parent) | Out-Null
  Copy-Item -LiteralPath $item.Target -Destination $backupFile
 }
 New-Item -ItemType Directory -Force -Path (Split-Path $item.Target -Parent) | Out-Null
 Copy-Item -LiteralPath $item.Source -Destination $item.Target -Force
}
foreach($item in $items){if((Get-FileHash -LiteralPath $item.Target).Hash -ne $item.SHA256){throw "Installed hash mismatch: $($item.Path)"}}
foreach($item in $retired){
 if((Get-FileHash -LiteralPath $item.Target).Hash -ne $item.OldSHA256){throw 'Retired file changed during installation'}
 $backupFile=Join-Path (Join-Path $backup 'retired') $item.Path
 New-Item -ItemType Directory -Force -Path (Split-Path $backupFile -Parent) | Out-Null
 Copy-Item -LiteralPath $item.Target -Destination $backupFile
 if((Get-FileHash -LiteralPath $backupFile).Hash -ne $item.OldSHA256){throw 'Retired backup mismatch'}
 Remove-Item -LiteralPath $item.Target
 if(Test-Path -LiteralPath $item.Target){throw 'Retired file removal failed'}
}
$report=[PSCustomObject]@{Archive=$archivePath;ArchiveSHA256=(Get-FileHash -LiteralPath $archivePath).Hash;Destination=$destinationRoot;Files=$items.Count;Changed=@($items | Where-Object Changed).Count;Removed=$retired.Count;Backup=$backup;SavedVariablesAccessed=$false;Payload=$items;Retired=$retired}
$report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $backup 'install-verification.json')
$report | Select-Object Archive,Destination,Files,Changed,Removed,Backup,SavedVariablesAccessed | Format-List
