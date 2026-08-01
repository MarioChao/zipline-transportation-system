--!strict

-- Zipline Configs


---------- Types ----------

type FXSounds = {
    grab: Sound,
    move: Sound,
}

type FXInfo = {
    guideParticles: typeof(script.Parent.DefaultFXInfo.GuideParticles),
    guideTemplate: typeof(script.Parent.DefaultFXInfo.GuideTemplate),
    sounds: FXSounds,
    segmentPart: BasePart,
    waypointPart: BasePart,
    waypointProximityPrompt: ProximityPrompt,
}

type RidersConfig = {
    allow_userControl: boolean,
    connect_ropeLength: number,
    connect_useWeld: boolean,
    dismount_byBackwardsEnd: boolean,
    dismount_byForwardsEnd: boolean,
    dismount_byJump: boolean,
    dismount_keepMomentum: boolean,
    dismount_willJump: boolean,
    enable_angularVelocity: boolean,
    enable_linearVelocity: boolean,
    end_reverseDirection: boolean,
    offset_clientPies: Vector3,
    offset_objects: Vector3,
    offset_players: Vector3,
    offset_tagged: Vector3,
    startDelay_clientPies: number,
    startDelay_objects: number,
    startDelay_players: number,
    startDelay_tagged: number,
    support_clientPies: boolean,
    support_objects: boolean,
    support_players: boolean,
    support_tagged: boolean,
    tagName_client: string,
    tagName_server: string,
}

type WaypointsConfig = {
    activate_proximityPrompt: boolean,
    activate_playerTouch: boolean,
    create_middle: boolean,
    create_start: boolean,
    create_stop: boolean,
    touch_radius: number,
}

export type ZiplineConfig = {
    hide_controlPoints: boolean,
    isLooped: boolean,
    loop_useSmooth: boolean,
    traverseSpeed: number,
    userControl_traverseAcceleration: number,
    ridersConfig: RidersConfig,
    waypointsConfig: WaypointsConfig,
    fxInfo: FXInfo,
}


---------- Constants ----------

local Constants = {}

Constants.ridersConfigAttributes = {
    allow_userControl = "Allow_UserControl",
    connect_ropeLength = "Connect_RopeLength",
    connect_useWeld = "Connect_UseWeld",
    dismount_byBackwardsEnd = "Dismount_ByBackwardsEnd",
    dismount_byForwardsEnd = "Dismount_ByForwardsEnd",
    dismount_byJump = "Dismount_ByJump",
    dismount_keepMomentum = "Dismount_KeepMomentum",
    dismount_willJump = "Dismount_WillJump",
    enable_angularVelocity = "Enable_AngularVelocity",
    enable_linearVelocity = "Enable_LinearVelocity",
    end_reverseDirection = "End_ReverseDirection",
    offset_clientPies = "Offset_ClientPies",
    offset_objects = "Offset_Objects",
    offset_players = "Offset_Players",
    offset_tagged = "Offset_Tagged",
    startDelay_clientPies = "StartDelay_ClientPies",
    startDelay_objects = "StartDelay_Objects",
    startDelay_players = "StartDelay_Players",
    startDelay_tagged = "StartDelay_Tagged",
    support_clientPies = "Support_ClientPies",
    support_objects = "Support_Objects",
    support_players = "Support_Players",
    support_tagged = "Support_Tagged",
    tagName_client = "TagName_Client",
    tagName_server = "TagName_Server",
}

Constants.waypointsConfigAttributes = {
    activate_proximityPrompt = "Activate_ProximityPrompt",
    activate_playerTouch = "Activate_PlayerTouch",
    create_middle = "Create_Middle",
    create_start = "Create_Start",
    create_stop = "Create_Stop",
    touch_radius = "Touch_Radius",
}

Constants.ziplineConfigAttributes = {
    hide_controlPoints = "Hide_ControlPoints",
    isLooped = "IsLooped",
    loop_useSmooth = "Loop_UseSmooth",
    traverseSpeed = "TraverseSpeed",
    userControl_traverseAcceleration = "UserControl_TraverseAcceleration",
}

Constants.fxInfoNames = {
    guideParticles = "GuideParticles",
    guideTemplate = "GuideTemplate",
    segmentPart = "SegmentPart",
    waypointPart = "WaypointPart",
    waypointProximityPrompt = "WaypointProximityPrompt",
}

Constants.fxSoundsNames = {
    grab = "Grab",
    move = "Move",
}

