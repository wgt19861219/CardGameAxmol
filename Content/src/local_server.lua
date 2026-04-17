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
    local tid = obj._hero_id or obj._tid
    local slot = obj._item_pos or obj._slot

    -- 使用运行时 ed.player 数据计算 GS（localdata 可能不同步）
    local gs = 0
    pcall(function()
        local hero = ed.player and ed.player.heroes[tid]
        local curGs = hero and hero._gs or 0
        local equipTable = ed.getDataTable("hero_equip")
        local equipDataTable = ed.getDataTable("equip")
        local rank = hero and hero._rank or 1
        local rankEquip = equipTable and equipTable[tid] and equipTable[tid][rank]
        local delta = 0
        if rankEquip and slot then
            local newItemId = rankEquip[string.format("Equip%d ID", slot)]
            if newItemId and equipDataTable and equipDataTable[newItemId] then
                local equipLevel = rankEquip.EquipLevel or 1
                delta = (tonumber(equipDataTable[newItemId]["GS"]) or 0) * equipLevel
            end
        end
        gs = math.max(math.floor(curGs + delta), 0)
    end)

    data._wear_equip_reply = {
        _result = "success",
        _gs = gs,
    }
end

-- ========== shop_refresh ==========
-- obj: 刷新商店请求
-- VIP经验商品使用特殊ID "vip_exp"
local VIP_EXP_SLOT = 1
local VIP_EXP_REWARD = 100
local VIP_EXP_PRICE = 200

