--!strict

-- Zipline Track


---------- Services ----------

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")


---------- Imports ----------

local ZiplineConfigs = require(script.ZiplineConfigs)

local Packages = script.Parent.Parent
local SpatialQuery = require(Packages:WaitForChild("SpatialQuery"))
local SegmentedRoute = require(Packages:WaitForChild("SegmentedRoute"))
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
Constants.routeAlphaAttributeName = "RouteAlpha"

table.freeze(Constants.defaultVFXInfo)
table.freeze(Constants)


---------- Global variables ----------

local Globals = {}
Globals.activeZiplineGroup = {} :: {[Instance]: ZiplineGroupInfo}
Globals.assemblyRootPart_inZipline = {} :: {[BasePart]: boolean}
Globals.waypointInstance_assemblyRootPart_throttle = {} :: {[Instance]: {[BasePart]: true?}}
Globals.waypointInstance_assemblyRootPart_throttleThread = {} :: {[Instance]: {[BasePart]: thread?}}


---------- Local functions ----------

local getPieModel
local isPieAClientPie

local getVFXInfo
local createZiplineRouteVisualizerVFX

local isValidWaypoint
local isLoopedStartWaypoint
local getWaypointAlpha
local createZiplineRouteWaypointsVFX
local setUpZiplineRouteWaypoints

local canMovePart
local isWaypointTouchThrottled
local setWaypointTouchThrottle

local checkZiplineTouchedLoop
local onTouchedZipline
local traverseAlongZipline
local runTraverseZiplineStartDelay

local traverseAlongZiplineWithDirection

local getControlPointConfig
local getOrderedControlPoints
local getOrderedSegments


----- Pie hiking tool -----

getPieModel = function(instance: Instance?): Model?
	-- Find a pie model by looking through the parent instances
	local loopCount = 0
	while instance and loopCount < 20 do
		-- Check if instance is a pie model
		if instance:IsA("Model") and instance.Name == "PieModel" and instance:FindFirstChild("MainPart") then
			return instance
		end

		-- Update variables
		local parent: Instance? = instance:FindFirstAncestorWhichIsA("Model")
		instance = parent
		loopCount += 1
	end
	return nil
end

isPieAClientPie = function(pieModel: Model?): boolean
	local pieMainPart = pieModel and pieModel:FindFirstChild("MainPart") :: Part
	local pieUniqueId = pieModel and pieModel:FindFirstChild("UniquePieId") :: StringValue
	local pieTag = pieUniqueId and pieUniqueId.Value
	local _isClientPie = pieMainPart and pieMainPart:IsA("Part") and pieTag and typeof(pieTag) == "string"
	return _isClientPie == true
end


----- Zipline effect functions -----

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
    templatePart.CanCollide = false
    templatePart.CanQuery = false
    templatePart.CanTouch = false
    templatePart.AudioCanCollide = false

    return partsFolder, vfxInstances
end


----- Waypoint funtions -----

isValidWaypoint = function(waypointId: number, ziplineConfig: ZiplineConfig, numberOfWaypoints: number)
    local isValid = true
    if waypointId == 1 or waypointId == numberOfWaypoints then
        if ziplineConfig.isLooped then
            isValid = isValid and (ziplineConfig.waypointConfig.create_start or ziplineConfig.waypointConfig.create_stop)
            isValid = isValid and waypointId == 1
        elseif waypointId == 1 then
            isValid = isValid and ziplineConfig.waypointConfig.create_start
        elseif waypointId == numberOfWaypoints then
            isValid = isValid and ziplineConfig.waypointConfig.create_stop
        end
    else
        isValid = isValid and ziplineConfig.waypointConfig.create_middle
    end
    return isValid
end

isLoopedStartWaypoint = function(waypointId: number, ziplineConfig: ZiplineConfig)
    return waypointId == 1 and ziplineConfig.isLooped
end

