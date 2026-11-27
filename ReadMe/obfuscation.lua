--[[
    Xenon Hub — Rewritten + Clean GUI
    Original: "MADE BY GUARDIAN, XENON RUNS YOU"
    Rewrite: dedup, bug fixes, perf, safety, UX, clean animated UI
]]

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local VirtualUser       = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Mouse       = LocalPlayer:GetMouse()
local Camera      = Workspace.CurrentCamera

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------
local Config = {
    -- Murderer
    KillAura         = false,
    KillAuraRange    = 15,
    TeleportKillAll  = false,
    -- Sheriff
    AutoShootMurderer = false,
    AimAssist        = false,
    AimSmoothness    = 0.2,
    AutoGrabGun      = false,
    -- ESP
    PlayerESP        = false,
    RoleESP          = false,
    GunESP           = false,
    -- Movement
    SpeedBoost       = false,
    WalkSpeedValue   = 24,
    NoClip           = false,
    -- Misc
    AntiAFK          = true,
    -- Coin teleport
    CoinFarm         = false,
    CoinTeleportDelay = 0.4,
    CoinKeyword      = "coin",
    CoinHeightOffset = 0,
}

-- Red + black palette. All lettering stays white.
local Theme = {
    Background   = Color3.fromRGB(8, 8, 8),
    TopBar       = Color3.fromRGB(12, 6, 6),
    Sidebar      = Color3.fromRGB(10, 10, 10),
    Panel        = Color3.fromRGB(32, 8, 8),
    PanelHover   = Color3.fromRGB(52, 10, 10),
    Accent       = Color3.fromRGB(255, 40, 45),
    AccentBright = Color3.fromRGB(255, 95, 95),
    Text         = Color3.fromRGB(255, 255, 255),
    TextMuted    = Color3.fromRGB(225, 225, 225),
    Stroke       = Color3.fromRGB(150, 25, 25),
    Track        = Color3.fromRGB(26, 10, 10),
    ToggleOff    = Color3.fromRGB(26, 10, 10),
    Danger       = Color3.fromRGB(255, 40, 45),
    Success      = Color3.fromRGB(255, 40, 45),
}

------------------------------------------------------------
-- STATE
------------------------------------------------------------
local State = {
    Connections     = {},
    Highlights      = {},
    ESPTags         = {},
    RoleCache       = {},
    RoleCacheTime   = {},
    OriginalWalk    = nil,
    OriginalCollide = {},
    LastKnifeAct    = 0,
    LastShotAct     = 0,
    NoclipActive    = false,
    RoundActive     = false,
    CoinIndex       = 0,
    CoinLastTeleport = 0,
    Unloaded        = false,
}

local ROLE_CACHE_TTL = 1.0
local KNIFE_COOLDOWN  = 0.15
local SHOT_COOLDOWN   = 0.3

local function track(conn)
    table.insert(State.Connections, conn)
    return conn
end

------------------------------------------------------------
-- MM2 HELPERS
------------------------------------------------------------
local function GetPlayerRole(player)
    if not player or not player.Character then
        return "Innocent"
    end
    local now = tick()
    if State.RoleCache[player] and (now - (State.RoleCacheTime[player] or 0)) < ROLE_CACHE_TTL then
        return State.RoleCache[player]
    end
    local char     = player.Character
    local backpack = player:FindFirstChild("Backpack")
    local role     = "Innocent"
    if char:FindFirstChild("Knife") or (backpack and backpack:FindFirstChild("Knife")) then
        role = "Murderer"
    elseif char:FindFirstChild("Gun") or (backpack and backpack:FindFirstChild("Gun")) then
        role = "Sheriff"
    end
    State.RoleCache[player]     = role
    State.RoleCacheTime[player] = now
    return role
end

local function GetRoleColor(role)
    if role == "Murderer" then return Color3.fromRGB(255, 65, 84) end
    if role == "Sheriff"  then return Color3.fromRGB(0, 150, 255) end
    return Color3.fromRGB(46, 204, 113)
end

local function GetMurderer()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and GetPlayerRole(p) == "Murderer" then
            return p
        end
    end
    return nil
end

local function GetDroppedGun()
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj.Name == "GunDrop" or (obj:IsA("Tool") and obj.Name == "Gun") then
            local handle = obj:IsA("BasePart") and obj or obj:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                return handle
            end
        end
    end
    return nil
end

local function GetCoinVisualFrames()
    local frames = {}
    local keyword = tostring(Config.CoinKeyword or "coin"):lower()
    if keyword == "" then return frames end

    for _, obj in ipairs(Workspace:GetDescendants()) do
        local hit = obj.Name:lower():find(keyword, 1, true) ~= nil
        local ancestor = obj.Parent
        for _ = 1, 4 do
            if not ancestor then break end
            if ancestor.Name:lower():find(keyword, 1, true) then
                hit = true
                break
            end
            ancestor = ancestor.Parent
        end
        if hit then
            local cf = nil
            if obj:IsA("BasePart") then
                cf = obj.CFrame
            elseif obj:IsA("Model") then
                local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
                if part then cf = part.CFrame end
            end
            if cf then table.insert(frames, cf) end
        end
    end
    return frames
