# Magnet

## Goal

磁鐵技能讓玩家更容易接到物件。它不改玩家顯示大小，只放大 `game_ctrl` 內部的碰撞範圍。

## Default Spec

```text
duration: 15 seconds
hitbox: player left/right each +16 pixels
```

## Patch

```powershell
git apply --ignore-whitespace .\skills\patches\magnet.patch
```

這個 patch 會新增：

```text
src/game/skill_magnet.v
```

並修改：

```text
src/game/game_ctrl.v
hdmi_coin.gprj
```

## Hook Points

Base branch 已經保留：

```verilog
hit_player_l
hit_player_r
hit_player_t
hit_player_b
```

Patch apply 後會加入 `magnet_on`，並把左右碰撞範圍改寬：

```verilog
hit_player_l = magnet_on ? player_x - MAGNET_PAD : player_x;
hit_player_r = magnet_on ? player_x + PLAYER_WIDTH + MAGNET_PAD
                         : player_x + PLAYER_WIDTH;
```

## Test Points

- base branch 沒有磁鐵效果
- apply patch 後，按下 skill 且 charge 滿格才啟動
- 技能期間玩家 sprite 顯示大小不變
- 技能期間碰撞範圍變寬
