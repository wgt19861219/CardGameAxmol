# 战斗性能优化设计

## 问题描述

1. **整体帧率偏低**：战斗场景 update 每帧遍历开销大，频繁创建临时表
2. **多次战斗后累积卡顿**：场景退出无清理回调，导致内存泄漏

## 根因分析

### 帧率偏低
- `battle_scene:update()` 每帧遍历 actor_list、effect_list、ui_list 各一次
- 每次遍历创建新表做过滤（`new_list` 模式），产生大量 GC 压力
- 波次切换时 `replaceScene` 重建整个 CCScene + 4个 Layer + 所有 Sprite

### 累积卡顿
- `battle_scene` 没有 `OnPopScene` 回调，pop/replace 场景时不清理
- `ListenTimer` 注册的4处定时器回调在场景退出后可能仍在触发
- `ed.engine` 全局对象不会被重置，unit_list、alive_units 数据累积
- `registerScriptTouchHandler` 注册的触摸监听没有对应的 unregister
- actor/effect/ui 的 Lua 引用在场景退出后未释放

## 优化方案

### 1. OnPopScene 清理回调

在 `battle_scene.lua` 新增 `OnPopScene(self)` 函数：

- 停止并释放 `nextwaveAction`（retain/release 配对）
- 注销 `pauseLayer` 的触摸监听
- 遍历清理 `actor_list`、`effect_list`、`ui_list` 中所有节点的引用
- 清空 `ed.engine.unit_list` 中所有 unit 的 actor 引用
- 清空 `delayPlayMusicHandler`
- 触发 `collectgarbage("collect")`

### 2. 波次切换场景复用

**改造 `nextBattle()`**：不再调用 `ed.replaceScene(ed.scene)`，改为在当前场景内清理+重建。

**改造 `reset()`**：检测 layers 是否已存在：
- 不存在：创建新 CCScene + 4个 Layer（首次进入战斗）
- 已存在：`removeAllChildrenWithCleanup(true)` 清空子节点，复用 Layer

流程变为：
1. 清理旧波次的 actor/effect/ui 节点
2. 清理旧背景 Sprite
3. 调用 `ed.engine:nextBattle()` 切换引擎层数据
4. 调用 `self:reset()` 复用已有场景节点重建内容

### 3. update 循环优化

将3个列表的"创建新表过滤"改为**原地移除**：

```lua
local n = 0
for i = 1, #self.actor_list do
    local actor = self.actor_list[i]
    if not actor.model.terminated then
        n = n + 1
        self.actor_list[n] = actor
        -- update logic
    else
        actor.node:removeFromParentAndCleanup(true)
    end
end
for i = n + 1, #self.actor_list do
    self.actor_list[i] = nil
end
```

effect_list 和 ui_list 同理。消除每帧3次表分配。

### 4. 轻量 Sprite 缓存

在 `battle_scene` 上加 `cached_sprites = {}` 表：
- actor 销毁时，将其内部可复用的 CCSprite（血条背景等）detach 并缓存
- 新建 actor 时优先从缓存取
- OnPopScene 时清空缓存

## 修改文件

| 文件 | 改动 |
|------|------|
| `Content/src/battle/battle_scene.lua` | 加 OnPopScene、改 nextBattle、改 reset、优化 update |
| `Content/src/battle/battle_engine.lua` | 无直接改动（engine 逻辑不变） |

## 风险

- 波次切换复用场景：需确保 reset() 中所有状态都被正确重置，否则波次间可能残留旧数据
- 原地移除：需验证遍历顺序不会影响逻辑（当前逻辑是遍历+过滤，无序要求）

## 验证标准

1. 进入战斗打完3波退出，再进战斗打3波退出，重复5次，帧率无明显下降
2. 波次切换时无黑屏/停顿
3. Android 设备上流畅度可接受
