-----------------------------------------------------------------
-- CardGame Axmol 入口
-- 加载顺序: config -> stubs -> axmol core -> compat -> game modules -> scene
-----------------------------------------------------------------

require "config"

-- 将 Lua print 输出同时写入 ax_debug.txt（与 C++ dbg() 共享日志文件）
do
    local _logFile = io.open("lua_debug.log", "w")
    if _logFile then
        local _origPrint = print
        rawset(_G, "print", function(...)
            if _origPrint then pcall(_origPrint, ...) end
            local args = { ... }
            local line = ""
            for i, v in ipairs(args) do
                if i > 1 then line = line .. "\t" end
                line = line .. tostring(v)
            end
            _logFile:write("[LUA] " .. line .. "\n")
            _logFile:flush()
        end)
        _logFile:write("[LUA] === lua_debug.log opened ===\n")
        _logFile:flush()
    end
end
print("[MAIN] Lua print redirected, loading modules...")

-----------------------------------------------------------------
-- 全局桩函数（在 axmol.init 之前就需要）
-----------------------------------------------------------------
if not rawget(_G, "tolua") then rawset(_G, "tolua", {}) end
if not tolua.isnull then tolua.isnull = function(obj) return obj == nil end end

rawset(_G, "LegendSetAniScaleFactor", function() end)
rawset(_G, "LegendSetSoundSwitch", function() end)
rawset(_G, "LegendGetDeviceID", function() return "ax-001" end)
rawset(_G, "LegendFindFileCpp", function(f) return f end)
rawset(_G, "GetPlatformOS", function() return 3 end)  -- 3=Win32, stub
rawset(_G, "EDFLAGWIN32", true)
rawset(_G, "EDFLAGSVR", false)
rawset(_G, "LegendPlatformFLAG", 3)  -- CC_PLATFORM_WIN32
rawset(_G, "LegendFLAG_ALPHAVERSION", false)
rawset(_G, "LegendSDKType", 0)
rawset(_G, "LegendLog", function(...) print("[LL]", ...) end)
rawset(_G, "EDLanguage", "chinese")
rawset(_G, "EDDebug", function(err) print("[EDDEBUG] ERROR: " .. tostring(err)) end)
rawset(_G, "FireEvent", function(...) end)
rawset(_G, "do_battle_log", false)
rawset(_G, "protobuf", { encode = function() return "" end, decode = function() return {} end })

-- LSTR fallback (will be overridden if LocalString.lua loads successfully)
if not rawget(_G, "LSTR") then
    rawset(_G, "LSTR", function(key, ...)
        local s = tostring(key)
        local args = { ... }
        for i, v in ipairs(args) do s = s:gsub("%%" .. i, tostring(v)) end
        return s
    end)
end

-- pb (protobuf) stub
if not rawget(_G, "pb") then
    local pbStub = {
        encode = function() return "" end,
        decode = function() return {} end,
        pack = function() return "" end,
        unpack = function() return nil end,
    }
    rawset(_G, "pb", pbStub)
    package.loaded["pb"] = pbStub
end

-- md5 stub
if not rawget(_G, "md5") then
    local md5Stub = function(str) return str or "" end
    rawset(_G, "md5", md5Stub)
    package.loaded["md5"] = md5Stub
end

-- ed.ui stub (UI framework placeholder)
if not rawget(_G, "ed") then rawset(_G, "ed", {}) end
if not ed.ui then ed.ui = {} end
if not rawget(_G, "socket") then rawset(_G, "socket", { connect = function() end }) end

-- LegendTime stub (C++ time function, returns y,m,d,h,min,sec,time,million)
if not rawget(_G, "LegendTime") then
    rawset(_G, "LegendTime", function()
        local t = os.date("*t", os.time())
        return t.year, t.month, t.day, t.hour, t.min, t.sec, os.time(), os.time() * 1000
    end)
end

-- FontFactory stub
if not rawget(_G, "FontFactory") then
    rawset(_G, "FontFactory", {
        instance = function() return { create_font = function() end } end
    })
end

-- EDTables stub (game data tables)
if not rawget(_G, "EDTables") then rawset(_G, "EDTables", { fontcfg = { annfonts = {} } }) end

