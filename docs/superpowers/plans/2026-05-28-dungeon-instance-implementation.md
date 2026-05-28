# 副本系统实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现 7 个副本（4 普通 + 3 英雄）的数据层、入口 UI、掉落判定和钥匙经济系统

**Architecture:** 复用现有 ActStageGroup + Stage 数据驱动架构。新增副本注册为 Group 40001-40007，Stage 40001-40021。钥匙经济复用 `player._points` 系统新增 `dungeonpoint` 类型。掉落概率通过 Stage 的 `UI reward + Min/Max Amount` 实现（Min=0 表示概率掉落，Max=1 表示最多掉 1 件）。

**Tech Stack:** Lua + Axmol C++ 引擎 + CSV 数据表

**设计文档:** `docs/superpowers/specs/2026-05-28-dungeon-instance-design.md`

---

## 文件结构

| 文件 | 职责 | 操作 |
|------|------|------|
| `Content/src/ActStageGroupDungeon.lua` | 副本组配置（7个副本） | 新建 |
| `Content/src/StageDungeon.lua` | 副本关卡配置（21个Boss战） | 新建 |
| `Content/src/ui/dungeon.lua` | 副本入口UI（复用exercise模式） | 新建 |
| `Content/src/local_server.lua` | 副本掉落判定+钥匙经济 | 修改 |
| `Content/src/player.lua` | 新增 `addDungeonPoint`/`getDungeonPoint` | 修改 |
| `Content/src/playertools.lua` | `addPoint` 支持新的 `dungeonpoint` 类型 | 修改 |
| `Content/src/ui/main.lua` | 主界面添加副本入口按钮 | 修改 |
| `Content/src/language/zh-CN.lua` | 副本名称/Boss名称/成就文本 | 修改 |
| `Content/src/playerlimit.lua` | 副本次数限制配置 | 修改 |
| `Content/src/main.lua` | 注册新的数据表和UI模块 | 修改 |

---

## Task 1: 数据层 — 副本组配置

**Files:**
- Create: `Content/src/ActStageGroupDungeon.lua`
- Modify: `Content/src/main.lua`

- [ ] **Step 1: 创建 ActStageGroupDungeon.lua**

