--[[
    XENON V2.1 — Full bug fix, movement rework, UI redesign
    -------------------------------------------------------
    Client-side developer control panel. Combat routes through the real
    weapon remotes (ShootGun / Stab / ThrowStart / ThrowHit) using the
    framework's CharacterRayOrigin / WeaponRaycast / BulletRenderer.
    Server still validates every hit — nothing here bypasses that.

    Changes vs V2.0:
      - Targeting rewritten (stable, validation-driven, priority actually
        re-picks target).
      - Lowest HP removed as misleading for MVSD; replaced with "Threat"
        (visibility + proximity composite) and "Crosshair" (true camera
        direction raycast, not positional comparison).
      - NoClip removed entirely.
      - Speed/Jump moved to a proper frame-rate-independent controller
        using Humanoid.WalkSpeed + JumpPower with reserve/respawn hygiene.
      - Fly rebuilt on HumanoidRootPart with smooth accel/decel and proper
        teardown on disable, death, and GUI close.
      - UI rebuilt: compact 640×420, thin borders, animated glowing sweep
        lines, gradient lighting, stable tab state, smooth transitions.
      - All dead code from V2.0 removed.
]]

-- ============================================================
-- 0. RE-EXECUTION GUARD
-- ============================================================
if _G.__XENON_PANEL   then pcall(function() _G.__XENON_PANEL:Destroy()   end) end
if _G.__XENON_NOTIFS  then pcall(function() _G.__XENON_NOTIFS:Destroy()  end) end
if _G.__XENON_LOOPS   then
    for _,c in ipairs(_G.__XENON_LOOPS) do pcall(function() c:Disconnect() end) end
end
_G.__XENON_LOOPS = {}

-- ============================================================
-- 1. SERVICES
-- ============================================================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local Workspace         = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera
local Mouse       = LocalPlayer:GetMouse()

-- ============================================================
-- 2. SAFE MODULE LOADER
-- ============================================================
local function safeRequire(path)
    local ok, result = pcall(function()
        local node = ReplicatedStorage
        for _, seg in ipairs(path) do
            node = node:WaitForChild(seg, 5)
            if not node then error("missing "..seg) end
        end
        return require(node)
    end)
    return ok and result or nil
end

local CharacterRayOrigin = safeRequire({"Modules", "CharacterRayOrigin"})
local BulletRenderer     = safeRequire({"Modules", "BulletRenderer"})
local WeaponRaycast      = safeRequire({"Modules", "WeaponRaycast"})
local CollisionGroups    = safeRequire({"Modules", "CollisionGroups"})
local Maid               = safeRequire({"Modules", "Util", "Maid"})
local Tags               = safeRequire({"Modules", "Tags"})
local InvulnController   = safeRequire({"Ability", "InvulnerableStateController"})

local Remotes        = ReplicatedStorage:FindFirstChild("Remotes")
local ShootGunRemote = Remotes and Remotes:FindFirstChild("ShootGun")
local StabRemote     = Remotes and Remotes:FindFirstChild("Stab")
local ThrowStartRmt  = Remotes and Remotes:FindFirstChild("ThrowStart")
local ThrowHitRmt    = Remotes and Remotes:FindFirstChild("ThrowHit")

local HAS_COMBAT     = CharacterRayOrigin and BulletRenderer and WeaponRaycast
                       and CollisionGroups and ShootGunRemote ~= nil
local HAS_KNIFE      = CharacterRayOrigin and WeaponRaycast and CollisionGroups
                       and StabRemote ~= nil
local GUN_TAG        = (Tags and Tags.GUN_TOOL)   or "GUN_TOOL"
local KNIFE_TAG      = (Tags and Tags.KNIFE_TOOL) or "KNIFE_TOOL"
local SCREEN_GROUP   = (CollisionGroups and CollisionGroups.SCREEN_RAYCAST) or "ScreenRaycast"

-- ============================================================
-- 3. MAID
-- ============================================================
local MaidImpl = Maid
if not MaidImpl then
    local M = {}; M.__index = M
    function M.new() return setmetatable({ _t = {} }, M) end
    function M:GiveTask(t) table.insert(self._t, t); return t end
    function M:DoCleaning()
        for _, t in ipairs(self._t) do pcall(function()
            if typeof(t) == "RBXScriptConnection" then t:Disconnect()
            elseif typeof(t) == "Instance" then t:Destroy()
            elseif type(t) == "function" then t() end
        end) end
        self._t = {}
    end
    MaidImpl = M
end
local toolMaid = MaidImpl.new()

-- ============================================================
-- 4. THEME & STATE
-- ============================================================
local Theme = {
    Background = Color3.fromRGB(8, 8, 10),
    Window     = Color3.fromRGB(16, 12, 14),
    Panel      = Color3.fromRGB(22, 18, 20),
    PanelAlt   = Color3.fromRGB(30, 24, 26),
    Border     = Color3.fromRGB(100, 15, 20),
    Accent     = Color3.fromRGB(220, 25, 35),
    AccentSoft = Color3.fromRGB(150, 20, 28),
    AccentGlow = Color3.fromRGB(255, 55, 65),
    Text       = Color3.fromRGB(235, 232, 235),
    TextDim    = Color3.fromRGB(155, 150, 155),
    TextFaint  = Color3.fromRGB(90, 86, 90),
    Success    = Color3.fromRGB(55, 200, 115),
    Warning    = Color3.fromRGB(240, 170, 60),
    Error      = Color3.fromRGB(235, 60, 65),
    Info       = Color3.fromRGB(70, 165, 235),
}
local FONT       = Enum.Font.Gotham
local FONT_BOLD  = Enum.Font.GothamBold
local FONT_MED   = Enum.Font.GothamMedium
local FONT_BLACK = Enum.Font.GothamBlack

local State = {
    scale=1, transparency=0, animationSpeed=1,
    toggleKey=Enum.KeyCode.RightShift, notificationsOn=true, performanceMode=false,
    sessionStart=tick(), version="V2.1",

    -- combat
    autoKill=false, maxTargetDist=500, targetNPCs=true, teamCheck=false,
    losTest=false, targetPriority="Closest",
    closestTarget=nil, closestTargetPrev=nil,  -- for detecting switched targets
    currentTool=nil, currentToolKind=nil, lastFireTick=0,

    -- movement
    speedEnabled=false, speedValue=16,
    jumpEnabled=false, jumpValue=50,
    flyEnabled=false, flySpeed=60,

    -- visuals
    espEnabled=false, espNames=true, espHealth=true, espDistance=true,
    espHighlights=true, espNPCs=true,
    espColor=Color3.fromRGB(255, 40, 40), espTeamColors=false, espTextSize=12,
    espTrackers={},
}

local function setAccent(c)
    Theme.Accent     = c
    Theme.AccentSoft = Color3.new(c.R*0.7, c.G*0.7, c.B*0.7)
    Theme.AccentGlow = Color3.new(math.min(c.R*1.15,1), math.min(c.G*1.15,1), math.min(c.B*1.15,1))
end

-- ============================================================
-- 5. UI HELPERS
-- ============================================================
local function new(class, props, children)
    local inst = Instance.new(class)
    for k,v in pairs(props or {}) do inst[k]=v end
    for _,ch in ipairs(children or {}) do ch.Parent=inst end
    return inst
end
local function corner(p, r)  return new("UICorner",{CornerRadius=UDim.new(0,r or 6), Parent=p}) end
local function stroke(p, c, t, tr)
    return new("UIStroke",{Color=c or Theme.Border, Thickness=t or 1,
        Transparency=tr or 0, ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Parent=p})
end
local function padding(p,n)
    return new("UIPadding",{PaddingTop=UDim.new(0,n),PaddingBottom=UDim.new(0,n),
        PaddingLeft=UDim.new(0,n),PaddingRight=UDim.new(0,n),Parent=p})
