-- CoAuctionator +Mod 1.9
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
    -- explicit sections, and are the main source of the visual collisions seen
    -- in +Mod 1.8.
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

    -- Bids uses most of the AH's interior but leaves a comfortable stone border.
    -- Scale the 744x374 Inventory workspace to ~670x337 and center it there.
    frame:SetScale (0.90);
    frame:ClearAllPoints();
    frame:SetPoint ("TOPLEFT", AuctionFrame, "TOPLEFT", 82, -67);

    HideLegacyInventoryDecorations (frame);
    ShowInventoryHeader (true);

    inventoryPanel:Show();
    marketPanel:Show();
    postingPanel:Show();

    -- Keep all three utility buttons inside the Inventory Items header instead of
    -- letting them straddle both upper sections.
    MoveButton (frame.refreshButton,   inventoryPanel, "TOPLEFT", "TOPLEFT", 176, -4, 68, 22);
    MoveButton (frame.selectAllButton, inventoryPanel, "TOPLEFT", "TOPLEFT", 248, -4, 72, 22);
    MoveButton (frame.clearButton,     inventoryPanel, "TOPLEFT", "TOPLEFT", 324, -4, 58, 22);

    -- The Inventory engine updates marketTitle dynamically with the active item,
    -- so reuse it as the right-pane caption instead of drawing a second title.
    if (frame.marketTitle) then
        frame.marketTitle:ClearAllPoints();
        frame.marketTitle:SetPoint ("TOPLEFT", marketPanel, "TOPLEFT", 8, -6);
        frame.marketTitle:SetWidth (324);
        frame.marketTitle:SetHeight (16);
        frame.marketTitle:Show();
    end

    if (frame.selectionSummary) then
        frame.selectionSummary:ClearAllPoints();
        frame.selectionSummary:SetPoint ("BOTTOMLEFT", inventoryPanel, "BOTTOMLEFT", 8, 7);
        frame.selectionSummary:SetWidth (372);
        frame.selectionSummary:SetHeight (18);
    end

    if (frame.marketHint) then
        frame.marketHint:ClearAllPoints();
        frame.marketHint:SetPoint ("BOTTOMLEFT", marketPanel, "BOTTOMLEFT", 8, 7);
        frame.marketHint:SetWidth (324);
        frame.marketHint:SetHeight (18);
    end

    -- One lower inset owns state, price/stack inputs and queue actions. The input
    -- boxes themselves keep their proven AuctionatorInventory.lua coordinates;
    -- only the status and action row are normalized around them.
    if (frame.queueStatus) then
        frame.queueStatus:ClearAllPoints();
        frame.queueStatus:SetPoint ("TOPLEFT", postingPanel, "TOPLEFT", 8, -19);
        frame.queueStatus:SetWidth (355);
        frame.queueStatus:SetHeight (24);
        frame.queueStatus:SetJustifyV ("MIDDLE");
    end

    if (frame.buyoutTotal) then
        frame.buyoutTotal:ClearAllPoints();
        frame.buyoutTotal:SetPoint ("TOPLEFT", postingPanel, "TOPLEFT", 382, -18);
        frame.buyoutTotal:SetWidth (348);
        frame.buyoutTotal:SetHeight (13);
    end

    if (frame.planSummary) then
        frame.planSummary:ClearAllPoints();
        frame.planSummary:SetPoint ("TOPLEFT", postingPanel, "TOPLEFT", 382, -32);
        frame.planSummary:SetWidth (348);
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

    -- Existing rows occupy approximately x=0..390 and x=398..740. Keep those
    -- proven dimensions and give each area a restrained Bids-like inset.
    inventoryPanel = MakePanel (frame, "CoAtr_InventoryItemsPanel", 0, -18, 390, 240);
    marketPanel    = MakePanel (frame, "CoAtr_InventoryMarketPanel", 398, -18, 342, 240);
    postingPanel   = MakePanel (frame, "CoAtr_InventoryPostingPanel", 0, -268, 740, 104);

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
