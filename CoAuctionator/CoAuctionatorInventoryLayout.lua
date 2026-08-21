-- CoAuctionator +Mod 1.12
-- Inventory-specific UI shell.
--
-- Inventory is intentionally NOT drawn on Atr_Main_Panel. CoAuctionatorClassicSkin
-- gives this tab Blizzard's neutral Bids artwork; this file arranges the existing
-- Inventory controls inside that blank canvas without changing posting logic.

local built = false;
local inventoryPanel;
local marketPanel;
local postingPanel;
local inventoryTitle;
local inventoryOptionsButton;
local inventoryFullScanButton;

local function MakePanel (parent, name, x, y, width, height)
    local panel = CreateFrame ("Frame", name, parent);
    panel:SetWidth (width);
    panel:SetHeight (height);
    panel:SetPoint ("TOPLEFT", parent, "TOPLEFT", x, y);
    panel:SetFrameLevel (parent:GetFrameLevel());
    panel:EnableMouse (false);
    panel:SetBackdrop ({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    });
    panel:SetBackdropColor (0.01, 0.01, 0.01, 0.42);
    panel:SetBackdropBorderColor (0.48, 0.42, 0.24, 0.72);
    return panel;
end

local function MakeCaption (panel, text)
    local caption = panel:CreateFontString (nil, "ARTWORK", "GameFontNormalSmall");
    caption:SetPoint ("TOPLEFT", panel, "TOPLEFT", 8, -6);
    caption:SetText (text);
    return caption;
end

local function MoveObject (object, anchor, point, relPoint, x, y, width, height)
    if (not object or not anchor) then return; end
    object:ClearAllPoints();
    object:SetPoint (point or "TOPLEFT", anchor, relPoint or "TOPLEFT", x or 0, y or 0);
    if (width and object.SetWidth) then object:SetWidth (width); end
    if (height and object.SetHeight) then object:SetHeight (height); end
end

local function MoveButton (button, anchor, point, relPoint, x, y, width, height)
    MoveObject (button, anchor, point, relPoint, x, y, width, height);
end

local function FindTextRegion (frame, wantedText)
    if (not frame or not wantedText) then return nil; end

    local regions = {frame:GetRegions()};
    local i;
    for i = 1, #regions do
        local region = regions[i];
        if (region and region.GetText and region:GetText() == wantedText) then
            return region;
        end
    end
    return nil;
end

local function FindTextureRegion (frame, textureNeedle)
    if (not frame or not textureNeedle) then return nil; end

    local regions = {frame:GetRegions()};
    local i;
    for i = 1, #regions do
        local region = regions[i];
        if (region and region.GetTexture) then
            local texture = region:GetTexture();
            if (type(texture) == "string" and string.find(texture, textureNeedle, 1, true)) then
                return region;
            end
        end
    end
    return nil;
end

local function HideLegacyInventoryDecorations (frame)
    -- AuctionatorInventory.lua predates this shell and creates an explanatory
    -- paragraph plus a 1px center divider. They are redundant once the tab has
    -- explicit sections.
    local regions = {frame:GetRegions()};
    local i;
    for i = 1, #regions do
        local region = regions[i];
        if (region and region.GetText) then
            local text = region:GetText();
            if (type(text) == "string" and string.find(text, "Auctionable inventory sorted", 1, true) == 1) then
                region:Hide();
            end
        elseif (region and region.GetWidth and region.GetHeight) then
            local w = region:GetWidth();
            local h = region:GetHeight();
            if (w and h and w <= 2 and h >= 200 and h <= 240) then
                region:Hide();
            end
        end
    end
end

local function InventoryTabSelected ()
    if (not AuctionFrame or not PanelTemplates_GetSelectedTab or not Atr_FindTabIndex) then
        return false;
    end

    local inventoryIndex = Atr_FindTabIndex (4); -- INVENTORY_TAB in Auctionator.lua
    local selectedIndex = PanelTemplates_GetSelectedTab (AuctionFrame);
    return inventoryIndex and inventoryIndex > 0 and selectedIndex == inventoryIndex;
