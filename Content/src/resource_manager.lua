local size = (CCEGLView and CCEGLView:sharedOpenGLView():getFrameSize()) or {width = 800, height = 480}

local antiAlias = (size.width ~= 800 and size.height ~= 480) or (size.width ~= 480 and size.height ~= 800)
local ed = ed
ed.cha_scale = 0.09
ed.cha_ui_scale = 0.39
if LegendSetAniScaleFactor then
	LegendSetAniScaleFactor(ed.cha_scale)
end
local function getSpriteFrame(resource, isUI)
	if not resource then
		return nil
	end
	local frame = CCSpriteFrameCache:sharedSpriteFrameCache():spriteFrameByName(resource)
	if not frame then
		local format
		local config = ed.lookupDataTable("TextureConfig", resource)
		local doCache = true
		if config then
			format = config.PixelFormat
			format = format and _G[format]
			doCache = not config.NoCache
		end
		local texture
		if format then
			texture = CCTextureCache:sharedTextureCache():addImage(resource, format)
		else
			texture = CCTextureCache:sharedTextureCache():addImage(resource)
		end
		if not texture then
			return nil
		end
		local rect = CCRect(0, 0, texture:getContentSize().width, texture:getContentSize().height)
		frame = CCSpriteFrame:createWithTexture(texture, rect)
		if doCache then
			CCSpriteFrameCache:sharedSpriteFrameCache():addSpriteFrame(frame, resource)
		else
			CCTextureCache:sharedTextureCache():removeTextureForKey(resource)
		end
	end
	return frame
end
ed.getSpriteFrame = getSpriteFrame
local function getSpriteOriginalScale(resource)
	local config = ed.lookupDataTable("TextureConfig", resource)
	if not config then
		return 1
	end
	if EDFLAGWIN32 and not config.Prescaled then
		return 1
	end
	if config.ContentScale == 0 then
		return 1
	end
	return config.ContentScale
end
ed.getSpriteOriginalScale = getSpriteOriginalScale
local function createSprite(resource)
	local frame = ed.getSpriteFrame(resource)
	if frame then
		local spr = CCSprite:createWithSpriteFrame(frame)
		local scale = getSpriteOriginalScale(resource)
		spr:setScale(scale)
		return spr
	else
		-- sprite frame not found, try loading from file directly
		local spr = CCSprite:create(resource)
		if spr then
			local scale = getSpriteOriginalScale(resource)
			spr:setScale(scale)
			return spr
		end
		LegendLog("Failed to creating sprite from " .. (resource or "nil"))
		return CCSprite:create()
	end
end
ed.createSprite = createSprite
local function initSpriteWithFrame(sprite, resource)
	local frame = ed.getSpriteFrame(resource)
	if frame then
		sprite:initWithSpriteFrame(frame)
	end
end
ed.initSpriteWithFrame = initSpriteWithFrame
local function createScale9Sprite(res, capInsets)
	local frame = ed.getSpriteFrame(res)
	if not frame then return nil end
	if not capInsets then
		local sw, sh = 0, 0
		local ok, rect = pcall(function() return frame:getRect() end)
		if ok and rect then
			if type(rect) == "table" then
				sw = rect.width or (rect.size and rect.size.width) or 0
				sh = rect.height or (rect.size and rect.size.height) or 0
			end
		end
		if sw == 0 or sh == 0 then
			local ok2, sz = pcall(function() return frame:getOriginalSize() end)
			if ok2 and sz then sw = sz.width or 0; sh = sz.height or 0 end
		end
		capInsets = CCRectMake(sw / 3, sh / 3, sw / 3, sh / 3)
	end
	local sprite = CCScale9Sprite:createWithSpriteFrame(frame, capInsets)
	return sprite
end
ed.createScale9Sprite = createScale9Sprite
local function createMultiSprite(resource)
	local frame = ed.getSpriteFrame(resource)
	if frame then
		return CCMultiSprite:createWithSpriteFrame(frame)
	else
		LegendLog("[resource_manager.lua|createMultiSprite] Failed to creating sprite from " .. (resource or "nil"))
		return CCMultiSprite:create()
	end
end
ed.createMultiSprite = createMultiSprite
local function addStubMethods(node)
	node.setAction = function() end
	node.setNextAction = function() end
	node.setLoop = function() end
	node.runAnimation = function() end
	node.useShader = function() end
	node.useDefaultShader = function() end
	node.setComponent = function() end
	node.registerLuaListener = function() end
	node.unregisterLuaListener = function() end
	node.stopAllAnimations = function() end
	node.addEffect = function() return -1 end
	node.removeEffectWithID = function() end
	node.removeEffectWithName = function() end
	node.tint = function() end
	node.setActionElapsed = function() end
	node.setActionSpeeder = function() end
	node.setStartAction = function() end
	node.setLoopAction = function() end
	node.getAniFileName = function() return "" end
	node.isTerminated = function() return true end
	local breatheScale = CCScaleBy:create(1.2, 0.95)
	local breatheBack = breatheScale:reverse()
	local breatheSeq = CCSequence:createWithTwoActions(breatheScale, breatheBack)
	local breatheForever = CCRepeatForever:create(breatheSeq)
	breatheForever:setTag(9999)
	node:runAction(breatheForever)
	return node
end

local function parseAtlasRegions(atlasContent)
	local regions = {}
	local current = nil
	local lineSep = string.char(13) .. string.char(10)
	local function saveCurrent()
		if current and current.name and current.x and current.y and current.width and current.height then
			table.insert(regions, current)
		end
		current = nil
	end
	for line in atlasContent:gmatch('[^' .. lineSep .. ']+') do
		local l = line:match('^%s*(.-)%s*$')
		if l == '' then
		elseif l:match('^%s*rotate:') then
			if current then current.rotate = (l:match('rotate:%s*(%S+)') == 'true') end
		elseif l:match('^%s*xy:') then
			if current then
				local x, y = l:match('xy:%s*(%d+)%s*,%s*(%d+)')
				current.x, current.y = tonumber(x), tonumber(y)
			end
		elseif l:match('^%s*size:') then
			if current then
				local w, h = l:match('size:%s*(%d+)%s*,%s*(%d+)')
				current.width, current.height = tonumber(w), tonumber(h)
			end
		elseif l:match('^%s*orig:') then
		elseif l:match('^%s*offset:') then
		elseif l:match('^%s*index:') then
			saveCurrent()
		elseif l:match('^%s*format:') or l:match('^%s*filter:') or l:match('^%s*repeat:') then
		else
			saveCurrent()
			current = { name = l }
		end
	end
	saveCurrent()
	return regions
