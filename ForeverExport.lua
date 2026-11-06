-- Forever Export: independent character report tool for World of Warcraft: Forever.
-- No networking, no external dependencies, and no automatic uploads.
-- Based on the manually copyable report from ForeverQuest's Export.lua.
local addonName = ...
local Export = {}
_G.ForeverExport = Export

local function safeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f = pcall(fn, ...)
    if ok then return a, b, c, d, e, f end
end

local function isSecret(value)
    if value == nil then return false end
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if ok and secret then return true end
    end
    return false
end

local function clean(value)
    if value == nil then return "unknown" end
    if isSecret(value) then return "<restricted>" end
    local ok, text = pcall(function()
        local s = tostring(value)
        s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        return s:gsub("[\r\n\t]", " "):gsub("%s+", " ")
    end)
    return ok and text or "<restricted>"
end

local function valid(value, kind)
    return not isSecret(value) and type(value) == kind
end

local function itemName(link)
    if not valid(link, "string") then return nil end
    local ok, name = pcall(function() return link:match("%[([^%]]+)%]") end)
    return ok and name or clean(link)
end

local function characterKey()
    local guid = safeCall(UnitGUID, "player")
    if valid(guid, "string") and guid ~= "" then return guid end
    return clean(safeCall(UnitName, "player")) .. "-" .. clean(safeCall(GetRealmName))
end

