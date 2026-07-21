$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BuildDir = Join-Path $PSScriptRoot "build\verilated"
$Harness = Join-Path $PSScriptRoot "verilator\main.cpp"
$Executable = Join-Path $BuildDir "coin_simulator.exe"
$ToolBin = "C:\msys64\ucrt64\bin"
$Verilator = Join-Path $ToolBin "verilator_bin.exe"

if (-not (Test-Path $Verilator)) {
    throw "Verilator was not found at $Verilator. Install mingw-w64-ucrt-x86_64-verilator."
}

$env:PATH = $ToolBin + ";C:\msys64\usr\bin;" + $env:PATH
$env:VERILATOR_ROOT = "C:/msys64/ucrt64/share/verilator"
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

$Sources = @(
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

$VerilatorArgs = @(
    "--cc",
    "--exe",
    "--build",
    "-j", "0",
    "-O3",
    "-Wno-fatal",
    "--top-module", "game_core",
    "--Mdir", ($BuildDir -replace "\\", "/"),
    "-Isrc",
    "-CFLAGS", "-O3 -DNDEBUG -std=c++20",
    "-LDFLAGS", "-municode -mwindows -static -lgdi32 -luser32",
    "-o", "coin_simulator.exe"
) + $Sources + @($Harness)

Push-Location $ProjectRoot
try {
    & $Verilator @VerilatorArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Verilator build failed (exit code $LASTEXITCODE)."
    }
} finally {
    Pop-Location
}

if (-not (Test-Path $Executable)) {
    throw "Verilator finished but the simulator executable was not created: $Executable"
}

Write-Host "Launching Verilog simulator: $Executable"
$SimulatorProcess = Start-Process -FilePath $Executable -WorkingDirectory $ProjectRoot -PassThru -Wait
if ($SimulatorProcess.ExitCode -ne 0) {
    throw "Simulator exited with code $($SimulatorProcess.ExitCode)."
}
