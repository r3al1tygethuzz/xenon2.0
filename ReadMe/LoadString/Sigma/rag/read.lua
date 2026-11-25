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
local localPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ============================================================
-- CONFIG
-- ============================================================
local FLY_SPEED = 24
local AIM_SMOOTH = 0.15
local HBE_SIZE = 8
local AIM_FOV = 250
local FIRE_MULTIPLIER = 1.0   -- scales all gun cooldowns (0.5 = 2x speed)

local cfg = {
    fly     = false,
    hbe     = false,
    aimlock = false,
    esp     = false,
    aura    = false,
    killAll = false,
    fovRing = false,
    auraRequireGun = true,
}

local AIM = {
    part = "Head",       -- "Head" / "Torso" / "Nearest"
    smooth = 0.15,       -- lerp factor
    fov = 250,           -- pixel radius
}

local AURA = {
    radius   = 60,
    interval = 0.12,
    useHead  = true,
    requireGun = true,
    killAllInterval = 0.25,
}

-- ============================================================
-- GUN CONFIG HOOK (super fast fire)
-- ============================================================
local GunConfigs = nil
pcall(function()
    GunConfigs = require(ReplicatedStorage:WaitForChild("GunConfigs", 10))
end)

-- original cooldowns, for reset
local ORIGINAL_COOLDOWNS = {}
local GUN_LIST = {
    "Glock", "Deagle", "Spaz", "AA12", "Revolver", "Sawed-Off", "Sniper",
    "Uzi", "Tec-9", "LMG", "AK47", "Tommy", "Assault Rifle", "Silencer",
    "Draco", "Firework Launcher",
}

-- per-gun fast cooldown targets
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
    for name, _ in pairs(GUN_COOLDOWNS) do
        applyCooldown(name)
    end
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

    local args = {
        [1] = "Fire",
        [2] = { [1] = target.Position, [2] = target },
        [3] = gun,
    }
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
                    -- Nearest: pick the closest visible limb by screen distance
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
        if not cfg.aimlock then return end
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
    hl.FillColor = Color3.fromRGB(62, 232, 122)
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
    if not cfg.fovRing then
        fovCircle.Visible = false
        return
    end
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
-- UI
-- ============================================================
local THEME = {
    Bg        = Color3.fromRGB(15,15,15),
    Panel     = Color3.fromRGB(26,26,26),
    PanelAlt  = Color3.fromRGB(32,32,32),
    Green     = Color3.fromRGB(255,55,65),
    GreenDark = Color3.fromRGB(125,25,32),
    Text      = Color3.fromRGB(230,235,230),
    TextDim   = Color3.fromRGB(120,130,120),
    Red       = Color3.fromRGB(255,70,70),
    RedDark   = Color3.fromRGB(140,40,40),
}

local gui = Instance.new("ScreenGui")
gui.Name = "FlyAimHub"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 200
pcall(function() gui.Parent = CoreGui end)
if not gui.Parent then gui.Parent = localPlayer:WaitForChild("PlayerGui") end

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 460, 0, 640)
main.Position = UDim2.new(0.5, -230, 0.5, -320)
main.BackgroundColor3 = THEME.Bg
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui
local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0,8); mc.Parent = main
local ms = Instance.new("UIStroke"); ms.Color = THEME.Green; ms.Thickness = 1; ms.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,-78,0,34)
title.Position = UDim2.new(0,0,0,0)
title.BackgroundColor3 = Color3.fromRGB(8,8,8)
title.BorderSizePixel = 0
title.Text = "Xenon"
title.TextColor3 = THEME.Green
title.TextSize = 16
title.Font = Enum.Font.GothamBold
title.Parent = main
local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0,8); tc.Parent = title

