param([Parameter(Mandatory=$true)][string]$Archive,
 [string]$Destination='D:\World of Warcraft\_forever_\Interface\AddOns\Epicast')
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
$report=[PSCustomObject]@{Archive=$archivePath;ArchiveSHA256=(Get-FileHash -LiteralPath $archivePath).Hash;Destination=$destinationRoot;Files=$items.Count;Changed=@($items | Where-Object Changed).Count;Backup=$backup;SavedVariablesAccessed=$false;Payload=$items}
$report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $backup 'install-verification.json')
$report | Select-Object Archive,Destination,Files,Changed,Backup,SavedVariablesAccessed | Format-List
