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
        _task = {},
        _task_finished = {},
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
        local rewardPro = stageCfg["UI reward" .. i .. " Pro"] or 100
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
    local tid = obj._hero_id or obj._tid
    local hero = ed.player and ed.player.heroes[tid]

    if hero then
        local newRank = (hero._rank or 1) + 1
        local gs = hero._gs or 0

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
    local payType = (shopId == 3) and "diamond" or "gold"
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
end

-- ========== trigger_task ==========
M.handlers.trigger_task = function(data, obj, localdata)
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
    -- drawType: 0=single, 1=combo(10x)
    -- boxType: 1=green(bronze), 2=blue(silver), 3=purple(gold), 4=magicsoul
    local itemIds = {}
    local newHeroes = {}

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
local CRUSADE_MAX_STAGE = 15

-- 可用英雄ID池（从 hero_equip 表提取）
local CRUSADE_HERO_POOL = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,
    21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40}

local AI_NAMES = {
    "暗影猎手","龙骑士","风暴法师","圣光骑士","血魔领主",
    "冰霜女王","烈焰术士","大地守卫","幽灵刺客","雷霆战神",
    "月光游侠","黑暗领主","星辰法师","铁甲战士","毒蛇猎手",
}

local function initCrusade(localdata)
    local cd = localdata.crusade
    if cd and cd.enemies and #cd.enemies > 0 then
        return cd
    end
    -- 生成15关的敌人数据
    local enemies = {}
    local playerLevel = localdata.player and localdata.player.level or 1
    local usedHeroes = {}
    for stage = 1, CRUSADE_MAX_STAGE do
        local stageEnemies = {}
        -- 难度递增：关卡越高，英雄等级/星级/阶位越高
        local baseLevel = math.min(playerLevel + stage * 2, 90)
        local baseStars = math.min(1 + math.floor(stage / 3), 5)
        local baseRank = math.min(1 + math.floor(stage / 4), 8)
        for i = 1, 5 do
            local hid
            repeat
                hid = CRUSADE_HERO_POOL[math_random(1, #CRUSADE_HERO_POOL)]
            until not usedHeroes[hid] or #usedHeroes > 30
            usedHeroes[hid] = true
            table.insert(stageEnemies, {
                _tid = hid,
                _level = baseLevel + math_random(-2, 2),
                _stars = baseStars,
                _rank = baseRank,
            })
        end
        local nameIdx = math_random(1, #AI_NAMES)
        enemies[stage] = {
            heroes = stageEnemies,
            name = AI_NAMES[nameIdx],
            level = baseLevel,
            avatar = CRUSADE_HERO_POOL[math_random(1, #CRUSADE_HERO_POOL)],
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
                local itemGroups = ed.getDataTable("ItemGroups")
                local tavernBoxType = ed.getDataTable("TavernBoxType")
                if itemGroups and tavernBoxType and id > 0 then
                    local boxInfo = tavernBoxType[id]
                    if boxInfo then
                        local boxEntry = boxInfo[0]
                        if boxEntry then
                            local groupId = boxEntry["Chest Group ID"]
                            local group = itemGroups[groupId]
                            if group then
                                local items = {}
                                for _, item in pairs(group) do
                                    table.insert(items, item)
                                end
                                if #items > 0 then
                                    local picked = items[math.random(1, #items)]
                                    table.insert(rewards, { _type = "item", _param1 = picked["id"], _param2 = picked["amout"] or 1 })
                                end
                            end
                        end
                    end
                end
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
M.handlers.guild = function(data, obj, localdata)
    data._guild_reply = data._guild_reply or {}
end

-- ladder: 天梯/PVP 系统，触发 FireEvent("pvpRsp")
M.handlers.ladder = function(data, obj, localdata)
    data._ladder_reply = data._ladder_reply or {}
end

-- excavate: 挖矿系统
M.handlers.excavate = function(data, obj, localdata)
    data._excavate_reply = data._excavate_reply or {}
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
            local ok, err = pcall(handler, loot)
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