local keyHint = Instance.new("TextLabel")
keyHint.Size = UDim2.new(1,-16,0,18)
keyHint.Position = UDim2.new(0,8,0,36)
keyHint.BackgroundTransparency = 1
keyHint.Text = "RIGHT SHIFT = toggle panel  •  tap player = whitelist  •  double-click = TP"
keyHint.TextColor3 = THEME.TextDim
keyHint.TextSize = 9
keyHint.Font = Enum.Font.Code
keyHint.TextXAlignment = Enum.TextXAlignment.Left
keyHint.Parent = main

-- tab bar
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1,-16,0,30)
tabBar.Position = UDim2.new(0,8,0,58)
tabBar.BackgroundColor3 = THEME.Panel
tabBar.BorderSizePixel = 0
tabBar.Parent = main
local tbc = Instance.new("UICorner"); tbc.CornerRadius = UDim.new(0,4); tbc.Parent = tabBar
local tbl = Instance.new("UIListLayout")
tbl.FillDirection = Enum.FillDirection.Horizontal
tbl.Padding = UDim.new(0,2)
tbl.Parent = tabBar
local tbp = Instance.new("UIPadding")
tbp.PaddingLeft = UDim.new(0,4); tbp.PaddingRight = UDim.new(0,4); tbp.PaddingTop = UDim.new(0,3); tbp.Parent = tabBar

local pages = {}
local activeTab = nil

local function makeTabButton(name, key)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 76, 0, 24)
    b.BackgroundColor3 = THEME.PanelAlt
    b.Text = name
    b.TextColor3 = THEME.Text
    b.TextSize = 11
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Parent = tabBar
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,3); c.Parent = b
    b.MouseButton1Click:Connect(function()
        for k, pg in pairs(pages) do pg.Visible = (k == key) end
        activeTab = key
    end)
    return b
end

local function makePage(key, yPos, height)
    local pg = Instance.new("Frame")
    pg.Size = UDim2.new(1,-16,0,height)
    pg.Position = UDim2.new(0,8,0,yPos)
    pg.BackgroundTransparency = 1
    pg.Visible = false
    pg.Parent = main
    pages[key] = pg
    return pg
end

-- TAB PAGES
local mainPage   = makePage("main", 94, 500)
local aimPage    = makePage("aim", 94, 500)
local auraPage   = makePage("aura", 94, 500)
local gunsPage   = makePage("guns", 94, 500)
local playerPage = makePage("players", 94, 500)

makeTabButton("Main", "main")
makeTabButton("Aim", "aim")
makeTabButton("Aura", "aura")
makeTabButton("Guns", "guns")
makeTabButton("Players", "players")

-- helper: toggle
local function makeToggle(parent, yPos, labelText, key, onEnable, onDisable)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,30)
    row.Position = UDim2.new(0,0,0,yPos)
    row.BackgroundColor3 = THEME.Panel
    row.BorderSizePixel = 0
    row.Parent = parent
    local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0,4); rc.Parent = row
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.7,0,1,0)
    lbl.Position = UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = THEME.Text
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0,24,0,24)
    btn.Position = UDim2.new(1,-32,0.5,-12)
    btn.BackgroundColor3 = cfg[key] and THEME.Green or THEME.GreenDark
    btn.Text = ""
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = row
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0,3); bc.Parent = btn
    btn.MouseButton1Click:Connect(function()
        cfg[key] = not cfg[key]
        btn.BackgroundColor3 = cfg[key] and THEME.Green or THEME.GreenDark
        if cfg[key] then if onEnable then onEnable() end
        else if onDisable then onDisable() end end
    end)
end

