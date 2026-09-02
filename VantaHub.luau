--[[
    VantaHub
    Standalone feature interface built with MrRos3/VantaUI.

    This file does not modify VantaUI or VantaTest.
    Feature callbacks are exposed through getgenv().VantaHubHandlers so game-owned
    implementations can be attached separately without mixing them into the UI.
]]

local VantaUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/MrRos3/VantaUI/main/main.lua"
))()

assert(type(VantaUI) == "table", "[VantaHub] Failed to load VantaUI")

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

VantaUI:SetTheme("Salty Special")

local Handlers = getgenv().VantaHubHandlers or {}
local State = getgenv().VantaHubState or {}
getgenv().VantaHubHandlers = Handlers
getgenv().VantaHubState = State

local Window = VantaUI:CreateWindow({
    Title = "Vanta",
    Author = "MrRos3",
    Theme = "Salty Special",
    StartupTab = "Home",
    Size = UDim2.fromOffset(800, 540),
    Resizable = true,
    HideSearchBar = false,
    ScrollBarEnabled = true,
    NewElements = true,
    Topbar = {
        Height = 44,
        ButtonsType = "Mac",
    },
    Branding = {
        Name = "VANTA",
        Image = VantaUI.Brand.Image,
        Folder = "VantaUI",
        IconSize = 24,
        IconRadius = 7,
        OpenButtonIconRadius = 8,
        Intro = false,
    },
    OpenButton = {
        Title = "Vanta",
        Enabled = true,
        Draggable = true,
        OnlyIcon = true,
        OnlyMobile = false,
        CornerRadius = UDim.new(0, 11),
        StrokeThickness = 2,
        ImageZoom = 1,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromHex("#000000")),
            ColorSequenceKeypoint.new(1, Color3.fromHex("#000000")),
        }),
    },
    User = {
        Enabled = false,
    },
})

Window:Tag({
    Title = "HUB",
    Icon = "sparkles",
    Border = true,
})

local function notify(title, content, icon)
    VantaUI:Notify({
        Title = title or "Vanta",
        Content = content or "",
        Icon = icon or "sparkles",
        Duration = 4,
    })
end

local function runHandler(id, ...)
    local fn = Handlers[id]
    if type(fn) ~= "function" then
        return false
    end

    local ok, err = pcall(fn, ...)
    if not ok then
        warn("[VantaHub] " .. tostring(id) .. ": " .. tostring(err))
        notify("Feature error", tostring(err), "triangle-alert")
    end

    return ok
end

local function section(tab, title)
    tab:Section({
        Title = title,
        TextSize = 16,
    })
end

local function toggle(tab, id, title, desc, default)
    State[id] = default == true

    tab:Toggle({
        Title = title,
        Desc = desc,
        Default = default == true,
        Callback = function(value)
            State[id] = value == true
            runHandler(id, State[id])
        end,
    })
end

local function button(tab, id, title, desc)
    tab:Button({
        Title = title,
        Desc = desc,
        Callback = function()
            if not runHandler(id) then
                notify("Vanta", title .. " is ready for its handler.", "sparkles")
            end
        end,
    })
end

local Home = Window:Tab({ Title = "Home", Icon = "house" })
local Fishing = Window:Tab({ Title = "Auto Fishing", Icon = "fish" })
local QuestItems = Window:Tab({ Title = "Quest | Items", Icon = "scroll-text" })
local VolcanoDojo = Window:Tab({ Title = "Volcano Dojo", Icon = "flame" })
local SeaEvent = Window:Tab({ Title = "Sea Event", Icon = "waves" })
local RaceV4 = Window:Tab({ Title = "Race V4", Icon = "crown" })
local RaidFruits = Window:Tab({ Title = "Raid Fruits", Icon = "swords" })
local FruitsStock = Window:Tab({ Title = "Fruits | Stock", Icon = "apple" })
local Teleport = Window:Tab({ Title = "Teleport", Icon = "map-pin" })
local PvP = Window:Tab({ Title = "PvP Player", Icon = "users" })
local Shop = Window:Tab({ Title = "Shop", Icon = "shopping-cart" })
local Settings = Window:Tab({ Title = "Settings", Icon = "settings" })

-- Home
section(Home, "Vanta Hub")

