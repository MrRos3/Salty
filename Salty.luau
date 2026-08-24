-- Salty public entrypoint
-- Core UI/runtime is kept byte-for-byte in SaltyCore.luau.

local BASE = "https://raw.githubusercontent.com/MrRos3/Salty/main/"

local coreSource = game:HttpGet(BASE .. "SaltyCore.luau")
local coreChunk, coreCompileError = loadstring(coreSource)
if not coreChunk then
    error("Salty core compile error: " .. tostring(coreCompileError))
end

local result = coreChunk()

-- Install the remote transport patch only after the original runtime has
-- finished and exposed getgenv().Salty. Failure here must never stop the UI.
task.defer(function()
    local ok, err = pcall(function()
        local compatSource = game:HttpGet(BASE .. "compat.lua")
        local compatChunk, compatCompileError = loadstring(compatSource)
        if not compatChunk then
            error(compatCompileError)
        end
        compatChunk()
    end)

    if not ok then
        warn("[Salty Remote Hooks] " .. tostring(err))
    end
end)

return result
