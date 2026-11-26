-- Hey, if you're readying this, you're prolly gay, smirky wirky, I'm gonna put a broken script below, okay.
--MADE BY G.U.A.R.D.I.A.N
-- Xenon v2.5 | zombie farm — draggable minimized rectangle, ground mode, anti-afk, zombie census
if not game:IsLoaded() then game.Loaded:Wait() end

local HUB_NAME = "Xenon"
local HUB_SUBTITLE = "A generalized Zombie attack farm"

local SecretHub = loadstring(game:HttpGet("https://gist.githubusercontent.com/powelleshon-max/355cfd6b683dc04a1a6f41d74646f9b4/raw/989b58d4eb2b7d3f57c3c55d1569536209e9d85f/Asdsadas"))()

-- THEME — red / black / grey
SecretHub.Config.Title    = HUB_NAME
SecretHub.Config.SubTitle = "v2.5"
SecretHub.Config.Accent   = Color3.fromRGB(220, 50, 50)      -- red
SecretHub.Config.Accent2  = Color3.fromRGB(140, 30, 30)      -- dark red
SecretHub.Config.Warn     = Color3.fromRGB(220, 180, 100)    -- amber
SecretHub.Config.Danger   = Color3.fromRGB(255, 70, 70)      -- bright red
SecretHub.Config.BgMain   = Color3.fromRGB(10, 10, 10)       -- near black
SecretHub.Config.BgPanel  = Color3.fromRGB(18, 18, 18)       -- dark grey
SecretHub.Config.BgSidebar= Color3.fromRGB(6, 6, 6)          -- black
SecretHub.Config.BgCard   = Color3.fromRGB(26, 26, 26)       -- grey
SecretHub.Config.Text     = Color3.fromRGB(225, 225, 225)    -- near white
SecretHub.Config.TextDim  = Color3.fromRGB(140, 140, 140)    -- grey

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

-- SAFE LocalPlayer
local LocalPlayer
do
    local t0 = tick()
    while not LocalPlayer and tick() - t0 < 30 do
        LocalPlayer = Players.LocalPlayer
        if not LocalPlayer then task.wait(0.1) end
    end
    if not LocalPlayer then error("[Xenon] LocalPlayer never appeared after 30s") end
end
print("[Xenon] LocalPlayer ready:", LocalPlayer.Name)

-- REBRAND (patch title label)
task.spawn(function()
    local pg = LocalPlayer:WaitForChild("PlayerGui", 5)
    local cg = game:GetService("CoreGui")
    for _ = 1, 60 do
        local gui = (pg and pg:FindFirstChild("gameUI")) or (cg and cg:FindFirstChild("gameUI"))
        if gui then
            for _, d in ipairs(gui:GetDescendants()) do
                if d:IsA("TextLabel") and (d.Text == "X1nex Hub" or d.Text:find("X1nex")) then
                    d.Text = HUB_NAME
                    d:GetPropertyChangedSignal("Text"):Connect(function()
                        if d.Text ~= HUB_NAME and d.Text:find("X1nex") then d.Text = HUB_NAME end
                    end)
                end
            end
            return
        end
        task.wait(0.1)
    end
end)

-- ============================================================
-- PATCH MINIMIZED BUTTON → draggable rectangle (red/black/grey)
-- ============================================================
task.spawn(function()
    local pg = LocalPlayer:WaitForChild("PlayerGui", 5)
    local cg = game:GetService("CoreGui")

    local gui = nil
    for _ = 1, 60 do
        gui = (pg and pg:FindFirstChild("gameUI")) or (cg and cg:FindFirstChild("gameUI"))
        if gui then break end
        task.wait(0.1)
    end
    if not gui then
        warn("[Xenon] gameUI never appeared — minimized button patch skipped")
        return
    end

    local openBtn = nil
    for _, d in ipairs(gui:GetChildren()) do
        if d:IsA("TextButton") and (d.Text == "⬡" or d.Text == "◈" or d.Text == "◉") then
            openBtn = d
            break
        end
    end
    if not openBtn then
        for _, d in ipairs(gui:GetChildren()) do
            if d:IsA("TextButton") and d.Position.Y.Offset < 80 then
                openBtn = d
                break
            end
        end
    end
    if not openBtn then
        warn("[Xenon] OpenBtn not found — minimized button patch skipped")
        return
    end

    openBtn.Size = UDim2.new(0, 280, 0, 54)
    openBtn.Position = UDim2.new(0, 20, 0, 20)
    openBtn.Text = ""
    openBtn.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    openBtn.BackgroundTransparency = 0.05
    openBtn.AutoButtonColor = false
    openBtn.Active = true
    openBtn.ClipsDescendants = true

    for _, c in ipairs(openBtn:GetChildren()) do
        if c:IsA("UICorner") or c:IsA("UIStroke") or c:IsA("Frame") or c:IsA("TextLabel") then
            c:Destroy()
        end
    end

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = openBtn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(200, 50, 50)
    stroke.Thickness = 1
    stroke.Transparency = 0.45
    stroke.Parent = openBtn

    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(0, 3, 1, 0)
    accent.Position = UDim2.new(0, 0, 0, 0)
    accent.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    accent.BorderSizePixel = 0
    accent.Parent = openBtn
    local acc = Instance.new("UICorner")
    acc.CornerRadius = UDim.new(0, 2)
    acc.Parent = accent

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -22, 0, 24)
    titleLbl.Position = UDim2.new(0, 16, 0, 6)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = HUB_NAME
    titleLbl.TextColor3 = Color3.fromRGB(225, 225, 225)
    titleLbl.TextSize = 15
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = openBtn

    local subLbl = Instance.new("TextLabel")
    subLbl.Size = UDim2.new(1, -22, 0, 16)
    subLbl.Position = UDim2.new(0, 16, 0, 30)
    subLbl.BackgroundTransparency = 1
    subLbl.Text = HUB_SUBTITLE
    subLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
    subLbl.TextSize = 10
    subLbl.Font = Enum.Font.Gotham
    subLbl.TextXAlignment = Enum.TextXAlignment.Left
    subLbl.Parent = openBtn

    local dragging = false
    local dragStart = nil
    local startPos = nil

    openBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = openBtn.Position
            openBtn.Active = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - dragStart
        openBtn.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false
                task.wait(0.15)
                openBtn.Active = true
            end
        end
    end)

    print("[Xenon] minimized button patched (draggable rectangle)")
