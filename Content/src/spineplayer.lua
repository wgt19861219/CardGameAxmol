-- spineplayer.lua — Spine 2.1.07 region-only 简化骨骼动画播放器
-- 借鉴 CardGame2(Godot 版) scripts/ui/spine_skeleton.gd 三件套移植到 Lua/cocos。
-- 背景:Source/SpineContainer.cpp 遇 "spine":"2.x" 数据直接返回 nullptr(4.x runtime 不兼容),
-- resource_manager.createFcaNode 因此回退到单张最大散件静态图,主界面建筑风车/光效等散件缺失。
-- 本播放器在 Lua 层还原骨骼层级 + slot 附件 + 逐帧插值(region-only,无 mesh/权重/IK/约束/事件/变形)。
-- 坐标系:cocos y 向上与 Spine 一致,无需翻转;bone/attachment rotation 均逆时针正,setRotation 同号直用
-- (语义对照 HC 原项目 spine runtime Code_Core/extensions/spine/RegionAttachment.c 顶点数学)。
-- rotate region:atlas 内宽高互换存储,切图后 setRotation(+90) 校准(方向以截图实测为准)。

local spineplayer = {}

-- ============ 工具:颜色/曲线/插值(移植 spine_skeleton.gd) ============

local colorHexCache = {}

local function parseColorHex(hex)
	if not hex or #hex < 8 then return 255, 255, 255, 255 end
	local cached = colorHexCache[hex]
	if cached then return cached[1], cached[2], cached[3], cached[4] end
	local r = tonumber(hex:sub(1, 2), 16) or 255
	local g = tonumber(hex:sub(3, 4), 16) or 255
	local b = tonumber(hex:sub(5, 6), 16) or 255
	local a = tonumber(hex:sub(7, 8), 16) or 255
	colorHexCache[hex] = { r, g, b, a }
	return r, g, b, a
end

local function bez(t, p1, p2)
	local mt = 1 - t
	return 3 * mt * mt * t * p1 + 3 * mt * t * t * p2 + t * t * t
end

local function bezD(t, p1, p2)
	local mt = 1 - t
	return 3 * mt * mt * p1 + 6 * mt * t * (p2 - p1) + 3 * t * t * (1 - p2)
end

-- 贝塞尔 P0=(0,0) P1=(c1,c2) P2=(c3,c4) P3=(1,1),给 x=tx 牛顿迭代求 y
local function bezierY(tx, c1, c2, c3, c4)
	local t = tx
	for _ = 1, 5 do
		local x = bez(t, c1, c3)
		local dx = bezD(t, c1, c3)
		if math.abs(dx) < 1e-6 then break end
		t = t - (x - tx) / dx
		if t < 0 then t = 0 elseif t > 1 then t = 1 end
	end
	return bez(t, c2, c4)
end

-- curve:缺省/nil="linear" | "stepped" | {c1,c2,c3,c4} 贝塞尔控制点
local function evalCurve(curve, raw)
	if curve == nil or curve == "linear" then return raw end
	if curve == "stepped" then return 0 end
	if type(curve) == "table" and #curve >= 4 then
		return bezierY(raw, curve[1], curve[2], curve[3], curve[4])
	end
	return raw
end

-- 找 t 落在哪两个关键帧之间 + 插值 alpha;返回 i0, i1, alpha(1-based)
local function keyframes(timeline, t)
	local n = #timeline
	if n == 0 then return 0, 0, 0 end
	if t <= (timeline[1].time or 0) then return 1, 1, 0 end
	if t >= (timeline[n].time or 0) then return n, n, 0 end
	for i = 1, n - 1 do
		local t0 = timeline[i].time or 0
		local t1 = timeline[i + 1].time or 0
		if t >= t0 and t < t1 then
			local raw = t1 > t0 and (t - t0) / (t1 - t0) or 0
			return i, i + 1, evalCurve(timeline[i].curve, raw)
		end
	end
	return n, n, 0
end

local function lastTime(timeline)
	local n = #timeline
	if n == 0 then return 0 end
	return timeline[n].time or 0
