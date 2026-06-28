PNC = PNC or {}
PNC.Equipment = PNC.Equipment or {}

local Equipment = PNC.Equipment

local MANAGED_ATTACHMENT_TYPES = {
    Back = true,
    HolsterLeft = true,
    HolsterRight = true,
    HolsterShoulder = true,
    SmallBeltLeft = true,
    SmallBeltRight = true,
    WebbingLeft = true,
    WebbingRight = true,
}

local MANAGED_SLOT_TYPE_PRIORITY = {
    HolsterRight = 1,
    HolsterLeft = 2,
    HolsterShoulder = 3,
    SmallBeltLeft = 4,
    SmallBeltRight = 5,
    WebbingLeft = 6,
    WebbingRight = 7,
    Back = 8,
}

local ATTACHMENT_TYPE_SLOT_PRIORITY = {
    BigBlade = { "Back" },
    BigWeapon = { "Back" },
    Guitar = { "Back" },
    GuitarAcoustic = { "Back" },
    Hammer = { "SmallBeltLeft", "SmallBeltRight" },
    HammerRotated = { "SmallBeltLeft", "SmallBeltRight" },
    Holster = { "HolsterRight", "HolsterLeft", "HolsterShoulder" },
    HolsterSmall = { "HolsterRight", "HolsterLeft", "HolsterShoulder" },
    Knife = { "SmallBeltLeft", "SmallBeltRight", "WebbingLeft", "WebbingRight" },
    MeatCleaver = { "SmallBeltLeft", "SmallBeltRight" },
    Nightstick = { "SmallBeltLeft", "SmallBeltRight" },
    NotKnife = { "SmallBeltLeft", "SmallBeltRight" },
    Pan = { "Back" },
    Racket = { "Back" },
    Rifle = { "Back" },
    Saucepan = { "Back" },
    Screwdriver = { "SmallBeltLeft", "SmallBeltRight" },
    Shovel = { "Back" },
    Sword = { "Back", "SmallBeltLeft", "SmallBeltRight" },
    Walkie = { "SmallBeltLeft", "SmallBeltRight", "WebbingLeft", "WebbingRight" },
    Webbing = { "WebbingLeft", "WebbingRight" },
    Wrench = { "SmallBeltLeft", "SmallBeltRight" },
}

local BODY_LOCATIONS_ORDERED = {
    "UnderwearBottom", "UnderwearTop", "UnderwearExtra1", "UnderwearExtra2", "Underwear", "Codpiece", "Torso1Legs1", "Legs1",
    "Ears", "EarTop", "Nose", "Hat", "FullHat", "SCBA",
    "Mask", "MaskEyes", "Eyes", "RightEye", "LeftEye",
    "Neck", "Necklace", "Necklace_Long", "Gorget", "Scarf",
    "Pants", "Pants_Skinny", "PantsExtra", "ShortPants", "ShortsShort", "LongSkirt", "Skirt", "Dress", "LongDress",
    "TankTop", "Tshirt", "ShortSleeveShirt", "Shirt", "Jersey",
    "VestTexture", "Sweater", "SweaterHat", "TorsoExtraVest", "Cuirass", "TorsoExtra",
    "Jacket", "JacketHat", "Jacket_Down", "JacketHat_Bulky", "Jacket_Bulky", "JacketSuit", "FullTop",
    "RightWrist", "Right_MiddleFinger", "Right_RingFinger", "LeftWrist", "Left_MiddleFinger", "Left_RingFinger", "Hands", "HandsRight", "HandsLeft",
    "BathRobe", "FullSuit", "FullSuitHead", "Boilersuit", "Tail", "TorsoExtraVestBullet",
    "ShoulderpadRight", "ShoulderpadLeft", "Elbow_Right", "Elbow_Left", "ForeArm_Right", "ForeArm_Left",
    "Thigh_Right", "Thigh_Left", "Knee_Right", "Knee_Left", "Calf_Right", "Calf_Left",
    "FannyPackFront", "FannyPackBack", "Webbing", "Back",
    "AmmoStrap", "AnkleHolster", "BeltExtra", "ShoulderHolster",
    "Socks", "Shoes"
}

local BODY_LOCATION_PRIORITY = nil
local BODY_LOCATION_CANONICAL = nil
local ATTACHMENT_LOCATION_TO_TYPE = nil

local function normalizeString(value)
    if value == nil or value == "" then
        return nil
    end
    return tostring(value)
end

local function normalizeStringMap(source)
    local output = {}
    local key
    local value
    if type(source) ~= "table" then
        return output
    end
    for key, value in pairs(source) do
        key = normalizeString(key)
        value = normalizeString(value)
        if key and value then
            output[key] = value
        end
    end
    return output
end