end


local spineDataCache = {}

local function parseSpineJson(resource)
	local jsonPath = 'spine/' .. resource .. '/' .. resource .. '.json'
	local fu = CCFileUtils:sharedFileUtils()
	if not fu:isFileExist(jsonPath) then
		return nil
	end
	local jsonContent = fu:getStringFromFile(jsonPath)
	if not jsonContent or jsonContent == "" then
		return nil
	end
	local ok, data = pcall(json.decode, jsonContent)
	if not ok or not data then
		LegendLog("[spine-composite] json.decode failed for: " .. resource)
		return nil
	end
	local bones = {}
	if data.bones then
		for _, b in ipairs(data.bones) do
			bones[b.name] = {
				x = b.x or 0,
				y = b.y or 0,
				rotation = b.rotation or 0,
				scaleX = b.scaleX or 1,
				scaleY = b.scaleY or 1,
				parent = b.parent
			}
		end
	end
	local slots = {}
	if data.slots then
		for _, s in ipairs(data.slots) do
			local colorStr = s.color
			local entry = {
				name = s.name,
				bone = s.bone,
				order = s.order or 0,
				color = colorStr
			}
			if s.attachment then
				entry.attachment = s.attachment
			end
			table.insert(slots, entry)
		end
	end
	local skins = {}
	if data.skins then
		for skinName, skinData in pairs(data.skins) do
			skins[skinName] = skinData
		end
	end
	local colorAnimations = {}
	if data.animations and data.animations.Loop and data.animations.Loop.slots then
		for slotName, timelines in pairs(data.animations.Loop.slots) do
			if timelines.color then
				local keyframes = {}
				for _, kf in ipairs(timelines.color) do
					table.insert(keyframes, {
						time = kf.time or 0,
						color = kf.color
					})
				end
				table.sort(keyframes, function(a, b) return a.time < b.time end)
				colorAnimations[slotName] = keyframes
			end
		end
	end
	return {
		bones = bones,
		slots = slots,
		skins = skins,
		colorAnimations = colorAnimations,
		animations = data.animations or {}
	}
end

local function getOrParseSpineData(resource)
	if spineDataCache[resource] then
		return spineDataCache[resource]
	end
	local data = parseSpineJson(resource)
	if data then
		spineDataCache[resource] = data
	end
	return data
end
ed.getOrParseSpineData = getOrParseSpineData
ed.parseAtlasRegions = parseAtlasRegions

local function computeSlotWorldTransform(slotData, bones)
	local boneName = slotData.bone
	local chain = {}
	local cur = bones[boneName]
	while cur do
		table.insert(chain, 1, cur)
		cur = cur.parent and bones[cur.parent]
	end
	local transform = {a = 1, b = 0, c = 0, d = 1, tx = 0, ty = 0}
	for _, bone in ipairs(chain) do
		local bx, by = bone.x or 0, bone.y or 0
		local rot = bone.rotation or 0
		local sx, sy = bone.scaleX or 1, bone.scaleY or 1
		local rad = math.rad(rot)
		local cosR, sinR = math.cos(rad), math.sin(rad)
		local la = cosR * sx
		local lb = sinR * sx
		local lc = -sinR * sy
		local ld = cosR * sy
		local pa, pb, pc, pd, ptx, pty =
			transform.a, transform.b, transform.c, transform.d,
			transform.tx, transform.ty
		transform.a  = pa * la + pc * lb
		transform.b  = pb * la + pd * lb
		transform.c  = pa * lc + pc * ld
		transform.d  = pb * lc + pd * ld
		transform.tx = pa * bx + pc * by + ptx
		transform.ty = pb * bx + pd * by + pty
	end
	return transform
end

local function applySlotColor(sprite, colorStr)
	if not colorStr or #colorStr ~= 8 then return end
	local r = tonumber(colorStr:sub(1, 2), 16)
	local g = tonumber(colorStr:sub(3, 4), 16)
	local b = tonumber(colorStr:sub(5, 6), 16)
	local a = tonumber(colorStr:sub(7, 8), 16)
	if r and g and b then
		sprite:setColor(ccc3(r, g, b))
	end
	if a then
		sprite:setOpacity(a)
	end
end

local function createColorAnimation(colorTimeline)
	if not colorTimeline or #colorTimeline < 2 then return nil end
	local actions = {}
	for i = 1, #colorTimeline - 1 do
		local cur = colorTimeline[i]
		local nxt = colorTimeline[i + 1]
		local dt = nxt.time - cur.time
		if dt > 0 then
			local curR = tonumber(cur.color:sub(1, 2), 16)
			local curG = tonumber(cur.color:sub(3, 4), 16)
			local curB = tonumber(cur.color:sub(5, 6), 16)
			local curA = tonumber(cur.color:sub(7, 8), 16)
			local nxtR = tonumber(nxt.color:sub(1, 2), 16)
			local nxtG = tonumber(nxt.color:sub(3, 4), 16)
			local nxtB = tonumber(nxt.color:sub(5, 6), 16)
			local nxtA = tonumber(nxt.color:sub(7, 8), 16)
			local hasRGB = (curR ~= nxtR or curG ~= nxtG or curB ~= nxtB)
			local hasAlpha = (curA ~= nxtA)
			local action
			if hasRGB and hasAlpha then
				action = CCSpawn:createWithTwoActions(
					CCTintTo:create(dt, nxtR, nxtG, nxtB),
					CCFadeTo:create(dt, nxtA)
				)
			elseif hasRGB then
				action = CCTintTo:create(dt, nxtR, nxtG, nxtB)
			elseif hasAlpha then
				action = CCFadeTo:create(dt, nxtA)
			end
			if action then
				table.insert(actions, action)
			end
		end
	end
	if #actions == 0 then return nil end
	if #actions == 1 then return CCRepeatForever:create(actions[1]) end
	local seq = CCSequence:create(actions)
	return CCRepeatForever:create(seq)
