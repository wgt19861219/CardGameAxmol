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

local heroicPrereq = { [40005]=40001, [40006]=40002, [40007]=40004 }

local function isHeroicUnlocked(groupId)
  local normalGroup = heroicPrereq[groupId]
  if not normalGroup then return true end
  local groupTable = ed.getDataTable("ActStageGroupDungeon")
  local groupCfg = groupTable and groupTable[normalGroup]
  if not groupCfg then return true end
  local stageIds = groupCfg["Stages"]
  if not stageIds then return true end
  for _, sid in ipairs(stageIds) do
    if sid > 0 then
      local stars = ed.player and ed.player:getStageStar(sid) or 0
      if stars < 1 then return false end
    end
  end
  return true
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

    -- 次数显示 / 锁定提示
    local locked = difficulty == 2 and not isHeroicUnlocked(g.id)
    if locked then
      local lockLbl = ed.createttf(T(LSTR("DUNGEON.HEROIC_PREREQ")), 13)
      lockLbl:setPosition(ccp(80, 30))
      lockLbl:setColor(ccc3(255, 80, 80))
      btnBg:addChild(lockLbl)
    else
      local dailyLimit = g.data["DailyLimit"] or 2
      local maxBuy = g.data["MaxBuyPerDay"] or 3
      local usedTimes = (ed.player and ed.player:getActTimes(g.id)) or 0
      local leftTimes = math.max(0, dailyLimit + maxBuy - usedTimes)
      local leftText = T(LSTR("DUNGEON.DAILY_LEFT")) .. tostring(leftTimes)
      local leftLbl = ed.createttf(leftText, 14)
      leftLbl:setPosition(ccp(80, 30))
      leftLbl:setColor(ccc3(200, 200, 200))
      btnBg:addChild(leftLbl)
    end

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
          self:showBossSelect(btn.groupId, btn.bg)
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

local function showBossSelect(self, groupId, parentWidget)
  if not isHeroicUnlocked(groupId) then
    ed.showToast(T(LSTR("DUNGEON.HEROIC_PREREQ")))
    return
  end
  if self.bossPanel then
    self.bossPanel:removeFromParentAndCleanup(true)
    self.bossPanel = nil
    return
  end
  local stages = getDungeonStages(groupId)
  if #stages == 0 then return end

  local panel = CCLayerColor:create(ccc4(0, 0, 0, 160))
  panel:setPosition(ccp(0, 0))
  panel:setContentSize(CCSizeMake(850, 520))
  self.ui.frame:addChild(panel, 100)
  self.bossPanel = panel

  local bg = ed.createScale9Sprite("UI/alpha/HVGA/main_vit_tips.png", CCRectMake(10, 10, 58, 26))
  bg:setPosition(ccp(425, 260))
  bg:setContentSize(CCSizeMake(500, 320))
  panel:addChild(bg)

  local title = ed.createttf(T(LSTR("DUNGEON.SELECT_BOSS")), 20)
  title:setPosition(ccp(250, 295))
  title:setColor(ccc3(231, 206, 19))
  bg:addChild(title)

  local bossBtns = {}
  for i, st in ipairs(stages) do
    local by = 220 - (i - 1) * 85
    local row = ed.createScale9Sprite("UI/alpha/HVGA/main_vit_tips.png", CCRectMake(10, 10, 58, 26))
    row:setPosition(ccp(250, by))
    row:setContentSize(CCSizeMake(440, 70))
    bg:addChild(row)

    local nameStr = type(st.name) == "string" and st.name or T(st.name or "")
    local nameLbl = ed.createttf(nameStr, 18)
    nameLbl:setPosition(ccp(130, 45))
    nameLbl:setColor(ccc3(233, 214, 181))
    row:addChild(nameLbl)

    local vitText = T(LSTR("DUNGEON.VIT_COST")) .. tostring(st.vit)
    local vitLbl = ed.createttf(vitText, 14)
    vitLbl:setPosition(ccp(130, 20))
    vitLbl:setColor(ccc3(180, 180, 180))
    row:addChild(vitLbl)

    local goBtn = ed.createScale9Sprite("UI/alpha/HVGA/main_vit_tips.png", CCRectMake(10, 10, 58, 26))
    goBtn:setPosition(ccp(380, 35))
    goBtn:setContentSize(CCSizeMake(80, 40))
    row:addChild(goBtn)
    local goLbl = ed.createttf(T(LSTR("DUNGEON.ENTER")), 16)
    goLbl:setPosition(ccp(40, 20))
    goLbl:setColor(ccc3(255, 255, 255))
    goBtn:addChild(goLbl)

    table.insert(bossBtns, { row = row, stageId = st.id, goBtn = goBtn })
  end

  panel:setTouchEnabled(true)
  panel:registerScriptTouchHandler(function(event, x, y)
    xpcall(function()
      if event == "began" then
        for _, b in ipairs(bossBtns) do
          local bx, by = b.row:getPosition()
          local px, py = b.row:getParent():convertToWorldSpace(ccp(bx, by))
          if math.abs(x - px) < 220 and math.abs(y - py) < 35 then
            return true
          end
        end
        panel._dismiss = true
        return true
      elseif event == "ended" then
        local handled = false
        for _, b in ipairs(bossBtns) do
          local bx, by = b.row:getPosition()
          local px, py = b.row:getParent():convertToWorldSpace(ccp(bx, by))
          if math.abs(x - px) < 220 and math.abs(y - py) < 35 then
            panel:removeFromParentAndCleanup(true)
            self.bossPanel = nil
            local scene = ed.ui.stagedetail.createForExercise(b.stageId, {
              isExercise = true,
              actType = "dungeon",
            })
            ed.pushScene(scene)
            handled = true
            break
          end
        end
        if not handled and panel._dismiss then
          panel:removeFromParentAndCleanup(true)
          self.bossPanel = nil
        end
      end
    end, EDDebug)
    return true
  end, false, -145, true)

  panel:setScale(0)
  local s = CCScaleTo:create(0.15, 1)
  s = CCEaseBackOut:create(s)
  panel:runAction(s)
end
class.showBossSelect = showBossSelect

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