-- ed.config and ed.PlatformCode
if not ed.config then ed.config = { localMode = true } end
ed.config.localMode = true
if not ed.PlatformCode then
    ed.PlatformCode = { CC_PLATFORM_IOS = 1, CC_PLATFORM_ANDROID = 2, CC_PLATFORM_WIN32 = 3 }
end

rawset(_G, "EDFLAGWP8", false)
rawset(_G, "LegendLuaReset", 0)
rawset(_G, "sessionId", "local-session")

-- Animation type constants
rawset(_G, "Type_LegendAnimation", 0)
rawset(_G, "Type_Spine", 1)
rawset(_G, "Type_DragonBone", 2)

-- Lua 5.5 compat: loadstring → load
if not rawget(_G, "loadstring") then rawset(_G, "loadstring", load) end

-- Lua 5.5 compat: collectgarbage("setpause"/"setstepmul") 已移除
local _orig_collectgarbage = collectgarbage
rawset(_G, "collectgarbage", function(opt, ...)
    if opt == "setpause" or opt == "setstepmul" then return end
    return _orig_collectgarbage(opt, ...)
end)

-- string.gfind → string.gmatch (Lua 5.1+ rename)
if not string.gfind then string.gfind = string.gmatch end

-- LegendGetScriptString stub (C++ debug function)
if not rawget(_G, "LegendGetScriptString") then
    rawset(_G, "LegendGetScriptString", function() return nil end)
end

-- EDSwitchToResolutionDir stub
rawset(_G, "EDSwitchToResolutionDir", function() end)

-- ed.getMillionTime fallback (overridden by time.lua if it loads)
if not ed.getMillionTime then
    ed.getMillionTime = function() return os.time() * 1000 end
end
-- ed.tick_interval fallback (overridden by battle_engine.lua)
if not ed.tick_interval then ed.tick_interval = 0.1 end
-- ed.proc_net fallback (overridden by network.lua)
if not ed.proc_net then ed.proc_net = function() end end

-- Login/network stubs (logo.lua doLogin needs these)
if not ed.getUserid then ed.getUserid = function() return "ax-user-001" end end
if not ed.getDeviceId then ed.getDeviceId = function() return "ax-device-001" end end
if not ed.send then ed.send = function() end end
if not ed.upmsg then
    ed.upmsg = { login = function() return {} end }
end
if not ed.downmsg then 
    ed.downmsg = setmetatable({}, {
        __index = function(t, key)
            -- Auto-create factory functions for protobuf message types
            t[key] = function() return {} end
            return t[key]
        end
    })
end
if not rawget(_G, "LegendGetLoginPwd") then rawset(_G, "LegendGetLoginPwd", function() return "1.0.0" end) end
if not rawget(_G, "LegendEnterGameNotifiy") then rawset(_G, "LegendEnterGameNotifiy", function() end) end
if not rawget(_G, "LegendCheckWifi") then rawset(_G, "LegendCheckWifi", function() return true end) end
if not rawget(_G, "LegendExit") then rawset(_G, "LegendExit", function() os.exit() end) end
if not rawget(_G, "LegendRestartApplication") then rawset(_G, "LegendRestartApplication", function() end) end
if not rawget(_G, "CloseEvent") then rawset(_G, "CloseEvent", function() end) end
if not rawget(_G, "ListenEvent") then rawset(_G, "ListenEvent", function() end) end
if not rawget(_G, "LegendLoadShader") then rawset(_G, "LegendLoadShader", function() end) end
if not rawget(_G, "LegendGetShopPriceInfo") then rawset(_G, "LegendGetShopPriceInfo", function() end) end
if not rawget(_G, "LegendCancelNotification") then rawset(_G, "LegendCancelNotification", function() end) end
if not rawget(_G, "LegendUpdateSvr") then rawset(_G, "LegendUpdateSvr", function() end) end
if not rawget(_G, "LegendRegisterNotification") then rawset(_G, "LegendRegisterNotification", function() end) end
if not rawget(_G, "LegendLocalNotify") then rawset(_G, "LegendLocalNotify", function() end) end
if not rawget(_G, "LegendEnableSDKUI") then rawset(_G, "LegendEnableSDKUI", function() end) end
if not rawget(_G, "LegendSetLocalNotify") then rawset(_G, "LegendSetLocalNotify", function() end) end
if not rawget(_G, "LegendCancelLocalNotify") then rawset(_G, "LegendCancelLocalNotify", function() end) end
if not rawget(_G, "LegendAddNotification") then rawset(_G, "LegendAddNotification", function() end) end
if not rawget(_G, "LegendRemoveNotification") then rawset(_G, "LegendRemoveNotification", function() end) end

