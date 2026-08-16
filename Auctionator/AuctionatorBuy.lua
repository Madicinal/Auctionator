
local addonName, addonTable = ...; 
local zc = addonTable.zc;


local ATR_BUY_NULL						= 0;
local ATR_BUY_QUERY_SENT				= 1;
local ATR_BUY_JUST_BOUGHT				= 2;
local ATR_BUY_PROCESSING_QUERY_RESULTS	= 3;
local ATR_BUY_WAITING_FOR_AH_CAN_SEND	= 4;

local Atr_BuyState = ATR_BUY_NULL;
local ATR_BUY_POST_BUY_DELAY			= 1;

-----------------------------------------

local gAtr_Buy_BuyoutPrice;
local gAtr_Buy_ItemName;
local gAtr_Buy_StackSize;
local gAtr_Buy_NumBought;
local gAtr_Buy_NumUserWants;
local gAtr_Buy_MaxCanBuy;
local gAtr_Buy_CurPage;
local gAtr_Buy_Waiting_Start;
local gAtr_Buy_Query;
local gAtr_Buy_Pass;
local gAtr_Buy_Session_NumBought		= 0;
local gAtr_Buy_Session_TotalSpent		= 0;
local gAtr_Buy_PendingBuy				= nil;

-- Ascension chain-buy mode.  The server protects PlaceAuctionBid(), so every
-- purchase in this mode is tied to its own visible hardware-click button.
local gAtr_Buy_ChainMode				= false;
local gAtr_Buy_ChainFrame				= nil;
local gAtr_Buy_ChainRows				= {};
local gAtr_Buy_ChainDisplayOffset		= 0;
local gAtr_Buy_ChainRowsPerPage			= 10;
local gAtr_Buy_ChainReady				= false;

-----------------------------------------

local function Atr_Buy_IsChainChecked()

	return (Atr_Buy_Chain_CB and Atr_Buy_Chain_CB:GetChecked());

end

-----------------------------------------

local function Atr_Buy_IsBuyableData(data)

	return (data and data.type == "n" and not data.yours and not data.altname and data.buyoutPrice > 0);

end

-----------------------------------------

local function Atr_Buy_CoinString(val)

	local gold, silver, copper = zc.val2gsc(val);
	local goldIcon		= "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t";
	local silverIcon	= "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t";
	local copperIcon	= "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t";
	local st = "";

	if (gold > 0) then
		st = gold..goldIcon.." "..format("%02i", silver)..silverIcon.." "..format("%02i", copper)..copperIcon;
	elseif (silver > 0) then
		st = silver..silverIcon.." "..format("%02i", copper)..copperIcon;
	else
		st = copper..copperIcon;
	end

	return st;

end

-----------------------------------------

local function Atr_Buy_UpdateSessionText()

	if (not Atr_Buy_Session_Text) then
		return;
	end

	if (gAtr_Buy_Session_NumBought > 0) then
		Atr_Buy_Session_Text:SetText ("Bought x"..gAtr_Buy_Session_NumBought.." for "..Atr_Buy_CoinString(gAtr_Buy_Session_TotalSpent));
	else
		Atr_Buy_Session_Text:SetText ("");
	end

end

-----------------------------------------

local function Atr_Buy_AddBackToScan(itemName, stackSize, buyoutPrice, howMany)

	if (howMany == nil) then
		howMany = 1;
	end

	local scan = Atr_FindScan (itemName);

	scan:AddScanItem (itemName, stackSize, buyoutPrice, nil, howMany);
	scan:CondenseAndSort ();

	local currentPane = Atr_GetCurrentPane();
	if (currentPane) then
		currentPane.UINeedsUpdate = true;
	end

end

-----------------------------------------

local function Atr_Buy_ClearPendingBuy()

	gAtr_Buy_PendingBuy = nil;

end

-----------------------------------------

local function Atr_Buy_TrackPendingBuy(numAuctions)

	gAtr_Buy_PendingBuy = {
		itemName	= gAtr_Buy_ItemName;
		stackSize	= gAtr_Buy_StackSize;
		buyoutPrice	= gAtr_Buy_BuyoutPrice;
		numAuctions	= numAuctions;
		itemsPerAuction	= gAtr_Buy_StackSize;
		spentPerAuction	= gAtr_Buy_BuyoutPrice;
		when		= time();
	};

end

-----------------------------------------

