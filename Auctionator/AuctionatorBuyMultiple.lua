local addonName, addonTable = ...;
local zc = addonTable.zc;

-- This module is intentionally presentation-only. AuctionatorBuy.lua owns
-- the query state, exact row validation, PlaceAuctionBid call, server ACK,
-- retries, stale-row handling and displayed-scan updates.

local frame;
local rows = {};
local currentMatches = {};
local rowsPerPage = 10;
local offset = 0;
local updateElapsed = 0;
local lastPurchaseSource = "none";

local function CoinText(copper)
    if GetCoinTextureString then return GetCoinTextureString(copper or 0); end
    local v = copper or 0;
    local g = math.floor(v / 10000);
    local s = math.floor((v % 10000) / 100);
    local c = v % 100;
    return g.."g "..s.."s "..c.."c";
end

local function SetButtonsEnabled(enabled)
    local i;
    for i = 1, #rows do
        if rows[i]:IsShown() then
            if enabled then rows[i].buy:Enable(); else rows[i].buy:Disable(); end
        end
    end
end

local function RefreshRows()
    if not frame then return; end

    local maxOffset = math.max(0, #currentMatches - rowsPerPage);
    if offset > maxOffset then offset = maxOffset; end
    if offset < 0 then offset = 0; end

    local i;
    for i = 1, rowsPerPage do
        local rf = rows[i];
        local d = currentMatches[offset + i];
        if d then
            rf.num:SetText("#"..(offset + i));
            rf.item:SetText((d.name or "Unknown").." x"..(d.count or 0));
            rf.owner:SetText(d.owner or "Unknown seller");
            rf.price:SetText(CoinText(d.price));
            rf.index:SetText("AH row "..d.index);
            rf.buy.auctionIndex = d.index;
            rf:Show();
            rf.buy:Enable();
        else
            rf:Hide();
        end
    end

    if offset > 0 then frame.prev:Enable(); else frame.prev:Disable(); end
    if offset + rowsPerPage < #currentMatches then frame.next:Enable(); else frame.next:Disable(); end

    if #currentMatches > 0 then
        frame.page:SetText(string.format("Showing %d-%d of %d live matching auctions", offset + 1, math.min(#currentMatches, offset + rowsPerPage), #currentMatches));
    else
        frame.page:SetText("No live matching auctions on this page");
    end
end

local function CreatePicker()
    if frame then return; end

    frame = CreateFrame("Frame", "Atr_BuyMultiple_Frame", UIParent);
    frame:SetWidth(640);
    frame:SetHeight(440);
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
    frame:SetFrameStrata("FULLSCREEN_DIALOG");
    frame:SetMovable(true);
    frame:EnableMouse(true);
    frame:RegisterForDrag("LeftButton");
    frame:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=16,
        insets={left=4,right=4,top=4,bottom=4}
    });
    frame:SetBackdropColor(0.03,0.03,0.03,0.96);
    frame:SetBackdropBorderColor(1.0,0.72,0.18,1.0);
    frame:SetScript("OnDragStart", function(self) self:StartMoving(); end);
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); end);
    frame:Hide();

    frame.title = frame:CreateFontString(nil,"OVERLAY","GameFontNormalLarge");
    frame.title:SetPoint("TOP",0,-18);
    frame.title:SetText("Auctionator - Buy Multiple");

    frame.item = frame:CreateFontString(nil,"OVERLAY","GameFontHighlight");
    frame.item:SetPoint("TOP",0,-43);
    frame.item:SetWidth(600);
    frame.item:SetJustifyH("CENTER");

    frame.help = frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");
    frame.help:SetPoint("TOP",0,-62);
    frame.help:SetWidth(600);
    frame.help:SetJustifyH("CENTER");
    frame.help:SetText("Each line is one live auction. Every Buy click is one protected purchase through the CoA buy engine.");

    local headers = {{"Entry",20},{"Item",68},{"Seller",252},{"Price",390},{"Action",530}};
    local h;
    for h = 1, #headers do
        local fs=frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");
        fs:SetPoint("TOPLEFT",frame,"TOPLEFT",headers[h][2],-90);
        fs:SetText(headers[h][1]);
    end

    local i;
    for i = 1, rowsPerPage do
        local rf=CreateFrame("Frame",nil,frame);
        rf:SetWidth(598); rf:SetHeight(27);
        rf:SetPoint("TOPLEFT",frame,"TOPLEFT",20,-107-((i-1)*28));
        rf:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background"});
        rf:SetBackdropColor(0.08,0.08,0.08,0.70);

        rf.num=rf:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");
        rf.num:SetPoint("LEFT",4,0); rf.num:SetWidth(40); rf.num:SetJustifyH("LEFT");
        rf.item=rf:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");
        rf.item:SetPoint("LEFT",50,0); rf.item:SetWidth(178); rf.item:SetJustifyH("LEFT");
        rf.owner=rf:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");
        rf.owner:SetPoint("LEFT",234,0); rf.owner:SetWidth(132); rf.owner:SetJustifyH("LEFT");
        rf.price=rf:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");
        rf.price:SetPoint("LEFT",372,0); rf.price:SetWidth(120); rf.price:SetJustifyH("LEFT");
        rf.index=rf:CreateFontString(nil,"OVERLAY","GameFontDisableSmall");
        rf.index:SetPoint("BOTTOMLEFT",50,1); rf.index:SetWidth(178); rf.index:SetJustifyH("LEFT");

        rf.buy=CreateFrame("Button",nil,rf,"UIPanelButtonTemplate");
        rf.buy:SetWidth(74); rf.buy:SetHeight(21); rf.buy:SetPoint("RIGHT",-4,0); rf.buy:SetText("Buy");
        rf.buy:SetScript("OnClick",function(self)
            if self.auctionIndex and Atr_Buy_Multiple_BuyIndex then
                lastPurchaseSource = "Buy Multiple row";
                SetButtonsEnabled(false);
                frame.status:SetText("Waiting for Auction House confirmation...");
                if Atr_Buy_Multiple_BuyIndex(self.auctionIndex) ~= 1 then
                    frame.status:SetText("That row changed before the click. Refreshing...");
                    if Atr_Buy_QueueQuery then Atr_Buy_QueueQuery(0); end
                end
            end
        end);
        rows[i]=rf;
    end

    frame.status=frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");
    frame.status:SetPoint("BOTTOM",0,57); frame.status:SetWidth(590); frame.status:SetJustifyH("CENTER");

    frame.page=frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");
    frame.page:SetPoint("BOTTOM",0,38); frame.page:SetWidth(300); frame.page:SetJustifyH("CENTER");

    frame.prev=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate");
    frame.prev:SetWidth(90); frame.prev:SetHeight(22); frame.prev:SetPoint("BOTTOMLEFT",20,18); frame.prev:SetText("Prev Rows");
    frame.prev:SetScript("OnClick",function() offset=math.max(0,offset-rowsPerPage); RefreshRows(); end);

    frame.next=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate");
    frame.next:SetWidth(90); frame.next:SetHeight(22); frame.next:SetPoint("LEFT",frame.prev,"RIGHT",8,0); frame.next:SetText("Next Rows");
    frame.next:SetScript("OnClick",function() offset=offset+rowsPerPage; RefreshRows(); end);

    frame.close=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate");
    frame.close:SetWidth(90); frame.close:SetHeight(22); frame.close:SetPoint("BOTTOMRIGHT",-20,18); frame.close:SetText("Done");
    frame.close:SetScript("OnClick",function() if Atr_Buy_Cancel then Atr_Buy_Cancel(nil,true); else frame:Hide(); end end);
