-- Salty public entrypoint
-- Stable core UI/runtime lives in SaltyCore.luau.

local BASE = "https://raw.githubusercontent.com/MrRos3/Salty/main/"
local CORE_URL = BASE .. "SaltyCore.luau"
local COMPAT_URL = BASE .. "compat.lua"

-- Every execution gets a fresh transport install. Previous test builds could
-- leave this flag behind and make compat.lua return immediately.
getgenv().SaltySafeCompatInstalled = nil
getgenv().SaltySafeCompat = nil

-- Start the repair watcher BEFORE the bundled core. This way the compatibility
-- transport is installed as soon as the core exposes its Logs/Communicator,
-- rather than waiting for every optional subsystem to finish first.
task.spawn(function()
    local deadline = tick() + 20

    repeat
        local runtime = getgenv().Salty
        local shared = runtime and runtime.shared

        if shared and shared.Logs and shared.Communicator and shared.NewLog then
            local ok, err = pcall(function()
                local source = game:HttpGet(COMPAT_URL)
                local chunk, compileError = loadstring(source)
                if not chunk then
                    error(compileError)
                end
                chunk()
            end)

            if not ok then
                warn("[Salty Remote Hooks] " .. tostring(err))
            end
            return
        end

        task.wait(0.05)
    until tick() >= deadline

    warn("[Salty Remote Hooks] runtime was not exposed within 20 seconds")
end)

local coreSource = game:HttpGet(CORE_URL)
local coreChunk, coreCompileError = loadstring(coreSource)
if not coreChunk then
    error("Salty core compile error: " .. tostring(coreCompileError))
end

local ok, result = xpcall(coreChunk, function(err)
    local message = tostring(err)
    if debug and typeof(debug.traceback) == "function" then
        message = debug.traceback(message, 2)
    end
    return message
end)

if not ok then
    warn("[Salty Core Error] " .. tostring(result))
    return nil
end

return result
