local ed = ed
local dict
local function utf8_iter(s)
  local i = 0
  return function()
    if #s == 0 then return nil end
    local b = s:byte(1)
    local len
    if b < 128 then len = 1
    elseif b < 224 then len = 2
    elseif b < 240 then len = 3
    else len = 4
    end
    local c = s:sub(1, len)
    s = s:sub(len + 1)
    i = i + 1
    return i, c
  end
end
local function make_dict()
  local tab = ed.getDataTable("dirtywords")
  dict = {}
  for k, _ in pairs(tab) do
    if k ~= name then
      local node = dict
      for i, c in utf8_iter(k) do
        if not node[c] then
          node[c] = {}
        end
        node = node[c]
      end
      node.ending = true
    end
  end
end
local function check(array, i)
  local node = dict
  local j = i - 1
  while true do
    if not node or node.ending then
      break
    end
    j = j + 1
    local c = array[j]
    node = node[c]
  end
  if node and node.ending then
    return table.concat(array, "", i, j)
  end
end
local function dirtyword_check(text)
  if not dict then
    make_dict()
  end
  local array = {}
  for i, c in utf8_iter(text) do
    array[i] = c
  end
  for i = 1, #array do
    local word = check(array, i)
    if word then
      return word
    end
  end
end
ed.dirtyword_check = dirtyword_check
