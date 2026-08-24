-- Salty safe compatibility spy
-- Replaces only the fragile transport hooks while preserving Salty's UI/log objects.

if getgenv().SaltySafeCompatInstalled then
    return
end

local Runtime = getgenv().Salty
if not Runtime or not Runtime.shared then
    warn("Salty safe compat: runtime not initialized")
    return
end

local shared = Runtime.shared
getgenv().SaltySafeCompatInstalled = true

local function safeCall(fn, ...)
    if typeof(fn) ~= "function" then
        return false, nil
    end
    return pcall(fn, ...)
end

local function safeCallingScript()
    if typeof(getcallingscript) ~= "function" then
        return nil
    end
    local ok, result = pcall(getcallingscript)
    return ok and result or nil
end

local function safeCheckCaller()
    if typeof(checkcaller) ~= "function" then
        return false
    end
    local ok, result = pcall(checkcaller)
    return ok and result == true or false
end

local function shouldIgnore(instance, origin)
    if not shared.ShouldIgnore then
        return false
    end
    local ok, result = pcall(shared.ShouldIgnore, instance, origin)
    return ok and result == true or false
end

local function ensureLog(instance, kind, method, origin)
    local logs = shared.Logs and shared.Logs[kind]
    if not logs then
        return nil
    end

    local log = logs[instance]
    if not log and shared.NewLog then
        local ok, created = pcall(shared.NewLog, instance, kind, method, origin)
        if ok then
            log = created
        end
    end
    return log
end

local function addCall(instance, kind, method, args, origin, isExecutor)
    if shared.Unloaded or shouldIgnore(instance, origin) then
        return false
    end

    local log = ensureLog(instance, kind, method, origin)
    if not log or log.Ignored then
        return false
    end

    local info = {
        Arguments = args,
        Origin = origin,
        Function = nil,
        Line = nil,
        Source = "[Salty Safe Compat]",
        IsExecutor = isExecutor == true,
    }

    if log.Blocked then
        local saveManager = shared.SaveManager
        local shouldLogBlocked = false
        if saveManager and saveManager.GetState then
            local ok, state = pcall(saveManager.GetState, saveManager, "LogBlockedRemotes", false)
            shouldLogBlocked = ok and state == true
        end
        if shouldLogBlocked then
            info.Blocked = true
            pcall(log.Call, log, info)
        end
        return true
    end

    return pcall(log.Call, log, info)
end

local function callCount(kind, instance)
    local group = shared.Logs and shared.Logs[kind]
    local log = group and group[instance]
    return log and log.Calls and #log.Calls or 0
end

-- Restore Cobalt/Salty's prototype hooks for network methods so our single
-- namecall transport is not stacked on top of several function hooks.
if shared.Hooks then
    local restoreNames = {
        FireServer = true,
        InvokeServer = true,
        fireServer = true,
        invokeServer = true,
    }

    local toRemove = {}
    for hooked, original in pairs(shared.Hooks) do
        local name = nil
        pcall(function()
            name = debug.info(hooked, "n")
        end)

        if restoreNames[name] then
            local restored = false
            if typeof(restorefunction) == "function" then
                restored = pcall(restorefunction, hooked)
            end
            if not restored and typeof(hookfunction) == "function" and typeof(original) == "function" then
                pcall(hookfunction, hooked, original)
            end
            table.insert(toRemove, hooked)
        end
    end

    for _, hooked in ipairs(toRemove) do
        shared.Hooks[hooked] = nil
    end
end

-- OUTGOING
-- Bypass the old Cobalt namecall wrapper completely when its original function
-- reference is available. This avoids executor-specific metadata code from
-- preventing the actual network call or logger from running.
local outgoingClasses = {
    RemoteEvent = true,
    RemoteFunction = true,
    UnreliableRemoteEvent = true,
}

local outgoingMethods = {
    FireServer = true,
    fireServer = true,
    InvokeServer = true,
    invokeServer = true,
}

local baseNamecall = typeof(shared.NamecallHook) == "function" and shared.NamecallHook or nil
local installedNamecall = false
local wrapClosure = typeof(newcclosure) == "function" and newcclosure or function(fn)
    return fn
end

