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
local UIUtil = require(Packages:WaitForChild("UIUtil"))
local LinkedRoute = SegmentedRoute.LinkedRoute

local ClientMovementDetector
if RunService:IsClient() then
    ClientMovementDetector = require(Packages:WaitForChild("ClientMovementDetector"))
end

---------- Types ----------

type LinkedRoute = typeof(LinkedRoute) & {_routeSegments: {any}}

type ZiplineGroupInfo = {
    config: ZiplineConfig,
    container: Instance,
    route: LinkedRoute,
    waypointInstances: {BasePart},
    visualizedFXFolder: Folder?,
    extraFXFolder: Folder,
    extraInstances: {Instance},
    connections: {RBXScriptConnection},
}

export type ZiplineConfig = ZiplineConfigs.ZiplineConfig


---------- Constants ----------

local Constants = {}

Constants.controlPointsFolderName = "ControlPoints"
Constants.controlPointAttachmentName = "ControlPointAttachment"

Constants.ziplineConfigName = "ZiplineConfig"

Constants.waypointTouchThrottle = 0.5

Constants.storedTransparencyAttributeName = "StoredTransparency"
Constants.routeAlphaAttributeName = "RouteAlpha"

Constants.guidePartTagName = "ZiplineGuidePart"

Constants.rotateXToZOffsetCFrame = CFrame.fromRotationBetweenVectors(Vector3.xAxis, Vector3.zAxis)

table.freeze(Constants)


---------- Global variables ----------

local Globals = {}
Globals.activeZiplineGroup = {} :: {[Instance]: ZiplineGroupInfo}
Globals.assemblyRootPart_inZipline = {} :: {[BasePart]: boolean}
Globals.waypointInstance_part_throttle = {} :: {[Instance]: {[BasePart]: true?}}
Globals.waypointInstance_part_throttleThread = {} :: {[Instance]: {[BasePart]: thread?}}


---------- Local functions ----------

local getPieModel
local getIsPieAClientPie
local getIsTaggedRider

local processFXInfo
local createZiplineRouteVisualizerVFX

local getIsActiveWaypoint
local getIsLoopedStartWaypoint
local getWaypointAlpha
local createZiplineRouteWaypointsVFX
local setUpZiplineRouteWaypoints

local canMovePart
local getIsGuidePart
local getIsWaypointTouchThrottled
local setWaypointTouchThrottle

local checkZiplineTouchedLoop
local onTouchedZipline
local traverseAlongZipline

local getTraverseZiplineStartDelay
local getTraverseZiplineOffset
local getNextRouteAlpha
local traverseAlongZiplineWithDirection

local getControlPointConfig
local getOrderedControlPoints
local getOrderedSegments


----- Rider -----

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

getIsPieAClientPie = function(pieModel: Model?): boolean
	local pieMainPart = pieModel and pieModel:FindFirstChild("MainPart") :: Part
	local pieUniqueId = pieModel and pieModel:FindFirstChild("UniquePieId") :: StringValue
	local pieTag = pieUniqueId and pieUniqueId.Value
	local _isClientPie = pieMainPart and pieMainPart:IsA("Part") and pieTag and typeof(pieTag) == "string"
	return _isClientPie == true
end

getIsTaggedRider = function(rootPart: BasePart?, ziplineConfig: ZiplineConfig)
    local hasTag = false
    if rootPart then
        local targetTag
        if RunService:IsClient() then
            targetTag = ziplineConfig.ridersConfig.tagName_client
        else
            targetTag = ziplineConfig.ridersConfig.tagName_server
        end
        hasTag = rootPart:HasTag(targetTag)
    end
    return hasTag
end


----- Zipline effect functions -----

processFXInfo = function(ziplineConfig: ZiplineConfig)
    local fxInfo = ziplineConfig.fxInfo

    -- Process parts
    local parts = {
        fxInfo.guidePart, fxInfo.segmentPart, fxInfo.waypointPart
    }
    for _, part in parts do
        -- Anchor & disable collision
        part.Anchored = true
        part.AudioCanCollide = false
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false

        -- Store transparency
        if not part:GetAttribute(Constants.storedTransparencyAttributeName) then
            part:SetAttribute(Constants.storedTransparencyAttributeName, part.Transparency)
        end
        UIUtil.setTransparency(part, 1)
    end
end

