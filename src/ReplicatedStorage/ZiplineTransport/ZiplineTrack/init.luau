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
local _SegmentedRoute = require(Packages._Index["mariochao_segmented-route@0.1.1"]["segmented-route"])


---------- Types ----------

type LinkedRoute = _SegmentedRoute.LinkedRoute

type ZiplineGroupInfo = {
    route: LinkedRoute,
    waypointInstances: {BasePart},
    vfxFolder: Folder?,
    extraInstances: {Instance},
    connections: {RBXScriptConnection},
}

type ZiplineConfigs = ZiplineConfigs.ZiplineConfigs

type VFXInfo = {
    VFXPart: Part,
    WaypointPart: Part,
}


---------- Constants ----------

local Constants = {}

Constants.controlPointsFolderName = "ControlPoints"
Constants.controlPointAttachmentName = "ControlPointAttachment"

Constants.ziplineConfigsName = "ZiplineConfigs"

Constants.VFXInfoFolderName = "VFXInfo"
Constants._DefaultVFXPart = script.DefaultVFXPart
Constants._DefaultWaypointPart = script.DefaultWaypointPart
Constants.defaultVFXInfo = {
    VFXPart = Constants._DefaultVFXPart,
    WaypointPart = Constants._DefaultWaypointPart,
} :: VFXInfo
Constants.waypointTouchThrottle = 0.5

Constants.storedTransparencyAttributeName = "StoredTransparency"

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
local createZiplineRouteWaypointsVFX

local canMovePart
local isWaypointTouchThrottled
local setWaypointTouchThrottle

local checkZiplineTouchedLoop
local onTouchedZipline
local traverseAlongZipline
local traverseAlongZiplineStartingDelay
local getTraverseWaypointOrder
local traverseAlongZiplineWithDirection

local getOrCreateZiplineConfigs

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
        0, 0.05
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

createZiplineRouteWaypointsVFX = function(container: Instance, ziplineRoute: LinkedRoute)
    local vfxInfo = getVFXInfo(container)
    local templatePart = vfxInfo.WaypointPart
    local partsFolder
    local vfxInstances

    partsFolder, vfxInstances = SegmentedRoute.RouteUtil.Visualizer.createParts_equalSteps(
        ziplineRoute, {templatePart = templatePart :: BasePart, colorRange = {templatePart.Color}},
        nil, 0, 1
    )

    -- Remove last (duplicated) waypoint
    vfxInstances[#vfxInstances]:Destroy()
    table.remove(vfxInstances)

    -- Ensure waypoint part properties
    for _, part in vfxInstances do
        part.CanCollide = false
        part.CanTouch = templatePart.CanTouch
        part.Transparency = tonumber(templatePart:GetAttribute(Constants.storedTransparencyAttributeName)) or 1
    end

    -- Hide template part
    templatePart.Transparency = 1

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

checkZiplineTouchedLoop = function(container: Instance, ziplineConfigs: ZiplineConfigs, ziplineGroup: ZiplineGroupInfo, isValidPart_function: (BasePart) -> boolean)
    local waypointTouchRadius = ziplineConfigs.waypointTouchRadius
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
            isValidPart = isValidPart and (ziplineConfigs.support_objects or isPlayer)
            isValidPart = isValidPart and (ziplineConfigs.support_players or not isPlayer)
            if isValidPart and (part.Parent and part.Parent.Parent) ~= container then
                onTouchedZipline(part, waypointId, ziplineConfigs, ziplineGroup)
            end
        end
    end
    waypointQueryPart:Destroy()
end

onTouchedZipline = function(part: BasePart, startWaypointId: number, ziplineConfigs: ZiplineConfigs, ziplineGroup: ZiplineGroupInfo)
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
            traverseAlongZipline(assemblyRootPart, startWaypointId, ziplineConfigs, ziplineGroup)
            task.wait(0.1)
            Globals.assemblyRootPart_inZipline[assemblyRootPart] = nil
        end)
    end
end