function Atr_Buy_OnErrorMessage(msg)

	if (not gAtr_Buy_PendingBuy or not msg) then
		return false;
	end

	local msgLC = string.lower(msg);

	if (time() - gAtr_Buy_PendingBuy.when > 5) then
		Atr_Buy_ClearPendingBuy();
		return false;
	end

	if (not (string.find(msgLC, "item was not found", 1, true)
		or string.find(msgLC, "item not found", 1, true)
		or string.find(msgLC, "auction doesn't exist", 1, true)
		or string.find(msgLC, "auction does not exist", 1, true)
		or string.find(msgLC, "auction not found", 1, true))) then
		return false;
	end

	gAtr_Buy_Session_NumBought = math.max(0, gAtr_Buy_Session_NumBought - gAtr_Buy_PendingBuy.itemsPerAuction);
	gAtr_Buy_Session_TotalSpent = math.max(0, gAtr_Buy_Session_TotalSpent - gAtr_Buy_PendingBuy.spentPerAuction);
	gAtr_Buy_NumBought = math.max(0, gAtr_Buy_NumBought - 1);
	gAtr_Buy_PendingBuy.numAuctions = gAtr_Buy_PendingBuy.numAuctions - 1;

	Atr_Buy_AddBackToScan(gAtr_Buy_PendingBuy.itemName, gAtr_Buy_PendingBuy.stackSize, gAtr_Buy_PendingBuy.buyoutPrice, 1);
	Atr_Buy_UpdateSessionText();

	if (gAtr_Buy_PendingBuy.numAuctions <= 0) then
		Atr_Buy_ClearPendingBuy();
	end

	if (gAtr_Buy_ChainMode) then
		gAtr_Buy_ChainReady = false;
		Atr_Buy_Chain_SetRowsEnabled(false);
		Atr_Buy_Chain_SetStatus("Ascension rejected that auction as stale/not found. Refreshing the individual list...");
		Atr_BuyState = ATR_BUY_JUST_BOUGHT;
		gAtr_Buy_Waiting_Start = time();
	end

	return true;

end

-----------------------------------------

local function Atr_Buy_ResetSession()

	gAtr_Buy_Session_NumBought = 0;
	gAtr_Buy_Session_TotalSpent = 0;
	Atr_Buy_ClearPendingBuy();
	Atr_Buy_UpdateSessionText();

end

-----------------------------------------

local function Atr_Buy_ShowLoadingState()

	Atr_Buy_Confirm_OKBut:SetText (ZT("Buy"))
	Atr_Buy_Confirm_OKBut:Disable();
	Atr_Buy_UpdateSessionText();

	if (Atr_Buy_IsChainChecked()) then
		Atr_Buy_Continue_Text:SetText ("Refreshing auctions...");
		Atr_Buy_Part1:Hide();
		Atr_Buy_Part2:Show();
	end

end

-----------------------------------------

local function Atr_Buy_ShowCurrentSelection(openMultipleDirect)

	local currentPane = Atr_GetCurrentPane();
	local scan = currentPane.activeScan;
	local data = scan.sortedData[currentPane.currIndex];

	gAtr_Buy_Query			= Atr_NewQuery();
	gAtr_Buy_NumUserWants	= -1;
	gAtr_Buy_NumBought		= 0;
	
	gAtr_Buy_BuyoutPrice	= data.buyoutPrice;
	gAtr_Buy_ItemName		= scan.itemName;
	gAtr_Buy_StackSize		= data.stackSize;
	gAtr_Buy_MaxCanBuy		= data.count;
	gAtr_Buy_Pass			= 1;		-- - first pass
	
	Atr_Buy_Confirm_ItemName:SetText (gAtr_Buy_ItemName.." x"..gAtr_Buy_StackSize);
	Atr_Buy_Confirm_Numstacks:SetNumber (1);
	Atr_Buy_Confirm_Max_Text:SetText (ZT("max")..": "..gAtr_Buy_MaxCanBuy);
	Atr_Buy_UpdateSessionText();
	
	Atr_Buy_Part1:Show();
	Atr_Buy_Part2:Hide();
	
	Atr_Buy_Confirm_OKBut:SetText (ZT("Buy"))
	Atr_Buy_Confirm_OKBut:Disable();

	Atr_HighlightEntry(currentPane.currIndex);

	-- Direct Buy Multiple deliberately skips the normal confirmation dialog.
	-- Ascension's auction/dress-up UI has custom panel behavior, so keep the
	-- multiple-buy workflow isolated in its own frame from the first click.
	if (openMultipleDirect) then
		Atr_Buy_Confirm_Frame:Hide();
		Atr_Buy_Chain_Open();
		return;
	end

	Atr_Buy_Confirm_Frame:Show();

	if (scan.searchWasExact and data.minpage ~= nil) then
		Atr_Buy_QueueQuery(data.minpage);
	else
		Atr_Buy_QueueQuery(0);
	end

end

-----------------------------------------

function Atr_Buy_ChainAdvance()

	if (not Atr_Buy_IsChainChecked()) then
		return false;
	end

	local currentPane = Atr_GetCurrentPane();
	local scan = currentPane.activeScan;
	local startIndex = currentPane.currIndex or 0;
	local x;

	for x = startIndex, #scan.sortedData do
		local data = scan.sortedData[x];

		if (Atr_Buy_IsBuyableData(data) and (data.stackSize ~= gAtr_Buy_StackSize or data.buyoutPrice ~= gAtr_Buy_BuyoutPrice)) then
			currentPane.currIndex = x;
			Atr_Buy_ShowCurrentSelection();
			return true;
		end
	end

	return false;

end

-----------------------------------------

