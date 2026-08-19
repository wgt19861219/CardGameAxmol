# AGENTS.md — CardGameAxmol 工作区指南

## 项目定位

刀塔卡牌单机版:Axmol(cocos2d-x 分支)引擎,Lua 5.1 + C++,Android 平台,**设计分辨率 800x480 横屏**(实测 `ax_debug.txt` 的 `setDesignResolution` 输出;1920x1080 屏幕上 ScaleX=2.4/ScaleY=2.25)。原架构为 cocos2d-x 2.x 客户端 + PHP 服务端,已完全本地化——所有网络请求被 `Content/src/local_server.lua` 在客户端 Lua 层拦截并模拟服务端响应,无真实网络层。

**注意**:根目录 `CLAUDE.md` 描述的是兄弟项目(Godot 4.5 重写版,位于 `D:\workspace\projects\CardGame\`),不是本仓库。本仓库(Axmol 版)在 `Content/src/` 持续活跃开发,以 git log 为准。

相关路径:
- 原项目参考:客户端 `D:\workspace\projects\HC\Client\Resource_Client\`,PHP 服务端 `D:\workspace\projects\HC\Server\GameServer\server2\`
- Axmol 引擎:根目录 `axmol` 符号链接 → `D:\workspace\projects\AxmolEngine`
- 知识库:`D:\workspace\Obsidian\CardGame\`(会话启动先读其首页与系统索引 MOC;遇到问题先查 `wiki/` 概念页和 `D:\workspace\Obsidian\跨项目\Axmol-Lua\`)

## 目录结构

| 目录 | 内容 |
|------|------|
| `Content/src/` | **Lua 主体(git 跟踪,活跃开发区)**。入口 `main.lua`;数据表 `*.lua`(如 `StageDungeon.lua`);`local_server.lua` 本地服务端;`player.lua`/`playertools.lua` 玩家数据;`ui/` 界面模块;`battle/` 战斗系统(`battle_engine.lua`、`battle_scene.lua`、`heroes/` AI);`language/` 多语言(主用 `zh-CN.lua`);`util/`、`gamedatatables/`、`tutorial/`、`activity/` |
| `Source/` | C++ 原生层:AppDelegate、CCBContainer/CCBReader、GameAnimation、LegendAnimation(FCA)、SpineContainer、GameLuaBindings。稳定,很少改动 |
| `Content/res/` | 资源:UI 图片(`UI/`)、FCA 动画(`anim/`)、音效(`sound/`)、Spine(`spine/`) |
| `proj.android/` | Android 工程(gradle + CMake),构建产物在此 |
| `docs/superpowers/` | `plans/`(实施计划)与 `specs/`(设计文档),按 `YYYY-MM-DD-主题.md` 命名 |

**未跟踪目录坑**:`Content/gametable/`、`Content/installer/`、`Content/hot_update.json` 本地存在但未被 git 跟踪,而 `maingameproject.lua` 引用了 `gametable/*` 模块——本地能跑、全新 clone 会缺,改这些文件时没有版本历史兜底。根目录还有大量临时 txt/png/调试文件,均未跟踪,不要动也不要提交。

## 构建与验证

```bash
# Android APK(产物在 proj.android/app/build/outputs/apk/release/)
cd proj.android && ./gradlew assembleRelease

# Lua 语法检查(本机已装 Lua 5.1)
"/c/Program Files (x86)/Lua/5.1/luac" -p Content/src/<文件>.lua
# 批量:参照 Content/src/luacall.sh 的 find + luac 模式
```

- 无 Windows 工程目录,本机不跑桌面版;运行时验证靠 Android 设备/模拟器 + adb 截图(截图惯例见 `.gitignore` 中的 `screen_*.png`、`screenshot*.png` 模式,历史截图在 `docs/screenshots/`)。
- 运行日志:`main.lua` 把 Lua print 重定向到工作目录 `lua_debug.log`(已 ignore);C++ 侧调试输出 `ax_debug.txt`、`game_stdout.txt`(已 ignore);战斗/性能诊断 `files/perf.log`(每 5 秒逻辑帧率 + Lua 堆,`hello.lua` gameUpdate 写入)。
- 无自动化测试;改 Lua 后至少跑 `luac -p` 语法检查,涉及战斗/UI 的改动用截图对比验证。

## 模拟器测试基础设施(2026-08-19 全量回归沉淀)

- **debugcmd.lua 注入通道**:`hello.lua` gameUpdate 每 2 秒轮询 `files/debugcmd.lua`,存在则 loadstring 执行并删除;print 输出进 logcat `[LUA-print]` 标签。注入方式:`cat x.lua | adb shell "run-as dev.axmol.cardgame sh -c 'cat > files/debugcmd.lua'"`。**注入脚本必须先过 `luac -p`**(语法错会被 loadstring 静默跳过)。
- **辅助脚本**:`docs/screenshots/test0819/` 下 `inject.sh`(带 3 次重试注入)、`tap_test.sh`(点击+截图+验证)、`batch_goto.sh`(入口批量驱动)、`cmd_*.lua`(场景 dump/popScene/战斗进场等注入片段)。
- **按钮直调**:`ed.getCurrentScene():getMainButtonHandler(key)()` 与真实点击同路径(14 个入口 key 见 `ui/parameter/mainres.lua` button_key);快捷栏走 `ui/framework.lua` getSCButtonTouchHandler。
- **MuMu 模拟器坑**:多 display(4/6/7 随 am start 漂移),`input tap` 必须带 `-d <FocusedDisplayId>` 且仍可能间歇失效(monkey 也 Injection Failed)——注入通道比 input 稳定,优先用;Android 返回键会把游戏切后台进 freezer,用注入 `ed.popScene()` 代替;`adb exec-out screencap > file` 在 Git Bash 下会被输出污染,须设备端 screencap 后 pull,目标路径用 Windows 风格 + `MSYS_NO_PATHCONV=1`。
- **坐标换算**:world_x = screen_x/2.4,world_y = 480 − screen_y/2.25;按钮位置 = mainres.lua res_pos 的 pos + touchCenter,再按其 parent container 偏移(pve 在 subContainer,volcano 在 middleContainer,其余 topContainer)。

## 架构与加载链(改代码前必读)

1. `Content/src/main.lua` 是唯一入口:加载顺序 = `config` → 全局桩(stub,补 tolua/Legend* 接口)→ axmol core → 兼容层 → 游戏模块 → 场景。全局命名空间 `ed` 在 `main.lua:120` 创建(`rawset(_G, "ed", {})`)。
2. **新模块必须注册进 `Content/src/maingameproject.lua` 的 `ed.needLoadFiles` 列表**,否则不会被加载(`main.lua` 按该列表逐个 require)。
3. **数据表机制**(`Content/src/datatable.lua`):`ed.getDataTable("表名")` 先 `require(表名)`(即 `Content/src/<表名>.lua` 导出的纯 Lua 表),失败再找 `csv/<表名>.csv`。游戏数据(关卡、英雄、技能、副本)全是这套,新增配置表 = 在 `Content/src/` 建同名 Lua 文件 + 注册加载。
4. `local_server.lua` 是"服务端":处理请求路由、掉落判定、存档(`local_save_data`)。改玩法逻辑(掉落、次数、货币)大多落在这里,而不是 UI 文件。
5. 货币/次数系统:玩家点数走 `player._points` + `playertools.lua` 的 `addPoint`(新增货币类型在此扩展);次数限制配置在 `Content/src/playerlimit.lua`。
6. UI:基于 CCB(.ccbi)布局 + Lua 控制器(`ui/*.lua`);新 UI 文本进 `Content/src/language/zh-CN.lua`(其余 6 个语言文件按需同步)。`ui/UiRegister.lua` 的 `UIREGISTERTABLE` 是遗留空壳,不用管。
7. 战斗:`battle/battle_engine.lua` tick 循环 + 实体;英雄 AI 在 `battle/heroes/`;副本 Boss 多波次战斗的波次/难度数据在 `StageDungeon.lua` + `ActStageGroupDungeon.lua`(ID 段已迁移到 5xxxx,勿再用 4xxxx)。

## C++ 层注意事项(动 Source/ 前必读)

- FCA 动画 `.ani` 是 ZIP 格式(sheet.plist + sheet.png + sheet.key),由 `LegendAnimation*` 解析;Spine 是 2.1.07 老格式,与新版 runtime 不兼容(由 `SpineContainer` 兼容处理);`.ccbi` 不能直接编辑,布局改动需在 Lua 侧重建。
- 改 C++ 需要重新编译 APK 才能验证,成本高;优先在 Lua 层解决。

## Git 与流程约定

- Commit 风格(见 git log):Conventional Commits,type 英文前缀 + 中文 subject,如 `feat: 副本Boss 3波战斗 + 波次自动切换`。默认分支 `master`,遵循全局规则:不开破坏性提交、不推 force。
- 功能开发流程:先用 superpowers `writing-plans` 写计划到 `docs/superpowers/plans/YYYY-MM-DD-主题.md`(设计文档进 `specs/`),再 `executing-plans` 逐任务执行——docs 下已有文档均按此模式组织。
- `.gitignore` 已忽略构建产物、签名文件(`*.jks`/`*.keystore`/`gradle.properties`)与各类调试输出;不要把截图和临时分析 txt 提交入库。
