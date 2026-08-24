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
getgenv().SaltyBootError = nil
getgenv().SaltyInitialized = false

-- Teleports reload the complete Salty stack.
getgenv().SALTY_LATEST_URL = LOADER_URL

-- Salty's bundled window is created before Spy.Init, but the original bundle
-- only exposes getgenv().Salty after Spy.Init succeeds. If Spy.Init throws,
-- the GUI remains visible while every fallback loader becomes unreachable.
-- Inject the runtime reference immediately at startup so compatibility hooks
-- can still attach to the already-created Logs/Communicator/UI state.
local source = game:HttpGet(MAIN_URL)
local marker = "wax.shared.SaltyStartTime = tick()"
local injected = marker .. "\ngetgenv().Salty = wax"
local patchedCount
source, patchedCount = source:gsub(marker, injected, 1)

if patchedCount == 0 then
    warn("Salty loader: early-runtime injection marker was not found")
end

local chunk, compileError = loadstring(source)
if not chunk then
    error("Salty loader: failed to compile Salty.luau: " .. tostring(compileError))
end

local coreOK, coreResult = xpcall(chunk, function(err)
    local traceback = debug and debug.traceback
    if typeof(traceback) == "function" then
        return traceback(tostring(err), 2)
    end
    return tostring(err)
end)

if not coreOK then
    getgenv().SaltyBootError = coreResult
    warn("[Salty Core Error] " .. tostring(coreResult))
end

-- Always try the safe transport layer, even if Spy.Init inside the bundled
-- runtime failed. At this point the window/log tables normally already exist.
local compatOK, compatError = xpcall(function()
    local compatSource = game:HttpGet(COMPAT_URL)
    local compatChunk, compatCompileError = loadstring(compatSource)
    if not compatChunk then
        error(compatCompileError)
    end
    return compatChunk()
end, function(err)
    return tostring(err)
end)

if not compatOK then
    warn("Salty: safe compatibility hooks failed to load: " .. tostring(compatError))
end

-- Surface a useful status without modifying the game tree.
local runtime = getgenv().Salty
if runtime and runtime.shared and runtime.shared.Sonner then
    if coreOK then
        pcall(runtime.shared.Sonner.success, "Salty runtime + fallback hooks loaded")
    elseif compatOK then
        pcall(runtime.shared.Sonner.warning or runtime.shared.Sonner.info, "Salty core spy failed; fallback hooks recovered")
    end
end

return coreOK and coreResult or runtime