function Atr_Buy_ChainContinue()

	if (not Atr_Buy_IsChainChecked()) then
		return false;
	end

	local currentPane = Atr_GetCurrentPane();
	local scan = currentPane.activeScan;
	local data = scan.sortedData[currentPane.currIndex];
	local boughtRequestedQty = (gAtr_Buy_NumUserWants ~= -1 and gAtr_Buy_NumBought > 0 and gAtr_Buy_NumUserWants <= gAtr_Buy_NumBought);

	if (boughtRequestedQty and gAtr_Buy_NumBought < gAtr_Buy_MaxCanBuy and Atr_Buy_IsBuyableData(data) and data.stackSize == gAtr_Buy_StackSize and data.buyoutPrice == gAtr_Buy_BuyoutPrice and data.count > 0) then
		Atr_Buy_ShowCurrentSelection();
		return true;
	end

	return Atr_Buy_ChainAdvance();

end


-----------------------------------------

function Atr_Buy_Chain_SetStatus(text)

	if (gAtr_Buy_ChainFrame and gAtr_Buy_ChainFrame.statusText) then
		gAtr_Buy_ChainFrame.statusText:SetText(text or "");
	end

end

-----------------------------------------

function Atr_Buy_Chain_SetRowsEnabled(enabled)

	if (not gAtr_Buy_ChainFrame or not gAtr_Buy_ChainFrame.rows) then
		return;
	end

	local i;
	for i = 1, #gAtr_Buy_ChainFrame.rows do
		local row = gAtr_Buy_ChainFrame.rows[i];
		if (row:IsShown() and row.buyButton) then
			if (enabled) then
				row.buyButton:Enable();
			else
				row.buyButton:Disable();
			end
		end
	end

end

-----------------------------------------

function Atr_Buy_Chain_RefreshVisibleRows()

	if (not gAtr_Buy_ChainFrame) then
		return;
	end

	local total = #gAtr_Buy_ChainRows;
	local maxOffset = math.max(0, total - gAtr_Buy_ChainRowsPerPage);
	if (gAtr_Buy_ChainDisplayOffset > maxOffset) then
		gAtr_Buy_ChainDisplayOffset = maxOffset;
	end
	if (gAtr_Buy_ChainDisplayOffset < 0) then
		gAtr_Buy_ChainDisplayOffset = 0;
	end

	local i;
	for i = 1, gAtr_Buy_ChainRowsPerPage do
		local rowFrame = gAtr_Buy_ChainFrame.rows[i];
		local data = gAtr_Buy_ChainRows[gAtr_Buy_ChainDisplayOffset + i];

		if (data) then
			rowFrame.numberText:SetText("#"..(gAtr_Buy_ChainDisplayOffset + i));
			rowFrame.itemText:SetText(data.name.." x"..data.count);
			rowFrame.ownerText:SetText(data.owner or "Unknown seller");
			rowFrame.priceText:SetText(Atr_Buy_CoinString(data.buyoutPrice));
			rowFrame.indexText:SetText("AH row "..data.auctionIndex);

			rowFrame.buyButton.auctionIndex = data.auctionIndex;
			rowFrame.buyButton.expectedName = data.name;
			rowFrame.buyButton.expectedCount = data.count;
			rowFrame.buyButton.expectedPrice = data.buyoutPrice;
			rowFrame:Show();

			if (gAtr_Buy_ChainReady) then
				rowFrame.buyButton:Enable();
			else
				rowFrame.buyButton:Disable();
			end
		else
			rowFrame:Hide();
		end
	end

	if (gAtr_Buy_ChainDisplayOffset > 0) then
		gAtr_Buy_ChainFrame.prevButton:Enable();
	else
		gAtr_Buy_ChainFrame.prevButton:Disable();
	end

	if (gAtr_Buy_ChainDisplayOffset + gAtr_Buy_ChainRowsPerPage < total) then
		gAtr_Buy_ChainFrame.nextButton:Enable();
	else
		gAtr_Buy_ChainFrame.nextButton:Disable();
	end

	if (total > 0) then
		local first = gAtr_Buy_ChainDisplayOffset + 1;
		local last = math.min(total, gAtr_Buy_ChainDisplayOffset + gAtr_Buy_ChainRowsPerPage);
		gAtr_Buy_ChainFrame.pageText:SetText(string.format("Showing %d-%d of %d matching auctions", first, last, total));
	else
		gAtr_Buy_ChainFrame.pageText:SetText("No matching auctions on this page");
	end

end

-----------------------------------------

function Atr_Buy_Chain_ShowPreviousRows()

	gAtr_Buy_ChainDisplayOffset = math.max(0, gAtr_Buy_ChainDisplayOffset - gAtr_Buy_ChainRowsPerPage);
	Atr_Buy_Chain_RefreshVisibleRows();

end

-----------------------------------------

function Atr_Buy_Chain_ShowNextRows()

	gAtr_Buy_ChainDisplayOffset = gAtr_Buy_ChainDisplayOffset + gAtr_Buy_ChainRowsPerPage;
	Atr_Buy_Chain_RefreshVisibleRows();

end

-----------------------------------------

