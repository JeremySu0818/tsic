# Speed Boost

## Goal

加跑速技能讓玩家技能期間左右移動速度變快。

## Default Spec

```text
duration: 12 seconds
normal speed: 8 px/frame
boost speed: 12 px/frame
```

## Patch

```powershell
git apply --ignore-whitespace .\skills\patches\speed_boost.patch
```

這個 patch 會修改：

```text
src/game/game_ctrl.v
```

## Common Slot

Base project 已經有共用 `skill_slot`，負責 skill 啟動、charge 檢查、timer 倒數與 `skill_on`。

Patch 只會把 `SKILL_ENABLE` 改成 1、設定 `SKILL_DURATION`，並使用 `skill_on` 改移動速度。

## Effect Hook

Base branch 直接使用：

```verilog
player_speed
```

Patch apply 後會新增 `player_speed_eff`，再讓移動判斷和位置更新使用它：

```verilog
player_speed_eff = skill_on ? SPEED_BOOST_VALUE : player_speed;
```

## Test Points

- base branch 速度固定為 `player_speed`
- apply patch 後，技能期間速度變快
- 玩家仍不能超出左右邊界
