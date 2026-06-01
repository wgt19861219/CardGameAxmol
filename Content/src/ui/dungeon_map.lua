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
local acts = require("util.cocos2dx.actions")
local needRefreshOnEnter = false

-- 难度弹窗引用
local diffLayerNode
local diffBossLabel
local diffRows = {}

-- 难度名称与颜色
local diffNames = { "Normal", "Elite", "Hero", "Nightmare" }
local diffColors = {
  ccc3(100, 220, 100),
  ccc3(100, 150, 255),
  ccc3(180, 100, 255),
  ccc3(255, 80, 80),
}

local titleMap = {
  hero_trial = "英雄试炼",
  time_cavern = "时光之穴",
  em = "经验关",
  equip = "装备关",
}

---------------------------------------------------
-- 从数据表获取某组Boss列表
---------------------------------------------------
local function getBossesForGroup(groupId)
  local dgTable = ed.getDataTable("ActStageGroupDungeon")
  local groupData = dgTable[groupId]
  if not groupData then return {} end
  local stDungeon = ed.getDataTable("StageDungeon")
  local result = {}
  for _, bossId in ipairs(groupData.Stages) do
    if bossId > 0 then
      local baseData = stDungeon[bossId]
      local bossName = ""
      if baseData and baseData["Stage Name"] then
        bossName = T(baseData["Stage Name"])
      end
      local boss = { baseId = bossId, name = bossName, difficulties = {} }
      -- 生成4级难度（StageDungeon只有基础条目，额外难度从基础数据派生）
      local baseVit = (baseData and baseData["Vitality Cost"]) or 12
      local baseUnlock = (baseData and baseData["Unlock Level"]) or 1
      local vitScale = { 1.0, 1.3, 1.7, 2.0 }
      local unlockOffset = { 0, 5, 10, 15 }
      for diff = 1, 4 do
        local diffId = bossId + (diff - 1) * 1000
        local stageData = stDungeon[diffId]
        if stageData then
          -- 数据表有该难度条目
          table.insert(boss.difficulties, {
            id = diffId,
            vit = stageData["Vitality Cost"] or 12,
            keyCost = stageData["Key Cost"] or 0,
            unlockLevel = stageData["Unlock Level"] or 1,
            diff = diff,
          })
        else
          -- 没有该难度条目，从基础数据派生
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
  for b = 1, 3 do
    local bossIdx = (groupIdx - 1) * 3 + b
    if bossIdx > #bosses then return false end
    if not isBossCleared(bosses[bossIdx].baseId) then
      return false
    end
  end
  return true
end