traverseAlongZipline = function(rootPart: BasePart, startWaypointId: number, ziplineConfigs: ZiplineConfigs, ziplineGroup: ZiplineGroupInfo)
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
        local routeAlpha = startWaypointId - 1
        waypointPositiveDirection = ziplineGroup.route:getPositiveDirectionAtAlpha(routeAlpha + 0.001)
        waypointNegativeDirection = -ziplineGroup.route:getPositiveDirectionAtAlpha(routeAlpha - 0.001)
        rootPartVelocityDirection = rootPart.AssemblyLinearVelocity.Unit
        if rootPartVelocityDirection ~= rootPartVelocityDirection then
            rootPartVelocityDirection = Vector3.new(0, -1, 0)
        end
        isPositiveDirection = waypointPositiveDirection:Dot(rootPartVelocityDirection) >= waypointNegativeDirection:Dot(rootPartVelocityDirection)
    end
    traverseAlongZiplineStartingDelay(rootPart, startWaypointId, ziplineConfigs, ziplineGroup)
    traverseAlongZiplineWithDirection(rootPart, startWaypointId, ziplineConfigs, ziplineGroup, isPositiveDirection)
end

traverseAlongZiplineStartingDelay = function(rootPart: BasePart, startWaypointId: number, ziplineConfigs: ZiplineConfigs, ziplineGroup: ZiplineGroupInfo)
    local assemblyRootPart = rootPart.AssemblyRootPart
    local isPlayer
    local startDelay
    local startPosition
    local delayStartTime
    local delayStopTime

    -- Get start delay
    isPlayer = Players:GetPlayerFromCharacter(assemblyRootPart and assemblyRootPart.Parent)
    if isPlayer then
        startDelay = ziplineConfigs.startDelay_players
    else
        startDelay = ziplineConfigs.startDelay_objects
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

traverseAlongZiplineWithDirection = function(rootPart: BasePart, startWaypointId: number, ziplineConfigs: ZiplineConfigs, ziplineGroup: ZiplineGroupInfo, isPositiveDirection: boolean)
    local traverseSpeed = ziplineConfigs.traverseSpeed
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
        routeAlpha = waypointId - 1
        segmentStartDistance = reparameterization_function(routeAlpha, false)
        segmentStopDistance = reparameterization_function(nextWaypointId - 1, false)
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


----- Zipline config functions -----

getOrCreateZiplineConfigs = function(container: Instance)
    local ziplineConfigs
    local containerChildConfigs = container:FindFirstChild(Constants.ziplineConfigsName)
    if containerChildConfigs and containerChildConfigs:IsA("Configuration") then
        ziplineConfigs = containerChildConfigs
    else
        ziplineConfigs = Instance.new("Configuration")
        table.insert(Globals.activeZiplineGroup[container].extraInstances, ziplineConfigs)
        ziplineConfigs.Name = Constants.ziplineConfigsName
        ziplineConfigs.Parent = container
    end
    return ziplineConfigs
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
    local ziplineConfigsInstance
    local ziplineConfigs
    local _: any

    -- Clean up & initialize
    cleanUpZiplineGroup(container)
    ziplineGroupInfo = {} :: ZiplineGroupInfo
    ziplineGroupInfo.vfxFolder = nil
    ziplineGroupInfo.extraInstances = {}
    ziplineGroupInfo.connections = {}
    Globals.activeZiplineGroup[container] = ziplineGroupInfo

    -- Get zipline configs
    ziplineConfigsInstance = getOrCreateZiplineConfigs(container)
    ziplineConfigs = ZiplineConfigs.getConfigs(ziplineConfigsInstance)

    -- Create zipline route
    orderedControlPoints = getOrderedControlPoints(container)
    orderedSegments = getOrderedSegments(orderedControlPoints)
    ziplineRoute = LinkedRoute.new()
    ziplineGroupInfo.route = ziplineRoute
    for _, segment in orderedSegments do
        ziplineRoute:addSegment(segment)
    end

    -- Create zipline waypoints
    _, ziplineGroupInfo.waypointInstances = createZiplineRouteWaypointsVFX(container, ziplineRoute)

    -- Create zipline VFX
    if willCreateVFX then
        ziplineGroupInfo.vfxFolder, _ = createZiplineRouteVisualizerVFX(container, ziplineRoute)
    end

    -- Hide control points
    if ziplineConfigs.hide_controlPoints then
        for _, point in orderedControlPoints do
            point.Transparency = 1
        end
    end

    -- Set up zipline connection
    table.insert(ziplineGroupInfo.connections, RunService.Heartbeat:Connect(function()
        checkZiplineTouchedLoop(container, ziplineConfigs, ziplineGroupInfo, isValidPart_function)
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
