-- Salty compatibility hooks
-- Fallback logger for executors where the bundled hook path stays silent.

if getgenv().SaltyCompatInstalled then
    return
end

local Salty = getgenv().Salty
if not Salty or not Salty.shared then
    warn("Salty compat: main runtime is not initialized")
    return
end

local shared = Salty.shared
getgenv().SaltyCompatInstalled = true

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

local function getLogCount(kind, instance)
    local group = shared.Logs and shared.Logs[kind]
    local log = group and group[instance]
    return log and log.Calls and #log.Calls or 0, log
end

local function ensureLog(instance, kind, method, origin)
    local group = shared.Logs and shared.Logs[kind]
    if not group then
        return nil
    end

    local log = group[instance]
    if not log and shared.NewLog then
        local ok, result = pcall(shared.NewLog, instance, kind, method, origin)
        if ok then
            log = result
        end
    end
    return log
end

local function addCompatCall(instance, kind, method, args, origin, isExecutor)
    if shared.Unloaded or shouldIgnore(instance, origin) then
        return
    end

    local log = ensureLog(instance, kind, method, origin)
    if not log or log.Ignored or log.Blocked then
        return
    end

    pcall(function()
        log:Call({
            Arguments = args,
            Origin = origin,
            Function = nil,
            Line = 0,
            Source = "[Salty Compat]",
            IsExecutor = isExecutor == true,
        })
    end)
end

-- Incoming RemoteEvent fallback.
-- Connections registered by the bundled logger run first. We track the last
-- observed call count so this only writes when the normal logger stayed silent.
local incomingSeen = setmetatable({}, { __mode = "k" })
local attached = setmetatable({}, { __mode = "k" })

local function attachIncoming(instance)
    if attached[instance] then
        return
    end

    local className = instance.ClassName
    if className ~= "RemoteEvent" and className ~= "UnreliableRemoteEvent" then
        return
    end

    attached[instance] = true
    local count = getLogCount("Incoming", instance)
    incomingSeen[instance] = count

    local connection = instance.OnClientEvent:Connect(function(...)
        if shared.Unloaded then
            return
        end

        local args = table.pack(...)
        local current = getLogCount("Incoming", instance)
        local previous = incomingSeen[instance] or 0

        if current > previous then
            incomingSeen[instance] = current
            return
        end

        addCompatCall(instance, "Incoming", "OnClientEvent", args, nil, false)
        incomingSeen[instance] = getLogCount("Incoming", instance)
    end)

    if shared.Connect then
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

-- Outgoing fallback. We deliberately install both a namecall wrapper and
-- prototype-function wrappers. Each waits for Salty's original hook first and
-- only writes when the normal call count did not change.
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

local function runAfterOriginal(instance, method, args, origin, isExecutor, before)
    task.defer(function()
        if shared.Unloaded then
            return
        end

        local after, log = getLogCount("Outgoing", instance)
        if after > before or (log and log.Blocked) then
            return
        end

        addCompatCall(instance, "Outgoing", method, args, origin, isExecutor)
    end)
end

local wrapClosure = typeof(newcclosure) == "function" and newcclosure or function(fn)
    return fn
end

if typeof(hookmetamethod) == "function" and typeof(getnamecallmethod) == "function" then
    pcall(function()
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", wrapClosure(function(self, ...)
            local method = getnamecallmethod()
            local className = typeof(self) == "Instance" and self.ClassName or nil

            if className and outgoingClasses[className] and outgoingMethods[method] then
                local origin = safeCallingScript()
                local args = table.pack(...)
                local before = getLogCount("Outgoing", self)
                local isExecutor = safeCheckCaller()

                local results = table.pack(oldNamecall(self, ...))
                runAfterOriginal(self, method, args, origin, isExecutor, before)
                return table.unpack(results, 1, results.n)
            end

            return oldNamecall(self, ...)
        end))
    end)
end

local function hookPrototype(className, method)
    if typeof(hookfunction) ~= "function" then
        return
    end

    pcall(function()
        local temp = Instance.new(className)
        local target = temp[method]
        temp:Destroy()

        local original
        original = hookfunction(target, wrapClosure(function(self, ...)
            if typeof(self) == "Instance" and self.ClassName == className then
                local origin = safeCallingScript()
                local args = table.pack(...)
                local before = getLogCount("Outgoing", self)
                local isExecutor = safeCheckCaller()

                local results = table.pack(original(self, ...))
                runAfterOriginal(self, method, args, origin, isExecutor, before)
                return table.unpack(results, 1, results.n)
            end

            return original(self, ...)
        end))
    end)
end

hookPrototype("RemoteEvent", "FireServer")
hookPrototype("RemoteFunction", "InvokeServer")
hookPrototype("UnreliableRemoteEvent", "FireServer")

-- Allow a clean re-install after Salty is unloaded.
if shared.Unload and not shared.__SaltyCompatWrappedUnload then
    shared.__SaltyCompatWrappedUnload = true
    local originalUnload = shared.Unload
    shared.Unload = function(...)
        getgenv().SaltyCompatInstalled = nil
        return originalUnload(...)
    end
end

if shared.Sonner and shared.Sonner.success then
    pcall(shared.Sonner.success, "Salty compatibility hooks active")
end
