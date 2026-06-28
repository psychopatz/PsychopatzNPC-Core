PNC = PNC or {}
PNC.Equipment = PNC.Equipment or {}

local Equipment = PNC.Equipment
local Core = PNC.Core
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

local function safeInvoke(target, methodName, ...)
    local method
    if not target then
        return false, "missing_target"
    end
    method = target[methodName]
    if type(method) ~= "function" then
        return false, "missing_method:" .. tostring(methodName)
    end
    return pcall(method, target, ...)
end

local function setEquipmentVariables(zombie, primaryType, primaryFullType, secondaryFullType)
    if not zombie or not zombie.setVariable then
        return
    end
    zombie:setVariable("PNCPrimary", tostring(primaryFullType or ""))
    zombie:setVariable("PNCSecondary", tostring(secondaryFullType or ""))
    zombie:setVariable("PNCPrimaryType", tostring(primaryType or "barehand"))
end

local function refreshHands(zombie)
    if not zombie then
        return
    end
    if zombie.resetEquippedHandsModels then
        zombie:resetEquippedHandsModels()
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

local function clearHands(zombie)
    if not zombie then
        return
    end
    if zombie.setPrimaryHandItem then
        pcall(function()
            zombie:setPrimaryHandItem(nil)
        end)
    end
    if zombie.setSecondaryHandItem then
        pcall(function()
            zombie:setSecondaryHandItem(nil)
        end)
    end
    refreshHands(zombie)
end

local function clearAttachedItems(zombie)
    local attachedItems
    local i
    local attachedItem
    local item
    if not zombie or not zombie.getAttachedItems then
        return
    end
    attachedItems = zombie:getAttachedItems()
    if not attachedItems or not attachedItems.size then
        return
    end
    for i = attachedItems:size() - 1, 0, -1 do
        attachedItem = attachedItems:get(i)
        item = attachedItem and attachedItem.getItem and attachedItem:getItem() or nil
        if item and zombie.removeAttachedItem then
            pcall(function()
                zombie:removeAttachedItem(item)
            end)
        end
    end
end

local function clearExplicitWornItems(zombie)
    local wornItems
    local itemVisuals
    if not zombie then
        return
    end
    wornItems = zombie.getWornItems and zombie:getWornItems() or nil
    itemVisuals = zombie.getItemVisuals and zombie:getItemVisuals() or nil
    if wornItems and wornItems.clear then
        wornItems:clear()
    end
    if itemVisuals and itemVisuals.clear then
        itemVisuals:clear()
    end
end

local function applyWornItems(zombie, equipment)
    local entries = Equipment.GetOrderedWornEntries(equipment)
    local appliedCount = 0
    local failureCount = 0
    local i
    local entry
    local item
    local createReason
    local ok
    local errorMessage

    if #entries <= 0 then
        return true, "worn:none"
    end

    clearExplicitWornItems(zombie)

    for i = 1, #entries do
        entry = entries[i]
        item, createReason = Equipment.CreateItem(entry.fullType)
        if item then
            ok, errorMessage = safeInvoke(zombie, "setWornItem", entry.bodyLocation, item)
            if not ok then
                failureCount = failureCount + 1
                Core.LogWarn("PNC equipment failed to wear " .. tostring(entry.fullType) .. " on " .. tostring(entry.bodyLocation) .. ": " .. tostring(errorMessage))
            else
                appliedCount = appliedCount + 1
            end
        else
            failureCount = failureCount + 1
            Core.LogWarn("PNC equipment could not create worn item " .. tostring(entry.fullType) .. ": " .. tostring(createReason))
        end
    end

    if failureCount > 0 then
        return false, "worn:applied=" .. tostring(appliedCount) .. ",failed=" .. tostring(failureCount)
    end
    return true, "worn:" .. tostring(appliedCount)
end

