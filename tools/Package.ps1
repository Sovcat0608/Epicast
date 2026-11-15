param([string]$OutputDirectory)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$dist=if($OutputDirectory){[IO.Path]::GetFullPath($OutputDirectory)}else{Join-Path $root 'dist'}
$toc=Get-Content -LiteralPath (Join-Path $root 'Epicast.toc')
$version=($toc | Where-Object {$_ -match '^## Version: '}) -replace '^## Version: ',''
if($version -notmatch '^\d+\.\d+\.\d+(?:-[A-Za-z0-9.]+)?$'){throw 'Invalid version'}
$runtime=@($toc | ForEach-Object {$_.Trim()} | Where-Object {$_ -and -not $_.StartsWith('#')})
$media=(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'media-manifest.json') -Raw | ConvertFrom-Json).PSObject.Properties.Name
$files=@('Epicast.toc','README.md','CHANGELOG.md','LICENSE','THIRD-PARTY-CAS.txt')+$runtime+@($media)
if(($files | Sort-Object -Unique).Count -ne $files.Count){throw 'Duplicate manifest path'}
New-Item -ItemType Directory -Force -Path $dist | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$candidate=Join-Path $dist ([Guid]::NewGuid().ToString('N')+'.zip')
$zip=[IO.Compression.ZipFile]::Open($candidate,[IO.Compression.ZipArchiveMode]::Create)
try {foreach($file in $files){
 $source=[IO.Path]::GetFullPath((Join-Path $root $file))
 if(-not $source.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe manifest path'}
 [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$source,('Epicast/'+$file.Replace('\','/')),[IO.Compression.CompressionLevel]::Optimal) | Out-Null
}} finally {$zip.Dispose()}
$zip=[IO.Compression.ZipFile]::OpenRead($candidate)
try {if($zip.Entries.Count -ne $files.Count){throw 'Wrong file count'};foreach($entry in $zip.Entries){
 $relative=$entry.FullName.Substring(8);if($files -notcontains $relative){throw 'Unexpected ZIP entry'}
 $stream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create()
 try {$actual=[Convert]::ToHexString($sha.ComputeHash($stream));if($actual -ne (Get-FileHash -LiteralPath (Join-Path $root $relative)).Hash){throw "Hash mismatch $relative"}}finally{$stream.Dispose();$sha.Dispose()}
}}finally{$zip.Dispose()}
$archive=Join-Path $dist "Epicast-$version.zip"
Move-Item -LiteralPath $candidate -Destination $archive -Force
$report=[PSCustomObject]@{Version=$version;Files=$files.Count;Bytes=(Get-Item -LiteralPath $archive).Length;SHA256=(Get-FileHash -LiteralPath $archive).Hash;Archive=$archive}
$report | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $dist 'package-verification.json')
$report | Format-List
