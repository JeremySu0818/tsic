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

這個 patch 會新增：

```text
src/game/skill_invincible_1.v
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

Patch apply 後會加入 `inv1_on`，並讓負分變 0：

```verilog
if (inv1_on && score_delta < 0)
    score_delta_eff = 0;
```

## Test Points

- base branch 碰到 `-3/-5` 正常扣分
- apply patch 後，技能期間碰到 `-3/-5` 分數不變
- 正分物件仍正常加分