end
local function tween(inst, props, dur)
    local t = TweenService:Create(inst,
        TweenInfo.new((dur or 0.2)/State.animationSpeed, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        props)
    t:Play(); return t
end

-- ============================================================
-- 6. NOTIFICATIONS
-- ============================================================
local notifHolder
local function Notify(title, msg, kind, dur)
    if not State.notificationsOn or not notifHolder then return end
    kind = kind or "info"; dur = dur or 3
    local colors = {success=Theme.Success, warning=Theme.Warning, error=Theme.Error, info=Theme.Info}
    local accent = colors[kind] or Theme.Info
    local toast = new("Frame",{
        Size=UDim2.new(0,260,0,54), Position=UDim2.new(1,280,0,0),
        BackgroundColor3=Theme.Panel, BorderSizePixel=0, ClipsDescendants=true,
    })
    corner(toast,6); stroke(toast,accent,1,0.35)
    new("Frame",{Size=UDim2.new(0,2,1,0),BackgroundColor3=accent,BorderSizePixel=0,Parent=toast})
    new("TextLabel",{Size=UDim2.new(1,-14,0,18),Position=UDim2.new(0,10,0,6),
        BackgroundTransparency=1, Text=title, TextColor3=Theme.Text,
        Font=FONT_BOLD, TextSize=12, TextXAlignment=Enum.TextXAlignment.Left, Parent=toast})
    new("TextLabel",{Size=UDim2.new(1,-14,0,24),Position=UDim2.new(0,10,0,24),
        BackgroundTransparency=1, Text=msg, TextColor3=Theme.TextDim,
        Font=FONT, TextSize=11, TextWrapped=true,
        TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top, Parent=toast})
    local prog = new("Frame",{Size=UDim2.new(1,0,0,2),Position=UDim2.new(0,0,1,-2),
        BackgroundColor3=accent, BorderSizePixel=0, Parent=toast})
    local idx = #notifHolder:GetChildren()
    toast.Position = UDim2.new(1,280,0,idx*62)
    toast.Parent = notifHolder
    tween(toast,{Position=UDim2.new(1,-16,0,idx*62)},0.3)
    tween(prog,{Size=UDim2.new(0,0,0,2)},dur)
    task.delay(dur+0.1,function()
        if toast and toast.Parent then
            tween(toast,{Position=UDim2.new(1,280,0,toast.Position.Y.Offset)},0.28)
            task.delay(0.3,function() if toast then toast:Destroy() end end)
        end
    end)
end

-- ============================================================
-- 7. ROOT GUI
-- ============================================================
local Screen = new("ScreenGui",{Name="XENON_PANEL",ResetOnSpawn=false,IgnoreGuiInset=true,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=9999,
    Parent=LocalPlayer:WaitForChild("PlayerGui")})
_G.__XENON_PANEL = Screen

local notifGui = new("ScreenGui",{Name="XENON_NOTIFS",ResetOnSpawn=false,IgnoreGuiInset=true,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=10000,
    Parent=LocalPlayer:WaitForChild("PlayerGui")})
_G.__XENON_NOTIFS = notifGui
notifHolder = new("Frame",{Size=UDim2.new(0,280,1,0),BackgroundTransparency=1,Parent=notifGui})

-- ============================================================
-- 8. MAIN WINDOW (compact 640×420)
-- ============================================================
local BASE_W, BASE_H = 640, 420
local Main = new("Frame",{Name="Main",
    Size=UDim2.new(0,BASE_W,0,BASE_H),
    Position=UDim2.new(0.5,-BASE_W/2,0.5,-BASE_H/2),
    BackgroundColor3=Theme.Window, BorderSizePixel=0,
    ClipsDescendants=true, Parent=Screen})
corner(Main,10)
local mainStroke = stroke(Main, Theme.Border, 1, 0.15)
mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- animated gradient background
local bgGrad = new("UIGradient",{
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, Color3.fromRGB(20, 8, 10)),
        ColorSequenceKeypoint.new(0.35, Color3.fromRGB(28, 10, 12)),
        ColorSequenceKeypoint.new(0.65, Color3.fromRGB(16, 6, 8)),
        ColorSequenceKeypoint.new(1.0, Color3.fromRGB(24, 10, 12)),
    }),
    Rotation = 0, Parent = Main})
_G.__XENON_LOOPS[#_G.__XENON_LOOPS+1] = TweenService:Create(
    bgGrad,
    TweenInfo.new(9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    { Rotation = 360 }
):Play()

-- animated glowing sweep lines (3 across the window, unobtrusive)
local function makeSweepLine(delay, thickness, transparency)
    local line = new("Frame",{
        Size=UDim2.new(0,0,0,thickness), BackgroundColor3=Theme.AccentGlow,
        BorderSizePixel=0, BackgroundTransparency=transparency or 0.7,
        Position=UDim2.new(0,0,0.2,0), Rotation=-25, Parent=Main, ZIndex=0,
    })
    corner(line, thickness/2)
    local grad = new("UIGradient",{
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.0, Color3.new(0,0,0)),
            ColorSequenceKeypoint.new(0.5, Theme.AccentGlow),
            ColorSequenceKeypoint.new(1.0, Color3.new(0,0,0)),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.0, 1),
            NumberSequenceKeypoint.new(0.5, 0.2),
            NumberSequenceKeypoint.new(1.0, 1),
        }),
        Parent = line,
    })
    local function run()
        if not line or not line.Parent then return end
        local fromY = math.random(5, 90) / 100
        line.Position = UDim2.new(0, -BASE_W, fromY, 0)
        line.Size = UDim2.new(0, BASE_W*1.4, 0, thickness)
        local duration = 5 + math.random()*2
        local t = TweenService:Create(line,
            TweenInfo.new(duration, Enum.EasingStyle.Linear),
            { Position = UDim2.new(0, BASE_W, fromY + 0.05, 0) })
        t:Play()
        t.Completed:Connect(function() task.wait(delay); run() end)
    end
    task.delay(delay, run)
end
makeSweepLine(0.0, 1, 0.75)
makeSweepLine(3.5, 1, 0.8)
makeSweepLine(7.0, 1, 0.85)

-- ============================================================
-- 9. TOP BAR
-- ============================================================
local TopBar = new("Frame",{
    Size=UDim2.new(1,0,0,36),
    BackgroundColor3=Theme.Panel, BorderSizePixel=0, Parent=Main,
    ZIndex=2,
})
corner(TopBar,10)

new("TextLabel",{
    Size=UDim2.new(0,90,1,0), Position=UDim2.new(0,12,0,0),
    BackgroundTransparency=1, Text="XENON",
    TextColor3=Theme.Accent, Font=FONT_BLACK, TextSize=16,
    TextXAlignment=Enum.TextXAlignment.Left, Parent=TopBar, ZIndex=3,
})
new("TextLabel",{
    Size=UDim2.new(0,150,1,0), Position=UDim2.new(0,66,0,0),
    BackgroundTransparency=1, Text="CONTROL SYSTEM · "..State.version,
    TextColor3=Theme.TextFaint, Font=FONT_MED, TextSize=9,
    TextXAlignment=Enum.TextXAlignment.Left, Parent=TopBar, ZIndex=3,
})

local statusDot = new("Frame",{
    Size=UDim2.new(0,6,0,6), Position=UDim2.new(1,-108,0.5,-3),
    BackgroundColor3=Theme.Success, BorderSizePixel=0, Parent=TopBar, ZIndex=3,
})
corner(statusDot,3)
_G.__XENON_LOOPS[#_G.__XENON_LOOPS+1] = TweenService:Create(
    statusDot,
    TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    { BackgroundColor3 = Color3.fromRGB(95,255,155) }
):Play()
new("TextLabel",{
    Size=UDim2.new(0,60,1,0), Position=UDim2.new(1,-96,0,0),
    BackgroundTransparency=1, Text="ONLINE",
    TextColor3=Theme.Success, Font=FONT_BOLD, TextSize=9,
    TextXAlignment=Enum.TextXAlignment.Left, Parent=TopBar, ZIndex=3,
})

