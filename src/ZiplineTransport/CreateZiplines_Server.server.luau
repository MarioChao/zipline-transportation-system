--!strict

---------- Services ----------

local Players = game:GetService("Players")


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

local isValidPart_function

local getConfigFromInstance
local setUpContainer
local cleanUpContainer


----- Valid part -----

isValidPart_function = function(part: BasePart, ziplineConfig: ZiplineTrack.ZiplineConfig)
    local assemblyRootPart = part.AssemblyRootPart
    local isNotPlayer = not Players:GetPlayerFromCharacter(assemblyRootPart and assemblyRootPart.Parent)
    return isNotPlayer
end


----- Container mechanic -----

getConfigFromInstance = function(configInstance: Instance): ZiplineTagConfig
    return {}
end

setUpContainer = function(container: Instance, config: ZiplineTagConfig)
    Globals.container_isUnderWorkspace[container] = container:IsDescendantOf(workspace)
    if Globals.container_isUnderWorkspace[container] then
        ZiplineTrack.setUpZiplineGroup(container, isValidPart_function, false)
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
                ZiplineTrack.setUpZiplineGroup(container, isValidPart_function, false)
            else
                ZiplineTrack.cleanUpZiplineGroup(container)
            end
        end
        Globals.container_isUnderWorkspace[container] = isUnderWorkspace
    end)
end

cleanUpContainer = function(container: Instance)
    ZiplineTrack.cleanUpZiplineGroup(container)
end


---------- Main ----------

local function main()
    local mechanic = ContainerMechanic.new(Constants.ziplineConfigTag)
    mechanic:setFunction_getConfigFromInstance(getConfigFromInstance)
    mechanic:setFunction_setUpContainer(setUpContainer)
    mechanic:setFunction_cleanUpContainer(cleanUpContainer)
    mechanic:run()
end


---------- Calling function ----------

main()