local function getBodyLocationCanonical()
    local map
    local i
    local canonical
    if BODY_LOCATION_CANONICAL then
        return BODY_LOCATION_CANONICAL
    end
    map = {}
    for i = 1, #BODY_LOCATIONS_ORDERED do
        canonical = BODY_LOCATIONS_ORDERED[i]
        map[string.lower(canonical)] = canonical
    end
    BODY_LOCATION_CANONICAL = map
    return BODY_LOCATION_CANONICAL
end

local function normalizeBodyLocation(value)
    local lowered
    local stripped
    local canonical
    value = normalizeString(value)
    if not value then
        return nil
    end
    lowered = string.lower(value)
    stripped = string.match(lowered, "([^:%.]+)$") or lowered
    canonical = getBodyLocationCanonical()[stripped]
    if canonical then
        return canonical
    end
    return value
end

local function normalizeWornMap(source)
    local output = {}
    local key
    local value
    if type(source) ~= "table" then
        return output
    end
    for key, value in pairs(source) do
        key = normalizeBodyLocation(key)
        value = normalizeString(value)
        if key and value then
            output[key] = value
        end
    end
    return output
end

local function getBodyLocationPriority()
    local i
    if BODY_LOCATION_PRIORITY then
        return BODY_LOCATION_PRIORITY
    end
    BODY_LOCATION_PRIORITY = {}
    for i = 1, #BODY_LOCATIONS_ORDERED do
        BODY_LOCATION_PRIORITY[BODY_LOCATIONS_ORDERED[i]] = i
    end
    return BODY_LOCATION_PRIORITY
end

local function getAttachmentLocationToType()
    local map
    local _
    local def
    local attachmentType
    local location
    if ATTACHMENT_LOCATION_TO_TYPE then
        return ATTACHMENT_LOCATION_TO_TYPE
    end
    map = {}
    if ISHotbarAttachDefinition then
        for _, def in pairs(ISHotbarAttachDefinition) do
            if type(def) == "table" and def.attachments then
                for attachmentType, location in pairs(def.attachments) do
                    if attachmentType and location and not map[location] then
                        map[location] = def.type
                    end
                end
            end
        end
    end
    ATTACHMENT_LOCATION_TO_TYPE = map
    return ATTACHMENT_LOCATION_TO_TYPE
end

function Equipment.NormalizeLoadoutSpec(loadoutSpec)
    local source = type(loadoutSpec) == "table" and loadoutSpec or {}
    return {
        primaryFullType = normalizeString(source.primaryFullType),
        secondaryFullType = normalizeString(source.secondaryFullType),
        worn = normalizeWornMap(source.worn),
        attached = normalizeStringMap(source.attached),
    }
end

function Equipment.EnsureRecordEquipment(record)
    if not record then
        return Equipment.NormalizeLoadoutSpec(nil)
    end
    record.equipment = Equipment.NormalizeLoadoutSpec(record.equipment)
    return record.equipment
end

function Equipment.SetLoadout(record, loadoutSpec)
    if not record then
        return false
    end
    record.equipment = Equipment.NormalizeLoadoutSpec(loadoutSpec)
    return true
end

function Equipment.SetPrimary(record, fullType)
    local equipment
    if not record then
        return false
    end
    equipment = Equipment.EnsureRecordEquipment(record)
    equipment.primaryFullType = normalizeString(fullType)
    return true
end

function Equipment.SetSecondary(record, fullType)
    local equipment
    if not record then
        return false
    end
    equipment = Equipment.EnsureRecordEquipment(record)
    equipment.secondaryFullType = normalizeString(fullType)
    return true
end

function Equipment.SetAttached(record, location, fullType)
    local equipment
    location = normalizeString(location)
    if not record or not location then
        return false
    end
    equipment = Equipment.EnsureRecordEquipment(record)
    fullType = normalizeString(fullType)
    if fullType then
        equipment.attached[location] = fullType
    else
        equipment.attached[location] = nil
    end
    return true
end

function Equipment.SetWorn(record, bodyLocation, fullType)
    local equipment
    bodyLocation = normalizeBodyLocation(bodyLocation)
    if not record or not bodyLocation then
        return false
    end
    equipment = Equipment.EnsureRecordEquipment(record)
    fullType = normalizeString(fullType)
    if fullType then
        equipment.worn[bodyLocation] = fullType
    else
        equipment.worn[bodyLocation] = nil
    end
    return true
end

function Equipment.ResolveAttachedSlotType(location)
    if not location or location == "" then
        return nil
    end
    return getAttachmentLocationToType()[tostring(location)]
end