do
    local defaultFXInfo = script.Parent:WaitForChild("DefaultFXInfo")
    local soundsFolder = defaultFXInfo:WaitForChild("Sounds")
    Constants.defaultFXInfo = {
        guideParticles = defaultFXInfo:WaitForChild(Constants.fxInfoNames.guideParticles),
        guideTemplate = defaultFXInfo:WaitForChild(Constants.fxInfoNames.guideTemplate),
        sounds = {
            grab = soundsFolder:WaitForChild(Constants.fxSoundsNames.grab),
            move = soundsFolder:WaitForChild(Constants.fxSoundsNames.move),
        },
        segmentPart = defaultFXInfo:WaitForChild(Constants.fxInfoNames.segmentPart),
        waypointPart = defaultFXInfo:WaitForChild(Constants.fxInfoNames.waypointPart),
        waypointProximityPrompt = defaultFXInfo:WaitForChild(Constants.fxInfoNames.waypointProximityPrompt),
    } :: FXInfo
end

table.freeze(Constants)


---------- Local functions ----------

local getDefault_boolean
local getDefault_childInstance
local getDefault_number
local getDefault_string
local getDefault_vector3

local getZiplineConfig
local getRidersConfig
local getWaypointsConfig
local getFXInfo


----- Default -----

getDefault_boolean = function(value: any, default: boolean)
    if type(value) == "boolean" then
        return value
    else
        return default
    end
end

getDefault_childInstance = function(parent: Instance, childName: string, default: Instance, className: string): Instance
    local child = parent:FindFirstChild(childName)
    if child and child:IsA(className) then
        return child
    else
        return default
    end
end

getDefault_number = function(value: any, default: number)
    return tonumber(value) or default
end

getDefault_string = function(value: any, default: string)
    return value or default
end

getDefault_vector3 = function(value: any, default: Vector3)
    if typeof(value) == "Vector3" then
        return value
    else
        return default
    end
end


----- Config functions -----

getZiplineConfig = function(configInstance: Configuration?)
    local realConfig = configInstance or Instance.new("Configuration")

    local result = {
        hide_controlPoints = getDefault_boolean(realConfig:GetAttribute(Constants.ziplineConfigAttributes.hide_controlPoints), true),
        isLooped = getDefault_boolean(realConfig:GetAttribute(Constants.ziplineConfigAttributes.isLooped), false),
        loop_useSmooth = getDefault_boolean(realConfig:GetAttribute(Constants.ziplineConfigAttributes.loop_useSmooth), true),
        traverseSpeed = getDefault_number(realConfig:GetAttribute(Constants.ziplineConfigAttributes.traverseSpeed), 32),
        userControl_traverseAcceleration = getDefault_number(realConfig:GetAttribute(Constants.ziplineConfigAttributes.userControl_traverseAcceleration), 32),
    } :: ZiplineConfig

    -- Riders config
    result.ridersConfig = getRidersConfig((realConfig:FindFirstChild("RidersConfig") :: Configuration or Instance.new("Configuration")))

    -- Waypoint config
    result.waypointsConfig = getWaypointsConfig(realConfig:FindFirstChild("WaypointsConfig") :: Configuration or Instance.new("Configuration"))

    -- FX Info
    result.fxInfo = getFXInfo(realConfig:FindFirstChild("FXInfo") :: Folder or Instance.new("Folder"))

    -- Return result
    return result
end