function Atr_Buy_Chain_CreateFrame()

	if (gAtr_Buy_ChainFrame) then
		return;
	end

	local frame = CreateFrame("Frame", "Atr_Buy_Chain_Frame", UIParent);
	gAtr_Buy_ChainFrame = frame;
	frame:SetWidth(610);
	frame:SetHeight(430);
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
	frame:SetFrameStrata("FULLSCREEN_DIALOG");
	frame:SetMovable(true);
	frame:EnableMouse(true);
	frame:RegisterForDrag("LeftButton");
	frame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 }
	});
	frame:SetBackdropColor(0.03, 0.03, 0.03, 0.96);
	frame:SetBackdropBorderColor(1.0, 0.72, 0.18, 1.0);
	frame:SetScript("OnDragStart", function(self) self:StartMoving(); end);
	frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); end);
	frame:Hide();

	frame.titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	frame.titleText:SetPoint("TOP", frame, "TOP", 0, -18);
	frame.titleText:SetText("Auctionator - Buy Multiple");

	frame.itemText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	frame.itemText:SetPoint("TOP", frame, "TOP", 0, -43);
	frame.itemText:SetWidth(570);
	frame.itemText:SetJustifyH("CENTER");

	frame.helpText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	frame.helpText:SetPoint("TOP", frame, "TOP", 0, -62);
	frame.helpText:SetWidth(570);
	frame.helpText:SetJustifyH("CENTER");
	frame.helpText:SetText("Each row is one live auction. Click Buy once per auction; the list refreshes after every purchase.");

	local headerY = -88;
	local headers = {
		{ text = "Entry", x = 22 },
		{ text = "Item", x = 72 },
		{ text = "Seller", x = 247 },
		{ text = "Price", x = 382 },
		{ text = "Action", x = 505 },
	};
	local h;
	for h = 1, #headers do
		local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
		fs:SetPoint("TOPLEFT", frame, "TOPLEFT", headers[h].x, headerY);
		fs:SetText(headers[h].text);
	end

	frame.rows = {};
	local i;
	for i = 1, gAtr_Buy_ChainRowsPerPage do
		local row = CreateFrame("Frame", nil, frame);
		row:SetWidth(570);
		row:SetHeight(27);
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -105 - ((i - 1) * 28));
		row:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" });
		row:SetBackdropColor(0.08, 0.08, 0.08, 0.70);

		row.numberText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		row.numberText:SetPoint("LEFT", row, "LEFT", 4, 0);
		row.numberText:SetWidth(42);
		row.numberText:SetJustifyH("LEFT");

		row.itemText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		row.itemText:SetPoint("LEFT", row, "LEFT", 52, 0);
		row.itemText:SetWidth(170);
		row.itemText:SetJustifyH("LEFT");

		row.ownerText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		row.ownerText:SetPoint("LEFT", row, "LEFT", 227, 0);
		row.ownerText:SetWidth(128);
		row.ownerText:SetJustifyH("LEFT");

		row.priceText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		row.priceText:SetPoint("LEFT", row, "LEFT", 357, 0);
		row.priceText:SetWidth(105);
		row.priceText:SetJustifyH("LEFT");

		row.indexText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
		row.indexText:SetPoint("RIGHT", row, "RIGHT", -84, 0);
		row.indexText:SetWidth(64);
		row.indexText:SetJustifyH("RIGHT");

		row.buyButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate");
		row.buyButton:SetWidth(72);
		row.buyButton:SetHeight(22);
		row.buyButton:SetPoint("RIGHT", row, "RIGHT", -2, 0);
		row.buyButton:SetText("Buy");
		row.buyButton:SetScript("OnClick", Atr_Buy_Chain_BuyButton_OnClick);

		frame.rows[i] = row;
		row:Hide();
	end

	frame.statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	frame.statusText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 52);
	frame.statusText:SetWidth(565);
	frame.statusText:SetJustifyH("LEFT");

	frame.pageText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	frame.pageText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 31);
	frame.pageText:SetWidth(260);
	frame.pageText:SetJustifyH("CENTER");

	frame.prevButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	frame.prevButton:SetWidth(80);
	frame.prevButton:SetHeight(22);
	frame.prevButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 18);
	frame.prevButton:SetText("Prev Rows");
	frame.prevButton:SetScript("OnClick", Atr_Buy_Chain_ShowPreviousRows);

	frame.nextButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	frame.nextButton:SetWidth(80);
	frame.nextButton:SetHeight(22);
	frame.nextButton:SetPoint("LEFT", frame.prevButton, "RIGHT", 6, 0);
	frame.nextButton:SetText("Next Rows");
	frame.nextButton:SetScript("OnClick", Atr_Buy_Chain_ShowNextRows);

	frame.refreshButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	frame.refreshButton:SetWidth(80);
	frame.refreshButton:SetHeight(22);
	frame.refreshButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -106, 18);
	frame.refreshButton:SetText("Refresh");
	frame.refreshButton:SetScript("OnClick", Atr_Buy_Chain_ManualRefresh);

	frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	frame.closeButton:SetWidth(80);
	frame.closeButton:SetHeight(22);
	frame.closeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 18);
	frame.closeButton:SetText("Close");
	frame.closeButton:SetScript("OnClick", Atr_Buy_Chain_Close);

end

-----------------------------------------

