# CLAUDE.md

## Project Overview

卡牌手游项目，**用 Godot 4.5 重写为单机版**。原项目为 cocos2d-x 2.x 客户端 + PHP 服务端架构。

## 原项目路径

- **客户端**: `D:\workspace\projects\HC\Client\Resource_Client\` (Lua + C++ + 资源)
- **服务端**: `D:\workspace\projects\HC\Server\GameServer\server2\` (PHP, 51个API, 30+模块)

## Godot 项目

- **项目路径**: `D:\workspace\projects\CardGame\`
- **引擎**: Godot 4.5.1 (gl_compatibility)
- **分辨率**: 960x640 (横屏HVGA)
- **语言**: GDScript
- **实施计划**: `docs/superpowers/plans/2026-04-10-godot-rewrite.md`

## Architecture (Godot)

### scripts/core/ — 核心系统
- `game_manager.gd` — Autoload全局管理器
- `game_server.gd` — 本地服务器(替代PHP, 51个API)
- `save_manager.gd` — JSON存档系统
- `scene_manager.gd` — 场景切换管理

### scripts/data/ — 数据层
- `data_tables.gd` — JSON配置表加载器(从Lua转换的22个表)
- `player_data.gd` — 玩家数据模型(对应63个DB表)

### scripts/server/ — 业务模块 (GDScript重写PHP逻辑)
- `hero_module.gd`, `item_module.gd`, `loot_module.gd`
- `stage_module.gd`, `shop_module.gd`, `equip_module.gd`

### scripts/battle/ — 战斗系统
- `battle_engine.gd` — tick循环 + 实体管理
- `battle_unit.gd`, `battle_skill.gd`, `battle_buff.gd`
- 80+英雄AI脚本

### assets/ — 资源 (从原项目复制)
- `ui/` — 1394个PNG图片
- `anim/` — 99个FCA动画(.ani, 需转SpriteFrames)
- `sound/` — 362个MP3音效
- `spine/` — 19个Spine动画(2.1.07格式, 待定方案)

## Important Notes

- FCA动画 .ani 是ZIP格式，内含 sheet.plist + sheet.png + sheet.key，需要专门解析器
- Spine 2.1.07数据与当前runtime不兼容，需要重新导出或用静态fallback
- CCB (.ccbi) 文件不能直接用，需要根据原布局手动重建Godot场景
- 原项目所有网络请求(ed.send)已被本地GameServer替代，无需网络层
- 旧 Axmol 代码仍在根目录 (Source/, Content/, proj.android/)，作为参考保留

## 知识库上下文

本项目的知识库位于 `D:\workspace\Obsidian\CardGame\`

### 开发会话启动时必读

1. 读取 `D:\workspace\Obsidian\CardGame\CardGame 首页.md` → 获取当前状态和待办
2. 读取 `D:\workspace\Obsidian\CardGame\wiki\MOC - 系统索引.md` → 了解所有已记录的系统模块（如有）
3. 如果涉及特定系统，读取对应 wiki 概念页

### 遇到问题时必查

- 先搜索 `D:\workspace\Obsidian\CardGame\wiki\` 下是否有相关概念页（已有决策/避坑记录）
- 再搜索 `D:\workspace\Obsidian\跨项目\Axmol-Lua\` 下是否有同类经验（其他项目踩过的坑）
- 如果找到相关记录，在实现前先参考已有方案，避免重复犯错