```lua
-- 副本组配置：7个副本（4普通+3英雄）
-- Group ID: 40001-40007
return {
  [40001] = {
    ["CD"] = 0,
    ["DailyLimit"] = 2,
    ["MaxBuyPerDay"] = 3,
    ["BuyCost"] = 50,
    ["Currency"] = "dungeonpoint",
    ["Group Name"] = LSTR("DUNGEON.BLACKROCK_LOWER"),
    ["Difficulty"] = 1,
    ["Monday"] = true, ["Tuesday"] = true, ["Wednesday"] = true,
    ["Thursday"] = true, ["Friday"] = true, ["Saturday"] = true, ["Sunday"] = true,
    ["Stage Group"] = 40001,
    ["Stages"] = { 40001, 40002, 40003, 0, 0, 0, 0, 0 },
    ["UI reward1"] = 312,  -- 大电锤
    ["UI reward2"] = 351,  -- 撒旦
    ["UI reward3"] = 338,  -- 深渊之刃
  },
  [40002] = {
    ["CD"] = 0,
    ["DailyLimit"] = 2,
    ["MaxBuyPerDay"] = 3,
    ["BuyCost"] = 50,
    ["Currency"] = "dungeonpoint",
    ["Group Name"] = LSTR("DUNGEON.STRATHOLME"),
    ["Difficulty"] = 1,
    ["Monday"] = true, ["Tuesday"] = true, ["Wednesday"] = true,
    ["Thursday"] = true, ["Friday"] = true, ["Saturday"] = true, ["Sunday"] = true,
    ["Stage Group"] = 40002,
    ["Stages"] = { 40004, 40005, 40006, 0, 0, 0, 0, 0 },
    ["UI reward1"] = 306,  -- 天堂
    ["UI reward2"] = 309,  -- 林肯
    ["UI reward3"] = 311,  -- 强袭
  },
  [40003] = {
    ["CD"] = 0,
    ["DailyLimit"] = 2,
    ["MaxBuyPerDay"] = 3,
    ["BuyCost"] = 50,
    ["Currency"] = "dungeonpoint",
    ["Group Name"] = LSTR("DUNGEON.DIRE_MAUL"),
    ["Difficulty"] = 1,
    ["Monday"] = true, ["Tuesday"] = true, ["Wednesday"] = true,
    ["Thursday"] = true, ["Friday"] = true, ["Saturday"] = true, ["Sunday"] = true,
    ["Stage Group"] = 40003,
    ["Stages"] = { 40007, 40008, 40009, 0, 0, 0, 0, 0 },
    ["UI reward1"] = 307,  -- 紫苑
    ["UI reward2"] = 310,  -- 刷新珠
    ["UI reward3"] = 347,  -- 光耀
  },
  [40004] = {
    ["CD"] = 0,
    ["DailyLimit"] = 2,
    ["MaxBuyPerDay"] = 3,
    ["BuyCost"] = 50,
    ["Currency"] = "dungeonpoint",
    ["Group Name"] = LSTR("DUNGEON.SCHNOLOMANCE"),
    ["Difficulty"] = 1,
    ["Monday"] = true, ["Tuesday"] = true, ["Wednesday"] = true,
    ["Thursday"] = true, ["Friday"] = true, ["Saturday"] = true, ["Sunday"] = true,
    ["Stage Group"] = 40004,
    ["Stages"] = { 40010, 40011, 40012, 0, 0, 0, 0, 0 },
    ["UI reward1"] = 315,  -- 冰眼（复选）
    ["UI reward2"] = 310,  -- 刷新珠（复选）
    ["UI reward3"] = 306,  -- 天堂（复选）
  },
  [40005] = {
    ["CD"] = 0,
    ["DailyLimit"] = 1,
    ["MaxBuyPerDay"] = 2,
    ["BuyCost"] = 100,
    ["Currency"] = "dungeonpoint",
    ["Group Name"] = LSTR("DUNGEON.NAXXRAMAS"),
    ["Difficulty"] = 2,
    ["Monday"] = true, ["Tuesday"] = true, ["Wednesday"] = true,
    ["Thursday"] = true, ["Friday"] = true, ["Saturday"] = true, ["Sunday"] = true,
    ["Stage Group"] = 40005,
    ["Stages"] = { 40013, 40014, 40015, 0, 0, 0, 0, 0 },
    ["UI reward1"] = 405,  -- 雷霆之怒
    ["UI reward2"] = 406,  -- 欺诈者之剑
    ["UI reward3"] = 409,  -- 地覆
  },
  [40006] = {
    ["CD"] = 0,
    ["DailyLimit"] = 1,
    ["MaxBuyPerDay"] = 2,
    ["BuyCost"] = 100,
    ["Currency"] = "dungeonpoint",
    ["Group Name"] = LSTR("DUNGEON.BLACKWING_LAIR"),
    ["Difficulty"] = 2,
    ["Monday"] = true, ["Tuesday"] = true, ["Wednesday"] = true,
    ["Thursday"] = true, ["Friday"] = true, ["Saturday"] = true, ["Sunday"] = true,
    ["Stage Group"] = 40006,
    ["Stages"] = { 40016, 40017, 40018, 0, 0, 0, 0, 0 },
    ["UI reward1"] = 417,  -- 不朽之守护
    ["UI reward2"] = 419,  -- 魔龙之鳞
    ["UI reward3"] = 412,  -- 水晶之塔
  },
  [40007] = {
    ["CD"] = 0,
    ["DailyLimit"] = 1,
    ["MaxBuyPerDay"] = 2,
    ["BuyCost"] = 100,
    ["Currency"] = "dungeonpoint",
    ["Group Name"] = LSTR("DUNGEON.RUINS_OF_AHN_QIRAJ"),
    ["Difficulty"] = 2,
    ["Monday"] = true, ["Tuesday"] = true, ["Wednesday"] = true,
    ["Thursday"] = true, ["Friday"] = true, ["Saturday"] = true, ["Sunday"] = true,
    ["Stage Group"] = 40007,
    ["Stages"] = { 40019, 40020, 40021, 0, 0, 0, 0, 0 },
    ["UI reward1"] = 413,  -- 无尽长夜法杖
    ["UI reward2"] = 414,  -- 翡翠之吻
    ["UI reward3"] = 416,  -- 暗月卡牌
  },
}
```

- [ ] **Step 2: 在 main.lua 中注册数据表**

在 `main.lua` 中找到其他 `getDataTable` 调用的位置，添加：

```lua
ed.datatable["ActStageGroupDungeon"] = require("Content/src/ActStageGroupDungeon")
ed.datatable["StageDungeon"] = require("Content/src/StageDungeon")
```

- [ ] **Step 3: 提交**

```bash
git add Content/src/ActStageGroupDungeon.lua Content/src/main.lua
git commit -m "feat: 副本数据层 — 7个副本组配置"
```

---

## Task 2: 数据层 — 关卡配置

**Files:**
- Create: `Content/src/StageDungeon.lua`

- [ ] **Step 1: 创建 StageDungeon.lua**

每个 Stage 条目参照 Stage.lua 中 20001 的完整字段格式。以下只展示前 3 个 Stage（黑石塔 Boss 1-3），其余 18 个 Stage 结构相同，按设计文档填写字段。

