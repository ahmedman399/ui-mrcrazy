# MR CRAZY UI LIB: Guide for AI script writers

> **Read this whole file before you write any MR CRAZY Roblox script.**
> It tells you exactly how to build a script with our library, and how to ship the
> **key system + the real script in ONE file** that imports the UI from GitHub.

---

## 0. The deliverable (what you must produce)

One `.lua` file that the player pastes into the executor. It contains, in this order:

1. A short header comment (script name, game, version).
2. A `CONFIG` table.
3. **One line that imports the library from GitHub** (never paste the library into the script):
   `local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/ahmedman399/ui-mrcrazy/main/mrcrazy_ui_lib.lua"))()`
4. Game logic (services, state, helper functions).
5. `buildUI(session)`: builds the main window with `Lib:CreateWindow`.
6. **The entry point:** `Lib.KeySystem.Run({ ..., AutoLoad = false, OnSuccess = buildUI })`.

**Nothing runs before the key is accepted.** All game logic starts from `buildUI` (the key system's `OnSuccess`).

---

## 1. Files in this folder

| File | Use |
|---|---|
| `mrcrazy_ui_lib.lua` | **The library every script imports** (raw GitHub URL above). Window UI + Dynamic-Island notch + pixel logo / icons + key system. |
| `mrcrazy_keysystem.lua` | Key system only (no main window). Use it only for a loader that downloads the script from the server (section 9). |
| `example.lua` | A complete working example (key system + every widget). Copy its structure. |
| `docs/LUA-INTEGRATION.md` | How the website / key server works. You never call the server yourself: `Lib.KeySystem` does it. |

---

## 2. Hard rules (never break these)

1. **No emoji. Anywhere.** Not in tab names, buttons, toasts, prints or comments shown to the player. Use the pixel icon names (section 6). Before you finish, check your file contains no emoji characters.
2. **Do not copy or edit the library.** Always import it with the one `loadstring(game:HttpGet(...))` line. The script file holds only the game logic and `buildUI`. If something is missing in the library, say so to the user instead of hacking around it.
3. **Do not create your own ScreenGuis / frames / styles** for the script UI. Only use the library API. The design is fixed: "Classic Sky", Ubuntu font, 656x536. No theme or font switchers. (On phones the library draws the same 656x536 layout smaller by itself, see section 5.1. Do not build a separate mobile UI.)
4. **No secrets in the script.** No keys, tokens, webhooks, Supabase URLs or keys. Never hard-code a valid key. Never `print` the player's key.
5. **Never set `Demo = true`** in a script you deliver. It accepts the test key offline and is only for previewing the UI.
6. **Do not call the key server yourself.** No `request()` to `app-api`. `Lib.KeySystem.Run` handles activation, HWID, saved key, maintenance and errors.
7. **All text the player sees is English.** Keep subtitles short (about 45 characters max) or they get cut with "...".
8. Every remote call / game interaction goes inside `pcall`. A broken game update must not crash the UI.
9. Every loop must stop when its toggle is turned off, when the window is closed (`Win:IsAlive()`), or when the script is executed again (session token, section 7).

---

## 3. File template (copy this exactly, then fill in)

```lua
--[[
    MR CRAZY - <GAME NAME>
    Version: 1.0.0
    Made with the MR CRAZY UI LIB
--]]

-- ═════════════════════════════ CONFIG ═════════════════════════════
local CONFIG = {
    ScriptName = "MR CRAZY - <GAME NAME>",
    Version = "1.0.0",
    DiscordUrl = "https://discord.gg/PfnUrnYvg3",
    WebsiteUrl = "https://mrcrazy.xyz",
}

-- ═════════════════════════════ LIBRARY ════════════════════════════
local LIB_URL = "https://raw.githubusercontent.com/ahmedman399/ui-mrcrazy/main/mrcrazy_ui_lib.lua"
local okLib, Lib = pcall(function() return loadstring(game:HttpGet(LIB_URL))() end)
if not okLib or type(Lib) ~= "table" then
    warn("[MR CRAZY] UI library failed to load: " .. tostring(Lib))
    return
end

-- ═════════════════════════════ SESSION GUARD ══════════════════════
-- Re-running the script stops every loop of the previous run.
local env = (getgenv and getgenv()) or _G
env.MRCRAZY_RUN = (env.MRCRAZY_RUN or 0) + 1
local RUN_ID = env.MRCRAZY_RUN
local function isCurrentRun() return env.MRCRAZY_RUN == RUN_ID end

-- ═════════════════════════════ SERVICES & STATE ═══════════════════
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local State = {
    AutoFarm = false,
    FarmDelay = 0.2,
}

-- ═════════════════════════════ GAME LOGIC ═════════════════════════
local function getRoot()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function farmOnce()
    -- one step of the feature; all game calls inside pcall
    local ok, err = pcall(function()
        -- ReplicatedStorage.Remotes.Hit:FireServer(...)
    end)
    if not ok then warn("[MR CRAZY] farmOnce: " .. tostring(err)) end
end

-- ═════════════════════════════ UI ═════════════════════════════════
local function buildUI(session)
    local Win = Lib:CreateWindow({
        Title = CONFIG.ScriptName,
        Subtitle = "Plan: " .. tostring(session and session.plan or "free"),
        DiscordUrl = CONFIG.DiscordUrl,
        WebsiteUrl = CONFIG.WebsiteUrl,
        ToggleKey = Enum.KeyCode.RightShift,
        OnClose = function()
            -- stop everything when the window is closed
            State.AutoFarm = false
        end,
    })

    local function running(flagName)
        return State[flagName] and Win:IsAlive() and isCurrentRun()
    end

    local farm = Win:CreateTab("Farm", "egg")
    farm:CreateSection("Auto Farm")
    farm:CreateToggle("Auto Farm", "Hits the nearest egg automatically", false, function(on)
        State.AutoFarm = on
        if not on then return end
        task.spawn(function()
            while running("AutoFarm") do
                farmOnce()
                task.wait(State.FarmDelay)
            end
        end)
    end)
    farm:CreateSlider("Farm Delay", "Milliseconds between hits", 50, 1000, 200, " ms", function(ms)
        State.FarmDelay = ms / 1000
    end)

    local settings = Win:CreateTab("Settings", "gear")
    settings:CreateSection("Server")
    settings:CreateButton("Rejoin Server", "Reconnects to this server", "Blue", function()
        pcall(function()
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end)
    end)

    Win:Notify("MR CRAZY", Win:IsMobile() and "Loaded. Tap the doge button to hide / show"
        or "Loaded. Press RightShift to hide / show", 4, "Blue")
end

-- ═════════════════════════════ START ══════════════════════════════
Lib.KeySystem.Run({
    Version = CONFIG.Version,
    AutoLoad = false,     -- the real script is THIS file, do not download one
    OnSuccess = buildUI,  -- runs after the key is accepted (or the saved key is still valid)
})
```

---

## 4. Key system: what happens

`Lib.KeySystem.Run(options)`:

1. Checks the server (`/info`). If it is under maintenance, the key window shows the message and refuses keys.
2. If a saved key exists (`MRCRAZY/key.txt`) and is still valid, **no window is shown**: an Island notification "Welcome back" drops in and `OnSuccess(session)` runs.
3. Otherwise it shows the **"Shy Doge" key window**:
   - The key is auto-formatted as `MRC-XXXX-XXXX-XXXX-XXXX`, uppercase. Paste works.
   - The eye button shows / hides the key. The doge covers its eyes while you type a hidden key.
   - **GET KEY** copies `https://mrcrazy.xyz/free`. **DISCORD** and **WEBSITE** copy their links.
   - The yellow button minimizes the window into an island pill at the top. Tap the pill to reopen it.
   - Wrong key: the field shakes, the doge shakes its head, and the server's message is shown.
   - Correct key: the window collapses into the island pill ("Key accepted" + plan), closes after about 3 s, then `OnSuccess(session)` runs.

Options:

| Option | Default | Meaning |
|---|---|---|
| `Version` | `nil` | Your script version. Shows "Update available" if the server's `app_version` is newer. |
| `AutoLoad` | `true` | `true` = download the game script from the server and run it. **For single-file scripts use `false`.** |
| `AutoLogin` | `true` | Skip the window when the saved key is valid. |
| `OnSuccess` | | `function(session)`. `session = { plan, expires_at, games, keyHint }` (`plan` is `"free"` or `"premium"`, `keyHint` = `"****-ABCD"`). |
| `OnClose` | | The player closed the key window without a key. Do not start the script. |
| `Game` | PlaceId | Only matters when `AutoLoad = true`. |
| `Title`, `Subtitle`, `Footer` | MR CRAZY texts | Key window texts. Usually leave them. |
| `Demo` | `false` | Preview only. **Never ship it.** |

Premium-only features: check `session.plan == "premium"` inside `buildUI` and either hide the feature or show a disabled button that calls `Win:Notify("Premium", "This feature is for Premium players", 3, "Gold")`.

---

## 5. Window and widget API

```lua
local Win = Lib:CreateWindow({
    Title = "...", Subtitle = "...",
    DiscordUrl = "...", WebsiteUrl = "...",
    ToggleKey = Enum.KeyCode.RightShift,  -- optional
    ShortName = "MR CRAZY",               -- text in the idle notch
    AutoActivity = true,                  -- toggles show in the notch while ON
    OnClose = function() end,             -- once, when the window closes
    -- Scale = 0.8,                       -- optional fixed size 0.3..1.5. Leave it out (auto).
    -- Mobile = true,                     -- optional: force mobile mode (to preview it on PC). Leave it out.
})
```

Window methods:

| Method | What it does |
|---|---|
| `Win:CreateTab(name, iconName)` | New sidebar tab. `iconName` from section 6. Returns a Tab. |
| `Win:Notify(title, message, seconds, tone)` | Toast at the bottom right. While minimized it pops out of the notch instead. |
| `Win:AddActivity(id, text)` / `Win:RemoveActivity(id)` | Shows a running task in the notch. Toggles do this automatically. Use it for buttons that start long tasks. |
| `Win:Minimize()` / `Win:Restore()` | Notch (Dynamic Island) mode. |
| `Win:Maximize()` / `Win:RestoreSize()` / `Win:ToggleMaximize()` | |
| `Win:SetVisible(bool)` / `Win:Destroy()` / `Win:IsAlive()` | |
| `Win:SetScale(n)` / `Win:GetScale()` / `Win:IsMobile()` | Draw size multiplier 0.3..1.5 (`nil` = back to automatic). `IsMobile()` = the library is in mobile mode. |

Tab widgets (arguments in `[ ]` are optional and can be skipped):

| Widget | Signature | Returns | Notes |
|---|---|---|---|
| Section | `Tab:CreateSection(title)` | | Gold header, shown in UPPERCASE. |
| Button | `Tab:CreateButton(text, [sub], [tone], callback)` | | Forms: `(text, cb)`, `(text, "Gold", cb)`, `(text, "description", cb)`, `(text, "description", "Red", cb)`. |
| Toggle | `Tab:CreateToggle(title, [sub], default, callback(on))` | `{ Set(v), Get() }` | **The callback is NOT called for the default value.** Apply the default to your state yourself. `Set` does not fire the callback. |
| Slider | `Tab:CreateSlider(title, [sub], min, max, default, suffix, callback(value))` | `{ Set(v), Get() }` | **Whole numbers only.** For decimals use a bigger range and divide (ms then `/1000`). Fires continuously while dragging. |
| Dropdown | `Tab:CreateDropdown(title, [sub], options, default, callback(option))` | `{ Refresh(newOptions, resetFirst), Get() }` | **Each click cycles to the next option** (it is not a popup list). Keep lists short (2-10). |
| Stat card | `Tab:CreateStatCard(label, value, tone)` | `{ SetValue(text) }` | Live numbers: tiers, coins, counters. |
| Status card | `Tab:CreateStatusCard(title, text)` | `{ SetText(text) }` | Multi-line live status of a feature. |
| Player selector | `Tab:CreatePlayerSelector(title, [sub], callback(player, selected))` | `{ GetSelected(), Refresh() }` | Grid of the other players, auto-refreshes on join and leave. |

Tones: `"Blue"` (default action), `"Gold"` (highlight / upgrade), `"Green"` (start / confirm), `"Red"` (stop / danger / server hop), `"Ice"`, `"Card"` (neutral / white).

### 5.1 Mobile (automatic, nothing to do in the script)

The library detects phones / tablets (touch screen with no keyboard, or a touch screen with a small viewport) and:

- Draws the **same** window smaller with a `UIScale`: it fits about 60% of the screen width / height, never smaller than 0.45. It refits when the phone rotates. Layout and design do not change. Toasts scale the same way.
- Shows a round **draggable doge button** on the left edge. Tap = hide / show the window (if the window is in the notch, tap restores it). Drag it anywhere. This replaces `ToggleKey`, which does not exist on phones.
- Drags (window bar, resize grip, sliders, the button) follow only the finger that started them, so moving with the thumbstick never drags the UI. The grip corner still resizes the window.

Desktop is unchanged (scale 1, no floating button, `ToggleKey` as before).

Script rules for mobile: do not add your own mobile button or scale code. For the "loaded" toast write text that is true on both, e.g. `Win:Notify("MR CRAZY", Win:IsMobile() and "Loaded. Tap the doge button to hide / show" or "Loaded. Press RightShift to hide / show", 4, "Blue")`.

Island notification (no window needed): `Lib:Island({ Title = "...", Text = "...", Icon = "check", Tone = "Green", Duration = 3 })`.

---

## 6. Pixel icons (use these instead of emoji)

`key` `discord` `globe` `check` `x` `minus` `plus` `restore` `arrow` `play` `stop` `grip` `chevron` `egg` `gem` `gear` `target` `pin` `refresh` `signal` `eye` `eyeoff` `lock` `user` `alert` `bolt`

Suggested tab icons:

| Tab | Icon |
|---|---|
| Steal / Combat / PvP | `target` |
| Farm / Eggs / Collect | `egg` |
| Upgrades / Shop / Items | `gem` |
| Teleports / Map | `pin` |
| Players | `user` |
| Speed / Movement / Auto | `bolt` |
| Visuals / ESP | `eye` |
| Misc / Info | `signal` |
| Settings | `gear` (always the last tab) |

Only these names exist. An unknown name in `CreateTab` is shown as plain text, and in `Lib.Icon` it draws nothing. If you truly need a new icon, tell the user. Icons are 9x9 pixel grids in the `ICONS` table of the library.

---

## 7. Patterns you must use

**Session guard** (top of the file, see the template): every loop checks `isCurrentRun()`, so executing the script twice does not double the loops.

**Toggle loop with no duplicates.** If the player spams the toggle, only one loop may run:

```lua
local farmRun = 0
tab:CreateToggle("Auto Farm", "Hits the nearest egg", false, function(on)
    State.AutoFarm = on
    farmRun += 1
    if not on then return end
    local myRun = farmRun
    task.spawn(function()
        while State.AutoFarm and farmRun == myRun and Win:IsAlive() and isCurrentRun() do
            farmOnce()
            task.wait(State.FarmDelay)
        end
    end)
end)
```

**Long task started by a button.** Show it in the notch:

```lua
tab:CreateButton("Collect All", "Collects every drop on the map", "Green", function()
    Win:AddActivity("collect", "Collect All")
    task.spawn(function()
        pcall(collectAll)
        Win:RemoveActivity("collect")
        Win:Notify("Collect", "Done", 2, "Green")
    end)
end)
```

**Live values:**

```lua
local coins = tab:CreateStatCard("Coins", "0", "Gold")
task.spawn(function()
    while Win:IsAlive() and isCurrentRun() do
        local ok, value = pcall(function() return LocalPlayer.leaderstats.Coins.Value end)
        if ok then coins:SetValue(tostring(value)) end
        task.wait(1)
    end
end)
```

**Dropdown that depends on another dropdown:**

```lua
local eggDrop = tab:CreateDropdown("Egg", ZONES.Zone1, ZONES.Zone1[1], function(egg) State.Egg = egg end)
tab:CreateDropdown("Zone", { "Zone1", "Zone2" }, "Zone1", function(zone)
    State.Zone = zone
    eggDrop:Refresh(ZONES[zone], true) -- true = select the first option and fire the callback
end)
```

**Feedback:** after an action that does something the player can't see, call `Win:Notify(title, short message, 2-3, tone)`. Errors use `"Red"`, success `"Green"`, info `"Blue"`.

**Anti-AFK / connections:** keep any `Connect` you create in a table and `Disconnect` it in the window's `OnClose`.

---

## 8. UI layout rules

- 3 to 6 tabs. `Settings` (icon `gear`) is always the last tab and holds misc and server items (rejoin, server hop, anti-AFK, Discord info).
- Every tab starts with `CreateSection`. Group related controls under sections.
- Order inside a section: main toggle first, then its sliders and dropdowns, then a status card if it has live status.
- Titles: short Title Case ("Auto Farm", "Walk Speed"). The description says what it does in plain words.
- Use buttons for one-shot actions and toggles for anything that keeps running.
- Do not put more than about 12 controls in one tab. Split into another tab instead.

---

## 9. Optional: loader mode (script stored on the server)

If the user asks for the script to be hidden on the server instead of shipped inside the file:

- The real script (built exactly as above, **but without the key system at the end**: call `buildUI()` directly) is uploaded by the website admin to the `scripts` bucket for that game.
- The player runs a small loader:

```lua
local KeySystem = loadstring(game:HttpGet("https://raw.githubusercontent.com/ahmedman399/ui-mrcrazy/main/mrcrazy_keysystem.lua"))()
KeySystem.Run({ Version = "1.0.0" }) -- AutoLoad = true: downloads and runs this game's script
```

Single-file mode (sections 0 and 3) is the default unless the user asks for loader mode.

---

## 10. Final checklist before you deliver

- [ ] One file: CONFIG, the one-line library import from GitHub, session guard, logic, `buildUI`, `Lib.KeySystem.Run({ AutoLoad = false, OnSuccess = buildUI })`.
- [ ] The library code is NOT pasted into the script.
- [ ] Nothing runs before the key is accepted.
- [ ] No `Demo = true`, no keys, no secrets, no `request()` to the key server.
- [ ] No emoji anywhere. Tab icons come from section 6.
- [ ] Every loop checks its flag, `Win:IsAlive()` and `isCurrentRun()`. Every game call is in `pcall`.
- [ ] Toggle defaults are applied to the state manually (the callback does not fire for the default).
- [ ] Slider values are whole numbers (scaled if needed).
- [ ] English text, short subtitles, Settings tab last.
