--!strict

---------- Serices ----------

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")


---------- Imports ----------

local SpatialQuery = require(script.Parent.Packages.SpatialQuery)
local ZiplineRoute = require(script.Parent.ZiplineRoute)


---------- Types ----------

type ZiplineGroupInfo = {
    route: ZiplineRoute.ClassType,
    vfxInstances: {Instance},
    extraInstances: {Instance},
    connections: {RBXScriptConnection},
}

type VFXInfo = {
    VFXBeam: Beam
}


---------- Constants ----------

local Constants = {}

Constants.waypointsFolderName = "Waypoints"
Constants.ziplineConfigsName = "ZiplineConfigs"

Constants.VFXInstancesFolder = Instance.new("Folder")
Constants.VFXInstancesFolder.Name = "ZiplineVFXInstances"
Constants.VFXInstancesFolder.Parent = workspace

Constants.VFXInfoFolderName = "VFXInfo"
Constants.DefaultVFXBeam = script.DefaultVFXBeam
Constants.defaultVFXInfo = {
    VFXBeam = Constants.DefaultVFXBeam
} :: VFXInfo
Constants.waypointAttachmentName = "WaypointAttachment"
Constants.waypointTouchThrottle = 0.5

local ZiplineConfigAttributeNames = {}
ZiplineConfigAttributeNames.startDelay_objects = "StartDelay_Objects"
ZiplineConfigAttributeNames.startDelay_players = "StartDelay_Players"
ZiplineConfigAttributeNames.traverseSpeed = "TraverseSpeed"
ZiplineConfigAttributeNames.waypointTouchRadius = "WaypointTouchRadius"


---------- Global variables ----------

local Globals = {}
Globals.activeZiplineGroup = {} :: {[Instance]: ZiplineGroupInfo}
Globals.assemblyRootPart_inZipline = {} :: {[BasePart]: boolean}
Globals.waypointInstance_assemblyRootPart_throttle = {} :: {[Instance]: {[BasePart]: boolean}}


---------- Ziplin effect functions ----------

local getVFXInfo
local getOrCreateWaypointAttachment
local createZiplineRouteVFX

getVFXInfo = function(container: Instance): VFXInfo?
    local VFXInfoFolder
    local result

    VFXInfoFolder = container:FindFirstChild(Constants.VFXInfoFolderName)
    if VFXInfoFolder then
        result = {} :: VFXInfo
        result.VFXBeam =  VFXInfoFolder:FindFirstChild("VFXBeam") :: Beam
        result.VFXBeam.Enabled = false
    end

    return result
end

getOrCreateWaypointAttachment = function(container: Instance, ziplineRoute: ZiplineRoute.ClassType, waypointId: number)
    local waypointInstance
    local waypointInstanceChildAttachment
    local waypointAttachment
    waypointInstance = ziplineRoute._waypointPositionInstances[waypointId]
    if waypointInstance:IsA("BasePart") then
        waypointInstanceChildAttachment = waypointInstance:FindFirstChild(Constants.waypointAttachmentName)
        if waypointInstanceChildAttachment and waypointInstanceChildAttachment:IsA("Attachment") then
            waypointAttachment = waypointInstanceChildAttachment
        else
            waypointAttachment = Instance.new("Attachment")
            table.insert(Globals.activeZiplineGroup[container].extraInstances, waypointAttachment)
            waypointAttachment.Name = Constants.waypointAttachmentName
            waypointAttachment.Parent = waypointInstance
        end
    else
        waypointAttachment = waypointInstance
    end
    return waypointAttachment
end

createZiplineRouteVFX = function(container: Instance, ziplineRoute: ZiplineRoute.ClassType)
    local vfxInfo = getVFXInfo(container) or Constants.defaultVFXInfo
    local templateBeam = vfxInfo.VFXBeam
    local vfxInstances = {}
    local waypointAttachment0
    local waypointAttachment1
    local pathBeam

    for waypointId = 1, ZiplineRoute.getWaypointCount(ziplineRoute) - 1 do
        waypointAttachment0 = getOrCreateWaypointAttachment(container, ziplineRoute, waypointId)
        waypointAttachment1 = getOrCreateWaypointAttachment(container, ziplineRoute, waypointId + 1)
        pathBeam = templateBeam:Clone()
        table.insert(Globals.activeZiplineGroup[container].vfxInstances, pathBeam)
        pathBeam.Attachment0 = waypointAttachment0
        pathBeam.Attachment1 = waypointAttachment1
        pathBeam.Enabled = true
        pathBeam.Parent = Constants.VFXInstancesFolder
    end

    return vfxInstances