createZiplineRouteVisualizerVFX = function(ziplineConfig: ZiplineConfig, ziplineRoute: LinkedRoute)
    local fxInfo = ziplineConfig.fxInfo
    local templatePart = fxInfo.segmentPart
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

getIsActiveWaypoint = function(waypointId: number, ziplineConfig: ZiplineConfig, numberOfWaypoints: number)
    local result = true
    if waypointId == 1 or waypointId == numberOfWaypoints then
        if ziplineConfig.isLooped then
            result = result and (ziplineConfig.waypointsConfig.create_start or ziplineConfig.waypointsConfig.create_stop)
            result = result and waypointId == 1
        elseif waypointId == 1 then
            result = result and ziplineConfig.waypointsConfig.create_start
        elseif waypointId == numberOfWaypoints then
            result = result and ziplineConfig.waypointsConfig.create_stop
        end
    else
        result = result and ziplineConfig.waypointsConfig.create_middle
    end
    return result
end

getIsLoopedStartWaypoint = function(waypointId: number, ziplineConfig: ZiplineConfig)
    return waypointId == 1 and ziplineConfig.isLooped
end

getWaypointAlpha = function(waypoint: BasePart)
    return tonumber(waypoint:GetAttribute(Constants.routeAlphaAttributeName)) or 0
end

