--[[
══════════════════════════════════════════════════════════════════════════════
 MR CRAZY UI LIBRARY  •  "Classic Sky" design  •  Ubuntu font  •  v2.0.0
══════════════════════════════════════════════════════════════════════════════
 One file: window UI + Dynamic-Island notch + pixel logo & icons + key system.
 Pure Luau, no image assets, no emoji, no secrets.

 LOAD
   local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/ahmedman399/ui-mrcrazy/main/mrcrazy_ui_lib.lua"))()

 KEY SYSTEM (talks to the website app-api, see docs/LUA-INTEGRATION.md)
   Lib.KeySystem.Run({
       Version   = "1.0.0",            -- compared with the server app_version
       Game      = nil,                -- optional slug, default = current PlaceId
       AutoLoad  = true,               -- download + run the game script after the key is accepted
       AutoLogin = true,               -- use the saved key (MRCRAZY/key.txt) without showing the window
       OnSuccess = function(session) end, -- { plan, expires_at, games, keyHint, source? }
       OnClose   = function() end,
       -- Demo = true                  -- offline preview, NEVER ship it
   })
   Key window: "Shy Doge" - the doge covers its eyes while you type a hidden key,
   peeks when you show it, shakes its head on a wrong key, and when the key is
   accepted the window itself turns into a Dynamic-Island pill at the top of the screen.
   The yellow button minimizes it into the same pill - tap the pill to open it again.

 ISLAND NOTIFICATION
   Lib:Island({ Title = "Key accepted", Text = "Free plan", Icon = "check", Tone = "Green", Duration = 3 })

 WINDOW
   local Win = Lib:CreateWindow({
       Title      = "MR CRAZY - BREAK AND STEAL AN EGG",
       Subtitle   = "Made with love for you",
       DiscordUrl = "https://discord.gg/PfnUrnYvg3",   -- DISCORD button copies it
       WebsiteUrl = "https://mrcrazy.xyz",      -- WEB button copies it
       Width = 656, Height = 536,                      -- default size
       ToggleKey = Enum.KeyCode.RightShift,            -- optional show / hide key
       ShortName = "MR CRAZY",                         -- text in the idle notch
       AutoActivity = true,                            -- toggles report to the notch
       OnClose = function() end,                       -- called once when the window is closed
       -- LogoId / DiscordIcon / WebIcon = "rbxassetid://..." to replace the pixel art
   })
   Win:CreateTab(name, iconName)      -> Tab
   Win:Notify(title, message, seconds, tone)
   Win:Minimize()  Win:Restore()      -- minimize = Dynamic-Island notch at the top
   Win:Maximize()  Win:RestoreSize()  Win:ToggleMaximize()
   Win:SetSize(w, h)  Win:ResetSize()  Win:SetVisible(bool)  Win:Destroy()
   Win:IsAlive()                      -- false after the window is closed (stop your loops)
   Win:AddActivity(id, text)  Win:RemoveActivity(id)  Win:GetActivities()

 TAB
   Tab:CreateSection(title)
   Tab:CreateButton(text, [sub], [tone], callback)
   Tab:CreateToggle(title, [sub], default, callback(state))                   -> { Set, Get }
   Tab:CreateSlider(title, [sub], min, max, default, suffix, callback(value)) -> { Set, Get }
   Tab:CreateDropdown(title, [sub], options, default, callback(option))       -> { Refresh, Get }
   Tab:CreateStatCard(label, value, tone)                                     -> { SetValue }
   Tab:CreateStatusCard(title, text)                                          -> { SetText }
   Tab:CreatePlayerSelector(title, [sub], callback(player, selected))         -> { GetSelected, Refresh }

 TONES   "Blue" "Gold" "Green" "Red" "Ice" "Card" or any Color3   (Lib.Tones / Lib.Theme)
 ICONS   Lib.Icon(parent, name, size, color)  - sizes 9 / 18 / 27 are pixel perfect
   key discord globe check x minus plus restore arrow play stop grip chevron egg gem
   gear target pin refresh signal eye eyeoff lock user alert bolt

 WINDOW CONTROLS
   red = close, yellow = minimize into the notch (click the notch to restore),
   green = maximize / restore. Drag the top bar to move, drag the right edge,
   bottom edge or the grip corner to resize (600x340 .. 1300x900).
══════════════════════════════════════════════════════════════════════════════
--]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local Library = { Version = "1.0.0" }

-- ══════════════════════════════════════════════════════════════
-- DESIGN TOKENS (fixed: Classic Sky + Ubuntu)
-- ══════════════════════════════════════════════════════════════
local C = Color3.fromRGB
local WHITE = C(255, 255, 255)

local THEME = {
    Ink = C(11, 21, 51),
    Navy = C(13, 26, 72),
    Sky = C(63, 167, 255),
    SkyDark = C(47, 134, 214),
    Ice = C(207, 226, 255),
    Gold = C(255, 210, 63),
    GoldText = C(196, 142, 0),
    Green = C(107, 209, 80),
    Red = C(255, 90, 95),
    Discord = C(88, 101, 242),

    WinTop = C(36, 85, 154),
    WinBottom = C(13, 26, 72),
    Card = WHITE,
    Text = C(11, 21, 51),
    TextMuted = C(74, 90, 128),
    TextSub = C(94, 110, 148),
    BarText = C(244, 248, 255),
    BarSub = C(185, 202, 235),
    TabBg = C(23, 58, 122),
    PillOff = C(185, 202, 235),
    Track = C(201, 214, 238),
    Input = C(238, 244, 255),
}
Library.Theme = THEME

Library.Tones = {
    Blue = THEME.Sky, Gold = THEME.Gold, Green = THEME.Green,
    Red = THEME.Red, Ice = THEME.Ice, Card = THEME.Card,
}

local FONT = Enum.Font.Ubuntu
local TEXT_BOOST = 1.28
local LIFT = 4 -- height of the block-button "shadow"

local function fs(n) return math.floor(n * TEXT_BOOST + 0.5) end

local function resolveTone(tone)
    if typeof(tone) == "string" then return Library.Tones[tone] or THEME.Sky end
    return tone or THEME.Sky
end

local function luminance(c) return c.R * 0.2126 + c.G * 0.7152 + c.B * 0.0722 end

-- ══════════════════════════════════════════════════════════════
-- SMALL INSTANCE HELPERS
-- ══════════════════════════════════════════════════════════════
local function inst(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function corner(o, r) return inst("UICorner", { CornerRadius = UDim.new(0, r) }, o) end

local function stroke(o, color, thickness)
    return inst("UIStroke", {
        Color = color, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, o)
end

local function frame(parent, size, pos, color)
    return inst("Frame", {
        Size = size, Position = pos or UDim2.new(), BorderSizePixel = 0,
        BackgroundColor3 = color or WHITE, BackgroundTransparency = color and 0 or 1,
    }, parent)
end

-- o: Size, Pos, Text, TS (base size), Color, Align, Wrap, Truncate
local function label(parent, o)
    return inst("TextLabel", {
        BackgroundTransparency = 1,
        Size = o.Size, Position = o.Pos or UDim2.new(),
        Font = FONT, Text = o.Text or "", TextSize = fs(o.TS or 11),
        TextColor3 = o.Color or THEME.Text,
        TextXAlignment = o.Align or Enum.TextXAlignment.Left,
        TextYAlignment = o.Wrap and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
        TextWrapped = o.Wrap or false,
        TextTruncate = o.Truncate and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None,
    }, parent)
end

local function copyText(text)
    local fn = setclipboard or toclipboard or set_clipboard
    if not fn then return false end
    return (pcall(fn, text))
end

local function isPress(i)
    return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

-- ══════════════════════════════════════════════════════════════
-- PIXEL LOGO (Doge) - built from Frames, no image asset needed
-- ══════════════════════════════════════════════════════════════
local LOGO_ROWS = {
    "0000000002200000000000000000000000",
    "0000000002220000000000000000000000",
    "0000000002220000000000000222300000",
    "0000000022322000000000002222300000",
    "0000000022332200000000022222300000",
    "0000000022233222200000222222230000",
    "0000000022222222222222222332230000",
    "0000000222222222222222222332300000",
    "0000022222222322222222223332300000",
    "0000222222223322222222223332300000",
    "0002222232233221122222232222200000",
    "0002222332222211122222222222220000",
    "0022226552222211122222222222220000",
    "0021125552221225652222222222220000",
    "0021126552211356555222222222220000",
    "0011122112111356555244444442222000",
    "0111111111111226652244444444222000",
    "0111111111112122222444444444222000",
    "0111155551111112224444444442222000",
    "0114555554111144444444444444222200",
    "0114555544411144444444444444222200",
    "0114255244411144444444441414222200",
    "0111222224411114444411111112222200",
    "0111522221111111144111111112222210",
    "0111155221551111111111111122223210",
    "0111111555111111111111111122232211",
    "0111111111111111111111111122232221",
    "0021111111111111111111111222322211",
    "0021111111111111111111111123332211",
    "0022111111111111111111111223322111",
    "0112311111111111111111111233321112",
    "0112233111111111132111111223221112",
    "0111222333333333322111112222111122",
    "0111222233333332221111111111111122",
    "1111112223333322111111111111111122",
    "1111112222333221111111111111111122",
    "1111111222232211111111111111111222",
}
local LOGO_PALETTE = {
    [1] = Color3.fromRGB(222, 196, 106),
    [2] = Color3.fromRGB(198, 149, 59),
    [3] = Color3.fromRGB(158, 109, 25),
    [4] = Color3.fromRGB(244, 238, 202),
    [5] = Color3.fromRGB(51, 51, 48),
    [6] = Color3.fromRGB(251, 251, 249),
}

local LOGO_COLS, LOGO_ROWS_N = #LOGO_ROWS[1], #LOGO_ROWS

-- Returns holder (fixed layout box) and logo (the animated inner frame).
local function buildLogo(parent, height)
    local cell = height / LOGO_ROWS_N
    local width = math.floor(LOGO_COLS * cell)
    local holder = inst("Frame", {
        Size = UDim2.new(0, width, 0, height), BackgroundTransparency = 1, BorderSizePixel = 0,
    }, parent)
    local logo = inst("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0 }, holder)
    for y, row in ipairs(LOGO_ROWS) do
        local x = 1
        while x <= #row do
            local ch = row:sub(x, x)
            local x2 = x
            while x2 < #row and row:sub(x2 + 1, x2 + 1) == ch do x2 += 1 end
            if ch ~= "0" then
                local px0, px1 = math.floor((x - 1) * cell), math.floor(x2 * cell)
                local py0, py1 = math.floor((y - 1) * cell), math.floor(y * cell)
                inst("Frame", {
                    Position = UDim2.new(0, px0, 0, py0),
                    Size = UDim2.new(0, math.max(1, px1 - px0), 0, math.max(1, py1 - py0)),
                    BackgroundColor3 = LOGO_PALETTE[tonumber(ch)], BorderSizePixel = 0,
                }, logo)
            end
            x = x2 + 1
        end
    end
    return holder, logo
end

-- ══════════════════════════════════════════════════════════════
-- PIXEL ICONS (9x9 grids, no emoji, no image assets)
-- names: key, discord, globe, check, x, minus, plus, restore, arrow, play, stop, grip, chevron, egg, gem, gear, target, pin, refresh, signal, eye, eyeoff, lock, user, alert, bolt
-- ══════════════════════════════════════════════════════════════
local ICONS = {
    key = { ".........", ".###.....", "##.##....", "#...#####", "##.##.#.#", ".###..#.#", ".........", ".........", "........." },
    discord = { ".........", ".##...##.", "#########", "#########", "##.###.##", "##.###.##", "#########", "###...###", ".#.....#." },
    globe = { "...###...", ".#..#..#.", "#..###..#", "#########", "#...#...#", "#########", "#..###..#", ".#..#..#.", "...###..." },
    check = { ".........", "........#", ".......##", "#.....##.", "##...##..", ".##.##...", "..###....", "...#.....", "........." },
    x = { ".........", ".##...##.", ".###.###.", "..#####..", "...###...", "..#####..", ".###.###.", ".##...##.", "........." },
    minus = { ".........", ".........", ".........", ".........", ".#######.", ".#######.", ".........", ".........", "........." },
    plus = { ".........", "....#....", "....#....", "....#....", ".#######.", "....#....", "....#....", "....#....", "........." },
    restore = { ".........", ".........", ".#######.", ".#######.", ".........", ".#######.", ".#######.", ".........", "........." },
    arrow = { "..#......", "..##.....", "..###....", "..####...", "..#####..", "..####...", "..###....", "..##.....", "..#......" },
    play = { ".#.......", ".##......", ".###.....", ".####....", ".#####...", ".####....", ".###.....", ".##......", ".#......." },
    stop = { ".........", ".#######.", ".#######.", ".#######.", ".#######.", ".#######.", ".#######.", ".#######.", "........." },
    grip = { ".........", ".......#.", ".........", ".....#.#.", ".........", "...#.#.#.", ".........", ".#.#.#.#.", "........." },
    chevron = { ".........", ".........", ".#.....#.", ".##...##.", "..##.##..", "...###...", "....#....", ".........", "........." },
    egg = { "...###...", "..#####..", ".#######.", ".#######.", "#########", "#########", "#########", ".#######.", "..#####.." },
    gem = { ".........", ".#######.", "#########", "#########", ".#######.", "..#####..", "...###...", "....#....", "........." },
    gear = { "....#....", ".#.###.#.", "..#####..", ".##...##.", "###...###", ".##...##.", "..#####..", ".#.###.#.", "....#...." },
    target = { "..#####..", ".#.....#.", "#..###..#", "#.#...#.#", "#.#.#.#.#", "#.#...#.#", "#..###..#", ".#.....#.", "..#####.." },
    pin = { "..#####..", ".###.###.", ".##...##.", ".###.###.", "..#####..", "...###...", "....#....", ".........", "........." },
    refresh = { "..####.#.", ".#....##.", "#....###.", "#........", "#.......#", "........#", ".###....#", ".##....#.", ".#.####.." },
    signal = { ".........", ".......##", ".......##", "....##.##", "....##.##", ".##.##.##", ".##.##.##", ".........", "........." },
    eye = { ".........", ".........", "..#####..", ".#.....#.", "#..###..#", ".#.....#.", "..#####..", ".........", "........." },
    eyeoff = { "#........", ".#.......", "..#####..", ".#.#...#.", "#...#...#", ".#...#.#.", "..#####..", ".......#.", "........#" },
    lock = { "...###...", "..#...#..", "..#...#..", ".#######.", ".###.###.", ".###.###.", ".#######.", ".#######.", "........." },
    user = { "...###...", "..#####..", "..#####..", "...###...", ".........", ".#######.", "#########", "#########", "........." },
    alert = { "....#....", "...###...", "...#.#...", "..##.##..", "..##.##..", ".#######.", ".###.###.", "#########", "........." },
    bolt = { ".....##..", "....##...", "...##....", "..######.", "....##...", "...##....", "..##.....", ".##......", "........." },
}

local function drawIcon(parent, name, size, color)
    local holder = inst("Frame", {
        Name = "Icon_" .. tostring(name), Size = UDim2.new(0, size, 0, size),
        BackgroundTransparency = 1, BorderSizePixel = 0,
    }, parent)
    local grid = ICONS[name]
    if not grid then return holder end
    local cell = size / 9
    for y, row in ipairs(grid) do
        local x = 1
        while x <= 9 do
            if row:sub(x, x) == "#" then
                local x2 = x
                while x2 < 9 and row:sub(x2 + 1, x2 + 1) == "#" do x2 += 1 end
                local px0, px1 = math.floor((x - 1) * cell + 0.5), math.floor(x2 * cell + 0.5)
                local py0, py1 = math.floor((y - 1) * cell + 0.5), math.floor(y * cell + 0.5)
                inst("Frame", {
                    Position = UDim2.new(0, px0, 0, py0),
                    Size = UDim2.new(0, math.max(1, px1 - px0), 0, math.max(1, py1 - py0)),
                    BackgroundColor3 = color or WHITE, BorderSizePixel = 0,
                }, holder)
                x = x2 + 1
            else
                x += 1
            end
        end
    end
    return holder
end

local function recolorIcon(holder, color)
    for _, f in ipairs(holder:GetChildren()) do
        if f:IsA("Frame") then f.BackgroundColor3 = color end
    end
end

Library.Icons = ICONS
function Library.Icon(parent, name, size, color) return drawIcon(parent, name, size or 18, color) end

-- Bobbing + tilting animation. fast = true while something is running. Returns stop().
local function startLogoAnim(logo, fast)
    local period = fast and 0.3 or 1.1
    logo.Rotation = -7
    logo.Position = UDim2.new()
    local info = TweenInfo.new(period, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    local spin = TweenService:Create(logo, info, { Rotation = 7 })
    local bob = TweenService:Create(logo, TweenInfo.new(period / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Position = UDim2.new(0, 0, 0, fast and -4 or -2) })
    spin:Play()
    bob:Play()
    return function()
        spin:Cancel()
        bob:Cancel()
        logo.Rotation = 0
        logo.Position = UDim2.new()
    end
end

-- ══════════════════════════════════════════════════════════════
-- WINDOW
-- ══════════════════════════════════════════════════════════════
function Library:CreateWindow(config)
    config = config or {}
    local GUI_NAME = config.Name or "MrCrazy_UI"
    local DEF_W, DEF_H = config.Width or 656, config.Height or 536
    local WIN_W, WIN_H = DEF_W, DEF_H
    local TOP_H, SIDE_W = 60, 176
    local MIN_W, MIN_H, MAX_W, MAX_H = 600, 340, 1300, 900

    -- remove any previous copy
    for _, parent in ipairs({ CoreGui, LocalPlayer:FindFirstChild("PlayerGui"), gethui and gethui() or nil }) do
        local old = parent and parent:FindFirstChild(GUI_NAME)
        if old then old:Destroy() end
    end

    local gui = inst("ScreenGui", { Name = GUI_NAME, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
    local okParent = pcall(function() gui.Parent = (gethui and gethui()) or CoreGui end)
    if not okParent or not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local conns = {}
    local function onSignal(signal, fn)
        local c = signal:Connect(fn)
        table.insert(conns, c)
        return c
    end

    local Window = {}

    -- window state
    local alive = true
    local minimized, maximized, hidden = false, false, false
    local activities, activityOrder = {}, {} -- running tasks shown in the notch
    local notchPop -- assigned below (Notify uses it while minimized)

    -- ── toasts ──────────────────────────────────────────────
    local toastBox = inst("Frame", {
        Size = UDim2.new(0, 320, 1, -40), Position = UDim2.new(1, -340, 0, 20),
        BackgroundTransparency = 1, ZIndex = 100,
    }, gui)
    inst("UIListLayout", {
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8),
    }, toastBox)

    function Window:Notify(title, message, duration, tone)
        if minimized then
            notchPop(title, message, tone, duration)
            return
        end
        local color = resolveTone(tone)
        local toast = inst("Frame", {
            Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = WHITE,
            BorderSizePixel = 0, ClipsDescendants = true,
        }, toastBox)
        corner(toast, 10)
        stroke(toast, THEME.Ink, 3)
        frame(toast, UDim2.new(0, 6, 1, 0), nil, color)
        label(toast, { Size = UDim2.new(1, -30, 0, 24), Pos = UDim2.new(0, 18, 0, 7), TS = 13,
            Text = tostring(title), Color = THEME.Ink })
        label(toast, { Size = UDim2.new(1, -30, 0, 34), Pos = UDim2.new(0, 18, 0, 31), TS = 10,
            Text = tostring(message), Color = THEME.TextMuted, Wrap = true })

        toast.Position = UDim2.new(1, 100, 0, 0)
        TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.new() }):Play()
        task.delay(duration or 3, function()
            if toast.Parent then
                local tw = TweenService:Create(toast, TweenInfo.new(0.3), { Position = UDim2.new(1, 100, 0, 0) })
                tw:Play()
                tw.Completed:Connect(function() toast:Destroy() end)
            end
        end)
    end

    -- ── main window ────────────────────────────────────────
    local main = inst("Frame", {
        Size = UDim2.new(0, WIN_W, 0, WIN_H),
        Position = UDim2.new(0.5, -WIN_W / 2, 0.5, -WIN_H / 2),
        BackgroundColor3 = WHITE, BorderSizePixel = 0, Active = true, ClipsDescendants = true,
    }, gui)
    local mainCorner = corner(main, 16)
    inst("UIGradient", { Rotation = 90, Color = ColorSequence.new(THEME.WinTop, THEME.WinBottom) }, main)
    stroke(main, THEME.Ink, 4)

    -- ── top bar ────────────────────────────────────────────
    local topBar = frame(main, UDim2.new(1, 0, 0, TOP_H), nil, THEME.Navy)
    frame(topBar, UDim2.new(1, 0, 0, 3), UDim2.new(0, 0, 1, -3), THEME.Ink)

    -- ── window controls: close / minimize (notch) / maximize-restore ──
    local function dot(x, color, glyph, onClick)
        local d = inst("TextButton", {
            Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(0, x, 0.5, -8),
            BackgroundColor3 = color, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
            Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = THEME.Ink,
        }, topBar)
        corner(d, 8)
        stroke(d, THEME.Ink, 2)
        local icon
        d.MouseEnter:Connect(function()
            if icon then icon:Destroy() end
            icon = drawIcon(d, glyph(), 9, THEME.Ink)
            icon.Position = UDim2.new(0.5, -4, 0.5, -4)
        end)
        d.MouseLeave:Connect(function()
            if icon then icon:Destroy() icon = nil end
        end)
        d.MouseButton1Click:Connect(onClick)
        return d
    end

    local savedRect -- size/position before maximizing
    local restoreRect -- size/position before minimizing
    local function tweenMain(size, pos, time, style)
        TweenService:Create(main, TweenInfo.new(time or 0.3, style or Enum.EasingStyle.Quint), { Size = size, Position = pos }):Play()
    end

    function Window:SetSize(w, h)
        if maximized or minimized then return end
        WIN_W, WIN_H = math.clamp(w, MIN_W, MAX_W), math.clamp(h, MIN_H, MAX_H)
        main.Size = UDim2.new(0, WIN_W, 0, WIN_H)
    end
    function Window:ResetSize()
        if maximized then
            maximized = false
            WIN_W, WIN_H = DEF_W, DEF_H
            tweenMain(UDim2.new(0, DEF_W, 0, DEF_H), UDim2.new(0.5, -DEF_W / 2, 0.5, -DEF_H / 2))
        else
            Window:SetSize(DEF_W, DEF_H)
        end
    end

    function Window:Maximize()
        if minimized or maximized then return end
        savedRect = { pos = main.Position, size = main.Size, w = WIN_W, h = WIN_H }
        local vs = gui.AbsoluteSize
        local w, h = math.floor(vs.X * 0.94), math.floor(vs.Y * 0.92)
        maximized = true
        WIN_W, WIN_H = w, h
        tweenMain(UDim2.new(0, w, 0, h), UDim2.fromOffset(math.floor((vs.X - w) / 2), math.floor((vs.Y - h) / 2)))
    end
    function Window:RestoreSize()
        if not maximized or not savedRect then return end
        maximized = false
        WIN_W, WIN_H = savedRect.w, savedRect.h
        tweenMain(savedRect.size, savedRect.pos, 0.3, Enum.EasingStyle.Back)
    end
    function Window:ToggleMaximize()
        if maximized then Window:RestoreSize() else Window:Maximize() end
    end

    -- ── Dynamic-Island style notch (shown while minimized) ──
    local NOTCH_H = 46
    local notch = inst("TextButton", {
        Size = UDim2.new(0, 200, 0, NOTCH_H), AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 8), BackgroundColor3 = THEME.Navy, AutoButtonColor = false,
        Text = "", BorderSizePixel = 0, Visible = false, ClipsDescendants = true, ZIndex = 60,
    }, gui)
    corner(notch, 23)
    stroke(notch, THEME.Ink, 3)
    local nLogoHolder, nLogo = buildLogo(notch, 30)
    nLogoHolder.Position = UDim2.new(0, 14, 0.5, -15)
    local nTitle = label(notch, { Size = UDim2.new(1, -104, 0, 20), Pos = UDim2.new(0, 54, 0, 5), TS = 10,
        Text = "MR CRAZY", Color = THEME.BarText, Truncate = true })
    local nSub = label(notch, { Size = UDim2.new(1, -104, 0, 16), Pos = UDim2.new(0, 54, 0, 25), TS = 8,
        Text = "", Color = THEME.BarSub, Truncate = true })
    local nBadge = frame(notch, UDim2.new(0, 28, 0, 28), UDim2.new(1, -42, 0.5, -14), THEME.PillOff)
    corner(nBadge, 14)
    stroke(nBadge, THEME.Ink, 2)
    local nBadgeText = label(nBadge, { Size = UDim2.new(1, 0, 1, 0), TS = 10, Text = "", Color = THEME.Ink,
        Align = Enum.TextXAlignment.Center })

    local popActive, popToken, rotateIndex = false, 0, 0
    local nBadgeIcon
    local function applyNotch(width, height, title, sub, badgeColor, badgeText, badgeIcon)
        nTitle.Text, nSub.Text = title, sub
        nBadge.BackgroundColor3 = badgeColor
        nBadgeText.Text = badgeText
        if nBadgeIcon then nBadgeIcon:Destroy() nBadgeIcon = nil end
        if badgeIcon then
            nBadgeIcon = drawIcon(nBadge, badgeIcon, 18, THEME.Ink)
            nBadgeIcon.Position = UDim2.new(0.5, -9, 0.5, -9)
        end
        TweenService:Create(notch, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Size = UDim2.new(0, width, 0, height) }):Play()
    end
    local function notchWidth() return #activityOrder > 0 and 250 or 200 end
    local function refreshNotch()
        if popActive then return end
        local n = #activityOrder
        if n == 0 then
            applyNotch(200, NOTCH_H, config.ShortName or "MR CRAZY", "Idle • tap to open", THEME.PillOff, "", "bolt")
        else
            local id = activityOrder[(rotateIndex % n) + 1]
            applyNotch(250, NOTCH_H, activities[id], n .. " running • tap to open", THEME.Green, tostring(n))
        end
    end
    notchPop = function(title, text, tone, duration, icon)
        popActive = true
        popToken += 1
        local token = popToken
        applyNotch(340, 60, tostring(title), tostring(text), resolveTone(tone), "", icon or "alert")
        task.delay(duration or 2.5, function()
            if token ~= popToken or not alive then return end
            popActive = false
            refreshNotch()
        end)
    end

    -- ── logos (top bar + notch) ──
    local logoStops = {}
    local topLogoHolder, topLogo
    local function updateLogoMood()
        for _, stop in ipairs(logoStops) do stop() end
        logoStops = {}
        local fast = #activityOrder > 0
        if topLogo then table.insert(logoStops, startLogoAnim(topLogo, fast)) end
        table.insert(logoStops, startLogoAnim(nLogo, fast))
    end

    -- ── running activities (shown in the notch) ──
    function Window:AddActivity(id, text, silent)
        if not activities[id] then table.insert(activityOrder, id) end
        activities[id] = text or id
        updateLogoMood()
        if minimized and not silent then notchPop("Started", activities[id], "Green", 2, "play") else refreshNotch() end
    end
    function Window:RemoveActivity(id, silent)
        local text = activities[id]
        if not text then return end
        activities[id] = nil
        table.remove(activityOrder, table.find(activityOrder, id))
        updateLogoMood()
        if minimized and not silent then notchPop("Stopped", text, "Red", 1.6, "stop") else refreshNotch() end
    end
    function Window:GetActivities()
        local out = {}
        for _, id in ipairs(activityOrder) do table.insert(out, activities[id]) end
        return out
    end

    -- ── minimize -> notch  /  restore ──
    local function notchTopLeft(width)
        return UDim2.fromOffset(math.floor((gui.AbsoluteSize.X - width) / 2), 8)
    end
    function Window:Minimize()
        if minimized or not alive then return end
        minimized = true
        restoreRect = { pos = main.Position, size = main.Size }
        refreshNotch()
        local w = notchWidth()
        TweenService:Create(main, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
            Size = UDim2.new(0, w, 0, NOTCH_H), Position = notchTopLeft(w) }):Play()
        TweenService:Create(mainCorner, TweenInfo.new(0.3), { CornerRadius = UDim.new(0, 23) }):Play()
        task.delay(0.3, function()
            if not alive or not minimized then return end
            main.Visible = false
            notch.Visible = not hidden
        end)
    end
    function Window:Restore()
        if not minimized or not alive then return end
        minimized = false
        popActive = false
        popToken += 1
        local w = notch.Size.X.Offset
        notch.Visible = false
        main.Size = UDim2.new(0, w, 0, NOTCH_H)
        main.Position = notchTopLeft(w)
        main.Visible = not hidden
        TweenService:Create(main, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = restoreRect.size, Position = restoreRect.pos }):Play()
        TweenService:Create(mainCorner, TweenInfo.new(0.3), { CornerRadius = UDim.new(0, 16) }):Play()
    end
    notch.MouseButton1Click:Connect(function() Window:Restore() end)

    function Window:SetVisible(v)
        hidden = not v
        main.Visible = v and not minimized
        notch.Visible = v and minimized
    end
    function Window:Destroy()
        if not alive then return end
        alive = false
        for _, stop in ipairs(logoStops) do stop() end
        for _, c in ipairs(conns) do c:Disconnect() end
        gui:Destroy()
        if config.OnClose then task.spawn(config.OnClose) end
    end
    -- false once the window was closed (red button, Destroy, or re-running the script)
    function Window:IsAlive() return alive end
    gui.Destroying:Connect(function()
        if alive then
            alive = false
            for _, c in ipairs(conns) do c:Disconnect() end
            if config.OnClose then task.spawn(config.OnClose) end
        end
    end)

    dot(14, THEME.Red, function() return "x" end, function() Window:Destroy() end)
    dot(38, THEME.Gold, function() return "minus" end, function() Window:Minimize() end)
    dot(62, THEME.Green, function() return maximized and "restore" or "plus" end, function() Window:ToggleMaximize() end)

    local titleX = 96
    if config.LogoId then
        inst("ImageLabel", {
            Size = UDim2.new(0, 34, 0, 34), Position = UDim2.new(0, 90, 0.5, -17),
            BackgroundTransparency = 1, Image = config.LogoId,
        }, topBar)
        titleX = 136
    elseif config.Logo ~= false then
        topLogoHolder, topLogo = buildLogo(topBar, 38)
        topLogoHolder.Position = UDim2.new(0, 92, 0.5, -19)
        titleX = 138
    end
    updateLogoMood()
    refreshNotch()

    task.spawn(function() -- rotate through running activities while minimized
        while alive do
            task.wait(2.5)
            if alive and minimized and #activityOrder > 1 and not popActive then
                rotateIndex += 1
                refreshNotch()
            end
        end
    end)

    local rightReserve = 222 -- space taken by the DISCORD / WEB buttons
    label(topBar, { Size = UDim2.new(1, -(titleX + rightReserve), 0, 26), Pos = UDim2.new(0, titleX, 0, 7), TS = 12,
        Text = config.Title or "MR CRAZY", Color = THEME.BarText, Truncate = true })
    local subLbl = label(topBar, { Size = UDim2.new(1, -(titleX + rightReserve), 0, 20), Pos = UDim2.new(0, titleX, 0, 34),
        TS = 9, Text = config.Subtitle or "", Color = THEME.BarSub, Truncate = true })

    -- fixed DISCORD / WEB buttons
    local function topButton(xFromRight, width, text, fill, iconId, iconName, onClick)
        local b = inst("TextButton", {
            Size = UDim2.new(0, width, 0, 34), Position = UDim2.new(1, -xFromRight, 0.5, -17),
            BackgroundColor3 = fill, AutoButtonColor = false, BorderSizePixel = 0,
            Text = text, Font = FONT, TextSize = fs(11), TextColor3 = WHITE,
            TextStrokeColor3 = THEME.Ink, TextStrokeTransparency = 0,
        }, topBar)
        corner(b, 9)
        stroke(b, THEME.Ink, 3)
        inst("UIPadding", { PaddingLeft = UDim.new(0, 24) }, b)
        if iconId then
            inst("ImageLabel", {
                Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(0, -22, 0.5, -10),
                BackgroundTransparency = 1, Image = iconId,
            }, b)
        else
            local ic = drawIcon(b, iconName, 18, WHITE)
            ic.Position = UDim2.new(0, -22, 0.5, -9)
        end
        b.MouseButton1Down:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.06), { Position = UDim2.new(1, -xFromRight, 0.5, -15) }):Play()
        end)
        local function release()
            TweenService:Create(b, TweenInfo.new(0.12, Enum.EasingStyle.Back), {
                Position = UDim2.new(1, -xFromRight, 0.5, -17) }):Play()
        end
        b.MouseButton1Up:Connect(release)
        b.MouseLeave:Connect(release)
        b.MouseButton1Click:Connect(onClick)
        return b
    end

    local function copyLink(name, url, fill)
        if not url or url == "" then
            Window:Notify(name, name .. " link is not set", 2.5, "Red")
        elseif copyText(url) then
            Window:Notify(name, (name == "Discord" and "Discord server" or "Website") .. " link copied", 2.5, fill)
        else
            Window:Notify(name, "Clipboard not supported: " .. url, 5, "Gold")
        end
    end

    topButton(16 + 82, 82, "WEB", THEME.Sky, config.WebIcon, "globe", function()
        copyLink("Website", config.WebsiteUrl, "Blue")
    end)
    topButton(16 + 82 + 8 + 116, 116, "DISCORD", THEME.Discord, config.DiscordIcon, "discord", function()
        copyLink("Discord", config.DiscordUrl, "Blue")
    end)

    -- ── sidebar + pages ────────────────────────────────────
    local sidebar = frame(main, UDim2.new(0, SIDE_W, 1, -TOP_H), UDim2.new(0, 0, 0, TOP_H), THEME.Navy)
    frame(sidebar, UDim2.new(0, 3, 1, 0), UDim2.new(1, -3, 0, 0), THEME.Ink)

    local tabList = inst("ScrollingFrame", {
        Size = UDim2.new(1, -16, 1, -20), Position = UDim2.new(0, 8, 0, 10),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
        ScrollBarImageColor3 = THEME.Sky, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, sidebar)
    inst("UIListLayout", { Padding = UDim.new(0, 8) }, tabList)

    local pages = frame(main, UDim2.new(1, -SIDE_W - 24, 1, -TOP_H - 20), UDim2.new(0, SIDE_W + 12, 0, TOP_H + 10))

    -- ── drag + resize ──────────────────────────────────────
    local dragState, resizeState
    local sizeToken = 0

    topBar.InputBegan:Connect(function(i)
        if isPress(i) and not maximized and not minimized then dragState = { start = i.Position, pos = main.Position } end
    end)

    local function handle(size, pos, mx, my, glyph)
        local h = inst("TextButton", {
            Size = size, Position = pos, Text = "", AutoButtonColor = false,
            BackgroundColor3 = THEME.Sky, BackgroundTransparency = 1, BorderSizePixel = 0,
            ZIndex = 20, Font = Enum.Font.GothamBold, TextSize = 18,
            TextTransparency = 1,
        }, main)
        if glyph then
            local ic = drawIcon(h, glyph, 18, THEME.Gold)
            ic.Position = UDim2.new(0, 4, 0, 4)
        end
        h.MouseEnter:Connect(function()
            if not glyph then h.BackgroundTransparency = 0.6 end
        end)
        h.MouseLeave:Connect(function()
            if not glyph then h.BackgroundTransparency = 1 end
        end)
        h.InputBegan:Connect(function(i)
            if minimized or maximized or not isPress(i) then return end
            local o = main.AbsolutePosition - gui.AbsolutePosition
            main.Position = UDim2.fromOffset(o.X, o.Y) -- pin top-left, grow to bottom-right
            resizeState = { start = i.Position, w = WIN_W, h = WIN_H, mx = mx, my = my }
        end)
    end
    handle(UDim2.new(0, 10, 1, -TOP_H - 28), UDim2.new(1, -10, 0, TOP_H), 1, 0)
    handle(UDim2.new(1, -40, 0, 10), UDim2.new(0, 0, 1, -10), 0, 1)
    handle(UDim2.new(0, 26, 0, 26), UDim2.new(1, -26, 1, -26), 1, 1, "grip")

    onSignal(UserInputService.InputChanged, function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        if resizeState then
            local d = i.Position - resizeState.start
            Window:SetSize(resizeState.w + d.X * resizeState.mx, resizeState.h + d.Y * resizeState.my)
            subLbl.Text = string.format("Size %dx%d", WIN_W, WIN_H)
        elseif dragState then
            local d, p = i.Position - dragState.start, dragState.pos
            main.Position = UDim2.new(p.X.Scale, p.X.Offset + d.X, p.Y.Scale, p.Y.Offset + d.Y)
        end
    end)
    onSignal(UserInputService.InputEnded, function(i)
        if not isPress(i) then return end
        if resizeState then
            sizeToken += 1
            local token = sizeToken
            task.delay(1.5, function()
                if token == sizeToken and subLbl.Parent then subLbl.Text = config.Subtitle or "" end
            end)
        end
        dragState, resizeState = nil, nil
    end)

    if config.ToggleKey then
        onSignal(UserInputService.InputBegan, function(i, processed)
            if not processed and i.KeyCode == config.ToggleKey then Window:SetVisible(hidden) end
        end)
    end

    -- ══════════════════════════════════════════════════════
    -- TABS + WIDGETS
    -- ══════════════════════════════════════════════════════
    local activeTab = nil
    local tabs = {}

    local function card(page, height)
        local c = inst("Frame", { Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = THEME.Card, BorderSizePixel = 0 }, page)
        corner(c, 12)
        local s = stroke(c, THEME.Ink, 3)
        return c, s
    end

    function Window:CreateTab(tabName, tabIcon)
        local page = inst("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = THEME.Sky, Visible = false,
            AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
        }, pages)
        inst("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, page)
        inst("UIPadding", {
            PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6),
            PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
        }, page)

        local btn = inst("TextButton", {
            Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = THEME.TabBg,
            Text = "", AutoButtonColor = false, BorderSizePixel = 0,
        }, tabList)
        corner(btn, 9)
        local btnStroke = stroke(btn, THEME.Ink, 2)
        local tabIconHolder
        if tabIcon and ICONS[tabIcon] then
            tabIconHolder = drawIcon(btn, tabIcon, 18, THEME.Ice)
            tabIconHolder.Position = UDim2.new(0, 17, 0.5, -9)
        elseif tabIcon then
            label(btn, { Size = UDim2.new(0, 28, 1, 0), Pos = UDim2.new(0, 12, 0, 0), TS = 12,
                Text = tabIcon, Color = THEME.BarText, Align = Enum.TextXAlignment.Center })
        end
        local nameLbl = label(btn, { Size = UDim2.new(1, -52, 1, 0), Pos = UDim2.new(0, 46, 0, 0), TS = 11,
            Text = tabName, Color = THEME.Ice })
        local bar = frame(btn, UDim2.new(0, 3, 0.6, 0), UDim2.new(0, 3, 0, 0), THEME.Ink)
        bar.Position = UDim2.new(0, 3, 0.2, 0)
        corner(bar, 2)

        local function paint()
            local active = activeTab == tabName
            btn.BackgroundColor3 = active and THEME.Gold or THEME.TabBg
            nameLbl.TextColor3 = active and THEME.Ink or THEME.Ice
            if tabIconHolder then recolorIcon(tabIconHolder, active and THEME.Ink or THEME.Ice) end
            bar.Visible = active
        end
        tabs[tabName] = { Page = page, Paint = paint }
        btn.MouseButton1Click:Connect(function()
            for _, t in pairs(tabs) do t.Page.Visible = false end
            page.Visible = true
            activeTab = tabName
            for _, t in pairs(tabs) do t.Paint() end
        end)
        if not activeTab then
            page.Visible = true
            activeTab = tabName
        end
        for _, t in pairs(tabs) do t.Paint() end

        local Tab = {}

        function Tab:CreateSection(title)
            local sec = frame(page, UDim2.new(1, 0, 0, 34))
            label(sec, { Size = UDim2.new(1, 0, 1, 0), TS = 11, Text = "• " .. string.upper(title), Color = THEME.Gold })
        end

        function Tab:CreateButton(text, subText, tone, onClick)
            -- accepted forms: (text, cb) (text, tone, cb) (text, sub, cb) (text, sub, tone, cb)
            if type(subText) == "function" then
                onClick, tone, subText = subText, nil, nil
            elseif type(tone) == "function" then
                onClick = tone
                if type(subText) == "string" and not Library.Tones[subText] then
                    tone = nil -- plain description text
                else
                    tone, subText = subText, nil -- tone name / Color3
                end
            end
            local fill = resolveTone(tone)
            local dark = luminance(fill) > 0.72
            local txtColor = dark and THEME.Ink or WHITE

            local holder = frame(page, UDim2.new(1, 0, 0, subText and 62 or 48))
            local shadow = frame(holder, UDim2.new(1, 0, 1, -LIFT), UDim2.new(0, 0, 0, LIFT), fill:Lerp(Color3.new(), 0.55))
            corner(shadow, 9)
            local b = inst("TextButton", {
                Size = UDim2.new(1, 0, 1, -LIFT), BackgroundColor3 = fill, Text = "",
                AutoButtonColor = false, BorderSizePixel = 0, ClipsDescendants = true,
            }, holder)
            corner(b, 9)
            stroke(b, THEME.Ink, 3)

            local function styled(l)
                if not dark then
                    l.TextStrokeColor3, l.TextStrokeTransparency = THEME.Ink, 0
                end
                return l
            end
            styled(label(b, { Size = UDim2.new(1, -64, 0, 24), Pos = UDim2.new(0, 16, 0, subText and 6 or 10),
                TS = 12, Text = text, Color = txtColor }))
            if subText then
                styled(label(b, { Size = UDim2.new(1, -64, 0, 20), Pos = UDim2.new(0, 16, 0, 31),
                    TS = 10, Text = subText, Color = txtColor }))
            end
            local badge = frame(b, UDim2.new(0, 30, 0, 30), UDim2.new(1, -44, 0.5, -15), dark and Color3.new() or WHITE)
            badge.BackgroundTransparency = 0.82
            corner(badge, 9)
            local arrowIcon = drawIcon(badge, "arrow", 18, txtColor)
            arrowIcon.Position = UDim2.new(0.5, -9, 0.5, -9)

            b.MouseButton1Down:Connect(function()
                TweenService:Create(b, TweenInfo.new(0.07), { Position = UDim2.new(0, 0, 0, LIFT) }):Play()
            end)
            local function release()
                TweenService:Create(b, TweenInfo.new(0.14, Enum.EasingStyle.Back), { Position = UDim2.new() }):Play()
            end
            b.MouseButton1Up:Connect(release)
            b.MouseLeave:Connect(release)
            b.MouseButton1Click:Connect(function() if onClick then onClick() end end)
        end

        function Tab:CreateToggle(title, subText, default, onToggle)
            if type(subText) == "boolean" or type(subText) == "function" then
                onToggle, default, subText = default, subText, nil
            end
            local on = default or false
            local c, cStroke = card(page, subText and 66 or 54)
            label(c, { Size = UDim2.new(1, -96, 0, 24), Pos = UDim2.new(0, 16, 0, subText and 8 or 15), TS = 11, Text = title })
            if subText then
                label(c, { Size = UDim2.new(1, -96, 0, 20), Pos = UDim2.new(0, 16, 0, 35), TS = 9,
                    Text = subText, Color = THEME.TextSub })
            end
            local pill = inst("TextButton", {
                Size = UDim2.new(0, 50, 0, 26), Position = UDim2.new(1, -66, 0.5, -13),
                Text = "", AutoButtonColor = false, BorderSizePixel = 0,
            }, c)
            corner(pill, 13)
            stroke(pill, THEME.Ink, 2)
            local knob = frame(pill, UDim2.new(0, 20, 0, 20), nil, WHITE)
            corner(knob, 10)

            local function paint(tween)
                local info = TweenInfo.new(tween and 0.2 or 0, Enum.EasingStyle.Back)
                TweenService:Create(pill, info, { BackgroundColor3 = on and THEME.Green or THEME.PillOff }):Play()
                TweenService:Create(knob, info, {
                    Position = on and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10) }):Play()
                cStroke.Color = on and THEME.Sky or THEME.Ink
            end
            paint(false)
            local activityId = "toggle:" .. tostring(title)
            local function set(v, silent)
                on = v and true or false
                paint(true)
                if config.AutoActivity ~= false then
                    if on then Window:AddActivity(activityId, title, silent) else Window:RemoveActivity(activityId, silent) end
                end
                if onToggle and not silent then onToggle(on) end
            end
            if on and config.AutoActivity ~= false then Window:AddActivity(activityId, title, true) end
            pill.MouseButton1Click:Connect(function() set(not on) end)
            return { Set = function(_, v) set(v, true) end, Get = function() return on end }
        end

        function Tab:CreateSlider(title, subText, minV, maxV, default, suffix, onChange)
            if type(subText) == "number" then
                onChange, suffix, default, maxV, minV, subText = suffix, default, maxV, minV, subText, nil
            end
            suffix = suffix or ""
            local value = math.clamp(default or minV, minV, maxV)
            local c = card(page, subText and 86 or 68)
            label(c, { Size = UDim2.new(1, -140, 0, 24), Pos = UDim2.new(0, 16, 0, 8), TS = 11, Text = title })
            if subText then
                label(c, { Size = UDim2.new(1, -32, 0, 20), Pos = UDim2.new(0, 16, 0, 33), TS = 9,
                    Text = subText, Color = THEME.TextSub })
            end
            local valLbl = label(c, { Size = UDim2.new(0, 110, 0, 24), Pos = UDim2.new(1, -126, 0, 8), TS = 11,
                Text = tostring(value) .. suffix, Color = THEME.SkyDark, Align = Enum.TextXAlignment.Right })

            local track = frame(c, UDim2.new(1, -32, 0, 10), UDim2.new(0, 16, 0, subText and 66 or 46), THEME.Track)
            corner(track, 5)
            local pct0 = (value - minV) / (maxV - minV)
            local fill = frame(track, UDim2.new(pct0, 0, 1, 0), nil, THEME.Sky)
            corner(fill, 5)
            local knob = frame(track, UDim2.new(0, 20, 0, 20), UDim2.new(pct0, -10, 0.5, -10), WHITE)
            corner(knob, 10)
            stroke(knob, THEME.Ink, 2)

            local function apply(v, silent)
                value = math.clamp(math.floor(v), minV, maxV)
                local pct = (value - minV) / (maxV - minV)
                fill.Size = UDim2.new(pct, 0, 1, 0)
                knob.Position = UDim2.new(pct, -10, 0.5, -10)
                valLbl.Text = tostring(value) .. suffix
                if onChange and not silent then onChange(value) end
            end
            local dragging = false
            local function fromX(x)
                local pct = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                apply(minV + (maxV - minV) * pct)
            end
            track.InputBegan:Connect(function(i)
                if isPress(i) then dragging = true; fromX(i.Position.X) end
            end)
            onSignal(UserInputService.InputChanged, function(i)
                if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                    fromX(i.Position.X)
                end
            end)
            onSignal(UserInputService.InputEnded, function(i) if isPress(i) then dragging = false end end)
            return { Set = function(_, v) apply(v, true) end, Get = function() return value end }
        end

        function Tab:CreateDropdown(title, subText, options, default, onSelect)
            if type(subText) == "table" then
                onSelect, default, options, subText = default, options, subText, nil
            end
            options = options or {}
            local selected = default or options[1] or "Select"
            local baseH = subText and 66 or 54
            local ROW, GAP, MAX_ROWS = 32, 6, 6
            local isOpen = false

            local c, cStroke = card(page, baseH)
            c.ClipsDescendants = true
            label(c, { Size = UDim2.new(0.5, -16, 0, 24), Pos = UDim2.new(0, 16, 0, subText and 8 or 15), TS = 11, Text = title })
            if subText then
                label(c, { Size = UDim2.new(0.5, -16, 0, 20), Pos = UDim2.new(0, 16, 0, 35), TS = 9,
                    Text = subText, Color = THEME.TextSub })
            end
            local choice = inst("TextButton", {
                Size = UDim2.new(0.42, 0, 0, 34), Position = UDim2.new(0.58, -16, 0, (baseH - 34) / 2),
                BackgroundColor3 = THEME.Input, AutoButtonColor = false, BorderSizePixel = 0,
                Text = tostring(selected), Font = FONT, TextSize = fs(11), TextColor3 = THEME.Ink,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }, c)
            corner(choice, 9)
            stroke(choice, THEME.Ink, 2)
            inst("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 28) }, choice)
            local chevron = drawIcon(choice, "chevron", 18, THEME.Ink)
            chevron.Position = UDim2.new(1, 4, 0.5, -9)

            -- the option list opens inside the card (the card grows), so it never gets clipped by the page
            local list = inst("ScrollingFrame", {
                Size = UDim2.new(1, -32, 0, 0), Position = UDim2.new(0, 16, 0, baseH),
                BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
                ScrollBarImageColor3 = THEME.Sky, CanvasSize = UDim2.new(),
                AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false,
            }, c)
            inst("UIListLayout", { Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder }, list)
            inst("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2) }, list)

            local items = {}
            local setOpen
            local function closeSelf() setOpen(false) end

            local function paintItems()
                for _, it in ipairs(items) do
                    local sel = it.value == selected
                    it.button.BackgroundColor3 = sel and THEME.Gold or THEME.Input
                    it.check.Visible = sel
                end
            end
            local function listHeight()
                local n = math.min(#options, MAX_ROWS)
                return n * ROW + math.max(0, n - 1) * GAP + 4
            end

            local function rebuild()
                for _, it in ipairs(items) do it.button:Destroy() end
                items = {}
                for i, opt in ipairs(options) do
                    local b = inst("TextButton", {
                        Size = UDim2.new(1, 0, 0, ROW), BackgroundColor3 = THEME.Input, AutoButtonColor = false,
                        BorderSizePixel = 0, Text = tostring(opt), Font = FONT, TextSize = fs(10), TextColor3 = THEME.Ink,
                        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = i,
                    }, list)
                    corner(b, 8)
                    stroke(b, THEME.Ink, 2)
                    inst("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 30) }, b)
                    local check = drawIcon(b, "check", 18, THEME.Ink)
                    check.Position = UDim2.new(1, 6, 0.5, -9)
                    b.MouseEnter:Connect(function()
                        if opt ~= selected then b.BackgroundColor3 = THEME.Ice end
                    end)
                    b.MouseLeave:Connect(paintItems)
                    b.MouseButton1Click:Connect(function()
                        selected = opt
                        choice.Text = tostring(opt)
                        paintItems()
                        setOpen(false)
                        if onSelect then onSelect(opt) end
                    end)
                    table.insert(items, { value = opt, button = b, check = check })
                end
                paintItems()
            end

            setOpen = function(v)
                if v and #options == 0 then return end
                isOpen = v
                local lh = listHeight()
                list.Size = UDim2.new(1, -32, 0, lh)
                if v then list.Visible = true end
                cStroke.Color = v and THEME.Sky or THEME.Ink
                chevron.Rotation = v and 180 or 0
                local tw = TweenService:Create(c, TweenInfo.new(0.22, Enum.EasingStyle.Quad),
                    { Size = UDim2.new(1, 0, 0, v and (baseH + lh + 12) or baseH) })
                tw:Play()
                if v then
                    -- only one open list per window
                    if Window._openDropdown and Window._openDropdown ~= closeSelf then Window._openDropdown() end
                    Window._openDropdown = closeSelf
                else
                    tw.Completed:Connect(function() if not isOpen then list.Visible = false end end)
                    if Window._openDropdown == closeSelf then Window._openDropdown = nil end
                end
            end

            choice.MouseButton1Click:Connect(function() setOpen(not isOpen) end)
            rebuild()

            return {
                Get = function() return selected end,
                Set = function(_, value)
                    selected = value
                    choice.Text = tostring(value)
                    paintItems()
                end,
                Refresh = function(_, newOptions, resetFirst)
                    options = newOptions or {}
                    rebuild()
                    if resetFirst and options[1] then
                        selected = options[1]
                        choice.Text = tostring(selected)
                        paintItems()
                        if onSelect then onSelect(selected) end
                    end
                    if isOpen then setOpen(#options > 0) end
                end,
            }
        end

        function Tab:CreateStatCard(labelText, valueText, tone)
            local color = resolveTone(tone or "Gold")
            local c = frame(page, UDim2.new(1, 0, 0, 50), nil, THEME.Card)
            corner(c, 12)
            stroke(c, color, 3)
            label(c, { Size = UDim2.new(0.6, 0, 1, 0), Pos = UDim2.new(0, 16, 0, 0), TS = 11,
                Text = labelText, Color = THEME.TextMuted })
            local textColor = (color == THEME.Gold) and THEME.GoldText or color
            local val = label(c, { Size = UDim2.new(0.4, 0, 1, 0), Pos = UDim2.new(0.6, -16, 0, 0), TS = 11,
                Text = valueText, Color = textColor, Align = Enum.TextXAlignment.Right })
            return { SetValue = function(_, t) val.Text = tostring(t) end }
        end

        function Tab:CreateStatusCard(title, initial)
            local c = frame(page, UDim2.new(1, 0, 0, 96), nil, THEME.Input)
            corner(c, 9)
            stroke(c, THEME.Ink, 3)
            local sig = drawIcon(c, "signal", 18, THEME.SkyDark)
            sig.Position = UDim2.new(0, 14, 0, 10)
            label(c, { Size = UDim2.new(1, -52, 0, 22), Pos = UDim2.new(0, 40, 0, 8), TS = 10,
                Text = string.upper(title), Color = THEME.SkyDark })
            local l = label(c, { Size = UDim2.new(1, -28, 0, 56), Pos = UDim2.new(0, 14, 0, 34), TS = 10,
                Text = initial or "", Color = THEME.TextMuted, Wrap = true })
            return { SetText = function(_, t) l.Text = tostring(t) end }
        end

        function Tab:CreatePlayerSelector(title, subText, onChanged)
            if type(subText) == "function" then onChanged, subText = subText, nil end
            local c = card(page, 180)
            label(c, { Size = UDim2.new(1, -130, 0, 24), Pos = UDim2.new(0, 16, 0, 8), TS = 11, Text = title })
            label(c, { Size = UDim2.new(1, -130, 0, 20), Pos = UDim2.new(0, 16, 0, 33), TS = 9,
                Text = subText or "Select players to prioritize", Color = THEME.TextSub })
            local refresh = inst("TextButton", {
                Size = UDim2.new(0, 104, 0, 32), Position = UDim2.new(1, -118, 0, 10),
                BackgroundColor3 = THEME.Input, AutoButtonColor = false, BorderSizePixel = 0,
                Text = "Refresh", Font = FONT, TextSize = fs(10), TextColor3 = THEME.SkyDark,
            }, c)
            corner(refresh, 9)
            stroke(refresh, THEME.Ink, 2)
            inst("UIPadding", { PaddingLeft = UDim.new(0, 22) }, refresh)
            local refreshIcon = drawIcon(refresh, "refresh", 18, THEME.SkyDark)
            refreshIcon.Position = UDim2.new(0, -14, 0.5, -9)

            local list = inst("ScrollingFrame", {
                Size = UDim2.new(1, -32, 1, -68), Position = UDim2.new(0, 16, 0, 56),
                BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
                ScrollBarImageColor3 = THEME.Sky, AutomaticCanvasSize = Enum.AutomaticSize.Y,
                CanvasSize = UDim2.new(),
            }, c)
            inst("UIGridLayout", {
                CellSize = UDim2.new(0.48, 0, 0, 34), CellPadding = UDim2.new(0.04, 0, 0, 8),
            }, list)

            local selected = {} -- [UserId] = Player
            local function rebuild()
                for _, ch in ipairs(list:GetChildren()) do
                    if ch:IsA("GuiObject") then ch:Destroy() end
                end
                local others = {}
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer then table.insert(others, p) end
                end
                for id in pairs(selected) do
                    if not Players:GetPlayerByUserId(id) then selected[id] = nil end
                end
                if #others == 0 then
                    label(list, { Size = UDim2.new(1, 0, 0, 34), TS = 10, Text = "No other players in server", Color = THEME.TextSub })
                    return
                end
                for _, p in ipairs(others) do
                    local item = inst("TextButton", {
                        BackgroundColor3 = THEME.Input, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
                    }, list)
                    corner(item, 9)
                    local d = frame(item, UDim2.new(0, 16, 0, 16), UDim2.new(0, 8, 0.5, -8), THEME.PillOff)
                    corner(d, 8)
                    stroke(d, THEME.Ink, 2)
                    local nm = label(item, { Size = UDim2.new(1, -36, 1, 0), Pos = UDim2.new(0, 32, 0, 0), TS = 10,
                        Text = p.DisplayName or p.Name, Color = THEME.TextMuted, Truncate = true })
                    local function paint()
                        local s = selected[p.UserId] ~= nil
                        d.BackgroundColor3 = s and THEME.Green or THEME.PillOff
                        nm.TextColor3 = s and THEME.Ink or THEME.TextMuted
                    end
                    paint()
                    item.MouseButton1Click:Connect(function()
                        selected[p.UserId] = (not selected[p.UserId]) and p or nil
                        paint()
                        if onChanged then onChanged(p, selected[p.UserId] ~= nil) end
                    end)
                end
            end
            refresh.MouseButton1Click:Connect(function()
                rebuild()
                Window:Notify("Players", "List refreshed", 2, "Blue")
            end)
            onSignal(Players.PlayerAdded, rebuild)
            onSignal(Players.PlayerRemoving, function() task.defer(rebuild) end)
            rebuild()
            return {
                Refresh = rebuild,
                GetSelected = function()
                    local out = {}
                    for _, p in pairs(selected) do table.insert(out, p) end
                    return out
                end,
            }
        end

        return Tab
    end

    return Window
end

-- ══════════════════════════════════════════════════════════════
-- KEY WINDOW - "Shy Doge" (UI only; Lib.KeySystem drives it)
--   Lib:CreateKeyWindow({
--       Title, Subtitle, Footer, DefaultKey, Masked (default true),
--       GetKeyUrl, DiscordUrl, WebsiteUrl,
--       OnActivate = function(key) return ok, message, data end,   -- may yield (HTTP)
--       OnSuccess  = function(data) end,
--       OnClose    = function() end,
--   }) -> { SetStatus(text, "ok"|"error"|"info"), Close(), Submit() }
-- ══════════════════════════════════════════════════════════════
local KEY_PATTERN = "^MRC%-%w%w%w%w%-%w%w%w%w%-%w%w%w%w%-%w%w%w%w$"
local KEY_LEN = 19 -- alphanumeric characters in a full key (MRC + 16)
local KEY_PLACEHOLDER = "MRC-XXXX-XXXX-XXXX-XXXX"
local LOGO_EYES = { { 6, 12, 3, 3 }, { 13, 13, 6, 4 } } -- eye rects on the logo grid (x, y, w, h)
local STATUS_COLORS = { ok = C(160, 240, 120), error = C(255, 130, 135), info = THEME.Ice }

local function formatKey(raw)
    local alnum = (string.upper(raw or ""):gsub("[^%w]", "")):sub(1, KEY_LEN)
    if #alnum == 0 then return "", 0 end
    local parts = { alnum:sub(1, 3) }
    local i = 4
    while i <= #alnum do
        table.insert(parts, alnum:sub(i, i + 3))
        i += 4
    end
    return table.concat(parts, "-"), #alnum
end

local function maskKey(text)
    local out, n = {}, 0
    for c in text:gmatch(".") do
        if c == "-" then
            table.insert(out, "-")
        else
            n += 1
            table.insert(out, n <= 3 and c or "•")
        end
    end
    return table.concat(out)
end

-- ── animation helpers ─────────────────────────────────────────
local function tween(obj, time, props, style, dir, repeatCount, reverses)
    local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad,
        dir or Enum.EasingDirection.Out, repeatCount or 0, reverses or false), props)
    t:Play()
    return t
end

local function hop(obj, height, time)
    tween(obj, time or 0.09, { Position = UDim2.new(0, 0, 0, -(height or 6)) }, Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out, 0, true)
end

local function shakeX(obj, base, amount)
    task.spawn(function()
        for _, dx in ipairs({ amount, -amount, amount * 0.7, -amount * 0.7, amount * 0.3, 0 }) do
            obj.Position = UDim2.new(base.X.Scale, base.X.Offset + dx, base.Y.Scale, base.Y.Offset)
            task.wait(0.045)
        end
        obj.Position = base
    end)
end

local function tintLogo(logo, color, time)
    for _, f in ipairs(logo:GetChildren()) do
        if f:IsA("Frame") and f.Name ~= "Paw" then
            local base = f:GetAttribute("Base") or f.BackgroundColor3
            f:SetAttribute("Base", base)
            f.BackgroundColor3 = base
            tween(f, (time or 0.5) / 2, { BackgroundColor3 = base:Lerp(color, 0.65) }, Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out, 0, true)
        end
    end
end

local function newGui(name)
    for _, parent in ipairs({ CoreGui, LocalPlayer:FindFirstChild("PlayerGui"), gethui and gethui() or nil }) do
        local old = parent and parent:FindFirstChild(name)
        if old then old:Destroy() end
    end
    local gui = inst("ScreenGui", { Name = name, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
    local ok = pcall(function() gui.Parent = (gethui and gethui()) or CoreGui end)
    if not ok or not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    return gui
end

local function skyPanel(parent, w, h)
    local p = inst("Frame", {
        Size = UDim2.new(0, w, 0, h), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundColor3 = WHITE, BorderSizePixel = 0, Active = true, ClipsDescendants = true,
    }, parent)
    corner(p, 16)
    inst("UIGradient", { Rotation = 90, Color = ColorSequence.new(THEME.WinTop, THEME.WinBottom) }, p)
    stroke(p, THEME.Ink, 4)
    local scale = inst("UIScale", { Scale = 0.85 }, p)
    tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
    return p, scale
end

-- logo inside two wrapper layers: stage (placement) > holder (hops / shakes) > logo (idle animation)
local function logoStage(parent, height, pos)
    local cell = height / LOGO_ROWS_N
    local stage = frame(parent, UDim2.new(0, math.floor(LOGO_COLS * cell), 0, height), pos)
    local holder, logo = buildLogo(stage, height)
    return stage, holder, logo, cell
end

-- block button with a pixel icon + text, centred
local function iconButton(parent, size, pos, text, iconName, fill, onClick)
    local dark = luminance(fill) > 0.72
    local fg = dark and THEME.Ink or WHITE
    local holder = frame(parent, size, pos)
    local shadow = frame(holder, UDim2.new(1, 0, 1, -LIFT), UDim2.new(0, 0, 0, LIFT), fill:Lerp(Color3.new(), 0.55))
    corner(shadow, 10)
    local b = inst("TextButton", {
        Size = UDim2.new(1, 0, 1, -LIFT), BackgroundColor3 = fill, AutoButtonColor = false, BorderSizePixel = 0, Text = "",
    }, holder)
    corner(b, 10)
    stroke(b, THEME.Ink, 3)
    local row = inst("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1 }, b)
    inst("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
    }, row)
    local icon
    local function setIcon(name)
        if icon then icon:Destroy() end
        icon = name and drawIcon(row, name, 18, fg) or nil
        if icon then icon.LayoutOrder = 1 end
    end
    setIcon(iconName)
    local lbl = inst("TextLabel", {
        BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 24),
        Font = FONT, TextSize = fs(11), Text = text, TextColor3 = fg, LayoutOrder = 2,
        TextStrokeColor3 = THEME.Ink, TextStrokeTransparency = dark and 1 or 0, Visible = text ~= "",
    }, row)
    b.MouseButton1Down:Connect(function()
        tween(b, 0.07, { Position = UDim2.new(0, 0, 0, LIFT) })
    end)
    local function release()
        tween(b, 0.14, { Position = UDim2.new() }, Enum.EasingStyle.Back)
    end
    b.MouseButton1Up:Connect(release)
    b.MouseLeave:Connect(release)
    b.MouseButton1Click:Connect(onClick)
    return {
        Button = b, Holder = holder,
        SetText = function(_, t) lbl.Text = t end,
        SetIcon = function(_, n) setIcon(n) end,
        SetFill = function(_, color)
            b.BackgroundColor3 = color
            shadow.BackgroundColor3 = color:Lerp(Color3.new(), 0.55)
        end,
    }
end

-- ── shared logic every style uses ─────────────────────────────
local function newKeyContext(config, gui)
    local ctx = {
        gui = gui, config = config, conns = {}, listeners = {},
        key = "", count = 0, valid = false, masked = config.Masked ~= false,
        focused = false, busy = false, closed = false,
    }
    -- stop every loop / connection if the gui is destroyed from outside (e.g. reopened)
    gui.Destroying:Connect(function()
        if ctx.closed then return end
        ctx.closed = true
        for _, c in ipairs(ctx.conns) do c:Disconnect() end
    end)

    function ctx.on(name, fn)
        ctx.listeners[name] = ctx.listeners[name] or {}
        table.insert(ctx.listeners[name], fn)
    end
    function ctx.emit(name, ...)
        for _, fn in ipairs(ctx.listeners[name] or {}) do
            local ok, err = pcall(fn, ...)
            if not ok then warn("[MR CRAZY] key ui: " .. tostring(err)) end
        end
    end
    function ctx.track(conn) table.insert(ctx.conns, conn) return conn end
    function ctx.every(seconds, fn)
        task.spawn(function()
            while not ctx.closed do
                task.wait(seconds)
                if ctx.closed then break end
                local ok, err = pcall(fn)
                if not ok then warn("[MR CRAZY] key ui: " .. tostring(err)) end
            end
        end)
    end

    function ctx.setStatus(text, kind)
        if ctx.statusLabel then
            ctx.statusLabel.Text = text or ""
            ctx.statusLabel.TextColor3 = STATUS_COLORS[kind or "info"] or THEME.Ice
        end
        ctx.emit("status", text, kind)
    end
    function ctx.statusAt(parent, size, pos)
        ctx.statusLabel = label(parent, { Size = size, Pos = pos, TS = 10, Text = "", Color = THEME.Ice,
            Align = Enum.TextXAlignment.Center, Truncate = true })
        return ctx.statusLabel
    end

    function ctx.setMasked(v)
        ctx.masked = v
        ctx.emit("mask", v)
        ctx.emit("render")
    end
    function ctx.display()
        if ctx.key == "" then return "" end
        return ctx.masked and maskKey(ctx.key) or ctx.key
    end

    -- wires a TextBox: auto-format MRC-XXXX-..., uppercase, max length, focus and enter
    function ctx.bindBox(box)
        local guard = false
        box.ClearTextOnFocus = false
        ctx.track(box:GetPropertyChangedSignal("Text"):Connect(function()
            if guard then return end
            local formatted, n = formatKey(box.Text)
            local grew = n > ctx.count
            ctx.key, ctx.count = formatted, n
            ctx.valid = formatted:match(KEY_PATTERN) ~= nil
            if box.Text ~= formatted then
                guard = true
                box.Text = formatted
                box.CursorPosition = #formatted + 1
                guard = false
            end
            ctx.emit("input", n / KEY_LEN, ctx.valid, grew)
            ctx.emit("render")
        end))
        ctx.track(box.Focused:Connect(function()
            ctx.focused = true
            ctx.emit("focus", true)
            ctx.emit("render")
        end))
        ctx.track(box.FocusLost:Connect(function(enter)
            ctx.focused = false
            ctx.emit("focus", false)
            ctx.emit("render")
            if enter then ctx.submit() end
        end))
        ctx.box = box
        if config.DefaultKey and config.DefaultKey ~= "" then box.Text = config.DefaultKey end
    end

    function ctx.submit()
        if ctx.busy or ctx.closed then return end
        if not ctx.valid then
            ctx.setStatus(ctx.count == 0 and "Paste your key first" or "Key format: " .. KEY_PLACEHOLDER, "error")
            ctx.emit("fail")
            return
        end
        ctx.busy = true
        ctx.setStatus("Checking key...", "info")
        ctx.emit("checking", true)
        local validator = config.OnActivate or function() return false, "No validator set" end
        local ran, ok, message, data = pcall(validator, ctx.key)
        ctx.busy = false
        if ctx.closed then return end
        ctx.emit("checking", false)
        if ran and ok then
            ctx.setStatus(message or "Key accepted", "ok")
            ctx.emit("success")
            task.delay(config.SuccessDelay or 1.4, function()
                ctx.close(true)
                if config.OnSuccess then task.spawn(config.OnSuccess, data) end
            end)
        else
            ctx.setStatus(ran and (message or "Invalid key") or ("Unexpected error: " .. tostring(ok)), "error")
            ctx.emit("fail")
        end
    end

    function ctx.close(silent)
        if ctx.closed then return end
        ctx.closed = true
        for _, c in ipairs(ctx.conns) do c:Disconnect() end
        ctx.emit("close")
        task.delay(0.35, function() gui:Destroy() end)
        if not silent and config.OnClose then task.spawn(config.OnClose) end
    end

    function ctx.copy(url, doneText, missingText)
        if not url or url == "" then
            ctx.setStatus(missingText, "error")
        elseif copyText(url) then
            ctx.setStatus(doneText, "ok")
        else
            ctx.setStatus("Copy this link: " .. url, "info")
        end
    end

    -- GET KEY / DISCORD / WEBSITE in one row
    function ctx.linkRow(parent, x, y, width, height, compact)
        local gap = 8
        local w = (width - gap * 2) / 3
        local items = {
            { compact and "KEY" or "GET KEY", "key", THEME.Gold, config.GetKeyUrl, "Key page link copied - open it in your browser", "Key page link is not set" },
            { compact and "" or "DISCORD", "discord", THEME.Discord, config.DiscordUrl, "Discord server link copied", "Discord link is not set" },
            { compact and "" or "WEBSITE", "globe", THEME.Sky, config.WebsiteUrl, "Website link copied", "Website link is not set" },
        }
        for i, it in ipairs(items) do
            iconButton(parent, UDim2.new(0, w, 0, height), UDim2.new(0, x + (i - 1) * (w + gap), 0, y), it[1], it[2], it[3],
                function() ctx.copy(it[4], it[5], it[6]) end)
        end
    end

    -- standard key field: lock icon, live formatted / masked text, caret, show-hide button
    function ctx.keyField(parent, size, pos)
        local card = frame(parent, size, pos, THEME.Card)
        corner(card, 12)
        local cardStroke = stroke(card, THEME.Ink, 3)
        local lock = drawIcon(card, "lock", 18, THEME.TextSub)
        lock.Position = UDim2.new(0, 14, 0.5, -9)
        local box = inst("TextBox", {
            Size = UDim2.new(1, -100, 1, 0), Position = UDim2.new(0, 42, 0, 0), BackgroundTransparency = 1,
            Text = "", PlaceholderText = "", TextTransparency = 1, Font = FONT, TextSize = fs(11),
            TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.Ink, ClearTextOnFocus = false,
        }, card)
        local shown = label(card, { Size = UDim2.new(1, -100, 1, 0), Pos = UDim2.new(0, 42, 0, 0), TS = 11,
            Text = "", Color = THEME.Ink, Truncate = true })
        local eye = inst("TextButton", {
            Size = UDim2.new(0, 38, 0, 38), Position = UDim2.new(1, -48, 0.5, -19), BackgroundColor3 = THEME.Input,
            Text = "", AutoButtonColor = false, BorderSizePixel = 0,
        }, card)
        corner(eye, 9)
        stroke(eye, THEME.Ink, 2)
        local eyeIcon
        local function drawEye()
            if eyeIcon then eyeIcon:Destroy() end
            eyeIcon = drawIcon(eye, ctx.masked and "eyeoff" or "eye", 18, THEME.Ink)
            eyeIcon.Position = UDim2.new(0.5, -9, 0.5, -9)
        end
        drawEye()
        eye.MouseButton1Click:Connect(function() ctx.setMasked(not ctx.masked) end)

        local blink = true
        local function render()
            if ctx.key == "" then
                shown.Text = ctx.focused and (blink and "|" or "") or KEY_PLACEHOLDER
                shown.TextColor3 = THEME.TextSub
            else
                shown.Text = ctx.display() .. ((ctx.focused and blink) and "|" or "")
                shown.TextColor3 = THEME.Ink
            end
            lock.Visible = true
            cardStroke.Color = ctx.valid and THEME.Green or (ctx.focused and THEME.Sky or THEME.Ink)
        end
        ctx.on("render", render)
        ctx.on("mask", drawEye)
        ctx.on("fail", function()
            cardStroke.Color = THEME.Red
            shakeX(card, pos, 10)
            task.delay(0.6, render)
        end)
        ctx.every(0.5, function()
            blink = not blink
            if ctx.focused then render() end
        end)
        render()
        ctx.fieldBox = box
        return card, box
    end

    -- navy title bar with a close button; drags `target`
    function ctx.titleBar(panel, height, title, subtitle, textX)
        local bar = frame(panel, UDim2.new(1, 0, 0, height), nil, THEME.Navy)
        local line = frame(bar, UDim2.new(1, 0, 0, 3), UDim2.new(0, 0, 1, -3), THEME.Ink)
        local close = inst("TextButton", {
            Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(0, 16, 0.5, -8), BackgroundColor3 = THEME.Red,
            Text = "", AutoButtonColor = false, BorderSizePixel = 0,
        }, bar)
        corner(close, 8)
        stroke(close, THEME.Ink, 2)
        local xIcon = drawIcon(close, "x", 9, THEME.Ink)
        xIcon.Position = UDim2.new(0.5, -4, 0.5, -4)
        xIcon.Visible = false
        close.MouseEnter:Connect(function() xIcon.Visible = true end)
        close.MouseLeave:Connect(function() xIcon.Visible = false end)
        close.MouseButton1Click:Connect(function() ctx.close() end)
        local titleLbl = label(bar, { Size = UDim2.new(1, -(textX or 44) - 12, 0, 26), Pos = UDim2.new(0, textX or 44, 0, 7), TS = 12,
            Text = title, Color = THEME.BarText, Truncate = true })
        local subLbl = label(bar, { Size = UDim2.new(1, -(textX or 44) - 12, 0, 20), Pos = UDim2.new(0, textX or 44, 0, height - 26), TS = 9,
            Text = subtitle, Color = THEME.BarSub, Truncate = true })

        local dragStart, startPos
        bar.InputBegan:Connect(function(i)
            if isPress(i) and not ctx.islandMode then dragStart, startPos = i.Position, panel.Position end
        end)
        ctx.track(UserInputService.InputChanged:Connect(function(i)
            if dragStart and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                local d = i.Position - dragStart
                panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end))
        ctx.track(UserInputService.InputEnded:Connect(function(i)
            if isPress(i) then dragStart = nil end
        end))
        return bar, { close = close, title = titleLbl, sub = subLbl, line = line }
    end

    function ctx.closeWithScale(scale)
        ctx.on("close", function()
            tween(scale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        end)
    end

    return ctx
end

-- ══════════════════════════════════════════════════════════════
-- ISLAND NOTIFICATION - drops from the top of the screen like a Dynamic Island
--   Lib:Island({ Title, Text, Icon = "check", Tone = "Green", Duration = 3 })
-- ══════════════════════════════════════════════════════════════
function Library:Island(opts)
    opts = opts or {}
    local W, H = 320, 56
    local gui = newGui("MrCrazy_Island")
    local pill = inst("Frame", {
        Size = UDim2.new(0, W, 0, H), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10),
        BackgroundColor3 = THEME.Navy, BorderSizePixel = 0, ClipsDescendants = true,
    }, gui)
    corner(pill, H / 2)
    stroke(pill, THEME.Ink, 3)
    local scale = inst("UIScale", { Scale = 0.6 }, pill)
    tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)

    local _, holder, logo = logoStage(pill, 38, UDim2.new(0, 16, 0, 9))
    local stopAnim = startLogoAnim(logo, true)
    label(pill, { Size = UDim2.new(1, -130, 0, 26), Pos = UDim2.new(0, 64, 0, 7), TS = 12,
        Text = opts.Title or "MR CRAZY", Color = THEME.BarText, Truncate = true })
    label(pill, { Size = UDim2.new(1, -130, 0, 20), Pos = UDim2.new(0, 64, 0, 30), TS = 9,
        Text = opts.Text or "", Color = THEME.BarSub, Truncate = true })
    local badge = frame(pill, UDim2.new(0, 34, 0, 34), UDim2.new(1, -48, 0, 11), resolveTone(opts.Tone or "Green"))
    corner(badge, 17)
    stroke(badge, THEME.Ink, 2)
    local icon = drawIcon(badge, opts.Icon or "check", 18, THEME.Ink)
    icon.Position = UDim2.new(0.5, -9, 0.5, -9)
    task.delay(0.35, function() hop(holder, 10, 0.12) end)

    task.delay(opts.Duration or 3, function()
        tween(pill, 0.3, { Size = UDim2.new(0, 0, 0, H) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        task.delay(0.35, function()
            stopAnim()
            gui:Destroy()
        end)
    end)
end

-- breathing idle, covers its eyes with paws while you type a hidden key, peeks when you show it,
-- shakes its head on a wrong key, and collapses straight into the Island pill on success
local function buildShyDoge(ctx, config)
    local W, H = 420, 476
    local panel, scale = skyPanel(ctx.gui, W, H)
    local TEXT_X, LOGO_X = 110, 64 -- window layout of the drag bar: close, minimize, logo, title
    local bar, barParts = ctx.titleBar(panel, 56, config.Title, config.Subtitle, TEXT_X)
    local miniStage, miniHolder, miniLogo = logoStage(bar, 38, UDim2.new(0, LOGO_X, 0, 9))
    local stopMini = startLogoAnim(miniLogo, false)

    -- yellow minimize button next to the red close button
    local minimize = inst("TextButton", {
        Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(0, 40, 0.5, -8), BackgroundColor3 = THEME.Gold,
        Text = "", AutoButtonColor = false, BorderSizePixel = 0,
    }, bar)
    corner(minimize, 8)
    stroke(minimize, THEME.Ink, 2)
    local minusIcon = drawIcon(minimize, "minus", 9, THEME.Ink)
    minusIcon.Position = UDim2.new(0.5, -4, 0.5, -4)
    minusIcon.Visible = false
    minimize.MouseEnter:Connect(function() minusIcon.Visible = true end)
    minimize.MouseLeave:Connect(function() minusIcon.Visible = false end)

    -- closing: normal = shrink, as an island = the pill squeezes shut (same as the Island style)
    local PILL_W, PILL_H = 320, 56
    ctx.on("close", function()
        stopMini()
        if ctx.islandMode then
            tween(panel, 0.3, { Size = UDim2.new(0, 0, 0, PILL_H) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        else
            tween(scale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        end
    end)

    local panelCorner = panel:FindFirstChildOfClass("UICorner")
    local panelStroke = panel:FindFirstChildOfClass("UIStroke")
    local badge = frame(bar, UDim2.new(0, 34, 0, 34), UDim2.new(1, -48, 0, 11), THEME.Gold)
    badge.Visible = false
    corner(badge, 17)
    stroke(badge, THEME.Ink, 2)
    local badgePop = inst("UIScale", { Scale = 0 }, badge)
    local badgeIcon
    -- invisible button over the pill: tap the collapsed island to open the window again
    local reopen = inst("TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 20, Visible = false,
    }, bar)

    local savedPos -- window position before it became an island
    local function setBadge(iconName, color)
        if badgeIcon then badgeIcon:Destroy() end
        badge.BackgroundColor3 = color
        badgeIcon = drawIcon(badge, iconName, 18, THEME.Ink)
        badgeIcon.Position = UDim2.new(0.5, -9, 0.5, -9)
        badge.Visible = true
        badgePop.Scale = 0
        task.delay(0.25, function() tween(badgePop, 0.35, { Scale = 1 }, Enum.EasingStyle.Back) end)
    end

    -- the window collapses into a Dynamic-Island pill at the top of the screen
    local function toIsland(title, sub, iconName, color, tappable)
        if ctx.closed then return end
        if not ctx.islandMode then
            savedPos = panel.Position
            local abs = panel.AbsolutePosition - ctx.gui.AbsolutePosition
            panel.AnchorPoint = Vector2.new(0.5, 0)
            panel.Position = UDim2.fromOffset(abs.X + panel.AbsoluteSize.X / 2, abs.Y)
        end
        ctx.islandMode = true
        if ctx.box then ctx.box:ReleaseFocus() end
        tween(panel, 0.45, { Size = UDim2.new(0, PILL_W, 0, PILL_H), Position = UDim2.new(0.5, 0, 0, 10) }, Enum.EasingStyle.Back)
        if panelCorner then tween(panelCorner, 0.3, { CornerRadius = UDim.new(0, PILL_H / 2) }) end
        if panelStroke then tween(panelStroke, 0.3, { Thickness = 3 }) end

        barParts.line.Visible = false
        barParts.close.Visible = false
        minimize.Visible = false
        barParts.title.Text = title
        barParts.sub.Text = sub
        tween(miniStage, 0.35, { Position = UDim2.new(0, 16, 0, 9) }, Enum.EasingStyle.Back)
        tween(barParts.title, 0.35, { Position = UDim2.new(0, 64, 0, 7), Size = UDim2.new(1, -130, 0, 26) }, Enum.EasingStyle.Back)
        tween(barParts.sub, 0.35, { Position = UDim2.new(0, 64, 0, 30), Size = UDim2.new(1, -130, 0, 20) }, Enum.EasingStyle.Back)
        setBadge(iconName, color)
        reopen.Visible = tappable

        stopMini()
        stopMini = startLogoAnim(miniLogo, true)
        task.delay(0.45, function() hop(miniHolder, 10, 0.12) end)
    end

    -- the pill opens back into the full window where it was
    local function fromIsland()
        if ctx.closed or not ctx.islandMode then return end
        ctx.islandMode = false
        reopen.Visible = false
        badge.Visible = false
        local target = UDim2.new(savedPos.X.Scale, savedPos.X.Offset, savedPos.Y.Scale, savedPos.Y.Offset - H / 2)
        local t = tween(panel, 0.45, { Size = UDim2.new(0, W, 0, H), Position = target }, Enum.EasingStyle.Back)
        t.Completed:Connect(function()
            if ctx.islandMode or ctx.closed then return end
            panel.AnchorPoint = Vector2.new(0.5, 0.5)
            panel.Position = savedPos
        end)
        if panelCorner then tween(panelCorner, 0.3, { CornerRadius = UDim.new(0, 16) }) end
        if panelStroke then tween(panelStroke, 0.3, { Thickness = 4 }) end

        barParts.line.Visible = true
        barParts.close.Visible = true
        minimize.Visible = true
        barParts.title.Text = config.Title
        barParts.sub.Text = config.Subtitle
        tween(miniStage, 0.35, { Position = UDim2.new(0, LOGO_X, 0, 9) }, Enum.EasingStyle.Back)
        tween(barParts.title, 0.35, { Position = UDim2.new(0, TEXT_X, 0, 7), Size = UDim2.new(1, -TEXT_X - 12, 0, 26) }, Enum.EasingStyle.Back)
        tween(barParts.sub, 0.35, { Position = UDim2.new(0, TEXT_X, 0, 30), Size = UDim2.new(1, -TEXT_X - 12, 0, 20) }, Enum.EasingStyle.Back)

        stopMini()
        stopMini = startLogoAnim(miniLogo, false)
        task.delay(0.3, function() if ctx.box and not ctx.islandMode then ctx.box:CaptureFocus() end end)
    end

    minimize.MouseButton1Click:Connect(function()
        toIsland(config.ShortName or "MR CRAZY", "Tap to enter your key", "key", THEME.Gold, true)
    end)
    reopen.MouseButton1Click:Connect(fromIsland)

    local function morphToIsland(message)
        toIsland("Key accepted", message ~= "" and message or "Loading...", "check", THEME.Green, false)
    end

    local LOGO_H = 124
    local stage, holder, logo, cell = logoStage(panel, LOGO_H, UDim2.new(0.5, -math.floor(LOGO_COLS * LOGO_H / LOGO_ROWS_N / 2), 0, 72))
    logo.AnchorPoint = Vector2.new(0.5, 0.5)
    logo.Position = UDim2.new(0.5, 0, 0.5, 0)
    local breathe = inst("UIScale", { Scale = 1 }, logo)
    tween(breathe, 1.6, { Scale = 1.05 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

    -- paws (cover the eyes)
    local paws = {}
    for i, eye in ipairs(LOGO_EYES) do
        local x, y, w, h = eye[1] * cell - 5, eye[2] * cell - 5, eye[3] * cell + 10, eye[4] * cell + 10
        local paw = frame(logo, UDim2.new(0, w, 0, h), UDim2.new(0, x, 0, y + 70), LOGO_PALETTE[1])
        paw.Name = "Paw"
        paw.Visible = false
        paw.ZIndex = 5
        corner(paw, 8)
        stroke(paw, THEME.Ink, 2)
        for t = 0, 2 do
            local toe = frame(paw, UDim2.new(0, 4, 0, 6), UDim2.new((t + 1) / 4, -2, 0, 3), LOGO_PALETTE[3])
            toe.ZIndex = 6
        end
        paws[i] = { frame = paw, y = y }
    end
    local covered = false
    local function setCovered(v)
        if v == covered then return end
        covered = v
        for _, p in ipairs(paws) do
            if v then
                p.frame.Visible = true
                tween(p.frame, 0.3, { Position = UDim2.new(0, p.frame.Position.X.Offset, 0, p.y) }, Enum.EasingStyle.Back)
            else
                local t = tween(p.frame, 0.25, { Position = UDim2.new(0, p.frame.Position.X.Offset, 0, p.y + 70) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                t.Completed:Connect(function() if not covered then p.frame.Visible = false end end)
            end
        end
    end
    local function updatePaws()
        setCovered(ctx.masked and ctx.focused)
        tween(logo, 0.3, { Rotation = (ctx.focused and not ctx.masked) and 8 or 0 }, Enum.EasingStyle.Back)
    end

    ctx.keyField(panel, UDim2.new(1, -40, 0, 56), UDim2.new(0, 20, 0, 214))
    ctx.statusAt(panel, UDim2.new(1, -40, 0, 24), UDim2.new(0, 20, 0, 276))
    local activate = iconButton(panel, UDim2.new(1, -40, 0, 58), UDim2.new(0, 20, 0, 306), "ACTIVATE KEY", "check", THEME.Green, ctx.submit)
    ctx.linkRow(panel, 20, 376, W - 40, 46)
    label(panel, { Size = UDim2.new(1, -40, 0, 20), Pos = UDim2.new(0, 20, 0, 432), TS = 9,
        Text = "Hide your key and he won't peek", Color = THEME.BarSub, Align = Enum.TextXAlignment.Center })

    ctx.on("focus", updatePaws)
    ctx.on("mask", updatePaws)
    ctx.on("input", function(_, _, grew) if grew then hop(holder, 4, 0.07) end end)
    local thinking
    ctx.on("checking", function(on)
        if on then
            activate:SetText("CHECKING...")
            thinking = tween(logo, 0.35, { Rotation = 10 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
        else
            activate:SetText("ACTIVATE KEY")
            if thinking then thinking:Cancel() end
            logo.Rotation = 0
        end
    end)
    ctx.on("fail", function()
        tintLogo(logo, THEME.Red, 0.6)
        task.spawn(function()
            for _, r in ipairs({ -12, 12, -9, 9, -4, 0 }) do
                logo.Rotation = r
                task.wait(0.06)
            end
        end)
    end)
    -- correct key: no celebration, the window collapses straight into the island (like the Island style)
    ctx.on("success", function()
        morphToIsland(ctx.statusLabel and ctx.statusLabel.Text or "")
    end)
    ctx.bindBox(ctx.fieldBox)
end

function Library:CreateKeyWindow(config)
    config = config or {}
    config.Title = config.Title or "MR CRAZY • KEY SYSTEM"
    config.Subtitle = config.Subtitle or "Activate your key to unlock the script"
    config.SuccessDelay = config.SuccessDelay or 3.2 -- island morph + time on screen
    local gui = newGui(config.Name or "MrCrazy_KeySystem")
    local ctx = newKeyContext(config, gui)
    buildShyDoge(ctx, config)
    ctx.emit("render")
    return {
        SetStatus = function(_, text, kind) ctx.setStatus(text, kind) end,
        Close = function() ctx.close(true) end,
        Submit = function() ctx.submit() end,
    }
end

-- ══════════════════════════════════════════════════════════════
-- KEY SYSTEM - client for the website app-api (docs/LUA-INTEGRATION.md)
--   * HWID comes from the executor "*-Fingerprint" header; body hwid is a fallback
--   * key saved in MRCRAZY/key.txt, deleted on invalid_key / expired / revoked
--   * the full key is never printed
-- ══════════════════════════════════════════════════════════════
local HttpService = game:GetService("HttpService")

local KeySystem = {}

local DEFAULTS = {
    Api = "https://yarmjpvakthxvvqarxwq.supabase.co/functions/v1/app-api",
    Site = "https://mrcrazy.xyz",
    Discord = "https://discord.gg/PfnUrnYvg3",
    Folder = "MRCRAZY",
}

local function messages(site)
    return {
        invalid_key = "Key not found. Copy it again from " .. site .. "/profile",
        expired = "Your free key expired. Get a new one at " .. site .. "/free",
        revoked = "This key was turned off. Check your profile on the site.",
        banned = "Your account is suspended.",
        hwid_mismatch = "This key is linked to another device. Premium: use Reset device on your profile.",
        premium_only = "This game is for Premium players.",
        game_not_found = "This game isn't supported yet.",
        script_file_missing = "This script is being updated. Try again soon.",
        rate_limited = "Slow down and try again in a minute.",
        bad_request = "This executor isn't supported (no device id).",
        network = "Cannot reach the server. Check your connection.",
        no_request = "This executor isn't supported (no request function).",
        maintenance = "Under maintenance. Try again later.",
    }
end

-- request() is the sUNC standard; the rest are older aliases
local httpRequest = request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)

local function fallbackHwid()
    if type(gethwid) == "function" then
        local ok, id = pcall(gethwid)
        if ok and type(id) == "string" and #id > 0 then return id end
    end
    local ok, id = pcall(function() return game:GetService("RbxAnalyticsService"):GetClientId() end)
    if ok and type(id) == "string" and #id > 0 then return id end
    return nil
end

-- status, decoded JSON (or nil), raw body
local function call(api, method, route, body)
    if not httpRequest then return -1, nil, "" end
    local ok, response = pcall(httpRequest, {
        Url = api .. "/" .. route,
        Method = method,
        Headers = { ["Content-Type"] = "application/json" },
        Body = body and HttpService:JSONEncode(body) or nil,
    })
    if not ok or type(response) ~= "table" then return 0, nil, "" end
    local raw = response.Body or ""
    local decoded, data = pcall(HttpService.JSONDecode, HttpService, raw)
    return response.StatusCode or 0, (decoded and type(data) == "table") and data or nil, raw
end

local function keyFile(cfg) return (cfg.Folder or DEFAULTS.Folder) .. "/key.txt" end

local function savedKey(cfg)
    if cfg.SaveKey == false then return nil end
    local ok, value = pcall(function()
        return isfile and isfile(keyFile(cfg)) and readfile(keyFile(cfg))
    end)
    if ok and type(value) == "string" then
        value = value:gsub("%s+", "")
        if value ~= "" then return value end
    end
    return nil
end

local function saveKey(cfg, key)
    if cfg.SaveKey == false or not writefile then return end
    pcall(function()
        local folder = cfg.Folder or DEFAULTS.Folder
        if makefolder and isfolder and not isfolder(folder) then makefolder(folder) end
        writefile(keyFile(cfg), key)
    end)
end

local function forgetKey(cfg)
    pcall(function()
        if delfile and isfile and isfile(keyFile(cfg)) then delfile(keyFile(cfg)) end
    end)
end

local function hint(key) return "****-" .. key:sub(-4) end

local function newerVersion(remote, mine)
    if type(remote) ~= "string" or type(mine) ~= "string" then return false end
    local r, m = {}, {}
    for n in remote:gmatch("%d+") do table.insert(r, tonumber(n)) end
    for n in mine:gmatch("%d+") do table.insert(m, tonumber(n)) end
    for i = 1, math.max(#r, #m) do
        local a, b = r[i] or 0, m[i] or 0
        if a ~= b then return a > b end
    end
    return false
end

-- returns ok, message, session
local function activate(cfg, MSG, key)
    key = string.upper((key or ""):gsub("%s+", ""))
    if not key:match(KEY_PATTERN) then return false, MSG.invalid_key end

    if cfg.Demo then
        task.wait(1.2)
        if key == "MRC-TEST-TEST-TEST-TEST" then
            return true, "Demo key • Free plan", { plan = "free", games = {}, keyHint = hint(key), demo = true }
        elseif key == "MRC-0000-0000-0000-0000" then
            return false, MSG.hwid_mismatch
        end
        return false, MSG.invalid_key
    end

    if not httpRequest then return false, MSG.no_request end
    if cfg._maintenance then return false, MSG.maintenance end
    local api = cfg.Api or DEFAULTS.Api
    local hwid = fallbackHwid()

    local status, data = call(api, "POST", "activate", { key = key, hwid = hwid })
    if status == 200 and data and data.ok then
        saveKey(cfg, key)
        local session = { plan = data.plan, expires_at = data.expires_at, games = data.games or {}, keyHint = hint(key) }
        local expiry = data.expires_at and ("until " .. tostring(data.expires_at):sub(1, 16):gsub("T", " ")) or "lifetime"
        local plan = tostring(data.plan or "?")
        local message = string.format("%s plan • %s", plan:sub(1, 1):upper() .. plan:sub(2), expiry)

        if cfg.AutoLoad ~= false then
            local sStatus, sData, raw = call(api, "POST", "script", {
                key = key, hwid = hwid, game = cfg.Game or tostring(game.PlaceId),
            })
            if sStatus ~= 200 then
                return false, MSG[sData and sData.error or ""] or ("Something went wrong (" .. tostring(sStatus) .. "). Try again.")
            end
            session.source = raw
        end
        return true, message, session
    end
    if status == 0 then return false, MSG.network end
    local code = data and data.error or "server_error"
    if code == "invalid_key" or code == "expired" or code == "revoked" then forgetKey(cfg) end
    return false, MSG[code] or "Something went wrong. Try again."
end

local function runSession(cfg, session)
    if getgenv then
        getgenv().MrCrazySession = { Plan = session.plan, ExpiresAt = session.expires_at, Key = session.keyHint }
    end
    if session.source then
        local chunk, compileError = loadstring(session.source)
        if chunk then
            task.spawn(chunk)
        else
            warn("[MR CRAZY] Script error: " .. tostring(compileError))
        end
    end
    if cfg.OnSuccess then task.spawn(cfg.OnSuccess, session) end
end

function KeySystem.Run(cfg)
    cfg = cfg or {}
    local site = cfg.Site or DEFAULTS.Site
    local MSG = messages(site)

    -- maintenance / version check (skipped in demo)
    local notice
    if not cfg.Demo and httpRequest then
        local status, info = call(cfg.Api or DEFAULTS.Api, "GET", "info")
        if status == 200 and info then
            cfg._maintenance = info.maintenance == true
            if cfg._maintenance then
                notice = { MSG.maintenance, "error" }
            elseif newerVersion(info.app_version, cfg.Version) then
                notice = { "Update available: v" .. tostring(info.app_version), "info" }
            end
        end
    elseif not cfg.Demo then
        notice = { MSG.no_request, "error" }
    end

    -- auto login with the saved key
    local saved = savedKey(cfg)
    if saved and cfg.AutoLogin ~= false and not cfg._maintenance and not cfg.Demo then
        local ok, message, session = activate(cfg, MSG, saved)
        if ok then
            print("[MR CRAZY] " .. message .. " (" .. session.keyHint .. ")")
            Library:Island({ Title = "Welcome back", Text = message, Icon = "check", Tone = "Green", Duration = 3 })
            runSession(cfg, session)
            return nil
        end
        notice = { message, "error" }
        saved = savedKey(cfg) -- may have been deleted (invalid / expired / revoked)
    end

    local window = Library:CreateKeyWindow({
        Title = cfg.Title or "MR CRAZY • KEY SYSTEM",
        Subtitle = cfg.Subtitle or "Activate your key to unlock the script",
        Footer = cfg.Footer or ("Free keys: " .. site:gsub("^https?://", "") .. "/free"),
        DefaultKey = saved,
        Masked = cfg.Masked,
        GetKeyUrl = cfg.GetKeyUrl or (site .. "/free"),
        DiscordUrl = cfg.DiscordUrl or DEFAULTS.Discord,
        WebsiteUrl = cfg.WebsiteUrl or site,
        OnActivate = function(key) return activate(cfg, MSG, key) end,
        OnSuccess = function(session) runSession(cfg, session) end,
        OnClose = cfg.OnClose,
    })
    if notice then window:SetStatus(notice[1], notice[2]) end
    return window
end

Library.KeySystem = KeySystem

Library.Util = {
    inst = inst, corner = corner, stroke = stroke, frame = frame, label = label,
    icon = drawIcon, buildLogo = buildLogo, tween = tween, formatKey = formatKey,
}

return Library
