#include "AppDelegate.h"
#include "lua-bindings/manual/LuaEngine.h"
#include "lua-bindings/manual/lua_module_register.h"
#include "axmol/base/Director.h"
#include "GameLuaBindings.h"
#if AX_TARGET_PLATFORM == AX_PLATFORM_WIN32 || AX_TARGET_PLATFORM == AX_PLATFORM_MAC || AX_TARGET_PLATFORM == AX_PLATFORM_LINUX
#include "axmol/platform/desktop/RenderViewImpl.h"
#endif
#include "axmol/platform/FileUtils.h"

#include <cstdio>
#include <string>
#include <cstdarg>
#include <mutex>
#if AX_TARGET_PLATFORM == AX_PLATFORM_ANDROID
#include <android/log.h>
#endif

using namespace ax;

static FILE* g_dbgFile = nullptr;
static std::mutex g_dbgMutex;

static void ensureDbgFile()
{
    if (!g_dbgFile) {
        std::string path = FileUtils::getInstance()->getWritablePath() + "ax_debug.txt";
        g_dbgFile = fopen(path.c_str(), "a");
    }
}

static int lua_LegendLog(lua_State* L)
{
    const char* msg = luaL_checkstring(L, 1);
    if (msg) {
#if AX_TARGET_PLATFORM == AX_PLATFORM_WIN32
        OutputDebugStringA(msg);
        OutputDebugStringA("\n");
#elif AX_TARGET_PLATFORM == AX_PLATFORM_ANDROID
        __android_log_print(ANDROID_LOG_INFO, "CardGame", "%s", msg);
#endif
        std::lock_guard<std::mutex> lk(g_dbgMutex);
        ensureDbgFile();
        if (g_dbgFile) { fprintf(g_dbgFile, "%s\n", msg); fflush(g_dbgFile); }
    }
    return 0;
}

static void dbg(const char* fmt, ...)
{
    char buf[1024];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
#if AX_TARGET_PLATFORM == AX_PLATFORM_WIN32
    OutputDebugStringA(buf);
    OutputDebugStringA("\n");
#elif AX_TARGET_PLATFORM == AX_PLATFORM_ANDROID
    __android_log_print(ANDROID_LOG_INFO, "CardGame", "%s", buf);
#endif
    std::lock_guard<std::mutex> lk(g_dbgMutex);
    ensureDbgFile();
    if (g_dbgFile) { fprintf(g_dbgFile, "%s\n", buf); fflush(g_dbgFile); }
}

AppDelegate::AppDelegate() {}
AppDelegate::~AppDelegate() {}

void AppDelegate::initContextAttrs()
{
    dbg("[A1] initContextAttrs");
    ContextAttrs contextAttrs = {.powerPreference = PowerPreference::HighPerformance};
    setContextAttrs(contextAttrs);
}

bool AppDelegate::applicationDidFinishLaunching()
{
    char pidBuf[32];
#if AX_TARGET_PLATFORM == AX_PLATFORM_WIN32
    snprintf(pidBuf, sizeof(pidBuf), "[B0] PID=%lu", (unsigned long)GetCurrentProcessId());
#else
    snprintf(pidBuf, sizeof(pidBuf), "[B0] PID=%d", getpid());
#endif
    dbg(pidBuf);
    dbg("[B1] applicationDidFinishLaunching");
    Director::getInstance()->setAnimationInterval(1.0 / 60.0f);
    dbg("[B2] setAnimationInterval done");

    auto engine = LuaEngine::getInstance();
    ScriptEngineManager::getInstance()->setScriptEngine(engine);
    lua_State* L = engine->getLuaStack()->getLuaState();
    lua_module_register(L);
    dbg("[B3] lua_module_register done");

    register_game_bindings(L);
    dbg("[B3b] game bindings registered");

    // Register LegendLog
    lua_pushcfunction(L, lua_LegendLog);
    lua_setglobal(L, "LegendLog");
    dbg("[B3c] LegendLog registered");

    LuaStack* stack = engine->getLuaStack();
    // 添加 writable path 到搜索路径最前面，允许 sdcard 上的 hotfix 文件覆盖 APK 内的文件
    std::string writablePath = FileUtils::getInstance()->getWritablePath();
    if (!writablePath.empty()) {
        auto paths = FileUtils::getInstance()->getSearchPaths();
        paths.insert(paths.begin(), writablePath);
        FileUtils::getInstance()->setSearchPaths(paths);
        dbg("[B4a] writable search path: %s", writablePath.c_str());
    }
    stack->addSearchPath("src");
    FileUtils::getInstance()->addSearchPath("res");
    dbg("[B4] search paths set");

    auto director = Director::getInstance();
#if AX_TARGET_PLATFORM == AX_PLATFORM_WIN32 || AX_TARGET_PLATFORM == AX_PLATFORM_MAC || AX_TARGET_PLATFORM == AX_PLATFORM_LINUX
    if (!director->getRenderView())
    {
        auto view = RenderViewImpl::createWithRect("CardGame", Rect(0, 0, 960, 640));
        director->setRenderView(view);
        dbg("[B5] RenderView created");
    }
#endif

    // 设置设计分辨率（Android/iOS 上由 Java/ObjC 创建 RenderView，需要 C++ 侧设置设计分辨率）
    if (auto view = director->getRenderView())
    {
        auto ws = view->getWindowSize();
        dbg("[B5b] BEFORE setDesignResolution: WindowSize=%.0fx%.0f", ws.width, ws.height);
        view->setDesignResolutionSize(800, 480, ResolutionPolicy::EXACT_FIT);
        // 设置清屏颜色为天空色，与 Lua 侧 basescene.lua 的背景层一致
        director->setClearColor(ax::Color(0.53f, 0.82f, 0.92f, 1.0f));
        auto ds = view->getDesignResolutionSize();
        dbg("[B5c] AFTER setDesignResolution: DesignRes=%.0fx%.0f", ds.width, ds.height);
        dbg("[B5d] ScaleX=%.3f ScaleY=%.3f", view->getScaleX(), view->getScaleY());
        auto vp = view->getViewportRect();
        dbg("[B5e] ViewportRect: origin=(%.0f,%.0f) size=(%.0fx%.0f)", vp.origin.x, vp.origin.y, vp.size.width, vp.size.height);
    }

    // Test Lua engine
    dbg("[B6a] About to test Lua engine...");
    int pr = luaL_dostring(L, "return 1+1");
    if (pr == 0) {
        dbg("[B6b] Lua basic test OK");
    } else {
        dbg("[B6b] Lua basic test FAILED");
    }
    dbg("[B6] Lua engine test done");

    // Provide an initial scene so Lua's pushScene/replaceScene can work
    auto initScene = Scene::create();
    Director::getInstance()->runWithScene(initScene);
    dbg("[B7] initial scene created");

    int ret = engine->executeString("require 'main'");
    if (ret)
    {
        dbg("[B8] require 'main' FAILED");
        return false;
    }
    dbg("[B9] require 'main' OK");
    return true;
}

void AppDelegate::applicationDidEnterBackground()
{
    Director::getInstance()->stopAnimation();
}

void AppDelegate::applicationWillEnterForeground()
{
    Director::getInstance()->startAnimation();
}
void AppDelegate::applicationWillQuit()
{
    std::lock_guard<std::mutex> lk(g_dbgMutex);
    if (g_dbgFile)
    {
        fflush(g_dbgFile);
        fclose(g_dbgFile);
        g_dbgFile = nullptr;
    }
}
