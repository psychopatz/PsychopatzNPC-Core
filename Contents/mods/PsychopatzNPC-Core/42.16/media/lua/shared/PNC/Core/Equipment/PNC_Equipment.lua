PNC = PNC or {}
PNC.Equipment = PNC.Equipment or {}

local Equipment = PNC.Equipment

local function clearHands(zombie)
    if not zombie then
        return
    end
    if zombie.setPrimaryHandItem then
        zombie:setPrimaryHandItem(nil)
    end
    if zombie.setSecondaryHandItem then
        zombie:setSecondaryHandItem(nil)
    end
    if zombie.resetEquippedHandsModels then
        zombie:resetEquippedHandsModels()
    end
    if zombie.clearAttachedItems then
        zombie:clearAttachedItems()
    end
end

local function resolvePrimaryType(item)
    local weaponType
    if not item or not item.IsWeapon or not item:IsWeapon() or not WeaponType or not WeaponType.getWeaponType then
        return "barehand"
    end
    weaponType = WeaponType.getWeaponType(item)
    if weaponType == WeaponType.FIREARM then
        return "rifle"
    end
    if weaponType == WeaponType.HANDGUN then
        return "handgun"
    end
    if weaponType == WeaponType.SPEAR then
        return "spear"
    end
    if weaponType == WeaponType.HEAVY or weaponType == WeaponType.TWO_HANDED then
        return "twohanded"
    end
    if weaponType == WeaponType.ONE_HANDED then
        return "onehanded"
    end
    return "barehand"
end

local function resolveModeFromPrimaryType(primaryType)
    if primaryType == "rifle" or primaryType == "handgun" then
        return "ranged"
    end
    if primaryType == "twohanded" or primaryType == "onehanded" or primaryType == "spear" then
        return "melee"
    end
    return "melee"
end

function Equipment.Apply(zombie, record)
    local equipment
    local fullType
    local item
    local primaryType

    if not zombie or not record then
        return
    end

    equipment = record.equipment or {}
    fullType = equipment.primaryFullType

    clearHands(zombie)

    if not fullType or not InventoryItemFactory or not InventoryItemFactory.CreateItem then
        if zombie.setVariable then
            zombie:setVariable("BanditPrimary", "")
            zombie:setVariable("BanditSecondary", "")
            zombie:setVariable("BanditPrimaryType", "barehand")
        end
        return
    end

    item = InventoryItemFactory.CreateItem(fullType)
    if not item then
        if zombie.setVariable then
            zombie:setVariable("BanditPrimary", "")
            zombie:setVariable("BanditSecondary", "")
            zombie:setVariable("BanditPrimaryType", "barehand")
        end
        return
    end

    primaryType = resolvePrimaryType(item)

    if zombie.setPrimaryHandItem then
        zombie:setPrimaryHandItem(item)
    end
    if item.isRequiresEquippedBothHands and item:isRequiresEquippedBothHands() and zombie.setSecondaryHandItem then
        zombie:setSecondaryHandItem(item)
    end
    if zombie.setVariable then
        zombie:setVariable("BanditPrimary", fullType)
        zombie:setVariable("BanditSecondary", "")
        zombie:setVariable("BanditPrimaryType", primaryType)
    end
    if zombie.resetEquippedHandsModels then
        zombie:resetEquippedHandsModels()
    end
end

function Equipment.SetPrimary(record, fullType)
    if not record then
        return false
    end
    record.equipment = record.equipment or {}
    record.equipment.primaryFullType = fullType
    return true
end

function Equipment.ResolveWeaponMode(fullType)
    local item
    if not fullType or not InventoryItemFactory or not InventoryItemFactory.CreateItem then
        return "melee"
    end
    item = InventoryItemFactory.CreateItem(fullType)
    if not item then
        return "melee"
    end
    return resolveModeFromPrimaryType(resolvePrimaryType(item))
end
