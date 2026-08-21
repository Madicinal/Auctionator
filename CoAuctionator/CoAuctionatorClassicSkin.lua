-- CoAuctionator +Mod 1.6
-- Classic/original Auctionator presentation layer with strict tab isolation.
--
-- The CoA fork intentionally hides the six AuctionFrame art tiles and draws its
-- own full-canvas panels on custom tabs.  For this fork we want the opposite:
-- keep the original Auctionator artwork visible on CoAuctionator tabs, keep the
-- CoA panels structurally present but visually transparent, and never touch the
-- appearance of Blizzard's Browse / Bids / Auctions tabs.

local textureBase = "Interface\\AddOns\\CoAuctionator\\Images\\";
local classicAdvancedButton = nil;
local elapsedSinceApply = 0;
local lastWasCustom = nil;

local function ClearPanelBackdrop (panel)
    if (not panel) then return; end

    if (panel.SetBackdrop) then
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

local function HideLegacyBackdropIfPresent ()
    -- +Mod 1.5 created this frame.  A /reload removes the old implementation,
    -- but hide it defensively in case this module is hot-reloaded while testing.
    local oldBackdrop = _G["CoAtr_ClassicBackdrop"];
    if (oldBackdrop) then
        oldBackdrop:Hide();
    end
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

    -- The CoA panels still own useful tab structure, but they must not paint the
    -- black full-canvas surface over the original Auctionator art.
    ClearPanelBackdrop (Atr_Panel_Sell);
    ClearPanelBackdrop (Atr_Panel_Buy);
    ClearPanelBackdrop (Atr_Panel_More);
    ClearPanelBackdrop (Atr_Panel_Inventory);
end

local function EnsureClassicAdvancedButton ()
    if (classicAdvancedButton) then
        return classicAdvancedButton;
    end

    if (not Atr_Search_Button or not Atr_Search_Button.GetParent) then
        return nil;
    end

    local parent = Atr_Search_Button:GetParent();
    if (not parent) then return nil; end

    classicAdvancedButton = CreateFrame ("Button", "CoAtr_AdvancedSearchButton", parent, "UIPanelButtonTemplate");
    classicAdvancedButton:SetWidth (24);
    classicAdvancedButton:SetHeight (18);
    classicAdvancedButton:SetText ("+");
    classicAdvancedButton:SetScript ("OnClick", function ()
        if (Atr_Adv_Search_Onclick) then
            Atr_Adv_Search_Onclick();
        end
    end);
    classicAdvancedButton:SetScript ("OnEnter", function (self)
        GameTooltip:SetOwner (self, "ANCHOR_TOP");
        GameTooltip:SetText ("Advanced Search");
        GameTooltip:Show();
    end);
    classicAdvancedButton:SetScript ("OnLeave", function () GameTooltip:Hide(); end);

    return classicAdvancedButton;
end

local function ApplyLegacyGeometry ()
    local _, _, isCustom = SelectedTabInfo();
    if (not isCustom or not Atr_Search_Box or not Atr_Search_Button) then
        return;
    end

    -- Search row copied from the preserved pre-fork Auctionator layout.
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

        -- Keep the CoA checkbox as the underlying state source while presenting
        -- the original compact + button to the user.
        if (Atr_Adv_Search_Button) then
            if (Atr_Adv_Search_Button:IsEnabled()) then adv:Enable(); else adv:Disable(); end
            Atr_Adv_Search_Button:Hide();
        end
    end

    -- Exact Match is a CoA feature with no legacy equivalent. Keep it tucked
    -- beneath the original advanced-search button.
    if (Atr_Exact_Search_Button and adv) then
        Atr_Exact_Search_Button:ClearAllPoints();
        Atr_Exact_Search_Button:SetPoint ("TOPLEFT", adv, "BOTTOMLEFT", 0, 2);
        Atr_Exact_Search_Button:Show();
    end

    if (Auctionator1Button) then
        Auctionator1Button:ClearAllPoints();
        Auctionator1Button:SetWidth (70);
        Auctionator1Button:SetHeight (18);
        Auctionator1Button:SetText ("Options");
        Auctionator1Button:SetPoint ("LEFT", Atr_Search_Button, "RIGHT", 165, 0);
    end

    if (Atr_FullScanButton and Auctionator1Button) then
        Atr_FullScanButton:ClearAllPoints();
        Atr_FullScanButton:SetWidth (74);
        Atr_FullScanButton:SetHeight (18);
        Atr_FullScanButton:SetPoint ("RIGHT", Auctionator1Button, "LEFT", -2, 0);
    end
