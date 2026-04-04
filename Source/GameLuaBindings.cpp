#include "GameLuaBindings.h"
#include "CCBContainer.h"
#include "SpineContainer.h"
#include "axmol/axmol.h"

extern "C" {
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}

using namespace ax;

// lua_pushcfunction 是宏 #define lua_pushcfunction(L,f) lua_pushcclosure(L,(f),0)
// Lambda 中的逗号会被当作宏参数分隔符，重新定义为 inline 函数
#undef lua_pushcfunction
// 不用宏！用 inline 函数避免 lambda 中逗号被当作宏参数分隔符
inline void lua_pushcfunction(lua_State* L, lua_CFunction f) { lua_pushcclosure(L, f, 0); }

// ========================================================================
// tolua 全局函数
// ========================================================================

static int lua_tolua_isnull(lua_State* L)
{
    if (lua_isnil(L, 1)) {
        lua_pushboolean(L, 1);
        return 1;
    }
    // 尝试获取 userdata 指针
    void** p = (void**)lua_touserdata(L, 1);
    if (p && *p == nullptr) {
        lua_pushboolean(L, 1);
        return 1;
    }
    lua_pushboolean(L, 0);
    return 1;
}

static int lua_tolua_CAST(lua_State* L)
{
    // tolua._CAST(obj, "TypeName") — 类型转换 stub
    if (lua_gettop(L) >= 1) {
        lua_pushvalue(L, 1);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

// ========================================================================
// CCBContainer 绑定
// ========================================================================

static int lua_CCBContainer_create(lua_State* L)
{
    auto* obj = CCBContainer::create();
    if (obj) {
        // 将 CCBContainer* 作为 ax::Node* 推送到 Lua（复用 Axmol 已有的 Node 绑定）
        lua_getglobal(L, "CCBContainer");
        if (lua_istable(L, -1)) {
            // 直接 push userdata
            void** ud = (void**)lua_newuserdata(L, sizeof(void*));
            *ud = obj;
            obj->retain();

            // 设置元表为 CCBContainer
            luaL_getmetatable(L, "CCBContainer_mt");
            if (lua_isnil(L, -1)) {
                lua_pop(L, 1);
                // fallback: 设置为 Node
                luaL_getmetatable(L, "ax.Node");
            }
            lua_setmetatable(L, -2);
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int lua_CCBContainer_loadCcbiFile(lua_State* L)
{
    auto* self = *(CCBContainer**)lua_touserdata(L, 1);
    const char* file = luaL_checkstring(L, 2);
    bool forceLoad = false;
    if (lua_gettop(L) >= 3 && lua_isboolean(L, 3))
        forceLoad = lua_toboolean(L, 3);
    if (self && file)
        self->loadCcbiFile(file, forceLoad);
    return 0;
}

static int lua_CCBContainer_runAnimation(lua_State* L)
{
    auto* self = *(CCBContainer**)lua_touserdata(L, 1);
    const char* name = luaL_checkstring(L, 2);
    if (self && name)
        self->runAnimation(name);
    return 0;
}

static int lua_CCBContainer_hasAnimation(lua_State* L)
{
    auto* self = *(CCBContainer**)lua_touserdata(L, 1);
    const char* name = luaL_checkstring(L, 2);
    bool ret = false;
    if (self && name)
        ret = self->hasAnimation(name);
    lua_pushboolean(L, ret);
    return 1;
}

static int lua_CCBContainer_getVariable(lua_State* L)
{
    auto* self = *(CCBContainer**)lua_touserdata(L, 1);
    const char* name = luaL_checkstring(L, 2);
    if (self && name) {
        auto* obj = self->getVariable(name);
        if (obj) {
            // 推送为 ax::Node* userdata
            void** ud = (void**)lua_newuserdata(L, sizeof(void*));
            *ud = obj;
            luaL_getmetatable(L, "ax.Node");
            if (!lua_isnil(L, -1))
                lua_setmetatable(L, -2);
            else
                lua_pop(L, 1);
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int lua_CCBContainer_getCCNodeFromCCB(lua_State* L)
{
    auto* self = *(CCBContainer**)lua_touserdata(L, 1);
    const char* name = luaL_checkstring(L, 2);
    if (self && name) {
        auto* node = self->getCCNodeFromCCB(name);
        if (node) {
            void** ud = (void**)lua_newuserdata(L, sizeof(void*));
            *ud = node;
            luaL_getmetatable(L, "ax.Node");
            if (!lua_isnil(L, -1))
                lua_setmetatable(L, -2);
            else
                lua_pop(L, 1);
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int lua_CCBContainer_getCCSpriteFromCCB(lua_State* L)
{
    auto* self = *(CCBContainer**)lua_touserdata(L, 1);
    const char* name = luaL_checkstring(L, 2);
    if (self && name) {
        auto* sp = self->getCCSpriteFromCCB(name);
        if (sp) {
            void** ud = (void**)lua_newuserdata(L, sizeof(void*));
            *ud = sp;
            luaL_getmetatable(L, "ax.Sprite");
            if (!lua_isnil(L, -1))
                lua_setmetatable(L, -2);
            else
                lua_pop(L, 1);
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int lua_CCBContainer_registerFunctionHandler(lua_State* L)
{
    auto* self = *(CCBContainer**)lua_touserdata(L, 1);
    int handler = (int)luaL_checkinteger(L, 2);
    if (self)
        self->registerFunctionHandler(handler);
    return 0;
}

static int lua_CCBContainer_unregisterFunctionHandler(lua_State* L)
{
    auto* self = *(CCBContainer**)lua_touserdata(L, 1);
    if (self)
        self->unregisterFunctionHandler();
    return 0;
}

static int lua_CCBContainer_unload(lua_State* L)
{
    auto* self = *(CCBContainer**)lua_touserdata(L, 1);
    if (self)
        self->unload();
    return 0;
}

static int lua_CCBContainer_getLoaded(lua_State* L)
{
    auto* self = *(CCBContainer**)lua_touserdata(L, 1);
    lua_pushboolean(L, self ? self->getLoaded() : false);
    return 1;
}

static int lua_CCBContainer_getCurAnimationDoneName(lua_State* L)
{
    auto* self = *(CCBContainer**)lua_touserdata(L, 1);
    if (self)
        lua_pushstring(L, self->getCurAnimationDoneName().c_str());
    else
        lua_pushstring(L, "");
    return 1;
}

static int lua_CCBContainer_setAllChildColor(lua_State* L)
{
    auto* self = *(CCBContainer**)lua_touserdata(L, 1);
    int r = (int)luaL_checkinteger(L, 2);
    int g = (int)luaL_checkinteger(L, 3);
    int b = (int)luaL_checkinteger(L, 4);
    if (self)
        self->setAllChildColor((unsigned char)r, (unsigned char)g, (unsigned char)b);
    return 0;
}

static int lua_CCBContainer_setCCBFilePath(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);
    if (path)
        CCBContainer::setCCBFilePath(path);
    return 0;
}

static int lua_CCBContainer_dumpInfo(lua_State* L)
{
    auto* self = *(CCBContainer**)lua_touserdata(L, 1);
    if (self)
        AXLOGW("CCBContainer dumpInfo not implemented");
    return 0;
}

static int lua_CCBContainer_playAutoPlaySequence(lua_State* L)
{
    auto* self = *(CCBContainer**)lua_touserdata(L, 1);
    if (self)
        self->playAutoPlaySequence();
    return 0;
}

// CCBContainer __gc 元方法
static int lua_CCBContainer_gc(lua_State* L)
{
    auto** self = (CCBContainer**)lua_touserdata(L, 1);
    if (self && *self) {
        (*self)->release();
        *self = nullptr;
    }
    return 0;
}

// ========================================================================
// Stub 类注册辅助宏
// ========================================================================

static void register_stub_singleton(lua_State* L, const char* className)
{
    // 创建一个空表作为单例类
    lua_newtable(L);
    // 设置 __index 指向自身（方法调用返回 nil 而非报错）
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    // 给每个方法调用返回一个空函数
    lua_pushstring(L, className);
    lua_pushcclosure(L, [](lua_State* L) -> int {
        const char* name = lua_tostring(L, lua_upvalueindex(1));
        AXLOGW("Stub class {} method called, returning nil", name);
        lua_pushnil(L);
        return 1;
    }, 1);
    lua_setfield(L, -2, "__call");

    lua_setglobal(L, className);
}

// 注册带方法的 stub 类（getInstance 返回类表自身，支持链式调用）
static void register_stub_class(lua_State* L, const char* className,
                                const std::vector<std::string>& methods)
{
    lua_newtable(L);  // 方法表
    for (const auto& method : methods) {
        lua_pushstring(L, className);
        lua_pushstring(L, method.c_str());
        lua_pushcclosure(L, [](lua_State* L) -> int {
            const char* cls = lua_tostring(L, lua_upvalueindex(1));
            const char* mtd = lua_tostring(L, lua_upvalueindex(2));
            AXLOGD("Stub {}.{}() called", cls, mtd);
            // getInstance/getInstance 返回类表自身（支持链式调用）
            if (strcmp(mtd, "getInstance") == 0) {
                lua_getglobal(L, cls);
                return 1;
            }
            lua_pushnil(L);
            return 1;
        }, 2);
        lua_setfield(L, -2, method.c_str());
    }

    // 创建 metatable 用于实例
    luaL_newmetatable(L, (std::string(className) + "_mt").c_str());
    lua_pushvalue(L, -2);  // 复制方法表
    lua_setfield(L, -2, "__index");
    lua_pop(L, 1);  // pop metatable

    // 设置全局
    lua_setglobal(L, className);
}

// ========================================================================
// 主注册函数
// ========================================================================

// tolua++ 类型别名注册：让 tolua.cast(obj, "CCNode") 能找到 ax.Node 的 metatable
static void register_type_aliases(lua_State* L)
{
    struct Alias { const char* oldName; const char* newName; };
    static const Alias aliases[] = {
        {"CCNode", "ax.Node"},
        {"CCSprite", "ax.Sprite"},
        {"CCScene", "ax.Scene"},
        {"CCLayer", "ax.Layer"},
        {"CCAction", "ax.Action"},
        {"CCBone", "ax.Bone"},
        {"CCMoveTo", "ax.MoveTo"},
        {"CCMoveBy", "ax.MoveBy"},
        {"CCSequence", "ax.Sequence"},
        {"CCRepeatForever", "ax.RepeatForever"},
        {"CCEaseSineOut", "ax.EaseSineOut"},
        {"CCEaseSineInOut", "ax.EaseSineInOut"},
        {"CCDelayTime", "ax.DelayTime"},
        {"CCCallFunc", "ax.CallFunc"},
        {"CCScaleTo", "ax.ScaleTo"},
        {"CCScaleBy", "ax.ScaleBy"},
        {"CCSpawn", "ax.Spawn"},
        {"CCAnimate", "ax.Animate"},
        {"CCAnimation", "ax.Animation"},
        {"CCFadeIn", "ax.FadeIn"},
        {"CCFadeOut", "ax.FadeOut"},
        {"CCFadeTo", "ax.FadeTo"},
        {"CCBlink", "ax.Blink"},
        {"CCTintTo", "ax.TintTo"},
        {"CCRotateTo", "ax.RotateTo"},
        {"CCRotateBy", "ax.RotateBy"},
        {"CCJumpBy", "ax.JumpBy"},
        {"CCCardinalSplatBy", "ax.CardinalSplineBy"},
        {"CCBezierBy", "ax.BezierBy"},
    };
    for (const auto& a : aliases) {
        luaL_getmetatable(L, a.newName);
        if (!lua_isnil(L, -1)) {
            lua_pop(L, 1);
            // 注册别名：将 CC* 名映射到 ax.* 的 metatable
            luaL_getmetatable(L, a.newName);
            lua_setfield(L, LUA_REGISTRYINDEX, a.oldName);
            // 也在 tolua 的 super 表中注册继承关系
        } else {
            lua_pop(L, 1);
        }
    }
}

int register_game_bindings(lua_State* L)
{
    // ---- tolua 全局 ----
    lua_getglobal(L, "tolua");
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
        lua_newtable(L);
        lua_setglobal(L, "tolua");
        lua_getglobal(L, "tolua");
    }
    lua_pushcfunction(L, lua_tolua_isnull);
    lua_setfield(L, -2, "isnull");
    lua_pushcfunction(L, lua_tolua_CAST);
    lua_setfield(L, -2, "_CAST");
    lua_pop(L, 1);  // pop tolua table

    // ---- 注册 CC* → ax.* 类型别名（让 tolua.cast 能工作） ----
    register_type_aliases(L);

    // ---- CCBContainer ----
    // 创建 CCBContainer 元表
    luaL_newmetatable(L, "CCBContainer_mt");

    // 方法表
    lua_newtable(L);
    lua_pushcfunction(L, lua_CCBContainer_loadCcbiFile);
    lua_setfield(L, -2, "loadCcbiFile");
    lua_pushcfunction(L, lua_CCBContainer_runAnimation);
    lua_setfield(L, -2, "runAnimation");
    lua_pushcfunction(L, lua_CCBContainer_hasAnimation);
    lua_setfield(L, -2, "hasAnimation");
    lua_pushcfunction(L, lua_CCBContainer_getVariable);
    lua_setfield(L, -2, "getVariable");
    lua_pushcfunction(L, lua_CCBContainer_getCCNodeFromCCB);
    lua_setfield(L, -2, "getCCNodeFromCCB");
    lua_pushcfunction(L, lua_CCBContainer_getCCSpriteFromCCB);
    lua_setfield(L, -2, "getCCSpriteFromCCB");
    lua_pushcfunction(L, lua_CCBContainer_registerFunctionHandler);
    lua_setfield(L, -2, "registerFunctionHandler");
    lua_pushcfunction(L, lua_CCBContainer_unregisterFunctionHandler);
    lua_setfield(L, -2, "unregisterFunctionHandler");
    lua_pushcfunction(L, lua_CCBContainer_unload);
    lua_setfield(L, -2, "unload");
    lua_pushcfunction(L, lua_CCBContainer_getLoaded);
    lua_setfield(L, -2, "getLoaded");
    lua_pushcfunction(L, lua_CCBContainer_getCurAnimationDoneName);
    lua_setfield(L, -2, "getCurAnimationDoneName");
    lua_pushcfunction(L, lua_CCBContainer_setAllChildColor);
    lua_setfield(L, -2, "setAllChildColor");
    lua_pushcfunction(L, lua_CCBContainer_dumpInfo);
    lua_setfield(L, -2, "dumpInfo");
    lua_pushcfunction(L, lua_CCBContainer_playAutoPlaySequence);
    lua_setfield(L, -2, "playAutoPlaySequence");

    lua_setfield(L, -2, "__index");

    // __gc
    lua_pushcfunction(L, lua_CCBContainer_gc);
    lua_setfield(L, -2, "__gc");
    lua_pop(L, 1);  // pop metatable

    // CCBContainer 全局表（含 create 静态方法和 setCCBFilePath）
    lua_newtable(L);
    lua_pushcfunction(L, lua_CCBContainer_create);
    lua_setfield(L, -2, "create");
    lua_pushcfunction(L, lua_CCBContainer_setCCBFilePath);
    lua_setfield(L, -2, "setCCBFilePath");
    lua_setglobal(L, "CCBContainer");

    // ---- SpineContainer 真正绑定 ----
    luaL_newmetatable(L, "SpineContainer_mt");

    // 方法表
    lua_newtable(L);

    // create(path, name, scale=1.0) -> SpineContainer
    // 支持 SpineContainer:create(...) 冒号调用（self 是 table）和 . 点调用
    lua_pushcfunction(L, [](lua_State* L) -> int {
        int argOffset = 0;
        if (lua_type(L, 1) != LUA_TSTRING) argOffset = 1; // 冒号调用，跳过 self
        const char* path = luaL_checkstring(L, 1 + argOffset);
        const char* name = luaL_checkstring(L, 2 + argOffset);
        float scale = (float)luaL_optnumber(L, 3 + argOffset, 1.0f);
        SpineContainer* obj = nullptr;
        try { obj = SpineContainer::create(path, name, scale); } catch (...) {
            AXLOGW("SpineContainer::create failed for path={}, name={}", path, name);
            obj = nullptr;
        }
        if (obj) {
            obj->retain();
            void** ud = (void**)lua_newuserdata(L, sizeof(void*));
            *ud = obj;
            luaL_getmetatable(L, "SpineContainer_mt");
            lua_setmetatable(L, -2);
            return 1;
        }
        // SpineContainer::create failed (missing files or incompatible version)
        // Return nil so Lua-side wrapper can provide a safe stub
        AXLOGW("SpineContainer::create returning nil for path={}, name={}", path, name);
        lua_pushnil(L);
        return 1;
    });
    lua_setfield(L, -2, "create");

    // Helper: safely get SpineContainer* from userdata, returns nullptr for fallback Nodes
    #define SAFE_SPINE(L) \
        ([](lua_State* LS) -> SpineContainer* { \
            void** p = (void**)lua_touserdata(LS, 1); \
            if (!p || !*p) return nullptr; \
            return dynamic_cast<SpineContainer*>(static_cast<ax::Node*>(*p)); \
        })(L)

    // runAnimation(trackIndex, name, loopTimes=1, delay=0)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* self = SAFE_SPINE(L);
        if (!self) return 0;
        int trackIndex = (int)luaL_checkinteger(L, 2);
        const char* name = luaL_checkstring(L, 3);
        int loopTimes = (int)luaL_optinteger(L, 4, 1);
        float delay = (float)luaL_optnumber(L, 5, 0);
        self->runAnimation(trackIndex, name, loopTimes, delay);
        return 0;
    });
    lua_setfield(L, -2, "runAnimation");

    // registerLuaListener(handler)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* self = SAFE_SPINE(L);
        if (self) self->registerLuaListener((int)luaL_checkinteger(L, 2));
        return 0;
    });
    lua_setfield(L, -2, "registerLuaListener");

    // unregisterLuaListener()
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* self = SAFE_SPINE(L);
        if (self) self->unregisterLuaListener();
        return 0;
    });
    lua_setfield(L, -2, "unregisterLuaListener");

    // stopAllAnimations()
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* self = SAFE_SPINE(L);
        if (self) self->stopAllAnimations();
        return 0;
    });
    lua_setfield(L, -2, "stopAllAnimations");

    // stopAnimationByIndex(trackIndex)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* self = SAFE_SPINE(L);
        if (self) self->stopAnimationByIndex((int)luaL_checkinteger(L, 2));
        return 0;
    });
    lua_setfield(L, -2, "stopAnimationByIndex");

    // setAction(name, bRemoveQueue=true) -> bool
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* self = SAFE_SPINE(L);
        if (!self) { lua_pushboolean(L, false); return 1; }
        const char* name = luaL_checkstring(L, 2);
        bool bRemoveQueue = lua_isboolean(L, 3) ? (bool)lua_toboolean(L, 3) : true;
        lua_pushboolean(L, self->setAction(name, bRemoveQueue));
        return 1;
    });
    lua_setfield(L, -2, "setAction");

    // addEffect(resName) / addEffect(resName, AffineTransform, zorder) / addEffect(resName, Vec2, zorder) / addEffect(resName, zorder)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* self = SAFE_SPINE(L);
        const char* resName = luaL_checkstring(L, 2);
        if (!self) { lua_pushinteger(L, -1); return 1; }

        int top = lua_gettop(L);
        if (top == 2) {
            // addEffect(resName)
            lua_pushinteger(L, self->addEffect(resName));
        } else if (top == 3) {
            // addEffect(resName, zorder)
            int zorder = (int)luaL_checkinteger(L, 3);
            lua_pushinteger(L, self->addEffect(resName, zorder));
        } else if (top >= 4) {
            int type3 = lua_type(L, 3);
            if (type3 == LUA_TNUMBER) {
                // addEffect(resName, zorder) with extra arg
                int zorder = (int)luaL_checkinteger(L, 3);
                lua_pushinteger(L, self->addEffect(resName, zorder));
            } else {
                // addEffect(resName, Vec2/table{x,y}, zorder)
                float x = 0, y = 0;
                if (lua_istable(L, 3)) {
                    lua_getfield(L, 3, "x"); x = (float)luaL_optnumber(L, -1, 0); lua_pop(L, 1);
                    lua_getfield(L, 3, "y"); y = (float)luaL_optnumber(L, -1, 0); lua_pop(L, 1);
                }
                int zorder = (int)luaL_checkinteger(L, 4);
                lua_pushinteger(L, self->addEffect(resName, ax::Vec2(x, y), zorder));
            }
        } else {
            lua_pushinteger(L, -1);
        }
        return 1;
    });
    lua_setfield(L, -2, "addEffect");

    // clearActionSequence()
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* self = SAFE_SPINE(L);
        if (self) self->clearActionSequence();
        return 0;
    });
    lua_setfield(L, -2, "clearActionSequence");

    // interruptSound()
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* self = SAFE_SPINE(L);
        if (self) self->interruptSound();
        return 0;
    });
    lua_setfield(L, -2, "interruptSound");

    // onActionFinished()
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* self = SAFE_SPINE(L);
        if (self) self->onActionFinished();
        return 0;
    });
    lua_setfield(L, -2, "onActionFinished");

    // removeEffectWithID(eid)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* self = SAFE_SPINE(L);
        int eid = (int)luaL_checkinteger(L, 2);
        if (self) self->removeEffectWithID(eid);
        return 0;
    });
    lua_setfield(L, -2, "removeEffectWithID");

    // removeEffectWithName(name)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* self = SAFE_SPINE(L);
        const char* name = luaL_checkstring(L, 2);
        if (self) self->removeEffectWithName(name);
        return 0;
    });
    lua_setfield(L, -2, "removeEffectWithName");

    // setColor(r, g, b)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* self = SAFE_SPINE(L);
        int r = (int)luaL_checkinteger(L, 2);
        int g = (int)luaL_checkinteger(L, 3);
        int b = (int)luaL_checkinteger(L, 4);
        if (self) self->setColor(ax::Color32((uint8_t)r, (uint8_t)g, (uint8_t)b));
        return 0;
    });
    lua_setfield(L, -2, "setColor");

    // setComponent(param1, param2) or setComponent(index, name)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* self = SAFE_SPINE(L);
        if (!self) { lua_pushboolean(L, false); return 1; }
        if (lua_type(L, 2) == LUA_TNUMBER) {
            int index = (int)luaL_checkinteger(L, 2);
            const char* name = luaL_checkstring(L, 3);
            lua_pushboolean(L, self->setComponent(index, name));
        } else {
            const char* p1 = luaL_checkstring(L, 2);
            const char* p2 = luaL_checkstring(L, 3);
            lua_pushboolean(L, self->setComponent(p1, p2));
        }
        return 1;
    });
    lua_setfield(L, -2, "setComponent");

    // setNextAction(actionName)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* self = SAFE_SPINE(L);
        const char* name = luaL_checkstring(L, 2);
        if (self) self->setNextAction(name);
        return 0;
    });
    lua_setfield(L, -2, "setNextAction");

    // setOpacity(value) - also works on fallback Node
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* self = SAFE_SPINE(L);
        int val = (int)luaL_checkinteger(L, 2);
        if (self) {
            self->setOpacity((unsigned char)val);
        } else {
            // Fallback: call on the raw Node
            void** ud = (void**)lua_touserdata(L, 1);
            if (ud && *ud) static_cast<ax::Node*>(*ud)->setOpacity((unsigned char)val);
        }
        return 0;
    });
    lua_setfield(L, -2, "setOpacity");

    // tint(r, g, b)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* self = SAFE_SPINE(L);
        float r = (float)luaL_checknumber(L, 2);
        float g = (float)luaL_checknumber(L, 3);
        float b = (float)luaL_checknumber(L, 4);
        if (self) self->tint(r, g, b);
        return 0;
    });
    lua_setfield(L, -2, "tint");

    // update(dt, isAuto=true)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* self = SAFE_SPINE(L);
        float dt = (float)luaL_checknumber(L, 2);
        bool isAuto = lua_isboolean(L, 3) ? (bool)lua_toboolean(L, 3) : true;
        if (self) self->update(dt, isAuto);
        return 0;
    });
    lua_setfield(L, -2, "update");

    // useDefaultShader()
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* self = SAFE_SPINE(L);
        if (self) self->useDefaultShader();
        return 0;
    });
    lua_setfield(L, -2, "useDefaultShader");

    // useShader(shaderName)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* self = SAFE_SPINE(L);
        const char* name = luaL_checkstring(L, 2);
        if (self) self->useShader(name);
        return 0;
    });
    lua_setfield(L, -2, "useShader");

    // setActionElapsed(elapsed)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* self = SAFE_SPINE(L);
        float val = (float)luaL_checknumber(L, 2);
        if (self) self->setActionElapsed(val);
        return 0;
    });
    lua_setfield(L, -2, "setActionElapsed");

    // setActionSpeeder(speeder)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* self = SAFE_SPINE(L);
        float val = (float)luaL_checknumber(L, 2);
        if (self) self->setActionSpeeder(val);
        return 0;
    });
    lua_setfield(L, -2, "setActionSpeeder");

    // setLoop(val)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* self = SAFE_SPINE(L);
        bool val = lua_toboolean(L, 2);
        if (self) self->setLoop(val);
        return 0;
    });
    lua_setfield(L, -2, "setLoop");

    lua_setfield(L, -2, "__methods");  // save methods table as __methods

    // __index: first check SpineContainer methods, then fallback to ax.Node class table
    lua_pushcfunction(L, [](lua_State* L) -> int {
        // 1. Check SpineContainer methods table
        lua_getmetatable(L, 1);           // get SpineContainer_mt
        lua_getfield(L, -1, "__methods"); // get methods table
        lua_pushvalue(L, 2);              // key
        lua_rawget(L, -2);                // methods[key]
        if (!lua_isnil(L, -1)) {
            return 1;  // found in SpineContainer methods
        }
        lua_pop(L, 2);  // pop nil and methods table

        // 2. Fallback: look up in ax.Node class table (ax.Node in Lua globals)
        // tolua++ stores methods in the class table (ax.Node), not in the metatable
        void** ud = (void**)lua_touserdata(L, 1);
        if (ud && *ud) {
            // Cache the ax.Node class table reference in SpineContainer_mt for fast lookup
            lua_getmetatable(L, 1);               // get SpineContainer_mt again
            lua_getfield(L, -1, "__node_class");  // get cached ax.Node class table
            if (!lua_istable(L, -1)) {
                lua_pop(L, 1);                    // pop non-table value
                // First time: look up ax.Node from globals and cache it
                lua_getglobal(L, "ax");
                if (lua_istable(L, -1)) {
                    lua_getfield(L, -1, "Node");
                    if (lua_istable(L, -1)) {
                        lua_pushvalue(L, -1);
                        lua_setfield(L, -5, "__node_class");  // cache in SpineContainer_mt
                    } else {
                        lua_pop(L, 1);  // pop non-table ax.Node
                    }
                } else {
                    lua_pop(L, 1);  // pop non-table ax
                }
                lua_pop(L, 1);  // pop ax table
                // Now get the cached value
                lua_getfield(L, -1, "__node_class");
            }
            if (lua_istable(L, -1)) {
                lua_pushvalue(L, 2);    // key
                lua_rawget(L, -2);      // ax.Node[key] (raw lookup in class table)
                if (!lua_isnil(L, -1)) {
                    return 1;  // found in ax.Node class table
                }
                lua_pop(L, 1);  // pop nil
            }
            lua_pop(L, 2);  // pop __node_class and SpineContainer_mt
        } else {
            lua_pop(L, 1);  // pop SpineContainer_mt
        }

        lua_pushnil(L);
        return 1;
    });
    lua_setfield(L, -2, "__index");

    // __gc
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto** self = (SpineContainer**)lua_touserdata(L, 1);
        if (self && *self) {
            (*self)->release();
            *self = nullptr;
        }
        return 0;
    });
    lua_setfield(L, -2, "__gc");
    lua_pop(L, 1);  // pop metatable

    // SpineContainer 全局表（含 create 静态方法）
    lua_newtable(L);
    // 把 create 也放到全局表上，因为原版 tolua 是 SpineContainer.create()
    // 支持冒号调用 SpineContainer:create(...) 和点调用 SpineContainer.create(...)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        int argOffset = 0;
        if (lua_type(L, 1) != LUA_TSTRING) argOffset = 1; // 冒号调用，跳过 self
        const char* path = luaL_checkstring(L, 1 + argOffset);
        const char* name = luaL_checkstring(L, 2 + argOffset);
        float scale = (float)luaL_optnumber(L, 3 + argOffset, 1.0f);
        SpineContainer* obj = nullptr;
        try { obj = SpineContainer::create(path, name, scale); } catch (...) {
            AXLOGW("SpineContainer::create(global) failed for path={}, name={}", path, name);
            obj = nullptr;
        }
        if (obj) {
            obj->retain();
            void** ud = (void**)lua_newuserdata(L, sizeof(void*));
            *ud = obj;
            luaL_getmetatable(L, "SpineContainer_mt");
            lua_setmetatable(L, -2);
            return 1;
        }
        // Return fallback Node with SpineContainer_mt (methods use SAFE_SPINE for safety)
        AXLOGW("SpineContainer::create(global) returning fallback Node for path={}, name={}", path, name);
        auto* emptyNode = ax::Node::create();
        emptyNode->retain();
        void** ud = (void**)lua_newuserdata(L, sizeof(void*));
        *ud = emptyNode;
        luaL_getmetatable(L, "SpineContainer_mt");
        lua_setmetatable(L, -2);
        return 1;
    });
    lua_setfield(L, -2, "create");
    lua_setglobal(L, "SpineContainer");

    // ---- ArmatureContainer stub ----
    register_stub_class(L, "ArmatureContainer", {
        "create", "runAnimation", "changeSkin", "update", "registerLuaListener",
        "unregisterLuaListener", "setAction", "setLoop", "setResourcePath",
        "getResourcePath", "clearResource", "setColor", "tint", "addEffect",
        "removeEffectWithID", "removeEffectWithName", "useDefaultShader",
        "useShader", "setActionElapsed", "setActionSpeeder", "setNextAction"
    });

    // ---- LegendAnimation stub ----
    register_stub_class(L, "LegendAnimation", {"create"});

    // ---- libOS stub ----
    register_stub_class(L, "libOS", {
        "getInstance", "avalibleMemory", "rmdir", "generateSerial",
        "showInputbox", "showMessagebox", "openURL", "emailTo",
        "setWaiting", "getFreeSpace", "getNetWork", "getDeviceID",
        "getPlatformInfo", "analyticsLogEvent", "WeChatInit", "WeChatIsInstalled",
        "WeChatOpen"
    });

    // ---- Language stub ----
    register_stub_class(L, "Language", {
        "getInstance", "init", "addLanguageFile", "hasString",
        "getString", "updateNode", "clear"
    });

    // ---- libPlatform stub ----
    register_stub_class(L, "libPlatform", {
        "getInstance", "openBBS", "userFeedBack", "gamePause",
        "getLogined", "loginUin", "login", "switchUsers",
        "sessionID", "nickName", "getPlatformInfo", "getClientChannel", "getPlatformId"
    });

    // ---- libPlatformManager stub ----
    register_stub_class(L, "libPlatformManager", {
        "getInstance", "setPlatform", "getPlatform"
    });

    // ---- SeverConsts stub ----
    register_stub_class(L, "SeverConsts", {
        "getInstance", "getServerInfoByLua", "getBaseVersion",
        "setIsInLoading", "getServerInGrayMsg", "getServerInUpdateMsg", "getSeverDefaultID"
    });

    // ---- AnnouncementNewPage stub ----
    register_stub_class(L, "AnnouncementNewPage", {
        "getInstance", "new", "startDown", "downInternalAnnouncementFile", "downloaded"
    });

    // ---- 全局函数 stub ----
    // LegendFindFileCpp / LegendFindFileForLua
    lua_pushcfunction(L, [](lua_State* L) -> int {
        const char* file = luaL_checkstring(L, 1);
        if (file) {
            auto path = FileUtils::getInstance()->fullPathForFilename(file);
            lua_pushstring(L, path.c_str());
        } else {
            lua_pushstring(L, "");
        }
        return 1;
    });
    lua_setglobal(L, "LegendFindFileForLua");

    lua_pushcfunction(L, [](lua_State* L) -> int {
        const char* file = luaL_checkstring(L, 1);
        if (file) {
            auto path = FileUtils::getInstance()->fullPathForFilename(file);
            lua_pushstring(L, path.c_str());
        } else {
            lua_pushstring(L, "");
        }
        return 1;
    });
    lua_setglobal(L, "LegendFindFileCpp");

    // LegendSetAniScaleFactor / LegendSetSoundSwitch
    lua_pushcfunction(L, [](lua_State* L) -> int { return 0; });
    lua_setglobal(L, "LegendSetAniScaleFactor");
    lua_pushcfunction(L, [](lua_State* L) -> int { return 0; });
    lua_setglobal(L, "LegendSetSoundSwitch");

    AXLOGI("Game Lua bindings registered successfully");
    return 0;
}
