-----------------------------------------------------------------------
-- local_server.lua
-- 本地服务器模拟模块：拦截所有网络请求，在客户端 Lua 层模拟服务端响应
-- 用于将 cocos2d-x 卡牌游戏改造为完全单机版
-----------------------------------------------------------------------

local ed = ed
local math_floor = math.floor
local math_random = math.random
local table_insert = table.insert
local ipairs = ipairs
local pairs = pairs
local rawget = rawget
local tostring = tostring
local tonumber = tonumber
local type = type

-----------------------------------------------------------------------
-- JSON 库（util/json.lua 通过 module("json") 注册为全局变量）
-----------------------------------------------------------------------
local json = json

-----------------------------------------------------------------------
-- 常量
-----------------------------------------------------------------------
local SAVE_KEY = "local_save_data"
local SERVER_TIMEZONE = "+8"

-----------------------------------------------------------------------
-- 深拷贝工具
-----------------------------------------------------------------------
local function deepCopy(obj)
    if type(obj) ~= "table" then return obj end
    local copy = {}
    for k, v in pairs(obj) do
        copy[k] = deepCopy(v)
    end
    return copy
end

-----------------------------------------------------------------------
-- 默认玩家数据
-----------------------------------------------------------------------
local DEFAULT_DATA = {
    player = {
        userid = 1,
        name = "Player",
        avatar = 0,
        level = 1,
        exp = 0,
        gold = 100000,
        diamond = 5000,
        recharge_sum = 0,
        last_login = 0,
        sessionid = 0,
    },
    vitality = {
        current = 120,
        lastchange = 0,
        todaybuy = 0,
        lastbuy = 0,
    },
    heroes = {
        { tid = 1, rank = 1, level = 1, stars = 1, exp = 0, gs = 100, state = "idle", skill_levels = {1,1,1,1} },
        { tid = 2, rank = 1, level = 1, stars = 1, exp = 0, gs = 100, state = "idle", skill_levels = {1,1,1,1} },
        { tid = 3, rank = 1, level = 1, stars = 1, exp = 0, gs = 100, state = "idle", skill_levels = {1,1,1,1} },
        { tid = 4, rank = 1, level = 1, stars = 1, exp = 0, gs = 100, state = "idle", skill_levels = {1,1,1,1} },
        { tid = 5, rank = 1, level = 1, stars = 1, exp = 0, gs = 100, state = "idle", skill_levels = {1,1,1,1} },
    },
    items = {
        [101] = 10, [102] = 10,
        [106] = 5, [107] = 5, [108] = 5, [109] = 5, [110] = 5, [111] = 5,
    },
    stage = {
        max_normal = 0,
        normal_stars = {},
        elite_stars = {},
        elite_daily = {},
        elite_reset_time = 0,
        sweep_last_reset = 0,
        sweep_today_free = 0,
        act_reset_time = 0,
    },
    skill = {
        chance = 5,
        cd_time = 0,
        reset_times = 0,
        last_reset_date = 0,
    },
    tavern = {
        { box_type = "green",  left_count = 5, last_get_time = 0, has_first_draw = 0 },
        { box_type = "blue",   left_count = 5, last_get_time = 0, has_first_draw = 0 },
        { box_type = "purple", left_count = 5, last_get_time = 0, has_first_draw = 0 },
    },
    tutorial = (function()
        local t = {}
        for i = 1, 96 do t[i] = 10 end
        return t
    end)(),
    midas = { last_change = 0, today_times = 0 },
    daily_login = { status = "nothing", frequency = 0, last_login_date = 0 },
    battle = { stage_id = 0, enter_time = 0, srand = 0 },
    shop = {
        { id = 1, last_auto_refresh_time = 0, expire_time = 0, last_manual_refresh_time = 0, today_times = 0, goods = {} }
    },
    task = {},            -- 当前活跃任务 [{chain=N, id=N, status="working"}, ...]
    task_finished = {},   -- 已完成的任务链ID列表
}

-----------------------------------------------------------------------
-- 数据管理层 LocalData
-----------------------------------------------------------------------
local LocalData = {}

function LocalData.load()
    local ud = CCUserDefault:sharedUserDefault()
    local saved = ud:getStringForKey(SAVE_KEY)
    if saved and saved ~= "" then
        local ok, data = pcall(json.decode, saved)
        if ok and data and type(data) == "table" then
            return data
        end
    end
    return deepCopy(DEFAULT_DATA)
end

function LocalData.save(data)
    local ud = CCUserDefault:sharedUserDefault()
    local ok, str = pcall(json.encode, data)
    if ok and str then
        ud:setStringForKey(SAVE_KEY, str)
        ud:flush()
    end
end

function LocalData.reset()
    return deepCopy(DEFAULT_DATA)
end

-----------------------------------------------------------------------
-- 构建器函数 Builders
-----------------------------------------------------------------------

-- 构造 hero_equip 列表（6个槽位）
local function buildHeroEquips()
    local equips = {}
    for i = 1, 6 do
        equips[i] = { _index = i, _item_id = 0, _exp = 0 }
    end
    return equips
end

-- 构造单个 hero 子消息
local function buildHero(hero_data)
    if not hero_data then return nil end
    return {
        _tid = hero_data.tid,
        _rank = hero_data.rank or 1,
        _level = hero_data.level or 1,
        _stars = hero_data.stars or 1,
        _exp = hero_data.exp or 0,
        _gs = hero_data.gs or 100,
        _state = hero_data.state or "idle",
        _skill_levels = hero_data.skill_levels or {1,1,1,1},
        _items = buildHeroEquips(),
    }
end

-- 构造 vitality 子消息
local function buildVitality(vit_data)
    if not vit_data then
        vit_data = { current = 120, lastchange = 0, todaybuy = 0, lastbuy = 0 }
    end
    return {
        _current = vit_data.current or 120,
        _lastchange = vit_data.lastchange or 0,
        _todaybuy = vit_data.todaybuy or 0,
        _lastbuy = vit_data.lastbuy or 0,
    }
end

-- 构造 skilllevelup 子消息
local function buildSkillLevelUp(skill_data)
    if not skill_data then
        skill_data = { chance = 5, cd_time = 0, reset_times = 0, last_reset_date = 0 } -- cd_time 在 buildSkillLevelUp 中 fallback 到 os.time()
    end
    return {
        _skill_levelup_chance = skill_data.chance or 5,
        _skill_levelup_cd = skill_data.cd_time or os.time(),
        _reset_times = skill_data.reset_times or 0,
        _last_reset_date = skill_data.last_reset_date or 0,
    }
end

-- 构造 userstage 子消息
local function buildUserStage(stage_data)
    if not stage_data then
        stage_data = {
            normal_stars = {},
            elite_stars = {},
            elite_daily = {},
            elite_reset_time = 0,
            sweep_last_reset = 0,
            sweep_today_free = 0,
            act_reset_time = 0,
        }
    end
    return {
        _normal_stage_stars = stage_data.normal_stars or {},
        _elite_stage_stars = stage_data.elite_stars or {},
        _elite_daily_record = stage_data.elite_daily or {},
        _elite_reset_time = stage_data.elite_reset_time or 0,
        _sweep = {
            _last_reset_time = stage_data.sweep_last_reset or 0,
            _today_free_sweep_times = stage_data.sweep_today_free or 0,
        },
        _act_reset_time = stage_data.act_reset_time or 0,
    }
end

-- 构造 tavern_record 子消息
local function buildTavernRecords(tavern_data)
    if not tavern_data then return {} end
    local records = {}
    local box_type_map = { green = 1, blue = 2, purple = 3, magicsoul = 4 }
    for i, t in ipairs(tavern_data) do
        records[i] = {
            _box_type = box_type_map[t.box_type] or 1,
            _left_cnt = t.left_count or 5,
            _last_get_time = t.last_get_time or 0,
            _has_first_draw = t.has_first_draw or 0,
        }
    end
    return records
end

-- 构造物品列表（编码为 repeated uint32）
local function buildItemsList(items_data)
    if not items_data then return {} end
    local items = {}
    for id, amount in pairs(items_data) do
        if amount > 0 then
            table_insert(items, ed.makebits(11, amount, 10, id))
        end
    end
    return items
end

-- 构造完整 user 消息（login/reset 时使用）
local function buildUser(localdata)
    local p = localdata.player
    local heroes = {}
    for i, h in ipairs(localdata.heroes or {}) do
        heroes[i] = buildHero(h)
    end

    return {
        _userid = p.userid or 1,
        _name_card = {
            _name = p.name or "Player",
            _last_set_name_time = 0,
            _avatar = p.avatar or 0,
        },
        _level = p.level or 1,
        _recharge_sum = p.recharge_sum or 0,
        _exp = p.exp or 0,
        _money = p.gold or 0,
        _rmb = p.diamond or 0,
        _vitality = buildVitality(localdata.vitality),
        _heroes = heroes,
        _items = buildItemsList(localdata.items),
        _skill_level_up = buildSkillLevelUp(localdata.skill),
        _userstage = buildUserStage(localdata.stage),
        _shop = {},
        _tutorial = (function()
            -- 强制所有教程已完成（忽略存档数据，避免教程卡死）
            local t = {}
            for i = 1, 96 do t[i] = 10 end
            return t
        end)(),
        _task = (function()
            local tasks = {}
            for _, t in ipairs(localdata.task or {}) do
                if t.status ~= "finished" then
                    table_insert(tasks, {
                        _line = t.chain,
                        _id = t.id,
                        _status = t.status or "working",
                        _task_target = t.target or 0,
                    })
                end
            end
            return tasks
        end)(),
        _task_finished = localdata.task_finished or {},
        _last_login = p.last_login or 0,
        _dailyjob = (function()
            local jobs = {}
            local tdt = ed.getDataTable("Todolist")
            if tdt then
                for id, row in pairs(tdt) do
                    if type(id) == "number" then
                        table.insert(jobs, {
                            _id = id,
                            _task_target = 0,
                            _last_rewards_time = 0,
                        })
                    end
                end
            end
            return jobs
        end)(),
        _tavern_record = buildTavernRecords(localdata.tavern),
        _usermidas = {
            _last_change = localdata.midas and localdata.midas.last_change or 0,
            _today_times = localdata.midas and localdata.midas.today_times or 0,
        },
        _daily_login = {
            _status = (localdata.daily_login and localdata.daily_login.status) or "nothing",
            _frequency = (localdata.daily_login and localdata.daily_login.frequency) or 0,
            _last_login_date = (localdata.daily_login and localdata.daily_login.last_login_date) or 0,
        },
        _recharge_limit = {},
        _vip_gifts_draw = {},
        _points = {},
        _month_card = {},
        _user_guild = { _id = 0, _name = "" },
        _chat = { _world_chat_times = 0, _last_reset_world_chat_time = 0 },
        _sshop = {
            _id = 6,
            _expire_time = os.time() + 86400 * 30,
            _star_goods = generateStarGoods(),
        },
        _facebook_follow = 1,
        _praise = "",
        _sessionid = p.sessionid or 0,
    }
end

-----------------------------------------------------------------------
-- 辅助函数
-----------------------------------------------------------------------

-- 获取当前时间戳
local function getTimestamp()
    return os.time()
end

-- 生成星际商店商品
-- TavernBoxType: 8=stone_green(小), 9=stone_blue(中), 10=stone_purple(大)
local function generateStarGoods()
    local goods = {}
    local types = { 0, 0, 1, 1, 2 }
    local stoneIds = { [0] = 8, [1] = 9, [2] = 10 }
    local prices = { [0] = 50, [1] = 100, [2] = 200 }
    for i, t in ipairs(types) do
        table.insert(goods, {
            _type = t,
            _amount = 1,
            _stone_id = stoneIds[t],
            _stone_amount = prices[t],
        })
    end
    return goods
end

-- 生成随机种子
local function makeRandomSeed()
    return math_random(1, 2147483647)
end

-- 查找英雄数据
local function findHero(localdata, tid)
    for i, h in ipairs(localdata.heroes) do
        if h.tid == tid then
            return h, i
        end
    end
    return nil, nil
end

-- 掉落物品生成（从 Stage 配置中读取，掉落翻倍+扫荡券）
local function generateLoots(stage_id)
    local loots = {}
    local StageTable = ed.getDataTable("Stage")
    if not StageTable then return loots end
    local stageCfg = StageTable[stage_id]
    if not stageCfg then return loots end

    for i = 1, 7 do
        local rewardId = stageCfg["UI reward" .. i]
        local rewardPro = stageCfg["UI reward" .. i .. " Pro"] or 100
        if rewardId and rewardId ~= 0 and math_random(1, 100) <= (rewardPro or 0) then
            -- 掉落翻倍：每个物品加2个
            local packed = ed.makebits(3, 1, 3, 1, 10, rewardId)
            table_insert(loots, packed)
            table_insert(loots, packed)
        end
    end
    -- 必掉扫荡券（物品ID=390）
    local sweepPacked = ed.makebits(3, 1, 3, 1, 10, 390)
    table_insert(loots, sweepPacked)
    return loots
end

-- 获取关卡掉落的经验和金币（10倍）
local function getStageRewards(stage_id)
    local StageTable = ed.getDataTable("Stage")
    if not StageTable then return 0, 0 end
    local stageCfg = StageTable[stage_id]
    if not stageCfg then return 0, 0 end
    return (stageCfg["Exp Reward"] or 0) * 10, (stageCfg["Money Reward"] or 0) * 10
end

-- 副本硬币掉落：普通5-10，英雄15-25
local function getDungeonCoinReward(difficulty)
  if difficulty == 2 then
    return math.random(15, 25)
  end
  return math.random(5, 10)
end

-- 副本Stage->Group映射
local dungeonStageToGroup = {
  [40001]=40001,[40002]=40001,[40003]=40001,
  [40004]=40002,[40005]=40002,[40006]=40002,
  [40007]=40003,[40008]=40003,[40009]=40003,
  [40010]=40004,[40011]=40004,[40012]=40004,
  [40013]=40005,[40014]=40005,[40015]=40005,
  [40016]=40006,[40017]=40006,[40018]=40006,
  [40019]=40007,[40020]=40007,[40021]=40007,
}

local function isDungeonStage(stage_id)
  return stage_id >= 40001 and stage_id <= 40021
end
ed.isDungeonStage = isDungeonStage