rawset(_G, "setfenv", function(fn_or_level, env)
    -- 支持 setfenv(fn, env) 和 setfenv(level, env) 两种调用方式
    local fn
    if type(fn_or_level) == "number" then
        local info = debug.getinfo(fn_or_level + 1, "f")
        fn = info and info.func
    else
        fn = fn_or_level
    end
    if not fn then return fn_or_level end
    -- 先尝试 debug.setfenv (Lua 5.1)
    local ok = pcall(debug.setfenv, fn, env)
    if ok then return fn end
    -- Lua 5.5 回退: 通过修改 _ENV 上值实现
    local i = 1
    while true do
        local name = debug.getupvalue(fn, i)
        if not name then break end
        if name == "_ENV" then
            debug.setupvalue(fn, i, env)
            break
        end
        i = i + 1
    end
    return fn
end)
rawset(_G, "getfenv", function(fn_or_level)
    local fn
    if type(fn_or_level) == "number" then
        local info = debug.getinfo(fn_or_level + 1, "f")
        fn = info and info.func
    else
        fn = fn_or_level
    end
    if not fn then return _G end
    -- 先尝试 debug.getfenv (Lua 5.1)
    local ok, env = pcall(debug.getfenv, fn)
    if ok then return env end
    -- Lua 5.5 回退: 获取 _ENV 上值
    local i = 1
    while true do
        local name, value = debug.getupvalue(fn, i)
        if not name then break end
        if name == "_ENV" then return value end
        i = i + 1
    end
    return _G
end)
rawset(_G, "module", function(name, ...)
    -- 复用已有的全局表（避免 module("ed") 覆盖 tools.lua 创建的 ed 表）
    local M = package.loaded[name]
    if type(M) ~= "table" then M = rawget(_G, name) end
    if type(M) ~= "table" then M = {} end
    rawset(_G, name, M)
    package.loaded[name] = M
    -- 应用 package.seeall 等参数（设置 __index = _G 以继承全局）
    for i = 1, select('#', ...) do
        local fn = select(i, ...)
        if type(fn) == "function" then pcall(fn, M) end
    end
    -- 设置调用者的环境为 M（模拟 Lua 5.1 module() 行为）
    local info = debug.getinfo(2, "f")
    if info and info.func then pcall(debug.setfenv, info.func, M) end
end)
-- 确保 package.seeall 存在
if not package.seeall then
    package.seeall = function(mod) setmetatable(mod, {__index = _G}) end
end

rawset(_G, "CCEGLView", {
    sharedOpenGLView = function()
        return {
            getFrameSize = function()
                local vs = ax.Director:getInstance():getVisibleSize()
                return { width = vs.width, height = vs.height }
            end
        }
    end,
})

-- CCB/Spine/Armature: 使用 C++ 绑定，如果没有则 fallback 到 stub
if not rawget(_G, "CCBContainer") then
    rawset(_G, "CCBContainer", {
        create = function(self, file) return ax.Node:create() end,
        new = function(cls, file) return ax.Node:create() end,
    })
