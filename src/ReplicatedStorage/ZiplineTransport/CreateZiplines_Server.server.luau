--!strict

---------- Servies ----------

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")


---------- Imports ----------

local ZiplineTrack = require(script.Parent.ZiplineTrack)


---------- Constants ----------

local Constants = {}
Constants.ziplineGroupTag = "ZiplineGroup"


---------- Valid part function ----------

local isValidPart_function

isValidPart_function = function(part: BasePart)
    local assemblyRootPart = part.AssemblyRootPart
    local isNotPlayer = not Players:GetPlayerFromCharacter(assemblyRootPart and assemblyRootPart.Parent)
    return isNotPlayer
end


---------- Tag functions ----------

local setUpTagged
local cleanUpTagged

setUpTagged = function(taggedInstance: Instance)
    ZiplineTrack.setUpZiplineGroup(taggedInstance, isValidPart_function, true)
end

cleanUpTagged = function(taggedInstance: Instance)
    ZiplineTrack.cleanUpZiplineGroup(taggedInstance)
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
