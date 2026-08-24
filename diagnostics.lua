-- Salty runtime diagnostics / self-test
-- Verifies whether the core spy actually records local test traffic in this executor.

if getgenv().SaltyDiagnosticsRan then
    return
end
getgenv().SaltyDiagnosticsRan = true

local Runtime = getgenv().Salty
if not Runtime or not Runtime.shared then
    warn("Salty diagnostics: runtime is not initialized")
    return
end

local shared = Runtime.shared
local Support = shared.ExecutorSupport or {}

local function support(name)
    local item = Support[name]
    return item and item.IsWorking == true or false
end

local function count(kind, instance)
    local group = shared.Logs and shared.Logs[kind]
    local log = group and group[instance]
    return log and log.Calls and #log.Calls or 0
end

local executorName = "Unknown"
pcall(function()
    executorName = identifyexecutor()
end)

local actorCount = 0
pcall(function()
    actorCount = #game:QueryDescendants("Actor")
end)

local parallelFlag
pcall(function()
    if typeof(getfflag) == "function" then
        parallelFlag = getfflag("DebugRunParallelLuaOnMainThread")
    end
end)

-- Proactively request the same Actor compatibility mode used by the original spy.
-- If Roblox already created Actor VMs, the user must rejoin once for this to take effect.
local actorFixChanged = false
if actorCount > 0 and not support("run_on_actor") and typeof(setfflag) == "function" then
    local current = tostring(parallelFlag):lower()
    if current ~= "true" then
        local ok = pcall(setfflag, "DebugRunParallelLuaOnMainThread", "true")
        actorFixChanged = ok
    end
end

local testRemote = Instance.new("RemoteEvent")
testRemote.Name = "SaltyHookSelfTest"
testRemote.Parent = game:GetService("ReplicatedStorage")

-- Give the Incoming hook's DescendantAdded listener a moment to attach.
task.wait(0.15)

local outgoingBefore = count("Outgoing", testRemote)
local incomingBefore = count("Incoming", testRemote)

pcall(function()
    testRemote:FireServer("SaltyHookSelfTest")
end)

local firedIncoming = false
if typeof(firesignal) == "function" then
    firedIncoming = pcall(firesignal, testRemote.OnClientEvent, "SaltyHookSelfTest")
end

task.wait(0.3)

local outgoingOK = count("Outgoing", testRemote) > outgoingBefore
local incomingOK = firedIncoming and count("Incoming", testRemote) > incomingBefore

local function mark(value)
    return value and "YES" or "NO"
end

local details = table.concat({
    "Executor: " .. tostring(executorName),
    "Outgoing self-test: " .. mark(outgoingOK),
    "Incoming self-test: " .. (typeof(firesignal) == "function" and mark(incomingOK) or "N/A (no firesignal)"),
    "hookmetamethod: " .. mark(support("hookmetamethod")),
    "hookfunction: " .. mark(support("hookfunction")),
    "getconnections: " .. mark(support("getconnections")),
    "run_on_actor: " .. mark(support("run_on_actor")),
    "Actors found: " .. tostring(actorCount),
    "Parallel-on-main flag: " .. tostring(parallelFlag),
}, " | ")

warn("[Salty Diagnostics] " .. details)

if shared.Sonner then
    if outgoingOK and (incomingOK or typeof(firesignal) ~= "function") then
        pcall(shared.Sonner.success, "Salty self-test passed — hook engine is working")
    elseif actorFixChanged then
        pcall(shared.Sonner.warning or shared.Sonner.info, "Salty enabled Actor compatibility — rejoin once, then run the loader again")
    else
        pcall(shared.Sonner.error or shared.Sonner.warning or shared.Sonner.info, "Salty hook self-test FAILED — check console for [Salty Diagnostics]")
    end
end

-- Also expose the result so it is easy to inspect from an executor console.
getgenv().SaltyDiagnostics = {
    Executor = executorName,
    Outgoing = outgoingOK,
    Incoming = incomingOK,
    IncomingTestAvailable = typeof(firesignal) == "function",
    HookMetaMethod = support("hookmetamethod"),
    HookFunction = support("hookfunction"),
    GetConnections = support("getconnections"),
    RunOnActor = support("run_on_actor"),
    Actors = actorCount,
    ParallelFlag = parallelFlag,
    ActorFixChanged = actorFixChanged,
}

task.delay(2, function()
    pcall(function()
        testRemote:Destroy()
    end)
end)