-- 副本掉落：概率+保底+优先未拥有
local function generateDungeonLoots(stage_id)
  local loots = {}
  local stageTable = ed.getDataTable("StageDungeon")
  if not stageTable then return loots end
  local stage = stageTable[stage_id]
  if not stage then return loots end

  local difficulty = stage["Difficulty"] or 1
  local dropRate = difficulty == 2 and 0.2 or 0.3

  for i = 1, 7 do
    local rewardId = stage["UI reward" .. i]
    if rewardId and rewardId ~= 0 then
      if math.random() < dropRate then
        table_insert(loots, ed.makebits(3, 1, 3, 1, 10, rewardId))
      end
    end
  end

  -- 保底
  if #loots == 0 then
    local candidates = {}
    for i = 1, 7 do
      local rewardId = stage["UI reward" .. i]
      if rewardId and rewardId ~= 0 then
        table_insert(candidates, rewardId)
      end
    end
    if #candidates > 0 then
      local chosen = nil
      if ed.player then
        for _, id in ipairs(candidates) do
          local owned = false
          for _, item in pairs(ed.player.items or {}) do
            if item._id == id then owned = true break end
          end
          if not owned then chosen = id break end
        end
      end
      if not chosen then chosen = candidates[math.random(#candidates)] end
      table_insert(loots, ed.makebits(3, 1, 3, 1, 10, chosen))
    end
  end

  return loots
end

-- 获取关卡体力消耗
local function getStageVitalityCost(stage_id)
    local StageTable = ed.getDataTable("Stage")
    if not StageTable then return 0 end
    local stageCfg = StageTable[stage_id]
    if not stageCfg then return 0 end
    return stageCfg["Vitality Cost"] or 0
end

-- 判断关卡类型
local function isEliteStage(stage_id)
    return stage_id and stage_id >= 10000
end

-----------------------------------------------------------------------
-- 主模块
-----------------------------------------------------------------------
local M = {}
M.data = nil

-----------------------------------------------------------------------
-- Handler 定义
-- 签名: function(data, obj, localdata)
--   data: down_msg 的 .data 表，直接设置字段即可
--   obj: 客户端发送的消息对象（up_msg 中的字段）
--   localdata: 本地存储的数据引用
-----------------------------------------------------------------------
M.handlers = {}

-- ========== login ==========
-- obj: 无特殊字段，login 由系统触发
M.handlers.login = function(data, obj, localdata)
    local now = getTimestamp()
    localdata.player.last_login = now
    localdata.player.sessionid = math_random(100000, 999999)
    LocalData.save(localdata)

    -- 恢复竞技场数据
    do
      local pvpJson = CCUserDefault:sharedUserDefault():getStringForKey("pvp_data")
      if pvpJson and pvpJson ~= "" then
        local ok, pvpData = pcall(json.decode, pvpJson)
        if ok and pvpData then
            localdata.player._pvp = pvpData
        end
      end
    end

    data._login_reply = {
        _result = "success",
        _user = buildUser(localdata),
        _time_zone = SERVER_TIMEZONE,
    }

    -- 附带活动通知，让客户端显示活动按钮
    local activities = generateActivities(localdata)
    data._activity_notify = activities
end

-- ========== get_svr_time ==========
M.handlers.get_svr_time = function(data, obj, localdata)
    data._svr_time = getTimestamp()
end

-- ========== enter_stage ==========
-- obj: { _stage_id = N }
M.handlers.enter_stage = function(data, obj, localdata)
    local stage_id = obj._stage_id or 0
    local rseed = makeRandomSeed()
    local loots = generateLoots(stage_id)

    localdata.battle = {
        stage_id = stage_id,
        enter_time = getTimestamp(),
        srand = rseed,
    }
    LocalData.save(localdata)

    data._enter_stage_reply = {
        _rseed = rseed,
        _loots = loots,
    }
end

-- ========== enter_act_stage ==========
-- obj: { _stage = N, _stage_group = N }
-- 与 enter_stage 共用 _enter_stage_reply，local_dispatch 已处理
M.handlers.enter_act_stage = function(data, obj, localdata)
    local stage_id = obj._stage or 0
    local stage_group = obj._stage_group or 0

    -- 副本关卡走 StageDungeon 表
    if isDungeonStage(stage_id) then
        local stageTable = ed.getDataTable("StageDungeon")
        if not stageTable or not stageTable[stage_id] then
            data._enter_stage_reply = { _error = "invalid_stage" }
            return
        end
        local stageCfg = stageTable[stage_id]

        local expectedGroup = dungeonStageToGroup[stage_id]
        if expectedGroup ~= stage_group then
            data._enter_stage_reply = { _error = "group_mismatch" }
            return
        end

        local unlockLv = stageCfg["Unlock Level"] or 0
        local plyLevel = (ed.player and ed.player:getLevel()) or 1
        if plyLevel < unlockLv then
            data._enter_stage_reply = { _error = "level_lock" }
            return
        end

        -- 次数校验
        local groupTable = ed.getDataTable("ActStageGroupDungeon")
        local groupCfg = groupTable and groupTable[expectedGroup]
        if groupCfg then
            local dailyLimit = groupCfg["DailyLimit"] or 2
            local maxBuy = groupCfg["MaxBuyPerDay"] or 3
            local totalAllowed = dailyLimit + maxBuy
            local usedTimes = ed.player and ed.player:getActTimes(expectedGroup) or 0
            if usedTimes >= totalAllowed then
                data._enter_stage_reply = { _error = "no_attempts" }
                return
            end
            -- 免费次数用完后扣除龙鳞硬币
            if usedTimes >= dailyLimit then
                local buyCost = groupCfg["BuyCost"] or 50
                local coins = ed.player and ed.player:getDungeonPoint() or 0
                if coins < buyCost then
                    data._enter_stage_reply = { _error = "not_enough_coins" }
                    return
                end
                ed.player:addDungeonPoint(-buyCost)
                localdata.player.dungeonpoint = (localdata.player.dungeonpoint or 0) - buyCost
            end
            -- 记录次数
            if ed.player then
                ed.player:addActTimes(expectedGroup)
            end
        end

        local costVit = stageCfg["Vitality Cost"] or 0
        local returnVit = stageCfg["Vit Return"] or 0
        local enterCost = math.max(0, costVit - returnVit)
        if enterCost > 0 and ed.player then
            ed.player:addVitality(-enterCost)
        end

        local rseed = makeRandomSeed()
        local loots = generateDungeonLoots(stage_id)

        localdata.battle = {
            stage_id = stage_id,
            stage_group = stage_group,
            enter_time = getTimestamp(),
            srand = rseed,
        }
        LocalData.save(localdata)

        data._enter_stage_reply = {
            _rseed = rseed,
            _loots = loots,
        }
        return
    end

    local StageTable = ed.getDataTable("Stage")
    if not StageTable or not StageTable[stage_id] then return end
    local stageCfg = StageTable[stage_id]

    -- 校验 stage group 匹配
    if (stageCfg["Stage Group"] or 0) ~= stage_group then return end

    -- 等级检查
    local unlockLv = stageCfg["Unlock Level"] or 0
    local plyLevel = (ed.player and ed.player:getLevel()) or 1
    if plyLevel < unlockLv then return end

    -- 体力消耗（净消耗 = Vitality Cost - Vit Return）
    local costVit = stageCfg["Vitality Cost"] or 0
    local returnVit = stageCfg["Vit Return"] or 0
    local enterCost = math.max(0, costVit - returnVit)
    if enterCost > 0 and ed.player then
        ed.player:addVitality(-enterCost)
    end

    local rseed = makeRandomSeed()
    local loots = generateLoots(stage_id)

    localdata.battle = {
        stage_id = stage_id,
        stage_group = stage_group,
        enter_time = getTimestamp(),
        srand = rseed,
    }
    LocalData.save(localdata)

    data._enter_stage_reply = {
        _rseed = rseed,
        _loots = loots,
    }
end

-- ========== exit_stage ==========
-- obj: { _result = "victory"/"defeat"/..., _stars = N, _heroes = {...}, ... }
M.handlers.exit_stage = function(data, obj, localdata)
    local result = "known"
    local stage_id = localdata.battle and localdata.battle.stage_id or 0

    if stage_id > 0 then
        local battleResult = obj._result
        if battleResult == "victory" then
            -- 副本关卡：从 StageDungeon 读奖励
            if isDungeonStage(stage_id) then
                local stageTable = ed.getDataTable("StageDungeon")
                local stageCfg = stageTable and stageTable[stage_id]
                if stageCfg then
                    local expReward = (stageCfg["Exp Reward"] or 0) * 10
                    local goldReward = difficulty == 2 and 5000 or 2000
                    localdata.player.exp = localdata.player.exp + expReward
                    localdata.player.gold = localdata.player.gold + goldReward

                    -- 副本硬币
                    local difficulty = stageCfg["Difficulty"] or 1
                    local coins = getDungeonCoinReward(difficulty)
                    if ed.player then ed.player:addDungeonPoint(coins) end
                    localdata.player.dungeonpoint = (localdata.player.dungeonpoint or 0) + coins
                end
            else
                local expReward, moneyReward = getStageRewards(stage_id)
                localdata.player.exp = localdata.player.exp + expReward
                localdata.player.gold = localdata.player.gold + moneyReward
            end

            if not isEliteStage(stage_id) and not isDungeonStage(stage_id) then
                if stage_id >= localdata.stage.max_normal then
                    localdata.stage.max_normal = stage_id
                end
                if obj._stars then
                    localdata.stage.normal_stars[stage_id] = math.max(
                        localdata.stage.normal_stars[stage_id] or 0,
                        obj._stars
                    )
                end
            else
                if obj._stars then
                    localdata.stage.elite_stars[stage_id] = math.max(
                        localdata.stage.elite_stars[stage_id] or 0,
                        obj._stars
                    )
                end
            end
        end
    end

    LocalData.save(localdata)
    pcall(function() ed.saveDirty = true end)

    data._exit_stage_reply = {
        _result = result,
    }
end

-- ========== hero_upgrade ==========
-- obj: { _tid = N } (英雄类型ID)
M.handlers.hero_upgrade = function(data, obj, localdata)
    local tid = obj._hero_id or obj._tid
    local hero = ed.player and ed.player.heroes[tid]

    if hero then
        local newRank = (hero._rank or 1) + 1
        local gs = hero._gs or 0

        -- 同步更新 localdata
        local lh = findHero(localdata, tid)
        if lh then
            lh.rank = newRank
        end

        data._hero_upgrade_reply = {
            _result = "success",
            _hero = {
                _tid = tid,
                _rank = newRank,
                _level = hero._level or 1,
                _stars = hero._stars or 1,
                _exp = hero._exp or 0,
                _gs = gs,
                _state = "idle",
                _skill_levels = hero._skill_levels or {1,1,1,1},
                _items = hero._items or {},
            },
            _items = {},
        }
    else
        data._hero_upgrade_reply = {
            _result = "fail",
        }
    end
end

-- ========== hero_evolve ==========
-- obj: { _heroid = N }
M.handlers.hero_evolve = function(data, obj, localdata)
    local tid = obj._heroid
    local hero = ed.player and ed.player.heroes[tid]

    if hero then
        -- 已有英雄：进化（星星+1）
        local newStars = (hero._stars or 1) + 1
        local gs = hero._gs or 0

        -- 同步更新 localdata
        local lh = findHero(localdata, tid)
        if lh then
            lh.stars = newStars
        end

        data._hero_evolve_reply = {
            _result = "success",
            _hero = {
                _tid = tid,
                _rank = hero._rank or 1,
                _level = hero._level or 1,
                _stars = newStars,
                _exp = hero._exp or 0,
                _gs = gs,
                _state = "idle",
                _skill_levels = hero._skill_levels or {1,1,1,1},
                _items = hero._items or {},
            },
        }
    else
        -- 新英雄召唤：构造初始数据（与 addHero 保持一致）
        local initRank = 1
        local initStars = 1
        pcall(function()
            initRank = ed.lookupDataTable("Unit", "Initial Rank", tid) or 1
            initStars = ed.getDataTable("Unit")[tid]["Initial Stars"] or 1
        end)
        local items = {}
        for i = 1, 6 do
            items[i] = {_item_id = 0, _exp = 0, _index = i}
        end
        local skill_levels = {1,1,1,1}
        pcall(function()
            local sg = ed.getDataTable("SkillGroup")
            for i = 1, 4 do
                if sg and sg[tid] and sg[tid][i] then
                    skill_levels[i] = sg[tid][i]["Init Level"] or 1
                end
            end
        end)

        -- 添加新英雄到 localdata
        if localdata.heroes then
            table.insert(localdata.heroes, {
                tid = tid,
                rank = initRank,
                level = 1,
                stars = initStars,
                exp = 0,
                gs = 5,
                state = "idle",
                skill_levels = skill_levels,
                items = items,
            })
        end

        data._hero_evolve_reply = {
            _result = "success",
            _hero = {
                _tid = tid,
                _rank = initRank,
                _level = 1,
                _stars = initStars,
                _exp = 0,
                _gs = 5,
                _state = "idle",
                _skill_levels = skill_levels,
                _items = items,
            },
        }
    end
    pcall(function() ed.saveDirty = true end)
end

-- ========== consume_item ==========
-- obj: { _hero_id = hero_tid, _item_id = packed_item_info }
M.handlers.consume_item = function(data, obj, localdata)
    local hid = obj._hero_id
    local itemBits = obj._item_id
    if not hid then return end
    local amount, id = ed.splitbits(itemBits, 11, 10)
    amount = amount or 1
    local equipTable = ed.getDataTable("equip")
    local expPerItem = 60
    if equipTable and id then
        local cfg = equipTable[id]
        if cfg then expPerItem = cfg["Exp"] or 60 end
    end
    local expGain = expPerItem * amount
    local hero = ed.player and ed.player.heroes and ed.player.heroes[hid]
    if hero then
        hero:addExp(expGain)
    end
    data._consume_item_reply = {
        _hero = hero and {
            _tid = hero._tid,
            _rank = hero._rank or 1,
            _level = hero._level or 1,
            _stars = hero._stars or 1,
            _exp = hero._exp or 0,
            _gs = hero._gs or 0,
            _state = hero._state or "idle",
            _skill_levels = hero._skill_levels or {1,1,1,1},
            _items = buildHeroEquips(),
        } or nil,
    }
    pcall(function() ed.saveDirty = true end)
end

-- ========== equip_synthesis ==========
-- obj: 合成装备请求（支持递归合成，自动合成所有前置材料）
local function collectCraftChain(targetId)
    local ect = ed.getDataTable("equipcraft")
    local totalCost = 0
    local consume = {}
    local allocated = {}

    local function recurse(id)
        local row = ect[id]
        if not row or (row.Components or 0) < 1 then return end
        totalCost = totalCost + (row.Expense or 0)
        for i = 1, (row.Components or 0) do
            local cid = row["Component" .. i]
            local need = math.max(row[string.format("Component%d Count", i)] or 1, 1)
            local totalHave = ed.player.equip_qunty[cid] or 0
            local available = math.max(totalHave - (allocated[cid] or 0), 0)
            local use = math.min(available, need)
            if use > 0 then
                consume[cid] = (consume[cid] or 0) + use
                allocated[cid] = (allocated[cid] or 0) + use
            end
            if use < need then
                local craftable = ect[cid] and (ect[cid].Components or 0) > 0
                if craftable then
                    recurse(cid)
                end
            end
        end
    end

    recurse(targetId)
    return totalCost, consume
end

M.handlers.equip_synthesis = function(data, obj, localdata)
    local targetId = obj._equip_id
    local ect = ed.getDataTable("equipcraft")
    local row = ect and ect[targetId]

    if not row then
        data._equip_synthesis_reply = { _result = "fail" }
        return
    end

    local totalCost, consume = collectCraftChain(targetId)

    -- 检查金币
    if totalCost > (ed.player._money or 0) then
        data._equip_synthesis_reply = { _result = "fail" }
        return
    end

    -- 检查基础材料是否足够
    for cid, amount in pairs(consume) do
        local have = ed.player.equip_qunty[cid] or 0
        if have < amount then
            data._equip_synthesis_reply = { _result = "fail" }
            return
        end
    end

    -- 执行合成：扣除材料、金币，产出目标
    pcall(function()
        ed.player:addMoney(-totalCost)
        for cid, amount in pairs(consume) do
            ed.player:consumeEquip(cid, amount)
        end
        ed.player:addEquip(targetId)
        ed.saveDirty = true
    end)

    -- 更新 netdata 让客户端回复处理正确
    if ed.netdata then
        ed.netdata.equipCraft = {
            id = targetId,
            node = {},
            consume = {},
            expense = totalCost,
        }
        local i = 1
        for cid, amount in pairs(consume) do
            ed.netdata.equipCraft.node[i] = cid
            ed.netdata.equipCraft.consume[i] = amount
            i = i + 1
        end
    end

    data._equip_synthesis_reply = {
        _result = "success",
    }
end

-- ========== wear_equip ==========
-- obj: { _tid = hero_tid, _slot = slot_index, _equip_id = equip_id }
M.handlers.wear_equip = function(data, obj, localdata)
    local tid = obj._hero_id or obj._tid
    local slot = obj._item_pos or obj._slot

    local hero = ed.player and ed.player.heroes[tid]

    if not hero then
        data._wear_equip_reply = {
            _result = "fail",
            _gs = 0,
        }
        return
    end

    local curGs = hero._gs or 0
    local delta = 0
    pcall(function()
        local equipTable = ed.getDataTable("hero_equip")
        local equipDataTable = ed.getDataTable("equip")
        local rank = hero._rank or 1
        local rankEquip = equipTable and equipTable[tid] and equipTable[tid][rank]
        if rankEquip and slot then
            local newItemId = rankEquip[string.format("Equip%d ID", slot)]
            if newItemId and equipDataTable and equipDataTable[newItemId] then
                local equipLevel = rankEquip.EquipLevel or 1
                delta = (tonumber(equipDataTable[newItemId]["GS"]) or 0) * equipLevel
            end
        end
    end)
    local gs = math.max(math.floor(curGs + delta), 0)

    data._wear_equip_reply = {
        _result = "success",
        _gs = gs,
    }
    pcall(function() ed.saveDirty = true end)
end

-- ========== shop_refresh ==========
-- obj: 刷新商店请求
local function generateShopGoods(shopId)
    shopId = shopId or 1
    local goods = {}
    local equipIds = {}
    pcall(function()
        local equipTable = ed.getDataTable("equip")
        if equipTable then
            for eid, row in pairs(equipTable) do
                if type(eid) == "number" then
                    equipIds[#equipIds + 1] = eid
                end
            end
        end
    end)
    if #equipIds == 0 then
        equipIds = {101, 102, 103, 104, 105, 106, 107, 108, 109, 110}
    end
    local shuffled = {}
    for _, id in ipairs(equipIds) do shuffled[#shuffled + 1] = id end
    for i = #shuffled, 2, -1 do
        local j = math.random(1, i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    local payTypeMap = { [3] = "diamond", [4] = "crusadepoint", [5] = "arenapoint", [6] = "guildpoint" }
    local payType = payTypeMap[shopId] or "gold"
    local priceMul = (shopId == 2) and 0.6 or (shopId == 3) and 2.0 or 1.0
    for i = 1, math.min(6, #shuffled) do
        local price = 100
        pcall(function()
            local equipTable = ed.getDataTable("equip")
            if equipTable and equipTable[shuffled[i]] then
                price = tonumber(equipTable[shuffled[i]]["Price"]) or math.random(50, 500)
            end
        end)
        price = math.floor(price * priceMul)
        if price < 10 then price = 10 end
        goods[i] = {
            _id = shuffled[i],
            _type = payType,
            _price = price,
            _amount = 1,
            _is_sale = (shopId == 2),
        }
    end
    return goods
end

M.handlers.shop_refresh = function(data, obj, localdata)
    local shopId = (obj and obj._shop_id) or (obj and obj._id) or 1
    local goods = generateShopGoods(shopId)
    -- 存储商品数据供 shop_consume 查找
    localdata.shop_data = localdata.shop_data or {}
    local slotMap = {}
    for i, g in ipairs(goods) do
        slotMap[i] = g
    end
    localdata.shop_data[shopId] = slotMap
    LocalData.save(localdata)
    data._shop_refresh_reply = {
        _id = shopId,
        _last_auto_refresh_time = getTimestamp(),
        _expire_time = 0,
        _last_manual_refresh_time = getTimestamp(),
        _today_times = 0,
        _current_goods = goods,
    }
end

-- ========== shop_consume ==========
-- obj: 购买商品请求
M.handlers.shop_consume = function(data, obj, localdata)
    local shopId = obj._sid or 1
    local slotId = obj._slotid
    local shopData = localdata.shop_data and localdata.shop_data[shopId]
    local goodsItem = shopData and shopData[slotId]

    if not goodsItem then
        data._shop_consume_reply = { _result = "fail" }
        return
    end

    local payType = goodsItem._type
    local price = goodsItem._price or 0
    local amount = obj._amount or 1
    local totalCost = price * amount

    -- 余额检查使用运行时 ed.player（localdata.player.money/rmb 可能为 nil）
    local playerMoney = (ed.player and ed.player._money) or 0
    local playerRmb = (ed.player and ed.player._rmb) or 0
    local function getPoint(pt)
        return ed.player and ed.player:getPoint(pt) or 0
    end
    if payType == "gold" then
        if playerMoney < totalCost then
            data._shop_consume_reply = { _result = "fail" }
            return
        end
    elseif payType == "diamond" then
        if playerRmb < totalCost then
            data._shop_consume_reply = { _result = "fail" }
            return
        end
    elseif payType == "crusadepoint" or payType == "arenapoint" or payType == "guildpoint" then
        if getPoint(payType) < totalCost then
            data._shop_consume_reply = { _result = "fail" }
            return
        end
    end

    -- 实际扣费和物品添加由客户端回调（shop.lua buyReply）处理
    -- 服务端只做校验和标记售罄

    -- 商品售罄
    goodsItem._amount = 0
    LocalData.save(localdata)

    -- 追踪钻石消费
    if payType == "diamond" and totalCost > 0 then
        trackDiamondSpent(localdata, totalCost)
    end

    data._shop_consume_reply = { _result = "success" }
    pcall(function() ed.saveDirty = true end)
end

-- ========== shop_star_consume ==========
-- obj: 星际商店购买
M.handlers.shop_star_consume = function(data, obj, localdata)
    local slot = obj._star_goods_slot
    local sshop = localdata.player._sshop
    if sshop and sshop._star_goods and sshop._star_goods[slot] then
        local good = sshop._star_goods[slot]
        if good._amount > 0 then
            good._amount = 0
            LocalData.save(localdata)
        end
    end
    data._shop_star_consume_reply = { _result = "success" }
end

-- ========== open_shop ==========
-- obj: { _shopid = N }
M.handlers.open_shop = function(data, obj, localdata)
    local shopId = obj._shopid or 1
    local goods = generateShopGoods(shopId)
    localdata.shop_data = localdata.shop_data or {}
    local slotMap = {}
    for i, g in ipairs(goods) do
        slotMap[i] = g
    end
    localdata.shop_data[shopId] = slotMap
    LocalData.save(localdata)
    data._open_shop_reply = {
        _result = "success",
        _shop = {
            _id = shopId,
            _last_auto_refresh_time = getTimestamp(),
            _expire_time = 0,
            _last_manual_refresh_time = getTimestamp(),
            _today_times = 0,
            _current_goods = goods,
        },
    }
end

-- ========== skill_levelup ==========
-- 实际消息格式: _heroid = hero_tid, _order = packed skill orders
-- packed order: ed.makebits(11, amount, 4, slot)
M.handlers.skill_levelup = function(data, obj, localdata)
    local tid = obj._heroid or obj._tid
    local hero = ed.player and ed.player.heroes[tid]

    if hero then
        -- 只计算 gs 增量，不修改 _skill_levels
        -- dealSkillLevelup 会通过 strenHeroSkill 处理技能等级
        local totalUpgrades = 0
        local orders = obj._order or {}
        for i, packed in ipairs(orders) do
            local amount = ed.bits(packed, 0, 4)
            totalUpgrades = totalUpgrades + (amount or 1)
        end
        if totalUpgrades == 0 and obj._skill_index then
            totalUpgrades = 1
        end
        hero._gs = (hero._gs or 0) + totalUpgrades * 10

        data._skill_levelup_reply = {
            _result = "success",
            _gs = hero._gs,
        }
    else
        data._skill_levelup_reply = {
            _result = "fail",
            _gs = 0,
        }
    end
end

-- ========== sell_item ==========
-- obj: 出售物品请求
M.handlers.sell_item = function(data, obj, localdata)
    data._sell_item_reply = {
        _result = "success",
    }
end

-- ========== fragment_compose ==========
-- obj: 碎片合成请求
M.handlers.fragment_compose = function(data, obj, localdata)
    data._fragment_compose_reply = {
        _result = "success",
    }
end

-- ========== hero_equip_upgrade ==========
-- obj: { _tid = hero_tid, _slot = N }
M.handlers.hero_equip_upgrade = function(data, obj, localdata)
    local tid = obj._tid or obj._hero_id
    local hero = ed.player and ed.player.heroes[tid]

    if hero then
        data._hero_equip_upgrade_reply = {
            _result = "success",
            _hero = {
                _tid = tid,
                _rank = hero._rank or 1,
                _level = hero._level or 1,
                _stars = hero._stars or 1,
                _exp = hero._exp or 0,
                _gs = hero._gs or 0,
                _state = "idle",
                _skill_levels = hero._skill_levels or {1,1,1,1},
                _items = hero._items or {},
            },
        }
    else
        data._hero_equip_upgrade_reply = {
            _result = "fail",
        }
    end
    pcall(function() ed.saveDirty = true end)
end

-- ========== trigger_task ==========
M.handlers.trigger_task = function(data, obj, localdata)
    -- 解析触发的任务并保存到 localdata
    if obj and obj._task then
        local lt = localdata.task or {}
        for i, packed in ipairs(obj._task) do
            local chain, id = ed.splitbits(packed, 16, 16)
            -- 移除该链旧任务
            for j = #lt, 1, -1 do
                if lt[j].chain == chain then
                    table.remove(lt, j)
                end
            end
            -- 添加新任务
            table_insert(lt, { chain = chain, id = id, status = "working", target = 0 })
        end
        localdata.task = lt
        LocalData.save(localdata)
    end
    data._trigger_task_reply = {
        _result = { "success" },
    }
end

-- ========== require_rewards ==========
M.handlers.require_rewards = function(data, obj, localdata)
    local chain = obj and obj._line
    local id = obj and obj._id
    if not chain or not id then
        data._require_rewards_reply = { _result = "fail" }
        return
    end

    local taskTable = ed.getDataTable("Task")
    if not taskTable or not taskTable[chain] or not taskTable[chain][id] then
        data._require_rewards_reply = { _result = "fail" }
        return
    end

    local row = taskTable[chain][id]

    -- 发放奖励
    local rType = row["Task Reward Type"]
    local rId = row["Task Reward ID"]
    local rAmount = row["Task Reward Amount"]
    if rType and rAmount and rAmount > 0 then
        if rType == "Coin" then
            if ed.player and ed.player.addMoney then ed.player:addMoney(rAmount, true) end
        elseif rType == "Diamond" then
            if ed.player and ed.player.addrmb then ed.player:addrmb(rAmount) end
        elseif rType == "Vitality" then
            if ed.player and ed.player.addVitality then ed.player:addVitality(rAmount) end
        elseif rType == "PlayerEXP" then
            if ed.player and ed.player.addExp then ed.player:addExp(rAmount) end
        elseif rType == "Item" then
            if ed.player and ed.player.addEquip then ed.player:addEquip(rId, rAmount) end
        end
    end

    -- 消耗类任务处理
    if row["Task Need Consume"] then
        local cType = row["Task Consume Type"]
        local cId = row["Task Consume ID"]
        local cAmount = row["Task Consume Amount"]
        if cType == "Coin" and ed.player and ed.player.addMoney then
            ed.player:addMoney(-cAmount, true)
        elseif cType == "Diamond" and ed.player and ed.player.addrmb then
            ed.player:addrmb(-cAmount)
        elseif cType == "Item" and ed.player and ed.player.addEquip then
            ed.player:addEquip(cId, -cAmount)
        end
    end

    -- 更新 localdata 任务状态
    local lt = localdata.task or {}
    for i, t in ipairs(lt) do
        if t.chain == chain and t.id == id then
            t.status = "finished"
            break
        end
    end
    -- 如果是该链最后一个任务，加入 task_finished
    local taskTable2 = ed.getDataTable("Task")
    if not taskTable2[chain] or not taskTable2[chain][id + 1] then
        local tf = localdata.task_finished or {}
        local alreadyFinished = false
        for _, v in ipairs(tf) do
            if v == chain then alreadyFinished = true; break end
        end
        if not alreadyFinished then
            table_insert(tf, chain)
        end
        localdata.task_finished = tf
    end
    localdata.task = lt
    LocalData.save(localdata)

    data._require_rewards_reply = { _result = "success" }
end

-- ========== reset_elite ==========
-- obj: 重置精英关卡
M.handlers.reset_elite = function(data, obj, localdata)
    data._reset_elite_reply = {
        _result = "success",
    }
end

-- ========== sweep_stage ==========
-- obj: { _stage_id = N, ... }
M.handlers.sweep_stage = function(data, obj, localdata)
    local stage_id = obj._stageid or obj._stage_id or 0
    local times = obj._times or 1
    local expReward, moneyReward = getStageRewards(stage_id)
    local sweepLoot = {}
    M.sweep_loot_record = M.sweep_loot_record or {}
    local key = tostring(stage_id)
    M.sweep_loot_record[key] = M.sweep_loot_record[key] or {}

    for t = 1, times do
        local loot = {
            _exp = expReward,
            _money = moneyReward,
            _items = {},
        }
        local StageTable = ed.getDataTable("Stage")
        if StageTable and StageTable[stage_id] then
            local stageCfg = StageTable[stage_id]
            for i = 1, 7 do
                local rewardId = stageCfg["UI reward" .. i]
                if rewardId and rewardId ~= 0 then
                    local basePro = stageCfg["UI reward" .. i .. " Pro"] or 34
                    local rKey = tostring(rewardId)
                    local missCount = M.sweep_loot_record[key][rKey] or 0
                    local lootPro
                    if missCount == 0 then
                        lootPro = basePro
                    else
                        lootPro = basePro * missCount
                    end
                    lootPro = math.min(lootPro, 100)
                    if math_random(1, 100) <= lootPro then
                        table_insert(loot._items, ed.makebits(11, 1, 10, rewardId))
                        M.sweep_loot_record[key][rKey] = 0
                    else
                        M.sweep_loot_record[key][rKey] = missCount + 1
                    end
                end
            end
        end
        table_insert(sweepLoot, loot)
    end

    -- Raid Bonus（扫荡额外奖励，按次数倍增）
    local bonusItems = {}
    local StageTable = ed.getDataTable("Stage")
    if StageTable and StageTable[stage_id] then
        local stageCfg = StageTable[stage_id]
        for i = 1, 4 do
            local bType = stageCfg["Raid Bonus Type " .. i]
            local bId = stageCfg["Raid Bonus ID " .. i] or 0
            local bAmt = stageCfg["Raid Bonus Amount " .. i] or 0
            if bType == "Item" and bId ~= 0 and bAmt > 0 then
                local totalAmt = bAmt * times
                table_insert(bonusItems, ed.makebits(11, totalAmt, 10, bId))
            end
        end
    end

    data._sweep_stage_reply = {
        _loot = sweepLoot,
        _items = bonusItems,
    }
end

-- ========== ask_magicsoul ==========
-- 查询魂匣英雄列表，返回英雄ID数组
M.handlers.ask_magicsoul = function(data, obj, localdata)
    -- 返回随机英雄ID列表（1-30范围）
    local heroIds = {}
    for i = 1, 6 do
        table_insert(heroIds, math_random(1, 30))
    end
    -- 第一个是每日特别英雄
    heroIds[1] = math_random(1, 15)
    data._ask_magicsoul_reply = heroIds
end

-- ========== tavern_draw ==========
-- obj: { _draw_type = 0/1(draw_type enum), _box_type = 1-7(box_type enum) }
M.handlers.tavern_draw = function(data, obj, localdata)
    local drawType = obj._draw_type or 0
    local boxType = obj._box_type or 1
    LegendLog("[local_server] tavern_draw: drawType=" .. tostring(drawType) .. " boxType=" .. tostring(boxType))
    local itemIds = {}
    local newHeroes = {}

    -- starshop 灵魂石购买：drawType="stone", boxType="stone_green"/"stone_blue"/"stone_purple"
    if drawType == "stone" then
        local qualityMap = {
            stone_green = {1, 2, 3},
            stone_blue = {3, 4, 5},
            stone_purple = {4, 5, 6},
        }
        local qualities = qualityMap[boxType] or {1, 2, 3}
        local validEquips = {}
        pcall(function()
            local equipTable = ed.getDataTable("equip")
            if equipTable then
                for k, v in pairs(equipTable) do
                    if type(k) == "number" and v.Icon then
                        local q = v.Quality or 1
                        for _, tq in ipairs(qualities) do
                            if q == tq then
                                table_insert(validEquips, k)
                                break
                            end
                        end
                    end
                end
            end
        end)
        if #validEquips == 0 then validEquips = {101} end
        for i = 1, 3 do
            local eid = validEquips[math_random(1, #validEquips)]
            table_insert(itemIds, ed.makebits(11, math_random(1, 3), 10, eid))
        end
        data._tavern_draw_reply = {
            _item_ids = itemIds,
            _new_heroes = newHeroes,
            _smash_idx = {},
        }
        return
    end

    -- drawType: 0=single, 1=combo(10x)
    -- boxType: 1=green(bronze), 2=blue(silver), 3=purple(gold), 4=magicsoul
    -- 简单掉落模拟：根据箱子品质给不同品质的物品
    local drawCount = 1
    if drawType == 1 then
        drawCount = 10
    end

    -- 收集有效的 equip ID 和 hero ID
    local validEquipIds = {}
    local validHeroIds = {}
    pcall(function()
        local equipTable = ed.getDataTable("equip")
        if equipTable then
            for k, v in pairs(equipTable) do
                if type(k) == "number" and v.Icon then
                    table_insert(validEquipIds, k)
                end
            end
        end
        local unitTable = ed.getDataTable("Unit")
        if unitTable then
            for k, v in pairs(unitTable) do
                if type(k) == "number" and v.Portrait and v["Unit Type"] == "Hero" then
                    table_insert(validHeroIds, k)
                end
            end
        end
    end)
    -- fallback：如果数据表为空，用硬编码的安全ID
    if #validEquipIds == 0 then
        validEquipIds = {101}
    end
    if #validHeroIds == 0 then
        validHeroIds = {1, 2, 3, 4, 5}
    end

    for i = 1, drawCount do
        local equipId = validEquipIds[math_random(1, #validEquipIds)]
        table_insert(itemIds, ed.makebits(11, 1, 10, equipId))
    end

    -- 小概率给英雄碎片
    if math_random(1, 10) <= 3 then
        local heroId = validHeroIds[math_random(1, #validHeroIds)]
        table_insert(itemIds, ed.makebits(11, math_random(1, 3), 10, heroId))
    end

    data._tavern_draw_reply = {
        _item_ids = itemIds,
        _new_heroes = newHeroes,
        _smash_idx = {},
    }

    -- 追踪钻石消费
    local td = ed.getDataTable("TavernDrawConfig")
    if td then
        local costInfo = td[boxType]
        if costInfo and drawType == 0 then
            local diamondCost = costInfo["Draw 1 Cost Diamond"] or 0
            if diamondCost > 0 then trackDiamondSpent(localdata, diamondCost) end
        elseif costInfo and drawType == 1 then
            local diamondCost = costInfo["Draw 10 Cost Diamond"] or 0
            if diamondCost > 0 then trackDiamondSpent(localdata, diamondCost) end
        end
    end
end

-- ========== sync_vitality ==========
M.handlers.sync_vitality = function(data, obj, localdata)
    data._sync_vitality_reply = {
        _vitality = buildVitality(localdata.vitality),
    }
end

-- ========== buy_vitality ==========
M.handlers.buy_vitality = function(data, obj, localdata)
    local cost = 50
    if localdata.player.diamond >= cost then
        localdata.player.diamond = localdata.player.diamond - cost
        localdata.vitality.current = math.min((localdata.vitality.current or 0) + 120, 9999)
        localdata.vitality.todaybuy = (localdata.vitality.todaybuy or 0) + 1
        LocalData.save(localdata)
    end

    data._sync_vitality_reply = {
        _vitality = buildVitality(localdata.vitality),
    }
    pcall(function() ed.saveDirty = true end)
end

-- ========== tutorial ==========
-- obj: { _step = N, ... }
M.handlers.tutorial = function(data, obj, localdata)
    data._tutorial_reply = {
        _result = "success",
    }
end

-- ========== set_name ==========
-- obj: { _name = "xxx" }
M.handlers.set_name = function(data, obj, localdata)
    local name = obj._name
    if name and name ~= "" then
        localdata.player.name = name
        LocalData.save(localdata)
        data._set_name_reply = {
            _result = "success",
        }
    else
        data._set_name_reply = {
            _result = "success",  -- 客户端已校验
        }
    end
    pcall(function() ed.saveDirty = true end)
end

-- ========== set_avatar ==========
-- obj: { _avatar = N }
M.handlers.set_avatar = function(data, obj, localdata)
    if obj._avatar then
        localdata.player.avatar = obj._avatar
        LocalData.save(localdata)
    end
    data._set_avatar_reply = {
        _result = "success",
    }
end

-- ========== midas ==========
-- obj: { _times = N }
M.handlers.midas = function(data, obj, localdata)
    local times = obj._times or 1

    local gt = ed.getDataTable("GradientPrice")
    local plt = ed.getDataTable("PlayerLevel")
    local mt = ed.getDataTable("Midas")

    local playerRmb = (ed.player and ed.player._rmb) or 0
    local acquireList = {}
    local totalCost = 0
    local midasTimes = 0
    if ed.player and ed.player.getMidasTimes then
        midasTimes = ed.player:getMidasTimes() or 0
    end
    local playerLevel = 1
    if ed.player and ed.player.getLevel then
        playerLevel = ed.player:getLevel() or 1
    end

    for i = 1, times do
        local costIdx = midasTimes + i
        local costEntry = gt and gt[costIdx] or {}
        totalCost = totalCost + (costEntry.Midas or 0)

        local yieldEntry = mt and mt[costIdx] or {}
        local yieldRate = yieldEntry["Yield 1"] or 1
        local levelEntry = plt and plt[playerLevel] or {}
        local baseMoney = levelEntry["Midas Money"] or 5000
        local moneyGain = math.floor(baseMoney * yieldRate)

        table_insert(acquireList, {
            _type = 1,
            _money = moneyGain,
        })
    end

    LegendLog("[midas] times=" .. times .. " cost=" .. totalCost .. " rmb=" .. playerRmb .. " acquire=" .. #acquireList)

    if playerRmb < totalCost then
        data._midas_reply = { _acquire = {} }
        return
    end

    -- 追踪钻石消费
    if totalCost > 0 then trackDiamondSpent(localdata, totalCost) end

    data._midas_reply = {
        _acquire = acquireList,
    }
end

-- ========== query_data ==========
-- obj: 查询增量数据
M.handlers.query_data = function(data, obj, localdata)
    data._query_data_reply = {
        heroes = {},
        recharge_limit = {},
        _month_card = {},
    }
end

-- ========== gm_cmd ==========
-- obj: GM 命令，包含各种 _set_* / _unlock_* / _get_* 字段
M.handlers.gm_cmd = function(data, obj, localdata)
    LegendLog("[gm_cmd] === START ===")
    LegendLog("[gm_cmd] obj type: " .. type(obj))
    LegendLog("[gm_cmd] obj._set_money: " .. tostring(obj._set_money))
    LegendLog("[gm_cmd] obj._unlock_all_stages: " .. tostring(obj._unlock_all_stages))
    LegendLog("[gm_cmd] obj._get_all_heroes: " .. tostring(obj._get_all_heroes))
    LegendLog("[gm_cmd] obj._set_vitality: " .. tostring(obj._set_vitality))
    LegendLog("[gm_cmd] obj._set_player_level: " .. tostring(obj._set_player_level))

    -- 解锁所有关卡
    if obj._unlock_all_stages and obj._unlock_all_stages > 0 then
        localdata.stage.max_normal = 9999
        local StageTable = ed.getDataTable("Stage")
        local count = 0
        if StageTable then
            for sid, row in pairs(StageTable) do
                if type(sid) == "number" and sid > 0 then
                    local ch = row["Chapter ID"]
                    if type(ch) == "number" and ch >= 1 and ch <= 14 then
                        local sType = ed.stageType(sid)
                        if sType == "normal" then
                            localdata.stage.normal_stars[sid] = 3
                        elseif sType == "elite" then
                            localdata.stage.elite_stars[sid] = 3
                        end
                        count = count + 1
                    end
                end
            end
        end
        localdata.player.level = 80
        LegendLog("[gm_cmd] unlock_all_stages done, count=" .. count)
    end

    -- 获取所有英雄
    if obj._get_all_heroes and obj._get_all_heroes > 0 then
        local UnitTable = ed.getDataTable("Unit")
        if UnitTable then
            local existingTids = {}
            for _, h in ipairs(localdata.heroes) do
                existingTids[h.tid] = true
            end
            for tid, unit in pairs(UnitTable) do
                if type(tid) == "number" and tid > 0 and not existingTids[tid]
                    and unit["Unit Type"] == "Hero" and unit.Portrait then
                    table_insert(localdata.heroes, {
                        tid = tid,
                        rank = 1,
                        level = 1,
                        stars = 1,
                        exp = 0,
                        gs = 100,
                        state = "idle",
                        skill_levels = {1,1,1,1},
                    })
                end
            end
        end
    end

    -- 设置英雄信息
    if obj._set_hero_info then
        for _, heroMsg in ipairs(obj._set_hero_info) do
            local tid = heroMsg._tid
            if tid then
                local hero = ed.player and ed.player.heroes[tid]
                if hero then
                    if heroMsg._rank then hero._rank = heroMsg._rank end
                    if heroMsg._level then hero._level = heroMsg._level end
                    if heroMsg._stars then hero._stars = heroMsg._stars end
                    if heroMsg._exp then hero._exp = heroMsg._exp end
                    if heroMsg._gs then hero._gs = heroMsg._gs end
                end
            end
        end
    end

    -- 设置体力
    if obj._set_vitality then
        localdata.vitality.current = obj._set_vitality
    end

    -- 设置金币/钻石/远征币/竞技场币
    -- GM 发送格式: _type="gold"/"diamond"/"crusadepoint"/"arenapoint", _amount=N
    if obj._set_money then
        local sm = obj._set_money
        LegendLog("[gm_cmd] _set_money present, _type=" .. tostring(sm._type) .. " _amount=" .. tostring(sm._amount))
        local moneyType = sm._type
        local amount = sm._amount
        if moneyType and amount then
            if moneyType == "gold" then
                localdata.player.gold = amount
                LegendLog("[gm_cmd] set gold = " .. tostring(amount))
            elseif moneyType == "diamond" then
                localdata.player.diamond = amount
                LegendLog("[gm_cmd] set diamond = " .. tostring(amount))
            elseif moneyType == "crusadepoint" then
                localdata.player.crusade_point = amount
            elseif moneyType == "arenapoint" then
                localdata.player.arena_point = amount
            end
        end
        -- 兼容旧格式 _money / _rmb
        if obj._set_money._money then
            localdata.player.gold = obj._set_money._money
        end
        if obj._set_money._rmb then
            localdata.player.diamond = obj._set_money._rmb
        end
    end

    -- 设置累计充值
    if obj._set_recharge_sum then
        localdata.player.recharge_sum = obj._set_recharge_sum
    end

    -- 设置玩家等级
    if obj._set_player_level then
        localdata.player.level = obj._set_player_level
    end

    -- 设置玩家经验
    if obj._set_player_exp then
        localdata.player.exp = obj._set_player_exp
    end

    -- 设置物品
    if obj._set_items then
        for _, itemBits in ipairs(obj._set_items) do
            local id = ed.bits(itemBits, 0, 10)
            local amount = ed.bits(itemBits, 10, 11)
            localdata.items[id] = amount
        end
    end

    -- 删号重练
    if obj._reset_device and obj._reset_device > 0 then
        localdata = LocalData.reset()
        M.data = localdata
    end

    -- 打开神秘商店
    if obj._open_mystery_shop then
        -- 不需要额外处理，通过 _reset 返回数据即可
    end

    -- 重置精英扫荡次数
    if obj._reset_sweep and obj._reset_sweep > 0 then
        localdata.stage.sweep_today_free = 0
    end

    -- 设置连续登陆天数
    if obj._set_dailylogin_days then
        localdata.daily_login.frequency = obj._set_dailylogin_days
    end

    -- 清理非 Hero 类型的英雄（旧存档可能混入了怪物/召唤物）
    local UnitTable = ed.getDataTable("Unit")
    if UnitTable then
        local i = 1
        while i <= #localdata.heroes do
            local h = localdata.heroes[i]
            local u = UnitTable[h.tid]
            if u and (u["Unit Type"] ~= "Hero" or not u.Portrait) then
                table.remove(localdata.heroes, i)
            else
                i = i + 1
            end
        end
    end

    LocalData.save(localdata)

    -- GM 命令返回 _reset（完整 user 数据）
    local user = buildUser(localdata)
    LegendLog("[gm_cmd] built user: _money=" .. tostring(user._money) .. " _rmb=" .. tostring(user._rmb) .. " _level=" .. tostring(user._level))
    data._reset = {
        _user = user,
    }
    LegendLog("[gm_cmd] data._reset set, _reset._user=" .. tostring(data._reset and data._reset._user))
    LegendLog("[gm_cmd] === END ===")
end

-- ========== ask_daily_login ==========
M.handlers.ask_daily_login = function(data, obj, localdata)
    local status = (obj and obj._status) or 2  -- 1=all, 2=common, 3=vip

    -- 防重复领取
    local rewardStatus = ed.player and ed.player.getLoginRewardStatus and ed.player:getLoginRewardStatus()
    if rewardStatus == "received" then
        data._ask_daily_login_reply = {
            _result = "fail", _items = {}, _hero = {}, _diamond = 0,
        }
        return
    end

    -- 获取签到天数对应的奖励
    local frq = 1
    if ed.player and ed.player.getLoginFrequency then
        frq = ed.player:getLoginFrequency() or 1
    end

    -- 数据表可能只有旧年份，取当前月份对应的数据
    local dlTable = ed.getDataTable("DailyLoginReward")
    local date = ed.serverTime2China and ed.serverTime2China() or os.time()
    local ymd = ed.getYMDHMS and ed.getYMDHMS(date) or os.date("*t", date)
    local m = tonumber(ymd.month)
    local d = frq  -- 按连续签到天数取奖励

    -- 尝试当前年，再尝试 2018
    local row
    for _, tryYear in ipairs({tonumber(ymd.year), 2018}) do
        if dlTable[tryYear] and dlTable[tryYear][m] and dlTable[tryYear][m][d] then
            row = dlTable[tryYear][m][d]
            break
        end
    end

    if not row then
        data._ask_daily_login_reply = {
            _result = "fail",
            _items = {},
            _hero = {},
            _diamond = 0,
        }
        return
    end

    local rewardType = row["Reward Type"]
    local rewardId = row["Reward ID"]
    local rewardAmount = row["Reward Amount"]
    local vipRequired = row["Double Reward VIP Level"] or 0
    local playerVip = (ed.player and ed.player.getvip and ed.player:getvip()) or 0

    local items = {}
    local heroes = {}
    local diamond = 0

    -- 计算倍率
    local multiplier = 1
    if status == 1 and vipRequired > 0 and playerVip >= vipRequired then
        multiplier = 2  -- VIP双倍
    end

    if rewardType == "Item" then
        table_insert(items, ed.makebits(11, rewardAmount * multiplier, 10, rewardId))
    elseif rewardType == "Hero" then
        table_insert(heroes, {_tid = rewardId})
    elseif rewardType == "Diamond" then
        diamond = rewardAmount * multiplier
        if ed.player and ed.player.addrmb then
            ed.player:addrmb(diamond)
        end
    elseif rewardType == "Gold" then
        if ed.player and ed.player.addMoney then
            ed.player:addMoney(rewardAmount * multiplier, true)
        end
    elseif rewardType == "PlayerEXP" then
        if ed.player and ed.player.addExp then
            ed.player:addExp(rewardAmount * multiplier)
        end
    end

    data._ask_daily_login_reply = {
        _result = "success",
        _items = items,
        _hero = heroes,
        _diamond = diamond,
    }
end

-- ========== buy_skill_stren_point ==========
M.handlers.buy_skill_stren_point = function(data, obj, localdata)
    localdata.skill.chance = (localdata.skill.chance or 0) + 10
    localdata.skill.reset_times = (localdata.skill.reset_times or 0) + 1
    LocalData.save(localdata)

    data._sync_skill_stren_reply = {
        _skill_level_up = buildSkillLevelUp(localdata.skill),
    }
    pcall(function() ed.saveDirty = true end)
end

-- ========== sync_skill_stren ==========
M.handlers.sync_skill_stren = function(data, obj, localdata)
    data._sync_skill_stren_reply = {
        _skill_level_up = buildSkillLevelUp(localdata.skill),
    }
end

-- ========== system_setting_reply (空响应) ==========
M.handlers.system_setting = function(data, obj, localdata)
    data._system_setting_reply = {}
end

-- ========== sdk_login ==========
M.handlers.sdk_login = function(data, obj, localdata)
    data._sdk_login_reply = {
        _result = "success",
        _uin = tostring(localdata.player.userid or 1),
    }
end

-----------------------------------------------------------------------
-- NPC 名称（排行榜/竞技场共用）
-----------------------------------------------------------------------
local AI_NAMES = {
    "暗影猎手","龙骑士","风暴法师","圣光骑士","血魔领主",
    "冰霜女王","烈焰术士","大地守卫","幽灵刺客","雷霆战神",
    "月光游侠","黑暗领主","星辰法师","铁甲战士","毒蛇猎手",
}

-----------------------------------------------------------------------
-- 排行榜查询
-----------------------------------------------------------------------
M.handlers.query_ranklist = function(data, obj, localdata)
    local rankType = obj._rank_type or "top_gs"
    local npcNames = AI_NAMES
    local guildNames = {"暗影军团","龙骑联盟","风暴之翼","圣光骑士团","血魔殿",
        "冰霜堡垒","烈焰公会","大地之盾","幽灵暗杀","雷霆战队",
        "月光森林","黑暗帝国","星辰学院","铁甲军团","毒蛇巢穴"}

    -- 计算玩家自身分数（基于实际英雄数据）
    local playerLevel = localdata.player.level or 1
    local totalGs = 0
    local heroCount = 0
    local topHeroGs = {}
    local totalStars = 0
    local totalArousal = 0
    pcall(function()
        for tid, hero in pairs(ed.player.heroes or {}) do
            local gs = hero._gs or 0
            totalGs = totalGs + gs
            heroCount = heroCount + 1
            table.insert(topHeroGs, gs)
            totalStars = totalStars + (hero._stars or 0)
            totalArousal = totalArousal + (hero._rank or 0)
        end
    end)
    table.sort(topHeroGs, function(a, b) return a > b end)
    local top5Gs = 0
    local top15Gs = 0
    for i, gs in ipairs(topHeroGs) do
        if i <= 5 then top5Gs = top5Gs + gs end
        if i <= 15 then top15Gs = top15Gs + gs end
    end

    local selfParam = 0
    if rankType == "top_gs" then
        selfParam = top15Gs
    elseif rankType == "full_hero_gs" then
        selfParam = totalGs
    elseif rankType == "hero_team_gs" then
        selfParam = top5Gs
    elseif rankType == "hero_evo_star" then
        selfParam = totalStars
    elseif rankType == "hero_arousal" then
        selfParam = totalArousal
    else
        selfParam = math.floor(totalGs * 0.1)
    end

    -- 根据玩家实际战力范围生成NPC数据
    local baseScale = math.max(selfParam, 100)
    local items = {}
    for i = 1, 20 do
        local ni = ((i - 1) % #npcNames) + 1
        local lvl = math.max(playerLevel + 5 - i, 5)
        local param = math.floor(baseScale * (1.5 - i * 0.06))
        if param < 10 then param = 10 end

        local item
        if rankType == "guildliveness" then
            item = {
                _guild_summary = {
                    _avatar = ((i - 1) % 5) + 1,
                    _name = guildNames[ni],
                    _president = { _name = npcNames[ni] },
                },
                _param1 = math.max(3000 - i * 120, 100),
            }
        else
            item = {
                _user_summary = {
                    _avatar = (i % 10) + 1,
                    _vip = 0,
                    _name = npcNames[ni],
                    _level = lvl,
                },
                _param1 = param,
            }
        end
        table_insert(items, item)
    end

    -- 计算玩家排名
    local selfRank = 0
    for i, item in ipairs(items) do
        if selfParam >= item._param1 then
            selfRank = i
            break
        end
    end
    if selfRank == 0 then selfRank = #items + 1 end

    data._query_ranklist_reply = {
        _rank_type = rankType,
        _ranklist_item = items,
        _self_ranking = selfRank,
        _self_prev_pos = selfRank,
        _self_item = {
            _user_summary = {
                _avatar = localdata.player.avatar or 1,
                _vip = 0,
                _name = localdata.player.name or "Player",
                _level = playerLevel,
            },
            _param1 = selfParam,
        },
    }
end

-----------------------------------------------------------------------
-- 竞技场排行榜 (top_arena)
-----------------------------------------------------------------------
M.handlers.top_arena = function(data, obj, localdata)
    local npcNames = AI_NAMES
    local rankList = {}
    for i = 1, 20 do
        local ni = ((i - 1) % #npcNames) + 1
        table_insert(rankList, {
            _summary = {
                _avatar = (i % 10) + 1,
                _vip = 0,
                _name = npcNames[ni],
                _level = math.max(60 - i * 2, 10),
            },
        })
    end

    local playerLevel = localdata.player.level or 1
    local pvp = localdata.player._pvp
    local pvpRank = (pvp and pvp.rank) or 1001
    data._top_arena_reply = {
        _rank_list = rankList,
        _pos = pvpRank,
        _prev_pos = pvpRank,
        _self_rank = {
            _summary = {
                _avatar = localdata.player.avatar or 1,
                _vip = 0,
                _name = localdata.player.name or "Player",
                _level = playerLevel,
            },
        },
    }
end

-----------------------------------------------------------------------
-- TBC (远征/十字军)
-----------------------------------------------------------------------
local CRUSADE_MAX_STAGE = 15

-- 可用英雄ID池（从 hero_equip 表提取）
local CRUSADE_HERO_POOL = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,
    21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40}

local function initCrusade(localdata)
    local cd = localdata.crusade
    if cd and cd.enemies and #cd.enemies > 0 then
        return cd
    end

    -- 从 ed.player 获取实时英雄战力
    local playerHeroes = {}
    pcall(function()
        for tid, hero in pairs(ed.player.heroes or {}) do
            table.insert(playerHeroes, {
                tid = tid,
                gs = hero._gs or 0,
                level = hero._level or 1,
                stars = hero._stars or 1,
                rank = hero._rank or 1,
            })
        end
    end)
    if #playerHeroes == 0 then
        for _, h in ipairs(localdata.heroes or {}) do
            table.insert(playerHeroes, {
                tid = h.tid,
                gs = (h.level or 1) * 100,
                level = h.level or 1,
                stars = h.stars or 1,
                rank = h.rank or 1,
            })
        end
    end
    table.sort(playerHeroes, function(a, b) return a.gs > b.gs end)

    -- 玩家前5英雄总战力作为基准
    local playerTeamGs = 0
    for i = 1, math.min(5, #playerHeroes) do
        playerTeamGs = playerTeamGs + playerHeroes[i].gs
    end
    if playerTeamGs < 100 then playerTeamGs = 500 end

    -- 难度曲线：第1关60% → 第15关180%
    local function stageScale(stage)
        return 0.6 + (stage - 1) * (1.2 / (CRUSADE_MAX_STAGE - 1))
    end

    local enemies = {}
    for stage = 1, CRUSADE_MAX_STAGE do
        local scale = stageScale(stage)
        local stageEnemies = {}
        for i = 1, 5 do
            -- 从玩家英雄池轮换选取模板
            local srcIdx = ((stage - 1 + i - 1) % #playerHeroes) + 1
            local src = playerHeroes[srcIdx]
            -- 按战力比例缩放属性
            local lvl = math.max(1, math.min(math.floor(src.level * scale + 0.5), 90))
            local stars = math.max(1, math.min(math.floor(src.stars * scale + 0.5), 5))
            local rank = math.max(1, math.min(math.floor(src.rank * scale + 0.5), 12))
            table.insert(stageEnemies, {
                _tid = src.tid,
                _level = lvl,
                _stars = stars,
                _rank = rank,
            })
        end
        local nameIdx = math_random(1, #AI_NAMES)
        enemies[stage] = {
            heroes = stageEnemies,
            name = AI_NAMES[nameIdx],
            level = stageEnemies[1]._level,
            avatar = playerHeroes[((stage - 1) % #playerHeroes) + 1].tid,
            vip = math.min(math.floor(stage / 5), 3),
        }
    end

    local stages = {}
    for i = 1, CRUSADE_MAX_STAGE do
        stages[i] = { _status = 0, _rewards = {} }
    end

    local cd = {
        cur_stage = 1,
        reset_times = 0,
        last_reset_date = tonumber(os.date("%Y%m%d")),
        stages = stages,
        enemies = enemies,
        hero_crusade_data = {},
    }
    localdata.crusade = cd
    LocalData.save(localdata)
    return cd
end

local function getCrusadeStages(cd)
    local stages = {}
    for i = 1, CRUSADE_MAX_STAGE do
        local s = cd.stages[i]
        stages[i] = {
            _status = s and s._status or 0,
            _rewards = s and s._rewards or {},
        }
    end
    return stages
end

local function getHeroCrusadeList(localdata)
    local result = {}
    for i, h in ipairs(localdata.heroes or {}) do
        local cd = localdata.crusade and localdata.crusade.hero_crusade_data
        local hcd = cd and cd[h.tid]
        local hpPerc = hcd and hcd._hp_perc or 10000
        local mpPerc = hcd and hcd._mp_perc or 0
        local entry = {
            _tid = h.tid,
            _level = h.level,
            _stars = h.stars,
            _rank = h.rank,
            _dyna = {
                _hp_perc = hpPerc,
                _mp_perc = mpPerc,
                _custom_data = nil,
            },
        }
        table.insert(result, entry)
    end
    return result
end

local function buildCrusadeInfo(localdata)
    local cd = initCrusade(localdata)
    return {
        _cur_stage = cd.cur_stage,
        _reset_times = cd.reset_times,
        _stages = getCrusadeStages(cd),
        _heroes = getHeroCrusadeList(localdata),
        _hire_hero = nil,
    }
end

local function getCrusadeReward(stageId, resetTimes)
    local rewardTable = ed.getDataTable("CrusadeRewards")
    if not rewardTable then
        return { { _type = "gold", _param1 = stageId * 500, _param2 = 0 },
                 { _type = "crusadepoint", _param1 = stageId * 50, _param2 = 0 } }
    end
    local waveRewards = rewardTable[resetTimes] or rewardTable[1]
    if not waveRewards then
        return { { _type = "gold", _param1 = stageId * 500, _param2 = 0 } }
    end
    local stageReward = waveRewards[stageId]
    if not stageReward then
        return { { _type = "gold", _param1 = stageId * 500, _param2 = 0 } }
    end
    local vipFlag = 0
    local reward = stageReward[vipFlag]
    if not reward then reward = stageReward[0] end
    if not reward then
        return { { _type = "gold", _param1 = stageId * 500, _param2 = 0 } }
    end

    local rewards = {}
    for i = 1, 5 do
        local rtype = reward["Type " .. i]
        local amount = reward["Amount " .. i] or 0
        local id = reward["ID " .. i] or 0
        if rtype and amount > 0 then
            local t = string.lower(rtype)
            if t == "crusadepoint" then
                table.insert(rewards, { _type = "crusadepoint", _param1 = amount * 10, _param2 = 0 })
            elseif t == "chestbox" then
                local coinMap = { [1] = 50, [2] = 100, [3] = 200, [4] = 100, [5] = 200, [6] = 400 }
                local coins = coinMap[id] or 50
                table.insert(rewards, { _type = "crusadepoint", _param1 = coins * 10, _param2 = 0 })
            elseif t == "item" then
                table.insert(rewards, { _type = "item", _param1 = id, _param2 = amount })
            end
        end
    end
    if #rewards == 0 then
        rewards = { { _type = "gold", _param1 = stageId * 500, _param2 = 0 },
                    { _type = "crusadepoint", _param1 = stageId * 50, _param2 = 0 } }
    end
    return rewards
end

M.handlers.tbc = function(data, obj, localdata)
    local reply = {}

    if obj._open_panel then
        local info = buildCrusadeInfo(localdata)
        reply._open_panel = { _info = info }

    elseif obj._query_oppo then
        local cd = initCrusade(localdata)
        local stageId = obj._query_oppo._stage_id or 1
        local enemy = cd.enemies[stageId]
        if not enemy then
            reply._query_oppo = { _summary = { _name = "???", _level = 1, _avatar = 1, _vip = 0, _guild_name = "" }, _oppos = {}, _is_robot = 1 }
        else
            local oppos = {}
            for _, h in ipairs(enemy.heroes) do
                table.insert(oppos, {
                    _base = { _tid = h._tid, _level = h._level, _stars = h._stars, _rank = h._rank },
                    _dyna = { _hp_perc = 10000, _mp_perc = 0 },
                })
            end
            reply._query_oppo = {
                _summary = { _name = enemy.name, _level = enemy.level, _avatar = enemy.avatar, _vip = enemy.vip, _guild_name = "" },
                _oppos = oppos,
                _is_robot = 1,
            }
        end

    elseif obj._start_bat then
        local rseed = math_random(1, 2147483647)
        reply._start_bat = { _result = "success", _rseed = rseed }

    elseif obj._end_bat then
        local cd = initCrusade(localdata)
        local result = obj._end_bat._result or "defeat"
        local stageId = obj._end_bat._stage_id or cd.cur_stage
        if stageId and stageId < 0 then
            stageId = -stageId - 2
        end
        if result == "victory" or result == 0 then
            cd.stages[stageId] = cd.stages[stageId] or { _status = 0, _rewards = {} }
            cd.stages[stageId]._status = 1
            if stageId >= cd.cur_stage then
                cd.cur_stage = stageId + 1
            end
        end
        -- 保存战斗后英雄状态
        if obj._end_bat._self_heroes then
            cd.hero_crusade_data = cd.hero_crusade_data or {}
            for _, h in ipairs(obj._end_bat._self_heroes) do
                if h._tid then
                    cd.hero_crusade_data[h._tid] = {
                        _hp_perc = h._hp_perc or 0,
                        _mp_perc = h._mp_perc or 0,
                    }
                end
            end
        end
        LocalData.save(localdata)
        reply._end_bat = { _result = result }

    elseif obj._reset then
        local cd = localdata.crusade
        local resetTimes = cd and cd.reset_times or 0
        -- 清空远征数据，重新生成
        localdata.crusade = nil
        local cd = initCrusade(localdata)
        cd.reset_times = resetTimes + 1
        LocalData.save(localdata)
        reply._reset = {
            _result = "success",
            _info = buildCrusadeInfo(localdata),
        }

    elseif obj._draw_reward then
        local cd = initCrusade(localdata)
        local stageId = obj._draw_reward._stage_id or 1
        local rewards = getCrusadeReward(stageId, cd.reset_times or 0)
        if cd.stages[stageId] then
            cd.stages[stageId]._status = 2 -- rewarded
        end
        LocalData.save(localdata)
        reply._draw_reward = {
            _result = "success",
            _stage_id = stageId,
            _rewards = rewards,
            _heroes = {},
        }
    end

    data._tbc_reply = reply
end

-----------------------------------------------------------------------
-- 回放查询
-----------------------------------------------------------------------
M.handlers.query_replay = function(data, obj, localdata)
    data._record_index = obj._record_index or 0
    data._record_svrid = obj._record_svrid or 0
    data._replay_data = ""
end

-----------------------------------------------------------------------
-- 邮件相关
-----------------------------------------------------------------------
local function generateSystemMails()
    local mails = {}
    local now = os.time()

    -- 首通奖励邮件：从 localdata 读取已完成的关卡
    -- 这里简单生成几封欢迎邮件
    table.insert(mails, {
        _id = 1,
        _status = "unread",
        _mail_time = now - 3600,
        _expire_time = now + 30 * 86400,
        _content = {
            _plain_mail = {
                _from = "系统",
                _title = "欢迎来到卡牌大乱斗",
                _content = "感谢您的支持，请收下这份新手礼包！",
            }
        },
        _money = 5000,
        _diamonds = 200,
        _items = {},
        _points = {},
    })

    table.insert(mails, {
        _id = 2,
        _status = "unread",
        _mail_time = now - 1800,
        _expire_time = now + 30 * 86400,
        _content = {
            _plain_mail = {
                _from = "系统",
                _title = "道具礼包",
                _content = "附件内含精选道具，请查收。",
            }
        },
        _money = 10000,
        _diamonds = 0,
        _items = { ed.makebits(11, 10, 10, 371) },
        _points = {},
    })

    return mails
end

M.handlers.get_maillist = function(data, obj, localdata)
    -- 首次：生成系统邮件并存入 localdata
    if not localdata.mails_initialized then
        localdata.mails = generateSystemMails()
        localdata.mails_initialized = true
        LocalData.save(localdata)
    end

    -- 过期清理
    local now = os.time()
    local valid = {}
    for _, m in ipairs(localdata.mails) do
        if (m._expire_time or 0) > now then
            table.insert(valid, m)
        end
    end

    data._mail_list = {
        _sys_mail_list = valid,
    }
end

M.handlers.read_mail = function(data, obj, localdata)
    local mailId = obj and obj._id or 0

    -- 从 localdata.mails 中移除已领取的邮件
    if localdata.mails then
        for i = #localdata.mails, 1, -1 do
            if localdata.mails[i]._id == mailId then
                table.remove(localdata.mails, i)
                break
            end
        end
        LocalData.save(localdata)
    end

    -- 返回成功 + 剩余邮件列表，确保客户端数据同步
    local now = os.time()
    local remaining = {}
    for _, m in ipairs(localdata.mails or {}) do
        if (m._expire_time or 0) > now then
            table.insert(remaining, m)
        end
    end

    data._read_mail_reply = {
        _result = "success",
    }
    data._mail_list = {
        _sys_mail_list = remaining,
    }
end

-----------------------------------------------------------------------
-- 英雄分解
-----------------------------------------------------------------------
M.handlers.query_split_data = function(data, obj, localdata)
    data._split_data = data._split_data or {}
end

M.handlers.query_split_return = function(data, obj, localdata)
    data._split_return = data._split_return or {}
end

M.handlers.split_hero = function(data, obj, localdata)
    local hid = obj._tid
    if hid and localdata.heroes then
        localdata.heroes[hid] = nil
    end
    data._reward_list = {}
end

-----------------------------------------------------------------------
-- 公会日志
-----------------------------------------------------------------------
M.handlers.request_guild_log = function(data, obj, localdata)
    data._guild_log_list = {}
end

-----------------------------------------------------------------------
-- 充值返利
-----------------------------------------------------------------------
M.handlers.recharge_rebate = function(data, obj, localdata)
    data._recharge_rebate = data._recharge_rebate or {}
    data._recharge_rebate_info = data._recharge_rebate_info or {}
end

-----------------------------------------------------------------------
-- 社交/活动/次要系统 handler
-----------------------------------------------------------------------

-- chat: 聊天系统，返回 _say success 并触发 FireEvent("ChatRsp")
M.handlers.chat = function(data, obj, localdata)
    local reply = obj
    if reply and (reply._contents or reply._channel) then
        data._say = {
            _result = "success",
            _channel = reply._channel or 1,
            _contents = reply._contents or "",
        }
    else
        -- 聊天列表拉取，返回空列表
        data._chat_list = {}
    end
end

-- guild: 公会系统，触发 FireEvent("GuildRsp")
-- 单人版：自动创建公会，模拟NPC成员
local guild_npc_members = {
    { _uid = 9001, _name = "亚历山大", _avatar = 10, _level = 90, _vip = 10, _job = "elder" },
    { _uid = 9002, _name = "贝奥武夫", _avatar = 15, _level = 85, _vip = 8, _job = "member" },
    { _uid = 9003, _name = "克里斯蒂娜", _avatar = 20, _level = 82, _vip = 7, _job = "member" },
    { _uid = 9004, _name = "达芙妮", _avatar = 5, _level = 78, _vip = 5, _job = "member" },
    { _uid = 9005, _name = "埃里克", _avatar = 30, _level = 75, _vip = 3, _job = "member" },
    { _uid = 9006, _name = "菲奥娜", _avatar = 25, _level = 72, _vip = 2, _job = "member" },
    { _uid = 9007, _name = "加雷斯", _avatar = 35, _level = 88, _vip = 9, _job = "member" },
    { _uid = 9008, _name = "海伦娜", _avatar = 40, _level = 80, _vip = 6, _job = "member" },
}
local guild_npc_guilds = {
    { _id = 10001, _name = "英雄殿堂", _avatar = 1, _slogan = "共同战斗，共创辉煌！", _member_cnt = 9, _join_type = "no_verify", _join_limit = 30 },
    { _id = 10002, _name = "暗影军团", _avatar = 143, _slogan = "黑暗中前行", _member_cnt = 15, _join_type = "no_verify", _join_limit = 32 },
    { _id = 10003, _name = "龙骑联盟", _avatar = 147, _slogan = "龙之力量", _member_cnt = 22, _join_type = "verify", _join_limit = 35 },
    { _id = 10004, _name = "风暴之翼", _avatar = 150, _slogan = "自由翱翔", _member_cnt = 18, _join_type = "no_verify", _join_limit = 30 },
    { _id = 10005, _name = "圣光骑士团", _avatar = 155, _slogan = "光明永存", _member_cnt = 30, _join_type = "verify", _join_limit = 40 },
}

M.handlers.guild = function(data, obj, localdata)
    local reply = {}
    local pName = localdata.player.name or "Player"
    local pLevel = localdata.player.level or 1
    local pAvatar = localdata.player.avatar or 1
    local pVip = localdata.player.vip or 0
    local pUid = localdata.player.uid or 1
    local hasGuild = localdata.player._user_guild and localdata.player._user_guild._id and localdata.player._user_guild._id ~= 0

    local function makePlayerMember()
        return {
            _uid = pUid,
            _job = "chairman",
            _active = 100,
            _join_instance_time = 0,
            _last_login = 0,
            _summary = { _avatar = pAvatar, _level = pLevel, _name = pName, _vip = pVip }
        }
    end

    local function makeGuildInfo(guildName, guildAvatar)
        local members = { makePlayerMember() }
        for _, npc in ipairs(guild_npc_members) do
            table.insert(members, {
                _uid = npc._uid, _job = npc._job, _active = math.random(10, 100),
                _join_instance_time = math.random(0, 5), _last_login = os.time() - math.random(0, 3600),
                _summary = { _avatar = npc._avatar, _level = npc._level, _name = npc._name, _vip = npc._vip }
            })
        end
        return {
            _vitality = 5000, _self_vitality = 100, _left_distribute_time = 0,
            _summary = {
                _id = 10001, _name = guildName or "英雄殿堂",
                _slogan = "共同战斗，共创辉煌！", _avatar = guildAvatar or 1,
                _join_type = "no_verify", _join_limit = 32
            },
            _members = members
        }
    end

    if obj._open_pannel then
        if hasGuild then
            local gName = localdata.player._user_guild._name or "英雄殿堂"
            reply._query = { _info = makeGuildInfo(gName), _worship = { _use_times = 0 } }
        else
            reply._list = { _guilds = guild_npc_guilds, _create_cost = 500 }
        end
    elseif obj._create then
        local name = (type(obj._create) == "table" and obj._create._name) or "我的公会"
        local avatar = (type(obj._create) == "table" and obj._create._avatar) or 1
        reply._create = { _result = "success", _guild_info = makeGuildInfo(name, avatar) }
        localdata.player._user_guild = { _id = 10001, _name = name }
    elseif obj._query then
        if hasGuild then
            local gName = localdata.player._user_guild._name or "英雄殿堂"
            reply._query = { _info = makeGuildInfo(gName), _worship = { _use_times = 0 } }
        else
            reply._list = { _guilds = guild_npc_guilds, _create_cost = 500 }
        end
    elseif obj._search then
        local gid = obj._search and obj._search._guild_id
        local found = nil
        for _, g in ipairs(guild_npc_guilds) do
            if g._id == gid then found = g break end
        end
        reply._search = { _guilds = found }
    elseif obj._join then
        local gid = (type(obj._join) == "table" and obj._join._guild_id) or 10001
        local gName = "英雄殿堂"
        for _, g in ipairs(guild_npc_guilds) do
            if g._id == gid then gName = g._name break end
        end
        reply._join = { _result = "join_enter", _guild_info = makeGuildInfo(gName) }
        localdata.player._user_guild = { _id = gid, _name = gName }
    elseif obj._set then
        reply._set = { _result = "success" }
    elseif obj._set_job then
        reply._set_job = { _result = "success" }
    elseif obj._kick then
        reply._kick = { _result = "success" }
    elseif obj._join_confirm then
        reply._join_confirm = { _result = "success" }
    elseif obj._leave then
        reply._leave = { _result = "success" }
        localdata.player._user_guild = { _id = 0, _name = "" }
    elseif obj._dismiss then
        reply._dismiss = { _result = "success" }
        localdata.player._user_guild = { _id = 0, _name = "" }
    elseif obj._query_hires then
        reply._query_hires = { _users = {} }
    elseif obj._add_hire then
        reply._add_hire = { _result = "success", _income = 100 }
    elseif obj._del_hire then
        reply._del_hire = {
            _result = "success", _hire_reward = 50, _stay_reward = 50,
            _heroid = obj._del_hire and obj._del_hire._heroid or 0
        }
    elseif obj._worship_req then
        reply._worship_req = { _result = "success" }
    elseif obj._worship_withdraw then
        reply._worship_withdraw = { _rewards = { { _type = "gold", _param1 = 5000 } } }
    elseif obj._query_hh_detail then
        reply._query_hh_detail = { _hero = { _tid = 1, _rank = 1, _level = 1, _stars = 1 } }
    elseif obj._instance_query then
        reply._instance_query = { _current_raid_id = 1, _summary = {} }
    elseif obj._instance_open then
        reply._instance_open = {
            _result = "success",
            _raid_id = obj._instance_open and obj._instance_open._raid_id or 1,
            _left_time = 604800
        }
    elseif obj._drop_info then
        reply._drop_info = { _items = nil, _members = {} }
    elseif obj._drop_give then
        reply._drop_give = { _result = "success" }
    elseif obj._items_history then
        reply._items_history = { _item_historys = {} }
    elseif obj._instance_damage then
        reply._instance_damage = { _damages = {} }
    elseif obj._instance_start then
        reply._instance_start = { _rseed = math.random(1, 999999), _instance_info = {}, _loots = {} }
    elseif obj._instance_end then
        reply._instance_end = {
            _result = "success",
            _summary = { _id = 1, _stage_id = 1, _stage_progress = 0, _progress = 0, _left_time = 604800, _start_time = os.time() }
        }
    elseif obj._instance_detail then
        reply._instance_detail = { _wave = 1, _hp = 100, _challenger = "", _stage = 1, _challenger_status = "idle" }
    elseif obj._instance_drop then
        reply._instance_drop = { _rewards = {} }
    elseif obj._guild_stage_rank then
        reply._guild_stage_rank = { _ranks = {} }
    end

    data._guild_reply = reply
end

------------------------------------------------------------------------
-- 竞技场 AI 对手生成
------------------------------------------------------------------------
local pvp_names = {
  "亚历山大", "贝奥武夫", "克里斯蒂娜", "达芙妮", "埃里克",
  "菲奥娜", "加雷斯", "海伦娜", "伊莎贝拉", "贾斯汀",
  "凯瑟琳", "莱昂纳多", "米开朗基罗", "娜塔莎", "奥利维亚",
  "帕特里克", "昆廷", "罗莎琳德", "塞巴斯蒂安", "特里斯坦",
  "乌苏拉", "薇薇安", "沃尔特", "谢丽尔", "尤里乌斯",
  "赵云", "关羽", "张飞", "诸葛亮", "周瑜",
  "吕布", "貂蝉", "孙策", "马超", "黄忠"
}

-- 保存竞技场数据到CCUserDefault
local function savePvpData(player)
    if player._pvp then
        local pvpJson = json.encode(player._pvp)
        CCUserDefault:sharedUserDefault():setStringForKey("pvp_data", pvpJson)
        CCUserDefault:sharedUserDefault():flush()
    end
end

local function generateAiPlayer(rank, playerLevel)
  local nameIdx = math.random(1, #pvp_names)
  local name = pvp_names[nameIdx]
  local level = math.max(1, math.min(playerLevel + math.random(-3, 3), playerLevel + 5))
  local avatar = math.random(1, 8)
  local vip = math.random(0, math.min(5, math.floor(playerLevel / 20)))

  local pvpEnemy = ed.getDataTable("PVPEmeny")
  local heroConfig = nil
  if pvpEnemy then
    for _, row in pairs(pvpEnemy) do
      if row["Rank"] and rank >= row["Rank"] then
        heroConfig = row
        break
      end
    end
  end

  local heroes = {}
  if heroConfig then
    for i = 1, 5 do
      local heroId = heroConfig["Hero" .. i]
      if heroId and heroId > 0 then
        local heroLevel = math.max(1, level - math.random(0, 2))
        table.insert(heroes, {
          _tid = heroId,
          _level = heroLevel,
          _stars = math.max(1, math.min(5, math.floor(level / 15) + math.random(0, 1))),
          _rank = math.max(5, math.min(22, math.floor(level / 10) + 1)),
        })
      end
    end
  end

  if #heroes == 0 then
    local allHeroes = {}
    local unitTable = ed.getDataTable("Unit")
    if unitTable then
      for tid, row in pairs(unitTable) do
        if type(tid) == "number" and row["Type"] ~= "Boss" then
          table.insert(allHeroes, tid)
        end
      end
    end
    local count = math.random(3, 5)
    for i = 1, count do
      if #allHeroes > 0 then
        local idx = math.random(1, #allHeroes)
        local tid = allHeroes[idx]
        table.insert(heroes, {
          _tid = tid,
          _level = math.max(1, level - math.random(0, 3)),
          _stars = math.random(1, math.min(5, math.floor(level / 15) + 1)),
          _rank = math.max(5, math.min(22, math.max(1, math.floor(level / 10)))),
        })
      end
    end
  end

  local gs = 0
  for _, h in ipairs(heroes) do
    gs = gs + h._level * 10 + h._stars * 50 + h._rank * 30
  end

  return {
    _user_id = 10000 + rank,
    _summary = {
      _name = name,
      _avatar = avatar,
      _level = level,
      _vip = vip,
    },
    _gs = gs,
    _rank = rank,
    _heroes = heroes,
    _is_robot = 1,
  }
end

local function generateAiOpponents(playerRank, playerLevel, count)
  local opponents = {}
  for i = 1, count do
    local targetRank = math.max(1, playerRank - math.random(1, 50 * i))
    local opponent = generateAiPlayer(targetRank, playerLevel)
    table.insert(opponents, opponent)
  end
  table.sort(opponents, function(a, b) return a._rank < b._rank end)
  return opponents
end

local function generateRankBoard(playerRank, playerLevel, count)
  local board = {}
  count = count or 20
  for i = 1, count do
    local rank = i
    local entry = generateAiPlayer(rank, playerLevel)
    entry._rank = rank
    table.insert(board, entry)
  end
  return board
end

-- ladder: 天梯/PVP 系统
M.handlers.ladder = function(data, obj, localdata)
    -- 排行榜查询（tab1 竞技场每日排名）
    if obj._query_rankboard then
        local npcNames = AI_NAMES
        local rankList = {}
        for i = 1, 20 do
            local ni = ((i - 1) % #npcNames) + 1
            table_insert(rankList, {
                _summary = {
                    _avatar = (i % 10) + 1,
                    _vip = 0,
                    _name = npcNames[ni],
                    _level = math.max(60 - i * 2, 10),
                },
            })
        end
        local playerLevel = localdata.player.level or 1
        local pvp = localdata.player._pvp
        local pvpRank = (pvp and pvp.rank) or 1001
        local pvpGs = 0
        pcall(function()
            for tid, hero in pairs(ed.player.heroes or {}) do
                pvpGs = pvpGs + (hero._gs or 0)
            end
        end)
        data._query_pvp_ranklist_reply = {
            _rank_list = rankList,
            _pos = pvpRank,
            _prev_pos = pvpRank,
            _self_rank = {
                _summary = {
                    _avatar = localdata.player.avatar or 1,
                    _vip = 0,
                    _name = localdata.player.name or "Player",
                    _level = playerLevel,
                },
            },
        }
        return
    end

    data._ladder_reply = data._ladder_reply or {}
    local reply = data._ladder_reply
    local player = localdata.player
    local pvp = player._pvp

    -- 确保竞技场数据初始化
    if not pvp then
        pvp = {
            rank = 1001,
            gs = 0,
            left_count = 5,
            buy_times = 0,
            last_bt_time = 0,
            highest_rank = 1001,
            enemies = {},
            records = {},
            defend_lineup = {},
        }
        player._pvp = pvp
    end

    -- 刷新GS
    if ed.player and ed.player.getPvpGs then
        pvp.gs = ed.player:getPvpGs()
    end

    local now = os.time()
    -- 单机版：每次打开面板恢复5次挑战机会
    if obj._open_panel then
        pvp.left_count = 5
    end
    if obj._open_panel then
        pvp.enemies = generateAiOpponents(pvp.rank, player.level or 1, 3)
        -- 默认防守阵容：如果为空，取玩家前5个英雄
        if not pvp.defend_lineup or #pvp.defend_lineup == 0 then
            pvp.defend_lineup = {}
            local runtimeHeroes = ed.player and (ed.player._heroes or {})
            local count = 0
            for _, h in ipairs(runtimeHeroes) do
                if count >= 5 then break end
                local tid = type(h) == "table" and h._tid or h
                if tid then
                    table.insert(pvp.defend_lineup, tid)
                    count = count + 1
                end
            end
        end
        reply._open_panel = {
            _rank = pvp.rank,
            _gs = pvp.gs,
            _left_count = pvp.left_count,
            _buy_times = pvp.buy_times,
            _last_bt_time = pvp.last_bt_time,
            _highestrank = pvp.highest_rank,
            _oppos = pvp.enemies,
            _lineup = pvp.defend_lineup,
        }
        LegendLog("[PVP] _open_panel: rank=" .. pvp.rank)
    end

    -- 刷新对手
    if obj._apply_opponent then
        pvp.enemies = generateAiOpponents(pvp.rank, player.level or 1, 3)
        reply._apply_opponent = {
            _oppos = pvp.enemies,
        }
    end

    -- 开始战斗
    if obj._start_battle then
        local attackLineup = obj._start_battle._attack_lineup or {}
        local oppoUserId = obj._start_battle._oppo_user_id

        local enemy = nil
        for _, e in ipairs(pvp.enemies or {}) do
            if e._user_id == oppoUserId then
                enemy = e
                break
            end
        end

        -- fallback: 如果在 enemies 中找不到，用 oppoUserId 反推 rank 并生成
        if not enemy then
            local rank = math.max(1, oppoUserId - 10000)
            enemy = generateAiPlayer(rank, player.level or 1)
        end

        if enemy then
            local enemyHeroes = {}
            for _, h in ipairs(enemy._heroes or {}) do
                table.insert(enemyHeroes, h)
            end

            local selfHeroes = {}
            for _, tid in ipairs(attackLineup) do
                local hero = ed.player and ed.player.heroes and ed.player.heroes[tid]
                LegendLog("[PVP] self_hero tid=" .. tostring(tid) .. " hero=" .. tostring(hero ~= nil) .. " level=" .. tostring(hero and hero._level))
                if hero then
                    local heroData = {
                        _tid = hero._tid,
                        _level = hero._level,
                        _rank = hero._rank,
                        _stars = hero._stars,
                        _exp = hero._exp,
                        _items = hero._items,
                        _skill_levels = hero._skill_levels,
                        _state = hero._state,
                    }
                    table.insert(selfHeroes, heroData)
                else
                    LegendLog("[PVP] WARNING: hero tid=" .. tostring(tid) .. " not found in ed.player.heroes, fallback to level 1")
                    table.insert(selfHeroes, {_tid = tid, _level = 1})
                end
            end

            pvp.left_count = math.max(0, pvp.left_count - 1)
            pvp.last_bt_time = now
            pvp.last_oppo_rank = enemy._rank

            reply._start_battle = {
                _heroes = enemyHeroes,
                _self_heroes = selfHeroes,
                _is_robot = enemy._is_robot or 1,
                _rseed = math.random(1, 999999),
            }
            pcall(function() ed.saveDirty = true end)
        end
    end

    -- 结束战斗
    if obj._end_battle then
        local result = obj._end_battle._result
        LegendLog("[PVP] _end_battle received: result=" .. tostring(result) .. " type=" .. type(result))
        table.insert(pvp.records, 1, {
            _result = result,
            _time = now,
            _rank = pvp.rank,
        })
        while #pvp.records > 20 do
            table.remove(pvp.records)
        end

        if result == "victory" or result == 0 then
            local oldRank = pvp.rank
            local oppoRank = pvp.last_oppo_rank or pvp.rank
            if oppoRank < pvp.rank then
                pvp.rank = oppoRank
            end
            LegendLog("[PVP] _end_battle VICTORY: oldRank=" .. oldRank .. " newRank=" .. pvp.rank)
            if pvp.rank < pvp.highest_rank then
                pvp.highest_rank = pvp.rank
            end

            local rewardAmount = math.max(10, 100 - pvp.rank)
            if ed.player and ed.player.addPvpMoney then
                ed.player:addPvpMoney(rewardAmount)
            end

            reply._end_battle = {
                _result = "victory",
                _rank = pvp.rank,
                _prev_rank = oldRank,
                _reward = rewardAmount,
            }
        else
            reply._end_battle = {
                _result = "defeat",
                _rank = pvp.rank,
                _prev_rank = pvp.rank,
                _reward = 0,
            }
        end
        pcall(function() ed.saveDirty = true end)
    end

    -- 购买挑战次数
    if obj._buy_battle_chance then
        local priceTable = ed.getDataTable("GradientPrice")
        local cost = 50
        if priceTable then
            local row = priceTable[pvp.buy_times + 1]
            if row then cost = tonumber(row["PVP Buy"]) or 50 end
        end
        if player._rmb >= cost then
            player._rmb = player._rmb - cost
            pvp.buy_times = pvp.buy_times + 1
            pvp.left_count = pvp.left_count + 1
            reply._buy_battle_chance = {
                _result = "success",
                _left_count = pvp.left_count,
                _buy_times = pvp.buy_times,
            }
        else
            reply._buy_battle_chance = {
                _result = "fail",
            }
        end
        pcall(function() ed.saveDirty = true end)
    end

    -- 清除战斗CD
    if obj._clear_battle_cd then
        local cdCost = 50
        if player._rmb >= cdCost then
            player._rmb = player._rmb - cdCost
            pvp.last_bt_time = 0
            reply._clear_battle_cd = {
                _result = "success",
            }
        else
            reply._clear_battle_cd = {
                _result = "fail",
            }
        end
        pcall(function() ed.saveDirty = true end)
    end

    -- 查询战斗记录
    if obj._query_records then
        reply._query_records = {
            _records = pvp.records,
        }
    end

    -- 查询排行榜
    if obj._query_rankborad then
        local board = generateRankBoard(pvp.rank, player.level or 1, 20)
        table.insert(board, {
            _user_id = 0,
            _summary = {
                _name = player.name or "Player",
                _avatar = player.avatar or 1,
                _level = player.level or 1,
                _vip = player:getvip(),
            },
            _gs = pvp.gs,
            _rank = pvp.rank,
            _is_self = 1,
        })
        reply._query_rankborad = {
            _rankboard = board,
        }
    end

    -- 查询对手详情
    if obj._query_oppo then
        local oppoId = obj._query_oppo._user_id
        local foundEnemy = nil
        for _, e in ipairs(pvp.enemies or {}) do
            if e._user_id == oppoId then
                foundEnemy = e
                break
            end
        end
        if foundEnemy then
            reply._query_oppo = foundEnemy
        end
    end

    -- 设置防守阵容
    if obj._set_lineup then
        pvp.defend_lineup = obj._set_lineup._lineup or {}
        pvp.gs = ed.player and ed.player.getPvpGs and ed.player:getPvpGs() or 0
        reply._set_lineup = {
            _result = "success",
            _lineup = pvp.defend_lineup,
            _gs = tostring(pvp.gs),
        }
    end

    -- 自动保存竞技场数据
    savePvpData(localdata.player)
end


-----------------------------------------------------------------------
-- 挖矿系统辅助函数
-----------------------------------------------------------------------
local ExcavateTreasureTable = nil
local ExcavateWildEnemyTable = nil
local GradientPriceTable = nil

local function getExcavateConfig()
    if not ExcavateTreasureTable then
        ExcavateTreasureTable = ed.getDataTable("ExcavateTreasure")
    end
    if not ExcavateWildEnemyTable then
        ExcavateWildEnemyTable = ed.getDataTable("ExcavateWildEnemy")
    end
    if not GradientPriceTable then
        GradientPriceTable = ed.getDataTable("GradientPrice")
    end
end

local function initExcavate(localdata)
    if not localdata.excavate then
        localdata.excavate = {
            mines = {},
            searched_id = 0,
            search_times = 0,
            last_search_ts = 0,
            last_search_type = 0,
            attacking_id = 0,
            attack_team_id = 0,
            history = {},
            next_mine_id = 1,
            next_history_id = 1,
        }
    end
    return localdata.excavate
end

-- 根据权重随机选择矿点类型（1-9）
local function randomExcavateType(playerLevel)
    getExcavateConfig()
    if not ExcavateTreasureTable then return 4 end

    local candidates = {}
    local totalWeight = 0
    for i = 1, 9 do
        local row = ExcavateTreasureTable[i]
        if row then
            local lvlReq = row["Level Requirement"] or 1
            if playerLevel >= lvlReq then
                local w = row["Prob Weight"] or 0
                table_insert(candidates, { type_id = i, weight = w })
                totalWeight = totalWeight + w
            end
        end
    end
    if #candidates == 0 then return 4 end

    local r = math_random(1, math_floor(totalWeight + 0.5))
    local acc = 0
    for _, c in ipairs(candidates) do
        acc = acc + c.weight
        if r <= acc then return c.type_id end
    end
    return candidates[#candidates].type_id
end

-- 获取当前服务器时间戳（秒）
local function getExcavateTime()
    return ed.getServerTime and ed.getServerTime() or os.time()
end

-- 构建矿点回复数据（down.proto excavate 结构）
local function buildExcavateReply(mine)
    local typeRow = nil
    getExcavateConfig()
    if ExcavateTreasureTable then
        typeRow = ExcavateTreasureTable[mine.type_id]
    end

    local teams = {}
    for _, t in ipairs(mine.teams or {}) do
        table_insert(teams, {
            _team_id = t.team_id,
            _player = t.player,
            _hero_bases = t.hero_bases,
            _hero_dynas = t.hero_dynas,
            _res_got = t.res_got or 0,
        })
    end

    return {
        _owner = mine.owner or "monster",
        _id = mine.id,
        _type_id = mine.type_id,
        _team = teams,
        _state = mine.state,
        _state_end_ts = mine.state_end_ts or 0,
        _produce_speed = mine.produce_speed or (typeRow and typeRow["Priduce Speed Per Minute"] or 0),
        _storage = mine.storage or (typeRow and typeRow["Storage Amount"] or 0),
    }
end

-- 计算矿点已产出资源量
local function calcProduced(mine, now)
    if not mine.found_ts or mine.found_ts == 0 then return 0 end
    local elapsed = (now or getExcavateTime()) - mine.found_ts
    if elapsed < 0 then elapsed = 0 end
    return math_floor(mine.produce_speed * elapsed / 60 + 0.5)
end

-- 检查并更新矿点状态
local function updateMineState(mine, now)
    if not mine then return end
    now = now or getExcavateTime()
    if mine.state == "searched" and mine.state_end_ts > 0 and now >= mine.state_end_ts then
        mine.state = "empty"
        mine.state_end_ts = 0
    elseif mine.state == "prepare" and mine.state_end_ts > 0 and now >= mine.state_end_ts then
        mine.state = "occupy"
        mine.state_end_ts = 0
    elseif mine.state == "protect" and mine.state_end_ts > 0 and now >= mine.state_end_ts then
        mine.state = "occupy"
        mine.state_end_ts = 0
    end
end

-- 从玩家英雄池生成野怪AI防守队伍
local function generateWildTeam(mineTypeId, teamCount)
    getExcavateConfig()
    local typeRow = ExcavateTreasureTable and ExcavateTreasureTable[mineTypeId]
    if not typeRow then return {} end

    local wildKey = "Wild ID " .. tostring(teamCount)
    local wildList = typeRow[wildKey]
    local wildIds = {}
    if wildList then
        for _, id in ipairs(wildList) do
            table_insert(wildIds, tonumber(id))
        end
    end
    if #wildIds == 0 then return {} end

    local wildIdx = wildIds[math_random(1, #wildIds)]
    local wildData = ExcavateWildEnemyTable and ExcavateWildEnemyTable[wildIdx]

    local team = {
        team_id = 1,
        player = {
            _name = wildData and wildData["Player Name"] or "野怪",
            _level = wildData and wildData["Player Level"] or 50,
            _avatar = wildData and wildData["Avatar ID"] or 1,
            _vip = 0,
            _guild_name = "",
        },
        hero_bases = {},
        hero_dynas = {},
        res_got = 0,
    }

    local playerHeroes = {}
    if ed.player and ed.player.heroes then
        for tid, h in pairs(ed.player.heroes) do
            if type(h) == "table" and h._level then
                table_insert(playerHeroes, {
                    tid = tid,
                    level = h._level or 1,
                    stars = h._stars or 1,
                    rank = h._rank or 0,
                })
            end
        end
    end

    for i = #playerHeroes, 2, -1 do
        local j = math_random(1, i)
        playerHeroes[i], playerHeroes[j] = playerHeroes[j], playerHeroes[i]
    end

    local count = math.min(5, #playerHeroes)
    for i = 1, count do
        local h = playerHeroes[i]
        table_insert(team.hero_bases, {
            _tid = h.tid,
            _level = h.level,
            _stars = h.stars,
            _rank = h.rank,
        })
        table_insert(team.hero_dynas, {
            _hp_perc = 10000,
            _mp_perc = 0,
        })
    end

    return { team }
end

-- 检查搜索次数是否需要跨天重置
local function checkSearchDayReset(exc)
    if exc.search_times > 0 then
        local lastTs = exc.last_search_ts
        local nowTs = getExcavateTime()
        if ed.checkTwoDateod and ed.checkTwoDateod(lastTs, nowTs) then
            exc.search_times = 0
            exc.last_search_ts = nowTs
        end
    end
end

-- 按 ID 查找矿点
local function findMine(exc, id)
    for _, m in ipairs(exc.mines) do
        if m.id == id then return m end
    end
    return nil
end

-- 构建资源奖励结构
local function buildResourceReward(typeRow, amount)
    if not amount or amount <= 0 then return nil end
    local produceType = typeRow and typeRow["Produce Type"] or "Gold"
    local rewardType = "gold"
    if produceType == "Diamond" then rewardType = "diamond"
    elseif produceType == "Item" then rewardType = "item"
    end
    if rewardType == "item" then
        local produceId = typeRow and typeRow["Produce ID"] or 218
        return { _type = "item", _param1 = produceId, _param2 = amount }
    else
        return { _type = rewardType, _param1 = amount }
    end
end

-----------------------------------------------------------------------
-- excavate: 挖矿系统
-----------------------------------------------------------------------
M.handlers.excavate = function(data, obj, localdata)
    local exc = initExcavate(localdata)
    local reply = {}
    local now = getExcavateTime()

    for _, mine in ipairs(exc.mines) do
        updateMineState(mine, now)
    end

    checkSearchDayReset(exc)

    if obj._query_excavate_data then
        local mineReplies = {}
        for _, mine in ipairs(exc.mines) do
            table_insert(mineReplies, buildExcavateReply(mine))
        end

        reply._query_excavate_data_reply = {
            _excavate = mineReplies,
            _searched_id = exc.searched_id or 0,
            _search_times = exc.search_times or 0,
            _last_search_ts = exc.last_search_ts or 0,
            _attacking_id = exc.attacking_id or 0,
            _bat_heroes = {},
            _cfg = { _attack_timeout = 180 },
        }

    elseif obj._search_excavate then
        local playerLevel = (localdata.player and localdata.player.level) or 1
        local times = exc.search_times + 1

        getExcavateConfig()
        local cost = 100
        if GradientPriceTable and GradientPriceTable[times] then
            cost = GradientPriceTable[times]["Excavate Search"] or 100
            if cost <= 0 then
                for i = 1, 20 do
                    if GradientPriceTable[i] and GradientPriceTable[i]["Excavate Search"] and GradientPriceTable[i]["Excavate Search"] > 0 then
                        cost = GradientPriceTable[i]["Excavate Search"]
                    end
                end
            end
        end

        local gold = (localdata.player and localdata.player.gold) or 0
        if gold < cost then
            reply._search_excavate_reply = { _result = "lack_money" }
        else
            localdata.player.gold = gold - cost

            local typeId = randomExcavateType(playerLevel)
            local typeRow = ExcavateTreasureTable and ExcavateTreasureTable[typeId]

            local mine = {
                id = exc.next_mine_id,
                type_id = typeId,
                owner = "monster",
                state = "searched",
                state_end_ts = now + 300,
                teams = generateWildTeam(typeId, 1),
                produce_speed = typeRow and typeRow["Priduce Speed Per Minute"] or 30,
                storage = typeRow and typeRow["Storage Amount"] or 72000,
                found_ts = now,
            }

            table_insert(exc.mines, mine)
            exc.next_mine_id = exc.next_mine_id + 1
            exc.searched_id = mine.id
            exc.search_times = times
            exc.last_search_ts = now
            exc.last_search_type = typeId

            LocalData.save(localdata)

            reply._search_excavate_reply = {
                _result = "success",
                _excavate = buildExcavateReply(mine),
            }
        end

    elseif obj._set_excavate_team then
        local excId = obj._set_excavate._excavate_id
        local tids = obj._set_excavate._tid or {}

        local mine = findMine(exc, excId)

        if not mine then
            reply._set_excavate_team_reply = { _result = "expired" }
        elseif mine.owner ~= "mine" then
            reply._set_excavate_team_reply = { _result = "fall" }
        else
            local heroBases = {}
            local heroDynas = {}
            for _, tid in ipairs(tids) do
                local h = ed.player.heroes and ed.player.heroes[tid]
                if h then
                    table_insert(heroBases, {
                        _tid = tid,
                        _level = h._level or 1,
                        _stars = h._stars or 1,
                        _rank = h._rank or 0,
                    })
                    table_insert(heroDynas, {
                        _hp_perc = 10000,
                        _mp_perc = 0,
                    })
                end
            end

            if mine.teams and #mine.teams > 0 then
                mine.teams[1].hero_bases = heroBases
                mine.teams[1].hero_dynas = heroDynas
            else
                mine.teams = {{
                    team_id = 1,
                    player = { _name = localdata.player.name or "Player", _level = localdata.player.level or 1, _avatar = localdata.player.avatar or 0, _vip = 0, _guild_name = "" },
                    hero_bases = heroBases,
                    hero_dynas = heroDynas,
                    res_got = 0,
                }}
            end

            LocalData.save(localdata)
            reply._set_excavate_team_reply = { _result = "success" }
        end

    elseif obj._excavate_start_battle then
        local excId = obj._excavate_start_battle._excavate_id
        local teamId = obj._excavate_start_battle._team_id or 1

        local mine = findMine(exc, excId)

        if not mine then
            reply._excavate_start_battle_reply = { _result = "failed", _rseed = 0 }
        else
            exc.attacking_id = excId
            exc.attack_team_id = teamId
            mine.state = "battle"

            local rseed = math_random(1, 2147483647)
            local heroBases = {}
            local heroDynas = {}
            if mine.teams then
                for _, team in ipairs(mine.teams) do
                    if team.team_id == teamId then
                        heroBases = team.hero_bases or {}
                        heroDynas = team.hero_dynas or {}
                        break
                    end
                end
            end

            LocalData.save(localdata)
            reply._excavate_start_battle_reply = {
                _result = "success",
                _rseed = rseed,
                _hero_bases = heroBases,
                _hero_dynas = heroDynas,
            }
        end

    elseif obj._excavate_end_battle then
        local result = obj._excavate_end_battle._result or "defeat"
        local excId = exc.attacking_id or 0

        local mine = findMine(exc, excId)

        exc.attacking_id = 0
        exc.attack_team_id = 0

        if not mine then
            LocalData.save(localdata)
            reply._excavate_end_battle_reply = { _result = result }
        elseif result == "victory" or result == 0 then
            local typeRow = ExcavateTreasureTable and ExcavateTreasureTable[mine.type_id]
            local prepareTime = typeRow and typeRow["Prepare Time"] or 7200

            local produced = calcProduced(mine, now)
            local lootRatio = typeRow and typeRow["Loot Ratio"] or 0.2
            local lootAmount = math_floor(produced * lootRatio)
            local safeAmount = typeRow and typeRow["Safe Amount"] or 0
            if lootAmount < safeAmount then lootAmount = 0 end

            mine.owner = "mine"
            mine.state = "prepare"
            mine.state_end_ts = now + prepareTime
            mine.teams = {{
                team_id = 1,
                player = { _name = localdata.player.name or "Player", _level = localdata.player.level or 1, _avatar = localdata.player.avatar or 0, _vip = 0, _guild_name = "" },
                hero_bases = {},
                hero_dynas = {},
                res_got = 0,
            }}
            mine.found_ts = now

            local reward = buildResourceReward(typeRow, lootAmount)

            LocalData.save(localdata)
            reply._excavate_end_battle_reply = {
                _result = result,
                _excavate = buildExcavateReply(mine),
                _reward = reward,
            }
        else
            mine.state = "occupy"
            LocalData.save(localdata)
            reply._excavate_end_battle_reply = { _result = result }
        end

    elseif obj._query_excavate_history then
        reply._query_excavate_history_reply = {
            _excavate_history = exc.history or {},
        }

    elseif obj._query_excavate_battle then
        reply._query_excavate_battle_reply = { _battles = {} }

    elseif obj._query_excavate_def then
        local mineId = obj._query_excavate_def._mine_id
        local mine = findMine(exc, mineId)
        if mine and mine.owner == "mine" then
            reply._query_excavate_def_reply = { _excavate = buildExcavateReply(mine) }
        else
            reply._query_excavate_def_reply = {}
        end

    elseif obj._clear_excavate_battle then
        if exc.attacking_id and exc.attacking_id > 0 then
            local mine = findMine(exc, exc.attacking_id)
            if mine then mine.state = "occupy" end
            exc.attacking_id = 0
            exc.attack_team_id = 0
            LocalData.save(localdata)
        end
        reply._clear_excavate_battle_reply = { _result = "success" }

    elseif obj._withdraw_excavate_hero then
        local heroId = obj._withdraw_excavate_hero._hero_id
        local found = false
        for _, mine in ipairs(exc.mines) do
            if mine.teams then
                for _, team in ipairs(mine.teams) do
                    for i, base in ipairs(team.hero_bases or {}) do
                        if base._tid == heroId then
                            table.remove(team.hero_bases, i)
                            table.remove(team.hero_dynas, i)
                            found = true
                            break
                        end
                    end
                    if found then break end
                end
            end
            if found then break end
        end
        LocalData.save(localdata)
        reply._withdraw_excavate_hero_reply = { _result = "success" }

    elseif obj._draw_excavate_def_rwd then
        local histId = obj._draw_excavate_def_rwd._id
        local vitReward = 10
        for i, h in ipairs(exc.history or {}) do
            if h._id == histId then
                vitReward = h._vatility or 10
                table.remove(exc.history, i)
                break
            end
        end
        if localdata.vitality then
            localdata.vitality.current = (localdata.vitality.current or 0) + vitReward
        end
        LocalData.save(localdata)
        reply._draw_excavate_def_rwd_reply = {
            _result = "success",
            _draw_vitality = vitReward,
        }

    elseif obj._drop_excavate then
        local mineId = obj._drop_excavate._mine_id
        local removedMine = nil
        for i, m in ipairs(exc.mines) do
            if m.id == mineId then
                removedMine = m
                table.remove(exc.mines, i)
                break
            end
        end

        local reward = nil
        if removedMine then
            local produced = calcProduced(removedMine, now)
            local typeRow = ExcavateTreasureTable and ExcavateTreasureTable[removedMine.type_id]
            reward = buildResourceReward(typeRow, produced)
            if exc.searched_id == mineId then
                exc.searched_id = 0
            end
        end

        LocalData.save(localdata)
        reply._drop_excavate_reply = {
            _result = "success",
            _reward = reward,
        }

    elseif obj._query_replay then
        data._record_index = obj._query_replay._record_index or 0
        data._record_svrid = obj._query_replay._record_svrid or 0
        data._replay_data = ""
    end

    data._excavate_reply = reply
end

-- change_server: 切换服务器
M.handlers.change_server = function(data, obj, localdata)
    data._change_server_reply = { _result = "success" }
end

-- cdkey_gift: CDKEY 兑换
M.handlers.cdkey_gift = function(data, obj, localdata)
    data._cdkey_gift_reply = { _result = "success" }
end

-- worldcup: 世界杯活动
M.handlers.worldcup = function(data, obj, localdata)
    data._worldcup_reply = data._worldcup_reply or {}
end

-- fb_attention: Facebook 关注
M.handlers.fb_attention = function(data, obj, localdata)
    data._fb_attention_reply = { _result = "success" }
end

-- get_vip_gift: VIP 已移除，保留空 handler 避免报错
M.handlers.get_vip_gift = function(data, obj, localdata)
    data._get_vip_gift_reply = { _result = "success" }
end

-- trigger_job: 触发任务（已由login初始化_dailyjob，此handler保持兼容）
M.handlers.trigger_job = function(data, obj, localdata)
    data._trigger_job_reply = { _result = "success" }
end

-- job_rewards: 领取日常任务/活动奖励
M.handlers.job_rewards = function(data, obj, localdata)
    local jobId = obj and obj._job
    if not jobId then
        data._job_rewards_reply = { _result = "fail" }
        return
    end

    -- 活动奖励（job ID 以 "act_" 开头）
    if type(jobId) == "string" and string.sub(jobId, 1, 4) == "act_" then
        local activities = generateActivities(localdata)
        local targetReward = nil
        local targetAct = nil
        for _, act in ipairs(activities) do
            for _, rw in ipairs(act._rewards or {}) do
                if rw._dailyjob and rw._dailyjob._id == jobId then
                    targetReward = rw
                    targetAct = act
                    break
                end
            end
            if targetReward then break end
        end
        if not targetReward then
            data._job_rewards_reply = { _result = "fail" }
            return
        end
        -- 检查是否已领取
        if localdata.activity_claimed and localdata.activity_claimed[jobId] then
            data._job_rewards_reply = { _result = "fail" }
            return
        end
        -- 检查消费是否达标
        local spent = localdata.activity_spent and localdata.activity_spent.amount or 0
        if spent < targetReward._dailyjob._task_target then
            data._job_rewards_reply = { _result = "fail" }
            return
        end
        -- 标记已领取
        if not localdata.activity_claimed then localdata.activity_claimed = {} end
        localdata.activity_claimed[jobId] = true
        LocalData.save(localdata)
        -- 发放奖励
        local rewardItems = {}
        for _, rw in ipairs(targetAct._rewards) do
            if rw._dailyjob._id == jobId then
                local item = { _type = rw._type, _id = rw._id, _amount = rw._amount }
                table.insert(rewardItems, item)
                if rw._type == "money" and ed.player and ed.player.addMoney then
                    ed.player:addMoney(rw._amount, true)
                elseif rw._type == "rmb" and ed.player and ed.player.addrmb then
                    ed.player:addrmb(rw._amount)
                elseif rw._type == "item" and ed.player and ed.player.addEquip then
                    ed.player:addEquip(rw._id, rw._amount)
                end
                break
            end
        end
        data._job_rewards_reply = { _result = "success", _activity_reward = rewardItems }
        return
    end

    -- 日常任务奖励
    local row = ed.getDataTable("Todolist")[jobId]
    if not row then
        data._job_rewards_reply = { _result = "fail" }
        return
    end

    local target = row["Task Target"]
    local count = ed.player and ed.player.getDailyjobCount and ed.player:getDailyjobCount(jobId) or 0
    if count < target then
        data._job_rewards_reply = { _result = "fail" }
        return
    end

    for i = 1, 2 do
        local rType = row[string.format("Task Reward %d Type", i)]
        local rId = row[string.format("Task Reward %d ID", i)]
        local rAmount = row[string.format("Task Reward %d Amount", i)]
            or (i == 1 and row["Task Reward Amount"])
        if rType and rAmount and rAmount > 0 then
            if rType == "Coin" then
                if ed.player and ed.player.addMoney then ed.player:addMoney(rAmount, true) end
            elseif rType == "Diamond" then
                if ed.player and ed.player.addrmb then ed.player:addrmb(rAmount) end
            elseif rType == "Vitality" then
                if ed.player and ed.player.addVitality then ed.player:addVitality(rAmount) end
            elseif rType == "PlayerEXP" then
                if ed.player and ed.player.addExp then ed.player:addExp(rAmount) end
            elseif rType == "Item" then
                if ed.player and ed.player.addEquip then ed.player:addEquip(rId, rAmount) end
            end
        end
    end

    if ed.player and ed.player.resetDailyjobTime then
        ed.player:resetDailyjobTime(jobId)
    end

    data._job_rewards_reply = { _result = "success" }
end

-----------------------------------------------------------------------
-- 活动系统辅助函数
-----------------------------------------------------------------------
local function getActivityPeriod()
    local now = os.time()
    local t = os.date("*t", now)
    t.hour = 0; t.min = 0; t.sec = 0
    local dayStart = os.time(t)
    local wday = t.wday
    local daysToMonday = (wday == 1) and 6 or (wday - 2)
    local weekStart = dayStart - daysToMonday * 86400
    local weekEnd = weekStart + 7 * 86400
    return weekStart, weekEnd
end

local function getSpentDiamond(localdata)
    local periodStart, periodEnd = getActivityPeriod()
    if not localdata.activity_spent then
        localdata.activity_spent = { period = periodStart, amount = 0 }
    end
    if localdata.activity_spent.period ~= periodStart then
        localdata.activity_spent.period = periodStart
        localdata.activity_spent.amount = 0
    end
    return localdata.activity_spent.amount, periodStart, periodEnd
end

local function buildDiamondConsumeActivity(localdata)
    local spent, startT, endT = getSpentDiamond(localdata)
    return {
        _type = "diamond_consume",
        _title = "钻石消费返利",
        _desc = "活动期间累计消费钻石即可领取丰厚奖励，消费越多奖励越丰厚！",
        _rules = "1.活动期间累计消费指定数量钻石即可领取对应奖励\n2.每个档位奖励只能领取一次\n3.每周一重置消费进度",
        _start_time = startT,
        _end_time = endT,
        _amount = spent,
        _rewards = {
            {
                _type = "money", _id = 0, _amount = 50000,
                _dailyjob = { _id = "act_dia_200", _task_target = 200, _last_rewards_time = localdata.activity_claimed and localdata.activity_claimed["act_dia_200"] and 1 or 0 }
            },
            {
                _type = "item", _id = 14001, _amount = 3,
                _dailyjob = { _id = "act_dia_500", _task_target = 500, _last_rewards_time = localdata.activity_claimed and localdata.activity_claimed["act_dia_500"] and 1 or 0 }
            },
            {
                _type = "item", _id = 14002, _amount = 2,
                _dailyjob = { _id = "act_dia_1000", _task_target = 1000, _last_rewards_time = localdata.activity_claimed and localdata.activity_claimed["act_dia_1000"] and 1 or 0 }
            },
            {
                _type = "rmb", _id = 0, _amount = 200,
                _dailyjob = { _id = "act_dia_2000", _task_target = 2000, _last_rewards_time = localdata.activity_claimed and localdata.activity_claimed["act_dia_2000"] and 1 or 0 }
            },
        }
    }
end

local function buildTavernBonusActivity(actType, title, desc, spent, startT, endT)
    return {
        _type = actType,
        _title = title,
        _desc = desc,
        _rules = "活动期间可享受优惠抽卡",
        _start_time = startT,
        _end_time = endT,
        _amount = spent or 0,
        _rewards = {
            {
                _type = "money", _id = 0, _amount = 10000,
                _dailyjob = { _id = "act_" .. actType, _task_target = 1, _last_rewards_time = 0 }
            }
        }
    }
end

local function generateActivities(localdata)
    local activities = {}
    local startT, endT = getActivityPeriod()

    table.insert(activities, buildDiamondConsumeActivity(localdata))

    table.insert(activities, buildTavernBonusActivity(
        "single_br_tavern", "青铜单抽优惠", "活动期间青铜单抽享受优惠价格", 0, startT, endT))
    table.insert(activities, buildTavernBonusActivity(
        "combo_br_tavern", "青铜十连优惠", "活动期间青铜十连享受优惠价格", 0, startT, endT))

    return activities
end

-- 跟踪钻石消费（供其他handler调用）
local function trackDiamondSpent(localdata, amount)
    if not amount or amount <= 0 then return end
    local spent, _, _ = getSpentDiamond(localdata)
    localdata.activity_spent.amount = spent + amount
    LocalData.save(localdata)
end

-- activity_info: 登录时活动信息
M.handlers.activity_info = function(data, obj, localdata)
    local activities = generateActivities(localdata)
    data._activity_info_reply = { _activities = activities }
end

-- activity_lotto_info: 活动抽奖信息
M.handlers.activity_lotto_info = function(data, obj, localdata)
    data._activity_lotto_info_reply = {}
end

-- activity_lotto_reward: 活动抽奖奖励
M.handlers.activity_lotto_reward = function(data, obj, localdata)
    data._activity_lotto_reward_reply = { _result = "success" }
end

-- activity_bigpackage_info: 大礼包信息
M.handlers.activity_bigpackage_info = function(data, obj, localdata)
    data._activity_bigpackage_info_reply = {}
end

-- activity_bigpackage_reward: 大礼包奖励
M.handlers.activity_bigpackage_reward = function(data, obj, localdata)
    data._activity_bigpackage_reward_reply = { _result = "success" }
end

-- activity_bigpackage_reset: 大礼包重置
M.handlers.activity_bigpackage_reset = function(data, obj, localdata)
    data._activity_bigpackage_reset_reply = { _result = "success" }
end

-- continue_pay: 连续充值
M.handlers.continue_pay = function(data, obj, localdata)
    data._continue_pay_reply = {}
end

-- every_day_happy: 每日惊喜
M.handlers.every_day_happy = function(data, obj, localdata)
    data._every_day_happy_reply = {}
end

-- charge: 充值
M.handlers.charge = function(data, obj, localdata)
    data._charge_reply = { _result = "success" }
end

-- ask_activity_info: 查询活动信息
M.handlers.ask_activity_info = function(data, obj, localdata)
    local activities = generateActivities(localdata)
    data._ask_activity_info_reply = { _activity_info = activities }
end

-- chapter_star_reward: 章节星数奖励（查询或领取）
-- obj: { _chapter_id = N, _tier = N(可选，有则领取，无则查询) }
M.handlers.chapter_star_reward = function(data, obj, localdata)
    local chapterId = obj and obj._chapter_id
    if not chapterId then
        data._chapter_star_reward_reply = { _result = "fail" }
        return
    end
    local tier = obj._tier
    if tier then
        -- 领取奖励
        local ok, rewards = ed.player:claimChapterStarReward(chapterId, tier)
        if ok then
            data._chapter_star_reward_reply = {
                _result = "success",
                _chapter_id = chapterId,
                _tier = tier,
                _rewards = rewards,
            }
        else
            data._chapter_star_reward_reply = { _result = "fail" }
        end
    else
        -- 查询状态
        local status, totalStars = ed.player:getChapterStarStatus(chapterId)
        data._chapter_star_reward_reply = {
            _result = "success",
            _chapter_id = chapterId,
            _total_stars = totalStars,
            _tiers = status,
        }
    end
end

-- suspend_report: 暂停报告
M.handlers.suspend_report = function(data, obj, localdata)
    -- 无需回复
end

-----------------------------------------------------------------------
-- 简化 dispatch：处理本地模式下的服务器回复
-- 只负责调用 ed.netreply 中注册的回调函数，重置状态
-----------------------------------------------------------------------
local function local_dispatch(msg)
    local data = rawget(msg, ".data")
    if type(data) ~= "table" then return end

    -- tavern_draw_reply：处理酒馆抽取结果
    -- 模拟 network.lua:1260-1321 的关键逻辑
    if data._tavern_draw_reply then
        local reply = data._tavern_draw_reply
        local loot = reply._item_ids or {}
        -- 处理掉落物品（安全调用，忽略错误）
        for k, v in pairs(loot) do
            pcall(function()
                local id = ed.bits(v, 0, 10)
                local amount = ed.bits(v, 10, 11)
                local it = ed.itemType(id)
                if it == "hero" then
                    ed.player:addHero(id)
                elseif it == "equip" then
                    ed.player:addEquip(id, amount)
                end
            end)
        end
        pcall(function() ed.saveDirty = true end)
        -- 扣费处理
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
        -- 调用回调（这会重置 isTaverning）
        LegendLog("[local_dispatch] tavern_draw_reply, calling netreply.tavern, loot_count=" .. tostring(#loot))
        local handler = ed.netreply and ed.netreply.tavern
        if handler then
            local nd = ed.netdata
            local isStone = nd and nd.tavern and nd.tavern.type == "stone"
            local ok, err
            if isStone then
                -- stone 类型传两个参数，与原版 network.lua:1314-1315 一致
                local heroes = reply._new_heroes or {}
                ok, err = pcall(handler, loot, heroes)
            else
                ok, err = pcall(handler, loot)
            end
            if not ok then
                LegendLog("[local_dispatch] tavern callback ERROR: " .. tostring(err))
            end
            ed.netreply.tavern = nil
        else
            LegendLog("[local_dispatch] WARNING: no tavern callback registered!")
        end
    end

    -- chat_reply: 聊天回复，触发 FireEvent("ChatRsp")
    if data._say then
        pcall(function()
            if FireEvent then FireEvent("ChatRsp", data) end
        end)
        local handler = ed.netreply and ed.netreply.chatSay
        if handler then
            pcall(handler, data._say._result == "success")
            ed.netreply.chatSay = nil
        end
    end

    -- guild_reply: 公会回复，触发 FireEvent("GuildRsp")
    if data._guild_reply then
        pcall(function()
            if FireEvent then FireEvent("GuildRsp", data._guild_reply) end
        end)
    end

    -- ladder_reply: 天梯回复，触发 FireEvent("pvpRsp")
    if data._ladder_reply then
        pcall(function()
            if FireEvent then FireEvent("pvpRsp", data._ladder_reply) end
        end)
    end

    -- query_ranklist_reply: 通用排行榜回复
    if data._query_ranklist_reply then
        local handler = ed.getNetReply("query_ranklist")
        if handler then
            local ok, err = pcall(handler, data._query_ranklist_reply)
            if not ok then LegendLog("[local_dispatch] query_ranklist callback ERROR: " .. tostring(err)) end
        end
    end

    -- top_arena_reply: 巅峰竞技场排行榜回复
    if data._top_arena_reply then
        local handler = ed.getNetReply("top_arena")
        if handler then
            pcall(handler, data._top_arena_reply)
        end
    end

    -- query_pvp_ranklist_reply: PVP竞技场排行榜回复
    if data._query_pvp_ranklist_reply then
        local handler = ed.getNetReply("query_pvp_ranklist")
        if handler then
            pcall(handler, data._query_pvp_ranklist_reply)
        end
    end

    -- ask_magicsoul_reply：魂匣英雄列表
    if data._ask_magicsoul_reply then
        local ids = data._ask_magicsoul_reply
        LegendLog("[local_dispatch] ask_magicsoul_reply, ids_count=" .. tostring(type(ids) == "table" and #ids or "non-table"))
        local handler = ed.netreply and ed.netreply.askMagicsoul
        if handler then
            pcall(handler, ids)
            ed.netreply.askMagicsoul = nil
        end
    end

    -- _reset: GM 命令或删号重练返回的完整玩家数据
    if data._reset then
        LegendLog("[local_dispatch] _reset: refreshing player data")
        local user = data._reset._user
        LegendLog("[local_dispatch] user=" .. tostring(user) .. " ed.player=" .. tostring(ed.player))
        if user and ed.player and ed.player.setup then
            LegendLog("[local_dispatch] calling ed.player:setup, user._money=" .. tostring(user._money) .. " user._rmb=" .. tostring(user._rmb))
            local ok_s, err_s = pcall(function() ed.player:setup(user) end)
            if not ok_s then
                LegendLog("[local_dispatch] player:setup ERROR: " .. tostring(err_s))
            else
                LegendLog("[local_dispatch] player:setup OK, ed.player._money=" .. tostring(ed.player._money))
            end
        else
            LegendLog("[local_dispatch] MISSING: user=" .. tostring(user ~= nil) .. " player=" .. tostring(ed.player ~= nil) .. " setup=" .. tostring(ed.player and ed.player.setup ~= nil))
        end
        -- 刷新主界面显示
        pcall(function()
            if FireEvent then
                LegendLog("[local_dispatch] firing LoginSuc")
                FireEvent("LoginSuc")
            else
                LegendLog("[local_dispatch] WARNING: FireEvent not found!")
            end
        end)
    end

    -- ========== 以下为 stubSend 回退路径中的回复处理 ==========
    -- 当 local_server.handle() 成功但 ed.dispatch 不可用时，
    -- local_dispatch 必须处理所有回复类型，否则回调不会被触发

    -- sync_skill_stren / buy_skill_stren_point 回复
    if data._sync_skill_stren_reply then
        local reply = data._sync_skill_stren_reply
        if reply._skill_level_up and ed.player then
            ed.player._skill_level_up = reply._skill_level_up
        end
        local handler, rdata = ed.getNetReply("sync_skill_stren_chance")
        if rdata and rdata.cost then pcall(function() ed.player:addrmb(-rdata.cost) end) end
        if handler then
            handler()
        else
            -- 购买技能点时 handler 为 nil，需要手动刷新技能面板的 times bar
            pcall(function()
                local sw = ed.getPopWindow and ed.getPopWindow("herodetailskill")
                if sw and sw.createInformationBar then
                    sw:createInformationBar()
                end
            end)
        end
        pcall(function() ed.saveDirty = true end)
    end

    -- skill_levelup 回复
    if data._skill_levelup_reply then
        if ed.ui and ed.ui.herodetail and ed.ui.herodetail.dealSkillLevelup then
            ed.ui.herodetail.dealSkillLevelup(data._skill_levelup_reply)
        end
    end

    -- hero_upgrade 回复（英雄进阶）
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
        if result and hero then
            pcall(function()
                -- 进阶后清空装备槽，用新阶的空槽替换
                hero._items = {}
                for i = 1, 6 do
                    hero._items[i] = {_item_id = 0, _exp = 0}
                end
                ed.player:resetHero(hero)
            end)
        end
        if ed.netreply and ed.netreply.heroUpgradeReply then
            ed.netreply.heroUpgradeReply(result, props)
            ed.netreply.heroUpgradeReply = nil
        end
    end

    -- hero_evolve 回复（英雄进化/召唤）
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
                    ed.player:addHero(ndata.hid)
                end
                ed.player:resetHero(hero)
            end)
            ed.netdata.evolve = nil
            pcall(function() ed.saveDirty = true end)
        end
        if ed.netreply and ed.netreply.evolve then
            ed.netreply.evolve(result)
            ed.netreply.evolve = nil
        end
    end

    -- wear_equip 回复（穿戴装备）
    if data._wear_equip_reply then
        local reply = data._wear_equip_reply
        local result = reply._result == "success"
        local gs = reply._gs
        if ed.netdata and ed.netdata.putonReply then
            pcall(function()
                local rdata = ed.netdata.putonReply
                ed.player:consumeEquip(rdata.eid, 1)
                ed.player.heroes[rdata.hid]:equip(rdata.sid)
                ed.player.heroes[rdata.hid]:resetgs(gs)
            end)
            ed.netdata.putonReply = nil
            pcall(function() ed.saveDirty = true end)
        end
        if ed.netreply and ed.netreply.putonReply then
            ed.netreply.putonReply(result)
            ed.netreply.putonReply = nil
        end
    end

    -- enter_stage 回复
    if data._enter_stage_reply then
        if ed.netreply and ed.netreply.enterStage then
            ed.netreply.enterStage()
            ed.netreply.enterStage = nil
        end
        pcall(function() ed.srand(data._enter_stage_reply._rseed) end)
        if ed.player then ed.player.loots = data._enter_stage_reply._loots or {} end
    end

    -- midas 回复
    if data._midas_reply then
        pcall(function() ed.ui.midas.dealUse(data._midas_reply) end)
    end

    -- activity_notify: 活动通知（登录时附带）
    if data._activity_notify then
        pcall(function()
            if FireEvent then FireEvent("activityNotify", data._activity_notify) end
        end)
    end

    -- ask_activity_info 回复
    if data._ask_activity_info_reply then
        local reply = data._ask_activity_info_reply
        pcall(function()
            if FireEvent then FireEvent("getActivities", reply._activity_info or {}) end
        end)
    end

    -- activity_info 回复（状态栏活动按钮）
    if data._activity_info_reply then
        local handler = ed.getNetReply("GotoActivity")
        if handler then
            pcall(handler, data._activity_info_reply)
        end
    end

    -- chapter_star_reward 回复
    if data._chapter_star_reward_reply then
        local reply = data._chapter_star_reward_reply
        local handler = ed.netreply and ed.netreply.chapterStarReward
        if handler then
            pcall(handler, reply)
            ed.netreply.chapterStarReward = nil
        end
    end

    -- get_svr_time 回复
    if data._svr_time then
        pcall(function() ed.player:initNativeTimeDiff(data._svr_time) end)
        local handler = ed.netreply and ed.netreply.syncTime
        if handler then
            pcall(function() handler() end)
            ed.netreply.syncTime = nil
        end
    end

    -- ask_daily_login 回复
    if data._ask_daily_login_reply then
        local reply = data._ask_daily_login_reply
        local result = reply._result == "success" or reply._result == 0
        local reward = {
            items = reply._items or {},
            heroes = reply._hero or {},
            diamond = reply._diamond or 0,
        }
        local ndata = ed.netdata and ed.netdata.dailylogin
        if result and ndata then
            pcall(function() ed.player:recievedDailyLoginReward(ndata.type) end)
        end
        local handler = ed.netreply and ed.netreply.dailylogin
        if handler then
            pcall(function() handler(result, reward) end)
            ed.netreply.dailylogin = nil
        end
        ed.netdata.dailylogin = nil
    end

    -- exit_stage 回复
    if data._exit_stage_reply then
        local result = data._exit_stage_reply._result == "known"
        LegendLog("[local_dispatch] exit_stage_reply: result=" .. tostring(result) .. " netreply=" .. tostring(ed.netreply ~= nil) .. " exitStageReply=" .. tostring(ed.netreply and ed.netreply.exitStageReply ~= nil))
        if ed.netreply and ed.netreply.exitStageReply then
            LegendLog("[local_dispatch] calling exitStageReply(" .. tostring(result) .. ")")
            ed.netreply.exitStageReply(result)
            ed.netreply.exitStageReply = nil
        else
            LegendLog("[local_dispatch] WARNING: exitStageReply callback is nil!")
        end
        if ed.netdata then ed.netdata.exitStageReply = nil end
    else
        -- 诊断：检查 data 中有哪些 key
        local keys = {}
        for k, _ in pairs(data) do keys[#keys+1] = k end
        LegendLog("[local_dispatch] NO _exit_stage_reply in data, keys: " .. table.concat(keys, ","))
    end

    -- ladder / PVP 回复
    if data._ladder_reply then
        LegendLog("[local_dispatch] processing _ladder_reply, has_start_battle=" .. tostring(data._ladder_reply._start_battle ~= nil) .. " has_callback=" .. tostring(ed.netreply.gotoPvpBattleReply ~= nil))
        if FireEvent then
            FireEvent("pvpRsp", data._ladder_reply)
        end
        if ed.netreply.gotoPvpBattleReply and data._ladder_reply._start_battle then
            local enemyList = data._ladder_reply._start_battle._heroes
            local selfList = data._ladder_reply._start_battle._self_heroes
            local isBot = data._ladder_reply._start_battle._is_robot
            isBot = isBot and isBot > 0
            LegendLog("[local_dispatch] calling gotoPvpBattleReply, enemies=" .. tostring(#enemyList) .. " self=" .. tostring(#selfList) .. " isBot=" .. tostring(isBot))
            ed.netreply.gotoPvpBattleReply(enemyList, isBot, selfList)
            ed.srand(data._ladder_reply._start_battle._rseed)
            if FireEvent then
                FireEvent("StartPVPBattle")
            end
        end
        if ed.netreply.exitStageReply and data._ladder_reply._end_battle then
            local r = data._ladder_reply._end_battle._result
            if r == "victory" then r = 0 elseif r == "defeat" then r = 1 end
            ed.netreply.exitStageReply(r, data._ladder_reply._end_battle)
            ed.netreply.exitStageReply = nil
        end
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

    -- equip_synthesis 回复（装备合成）
    if data._equip_synthesis_reply then
        local result = data._equip_synthesis_reply._result == "success"
        local rdata = ed.netdata and ed.netdata.equipCraft
        if result and rdata then
            pcall(function()
                ed.player:addMoney(-rdata.expense)
                local na = rdata.consume
                for k, v in pairs(rdata.node) do
                    ed.player:consumeEquip(v, na[k] or 1)
                end
                ed.player:addEquip(rdata.id)
            end)
            pcall(function() ed.saveDirty = true end)
        end
        if ed.netreply and ed.netreply.craftReply then
            ed.netreply.craftReply(result)
            ed.netreply.craftReply = nil
        end
    end

    -- fragment_compose 回复（碎片合成）
    if data._fragment_compose_reply then
        local result = data._fragment_compose_reply._result == "success"
        local info = ed.netdata and ed.netdata.fragmentCompose
        if result and info then
            pcall(function()
                ed.player:addMoney(-info.cost)
                ed.player:consumeEquip(info.id, info.fragmentAmount)
                if info.makeId > 100 then
                    ed.player:addEquip(info.makeId)
                end
            end)
            pcall(function() ed.saveDirty = true end)
        end
        if ed.netreply and ed.netreply.composeFragmentReply then
            ed.netreply.composeFragmentReply(result)
            ed.netreply.composeFragmentReply = nil
        end
    end

    -- hero_equip_upgrade 回复（英雄装备升级）
    if data._hero_equip_upgrade_reply then
        local result = data._hero_equip_upgrade_reply._result == "success"
        local hero = data._hero_equip_upgrade_reply._hero
        if result and hero then pcall(function() ed.player:resetHero(hero) end) end
        pcall(function() ed.saveDirty = true end)
        local handler = ed.netreply and ed.netreply.equipUpgrade
        if handler then handler(result); ed.netreply.equipUpgrade = nil end
    end

    -- sweep_stage 回复（扫荡）
    if data._sweep_stage_reply then
        local reply = data._sweep_stage_reply
        pcall(function()
            for k, v in pairs(reply._loot or {}) do
                ed.player:addExp(v._exp, "sweep")
                ed.player:addMoney(v._money)
                for ck, cv in pairs(v._items or {}) do
                    ed.player:addEquip(ed.bits(cv, 0, 10), ed.bits(cv, 10, 11))
                end
            end
            -- Raid Bonus 额外奖励
            for ck, cv in pairs(reply._items or {}) do
                ed.player:addEquip(ed.bits(cv, 0, 10), ed.bits(cv, 10, 11))
            end
        end)
        local sdata = ed.netdata and ed.netdata.sweep
        if sdata then
            pcall(function()
                ed.player:addVitality(-(sdata.power or 0) * (sdata.times or 1))
                if sdata.type == "free" then
                    ed.player:useSweepTimes(sdata.times)
                else
                    ed.player._rmb = (ed.player._rmb or 0) - (sdata.cost or 0)
                end
            end)
            ed.netdata.sweep = nil
        end
        if ed.netreply and ed.netreply.sweep then
            ed.netreply.sweep(reply)
            ed.netreply.sweep = nil
        end
        ed.sweep_dirty = true
    end

    -- consume_item 回复（消耗品/吃经验）
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
        pcall(function() ed.saveDirty = true end)
        if ed.saveGame then pcall(function() ed.saveGame() end) end
    end

    -- sync_vitality / buy_vitality 回复
    if data._sync_vitality_reply then
        local reply = data._sync_vitality_reply
        ed.player._vitality = reply._vitality
        local rdata = ed.netdata and ed.netdata.buyVitality
        if rdata and rdata.isBuy then
            ed.player._rmb = ed.player._rmb - rdata.cost
            if ed.netreply and ed.netreply.buyVitalityReply then
                ed.netreply.buyVitalityReply()
                ed.netreply.buyVitalityReply = nil
            end
            ed.netdata.buyVitality = nil
            pcall(function() ed.saveDirty = true end)
        end
    end

    -- set_name 回复
    if data._set_name_reply then
        local result = data._set_name_reply._result
        local rdata = ed.netdata and ed.netdata.setname
        if result == "success" and rdata then
            pcall(function()
                ed.player:setName(rdata.name or "")
                ed.player:addrmb(-(rdata.cost or 0))
                ed.player:refreshSetNameTime()
            end)
            ed.netdata.setname = nil
            pcall(function() ed.saveDirty = true end)
        end
        if ed.netreply and ed.netreply.setname then
            ed.netreply.setname(result)
            ed.netreply.setname = nil
        end
    end

    -- set_avatar 回复
    if data._set_avatar_reply then
        local result = data._set_avatar_reply._result == "success"
        local rdata = ed.netdata and ed.netdata.setAvatar
        if rdata and result then
            pcall(function() ed.player:setAvatar(rdata.id) end)
        end
        if ed.netreply and ed.netreply.setAvatar then ed.netreply.setAvatar(result) end
    end

    -- tutorial 回复
    if data._tutorial_reply then
        if ed.netdata then ed.netdata.tutorial = nil end
        if ed.netreply and ed.netreply.tutorial then
            ed.netreply.tutorial()
            ed.netreply.tutorial = nil
        end
    end

    -- trigger_task / require_rewards 回复
    if data._trigger_task_reply then
        if ed.netreply and ed.netreply.triggerTask then
            ed.netreply.triggerTask(data._trigger_task_reply._result)
            ed.netreply.triggerTask = nil
        end
    end
    if data._require_rewards_reply then
        local result = data._require_rewards_reply._result == "success"
        if ed.netreply and ed.netreply.requireRewards then
            ed.netreply.requireRewards(result, ed.netdata and ed.netdata.requireRewards)
            ed.netreply.requireRewards = nil
            ed.netdata.requireRewards = nil
        end
    end

    -- job_rewards 回复（含活动奖励 tenPumping 分发）
    if data._job_rewards_reply then
        local result = data._job_rewards_reply._result == "success"
        if ed.netreply and ed.netreply.jobRewards then
            ed.netreply.jobRewards(result, ed.netdata and ed.netdata.jobRewards)
            ed.netreply.jobRewards = nil
            ed.netdata.jobRewards = nil
        end
        if ed.netreply and ed.netreply.tenPumping == "1" then
            if FireEvent then FireEvent("getPrize", data._job_rewards_reply) end
            ed.netreply.tenPumping = nil
        end
    end

    -- tbc (远征) 回复 — 通过 CrusadeRsp 事件传递给 crusade.lua
    if data._tbc_reply then
        if FireEvent then
            FireEvent("CrusadeRsp", data._tbc_reply)
        end
    end

    -- 邮件列表回复（仅 get_maillist 时触发）
    if data._mail_list and not data._read_mail_reply then
        pcall(function() ed.player:refreshMailData(data._mail_list._sys_mail_list) end)
        if ed.netreply and ed.netreply.getMail then
            ed.netreply.getMail()
            ed.netreply.getMail = nil
        end
    end

    -- read_mail 回复
    if data._read_mail_reply then
        local result = data._read_mail_reply._result == "success"
        if result then
            local rdata = ed.netdata and ed.netdata.readMail
            if rdata then
                pcall(function() ed.player:readMail(rdata.id) end)
            end
            -- 用服务端返回的剩余邮件列表刷新客户端数据
            if data._mail_list then
                pcall(function() ed.player:refreshMailData(data._mail_list._sys_mail_list) end)
            end
        end
        if ed.netreply and ed.netreply.readMail then
            ed.netreply.readMail()
            ed.netreply.readMail = nil
        end
        ed.netdata.readMail = nil
    end

end

-----------------------------------------------------------------------
-- 初始化
-----------------------------------------------------------------------
function M.init()
    M.data = LocalData.load()
    -- 清空旧远征数据，强制用新战力逻辑重新生成
    if M.data and M.data.crusade then
        M.data.crusade = nil
        LocalData.save(M.data)
    end
    -- 确保 down 模块可用（供 M.handle 创建 down_msg 对象）
    if not down then
        -- 方式1: 从 ed.downmsg 获取（main.lua stub 会设置）
        if ed.downmsg then
            down = ed.downmsg
            LegendLog("[local_server] init: got 'down' from ed.downmsg")
        end
    end
    if not down then
        -- 方式2: 从全局查找
        down = rawget(_G, "down")
        if down then
            LegendLog("[local_server] init: got 'down' from _G")
        end
    end
    if not down then
        LegendLog("[local_server] init: WARNING: 'down' is nil, M.handle may not work")
    end
end

-----------------------------------------------------------------------
-- 主入口：处理消息
-- msg_type: 消息类型字符串（如 "login", "enter_stage" 等）
-- obj: 客户端发送的消息对象（up_msg 中的对应字段）
-----------------------------------------------------------------------
function M.handle(msg_type, obj)
    obj = obj or {}

    -- 诊断日志：关键消息类型始终记录
    local alwaysLog = { gm_cmd = true, login = true, tavern_draw = true }
    if alwaysLog[msg_type] then
        LegendLog("[local_server] >>> handle: " .. tostring(msg_type))
    end

    -- 创建 down_msg 对象并获取 .data 表
    local msg
    if down and down.down_msg then
        local ok_down
        ok_down, msg = pcall(function() return down.down_msg() end)
        if not ok_down then
            LegendLog("[local_server] ERROR: down.down_msg() failed: " .. tostring(msg))
            msg = nil
        end
    end
    -- 如果 down 不可用或返回空表，手动创建带 .data 的消息对象
    if not msg or not rawget(msg, ".data") then
        msg = setmetatable({[".data"] = {}}, {
            __index = function(m, k) return rawget(m, ".data")[k] end,
            __newindex = function(m, k, v) rawget(m, ".data")[k] = v end,
        })
    end
    local data = rawget(msg, ".data")

    -- 诊断：exit_stage 的处理追踪
    if msg_type == "exit_stage" then
        LegendLog("[local_server] handle exit_stage: obj._result=" .. tostring(obj._result) .. " handler=" .. tostring(M.handlers[msg_type] ~= nil))
    end

    local handler = M.handlers[msg_type]
    if handler then
        local ok_h, err_h = pcall(handler, data, obj, M.data)
        if not ok_h then
            LegendLog("[local_server] handler '" .. tostring(msg_type) .. "' ERROR: " .. tostring(err_h))
        end
    else
        LegendLog("[local_server] WARNING: no handler for '" .. tostring(msg_type) .. "'")
    end

    -- 诊断：handler 后检查 data 内容
    if msg_type == "exit_stage" then
        LegendLog("[local_server] after handler: _exit_stage_reply=" .. tostring(data._exit_stage_reply ~= nil) .. " ed.dispatch=" .. tostring(ed.dispatch ~= nil))
    end

    -- 使用 network.lua 的 dispatch 处理所有回复类型（40+ 消息类型）
    -- 注意：proc_net 在 localMode 下是空操作，必须直接调用 dispatch
    if ed.dispatch then
        local ok_d, err_d = xpcall(function() ed.dispatch(msg) end, function(err)
            LegendLog("[local_server|dispatch ERROR] " .. tostring(err))
        end)
        if not ok_d then
            LegendLog("[local_server] dispatch failed: " .. tostring(err_d))
        end
    else
        -- fallback: 使用 local_dispatch（仅处理部分回复类型）
        local ok_d, err_d = xpcall(function() local_dispatch(msg) end, function(err)
            LegendLog("[local_server|dispatch ERROR] " .. tostring(err))
        end)
        if not ok_d then
            LegendLog("[local_server] dispatch failed: " .. tostring(err_d))
        end
    end

    -- GM 命令 (_reset) 后刷新主界面（ed.dispatch 只做 player:setup，不触发 UI 刷新）
    local data = rawget(msg, ".data")
    if data and data._reset then
        pcall(function()
            if FireEvent then
                LegendLog("[local_server] _reset: firing LoginSuc to refresh UI")
                FireEvent("LoginSuc")
            end
        end)
    end
    return true
end

-----------------------------------------------------------------------
-- 拦截原始网络发送（替换 ed.send）
-----------------------------------------------------------------------
function M.install()
    M.init()

    -- 保存原始 ed.send（如果需要的话）
    M._originalSend = ed.send

    -- 替换 ed.send 为本地处理
    ed.send = function(obj, ttype, block)
        LegendLog("[local_server] Intercepted send: " .. tostring(ttype))
        -- 从 up_msg 对象中提取对应字段
        local field = "_" .. ttype
        local msgObj = obj[field]
        if msgObj then
            M.handle(ttype, msgObj)
        else
            -- 某些消息类型字段名不同，尝试直接传递
            M.handle(ttype, obj)
        end
        return true
    end

    LegendLog("[local_server] Local server installed, all network requests intercepted.")
end

-----------------------------------------------------------------------
-- 手动保存数据
-----------------------------------------------------------------------
function M.save()
    if M.data then
        LocalData.save(M.data)
    end
end

-----------------------------------------------------------------------
-- 手动重置数据
-----------------------------------------------------------------------
function M.resetData()
    M.data = LocalData.reset()
    LocalData.save(M.data)
end

return M