end)

-- CONFIG
local FIRE_AUTO   = 0.05
local FIRE_SINGLE = 0.35
local FIRE_CUSTOM = 0.10
local AttackDelay = FIRE_AUTO

local HOVER_HEIGHT = _G.__XenonHoverHeight or 25
local HOVER_HORIZONTAL_OFFSET = 0
local TP_INTERVAL = 0.2

-- Ground mode tuning
local GROUND_NEAR_DIST = _G.__XenonGroundNear or 12
local GROUND_FAR_DIST  = _G.__XenonGroundFar  or 22
local GROUND_STEP      = 0.20
local GROUND_SIDESTEP  = 6

local Mode = "Air"

local AimbotEnabled = false
local CurrentTarget = nil
local MaxDistance = 5000
local deadTargets = {}
local lastFireAt = 0
local lastTPAt = 0
local lastGroundAt = 0
local lastGroundDir = nil
local hoverBody = nil

-- ANTI-AFK
local AntiAfkEnabled = false
local antiAfkConn = nil

local function startAntiAfk()
    if antiAfkConn then return end
    antiAfkConn = LocalPlayer.Idled:Connect(function()
        if not AntiAfkEnabled then return end
        VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end)
end

local function stopAntiAfk()
    if antiAfkConn then
        pcall(function() antiAfkConn:Disconnect() end)
        antiAfkConn = nil
    end
end

-- DEATH PROTECTOR
local ProtectEnabled = _G.__XenonProtectEnabled or false
local PROTECT_LOW_PCT  = _G.__XenonProtectLow  or 25
local PROTECT_HIGH_PCT = _G.__XenonProtectHigh or 75
local PROTECT_TP_HEIGHT = _G.__XenonProtectTP   or 250
local protectActive = false
local protectAnchor = nil
local protectBody = nil

-- REMOTES
local GunRemote = ReplicatedStorage:WaitForChild("Gun", 10)
if not GunRemote then warn("[Xenon] Gun remote not found") end

local CommunicationF = nil
task.spawn(function()
    local container = ReplicatedStorage:WaitForChild("RemoteEventContainer", 30)
    if not container then warn("[Xenon] RemoteEventContainer never loaded"); return end
    local comm = container:WaitForChild("CommunicationF", 15)
    if not comm then warn("[Xenon] CommunicationF never loaded"); return end
    CommunicationF = comm
    print("[Xenon] CommunicationF ready:", comm:GetFullName())
end)

-- MONEY
local function getCurrentMoney()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if not ls then return nil end
    local cash = ls:FindFirstChild("Cash")
    if not cash then return nil end
    return cash.Value
end

-- NPC DETECTION
local function IsNPCAlive(npc)
    if not npc or not npc.Parent or not npc:IsDescendantOf(workspace) then return false end
    local hum = npc:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    if hum.Health <= 0 then return false end
    if hum:GetState() == Enum.HumanoidStateType.Dead then return false end
    local hrp = npc:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    if hrp.Position.Y < -10 then return false end
    local animator = hum:FindFirstChildOfClass("Animator")
    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            if track.Animation then
                local id = track.Animation.AnimationId:lower()
                if id:find("death") or id:find("die") then return false end
            end
        end
    end
    return true
end

local function MarkDead(npc)
    if npc then
        deadTargets[npc] = true
        task.delay(15, function() deadTargets[npc] = nil end)
    end
end

local function IsNPC(obj)
    if not obj:IsA("Model") then return false end
    if deadTargets[obj] then return false end
    local hrp = obj:FindFirstChild("HumanoidRootPart")
    local hum = obj:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return false end
    if not IsNPCAlive(obj) then MarkDead(obj); return false end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character == obj then return false end
        if plr.Character and obj:IsDescendantOf(plr.Character) then return false end
    end
    return true
end

local function sweepDeadTargets()
    for npc in pairs(deadTargets) do
        if not npc.Parent or not npc:IsDescendantOf(workspace) then
            deadTargets[npc] = nil
        else
            local hum = npc:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > hum.MaxHealth * 0.5 and hum:GetState() ~= Enum.HumanoidStateType.Dead then
                deadTargets[npc] = nil
            end
        end
    end
end

