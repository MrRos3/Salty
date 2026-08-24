local BASE = "https://raw.githubusercontent.com/MrRos3/Salty/main/"
local MAIN_URL = BASE .. "Salty.luau"
local COMPAT_URL = BASE .. "compat.lua"
local LOADER_URL = BASE .. "loader.lua"

-- Remove an older/stale Salty instance before installing the current build.
local oldSalty = getgenv().Salty
if oldSalty and oldSalty.shared and typeof(oldSalty.shared.Unload) == "function" then
    pcall(oldSalty.shared.Unload)
end

getgenv().SaltySafeCompatInstalled = nil
getgenv().SaltySafeCompat = nil
getgenv().SaltyInitialized = false

-- Teleports reload the complete Salty stack.
getgenv().SALTY_LATEST_URL = LOADER_URL

local result = loadstring(game:HttpGet(MAIN_URL))()

local ok, err = pcall(function()
    loadstring(game:HttpGet(COMPAT_URL))()
end)
if not ok then
    warn("Salty: safe compatibility hooks failed to load: " .. tostring(err))
end

return result
