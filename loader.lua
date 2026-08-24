local BASE = "https://raw.githubusercontent.com/MrRos3/Salty/main/"
local MAIN_URL = BASE .. "Salty.luau"
local COMPAT_URL = BASE .. "compat.lua"
local DIAGNOSTICS_URL = BASE .. "diagnostics.lua"
local LOADER_URL = BASE .. "loader.lua"

-- Remove an older/stale Salty instance before installing the current build.
local oldSalty = getgenv().Salty
if oldSalty and oldSalty.shared and typeof(oldSalty.shared.Unload) == "function" then
    pcall(oldSalty.shared.Unload)
end

getgenv().SaltyCompatInstalled = nil
getgenv().SaltyDiagnosticsRan = nil
getgenv().SaltyDiagnostics = nil
getgenv().SaltyInitialized = false

-- Teleports reload the complete Salty stack.
getgenv().SALTY_LATEST_URL = LOADER_URL

local result = loadstring(game:HttpGet(MAIN_URL))()

local compatOK, compatErr = pcall(function()
    loadstring(game:HttpGet(COMPAT_URL))()
end)
if not compatOK then
    warn("Salty: compatibility layer failed to load: " .. tostring(compatErr))
end

local diagOK, diagErr = pcall(function()
    loadstring(game:HttpGet(DIAGNOSTICS_URL))()
end)
if not diagOK then
    warn("Salty: diagnostics failed to load: " .. tostring(diagErr))
end

return result