local minBtn = new("TextButton",{
    Size=UDim2.new(0,22,0,22), Position=UDim2.new(1,-54,0.5,-11),
    BackgroundColor3=Theme.PanelAlt, Text="—", TextColor3=Theme.Text,
    Font=FONT_BOLD, TextSize=12, AutoButtonColor=false,
    Parent=TopBar, ZIndex=3,
})
corner(minBtn,4)
local closeBtn = new("TextButton",{
    Size=UDim2.new(0,22,0,22), Position=UDim2.new(1,-28,0.5,-11),
    BackgroundColor3=Theme.PanelAlt, Text="✕", TextColor3=Theme.Accent,
    Font=FONT_BOLD, TextSize=12, AutoButtonColor=false,
    Parent=TopBar, ZIndex=3,
})
corner(closeBtn,4)

-- drag
do
    local dragging, dragStart, startPos = false, nil, nil
    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging=true; dragStart=input.Position; startPos=Main.Position
            input.Changed:Connect(function()
                if input.UserInputState==Enum.UserInputState.End then dragging=false end
            end)
        end
    end)
    local c = UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then
            local dx=input.Position.X-dragStart.X
            local dy=input.Position.Y-dragStart.Y
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+dx,
                startPos.Y.Scale, startPos.Y.Offset+dy)
        end
    end)
    _G.__XENON_LOOPS[#_G.__XENON_LOOPS+1] = c
end

-- ============================================================
-- 10. SIDEBAR + TABS
-- ============================================================
local SIDE_W = 148
local Sidebar = new("Frame",{
    Size=UDim2.new(0,SIDE_W,1,-36), Position=UDim2.new(0,0,0,36),
    BackgroundColor3=Theme.Panel, BorderSizePixel=0, Parent=Main, ZIndex=2,
})
new("UIListLayout",{Padding=UDim.new(0,2), SortOrder=Enum.SortOrder.LayoutOrder,
    HorizontalAlignment=Enum.HorizontalAlignment.Center, Parent=Sidebar})
padding(Sidebar, 6)

-- active indicator sits on the left edge of the selected tab
local activeIndicator = new("Frame",{
    Size=UDim2.new(0,2,0,26), Position=UDim2.new(0,0,0,0),
    BackgroundColor3=Theme.Accent, BorderSizePixel=0, Parent=Sidebar, ZIndex=3,
})
corner(activeIndicator, 1)

local Content = new("Frame",{
    Size=UDim2.new(1,-SIDE_W,1,-36), Position=UDim2.new(0,SIDE_W,0,36),
    BackgroundColor3=Theme.Window, BackgroundTransparency=0.4,
    BorderSizePixel=0, ClipsDescendants=true, Parent=Main, ZIndex=1,
})

local pages, tabs, currentTab = {}, {}, nil

local TABS = {
    {key="dashboard", label="Dashboard", icon="◈"},
    {key="combat",    label="Combat",    icon="⚔"},
    {key="visuals",   label="Visuals",   icon="◉"},
    {key="movement",  label="Movement",  icon="➤"},
    {key="weapons",   label="Weapons",   icon="✦"},
    {key="player",    label="Player",    icon="☻"},
    {key="settings",  label="Settings",  icon="⚙"},
    {key="info",      label="About",     icon="ℹ"},
}

local function makePage(key)
    local p = new("ScrollingFrame",{
        Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
        BorderSizePixel=0, ScrollBarThickness=3,
        ScrollBarImageColor3=Theme.AccentSoft,
        CanvasSize=UDim2.new(0,0,0,0), Visible=false, Parent=Content,
    })
    new("UIListLayout",{Padding=UDim.new(0,6), SortOrder=Enum.SortOrder.LayoutOrder, Parent=p})
    padding(p, 12)
    pages[key] = p
    return p
end

local function setTabVisual(tabKey, isActive)
    local btn = tabs[tabKey]
    if not btn then return end
    local icon = btn:FindFirstChildWhichIsA("TextLabel", true)
    local label = btn:FindFirstChild("Label")
    if isActive then
        tween(btn, { BackgroundColor3 = Theme.PanelAlt, BackgroundTransparency = 0 }, 0.2)
        if icon then tween(icon, { TextColor3 = Theme.AccentGlow }, 0.2) end
        if label then tween(label, { TextColor3 = Theme.Text }, 0.2) end
    else
        tween(btn, { BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.5 }, 0.2)
        if icon then tween(icon, { TextColor3 = Theme.Accent }, 0.2) end
        if label then tween(label, { TextColor3 = Theme.TextDim }, 0.2) end
    end
end

local function switchTab(key)
    if currentTab == key then return end
    for k, p in pairs(pages) do p.Visible = (k == key) end
    if currentTab then setTabVisual(currentTab, false) end
    setTabVisual(key, true)
    local b = tabs[key]
    if b then
        tween(activeIndicator,
            { Position = UDim2.new(0, 0, 0, b.AbsolutePosition.Y - Sidebar.AbsolutePosition.Y) },
            0.22)
    end
    currentTab = key
end

for i, t in ipairs(TABS) do
    local btn = new("TextButton",{
        Size=UDim2.new(1,0,0,26),
        BackgroundColor3=Theme.Panel, BackgroundTransparency=0.5,
        Text="", AutoButtonColor=false, LayoutOrder=i, Parent=Sidebar, ZIndex=2,
    })
    corner(btn, 4)
    local iconLbl = new("TextLabel",{
        Size=UDim2.new(0,22,1,0), Position=UDim2.new(0,6,0,0),
        BackgroundTransparency=1, Text=t.icon, TextColor3=Theme.Accent,
        Font=FONT_BOLD, TextSize=12, Parent=btn, ZIndex=3,
    })
    local labelLbl = new("TextLabel",{
        Name="Label", Size=UDim2.new(1,-28,1,0), Position=UDim2.new(0,26,0,0),
        BackgroundTransparency=1, Text=t.label, TextColor3=Theme.TextDim,
        Font=FONT_MED, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left,
        Parent=btn, ZIndex=3,
    })
    btn.MouseEnter:Connect(function()
        if currentTab ~= t.key then
            tween(btn, { BackgroundTransparency = 0.2 }, 0.15)
        end
    end)
    btn.MouseLeave:Connect(function()
        if currentTab ~= t.key then
            tween(btn, { BackgroundTransparency = 0.5 }, 0.15)
        end
    end)
    btn.MouseButton1Click:Connect(function() switchTab(t.key) end)
    tabs[t.key] = btn
    makePage(t.key)
end

-- ============================================================
-- 11. UI PRIMITIVES
-- ============================================================
local function sectionTitle(parent, text, order)
    return new("TextLabel",{
        Size=UDim2.new(1,0,0,16), BackgroundTransparency=1, Text=text,
        TextColor3=Theme.Accent, Font=FONT_BOLD, TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Left,
        LayoutOrder=order or 0, Parent=parent,
    })
end
local function card(parent, order)
    local f = new("Frame",{
        Size=UDim2.new(1,0,0,0),
        AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundColor3=Theme.Panel, BorderSizePixel=0,
        LayoutOrder=order or 0, Parent=parent,
    })
    corner(f, 6); stroke(f, Theme.Border, 1, 0.7); padding(f, 8)
    new("UIListLayout",{Padding=UDim.new(0,4), SortOrder=Enum.SortOrder.LayoutOrder, Parent=f})
    return f
end
local function label(parent, text, color, bold, order)
    return new("TextLabel",{
        Size=UDim2.new(1,0,0,14), BackgroundTransparency=1, Text=text,
        TextColor3=color or Theme.Text, Font=bold and FONT_BOLD or FONT,
        TextSize=11, TextXAlignment=Enum.TextXAlignment.Left,
        LayoutOrder=order or 0, Parent=parent,
    })
end
local function button(parent, text, order, onClick)
    local b = new("TextButton",{
        Size=UDim2.new(1,0,0,24), BackgroundColor3=Theme.PanelAlt,
        Text=text, TextColor3=Theme.Text, Font=FONT_MED, TextSize=11,
        AutoButtonColor=false, LayoutOrder=order or 0, Parent=parent,
    })
    corner(b, 4); local s = stroke(b, Theme.Accent, 1, 1)
    b.MouseEnter:Connect(function()
        tween(b, { BackgroundColor3 = Theme.AccentSoft }, 0.12)
        tween(s, { Transparency = 0.2 }, 0.12)
    end)
    b.MouseLeave:Connect(function()
        tween(b, { BackgroundColor3 = Theme.PanelAlt }, 0.12)
        tween(s, { Transparency = 1 }, 0.12)
    end)
    b.MouseButton1Click:Connect(onClick)
    return b
end
local function toggle(parent, text, order, getState, setState, onChange)
    local row = new("Frame",{Size=UDim2.new(1,0,0,24), BackgroundTransparency=1,
        LayoutOrder=order or 0, Parent=parent})
    new("TextLabel",{Size=UDim2.new(1,-56,1,0), BackgroundTransparency=1,
        Text=text, TextColor3=Theme.Text, Font=FONT, TextSize=11,
        TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
    local track = new("Frame",{Size=UDim2.new(0,36,0,18), Position=UDim2.new(1,-36,0.5,-9),
        BackgroundColor3=Theme.PanelAlt, BorderSizePixel=0, Parent=row})
    corner(track, 9)
    local knob = new("Frame",{Size=UDim2.new(0,14,0,14), Position=UDim2.new(0,2,0.5,-7),
        BackgroundColor3=Theme.TextDim, BorderSizePixel=0, Parent=track})
    corner(knob, 7)
    local function refresh()
        local on = getState()
        tween(track, { BackgroundColor3 = on and Theme.Accent or Theme.PanelAlt }, 0.18)
        tween(knob, {
            Position = on and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7),
            BackgroundColor3 = on and Theme.Text or Theme.TextDim }, 0.18)
    end
    refresh()
    local click = new("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",Parent=row})
    click.MouseButton1Click:Connect(function()
        setState(not getState()); refresh()
        if onChange then onChange(getState()) end
    end)
    return refresh
end
local function numberInput(parent, text, order, getValue, setValue, onCommit)
    local row = new("Frame",{Size=UDim2.new(1,0,0,24), BackgroundTransparency=1,
        LayoutOrder=order or 0, Parent=parent})
    new("TextLabel",{Size=UDim2.new(0.55,0,1,0), BackgroundTransparency=1, Text=text,
        TextColor3=Theme.Text, Font=FONT, TextSize=11,
        TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
    local box = new("TextBox",{Size=UDim2.new(0.4,0,1,0), Position=UDim2.new(0.6,0,0,0),
        BackgroundColor3=Theme.PanelAlt, Text=tostring(getValue()), TextColor3=Theme.Text,
        Font=FONT, TextSize=11, ClearTextOnFocus=false, Parent=row})
    corner(box, 4)
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then setValue(n); if onCommit then onCommit(n) end end
        box.Text = tostring(getValue())
    end)
    return box
end
local function dropdown(parent, text, order, options, getValue, setValue)
    local row = new("Frame",{Size=UDim2.new(1,0,0,24), BackgroundTransparency=1,
        LayoutOrder=order or 0, Parent=parent})
    new("TextLabel",{Size=UDim2.new(0.5,0,1,0), BackgroundTransparency=1, Text=text,
        TextColor3=Theme.Text, Font=FONT, TextSize=11,
        TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
    local btn = new("TextButton",{Size=UDim2.new(0.45,0,1,0), Position=UDim2.new(0.55,0,0,0),
        BackgroundColor3=Theme.PanelAlt, Text=getValue().." ▾", TextColor3=Theme.Text,
        Font=FONT, TextSize=11, AutoButtonColor=false, Parent=row})
    corner(btn, 4); stroke(btn, Theme.Accent, 1, 0.5)
    local idx = 1
    for i, o in ipairs(options) do if o == getValue() then idx = i; break end end
    btn.MouseButton1Click:Connect(function()
        idx = idx % #options + 1
        setValue(options[idx]); btn.Text = options[idx].." ▾"
    end)
    return btn
end

-- ============================================================
-- 12. TARGETING (rewritten)
-- ============================================================
local function getLocalPosition()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    return root and root.Position or nil
end
local function isAlive(char)
    if not char or not char.Parent then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end
local function getRoot(char)
    return char and char:FindFirstChild("HumanoidRootPart")
end
local function isInvulnerable(char)
    if not InvulnController then return false end
    local ok, res = pcall(function() return InvulnController.hasState(char) end)
    return ok and res or false
end
local function isFFA(plr)
    return plr.Team and plr.Team.Name == "FFA_Team"
end
local function validTarget(char, plr)
    if not char or not char.Parent then return false end
    if char == LocalPlayer.Character then return false end
    if not isAlive(char) then return false end
    if isInvulnerable(char) then return false end
    if plr and plr == LocalPlayer then return false end
    if plr and State.teamCheck and plr.Team and LocalPlayer.Team
        and plr.Team == LocalPlayer.Team and not isFFA(plr) then
        return false
    end
    return true
end

-- For "Threat" priority we combine proximity and crosshair alignment
local function cameraForward()
    return Camera.CFrame.LookVector
end

-- Screen-space aim point from current crosshair
local function crosshairAim()
    if WeaponRaycast and WeaponRaycast.convertScreenPointToVector3 then
        return WeaponRaycast.convertScreenPointToVector3(UserInputService:GetMouseLocation())
    end
    return Camera.CFrame.Position + Camera.CFrame.LookVector * 1000
end

-- Score-based targeting: always returns the SINGLE best candidate.
-- Priority changes in State.targetPriority cause re-selection on next tick.
local function findClosestTarget()
    local myPos = getLocalPosition()
    if not myPos then return nil end

    local candidates = {}
    local camLook   = cameraForward()
    local aimPoint  = crosshairAim()

    local function consider(char, plr)
        if not validTarget(char, plr) then return end
        local root = getRoot(char)
        if not root then return end
        local d = (root.Position - myPos).Magnitude
        if d > State.maxTargetDist then return end
        -- raycast line-of-sight visibility (used only for threat scoring)
        local visible = 0
        if WeaponRaycast then
            local origin = CharacterRayOrigin and CharacterRayOrigin(LocalPlayer.Character) or myPos
            if origin then
                local hit = WeaponRaycast(origin, root.Position)
                if hit and (hit.Instance == root or hit.Instance:IsDescendantOf(char)) then
                    visible = 1
                end
            end
        end
        local toTarget = (root.Position - myPos).Unit
        local align    = camLook:Dot(toTarget)          -- 1 = dead-on crosshair
        table.insert(candidates, {
            char=char, dist=d, visible=visible, align=align,
        })
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        consider(plr.Character, plr)
    end
    if State.targetNPCs then
        for _, model in ipairs(Workspace:GetChildren()) do
            if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid")
               and not Players:GetPlayerFromCharacter(model) then
                consider(model, nil)
            end
        end
    end

    if #candidates == 0 then return nil end

    local priority = State.targetPriority
    if priority == "Closest" then
        table.sort(candidates, function(a,b) return a.dist < b.dist end)
    elseif priority == "Farthest" then
        table.sort(candidates, function(a,b) return a.dist > b.dist end)
    elseif priority == "Crosshair" then
        table.sort(candidates, function(a,b) return a.align > b.align end)
    elseif priority == "Threat" then
        -- Threat = visible first, then closer, then better aligned
        table.sort(candidates, function(a,b)
            if a.visible ~= b.visible then return a.visible > b.visible end
            if math.abs(a.dist - b.dist) > 25 then return a.dist < b.dist end
            return a.align > b.align
        end)
    else
        table.sort(candidates, function(a,b) return a.dist < b.dist end)
    end
    return candidates[1].char
end

-- Stable re-evaluation: if priority changed, force re-pick next tick
local function reevaluateTarget()
    if not State.autoKill then State.closestTarget = nil; return end
    local cur = State.closestTarget
    if cur and not validTarget(cur, Players:GetPlayerFromCharacter(cur)) then
        State.closestTarget = nil
    end
    if cur and getRoot(cur) and getLocalPosition()
        and (getRoot(cur).Position - getLocalPosition()).Magnitude > State.maxTargetDist then
        State.closestTarget = nil
    end
    if not State.closestTarget then
        State.closestTarget = findClosestTarget()
    end
end

-- ============================================================
-- 13. COMBAT — gun (exact framework pipeline)
-- ============================================================
local function fireGunAt(aimPos)
    if not HAS_COMBAT then return end
    local tool = State.currentTool
    if not tool or State.currentToolKind ~= "gun" then return end
    if not tool.Enabled then return end
    local cd = tool:GetAttribute("Cooldown") or 0
    if State.lastFireTick ~= 0 and cd > tick() - State.lastFireTick then return end
    local muzzle = tool:FindFirstChild("Muzzle", true)
    if not muzzle then return end
    State.lastFireTick = tick()

    local screenHit = WeaponRaycast(Camera.CFrame.Position, aimPos, nil, SCREEN_GROUP)
    local origin    = CharacterRayOrigin(LocalPlayer.Character)
    if not origin then return end
    local endAim    = (screenHit and screenHit.Position) or aimPos
    local weaponHit = WeaponRaycast(origin, endAim)
    if not weaponHit and screenHit then weaponHit = screenHit end

    local snd = tool:FindFirstChild("Fire")
    if snd then pcall(function() snd:Play() end) end
    BulletRenderer(muzzle.WorldPosition,
        (weaponHit and weaponHit.Position) or endAim,
        tool:GetAttribute("BulletType"))
    tool:Activate()
    ShootGunRemote:FireServer(
        origin, aimPos,
        weaponHit and weaponHit.Instance or nil,
        weaponHit and weaponHit.Position or nil
    )
end

-- Knife: stab / throw through real remotes
local function tryStabTarget(root)
    if not StabRemote or not root or not root.Parent then return end
    local hum = root.Parent:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    pcall(function() StabRemote:FireServer(root) end)
end
local function throwKnifeAt(aimPos)
    if not (ThrowStartRmt and ThrowHitRmt) then return end
    local tool = State.currentTool
    if not tool or State.currentToolKind ~= "knife" then return end
    local cd = tool:GetAttribute("Cooldown") or 0
    if State.lastFireTick ~= 0 and cd > tick() - State.lastFireTick then return end
    State.lastFireTick = tick()
    local origin = CharacterRayOrigin(LocalPlayer.Character)
    if not origin then return end
    local screenHit = WeaponRaycast(Camera.CFrame.Position, aimPos, nil, SCREEN_GROUP)
    local endAim    = (screenHit and screenHit.Position) or aimPos
    local weaponHit = WeaponRaycast(origin, endAim)
    if not weaponHit and screenHit then weaponHit = screenHit end
    local dir = (endAim - origin).Unit
    pcall(function() ThrowStartRmt:FireServer(origin, dir) end)
    task.delay(0.18, function()
        ThrowHitRmt:FireServer(
            weaponHit and weaponHit.Instance or nil,
            weaponHit and weaponHit.Position or nil)
    end)
end

-- ============================================================
-- 14. TOOL BINDING
-- ============================================================
local function bindTool(tool)
    toolMaid:DoCleaning()
    State.currentTool = tool
    State.currentToolKind = nil
    State.lastFireTick = 0
    if CollectionService:HasTag(tool, GUN_TAG) then
        State.currentToolKind = "gun"
    elseif CollectionService:HasTag(tool, KNIFE_TAG) then
        State.currentToolKind = "knife"
    end
    toolMaid:GiveTask(tool.AncestryChanged:Connect(function()
        if not tool:IsDescendantOf(LocalPlayer.Character) then
            if State.currentTool == tool then
                State.currentTool = nil; State.currentToolKind = nil
            end
        end
    end))
end
local function scanCharacter(char)
    if not char then return end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool")
           and (CollectionService:HasTag(child, GUN_TAG) or CollectionService:HasTag(child, KNIFE_TAG)) then
            bindTool(child)
        end
    end
end
_G.__XENON_LOOPS[#_G.__XENON_LOOPS+1] = CollectionService:GetInstanceAddedSignal(GUN_TAG):Connect(function(inst)
    if inst:IsA("Tool") and inst:IsDescendantOf(LocalPlayer.Character) then bindTool(inst) end
end)
_G.__XENON_LOOPS[#_G.__XENON_LOOPS+1] = CollectionService:GetInstanceAddedSignal(KNIFE_TAG):Connect(function(inst)
    if inst:IsA("Tool") and inst:IsDescendantOf(LocalPlayer.Character) then bindTool(inst) end
end)
_G.__XENON_LOOPS[#_G.__XENON_LOOPS+1] = LocalPlayer.CharacterAdded:Connect(function(c)
    State.currentTool = nil; State.currentToolKind = nil
    State.closestTarget = nil
    task.defer(function() scanCharacter(c) end)
end)
if LocalPlayer.Character then scanCharacter(LocalPlayer.Character) end

-- ============================================================
-- 15. MOVEMENT — Speed / Jump controller
-- ============================================================
local movementState = { defaults = {}, applied = false }

local function readDefault(hum)
    movementState.defaults.WalkSpeed = hum.WalkSpeed
    movementState.defaults.JumpPower = hum.JumpPower
    movementState.defaults.UseJumpPower = hum.UseJumpPower
end
local function applyMovement()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if not movementState.applied then
        readDefault(hum)
        movementState.applied = true
    end
    if State.speedEnabled then
        hum.WalkSpeed = math.clamp(State.speedValue, 0, 500)
    else
        hum.WalkSpeed = movementState.defaults.WalkSpeed or 16
    end
    if State.jumpEnabled then
        hum.UseJumpPower = true
        hum.JumpPower = math.clamp(State.jumpValue, 0, 500)
    else
        hum.UseJumpPower = movementState.defaults.UseJumpPower
        hum.JumpPower = movementState.defaults.JumpPower or 50
    end
end

-- Re-apply on respawn (deferred so Humanoid is present)
_G.__XENON_LOOPS[#_G.__XENON_LOOPS+1] = LocalPlayer.CharacterAdded:Connect(function()
    movementState.applied = false
    task.delay(0.2, applyMovement)
end)

-- ============================================================
-- 16. FLY — HumanoidRootPart controller with smoothing
-- ============================================================
local flyState = {
    active = false,
    root = nil,
    velocity = Vector3.zero,
    conn = nil,
}

local function stopFly()
    flyState.active = false
    flyState.velocity = Vector3.zero
    if flyState.conn then flyState.conn:Disconnect(); flyState.conn = nil end
    if flyState.root then
        local bg = flyState.root:FindFirstChild("XENON_FlyBV")
        if bg then bg:Destroy() end
        local av = flyState.root:FindFirstChild("XENON_FlyAV")
        if av then av:Destroy() end
        local hum = flyState.root.Parent and flyState.root.Parent:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
    end
    flyState.root = nil
end

local function startFly()
    stopFly()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then State.flyEnabled = false; return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = true end

    local bv = Instance.new("BodyVelocity")
    bv.Name = "XENON_FlyBV"
    bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bv.Velocity = Vector3.zero
    bv.Parent = root
    local av = Instance.new("BodyAngularVelocity")
    av.Name = "XENON_FlyAV"
    av.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    av.AngularVelocity = Vector3.zero
    av.Parent = root

    flyState.active = true
    flyState.root = root

    flyState.conn = RunService.RenderStepped:Connect(function(dt)
        if not flyState.active or not flyState.root or not flyState.root.Parent then
            stopFly(); return
        end
        local camLook  = Camera.CFrame.LookVector
        local camRight = Camera.CFrame.RightVector
        local camUp    = Vector3.new(0,1,0)

        local input = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then input += camLook  end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then input -= camLook  end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then input += camRight end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then input -= camRight end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space)       then input += camUp end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then input -= camUp end

        local desired = input.Magnitude > 0
            and input.Unit * State.flySpeed
            or Vector3.zero
        -- Smooth accel/decel — frame-rate independent
        local alpha = math.clamp(dt * 8, 0, 1)
        flyState.velocity = flyState.velocity:Lerp(desired, alpha)
        bv.Velocity = flyState.velocity
        av.AngularVelocity = Vector3.zero
    end)
end

_G.__XENON_LOOPS[#_G.__XENON_LOOPS+1] = LocalPlayer.CharacterAdded:Connect(function()
    if State.flyEnabled then task.delay(0.2, startFly) end
end)
_G.__XENON_LOOPS[#_G.__XENON_LOOPS+1] = LocalPlayer.CharacterRemoving:Connect(function()
    stopFly()
end)

-- ============================================================
-- 17. ESP
-- ============================================================
local function destroyESP(char)
    local t = State.espTrackers[char]
    if not t then return end
    pcall(function() if t.billboard then t.billboard:Destroy() end end)
    pcall(function() if t.highlight then t.highlight:Destroy() end end)
    State.espTrackers[char] = nil
end
local function processChar(char, plr)
    local root = getRoot(char)
    local head = char:FindFirstChild("Head")
    if not root or not head then return end
    if not State.espTrackers[char] then State.espTrackers[char] = {} end
    local tr = State.espTrackers[char]
    local color = State.espColor
    if State.espTeamColors and plr and plr.Team then color = plr.Team.TeamColor.Color end

    if State.espHighlights and not tr.highlight then
        local h = Instance.new("Highlight")
        h.FillColor = color; h.OutlineColor = color
        h.FillTransparency = 0.75
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Parent = char
        tr.highlight = h
    elseif not State.espHighlights and tr.highlight then
        tr.highlight:Destroy(); tr.highlight = nil
    end

    if not tr.billboard then
        local bb = Instance.new("BillboardGui")
        bb.Name = "XENON_ESP_BB"
        bb.Size = UDim2.new(0,120,0,50)
        bb.StudsOffset = Vector3.new(0,2.5,0)
        bb.AlwaysOnTop = true
        bb.Parent = head
        tr.billboard = bb
    end
    local bb = tr.billboard; bb.Enabled = true
    for _, c in ipairs(bb:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    local y = 0
    local function addLine(text, c)
        new("TextLabel",{Size=UDim2.new(1,0,0,12), Position=UDim2.new(0,0,0,y),
            BackgroundTransparency=1, Text=text, TextColor3=c, Font=FONT_BOLD,
            TextSize=State.espTextSize, TextStrokeTransparency=0.5, Parent=bb})
        y += 12
    end
    if State.espNames then addLine(char.Name, Color3.new(1,1,1)) end
    if State.espHealth then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then addLine(string.format("HP %d", math.floor(hum.Health)), Theme.Error) end
    end
    if State.espDistance then
        local myPos = getLocalPosition()
        if myPos then addLine(string.format("%dm", math.floor((root.Position-myPos).Magnitude)), Color3.new(1,1,1)) end
    end
end
local function updateESP()
    for char in pairs(State.espTrackers) do
        if not char or not char.Parent or not isAlive(char) then destroyESP(char) end
    end
    if not State.espEnabled then
        for char in pairs(State.espTrackers) do destroyESP(char) end
        return
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isAlive(plr.Character) then
            if not (State.teamCheck and plr.Team and LocalPlayer.Team
                    and plr.Team == LocalPlayer.Team and not isFFA(plr)) then
                processChar(plr.Character, plr)
            end
        end
    end
    if State.espNPCs then
        for _, model in ipairs(Workspace:GetChildren()) do
            if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid")
               and not Players:GetPlayerFromCharacter(model) and isAlive(model) then
                processChar(model, nil)
            end
        end
    end
end

-- ============================================================
-- 18. DASHBOARD
-- ============================================================
local dash = pages.dashboard
sectionTitle(dash, "OVERVIEW", 1)
local dashCard = card(dash, 2)
local dashPlayer  = label(dashCard, "—", Theme.Text, true, 1)
local dashDisplay = label(dashCard, "—", Theme.TextDim, false, 2)
local dashHealth  = label(dashCard, "HP —", Theme.Text, false, 3)
local dashWeapon  = label(dashCard, "Weapon —", Theme.Text, false, 4)
local dashTarget  = label(dashCard, "Target —", Theme.TextDim, false, 5)

sectionTitle(dash, "ACTIVE FEATURES", 3)
local activeCard = card(dash, 4)
local activeList = label(activeCard, "None", Theme.Text, false, 1)

sectionTitle(dash, "SYSTEM", 5)
local sysCard = card(dash, 6)
local sysLine1 = label(sysCard,
    "Combat: "..(HAS_COMBAT and "linked" or "missing"),
    HAS_COMBAT and Theme.Success or Theme.Warning, false, 1)
local sysLine2 = label(sysCard,
    "Knife: "..(HAS_KNIFE and "linked" or "missing"),
    HAS_KNIFE and Theme.Success or Theme.Warning, false, 2)
local sysUptime = label(sysCard, "Uptime —", Theme.TextDim, false, 3)

-- ============================================================
-- 19. COMBAT
-- ============================================================
local combat = pages.combat
sectionTitle(combat, "TARGETING", 1)
local combatCard = card(combat, 2)
toggle(combatCard, "Auto-Kill", 1,
    function() return State.autoKill end,
    function(v)
        State.autoKill = v
        if not v then State.closestTarget = nil end
    end,
    function(v)
        if v and not HAS_COMBAT then
            Notify("Combat", "Framework not detected.", "warning")
        end
    end)
numberInput(combatCard, "Max Distance", 2,
    function() return State.maxTargetDist end,
    function(v) State.maxTargetDist = math.clamp(v, 10, 5000) end)
dropdown(combatCard, "Priority", 3,
    {"Closest", "Crosshair", "Threat", "Farthest"},
    function() return State.targetPriority end,
    function(v)
        State.targetPriority = v
        State.closestTarget = nil  -- force re-pick under new priority
    end)
toggle(combatCard, "Target NPCs", 4,
    function() return State.targetNPCs end,
    function(v) State.targetNPCs = v; State.closestTarget = nil end)
toggle(combatCard, "Team Check", 5,
    function() return State.teamCheck end,
    function(v) State.teamCheck = v; State.closestTarget = nil end)

sectionTitle(combat, "STATUS", 3)
local combatStatus = card(combat, 4)
local combatTargetLbl   = label(combatStatus, "Target —", Theme.Text, false, 1)
local combatWeaponLbl   = label(combatStatus, "Weapon —", Theme.Text, false, 2)
local combatCooldownLbl = label(combatStatus, "Cooldown —", Theme.TextDim, false, 3)
local combatLosLbl      = label(combatStatus, "LOS —", Theme.TextDim, false, 4)
toggle(combatStatus, "LOS Test (once/sec)", 5,
    function() return State.losTest end,
    function(v) State.losTest = v end)

sectionTitle(combat, "NOTES", 5)
local combatNote = card(combat, 6)
label(combatNote,
    "Lowest HP is not offered: MVSD targets are effectively one-shot, so current "..
    "Humanoid.Health cannot meaningfully distinguish them. Use Threat (visibility + "..
    "proximity) or Crosshair instead.", Theme.TextDim, false, 1)
label(combatNote,
    "Damage is validated by the server. This panel never fakes hit results.",
    Theme.Warning, false, 2)

-- ============================================================
-- 20. VISUALS
-- ============================================================
local visuals = pages.visuals
sectionTitle(visuals, "ESP", 1)
local espCard = card(visuals, 2)
toggle(espCard, "ESP Enabled", 1, function() return State.espEnabled end,
    function(v) State.espEnabled = v end)
toggle(espCard, "Names", 2, function() return State.espNames end,
    function(v) State.espNames = v end)
toggle(espCard, "Health", 3, function() return State.espHealth end,
    function(v) State.espHealth = v end)
toggle(espCard, "Distance", 4, function() return State.espDistance end,
    function(v) State.espDistance = v end)
toggle(espCard, "Highlights", 5, function() return State.espHighlights end,
    function(v) State.espHighlights = v end)
toggle(espCard, "NPCs", 6, function() return State.espNPCs end,
    function(v) State.espNPCs = v end)
toggle(espCard, "Team Colors", 7, function() return State.espTeamColors end,
    function(v) State.espTeamColors = v end)
numberInput(espCard, "Text Size", 8,
    function() return State.espTextSize end,
    function(v) State.espTextSize = math.clamp(v, 8, 22) end)
button(espCard, "Clear ESP", 9, function()
    for _, tr in pairs(State.espTrackers) do
        if tr.billboard then tr.billboard:Destroy() end
        if tr.highlight then tr.highlight:Destroy() end
    end
    State.espTrackers = {}
    Notify("Visuals", "ESP cleared.", "success")
end)

-- ============================================================
-- 21. MOVEMENT (NoClip removed)
-- ============================================================
local movement = pages.movement
sectionTitle(movement, "SPEED", 1)
local moveCard = card(movement, 2)
toggle(moveCard, "Speed Override", 1,
    function() return State.speedEnabled end,
    function(v) State.speedEnabled = v; applyMovement() end)
numberInput(moveCard, "Walk Speed", 2,
    function() return State.speedValue end,
    function(v) State.speedValue = math.clamp(v, 0, 500); applyMovement() end)

sectionTitle(movement, "JUMP", 3)
local jumpCard = card(movement, 4)
toggle(jumpCard, "Jump Override", 1,
    function() return State.jumpEnabled end,
    function(v) State.jumpEnabled = v; applyMovement() end)
numberInput(jumpCard, "Jump Power", 2,
    function() return State.jumpValue end,
    function(v) State.jumpValue = math.clamp(v, 0, 500); applyMovement() end)

sectionTitle(movement, "FLY", 5)
local flyCard = card(movement, 6)
toggle(flyCard, "Fly", 1,
    function() return State.flyEnabled end,
    function(v)
        State.flyEnabled = v
        if v then startFly() else stopFly() end
    end)
numberInput(flyCard, "Fly Speed", 2,
    function() return State.flySpeed end,
    function(v) State.flySpeed = math.clamp(v, 5, 400) end)

sectionTitle(movement, "ACTIONS", 7)
local actionCard = card(movement, 8)
button(actionCard, "Reset Character", 1, function()
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.Health = 0 end
end)

-- ============================================================
-- 22. WEAPONS
-- ============================================================
local weapons = pages.weapons
sectionTitle(weapons, "EQUIPPED", 1)
local wCard = card(weapons, 2)
local wName     = label(wCard, "Name —", Theme.Text, true, 1)
local wKind     = label(wCard, "Kind —", Theme.TextDim, false, 2)
local wCooldown = label(wCard, "Cooldown —", Theme.TextDim, false, 3)
local wBullet   = label(wCard, "Bullet —", Theme.TextDim, false, 4)
local wMuzzle   = label(wCard, "Muzzle —", Theme.TextDim, false, 5)
local wStatus   = label(wCard, "Status —", Theme.TextDim, false, 6)

sectionTitle(weapons, "ACTIONS", 3)
local wActions = card(weapons, 4)
button(wActions, "Fire Once", 1, function()
    if not HAS_COMBAT then return end
    local target = State.closestTarget or findClosestTarget()
    local root = target and getRoot(target)
    if root then fireGunAt(root.Position) end
end)
button(wActions, "Stab Once", 2, function()
    if not HAS_KNIFE or State.currentToolKind ~= "knife" then return end
    local target = State.closestTarget or findClosestTarget()
    local root = target and getRoot(target)
    if root then tryStabTarget(root) end
end)
button(wActions, "Throw Once", 3, function()
    if not HAS_KNIFE or State.currentToolKind ~= "knife" then return end
    local target = State.closestTarget or findClosestTarget()
    local root = target and getRoot(target)
    if root then throwKnifeAt(root.Position) end
end)

-- ============================================================
-- 23. PLAYER
-- ============================================================
local playerPage = pages.player
sectionTitle(playerPage, "CHARACTER", 1)
local pCard = card(playerPage, 2)
local pHealth = label(pCard, "Health —", Theme.Text, false, 1)
local pPos    = label(pCard, "Position —", Theme.TextDim, false, 2)
local pTeam   = label(pCard, "Team —", Theme.TextDim, false, 3)
local pModel  = label(pCard, "Model —", Theme.TextDim, false, 4)
button(pCard, "Respawn", 5, function()
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.Health = 0 end
end)

-- ============================================================
-- 24. SETTINGS
-- ============================================================
local settings = pages.settings
sectionTitle(settings, "APPEARANCE", 1)
local setCard = card(settings, 2)
numberInput(setCard, "Scale (0.5–1.5)", 1,
    function() return State.scale end,
    function(v)
        State.scale = math.clamp(v, 0.5, 1.5)
        Main.Size = UDim2.new(0, BASE_W*State.scale, 0, BASE_H*State.scale)
    end)
numberInput(setCard, "Transparency (0–0.9)", 2,
    function() return State.transparency end,
    function(v)
        State.transparency = math.clamp(v, 0, 0.9)
        Main.BackgroundTransparency = State.transparency
    end)
numberInput(setCard, "Animation Speed", 3,
    function() return State.animationSpeed end,
    function(v) State.animationSpeed = math.clamp(v, 0.25, 3) end)

label(setCard, "Accent", Theme.Text, true, 4)
local swatchRow = new("Frame",{Size=UDim2.new(1,0,0,22), BackgroundTransparency=1,
    LayoutOrder=5, Parent=setCard})
new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0,4), Parent=swatchRow})
for _, c in ipairs({
    Color3.fromRGB(220,25,35), Color3.fromRGB(60,180,240), Color3.fromRGB(90,220,120),
    Color3.fromRGB(240,170,60), Color3.fromRGB(200,100,240), Color3.fromRGB(255,255,255)})
do
    local b = new("TextButton",{Size=UDim2.new(0,20,0,20), BackgroundColor3=c, Text="",
        AutoButtonColor=false, Parent=swatchRow})
    corner(b, 4); stroke(b, Theme.Border, 1, 0.5)
    b.MouseButton1Click:Connect(function()
        setAccent(c); Notify("Settings", "Accent updated.", "success", 2)
    end)
end

sectionTitle(settings, "BEHAVIOR", 3)
local behCard = card(settings, 4)
toggle(behCard, "Notifications", 1,
    function() return State.notificationsOn end,
    function(v) State.notificationsOn = v end)
toggle(behCard, "Performance Mode", 2,
    function() return State.performanceMode end,
    function(v) State.performanceMode = v; State.animationSpeed = v and 2 or 1 end)

local keyBtn = button(behCard, "Toggle Key: "..State.toggleKey.Name, 3, function()
    keyBtn.Text = "Press any key…"
    local conn
    conn = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            State.toggleKey = input.KeyCode
            keyBtn.Text = "Toggle Key: "..input.KeyCode.Name
            conn:Disconnect()
        end
    end)
end)

