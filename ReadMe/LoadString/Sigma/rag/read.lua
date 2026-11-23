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

local AURA = {
    radius   = 60,
    interval = 0.12,
    useHead  = true,
    requireGun = true,
    killAllInterval = 0.25,
}

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
    local best, bestDist = nil, AIM_FOV
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer and not isWhitelisted(p) then
            local char = p.Character
            local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if head and hum and hum.Health > 0 then
                local sp, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d < bestDist then bestDist = d; best = head end
                end
            end
        end
    end
    return best
end

local function startAim()
    aimConn = RunService.RenderStepped:Connect(function()
        if not cfg.aimlock then return end
        local target = findAimTarget()
        if target then
            local goal = CFrame.new(Camera.CFrame.Position, target.Position)
            Camera.CFrame = Camera.CFrame:Lerp(goal, 1 - AIM_SMOOTH)
        end
    end)
end
local function stopAim()
    if aimConn then aimConn:Disconnect(); aimConn = nil end
end

-- ============================================================
-- ESP — Highlight-based (the BoxHandleAdornment wasn't rendering)
-- ============================================================
local espFolder = Instance.new("Folder")
espFolder.Name = "FlyAimESP"
espFolder.Parent = Workspace
local espTracked = {}          -- [player] = { hl, billboard, label }
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
-- FOV RING + RED AURA HIGHLIGHTS
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

-- red aura highlight pool
local auraFolder = Instance.new("Folder")
auraFolder.Name = "AuraRedHL"
auraFolder.Parent = Workspace
local auraHighlights = {}   -- [player] = Highlight

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
    -- project the aura world radius to screen space
    local center = Camera.ViewportSize / 2
    local worldPoint = Camera.CFrame.Position + (Camera.CFrame.RightVector * AURA.radius)
    local screenPoint, onScreen = Camera:WorldToViewportPoint(worldPoint)
    local pixelRadius = math.abs(screenPoint.X - center.X)

    if pixelRadius < 4 then pixelRadius = 4 end
    fovCircle.Visible = true
    fovCircle.Size = UDim2.fromOffset(pixelRadius * 2, pixelRadius * 2)
end

-- aura loop updates highlights + fires
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
                            hl.Adornee = p.Character
                            hl.Enabled = true
                        else
                            hl.Adornee = nil
                            hl.Enabled = false
                        end
                    else
                        hl.Adornee = nil
                        hl.Enabled = false
                    end
                elseif isWhitelisted(p) then
                    local hl = auraHighlights[p]
                    if hl then hl.Adornee = nil; hl.Enabled = false end
                end
            end
        end

        -- aura firing
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

        -- kill-all firing
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
-- UI — bigger panel + tabs
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
main.Size = UDim2.new(0, 420, 0, 640)
main.Position = UDim2.new(0.5, -210, 0.5, -320)
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

-- Minimize/Restore functionality
local minimized = false
local normalSize = UDim2.new(0, 420, 0, 640)

-- Create the restore button (shown when minimized)
local restoreButton = Instance.new("TextButton")
restoreButton.Size = UDim2.new(0, 30, 0, 30)
restoreButton.Position = UDim2.new(0, 0, 0, 0)
restoreButton.BackgroundColor3 = THEME.Green
restoreButton.Text = "+"
restoreButton.TextColor3 = Color3.new(1, 1, 1)
restoreButton.TextSize = 20
restoreButton.BorderSizePixel = 0
restoreButton.Visible = false
restoreButton.Parent = main
local rbcorner = Instance.new("UICorner")
rbcorner.CornerRadius = UDim.new(0, 4)
rbcorner.Parent = restoreButton

local function makeTitleButton(text, xOffset)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 30, 0, 26)
    button.Position = UDim2.new(1, xOffset, 0, 4)
    button.BackgroundColor3 = THEME.PanelAlt
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = THEME.Text
    button.TextSize = 15
    button.Font = Enum.Font.GothamBold
    button.AutoButtonColor = true
    button.Parent = main
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button
    return button
end

local sizeButton = makeTitleButton("□", -70)
local minimizeButton = makeTitleButton("−", -36)

sizeButton.MouseButton1Click:Connect(function()
    -- Placeholder for future size functionality if needed
end)

