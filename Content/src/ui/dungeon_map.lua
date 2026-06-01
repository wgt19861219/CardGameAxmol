local dungeon_map = {}
dungeon_map.__index = dungeon_map
local base = ed.ui.framework
setmetatable(dungeon_map, base.mt)
ed.ui.dungeon_map = dungeon_map

local panel
local dragPressX
local layerOriPos = ccp(0, 0)
local dragMode = false
local bosses = {}
local selectedBossIdx = nil
local param_mode = ""
local param_groupIds = {}
local groupBossCounts = {}
local groupBossOffset = {}
local acts = require("util.cocos2dx.actions")
local needRefreshOnEnter = false

-- 难度弹窗引用
local degreePopup = nil
local degreeButtons = {}

---------------------------------------------------
-- 远征坐标表（从crusadeconfig.lua原样复制）
-- 3个section，每个5个boss坐标
---------------------------------------------------
local crusadeBossPos = {
  { ccp(135, 260), ccp(210, 132), ccp(370, 211), ccp(548, 268), ccp(584, 126) },
  { ccp(121, 190), ccp(345, 130), ccp(278, 275), ccp(472, 283), ccp(584, 145) },
  { ccp(30, 265),  ccp(60, 120),  ccp(185, 230), ccp(375, 277), ccp(285, 130) },
}
-- 远征原版宝箱分布：section1=4个, section2=6个, section3=5个
local crusadeBoxPos = {
  { ccp(100, 155), ccp(350, 110), ccp(410, 310), ccp(488, 162) },
  { ccp(-10, 170), ccp(215, 117), ccp(320, 186), ccp(370, 305), ccp(468, 133), ccp(627, 262) },
  { ccp(-10, 175), ccp(157, 130), ccp(233, 310), ccp(350, 195), ccp(435, 125) },
}

-- 固定3个section，最多15个boss
local MAX_SECTIONS = 3
local MAX_BOSSES = 15

---------------------------------------------------
-- 从数据表获取某组Boss列表
---------------------------------------------------
local function getBossesForGroup(groupId)
  local dgTable = ed.getDataTable("ActStageGroupDungeon")
  local groupData = dgTable[groupId]
  local stageTable = ed.getDataTable("Stage")
  local stDungeon = ed.getDataTable("StageDungeon")

  if not groupData then
    local asTable = ed.getDataTable("ActStageGroup")
    groupData = asTable and asTable[groupId]
  end
  if not groupData then return {} end

  local result = {}
  for _, bossId in ipairs(groupData.Stages) do
    if bossId > 0 then
      local baseData = stDungeon[bossId] or (stageTable and stageTable[bossId])
      local bossName = ""
      if baseData then
        local nameField = baseData["Stage Name"] or baseData["Group Name"]
        if nameField then bossName = T(nameField) end
      end
      local boss = { baseId = bossId, name = bossName, difficulties = {} }
      local baseVit = (baseData and (baseData["Vitality Cost"] or baseData["Vit Cost"])) or 12
      local baseUnlock = (baseData and baseData["Unlock Level"]) or 1
      local vitScale = { 1.0, 1.3, 1.7, 2.0 }
      local unlockOffset = { 0, 5, 10, 15 }
      for diff = 1, 4 do
        local diffId = bossId + (diff - 1) * 1000
        local stageData = stDungeon[diffId]
        if stageData then
          table.insert(boss.difficulties, {
            id = diffId,
            vit = stageData["Vitality Cost"] or 12,
            keyCost = stageData["Key Cost"] or 0,
            unlockLevel = stageData["Unlock Level"] or 1,
            diff = diff,
          })
        else
          table.insert(boss.difficulties, {
            id = diffId,
            vit = math.ceil(baseVit * vitScale[diff]),
            keyCost = 0,
            unlockLevel = baseUnlock + unlockOffset[diff],
            diff = diff,
          })
        end
      end
      table.insert(result, boss)
    end
  end
  return result
end

---------------------------------------------------
-- 状态查询
---------------------------------------------------
local function isBossCleared(bossId)
  local stars = ed.player:getStageStar(bossId)
  return stars and stars > 0
end

-- Boss是否已解锁（第1个始终解锁，后续需要前一个通关）
local function isBossUnlocked(bossIdx)
  if bossIdx <= 1 then return true end
  if bossIdx > #bosses then return false end
  return isBossCleared(bosses[bossIdx - 1].baseId)
end

