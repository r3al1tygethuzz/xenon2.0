-- Xenon v15.9 part2 | UI with expanded admin panel + session stats tab
print("[Xenon] part2 starting")

local C = _G.Xenon or _G.Cleaners
if not C then warn("[Xenon] part2: _G.Xenon missing — part1 didn't run"); return end
_G.Xenon = C -- ensure Xenon global is set for downstream references

local Players = C.Players
local RunService = C.RunService
local ReplicatedStorage = C.ReplicatedStorage
local TweenService = C.TweenService
local VirtualUser = C.VirtualUser
local UserInputService = C.UserInputService
local CoreGui = C.CoreGui
local localPlayer = C.localPlayer
local FONT = C.FONT
local THEME = C.THEME
local state = C.state
local tunables = C.tunables
local CleanersConfig = C.CleanersConfig
local antiAdmin = C.antiAdmin
local farmHighlights = C.farmHighlights
local scanAndHighlight = C.scanAndHighlight
local createESP = C.createESP
local removeESP = C.removeESP
local trackedPlayers = C.trackedPlayers
local fpsBoostEnable = C.fpsBoostEnable
local fpsBoostDisable = C.fpsBoostDisable
local lowGfxEnable = C.lowGfxEnable
local lowGfxDisable = C.lowGfxDisable
local startBoxesFarm = C.startBoxesFarm
local stopBoxesFarm = C.stopBoxesFarm
local startFarmModule = C.startFarmModule
local warmCache = C.warmCache
local forceIdle = C.forceIdle
local forceIdleUnder = C.forceIdleUnder
local teleportSystem = C.teleportSystem
local sessionStats = C.sessionStats
local ADMIN_ROSTER = C.ADMIN_ROSTER
local getAdminRosterSnapshot = C.getAdminRosterSnapshot

local TP_ACTIONS_BEFORE_RESET = C.TP_ACTIONS_BEFORE_RESET
local TWEEN_ACTIONS_BEFORE_RESET = C.TWEEN_ACTIONS_BEFORE_RESET
local EARLY_RESET_PERCENT = C.EARLY_RESET_PERCENT
local HARD_RESET_MIN_GAP = C.HARD_RESET_MIN_GAP
local tpActionsSinceReset = 0
local tweenActionsSinceReset = 0
local superFarmRunning = false
local superFarmLastTick = 0
local selectedFarmKey = C.selectedFarmKey
local antiAFKConnection = C.antiAFKConnection

-- ============================================================
-- THEME OVERRIDE: green -> red + gradient accents
-- (part2 only has read-access to THEME; we mutate it in place so
--  all UI built in this file picks up the red scheme.)
-- ============================================================
THEME.Green       = Color3.fromRGB(255,  60,  60)   -- primary red
THEME.GreenDark   = Color3.fromRGB(120,  20,  20)   -- dark red
THEME.GreenDeep   = Color3.fromRGB( 70,  10,  10)   -- deepest red
THEME.Red         = Color3.fromRGB(255,  30,  30)   -- alert red
-- Gradient stops used by the helpers below
THEME.GradA       = Color3.fromRGB(255,  90,  70)   -- bright red-orange
THEME.GradB       = Color3.fromRGB(180,  20,  30)   -- deep crimson
THEME.GradC       = Color3.fromRGB(255,  40,  60)   -- vivid red

-- ============================================================
-- Gradient helpers
-- ============================================================
local function applyUIGradient(inst, a, b, rotation)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, a or THEME.GradA),
        ColorSequenceKeypoint.new(1, b or THEME.GradB),
    })
    g.Rotation = rotation or 0
    g.Parent = inst
    return g
end

-- Adds a red gradient stroke to a GuiObject
local function applyGradientStroke(inst, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Thickness = thickness or 1.5
    s.Transparency = transparency or 0.15
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = inst
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, THEME.GradA),
        ColorSequenceKeypoint.new(0.5, THEME.GradC),
        ColorSequenceKeypoint.new(1.0, THEME.GradB),
    })
    g.Rotation = 45
    g.Parent = s
    return s, g
end

-- Animated sweeping gradient for "glow" accents
local function animateSweep(gradient, speed)
    speed = speed or 60
    task.spawn(function()
        while gradient and gradient.Parent do
            gradient.Rotation = (gradient.Rotation + speed * task.wait(0.03)) % 360
        end
    end)
end

local UI_W, UI_H = 780, 720
local screenGui = Instance.new("ScreenGui")
screenGui.Name="XenonUI"; screenGui.ResetOnSpawn=false; screenGui.IgnoreGuiInset=true; screenGui.DisplayOrder=100
local okGui = pcall(function() screenGui.Parent = CoreGui end)
if not okGui or not screenGui.Parent then pcall(function() screenGui.Parent = localPlayer:WaitForChild("PlayerGui",5) end) end
screenGui.Enabled = false

local mainFrame = Instance.new("Frame")
mainFrame.Size=UDim2.new(0,UI_W,0,UI_H); mainFrame.Position=UDim2.new(0.5,-UI_W/2,0.5,-UI_H/2)
mainFrame.BackgroundColor3=THEME.Bg; mainFrame.BorderSizePixel=0
mainFrame.Active=true; mainFrame.Draggable=true; mainFrame.ClipsDescendants=true; mainFrame.Parent=screenGui
local corner = Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,8); corner.Parent=mainFrame
-- gradient stroke replaces flat border
local mainStroke = applyGradientStroke(mainFrame, 1.5, 0.1)
animateSweep(mainStroke:FindFirstChildOfClass("UIGradient"), 25)

local titleBar = Instance.new("Frame")
titleBar.Size=UDim2.new(1,0,0,40); titleBar.BackgroundColor3=THEME.TitleBar; titleBar.BorderSizePixel=0; titleBar.Parent=mainFrame
local tbc = Instance.new("UICorner"); tbc.CornerRadius=UDim.new(0,8); tbc.Parent=titleBar
-- gradient fill overlay on title bar (subtle)
local tbGrad = Instance.new("UIGradient")
tbGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.0, Color3.fromRGB(60, 8, 8)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(30, 4, 4)),
    ColorSequenceKeypoint.new(1.0, Color3.fromRGB(60, 8, 8)),
})
tbGrad.Rotation = 90
tbGrad.Parent = titleBar

local title = Instance.new("TextLabel")
title.Size=UDim2.new(0.6,0,1,0); title.Position=UDim2.new(0,16,0,0)
title.BackgroundTransparency=1; title.Text="XENON"; title.TextColor3=THEME.Green
title.TextSize=18; title.Font=FONT; title.TextXAlignment=Enum.TextXAlignment.Left; title.Parent=titleBar
-- gradient tint on the title text (red -> orange)
applyUIGradient(title, THEME.GradA, THEME.GradC, 0)
-- animated glow stroke around title text for a "live" feel
applyGradientStroke(title, 1, 0.7)

