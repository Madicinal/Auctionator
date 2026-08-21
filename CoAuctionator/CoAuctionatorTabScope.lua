-- CoAuctionator +Mod 1.7
-- Strict ownership for controls that only make sense on the Buy tab.
-- The CoA fork reuses one main panel for several custom tabs, so controls that
-- are shown on Buy can otherwise remain visible when switching to Sell/Inventory.

local elapsed = 0;

local function IsBuyTab ()
    if (Atr_IsModeBuy) then
        return Atr_IsModeBuy() and true or false;
    end
    return false;
end

local function HideBuyOnlyControls ()
    if (CoAtr_AdvancedSearchButton) then
        CoAtr_AdvancedSearchButton:Hide();
    end

    -- The classic shell presents Advanced with CoAtr_AdvancedSearchButton, but
    -- keep the upstream checkbox hidden as well so neither implementation can
    -- leak onto Sell, More, or Inventory.
    if (Atr_Adv_Search_Button) then
        Atr_Adv_Search_Button:Hide();
    end

    if (Atr_Exact_Search_Button) then
        Atr_Exact_Search_Button:Hide();
    end
end

local controller = CreateFrame ("Frame");
controller:RegisterEvent ("AUCTION_HOUSE_CLOSED");
controller:SetScript ("OnEvent", function ()
    HideBuyOnlyControls();
end);

controller:SetScript ("OnUpdate", function (self, dt)
    elapsed = elapsed + dt;
    if (elapsed < 0.10) then return; end
    elapsed = 0;

    if (not AuctionFrame or not AuctionFrame:IsShown()) then
        return;
    end

    if (not IsBuyTab()) then
        HideBuyOnlyControls();
    end
end);