local function Atr_Buy_Chain_BuildCurrentPage()

	gAtr_Buy_ChainRows = {};

	local numBatchAuctions = GetNumAuctionItems("list");
	local i;
	for i = numBatchAuctions, 1, -1 do
		local name, _, count, _, _, _, _, _, buyoutPrice, _, _, owner = GetAuctionItemInfo("list", i);

		if (name and zc.StringSame(name, gAtr_Buy_ItemName) and count == gAtr_Buy_StackSize and buyoutPrice == gAtr_Buy_BuyoutPrice) then
			table.insert(gAtr_Buy_ChainRows, {
				auctionIndex = i,
				name = name,
				count = count,
				buyoutPrice = buyoutPrice,
				owner = owner,
			});
		end
	end

	gAtr_Buy_ChainDisplayOffset = 0;

end

-----------------------------------------

function Atr_Buy_Chain_ProcessQueryResults()

	Atr_BuyState = ATR_BUY_PROCESSING_QUERY_RESULTS;
	Atr_Buy_Chain_BuildCurrentPage();

	local total = #gAtr_Buy_ChainRows;
	local isLastPage = gAtr_Buy_Query:IsLastPage(gAtr_Buy_CurPage);

	if (total > 0) then
		gAtr_Buy_ChainReady = true;
		Atr_Buy_Chain_SetStatus(string.format("Ready: %d matching auction%s on AH page %d. Click one Buy button.", total, total == 1 and "" or "s", gAtr_Buy_CurPage + 1));
		Atr_Buy_Chain_RefreshVisibleRows();
	elseif (not isLastPage) then
		gAtr_Buy_ChainReady = false;
		Atr_Buy_Chain_RefreshVisibleRows();
		Atr_Buy_Chain_SetStatus(string.format("No matching entries on AH page %d. Checking the next page...", gAtr_Buy_CurPage + 1));
		Atr_Buy_QueueQuery(gAtr_Buy_CurPage + 1);
	else
		gAtr_Buy_ChainReady = false;
		Atr_Buy_Chain_RefreshVisibleRows();
		Atr_Buy_Chain_SetStatus("No matching auctions remain at this stack size and price.");
	end

end

-----------------------------------------

function Atr_Buy_Chain_ManualRefresh()

	if (not gAtr_Buy_ChainMode) then
		return;
	end

	gAtr_Buy_ChainReady = false;
	Atr_Buy_Chain_SetRowsEnabled(false);
	Atr_Buy_Chain_SetStatus("Refreshing this auction page...");
	Atr_Buy_QueueQuery(gAtr_Buy_CurPage or 0);

end

-----------------------------------------

function Atr_Buy_Chain_BuyButton_OnClick(self)

	if (not gAtr_Buy_ChainMode or not gAtr_Buy_ChainReady) then
		return;
	end

	local auctionIndex = self.auctionIndex;
	if (not auctionIndex) then
		return;
	end

	local name, _, count, _, _, _, _, _, buyoutPrice = GetAuctionItemInfo("list", auctionIndex);

	-- Revalidate the exact live AH row at the instant of the hardware click.
	-- If Ascension has already moved/replaced the row, do not send a bid at all.
	if (not name or not zc.StringSame(name, self.expectedName) or count ~= self.expectedCount or buyoutPrice ~= self.expectedPrice) then
		gAtr_Buy_ChainReady = false;
		Atr_Buy_Chain_SetRowsEnabled(false);
		Atr_Buy_Chain_SetStatus("That auction row changed before the click. No purchase was sent; refreshing...");
		Atr_Buy_QueueQuery(gAtr_Buy_CurPage or 0);
		return;
	end

	if (GetMoney() < buyoutPrice) then
		Atr_Buy_Chain_SetStatus("You do not have enough gold for this auction.");
		return;
	end

	gAtr_Buy_ChainReady = false;
	Atr_Buy_Chain_SetRowsEnabled(false);
	Atr_Buy_Chain_SetStatus(string.format("Purchase sent for AH row %d. Waiting for Ascension to refresh the list...", auctionIndex));

	Atr_Buy_TrackPendingBuy(1);
	gAtr_Buy_NumBought = gAtr_Buy_NumBought + 1;
	gAtr_Buy_Session_NumBought = gAtr_Buy_Session_NumBought + gAtr_Buy_StackSize;
	gAtr_Buy_Session_TotalSpent = gAtr_Buy_Session_TotalSpent + gAtr_Buy_BuyoutPrice;
	Atr_Buy_UpdateSessionText();
	AuctionatorSubtractFromScan(gAtr_Buy_ItemName, gAtr_Buy_StackSize, gAtr_Buy_BuyoutPrice, 1);

	-- This is intentionally the only protected action in chain mode, and it is
	-- executed directly inside this button's OnClick hardware event.
	PlaceAuctionBid("list", auctionIndex, buyoutPrice);

	Atr_BuyState = ATR_BUY_JUST_BOUGHT;
	gAtr_Buy_Waiting_Start = time();

end

-----------------------------------------