local function append(lines, line)
    lines[#lines+1] = line
end

local function moneyText(copper)
    if not valid(copper, "number") then return "unknown" end
    copper = math.max(0, math.floor(copper))
    return string.format("%dg %ds %dc", math.floor(copper / 10000),
        math.floor(copper / 100) % 100, copper % 100)
end

local function addCharacter(lines)
    local name = safeCall(UnitName, "player") or "Unknown"
    local race = safeCall(UnitRace, "player") or "Unknown"
    local class = safeCall(UnitClass, "player") or "Unknown"
    local level = safeCall(UnitLevel, "player")
    local realm = safeCall(GetRealmName) or "Unknown"
    append(lines, "Character: " .. clean(name) .. " - " .. clean(race)
        .. " " .. clean(class) .. " (level " .. clean(level) .. ")")
    append(lines, "Realm: " .. clean(realm))
    local xp, maxXP = safeCall(UnitXP, "player"), safeCall(UnitXPMax, "player")
    if valid(xp, "number") and valid(maxXP, "number") and maxXP > 0 then
        append(lines, string.format("XP: %d / %d", xp, maxXP))
    end
    append(lines, "Money: " .. moneyText(safeCall(GetMoney)))
    local zone = safeCall(GetZoneText) or "Unknown"
    local subzone = safeCall(GetSubZoneText)
    local location = clean(zone)
    if valid(subzone, "string") and subzone ~= "" and subzone ~= zone then
        location = location .. " / " .. clean(subzone)
    end
    local mapID = safeCall(C_Map and C_Map.GetBestMapForUnit, "player")
    if valid(mapID, "number") then
        location = location .. " (map " .. tostring(mapID) .. ")"
        local position = safeCall(C_Map and C_Map.GetPlayerMapPosition, mapID, "player")
        if position and not isSecret(position) then
            local x, y = safeCall(position.GetXY, position)
            if valid(x, "number") and valid(y, "number") then
                location = location .. string.format(" %.1f, %.1f", x * 100, y * 100)
            end
        end
    end
    append(lines, "Location: " .. location)
end

local EQUIPMENT_SLOTS = {
    {16, "Main hand"}, {17, "Off hand"},
    {1, "Head"}, {2, "Neck"}, {3, "Shoulder"},
    {5, "Chest"}, {6, "Waist"}, {7, "Legs"},
    {8, "Feet"}, {9, "Wrist"}, {10, "Hands"},
    {11, "Ring 1"}, {12, "Ring 2"},
    {13, "Trinket 1"}, {14, "Trinket 2"},
    {15, "Back"}, {18, "Ranged"},
}

local function addEquipment(lines)
    append(lines, "")
    append(lines, "EQUIPMENT")
    local found = 0
    for _, slot in ipairs(EQUIPMENT_SLOTS) do
        local link = safeCall(GetInventoryItemLink, "player", slot[1])
        local name = itemName(link)
        if name then
            append(lines, slot[2] .. ": " .. clean(name))
            found = found + 1
        end
    end
    if found == 0 then append(lines, "(none found or equipment API unavailable)") end
end

local function addProfessions(lines)
    append(lines, "")
    append(lines, "PROFESSIONS")
    local found = 0
    -- GetProfessions returns up to six slot indices with possible nil gaps.
    -- ipairs({GetProfessions()}) silently skips everything after the first gap.
    local a,b,c,d,e,f = safeCall(GetProfessions)
    local indices = {a,b,c,d,e,f}
    for slot = 1, 6 do
        local index = indices[slot]
        if valid(index, "number") and index > 0 then
            local name, _, skill, maxSkill = safeCall(GetProfessionInfo, index)
            if valid(name, "string") and name ~= "" then
                local suffix = ""
                if valid(skill, "number") then
                    suffix = " " .. tostring(skill)
                    if valid(maxSkill, "number") then
                        suffix = suffix .. "/" .. tostring(maxSkill)
                    end
                end
                append(lines, clean(name) .. suffix)
                found = found + 1
            end
        end
    end
    if found == 0 then append(lines, "(none known or API unavailable)") end
end

local function addQuests(lines)
    append(lines, "")
    append(lines, "ACTIVE QUESTS (live quest log)")
    local api = C_QuestLog
    if not api or type(api.GetNumQuestLogEntries) ~= "function"
        or type(api.GetInfo) ~= "function" then
        append(lines, "(quest log API unavailable)")
        return
    end
    local entries = safeCall(api.GetNumQuestLogEntries)
    if not valid(entries, "number") then
        append(lines, "(quest log unavailable)")
        return
    end
    local found = 0
    for i = 1, math.min(entries, 200) do
        local info = safeCall(api.GetInfo, i)
        if type(info) == "table" and not isSecret(info)
            and not info.isHeader and not info.isHidden then
            local id = info.questID
            if valid(id, "number") and id > 0 then
                found = found + 1
                local title = valid(info.title, "string") and info.title
                    or safeCall(api.GetTitleForQuestID, id) or ("Quest " .. id)
                local complete = safeCall(api.IsComplete, id) == true
                local level = valid(info.level, "number")
                    and ("L" .. tostring(info.level) .. " ") or ""
                append(lines, string.format("- [%d] %s%s%s", id, level,
                    clean(title), complete and " [READY TO TURN IN]" or ""))
                local objectives = safeCall(api.GetQuestObjectives, id)
                if type(objectives) == "table" and not isSecret(objectives) then
                    for _, objective in ipairs(objectives) do
                        if type(objective) == "table" and not isSecret(objective) then
                            local description = objective.text or objective.description
                            if valid(description, "string") and description ~= "" then
                                local done = objective.finished == true
                                    or objective.isFinished == true
                                append(lines, "    " .. (done and "[done] " or "[ ] ")
                                    .. clean(description))
                            end
                        end
                    end
                end
            end
        end
    end
    if found == 0 then append(lines, "(quest log empty)") end
end

local function copyLegacyRecent(db)
    -- Migration is per character: importing one alt should not prevent the
    -- next alt's history from transferring when that character logs in.
    db.legacyImportedByCharacter = db.legacyImportedByCharacter or {}
    local key = characterKey()
    if db.legacyImportedByCharacter[key] then return end
    local old = _G.ForeverQuestDB
    if type(old) == "table" and type(old.exportRecentTurnins) == "table" then
        local previous = old.exportRecentTurnins[key]
        if type(previous) == "table" and #previous > 0 then
            local current = db.recentTurnins[key] or {}
            local seen = {}
            for _, record in ipairs(current) do
                if type(record) == "table" and valid(record.id,"number") then
                    seen[record.id] = true
                end
            end
            for _, record in ipairs(previous) do
                if type(record) == "table" and valid(record.id, "number")
                    and not seen[record.id] then
                    current[#current+1] = {id=record.id, title=clean(record.title)}
                    seen[record.id] = true
                end
                if #current >= 20 then break end
            end
            db.recentTurnins[key] = current
        end
        db.legacyImportedByCharacter[key] = true
    end
end

local function getDB()
    ForeverExportDB = ForeverExportDB or {}
    ForeverExportDB.recentTurnins = ForeverExportDB.recentTurnins or {}
    copyLegacyRecent(ForeverExportDB)
    return ForeverExportDB
end

local function addRecentTurnins(lines)
    append(lines, "")
    append(lines, "RECENT TURN-INS (recorded while this exporter was installed)")
    local db = getDB()
    local recent = db.recentTurnins[characterKey()]
    if type(recent) ~= "table" or #recent == 0 then
        append(lines, "(none recorded yet)")
        return
    end
    for _, entry in ipairs(recent) do
        if type(entry) == "table" and valid(entry.id, "number") then
            append(lines, string.format("- [%d] %s", entry.id, clean(entry.title)))
        end
    end
end

local function addBags(lines)
    append(lines, "")
    append(lines, "BAGS")
    local grouped, order = {}, {}
    local found = 0
    for bag = 0, 4 do
        local slots = safeCall(C_Container and C_Container.GetContainerNumSlots, bag)
        if not valid(slots, "number") then slots = safeCall(GetContainerNumSlots, bag) end
        slots = valid(slots, "number") and math.min(tonumber(slots), 80) or 0
        for slot = 1, slots do
            local link = safeCall(C_Container and C_Container.GetContainerItemLink, bag, slot)
                or safeCall(GetContainerItemLink, bag, slot)
            local name = itemName(link)
            if name then
                local item = safeCall(C_Container and C_Container.GetContainerItemInfo, bag, slot)
                local count = type(item) == "table" and not isSecret(item)
                    and item.stackCount or nil
                if not valid(count, "number") then
                    local _, legacy = safeCall(GetContainerItemInfo, bag, slot)
                    count = legacy
                end
                count = valid(count, "number") and math.max(1, count) or 1
                name = clean(name)
                if not grouped[name] then
                    grouped[name] = 0
                    order[#order + 1] = name
                end
                grouped[name] = grouped[name] + count
                found = found + 1
            end
        end
    end
    table.sort(order)
    for _, name in ipairs(order) do
        append(lines, "- " .. name .. " x" .. tostring(grouped[name]))
    end
    if found == 0 then append(lines, "(no bag items found or API unavailable)") end
end

function Export.BuildReport()
    getDB()
    local lines = {"FOREVER CHARACTER REPORT v2", "Manual export - no automatic sharing"}
    addCharacter(lines)
    addEquipment(lines)
    addProfessions(lines)
    addQuests(lines)
    addRecentTurnins(lines)
    addBags(lines)
    return table.concat(lines, "\n")
end

local window, editBox
function Export.Open()
    if not UIParent or type(CreateFrame) ~= "function" then return end
    if not window then
        window = CreateFrame("Frame", "ForeverExportWindow", UIParent)
        window:SetSize(720, 480)
        window:SetPoint("CENTER")
        window:SetFrameStrata("DIALOG")
        window:SetMovable(true)
        window:EnableMouse(true)
        window:RegisterForDrag("LeftButton")
        window:SetScript("OnDragStart", function(self) self:StartMoving() end)
        window:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        local backdrop = window:CreateTexture(nil, "BACKGROUND")
        backdrop:SetAllPoints(window)
        backdrop:SetColorTexture(0.06, 0.07, 0.09, 0.97)
        local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 18, -16)
        title:SetText("Forever Export - Character Report")
        local hint = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", 18, -40)
        hint:SetText("Press Ctrl+C to copy this report, then paste it where you want.")
        local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
        close:SetScript("OnClick", function() window:Hide() end)
        local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 18, -67)
        scroll:SetPoint("BOTTOMRIGHT", -33, 50)
        editBox = CreateFrame("EditBox", nil, scroll)
        editBox:SetFontObject(ChatFontNormal)
        editBox:SetMultiLine(true)
        editBox:SetMaxLetters(0)
        editBox:SetAutoFocus(false)
        editBox:SetWidth(655)
        editBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            window:Hide()
        end)
        scroll:SetScrollChild(editBox)
        local selectButton = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        selectButton:SetSize(110, 24)
        selectButton:SetPoint("BOTTOMLEFT", 18, 14)
        selectButton:SetText("Select all")
        selectButton:SetScript("OnClick", function()
            editBox:SetFocus()
            editBox:HighlightText()
        end)
        local refreshButton = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        refreshButton:SetSize(110, 24)
        refreshButton:SetPoint("LEFT", selectButton, "RIGHT", 10, 0)
        refreshButton:SetText("Refresh report")
        refreshButton:SetScript("OnClick", function() Export.Open() end)
    end
    local report = Export.BuildReport()
    editBox:SetText(report)
    local _, newlines = report:gsub("\n", "\n")
    editBox:SetHeight(math.max(350, (newlines + 2) * 16))
    window:Show()
    editBox:SetFocus()
    editBox:HighlightText()
end

SLASH_FOREVEREXPORT1 = "/fexport"
SLASH_FOREVEREXPORT2 = "/foreverexport"
SlashCmdList.FOREVEREXPORT = function() Export.Open() end

-- Record only turn-ins observed after installation. SavedVariables are scoped
-- to this addon and will persist even when ForeverQuest is disabled.
if type(CreateFrame) == "function" then
    local observer = CreateFrame("Frame")
    pcall(observer.RegisterEvent, observer, "QUEST_TURNED_IN")
    observer:SetScript("OnEvent", function(_, _, questID)
        if not valid(questID, "number") or questID <= 0 then return end
        local db = getDB()
        local key = characterKey()
        local entries = db.recentTurnins[key] or {}
        db.recentTurnins[key] = entries
        local title = safeCall(C_QuestLog and C_QuestLog.GetTitleForQuestID,
            questID) or ("Quest " .. questID)
        for i = #entries, 1, -1 do
            if entries[i].id == questID then table.remove(entries, i) end
        end
        table.insert(entries, 1, {id=questID, title=clean(title)})
        while #entries > 20 do table.remove(entries) end
    end)
end