end

local function createCompositeFromSpineData(resource)
	local spineData = getOrParseSpineData(resource)
	if not spineData then return nil end

	local atlasPath = 'spine/' .. resource .. '/' .. resource .. '.atlas'
	local pngPath = 'spine/' .. resource .. '/' .. resource .. '.png'
	local fu = CCFileUtils:sharedFileUtils()
	local atlasContent = fu:getStringFromFile(atlasPath)
	if not atlasContent or atlasContent == "" then return nil end

	local regionList = parseAtlasRegions(atlasContent)
	if #regionList == 0 then return nil end
	local regionMap = {}
	for _, r in ipairs(regionList) do
		regionMap[r.name] = r
	end

	local texture = CCTextureCache:sharedTextureCache():addImage(pngPath)
	if not texture then return nil end

	local skinData = nil
	for _, sd in pairs(spineData.skins) do
		skinData = sd
		break
	end
	if not skinData then return nil end

	local rootScaleX, rootScaleY = 1, 1
	for _, bone in pairs(spineData.bones) do
		if not bone.parent then
			rootScaleX = bone.scaleX or 1
			rootScaleY = bone.scaleY or 1
			break
		end
	end

	local container = CCNode:create()
	container:setAnchorPoint(ccp(0.5, 0.5))
	container:setCascadeOpacityEnabled(true)

	local spriteInfos = {}
	for _, slotData in ipairs(spineData.slots) do
		local attachmentName = slotData.attachment
		if not attachmentName then
			local slotSkinData = skinData[slotData.name]
			if slotSkinData then
				for attName, _ in pairs(slotSkinData) do
					attachmentName = attName
					break
				end
			end
		end

		if attachmentName then
			local region = regionMap[attachmentName]
			if not region then
				local slotSkinData = skinData[slotData.name]
				if slotSkinData and slotSkinData[attachmentName] then
					local skinEntry = slotSkinData[attachmentName]
					if skinEntry.name then
						region = regionMap[skinEntry.name]
					end
				end
			end

			if region then
				local rect = CCRectMake(region.x, region.y, region.width, region.height)
				local frame = CCSpriteFrame:createWithTexture(texture, rect)
				if not frame then goto continue end
				local sprite = CCSprite:createWithSpriteFrame(frame)
				if not sprite then goto continue end

				local transform = computeSlotWorldTransform(slotData, spineData.bones)
				local attach = nil
				local slotSkinData = skinData[slotData.name]
				if slotSkinData then
					attach = slotSkinData[attachmentName]
				end

				local ax, ay = 0, 0
				local aRot = 0
				local aScaleX, aScaleY = 1, 1
				if attach then
					ax = attach.x or 0
					ay = attach.y or 0
					aRot = attach.rotation or 0
					aScaleX = attach.scaleX or 1
					aScaleY = attach.scaleY or 1
				end

				local wx = transform.a * ax + transform.c * ay + transform.tx
				local wy = transform.b * ax + transform.d * ay + transform.ty
				local wrot = math.deg(math.atan2(transform.b, transform.a)) + aRot
				local boneScaleX = math.sqrt(transform.a * transform.a + transform.b * transform.b)
				local boneScaleY = math.sqrt(transform.c * transform.c + transform.d * transform.d)

				applySlotColor(sprite, slotData.color)
				local colorAnim = createColorAnimation(spineData.colorAnimations[slotData.name])

				spriteInfos[#spriteInfos + 1] = {
					sprite = sprite,
					wx = wx,
					wy = wy,
					wrot = wrot,
					scaleX = boneScaleX * aScaleX,
					scaleY = boneScaleY * aScaleY,
					regionW = region.width,
					regionH = region.height,
					regionRotate = region.rotate,
					colorAnim = colorAnim
				}
			end
		end
		::continue::
	end

	if #spriteInfos == 0 then
		return nil
	end

	local mainIdx = 1
	local mainArea = 0
	for i, info in ipairs(spriteInfos) do
		local area = info.regionW * info.regionH
		if area > mainArea then
			mainArea = area
			mainIdx = i
		end
	end

	local main = spriteInfos[mainIdx]
	if main.regionRotate then
		main.sprite:setRotation(90)
	end
	container:addChild(main.sprite)

	local extraCount = 0
	local mainAreaThreshold = mainArea * 0.3
	for i, info in ipairs(spriteInfos) do
		if i ~= mainIdx then
			local extraArea = info.regionW * info.regionH
			if extraArea > mainAreaThreshold then
				-- skip large decorations that look bad as static
			else
				local dx = (info.wx - main.wx) / rootScaleX
				local dy = (info.wy - main.wy) / rootScaleY
				local sx = info.scaleX / rootScaleX
				local sy = info.scaleY / rootScaleY

				info.sprite:setPosition(ccp(dx, -dy))
				info.sprite:setRotation(-info.wrot)
				info.sprite:setScale(sx, sy)
				container:addChild(info.sprite)
				extraCount = extraCount + 1

				if info.colorAnim then
					info.sprite:runAction(info.colorAnim)
				end
			end
		end
	end

	container:setContentSize(CCSizeMake(main.regionW, main.regionH))

	LegendLog("[spine-composite] " .. resource .. ": " .. #spriteInfos .. " total, " .. (extraCount + 1) .. " shown, main=" .. main.regionW .. "x" .. main.regionH)
	addStubMethods(container)
	return container
end

local function createStaticSpriteFromSpineAtlas(resource)
	local atlasPath = 'spine/' .. resource .. '/' .. resource .. '.atlas'
	local pngPath = 'spine/' .. resource .. '/' .. resource .. '.png'
	local fu = CCFileUtils:sharedFileUtils()
	if not fu:isFileExist(atlasPath) or not fu:isFileExist(pngPath) then
		return nil
	end
	local atlasContent = fu:getStringFromFile(atlasPath)
	if not atlasContent or atlasContent == "" then
		return nil
	end

	local regions = parseAtlasRegions(atlasContent)
	if #regions == 0 then
		return nil
	end
	local texture = CCTextureCache:sharedTextureCache():addImage(pngPath)
	if not texture then return nil end

	local bestRegion = nil
	local bestArea = 0
	for _, r in ipairs(regions) do
		local w = r.rotate and r.height or r.width
		local h = r.rotate and r.width or r.height
		local area = w * h
		if area > bestArea then
			bestArea = area
			bestRegion = r
		end
	end

	if not bestRegion then return nil end
	-- 与 spineplayer.lua 同口径:atlas xy 左下原点、rect 逻辑点(×factor)、rotate +90 逆时针转正
	local pxH = texture:getContentSize().height
	local factor = 1
	pcall(function()
		pxH = texture:getPixelsHigh()
		factor = texture:getContentSize().width / texture:getPixelsWide()
	end)
	local rw = bestRegion.rotate and bestRegion.height or bestRegion.width
	local rh = bestRegion.rotate and bestRegion.width or bestRegion.height
	local rect = CCRectMake(bestRegion.x * factor, (pxH - bestRegion.y - rh) * factor, rw * factor, rh * factor)
	local frame = CCSpriteFrame:createWithTexture(texture, rect)
	if not frame then return nil end
	local sprite = CCSprite:createWithSpriteFrame(frame)
	if not sprite then return nil end
	if bestRegion.rotate then
		sprite:setRotation(90)
	end
	addStubMethods(sprite)
	return sprite
end
ed.createStaticSpriteFromSpineAtlas = createStaticSpriteFromSpineAtlas
local function createFcaNode(resource, aniType)
	local isUI = string.match(resource, '^eff_UI')
	if isUI then
		LegendSetAniScaleFactor(ed.cha_ui_scale)
	else
		LegendSetAniScaleFactor(ed.cha_scale)
	end
	local node = nil;
	if aniType and aniType == Type_Spine then
		node = ed.createAnimation(resource, 1.0, aniType);
		if node then
			node:setAction('Start');
			node:setNextAction('Loop');
			node:setLoop(true);
		end
	else
		if LegendAminationEffect then
			node = LegendAminationEffect:create(resource)
		end
	end
	LegendSetAniScaleFactor(ed.cha_scale)
	if not node then
		-- SpineContainer 拒载 spine 2.x / FCA 资源缺失时:优先纯 Lua Spine 播放器(全散件 + 动画),
		-- 再落单张最大散件静态图(spineplayer.lua,借鉴 CardGame2 spine_skeleton.gd)
		if ed.createSpinePlayer then
			node = ed.createSpinePlayer(resource)
			if node then
				node:setAction('Start')
				node:setNextAction('Loop')
				node:setLoop(true)
			end
		end
	end
	if not node then
		node = createStaticSpriteFromSpineAtlas(resource)
	end
	if not node then
		LegendLog('[resource_manager] createFcaNode failed: ' .. tostring(resource))
		node = CCNode:create()
		node.setAction = function() end
		node.setNextAction = function() end
		node.setLoop = function() end
		node.runAnimation = function() end
		node.useShader = function() end
		node.useDefaultShader = function() end
		node.setComponent = function() end
		node.registerLuaListener = function() end
		node.unregisterLuaListener = function() end
		node.stopAllAnimations = function() end
		node.addEffect = function() return -1 end
		node.removeEffectWithID = function() end
		node.removeEffectWithName = function() end
		node.tint = function() end
		node.setActionElapsed = function() end
		node.setActionSpeeder = function() end
		node.setStartAction = function() end
		node.setLoopAction = function() end
		node.getAniFileName = function() return "" end
		node.isTerminated = function() return true end
	end
	return node
end
ed.createFcaNode = createFcaNode
local function createFcaActor(resource)
	local isUI = string.match(resource, "^eff_UI")
	if isUI then
		resource = "effect/" .. resource
		LegendSetAniScaleFactor(ed.cha_ui_scale)
	else
		LegendSetAniScaleFactor(ed.cha_scale)
	end
	local node = LegendAnimation:create(resource, 1)
	LegendSetAniScaleFactor(ed.cha_scale)
	return node
end
ed.createFcaActor = createFcaActor
local function createClippingNodeOnly(stencil, alphaThreshold)
	if nil == stencil then
		return
	end
	alphaThreshold = alphaThreshold or 0.5
	local cn = CCClippingNode:create()
	local stencil = ed.createSprite(stencil)
	cn:setStencil(stencil)
	cn:setAlphaThreshold(alphaThreshold)
	cn:setCascadeOpacityEnabled(true)
	return cn
end
ed.createClippingNodeOnly = createClippingNodeOnly
local function createClippingNode(res, stencil, alphaThreshold, setSize)
	local ClippingNode = createClippingNodeOnly(stencil, alphaThreshold)
	if nil == ClippingNode then
		return
	end
	local sprite = ed.createSprite(res)
	sprite:setAnchorPoint(ccp(0.5, 0.5))
	local size = sprite:getContentSize()
	local ow, oh = 0, 0
	if setSize then
		ow = setSize.width
		oh = setSize.height
	end
	local stencil = ClippingNode:getStencil()
	local ss = stencil:getContentSize()
	stencil:setScaleX((size.width + ow) / ss.width)
	stencil:setScaleY((size.height + oh) / ss.height)
	ClippingNode:addChild(sprite)
	return ClippingNode, sprite
end
ed.createClippingNode = createClippingNode
local function createLabelTTF(text, size, font, skipFormat)
	if not skipFormat then
		text = ed.formatText(text)
	end
	text = text or ""
	assert(text, "the text of the label must not be nil. @ resource_manager")
	local label
	if not font then
		label = CCLabelTTF:create(text, ed.font, size)
	else
		label = CCLabelTTF:create(text, font, size)
	end
	return label
end
ed.createLabelTTF = createLabelTTF
local function setLabelFontInfo(label, info)
	if nil == label then
		return
	end
	if nil == info then
		return
	end
	local fontInfo = EDTables.fontconfigs[info]
	if fontInfo == nil then
		print("fontInfo:" .. info .. "no found!!")
		return
	end
	if fontInfo.color then
		label:setColor(fontInfo.color)
	end
	if fontInfo.strokeColor then
		ed.setLabelStroke(label, fontInfo.strokeColor, fontInfo.strokeSize)
	end
	if fontInfo.shadowColor then
		ed.setLabelShadow(label, fontInfo.shadowColor, fontInfo.shadowOffset)
	end
end
ed.setLabelFontInfo = setLabelFontInfo
local function createLabelWithFontInfo(text, info, size)
	if nil == info then
		return
	end
	local fontInfo = EDTables.fontconfigs[info]
	if fontInfo == nil then
		print("fontInfo:" .. info .. "no found!!")
		return
	end
	font = ed.font
	if fontInfo.font then
		font = fontInfo.font
	end
	
	if not size then
		size = fontInfo.size
	end
	
	local label = ed.createLabelTTF("", size,font)
	setLabelFontInfo(label, info)
	ed.setLabelString(label, text)
	return label
end
ed.createLabelWithFontInfo = createLabelWithFontInfo
local function setLabelString(label, text, skipFormat)
	if tolua.isnull(label) then
		return
	end
	if not text then
		return
	end
	if not skipFormat then
		text = ed.formatText(text)
	end
	label:setString(text)
end
ed.setLabelString = setLabelString
local function createttf(text, size, font)
	return ed.createLabelTTF(text, size, font, true)
end
ed.createttf = createttf
local function setString(label, text)
	if not label then
		return
	end
	if not text then
		return
	end
	if not label.setString then
		return
	end
	if type(label) == "userdata" then
		ed.setLabelString(label, text, true)
	elseif type(label) == "table" then
		label:setString(text)
	end
end
ed.setString = setString
local setLabelShadow = function(label, color, offset)
	if tolua.isnull(label) then
		return
	end
	if label.setShadow then label:setShadow(color, offset) end
end
ed.setLabelShadow = setLabelShadow
local setLabelStroke = function(label, color, size)
	if tolua.isnull(label) then
		return
	end
	if label.setStroke then label:setStroke(color, size) end
end
ed.setLabelStroke = setLabelStroke
local setLabelColor = function(label, color)
	if tolua.isnull(label) then
		return
	end
	label:setColor(color)
end
ed.setLabelColor = setLabelColor
local setLabelDimensions = function(label, dimensions)
	if tolua.isnull(label) then
		return
	end
	if type(dimensions) == "table" then
		label:setDimensions(dimensions.width or 0, dimensions.height or 0)
	else
		label:setDimensions(dimensions or 0, 0)
	end
end
ed.setLabelDimensions = setLabelDimensions
local function createFrameAnim(list, delay)
	delay = delay or 0.041666666666666664
	local spr
	local array = CCArray:createWithCapacity(#list)
	for i, v in ipairs(list) do
		spr = spr or createSprite(v)
		local frame = ed.getSpriteFrame(v)
		array:addObject(frame)
	end
	local animation = CCAnimation:createWithSpriteFrames(array, delay)
	local anim = CCAnimate:create(animation)
	return spr, anim
end
ed.createFrameAnim = createFrameAnim
local loadSpriteSheet = function(xml_file)
	local xfile = xml.load(xml_file)
	local xaltas = xfile:find("TextureAtlas")
	local texture = CCTextureCache:sharedTextureCache():addImage(xaltas.imagePath)
	for i = 1, #xaltas do
		local xsprite = xaltas[i]
		local rect = CCRectMake(xsprite.x, xsprite.y, xsprite.w, xsprite.h)
		xsprite.oX = xsprite.oX or 0
		xsprite.oY = xsprite.oY or 0
		local offset = ccp(xsprite.oX, xsprite.oY)
		xsprite.oW = xsprite.oW or xsprite.w
		xsprite.oH = xsprite.oH or xsprite.h
		local originSize = CCSize(xsprite.oW, xsprite.oH)
		local rotated = xsprite.r == "y"
		local frame = CCSpriteFrame:createWithTexture(texture, rect, rotated, offset, originSize)
		CCSpriteFrameCache:sharedSpriteFrameCache():addSpriteFrame(frame, xsprite.n)
	end
end
function createAnimateWithFrameNames(name_list, delay)
	if not name_list then
		return nil
	end
	delay = delay or 0.08333333333333333
	local array = CCArray:create()
	for i = 1, #name_list do
		local frame = ed.getSpriteFrame(name_list[i])
		array:addObject(frame)
	end
	local animation = CCAnimation:createWithSpriteFrames(array, delay)
	return CCAnimate:create(animation)
end
ed.createAnimateWithFrameNames = createAnimateWithFrameNames
local setSpriteGray = function(sprite)
	if not sprite then return end
	-- GrayScalingShader 在 Axmol 中不可用，改用颜色着色 + 降低不透明度实现灰化效果
	pcall(function() sprite:setCascadeColorEnabled(true) end)
	pcall(function() sprite:setColor(ccc3(100, 100, 100)) end)
	pcall(function() sprite:setOpacity(180) end)
end
ed.setSpriteGray = setSpriteGray
local resetSpriteShader = function(sprite)
	if not sprite then return end
	pcall(function() sprite:setColor(ccc3(255, 255, 255)) end)
	pcall(function() sprite:setOpacity(255) end)
end
ed.resetSpriteShader = resetSpriteShader
local setSpriteBlur = function(sprite, radius)
	if not CCShaderCache then
		return
	end
	local shader = CCShaderCache:sharedShaderCache():programForKey("Blur")
	if not shader then
		return
	end
	sprite:setShaderProgram(shader)
	sprite:getShaderProgram():use()
	local size = sprite:getTexture():getContentSizeInPixels()
	local width = size.width
	local height = size.height
	local location = sprite:getShaderProgram():getUniformLocationForName("blurSize")
	sprite:getShaderProgram():setUniformsForBuiltins()
	sprite:getShaderProgram():setUniformLocationWith2f(location, 1 / width * radius, 1 / height * radius)
end
ed.setSpriteBlur = setSpriteBlur
local createSpriteBlur = function(sprite, radius)
	local shader = CCGLProgram:createWithFileName("shader/Blur.vsh", "shader/Blur.fsh")
	sprite:setShaderProgram(shader)
	sprite:getShaderProgram():use()
	local size = sprite:getTexture():getContentSizeInPixels()
	local width = size.width
	local height = size.height
	local location = sprite:getShaderProgram():getUniformLocationForName("blurSize")
	sprite:getShaderProgram():setUniformsForBuiltins()
	sprite:getShaderProgram():setUniformLocationWith2f(location, 1 / width * radius, 1 / height * radius)
end
ed.setSpriteBlur = setSpriteBlur
local function horizontalArrange(nodes, param)
	param = param or {}
	local mode = param.type or "center"
	local fix_height = param.fix_height
	local fix_width = param.fix_width
	local fix_size
	if fix_height or fix_width then
		fix_size = CCSizeMake(fix_width or 0, fix_height or 0)
	end
	local n1
	if type(nodes[1]) == "table" then
		n1 = nodes[1].node
	else
		n1 = nodes[1]
	end
	local height = param.height or n1:getContentSize().height * math.min(n1:getScale(), n1:getScaleY())
	local ns = {}
	local container = CCSprite:create()
	container:setCascadeOpacityEnabled(true)
	local addWidth = 0
	for i = 1, #(nodes or {}) do
		local node = nodes[i]
		local offset = 0
		if type(node) == "table" then
			offset = node.offset
			node = node.node
		end
		node:setAnchorPoint(ccp(0, 0.5))
		ed.fixNodeSize(node, fix_size)
		if i == 1 then
			node:setPosition(ccp(0, height / 2))
		else
			local pn
			if type(nodes[i - 1]) == "table" then
				pn = nodes[i - 1].node
			else
				pn = nodes[i - 1]
			end
			ed.right2(node, pn, offset)
			addWidth = addWidth + (offset or 0)
		end
		table.insert(ns, node)
		container:addChild(node)
	end
	local width = ed.sumNodeSize(ns) + addWidth
	container:setContentSize(CCSizeMake(width, height))
	return container
end
ed.horizontalArrange = horizontalArrange
local function verticalArrange(nodes, param)
	param = param or {}
	local mode = param.type or "center"
	local fix_height = param.fix_height
	local fix_width = param.fix_width
	local fix_size
	if fix_height or fix_width then
		fix_size = CCSizeMake(fix_width or 0, fix_height or 0)
	end
	local n1
	if type(nodes[1]) == "table" then
		n1 = nodes[1].node
	else
		n1 = nodes[1]
	end
	local ns = {}
	local container = CCSprite:create()
	container:setCascadeOpacityEnabled(true)
	local addHeight = 0
	local maxWidth = 0
	for i = 1, #(nodes or {}) do
		local node = nodes[i]
		local offset = 0
		if type(node) == "table" then
			offset = node.offset
			node = node.node
		end
		node:setAnchorPoint(ccp(0, 1))
		ed.fixNodeSize(node, fix_size)
		local nodeSize = node:getContentSize()
		local w = nodeSize.width
		maxWidth = math.max(w, maxWidth)
		if i == 1 then
			node:setPosition(ccp(0, 0))
		else
			local pn
			if type(nodes[i - 1]) == "table" then
				pn = nodes[i - 1].node
			else
				pn = nodes[i - 1]
			end
			ed.below2(node, pn, offset)
			addHeight = addHeight + (offset or 0)
		end
		table.insert(ns, node)
		container:addChild(node)
	end
	local tw, height = ed.sumNodeSize(ns)
	height = height + addHeight
	local vNode = CCSprite:create()
	vNode:setContentSize(CCSizeMake(maxWidth, height))
	container:setAnchorPoint(ccp(0, 0))
	container:setPosition(ccp(0, height))
	vNode:addChild(container)
	vNode:setCascadeOpacityEnabled(true)
	return vNode
end
ed.verticalArrange = verticalArrange
local function getHeadIcon(param)
	param = param or {}
	local id = param.id
	local res
	if id then
		local row = ed.getDataTable("Avatar")[id]
		if not row then
			return
		end
		res = row.Picture
	else
		res = param.res or ed.player:getHeadIconRes()
	end
	local length = param.length or 70
	local head, headicon = ed.createClippingNode(res, "UI/alpha/HVGA/main_head_mask.png", nil, CCSizeMake(-10, -10))
	local size = headicon:getContentSize()
	local len = size.width
	head:setScale(length / size.width)
	return head, headicon
end
ed.getHeadIcon = getHeadIcon
local function getTeamHead(param)
	param = param or {}
	local state = param.type
	local vip = param.vip
	local length = param.length
	param.length = nil
	local head, headicon = ed.getHeadIcon(param)
	if tolua.isnull(headicon) then
		return
	end
	local container = CCSprite:create()
	local size = headicon:getContentSize()
	container:setContentSize(size)
	local center = ed.getCenterPos(container)
	local frameres = vip and "UI/alpha/HVGA/main_head_frame_gold.png" or "UI/alpha/HVGA/main_head_frame_silver.png"
	frameres = --[[not state or state == "vip" and --]]"UI/alpha/HVGA/main_head_frame_gold.png" or "UI/alpha/HVGA/main_head_frame_silver.png"
	local frame = ed.createSprite(frameres)
	head:setPosition(ccp(center.x-3,center.y+2))
	container:addChild(head)
	frame:setPosition(ccpAdd(center, ccp(13, -1)))
	container:addChild(frame)
	if length then
		container:setScale(length / size.width)
	end
	return container
end
ed.getTeamHead = getTeamHead
local function getLevelIcon(param)
	param = param or {}
	if not param.level then
		return
	end
	local level = param.level or 1
	local state = param.type or "common"
	local vip = param.vip
	local frameres = "UI/alpha/HVGA/pvp/main_head_level_bg_silver.png"
	if vip then
		frameres = "UI/alpha/HVGA/pvp/main_head_level_bg_gold.png"
	end
	local frame = ed.createSprite(frameres)
	local size = frame:getContentSize()
	local container = CCSprite:create()
	container:setContentSize(size)
	local center = ed.getCenterPos(container)
	frame:setPosition(center)
	container:addChild(frame)
	local levelLabel = ed.createLabelTTF(level, 20)
	center.y = center.y + 1
	levelLabel:setPosition(center)
	container:addChild(levelLabel)
	ed.setLabelColor(levelLabel, ccc3(255, 255, 228))
	return container, levelLabel
end
ed.getLevelIcon = getLevelIcon
local function getHeroIconByID(param)
	param = param or {}
	local hid = param.hid
	local id = param.id or 1
	local vip = param.vip
	local length = param.length
	local head = CCSprite:create()
	head:setContentSize(CCSizeMake(80, 80))
	local res
	if hid then
		local ut = ed.getDataTable("Unit")
		local row = ut[hid]
		if not row then
			return
		end
		res = row.Portrait
	else
		local at = ed.getDataTable("Avatar")
		local row = at[id]
		if not row then
			return
		end
		res = row.Picture
	end
	local param = {res = res, length = length}
	local icon = ed.getHeadIcon(param)
	icon:setPosition(ccp(40, 40))
	head:addChild(icon)
	local fres = "UI/alpha/HVGA/main_head_frame_silver.png"
	if vip then
		fres = "UI/alpha/HVGA/main_head_frame_gold.png"
	end
	local frame = ed.createSprite(fres)
	frame:setPosition(ccp(55, 38))
	head:addChild(frame)
	return head, frame
end
ed.getHeroIconByID = getHeroIconByID
local getPosition = function(icon)
	return icon:getPosition()
end
local getContentSize = function(icon)
	return icon:getContentSize()
end
local function getWholeHeadIcon(param)
	local node = CCNode:create()
	local headIcon = getHeroIconByID(param)
	if param.scale then
		headIcon:setScale(param.scale)
	end
	node:addChild(headIcon)
	local x, y = getPosition(headIcon)
	local size = getContentSize(headIcon)
	if param.name then
		local nameBg = ed.createSprite("UI/alpha/HVGA/pvp/pvp_rank_name_bg.png")
		nameBg:setAnchorPoint(ccp(0, 0.5))
		nameBg:setPosition(ccp(x + 8 + size.width / 2, y + 2))
		local paration = 28
		local font = "guild_join_list_guildname"
		if param.config then
			paration = param.config.nameposition
			font = param.config.namefont
		end
		
		local name = ed.createLabelWithFontInfo(param.name, font)
		name:setAnchorPoint(ccp(0, 0.5))
		name:setPosition(ccp(x + paration + size.width / 2, y + 2))
		if param.nameWidth and name:getContentSize().width > param.nameWidth then
			name:setScale(param.nameWidth / name:getContentSize().width)
		end
		node:addChild(nameBg)
		node:addChild(name)
	end
	local levelIcon = getLevelIcon(param)
	if levelIcon then
		local paration = 8
		if param.config then
			paration = param.config.levelposition
		end
		levelIcon:setAnchorPoint(ccp(0.5, 0.5))
		levelIcon:setPosition(ccp(x + paration + size.width / 2, y + 2))
		node:addChild(levelIcon)
	end
	return node
end
ed.getWholeHeadIcon = getWholeHeadIcon
local scaleNodeBySideLen = function(node, type, len)
	local size = node:getContentSize()
	local w = size.width
	local h = size.height
	if type == "w" then
		node:setScale(len / w)
	elseif type == "h" then
		node:setScale(len / h)
	end
end
ed.scaleNodeBySideLen = scaleNodeBySideLen
local fixNodeSize = function(node, size)
	if not size then
		return
	end
	local ns = node:getContentSize()
	local nw, nh = ns.width, ns.height
	local w, h = size.width, size.height
	if w > 0 then
		node:setScaleX(w / nw)
	end
	if h > 0 then
		node:setScaleY(h / nh)
	end
end
ed.fixNodeSize = fixNodeSize
local sumNodeSize = function(nodes)
	local w, h = 0, 0
	for k, v in pairs(nodes) do
		local size = v:getContentSize()
		local sx = v:getScaleX()
		local sy = v:getScaleY()
		w = w + size.width * sx
		h = h + size.height * sy
	end
	return w, h
end
ed.sumNodeSize = sumNodeSize
local getCenterPos = function(node)
	if tolua.isnull(node) then
		print("getCenterPos : invalid node")
		return
	end
	local size = node:getContentSize()
	local w, h = size.width, size.height
	return ccp(w / 2, h / 2)
end
ed.getCenterPos = getCenterPos
local left2Point = function(node, pos, offset)
	if tolua.isnull(node) then
		print("left2Point : invalid node")
		return
	end
	offset = offset or 0
	local anchor = node:getAnchorPoint()
	local size = node:getContentSize()
	local sx = node:getScaleX()
	node:setPosition(ccpAdd(pos, ccp(-size.width * sx * (1 - anchor.x) - offset, 0)))
end
ed.left2Point = left2Point
local function left2(node, refer, offset)
	if tolua.isnull(node) then
		print("left2 : invalid node")
		return
	end
	local pos = ed.getLeftSidePos(refer, offset)
	ed.left2Point(node, pos)
end
ed.left2 = left2
local getLeftSidePos = function(node, offset)
	if tolua.isnull(node) then
		print("getLeftSidePos : invalid node")
		return
	end
	offset = offset or 0
	local anchor = node:getAnchorPoint()
	local x, y = node:getPosition()
	local size = node:getContentSize()
	local sx = node:getScaleX()
	x = x - anchor.x * size.width * sx - offset
	return ccp(x, y)
end
ed.getLeftSidePos = getLeftSidePos
local right2Point = function(node, pos, offset)
	if tolua.isnull(node) then
		print("right2Point : invalid node")
		return
	end
	offset = offset or 0
	local anchor = node:getAnchorPoint()
	local size = node:getContentSize()
	local sx = node:getScaleX()
	node:setPosition(ccpAdd(pos, ccp(size.width * sx * anchor.x + offset, 0)))
end
ed.right2Point = right2Point
local function right2(node, refer, offset)
	if tolua.isnull(node) then
		print("right2 : invalid node")
		return
	end
	local pos = ed.getRightSidePos(refer, offset)
	ed.right2Point(node, pos)
end
ed.right2 = right2
local getRightSidePos = function(node, offset)
	if tolua.isnull(node) then
		print("getRightSidePos : invalid node")
		return
	end
	offset = offset or 0
	local anchor = node:getAnchorPoint()
	local x, y = node:getPosition()
	local size = node:getContentSize()
	local sx = node:getScaleX()
	x = x + (1 - anchor.x) * size.width * sx + offset
	return ccp(x, y)
end
ed.getRightSidePos = getRightSidePos
local below2Point = function(node, pos, offset)
	if tolua.isnull(node) then
		print("below2Point : invalid node")
		return
	end
	offset = offset or 0
	local anchor = node:getAnchorPoint()
	local size = node:getContentSize()
	local sy = node:getScaleY()
	node:setPosition(ccpAdd(pos, ccp(0, -size.height * sy * (1 - anchor.y) - offset)))
end
ed.below2Point = below2Point
local function below2(node, refer, offset)
	if tolua.isnull(node) then
		print("below2 : invalid node")
		return
	end
	local pos = ed.getBottomPos(refer, offset)
	ed.below2Point(node, pos)
end
ed.below2 = below2
local getBottomPos = function(node, offset)
	if tolua.isnull(node) then
		print("getBottomPos : invalid node")
		return
	end
	offset = offset or 0
	local anchor = node:getAnchorPoint()
	local x, y = node:getPosition()
	local size = node:getContentSize()
	local sy = node:getScaleY()
	y = y - anchor.y * size.height * sy - offset
	return ccp(x, y)
end
ed.getBottomPos = getBottomPos
local above2Point = function(node, pos, offset)
	if tolua.isnull(node) then
		print("above2Point : invalid node")
		return
	end
	offset = offset or 0
	local anchor = node:getAnchorPoint()
	local size = node:getContentSize()
	local sy = node:getScaleY()
	node:setPosition(ccpAdd(pos, ccp(0, size.height * sy * anchor.y + offset)))
end
ed.above2Point = above2Point
local function above2(node, refer, offset)
	if tolua.isnull(node) then
		print("above2 : invalid node")
		return
	end
	local pos = ed.getTopSidePos(refer, offset)
	ed.above2Point(node, pos)
end
ed.above2 = above2
local getTopSidePos = function(node, offset)
	if tolua.isnull(node) then
		print("getTopSidePos : invalid node")
		return
	end
	offset = offset or 0
	local anchor = node:getAnchorPoint()
	local x, y = node:getPosition()
	local size = node:getContentSize()
	local sy = node:getScaleY()
	y = y + anchor.y * size.height * sy + offset
	return ccp(x, y)
end
ed.getTopSidePos = getTopSidePos
local setNodeAnchor = function(node, anchor)
	if node == nil then
		return
	end
	local a = node:getAnchorPoint()
	local ax, ay = a.x, a.y
	local x, y = node:getPosition()
	local size = node:getContentSize()
	local w, h = size.width, size.height
	local cax, cay = anchor.x, anchor.y
	local cx, cy = x, y
	cx = cx - w * (ax - cax)
	cy = cy - h * (ay - cay)
	node:setAnchorPoint(anchor)
	node:setPosition(ccp(cx, cy))
end
ed.setNodeAnchor = setNodeAnchor
local function getExcavateNameTag(typeid)
	local row = ed.getDataTable("ExcavateTreasure")[typeid]
	if not row then
		return nil
	end
	local tag_res = {
	Diamond = "UI/alpha/HVGA/chat/chat_icon_treasure_diamond.png",
	Gold = "UI/alpha/HVGA/chat/chat_icon_treasure_gold.png",
	Item = "UI/alpha/HVGA/chat/chat_icon_treasure_exp.png"
	}
	local container = CCSprite:create()
	container:setCascadeOpacityEnabled(true)
	local produce = row["Produce Type"]
	local name = row["Display Name"]
	local scope = row["Max Player"] or 1
	local ui = {}
	local readnode = ed.readnode.create(container, ui)
	local ui_info = {
	{
	t = "HorizontalNode",
	base = {name = "tag"},
	layout = {
	anchor = ccp(0, 0),
	layout = ccp(0, 0)
	},
	config = {},
	ui = {
	{
	t = "Label",
	base = {
	name = "1",
	text = "【",
	size = 20
	},
	config = {
	color = ccc3(255, 255, 102)
	}
	},
	{
	t = "Sprite",
	base = {
	name = "2",
	res = tag_res[produce]
	}
	},
	{
	t = "Label",
	base = {
	name = "3",
	text = name .. "】",
	size = 20
	},
	config = {
	color = ccc3(255, 255, 102)
	}
	},
	{
	t = "Label",
	base = {
	name = "4",
	text = T("(%d", scope) .. LSTR("RESOURCE_MANAGER.HUMAN_BEINGS") .. ")",
	size = 20
	},
	config = {
	color = ccc3(255, 255, 102)
	}
	}
	}
	}
	}
	readnode:addNode(ui_info)
	container:setContentSize(ui.tag:getContentSize())
	return container
end
ed.getExcavateNameTag = getExcavateNameTag
local function createNode(param, parent, z)
	local node = ed.readnode.getFeralNode(param)
	if not tolua.isnull(parent) then
		parent:addChild(node, z or 0)
	end
	return node
end
ed.createNode = createNode
