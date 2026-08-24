local BASE = "https://raw.githubusercontent.com/MrRos3/Salty/main/"
local MAIN_URL = BASE .. "Salty.luau"
local COMPAT_URL = BASE .. "compat.lua"
local LOADER_URL = BASE .. "loader.lua"

-- Clean up an older Salty instance if one is already loaded.
local oldSalty = getgenv().Salty
if oldSalty and oldSalty.shared and typeof(oldSalty.shared.Unload) == "function" then
    pcall(oldSalty.shared.Unload)
end

getgenv().SaltySafeCompatInstalled = nil
getgenv().SaltySafeCompat = nil
getgenv().SaltyInitialized = false
getgenv().SALTY_LATEST_URL = LOADER_URL

-- Load Salty normally. Do not rewrite the bundled source during startup.
local source = game:HttpGet(MAIN_URL)
local chunk, compileError = loadstring(source)
if not chunk then
    warn("Salty: failed to compile main runtime: " .. tostring(compileError))
    return
end

local ok, result = pcall(chunk)
if not ok then
    warn("[Salty Core Error] " .. tostring(result))
    return
end

-- Only attach the compatibility layer after the normal runtime has fully loaded.
local compatOK, compatError = pcall(function()
    local compatSource = game:HttpGet(COMPAT_URL)
    local compatChunk, compatCompileError = loadstring(compatSource)
    if not compatChunk then
        error(compatCompileError)
    end
    compatChunk()
end)

if not compatOK then
    warn("Salty: compatibility layer failed: " .. tostring(compatError))
end

return result