function Atr_Buy_Chain_Open()

	if (not Atr_ShowingCurrentAuctions()) then
		return;
	end

	Atr_Buy_Chain_CreateFrame();
	gAtr_Buy_ChainMode = true;
	gAtr_Buy_ChainReady = false;
	gAtr_Buy_ChainRows = {};
	gAtr_Buy_ChainDisplayOffset = 0;
	gAtr_Buy_Query = Atr_NewQuery();
	gAtr_Buy_Pass = 1;

	Atr_Buy_Confirm_Frame:Hide();
	gAtr_Buy_ChainFrame.itemText:SetText(gAtr_Buy_ItemName.." x"..gAtr_Buy_StackSize.."  -  "..Atr_Buy_CoinString(gAtr_Buy_BuyoutPrice).." each");
	gAtr_Buy_ChainFrame:Show();
	Atr_Buy_Chain_RefreshVisibleRows();
	Atr_Buy_Chain_SetStatus("Loading a fresh list of individual auctions...");

	local currentPane = Atr_GetCurrentPane();
	local scan = currentPane and currentPane.activeScan;
	local data = scan and scan.sortedData[currentPane.currIndex];
	if (scan and data and scan.searchWasExact and data.minpage ~= nil) then
		Atr_Buy_QueueQuery(data.minpage);
	else
		Atr_Buy_QueueQuery(0);
	end

end

-----------------------------------------

function Atr_Buy_Chain_CB_OnClick()

	if (Atr_Buy_IsChainChecked()) then
		Atr_Buy_Chain_Open();
	end

end

-----------------------------------------

function Atr_Buy_Chain_Close()

	gAtr_Buy_ChainMode = false;
	gAtr_Buy_ChainReady = false;
	gAtr_Buy_ChainRows = {};
	Atr_BuyState = ATR_BUY_NULL;
	Atr_Buy_ClearPendingBuy();

	if (gAtr_Buy_ChainFrame) then
		gAtr_Buy_ChainFrame:Hide();
	end
	if (Atr_Buy_Chain_CB) then
		Atr_Buy_Chain_CB:SetChecked(false);
	end

end

-----------------------------------------

function Atr_Buy_Debug1 (yellow)

	if (Atr_BuyState == ATR_BUY_NULL)										then asstr = "ATR_BUY_NULL"; end;
	if (Atr_BuyState == ATR_BUY_QUERY_SENT)								then asstr = "ATR_BUY_QUERY_SENT"; end;
	if (Atr_BuyState == ATR_BUY_PROCESSING_QUERY_RESULTS)					then asstr = "ATR_BUY_PROCESSING_QUERY_RESULTS"; end;
	if (Atr_BuyState == ATR_BUY_JUST_BOUGHT)								then asstr = "ATR_BUY_JUST_BOUGHT"; end;
	if (Atr_BuyState == ATR_BUY_WAITING_FOR_AH_CAN_SEND)					then asstr = "ATR_BUY_WAITING_FOR_AH_CAN_SEND"; end;

	if (Atr_BuyState ~= ATR_BUY_NULL) then
		if (yellow) then
			zc.msg (asstr, "curpage: ", gAtr_Buy_CurPage, "   gAtr_Buy_NumBought: ", gAtr_Buy_NumBought);
		else
			zc.msg_pink (asstr, "curpage: ", gAtr_Buy_CurPage, "   gAtr_Buy_NumBought: ", gAtr_Buy_NumBought);
		end
	end
	
end

-----------------------------------------

function Atr_ClearBuyState()

	Atr_BuyState = ATR_BUY_NULL;
	Atr_Buy_ClearPendingBuy();
	gAtr_Buy_ChainMode = false;
	gAtr_Buy_ChainReady = false;
	gAtr_Buy_ChainRows = {};
	if (gAtr_Buy_ChainFrame) then
		gAtr_Buy_ChainFrame:Hide();
	end

end


-----------------------------------------

function Atr_Buy1_Onclick ()

	if (not Atr_ShowingCurrentAuctions()) then
		return;
	end
	
	Atr_Buy_ResetSession();
	Atr_Buy_ShowCurrentSelection(false);

end

-----------------------------------------

function Atr_Buy_Multiple_Onclick ()

	if (not Atr_ShowingCurrentAuctions()) then
		return;
	end

	local currentPane = Atr_GetCurrentPane();
	local scan = currentPane and currentPane.activeScan;
	local data = scan and currentPane.currIndex and scan.sortedData[currentPane.currIndex];

	if (not Atr_Buy_IsBuyableData(data)) then
		return;
	end

	Atr_Buy_ResetSession();
	Atr_Buy_ShowCurrentSelection(true);

end

-----------------------------------------

function Atr_Buy_QueueQuery (page)

	gAtr_Buy_CurPage = page;

--zc.msg_pink ("Queuing query for page ", page);

	Atr_BuyState = ATR_BUY_WAITING_FOR_AH_CAN_SEND;
	gAtr_Buy_Waiting_Start = time();
	
	Atr_Buy_SendQuery();		-- give it a shot
end

-----------------------------------------

function Atr_Buy_SendQuery ()

	if (CanSendAuctionQuery()) then

		Atr_BuyState = ATR_BUY_QUERY_SENT;

		local queryString = zc.UTF8_Truncate (gAtr_Buy_ItemName,63);	-- attempting to reduce number of disconnects

		QueryAuctionItems (queryString, "", "", nil, 0, 0, gAtr_Buy_CurPage, nil, nil);
	end
		