end

local function EnsureInventoryHeader ()
    if (inventoryTitle or not AuctionFrame) then return; end

    inventoryTitle = AuctionFrame:CreateFontString ("CoAtr_InventoryTitle", "OVERLAY", "GameFontNormal");
    inventoryTitle:SetPoint ("TOP", AuctionFrame, "TOP", 0, -17);
    inventoryTitle:SetText ("Auctionator - Inventory Value");

    inventoryOptionsButton = CreateFrame ("Button", "CoAtr_InventoryOptionsButton", AuctionFrame, "UIPanelButtonTemplate");
    inventoryOptionsButton:SetWidth (72);
    inventoryOptionsButton:SetHeight (20);
    inventoryOptionsButton:SetPoint ("TOPRIGHT", AuctionFrame, "TOPRIGHT", -18, -42);
    inventoryOptionsButton:SetText ("Options");
    inventoryOptionsButton:SetScript ("OnClick", function ()
        if (Auctionator1Button and Auctionator1Button.GetScript) then
            local click = Auctionator1Button:GetScript ("OnClick");
            if (click) then click (Auctionator1Button); return; end
        end
        if (InterfaceOptionsFrame_OpenToCategory) then
            InterfaceOptionsFrame_OpenToCategory ("Auctionator");
        end
    end);

    inventoryFullScanButton = CreateFrame ("Button", "CoAtr_InventoryFullScanButton", AuctionFrame, "UIPanelButtonTemplate");
    inventoryFullScanButton:SetWidth (82);
    inventoryFullScanButton:SetHeight (20);
    inventoryFullScanButton:SetPoint ("RIGHT", inventoryOptionsButton, "LEFT", -8, 0);
    inventoryFullScanButton:SetText ("Full Scan...");
    inventoryFullScanButton:SetScript ("OnClick", function ()
        if (Atr_ShowFullScanFrame) then Atr_ShowFullScanFrame(); end
    end);

    inventoryTitle:Hide();
    inventoryOptionsButton:Hide();
    inventoryFullScanButton:Hide();
end

local function ShowInventoryHeader (show)
    EnsureInventoryHeader();

    if (show) then
        if (inventoryTitle) then inventoryTitle:Show(); end
        if (inventoryOptionsButton) then inventoryOptionsButton:Show(); end
        if (inventoryFullScanButton) then inventoryFullScanButton:Show(); end
    else
        if (inventoryTitle) then inventoryTitle:Hide(); end
        if (inventoryOptionsButton) then inventoryOptionsButton:Hide(); end
        if (inventoryFullScanButton) then inventoryFullScanButton:Hide(); end
    end
end

