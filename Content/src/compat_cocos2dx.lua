--[[
    cocos2d-x 2.x -> Axmol ���ݲ� v2

    ��;���� 521 ���� Lua �ļ�ʹ�� CC ǰ׺ API �Ĵ�������� Axmol ������
    ���ԣ��� main.lua �ͷ require "compat_cocos2dx"
    ����ӳ����ȫ�ֿռ�ע�ᣬ�ɴ��������޸�
--]]

-----------------------------------------------------------------
-- Axmol ʹ�� "ax" �����ռ䣬�ɴ�����ȫ����
-- �� ax �����ռ䵼����ȫ��
-----------------------------------------------------------------

-- ȷ�� ax ȫ�ִ��ڣ��� Axmol Lua ����ṩ��
if not ax then
    error("compat_cocos2dx.lua: 'ax' namespace not found. Make sure Axmol Lua engine is initialized first.")
end

-- ���� ax ���캯���ı������ã���ֹ ax ���������޸ģ�
local _vec2 = ax.vec2
local _size = ax.size
local _rect = ax.rect
local _Color32 = ax.Color4B or ax.Color32 or ax.color32
if not _vec2 then
    _vec2 = function(x, y) return {x=x, y=y} end
    ax.vec2 = _vec2
    print("[compat] ax.vec2 fallback: using plain table")
end
if not _size then
    _size = function(w, h) return {width=w, height=h} end
    ax.size = _size
end
if not _rect then
    _rect = function(x, y, w, h) return {x=x, y=y, width=w, height=h} end
    ax.rect = _rect
end

-- 包装 ax.rect，让返回值包含 containsPoint 方法（cocos2d-x 2.x 兼容）
local _orig_rect = _rect
_rect = function(x, y, w, h)
    x, y, w, h = x or 0, y or 0, w or 0, h or 0
    local ok, r = pcall(_orig_rect, x, y, w, h)
    if not ok then r = {x=x, y=y, width=w, height=h} end
    -- 安全添加 containsPoint（如果 r 是 userdata 则 pcall 保护）
    if r then
        local function _containsPoint(point_or_x, maybe_y)
            local px, py
            if type(point_or_x) == "table" then
                px = point_or_x.x or 0
                py = point_or_x.y or 0
            else
                px = point_or_x or 0
                py = maybe_y or 0
            end
            local rx = (type(r.x) == "number") and r.x or (r.origin and r.origin.x) or 0
            local ry = (type(r.y) == "number") and r.y or (r.origin and r.origin.y) or 0
            local rw = (type(r.width) == "number") and r.width or (r.size and r.size.width) or 0
            local rh = (type(r.height) == "number") and r.height or (r.size and r.size.height) or 0
            return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
        end
        pcall(function() r.containsPoint = _containsPoint end)
    end
    return r
end
ax.rect = _rect

-----------------------------------------------------------------
-- ��ʱ���� Axmol ȫ�ֱ�����������ֱ������ CC* ȫ�ֱ�����
-----------------------------------------------------------------
local _G_mt = getmetatable(_G)
local _G_old_newindex
if _G_mt and _G_mt.__newindex then
    _G_old_newindex = _G_mt.__newindex
    _G_mt.__newindex = nil
end

-----------------------------------------------------------------
-- 1. ��������ӳ�䣨ȫ���� �� ax ���ͣ�
-----------------------------------------------------------------

-- ��ѧ���ͣ�ʹ�ñ������ã������� ax ������״̬��
CCPoint  = _vec2
CCSize   = _size
CCRect   = _rect

CCSizeMake = function(w, h)
    local s = _size(w or 0, h or 0)
    -- 确保 size 表同时支持 width/height 和扁平访问
    return s
end
CCRectMake = function(x, y, w, h)
    x, y, w, h = x or 0, y or 0, w or 0, h or 0
    local r = _rect(x, y, w, h)
    -- 添加 cocos2d-x 2.x 嵌套访问支持：rect.origin.x, rect.size.width
    if r then
        r.origin = {x = x, y = y}
        r.size = {width = w, height = h}
        -- containsPoint 兼容：cocos2d-x 2.x Rect 方法
        -- 参数可以是 ccp(x,y) 也可以直接传 x,y 数字
        r.containsPoint = function(self, point_or_x, maybe_y)
            local px, py
            if type(point_or_x) == "table" then
                px = point_or_x.x or 0
                py = point_or_x.y or 0
            else
                px = point_or_x or 0
                py = maybe_y or 0
            end
            local rx = r.x or 0
            local ry = r.y or 0
            local rw = r.width or (r.size and r.size.width) or 0
            local rh = r.height or (r.size and r.size.height) or 0
            return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
        end
    end
    return r
end
ccp = function(x, y) return _vec2(x or 0, y or 0) end

-- ��ɫ���ͣ�Axmol �� Color32 ���� Color3B��
CCColor3B = _Color32
Color3B   = _Color32
if _Color32 then
    ccc3 = function(r, g, b) return _Color32(r, g, b) end
    ccc4 = function(r, g, b, a) return _Color32(r, g, b, a) end
else
    -- fallback������һ�� table ģ����ɫ
    ccc3 = function(r, g, b) return {r=r, g=g, b=b, a=255} end
    ccc4 = function(r, g, b, a) return {r=r, g=g, b=b, a=a} end
end

ccWHITE   = ccc3(255, 255, 255)
ccBLACK   = ccc3(0, 0, 0)
ccRED     = ccc3(255, 0, 0)
ccGREEN   = ccc3(0, 255, 0)
ccBLUE    = ccc3(0, 0, 255)
ccYELLOW  = ccc3(255, 255, 0)
ccGRAY    = ccc3(128, 128, 128)
ccORANGE  = ccc3(255, 127, 0)
ccMAGENTA = ccc3(255, 0, 255)

-----------------------------------------------------------------
-- 2. �ڵ���ӳ�䣨CC ǰ׺ �� Axmol �ࣩ
-----------------------------------------------------------------

