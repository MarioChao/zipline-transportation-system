--!strict

---------- Services ----------

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")


---------- Imports ----------

local ZiplineTrack = require(script.Parent.ZiplineTrack)


---------- Constants ----------

local Constants = {}
Constants.ziplineGroupTag = "ZiplineGroup"


---------- Local functions ----------

local isValidPart_function

local setUpTagged
local cleanUpTagged


----- Valid part -----

isValidPart_function = function(part: BasePart)
    local assemblyRootPart = part.AssemblyRootPart
    local isNotPlayer = not Players:GetPlayerFromCharacter(assemblyRootPart and assemblyRootPart.Parent)
    return isNotPlayer
end


----- Tag -----

setUpTagged = function(taggedInstance: Instance)
    ZiplineTrack.setUpZiplineGroup(taggedInstance, isValidPart_function, true)
end

cleanUpTagged = function(taggedInstance: Instance)
    ZiplineTrack.cleanUpZiplineGroup(taggedInstance)
end


---------- Main ----------

local function main()
    CollectionService:GetInstanceAddedSignal(Constants.ziplineGroupTag):Connect(setUpTagged)
    CollectionService:GetInstanceRemovedSignal(Constants.ziplineGroupTag):Connect(cleanUpTagged)
    for _, tagged in CollectionService:GetTagged(Constants.ziplineGroupTag) do
        setUpTagged(tagged)
    end
end


---------- Calling function ----------

main()
