PNC = PNC or {}
PNC.Equipment = PNC.Equipment or {}

local Equipment = PNC.Equipment

function Equipment.CreateItem(fullType)
    local ok
    local item
    local script

    if not fullType or fullType == "" then
        return nil, "no_full_type"
    end

    if instanceItem then
        ok, item = pcall(instanceItem, fullType)
        if ok and item then
            return item, "instance_item"
        end
    end

    if InventoryItemFactory and InventoryItemFactory.CreateItem then
        ok, item = pcall(InventoryItemFactory.CreateItem, fullType)
        if ok and item then
            return item, "item_factory"
        end
    end

    script = getScriptManager and getScriptManager():getItem(fullType) or nil
    if script then
        return nil, "script_found_no_instance"
    end

    return nil, "invalid_full_type"
end