local close = Instance.new("TextButton")
close.Size=UDim2.new(0,34,0,34); close.Position=UDim2.new(1,-38,0,3)
close.BackgroundColor3=THEME.GreenDeep; close.Text="X"; close.TextColor3=THEME.Green
close.TextSize=16; close.Font=FONT; close.BorderSizePixel=0; close.Parent=titleBar
local cc = Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,4); cc.Parent=close
applyGradientStroke(close, 1, 0.2)
applyUIGradient(close, THEME.GradA, THEME.GradB, 90)

local minimize = Instance.new("TextButton")
minimize.Size=UDim2.new(0,34,0,34); minimize.Position=UDim2.new(1,-76,0,3)
minimize.BackgroundColor3=THEME.PanelAlt; minimize.Text="-"; minimize.TextColor3=THEME.Green
minimize.TextSize=18; minimize.Font=FONT; minimize.BorderSizePixel=0; minimize.Parent=titleBar
local mc = Instance.new("UICorner"); mc.CornerRadius=UDim.new(0,4); mc.Parent=minimize
applyGradientStroke(minimize, 1, 0.2)

-- 5 tabs now: Farms, ESP, Anti-Admin, Stats, Settings
local tabs = { "Farms", "ESP", "Anti-Admin", "Stats", "Settings" }
local tabRow = Instance.new("Frame")
tabRow.Size=UDim2.new(1,0,0,32); tabRow.Position=UDim2.new(0,0,0,40)
tabRow.BackgroundColor3=THEME.BgAlt; tabRow.BorderSizePixel=0; tabRow.Parent=mainFrame
local tabButtons = {}
local tabGradients = {}
local TAB_W = 84
for i, name in ipairs(tabs) do
    local b = Instance.new("TextButton")
    b.Size=UDim2.new(0,TAB_W,1,0); b.Position=UDim2.new(0,(i-1)*TAB_W,0,0)
    b.BackgroundColor3 = i==1 and THEME.TitleBar or THEME.BgAlt
    b.Text=name; b.TextColor3 = i==1 and THEME.Green or THEME.TextDim
    b.TextSize=10; b.Font=FONT; b.BorderSizePixel=0; b.AutoButtonColor=false
    b.Parent=tabRow; tabButtons[name]=b
    -- gradient stroke for each tab (bright when active)
    local _, g = applyGradientStroke(b, 1, i==1 and 0.15 or 0.65)
    tabGradients[name] = { stroke = _, gradient = g, wasActive = (i==1) }
end

local content = Instance.new("ScrollingFrame")
content.Size=UDim2.new(1,-12,1,-88); content.Position=UDim2.new(0,6,0,78)
content.BackgroundColor3=THEME.Bg; content.BorderSizePixel=0
content.ScrollBarThickness=4; content.ScrollBarImageColor3=THEME.Green
content.CanvasSize=UDim2.new(0,0,0,0); content.Parent=mainFrame
local listL = Instance.new("UIListLayout"); listL.Parent=content
listL.SortOrder=Enum.SortOrder.LayoutOrder; listL.Padding=UDim.new(0,4)
local pad = Instance.new("UIPadding"); pad.PaddingTop=UDim.new(0,8); pad.PaddingLeft=UDim.new(0,8)
pad.PaddingRight=UDim.new(0,8); pad.PaddingBottom=UDim.new(0,8); pad.Parent=content

local mini = Instance.new("TextButton")
mini.Size=UDim2.new(0,320,0,40); mini.Position=UDim2.new(0,20,0,20)
mini.BackgroundColor3=THEME.Bg; mini.BorderSizePixel=0; mini.Text=""
mini.AutoButtonColor=false; mini.Active=true; mini.Draggable=true; mini.Visible=false
mini.Parent=screenGui
local mic = Instance.new("UICorner"); mic.CornerRadius=UDim.new(0,8); mic.Parent=mini
-- mini button uses animated gradient stroke
local miniStroke = applyGradientStroke(mini, 2, 0.05)
animateSweep(miniStroke:FindFirstChildOfClass("UIGradient"), 40)
local miniLabel = Instance.new("TextLabel")
miniLabel.Size=UDim2.new(0,130,1,0); miniLabel.Position=UDim2.new(0,14,0,0)
miniLabel.BackgroundTransparency=1; miniLabel.Text="Xenon"
miniLabel.TextColor3=THEME.Green; miniLabel.TextSize=16; miniLabel.Font=Enum.Font.GothamBold
miniLabel.TextXAlignment=Enum.TextXAlignment.Left
miniLabel.TextYAlignment=Enum.TextYAlignment.Center; miniLabel.Active=false; miniLabel.Parent=mini
applyUIGradient(miniLabel, THEME.GradA, THEME.GradC, 0)

minimize.MouseButton1Click:Connect(function()
    if state.minimized then return end
    state.minimized=true; mainFrame.Visible=false; mini.Visible=true
end)
mini.MouseButton1Click:Connect(function()
    if not state.minimized then return end
    state.minimized=false; mini.Visible=false; mainFrame.Visible=true
end)

local function clearContent()
    for _, ch in ipairs(content:GetChildren()) do if ch ~= listL and ch ~= pad then ch:Destroy() end end
    content.CanvasSize = UDim2.new(0,0,0,0)
end
local function makeRow(order, height)
    local r = Instance.new("Frame")
    r.Size=UDim2.new(1,0,0,height or 34); r.BackgroundColor3=THEME.Panel
    r.BorderSizePixel=0; r.LayoutOrder=order; r.Parent=content
    local c = Instance.new("UICorner"); c.CornerRadius=UDim.new(0,4); c.Parent=r
    applyGradientStroke(r, 1, 0.55)
    return r
end
local function makeToggle(labelText, stateRef, key, callback, order)
    local r = makeRow(order, 34)
    local l = Instance.new("TextLabel")
    l.Size=UDim2.new(0.75,0,1,0); l.Position=UDim2.new(0,12,0,0)
    l.BackgroundTransparency=1; l.Text=labelText; l.TextColor3=THEME.Text
    l.TextSize=12; l.Font=FONT; l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=r
    local b = Instance.new("TextButton")
    b.Size=UDim2.new(0,22,0,22); b.Position=UDim2.new(1,-30,0.5,-11)
    b.BackgroundColor3 = stateRef[key] and THEME.Green or THEME.GreenDark
    b.Text=""; b.BorderSizePixel=0; b.AutoButtonColor=false; b.Parent=r
    local bc = Instance.new("UICorner"); bc.CornerRadius=UDim.new(0,3); bc.Parent=b
    -- gradient fill on the toggle knob
    local togGrad = Instance.new("UIGradient")
    togGrad.Rotation = 90
    togGrad.Parent = b
    local function paintToggle()
        if stateRef[key] then
            b.BackgroundColor3 = Color3.new(1,1,1) -- let gradient show
            togGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, THEME.GradA),
                ColorSequenceKeypoint.new(1, THEME.GradC),
            })
        else
            b.BackgroundColor3 = THEME.GreenDark
            togGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, THEME.GreenDark),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 10, 10)),
            })
        end
    end
    paintToggle()
    b.MouseButton1Click:Connect(function()
        stateRef[key] = not stateRef[key]
        paintToggle()
        if callback then pcall(callback, stateRef[key]) end
    end)
    return r
