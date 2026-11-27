--made by GUARDIAN
-- to open, right shift sweetie

if _G.__FlyAimHub then
    print("[FlyAim] already loaded")
    return
end
_G.__FlyAimHub = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local localPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ============================================================
-- CONFIG
-- ============================================================
local FLY_SPEED = 24
local AIM_SMOOTH = 0.15
local HBE_SIZE = 8
local AIM_FOV = 250
local FIRE_MULTIPLIER = 1.0

local cfg = {
    fly     = false,
    hbe     = false,
    aimlock = false, -- Internal state for aimlock (used in Toggle mode)
    esp     = false,
    aura    = false,
    killAll = false,
    fovRing = false,
    auraRequireGun = true,
    noclip  = false,
}

local AIM = { 
    part = "Head", 
    smooth = 0.15, 
    fov = 250,
    mode = "Toggle", -- Toggle, Hold
    keybind = Enum.KeyCode.E,
    holdActive = false,
}

local AURA = { radius = 60, interval = 0.12, useHead = true, requireGun = true, killAllInterval = 0.25 }

-- ============================================================
-- GUN CONFIG HOOK
-- ============================================================
local GunConfigs = nil
pcall(function()
    GunConfigs = require(ReplicatedStorage:WaitForChild("GunConfigs", 10))
end)

local ORIGINAL_COOLDOWNS = {}
local GUN_LIST = {
    "Glock", "Deagle", "Spaz", "AA12", "Revolver", "Sawed-Off", "Sniper",
    "Uzi", "Tec-9", "LMG", "AK47", "Tommy", "Assault Rifle", "Silencer",
    "Draco", "Firework Launcher",
}
local GUN_COOLDOWNS = {
    Glock = 0.03, Deagle = 0.05, Spaz = 0.03, AA12 = 0.01,
    Revolver = 0.03, ["Sawed-Off"] = 0.03, Sniper = 0.05,
    Uzi = 0.02, ["Tec-9"] = 0.02, LMG = 0.03, AK47 = 0.03,
    Tommy = 0.02, ["Assault Rifle"] = 0.03, Silencer = 0.03,
    Draco = 0.03, ["Firework Launcher"] = 0.15,
}

if GunConfigs then
    for name, _ in pairs(GunConfigs) do
        if type(GunConfigs[name]) == "table" and GunConfigs[name].CoolDown then
            ORIGINAL_COOLDOWNS[name] = GunConfigs[name].CoolDown
        end
    end
end

local function applyCooldown(gunName)
    if not GunConfigs or not GunConfigs[gunName] then return end
    local target = GUN_COOLDOWNS[gunName] or ORIGINAL_COOLDOWNS[gunName] or 0.1
    GunConfigs[gunName].CoolDown = target * FIRE_MULTIPLIER
end

local function applyAllCooldowns()
    if not GunConfigs then return end
    for name, _ in pairs(GUN_COOLDOWNS) do applyCooldown(name) end
end

applyAllCooldowns()

local WHITELIST = {}
local function isWhitelisted(plr) return WHITELIST[plr.UserId] == true end

local WeaponEvent = nil
task.spawn(function()
    pcall(function()
        local ev = ReplicatedStorage:WaitForChild("Events", 20)
        if ev then WeaponEvent = ev:WaitForChild("WeaponEvent", 20) end
    end)
end)

local function getEquippedGunName()
    local char = localPlayer.Character
    if not char then return nil end
    for _, c in ipairs(char:GetChildren()) do
        if c:IsA("Tool") and c.Name ~= "Knife" and c.Name ~= "Handcuffs" then
            return c.Name
        end
    end
    return nil
end
local function isHoldingGun() return getEquippedGunName() ~= nil end

local function getMyPos()
    local char = localPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position or nil
end

local function fireMagicAt(plr)
    if plr == localPlayer or isWhitelisted(plr) then return false end
    local char = plr.Character
    if not char then return false end
    local target = AURA.useHead and char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    if not target then return false end
    local gun = getEquippedGunName()
    if not gun then return false end
    if not WeaponEvent then return false end
    local args = { [1] = "Fire", [2] = { [1] = target.Position, [2] = target }, [3] = gun }
    pcall(function() WeaponEvent:FireServer(unpack(args)) end)
    return true
end

-- ============================================================
-- FLY
-- ============================================================
local flyConn
local function startFly()
    local char = localPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    flyConn = RunService.RenderStepped:Connect(function()
        if not cfg.fly then return end
        local c = localPlayer.Character
        if not c then return end
        local root = c:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local move = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0,1,0) end
        local newPos = root.Position + move * FLY_SPEED * (1/60)
        root.CFrame = CFrame.new(newPos, newPos + Camera.CFrame.LookVector)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function stopFly()
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    local char = localPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end
end