getRidersConfig = function(configInstance: Configuration?)
    local realConfig = configInstance or Instance.new("Configuration")

    local result = {
        allow_userControl = getDefault_boolean(realConfig:GetAttribute(Constants.ridersConfigAttributes.allow_userControl), false),
        connect_ropeLength = getDefault_number(realConfig:GetAttribute(Constants.ridersConfigAttributes.connect_ropeLength), 5),
        connect_useWeld = getDefault_boolean(realConfig:GetAttribute(Constants.ridersConfigAttributes.connect_useWeld), false),
        dismount_byBackwardsEnd = getDefault_boolean(realConfig:GetAttribute(Constants.ridersConfigAttributes.dismount_byBackwardsEnd), false),
        dismount_byForwardsEnd = getDefault_boolean(realConfig:GetAttribute(Constants.ridersConfigAttributes.dismount_byForwardsEnd), true),
        dismount_byJump = getDefault_boolean(realConfig:GetAttribute(Constants.ridersConfigAttributes.dismount_byJump), false),
        dismount_keepMomentum = getDefault_boolean(realConfig:GetAttribute(Constants.ridersConfigAttributes.dismount_keepMomentum), false),
        dismount_willJump = getDefault_boolean(realConfig:GetAttribute(Constants.ridersConfigAttributes.dismount_willJump), true),
        enable_angularVelocity = getDefault_boolean(realConfig:GetAttribute(Constants.ridersConfigAttributes.enable_angularVelocity), true),
        enable_linearVelocity = getDefault_boolean(realConfig:GetAttribute(Constants.ridersConfigAttributes.enable_linearVelocity), true),
        end_reverseDirection = getDefault_boolean(realConfig:GetAttribute(Constants.ridersConfigAttributes.end_reverseDirection), false),
        offset_clientPies = getDefault_vector3(realConfig:GetAttribute(Constants.ridersConfigAttributes.offset_clientPies), Vector3.zero),
        offset_objects = getDefault_vector3(realConfig:GetAttribute(Constants.ridersConfigAttributes.offset_objects), Vector3.zero),
        offset_players = getDefault_vector3(realConfig:GetAttribute(Constants.ridersConfigAttributes.offset_players), Vector3.new(0, 2, 0)),
        offset_tagged = getDefault_vector3(realConfig:GetAttribute(Constants.ridersConfigAttributes.offset_tagged), Vector3.zero),
        startDelay_clientPies = getDefault_number(realConfig:GetAttribute(Constants.ridersConfigAttributes.startDelay_clientPies), 0),
        startDelay_objects = getDefault_number(realConfig:GetAttribute(Constants.ridersConfigAttributes.startDelay_objects), 0),
        startDelay_players = getDefault_number(realConfig:GetAttribute(Constants.ridersConfigAttributes.startDelay_players), 0),
        startDelay_tagged = getDefault_number(realConfig:GetAttribute(Constants.ridersConfigAttributes.startDelay_tagged), 0),
        support_clientPies = getDefault_boolean(realConfig:GetAttribute(Constants.ridersConfigAttributes.support_clientPies), true),
        support_objects = getDefault_boolean(realConfig:GetAttribute(Constants.ridersConfigAttributes.support_objects), false),
        support_players = getDefault_boolean(realConfig:GetAttribute(Constants.ridersConfigAttributes.support_players), true),
        support_tagged = getDefault_boolean(realConfig:GetAttribute(Constants.ridersConfigAttributes.support_tagged), true),
        tagName_client = getDefault_string(realConfig:GetAttribute(Constants.ridersConfigAttributes.tagName_client), "ZiplineRider_Client"),
        tagName_server = getDefault_string(realConfig:GetAttribute(Constants.ridersConfigAttributes.tagName_server), "ZiplineRider_Server"),
    } :: RidersConfig
    return result
end

getWaypointsConfig = function(configInstance: Configuration?)
    local realConfig = configInstance or Instance.new("Configuration")

    local result = {
        activate_proximityPrompt = getDefault_boolean(realConfig:GetAttribute(Constants.waypointsConfigAttributes.activate_proximityPrompt), false),
        activate_playerTouch = getDefault_boolean(realConfig:GetAttribute(Constants.waypointsConfigAttributes.activate_playerTouch), true),
        create_middle = getDefault_boolean(realConfig:GetAttribute(Constants.waypointsConfigAttributes.create_middle), false),
        create_start = getDefault_boolean(realConfig:GetAttribute(Constants.waypointsConfigAttributes.create_start), true),
        create_stop = getDefault_boolean(realConfig:GetAttribute(Constants.waypointsConfigAttributes.create_stop), true),
        touch_radius = getDefault_number(realConfig:GetAttribute(Constants.waypointsConfigAttributes.touch_radius), 1),
    } :: WaypointsConfig
    return result
end

getFXInfo = function(configFolder: Folder?)
    local realConfig = configFolder or Instance.new("Folder")
    local soundsFolder = realConfig:FindFirstChild("Sounds") or Instance.new("Folder")

    local result = {
        guideParticles = getDefault_childInstance(realConfig, Constants.fxInfoNames.guideParticles, Constants.defaultFXInfo.guideParticles, "Folder") :: Folder,
        guideTemplate = getDefault_childInstance(realConfig, Constants.fxInfoNames.guideTemplate, Constants.defaultFXInfo.guideTemplate, "Folder") :: Folder,
        sounds = {
            grab = getDefault_childInstance(soundsFolder, Constants.fxSoundsNames.grab, Constants.defaultFXInfo.sounds.grab, "Sound") :: Sound,
            move = getDefault_childInstance(soundsFolder, Constants.fxSoundsNames.move, Constants.defaultFXInfo.sounds.move, "Sound") :: Sound,
        },
        segmentPart = getDefault_childInstance(realConfig, Constants.fxInfoNames.segmentPart, Constants.defaultFXInfo.segmentPart, "BasePart") :: BasePart,
        waypointPart = getDefault_childInstance(realConfig, Constants.fxInfoNames.waypointPart, Constants.defaultFXInfo.waypointPart, "BasePart") :: BasePart,
        waypointProximityPrompt = getDefault_childInstance(realConfig, Constants.fxInfoNames.waypointProximityPrompt, Constants.defaultFXInfo.waypointProximityPrompt, "ProximityPrompt") :: ProximityPrompt,
    } :: FXInfo
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
