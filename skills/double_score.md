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

這個 patch 會修改：

```text
src/game/game_ctrl.v
```

## Common Slot

Base project 已經有共用 `skill_slot`，負責 skill 啟動、charge 檢查、timer 倒數與 `skill_on`。

Patch 只會把 `SKILL_ENABLE` 改成 1、設定 `SKILL_DURATION`，並使用 `skill_on` 改分數。

## Effect Hook

Base branch 直接使用：

```verilog
score_delta
```

Patch apply 後會新增 `score_delta_eff`，再用它更新分數：

```verilog
score_delta_eff = skill_on ? score_delta <<< 1 : score_delta;
```

## Test Points

- base branch 沒有加倍效果
- apply patch 後，技能期間正分與負分都乘 2
- 扣分後分數仍不能低於 0
