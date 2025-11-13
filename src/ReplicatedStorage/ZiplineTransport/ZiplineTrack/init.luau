--!strict

-- Zipline Track


---------- Services ----------

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")


---------- Imports ----------

local ZiplineConfigs = require(script.ZiplineConfigs)

local Packages = script.Parent.Parent
local SpatialQuery = require(Packages.SpatialQuery)
local SegmentedRoute = require(Packages.SegmentedRoute)
local LinkedRoute = SegmentedRoute.LinkedRoute
local _SegmentedRoute = require(Packages._Index["mariochao_segmented-route@0.1.2"]["segmented-route"])


---------- Types ----------

type LinkedRoute = _SegmentedRoute.LinkedRoute

type ZiplineGroupInfo = {
    route: LinkedRoute,
    waypointInstances: {BasePart},
    vfxFolder: Folder?,
    extraInstances: {Instance},
    connections: {RBXScriptConnection},
}

type ZiplineConfig = ZiplineConfigs.ZiplineConfig

type VFXInfo = {
    VFXPart: Part,
    WaypointPart: Part,
}


---------- Constants ----------

local Constants = {}

Constants.controlPointsFolderName = "ControlPoints"
Constants.controlPointAttachmentName = "ControlPointAttachment"

Constants.ziplineConfigName = "ZiplineConfig"

Constants.VFXInfoFolderName = "VFXInfo"
Constants._DefaultVFXPart = script.DefaultVFXPart
Constants._DefaultWaypointPart = script.DefaultWaypointPart
Constants.defaultVFXInfo = {
    VFXPart = Constants._DefaultVFXPart,
    WaypointPart = Constants._DefaultWaypointPart,
} :: VFXInfo
Constants.waypointTouchThrottle = 0.5

Constants.storedTransparencyAttributeName = "StoredTransparency"
Constants.routeAlphAttributeName = "RouteAlpha"

table.freeze(Constants.defaultVFXInfo)
table.freeze(Constants)


---------- Global variables ----------

local Globals = {}
Globals.activeZiplineGroup = {} :: {[Instance]: ZiplineGroupInfo}
Globals.assemblyRootPart_inZipline = {} :: {[BasePart]: boolean}
Globals.waypointInstance_assemblyRootPart_throttle = {} :: {[Instance]: {[BasePart]: boolean}}


---------- Local functions ----------

local getVFXInfo
local createZiplineRouteVisualizerVFX

local isValidWaypoint
local getWaypointAlpha
local createZiplineRouteWaypointsVFX
local setUpZiplineRouteWaypoints

local canMovePart
local isWaypointTouchThrottled
local setWaypointTouchThrottle

local checkZiplineTouchedLoop
local onTouchedZipline
local traverseAlongZipline
local traverseAlongZiplineStartingDelay
local getTraverseWaypointOrder
local traverseAlongZiplineWithDirection

local getControlPointConfig
local getOrderedControlPoints
local getOrderedSegments


----- Ziplin effect functions -----

getVFXInfo = function(container: Instance): VFXInfo
    local VFXInfoFolder
    local result = table.clone(Constants.defaultVFXInfo)
    local VFXPart
    local WaypointPart

    -- Get template parts
    VFXInfoFolder = container:FindFirstChild(Constants.VFXInfoFolderName)
    if VFXInfoFolder then
        VFXPart = VFXInfoFolder:FindFirstChild("VFXPart")
        WaypointPart = VFXInfoFolder:FindFirstChild("WaypointPart") :: Part
        if VFXPart and VFXPart:IsA("Part") then
            result.VFXPart = VFXPart
            VFXPart.CanCollide = false
            VFXPart.Anchored = true
        end
        if WaypointPart and WaypointPart:IsA("Part") then
            result.WaypointPart = WaypointPart
            WaypointPart.CanCollide = false
            WaypointPart.Anchored = true
        end
    end

    -- Store template part transparency
    if not result.VFXPart:GetAttribute(Constants.storedTransparencyAttributeName) then
        result.VFXPart:SetAttribute(Constants.storedTransparencyAttributeName, result.VFXPart.Transparency)
    end
    if not result.WaypointPart:GetAttribute(Constants.storedTransparencyAttributeName) then
        result.WaypointPart:SetAttribute(Constants.storedTransparencyAttributeName, result.WaypointPart.Transparency)
    end

    return result