end
local function makeOptionRow(label, options, currentValue, onSelect, order)
    local r = makeRow(order, 32)
    local l = Instance.new("TextLabel")
    l.Size=UDim2.new(0.45,0,1,0); l.Position=UDim2.new(0,12,0,0)
    l.BackgroundTransparency=1; l.Text=label; l.TextColor3=THEME.Text
    l.TextSize=11; l.Font=FONT; l.TextXAlignment=Enum.TextXAlignment.Left
    l.TextYAlignment=Enum.TextYAlignment.Center; l.Parent=r
    local holder = Instance.new("Frame")
    holder.Size=UDim2.new(0.53,0,1,0); holder.Position=UDim2.new(0.47,0,0,0)
    holder.BackgroundTransparency=1; holder.Parent=r
    local hl = Instance.new("UIListLayout")
    hl.FillDirection=Enum.FillDirection.Horizontal; hl.HorizontalAlignment=Enum.HorizontalAlignment.Right
    hl.VerticalAlignment=Enum.VerticalAlignment.Center; hl.Padding=UDim.new(0,3); hl.Parent=holder
    local btns = {}
    local function paint()
        for _, e in ipairs(btns) do
            local active = tostring(e.v) == tostring(currentValue())
            if active then
                e.b.BackgroundColor3 = Color3.new(1,1,1)
                e.g.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, THEME.GradA),
                    ColorSequenceKeypoint.new(1, THEME.GradB),
                })
                e.b.TextColor3 = Color3.fromRGB(20, 5, 5)
            else
                e.b.BackgroundColor3 = THEME.PanelAlt
                e.g.Color = ColorSequence.new(THEME.PanelAlt)
                e.b.TextColor3 = THEME.TextDim
            end
        end
    end
    for _, v in ipairs(options) do
        local b = Instance.new("TextButton")
        b.Size=UDim2.new(0,34,0,22); b.BackgroundColor3=THEME.PanelAlt
        b.Text=tostring(v); b.TextColor3=THEME.TextDim; b.TextSize=10; b.Font=FONT
        b.BorderSizePixel=0; b.AutoButtonColor=false; b.Parent=holder
        local bc = Instance.new("UICorner"); bc.CornerRadius=UDim.new(0,3); bc.Parent=b
        local g = Instance.new("UIGradient"); g.Rotation=90; g.Color=ColorSequence.new(THEME.PanelAlt); g.Parent=b
        table.insert(btns, {b=b, v=v, g=g})
        b.MouseButton1Click:Connect(function() onSelect(v); paint() end)
    end
    paint(); return r
end
local function makeSectionHeader(text, order)
    local h = Instance.new("TextLabel")
    h.Size=UDim2.new(1,0,0,22); h.BackgroundTransparency=1; h.Text=text
    h.TextColor3=THEME.TextDim; h.TextSize=11; h.Font=FONT
    h.TextXAlignment=Enum.TextXAlignment.Left; h.LayoutOrder=order; h.Parent=content
    -- subtle red gradient tint on header text
    applyUIGradient(h, THEME.GradC, THEME.GradB, 0)
    return h
end
local function makeFarmToggleRow(parent, labelText, stateRef, key, order, onChange)
    local r = Instance.new("Frame")
    r.Size=UDim2.new(1,0,0,28); r.BackgroundColor3=THEME.PanelAlt
    r.BorderSizePixel=0; r.LayoutOrder=order; r.Parent=parent
    Instance.new("UICorner", r).CornerRadius=UDim.new(0,3)
    local l = Instance.new("TextLabel", r)
    l.Size=UDim2.new(0.75,0,1,0); l.Position=UDim2.new(0,10,0,0)
    l.BackgroundTransparency=1; l.Text=labelText; l.TextColor3=THEME.TextMid
    l.TextSize=11; l.Font=FONT; l.TextXAlignment=Enum.TextXAlignment.Left
    local b = Instance.new("TextButton", r)
    b.Size=UDim2.new(0,18,0,18); b.Position=UDim2.new(1,-26,0.5,-9)
    b.BackgroundColor3 = stateRef[key] and THEME.Green or THEME.GreenDark
    b.Text=""; b.BorderSizePixel=0; b.AutoButtonColor=false
    Instance.new("UICorner", b).CornerRadius=UDim.new(0,3)
    local g = Instance.new("UIGradient"); g.Rotation=90; g.Parent=b
    local function paint()
        if stateRef[key] then
            b.BackgroundColor3 = Color3.new(1,1,1)
            g.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, THEME.GradA),
                ColorSequenceKeypoint.new(1, THEME.GradC),
            })
        else
            b.BackgroundColor3 = THEME.GreenDark
            g.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, THEME.GreenDark),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 10, 10)),
            })
        end
    end
    paint()
    b.MouseButton1Click:Connect(function()
        stateRef[key] = not stateRef[key]
        paint()
        if onChange then onChange() end
    end)
    return r
end

local function makeDropdown(titleText, defaultOpen, order)
    local header = Instance.new("TextButton")
    header.Size=UDim2.new(1,0,0,34); header.BackgroundColor3=THEME.PanelAlt
    header.Text=(defaultOpen and "▲  " or "▼  ")..titleText; header.TextColor3=THEME.Green
    header.TextSize=12; header.Font=Enum.Font.GothamBold
    header.TextXAlignment=Enum.TextXAlignment.Left; header.BorderSizePixel=0
    header.AutoButtonColor=false; header.LayoutOrder=order; header.Parent=content
    local hc = Instance.new("UICorner"); hc.CornerRadius=UDim.new(0,4); hc.Parent=header
    local hp = Instance.new("UIPadding"); hp.PaddingLeft=UDim.new(0,12); hp.Parent=header
    applyGradientStroke(header, 1, 0.4)
    local body = Instance.new("Frame")
    body.Size=UDim2.new(1,0,0,0); body.AutomaticSize=Enum.AutomaticSize.Y
    body.BackgroundColor3=THEME.Panel; body.BorderSizePixel=0; body.Visible=defaultOpen
    body.LayoutOrder=order+0.001; body.Parent=content
    local bc = Instance.new("UICorner"); bc.CornerRadius=UDim.new(0,4); bc.Parent=body
    applyGradientStroke(body, 1, 0.6)
    local bp = Instance.new("UIPadding"); bp.PaddingTop=UDim.new(0,6); bp.PaddingBottom=UDim.new(0,6)
    bp.PaddingLeft=UDim.new(0,6); bp.PaddingRight=UDim.new(0,6); bp.Parent=body
    local bl = Instance.new("UIListLayout"); bl.SortOrder=Enum.SortOrder.LayoutOrder; bl.Padding=UDim.new(0,4); bl.Parent=body
    local open = defaultOpen
    header.MouseButton1Click:Connect(function()
        open = not open; body.Visible=open
        header.Text=(open and "▲  " or "▼  ")..titleText
        if titleText == "SUPER FARM" then state.ui.superFarmOpen=open; CleanersConfig.markDirty() end
    end)
    return header, body, function() return open end, function(v)
        open=v; body.Visible=v; header.Text=(v and "▲  " or "▼  ")..titleText
        if titleText == "SUPER FARM" then state.ui.superFarmOpen=v; CleanersConfig.markDirty() end
    end