Home:Paragraph({
    Title = "Welcome " .. tostring(LocalPlayer and LocalPlayer.DisplayName or "Player"),
    Desc = "Standalone VantaUI feature hub. Home is the default startup page.",
})

Home:Button({
    Title = "Feature status",
    Desc = "Show how many feature switches are currently enabled.",
    Callback = function()
        local total, enabled = 0, 0
        for _, value in pairs(State) do
            total += 1
            if value == true then
                enabled += 1
            end
        end
        notify("Feature status", tostring(enabled) .. " / " .. tostring(total) .. " enabled", "activity")
    end,
})

-- Auto Fishing
section(Fishing, "Fishing")
toggle(Fishing, "auto_fishing", "Auto Fishing", "Main fishing switch.", false)
toggle(Fishing, "auto_reel", "Auto Reel", "Automatic reel state.", false)
toggle(Fishing, "auto_bait", "Auto Bait", "Automatic bait state.", false)
toggle(Fishing, "fish_radar", "Fish Radar", "Fish radar display state.", false)
toggle(Fishing, "rare_fish", "Rare Fish Priority", "Prioritize configured rare fish targets.", false)

-- Quest | Items
section(QuestItems, "Quest Farming")
toggle(QuestItems, "auto_quest", "Auto Quest", "Quest progression switch.", false)
toggle(QuestItems, "auto_level", "Auto Level", "Level progression switch.", false)
toggle(QuestItems, "auto_mastery", "Auto Mastery", "Mastery progression switch.", false)
toggle(QuestItems, "auto_boss", "Auto Boss", "Boss rotation switch.", false)
toggle(QuestItems, "elite_hunter", "Elite Hunter", "Elite target switch.", false)

section(QuestItems, "Items & Currency")
toggle(QuestItems, "auto_chest", "Auto Chest", "Chest collection switch.", false)
toggle(QuestItems, "farm_materials", "Farm Materials", "Material farming switch.", false)
toggle(QuestItems, "farm_bones", "Farm Bones", "Bone farming switch.", false)
toggle(QuestItems, "farm_fragments", "Farm Fragments", "Fragment farming switch.", false)
toggle(QuestItems, "auto_haki", "Auto Haki", "Haki helper state.", false)

-- Volcano Dojo
section(VolcanoDojo, "Volcano")
toggle(VolcanoDojo, "volcano_event", "Volcano Event", "Volcano event helper state.", false)
toggle(VolcanoDojo, "volcano_progress", "Volcano Progress", "Volcano progress helper state.", false)

section(VolcanoDojo, "Dojo")
toggle(VolcanoDojo, "dojo_helper", "Dojo Helper", "Dojo progression helper state.", false)
toggle(VolcanoDojo, "dojo_tasks", "Dojo Tasks", "Dojo task helper state.", false)

-- Sea Event
section(SeaEvent, "Sea Hunting")
toggle(SeaEvent, "sea_beast", "Sea Beast Hunter", "Sea Beast helper state.", false)
toggle(SeaEvent, "mirage_island", "Mirage Island", "Mirage Island helper state.", false)
toggle(SeaEvent, "terror_shark", "Terrorshark", "Terrorshark helper state.", false)
toggle(SeaEvent, "ship_farm", "Ship Farm", "Ship event helper state.", false)
toggle(SeaEvent, "auto_boat", "Auto Boat", "Boat navigation helper state.", false)

-- Race V4
section(RaceV4, "Race Progression")
toggle(RaceV4, "race_v4", "Race V4", "Race V4 progression state.", false)
toggle(RaceV4, "race_awakening", "Race Awakening", "Race awakening state.", false)
toggle(RaceV4, "race_trials", "Race Trials", "Race trial helper state.", false)
toggle(RaceV4, "gear_helper", "Gear Helper", "Gear progression helper state.", false)

-- Raid Fruits
section(RaidFruits, "Raids")
toggle(RaidFruits, "auto_raid", "Auto Raid", "Raid progression switch.", false)
toggle(RaidFruits, "auto_awaken", "Auto Awaken", "Fruit awakening state.", false)
toggle(RaidFruits, "raid_retry", "Auto Retry", "Raid retry state.", false)
toggle(RaidFruits, "raid_fragments", "Fragment Farm", "Raid fragment state.", false)

