ed.ui.herodetail = ed.ui.herodetail or {}
local herodetail = ed.ui.herodetail
local base = ed.ui.baseres
local class = newclass(base.mt)
herodetail.res = class
setfenv(1, class)
equip_tag_icon = {
  wear = "UI/alpha/HVGA/herodetail-equipadd.png",
  cannotwear = "UI/alpha/HVGA/herodetail_icon_plus_yellow.png"
}
equip_tag_text = {
  notHave = "UI/alpha/HVGA/herodetail-equip-nowned.png",
  canWear = "UI/alpha/HVGA/herodetail-equip-owned.png",
  cannotwear = "UI/alpha/HVGA/herodetail_cannot_equip.png",
  canCraft = "UI/alpha/HVGA/herodetail-equip-craftable.png"
}
type_icon = {
  STR = "UI/alpha/HVGA/icon_str.png",
  AGI = "UI/alpha/HVGA/icon_agi.png",
  INT = "UI/alpha/HVGA/icon_int.png"
}
card_type_icon = {
  STR = "UI/alpha/HVGA/card/card_att_str.png",
  AGI = "UI/alpha/HVGA/card/card_att_agi.png",
  INT = "UI/alpha/HVGA/card/card_att_int.png"
}
card_frame = {
  "UI/alpha/HVGA/card/card_bg_white.png",
  "UI/alpha/HVGA/card/card_bg_green.png",
  "UI/alpha/HVGA/card/card_bg_green.png",
  "UI/alpha/HVGA/card/card_bg_blue.png",
  "UI/alpha/HVGA/card/card_bg_blue.png",
  "UI/alpha/HVGA/card/card_bg_blue.png",
  "UI/alpha/HVGA/card/card_bg_purple.png",
  "UI/alpha/HVGA/card/card_bg_purple.png",
  "UI/alpha/HVGA/card/card_bg_purple.png",
  "UI/alpha/HVGA/card/card_bg_purple.png",
  "UI/alpha/HVGA/card/card_bg_purple.png",
  "UI/alpha/HVGA/card/card_bg_orange.png",
  "UI/alpha/HVGA/card/card_bg_orange.png",
  "UI/alpha/HVGA/card/card_bg_orange.png",
  "UI/alpha/HVGA/card/card_bg_orange.png",
  "UI/alpha/HVGA/card/card_bg_orange.png",
  "UI/alpha/HVGA/card/card_bg_orange.png",
  "UI/alpha/HVGA/card/card_bg_red.png",
  "UI/alpha/HVGA/card/card_bg_red.png",
  "UI/alpha/HVGA/card/card_bg_red.png",
  "UI/alpha/HVGA/card/card_bg_red.png",
  "UI/alpha/HVGA/card/card_bg_red.png",
  "UI/alpha/HVGA/card/card_bg_red.png"
}
card_rotate_amount = 0
card_rotate_direction = "left"
skill_unlock_color_text = {
  T(LSTR("HERODETAILRES.WHITE")),
  T(LSTR("HERODETAILRES.GREEN")),
  T(LSTR("HERODETAILRES.GREEN")),
  T(LSTR("HERODETAILRES.BLUE")),
  T(LSTR("HERODETAILRES.BLUE")),
  T(LSTR("HERODETAILRES.BLUE")),
  T(LSTR("HERODETAILRES.PURPLE")),
  T(LSTR("HERODETAILRES.PURPLE")),
  T(LSTR("HERODETAILRES.PURPLE")),
  T(LSTR("HERODETAILRES.PURPLE")),
  T(LSTR("HERODETAILRES.PURPLE")),
  T(LSTR("HERODETAILRES.ORANGE")),
  T(LSTR("HERODETAILRES.ORANGE")),
  T(LSTR("HERODETAILRES.ORANGE")),
  T(LSTR("HERODETAILRES.ORANGE")),
  T(LSTR("HERODETAILRES.ORANGE")),
  T(LSTR("HERODETAILRES.ORANGE")),
  T(LSTR("HERODETAILRES.RED")),
  T(LSTR("HERODETAILRES.RED")),
  T(LSTR("HERODETAILRES.RED")),
  T(LSTR("HERODETAILRES.RED")),
  T(LSTR("HERODETAILRES.RED")),
  T(LSTR("HERODETAILRES.RED"))
}
skill_unlock_key_rank = {
  [2] = 2,
  [4] = 3,
  [7] = 4,
  [12] = 5,
  [17] = 6
}
equip_rank_info = {
  {name = "White", font = "equip_white"},
  {name = "Green", font = "equip_green"},
  {name = "Green+1", font = "equip_green"},
  {name = "Blue", font = "equip_blue"},
  {name = "Blue+1", font = "equip_blue"},
  {name = "Blue+2", font = "equip_blue"},
  {name = "Purple", font = "equip_purple"},
  {name = "Purple+1", font = "equip_purple"},
  {name = "Purple+2", font = "equip_purple"},
  {name = "Purple+3", font = "equip_purple"},
  {name = "Purple+4", font = "equip_purple"},
  {name = "Orange", font = "equip_orange"},
  {name = "Orange+1", font = "equip_orange"},
  {name = "Orange+2", font = "equip_orange"},
  {name = "Orange+3", font = "equip_orange"},
  {name = "Orange+4", font = "equip_orange"},
  {name = "Orange+5", font = "equip_orange"},
  {name = "Red", font = "equip_red"},
  {name = "Red+1", font = "equip_red"},
  {name = "Red+2", font = "equip_red"},
  {name = "Red+3", font = "equip_red"},
  {name = "Red+4", font = "equip_red"},
  {name = "Red+5", font = "equip_red"}
}
