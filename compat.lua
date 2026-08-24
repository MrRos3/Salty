-- Salty safe compatibility spy v2
-- Captures remotes and bypasses the old Cobalt Log:Call black hole when needed.

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
    local group = shared.Logs and shared.Logs[kind]
    if not group then
        return nil
    end

    local log = group[instance]
    if not log and shared.NewLog then
        local ok, created = pcall(shared.NewLog, instance, kind, method, origin)
        if ok then
            log = created
        end
    end
    return log
end

local function callCount(kind, instance)
    local group = shared.Logs and shared.Logs[kind]
    local log = group and group[instance]
    return log and log.Calls and #log.Calls or 0
end

local function directAppend(log, info)
    log.Calls = log.Calls or {}
    log.GameCalls = log.GameCalls or {}

    info.CreationTime = info.CreationTime or tick()

    local index = #log.Calls + 1
    log.Calls[index] = info

    if not info.IsExecutor then
        table.insert(log.GameCalls, index)
    end

    if shared.Communicator then
        pcall(function()
            shared.Communicator:Fire(log.Instance, log.Type, index)
        end)
    end

    return true
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
        CreationTime = tick(),
    }

    if log.Blocked then
        local shouldLogBlocked = false
        if shared.SaveManager and shared.SaveManager.GetState then
            local ok, state = pcall(shared.SaveManager.GetState, shared.SaveManager, "LogBlockedRemotes", false)
            shouldLogBlocked = ok and state == true
        end

        if shouldLogBlocked then
            info.Blocked = true
        else
            return true
        end
    end

    local before = #log.Calls
    if typeof(log.Call) == "function" then
        pcall(log.Call, log, info)
    end

    if #log.Calls <= before then
        return directAppend(log, info)
    end

    return true
end

-- Restore the original Cobalt/Salty prototype hooks before installing ours.
if shared.Hooks then
    local restoreNames = {
        FireServer = true,
        InvokeServer = true,
        fireServer = true,
        invokeServer = true,
    }

    local remove = {}
    for hooked, original in pairs(shared.Hooks) do
        local name
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
            table.insert(remove, hooked)
        end
    end

    for _, hooked in ipairs(remove) do
        shared.Hooks[hooked] = nil
    end
end

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

local wrapClosure = typeof(newcclosure) == "function" and newcclosure or function(fn)
    return fn
end

-- Core Salty stores the original __namecall function here after installing its hook.
local baseNamecall = typeof(shared.NamecallHook) == "function" and shared.NamecallHook or nil
local installedNamecall = false

local safeNamecall
safeNamecall = wrapClosure(function(self, ...)
    local method
    if typeof(getnamecallmethod) == "function" then
        local ok, value = pcall(getnamecallmethod)
        if ok then
            method = value
        end
    end

    local isRemote = typeof(self) == "Instance" and outgoingClasses[self.ClassName] and outgoingMethods[method]
    if not isRemote or typeof(baseNamecall) ~= "function" then
        return baseNamecall(self, ...)
    end

    local origin = safeCallingScript()
    local args = table.pack(...)
    local executorCall = safeCheckCaller()
    local before = callCount("Outgoing", self)

    local log = ensureLog(self, "Outgoing", method, origin)
    if log and log.Blocked then
        addCall(self, "Outgoing", method, args, origin, executorCall)
        return nil
    end

    local result = table.pack(baseNamecall(self, ...))

    if callCount("Outgoing", self) <= before then
        addCall(self, "Outgoing", method, args, origin, executorCall)
    end

    return table.unpack(result, 1, result.n)
end)

if typeof(hookmetamethod) == "function" then
    local previous
    local ok = pcall(function()
        previous = hookmetamethod(game, "__namecall", safeNamecall)
    end)

    if ok then
        if typeof(baseNamecall) ~= "function" and typeof(previous) == "function" then
            baseNamecall = previous
        end
        installedNamecall = typeof(baseNamecall) == "function"
    end
end

if not installedNamecall and typeof(getrawmetatable) == "function" and typeof(setreadonly) == "function" then
    pcall(function()
        local mt = getrawmetatable(game)
        if typeof(baseNamecall) ~= "function" then
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

-- Also hook direct method calls such as RemoteEvent.FireServer(remote, ...).
local function installPrototypeHook(className, method)
    if typeof(hookfunction) ~= "function" then
        return false
    end

    local ok = pcall(function()
        local temp = Instance.new(className)
        local target = temp[method]
        temp:Destroy()

        local original
        original = hookfunction(target, wrapClosure(function(self, ...)
            if typeof(self) ~= "Instance" or self.ClassName ~= className then
                return original(self, ...)
            end

            local origin = safeCallingScript()
            local args = table.pack(...)
            local executorCall = safeCheckCaller()
            local before = callCount("Outgoing", self)

            local log = ensureLog(self, "Outgoing", method, origin)
            if log and log.Blocked then
                addCall(self, "Outgoing", method, args, origin, executorCall)
                return nil
            end

            local result = table.pack(original(self, ...))

            if callCount("Outgoing", self) <= before then
                addCall(self, "Outgoing", method, args, origin, executorCall)
            end

            return table.unpack(result, 1, result.n)
        end))
    end)

    return ok
end

local prototypeHooks = 0
if installPrototypeHook("RemoteEvent", "FireServer") then prototypeHooks += 1 end
if installPrototypeHook("RemoteFunction", "InvokeServer") then prototypeHooks += 1 end
if installPrototypeHook("UnreliableRemoteEvent", "FireServer") then prototypeHooks += 1 end

-- Incoming RemoteEvent observation.
local attached = setmetatable({}, { __mode = "k" })
local incomingSeen = setmetatable({}, { __mode = "k" })
local attachedCount = 0

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

        local previous = incomingSeen[instance] or 0
        local current = callCount("Incoming", instance)

        if current <= previous then
            addCall(instance, "Incoming", "OnClientEvent", table.pack(...), nil, false)
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

    if ok and connection then
        attachedCount += 1
        if shared.Connect then
            pcall(shared.Connect, connection)
        end
    end
end

for _, instance in ipairs(game:GetDescendants()) do
    attachIncoming(instance)
end

local descendantConnection = game.DescendantAdded:Connect(attachIncoming)
if shared.Connect then
    pcall(shared.Connect, descendantConnection)
end

local actorCount = 0
pcall(function()
    actorCount = #game:QueryDescendants("Actor")
end)

getgenv().SaltySafeCompat = {
    OutgoingHook = installedNamecall,
    PrototypeHooks = prototypeHooks,
    IncomingConnections = attachedCount,
    ActorCount = actorCount,
    ActorsEnabled = shared.ActorsEnabled == true,
}

if shared.Sonner then
    pcall(shared.Sonner.success, string.format(
        "Salty hooks ready — incoming:%d outgoing:%s/%d",
        attachedCount,
        installedNamecall and "yes" or "no",
        prototypeHooks
    ))
end