-- ============================================================
-- NOCLIP
-- ============================================================
local noclipConn
local function startNoclip()
    if noclipConn then return end
    noclipConn = RunService.Stepped:Connect(function()
        if not cfg.noclip then return end
        local char = localPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end

local function stopNoclip()
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
    local char = localPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

-- ============================================================
-- HBE
-- ============================================================
local hbeConn
local function applyHBE(plr)
    local char = plr.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if hrp:GetAttribute("_hbe_orig") then return end
    hrp:SetAttribute("_hbe_orig", hrp.Size)
    hrp.Size = Vector3.new(HBE_SIZE, HBE_SIZE, HBE_SIZE)
    hrp.Transparency = 0.6
    hrp.CanCollide = false
end
local function removeHBE(plr)
    local char = plr.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local orig = hrp:GetAttribute("_hbe_orig")
    if orig then
        hrp.Size = orig
        hrp.Transparency = 0
        hrp.CanCollide = true
        hrp:SetAttribute("_hbe_orig", nil)
    end
end
local function startHBE()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer then applyHBE(p) end
    end
    hbeConn = Players.PlayerAdded:Connect(function(p) task.wait(1); if cfg.hbe then applyHBE(p) end end)
    Players.PlayerRemoving:Connect(function(p) removeHBE(p) end)
end
local function stopHBE()
    if hbeConn then hbeConn:Disconnect(); hbeConn = nil end
    for _, p in ipairs(Players:GetPlayers()) do removeHBE(p) end
end

-- ============================================================
-- AIM LOCK
-- ============================================================
local aimConn
local function findAimTarget()
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local best, bestDist = nil, AIM.fov
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer and not isWhitelisted(p) then
            local char = p.Character
            if char then
                local part
                if AIM.part == "Head" then
                    part = char:FindFirstChild("Head")
                elseif AIM.part == "Torso" then
                    part = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
                else
                    for _, name in ipairs({"Head", "UpperTorso", "Torso", "HumanoidRootPart", "LowerTorso"}) do
                        local c = char:FindFirstChild(name)
                        if c then
                            local sp, on = Camera:WorldToViewportPoint(c.Position)
                            if on then
                                local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                                if d < bestDist then bestDist = d; best = c end
                            end
                        end
                    end
                    part = nil
                end
                if part then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
                        if onScreen then
                            local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                            if d < bestDist then bestDist = d; best = part end
                        end
                    end
                end
            end
        end
    end
    return best
end

local function startAim()
    if aimConn then return end
    aimConn = RunService.RenderStepped:Connect(function()
        local isActive = false
        if AIM.mode == "Toggle" then
            isActive = cfg.aimlock
        elseif AIM.mode == "Hold" then
            isActive = AIM.holdActive
        end

        if not isActive then return end

        local target = findAimTarget()
        if target then
            local goal = CFrame.new(Camera.CFrame.Position, target.Position)
            Camera.CFrame = Camera.CFrame:Lerp(goal, 1 - AIM.smooth)
        end
    end)
end
local function stopAim()
    if aimConn then aimConn:Disconnect(); aimConn = nil end
end

-- ============================================================
-- ESP
-- ============================================================
local espFolder = Instance.new("Folder")
espFolder.Name = "FlyAimESP"
espFolder.Parent = Workspace
local espTracked = {}
local espConns = {}

local function createESP(plr)
    if plr == localPlayer or espTracked[plr] then return end
    local hl = Instance.new("Highlight")
    hl.Name = "ESP_HL_" .. plr.UserId
    hl.FillColor = Color3.fromRGB(255, 60, 70)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.7
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Enabled = false
    hl.Parent = espFolder
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 220, 0, 28)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.Enabled = false
    billboard.Parent = espFolder
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.TextSize = 14
    label.Font = Enum.Font.Code
    label.Text = ""
    label.Parent = billboard
    espTracked[plr] = { hl = hl, billboard = billboard, label = label }
end

local function removeESP(plr)
    local d = espTracked[plr]
    if d then
        if d.hl then d.hl:Destroy() end
        if d.billboard then d.billboard:Destroy() end
        espTracked[plr] = nil
    end
end

local function startESP()
    for _, c in ipairs(espConns) do pcall(function() c:Disconnect() end) end
    espConns = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer then createESP(p) end
    end
    table.insert(espConns, Players.PlayerAdded:Connect(createESP))
    table.insert(espConns, Players.PlayerRemoving:Connect(removeESP))
    local lastUpdate = 0
    table.insert(espConns, RunService.Heartbeat:Connect(function()
        if not cfg.esp then
            for _, d in pairs(espTracked) do
                d.hl.Enabled = false
                d.billboard.Enabled = false
            end
            return
        end
        local now = tick()
        if now - lastUpdate < 0.05 then return end
        lastUpdate = now
        local myRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
        local myPos = myRoot and myRoot.Position
        for plr, d in pairs(espTracked) do
            local char = plr.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if char and root and hum and hum.Health > 0 then
                d.hl.Adornee = char
                d.hl.Enabled = true
                d.billboard.Adornee = char:FindFirstChild("Head") or root
                d.billboard.Enabled = true
                local dist = myPos and math.floor((root.Position - myPos).Magnitude) or 0
                d.label.Text = string.format("%s [%d m]", plr.Name, dist)
            else
                d.hl.Adornee = nil
                d.hl.Enabled = false
                d.billboard.Adornee = nil
                d.billboard.Enabled = false
            end
        end
    end))
end

local function stopESP()
    for _, c in ipairs(espConns) do pcall(function() c:Disconnect() end) end
    espConns = {}
    for p, _ in pairs(espTracked) do removeESP(p) end
end

-- ============================================================
-- FOV RING + AURA HIGHLIGHTS
-- ============================================================
local fovGui = Instance.new("ScreenGui")
fovGui.Name = "AuraFOVRing"
fovGui.ResetOnSpawn = false
fovGui.IgnoreGuiInset = true
fovGui.DisplayOrder = 190
pcall(function() fovGui.Parent = CoreGui end)
if not fovGui.Parent then fovGui.Parent = localPlayer:WaitForChild("PlayerGui") end

local fovCircle = Instance.new("Frame")
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
fovCircle.BackgroundTransparency = 1
fovCircle.Visible = false
fovCircle.Parent = fovGui
local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Color3.fromRGB(255, 60, 60)
fovStroke.Thickness = 2
fovStroke.Transparency = 0.25
fovStroke.Parent = fovCircle
local fovCorner = Instance.new("UICorner")
fovCorner.CornerRadius = UDim.new(1, 0)
fovCorner.Parent = fovCircle

local auraFolder = Instance.new("Folder")
auraFolder.Name = "AuraRedHL"
auraFolder.Parent = Workspace
local auraHighlights = {}

local function ensureAuraHL(plr)
    if auraHighlights[plr] then return auraHighlights[plr] end
    local h = Instance.new("Highlight")
    h.Name = "AuraHL_" .. plr.UserId
    h.FillColor = Color3.fromRGB(255, 40, 40)
    h.OutlineColor = Color3.fromRGB(255, 180, 180)
    h.FillTransparency = 0.5
    h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Enabled = false
    h.Parent = auraFolder
    auraHighlights[plr] = h
    return h
end

local function updateFOVRing()
    if not cfg.fovRing then fovCircle.Visible = false; return end
    local center = Camera.ViewportSize / 2
    local worldPoint = Camera.CFrame.Position + (Camera.CFrame.RightVector * AURA.radius)
    local screenPoint = Camera:WorldToViewportPoint(worldPoint)
    local pixelRadius = math.abs(screenPoint.X - center.X)
    if pixelRadius < 4 then pixelRadius = 4 end
    fovCircle.Visible = true
    fovCircle.Size = UDim2.fromOffset(pixelRadius * 2, pixelRadius * 2)
end

