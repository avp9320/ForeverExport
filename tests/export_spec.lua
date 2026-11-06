-- Standalone /fexport data smoke test (Lua 5.1).
local messages = {}
local observer
CreateFrame = function()
    local frame = {}
    function frame:RegisterEvent(event) self.event = event end
    function frame:SetScript(name, fn) self[name] = fn end
    observer = frame
    return frame
end
SlashCmdList = {}
UnitGUID = function() return "Player-test-export" end
UnitName = function() return "GumbusJr" end
UnitRace = function() return "Orc" end
UnitClass = function() return "Warrior" end
UnitLevel = function() return 7 end
UnitXP = function() return 1991 end
UnitXPMax = function() return 4500 end
GetRealmName = function() return "Forever" end
GetMoney = function() return 206 end
GetZoneText = function() return "Durotar" end
GetSubZoneText = function() return "Razor Hill" end
GetInventoryItemLink = function(_, slot)
    if slot == 16 then return "|cff1eff00|Hitem:123:0|h[Large Axe]|h|r" end
end
GetProfessions = function() return 1 end
GetProfessionInfo = function() return "Mining", nil, 20, 75 end
C_Map = {
    GetBestMapForUnit = function() return 1411 end,
    GetPlayerMapPosition = function()
        return {GetXY=function() return 0.522, 0.431 end}
    end,
}
C_QuestLog = {
    GetNumQuestLogEntries = function() return 2 end,
    GetInfo = function(index)
        if index == 1 then return {isHeader=true, title="Durotar"} end
        return {questID=1234, title="Testing Export", level=8}
    end,
    GetQuestObjectives = function()
        return {
            {text="2/4 Enemies slain", finished=false},
            {text="1/1 Item collected", finished=true},
        }
    end,
    IsComplete = function() return false end,
    GetTitleForQuestID = function(id) return "Turned In " .. id end,
}
C_Container = {
    GetContainerNumSlots = function(bag)
        if bag == 0 then return 1 end
        return 0
    end,
    GetContainerItemLink = function()
        return "|cff1eff00|Hitem:88:0|h[Mining Pick]|h|r"
    end,
    GetContainerItemInfo = function() return {stackCount=1} end,
}
-- Simulate the live Classic-style talent API from the Forever client.
GetNumTalentTabs = function() return 3 end
GetTalentTabInfo = function(tab)
    return ({"Arms", "Fury", "Protection"})[tab]
end
GetNumTalents = function(tab) return tab == 1 and 4 or 0 end
GetTalentInfo = function(tab, index)
    if tab ~= 1 then return nil end
    local talents = {
        {"Improved Heroic Strike", 2, 3},
        {"Deflection", 0, 5},
        {"Improved Rend", 3, 3},
        {"Improved Overpower", 2, 2}
    }
    local talent = talents[index]
    return talent[1], 0, 1, index, talent[2], talent[3]
end
GetUnspentTalentPoints = function() return 0 end
ForeverExportDB = {}
dofile("ForeverExport.lua")
local exp = _G.ForeverExport
assert(type(SlashCmdList.FOREVEREXPORT) == "function", "export slash command")
assert(SLASH_FOREVEREXPORT1 == "/fexport", "standalone short command")
assert(SLASH_FOREVEREXPORT2 == "/foreverexport", "standalone long command")
assert(_G.ForeverQuestExport == nil, "no old exporter dependency")
local report = exp.BuildReport()
assert(report:find("GumbusJr - Orc Warrior (level 7)",1,true), "identity")
assert(report:find("1991 / 4500",1,true), "xp")
assert(report:find("Razor Hill",1,true), "zone")
assert(report:find("52.2, 43.1",1,true), "position")
assert(report:find("Large Axe",1,true), "equipped weapon")
assert(report:find("Mining 20/75",1,true), "profession skill")
assert(report:find("TALENTS (live character build)",1,true), "talent section")
assert(report:find("Arms: 7 points",1,true), "tree total")
assert(report:find("Improved Heroic Strike: 2/3",1,true), "spent talent rank")
assert(report:find("Improved Rend: 3/3",1,true), "rend talent rank")
assert(report:find("Improved Overpower: 2/2",1,true), "overpower talent rank")
assert(not report:find("Deflection: 0/5",1,true), "skip empty talents")
assert(report:find("Fury: 0 points",1,true), "empty trees still visible")
assert(report:find("Unspent talent points: 0",1,true), "unspent native total")
assert(report:find("[1234] L8 Testing Export",1,true), "quest ID and title")
assert(report:find("[ ] 2/4 Enemies slain",1,true), "unfinished objective")
assert(report:find("[done] 1/1 Item collected",1,true), "finished objective")
assert(report:find("Mining Pick x1",1,true), "bag inventory")
assert(observer.event == "QUEST_TURNED_IN", "turnin observer")
observer.OnEvent(observer, "QUEST_TURNED_IN", 9876)
report = exp.BuildReport()
assert(report:find("[9876] Turned In 9876",1,true), "recent completed quest")
-- Second profession slot after a nil gap must still appear.
GetProfessions = function() return nil, 8, nil, 10 end
GetProfessionInfo = function(index)
    if index == 8 then return "Blacksmithing", nil, 65, 150 end
    if index == 10 then return "Cooking", nil, 40, 75 end
end
report = exp.BuildReport()
assert(report:find("Blacksmithing 65/150",1,true), "sparse profession slot")
assert(report:find("Cooking 40/75",1,true), "profession slot after another nil")

-- Legacy migration works without ForeverQuest's addon code.
ForeverQuestDB={exportRecentTurnins={["Player-test-export"]={
    {id=9988,title="An Old Turn-in"}
}}}
report=exp.BuildReport()
assert(report:find("[9988] An Old Turn-in",1,true), "legacy turn-in imported")
assert(ForeverExportDB.recentTurnins["Player-test-export"], "own persistent DB")
-- Once imported, no later duplicates when the report is opened repeatedly.
report=exp.BuildReport()
local first=report:find("[9988] An Old Turn-in",1,true)
assert(not report:find("[9988] An Old Turn-in",first+1,true), "migration deduplicated")
-- Unsupported talent APIs must not break the character report.
GetNumTalentTabs = nil
report=exp.BuildReport()
assert(report:find("(talent API unavailable)",1,true),
    "graceful talent API fallback")
assert(report:find("ACTIVE QUESTS",1,true),
    "quest reporting survives missing talent API")
print("ForeverExport standalone smoke test passed")
