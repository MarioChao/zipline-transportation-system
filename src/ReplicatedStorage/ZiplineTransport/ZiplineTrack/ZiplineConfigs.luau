--!strict

-- Zipline Configs


---------- Types ----------

export type ZiplineConfigs = {
    hide_controlPoints: boolean,
    startDelay_objects: number,
    startDelay_players: number,
    support_objects: boolean,
    support_players: boolean,
    traverseSpeed: number,
    waypointTouchRadius: number,
}


---------- Constants ----------

local Constants = {}

Constants.ZiplineConfigAttributeNames = {
    hide_controlPoints = "Hide_ControlPoints",
    startDelay_objects = "StartDelay_Objects",
    startDelay_players = "StartDelay_Players",
    support_objects = "Support_Objects",
    support_players = "Support_Players",
    traverseSpeed = "TraverseSpeed",
    waypointTouchRadius = "WaypointTouchRadius",
}

table.freeze(Constants)


---------- Module ----------

local Module = {}


----- Module fields -----

function Module.getConfigs(configsInstance: Configuration)
    local result = {
        hide_controlPoints = configsInstance:GetAttribute(Constants.ZiplineConfigAttributeNames.hide_controlPoints) == true,
        startDelay_objects = tonumber(configsInstance:GetAttribute(Constants.ZiplineConfigAttributeNames.startDelay_objects)) or 0,
        startDelay_players = tonumber(configsInstance:GetAttribute(Constants.ZiplineConfigAttributeNames.startDelay_players)) or 0.5,
        support_objects = configsInstance:GetAttribute(Constants.ZiplineConfigAttributeNames.support_objects) == true,
        support_players = configsInstance:GetAttribute(Constants.ZiplineConfigAttributeNames.support_players) == true,
        traverseSpeed = tonumber(configsInstance:GetAttribute(Constants.ZiplineConfigAttributeNames.traverseSpeed)) or 16,
        waypointTouchRadius = tonumber(configsInstance:GetAttribute(Constants.ZiplineConfigAttributeNames.waypointTouchRadius)) or 1,
    } :: ZiplineConfigs

    return result
end


---------- Return module ----------

return Module
