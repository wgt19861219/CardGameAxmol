# 刀塔卡牌

一款基于 Axmol 引擎（cocos2d-x 分支）的卡牌手游单机版。原项目为 cocos2d-x 2.x 客户端 + PHP 服务端架构，已完全本地化，无需服务器即可运行。

## 截图

<!-- 截图待添加 -->

## 特性

- 完整 PVE 流程：主线关卡、精英副本、远征
- 卡牌收集与养成：英雄招募、装备强化、技能升级
- 战斗系统：自动战斗 + 实时技能释放
- 竞技场 PVP（本地模拟）
- 排行榜、任务、商店、背包等完整系统
- 中文界面

## 技术栈

| 组件 | 技术 |
|------|------|
| 引擎 | Axmol (cocos2d-x 分支) |
| 语言 | Lua + C++ |
| 平台 | Android |
| 分辨率 | 960x640 (HVGA 横屏) |
| 原服务端 | PHP → 已迁移为本地 Lua 模块 |

## 编译

### 前置依赖

- [Axmol Engine](https://github.com/axmolengine/axmol) (设置 `AX_ROOT` 环境变量)
- Android SDK + NDK (r25c+)
- CMake 3.22+
- Gradle 7.x

### 编译步骤

```bash
# 1. 克隆仓库
git clone https://github.com/wgt19861219/CardGameAxmol.git
cd CardGameAxmol

# 2. 确保 Axmol 引擎已安装
# Windows: 设置 AX_ROOT 环境变量指向 axmol 目录
# 或将 axmol 放在项目根目录下

# 3. 编译 Android APK
cd proj.android
./gradlew assembleRelease
```

生成的 APK 在 `proj.android/app/build/outputs/apk/release/`。

## 下载

最新版本 APK 请到 [Releases](https://github.com/wgt19861219/CardGameAxmol/releases) 页面下载。

## 项目结构

```
CardGameAxmol/
├── Content/
│   ├── res/          # 游戏资源 (图片/动画/音效/Spine)
│   │   ├── UI/       # 界面图片
│   │   ├── anim/     # FCA 动画
│   │   ├── sound/    # 音效
│   │   └── spine/    # Spine 动画
│   └── src/          # Lua 源码
│       ├── ui/       # 界面模块
│       ├── battle/   # 战斗系统
│       └── ...       # 其他游戏逻辑
├── proj.android/     # Android 工程配置
├── Source/           # C++ 原生代码
└── CMakeLists.txt    # CMake 构建配置
```

## 协议

本项目基于 [MIT License](LICENSE) 开源。
