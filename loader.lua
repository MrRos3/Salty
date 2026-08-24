local BASE = "https://raw.githubusercontent.com/MrRos3/Salty/main/"
local MAIN_URL = BASE .. "Salty.luau"
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

-- Load the bundled Salty runtime only. No extra remote wrappers are installed here,
-- so RemoteFunction return values remain exactly as the game returned them.
local result = loadstring(game:HttpGet(MAIN_URL))()

-- Diagnostics only observe Salty's own log state and executor support.
local diagOK, diagErr = pcall(function()
    loadstring(game:HttpGet(DIAGNOSTICS_URL))()
end)
if not diagOK then
    warn("Salty: diagnostics failed to load: " .. tostring(diagErr))
end

return result