end
-- SpineContainer 安全包装：
-- 确保无论 C++ 绑定是否成功注册，SpineContainer:create 都不会崩溃
-- 冒号调用 SpineContainer:create(path,name,scale) 和点调用 SpineContainer.create(path,name,scale) 都安全
do
    local _spineCreate = nil
    -- 尝试获取 C++ 绑定的 create 函数
    if rawget(_G, "SpineContainer") and type(SpineContainer) == "table" and type(SpineContainer.create) == "function" then
        _spineCreate = SpineContainer.create
    end

    -- 创建安全的 SpineContainer 全局表
    local _spineTable = {}
    rawset(_G, "SpineContainer", _spineTable)

    _spineTable.create = function(...)
        local args = {...}
        local path, name, scale
        if type(args[1]) == "string" then
            path, name, scale = args[1], args[2], args[3] or 1.0
        elseif type(args[1]) == "table" and type(args[2]) == "string" then
            path, name, scale = args[2], args[3], args[4] or 1.0
        else
            print("[WARN] SpineContainer.create unexpected args")
            return ax.Node:create()
        end

        if _spineCreate then
            local ok, spine = pcall(_spineCreate, path, name, scale)
            if not ok or spine == nil then
                print("[WARN] SpineContainer.create failed: " .. tostring(path).."/"..tostring(name))
                return nil
            end
            return spine
        else
            print("[WARN] SpineContainer.create no C++ binding, returning nil")
            return nil
        end
    end

    -- tolua.cast 安全包装
    local _origToluaCast = nil
    if tolua and type(tolua.cast) == "function" then
        _origToluaCast = tolua.cast
        tolua.cast = function(obj, typeName)
            local ok, result = pcall(_origToluaCast, obj, typeName)
            if not ok then
                return obj  -- cast 失败就直接返回原对象
            end
            return result
        end
    end
end
if not rawget(_G, "ArmatureContainer") then
    rawset(_G, "ArmatureContainer", {
        create = function(self, ...) return ax.Node:create() end,
        new = function(cls, ...) return ax.Node:create() end,
    })
end

-----------------------------------------------------------------
-- 加载 bit 模块
-----------------------------------------------------------------
local _bit_ok, _bit_mod = pcall(require, "bit")
if _bit_ok and type(_bit_mod) == "table" then
    rawset(_G, "bit", _bit_mod)
end

-----------------------------------------------------------------
-- 加载 Axmol 核心扩展（提供 ax.vec2, ax.size, ax.rect, ax.p 等）
-----------------------------------------------------------------
local axmolCoreOk, axmolCoreErr = pcall(require, "axmol.core.Axmol")
print("axmol.core.Axmol: " .. (axmolCoreOk and "OK" or "FAIL: " .. tostring(axmolCoreErr)))

-----------------------------------------------------------------
-- 预加载语言文件
-- 直接 require 即可，Lua 5.5 对路径中的 '-' 没有问题
-----------------------------------------------------------------
for _, _ln in ipairs({"en-US", "zh-CN", "de-DE", "ko-KR", "pt-BR", "ru-RU", "tr-TR"}) do
    local _modname = "language/" .. _ln
    if not package.loaded[_modname] then
        local _ok, _result = pcall(require, _modname)
        if _ok then
            package.loaded[_modname] = _result or true
        else
            print("[LANG] require " .. _ln .. " failed: " .. tostring(_result):match("[^\n]+"))
        end
    end
end
print("[LANG] preloaded en-US=" .. tostring(type(package.loaded["language/en-US"])))

-----------------------------------------------------------------
-- 确保 ax.Handler 常量可用（AX_USE_FRAMEWORK=false 时不会自动加载 Constants.lua）
-----------------------------------------------------------------
if not rawget(ax, "Handler") then
    pcall(require, "axmol.core.Constants")
end
if not rawget(ax, "Handler") then
    -- 手动定义最低限度的 Handler 常量
    ax.Handler = {}
    ax.Handler.EVENT_TOUCH_BEGAN      = 40
    ax.Handler.EVENT_TOUCH_MOVED      = 41
    ax.Handler.EVENT_TOUCH_ENDED      = 42
    ax.Handler.EVENT_TOUCH_CANCELLED  = 43
    ax.Handler.EVENT_TOUCHES_BEGAN    = 44
    ax.Handler.EVENT_TOUCHES_MOVED    = 45
    ax.Handler.EVENT_TOUCHES_ENDED    = 46
    ax.Handler.EVENT_TOUCHES_CANCELLED = 47
    ax.Handler.EVENT_KEYBOARD_PRESSED  = 38
    ax.Handler.EVENT_KEYBOARD_RELEASED = 39
    ax.Handler.EVENT_MOUSE_DOWN       = 48
    ax.Handler.EVENT_MOUSE_UP         = 49
    ax.Handler.EVENT_MOUSE_MOVE       = 50
    ax.Handler.EVENT_MOUSE_SCROLL     = 51
