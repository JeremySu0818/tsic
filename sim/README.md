# Tang Nano 4K RTL 開發板模擬器

這個模擬器直接執行專案的 `game_core` Verilog，不是另外重寫的遊戲。

## 執行

在專案根目錄執行：

```powershell
powershell -ExecutionPolicy Bypass -File .\sim\run.ps1
```

每次啟動會重新編譯 RTL；若剛編譯過，可加 `-NoBuild`。互動模式每個 8x8 區塊
取樣一個真實 RTL pixel，再以 nearest-neighbor 放大，因此每 frame 只需跑 4,800
個 pixel。若要逐 pixel 的 640x480 精確輸出，使用 `-Exact`（Icarus 會慢很多）：

```powershell
powershell -ExecutionPolicy Bypass -File .\sim\run.ps1 -Exact
```

需要安裝 Icarus Verilog，並讓 `iverilog.exe`、`vvp.exe` 位於 `PATH`。

## 模擬的 I/O

| 板端 I/O | 模擬器 |
|---|---|
| `btn_left` / pin 13 | A、左方向鍵、Left 按鈕 |
| `btn_right` / pin 17 | D、右方向鍵、Right 按鈕 |
| `btn_start` / pin 15 | Enter、Start 按鈕 |
| `btn_skill` / pin 16 | S、Skill 按鈕 |
| `btn_jump` / pin 18 | Space、Jump 按鈕 |
| `resetn` / pin 14 | R、Reset 按鈕 |
| HDMI TMDS output | 640×480 BGR888 視窗 |

畫面右側也會顯示從 RTL hierarchy 讀出的 frame、state、score、timer、玩家座標、
charge、skill、combo 與 difficulty，方便除錯。

## 模擬邊界

遊戲控制、物件生成、碰撞、技能、ROM、各 render layer 與完整 640×480 pixel
stream 都是真實 RTL。板載 PLL、OSER10、ELVDS_OBUF 與 TMDS 差動電氣訊號不在互動
視窗逐位元模擬；它們被替換為 HDMI 編碼前的像素接收器。這是日常修改遊戲邏輯與
畫面最快也最有用的邊界。需要驗證 TMDS encoder 時，仍可另寫針對
`svo_enc`/`svo_tmds` 的 waveform testbench。

## 自動檢查

```powershell
powershell -ExecutionPolicy Bypass -File .\sim\smoke-test.ps1
```

這會編譯 RTL、跑一個完整 frame，並檢查輸出是否正好為 `640*480*3` bytes。