```lua
-- 副本关卡配置：21个Boss战
-- Stage ID: 40001-40021
return {
  -- ===== 黑石塔下层 (Group 40001) =====
  [40001] = {
    ["Chapter ID"] = 201,
    ["Chest For FD"] = false,
    ["Daily Limit"] = 0,
    ["Difficulty"] = 1,
    ["Exp Reward"] = 10,
    ["Fail Exp Reward"] = 2,
    ["Heroexp Reward"] = 250,
    ["Key Stage"] = false,
    ["Loot 1 Name"] = 0,
    ["Loot 2 Name"] = 0,
    ["Loot 3 Name"] = 0,
    ["Loot 4 Name"] = 0,
    ["Loot 5 Name"] = 0,
    ["Loot 6 Name"] = 0,
    ["Loot 7 Name"] = 0,
    ["Monster Level"] = 80,
    ["Raid Bonus Amount 1"] = 1,
    ["Raid Bonus Amount 2"] = 1,
    ["Raid Bonus Amount 3"] = 0,
    ["Raid Bonus Amount 4"] = 0,
    ["Raid Bonus ID 1"] = 312,   -- 大电锤
    ["Raid Bonus ID 2"] = 351,   -- 撒旦
    ["Raid Bonus ID 3"] = 0,
    ["Raid Bonus ID 4"] = 0,
    ["Raid Bonus Type 1"] = "Equip",
    ["Raid Bonus Type 2"] = "Equip",
    ["Raid Bonus Type 3"] = "Item",
    ["Require Stage"] = 0,
    ["Require Stars"] = 0,
    ["Stage Group"] = 40001,
    ["Stage ID"] = 40001,
    ["Stage Name"] = LSTR("DUNGEON.BOSS_LAVA_BEAST"),
    ["UI reward1"] = 312,
    ["UI reward1 Max Amount"] = 1,
    ["UI reward1 Min Amount"] = 0,
    ["UI reward2"] = 351,
    ["UI reward2 Max Amount"] = 1,
    ["UI reward2 Min Amount"] = 0,
    ["UI reward3"] = 0,
    ["UI reward3 Max Amount"] = 0,
    ["UI reward3 Min Amount"] = 0,
    ["UI reward4"] = 0,
    ["UI reward4 Max Amount"] = 0,
    ["UI reward4 Min Amount"] = 0,
    ["UI reward5"] = 0,
    ["UI reward5 Max Amount"] = 0,
    ["UI reward5 Min Amount"] = 0,
    ["UI reward6"] = 0,
    ["UI reward6 Max Amount"] = 0,
    ["UI reward6 Min Amount"] = 0,
    ["UI reward7"] = 0,
    ["UI reward7 Max Amount"] = 0,
    ["UI reward7 Min Amount"] = 0,
    ["Unlock Level"] = 60,
    ["Vit Return"] = 0,
    ["Vitality Cost"] = 12,
    ["Waves"] = 1,
  },
  [40002] = {
    -- 火焰工匠 — 同结构，改 Stage ID/Name/reward
    ["Chapter ID"] = 201,
    ["Chest For FD"] = false,
    ["Daily Limit"] = 0,
    ["Difficulty"] = 1,
    ["Exp Reward"] = 10,
    ["Fail Exp Reward"] = 2,
    ["Heroexp Reward"] = 250,
    ["Key Stage"] = false,
    ["Loot 1 Name"] = 0, ["Loot 2 Name"] = 0, ["Loot 3 Name"] = 0,
    ["Loot 4 Name"] = 0, ["Loot 5 Name"] = 0, ["Loot 6 Name"] = 0, ["Loot 7 Name"] = 0,
    ["Monster Level"] = 82,
    ["Raid Bonus Amount 1"] = 1, ["Raid Bonus Amount 2"] = 1,
    ["Raid Bonus Amount 3"] = 0, ["Raid Bonus Amount 4"] = 0,
    ["Raid Bonus ID 1"] = 352,   -- 深渊之刃
    ["Raid Bonus ID 2"] = 305,   -- 长笛
    ["Raid Bonus ID 3"] = 0, ["Raid Bonus ID 4"] = 0,
    ["Raid Bonus Type 1"] = "Equip", ["Raid Bonus Type 2"] = "Equip",
    ["Raid Bonus Type 3"] = "Item",
    ["Require Stage"] = 0, ["Require Stars"] = 0,
    ["Stage Group"] = 40001,
    ["Stage ID"] = 40002,
    ["Stage Name"] = LSTR("DUNGEON.BOSS_FIRE_CRAFTER"),
    ["UI reward1"] = 352, ["UI reward1 Max Amount"] = 1, ["UI reward1 Min Amount"] = 0,
    ["UI reward2"] = 305, ["UI reward2 Max Amount"] = 1, ["UI reward2 Min Amount"] = 0,
    ["UI reward3"] = 0, ["UI reward3 Max Amount"] = 0, ["UI reward3 Min Amount"] = 0,
    ["UI reward4"] = 0, ["UI reward4 Max Amount"] = 0, ["UI reward4 Min Amount"] = 0,
    ["UI reward5"] = 0, ["UI reward5 Max Amount"] = 0, ["UI reward5 Min Amount"] = 0,
    ["UI reward6"] = 0, ["UI reward6 Max Amount"] = 0, ["UI reward6 Min Amount"] = 0,
    ["UI reward7"] = 0, ["UI reward7 Max Amount"] = 0, ["UI reward7 Min Amount"] = 0,
    ["Unlock Level"] = 60, ["Vit Return"] = 0, ["Vitality Cost"] = 12, ["Waves"] = 1,
  },
  [40003] = {
    -- 黑铁领主 — 同结构
    ["Chapter ID"] = 201, ["Chest For FD"] = false, ["Daily Limit"] = 0,
    ["Difficulty"] = 1, ["Exp Reward"] = 12, ["Fail Exp Reward"] = 2,
    ["Heroexp Reward"] = 300, ["Key Stage"] = false,
    ["Loot 1 Name"] = 0, ["Loot 2 Name"] = 0, ["Loot 3 Name"] = 0,
    ["Loot 4 Name"] = 0, ["Loot 5 Name"] = 0, ["Loot 6 Name"] = 0, ["Loot 7 Name"] = 0,
    ["Monster Level"] = 85,
    ["Raid Bonus Amount 1"] = 1, ["Raid Bonus Amount 2"] = 1,
    ["Raid Bonus Amount 3"] = 0, ["Raid Bonus Amount 4"] = 0,
    ["Raid Bonus ID 1"] = 318,   -- 金箍棒
    ["Raid Bonus ID 2"] = 308,   -- 分身斧
    ["Raid Bonus ID 3"] = 0, ["Raid Bonus ID 4"] = 0,
    ["Raid Bonus Type 1"] = "Equip", ["Raid Bonus Type 2"] = "Equip",
    ["Raid Bonus Type 3"] = "Item",
    ["Require Stage"] = 0, ["Require Stars"] = 0,
    ["Stage Group"] = 40001, ["Stage ID"] = 40003,
    ["Stage Name"] = LSTR("DUNGEON.BOSS_DARK_IRON_LORD"),
    ["UI reward1"] = 318, ["UI reward1 Max Amount"] = 1, ["UI reward1 Min Amount"] = 0,
    ["UI reward2"] = 308, ["UI reward2 Max Amount"] = 1, ["UI reward2 Min Amount"] = 0,
    ["UI reward3"] = 0, ["UI reward3 Max Amount"] = 0, ["UI reward3 Min Amount"] = 0,
    ["UI reward4"] = 0, ["UI reward4 Max Amount"] = 0, ["UI reward4 Min Amount"] = 0,
    ["UI reward5"] = 0, ["UI reward5 Max Amount"] = 0, ["UI reward5 Min Amount"] = 0,
    ["UI reward6"] = 0, ["UI reward6 Max Amount"] = 0, ["UI reward6 Min Amount"] = 0,
    ["UI reward7"] = 0, ["UI reward7 Max Amount"] = 0, ["UI reward7 Min Amount"] = 0,
    ["Unlock Level"] = 60, ["Vit Return"] = 0, ["Vitality Cost"] = 12, ["Waves"] = 1,
  },
  -- ===== 斯坦索姆 (Group 40002) =====
  -- Stage 40004: 瘟疫使者 → reward: 天堂(306), 林肯(309)
  -- Stage 40005: 肉盾憎恶 → reward: 强袭(311), 冰甲(345)
  -- Stage 40006: 死亡骑士 → reward: 龙心(348), 冰眼(315)
  -- ... (结构同上，按设计文档第四章填写)

  -- ===== 厄运之槌 (Group 40003) =====
  -- Stage 40007: 扭曲树精 → reward: 紫苑(307), 羊刀(319)
  -- Stage 40008: 恶魔卫士 → reward: 刷新珠(310), 虚灵(346)
  -- Stage 40009: 厄运王子 → reward: 光耀(347), *(ID 349)*

  -- ===== 通灵学院 (Group 40004) =====
  -- Stage 40010: 冰霜讲师 → reward: 冰眼(315,复选), 冰甲(345,复选)
  -- Stage 40011: 暗影学员 → reward: 刷新珠(310,复选), 羊刀(319,复选)
  -- Stage 40012: 院长加丁 → reward: 天堂(306,复选), 强袭(311,复选)

  -- ===== 纳克萨玛斯 (Group 40005) =====
  -- Stage 40013: 教官拉苏维奥斯 → reward: 雷霆之怒(405), 大天使之剑(407)
  -- Stage 40014: 瘟疫使者诺斯 → reward: 欺诈者之剑(406), 群星之怒(408)
  -- Stage 40015: 克尔苏加德 → reward: 地覆(409), 阴影之书(420)

  -- ===== 黑翼之巢 (Group 40006) =====
  -- Stage 40016: 拉佐格尔 → reward: 不朽之守护(417), 十字军巨盾(418)
  -- Stage 40017: 瓦拉斯塔兹 → reward: 魔龙之鳞(419), 女王的浴衣(411)
  -- Stage 40018: 奈法利安 → reward: 水晶之塔(412), 虚无法杖(410)

  -- ===== 安其拉废墟 (Group 40007) =====
  -- Stage 40019: 斯克拉姆 → reward: 无尽长夜法杖(413), 逐日者法典(421)
  -- Stage 40020: 沙尔图拉 → reward: 翡翠之吻(414), 毁灭护符(415)
  -- Stage 40021: 克苏恩 → reward: 暗月卡牌(416), 疾行鞋(422)
}
```

