# 战斗性能优化实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 消除战斗场景的内存泄漏和帧率瓶颈，使多次战斗后无累积卡顿

**Architecture:** 在 battle_scene.lua 中新增 OnPopScene 清理回调、改造波次切换为场景复用、优化 update 循环避免每帧表分配

**Tech Stack:** Lua + Axmol (cocos2d-x 2.x API)

---

### Task 1: 新增 OnPopScene 清理回调

**Files:**
- Modify: `Content/src/battle/battle_scene.lua:294` (在 class.exit = exit 之后插入)

- [ ] **Step 1: 在 class.exit = exit 之后添加 OnPopScene 函数**

在第294行 `class.exit = exit` 之后、第296行 `local function returnBtnTapHandler()` 之前插入：

```lua
local function OnPopScene(self)
    -- 停止并释放未完成的波次切换动作
    if self.nextwaveAction then
        pcall(function()
            if self.node and not tolua.isnull(self.node) then
                self.node:stopAction(self.nextwaveAction)
            end
            self.nextwaveAction:release()
            self.nextwaveAction = nil
        end)
    end
    -- 注销暂停层触摸监听
    if self.pauseLayer and not tolua.isnull(self.pauseLayer) then
        pcall(function() self.pauseLayer:unregisterScriptTouchHandler() end)
    end
    -- 清理所有 actor 节点引用
    for _, actor in ipairs(self.actor_list or {}) do
        if actor.node and not tolua.isnull(actor.node) then
            pcall(function() actor.node:removeFromParentAndCleanup(true) end)
        end
    end
    self.actor_list = {}
    -- 清理所有 effect 节点引用
    for _, effect in ipairs(self.effect_list or {}) do
        pcall(function()
            local node = effect.node or effect
            if not tolua.isnull(node) then
                node:removeFromParentAndCleanup(true)
            end
        end)
    end
    self.effect_list = {}
    -- 清理 ui_list 引用
    self.ui_list = {}
    -- 清空引擎中所有 unit 的 actor 引用（防止 Lua 持有已销毁节点）
    if ed.engine and ed.engine.unit_list then
        for _, unit in ipairs(ed.engine.unit_list) do
            unit.actor = nil
        end
    end
    -- 清空延迟音乐回调
    self.delayPlayMusicHandler = nil
    -- 清空暂停层引用
    self.pauseLayer = nil
    -- 强制 GC 回收
    collectgarbage("collect")
end
class.OnPopScene = OnPopScene
```

- [ ] **Step 2: 验证代码无语法错误**

检查要点：
- `OnPopScene` 必须在 `class.exit = exit` 之后、`returnBtnTapHandler` 之前
- `class.OnPopScene = OnPopScene` 确保 `hello.lua:363` 的 `scene:OnPopScene()` 调用可访问

- [ ] **Step 3: 提交**

```bash
git add Content/src/battle/battle_scene.lua
git commit -m "战斗性能：新增OnPopScene清理回调，释放actor/effect/action引用"
```

---

### Task 2: 改造 reset() 为可复用模式

**Files:**
- Modify: `Content/src/battle/battle_scene.lua:47-116`

- [ ] **Step 1: 改造 reset() 中的场景节点创建逻辑**

将第60-69行：

```lua
	self.node = CCScene:create()
	-- ensure layers exist first
	self.background_layer = CCLayer:create()
	self.main_layer = CCLayer:create()
	self.top_layer = CCLayer:create()
	self.ui_layer = CCLayer:create()
	self.node:addChild(self.background_layer, 0)
	self.node:addChild(self.main_layer, 1)
	self.node:addChild(self.top_layer, 2)
	self.node:addChild(self.ui_layer, 3)
```

替换为：

```lua
	-- 复用已有场景节点（波次切换），或首次创建
	if not self.node or tolua.isnull(self.node) then
		self.node = CCScene:create()
		self.background_layer = CCLayer:create()
		self.main_layer = CCLayer:create()
		self.top_layer = CCLayer:create()
		self.ui_layer = CCLayer:create()
		self.node:addChild(self.background_layer, 0)
		self.node:addChild(self.main_layer, 1)
		self.node:addChild(self.top_layer, 2)
		self.node:addChild(self.ui_layer, 3)
	else
		-- 波次切换时复用已有 layers，清空子节点
		self.background_layer:removeAllChildrenWithCleanup(true)
		self.main_layer:removeAllChildrenWithCleanup(true)
		self.top_layer:removeAllChildrenWithCleanup(true)
		self.ui_layer:removeAllChildrenWithCleanup(true)
	end
```

- [ ] **Step 2: 提交**

```bash
git add Content/src/battle/battle_scene.lua
git commit -m "战斗性能：reset()支持场景复用，波次切换清空子节点而非重建CCScene"
```

---

### Task 3: 改造 nextBattle() 为场景内切换

**Files:**
- Modify: `Content/src/battle/battle_scene.lua:365-375`

- [ ] **Step 1: 替换 nextBattle() 函数**

将第365-375行：