local function GetNearestNPC()
    local char = LocalPlayer.Character
    if not char then return nil end
    local myPos = char:GetPivot().Position
    local nearest, nearestDist = nil, MaxDistance
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj ~= char and not deadTargets[obj] and IsNPC(obj) then
            local hrp = obj:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (myPos - hrp.Position).Magnitude
                if d < nearestDist then nearestDist = d; nearest = obj end
            end
        end
    end
    return nearest
end

-- TOOL / FIRE
local function GetEquippedTool()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Tool")
end

local function EquipBestTool()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not hum or not backpack then return end
    local current = char:FindFirstChildOfClass("Tool")
    if current and current.Name ~= "Knife" then return end
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") and item.Name ~= "Knife" then hum:EquipTool(item); return end
    end
end

local function FireGunAt(npc)
    if not GunRemote then return end
    local head = npc and npc:FindFirstChild("Head")
    if not head then return end
    local tool = GetEquippedTool()
    if not tool or tool.Name == "Knife" then
        EquipBestTool()
        tool = GetEquippedTool()
        if not tool or tool.Name == "Knife" then return end
    end
    pcall(function()
        GunRemote:FireServer({
            Normal    = Vector3.new(0, 1, 0),
            Direction = head.Position,
            Name      = tool.Name,
            Hit       = head,
            Origin    = head.Position,
            Pos       = head.Position,
        })
    end)
end

-- HOVER / TP
local function stopHover()
    if hoverBody then pcall(function() hoverBody:Destroy() end); hoverBody = nil end
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = false; hum.WalkSpeed = 16; hum.JumpPower = 50; hum.AutoRotate = true end
end

local function updateHover(npc)
    if not npc or deadTargets[npc] or not IsNPCAlive(npc) then stopHover(); return end
    local char = LocalPlayer.Character
    if not char then stopHover(); return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    local head = npc:FindFirstChild("Head")
    if not hrp or not hum or not head then stopHover(); return end
    local desired = Vector3.new(head.Position.X + HOVER_HORIZONTAL_OFFSET, head.Position.Y + HOVER_HEIGHT, head.Position.Z)
    if not hoverBody or hoverBody.Parent ~= hrp then
        if hoverBody then pcall(function() hoverBody:Destroy() end) end
        hoverBody = Instance.new("BodyPosition")
        hoverBody.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        hoverBody.P = 15000; hoverBody.D = 1500
        hoverBody.Position = desired; hoverBody.Parent = hrp
    else
        hoverBody.Position = desired
    end
    hum.PlatformStand = true; hum.WalkSpeed = 0; hum.JumpPower = 0; hum.AutoRotate = false
end

local function tpAbove(npc)
    if not npc or deadTargets[npc] or not IsNPCAlive(npc) then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    local head = npc:FindFirstChild("Head")
    if not hrp or not hum or not head then return end
    local target = Vector3.new(head.Position.X + HOVER_HORIZONTAL_OFFSET, head.Position.Y + HOVER_HEIGHT, head.Position.Z)
    hum.PlatformStand = true; hum.WalkSpeed = 0; hum.JumpPower = 0
    hrp.CFrame = CFrame.new(target, head.Position)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
end

-- ============================================================
-- GROUND MODE
-- ============================================================
local GROUND_NEAR_DIST  = _G.__XenonGroundNear or 12
local GROUND_FAR_DIST   = _G.__XenonGroundFar  or 22
local GROUND_STEP       = 0.20
local GROUND_SIDESTEP   = 6
local GROUND_RAY_LEN    = 6
local GROUND_JUMP_MAX   = 6

local lastGroundDir     = nil
local lastJumpAt        = 0
local stuckTimer        = 0
local lastPos           = nil

local function makeRayParams(char)
    local p = RaycastParams.new()
    p.FilterType = Enum.RaycastFilterType.Exclude
    p.FilterDescendantsInstances = { char }
    p.IgnoreWater = true
    return p
end

local function probe(hrp, char, dir, length)
    local params = makeRayParams(char)
    local origin = hrp.Position + Vector3.new(0, 0, 0)
    return workspace:Raycast(origin, dir.Unit * length, params)
end

local function classifyDir(hrp, char, dir, length)
    local hit = probe(hrp, char, dir, length)
    if not hit then return "clear", nil end
    if hit.Instance then
        local size = hit.Instance.Size
        local height = hit.Position.Y - hrp.Position.Y + (size.Y * 0.5)
        if height <= GROUND_JUMP_MAX and height > 0.5 then
            return "jump", hit
        end
    end
    return "blocked", hit
end

local function chooseDirection(hrp, char, desiredDir)
    local angles = { 0, 30, -30, 60, -60 }
    local bestDir, bestScore, bestAction = nil, -math.huge, "blocked"

    for _, deg in ipairs(angles) do
        local rad = math.rad(deg)
        local rotated = Vector3.new(
            desiredDir.X * math.cos(rad) - desiredDir.Z * math.sin(rad),
            0,
            desiredDir.X * math.sin(rad) + desiredDir.Z * math.cos(rad)
        )
        local action, hit = classifyDir(hrp, char, rotated, GROUND_RAY_LEN)

        local score
        if action == "clear" then
            score = 100 - math.abs(deg) * 0.5
        elseif action == "jump" then
            score = 60 - math.abs(deg) * 0.5
        else
            local dist = hit and (hit.Position - hrp.Position).Magnitude or 0
            score = dist - math.abs(deg) * 0.1
        end

        if score > bestScore then
            bestScore = score
            bestDir = rotated
            bestAction = action
        end
    end

    return bestDir or desiredDir, bestAction
