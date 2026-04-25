local ed = ed
local class = {
    mt = {}
}
class.mt.__index = class
ed.ui.savemanager = class

local function readSaveIndex()
    local fu = CCFileUtils:sharedFileUtils()
    local writablePath = fu:getWritablePath()
    local indexPath = writablePath .. "cardgame_save_index.json"
    local f = io.open(indexPath, "r")
    if not f then return {} end
    local content = f:read("*a")
    f:close()
    if not content or #content == 0 then return {} end
    local ok, data = pcall(json.decode, content)
    if ok and type(data) == "table" then return data end
    return {}
end

local function createSnapshotRow(snapshot, index, container, yPos)
    local row = CCSprite:create()
    row:setContentSize(CCSizeMake(520, 90))
    row:setPosition(ccp(260, yPos))
    row:setAnchorPoint(ccp(0.5, 1))

    local bg = ed.createScale9Sprite("UI/alpha/HVGA/main_vit_tips.png", CCRectMake(15, 20, 45, 15))
    bg:setContentSize(CCSizeMake(520, 85))
    bg:setPosition(ccp(260, 42))
    bg:setAnchorPoint(ccp(0.5, 0.5))
    row:addChild(bg)

    local timeStr = os.date("%m/%d %H:%M", snapshot.time or os.time())
    local typeStr = (snapshot.type == "manual") and "手动" or "自动"
    local headerText = string.format("#%d %s存档  %s", index, typeStr, timeStr)
    local headerLabel = ed.createttf(headerText, 16)
    headerLabel:setAnchorPoint(ccp(0, 0.5))
    headerLabel:setPosition(ccp(10, 68))
    ed.setLabelColor(headerLabel, ccc3(220, 200, 160))
    row:addChild(headerLabel)

    local levelText = string.format("Lv.%d", snapshot.level or 1)
    local levelLabel = ed.createttf(levelText, 18)
    levelLabel:setAnchorPoint(ccp(0, 0.5))
    levelLabel:setPosition(ccp(10, 42))
    ed.setLabelColor(levelLabel, ccc3(255, 220, 100))
    row:addChild(levelLabel)

    local team = snapshot.team or {}
    for i = 1, math.min(#team, 5) do
        local heroInfo = team[i]
        local icon = ed.readhero.createIcon({
            id = heroInfo.tid,
            rank = heroInfo.rank or 0,
            level = heroInfo.level,
            stars = heroInfo.stars
        })
        if icon and icon.icon then
            icon.icon:setScale(0.45)
            icon.icon:setAnchorPoint(ccp(0, 0.5))
            icon.icon:setPosition(ccp(100 + (i - 1) * 55, 42))
            row:addChild(icon.icon)
        end
    end

    if #team == 0 then
        local emptyLabel = ed.createttf("无配队数据", 14)
        emptyLabel:setAnchorPoint(ccp(0, 0.5))
        emptyLabel:setPosition(ccp(100, 42))
        ed.setLabelColor(emptyLabel, ccc3(150, 150, 150))
        row:addChild(emptyLabel)
    end

    container:addChild(row)
    return row
end

local function doManualSave(self)
    if ed.saveGame then
        ed.saveDirty = true
        local ok = ed.saveGame()
        if ok then
            ed.showToast("手动保存成功")
            self:destroy()
            local newPopup = ed.ui.savemanager.create()
            CCDirector:sharedDirector():getRunningScene():addChild(newPopup.mainLayer, 200)
        else
            ed.showAlertDialog({text = "保存失败"})
        end
    end
end
class.doManualSave = doManualSave

local function doExportSave(self)
    local ok, err = pcall(function()
        if ed.saveGame then ed.saveGame() end
        local fu = CCFileUtils:sharedFileUtils()
        local writablePath = fu:getWritablePath()
        local srcPath = writablePath .. "cardgame_save.json"
        local f = io.open(srcPath, "r")
        if not f then
            ed.showAlertDialog({text = "未找到存档文件"})
            return
        end
        local content = f:read("*a")
        f:close()
        local decodeOk, data = pcall(json.decode, content)
        if decodeOk and data then
            data._export_time = os.time()
            content = json.encode(data)
        end
        local ud = CCUserDefault:sharedUserDefault()
        ud:setStringForKey("cardgame_save_export", content)
        local dateStr = os.date("%Y%m%d")
        local exportName = "cardgame_save_export_" .. dateStr .. ".json"
        local exportPaths = {
            writablePath .. exportName,
            "/sdcard/Download/" .. exportName,
            "/storage/emulated/0/Download/" .. exportName
        }
        local savedTo = nil
        for _, path in ipairs(exportPaths) do
            local out = io.open(path, "w")
            if out then
                out:write(content)
                out:close()
                savedTo = path
                break
            end
        end
        if savedTo then
            ed.showAlertDialog({text = "存档导出成功！\n文件：" .. savedTo .. "\n换机时用系统自带的数据迁移\n工具即可将存档带到新设备"})
        else
            ed.showAlertDialog({text = "存档已保存到应用内部\n换机时用系统数据迁移工具"})
        end
    end)
    if not ok then
        ed.showAlertDialog({text = "导出失败: " .. tostring(err)})
    end
end
class.doExportSave = doExportSave

local function doImportSave(self)
    local ok, err = pcall(function()
        local fu = CCFileUtils:sharedFileUtils()
        local writablePath = fu:getWritablePath()
        local content = nil
        local ud = CCUserDefault:sharedUserDefault()
        local saved = ud:getStringForKey("cardgame_save_export")
        if saved and #saved > 10 then
            content = saved
        end
        if not content then
            local dateStr = os.date("%Y%m%d")
            local importPaths = {
                writablePath .. "cardgame_save_export_" .. dateStr .. ".json",
                writablePath .. "cardgame_save_export.json",
                "/sdcard/Download/cardgame_save_export_" .. dateStr .. ".json",
                "/sdcard/Download/cardgame_save_export.json",
                "/storage/emulated/0/Download/cardgame_save_export_" .. dateStr .. ".json",
                "/storage/emulated/0/Download/cardgame_save_export.json",
            }
            for _, path in ipairs(importPaths) do
                local f = io.open(path, "r")
                if f then
                    content = f:read("*a")
                    f:close()
                    break
                end
            end
        end
        if not content then
            ed.showAlertDialog({text = "未找到导出的存档\n请先在旧设备上点击导出，\n再用系统数据迁移工具\n将应用数据迁到本机"})
            return
        end
        local decodeOk, data = pcall(json.decode, content)
        if not decodeOk or not data or type(data) ~= "table" then
            ed.showAlertDialog({text = "存档文件格式无效\n无法解析JSON数据"})
            return
        end
        if not data._userid or not data._heroes then
            ed.showAlertDialog({text = "存档数据不完整\n缺少关键数据字段"})
            return
        end
        local currentSavePath = writablePath .. "cardgame_save.json"
        pcall(function()
            local cf = io.open(currentSavePath, "r")
            if cf then
                local c = cf:read("*a")
                cf:close()
                local bf = io.open(currentSavePath .. ".bak_pre_import", "w")
                if bf then bf:write(c) bf:close() end
            end
        end)
        local out = io.open(currentSavePath, "w")
        if not out then
            ed.showAlertDialog({text = "无法写入存档"})
            return
        end
        out:write(content)
        out:close()
        if ed.player and ed.player.setup then
            ed.player.heroes = {}
            ed.player:setup(data)
            if ed.recalcHeroGs and ed.player.heroes then
                for tid, hero in pairs(ed.player.heroes) do
                    ed.recalcHeroGs(hero)
                end
            end
            ed.saveDirty = true
            ed.saveGame()
        end
        ed.showAlertDialog({text = "存档导入成功！"})
        self:destroy()
    end)
    if not ok then
        ed.showAlertDialog({text = "导入失败: " .. tostring(err)})
    end
end
class.doImportSave = doImportSave

local function createWindow(self)
    if not tolua.isnull(self.container) then
        self.container:removeFromParentAndCleanup(true)
    end

    local mainLayer = self.mainLayer
    local container = CCLayer:create()
    container:setAnchorPoint(ccp(0.5, 0.8))
    self.container = container
    mainLayer:addChild(container)

    local ui = {}
    self.ui = ui
    local readnode = ed.readnode.create(container, ui)

    local ui_info = {
        {
            t = "Scale9Sprite",
            base = {
                name = "frame",
                res = "UI/alpha/HVGA/main_vit_tips.png",
                capInsets = CCRectMake(15, 20, 45, 15)
            },
            layout = {
                anchor = ccp(0.5, 0.5),
                position = ccp(480, 280)
            },
            config = {
                scaleSize = CCSizeMake(560, 430)
            }
        },
        {
            t = "Label",
            base = {
                name = "title",
                text = "存档管理",
                fontinfo = "ui_normal_button",
                size = 22
            },
            layout = {
                position = ccp(480, 480)
            },
            config = {
                color = ccc3(255, 220, 100),
                shadow = {
                    color = ccc3(0, 0, 0),
                    offset = ccp(0, 2)
                }
            }
        },
        {
            t = "Sprite",
            base = {
                name = "close",
                res = "UI/alpha/HVGA/common/common_tips_button_close_1.png"
            },
            layout = {
                position = ccp(745, 480)
            },
            config = {}
        },
        {
            t = "Sprite",
            base = {
                name = "close_press",
                res = "UI/alpha/HVGA/common/common_tips_button_close_2.png",
                parent = "close"
            },
            layout = {
                anchor = ccp(0, 0),
                position = ccp(0, 0)
            },
            config = {visible = false}
        },
        {
            t = "Scale9Sprite",
            base = {
                name = "save_button",
                res = "UI/alpha/HVGA/sell_number_button.png",
                capInsets = CCRectMake(15, 22, 15, 25)
            },
            layout = {
                position = ccp(380, 78)
            },
            config = {
                scaleSize = CCSizeMake(130, 45)
            }
        },
        {
            t = "Scale9Sprite",
            base = {
                name = "save_button_press",
                res = "UI/alpha/HVGA/sell_number_button_down.png",
                capInsets = CCRectMake(15, 22, 15, 25),
                parent = "save_button"
            },
            layout = {
                anchor = ccp(0, 0),
                position = ccp(0, 0)
            },
            config = {
                scaleSize = CCSizeMake(130, 45),
                visible = false
            }
        },
        {
            t = "Label",
            base = {
                name = "save_label",
                text = "手动保存",
                fontinfo = "ui_normal_button",
                size = 18,
                parent = "save_button"
            },
            layout = {
                position = ccp(65, 22)
            },
            config = {
                color = ccc3(235, 223, 207),
                shadow = {
                    color = ccc3(0, 0, 0),
                    offset = ccp(0, 2)
                }
            }
        },
        {
            t = "Scale9Sprite",
            base = {
                name = "export_button",
                res = "UI/alpha/HVGA/sell_number_button.png",
                capInsets = CCRectMake(15, 22, 15, 25)
            },
            layout = {
                position = ccp(520, 78)
            },
            config = {
                scaleSize = CCSizeMake(130, 45)
            }
        },
        {
            t = "Scale9Sprite",
            base = {
                name = "export_button_press",
                res = "UI/alpha/HVGA/sell_number_button_down.png",
                capInsets = CCRectMake(15, 22, 15, 25),
                parent = "export_button"
            },
            layout = {
                anchor = ccp(0, 0),
                position = ccp(0, 0)
            },
            config = {
                scaleSize = CCSizeMake(130, 45),
                visible = false
            }
        },
        {
            t = "Label",
            base = {
                name = "export_label",
                text = "导出存档",
                fontinfo = "ui_normal_button",
                size = 18,
                parent = "export_button"
            },
            layout = {
                position = ccp(65, 22)
            },
            config = {
                color = ccc3(235, 223, 207),
                shadow = {
                    color = ccc3(0, 0, 0),
                    offset = ccp(0, 2)
                }
            }
        },
        {
            t = "Scale9Sprite",
            base = {
                name = "import_button",
                res = "UI/alpha/HVGA/sell_number_button.png",
                capInsets = CCRectMake(15, 22, 15, 25)
            },
            layout = {
                position = ccp(660, 78)
            },
            config = {
                scaleSize = CCSizeMake(130, 45)
            }
        },
        {
            t = "Scale9Sprite",
            base = {
                name = "import_button_press",
                res = "UI/alpha/HVGA/sell_number_button_down.png",
                capInsets = CCRectMake(15, 22, 15, 25),
                parent = "import_button"
            },
            layout = {
                anchor = ccp(0, 0),
                position = ccp(0, 0)
            },
            config = {
                scaleSize = CCSizeMake(130, 45),
                visible = false
            }
        },
        {
            t = "Label",
            base = {
                name = "import_label",
                text = "导入存档",
                fontinfo = "ui_normal_button",
                size = 18,
                parent = "import_button"
            },
            layout = {
                position = ccp(65, 22)
            },
            config = {
                color = ccc3(235, 223, 207),
                shadow = {
                    color = ccc3(0, 0, 0),
                    offset = ccp(0, 2)
                }
            }
        }
    }
    readnode:addNode(ui_info)

    local snapshots = readSaveIndex()
    local listHeight = math.max(#snapshots * 90, 200)
    local listContainer = CCLayer:create()
    listContainer:setContentSize(CCSizeMake(520, listHeight))
    for i, snap in ipairs(snapshots) do
        createSnapshotRow(snap, i, listContainer, listHeight - (i - 1) * 90)
    end
    if #snapshots == 0 then
        local emptyLabel = ed.createttf("暂无存档记录", 18)
        emptyLabel:setPosition(ccp(260, 100))
        ed.setLabelColor(emptyLabel, ccc3(180, 180, 180))
        listContainer:addChild(emptyLabel)
    end

    local dragInfo = {
        cliprect = CCRectMake(215, 100, 530, 360),
        container = container,
        zorder = 10,
        priority = -160,
        bar = {
            bglen = 340,
            bgpos = ccp(210, 280)
        }
    }
    self.draglist = ed.draglist.create(dragInfo)
    self.draglist:addItem(listContainer, CCSizeMake(520, listHeight))

    self.mainLayer:registerScriptTouchHandler(self:doMainLayerTouch(), false, -155, true)
end
class.createWindow = createWindow

local function create()
    local self = {}
    setmetatable(self, class.mt)
    local mainLayer = CCLayerColor:create(ccc4(0, 0, 0, 150))
    self.mainLayer = mainLayer
    mainLayer:setTouchEnabled(true)
    self:createWindow()
    self:show()
    return self
end
class.create = create

local function show(self)
    local container = self.container
    container:setScale(0)
    local s = CCScaleTo:create(0.2, 1)
    s = CCEaseBackOut:create(s)
    container:runAction(s)
end
class.show = show

local function destroy(self)
    local container = self.container
    local s = CCScaleTo:create(0.2, 0)
    s = CCEaseBackIn:create(s)
    local f = CCCallFunc:create(function()
        xpcall(function()
            self.mainLayer:removeFromParentAndCleanup(true)
        end, EDDebug)
    end)
    s = CCSequence:createWithTwoActions(s, f)
    container:runAction(s)
end
class.destroy = destroy

local function doMainLayerTouch(self)
    local ui = self.ui
    local function handler(event, x, y)
        if tolua.isnull(ui.frame) then
            return true
        end
        if event == "began" then
            if ed.containsPoint(ui.close, x, y) then
                ui.close_press:setVisible(true)
                return true
            end
            if ui.save_button and ed.containsPoint(ui.save_button, x, y) then
                ui.save_button_press:setVisible(true)
                return true
            end
            if ui.export_button and ed.containsPoint(ui.export_button, x, y) then
                ui.export_button_press:setVisible(true)
                return true
            end
            if ui.import_button and ed.containsPoint(ui.import_button, x, y) then
                ui.import_button_press:setVisible(true)
                return true
            end
            if not ed.containsPoint(ui.frame, x, y) then
                self:destroy()
                return true
            end
        elseif event == "ended" then
            if ui.close_press then ui.close_press:setVisible(false) end
            if ui.save_button_press then ui.save_button_press:setVisible(false) end
            if ui.export_button_press then ui.export_button_press:setVisible(false) end
            if ui.import_button_press then ui.import_button_press:setVisible(false) end
            if ed.containsPoint(ui.close, x, y) then
                self:destroy()
            elseif ui.save_button and ed.containsPoint(ui.save_button, x, y) then
                self:doManualSave()
            elseif ui.export_button and ed.containsPoint(ui.export_button, x, y) then
                self:doExportSave()
            elseif ui.import_button and ed.containsPoint(ui.import_button, x, y) then
                self:doImportSave()
            end
        end
        return true
    end
    return handler
end
class.doMainLayerTouch = doMainLayerTouch
