--[[
    Xenon Hub — Rewritten + Animated Pulse Border
    Original: "MADE BY GUARDIAN, XENON RUNS YOU"
    Rewrite: dedup, bug fixes, perf, safety, UX, animated UI
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
}

local Theme = {
    Background   = Color3.fromRGB(128, 128, 128),
    CardBg       = Color3.fromRGB(140, 30, 30),
    TopBarBg     = Color3.fromRGB(0, 0, 0),
    SidebarBg    = Color3.fromRGB(128, 128, 128),
    Accent       = Color3.fromRGB(220, 180, 100),
    TextBright   = Color3.fromRGB(220, 50, 50),
    TextMuted    = Color3.fromRGB(220, 50, 50),
    Border       = Color3.fromRGB(0, 0, 0),
    ToggleOff    = Color3.fromRGB(30, 34, 45),
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
            txt.TextColor3 = Color3.fromRGB(255, 215, 0)
            txt.Font = Enum.Font.GothamBold
            txt.TextSize = 12
            txt.Text = "🔫 DROPPED GUN"
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
GUI.Parent = LocalPlayer:WaitForChild("PlayerGui")

local Main = Instance.new("Frame")
Main.Name = "Xenon Hub"
Main.Size = UDim2.fromOffset(520, 360)
Main.Position = UDim2.new(0.5, -260, 0.5, -180)
Main.BackgroundColor3 = Theme.Background
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = GUI
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Theme.Border
MainStroke.Thickness = 1.2
MainStroke.Parent = Main

------------------------------------------------------------
-- ANIMATED PULSE BORDER
------------------------------------------------------------
local PulseFrame = Instance.new("Frame")
PulseFrame.Name = "PulseBorder"
PulseFrame.Size = UDim2.new(1, 0, 1, 0)
PulseFrame.Position = UDim2.new(0, 0, 0, 0)
PulseFrame.BackgroundTransparency = 1
PulseFrame.BorderSizePixel = 0
PulseFrame.ZIndex = 10
PulseFrame.Parent = Main
Instance.new("UICorner", PulseFrame).CornerRadius = UDim.new(0, 12)

local PulseStroke = Instance.new("UIStroke")
PulseStroke.Thickness = 2
PulseStroke.Color = Color3.fromRGB(255, 255, 255)
PulseStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
PulseStroke.Transparency = 0
PulseStroke.Parent = PulseFrame

local PulseGradient = Instance.new("UIGradient")
PulseGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0.00, Theme.Accent),
    ColorSequenceKeypoint.new(0.50, Color3.fromRGB(255, 255, 255)),
    ColorSequenceKeypoint.new(1.00, Theme.Accent),
}
PulseGradient.Transparency = NumberSequence.new{
    NumberSequenceKeypoint.new(0.00, 1.00),
    NumberSequenceKeypoint.new(0.35, 1.00),
    NumberSequenceKeypoint.new(0.48, 0.10),
    NumberSequenceKeypoint.new(0.50, 0.00),
    NumberSequenceKeypoint.new(0.52, 0.10),
    NumberSequenceKeypoint.new(0.65, 1.00),
    NumberSequenceKeypoint.new(1.00, 1.00),
}
PulseGradient.Rotation = 0
PulseGradient.Parent = PulseStroke