end

-----------------------------------------
local prevBuyState;

-----------------------------------------

function Atr_Buy_Idle ()

	if (gAtr_Buy_PendingBuy and time() - gAtr_Buy_PendingBuy.when > 5) then
		Atr_Buy_ClearPendingBuy();
	end

	if (Atr_BuyState ~= prevBuyState) then
		prevBuyState = Atr_BuyState;
--		Atr_Buy_Debug1 (true);
	end
	
	if (Atr_BuyState == ATR_BUY_WAITING_FOR_AH_CAN_SEND) then
	
--		zc.md ("WAITING_FOR_AH_CAN_SEND: ", time() - gAtr_Buy_Waiting_Start);
		
		if (GetMoney() < gAtr_Buy_BuyoutPrice) then
			Atr_Buy_Cancel (ZT("You do not have enough gold\n\nto make any more purchases."));
		elseif (time() - gAtr_Buy_Waiting_Start > 10) then
			Atr_Buy_Cancel (ZT("Auction House timed out"));
		else	
			Atr_Buy_SendQuery ();
		end
		
	elseif (Atr_BuyState == ATR_BUY_JUST_BOUGHT) then

--		zc.msg_pink ("ATR_BUY_JUST_BOUGHT: ",  time() - gAtr_Buy_Waiting_Start);

		local queueIf = (time() - gAtr_Buy_Waiting_Start > ATR_BUY_POST_BUY_DELAY);		-- wait a moment for Auction List to Update after buys

		if (queueIf and gAtr_Buy_ChainMode) then
			-- Never perform another protected purchase here.  Chain mode only
			-- refreshes the live rows; the next PlaceAuctionBid() requires the
			-- player's next click on an individual Buy button.
			Atr_Buy_QueueQuery(gAtr_Buy_CurPage or 0);
		elseif (queueIf) then
			if (Atr_Buy_IsComplete()) then
				if (not Atr_Buy_ChainContinue()) then
					Atr_Buy_Cancel();
				end
			else
				Atr_Buy_QueueQuery(gAtr_Buy_CurPage);
			end
		end
		
	end

end

-----------------------------------------

function Atr_Buy_OnAuctionUpdate()

--	Atr_Buy_Debug1();

	if (Atr_BuyState == ATR_BUY_QUERY_SENT) then
		if (gAtr_Buy_ChainMode) then
			Atr_Buy_Chain_ProcessQueryResults();
		else
			Atr_Buy_CheckForMatches ();
		end
	end

	return (Atr_BuyState ~= ATR_BUY_NULL);
end

-----------------------------------------

function Atr_Buy_CheckForMatches ()

	Atr_BuyState = ATR_BUY_PROCESSING_QUERY_RESULTS;
	Atr_Buy_ClearPendingBuy();
	
	if (gAtr_Buy_Query:CheckForDuplicatePage(gAtr_Buy_CurPage)) then
		Atr_Buy_QueueQuery (gAtr_Buy_CurPage);
		return;
	end

	local isLastPage = gAtr_Buy_Query:IsLastPage(gAtr_Buy_CurPage);
	
	local numMatches = Atr_Buy_CountMatches();
	
	if (numMatches > 0) then		-- update the confirmation screen
	
		if (gAtr_Buy_NumUserWants ~= -1) then		
			-- Ascension protects PlaceAuctionBid(). Never continue a purchase
			-- automatically from an auction-list update; the next purchase must
			-- originate from the player's next hardware click.
			Atr_Buy_Continue_Text:SetText (string.format (ZT("%d of %d bought so far"), gAtr_Buy_NumBought, gAtr_Buy_NumUserWants));
			Atr_Buy_Part1:Hide();
			Atr_Buy_Part2:Show();
			Atr_Buy_Confirm_OKBut:SetText (ZT("Buy Next"))
			Atr_Buy_Confirm_OKBut:Enable();
		else
			Atr_Buy_Confirm_OKBut:Enable();
		end

	else
		Atr_Buy_NextPage_Or_Cancel();
	end

end


-----------------------------------------

function Atr_Buy_BuyMatches ()
	return Atr_Buy_CountMatches (true);
end

-----------------------------------------

function Atr_Buy_BuyNextMatch ()

	if (GetMoney() < gAtr_Buy_BuyoutPrice) then
		Atr_Buy_Cancel (ZT("You do not have enough gold\n\nto make any more purchases."));
		return;
	end

	local _, numJustBought = Atr_Buy_BuyMatches ();

	if (numJustBought > 0) then

--zc.msg (numJustBought, " from page ", gAtr_Buy_CurPage);
	
		Atr_Buy_TrackPendingBuy(numJustBought);
		gAtr_Buy_Session_NumBought = gAtr_Buy_Session_NumBought + (numJustBought * gAtr_Buy_PendingBuy.itemsPerAuction);
		gAtr_Buy_Session_TotalSpent = gAtr_Buy_Session_TotalSpent + (numJustBought * gAtr_Buy_PendingBuy.spentPerAuction);
		AuctionatorSubtractFromScan (gAtr_Buy_ItemName, gAtr_Buy_StackSize, gAtr_Buy_BuyoutPrice, numJustBought);
		Atr_BuyState = ATR_BUY_JUST_BOUGHT;
		gAtr_Buy_Waiting_Start = time();
		Atr_Buy_ShowLoadingState();
	else
		Atr_Buy_NextPage_Or_Cancel();
	end
	
