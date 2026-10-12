--[[
══════════════════════════════════════════════════════════════════════════════
 MR CRAZY KEY SYSTEM  •  standalone  •  v2.0.0
══════════════════════════════════════════════════════════════════════════════
 The key system on its own (no main window). Same design as the UI library:
 "Classic Sky", Ubuntu font, pixel doge logo, pixel icons, no emoji, no secrets.
 Talks to the website app-api (see docs/LUA-INTEGRATION.md).

 LOAD
   local KeySystem = loadstring(game:HttpGet("https://raw.githubusercontent.com/ahmedman399/ui-mrcrazy/main/mrcrazy_keysystem.lua"))()

 RUN
   KeySystem.Run({
       Version   = "1.0.0",            -- compared with the server app_version
       Game      = nil,                -- optional slug, default = current PlaceId
       AutoLoad  = true,               -- download + run the game script after the key is accepted
       AutoLogin = true,               -- use the saved key (MRCRAZY/key.txt) without showing the window
       OnSuccess = function(session) end, -- { plan, expires_at, games, keyHint, source? }
       OnClose   = function() end,
       -- Demo = true                  -- offline preview, NEVER ship it
   })

 Key window "Shy Doge": the doge covers its eyes while you type a hidden key,
 peeks when you show it, shakes its head on a wrong key, and an Island
 notification drops from the top of the screen when the key is accepted.

 ALSO AVAILABLE
   KeySystem:Island({ Title, Text, Icon = "check", Tone = "Green", Duration = 3 })
   KeySystem:CreateKeyWindow({ OnActivate = function(key) return ok, msg, data end, ... })
   KeySystem.Icon(parent, name, size, color)
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

Library.Run = KeySystem.Run -- shortcut: KeySystem.Run({...})

return Library