end

local function GetClosestTargetForAim()
    local myRole = GetPlayerRole(LocalPlayer)
    local closest, shortest = nil, math.huge
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local targetRole = GetPlayerRole(p)
            local shouldTarget = (myRole == "Sheriff") and (targetRole == "Murderer")
                              or (myRole ~= "Sheriff") and (targetRole ~= "Innocent")
            if shouldTarget then
                local pos, onScreen = Camera:WorldToViewportPoint(p.Character.HumanoidRootPart.Position)
                if onScreen then
                    local d = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                    if d < shortest then
                        shortest, closest = d, p
                    end
                end
            end
        end
    end
    return closest
end

local function safeActivate(tool)
    if not tool then return false end
    return pcall(function() tool:Activate() end)
end

local function safeTouch(partA, partB)
    if not partA or not partB then return end
    pcall(function() firetouchinterest(partA, partB, 0) end)
    pcall(function() firetouchinterest(partA, partB, 1) end)
end

------------------------------------------------------------
-- NOCLIP
------------------------------------------------------------
local function SetNoclip(enabled)
    local char = LocalPlayer.Character
    if not char then return end
    if enabled then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                State.OriginalCollide[part] = true
                part.CanCollide = false
            end
        end
    else
        for part in pairs(State.OriginalCollide) do
            if part and part.Parent then
                pcall(function() part.CanCollide = true end)
            end
        end
        State.OriginalCollide = {}
    end
    State.NoclipActive = enabled
end

------------------------------------------------------------
-- ROUND AWARENESS
------------------------------------------------------------
local function RefreshRoundState()
    State.RoleCache = {}
    State.RoleCacheTime = {}
end

track(Workspace.ChildAdded:Connect(function(obj)
    if obj.Name == "Game" or obj.Name == "Map" or obj:IsA("Model") then
        RefreshRoundState()
    end
end))

track(LocalPlayer.CharacterAdded:Connect(function()
    State.OriginalWalk = nil
    State.OriginalCollide = {}
    RefreshRoundState()
end))