local function calcMaxRight()
  return -math.max(0, (#param_groupIds - 1) * 727)
end

---------------------------------------------------
-- 拖拽触摸
---------------------------------------------------
local function dragLayerTouch(event, x, y)
  if not panel then return false end
  if not panel.dragLayer:getVisible() then return false end
  -- 难度弹窗打开时不响应拖拽
  if diffLayerNode and diffLayerNode:isVisible() then return false end

  if event == "began" then
    dragPressX = x
    print("[DUNGEON_MAP] touch began: " .. x .. "," .. y)
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
  end
  panel.dragLayer:touch(event, x, y)
  return true
end

---------------------------------------------------
-- 刷新Boss节点和宝箱状态
---------------------------------------------------
local function refreshBattleState()
  if not panel then return end
  for i, boss in ipairs(bosses) do
    local btn = panel.dragLayer[string.format("battle%d", i)]
    local box = panel.dragLayer[string.format("box%d", i)]
    local cleared = isBossCleared(boss.baseId)
    if btn and btn.enable then
      btn:enable(not cleared)
    end
    if box and box.setVisible then
      box:setVisible(cleared)
    end
  end
end

---------------------------------------------------
-- 刷新雾效
---------------------------------------------------
local function refreshFog()
  if not panel then return end
  local fogCount = #param_groupIds - 1
  for i = 1, fogCount do
    local fog = panel.dragLayer[string.format("fog%d", i)]
    if fog and fog.setVisible then
      if isGroupCleared(i) then
        fog:setVisible(false)
      else
        fog:setVisible(true)
        if fog.setOpacity then fog:setOpacity(255) end
      end
    end
  end
end

local function refreshFogAnimation(groupIdx)
  if not panel then return end
  local fog = panel.dragLayer[string.format("fog%d", groupIdx)]
  if not fog or not fog.stopAllActions then return end
  fog:stopAllActions()
  fog:runAction(acts.sequence({
    CCFadeOut:create(1.5),
    CCCallFunc:create(function()
      fog:setVisible(false)
    end),
  }))
end

---------------------------------------------------
-- 难度弹窗
---------------------------------------------------
local function closeDifficultyPopup()
  if diffLayerNode then
    diffLayerNode:setVisible(false)
  end
  selectedBossIdx = nil
end

local function showDifficultyPopup(bossIdx)
  selectedBossIdx = bossIdx
  local boss = bosses[bossIdx]
  if not boss or not diffLayerNode then return end

  -- 更新Boss名
  diffBossLabel:setString(boss.name)

  -- 更新4个难度行
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

-- 难度弹窗触摸（检测点击哪个难度行）
local function diffLayerTouchHandler(event, x, y)
  if event ~= "began" then return true end
  if not diffLayerNode or not diffLayerNode:isVisible() then return false end

  -- 关闭按钮区域（右上角）
  if x > 610 and x < 660 and y > 440 and y < 490 then
    closeDifficultyPopup()
    return true
  end

  -- 检测难度行（每行高55，从y=375向下排列）
  for d = 1, 4 do
    local rowY = 375 - (d - 1) * 65
    if y > rowY - 27 and y < rowY + 27 and x > 300 and x < 660 then
      local row = diffRows[d]
      if row and row.diffData then
        local diffData = row.diffData
        closeDifficultyPopup()
        -- 调用exercise的副本战斗入口
        ed.ui.exercise.doDungeonGotoStage({}, diffData)
      end
      return true
    end
  end

  -- 点击弹窗面板外→关闭
  if y < 200 or y > 500 or x < 270 or x > 690 then
    closeDifficultyPopup()
  end
  return true
end

-- 构建难度弹窗UI（添加到titleBg精灵上，titleBg在screen 402,395.3）
local function buildDifficultyLayer(parentSprite)
  -- titleBg中心在(402,395.3)，弹窗坐标系需要偏移使screen(480,320)=local(78,-75.3)
  local ox, oy = 78, -75
  local layer = CCLayer:create()
  layer:setContentSize(CCSizeMake(960, 640))
  layer:setPosition(ccp(-402, -395))
  layer:setVisible(false)

  -- 半透明背景
  local backdrop = CCLayerColor:create(ccc4(0, 0, 0, 150))
  backdrop:setContentSize(CCSizeMake(960, 640))
  backdrop:setPosition(ccp(0, 0))
  layer:addChild(backdrop)

  -- 弹窗面板背景
  local panelBg = CCScale9Sprite:create("UI/alpha/HVGA/crusade/crusade_reset_bg.png")
  panelBg:setContentSize(CCSizeMake(400, 330))
  panelBg:setPosition(ccp(480, 330))
  layer:addChild(panelBg)

  -- Boss名标题
  local bossLabel = CCLabelTTF:create("", "Arial", 22)
  bossLabel:setPosition(ccp(480, 465))
  bossLabel:setColor(ccc3(255, 255, 200))
  layer:addChild(bossLabel)
  diffBossLabel = bossLabel

  -- 关闭按钮（X文字）
  local closeLabel = CCLabelTTF:create("X", "Arial", 26)
  closeLabel:setPosition(ccp(635, 465))
  closeLabel:setColor(ccc3(255, 200, 200))
  layer:addChild(closeLabel)

  -- 4个难度行
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

  -- 注册触摸（优先级-50，高于所有层）
  layer:setTouchEnabled(true)
  layer:registerScriptTouchHandler(diffLayerTouchHandler, false, -50, true)

  parentSprite:addChild(layer, 100)
  diffLayerNode = layer
end

---------------------------------------------------
-- Boss选择回调
---------------------------------------------------
function dungeon_map.selectBoss(index)
  print("[DUNGEON_MAP] selectBoss called: index=" .. tostring(index))
  showDifficultyPopup(index)
end

---------------------------------------------------
-- 场景创建
---------------------------------------------------
function dungeon_map.create(param)
  param = param or {}
  param_mode = param.mode or "hero_trial"
  param_groupIds = param.groupIds or { 40001, 40002, 40003, 40004 }

  local newscene = base.create("dungeon_map")
  setmetatable(newscene, dungeon_map)

  -- 收集所有Boss数据
  bosses = {}
  for _, gid in ipairs(param_groupIds) do
    local group = getBossesForGroup(gid)
    for _, boss in ipairs(group) do
      table.insert(bosses, boss)
    end
  end

  -- 生成UI配置并创建panel
  local dungeonmapconfig = require("gametable/dungeonmapconfig")
  local uiRes = dungeonmapconfig.buildUIRes(#param_groupIds)
  panel = panelMeta:new(newscene, uiRes)
  if not panel then return newscene end

  -- 标题文字（添加到topLayer.titleBg精灵上）
  local titleLabel = CCLabelTTF:create(titleMap[param_mode] or "副本", "Arial", 22)
  titleLabel:setPosition(ccp(0, -5))
  titleLabel:setColor(ccc3(255, 255, 255))
  if panel.uiLayer and panel.uiLayer.titleBg then
    panel.uiLayer.titleBg:addChild(titleLabel)
  elseif panel.mainLayer and panel.mainLayer.titleBg then
    panel.mainLayer.titleBg:addChild(titleLabel)
  end

  -- 底部信息文字（添加到topLayer.bottom精灵上）
  local infoLabel = CCLabelTTF:create(
    string.format("共%d个Boss  |  %s", #bosses, titleMap[param_mode] or ""),
    "Arial", 16
  )
  infoLabel:setPosition(ccp(0, 0))
  infoLabel:setColor(ccc3(255, 255, 200))
  if panel.uiLayer and panel.uiLayer.bottom then
    panel.uiLayer.bottom:addChild(infoLabel)
  elseif panel.mainLayer and panel.mainLayer.bottom then
    panel.mainLayer.bottom:addChild(infoLabel)
  end

  -- dragLayer触摸
  if panel.dragLayer and panel.dragLayer.mainLayer then
    panel.dragLayer.mainLayer:setTouchEnabled(true)
    panel.dragLayer.mainLayer:registerScriptTouchHandler(dragLayerTouch, false, -10, false)
  end

  -- 构建难度弹窗（添加到topLayer，确保在所有内容之上）
  if panel.uiLayer and panel.uiLayer.titleBg then
    buildDifficultyLayer(panel.uiLayer.titleBg)
  elseif panel.mainLayer and panel.mainLayer.bgframe then
    buildDifficultyLayer(panel.mainLayer.bgframe)
  end

  -- 初始状态
  refreshBattleState()
  refreshFog()

  -- 注册生命周期回调
  newscene:registerOnEnterHandler("onEnterDungeon", function()
    if needRefreshOnEnter and panel then
      needRefreshOnEnter = false
      refreshBattleState()
      refreshFog()
    end
  end)
  newscene:registerOnExitHandler("onExitDungeon", function() end)
  newscene:registerOnPopSceneHandler("onPopSceneDungeon", function()
    panel = nil
    bosses = {}
    diffLayerNode = nil
    diffRows = {}
  end)

  return newscene
end