minimizeButton.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        -- Hide all elements and shrink frame
        title.Visible = false
        keyHint.Visible = false
        tabBar.Visible = false
        for _, page in pairs(pages) do page.Visible = false end
        main.Size = UDim2.new(0, 30, 0, 30)
        minimizeButton.Visible = false
        sizeButton.Visible = false
        restoreButton.Visible = true
    else
        -- Show all elements and restore frame
        title.Visible = true
        keyHint.Visible = true
        tabBar.Visible = true
        for _, page in pairs(pages) do page.Visible = (page == pages[activeTab]) end
        main.Size = normalSize
        minimizeButton.Visible = true
        sizeButton.Visible = true
        restoreButton.Visible = false
    end
end)

restoreButton.MouseButton1Click:Connect(function()
    minimized = false
    title.Visible = true
    keyHint.Visible = true
    tabBar.Visible = true
    for _, page in pairs(pages) do page.Visible = (page == pages[activeTab]) end
    main.Size = normalSize
    minimizeButton.Visible = true
    sizeButton.Visible = true
    restoreButton.Visible = false
end)


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
    b.Size = UDim2.new(0, 90, 0, 24)
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
local mainPage   = makePage("main", 94, 420)
local auraPage   = makePage("aura", 94, 420)
local playerPage = makePage("players", 94, 420)

makeTabButton("Main", "main")
makeTabButton("Aura", "aura")
makeTabButton("Players", "players")

-- helper: toggle row
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

-- helper: slider with textbox for numeric values
local function makeSliderWithTextbox(parent, yPos, label, initialValue, minVal, maxVal, setterCallback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 50)
    row.Position = UDim2.new(0, 0, 0, yPos)
    row.BackgroundColor3 = THEME.Panel
    row.BorderSizePixel = 0
    row.Parent = parent
    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0, 4)
    rc.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -10, 0, 18)
    lbl.Position = UDim2.new(0, 10, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = THEME.Text
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    -- Textbox for direct input
    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(0, 60, 0, 20)
    textBox.Position = UDim2.new(1, -70, 0, 26)
    textBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    textBox.Text = tostring(initialValue)
    textBox.TextColor3 = THEME.Text
    textBox.TextSize = 12
    textBox.Font = Enum.Font.Code
    textBox.BorderSizePixel = 0
    textBox.ClearTextOnFocus = false
    textBox.Parent = row
    local tbc = Instance.new("UICorner")
    tbc.CornerRadius = UDim.new(0, 3)
    tbc.Parent = textBox

    -- Slider
    local slider = Instance.new("TextButton")
    slider.Size = UDim2.new(1, -80, 0, 20)
    slider.Position = UDim2.new(0, 10, 0, 26)
    slider.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    slider.Text = ""
    slider.AutoButtonColor = false
    slider.BorderSizePixel = 0
    slider.Parent = row
    local sc = Instance.new("UICorner")
    sc.CornerRadius = UDim.new(0, 3)
    sc.Parent = slider

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((initialValue - minVal) / (maxVal - minVal), 0, 1, 0)
    fill.BackgroundColor3 = THEME.Green
    fill.BorderSizePixel = 0
    fill.Parent = slider
    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(0, 3)
    fc.Parent = fill

    local function updateValue(value)
        value = math.clamp(math.floor(value), minVal, maxVal)
        textBox.Text = tostring(value)
        fill.Size = UDim2.new((value - minVal) / (maxVal - minVal), 0, 1, 0)
        if setterCallback then setterCallback(value) end
    end

    textBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            local num = tonumber(textBox.Text)
            if num then
                updateValue(num)
            else
                textBox.Text = tostring(initialValue) -- Revert on invalid input
            end
        end
    end)

    slider.MouseButton1Down:Connect(function(input)
        local function update()
            local mouse = UserInputService:GetMouseLocation()
            local rel = math.clamp((mouse.X - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
            local value = minVal + (maxVal - minVal) * rel
            updateValue(value)
        end
        update()
        local moveConnection, releaseConnection
        moveConnection = UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                update()
            end
        end)
        releaseConnection = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                moveConnection:Disconnect()
                releaseConnection:Disconnect()
            end
        end)
    end)
end

