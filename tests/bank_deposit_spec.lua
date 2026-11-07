-- Manual deposit button smoke test. No bank inventory is scanned.
local messages, scanned, used = {}, {}, {}
local bankIsOpen = true
BankFrame = {IsShown = function() return bankIsOpen end}
DEFAULT_CHAT_FRAME = {AddMessage = function(_, msg) messages[#messages+1] = msg end}
local listener, button
CreateFrame = function(kind, name, parent)
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
local carriedID = 101
C_Container = {
    GetContainerNumSlots = function(bag)
        assert(bag >= 0 and bag <= 4, "scanned non-carried bank bag")
        scanned[#scanned+1] = bag
        return bag == 0 and 1 or 0
    end,
    GetContainerItemID = function(bag, slot)
        assert(bag == 0 and slot == 1, "wrong bag item")
        return carriedID
    end,
    UseContainerItem = function(bag, slot) used[#used+1] = {bag, slot} end,
}
GetItemInfoInstant = function(id)
    return id, nil, nil, nil, nil, (id == 101 and 7 or 2)
end
C_Timer = {After = function(_, callback) callback() end}
dofile("BankDeposit.lua")
assert(listener.events.BANKFRAME_OPENED and listener.events.BANKFRAME_CLOSED, "bank events registered")
listener.OnEvent(listener, "BANKFRAME_OPENED")
assert(button and button.shown and button.text == "Deposit Reagents", "button visible")
assert(button.point[1] == "TOPRIGHT" and button.point[2] == BankFrame
    and button.point[3] == "TOPRIGHT", "button anchored to bank header")
assert(button.point[4] < 0 and button.point[5] < 0, "header inset")
button.OnClick()
assert(#used == 1 and used[1][1] == 0 and used[1][2] == 1, "deposits carried trade goods")
assert(#scanned == 5, "scans carried bags 0-4 only")
carriedID = 222
button.OnClick()
assert(#used == 1, "does not deposit a non-crafting item")
assert(messages[#messages]:find("No recognized crafting materials", 1, true), "clear empty message")
bankIsOpen = false
listener.OnEvent(listener, "BANKFRAME_CLOSED")
assert(not button.shown, "button hides on bank close")
print("ForeverExport carried-bag deposit smoke test passed")
