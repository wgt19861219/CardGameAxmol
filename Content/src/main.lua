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

if not rawget(_G, "LegendSetAniScaleFactor") then rawset(_G, "LegendSetAniScaleFactor", function() end) end
if not rawget(_G, "LegendSetSoundSwitch") then rawset(_G, "LegendSetSoundSwitch", function() end) end
rawset(_G, "LegendGetDeviceID", function() return "ax-001" end)
rawset(_G, "LegendFindFileCpp", function(f) return f end)
rawset(_G, "LegendGetEncryptedFileData", function(path)
    -- Read proto files from Content/src/ directory
    -- path is "data/up.proto" -> resolve to "src/up.proto" relative to write dir
    local fu = CCFileUtils:sharedFileUtils()
    -- Try multiple search paths
    local searchPaths = {
        "src/" .. path:sub("^data/", ""),
        "Content/src/" .. path:sub("^data/", ""),
        path:sub("^data/", ""),
        path,
    }
    for _, searchPath in ipairs(searchPaths) do
        local fullPath = fu:fullPathForFilename(searchPath)
        if fullPath and fullPath ~= "" then
            local file = io.open(fullPath, "r")
            if file then
                local content = file:read("*a")
                file:close()
                return content
            end
        end
    end
    -- Fallback: try direct path
    local file = io.open(path, "r")
    if file then
        local content = file:read("*a")
        file:close()
        return content
    end
    return nil
end)
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
        -- 使用 os.clock() 获取毫秒精度（os.time() 只有秒级精度，导致 dt 计算不准）
        local million = math.floor(os.clock() * 1000)
        return t.year, t.month, t.day, t.hour, t.min, t.sec, os.time(), million
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
if not ed.delaySend then ed.delaySend = function() end end
if not ed.upmsg then
    ed.upmsg = setmetatable({ login = function() return {} end }, {
        __index = function(t, key)
            -- Auto-create message factory for any proto message type
            t[key] = function() return {} end
            return t[key]
        end
    })
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
rawset(_G, "LegendLoadShader", function() end)  -- force no-op: shader files don't exist
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

    -- 支持点分隔的模块名：创建中间表并注册到正确位置
    -- e.g. module("ed.FloatingBarType.HP") -> ed.FloatingBarType.HP = M
    local parts = {}
    for part in name:gmatch("[^.]+") do parts[#parts+1] = part end
    if #parts > 1 then
        local parent = _G
        for i = 1, #parts - 1 do
            if type(parent[parts[i]]) ~= "table" then
                parent[parts[i]] = {}
            end
            parent = parent[parts[i]]
        end
        parent[parts[#parts]] = M
    else
        rawset(_G, name, M)
    end

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
-- 加载 JSON 模块（存档系统需要）
-----------------------------------------------------------------
local _json_ok, _json_mod = pcall(require, "util/json")
-- util/json.lua 内部调用 module("json")，注册到 package.loaded["json"] 而非 "util/json"
-- require 返回值可能是 true 而非 table，需要从 package.loaded["json"] 取回实际模块表
if _json_ok and type(_json_mod) ~= "table" then
    _json_mod = package.loaded["json"]
end
-- Lua 5.5 的 debug.setfenv 不存在，module() 无法切换环境，
-- 导致 json.lua 中的 encode/decode 被定义在 _G 上而非模块表上
if type(_json_mod) == "table" then
    if not _json_mod.encode and rawget(_G, "encode") then
        _json_mod.encode = rawget(_G, "encode")
    end
    if not _json_mod.decode and rawget(_G, "decode") then
        _json_mod.decode = rawget(_G, "decode")
    end
    rawset(_G, "json", _json_mod)
    print("[JSON] json module loaded OK")
else
    print("[JSON] json module failed: " .. tostring(_json_mod))
end

-----------------------------------------------------------------
-- 存档系统
-----------------------------------------------------------------
local SAVE_FILE_NAME = "cardgame_save.json"

local function getSavePath()
    local fu = CCFileUtils:sharedFileUtils()
    local writablePath = fu:getWritablePath()
    if writablePath and #writablePath > 0 then
        return writablePath .. SAVE_FILE_NAME
    end
    return SAVE_FILE_NAME
end

local function deepCopy(obj)
    if type(obj) ~= "table" then return obj end
    local copy = {}
    for k, v in pairs(obj) do
        copy[k] = deepCopy(v)
    end
    return copy
end

local function saveGame()
    if not ed.player or not ed.player.data then return false end
    if not json or not json.encode then return false end
    local ok, result = pcall(function()
        local data = deepCopy(ed.player.data)
        -- 清理酒馆历史记录（409KB+，占存档99%），只保留最近10条
        if data._tavern_record and type(data._tavern_record) == "table" then
            local tr = data._tavern_record
            if #tr > 10 then
                local recent = {}
                for i = #tr - 9, #tr do table.insert(recent, tr[i]) end
                data._tavern_record = recent
            end
        end
        local encoded = json.encode(data)
        local path = getSavePath()
        local f = io.open(path, "w")
        if f then
            f:write(encoded)
            f:close()
            print("[SAVE] Saved " .. #encoded .. " bytes")
            return true
        end
        return false
    end)
    if not ok then
        print("[SAVE] Error: " .. tostring(result))
        return false
    end
    return result
end
ed.saveGame = saveGame

local function loadSaveData()
    if not json or not json.decode then return nil end
    local ok, result = pcall(function()
        local path = getSavePath()
        local f = io.open(path, "r")
        if not f then return nil end
        local content = f:read("*a")
        f:close()
        if not content or #content == 0 then return nil end
        -- 存档超过 50KB 说明包含了大量酒馆历史记录，json.decode 会极慢
        -- 直接删掉旧存档，让游戏从默认数据开始（saveGame 会保存精简版）
        if #content > 50000 then
            print("[SAVE] Large save file (" .. #content .. " bytes), removing and using defaults")
            os.remove(path)
            return nil
        end
        local data = json.decode(content)
        print("[SAVE] Loaded " .. #content .. " bytes (tavern_record truncated)")
        return data
    end)
    if not ok then
        print("[SAVE] Load error: " .. tostring(result))
        return nil
    end
    return result
end
ed.loadSaveData = loadSaveData

-- 定时自动保存（每60秒）
local function startAutoSave()
    local scheduler = ax.Director:getInstance():getScheduler()
    if scheduler then
        scheduler:scheduleScriptFunc(function()
            saveGame()
        end, 60, false)
    end
end
ed.startAutoSave = startAutoSave

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
    "resource_manager", "pb", "network", "soundres", "sound",
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
        -- local_server 延迟加载（需要 pb_loader，等 pb 模块加载后再初始化）
        local function getLocalServer()
            local ls = rawget(_G, "local_server")
            if ls then return ls end
            -- 检查 package.loaded（可能已被其他方式加载）
            ls = package.loaded["local_server"]
            if ls then
                rawset(_G, "local_server", ls)
                print("[STUB-NET] local_server found in package.loaded")
                return ls
            end
            print("[STUB-NET] getLocalServer: attempting to load local_server")
            local ok, err
            -- 方式1: require（先清除可能的缓存）
            package.loaded["local_server"] = nil
            ok, err = pcall(function()
                ls = require("local_server")
            end)
            if not ok or not ls then
                -- 方式2: 手动通过 Axmol 加载器查找
                local loaders = package.loaders or package.searchers
                if loaders then
                    for i, loader in ipairs(loaders) do
                        local ok2, result = pcall(function() return loader("local_server") end)
                        if ok2 and type(result) == "function" then
                            local ok3, result3 = pcall(result)
                            if ok3 then
                                ls = result3
                                break
                            end
                        end
                    end
                end
            end
            if ls then
                ok, err = pcall(function() ls.init() end)
                if not ok then
                    print("[STUB-NET] local_server.init error: " .. tostring(err))
                    LegendLog("[STUB-NET] local_server.init ERROR: " .. tostring(err))
                end
                rawset(_G, "local_server", ls)
                print("[STUB-NET] local_server loaded OK")
            else
                print("[STUB-NET] local_server NOT found by any method")
                LegendLog("[STUB-NET] local_server NOT found by any method: " .. tostring(err))
            end
            return ls
        end
        -- 生成默认用户数据（登录和删号共用）
        local function createDefaultUserData(overrides)
            local data = {
                _userid = 1,
                _name_card = {
                    _name = "Player",
                    _last_set_name_time = 0,
                    _avatar = 1,
                },
                _level = 30,
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
                    _skill_levelup_cd = os.time(),
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
            if overrides then
                for k, v in pairs(overrides) do data[k] = v end
            end
            return data
        end
        -- 辅助：addHero 后设置英雄初始属性
        -- fromGM=true 时设置高等级（GM命令获取所有英雄用）
        local function addHeroWithLevel(tid, fromGM)
            if not ed.player or not ed.player.addHero then return end
            local isNew = not ed.player.heroes[tid]
            ed.player:addHero(tid)
            if isNew and ed.player.heroes[tid] then
                pcall(function()
                    local hero = ed.player.heroes[tid]
                    if fromGM then
                        local playerLevel = ed.player._level or 30
                        hero._level = playerLevel
                        hero._rank = math.max(hero._rank or 1, 5)
                        hero._stars = math.max(hero._stars or 1, 2)
                        hero._gs = (hero._gs or 0) + playerLevel * 10
                    else
                        local unitTable = ed.getDataTable("Unit")
                        local initStars = (unitTable and unitTable[tid]) and unitTable[tid]["Initial Stars"] or 1
                        hero._level = 1
                        hero._rank = 1
                        hero._stars = initStars
                        hero._gs = 0
                    end
                end)
            end
        end
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
                            -- 尝试从存档加载
                            local savedData = ed.loadSaveData and ed.loadSaveData()
                            if savedData and savedData._userid then
                                print("[STUB-NET] Loading saved game data")
                                ed.player:setup(savedData)
                            else
                                print("[STUB-NET] No save data, using default mockUser")
                                local mockUser = createDefaultUserData()
                                ed.player:setup(mockUser)
                            end
                            print("[STUB-NET] Player setup complete")
                        end
                    end)
                    if not ok_setup then print("[STUB-NET] Player setup error: " .. tostring(err_setup)) end
                    -- 登录后重算所有英雄GS（修正旧存档或初始值的GS=0问题）
                    pcall(function()
                        if ed.player and ed.player.heroes and ed.recalcHeroGs then
                            for tid, hero in pairs(ed.player.heroes) do
                                ed.recalcHeroGs(hero)
                            end
                            print("[GS] login recalc done")
                        else
                            print("[GS] no player/heroes/recalcFn: p=" .. tostring(ed.player ~= nil) .. " h=" .. tostring(ed.player and ed.player.heroes ~= nil) .. " fn=" .. tostring(ed.recalcHeroGs ~= nil))
                        end
                    end)
                    -- 强制初始化商店数据（确保有商品避免 market.lua 崩溃）
                    pcall(function()
                        if ed.player and ed.player.refreshShopData then
                            local existing = ed.player:getShopData(1)
                            local goods = existing and existing._current_goods
                            if not goods or #goods == 0 then
                                ed.player:refreshShopData({
                                    _id = 1,
                                    _last_auto_refresh_time = os.time(),
                                    _expire_time = 0,
                                    _last_manual_refresh_time = os.time(),
                                    _today_times = 0,
                                    _current_goods = {
                                        {_id = "vip_exp", _type = "diamond", _price = 200, _amount = 1, _is_sale = false},
                                        {_id = 101, _type = "gold", _price = 100, _amount = 1, _is_sale = false},
                                        {_id = 102, _type = "gold", _price = 200, _amount = 1, _is_sale = false},
                                    },
                                })
                            end
                        end
                    end)
                    if ed.setUserid then ed.setUserid(1) end
                    -- 保存游戏数据（首通或加载后立即保存一次）
                    if ed.saveGame then ed.saveGame() end
                    -- 启动定时自动保存
                    if ed.startAutoSave then ed.startAutoSave() end
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
            elseif msgType == "tavern_draw" then
                LegendLog("[STUB-NET] tavern_draw: handling directly")
                local drawType = obj._draw_type or 0
                local boxType = obj._box_type or 1
                local drawCount = drawType == 1 and 10 or 1

                -- 品质上限: bronze=3, gold/magic=4+
                local maxQuality = 3
                if boxType >= 3 then maxQuality = 6 end

                -- 识别灵魂石和装备（只收集英雄碎片，过滤非英雄条目）
                local soulStoneIds = {}
                local normalEquips = {}
                pcall(function()
                    local fragTable = ed.getDataTable("fragment")
                    local unitTable = ed.getDataTable("Unit")
                    if fragTable then
                        for fid, frow in pairs(fragTable) do
                            if type(fid) == "number" and frow["Fragment ID"] then
                                -- 只将实际英雄的碎片加入灵魂石池
                                local isHero = unitTable and unitTable[fid]
                                    and unitTable[fid]["Unit Type"] == "Hero"
                                if isHero then
                                    soulStoneIds[frow["Fragment ID"]] = true
                                end
                            end
                        end
                    end
                    local equipTable = ed.getDataTable("equip")
                    if equipTable then
                        for eid, row in pairs(equipTable) do
                            if type(eid) == "number" and eid > 0 and row.Quality then
                                if not soulStoneIds[eid] and row.Quality <= maxQuality then
                                    normalEquips[row.Quality] = normalEquips[row.Quality] or {}
                                    table.insert(normalEquips[row.Quality], eid)
                                end
                            end
                        end
                    end
                end)

                -- 收集英雄→灵魂石映射（用于掉落完整英雄）
                local heroSummonList = {}
                pcall(function()
                    local unitTable = ed.getDataTable("Unit")
                    local fragTable = ed.getDataTable("fragment")
                    local heroStars = ed.getDataTable("HeroStars")
                    if not unitTable or not fragTable or not heroStars then return end
                    for tid, unit in pairs(unitTable) do
                        if type(tid) == "number" and tid > 0 and tid < 100
                            and unit["Unit Type"] == "Hero" and unit.Portrait then
                            local frag = fragTable[tid]
                            if frag then
                                local stoneId = frag["Fragment ID"]
                                local initStars = unit["Initial Stars"] or 1
                                local convertAmount = (heroStars[initStars] or {})["Convert Fragments"] or 80
                                if stoneId then
                                    table.insert(heroSummonList, { stoneId = stoneId, heroId = tid, amount = convertAmount })
                                end
                            end
                        end
                    end
                end)

                local soulStoneList = {}
                for sid, _ in pairs(soulStoneIds) do table.insert(soulStoneList, sid) end

                -- 生成掉落
                local loot = {}
                local function pickEquip(maxQ)
                    for q = maxQ, 1, -1 do
                        local pool = normalEquips[q]
                        if pool and #pool > 0 then return pool[math.random(1, #pool)] end
                    end
                    return math.random(100, 120)
                end

                local heroChance = boxType >= 3 and 8 or 0
                local soulChance = boxType >= 3 and 12 or 10

                for i = 1, drawCount do
                    local q = 1
                    local r = math.random(1, 100)
                    if boxType >= 3 then
                        if r <= 1 then q = 6
                        elseif r <= 5 then q = 5
                        elseif r <= 15 then q = 4
                        elseif r <= 35 then q = 3
                        elseif r <= 65 then q = 2
                        else q = 1 end
                    else
                        if r <= 25 then q = 3
                        elseif r <= 60 then q = 2
                        else q = 1 end
                    end

                    local roll = math.random(1, 100)
                    if roll <= heroChance and #heroSummonList > 0 then
                        local entry = heroSummonList[math.random(1, #heroSummonList)]
                        table.insert(loot, ed.makebits(11, entry.amount, 10, entry.stoneId))
                    elseif roll <= heroChance + soulChance and #soulStoneList > 0 then
                        local sid = soulStoneList[math.random(1, #soulStoneList)]
                        table.insert(loot, ed.makebits(11, math.random(1, 3), 10, sid))
                    else
                        local equipId = pickEquip(q)
                        table.insert(loot, ed.makebits(11, math.random(1, 3), 10, equipId))
                    end
                end

                -- 处理掉落物品
                for k, v in pairs(loot) do
                    pcall(function()
                        local id = ed.bits(v, 0, 10)
                        local amount = ed.bits(v, 10, 11)
                        local it = ed.itemType(id)
                        if it == "hero" then
                            LegendLog("[TAVERN] hero direct: id=" .. id .. " amount=" .. amount)
                            addHeroWithLevel(id)
                        elseif it == "equip" then
                            local mhid = ed.readhero and ed.readhero.getMakeid(id)
                            if mhid and ed.itemType(mhid) == "hero" then
                                if ed.player and ed.player.heroes and ed.player.heroes[mhid] then
                                    LegendLog("[TAVERN] fragment→equip: frag=" .. id .. " hero=" .. mhid .. " amount=" .. amount)
                                    if ed.player.addEquip then ed.player:addEquip(id, amount) end
                                else
                                    LegendLog("[TAVERN] fragment→hero: frag=" .. id .. " hero=" .. mhid)
                                    addHeroWithLevel(mhid)
                                end
                            else
                                LegendLog("[TAVERN] equip: id=" .. id .. " amount=" .. amount)
                                if ed.player and ed.player.addEquip then ed.player:addEquip(id, amount) end
                            end
                        end
                    end)
                end
                -- 扣费
                pcall(function()
                    local nd = ed.netdata
                    if nd and nd.tavern and nd.tavern.type ~= "stone" then
                        local td = nd.tavern
                        if not td.isFree then
                            local pay = td.cost and td.cost.pay
                            local number = td.cost and td.cost.number or 0
                            if pay == "Gold" then
                                ed.player._money = (ed.player._money or 0) - number
                            elseif pay == "Diamond" then
                                ed.player._rmb = (ed.player._rmb or 0) - number
                            end
                        end
                        nd.tavern = nil
                    end
                end)
                LegendLog("[STUB-NET] tavern_draw: loot_count=" .. tostring(#loot) .. ", calling netreply.tavern")
                local handler = ed.netreply and ed.netreply.tavern
                if handler then
                    local ok, err = pcall(handler, loot)
                    if not ok then
                        LegendLog("[STUB-NET] tavern callback ERROR: " .. tostring(err))
                    end
                    ed.netreply.tavern = nil
                else
                    LegendLog("[STUB-NET] WARNING: no tavern callback registered!")
                end
            elseif msgType == "ask_magicsoul" then
                -- 魂匣英雄列表：返回随机英雄ID
                LegendLog("[STUB-NET] ask_magicsoul: handling directly")
                local ids = {}
                for i = 1, 6 do
                    table.insert(ids, math.random(1, 30))
                end
                ids[1] = math.random(1, 15)
                local handler2 = ed.netreply and ed.netreply.askMagicsoul
                if handler2 then
                    pcall(handler2, ids)
                    ed.netreply.askMagicsoul = nil
                end
            elseif msgType == "gm_cmd" then
                -- GM 命令：直接处理，不依赖 local_server 模块
                LegendLog("[STUB-NET] gm_cmd: handling directly, obj type=" .. type(obj))
                -- 调试：遍历 obj 的所有字段
                local fields = {}
                for k, v in pairs(obj or {}) do
                    table.insert(fields, tostring(k) .. "=" .. tostring(v))
                end
                LegendLog("[STUB-NET] gm_cmd obj fields: " .. table.concat(fields, ", "))

                local function handleGmCmd(gmObj)
                    LegendLog("[STUB-NET] gm_cmd obj: _set_money=" .. tostring(gmObj._set_money)
                        .. " _unlock=" .. tostring(gmObj._unlock_all_stages)
                        .. " _get_all_heroes=" .. tostring(gmObj._get_all_heroes)
                        .. " _set_vitality=" .. tostring(gmObj._set_vitality)
                        .. " _set_player_level=" .. tostring(gmObj._set_player_level))

                    -- 解锁所有关卡
                    if gmObj._unlock_all_stages and gmObj._unlock_all_stages > 0 then
                        if ed.player and ed.player._userstage then
                            ed.player._userstage._normal_stage_stars = ed.player._userstage._normal_stage_stars or {}
                            -- 标记所有关卡为3星
                        end
                        LegendLog("[STUB-NET] gm_cmd: unlock_all_stages=" .. tostring(gmObj._unlock_all_stages))
                    end

                    -- 获取所有英雄（localMode 下自动设置英雄等级=玩家等级、rank>=5 以支持技能升级）
                    if gmObj._get_all_heroes and gmObj._get_all_heroes > 0 then
                        local ok_gah, err_gah = xpcall(function()
                            local UnitTable = ed.getDataTable("Unit")
                            if not UnitTable then return end
                            if not ed.player then return end
                            if not ed.player.addHero then return end
                            if not ed.player.heroes then return end
                            local playerLevel = ed.player._level or 30
                            local count = 0
                            for tid, unit in pairs(UnitTable) do
                                if type(tid) == "number" and tid > 0 and unit.Name
                                    and unit["Unit Type"] == "Hero" and unit.Portrait then
                                    if not ed.player.heroes[tid] then
                                        local ok_h = pcall(function() addHeroWithLevel(tid, true) end)
                                        if ok_h then count = count + 1 end
                                    else
                                        -- 已有英雄也刷新等级（修复之前 addHero 默认 level=1 的英雄）
                                        pcall(function()
                                            local hero = ed.player.heroes[tid]
                                            if hero and (hero._level or 0) < playerLevel then
                                                hero._level = playerLevel
                                                hero._rank = math.max(hero._rank or 1, 5)
                                                hero._stars = math.max(hero._stars or 1, 2)
                                                hero._gs = (hero._gs or 0) + playerLevel * 10
                                            end
                                        end)
                                    end
                                end
                            end
                            LegendLog("[GM] get_all_heroes: added " .. tostring(count) .. " heroes, level=" .. tostring(playerLevel))
                            -- 清理非 Hero 类型的单位（旧存档可能混入了怪物/召唤物）
                            local removed = 0
                            for tid, hero in pairs(ed.player.heroes) do
                                local u = UnitTable[tid]
                                if u and (u["Unit Type"] ~= "Hero" or not u.Portrait) then
                                    ed.player.heroes[tid] = nil
                                    removed = removed + 1
                                end
                            end
                            -- 同步清理 _heroes 数组
                            for i = #ed.player._heroes, 1, -1 do
                                local h = ed.player._heroes[i]
                                local u = UnitTable[h._tid]
                                if u and (u["Unit Type"] ~= "Hero" or not u.Portrait) then
                                    table.remove(ed.player._heroes, i)
                                    removed = removed + 1
                                end
                            end
                            if removed > 0 then
                                LegendLog("[GM] get_all_heroes: removed " .. tostring(removed) .. " non-hero units")
                            end
                        end, function(err) LegendLog("[GM] get_all_heroes ERROR: " .. tostring(err)) end)
                        if not ok_gah then
                            LegendLog("[STUB-NET] gm_cmd: get_all_heroes failed: " .. tostring(err_gah))
                        end
                    end

                    -- 设置金币/钻石
                    if gmObj._set_money then
                        local sm = gmObj._set_money
                        local mtype = sm._type
                        local amount = sm._amount
                        LegendLog("[STUB-NET] gm_cmd: _set_money type=" .. tostring(mtype) .. " amount=" .. tostring(amount))
                        if mtype and amount then
                            if mtype == "gold" then
                                if ed.player then ed.player._money = amount end
                                LegendLog("[STUB-NET] gm_cmd: set gold=" .. tostring(amount))
                            elseif mtype == "diamond" then
                                if ed.player then ed.player._rmb = amount end
                                LegendLog("[STUB-NET] gm_cmd: set diamond=" .. tostring(amount))
                            end
                        end
                        -- 兼容旧格式
                        if sm._money and ed.player then ed.player._money = sm._money end
                        if sm._rmb and ed.player then ed.player._rmb = sm._rmb end
                    end

                    -- 设置体力
                    if gmObj._set_vitality then
                        pcall(function()
                            if ed.player and ed.player._vitality then
                                ed.player._vitality._current = gmObj._set_vitality
                            end
                        end)
                        LegendLog("[STUB-NET] gm_cmd: set_vitality=" .. tostring(gmObj._set_vitality))
                    end

                    -- 重置账号（删号）
                    if gmObj._reset_device then
                        LegendLog("[GM] _reset_device: resetting account...")
                        pcall(function()
                            local resetUser = createDefaultUserData({
                                _level = 1,
                                _money = 10000,
                                _rmb = 1000,
                            })
                            -- 清空旧数据再 setup，否则 heroes 等缓存表不会被清除
                            if ed.player then
                                ed.player.heroes = {}
                            end
                            if ed.player and ed.player.setup then
                                ed.player:setup(resetUser)
                            end
                            -- 删除存档文件
                            local FileUtils = cc.FileUtils and cc.FileUtils:getInstance()
                            if FileUtils then
                                local savePath = FileUtils:getWritablePath() .. "save.json"
                                FileUtils:removeFile(savePath)
                                LegendLog("[GM] _reset_device: save file removed: " .. savePath)
                            end
                            LegendLog("[GM] _reset_device: account reset complete")
                        end)
                        -- 触发 UI 刷新
                        pcall(function()
                            if FireEvent then FireEvent("LoginSuc") end
                        end)
                    end

                    -- 设置英雄信息
                    -- 设置英雄信息
                    if gmObj._set_hero_info then
                        for _, heroMsg in ipairs(gmObj._set_hero_info) do
                            local tid = heroMsg._tid
                            if tid and ed.player and ed.player.heroes then
                                for _, hero in pairs(ed.player.heroes) do
                                    if hero._tid == tid then
                                        if heroMsg._rank then hero._rank = heroMsg._rank end
                                        if heroMsg._level then hero._level = heroMsg._level end
                                        if heroMsg._stars then hero._stars = heroMsg._stars end
                                        if heroMsg._exp then hero._exp = heroMsg._exp end
                                        if heroMsg._gs then hero._gs = heroMsg._gs end
                                    end
                                end
                            end
                        end
                    end

                    -- 设置充值总额
                    if gmObj._set_recharge_sum and ed.player then
                        ed.player._recharge_sum = gmObj._set_recharge_sum
                    end

                    -- 设置玩家等级
                    if gmObj._set_player_level and ed.player then
                        ed.player._level = gmObj._set_player_level
                    end

                    -- 设置玩家经验
                    if gmObj._set_player_exp and ed.player then
                        ed.player._exp = gmObj._set_player_exp
                    end

                    -- 设置物品
                    if gmObj._set_items then
                        pcall(function()
                            for _, itemBits in ipairs(gmObj._set_items) do
                                local id = ed.bits(itemBits, 0, 10)
                                local amount = ed.bits(itemBits, 10, 11)
                                -- 直接添加到背包
                                if ed.player and ed.player.addEquip then
                                    ed.player:addEquip(id, amount)
                                end
                            end
                        end)
                    end

                    -- 刷UI
                    pcall(function()
                        if FireEvent then FireEvent("LoginSuc") end
                    end)
                    LegendLog("[STUB-NET] gm_cmd: done, LoginSuc fired")
                end
                handleGmCmd(obj)
            else
                -- 其他消息：尝试 local_server，失败则直接构造 down_msg 并 dispatch
                local handled = false
                local ls = rawget(_G, "local_server")
                if ls and ls.handle then
                    local ok_ls, result_ls = pcall(function() return ls.handle(msgType, obj) end)
                    if ok_ls and result_ls then
                        handled = true
                    else
                        if not ok_ls then
                            LegendLog("[STUB-NET] local_server error: " .. tostring(result_ls))
                        else
                            LegendLog("[STUB-NET] local_server returned false for: " .. tostring(msgType))
                        end
                    end
                else
                end

                if not handled then
                    -- 直接构造 down_msg 回复并通过 ed.dispatch 处理
                    pcall(function()
                        -- 直接构造 down_msg 消息对象（ed.downmsg.down_msg() 可能返回空表）
                        local msg = setmetatable({[".data"]={}}, {
                            __index = function(m, k) return rawget(m, ".data")[k] end,
                            __newindex = function(m, k, v) rawget(m, ".data")[k] = v end,
                        })
                        local data = rawget(msg, ".data")

                        -- 根据消息类型填充回复数据
                        if msgType == "sync_skill_stren" then
                            local slu = ed.player and ed.player._skill_level_up
                            LegendLog("[STUB] sync_skill_stren: slu=" .. tostring(slu) .. " chance=" .. tostring(slu and slu._skill_levelup_chance))
                            if slu then
                                data._sync_skill_stren_reply = {
                                    _skill_level_up = {
                                        _skill_levelup_chance = slu._skill_levelup_chance or 5,
                                        _skill_levelup_cd = slu._skill_levelup_cd or 0,
                                        _reset_times = slu._reset_times or 0,
                                        _last_reset_date = slu._last_reset_date or 0,
                                    }
                                }
                            end
                        elseif msgType == "buy_skill_stren_point" then
                            local slu = ed.player and ed.player._skill_level_up
                            if slu then
                                slu._skill_levelup_chance = (slu._skill_levelup_chance or 0) + 10
                                data._sync_skill_stren_reply = {
                                    _skill_level_up = {
                                        _skill_levelup_chance = slu._skill_levelup_chance,
                                        _skill_levelup_cd = slu._skill_levelup_cd or 0,
                                        _reset_times = (slu._reset_times or 0) + 1,
                                        _last_reset_date = slu._last_reset_date or 0,
                                    }
                                }
                            end
                        elseif msgType == "skill_levelup" then
                            -- 技能升级：只计算 _gs，不更新技能等级和技能点
                            -- dealSkillLevelup 会通过 strenHeroSkill 和 addSkillPoint 处理
                            local gs = 0
                            pcall(function()
                                local hid = obj._heroid or obj._tid
                                local hero = ed.player and ed.player.heroes[hid]
                                if hero then
                                    -- 解析 _order 计算升级数量（用于 gs 增量）
                                    local orders = obj._order or {}
                                    local totalUpgrades = 0
                                    for i, packed in ipairs(orders) do
                                        local slot = ed.bits(packed, 4, 11)
                                        local amount = ed.bits(packed, 0, 4)
                                        totalUpgrades = totalUpgrades + (amount or 1)
                                    end
                                    if totalUpgrades == 0 and obj._skill_index then
                                        totalUpgrades = 1
                                    end
                                    hero._gs = (hero._gs or 0) + totalUpgrades * 10
                                    gs = hero._gs
                                end
                            end)
                            data._skill_levelup_reply = {
                                _result = "success",
                                _gs = gs,
                            }
                        elseif msgType == "hero_upgrade" then
                            -- 英雄进阶：rank+1，清空装备，填新装备
                            local maxRank = (ed.parameter and ed.parameter.unit_max_rank) or 10
                            local heroData = nil
                            pcall(function()
                                local hid = obj._hero_id
                                local hero = ed.player and ed.player.heroes[hid]
                                if hero and (hero._rank or 1) < maxRank then
                                    -- 扣除旧 rank 的装备 GS 贡献（hero_equip 表的 GS 字段是满装备总贡献）
                                    local oldRank = hero._rank or 1
                                    local oldRankGs = 0
                                    pcall(function()
                                        oldRankGs = tonumber(ed.lookupDataTable("hero_equip", "GS", hero._tid, oldRank)) or 0
                                    end)

                                    hero._rank = oldRank + 1

                                    -- 清空旧装备，填空槽位
                                    hero._items = {}
                                    for i = 1, 6 do
                                        table.insert(hero._items, {_item_id = 0, _exp = 0, _index = i})
                                    end
                                    -- 填充新rank的初始装备（当前所有Init ID均为0，预留逻辑）
                                    pcall(function()
                                        for i = 1, 6 do
                                            local init = ed.lookupDataTable("hero_equip", "Init" .. i .. " ID", hid, hero._rank)
                                            if init and init ~= 0 then
                                                hero._items[i] = {_item_id = init, _exp = 0, _index = i}
                                            end
                                        end
                                    end)

                                    -- 新 GS = 旧GS - 旧rank装备贡献 + 新rank初始装备贡献
                                    local newInitGs = 0
                                    pcall(function()
                                        local newEquipLevel = tonumber(ed.lookupDataTable("hero_equip", "EquipLevel", hero._tid, hero._rank)) or 1
                                        local equipDataTable = ed.getDataTable("equip")
                                        for i = 1, 6 do
                                            local iid = hero._items[i]._item_id
                                            if iid and iid ~= 0 and equipDataTable and equipDataTable[iid] then
                                                newInitGs = newInitGs + (tonumber(equipDataTable[iid]["GS"]) or 0)
                                            end
                                        end
                                        newInitGs = newInitGs * newEquipLevel
                                    end)

                                    hero._gs = math.max(math.floor((hero._gs or 0) - oldRankGs + newInitGs), 0)
                                    LegendLog("[UPGRADE] hero=" .. tostring(hid) .. " rank=" .. tostring(oldRank) .. "->" .. tostring(hero._rank)
                                        .. " oldRankGs=" .. string.format("%.1f", oldRankGs)
                                        .. " newInitGs=" .. string.format("%.1f", newInitGs)
                                        .. " resultGs=" .. tostring(hero._gs))

                                    heroData = hero
                                end
                            end)
                            local heroReply = nil
                            if heroData then
                                heroReply = {
                                    _tid = heroData._tid,
                                    _rank = heroData._rank,
                                    _level = heroData._level or 1,
                                    _stars = heroData._stars or 1,
                                    _exp = heroData._exp or 0,
                                    _gs = heroData._gs or 0,
                                    _state = heroData._state or "idle",
                                    _skill_levels = heroData._skill_levels or {1,1,1,1},
                                    _items = heroData._items or {},
                                }
                            end
                            data._hero_upgrade_reply = {
                                _result = "success",
                                _hero = heroReply,
                                _items = {},
                            }
                        elseif msgType == "hero_evolve" then
                            -- 英雄进化：stars+1
                            local heroData = nil
                            pcall(function()
                                local hid = obj._heroid
                                local hero = ed.player and ed.player.heroes[hid]
                                if hero then
                                    hero._stars = (hero._stars or 1) + 1
                                    hero._gs = (hero._gs or 0) + 100
                                    -- 扣除金币
                                    local nd = ed.netdata and ed.netdata.evolve
                                    if nd and nd.cost then
                                        ed.player._money = math.max(0, (ed.player._money or 0) - nd.cost)
                                    end
                                    -- 扣除灵魂石
                                    if nd and nd.id and nd.amount then
                                        pcall(function() ed.player:consumeEquip(nd.id, nd.amount) end)
                                    end
                                    heroData = hero
                                end
                            end)
                            local heroReply = nil
                            if heroData then
                                heroReply = {
                                    _tid = heroData._tid,
                                    _rank = heroData._rank or 1,
                                    _level = heroData._level or 1,
                                    _stars = heroData._stars,
                                    _exp = heroData._exp or 0,
                                    _gs = heroData._gs or 0,
                                    _state = heroData._state or "idle",
                                    _skill_levels = heroData._skill_levels or {1,1,1,1},
                                    _items = heroData._items or {},
                                }
                            end
                            data._hero_evolve_reply = {
                                _result = "success",
                                _hero = heroReply,
                            }
                        elseif msgType == "enter_stage" then
                            local loots = {}
                            pcall(function()
                                local stageId = obj._stage_id
                                local stageTable = ed.getDataTable("Stage")
                                local battleTable = ed.getDataTable("Battle")
                                if stageTable and stageTable[stageId] then
                                    local stageInfo = stageTable[stageId]
                                    local waves = stageInfo["Waves"] or 3
                                    -- 找到最后一波的 Boss Position 作为掉落位置
                                    local targetWave = waves
                                    local bossPos = 1
                                    if battleTable and battleTable[stageId] then
                                        local lastWave = battleTable[stageId][targetWave]
                                        if lastWave then
                                            bossPos = lastWave["Boss Position"] or 1
                                            if bossPos == 0 then bossPos = 1 end
                                        end
                                    end
                                    -- 根据 Stage 表的 UI reward 字段生成掉落
                                    for i = 1, 7 do
                                        local lootId = stageInfo["UI reward" .. i]
                                        if lootId and lootId > 0 then
                                            -- 概率判定：使用 UI reward{i} Pro，默认 34%
                                            local lootPro = stageInfo["UI reward" .. i .. " Pro"] or 34
                                            local randVal = math.random(1, 100)
                                            if randVal <= lootPro then
                                                -- 检查是否有碎片ID（Frag ID）
                                                local realItem = lootId
                                                local equipDataTable = ed.getDataTable("equip")
                                                if equipDataTable and equipDataTable[lootId] then
                                                    local fragId = tonumber(equipDataTable[lootId]["Frag ID"]) or 0
                                                    if fragId > 0 then
                                                        realItem = fragId
                                                    end
                                                end
                                                -- 位打包: wave_idx(3) | monster_idx(3) | item_id(10)
                                                local packed = ed.makebits(3, targetWave - 1, 3, bossPos - 1, 10, realItem)
                                                table.insert(loots, packed)
                                            end
                                        end
                                    end
                                    -- 首通奖励: FD Bonus 1-5 每波
                                    -- (暂时跳过，需要追踪首通状态)
                                    LegendLog("[LOOT] stage=" .. tostring(stageId) .. " loot_count=" .. tostring(#loots))
                                end
                            end)
                            data._enter_stage_reply = {
                                _rseed = math.random(1, 2147483647),
                                _loots = loots,
                            }
                        elseif msgType == "exit_stage" then
                            data._exit_stage_reply = {
                                _result = "known",
                            }
                        elseif msgType == "tavern_draw" then
                            data._tavern_draw_reply = {
                                _item_ids = {},
                                _new_heroes = {},
                                _smash_idx = {},
                            }
                        elseif msgType == "shop_refresh" then
                            -- 尝试走 local_server 生成商品
                            local ls = rawget(_G, "local_server")
                            if ls and ls.handle then
                                local ok_ls, result_ls = pcall(function() return ls.handle(msgType, obj) end)
                                if ok_ls and result_ls then
                                    data._shop_refresh_reply = result_ls._shop_refresh_reply
                                end
                            end
                            if not data._shop_refresh_reply then
                                data._shop_refresh_reply = {
                                    _id = 1,
                                    _last_auto_refresh_time = os.time(),
                                    _expire_time = 0,
                                    _last_manual_refresh_time = os.time(),
                                    _today_times = 0,
                                    _current_goods = {},
                                }
                            end
                        elseif msgType == "open_shop" then
                            local ls = rawget(_G, "local_server")
                            if ls and ls.handle then
                                local ok_ls, result_ls = pcall(function() return ls.handle(msgType, obj) end)
                                if ok_ls and result_ls then
                                    data._open_shop_reply = result_ls._open_shop_reply
                                end
                            end
                            if not data._open_shop_reply then
                                data._open_shop_reply = {
                                    _result = "success",
                                    _shop = {
                                        _id = 1,
                                        _last_auto_refresh_time = os.time(),
                                        _expire_time = 0,
                                        _last_manual_refresh_time = os.time(),
                                        _today_times = 0,
                                        _current_goods = {},
                                    },
                                }
                            end
                        elseif msgType == "shop_consume" then
                            local ls = rawget(_G, "local_server")
                            if ls and ls.handle then
                                local ok_ls, result_ls = pcall(function() return ls.handle(msgType, obj) end)
                                if ok_ls and result_ls then
                                    data._shop_consume_reply = result_ls._shop_consume_reply
                                end
                            end
                            if not data._shop_consume_reply then
                                data._shop_consume_reply = { _result = "success" }
                            end
                        elseif msgType == "wear_equip" then
                            -- 计算穿戴后的 GS：直接用 equip 表的 GS 字段 × EquipLevel
                            local newGs = 0
                            pcall(function()
                                local heroId = obj._hero_id
                                local slot = obj._item_pos
                                if heroId and ed.player.heroes[heroId] then
                                    local hero = ed.player.heroes[heroId]
                                    local curGs = hero._gs or 0
                                    local equipDataTable = ed.getDataTable("equip")
                                    local heroEquipTable = ed.getDataTable("hero_equip")

                                    -- 获取 hero_equip 的 EquipLevel 倍率
                                    local equipLevel = 1
                                    local newItemId = nil
                                    if heroEquipTable and heroEquipTable[hero._tid]
                                        and heroEquipTable[hero._tid][hero._rank] then
                                        local rankEquip = heroEquipTable[hero._tid][hero._rank]
                                        equipLevel = rankEquip.EquipLevel or 1
                                        newItemId = rankEquip[string.format("Equip%d ID", slot)]
                                    end

                                    local oldItemId = nil
                                    if hero._items and hero._items[slot] then
                                        oldItemId = hero._items[slot]._item_id
                                    end

                                    -- 直接用 equip 表的 GS 字段（策划配置的综合 GS 值）
                                    local oldSlotGs = 0
                                    if oldItemId and equipDataTable and equipDataTable[oldItemId] then
                                        oldSlotGs = tonumber(equipDataTable[oldItemId]["GS"]) or 0
                                    end
                                    local newSlotGs = 0
                                    if newItemId and equipDataTable and equipDataTable[newItemId] then
                                        newSlotGs = tonumber(equipDataTable[newItemId]["GS"]) or 0
                                    end

                                    local delta = (newSlotGs - oldSlotGs) * equipLevel

                                    LegendLog("[WEAR] hero=" .. tostring(heroId) .. " slot=" .. tostring(slot)
                                        .. " old=" .. tostring(oldItemId) .. " new=" .. tostring(newItemId)
                                        .. " equipLv=" .. tostring(equipLevel) .. " delta=" .. string.format("%.1f", delta))

                                    newGs = math.max(math.floor(curGs + delta), 0)
                                    LegendLog("[WEAR] curGs=" .. tostring(curGs) .. " -> newGs=" .. tostring(newGs))
                                end
                            end)
                            data._wear_equip_reply = { _result = "success", _gs = newGs }
                        elseif msgType == "sell_item" then
                            data._sell_item_reply = { _result = "success" }
                        elseif msgType == "equip_synthesis" then
                            data._equip_synthesis_reply = { _result = "success" }
                        elseif msgType == "fragment_compose" then
                            data._fragment_compose_reply = { _result = "success" }
                        elseif msgType == "hero_equip_upgrade" then
                            data._hero_equip_upgrade_reply = { _result = "success" }
                        elseif msgType == "consume_item" then
                            local hid = msg._hero_id
                            local itemBits = msg._item_id
                            local hero = hid and ed.player and ed.player.heroes[hid]
                            if hero then
                                local expGain = 60
                                local amount = 1
                                if itemBits then
                                    local amt, id = ed.splitbits(itemBits, 11, 10)
                                    amount = amt or 1
                                    if id then
                                        local eq = ed.getDataTable("equip")
                                        if eq and eq[id] then
                                            expGain = eq[id]["Exp"] or 60
                                        end
                                    end
                                end
                                hero:addExp(expGain * amount)
                                ed.saveGame()
                                data._consume_item_reply = {
                                    _hero = {
                                        _tid = hero._tid,
                                        _level = hero._level,
                                        _exp = hero._exp,
                                        _rank = hero._rank or 1,
                                        _stars = hero._stars or 1,
                                        _gs = hero._gs or 0,
                                        _state = hero._state or "idle",
                                    }
                                }
                            else
                                data._consume_item_reply = {}
                            end
                        elseif msgType == "tutorial" then
                            data._tutorial_reply = { _result = "success" }
                        elseif msgType == "set_name" then
                            data._set_name_reply = { _result = "success" }
                        elseif msgType == "set_avatar" then
                            data._set_avatar_reply = { _result = "success" }
                        elseif msgType == "trigger_task" then
                            data._trigger_task_reply = { _result = { "success" } }
                        elseif msgType == "trigger_job" then
                            -- handled by local_server.lua
                        elseif msgType == "job_rewards" then
                            -- handled by local_server.lua
                        elseif msgType == "require_rewards" then
                            -- handled by local_server.lua
                        elseif msgType == "reset_elite" then
                            data._reset_elite_reply = { _result = "success" }
                        elseif msgType == "sweep_stage" then
                            data._sweep_stage_reply = {
                                _loot = { { _exp = 0, _money = 0, _items = {} } },
                                _items = {},
                            }
                        elseif msgType == "midas" then
                            data._midas_reply = { _acquire = {} }
                        elseif msgType == "query_data" then
                            data._query_data_reply = { heroes = {}, recharge_limit = {}, _month_card = {} }
                        elseif msgType == "sync_vitality" then
                            -- 使用玩家实际体力数据（含自然恢复计算）
                            local vit = ed.player and ed.player._vitality
                            if vit then
                                -- 自然恢复：每6分钟恢复1点
                                local now = os.time()
                                local elapsed = now - (vit._lastchange or 0)
                                local recovered = math.floor(elapsed / 360)
                                if recovered > 0 then
                                    vit._current = math.min((vit._current or 0) + recovered, 120)
                                    vit._lastchange = now
                                end
                            else
                                vit = { _current = 120, _lastchange = 0, _todaybuy = 0, _lastbuy = 0 }
                            end
                            data._sync_vitality_reply = { _vitality = vit }
                        elseif msgType == "buy_vitality" then
                            -- 购买体力：+120，扣除钻石
                            local vit = ed.player and ed.player._vitality
                            if vit then
                                vit._current = (vit._current or 0) + 120
                                vit._todaybuy = (vit._todaybuy or 0) + 1
                                vit._lastbuy = os.time()
                                pcall(function() ed.player:addrmb(-50) end)
                            else
                                vit = { _current = 240, _lastchange = 0, _todaybuy = 1, _lastbuy = os.time() }
                            end
                            data._sync_vitality_reply = { _vitality = vit }
                        elseif msgType == "ask_daily_login" then
                            -- handled by local_server.lua
                        elseif msgType == "sdk_login" then
                            data._sdk_login_reply = { _result = "success", _uin = "1" }
                        elseif msgType == "system_setting" then
                            data._system_setting_reply = {}
                        elseif msgType == "ask_magicsoul" then
                            local ids = {}
                            for i = 1, 6 do ids[i] = math.random(1, 30) end
                            data._ask_magicsoul_reply = ids
                        elseif msgType == "get_svr_time" then
                            data._svr_time = os.time()
                        elseif msgType == "get_maillist" then
                            -- handled by local_server.lua
                        elseif msgType == "change_server" then
                            data._change_server_reply = { _result = "success" }
                        elseif msgType == "cdkey_gift" then
                            data._cdkey_gift_reply = { _result = "success" }
                        elseif msgType == "charge" then
                            data._charge_reply = { _result = "success" }
                        elseif msgType == "suspend_report" then
                            -- 无回复
                            return
                        end

                        -- 直接处理回复（ed.dispatch 不可用，network.lua 未加载）
                        -- 实现 network.lua dispatch 函数的核心逻辑
                        LegendLog("[STUB] handling reply for: " .. tostring(msgType))
                        pcall(function()
                            -- sync_skill_stren / buy_skill_stren_point 回复
                            if data._sync_skill_stren_reply then
                                local reply = data._sync_skill_stren_reply
                                ed.player._skill_level_up = reply._skill_level_up
                                local handler, rdata = ed.getNetReply("sync_skill_stren_chance")
                                LegendLog("[STUB] _sync_skill_stren_reply: handler=" .. tostring(handler ~= nil) .. " rdata=" .. tostring(rdata ~= nil) .. " cost=" .. tostring(rdata and rdata.cost))
                                if rdata and rdata.cost then pcall(function() ed.player:addrmb(-rdata.cost) end) end
                                if handler then
                                    handler()
                                else
                                    -- handler 为 nil 时（buy_skill_stren_point 场景），手动刷新技能面板
                                    pcall(function()
                                        local sw = ed.getPopWindow and ed.getPopWindow("herodetailskill")
                                        LegendLog("[STUB] manual UI refresh: sw=" .. tostring(sw ~= nil))
                                        if sw and sw.createInformationBar then
                                            sw:createInformationBar()
                                            LegendLog("[STUB] createInformationBar called OK")
                                        end
                                    end)
                                end
                            end
                            -- skill_levelup 回复
                            if data._skill_levelup_reply then
                                if ed.ui and ed.ui.herodetail and ed.ui.herodetail.dealSkillLevelup then
                                    ed.ui.herodetail.dealSkillLevelup(data._skill_levelup_reply)
                                end
                            end
                            -- hero_upgrade 回复
                            if data._hero_upgrade_reply then
                                local reply = data._hero_upgrade_reply
                                local result = reply._result == "success"
                                local hero = reply._hero
                                local items = reply._items
                                local props = {}
                                for i = 1, #(items or {}) do
                                    local item = items[i]
                                    local id = ed.bits(item, 0, 10)
                                    local amount = ed.bits(item, 10, 11)
                                    pcall(function() ed.player:addEquip(id, amount) end)
                                    props[i] = {id = id, amount = amount}
                                end
                                if result and hero then pcall(function() ed.player:resetHero(hero) end) end
                                if ed.netreply.heroUpgradeReply then
                                    ed.netreply.heroUpgradeReply(result, props)
                                    ed.netreply.heroUpgradeReply = nil
                                    if ed.saveGame then ed.saveGame() end
                                end
                            end
                            -- hero_evolve 回复
                            if data._hero_evolve_reply then
                                local reply = data._hero_evolve_reply
                                local result = reply._result == "success"
                                local hero = reply._hero
                                local ndata = ed.netdata and ed.netdata.evolve
                                if ndata and result then
                                    pcall(function()
                                        ed.player:addMoney(-(ndata.cost or 0))
                                        ed.player:consumeEquip(ndata.id, ndata.amount)
                                        if ed.player.heroes[ndata.hid] then
                                            ed.player.heroes[ndata.hid]:evolve()
                                        else
                                            addHeroWithLevel(ndata.hid)
                                        end
                                        ed.player:resetHero(hero)
                                    end)
                                    ed.netdata.evolve = nil
                                end
                                if ed.netreply.evolve then
                                    ed.netreply.evolve(result)
                                    ed.netreply.evolve = nil
                                    if ed.saveGame then ed.saveGame() end
                                end
                            end
                            -- wear_equip 回复
                            if data._wear_equip_reply then
                                local reply = data._wear_equip_reply
                                local result = reply._result == "success"
                                local gs = reply._gs
                                if ed.netdata.putonReply then
                                    local ok_equip, err_equip = pcall(function()
                                        local rdata = ed.netdata.putonReply
                                        ed.player:consumeEquip(rdata.eid, 1)
                                        ed.player.heroes[rdata.hid]:equip(rdata.sid)
                                        local hero = ed.player.heroes[rdata.hid]
                                        hero:resetgs(gs)
                                    end)
                                    if not ok_equip then LegendLog("[wear_equip] ERROR: " .. tostring(err_equip)) end
                                    ed.netdata.putonReply = nil
                                end
                                if ed.netreply.putonReply then
                                    ed.netreply.putonReply(result)
                                    ed.netreply.putonReply = nil
                                    if ed.saveGame then ed.saveGame() end
                                end
                            end
                            -- enter_stage 回复
                            if data._enter_stage_reply then
                                LegendLog("[REPLY] enter_stage reply received, callback=" .. tostring(ed.netreply.enterStage ~= nil))
                                if ed.netreply.enterStage then
                                    ed.netreply.enterStage()
                                    ed.netreply.enterStage = nil
                                end
                                pcall(function() ed.srand(data._enter_stage_reply._rseed) end)
                                if ed.player then ed.player.loots = data._enter_stage_reply._loots or {} end
                            end
                            -- exit_stage 回复（战斗结算后保存）
                            if data._exit_stage_reply then
                                local result = data._exit_stage_reply._result == "known"
                                if ed.netreply.exitStageReply then
                                    ed.netreply.exitStageReply(result)
                                    ed.netreply.exitStageReply = nil
                                    -- 战斗结束后自动保存
                                    if ed.saveGame then ed.saveGame() end
                                else
                                end
                                ed.netdata.exitStageReply = nil
                            end

                            -- shop_refresh / shop_consume 回复
                            if data._shop_refresh_reply then
                                pcall(function() ed.ui.market.dealRefresh(data._shop_refresh_reply) end)
                            end
                            if data._shop_consume_reply then
                                pcall(function() ed.ui.market.dealConsume(data._shop_consume_reply) end)
                            end
                            -- sell_item 回复
                            if data._sell_item_reply then
                                local result = data._sell_item_reply._result
                                local handler, rdata = ed.getNetReply("sell_item")
                                if result and rdata then
                                    pcall(function()
                                        ed.player._money = ed.player._money + rdata.income
                                        for k, v in pairs(rdata.items) do
                                            ed.player:consumeEquip(v.id, v.amount)
                                        end
                                    end)
                                end
                                if handler and rdata then handler(result, rdata.amount) end
                            end
                            -- equip_synthesis 回复
                            if data._equip_synthesis_reply then
                                local result = data._equip_synthesis_reply._result == "success"
                                local rdata = ed.netdata.equipCraft
                                if result and rdata then
                                    pcall(function()
                                        ed.player:addMoney(-rdata.expense)
                                        local na = rdata.consume
                                        for k, v in pairs(rdata.node) do
                                            ed.player:consumeEquip(v, na[k] or 1)
                                        end
                                        ed.player:addEquip(rdata.id)
                                    end)
                                end
                                if ed.netreply.craftReply then
                                    ed.netreply.craftReply(result)
                                    ed.netreply.craftReply = nil
                                end
                            end
                            -- fragment_compose 回复
                            if data._fragment_compose_reply then
                                local result = data._fragment_compose_reply._result == "success"
                                local info = ed.netdata.fragmentCompose
                                if result and info then
                                    pcall(function()
                                        ed.player:addMoney(-info.cost)
                                        ed.player:consumeEquip(info.id, info.fragmentAmount)
                                        if info.makeId > 100 then
                                            ed.player:addEquip(info.makeId)
                                        else
                                            addHeroWithLevel(info.makeId)
                                        end
                                    end)
                                end
                                if ed.netreply.composeFragmentReply then
                                    ed.netreply.composeFragmentReply(result)
                                    ed.netreply.composeFragmentReply = nil
                                end
                            end
                            -- hero_equip_upgrade 回复
                            if data._hero_equip_upgrade_reply then
                                local result = data._hero_equip_upgrade_reply._result == "success"
                                local hero = data._hero_equip_upgrade_reply._hero
                                if result and hero then pcall(function() ed.player:resetHero(hero) end) end
                                local handler = ed.netreply.equipUpgrade
                                if handler then handler(result); ed.netreply.equipUpgrade = nil end
                            end
                            -- consume_item 回复
                            if data._consume_item_reply then
                                local hero = data._consume_item_reply._hero
                                local handler, rdata = ed.getNetReply("eat_exp")
                                if rdata then
                                    pcall(function()
                                        ed.player:consumeEquip(rdata.id, rdata.amount)
                                        if hero then ed.player:resetHero(hero) end
                                    end)
                                end
                                if handler then handler() end
                                if ed.saveGame then pcall(function() ed.saveGame() end) end
                            end
                            -- sync_vitality / buy_vitality 回复
                            if data._sync_vitality_reply then
                                local reply = data._sync_vitality_reply
                                ed.player._vitality = reply._vitality
                                local rdata = ed.netdata.buyVitality
                                if rdata and rdata.isBuy then
                                    ed.player._rmb = ed.player._rmb - rdata.cost
                                    if ed.netreply.buyVitalityReply then
                                        ed.netreply.buyVitalityReply()
                                        ed.netreply.buyVitalityReply = nil
                                    end
                                    ed.netdata.buyVitality = nil
                                end
                            end
                            -- set_name 回复
                            if data._set_name_reply then
                                local result = data._set_name_reply._result
                                local rdata = ed.netdata.setname
                                if result == "success" and rdata then
                                    pcall(function()
                                        ed.player:setName(rdata.name or "")
                                        ed.player:addrmb(-(rdata.cost or 0))
                                        ed.player:refreshSetNameTime()
                                    end)
                                    ed.netdata.setname = nil
                                end
                                if ed.netreply.setname then
                                    ed.netreply.setname(result)
                                    ed.netreply.setname = nil
                                end
                            end
                            -- set_avatar 回复
                            if data._set_avatar_reply then
                                local result = data._set_avatar_reply._result == "success"
                                local rdata = ed.netdata.setAvatar
                                if rdata and result then
                                    pcall(function() ed.player:setAvatar(rdata.id) end)
                                end
                                if ed.netreply.setAvatar then ed.netreply.setAvatar(result) end
                            end
                            -- tutorial 回复
                            if data._tutorial_reply then
                                ed.netdata.tutorial = nil
                                if ed.netreply.tutorial then
                                    ed.netreply.tutorial()
                                    ed.netreply.tutorial = nil
                                end
                            end
                            -- trigger_task / trigger_job / job_rewards / require_rewards 回复
                            if data._trigger_task_reply then
                                if ed.netreply.triggerTask then
                                    ed.netreply.triggerTask(data._trigger_task_reply._result)
                                    ed.netreply.triggerTask = nil
                                end
                            end
                            if data._require_rewards_reply then
                                local result = data._require_rewards_reply._result == "success"
                                if ed.netreply.requireRewards then
                                    ed.netreply.requireRewards(result, ed.netdata.requireRewards)
                                    ed.netreply.requireRewards = nil
                                    ed.netdata.requireRewards = nil
                                end
                            end
                            if data._job_rewards_reply then
                                local result = data._job_rewards_reply._result == "success"
                                if ed.netreply.jobRewards then
                                    ed.netreply.jobRewards(result, ed.netdata.jobRewards)
                                    ed.netreply.jobRewards = nil
                                    ed.netdata.jobRewards = nil
                                end
                            end
                            -- reset_elite 回复
                            if data._reset_elite_reply then
                                local result = data._reset_elite_reply._result == "success"
                                if result then pcall(function() ed.player:refreshEliteResetTime() end) end
                                if ed.netreply.resetElite then
                                    ed.netreply.resetElite(result)
                                    ed.netreply.resetElite = nil
                                    ed.netdata.resetElite = nil
                                end
                            end
                            -- sweep_stage 回复
                            if data._sweep_stage_reply then
                                local reply = data._sweep_stage_reply
                                pcall(function()
                                    local function addSweepLoot(info)
                                        for k, v in pairs(info._loot or {}) do
                                            ed.player:addExp(v._exp, "sweep")
                                            ed.player:addMoney(v._money)
                                            for ck, cv in pairs(v._items or {}) do
                                                ed.player:addEquip(ed.bits(cv, 0, 10), ed.bits(cv, 10, 11))
                                            end
                                        end
                                    end
                                    addSweepLoot(reply)
                                end)
                                if ed.netreply.sweep then
                                    ed.netreply.sweep(reply)
                                    ed.netreply.sweep = nil
                                end
                                ed.netdata.sweep = nil
                            end
                            -- open_shop 回复
                            if data._open_shop_reply then
                                local reply = data._open_shop_reply
                                local result = reply._result == "success"
                                if reply._shop then pcall(function() ed.player:refreshShopData(reply._shop) end) end
                                local rdata = ed.netdata.openShop
                                if rdata then pcall(function() ed.player:addrmb(-rdata.cost) end) end
                                if ed.netreply.openShop then
                                    ed.netreply.openShop(result)
                                    ed.netreply.openShop = nil
                                end
                            end
                            -- ask_magicsoul 回复
                            if data._ask_magicsoul_reply then
                                local handler = ed.netreply.askMagicsoul
                                if handler then handler(data._ask_magicsoul_reply) end
                            end
                            -- get_svr_time 回复
                            if data._svr_time then
                                pcall(function() ed.player:initNativeTimeDiff(data._svr_time) end)
                                local handler = ed.netreply.syncTime
                                if handler then handler(); ed.netreply.syncTime = nil end
                            end
                            -- ask_daily_login 回复
                            if data._ask_daily_login_reply then
                                local result = data._ask_daily_login_reply._result == "success"
                                local rdata = ed.netdata.dailylogin
                                if result and rdata then
                                    pcall(function() ed.player:recievedDailyLoginReward(rdata.type) end)
                                end
                                if ed.netreply.dailylogin then
                                    ed.netreply.dailylogin(result)
                                    ed.netreply.dailylogin = nil
                                end
                            end
                            -- system_setting 回复
                            if data._system_setting_reply then
                                FireEvent("SystemSettingReply", data._system_setting_reply)
                            end
                            -- cdkey_gift / change_server / sdk_login / charge / get_maillist 回复
                            if data._cdkey_gift_reply then
                                local handler = ed.netreply.cdkeyGift
                                if handler then handler(data._cdkey_gift_reply._result, data._cdkey_gift_reply._pack) end
                            end
                            if data._change_server_reply then
                                pcall(function()
                                    if data._change_server_reply._result == "change_ok" then
                                        LegendRestartApplication()
                                    end
                                end)
                            end
                            if data._sdk_login_reply then
                                FireEvent("SDKLoginRsp", data._sdk_login_reply._result)
                            end
                            if data._charge_reply then
                                FireEvent("chargeRsp", data._charge_reply)
                            end
                            if data._mail_list then
                                pcall(function() ed.player:refreshMailData(data._mail_list._sys_mail_list) end)
                                local handler = ed.netreply.getMail
                                if handler then handler() end
                            end
                            -- query_data 回复
                            if data._query_data_reply then
                                local reply = data._query_data_reply
                                for i = 1, #(reply.heroes or {}) do
                                    pcall(function() ed.player:resetHero(reply.heroes[i]) end)
                                end
                            end
                        end)
                        LegendLog("[STUB] reply handled for: " .. tostring(msgType))
                    end)
                end
            end
        end
        local nw = { connect = function() end, send = stubSend, close = function() end, isConnected = function() return false end }
        package.loaded["network"] = nw; rawset(_G, "network", nw)
        ed.send = stubSend
        okCount = okCount + 1
        -- 加载 local_server 模块（供 stubSend 的 else 分支调用）
        getLocalServer()
        -- network.lua 会设置这些表，stub 也需要初始化
        if not ed.netreply then ed.netreply = {} end
        if not ed.netdata then ed.netdata = {} end
        if not ed.registerNetReply or ed.registerNetReply() == nil then
            ed.registerNetReply = function(key, handler, data)
                ed.netreply[key] = handler
                ed.netdata[key] = data
            end
        end
        if not ed.getNetReply or (function() local ok,_ = pcall(ed.getNetReply, "test"); return not ok end)() then
            ed.getNetReply = function(key)
                if not key then return nil, nil end
                local handler = ed.netreply[key]
                local data = ed.netdata[key]
                ed.netreply[key] = nil
                ed.netdata[key] = nil
                return handler, data
            end
        end
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
    if not ed.delaySend then ed.delaySend = function() end end
    if not ed.send then
        ed.send = function(msg, msgType)
            print("[STUB-SEND] " .. tostring(msgType))
            if msgType == "login" then
                -- 使用 scheduler 延迟执行（与第一处 stubSend 一致）
                local function doLoginReply()
                    local ok_s, err_s = pcall(function()
                        if ed.player and ed.player.setup then
                            -- 尝试从存档加载
                            local savedData = ed.loadSaveData and ed.loadSaveData()
                            if savedData and savedData._userid then
                                print("[STUB-NET] Loading saved game data (ensureStubs)")
                                ed.player:setup(savedData)
                            else
                                local mockUser = createDefaultUserData()
                                ed.player:setup(mockUser)
                            end
                            print("[STUB-NET] Player setup OK (ensureStubs)")
                        end
                    end)
                    if not ok_s then print("[STUB-NET] player setup err: " .. tostring(err_s)) end
                    if ed.setUserid then ed.setUserid(1) end
                    if ed.saveGame then ed.saveGame() end
                    if ed.startAutoSave then ed.startAutoSave() end
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
            elseif msgType == "tavern_draw" then
                LegendLog("[ENSURE-SEND] tavern_draw: handling directly")
                local drawType = obj._draw_type or 0
                local drawCount = drawType == 1 and 10 or 1
                local loot = {}
                for i = 1, drawCount do
                    local equipId = math.random(100, 120)
                    table.insert(loot, ed.makebits(11, 1, 10, equipId))
                end
                if math.random(1, 10) <= 3 then
                    table.insert(loot, ed.makebits(11, math.random(1, 3), 10, math.random(1, 5)))
                end
                -- 扣费
                pcall(function()
                    local nd = ed.netdata
                    if nd and nd.tavern and nd.tavern.type ~= "stone" then
                        local td = nd.tavern
                        if not td.isFree then
                            local pay = td.cost and td.cost.pay
                            local number = td.cost and td.cost.number or 0
                            if pay == "Gold" then
                                ed.player._money = (ed.player._money or 0) - number
                            elseif pay == "Diamond" then
                                ed.player._rmb = (ed.player._rmb or 0) - number
                            end
                        end
                        nd.tavern = nil
                    end
                end)
                -- 调用回调
                local cb = ed.netreply and ed.netreply.tavern
                if cb then
                    local ok, err = pcall(cb, loot)
                    if not ok then LegendLog("[ENSURE-SEND] tavern cb error: " .. tostring(err)) end
                    ed.netreply.tavern = nil
                else
                    LegendLog("[ENSURE-SEND] WARNING: no tavern callback!")
                end
            elseif msgType == "ask_magicsoul" then
                LegendLog("[ENSURE-SEND] ask_magicsoul: handling directly")
                local ids = {}
                for i = 1, 6 do table.insert(ids, math.random(1, 30)) end
                ids[1] = math.random(1, 15)
                local cb2 = ed.netreply and ed.netreply.askMagicsoul
                if cb2 then pcall(cb2, ids); ed.netreply.askMagicsoul = nil end
            elseif msgType == "consume_item" then
                local hid = msg._hero_id
                local itemBits = msg._item_id
                local hero = hid and ed.player and ed.player.heroes[hid]
                if hero then
                    local expGain = 60
                    local amount = 1
                    if itemBits then
                        local amt, id = ed.splitbits(itemBits, 11, 10)
                        amount = amt or 1
                        if id then
                            local eq = ed.getDataTable("equip")
                            if eq and eq[id] then
                                expGain = eq[id]["Exp"] or 60
                            end
                        end
                    end
                    hero:addExp(expGain * amount)
                    ed.saveGame()
                    pcall(function()
                        local rdata = ed.netdata and ed.netdata.eat_exp
                        if rdata then
                            ed.player:consumeEquip(rdata.id, rdata.amount)
                        end
                    end)
                    local cb3 = ed.netreply and ed.netreply.eat_exp
                    if cb3 then pcall(cb3); ed.netreply.eat_exp = nil end
                end
            end
        end
    end
    if not ed.proc_net then ed.proc_net = function() end end
    if not ed.delaySend then ed.delaySend = function() end end
    if not ed.netreply then ed.netreply = {} end
    if not ed.netdata then ed.netdata = {} end
    -- 包装 ed.upmsg：保留 proto 已有的消息类型，缺失的自动创建空工厂
    -- 这样 tavern_draw、ask_magicsoul 等即使 proto 加载不完整也能工作
    do
        local _origUpmsg = ed.upmsg
        if not _origUpmsg then _origUpmsg = {} end
        ed.upmsg = setmetatable({}, {
            __index = function(t, key)
                local val = _origUpmsg[key]
                if val ~= nil then
                    t[key] = val
                    return val
                end
                -- proto 没有此消息类型，自动创建空工厂
                print("[ENSURE] ed.upmsg." .. tostring(key) .. " auto-stub created")
                t[key] = function() return {} end
                return t[key]
            end
        })
    end
    -- 包装 ed.downmsg：同样保留 proto 已有类型，缺失的自动创建
    do
        local _origDownmsg = ed.downmsg
        if not _origDownmsg then _origDownmsg = {} end
        ed.downmsg = setmetatable({}, {
            __index = function(t, key)
                local val = _origDownmsg[key]
                if val ~= nil then
                    t[key] = val
                    return val
                end
                print("[ENSURE] ed.downmsg." .. tostring(key) .. " auto-stub created")
                t[key] = function() return setmetatable({[".data"]={}}, {
                    __index = function(msg, name) return rawget(msg, ".data")[name] end,
                    __newindex = function(msg, name, value) rawget(msg, ".data")[name] = value end,
                }) end
                return t[key]
            end
        })
    end
    if not ed.getMillionTime then ed.getMillionTime = function() return os.time() * 1000 end end
    if not ed.tick_interval then ed.tick_interval = 0.1 end
    -- 重新绑定存档系统（tools.lua 的 ed={} 会清除之前的 saveGame/loadSaveData）
    ed.saveGame = saveGame
    ed.loadSaveData = loadSaveData
    ed.startAutoSave = startAutoSave
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
    -- "battle/battle_scene" 已移至延迟加载，它链式加载74个英雄AI脚本
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
-- 加载 ed.needLoadFiles 中列出的游戏模块
-- 只加载关键模块，其余延迟加载避免阻塞
-----------------------------------------------------------------
do
    local needFiles = ed.needLoadFiles
    if needFiles and type(needFiles) == "table" then
        -- 关键模块（教程、UI等必须先加载的）
        local criticalModules = {
            "tutorial/tutorialres",
            "tutorial/tutorialmaker",
            "tutorial/tutorial",
            "tutorial/5v5",
        }
        local criticalSet = {}
        for _, f in ipairs(criticalModules) do criticalSet[f] = true end

        local nfOk, nfFail = 0, 0
        -- 第一轮：只加载关键模块
        for _, f in ipairs(needFiles) do
            if type(f) == "string" and #f > 0 and criticalSet[f] then
                local ok3, err3 = pcall(require, f)
                if ok3 then
                    nfOk = nfOk + 1
                else
                    nfFail = nfFail + 1
                    print("[NEED-FILE-FAIL] " .. f .. ": " .. tostring(err3):match("[^\n]+"))
                end
            end
        end
        print("[NEED-FILES-CRITICAL] Loaded: " .. nfOk .. "/" .. (nfOk + nfFail))

        -- 注册延迟加载：其他模块在首次 require 时自动加载
        -- (Lua 的 require 机制已支持这一点，无需预加载)
        print("[NEED-FILES] " .. #needFiles .. " total, " .. nfOk .. " critical loaded, rest lazy-loaded")
    else
        print("[NEED-FILES] ed.needLoadFiles not found or empty")
    end
end

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