end

-- 角度最短路径插值(spine-c RotateTimeline 语义:diff 归一化到 [-180,180))。
-- 相邻帧差 >180° 时数值线性插值会绕远路自旋(主城 Shop/Mailbox/Guard 建筑摇摆动画有此数据)。
local function interpAngle(timeline, t)
	local i0, i1, alpha = keyframes(timeline, t)
	if i0 == 0 then return 0 end
	local v0 = timeline[i0].angle or 0
	local v1 = timeline[i1].angle or 0
	local diff = math.fmod(v1 - v0 + 540, 360) - 180
	return v0 + diff * alpha
end

local function interpVec(timeline, t)
	local i0, i1, alpha = keyframes(timeline, t)
	if i0 == 0 then return 0, 0 end
	local f0, f1 = timeline[i0], timeline[i1]
	local x0, y0 = f0.x or 0, f0.y or 0
	local x1, y1 = f1.x or 0, f1.y or 0
	return x0 + (x1 - x0) * alpha, y0 + (y1 - y0) * alpha
end

local function interpColor(timeline, t)
	local i0, i1, alpha = keyframes(timeline, t)
	if i0 == 0 then return 255, 255, 255, 255 end
	local r0, g0, b0, a0 = parseColorHex(timeline[i0].color)
	local r1, g1, b1, a1 = parseColorHex(timeline[i1].color)
	return r0 + (r1 - r0) * alpha, g0 + (g1 - g0) * alpha,
		b0 + (b1 - b0) * alpha, a0 + (a1 - a0) * alpha
end

-- slot attachment timeline(序列帧切换):找 t 时刻该 slot 显示的 attachment 名。
-- name=nil/空=隐藏;t < 首帧 time 时用 slot 默认 attachment。
local function slotAttachmentAt(timeline, t, defaultAtt)
	local n = #timeline
	if n == 0 then return defaultAtt end
	if t < (timeline[1].time or 0) then return defaultAtt end
	local lastName = nil
	for i = 1, n do
		local frame = timeline[i]
		if (frame.time or 0) <= t then
			lastName = frame.name
		else
			break
		end
	end
	return lastName
end

-- ============ SpriteFrame 缓存(resource 级,跨实例复用) ============

local frameCache = {}

local function getFrames(resource)
	if frameCache[resource] then return frameCache[resource] end
	local fu = CCFileUtils:sharedFileUtils()
	local atlasPath = 'spine/' .. resource .. '/' .. resource .. '.atlas'
	local pngPath = 'spine/' .. resource .. '/' .. resource .. '.png'
	if not fu:isFileExist(atlasPath) or not fu:isFileExist(pngPath) then
		return nil
	end
	local atlasContent = fu:getStringFromFile(atlasPath)
	if not atlasContent or atlasContent == "" then return nil end
	local regions = ed.parseAtlasRegions(atlasContent)
	if not regions or #regions == 0 then return nil end
	local texture = CCTextureCache:sharedTextureCache():addImage(pngPath)
	if not texture then return nil end
	-- 坐标系要点(引擎源码 SpriteFrame.cpp + CardGame2 最终纹理像素对照实证,2026-08-20):
	-- 1. spine 2.1 atlas xy 为左下原点;2 参 createWithTexture 的 rect 为逻辑点(引擎内部 ×contentScale 转像素)
	-- 2. factor = 逻辑/像素(contentScale 倒数);3. rotate region 用 sprite setRotation(+90) 逆时针转正(cocos 正角逆时针)
	local pxH = texture:getContentSize().height
	local factor = 1
	pcall(function()
		pxH = texture:getPixelsHigh()
		factor = texture:getContentSize().width / texture:getPixelsWide()
	end)
	local frames = {}
	local mainName, mainArea = nil, -1
	for _, r in ipairs(regions) do
		local storedW, storedH
		if r.rotate then
			storedW, storedH = r.height, r.width
		else
			storedW, storedH = r.width, r.height
		end
		local area = storedW * storedH
		if area > mainArea then mainArea, mainName = area, r.name end
		-- atlas xy 为标准左上原点(2026-08-20 终版:Guard/Pvp 主体覆盖率 0.53/0.60 vs 左下解释 0.15/0.42
		-- 证明左上;此前"左下原点"结论系 Pve 主体两解释重叠 95% + 风车序列帧相邻相似的假阳性)
		-- rect 单位为逻辑点(×factor,引擎内部 ×contentScale 转像素)
		local rect = CCRectMake(r.x * factor, r.y * factor, storedW * factor, storedH * factor)
		local frame = CCSpriteFrame:createWithTexture(texture, rect)
		if frame then
			frames[r.name] = { frame = frame, rotated = r.rotate and true or false }
		end
	end
	if not next(frames) then return nil end
	-- 主体 region(面积最大):保持 Axmol 既有口径(逻辑尺寸,用户基准);
	-- 其余装饰部件(光柱/旗帜/风车叶片等)按 spine 原生口径(×1/factor)渲染,
	-- 与 Godot 端等效显示一致(2026-08-20 远征光柱可见性)
	frames._mainRegion = mainName
	frames._partScale = 1 / factor
	frameCache[resource] = frames
	return frames
