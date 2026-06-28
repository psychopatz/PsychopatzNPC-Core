--[[
    PNC Behavior Combat
    Encapsulates combat engagement flow so job handlers can hand off an active
    target without owning melee, ranged, and retreat state sequencing.
]]

PNC = PNC or {}
PNC.BehaviorCombat = PNC.BehaviorCombat or {}

local BehaviorCombat = PNC.BehaviorCombat
local Core = PNC.Core
local Const = PNC.Const
local Combat = PNC.Combat
local Equipment = PNC.Equipment
local Tactics = PNC.CombatTactics
local Common = PNC.BehaviorCommon
local Targeting = PNC.BehaviorTargeting

function BehaviorCombat.TickEngage(record, zombie, target)
    local dist = math.sqrt(tonumber(target and target.distSq or 0) or 0)
    local equipmentInfo = Equipment.Describe(record)
    local effectiveMode = equipmentInfo.combatModeResolved
    local previousWeaponStatus = record.runtime.weaponStatus
    local attacked
    local reason
    local actionActive
    local repositioned
    local repositionReason

    Targeting.BindLiveTarget(zombie, target)
    Common.SetCombatDebug(record, target, "engaging_" .. tostring(target.kind or "unknown"), effectiveMode, equipmentInfo.weaponStatus)

    if equipmentInfo.weaponStatus ~= previousWeaponStatus then
        Core.LogRecordDebug(record, "NPC " .. tostring(record.id) .. " weapon state=" .. tostring(equipmentInfo.weaponStatus))
    end

    if Combat and Combat.PumpAttackAction then
        actionActive, reason = Combat.PumpAttackAction(record, zombie)
        if actionActive then
            Common.HaltMovement(record, zombie)
            Common.SetCombatDebug(record, target, reason or "attack_in_progress", effectiveMode, equipmentInfo.weaponStatus)
            return
        end
    end

    if effectiveMode == "ranged" and Tactics and Tactics.TryReposition and target.kind == "zombie" and dist < 4.2 then
        repositioned, repositionReason = Tactics.TryReposition(record, zombie, target, effectiveMode, "target_too_close", equipmentInfo)
        if repositioned then
            Common.SetCombatDebug(record, target, repositionReason or "maintaining_range", effectiveMode, equipmentInfo.weaponStatus)
            return
        end
    end

    if effectiveMode == "melee" then
        attacked, reason = Combat.TryMelee(record, zombie, target)
        if attacked then
            if Tactics and Tactics.ClearRetreatState then
                Tactics.ClearRetreatState(record)
            end
            Common.HaltMovement(record, zombie)
            Common.SetCombatDebug(record, target, "attacking_melee", effectiveMode, equipmentInfo.weaponStatus)
            return
        end
        if reason == "target_out_of_range" then
            Common.MoveRecord(record, zombie, target.x, target.y, target.z, Common.ResolveCombatApproachMode(dist, "run"), Const.MELEE_RANGE)
            Common.SetCombatDebug(record, target, "closing_to_melee", effectiveMode, equipmentInfo.weaponStatus)
            return
        end
        if Tactics and Tactics.TryReposition then
            repositioned, repositionReason = Tactics.TryReposition(record, zombie, target, effectiveMode, reason, equipmentInfo)
        else
            repositioned, repositionReason = false, nil
        end
        if repositioned then
            Common.SetCombatDebug(record, target, repositionReason or "melee_kiting", effectiveMode, equipmentInfo.weaponStatus)
            return
        end
        Common.SetCombatDebug(record, target, reason, effectiveMode, equipmentInfo.weaponStatus)
        Core.LogRecordDebug(record, "NPC " .. tostring(record.id) .. " melee blocked=" .. tostring(reason))
        return
    end

    if effectiveMode == "ranged" then
        attacked, reason = Combat.TryRanged(record, zombie, target)
        if attacked then
            if Tactics and Tactics.ClearRetreatState then
                Tactics.ClearRetreatState(record)
            end
            Common.HaltMovement(record, zombie)
            Common.SetCombatDebug(record, target, "attacking_ranged", effectiveMode, equipmentInfo.weaponStatus)
            return
        end
        if reason == "target_out_of_range" then
            Common.MoveRecord(record, zombie, target.x, target.y, target.z, Common.ResolveCombatApproachMode(dist, "run"), Const.RANGED_RANGE * 0.8)
            Common.SetCombatDebug(record, target, "closing_to_range", effectiveMode, equipmentInfo.weaponStatus)
            return
        end
        if Tactics and Tactics.TryReposition then
            repositioned, repositionReason = Tactics.TryReposition(record, zombie, target, effectiveMode, reason, equipmentInfo)
        else
            repositioned, repositionReason = false, nil
        end
        if repositioned then
            Common.SetCombatDebug(record, target, repositionReason or "maintaining_range", effectiveMode, equipmentInfo.weaponStatus)
            return
        end
        Common.SetCombatDebug(record, target, reason, effectiveMode, equipmentInfo.weaponStatus)
        Core.LogRecordDebug(record, "NPC " .. tostring(record.id) .. " ranged blocked=" .. tostring(reason))
        return
    end

    if dist <= Const.MELEE_RANGE * 1.1 then
        attacked, reason = Combat.TryMelee(record, zombie, target)
        if attacked then
            if Tactics and Tactics.ClearRetreatState then
                Tactics.ClearRetreatState(record)
            end
            Common.HaltMovement(record, zombie)
            Common.SetCombatDebug(record, target, "attacking_melee", "mixed", equipmentInfo.weaponStatus)
            return
        end
        if Tactics and Tactics.TryReposition then
            repositioned, repositionReason = Tactics.TryReposition(record, zombie, target, "melee", reason, equipmentInfo)
        else
            repositioned, repositionReason = false, nil
        end
        if repositioned then
            Common.SetCombatDebug(record, target, repositionReason or "melee_kiting", "mixed", equipmentInfo.weaponStatus)
            return
        end
        Common.SetCombatDebug(record, target, reason, "mixed", equipmentInfo.weaponStatus)
        Core.LogRecordDebug(record, "NPC " .. tostring(record.id) .. " mixed melee blocked=" .. tostring(reason))
        return
    end

    attacked, reason = Combat.TryRanged(record, zombie, target)
    if attacked then
        if Tactics and Tactics.ClearRetreatState then
            Tactics.ClearRetreatState(record)
        end
        Common.HaltMovement(record, zombie)
        Common.SetCombatDebug(record, target, "attacking_ranged", "mixed", equipmentInfo.weaponStatus)
        return
    end
    if reason == "target_out_of_range" then
        Common.MoveRecord(record, zombie, target.x, target.y, target.z, Common.ResolveCombatApproachMode(dist, "run"), Const.RANGED_RANGE * 0.85)
        Common.SetCombatDebug(record, target, "closing_to_range", "mixed", equipmentInfo.weaponStatus)
        return
    end
    if Tactics and Tactics.TryReposition then
        repositioned, repositionReason = Tactics.TryReposition(record, zombie, target, "ranged", reason, equipmentInfo)
    else
        repositioned, repositionReason = false, nil
    end
    if repositioned then
        Common.SetCombatDebug(record, target, repositionReason or "maintaining_range", "mixed", equipmentInfo.weaponStatus)
        return
    end
    Common.SetCombatDebug(record, target, reason, "mixed", equipmentInfo.weaponStatus)
    Core.LogRecordDebug(record, "NPC " .. tostring(record.id) .. " mixed ranged blocked=" .. tostring(reason))
end
