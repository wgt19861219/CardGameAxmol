local ed = ed
local class = {
  mt = {}
}
class.mt.__index = class
ed.ui.bename = class
local base = ed.ui.popwindow
setmetatable(class, base.mt)
local function rollName(self)
  local name = ""
  local ac = ed.getDataTable("affixcount")
  if ac and #ac > 0 then
    name = ac[math.random(1, #ac)]
    self:setName(name)
  end
end
class.rollName = rollName
local getNameLength = function(self)
  local edit = self.edit
  return #edit:getString()
end
class.getNameLength = getNameLength
local getName = function(self)
  local edit = self.edit
  return edit:getString()
end
class.getName = getName
local setName = function(self, name)
  self.edit:setString(name)
end
class.setName = setName
local createEdit = function(self)
  local nameLabel = CCLabelTTF:create("", ed.font, 22)
  nameLabel:setColor(ccc3(198, 175, 126))
  nameLabel:setAnchorPoint(ccp(0, 0.5))
  nameLabel:setPosition(ccp(40, 95))
  self.ui.bg:addChild(nameLabel)
  self.edit = nameLabel
  local gameCenterNickName = CCUserDefault:sharedUserDefault():getStringForKey("OC_GAME_CENTER_NICK_NAME_KEY")
  local uname = self:getName() or ""
  if string.len(uname) == 0 and string.len(gameCenterNickName) > 0 then
    self:setName(gameCenterNickName)
  else
    if not ispvp then
      self:rollName()
    end
  end
end
class.createEdit = createEdit
local registerTouchHandler = function(self)
  local ui = self.ui
  local mainLayer = self.mainLayer

  -- 手动计算按钮在mainLayer坐标系中的hit区域，绕过ed.containsPoint的worldSpace问题
  local bg = ui.bg
  local bgPosX, bgPosY = bg:getPosition()
  local bgAnchor = bg:getAnchorPoint()
  local bgSize = bg:getContentSize()
  -- bg在mainLayer中的包围盒
  local bgRect = {x = bgPosX - bgAnchor.x * bgSize.width, y = bgPosY - bgAnchor.y * bgSize.height, w = bgSize.width, h = bgSize.height}

  local function pointInBgRect(lx, ly)
    return lx >= bgRect.x and lx <= bgRect.x + bgRect.w and ly >= bgRect.y and ly <= bgRect.y + bgRect.h
  end

  -- ok按钮在bg内的相对位置: ccp(235, 35)，size 110x45
  local okRelX, okRelY, okW, okH = 235, 35, 110, 45
  local function pointInOk(lx, ly)
    local ox = bgRect.x + okRelX - okW/2
    local oy = bgRect.y + okRelY - okH/2
    return lx >= ox and lx <= ox + okW and ly >= oy and ly <= oy + okH
  end

  -- cancel按钮在bg内的相对位置: ccp(115, 35)，size 110x45
  local cancelRelX, cancelRelY = 115, 35
  local function pointInCancel(lx, ly)
    local ox = bgRect.x + cancelRelX - okW/2
    local oy = bgRect.y + cancelRelY - okH/2
    return lx >= ox and lx <= ox + okW and ly >= oy and ly <= oy + okH
  end

  -- roll按钮在bg内的相对位置: ccp(300, 95)，size约62x59
  local rollRelX, rollRelY, rollW, rollH = 300, 95, 62, 59
  local function pointInRoll(lx, ly)
    local ox = bgRect.x + rollRelX - rollW/2
    local oy = bgRect.y + rollRelY - rollH/2
    return lx >= ox and lx <= ox + rollW and ly >= oy and ly <= oy + rollH
  end

  local isOk, isCancel, isRoll
  local function handler(event, x, y)
    xpcall(function()
      if event == "began" then
        isOk, isCancel, isRoll = nil, nil, nil
        if pointInOk(x, y) then
          isOk = true
          if not tolua.isnull(ui.ok_press) then ui.ok_press:setVisible(true) end
        elseif pointInCancel(x, y) then
          isCancel = true
          if not tolua.isnull(ui.cancel_press) then ui.cancel_press:setVisible(true) end
        elseif pointInRoll(x, y) then
          isRoll = true
          if not tolua.isnull(ui.roll_press) then ui.roll_press:setVisible(true) end
        end
      elseif event == "ended" then
        if isOk then
          if not tolua.isnull(ui.ok_press) then ui.ok_press:setVisible(false) end
          if pointInOk(x, y) then self:doClickok() end
        elseif isCancel then
          if not tolua.isnull(ui.cancel_press) then ui.cancel_press:setVisible(false) end
          self:doClickCancel()
        elseif isRoll then
          if not tolua.isnull(ui.roll_press) then ui.roll_press:setVisible(false) end
          self:doClickRoll()
        else
          if not pointInBgRect(x, y) then
            self:doClickCancel()
          end
        end
        isOk, isCancel, isRoll = nil, nil, nil
      end
    end, EDDebug)
    return true
  end

  mainLayer:setTouchEnabled(true)
  mainLayer:registerScriptTouchHandler(handler, false, self.mainTouchPriority, true)
end
class.registerTouchHandler = registerTouchHandler
local function create(param)
  param = param or {}
  local pt = param.type
  local ispvp = param.ispvp
  local callback = param.callback
  local self = base.create("bename")
  setmetatable(self, class.mt)
  self.type = pt or "free"
  self.callback = callback
  local mainLayer = self.mainLayer
  self.ui = {}
  local frame = ed.createScale9Sprite("UI/alpha/HVGA/main_vit_tips.png", CCRectMake(10, 10, 58, 26))
  frame:setContentSize(CCSizeMake(355, 180))
  frame:setPosition(ccp(400, 355))
  mainLayer:addChild(frame)
  self.ui.bg = frame
  local ui_info = {
    {
      t = "Label",
      base = {
        name = "title",
        text = T(LSTR("BENAME.A_NAME_FOR_YOUR_TEAM_")),
        size = 20
      },
      layout = {
        anchor = ccp(0, 0.5),
        position = ccp(30, 150)
      },
      config = {}
    },
    {
      t = "Scale9Sprite",
      base = {
        name = "name_bg",
        res = "UI/alpha/HVGA/activate_input.png",
        capInsets = CCRectMake(12, 10, 12, 22)
      },
      layout = {
        anchor = ccp(0, 0.5),
        position = ccp(30, 95)
      },
      config = {
        scaleSize = CCSizeMake(235, 42)
      }
    },
    {
      t = "Sprite",
      base = {
        name = "roll",
        res = "UI/alpha/HVGA/naming_button_roll_1.png"
      },
      layout = {
        position = ccp(300, 95)
      },
      config = {}
    },
    {
      t = "Sprite",
      base = {
        name = "roll_press",
        res = "UI/alpha/HVGA/naming_button_roll_2.png",
        parent = "roll"
      },
      layout = {
        anchor = ccp(0, 0),
        position = ccp(0, 0)
      },
      config = {visible = false}
    },
    {
      t = "Scale9Sprite",
      base = {
        name = "ok",
        res = "UI/alpha/HVGA/sell_number_button.png",
        capInsets = CCRectMake(15, 22, 15, 25)
      },
      layout = {
        position = ccp(235, 35)
      },
      config = {
        scaleSize = CCSizeMake(110, 45)
      }
    },
    {
      t = "Scale9Sprite",
      base = {
        name = "ok_press",
        res = "UI/alpha/HVGA/sell_number_button_down.png",
        capInsets = CCRectMake(15, 22, 15, 25),
        parent = "ok"
      },
      layout = {
        anchor = ccp(0, 0),
        position = ccp(0, 0)
      },
      config = {
        visible = false,
        scaleSize = CCSizeMake(110, 45)
      }
    },
    {
      t = "Label",
      base = {
        name = "ok_label",
        text = T(LSTR("CHATCONFIG.CONFIRM")),
        fontinfo = "ui_normal_button",
        z = 1,
        parent = "ok"
      },
      layout = {
        position = ccp(55, 23)
      },
      config = {
        color = ccc3(235, 225, 205)
      }
    },
    {
      t = "Scale9Sprite",
      base = {
        name = "cancel",
        res = "UI/alpha/HVGA/sell_number_button.png",
        capInsets = CCRectMake(15, 22, 15, 25)
      },
      layout = {
        position = ccp(115, 35)
      },
      config = {
        scaleSize = CCSizeMake(110, 45)
      }
    },
    {
      t = "Scale9Sprite",
      base = {
        name = "cancel_press",
        res = "UI/alpha/HVGA/sell_number_button_down.png",
        capInsets = CCRectMake(15, 22, 15, 25),
        parent = "cancel"
      },
      layout = {
        anchor = ccp(0, 0),
        position = ccp(0, 0)
      },
      config = {
        visible = false,
        scaleSize = CCSizeMake(110, 45)
      }
    },
    {
      t = "Label",
      base = {
        name = "cancel_label",
        text = T(LSTR("CHATCONFIG.CANCEL")),
        fontinfo = "ui_normal_button",
        z = 1,
        parent = "cancel"
      },
      layout = {
        position = ccp(55, 23)
      },
      config = {
        color = ccc3(235, 225, 205)
      }
    }
  }
  local readNode = ed.readnode.create(frame, self.ui)
  readNode:addNode(ui_info)
  local seed = ed.getMillionTime()
  math.randomseed(seed)
  math.random()
  math.random()
  math.random()
  self:createEdit(ispvp)
  self:registerTouchHandler()
  self:show()
  if ispvp then
     ListenTimer(Timer:Once(0.8), function()
      self:doClickName()
    end)
  end
  return self
end
class.create = create
local function show(self)
  local bg = self.ui.bg
  ed.setNodeAnchor(bg, ccp(0.5, 0.5))
  bg:setScale(0)
  self.edit:setVisible(false)
  local s = CCScaleTo:create(0.2, 1)
  s = CCEaseBackOut:create(s)
  local f = CCCallFunc:create(function()
    xpcall(function()
      self.edit:setVisible(true)
    end, EDDebug)
  end)
  s = CCSequence:createWithTwoActions(s, f)
  bg:runAction(s)
end
class.show = show
local destroy = function(self)
  if not self then
    return
  end
  if not self.ui then
    return
  end
  if tolua.isnull(self.ui.bg) then
    return
  end
  local bg = self.ui.bg
  local s = CCScaleTo:create(0.2, 0)
  s = CCEaseBackIn:create(s)
  local f = CCCallFunc:create(function()
    xpcall(function()
      self.mainLayer:removeFromParentAndCleanup(true)
      if self.destroyHandler and self.isClose then
        self.destroyHandler()
      end
      if self.callback then
        self.callback()
      end
    end, EDDebug)
  end)
  s = CCSequence:createWithTwoActions(s, f)
  self.edit:setVisible(false)
  bg:runAction(s)
end
class.destroy = destroy
local doClickName = function(self)
end
class.doClickName = doClickName
local doClickRoll = function(self)
  self:rollName()
end
class.doClickRoll = doClickRoll
local function sendSetName(self)
  local function handler()
    if self.type == "pay" and ed.player._rmb < ed.player:getSetNameCost() then
      ed.showHandyDialog("toRecharge")
      return
    end
    ed.netdata.setname = {
      name = self:getName(),
      cost = self.type == "pay" and ed.player:getSetNameCost()
    }
    ed.netreply.setname = self:doSetNameReply()
    local msg = ed.upmsg.set_name()
    msg._name = self:getName()
    msg._type = self.type == "free" and 0 or 1
    ed.send(msg, "set_name")
  end
  return handler
end
class.sendSetName = sendSetName
local function doSetName(self)
  if self:getNameLength() < 1 then
    ed.showToast(T(LSTR("BENAME.PLEASE_ENTER_A_NAME")))
    return
  end
  local name = self:getName()
  if ed.dirtyword_check(name) then
    ed.showToast(T(LSTR("BENAME.THIS_NAME_IS_NOT_AVAILABLE_PLEASE_REENTER")))
    return
  end
  name = string.gsub(name, "[\r\n]", "")
  --fix it 输入六个中文字 会提示超出长度
  local _, count = string.gsub(name, "[^\128-\193]", "")
  if count > 13 then
    ed.showToast(T(LSTR("BENAME.NAME_CAN_NOT_EXCEED_SEVEN_WORDS")))
    return
  end
  local handler = self:sendSetName()
  if self.type == "free" then
    handler()
  else
    ed.showConfirmDialog({
      text = T(LSTR("BENAME.COST_100_DIAMONDS_TO_CHANGE_THE_NAME \\N_CONTINUE")),
      rightHandler = handler
    })
  end
end
class.doSetName = doSetName
local function doSetNameReply(self)
  local function handler(result)
    if result == "success" then
      self:destroy()
    elseif result == "exists" then
      ed.showToast(T(LSTR("BENAME.NAME_HAS_BEEN_OCCUPIED")))
    elseif result == "dirty_word" then
      ed.showToast(T(LSTR("BENAME.THIS_NAME_IS_NOT_AVAILABLE_PLEASE_REENTER")))
    else
      ed.showToast(T(LSTR("BENAME.DATA_ERROR")))
    end
  end
  return handler
end
class.doSetNameReply = doSetNameReply
local doClickok = function(self)
  self:doSetName()
end
class.doClickok = doClickok
local doClickCancel = function(self)
  self.isClose = true
  self:destroy()
end
class.doClickCancel = doClickCancel