button(behCard, "Reset Settings", 4, function()
    State.scale, State.transparency, State.animationSpeed = 1, 0, 1
    State.notificationsOn, State.performanceMode = true, false
    setAccent(Color3.fromRGB(220,25,35))
    Main.Size = UDim2.new(0, BASE_W, 0, BASE_H)
    Main.BackgroundTransparency = 0
    Notify("Settings", "Reset complete.", "success")
end)

-- ============================================================
-- 25. ABOUT
-- ============================================================
local info = pages.info
sectionTitle(info, "XENON", 1)
local infoCard = card(info, 2)
label(infoCard, "XENON Control Panel · "..State.version, Theme.Accent, true, 1)
label(infoCard, "Client-side developer toolkit.", Theme.TextDim, false, 2)
label(infoCard, "Combat: "..(HAS_COMBAT and "framework linked" or "framework missing"),
    HAS_COMBAT and Theme.Success or Theme.Warning, false, 3)
label(infoCard, "Knife: "..(HAS_KNIFE and "framework linked" or "framework missing"),
    HAS_KNIFE and Theme.Success or Theme.Warning, false, 4)
label(infoCard,
    "All combat routes through the real remotes. The server validates every hit. "..
    "No feature here bypasses server authority.",
    Theme.TextDim, false, 5)