-- helper: slider with textbox
local function makeSlider(parent, yPos, label, initialValue, minVal, maxVal, setter, isFloat)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 46)
    row.Position = UDim2.new(0, 0, 0, yPos)
    row.BackgroundColor3 = THEME.Panel
    row.BorderSizePixel = 0
    row.Parent = parent
    local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 4); rc.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -80, 0, 16)
    lbl.Position = UDim2.new(0, 10, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = THEME.Text
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(0, 60, 0, 20)
    textBox.Position = UDim2.new(1, -70, 0, 2)
    textBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    textBox.Text = tostring(initialValue)
    textBox.TextColor3 = THEME.Text
    textBox.TextSize = 11
    textBox.Font = Enum.Font.Code
    textBox.BorderSizePixel = 0
    textBox.ClearTextOnFocus = false
    textBox.Parent = row
    local tbc = Instance.new("UICorner"); tbc.CornerRadius = UDim.new(0, 3); tbc.Parent = textBox

    local slider = Instance.new("TextButton")
    slider.Size = UDim2.new(1, -20, 0, 14)
    slider.Position = UDim2.new(0, 10, 0, 26)
    slider.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    slider.Text = ""
    slider.AutoButtonColor = false
    slider.BorderSizePixel = 0
    slider.Parent = row
    local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 3); sc.Parent = slider

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((initialValue - minVal) / (maxVal - minVal), 0, 1, 0)
    fill.BackgroundColor3 = THEME.Green
    fill.BorderSizePixel = 0
    fill.Parent = slider
    local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0, 3); fc.Parent = fill

    local function updateValue(value)
        if isFloat then
            value = math.clamp(value, minVal, maxVal)
        else
            value = math.clamp(math.floor(value), minVal, maxVal)
        end
        textBox.Text = isFloat and string.format("%.3f", value) or tostring(value)
        fill.Size = UDim2.new((value - minVal) / (maxVal - minVal), 0, 1, 0)
        setter(value)
    end

    textBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            local num = tonumber(textBox.Text)
            if num then updateValue(num) else textBox.Text = tostring(initialValue) end
        end
    end)

    slider.MouseButton1Down:Connect(function()
        local function update()
            local mouse = UserInputService:GetMouseLocation()
            local rel = math.clamp((mouse.X - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
            updateValue(minVal + (maxVal - minVal) * rel)
        end
        update()
        local m, e
        m = UserInputService.InputChanged:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseMovement then update() end
        end)
        e = UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then
                m:Disconnect(); e:Disconnect()
            end
        end)
    end)
end

