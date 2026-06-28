PNC = PNC or {}
PNC.Inventory = PNC.Inventory or {}

local Inventory = PNC.Inventory
local Core = PNC.Core
local Archetypes = PNC.Archetypes
local Identity = PNC.Identity
local Skills = PNC.Skills

local ITEM_WEIGHT_CACHE = {}
local ITEM_CAPACITY_CACHE = {}

local function normalizeString(value)
    if value == nil or value == "" then
        return nil
    end
    return tostring(value)
end

local function clamp(value, minValue, maxValue)
    local numeric = tonumber(value) or minValue
    if numeric < minValue then
        return minValue
    end
    if numeric > maxValue then
        return maxValue
    end
    return numeric
end

local function shallowArrayCopy(source)
    local output = {}
    local i
    if type(source) ~= "table" then
        return output
    end
    for i = 1, #source do
        output[i] = source[i]
    end
    return output
end

local function choose(list, seed, salt)
    if type(list) ~= "table" or #list <= 0 then
        return nil
    end
    return list[Identity.Index(seed, salt, #list)]
end

local function getRuntimeState(record)
    if not record then
        return nil
    end
    record.runtime = record.runtime or {}
    record.runtime.inventory = record.runtime.inventory or {
        nextItemSerial = 0,
        opLog = {},
    }
    record.runtime.inventory.nextItemSerial = math.max(0, math.floor(tonumber(record.runtime.inventory.nextItemSerial) or 0))
    record.runtime.inventory.opLog = type(record.runtime.inventory.opLog) == "table"
        and record.runtime.inventory.opLog
        or {}
    return record.runtime.inventory
end

local function nextItemID(record)
    local runtime = getRuntimeState(record)
    runtime.nextItemSerial = runtime.nextItemSerial + 1
    return "item_" .. tostring(runtime.nextItemSerial)
end

local function refreshNextItemSerial(record, inv)
    local runtime = getRuntimeState(record)
    local maxSerial = 0
    local itemID
    local serial
    if not runtime or not inv or type(inv.items) ~= "table" then
        return
    end
    for itemID, _ in pairs(inv.items) do
        if type(itemID) == "string" then
            serial = tonumber(string.match(itemID, "^item_(%d+)$"))
            if serial and serial > maxSerial then
                maxSerial = serial
            end
        end
    end
    runtime.nextItemSerial = math.max(maxSerial, tonumber(runtime.nextItemSerial) or 0)
end

local function getItemWeight(fullType)
    local cached = ITEM_WEIGHT_CACHE[fullType]
    local item
    if cached ~= nil then
        return cached
    end
    cached = 0.1
    if PNC.Equipment and PNC.Equipment.CreateItem then
        item = PNC.Equipment.CreateItem(fullType)
        if type(item) == "table" then
            item = item[1]
        end
    end
    if item and item.getActualWeight then
        cached = tonumber(item:getActualWeight()) or cached
    elseif item and item.getWeight then
        cached = tonumber(item:getWeight()) or cached
    elseif getScriptManager and getScriptManager().getItem then
        item = getScriptManager():getItem(fullType)
        if item and item.getActualWeight then
            cached = tonumber(item:getActualWeight()) or cached
        elseif item and item.getWeight then
            cached = tonumber(item:getWeight()) or cached
        end
    end
    ITEM_WEIGHT_CACHE[fullType] = math.max(0, cached)
    return ITEM_WEIGHT_CACHE[fullType]
end

local function getItemCapacity(fullType)
    local cached = ITEM_CAPACITY_CACHE[fullType]
    local item
    if cached ~= nil then
        return cached
    end
    cached = 0
    if PNC.Equipment and PNC.Equipment.CreateItem then
        item = PNC.Equipment.CreateItem(fullType)
        if type(item) == "table" then
            item = item[1]
        end
    end
    if item and item.getMaxCapacity then
        cached = tonumber(item:getMaxCapacity()) or cached
    elseif item and item.getCapacity then
        cached = tonumber(item:getCapacity()) or cached
    elseif getScriptManager and getScriptManager().getItem then
        item = getScriptManager():getItem(fullType)
        if item and item.getCapacity then
            cached = tonumber(item:getCapacity()) or cached
        end
    end
    ITEM_CAPACITY_CACHE[fullType] = math.max(0, cached)
    return ITEM_CAPACITY_CACHE[fullType]
end

local function ensureContainer(inv, containerID, maxWeight)
    inv.containers = inv.containers or {}
    inv.containers[containerID] = inv.containers[containerID] or {
        maxWeight = tonumber(maxWeight) or 0,
        items = {},
    }
    inv.containers[containerID].maxWeight = tonumber(inv.containers[containerID].maxWeight) or tonumber(maxWeight) or 0
    inv.containers[containerID].items = type(inv.containers[containerID].items) == "table"
        and inv.containers[containerID].items
        or {}
    return inv.containers[containerID]
end

local function removeItemFromAllContainers(inv, itemID)
    local containerID
    local container
    local i
    if not inv or not inv.containers then
        return
    end
    for containerID, container in pairs(inv.containers) do
        if type(container.items) == "table" then
            for i = #container.items, 1, -1 do
                if container.items[i] == itemID then
                    table.remove(container.items, i)
                end
            end
        end
    end
end

local function addItemToContainer(inv, itemID, containerID)
    local container = ensureContainer(inv, containerID, containerID == "root" and inv.rootMaxWeight or 0)
    removeItemFromAllContainers(inv, itemID)
    container.items[#container.items + 1] = itemID
end

local function serializeColor(color)
    if not color then
        return nil
    end
    return {
        r = tonumber(color.r) or 0.2,
        g = tonumber(color.g) or 0.1,
        b = tonumber(color.b) or 0.1,
    }
end

local function itemToPayload(item)
    local payload
    if not item or not item.id or not item.type then
        return nil
    end
    payload = {
        id = item.id,
        type = item.type,
        stack = tonumber(item.stack) or nil,
        uses = tonumber(item.uses) or nil,
        cond = tonumber(item.cond) or nil,
        fav = item.fav == true or nil,
        container = item.container,
        bagContainer = item.bagContainer,
        maxWeight = tonumber(item.maxWeight) or nil,
        templateKey = item.templateKey,
        preferredContainer = item.preferredContainer,
        wornSlot = item.wornSlot,
        attachedSlot = item.attachedSlot,
        equipSlot = item.equipSlot,
    }
    return payload
end

local function buildOperation(op, data)
    local payload = { op = op }
    local key
    if type(data) == "table" then
        for key, _ in pairs(data) do
            payload[key] = data[key]
        end
    end
    return payload
end

local function pruneOpLog(runtime)
    local extra
    if not runtime or type(runtime.opLog) ~= "table" then
        return
    end
    extra = #runtime.opLog - (PNC.Const.INVENTORY_OPLOG_MAX or 32)
    while extra > 0 do
        table.remove(runtime.opLog, 1)
        extra = extra - 1
    end
end

local function bumpRevision(record, ops, reason)
    local inv = record.inventory
    local runtime = getRuntimeState(record)
    local i
    if type(ops) ~= "table" or #ops <= 0 then
        return inv and inv.revision or 0
    end
    inv.revision = math.max(0, math.floor(tonumber(inv.revision) or 0)) + 1
    inv.lastMutationReason = normalizeString(reason) or "mutation"
    for i = 1, #ops do
        runtime.opLog[#runtime.opLog + 1] = {
            revision = inv.revision,
            op = ops[i],
        }
    end
    pruneOpLog(runtime)
    return inv.revision
end

local function buildIdentityTemplate(record)
    local appearance = Identity and Identity.RollAppearance and Identity.RollAppearance(record) or {}
    local archetype = Archetypes.Get(record and record.archetypeID or nil)
    local loadout = archetype.loadout or {}
    local seed = Identity.NormalizeSeed(record and record.identitySeed or nil, record and record.id or "npc")
    local bagType = choose(loadout.bagChoices, seed, "inv:bag:" .. tostring(archetype.id))
    local primaryType = choose(loadout.primaryChoices, seed, "inv:primary:" .. tostring(archetype.id))
    local supplies = shallowArrayCopy(loadout.supplies)
    return {
        archetypeID = archetype.id,
        appearance = appearance,
        bagType = bagType,
        primaryType = primaryType,
        attached = Core.DeepCopy(loadout.attached or {}),
        supplies = supplies,
    }
end

local function buildBaseCarryWeight(record)
    local strength = Skills and Skills.GetLevel and Skills.GetLevel(record, "Strength") or 2
    local fitness = Skills and Skills.GetLevel and Skills.GetLevel(record, "Fitness") or 2
    return math.max(6, 6 + (tonumber(strength) or 0) + ((tonumber(fitness) or 0) * 0.5))
end

local function createBaseInventory(record)
    local maxWeight = buildBaseCarryWeight(record)
    return {
        revision = 0,
        deltaMode = record and record.recruited == true and "full" or "template_plus_delta",
        cachedWeight = 0,
        maxWeight = maxWeight,
        rootMaxWeight = maxWeight,
        equipped = {
            primary = nil,
            secondary = nil,
            bag = nil,
        },
        worn = {},
        attached = {},
        items = {},
        containers = {
            root = {
                maxWeight = maxWeight,
                items = {},
            },
        },
        template = {
            archetypeID = record and record.archetypeID or "General",
            seed = record and record.identitySeed or 1,
        },
    }
end

local function createItem(record, inv, spec)
    local itemID = normalizeString(spec.id) or nextItemID(record)
    local item = {
        id = itemID,
        type = normalizeString(spec.type),
        stack = math.max(1, math.floor(tonumber(spec.stack) or tonumber(spec.uses) or 1)),
        uses = tonumber(spec.uses),
        cond = tonumber(spec.cond),
        fav = spec.fav == true,
        container = normalizeString(spec.container) or "root",
        bagContainer = normalizeString(spec.bagContainer),
        maxWeight = tonumber(spec.maxWeight),
        templateKey = normalizeString(spec.templateKey),
        preferredContainer = normalizeString(spec.preferredContainer),
        wornSlot = normalizeString(spec.wornSlot),
        attachedSlot = normalizeString(spec.attachedSlot),
        equipSlot = normalizeString(spec.equipSlot),
    }
    if not item.type then
        return nil
    end
    inv.items[itemID] = item
    addItemToContainer(inv, itemID, item.container)
    if item.maxWeight and item.maxWeight > 0 then
        ensureContainer(inv, "bag_" .. tostring(itemID), item.maxWeight)
        item.bagContainer = "bag_" .. tostring(itemID)
    elseif item.bagContainer then
        ensureContainer(inv, item.bagContainer, 0)
    end
    if item.wornSlot then
        inv.worn[item.wornSlot] = itemID
    end
    if item.attachedSlot then
        inv.attached[item.attachedSlot] = itemID
    end
    if item.equipSlot == "primary" then
        inv.equipped.primary = itemID
    elseif item.equipSlot == "secondary" then
        inv.equipped.secondary = itemID
    elseif item.equipSlot == "bag" then
        inv.equipped.bag = itemID
    end
    return item
end

local function clearItemRefs(inv, itemID)
    local key
    if inv.equipped.primary == itemID then
        inv.equipped.primary = nil
    end
    if inv.equipped.secondary == itemID then
        inv.equipped.secondary = nil
    end
    if inv.equipped.bag == itemID then
        inv.equipped.bag = nil
    end
    for key, _ in pairs(inv.worn) do
        if inv.worn[key] == itemID then
            inv.worn[key] = nil
        end
    end
    for key, _ in pairs(inv.attached) do
        if inv.attached[key] == itemID then
            inv.attached[key] = nil
        end
    end
end

local function removeItemByID(inv, itemID)
    local item = inv.items[itemID]
    if not item then
        return false
    end
    clearItemRefs(inv, itemID)
    removeItemFromAllContainers(inv, itemID)
    if item.bagContainer then
        inv.containers[item.bagContainer] = nil
    end
    inv.items[itemID] = nil
    return true
end

local function calculateWeights(inv)
    local usedWeight = 0
    local maxWeight = tonumber(inv.rootMaxWeight) or tonumber(inv.maxWeight) or 0
    local itemID
    local item
    for itemID, item in pairs(inv.items) do
        usedWeight = usedWeight + (getItemWeight(item.type) * math.max(1, tonumber(item.stack) or 1))
        if item.bagContainer and inv.containers[item.bagContainer] then
            maxWeight = maxWeight + math.max(0, tonumber(inv.containers[item.bagContainer].maxWeight) or 0)
        end
    end
    inv.cachedWeight = usedWeight
    inv.maxWeight = maxWeight
    return usedWeight, maxWeight
end

local function countMapEntries(map)
    local count = 0
    local _
    for _, _ in pairs(map or {}) do
        count = count + 1
    end
    return count
end

local function buildTemplateSnapshot(record)
    local base = createBaseInventory(record)
    local template = buildIdentityTemplate(record)
    local appearanceItems = template.appearance and template.appearance.outfitItems or {}
    local i
    local item
    local bagItem
    local supply
    local bagContainerID
    for i = 1, #appearanceItems do
        item = createItem(record, base, {
            type = appearanceItems[i],
            container = "root",
            wornSlot = PNC.Equipment and PNC.Equipment.CreateItem and nil or nil,
            templateKey = "tmpl:look:" .. tostring(i),
        })
        if item and PNC.Equipment and PNC.Equipment.CreateItem then
            local created = PNC.Equipment.CreateItem(appearanceItems[i])
            created = type(created) == "table" and created[1] or created
            if created and created.getBodyLocation then
                item.wornSlot = normalizeString(created:getBodyLocation())
                if item.wornSlot then
                    base.worn[item.wornSlot] = item.id
                end
            end
        end
    end

    if template.bagType then
        bagItem = createItem(record, base, {
            type = template.bagType,
            container = "root",
            equipSlot = "bag",
            templateKey = "tmpl:bag:0",
            maxWeight = getItemCapacity(template.bagType),
        })
        if bagItem then
            bagContainerID = bagItem.bagContainer
        end
    end

    if template.primaryType then
        createItem(record, base, {
            type = template.primaryType,
            container = "root",
            equipSlot = "primary",
            templateKey = "tmpl:weapon:0",
        })
    end

    for i = 1, #(template.supplies or {}) do
        supply = template.supplies[i]
        createItem(record, base, {
            type = supply.type,
            stack = supply.stack,
            container = (supply.preferredContainer == "bag" and bagContainerID) and bagContainerID or "root",
            preferredContainer = supply.preferredContainer,
            templateKey = "tmpl:supply:" .. tostring(i),
        })
    end

    calculateWeights(base)
    return base
end

local function findItemByTemplateKey(inv, templateKey)
    local itemID
    local item
    if not inv or not templateKey then
        return nil
    end
    for itemID, item in pairs(inv.items or {}) do
        if item and item.templateKey == templateKey then
            return item
        end
    end
    return nil
end

local function setItemContainer(inv, item, containerID)
    if not inv or not item then
        return false
    end
    item.container = normalizeString(containerID) or "root"
    addItemToContainer(inv, item.id, item.container)
    return true
end

local function applySavedDelta(record, inv, delta)
    local i
    local item
    local changed
    if type(delta) ~= "table" then
        return
    end
    for i = 1, #(delta.removedTemplateKeys or {}) do
        item = findItemByTemplateKey(inv, delta.removedTemplateKeys[i])
        if item then
            removeItemByID(inv, item.id)
        end
    end
    for i = 1, #(delta.moved or {}) do
        changed = delta.moved[i]
        item = changed and changed.templateKey and findItemByTemplateKey(inv, changed.templateKey) or nil
        if item then
            setItemContainer(inv, item, normalizeString(changed.to) or "root")
        end
    end
    if type(delta.changed) == "table" then
        local templateKey
        for templateKey, changed in pairs(delta.changed) do
            item = findItemByTemplateKey(inv, templateKey)
            if item and type(changed) == "table" then
                if changed.stack ~= nil then
                    item.stack = math.max(1, math.floor(tonumber(changed.stack) or item.stack or 1))
                end
                if changed.uses ~= nil then
                    item.uses = tonumber(changed.uses)
                end
                if changed.cond ~= nil then
                    item.cond = tonumber(changed.cond)
                end
                if changed.container ~= nil then
                    setItemContainer(inv, item, changed.container)
                end
            end
        end
    end
    for i = 1, #(delta.added or {}) do
        changed = delta.added[i]
        if type(changed) == "table" then
            createItem(record, inv, changed)
        end
    end
end

local function buildCompactDelta(record, inv)
    local template = buildTemplateSnapshot(record)
    local removedTemplateKeys = {}
    local moved = {}
    local changed = {}
    local added = {}
    local itemID
    local item
    local templateItem
    for itemID, item in pairs(inv.items or {}) do
        if item.templateKey then
            templateItem = findItemByTemplateKey(template, item.templateKey)
            if not templateItem then
                added[#added + 1] = itemToPayload(item)
            else
                if item.container ~= templateItem.container then
                    moved[#moved + 1] = {
                        templateKey = item.templateKey,
                        to = item.container,
                    }
                end
                if (tonumber(item.stack) or 1) ~= (tonumber(templateItem.stack) or 1)
                    or (tonumber(item.uses) or 0) ~= (tonumber(templateItem.uses) or 0)
                    or (tonumber(item.cond) or 0) ~= (tonumber(templateItem.cond) or 0)
                then
                    changed[item.templateKey] = {
                        stack = item.stack,
                        uses = item.uses,
                        cond = item.cond,
                        container = item.container,
                    }
                end
            end
        else
            added[#added + 1] = itemToPayload(item)
        end
    end
    for itemID, item in pairs(template.items or {}) do
        if item.templateKey and not findItemByTemplateKey(inv, item.templateKey) then
            removedTemplateKeys[#removedTemplateKeys + 1] = item.templateKey
        end
    end
    return {
        added = added,
        removedTemplateKeys = removedTemplateKeys,
        moved = moved,
        changed = changed,
    }
end

function Inventory.CreateFromTemplate(record, options)
    local inv
    local runtime
    if not record then
        return nil
    end
    inv = buildTemplateSnapshot(record)
    inv.deltaMode = record.recruited == true and "full" or "template_plus_delta"
    inv.template = {
        archetypeID = record.archetypeID,
        seed = record.identitySeed,
    }
    record.inventory = inv
    runtime = getRuntimeState(record)
    if options and options.keepRevision then
        inv.revision = tonumber(options.keepRevision) or inv.revision
    else
        inv.revision = 0
    end
    runtime.opLog = {}
    refreshNextItemSerial(record, inv)
    Inventory.SyncEquipmentFromInventory(record)
    Inventory.RebuildCaches(record)
    return record.inventory
end

function Inventory.RebuildCaches(record)
    local inv
    if not record or type(record.inventory) ~= "table" then
        return nil
    end
    inv = record.inventory
    calculateWeights(inv)
    inv.itemCount = countMapEntries(inv.items)
    inv.containerCount = countMapEntries(inv.containers)
    inv.remainingWeight = math.max(0, (tonumber(inv.maxWeight) or 0) - (tonumber(inv.cachedWeight) or 0))
    inv.signature = table.concat({
        tostring(inv.revision or 0),
        tostring(inv.itemCount or 0),
        tostring(math.floor((tonumber(inv.cachedWeight) or 0) * 10)),
        tostring(record.equipment and record.equipment.primaryFullType or ""),
        tostring(record.equipment and record.equipment.secondaryFullType or ""),
    }, ":")
    return inv
end

function Inventory.EnsureRecordInventory(record)
    local inv
    local raw
    local itemID
    local item
    if not record then
        return nil
    end
    if type(record.inventory) ~= "table" or not record.inventory.items or not record.inventory.containers then
        return Inventory.CreateFromTemplate(record)
    end
    inv = record.inventory
    inv.revision = math.max(0, math.floor(tonumber(inv.revision) or 0))
    inv.deltaMode = normalizeString(inv.deltaMode) or (record.recruited == true and "full" or "template_plus_delta")
    inv.cachedWeight = tonumber(inv.cachedWeight) or 0
    inv.rootMaxWeight = tonumber(inv.rootMaxWeight) or tonumber(inv.maxWeight) or buildBaseCarryWeight(record)
    inv.maxWeight = tonumber(inv.maxWeight) or inv.rootMaxWeight
    inv.equipped = type(inv.equipped) == "table" and inv.equipped or { primary = nil, secondary = nil, bag = nil }
    inv.worn = type(inv.worn) == "table" and inv.worn or {}
    inv.attached = type(inv.attached) == "table" and inv.attached or {}
    inv.items = type(inv.items) == "table" and inv.items or {}
    inv.containers = type(inv.containers) == "table" and inv.containers or {}
    ensureContainer(inv, "root", inv.rootMaxWeight)
    raw = inv.items
    inv.items = {}
    for itemID, item in pairs(raw) do
        if type(item) == "table" and normalizeString(item.type) then
            item.id = normalizeString(item.id) or tostring(itemID)
            item.type = normalizeString(item.type)
            item.container = normalizeString(item.container) or "root"
            item.stack = math.max(1, math.floor(tonumber(item.stack) or tonumber(item.uses) or 1))
            item.uses = tonumber(item.uses)
            item.cond = tonumber(item.cond)
            item.templateKey = normalizeString(item.templateKey)
            item.wornSlot = normalizeString(item.wornSlot)
            item.attachedSlot = normalizeString(item.attachedSlot)
            item.equipSlot = normalizeString(item.equipSlot)
            item.bagContainer = normalizeString(item.bagContainer)
            item.maxWeight = tonumber(item.maxWeight)
            inv.items[item.id] = item
            ensureContainer(inv, item.container, item.container == "root" and inv.rootMaxWeight or 0)
            addItemToContainer(inv, item.id, item.container)
            if item.bagContainer then
                ensureContainer(inv, item.bagContainer, tonumber(item.maxWeight) or 0)
            end
        end
    end
    getRuntimeState(record)
    refreshNextItemSerial(record, inv)
    Inventory.SyncEquipmentFromInventory(record)
    Inventory.RebuildCaches(record)
    return record.inventory
end

function Inventory.GetWeightState(record)
    local inv = Inventory.EnsureRecordInventory(record)
    return inv and {
        usedWeight = tonumber(inv.cachedWeight) or 0,
        maxWeight = tonumber(inv.maxWeight) or 0,
        remainingWeight = tonumber(inv.remainingWeight) or math.max(0, (tonumber(inv.maxWeight) or 0) - (tonumber(inv.cachedWeight) or 0)),
    } or nil
end

function Inventory.SyncEquipmentFromInventory(record)
    local inv
    local function fullTypeFor(itemID)
        local item = inv and inv.items and inv.items[itemID] or nil
        return item and item.type or nil
    end
    local slot
    if not record then
        return nil
    end
    inv = record.inventory
    if not inv then
        return nil
    end
    record.equipment = PNC.Equipment and PNC.Equipment.NormalizeLoadoutSpec and PNC.Equipment.NormalizeLoadoutSpec(record.equipment) or (record.equipment or {
        primaryFullType = nil,
        secondaryFullType = nil,
        worn = {},
        attached = {},
    })
    record.equipment.primaryFullType = fullTypeFor(inv.equipped.primary)
    record.equipment.secondaryFullType = fullTypeFor(inv.equipped.secondary)
    record.equipment.worn = {}
    record.equipment.attached = {}
    for slot, _ in pairs(inv.worn or {}) do
        record.equipment.worn[slot] = fullTypeFor(inv.worn[slot])
    end
    for slot, _ in pairs(inv.attached or {}) do
        record.equipment.attached[slot] = fullTypeFor(inv.attached[slot])
    end
    return record.equipment
end

function Inventory.SyncFromEquipment(record, reason)
    local inv
    local equipment
    local hadInventory
    local preserved = {}
    local previousInv
    local function assignItem(slotType, slotValue, fullType)
        local item
        if not fullType then
            return
        end
        if slotType == "equip" and slotValue == "bag" then
            item = createItem(record, inv, {
                type = fullType,
                container = "root",
                equipSlot = "bag",
                maxWeight = getItemCapacity(fullType),
            })
            return item and item.id or nil
        end
        item = createItem(record, inv, {
            type = fullType,
            container = "root",
            wornSlot = slotType == "worn" and slotValue or nil,
            attachedSlot = slotType == "attached" and slotValue or nil,
            equipSlot = slotType == "equip" and slotValue or nil,
        })
        return item and item.id or nil
    end
    local key
    if not record then
        return nil
    end
    hadInventory = type(record.inventory) == "table" and record.inventory.revision ~= nil
    previousInv = hadInventory and record.inventory or nil
    if previousInv and type(previousInv.items) == "table" then
        local itemID
        local item
        for itemID, item in pairs(previousInv.items) do
            if type(item) == "table" and not item.wornSlot and not item.attachedSlot and not item.equipSlot then
                preserved[#preserved + 1] = itemToPayload(item)
            end
        end
    end
    inv = createBaseInventory(record)
    record.inventory = inv
    equipment = PNC.Equipment and PNC.Equipment.EnsureRecordEquipment and PNC.Equipment.EnsureRecordEquipment(record) or record.equipment
    if equipment.attached
        and equipment.attached.Back
        and not equipment.primaryFullType
        and getItemCapacity(equipment.attached.Back) > 0
    then
        assignItem("equip", "bag", equipment.attached.Back)
    end
    if equipment.primaryFullType then
        assignItem("equip", "primary", equipment.primaryFullType)
    end
    if equipment.secondaryFullType then
        assignItem("equip", "secondary", equipment.secondaryFullType)
    end
    for key, _ in pairs(equipment.worn or {}) do
        assignItem("worn", key, equipment.worn[key])
    end
    for key, _ in pairs(equipment.attached or {}) do
        assignItem("attached", key, equipment.attached[key])
    end
    for key = 1, #preserved do
        local item = preserved[key]
        if item then
            if item.container ~= "root" and not inv.containers[item.container] then
                if item.preferredContainer == "bag" and inv.equipped.bag and inv.items[inv.equipped.bag] then
                    item.container = inv.items[inv.equipped.bag].bagContainer or "root"
                else
                    item.container = "root"
                end
            end
            createItem(record, inv, item)
        end
    end
    inv.deltaMode = record.recruited == true and "full" or "template_plus_delta"
    if hadInventory then
        inv.revision = math.max(1, tonumber(inv.revision) or 0)
    end
    refreshNextItemSerial(record, inv)
    Inventory.RebuildCaches(record)
    return record.inventory
end

function Inventory.ApplyDelta(record, ops, reason)
    local inv = Inventory.EnsureRecordInventory(record)
    local appliedOps = {}
    local i
    local op
    local item
    if type(ops) ~= "table" then
        return false
    end
    for i = 1, #ops do
        op = ops[i]
        if type(op) == "table" then
            if op.op == "add" and type(op.item) == "table" then
                item = createItem(record, inv, op.item)
                if item then
                    appliedOps[#appliedOps + 1] = buildOperation("add", {
                        item = itemToPayload(item),
                        container = item.container,
                    })
                end
            elseif op.op == "move" and normalizeString(op.itemID) and normalizeString(op.to) then
                item = inv.items[op.itemID]
                if item and setItemContainer(inv, item, op.to) then
                    appliedOps[#appliedOps + 1] = buildOperation("move", {
                        itemID = item.id,
                        to = item.container,
                    })
                end
            elseif op.op == "remove" and normalizeString(op.itemID) then
                item = inv.items[op.itemID]
                if item and removeItemByID(inv, op.itemID) then
                    appliedOps[#appliedOps + 1] = buildOperation("remove", {
                        itemID = op.itemID,
                    })
                end
            elseif op.op == "update" and normalizeString(op.itemID) then
                item = inv.items[op.itemID]
                if item then
                    if op.stack ~= nil then
                        item.stack = math.max(1, math.floor(tonumber(op.stack) or item.stack or 1))
                    end
                    if op.uses ~= nil then
                        item.uses = tonumber(op.uses)
                    end
                    if op.cond ~= nil then
                        item.cond = tonumber(op.cond)
                    end
                    appliedOps[#appliedOps + 1] = buildOperation("update", {
                        itemID = item.id,
                        stack = item.stack,
                        uses = item.uses,
                        cond = item.cond,
                    })
                end
            end
        end
    end
    if #appliedOps <= 0 then
        return false
    end
    bumpRevision(record, appliedOps, reason)
    Inventory.SyncEquipmentFromInventory(record)
    Inventory.RebuildCaches(record)
    return true
end

function Inventory.BuildSummaryPayload(record)
    local inv = Inventory.EnsureRecordInventory(record)
    if not inv then
        return nil
    end
    return {
        revision = inv.revision,
        usedWeight = tonumber(inv.cachedWeight) or 0,
        maxWeight = tonumber(inv.maxWeight) or 0,
        remainingWeight = tonumber(inv.remainingWeight) or 0,
        itemCount = tonumber(inv.itemCount) or countMapEntries(inv.items),
        containerCount = tonumber(inv.containerCount) or countMapEntries(inv.containers),
        signature = inv.signature,
        deltaMode = inv.deltaMode,
    }
end

function Inventory.BuildFullPayload(record)
    local inv = Inventory.EnsureRecordInventory(record)
    local items = {}
    local containers = {}
    local id
    if not inv then
        return nil
    end
    for id, _ in pairs(inv.items or {}) do
        items[id] = itemToPayload(inv.items[id])
    end
    for id, _ in pairs(inv.containers or {}) do
        containers[id] = {
            maxWeight = tonumber(inv.containers[id].maxWeight) or 0,
            items = shallowArrayCopy(inv.containers[id].items),
        }
    end
    return {
        revision = inv.revision,
        deltaMode = inv.deltaMode,
        template = Core.DeepCopy(inv.template or {}),
        summary = Inventory.BuildSummaryPayload(record),
        equipped = Core.DeepCopy(inv.equipped or {}),
        worn = Core.DeepCopy(inv.worn or {}),
        attached = Core.DeepCopy(inv.attached or {}),
        items = items,
        containers = containers,
    }
end

function Inventory.BuildDeltaPayload(record, sinceRevision)
    local runtime = getRuntimeState(record)
    local inv = Inventory.EnsureRecordInventory(record)
    local payload = {}
    local i
    local entry
    sinceRevision = tonumber(sinceRevision) or 0
    if not inv or not runtime or type(runtime.opLog) ~= "table" then
        return nil
    end
    for i = 1, #runtime.opLog do
        entry = runtime.opLog[i]
        if entry and (tonumber(entry.revision) or 0) > sinceRevision then
            payload[#payload + 1] = Core.DeepCopy(entry.op)
        end
    end
    if #payload <= 0 then
        return nil
    end
    return {
        npcId = record.id,
        inventoryRevision = inv.revision,
        ops = payload,
        summary = Inventory.BuildSummaryPayload(record),
    }
end

function Inventory.Serialize(record)
    local inv = Inventory.EnsureRecordInventory(record)
    local payload
    if not inv then
        return nil
    end
    if record.recruited ~= true and inv.deltaMode == "template_plus_delta" then
        payload = {
            revision = inv.revision,
            deltaMode = inv.deltaMode,
            maxWeight = inv.maxWeight,
            cachedWeight = inv.cachedWeight,
            template = {
                archetypeID = record.archetypeID,
                seed = record.identitySeed,
            },
            delta = buildCompactDelta(record, inv),
        }
        return payload
    end
    payload = Inventory.BuildFullPayload(record)
    payload.maxWeight = inv.maxWeight
    payload.cachedWeight = inv.cachedWeight
    return payload
end

function Inventory.Deserialize(record, rawInventory)
    local inv
    if not record then
        return nil
    end
    if type(rawInventory) ~= "table" then
        return Inventory.CreateFromTemplate(record)
    end
    if normalizeString(rawInventory.deltaMode) == "template_plus_delta" and not rawInventory.items then
        inv = Inventory.CreateFromTemplate(record, { keepRevision = rawInventory.revision })
        inv.deltaMode = "template_plus_delta"
        inv.maxWeight = tonumber(rawInventory.maxWeight) or inv.maxWeight
        inv.cachedWeight = tonumber(rawInventory.cachedWeight) or inv.cachedWeight
        applySavedDelta(record, inv, rawInventory.delta)
        Inventory.SyncEquipmentFromInventory(record)
        Inventory.RebuildCaches(record)
        return inv
    end
    record.inventory = {
        revision = tonumber(rawInventory.revision) or 0,
        deltaMode = normalizeString(rawInventory.deltaMode) or (record.recruited == true and "full" or "template_plus_delta"),
        cachedWeight = tonumber(rawInventory.cachedWeight) or 0,
        maxWeight = tonumber(rawInventory.maxWeight) or buildBaseCarryWeight(record),
        rootMaxWeight = tonumber(rawInventory.rootMaxWeight) or tonumber(rawInventory.maxWeight) or buildBaseCarryWeight(record),
        template = type(rawInventory.template) == "table" and Core.DeepCopy(rawInventory.template) or {
            archetypeID = record.archetypeID,
            seed = record.identitySeed,
        },
        equipped = type(rawInventory.equipped) == "table" and Core.DeepCopy(rawInventory.equipped) or {},
        worn = type(rawInventory.worn) == "table" and Core.DeepCopy(rawInventory.worn) or {},
        attached = type(rawInventory.attached) == "table" and Core.DeepCopy(rawInventory.attached) or {},
        items = type(rawInventory.items) == "table" and Core.DeepCopy(rawInventory.items) or {},
        containers = type(rawInventory.containers) == "table" and Core.DeepCopy(rawInventory.containers) or {},
    }
    inv = Inventory.EnsureRecordInventory(record)
    Inventory.SyncEquipmentFromInventory(record)
    Inventory.RebuildCaches(record)
    refreshNextItemSerial(record, inv)
    return inv
end