end

-----------------------------------------------------------------
-- 加载兼容层
-----------------------------------------------------------------
local ok, err = pcall(require, "compat_cocos2dx")
print("compat_cocos2dx: " .. (ok and "OK" or "FAIL: " .. tostring(err)))

-----------------------------------------------------------------
-- 加载游戏模块
-----------------------------------------------------------------

-- 修复 stub 单例方法：让返回值类型安全（不返回 nil 导致字符串连接崩溃）
local function safeStubReturns()
    -- SeverConsts
    if rawget(_G, "SeverConsts") then
        local sc = SeverConsts
        if sc.getBaseVersion then sc.getBaseVersion = function() return "1.0.0-axmol" end end
        if sc.getSeverDefaultID then sc.getSeverDefaultID = function() return 1 end end
        if sc.getBaseVersion then sc.setIsInLoading = function() end end
        if sc.getServerInGrayMsg then sc.getServerInGrayMsg = function() return "" end end
        if sc.getServerInUpdateMsg then sc.getServerInUpdateMsg = function() return "" end end
        if sc.getServerInfoByLua then sc.getServerInfoByLua = function() return {} end end
    end
    -- libOS
    if rawget(_G, "libOS") then
        local lo = libOS
        if lo.getInstance then
            local origGI = lo.getInstance
            lo.getInstance = function() return lo end
        end
        if lo.avalibleMemory then lo.avalibleMemory = function() return 512 end end
        if lo.getFreeSpace then lo.getFreeSpace = function() return 1024 end end
        if lo.getNetWork then lo.getNetWork = function() return 1 end end
        if lo.getDeviceID then lo.getDeviceID = function() return "axmol-device-001" end end
        if lo.getPlatformInfo then lo.getPlatformInfo = function() return "Axmol Stub" end end
        if lo.generateSerial then lo.generateSerial = function() return "serial-001" end end
    end
    -- libPlatform
    if rawget(_G, "libPlatform") then
        local lp = libPlatform
        if lp.getLogined then lp.getLogined = function() return false end end
        if lp.loginUin then lp.loginUin = function() return "stub-uin" end end
        if lp.getClientChannel then lp.getClientChannel = function() return "debug" end end
        if lp.getPlatformId then lp.getPlatformId = function() return 0 end end
        if lp.getPlatformInfo then lp.getPlatformInfo = function() return "Axmol Debug" end end
    end
    -- libPlatformManager
    if rawget(_G, "libPlatformManager") then
        local lpm = libPlatformManager
        if lpm.getPlatform then lpm.getPlatform = function() return libPlatform or {} end end
    end
    -- LegendAnimation
    if rawget(_G, "LegendAnimation") then
        LegendAnimation.gc = function() end
        LegendAnimation.setgcTime = function() end
    end
end
safeStubReturns()
local coreModules = {
    "tools", "stringutil", "stringbuffer", "util/list", "GameConfig",
    "datatable", "event/event", "event/systemevent",
    "LocalString",
    "resource_manager", "network", "soundres", "sound",
    "pb",
    "ui/announce/announce",
    "ui/controllers/button", "ui/controllers/panel",
    "ui/basetouchnode", "ui/basenode", "ui/basescene",
    "ed", "maingameproject",
    -- ui/framework is loaded via loadAllFiles in hello.lua (needs frameworklsr)
}

local okCount, failCount = 0, 0

-- LegendAnimation stub methods (added by C++ binding, need extra methods)
if rawget(_G, "LegendAnimation") then
    if not LegendAnimation.gc then LegendAnimation.gc = function() end end
    if not LegendAnimation.setgcTime then LegendAnimation.setgcTime = function() end end
end