end

function Atr_BuyMultiple_OnSearching(itemName, stackSize, price)
    CreatePicker();
    currentMatches={}; offset=0;
    frame.item:SetText((itemName or "").." x"..(stackSize or 0).." at "..CoinText(price));
    frame.status:SetText("Searching and validating live auctions...");
    frame.page:SetText("");
    RefreshRows();
    frame:Show();
end

function Atr_BuyMultiple_OnReady(matchList, itemName, stackSize, price, page)
    CreatePicker();
    currentMatches={}; offset=0;
    local i;
    for i = 1, #(matchList or {}) do
        local index=matchList[i];
        local name,_,count,_,_,_,_,_,buyout,_,_,owner=GetAuctionItemInfo("list",index);
        if name and count and buyout then
            table.insert(currentMatches,{index=index,name=name,count=count,price=buyout,owner=owner});
        end
    end
    table.sort(currentMatches,function(a,b) return a.index < b.index; end);
    frame.item:SetText((itemName or "").." x"..(stackSize or 0).." at "..CoinText(price));
    frame.status:SetText("Page "..((page or 0)+1).." validated. Choose the exact auction to buy.");
    RefreshRows();
    frame:Show();
end

function Atr_BuyMultiple_OnWaiting()
    if frame then
        SetButtonsEnabled(false);
        frame.status:SetText("Waiting for Auction House confirmation...");
    end