task.spawn(function()
    local lastFire, lastKillAllFire = 0, 0
    while true do
        task.wait(0.05)
        updateFOVRing()
        local myPos = getMyPos()
        if myPos then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= localPlayer and p.Character and not isWhitelisted(p) then
                    local root = p.Character:FindFirstChild("HumanoidRootPart")
                    local hum = p.Character:FindFirstChildOfClass("Humanoid")
                    local hl = ensureAuraHL(p)
                    if root and hum and hum.Health > 0 then
                        local inRange = (myPos - root.Position).Magnitude <= AURA.radius
                        if inRange and (cfg.aura or cfg.killAll) then
                            hl.Adornee = p.Character; hl.Enabled = true
                        else
                            hl.Adornee = nil; hl.Enabled = false
                        end
                    else
                        hl.Adornee = nil; hl.Enabled = false
                    end
                elseif isWhitelisted(p) then
                    local hl = auraHighlights[p]
                    if hl then hl.Adornee = nil; hl.Enabled = false end
                end
            end
        end
        if cfg.aura and (not AURA.requireGun or isHoldingGun()) then
            local now = tick()
            if (now - lastFire) >= AURA.interval then
                lastFire = now
                if myPos then
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= localPlayer and p.Character and not isWhitelisted(p) then
                            local root = p.Character:FindFirstChild("HumanoidRootPart")
                            local hum = p.Character:FindFirstChildOfClass("Humanoid")
                            if root and hum and hum.Health > 0 and (myPos - root.Position).Magnitude <= AURA.radius then
                                fireMagicAt(p)
                            end
                        end
                    end
                end
            end
        end
        if cfg.killAll and (not AURA.requireGun or isHoldingGun()) then
            local now = tick()
            if (now - lastKillAllFire) >= AURA.killAllInterval then
                lastKillAllFire = now
                if myPos then
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= localPlayer and p.Character and not isWhitelisted(p) then
                            local root = p.Character:FindFirstChild("HumanoidRootPart")
                            local hum = p.Character:FindFirstChildOfClass("Humanoid")
                            if root and hum and hum.Health > 0 and (myPos - root.Position).Magnitude <= AURA.radius then
                                fireMagicAt(p)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ============================================================
-- PLAYER TP
-- ============================================================
local function tpToPlayer(plr)
    local myChar = localPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local theirChar = plr.Character
    local theirHrp = theirChar and theirChar:FindFirstChild("HumanoidRootPart")
    if myHrp and theirHrp then
        myHrp.CFrame = theirHrp.CFrame * CFrame.new(0, 0, 3)
        myHrp.AssemblyLinearVelocity = Vector3.zero
    end
end

-- ============================================================
-- THEME
-- ============================================================
local THEME = {
    Bg         = Color3.fromRGB(14, 10, 14),
    Rail       = Color3.fromRGB(20, 14, 20),
    Panel      = Color3.fromRGB(24, 18, 24),
    PanelAlt   = Color3.fromRGB(32, 24, 32),
    Card       = Color3.fromRGB(28, 20, 28),
    Accent     = Color3.fromRGB(255, 45, 70),
    AccentDim  = Color3.fromRGB(120, 20, 35),
    AccentGlow = Color3.fromRGB(255, 90, 110),
    Text       = Color3.fromRGB(240, 232, 240),
    TextDim    = Color3.fromRGB(140, 120, 140),
    SectionTxt = Color3.fromRGB(255, 80, 100),
    Stroke     = Color3.fromRGB(80, 20, 40),
}

-- ============================================================
-- ANIMATED UI HELPERS
-- ============================================================
local function tween(inst, time, props, style, dir)
    local t = TweenService:Create(inst, TweenInfo.new(time or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function makeToggle(parent, labelText, initial, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3 = THEME.Card
    row.BorderSizePixel = 0
    row.Parent = parent
    local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 6); rc.Parent = row
    local stroke = Instance.new("UIStroke"); stroke.Color = THEME.Stroke; stroke.Thickness = 1; stroke.Transparency = 0.5; stroke.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.7, 0, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = THEME.Text
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 38, 0, 20)
    track.Position = UDim2.new(1, -50, 0.5, -10)
    track.BackgroundColor3 = initial and THEME.Accent or Color3.fromRGB(50, 40, 50)
    track.BorderSizePixel = 0
    track.Parent = row
    local trc = Instance.new("UICorner"); trc.CornerRadius = UDim.new(1, 0); trc.Parent = track

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = initial and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = track
    local kc = Instance.new("UICorner"); kc.CornerRadius = UDim.new(1, 0); kc.Parent = knob

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = row

    local state = initial
    btn.MouseButton1Click:Connect(function()
        state = not state
        tween(track, 0.18, { BackgroundColor3 = state and THEME.Accent or Color3.fromRGB(50, 40, 50) })
        tween(knob, 0.18, { Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8) })
        if callback then callback(state) end
    end)
    return row
end

local function makeSlider(parent, label, initial, minV, maxV, setter, isFloat)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 54)
    row.BackgroundColor3 = THEME.Card
    row.BorderSizePixel = 0
    row.Parent = parent
    local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 6); rc.Parent = row
    local stroke = Instance.new("UIStroke"); stroke.Color = THEME.Stroke; stroke.Thickness = 1; stroke.Transparency = 0.5; stroke.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -90, 0, 18)
    lbl.Position = UDim2.new(0, 12, 0, 5)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = THEME.Text
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, 64, 0, 20)
    box.Position = UDim2.new(1, -74, 0, 4)
    box.BackgroundColor3 = Color3.fromRGB(45, 30, 45)
    box.Text = isFloat and string.format("%.3f", initial) or tostring(initial)
    box.TextColor3 = THEME.Text
    box.TextSize = 11
    box.Font = Enum.Font.Code
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.Parent = row
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 4); bc.Parent = box

    local track = Instance.new("TextButton")
    track.Size = UDim2.new(1, -24, 0, 10)
    track.Position = UDim2.new(0, 12, 0, 32)
    track.BackgroundColor3 = Color3.fromRGB(45, 30, 45)
    track.Text = ""
    track.AutoButtonColor = false
    track.BorderSizePixel = 0
    track.Parent = row
    local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(1, 0); tc.Parent = track

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((initial - minV) / (maxV - minV), 0, 1, 0)
    fill.BackgroundColor3 = THEME.Accent
    fill.BorderSizePixel = 0
    fill.Parent = track
    local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(1, 0); fc.Parent = fill

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.Position = UDim2.new(fill.Size.X.Scale, -6, 0.5, -6)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = track
    local knc = Instance.new("UICorner"); knc.CornerRadius = UDim.new(1, 0); knc.Parent = knob

    local function setVal(v)
        if isFloat then v = math.clamp(v, minV, maxV) else v = math.clamp(math.floor(v), minV, maxV) end
        local scale = (v - minV) / (maxV - minV)
        tween(fill, 0.1, { Size = UDim2.new(scale, 0, 1, 0) })
        tween(knob, 0.1, { Position = UDim2.new(scale, -6, 0.5, -6) })
        box.Text = isFloat and string.format("%.3f", v) or tostring(v)
        setter(v)
    end

    box.FocusLost:Connect(function(enter)
        if enter then
            local n = tonumber(box.Text)
            if n then setVal(n) else box.Text = isFloat and string.format("%.3f", initial) or tostring(initial) end
        end
    end)

    track.MouseButton1Down:Connect(function()
        local function update()
            local m = UserInputService:GetMouseLocation()
            local rel = math.clamp((m.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            setVal(minV + (maxV - minV) * rel)
        end
        update()
        local m, e
        m = UserInputService.InputChanged:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseMovement then update() end
        end)
        e = UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then m:Disconnect(); e:Disconnect() end
        end)
    end)
    return row