end

local function slideAlong(hrp, char, desiredDir)
    local params = makeRayParams(char)
    local origin = hrp.Position
    local hit = workspace:Raycast(origin, desiredDir.Unit * GROUND_RAY_LEN, params)
    if not hit or not hit.Normal then return desiredDir end
    local slide = (desiredDir - hit.Normal * desiredDir:Dot(hit.Normal))
    if slide.Magnitude < 0.01 then
        slide = hit.Normal:Cross(Vector3.yAxis)
    end
    return slide.Unit
end

local function groundStep(npc)
    local char = LocalPlayer.Character
    if not char then stopHover(); return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end
    local head = npc:FindFirstChild("Head")
    if not head then return end

    hum.PlatformStand = false
    hum.WalkSpeed = 20
    hum.AutoRotate = true

    local myPos = hrp.Position
    local targetPos = head.Position
    local flatDelta = Vector3.new(targetPos.X - myPos.X, 0, targetPos.Z - myPos.Z)
    local dist = flatDelta.Magnitude
    if dist < 0.01 then return end

    local desiredDir = flatDelta.Unit

    if lastPos and (myPos - lastPos).Magnitude < 0.5 then
        stuckTimer += GROUND_STEP
    else
        stuckTimer = 0
    end
    lastPos = myPos

    local now = tick()

    if dist > GROUND_FAR_DIST then
        local moveDir, action = chooseDirection(hrp, char, desiredDir)
        if action == "clear" then
            hum:MoveTo(myPos + moveDir * 8)
            lastGroundDir = nil
        elseif action == "jump" then
            if now - lastJumpAt > 0.6 then
                hum.Jump = true
                lastJumpAt = now
            end
            hum:MoveTo(myPos + moveDir * 8)
        else
            local slide = slideAlong(hrp, char, desiredDir)
            hum:MoveTo(myPos + slide * GROUND_SIDESTEP)
            lastGroundDir = slide
        end
        if stuckTimer > 1.5 then
            hum.Jump = true
            local side = lastGroundDir or Vector3.new(1, 0, 0)
            hum:MoveTo(myPos + side * (GROUND_SIDESTEP * 2))
            stuckTimer = 0
        end
    elseif dist < GROUND_NEAR_DIST then
        local away = -desiredDir
        local moveDir, action = chooseDirection(hrp, char, away)
        if action == "blocked" then
            moveDir = slideAlong(hrp, char, away)
        end
        hum:MoveTo(myPos + moveDir * 6)
    else
        hum:MoveTo(myPos)
    end

    hrp.CFrame = CFrame.lookAt(myPos, Vector3.new(targetPos.X, myPos.Y, targetPos.Z))
end

-- DEATH PROTECTOR
local function enterProtection(hrp, hum)
    if protectActive then return end
    protectActive = true
    protectAnchor = hrp.Position + Vector3.new(0, PROTECT_TP_HEIGHT, 0)
    print(string.format("[Xenon] Death protect ON — health %.0f%%", hum.Health / math.max(hum.MaxHealth,1) * 100))
    if hoverBody then pcall(function() hoverBody:Destroy() end); hoverBody = nil end
    if protectBody then pcall(function() protectBody:Destroy() end) end
    protectBody = Instance.new("BodyPosition")
    protectBody.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    protectBody.P = 25000; protectBody.D = 3000
    protectBody.Position = protectAnchor
    protectBody.Parent = hrp
    hum.PlatformStand = true
    hum.WalkSpeed = 0
    hum.JumpPower = 0
    hum.AutoRotate = false
    SecretHub.Notify(HUB_NAME, "Death protect: floating to safety", "warn")
end

local function exitProtection(hrp, hum)
    if not protectActive then return end
    protectActive = false
    protectAnchor = nil
    if protectBody then pcall(function() protectBody:Destroy() end); protectBody = nil end
    hum.PlatformStand = false
    hum.WalkSpeed = 16
    hum.JumpPower = 50
    hum.AutoRotate = true
    print(string.format("[Xenon] Death protect OFF — health %.0f%%", hum.Health / math.max(hum.MaxHealth,1) * 100))
    SecretHub.Notify(HUB_NAME, "Death protect: recovered", "success")
end

task.spawn(function()
    while true do
        task.wait(0.1)
        if not ProtectEnabled then
            if protectActive then
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hrp and hum then exitProtection(hrp, hum) end
            end
            continue
        end
        local char = LocalPlayer.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then continue end
        local pct = hum.Health / math.max(hum.MaxHealth, 1) * 100
        if not protectActive then
            if pct <= PROTECT_LOW_PCT then enterProtection(hrp, hum) end
        else
            if protectBody then protectBody.Position = protectAnchor end
            hrp.CFrame = CFrame.new(protectAnchor)
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            if pct >= PROTECT_HIGH_PCT then exitProtection(hrp, hum) end
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    protectActive = false
    protectBody = nil
    protectAnchor = nil
    hoverBody = nil
    lastGroundDir = nil
end)

