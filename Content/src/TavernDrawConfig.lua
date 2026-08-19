-- TavernDrawConfig 数据表(占位)
-- 原版此表未随资源迁移,导致 local_server 的 tavern_draw handler 在
-- getDataTable 处走 csv 回退路径崩溃(io.open nil),抽卡回复永久丢失。
-- 真实抽卡扣款逻辑不依赖本表;此处仅钻石消耗统计(activity_spent)读取。
-- 结构: [boxType] = { ["Draw 1 Cost Diamond"] = N, ["Draw 10 Cost Diamond"] = N }
-- boxType: 1=铜箱(bronze,金币/免费) 2=银箱 3=金箱(gold,钻石) 4=魂匣
local data = {
  [1] = { ["Draw 1 Cost Diamond"] = 0, ["Draw 10 Cost Diamond"] = 0 },
  [2] = { ["Draw 1 Cost Diamond"] = 0, ["Draw 10 Cost Diamond"] = 0 },
  [3] = { ["Draw 1 Cost Diamond"] = 0, ["Draw 10 Cost Diamond"] = 0 },
  [4] = { ["Draw 1 Cost Diamond"] = 0, ["Draw 10 Cost Diamond"] = 0 },
}
return data
