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
local diffLayerNode
local diffBossLabel
local diffRows = {}

local diffNames = { "Normal", "Elite", "Hero", "Nightmare" }
local diffColors = {
  ccc3(100, 220, 100),
  ccc3(100, 150, 255),
  ccc3(180, 100, 255),
  ccc3(255, 80, 80),
}

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
  -- 裁剪区右边界=44+712=756，留足余量让最右boss完整显示
  return math.min(0, 660 - maxX)
end

---------------------------------------------------
-- 拖拽触摸
---------------------------------------------------
local function dragLayerTouch(event, x, y)
  if not panel then return false end
  if not panel.dragLayer:getVisible() then return false end
  if diffLayerNode and diffLayerNode:isVisible() then return false end

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
              dungeon_map.selectBoss(i)
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
-- 难度弹窗
---------------------------------------------------
local function closeDifficultyPopup()
  if diffLayerNode then diffLayerNode:setVisible(false) end
  selectedBossIdx = nil
end

local function showDifficultyPopup(bossIdx)
  selectedBossIdx = bossIdx
  local boss = bosses[bossIdx]
  if not boss or not diffLayerNode then return end

  diffBossLabel:setString(boss.name)
  for d = 1, 4 do
    local row = diffRows[d]
    if row then
      local diffData = boss.difficulties[d]
      if diffData then
        row.bg:setVisible(true)
        row.label:setVisible(true)
        row.diffData = diffData
        local txt = string.format("%s    Vit:%d    Lv:%d",
          diffNames[d], diffData.vit, diffData.unlockLevel)
        row.label:setString(txt)
        local locked = diffData.unlockLevel > ed.player:getLevel()
        row.label:setColor(locked and ccc3(128, 128, 128) or diffColors[d])
      else
        row.bg:setVisible(false)
        row.label:setVisible(false)
        row.diffData = nil
      end
    end
  end
  diffLayerNode:setVisible(true)
end

local function diffLayerTouchHandler(event, x, y)
  if event ~= "began" then return true end
  if not diffLayerNode or not diffLayerNode:isVisible() then return false end
  if x > 610 and x < 660 and y > 440 and y < 490 then
    closeDifficultyPopup()
    return true
  end
  for d = 1, 4 do
    local rowY = 375 - (d - 1) * 65
    if y > rowY - 27 and y < rowY + 27 and x > 300 and x < 660 then
      local row = diffRows[d]
      if row and row.diffData then
        closeDifficultyPopup()
        ed.ui.exercise.doDungeonGotoStage({}, row.diffData)
      end
      return true
    end
  end
  if y < 200 or y > 500 or x < 270 or x > 690 then
    closeDifficultyPopup()
  end
  return true
end

local function buildDifficultyLayer(parentSprite)
  local layer = CCLayer:create()
  layer:setContentSize(CCSizeMake(960, 640))
  layer:setPosition(ccp(-402, -395))
  layer:setVisible(false)

  local backdrop = CCLayerColor:create(ccc4(0, 0, 0, 150))
  backdrop:setContentSize(CCSizeMake(960, 640))
  layer:addChild(backdrop)

  local panelBg = CCScale9Sprite:create("UI/alpha/HVGA/crusade/crusade_reset_bg.png")
  panelBg:setContentSize(CCSizeMake(400, 330))
  panelBg:setPosition(ccp(480, 330))
  layer:addChild(panelBg)

  local bossLabel = CCLabelTTF:create("", "Arial", 22)
  bossLabel:setPosition(ccp(480, 465))
  bossLabel:setColor(ccc3(255, 255, 200))
  layer:addChild(bossLabel)
  diffBossLabel = bossLabel

  local closeLabel = CCLabelTTF:create("X", "Arial", 26)
  closeLabel:setPosition(ccp(635, 465))
  closeLabel:setColor(ccc3(255, 200, 200))
  layer:addChild(closeLabel)

  diffRows = {}
  for d = 1, 4 do
    local rowY = 375 - (d - 1) * 65
    local rowBg = CCScale9Sprite:create("UI/alpha/HVGA/tavern_button_normal_1.png")
    rowBg:setContentSize(CCSizeMake(350, 50))
    rowBg:setPosition(ccp(480, rowY))
    layer:addChild(rowBg)
    local rowLabel = CCLabelTTF:create("", "Arial", 18)
    rowLabel:setPosition(ccp(480, rowY))
    layer:addChild(rowLabel)
    diffRows[d] = { bg = rowBg, label = rowLabel, diffData = nil }
  end

  layer:setTouchEnabled(true)
  layer:registerScriptTouchHandler(diffLayerTouchHandler, false, -50, true)
  parentSprite:addChild(layer, 100)
  diffLayerNode = layer
end

function dungeon_map.selectBoss(index)
  showDifficultyPopup(index)
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

  print(string.format("[DM] mode=%s bosses=%d", param_mode, #bosses))

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
      local localIdx = i - (s - 1) * 5  -- section内的序号1-5
      local posIdx = math.min(localIdx, 5)
      local imgIdx = (i - 1) % 15 + 1

      -- boss精灵
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

  -- 宝箱独立放置（照搬远征：沿路径放置，不与boss一一对应）
  -- 远征section1有4箱、section2有6箱、section3有5箱，副本按boss数量等比分配
  for s = 1, MAX_SECTIONS do
    local sub = panel.dragLayer[string.format("sub%d", s)]
    if sub then
      local sectionBossCount = 0
      for _, boss in ipairs(bosses) do
        if boss.sectionIdx == s then sectionBossCount = sectionBossCount + 1 end
      end
      -- section有几个boss就放几个box，用远征该section的box坐标
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
          end
        end
      end
    end
  end

  -- ClippingNode裁剪（使用之前效果好的参数：alphaThreshold=0.1, 712x370）
  if panel.dragLayer and panel.dragLayer.dragContainer then
    local clipNode = ax.ClippingNode:create()
    clipNode:setAlphaThreshold(0.1)
    local stencil = CCLayerColor:create(ccc4(255, 255, 255, 255))
    stencil:setContentSize(CCSizeMake(712, 370))
    stencil:setPosition(ccp(44, 20))
    clipNode:setStencil(stencil)
    local dc = panel.dragLayer.dragContainer
    dc:retain()
    dc:removeFromParent(false)
    clipNode:addChild(dc)
    dc:release()
    panel.dragLayer.mainLayer:addChild(clipNode, 1)
  end

  -- dragLayer触摸
  if panel.dragLayer and panel.dragLayer.mainLayer then
    panel.dragLayer.mainLayer:setTouchEnabled(true)
    panel.dragLayer.mainLayer:registerScriptTouchHandler(dragLayerTouch, false, -10, false)
  end

  -- 构建难度弹窗
  if panel.mainLayer and panel.mainLayer.titleBg then
    buildDifficultyLayer(panel.mainLayer.titleBg)
  elseif panel.mainLayer and panel.mainLayer.bgframe then
    buildDifficultyLayer(panel.mainLayer.bgframe)
  end

  refreshBattleState()

  newscene:registerOnEnterHandler("onEnterDungeon", function()
    if needRefreshOnEnter and panel then
      needRefreshOnEnter = false
      refreshBattleState()
    end
  end)
  newscene:registerOnExitHandler("onExitDungeon", function() end)
  newscene:registerOnPopSceneHandler("onPopSceneDungeon", function()
    panel = nil
    bosses = {}
    groupBossCounts = {}
    groupBossOffset = {}
    diffLayerNode = nil
    diffRows = {}
    selectedBossIdx = nil
    dragMode = false
    dragPressX = nil
    needRefreshOnEnter = false
  end)

  return newscene
end
