#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstdint>
#include <memory>
#include <mutex>
#include <thread>
#include <vector>

#include "Vgame_core.h"
#include "verilated.h"

double sc_time_stamp() { return 0.0; }

namespace {
constexpr int WIDTH = 640;
constexpr int HEIGHT = 480;
constexpr int PIXELS = WIDTH * HEIGHT;
constexpr UINT FRAME_READY = WM_APP + 1;

std::atomic<bool> running{true};
std::atomic<bool> leftPressed{false};
std::atomic<bool> rightPressed{false};
std::atomic<bool> startPressed{false};
std::atomic<bool> skillPressed{false};
std::atomic<bool> jumpPressed{false};
std::atomic<bool> resetPressed{false};
std::atomic<double> simulationFps{0.0};

std::mutex frameMutex;
std::vector<uint32_t> publishedFrame(PIXELS, 0);
std::vector<uint32_t> paintFrame(PIXELS, 0);
HWND mainWindow = nullptr;
bool fullscreen = false;
WINDOWPLACEMENT savedPlacement{};

uint32_t toWindowsBgr(uint32_t rtlBgr) {
    // RTL is packed {B,G,R}; a 32-bit Windows DIB integer is 0x00RRGGBB.
    const uint32_t red = rtlBgr & 0xffu;
    const uint32_t green = (rtlBgr >> 8) & 0xffu;
    const uint32_t blue = (rtlBgr >> 16) & 0xffu;
    return (red << 16) | (green << 8) | blue;
}

void setInputs(Vgame_core& dut) {
    dut.btn_left = leftPressed.load(std::memory_order_relaxed);
    dut.btn_right = rightPressed.load(std::memory_order_relaxed);
    dut.btn_start = startPressed.load(std::memory_order_relaxed);
    dut.btn_skill = skillPressed.load(std::memory_order_relaxed);
    dut.btn_jump = jumpPressed.load(std::memory_order_relaxed);
    dut.resetn = !resetPressed.load(std::memory_order_relaxed);
    dut.out_axis_tready = 1;
}

void clockOnce(VerilatedContext& context, Vgame_core& dut) {
    dut.clk = 0;
    setInputs(dut);
    dut.eval();
    context.timeInc(1);
    dut.clk = 1;
    setInputs(dut);
    dut.eval();
    context.timeInc(1);
}

void simulationThread() {
    auto context = std::make_unique<VerilatedContext>();
    context->traceEverOn(false);
    auto dut = std::make_unique<Vgame_core>(context.get());
    std::vector<uint32_t> workingFrame(PIXELS, 0);
    int pixelIndex = 0;
    bool capturing = false;

    resetPressed.store(true);
    for (int i = 0; i < 16; ++i) clockOnce(*context, *dut);
    resetPressed.store(false);

    using clock = std::chrono::steady_clock;
    auto fpsStart = clock::now();
    int frameCount = 0;

    while (running.load(std::memory_order_relaxed) && !context->gotFinish()) {
        clockOnce(*context, *dut);

        if (dut->out_axis_tvalid && dut->out_axis_tready) {
            if (dut->out_axis_tuser & 1u) {
                pixelIndex = 0;
                capturing = true;
            }
            if (capturing && pixelIndex < PIXELS) {
                workingFrame[pixelIndex++] = toWindowsBgr(dut->out_axis_tdata);
                if (pixelIndex == PIXELS) {
                    {
                        std::lock_guard<std::mutex> lock(frameMutex);
                        publishedFrame.swap(workingFrame);
                    }
                    capturing = false;
                    ++frameCount;
                    PostMessage(mainWindow, FRAME_READY, 0, 0);

                    const auto now = clock::now();
                    const double elapsed = std::chrono::duration<double>(now - fpsStart).count();
                    if (elapsed >= 0.5) {
                        simulationFps.store(frameCount / elapsed, std::memory_order_relaxed);
                        frameCount = 0;
                        fpsStart = now;
                    }
                }
            }
        }
    }

    dut->final();
}

void toggleFullscreen(HWND hwnd) {
    const DWORD style = GetWindowLong(hwnd, GWL_STYLE);
    if (!fullscreen) {
        MONITORINFO monitor{};
        monitor.cbSize = sizeof(monitor);
        if (GetWindowPlacement(hwnd, &savedPlacement) &&
            GetMonitorInfo(MonitorFromWindow(hwnd, MONITOR_DEFAULTTOPRIMARY), &monitor)) {
            SetWindowLong(hwnd, GWL_STYLE, style & ~WS_OVERLAPPEDWINDOW);
            SetWindowPos(hwnd, HWND_TOP, monitor.rcMonitor.left, monitor.rcMonitor.top,
                         monitor.rcMonitor.right - monitor.rcMonitor.left,
                         monitor.rcMonitor.bottom - monitor.rcMonitor.top,
                         SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
            fullscreen = true;
        }
    } else {
        SetWindowLong(hwnd, GWL_STYLE, style | WS_OVERLAPPEDWINDOW);
        SetWindowPlacement(hwnd, &savedPlacement);
        SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                     SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);
        fullscreen = false;
    }
}

void releaseAllInputs() {
    leftPressed = false;
    rightPressed = false;
    startPressed = false;
    skillPressed = false;
    jumpPressed = false;
    resetPressed = false;
}

LRESULT CALLBACK windowProcedure(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) {
    switch (message) {
        case WM_KEYDOWN:
            if (wParam == VK_F11 && !(lParam & (1LL << 30))) toggleFullscreen(hwnd);
            else if (wParam == 'A' || wParam == VK_LEFT) leftPressed = true;
            else if (wParam == 'D' || wParam == VK_RIGHT) rightPressed = true;
            else if (wParam == VK_RETURN) startPressed = true;
            else if (wParam == 'S') skillPressed = true;
            else if (wParam == VK_SPACE || wParam == 'W' || wParam == VK_UP) jumpPressed = true;
            else if (wParam == 'R') resetPressed = true;
            return 0;
        case WM_KEYUP:
            if (wParam == 'A' || wParam == VK_LEFT) leftPressed = false;
            else if (wParam == 'D' || wParam == VK_RIGHT) rightPressed = false;
            else if (wParam == VK_RETURN) startPressed = false;
            else if (wParam == 'S') skillPressed = false;
            else if (wParam == VK_SPACE || wParam == 'W' || wParam == VK_UP) jumpPressed = false;
            else if (wParam == 'R') resetPressed = false;
            return 0;
        case WM_KILLFOCUS:
            releaseAllInputs();
            return 0;
        case FRAME_READY: {
            {
                std::lock_guard<std::mutex> lock(frameMutex);
                paintFrame = publishedFrame;
            }
            wchar_t title[160];
            swprintf_s(title, L"Tang Nano 4K Verilog Simulator | %.1f RTL FPS | F11 Fullscreen",
                       simulationFps.load(std::memory_order_relaxed));
            SetWindowTextW(hwnd, title);
            InvalidateRect(hwnd, nullptr, FALSE);
            return 0;
        }
        case WM_ERASEBKGND:
            return 1;
        case WM_PAINT: {
            PAINTSTRUCT paint{};
            HDC dc = BeginPaint(hwnd, &paint);
            RECT client{};
            GetClientRect(hwnd, &client);
            const int clientWidth = client.right - client.left;
            const int clientHeight = client.bottom - client.top;
            const double scale = std::min(clientWidth / static_cast<double>(WIDTH),
                                          clientHeight / static_cast<double>(HEIGHT));
            const int drawWidth = static_cast<int>(WIDTH * scale);
            const int drawHeight = static_cast<int>(HEIGHT * scale);
            const int drawX = (clientWidth - drawWidth) / 2;
            const int drawY = (clientHeight - drawHeight) / 2;

            PatBlt(dc, 0, 0, clientWidth, clientHeight, BLACKNESS);
            BITMAPINFO bitmap{};
            bitmap.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
            bitmap.bmiHeader.biWidth = WIDTH;
            bitmap.bmiHeader.biHeight = -HEIGHT;
            bitmap.bmiHeader.biPlanes = 1;
            bitmap.bmiHeader.biBitCount = 32;
            bitmap.bmiHeader.biCompression = BI_RGB;
            SetStretchBltMode(dc, COLORONCOLOR);
            StretchDIBits(dc, drawX, drawY, drawWidth, drawHeight,
                          0, 0, WIDTH, HEIGHT, paintFrame.data(), &bitmap,
                          DIB_RGB_COLORS, SRCCOPY);
            EndPaint(hwnd, &paint);
            return 0;
        }
        case WM_DESTROY:
            running = false;
            PostQuitMessage(0);
            return 0;
    }
    return DefWindowProcW(hwnd, message, wParam, lParam);
}
}  // namespace

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int showCommand) {
    savedPlacement.length = sizeof(savedPlacement);

    constexpr wchar_t windowClass[] = L"TangNanoVerilatedWindow";
    WNDCLASSW definition{};
    definition.lpfnWndProc = windowProcedure;
    definition.hInstance = instance;
    definition.lpszClassName = windowClass;
    definition.hCursor = LoadCursor(nullptr, IDC_ARROW);
    definition.hbrBackground = static_cast<HBRUSH>(GetStockObject(BLACK_BRUSH));
    if (!RegisterClassW(&definition)) return 1;

    RECT requested{0, 0, 1280, 960};
    AdjustWindowRect(&requested, WS_OVERLAPPEDWINDOW, FALSE);
    mainWindow = CreateWindowExW(0, windowClass, L"Tang Nano 4K Verilog Simulator",
                                 WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT,
                                 requested.right - requested.left,
                                 requested.bottom - requested.top,
                                 nullptr, nullptr, instance, nullptr);
    if (!mainWindow) return 1;

    ShowWindow(mainWindow, showCommand);
    UpdateWindow(mainWindow);
    std::thread simulator(simulationThread);

    MSG message{};
    while (GetMessage(&message, nullptr, 0, 0) > 0) {
        TranslateMessage(&message);
        DispatchMessage(&message);
    }

    running = false;
    simulator.join();
    return 0;
}
