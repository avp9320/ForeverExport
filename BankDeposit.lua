-- Optional bank helper for ForeverExport.
-- Manual click only; no change to character report/export.
local bankOpen = false
local button
local busy = false
local epoch = 0
local function message(s)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverExport:|r " .. s)
    end
end
local function numSlots(bag)
    local fn = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    if type(fn) ~= "function" then return 0 end
    local ok, n = pcall(fn, bag)
    return ok and type(n) == "number" and math.max(0, math.min(n, 80)) or 0
end
local function itemID(bag, slot)
    local fn = C_Container and C_Container.GetContainerItemID or GetContainerItemID
    if type(fn) == "function" then
        local ok, id = pcall(fn, bag, slot)
        if ok and type(id) == "number" then return id end
    end
    local linkFn = C_Container and C_Container.GetContainerItemLink or GetContainerItemLink
    if type(linkFn) == "function" then
        local ok, link = pcall(linkFn, bag, slot)
        if ok and type(link) == "string" then
            return tonumber(link:match("item:(%d+)"))
        end
    end
end
local function isReagent(id)
    if not id then return false end
    local class
    if type(GetItemInfoInstant) == "function" then
        local ok, _, _, _, _, _, c = pcall(GetItemInfoInstant, id)
        if ok then class = c end
    end
    if type(class) ~= "number" and type(GetItemInfo) == "function" then
        local ok, c = pcall(function() return select(12, GetItemInfo(id)) end)
        if ok then class = c end
    end
    -- The item class is the sixth return of GetItemInfoInstant, not fifth.
    -- Some Forever builds use a string category from GetItemInfo instead.
    if class == 7 then return true end
    if type(GetItemInfo) == "function" then
        local ok, kind = pcall(function() return select(6, GetItemInfo(id)) end)
        if ok and (kind == "Trade Goods" or kind == "Tradeskills") then return true end
    end
    return false
end
local function bankVisible()
    return bankOpen and BankFrame and BankFrame.IsShown and BankFrame:IsShown()
end
local function deposit()
    if busy then return end
    if not bankVisible() then
        message("Open your personal bank first.")
        return
    end
    local use = C_Container and C_Container.UseContainerItem or UseContainerItem
    if type(use) ~= "function" or not (C_Timer and type(C_Timer.After) == "function") then
        message("This client does not expose the required bag APIs.")
        return
    end
    local items = {}
    for bag = 0, 4 do
        for slot = 1, numSlots(bag) do
            local id = itemID(bag, slot)
            if isReagent(id) then
                items[#items + 1] = {bag, slot, id}
            end
        end
    end
    if #items == 0 then message("No recognized crafting materials in your bags."); return end
    busy = true
    epoch = epoch + 1
    local token, i, attempted = epoch, 1, 0
    local function step()
        if token ~= epoch or not bankVisible() then
            busy = false
            return
        end
        if i > #items then
            busy = false
            message("Deposit pass finished (" .. attempted .. " stacks attempted). Check your bank for any items that could not fit.")
            return
        end
        local entry = items[i]
        i = i + 1
        -- Revalidate each slot as earlier transfers may alter bag contents.
        if itemID(entry[1], entry[2]) == entry[3] then
            local ok = pcall(use, entry[1], entry[2])
            if ok then attempted = attempted + 1 end
        end
        C_Timer.After(0.12, step)
    end
    step()
end
local function showButton()
    if not BankFrame or type(CreateFrame) ~= "function" then return end
    if not button then
        button = CreateFrame("Button", "ForeverExportDepositReagents", BankFrame, "UIPanelButtonTemplate")
        button:SetSize(136, 23)
        button:SetPoint("TOPLEFT", BankFrame, "TOPLEFT", 187, -59)
        button:SetText("Deposit Reagents")
        button:SetScript("OnClick", deposit)
        button:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Deposit crafting materials", 1, 1, 1)
            GameTooltip:AddLine("Moves Trade Goods from your carried bags into your personal bank when possible. Click only when you want to deposit.", nil, nil, nil, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)
    end
    button:Show()
end
if type(CreateFrame) == "function" then
    local listener = CreateFrame("Frame")
    listener:RegisterEvent("BANKFRAME_OPENED")
    listener:RegisterEvent("BANKFRAME_CLOSED")
    listener:SetScript("OnEvent", function(_, event)
        if event == "BANKFRAME_OPENED" then
            bankOpen = true
            showButton()
        else
            bankOpen = false
            epoch = epoch + 1
            busy = false
            if button then button:Hide() end
        end
    end)
end