end

local function makeDropdown(parent, label, options, current, setter)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3 = THEME.Card
    row.BorderSizePixel = 0
    row.Parent = parent
    local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 6); rc.Parent = row
    local stroke = Instance.new("UIStroke"); stroke.Color = THEME.Stroke; stroke.Thickness = 1; stroke.Transparency = 0.5; stroke.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.4, 0, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = THEME.Text
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.55, -24, 0, 24)
    btn.Position = UDim2.new(0.45, 0, 0.5, -12)
    btn.BackgroundColor3 = Color3.fromRGB(45, 30, 45)
    btn.Text = current
    btn.TextColor3 = THEME.AccentGlow
    btn.TextSize = 11
    btn.Font = Enum.Font.Code
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = row
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 4); bc.Parent = btn

    btn.MouseButton1Click:Connect(function()
        local idx = 1
        for i, o in ipairs(options) do if o == btn.Text then idx = i; break end end
        idx = (idx % #options) + 1
        btn.Text = options[idx]
        setter(options[idx])
    end)
    return row
end

local function makeSectionHeader(parent, text)
    local h = Instance.new("Frame")
    h.Size = UDim2.new(1, 0, 0, 26)
    h.BackgroundColor3 = Color3.fromRGB(35, 14, 22)
    h.BorderSizePixel = 0
    h.Parent = parent
    local hc = Instance.new("UICorner"); hc.CornerRadius = UDim.new(0, 4); hc.Parent = h
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 4, 0, 14)
    dot.Position = UDim2.new(0, 8, 0.5, -7)
    dot.BackgroundColor3 = THEME.Accent
    dot.BorderSizePixel = 0
    dot.Parent = h
    local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(1, 0); dc.Parent = dot
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 1, 0)
    lbl.Position = UDim2.new(0, 20, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = THEME.SectionTxt
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = h
    return h
end

-- ============================================================
-- MAIN GUI
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name = "FlyAimHub"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 200
pcall(function() gui.Parent = CoreGui end)
if not gui.Parent then gui.Parent = localPlayer:WaitForChild("PlayerGui") end

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 720, 0, 480)
main.Position = UDim2.new(0.5, -360, 0.5, -240)
main.BackgroundColor3 = THEME.Bg
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.ClipsDescendants = true
main.Parent = gui
local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0, 10); mc.Parent = main
local ms = Instance.new("UIStroke"); ms.Color = THEME.Stroke; ms.Thickness = 1; ms.Parent = main

-- Mouse Tracking Gradient (Depth Effect)
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 90)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 5, 10)),
}
gradient.Transparency = NumberSequence.new{
    NumberSequenceKeypoint.new(0, 0.85),
    NumberSequenceKeypoint.new(1, 1),
}
gradient.Parent = main

local targetOffset = Vector2.new(0.5, 0.5)
local currentOffset = Vector2.new(0.5, 0.5)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        local mouse = UserInputService:GetMouseLocation()
        local relativeX = (mouse.X - main.AbsolutePosition.X) / main.AbsoluteSize.X
        local relativeY = (mouse.Y - main.AbsolutePosition.Y) / main.AbsoluteSize.Y
        if relativeX >= 0 and relativeX <= 1 and relativeY >= 0 and relativeY <= 1 then
            targetOffset = Vector2.new(relativeX, relativeY)
        end
    end
end)

RunService.RenderStepped:Connect(function()
    currentOffset = currentOffset:Lerp(targetOffset, 0.1)
    gradient.Offset = currentOffset
end)

local topGlow = Instance.new("Frame")
topGlow.Size = UDim2.new(1, 0, 0, 2)
topGlow.BackgroundColor3 = THEME.Accent
topGlow.BorderSizePixel = 0
topGlow.Parent = main
local tgc = Instance.new("UICorner"); tgc.CornerRadius = UDim.new(1, 0); tgc.Parent = topGlow

-- ============ RIGHT RAIL (TABS) ============
local rail = Instance.new("Frame")
rail.Size = UDim2.new(0, 150, 1, -40)
rail.Position = UDim2.new(1, -160, 0, 30)
rail.BackgroundColor3 = THEME.Rail
rail.BorderSizePixel = 0
rail.Parent = main
local rrc = Instance.new("UICorner"); rrc.CornerRadius = UDim.new(0, 8); rrc.Parent = rail
local rrs = Instance.new("UIStroke"); rrs.Color = THEME.Stroke; rrs.Thickness = 1; rrs.Transparency = 0.5; rrs.Parent = rail

local railTitle = Instance.new("TextLabel")
railTitle.Size = UDim2.new(1, 0, 0, 30)
railTitle.Position = UDim2.new(0, 0, 0, 0)
railTitle.BackgroundTransparency = 1
railTitle.Text = "Xenon"
railTitle.TextColor3 = THEME.Accent
railTitle.TextSize = 16
railTitle.Font = Enum.Font.GothamBold
railTitle.Parent = rail

local railTabs = {}
local railTabOrder = {
    { key = "main",    label = "Main" },
    { key = "aim",     label = "Aim" },
    { key = "aura",    label = "Aura" },
    { key = "guns",    label = "Guns" },
    { key = "players", label = "Players" },
}

local railList = Instance.new("Frame")
railList.Size = UDim2.new(1, 0, 1, -40)
railList.Position = UDim2.new(0, 0, 0, 36)
railList.BackgroundTransparency = 1
railList.Parent = rail
local rl = Instance.new("UIListLayout")
rl.Padding = UDim.new(0, 4)
rl.Parent = railList
local rlp = Instance.new("UIPadding")
rlp.PaddingLeft = UDim.new(0, 8); rlp.PaddingRight = UDim.new(0, 8); rlp.Parent = railList