end

-----------------------------------------

function Atr_Buy_CountMatches (andBuy)

	local numMatches		= 0;
	local numBoughtThisPage	= 0;
	local buyIndex			= nil;
	local i = 1;

	-- Build a stable view of the page before buying anything. Ascension can
	-- remove/reindex an auction immediately after PlaceAuctionBid(), so buying
	-- while this loop is still walking upward makes later indexes stale.
	while (true) do
	
		local name, _, count, _, _, _, _, _, buyoutPrice, _ = GetAuctionItemInfo ("list", i);

		if (name == nil) then
			break;
		end

		if (zc.StringSame (name, gAtr_Buy_ItemName) and buyoutPrice == gAtr_Buy_BuyoutPrice and count == gAtr_Buy_StackSize) then
			
			numMatches = numMatches + 1;

			-- Keep the highest matching row. Removing a higher row does not
			-- invalidate the lower rows that remain for the next refresh.
			if (andBuy and gAtr_Buy_NumUserWants > gAtr_Buy_NumBought) then
				buyIndex = i;
			end
		end

		i = i + 1;
	end

	-- One protected auction action per player click. The refreshed page will
	-- enable the button as "Buy Next" for the following purchase.
	if (andBuy and buyIndex ~= nil and gAtr_Buy_NumUserWants > gAtr_Buy_NumBought) then
		PlaceAuctionBid("list", buyIndex, gAtr_Buy_BuyoutPrice);
		numBoughtThisPage = 1;
		gAtr_Buy_NumBought = gAtr_Buy_NumBought + 1;
	end

	return numMatches, numBoughtThisPage;
end



-----------------------------------------

function Atr_Buy_Confirm_Update ()

	local num = Atr_Buy_Confirm_Numstacks:GetNumber();

	if (num == 1) then
		Atr_Buy_Confirm_Text2:SetText (ZT("stack for"));
	else
		Atr_Buy_Confirm_Text2:SetText (ZT("stacks for"));
	end

	MoneyFrame_Update ("Atr_Buy_Confirm_TotalPrice",  gAtr_Buy_BuyoutPrice * num);

end

-----------------------------------------

function Atr_Buy_NextPage_Or_Cancel ( queueIf )

	if (Atr_Buy_IsComplete()) then

		if (not Atr_Buy_ChainContinue()) then
			Atr_Buy_Cancel();
		end
		
	elseif (queueIf == nil or queueIf == true) then
	
		if (Atr_Buy_IsFirstPassComplete()) then
			gAtr_Buy_Pass = 2;
			Atr_Buy_QueueQuery(0);
		else
			Atr_Buy_QueueQuery(gAtr_Buy_CurPage + 1);
		end
	end
end

-----------------------------------------

function Atr_Buy_IsComplete ()

	if (gAtr_Buy_NumUserWants ~= -1 and gAtr_Buy_NumUserWants <= gAtr_Buy_NumBought) then
		return true;
	end

	if (gAtr_Buy_Query:IsLastPage(gAtr_Buy_CurPage) and gAtr_Buy_Pass == 2) then
		return true;
	end

	return false;

end

-----------------------------------------

function Atr_Buy_IsFirstPassComplete ()

	if (gAtr_Buy_Query:IsLastPage(gAtr_Buy_CurPage) and gAtr_Buy_Pass == 1) then
		return true;
	end

	return false;

end

-----------------------------------------

function Atr_Buy_Confirm_OK ()

	if (Atr_Buy_IsChainChecked()) then
		Atr_Buy_Chain_Open();
		return;
	end

	if (gAtr_Buy_NumUserWants == -1) then
		local numToBuy = Atr_Buy_Confirm_Numstacks:GetNumber();

		if (numToBuy > gAtr_Buy_MaxCanBuy) then
			Atr_Error_Text:SetText (string.format (ZT("You can buy at most %d auctions"), gAtr_Buy_MaxCanBuy));
			Atr_Error_Frame:Show ();
			return;
		end
		
		gAtr_Buy_NumUserWants = numToBuy;
	end
	
	Atr_Buy_BuyNextMatch();
	
end

-----------------------------------------

function Atr_Buy_Wait_For_Bought_To_Clear ()

	zc.md ("Atr_Buy_Wait_For_Bought_To_Clear: ", time() - gAtr_Buy_Waiting_Start);
	
end

-----------------------------------------

function Atr_Buy_Cancel (msg)
	
	Atr_BuyState = ATR_BUY_NULL;
	gAtr_Buy_ChainMode = false;
	gAtr_Buy_ChainReady = false;

	Atr_Buy_Confirm_Frame:Hide();
	if (gAtr_Buy_ChainFrame) then
		gAtr_Buy_ChainFrame:Hide();
	end
	if (Atr_Buy_Chain_CB) then
		Atr_Buy_Chain_CB:SetChecked(false);
	end
	
	Atr_Error_Display(msg);
end