-- helper: dropdown
local function makeDropdown(parent, yPos, label, options, current, setter)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 30)
    row.Position = UDim2.new(0, 0, 0, yPos)
    row.BackgroundColor3 = THEME.Panel
    row.BorderSizePixel = 0
    row.Parent = parent
    local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 4); rc.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.4, 0, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = THEME.Text
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.55, -20, 0, 22)
    btn.Position = UDim2.new(0.45, 0, 0.5, -11)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    btn.Text = current
    btn.TextColor3 = THEME.Text
    btn.TextSize = 11
    btn.Font = Enum.Font.Code
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = row
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 3); bc.Parent = btn

    btn.MouseButton1Click:Connect(function()
        local idx = 1
        for i, o in ipairs(options) do if o == btn.Text then idx = i; break end end
        idx = (idx % #options) + 1
        btn.Text = options[idx]
        setter(options[idx])
    end)
end

-- ============================================================
-- MAIN PAGE
-- ============================================================
makeToggle(mainPage, 6,   "Fly (WASD, Space/Ctrl)", "fly", startFly, stopFly)
makeSlider(mainPage, 40, "Fly Speed", FLY_SPEED, 10, 100, function(v) FLY_SPEED = v end, false)
makeToggle(mainPage, 90,  "Hitbox Extender", "hbe", startHBE, stopHBE)
makeToggle(mainPage, 124, "ESP",             "esp", startESP, stopESP)

-- ============================================================
-- AIM PAGE
-- ============================================================
makeToggle(aimPage, 6, "Enable Aimlock", "aimlock", startAim, stopAim)

makeDropdown(aimPage, 40, "Lock Part", {"Head", "Torso", "Nearest"}, AIM.part, function(v) AIM.part = v end)

makeSlider(aimPage, 80, "Smoothness (0=tight, 1=slow)", AIM.smooth, 0, 0.99, function(v) AIM.smooth = v end, true)

makeSlider(aimPage, 130, "Aim FOV (pixels)", AIM.fov, 50, 1000, function(v) AIM.fov = v end, false)

-- aim whitelist section
local aimWlLabel = Instance.new("TextLabel")
aimWlLabel.Size = UDim2.new(1, 0, 0, 18)
aimWlLabel.Position = UDim2.new(0, 0, 0, 180)
aimWlLabel.BackgroundTransparency = 1
aimWlLabel.Text = "AIM WHITELIST (tap to toggle)"
aimWlLabel.TextColor3 = THEME.TextDim
aimWlLabel.TextSize = 10
aimWlLabel.Font = Enum.Font.Code
aimWlLabel.TextXAlignment = Enum.TextXAlignment.Left
aimWlLabel.Parent = aimPage

local aimWlScroll = Instance.new("ScrollingFrame")
aimWlScroll.Size = UDim2.new(1, 0, 0, 280)
aimWlScroll.Position = UDim2.new(0, 0, 0, 204)
aimWlScroll.BackgroundColor3 = THEME.Panel
aimWlScroll.BorderSizePixel = 0
aimWlScroll.ScrollBarThickness = 3
aimWlScroll.ScrollBarImageColor3 = THEME.Green
aimWlScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
aimWlScroll.Parent = aimPage
local awc = Instance.new("UICorner"); awc.CornerRadius = UDim.new(0, 4); awc.Parent = aimWlScroll
local awl = Instance.new("UIListLayout"); awl.Parent = aimWlScroll; awl.SortOrder = Enum.SortOrder.Name; awl.Padding = UDim.new(0, 2)

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
            b.BackgroundColor3 = isWhitelisted(p) and Color3.fromRGB(145,35,42) or Color3.fromRGB(34,34,34)
            b.Text = (isWhitelisted(p) and "[WL] " or "") .. p.Name
            b.TextColor3 = THEME.Text
            b.TextSize = 11
            b.Font = Enum.Font.Code
            b.TextXAlignment = Enum.TextXAlignment.Left
            b.BorderSizePixel = 0
            b.AutoButtonColor = false
            b.Parent = aimWlScroll
            local bbc = Instance.new("UICorner"); bbc.CornerRadius = UDim.new(0,3); bbc.Parent = b
            local bpad = Instance.new("UIPadding"); bpad.PaddingLeft = UDim.new(0,8); bpad.Parent = b
            b.MouseButton1Click:Connect(function()
                if WHITELIST[p.UserId] then WHITELIST[p.UserId] = nil
                else WHITELIST[p.UserId] = true end
                rebuildAimWhitelist()
                if rebuildPlayerList then rebuildPlayerList() end
            end)
        end
    end
    aimWlScroll.CanvasSize = UDim2.new(0, 0, 0, count * 28 + 4)
end

-- ============================================================
-- AURA PAGE
-- ============================================================
makeToggle(auraPage, 6,   "Proximity Aura",         "aura")
makeToggle(auraPage, 40,  "Kill Everyone in Range", "killAll")
makeToggle(auraPage, 74,  "Show FOV Ring",          "fovRing")
makeToggle(auraPage, 108, "Require Held Weapon",    "auraRequireGun",
    function() AURA.requireGun = true end,
    function() AURA.requireGun = false end)

makeSlider(auraPage, 150, "Aura Radius (studs)", AURA.radius, 10, 300, function(v) AURA.radius = v end, false)

-- ============================================================
-- GUNS PAGE
-- ============================================================
local gunsScroll = Instance.new("ScrollingFrame")
gunsScroll.Size = UDim2.new(1, 0, 0, 500)
gunsScroll.Position = UDim2.new(0, 0, 0, 0)
gunsScroll.BackgroundColor3 = THEME.Panel
gunsScroll.BorderSizePixel = 0
gunsScroll.ScrollBarThickness = 3
gunsScroll.ScrollBarImageColor3 = THEME.Green
gunsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
gunsScroll.Parent = gunsPage
local gsc = Instance.new("UICorner"); gsc.CornerRadius = UDim.new(0, 4); gsc.Parent = gunsScroll
local gsl = Instance.new("UIListLayout"); gsl.Parent = gunsScroll; gsl.Padding = UDim.new(0, 3); gsl.SortOrder = Enum.SortOrder.Name

-- Fire rate multiplier control
local multRow = Instance.new("Frame")
multRow.Size = UDim2.new(1, -8, 0, 60)
multRow.Position = UDim2.new(0, 4, 0, 4)
multRow.BackgroundColor3 = THEME.Panel
multRow.BorderSizePixel = 0
multRow.Parent = gunsScroll
local mrc = Instance.new("UICorner"); mrc.CornerRadius = UDim.new(0, 4); mrc.Parent = multRow

local multLbl = Instance.new("TextLabel")
multLbl.Size = UDim2.new(1, -20, 0, 18)
multLbl.Position = UDim2.new(0, 10, 0, 4)
multLbl.BackgroundTransparency = 1
multLbl.Text = "Fire Rate Multiplier (0.5 = 2x faster)"
multLbl.TextColor3 = THEME.Text
multLbl.TextSize = 11
multLbl.Font = Enum.Font.GothamBold
multLbl.TextXAlignment = Enum.TextXAlignment.Left
multLbl.Parent = multRow

local multBox = Instance.new("TextBox")
multBox.Size = UDim2.new(0, 70, 0, 24)
multBox.Position = UDim2.new(1, -80, 0, 28)
multBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
multBox.Text = tostring(FIRE_MULTIPLIER)
multBox.TextColor3 = THEME.Text
multBox.TextSize = 11
multBox.Font = Enum.Font.Code
multBox.BorderSizePixel = 0
multBox.ClearTextOnFocus = false
multBox.Parent = multRow
local mbc = Instance.new("UICorner"); mbc.CornerRadius = UDim.new(0, 3); mbc.Parent = multBox

local applyBtn = Instance.new("TextButton")
applyBtn.Size = UDim2.new(0, 90, 0, 24)
applyBtn.Position = UDim2.new(0, 10, 0, 28)
applyBtn.BackgroundColor3 = THEME.GreenDark
applyBtn.Text = "Apply All"
applyBtn.TextColor3 = THEME.Text
applyBtn.TextSize = 11
applyBtn.Font = Enum.Font.GothamBold
applyBtn.BorderSizePixel = 0
applyBtn.AutoButtonColor = false
applyBtn.Parent = multRow
local abc = Instance.new("UICorner"); abc.CornerRadius = UDim.new(0, 3); abc.Parent = applyBtn
applyBtn.MouseButton1Click:Connect(function()
    local num = tonumber(multBox.Text)
    if num then
        FIRE_MULTIPLIER = math.clamp(num, 0.01, 10)
        multBox.Text = tostring(FIRE_MULTIPLIER)
        applyAllCooldowns()
    end
end)

-- per-gun rows
for _, gunName in ipairs(GUN_LIST) do
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -8, 0, 54)
    row.BackgroundColor3 = THEME.Panel
    row.BorderSizePixel = 0
    row.Parent = gunsScroll
    local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 4); rc.Parent = row

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
    cdBox.Position = UDim2.new(1, -80, 0, 4)
    cdBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    local currentCD = GUN_COOLDOWNS[gunName] or 0.1
    cdBox.Text = string.format("%.3f", currentCD)
    cdBox.TextColor3 = THEME.Text
    cdBox.TextSize = 11
    cdBox.Font = Enum.Font.Code
    cdBox.BorderSizePixel = 0
    cdBox.ClearTextOnFocus = false
    cdBox.Parent = row
    local cbc = Instance.new("UICorner"); cbc.CornerRadius = UDim.new(0, 3); cbc.Parent = cdBox

    local slider = Instance.new("TextButton")
    slider.Size = UDim2.new(1, -20, 0, 14)
    slider.Position = UDim2.new(0, 10, 0, 32)
    slider.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    slider.Text = ""
    slider.AutoButtonColor = false
    slider.BorderSizePixel = 0
    slider.Parent = row
    local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 3); sc.Parent = slider

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(math.clamp((currentCD - 0.01) / (0.5 - 0.01), 0, 1), 0, 1, 0)
    fill.BackgroundColor3 = THEME.Green
    fill.BorderSizePixel = 0
    fill.Parent = slider
    local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0, 3); fc.Parent = fill

    local function setGunCD(v)
        v = math.clamp(v, 0.01, 0.5)
        GUN_COOLDOWNS[gunName] = v
        cdBox.Text = string.format("%.3f", v)
        fill.Size = UDim2.new((v - 0.01) / (0.5 - 0.01), 0, 1, 0)
        if GunConfigs and GunConfigs[gunName] then
            GunConfigs[gunName].CoolDown = v * FIRE_MULTIPLIER
        end
    end

    cdBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            local num = tonumber(cdBox.Text)
            if num then setGunCD(num) else cdBox.Text = string.format("%.3f", currentCD) end
        end
    end)

    slider.MouseButton1Down:Connect(function()
        local function update()
            local mouse = UserInputService:GetMouseLocation()
            local rel = math.clamp((mouse.X - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
            setGunCD(0.01 + (0.5 - 0.01) * rel)
        end
        update()
        local m, e
        m = UserInputService.InputChanged:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseMovement then update() end
        end)
        e = UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then
                m:Disconnect(); e:Disconnect()
            end
        end)
    end)