CCNode           = ax.Node
CCSprite         = ax.Sprite
CCScene          = ax.Scene
CCLayer          = ax.Layer
CCLayerColor     = ax.LayerColor
CCLayerGradient  = ax.LayerGradient
-- CCLabelTTF ���ݰ�װ
-- cocos2d-x 2.x: CCLabelTTF:create(text, fontName, fontSize)
-- Axmol: Label:createWithSystemFont(text, fontName, fontSize)
-- ֱ�Ӹ�ֵ ax.Label ������Ϊ Label:create() �����ܲ���
do
    local _Label = ax.Label
    CCLabelTTF = setmetatable({}, {
        __index = function(_, key)
            return _Label[key]
        end,
        __call = function(_, ...)  -- ֧�� CCLabelTTF(...) �� create
            return CCLabelTTF:create(...)
        end,
    })
    function CCLabelTTF:create(text, fontName, fontSize)
        if text and fontName and fontSize then
            return _Label.createWithSystemFont(_Label, text, fontName, fontSize)
        elseif text then
            return _Label.createWithSystemFont(_Label, text, "Arial", 24)
        else
            return _Label.create(_Label)
        end
    end
    function CCLabelTTF:createWithTTF(text, fontName, fontSize)
        if text and fontName and fontSize then
            local ok, lbl = pcall(function() return _Label.createWithTTF(_Label, text, fontName, fontSize) end)
            if ok then return lbl end
            return _Label.createWithSystemFont(_Label, text, fontName, fontSize)
        end
        return _Label.create(_Label)
    end
    function CCLabelTTF:setText(text)
        if self and self.setString then self:setString(text or "") end
    end
end

CCLabelBMFont    = ax.Label
CCMenu           = ax.Menu
CCMenuItem       = ax.MenuItem
CCMenuItemImage  = ax.MenuItemImage
CCMenuItemLabel  = ax.MenuItemLabel
CCMenuItemFont   = ax.MenuItemFont
CCMenuItemToggle = ax.MenuItemToggle
CCMenuItemSprite = ax.MenuItemSprite
CCProgressTimer  = ax.ProgressTimer
CCProgressFromTo = ax.ProgressFromTo
CCRenderTexture  = ax.RenderTexture
CCDrawNode       = ax.DrawNode
CCClippingNode   = ax.ClippingNode
CCParallaxNode   = ax.ParallaxNode

-----------------------------------------------------------------
-- 3. Director / ����ӳ��
-----------------------------------------------------------------

CCDirector = ax.Director
-- ���� Director ��ķ���������cocos2d-x 2.x �� Axmol��
-- tolua++ ��ʵ������ͨ��������ң�����ֱ�������������
if ax.Director.getVisibleSize and not ax.Director.getWinSize then
    function ax.Director:getWinSize() return self:getVisibleSize() end
end
if not ax.Director.getWinSizeInPixels then
    function ax.Director:getWinSizeInPixels() return self:getVisibleSize() end
end
if not ax.Director.getOpenGLView then
    function ax.Director:getOpenGLView()
        if self.getGLView then return self:getGLView() end
        return nil
    end
end
if CCDirector and not CCDirector.sharedDirector then
    CCDirector.sharedDirector = function() return ax.Director:getInstance() end
end

CCFileUtils = ax.FileUtils
if CCFileUtils and not CCFileUtils.sharedFileUtils then
    CCFileUtils.sharedFileUtils = function() return ax.FileUtils:getInstance() end
end

CCApplication = ax.Application
if CCApplication and not CCApplication.sharedApplication then
    CCApplication.sharedApplication = function() return ax.Application:getInstance() end
end

CCUserDefault = ax.UserDefault
if CCUserDefault and not CCUserDefault.sharedUserDefault then
    CCUserDefault.sharedUserDefault = function() return ax.UserDefault:getInstance() end
end

-- EGLView���ɴ����� CCEGLView:sharedOpenGLView():getFrameSize()��
if ax.EGLView then
    CCEGLView = ax.EGLView
    if not CCEGLView.sharedOpenGLView then
        CCEGLView.sharedOpenGLView = function() return ax.EGLView:getInstance() end
    end
else
    -- Axmol û�� EGLView/GLView ȫ���࣬����һ�� stub
    CCEGLView = {}
    function CCEGLView.sharedOpenGLView()
        local view = {}
        function view:getFrameSize()
            local vs = ax.Director:getInstance():getVisibleSize()
            return { width = vs.width, height = vs.height }
        end
        function view:getVisibleSize()
            return ax.Director:getInstance():getVisibleSize()
        end
        function view:getDesignResolutionSize()
            return ax.Director:getInstance():getVisibleSize()
        end
        return view
    end
end

-----------------------------------------------------------------
-- 4. Action ��ӳ��
-----------------------------------------------------------------

CCAction             = ax.Action
CCFiniteTimeAction   = ax.FiniteTimeAction
CCMoveTo             = ax.MoveTo
CCMoveBy             = ax.MoveBy
CCJumpTo             = ax.JumpTo
CCJumpBy             = ax.JumpBy
CCBezierTo           = ax.BezierTo
CCBezierBy           = ax.BezierBy
CCScaleTo            = ax.ScaleTo
CCScaleBy            = ax.ScaleBy
CCRotateTo           = ax.RotateTo
CCRotateBy           = ax.RotateBy
CCBlink              = ax.Blink
CCFadeIn             = ax.FadeIn
CCFadeOut            = ax.FadeOut
CCFadeTo             = ax.FadeTo
CCTintTo             = ax.TintTo
CCTintBy             = ax.TintBy
CCDelayTime          = ax.DelayTime
CCReverseTime        = ax.ReverseTime
CCAnimate            = ax.Animate
CCAnimation          = ax.Animation
CCAnimationCache     = ax.AnimationCache
CCCallFunc           = ax.CallFunc
CCCallFuncN          = ax.CallFuncN
CCTargetedAction     = ax.TargetedAction
CCShow               = ax.Show
CCHide               = ax.Hide
CCToggleVisibility   = ax.ToggleVisibility
CCRemoveSelf         = ax.RemoveSelf
CCFlipX              = ax.FlipX
CCFlipY              = ax.FlipY
CCPlace              = ax.Place
CCFollow             = ax.Follow
CCSpeed              = ax.Speed

