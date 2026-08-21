-- CoAuctionator +Mod 1.8
-- Classic/original Auctionator presentation layer with strict tab isolation.

local textureBase = "Interface\\AddOns\\CoAuctionator\\Images\\";
local classicAdvancedButton = nil;
local elapsedSinceApply = 0;

local function ClearPanelBackdrop (panel)
    if (panel and panel.SetBackdrop) then
        panel:SetBackdrop (nil);
    end
end

local function SelectedTabInfo ()
    if (not AuctionFrame or not PanelTemplates_GetSelectedTab) then
        return nil, nil, false;
    end

    local index = PanelTemplates_GetSelectedTab (AuctionFrame);
    if (not index) then
        return nil, nil, false;
    end

    local tab = _G["AuctionFrameTab"..index];
    local isCustom = tab and tab.auctionatorTab ~= nil;
    return index, tab, isCustom and true or false;
end

local function IsBuyTab ()
    return Atr_IsModeBuy and Atr_IsModeBuy() and true or false;
end

local function HideLegacyBackdropIfPresent ()
    local oldBackdrop = _G["CoAtr_ClassicBackdrop"];
    if (oldBackdrop) then oldBackdrop:Hide(); end
end

local function HideBuyOnlyControls ()
    if (classicAdvancedButton) then classicAdvancedButton:Hide(); end
    if (Atr_Adv_Search_Button) then Atr_Adv_Search_Button:Hide(); end
    if (Atr_Exact_Search_Button) then Atr_Exact_Search_Button:Hide(); end
end

local function ShowClassicAuctionArt ()
    if (not AuctionFrame) then return; end

    HideLegacyBackdropIfPresent();

    local art = {
        {AuctionFrameTopLeft,  "atr_topleft"},
        {AuctionFrameTop,      "atr_top"},
        {AuctionFrameTopRight, "atr_topright"},
        {AuctionFrameBotLeft,  "atr_botleft"},
        {AuctionFrameBot,      "atr_bot"},
        {AuctionFrameBotRight, "atr_botright"},
    };

    local i;
    for i = 1, #art do
        local texture = art[i][1];
        if (texture) then
            texture:SetTexture (textureBase..art[i][2]);
            texture:SetAlpha (1);
            texture:Show();
        end
    end

    ClearPanelBackdrop (Atr_Panel_Sell);
    ClearPanelBackdrop (Atr_Panel_Buy);
    ClearPanelBackdrop (Atr_Panel_More);
    ClearPanelBackdrop (Atr_Panel_Inventory);
end

local function EnsureClassicAdvancedButton ()
    if (classicAdvancedButton) then return classicAdvancedButton; end
    if (not Atr_Search_Button or not Atr_Search_Button.GetParent) then return nil; end

    local parent = Atr_Search_Button:GetParent();
    if (not parent) then return nil; end

    classicAdvancedButton = CreateFrame ("Button", "CoAtr_AdvancedSearchButton", parent, "UIPanelButtonTemplate");
    classicAdvancedButton:SetWidth (24);
    classicAdvancedButton:SetHeight (18);
    classicAdvancedButton:SetText ("+");
    classicAdvancedButton:SetScript ("OnClick", function ()
        if (Atr_Adv_Search_Onclick) then Atr_Adv_Search_Onclick(); end
    end);
    classicAdvancedButton:SetScript ("OnEnter", function (self)
        GameTooltip:SetOwner (self, "ANCHOR_TOP");
        GameTooltip:SetText ("Advanced Search");
        GameTooltip:Show();
    end);
    classicAdvancedButton:SetScript ("OnLeave", function () GameTooltip:Hide(); end);
    return classicAdvancedButton;
end

local function ApplyCommonCustomGeometry ()
    if (Auctionator1Button) then
        Auctionator1Button:ClearAllPoints();
        Auctionator1Button:SetWidth (70);
        Auctionator1Button:SetHeight (18);
        Auctionator1Button:SetText ("Options");
        Auctionator1Button:SetPoint ("TOPRIGHT", AuctionFrame, "TOPRIGHT", -20, -42);
    end

    if (Atr_FullScanButton and Auctionator1Button) then
        Atr_FullScanButton:ClearAllPoints();
        Atr_FullScanButton:SetWidth (74);
        Atr_FullScanButton:SetHeight (18);
        Atr_FullScanButton:SetPoint ("RIGHT", Auctionator1Button, "LEFT", -8, 0);
    end
end

