PNC = PNC or {}
PNC.OrderSystem = PNC.OrderSystem or {}

local OrderSystem = PNC.OrderSystem
local Const = PNC.Const
local Core = PNC.Core

local function fallbackOrder(record)
    if record.faction == "hostile" then
        return { kind = Const.ORDER_HOSTILE_HUNT }
    end
    return { kind = Const.ORDER_GUARD, x = record.anchorX, y = record.anchorY, z = record.anchorZ }
end

function OrderSystem.Normalize(record, orderSpec)
    local spec = orderSpec or fallbackOrder(record)
    local kind = tostring(spec.kind or spec.mode or "")

    if kind == "" then
        return fallbackOrder(record)
    end

    if kind == Const.ORDER_FOLLOW then
        return {
            kind = kind,
            ownerUsername = spec.ownerUsername or record.ownerUsername,
            ownerOnlineID = spec.ownerOnlineID or record.ownerOnlineID,
        }
    end

    if kind == Const.ORDER_GUARD then
        return {
            kind = kind,
            x = tonumber(spec.x) or record.anchorX,
            y = tonumber(spec.y) or record.anchorY,
            z = tonumber(spec.z) or record.anchorZ,
        }
    end

    if kind == Const.ORDER_PATROL then
        return {
            kind = kind,
            points = Core.DeepCopy(spec.points or record.patrolPoints or {
                { x = record.anchorX, y = record.anchorY, z = record.anchorZ },
            }),
        }
    end

    if kind == Const.ORDER_HOSTILE_ROAM or kind == Const.ORDER_HOSTILE_HUNT then
        return {
            kind = kind,
            x = tonumber(spec.x) or record.anchorX,
            y = tonumber(spec.y) or record.anchorY,
            z = tonumber(spec.z) or record.anchorZ,
        }
    end

    return fallbackOrder(record)
end

function OrderSystem.SetOrder(record, orderSpec)
    record.orderSpec = OrderSystem.Normalize(record, orderSpec)
    record.runtime.target = nil
    record.runtime.lastPathX = nil
    record.runtime.lastPathY = nil
    if record.orderSpec.kind == Const.ORDER_PATROL and record.patrolIndex == nil then
        record.patrolIndex = 1
    end
end

function OrderSystem.SetHostility(record, modeSpec)
    record.hostility = record.hostility or {}
    record.hostility.mode = tostring(modeSpec and modeSpec.mode or record.hostility.mode or "neutral")
    record.hostility.attackPlayers = modeSpec and modeSpec.attackPlayers == true or record.hostility.attackPlayers == true
    record.hostility.attackNPCs = modeSpec and modeSpec.attackNPCs ~= false or record.hostility.attackNPCs ~= false
    record.hostility.attackZombies = modeSpec and modeSpec.attackZombies ~= false or record.hostility.attackZombies ~= false
end