end

createZiplineRouteVisualizerVFX = function(container: Instance, ziplineRoute: LinkedRoute)
    local vfxInfo = getVFXInfo(container)
    local templatePart = vfxInfo.VFXPart
    local partsFolder
    local vfxInstances

    partsFolder, vfxInstances = SegmentedRoute.RouteUtil.Visualizer.createParts_connected_equalSteps(
        ziplineRoute, {templatePart = templatePart :: BasePart, colorRange = {templatePart.Color}},
        0, 0.01
    )

    -- Make sure visualized parts are not collidable
    for _, part in vfxInstances do
        part.CanCollide = false
        part.CanTouch = templatePart.CanTouch
        part.Transparency = tonumber(templatePart:GetAttribute(Constants.storedTransparencyAttributeName)) or 1
    end

    -- Hide template part
    templatePart.Transparency = 1

    return partsFolder, vfxInstances
end


----- Waypoint funtions -----

isValidWaypoint = function(waypointId: number, ziplineConfig: ZiplineConfig, numberOfWaypoints: number)
    local isValid = true
    if waypointId == 1 then
        isValid = isValid and ziplineConfig.waypointConfig.create_start
    elseif waypointId == numberOfWaypoints then
        isValid = isValid and ziplineConfig.waypointConfig.create_stop
    else
        isValid = isValid and ziplineConfig.waypointConfig.create_middle
    end
    return isValid
end

getWaypointAlpha = function(waypoint: BasePart)
    return tonumber(waypoint:GetAttribute(Constants.routeAlphAttributeName)) or 0
end