local function ApplyLegacyGeometry ()
    local _, _, isCustom = SelectedTabInfo();
    if (not isCustom) then
        HideBuyOnlyControls();
        return;
    end

    ApplyCommonCustomGeometry();

    -- Advanced search and Exact Match belong ONLY to the Buy tab.  Previous
    -- versions applied this block to every custom tab while another module hid
    -- the controls again, causing visible show/hide flicker several times/sec.
    if (not IsBuyTab()) then
        HideBuyOnlyControls();
        return;
    end

    if (not Atr_Search_Box or not Atr_Search_Button) then return; end

    Atr_Search_Box:ClearAllPoints();
    Atr_Search_Box:SetWidth (260);
    Atr_Search_Box:SetHeight (20);
    Atr_Search_Box:SetPoint ("TOPLEFT", Atr_Search_Box:GetParent(), "TOPLEFT", 20, -45);

    Atr_Search_Button:ClearAllPoints();
    Atr_Search_Button:SetWidth (80);
    Atr_Search_Button:SetHeight (22);
    Atr_Search_Button:SetPoint ("LEFT", Atr_Search_Box, "RIGHT", 15, 0);

    local adv = EnsureClassicAdvancedButton();
    if (adv) then
        adv:ClearAllPoints();
        adv:SetPoint ("LEFT", Atr_Search_Button, "RIGHT", 4, 0);
        adv:Show();
        if (Atr_Adv_Search_Button and Atr_Adv_Search_Button:IsEnabled()) then adv:Enable(); else adv:Disable(); end
    end

    -- The upstream Advanced checkbox remains hidden; the compact + button is the
    -- classic-shell presentation for the same dialog.
    if (Atr_Adv_Search_Button) then Atr_Adv_Search_Button:Hide(); end

    if (Atr_Exact_Search_Button and adv) then
        Atr_Exact_Search_Button:ClearAllPoints();
        Atr_Exact_Search_Button:SetPoint ("TOPLEFT", adv, "BOTTOMLEFT", 0, 2);
        Atr_Exact_Search_Button:Show();
    end
end

local function IsolateBlizzardTab ()
    HideLegacyBackdropIfPresent();
    HideBuyOnlyControls();

    if (Atr_Main_Panel) then Atr_Main_Panel:Hide(); end
    if (Atr_Panel_Sell) then Atr_Panel_Sell:Hide(); end
    if (Atr_Panel_Buy) then Atr_Panel_Buy:Hide(); end
    if (Atr_Panel_More) then Atr_Panel_More:Hide(); end
    if (Atr_Panel_Inventory) then Atr_Panel_Inventory:Hide(); end
    if (Atr_BagPanel) then Atr_BagPanel:Hide(); end
    if (Atr_InventoryFrame) then Atr_InventoryFrame:Hide(); end

    if (Atr_BuyMultiple_Frame and Atr_BuyMultiple_Frame:IsShown()) then
        Atr_BuyMultiple_Frame:Hide();
    end
end

-- The classic shell uses the six original Auctionator art tiles, so the CoA
-- panel system must not hide them on custom tabs.
function Atr_HideAHArt ()
end

function Atr_ApplyPanelSkin (frame)
    ClearPanelBackdrop (frame);
end

if (Atr_FixupButtons) then
    local upstreamFixupButtons = Atr_FixupButtons;
    Atr_FixupButtons = function (...)
        local result = upstreamFixupButtons (...);
        ApplyLegacyGeometry();
        return result;
    end;
end

local function ApplyForSelectedTab ()
    local _, _, isCustom = SelectedTabInfo();
    if (isCustom) then
        ShowClassicAuctionArt();
        ApplyLegacyGeometry();
    else
        IsolateBlizzardTab();
    end
end

local controller = CreateFrame ("Frame");
controller:RegisterEvent ("AUCTION_HOUSE_SHOW");
controller:RegisterEvent ("AUCTION_HOUSE_CLOSED");
controller:SetScript ("OnEvent", function (self, eventName)
    if (eventName == "AUCTION_HOUSE_SHOW") then
        ApplyForSelectedTab();
    else
        IsolateBlizzardTab();
    end
end);

-- Reassert presentation after delayed skin updates, but every pass is now
-- tab-aware: Buy-only controls are never shown outside Buy.
controller:SetScript ("OnUpdate", function (self, elapsed)
    elapsedSinceApply = elapsedSinceApply + elapsed;
    if (elapsedSinceApply < 0.20) then return; end
    elapsedSinceApply = 0;

    if (not AuctionFrame or not AuctionFrame:IsShown()) then return; end
    ApplyForSelectedTab();
end);
