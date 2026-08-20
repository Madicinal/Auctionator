-- CoAuctionator +Mod 1.3
-- Creates the Buy Multiple entry point as a true sibling of the CoA fork's
-- native Atr_Buy1_Button.  The picker/purchase bridge remains in
-- AuctionatorBuyMultipleMod.lua and AuctionatorBuy.lua.

local button = nil;
local elapsedSinceUpdate = 0;

local function EnsureButton ()
    if (button) then
        return button;
    end

    if (not Atr_Buy1_Button or not Atr_Buy1_Button.GetParent) then
        return nil;
    end

    local parent = Atr_Buy1_Button:GetParent();
    if (not parent) then
        return nil;
    end

    button = CreateFrame ("Button", "CoAtr_BuyMultiple_Button", parent, "UIPanelButtonTemplate");
    button:SetWidth (105);
    button:SetHeight (22);
    button:ClearAllPoints();
    button:SetPoint ("RIGHT", Atr_Buy1_Button, "LEFT", -8, 0);
    button:SetText ("Buy Multiple");
    button:SetFrameLevel ((Atr_Buy1_Button:GetFrameLevel() or 1) + 1);
    button:SetScript ("OnClick", function ()
        if (Atr_Buy_Multiple_Start) then
            Atr_Buy_Multiple_Start();
        end
    end);

    button:SetScript ("OnEnter", function (self)
        GameTooltip:SetOwner (self, "ANCHOR_TOP");
        GameTooltip:SetText ("Buy Multiple");
        GameTooltip:AddLine ("Show the exact live auctions in the selected group and choose one to buy.", 1, 1, 1, true);
        GameTooltip:Show();
    end);
    button:SetScript ("OnLeave", function () GameTooltip:Hide(); end);

    button:Disable();
    button:Show();
    return button;
end

local controller = CreateFrame ("Frame");
controller:SetScript ("OnUpdate", function (self, elapsed)
    elapsedSinceUpdate = elapsedSinceUpdate + elapsed;
    if (elapsedSinceUpdate < 0.10) then
        return;
    end
    elapsedSinceUpdate = 0;

    local b = EnsureButton();
    if (not b or not Atr_Buy1_Button) then
        return;
    end

    -- Follow the exact same pane visibility as the native Buy button.
    if (Atr_Buy1_Button:IsShown()) then
        b:Show();
    else
        b:Hide();
        return;
    end

    -- Do not use data.count here.  In the CoA condensed scan that value is not
    -- a reliable test for whether multiple exact physical auctions exist.
    -- The upstream buy engine performs that live-row validation after click.
    local pane = Atr_GetCurrentPane and Atr_GetCurrentPane();
    local scan = pane and pane.activeScan;
    local data = scan and pane.currIndex and scan.sortedData and scan.sortedData[pane.currIndex];

    if (data and not data.yours and not data.altname and data.buyoutPrice and data.buyoutPrice > 0) then
        b:Enable();
    else
        b:Disable();
    end
end);