for _, t in ipairs(railTabOrder) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = Color3.fromRGB(30, 20, 30)
    btn.BackgroundTransparency = 0.4
    btn.Text = ""
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = railList
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 6); bc.Parent = btn

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 6, 0, 6)
    dot.Position = UDim2.new(0, 8, 0.5, -3)
    dot.BackgroundColor3 = THEME.Accent
    dot.BorderSizePixel = 0
    dot.Visible = false
    dot.Parent = btn
    local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(1, 0); dc.Parent = dot

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -24, 1, 0)
    lbl.Position = UDim2.new(0, 20, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = t.label
    lbl.TextColor3 = THEME.TextDim
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = btn

    btn.MouseEnter:Connect(function()
        if activeKey ~= t.key then
            tween(btn, 0.15, { BackgroundColor3 = Color3.fromRGB(45, 30, 45), BackgroundTransparency = 0.2 })
            tween(lbl, 0.15, { TextColor3 = THEME.Text })
        end
    end)
    btn.MouseLeave:Connect(function()
        if activeKey ~= t.key then
            tween(btn, 0.15, { BackgroundColor3 = Color3.fromRGB(30, 20, 30), BackgroundTransparency = 0.4 })
            tween(lbl, 0.15, { TextColor3 = THEME.TextDim })
        end
    end)

    railTabs[t.key] = { btn = btn, dot = dot, lbl = lbl }
end

-- ============ PAGES CONTAINER ============
local pagesFrame = Instance.new("Frame")
pagesFrame.Size = UDim2.new(1, -180, 1, -40)
pagesFrame.Position = UDim2.new(0, 10, 0, 30)
pagesFrame.BackgroundColor3 = THEME.Panel
pagesFrame.BorderSizePixel = 0
pagesFrame.Parent = main
local pfc = Instance.new("UICorner"); pfc.CornerRadius = UDim.new(0, 8); pfc.Parent = pagesFrame
local pfs = Instance.new("UIStroke"); pfs.Color = THEME.Stroke; pfs.Thickness = 1; pfs.Transparency = 0.5; pfs.Parent = pagesFrame

local pages = {}
local activeKey = nil

local function switchTab(key)
    activeKey = key
    for k, pg in pairs(pages) do
        pg.Visible = (k == key)
    end
    for k, t in pairs(railTabs) do
        local isActive = (k == key)
        t.dot.Visible = isActive
        tween(t.btn, 0.15, { BackgroundColor3 = isActive and THEME.AccentDim or Color3.fromRGB(30, 20, 30), BackgroundTransparency = isActive and 0.1 or 0.4 })
        t.lbl.TextColor3 = isActive and THEME.Text or THEME.TextDim
    end
end

for _, t in ipairs(railTabOrder) do
    railTabs[t.key].btn.MouseButton1Click:Connect(function() switchTab(t.key) end)
end

local function makePage(key)
    local pg = Instance.new("ScrollingFrame")
    pg.Size = UDim2.new(1, -16, 1, -16)
    pg.Position = UDim2.new(0, 8, 0, 8)
    pg.BackgroundColor3 = THEME.Panel
    pg.BorderSizePixel = 0
    pg.ScrollBarThickness = 3
    pg.ScrollBarImageColor3 = THEME.Accent
    pg.CanvasSize = UDim2.new(0, 0, 0, 0)
    pg.Visible = false
    pg.Parent = pagesFrame
    local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0, 6); pc.Parent = pg
    local pl = Instance.new("UIListLayout"); pl.Padding = UDim.new(0, 6); pl.SortOrder = Enum.SortOrder.LayoutOrder; pl.Parent = pg
    local pp = Instance.new("UIPadding"); pp.PaddingLeft = UDim.new(0, 4); pp.PaddingRight = UDim.new(0, 4); pp.PaddingTop = UDim.new(0, 4); pp.Parent = pg
    pages[key] = pg
    return pg
end

local mainPage   = makePage("main")
local aimPage    = makePage("aim")
local auraPage   = makePage("aura")
local gunsPage   = makePage("guns")
local playerPage = makePage("players")

local function autoCanvas(scroll)
    task.defer(function()
        local layout = scroll:FindFirstChildOfClass("UIListLayout")
        if layout then
            scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
            layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
            end)
        end
    end)
end

-- ============ MAIN PAGE ============
makeSectionHeader(mainPage, "Control")
makeToggle(mainPage, "Fly (WASD, Space/Ctrl)", cfg.fly, function(v)
    cfg.fly = v
    if v then startFly() else stopFly() end
end)
makeSlider(mainPage, "Fly Speed", FLY_SPEED, 1, 50, function(v) FLY_SPEED = v end, false)
makeToggle(mainPage, "Noclip", cfg.noclip, function(v)
    cfg.noclip = v
    if v then startNoclip() else stopNoclip() end
end)
makeSectionHeader(mainPage, "Visuals")
makeToggle(mainPage, "Hitbox Extender", cfg.hbe, function(v)
    cfg.hbe = v
    if v then startHBE() else stopHBE() end
end)
makeToggle(mainPage, "ESP", cfg.esp, function(v)
    cfg.esp = v
    if v then startESP() else stopESP() end
end)

-- ============ AIM PAGE ============
makeSectionHeader(aimPage, "Aim Control")

local aimToggleState = false
local aimToggleBtn

aimToggleBtn = makeToggle(aimPage, "Enable Aimlock", cfg.aimlock, function(v)
    cfg.aimlock = v
end)

-- Custom Dropdown for Activation Mode
local modeRow = Instance.new("Frame")
modeRow.Size = UDim2.new(1, 0, 0, 34)
modeRow.BackgroundColor3 = THEME.Card
modeRow.BorderSizePixel = 0
modeRow.Parent = aimPage
local mrc = Instance.new("UICorner"); mrc.CornerRadius = UDim.new(0, 6); mrc.Parent = modeRow
local mrs = Instance.new("UIStroke"); mrs.Color = THEME.Stroke; mrs.Thickness = 1; mrs.Transparency = 0.5; mrs.Parent = modeRow

local modeLbl = Instance.new("TextLabel")
modeLbl.Size = UDim2.new(0.4, 0, 1, 0)
modeLbl.Position = UDim2.new(0, 12, 0, 0)
modeLbl.BackgroundTransparency = 1
modeLbl.Text = "Activation Mode"
modeLbl.TextColor3 = THEME.Text
modeLbl.TextSize = 11
modeLbl.Font = Enum.Font.GothamMedium
modeLbl.TextXAlignment = Enum.TextXAlignment.Left
modeLbl.Parent = modeRow

local modeBtn = Instance.new("TextButton")
modeBtn.Size = UDim2.new(0.55, -24, 0, 24)
modeBtn.Position = UDim2.new(0.45, 0, 0.5, -12)
modeBtn.BackgroundColor3 = Color3.fromRGB(45, 30, 45)
modeBtn.Text = AIM.mode
modeBtn.TextColor3 = THEME.AccentGlow
modeBtn.TextSize = 11
modeBtn.Font = Enum.Font.Code
modeBtn.BorderSizePixel = 0
modeBtn.AutoButtonColor = false
modeBtn.Parent = modeRow
local mbc = Instance.new("UICorner"); mbc.CornerRadius = UDim.new(0, 4); mbc.Parent = modeBtn

