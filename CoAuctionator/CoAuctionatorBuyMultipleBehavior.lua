-- CoAuctionator +Mod 1.4
-- Make the Buy Multiple picker behave like a normal Blizzard dialog.

local pickerRegisteredForEscape = false;
local elapsedSinceCheck = 0;

local function AttachPickerBehavior ()
    local picker = Atr_BuyMultiple_Frame;
    if (not picker) then return; end

    if (not pickerRegisteredForEscape) then
        UISpecialFrames = UISpecialFrames or {};

        local found = false;
        local i;
        for i = 1, #UISpecialFrames do
            if (UISpecialFrames[i] == "Atr_BuyMultiple_Frame") then
                found = true;
                break;
            end
        end

        if (not found) then
            table.insert (UISpecialFrames, "Atr_BuyMultiple_Frame");
        end

        pickerRegisteredForEscape = true;
    end

    if (not picker.coAtrBehaviorHooked) then
        picker.coAtrBehaviorHooked = true;
        picker:HookScript ("OnHide", function ()
            -- Escape hides UISpecialFrames directly. Clear only the active buy
            -- runtime here; the next native or multiple Buy click initializes
            -- its own mode/session normally.
            if (Atr_ClearBuyState) then
                Atr_ClearBuyState();
            end
        end);
    end
end

local controller = CreateFrame ("Frame");
controller:RegisterEvent ("AUCTION_HOUSE_CLOSED");
controller:SetScript ("OnEvent", function ()
    if (Atr_BuyMultiple_Frame and Atr_BuyMultiple_Frame:IsShown()) then
        Atr_BuyMultiple_Frame:Hide();
    end

    if (Atr_ClearBuyState) then
        Atr_ClearBuyState();
    end
end);

-- The picker is created lazily on first use, so attach once it exists.
controller:SetScript ("OnUpdate", function (self, elapsed)
    elapsedSinceCheck = elapsedSinceCheck + elapsed;
    if (elapsedSinceCheck < 0.20) then return; end
    elapsedSinceCheck = 0;

    if (not pickerRegisteredForEscape or (Atr_BuyMultiple_Frame and not Atr_BuyMultiple_Frame.coAtrBehaviorHooked)) then
        AttachPickerBehavior();
    end
end);