createZiplineRouteWaypointsVFX = function(ziplineConfig: ZiplineConfig, ziplineRoute: LinkedRoute)
    local fxInfo = ziplineConfig.fxInfo
    local templatePart = fxInfo.waypointPart
    local partsFolder
    local vfxInstances
    local alphaRange_scalar = ziplineRoute:getAlphaRange_scalar()
    local waypointsConfig = ziplineConfig.waypointsConfig
    local startAlpha = 0
    local deltaAlpha = if waypointsConfig.create_middle then 1 else alphaRange_scalar

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
    local keepStart = waypointsConfig.create_start
    keepStart = keepStart or (ziplineConfig.isLooped and (waypointsConfig.create_start or waypointsConfig.create_stop))
    local keepStop = waypointsConfig.create_stop
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
    partsFolder, vfxInstances = createZiplineRouteWaypointsVFX(ziplineConfig, ziplineRoute)

    -- Set up proximity prompts
    if ziplineConfig.waypointsConfig.activate_proximityPrompt and RunService:IsClient() then
        for i = 1, #vfxInstances do
            if getIsActiveWaypoint(i, ziplineConfig, #vfxInstances) then
                proximityPrompt = ziplineConfig.fxInfo.waypointProximityPrompt:Clone()
                proximityPrompt.Parent = vfxInstances[i]
                proximityPrompt.Triggered:Connect(function(player: Player)
                    -- Check valid
                    local character = player.Character
                    local part = character and character:FindFirstChild("HumanoidRootPart")
                    if part and part:IsA("BasePart") then
                        local rootPart = part.AssemblyRootPart
                        local isPlayer = Players:GetPlayerFromCharacter(rootPart and rootPart.Parent)
                        local isValidPart = ziplineConfig.ridersConfig.support_players and isPlayer
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

getIsGuidePart = function(part: BasePart)
    return part:HasTag(Constants.guidePartTagName)
end

getIsWaypointTouchThrottled = function(ziplineGroup: ZiplineGroupInfo, waypointId: number, part: BasePart)
    local touchedWaypointInstance = ziplineGroup.waypointInstances[waypointId]
    local part_throttle = Globals.waypointInstance_part_throttle[touchedWaypointInstance]
   return part_throttle and part_throttle[part]
end

setWaypointTouchThrottle = function(ziplineGroup: ZiplineGroupInfo, waypointId: number, assemblyPart: BasePart)
    local waypointInstance = ziplineGroup.waypointInstances[waypointId]
    if waypointInstance then
        -- Create default table
        if not Globals.waypointInstance_part_throttle[waypointInstance] then
            Globals.waypointInstance_part_throttle[waypointInstance] = {}
        end
        if not Globals.waypointInstance_part_throttleThread[waypointInstance] then
            Globals.waypointInstance_part_throttleThread[waypointInstance] = {}
        end

        -- Throttle
        for _, part in assemblyPart:GetConnectedParts(true) do
            local existingThread = Globals.waypointInstance_part_throttleThread[waypointInstance][part]
            if existingThread then
                task.cancel(existingThread)
            end
            Globals.waypointInstance_part_throttle[waypointInstance][part] = true
            Globals.waypointInstance_part_throttleThread[waypointInstance][part] = task.delay(Constants.waypointTouchThrottle, function()
                Globals.waypointInstance_part_throttle[waypointInstance][part] = nil
                Globals.waypointInstance_part_throttleThread[waypointInstance][part] = nil
            end)
        end
    end
end


----- Zipline touched functions -----

checkZiplineTouchedLoop = function(container: Instance, ziplineConfig: ZiplineConfig, ziplineGroup: ZiplineGroupInfo, isValidPart_function: (BasePart, ZiplineConfig) -> boolean)
    local waypointTouchRadius = ziplineConfig.waypointsConfig.touch_radius
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
            local isClientPie = getIsPieAClientPie(getPieModel(rootPart))
            local isTaggedRider = getIsTaggedRider(rootPart, ziplineConfig)
            local isValidPart = true

            -- Ensure valid part
            isValidPart = isValidPart and not getIsGuidePart(part)
            isValidPart = isValidPart and getIsActiveWaypoint(waypointId, ziplineConfig, #ziplineGroup.waypointInstances)
            isValidPart = isValidPart and isValidPart_function(part, ziplineConfig)

            -- Ensure valid part from config
            if isPlayer then
                isValidPart = isValidPart and ziplineConfig.ridersConfig.support_players and ziplineConfig.waypointsConfig.activate_playerTouch
            elseif isClientPie then
                isValidPart = isValidPart and ziplineConfig.ridersConfig.support_clientPies
            elseif isTaggedRider then
                isValidPart = isValidPart and ziplineConfig.ridersConfig.support_tagged
            else
                isValidPart = isValidPart and ziplineConfig.ridersConfig.support_objects
            end

            -- Run touched
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
    isValid = isValid and not getIsWaypointTouchThrottled(ziplineGroup, startWaypointId, assemblyRootPart)

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
    -- Info
    local waypointCount = #ziplineGroup.waypointInstances
    local isPlayer = Players:GetPlayerFromCharacter(rootPart and rootPart.Parent)

    -- Calculated values
    local isPositiveDirection

    -- Check looped endpoint
    if getIsLoopedStartWaypoint(startWaypointId, ziplineConfig) then
        local routeAlphaRange = ziplineGroup.route:getAlphaRange()
        local waypointPositiveDirection = ziplineGroup.route:getPositiveDirectionAtAlpha(routeAlphaRange.Min)
        local waypointNegativeDirection = -ziplineGroup.route:getPositiveDirectionAtAlpha(routeAlphaRange.Max)
        local rootPartVelocityDirection = rootPart.AssemblyLinearVelocity.Unit

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
        local waypointPositiveDirection = ziplineGroup.route:getPositiveDirectionAtAlpha(routeAlpha + 0.001)
        local waypointNegativeDirection = -ziplineGroup.route:getPositiveDirectionAtAlpha(routeAlpha - 0.001)
        local rootPartVelocityDirection = rootPart.AssemblyLinearVelocity.Unit
        if rootPartVelocityDirection ~= rootPartVelocityDirection then
            rootPartVelocityDirection = Vector3.new(0, -1, 0)
        end
        isPositiveDirection = waypointPositiveDirection:Dot(rootPartVelocityDirection) >= waypointNegativeDirection:Dot(rootPartVelocityDirection)
    end

    -- Traverse
    local startAlpha = getWaypointAlpha(ziplineGroup.waypointInstances[startWaypointId])
    traverseAlongZiplineWithDirection(rootPart, startAlpha, ziplineConfig, ziplineGroup, isPositiveDirection)

    -- Validate can move
    if not canMovePart(rootPart) then
        return
    end

    -- Dismount: keep momentum
    if not ziplineConfig.ridersConfig.dismount_keepMomentum then
        rootPart.AssemblyLinearVelocity = Vector3.zero
    end

    -- Dismount: will jump
    if ziplineConfig.ridersConfig.dismount_willJump then
        if RunService:IsClient() and isPlayer then
            local player = isPlayer
            local character = player.Character
            local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end
end


----- Zipline traversal -----

getTraverseZiplineStartDelay = function(rootPart: BasePart, ziplineConfig: ZiplineConfig)
    -- Confirm root part
    rootPart = rootPart.AssemblyRootPart

    -- Get part type
    local isPlayer = Players:GetPlayerFromCharacter(rootPart and rootPart.Parent)
    local isClientPie = getIsPieAClientPie(getPieModel(rootPart))
    local isTaggedRider = getIsTaggedRider(rootPart, ziplineConfig)

    -- Get start delay
    local startDelay
    if isPlayer then
        startDelay = ziplineConfig.ridersConfig.startDelay_players
    elseif isClientPie then
        startDelay = ziplineConfig.ridersConfig.startDelay_clientPies
    elseif isTaggedRider then
        startDelay = ziplineConfig.ridersConfig.startDelay_tagged
    else
        startDelay = ziplineConfig.ridersConfig.startDelay_objects
    end

    -- Return result
    return startDelay
end

getTraverseZiplineOffset = function(rootPart: BasePart, ziplineConfig: ZiplineConfig)
    -- Confirm root part
    rootPart = rootPart.AssemblyRootPart

    -- Get part type
    local isPlayer = Players:GetPlayerFromCharacter(rootPart and rootPart.Parent)
    local isClientPie = getIsPieAClientPie(getPieModel(rootPart))
    local isTaggedRider = getIsTaggedRider(rootPart, ziplineConfig)

    -- Get offset
    local result
    if isPlayer then
        result = ziplineConfig.ridersConfig.offset_players
    elseif isClientPie then
        result = ziplineConfig.ridersConfig.offset_clientPies
    elseif isTaggedRider then
        result = ziplineConfig.ridersConfig.offset_tagged
    else
        result = ziplineConfig.ridersConfig.offset_objects
    end

    -- Return result
    return result
end

getNextRouteAlpha = function(
    currentAlpha: number, velocitySign: number, reparameterization_function: (number, boolean, boolean?) -> number,
    isLooped: boolean,
    traverseSpeed: number, deltaTime: number,
    routeDistanceRange: NumberRange
)
    local routeAlpha = currentAlpha
    if velocitySign ~= 0 then
        local routeDistance = reparameterization_function(routeAlpha, false)
        local deltaDistance = deltaTime * traverseSpeed * velocitySign
        routeDistance += deltaDistance

        -- Resolve looped
        if isLooped then
            if routeDistance < routeDistanceRange.Min or routeDistance > routeDistanceRange.Max then
                local rangeScalar = routeDistanceRange.Max - routeDistanceRange.Min
                routeDistance = (routeDistance - routeDistanceRange.Min) % rangeScalar + routeDistanceRange.Min
            end
        end

        routeAlpha = reparameterization_function(routeDistance, true)
    end
    return routeAlpha
end

traverseAlongZiplineWithDirection = function(rootPart: BasePart, startAlpha: number, ziplineConfig: ZiplineConfig, ziplineGroup: ZiplineGroupInfo, isPositiveDirection: boolean)
    -- Validate can move
    --  This is needed in case rootPart becomes anchored right before
    if not canMovePart(rootPart) then
        return
    end

    -- Create guide part
    local startPosition = ziplineGroup.route:getPositionAtAlpha(startAlpha)
    local startLookVector = ziplineGroup.route:getPositiveDirectionAtAlpha(startAlpha)
    local startLookCFrame = CFrame.lookAlong(startPosition, startLookVector)
    local startRightCFrame = startLookCFrame:ToWorldSpace(Constants.rotateXToZOffsetCFrame)
    local guidePart = ziplineConfig.fxInfo.guidePart:Clone()
    guidePart:AddTag(Constants.guidePartTagName)
    guidePart:PivotTo(startRightCFrame)
    UIUtil.resetTransparency(guidePart)
    guidePart.Parent = ziplineGroup.extraFXFolder

    -- Create constraints
    local constraintInstances = {} :: {Instance}
    if ziplineConfig.ridersConfig.connect_byRope then
        local attachment0 = Instance.new("Attachment")
        local attachment1 = Instance.new("Attachment")
        local constraint = Instance.new("RopeConstraint")
        attachment0.Parent = guidePart
        attachment1.Parent = rootPart
        constraint.Length = ziplineConfig.ridersConfig.connect_ropeLength
        constraint.Attachment0 = attachment0
        constraint.Attachment1 = attachment1
        constraint.Parent = guidePart
        constraint.Visible = true
        table.insert(constraintInstances, attachment0)
        table.insert(constraintInstances, attachment1)
        table.insert(constraintInstances, constraint)
    else
        local offset = getTraverseZiplineOffset(rootPart, ziplineConfig)
        local constraint = Instance.new("WeldConstraint")
        rootPart:PivotTo(startLookCFrame.Rotation + startLookCFrame:PointToWorldSpace(offset))
        constraint.Part0 = guidePart
        constraint.Part1 = rootPart
        constraint.Parent = guidePart
        table.insert(constraintInstances, constraint)
    end

    -- Traverse info
    local waypointCount = #ziplineGroup.waypointInstances
    local routeAlphaRange = ziplineGroup.route:getAlphaRange()
    local traverseSpeed = ziplineConfig.traverseSpeed
    local baseVelocitySign = if isPositiveDirection then 1 else -1

    -- Player info
    local isPlayer = Players:GetPlayerFromCharacter(rootPart and rootPart.Parent)
    local ignoreCurrentJump = true

    -- Get reparameterized route (assume static route)
    local reparameterization_function = SegmentedRoute.RouteUtil.Reparam.getRoute_reparameterization_function(ziplineGroup.route)
    local routeDistanceRange = NumberRange.new(
        reparameterization_function(routeAlphaRange.Min, false),
        reparameterization_function(routeAlphaRange.Max, false)
    )

    -- Create align objects
    local alignAttachment = Instance.new("Attachment")
    local alignPosition = Instance.new("AlignPosition")
    -- alignAttachment.Parent = rootPart
    -- alignPosition.MaxForce = math.huge
    -- alignPosition.MaxVelocity = traverseSpeed
    -- alignPosition.Responsiveness = 1000
    -- alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
    -- alignPosition.Attachment0 = alignAttachment
    -- alignPosition.Parent = rootPart

    -- Start delay
    local startDelay = getTraverseZiplineStartDelay(rootPart, ziplineConfig)
    if startDelay > 0 then
        local delayStartTime = time()
        local delayStopTime = delayStartTime + startDelay
        while time() < delayStopTime do
            -- Validate exist
            if not rootPart:IsDescendantOf(workspace) then
                break
            end

            -- Resolve dismount: by jump
            if ziplineConfig.ridersConfig.dismount_byJump then
                if RunService:IsClient() and isPlayer then
                    local isJumping = ClientMovementDetector.getIsJumping()
                    if ignoreCurrentJump then
                        -- Ignore if jump held from before the zipline traversal
                        ignoreCurrentJump = isJumping
                    elseif isJumping then
                        break
                    end
                end
            end

            -- Move
            guidePart:PivotTo(startRightCFrame)
            guidePart.AssemblyLinearVelocity = Vector3.zero

            -- Delay
            task.wait()
        end
    end

    -- Traverse
    local routeAlpha = startAlpha
    local previousTime
    local previousTraversePosition
    local previousTraverseOrientation
    while true do
        -- Validate exist
        if not rootPart:IsDescendantOf(workspace) then
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
            if nearbyWaypointId == waypointCount and ziplineConfig.isLooped then
                nearbyWaypointId = 1
            end
            setWaypointTouchThrottle(ziplineGroup, nearbyWaypointId, rootPart)
        end

        -- Calculate velocity sign
        local velocitySign = baseVelocitySign
        if RunService:IsClient() and isPlayer and ziplineConfig.ridersConfig.allow_userControl then
            local moveDirection = ClientMovementDetector.getMoveDirection_input()
            local isForwards = moveDirection.Z < 0
            local isBackwards = moveDirection.Z > 0
            if isForwards then
                velocitySign *= 1
            elseif isBackwards then
                velocitySign *= -1
            else
                velocitySign = 0
            end
        end

        -- Update route alpha
        local currentTime = time()
        if previousTime then
            routeAlpha = getNextRouteAlpha(
                routeAlpha, velocitySign, reparameterization_function,
                ziplineConfig.isLooped,
                traverseSpeed, currentTime - previousTime,
                routeDistanceRange
            )
        end

        -- Resolve dismount: by end
        if ziplineConfig.ridersConfig.dismount_byEnd and not ziplineConfig.isLooped then
            local isEnd = false
            isEnd = isEnd or (isPositiveDirection and routeAlpha > routeAlphaRange.Max)
            isEnd = isEnd or (not isPositiveDirection and routeAlpha < routeAlphaRange.Min)
            if isEnd then
                break
            end
        end

        -- Resolve dismount: by jump
        if ziplineConfig.ridersConfig.dismount_byJump then
            if RunService:IsClient() and isPlayer then
                local isJumping = ClientMovementDetector.getIsJumping()
                if ignoreCurrentJump then
                    -- Ignore if jump held from before the zipline traversal
                    ignoreCurrentJump = isJumping
                elseif isJumping then
                    break
                end
            end
        end

        -- Clamp route alpha
        routeAlpha = math.clamp(routeAlpha, routeAlphaRange.Min, routeAlphaRange.Max)

        -- Calculate traverse position
        local traversePosition = ziplineGroup.route:getPositionAtAlpha(routeAlpha, true)

        -- Calculate traverse velocity vector
        local traverseVelocity = Vector3.zero
        if previousTime and previousTraversePosition then
            local positionChange = traversePosition - previousTraversePosition
            local timeChange = currentTime - previousTime
            traverseVelocity = positionChange / timeChange
        end

        -- Calculate traverse orientation
        local baseTraverseDirection = ziplineGroup.route:getPositiveDirectionAtAlpha(routeAlpha, true) * baseVelocitySign
        local traverseLookCFrame = CFrame.lookAlong(traversePosition, baseTraverseDirection)
        local traverseOrientation
        do
            local rx, ry, rz = traverseLookCFrame:ToOrientation()
            traverseOrientation = Vector3.new(rx, ry, rz)
        end

        -- Calculate traverse angular velocity vector
        local traverseAngularVelocity = Vector3.zero
        if previousTime and previousTraverseOrientation then
            local orientationChange = traverseOrientation - previousTraverseOrientation
            local timeChange = currentTime - previousTime
            traverseAngularVelocity = orientationChange / timeChange
        end

        -- Set traverse kinematics
        -- alignPosition.Position = traversePosition
        local traverseRightCFrame = traverseLookCFrame:ToWorldSpace(Constants.rotateXToZOffsetCFrame)
        guidePart:PivotTo(traverseRightCFrame)
        guidePart.AssemblyLinearVelocity = traverseVelocity
        guidePart.AssemblyAngularVelocity = traverseAngularVelocity

        -- Delay
        task.wait()

        -- Update state
        previousTime = currentTime
        previousTraversePosition = traversePosition
        previousTraverseOrientation = traverseOrientation
    end

    -- Clean up
    alignPosition:Destroy()
    alignAttachment:Destroy()
    guidePart:Destroy()
    for _, instance in constraintInstances do
        instance:Destroy()
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


----- Set up functions -----

local setUpZiplineGroup
local cleanUpZiplineGroup

setUpZiplineGroup = function(container: Instance, isValidPart_function: (BasePart, ZiplineConfig) -> boolean, willCreateRouteVFX: boolean)
    local orderedControlPoints
    local orderedSegments
    local ziplineRoute
    local ziplineConfig
    local _: any

    -- Clean up
    cleanUpZiplineGroup(container)

    -- Initialize
    local ziplineGroupInfo = {} :: ZiplineGroupInfo
    ziplineGroupInfo.container = container
    ziplineGroupInfo.visualizedFXFolder = nil
    ziplineGroupInfo.extraFXFolder = Instance.new("Folder")
    ziplineGroupInfo.extraFXFolder.Name = "ZiplineGuidingParts"
    ziplineGroupInfo.extraFXFolder.Parent = workspace
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

    -- Process zipline FX
    processFXInfo(ziplineConfig)

    -- Create zipline visualizer VFX
    if willCreateRouteVFX then
        ziplineGroupInfo.visualizedFXFolder, _ = createZiplineRouteVisualizerVFX(ziplineConfig, ziplineRoute)
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
            table.clear(Globals.waypointInstance_part_throttle[instance])
        end
        ziplineGroup.route:cleanUp()
        if ziplineGroup.visualizedFXFolder then ziplineGroup.visualizedFXFolder:Destroy() end
        for _, object in ziplineGroup.extraInstances do object:Destroy() end
        for _, connection in ziplineGroup.connections do connection:Disconnect() end
        table.clear(ziplineGroup[container])
    end
end


---------- Module ----------

local Module = {}


----- Module fields -----

Module.setUpZiplineGroup = setUpZiplineGroup
Module.cleanUpZiplineGroup = cleanUpZiplineGroup


---------- Return module ----------

table.freeze(Module)
return Module