-- Keybind UI
local keyPickerActive = false
local keybindBtn
local keybindLbl

local function updateKeybindUI()
    keybindBtn.BackgroundColor3 = Color3.fromRGB(45, 30, 45)
    keybindLbl.Text = "Activation Key"
    if keyPickerActive then
        keybindBtn.Text = "Press any key..."
        keybindBtn.BackgroundColor3 = THEME.AccentDim
    else
        keybindBtn.Text = AIM.keybind.Name
    end
end

local kbRow = Instance.new("Frame")
kbRow.Size = UDim2.new(1, 0, 0, 34)
kbRow.BackgroundColor3 = THEME.Card
kbRow.BorderSizePixel = 0
kbRow.Parent = aimPage
local kbrc = Instance.new("UICorner"); kbrc.CornerRadius = UDim.new(0, 6); kbrc.Parent = kbRow
local kbs = Instance.new("UIStroke"); kbs.Color = THEME.Stroke; kbs.Thickness = 1; kbs.Transparency = 0.5; kbs.Parent = kbRow

keybindLbl = Instance.new("TextLabel")
keybindLbl.Size = UDim2.new(0.4, 0, 1, 0)
keybindLbl.Position = UDim2.new(0, 12, 0, 0)
keybindLbl.BackgroundTransparency = 1
keybindLbl.Text = "Activation Key"
keybindLbl.TextColor3 = THEME.Text
keybindLbl.TextSize = 11
keybindLbl.Font = Enum.Font.GothamMedium
keybindLbl.TextXAlignment = Enum.TextXAlignment.Left
keybindLbl.Parent = kbRow

keybindBtn = Instance.new("TextButton")
keybindBtn.Size = UDim2.new(0.55, -24, 0, 24)
keybindBtn.Position = UDim2.new(0.45, 0, 0.5, -12)
keybindBtn.BackgroundColor3 = Color3.fromRGB(45, 30, 45)
keybindBtn.Text = AIM.keybind.Name
keybindBtn.TextColor3 = THEME.AccentGlow
keybindBtn.TextSize = 11
keybindBtn.Font = Enum.Font.Code
keybindBtn.BorderSizePixel = 0
keybindBtn.AutoButtonColor = false
keybindBtn.Parent = kbRow
local kbbc = Instance.new("UICorner"); kbbc.CornerRadius = UDim.new(0, 4); kbbc.Parent = keybindBtn

keybindBtn.MouseButton1Click:Connect(function()
    keyPickerActive = true
    updateKeybindUI()
end)

modeBtn.MouseButton1Click:Connect(function()
    local options = {"Toggle", "Hold"}
    local idx = 1
    for i, o in ipairs(options) do if o == modeBtn.Text then idx = i; break end end
    idx = (idx % #options) + 1
    modeBtn.Text = options[idx]
    AIM.mode = options[idx]
    
    if AIM.mode ~= "Toggle" then
        cfg.aimlock = false
        if aimToggleBtn then
            local track = aimToggleBtn:FindFirstChildWhichIsA("Frame")
            local knob = track and track:FindFirstChildWhichIsA("Frame")
            if track and knob then
                tween(track, 0.18, { BackgroundColor3 = Color3.fromRGB(50, 40, 50) })
                tween(knob, 0.18, { Position = UDim2.new(0, 2, 0.5, -8) })
            end
        end
    end
end)

updateKeybindUI()

makeDropdown(aimPage, "Lock Part", {"Head", "Torso", "Nearest"}, AIM.part, function(v) AIM.part = v end)
makeSlider(aimPage, "Smoothness (0=tight, 1=slow)", AIM.smooth, 0, 0.99, function(v) AIM.smooth = v end, true)
makeSlider(aimPage, "Aim FOV (pixels)", AIM.fov, 50, 1000, function(v) AIM.fov = v end, false)

makeSectionHeader(aimPage, "Aim Whitelist")
local aimWlScroll = Instance.new("ScrollingFrame")
aimWlScroll.Size = UDim2.new(1, 0, 0, 240)
aimWlScroll.BackgroundColor3 = THEME.Card
aimWlScroll.BorderSizePixel = 0
aimWlScroll.ScrollBarThickness = 3
aimWlScroll.ScrollBarImageColor3 = THEME.Accent
aimWlScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
aimWlScroll.Parent = aimPage
local awc = Instance.new("UICorner"); awc.CornerRadius = UDim.new(0, 6); awc.Parent = aimWlScroll
local awl = Instance.new("UIListLayout"); awl.Parent = aimWlScroll; awl.SortOrder = Enum.SortOrder.Name; awl.Padding = UDim.new(0, 3)
local awp = Instance.new("UIPadding"); awp.PaddingLeft = UDim.new(0, 4); awp.PaddingRight = UDim.new(0, 4); awp.PaddingTop = UDim.new(0, 4); awp.Parent = aimWlScroll

local function rebuildAimWhitelist()
    for _, ch in ipairs(aimWlScroll:GetChildren()) do
        if ch:IsA("TextButton") then ch:Destroy() end
    end
    local count = 0
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer then
            count = count + 1
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, -8, 0, 26)
            b.BackgroundColor3 = isWhitelisted(p) and THEME.AccentDim or Color3.fromRGB(38, 26, 38)
            b.Text = (isWhitelisted(p) and "[WL] " or "") .. p.Name
            b.TextColor3 = THEME.Text
            b.TextSize = 11
            b.Font = Enum.Font.Code
            b.TextXAlignment = Enum.TextXAlignment.Left
            b.BorderSizePixel = 0
            b.AutoButtonColor = false
            b.Parent = aimWlScroll
            local bbc = Instance.new("UICorner"); bbc.CornerRadius = UDim.new(0, 4); bbc.Parent = b
            local bpad = Instance.new("UIPadding"); bpad.PaddingLeft = UDim.new(0, 8); bpad.Parent = b
            b.MouseButton1Click:Connect(function()
                if WHITELIST[p.UserId] then WHITELIST[p.UserId] = nil
                else WHITELIST[p.UserId] = true end
                rebuildAimWhitelist()
                if rebuildPlayerList then rebuildPlayerList() end
            end)
        end
    end
    aimWlScroll.CanvasSize = UDim2.new(0, 0, 0, count * 30 + 4)
end

