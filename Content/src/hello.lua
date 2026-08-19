---

pcall(function()
	if EDFLAGWIN32 then
		logfile = io.open("log_client.log", "w")
	end
	require("LocalString")
	require("tools")
	require("edebug")
	require("maingameproject")
end)

--EDFLAGWIN32=false
local debug_mode=false
if LegendPlatformFLAG==3 then
	--EDFLAGWIN32=true
	debug_mode =true
end
ed.debug_mode = debug_mode
EDLanguage = EDLanguage or "chinese"
local initFont = function()
	font = "arial_unicode_ms.ttf"
	fontBold = "arial_unicode_ms.ttf"
	selfFont = "arial_unicode_ms.ttf"
	local language = CCUserDefault:sharedUserDefault():getStringForKey("client_language")
	if language == "en-US" then
		font = "arial_unicode_ms.ttf"
		fontBold = "arial_unicode_ms.ttf"
		if LegendPlatformFLAG==ed.PlatformCode.CC_PLATFORM_ANDROID or EDFLAGWP8 then
			font = "arial_unicode_ms.ttf"
			fontBold = "arial_unicode_ms.ttf"
		end
	elseif language == "zh-CN" then
		font = "Arial"
		fontBold = "Arial"
		if LegendPlatformFLAG==ed.PlatformCode.CC_PLATFORM_ANDROID or EDFLAGWP8 then
			font = "Arial"
			fontBold = "Arial"
		end
	elseif language == "ko-KR" then
		font = "arial_unicode_ms.ttf"
		fontBold = "arial_unicode_ms.ttf"
		if LegendPlatformFLAG==ed.PlatformCode.CC_PLATFORM_ANDROID or EDFLAGWP8 then
			font = "arial_unicode_ms.ttf"
			fontBold = "arial_unicode_ms.ttf"
		end
		selfFont = "arial_unicode_ms.ttf"
	elseif language == "de-DE" then
		font = "arial_unicode_ms.ttf"
		fontBold = "arial_unicode_ms.ttf"
		if LegendPlatformFLAG==ed.PlatformCode.CC_PLATFORM_ANDROID or EDFLAGWP8 then
			font = "arial_unicode_ms.ttf"
			fontBold = "arial_unicode_ms.ttf"
		end
		selfFont = "arial_unicode_ms.ttf"
	end
	ed.font = font
	ed.fontBold = fontBold
	ed.selfFont = selfFont