createZiplineRouteWaypointsVFX = function(container: Instance, ziplineConfig: ZiplineConfig, ziplineRoute: LinkedRoute)
    local vfxInfo = getVFXInfo(container)
    local templatePart = vfxInfo.WaypointPart
    local partsFolder
    local vfxInstances
    local alphaRange_scalar = ziplineRoute:getAlphaRange_scalar()
    local waypointConfig = ziplineConfig.waypointConfig
    local startAlpha = 0
    local deltaAlpha = if waypointConfig.create_middle then 1 else alphaRange_scalar

    partsFolder, vfxInstances = SegmentedRoute.RouteUtil.Visualizer.createParts_equalSteps(
        ziplineRoute, {templatePart = templatePart :: BasePart, colorRange = {templatePart.Color}},
        nil, startAlpha, deltaAlpha
    )

    -- Remove last (duplicated) waypoint
    if #vfxInstances >= 2 and vfxInstances[#vfxInstances - 1].Position:FuzzyEq(vfxInstances[#vfxInstances].Position) then
        vfxInstances[#vfxInstances]:Destroy()
        table.remove(vfxInstances)
    end

    -- Ensure waypoint part properties
    for _, part in vfxInstances do
        part.CanCollide = false
        part.CanTouch = templatePart.CanTouch
        part.Transparency = tonumber(templatePart:GetAttribute(Constants.storedTransparencyAttributeName)) or 1
    end

    -- Hide start & stop waypoints
    if not waypointConfig.create_start then
        vfxInstances[1].Transparency = 1
    end
    if not waypointConfig.create_stop then
        vfxInstances[#vfxInstances].Transparency = 1
    end

    -- Hide template part
    templatePart.Transparency = 1

    return partsFolder, vfxInstances
end

setUpZiplineRouteWaypoints = function(container: Instance, ziplineConfig: ZiplineConfig, ziplineRoute: LinkedRoute)
    local partsFolder
    local vfxInstances
    local proximityPrompt

    -- Create waypoints
    partsFolder, vfxInstances = createZiplineRouteWaypointsVFX(container, ziplineConfig, ziplineRoute)

    -- Set up proximity prompts
    if ziplineConfig.waypointConfig.activate_proximityPrompt and RunService:IsClient() then
        for i = 1, #vfxInstances do
            if isValidWaypoint(i, ziplineConfig, #vfxInstances) then
                proximityPrompt = ziplineConfig.waypointProximityPrompt:Clone()
                proximityPrompt.Parent = vfxInstances[i]
                proximityPrompt.Triggered:Connect(function(player: Player)
                    -- Check valid
                    local character = player.Character
                    local part = character and character:FindFirstChild("HumanoidRootPart")
                    if part and part:IsA("BasePart") then
                        local rootPart = part.AssemblyRootPart
                        local isPlayer = Players:GetPlayerFromCharacter(rootPart and rootPart.Parent)
                        local isValidPart = ziplineConfig.support_players and isPlayer
                        if isValidPart and (part.Parent and part.Parent.Parent) ~= container then
                            onTouchedZipline(part, i, ziplineConfig, Globals.activeZiplineGroup[container])
                        end
                    end
                end)
            end
        end
    end

    return partsFolder, vfxInstances
end


----- Zipline touched helper functions -----

canMovePart = function(part: BasePart)
    local assemblyRootPart = part.AssemblyRootPart
    local result
    result = assemblyRootPart and not assemblyRootPart.Anchored
    return result == true
end

isWaypointTouchThrottled = function(ziplineGroup: ZiplineGroupInfo, waypointId: number, part: BasePart)
    local touchedWaypointInstance = ziplineGroup.waypointInstances[waypointId]
    local assemblyRootPart_throttle = Globals.waypointInstance_assemblyRootPart_throttle[touchedWaypointInstance]
    local assemblyRootPart = part.AssemblyRootPart
   return assemblyRootPart_throttle and assemblyRootPart and assemblyRootPart_throttle[assemblyRootPart]
end

setWaypointTouchThrottle = function(ziplineGroup: ZiplineGroupInfo, waypointId: number, part: BasePart)
    local waypointInstance = ziplineGroup.waypointInstances[waypointId]
    local assemblyRootPart = part.AssemblyRootPart
    if assemblyRootPart then
        if not Globals.waypointInstance_assemblyRootPart_throttle[waypointInstance] then
            Globals.waypointInstance_assemblyRootPart_throttle[waypointInstance] = {}
        end
        Globals.waypointInstance_assemblyRootPart_throttle[waypointInstance][assemblyRootPart] = true
        task.delay(Constants.waypointTouchThrottle, function()
            Globals.waypointInstance_assemblyRootPart_throttle[waypointInstance][assemblyRootPart] = nil
        end)
    end
end


----- Zipline touched functions -----

checkZiplineTouchedLoop = function(container: Instance, ziplineConfig: ZiplineConfig, ziplineGroup: ZiplineGroupInfo, isValidPart_function: (BasePart) -> boolean)
    local waypointTouchRadius = ziplineConfig.waypointConfig.touch_radius
    local waypointQueryPart
    local waypointPosition
    local queriedParts

    waypointQueryPart = Instance.new("Part")
    waypointQueryPart.Shape = Enum.PartType.Ball
    waypointQueryPart.Size = Vector3.one * waypointTouchRadius * 2
    waypointQueryPart.CanCollide = false
    waypointQueryPart.Anchored = true
    for waypointId = 1, #ziplineGroup.waypointInstances do
        waypointPosition = ziplineGroup.waypointInstances[waypointId].Position
        waypointQueryPart.Position = waypointPosition
        queriedParts = SpatialQuery.getWhitelistedInParts({waypointQueryPart}, {workspace})
        for _, part in queriedParts do
            -- Check valid
            local rootPart = part.AssemblyRootPart
            local isPlayer = Players:GetPlayerFromCharacter(rootPart and rootPart.Parent)
            local isValidPart = true
            isValidPart = isValidPart and isValidPart_function(part)
            if isPlayer then
                isValidPart = isValidPart and ziplineConfig.support_players and ziplineConfig.waypointConfig.activate_playerTouch
            else
                isValidPart = isValidPart and ziplineConfig.support_objects
            end
            isValidPart = isValidPart and isValidWaypoint(waypointId, ziplineConfig, #ziplineGroup.waypointInstances)
            if isValidPart and (part.Parent and part.Parent.Parent) ~= container then
                onTouchedZipline(part, waypointId, ziplineConfig, ziplineGroup)
            end
        end
    end
    waypointQueryPart:Destroy()
end

onTouchedZipline = function(part: BasePart, startWaypointId: number, ziplineConfig: ZiplineConfig, ziplineGroup: ZiplineGroupInfo)
    local assemblyRootPart = part.AssemblyRootPart
    local isValid

    -- Validate touched part
    isValid = canMovePart(assemblyRootPart)
    isValid = isValid and not Globals.assemblyRootPart_inZipline[assemblyRootPart]
    isValid = isValid and not isWaypointTouchThrottled(ziplineGroup, startWaypointId, assemblyRootPart)

    -- Traverse
    if isValid then
        Globals.assemblyRootPart_inZipline[assemblyRootPart] = true
        task.defer(function()
            traverseAlongZipline(assemblyRootPart, startWaypointId, ziplineConfig, ziplineGroup)
            task.wait(0.1)
            Globals.assemblyRootPart_inZipline[assemblyRootPart] = nil
        end)
    end
end

traverseAlongZipline = function(rootPart: BasePart, startWaypointId: number, ziplineConfig: ZiplineConfig, ziplineGroup: ZiplineGroupInfo)
    local waypointCount = #ziplineGroup.waypointInstances
    local isPositiveDirection
    local waypointPositiveDirection
    local waypointNegativeDirection
    local rootPartVelocityDirection
    if startWaypointId == 1 then
        isPositiveDirection = true
    elseif startWaypointId == waypointCount then
        isPositiveDirection = false
    else
        local routeAlpha = getWaypointAlpha(ziplineGroup.waypointInstances[startWaypointId])
        waypointPositiveDirection = ziplineGroup.route:getPositiveDirectionAtAlpha(routeAlpha + 0.001)
        waypointNegativeDirection = -ziplineGroup.route:getPositiveDirectionAtAlpha(routeAlpha - 0.001)
        rootPartVelocityDirection = rootPart.AssemblyLinearVelocity.Unit
        if rootPartVelocityDirection ~= rootPartVelocityDirection then
            rootPartVelocityDirection = Vector3.new(0, -1, 0)
        end
        isPositiveDirection = waypointPositiveDirection:Dot(rootPartVelocityDirection) >= waypointNegativeDirection:Dot(rootPartVelocityDirection)
    end
    traverseAlongZiplineStartingDelay(rootPart, startWaypointId, ziplineConfig, ziplineGroup)
    traverseAlongZiplineWithDirection(rootPart, startWaypointId, ziplineConfig, ziplineGroup, isPositiveDirection)
end

traverseAlongZiplineStartingDelay = function(rootPart: BasePart, startWaypointId: number, ziplineConfig: ZiplineConfig, ziplineGroup: ZiplineGroupInfo)
    local assemblyRootPart = rootPart.AssemblyRootPart
    local isPlayer
    local startDelay
    local startPosition
    local delayStartTime
    local delayStopTime

    -- Get start delay
    isPlayer = Players:GetPlayerFromCharacter(assemblyRootPart and assemblyRootPart.Parent)
    if isPlayer then
        startDelay = ziplineConfig.startDelay_players
    else
        startDelay = ziplineConfig.startDelay_objects
    end

    -- Idle at start position
    startPosition = ziplineGroup.waypointInstances[startWaypointId].Position
    delayStartTime = time()
    delayStopTime = delayStartTime + startDelay
    while time() < delayStopTime and canMovePart(rootPart) and rootPart == rootPart.AssemblyRootPart do
        rootPart:PivotTo(CFrame.new(startPosition) * rootPart.CFrame.Rotation)
        rootPart.AssemblyLinearVelocity = Vector3.zero
        RunService.Heartbeat:Wait()
    end
end

getTraverseWaypointOrder = function(ziplineGroup: ZiplineGroupInfo, startWaypointId: number, isPositiveDirection: boolean)
    local result = {}
    if isPositiveDirection then
        for id = startWaypointId, #ziplineGroup.waypointInstances do
            table.insert(result, id)
        end
    else
        for id = startWaypointId, 1, -1 do
            table.insert(result, id)
        end
    end
    return result
end

traverseAlongZiplineWithDirection = function(rootPart: BasePart, startWaypointId: number, ziplineConfig: ZiplineConfig, ziplineGroup: ZiplineGroupInfo, isPositiveDirection: boolean)
    local traverseSpeed = ziplineConfig.traverseSpeed
    local reparameterization_function
    local traverseWaypointOrder
    local waypointId
    local nextWaypointId
    local routeAlpha
    local routeDistance
    local segmentStartDistance
    local segmentStopDistance
    local segmentLength
    local traverseSegmentStartTime
    local traverseSegmentStopTime
    local velocitySign
    local waypointTraverseVelocity
    local traversePosition

    -- Get reparameterized route (assume static route)
    reparameterization_function = SegmentedRoute.RouteUtil.Reparam.getRoute_reparameterization_function(ziplineGroup.route)

    -- Traverse
    velocitySign = if isPositiveDirection then 1 else -1
    traverseWaypointOrder = getTraverseWaypointOrder(ziplineGroup, startWaypointId, isPositiveDirection)
    for traverseId = 1, #traverseWaypointOrder - 1 do
        waypointId = traverseWaypointOrder[traverseId]
        nextWaypointId = traverseWaypointOrder[traverseId + 1]

        -- Throttle / debounce for waypoint
        setWaypointTouchThrottle(ziplineGroup, waypointId, rootPart)

        -- Calculate segment distances
        routeAlpha = getWaypointAlpha(ziplineGroup.waypointInstances[waypointId])
        segmentStartDistance = reparameterization_function(routeAlpha, false)
        segmentStopDistance = reparameterization_function(getWaypointAlpha(ziplineGroup.waypointInstances[nextWaypointId]), false)
        segmentLength = math.abs(segmentStopDistance - segmentStartDistance)

        -- Calculate traversal time
        traverseSegmentStartTime = time()
        traverseSegmentStopTime = traverseSegmentStartTime + segmentLength / traverseSpeed

        while time() < traverseSegmentStopTime and canMovePart(rootPart) and rootPart == rootPart.AssemblyRootPart do
            routeDistance = math.map(time(), traverseSegmentStartTime, traverseSegmentStopTime, segmentStartDistance, segmentStopDistance)
            routeAlpha = reparameterization_function(routeDistance, true)
            traversePosition = ziplineGroup.route:getPositionAtAlpha(routeAlpha, true)
            rootPart:PivotTo(CFrame.new(traversePosition) * rootPart.CFrame.Rotation)

            -- Calculate traverse velocity vector
            waypointTraverseVelocity = ziplineGroup.route:getPositiveDirectionAtAlpha(routeAlpha) * traverseSpeed
            waypointTraverseVelocity *= velocitySign

            -- Anchor part to create movement platform effect
            rootPart.Anchored = true
            rootPart.AssemblyLinearVelocity = waypointTraverseVelocity
            RunService.Heartbeat:Wait()
            rootPart.Anchored = false
        end

        -- Validate can move
        if not (canMovePart(rootPart) and rootPart == rootPart.AssemblyRootPart) then
            break
        end
    end

    -- Throttle / debounce for last waypoint
    if canMovePart(rootPart) and rootPart == rootPart.AssemblyRootPart then
        setWaypointTouchThrottle(ziplineGroup, nextWaypointId, rootPart)
    end
end


----- Set up helper functions -----

getControlPointConfig = function(controlPoint: BasePart)
    local configInstance
    local configTable

    configInstance = controlPoint:FindFirstChild("ControlPointConfig")
    configTable = {
        IsBezierControlPoint = configInstance and configInstance:GetAttribute("IsBezierControlPoint") == true,
    }
    return configTable
end

getOrderedControlPoints = function(container: Instance)
    local partsFolder = container:FindFirstChild(Constants.controlPointsFolderName)
    local controlPointInstances

    -- Get children control points
    controlPointInstances = {}
    if partsFolder then
        for _, object in partsFolder:GetChildren() do
            if object:IsA("BasePart") then
                table.insert(controlPointInstances, object)
            end
        end
    end

    -- Sort control points by name
    table.sort(controlPointInstances, function(a, b) return a.Name < b.Name end)

    return controlPointInstances
end

getOrderedSegments = function(orderedControlPoints: {BasePart})
    local segments

    -- Get segments
    segments = {}
    local startPointId = 1
    local stopPointId
    while startPointId < #orderedControlPoints do
        -- Get stop point
        stopPointId = startPointId + 1
        while stopPointId < #orderedControlPoints and getControlPointConfig(orderedControlPoints[stopPointId]).IsBezierControlPoint do
            stopPointId += 1
        end

        -- Create segment
        local bezierSegment = SegmentedRoute.RouteSegment.BezierCurve.new()
        for i = startPointId, stopPointId, 1 do
            bezierSegment:addControlPointPart_getOrCreateAttachment(orderedControlPoints[i], Constants.controlPointAttachmentName)
        end
        table.insert(segments, bezierSegment)

        -- Ready next segment
        startPointId = stopPointId
    end

    return segments
end


---------- Set up functions ----------

local setUpZiplineGroup
local cleanUpZiplineGroup

setUpZiplineGroup = function(container: Instance, isValidPart_function: (BasePart) -> boolean, willCreateVFX: boolean)
    local orderedControlPoints
    local orderedSegments
    local ziplineRoute
    local ziplineGroupInfo
    local ziplineConfig
    local _: any

    -- Clean up & initialize
    cleanUpZiplineGroup(container)
    ziplineGroupInfo = {} :: ZiplineGroupInfo
    ziplineGroupInfo.vfxFolder = nil
    ziplineGroupInfo.extraInstances = {}
    ziplineGroupInfo.connections = {}
    Globals.activeZiplineGroup[container] = ziplineGroupInfo

    -- Get zipline config
    ziplineConfig = ZiplineConfigs.getConfig(container:FindFirstChild(Constants.ziplineConfigName) :: Configuration)

    -- Create zipline route
    orderedControlPoints = getOrderedControlPoints(container)
    orderedSegments = getOrderedSegments(orderedControlPoints)
    ziplineRoute = LinkedRoute.new()
    ziplineGroupInfo.route = ziplineRoute
    for _, segment in orderedSegments do
        ziplineRoute:addSegment(segment)
    end

    -- Create zipline visualizer VFX
    if willCreateVFX then
        ziplineGroupInfo.vfxFolder, _ = createZiplineRouteVisualizerVFX(container, ziplineRoute)
    end

    -- Create zipline waypoints
    _, ziplineGroupInfo.waypointInstances = setUpZiplineRouteWaypoints(container, ziplineConfig, ziplineRoute)

    -- Hide control points
    if ziplineConfig.hide_controlPoints then
        for _, point in orderedControlPoints do
            point.Transparency = 1
        end
    end

    -- Set up zipline connection
    table.insert(ziplineGroupInfo.connections, RunService.Heartbeat:Connect(function()
        checkZiplineTouchedLoop(container, ziplineConfig, ziplineGroupInfo, isValidPart_function)
    end))
end

cleanUpZiplineGroup = function(container: Instance)
    local ziplineGroup = Globals.activeZiplineGroup[container]
    if ziplineGroup then
        for _, instance in ziplineGroup.waypointInstances do
            table.clear(Globals.waypointInstance_assemblyRootPart_throttle[instance])
        end
        ziplineGroup.route:cleanUp()
        if ziplineGroup.vfxFolder then ziplineGroup.vfxFolder:Destroy() end
        for _, object in ziplineGroup.extraInstances do object:Destroy() end
        for _, connection in ziplineGroup.connections do connection:Disconnect() end
        table.clear(ziplineGroup[container])
    end
end


---------- Module ----------

local module = {}


----- Module fields -----

module.setUpZiplineGroup = setUpZiplineGroup
module.cleanUpZiplineGroup = cleanUpZiplineGroup


---------- Return module ----------

return module
