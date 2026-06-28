--[[
    PNC Behavior System
    Thin coordinator for live and abstract NPC behavior ticks. Focused job,
    combat, targeting, and common helpers live in separate Lua files so this
    entry point stays small and scalable.
]]

require "PNC/Core/Behaviors/PNC_Behavior_MoveIntent"
require "PNC/Core/Behaviors/PNC_Behavior_Common"
require "PNC/Core/Behaviors/PNC_Behavior_Targeting"
require "PNC/Core/Behaviors/PNC_Behavior_Combat"
require "PNC/Core/Behaviors/PNC_Behavior_Incapacitated"
require "PNC/Core/Behaviors/PNC_Behavior_Companion"
require "PNC/Core/Behaviors/PNC_Behavior_Hostile"

PNC = PNC or {}
PNC.BehaviorSystem = PNC.BehaviorSystem or {}

local Behavior = PNC.BehaviorSystem
local JobSystem = PNC.JobSystem
local Animation = PNC.Animation
local Common = PNC.BehaviorCommon
local Incapacitated = PNC.BehaviorIncapacitated
local Companion = PNC.BehaviorCompanion
local Hostile = PNC.BehaviorHostile

function Behavior.Tick(record, zombie, now)
    local job

    if record.alive == false then
        record.activeJob = "Dead"
        record.activeBehavior = "Dead"
        Common.ClearCombatTarget(record, "dead")
        if zombie then
            Animation.Apply(zombie, record, "Idle")
        end
        return
    end

    if record.health and record.health.state == "incapacitated" then
        Incapacitated.Tick(record, zombie)
        return
    end

    job = JobSystem.Select(record)
    record.activeJob = job
    record.activeBehavior = job

    if Companion.Tick(record, zombie, job) then
        return
    end

    if Hostile.Tick(record, zombie, job) then
        return
    end

    Common.ClearCombatTarget(record, "idle")
    if zombie then
        Animation.Apply(zombie, record, "Idle")
    end
end