end

-- ============================================================
-- FARMS TAB
-- ============================================================
local function buildFarmsEnable(parent, sNext)
    local enRow = Instance.new("Frame")
    enRow.Size=UDim2.new(1,0,0,34); enRow.BackgroundColor3=THEME.PanelAlt
    enRow.BorderSizePixel=0; enRow.LayoutOrder=sNext(); enRow.Parent=parent
    local enc = Instance.new("UICorner"); enc.CornerRadius=UDim.new(0,3); enc.Parent=enRow
    applyGradientStroke(enRow, 1, 0.45)
    local enLbl = Instance.new("TextLabel")
    enLbl.Size=UDim2.new(0.75,0,1,0); enLbl.Position=UDim2.new(0,10,0,0)
    enLbl.BackgroundTransparency=1; enLbl.Text="Enable Super Farm"; enLbl.TextColor3=THEME.Text
    enLbl.TextSize=12; enLbl.Font=Enum.Font.GothamBold
    enLbl.TextXAlignment=Enum.TextXAlignment.Left; enLbl.Parent=enRow
    local enBtn = Instance.new("TextButton")
    enBtn.Size=UDim2.new(0,26,0,22); enBtn.Position=UDim2.new(1,-34,0.5,-11)
    enBtn.BackgroundColor3 = state.farms.SuperFarm and THEME.Green or THEME.GreenDark
    enBtn.Text=""; enBtn.BorderSizePixel=0; enBtn.AutoButtonColor=false; enBtn.Parent=enRow
    local enbc = Instance.new("UICorner"); enbc.CornerRadius=UDim.new(0,3); enbc.Parent=enBtn
    local enGrad = Instance.new("UIGradient"); enGrad.Rotation=90; enGrad.Parent=enBtn
    local function paintEn()
        if state.farms.SuperFarm then
            enBtn.BackgroundColor3 = Color3.new(1,1,1)
            enGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, THEME.GradA),
                ColorSequenceKeypoint.new(1, THEME.GradC),
            })
        else
            enBtn.BackgroundColor3 = THEME.GreenDark
            enGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, THEME.GreenDark),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(60,10,10)),
            })
        end
    end
    paintEn()
    enBtn.MouseButton1Click:Connect(function()
        local v = not state.farms.SuperFarm
        if v then
            state.farms.SuperFarm=true; selectedFarmKey="SuperFarm"
            teleportSystem.successfulTPs=0; teleportSystem.atmsSinceReset=0
            tpActionsSinceReset=0; tweenActionsSinceReset=0
            teleportSystem.generation = teleportSystem.generation + 1
            superFarmRunning=false; superFarmLastTick=tick()
            warmCache(); startFarmModule("SuperFarm")
        else
            state.farms.SuperFarm=false
            if selectedFarmKey == "SuperFarm" then selectedFarmKey=nil end
            superFarmRunning=false
            sessionStats.stop()
            task.spawn(function() if state.movement.mode=="Tween" then forceIdleUnder() else forceIdle() end end)
        end
        paintEn()
        CleanersConfig.markDirty()
    end)
end
local function buildFarmsTargets(parent, sNext)
    local tgtH = Instance.new("TextLabel")
    tgtH.Size=UDim2.new(1,0,0,20); tgtH.BackgroundTransparency=1; tgtH.Text="Targets (priority order)"
    tgtH.TextColor3=THEME.TextDim; tgtH.TextSize=10; tgtH.Font=FONT
    tgtH.TextXAlignment=Enum.TextXAlignment.Left; tgtH.LayoutOrder=sNext(); tgtH.Parent=parent
    for _, k in ipairs({"Registers","ATMs","Cash","Dumpsters"}) do
        makeFarmToggleRow(parent, k, state.superTargets, k, sNext(), function() CleanersConfig.markDirty() end)
    end
end
local function buildFarmsJob(parent, sNext)
    local jobH = Instance.new("TextLabel")
    jobH.Size=UDim2.new(1,0,0,20); jobH.BackgroundTransparency=1; jobH.Text="Job Farms"
    jobH.TextColor3=THEME.TextDim; jobH.TextSize=10; jobH.Font=FONT
    jobH.TextXAlignment=Enum.TextXAlignment.Left; jobH.LayoutOrder=sNext(); jobH.Parent=parent
    local boxRow = Instance.new("Frame")
    boxRow.Size=UDim2.new(1,0,0,28); boxRow.BackgroundColor3=THEME.PanelAlt
    boxRow.BorderSizePixel=0; boxRow.LayoutOrder=sNext(); boxRow.Parent=parent
    local brc = Instance.new("UICorner"); brc.CornerRadius=UDim.new(0,3); brc.Parent=boxRow
    applyGradientStroke(boxRow, 1, 0.5)
    local boxLbl = Instance.new("TextLabel")
    boxLbl.Size=UDim2.new(0.45,0,1,0); boxLbl.Position=UDim2.new(0,10,0,0)
    boxLbl.BackgroundTransparency=1; boxLbl.Text="Boxes Farm"; boxLbl.TextColor3=THEME.Text
    boxLbl.TextSize=11; boxLbl.Font=FONT; boxLbl.TextXAlignment=Enum.TextXAlignment.Left; boxLbl.Parent=boxRow
    local bStart = Instance.new("TextButton")
    bStart.Size=UDim2.new(0,66,0.7,0); bStart.Position=UDim2.new(1,-150,0.15,0)
    bStart.BackgroundColor3=THEME.GreenDark; bStart.Text="START"; bStart.TextColor3=THEME.Green
    bStart.TextSize=9; bStart.Font=Enum.Font.GothamBold; bStart.BorderSizePixel=0; bStart.AutoButtonColor=false; bStart.Parent=boxRow
    local bsc = Instance.new("UICorner"); bsc.CornerRadius=UDim.new(0,3); bsc.Parent=bStart
    local bStartGrad = Instance.new("UIGradient"); bStartGrad.Rotation=90; bStartGrad.Parent=bStart
    local bStop = Instance.new("TextButton")
    bStop.Size=UDim2.new(0,66,0.7,0); bStop.Position=UDim2.new(1,-78,0.15,0)
    bStop.BackgroundColor3=THEME.PanelAlt; bStop.Text="STOP"; bStop.TextColor3=THEME.Red
    bStop.TextSize=9; bStop.Font=Enum.Font.GothamBold; bStop.BorderSizePixel=0; bStop.AutoButtonColor=false; bStop.Parent=boxRow
    local btc = Instance.new("UICorner"); btc.CornerRadius=UDim.new(0,3); btc.Parent=bStop
    applyGradientStroke(bStop, 1, 0.4)
    local function paintBoxes()
        if state.farms.BoxesFarm then
            bStart.BackgroundColor3=Color3.new(1,1,1)
            bStartGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, THEME.GradA),
                ColorSequenceKeypoint.new(1, THEME.GradC),
            })
            bStart.TextColor3=Color3.fromRGB(20,5,5)
        else
            bStart.BackgroundColor3=THEME.GreenDark
            bStartGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, THEME.GreenDark),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(60,10,10)),
            })
            bStart.TextColor3=THEME.Green
        end
    end
    bStart.MouseButton1Click:Connect(function() startBoxesFarm(); paintBoxes() end)
    bStop.MouseButton1Click:Connect(function() stopBoxesFarm(); paintBoxes() end)
    task.spawn(function() while boxRow.Parent do paintBoxes(); task.wait(0.5) end end)