end

-- ============ 播放器 ============

local function applyAttToSprite(sprite, att, frames, attName)
	local entry = frames[attName]
	if not entry then return end
	sprite:setDisplayFrame(entry.frame)
	-- rotate region 在 atlas 中转置存储:存储贴图 setRotation(-90)+setScaleX(-1) 复原
	-- (离屏渲染 vs CardGame2 最终纹理像素对照 0.963 实证,2026-08-20;setFlipX 在 visit 路径不生效,负 scale 可靠)
	-- 非 rotate 原样直显即正确(同法实证 0.814)
	-- spine 角度逆时针正,cocos setRotation 顺时针正 —— 所有 spine 角度入口取负
	-- (2026-08-20 远征 Light 位置实证:att 偏移被骨骼反向旋转进火山体内)
	local rot = -((att and att.rotation) or 0)
	local sx, sy = (att and att.scaleX) or 1, (att and att.scaleY) or 1
	local ts = 1
	if frames._partScale and attName ~= frames._mainRegion then
		ts = frames._partScale -- 装饰部件按 spine 原生口径(主体保持用户基准尺寸)
	end
	if entry.rotated then
		sprite:setRotation(rot - 90)
		sprite:setScale(-sx * ts, sy * ts)
	else
		sprite:setRotation(rot)
		sprite:setScale(sx * ts, sy * ts)
	end
	sprite:setPosition((att and att.x) or 0, (att and att.y) or 0)
end