end


---------- Zipline touched helper functions ----------

local canMovePart
local isWaypointTouchThrottled
local setWaypointTouchThrottle

canMovePart = function(part: BasePart)
    local assemblyRootPart = part.AssemblyRootPart
    local result
    result = assemblyRootPart and not assemblyRootPart.Anchored
    return result == true
end

isWaypointTouchThrottled = function(ziplineRoute: ZiplineRoute.ClassType, waypointId: number, part: BasePart)
    local touchedWaypointInstance = ziplineRoute._waypointPositionInstances[waypointId]
    local assemblyRootPart_throttle = Globals.waypointInstance_assemblyRootPart_throttle[touchedWaypointInstance]
    local assemblyRootPart = part.AssemblyRootPart
   return assemblyRootPart_throttle and assemblyRootPart and assemblyRootPart_throttle[assemblyRootPart]
end

setWaypointTouchThrottle = function(ziplineRoute: ZiplineRoute.ClassType, waypointId: number, part: BasePart)
    local waypointInstance = ziplineRoute._waypointPositionInstances[waypointId]
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


---------- Zipline touched functions ----------

local checkZiplineTouchedLoop
local onTouchedZipline
local traverseAlongZipline
local traverseAlongZiplineStartingDelay
local getTraverseWaypointOrder
local traverseAlongZiplineWithDirection

checkZiplineTouchedLoop = function(container: Instance, ziplineConfigs: Configuration, ziplineRoute: ZiplineRoute.ClassType, isValidPart_function: (BasePart) -> boolean)
    local waypointTouchRadius = tonumber(ziplineConfigs:GetAttribute(ZiplineConfigAttributeNames.waypointTouchRadius)) or 1
    local waypointQueryPart
    local waypointPosition
    local queriedParts

    waypointQueryPart = Instance.new("Part")
    waypointQueryPart.Shape = Enum.PartType.Ball
    waypointQueryPart.Size = Vector3.one * waypointTouchRadius * 2
    waypointQueryPart.CanCollide = false
    waypointQueryPart.Anchored = true
    for waypointId = 1, ZiplineRoute.getWaypointCount(ziplineRoute) do
        waypointPosition = ZiplineRoute.getWaypointPosition(ziplineRoute, waypointId)
        waypointQueryPart.Position = waypointPosition
        queriedParts = SpatialQuery.getWhitelistedInParts({waypointQueryPart}, {workspace})
        for _, part in queriedParts do
            if isValidPart_function(part) and (part.Parent and part.Parent.Parent) ~= container then
                onTouchedZipline(part, waypointId, ziplineConfigs, ziplineRoute)
            end
        end
    end
    waypointQueryPart:Destroy()
end

onTouchedZipline = function(part: BasePart, startWaypointId: number, ziplineConfigs: Configuration, ziplineRoute: ZiplineRoute.ClassType)
    local assemblyRootPart = part.AssemblyRootPart
    local isValid

    -- Validate touched part
    isValid = canMovePart(assemblyRootPart)
    isValid = isValid and not Globals.assemblyRootPart_inZipline[assemblyRootPart]
    isValid = isValid and not isWaypointTouchThrottled(ziplineRoute, startWaypointId, assemblyRootPart)

    -- Traverse
    if isValid then
        Globals.assemblyRootPart_inZipline[assemblyRootPart] = true
        task.defer(function()
            traverseAlongZipline(assemblyRootPart, startWaypointId, ziplineConfigs, ziplineRoute)
            task.wait(0.1)
            Globals.assemblyRootPart_inZipline[assemblyRootPart] = nil
        end)
    end
end

