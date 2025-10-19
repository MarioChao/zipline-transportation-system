--!strict

-- A zipline route connects waypoints such that waypoint K can only go to waypoint K-1 and waypoint K+1

---------- Types ----------

export type WaypointInstance = BasePart


---------- Constants ----------

local Constants = {}
Constants.waypointAttachmentName = "WaypointAttachment"


---------- Module ----------

local ZiplineRoute = {}
ZiplineRoute.__index = ZiplineRoute


---------- Module types ----------

type ClassData = {
    _waypointPositionInstances: {WaypointInstance},
}

export type ClassType = ClassData
-- export type ClassType = typeof(setmetatable({} :: ClassData, ZiplineRoute))


---------- Module fields ----------

function ZiplineRoute.new(): ClassType
    local self = {} :: ClassData
    -- local self = setmetatable({} :: ClassData, ZiplineRoute)

    self._waypointPositionInstances = {}

    return self
end


----- Functions for configuring waypoints -----

function ZiplineRoute.addWaypointInstance(self: ClassType, instance: WaypointInstance)
    table.insert(self._waypointPositionInstances, instance)
end

function ZiplineRoute.setWaypointInstances(self: ClassType, orderedInstances: {WaypointInstance})
    ZiplineRoute.clearWaypoints(self)
    for _, instance in orderedInstances do
        ZiplineRoute.addWaypointInstance(self, instance)
    end
end

function ZiplineRoute.clearWaypoints(self: ClassType)
    table.clear(self._waypointPositionInstances)
end


----- Route information functions -----

function ZiplineRoute.getWaypointCount(self: ClassType): number
    return #self._waypointPositionInstances
end

function ZiplineRoute.getEndpointAlphas(self: ClassType): NumberRange
    return NumberRange.new(0, ZiplineRoute.getWaypointCount(self) - 1)
end

function ZiplineRoute.isAlphaInRoute(self: ClassType, alpha: number): boolean
    local alphaRange = ZiplineRoute.getEndpointAlphas(self)
    return alphaRange.Min <= alpha and alpha <= alphaRange.Max
end


----- Position functions -----

function ZiplineRoute.getWaypointPosition(self: ClassType, waypointId: number): Vector3
    local positionInstance = self._waypointPositionInstances[waypointId]
    local positionInstanceChildAttachment
    local result
    positionInstanceChildAttachment = positionInstance:FindFirstChild(Constants.waypointAttachmentName)
    if positionInstanceChildAttachment and positionInstanceChildAttachment:IsA("Attachment") then
        result = positionInstanceChildAttachment.WorldPosition
    else
        result = positionInstance.Position
    end
    return result
end

function ZiplineRoute.getPositionBetweenWaypoints(self: ClassType, waypointId1: number, waypointId2: number, alpha: number): Vector3
    local position1 = ZiplineRoute.getWaypointPosition(self, waypointId1)
    local position2 =ZiplineRoute.getWaypointPosition(self, waypointId2)
    return position1:Lerp(position2, alpha)
end

function ZiplineRoute.getPosition(self: ClassType, alpha: number, willClampAlpha: boolean?): Vector3
    local waypointId1
    local waypointId2
    local waypointCount = ZiplineRoute.getWaypointCount(self)

    if willClampAlpha then
        local alphaRange = ZiplineRoute.getEndpointAlphas(self)
        alpha = math.clamp(alpha, alphaRange.Min, alphaRange.Max)
    end
    waypointId1 = math.clamp(math.floor(alpha) + 1, 1, waypointCount)
    waypointId2 = math.clamp(waypointId1 + 1, 1, waypointCount)
    return ZiplineRoute.getPositionBetweenWaypoints(self, waypointId1, waypointId2, select(2, math.modf(alpha)))
end


----- Clean up functions -----

function ZiplineRoute.cleanUp(self: ClassType)
    ZiplineRoute.clearWaypoints(self)
end


---------- Return module ----------

return ZiplineRoute