for _, mod in ipairs(coreModules) do
    if mod == "network" then
        -- 模拟网络层：localMode 下模拟服务器响应
        local function stubSend(obj, msgType)
            print("[STUB-NET] send: " .. tostring(msgType))
            if msgType == "login" then
                -- 同步执行 loginReply（不使用延迟回调，避免 Axmol 中 action/scheduler 不触发的问题）
                print("[STUB-NET] login: executing synchronously")
                -- 延迟到下一帧用 scheduler 触发，确保 scene 已完全初始化
                local function doLoginReply()
                    print("[STUB-NET] doLoginReply called")
                    local ok_setup, err_setup = pcall(function()
                        if ed.player and ed.player.setup then
                            local mockUser = {
                                _userid = 1,
                                _name_card = {
                                    _name = "Player",
                                    _last_set_name_time = 0,
                                    _avatar = 1,
                                },
                                _level = 1,
                                _recharge_sum = 0,
                                _exp = 0,
                                _money = 100000,
                                _rmb = 5000,
                                _vitality = {
                                    _current = 120,
                                    _lastchange = 0,
                                    _todaybuy = 0,
                                    _lastbuy = 0,
                                },
                                _items = {},
                                _heroes = {},
                                _userstage = {
                                    _normal_stage_stars = {},
                                    _elite_stage_stars = {},
                                    _elite_daily_record = {},
                                    _elite_reset_time = 0,
                                    _sweep = { _last_reset_time = 0, _today_free_sweep_times = 0 },
                                    _act_reset_time = 0,
                                },
                                _skill_level_up = {
                                    _skill_levelup_chance = 5,
                                    _skill_levelup_cd = 0,
                                    _reset_times = 0,
                                    _last_reset_date = 0,
                                },
                                _tutorial = (function()
                                    local t = {}
                                    for i = 1, 96 do t[i] = 10 end
                                    return t
                                end)(),
                                _task = {},
                                _task_finished = {},
                                _last_login = 0,
                                _dailyjob = {},
                                _tavern_record = {},
                                _usermidas = {
                                    _last_change = 0,
                                    _today_times = 0,
                                },
                                _daily_login = {
                                    _status = "nothing",
                                    _frequency = 0,
                                    _last_login_date = 0,
                                },
                                _shop = {
                                    { id = 1, last_auto_refresh_time = 0, expire_time = 0, last_manual_refresh_time = 0, today_times = 0, goods = {} }
                                },
                            }
                            ed.player:setup(mockUser)
                            print("[STUB-NET] Player setup complete")
                        end
                    end)
                    if not ok_setup then print("[STUB-NET] Player setup error: " .. tostring(err_setup)) end
                    if ed.setUserid then ed.setUserid(1) end
                    FireEvent("LoginSuc")
                    if ed.netreply and ed.netreply.loginReply then
                        print("[STUB-NET] Simulating loginReply")
                        local ok, err = pcall(ed.netreply.loginReply)
                        if not ok then print("[STUB-NET] loginReply error: " .. tostring(err)) end
                        ed.netreply.loginReply = nil
                    end
                end
                -- 使用 scheduler 延迟 1 帧执行（确保 logo scene 的 mainLayer 已创建）
                local scheduler = ax.Director:getInstance():getScheduler()
                if scheduler then
                    local entry = nil
                    entry = scheduler:scheduleScriptFunc(function()
                        scheduler:unscheduleScriptEntry(entry)
                        doLoginReply()
                    end, 0.1, false)
                    print("[STUB-NET] login scheduled via scheduler")
                else
                    print("[STUB-NET] no scheduler, executing synchronously")
                    doLoginReply()
                end
            elseif msgType == "ask_activity_info" then
                -- 活动信息请求，忽略
            elseif msgType == "job_rewards" then
                -- 任务奖励，忽略
            end
        end
        local nw = { connect = function() end, send = stubSend, close = function() end, isConnected = function() return false end }
        package.loaded["network"] = nw; rawset(_G, "network", nw)
        ed.send = stubSend
        okCount = okCount + 1
        -- network.lua 会设置这些表，stub 也需要初始化
        if not ed.netreply then ed.netreply = {} end
        if not ed.netdata then ed.netdata = {} end
        if not ed.registerNetReply then ed.registerNetReply = function() end end
        if not ed.upmsg then ed.upmsg = { login = function() return {} end } end
        if not ed.downmsg then 
    ed.downmsg = setmetatable({}, {
        __index = function(t, key)
            t[key] = function() return {} end
            return t[key]
        end
    })
