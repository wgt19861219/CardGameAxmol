local envFuncs = {
  T = T,
  ccp = ccp,
  ccc3 = ccc3,
  CCRectMake = CCRectMake,
  CCSizeMake = CCSizeMake,
  ccc4 = ccc4,
  kCCTextAlignmentLeft = kCCTextAlignmentLeft,
  kCCTextAlignmentCenter = kCCTextAlignmentCenter,
  kCCTextAlignmentRight = kCCTextAlignmentRight,
  kCCVerticalTextAlignmentTop = kCCVerticalTextAlignmentTop,
  kCCVerticalTextAlignmentCenter = kCCVerticalTextAlignmentCenter,
  kCCVerticalTextAlignmentBottom = kCCVerticalTextAlignmentBottom,
  LSTR = LSTR
}
local configTableMeta = {}
function configTableMeta:__index(key)
  return envFuncs[key]
end
EDTables = {}
function _G.EDDefineTable(tablename)
  local newTable = EDTables[tablename]
  if nil == newTable then
    newTable = {}
    EDTables[tablename] = newTable
  end
  setmetatable(newTable, configTableMeta)
  setfenv(2, newTable)
end