------------------------------------------------------------
-- COMBAT ENGINE
------------------------------------------------------------
track(RunService.Stepped:Connect(function()
    if State.Unloaded then return end
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not (root and humanoid) then return end

    -- Speed Boost
    if Config.SpeedBoost then
        if not State.OriginalWalk then State.OriginalWalk = humanoid.WalkSpeed end
        humanoid.WalkSpeed = Config.WalkSpeedValue
    elseif State.OriginalWalk then
        humanoid.WalkSpeed = State.OriginalWalk
        State.OriginalWalk = nil
    end

    -- Noclip
    if (Config.NoClip or Config.TeleportKillAll) ~= State.NoclipActive then
        SetNoclip(Config.NoClip or Config.TeleportKillAll)
    end

    -- Auto Grab Gun
    if Config.AutoGrabGun then
        local gun = GetDroppedGun()
        if gun then root.CFrame = gun.CFrame end
    end

    -- Teleport Kill All
    if Config.TeleportKillAll and GetPlayerRole(LocalPlayer) == "Murderer" then
        local knife = char:FindFirstChild("Knife")
            or (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Knife"))
        if knife then
            if knife.Parent ~= char then knife.Parent = char end
            for _, target in ipairs(Players:GetPlayers()) do
                if target ~= LocalPlayer and target.Character then
                    local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
                    local tHum  = target.Character:FindFirstChildOfClass("Humanoid")
                    if tRoot and tHum and tHum.Health > 0 then
                        root.CFrame = tRoot.CFrame * CFrame.new(0, 0, 1.5)
                        safeActivate(knife)
                        safeTouch(knife:FindFirstChild("Handle"), tRoot)
                        task.wait(0.08)
                    end
                end
            end
        end
    end

    -- Knife Kill Aura
    if Config.KillAura and not Config.TeleportKillAll
       and GetPlayerRole(LocalPlayer) == "Murderer" then
        local now = tick()
        if now - State.LastKnifeAct >= KNIFE_COOLDOWN then
            local knife = char:FindFirstChild("Knife")
                or (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Knife"))
            if knife then
                if knife.Parent ~= char then knife.Parent = char end
                local knifeHandle = knife:FindFirstChild("Handle")
                local touched = false
                for _, target in ipairs(Players:GetPlayers()) do
                    if target ~= LocalPlayer and target.Character then
                        local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
                        if tRoot and (root.Position - tRoot.Position).Magnitude <= Config.KillAuraRange then
                            safeActivate(knife)
                            safeTouch(knifeHandle, tRoot)
                            touched = true
                        end
                    end
                end
                if touched then State.LastKnifeAct = now end
            end
        end
    end

    -- Auto Shoot Murderer
    if Config.AutoShootMurderer and GetPlayerRole(LocalPlayer) == "Sheriff" then
        local murderer = GetMurderer()
        if murderer and murderer.Character then
            local mRoot = murderer.Character:FindFirstChild("HumanoidRootPart")
            local mHum  = murderer.Character:FindFirstChildOfClass("Humanoid")
            if mRoot and mHum and mHum.Health > 0 then
                local gun = char:FindFirstChild("Gun")
                    or (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Gun"))
                    or char:FindFirstChildOfClass("Tool")
                if gun and (gun.Name == "Gun" or gun:FindFirstChild("GunScript")) then
                    if gun.Parent ~= char then gun.Parent = char end
                    if not Config.AimAssist then
                        Camera.CFrame = CFrame.new(Camera.CFrame.Position, mRoot.Position)
                    end
                    local now = tick()
                    if now - State.LastShotAct >= SHOT_COOLDOWN then
                        safeActivate(gun)
                        State.LastShotAct = now
                    end
                end
            end
        end
    end
end))

------------------------------------------------------------
-- AIM ASSIST
------------------------------------------------------------
track(RunService.RenderStepped:Connect(function(dt)
    if State.Unloaded then return end
    if not Config.AimAssist then return end
    if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
    local target = GetClosestTargetForAim()
    if target and target.Character then
        local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
        if tRoot then
            local current = Camera.CFrame
            local desired = CFrame.new(current.Position, tRoot.Position)
            Camera.CFrame = current:Lerp(desired, math.clamp(Config.AimSmoothness, 0, 1))
        end
    end
end))

------------------------------------------------------------
-- ANTI-AFK
------------------------------------------------------------
track(LocalPlayer.Idled:Connect(function()
    if State.Unloaded then return end
    if Config.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end))

------------------------------------------------------------
-- COIN TELEPORT (loops through every coin visual while enabled)
------------------------------------------------------------
track(RunService.Stepped:Connect(function()
    if State.Unloaded or not Config.CoinFarm then return end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local now = tick()
    if now - State.CoinLastTeleport < Config.CoinTeleportDelay then return end

    local frames = GetCoinVisualFrames()
    if #frames == 0 then return end

    State.CoinIndex = State.CoinIndex % #frames + 1
    root.CFrame = frames[State.CoinIndex] + Vector3.new(0, Config.CoinHeightOffset, 0)
    State.CoinLastTeleport = now
end))

------------------------------------------------------------
-- ESP RENDER
------------------------------------------------------------
track(RunService.RenderStepped:Connect(function()
    if State.Unloaded then return end
    local wantPlayerESP = Config.PlayerESP or Config.RoleESP

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local existing = State.Highlights[player]
            if wantPlayerESP and char and char:FindFirstChild("HumanoidRootPart") then
                local color = GetRoleColor(GetPlayerRole(player))
                if not existing or existing.Parent ~= char then
                    if existing then pcall(function() existing:Destroy() end) end
                    local hl = Instance.new("Highlight")
                    hl.Name = "XenonESP"
                    hl.FillTransparency = 0.6
                    hl.OutlineTransparency = 0.1
                    hl.Parent = char
                    State.Highlights[player] = hl
                    existing = hl
                end
                existing.FillColor    = color
                existing.OutlineColor = color
            elseif existing then
                if existing.Parent then pcall(function() existing:Destroy() end) end
                State.Highlights[player] = nil
            end
        end
    end

    local gun = GetDroppedGun()
    if gun and Config.GunESP then
        local tag = State.ESPTags["DroppedGun"]
        if not tag or tag.Parent ~= gun then
            if tag then pcall(function() tag:Destroy() end) end
            local bb = Instance.new("BillboardGui")
            bb.Name = "XenonGunESP"
            bb.Size = UDim2.fromOffset(120, 30)
            bb.StudsOffset = Vector3.new(0, 3, 0)
            bb.AlwaysOnTop = true
            local txt = Instance.new("TextLabel")
            txt.Size = UDim2.fromScale(1, 1)
            txt.BackgroundTransparency = 1
            txt.TextColor3 = Color3.fromRGB(255, 40, 45)
            txt.Font = Enum.Font.GothamBold
            txt.TextSize = 12
            txt.Text = "DROPPED GUN"
            txt.Parent = bb
            bb.Parent = gun
            State.ESPTags["DroppedGun"] = bb
        end
    elseif State.ESPTags["DroppedGun"] then
        pcall(function() State.ESPTags["DroppedGun"]:Destroy() end)
        State.ESPTags["DroppedGun"] = nil
    end
end))

------------------------------------------------------------
-- UI ROOT
------------------------------------------------------------
local GUI = Instance.new("ScreenGui")
GUI.Name = "Xenon"
GUI.ResetOnSpawn = false
GUI.IgnoreGuiInset = true
GUI.DisplayOrder = 10
GUI.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MAIN_W, MAIN_H, COLLAPSED_H = 540, 380, 52

local Main = Instance.new("Frame")
Main.Name = "Xenon Hub"
Main.Size = UDim2.fromOffset(MAIN_W, MAIN_H)
Main.Position = UDim2.new(0.5, -MAIN_W / 2, 0.5, -MAIN_H / 2)
Main.BackgroundColor3 = Theme.Background
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = GUI
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 14)

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Theme.Stroke
MainStroke.Thickness = 1
MainStroke.Transparency = 0.25
MainStroke.Parent = Main

-- Small helpers used by every control
local function Corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
    return c
end

local function Stroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.Parent = parent
    return s
end

local function Tween(obj, duration, props, style, direction)
    return TweenService:Create(
        obj,
        TweenInfo.new(duration, style or Enum.EasingStyle.Quart,
                      direction or Enum.EasingDirection.Out),
        props
    ):Play()
end

------------------------------------------------------------
-- SUBTLE ANIMATED ACCENT BORDER
------------------------------------------------------------
local BorderFrame = Instance.new("Frame")
BorderFrame.Name = "AccentBorder"
BorderFrame.Size = UDim2.fromScale(1, 1)
BorderFrame.BackgroundTransparency = 1
BorderFrame.BorderSizePixel = 0
BorderFrame.ZIndex = 20
BorderFrame.Parent = Main
Corner(BorderFrame, 14)

local BorderStroke = Instance.new("UIStroke")
BorderStroke.Thickness = 1.6
BorderStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
BorderStroke.Parent = BorderFrame

local BorderGradient = Instance.new("UIGradient")
BorderGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0.00, Theme.Accent),
    ColorSequenceKeypoint.new(0.50, Theme.AccentBright),
    ColorSequenceKeypoint.new(1.00, Theme.Accent),
}
BorderGradient.Transparency = NumberSequence.new{
    NumberSequenceKeypoint.new(0.00, 1.00),
    NumberSequenceKeypoint.new(0.24, 0.80),
    NumberSequenceKeypoint.new(0.50, 0.00),
    NumberSequenceKeypoint.new(0.76, 0.80),
    NumberSequenceKeypoint.new(1.00, 1.00),
}
BorderGradient.Parent = BorderStroke