-- MAIN LOOP
local function mainLoop()
    while AimbotEnabled do
        local now = tick()
        if protectActive then task.wait(0.2); continue end
        if CurrentTarget and not IsNPCAlive(CurrentTarget) then
            local hum = CurrentTarget:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and hum:GetState() ~= Enum.HumanoidStateType.Dead then
                -- still alive
            else
                MarkDead(CurrentTarget)
                CurrentTarget = nil
                if Mode ~= "Ground" then stopHover() end
            end
        end
        sweepDeadTargets()
        local npc = GetNearestNPC()
        if npc then
            CurrentTarget = npc
            if Mode == "Air" then
                updateHover(npc)
            elseif Mode == "TP" then
                if now - lastTPAt >= TP_INTERVAL then lastTPAt = now; tpAbove(npc) end
            elseif Mode == "Ground" then
                if now - lastGroundAt >= GROUND_STEP then lastGroundAt = now; groundStep(npc) end
            end
            if now - lastFireAt >= AttackDelay then
                lastFireAt = now
                local hum = npc:FindFirstChildOfClass("Humanoid")
                FireGunAt(npc)
                if hum and hum.Health > 0 and hum.Health < (hum.MaxHealth * 0.05) then
                    task.delay(AttackDelay, function()
                        if npc and npc.Parent and IsNPCAlive(npc) then
                            FireGunAt(npc)
                        end
                    end)
                end
            end
        else
            CurrentTarget = nil
            if Mode ~= "Ground" then stopHover() end
        end
        task.wait(0.02)
    end
    stopHover()
end

-- AUTOBUY
local GUNS = {
    { name = "Pistol",          price = 0 },
    { name = "Revolver",        price = 250 },
    { name = "Uzi",             price = 600 },
    { name = "Trench Shotgun",  price = 950 },
    { name = "M1 Garand",       price = 1250 },
    { name = "Type 100",        price = 2000 },
    { name = "M16",             price = 3000 },
    { name = "Sniper",          price = 4000 },
    { name = "Tatical Shotgun", price = 5000 },
    { name = "Thompson",        price = 7500 },
    { name = "Blaster",         price = 8500 },
    { name = "Machine Gun",     price = 9500 },
    { name = "Cobra",           price = 12500 },
    { name = "Fiery Cannon",    price = 15000 },
    { name = "Toxic",           price = 17500 },
    { name = "Retribution Ray", price = 20000 },
    { name = "Platinum Gun",    price = 23000 },
    { name = "Scope Rifle",     price = 24000 },
    { name = "Space Gun",       price = 26000 },
    { name = "Railgun",         price = 28000 },
    { name = "Ghost",           price = 31000 },
    { name = "Alien Rifle",     price = 35000 },
    { name = "Ray Gun",         price = 38000 },
    { name = "Annihilator",     price = 40000 },
    { name = "Biohazard",       price = 43000 },
    { name = "Venom",           price = 45000 },
    { name = "Golden Pistol",   price = 50000 },
    { name = "Rainbow Blaster", price = 65000 },
    { name = "Hex Spitter",     price = 80000 },
    { name = "Beam Launcher",   price = 90000 },
    { name = "Gatling Laser",   price = 100000 },
    { name = "Tri Laser",       price = 150000 },
    { name = "Techno Rifle",    price = 200000 },
    { name = "Minigun",         price = 500000 },
}

local function findGunIndex(gunName)
    if not gunName or gunName == "" then return nil end
    for i, g in ipairs(GUNS) do if g.name == gunName then return i end end
    local lower = string.lower(gunName)
    for i, g in ipairs(GUNS) do if string.lower(g.name) == lower then return i end end
    for i, g in ipairs(GUNS) do
        local gn = string.lower(g.name)
        if gn:find(lower, 1, true) or lower:find(gn, 1, true) then return i end
    end
    return nil
end

local function getEquippedGunName()
    local char = LocalPlayer.Character
    if not char then return nil end
    for _, c in ipairs(char:GetChildren()) do
        if c:IsA("Tool") and c.Name ~= "Knife" and c.Name ~= "Handcuffs" then return c.Name end
    end
    return nil
end

local autobuyFloorIndex = _G.__XenonAutobuyFloor or 1

local function refreshAutobuyFloor()
    local equipped = getEquippedGunName()
    local idx = findGunIndex(equipped)
    if idx and idx > autobuyFloorIndex then
        autobuyFloorIndex = idx
        _G.__XenonAutobuyFloor = idx
        return idx, equipped
    end
    if not _G.__XenonAutobuyFloor and idx then
        autobuyFloorIndex = idx
        _G.__XenonAutobuyFloor = idx
        return idx, equipped
    end
    return autobuyFloorIndex, equipped
end

local AutoBuyEnabled = false
local AUTOBUY_INTERVAL = 5
local lastBuyAt = 0
local buyAttempts = {}
local buyLog = {}
local buyLogSize = 8

local function logBuy(msg)
    table.insert(buyLog, 1, msg)
    while #buyLog > buyLogSize do table.remove(buyLog) end
end

local function tryBuyGun(gunName)
    if not CommunicationF then return false, "no remote" end
    local ok, result = pcall(function()
        return CommunicationF:InvokeServer("BuyItem_Cash", gunName)
    end)
    if not ok then return false, "error: " .. tostring(result) end
    return true, result
end

local function tryEquipGun(gunName)
    if not CommunicationF then return false, "no remote" end
    local ok, result = pcall(function()
        return CommunicationF:InvokeServer("EquipItem", gunName)
    end)
    return ok, result
end

