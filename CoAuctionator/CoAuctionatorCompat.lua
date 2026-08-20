-- CoAuctionator identity shim.
-- The upstream 2.9.9 code contains a few hard-coded references to the original
-- addon folder name "Auctionator".  The Ascension launcher manages that name,
-- so this fork intentionally installs as "CoAuctionator" instead.

local COA_ADDON_NAME = "CoAuctionator";

-- Atr_OnLoad assigns AuctionatorVersion from GetAddOnMetadata("Auctionator", ...).
-- Keep the upstream initialization intact, then immediately restore this fork's
-- own metadata so About/version checks identify the actual loaded addon.
if (Atr_OnLoad) then
    local upstreamAtrOnLoad = Atr_OnLoad;
    Atr_OnLoad = function (...)
        upstreamAtrOnLoad (...);
        local version = GetAddOnMetadata (COA_ADDON_NAME, "Version");
        if (version) then
            AuctionatorVersion = version;
        end
    end;
end

-- The upstream memory helper also hard-codes "Auctionator".
function Atr_GetAuctionatorMemString (msg)
    UpdateAddOnMemoryUsage();
    local mem = GetAddOnMemoryUsage (COA_ADDON_NAME) or 0;
    return string.format ("%6i KB", math.floor (mem));
end

-- Reassert the identity after login in case another addon queries/changes the
-- shared AuctionatorVersion global during startup.
local identityFrame = CreateFrame ("Frame");
identityFrame:RegisterEvent ("PLAYER_LOGIN");
identityFrame:SetScript ("OnEvent", function ()
    local version = GetAddOnMetadata (COA_ADDON_NAME, "Version");
    if (version) then
        AuctionatorVersion = version;
    end
end);