task.spawn(function()
    while not State.Unloaded do
        local from = BorderGradient.Rotation
        local tween = TweenService:Create(
            BorderGradient,
            TweenInfo.new(4.5, Enum.EasingStyle.Linear),
            { Rotation = from + 360 }
        )
        tween:Play()
        tween.Completed:Wait()
        task.wait(0.15)
    end
end)

------------------------------------------------------------
-- TOP BAR
------------------------------------------------------------
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 52)
TopBar.BackgroundColor3 = Theme.TopBar
TopBar.BorderSizePixel = 0
TopBar.ZIndex = 2
TopBar.Parent = Main

local TopLine = Instance.new("Frame")
TopLine.Size = UDim2.new(1, 0, 0, 1)
TopLine.Position = UDim2.new(0, 0, 1, 0)
TopLine.BackgroundColor3 = Theme.Accent
TopLine.BackgroundTransparency = 0.35
TopLine.BorderSizePixel = 0
TopLine.ZIndex = 3
TopLine.Parent = TopBar
local TopLineGrad = Instance.new("UIGradient")
TopLineGrad.Transparency = NumberSequence.new{
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.5, 0),
    NumberSequenceKeypoint.new(1, 1),
}
TopLineGrad.Parent = TopLine

local Logo = Instance.new("Frame")
Logo.Size = UDim2.fromOffset(30, 30)
Logo.Position = UDim2.fromOffset(14, 11)
Logo.BackgroundColor3 = Theme.Accent
Logo.BorderSizePixel = 0
Logo.ZIndex = 3
Logo.Parent = TopBar
Corner(Logo, 8)
local LogoGrad = Instance.new("UIGradient")
LogoGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Theme.AccentBright),
    ColorSequenceKeypoint.new(1, Theme.Accent),
}
LogoGrad.Rotation = 45
LogoGrad.Parent = Logo

local LogoText = Instance.new("TextLabel")
LogoText.Size = UDim2.fromScale(1, 1)
LogoText.BackgroundTransparency = 1
LogoText.Text = "X"
LogoText.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoText.Font = Enum.Font.GothamBlack
LogoText.TextSize = 17
LogoText.ZIndex = 4
LogoText.Parent = Logo

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0, 230, 0, 20)
Title.Position = UDim2.fromOffset(54, 9)
Title.BackgroundTransparency = 1
Title.Text = "XENON HUB"
Title.TextColor3 = Theme.Text
Title.TextSize = 15
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 3
Title.Parent = TopBar

local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(0, 230, 0, 14)
Subtitle.Position = UDim2.fromOffset(55, 28)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "CONTROL PANEL  //  v2.0"
Subtitle.TextColor3 = Theme.TextMuted
Subtitle.TextSize = 9
Subtitle.Font = Enum.Font.GothamMedium
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.ZIndex = 3
Subtitle.Parent = TopBar

local StatusPill = Instance.new("Frame")
StatusPill.Size = UDim2.fromOffset(78, 22)
StatusPill.Position = UDim2.new(1, -152, 0.5, -11)
StatusPill.BackgroundColor3 = Theme.Panel
StatusPill.BorderSizePixel = 0
StatusPill.ZIndex = 3
StatusPill.Parent = TopBar
Corner(StatusPill, 11)
Stroke(StatusPill, Theme.Stroke, 1, 0.4)

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.fromOffset(6, 6)
StatusDot.Position = UDim2.fromOffset(11, 8)
StatusDot.BackgroundColor3 = Theme.Success
StatusDot.BorderSizePixel = 0
StatusDot.ZIndex = 4
StatusDot.Parent = StatusPill
Corner(StatusDot, 3)