local function autobuyTick()
    if not AutoBuyEnabled or not CommunicationF then return end
    local now = tick()
    if now - lastBuyAt < AUTOBUY_INTERVAL then return end
    lastBuyAt = now
    refreshAutobuyFloor()

    local money = getCurrentMoney()
    if not money then return end

    for i = autobuyFloorIndex + 1, #GUNS do
        local gun = GUNS[i]
        if money < gun.price then break end
        local lastTry = buyAttempts[gun.name]
        if not lastTry or (now - lastTry) > 30 then
            local ok, response = tryBuyGun(gun.name)
            buyAttempts[gun.name] = now
            local label = gun.name .. " -> " .. tostring(response)
            logBuy(label)
            if ok then
                local okEq, eqRes = tryEquipGun(gun.name)
                logBuy("equip " .. gun.name .. " -> " .. tostring(eqRes))
                SecretHub.Notify(HUB_NAME, "Buy: " .. label, "success")
                refreshAutobuyFloor()
                return
            end
        end
    end
end

task.spawn(function()
    while true do
        task.wait(1)
        pcall(autobuyTick)
    end
end)

task.spawn(function()
    task.wait(2)
    pcall(refreshAutobuyFloor)
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1.5)
    pcall(refreshAutobuyFloor)
end)

-- ESP
local ESP = { enabled = false, tracked = {}, folder = nil, conns = {} }

local function ensureESPFolder()
    if ESP.folder and ESP.folder.Parent then return ESP.folder end
    local f = workspace:FindFirstChild("XenonESPFolder")
    if not f then f = Instance.new("Folder"); f.Name = "XenonESPFolder"; f.Parent = workspace end
    ESP.folder = f; return f
end

local function healthColor(p)
    if p > 0.6 then return Color3.fromRGB(200, 80, 80)
    elseif p > 0.3 then return Color3.fromRGB(230, 140, 80)
    else return Color3.fromRGB(255, 60, 60) end
end

local function removeESP(npc)
    local d = ESP.tracked[npc]
    if d then
        if d.hl then pcall(function() d.hl:Destroy() end) end
        if d.bar then pcall(function() d.bar:Destroy() end) end
        if d.name then pcall(function() d.name:Destroy() end) end
        ESP.tracked[npc] = nil
    end
end

local function addESP(npc)
    if ESP.tracked[npc] or not IsNPCAlive(npc) then return end
    local folder = ensureESPFolder()

    local hl = Instance.new("Highlight")
    hl.Adornee = npc
    hl.FillColor = Color3.fromRGB(200, 50, 50)
    hl.OutlineColor = Color3.fromRGB(255, 100, 100)
    hl.FillTransparency = 0.85
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Enabled = ESP.enabled
    hl.Parent = folder

    local bar = Instance.new("BillboardGui")
    bar.Size = UDim2.new(0, 22, 0, 110)
    bar.StudsOffset = Vector3.new(-3.2, 0, 0)
    bar.AlwaysOnTop = true
    bar.LightInfluence = 0
    bar.Enabled = ESP.enabled
    bar.Parent = folder
    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(1,0,1,0)
    barBg.BackgroundColor3 = Color3.fromRGB(20,20,20)
    barBg.BackgroundTransparency = 0.15
    barBg.BorderSizePixel = 1
    barBg.Parent = bar
    local bbc = Instance.new("UICorner"); bbc.CornerRadius = UDim.new(0,3); bbc.Parent = barBg
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(1,0,1,0)
    fill.AnchorPoint = Vector2.new(0,1)
    fill.Position = UDim2.new(0,0,1,0)
    fill.BackgroundColor3 = healthColor(1)
    fill.BorderSizePixel = 0
    fill.Parent = barBg
    local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0,3); fc.Parent = fill
    local pct = Instance.new("TextLabel")
    pct.Size = UDim2.new(0,50,0,16)
    pct.Position = UDim2.new(0.5,-25,1,2)
    pct.BackgroundTransparency = 1
    pct.TextColor3 = Color3.new(1,1,1)
    pct.TextStrokeTransparency = 0
    pct.TextSize = 11
    pct.Font = Enum.Font.Code
    pct.Text = "100%"
    pct.Parent = bar

    local name = Instance.new("BillboardGui")
    name.Size = UDim2.new(0,200,0,24)
    name.StudsOffset = Vector3.new(0,3.5,0)
    name.AlwaysOnTop = true
    name.LightInfluence = 0
    name.Enabled = ESP.enabled
    name.Parent = folder
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(230,230,230)
    lbl.TextStrokeTransparency = 0
    lbl.TextSize = 13
    lbl.Font = Enum.Font.Code
    lbl.Text = npc.Name
    lbl.Parent = name

    ESP.tracked[npc] = { hl = hl, bar = bar, fill = fill, pct = pct, name = name, lbl = lbl }

    local root = npc:FindFirstChild("HumanoidRootPart")
    if root then bar.Adornee = root; name.Adornee = root end
end

local function updateESP()
    if not ESP.enabled then return end
    for npc, d in pairs(ESP.tracked) do
        if not IsNPCAlive(npc) then
            removeESP(npc)
        else
            local hum = npc:FindFirstChildOfClass("Humanoid")
            local root = npc:FindFirstChild("HumanoidRootPart")
            if hum and root then
                local p = math.clamp(hum.Health / math.max(hum.MaxHealth,1), 0, 1)
                d.fill.Size = UDim2.new(1,0,p,0)
                d.fill.BackgroundColor3 = healthColor(p)
                d.pct.Text = string.format("%d%%", math.floor(p*100))
                d.bar.Adornee = root
                d.name.Adornee = root
            end
        end
    end
