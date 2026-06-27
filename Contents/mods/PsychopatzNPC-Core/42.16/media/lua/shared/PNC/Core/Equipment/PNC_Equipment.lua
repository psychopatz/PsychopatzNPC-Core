PNC = PNC or {}
PNC.Equipment = PNC.Equipment or {}

local Equipment = PNC.Equipment
local resolvePrimaryType
local resolveModeFromPrimaryType

local function buildWeaponDescriptor(fullType)
    local item
    local primaryType
    local createReason
    if not fullType or fullType == "" then
        return {
            fullType = nil,
            primaryType = "barehand",
            resolvedMode = "melee",
            hasWeapon = false,
            hasUsableFirearm = false,
            weaponStatus = "barehand",
            item = nil,
        }
    end

    item, createReason = Equipment.CreateItem(fullType)
    if not item then
        return {
            fullType = fullType,
            primaryType = "barehand",
            resolvedMode = "melee",
            hasWeapon = false,
            hasUsableFirearm = false,
            weaponStatus = createReason or "invalid_full_type",
            createReason = createReason or "invalid_full_type",
            item = nil,
        }
    end

    primaryType = resolvePrimaryType(item)
    return {
        fullType = fullType,
        primaryType = primaryType,
        resolvedMode = resolveModeFromPrimaryType(primaryType),
        hasWeapon = item.IsWeapon and item:IsWeapon() or false,
        hasUsableFirearm = primaryType == "rifle" or primaryType == "handgun",
        weaponStatus = primaryType == "barehand" and "barehand" or ("equipped_" .. tostring(primaryType)),
        createReason = createReason or "unknown",
        item = item,
    }
end

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

resolvePrimaryType = function(item)
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

resolveModeFromPrimaryType = function(primaryType)
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
    local descriptor
    local item
    local primaryType

    if not zombie or not record then
        return false, "missing_body_or_record"
    end

    equipment = record.equipment or {}
    fullType = equipment.primaryFullType

    clearHands(zombie)

    descriptor = buildWeaponDescriptor(fullType)
    if not descriptor.fullType then
        if zombie.setVariable then
            zombie:setVariable("PNCPrimary", "")
            zombie:setVariable("PNCSecondary", "")
            zombie:setVariable("PNCPrimaryType", "barehand")
        end
        return true, descriptor.weaponStatus
    end

    item = descriptor.item
    if not item then
        if zombie.setVariable then
            zombie:setVariable("PNCPrimary", "")
            zombie:setVariable("PNCSecondary", "")
            zombie:setVariable("PNCPrimaryType", "barehand")
        end
        return false, descriptor.weaponStatus
    end

    primaryType = descriptor.primaryType

    if zombie.setPrimaryHandItem then
        zombie:setPrimaryHandItem(item)
    end
    if item.isRequiresEquippedBothHands and item:isRequiresEquippedBothHands() and zombie.setSecondaryHandItem then
        zombie:setSecondaryHandItem(item)
    end
    if zombie.setVariable then
        zombie:setVariable("PNCPrimary", fullType)
        zombie:setVariable("PNCSecondary", "")
        zombie:setVariable("PNCPrimaryType", primaryType)
    end
    if zombie.resetEquippedHandsModels then
        zombie:resetEquippedHandsModels()
    end
    return true, descriptor.weaponStatus .. ":" .. tostring(descriptor.createReason or "unknown")
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
    return buildWeaponDescriptor(fullType).resolvedMode
end

function Equipment.Describe(record)
    local configuredMode
    local fullType
    local descriptor
    local combatModeResolved
    local weaponStatus

    configuredMode = tostring(record and record.weaponMode or "melee")
    fullType = record and record.equipment and record.equipment.primaryFullType or nil
    descriptor = buildWeaponDescriptor(fullType)
    combatModeResolved = configuredMode
    weaponStatus = descriptor.weaponStatus

    if configuredMode == "ranged" then
        if descriptor.hasUsableFirearm then
            combatModeResolved = "ranged"
            weaponStatus = "ranged_ready"
        else
            combatModeResolved = "melee"
            if descriptor.weaponStatus ~= "barehand" and descriptor.hasWeapon ~= true and descriptor.fullType then
                weaponStatus = descriptor.weaponStatus .. "_fallback_melee"
            elseif descriptor.fullType and descriptor.hasWeapon then
                weaponStatus = "ranged_missing_firearm_fallback_melee"
            else
                weaponStatus = "ranged_unarmed_fallback_melee"
            end
        end
    elseif configuredMode == "mixed" then
        if descriptor.hasUsableFirearm then
            combatModeResolved = "mixed"
            weaponStatus = "mixed_ranged_ready"
        elseif descriptor.weaponStatus ~= "barehand" and descriptor.hasWeapon ~= true and descriptor.fullType then
            combatModeResolved = "melee"
            weaponStatus = descriptor.weaponStatus .. "_fallback_melee"
        elseif descriptor.hasWeapon then
            combatModeResolved = "melee"
            weaponStatus = "mixed_melee_only"
        else
            combatModeResolved = "melee"
            weaponStatus = "mixed_unarmed_fallback_melee"
        end
    elseif configuredMode == "melee" then
        combatModeResolved = "melee"
        if descriptor.hasWeapon then
            weaponStatus = "melee_ready"
        else
            weaponStatus = "melee_unarmed"
        end
    end

    return {
        configuredMode = configuredMode,
        combatModeResolved = combatModeResolved,
        weaponStatus = weaponStatus,
        primaryType = descriptor.primaryType,
        hasWeapon = descriptor.hasWeapon,
        hasUsableFirearm = descriptor.hasUsableFirearm,
        fullType = descriptor.fullType,
    }
end
