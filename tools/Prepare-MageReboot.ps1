$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$source=Join-Path $root 'concepts\mage-reboot\Mage-reboot-trio-v3-initial.png'
if((Get-FileHash -LiteralPath $source).Hash -ne '5DD9D15C1D72C67EFB83DFA664E235E450B36C8B8C1C3BBC7CC017B2A2D3F5AC'){throw 'Approved option 1 source changed'}
$output=Join-Path $root 'artifacts\mage-reboot-option1'
New-Item -ItemType Directory -Force -Path $output | Out-Null
Add-Type -AssemblyName System.Drawing
$bitmap=[Drawing.Bitmap]::new($source)
try {
 if($bitmap.Width -ne 2172 -or $bitmap.Height -ne 724){throw 'Unexpected source dimensions'}
 $lock=$bitmap.LockBits([Drawing.Rectangle]::new(0,0,2172,724),[Drawing.Imaging.ImageLockMode]::ReadOnly,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
 try {
  if($lock.Stride -ne 2172*4){throw 'Unexpected pixel stride'}
  $pixels=[byte[]]::new($lock.Stride*724)
  [Runtime.InteropServices.Marshal]::Copy($lock.Scan0,$pixels,0,$pixels.Length)
  [IO.File]::WriteAllBytes((Join-Path $output 'approved.bgra'),$pixels)
 } finally {$bitmap.UnlockBits($lock)}
} finally {$bitmap.Dispose()}