-- Ease ����
CCEaseIn             = ax.EaseIn
CCEaseOut            = ax.EaseOut
CCEaseInOut          = ax.EaseInOut
CCEaseSineIn         = ax.EaseSineIn
CCEaseSineOut        = ax.EaseSineOut
CCEaseSineInOut      = ax.EaseSineInOut
CCEaseExponentialIn  = ax.EaseExponentialIn
CCEaseExponentialOut = ax.EaseExponentialOut
CCEaseExponentialInOut = ax.EaseExponentialInOut
CCEaseElasticIn      = ax.EaseElasticIn
CCEaseElasticOut     = ax.EaseElasticOut
CCEaseElasticInOut   = ax.EaseElasticInOut
CCEaseBounceIn       = ax.EaseBounceIn
CCEaseBounceOut      = ax.EaseBounceOut
CCEaseBounceInOut    = ax.EaseBounceInOut
CCEaseBackIn         = ax.EaseBackIn
CCEaseBackOut        = ax.EaseBackOut
CCEaseBackInOut      = ax.EaseBackInOut

CCSpriteFrame       = ax.SpriteFrame
print("[compat] CCSpriteFrame = ax.SpriteFrame -> " .. tostring(CCSpriteFrame))
if not CCSpriteFrame then
    print("[compat] WARNING: ax.SpriteFrame is nil at load time, using lazy lookup stub")
    -- ����ʱ�ӳٲ��ң�ÿ��ʹ��ʱ�� ax.SpriteFrame ���»�ȡ
    CCSpriteFrame = setmetatable({}, {
        __index = function(_, key)
            if ax.SpriteFrame then
                return ax.SpriteFrame[key]
            end
            return nil
        end,
        __call = function(_, ...)
            if ax.SpriteFrame then
                return ax.SpriteFrame(...)
            end
        end,
    })
end

-- ��϶���
if ax.Sequence then
    CCSequence = ax.Sequence
    -- �ɴ��������ð�ŵ��� CCSequence:createWithTwoActions(a, b)
    -- Ҳ�����õ���� CCSequence.createWithTwoActions(a, b)
    -- ð�ŵ���ʱ self=CCSequence ����Ϊ��һ������
    if not rawget(CCSequence, "createWithTwoActions") then
        CCSequence.createWithTwoActions = function(self_or_a, b_or_c, maybe_c)
            local a, b
            if maybe_c ~= nil then
                -- ð�ŵ���: self_or_a=self, b_or_c=a, maybe_c=b
                a, b = b_or_c, maybe_c
            else
                -- �����: self_or_a=a, b_or_c=b
                a, b = self_or_a, b_or_c
            end
            if a and b then
                return CCSequence:create(a, b)
            elseif a then
                return a
            else
                return b
            end
        end
    end
end

CCSpawn      = ax.Spawn
CCRepeat     = ax.Repeat
CCRepeatForever = ax.RepeatForever

CCCallFuncN = ax.CallFunc

-- CCSpawn:createWithTwoActions compat
if CCSpawn and not rawget(CCSpawn, "createWithTwoActions") then
    CCSpawn.createWithTwoActions = function(self_or_a, b_or_c, maybe_c)
        local a, b
        if maybe_c ~= nil then
            a, b = b_or_c, maybe_c
        else
            a, b = self_or_a, b_or_c
        end
        if a and b then
            return CCSpawn:create(a, b)
        elseif a then
            return a
        elseif b then
            return b
        end
    end
end

-- Wrap CCSequence:create and CCSpawn:create to support table args (ccArrayMake returns table)
do
    local _seqCreate = CCSequence and CCSequence.create
    local _spawnCreate = CCSpawn and CCSpawn.create
    if _seqCreate then
        CCSequence.create = function(...)
            local args = {...}
            if #args == 1 and type(args[1]) == "table" then
                return _seqCreate(unpack(args[1]))
            else
                return _seqCreate(...)
            end
        end
    end
    if _spawnCreate then
        CCSpawn.create = function(...)
            local args = {...}
            if #args == 1 and type(args[1]) == "table" then
                return _spawnCreate(unpack(args[1]))
            else
                return _spawnCreate(...)
            end
        end
    end
end

-----------------------------------------------------------------
-- 5. ����/��������ӳ��
-----------------------------------------------------------------

CCSpriteFrameCache = ax.SpriteFrameCache
if CCSpriteFrameCache and not CCSpriteFrameCache.sharedSpriteFrameCache then
    CCSpriteFrameCache.sharedSpriteFrameCache = function()
        local ok, inst = pcall(function() return ax.SpriteFrameCache:getInstance() end)
        if ok then return inst end
        -- fallback: �����౾����֧�� gc/setGcTime ��׮�������ã�
        return CCSpriteFrameCache
    end
end

CCTextureCache = ax.TextureCache
if CCTextureCache and not CCTextureCache.sharedTextureCache then
    CCTextureCache.sharedTextureCache = function()
        local ok, inst = pcall(function() return ax.Director:getInstance():getTextureCache() end)
        if ok then return inst end
        return CCTextureCache
    end
end

CCActionManager = ax.ActionManager

-----------------------------------------------------------------
-- 5b. gc/setGcTime ׮��cocos2d-x 2.x ������չ������
-----------------------------------------------------------------
if ax.SpriteFrameCache then
    if not ax.SpriteFrameCache.gc then function ax.SpriteFrameCache:gc() end end
    if not ax.SpriteFrameCache.setGcTime then function ax.SpriteFrameCache:setGcTime() end end
    -- cocos2d-x 2.x �� Axmol ������ӳ��
    -- Axmol Lua ��: getSpriteFrameByName C++ �� Lua ע����Ϊ "getSpriteFrame"
    if not ax.SpriteFrameCache.spriteFrameByName then
        ax.SpriteFrameCache.spriteFrameByName = ax.SpriteFrameCache.getSpriteFrameByName
            or ax.SpriteFrameCache.getSpriteFrame
    end
end
if ax.TextureCache then
    if not ax.TextureCache.gc then function ax.TextureCache:gc() end end
    if not ax.TextureCache.setGcTime then function ax.TextureCache:setGcTime() end end
