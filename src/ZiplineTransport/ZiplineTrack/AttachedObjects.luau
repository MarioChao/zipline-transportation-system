--!strict

-- Attached Objects


---------- Types ----------

export type AttachedObjectConfig = {
    attach_atParameter: number,
    attach_fromClient: boolean,
    attach_traversePositiveDirection: boolean,
    attach_useDistanceAsParameter: boolean,
}


---------- Constants ----------

local Constants = {}

Constants.attObjConfigAttributes = {
    attach_atParameter = "Attach_AtParameter",
    attach_fromClient = "Attach_FromClient",
    attach_traversePositiveDirection = "Attach_TraversePositiveDirection",
    attach_useDistanceAsParameter = "Attach_UseDistanceAsParameter",
}

table.freeze(Constants)


---------- Local functions ----------

local getDefault_boolean
local getDefault_childInstance
local getDefault_number
local getDefault_string
local getDefault_vector3

local getAttachedObjectConfig


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

getAttachedObjectConfig = function(configInstance: ObjectValue)
    local realConfig = configInstance or Instance.new("ObjectValue")

    local result = {
        attach_atParameter = getDefault_number(realConfig:GetAttribute(Constants.attObjConfigAttributes.attach_atParameter), 0),
        attach_fromClient = getDefault_boolean(realConfig:GetAttribute(Constants.attObjConfigAttributes.attach_fromClient), true),
        attach_traversePositiveDirection = getDefault_boolean(realConfig:GetAttribute(Constants.attObjConfigAttributes.attach_traversePositiveDirection), true),
        attach_useDistanceAsParameter = getDefault_boolean(realConfig:GetAttribute(Constants.attObjConfigAttributes.attach_useDistanceAsParameter), true),
    } :: AttachedObjectConfig
    return result
end


---------- Module ----------

local Module = {}


----- Module fields -----

function Module.getConfig(configInstance: ObjectValue)
    return getAttachedObjectConfig(configInstance)
end


---------- Return module ----------

return Module
