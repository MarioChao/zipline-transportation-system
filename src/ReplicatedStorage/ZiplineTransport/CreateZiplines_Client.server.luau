--!strict

---------- Servies ----------

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")


---------- Imports ----------

local ZiplineSetup = require(script.Parent.ZiplineSetup)


---------- Constants ----------

local Constants = {}
Constants.ziplineGroupTag = "ZiplineGroup"


---------- Pie hiking tool functions ----------

local getPieModel
local isPieAClientPie

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


---------- Valid part function ----------

local isValidPart_function

isValidPart_function = function(part: BasePart)
    local isLocalPlayer = Players:GetPlayerFromCharacter(part.Parent) == Players.LocalPlayer
    local isClientPie = isPieAClientPie(getPieModel(part))
    return isLocalPlayer or isClientPie
end


---------- Tag functions ----------

local setUpTagged
local cleanUpTagged

setUpTagged = function(taggedInstance: Instance)
    ZiplineSetup.setUpZiplineGroup(taggedInstance, isValidPart_function, false)
end

cleanUpTagged = function(taggedInstance: Instance)
    ZiplineSetup.cleanUpZiplineGroup(taggedInstance)
end


---------- Main function ----------

local function onServerStart()
    CollectionService:GetInstanceAddedSignal(Constants.ziplineGroupTag):Connect(setUpTagged)
    CollectionService:GetInstanceRemovedSignal(Constants.ziplineGroupTag):Connect(cleanUpTagged)
    for _, tagged in CollectionService:GetTagged(Constants.ziplineGroupTag) do
        setUpTagged(tagged)
    end
end


---------- Calling functions ----------

onServerStart()