local function ApplyPostingInputRow (frame)
    if (not frame or not postingPanel) then return; end

    -- AuctionatorInventory.lua creates this whole row at y=-313/-319.  That was
    -- correct for the upstream full-canvas layout, but in our segmented shell it
    -- collides with queueStatus/buyoutTotal.  Re-anchor the existing objects as a
    -- single lower row, leaving the posting engine and callbacks untouched.
    local buyoutLabel = FindTextRegion (frame, "Buyout per item:");
    local stackLabel = FindTextRegion (frame, "Stack:");
    local auctionsLabel = FindTextRegion (frame, "Auctions:");
    local goldIcon = FindTextureRegion (frame, "UI-GoldIcon");
    local silverIcon = FindTextureRegion (frame, "UI-SilverIcon");
    local copperIcon = FindTextureRegion (frame, "UI-CopperIcon");

    MoveObject (buyoutLabel, postingPanel, "TOPLEFT", "TOPLEFT", 8, -56, 84, nil);
    MoveObject (frame.priceGold, postingPanel, "TOPLEFT", "TOPLEFT", 98, -50, 38, 20);
    MoveObject (goldIcon, postingPanel, "TOPLEFT", "TOPLEFT", 140, -54, 12, 12);
    MoveObject (frame.priceSilver, postingPanel, "TOPLEFT", "TOPLEFT", 156, -50, 31, 20);
    MoveObject (silverIcon, postingPanel, "TOPLEFT", "TOPLEFT", 191, -54, 12, 12);
    MoveObject (frame.priceCopper, postingPanel, "TOPLEFT", "TOPLEFT", 207, -50, 31, 20);
    MoveObject (copperIcon, postingPanel, "TOPLEFT", "TOPLEFT", 242, -54, 12, 12);
    MoveButton (frame.recommendedButton, postingPanel, "TOPLEFT", "TOPLEFT", 258, -51, 64, 22);

    MoveObject (stackLabel, postingPanel, "TOPLEFT", "TOPLEFT", 342, -56, 42, nil);
    MoveObject (frame.stackSize, postingPanel, "TOPLEFT", "TOPLEFT", 388, -50, 36, 20);
    MoveButton (frame.stackMaxButton, postingPanel, "TOPLEFT", "TOPLEFT", 430, -51, 42, 22);

    MoveObject (auctionsLabel, postingPanel, "TOPLEFT", "TOPLEFT", 490, -56, 52, nil);
    MoveObject (frame.numAuctions, postingPanel, "TOPLEFT", "TOPLEFT", 548, -50, 36, 20);
    MoveButton (frame.auctionsMaxButton, postingPanel, "TOPLEFT", "TOPLEFT", 590, -51, 42, 22);

    MoveButton (frame.durationButton, postingPanel, "TOPRIGHT", "TOPRIGHT", -8, -51, 120, 22);
end

