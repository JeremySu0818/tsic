$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$RuntimeDir = Join-Path $PSScriptRoot "runtime"
$Simulator = Join-Path $PSScriptRoot "build\rtl_sim_fast.vvp"

& (Join-Path $PSScriptRoot "build.ps1") -Quiet
New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null
Get-ChildItem -LiteralPath $RuntimeDir -File -ErrorAction SilentlyContinue | Remove-Item -Force
[IO.File]::WriteAllText((Join-Path $RuntimeDir "io.txt"), "1 0 0 0 0 0 0`n")

Push-Location $ProjectRoot
try {
    & vvp $Simulator +MAX_FRAMES=1
    if ($LASTEXITCODE -ne 0) { throw "vvp failed with exit code $LASTEXITCODE" }
} finally {
    Pop-Location
}

$Frame = Get-Item (Join-Path $RuntimeDir "frame_00000000.hex")
$LineCount = @(Get-Content $Frame.FullName | Where-Object { -not $_.StartsWith("//") }).Count
if ($LineCount -ne 80 * 60) {
    throw "Bad frame length: $LineCount pixels"
}
if (-not (Test-Path (Join-Path $RuntimeDir "state_00000000.txt"))) {
    throw "State snapshot was not generated."
}
Write-Host "PASS: compiled real RTL and rendered one sampled 80x60 preview frame."
