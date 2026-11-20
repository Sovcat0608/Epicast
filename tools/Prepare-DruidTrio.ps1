$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$source=Join-Path $root 'concepts\druid-specialization-trio\Druid-specializations-review-v8.png'
if((Get-FileHash -LiteralPath $source).Hash -ne '4D592A779782DD20FA9B0BCBD38CE7B018613397EA53A53E0ABC77E4C76CBFC8'){throw 'Approved trio source changed'}
$output=Join-Path $root 'artifacts\druid-trio-v8'
New-Item -ItemType Directory -Force -Path $output | Out-Null
Add-Type -AssemblyName System.Drawing
function Export-Bgra($imagePath,$width,$height,$file) {
$bitmap=[Drawing.Bitmap]::new($imagePath)
try {
 if($bitmap.Width -ne $width -or $bitmap.Height -ne $height){throw 'Unexpected source dimensions'}
 $lock=$bitmap.LockBits([Drawing.Rectangle]::new(0,0,$width,$height),[Drawing.Imaging.ImageLockMode]::ReadOnly,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
 try {
  if($lock.Stride -ne $width*4){throw 'Unexpected pixel stride'}
  $pixels=[byte[]]::new($lock.Stride*$height)
  [Runtime.InteropServices.Marshal]::Copy($lock.Scan0,$pixels,0,$pixels.Length)
  [IO.File]::WriteAllBytes((Join-Path $output $file),$pixels)
 } finally {$bitmap.UnlockBits($lock)}
} finally {$bitmap.Dispose()}
}
Export-Bgra $source 1882 836 'approved.bgra'
$restoration=Join-Path $root 'concepts/restoration-autumn-treant/Restoration registered.png'
Export-Bgra $restoration 660 880 'preferred-restoration.bgra'