traverseAlongZipline = function(rootPart: BasePart, startWaypointId: number, ziplineConfigs: Configuration, ziplineRoute: ZiplineRoute.ClassType)
    local waypointCount = ZiplineRoute.getWaypointCount(ziplineRoute)
    local isPositiveDirection
    local waypointPosition
    local nextWaypointPosition
    local previousWaypointPosition
    local waypointPositiveDirection
    local waypointNegativeDirection
    local rootPartVelocityDirection
    if startWaypointId == 1 then
        isPositiveDirection = true
    elseif startWaypointId == waypointCount then
        isPositiveDirection = false
    else
        waypointPosition = ZiplineRoute.getWaypointPosition(ziplineRoute, startWaypointId)
        nextWaypointPosition = ZiplineRoute.getWaypointPosition(ziplineRoute, startWaypointId + 1)
        previousWaypointPosition = ZiplineRoute.getWaypointPosition(ziplineRoute, startWaypointId - 1)
        waypointPositiveDirection = (nextWaypointPosition - waypointPosition).Unit
        waypointNegativeDirection = (previousWaypointPosition - waypointPosition).Unit
        rootPartVelocityDirection = rootPart.AssemblyLinearVelocity.Unit
        if rootPartVelocityDirection ~= rootPartVelocityDirection then
            rootPartVelocityDirection = Vector3.new(0, -1, 0)
        end
        isPositiveDirection = waypointPositiveDirection:Dot(rootPartVelocityDirection) >= waypointNegativeDirection:Dot(rootPartVelocityDirection)
    end
    traverseAlongZiplineStartingDelay(rootPart, startWaypointId, ziplineConfigs, ziplineRoute)
    traverseAlongZiplineWithDirection(rootPart, startWaypointId, ziplineConfigs, ziplineRoute, isPositiveDirection)
end

traverseAlongZiplineStartingDelay = function(rootPart: BasePart, startWaypointId: number, ziplineConfigs: Configuration, ziplineRoute: ZiplineRoute.ClassType)
    local assemblyRootPart = rootPart.AssemblyRootPart
    local isPlayer
    local startDelay
    local startPosition
    local delayStartTime
    local delayStopTime

    -- Get start delay
    isPlayer = Players:GetPlayerFromCharacter(assemblyRootPart and assemblyRootPart.Parent)
    if isPlayer then
        startDelay = tonumber(ziplineConfigs:GetAttribute(ZiplineConfigAttributeNames.startDelay_players)) or 0.5
    else
        startDelay = tonumber(ziplineConfigs:GetAttribute(ZiplineConfigAttributeNames.startDelay_objects)) or 0
    end

    -- Idle at start position
    startPosition = ziplineRoute._waypointPositionInstances[startWaypointId].Position
    delayStartTime = time()
    delayStopTime = delayStartTime + startDelay
    while time() < delayStopTime and canMovePart(rootPart) and rootPart == rootPart.AssemblyRootPart do
        rootPart:PivotTo(CFrame.new(startPosition) * rootPart.CFrame.Rotation)
        rootPart.AssemblyLinearVelocity = Vector3.zero
        RunService.Heartbeat:Wait()
    end
end

getTraverseWaypointOrder = function(ziplineRoute: ZiplineRoute.ClassType, startWaypointId: number, isPositiveDirection: boolean)
    local result = {}
    if isPositiveDirection then
        for id = startWaypointId, ZiplineRoute.getWaypointCount(ziplineRoute) do
            table.insert(result, id)
        end
    else
        for id = startWaypointId, 1, -1 do
            table.insert(result, id)
        end
    end
    return result
end

traverseAlongZiplineWithDirection = function(rootPart: BasePart, startWaypointId: number, ziplineConfigs: Configuration, ziplineRoute: ZiplineRoute.ClassType, isPositiveDirection: boolean)
    local traverseSpeed = tonumber(ziplineConfigs:GetAttribute(ZiplineConfigAttributeNames.traverseSpeed)) or 32
    local traverseWaypointOrder
    local waypointId
    local nextWaypointId
    local waypointPosition
    local nextWaypointPosition
    local waypointDistance
    local segmentTraversalTime
    local waypointTraverseDirection
    local waypointTraverseVelocity
    local traverseSegmentStartTime
    local traverseSegmentStopTime
    local alpha
    local traversePosition

    -- Traverse
    traverseWaypointOrder = getTraverseWaypointOrder(ziplineRoute, startWaypointId, isPositiveDirection)
    for traverseId = 1, #traverseWaypointOrder - 1 do
        waypointId = traverseWaypointOrder[traverseId]
        nextWaypointId = traverseWaypointOrder[traverseId + 1]

        -- Throttle / debounce for waypoint
        setWaypointTouchThrottle(ziplineRoute, waypointId, rootPart)

        -- Calculate segment traversal time
        waypointPosition = ZiplineRoute.getWaypointPosition(ziplineRoute, waypointId)
        nextWaypointPosition = ZiplineRoute.getWaypointPosition(ziplineRoute, nextWaypointId)
        waypointDistance = (waypointPosition - nextWaypointPosition).Magnitude
        segmentTraversalTime = waypointDistance / traverseSpeed

        -- Calculate traverse velocity
        waypointTraverseDirection = (nextWaypointPosition - waypointPosition).Unit
        waypointTraverseVelocity = waypointTraverseDirection * traverseSpeed

        -- Traverse the segment
        traverseSegmentStartTime = time()
        traverseSegmentStopTime = traverseSegmentStartTime + segmentTraversalTime
        while time() < traverseSegmentStopTime and canMovePart(rootPart) and rootPart == rootPart.AssemblyRootPart do
            alpha = math.map(time(), traverseSegmentStartTime, traverseSegmentStopTime, waypointId, nextWaypointId) - 1
            traversePosition = ZiplineRoute.getPosition(ziplineRoute, alpha, true)
            rootPart:PivotTo(CFrame.new(traversePosition) * rootPart.CFrame.Rotation)
            rootPart.AssemblyLinearVelocity = waypointTraverseVelocity
            RunService.Heartbeat:Wait()
        end

        -- Validate can move
        if not (canMovePart(rootPart) and rootPart == rootPart.AssemblyRootPart) then
            break
        end
    end

    -- Throttle / debounce for last waypoint
    if canMovePart(rootPart) and rootPart == rootPart.AssemblyRootPart then
        setWaypointTouchThrottle(ziplineRoute, nextWaypointId, rootPart)
    end
