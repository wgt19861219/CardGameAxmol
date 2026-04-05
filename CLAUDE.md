# CLAUDE.md

## Project Overview

卡牌手游项目，从 cocos2d-x 2.x 迁移到 **Axmol** 引擎。只保留 Android 端开发。

## Build

- **项目路径**: `D:\workspace\projects\CardGameAxmol`
- **构建**: `cd proj.android && ./gradlew assembleDebug`
- **APK输出**: `proj.android/app/build/outputs/apk/debug/CardGame-debug.apk`
- **安装**: `adb -s 192.168.1.16:5555 install -r <apk>`
- **日志**: `adb -s 192.168.1.16:5555 logcat -d | grep axmol`
- **包名**: `dev.axmol.cardgame`
- **Activity**: `dev.axmol.app.AppActivity`
- **模拟器**: MuMu (`adb connect 192.168.1.16:5555`)
- **C++标准**: C++20 (Axmol要求)
- **引擎**: Axmol 3.0.0

## Architecture

### Source/ (C++)
- `AppDelegate.cpp` — 应用入口，Lua引擎初始化
- `GameLuaBindings.cpp` — C++到Lua的绑定（CCBContainer, SpineContainer, LegendAnimation等）
- `CCBContainer.cpp` — CocoStudio CCB UI加载器
- `SpineContainer.cpp` — Spine动画容器（4.x runtime，2.x数据不兼容会fallback）
- `LegendAnimation.cpp` — FCA格式帧动画系统（LegendAnimation + LegendAnimationEffect）
- `LegendAnimationFileInfo.cpp` — FCA二进制格式解析器（ZIP内含sheet.plist/sheet.png/sheet.key）
- `GameAnimation.cpp` — 动画基类

### Content/src/ (Lua)
- `main.lua` — 入口
- `compat_cocos2dx.lua` — cocos2d-x兼容层
- `local_server.lua` — 本地服务器模拟（拦截ed.send，处理所有网络请求）
- `network.lua` — 网络层
- `resource_manager.lua` — 资源管理（createFcaNode, createFcaActor等）
- `ui/` — UI模块（framework.lua, main.lua, shortcut.lua等）
- `ui/parameter/uires.lua` — UI参数配置

### Content/res/
- `UI/alpha/HVGA/` — UI图片资源（含.pvr.ccz打包的合图）
- `anim/` — FCA动画文件（.ani格式，ZIP包含sprite+key数据）
- `ccbi/` — CocoStudio二进制UI文件
- `spine/` — Spine动画数据
- `sound/` — 音效

## Important Notes

- Lua绑定中 `LegendAminationEffect` (拼写错误) 是故意保留的，Lua脚本用的是这个名字
- Spine 2.x数据与4.x runtime不兼容，会返回fallback空Node
- local_server.lua 使用同步执行模式模拟服务器响应
- FCA动画的 .ani 文件是ZIP格式，内含 sheet.plist + sheet.png + sheet.key
- 占位图不要生成到 Content/res/UI/alpha/HVGA/ 下——原项目已有真实资源的会被覆盖
