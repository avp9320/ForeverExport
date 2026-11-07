-- Native Forever personal-bank reagent deposit smoke test.
-- The game owns matching the "Crafting Reagent" tag and moving bag items.
local messages, deposits = {}, {}
local bankIsOpen = true
BankFrame = {IsShown = function() return bankIsOpen end}
DEFAULT_CHAT_FRAME = {AddMessage = function(_, msg) messages[#messages+1] = msg end}
local listener, button
CreateFrame = function(kind)
    local f = {}
    function f:RegisterEvent(event) self.events = self.events or {}; self.events[event] = true end
    function f:SetScript(event, callback) self[event] = callback end
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:SetPoint(...) self.point = {...} end
    function f:SetText(text) self.text = text end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    if kind == "Button" then button = f else listener = f end
    return f
end
Enum = {BankType = {Character = 0, Account = 2}}
C_Bank = {AutoDepositItemsIntoBank = function(bankType)
    deposits[#deposits + 1] = bankType
end}
-- Any manual container scanning or delayed item movement is a regression.
C_Container = setmetatable({}, {__index = function(_, name)
    error("Unexpected manual bag operation: "..name)
end})
C_Timer = {After = function() error("Unexpected delayed deposit") end}
dofile("BankDeposit.lua")
assert(listener.events.BANKFRAME_OPENED and listener.events.BANKFRAME_CLOSED, "bank events")
listener.OnEvent(listener, "BANKFRAME_OPENED")
assert(button and button.shown and button.text == "Deposit Reagents", "bank button appears")
assert(button.point[1] == "BOTTOMRIGHT" and button.point[2] == BankFrame
    and button.point[3] == "BOTTOMRIGHT", "button in bank footer")
assert(button.point[4] == -24 and button.point[5] == 49, "button clear of grid and purchase")
button.OnClick()
assert(#deposits == 1 and deposits[1] == Enum.BankType.Character,
    "delegates exact native crafting-reagent action to personal bank")
assert(messages[#messages]:find("requested", 1, true), "no false claim of successful transfer")
C_Bank.AutoDepositItemsIntoBank = function() error("blocked") end
button.OnClick()
assert(#deposits == 1, "blocked action does not report another deposit")
assert(messages[#messages]:find("blocked", 1, true), "failure message")
C_Bank.AutoDepositItemsIntoBank = nil
button.OnClick()
assert(messages[#messages]:find("does not expose", 1, true), "missing API message")
bankIsOpen = false
listener.OnEvent(listener, "BANKFRAME_CLOSED")
assert(not button.shown, "button hides with bank")
button.OnClick()
assert(messages[#messages]:find("Open your personal bank", 1, true), "bank must be open")
print("ForeverExport native reagent deposit smoke test passed")