end

local function startESP()
    if ESP.enabled then return end
    ESP.enabled = true
    ensureESPFolder()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and IsNPC(obj) then addESP(obj) end
    end
    table.insert(ESP.conns, workspace.DescendantAdded:Connect(function(d)
        if not ESP.enabled then return end
        if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") and IsNPC(d.Parent) then addESP(d.Parent)
        elseif d:IsA("Model") and IsNPC(d) then addESP(d) end
    end))
    table.insert(ESP.conns, workspace.DescendantRemoving:Connect(function(d)
        if d:IsA("Model") and ESP.tracked[d] then removeESP(d) end
    end))
    table.insert(ESP.conns, RunService.Heartbeat:Connect(function()
        if not ESP.enabled then return end
        updateESP()
    end))
end

local function stopESP()
    ESP.enabled = false
    for _, c in ipairs(ESP.conns) do pcall(function() c:Disconnect() end) end
    ESP.conns = {}
    for npc, _ in pairs(ESP.tracked) do removeESP(npc) end
    if ESP.folder and ESP.folder.Parent then pcall(function() ESP.folder:Destroy() end); ESP.folder = nil end
end

-- ============================================================
-- UI
-- ============================================================
local Tab = SecretHub:Tab(HUB_NAME, "◈")
local MainSec = Tab:Section("Control")

MainSec:Toggle({
    Label = "Enable",
    Desc = "Start zombie farming",
    Default = false,
    Callback = function(v)
        AimbotEnabled = v
        deadTargets = {}
        if v then
            task.spawn(mainLoop)
            SecretHub.Notify(HUB_NAME, "Started (" .. Mode .. ")", "success")
        else
            stopHover()
            SecretHub.Notify(HUB_NAME, "Stopped", "warn")
        end
    end,
})

local FireSec = Tab:Section("Fire")

FireSec:Dropdown({
    Label = "Fire Mode",
    Items = { "Auto (rapid)", "Single (slow)", "Custom" },
    Default = "Auto (rapid)",
    Callback = function(v)
        if v:find("Auto") then AttackDelay = FIRE_AUTO
        elseif v:find("Single") then AttackDelay = FIRE_SINGLE
        elseif v:find("Custom") then AttackDelay = FIRE_CUSTOM end
    end,
})

FireSec:Input({
    Label = "Custom Delay (s)",
    Placeholder = "0.10", Default = "0.10",
    Callback = function(t)
        local n = tonumber(t)
        if n and n >= 0.01 and n <= 2 then
            FIRE_CUSTOM = n
            if AttackDelay == FIRE_CUSTOM or AttackDelay == 0.10 then AttackDelay = n end
        end
    end,
})

local ProtSec = Tab:Section("Death Protector")

ProtSec:Toggle({
    Label = "Enable Death Protector",
    Desc = "Floats you up when health drops below threshold",
    Default = ProtectEnabled,
    Callback = function(v)
        ProtectEnabled = v
        _G.__XenonProtectEnabled = v
        if not v then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hrp and hum then exitProtection(hrp, hum) end
        end
        SecretHub.Notify(HUB_NAME, v and "Death protect ON" or "Death protect OFF", v and "success" or "warn")
    end,
})

ProtSec:Slider({
    Label = "Trigger at HP%",
    Min = 5, Max = 80, Default = PROTECT_LOW_PCT,
    Callback = function(v) PROTECT_LOW_PCT = v; _G.__XenonProtectLow = v end,
})

ProtSec:Slider({
    Label = "Release at HP%",
    Min = 20, Max = 100, Default = PROTECT_HIGH_PCT,
    Callback = function(v) PROTECT_HIGH_PCT = v; _G.__XenonProtectHigh = v end,
})

ProtSec:Slider({
    Label = "Float Height",
    Min = 50, Max = 500, Default = PROTECT_TP_HEIGHT,
    Callback = function(v) PROTECT_TP_HEIGHT = v; _G.__XenonProtectTP = v end,
})

local BuySec = Tab:Section("Auto-Buy Guns")

BuySec:Toggle({
    Label = "Auto-Buy Next Gun",
    Desc = "Buys guns above your currently equipped one, cheapest first",
    Default = false,
    Callback = function(v)
        AutoBuyEnabled = v
        buyAttempts = {}
        buyLog = {}
        refreshAutobuyFloor()
        SecretHub.Notify(HUB_NAME, v and "Auto-buy ON" or "Auto-buy OFF", v and "success" or "warn")
    end,
})

BuySec:Input({
    Label = "Buy Interval (s)",
    Placeholder = "5", Default = "5",
    Callback = function(t)
        local n = tonumber(t)
        if n and n >= 1 and n <= 60 then AUTOBUY_INTERVAL = n end
    end,
})

local moneyLabel    = BuySec:Label("money: —")
local equippedLabel = BuySec:Label("equipped: —")
local floorLabel    = BuySec:Label("floor: Pistol ($0)")
local logLabel      = BuySec:Label("last: waiting")

