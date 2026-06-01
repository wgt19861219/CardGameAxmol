local ed = ed
local class = {
  mt = {}
}
class.mt.__index = class
ed.ui.exerciseres = class
class.entry_stage = {
  exp = 20001,
  money = 20002,
  int = 20003,
  agi = 20004,
  str = 20005,
  dg1 = 40001,
  dg2 = 40002,
  dg3 = 40003,
  dg4 = 40004,
  dg5 = 40005,
  dg6 = 40006,
  dg7 = 40007,
}
class.em = {
  uires = {
    frame = "UI/alpha/HVGA/stage-map-elite-frame.png",
    map = "UI/alpha/HVGA/act/act_map_bg_purple.png",
    titleShadow = "UI/alpha/HVGA/act/act_title_bg.png",
    titleBg = "UI/alpha/HVGA/equip_detail_title_bg.png",
    title = "UI/alpha/HVGA/act/act_title_2.png"
  },
  entry = {
    exp = {
      fca = {
        "NagaPriest.cha",
        "NagaArcher.cha"
      },
      pos = {
        ccp(178, 150),
        ccp(234, 156)
      },
      scale = {1, 1},
      center = ccp(212, 210),
      radius = 85,
      descres = "UI/alpha/HVGA/act/act_popup_title_4_1.png"
    },
    money = {
      fca = {"Tank.cha"},
      pos = {
        ccp(560, 210)
      },
      scale = {1},
      center = ccp(575, 185),
      radius = 85,
      descres = "UI/alpha/HVGA/act/act_popup_title_1_1.png"
    },
    cavern = {
      fca = {},
      pos = {},
      scale = {},
      center = ccp(400, 85),
      radius = 55,
      descres = "",
      isCavern = true,
    }
  }
}
class.equip = {
  uires = {
    frame = "UI/alpha/HVGA/stage-map-elite-frame.png",
    map = "UI/alpha/HVGA/act/act_map_bg_brown.png",
    titleShadow = "UI/alpha/HVGA/act/act_title_bg.png",
    titleBg = "UI/alpha/HVGA/equip_detail_title_bg.png",
    title = "UI/alpha/HVGA/act/act_title_1.png"
  },
  entry = {
    int = {
      fca = {"Golem.cha"},
      pos = {
        ccp(180, 168)
      },
      scale = {0.8},
      center = ccp(180, 180),
      radius = 85,
      descres = "UI/alpha/HVGA/act/act_popup_title_2_1.png"
    },
    agi = {
      fca = {
        "DragonBaby.cha"
      },
      pos = {
        ccp(392, 197)
      },
      scale = {0.8},
      center = ccp(390, 285),
      radius = 85,
      descres = "UI/alpha/HVGA/act/act_popup_title_3_1.png"
    },
    str = {
      fca = {
        "DR.cha",
        "Ench.cha",
        "WR.cha"
      },
      pos = {
        ccp(623, 197),
        ccp(654, 162),
        ccp(600, 162)
      },
      scale = {
        0.9,
        0.9,
        0.9
      },
      center = ccp(620, 185),
      radius = 85,
      descres = "UI/alpha/HVGA/act/act_popup_title_5_1.png"
    },
    dg1 = {
      fca = {},
      pos = {},
      scale = {},
      center = ccp(140, 85),
      radius = 55,
      descres = "",
      isDungeon = true,
    },
    dg2 = {
      fca = {},
      pos = {},
      scale = {},
      center = ccp(310, 85),
      radius = 55,
      descres = "",
      isDungeon = true,
    },
    dg3 = {
      fca = {},
      pos = {},
      scale = {},
      center = ccp(480, 85),
      radius = 55,
      descres = "",
      isDungeon = true,
    },
    dg4 = {
      fca = {},
      pos = {},
      scale = {},
      center = ccp(650, 85),
      radius = 55,
      descres = "",
      isDungeon = true,
    },
    cavern = {
      fca = {},
      pos = {},
      scale = {},
      center = ccp(830, 85),
      radius = 55,
      descres = "",
      isCavern = true,
    },
  }
}