end


---------- Zipline config functions ----------

local getOrCreateZiplineConfigs

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


---------- Set up helper functions ----------

local getOrderedWaypointInstances

getOrderedWaypointInstances = function(container: Instance)
    local waypointsFolder = container:FindFirstChild(Constants.waypointsFolderName)
    local waypointInstances

    -- Get children waypoints
    waypointInstances = {}
    if waypointsFolder then
        for _, object in waypointsFolder:GetChildren() do
            if object:IsA("BasePart") then
                table.insert(waypointInstances, object)
            end
        end
    end

    -- Sort waypoints by name
    table.sort(waypointInstances, function(a, b) return a.Name < b.Name end)

    return waypointInstances
end


---------- Set up functions ----------

local setUpZiplineGroup
local cleanUpZiplineGroup

setUpZiplineGroup = function(container: Instance, isValidPart_function: (BasePart) -> boolean, willCreateVFX: boolean)
    local orderedInstances
    local ziplineRoute
    local ziplineGroupInfo
    local ziplineConfigs

    -- Clean up & initialize
    cleanUpZiplineGroup(container)
    ziplineGroupInfo = {} :: ZiplineGroupInfo
    ziplineGroupInfo.vfxInstances = {}
    ziplineGroupInfo.extraInstances = {}
    ziplineGroupInfo.connections = {}
    Globals.activeZiplineGroup[container] = ziplineGroupInfo

    -- Get zipline configs
    ziplineConfigs = getOrCreateZiplineConfigs(container)

    -- Create zipline route
    orderedInstances = getOrderedWaypointInstances(container)
    ziplineRoute = ZiplineRoute.new()
    ziplineGroupInfo.route = ziplineRoute
    ZiplineRoute.setWaypointInstances(ziplineRoute, orderedInstances)

    -- Create zipline VFX
    if willCreateVFX then
        createZiplineRouteVFX(container, ziplineRoute)
    end

    -- Set up zipline connection
    table.insert(ziplineGroupInfo.connections, RunService.Heartbeat:Connect(function()
        checkZiplineTouchedLoop(container, ziplineConfigs, ziplineRoute, isValidPart_function)
    end))
end

cleanUpZiplineGroup = function(container: Instance)
    local ziplineGroup = Globals.activeZiplineGroup[container]
    if ziplineGroup then
        for _, instance in ziplineGroup.route._waypointPositionInstances do
            table.clear(Globals.waypointInstance_assemblyRootPart_throttle[instance])
        end
        ZiplineRoute.cleanUp(ziplineGroup.route)
        for _, object in ziplineGroup.vfxInstances do object:Destroy() end
        for _, object in ziplineGroup.extraInstances do object:Destroy() end
        for _, connection in ziplineGroup.connections do connection:Disconnect() end
        table.clear(ziplineGroup[container])
    end
end


---------- Module ----------

local module = {}


---------- Module fields ----------

module.setUpZiplineGroup = setUpZiplineGroup
module.cleanUpZiplineGroup = cleanUpZiplineGroup


---------- Return module ----------

return module