local StatusText = Instance.new("TextLabel")
StatusText.Size = UDim2.new(1, -22, 1, 0)
StatusText.Position = UDim2.fromOffset(20, 0)
StatusText.BackgroundTransparency = 1
StatusText.Text = "READY"
StatusText.TextColor3 = Theme.TextMuted
StatusText.TextSize = 9
StatusText.Font = Enum.Font.GothamBold
StatusText.ZIndex = 4
StatusText.Parent = StatusPill

local Controls = Instance.new("Frame")
Controls.Size = UDim2.fromOffset(54, 24)
Controls.Position = UDim2.new(1, -66, 0.5, -12)
Controls.BackgroundTransparency = 1
Controls.ZIndex = 3
Controls.Parent = TopBar
local ControlsLayout = Instance.new("UIListLayout")
ControlsLayout.FillDirection = Enum.FillDirection.Horizontal
ControlsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
ControlsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
ControlsLayout.Padding = UDim.new(0, 6)
ControlsLayout.Parent = Controls

local function MakeControlButton(text, normal, hovered)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(24, 24)
    btn.BackgroundColor3 = normal
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Theme.TextMuted
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.ZIndex = 4
    btn.Parent = Controls
    Corner(btn, 7)
    btn.MouseEnter:Connect(function()
        Tween(btn, 0.15, { BackgroundColor3 = hovered, TextColor3 = Theme.Text })
    end)
    btn.MouseLeave:Connect(function()
        Tween(btn, 0.15, { BackgroundColor3 = normal, TextColor3 = Theme.TextMuted })
    end)
    return btn
end

local MinBtn   = MakeControlButton("-", Theme.Panel, Theme.PanelHover)
local CloseBtn = MakeControlButton("✕", Theme.Panel, Theme.Danger)

------------------------------------------------------------
-- SIDEBAR
------------------------------------------------------------
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 132, 1, -52)
Sidebar.Position = UDim2.fromOffset(0, 52)
Sidebar.BackgroundColor3 = Theme.Sidebar
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 2
Sidebar.Parent = Main

local SidebarDivider = Instance.new("Frame")
SidebarDivider.Size = UDim2.new(0, 1, 1, -52)
SidebarDivider.Position = UDim2.fromOffset(131, 52)
SidebarDivider.BackgroundColor3 = Theme.Stroke
SidebarDivider.BackgroundTransparency = 0.35
SidebarDivider.BorderSizePixel = 0
SidebarDivider.ZIndex = 3
SidebarDivider.Parent = Main

local SidebarLabel = Instance.new("TextLabel")
SidebarLabel.Size = UDim2.new(1, 0, 0, 18)
SidebarLabel.BackgroundTransparency = 1
SidebarLabel.Text = "CATEGORIES"
SidebarLabel.TextColor3 = Theme.TextMuted
SidebarLabel.TextSize = 9
SidebarLabel.Font = Enum.Font.GothamBold
SidebarLabel.TextXAlignment = Enum.TextXAlignment.Center
SidebarLabel.ZIndex = 3
SidebarLabel.Parent = Sidebar

local SidebarList = Instance.new("UIListLayout")
SidebarList.Padding = UDim.new(0, 4)
SidebarList.HorizontalAlignment = Enum.HorizontalAlignment.Center
SidebarList.Parent = Sidebar

local SidebarPadding = Instance.new("UIPadding")
SidebarPadding.PaddingTop = UDim.new(0, 12)
SidebarPadding.PaddingLeft = UDim.new(0, 8)
SidebarPadding.PaddingRight = UDim.new(0, 8)
SidebarPadding.Parent = Sidebar

------------------------------------------------------------
-- TAB CONTAINER + FOOTER
------------------------------------------------------------
local TabContainer = Instance.new("Frame")
TabContainer.Name = "TabContainer"
TabContainer.Size = UDim2.new(1, -156, 1, -88)
TabContainer.Position = UDim2.fromOffset(144, 64)
TabContainer.BackgroundTransparency = 1
TabContainer.ZIndex = 2
TabContainer.Parent = Main

local Footer = Instance.new("Frame")
Footer.Size = UDim2.new(1, -156, 0, 16)
Footer.Position = UDim2.fromOffset(144, 360)
Footer.BackgroundTransparency = 1
Footer.ZIndex = 2
Footer.Parent = Main

local FooterHint = Instance.new("TextLabel")
FooterHint.Size = UDim2.new(0.5, 0, 1, 0)
FooterHint.BackgroundTransparency = 1
FooterHint.Text = "RIGHT SHIFT  •  SHOW / HIDE"
FooterHint.TextColor3 = Theme.TextMuted
FooterHint.TextSize = 9
FooterHint.Font = Enum.Font.GothamMedium
FooterHint.TextXAlignment = Enum.TextXAlignment.Left
FooterHint.ZIndex = 3
FooterHint.Parent = Footer