> 注：文件中注释标记了每个 Stage 的关键字段。完整实现时需要展开所有 21 个 Stage 的完整字段。Min Amount = 0 + Max Amount = 1 表示 30%/20% 概率掉落（由 local_server 的掉落逻辑判定）。

- [ ] **Step 2: 提交**

```bash
git add Content/src/StageDungeon.lua
git commit -m "feat: 副本数据层 — 21个Boss关卡配置"
```

---

## Task 3: 钥匙经济系统

**Files:**
- Modify: `Content/src/playertools.lua`
- Modify: `Content/src/player.lua`
- Modify: `Content/src/local_server.lua`

- [ ] **Step 1: playertools.lua — 注册 dungeonpoint 类型**

在 `addPoint` 函数的 `coin_type` 表中添加 `"dungeonpoint"`：

```lua
local coin_type = {
  "gold",
  "diamond",
  "crusadepoint",
  "arenapoint",
  "guildpoint",
  "dungeonpoint"
}
```

- [ ] **Step 2: player.lua — 添加副本点数便捷方法**

在 `addCrusadeMoney` 函数之后添加：

```lua
local addDungeonPoint = function(self, amount)
  amount = amount or 0
  self:addPoint("dungeonpoint", amount)
end
class.addDungeonPoint = addDungeonPoint

local getDungeonPoint = function(self)
  return self:getPoint("dungeonpoint")
end
class.getDungeonPoint = getDungeonPoint
```

