local class = newclass()
ed.scrollview = class
local function create(param)
  local self = {}
  setmetatable(self, class.mt)
  param = param or {}
  self._widthOffset = param.widthOffset or 0
  self._heightOffset = param.heightOffset or 0
  self._cliprect = param.cliprect
  self._noshade = param.noshade
  self._shaderect = param.shaderect
  self._container = param.container
  self._zorder = param.zorder
  self._priority = param.priority
  self._direction = param.direction or "v"
  self._barThick = param.barThick
  self._barPosition = param.barPosition
  self._barLenOffset = param.barLenOffset or 0
  self._barPosOffset = param.barPosOffset or ccp(0, 0)
  self._useBar = param.useBar
  self._initHandler = param.initHandler
  self._pageSize = param.pageSize or CCSizeMake(1, 1)
  self._rowCount = self._pageSize.width
  self._rowCount = math.max(self._rowCount, 1)
  self._columnCount = self._pageSize.height
  self._columnCount = math.max(self._columnCount, 1)
  self._pageCount = self._rowCount * self._columnCount
  self._pageSequence = param.pageSequence
  self._oriPosition = param.oriPosition or ccp(0, 0)
  self._itemSize = param.itemSize or CCSizeMake(0, 0)
  self._ox = self._oriPosition.x
  self._oy = self._oriPosition.y
  self._dx = self._itemSize.width
  self._dy = self._itemSize.height
  self._doPressIn = param.doPressIn
  self._cancelPressIn = param.cancelPressIn
  self._doClickIn = param.doClickIn
  self._cancelClickIn = param.cancelClickIn
  self._xMax = 0
  self._yMax = 0
  self._items = {}
  self.items = self._items
  local info = {}
  info.cliprect = self._cliprect
  info.rect = self._shaderect
  info.noshade = self._noshade
  info.zorder = self._zorder
  info.container = self._container
  info.priority = self._priority
  if self._useBar then
    info.bar = self:initBar()
    info.bar.barthick = self._barThick
  end
  info.doPressIn = self._doPressIn
  info.cancelPressIn = self._cancelPressIn
  info.doClickIn = self._doClickIn
  info.cancelClickIn = self._cancelClickIn
  self.draglist = ed.draglist.create(info)
  return self
end
class.create = create
local function initBar(self)
  local origin = self._cliprect.origin
  local size = self._cliprect.size
  local x, y = origin.x, origin.y
  local w, h = size.width, size.height
  local len, pos
  if self._direction == "v" then
    len = h - 10 + self._barLenOffset
    if self._barPosition == "left" then
      pos = ccpAdd(self._barPosOffset, ccp(x, y + h / 2))
    else
      pos = ccpAdd(self._barPosOffset, ccp(x + w, y + h / 2))
    end
  else
    len = w - 10 + self._barLenOffset
    if self._barPosition == "top" then
      pos = ccpAdd(self._barPosOffset, ccp(x + w / 2, y + h))
    else
      pos = ccpAdd(self._barPosOffset, ccp(x + w / 2, y))
    end
  end
  return {bglen = len, bgpos = pos}
end
class.initBar = initBar
local function getItemXY(self, index)
  local xc = self._rowCount
  local yc = self._columnCount
  local tc = self._pageCount
  local seq
  local x, y = 1, 1
  if self._direction == "v" then
    seq = self._pageSequence or "hv"
    if seq == "hv" then
      x = (index - 1) % xc
      x = math.max(x, 0)
      y = math.floor((index - 1) / xc)
      y = math.max(y, 0)
    else
      x = math.floor((index - 1) % tc / yc)
      x = math.max(x, 0)
      y = math.floor((index - 1) / tc) * yc + math.ceil(math.max((index - 1) % tc, 0) % yc)
    end
  else
    seq = self._pageSequence or "vh"
    if seq == "vh" then
      x = math.floor((index - 1) / yc)
      x = math.max(x, 0)
      y = (index - 1) % yc
      y = math.max(y, 0)
    else
      x = math.floor((index - 1) / tc) * xc + math.ceil(math.max((index - 1) % tc, 0) % xc)
      y = math.floor((index - 1) % tc / xc)
      y = math.max(y, 0)
    end
  end
  self._xMax = math.max(x, self._xMax)
  self._yMax = math.max(y, self._yMax)
  return x, y
