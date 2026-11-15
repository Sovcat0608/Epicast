$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$source=Join-Path $root 'concepts\druid-sisters\Moonwarden-Groveheart-review.png'
if((Get-FileHash -LiteralPath $source).Hash -ne '926C6CC974FCD6015A1AE576E52123C7C4F2A157DECADD3F0CB5F92DCA157034'){throw 'Approved source changed'}
$output=Join-Path $root 'artifacts\druid'
New-Item -ItemType Directory -Force -Path $output | Out-Null
Add-Type -AssemblyName System.Drawing
$bitmap=[Drawing.Bitmap]::new($source)
try {
 if($bitmap.Width -ne 1536 -or $bitmap.Height -ne 1024){throw 'Unexpected source dimensions'}
 $lock=$bitmap.LockBits([Drawing.Rectangle]::new(0,0,1536,1024),[Drawing.Imaging.ImageLockMode]::ReadOnly,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
 try {
  if($lock.Stride -ne 1536*4){throw 'Unexpected pixel stride'}
  $pixels=[byte[]]::new($lock.Stride*1024)
  [Runtime.InteropServices.Marshal]::Copy($lock.Scan0,$pixels,0,$pixels.Length)
  [IO.File]::WriteAllBytes((Join-Path $output 'approved.bgra'),$pixels)
 } finally {$bitmap.UnlockBits($lock)}
} finally {$bitmap.Dispose()}
& node (Join-Path $PSScriptRoot 'Build-Druid.cjs')
if($LASTEXITCODE -ne 0){throw 'Druid bake failed'}
