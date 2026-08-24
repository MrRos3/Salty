-- Salty public entrypoint
-- The bundled core keeps Cobalt-compatible internal runtime identifiers because
-- the original spy engine depends on them on some executors. Public UI remains Salty.

local BASE = "https://raw.githubusercontent.com/MrRos3/Salty/main/"
local CORE_URL = BASE .. "SaltyCore.luau"

-- The original engine reads this internal compatibility variable for teleport.
getgenv().COBALT_LATEST_URL = BASE .. "Salty.luau"

local source = game:HttpGet(CORE_URL)

-- Restore ONLY the original engine namespace before compiling. SaltyCore.luau
-- remains Salty-branded in the repository; this conversion exists solely at
-- runtime so the proven Cobalt hook engine executes with its original namespace.
source = source
    :gsub("SALTY", "COBALT")
    :gsub("Salty", "Cobalt")
    :gsub("salty", "cobalt")

-- Safe public-facing branding. Do not rename the internal runtime namespace.
source = source
    :gsub('Name = "Cobalt",\n\tResetOnSpawn', 'Name = "Salty",\n\tResetOnSpawn')
    :gsub('Text = "Cobalt",\n\t\tTextSize = 18', 'Text = "Salty",\n\t\tTextSize = 18')
    :gsub('Title = "Cobalt"', 'Title = "Salty"')
    :gsub('Cobalt_Session_', 'Salty_Session_')
    :gsub('<title>Cobalt %- Session Viewer</title>', '<title>Salty - Session Viewer</title>')
    :gsub('<span>Cobalt</span>', '<span>Salty</span>')
    :gsub('https://github.com/MrRos3/Cobalt', 'https://github.com/MrRos3/Salty')
    :gsub('https://raw.githubusercontent.com/MrRos3/Cobalt/main/Cobalt.luau', BASE .. 'Salty.luau')

local chunk, compileError = loadstring(source)
if not chunk then
    error("Salty core compile error: " .. tostring(compileError))
end

local result = chunk()

-- Public alias. The engine intentionally keeps getgenv().Cobalt internally.
local runtime = getgenv().Cobalt
if runtime then
    getgenv().Salty = runtime

    local shared = runtime.shared
    if shared and shared.ScreenGui then
        shared.ScreenGui.Name = "Salty"

        -- Catch any title text that was constructed through a code path not
        -- covered by the exact source replacements above.
        for _, object in ipairs(shared.ScreenGui:GetDescendants()) do
            if (object:IsA("TextLabel") or object:IsA("TextButton")) and object.Text == "Cobalt" then
                object.Text = "Salty"
            end
        end
    end
end

return result
