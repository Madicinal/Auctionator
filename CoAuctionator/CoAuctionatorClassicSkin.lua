-- CoAuctionator +Mod 1.5
-- Classic/original Auctionator presentation layer.
--
-- The CoA fork keeps the same underlying Auctionator pane model, but changes
-- presentation and adds flat full-canvas panels.  This module restores the
-- pre-fork Auctionator shell/geometry while leaving all CoA scan, search,
-- inventory and purchase logic untouched.

local textureBase = "Interface\\AddOns\\CoAuctionator\\Images\\";
local classicBackdrop = nil;
local classicAdvancedButton = nil;
local elapsedSinceApply = 0;

local function ClearPanelBackdrop (panel)
    if (not panel) then return; end

    if (panel.SetBackdrop) then
        panel:SetBackdrop (nil);
    end
end

local function EnsureClassicBackdrop ()
    if (classicBackdrop or not AuctionFrame) then
        return classicBackdrop;
    end

    classicBackdrop = CreateFrame ("Frame", "CoAtr_ClassicBackdrop", AuctionFrame);
    classicBackdrop:SetPoint ("TOPLEFT", AuctionFrame, "TOPLEFT", 8, -8);
    classicBackdrop:SetPoint ("BOTTOMRIGHT", AuctionFrame, "BOTTOMRIGHT", -8, 8);
    classicBackdrop:SetFrameLevel ((AuctionFrame:GetFrameLevel() or 0) + 1);
    classicBackdrop:SetBackdrop ({
        bgFile = "Interface\\CharacterFrame\\UI-Party-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    });
    classicBackdrop:Show();

    return classicBackdrop;
end

local function ApplyClassicAuctionArt ()
    if (not AuctionFrame) then return; end

    EnsureClassicBackdrop();

    -- These are the exact six artwork files used by the preserved pre-fork
    -- Auctionator branch; only the addon-folder portion of the path changed.
    if (AuctionFrameTopLeft)  then AuctionFrameTopLeft:SetTexture  (textureBase.."atr_topleft"); end
    if (AuctionFrameTop)      then AuctionFrameTop:SetTexture      (textureBase.."atr_top"); end
    if (AuctionFrameTopRight) then AuctionFrameTopRight:SetTexture (textureBase.."atr_topright"); end
    if (AuctionFrameBotLeft)  then AuctionFrameBotLeft:SetTexture  (textureBase.."atr_botleft"); end
    if (AuctionFrameBot)      then AuctionFrameBot:SetTexture      (textureBase.."atr_bot"); end
    if (AuctionFrameBotRight) then AuctionFrameBotRight:SetTexture (textureBase.."atr_botright"); end

    -- The CoA fork's full-canvas panels remain as structural frames, but their
    -- black fallback backdrops are removed so the classic shell shows through.
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
    if (not Atr_Search_Box or not Atr_Search_Button) then return; end

    -- Search row from the preserved pre-fork Auctionator XML.
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

        -- The CoA checkbox remains the source of enable/disable state, but the
        -- old UI exposes Advanced as the original compact + button instead.
        if (Atr_Adv_Search_Button) then
            if (Atr_Adv_Search_Button:IsEnabled()) then adv:Enable(); else adv:Disable(); end
            Atr_Adv_Search_Button:Hide();
        end
    end

    -- Exact Match is a CoA feature with no legacy equivalent. Keep it, but tuck
    -- it beneath the old + button rather than letting it reshape the search row.
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

-- The CoA fork calls this when showing one of its full-canvas structural panels.
-- Keep the panels transparent and let our legacy shell provide the surface.
function Atr_ApplyPanelSkin (frame)
    ClearPanelBackdrop (frame);
    ApplyClassicAuctionArt();
end

-- CoA also force-reanchors known controls after tab changes / skin conflicts.
-- Preserve that protection, then put the classic positions back on top of it.
if (Atr_FixupButtons) then
    local upstreamFixupButtons = Atr_FixupButtons;
    Atr_FixupButtons = function (...)
        local result = upstreamFixupButtons (...);
        ApplyLegacyGeometry();
        return result;
    end;
end

local controller = CreateFrame ("Frame");
controller:RegisterEvent ("AUCTION_HOUSE_SHOW");
controller:SetScript ("OnEvent", function ()
    ApplyClassicAuctionArt();
    ApplyLegacyGeometry();
end);

-- The inherited tab switcher still writes old Auctionator image paths and its
-- geometry fixer may run after other UI skins. Reassert only while AH is open.
controller:SetScript ("OnUpdate", function (self, elapsed)
    elapsedSinceApply = elapsedSinceApply + elapsed;
    if (elapsedSinceApply < 0.20) then return; end
    elapsedSinceApply = 0;

    if (AuctionFrame and AuctionFrame:IsShown()) then
        ApplyClassicAuctionArt();
        ApplyLegacyGeometry();
    end
end);
