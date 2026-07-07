param(
    [string]$InputDir = "png",
    [string]$OutputDir = "src\assets",
    # basenames stored as RGB323 (8-bit) instead of RGB565 (16-bit)
    [string[]]$Sprites8bit = @("player_right_32", "player_skill_32"),
    # Target sprite box size (N x N) is taken from the trailing "_<N>" in the
    # base name (e.g. obj_plus1_16 -> 16, player_right_32 -> 32); any-size source
    # art is scaled to fit (aspect-preserved, transparent pad). This map is an
    # override for bases that have no size suffix (e.g. background).
    [hashtable]$FitSize = @{ "background" = 32 }
)

Add-Type -AssemblyName System.Drawing

$ROOT = Split-Path -Parent $PSScriptRoot

function Resolve-LocalPath {
    param([string]$PathValue)
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return $PathValue
    }
    return Join-Path $ROOT $PathValue
}

$InputPath = Resolve-LocalPath $InputDir
$OutputPath = Resolve-LocalPath $OutputDir

if (!(Test-Path $InputPath -PathType Container)) {
    throw "Input folder not found: $InputPath"
}

New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null

$pngFiles = Get-ChildItem -Path $InputPath -Filter "*.png" -File | Sort-Object Name

if ($pngFiles.Count -eq 0) {
    throw "No .png files found in: $InputPath"
}

# Scale a bitmap to fit an N x N box, keeping aspect ratio, centered, with a
# transparent background (32bpp ARGB, high-quality downscale).
function Fit-Bitmap {
    param($src, [int]$n)
    $dst = New-Object System.Drawing.Bitmap($n, $n, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($dst)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    $scale = [Math]::Min($n / $src.Width, $n / $src.Height)
    $w = [int][Math]::Round($src.Width * $scale)
    $h = [int][Math]::Round($src.Height * $scale)
    if ($w -lt 1) { $w = 1 }
    if ($h -lt 1) { $h = 1 }
    $ox = [int](($n - $w) / 2)
    $oy = [int](($n - $h) / 2)
    $g.DrawImage($src, $ox, $oy, $w, $h)
    $g.Dispose()
    return $dst
}

# Target N x N box for a base: explicit override, else trailing "_<N>", else 0 (none).
function Get-TargetSize {
    param([string]$base)
    if ($FitSize.ContainsKey($base)) { return [int]$FitSize[$base] }
    if ($base -match '_(\d+)$') { return [int]$Matches[1] }
    return 0
}

# Load a sprite bitmap for the given base, scaling to fit its target box if any.
function Load-Sprite {
    param([string]$path, [string]$base)
    $bmp = [System.Drawing.Bitmap]::new($path)
    $n = Get-TargetSize $base
    if ($n -gt 0 -and ($bmp.Width -ne $n -or $bmp.Height -ne $n)) {
        $fitted = Fit-Bitmap $bmp $n
        $bmp.Dispose()
        return $fitted
    }
    return $bmp
}

# Write one bitmap's pixels (row-major) to an open StreamWriter.
function Write-Pixels {
    param($bmp, $writer, [bool]$use8bit)
    for ($y = 0; $y -lt $bmp.Height; $y++) {
        for ($x = 0; $x -lt $bmp.Width; $x++) {
            $color = $bmp.GetPixel($x, $y)
            if ($use8bit) {
                # RGB323: transparency comes ONLY from PNG alpha; an opaque pixel
                # never emits the 0x00 sentinel (near-black is bumped to 0x01).
                if ([int]$color.A -eq 0) {
                    $writer.WriteLine("00")
                }
                else {
                    $r = [int]$color.R; $g = [int]$color.G; $b = [int]$color.B
                    $val8 = (($r -shr 5) -shl 5) -bor (($g -shr 6) -shl 3) -bor ($b -shr 5)
                    if ($val8 -eq 0) { $val8 = 1 }
                    $writer.WriteLine("{0:X2}" -f $val8)
                }
            }
            else {
                # RGB565: original behaviour. Some sprites use OPAQUE BLACK as the
                # color-key transparent background, so black must stay 0x0000.
                $r = [int]$color.R; $g = [int]$color.G; $b = [int]$color.B
                if ([int]$color.A -eq 0) { $r = 0; $g = 0; $b = 0 }
                $val16 = (($r -shr 3) -shl 11) -bor (($g -shr 2) -shl 5) -bor ($b -shr 3)
                $writer.WriteLine("{0:X4}" -f $val16)
            }
        }
    }
}

# Classify: "<base>.<N>" is frame N of animation group <base>; else standalone.
$groups = @{}
$singles = @()
foreach ($png in $pngFiles) {
    if ($png.BaseName -match '^(.+)\.(\d+)$') {
        $base = $Matches[1]
        $idx = [int]$Matches[2]
        if (-not $groups.ContainsKey($base)) { $groups[$base] = @() }
        $groups[$base] += [pscustomobject]@{ Idx = $idx; File = $png }
    }
    else {
        $singles += $png
    }
}

$convertedCount = 0

foreach ($png in $singles) {
    $base = $png.BaseName
    $use8bit = $Sprites8bit -contains $base
    if ($use8bit) { $fmt = "RGB323" } else { $fmt = "RGB565" }
    $memPath = Join-Path $OutputPath ($base + ".mem")
    $bmp = Load-Sprite $png.FullName $base
    $w = $bmp.Width; $h = $bmp.Height
    $writer = [System.IO.StreamWriter]::new($memPath, $false, [System.Text.Encoding]::ASCII)
    try {
        Write-Pixels $bmp $writer $use8bit
    }
    finally {
        $writer.Dispose()
        $bmp.Dispose()
    }
    $convertedCount++
    Write-Host "$($png.Name) -> $base.mem ($w x $h, $fmt)"
}

foreach ($base in ($groups.Keys | Sort-Object)) {
    $frames = $groups[$base] | Sort-Object Idx
    $use8bit = $Sprites8bit -contains $base
    if ($use8bit) { $fmt = "RGB323" } else { $fmt = "RGB565" }
    $memPath = Join-Path $OutputPath ($base + ".mem")
    $writer = [System.IO.StreamWriter]::new($memPath, $false, [System.Text.Encoding]::ASCII)
    try {
        foreach ($fr in $frames) {
            $bmp = Load-Sprite $fr.File.FullName $base
            try { Write-Pixels $bmp $writer $use8bit }
            finally { $bmp.Dispose() }
        }
    }
    finally {
        $writer.Dispose()
    }
    $convertedCount++
    Write-Host "$base.{$(($frames | ForEach-Object { $_.Idx }) -join ',')} -> $base.mem ($($frames.Count) frames, $fmt)"
}

Write-Host "Converted $convertedCount item(s)."
Write-Host "Input dir : $InputPath"
Write-Host "Output dir: $OutputPath"
