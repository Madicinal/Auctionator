-- CoAuctionator +Mod 1.4
-- Presentation-only compatibility skin.
-- The CoA fork still contains the original Auctionator six-piece AH artwork,
-- but its inherited runtime paths point at Interface\AddOns\Auctionator.
-- Since this fork installs as CoAuctionator those paths no longer resolve.
-- Keep the newer CoA layout/logic, restore the intended Auctionator/Blizzard-style
-- frame artwork, and remove the flat black fallback canvases.

local textureBase = "Interface\\AddOns\\CoAuctionator\\Images\\";
local elapsedSinceSkin = 0;

local function ClearPanelBackdrop (panel)
    if (not panel) then return; end

    if (panel.SetBackdrop) then
        panel:SetBackdrop (nil);
    end

    if (panel.SetBackdropColor) then
        panel:SetBackdropColor (0, 0, 0, 0);
    end
end

local function ApplyClassicAuctionArt ()
    if (not AuctionFrame) then return; end

    if (AuctionFrameTopLeft)  then AuctionFrameTopLeft:SetTexture  (textureBase.."atr_topleft.blp"); end
    if (AuctionFrameTop)      then AuctionFrameTop:SetTexture      (textureBase.."atr_top.blp"); end
    if (AuctionFrameTopRight) then AuctionFrameTopRight:SetTexture (textureBase.."atr_topright.blp"); end
    if (AuctionFrameBotLeft)  then AuctionFrameBotLeft:SetTexture  (textureBase.."atr_botleft.blp"); end
    if (AuctionFrameBot)      then AuctionFrameBot:SetTexture      (textureBase.."atr_bot.blp"); end
    if (AuctionFrameBotRight) then AuctionFrameBotRight:SetTexture (textureBase.."atr_botright.blp"); end

    ClearPanelBackdrop (Atr_Panel_Sell);
    ClearPanelBackdrop (Atr_Panel_Buy);
    ClearPanelBackdrop (Atr_Panel_More);
    ClearPanelBackdrop (Atr_Panel_Inventory);
end

-- The CoA fork calls this whenever one of its full-canvas panels is shown.
-- Replacing only the presentation hook keeps all tab/search/buy logic unchanged.
function Atr_ApplyPanelSkin (frame)
    ClearPanelBackdrop (frame);
end

local skinController = CreateFrame ("Frame");
skinController:RegisterEvent ("AUCTION_HOUSE_SHOW");
skinController:SetScript ("OnEvent", function ()
    ApplyClassicAuctionArt();
end);

-- The inherited tab switcher rewrites the six texture paths each time a custom
-- Auctionator tab is selected. Reassert the renamed paths while the AH is open.
skinController:SetScript ("OnUpdate", function (self, elapsed)
    elapsedSinceSkin = elapsedSinceSkin + elapsed;
    if (elapsedSinceSkin < 0.20) then return; end
    elapsedSinceSkin = 0;

    if (AuctionFrame and AuctionFrame:IsShown()) then
        ApplyClassicAuctionArt();
    end
end);