local safeNamecall
safeNamecall = wrapClosure(function(self, ...)
    local method = nil
    if typeof(getnamecallmethod) == "function" then
        local ok, value = pcall(getnamecallmethod)
        if ok then
            method = value
        end
    end

    local isRemote = typeof(self) == "Instance" and outgoingClasses[self.ClassName] and outgoingMethods[method]
    if not isRemote then
        return baseNamecall(self, ...)
    end

    local origin = safeCallingScript()
    local args = table.pack(...)
    local isExecutor = safeCheckCaller()
    local before = callCount("Outgoing", self)

    local log = ensureLog(self, "Outgoing", method, origin)
    if log and log.Blocked then
        addCall(self, "Outgoing", method, args, origin, isExecutor)
        return nil
    end

    local result = table.pack(baseNamecall(self, ...))

    -- If the original Salty path did not log synchronously, write the fallback.
    if callCount("Outgoing", self) <= before then
        addCall(self, "Outgoing", method, args, origin, isExecutor)
    end

    return table.unpack(result, 1, result.n)
end)

if typeof(hookmetamethod) == "function" then
    local previous
    local ok = pcall(function()
        previous = hookmetamethod(game, "__namecall", safeNamecall)
    end)
    if ok then
        if not baseNamecall and typeof(previous) == "function" then
            baseNamecall = previous
        end
        installedNamecall = typeof(baseNamecall) == "function"
    end
end

if not installedNamecall and typeof(getrawmetatable) == "function" and typeof(setreadonly) == "function" then
    pcall(function()
        local mt = getrawmetatable(game)
        if not baseNamecall then
            baseNamecall = rawget(mt, "__namecall")
        end
        if typeof(baseNamecall) == "function" then
            setreadonly(mt, false)
            rawset(mt, "__namecall", safeNamecall)
            setreadonly(mt, true)
            installedNamecall = true
        end
    end)
end

-- INCOMING
-- Direct RemoteEvent observation requires none of Cobalt's getconnections,
-- getscriptfromthread, isexecutorclosure, or callback-detour machinery.
local attached = setmetatable({}, { __mode = "k" })
local incomingSeen = setmetatable({}, { __mode = "k" })

local function attachIncoming(instance)
    if attached[instance] or typeof(instance) ~= "Instance" then
        return
    end

    local className = instance.ClassName
    if className ~= "RemoteEvent" and className ~= "UnreliableRemoteEvent" then
        return
    end

    attached[instance] = true
    incomingSeen[instance] = callCount("Incoming", instance)

    local callback
    callback = function(...)
        if shared.Unloaded then
            return
        end

        local args = table.pack(...)
        local previous = incomingSeen[instance] or 0
        local current = callCount("Incoming", instance)

        -- The original logger's connection was registered before this one. If it
        -- already recorded the event, do not duplicate it.
        if current <= previous then
            addCall(instance, "Incoming", "OnClientEvent", args, nil, false)
            current = callCount("Incoming", instance)
        end

        incomingSeen[instance] = current
    end

    if shared.IncomingLogConnectionFunctions then
        shared.IncomingLogConnectionFunctions[callback] = true
    end

    local ok, connection = pcall(function()
        return instance.OnClientEvent:Connect(callback)
    end)

    if ok and connection and shared.Connect then
        pcall(shared.Connect, connection)
    end
end

for _, instance in ipairs(game:GetDescendants()) do
    attachIncoming(instance)
end

local descendantConnection = game.DescendantAdded:Connect(attachIncoming)
if shared.Connect then
    pcall(shared.Connect, descendantConnection)
end

-- Actor/parallel Luau notice. Main-VM hooks cannot see outgoing calls executed
-- inside isolated Actor VMs unless the executor exposes actor APIs.
local actorCount = 0
pcall(function()
    actorCount = #game:QueryDescendants("Actor")
end)

if shared.Sonner then
    if installedNamecall then
        pcall(shared.Sonner.success, "Salty safe remote hooks active")
    else
        pcall(shared.Sonner.warning or shared.Sonner.info, "Salty: outgoing hook API unavailable on this executor")
    end

    if actorCount > 0 and not shared.ActorsEnabled then
        pcall(shared.Sonner.warning or shared.Sonner.info, "Salty: Actor VMs detected; outgoing Actor traffic needs executor actor support")
    end
end

getgenv().SaltySafeCompat = {
    OutgoingHook = installedNamecall,
    ActorCount = actorCount,
    ActorsEnabled = shared.ActorsEnabled == true,
}
