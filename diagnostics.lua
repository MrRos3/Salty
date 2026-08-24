-- Salty passive runtime diagnostics
-- Read-only: does not create remotes, change FFlags, hook functions, or touch the game tree.

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

local executorName = "Unknown"
pcall(function()
    executorName = identifyexecutor()
end)

local actorCount = 0
pcall(function()
    actorCount = #game:QueryDescendants("Actor")
end)

local parallelFlag = "N/A"
pcall(function()
    if typeof(getfflag) == "function" then
        parallelFlag = tostring(getfflag("DebugRunParallelLuaOnMainThread"))
    end
end)

local outgoingCount = 0
local incomingCount = 0
pcall(function()
    for _, log in pairs(shared.Logs.Outgoing or {}) do
        outgoingCount += log.Calls and #log.Calls or 0
    end
    for _, log in pairs(shared.Logs.Incoming or {}) do
        incomingCount += log.Calls and #log.Calls or 0
    end
end)

local function mark(value)
    return value and "YES" or "NO"
end

local details = table.concat({
    "Executor: " .. tostring(executorName),
    "Outgoing calls seen: " .. tostring(outgoingCount),
    "Incoming calls seen: " .. tostring(incomingCount),
    "hookmetamethod: " .. mark(support("hookmetamethod")),
    "hookfunction: " .. mark(support("hookfunction")),
    "getconnections: " .. mark(support("getconnections")),
    "run_on_actor: " .. mark(support("run_on_actor")),
    "Actors found: " .. tostring(actorCount),
    "Parallel-on-main flag: " .. tostring(parallelFlag),
}, " | ")

warn("[Salty Diagnostics] " .. details)

getgenv().SaltyDiagnostics = {
    Executor = executorName,
    OutgoingCount = outgoingCount,
    IncomingCount = incomingCount,
    HookMetaMethod = support("hookmetamethod"),
    HookFunction = support("hookfunction"),
    GetConnections = support("getconnections"),
    RunOnActor = support("run_on_actor"),
    Actors = actorCount,
    ParallelFlag = parallelFlag,
}