task.spawn(function()
    while not State.Unloaded do
        local tween = TweenService:Create(
            PulseGradient,
            TweenInfo.new(2.4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
            { Rotation = PulseGradient.Rotation + 360 }
        )
        tween:Play()
        tween.Completed:Wait()
        task.wait(0.35)
    end
end)

------------------------------------------------------------
-- INNER GLOW PULSE
------------------------------------------------------------
local GlowFrame = Instance.new("Frame")
GlowFrame.Name = "GlowHalo"
GlowFrame.Size = UDim2.new(1, 10, 1, 10)
GlowFrame.Position = UDim2.new(0, -5, 0, -5)
GlowFrame.BackgroundColor3 = Theme.Accent
GlowFrame.BackgroundTransparency = 1
GlowFrame.BorderSizePixel = 0
GlowFrame.ZIndex = -1
GlowFrame.Parent = Main
Instance.new("UICorner", GlowFrame).CornerRadius = UDim.new(0, 16)

local GlowStroke = Instance.new("UIStroke")
GlowStroke.Color = Theme.Accent
GlowStroke.Thickness = 6
GlowStroke.Transparency = 0.85
GlowStroke.Parent = GlowFrame

task.spawn(function()
    while not State.Unloaded do
        TweenService:Create(
            GlowStroke,
            TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            { Transparency = 0.55, Thickness = 10 }
        ):Play()
        task.wait(1.6)
        TweenService:Create(
            GlowStroke,
            TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            { Transparency = 0.90, Thickness = 6 }
        ):Play()
        task.wait(1.6)
    end
end)

------------------------------------------------------------
-- TOP BAR
------------------------------------------------------------
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 48)
TopBar.BackgroundColor3 = Theme.TopBarBg
TopBar.BorderSizePixel = 0
TopBar.ZIndex = 2
TopBar.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0, 250, 1, 0)
Title.Position = UDim2.fromOffset(18, 0)
Title.BackgroundTransparency = 1
Title.Text = "Xenon"
Title.TextColor3 = Theme.TextBright
Title.TextSize = 15
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 2
Title.Parent = TopBar

local TopControlContainer = Instance.new("Frame")
TopControlContainer.Size = UDim2.new(0, 70, 1, 0)
TopControlContainer.Position = UDim2.new(1, -78, 0, 0)
TopControlContainer.BackgroundTransparency = 1
TopControlContainer.ZIndex = 2
TopControlContainer.Parent = TopBar
local TopControlLayout = Instance.new("UIListLayout")
TopControlLayout.FillDirection = Enum.FillDirection.Horizontal
TopControlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
TopControlLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TopControlLayout.Padding = UDim.new(0, 6)
TopControlLayout.Parent = TopControlContainer

local CollapseBtn = Instance.new("TextButton")
CollapseBtn.Size = UDim2.fromOffset(26, 26)
CollapseBtn.BackgroundColor3 = Theme.CardBg
CollapseBtn.Text = "-"
CollapseBtn.TextColor3 = Theme.TextBright
CollapseBtn.Font = Enum.Font.GothamBold
CollapseBtn.TextSize = 14
CollapseBtn.ZIndex = 3
CollapseBtn.Parent = TopControlContainer
Instance.new("UICorner", CollapseBtn).CornerRadius = UDim.new(0, 6)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.fromOffset(26, 26)
CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 65, 84)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 11
CloseBtn.ZIndex = 3
CloseBtn.Parent = TopControlContainer
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

------------------------------------------------------------
-- SIDEBAR
------------------------------------------------------------
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 130, 1, -48)
Sidebar.Position = UDim2.fromOffset(0, 48)
Sidebar.BackgroundColor3 = Theme.SidebarBg
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 2
Sidebar.Parent = Main
local SidebarList = Instance.new("UIListLayout")
SidebarList.Padding = UDim.new(0, 6)
SidebarList.HorizontalAlignment = Enum.HorizontalAlignment.Center
SidebarList.Parent = Sidebar
local SidebarPadding = Instance.new("UIPadding")
SidebarPadding.PaddingTop = UDim.new(0, 12)
SidebarPadding.Parent = Sidebar

------------------------------------------------------------
-- TAB CONTAINER
------------------------------------------------------------
local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(1, -142, 1, -60)
TabContainer.Position = UDim2.fromOffset(136, 54)
TabContainer.BackgroundTransparency = 1
TabContainer.ZIndex = 2
TabContainer.Parent = Main

------------------------------------------------------------
-- COLLAPSE / CLOSE / UNLOAD
------------------------------------------------------------
local IsCollapsed = false