-- Fruits | Stock
section(FruitsStock, "Fruit Tools")
toggle(FruitsStock, "fruit_notifier", "Fruit Notifier", "Fruit notification state.", false)
toggle(FruitsStock, "fruit_esp", "Fruit ESP", "Fruit display overlay state.", false)
toggle(FruitsStock, "fruit_sniper", "Fruit Sniper", "Configured fruit target state.", false)
toggle(FruitsStock, "auto_store_fruit", "Auto Store Fruit", "Fruit storage helper state.", false)
button(FruitsStock, "check_stock", "Check Fruit Stock", "Run the configured fruit stock callback.")

-- Teleport
section(Teleport, "Locations")

local selectedLocation = "Starter Island"
Teleport:Dropdown({
    Title = "Location",
    Desc = "Choose a location for the configured handler.",
    Values = {
        "Starter Island",
        "Jungle",
        "Pirate Village",
        "Desert",
        "Middle Town",
        "Marine Fortress",
        "Skylands",
        "Colosseum",
        "Magma Village",
        "Underwater City",
        "Fountain City",
        "Kingdom of Rose",
        "Green Zone",
        "Graveyard",
        "Snow Mountain",
        "Hot and Cold",
        "Cursed Ship",
        "Ice Castle",
        "Forgotten Island",
        "Port Town",
        "Hydra Island",
        "Great Tree",
        "Floating Turtle",
        "Castle on the Sea",
        "Haunted Castle",
        "Sea of Treats",
        "Tiki Outpost",
    },
    Value = selectedLocation,
    Callback = function(value)
        selectedLocation = value
    end,
})

Teleport:Button({
    Title = "Go to Location",
    Desc = "Run the configured location callback.",
    Callback = function()
        if not runHandler("location", selectedLocation) then
            notify("Teleport", selectedLocation .. " selected.", "map-pin")
        end
    end,
})

toggle(Teleport, "fruit_location", "Fruit Location", "Fruit location helper state.", false)
toggle(Teleport, "boss_location", "Boss Location", "Boss location helper state.", false)

-- PvP Player
section(PvP, "Player")
toggle(PvP, "player_esp", "Player ESP", "Player overlay state.", false)
toggle(PvP, "auto_dodge", "Auto Dodge", "Dodge helper state.", false)
toggle(PvP, "auto_combo", "Auto Combo", "Combo helper state.", false)
toggle(PvP, "auto_run", "Auto Run", "Movement helper state.", false)
toggle(PvP, "damage_predictor", "Damage Predictor", "Damage display state.", false)

-- Shop
section(Shop, "Fruit & Equipment")
button(Shop, "shop_fruits", "Fruit Dealer", "Run the configured fruit dealer callback.")
button(Shop, "shop_fighting_styles", "Fighting Styles", "Run the configured fighting styles callback.")
button(Shop, "shop_swords", "Swords", "Run the configured sword callback.")
button(Shop, "shop_guns", "Guns", "Run the configured gun callback.")
button(Shop, "shop_accessories", "Accessories", "Run the configured accessories callback.")

-- Settings
section(Settings, "Utilities")
toggle(Settings, "auto_rejoin", "Auto Rejoin", "Reconnect utility state.", false)
toggle(Settings, "anti_afk", "Anti AFK", "Idle prevention utility state.", false)
toggle(Settings, "fps_booster", "FPS Booster", "Performance utility state.", false)
toggle(Settings, "notifications", "Notifications", "Feature notification state.", true)

section(Settings, "Themes")

local function addTheme(themeName)
    Settings:Button({
        Title = themeName,
        Desc = "Switch Vanta to " .. themeName .. ".",
        Callback = function()
            VantaUI:SetTheme(themeName)
            notify("Theme", "Changed to " .. themeName, "palette")
        end,
    })
end

addTheme("Salty Special")
addTheme("Vanta AMOLED")
addTheme("Vanta Smoked")
addTheme("Vanta Dark")
addTheme("Vanta Violet")

Settings:Button({
    Title = "Reset State",
    Desc = "Reset all feature switch states for this session.",
    Callback = function()
        for key in pairs(State) do
            State[key] = false
        end
        State.notifications = true
        notify("Vanta", "Feature state reset.", "rotate-ccw")
    end,
})

Window:SelectTab(1)

return {
    UI = VantaUI,
    Window = Window,
    State = State,
    Handlers = Handlers,
}
