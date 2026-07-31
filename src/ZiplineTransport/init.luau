--!strict

-- Zipline Transport


---------- Imports ----------

local ZiplineTrack = require(script:WaitForChild("ZiplineTrack"))


---------- Module ----------

local Module = {}


----- Module fields -----

Module.ZiplineTrack = ZiplineTrack


---------- Return module ----------

table.freeze(Module)
return Module