CollapseBtn.MouseButton1Click:Connect(function()
    IsCollapsed = not IsCollapsed
    if IsCollapsed then
        TweenService:Create(Main, TweenInfo.new(0.3, Enum.EasingStyle.Cubic), {
            Size = UDim2.fromOffset(520, 48)
        }):Play()
        Sidebar.Visible = false
        TabContainer.Visible = false
        CollapseBtn.Text = "+"
    else
        TweenService:Create(Main, TweenInfo.new(0.3, Enum.EasingStyle.Cubic), {
            Size = UDim2.fromOffset(520, 360)
        }):Play()
        task.delay(0.15, function()
            Sidebar.Visible = true
            TabContainer.Visible = true
        end)
        CollapseBtn.Text = "-"
    end
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
local Tabs = {}
local TabButtons = {}

local function CreateTab(Name)
    local TabFrame = Instance.new("ScrollingFrame")
    TabFrame.Size = UDim2.new(1, 0, 1, 0)
    TabFrame.BackgroundTransparency = 1
    TabFrame.BorderSizePixel = 0
    TabFrame.ScrollBarThickness = 2
    TabFrame.ScrollBarImageColor3 = Theme.Accent
    TabFrame.Visible = false
    TabFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    TabFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    TabFrame.ZIndex = 2
    TabFrame.Parent = TabContainer

    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0, 8)
    Layout.Parent = TabFrame

    local TabBtn = Instance.new("TextButton")
    TabBtn.Size = UDim2.new(1, -16, 0, 32)
    TabBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    TabBtn.BackgroundTransparency = 1
    TabBtn.Text = Name
    TabBtn.TextColor3 = Theme.TextMuted
    TabBtn.Font = Enum.Font.GothamMedium
    TabBtn.TextSize = 12
    TabBtn.ZIndex = 3
    TabBtn.Parent = Sidebar
    Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 6)

    TabBtn.MouseButton1Click:Connect(function()
        for _, t in pairs(Tabs) do t.Visible = false end
        for _, b in pairs(TabButtons) do
            TweenService:Create(b, TweenInfo.new(0.2), {
                BackgroundTransparency = 1, TextColor3 = Theme.TextMuted
            }):Play()
        end
        TabFrame.Visible = true
        TweenService:Create(TabBtn, TweenInfo.new(0.2), {
            BackgroundTransparency = 0.8, TextColor3 = Theme.Accent
        }):Play()
    end)

    table.insert(Tabs, TabFrame)
    table.insert(TabButtons, TabBtn)
    return TabFrame
end

local MurdererTab = CreateTab("Murderer")
local SheriffTab  = CreateTab("Sheriff")
local ESPTab      = CreateTab("Visuals / ESP")
local MovementTab = CreateTab("Movement")

Tabs[1].Visible = true
TabButtons[1].BackgroundTransparency = 0.8
TabButtons[1].TextColor3 = Theme.Accent

------------------------------------------------------------
-- CONTROLS
------------------------------------------------------------
local function AddToggle(Parent, Name, Default, Callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, -6, 0, 40)
    Row.BackgroundColor3 = Theme.CardBg
    Row.ZIndex = 2
    Row.Parent = Parent
    Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 8)
    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Theme.Border
    Stroke.Thickness = 1
    Stroke.Parent = Row

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -60, 1, 0)
    Label.Position = UDim2.fromOffset(12, 0)
    Label.BackgroundTransparency = 1
    Label.Text = Name
    Label.TextColor3 = Theme.TextBright
    Label.TextSize = 12
    Label.Font = Enum.Font.GothamMedium
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.ZIndex = 3
    Label.Parent = Row

    local ToggleBg = Instance.new("Frame")
    ToggleBg.Size = UDim2.fromOffset(36, 18)
    ToggleBg.Position = UDim2.new(1, -48, 0.5, -9)
    ToggleBg.BackgroundColor3 = Default and Theme.Accent or Theme.ToggleOff
    ToggleBg.ZIndex = 3
    ToggleBg.Parent = Row
    Instance.new("UICorner", ToggleBg).CornerRadius = UDim.new(1, 0)

    local Indicator = Instance.new("Frame")
    Indicator.Size = UDim2.fromOffset(14, 14)
    Indicator.Position = Default and UDim2.fromOffset(19, 2) or UDim2.fromOffset(3, 2)
    Indicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Indicator.ZIndex = 4
    Indicator.Parent = ToggleBg
    Instance.new("UICorner", Indicator).CornerRadius = UDim.new(1, 0)

    local ClickArea = Instance.new("TextButton")
    ClickArea.Size = UDim2.fromScale(1, 1)
    ClickArea.BackgroundTransparency = 1
    ClickArea.Text = ""
    ClickArea.ZIndex = 5
    ClickArea.Parent = Row

    local on = Default
    ClickArea.MouseButton1Click:Connect(function()
        on = not on
        TweenService:Create(ToggleBg, TweenInfo.new(0.2), {
            BackgroundColor3 = on and Theme.Accent or Theme.ToggleOff
        }):Play()
        TweenService:Create(Indicator, TweenInfo.new(0.2), {
            Position = on and UDim2.fromOffset(19, 2) or UDim2.fromOffset(3, 2)
        }):Play()
        Callback(on)
    end)
