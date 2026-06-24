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

這個 patch 會修改：

```text
src/game/game_ctrl.v
```

## Common Slot

Base project 已經有共用 `skill_slot`，負責 skill 啟動、charge 檢查、timer 倒數與 `skill_on`。

Patch 只會把 `SKILL_ENABLE` 改成 1、設定 `SKILL_DURATION`，並使用 `skill_on` 改 spawn period。

## Effect Hook

Base branch 直接使用：

```verilog
spawn_period
```

Patch apply 後會新增 `spawn_period_eff`，再讓 spawn counter reload 使用它：

```verilog
spawn_period_eff = skill_on ? STAR_SPAWN_PERIOD : spawn_period;
```

## Test Points

- base branch 每 24 frame 生成一次
- apply patch 後，技能期間每 8 frame 生成一次
- 場上物件仍最多 16 個