end
local function buildFarmsMovement(parent, sNext)
    local mvH = Instance.new("TextLabel")
    mvH.Size=UDim2.new(1,0,0,20); mvH.BackgroundTransparency=1; mvH.Text="Movement"
    mvH.TextColor3=THEME.TextDim; mvH.TextSize=10; mvH.Font=FONT
    mvH.TextXAlignment=Enum.TextXAlignment.Left; mvH.LayoutOrder=sNext(); mvH.Parent=parent
    local mvRow = Instance.new("Frame")
    mvRow.Size=UDim2.new(1,0,0,28); mvRow.BackgroundColor3=THEME.PanelAlt
    mvRow.BorderSizePixel=0; mvRow.LayoutOrder=sNext(); mvRow.Parent=parent
    local mvc = Instance.new("UICorner"); mvc.CornerRadius=UDim.new(0,3); mvc.Parent=mvRow
    local mvLbl = Instance.new("TextLabel")
    mvLbl.Size=UDim2.new(0.4,0,1,0); mvLbl.Position=UDim2.new(0,10,0,0)
    mvLbl.BackgroundTransparency=1; mvLbl.Text="Mode"; mvLbl.TextColor3=THEME.Text
    mvLbl.TextSize=11; mvLbl.Font=FONT; mvLbl.TextXAlignment=Enum.TextXAlignment.Left; mvLbl.Parent=mvRow
    local mvHolder = Instance.new("Frame")
    mvHolder.Size=UDim2.new(0.55,0,1,0); mvHolder.Position=UDim2.new(0.42,0,0,0)
    mvHolder.BackgroundTransparency=1; mvHolder.Parent=mvRow
    local mvList = Instance.new("UIListLayout")
    mvList.FillDirection=Enum.FillDirection.Horizontal; mvList.HorizontalAlignment=Enum.HorizontalAlignment.Right
    mvList.VerticalAlignment=Enum.VerticalAlignment.Center; mvList.Padding=UDim.new(0,3); mvList.Parent=mvHolder
    local mvBtns = {}
    local function paintMv()
        for _, e in ipairs(mvBtns) do
            local active = e.v == state.movement.mode
            if active then
                e.b.BackgroundColor3 = Color3.new(1,1,1)
                e.g.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, THEME.GradA),
                    ColorSequenceKeypoint.new(1, THEME.GradB),
                })
                e.b.TextColor3 = Color3.fromRGB(20,5,5)
            else
                e.b.BackgroundColor3 = THEME.PanelAlt
                e.g.Color = ColorSequence.new(THEME.PanelAlt)
                e.b.TextColor3 = THEME.TextDim
            end
        end
    end
    for _, v in ipairs({"TP","Tween"}) do
        local b = Instance.new("TextButton")
        b.Size=UDim2.new(0,44,0,20); b.BackgroundColor3=THEME.PanelAlt; b.Text=v
        b.TextColor3=THEME.TextDim; b.TextSize=9; b.Font=FONT; b.BorderSizePixel=0; b.AutoButtonColor=false; b.Parent=mvHolder
        local bc2 = Instance.new("UICorner"); bc2.CornerRadius=UDim.new(0,3); bc2.Parent=b
        local g = Instance.new("UIGradient"); g.Rotation=90; g.Color=ColorSequence.new(THEME.PanelAlt); g.Parent=b
        table.insert(mvBtns, {b=b, v=v, g=g})
        b.MouseButton1Click:Connect(function() state.movement.mode=v; paintMv() end)
    end
    paintMv()