function Equipment.ResolveAttachedLocation(item, preferredSlotType)
    local attachmentType
    local preferredLookup = {}
    local entries = {}
    local i
    local _
    local def
    local location
    local preferredTypes

    if not item or not item.getAttachmentType or not ISHotbarAttachDefinition then
        return nil, nil
    end

    attachmentType = item:getAttachmentType()
    if not attachmentType or attachmentType == "" then
        return nil, nil
    end

    preferredTypes = ATTACHMENT_TYPE_SLOT_PRIORITY[attachmentType] or {}
    for i = 1, #preferredTypes do
        preferredLookup[preferredTypes[i]] = i
    end
    if preferredSlotType and not preferredLookup[preferredSlotType] then
        preferredLookup[preferredSlotType] = 0
    end

    for _, def in pairs(ISHotbarAttachDefinition) do
        if type(def) == "table" and MANAGED_ATTACHMENT_TYPES[def.type] and def.attachments then
            location = def.attachments[attachmentType]
            if location and location ~= "" then
                entries[#entries + 1] = {
                    location = location,
                    slotType = def.type,
                    preferred = preferredLookup[def.type] or 999,
                    fallback = MANAGED_SLOT_TYPE_PRIORITY[def.type] or 999,
                }
            end
        end
    end

    table.sort(entries, function(left, right)
        if left.preferred ~= right.preferred then
            return left.preferred < right.preferred
        end
        if left.fallback ~= right.fallback then
            return left.fallback < right.fallback
        end
        return tostring(left.location) < tostring(right.location)
    end)

    if entries[1] then
        return entries[1].location, entries[1].slotType
    end
    return nil, nil
end

function Equipment.SetAttachedByItem(record, fullType, preferredSlotType)
    local item
    local createReason
    local location
    if not record then
        return false, "missing_record"
    end
    item, createReason = Equipment.CreateItem(fullType)
    if not item then
        return false, createReason or "invalid_full_type"
    end
    location = Equipment.ResolveAttachedLocation(item, preferredSlotType)
    if not location then
        return false, "no_attachment_location"
    end
    Equipment.SetAttached(record, location, fullType)
    return true, location
end

function Equipment.GetOrderedWornEntries(equipment)
    local entries = {}
    local priority = getBodyLocationPriority()
    local bodyLocation
    local fullType
    equipment = Equipment.NormalizeLoadoutSpec(equipment)
    for bodyLocation, fullType in pairs(equipment.worn) do
        entries[#entries + 1] = {
            bodyLocation = bodyLocation,
            fullType = fullType,
            priority = priority[bodyLocation] or 999,
        }
    end
    table.sort(entries, function(left, right)
        if left.priority ~= right.priority then
            return left.priority < right.priority
        end
        return tostring(left.bodyLocation) < tostring(right.bodyLocation)
    end)
    return entries
end

function Equipment.GetOrderedAttachedEntries(equipment)
    local entries = {}
    local location
    local fullType
    equipment = Equipment.NormalizeLoadoutSpec(equipment)
    for location, fullType in pairs(equipment.attached) do
        entries[#entries + 1] = {
            location = location,
            fullType = fullType,
            slotType = Equipment.ResolveAttachedSlotType(location),
        }
    end
    table.sort(entries, function(left, right)
        return tostring(left.location) < tostring(right.location)
    end)
    return entries
end

function Equipment.CaptureCharacterLoadout(character)
    local loadout = Equipment.NormalizeLoadoutSpec(nil)
    local primary
    local secondary
    local wornItems
    local attachedItems
    local i
    local entry
    local item
    local location

    if not character then
        return nil, "missing_character"
    end

    primary = character.getPrimaryHandItem and character:getPrimaryHandItem() or nil
    if primary and primary.getFullType then
        loadout.primaryFullType = normalizeString(primary:getFullType())
    end

    secondary = character.getSecondaryHandItem and character:getSecondaryHandItem() or nil
    if secondary and secondary ~= primary and secondary.getFullType then
        loadout.secondaryFullType = normalizeString(secondary:getFullType())
    end

    wornItems = character.getWornItems and character:getWornItems() or nil
    if wornItems and wornItems.size then
        for i = 0, wornItems:size() - 1 do
            entry = wornItems:get(i)
            item = entry and entry.getItem and entry:getItem() or nil
            location = entry and entry.getLocation and entry:getLocation() or nil
            if not location and item and item.getBodyLocation then
                location = item:getBodyLocation()
            end
            if item and item.getFullType and location and location ~= "" then
                loadout.worn[tostring(location)] = tostring(item:getFullType())
            end
        end
    end

    attachedItems = character.getAttachedItems and character:getAttachedItems() or nil
    if attachedItems and attachedItems.size then
        for i = 0, attachedItems:size() - 1 do
            entry = attachedItems:get(i)
            item = entry and entry.getItem and entry:getItem() or nil
            location = entry and entry.getLocation and entry:getLocation() or nil
            if item and item.getFullType and location and location ~= "" then
                loadout.attached[tostring(location)] = tostring(item:getFullType())
            end
        end
    end

    return Equipment.NormalizeLoadoutSpec(loadout), "captured"
end

function Equipment.CopyCharacterLoadout(record, character)
    local loadout
    local reason
    if not record then
        return false, "missing_record"
    end
    loadout, reason = Equipment.CaptureCharacterLoadout(character)
    if not loadout then
        return false, reason or "capture_failed"
    end
    record.equipment = loadout
    return true, reason or "captured"
end