local function isGroupCleared(groupIdx)
  local count = groupBossCounts[groupIdx] or 0
  local offset = groupBossOffset[groupIdx] or 0
  for b = 1, count do
    local bossIdx = offset + b
    if bossIdx > #bosses then return false end
    if not isBossCleared(bosses[bossIdx].baseId) then return false end
  end
  return true
end

-- 子容器在dragContainer中的固定x偏移（与远征一致）
local subOffsetX = { 25, 752, 1477 }

-- 根据最右boss位置精确计算拖拽范围（不留多余空白）
local function calcMaxRight()
  local maxX = 0
  for i, boss in ipairs(bosses) do
    local s = boss.sectionIdx or 1
    local localIdx = i - (s - 1) * 5
    local posIdx = math.min(localIdx, 5)
    local positions = crusadeBossPos[s]
    if positions and positions[posIdx] then
      local absX = subOffsetX[s] + positions[posIdx].x
      if absX > maxX then maxX = absX end
    end
  end
  return math.min(0, 660 - maxX)
end

---------------------------------------------------
-- 拖拽触摸
---------------------------------------------------
local function dragLayerTouch(event, x, y)
  if not panel then return false end
  if not panel.dragLayer:getVisible() then return false end
  if degreePopup and degreePopup.mainLayer and not tolua.isnull(degreePopup.mainLayer) then return false end
  if degreePopup then degreePopup = nil end

  if event == "began" then
    dragPressX = x
    local cx, cy = panel.dragLayer.dragContainer:getPosition()
    layerOriPos = ccp(cx, cy)
  elseif event == "moved" then
    if not dragPressX then return end
    if math.abs(x - dragPressX) < 5 then return end
    local posX = layerOriPos.x + x - dragPressX
    posX = math.min(0, math.max(posX, calcMaxRight()))
    panel.dragLayer.dragContainer:setPosition(ccp(posX, layerOriPos.y))
    dragMode = true
  elseif event == "ended" then
    dragPressX = nil
    if dragMode then
      dragMode = false
      return
    end
    -- 非拖拽时检测boss点击
    local container = panel.dragLayer.dragContainer
    if container and #bosses > 0 then
      local ox, oy = container:getPosition()
      for i, boss in ipairs(bosses) do
        local sprite = panel.dragLayer[string.format("battle%d", i)]
        if sprite then
          local sub = panel.dragLayer[string.format("sub%d", boss.sectionIdx)]
          if sub then
            local sx, sy = sub:getPosition()
            local bx, by = sprite:getPosition()
            local worldX = ox + sx + bx
            local worldY = oy + sy + by
            if math.abs(x - worldX) < 40 and math.abs(y - worldY) < 40 then
              if isBossUnlocked(i) then
                dungeon_map.selectBoss(i)
              end
              return true
            end
          end
        end
      end
    end
  end
  return true
end

---------------------------------------------------
-- 刷新Boss节点状态
---------------------------------------------------
local function refreshBattleState()
  if not panel then return end
  for i, boss in ipairs(bosses) do
    local sprite = panel.dragLayer[string.format("battle%d", i)]
    local box = panel.dragLayer[string.format("box%d", i)]
    local cleared = isBossCleared(boss.baseId)

    if sprite and cleared then
      ed.setSpriteGray(sprite)
    end

    if box and cleared then
      local tex = CCTextureCache:sharedTextureCache():addImage("UI/alpha/HVGA/crusade/crusade_box_bronze_open.png")
      if tex and box.setTexture then box:setTexture(tex) end
    end
  end
end

---------------------------------------------------
-- 迷雾消散动画（远征风格）
---------------------------------------------------
local function refreshFogAnimation()
  if not panel then return end
  for s = 1, MAX_SECTIONS do
    local fog = panel.dragLayer[string.format("fog%d", s)]
    if fog and isGroupCleared(s) then
      fog:runAction(acts.sequence({
        CCFadeOut:create(0.5),
        CCCallFunc:create(function() fog:setVisible(false) end),
      }))
    end
  end
end

---------------------------------------------------
-- 单boss难度弹窗（完全照搬exercise createDegree风格）
---------------------------------------------------
local iconres = {
  "UI/alpha/HVGA/act/act_icon_difficulty_1.png",
  "UI/alpha/HVGA/act/act_icon_difficulty_2.png",
  "UI/alpha/HVGA/act/act_icon_difficulty_3.png",
  "UI/alpha/HVGA/act/act_icon_difficulty_4.png"
}