end
local function buildFarmsThresholds(parent, sNext)
    local rsH = Instance.new("TextLabel")
    rsH.Size=UDim2.new(1,0,0,20); rsH.BackgroundTransparency=1; rsH.Text="Reset thresholds"
    rsH.TextColor3=THEME.TextDim; rsH.TextSize=10; rsH.Font=FONT
    rsH.TextXAlignment=Enum.TextXAlignment.Left; rsH.LayoutOrder=sNext(); rsH.Parent=parent
    local function makeResetRow(label, options, currentValue, onSelect, fmt)
        local r = Instance.new("Frame")
        r.Size=UDim2.new(1,0,0,28); r.BackgroundColor3=THEME.PanelAlt
        r.BorderSizePixel=0; r.LayoutOrder=sNext(); r.Parent=parent
        local rc = Instance.new("UICorner"); rc.CornerRadius=UDim.new(0,3); rc.Parent=r
        local l = Instance.new("TextLabel")
        l.Size=UDim2.new(0.45,0,1,0); l.Position=UDim2.new(0,10,0,0)
        l.BackgroundTransparency=1; l.Text=label; l.TextColor3=THEME.Text
        l.TextSize=10; l.Font=FONT; l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=r
        local holder = Instance.new("Frame")
        holder.Size=UDim2.new(0.52,0,1,0); holder.Position=UDim2.new(0.46,0,0,0)
        holder.BackgroundTransparency=1; holder.Parent=r
        local list = Instance.new("UIListLayout")
        list.FillDirection=Enum.FillDirection.Horizontal; list.HorizontalAlignment=Enum.HorizontalAlignment.Right
        list.VerticalAlignment=Enum.VerticalAlignment.Center; list.Padding=UDim.new(0,2); list.Parent=holder
        local btns = {}
        local function paint()
            for _, e in ipairs(btns) do
                local active = math.abs(e.v - currentValue()) < 0.001
                if active then
                    e.b.BackgroundColor3 = Color3.new(1,1,1)
                    e.g.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, THEME.GradA),
                        ColorSequenceKeypoint.new(1, THEME.GradB),
                    })
                    e.b.TextColor3 = Color3.fromRGB(20,5,5)
                else
                    e.b.BackgroundColor3 = THEME.PanelAlt
                    e.g.Color = ColorSequence.new(THEME.PanelAlt)
                    e.b.TextColor3 = THEME.TextDim
                end
            end
        end
        for _, v in ipairs(options) do
            local b = Instance.new("TextButton")
            b.Size=UDim2.new(0,30,0,20); b.BackgroundColor3=THEME.PanelAlt
            b.Text = fmt and fmt(v) or tostring(v); b.TextColor3=THEME.TextDim
            b.TextSize=9; b.Font=FONT; b.BorderSizePixel=0; b.AutoButtonColor=false; b.Parent=holder
            local bc2 = Instance.new("UICorner"); bc2.CornerRadius=UDim.new(0,3); bc2.Parent=b
            local g = Instance.new("UIGradient"); g.Rotation=90; g.Color=ColorSequence.new(THEME.PanelAlt); g.Parent=b
            table.insert(btns, {b=b, v=v, g=g})
            b.MouseButton1Click:Connect(function() onSelect(v); paint(); CleanersConfig.markDirty() end)
        end
        paint(); return r
    end
    makeResetRow("TP actions", {2,3,4,5,6,7,8,10,12}, function() return TP_ACTIONS_BEFORE_RESET end, function(v) TP_ACTIONS_BEFORE_RESET=v; C.TP_ACTIONS_BEFORE_RESET=v end)
    makeResetRow("Tween actions", {10,20,30,40,50}, function() return TWEEN_ACTIONS_BEFORE_RESET end, function(v) TWEEN_ACTIONS_BEFORE_RESET=v; C.TWEEN_ACTIONS_BEFORE_RESET=v end)
    makeResetRow("Reset at % of max", {0.50,0.60,0.75,0.90,1.00}, function() return EARLY_RESET_PERCENT end, function(v) EARLY_RESET_PERCENT=v; C.EARLY_RESET_PERCENT=v end, function(v) return tostring(math.floor(v*100+0.5)).."%" end)
end

local function buildFarms()
    clearContent(); local o=0; local function next() o=o+1; return o end
    local _, superBody = makeDropdown("SUPER FARM", state.ui.superFarmOpen, next())
    local superInner = Instance.new("Frame")
    superInner.Size=UDim2.new(1,0,0,0); superInner.AutomaticSize=Enum.AutomaticSize.Y
    superInner.BackgroundTransparency=1; superInner.LayoutOrder=1; superInner.Parent=superBody
    local sil = Instance.new("UIListLayout"); sil.Parent=superInner
    sil.SortOrder=Enum.SortOrder.LayoutOrder; sil.Padding=UDim.new(0,4)
    local sOrder = 0; local function sNext() sOrder=sOrder+1; return sOrder end
    buildFarmsEnable(superInner, sNext)
    buildFarmsTargets(superInner, sNext)
    buildFarmsJob(superInner, sNext)
    buildFarmsMovement(superInner, sNext)
    buildFarmsThresholds(superInner, sNext)
    content.CanvasSize = UDim2.new(0,0,0,o*34+400)
end

-- ============================================================
-- ESP TAB
-- ============================================================
local function buildESP()
    clearContent(); local o=0; local function next() o=o+1; return o end
    makeSectionHeader("ESP", next())
    makeToggle("Player ESP", state.esp, "PlayerESP", function(v)
        C.playerESPEnabled = v
        if v then for _, p in ipairs(Players:GetPlayers()) do createESP(p) end
        else for p, _ in pairs(trackedPlayers) do removeESP(p) end end
    end, next())
    makeSectionHeader("Farm Highlights", next())
    for _, entry in ipairs({
        {key="Registers", label="Highlight Registers"},
        {key="Cash", label="Highlight Floor Cash"},
        {key="Dumpsters", label="Highlight Dumpsters"},
        {key="ATMs", label="Highlight ATMs"},
    }) do
        makeToggle(entry.label, state.esp, entry.key, function(v) farmHighlights[entry.key].enabled=v; scanAndHighlight(entry.key) end, next())
    end
    content.CanvasSize = UDim2.new(0,0,0,o*34+80)
end

