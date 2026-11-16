$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Add-Type -AssemblyName System.Drawing
$sheet=[Drawing.Bitmap]::new(1060,370,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g=[Drawing.Graphics]::FromImage($sheet)
try {
 $g.Clear([Drawing.Color]::FromArgb(255,24,28,38))
 $g.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
 $index=0
 foreach($spec in @('Frost','Fire','Arcane')) {
  $bytes=[IO.File]::ReadAllBytes((Join-Path $root "Media\MageReboot${spec}CASSize384.tga"))
  $w=[BitConverter]::ToUInt16($bytes,12);$h=[BitConverter]::ToUInt16($bytes,14)
  $bitmap=[Drawing.Bitmap]::new($w,$h,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
  try {
   $lock=$bitmap.LockBits([Drawing.Rectangle]::new(0,0,$w,$h),[Drawing.Imaging.ImageLockMode]::WriteOnly,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
   try {if($lock.Stride -ne $w*4){throw 'Unexpected stride'};[Runtime.InteropServices.Marshal]::Copy($bytes,18,$lock.Scan0,$w*$h*4)}finally{$bitmap.UnlockBits($lock)}
   $g.DrawImage($bitmap,[Drawing.Rectangle]::new(30+$index*340,25,304,304),0,0,384,384,[Drawing.GraphicsUnit]::Pixel)
  }finally{$bitmap.Dispose()}
  $index++
 }
 $sheet.Save((Join-Path $root 'artifacts\mage-reboot-option1\runtime-preview.png'),[Drawing.Imaging.ImageFormat]::Png)
}finally{$g.Dispose();$sheet.Dispose()}
