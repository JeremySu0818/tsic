# Star Rain

## Goal

滿天星技能讓物件生成速度變快，畫面變得更密集。

## Default Spec

```text
duration: 6 seconds
normal spawn period: 24 frames
skill spawn period: 8 frames
maximum active objects: still 16
```

## Patch

```powershell
git apply --ignore-whitespace .\skills\patches\star_rain.patch
```

這個 patch 會新增：

```text
src/game/skill_star_rain.v
```

並修改：

```text
src/game/game_ctrl.v
hdmi_coin.gprj
```

## Hook Points

Base branch 已經讓 spawn counter 使用：

```verilog
spawn_period_eff
```

Patch apply 後會加入 `star_on`，並把有效生成週期改短：

```verilog
spawn_period_eff = star_on ? STAR_SPAWN_PERIOD : spawn_period;
```

## Test Points

- base branch 每 24 frame 生成一次
- apply patch 後，技能期間每 8 frame 生成一次
- 場上物件仍最多 16 個