-- ============================================================
-- ANTI-ADMIN TAB (expanded with full roster)
-- ============================================================
local function buildAntiAdminTab()
    clearContent(); local o=0; local function next() o=o+1; return o end

    makeSectionHeader("Anti-Admin", next())
    makeToggle("Enable Anti-Admin (auto server hop)", state.protection, "AntiAdmin", function(v)
        antiAdmin.enabled=v; antiAdmin.autoLeave=v
    end, next())

    local info = Instance.new("TextLabel")
    info.Size=UDim2.new(1,0,0,32); info.BackgroundTransparency=1
    info.Text="Full watchlist — updates every 1s. Detected admins trigger auto hop when Anti-Admin is on."
    info.TextColor3=THEME.TextDim; info.TextSize=10; info.Font=FONT
    info.TextXAlignment=Enum.TextXAlignment.Left; info.TextWrapped=true
    info.LayoutOrder=next(); info.Parent=content

    makeSectionHeader("Watchlist (" .. #ADMIN_ROSTER .. " admins)", next())

    -- container that we rebuild every second
    local listBox = Instance.new("Frame")
    listBox.Size=UDim2.new(1,0,0,0); listBox.AutomaticSize=Enum.AutomaticSize.Y
    listBox.BackgroundTransparency=1; listBox.LayoutOrder=next(); listBox.Parent=content
    local listLay = Instance.new("UIListLayout"); listLay.Parent=listBox
    listLay.SortOrder=Enum.SortOrder.LayoutOrder; listLay.Padding=UDim.new(0,3)

    local rowWidgets = {}
    local function makeAdminRow(order, data)
        local r = Instance.new("Frame")
        r.Size=UDim2.new(1,0,0,46); r.BackgroundColor3=THEME.PanelAlt
        r.BorderSizePixel=0; r.LayoutOrder=order; r.Parent=listBox
        local rc = Instance.new("UICorner"); rc.CornerRadius=UDim.new(0,3); rc.Parent=r
        applyGradientStroke(r, 1, 0.6)

        local statusBar = Instance.new("Frame")
        statusBar.Size=UDim2.new(0,4,1,0); statusBar.BorderSizePixel=0
        statusBar.BackgroundColor3 = data.inServer and THEME.Red or THEME.GreenDark
        statusBar.Parent=r
        local sbc = Instance.new("UICorner"); sbc.CornerRadius=UDim.new(0,2); sbc.Parent=statusBar

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size=UDim2.new(0.42,0,0,20); nameLbl.Position=UDim2.new(0,12,0,4)
        nameLbl.BackgroundTransparency=1
        nameLbl.Text=data.display .. " (@" .. data.username .. ")"
        nameLbl.TextColor3=THEME.Text; nameLbl.TextSize=11; nameLbl.Font=Enum.Font.GothamBold
        nameLbl.TextXAlignment=Enum.TextXAlignment.Left; nameLbl.Parent=r

        local idLbl = Instance.new("TextLabel")
        idLbl.Size=UDim2.new(0.42,0,0,16); idLbl.Position=UDim2.new(0,12,0,24)
        idLbl.BackgroundTransparency=1
        idLbl.Text="UserId: " .. tostring(data.userId)
        idLbl.TextColor3=THEME.TextDim; idLbl.TextSize=10; idLbl.Font=FONT
        idLbl.TextXAlignment=Enum.TextXAlignment.Left; idLbl.Parent=r

        local statusLbl = Instance.new("TextLabel")
        statusLbl.Size=UDim2.new(0.5,0,0,20); statusLbl.Position=UDim2.new(0.48,0,0,4)
        statusLbl.BackgroundTransparency=1
        statusLbl.Text = data.inServer and ("IN SERVER: " .. tostring(data.playerName)) or "Not in server"
        statusLbl.TextColor3 = data.inServer and THEME.Red or THEME.TextMid
        statusLbl.TextSize=11; statusLbl.Font=Enum.Font.GothamBold
        statusLbl.TextXAlignment=Enum.TextXAlignment.Right; statusLbl.Parent=r

        local gameIdLbl = Instance.new("TextLabel")
        gameIdLbl.Size=UDim2.new(0.5,0,0,16); gameIdLbl.Position=UDim2.new(0.48,0,0,24)
        gameIdLbl.BackgroundTransparency=1
        gameIdLbl.Text = data.inServer and ("JobId: " .. tostring(game.JobId)) or "—"
        gameIdLbl.TextColor3=THEME.TextDim; gameIdLbl.TextSize=9; gameIdLbl.Font=FONT
        gameIdLbl.TextXAlignment=Enum.TextXAlignment.Right; gameIdLbl.Parent=r

        return { frame=r, statusBar=statusBar, nameLbl=nameLbl, idLbl=idLbl, statusLbl=statusLbl, gameIdLbl=gameIdLbl }
    end

    local snapshot = getAdminRosterSnapshot()
    for i, data in ipairs(snapshot) do
        rowWidgets[data.userId] = makeAdminRow(i, data)
    end

    -- updater loop: repaint every 1s based on fresh snapshot
    task.spawn(function()
        while listBox.Parent do
            task.wait(1)
            if not listBox.Parent then break end
            local fresh = getAdminRosterSnapshot()
            for _, data in ipairs(fresh) do
                local w = rowWidgets[data.userId]
                if w then
                    w.statusBar.BackgroundColor3 = data.inServer and THEME.Red or THEME.GreenDark
                    w.statusLbl.Text = data.inServer and ("IN SERVER: " .. tostring(data.playerName)) or "Not in server"
                    w.statusLbl.TextColor3 = data.inServer and THEME.Red or THEME.TextMid
                    w.gameIdLbl.Text = data.inServer and ("JobId: " .. tostring(game.JobId)) or "—"
                end
            end
        end
    end)

    content.CanvasSize = UDim2.new(0,0,0,o*34 + #ADMIN_ROSTER*50 + 200)
end

-- ============================================================
-- STATS TAB (farming time + cash estimate)
-- ============================================================
local function buildStats()
    clearContent(); local o=0; local function next() o=o+1; return o end

    makeSectionHeader("Session Stats", next())

    local function makeStatRow(labelText, order)
        local r = Instance.new("Frame")
        r.Size=UDim2.new(1,0,0,32); r.BackgroundColor3=THEME.Panel
        r.BorderSizePixel=0; r.LayoutOrder=order; r.Parent=content
        local rc = Instance.new("UICorner"); rc.CornerRadius=UDim.new(0,4); rc.Parent=r
        applyGradientStroke(r, 1, 0.55)

        local lbl = Instance.new("TextLabel")
        lbl.Size=UDim2.new(0.55,0,1,0); lbl.Position=UDim2.new(0,12,0,0)
        lbl.BackgroundTransparency=1; lbl.Text=labelText
        lbl.TextColor3=THEME.TextDim; lbl.TextSize=11; lbl.Font=FONT
        lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=r

        local val = Instance.new("TextLabel")
        val.Size=UDim2.new(0.43,0,1,0); val.Position=UDim2.new(0.56,0,0,0)
        val.BackgroundTransparency=1; val.Text="—"
        val.TextColor3=THEME.Green; val.TextSize=13; val.Font=Enum.Font.GothamBold
        val.TextXAlignment=Enum.TextXAlignment.Right; val.Parent=r
        applyUIGradient(val, THEME.GradA, THEME.GradC, 0)

        return r, val
    end

    local _, elapsedVal = makeStatRow("Farming time", next())
    local _, statusVal  = makeStatRow("Status", next())
    local _, cashVal    = makeStatRow("Est. cash earned", next())
    local _, perHourVal = makeStatRow("Est. cash / hour", next())
    local _, resetVal   = makeStatRow("Resets this session", next())

    makeSectionHeader("Pickups", next())
    local _, regVal  = makeStatRow("Registers", next())
    local _, atmVal  = makeStatRow("ATMs", next())
    local _, cashPickVal = makeStatRow("Floor cash", next())
    local _, dumpVal = makeStatRow("Dumpsters", next())
    local _, totalVal = makeStatRow("Total pickups", next())

    makeSectionHeader("Controls", next())

    local resetBtn = Instance.new("TextButton")
    resetBtn.Size=UDim2.new(1,0,0,34); resetBtn.BackgroundColor3=THEME.GreenDeep
    resetBtn.Text="RESET SESSION STATS"; resetBtn.TextColor3=THEME.Green
    resetBtn.TextSize=11; resetBtn.Font=Enum.Font.GothamBold
    resetBtn.BorderSizePixel=0; resetBtn.AutoButtonColor=false
    resetBtn.LayoutOrder=next(); resetBtn.Parent=content
    local rbc = Instance.new("UICorner"); rbc.CornerRadius=UDim.new(0,4); rbc.Parent=resetBtn
    local resetGrad = Instance.new("UIGradient"); resetGrad.Rotation=90
    resetGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, THEME.GradA),
        ColorSequenceKeypoint.new(1, THEME.GradB),
    })
    resetGrad.Parent = resetBtn
    applyGradientStroke(resetBtn, 1, 0.25)

    resetBtn.MouseButton1Click:Connect(function()
        sessionStats.startTime = tick()
        sessionStats.endTime = 0
        sessionStats.isRunning = state.farms.SuperFarm
        sessionStats.pickups = { Registers=0, ATMs=0, Cash=0, Dumpsters=0 }
        sessionStats.resets = 0
        sessionStats.estimatedCash = 0
    end)

    local note = Instance.new("TextLabel")
    note.Size=UDim2.new(1,0,0,32); note.BackgroundTransparency=1
    note.Text="Cash estimates are per-pickup approximations. Tune in part1 if needed."
    note.TextColor3=THEME.TextDim; note.TextSize=9; note.Font=FONT
    note.TextXAlignment=Enum.TextXAlignment.Left; note.TextWrapped=true
    note.LayoutOrder=next(); note.Parent=content

    content.CanvasSize = UDim2.new(0,0,0,o*34 + 200)

    -- live updater
    task.spawn(function()
        while content.Parent do
            task.wait(0.5)
            if not elapsedVal.Parent then break end
            elapsedVal.Text = sessionStats.formatTime(sessionStats.elapsed())
            statusVal.Text = sessionStats.isRunning and "FARMING" or (sessionStats.startTime > 0 and "PAUSED" or "IDLE")
            statusVal.TextColor3 = sessionStats.isRunning and THEME.Green or THEME.TextMid
            cashVal.Text = "$" .. tostring(sessionStats.estimatedCash)
            perHourVal.Text = "$" .. tostring(math.floor(sessionStats.perHour()))
            resetVal.Text = tostring(sessionStats.resets)
            regVal.Text = tostring(sessionStats.pickups.Registers)
            atmVal.Text = tostring(sessionStats.pickups.ATMs)
            cashPickVal.Text = tostring(sessionStats.pickups.Cash)
            dumpVal.Text = tostring(sessionStats.pickups.Dumpsters)
            totalVal.Text = tostring(sessionStats.totalPickups())
        end
    end)
