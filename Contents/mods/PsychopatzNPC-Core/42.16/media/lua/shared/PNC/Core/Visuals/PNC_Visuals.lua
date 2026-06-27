PNC = PNC or {}
PNC.Visuals = PNC.Visuals or {}

local Visuals = PNC.Visuals
local Profiles = PNC.VisualProfiles

local function clearBodySoiledState(humanVisual)
    local maxIndex
    local i
    local part
    if not humanVisual then
        return
    end
    if humanVisual.removeDirt then
        humanVisual:removeDirt()
    end
    if humanVisual.removeBlood then
        humanVisual:removeBlood()
    end
    if not BloodBodyPartType or not BloodBodyPartType.MAX or not BloodBodyPartType.FromIndex then
        return
    end
    maxIndex = BloodBodyPartType.MAX:index()
    for i = 0, maxIndex - 1 do
        part = BloodBodyPartType.FromIndex(i)
        humanVisual:setBlood(part, 0)
        humanVisual:setDirt(part, 0)
    end
end

local function clearAttachedItems(zombie)
    local attachedItems
    local i
    local entry
    local item
    if not zombie or not zombie.getAttachedItems then
        return
    end
    attachedItems = zombie:getAttachedItems()
    if not attachedItems then
        return
    end
    for i = attachedItems:size() - 1, 0, -1 do
        entry = attachedItems:get(i)
        item = entry and entry.getItem and entry:getItem() or nil
        if item and zombie.removeAttachedItem then
            zombie:removeAttachedItem(item)
        end
    end
end

local function refreshModel(zombie)
    if not zombie then
        return
    end
    if zombie.resetModelNextFrame then
        zombie:resetModelNextFrame()
    end
    if zombie.resetModel then
        zombie:resetModel()
    end
end

function Visuals.ApplyHumanVisuals(zombie, record)
    local appearance
    local humanVisual
    local itemVisuals
    local wornItems

    if not zombie or not record then
        return
    end

    appearance = Profiles.RollAppearance(record)
    if zombie.setFemaleEtc then
        zombie:setFemaleEtc(record.isFemale == true)
    end

    humanVisual = zombie.getHumanVisual and zombie:getHumanVisual() or nil
    itemVisuals = zombie.getItemVisuals and zombie:getItemVisuals() or nil
    wornItems = zombie.getWornItems and zombie:getWornItems() or nil

    if itemVisuals and itemVisuals.clear then
        itemVisuals:clear()
    end
    if wornItems and wornItems.clear then
        wornItems:clear()
    end

    clearAttachedItems(zombie)
    clearBodySoiledState(humanVisual)

    if zombie.dressInNamedOutfit then
        zombie:dressInNamedOutfit(appearance.outfit)
    end

    if humanVisual then
        if appearance.skinTexture and humanVisual.setSkinTextureName then
            humanVisual:setSkinTextureName(appearance.skinTexture)
        end
        if appearance.hairModel and humanVisual.setHairModel then
            humanVisual:setHairModel(appearance.hairModel)
        end
        if appearance.beardModel and humanVisual.setBeardModel then
            humanVisual:setBeardModel(appearance.beardModel)
        end
    end

    refreshModel(zombie)
end