end

-- Director setContentScaleFactor stub
if ax.Director and not ax.Director.setContentScaleFactor then
    function ax.Director:setContentScaleFactor() end
end

-----------------------------------------------------------------
-- 6. ScrollView / Scale9Sprite
-----------------------------------------------------------------

if ax.ScrollView then
    CCScrollView = ax.ScrollView
elseif ax.extensions and ax.extensions.ScrollView then
    CCScrollView = ax.extensions.ScrollView
end

-- EditBox 兼容（Axmol 3.0 注册为 ccui.EditBox）
if ccui and ccui.EditBox then
    CCEditBox = ccui.EditBox
else
    -- fallback stub
    CCEditBox = setmetatable({}, {
        __index = function(_, key)
            if key == "create" then
                return function(size, bg, font, fontSize, ...)
                    -- 返回一个模拟的 editbox node
                    local node = ax.Node:create()
                    node:setContentSize(size or CCSizeMake(200, 40))
                    -- stub 方法
                    node.setText = function(self, text) self._editText = tostring(text or "") end
                    node.getText = function(self) return self._editText or "" end
                    node.setString = function(self, text) self._editText = tostring(text or "") end
                    node.getString = function(self) return self._editText or "" end
                    node.getStringValue = function(self) return "" end
                    node.setFont = function(self, ...) end
                    node.setFontSize = function(self, ...) end
                    node.setFontColor = function(self, ...) end
                    node.setPlaceHolder = function(self, ...) end
                    node.setInputMode = function(self, ...) end
                    node.setInputFlag = function(self, ...) end
                    node.setReturnType = function(self, ...) end
                    node.setMaxLength = function(self, ...) end
                    node.setMessageRect = function(self, ...) end
                    node.registerScriptEditBoxHandler = function(self, ...) end
                    node.unregisterScriptEditBoxHandler = function(self) end
                    node.setTextHorizontalAlignment = function(self, ...) end
                    node.setPlaceholderFont = function(self, ...) end
                    node.setPlaceholderFontSize = function(self, ...) end
                    node.setPlaceholderFontColor = function(self, ...) end
                    return node
                end
            end
            return nil
        end,
    })
    print("[compat] CCEditBox fallback: using stub")
end

-- Axmol registers Scale9Sprite as axui.Scale9Sprite (global axui table)
local _axui = rawget(_G, "axui") or rawget(_G, "ccui") or (ax and ax.ui)
if _axui and _axui.Scale9Sprite then
    CCScale9Sprite = _axui.Scale9Sprite
elseif ax.Scale9Sprite then
    CCScale9Sprite = ax.Scale9Sprite
elseif ax.extensions and ax.extensions.Scale9Sprite then
    CCScale9Sprite = ax.extensions.Scale9Sprite
end
-- 确保 CCScale9Sprite 可用（Axmol 3.0 注册为 ccui.Scale9Sprite）
if not CCScale9Sprite then
    -- fallback: 用 Sprite 模拟（无 9-patch 拉伸功能）
    CCScale9Sprite = setmetatable({}, {
        __index = function(_, key)
            if key == "create" then
                return function(...)
                    local ok, spr = pcall(function(...) return ax.Sprite:create(...) end, ...)
                    if ok and spr then return spr end
                    return ax.Sprite:create()
                end
            elseif key == "createWithSpriteFrame" then
                return function(frame, capInsets)
                    if frame then
                        local ok, spr = pcall(ax.Sprite.createWithSpriteFrame, ax.Sprite, frame)
                        if ok and spr then return spr end
                    end
                    return ax.Sprite:create()
                end
            elseif key == "createWithSpriteFrameName" then
                return function(name, capInsets)
                    if name then
                        local ok, spr = pcall(ax.Sprite.createWithSpriteFrameName, ax.Sprite, name)
                        if ok and spr then return spr end
                    end
                    return ax.Sprite:create()
                end
            end
            if ax.Sprite then return ax.Sprite[key] end
            return nil
        end,
        __call = function(_, ...) return ax.Sprite:create() end,
    })
    print("[compat] CCScale9Sprite fallback: using ax.Sprite proxy")
end

-----------------------------------------------------------------
-- 7. SimpleAudioEngine ����
-- �ɴ����� SimpleAudioEngine:sharedEngine():playEffect(...)
-- ӳ�䵽 ax.AudioEngine
-----------------------------------------------------------------

SimpleAudioEngine = {}

function SimpleAudioEngine.sharedEngine()
    local engine = {}
    function engine:playEffect(file, loop)
        local ok, id = pcall(function() return ax.AudioEngine.play2d(file, loop or false) end)
        if ok then return id end
    end
    function engine:stopEffect(id)
        pcall(function() ax.AudioEngine.stop(id) end)
    end
    function engine:stopAllEffects()
        pcall(function() ax.AudioEngine.stopAll() end)
    end
    function engine:setEffectsVolume(vol)
        -- AudioEngine ʹ�� per-audio volume
    end
    function engine:getEffectsVolume()
        return 1.0
    end
    function engine:playMusic(file, loop)
        ax.AudioEngine.stopAll()
        return ax.AudioEngine.play2d(file, loop ~= false)
    end
    function engine:stopMusic()
        -- AudioEngine û��ȫ�� stopMusic����Ҫ�� Lua �����
    end
    function engine:setMusicVolume(vol)
        -- per-audio volume
    end
    function engine:pauseEffect(id)
        ax.AudioEngine.pause(id)
    end
    function engine:resumeEffect(id)
        ax.AudioEngine.resume(id)
    end
    function engine:pauseAllEffects()
        ax.AudioEngine.pauseAll()
    end
    function engine:resumeAllEffects()
        ax.AudioEngine.resumeAll()
    end
    function engine:playBackgroundMusic(file, loop)
        pcall(function() ax.AudioEngine.stopAll() end)
        local ok, id = pcall(function() return ax.AudioEngine.play2d(file, loop ~= false) end)
        if ok then return id end
    end
    function engine:stopBackgroundMusic()
        pcall(function() ax.AudioEngine.stopAll() end)
    end
    function engine:setBackgroundMusicVolume(vol)
        -- per-audio volume, not directly supported
    end
    function engine:getBackgroundMusicVolume()
        return 1.0
    end
    function engine:preloadEffect(file) end
    function engine:preloadBackgroundMusic(file) end
    function engine:unloadEffect(file) end
    function engine:willPlayMusic() return false end
    function engine:isBackgroundMusicPlaying() return false end
    return engine
