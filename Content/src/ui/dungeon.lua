-- 副本入口UI
local class = { mt = {} }
class.mt.__index = class

local function getDungeonGroups(difficulty)
  local groups = ed.getDataTable("ActStageGroupDungeon")
  if not groups then return {} end
  local result = {}
  for id, g in pairs(groups) do
    if g["Difficulty"] == difficulty then
      table.insert(result, { id = id, data = g })
    end
  end
  table.sort(result, function(a, b) return a.id < b.id end)
  return result
end

local function getDungeonStages(groupId)
  local group = ed.getDataTable("ActStageGroupDungeon")[groupId]
  if not group then return {} end
  local stageIds = group["Stages"]
  local stageTable = ed.getDataTable("StageDungeon")
  local stages = {}
  for _, sid in ipairs(stageIds or {}) do
    if sid > 0 and stageTable[sid] then
      table.insert(stages, {
        id = sid,
        name = stageTable[sid]["Stage Name"] or "",
        vit = stageTable[sid]["Vitality Cost"] or 0,
        group = groupId,
      })
    end
  end
  return stages
end

local function create(key)
  local self = {}
  setmetatable(self, class.mt)
  self.key = key or "normal"
  local difficulty = self.key == "heroic" and 2 or 1
  local groups = getDungeonGroups(difficulty)

  local mainLayer = CCLayerColor:create(ccc4(0, 0, 0, 200))
  self.mainLayer = mainLayer

  local container = CCLayer:create()
  container:setAnchorPoint(ccp(0.5, 0.5))
  self.container = container
  mainLayer:addChild(container)
  self.ui = {}

  -- 弹窗背景
  local frame = ed.createScale9Sprite("UI/alpha/HVGA/main_vit_tips.png", CCRectMake(10, 10, 58, 26))
  frame:setPosition(ccp(480, 320))
  frame:setContentSize(CCSizeMake(850, 520))
  container:addChild(frame)
  self.ui.frame = frame

  -- 标题
  local diffText = difficulty == 2 and T(LSTR("DUNGEON.DIFFICULTY_HEROIC")) or T(LSTR("DUNGEON.DIFFICULTY_NORMAL"))
  local title = ed.createttf(diffText, 22)
  title:setPosition(ccp(425, 490))
  title:setColor(ccc3(231, 206, 19))
  frame:addChild(title)

  -- 关闭按钮
  local closeBtn = ed.createSprite("UI/alpha/HVGA/herodetail-detail-close.png")
  closeBtn:setPosition(ccp(820, 500))
  frame:addChild(closeBtn)
  self.ui.closeBtn = closeBtn
  local closeBtnPress = ed.createSprite("UI/alpha/HVGA/herodetail-detail-close-p.png")
  closeBtnPress:setPosition(ccp(0, 0))
  closeBtnPress:setAnchorPoint(ccp(0, 0))
  closeBtnPress:setVisible(false)
  closeBtn:addChild(closeBtnPress)
  self.ui.closeBtnPress = closeBtnPress

  -- Tab: 普通/英雄切换
  local tabNormal = ed.createttf(T(LSTR("DUNGEON.DIFFICULTY_NORMAL")), 18)
  tabNormal:setPosition(ccp(180, 455))
  tabNormal:setColor(difficulty == 1 and ccc3(231, 206, 19) or ccc3(150, 150, 150))
  frame:addChild(tabNormal)
  self.ui.tabNormal = tabNormal

  local tabHeroic = ed.createttf(T(LSTR("DUNGEON.DIFFICULTY_HEROIC")), 18)
  tabHeroic:setPosition(ccp(320, 455))
  tabHeroic:setColor(difficulty == 2 and ccc3(231, 206, 19) or ccc3(150, 150, 150))
  frame:addChild(tabHeroic)
  self.ui.tabHeroic = tabHeroic

  -- 副本列表
  self.dungeonButtons = {}
  local ox, oy = 120, 370
  local dx = 180

  for i, g in ipairs(groups) do
    local x = ox + dx * ((i - 1) % 4)
    local y = oy - math.floor((i - 1) / 4) * 170

    -- 副本背景框
    local btnBg = ed.createScale9Sprite("UI/alpha/HVGA/main_vit_tips.png", CCRectMake(10, 10, 58, 26))
    btnBg:setPosition(ccp(x, y))
    btnBg:setContentSize(CCSizeMake(160, 140))
    frame:addChild(btnBg)

    -- 副本名称
    local gName = ed.getDataTable("ActStageGroupDungeon")[g.id]["Group Name"]
    local nameStr = type(gName) == "string" and gName or T(gName or "")
    local nameLbl = ed.createttf(nameStr, 16)
    nameLbl:setPosition(ccp(80, 120))
    nameLbl:setColor(ccc3(233, 214, 181))
    btnBg:addChild(nameLbl)

    -- 难度标记
    local diffLbl = ed.createttf(difficulty == 2 and T(LSTR("DUNGEON.DIFFICULTY_HEROIC")) or T(LSTR("DUNGEON.DIFFICULTY_NORMAL")), 14)
    diffLbl:setPosition(ccp(80, 100))
    diffLbl:setColor(difficulty == 2 and ccc3(255, 100, 100) or ccc3(100, 200, 100))
    btnBg:addChild(diffLbl)

    -- 次数显示
    local dailyLimit = g.data["DailyLimit"] or 2
    local maxBuy = g.data["MaxBuyPerDay"] or 3
    local usedTimes = (ed.player and ed.player:getActTimes(g.id)) or 0
    local leftTimes = math.max(0, dailyLimit + maxBuy - usedTimes)
    local leftText = T(LSTR("DUNGEON.DAILY_LEFT")) .. tostring(leftTimes)
    local leftLbl = ed.createttf(leftText, 14)
    leftLbl:setPosition(ccp(80, 30))
    leftLbl:setColor(ccc3(200, 200, 200))
    btnBg:addChild(leftLbl)

    -- 进入按钮
    local enterBtn = ed.createScale9Sprite("UI/alpha/HVGA/main_vit_tips.png", CCRectMake(10, 10, 58, 26))
    enterBtn:setPosition(ccp(80, 60))
    enterBtn:setContentSize(CCSizeMake(120, 30))
    btnBg:addChild(enterBtn)
    local enterLbl = ed.createttf(T(LSTR("DUNGEON.ENTER")), 16)
    enterLbl:setPosition(ccp(60, 15))
    enterLbl:setColor(ccc3(255, 255, 255))
    enterBtn:addChild(enterLbl)

    table.insert(self.dungeonButtons, {
      bg = btnBg,
      enterBtn = enterBtn,
      groupId = g.id,
      data = g.data,
    })
  end

  -- 触摸处理
  local pressTarget = nil
  mainLayer:setTouchEnabled(true)
  mainLayer:registerScriptTouchHandler(function(event, x, y)
    xpcall(function()
      if event == "began" then
        if ed.containsPoint(closeBtn, x, y) then
          pressTarget = "close"
          closeBtnPress:setVisible(true)
          return
        end
        if ed.containsPoint(tabNormal, x, y) and difficulty ~= 1 then
          pressTarget = "tab_normal"
          return
        end
        if ed.containsPoint(tabHeroic, x, y) and difficulty ~= 2 then
          pressTarget = "tab_heroic"
          return
        end
        for _, btn in ipairs(self.dungeonButtons) do
          local bx, by = btn.bg:getPosition()
          local px, py = btn.bg:getParent():convertToWorldSpace(ccp(bx, by))
          if math.abs(x - px) < 80 and math.abs(y - py) < 70 then
            pressTarget = btn
            return
          end
        end
      elseif event == "ended" then
        if pressTarget == "close" and ed.containsPoint(closeBtn, x, y) then
          self:destroy()
        elseif pressTarget == "tab_normal" then
          self:destroy()
          local newPanel = create("normal")
          local scene = ed.getCurrentScene()
          if scene and scene.container then
            scene.container:addChild(newPanel.mainLayer, 200)
          end
        elseif pressTarget == "tab_heroic" then
          self:destroy()
          local newPanel = create("heroic")
          local scene = ed.getCurrentScene()
          if scene and scene.container then
            scene.container:addChild(newPanel.mainLayer, 200)
          end
        elseif type(pressTarget) == "table" and pressTarget.groupId then
          local btn = pressTarget
          local stages = getDungeonStages(btn.groupId)
          if #stages > 0 then
            local stageId = stages[1].id
            local scene = ed.ui.stagedetail.createForExercise(stageId, {
              isExercise = true,
              actType = "dungeon",
            })
            ed.pushScene(scene)
          end
        end
        closeBtnPress:setVisible(false)
        pressTarget = nil
      end
    end, EDDebug)
    return true
  end, false, -140, true)

  -- 弹出动画
  container:setScale(0)
  local s = CCScaleTo:create(0.2, 1)
  s = CCEaseBackOut:create(s)
  container:runAction(s)

  return self
end

local function destroy(self)
  xpcall(function()
    self.mainLayer:removeFromParentAndCleanup(true)
  end, EDDebug)
end
class.destroy = destroy

ed.ui.dungeon = class

-- 创建独立场景入口（从主界面调用）
ed.ui.dungeon.createScene = function(key)
  key = key or "normal"
  local scene = CCScene:create()
  local bg = CCLayerColor:create(ccc4(0, 0, 0, 255))
  scene:addChild(bg)
  local panel = create(key)
  bg:addChild(panel.mainLayer)
  scene._dungeonPanel = panel
  return scene
end