end
function loadAllFiles()
	local _ok_n, _fail_n = 0, 0
	for i, v in ipairs(ed.needLoadFiles) do
		local ok, err = pcall(require, v)
		if ok then
			_ok_n = _ok_n + 1
		else
			_fail_n = _fail_n + 1
			if _fail_n <= 20 then
				print("[loadAllFiles] FAIL: " .. v .. " - " .. tostring(err):sub(1, 200))
			end
		end
	end
	print("[loadAllFiles] " .. _ok_n .. " OK, " .. _fail_n .. " FAIL / " .. #ed.needLoadFiles .. " total")
	end

	-- ====== 后台分帧加载器 ======
	local bg_queue = {}
	local bg_index = 1
	local bg_per_frame = 5
	local bg_entry_id = nil

	local function buildBackgroundQueue()
		bg_queue = {}
		bg_index = 1
		-- 收集未加载的 needLoadFiles 模块
		if ed.needLoadFiles then
			for _, v in ipairs(ed.needLoadFiles) do
				if not package.loaded[v] then
					table.insert(bg_queue, v)
				end
			end
		end
		-- 收集延迟数据表
		if ed.deferredDataTables then
			for _, v in ipairs(ed.deferredDataTables) do
				table.insert(bg_queue, "__datatable__" .. v)
			end
		end
		print("[BG-LOAD] Queue built: " .. #bg_queue .. " items")
	end

	local function backgroundLoadStep()
		if bg_index > #bg_queue then
			if bg_entry_id then
				local sched = CCDirector:sharedDirector():getScheduler()
				if sched then sched:unscheduleScriptEntry(bg_entry_id) end
				bg_entry_id = nil
			end
			ed.bg_load_complete = true
			print("[BG-LOAD] Complete")
			return
		end
		local loaded = 0
		while bg_index <= #bg_queue and loaded < bg_per_frame do
			local item = bg_queue[bg_index]
			if item:sub(1, 13) == "__datatable__" then
					local tname = item:sub(14)
					local ok, err = pcall(function() ed.getDataTable(tname) end)
					if not ok then print("[BG-LOAD-FAIL] datatable " .. tname .. ": " .. tostring(err):match("[^\n]+")) end
				else
					local ok, err = pcall(require, item)
					if not ok then print("[BG-LOAD-FAIL] module " .. item .. ": " .. tostring(err):match("[^\n]+")) end
				end
			bg_index = bg_index + 1
			loaded = loaded + 1
		end
	end

	local function startBackgroundLoad()
		if bg_entry_id then return end
		buildBackgroundQueue()
		if #bg_queue == 0 then
			ed.bg_load_complete = true
			return
		end
		local sched = CCDirector:sharedDirector():getScheduler()
		if sched then
			bg_entry_id = sched:scheduleScriptFunc(backgroundLoadStep, 0, false)
		end
	end
	ed.startBackgroundLoad = startBackgroundLoad

	-- ====== 按需同步加载 ======
	local sceneModules = {
		battle = {
			modules = {
				"battle/battle_scene", "battle/battle_engine",
				"battle/edp", "battle/popup", "battle/loot",
				"battle/entity", "battle/unit", "battle/skill",
				"battle/buff", "battle/stage", "battle/npc",
				"battle/ai", "battle/projectile", "battle/chain",
				"battle/effect", "battle/preload", "battle/puppet",
				"battle/ball", "battle/energyball", "battle/battle_check",
				"ui/battleStatistics", "ui/battle_share",
			},
			dataTables = { "Battle", "Buff", "SkillGroup", "AnimDuration", "AnimAtkFrame", "affixcount" },
		},
		pvp = {
			modules = { "ui/pvp" },
			dataTables = { "PVPEmeny", "PVPRankReward" },
		},
		guild = {
			modules = { "ui/guild/guild", "ui/guild/guildreward", "ui/guild/guildspecialreward" },
			dataTables = { "GuildWorship", "GuildHirePrice" },
		},
		tavern = {
			modules = {
				"ui/tavern", "ui/listener/tavernlsr",
				"ui/parameter/tavernres", "ui/popwindow/poptavernloot",
				"ui/listener/poptavernlootlsr",
			},
		},
		stageselect = {
			modules = {
				"ui/stageselect", "ui/listener/stageselectlsr",
				"ui/parameter/stageselectres", "ui/stagedetail",
				"ui/listener/stagedetaillsr", "ui/parameter/stagedetailres",
				"ui/battleprepare", "ui/listener/battlepreparelsr",
				"ui/stagedone", "ui/listener/stagedonelsr",
				"ui/stagefailed", "ui/listener/stagefailedlsr",
			},
		},
		shop = {
			modules = {
				"ui/market/marketconfig", "ui/market/market", "ui/market/shop",
				"ui/listener/shoplsr",
			},
		},
		package = {
			modules = {
				"ui/package", "ui/listener/packagelsr",
				"ui/heropackage", "ui/listener/heropackagelsr",
				"ui/heroitem", "ui/equipablelist",
			},
		},
		equip = {
			modules = {
				"ui/equipstrengthen", "ui/listener/equipstrengthenlsr",
				"ui/equipdetail", "ui/listener/equipdetaillsr",
				"ui/equipcraft", "ui/listener/equipcraftlsr",
				"ui/fragmentcompose", "ui/listener/fragmentcomposelsr",
				"ui/parameter/packageres",
			},
		},
		task = {
			modules = { "ui/task", "ui/listener/tasklsr" },
		},
		herodetail = {
			modules = {
				"ui/herodetail/param", "ui/herodetail/listener",
				"ui/herodetail/controller", "ui/herodetail/net",
				"ui/herodetail/herofca", "ui/herodetail/window",
				"ui/herodetail/attributes", "ui/herodetail/skillstren",
				"ui/herodetail/card", "ui/herodetail/evolveequip",
				"ui/herosplit/split", "ui/herosplit/window",
				"ui/selectwindow/base", "ui/selectwindow/ofavatar",
				"ui/selectwindow/ofhero", "ui/selectwindow/ofitem",
				"ui/listener/heroselectlsr",
				"ui/popwindow/popherocard", "ui/listener/popherocardlsr",
				"ui/popwindow/eatexplist", "ui/listener/eatexplistlsr",
				"ui/popwindow/bename", "ui/popwindow/fastsell", "ui/popwindow/buyconfirm",
			},
		},
		handbook = {
			modules = { "ui/handbook", "ui/listener/handbooklsr" },
		},
		recharge = {
			modules = {
				"ui/recharge", "ui/newrecharge", "ui/listener/rechargelsr",
				"activity/ContinueChargeDialog", "activity/ContinueRecharge",
				"activity/ActivityPage", "activity/LottoPage",
				"activity/ActiveRechargeRebate", "activity/EveryDayHappy",
				"activity/BigPackagePage",
			},
		},
		exercise = {
			modules = { "ui/exercise", "ui/listener/exerciselsr", "ui/parameter/exerciseres", "ui/dungeon_map", "gametable/dungeonmapconfig" },
			dataTables = { "ActStageGroupDungeon", "StageDungeon", "ActStageGroup", "Stage" },
		},
		dungeon_map = {
			modules = {
				"ui/dungeon_map", "gametable/dungeonmapconfig",
				"ui/exercise", "ui/listener/exerciselsr", "ui/parameter/exerciseres",
			},
			dataTables = { "ActStageGroupDungeon", "StageDungeon", "ActStageGroup", "Stage" },
		},
	}

	local function ensureSceneModules(sceneName)
		local group = sceneModules[sceneName]
		if not group then return true end
		for _, mod in ipairs(group.modules) do
			if not package.loaded[mod] then
				pcall(require, mod)
			end
		end
		for _, dt in ipairs(group.dataTables or {}) do
			pcall(function() ed.getDataTable(dt) end)
		end
		return true
	end
		ed.ensureSceneModules = ensureSceneModules

	local scene_stack = {}
	ed.scene_stack = scene_stack

--add by xinghui
local function registerFont()
	local platformTag=GetPlatformOS()
	local name, win32FontFile, iosFontFile, androidFontFile, fontColor, size, fontStyle, targetFontFile	
	for k, v in pairs(EDTables.fontcfg.annfonts) do	
		name = v.name
		win32FontFile = v.win32
		iosFontFile = v.ios
		androidFontFile = v.android
		fontColor = v.color
		size = v.size
		fontStyle = v.style
		if platformTag == 3 then
			targetFontFile = win32FontFile
		elseif platformTag == 2 then
			targetFontFile =  androidFontFile
		elseif platformTag == 1 then
			targetFontFile =  iosFontFile
		end
		FontFactory:instance():create_font(name, targetFontFile, fontColor, size, fontStyle)
	end
end
--

local main = function()
	local list = {
	["WVGA"] = {800, 480},
	["720p"] = {1280, 720},
	["1080p"] = {1920, 1080},
	["iPhone"] = {1024, 615},
	["iPad"] = {2048, 1230}
	}
	
	local resource_resolution="iPhone"
	
	local rr = list[resource_resolution]
	local lowres = 1
	
	if false then
		EDSwitchToResolutionDir(1)
		lowres = 0.5
	end
	
	CCDirector:sharedDirector():setContentScaleFactor(lowres * rr[2] / 480)
	LegendLog("[hello.lua|main]-------------------------------------------start")
	
	LegendLog("[hello.lua|main]Current Version: " .. SeverConsts:getInstance():getBaseVersion())
	LegendLog("[hello.lua|main]-------------------------------------------end")
	
	if LegendLuaReset then
		LegendLog("[hello.lua|main]LegendLuaReset is set")
	end
	
	--add by xinghui
	registerFont()
	--
	
	collectgarbage("setpause", 100)
	collectgarbage("setstepmul", 5000)
	LegendLuaReset = LegendLuaReset or 0
	if LegendPlatformFLAG==ed.PlatformCode.CC_PLATFORM_ANDROID and LegendLuaReset == 1 then
		LegendLog("[hello.lua|main] go to ed.ui.platformlogo.create()")
		ed.pushScene(ed.ui.platformlogo.create())
	else
		LegendLog("[hello.lua|main] go to ed.ui.serverlogin.create() localMode=" .. tostring(ed.config.localMode))
		if ed.config.localMode then
			ed.pushScene(ed.ui.logo.create(sessionId))
		else
			ed.pushScene(ed.ui.serverlogin.create())
		end
		--ed.pushScene(ed.ui.logo.create(sessionId))
		--ed.replaceScene(ed.ui.logo.create(sessionId))
	end
	local update_entry_id = CCDirector:sharedDirector():getScheduler():scheduleScriptFunc(ed.gameUpdate, 0, false)
end

local function cleanupBeforeTransition()
	if ed.ui.announce and ed.ui.announce.base then
		local cache = ed.ui.announce.base.windowCache or {}
		for i = #cache, 1, -1 do
			local v = cache[i]
			if v and v.mainLayer and not tolua.isnull(v.mainLayer) then
				pcall(function() v.mainLayer:removeFromParentAndCleanup(true) end)
			end
		end
		ed.ui.announce.base.windowCache = {}
	end
end

-- GC stop 仅为避免场景切换过渡帧被 GC 打断，下一帧必须恢复；
-- 否则非 basescene 场景（如 battle_scene 无 onEnter → 无 collectgarbage("restart")）
-- 战斗全程 GC 停止，每帧闭包/table 纯累积 → emergency GC 大卡顿
local function resumeGcNextFrame()
	local scheduler = CCDirector:sharedDirector():getScheduler()
	local entry
	entry = scheduler:scheduleScriptFunc(function()
		scheduler:unscheduleScriptEntry(entry)
		collectgarbage("restart")
	end, 0, false)
end

local function pushScene(scene)
	table.insert(scene_stack, scene)
	collectgarbage("stop")
	resumeGcNextFrame()
	CCDirector:sharedDirector():pushScene(scene:ccScene())
end
ed.pushScene = pushScene

local function popScene()
	LegendLog("popScene ")
	if #scene_stack > 0 then
		if scene_stack[#scene_stack].identity == "main" then
			return
		end
		local scene = table.remove(scene_stack, #scene_stack)
		if scene.OnPopScene then
			scene:OnPopScene()
		end
	end
	cleanupBeforeTransition()
	CCDirector:sharedDirector():popScene()
end
ed.popScene = popScene

local function popScene2()
	LegendLog("popScene2 ")
	if #scene_stack > 0 then
		if scene_stack[#scene_stack].identity == "main" or scene_stack[#scene_stack].identity == "serverlogin" or scene_stack[#scene_stack].identity == "logo" then
			return
		end
		local scene = table.remove(scene_stack, #scene_stack)
		if scene.OnPopScene then
			scene:OnPopScene()
		end
	end
	for i = #scene_stack, 1, -1 do scene_stack[i] = nil end
	local fresh = ed.ui.main.create("main")
	table.insert(scene_stack, fresh)
	CCDirector:sharedDirector():replaceScene(fresh:ccScene())
end
ed.popScene2 = popScene2

local function replaceScene(scene)
	if #scene_stack > 0 then
		local top = scene_stack[#scene_stack]
		if top.identity == "main" or top.identity == "pvp" then
			if #scene_stack < 10 then
				pushScene(scene)
				return
			end
		end
		local old = table.remove(scene_stack, #scene_stack)
		if old.OnPopScene then
			old:OnPopScene()
		end
	end
	table.insert(scene_stack, scene)
	scene.pushed = false
	cleanupBeforeTransition()
	collectgarbage("stop")
	resumeGcNextFrame()
	CCDirector:sharedDirector():replaceScene(scene:ccScene())
end
ed.replaceScene = replaceScene

local function getSceneCount()
	
	if #scene_stack > 0 then
		if scene_stack[#scene_stack].identity == "main" or scene_stack[#scene_stack].identity == "serverlogin" or scene_stack[#scene_stack].identity == "logo" then
			return 0
		end
	end
	return #scene_stack
end
ed.getSceneCount=getSceneCount

local applicationDidEnterBackground = function()
	print("applicationDidEnterBackground")
	LegendLog("applicationDidEnterBackground")
	
	ed.loadEnd()
	ed.closeConnect()
	if ed.player.initialized then
		--modify by xinghui:������Ϸ��ʱ���Ѿ�ˢ��
		--ed.localnotify.refresh()
	end
	if resume_timestamp and game_server_ip then
		local msg = ed.upmsg.suspend_report()
		msg._gametime = ed.getMillionTime() - resume_timestamp
		resume_timestamp = nil
		ed.send(msg, "suspend_report")
	end
end
ed.applicationDidEnterBackground = applicationDidEnterBackground
local applicationWillEnterForeground = function()
	LegendLog("applicationWillEnterForeground 31")
	ed.loadEnd()
	ed.closeConnect()
	--ed.playMusic(ed.music.map)
	resume_timestamp = ed.getMillionTime()
	if ed.checkSoundSwitch then
		ed.checkSoundSwitch()
	end
end
ed.applicationWillEnterForeground = applicationWillEnterForeground
local runScriptString = function()
	local temp = LegendGetScriptString()
	if temp ~= nil then
		local func = loadstring(temp)
		if func ~= nil then
			xpcall(func, EDDebug)
		end
	end
end
local gcPassTime = 0
local function memeryGC(fDelTime)
	gcPassTime = gcPassTime + fDelTime
	if gcPassTime > 10 then
		LegendLog("[DIAG] gameUpdate alive")
		CCSpriteFrameCache:sharedSpriteFrameCache():gc(gcPassTime)
		CCTextureCache:sharedTextureCache():gc(gcPassTime)
		LegendAnimation:gc(gcPassTime)
		gcPassTime = 0
	end
end
local function getCurrentScene()
	return scene_stack[#scene_stack]
end
ed.getCurrentScene = getCurrentScene
local update_timestamp = ed.getMillionTime()
local resume_timestamp
local game_update_handler_list = {}
-- 提为命名函数：xpcall 直接传引用，避免每帧创建 2 个闭包
local _gu_tick = 0
-- PERF 诊断：每 5 秒墙钟（毫秒）打印逻辑帧率与 Lua 堆大小（os.clock 在 Android 是 CPU 时间，帧率会被高估）
local _diag_t0, _diag_frames = ed.getMillionTime(), 0
local function gameUpdateImpl()
	local time = ed.getMillionTime()
	if not resume_timestamp then
		resume_timestamp = time
	end
	local raw_dt = update_timestamp ~= 0 and (time - update_timestamp) / 1000 or 0
	-- 钳制到 2 个逻辑 tick：低帧率(<30fps)下保持游戏时间流速（原钳制 1 tick 会把 17fps 压成 58% 速度的慢动作），
	-- 极端卡顿(>66ms/帧)时仍防大跳帧
	local dt = math.min(raw_dt, ed.tick_interval * 2)

	update_timestamp = time
	ed.proc_net()
	local scene = scene_stack[#scene_stack] or {}
	if scene.update then
		scene:update(dt)
	end
	runScriptString()
	UpdateEventSystem(dt)
	memeryGC(dt)
	for k, v in pairs(game_update_handler_list or {}) do
		v(dt)
	end
	_diag_frames = _diag_frames + 1
	local now = ed.getMillionTime()
	local elapsed = (now - _diag_t0) / 1000
	if elapsed >= 5 then
		local msg = string.format("[PERF] %.0f fps(logic), lua heap %.1f MB\n", _diag_frames / elapsed, collectgarbage("count") / 1024)
		print(msg)
		-- print 管道可能被吞，同时落盘到 writable path 保底
		pcall(function()
			local p = CCFileUtils:sharedFileUtils():getWritablePath() .. "perf.log"
			local f = io.open(p, "a")
			if f then f:write(msg) f:close() end
		end)
		_diag_t0, _diag_frames = now, 0
	end
	-- 调试钩子：每 2 秒轮询 writable/debugcmd.lua，存在则执行并删除（MuMu 实测注入通道）
	_dbghook_t = (_dbghook_t or 0) + dt
	if _dbghook_t > 2 then
		_dbghook_t = 0
		pcall(function()
			local p = CCFileUtils:sharedFileUtils():getWritablePath() .. "debugcmd.lua"
			local f = io.open(p, "r")
			if f then
				local code = f:read("*a")
				f:close()
				os.remove(p)
				local fn = loadstring(code)
				if fn then
					xpcall(fn, function(e)
						print("[DBGHOOK] error: " .. tostring(e))
					end)
				end
			end
		end)
	end
end

local function gameUpdateErr(msg)
	LegendLog("[gameUpdate ERROR] " .. tostring(msg))
	EDDebug(msg)
end

local function gameUpdate()
	_gu_tick = _gu_tick + 1
	xpcall(gameUpdateImpl, gameUpdateErr)
end
ed.gameUpdate = gameUpdate
local function registerGameUpdateHandler(key, handler)
	game_update_handler_list = game_update_handler_list or {}
	game_update_handler_list[key] = handler
end
ed.registerGameUpdateHandler = registerGameUpdateHandler
local function removeGameUpdateHandler(key)
	game_update_handler_list = game_update_handler_list or {}
	game_update_handler_list[key] = nil
end
ed.removeGameUpdateHandler = removeGameUpdateHandler
local initGcTime = function()
	CCSpriteFrameCache:sharedSpriteFrameCache():setGcTime(60)
	CCTextureCache:sharedTextureCache():setGcTime(60)
	LegendAnimation:setgcTime(120)
end

function OnRestartGame()
	local function handler()
		--CloseEvent("RestartGame")
		ed.replaceScene(ed.ui.platformlogo.create())
	end
	return handler
end

function createAnimation(resource, scale, aniType)
    local scale = scale or 1.0;
    local aniType = aniType or Type_LegendAnimation;
    if aniType == Type_LegendAnimation then
        return LegendAnimation:create(resource, scale);
    elseif aniType == Type_Spine then
        return SpineContainer:create('spine/' .. resource, resource ,scale)
    elseif aniType==Type_DragonBone then
    	return ArmatureContainer:create("dragbone/"..resource,resource,nil)
    end
end
ed.createAnimation = createAnimation;

xpcall(function()
		local ed = ed
			ed.run_with_scene = true
			LegendLog("[HELLO] loadAllFiles START")
			loadAllFiles()
			LegendLog("[HELLO] loadAllFiles DONE")
LegendLog("[HELLO] initFont START")
			initFont()
			LegendLog("[HELLO] initFont DONE")
			initGcTime()
LegendLog("[HELLO] main() START")
			main()
			LegendLog("[HELLO] main() DONE")
			-- 主场景创建后后台加载延迟数据表
LegendLog("[HELLO] startBackgroundLoad START")
			ed.startBackgroundLoad()
			LegendLog("[HELLO] startBackgroundLoad DONE")
	end, EDDebug)
		