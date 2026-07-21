param(
    [switch]$NoBuild,
    [switch]$Exact
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;

public static class RtlFrameLoader {
    public static Bitmap Load(string path, int sourceWidth, int sourceHeight, int scale) {
        int outputWidth = sourceWidth * scale;
        int outputHeight = sourceHeight * scale;
        byte[] pixels = new byte[outputWidth * outputHeight * 3];
        using (var reader = new StreamReader(path)) {
          for (int y = 0; y < sourceHeight; y++) {
            for (int x = 0; x < sourceWidth; x++) {
                string line;
                do { line = reader.ReadLine(); }
                while (line != null && line.StartsWith("//"));
                if (line == null) throw new InvalidDataException("Incomplete RTL frame");
                uint bgr = uint.Parse(line, NumberStyles.HexNumber, CultureInfo.InvariantCulture);
                for (int dy = 0; dy < scale; dy++) {
                  for (int dx = 0; dx < scale; dx++) {
                    int p = ((y * scale + dy) * outputWidth + x * scale + dx) * 3;
                    pixels[p] = (byte)(bgr >> 16);
                    pixels[p + 1] = (byte)(bgr >> 8);
                    pixels[p + 2] = (byte)bgr;
                  }
                }
            }
          }
        }
        var bitmap = new Bitmap(outputWidth, outputHeight, PixelFormat.Format24bppRgb);
        var data = bitmap.LockBits(new Rectangle(0, 0, outputWidth, outputHeight),
            ImageLockMode.WriteOnly, PixelFormat.Format24bppRgb);
        try { Marshal.Copy(pixels, 0, data.Scan0, pixels.Length); }
        finally { bitmap.UnlockBits(data); }
        return bitmap;
    }
}
"@

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$RuntimeDir = Join-Path $PSScriptRoot "runtime"
$SimulatorName = if ($Exact) { "rtl_sim_exact.vvp" } else { "rtl_sim_fast.vvp" }
$Simulator = Join-Path $PSScriptRoot ("build\" + $SimulatorName)
$FrameWidth = if ($Exact) { 640 } else { 80 }
$FrameHeight = if ($Exact) { 480 } else { 60 }
$FrameScale = if ($Exact) { 1 } else { 8 }

if (-not $NoBuild -or -not (Test-Path $Simulator)) {
    & (Join-Path $PSScriptRoot "build.ps1") -Quiet -Exact:$Exact
}
if (-not (Get-Command vvp -ErrorAction SilentlyContinue)) {
    throw "vvp was not found. Add Icarus Verilog to PATH."
}

New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null
Get-ChildItem -LiteralPath $RuntimeDir -File -ErrorAction SilentlyContinue | Remove-Item -Force

$script:CurrentFrame = -1
$script:Held = @{ left = $false; right = $false }
$script:PulseUntil = @{ reset = -1; start = -1; skill = -1; jump = -1 }
$script:Quit = $false

function Write-BoardIo {
    $resetn = if ($script:PulseUntil.reset -gt $script:CurrentFrame) { 0 } else { 1 }
    $left = if ($script:Held.left) { 1 } else { 0 }
    $right = if ($script:Held.right) { 1 } else { 0 }
    $start = if ($script:PulseUntil.start -gt $script:CurrentFrame) { 1 } else { 0 }
    $skill = if ($script:PulseUntil.skill -gt $script:CurrentFrame) { 1 } else { 0 }
    $jump = if ($script:PulseUntil.jump -gt $script:CurrentFrame) { 1 } else { 0 }
    $quit = if ($script:Quit) { 1 } else { 0 }
    $temp = Join-Path $RuntimeDir "io.tmp"
    $target = Join-Path $RuntimeDir "io.txt"
    [IO.File]::WriteAllText($temp, "$resetn $left $right $start $skill $jump $quit`n")
    Move-Item -LiteralPath $temp -Destination $target -Force
}

function Invoke-Pulse([string]$Name) {
    $script:PulseUntil[$Name] = $script:CurrentFrame + 1
    Write-BoardIo
}

Write-BoardIo
$Process = Start-Process -FilePath (Get-Command vvp).Source `
    -ArgumentList @($Simulator) -WorkingDirectory $ProjectRoot `
    -WindowStyle Hidden -PassThru

$Form = New-Object Windows.Forms.Form
$Form.Text = "Tang Nano 4K RTL Board Simulator"
$Form.ClientSize = New-Object Drawing.Size 920, 520
$Form.StartPosition = "CenterScreen"
$Form.KeyPreview = $true
$Form.BackColor = [Drawing.Color]::FromArgb(28, 30, 36)

$Screen = New-Object Windows.Forms.PictureBox
$Screen.Location = New-Object Drawing.Point 16, 16
$Screen.Size = New-Object Drawing.Size 640, 480
$Screen.BorderStyle = "FixedSingle"
$Screen.BackColor = [Drawing.Color]::Black
$Form.Controls.Add($Screen)

$Title = New-Object Windows.Forms.Label
$Title.Text = "BOARD I/O"
$Title.ForeColor = [Drawing.Color]::White
$Title.Font = New-Object Drawing.Font("Segoe UI", 14, [Drawing.FontStyle]::Bold)
$Title.Location = New-Object Drawing.Point 680, 18
$Title.AutoSize = $true
$Form.Controls.Add($Title)

$Status = New-Object Windows.Forms.Label
$Status.Text = "Waiting for the first RTL frame..."
$Status.ForeColor = [Drawing.Color]::Gainsboro
$Status.Font = New-Object Drawing.Font("Consolas", 10)
$Status.Location = New-Object Drawing.Point 680, 58
$Status.Size = New-Object Drawing.Size 225, 190
$Form.Controls.Add($Status)

function Add-Button([string]$Text, [int]$X, [int]$Y, [scriptblock]$Click) {
    $button = New-Object Windows.Forms.Button
    $button.Text = $Text
    $button.Location = New-Object Drawing.Point $X, $Y
    $button.Size = New-Object Drawing.Size 105, 42
    $button.FlatStyle = "Flat"
    $button.ForeColor = [Drawing.Color]::White
    $button.BackColor = [Drawing.Color]::FromArgb(55, 60, 72)
    $button.Add_Click($Click)
    $Form.Controls.Add($button)
    return $button
}

$LeftButton = Add-Button "< Left (A)" 680 260 {}
$LeftButton.Tag = "left"
$LeftButton.Add_MouseDown({ $script:Held.left = $true; Write-BoardIo })
$LeftButton.Add_MouseUp({ $script:Held.left = $false; Write-BoardIo })
$RightButton = Add-Button "Right (D) >" 795 260 {}
$RightButton.Add_MouseDown({ $script:Held.right = $true; Write-BoardIo })
$RightButton.Add_MouseUp({ $script:Held.right = $false; Write-BoardIo })
Add-Button "Start (Enter)" 680 316 { Invoke-Pulse "start" } | Out-Null
Add-Button "Skill (S)" 795 316 { Invoke-Pulse "skill" } | Out-Null
Add-Button "Jump (Space)" 680 372 { Invoke-Pulse "jump" } | Out-Null
Add-Button "Reset (R)" 795 372 { Invoke-Pulse "reset" } | Out-Null

$Hint = New-Object Windows.Forms.Label
$Hint.Text = "Hold A/D or arrow keys to move`nEnter start/pause - Space jump`nS skill - R reset"
$Hint.ForeColor = [Drawing.Color]::DarkGray
$Hint.Location = New-Object Drawing.Point 680, 438
$Hint.Size = New-Object Drawing.Size 230, 62
$Form.Controls.Add($Hint)

$Form.Add_KeyDown({
    param($sender, $event)
    switch ($event.KeyCode) {
        "A"     { $script:Held.left = $true; Write-BoardIo }
        "Left"  { $script:Held.left = $true; Write-BoardIo }
        "D"     { $script:Held.right = $true; Write-BoardIo }
        "Right" { $script:Held.right = $true; Write-BoardIo }
        "Enter" { Invoke-Pulse "start" }
        "S"     { Invoke-Pulse "skill" }
        "Space" { Invoke-Pulse "jump" }
        "R"     { Invoke-Pulse "reset" }
    }
    $event.SuppressKeyPress = $true
})
$Form.Add_KeyUp({
    param($sender, $event)
    switch ($event.KeyCode) {
        "A"     { $script:Held.left = $false; Write-BoardIo }
        "Left"  { $script:Held.left = $false; Write-BoardIo }
        "D"     { $script:Held.right = $false; Write-BoardIo }
        "Right" { $script:Held.right = $false; Write-BoardIo }
    }
})

$Timer = New-Object Windows.Forms.Timer
$Timer.Interval = 100
$Timer.Add_Tick({
    $frames = @(Get-ChildItem -LiteralPath $RuntimeDir -Filter "frame_*.hex" -File -ErrorAction SilentlyContinue |
        Sort-Object Name)
    if ($frames.Count -eq 0) { return }
    $latest = $frames[-1]
    if ($latest.BaseName -notmatch 'frame_(\d+)') { return }
    $number = [int]$Matches[1]
    if ($number -le $script:CurrentFrame) { return }

    try { $bitmap = [RtlFrameLoader]::Load($latest.FullName, $FrameWidth, $FrameHeight, $FrameScale) }
    catch { return }
    if ($null -eq $bitmap) { return }
    $old = $Screen.Image
    $Screen.Image = $bitmap
    if ($null -ne $old) { $old.Dispose() }
    $script:CurrentFrame = $number

    foreach ($key in @("reset", "start", "skill", "jump")) {
        if ($script:PulseUntil[$key] -le $script:CurrentFrame) {
            $script:PulseUntil[$key] = -1
        }
    }
    Write-BoardIo

    $statePath = Join-Path $RuntimeDir ("state_{0:D8}.txt" -f $number)
    if (Test-Path $statePath) {
        $values = @{}
        foreach ($line in Get-Content $statePath) {
            if ($line -match '^([^=]+)=(.*)$') { $values[$Matches[1]] = $Matches[2] }
        }
        $names = @("TITLE", "PLAYING", "GAME OVER", "PAUSED")
        $stateName = $names[[int]$values.state]
        $Status.Text = "Frame      $number`nState      $stateName`nScore      $($values.score)`nTimer      $($values.timer)`nPlayer     ($($values.player_x), $($values.player_y))`nCharge     $($values.charge)`nSkill      $($values.skill_on) / $($values.skill_timer)s`nCombo      $($values.combo)`nDifficulty $($values.difficulty)"
    }

    foreach ($file in $frames) {
        if ($file.FullName -ne $latest.FullName) { Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue }
    }
    Get-ChildItem -LiteralPath $RuntimeDir -Filter "state_*.txt" -File -ErrorAction SilentlyContinue |
        Where-Object BaseName -ne ("state_{0:D8}" -f $number) |
        Remove-Item -Force -ErrorAction SilentlyContinue
})
$Timer.Start()

$Form.Add_FormClosed({
    $Timer.Stop()
    $script:Quit = $true
    Write-BoardIo
    if (-not $Process.HasExited) {
        if (-not $Process.WaitForExit(1500)) { Stop-Process -Id $Process.Id -Force }
    }
    if ($null -ne $Screen.Image) { $Screen.Image.Dispose() }
})

[void]$Form.ShowDialog()
