-- CoAuctionator +Mod 1.7
-- Inventory-tab presentation layer.
--
-- The Inventory feature is intentionally more complex than the original 2.9.9
-- Buy/Sell panes, so give its existing controls clear visual ownership instead
-- of forcing them into the old Auctionator list layout.  This file changes only
-- presentation/anchors; AuctionatorInventory.lua remains the functional source.

local built = false;
local inventoryPanel;
local marketPanel;
local statusBar;
local postingPanel;
local queuePanel;

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
    panel:SetBackdropColor (0.03, 0.03, 0.03, 0.78);
    panel:SetBackdropBorderColor (0.55, 0.48, 0.28, 0.95);
    return panel;
end

local function MakeCaption (panel, text)
    local caption = panel:CreateFontString (nil, "ARTWORK", "GameFontNormalSmall");
    caption:SetPoint ("TOPLEFT", panel, "TOPLEFT", 8, 9);
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

    -- Top half: two clearly separated information regions.
    inventoryPanel:Show();
    marketPanel:Show();
    statusBar:Show();
    postingPanel:Show();
    queuePanel:Show();

    if (frame.marketTitle) then
        -- The bordered region and its caption replace the old floating title.
        frame.marketTitle:Hide();
    end

    if (frame.selectionSummary) then
        frame.selectionSummary:ClearAllPoints();
        frame.selectionSummary:SetPoint ("BOTTOMLEFT", inventoryPanel, "BOTTOMLEFT", 8, 7);
        frame.selectionSummary:SetWidth (372);
        frame.selectionSummary:SetHeight (20);
    end

    if (frame.marketHint) then
        frame.marketHint:ClearAllPoints();
        frame.marketHint:SetPoint ("BOTTOMLEFT", marketPanel, "BOTTOMLEFT", 8, 7);
        frame.marketHint:SetWidth (324);
        frame.marketHint:SetHeight (20);
    end

    -- A single status strip separates choosing/reviewing from posting controls.
    if (frame.queueStatus) then
        frame.queueStatus:ClearAllPoints();
        frame.queueStatus:SetPoint ("TOPLEFT", statusBar, "TOPLEFT", 8, -4);
        frame.queueStatus:SetWidth (365);
        frame.queueStatus:SetHeight (22);
        frame.queueStatus:SetJustifyV ("MIDDLE");
    end

    if (frame.buyoutTotal) then
        frame.buyoutTotal:ClearAllPoints();
        frame.buyoutTotal:SetPoint ("TOPLEFT", statusBar, "TOPLEFT", 384, -3);
        frame.buyoutTotal:SetWidth (346);
        frame.buyoutTotal:SetHeight (13);
    end

    if (frame.planSummary) then
        frame.planSummary:ClearAllPoints();
        frame.planSummary:SetPoint ("TOPLEFT", statusBar, "TOPLEFT", 384, -15);
        frame.planSummary:SetWidth (346);
        frame.planSummary:SetHeight (13);
    end

    -- Posting setup remains in the same logical left-to-right order, but the
    -- duration control is brought inside the setup region rather than floating
    -- into the queue area.
    if (frame.durationButton) then
        MoveButton (frame.durationButton, postingPanel, "BOTTOMRIGHT", "BOTTOMRIGHT", -8, 7, 120, 22);
    end

    -- Queue actions are now one compact 2x2 cluster with obvious ownership.
    MoveButton (frame.startButton, queuePanel, "TOPLEFT", "TOPLEFT", 7, -18, 66, 22);
    MoveButton (frame.postButton,  queuePanel, "TOPRIGHT", "TOPRIGHT", -7, -18, 66, 22);
    MoveButton (frame.skipButton,  queuePanel, "BOTTOMLEFT", "BOTTOMLEFT", 7, 7, 66, 22);
    MoveButton (frame.stopButton,  queuePanel, "BOTTOMRIGHT", "BOTTOMRIGHT", -7, 7, 66, 22);
end

local function BuildLayout ()
    if (built or not Atr_InventoryFrame) then return; end

    local frame = Atr_InventoryFrame;

    -- The coordinates deliberately follow the existing Inventory data model:
    -- item selection left, live market comparison right, state in the middle,
    -- then posting inputs and queue actions along the bottom.
    inventoryPanel = MakePanel (frame, "CoAtr_InventoryItemsPanel", 0, -30, 390, 236);
    marketPanel    = MakePanel (frame, "CoAtr_InventoryMarketPanel", 398, -30, 342, 236);
    statusBar      = MakePanel (frame, "CoAtr_InventoryStatusBar", 0, -272, 740, 30);
    postingPanel   = MakePanel (frame, "CoAtr_InventoryPostingPanel", 0, -308, 580, 64);
    queuePanel     = MakePanel (frame, "CoAtr_InventoryQueuePanel", 588, -308, 152, 64);

    MakeCaption (inventoryPanel, "Inventory Items");
    MakeCaption (marketPanel, "Matching Auctions");
    MakeCaption (postingPanel, "Posting Setup");
    MakeCaption (queuePanel, "Queue Controls");

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