local function destroyPopup()
  if degreePopup then
    xpcall(function()
      if degreePopup.mainLayer and not tolua.isnull(degreePopup.mainLayer) then
        degreePopup.mainLayer:removeFromParentAndCleanup(true)
      end
    end, EDDebug)
    degreePopup = nil
    degreeButtons = {}
  end
end

local function showDegreePopup(bossIdx)
  destroyPopup()

  local boss = bosses[bossIdx]
  if not boss or #boss.difficulties == 0 then return end

  -- 照搬 exercise createDungeon 结构
  local mainLayer = CCLayerColor:create(ccc4(0, 0, 0, 150))
  local container = CCLayer:create()
  container:setAnchorPoint(ccp(0.5, 0.5))
  mainLayer:addChild(container)

  local ui = {}
  local ui_info = {
    {
      t = "Scale9Sprite",
      base = {
        name = "frame",
        res = "UI/alpha/HVGA/main_vit_tips.png",
        capInsets = CCRectMake(10, 10, 58, 26)
      },
      layout = { position = ccp(400, 220) },
      config = { scaleSize = CCSizeMake(705, 300) }
    },
    {
      t = "Sprite",
      base = {
        name = "close",
        res = "UI/alpha/HVGA/herodetail-detail-close.png"
      },
      layout = { position = ccp(750, 350) },
      config = {}
    },
    {
      t = "Sprite",
      base = {
        name = "close_press",
        res = "UI/alpha/HVGA/herodetail-detail-close-p.png",
        parent = "close"
      },
      layout = { anchor = ccp(0, 0), position = ccp(0, 0) },
      config = { visible = false }
    },
  }
  local readNode = ed.readnode.create(container, ui)
  readNode:addNode(ui_info)

  -- 标题（添加到frame上，和exercise create一样）
  local title_info = {
    {
      t = "Sprite",
      base = {
        name = "title_bg",
        res = "UI/alpha/HVGA/act/act_popup_bg.png"
      },
      layout = { position = ccp(352, 272) },
      config = { visible = false }
    },
    {
      t = "Label",
      base = {
        name = "title",
        text = boss.name or "",
        fontinfo = "ui_normal_button"
      },
      layout = { position = ccp(352, 272) },
      config = { color = ccc3(231, 206, 19) }
    },
  }
  local readNode2 = ed.readnode.create(ui.frame, ui)
  readNode2:addNode(title_info)

  -- 4个难度按钮（完全照搬 exercise createDegree 的布局）
  degreeButtons = {}
  local ox, oy = 97, 140
  local dx = 170
  local ly = 45

  for di, diff in ipairs(boss.difficulties) do
    local isUnlock = diff.unlockLevel <= ed.player:getLevel()

    local btn_info = {
      {
        t = "Sprite",
        base = {
          name = "button",
          res = "UI/alpha/HVGA/act/act_select_bg.png"
        },
        layout = { position = ccp(ox + dx * (di - 1), oy) },
        config = {}
      },
      {
        t = "Sprite",
        base = {
          name = "button_press",
          res = "UI/alpha/HVGA/act/act_select_bg_chosen.png",
          parent = "button"
        },
        layout = { anchor = ccp(0, 0), position = ccp(0, 0) },
        config = { visible = false }
      },
      {
        t = "Sprite",
        base = {
          name = "button_icon",
          res = iconres[di],
          parent = "button"
        },
        layout = { mediate = true },
        config = {}
      },
      {
        t = "Sprite",
        base = {
          name = "vit_bg",
          res = "UI/alpha/HVGA/act/act_comment_bg.png"
        },
        layout = { position = ccp(ox + dx * (di - 1), ly) },
        config = {}
      },
      {
        t = "Label",
        base = {
          name = "vit_number",
          text = tostring(diff.vit),
          size = 18
        },
        layout = {
          anchor = ccp(1, 0.5),
          position = ccp(ox + dx * (di - 1) - 5, ly)
        },
        config = { color = ccc3(233, 214, 181) }
      },
      {
        t = "Sprite",
        base = {
          name = "vit_icon",
          res = "UI/alpha/HVGA/vitalityicon.png"
        },
        layout = {
          anchor = ccp(0, 0.5),
          position = ccp(ox + dx * (di - 1) + 5, ly)
        },
        config = { fix_height = 35 }
      },
    }

    local btn_ui = {}
    local rn = ed.readnode.create(ui.frame, btn_ui)
    rn:addNode(btn_info)

    if not isUnlock then
      ed.setSpriteGray(btn_ui.button)
    end

    degreeButtons[di] = {
      button = btn_ui.button,
      press = btn_ui.button_press,
      diff = diff,
      isUnlock = isUnlock,
    }
  end

  -- 添加到场景
  local root = panel and panel.getRoot and panel:getRoot()
  if root then
    root:addChild(mainLayer, 200)
  end

  -- 弹出动画
  container:setScale(0)
  local s = CCScaleTo:create(0.2, 1)
  s = CCEaseBackOut:create(s)
  container:runAction(s)

  degreePopup = {
    mainLayer = mainLayer,
    container = container,
    ui = ui,
    bossIdx = bossIdx,
  }
  selectedBossIdx = bossIdx