local function generateShopGoods()
    local goods = {}
    -- Slot 1: VIP经验商品（固定）
    goods[1] = {
        _id = "vip_exp",
        _type = "diamond",
        _price = VIP_EXP_PRICE,
        _amount = 1,
        _is_sale = false,
    }
    -- Slot 2-6: 随机装备商品
    local equipIds = {101, 102, 103, 104, 105, 106, 107, 108, 109, 110,
                      111, 112, 113, 114, 115, 116, 117, 118, 119, 120}
    local shuffled = {}
    for _, id in ipairs(equipIds) do shuffled[#shuffled + 1] = id end
    for i = #shuffled, 2, -1 do
        local j = math.random(1, i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    for i = 1, math.min(5, #shuffled) do
        goods[i + 1] = {
            _id = shuffled[i],
            _type = "gold",
            _price = math.random(50, 500),
            _amount = 1,
            _is_sale = false,
        }
    end
    return goods
end

M.handlers.shop_refresh = function(data, obj, localdata)
    local shopId = (obj and obj._shop_id) or (obj and obj._id) or 1
    local goods = generateShopGoods()
    LegendLog("[shop_refresh] shopId=" .. tostring(shopId) .. " goods_count=" .. tostring(#goods))
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

    if not localdata.player then
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

    -- VIP经验商品：增加充值额度
    if goodsItem._id == "vip_exp" then
        localdata.player.recharge_sum = (localdata.player.recharge_sum or 0) + totalCost
    else
        -- 普通装备：添加到背包
        local eid = goodsItem._id
        if eid then
            localdata.player.equips = localdata.player.equips or {}
            local found = false
            for _, e in ipairs(localdata.player.equips) do
                if e.id == eid then
                    e.count = (e.count or 1) + amount
                    found = true
                    break
                end
            end
            if not found then
                table.insert(localdata.player.equips, { id = eid, count = amount })
            end
        end
    end

    -- 商品售罄
    goodsItem._amount = 0
    LocalData.save(localdata)
    data._shop_consume_reply = { _result = "success" }
end

-- ========== open_shop ==========
-- obj: { _shopid = N }
M.handlers.open_shop = function(data, obj, localdata)
    local shopId = obj._shopid or 1
    local goods = generateShopGoods()
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
    local hero, idx = findHero(localdata, tid)

    if hero then
        -- 解析 _order（packed 格式）
        local orders = obj._order or {}
        local totalUpgrades = 0
        for i, packed in ipairs(orders) do
            local slot = ed.bits(packed, 4, 11)
            local amount = ed.bits(packed, 0, 4)
            if slot >= 1 and slot <= #(hero.skill_levels or {}) then
                hero.skill_levels[slot] = (hero.skill_levels[slot] or 1) + (amount or 1)
                totalUpgrades = totalUpgrades + (amount or 1)
            end
        end
        -- 也兼容旧的 _skill_index 格式
        if totalUpgrades == 0 and obj._skill_index then
            local skillIdx = obj._skill_index
            if skillIdx >= 1 and skillIdx <= #(hero.skill_levels or {}) then
                hero.skill_levels[skillIdx] = (hero.skill_levels[skillIdx] or 1) + 1
            end
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
    data._ask_daily_login_reply = {
        _result = "success",
        _items = {},
        _hero = {},
        _diamond = 0,
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

-- get_vip_gift: VIP 礼包领取
M.handlers.get_vip_gift = function(data, obj, localdata)
    data._get_vip_gift_reply = { _result = "success" }
end

-- trigger_job: 触发任务
M.handlers.trigger_job = function(data, obj, localdata)
    data._trigger_job_reply = { _result = "success" }
end

-- job_rewards: 任务奖励
M.handlers.job_rewards = function(data, obj, localdata)
    data._job_rewards_reply = { _result = "success" }
end

-- activity_info: 活动信息
M.handlers.activity_info = function(data, obj, localdata)
    data._activity_info_reply = { _activities = {} }
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
    data._ask_activity_info_reply = { _activities = {} }
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
        -- 修复商店数据：确保有商品避免 market.lua upsetShopGoods 崩溃
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
                            {_id = 101, _type = "gold", _price = 100, _amount = 1, _is_sale = false},
                            {_id = 102, _type = "gold", _price = 200, _amount = 1, _is_sale = false},
                            {_id = "vip_exp", _type = "diamond", _price = 200, _amount = 1, _is_sale = false},
                        },
                    })
                    LegendLog("[local_dispatch] shop data force-initialized with placeholder goods")
                end
            end
        end)
        -- 覆盖 upsetShopGoods 防止空数组/单商品时 math.random 崩溃
        if ed.Player and ed.Player.upsetShopGoods then
            local _origUpset = ed.Player.upsetShopGoods
            ed.Player.upsetShopGoods = function(self, id, goods)
                if not goods or #goods == 0 then return {} end
                local gl = {}
                for i = 1, #goods do
                    gl[i] = { good = goods[i], slot = i }
                end
                return gl
            end
            LegendLog("[local_dispatch] upsetShopGoods override applied")
        end
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
        local newChance = reply._skill_level_up and reply._skill_level_up._skill_levelup_chance
        LegendLog("[LD] _sync_skill_stren_reply: newChance=" .. tostring(newChance))
        if reply._skill_level_up and ed.player then
            ed.player._skill_level_up = reply._skill_level_up
        end
        local handler, rdata = ed.getNetReply("sync_skill_stren_chance")
        LegendLog("[LD] getNetReply: handler=" .. tostring(handler ~= nil) .. " rdata=" .. tostring(rdata and rdata.cost))
        if rdata and rdata.cost then pcall(function() ed.player:addrmb(-rdata.cost) end) end
        if handler then
            handler()
        else
            -- 购买技能点时 handler 为 nil，需要手动刷新技能面板的 times bar
            LegendLog("[LD] no handler, trying manual UI refresh for skill panel")
            pcall(function()
                local sw = ed.getPopWindow and ed.getPopWindow("herodetailskill")
                LegendLog("[LD] getPopWindow result: " .. tostring(sw ~= nil) .. " hasCreateInfoBar=" .. tostring(sw and sw.createInformationBar ~= nil))
                if sw and sw.createInformationBar then
                    sw:createInformationBar()
                    LegendLog("[LD] createInformationBar called OK")
                end
            end)
        end
    end

    -- skill_levelup 回复
    if data._skill_levelup_reply then
        LegendLog("[LD] _skill_levelup_reply: result=" .. tostring(data._skill_levelup_reply._result) .. " gs=" .. tostring(data._skill_levelup_reply._gs))
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

    -- hero_evolve 回复（英雄进化）
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
            ed.netreply.requireRewards(result)
            ed.netreply.requireRewards = nil
        end
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

    -- 诊断：shop_refresh 的处理追踪
    if msg_type == "shop_refresh" then
        LegendLog("[local_server] handle shop_refresh: obj._shop_id=" .. tostring(obj and obj._shop_id) .. " handler=" .. tostring(M.handlers[msg_type] ~= nil))
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
    if msg_type == "shop_refresh" then
        LegendLog("[local_server] shop_refresh: _reply=" .. tostring(data._shop_refresh_reply ~= nil) .. " goods=" .. tostring(data._shop_refresh_reply and #data._shop_refresh_reply._current_goods or "nil") .. " dispatch=" .. tostring(ed.dispatch ~= nil))
    end
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
