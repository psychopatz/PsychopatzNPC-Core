--[[
    PNC Path Service
    Entry point for the split pathing subsystem. The public `PNC.PathService`
    table remains stable while focused implementation files live under the
    dedicated `PNC_PathService/` folder.
]]

PNC = PNC or {}
PNC.PathService = PNC.PathService or {}

local PathService = PNC.PathService
PathService.Internal = PathService.Internal or {}

require "PNC/Core/Pathing/PNC_PathService/PNC_PathService_Context"
require "PNC/Core/Pathing/PNC_PathService/PNC_PathService_Facing"
require "PNC/Core/Pathing/PNC_PathService/PNC_PathService_Logging"
require "PNC/Core/Pathing/PNC_PathService/PNC_PathService_Interactions"
require "PNC/Core/Pathing/PNC_PathService/PNC_PathService_Lane"
require "PNC/Core/Pathing/PNC_PathService/PNC_PathService_Motion"