-- ============================================================
-- 26. OPEN / CLOSE
-- ============================================================
local function openPanel()
    Main.Visible = true
    Main.Size = UDim2.new(0, 0, 0, 0)
    Main.Position = UDim2.new(0.5, 0, 0.5, 0)
    tween(Main, {
        Size = UDim2.new(0, BASE_W*State.scale, 0, BASE_H*State.scale),
        Position = UDim2.new(0.5, -(BASE_W*State.scale)/2, 0.5, -(BASE_H*State.scale)/2),
    }, 0.3)
end
local function closePanel()
    tween(Main, {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
    }, 0.26)
    task.delay(0.3, function()
        if Main and Main.Parent then
            Main.Visible = false
            -- Stop stateful features when panel closes; but keep ESP/fly running
            -- if the user has them on and panel is closed? The spec says "Do not
            -- allow the fly controller to keep running after the GUI is closed."
            if State.flyEnabled then
                State.flyEnabled = false
                stopFly()
            end
        end
    end)
end
minBtn.MouseButton1Click:Connect(function()
    -- toggle between full and top-bar only
    local targetSize = Main.Size.Y.Offset > 40
        and UDim2.new(0, BASE_W*State.scale, 0, 36)
        or  UDim2.new(0, BASE_W*State.scale, 0, BASE_H*State.scale)
    tween(Main, { Size = targetSize }, 0.22)
end)
closeBtn.MouseButton1Click:Connect(closePanel)
_G.__XENON_LOOPS[#_G.__XENON_LOOPS+1] = UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == State.toggleKey then
        if not Main.Visible then openPanel() else closePanel() end
    end
end)
openPanel(); switchTab("dashboard")

