require "Fishing/FishingHandler"

if Fishing and Fishing.Handler and Fishing.Handler.handleFishing then
    local originalHandleFishing = Fishing.Handler.handleFishing

    Fishing.Handler.handleFishing = function(player, primaryHandItem)
        if not instanceof or not instanceof(player, "IsoPlayer") then
            return
        end
        return originalHandleFishing(player, primaryHandItem)
    end
end