end
    elseif mod == "ed" then
        if package.loaded["ed"] then okCount = okCount + 1
        else failCount = failCount + 1 end
    else
        local ok2, err2 = pcall(require, mod)
        if ok2 then
            if mod == "tools" and rawget(_G, "ed") then package.loaded["ed"] = ed end
            okCount = okCount + 1
        else
            print("[FAIL] " .. mod .. ": " .. tostring(err2):match("[^\n]+"))
            failCount = failCount + 1
        end
    end
end

-----------------------------------------------------------------
-- tools.lua 加载后 ed 表被重新创建，需要重新设置 stub
-----------------------------------------------------------------
local function ensureStubsAfterTools()
    -- ed.config 被 tools.lua 的 ed={} 覆盖了，必须重建
    if not ed.config then ed.config = { localMode = true } end
    ed.config.localMode = true
    print("[ENSURE] ed.config = " .. tostring(ed.config) .. " localMode=" .. tostring(ed.config.localMode))
    if not ed.getUserid then ed.getUserid = function() return "ax-user-001" end end
    if not ed.getDeviceId then ed.getDeviceId = function() return "ax-device-001" end end
    if not ed.send then
        ed.send = function(msg, msgType)
            print("[STUB-SEND] " .. tostring(msgType))
            if msgType == "login" then
                -- 使用 scheduler 延迟执行（与第一处 stubSend 一致）
                local function doLoginReply()
                    local ok_s, err_s = pcall(function()
                        if ed.player and ed.player.setup then
                            local mockUser = {
                                _userid = 1,
                                _name_card = {_name="Player",_last_set_name_time=0,_avatar=1},
                                _level = 1, _recharge_sum = 0, _exp = 0,
                                _money = 100000, _rmb = 5000,
                                _vitality = {_current=120,_lastchange=0,_todaybuy=0,_lastbuy=0},
                                _items = {}, _heroes = {},
                                _userstage = {
                                    _normal_stage_stars = {},
                                    _elite_stage_stars = {},
                                    _elite_daily_record = {},
                                    _elite_reset_time = 0,
                                    _sweep = {_last_reset_time=0,_today_free_sweep_times=0},
                                    _act_reset_time = 0,
                                },
                                _skill_level_up = {
                                    _skill_levelup_chance = 5,
                                    _skill_levelup_cd = 0,
                                    _reset_times = 0,
                                    _last_reset_date = 0,
                                },
                                _tutorial = (function()
                                    local t = {}
                                    for i = 1, 96 do t[i] = 10 end
                                    return t
                                end)(),
                                _task = {}, _task_finished = {},
                                _last_login = 0, _dailyjob = {},
                                _tavern_record = {},
                                _usermidas = {_last_change=0,_today_times=0},
                                _daily_login = {_status="nothing",_frequency=0,_last_login_date=0},
                                _shop = {
                                    {id=1,last_auto_refresh_time=0,expire_time=0,last_manual_refresh_time=0,today_times=0,goods={}}
                                },
                            }
                            ed.player:setup(mockUser)
                            print("[STUB-NET] Player setup OK (ensureStubs)")
                        end
                    end)
                    if not ok_s then print("[STUB-NET] player setup err: " .. tostring(err_s)) end
                    if ed.setUserid then ed.setUserid(1) end
                    FireEvent("LoginSuc")
                    if ed.netreply and ed.netreply.loginReply then
                        print("[STUB-NET] Simulating loginReply (ensureStubs)")
                        local ok, err = pcall(ed.netreply.loginReply)
                        if not ok then print("[STUB-NET] loginReply error: " .. tostring(err)) end
                        ed.netreply.loginReply = nil
                    end
                end
                local scheduler = ax.Director:getInstance():getScheduler()
                if scheduler then
                    local entry = nil
                    entry = scheduler:scheduleScriptFunc(function()
                        scheduler:unscheduleScriptEntry(entry)
                        doLoginReply()
                    end, 0.1, false)
                    print("[STUB-NET] login scheduled via scheduler (ensureStubs)")
                else
                    print("[STUB-NET] no scheduler, executing synchronously (ensureStubs)")
                    doLoginReply()
                end
            elseif msgType == "ask_activity_info" then
            end
        end
    end
    if not ed.proc_net then ed.proc_net = function() end end
    if not ed.netreply then ed.netreply = {} end
    if not ed.netdata then ed.netdata = {} end
    if not ed.upmsg then
        ed.upmsg = { login = function() return {} end }
    elseif not ed.upmsg.login then
        ed.upmsg.login = function() return {} end
    end
    if not ed.downmsg then 
    ed.downmsg = setmetatable({}, {
        __index = function(t, key)
            t[key] = function() return {} end
            return t[key]
        end
    })