local FooterBrand = Instance.new("TextLabel")
FooterBrand.Size = UDim2.new(0.5, 0, 1, 0)
FooterBrand.Position = UDim2.new(0.5, 0, 0, 0)
FooterBrand.BackgroundTransparency = 1
FooterBrand.Text = "XENON  //  READY"
FooterBrand.TextColor3 = Theme.TextMuted
FooterBrand.TextSize = 9
FooterBrand.Font = Enum.Font.GothamMedium
FooterBrand.TextXAlignment = Enum.TextXAlignment.Right
FooterBrand.ZIndex = 3
FooterBrand.Parent = Footer

------------------------------------------------------------
-- COLLAPSE / CLOSE / UNLOAD
------------------------------------------------------------
local IsCollapsed = false

local function SetCollapsed(collapsed)
    IsCollapsed = collapsed
    Tween(Main, 0.28, {
        Size = UDim2.fromOffset(MAIN_W, collapsed and COLLAPSED_H or MAIN_H)
    }, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)

    MinBtn.Text = collapsed and "+" or "-"

    if collapsed then
        Sidebar.Visible = false
        SidebarDivider.Visible = false
        TabContainer.Visible = false
        Footer.Visible = false
    else
        task.delay(0.14, function()
            if State.Unloaded or IsCollapsed then return end
            Sidebar.Visible = true
            SidebarDivider.Visible = true
            TabContainer.Visible = true
            Footer.Visible = true
        end)
    end
end

MinBtn.MouseButton1Click:Connect(function()
    SetCollapsed(not IsCollapsed)
end)

local function Unload()
    if State.Unloaded then return end
    State.Unloaded = true

    if State.NoclipActive then SetNoclip(false) end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and State.OriginalWalk then hum.WalkSpeed = State.OriginalWalk end

    for _, hl in pairs(State.Highlights) do pcall(function() hl:Destroy() end) end
    for _, esp in pairs(State.ESPTags) do pcall(function() esp:Destroy() end) end
    for _, conn in ipairs(State.Connections) do pcall(function() conn:Disconnect() end) end
    pcall(function() GUI:Destroy() end)
end

CloseBtn.MouseButton1Click:Connect(Unload)
_G.XenonUnload = Unload

------------------------------------------------------------
-- TAB ENGINE
------------------------------------------------------------
local Tabs       = {}
local TabButtons = {}
local TabBars    = {}

local function SelectTab(index)
    for i, tab in ipairs(Tabs) do
        tab.Visible = (i == index)
    end
    for i, btn in ipairs(TabButtons) do
        local active = (i == index)
        TabBars[i].Visible = active
        Tween(btn, 0.18, {
            BackgroundTransparency = active and 0.65 or 1,
            TextColor3 = active and Theme.Text or Theme.TextMuted,
        }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    end
end

local function CreateTab(Name)
    local TabFrame = Instance.new("ScrollingFrame")
    TabFrame.Size = UDim2.new(1, 0, 1, 0)
    TabFrame.BackgroundTransparency = 1
    TabFrame.BorderSizePixel = 0
    TabFrame.ScrollBarThickness = 3
    TabFrame.ScrollBarImageColor3 = Theme.Accent
    TabFrame.ScrollBarImageTransparency = 0.4
    TabFrame.CanvasSize = UDim2.fromOffset(0, 0)
    TabFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    TabFrame.VerticalScrollBarInset = Enum.ScrollBarInset.None
    TabFrame.Visible = false
    TabFrame.ZIndex = 2
    TabFrame.Parent = TabContainer

    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0, 8)
    Layout.Parent = TabFrame

    local TabPadding = Instance.new("UIPadding")
    TabPadding.PaddingTop = UDim.new(0, 2)
    TabPadding.PaddingRight = UDim.new(0, 6)
    TabPadding.PaddingBottom = UDim.new(0, 6)
    TabPadding.Parent = TabFrame

    local TabBtn = Instance.new("TextButton")
    TabBtn.Size = UDim2.new(1, 0, 0, 34)
    TabBtn.BackgroundColor3 = Theme.Panel
    TabBtn.BackgroundTransparency = 1
    TabBtn.Text = Name
    TabBtn.TextColor3 = Theme.TextMuted
    TabBtn.Font = Enum.Font.GothamMedium
    TabBtn.TextSize = 12
    TabBtn.TextXAlignment = Enum.TextXAlignment.Left
    TabBtn.ZIndex = 3
    TabBtn.Parent = Sidebar
    Corner(TabBtn, 8)

    local BtnPadding = Instance.new("UIPadding")
    BtnPadding.PaddingLeft = UDim.new(0, 14)
    BtnPadding.Parent = TabBtn

    local ActiveBar = Instance.new("Frame")
    ActiveBar.Size = UDim2.fromOffset(3, 18)
    ActiveBar.Position = UDim2.fromOffset(0, 8)
    ActiveBar.BackgroundColor3 = Theme.Accent
    ActiveBar.BorderSizePixel = 0
    ActiveBar.Visible = false
    ActiveBar.ZIndex = 4
    ActiveBar.Parent = TabBtn
    Corner(ActiveBar, 2)

    TabBtn.MouseEnter:Connect(function()
        Tween(TabBtn, 0.15, { BackgroundTransparency = 0.55 })
        if not ActiveBar.Visible then
            Tween(TabBtn, 0.15, { TextColor3 = Theme.Text })
        end
    end)
    TabBtn.MouseLeave:Connect(function()
        local active = ActiveBar.Visible
        Tween(TabBtn, 0.15, {
            BackgroundTransparency = active and 0.65 or 1,
            TextColor3 = active and Theme.Text or Theme.TextMuted,
        })
    end)

    local myIndex = #Tabs + 1
    TabBtn.MouseButton1Click:Connect(function()
        SelectTab(myIndex)
    end)

    table.insert(Tabs, TabFrame)
    table.insert(TabButtons, TabBtn)
    table.insert(TabBars, ActiveBar)
    return TabFrame
