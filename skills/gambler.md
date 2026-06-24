# Gambler

## Goal

賭神技能讓技能期間低分 `+1` 不再直接出現，改成高分或高風險物件。

## Default Spec

```text
duration: 10 seconds
+1 -> +3 / +5 / -5
```

## Patch

```powershell
git apply --ignore-whitespace .\skills\patches\gambler.patch
```

這個 patch 會新增：

```text
src/game/skill_gambler.v
```

並修改：

```text
src/game/game_ctrl.v
src/game/spawn_postprocess.v
hdmi_coin.gprj
```

## Hook Points

Base branch 已經在 `spawn_queue` 後面放了 pass-through：

```verilog
spawn_postprocess
```

Patch apply 後會加入 `gambler_on`，並在 `spawn_postprocess` 裡 remap `TYPE_COIN_1`：

```verilog
if (gambler_on && raw_type == TYPE_COIN_1)
    out_type = TYPE_COIN_3 / TYPE_COIN_5 / TYPE_MINUS5;
```

## Test Points

- base branch 不會 remap spawn type
- apply patch 後，技能期間新生成的 `+1` 會被改成其他 type
- 已經在畫面上的物件不需要被改掉
