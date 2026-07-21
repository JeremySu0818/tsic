# Tang Nano 4K RTL 開發板模擬器

預設互動後端是原生 C++20／Win32 模擬器，以 60 FPS 直接繪製完整 640x480
framebuffer。它載入與 FPGA 相同的 `.mem` 圖像資產，並模擬目前所有按鍵、遊戲狀態、
物件、碰撞、技能、計分、timer 與 HDMI 畫面。

## 執行

在專案根目錄執行：

```powershell
powershell -ExecutionPolicy Bypass -File .\sim\run.ps1
```

每次啟動會以 `g++ -O3` 重新編譯 C++；若剛編譯過，可加 `-NoBuild`。視窗預設
1280x960、可任意縮放，按 `F11` 切換全螢幕。

如果要執行原本逐 pixel 的 RTL regression viewer，使用 `-Exact`（Icarus 會慢很多）：

```powershell
powershell -ExecutionPolicy Bypass -File .\sim\run.ps1 -Exact
```

原生後端需要 MSYS2 UCRT64 `g++`。只有 `-Exact` 模式需要 Icarus Verilog。

## 模擬的 I/O

| 板端 I/O | 模擬器 |
|---|---|
| `btn_left` / pin 13 | A、左方向鍵、Left 按鈕 |
| `btn_right` / pin 17 | D、右方向鍵、Right 按鈕 |
| `btn_start` / pin 15 | Enter、Start 按鈕 |
| `btn_skill` / pin 16 | S、Skill 按鈕 |
| `btn_jump` / pin 18 | Space、Jump 按鈕 |
| `resetn` / pin 14 | R、Reset 按鈕 |
| HDMI TMDS output | 可縮放／全螢幕的 640×480 BGR888 視窗 |

視窗標題會顯示 state、score、timer 與即時 FPS。

## 模擬邊界

原生後端是 game/render RTL 的 C++ 功能模型，因此不經過 Verilog event scheduler，
也不模擬 PLL、OSER10、ELVDS_OBUF 或 TMDS 差動電氣波形。修改 `.mem` 資產會直接反映；
修改 Verilog 邏輯時，請用 `-Exact` 或 `smoke-test.ps1` 做 RTL regression。

## 自動檢查

```powershell
powershell -ExecutionPolicy Bypass -File .\sim\native-test.ps1
powershell -ExecutionPolicy Bypass -File .\sim\smoke-test.ps1
```

`native-test.ps1` 會跑 600 張完整 640x480 frame 並報告速度；`smoke-test.ps1`
則保留作 Verilog RTL regression。