end

---------------------------------------------------
-- 弹窗触摸处理
---------------------------------------------------
local pressDiffIdx = nil
local pressClose = false

local function popupTouchHandler(event, x, y)
  if not degreePopup or not degreePopup.mainLayer then return false end
  if tolua.isnull(degreePopup.mainLayer) then
    degreePopup = nil
    return false
  end

  if event == "began" then
    -- 检测关闭按钮
    if degreePopup.ui.close and ed.containsPoint(degreePopup.ui.close, x, y) then
      pressClose = true
      degreePopup.ui.close_press:setVisible(true)
      return true
    end
    -- 检测难度按钮
    for di, btn in ipairs(degreeButtons) do
      if btn.isUnlock and ed.containsPoint(btn.button, x, y) then
        pressDiffIdx = di
        btn.press:setVisible(true)
        return true
      end
    end
    -- 点击遮罩关闭
    destroyPopup()
    return true

  elseif event == "ended" then
    if pressClose then
      pressClose = false
      if degreePopup and degreePopup.ui then
        degreePopup.ui.close_press:setVisible(false)
        if degreePopup.ui.close and ed.containsPoint(degreePopup.ui.close, x, y) then
          destroyPopup()
        end
      end
      return true
    end
    if pressDiffIdx then
      local btn = degreeButtons[pressDiffIdx]
      btn.press:setVisible(false)
      if btn and btn.isUnlock and ed.containsPoint(btn.button, x, y) then
        -- 进入战斗（调用exercise的doDungeonGotoStage逻辑）
        local diffData = btn.diff
        local ul = diffData.unlockLevel
        if ul > ed.player:getLevel() then
          ed.showToast(T(LSTR("EXERCISE.YOU_CAN_ACCESS_HERE_ONCE_YOUR_CLAN_LEVEL_REACHES__D"), ul))
        elseif ed.player:getVitality() < diffData.vit then
          ed.showHandyDialog("buyVitality")
        else
          destroyPopup()
          local baseId = ed.getDungeonBaseStageId(diffData.id)
          ed._pendingDungeonDifficulty = diffData.diff
          local scene = ed.ui.stagedetail.createForExercise(baseId, {
            heroLimit = nil,
            actType = "dungeon",
            dungeonVit = diffData.vit,
            dungeonDailyLimit = 2
          })
          ed.pushScene(scene)
        end
      end
      pressDiffIdx = nil
      return true
    end
    pressDiffIdx = nil
    pressClose = false
    return true
  end
  return true
end

function dungeon_map.selectBoss(index)
  xpcall(function()
    showDegreePopup(index)
    -- 注册弹窗触摸
    if degreePopup and degreePopup.mainLayer then
      degreePopup.mainLayer:setTouchEnabled(true)
      degreePopup.mainLayer:registerScriptTouchHandler(popupTouchHandler, false, -135, true)
    end
  end, function(err)
    print("[DM] showDegreePopup ERROR: " .. tostring(err))
  end)
end

