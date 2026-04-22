# 战斗引擎性能优化 — 方案 A 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 消除战斗 tick 中的每帧表重建和冗余操作，提升战斗帧率 30-50%

**Architecture:** 只修改 Lua 层三个核心文件，原地过滤替代表重建，去掉冗余 pcall

**Tech Stack:** Lua (Axmol 引擎), Android 设备测试

---

### Task 1: battle_engine.lua — tick 函数原地过滤

**Files:**
- Modify: `Content/src/battle/battle_engine.lua:705-722`

**Context:** 当前 tick 函数每帧对 `unit_list`、`projectile_list`、`npc_list` 各创建一个新表并用 `table.insert` 填充。一场 60 秒战斗（30fps）约 1800 帧，产生 5400+ 个临时表，给 Lua GC 造成巨大压力。

- [ ] **Step 1: 替换列表过滤逻辑**

将 `Content/src/battle/battle_engine.lua` 第 705-723 行：

```lua
		for _, list_name in ipairs({
			"unit_list",
			"projectile_list",
			"npc_list"
		})
		do
			local list = self[list_name]
			local new_list = {}
			for _, entity in ipairs(list) do
				local f = entity.frozen_model
				if not f then
					entity:update(tick_interval)
				end
				if not entity.terminated then
					table.insert(new_list, entity)
				end
			end
			self[list_name] = new_list
		end
```

替换为（原地双指针过滤，零内存分配）：

```lua
		for _, list_name in ipairs({
			"unit_list",
			"projectile_list",
			"npc_list"
		})
		do
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

**注意：** 文件使用 tab 缩进 + CRLF 换行，用 python 做精确替换。

- [ ] **Step 2: 验证无依赖**

搜索代码中是否有地方依赖 `self.unit_list` 中包含 `terminated=true` 的实体：

```bash
grep -n "terminated" Content/src/battle/battle_engine.lua | head -20
```

确认 terminated 实体只在 tick 中被移除，没有其他地方遍历并期望包含 terminated 实体。

- [ ] **Step 3: 编译部署测试**

```bash
cd proj.android && ./gradlew assembleDebug
adb install -r app/build/outputs/apk/debug/CardGame-debug.apk
```

在设备上进入战斗，验证：
- 战斗正常进行，英雄/敌人正常攻击
- 战斗结束条件正常触发（胜利/失败/超时）
- 多波次战斗（远征）正常切换

- [ ] **Step 4: 提交**

```bash
git add Content/src/battle/battle_engine.lua
git commit -m "perf: 战斗tick用原地过滤替代每帧表重建，减少GC压力"
```

---

### Task 2: battle_scene.lua — syncActors 去掉 pcall

**Files:**
- Modify: `Content/src/battle/battle_scene.lua:433-436,455-459`

**Context:** syncActors 中用 pcall 包裹 Actor 创建。pcall 有额外开销（创建闭包 + 设置错误处理），而 `unit.actor` 判断已确保只在首次创建。

- [ ] **Step 1: 去掉 unit actor 创建的 pcall**

将 `Content/src/battle/battle_scene.lua` 第 432-440 行：

```lua
				if not unit.actor then
					local ok, actor = pcall(function()
						return ed.UnitActorCreate(unit)
					end)
					if ok and actor then
						unit.actor = actor
						actor._inScene = true
						self:addActor(actor)
					end
```

替换为：

```lua
				if not unit.actor then
					local actor = ed.UnitActorCreate(unit)
					if actor then
						unit.actor = actor
						actor._inScene = true
						self:addActor(actor)
					end
```

- [ ] **Step 2: 去掉 npc actor 创建的 pcall**

将同一函数第 454-462 行：

```lua
				if not npc.actor then
					local ok, ret = pcall(function()
						npc.actor = ed.NpcActorCreate(npc)
						npc:setAction(npc.bornActionName, true)
						return npc.actor
					end)
					if ok and ret then
						self:addActor(ret)
					end
```

替换为：

```lua
				if not npc.actor then
					npc.actor = ed.NpcActorCreate(npc)
					npc:setAction(npc.bornActionName, true)
					self:addActor(npc.actor)
```

- [ ] **Step 3: 编译部署测试**

在设备上进入战斗，验证：
- 英雄和敌人的 Actor（视觉表现）正常创建
- NPC（如战斗中的障碍物）正常出现
- 多波次战斗 Actor 正确切换

- [ ] **Step 4: 提交**

```bash
git add Content/src/battle/battle_scene.lua
git commit -m "perf: syncActors去掉冗余pcall，减少闭包创建开销"
```

---

### Task 3: basescene.lua — updateFca 加可见性检查

**Files:**
- Modify: `Content/src/ui/basescene.lua:346-349`

**Context:** updateFca 遍历所有 FCA 动画并调用 update。当前只检查 isPause，不检查节点是否可见。不可见的动画仍在消耗 CPU。保留已有的 pcall 回退机制。

- [ ] **Step 1: 在 update 调用前加 isVisible 检查**

将 `Content/src/ui/basescene.lua` 第 346-351 行：

```lua
	    elseif not v.isPause then
	      local okUpdate, _ = pcall(function() v.node:update(dt) end)
	      if not okUpdate then
	        pcall(function() v.node:update(dt, false) end)
	      end
	    end
```

替换为：

```lua
	    elseif not v.isPause then
	      if v.node:isVisible() then
	        local okUpdate, _ = pcall(function() v.node:update(dt) end)
	        if not okUpdate then
	          pcall(function() v.node:update(dt, false) end)
	        end
	      end
	    end
```

- [ ] **Step 2: 编译部署测试**

在设备上验证：
- 主界面动画正常播放
- 进入战斗后战斗动画正常
- 打开/关闭弹窗后动画状态正确

- [ ] **Step 3: 提交**

```bash
git add Content/src/ui/basescene.lua
git commit -m "perf: FCA动画update加isVisible检查，跳过不可见动画"
```
