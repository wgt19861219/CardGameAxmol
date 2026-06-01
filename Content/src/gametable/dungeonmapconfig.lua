-- 副本地图UI配置动态生成器
-- 3层: mainLayer(z=0,背景框) < dragLayer(z=1,地图) < topLayer(z=2,标题底栏)
-- 所有battle/box直接挂在dragContainer下，使用绝对坐标（与远征一致）
local function buildUIRes(groupCount)
  local uiRes = {}

  -- ============ mainLayer: 触摸处理层（不放bgframe，避免遮挡） ============
  table.insert(uiRes, {
    layerName = "mainLayer",
    touchInfo = { iPriority = -1, bSwallowsTouches = true },
    uiRes = {}
  })

  -- ============ dragLayer: 地图内容 ============
  local dragUI = {
    { t = "Sprite", base = { name = "dragContainer" }, config = {} }
  }

  -- 每组3个Boss的相对位置（组内坐标）
  local bossOffset = {
    ccp(135, 260),
    ccp(370, 211),
    ccp(548, 268)
  }
  local groupWidth = 727
  local groupBasePos = ccp(25, 12) -- 组容器基准位置（与远征laftMap一致）

  for g = 1, groupCount do
    local offsetX = (g - 1) * groupWidth
    local bgIdx = ((g - 1) % 3) + 1

    -- 地图背景
    table.insert(dragUI, {
      t = "Sprite",
      base = {
        name = string.format("bg%d", g),
        res = string.format("UI/alpha/HVGA/crusade/crusade_detail_bg%d.png", bgIdx),
        parent = "dragContainer"
      },
      layout = { anchor = ccp(0, 0.5), position = ccp(25 + offsetX, 210) },
      config = { scale = 2.0 }
    })

    -- 3个Boss节点 + 宝箱（直接挂在dragContainer下，用绝对坐标）
    for b = 1, 3 do
      local idx = (g - 1) * 3 + b
      local absX = groupBasePos.x + offsetX + bossOffset[b].x
      local absY = groupBasePos.y + bossOffset[b].y

      -- Boss战斗节点
      table.insert(dragUI, {
        t = "SpriteButton",
        base = {
          name = string.format("battle%d", idx),
          res = {
            normal = string.format("UI/alpha/HVGA/crusade/stage/crusade_stage_%d.png", idx),
            disable = string.format("UI/alpha/HVGA/crusade/stage/crusade_stage_%d_locked.png", idx)
          },
          parent = "dragContainer",
          handleName = "selectBoss",
          arrayIndex = idx
        },
        layout = { anchor = ccp(0.5, 0.5), position = ccp(absX, absY) },
        config = { messageRect = CCRectMake(0, 0, 80, 80) }
      })

      -- 宝箱
      table.insert(dragUI, {
        t = "Sprite",
        base = {
          name = string.format("box%d", idx),
          res = "UI/alpha/HVGA/crusade/crusade_box_bronze_closed.png",
          parent = "dragContainer"
        },
        layout = {
          anchor = ccp(0.5, 0.5),
          position = ccp(absX, absY + 45)
        },
        config = { scale = 0.6 }
      })
    end
  end

  -- 雾效（逆序添加，fog1在最上层）
  local fogCount = groupCount - 1
  for i = fogCount, 1, -1 do
    local fogImg = math.min(i, 4)
    table.insert(dragUI, {
      t = "Sprite",
      base = {
        name = string.format("fog%d", i),
        res = string.format("UI/alpha/HVGA/crusade/crusade_fog_%d.png", fogImg),
        parent = "dragContainer"
      },
      layout = { anchor = ccp(0, 0.5), position = ccp(25, 210) },
      config = { scale = 4.0 }
    })
  end

  table.insert(uiRes, { layerName = "dragLayer", uiRes = dragUI })

  -- ============ uiLayer: 标题和底栏 ============
  table.insert(uiRes, {
    layerName = "uiLayer",
    touchInfo = { iPriority = -1, bSwallowsTouches = true },
    uiRes = {
      {
        t = "Sprite",
        base = { name = "titleBg", res = "UI/alpha/HVGA/crusade/crusade_title_bg.png" },
        layout = { position = ccp(402, 395.3) }
      },
      {
        t = "Sprite",
        base = { name = "bottom" },
        layout = { position = ccp(402, 55) }
      },
      {
        t = "Scale9Sprite",
        base = {
          name = "bottomframe",
          res = "UI/alpha/HVGA/crusade/crusade_reset_bg.png",
          capInsets = CCRectMake(20, 20, 18, 18),
          parent = "bottom"
        },
        layout = {},
        config = { scaleSize = CCSizeMake(560, 58) }
      }
    }
  })

  return uiRes
end

return { buildUIRes = buildUIRes }