-- resource:资源名(如 "eff_UI_Main_Pve")。成功返回带骨骼层级与逐帧动画的 CCNode,失败返回 nil。
function spineplayer.create(resource)
	local data = ed.getOrParseSpineData(resource)
	if not data or not data.slots or #data.slots == 0 then return nil end
	local frames = getFrames(resource)
	if not frames then return nil end
	local skin = data.skins and data.skins.default
	if not skin then return nil end

	local container = CCNode:create()
	container:setCascadeOpacityEnabled(true)

	-- 骨骼层级(setup 姿态)。先建全部节点再挂父子链(pairs 无序,两遍循环保证父先存在)
	local boneNodes = {}
	local setupPos, setupRot, setupScale = {}, {}, {}
	for name, b in pairs(data.bones) do
		local node = CCNode:create()
		node:setPosition(b.x or 0, b.y or 0)
		node:setRotation(-(b.rotation or 0)) -- spine 逆时针正 → cocos 顺时针正
		node:setScale(b.scaleX or 1, b.scaleY or 1)
		boneNodes[name] = node
		setupPos[name] = { x = b.x or 0, y = b.y or 0 }
		setupRot[name] = -(b.rotation or 0)
		setupScale[name] = { x = b.scaleX or 1, y = b.scaleY or 1 }
	end
	local rootBoneName = nil
	for name, b in pairs(data.bones) do
		local parent = b.parent
		if parent and boneNodes[parent] then
			boneNodes[parent]:addChild(boneNodes[name])
		else
			container:addChild(boneNodes[name])
			if not rootBoneName then rootBoneName = name end
		end
	end

	-- setup 世界矩阵(spine-c Bone 语义:世界角=父+子,世界缩放=父×子,位置=父矩阵×局部平移)
	local boneMats = {}
	local function boneWorldMat(name)
		if boneMats[name] then return boneMats[name] end
		local b = data.bones[name]
		local m
		if not b then
			m = { a = 1, b = 0, c = 0, d = 1, tx = 0, ty = 0 }
		elseif b.parent and data.bones[b.parent] then
			local p = boneWorldMat(b.parent)
			local x, y = b.x or 0, b.y or 0
			local rot = math.rad((b.rotation or 0) + math.deg(math.atan2(p.b, p.a)))
			local wsx = p.wsx * (b.scaleX or 1)
			local wsy = p.wsy * (b.scaleY or 1)
			m = {
				a = math.cos(rot) * wsx, b = math.sin(rot) * wsx,
				c = -math.sin(rot) * wsy, d = math.cos(rot) * wsy,
				tx = p.a * x + p.c * y + p.tx,
				ty = p.b * x + p.d * y + p.ty,
				wsx = wsx, wsy = wsy,
			}
		else
			local rot = math.rad(b.rotation or 0)
			local wsx, wsy = b.scaleX or 1, b.scaleY or 1
			m = {
				a = math.cos(rot) * wsx, b = math.sin(rot) * wsx,
				c = -math.sin(rot) * wsy, d = math.cos(rot) * wsy,
				tx = b.x or 0, ty = b.y or 0,
				wsx = wsx, wsy = wsy,
			}
		end
		boneMats[name] = m
		return m
	end

	-- mesh/skinnedmesh 附件降级摆放:解析 setup 加权世界顶点,对全部顶点做
	-- UV→世界 的最小二乘仿射拟合(UV 四角常无精确顶点,取最近点会低估尺寸),
	-- 贴图按拟合出的 U/V 轴向量做刚体摆放(忽略网格非刚性变形)
	local function meshPlacement(att, attName)
		local verts = {}
		local seq = att.vertices or {}
		local i = 1
		local n = #seq
		while i <= n do
			local bc = seq[i] or 0
			i = i + 1
			local vx, vy = 0, 0
			for _ = 1, bc do
				local bIdx = seq[i]
				local x, y, w = seq[i + 1] or 0, seq[i + 2] or 0, seq[i + 3] or 1
				i = i + 4
				local bName = data.boneOrder and data.boneOrder[bIdx + 1]
				local m = bName and boneWorldMat(bName) or boneWorldMat(rootBoneName or "")
				vx = vx + w * (m.a * x + m.c * y + m.tx)
				vy = vy + w * (m.b * x + m.d * y + m.ty)
			end
			verts[#verts + 1] = { x = vx, y = vy }
		end
		local uvs = att.uvs or {}
		local nv = #verts
		if nv < 3 then return nil end
		-- 最小二乘拟合 world = (a*u + b*v + c, a2*u + b2*v + c2)
		local suu, svv, suv, su, sv = 0, 0, 0, 0, 0
		local sxu, sxv, sx, syu, syv, sy = 0, 0, 0, 0, 0, 0
		for vi = 1, nv do
			local u = uvs[vi * 2 - 1] or 0
			local v = uvs[vi * 2] or 0
			local p = verts[vi]
			suu = suu + u * u; svv = svv + v * v; suv = suv + u * v
			su = su + u; sv = sv + v
			sxu = sxu + p.x * u; sxv = sxv + p.x * v; sx = sx + p.x
			syu = syu + p.y * u; syv = syv + p.y * v; sy = sy + p.y
		end
		local function solve3(m11, m12, m13, m21, m22, m23, m31, m32, m33, r1, r2, r3)
			local det = m11 * (m22 * m33 - m23 * m32) - m12 * (m21 * m33 - m23 * m31) + m13 * (m21 * m32 - m22 * m31)
			if math.abs(det) < 1e-9 then return nil end
			local d1 = r1 * (m22 * m33 - m23 * m32) - m12 * (r2 * m33 - m23 * r3) + m13 * (r2 * m32 - m22 * r3)
			local d2 = m11 * (r2 * m33 - r3 * m23) - r1 * (m21 * m33 - m23 * m31) + m13 * (m21 * r3 - r2 * m31)
			local d3 = m11 * (m22 * r3 - r2 * m32) - m12 * (m21 * r3 - r2 * m31) + r1 * (m21 * m32 - m22 * m31)
			return d1 / det, d2 / det, d3 / det
		end
		local a1, b1, c1 = solve3(suu, suv, su, suv, svv, sv, su, sv, nv, sxu, sxv, sx)
		local a2, b2, c2 = solve3(suu, suv, su, suv, svv, sv, su, sv, nv, syu, syv, sy)
		if not a1 or not a2 then return nil end
		-- U 轴向量(世界)= 拟合式中 u 系数;中心 = u=v=0.5 处
		local cx = c1 + (a1 + b1) * 0.5
		local cy = c2 + (a2 + b2) * 0.5
		return {
			cx = cx, cy = cy,
			angle = math.deg(math.atan2(a2, a1)),
			uw = math.sqrt(a1 * a1 + a2 * a2),
			vh = math.sqrt(b1 * b1 + b2 * b2),
		}
	end


	local slotSprites = {}
	local slotByName = {}
	local maxWidth, maxHeight = 0, 0
	for _, slot in ipairs(data.slots) do
		local attName = slot.attachment
		local att = attName and skin[slot.name] and skin[slot.name][attName]
		if attName and frames[attName] then
			local isMesh = att and (att.type == "mesh" or att.type == "skinnedmesh")
			local sprite = CCSprite:createWithSpriteFrame(frames[attName].frame)
			if sprite then
				if isMesh then
					-- mesh 降级:按最小二乘仿射拟合的世界摆位,挂 container(不挂骨骼)
					local pl = meshPlacement(att, attName)
					if pl then
						local entry = frames[attName]
						local ts = 1
						if frames._partScale and attName ~= frames._mainRegion then
							ts = frames._partScale -- 装饰部件按 spine 原生口径
						end
						local rw = math.max(att.width or 0, 1)
						local rh = math.max(att.height or 0, 1)
						local sx = pl.uw / rw * ts
						local sy = pl.vh / rh * ts
						if entry.rotated then
							sprite:setRotation(pl.angle - 90)
							sprite:setScaleX(-sx)
							sprite:setScaleY(sy)
						else
							sprite:setRotation(pl.angle)
							sprite:setScale(sx, sy)
						end
						sprite:setPosition(pl.cx, pl.cy)
						container:addChild(sprite)
					else
						-- 拟合失败兜底:按 region 式挂骨骼(att 无 x/y 则零偏移)
						applyAttToSprite(sprite, att, frames, attName)
						local boneNode = boneNodes[slot.bone] or boneNodes[rootBoneName]
						if boneNode then boneNode:addChild(sprite) end
					end
				else
					applyAttToSprite(sprite, att, frames, attName)
					local boneNode = boneNodes[slot.bone] or boneNodes[rootBoneName]
					if boneNode then boneNode:addChild(sprite) end
				end
				local r, g, b, a = parseColorHex(slot.color)
				sprite:setColor(ccc3(r, g, b))
				sprite:setOpacity(a)
				local w = math.abs(att.width or 0) * math.abs((att.scaleX or 1))
				local h = math.abs(att.height or 0) * math.abs((att.scaleY or 1))
				if w > maxWidth then maxWidth = w end
				if h > maxHeight then maxHeight = h end
				slotSprites[#slotSprites + 1] = {
					sprite = sprite,
					slot = slot,
					setupColor = slot.color,
					defaultAtt = attName,
					curAtt = attName,
					isMesh = isMesh,
					lastColor = nil, -- 上一帧已应用的 RGBA(微变跳过,减每帧临时对象)
				}
				slotByName[slot.name] = slotSprites[#slotSprites]
			end
		end
	end
	if #slotSprites == 0 then
		container:removeFromParentAndCleanup(true)
		return nil
	end
	container:setContentSize(CCSizeMake(maxWidth, maxHeight))

	-- ---- 动画状态 ----
	local anims = data.animations or {}
	local state = {
		action = nil,
		nextAction = nil,
		loop = true,
		elapsed = 0,
		playing = false,
		duration = 0,
		boneTimelines = nil, -- name -> {rotate=…, translate=…, scale=…}
		slotTimelines = nil, -- name -> {attachment=…, color=…}
	}
	-- 切 action 时:全量恢复 setup(骨骼姿态/slot 颜色/默认 attachment),再按新 action 建时间线索引
	local function resetToSetup()
		for name, node in pairs(boneNodes) do
			node:setPosition(setupPos[name].x, setupPos[name].y)
			node:setRotation(setupRot[name])
			node:setScale(setupScale[name].x, setupScale[name].y)
		end
		for _, entry in ipairs(slotSprites) do
			local att = skin[entry.slot.name] and skin[entry.slot.name][entry.defaultAtt]
			if att and frames[entry.defaultAtt] and not entry.isMesh then
				applyAttToSprite(entry.sprite, att, frames, entry.defaultAtt)
				entry.curAtt = entry.defaultAtt
				entry.sprite:setVisible(true)
			end
			local r, g, b, a = parseColorHex(entry.setupColor)
			entry.sprite:setColor(ccc3(r, g, b))
			entry.sprite:setOpacity(a)
			entry.lastColor = { r, g, b, a }
		end
	end

	local function prepareAction(name)
		local anim = anims[name]
		state.action = name
		state.elapsed = 0
		if not anim then
			state.duration = 0
			state.boneTimelines = nil
			state.slotTimelines = nil
			return
		end
		local boneTl, slotTl = {}, {}
		local duration = 0
		if anim.bones then
			for boneName, tl in pairs(anim.bones) do
				if boneNodes[boneName] then boneTl[boneName] = tl end
				duration = math.max(duration, lastTime(tl.rotate or {}))
				duration = math.max(duration, lastTime(tl.translate or {}))
				duration = math.max(duration, lastTime(tl.scale or {}))
			end
		end
		if anim.slots then
			for slotName, tl in pairs(anim.slots) do
				slotTl[slotName] = tl
				duration = math.max(duration, lastTime(tl.color or {}))
			end
		end
		state.duration = duration
		state.boneTimelines = next(boneTl) and boneTl or nil
		state.slotTimelines = next(slotTl) and slotTl or nil
	end

	local function applyFrame(t)
		if state.boneTimelines then
			for name, tl in pairs(state.boneTimelines) do
				local node = boneNodes[name]
				if node then
					if tl.rotate then
						node:setRotation(setupRot[name] - interpAngle(tl.rotate, t)) -- spine 增量取负
					end
					if tl.translate then
						local x, y = interpVec(tl.translate, t)
						node:setPosition(setupPos[name].x + x, setupPos[name].y + y)
					end
					if tl.scale then
						local sx, sy = interpVec(tl.scale, t)
						node:setScale(setupScale[name].x * sx, setupScale[name].y * sy)
					end
				end
			end
		end
		if state.slotTimelines then
			for slotName, tl in pairs(state.slotTimelines) do
				local entry = slotByName[slotName]
				if entry then
					local sprite = entry.sprite
					if tl.attachment then
						local target = slotAttachmentAt(tl.attachment, t, entry.defaultAtt)
						if not target or target == "" then
							sprite:setVisible(false)
							entry.curAtt = nil
						elseif target ~= entry.curAtt then
							local att = skin[slotName] and skin[slotName][target]
							if att and frames[target] and not entry.isMesh then
								applyAttToSprite(sprite, att, frames, target)
								entry.curAtt = target
								sprite:setVisible(true)
							elseif entry.isMesh then
								entry.curAtt = target -- mesh 不做帧切换,保持 setup 摆放
							else
								sprite:setVisible(false)
								entry.curAtt = nil
							end
						end
					end
					if tl.color then
						local r, g, b, a = interpColor(tl.color, t)
						local lc = entry.lastColor
						-- 色值微变(总和<8/1020)跳过 setColor,避免每帧制造 ccc3 临时对象
						if not lc or (math.abs(r - lc[1]) + math.abs(g - lc[2])
							+ math.abs(b - lc[3]) + math.abs(a - lc[4])) >= 8 then
							sprite:setColor(ccc3(r, g, b))
							sprite:setOpacity(a)
							entry.lastColor = { r, g, b, a }
						end
					end
				end
			end
		end
	end

	local function switchAction(name)
		resetToSetup()
		prepareAction(name)
		state.playing = state.duration > 0
		if state.playing then applyFrame(0) end
	end

	local hasAnim = next(anims) ~= nil
	if hasAnim then
		-- 逐帧驱动:scheduleScriptFunc(项目标准方式,hello.lua gameUpdate 同款);
		-- 节点销毁后 tolua.isnull 自检摘除 entry,避免泄漏。
		-- 视觉应用降频至 30fps(逻辑帧 15fps 环境下 60fps apply 是浪费,且减少每帧临时对象)
		local scheduler = CCDirector:sharedDirector():getScheduler()
		local entryId = nil
		local applyAccum = 0
		local APPLY_INTERVAL = 1 / 30
		entryId = scheduler:scheduleScriptFunc(function(dt)
			if tolua.isnull(container) then
				if entryId then scheduler:unscheduleScriptEntry(entryId) end
				return
			end
			if not state.playing then return end
			state.elapsed = state.elapsed + dt
			if state.elapsed >= state.duration then
				if state.loop then
					state.elapsed = math.fmod(state.elapsed, state.duration)
				else
					state.playing = false
					applyFrame(state.duration)
					if state.nextAction and anims[state.nextAction] then
						switchAction(state.nextAction)
					end
					return
				end
			end
			applyAccum = applyAccum + dt
			if applyAccum >= APPLY_INTERVAL then
				applyAccum = 0
				applyFrame(state.elapsed)
			end
		end, 0, false)
	end

	-- ---- FCA 兼容接口(createFcaNode 调用方协议,对齐 resource_manager.addStubMethods 全集) ----
	container.setAction = function(name)
		if anims[name] then switchAction(name) end
	end
	container.setNextAction = function(name)
		state.nextAction = name
	end
	container.setLoop = function(flag)
		state.loop = flag and true or false
	end
	container.runAnimation = container.setAction
	container.stopAllAnimations = function()
		state.playing = false
	end
	container.useShader = function() end
	container.useDefaultShader = function() end
	container.setComponent = function() end
	container.registerLuaListener = function() end
	container.unregisterLuaListener = function() end
	container.addEffect = function() return -1 end
	container.removeEffectWithID = function() end
	container.removeEffectWithName = function() end
	container.tint = function() end
	container.setActionElapsed = function(t)
		if state.playing then
			state.elapsed = t
			applyFrame(t)
		end
	end
	container.setActionSpeeder = function() end
	container.setStartAction = function() end
	container.setLoopAction = function() end
	container.getAniFileName = function() return resource end
	container.isTerminated = function() return not state.playing end

	-- 默认动作:优先 Loop(主城建筑惯例),否则首个 action
	if hasAnim then
		if anims.Loop then
			switchAction("Loop")
		else
			local firstName = nil
			for name, _ in pairs(anims) do
				firstName = firstName or name
			end
			switchAction(firstName)
		end
	end

	LegendLog("[spine-player] " .. resource .. ": " .. #slotSprites .. " slots, anim="
		.. tostring(hasAnim and state.action or "none") .. ", dur=" .. tostring(state.duration))
	return container
end
ed.createSpinePlayer = spineplayer.create

return spineplayer
