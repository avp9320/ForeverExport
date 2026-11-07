-- Manual, one-click crafting-reagent deposit for the personal bank.
-- Let the Forever client decide what counts as a "Crafting Reagent":
-- C_Bank.AutoDepositItemsIntoBank(Character) is the native reagent deposit action.
-- This avoids guessing trade-goods categories or using protected, delayed item clicks.
local bankOpen = false
local button

local function message(s)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverExport:|r " .. s)
    end
end

local function bankVisible()
    return bankOpen and BankFrame and type(BankFrame.IsShown) == "function"
        and BankFrame:IsShown()
end

local function deposit()
    if not bankVisible() then
        message("Open your personal bank first.")
        return
    end

    local autoDeposit = C_Bank and C_Bank.AutoDepositItemsIntoBank
    if type(autoDeposit) ~= "function" then
        message("This client does not expose the built-in reagent deposit action.")
        return
    end

    local characterBank = Enum and Enum.BankType and Enum.BankType.Character or 0
    -- Run only as a direct button click. The game handles which carried items
    -- have the Crafting Reagent tag and whether the bank has room.
    local ok = pcall(autoDeposit, characterBank)
    if not ok then
        message("The game blocked the reagent deposit action.")
    else
        message("Reagent deposit requested. Check your bank for any items that could not fit.")
    end
end

local function showButton()
    if not BankFrame or type(CreateFrame) ~= "function" then return end
    if not button then
        button = CreateFrame("Button", "ForeverExportDepositReagents", BankFrame, "UIPanelButtonTemplate")
        button:SetSize(136, 23)
        -- The bottom-right footer is clear of the bank item grid and the search box.
        -- In Forever's bank layout this sits to the right of Purchase, above the money bar.
        button:SetPoint("BOTTOMRIGHT", BankFrame, "BOTTOMRIGHT", -24, 49)
        button:SetText("Deposit Reagents")
        button:SetScript("OnClick", deposit)
        button:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Deposit Crafting Reagents", 1, 1, 1)
            GameTooltip:AddLine("Uses the game's built-in function to move crafting reagents from your carried bags into your personal bank, when there is room.", nil, nil, nil, true)
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
            if button then button:Hide() end
        end
    end)
end