---------------------------------------------------
-- 场景创建（照搬远征：固定3个section，15个boss位）
---------------------------------------------------
function dungeon_map.create(param)
  param = param or {}
  param_mode = param.mode or "hero_trial"
  param_groupIds = param.groupIds or { 40001, 40002, 40003, 40004 }

  local newscene = base.create("dungeon_map")
  setmetatable(newscene, dungeon_map)

  -- 收集所有Boss数据
  bosses = {}
  groupBossCounts = {}
  groupBossOffset = {}
  for g, gid in ipairs(param_groupIds) do
    groupBossOffset[g] = #bosses
    local group = getBossesForGroup(gid)
    groupBossCounts[g] = #group
    for _, boss in ipairs(group) do
      table.insert(bosses, boss)
      if #bosses >= MAX_BOSSES then break end
    end
    if #bosses >= MAX_BOSSES then break end
  end

  -- 将boss分配到3个section（每个section最多5个）
  for i, boss in ipairs(bosses) do
    boss.sectionIdx = math.ceil(i / 5)
    if boss.sectionIdx > MAX_SECTIONS then boss.sectionIdx = MAX_SECTIONS end
  end

  -- 创建panel（固定3个section的UI配置）
  local dungeonmapconfig = require("gametable/dungeonmapconfig")
  local uiRes = dungeonmapconfig.buildUIRes()
  panel = panelMeta:new(newscene, uiRes)
  if not panel then return newscene end

  -- 在子容器中创建boss和box（照搬远征坐标）
  for i, boss in ipairs(bosses) do
    local s = boss.sectionIdx
    local sub = panel.dragLayer[string.format("sub%d", s)]
    if sub then
      local localIdx = i - (s - 1) * 5
      local posIdx = math.min(localIdx, 5)
      local imgIdx = (i - 1) % 15 + 1

      local bpos = crusadeBossPos[s][posIdx] or ccp(300, 200)

      local bossPath = string.format("UI/alpha/HVGA/crusade/stage/crusade_stage_%d.png", imgIdx)
      local bossSprite = CCSprite:create(bossPath)
      if bossSprite then
        bossSprite:setAnchorPoint(ccp(0.5, 0.5))
        bossSprite:setPosition(bpos)
        sub:addChild(bossSprite, 10)
      end

      panel.dragLayer[string.format("battle%d", i)] = bossSprite
    end
  end

  -- 宝箱
  for s = 1, MAX_SECTIONS do
    local sub = panel.dragLayer[string.format("sub%d", s)]
    if sub then
      local sectionBossCount = 0
      for _, boss in ipairs(bosses) do
        if boss.sectionIdx == s then sectionBossCount = sectionBossCount + 1 end
      end
      local boxCount = math.min(sectionBossCount, #crusadeBoxPos[s])
      for b = 1, boxCount do
        local boxp = crusadeBoxPos[s][b]
        if boxp then
          local box = CCSprite:create("UI/alpha/HVGA/crusade/crusade_box_bronze_closed.png")
          if box then
            box:setAnchorPoint(ccp(0.5, 0.5))
            box:setPosition(boxp)
            box:setScale(0.8)
            sub:addChild(box, 11)
            -- 用全局boss索引命名，让refreshBattleState能找到
            local bossIdx = (groupBossOffset[s] or 0) + b
            panel.dragLayer[string.format("box%d", bossIdx)] = box
          end
        end
      end
    end
  end

  -- 注意：ClippingNode在Android上不可用，不做裁剪
  -- dragContainer已由panelMeta添加到dragLayer中

  -- 远征风格迷雾：按section遮挡，挂在dragContainer上
  local dc = panel.dragLayer and panel.dragLayer.dragContainer
  if dc then
    for s = MAX_SECTIONS, 1, -1 do
      if not isGroupCleared(s) then
        local fogIdx = ((s - 1) % 4) + 1
        local fog = CCSprite:create(string.format("UI/alpha/HVGA/crusade/crusade_fog_%d.png", fogIdx))
        if fog then
          fog:setAnchorPoint(ccp(0, 0.5))
          fog:setPosition(ccp(subOffsetX[s], 210))
          fog:setScale(4.0)
          dc:addChild(fog, 20)
          panel.dragLayer[string.format("fog%d", s)] = fog
        end
      end
    end
  end

  -- 迷雾消散动画（远征风格）
  refreshFogAnimation()

  -- dragLayer触摸
  if panel.dragLayer and panel.dragLayer.mainLayer then
    panel.dragLayer.mainLayer:setTouchEnabled(true)
    panel.dragLayer.mainLayer:registerScriptTouchHandler(dragLayerTouch, false, -10, false)
  end

  refreshBattleState()

  newscene:registerOnEnterHandler("onEnterDungeon", function()
    if needRefreshOnEnter and panel then
      needRefreshOnEnter = false
      refreshBattleState()
      refreshFogAnimation()
    end
  end)
  newscene:registerOnExitHandler("onExitDungeon", function() end)
  newscene:registerOnPopSceneHandler("onPopSceneDungeon", function()
    destroyPopup()
    panel = nil
    bosses = {}
    groupBossCounts = {}
    groupBossOffset = {}
    selectedBossIdx = nil
    dragMode = false
    dragPressX = nil
    needRefreshOnEnter = false
  end)

  return newscene
end