local function applyAttachedItems(zombie, equipment)
    local entries = Equipment.GetOrderedAttachedEntries(equipment)
    local appliedCount = 0
    local failureCount = 0
    local i
    local entry
    local item
    local createReason
    local ok
    local errorMessage

    clearAttachedItems(zombie)

    if #entries <= 0 then
        return true, "attached:none"
    end

    for i = 1, #entries do
        entry = entries[i]
        item, createReason = Equipment.CreateItem(entry.fullType)
        if item then
            ok, errorMessage = safeInvoke(zombie, "setAttachedItem", entry.location, item)
            if ok then
                if item.setAttachedToModel then
                    item:setAttachedToModel(entry.location)
                end
                if item.setAttachedSlotType and entry.slotType then
                    item:setAttachedSlotType(entry.slotType)
                end
                appliedCount = appliedCount + 1
            else
                failureCount = failureCount + 1
                Core.LogWarn("PNC equipment failed to attach " .. tostring(entry.fullType) .. " at " .. tostring(entry.location) .. ": " .. tostring(errorMessage))
            end
        else
            failureCount = failureCount + 1
            Core.LogWarn("PNC equipment could not create attached item " .. tostring(entry.fullType) .. ": " .. tostring(createReason))
        end
    end

    if failureCount > 0 then
        return false, "attached:applied=" .. tostring(appliedCount) .. ",failed=" .. tostring(failureCount)
    end
    return true, "attached:" .. tostring(appliedCount)
end

local function applyHands(zombie, equipment, descriptor)
    local item
    local primaryType
    local secondaryItem
    local secondaryReason
    local secondaryFullType
    local ok
    local errorMessage

    clearHands(zombie)

    if not descriptor.fullType then
        setEquipmentVariables(zombie, "barehand", nil, nil)
        return true, descriptor.weaponStatus
    end

    item = descriptor.item
    if not item then
        setEquipmentVariables(zombie, "barehand", nil, nil)
        return false, descriptor.weaponStatus
    end

    primaryType = descriptor.primaryType
    ok, errorMessage = safeInvoke(zombie, "setPrimaryHandItem", item)
    if not ok then
        setEquipmentVariables(zombie, "barehand", nil, nil)
        return false, "primary_equip_failed:" .. tostring(errorMessage)
    end

    if item.isRequiresEquippedBothHands and item:isRequiresEquippedBothHands() then
        ok, errorMessage = safeInvoke(zombie, "setSecondaryHandItem", item)
        if not ok then
            setEquipmentVariables(zombie, primaryType, descriptor.fullType, nil)
            refreshHands(zombie)
            return false, "secondary_both_hands_failed:" .. tostring(errorMessage)
        end
    else
        secondaryFullType = equipment.secondaryFullType
        if secondaryFullType and secondaryFullType ~= descriptor.fullType then
            secondaryItem, secondaryReason = Equipment.CreateItem(secondaryFullType)
            if secondaryItem then
                ok, errorMessage = safeInvoke(zombie, "setSecondaryHandItem", secondaryItem)
                if not ok then
                    secondaryFullType = nil
                    Core.LogWarn("PNC equipment failed to equip secondary " .. tostring(equipment.secondaryFullType) .. ": " .. tostring(errorMessage))
                end
            else
                secondaryFullType = nil
                Core.LogWarn("PNC equipment could not create secondary " .. tostring(equipment.secondaryFullType) .. ": " .. tostring(secondaryReason))
            end
        end
    end

    setEquipmentVariables(zombie, primaryType, descriptor.fullType, secondaryFullType)
    refreshHands(zombie)
    return true, descriptor.weaponStatus .. ":" .. tostring(descriptor.createReason or "unknown")
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
    local descriptor
    local ok = true
    local laneOk
    local reasons = {}

    if not zombie or not record then
        return false, "missing_body_or_record"
    end

    equipment = Equipment.EnsureRecordEquipment(record)
    descriptor = buildWeaponDescriptor(equipment.primaryFullType)

    laneOk, reasons[#reasons + 1] = applyWornItems(zombie, equipment)
    if not laneOk then
        ok = false
    end

    laneOk, reasons[#reasons + 1] = applyAttachedItems(zombie, equipment)
    if not laneOk then
        ok = false
    end

    laneOk, reasons[#reasons + 1] = applyHands(zombie, equipment, descriptor)
    if not laneOk then
        ok = false
    end

    refreshModel(zombie)
    return ok, table.concat(reasons, "|")
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