end

local SliderState = { active = nil }
UserInputService.InputChanged:Connect(function(input)
    if SliderState.active and input.UserInputType == Enum.UserInputType.MouseMovement then
        SliderState.active(input)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        SliderState.active = nil
    end
end)

local function AddSlider(Parent, Name, Min, Max, Default, Callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, -6, 0, 52)
    Row.BackgroundColor3 = Theme.CardBg
    Row.ZIndex = 2
    Row.Parent = Parent
    Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 8)
    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Theme.Border
    Stroke.Thickness = 1
    Stroke.Parent = Row

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -70, 0, 24)
    Label.Position = UDim2.fromOffset(12, 4)
    Label.BackgroundTransparency = 1
    Label.Text = Name
    Label.TextColor3 = Theme.TextBright
    Label.TextSize = 12
    Label.Font = Enum.Font.GothamMedium
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.ZIndex = 3
    Label.Parent = Row

    local ValueLabel = Instance.new("TextLabel")
    ValueLabel.Size = UDim2.new(0, 50, 0, 24)
    ValueLabel.Position = UDim2.new(1, -62, 0, 4)
    ValueLabel.BackgroundTransparency = 1
    ValueLabel.Text = tostring(Default)
    ValueLabel.TextColor3 = Theme.Accent
    ValueLabel.TextSize = 12
    ValueLabel.Font = Enum.Font.GothamBold
    ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
    ValueLabel.ZIndex = 3
    ValueLabel.Parent = Row

    local Track = Instance.new("Frame")
    Track.Size = UDim2.new(1, -24, 0, 4)
    Track.Position = UDim2.fromOffset(12, 34)
    Track.BackgroundColor3 = Theme.ToggleOff
    Track.ZIndex = 3
    Track.Parent = Row
    Instance.new("UICorner", Track).CornerRadius = UDim.new(1, 0)

    local Fill = Instance.new("Frame")
    local startScale = math.clamp((Default - Min) / (Max - Min), 0, 1)
    Fill.Size = UDim2.new(startScale, 0, 1, 0)
    Fill.BackgroundColor3 = Theme.Accent
    Fill.ZIndex = 4
    Fill.Parent = Track
    Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)

    local function Update(input)
        local scale = math.clamp(
            (input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1
        )
        local val = math.clamp(math.floor(Min + (Max - Min) * scale + 0.5), Min, Max)
        Fill.Size = UDim2.new(scale, 0, 1, 0)
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

------------------------------------------------------------
-- DRAGGING & KEYBIND
------------------------------------------------------------
local Dragging, DragStart, StartPos
TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        Dragging = true
        DragStart = input.Position
        StartPos = Main.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if Dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - DragStart
        -- clamp on-screen so it can't be lost
        local newX = StartPos.X.Offset + delta.X
        local newY = StartPos.Y.Offset + delta.Y
        local vp = Camera.ViewportSize
        newX = math.clamp(newX, -260, vp.X - 260)
        newY = math.clamp(newY, -180, vp.Y - 180)
        Main.Position = UDim2.new(StartPos.X.Scale, newX, StartPos.Y.Scale, newY)
    end
end)

TopBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then Dragging = false end
end)

track(UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.RightShift then
        Main.Visible = not Main.Visible
    end
end))