task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(function()
            local name = getEquippedGunName()
            local floorGun = GUNS[autobuyFloorIndex] or GUNS[1]
            local money = getCurrentMoney()
            moneyLabel:Set("money: " .. (money and ("$" .. money) or "—"))
            equippedLabel:Set("equipped: " .. (name or "—"))
            floorLabel:Set(string.format("floor: %s ($%s)", floorGun.name, floorGun.price))
            if CommunicationF then
                if #buyLog > 0 then logLabel:Set("last: " .. buyLog[1])
                else logLabel:Set("remote ready — waiting for first buy") end
            else
                logLabel:Set("remote not loaded")
            end
        end)
    end
end)

local ESPTab = SecretHub:Tab("ESP", "◉")
local ESPSec = ESPTab:Section("Zombie ESP")

ESPSec:Toggle({
    Label = "Zombie ESP",
    Desc = "Highlight + health bar (through walls)",
    Default = false,
    Callback = function(v)
        if v then startESP() else stopESP() end
    end,
})

-- ZOMBIES TAB
local CountTab = SecretHub:Tab("Zombies", "☠")
local CountSec = CountTab:Section("Census")

local totalLabel    = CountSec:Label("alive: 0 | dead: 0")
local typeListLabel = CountSec:Label("types: —")
local perTypeLabels = {}

local function ensureTypeRow(typeName)
    if perTypeLabels[typeName] then return perTypeLabels[typeName] end
    local lbl = CountSec:Label(typeName .. ": 0 alive / 0 dead")
    perTypeLabels[typeName] = lbl
    return lbl
end

local function censusTick()
    local types = {}
    local totalAlive, totalDead = 0, 0

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local hrp = obj:FindFirstChild("HumanoidRootPart")
            if hum and hrp then
                local isPlayer = false
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr.Character == obj then isPlayer = true; break end
                end
                if not isPlayer then
                    local name = obj.Name
                    types[name] = types[name] or { alive = 0, dead = 0 }
                    local alive = IsNPCAlive(obj)
                    if alive then
                        types[name].alive += 1
                        totalAlive += 1
                    else
                        types[name].dead += 1
                        totalDead += 1
                    end
                end
            end
        end
    end

    totalLabel:Set(string.format("alive: %d | dead: %d", totalAlive, totalDead))

    local names = {}
    for n in pairs(types) do table.insert(names, n) end
    table.sort(names)
    typeListLabel:Set("types: " .. (#names > 0 and table.concat(names, ", ") or "—"))

    for _, n in ipairs(names) do
        local lbl = ensureTypeRow(n)
        local t = types[n]
        lbl:Set(string.format("%s: %d alive / %d dead", n, t.alive, t.dead))
    end
end

task.spawn(function()
    while true do
        task.wait(1)
        pcall(censusTick)
    end
end)

-- MODE TAB
local ModeTab = SecretHub:Tab("Mode", "⚙")
local ModeSec = ModeTab:Section("Farm Mode")

ModeSec:Dropdown({
    Label = "Farm Mode",
    Items = { "Air", "TP", "Ground" },
    Default = "Air",
    Callback = function(v)
        Mode = v
        stopHover()
        lastGroundDir = nil
        SecretHub.Notify(HUB_NAME, "Mode: " .. v, "info")
    end,
})

-- MODE TUNING TAB
local TuneTab = SecretHub:Tab("Mode Tuning", "≡")

local AirSec = TuneTab:Section("Air / TP")
AirSec:Slider({
    Label = "Fly Height (studs)",
    Min = 10, Max = 100, Default = HOVER_HEIGHT,
    Callback = function(v) HOVER_HEIGHT = v; _G.__XenonHoverHeight = v end,
})

local GroundSec = TuneTab:Section("Ground")
GroundSec:Slider({
    Label = "Back-off distance (studs)",
    Min = 4, Max = 40, Default = GROUND_NEAR_DIST,
    Callback = function(v) GROUND_NEAR_DIST = v; _G.__XenonGroundNear = v end,
})
GroundSec:Slider({
    Label = "Approach distance (studs)",
    Min = 10, Max = 80, Default = GROUND_FAR_DIST,
    Callback = function(v) GROUND_FAR_DIST = v; _G.__XenonGroundFar = v end,
})
GroundSec:Slider({
    Label = "Repath interval (s)",
    Min = 0.05, Max = 1, Default = GROUND_STEP,
    Callback = function(v) GROUND_STEP = v end,
})
GroundSec:Slider({
    Label = "Sidestep distance (studs)",
    Min = 2, Max = 20, Default = GROUND_SIDESTEP,
    Callback = function(v) GROUND_SIDESTEP = v end,
})

-- SETTINGS TAB
local SettingsTab = SecretHub:Tab("Settings", "✦")
local SettingsSec = SettingsTab:Section("Misc")

SettingsSec:Toggle({
    Label = "Anti-AFK",
    Desc = "Prevents Roblox from kicking you for inactivity",
    Default = AntiAfkEnabled,
    Callback = function(v)
        AntiAfkEnabled = v
        if v then
            startAntiAfk()
            SecretHub.Notify(HUB_NAME, "Anti-AFK ON", "success")
        else
            stopAntiAfk()
            SecretHub.Notify(HUB_NAME, "Anti-AFK OFF", "warn")
        end
    end,
})

print("if Xen isn't yo daddy, then who is? Feat. hbV2")
SecretHub.Notify(HUB_NAME, "Loaded (v2.5)", "success")