end

local MurdererTab = CreateTab("Murderer")
local SheriffTab  = CreateTab("Sheriff")
local ESPTab      = CreateTab("Visuals / ESP")
local MovementTab = CreateTab("Movement")

SelectTab(1)

------------------------------------------------------------
-- CONTROLS
------------------------------------------------------------
local function AddToggle(Parent, Name, Default, Callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, -4, 0, 44)
    Row.BackgroundColor3 = Theme.Panel
    Row.BorderSizePixel = 0
    Row.ZIndex = 2
    Row.Parent = Parent
    Corner(Row, 10)
    Stroke(Row, Theme.Stroke, 1, 0.4)

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -86, 1, 0)
    Label.Position = UDim2.fromOffset(14, 0)
    Label.BackgroundTransparency = 1
    Label.Text = Name
    Label.TextColor3 = Theme.Text
    Label.TextSize = 13
    Label.Font = Enum.Font.GothamMedium
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.ZIndex = 3
    Label.Parent = Row

    local Switch = Instance.new("Frame")
    Switch.Size = UDim2.fromOffset(40, 22)
    Switch.Position = UDim2.new(1, -54, 0.5, -11)
    Switch.BackgroundColor3 = Default and Theme.Accent or Theme.ToggleOff
    Switch.BorderSizePixel = 0
    Switch.ZIndex = 3
    Switch.Parent = Row
    Corner(Switch, 11)

    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.fromOffset(16, 16)
    Knob.Position = Default and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3)
    Knob.BackgroundColor3 = Default and Color3.fromRGB(8, 8, 8) or Theme.Accent
    Knob.BorderSizePixel = 0
    Knob.ZIndex = 4
    Knob.Parent = Switch
    Corner(Knob, 8)

    local ClickArea = Instance.new("TextButton")
    ClickArea.Size = UDim2.fromScale(1, 1)
    ClickArea.BackgroundTransparency = 1
    ClickArea.Text = ""
    ClickArea.ZIndex = 5
    ClickArea.Parent = Row

    ClickArea.MouseEnter:Connect(function()
        Tween(Row, 0.15, { BackgroundColor3 = Theme.PanelHover })
    end)
    ClickArea.MouseLeave:Connect(function()
        Tween(Row, 0.15, { BackgroundColor3 = Theme.Panel })
    end)

    local on = Default
    ClickArea.MouseButton1Click:Connect(function()
        on = not on
        Tween(Switch, 0.2, {
            BackgroundColor3 = on and Theme.Accent or Theme.ToggleOff,
        })
        Tween(Knob, 0.2, {
            Position = on and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3),
            BackgroundColor3 = on and Color3.fromRGB(8, 8, 8) or Theme.Accent,
        })
        Callback(on)
    end)
end

local SliderState = { active = nil }

track(UserInputService.InputChanged:Connect(function(input)
    if SliderState.active and input.UserInputType == Enum.UserInputType.MouseMovement then
        SliderState.active(input)
    end
end))

track(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        SliderState.active = nil
    end
end))