end

-- fix canvas size
task.defer(function()
    gunsScroll.CanvasSize = UDim2.new(0, 0, 0, #GUN_LIST * 58 + 80)
end)

-- ============================================================
-- PLAYERS PAGE
-- ============================================================
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1,0,0,500)
scroll.Position = UDim2.new(0,0,0,0)
scroll.BackgroundColor3 = THEME.Panel
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 3
scroll.ScrollBarImageColor3 = THEME.Green
scroll.CanvasSize = UDim2.new(0,0,0,0)
scroll.Parent = playerPage
local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0,4); sc.Parent = scroll
local scrollList = Instance.new("UIListLayout")
scrollList.Parent = scroll
scrollList.SortOrder = Enum.SortOrder.Name
scrollList.Padding = UDim.new(0,2)

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
            b.Size = UDim2.new(1,-8,0,28)
            b.BackgroundColor3 = isWhitelisted(p) and Color3.fromRGB(145,35,42) or Color3.fromRGB(34,34,34)
            b.Text = (isWhitelisted(p) and "[WL] " or "") .. p.Name .. "  [" .. p.DisplayName .. "]"
            b.TextColor3 = THEME.Text
            b.TextSize = 11
            b.Font = Enum.Font.Code
            b.TextXAlignment = Enum.TextXAlignment.Left
            b.BorderSizePixel = 0
            b.AutoButtonColor = false
            b.Parent = scroll
            local bbc = Instance.new("UICorner"); bbc.CornerRadius = UDim.new(0,3); bbc.Parent = b
            local bpad = Instance.new("UIPadding"); bpad.PaddingLeft = UDim.new(0,8); bpad.Parent = b

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
                            if WHITELIST[p.UserId] then
                                WHITELIST[p.UserId] = nil
                            else
                                WHITELIST[p.UserId] = true
                            end
                            rebuildPlayerList()
                            if rebuildAimWhitelist then rebuildAimWhitelist() end
                        end
                    end)
                end
            end)
        end
    end
    scroll.CanvasSize = UDim2.new(0,0,0,count * 30 + 4)
end

rebuildPlayerList()
rebuildAimWhitelist()
Players.PlayerAdded:Connect(function() task.wait(0.5); rebuildPlayerList(); rebuildAimWhitelist() end)
Players.PlayerRemoving:Connect(function() task.wait(0.2); rebuildPlayerList(); rebuildAimWhitelist() end)

-- ============================================================
-- KEY BINDS
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
    end
end)

pages.main.Visible = true

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
end)

print("lel ez scripts")
