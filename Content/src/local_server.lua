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
        skill_data = { chance = 5, cd_time = 0, reset_times = 0, last_reset_date = 0 }
    end
    return {
        _skill_levelup_chance = skill_data.chance or 5,
        _skill_levelup_cd = skill_data.cd_time or 0,
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
        _task = {},
        _task_finished = {},
        _last_login = p.last_login or 0,
        _dailyjob = {},
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
        _sshop = nil,
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

-- 掉落物品生成（从 Stage 配置中读取）
local function generateLoots(stage_id)
    local loots = {}
    local StageTable = ed.getDataTable("Stage")
    if not StageTable then return loots end
    local stageCfg = StageTable[stage_id]
    if not stageCfg then return loots end

    for i = 1, 7 do
        local rewardId = stageCfg["UI reward" .. i]
        local rewardPro = stageCfg["UI reward" .. i .. " Pro"] or 0
        if rewardId and rewardId ~= 0 and math_random(1, 100) <= (rewardPro or 0) then
            local packed = ed.makebits(3, 1, 3, 1, 10, rewardId)
            table_insert(loots, packed)
        end
    end
    return loots
end

-- 获取关卡掉落的经验和金币
local function getStageRewards(stage_id)
    local StageTable = ed.getDataTable("Stage")
    if not StageTable then return 0, 0 end
    local stageCfg = StageTable[stage_id]
    if not stageCfg then return 0, 0 end
    return stageCfg["Exp Reward"] or 0, stageCfg["Money Reward"] or 0
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

    data._login_reply = {
        _result = "success",
        _user = buildUser(localdata),
        _time_zone = SERVER_TIMEZONE,
    }
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

-- ========== exit_stage ==========
-- obj: { _result = "victory"/"defeat"/..., _stars = N, _heroes = {...}, ... }
M.handlers.exit_stage = function(data, obj, localdata)
    local result = "known"
    local stage_id = localdata.battle and localdata.battle.stage_id or 0

    if stage_id > 0 then
        local battleResult = obj._result
        if battleResult == "victory" then
            local expReward, moneyReward = getStageRewards(stage_id)
            localdata.player.exp = localdata.player.exp + expReward
            localdata.player.gold = localdata.player.gold + moneyReward

            if not isEliteStage(stage_id) then
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

    data._exit_stage_reply = {
        _result = result,
    }
end

-- ========== hero_upgrade ==========
-- obj: { _tid = N } (英雄类型ID)
M.handlers.hero_upgrade = function(data, obj, localdata)
    local tid = obj._tid
    local hero, idx = findHero(localdata, tid)

    if hero then
        hero.rank = (hero.rank or 0) + 1
        hero.gs = (hero.gs or 100) + 50
        LocalData.save(localdata)

        data._hero_upgrade_reply = {
            _result = "success",
            _hero = buildHero(hero),
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
    local hero, idx = findHero(localdata, tid)

    if hero then
        hero.stars = (hero.stars or 1) + 1
        hero.gs = (hero.gs or 100) + 100
        LocalData.save(localdata)

        data._hero_evolve_reply = {
            _result = "success",
            _hero = buildHero(hero),
        }
    else
        data._hero_evolve_reply = {
            _result = "fail",
        }
    end
end

-- ========== consume_item ==========
-- obj: { _tid = item_id, ... }
M.handlers.consume_item = function(data, obj, localdata)
    -- 吃经验丹，找到消耗的物品对应英雄
    local hero = localdata.heroes[1]
    if hero then
        hero.exp = (hero.exp or 0) + 100
        LocalData.save(localdata)

        data._consume_item_reply = {
            _hero = buildHero(hero),
        }
    end
end

-- ========== equip_synthesis ==========
-- obj: 合成装备请求
M.handlers.equip_synthesis = function(data, obj, localdata)
    data._equip_synthesis_reply = {
        _result = "success",
    }
end

-- ========== wear_equip ==========
-- obj: { _tid = hero_tid, _slot = slot_index, _equip_id = equip_id }
M.handlers.wear_equip = function(data, obj, localdata)
    local tid = obj._tid
    local hero, idx = findHero(localdata, tid)

    if hero then
        local gs = (hero.gs or 100) + 20
        hero.gs = gs

        if hero.equips then
            -- 如果已有装备列表
        else
            hero.equips = {}
        end

        LocalData.save(localdata)

        data._wear_equip_reply = {
            _result = "success",
            _gs = gs,
        }
    else
        data._wear_equip_reply = {
            _result = "fail",
            _gs = 0,
        }
    end
end

-- ========== shop_refresh ==========
-- obj: 刷新商店请求
M.handlers.shop_refresh = function(data, obj, localdata)
    data._shop_refresh_reply = {
        _id = 1,
        _last_auto_refresh_time = getTimestamp(),
        _expire_time = 0,
        _last_manual_refresh_time = getTimestamp(),
        _today_times = 0,
        _current_goods = {},
    }
end

-- ========== shop_consume ==========
-- obj: 购买商品请求
M.handlers.shop_consume = function(data, obj, localdata)
    data._shop_consume_reply = {
        _result = "success",
    }
end

-- ========== open_shop ==========
-- obj: { _shopid = N }
M.handlers.open_shop = function(data, obj, localdata)
    data._open_shop_reply = {
        _result = "success",
        _shop = {
            _id = obj._shopid or 1,
            _last_auto_refresh_time = getTimestamp(),
            _expire_time = 0,
            _last_manual_refresh_time = getTimestamp(),
            _today_times = 0,
            _current_goods = {},
        },
    }
end

-- ========== skill_levelup ==========
-- obj: { _tid = hero_tid, _skill_index = N }
M.handlers.skill_levelup = function(data, obj, localdata)
    local tid = obj._tid
    local hero, idx = findHero(localdata, tid)

    if hero then
        local skillIdx = (obj._skill_index or 1)
        if skillIdx >= 1 and skillIdx <= #(hero.skill_levels or {}) then
            hero.skill_levels[skillIdx] = (hero.skill_levels[skillIdx] or 1) + 1
        end
        hero.gs = (hero.gs or 100) + 10
        LocalData.save(localdata)

        data._skill_levelup_reply = {
            _result = "success",
            _gs = hero.gs,
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
    local tid = obj._tid
    local hero, idx = findHero(localdata, tid)

    if hero then
        hero.gs = (hero.gs or 100) + 30
        LocalData.save(localdata)

        data._hero_equip_upgrade_reply = {
            _result = "success",
            _hero = buildHero(hero),
        }
    else
        data._hero_equip_upgrade_reply = {
            _result = "fail",
        }
    end
end

-- ========== trigger_task ==========
M.handlers.trigger_task = function(data, obj, localdata)
    data._trigger_task_reply = {
        _result = { "success" },
    }
end

-- ========== require_rewards ==========
M.handlers.require_rewards = function(data, obj, localdata)
    data._require_rewards_reply = {
        _result = "success",
    }
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
    local stage_id = obj._stage_id or 0
    local expReward, moneyReward = getStageRewards(stage_id)
    local sweepLoot = {
        {
            _exp = expReward,
            _money = moneyReward,
            _items = {},
        },
    }

    -- 生成掉落物品
    local StageTable = ed.getDataTable("Stage")
    if StageTable and StageTable[stage_id] then
        local stageCfg = StageTable[stage_id]
        for i = 1, 7 do
            local rewardId = stageCfg["UI reward" .. i]
            local rewardPro = stageCfg["UI reward" .. i .. " Pro"] or 0
            if rewardId and rewardId ~= 0 and math_random(1, 100) <= (rewardPro or 0) then
                table_insert(sweepLoot[1]._items, ed.makebits(11, 1, 10, rewardId))
            end
        end
    end

    data._sweep_stage_reply = {
        _loot = sweepLoot,
        _items = {},
    }
end

-- ========== tavern_draw ==========
-- obj: { _draw_type = "single"/"combo"/"free"/"stone", _box_type = "green"/"blue"/"purple"/... }
M.handlers.tavern_draw = function(data, obj, localdata)
    local drawType = obj._draw_type or "single"
    local boxType = obj._box_type or "green"
    local itemIds = {}
    local newHeroes = {}

    -- 简单掉落模拟：根据箱子品质给不同品质的物品
    local drawCount = 1
    if drawType == "combo" then
        drawCount = 10
    end

    for i = 1, drawCount do
        -- 随机生成一个装备 ID（100-599 范围）
        local equipId = math_random(100, 120)
        table_insert(itemIds, ed.makebits(11, 1, 10, equipId))
    end

    -- 小概率给英雄碎片
    if math_random(1, 10) <= 3 then
        local heroId = math_random(1, 5)
        table_insert(itemIds, ed.makebits(11, math_random(1, 3), 10, heroId))
    end

    data._tavern_draw_reply = {
        _item_ids = itemIds,
        _new_heroes = newHeroes,
        _smash_idx = {},
    }
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
    local acquireList = {}
    local costPerUse = 50
    local baseGold = 5000

    for i = 1, times do
        local moneyGain = baseGold * (i + (localdata.midas.today_times or 0))
        table_insert(acquireList, {
            _type = 1,
            _money = moneyGain,
        })
    end

    if localdata.player.diamond >= costPerUse * times then
        localdata.player.diamond = localdata.player.diamond - costPerUse * times
        localdata.midas.today_times = (localdata.midas.today_times or 0) + times
        localdata.midas.last_change = getTimestamp()
        LocalData.save(localdata)
    end

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
    -- 解锁所有关卡
    if obj._unlock_all_stages and obj._unlock_all_stages > 0 then
        localdata.stage.max_normal = 9999
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
                if type(tid) == "number" and tid > 0 and not existingTids[tid] then
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
                local hero, idx = findHero(localdata, tid)
                if hero then
                    if heroMsg._rank then hero.rank = heroMsg._rank end
                    if heroMsg._level then hero.level = heroMsg._level end
                    if heroMsg._stars then hero.stars = heroMsg._stars end
                    if heroMsg._exp then hero.exp = heroMsg._exp end
                    if heroMsg._gs then hero.gs = heroMsg._gs end
                end
            end
        end
    end

    -- 设置体力
    if obj._set_vitality then
        localdata.vitality.current = obj._set_vitality
    end

    -- 设置金币
    if obj._set_money then
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

    LocalData.save(localdata)

    -- GM 命令返回 _reset（完整 user 数据）
    data._reset = {
        _user = buildUser(localdata),
    }
end

-- ========== ask_daily_login ==========
M.handlers.ask_daily_login = function(data, obj, localdata)
    data._ask_daily_login_reply = {
        _result = "success",
        _items = {},
        _hero = {},
        _diamond = 0,
    }
end

-- ========== buy_skill_stren_point ==========
M.handlers.buy_skill_stren_point = function(data, obj, localdata)
    localdata.skill.chance = (localdata.skill.chance or 0) + 1
    LocalData.save(localdata)

    data._sync_skill_stren_reply = {
        _skill_level_up = buildSkillLevelUp(localdata.skill),
    }
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
-- 排行榜查询
-----------------------------------------------------------------------
M.handlers.query_ranklist = function(data, obj, localdata)
    local rankType = obj._rank_type or "top_gs"
    data._rank_type = rankType
    data._ranklist_item = {}
    data._self_ranking = 0
    data._self_prev_pos = 0
    data._self_item = {
        _user_summary = {
            _avatar = 1,
            _vip = 0,
            _name = localdata.player.name or "Player",
            _level = localdata.player.level or 1,
        },
        _param1 = 0,
    }
end

-----------------------------------------------------------------------
-- 竞技场排行榜 (top_arena)
-----------------------------------------------------------------------
M.handlers.top_arena = function(data, obj, localdata)
    data._rank_list = {}
    data._pos = 0
    data._prev_pos = 0
    data._self_rank = {
        _summary = {
            _avatar = 1,
            _vip = 0,
            _name = localdata.player.name or "Player",
            _level = localdata.player.level or 1,
        },
    }
end

-----------------------------------------------------------------------
-- TBC (远征/十字军)
-----------------------------------------------------------------------
M.handlers.tbc = function(data, obj, localdata)
    -- 返回空对手信息
    data._query_oppo = data._query_oppo or {}
    data._query_oppo._stage_id = obj._query_oppo and obj._query_oppo._stage_id or 1
    data._query_oppo._formation = {}
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
M.handlers.get_maillist = function(data, obj, localdata)
    data._mail_list = {}
end

M.handlers.read_mail = function(data, obj, localdata)
    data._id = obj._id or 0
    data._mail_content = ""
    data._reward_list = {}
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
-- 空响应的次要 handler
-----------------------------------------------------------------------
local EMPTY_HANDLERS = {
    "chat", "guild", "ladder", "excavate",
    "change_server", "cdkey_gift", "worldcup",
    "fb_attention", "get_vip_gift", "trigger_job", "job_rewards",
    "ask_magicsoul",
    "activity_info", "activity_lotto_info", "activity_lotto_reward",
    "activity_bigpackage_info", "activity_bigpackage_reward",
    "activity_bigpackage_reset",
    "continue_pay", "every_day_happy",
    "charge", "ask_activity_info",
    "suspend_report",
}

for _, msgType in ipairs(EMPTY_HANDLERS) do
    if not M.handlers[msgType] then
        M.handlers[msgType] = function(data, obj, localdata)
            -- 返回空响应，不做任何处理
        end
    end
end

-----------------------------------------------------------------------
-- 初始化
-----------------------------------------------------------------------
function M.init()
    M.data = LocalData.load()
    -- 确保 down 模块已加载
    if not down then
        pb_loader("down")()
    end
end

-----------------------------------------------------------------------
-- 主入口：处理消息
-- msg_type: 消息类型字符串（如 "login", "enter_stage" 等）
-- obj: 客户端发送的消息对象（up_msg 中的对应字段）
-----------------------------------------------------------------------
local _handle_diag_count = 0
function M.handle(msg_type, obj)
    obj = obj or {}
    _handle_diag_count = (_handle_diag_count or 0) + 1
    if _handle_diag_count % 50 == 0 then
        LegendLog("[local_server] Handled " .. tostring(msg_type) .. " (count=" .. _handle_diag_count .. ")")
    end

    -- 创建 down_msg 对象并获取 .data 表
    local msg = down.down_msg()
    local data = rawget(msg, ".data")

    local handler = M.handlers[msg_type]
    if handler then
        handler(data, obj, M.data)
    end

    -- 直接调用 dispatch
    xpcall(function() ed.dispatch(msg) end, function(err) LegendLog("[local_server|dispatch ERROR] " .. tostring(err)) end)
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
