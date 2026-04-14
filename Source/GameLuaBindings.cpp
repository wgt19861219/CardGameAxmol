#include "GameLuaBindings.h"
#include <algorithm>
#include "CCBContainer.h"
#include "SpineContainer.h"
#include "LegendAnimation.h"
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
    int r = (int)luaL_checknumber(L, 2);
    int g = (int)luaL_checknumber(L, 3);
    int b = (int)luaL_checknumber(L, 4);
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
    // 提取公共 create 函数，避免代码重复（I1 修复）
    static const auto lua_SpineContainer_create = [](lua_State* L) -> int {
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
        lua_pushnil(L);
        return 1;
    };

    luaL_newmetatable(L, "SpineContainer_mt");

    // 方法表
    lua_newtable(L);

    // create(path, name, scale=1.0) -> SpineContainer
    lua_pushcfunction(L, lua_SpineContainer_create);
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
        int r = (int)luaL_checknumber(L, 2);
        int g = (int)luaL_checknumber(L, 3);
        int b = (int)luaL_checknumber(L, 4);
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
    // 把 create 也放到全局表上，复用公共函数
    lua_pushcfunction(L, lua_SpineContainer_create);
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

    // ---- LegendAnimation / LegendAminationEffect ----
    // First create instance metatable
    luaL_newmetatable(L, "LegendAnimationEffect_mt");

    // __index table for instance methods
    lua_newtable(L);  // methods table

    // setAction(name)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* obj = *(ax::LegendAnimationEffect**)luaL_checkudata(L, 1, "LegendAnimationEffect_mt");
        const char* name = luaL_checkstring(L, 2);
        if (obj) obj->setAction(name, true);
        return 0;
    });
    lua_setfield(L, -2, "setAction");

    // setNextAction(name)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* obj = *(ax::LegendAnimationEffect**)luaL_checkudata(L, 1, "LegendAnimationEffect_mt");
        const char* name = luaL_checkstring(L, 2);
        if (obj) obj->setNextAction(name);
        return 0;
    });
    lua_setfield(L, -2, "setNextAction");

    // setLoop(bool)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* obj = *(ax::LegendAnimationEffect**)luaL_checkudata(L, 1, "LegendAnimationEffect_mt");
        bool val = lua_toboolean(L, 2) != 0;
        if (obj) obj->setLoop(val);
        return 0;
    });
    lua_setfield(L, -2, "setLoop");

    // getAniFileName()
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* obj = *(ax::LegendAnimationEffect**)luaL_checkudata(L, 1, "LegendAnimationEffect_mt");
        if (obj) lua_pushstring(L, obj->getAniFileName().c_str());
        else lua_pushstring(L, "");
        return 1;
    });
    lua_setfield(L, -2, "getAniFileName");

    // isTerminated()
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* obj = *(ax::LegendAnimationEffect**)luaL_checkudata(L, 1, "LegendAnimationEffect_mt");
        lua_pushboolean(L, obj ? (obj->isTerminated() ? 1 : 0) : 0);
        return 1;
    });
    lua_setfield(L, -2, "isTerminated");

    // getActionNaturalDuration() -> float (returns 0 if no action)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* obj = *(ax::LegendAnimationEffect**)luaL_checkudata(L, 1, "LegendAnimationEffect_mt");
        if (obj)
            lua_pushnumber(L, obj->getActionNaturalDuration());
        else
            lua_pushnumber(L, 0);
        return 1;
    });
    lua_setfield(L, -2, "getActionNaturalDuration");

    // setLoopAction(name)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* obj = *(ax::LegendAnimationEffect**)luaL_checkudata(L, 1, "LegendAnimationEffect_mt");
        const char* name = luaL_checkstring(L, 2);
        if (obj) obj->setLoopAction(name);
        return 0;
    });
    lua_setfield(L, -2, "setLoopAction");

    // setStartAction(name)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* obj = *(ax::LegendAnimationEffect**)luaL_checkudata(L, 1, "LegendAnimationEffect_mt");
        const char* name = luaL_checkstring(L, 2);
        if (obj) obj->setStartAction(name);
        return 0;
    });
    lua_setfield(L, -2, "setStartAction");

    // setActionElapsed(elapsed)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* obj = *(ax::LegendAnimationEffect**)luaL_checkudata(L, 1, "LegendAnimationEffect_mt");
        float val = (float)luaL_checknumber(L, 2);
        if (obj) obj->setActionElapsed(val);
        return 0;
    });
    lua_setfield(L, -2, "setActionElapsed");

    // setActionSpeeder(speeder)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* obj = *(ax::LegendAnimationEffect**)luaL_checkudata(L, 1, "LegendAnimationEffect_mt");
        float val = (float)luaL_checknumber(L, 2);
        if (obj) obj->setActionSpeeder(val);
        return 0;
    });
    lua_setfield(L, -2, "setActionSpeeder");

    // update(dt)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* obj = *(ax::LegendAnimationEffect**)luaL_checkudata(L, 1, "LegendAnimationEffect_mt");
        float dt = (float)luaL_checknumber(L, 2);
        if (obj) obj->update(dt);
        return 0;
    });
    lua_setfield(L, -2, "update");

    // addEffect(resName[, pos/zorder, zorder]) — calls LegendAnimation::addEffect
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* obj = *(ax::LegendAnimationEffect**)luaL_checkudata(L, 1, "LegendAnimationEffect_mt");
        if (!obj) { lua_pushinteger(L, -1); return 1; }
        const char* resName = luaL_checkstring(L, 2);
        int top = lua_gettop(L);
        if (top == 2) {
            lua_pushinteger(L, obj->addEffect(resName));
        } else if (top == 3) {
            int zorder = (int)luaL_checkinteger(L, 3);
            lua_pushinteger(L, obj->addEffect(resName, zorder));
        } else if (top >= 4) {
            int type3 = lua_type(L, 3);
            if (type3 == LUA_TNUMBER) {
                int zorder = (int)luaL_checkinteger(L, 3);
                lua_pushinteger(L, obj->addEffect(resName, zorder));
            } else {
                float x = 0, y = 0;
                if (lua_istable(L, 3)) {
                    lua_getfield(L, 3, "x"); x = (float)luaL_optnumber(L, -1, 0); lua_pop(L, 1);
                    lua_getfield(L, 3, "y"); y = (float)luaL_optnumber(L, -1, 0); lua_pop(L, 1);
                }
                int zorder = (int)luaL_checkinteger(L, 4);
                lua_pushinteger(L, obj->addEffect(resName, ax::Vec2(x, y), zorder));
            }
        } else {
            lua_pushinteger(L, -1);
        }
        return 1;
    });
    lua_setfield(L, -2, "addEffect");

    // addEffectToComponent stub
    lua_pushcfunction(L, [](lua_State* L) -> int {
        return 0;
    });
    lua_setfield(L, -2, "addEffectToComponent");

    // removeEffectWithID(eid)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* obj = *(ax::LegendAnimationEffect**)luaL_checkudata(L, 1, "LegendAnimationEffect_mt");
        int eid = (int)luaL_checkinteger(L, 2);
        if (obj) obj->removeEffectWithID(eid);
        return 0;
    });
    lua_setfield(L, -2, "removeEffectWithID");

    // removeEffectWithName(name)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* obj = *(ax::LegendAnimationEffect**)luaL_checkudata(L, 1, "LegendAnimationEffect_mt");
        const char* name = luaL_checkstring(L, 2);
        if (obj) obj->removeEffectWithName(name);
        return 0;
    });
    lua_setfield(L, -2, "removeEffectWithName");

    // clearAllEffects stub
    lua_pushcfunction(L, [](lua_State* L) -> int {
        return 0;
    });
    lua_setfield(L, -2, "clearAllEffects");

    // setComponent stub
    lua_pushcfunction(L, [](lua_State* L) -> int {
        return 0;
    });
    lua_setfield(L, -2, "setComponent");

    // addNode stub
    lua_pushcfunction(L, [](lua_State* L) -> int {
        return 0;
    });
    lua_setfield(L, -2, "addNode");

    // addNodeToComponent stub
    lua_pushcfunction(L, [](lua_State* L) -> int {
        return 0;
    });
    lua_setfield(L, -2, "addNodeToComponent");

    // removeNodeWithID stub
    lua_pushcfunction(L, [](lua_State* L) -> int {
        return 0;
    });
    lua_setfield(L, -2, "removeNodeWithID");

    // useShader stub
    lua_pushcfunction(L, [](lua_State* L) -> int {
        return 0;
    });
    lua_setfield(L, -2, "useShader");

    // useDefaultShader stub
    lua_pushcfunction(L, [](lua_State* L) -> int {
        return 0;
    });
    lua_setfield(L, -2, "useDefaultShader");

    // setColor(r, g, b)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* obj = *(ax::LegendAnimationEffect**)luaL_checkudata(L, 1, "LegendAnimationEffect_mt");
        if (obj && lua_gettop(L) >= 4) {
            obj->setColor(ax::Color32((uint8_t)(int)luaL_checknumber(L, 2),
                (uint8_t)(int)luaL_checknumber(L, 3),
                (uint8_t)(int)luaL_checknumber(L, 4)));
        }
        return 0;
    });
    lua_setfield(L, -2, "setColor");

    // tint(r, g, b) — multiplicative color factor (0.0-∞, 1.0=normal)
    // Original FCA system: tint(0.4)=darken to 40%, tint(2.5)=brighten to 250% (restore)
    // Convert: value * 255, clamped to [0, 255]
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* obj = *(ax::LegendAnimationEffect**)luaL_checkudata(L, 1, "LegendAnimationEffect_mt");
        if (obj && lua_gettop(L) >= 4) {
            auto toColor = [](lua_State* LS, int idx) -> uint8_t {
                float v = (float)luaL_checknumber(LS, idx);
                int c = (int)(v * 255.0f);
                return (uint8_t)std::max(0, std::min(255, c));
            };
            obj->setColor(ax::Color32(toColor(L, 2), toColor(L, 3), toColor(L, 4), 255));
        }
        return 0;
    });
    lua_setfield(L, -2, "tint");

    // setNextAction stub (for compatibility - some code uses different name)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* obj = *(ax::LegendAnimationEffect**)luaL_checkudata(L, 1, "LegendAnimationEffect_mt");
        return 0;
    });
    lua_setfield(L, -2, "interruptSound");

    // ---- Node method forwards (bypass tolua++ type checking) ----
    // These are needed because tolua++ checks metatable type, and our
    // LegendAnimationEffect_mt doesn't match ax.Node/ax.Sprite.

    // Helper macro to get the Node* from LegendAnimationEffect userdata
    #define LAE_NODE(L) \
        (*reinterpret_cast<ax::LegendAnimationEffect**>(lua_touserdata(L, 1)))

    // addChild(child, zOrder, tag)
    lua_pushcclosure(L, [](lua_State* L) -> int {
        auto* self = LAE_NODE(L);
        if (!self) return 0;
        // child might be any Node* userdata — we need to extract the pointer
        // Try to get it as a generic userdata pointer
        void** childPtr = (void**)lua_touserdata(L, 2);
        if (!childPtr || !*childPtr) return 0;
        auto* child = static_cast<ax::Node*>(*childPtr);
        int top = lua_gettop(L);
        if (top >= 4) {
            self->addChild(child, (int)luaL_checkinteger(L, 3), (int)luaL_checkinteger(L, 4));
        } else if (top >= 3) {
            self->addChild(child, (int)luaL_checkinteger(L, 3));
        } else {
            self->addChild(child);
        }
        return 0;
    }, 0);
    lua_setfield(L, -2, "addChild");

    // removeFromParent()
    lua_pushcclosure(L, [](lua_State* L) -> int {
        auto* self = LAE_NODE(L);
        if (self) self->removeFromParent();
        return 0;
    }, 0);
    lua_setfield(L, -2, "removeFromParent");

    // removeFromParentAndCleanup(cleanup)
    lua_pushcclosure(L, [](lua_State* L) -> int {
        auto* self = LAE_NODE(L);
        if (self) self->removeFromParent();
        return 0;
    }, 0);
    lua_setfield(L, -2, "removeFromParentAndCleanup");

    // runAction(action)
    lua_pushcclosure(L, [](lua_State* L) -> int {
        auto* self = LAE_NODE(L);
        if (!self) return 0;
        // action is a userdata — extract pointer
        void** actionPtr = (void**)lua_touserdata(L, 2);
        if (!actionPtr || !*actionPtr) return 0;
        auto* action = static_cast<ax::Action*>(*actionPtr);
        self->runAction(action);
        return 0;
    }, 0);
    lua_setfield(L, -2, "runAction");

    // stopAllActions()
    lua_pushcclosure(L, [](lua_State* L) -> int {
        auto* self = LAE_NODE(L);
        if (self) self->stopAllActions();
        return 0;
    }, 0);
    lua_setfield(L, -2, "stopAllActions");

    // setPosition(x, y) or setPosition(vec2)
    lua_pushcclosure(L, [](lua_State* L) -> int {
        auto* self = LAE_NODE(L);
        if (!self) return 0;
        if (lua_type(L, 2) == LUA_TNUMBER) {
            float x = (float)luaL_checknumber(L, 2);
            float y = (float)luaL_checknumber(L, 3);
            self->setPosition(x, y);
        } else if (lua_istable(L, 2)) {
            lua_getfield(L, 2, "x");
            float x = (float)luaL_optnumber(L, -1, 0);
            lua_pop(L, 1);
            lua_getfield(L, 2, "y");
            float y = (float)luaL_optnumber(L, -1, 0);
            lua_pop(L, 1);
            self->setPosition(x, y);
        }
        return 0;
    }, 0);
    lua_setfield(L, -2, "setPosition");

    // getPosition() -> x, y
    lua_pushcclosure(L, [](lua_State* L) -> int {
        auto* self = LAE_NODE(L);
        if (!self) { lua_pushnumber(L, 0); lua_pushnumber(L, 0); return 2; }
        auto pos = self->getPosition();
        lua_pushnumber(L, pos.x);
        lua_pushnumber(L, pos.y);
        return 2;
    }, 0);
    lua_setfield(L, -2, "getPosition");

    // setScale(scale)
    lua_pushcclosure(L, [](lua_State* L) -> int {
        auto* self = LAE_NODE(L);
        if (self) self->setScale((float)luaL_checknumber(L, 2));
        return 0;
    }, 0);
    lua_setfield(L, -2, "setScale");

    // setScaleX(scaleX)
    lua_pushcclosure(L, [](lua_State* L) -> int {
        auto* self = LAE_NODE(L);
        if (self) self->setScaleX((float)luaL_checknumber(L, 2));
        return 0;
    }, 0);
    lua_setfield(L, -2, "setScaleX");

    // setScaleY(scaleY)
    lua_pushcclosure(L, [](lua_State* L) -> int {
        auto* self = LAE_NODE(L);
        if (self) self->setScaleY((float)luaL_checknumber(L, 2));
        return 0;
    }, 0);
    lua_setfield(L, -2, "setScaleY");

    // setOpacity(opacity)
    // Note: already defined above with SAFE_SPINE, but we need one for LegendAnimationEffect too
    // Actually it's already in the methods table above. Let's check...

    // setVisible(visible)
    lua_pushcclosure(L, [](lua_State* L) -> int {
        auto* self = LAE_NODE(L);
        if (self) self->setVisible(lua_toboolean(L, 2) != 0);
        return 0;
    }, 0);
    lua_setfield(L, -2, "setVisible");

    // isVisible() -> bool
    lua_pushcclosure(L, [](lua_State* L) -> int {
        auto* self = LAE_NODE(L);
        lua_pushboolean(L, self && self->isVisible());
        return 1;
    }, 0);
    lua_setfield(L, -2, "isVisible");

    // getScaleX() -> float
    lua_pushcclosure(L, [](lua_State* L) -> int {
        auto* self = LAE_NODE(L);
        lua_pushnumber(L, self ? self->getScaleX() : 1.0f);
        return 1;
    }, 0);
    lua_setfield(L, -2, "getScaleX");

    // getScaleY() -> float
    lua_pushcclosure(L, [](lua_State* L) -> int {
        auto* self = LAE_NODE(L);
        lua_pushnumber(L, self ? self->getScaleY() : 1.0f);
        return 1;
    }, 0);
    lua_setfield(L, -2, "getScaleY");

    // getScale() -> float
    lua_pushcclosure(L, [](lua_State* L) -> int {
        auto* self = LAE_NODE(L);
        lua_pushnumber(L, self ? self->getScale() : 1.0f);
        return 1;
    }, 0);
    lua_setfield(L, -2, "getScale");

    // setOpacity(opacity)
    lua_pushcclosure(L, [](lua_State* L) -> int {
        auto* self = LAE_NODE(L);
        if (self) self->setOpacity((uint8_t)(int)luaL_checknumber(L, 2));
        return 0;
    }, 0);
    lua_setfield(L, -2, "setOpacity");

    // getTag() -> int
    lua_pushcclosure(L, [](lua_State* L) -> int {
        auto* self = LAE_NODE(L);
        lua_pushinteger(L, self ? self->getTag() : -1);
        return 1;
    }, 0);
    lua_setfield(L, -2, "getTag");

    // setTag(tag)
    lua_pushcclosure(L, [](lua_State* L) -> int {
        auto* self = LAE_NODE(L);
        if (self) self->setTag((int)luaL_checknumber(L, 2));
        return 0;
    }, 0);
    lua_setfield(L, -2, "setTag");

    // getRotation() -> float
    lua_pushcclosure(L, [](lua_State* L) -> int {
        auto* self = LAE_NODE(L);
        lua_pushnumber(L, self ? self->getRotation() : 0.0f);
        return 1;
    }, 0);
    lua_setfield(L, -2, "getRotation");

    // setContentSize(width, height)
    lua_pushcclosure(L, [](lua_State* L) -> int {
        auto* self = LAE_NODE(L);
        if (!self) return 0;
        float w = (float)luaL_checknumber(L, 2);
        float h = (float)luaL_checknumber(L, 3);
        self->setContentSize(ax::Size(w, h));
        return 0;
    }, 0);
    lua_setfield(L, -2, "setContentSize");

    // getContentSize() -> width, height
    lua_pushcclosure(L, [](lua_State* L) -> int {
        auto* self = LAE_NODE(L);
        if (!self) { lua_pushnumber(L, 0); lua_pushnumber(L, 0); return 2; }
        auto s = self->getContentSize();
        lua_pushnumber(L, s.width);
        lua_pushnumber(L, s.height);
        return 2;
    }, 0);
    lua_setfield(L, -2, "getContentSize");

    // setAnchorPoint(x, y)
    lua_pushcclosure(L, [](lua_State* L) -> int {
        auto* self = LAE_NODE(L);
        if (!self) return 0;
        float x = (float)luaL_checknumber(L, 2);
        float y = (float)luaL_checknumber(L, 3);
        self->setAnchorPoint(ax::Vec2(x, y));
        return 0;
    }, 0);
    lua_setfield(L, -2, "setAnchorPoint");

    // setRotation(rotation)
    lua_pushcclosure(L, [](lua_State* L) -> int {
        auto* self = LAE_NODE(L);
        if (self) self->setRotation((float)luaL_checknumber(L, 2));
        return 0;
    }, 0);
    lua_setfield(L, -2, "setRotation");

    // setLocalZOrder(z) / setZOrder(z) — 接受 float 自动截断（cocos2d-x 2.x 兼容）
    lua_pushcclosure(L, [](lua_State* L) -> int {
        auto* self = LAE_NODE(L);
        if (self) self->setLocalZOrder((int)luaL_checknumber(L, 2));
        return 0;
    }, 0);
    lua_setfield(L, -2, "setLocalZOrder");
    lua_pushcclosure(L, [](lua_State* L) -> int {
        auto* self = LAE_NODE(L);
        if (self) self->setLocalZOrder((int)luaL_checknumber(L, 2));
        return 0;
    }, 0);
    lua_setfield(L, -2, "setZOrder");

    #undef LAE_NODE

    // Save methods table as __methods for reference
    lua_pushvalue(L, -1);
    lua_setfield(L, -3, "__methods");

    // Set methods table as __index
    lua_setfield(L, -2, "__index");

    // Register type in tolua++ type system so addChild accepts LegendAnimationEffect as ax.Node
    // 1. registry[metatable] = "LegendAnimationEffect" (type name lookup)
    lua_pushvalue(L, -1);                          // push metatable copy
    lua_pushstring(L, "LegendAnimationEffect");    // type name
    lua_rawset(L, LUA_REGISTRYINDEX);              // registry[mt] = "LegendAnimationEffect"

    // 2. tolua_super[metatable] = {ax.Node=true, ax.Sprite=true, ax.Ref=true}
    lua_pushstring(L, "tolua_super");
    lua_rawget(L, LUA_REGISTRYINDEX);              // get tolua_super from registry
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
        lua_newtable(L);
        lua_pushstring(L, "tolua_super");
        lua_pushvalue(L, -2);
        lua_rawset(L, LUA_REGISTRYINDEX);          // registry["tolua_super"] = new_table
    }
    if (lua_istable(L, -1)) {
        lua_pushvalue(L, -2);                      // key: metatable
        lua_newtable(L);                           // value: super types table
        lua_pushstring(L, "ax.Node");
        lua_pushboolean(L, 1);
        lua_rawset(L, -3);                         // super["ax.Node"] = true
        lua_pushstring(L, "ax.Sprite");
        lua_pushboolean(L, 1);
        lua_rawset(L, -3);                         // super["ax.Sprite"] = true
        lua_pushstring(L, "ax.Ref");
        lua_pushboolean(L, 1);
        lua_rawset(L, -3);                         // super["ax.Ref"] = true
        lua_rawset(L, -3);                         // tolua_super[metatable] = super
    }
    lua_pop(L, 1);                                 // pop tolua_super

    // __gc
    lua_pushcfunction(L, [](lua_State* L) -> int {
        auto* obj = *(ax::LegendAnimationEffect**)luaL_checkudata(L, 1, "LegendAnimationEffect_mt");
        if (obj) obj->release();
        return 0;
    });
    lua_setfield(L, -2, "__gc");

    // metatable is now set up but still on stack

    // Create the class table (static methods)
    lua_newtable(L);
    lua_pushcfunction(L, [](lua_State* L) -> int {
        int argOffset = (lua_type(L, 1) != LUA_TSTRING) ? 1 : 0;  // skip self for colon call
        const char* resource = luaL_checkstring(L, 1 + argOffset);
        float scale = (float)luaL_optnumber(L, 2 + argOffset, 1.0f);
        // LegendAnimationEffect::create handles Start/Loop auto-detection
        // LegendAnimationFileInfo searches both anim/ and anim/effect/ paths
        auto* obj = ax::LegendAnimationEffect::create(resource);
        if (obj)
        {
            obj->setScale(scale);
            obj->retain();
            auto** ud = (ax::LegendAnimationEffect**)lua_newuserdata(L, sizeof(ax::LegendAnimationEffect*));
            *ud = obj;
            luaL_getmetatable(L, "LegendAnimationEffect_mt");
            lua_setmetatable(L, -2);
            return 1;
        }
        lua_pushnil(L);
        return 1;
    });
    lua_setfield(L, -2, "create");

    // Register as global names
    lua_pushvalue(L, -1);
    lua_setglobal(L, "LegendAminationEffect");
    lua_pushvalue(L, -1);
    lua_setglobal(L, "LegendAnimation");

    lua_pop(L, 2);  // pop class table and metatable

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

    // LegendSetAniScaleFactor — sets global animation scale factor
    // (original engine used this to scale FCA animations to match screen DPI)
    lua_pushcfunction(L, [](lua_State* L) -> int {
        double scale = luaL_checknumber(L, 1);
        LegendAnimationFileInfo::setCurrentScaleFactor(scale);
        return 0;
    });
    lua_setglobal(L, "LegendSetAniScaleFactor");
    lua_pushcfunction(L, [](lua_State* L) -> int {
        SpineContainer::s_soundSwitch = (int)luaL_checkinteger(L, 1);
        return 0;
    });
    lua_setglobal(L, "LegendSetSoundSwitch");

    AXLOGI("Game Lua bindings registered successfully");
    return 0;
}
