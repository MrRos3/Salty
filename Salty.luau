local BASE = "https://raw.githubusercontent.com/MrRos3/Salty/main/"
local CORE_URL = BASE .. "SaltyCore.luau"
local INTERNAL = string.char(67, 111, 98, 97, 108, 116)
local UPPER = INTERNAL:upper()
local LOWER = INTERNAL:lower()

getgenv()[UPPER .. "_LATEST_URL"] = BASE .. "Salty.luau"

local source = game:HttpGet(CORE_URL)
source = source
    :gsub("SALTY", UPPER)
    :gsub("Salty", INTERNAL)
    :gsub("salty", LOWER)

source = source
    :gsub('Name = "' .. INTERNAL .. '",\n\tResetOnSpawn', 'Name = "Salty",\n\tResetOnSpawn')
    :gsub('Text = "' .. INTERNAL .. '",\n\t\tTextSize = 18', 'Text = "Salty",\n\t\tTextSize = 18')
    :gsub('Title = "' .. INTERNAL .. '"', 'Title = "Salty"')
    :gsub(INTERNAL .. '_Session_', 'Salty_Session_')
    :gsub('<title>' .. INTERNAL .. ' %- Session Viewer</title>', '<title>Salty - Session Viewer</title>')
    :gsub('<span>' .. INTERNAL .. '</span>', '<span>Salty</span>')
    :gsub('https://github.com/MrRos3/' .. INTERNAL, 'https://github.com/MrRos3/Salty')
    :gsub('https://raw.githubusercontent.com/MrRos3/' .. INTERNAL .. '/main/' .. INTERNAL .. '.luau', BASE .. 'Salty.luau')

local chunk, compileError = loadstring(source)
if not chunk then
    error("Salty core compile error: " .. tostring(compileError))
end

local result = chunk()
local runtime = getgenv()[INTERNAL]

if runtime then
    getgenv().Salty = runtime
    local shared = runtime.shared

    if shared and shared.ScreenGui then
        shared.ScreenGui.Name = "Salty"

        for _, object in ipairs(shared.ScreenGui:GetDescendants()) do
            if (object:IsA("TextLabel") or object:IsA("TextButton")) and object.Text == INTERNAL then
                object.Text = "Salty"
            end
        end
    end
end

return result
