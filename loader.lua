local BASE = "https://raw.githubusercontent.com/MrRos3/Salty/main/"
local MAIN_URL = BASE .. "Salty.luau"
local COMPAT_URL = BASE .. "compat.lua"
local LOADER_URL = BASE .. "loader.lua"

-- Teleports should reload the complete Salty stack, not only the bundled core.
getgenv().SALTY_LATEST_URL = LOADER_URL

local result = loadstring(game:HttpGet(MAIN_URL))()

local ok, err = pcall(function()
    loadstring(game:HttpGet(COMPAT_URL))()
end)

if not ok then
    warn("Salty: compatibility layer failed to load: " .. tostring(err))
end

return result