- [ ] **Step 3: local_server.lua — 添加副本掉落中的龙鳞硬币**

在 `getCrusadeReward` 函数附近添加副本掉落硬币逻辑。搜索 `getCrusadeReward`，在其后添加：

```lua
local function getDungeonCoinReward(difficulty)
  if difficulty == 1 then
    -- 普通副本：每Boss掉落 5-10 硬币
    return math.random(5, 10)
  elseif difficulty == 2 then
    -- 英雄副本：每Boss掉落 15-25 硬币
    return math.random(15, 25)
  end
  return 0
end
```

- [ ] **Step 4: 提交**

```bash
git add Content/src/playertools.lua Content/src/player.lua Content/src/local_server.lua
git commit -m "feat: 副本钥匙经济 — dungeonpoint类型+硬币掉落"
```

---

## Task 4: 副本掉落判定

**Files:**
- Modify: `Content/src/local_server.lua`

- [ ] **Step 1: 添加副本掉落判定函数**

在 local_server.lua 中，找到现有的关卡结算逻辑（搜索 `stageDone` 或 `stagedone`），在其附近添加副本专属的掉落判定：

```lua
local function getDungeonLoot(stageId)
  local stageTable = ed.getDataTable("StageDungeon")
  local stage = stageTable[stageId]
  if not stage then return {} end

  local difficulty = stage["Difficulty"] or 1
  local dropRate = difficulty == 2 and 0.2 or 0.3
  local rewards = {}

  -- 遍历 UI reward1-7
  for i = 1, 7 do
    local itemId = stage["UI reward" .. i]
    if itemId and itemId ~= 0 then
      if math.random() < dropRate then
        table.insert(rewards, {
          _type = "Equip",
          _id = itemId,
          _amount = 1
        })
      end
    end
  end

  -- 保底：如果没掉任何装备，随机掉落一个
  if #rewards == 0 then
    local candidates = {}
    for i = 1, 7 do
      local itemId = stage["UI reward" .. i]
      if itemId and itemId ~= 0 then
        table.insert(candidates, itemId)
      end
    end
    if #candidates > 0 then
      -- 优先未拥有的装备
      local chosen = nil
      if ed.player then
        for _, id in ipairs(candidates) do
          local owned = false
          for _, item in pairs(ed.player.items or {}) do
            if item._id == id then owned = true break end
          end
          if not owned then chosen = id break end
        end
      end
      if not chosen then chosen = candidates[math.random(#candidates)] end
      table.insert(rewards, {
        _type = "Equip",
        _id = chosen,
        _amount = 1
      })
    end
  end

  -- 额外：金币 + 龙鳞硬币
  table.insert(rewards, {
    _type = "Coin",
    _amount = difficulty == 2 and 5000 or 2000
  })
  table.insert(rewards, {
    _type = "dungeonpoint",
    _amount = getDungeonCoinReward(difficulty)
  })

  return rewards
end
```

