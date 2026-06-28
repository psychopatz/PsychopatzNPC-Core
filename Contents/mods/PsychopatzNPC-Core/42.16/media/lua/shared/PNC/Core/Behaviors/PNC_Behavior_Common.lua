--[[
    PNC Behavior Common
    Shared behavior helpers for combat debug state, owner resolution, and
    movement intent routing. Focused modules call through here instead of
    reimplementing the same record mutations.
]]

PNC = PNC or {}
PNC.BehaviorCommon = PNC.BehaviorCommon or {}

local Common = PNC.BehaviorCommon
local Core = PNC.Core
local Const = PNC.Const
local PathService = PNC.PathService
local Equipment = PNC.Equipment

local function resolveMoveIntent()
    return PNC.BehaviorMoveIntent
end

function Common.SetCombatDebug(record, target, reason, modeResolved, weaponStatus)
    record.runtime = record.runtime or {}
    record.runtime.targetKind = target and target.kind or "none"
    record.runtime.combatModeResolved = modeResolved or tostring(record.weaponMode or "melee")
    record.runtime.weaponStatus = weaponStatus or record.runtime.weaponStatus or "unknown"
    record.runtime.combatBlockReason = reason or "idle"
end

function Common.ClearCombatTarget(record, reason)
    local equipmentInfo = Equipment.Describe(record)
    record.runtime = record.runtime or {}
    record.runtime.target = nil
    Common.SetCombatDebug(
        record,
        nil,
        reason or "no_target",
        equipmentInfo.combatModeResolved or tostring(record.weaponMode or "melee"),
        equipmentInfo.weaponStatus or record.runtime.weaponStatus
    )
end

function Common.GetOwner(record)
    return Core.ResolvePlayerByOnlineID(record.ownerOnlineID) or Core.ResolvePlayerByUsername(record.ownerUsername)
end

function Common.MoveRecord(record, zombie, tx, ty, tz, mode, stopDistance)
    if record.presenceState == Const.PRESENCE_LIVE then
        if resolveMoveIntent() and resolveMoveIntent().RequestMove then
            resolveMoveIntent().RequestMove(record, tx, ty, tz, mode, stopDistance, "behavior_move")
            return true, "move_intent"
        end
        return PathService.MoveToward(record, zombie, tx, ty, tz, mode, stopDistance)
    end
    PathService.AdvanceAbstract(record, tx, ty, tz, stopDistance)
    return true, "abstract_move"
end

function Common.ResolveCombatApproachMode(dist, preferredMode)
    if preferredMode == "run" and tonumber(dist) and tonumber(dist) <= 3.5 then
        return "walk"
    end
    return preferredMode
end

function Common.HaltMovement(record, zombie, reason)
    if record and record.presenceState == Const.PRESENCE_LIVE and resolveMoveIntent() and resolveMoveIntent().Hold then
        resolveMoveIntent().Hold(record, reason or "hold")
        return
    end
    if zombie and PathService and PathService.Reset then
        PathService.Reset(zombie, record)
    end
end
