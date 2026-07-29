--!strict

-- Zipline Configs


---------- Types ----------

type WaypointConfig = {
    activate_proximityPrompt: boolean,
    activate_playerTouch: boolean,
    create_middle: boolean,
    create_start: boolean,
    create_stop: boolean,
    touch_radius: number,
}

export type ZiplineConfig = {
    hide_controlPoints: boolean,
    startDelay_clientPies: number,
    startDelay_objects: number,
    startDelay_players: number,
    support_clientPies: boolean,
    support_objects: boolean,
    support_players: boolean,
    traverseSpeed: number,
    waypointProximityPrompt: ProximityPrompt,
    waypointConfig: WaypointConfig,
}


---------- Constants ----------

local Constants = {}

Constants.waypointConfigAttributes = {
    activate_proximityPrompt = "Activate_ProximityPrompt",
    activate_playerTouch = "Activate_PlayerTouch",
    create_middle = "Create_Middle",
    create_start = "Create_Start",
    create_stop = "Create_Stop",
    touch_radius = "Touch_Radius",
}

Constants.ziplineConfigAttributes = {
    hide_controlPoints = "Hide_ControlPoints",
    startDelay_clientPies = "StartDelay_ClientPies",
    startDelay_objects = "StartDelay_Objects",
    startDelay_players = "StartDelay_Players",
    support_clientPies = "Support_ClientPies",
    support_objects = "Support_Objects",
    support_players = "Support_Players",
    traverseSpeed = "TraverseSpeed",
}

table.freeze(Constants)


---------- Local functions ----------

local getZiplineConfig
local getWaypointConfig


----- Config functions -----

getZiplineConfig = function(configInstance: Configuration?)
    local realConfig = configInstance or Instance.new("Configuration")

    local result = {
        hide_controlPoints = realConfig:GetAttribute(Constants.ziplineConfigAttributes.hide_controlPoints) ~= false,
        startDelay_clientPies = tonumber(realConfig:GetAttribute(Constants.ziplineConfigAttributes.startDelay_clientPies)) or 0,
        startDelay_objects = tonumber(realConfig:GetAttribute(Constants.ziplineConfigAttributes.startDelay_objects)) or 0,
        startDelay_players = tonumber(realConfig:GetAttribute(Constants.ziplineConfigAttributes.startDelay_players)) or 0.5,
        support_clientPies = realConfig:GetAttribute(Constants.ziplineConfigAttributes.support_clientPies) ~= false,
        support_objects = realConfig:GetAttribute(Constants.ziplineConfigAttributes.support_objects) ~= false,
        support_players = realConfig:GetAttribute(Constants.ziplineConfigAttributes.support_players) ~= false,
        traverseSpeed = tonumber(realConfig:GetAttribute(Constants.ziplineConfigAttributes.traverseSpeed)) or 16,
    } :: ZiplineConfig

    result.waypointProximityPrompt = (realConfig:FindFirstChild("WaypointProximityPrompt") :: ProximityPrompt) or (function()
        local proximityPrompt = Instance.new("ProximityPrompt")
        proximityPrompt.Parent = realConfig
        return proximityPrompt
    end)()
    result.waypointConfig = getWaypointConfig(realConfig:FindFirstChild("WaypointConfig") :: Configuration or Instance.new("Configuration"))
    return result
end

getWaypointConfig = function(configInstance: Configuration?)
    local realConfig = configInstance or Instance.new("Configuration")

    local result = {
        activate_proximityPrompt = realConfig:GetAttribute(Constants.waypointConfigAttributes.activate_proximityPrompt) == true,
        activate_playerTouch = realConfig:GetAttribute(Constants.waypointConfigAttributes.activate_playerTouch) ~= false,
        create_middle = realConfig:GetAttribute(Constants.waypointConfigAttributes.create_middle) == true,
        create_start = realConfig:GetAttribute(Constants.waypointConfigAttributes.create_start) ~= false,
        create_stop = realConfig:GetAttribute(Constants.waypointConfigAttributes.create_stop) ~= false,
        touch_radius = tonumber(realConfig:GetAttribute(Constants.waypointConfigAttributes.touch_radius)) or 1,
    } :: WaypointConfig
    return result
end


---------- Module ----------

local Module = {}


----- Module fields -----

function Module.getConfig(configInstance: Configuration?)
    return getZiplineConfig(configInstance)
end


---------- Return module ----------

return Module