-- Main page
makeToggle(mainPage, 6,   "Fly (WASD, Space/Ctrl)", "fly", startFly, stopFly)
makeSliderWithTextbox(mainPage, 40, "Fly Speed", FLY_SPEED, 10, 100, function(value) FLY_SPEED = value end)
makeToggle(mainPage, 100,  "Hitbox Extender",         "hbe", startHBE, stopHBE)
makeToggle(mainPage, 134,  "Aim Lock",                "aimlock", startAim, stopAim)
makeToggle(mainPage, 168, "ESP",                     "esp", startESP, stopESP)

-- Aura page
makeToggle(auraPage, 6,   "Proximity Aura",          "aura")
makeToggle(auraPage, 40,  "Kill Everyone in Range",  "killAll")
makeToggle(auraPage, 74,  "Show FOV Ring",           "fovRing")
makeToggle(auraPage, 108, "Require Held Weapon",     "auraRequireGun",
    function() AURA.requireGun = true end,
    function() AURA.requireGun = false end)
-- aura radius slider
local radiusLabel = Instance.new("TextLabel")
radiusLabel.Size = UDim2.new(1,0,0,18)
radiusLabel.Position = UDim2.new(0,0,0,214)
radiusLabel.BackgroundTransparency = 1
radiusLabel.Text = "Aura Radius: " .. AURA.radius .. " studs"
radiusLabel.TextColor3 = THEME.TextDim
radiusLabel.TextSize = 10
radiusLabel.Font = Enum.Font.Code
radiusLabel.TextXAlignment = Enum.TextXAlignment.Left
radiusLabel.Parent = auraPage

local radiusSlider = Instance.new("TextButton")
radiusSlider.Size = UDim2.new(1,0,0,22)
radiusSlider.Position = UDim2.new(0,0,0,234)
radiusSlider.BackgroundColor3 = Color3.fromRGB(40,40,40)
radiusSlider.Text = ""
radiusSlider.AutoButtonColor = false
radiusSlider.BorderSizePixel = 0
radiusSlider.Parent = auraPage
local rsc = Instance.new("UICorner"); rsc.CornerRadius = UDim.new(0,3); rsc.Parent = radiusSlider

local radiusFill = Instance.new("Frame")
radiusFill.Size = UDim2.new((AURA.radius-10)/(300-10), 0, 1, 0)
radiusFill.BackgroundColor3 = THEME.Red
radiusFill.BorderSizePixel = 0
radiusFill.Parent = radiusSlider
local rfc = Instance.new("UICorner"); rfc.CornerRadius = UDim.new(0,3); rfc.Parent = radiusFill

radiusSlider.MouseButton1Down:Connect(function()
    local function update()
        local mouse = UserInputService:GetMouseLocation()
        local rel = math.clamp((mouse.X - radiusSlider.AbsolutePosition.X) / radiusSlider.AbsoluteSize.X, 0, 1)
        local newRadius = math.floor(10 + (300-10) * rel)
        AURA.radius = newRadius
        radiusFill.Size = UDim2.new(rel, 0, 1, 0)
        radiusLabel.Text = "Aura Radius: " .. newRadius .. " studs"
    end
    update()
    local moveConn
    moveConn = UserInputService.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement then update() end
    end)
    local endConn
    endConn = UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            moveConn:Disconnect(); endConn:Disconnect()
        end
    end)
end)

-- ============================================================
-- PLAYER LIST — tap = whitelist, double click = TP
-- ============================================================
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1,0,0,400)
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

local function rebuildPlayerList()
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
                    -- double click → TP
                    lastClick[p.UserId] = 0
                    tpToPlayer(p)
                else
                    -- single click → whitelist toggle (after a short delay so it
                    -- doesn't fire before a potential second click)
                    lastClick[p.UserId] = now
                    task.delay(DOUBLE_CLICK_WINDOW + 0.02, function()
                        if lastClick[p.UserId] == now then
                            if WHITELIST[p.UserId] then
                                WHITELIST[p.UserId] = nil
                            else
                                WHITELIST[p.UserId] = true
                            end
                            rebuildPlayerList()
                        end
                    end)
                end
            end)
        end
    end
    scroll.CanvasSize = UDim2.new(0,0,0,count * 30 + 4)
end

rebuildPlayerList()
Players.PlayerAdded:Connect(function() task.wait(0.5); rebuildPlayerList() end)
Players.PlayerRemoving:Connect(function() task.wait(0.2); rebuildPlayerList() end)

-- ============================================================
-- KEY BINDS
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
    end
end)

-- show main tab by default
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

print("ur my ***** nigg")
