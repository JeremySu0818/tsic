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

這個 patch 會新增：

```text
src/game/skill_invincible_2.v
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

Patch apply 後會加入 `inv2_on`，並把負分取相反數：

```verilog
if (inv2_on && score_delta < 0)
    score_delta_eff = -score_delta;
```

## Test Points

- base branch 碰到 `-3/-5` 正常扣分
- apply patch 後，技能期間碰到 `-3/-5` 變加分
- 正分物件仍正常加分