getWaypointAlpha = function(waypoint: BasePart)
    return tonumber(waypoint:GetAttribute(Constants.routeAlphaAttributeName)) or 0
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
    --  We don't remove them because they are still used for traversal
    local keepStart = waypointConfig.create_start
    keepStart = keepStart or (ziplineConfig.isLooped and (waypointConfig.create_start or waypointConfig.create_stop))
    local keepStop = waypointConfig.create_stop
    keepStop = keepStop and not ziplineConfig.isLooped
    if not keepStart then
        local part = vfxInstances[1]
        part.Transparency = 1
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.AudioCanCollide = false
    end
    if not keepStop then
        local part = vfxInstances[#vfxInstances]
        part.Transparency = 1
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.AudioCanCollide = false
    end

    -- Hide template part
    templatePart.Transparency = 1
    templatePart.CanCollide = false
    templatePart.CanQuery = false
    templatePart.CanTouch = false
    templatePart.AudioCanCollide = false

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
    if waypointInstance and assemblyRootPart then
        -- Create default table
        if not Globals.waypointInstance_assemblyRootPart_throttle[waypointInstance] then
            Globals.waypointInstance_assemblyRootPart_throttle[waypointInstance] = {}
        end
        if not Globals.waypointInstance_assemblyRootPart_throttleThread[waypointInstance] then
            Globals.waypointInstance_assemblyRootPart_throttleThread[waypointInstance] = {}
        end

        -- Throttle
        local existingThread = Globals.waypointInstance_assemblyRootPart_throttleThread[waypointInstance][assemblyRootPart]
        if existingThread then
            task.cancel(existingThread)
        end
        Globals.waypointInstance_assemblyRootPart_throttle[waypointInstance][assemblyRootPart] = true
        Globals.waypointInstance_assemblyRootPart_throttleThread[waypointInstance][assemblyRootPart] = task.delay(Constants.waypointTouchThrottle, function()
            Globals.waypointInstance_assemblyRootPart_throttle[waypointInstance][assemblyRootPart] = nil
            Globals.waypointInstance_assemblyRootPart_throttleThread[waypointInstance][assemblyRootPart] = nil
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
            local isClientPie = isPieAClientPie(getPieModel(rootPart))
            local isValidPart = true
            isValidPart = isValidPart and isValidPart_function(part)
            if isPlayer then
                isValidPart = isValidPart and ziplineConfig.support_players and ziplineConfig.waypointConfig.activate_playerTouch
            elseif isClientPie then
                isValidPart = isValidPart and ziplineConfig.support_clientPies
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
            task.wait()
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

    -- Check looped endpoint
    if isLoopedStartWaypoint(startWaypointId, ziplineConfig) then
        local routeAlphaRange = ziplineGroup.route:getAlphaRange()
        waypointPositiveDirection = ziplineGroup.route:getPositiveDirectionAtAlpha(routeAlphaRange.Min)
        waypointNegativeDirection = -ziplineGroup.route:getPositiveDirectionAtAlpha(routeAlphaRange.Max)
        rootPartVelocityDirection = rootPart.AssemblyLinearVelocity.Unit

        -- Check zero (unit of zero velocity is (nan, nan, nan))
        if rootPartVelocityDirection ~= rootPartVelocityDirection then
            rootPartVelocityDirection = Vector3.new(0, -1, 0)
        end

        -- Reassign start waypoint
        isPositiveDirection = waypointPositiveDirection:Dot(rootPartVelocityDirection) >= waypointNegativeDirection:Dot(rootPartVelocityDirection)
        if not isPositiveDirection then
            startWaypointId = waypointCount
        end
    end

    -- Get direction
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

    -- Traverse
    local startAlpha = getWaypointAlpha(ziplineGroup.waypointInstances[startWaypointId])
    runTraverseZiplineStartDelay(rootPart, startAlpha, ziplineConfig, ziplineGroup)
    traverseAlongZiplineWithDirection(rootPart, startAlpha, ziplineConfig, ziplineGroup, isPositiveDirection)
end

runTraverseZiplineStartDelay = function(rootPart: BasePart, startAlpha: number, ziplineConfig: ZiplineConfig, ziplineGroup: ZiplineGroupInfo)
    local assemblyRootPart = rootPart.AssemblyRootPart
    local isPlayer
    local isClientPie
    local startDelay
    local startPosition
    local delayStartTime
    local delayStopTime

    -- Get start delay
    isPlayer = Players:GetPlayerFromCharacter(assemblyRootPart and assemblyRootPart.Parent)
    isClientPie = isPieAClientPie(getPieModel(assemblyRootPart))
    if isPlayer then
        startDelay = ziplineConfig.startDelay_players
    elseif isClientPie then
        startDelay = ziplineConfig.startDelay_clientPies
    else
        startDelay = ziplineConfig.startDelay_objects
    end

    -- Idle at start position
    startPosition = ziplineGroup.route:getPositionAtAlpha(startAlpha)
    delayStartTime = time()
    delayStopTime = delayStartTime + startDelay
    while time() < delayStopTime and canMovePart(rootPart) and rootPart == rootPart.AssemblyRootPart do
        rootPart:PivotTo(CFrame.new(startPosition) * rootPart.CFrame.Rotation)
        rootPart.AssemblyLinearVelocity = Vector3.zero
        RunService.Heartbeat:Wait()
    end
end


----- Zipline traversal -----

traverseAlongZiplineWithDirection = function(rootPart: BasePart, startAlpha: number, ziplineConfig: ZiplineConfig, ziplineGroup: ZiplineGroupInfo, isPositiveDirection: boolean)
    -- Get traverse info
    local routeAlphaRange = ziplineGroup.route:getAlphaRange()
    local traverseSpeed = ziplineConfig.traverseSpeed
    local velocitySign = if isPositiveDirection then 1 else -1

    -- Get reparameterized route (assume static route)
    local reparameterization_function = SegmentedRoute.RouteUtil.Reparam.getRoute_reparameterization_function(ziplineGroup.route)

    -- Traverse
    local routeAlpha = startAlpha
    local previousTime
    local previousTraversePosition
    while true do
        -- Validate can move
        if not (canMovePart(rootPart) and rootPart == rootPart.AssemblyRootPart) then
            break
        end

        -- Throttle / debounce for nearby waypoint
        local nearbyWaypointId = nil
        for waypointId, waypoint in ziplineGroup.waypointInstances do
            if math.abs(getWaypointAlpha(waypoint) - routeAlpha) < 0.1 then
                nearbyWaypointId = waypointId
            end
        end
        if nearbyWaypointId then
            setWaypointTouchThrottle(ziplineGroup, nearbyWaypointId, rootPart)
        end

        -- Update route alpha
        local currentTime = time()
        if velocitySign ~= 0 then
            local routeDistance = reparameterization_function(routeAlpha, false)
            local deltaDistance = 0
            if previousTime then
                deltaDistance = (currentTime - previousTime) * traverseSpeed
                deltaDistance *= velocitySign
            end
            routeDistance += deltaDistance
            routeAlpha = reparameterization_function(routeDistance, true)
        end

        -- Resolve route alpha
        if routeAlpha < routeAlphaRange.Min or routeAlpha > routeAlphaRange.Max then
            if ziplineConfig.isLooped then
                local rangeScalar = routeAlphaRange.Max - routeAlphaRange.Min
                routeAlpha = (routeAlpha - routeAlphaRange.Min) % rangeScalar + routeAlphaRange.Min
            else
                break
            end
        end

        -- Calculate traverse position
        local traversePosition = ziplineGroup.route:getPositionAtAlpha(routeAlpha, true)

        -- Calculate traverse velocity vector
        local traverseVelocity = Vector3.zero
        if previousTime and previousTraversePosition then
            local positionChange = traversePosition - previousTraversePosition
            local timeChange = currentTime - previousTime
            traverseVelocity = positionChange / timeChange
        end

        -- Set traverse kinematics
        rootPart:PivotTo(CFrame.new(traversePosition) * rootPart.CFrame.Rotation)
        rootPart.Anchored = true
        rootPart.AssemblyLinearVelocity = traverseVelocity

        -- Delay
        task.wait()
        rootPart.Anchored = false

        -- Update state
        previousTime = currentTime
        previousTraversePosition = traversePosition
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

    -- Create zipline loop
    if ziplineConfig.isLooped then
        ziplineRoute:connectLoop(1)
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
            point.CanCollide = false
            point.CanQuery = false
            point.CanTouch = false
            point.AudioCanCollide = false
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