end

function Atr_BuyMultiple_Hide()
    if frame then frame:Hide(); end
    currentMatches={}; offset=0;
end

-- Tag the inherited confirmation path so ADDON_ACTION_BLOCKED tells us whether
-- Ascension rejected the native Buy/Buy Next path or the individual-row path.
if Atr_Buy_Confirm_OK then
    local upstreamConfirmOK = Atr_Buy_Confirm_OK;
    Atr_Buy_Confirm_OK = function(...)
        lastPurchaseSource = "native Buy / Buy Next";
        return upstreamConfirmOK(...);
    end
end

if Atr_Buy_BuyMatches then
    local upstreamBuyMatches = Atr_Buy_BuyMatches;
    Atr_Buy_BuyMatches = function(...)
        lastPurchaseSource = "legacy Atr_Buy_BuyMatches";
        return upstreamBuyMatches(...);
    end
end

local blockedWatch=CreateFrame("Frame");
blockedWatch:RegisterEvent("ADDON_ACTION_BLOCKED");
blockedWatch:RegisterEvent("ADDON_ACTION_FORBIDDEN");
blockedWatch:SetScript("OnEvent",function(self,event,addonName,functionName)
    addonName = addonName or arg1;
    functionName = functionName or arg2;
    if addonName == "Auctionator" and functionName and string.find(tostring(functionName),"PlaceAuctionBid",1,true) then
        if zc and zc.msg_atr then
            zc.msg_atr("Ascension blocked PlaceAuctionBid. Purchase path: "..tostring(lastPurchaseSource));
        end
    end
end);

local controller=CreateFrame("Frame");

local function EnsureBuyMultipleButton()
    if not Atr_Buy1_Button then return nil; end

    if not controller.button then
        -- Parent to AuctionFrame rather than the Buy button's content frame. The
        -- CoA fork creates full-canvas tab panels, and those could cover a late-created
        -- sibling button depending on skin/frame-level ordering.
        local parent = AuctionFrame or UIParent;
        controller.button=CreateFrame("Button","Atr_BuyMultiple_Button",parent,"UIPanelButtonTemplate");
        controller.button:SetWidth(105);
        controller.button:SetHeight(22);
        controller.button:SetPoint("RIGHT",Atr_Buy1_Button,"LEFT",-8,0);
        controller.button:SetText("Buy Multiple");
        controller.button:SetFrameStrata(Atr_Buy1_Button:GetFrameStrata());
        controller.button:SetFrameLevel(math.max((Atr_Buy1_Button:GetFrameLevel() or 1) + 8, (parent:GetFrameLevel() or 1) + 12));
        controller.button:SetScript("OnClick",function()
            if Atr_Buy_Multiple_Start then Atr_Buy_Multiple_Start(); end
        end);
    end

    return controller.button;
end

controller:SetScript("OnUpdate",function(self,elapsed)
    updateElapsed=updateElapsed+elapsed;
    if updateElapsed < 0.20 then return; end
    updateElapsed=0;

    local button=EnsureBuyMultipleButton();
    if not button then return; end

    -- Keep the button physically present next to Buy whenever the native Buy control
    -- is visible. Disabled state is still shown so users can tell the feature loaded.
    if Atr_Buy1_Button:IsShown() and (not AuctionFrame or AuctionFrame:IsShown()) then
        button:Show();
    else
        button:Hide();
        return;
    end

    local pane=Atr_GetCurrentPane and Atr_GetCurrentPane();
    local scan=pane and pane.activeScan;
    local data=scan and pane.currIndex and scan.sortedData[pane.currIndex];

    if data and not data.yours and not data.altname and (data.buyoutPrice or 0) > 0 and (data.count or 0) > 1 then
        button:Enable();
    else
        button:Disable();
    end
end);