end

-----------------------------------------------------------------
-- 8. CCArray ���ݣ��� Lua table ģ�⣩
-----------------------------------------------------------------

CCArray = {}
-- Helper: create a CCArray-compatible table with addObject/count methods
local function makeCCArray()
    local arr = {}
    arr.addObject = function(self, obj) table.insert(self, obj) end
    arr.addbject = arr.addObject  -- typo compat
    arr.count = function(self) return #self end
    arr.removeObject = function(self, idx) return table.remove(self, idx) end
    arr.removeObjectAtIndex = arr.removeObject
    arr.objectAtIndex = function(self, idx) return self[idx + 1] end
    arr.indexOfObject = function(self, obj)
        for i = 1, #self do
            if self[i] == obj then return i - 1 end
        end
        return -1
    end
    return arr
end
function CCArray.create(...)
    local args = {...}
    if #args == 1 and type(args[1]) == "table" then
        local arr = makeCCArray()
        for _, v in ipairs(args[1]) do table.insert(arr, v) end
        return arr
    end
    return makeCCArray()
end
function CCArray:createWithCapacity(n)
    return makeCCArray()
end
function CCArray:create(...)
    local args = {...}
    if #args == 1 and type(args[1]) == "table" then
        local arr = makeCCArray()
        for _, v in ipairs(args[1]) do table.insert(arr, v) end
        return arr
    end
    return makeCCArray()
end

-----------------------------------------------------------------
-- 9. ���ߺ���
-----------------------------------------------------------------

-- bit ����ݣ��ɴ��� require "bit"��
if not bit then
    bit = {
        band   = function(a, b) return a & b end,
        bor    = function(a, b) return a | b end,
        bxor   = function(a, b) return a ~ b end,
        bnot   = function(a) return ~a end,
        lshift = function(a, n) return a << n end,
        rshift = function(a, n) return a >> n end,
    }
end

-- ��־
CCLuaLog = function(msg) print("[LUA] " .. tostring(msg)) end

-- ���볣��
CCTextAlignmentLeft   = 0
CCTextAlignmentCenter = 1
CCTextAlignmentRight  = 2
kCCTextAlignmentLeft   = 0
kCCTextAlignmentCenter = 1
kCCTextAlignmentRight  = 2
CCVerticalTextAlignmentTop      = 0
CCVerticalTextAlignmentCenter   = 1
CCVerticalTextAlignmentBottom   = 2

-- ��������
kCCTouchBegan     = 0
kCCTouchMoved     = 1
kCCTouchEnded     = 2
kCCTouchCancelled = 3

-- GL ״̬
ccGLBlendFunc = function(src, dst) end

-----------------------------------------------------------------
-- 10. ccp ��ѧ������ʹ�ñ������� _vec2��
-----------------------------------------------------------------

