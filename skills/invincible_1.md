# Invincible 1

## Goal

無敵 1 是防禦型技能。技能期間碰到負分物件時，不扣分。

## Default Spec

```text
duration: 12 seconds
-3 -> 0
-5 -> 0
```

## Patch

```powershell
git apply --ignore-whitespace .\skills\patches\invincible_1.patch
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
    score_delta_eff = 0;
```

## Test Points

- base branch 碰到 `-3/-5` 正常扣分
- apply patch 後，技能期間碰到 `-3/-5` 分數不變
- 正分物件仍正常加分