-- Input handling for Keybind Picker and Aim Activation
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if keyPickerActive then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            AIM.keybind = input.KeyCode
            keyPickerActive = false
            updateKeybindUI()
        end
    else
        if gameProcessed then return end
        if input.KeyCode == AIM.keybind then
            if AIM.mode == "Toggle" then
                cfg.aimlock = not cfg.aimlock
                if aimToggleBtn then
                    local track = aimToggleBtn:FindFirstChildWhichIsA("Frame")
                    local knob = track and track:FindFirstChildWhichIsA("Frame")
                    if track and knob then
                        tween(track, 0.18, { BackgroundColor3 = cfg.aimlock and THEME.Accent or Color3.fromRGB(50, 40, 50) })
                        tween(knob, 0.18, { Position = cfg.aimlock and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8) })
                    end
                end
            elseif AIM.mode == "Hold" then
                AIM.holdActive = true
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if not keyPickerActive then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == AIM.keybind and AIM.mode == "Hold" then
                AIM.holdActive = false
            end
        end
    end
end)

startAim() -- Start the aim loop immediately

-- ============ AURA PAGE ============
makeSectionHeader(auraPage, "Aura")
makeToggle(auraPage, "Proximity Aura", cfg.aura, function(v) cfg.aura = v end)
makeToggle(auraPage, "Kill Everyone in Range", cfg.killAll, function(v) cfg.killAll = v end)
makeToggle(auraPage, "Show FOV Ring", cfg.fovRing, function(v) cfg.fovRing = v end)
makeToggle(auraPage, "Require Held Weapon", cfg.auraRequireGun, function(v)
    cfg.auraRequireGun = v
    AURA.requireGun = v
end)
makeSlider(auraPage, "Aura Radius (studs)", AURA.radius, 10, 300, function(v) AURA.radius = v end, false)

-- ============ GUNS PAGE ============
makeSectionHeader(gunsPage, "Fire Rate Multiplier")
local multRow = Instance.new("Frame")
multRow.Size = UDim2.new(1, 0, 0, 64)
multRow.BackgroundColor3 = THEME.Card
multRow.BorderSizePixel = 0
multRow.Parent = gunsPage
local mrc2 = Instance.new("UICorner"); mrc2.CornerRadius = UDim.new(0, 6); mrc2.Parent = multRow
local mrs2 = Instance.new("UIStroke"); mrs2.Color = THEME.Stroke; mrs2.Thickness = 1; mrs2.Transparency = 0.5; mrs2.Parent = multRow

local multLbl = Instance.new("TextLabel")
multLbl.Size = UDim2.new(1, -24, 0, 18)
multLbl.Position = UDim2.new(0, 12, 0, 5)
multLbl.BackgroundTransparency = 1
multLbl.Text = "Multiplier (0.5 = 2x faster)"
multLbl.TextColor3 = THEME.Text
multLbl.TextSize = 11
multLbl.Font = Enum.Font.GothamMedium
multLbl.TextXAlignment = Enum.TextXAlignment.Left
multLbl.Parent = multRow

local multBox = Instance.new("TextBox")
multBox.Size = UDim2.new(0, 70, 0, 24)
multBox.Position = UDim2.new(1, -82, 0, 28)
multBox.BackgroundColor3 = Color3.fromRGB(45, 30, 45)
multBox.Text = tostring(FIRE_MULTIPLIER)
multBox.TextColor3 = THEME.Text
multBox.TextSize = 11
multBox.Font = Enum.Font.Code
multBox.BorderSizePixel = 0
multBox.ClearTextOnFocus = false
multBox.Parent = multRow
local mbc2 = Instance.new("UICorner"); mbc2.CornerRadius = UDim.new(0, 4); mbc2.Parent = multBox

local applyBtn = Instance.new("TextButton")
applyBtn.Size = UDim2.new(0, 90, 0, 24)
applyBtn.Position = UDim2.new(0, 12, 0, 28)
applyBtn.BackgroundColor3 = THEME.AccentDim
applyBtn.Text = "Apply All"
applyBtn.TextColor3 = THEME.Text
applyBtn.TextSize = 11
applyBtn.Font = Enum.Font.GothamBold
applyBtn.BorderSizePixel = 0
applyBtn.AutoButtonColor = false
applyBtn.Parent = multRow
local abc = Instance.new("UICorner"); abc.CornerRadius = UDim.new(0, 4); abc.Parent = applyBtn
applyBtn.MouseButton1Click:Connect(function()
    local num = tonumber(multBox.Text)
    if num then
        FIRE_MULTIPLIER = math.clamp(num, 0.01, 10)
        multBox.Text = tostring(FIRE_MULTIPLIER)
        applyAllCooldowns()
    end
end)

makeSectionHeader(gunsPage, "Per-Gun Cooldowns")
local gunsScroll = Instance.new("ScrollingFrame")
gunsScroll.Size = UDim2.new(1, 0, 0, 340)
gunsScroll.BackgroundColor3 = THEME.Card
gunsScroll.BorderSizePixel = 0
gunsScroll.ScrollBarThickness = 3
gunsScroll.ScrollBarImageColor3 = THEME.Accent
gunsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
gunsScroll.Parent = gunsPage
local gsc = Instance.new("UICorner"); gsc.CornerRadius = UDim.new(0, 6); gsc.Parent = gunsScroll
local gsl = Instance.new("UIListLayout"); gsl.Parent = gunsScroll; gsl.Padding = UDim.new(0, 4); gsl.SortOrder = Enum.SortOrder.Name
local gsp = Instance.new("UIPadding"); gsp.PaddingLeft = UDim.new(0, 4); gsp.PaddingRight = UDim.new(0, 4); gsp.PaddingTop = UDim.new(0, 4); gsp.Parent = gunsScroll