- [ ] **Step 2: 在关卡结算中路由副本掉落**

找到现有 `stageDone` 处理函数中判断活动关卡的逻辑（搜索 `ActStageGroup` 或 `20001`），添加副本路由：

```lua
-- 在现有活动关卡判断之后添加
if stageId >= 40001 and stageId <= 40021 then
  local loot = getDungeonLoot(stageId)
  -- 将 loot 写入返回给客户端的奖励数据
  -- 具体插入点取决于现有 stageDone 的数据结构
  reply.rewards = loot
end
```

- [ ] **Step 3: 提交**

```bash
git add Content/src/local_server.lua
git commit -m "feat: 副本掉落判定 — 30%/20%概率+保底+优先未拥有"
```

---

## Task 5: 语言文件

**Files:**
- Modify: `Content/src/language/zh-CN.lua`

- [ ] **Step 1: 添加副本名称**

在 zh-CN.lua 文件末尾（或 DUNGEON 相关区域）添加：

```lua
-- 副本名称
LSTR_DATABASE["DUNGEON.BLACKROCK_LOWER"] = "黑石塔下层"
LSTR_DATABASE["DUNGEON.STRATHOLME"] = "斯坦索姆废墟"
LSTR_DATABASE["DUNGEON.DIRE_MAUL"] = "厄运之槌"
LSTR_DATABASE["DUNGEON.SCHNOLOMANCE"] = "通灵学院"
LSTR_DATABASE["DUNGEON.NAXXRAMAS"] = "纳克萨玛斯"
LSTR_DATABASE["DUNGEON.BLACKWING_LAIR"] = "黑翼之巢"
LSTR_DATABASE["DUNGEON.RUINS_OF_AHN_QIRAJ"] = "安其拉废墟"

-- Boss名称
LSTR_DATABASE["DUNGEON.BOSS_LAVA_BEAST"] = "熔岩巨兽"
LSTR_DATABASE["DUNGEON.BOSS_FIRE_CRAFTER"] = "火焰工匠"
LSTR_DATABASE["DUNGEON.BOSS_DARK_IRON_LORD"] = "黑铁领主"
LSTR_DATABASE["DUNGEON.BOSS_PLAGUE_BRINGER"] = "瘟疫使者"
LSTR_DATABASE["DUNGEON.BOSS_FLESH_ABOMINATION"] = "肉盾憎恶"
LSTR_DATABASE["DUNGEON.BOSS_DEATH_KNIGHT"] = "死亡骑士"
LSTR_DATABASE["DUNGEON.BOSS_TWISTED_TREANT"] = "扭曲树精"
LSTR_DATABASE["DUNGEON.BOSS_DEMON_GUARD"] = "恶魔卫士"
LSTR_DATABASE["DUNGEON.BOSS_PRINCE_OF_DOOM"] = "厄运王子"
LSTR_DATABASE["DUNGEON.BOSS_FROST_LECTURER"] = "冰霜讲师"
LSTR_DATABASE["DUNGEON.BOSS_SHADOW_STUDENT"] = "暗影学员"
LSTR_DATABASE["DUNGEON.BOSS_HEADMASTER_GADING"] = "院长加丁"
LSTR_DATABASE["DUNGEON.BOSS_INSTRUCTOR_RAZUVIUS"] = "教官拉苏维奥斯"
LSTR_DATABASE["DUNGEON.BOSS_PLAGUE_NORTH"] = "瘟疫使者诺斯"
LSTR_DATABASE["DUNGEON.BOSS_KELTHUZAD"] = "克尔苏加德"
LSTR_DATABASE["DUNGEON.BOSS_RAZORGORE"] = "狂野的拉佐格尔"
LSTR_DATABASE["DUNGEON.BOSS_VAELASTRAZ"] = "堕落的瓦拉斯塔兹"
LSTR_DATABASE["DUNGEON.BOSS_NEFARIAN"] = "奈法利安"
LSTR_DATABASE["DUNGEON.BOSS_SKERAM"] = "预言者斯克拉姆"
LSTR_DATABASE["DUNGEON.BOSS_SARTURA"] = "沙尔图拉"
LSTR_DATABASE["DUNGEON.BOSS_CTHUN"] = "克苏恩"

-- 副本UI
LSTR_DATABASE["DUNGEON.DIFFICULTY_NORMAL"] = "普通"
LSTR_DATABASE["DUNGEON.DIFFICULTY_HEROIC"] = "英雄"
LSTR_DATABASE["DUNGEON.KEY_COST"] = "需要钥匙："
LSTR_DATABASE["DUNGEON.DAILY_LEFT"] = "今日剩余："
LSTR_DATABASE["DUNGEON.BUY_EXTRA"] = "购买额外次数"
LSTR_DATABASE["DUNGEON.COIN"] = "龙鳞硬币"
LSTR_DATABASE["DUNGEON.ENTER"] = "进入副本"
LSTR_DATABASE["DUNGEON.DUNGEON_POINT"] = "龙鳞硬币"
```