end

-- ============================================================
-- SETTINGS TAB
-- ============================================================
local function buildSettings()
    clearContent(); local o=0; local function next() o=o+1; return o end
    makeSectionHeader("Protection", next())
    makeToggle("Anti-AFK", state.protection, "AntiAFK", function(v)
        if v then
            if antiAFKConnection then antiAFKConnection:Disconnect() end
            antiAFKConnection = localPlayer.Idled:Connect(function()
                pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end)
            end)
            C.antiAFKConnection = antiAFKConnection
        else
            if antiAFKConnection then antiAFKConnection:Disconnect(); antiAFKConnection=nil; C.antiAFKConnection=nil end
        end
    end, next())
    makeToggle("Low GFX", state.protection, "LowGFX", function(v) if v then lowGfxEnable() else lowGfxDisable() end end, next())
    makeToggle("FPS Boost", state.protection, "FPSBoost", function(v) if v then fpsBoostEnable() else fpsBoostDisable() end end, next())
    makeToggle("Damage Failsafe", state.protection, "DamageFailsafe", nil, next())
    makeSectionHeader("Tunables", next())
    makeOptionRow("TP stand offset", {3,4,5,6,8}, function() return tunables.tpStandOffset end, function(v) tunables.tpStandOffset=v end, next())
    makeOptionRow("TP interval (s)", {0.25,0.35,0.45,0.60}, function() return tunables.tpInterval end, function(v) tunables.tpInterval=v end, next())
    makeOptionRow("Register dwell (s)", {0.20,0.35,0.50,0.75}, function() return tunables.registerDwell end, function(v) tunables.registerDwell=v end, next())
    makeOptionRow("ATM dwell (s)", {1.0,1.6,2.0,2.5}, function() return tunables.atmDwell end, function(v) tunables.atmDwell=v end, next())
    makeOptionRow("Cash dwell (s)", {0.08,0.12,0.18,0.25}, function() return tunables.cashDwell end, function(v) tunables.cashDwell=v end, next())
    makeOptionRow("Hard-reset min gap (s)", {3,5,8,12}, function() return HARD_RESET_MIN_GAP end, function(v) HARD_RESET_MIN_GAP=v; C.HARD_RESET_MIN_GAP=v end, next())
    content.CanvasSize = UDim2.new(0,0,0,o*34+200)
end

local builders = {
    ["Farms"]=buildFarms, ["ESP"]=buildESP, ["Anti-Admin"]=buildAntiAdminTab,
    ["Stats"]=buildStats, ["Settings"]=buildSettings,
}
local function switchTab(name)
    state.currentTab = name
    for tn, b in pairs(tabButtons) do
        local active = tn == name
        b.BackgroundColor3 = active and THEME.TitleBar or THEME.BgAlt
        b.TextColor3 = active and THEME.Green or THEME.TextDim
        local info = tabGradients[tn]
        if info and info.gradient then
            info.gradient.Color = active
                and ColorSequence.new({
                    ColorSequenceKeypoint.new(0, THEME.GradA),
                    ColorSequenceKeypoint.new(0.5, THEME.GradC),
                    ColorSequenceKeypoint.new(1, THEME.GradB),
                })
                or ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 15, 15)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 8, 8)),
                })
            if info.stroke then
                info.stroke.Transparency = active and 0.1 or 0.65
            end
        end
    end
    local fn = builders[name]; if fn then pcall(fn) end
end
for name, b in pairs(tabButtons) do b.MouseButton1Click:Connect(function() switchTab(name) end) end
pcall(switchTab, "Farms")

close.MouseButton1Click:Connect(function()
    pcall(function() CleanersConfig.flush() end)
    pcall(function() screenGui:Destroy() end)
    state.running = false
    if sessionStats.isRunning then sessionStats.stop() end
end)
task.spawn(function() task.wait(4.1); pcall(function() screenGui.Enabled=true end) end)

-- resume farm with startup delay
task.spawn(function()
    task.wait(8)
    if not (CleanersConfig.loaded and state.farms.SuperFarm) then return end
    local waited = 0
    while waited < 5 do
        local ch = localPlayer.Character
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if ch and hum and hum.Health > 0 and ch:FindFirstChild("HumanoidRootPart") then break end
        task.wait(0.25); waited = waited + 0.25
    end
    if not (localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")) then
        warn("[Xenon] resume: character not ready after 13s — skipping resume")
        return
    end
    print("[Xenon] config: resuming SuperFarm")
    selectedFarmKey = "SuperFarm"; C.selectedFarmKey = "SuperFarm"
    teleportSystem.successfulTPs=0; teleportSystem.atmsSinceReset=0
    tpActionsSinceReset=0; tweenActionsSinceReset=0
    teleportSystem.generation = teleportSystem.generation + 1
    superFarmRunning=false; superFarmLastTick=tick()
    warmCache(); startFarmModule("SuperFarm")
end)

print("[Xenon] ============================================")
print("[Xenon] part2 DONE — UI loaded")
print("[Xenon] Xenon v15.9 loaded (5 tabs: Farms, ESP, Anti-Admin, Stats, Settings)")
print("[Xenon] ============================================")