local function ApplyLayout ()
    local frame = Atr_InventoryFrame;
    if (not frame or not built) then return; end

    -- Fill nearly the same usable rectangle as Blizzard's Bids pane.  Instead of
    -- scaling the old 744-wide workspace way down, widen the shell itself so the
    -- right-side market pane and lower queue use the otherwise empty canvas.
    frame:SetWidth (850);
    frame:SetHeight (400);
    frame:SetScale (0.91);
    frame:ClearAllPoints();
    frame:SetPoint ("TOPLEFT", AuctionFrame, "TOPLEFT", 30, -60);

    HideLegacyInventoryDecorations (frame);

    -- Critical startup guard: BuildLayout runs once as soon as the Inventory
    -- frame exists, even when Browse/Bids/Auctions is currently selected.  The
    -- header is parented to AuctionFrame rather than Atr_InventoryFrame, so it
    -- must only be shown when Inventory itself is both selected and visible.
    ShowInventoryHeader (frame:IsShown() and InventoryTabSelected());

    inventoryPanel:Show();
    marketPanel:Show();
    postingPanel:Show();

    -- Keep all three utility buttons inside the Inventory Items header.
    MoveButton (frame.refreshButton,   inventoryPanel, "TOPLEFT", "TOPLEFT", 176, -4, 68, 22);
    MoveButton (frame.selectAllButton, inventoryPanel, "TOPLEFT", "TOPLEFT", 248, -4, 72, 22);
    MoveButton (frame.clearButton,     inventoryPanel, "TOPLEFT", "TOPLEFT", 324, -4, 58, 22);

    -- The Inventory engine updates marketTitle dynamically with the active item,
    -- so reuse it as the right-pane caption.
    if (frame.marketTitle) then
        frame.marketTitle:ClearAllPoints();
        frame.marketTitle:SetPoint ("TOPLEFT", marketPanel, "TOPLEFT", 8, -6);
        frame.marketTitle:SetWidth (434);
        frame.marketTitle:SetHeight (16);
        frame.marketTitle:Show();
    end

    -- The taller upper panes give the eighth inventory/market row breathing room
    -- before their summaries instead of letting the summary overlap the last row.
    if (frame.selectionSummary) then
        frame.selectionSummary:ClearAllPoints();
        frame.selectionSummary:SetPoint ("BOTTOMLEFT", inventoryPanel, "BOTTOMLEFT", 8, 7);
        frame.selectionSummary:SetWidth (372);
        frame.selectionSummary:SetHeight (18);
    end

    if (frame.marketHint) then
        frame.marketHint:ClearAllPoints();
        frame.marketHint:SetPoint ("BOTTOMLEFT", marketPanel, "BOTTOMLEFT", 8, 7);
        frame.marketHint:SetWidth (434);
        frame.marketHint:SetHeight (18);
    end

    -- Reserve the upper part of Posting Queue for status/summary, then put every
    -- price/stack/auction control on one lower row below it.
    if (frame.queueStatus) then
        frame.queueStatus:ClearAllPoints();
        frame.queueStatus:SetPoint ("TOPLEFT", postingPanel, "TOPLEFT", 8, -17);
        frame.queueStatus:SetWidth (390);
        frame.queueStatus:SetHeight (24);
        frame.queueStatus:SetJustifyV ("MIDDLE");
    end

    if (frame.buyoutTotal) then
        frame.buyoutTotal:ClearAllPoints();
        frame.buyoutTotal:SetPoint ("TOPLEFT", postingPanel, "TOPLEFT", 408, -16);
        frame.buyoutTotal:SetWidth (430);
        frame.buyoutTotal:SetHeight (13);
    end

    if (frame.planSummary) then
        frame.planSummary:ClearAllPoints();
        frame.planSummary:SetPoint ("TOPLEFT", postingPanel, "TOPLEFT", 408, -30);
        frame.planSummary:SetWidth (430);
        frame.planSummary:SetHeight (13);
    end

    ApplyPostingInputRow (frame);

    MoveButton (frame.startButton, postingPanel, "BOTTOMLEFT", "BOTTOMLEFT", 8, 7, 88, 22);
    if (frame.postButton) then
        frame.postButton:ClearAllPoints();
        frame.postButton:SetPoint ("LEFT", frame.startButton, "RIGHT", 6, 0);
        frame.postButton:SetWidth (88);
        frame.postButton:SetHeight (22);
    end
    if (frame.skipButton) then
        frame.skipButton:ClearAllPoints();
        frame.skipButton:SetPoint ("LEFT", frame.postButton, "RIGHT", 6, 0);
        frame.skipButton:SetWidth (78);
        frame.skipButton:SetHeight (22);
    end
    if (frame.stopButton) then
        frame.stopButton:ClearAllPoints();
        frame.stopButton:SetPoint ("LEFT", frame.skipButton, "RIGHT", 6, 0);
        frame.stopButton:SetWidth (58);
        frame.stopButton:SetHeight (22);
    end
end

local function BuildLayout ()
    if (built or not Atr_InventoryFrame) then return; end

    local frame = Atr_InventoryFrame;

    -- Left-side inventory rows retain their original width.  The market pane uses
    -- the additional Bids-canvas width, while both upper panes are taller so the
    -- summary/hint lines sit below the final visible row.
    inventoryPanel = MakePanel (frame, "CoAtr_InventoryItemsPanel", 0, -18, 390, 260);
    marketPanel    = MakePanel (frame, "CoAtr_InventoryMarketPanel", 398, -18, 452, 260);
    postingPanel   = MakePanel (frame, "CoAtr_InventoryPostingPanel", 0, -284, 850, 110);

    MakeCaption (inventoryPanel, "Inventory Items");
    MakeCaption (postingPanel, "Posting Queue");

    built = true;
    ApplyLayout();

    if (not frame.coAtrInventoryLayoutHooked) then
        frame.coAtrInventoryLayoutHooked = true;
        frame:HookScript ("OnShow", function ()
            ApplyLayout();
        end);
        frame:HookScript ("OnHide", function ()
            ShowInventoryHeader (false);
        end);
    end
end

local controller = CreateFrame ("Frame");
controller:SetScript ("OnUpdate", function (self)
    if (not built) then
        BuildLayout();
    else
        self:SetScript ("OnUpdate", nil);
    end
end);
