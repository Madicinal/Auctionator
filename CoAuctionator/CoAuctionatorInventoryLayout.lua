-- CoAuctionator +Mod 1.8
-- Compact Inventory-tab presentation layer.
--
-- Keep AuctionatorInventory.lua as the functional source.  This module only
-- gives that custom feature a Bids-like inset workspace: two clear upper panes
-- and one lower posting/queue pane, scaled slightly to sit comfortably inside
-- the normal Auction House content area.

local built = false;
local inventoryPanel;
local marketPanel;
local postingPanel;

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
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    });
    panel:SetBackdropColor (0.02, 0.02, 0.02, 0.62);
    panel:SetBackdropBorderColor (0.52, 0.46, 0.27, 0.90);
    return panel;
end

local function MakeCaption (panel, text)
    local caption = panel:CreateFontString (nil, "ARTWORK", "GameFontNormalSmall");
    -- Sit on the upper edge like Blizzard inset-frame labels instead of taking a
    -- full extra row inside the content area.
    caption:SetPoint ("BOTTOMLEFT", panel, "TOPLEFT", 8, -1);
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

local function ApplyLayout ()
    local frame = Atr_InventoryFrame;
    if (not frame or not built) then return; end

    -- The stock Bids pane leaves a margin around its content.  Inventory is a
    -- custom 744x374 workspace, so reduce it slightly and center it in that same
    -- visual area instead of letting it ride against every edge of AuctionFrame.
    frame:SetScale (0.92);
    frame:ClearAllPoints();
    frame:SetPoint ("TOPLEFT", AuctionFrame, "TOPLEFT", 45, -67);

    inventoryPanel:Show();
    marketPanel:Show();
    postingPanel:Show();

    -- Existing column headings/rows were already internally aligned well.  Keep
    -- those coordinates and place the section boundaries around them rather than
    -- fighting the Inventory engine's row geometry.
    if (frame.marketTitle) then
        frame.marketTitle:ClearAllPoints();
        frame.marketTitle:SetPoint ("BOTTOMLEFT", marketPanel, "TOPLEFT", 8, -1);
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

    -- One lower region owns both state and posting actions.  This is deliberately
    -- simpler than +Mod 1.7's five-box design and reads more like Blizzard's
    -- auction panes.
    if (frame.queueStatus) then
        frame.queueStatus:ClearAllPoints();
        frame.queueStatus:SetPoint ("TOPLEFT", postingPanel, "TOPLEFT", 8, -8);
        frame.queueStatus:SetWidth (360);
        frame.queueStatus:SetHeight (28);
        frame.queueStatus:SetJustifyV ("MIDDLE");
    end

    if (frame.buyoutTotal) then
        frame.buyoutTotal:ClearAllPoints();
        frame.buyoutTotal:SetPoint ("TOPLEFT", postingPanel, "TOPLEFT", 382, -7);
        frame.buyoutTotal:SetWidth (348);
        frame.buyoutTotal:SetHeight (13);
    end

    if (frame.planSummary) then
        frame.planSummary:ClearAllPoints();
        frame.planSummary:SetPoint ("TOPLEFT", postingPanel, "TOPLEFT", 382, -21);
        frame.planSummary:SetWidth (348);
        frame.planSummary:SetHeight (13);
    end

    -- Duration remains part of the posting parameters, not a separate queue box.
    MoveButton (frame.durationButton, postingPanel, "TOPRIGHT", "TOPRIGHT", -8, -35, 120, 22);

    -- Four actions form a single horizontal Blizzard-style action row.
    MoveButton (frame.startButton, postingPanel, "BOTTOMLEFT", "BOTTOMLEFT", 8, 7, 88, 22);
    MoveButton (frame.postButton,  postingPanel, "LEFT", "RIGHT", 6, 0, 88, 22);
    MoveButton (frame.skipButton,  postingPanel, "LEFT", "RIGHT", 6, 0, 78, 22);
    MoveButton (frame.stopButton,  postingPanel, "LEFT", "RIGHT", 6, 0, 58, 22);
end

local function BuildLayout ()
    if (built or not Atr_InventoryFrame) then return; end

    local frame = Atr_InventoryFrame;

    -- Match the existing row geometry: inventory occupies x=0..390, market
    -- x=398..740, and the posting controls already live in the last ~95px high
    -- band.  These three insets therefore segment without covering useful rows.
    inventoryPanel = MakePanel (frame, "CoAtr_InventoryItemsPanel", 0, -35, 390, 232);
    marketPanel    = MakePanel (frame, "CoAtr_InventoryMarketPanel", 398, -35, 342, 232);
    postingPanel   = MakePanel (frame, "CoAtr_InventoryPostingPanel", 0, -278, 740, 94);

    MakeCaption (inventoryPanel, "Inventory Items");
    MakeCaption (postingPanel, "Posting Queue");

    built = true;
    ApplyLayout();

    if (not frame.coAtrInventoryLayoutHooked) then
        frame.coAtrInventoryLayoutHooked = true;
        frame:HookScript ("OnShow", function ()
            ApplyLayout();
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