ccpAdd      = function(a, b) return _vec2(a.x + b.x, a.y + b.y) end
ccpSub      = function(a, b) return _vec2(a.x - b.x, a.y - b.y) end
ccpMult     = function(a, s) return _vec2(a.x * s, a.y * s) end
ccpCompMult = function(a, b) return _vec2(a.x * b.x, a.y * b.y) end
ccpLengthSQ = function(a) return a.x * a.x + a.y * a.y end
ccpDistanceSQ = function(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return dx * dx + dy * dy
end
ccpNormalize = function(a)
    local len = math.sqrt(a.x * a.x + a.y * a.y)
    if len > 0 then return _vec2(a.x / len, a.y / len) end
    return _vec2(0, 0)
end
ccpPerp     = function(a) return _vec2(-a.y, a.x) end
ccpToAngle  = function(a) return math.atan2(a.y, a.x) end
ccpForAngle = function(a) return _vec2(math.cos(a), math.sin(a)) end
ccpClamp    = function(a, min_v, max_v)
    return _vec2(
        math.min(math.max(a.x, min_v.x), max_v.x),
        math.min(math.max(a.y, min_v.y), max_v.y)
    )
end
ccpLength   = function(a) return math.sqrt(a.x * a.x + a.y * a.y) end
ccpDistance = function(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end
ccpDot   = function(a, b) return a.x * b.x + a.y * b.y end
ccpCross = function(a, b) return a.x * b.y - a.y * b.x end
ccpNeg   = function(a) return _vec2(-a.x, -a.y) end

-- Ҳ�� ed �����ռ���ע�ᣨtools.lua �ڼ��ݲ�֮����أ�
-- ed.ccpAdd ���� tools.lua ����ע��

-----------------------------------------------------------------
-- 11. EDDebug / debug ����
-----------------------------------------------------------------

-- �ɴ������ʹ�� EDDebug(...)��ӳ��Ϊ print
if not EDDebug then
    EDDebug = function(...)
        print("[DEBUG]", ...)
    end
end

-- table.pack ���ݣ�Lua 5.1 û�У�
if not table.pack then
    table.pack = function(...)
        local t = {...}
        t.n = select('#', ...)
        return t
    end
end

-- table.unpack ����
if not table.unpack then
    table.unpack = unpack
end
if not rawget(_G, "unpack") then
    rawset(_G, "unpack", table.unpack)
end

-- string.pack ���ݣ��ɴ��� protobuf ������Ҫ��

-----------------------------------------------------------------
-- 12. ����ȱʧ��ȫ��
-----------------------------------------------------------------

-- md5 / mycrypto �ɾɴ����Լ��� Lua ʵ���ṩ
-- LegendSetAniScaleFactor, LegendSetSoundSwitch �� C++ ���ṩ
-- tolua.isnull �� tolua++ ���ṩ
-- CCBReader, CCBContainer �� C++ ���ṩ

-- CCMessageBox ����
CCMessageBox = function(msg, title)
    print("[MSGBOX] " .. tostring(title) .. ": " .. tostring(msg))
end

-- CCLog ����
CCLog = function(...) print("[CC]", ...) end

-----------------------------------------------------------------
-- 13. ����ϵͳ���ݲ�
-- cocos2d-x 2.x: node:registerScriptTouchHandler(handler, isMulti, priority, swallows)
-- Axmol: EventDispatcher + EventListenerTouchOneByOne / AllAtOnce
-----------------------------------------------------------------

-- �� ax.Node ������ registerScriptTouchHandler ���ݷ���
-- �洢ÿ�� node �Ĵ������������ã������ظ�ע��
local _nodeTouchListeners = setmetatable({}, {__mode = "k"})
local _nodeTouchHandlers = setmetatable({}, {__mode = "k"})  -- save handler+params for re-register

if ax.Node then
    -- registerScriptTouchHandler(handler, isMultiTouches, priority, swallows)
    -- handler(event, ...) where event is "began"/"moved"/"ended"/"cancelled"
    -- force install: always override, don't check for existing method
    function ax.Node:registerScriptTouchHandler(handler, isMultiTouches, priority, swallows)
        if not handler then return end
        priority = priority or 0
        swallows = (swallows ~= false)  -- default true
        isMultiTouches = isMultiTouches or false

        -- Remove old listener
        self:unregisterScriptTouchHandler()

        local ok_create, listener = pcall(function()
            if isMultiTouches then
                return ax.EventListenerTouchAllAtOnce:create()
            else
                return ax.EventListenerTouchOneByOne:create()
            end
        end)
        if not ok_create or not listener then
            print("[COMPAT-ERR] Failed to create touch listener: " .. tostring(listener))
            return
        end

        if isMultiTouches then
            local ok_reg, err = pcall(function()
                listener:registerScriptHandler(function(touches, event)
                    if handler then
                        local pts = {}
                        for i, t in ipairs(touches or {}) do
                            pts[#pts+1] = t:getLocation()
                        end
                        handler(pts)
                    end
                end, ax.Handler.EVENT_TOUCHES_BEGAN)
            end)
            if not ok_reg then print("[COMPAT-ERR] multi-touch register failed: " .. tostring(err)) end
        else
            listener:setSwallowTouches(swallows)

            local ok1, err1 = pcall(function()
                listener:registerScriptHandler(function(touch, event)
                    if handler then
                        local ok_loc, loc = pcall(function() return touch:getLocation() end)
                        if ok_loc and loc then
                            local ok_h, ret = pcall(handler, "began", loc.x, loc.y)
                            if ok_h then
                                return ret ~= false
                            end
                        else
                            -- touch:getLocation() failed, try getLocationInView
                            local ok_loc2, loc2 = pcall(function() return touch:getLocationInView() end)
                            if ok_loc2 and loc2 then
                                local ok_h2, ret2 = pcall(handler, "began", loc2.x, loc2.y)
                                if ok_h2 then return ret2 ~= false end
                            end
                        end
                    end
                    return false
                end, ax.Handler.EVENT_TOUCH_BEGAN)
            end)
            if not ok1 then print("[COMPAT-ERR] began register failed: " .. tostring(err1)) end

            pcall(function()
                listener:registerScriptHandler(function(touch, event)
                    if handler then
                        local ok_loc, loc = pcall(function() return touch:getLocation() end)
                        if ok_loc and loc then
                            pcall(handler, "moved", loc.x, loc.y)
                        end
                    end
                end, ax.Handler.EVENT_TOUCH_MOVED)
            end)

            pcall(function()
                listener:registerScriptHandler(function(touch, event)
                    if handler then
                        local ok_loc, loc = pcall(function() return touch:getLocation() end)
                        if ok_loc and loc then
                            pcall(handler, "ended", loc.x, loc.y)
                        end
                    end
                end, ax.Handler.EVENT_TOUCH_ENDED)
            end)

            pcall(function()
                listener:registerScriptHandler(function(touch, event)
                    if handler then
                        local ok_loc, loc = pcall(function() return touch:getLocation() end)
                        if ok_loc and loc then
                            pcall(handler, "cancelled", loc.x, loc.y)
                        end
                    end
                end, ax.Handler.EVENT_TOUCH_CANCELLED)
            end)
        end

        local dispatcher = ax.Director:getInstance():getEventDispatcher()
        local ok_add, err_add
        -- Always use sceneGraphPriority: fixedPriority listeners don't receive
        -- touch events on Android in this Axmol build.  The node's Z-order in
        -- the scene tree determines dispatch order instead.
        ok_add, err_add = pcall(function()
            dispatcher:addEventListenerWithSceneGraphPriority(listener, self)
        end)
        if not ok_add then
            print("[COMPAT-ERR] addEventListener failed: " .. tostring(err_add))
        end
        _nodeTouchListeners[self] = listener
        _nodeTouchHandlers[self] = {handler, isMultiTouches, priority, swallows}
    end

    -- unregisterScriptTouchHandler - force install
    function ax.Node:unregisterScriptTouchHandler()
        local listener = _nodeTouchListeners[self]
        if listener then
            pcall(function()
                ax.Director:getInstance():getEventDispatcher():removeEventListener(listener)
            end)
            _nodeTouchListeners[self] = nil
        end
    end

    -- setTouchEnabled - cocos2d-x 2.x Layer ����
    -- Axmol û�� setTouchEnabled����Ҫ�ֶ�ʵ��
    -- ֱ���� ax.Layer �� ax.Node �϶����ӣ���Ϊ Lua ���� Layer Ԫ����һ���̳� Node��
    -- setTouchEnabled / isTouchEnabled for all nodes
    -- Cannot use rawset on C++ bound types; patch __index on Node metatable instead
    local _nodeMethods = {
        setTouchEnabled = function(self, enabled)
            self._touchEnabled = enabled
            if enabled then
                -- Re-register if we have a saved handler but no active listener
                local saved = _nodeTouchHandlers[self]
                local listener = _nodeTouchListeners[self]
                if saved and not listener and self.registerScriptTouchHandler then
                    self:registerScriptTouchHandler(saved[1], saved[2], saved[3], saved[4])
                end
            elseif not enabled and self.unregisterScriptTouchHandler then
                self:unregisterScriptTouchHandler()
            end
        end,
        isTouchEnabled = function(self)
            return self._touchEnabled == true
        end,
        numberOfRunningActions = function(self)
            local ok, result = pcall(function()
                return ax.Director:getInstance():getActionManager():getNumberOfRunningActionsInTarget(self)
            end)
            if ok and type(result) == 'number' then return result end
            -- fallback: check _runningActionCount property
            return self._runningActionCount or 0
        end,
    }
    -- Hook into ax.Node's metatable __index
    local mt = getmetatable(ax.Node)
    if mt then
        local oldIndex = mt.__index
        -- __index type: function (patched)
        if type(oldIndex) == "table" then
            for k, v in pairs(_nodeMethods) do
                rawset(oldIndex, k, v)
            end
            print("[COMPAT] setTouchEnabled added via table __index")
        elseif type(oldIndex) == "function" then
            mt.__index = function(t, k)
                if _nodeMethods[k] then return _nodeMethods[k] end
                return oldIndex(t, k)
            end
            print("[COMPAT] setTouchEnabled patched on ax.Node")
        else
            -- Fallback: try to set directly on the metatable
            for k, v in pairs(_nodeMethods) do
                mt[k] = v
            end
            print("[COMPAT] setTouchEnabled added via direct metatable set")
        end
    else
        -- No metatable - create one
        local proxy = {}
        proxy.__index = function(t, k)
            if _nodeMethods[k] then return _nodeMethods[k] end
        end
        setmetatable(ax.Node, proxy)
        print("[COMPAT] setTouchEnabled added via new metatable")
    end
    -- Test
    local testNode = ax.Node:create()
    print("[COMPAT] test node setTouchEnabled: " .. tostring(testNode.setTouchEnabled))
    -- Also patch ax.Layer and ax.LayerColor metatables
    for _, cls in ipairs({ax.Layer, ax.LayerColor, ax.LayerGradient}) do
        if cls then
            local cmt = getmetatable(cls)
            if cmt and type(cmt.__index) == "function" then
                local clsOldIndex = cmt.__index
                cmt.__index = function(t, k)
                    if _nodeMethods[k] then return _nodeMethods[k] end
                    return clsOldIndex(t, k)
                end
            end
        end
    end

    -- setClipRect ���ݣ�cocos2d-x 2.x Layer �ü�������
    -- Axmol û�� Layer:setClipRect���ü� stub ���ô��벻����
    local function addSetClipRect(cls)
        if cls and not rawget(cls, "setClipRect") then
            function cls:setClipRect(rect)
                self._clipRect = rect
            end
            function cls:getClipRect()
                return self._clipRect
            end
        end
    end
    addSetClipRect(ax.Node)
    addSetClipRect(ax.Layer)

    -- removeAllChildrenWithCleanup 兼容（cocos2d-x 2.x → Axmol）
    if not ax.Node.removeAllChildrenWithCleanup then
        function ax.Node:removeAllChildrenWithCleanup(cleanup)
            self:removeAllChildren()
        end
    end
    -- removeFromParentAndCleanup 兼容（cocos2d-x 2.x → Axmol）
    -- cocos2d-x 2.x: removeFromParentAndCleanup(true) 会移除节点并清理所有事件监听器
    -- Axmol: removeFromParent() 不会自动清理，需要手动 cleanup
    if not ax.Node.removeFromParentAndCleanup then
        function ax.Node:removeFromParentAndCleanup(cleanup)
            if cleanup then
                -- 先从父节点移除（触发 onExit，scene-graph 优先级的监听器会被标记删除）
                self:removeFromParent()
                -- 手动清理残留的触摸监听器
                self:unregisterScriptTouchHandler()
            else
                self:removeFromParent()
            end
        end
    end

    -- registerScriptKeypadHandler ���ݣ�Layer ���ؼ�������
    local _nodeKeypadListeners = setmetatable({}, {__mode = "k"})
    local old_regKeypad = ax.Node.registerScriptKeypadHandler
    if not old_regKeypad then
        function ax.Node:registerScriptKeypadHandler(handler)
            if not handler then return end
            self:unregisterScriptKeypadHandler()

            local listener = ax.EventListenerKeyboard:create()
            listener:registerScriptHandler(function(keyCode, event)
                -- �� cocos2d-x �� "back" ��Ӧ Android ���ؼ�
                if keyCode == ax.KeyCode.KEY_BACK then
                    handler("back")
                elseif keyCode == ax.KeyCode.KEY_MENU then
                    handler("menu")
                end
            end, ax.Handler.EVENT_KEYBOARD_RELEASED)

            ax.Director:getInstance():getEventDispatcher():addEventListenerWithSceneGraphPriority(listener, self)
            _nodeKeypadListeners[self] = listener
        end

        function ax.Node:unregisterScriptKeypadHandler()
            local listener = _nodeKeypadListeners[self]
            if listener then
                ax.Director:getInstance():getEventDispatcher():removeEventListener(listener)
                _nodeKeypadListeners[self] = nil
            end
        end
    end
end

-----------------------------------------------------------------
-- 13b. Node ����������cocos2d-x 2.x �� Axmol��
-- setZOrder �� setLocalZOrder
-- getZOrder �� getLocalZOrder
-----------------------------------------------------------------
if ax.Node then
    if not ax.Node.setZOrder and ax.Node.setLocalZOrder then
        ax.Node.setZOrder = ax.Node.setLocalZOrder
    end
    if not ax.Node.getZOrder and ax.Node.getLocalZOrder then
        ax.Node.getZOrder = ax.Node.getLocalZOrder
    end

    -- addChild compat: cocos2d-x 2.x uses addChild(child, zOrder)
    -- Axmol: addChild(child), addChild(child, zOrder, name), addChild(child, zOrder, tag)
    -- When called with 2 args (child, zOrder), auto-add tag=0
    local _origAddChild = ax.Node.addChild
    if _origAddChild then
        ax.Node.addChild = function(self, child, ...)
            local args = {...}
            if #args == 0 then
                _origAddChild(self, child)
            elseif #args == 1 then
                -- addChild(child, zOrder) -> addChild(child, zOrder, 0)
                _origAddChild(self, child, args[1], 0)
            else
                _origAddChild(self, child, ...)
            end
        end
    end
end


-- 14. registerScriptHandler (Node enter/exit �¼�) ����
-- Axmol ���� ax.Node:registerScriptHandler������Ҫȷ���¼���ӳ��
-- cocos2d-x 2.x: callback(event) where event == "enter"|"exit"
-- Axmol: callback(event) where event == "enter"|"exit" (��ͬ)
-----------------------------------------------------------------
-- Axmol ԭ��֧�֣�����������

-----------------------------------------------------------------
-- 15. Label �������ݣ�setShadow, setStroke �ȣ�
-- Axmol Label:createWithSystemFont �����ı�ǩû�� setShadow/setStroke
-----------------------------------------------------------------
if ax.Label then
    if not ax.Label.setShadow then
        function ax.Label:setShadow(color, offset)
            -- Axmol Label ����Ӱ������Ҫ�� LabelEffect ʵ��
            -- �������� stub �ô��벻����
        end
    end
    if not ax.Label.setStroke then
        function ax.Label:setStroke(color, size)
            -- stub
        end
    end
    if not ax.Label.setText then
        function ax.Label:setText(text)
            if self and self.setString then self:setString(text or "") end
        end
    end
    -- getTextureRect 兼容：Label 没有 getTextureRect，用 getContentSize 模拟
    if not ax.Label.getTextureRect then
        function ax.Label:getTextureRect()
            local s = self:getContentSize()
            return {x=0, y=0, width=s.width, height=s.height, origin={x=0,y=0}, size={width=s.width,height=s.height}}
        end
    end
end
-- Sprite getTextureRect 兼容（Axmol 3.0 可能没有此方法）
if ax.Sprite and not ax.Sprite.getTextureRect then
    function ax.Sprite:getTextureRect()
        local s = self:getContentSize()
        return {x=0, y=0, width=s.width, height=s.height, origin={x=0,y=0}, size={width=s.width,height=s.height}}
    end
end

-- setFlipX/setFlipY 兼容（cocos2d-x 2.x → Axmol 的 setFlippedX/setFlippedY）
if ax.Sprite then
    if not ax.Sprite.setFlipX and ax.Sprite.setFlippedX then
        function ax.Sprite:setFlipX(flip) self:setFlippedX(flip) end
    end
    if not ax.Sprite.setFlipY and ax.Sprite.setFlippedY then
        function ax.Sprite:setFlipY(flip) self:setFlippedY(flip) end
    end
end

-- setMessageRect 等编辑框方法安全 stub（readnode.lua 会对各类 node 调用）
if ax.Node then
    if not ax.Node.setMessageRect then
        function ax.Node:setMessageRect() end
    end
    -- getMessageRect 兼容：cocos2d-x 2.x 节点方法，返回用于触摸检测的矩形
    -- 默认返回零矩形，使 getNodeSize 回退到 getContentSize
    if not ax.Node.getMessageRect then
        function ax.Node:getMessageRect()
            return {origin = {x = 0, y = 0}, size = {width = 0, height = 0}}
        end
    end
end

-----------------------------------------------------------------
-- 16. CCTouch �� API ����
-- �ɴ�������� touch:getLocationInView() / touch:getPreviousLocationInView()
-----------------------------------------------------------------
-- Axmol Touch ������Щ����������������

-----------------------------------------------------------------
-- �ָ�ȫ�ֱ�����
-----------------------------------------------------------------
if _G_mt and _G_old_newindex then
    _G_mt.__newindex = _G_old_newindex
end


-----------------------------------------------------------------
-- numberOfRunningActions patch for all node types
-----------------------------------------------------------------
do
    local function _numberOfRunningActions(self)
        local ok, result = pcall(function()
            local am = ax.Director:getInstance():getActionManager()
            if am then
                return am:getNumberOfRunningActionsInTarget(self)
            end
        end)
        if ok and type(result) == "number" then return result end
        return 0
    end
    
    -- Patch all known node types
    local typesToPatch = {
        ax.Node, ax.Sprite, ax.Layer, ax.LayerColor, ax.LayerGradient,
        ax.Scale9Sprite, ax.Menu, ax.Label, ax.ProgressTimer,
        ax.ClippingNode, ax.DrawNode, ax.ParticleSystemQuad,
    }
    for _, cls in ipairs(typesToPatch) do
        if cls then
            local mt = getmetatable(cls)
            if mt then
                local oi = mt.__index
                if type(oi) == "table" then
                    rawset(oi, "numberOfRunningActions", _numberOfRunningActions)
                elseif type(oi) == "function" then
                    mt.__index = function(t, k)
                        if k == "numberOfRunningActions" then return _numberOfRunningActions end
                        return oi(t, k)
                    end
                end
            end
        end
    end
    print("[compat_cocos2dx] numberOfRunningActions patched")
end

-----------------------------------------------------------------
-- CCDictionary compatibility (cocos2d-x 2.x -> Lua table wrapper)
-----------------------------------------------------------------
CCDictionary = {}
CCDictionary.__index = CCDictionary
function CCDictionary:create()
    local obj = { _data = {} }
    setmetatable(obj, self)
    return obj
end
function CCDictionary:setObject(obj, key)
    self._data[key] = obj
end
function CCDictionary:objectForKey(key)
    return self._data[key]
end
function CCDictionary:count()
    local c = 0
    for _ in pairs(self._data) do c = c + 1 end
    return c
end
function CCDictionary:removeObjectForKey(key)
    self._data[key] = nil
end
function CCDictionary:allKeys()
    local keys = {}
    for k in pairs(self._data) do table.insert(keys, k) end
    return keys
end
function CCDictionary:getDict()
    return self._data
end
print("[compat_cocos2dx] CCDictionary compatibility added")

print("[compat_cocos2dx] Compatibility layer loaded successfully")
