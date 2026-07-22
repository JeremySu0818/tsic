# Tang Nano 4K Verilator simulator

There is one simulator path:

```text
VS Code task: simulate
  -> sim/run.ps1
  -> Verilator compiles the current Verilog sources to C++
  -> MinGW builds coin_simulator.exe
  -> the Win32 window displays the RTL BGR888 pixel stream
```

Run it from the project root:

```powershell
powershell -ExecutionPolicy Bypass -File .\sim\run.ps1
```

Controls:

- `Enter`: start or pause
- `A` / `D`, or left / right arrows: move
- `Space`, `W`, or up arrow: jump
- `S`: skill
- `R`: hold RTL reset
- `F11`: fullscreen

The window is a resizable 640x480 display. Game state, LFSRs, FIFOs, collision,
ROM reads, skills, and every render layer execute from the current Verilog.
The C++ harness does not contain a second implementation of the game.

For a repeatable performance measurement using the same DUT:

```powershell
powershell -ExecutionPolicy Bypass -File .\sim\run.ps1 -Benchmark
```

The benchmark enters the playing state and renders 32 complete RTL frames, so
the result includes object spawning rather than measuring only process startup.

The interactive display taps `game_core` before the physical-only PLL, OSER10,
ELVDS output buffers, and TMDS cable. Those blocks transport pixels to HDMI but
do not change the game framebuffer.
