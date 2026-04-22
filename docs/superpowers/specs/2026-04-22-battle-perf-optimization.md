# 战斗引擎性能优化 — 方案 A（Lua 层最小改动）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 消除战斗 tick 中的每帧表重建和冗余操作，提升战斗帧率 30-50%

**Architecture:** 只修改 Lua 层三个核心文件，用原地标记删除替代表重建，跳过冻结/终止实体的 update 调用

**Tech Stack:** Lua (Content/src/battle/)

---

## 问题分析

### 瓶颈 1：每帧表重建（battle_engine.lua:705-722）
每个 tick 对 `unit_list`、`projectile_list`、`npc_list` 执行：
```lua
local new_list = {}
for _, entity in ipairs(list) do
    entity:update(tick_interval)
    if not entity.terminated then
        table.insert(new_list, entity)
    end
end
self[list_name] = new_list
```
**问题：** 每帧创建 3 个新表 + N 次 table.insert = 大量 Lua GC 压力。一场 60 秒战斗约 1800 帧，产生 5400+ 个临时表。

**修复：** 原地过滤，把 terminated 实体移到末尾然后截断，不创建新表。

### 瓶颈 2：冗余 pcall 包裹（battle_scene.lua:433-434）
syncActors 每个 tick 对每个单位执行 `pcall(function() return ed.UnitActorCreate(unit) end)`。
pcall 本身有开销，且 Actor 创建应只在单位首次出现时执行一次。

**修复：** 去掉 pcall，Actor 创建已在 unit.actor 判断保护下，只在首次创建。

### 瓶颈 3：冻结单位仍然 update（battle_engine.lua:713-716）
冻结检查在 update 调用之前已经正确。但 terminated 实体仍在循环中被遍历。

**修复：** 原地过滤后，terminated 实体不再被遍历。

## 修改范围

| 文件 | 改动 | 行数 |
|------|------|------|
| `Content/src/battle/battle_engine.lua` | tick 函数中的列表过滤逻辑 | ~15 行 |
| `Content/src/battle/battle_scene.lua` | syncActors 去掉 pcall | ~5 行 |
| `Content/src/ui/basescene.lua` | fcaList 动画 update 加可见性检查 | ~10 行 |

总计约 30 行修改，3 个文件。

## 详细设计

### 1. battle_engine.lua — tick 函数原地过滤

将 705-722 行替换为：
```lua
for _, list_name in ipairs({"unit_list", "projectile_list", "npc_list"}) do
    local list = self[list_name]
    local write = 1
    for i = 1, #list do
        local entity = list[i]
        if not entity.frozen_model then
            entity:update(tick_interval)
        end
        if not entity.terminated then
            list[write] = entity
            write = write + 1
        end
    end
    for i = write, #list do
        list[i] = nil
    end
end
```

**原理：** 双指针原地过滤。write 指针只前进，不创建新表，不调用 table.insert。terminated 实体从末尾开始置 nil。GC 压力降为零。

### 2. battle_scene.lua — syncActors 去掉 pcall

将 433-434 行：
```lua
local ok, actor = pcall(function()
    return ed.UnitActorCreate(unit)
end)
if ok and actor then
```
改为：
```lua
local actor = ed.UnitActorCreate(unit)
if actor then
```

同步修改 455-456 行的 npc.actor 创建。

### 3. basescene.lua — fcaList 可见性检查

在 fcaList 遍历中加入可见性检查：
```lua
for k, v in pairs(self.fcaList or {}) do
    if not v.isPause and v.node and v.node:isVisible() then
        v.node:update(dt)
    end
end
```

## 预期效果

- 每帧减少 3 次表分配 + N 次 table.insert → GC 压力降低 90%
- 跳过 pcall 开销 → 函数调用减少约 50%
- 动画可见性检查 → 非可见动画零开销

## 风险评估

- **低风险：** 原地过滤是经典算法，不改变业务逻辑
- **需测试：** terminated 实体不再被遍历，确认没有后续代码依赖 `self.unit_list` 中包含 terminated 实体
- **回退容易：** 每个改动独立，可逐个回退