end

local function IsolateBlizzardTab ()
    HideLegacyBackdropIfPresent();

    -- These are all CoAuctionator-owned visual surfaces.  The upstream tab
    -- handler already hides them; this is a defensive boundary so a future skin,
    -- OnShow handler, or delayed update cannot project Buy/Sell UI onto Blizzard
    -- Browse, Bids, or Auctions.
    if (Atr_Main_Panel) then Atr_Main_Panel:Hide(); end
    if (Atr_Panel_Sell) then Atr_Panel_Sell:Hide(); end
    if (Atr_Panel_Buy) then Atr_Panel_Buy:Hide(); end
    if (Atr_Panel_More) then Atr_Panel_More:Hide(); end
    if (Atr_Panel_Inventory) then Atr_Panel_Inventory:Hide(); end
    if (Atr_BagPanel) then Atr_BagPanel:Hide(); end
    if (Atr_InventoryFrame) then Atr_InventoryFrame:Hide(); end
    if (classicAdvancedButton) then classicAdvancedButton:Hide(); end

    if (Atr_BuyMultiple_Frame and Atr_BuyMultiple_Frame:IsShown()) then
        Atr_BuyMultiple_Frame:Hide();
    end
end

-- The CoA panel system calls Atr_HideAHArt before showing its custom panel.
-- Suppress that behavior: original Auctionator uses these six art tiles as the
-- custom-tab shell, so they must remain visible.  This affects only the custom
-- panel path; Blizzard's own tab handler still controls its native artwork.
function Atr_HideAHArt ()
    -- intentionally empty for the classic-shell fork
end

-- Never allow the CoA full-canvas panels to paint their black fallback surface.
function Atr_ApplyPanelSkin (frame)
    ClearPanelBackdrop (frame);
end

-- CoA force-reanchors known controls after tab changes / skin conflicts. Preserve
-- its functional fixups, then reapply the legacy positions only on custom tabs.
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
        -- Do NOT set or re-show AuctionFrameTop*/Bot* textures here.  The native
        -- Blizzard AuctionFrameTab_OnClick that already ran owns those textures.
    end

    lastWasCustom = isCustom;
end

local controller = CreateFrame ("Frame");
controller:RegisterEvent ("AUCTION_HOUSE_SHOW");
controller:RegisterEvent ("AUCTION_HOUSE_CLOSED");
controller:SetScript ("OnEvent", function (self, eventName)
    if (eventName == "AUCTION_HOUSE_SHOW") then
        ApplyForSelectedTab();
    else
        IsolateBlizzardTab();
        lastWasCustom = nil;
    end
end);

-- Reassert tab ownership after other AH addons/skins finish their own delayed
-- updates.  The important distinction from +Mod 1.5 is that custom art is never
-- applied while a Blizzard tab is selected.
controller:SetScript ("OnUpdate", function (self, elapsed)
    elapsedSinceApply = elapsedSinceApply + elapsed;
    if (elapsedSinceApply < 0.20) then return; end
    elapsedSinceApply = 0;

    if (not AuctionFrame or not AuctionFrame:IsShown()) then
        return;
    end

    local _, _, isCustom = SelectedTabInfo();

    if (isCustom) then
        ShowClassicAuctionArt();
        ApplyLegacyGeometry();
    else
        IsolateBlizzardTab();
    end

    lastWasCustom = isCustom;
end);
