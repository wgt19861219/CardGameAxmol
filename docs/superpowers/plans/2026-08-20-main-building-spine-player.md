# 主界面建筑图标散件缺失修复 —— 纯 Lua Spine 2.1.07 播放器(借鉴 CardGame2)

- 日期:2026-08-20
- 状态:执行中
- 参考实现:`D:\workspace\projects\CardGame2\scripts\ui\spine_skeleton.gd` + `spine_skeleton_data.gd` + `spine_atlas.gd`

## 问题根因(调研结论)

主界面 16 个建筑图标(`Content/src/ui/parameter/mainres.lua` res_pos 中 `aniType = 1`)全部是 Spine **2.1.07** 老格式资源(`Content/res/spine/eff_UI_Main_*/`),而 `Source/SpineContainer.cpp:44-56` 遇 `"spine":"2.x"` 数据直接返回 nullptr(4.x runtime 不兼容 2.x)。Lua 侧 `Content/src/resource_manager.lua:594-595` 回退到 `createStaticSpriteFromSpineAtlas` —— 只挑 atlas 里面积最大的一张散件当静态图。结果:建筑主体在,风车/光效/序列帧等散件全部缺失,且无动画。

## 方案

Lua 层实现 Spine 2.1.07 region-only 播放器,插入 `createFcaNode` 回退链。不改 C++。

### 改动

1. 新建 `Content/src/spineplayer.lua`:骨骼 CCNode 层级 + slot CCSprite + onUpdate 逐帧插值(移植 spine_skeleton.gd 算法:curve 贝塞尔/stepped/linear、角度最短路径防自旋、attachment 序列帧、color 插值);接口 setAction/setNextAction/setLoop 做实 + addStubMethods
2. `resource_manager.lua`:parseSpineJson 补保留 animations;导出 ed.getOrParseSpineData / ed.parseAtlasRegions / ed.addStubMethods;createFcaNode 回退链插入 createSpinePlayer(单张静态图之前)
3. `maingameproject.lua`:needLoadFiles 注册 spineplayer.lua

### 坐标系/符号(cocos 版相对 CardGame2 的简化)

- cocos y 向上与 Spine 一致:无 y 翻转、无 flip_y
- bone/attachment rotation 逆时针正 = cocos setRotation 同号(HC `Code_Core/extensions/spine/RegionAttachment.c` 顶点数学验证)
- atlas rect 左上原点直用(现有静态回退已验证)
- rotate region(Pve/Guard 各 4 个):存储 rect 宽高互换切图后 setRotation(±90),方向实测校准

### 验证

luac -p → gradlew assembleRelease → 模拟器主界面截图对比 16 建筑散件完整性 → lua_debug.log [spine-player] 日志 → perf.log 帧率对比。

### 影响面

- 其他 createFcaNode 调用方资源不在 spine/ 目录,零影响
- tutorialres.lua 的 eff_UI_Main_Guard 顺带升级为完整动画(正向)
- serverlogin 中 Guard 调用是注释掉的死代码
