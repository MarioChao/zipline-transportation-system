--!strict

---------- Services ----------

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")


---------- Imports ----------

local ZiplineTrack = require(script.Parent.ZiplineTrack)


---------- Constants ----------

local Constants = {}

Constants.ziplineGroupTag = "ZiplineGroup"

table.freeze(Constants)


---------- Local functions ----------

local getPieModel
local getIsPieAClientPie
local getIsTaggedRider

local isValidPart_function

local setUpTagged
local cleanUpTagged


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


----- Tag -----

setUpTagged = function(taggedInstance: Instance)
    ZiplineTrack.setUpZiplineGroup(taggedInstance, isValidPart_function, false)
end

cleanUpTagged = function(taggedInstance: Instance)
    ZiplineTrack.cleanUpZiplineGroup(taggedInstance)
end


----- Main -----

local function main()
    CollectionService:GetInstanceAddedSignal(Constants.ziplineGroupTag):Connect(setUpTagged)
    CollectionService:GetInstanceRemovedSignal(Constants.ziplineGroupTag):Connect(cleanUpTagged)
    for _, tagged in CollectionService:GetTagged(Constants.ziplineGroupTag) do
        setUpTagged(tagged)
    end
end


---------- Calling function ----------

main()
