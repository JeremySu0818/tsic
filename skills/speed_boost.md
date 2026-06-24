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

這個 patch 會新增：

```text
src/game/skill_speed_boost.v
```

並修改：

```text
src/game/game_ctrl.v
hdmi_coin.gprj
```

## Hook Points

Base branch 已經讓移動使用：

```verilog
player_speed_eff
```

Patch apply 後會加入 `speed_on`，並把有效速度改成：

```verilog
player_speed_eff = speed_on ? SPEED_BOOST_VALUE : player_speed;
```

## Test Points

- base branch 速度固定為 `player_speed`
- apply patch 後，技能期間速度變快
- 玩家仍不能超出左右邊界