-- ============================================================
-- 27. MAIN LOOP
-- ============================================================
local uiAccum  = 0
local espAccum = 0
local losAccum = 0

_G.__XENON_LOOPS[#_G.__XENON_LOOPS+1] = RunService.Heartbeat:Connect(function(dt)
    -- Aura loop: stable target re-eval each frame but fire gated by cooldown
    if State.autoKill then
        reevaluateTarget()
        if State.closestTarget then
            local root = getRoot(State.closestTarget)
            if root then
                if State.currentToolKind == "gun" then
                    fireGunAt(root.Position)
                elseif State.currentToolKind == "knife" then
                    local myPos = getLocalPosition()
                    local d = myPos and (root.Position - myPos).Magnitude or math.huge
                    if d < 6 then tryStabTarget(root) else throwKnifeAt(root.Position) end
                end
            end
        end
    end

    -- ESP throttled (2 Hz, or 0.5 Hz in performance mode)
    espAccum += dt
    local espInterval = State.performanceMode and 2 or 0.5
    if espAccum >= espInterval then
        espAccum = 0
        if State.espEnabled then updateESP() end
    end

    -- LOS test (1 Hz)
    if State.losTest and State.closestTarget then
        losAccum += dt
        if losAccum >= 1 then
            losAccum = 0
            local origin = CharacterRayOrigin and CharacterRayOrigin(LocalPlayer.Character)
            local targetRoot = getRoot(State.closestTarget)
            if origin and targetRoot and WeaponRaycast then
                local hit = WeaponRaycast(origin, targetRoot.Position)
                if hit then
                    combatLosLbl.Text = "LOS clear"
                    combatLosLbl.TextColor3 = Theme.Success
                else
                    combatLosLbl.Text = "LOS blocked"
                    combatLosLbl.TextColor3 = Theme.Warning
                end
            end
        end
    else
        losAccum = 0
        combatLosLbl.Text = "LOS —"
        combatLosLbl.TextColor3 = Theme.TextDim
    end

    -- UI (2 Hz)
    uiAccum += dt
    if uiAccum < 0.5 then return end
    uiAccum = 0

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")

    dashPlayer.Text  = LocalPlayer.Name
    dashDisplay.Text = "@"..LocalPlayer.DisplayName
    dashHealth.Text  = hum and string.format("HP %d / %d", math.floor(hum.Health), math.floor(hum.MaxHealth)) or "HP —"
    dashWeapon.Text  = "Weapon "..(State.currentTool and State.currentTool.Name or "—")
    dashTarget.Text  = "Target "..(State.closestTarget and State.closestTarget.Name or "—")

    local active = {}
    if State.autoKill then table.insert(active, "Auto-Kill") end
    if State.espEnabled then table.insert(active, "ESP") end
    if State.speedEnabled then table.insert(active, "Speed") end
    if State.jumpEnabled then table.insert(active, "Jump") end
    if State.flyEnabled then table.insert(active, "Fly") end
    activeList.Text = #active > 0 and table.concat(active, " · ") or "None"

    local up = math.floor(tick() - State.sessionStart)
    sysUptime.Text = string.format("Uptime %02dh %02dm %02ds",
        math.floor(up/3600), math.floor((up%3600)/60), up%60)

    combatTargetLbl.Text = "Target — "..(State.closestTarget and State.closestTarget.Name or "—")
    combatWeaponLbl.Text = "Weapon — "..(State.currentTool and
        (State.currentTool.Name.." ("..(State.currentToolKind or "?")..")") or "—")
    combatCooldownLbl.Text = State.currentTool
        and string.format("Cooldown %.2fs", State.currentTool:GetAttribute("Cooldown") or 0)
        or "Cooldown —"

    wName.Text     = "Name — "..(State.currentTool and State.currentTool.Name or "—")
    wKind.Text     = "Kind — "..(State.currentToolKind or "—")
    wCooldown.Text = "Cooldown — "..(State.currentTool
        and tostring(State.currentTool:GetAttribute("Cooldown") or 0) or "—")
    wBullet.Text   = "Bullet — "..(State.currentTool
        and tostring(State.currentTool:GetAttribute("BulletType") or "—") or "—")
    local muzzle = State.currentTool and State.currentTool:FindFirstChild("Muzzle", true)
    wMuzzle.Text   = "Muzzle — "..(muzzle and muzzle.Name or "—")
    wStatus.Text   = "Status — "..(State.currentTool
        and (State.currentTool.Enabled and "Enabled" or "Disabled") or "—")

    pHealth.Text = "Health — "..(hum
        and string.format("%d / %d", math.floor(hum.Health), math.floor(hum.MaxHealth)) or "—")
    pPos.Text    = "Position — "..(root
        and string.format("%.0f, %.0f, %.0f", root.Position.X, root.Position.Y, root.Position.Z) or "—")
    pTeam.Text   = "Team — "..(LocalPlayer.Team and LocalPlayer.Team.Name or "None")
    pModel.Text  = "Model — "..(char and char.Name or "—")
end)

-- ============================================================
-- 28. CLEANUP
-- ============================================================
_G.__XENON_LOOPS[#_G.__XENON_LOOPS+1] = LocalPlayer.OnTeleport:Connect(function()
    stopFly()
    for _, c in ipairs(_G.__XENON_LOOPS) do pcall(function() c:Disconnect() end) end
    _G.__XENON_LOOPS = {}
    pcall(function() if Screen then Screen:Destroy() end end)
    pcall(function() if notifGui then notifGui:Destroy() end end)
end)

Notify("XENON", "Panel loaded — "..State.toggleKey.Name.." to toggle.", "success", 3)
