param(
    [switch]$Quiet,
    [switch]$Exact
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BuildDir = Join-Path $PSScriptRoot "build"
$OutputName = if ($Exact) { "rtl_sim_exact.vvp" } else { "rtl_sim_fast.vvp" }
$Output = Join-Path $BuildDir $OutputName

if (-not (Get-Command iverilog -ErrorAction SilentlyContinue)) {
    throw "iverilog was not found. Install Icarus Verilog and add it to PATH."
}

New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

$Sources = @(
    "sim/rtl_sim_tb.v",
    "src/common/bin2bcd.v",
    "src/common/fifo.v",
    "src/common/lfsr32.v",
    "src/common/rom.v",
    "src/game/game_core.v",
    "src/game/game_ctrl.v",
    "src/game/skill_slot.v",
    "src/game/spawn_postprocess.v",
    "src/game/spawn_queue.v",
    "src/overlay/bg_layer.v",
    "src/overlay/obj_layer.v",
    "src/overlay/ui_layer.v",
    "src/overlay/res_overlay.v"
)

Push-Location $ProjectRoot
try {
    $CompilerArgs = @("-g2012", "-Wall", "-Isrc")
    if (-not $Exact) { $CompilerArgs += "-DRTL_SIM_FAST" }
    $CompilerArgs += @("-s", "rtl_sim_tb", "-o", $Output)
    & iverilog @CompilerArgs @Sources
    if ($LASTEXITCODE -ne 0) {
        throw "RTL simulator build failed (iverilog exit code $LASTEXITCODE)."
    }
} finally {
    Pop-Location
}

if (-not $Quiet) {
    Write-Host "Simulator built: $Output"
}
