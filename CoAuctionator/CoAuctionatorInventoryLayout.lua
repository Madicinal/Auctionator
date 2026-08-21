-- CoAuctionator +Mod 1.10
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

local function MoveButton (button, anchor, point, relPoint, x, y, width, height)
    if (not button or not anchor) then return; end
    button:ClearAllPoints();
    button:SetPoint (point or "TOPLEFT", anchor, relPoint or "TOPLEFT", x or 0, y or 0);
    if (width) then button:SetWidth (width); end
    if (height) then button:SetHeight (height); end
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
    ShowInventoryHeader (true);

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

    -- One lower inset owns state, price/stack inputs and queue actions.  It is
    -- deeper and wider now, but the proven Inventory engine input coordinates are
    -- retained so this remains a presentation-only change.
    if (frame.queueStatus) then
        frame.queueStatus:ClearAllPoints();
        frame.queueStatus:SetPoint ("TOPLEFT", postingPanel, "TOPLEFT", 8, -8);
        frame.queueStatus:SetWidth (390);
        frame.queueStatus:SetHeight (24);
        frame.queueStatus:SetJustifyV ("MIDDLE");
    end

    if (frame.buyoutTotal) then
        frame.buyoutTotal:ClearAllPoints();
        frame.buyoutTotal:SetPoint ("TOPLEFT", postingPanel, "TOPLEFT", 408, -7);
        frame.buyoutTotal:SetWidth (430);
        frame.buyoutTotal:SetHeight (13);
    end

    if (frame.planSummary) then
        frame.planSummary:ClearAllPoints();
        frame.planSummary:SetPoint ("TOPLEFT", postingPanel, "TOPLEFT", 408, -21);
        frame.planSummary:SetWidth (430);
        frame.planSummary:SetHeight (13);
    end

    MoveButton (frame.durationButton, postingPanel, "TOPRIGHT", "TOPRIGHT", -8, -43, 120, 22);

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