- [ ] **Step 2: 提交**

```bash
git add Content/src/language/zh-CN.lua
git commit -m "feat: 副本语言文件 — 副本/Boss/UI名称"
```

---

## Task 6: 副本入口 UI

**Files:**
- Create: `Content/src/ui/dungeon.lua`
- Modify: `Content/src/ui/main.lua`
- Modify: `Content/src/main.lua`

- [ ] **Step 1: 创建 dungeon.lua — 副本入口界面**

复用 exercise.lua 的架构模式（create 函数 + tab 切换 + 关卡选择 + 进入战斗）。核心结构：

```lua
-- 副本入口UI — 复用exercise模式
local lsr = ed.ui.dungeonlsr and ed.ui.dungeonlsr.create() or nil

-- 获取副本组数据
local function getDungeonGroups(difficulty)
  local groups = ed.getDataTable("ActStageGroupDungeon")
  local result = {}
  for id, g in pairs(groups) do
    if g["Difficulty"] == difficulty then
      table.insert(result, { id = id, data = g })
    end
  end
  table.sort(result, function(a, b) return a.id < b.id end)
  return result
end

-- 获取副本次数
local function getDungeonLeftTimes(groupId)
  -- 查询 local_server 中存储的副本今日已用次数
  local group = ed.getDataTable("ActStageGroupDungeon")[groupId]
  if not group then return 0 end
  local dailyLimit = group["DailyLimit"] or 2
  local maxBuy = group["MaxBuyPerDay"] or 3
  local used = 0 -- TODO: 从 localdata 中读取今日已用次数
  return math.max(0, dailyLimit + maxBuy - used)
end

local function create(key)
  local self = {}
  self.key = key
  self.cdui = {}

  local container = CCSprite:create()
  self.container = container
  self.ui = {}
  self.ui.frame = container

  -- 背景层
  local mainLayer = CCLayerColor:create(ccc4(0, 0, 0, 150))
  self.mainLayer = mainLayer
  container:addChild(mainLayer)

  -- 根据key选择tab: "normal"=普通, "heroic"=英雄
  local difficulty = key == "heroic" and 2 or 1
  local groups = getDungeonGroups(difficulty)

  -- 创建副本列表（参照 exercise.lua 的 createDegree 模式）
  -- 每个 group 显示：名称、难度、掉落预览、钥匙需求、剩余次数
  -- 点击后调用 self:doGotoStage(stageId) 进入战斗

  -- TODO: 展开 UI 创建逻辑（参照 exercise.lua 第 346-482 行）

  return self
end

local function createDungeonScene(key)
  local scene = CCScene:create()
  local bg = CCLayerColor:create(ccc4(0, 0, 0, 255))
  scene:addChild(bg)

  local panel = create(key)
  bg:addChild(panel.container)

  return scene
end

ed.ui.dungeon = ed.ui.dungeon or {}
ed.ui.dungeon.create = createDungeonScene
```

> 注：完整实现需要参照 exercise.lua 第 230-580 行展开 UI 创建逻辑。这里给出骨架，后续 Phase 细化。

- [ ] **Step 2: main.lua — 注册 UI 模块**

在 main.lua 中找到 `ed.ui.exercise` 注册的位置，添加：

```lua
ed.ui.dungeon = require("Content/src/ui/dungeon")
```

- [ ] **Step 3: main UI — 添加副本入口按钮**

在 `Content/src/ui/main.lua` 中找到 exercise 入口按钮（搜索 `clickexercise`），在其附近添加副本入口：

```lua
-- 在现有按钮列表中添加
dungeon = function()
  if ed.ensureSceneModules then ed.ensureSceneModules("dungeon") end
  ed.pushScene(ed.ui.dungeon.create("normal"))
end,
```

- [ ] **Step 4: 提交**

```bash
git add Content/src/ui/dungeon.lua Content/src/ui/main.lua Content/src/main.lua
git commit -m "feat: 副本入口UI骨架 — 复用exercise模式"
```

---

## Task 7: 副本次数管理

**Files:**
- Modify: `Content/src/local_server.lua`

- [ ] **Step 1: 添加副本次数存储和校验**

在 local_server.lua 中添加副本次数管理：

