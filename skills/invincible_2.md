# Invincible 2

## Goal

無敵 2 是強化防禦技能。技能期間負分物件會反過來變成加分。

## Default Spec

```text
duration: 6 seconds
-3 -> +3
-5 -> +5
```

## Patch

```powershell
git apply --ignore-whitespace .\skills\patches\invincible_2.patch
```

這個 patch 會修改：

```text
src/game/game_ctrl.v
```

## Common Slot

Base project 已經有共用 `skill_slot`，負責 skill 啟動、charge 檢查、timer 倒數與 `skill_on`。

Patch 只會把 `SKILL_ENABLE` 改成 1、設定 `SKILL_DURATION`，並使用 `skill_on` 改負分處理。

## Effect Hook

Base branch 直接使用：

```verilog
score_delta
```

Patch apply 後會新增 `score_delta_eff`，再用它更新分數：

```verilog
if (skill_on && score_delta < 0)
    score_delta_eff = -score_delta;
```

## Test Points

- base branch 碰到 `-3/-5` 正常扣分
- apply patch 後，技能期間碰到 `-3/-5` 變加分
- 正分物件仍正常加分