```lua
local function nextBattle(self)
	local auto = self.auto_combat
	local stage = ed.engine.stage_info
	local battle = ed.lookupDataTable("Battle", nil, stage["Stage ID"], ed.engine.wave_id + 1)
	ed.engine:nextBattle()
	self:reset(stage, battle, self.battleModeInfo)
	self.auto_combat = auto
	self.auto_btn:setSelectedIndex(auto and 1 or 0)
	ed.replaceScene(ed.scene)
end
class.nextBattle = nextBattle
```

替换为：

```lua
local function nextBattle(self)
	local auto = self.auto_combat
	local stage = ed.engine.stage_info
	local battle = ed.lookupDataTable("Battle", nil, stage["Stage ID"], ed.engine.wave_id + 1)
	-- 清理旧波次的 actor 节点
	for _, actor in ipairs(self.actor_list) do
		if actor.node and not tolua.isnull(actor.node) then
			pcall(function() actor.node:removeFromParentAndCleanup(true) end)
		end
	end
	self.actor_list = {}
	-- 清理旧波次的 effect 节点
	for _, effect in ipairs(self.effect_list) do
		pcall(function()
			local node = effect.node or effect
			if not tolua.isnull(node) then
				node:removeFromParentAndCleanup(true)
			end
		end)
	end
	self.effect_list = {}
	-- 清理旧波次的 ui 节点
	for _, ui in ipairs(self.ui_list) do
		if ui.node and not tolua.isnull(ui.node) then
			pcall(function() ui.node:removeFromParentAndCleanup(true) end)
		end
	end
	self.ui_list = {}
	-- 清理旧背景
	if self.background and not tolua.isnull(self.background) then
		pcall(function() self.background:removeFromParentAndCleanup(true) end)
		self.background = nil
	end
	-- 引擎层切波
	ed.engine:nextBattle()
	-- 复用当前场景（reset 会检测已有 layers 并清空子节点）
	self:reset(stage, battle, self.battleModeInfo)
	self.auto_combat = auto
	self.auto_btn:setSelectedIndex(auto and 1 or 0)
end
class.nextBattle = nextBattle
```

关键变化：去掉 `ed.replaceScene(ed.scene)`，不再重建场景。

- [ ] **Step 2: 提交**

```bash
git add Content/src/battle/battle_scene.lua
git commit -m "战斗性能：nextBattle()场景内切换，去掉replaceScene避免重建CCScene"
```

---

### Task 4: 优化 update() 循环 — 原地移除替代新建表

**Files:**
- Modify: `Content/src/battle/battle_scene.lua:654-704`

- [ ] **Step 1: 替换 actor_list 过滤逻辑**

将第654-669行替换为：

```lua
			local n = 0
			for i = 1, #self.actor_list do
				local actor = self.actor_list[i]
				if not actor.model.terminated then
					n = n + 1
					self.actor_list[n] = actor
					if not actor.model.frozen_actor then
						local ok_upd, err_upd = pcall(function() actor:update(dt) end)
						if not ok_upd and not actor._updErrShown then
							print("[BATTLE_SCENE] actor update error: " .. tostring(err_upd))
							actor._updErrShown = true
						end
					end
				else
					actor.node:removeFromParentAndCleanup(true)
				end
			end
			for i = n + 1, #self.actor_list do
				self.actor_list[i] = nil
			end
```

- [ ] **Step 2: 替换 effect_list 过滤逻辑**

将第670-682行替换为：

```lua
			local n = 0
			for i = 1, #self.effect_list do
				local effect = self.effect_list[i]
				if effect.update then
					effect:update(dt)
				end
				if effect:isTerminated() then
					local node = effect.node or effect
					node:removeFromParentAndCleanup(true)
				else
					n = n + 1
					self.effect_list[n] = effect
				end
			end
			for i = n + 1, #self.effect_list do
				self.effect_list[i] = nil
			end
```

- [ ] **Step 3: 替换 ui_list 过滤逻辑**

将第696-704行替换为：

```lua
		local n = 0
		for i = 1, #self.ui_list do
			local ui = self.ui_list[i]
			ui:update(dt)
			if not ui.terminated then
				n = n + 1
				self.ui_list[n] = ui
			end
		end
		for i = n + 1, #self.ui_list do
			self.ui_list[i] = nil
		end
```

- [ ] **Step 4: 提交**

```bash
git add Content/src/battle/battle_scene.lua
git commit -m "战斗性能：update()原地移除替代新建表，消除每帧3次表分配的GC压力"
```

---

### Task 5: 编译验证与手动测试

**Files:** 无代码改动

- [ ] **Step 1: 编译 Android 项目**

```bash
cd D:\workspace\projects\CardGameAxmol\proj.android && ./gradlew assembleDebug
```

Expected: BUILD SUCCESSFUL

- [ ] **Step 2: 安装到 MuMu 模拟器，进入战斗场景测试**

测试流程：
1. 选择关卡进入战斗
2. 打完第1波 → 观察波次切换是否流畅（无黑屏/停顿）
3. 打完第2波 → 同上
4. 打完第3波退出
5. 重复进入战斗3-5次
6. 观察帧率是否稳定，无累积卡顿