end
class.getItemXY = getItemXY
local function getItemPos(self, index)
  local x, y = self:getItemXY(index)
  local px = self._ox + self._dx * x
  local py = self._oy - self._dy * y
  return ccp(px, py)
end
class.getItemPos = getItemPos
local function push(self, param)
  param = param or {}
  local index = #self._items + 1
  local container = CCSprite:create()
  container:setCascadeOpacityEnabled(true)
  container:setAnchorPoint(ccp(0, 0))
  local pos = self:getItemPos(index)
  self.draglist:addItem(container, pos)
  param.container = container
  local item = {
    container = container,
    ui = self._initHandler(param),
    param = param
  }
  table.insert(self._items, item)
  self:refreshSize()
end
class.push = push
local addMulti = function(self, params)
  params = params or {}
  for i = 1, #params do
    self:add(params[i], true)
  end
  self:refresh()
end
class.addMulti = addMulti
local function add(self, param, noRefresh)
  param = param or {}
  local container = CCSprite:create()
  container:setCascadeOpacityEnabled(true)
  container:setAnchorPoint(ccp(0, 0))
  self.draglist:addItem(container, ccp(0, 0))
  param.container = container
  local item = {
    container = container,
    ui = self._initHandler(param),
    param = param
  }
  table.insert(self._items, item)
  if not noRefresh then
    self:refresh()
  end
end
class.add = add
local function remove(self, index)
  table.remove(self._items, index)
  self:refresh()
end
class.remove = remove
local function refresh(self)
  self:order()
  for i = 1, #self._items do
    local container = self._items[i].container
    local pos = self:getItemPos(i)
    container:setPosition(pos)
  end
  self:refreshSize()
end
class.refresh = refresh
local function refreshSize(self)
  if self._direction == "v" then
    self.draglist:initListHeight(self._dy * (self._yMax + 1) + self._heightOffset, false)
  elseif self._direction == "h" then
    self.draglist:initListWidth(self._dx * (self._xMax + 1) + self._widthOffset, false)
  end
end
class.refreshSize = refreshSize
local function order(self)
  for i = 1, #self._items do
    for j = i, 2, -1 do
      if (self._items[j].param.index or 0) < (self._items[i].param.index or 0) then
        local temp = self._items[i]
        self._items[i] = self._items[j]
        self._items[j] = temp
      end
    end
  end
end
class.order = order
local function move2end(self, duration, callback)
  if self.draglist.isPressing then
    self.draglist.listLayer:stopAllActions()
    if callback then
      callback()
    end
    return
  end
  local ch = self._cliprect.size.height
  local lh = self._dy * (self._yMax + 1) + self._heightOffset
  if ch < lh then
    self.draglist.listLayer:stopAllActions()
    local pos = ccp(0, lh - ch)
    local m = CCMoveTo:create(duration, pos)
    m = CCEaseBackOut:create(m)
    local f = CCCallFunc:create(function()
      xpcall(function()
        if callback then
          callback()
        end
      end, EDDebug)
    end)
    self.draglist.listLayer:runAction(ed.readaction.create({
      t = "seq",
      m,
      f
    }))
  elseif callback then
    callback()
  end
end
class.move2end = move2end
local destroy = function(self)
  local layer = self.draglist.mainLayer
  if not tolua.isnull(layer) then
    layer:removeFromParentAndCleanup(true)
  end
end
class.destroy = destroy
local doMoveLayer = function(self, endPos, callback)
  local m = CCMoveTo:create(0.2, endPos)
  m = CCEaseSineOut:create(m)
  local f = CCCallFunc:create(function()
    xpcall(function()
      if callback then
        callback()
      end
    end, EDDebug)
  end)
  self.draglist.listLayer:runAction(ed.readaction.create({
    t = "seq",
    m,
    f
  }))
end
class.doMoveLayer = doMoveLayer
local setTouchEnabled = function(self, enabled)
  self.draglist:setTouchEnabled(enabled)
end
class.setTouchEnabled = setTouchEnabled
local checkTouchInList = function(self, x, y)
  return self.draglist:checkTouchInList(x, y)
end
class.checkTouchInList = checkTouchInList
