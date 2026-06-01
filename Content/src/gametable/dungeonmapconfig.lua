-- 副本地图UI配置
-- 完全照搬远征crusadeconfig：固定3张背景+3个子容器
-- 3个section，每个section最多5个boss，总计15个boss位置
-- mainLayer: bgframe + title + bottom（与远征完全一致）
local function buildUIRes()
  local uiRes = {}

  -- ============ dragLayer: 固定3个section（照搬远征） ============
  local dragUI = {
    { t = "Sprite", base = { name = "dragContainer" }, config = {} },
    -- 背景1（对应远征bg1 at 25,210）
    {
      t = "Sprite",
      base = {
        name = "bg1",
        res = "UI/alpha/HVGA/crusade/crusade_detail_bg1.png",
        parent = "dragContainer"
      },
      layout = { anchor = ccp(0, 0.5), position = ccp(25, 210) },
      config = { scale = 2.0 }
    },
    -- 背景2（对应远征bg2 at 752,210）
    {
      t = "Sprite",
      base = {
        name = "bg2",
        res = "UI/alpha/HVGA/crusade/crusade_detail_bg2.png",
        parent = "dragContainer"
      },
      layout = { anchor = ccp(0, 0.5), position = ccp(752, 210) },
      config = { scale = 2.0 }
    },
    -- 背景3（对应远征bg3 at 1477,210）
    {
      t = "Sprite",
      base = {
        name = "bg3",
        res = "UI/alpha/HVGA/crusade/crusade_detail_bg3.png",
        parent = "dragContainer"
      },
      layout = { anchor = ccp(0, 0.5), position = ccp(1477, 210) },
      config = { scale = 2.0 }
    },
    -- 子容器1（对应远征laftMap at 25,12）
    {
      t = "Sprite",
      base = { name = "sub1", parent = "dragContainer" },
      layout = { anchor = ccp(0, 0.5), position = ccp(25, 12) }
    },
    -- 子容器2（对应远征rightMap at 752,12）
    {
      t = "Sprite",
      base = { name = "sub2", parent = "dragContainer" },
      layout = { anchor = ccp(0, 0.5), position = ccp(752, 12) }
    },
    -- 子容器3（对应远征rightMap2 at 1477,12）
    {
      t = "Sprite",
      base = { name = "sub3", parent = "dragContainer" },
      layout = { anchor = ccp(0, 0.5), position = ccp(1477, 12) }
    },
  }
  table.insert(uiRes, { layerName = "dragLayer", uiRes = dragUI })

  -- ============ mainLayer: 边框+标题+底栏（与远征完全一致） ============
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
