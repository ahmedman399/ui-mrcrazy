--[[
══════════════════════════════════════════════════════════════════════════════
 MR CRAZY - FULL EXAMPLE (key system + main window with every widget)
 Paste the whole file into the executor and run it.

   DEMO = true  -> no server needed, use the key  MRC-TEST-TEST-TEST-TEST
                   (MRC-0000-0000-0000-0000 shows the "other device" error)
   DEMO = false -> real keys from https://mrcrazy.xyz/free
══════════════════════════════════════════════════════════════════════════════
--]]
local DEMO = true

local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/ahmedman399/ui-mrcrazy/main/mrcrazy_ui_lib.lua"))()

-- ══════════════════════════════════════════════════════════════
-- MAIN WINDOW (opens after the key is accepted)
-- ══════════════════════════════════════════════════════════════
local function openMainWindow(session)
    local Win = Lib:CreateWindow({
        Title = "MR CRAZY - BREAK AND STEAL AN EGG",
        Subtitle = "Plan: " .. tostring(session and session.plan or "?"),
        DiscordUrl = "https://discord.gg/D9gTCEwTpd",
        WebsiteUrl = "https://mrcrazy.xyz",
        ToggleKey = Enum.KeyCode.RightShift,
    })

    -- STEAL: toggles, sliders, status card, player selector
    local steal = Win:CreateTab("STEAL", "target")
    steal:CreateSection("Auto Steal & Ambush")
    steal:CreateToggle("Auto Steal From Players", "Cuts off carriers crossing the ambush line", false, function(on)
        Win:Notify("Auto Steal", on and "Started" or "Stopped", 2, on and "Green" or "Red")
    end)
    steal:CreateToggle("Show Ambush Line Wall", "Neon laser barrier in workspace", true, function() end)
    steal:CreateSlider("Ambush Line Width", "Lateral span of the barrier (studs)", 40, 240, 120, " studs", function() end)
    steal:CreateSlider("Intercept Range", 20, 180, 104, " studs", function() end)
    local status = steal:CreateStatusCard("Ambush Status", "Idle - waiting for carriers to cross the line...")
    steal:CreatePlayerSelector("Priority Targets", "Select players to prioritize", function(player, selected)
        status:SetText(player.Name .. (selected and " added to targets" or " removed from targets"))
    end)

    -- EGG FARM: dropdowns, toggle, slider, button
    local farm = Win:CreateTab("Egg Farm", "egg")
    farm:CreateSection("Farming")
    farm:CreateDropdown("Zone", "Tap to cycle zones", { "Zone1", "Zone2", "Zone3", "Zone4" }, "Zone1", function(zone)
        Win:Notify("Zone", zone, 1.5, "Blue")
    end)
    farm:CreateDropdown("Egg", { "Forest Egg", "Cactus Egg", "Ice Egg" }, "Forest Egg", function() end)
    farm:CreateToggle("Auto Farm Loop", "Hits eggs automatically", false, function() end)
    farm:CreateSlider("Attack Delay", "Milliseconds between hits", 50, 600, 120, " ms", function() end)
    farm:CreateButton("Start Farming", "Begins the auto farm cycle", "Green", function()
        Win:Notify("Farm", "Started", 2, "Green")
    end)

    -- UPGRADES: every button colour + stat cards
    local upgrades = Win:CreateTab("Upgrades", "gem")
    upgrades:CreateSection("Buttons")
    upgrades:CreateButton("Blue button", "Primary action", "Blue", function() end)
    upgrades:CreateButton("Gold button", "Highlight action", "Gold", function() end)
    upgrades:CreateButton("Green button", "Confirm action", "Green", function() end)
    upgrades:CreateButton("Red button", "Danger action", "Red", function() end)
    upgrades:CreateButton("Button without description", "Blue", function() end)
    upgrades:CreateSection("Stats")
    local pickaxe = upgrades:CreateStatCard("Pickaxe Tier", "7 / 12", "Gold")
    upgrades:CreateStatCard("Trail Tier", "3 / 10", "Blue")
    upgrades:CreateStatCard("Index Claimed", "42%", "Green")
    upgrades:CreateButton("Upgrade Pickaxe", "Updates the stat card above", "Gold", function()
        pickaxe:SetValue("8 / 12")
    end)

    -- TELEPORTS
    local tp = Win:CreateTab("Teleports", "pin")
    tp:CreateSection("Teleports")
    tp:CreateButton("Teleport to SafeZone", "Moves to the base", "Blue", function() end)
    tp:CreateButton("Teleport to Ambush Line", "Moves to the barrier", "Gold", function() end)

    -- SETTINGS: notch / activities / notifications
    local settings = Win:CreateTab("Settings", "gear")
    settings:CreateSection("Notch (minimize)")
    settings:CreateButton("Start a background task", "Shows in the notch while minimized", "Green", function()
        Win:AddActivity("demo_task", "Auto Collect")
        Win:Notify("Task", "Auto Collect started", 2, "Green")
    end)
    settings:CreateButton("Stop the background task", "Removes it from the notch", "Red", function()
        Win:RemoveActivity("demo_task")
    end)
    settings:CreateButton("Minimize + message in 1s", "The message pops out of the notch", "Gold", function()
        Win:Minimize()
        task.delay(1, function() Win:Notify("Hello", "This message pops out of the notch", 3, "Blue") end)
    end)
    settings:CreateSection("Notifications")
    settings:CreateButton("Island notification", "Drops from the top of the screen", "Blue", function()
        Lib:Island({ Title = "MR CRAZY", Text = "Island notification test", Icon = "bolt", Tone = "Gold" })
    end)
    settings:CreateButton("Success toast", "Green", function() Win:Notify("Success", "Everything worked", 3, "Green") end)
    settings:CreateButton("Error toast", "Red", function() Win:Notify("Error", "Something went wrong", 3, "Red") end)

    Win:Notify("MR CRAZY", "Welcome! Press RightShift to hide / show", 4, "Blue")
end

-- ══════════════════════════════════════════════════════════════
-- KEY SYSTEM (runs first)
-- ══════════════════════════════════════════════════════════════
Lib.KeySystem.Run({
    Demo = DEMO,
    Version = "1.0.0",
    AutoLoad = false, -- this example builds its own window instead of downloading a game script
    OnSuccess = openMainWindow,
})