for _, gunName in ipairs(GUN_LIST) do
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -8, 0, 54)
    row.BackgroundColor3 = Color3.fromRGB(38, 26, 38)
    row.BorderSizePixel = 0
    row.Parent = gunsScroll
    local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 5); rc.Parent = row

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(0.4, 0, 0, 18)
    nameLbl.Position = UDim2.new(0, 10, 0, 4)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = gunName
    nameLbl.TextColor3 = THEME.Text
    nameLbl.TextSize = 11
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.Parent = row

    local cdBox = Instance.new("TextBox")
    cdBox.Size = UDim2.new(0, 70, 0, 22)
    cdBox.Position = UDim2.new(1, -80, 0, 3)
    cdBox.BackgroundColor3 = Color3.fromRGB(45, 30, 45)
    local currentCD = GUN_COOLDOWNS[gunName] or 0.1
    cdBox.Text = string.format("%.3f", currentCD)
    cdBox.TextColor3 = THEME.Text
    cdBox.TextSize = 11
    cdBox.Font = Enum.Font.Code
    cdBox.BorderSizePixel = 0
    cdBox.ClearTextOnFocus = false
    cdBox.Parent = row
    local cbc = Instance.new("UICorner"); cbc.CornerRadius = UDim.new(0, 4); cbc.Parent = cdBox

    local slider = Instance.new("TextButton")
    slider.Size = UDim2.new(1, -20, 0, 8)
    slider.Position = UDim2.new(0, 10, 0, 34)
    slider.BackgroundColor3 = Color3.fromRGB(45, 30, 45)
    slider.Text = ""
    slider.AutoButtonColor = false
    slider.BorderSizePixel = 0
    slider.Parent = row
    local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(1, 0); sc.Parent = slider

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(math.clamp((currentCD - 0.01) / (0.5 - 0.01), 0, 1), 0, 1, 0)
    fill.BackgroundColor3 = THEME.Accent
    fill.BorderSizePixel = 0
    fill.Parent = slider
    local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(1, 0); fc.Parent = fill

    local function setGunCD(v)
        v = math.clamp(v, 0.01, 0.5)
        GUN_COOLDOWNS[gunName] = v
        cdBox.Text = string.format("%.3f", v)
        tween(fill, 0.1, { Size = UDim2.new((v - 0.01) / (0.5 - 0.01), 0, 1, 0) })
        if GunConfigs and GunConfigs[gunName] then
            GunConfigs[gunName].CoolDown = v * FIRE_MULTIPLIER
        end
    end

    cdBox.FocusLost:Connect(function(enter)
        if enter then
            local num = tonumber(cdBox.Text)
            if num then setGunCD(num) else cdBox.Text = string.format("%.3f", currentCD) end
        end
    end)

    slider.MouseButton1Down:Connect(function()
        local function update()
            local m = UserInputService:GetMouseLocation()
            local rel = math.clamp((m.X - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
            setGunCD(0.01 + (0.5 - 0.01) * rel)
        end
        update()
        local m, e
        m = UserInputService.InputChanged:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseMovement then update() end
        end)
        e = UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then m:Disconnect(); e:Disconnect() end
        end)
    end)
end

-- ============ PLAYERS PAGE ============
makeSectionHeader(playerPage, "Players (tap = whitelist, double = TP)")
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, 0, 0, 340)
scroll.BackgroundColor3 = THEME.Card
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 3
scroll.ScrollBarImageColor3 = THEME.Accent
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.Parent = playerPage
local sc2 = Instance.new("UICorner"); sc2.CornerRadius = UDim.new(0, 6); sc2.Parent = scroll
local scrollList = Instance.new("UIListLayout")
scrollList.Parent = scroll
scrollList.SortOrder = Enum.SortOrder.Name
scrollList.Padding = UDim.new(0, 3)
local scp = Instance.new("UIPadding"); scp.PaddingLeft = UDim.new(0, 4); scp.PaddingRight = UDim.new(0, 4); scp.PaddingTop = UDim.new(0, 4); scp.Parent = scroll

local DOUBLE_CLICK_WINDOW = 0.35
local lastClick = {}

function rebuildPlayerList()
    for _, ch in ipairs(scroll:GetChildren()) do
        if ch:IsA("TextButton") then ch:Destroy() end
    end
    local count = 0
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer then
            count = count + 1
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, -8, 0, 28)
            b.BackgroundColor3 = isWhitelisted(p) and THEME.AccentDim or Color3.fromRGB(38, 26, 38)
            b.Text = (isWhitelisted(p) and "[WL] " or "") .. p.Name .. "  [" .. p.DisplayName .. "]"
            b.TextColor3 = THEME.Text
            b.TextSize = 11
            b.Font = Enum.Font.Code
            b.TextXAlignment = Enum.TextXAlignment.Left
            b.BorderSizePixel = 0
            b.AutoButtonColor = false
            b.Parent = scroll
            local bbc = Instance.new("UICorner"); bbc.CornerRadius = UDim.new(0, 4); bbc.Parent = b
            local bpad = Instance.new("UIPadding"); bpad.PaddingLeft = UDim.new(0, 8); bpad.Parent = b

            b.MouseButton1Click:Connect(function()
                local now = tick()
                local last = lastClick[p.UserId] or 0
                if (now - last) <= DOUBLE_CLICK_WINDOW then
                    lastClick[p.UserId] = 0
                    tpToPlayer(p)
                else
                    lastClick[p.UserId] = now
                    task.delay(DOUBLE_CLICK_WINDOW + 0.02, function()
                        if lastClick[p.UserId] == now then
                            if WHITELIST[p.UserId] then WHITELIST[p.UserId] = nil
                            else WHITELIST[p.UserId] = true end
                            rebuildPlayerList()
                            if rebuildAimWhitelist then rebuildAimWhitelist() end
                        end
                    end)
                end
            end)
        end
    end
    scroll.CanvasSize = UDim2.new(0, 0, 0, count * 32 + 4)
end

rebuildPlayerList()
rebuildAimWhitelist()
Players.PlayerAdded:Connect(function() task.wait(0.5); rebuildPlayerList(); rebuildAimWhitelist() end)
Players.PlayerRemoving:Connect(function() task.wait(0.2); rebuildPlayerList(); rebuildAimWhitelist() end)

autoCanvas(mainPage)
autoCanvas(aimPage)
autoCanvas(auraPage)
autoCanvas(gunsPage)
autoCanvas(playerPage)

-- ============ PANEL OPEN/CLOSE ANIMATION ============
local panelOpen = true
local function setPanelOpen(open)
    panelOpen = open
    if open then
        main.Visible = true
        main.Size = UDim2.new(0, 0, 0, 0)
        main.Position = UDim2.new(0.5, 0, 0.5, 0)
        main.BackgroundTransparency = 1
        tween(main, 0.22, { Size = UDim2.new(0, 720, 0, 480), Position = UDim2.new(0.5, -360, 0.5, -240), BackgroundTransparency = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    else
        local t = tween(main, 0.18, { Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        t.Completed:Connect(function()
            if not panelOpen then main.Visible = false end
        end)
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        setPanelOpen(not panelOpen)
    end
end)

switchTab("main")
main.Visible = true

-- ============================================================
-- CLEANUP
-- ============================================================
localPlayer.CharacterRemoving:Connect(function()
    if cfg.fly then
        task.spawn(function()
            task.wait(0.5)
            if cfg.fly and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
                stopFly(); startFly()
            end
        end)
    end
    if cfg.noclip then
        task.spawn(function()
            task.wait(0.5)
            if cfg.noclip then startNoclip() end
        end)
    end
end)

print("lel ez scripts")
