--!strict

---------- Services ----------

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")


---------- Imports ----------

local ZiplineTrack = require(script.Parent:WaitForChild("ZiplineTrack"))

local _Modules = script.Parent.Parent
local ContainerMechanic = require(_Modules:WaitForChild("ContainerMechanic"))


---------- Types ----------

type ZiplineTagConfig = {}


---------- Constants ----------

local Constants = {}

Constants.ziplineConfigTag = "ZiplineConfig"

table.freeze(Constants)


---------- Globals ----------

local Globals = {}

Globals.container_ancestryChangedConnection = {} :: {[Instance]: RBXScriptConnection}
Globals.container_isUnderWorkspace = {} :: {[Instance]: boolean?}


---------- Local functions ----------

local getPieModel
local getIsPieAClientPie
local getIsTaggedRider

local isValidPart_function

local getConfigFromInstance
local setUpContainer
local cleanUpContainer


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

getIsTaggedRider = function(rootPart: BasePart?, ziplineConfig: ZiplineTrack.ZiplineConfig)
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


----- Valid part -----

isValidPart_function = function(part: BasePart, ziplineConfig: ZiplineTrack.ZiplineConfig)
    local isLocalPlayer = Players:GetPlayerFromCharacter(part.Parent) == Players.LocalPlayer
    local isClientPie = getIsPieAClientPie(getPieModel(part))
	local isTaggedRider = getIsTaggedRider(part, ziplineConfig)
    return isLocalPlayer or isClientPie or isTaggedRider
end


----- Container mechanic -----

getConfigFromInstance = function(configInstance: Instance): ZiplineTagConfig
    return {}
end

setUpContainer = function(container: Instance, config: ZiplineTagConfig)
    Globals.container_isUnderWorkspace[container] = container:IsDescendantOf(workspace)
    if Globals.container_isUnderWorkspace[container] then
        ZiplineTrack.setUpZiplineGroup(container, isValidPart_function, true)
    end

    -- Ancestry changed
    if Globals.container_ancestryChangedConnection[container] then
        Globals.container_ancestryChangedConnection[container]:Disconnect()
    end
    Globals.container_ancestryChangedConnection[container] = container.AncestryChanged:Connect(function()
        local previousIsUnderWorkspace = Globals.container_isUnderWorkspace[container]
        local isUnderWorkspace = container:IsDescendantOf(workspace)
        if previousIsUnderWorkspace ~= isUnderWorkspace then
            if isUnderWorkspace then
                ZiplineTrack.setUpZiplineGroup(container, isValidPart_function, true)
            else
                ZiplineTrack.cleanUpZiplineGroup(container)
            end
        end
        Globals.container_isUnderWorkspace[container] = isUnderWorkspace
    end)
end

cleanUpContainer = function(container: Instance)
    ZiplineTrack.cleanUpZiplineGroup(container)
    if Globals.container_ancestryChangedConnection[container] then
        Globals.container_ancestryChangedConnection[container]:Disconnect()
    end
    Globals.container_ancestryChangedConnection[container] = nil
    Globals.container_isUnderWorkspace[container] = nil
end


----- Main -----

local function main()
    local mechanic = ContainerMechanic.new(Constants.ziplineConfigTag)
    mechanic:setFunction_getConfigFromInstance(getConfigFromInstance)
    mechanic:setFunction_setUpContainer(setUpContainer)
    mechanic:setFunction_cleanUpContainer(cleanUpContainer)
    mechanic:run()
end


---------- Calling function ----------

main()
