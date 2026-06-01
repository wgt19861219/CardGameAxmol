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

-- 难度弹窗引用（照搬exercise原版degreeWindow视觉）
local degreePopup = nil  -- {mainLayer, container, ui, degree, bossIdx}

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
  -- 弹窗可能已被自身destroy()移除，检查mainLayer是否还有效
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
-- 难度弹窗（直接调用exercise原装degreeWindow）
---------------------------------------------------
-- groupId反查exercise key
local groupIdToKey = {}
for k, v in pairs(ed.ui.exerciseres and ed.ui.exerciseres.entry_stage or {}) do
  groupIdToKey[v] = k
end

local function showDegreePopup(bossIdx)
  if degreePopup then
    xpcall(function()
      if degreePopup.container then
        degreePopup.container:removeFromParentAndCleanup(true)
      elseif degreePopup.mainLayer then
        degreePopup.mainLayer:removeFromParentAndCleanup(true)
      end
    end, EDDebug)
    degreePopup = nil
  end

  local boss = bosses[bossIdx]
  if not boss then return end

  -- 找到该boss所属group的exercise key
  local groupIdx = math.ceil(bossIdx / 5)
  local gid = param_groupIds[groupIdx]
  local exKey = groupIdToKey[gid]
  if not exKey then
    return
  end

  local degree = ed.ui.exercise.createDungeon(exKey)
  if not degree or not degree.mainLayer then
    return
  end

  local root = panel and panel.getRoot and panel:getRoot()
  if root then
    root:addChild(degree.mainLayer, 200)
  end

  degreePopup = degree
  selectedBossIdx = bossIdx
end

function dungeon_map.selectBoss(index)
  xpcall(showDegreePopup, function(err)
    print("[DM] showDegreePopup ERROR: " .. tostring(err))
  end, index)
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

  refreshBattleState()

  newscene:registerOnEnterHandler("onEnterDungeon", function()
    if needRefreshOnEnter and panel then
      needRefreshOnEnter = false
      refreshBattleState()
    end
  end)
  newscene:registerOnExitHandler("onExitDungeon", function() end)
  newscene:registerOnPopSceneHandler("onPopSceneDungeon", function()
    degreePopup = nil
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
