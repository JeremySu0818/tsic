# Double Score

## Goal

分數加倍技能讓技能期間所有加分與扣分都變成 2 倍。

## Default Spec

```text
duration: 8 seconds
+1 -> +2
+3 -> +6
+5 -> +10
-3 -> -6
-5 -> -10
```

## Patch

```powershell
git apply --ignore-whitespace .\skills\patches\double_score.patch
```

這個 patch 會新增：

```text
src/game/skill_double_score.v
```

並修改：

```text
src/game/game_ctrl.v
hdmi_coin.gprj
```

## Hook Points

Base branch 已經把分數拆成：

```verilog
score_delta
score_delta_eff
```

Patch apply 後會加入 `double_on`，並把有效分數變成：

```verilog
score_delta_eff = double_on ? score_delta <<< 1 : score_delta;
```

## Test Points

- base branch 沒有加倍效果
- apply patch 後，技能期間正分與負分都乘 2
- 扣分後分數仍不能低於 0