end
    if not ed.getMillionTime then ed.getMillionTime = function() return os.time() * 1000 end end
    if not ed.tick_interval then ed.tick_interval = 0.1 end
end
ensureStubsAfterTools()

-----------------------------------------------------------------
-- 加载额外游戏模块（数据表、角色、装备等）
-----------------------------------------------------------------
local gameModules = {
    "gamedatatables/gamedatatables",
    "record", "playertools", "player", "mercenary",
    "playerlimit", "enhancement", "fragment",
    "equip", "equipcraft", "hero_equip",
    "battle/battle_scene",
    "ui/parameter/parameter", "ui/parameter/baseres",
    "ui/parameter/uires", "ui/parameter/mainres",
    "ui/listener/baselsr",
}

local extraOk, extraFail = 0, 0
for _, mod in ipairs(gameModules) do
    local ok2, err2 = pcall(require, mod)
    if ok2 then
        extraOk = extraOk + 1
    else
        extraFail = extraFail + 1
        print("[MOD-FAIL] " .. mod .. ": " .. tostring(err2):match("[^\n]+"))
    end
end

print("=== Core: " .. okCount .. "/" .. #coreModules .. "  Game: " .. extraOk .. "/" .. #gameModules .. " ===")

-----------------------------------------------------------------
-- localMode: 标记所有教程已完成，跳过 5v5 教程直接进主场景
-----------------------------------------------------------------
do
    -- 方法1: 覆盖 player.getTutorialRecord 使其总返回大数
    if ed.player then
        pcall(function()
            ed.player.getTutorialRecord = function(self, key)
                return 999
            end
        end)
    end
    -- 方法2: 覆盖 tutorial.checkDone 使其总返回 true
    pcall(function()
        if ed.tutorial then
            ed.tutorial.checkDone = function(key) return true end
        end
    end)
    print("[LOCAL-MODE] All tutorials marked as completed")
end

-----------------------------------------------------------------
-- 场景已由 C++ AppDelegate 创建，直接加载游戏流程
-----------------------------------------------------------------
local director = ax.Director:getInstance()

-- 调试：输出分辨率信息
do
    local vs = director:getVisibleSize()
    local vo = director:getVisibleOrigin()
    local rv = director:getRenderView()
    print("[RES-DEBUG] VisibleSize: " .. vs.width .. "x" .. vs.height)
    print("[RES-DEBUG] VisibleOrigin: " .. vo.x .. "," .. vo.y)
    if rv then
        local ws = rv:getWindowSize()
        local ds = rv:getDesignResolutionSize()
        print("[RES-DEBUG] WindowSize: " .. ws.width .. "x" .. ws.height)
        print("[RES-DEBUG] DesignResSize: " .. ds.width .. "x" .. ds.height)
    else
        print("[RES-DEBUG] RenderView is NIL!")
    end
end

-- 包装 SpineContainer:create 使其安全处理版本不匹配
-- Spine 2.x 数据与 Axmol 4.x 运行时不兼容，C++ 层返回 fallback Node（带安全的方法 stub）
-- 这里不再需要 Lua 侧包装，C++ 层已处理所有 fallback
-- 保留这段代码以防 C++ 层返回 nil 的情况
do
    -- 不再需要 Lua 包装器
end

-- 加载 hello.lua 前确认 ed.config 存在
print("[PRE-HELLO] ed=" .. tostring(ed) .. " ed.config=" .. tostring(ed.config) .. " ed.config.localMode=" .. tostring(ed and ed.config and ed.config.localMode))
-- 直接加载 hello.lua（它末尾会调用 main() → pushScene logo → autoLogin → replaceScene main）
local helloOk, helloErr = pcall(require, "hello")
if not helloOk then
    print("[FATAL] hello.lua failed: " .. tostring(helloErr))
else
    print("[MAIN] hello.lua loaded OK")
end