```lua
-- 副本次数数据结构（存储在 localdata.dungeon_runs 中）
-- { [groupId] = { used_free = N, used_bought = N, date = "YYYY-MM-DD" } }

local function getDungeonRunData(groupId)
  localdata.dungeon_runs = localdata.dungeon_runs or {}
  local today = os.date("%Y-%m-%d")
  -- 每日重置
  local run = localdata.dungeon_runs[groupId]
  if not run or run.date ~= today then
    localdata.dungeon_runs[groupId] = {
      used_free = 0,
      used_bought = 0,
      date = today
    }
  end
  return localdata.dungeon_runs[groupId]
end

local function canEnterDungeon(groupId)
  local group = ed.getDataTable("ActStageGroupDungeon")[groupId]
  if not group then return false, "invalid_group" end
  local run = getDungeonRunData(groupId)
  local dailyLimit = group["DailyLimit"] or 2
  local maxBuy = group["MaxBuyPerDay"] or 3
  local totalAllowed = dailyLimit + maxBuy
  local totalUsed = run.used_free + run.used_bought
  if totalUsed >= totalAllowed then
    return false, "no_attempts_left"
  end
  -- 如果免费次数用完，检查是否有足够硬币购买
  if run.used_free >= dailyLimit then
    local cost = group["BuyCost"] or 50
    local coins = ed.player and ed.player:getDungeonPoint() or 0
    if coins < cost then
      return false, "not_enough_coins"
    end
  end
  return true
end

local function consumeDungeonAttempt(groupId)
  local group = ed.getDataTable("ActStageGroupDungeon")[groupId]
  local run = getDungeonRunData(groupId)
  local dailyLimit = group["DailyLimit"] or 2

  if run.used_free < dailyLimit then
    run.used_free = run.used_free + 1
  else
    -- 购买额外次数
    local cost = group["BuyCost"] or 50
    ed.player:addDungeonPoint(-cost)
    run.used_bought = run.used_bought + 1
  end
end
```

- [ ] **Step 2: 在战斗进入逻辑中集成次数校验**

在 local_server.lua 的 `startStage` 或类似函数中添加副本 ID 范围判断：

```lua
-- 在现有 startStage 逻辑中添加
if stageId >= 40001 and stageId <= 40021 then
  local groupId = math.floor((stageId - 1) / 3) * 3 + 40001
  -- 计算groupId: Stage 40001-40003 -> Group 40001, etc.
  groupId = 40001 + math.floor((stageId - 40001) / 3) * 1
  -- 更正: groupId 对应关系
  local stageToGroup = {
    [40001] = 40001, [40002] = 40001, [40003] = 40001,
    [40004] = 40002, [40005] = 40002, [40006] = 40002,
    [40007] = 40003, [40008] = 40003, [40009] = 40003,
    [40010] = 40004, [40011] = 40004, [40012] = 40004,
    [40013] = 40005, [40014] = 40005, [40015] = 40005,
    [40016] = 40006, [40017] = 40006, [40018] = 40006,
    [40019] = 40007, [40020] = 40007, [40021] = 40007,
  }
  groupId = stageToGroup[stageId]
  if not groupId then return { error = "invalid_stage" } end

  local ok, reason = canEnterDungeon(groupId)
  if not ok then return { error = reason } end

  consumeDungeonAttempt(groupId)
end
```

- [ ] **Step 3: 提交**

```bash
git add Content/src/local_server.lua
git commit -m "feat: 副本次数管理 — 每日免费+硬币购买+每日重置"
```

---

## Task 8: 集成测试与调试

**Files:**
- 无新文件

- [ ] **Step 1: 编译并启动模拟器**

```bash
cd D:\workspace\projects\CardGameAxmol
# 编译 Android 或运行 Win32 版本
```

- [ ] **Step 2: 验证数据加载**

- 进入游戏主界面
- 检查 console 无报错
- 确认 `ActStageGroupDungeon` 和 `StageDungeon` 表加载成功

- [ ] **Step 3: 验证副本入口**

- 点击副本入口按钮
- 确认 UI 显示 4 个普通副本
- 确认点击可进入 Boss 战

- [ ] **Step 4: 验证掉落**

- 通关一个 Boss
- 确认掉落 1 件装备（30% 或保底）
- 确认获得龙鳞硬币

- [ ] **Step 5: 验证次数消耗**

- 再次进入同一副本
- 确认次数正确减少
- 确认购买额外次数扣除硬币

- [ ] **Step 6: 修复发现的问题**

- 根据测试结果修复 bug
- 提交修复

---

## 后续 Phase（本计划不展开，待 Phase 1 完成后另写计划）

- **Phase 3:** 普通副本 P1 机制（根须定身、魔法反伤、阶段切换、隐身偷Buff）
- **Phase 4:** 英雄副本 P2 机制（心智控制、疫病狂暴、冻结、龙息、燃烧、双阶段）
- **Phase 5:** 英雄副本 P3 机制（沉默、虫群、吞噬、减甲光环、传送）
- **Phase 6:** 成就系统 + 日常任务 + 副本超时判定
