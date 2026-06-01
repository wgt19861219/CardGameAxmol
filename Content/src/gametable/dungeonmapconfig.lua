-- 副本地图UI配置动态生成器
-- 2层结构（与远征crusadeconfig完全一致）：
-- dragLayer(z=0): dragContainer + bg（地图内容，可拖拽）
-- mainLayer(z=1,触摸): bgframe + title + bottom（盖在地图上面，产生裁剪效果）
local function buildUIRes(groupCount)
  local uiRes = {}

  -- ============ dragLayer: 地图内容 ============
  local dragUI = {
    { t = "Sprite", base = { name = "dragContainer" }, config = {} }
  }
  for g = 1, groupCount do
    local offsetX = (g - 1) * 727
    local bgIdx = ((g - 1) % 3) + 1
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
  end
  table.insert(uiRes, { layerName = "dragLayer", uiRes = dragUI })

  -- ============ mainLayer: 触摸 + 边框 + 标题 + 底栏（与远征完全一致） ============
  -- bgframe盖在dragLayer上面，产生裁剪视觉效果
  table.insert(uiRes, {
    layerName = "mainLayer",
    touchInfo = { iPriority = -1, bSwallowsTouches = true },
    uiRes = {
      {
        t = "Sprite",
        base = { name = "bg", res = "UI/alpha/HVGA/crusade/crusade_map_frame_light1.png" },
        layout = { position = ccp(400, 210) },
        config = {}
      },
      {
        t = "Sprite",
        base = { name = "bg", res = "UI/alpha/HVGA/crusade/crusade_map_frame_light2.png" },
        layout = { position = ccp(400, 210) },
        config = {}
      },
      {
        t = "Sprite",
        base = { name = "bgframe", res = "UI/alpha/HVGA/crusade/crusade_map_frame.png" },
        layout = { position = ccp(400, 210) },
        config = {}
      },
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