local function AddSlider(Parent, Name, Min, Max, Default, Callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, -4, 0, 58)
    Row.BackgroundColor3 = Theme.Panel
    Row.BorderSizePixel = 0
    Row.ZIndex = 2
    Row.Parent = Parent
    Corner(Row, 10)
    Stroke(Row, Theme.Stroke, 1, 0.4)

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -82, 0, 18)
    Label.Position = UDim2.fromOffset(14, 6)
    Label.BackgroundTransparency = 1
    Label.Text = Name
    Label.TextColor3 = Theme.Text
    Label.TextSize = 13
    Label.Font = Enum.Font.GothamMedium
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.ZIndex = 3
    Label.Parent = Row

    local ValuePill = Instance.new("Frame")
    ValuePill.Size = UDim2.fromOffset(48, 22)
    ValuePill.Position = UDim2.new(1, -60, 0, 5)
    ValuePill.BackgroundColor3 = Theme.Track
    ValuePill.BorderSizePixel = 0
    ValuePill.ZIndex = 3
    ValuePill.Parent = Row
    Corner(ValuePill, 6)
    Stroke(ValuePill, Theme.Accent, 1, 0.5)

    local ValueLabel = Instance.new("TextLabel")
    ValueLabel.Size = UDim2.fromScale(1, 1)
    ValueLabel.BackgroundTransparency = 1
    ValueLabel.Text = tostring(Default)
    ValueLabel.TextColor3 = Theme.Text
    ValueLabel.TextSize = 12
    ValueLabel.Font = Enum.Font.GothamBold
    ValueLabel.ZIndex = 4
    ValueLabel.Parent = ValuePill

    local Track = Instance.new("Frame")
    Track.Size = UDim2.new(1, -28, 0, 5)
    Track.Position = UDim2.fromOffset(14, 36)
    Track.BackgroundColor3 = Theme.Track
    Track.BorderSizePixel = 0
    Track.ZIndex = 3
    Track.Parent = Row
    Corner(Track, 3)

    local startScale = math.clamp((Default - Min) / (Max - Min), 0, 1)

    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new(startScale, 0, 1, 0)
    Fill.BackgroundColor3 = Theme.Accent
    Fill.BorderSizePixel = 0
    Fill.ZIndex = 4
    Fill.Parent = Track
    Corner(Fill, 3)

    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.fromOffset(12, 12)
    Knob.Position = UDim2.new(startScale, -6, 0, 32)
    Knob.BackgroundColor3 = Theme.AccentBright
    Knob.BorderSizePixel = 0
    Knob.ZIndex = 5
    Knob.Parent = Row
    Corner(Knob, 6)

    local function Update(input)
        local scale = math.clamp(
            (input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1
        )
        local val = math.clamp(math.floor(Min + (Max - Min) * scale + 0.5), Min, Max)
        Fill.Size = UDim2.new(scale, 0, 1, 0)
        Knob.Position = UDim2.new(scale, -6, 0, 32)
        ValueLabel.Text = tostring(val)
        Callback(val)
    end

    Track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            SliderState.active = Update
            Update(input)
        end
    end)
end

------------------------------------------------------------
-- POPULATE CONTROLS
------------------------------------------------------------
AddToggle(MurdererTab, "Teleport Kill All", Config.TeleportKillAll, function(v) Config.TeleportKillAll = v end)
AddToggle(MurdererTab, "Knife Kill Aura", Config.KillAura, function(v) Config.KillAura = v end)
AddSlider(MurdererTab, "Kill Aura Range", 5, 30, Config.KillAuraRange, function(v) Config.KillAuraRange = v end)

AddToggle(SheriffTab, "Auto Shoot Murderer", Config.AutoShootMurderer, function(v) Config.AutoShootMurderer = v end)
AddToggle(SheriffTab, "Gun Aim Assist (Hold RMB)", Config.AimAssist, function(v) Config.AimAssist = v end)
AddSlider(SheriffTab, "Aim Smoothness %", 1, 100, Config.AimSmoothness * 100, function(v) Config.AimSmoothness = v / 100 end)
AddToggle(SheriffTab, "Auto Grab Dropped Gun", Config.AutoGrabGun, function(v) Config.AutoGrabGun = v end)

AddToggle(ESPTab, "Role ESP (Murderer/Sheriff)", Config.RoleESP, function(v) Config.RoleESP = v end)
AddToggle(ESPTab, "Player ESP", Config.PlayerESP, function(v) Config.PlayerESP = v end)
AddToggle(ESPTab, "Dropped Gun ESP", Config.GunESP, function(v) Config.GunESP = v end)

AddToggle(MovementTab, "Speed Boost", Config.SpeedBoost, function(v) Config.SpeedBoost = v end)
AddSlider(MovementTab, "Walk Speed", 16, 60, Config.WalkSpeedValue, function(v) Config.WalkSpeedValue = v end)
AddToggle(MovementTab, "Noclip", Config.NoClip, function(v) Config.NoClip = v end)
AddToggle(MovementTab, "Coin Teleport (Loop All)", Config.CoinFarm, function(v) Config.CoinFarm = v end)
AddSlider(MovementTab, "Coin TP Delay (x0.1s)", 2, 30, Config.CoinTeleportDelay * 10, function(v) Config.CoinTeleportDelay = v / 10 end)

------------------------------------------------------------
-- DRAGGING & KEYBIND
------------------------------------------------------------
local Dragging, DragStart, StartPos

track(TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        Dragging = true
        DragStart = input.Position
        StartPos = Main.Position
    end
end))

track(UserInputService.InputChanged:Connect(function(input)
    if Dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - DragStart
        local vp = Camera.ViewportSize
        -- keep the title bar reachable so the GUI can never be lost off-screen
        local newX = math.clamp(StartPos.X.Offset + delta.X, -MAIN_W + 120, vp.X - 120)
        local newY = math.clamp(StartPos.Y.Offset + delta.Y, 0, vp.Y - COLLAPSED_H)
        Main.Position = UDim2.new(StartPos.X.Scale, newX, StartPos.Y.Scale, newY)
    end
end))

track(TopBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        Dragging = false
    end
end))

track(UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.RightShift then
        Main.Visible = not Main.Visible
    end
end))
