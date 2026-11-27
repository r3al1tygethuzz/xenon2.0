-- XENON v15.9 part1 | autoexec mode + session stats + admin roster
print("[XENON] ============================================")
print("[XENON] TOP OF FILE REACHED (part1)")
print("[XENON] ============================================")

if game.PlaceId ~= 13388465281 then
    print("[XENON] not in Hard Time (" .. tostring(game.PlaceId) .. ") — exiting")
    return
end

if _G.__XenonRunning then
    print("[XENON] already running in this session — skipping duplicate load")
    return
end
_G.__XenonRunning = true

local PART2_URL = "https://gist.githubusercontent.com/powelleshon-max/90dec1588418c13785f8a7b1c3bbcabd/raw/4e81460557a8d57dcf863e1d9b90f70f33554028/Ssss"

local XENON_LOGO = "rbxassetid://112895096658850"
local PRIVATE_SERVER_LINK = ""

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local VirtualUser       = game:GetService("VirtualUser")
local UserInputService  = game:GetService("UserInputService")
local CoreGui           = game:GetService("CoreGui")
local HttpService       = game:GetService("HttpService")
local Lighting          = game:GetService("Lighting")
local SoundService      = game:GetService("SoundService")
local TeleportService   = game:GetService("TeleportService")
local GuiService        = game:GetService("GuiService")
print("[XENON] ✓ services loaded")

local localPlayer = Players.LocalPlayer
local FONT = Enum.Font.Code
print("[XENON] ✓ localPlayer: " .. tostring(localPlayer and localPlayer.Name))

-- XENON RED THEME
local THEME = {
    Bg=Color3.fromRGB(10,10,10),
    BgAlt=Color3.fromRGB(18,18,18),
    Panel=Color3.fromRGB(26,26,26),
    PanelAlt=Color3.fromRGB(34,34,34),
    TitleBar=Color3.fromRGB(6,6,6),

    Border=Color3.fromRGB(190,25,40),
    Green=Color3.fromRGB(255,45,65),
    GreenDark=Color3.fromRGB(150,20,35),
    GreenDeep=Color3.fromRGB(65,10,18),

    Text=Color3.fromRGB(240,235,235),
    TextDim=Color3.fromRGB(135,120,122),
    TextMid=Color3.fromRGB(185,170,172),

    Red=Color3.fromRGB(255,70,70),
    Orange=Color3.fromRGB(255,170,60),
}

local state = {
    farms = { SuperFarm = false, BoxesFarm = false },
    superTargets = {
        Registers=true, Cash=true, Dumpsters=true, ATMs=true,
        Bank=false, Casino=false, Jewelry=false, Gunpowder=false,
    },
    farmOrder = { "Registers","ATMs","Cash","Dumpsters" },
    protection = { AntiAFK=false, FPSBoost=false, DamageFailsafe=true, LowGFX=false, AntiAdmin=true },
    esp = { PlayerESP=false, Registers=false, Cash=false, Dumpsters=false, ATMs=false },
    movement = { mode = "TP" },
    running = true, minimized = false, currentTab = "Farms",
    ui = { superFarmOpen = true },
}

-- ============================================================
-- SESSION STATS
-- ============================================================

local CASH_PER_REGISTER = 45
local CASH_PER_ATM      = 120
local CASH_PER_FLOOR    = 15
local CASH_PER_DUMPSTER = 25

local sessionStats = {
    startTime = 0,
    endTime = 0,
    isRunning = false,
    pickups = { Registers=0, ATMs=0, Cash=0, Dumpsters=0 },
    resets = 0,
    estimatedCash = 0,
}

function sessionStats.start()
    if sessionStats.isRunning then return end
    sessionStats.isRunning = true
    if sessionStats.startTime == 0 then sessionStats.startTime = tick() end
end

function sessionStats.stop()
    sessionStats.isRunning = false
    sessionStats.endTime = tick()
end

function sessionStats.elapsed()
    if sessionStats.startTime == 0 then return 0 end
    local endT = sessionStats.isRunning and tick() or (sessionStats.endTime > 0 and sessionStats.endTime or tick())
    return endT - sessionStats.startTime
end

function sessionStats.recordPickup(kind)
    if sessionStats.pickups[kind] then
        sessionStats.pickups[kind] = sessionStats.pickups[kind] + 1
    end
    if kind == "Registers" then
        sessionStats.estimatedCash = sessionStats.estimatedCash + CASH_PER_REGISTER
    elseif kind == "ATMs" then
        sessionStats.estimatedCash = sessionStats.estimatedCash + CASH_PER_ATM
    elseif kind == "Cash" then
        sessionStats.estimatedCash = sessionStats.estimatedCash + CASH_PER_FLOOR
    elseif kind == "Dumpsters" then
        sessionStats.estimatedCash = sessionStats.estimatedCash + CASH_PER_DUMPSTER
    end
end

function sessionStats.recordReset()
    sessionStats.resets = sessionStats.resets + 1
end

function sessionStats.totalPickups()
    local n = 0
    for _, v in pairs(sessionStats.pickups) do n = n + v end
    return n
end

function sessionStats.perHour()
    local el = sessionStats.elapsed()
    if el <= 0 then return 0 end
    return (sessionStats.estimatedCash / el) * 3600
end

function sessionStats.formatTime(sec)
    sec = math.floor(sec)
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    if h > 0 then return string.format("%dh %dm %ds", h, m, s) end
    if m > 0 then return string.format("%dm %ds", m, s) end
    return string.format("%ds", s)
end

print("[XENON] ✓ session stats ready")

local NYRA_ENABLED = false

local ATM_PICKUP_RADIUS = 6
local ATM_CASH_SPAWN_WAIT = 0.9
local ATM_HOLD_DEFAULT = 0.6
local ATM_HOLD_SLACK = 0.15
local REGISTER_CASH_RADIUS = 15
local FARM_PROMPT_RADIUS = 10
local BANK_WAIT_AFTER_BUTTON = 17
local JEWELRY_SPLIT_INDEX = 4
local JEWELRY_POST_RESET_WAIT = 300
local HARD_RESET_MIN_GAP = 3
local TP_COOLDOWN_AFTER = 8
local TP_BREATH_DURATION = 2.0

local TP_ACTIONS_BEFORE_RESET = 6
local TWEEN_ACTIONS_BEFORE_RESET = 30
local EARLY_RESET_PERCENT = 0.55
local FAILSAFE_COMBAT_COOLDOWN = 150
local RESET_WALLCLOCK_INTERVAL = 300
local SUPFERFARM_WATCHDOG_INTERVAL = 5
local SCAN_LIVE_INTERVAL = 1.0
local MEMORY_TTL = 45
local MEMORY_CAP = 400

local BOX_PICKUP_POS  = Vector3.new(-1286.81, 1.95, -512.01)
local BOX_DROPOFF_POS = Vector3.new(-1334.87, 1.91, -484.50)
local BOX_PROMPT_RADIUS = 8
local BOX_PICKUP_DWELL = 1.2
local BOX_DROPOFF_DWELL = 1.2
local BOX_LOOP_DELAY = 0.15
local BOX_REWARD_COOLDOWN = 0.4

local UNDER_Y = -6.14
local TWEEN_SPEED = 28
local TWEEN_MIN_GAP = 0.10
local TWEEN_LEG_TIMEOUT = 6
local IDLE_POS = Vector3.new(-912.79, 1.90, -1136.18)
local IDLE_THRESHOLD = 30

local tunables = {
    tpStandOffset=5, tpInterval=0.45, registerDwell=0.35,
    atmDwell=1.6, nyraDwell=0.5, cashDwell=0.12,
}
print("[XENON] ✓ constants defined")

-- config
local XenonConfig = {
    FILE="Xenon_config.json", VERSION=1, dirty=false, lastChange=0, loaded=false, ioWorking=nil,
}

function XenonConfig.testIO()
    if XenonConfig.ioWorking ~= nil then return XenonConfig.ioWorking end
    if type(writefile) ~= "function" or type(readfile) ~= "function" then
        XenonConfig.ioWorking = false
        return false
    end
    local probe = "xenon_io_probe.txt"
    local wok, werr = pcall(writefile, probe, "ok")
    if not wok then
        print("[XENON] config: writefile stubbed (" .. tostring(werr) .. ")")
        XenonConfig.ioWorking=false
        return false
    end
    local rok, rres = pcall(readfile, probe)
    if type(delfile) == "function" then pcall(delfile, probe) end
    if not rok or type(rres) ~= "string" then
        print("[XENON] config: readfile stubbed (" .. tostring(rres) .. ")")
        XenonConfig.ioWorking=false
        return false
    end
    XenonConfig.ioWorking = true
    return true
end

function XenonConfig.exists(name)
    if type(isfile) ~= "function" then
        if XenonConfig.ioWorking ~= true then return false end
        local ok, res = pcall(readfile, name)
        return ok and type(res) == "string" and #res > 0
    end
    local ok, res = pcall(isfile, name)
    if not ok then return false end
    return res == true
end

function XenonConfig.gather()
    return {
        version=XenonConfig.VERSION, savedAt=tick(),
        farms={SuperFarm=state.farms.SuperFarm},
        superTargets={
            Registers=state.superTargets.Registers, Cash=state.superTargets.Cash,
            Dumpsters=state.superTargets.Dumpsters, ATMs=state.superTargets.ATMs,
            Bank=state.superTargets.Bank, Casino=state.superTargets.Casino,
            Jewelry=state.superTargets.Jewelry, Gunpowder=state.superTargets.Gunpowder,
        },
        thresholds={
            TP_ACTIONS_BEFORE_RESET=TP_ACTIONS_BEFORE_RESET,
            TWEEN_ACTIONS_BEFORE_RESET=TWEEN_ACTIONS_BEFORE_RESET,
            EARLY_RESET_PERCENT=EARLY_RESET_PERCENT,
            HARD_RESET_MIN_GAP=HARD_RESET_MIN_GAP,
        },
        ui={superFarmOpen=state.ui.superFarmOpen},
    }
end

function XenonConfig.apply(cfg)
    if type(cfg) ~= "table" then return end
    if type(cfg.farms) == "table" and type(cfg.farms.SuperFarm) == "boolean" then
        state.farms.SuperFarm = cfg.farms.SuperFarm
    end
    if type(cfg.superTargets) == "table" then
        for k, v in pairs(cfg.superTargets) do
            if state.superTargets[k] ~= nil and type(v) == "boolean" then
                state.superTargets[k] = v
            end
        end
    end
    if type(cfg.thresholds) == "table" then
        local t = cfg.thresholds
        if type(t.TP_ACTIONS_BEFORE_RESET)=="number" then TP_ACTIONS_BEFORE_RESET=t.TP_ACTIONS_BEFORE_RESET end
        if type(t.TWEEN_ACTIONS_BEFORE_RESET)=="number" then TWEEN_ACTIONS_BEFORE_RESET=t.TWEEN_ACTIONS_BEFORE_RESET end
        if type(t.EARLY_RESET_PERCENT)=="number" then EARLY_RESET_PERCENT=math.clamp(t.EARLY_RESET_PERCENT,0.1,1.0) end
        if type(t.HARD_RESET_MIN_GAP)=="number" then HARD_RESET_MIN_GAP=math.max(1,t.HARD_RESET_MIN_GAP) end
    end
    if type(cfg.ui)=="table" and type(cfg.ui.superFarmOpen)=="boolean" then
        state.ui.superFarmOpen=cfg.ui.superFarmOpen
    end
end

function XenonConfig.decode(raw)
    if type(raw) ~= "string" or #raw == 0 then return nil end
    local okj, res = pcall(function() return HttpService:JSONDecode(raw) end)
    if okj and type(res) == "table" then return res end
    local okL, fn = pcall(function() return loadstring("return " .. raw) end)
    if okL and type(fn) == "function" then
        local okR, r2 = pcall(fn)
        if okR and type(r2) == "table" then return r2 end
    end
    return nil
end

function XenonConfig.load()
    if not XenonConfig.testIO() then
        print("[XENON] config: persistence unavailable — using defaults")
        XenonConfig.loaded=true
        return
    end
    if not XenonConfig.exists(XenonConfig.FILE) then
        print("[XENON] config: none found — using defaults")
        XenonConfig.loaded=true
        return
    end
    local ok, raw = pcall(readfile, XenonConfig.FILE)
    if not ok or type(raw) ~= "string" or #raw == 0 then
        print("[XENON] config: read failed (" .. tostring(raw) .. ")")
        XenonConfig.loaded=true
        return
    end
    local decoded = XenonConfig.decode(raw)
    if type(decoded) ~= "table" then
        print("[XENON] config: decode failed")
        XenonConfig.loaded=true
        return
    end
    XenonConfig.apply(decoded)
    XenonConfig.loaded=true
    print("[XENON] config: loaded")
end

function XenonConfig.flush()
    if XenonConfig.ioWorking ~= true then return end
    if not XenonConfig.dirty then return end
    local ok, encoded = pcall(function() return HttpService:JSONEncode(XenonConfig.gather()) end)
    if not ok or type(encoded) ~= "string" then XenonConfig.dirty=false; return end
    local wok, werr = pcall(writefile, XenonConfig.FILE, encoded)
    if wok then
        XenonConfig.dirty=false
    else
        print("[XENON] config: write failed (" .. tostring(werr) .. ")")
        XenonConfig.ioWorking=false
        XenonConfig.dirty=false
    end
end

function XenonConfig.markDirty()
    XenonConfig.dirty = true
    XenonConfig.lastChange = tick()
end

XenonConfig.load()

task.spawn(function()
    while state.running do
        task.wait(0.1)
        if XenonConfig.dirty and (tick() - XenonConfig.lastChange) >= 0.5 then
            XenonConfig.flush()
        end
    end
end)

pcall(function()
    game:BindToClose(function()
        XenonConfig.flush()
        task.wait(0.25)
    end)
end)

-- flags
local failsafeActive = false
local lastDamageAt = 0
local isResetting = false
local hardResetInFlight = false
local lastHardResetAt = 0
local lastResetWallclock = tick()
local lastHealth = nil
local healthConn = nil
local antiAFKConnection = nil
local fpsBoostPrev = nil
local lowGfxPrev = nil
local lowGfxConns = {}
local lowGfxEnabled = false
local stripQueue = {}
local stripProcessing = false
local lastTweenTime = 0
local playerESPEnabled = false
local trackedPlayers = {}
local superFarmLastTick = 0
local superFarmRunning = false
local tpActionsSinceReset = 0
local tweenActionsSinceReset = 0
local tweenInFlight = false
local isRagdolled = false

local teleportSystem = {
    generation=0, lastTPTime=0, consecutiveFast=0, atmsSinceReset=0, successfulTPs=0,
    farms = {
        Dumpster={memory={}}, Cash={memory={}}, Register={memory={}}, ATM={memory={}},
        Bank={memory={}}, Casino={memory={}}, Jewelry={memory={}}, Gunpowder={memory={}},
    },
}

local selectedFarmKey = nil
local startFarmModule
local jewelryState = { phase = 1, lastFinishAt = 0 }
local forceResetCharacter
local triggerReset
local boxesFarmGeneration = 0
local dumpsterSelling = false

local _cachedHRP = nil
local _cachedHum = nil

RunService.Heartbeat:Connect(function()
    local ch = localPlayer.Character
    if ch then
        local h = ch:FindFirstChildOfClass("Humanoid")
        if h and h.Health > 0 then
            _cachedHRP = ch:FindFirstChild("HumanoidRootPart")
            _cachedHum = h
            return
        end
    end
    _cachedHRP = nil
    _cachedHum = nil
end)

local function getHRP() return _cachedHRP end
local function getHumanoid() return _cachedHum end

RunService.Heartbeat:Connect(function()
    if state.movement.mode ~= "Tween" then return end
    if isRagdolled or tweenInFlight then return end
    if not state.farms.SuperFarm and not state.farms.BoxesFarm then return end
    local hrp = _cachedHRP
    if not hrp then return end
    if hrp.Position.Y > UNDER_Y + 0.5 then
        hrp.CFrame = CFrame.new(hrp.Position.X, UNDER_Y, hrp.Position.Z)
        hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X,0,hrp.AssemblyLinearVelocity.Z)
    end
end)

local function detectRagdoll()
    local char = localPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    local ok, st = pcall(function() return hum:GetState() end)
    if ok and st == Enum.HumanoidStateType.Ragdoll then return true end
    if char:FindFirstChild("Ragdoll") or char:FindFirstChild("RagdollTrigger") then return true end
    if char:GetAttribute("Ragdolled") == true then return true end
    return false
end

local function markMemory(key, obj)
    local mem = teleportSystem.farms[key] and teleportSystem.farms[key].memory
    if not mem then return end
    mem[obj] = tick()
    local count = 0
    for _ in pairs(mem) do count = count + 1 end
    if count > MEMORY_CAP then
        local oldest, oldestT = nil, math.huge
        for k, t in pairs(mem) do
            if t < oldestT then oldest, oldestT = k, t end
        end
        if oldest then mem[oldest] = nil end
    end
end

local function memoryFresh(key, obj)
    local mem = teleportSystem.farms[key] and teleportSystem.farms[key].memory
    if not mem then return false end
    local t = mem[obj]
    if not t then return false end
    if tick() - t > MEMORY_TTL then mem[obj] = nil; return false end
    return true
end

local function sweepMemory()
    local now = tick()
    for _, farm in pairs(teleportSystem.farms) do
        for k, t in pairs(farm.memory) do
            if now - t > MEMORY_TTL then farm.memory[k] = nil end
        end
    end
end

-- intro skip
local INTRO_SOUND_NAMES = {
    "Theme","ThemeSong","Music","IntroMusic","IntroTheme","Intro",
    "BackgroundMusic","BGM","Soundtrack","MainTheme","MenuMusic"
}

local function muteIntroSounds()
    local function tryMute(s)
        if not s:IsA("Sound") or not s.IsPlaying then return end
        local n = string.lower(s.Name)
        local id = string.lower(s.SoundId)
        for _, k in ipairs(INTRO_SOUND_NAMES) do
            if n:find(string.lower(k)) then s.Volume=0; s:Stop(); return end
        end
        if id:find("music") or id:find("theme") or id:find("song") then
            s.Volume=0
            s:Stop()
        end
    end
    for _, c in ipairs({
        SoundService, localPlayer:FindFirstChild("PlayerGui"),
        localPlayer:FindFirstChild("PlayerScripts"), ReplicatedStorage
    }) do
        if c then
            pcall(function()
                for _, s in ipairs(c:GetDescendants()) do tryMute(s) end
            end)
        end
    end
end

local IntroWeaponEvent = nil

task.spawn(function()
    pcall(function()
        local ev = ReplicatedStorage:WaitForChild("Events", 20)
        if ev then IntroWeaponEvent = ev:WaitForChild("WeaponEvent", 20) end
    end)
end)

local function skipIntro()
    if IntroWeaponEvent then
        pcall(function() firesignal(IntroWeaponEvent.OnClientEvent, "IntroEnd") end)
        pcall(function() IntroWeaponEvent:FireServer("RequestToEndIntro") end)
    end
    muteIntroSounds()
end

task.spawn(function()
    for _=1,12 do skipIntro(); task.wait(0.35) end
end)

task.spawn(function()
    task.wait(4)
    for _=1,4 do skipIntro(); task.wait(1.5) end
end)

pcall(function()
    localPlayer.CharacterAdded:Connect(function()
        task.wait(0.35)
        skipIntro()
    end)
end)

-- AS bridge
local AS = {}

function AS.getHRP()
    local ch = localPlayer.Character
    if not ch then return nil end
    local h = ch:FindFirstChildOfClass("Humanoid")
    if h and h.Health > 0 then return ch:FindFirstChild("HumanoidRootPart") end
    return nil
end

function AS.getHumanoid()
    local ch = localPlayer.Character
    return ch and ch:FindFirstChildOfClass("Humanoid")
end

function AS.zeroVelocity()
    local hrp = AS.getHRP()
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
        hrp.AssemblyAngularVelocity = Vector3.new(0,0,0)
    end
end

function AS.tpTo(pos, lookAt, countAsFarm)
    local hrp = AS.getHRP()
    if not hrp then return false end
    local hum = AS.getHumanoid()
    if hum then
        hum.PlatformStand=true
        hum.WalkSpeed=0
        hum.JumpPower=0
    end
    hrp.CFrame = CFrame.new(pos)
    if lookAt then
        local look = lookAt - pos
        if look.Magnitude > 0.01 then
            hrp.CFrame = CFrame.lookAt(pos, Vector3.new(lookAt.X,pos.Y,lookAt.Z))
        end
    end
    hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
    hrp.AssemblyAngularVelocity = Vector3.new(0,0,0)
    task.wait(0.05)
    if hum then
        hum.PlatformStand=false
        hum.WalkSpeed=16
        hum.JumpPower=50
    end
    if countAsFarm then
        local now = tick()
        local el = now - teleportSystem.lastTPTime
        teleportSystem.lastTPTime = now
        if el < tunables.tpInterval + 0.15 then
            teleportSystem.consecutiveFast = teleportSystem.consecutiveFast + 1
        else
            teleportSystem.consecutiveFast = math.max(0, teleportSystem.consecutiveFast - 1)
        end
        if teleportSystem.consecutiveFast >= TP_COOLDOWN_AFTER then
            teleportSystem.consecutiveFast = 0
            task.wait(TP_BREATH_DURATION)
        end
    end
    return true
end

function AS.firePromptFast(pr)
    if not pr or not pr.Enabled then return false end
    if fireproximityprompt then
        pcall(function() fireproximityprompt(pr) end)
        return true
    end
    pcall(function()
        pr:InputHoldBegin()
        task.wait(0.05)
        pr:InputHoldEnd()
    end)
    return true
end

function AS.firePromptHoldExact(pr)
    if not pr or not pr.Parent or not pr.Enabled then return false end
    local dur = pr.HoldDuration or 0
    if dur <= 0 then dur = ATM_HOLD_DEFAULT end
    dur = dur + ATM_HOLD_SLACK
    local began = pcall(function() pr:InputHoldBegin() end)
    if not began then return false end
    task.wait(dur)
    if pr and pr.Parent then pcall(function() pr:InputHoldEnd() end) end
    return true
end

function AS.dwellNear(pos, seconds, radius)
    radius = radius or FARM_PROMPT_RADIUS
    local t0 = tick()
    while tick() - t0 < seconds do
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("ProximityPrompt") and d.Enabled then
                local root = d.Parent
                local p = root and (root:IsA("BasePart") and root or root:FindFirstAncestorWhichIsA("BasePart"))
                if p and (p.Position - pos).Magnitude <= radius then
                    AS.firePromptFast(d)
                    task.wait(0.14)
                end
            end
        end
        task.wait(0.05)
    end
end

function AS.firePromptAt(pos, tries, radius)
    tries = tries or 2
    radius = radius or FARM_PROMPT_RADIUS
    local best, bd = nil, radius
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled then
            local root = d.Parent
            local p = root and (root:IsA("BasePart") and root or root:FindFirstAncestorWhichIsA("BasePart"))
            if p then
                local dist = (p.Position - pos).Magnitude
                if dist < bd then bd = dist; best = d end
            end
        end
    end
    if not best then return false end
    for _=1,tries do AS.firePromptFast(best); task.wait(0.14) end
    return true
end

local function goToIdle()
    local hrp = AS.getHRP()
    if not hrp then return end
    if (hrp.Position - IDLE_POS).Magnitude <= IDLE_THRESHOLD then return end
    AS.tpTo(IDLE_POS + Vector3.new(0, tunables.tpStandOffset, 0))
end

local function forceIdle()
    AS.tpTo(IDLE_POS + Vector3.new(0, tunables.tpStandOffset, 0))
end

local function forceIdleUnder()
    local hrp = AS.getHRP()
    if not hrp then return end
    hrp.CFrame = CFrame.new(IDLE_POS.X, UNDER_Y, IDLE_POS.Z)
    AS.zeroVelocity()
end

task.spawn(function()
    task.wait(5.5)
    goToIdle()
end)

-- XENON SPLASH
task.spawn(function()
    local gui = Instance.new("ScreenGui")
    gui.Name="XenonSplash"
    gui.IgnoreGuiInset=true
    gui.ResetOnSpawn=false
    gui.DisplayOrder=9999

    local ok = pcall(function() gui.Parent = CoreGui end)
    if not ok or not gui.Parent then
        pcall(function() gui.Parent = localPlayer:WaitForChild("PlayerGui",5) end)
    end
    if not gui.Parent then return end

    local holder = Instance.new("Frame")
    holder.Size=UDim2.new(0,340,0,400)
    holder.Position=UDim2.new(0.5,0,0.5,-40)
    holder.AnchorPoint=Vector2.new(0.5,0.5)
    holder.BackgroundTransparency=1
    holder.Parent=gui

    local spinner = Instance.new("Frame")
    spinner.Size=UDim2.new(0,260,0,260)
    spinner.Position=UDim2.new(0.5,-130,0,0)
    spinner.BackgroundTransparency=1
    spinner.Parent=holder

    -- Replaced recycle glyph with the supplied Xenon decal.
    local glyph = Instance.new("ImageLabel")
    glyph.Name="XenonLogo"
    glyph.Size=UDim2.new(1,0,1,0)
    glyph.BackgroundTransparency=1
    glyph.Image=XENON_LOGO
    glyph.ImageColor3=Color3.fromRGB(255,45,65)
    glyph.ScaleType=Enum.ScaleType.Fit
    glyph.ImageTransparency=1
    glyph.Parent=spinner

    local word = Instance.new("TextLabel")
    word.Size=UDim2.new(1,0,0,70)
    word.Position=UDim2.new(0,0,0.85,0)
    word.BackgroundTransparency=1
    word.Text="XENON"
    word.TextColor3=THEME.Green
    word.TextSize=44
    word.Font=Enum.Font.GothamBold
    word.TextTransparency=1
    word.TextStrokeColor3=Color3.fromRGB(255,255,255)
    word.TextStrokeTransparency=0.4
    word.Parent=holder

    TweenService:Create(
        glyph,
        TweenInfo.new(0.5,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
        {ImageTransparency=0}
    ):Play()

    task.wait(0.4)

    TweenService:Create(
        spinner,
        TweenInfo.new(0.55,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut),
        {Rotation=360}
    ):Play()

    task.wait(0.55)
    spinner.Rotation=0

    TweenService:Create(
        word,
        TweenInfo.new(0.6,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
        {TextTransparency=0}
    ):Play()

    task.wait(1.6)

    TweenService:Create(
        glyph,
        TweenInfo.new(0.9,Enum.EasingStyle.Linear),
        {ImageTransparency=1}
    ):Play()

    TweenService:Create(
        word,
        TweenInfo.new(0.9,Enum.EasingStyle.Linear),
        {TextTransparency=1,TextStrokeTransparency=1}
    ):Play()

    task.wait(1.0)
    gui:Destroy()
end)

-- prompt index
local promptIndex = {}
local promptIndexSet = {}

local function indexPrompt(pp)
    if not pp:IsA("ProximityPrompt") then return end
    if promptIndexSet[pp] then return end
    promptIndexSet[pp]=true
    table.insert(promptIndex, pp)
end

local function unindexPrompt(pp)
    if not promptIndexSet[pp] then return end
    promptIndexSet[pp]=nil
    for i = #promptIndex, 1, -1 do
        if promptIndex[i] == pp then table.remove(promptIndex,i); break end
    end
end

local function buildPromptIndex()
    promptIndex = {}
    promptIndexSet = {}
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            promptIndexSet[d]=true
            table.insert(promptIndex,d)
        end
    end
end

task.spawn(function()
    task.wait(1)
    buildPromptIndex()
    print("[XENON] ✓ prompt index: " .. tostring(#promptIndex))
    Workspace.DescendantAdded:Connect(indexPrompt)
    Workspace.DescendantRemoving:Connect(unindexPrompt)
end)

local function promptBasePos(pr)
    local root = pr.Parent
    if not root then return nil end
    if root:IsA("BasePart") then return root.Position end
    local a = root:FindFirstAncestorWhichIsA("BasePart")
    if a then return a.Position end
    return nil
end

local function speedPrompt(pp)
    if pp:IsA("ProximityPrompt") then
        pcall(function() pp.HoldDuration=0.1 end)
    end
end

task.spawn(function()
    task.wait(1.5)
    for _, pp in ipairs(promptIndex) do speedPrompt(pp) end
    Workspace.DescendantAdded:Connect(function(d)
        task.spawn(function() speedPrompt(d) end)
    end)
end)

-- classifiers
local BLACKLISTED = {
    "casino","bank","vault","gunpowder","gunpowder_vault",
    "safebox","deposit","atm","safe","crate","cashregister"
}

local function isBlacklisted(part)
    local p = part.Parent
    local d = 0
    while p and p ~= Workspace and d < 8 do
        local pn = string.lower(p.Name)
        for _, b in ipairs(BLACKLISTED) do
            if pn:find(b) then return true end
        end
        p = p.Parent
        d = d + 1
    end
    return false
end

local function isValidFloorCash(d)
    if not d:IsA("BasePart") then return false end
    if d.Transparency >= 0.5 or d.Size.Y > 3 or d.Size.Y <= 0.1 then return false end
    if isBlacklisted(d) then return false end
    local n = string.lower(d.Name)
    local pn = d.Parent and string.lower(d.Parent.Name) or ""
    local match = n=="cash" or n=="cashspawn" or n=="part" or pn=="cash" or pn=="cashspawn" or pn=="part" or n:find("cash") or n:find("money")
    if not match then return false end
    local pr = d:FindFirstChildWhichIsA("ProximityPrompt", true)
    return pr and pr.Enabled
end

local function isAtmPart(d)
    if not d or not d:IsA("BasePart") then return false end
    local n = string.lower(d.Name)
    local pn = d.Parent and string.lower(d.Parent.Name) or ""
    if not (n:find("atm") or pn:find("atm")) then return false end
    if d.Size.Magnitude < 1.5 then return false end
    return true
end

local function isRegisterPart(d)
    if not d or not d:IsA("BasePart") then return false end
    local n = string.lower(d.Name)
    local pn = d.Parent and string.lower(d.Parent.Name) or ""
    if not (n:find("register") or pn:find("register")) then return false end
    if n:find("button") or n:find("gui") then return false end
    if isBlacklisted(d) then return false end
    return true
end

local function isDumpsterPart(d)
    if not d or not d:IsA("BasePart") then return false end
    local n = string.lower(d.Name)
    local pn = d.Parent and string.lower(d.Parent.Name) or ""
    if not (n:find("dumpster") or pn:find("dumpster") or n:find("searchable") or n:find("prop")) then return false end
    if isBlacklisted(d) then return false end
    return true
end

local function findPromptIn(d)
    local dir = d:FindFirstChildWhichIsA("ProximityPrompt", false)
    if dir and dir.Enabled then return dir end
    return d:FindFirstChildWhichIsA("ProximityPrompt", true)
end

local function liveFindClosest(kind, fromPos, memoryKey)
    local best, bestPrompt, bestDist = nil, nil, math.huge
    for _, pr in ipairs(promptIndex) do
        if pr.Enabled and pr.Parent then
            local root = pr.Parent
            local part = nil
            if root:IsA("BasePart") then
                part = root
            else
                part = root:FindFirstAncestorWhichIsA("BasePart")
            end
            if part and part.Parent then
                local ok = false
                if kind=="Registers" then ok=isRegisterPart(part)
                elseif kind=="Cash" then ok=isValidFloorCash(part)
                elseif kind=="Dumpsters" then ok=isDumpsterPart(part)
                elseif kind=="ATMs" then ok=isAtmPart(part) end
                if ok and not memoryFresh(memoryKey, part) then
                    local dist = (fromPos - part.Position).Magnitude
                    if dist < bestDist then
                        bestDist=dist
                        best=part
                        bestPrompt=pr
                    end
                end
            end
        end
    end
    return best, bestPrompt, bestDist
end

-- movement
local function chainTeleport(pos, countAsFarm, lift)
    return AS.tpTo(pos + Vector3.new(0, lift or tunables.tpStandOffset, 0), nil, countAsFarm)
end

local function tweenLeg(targetCFrame)
    local hrp = AS.getHRP()
    if not hrp then return false end
    local cam = workspace.CurrentCamera
    if cam then
        local hum = AS.getHumanoid()
        if hum then
            cam.CameraType=Enum.CameraType.Custom
            cam.CameraSubject=hum
        end
    end
    local dist = (hrp.Position - targetCFrame.Position).Magnitude
    if dist < 0.5 then return true end
    local now = tick()
    local sinceLast = now - lastTweenTime
    if sinceLast < TWEEN_MIN_GAP then task.wait(TWEEN_MIN_GAP - sinceLast) end
    lastTweenTime = tick()
    tweenInFlight = true
    local t = TweenService:Create(
        hrp,
        TweenInfo.new(math.max(dist/TWEEN_SPEED,0.05), Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        { CFrame = targetCFrame }
    )
    t:Play()
    local waited = 0
    while t.PlaybackState == Enum.PlaybackState.Playing and waited < TWEEN_LEG_TIMEOUT do
        task.wait(0.03)
        waited = waited + 0.03
        if AS.getHRP() ~= hrp then tweenInFlight=false; return false end
    end
    local endHrp = AS.getHRP()
    if endHrp then
        endHrp.AssemblyLinearVelocity=Vector3.new(0,0,0)
        endHrp.AssemblyAngularVelocity=Vector3.new(0,0,0)
    end
    tweenInFlight = false
    return true
end

local function tweenToTargetXZ(targetPos)
    local hrp = AS.getHRP()
    if not hrp then return false end
    local hum = AS.getHumanoid()
    if hum then
        hum.PlatformStand=true
        hum.WalkSpeed=0
        hum.JumpPower=0
    end
    if math.abs(hrp.Position.Y - UNDER_Y) > 0.5 then
        hrp.CFrame = CFrame.new(hrp.Position.X, UNDER_Y, hrp.Position.Z)
    end
    tweenLeg(CFrame.new(targetPos.X, UNDER_Y, targetPos.Z))
    local endHrp = AS.getHRP()
    if endHrp and math.abs(endHrp.Position.Y - UNDER_Y) > 0.5 then
        endHrp.CFrame = CFrame.new(endHrp.Position.X, UNDER_Y, endHrp.Position.Z)
    end
    if hum then
        hum.PlatformStand=false
        hum.WalkSpeed=16
        hum.JumpPower=50
    end
    return true
end

local function moveTo(pos, countAsFarm, lift)
    if state.movement.mode == "Tween" then return tweenToTargetXZ(pos) end
    return chainTeleport(pos, countAsFarm, lift)
end

local function boxPathMove(targetPos)
    local hrp = AS.getHRP()
    if not hrp then return false end
    local hum = AS.getHumanoid()
    if hum then
        hum.PlatformStand=true
        hum.WalkSpeed=0
        hum.JumpPower=0
    end
    if state.movement.mode == "Tween" then
        if math.abs(hrp.Position.Y - UNDER_Y) > 0.5 then
            hrp.CFrame = CFrame.new(hrp.Position.X, UNDER_Y, hrp.Position.Z)
        end
        tweenLeg(CFrame.new(targetPos.X, UNDER_Y, targetPos.Z))
    else
        chainTeleport(targetPos, true)
    end
    if hum then
        hum.PlatformStand=false
        hum.WalkSpeed=16
        hum.JumpPower=50
    end
    return true
end

-- prompt firing
local function fireOwnPrompts(target)
    if not target or not target.Parent then return 0 end
    local fired = 0
    local dp = target:FindFirstChildWhichIsA("ProximityPrompt", false)
    if dp and dp.Enabled then
        AS.firePromptFast(dp)
        fired = fired + 1
    end
    for _, d in ipairs(target:GetDescendants()) do
        if d ~= dp and d:IsA("ProximityPrompt") and d.Enabled then
            AS.firePromptFast(d)
            fired = fired + 1
        end
    end
    return fired
end

local function firePromptsVeryClose(targetPart, radius)
    radius = radius or 2.5
    if not targetPart or not targetPart.Parent then return 0 end
    local basePos = targetPart.Position
    local fired = 0
    for _, pr in ipairs(promptIndex) do
        if pr.Enabled then
            local bp = promptBasePos(pr)
            if bp and (bp - basePos).Magnitude <= radius then
                AS.firePromptFast(pr)
                fired = fired + 1
            end
        end
    end
    return fired
end

local function fireRegisterCashSweep(reg, rp)
    for _=1,3 do
        if rp and rp.Enabled then AS.firePromptFast(rp) end
        task.wait(0.05)
    end
    task.wait(0.12)
    local regPos = reg.Position
    local nearby = {}
    for _, pr in ipairs(promptIndex) do
        if pr.Enabled then
            local root = pr.Parent
            local part = nil
            if root and root:IsA("BasePart") then
                part = root
            elseif root then
                part = root:FindFirstAncestorWhichIsA("BasePart")
            end
            if part and isValidFloorCash(part) and (part.Position - regPos).Magnitude <= REGISTER_CASH_RADIUS then
                table.insert(nearby, pr)
            end
        end
    end
    local sweepStart = tick()
    local lastFireAt = 0
    while tick() - sweepStart < (tunables.registerDwell * 3) do
        local fired = 0
        for _, pr in ipairs(nearby) do
            if pr.Enabled then AS.firePromptFast(pr); fired=fired+1 end
        end
        if fired > 0 then
            lastFireAt = tick()
        elseif lastFireAt > 0 and tick() - lastFireAt > 0.25 then
            break
        end
        task.wait(0.04)
    end
    for _, pr in ipairs(nearby) do
        if pr.Enabled then AS.firePromptFast(pr) end
    end
end

local function fireAllPromptsNear(pos, dwell, radius)
    radius = radius or BOX_PROMPT_RADIUS
    local t0 = tick()
    while tick() - t0 < dwell do
        for _, pr in ipairs(promptIndex) do
            if pr.Enabled then
                local bp = promptBasePos(pr)
                if bp and (bp - pos).Magnitude <= radius then AS.firePromptFast(pr) end
            end
        end
        task.wait(0.05)
    end
end

-- cache
local CACHE_CAP = 200
local PartCache = {
    cash={parts={},lastScan=0,interval=0.8},
    registers={parts={},lastScan=0,interval=0.8},
    dumpsters={parts={},lastScan=0,interval=0.8},
    atms={parts={},lastScan=0,interval=4.0},
}

local function warmCache()
    PartCache.cash.lastScan=0
    PartCache.registers.lastScan=0
    PartCache.dumpsters.lastScan=0
    PartCache.atms.lastScan=0
end

local function refreshCache(kind)
    local now = tick()
    if now - PartCache[kind].lastScan < PartCache[kind].interval and #PartCache[kind].parts > 0 then return end
    PartCache[kind].lastScan = now
    local out = {}
    local seen = {}
    for _, pr in ipairs(promptIndex) do
        if pr.Enabled then
            local root = pr.Parent
            local d = nil
            if root and root:IsA("BasePart") then
                d = root
            elseif root then
                d = root:FindFirstAncestorWhichIsA("BasePart")
            end
            if d and not seen[d] then
                local ok = false
                if kind=="cash" then ok=isValidFloorCash(d)
                elseif kind=="registers" then ok=isRegisterPart(d)
                elseif kind=="dumpsters" then ok=isDumpsterPart(d)
                elseif kind=="atms" then ok=isAtmPart(d) end
                if ok then
                    seen[d]=true
                    table.insert(out,d)
                end
            end
        end
        if #out >= CACHE_CAP then break end
    end
    PartCache[kind].parts = out
end

local function getCash()
    local hrp = AS.getHRP()
    if not hrp then return nil,nil end
    refreshCache("cash")
    local c,cp,cd = nil,nil,1e9
    for _, d in ipairs(PartCache.cash.parts) do
        if not memoryFresh("Cash", d) then
            local pr = d:FindFirstChildWhichIsA("ProximityPrompt", true)
            if pr and pr.Enabled then
                local dist=(hrp.Position-d.Position).Magnitude
                if dist<cd then cd=dist; c=d; cp=pr end
            end
        end
    end
    return c,cp
end

local function getRegisters()
    local hrp = AS.getHRP()
    if not hrp then return nil,nil end
    refreshCache("registers")
    local c,cp,cd = nil,nil,1e9
    for _, d in ipairs(PartCache.registers.parts) do
        if d.Parent and not memoryFresh("Register", d) then
            local pr = d:FindFirstChildWhichIsA("ProximityPrompt", true)
            if pr and pr.Parent and pr.Enabled then
                local dist=(hrp.Position-d.Position).Magnitude
                if dist<cd then cd=dist; c=d; cp=pr end
            end
        end
    end
    return c,cp
end

local function getATMs()
    local hrp = AS.getHRP()
    if not hrp then return nil,nil end
    refreshCache("atms")
    local c,cp,cd = nil,nil,1e9
    for _, d in ipairs(PartCache.atms.parts) do
        if d.Parent and not memoryFresh("ATM", d) then
            local pr = findPromptIn(d)
            if pr and pr.Parent and pr.Enabled and pr.Parent.Parent then
                local dist=(hrp.Position-d.Position).Magnitude
                if dist<cd then cd=dist; c=d; cp=pr end
            end
        end
    end
    return c,cp
end

local function getDumpsters()
    local list = {}
    local hrp = AS.getHRP()
    if not hrp then return list end
    refreshCache("dumpsters")
    for _, d in ipairs(PartCache.dumpsters.parts) do
        if d.Parent and not memoryFresh("Dumpster", d) then
            local pr = d:FindFirstChildWhichIsA("ProximityPrompt", true)
            if pr and pr.Enabled then
                table.insert(list, {
                    Part=d,
                    Prompt=pr,
                    Dist=(hrp.Position-d.Position).Magnitude
                })
            end
        end
    end
    table.sort(list, function(a,b) return a.Dist < b.Dist end)
    return list
end

-- reset
local function effectiveTpThreshold()
    return math.max(1, math.floor(TP_ACTIONS_BEFORE_RESET * EARLY_RESET_PERCENT + 0.5))
end

local function effectiveTweenThreshold()
    return math.max(1, math.floor(TWEEN_ACTIONS_BEFORE_RESET * EARLY_RESET_PERCENT + 0.5))
end

triggerReset = function(reason)
    print("[XENON] RESET — " .. tostring(reason))
    tpActionsSinceReset = 0
    tweenActionsSinceReset = 0
    if isResetting or hardResetInFlight then return end
    task.spawn(function() forceResetCharacter(true) end)
end

forceResetCharacter = function(force)
    if isResetting or hardResetInFlight then return end
    if not force and tick() - lastHardResetAt < HARD_RESET_MIN_GAP then return end
    lastHardResetAt = tick()
    hardResetInFlight = true
    isResetting = true
    teleportSystem.generation = teleportSystem.generation + 1
    teleportSystem.successfulTPs = 0
    teleportSystem.atmsSinceReset = 0
    tpActionsSinceReset = 0
    tweenActionsSinceReset = 0
    lastResetWallclock = tick()
    sweepMemory()
    sessionStats.recordReset()

    local E = ReplicatedStorage:FindFirstChild("Events")
    if E then
        local r = E:FindFirstChild("Reset")
        if r then
            for _=1,3 do
                pcall(function() r:FireServer("Reset") end)
                task.wait(0.08)
            end
        end
    end

    local old = localPlayer.Character
    local t = 0
    repeat
        task.wait(0.05)
        t = t + 0.05
        pcall(function()
            if E and E:FindFirstChild("Reset") then E.Reset:FireServer("Reset") end
        end)
    until (localPlayer.Character and localPlayer.Character ~= old and localPlayer.Character:FindFirstChild("HumanoidRootPart")) or t > 4

    task.wait(0.15)
    task.spawn(skipIntro)
    warmCache()
    teleportSystem.generation = teleportSystem.generation + 1
    isResetting = false
    hardResetInFlight = false
    print("[XENON]   reset complete")

    if selectedFarmKey and state.farms[selectedFarmKey] then
        task.spawn(function() startFarmModule(selectedFarmKey) end)
    else
        if state.movement.mode == "Tween" then forceIdleUnder() else forceIdle() end
    end
end

local function bumpAction()
    if state.movement.mode == "TP" then
        tpActionsSinceReset = tpActionsSinceReset + 1
        if tpActionsSinceReset >= effectiveTpThreshold() then triggerReset("TP threshold") end
    else
        tweenActionsSinceReset = tweenActionsSinceReset + 1
        if tweenActionsSinceReset >= effectiveTweenThreshold() then triggerReset("Tween threshold") end
    end
end

-- failsafe
local function failsafeLoop()
    print("[XENON] failsafe: waiting")
    if state.movement.mode == "Tween" then
        AS.tpTo(Vector3.new(IDLE_POS.X, UNDER_Y, IDLE_POS.Z))
    else
        AS.tpTo(IDLE_POS + Vector3.new(0, tunables.tpStandOffset, 0))
    end

    while state.running and failsafeActive do
        local remaining = FAILSAFE_COMBAT_COOLDOWN - (tick() - lastDamageAt)
        local hrp = AS.getHRP()
        if hrp and (hrp.Position - IDLE_POS).Magnitude > 20 then
            if state.movement.mode == "Tween" then
                AS.tpTo(Vector3.new(IDLE_POS.X, UNDER_Y, IDLE_POS.Z))
            else
                AS.tpTo(IDLE_POS + Vector3.new(0, tunables.tpStandOffset, 0))
            end
        end
        if remaining <= 0 then break end
        task.wait(0.5)
    end

    local hum = AS.getHumanoid()
    if not hum or hum.Health <= 0 then
        failsafeActive=false
        lastHealth=nil
        return
    end

    print("[XENON] failsafe: resetting")
    local E = ReplicatedStorage:FindFirstChild("Events")
    local r = E and E:FindFirstChild("Reset")
    if not r then failsafeActive=false; return end
    local old = localPlayer.Character
    local tt = tick()
    while state.running and failsafeActive and tick() - tt < 10 do
        pcall(function() r:FireServer("Reset") end)
        task.wait(0.4)
        local nc = localPlayer.Character
        if nc and nc ~= old and nc:FindFirstChild("HumanoidRootPart") then break end
    end
    task.wait(0.5)
    if selectedFarmKey and state.farms[selectedFarmKey] then
        startFarmModule(selectedFarmKey)
    else
        goToIdle()
    end
    failsafeActive=false
    lastHealth=nil
end

local function armFailsafe()
    if failsafeActive then return end
    failsafeActive = true
    lastDamageAt = tick()
    task.spawn(failsafeLoop)
end

local function onHumanoid(h)
    if healthConn then
        pcall(function() healthConn:Disconnect() end)
        healthConn=nil
    end
    lastHealth = h.Health
    local firstEvent = true
    healthConn = h.HealthChanged:Connect(function(nh)
        if not state.protection.DamageFailsafe then return end
        if firstEvent then firstEvent=false; lastHealth=nh; return end
        if nh >= lastHealth then lastHealth=nh; return end
        lastHealth = nh
        if nh <= 0 then return end
        armFailsafe()
    end)
end

local function attachFailsafe(c)
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h then
        local ok = pcall(function() h = c:WaitForChild("Humanoid",5) end)
        if not ok or not h then return end
    end
    onHumanoid(h)
end

if localPlayer.Character then attachFailsafe(localPlayer.Character) end
localPlayer.CharacterAdded:Connect(function(c)
    task.wait(0.5)
    attachFailsafe(c)
end)

-- fps / lowgfx
local function fpsBoostEnable()
    fpsBoostPrev = {
        GlobalShadows=Lighting.GlobalShadows,
        FogEnd=Lighting.FogEnd,
        Brightness=Lighting.Brightness,
        EDS=Lighting.EnvironmentDiffuseScale,
        ESS=Lighting.EnvironmentSpecularScale,
        QualityLevel=settings().Rendering.QualityLevel
    }
    pcall(function()
        Lighting.GlobalShadows=false
        Lighting.FogEnd=100000
        Lighting.Brightness=2
        Lighting.EnvironmentDiffuseScale=0
        Lighting.EnvironmentSpecularScale=0
    end)
    pcall(function() settings().Rendering.QualityLevel=Enum.QualityLevel.Level01 end)
end

local function fpsBoostDisable()
    if not fpsBoostPrev then return end
    pcall(function()
        Lighting.GlobalShadows=fpsBoostPrev.GlobalShadows
        Lighting.FogEnd=fpsBoostPrev.FogEnd
        Lighting.Brightness=fpsBoostPrev.Brightness
        Lighting.EnvironmentDiffuseScale=fpsBoostPrev.EDS
        Lighting.EnvironmentSpecularScale=fpsBoostPrev.ESS
        settings().Rendering.QualityLevel=fpsBoostPrev.QualityLevel
    end)
end

local function stripOne(i)
    if i:FindFirstAncestor("XenonESPFolder") or i:FindFirstAncestor("XenonFarmHighlights") then return end
    pcall(function()
        if i:IsA("ParticleEmitter") or i:IsA("Trail") or i:IsA("Smoke") or i:IsA("Fire") or i:IsA("Sparkles") or i:IsA("Beam") or i:IsA("BloomEffect") or i:IsA("BlurEffect") or i:IsA("ColorCorrectionEffect") or i:IsA("SunRaysEffect") or i:IsA("DepthOfFieldEffect") or i:IsA("Atmosphere") then
            i.Enabled=false
        end
        if i:IsA("Decal") or i:IsA("Texture") then i.Transparency=1 end
    end)
end

local function processStripQueue()
    if stripProcessing then return end
    stripProcessing = true
    task.spawn(function()
        while lowGfxEnabled and #stripQueue > 0 do
            local batch = 40
            while batch > 0 and #stripQueue > 0 do
                local item=table.remove(stripQueue)
                stripOne(item)
                batch=batch-1
            end
            RunService.Heartbeat:Wait()
        end
        stripProcessing = false
    end)
end

local function lowGfxEnable()
    if lowGfxEnabled then return end
    lowGfxEnabled = true
    lowGfxPrev = {
        QualityLevel=settings().Rendering.QualityLevel,
        GlobalShadows=Lighting.GlobalShadows,
        FogEnd=Lighting.FogEnd,
        Brightness=Lighting.Brightness,
        Ambient=Lighting.Ambient,
        OutdoorAmbient=Lighting.OutdoorAmbient,
        EDS=Lighting.EnvironmentDiffuseScale,
        ESS=Lighting.EnvironmentSpecularScale
    }
    pcall(function() settings().Rendering.QualityLevel=Enum.QualityLevel.Level01 end)
    pcall(function()
        Lighting.GlobalShadows=false
        Lighting.FogEnd=100000
        Lighting.Brightness=1
        Lighting.Ambient=Color3.fromRGB(120,120,120)
        Lighting.OutdoorAmbient=Color3.fromRGB(120,120,120)
        Lighting.EnvironmentDiffuseScale=0
        Lighting.EnvironmentSpecularScale=0
    end)
    for _, d in ipairs(Workspace:GetDescendants()) do table.insert(stripQueue,d) end
    for _, d in ipairs(Lighting:GetDescendants()) do table.insert(stripQueue,d) end
    processStripQueue()
    table.insert(lowGfxConns, Workspace.DescendantAdded:Connect(function(d)
        if not lowGfxEnabled then return end
        table.insert(stripQueue,d)
        processStripQueue()
    end))
    table.insert(lowGfxConns, Lighting.DescendantAdded:Connect(function(d)
        if not lowGfxEnabled then return end
        table.insert(stripQueue,d)
        processStripQueue()
    end))
end

local function lowGfxDisable()
    lowGfxEnabled=false
    stripQueue={}
    if lowGfxPrev then
        pcall(function() settings().Rendering.QualityLevel=lowGfxPrev.QualityLevel end)
        pcall(function()
            Lighting.GlobalShadows=lowGfxPrev.GlobalShadows
            Lighting.FogEnd=lowGfxPrev.FogEnd
            Lighting.Brightness=lowGfxPrev.Brightness
            Lighting.Ambient=lowGfxPrev.Ambient
            Lighting.OutdoorAmbient=lowGfxPrev.OutdoorAmbient
            Lighting.EnvironmentDiffuseScale=lowGfxPrev.EDS
            Lighting.EnvironmentSpecularScale=lowGfxPrev.ESS
        end)
    end
    for _, c in ipairs(lowGfxConns) do pcall(function() c:Disconnect() end) end
    lowGfxConns = {}
    lowGfxPrev = nil
end

-- ESP
local ESP_FOLDER_NAME = "XenonESPFolder"
local ESPFolder = workspace:FindFirstChild(ESP_FOLDER_NAME)
if not ESPFolder then
    ESPFolder=Instance.new("Folder")
    ESPFolder.Name=ESP_FOLDER_NAME
    ESPFolder.Parent=workspace
end

local function createESP(player)
    if player == localPlayer or trackedPlayers[player] then return end
    local d = {
        Highlight=Instance.new("Highlight"),
        Billboard=Instance.new("BillboardGui"),
        TextLabel=Instance.new("TextLabel"),
        Box=Instance.new("BoxHandleAdornment")
    }
    d.Highlight.FillColor=THEME.Green
    d.Highlight.OutlineColor=Color3.fromRGB(255,255,255)
    d.Highlight.FillTransparency=0.5
    d.Highlight.OutlineTransparency=0
    d.Highlight.Parent=ESPFolder
    d.Highlight.Enabled=false

    d.Billboard.Size=UDim2.new(0,200,0,50)
    d.Billboard.StudsOffset=Vector3.new(0,3,0)
    d.Billboard.AlwaysOnTop=true
    d.Billboard.Parent=ESPFolder
    d.Billboard.Enabled=false

    d.TextLabel.Size=UDim2.new(1,0,1,0)
    d.TextLabel.BackgroundTransparency=1
    d.TextLabel.TextColor3=Color3.fromRGB(255,255,255)
    d.TextLabel.TextStrokeTransparency=0
    d.TextLabel.TextSize=14
    d.TextLabel.Font=FONT
    d.TextLabel.Text=player.Name
    d.TextLabel.Parent=d.Billboard

    d.Box.Size=Vector3.new(4,5,2)
    d.Box.Color3=THEME.Green
    d.Box.Transparency=0.7
    d.Box.AlwaysOnTop=true
    d.Box.ZIndex=5
    d.Box.Parent=ESPFolder
    d.Box.Visible=false

    trackedPlayers[player] = d
end

local function removeESP(player)
    local d = trackedPlayers[player]
    if d then
        if d.Highlight then d.Highlight:Destroy() end
        if d.Billboard then d.Billboard:Destroy() end
        if d.Box then d.Box:Destroy() end
        trackedPlayers[player] = nil
    end
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= localPlayer then createESP(p) end
end

Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(removeESP)

local lastESPUpdate = 0
RunService.Heartbeat:Connect(function()
    if not playerESPEnabled then return end
    local now = tick()
    if now - lastESPUpdate < 0.5 then return end
    lastESPUpdate = now
    local lr = AS.getHRP()
    if not lr then return end
    for player, d in pairs(trackedPlayers) do
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if char and root and hum and hum.Health > 0 then
            d.Highlight.Adornee=char
            d.Billboard.Adornee=root
            d.Box.Adornee=root
            d.TextLabel.Text = string.format("%s\n[%d m]", player.Name, math.floor((root.Position-lr.Position).Magnitude))
            d.Highlight.Enabled=true
            d.Billboard.Enabled=true
            d.Box.Visible=true
        else
            d.Highlight.Adornee=nil
            d.Billboard.Adornee=nil
            d.Box.Adornee=nil
            d.Highlight.Enabled=false
            d.Billboard.Enabled=false
            d.Box.Visible=false
        end
    end
end)

-- Red farm highlight colors
local farmHighlights = {
    Registers={enabled=false,color=THEME.Green,objects={},label="Register"},
    Cash={enabled=false,color=Color3.fromRGB(255,90,105),objects={},label="Cash"},
    Dumpsters={enabled=false,color=Color3.fromRGB(190,25,40),objects={},label="Dumpster"},
    ATMs={enabled=false,color=Color3.fromRGB(235,55,75),objects={},label="ATM"},
}

local FARM_FOLDER = "XenonFarmHighlights"
local farmFolder = workspace:FindFirstChild(FARM_FOLDER)
if not farmFolder then
    farmFolder=Instance.new("Folder")
    farmFolder.Name=FARM_FOLDER
    farmFolder.Parent=workspace
end

local function resolveOutlineTarget(part)
    if not part then return nil end
    if part:IsA("BasePart") then
        local model = part:FindFirstAncestorOfClass("Model")
        if model and #model:GetDescendants() <= 40 then return model end
    end
    return part
end

local function clearHighlightEntry(t, target)
    local data = farmHighlights[t].objects[target]
    if data then
        if data.Highlight then data.Highlight:Destroy() end
        if data.Billboard then data.Billboard:Destroy() end
        farmHighlights[t].objects[target] = nil
    end
end

local function createFarmHighlight(part, t)
    local target = resolveOutlineTarget(part)
    if not target then return end
    if farmHighlights[t].objects[target] then clearHighlightEntry(t, target) end
    local hl = Instance.new("Highlight")
    hl.Adornee=target
    hl.FillColor=farmHighlights[t].color
    hl.OutlineColor=Color3.fromRGB(255,255,255)
    hl.FillTransparency=0.7
    hl.OutlineTransparency=0
    hl.DepthMode=Enum.HighlightDepthMode.Occluded
    hl.Parent=farmFolder
    hl.Enabled=farmHighlights[t].enabled

    local bb = Instance.new("BillboardGui")
    bb.Size=UDim2.new(0,120,0,30)
    bb.StudsOffset=Vector3.new(0,3,0)
    bb.AlwaysOnTop=true
    bb.Parent=farmFolder
    bb.Enabled=farmHighlights[t].enabled

    local lb = Instance.new("TextLabel")
    lb.Size=UDim2.new(1,0,1,0)
    lb.BackgroundTransparency=1
    lb.TextColor3=Color3.fromRGB(255,255,255)
    lb.TextStrokeTransparency=0
    lb.TextSize=12
    lb.Font=FONT
    lb.Text=farmHighlights[t].label
    lb.Parent=bb

    bb.Adornee = target
    farmHighlights[t].objects[target] = {
        Highlight=hl,
        Billboard=bb,
        Label=lb,
        Part=target
    }
end

local lastHighlightScan = { Registers=0, Cash=0, Dumpsters=0, ATMs=0 }
local HIGHLIGHT_SCAN_DEBOUNCE = 3.0

local function scanAndHighlight(t)
    local now = tick()
    if now - lastHighlightScan[t] < HIGHLIGHT_SCAN_DEBOUNCE then return end
    lastHighlightScan[t] = now
    for target, _ in pairs(farmHighlights[t].objects) do clearHighlightEntry(t, target) end
    if not farmHighlights[t].enabled then return end
    local seenTargets = {}
    for _, pr in ipairs(promptIndex) do
        if pr.Enabled then
            local root = pr.Parent
            local d = nil
            if root and root:IsA("BasePart") then
                d = root
            elseif root then
                d = root:FindFirstAncestorWhichIsA("BasePart")
            end
            if d then
                local yes = false
                if t=="Registers" then yes=isRegisterPart(d)
                elseif t=="Cash" then yes=isValidFloorCash(d)
                elseif t=="Dumpsters" then yes=isDumpsterPart(d)
                elseif t=="ATMs" then yes=isAtmPart(d) end
                if yes then
                    local target = resolveOutlineTarget(d)
                    if target and not seenTargets[target] then
                        seenTargets[target]=true
                        createFarmHighlight(d, t)
                    end
                end
            end
        end
    end
end

task.spawn(function()
    while state.running do
        if state.currentTab == "ESP" then
            for t, data in pairs(farmHighlights) do
                if data.enabled then pcall(function() scanAndHighlight(t) end) end
            end
            task.wait(3.0)
        else
            task.wait(1.0)
        end
    end
end)

-- ============================================================
-- ADMIN ROSTER
-- ============================================================

local ADMIN_ROSTER = {
    { userId=7057703919, username="u_nregretful", display="McChickenpls" },
    { userId=8949298535, username="nsomniakk",    display="nso" },
    { userId=1922797141, username="GamerGardenia",display="Matcha" },
    { userId=1129299091, username="emiromania3",  display="emiromania3" },
    { userId=335940915,  username="TrueMystic04", display="Mystic" },
    { userId=2393081430, username="Be1ahu",       display="Belahu" },
    { userId=93463931,   username="SithJJ",       display="SithJJ" },
}

local WATCHLIST = {}
for _, e in ipairs(ADMIN_ROSTER) do
    WATCHLIST[e.userId] = { username = e.username, display = e.display }
end

local antiAdmin = {
    enabled=true,
    autoLeave=true,
    checkInterval=4,
    isHandlingAdmin=false
}

local function getAdminRosterSnapshot()
    local inServer = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer and WATCHLIST[p.UserId] then
            inServer[p.UserId] = p.Name
        end
    end
    local out = {}
    for _, e in ipairs(ADMIN_ROSTER) do
        table.insert(out, {
            userId = e.userId,
            username = e.username,
            display = e.display,
            inServer = inServer[e.userId] ~= nil,
            playerName = inServer[e.userId],
        })
    end
    return out
end

local function checkWatchlistInServer()
    local found = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer and WATCHLIST[p.UserId] then
            table.insert(found, p.Name)
        end
    end
    return found
end

local function handleAdminDetection(reason)
    if antiAdmin.isHandlingAdmin then return end
    antiAdmin.isHandlingAdmin = true
    print("[XENON] ADMIN DETECTED — " .. reason)
    task.wait(0.4)
    local tp = (syn and syn.teleport) or (fluxus and fluxus.teleport) or nil
    if tp then pcall(function() tp(game.PlaceId) end); return end
    pcall(function() TeleportService:Teleport(game.PlaceId) end)
end

local rejoinInFlight = false
local lastRejoinAt = 0

local function tryRejoin()
    if rejoinInFlight then return end
    if tick() - lastRejoinAt < 10 then return end
    rejoinInFlight = true
    lastRejoinAt = tick()
    local jobId = game.JobId
    local placeId = game.PlaceId
    print("[XENON] network-disconnect rejoin: job " .. tostring(jobId))
    task.wait(0.2)
    if jobId and #jobId > 0 then
        local ok = pcall(function()
            TeleportService:TeleportToPlaceInstance(placeId, jobId, localPlayer)
        end)
        if ok then rejoinInFlight = false; return end
    end
    pcall(function() TeleportService:Teleport(placeId) end)
    rejoinInFlight = false
end

pcall(function()
    GuiService.ErrorMessageChanged:Connect(function(msg)
        if msg and msg ~= "" then
            print("[XENON] GuiService error: " .. tostring(msg))
            task.spawn(function()
                task.wait(0.5)
                tryRejoin()
            end)
        end
    end)
end)

pcall(function()
    TeleportService.TeleportInitFailed:Connect(function(player, result, errMsg)
        if player ~= localPlayer then return end
        print("[XENON] teleport failed: " .. tostring(result) .. " " .. tostring(errMsg))
        task.spawn(function()
            task.wait(1)
            if not rejoinInFlight then tryRejoin() end
        end)
    end)
end)

task.spawn(function()
    task.wait(2)
    while state.running and antiAdmin.enabled do
        task.wait(antiAdmin.checkInterval)
        local hits = checkWatchlistInServer()
        if #hits > 0 and antiAdmin.autoLeave then
            handleAdminDetection("WATCHLIST")
            break
        end
    end
end)

-- boxes farm
local function fireBoxJobEvent(action)
    local E = ReplicatedStorage:FindFirstChild("Events")
    if not E then return false end
    local we = E:FindFirstChild("WeaponEvent")
    if not we then return false end
    pcall(function() we:FireServer("StartOrEndJob", action) end)
    return true
end

local function boxesFarmLoop(myGen)
    if not fireBoxJobEvent("BOX JOB") then
        warn("[XENON] boxes: WeaponEvent missing")
        state.farms.BoxesFarm=false
        return
    end
    while state.farms.BoxesFarm and state.running do
        if myGen ~= boxesFarmGeneration then return end
        if failsafeActive or isResetting or isRagdolled then task.wait(0.4); continue end
        boxPathMove(BOX_PICKUP_POS, true)
        task.wait(0.10)
        fireAllPromptsNear(BOX_PICKUP_POS, BOX_PICKUP_DWELL, BOX_PROMPT_RADIUS)
        if not state.farms.BoxesFarm then break end
        bumpAction()
        boxPathMove(BOX_DROPOFF_POS, false)
        task.wait(0.10)
        fireAllPromptsNear(BOX_DROPOFF_POS, BOX_DROPOFF_DWELL, BOX_PROMPT_RADIUS)
        bumpAction()
        task.wait(BOX_REWARD_COOLDOWN + BOX_LOOP_DELAY)
    end
    fireBoxJobEvent("None")
end

local function startBoxesFarm()
    if state.farms.BoxesFarm then return end
    state.farms.BoxesFarm = true
    selectedFarmKey = "BoxesFarm"
    boxesFarmGeneration = boxesFarmGeneration + 1
    local myGen = boxesFarmGeneration
    task.spawn(function()
        local ok,err = pcall(boxesFarmLoop, myGen)
        if not ok then warn("[XENON] BoxesFarm: "..tostring(err)) end
    end)
end

local function stopBoxesFarm()
    if not state.farms.BoxesFarm then
        fireBoxJobEvent("None")
        return
    end
    state.farms.BoxesFarm = false
    boxesFarmGeneration = boxesFarmGeneration + 1
    fireBoxJobEvent("None")
    if selectedFarmKey == "BoxesFarm" then selectedFarmKey = nil end
    task.spawn(function()
        if state.movement.mode == "Tween" then forceIdleUnder() else forceIdle() end
    end)
end

-- ============================================================
-- SUPER FARM LOOP
-- ============================================================

local function superFarmLoop(myGen)
    superFarmRunning = true
    superFarmLastTick = tick()
    sessionStats.start()
    local passesSinceLive = 0

    while state.farms.SuperFarm and state.running do
        superFarmLastTick = tick()
        if failsafeActive or isResetting or isRagdolled then task.wait(0.4); continue end
        if myGen ~= teleportSystem.generation then superFarmRunning=false; return end
        if (tick() - lastResetWallclock) >= RESET_WALLCLOCK_INTERVAL then
            triggerReset("wallclock")
            superFarmRunning=false
            return
        end

        local hrp = AS.getHRP()
        if not hrp then task.wait(0.25); continue end
        local here = hrp.Position
        local candidates = {}
        local t = state.superTargets

        if t.Registers then
            local reg, rp = getRegisters()
            if reg and rp then
                table.insert(candidates, {
                    kind="Registers", part=reg, prompt=rp,
                    dist=(here-reg.Position).Magnitude, priority=1
                })
            end
        end

        if t.ATMs then
            local atm, ap = getATMs()
            if atm and ap and ap.Parent and ap.Enabled then
                table.insert(candidates, {
                    kind="ATMs", part=atm, prompt=ap,
                    dist=(here-atm.Position).Magnitude, priority=2
                })
            end
        end

        if t.Cash then
            local c, cp = getCash()
            if c and cp then
                table.insert(candidates, {
                    kind="Cash", part=c, prompt=cp,
                    dist=(here-c.Position).Magnitude, priority=3
                })
            end
        end

        if t.Dumpsters then
            local ds = getDumpsters()
            if #ds > 0 then
                table.insert(candidates, {
                    kind="Dumpsters", part=ds[1].Part, prompt=ds[1].Prompt,
                    dist=ds[1].Dist, priority=4
                })
            end
        end

        passesSinceLive = passesSinceLive + 1
        if #candidates == 0 and passesSinceLive >= 1 then
            passesSinceLive = 0
            warmCache()
            if t.Registers then
                local p,pr = liveFindClosest("Registers", here, "Register")
                if p and pr then
                    table.insert(candidates,{
                        kind="Registers",part=p,prompt=pr,
                        dist=(here-p.Position).Magnitude,priority=1
                    })
                end
            end
            if t.ATMs then
                local p,pr = liveFindClosest("ATMs", here, "ATM")
                if p and pr then
                    table.insert(candidates,{
                        kind="ATMs",part=p,prompt=pr,
                        dist=(here-p.Position).Magnitude,priority=2
                    })
                end
            end
            if t.Cash then
                local p,pr = liveFindClosest("Cash", here, "Cash")
                if p and pr then
                    table.insert(candidates,{
                        kind="Cash",part=p,prompt=pr,
                        dist=(here-p.Position).Magnitude,priority=3
                    })
                end
            end
            if t.Dumpsters then
                local p,pr = liveFindClosest("Dumpsters", here, "Dumpster")
                if p and pr then
                    table.insert(candidates,{
                        kind="Dumpsters",part=p,prompt=pr,
                        dist=(here-p.Position).Magnitude,priority=4
                    })
                end
            end
        end

        if #candidates == 0 then
            if state.movement.mode == "Tween" then forceIdleUnder() else forceIdle() end
            task.wait(SCAN_LIVE_INTERVAL)
        else
            table.sort(candidates, function(a,b)
                if a.priority ~= b.priority then return a.priority < b.priority end
                return a.dist < b.dist
            end)

            local pick = candidates[1]
            local kind, part, prompt = pick.kind, pick.part, pick.prompt

            if not part.Parent or not prompt.Enabled then
                markMemory(kind, part)
                markMemory(kind, prompt)
                task.wait(0.05)
            else
                if kind == "Registers" then
                    moveTo(part.Position, true)
                    task.wait(0.10)
                    fireRegisterCashSweep(part, prompt)
                    markMemory("Register", part)
                    markMemory("Register", prompt)
                    sessionStats.recordPickup("Registers")
                    task.wait(tunables.cashDwell)
                    bumpAction()

                elseif kind == "ATMs" then
                    moveTo(part.Position, true)
                    task.wait(0.10)
                    if not (prompt.Parent and prompt.Enabled) then
                        markMemory("ATM", part)
                    else
                        AS.firePromptHoldExact(prompt)
                        task.wait(ATM_CASH_SPAWN_WAIT)
                        local atmPos = part.Position
                        local t0 = tick()
                        local lastFireAt = 0
                        local firstFireAt = 0
                        local pickupRadius = ATM_PICKUP_RADIUS * 2.5

                        while tick() - t0 < (tunables.atmDwell + 1.5) do
                            local fired = 0
                            fired = fired + fireOwnPrompts(part)
                            for _, pr in ipairs(promptIndex) do
                                if pr.Enabled then
                                    local bp = promptBasePos(pr)
                                    if bp and (bp - atmPos).Magnitude <= pickupRadius then
                                        AS.firePromptFast(pr)
                                        fired = fired + 1
                                    end
                                end
                            end
                            for _, d in ipairs(Workspace:GetDescendants()) do
                                if d:IsA("BasePart") then
                                    local dn = string.lower(d.Name)
                                    local dp = d.Parent and string.lower(d.Parent.Name) or ""
                                    if (dn:find("cash") or dn:find("money") or dn == "part" or dp:find("cash") or dp:find("cashspawn")) and (d.Position - atmPos).Magnitude <= pickupRadius then
                                        local p2 = d:FindFirstChildWhichIsA("ProximityPrompt", true)
                                        if p2 and p2.Enabled then
                                            AS.firePromptFast(p2)
                                            fired = fired + 1
                                        else
                                            local hrp2 = AS.getHRP()
                                            if hrp2 and firetouchinterest then
                                                pcall(function()
                                                    firetouchinterest(hrp2, d, 0)
                                                    task.wait(0.02)
                                                    firetouchinterest(hrp2, d, 1)
                                                end)
                                                fired = fired + 1
                                            end
                                        end
                                    end
                                end
                            end
                            if fired > 0 then
                                lastFireAt = tick()
                                if firstFireAt == 0 then firstFireAt = tick() end
                            end
                            if firstFireAt > 0 and (tick() - lastFireAt) > 0.4 then break end
                            if firstFireAt == 0 and (tick() - t0) > (tunables.atmDwell + 1.2) then break end
                            task.wait(0.08)
                        end
                        markMemory("ATM", part)
                        markMemory("ATM", prompt)
                        teleportSystem.atmsSinceReset = teleportSystem.atmsSinceReset + 1
                        sessionStats.recordPickup("ATMs")
                        bumpAction()
                    end

                elseif kind == "Cash" then
                    moveTo(part.Position, true)
                    task.wait(0.10)
                    for _=1,3 do
                        firePromptsVeryClose(part, 3.5)
                        task.wait(0.05)
                    end
                    markMemory("Cash", part)
                    markMemory("Cash", prompt)
                    sessionStats.recordPickup("Cash")
                    task.wait(tunables.cashDwell)
                    bumpAction()

                elseif kind == "Dumpsters" then
                    moveTo(part.Position, true)
                    task.wait(0.10)
                    for _=1,2 do
                        firePromptsVeryClose(part, 2.5)
                        task.wait(0.06)
                    end
                    markMemory("Dumpster", part)
                    markMemory("Dumpster", prompt)
                    sessionStats.recordPickup("Dumpsters")
                    local remaining = getDumpsters()
                    if #remaining <= 1 then
                        task.wait(0.25)
                        if dumpsterSellRoutine then dumpsterSellRoutine() end
                    end
                    task.wait(tunables.cashDwell)
                    bumpAction()
                end
                task.wait(0.05)
            end
        end
    end
    superFarmRunning = false
end

-- dumpster sell
local PAWN_SHOP = Vector3.new(-1305.85, 2.39, -845.55)
local SELL_BTN = Vector2.new(559, 274)
local CLOSE_BTN = Vector2.new(946, 198)

dumpsterSellRoutine = function()
    if dumpsterSelling then return end
    dumpsterSelling = true
    moveTo(PAWN_SHOP, false)
    task.wait(0.12)

    local function count()
        local bp = localPlayer:FindFirstChild("Backpack")
        if not bp then return 0 end
        local c = 0
        for _, ch in ipairs(bp:GetChildren()) do
            if ch:IsA("Tool") or ch:IsA("HopperBin") then c=c+1 end
        end
        return c
    end

    local items = count()
    local tries = 0
    while items > 0 and tries < 20 do
        tries = tries + 1
        pcall(function()
            UserInputService:SetMouseLocation(SELL_BTN.X, SELL_BTN.Y)
            task.wait(0.02)
            UserInputService:MouseButton1Click(SELL_BTN)
        end)
        task.wait(0.06)
        items = count()
        if items == 0 then
            pcall(function()
                UserInputService:SetMouseLocation(CLOSE_BTN.X, CLOSE_BTN.Y)
                task.wait(0.02)
                UserInputService:MouseButton1Click(CLOSE_BTN)
            end)
            break
        end
    end
    dumpsterSelling = false
end

startFarmModule = function(name)
    if not state.farms[name] then
        task.spawn(function()
            if state.movement.mode=="Tween" then forceIdleUnder() else forceIdle() end
        end)
        return
    end
    if name == "SuperFarm" then
        if superFarmRunning and (tick() - superFarmLastTick) < 2 then return end
        local myGen = teleportSystem.generation
        task.spawn(function()
            local ok,err = pcall(superFarmLoop, myGen)
            if not ok then warn("[XENON] SuperFarm: "..tostring(err)) end
            superFarmRunning=false
        end)
        selectedFarmKey = name
        return
    end
    if name == "BoxesFarm" then
        startBoxesFarm()
        return
    end
end

task.spawn(function()
    while state.running do
        task.wait(SUPFERFARM_WATCHDOG_INTERVAL)
        if state.farms.SuperFarm then
            local age = tick() - superFarmLastTick
            if age > 6 and not isRagdolled then
                print(string.format("[XENON] watchdog: farm stale (%.1fs)", age))
                superFarmRunning = false
                warmCache()
                startFarmModule("SuperFarm")
            end
        end
    end
end)

task.spawn(function()
    while state.running do
        task.wait(30)
        pcall(sweepMemory)
    end
end)

-- nyra (gated)
local HOTEL_POS = Vector3.new(-574, 6, 120)

local BANK_WAVES = {
    {
        Vector3.new(-799,2,-33),Vector3.new(-794,2,-35),
        Vector3.new(-790,2,-36),Vector3.new(-791,2,-31),
        Vector3.new(-795,2,-31),Vector3.new(-798,2,-29),
        Vector3.new(-801,2,-30),Vector3.new(-803,2,-34)
    },
    {
        Vector3.new(-806,2,-35),Vector3.new(-807,2,-31),
        Vector3.new(-805,2,-26),Vector3.new(-801,2,-25),
        Vector3.new(-795,2,-26),Vector3.new(-792,2,-27),
        Vector3.new(-796,2,-22),Vector3.new(-800,2,-24)
    },
}

local CASINO_BASE = {
    Vector3.new(-1161,4,-776),Vector3.new(-1159,4,-781),
    Vector3.new(-1167,4,-779),Vector3.new(-1173,4,-775),
    Vector3.new(-1173,7,-784),Vector3.new(-1171,7,-788),
    Vector3.new(-1172,7,-792),Vector3.new(-1172,4,-798),
    Vector3.new(-1167,4,-801),Vector3.new(-1166,4,-795),
}

local CASINO_COORDS = {}
for _, base in ipairs(CASINO_BASE) do
    for _, ox in ipairs({-2,0,2}) do
        for _, oz in ipairs({-2,0,2}) do
            table.insert(CASINO_COORDS, Vector3.new(base.X+ox, base.Y, base.Z+oz))
        end
    end
end

local JEWELRY_COORDS = {
    Vector3.new(-601.44,6.42,-629.20),
    Vector3.new(-580.75,6.42,-641.73),
    Vector3.new(-581.68,6.39,-608.14),
    Vector3.new(-626.75,6.42,-628.86),
    Vector3.new(-651.22,6.42,-628.90),
    Vector3.new(-671.11,6.42,-608.31),
    Vector3.new(-670.99,6.42,-641.92),
}

local GUNPOWDER_COORDS = {
    Vector3.new(-1123,3,-320),Vector3.new(-1151,3,-334),
    Vector3.new(-1138,3,-355),Vector3.new(-1109,3,-341),
    Vector3.new(-1090,3,-326),Vector3.new(-1200,3,-312),
}

local SMUG_BUTTON_POS = Vector3.new(-1335.631103515625, -0.7788606286048889, -394.15838623046875)

-- Keep these original green/red checks: they detect the game's button state.
local function getButtonStateNyra(part)
    if not part then return "unknown" end
    local c = part.Color
    if (math.abs(c.R-196/255)<0.05 and math.abs(c.G-40/255)<0.05 and math.abs(c.B-28/255)<0.05) or part.BrickColor.Name=="Really red" or part.BrickColor.Name=="Bright red" then
        return "not_ready"
    end
    if (math.abs(c.R-75/255)<0.05 and math.abs(c.G-151/255)<0.05 and math.abs(c.B-75/255)<0.05) or part.BrickColor.Name=="Bright green" or part.BrickColor.Name=="Lime green" then
        return "ready"
    end
    return "waiting"
end

local function findFarmButton(buttonName, parentName)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name == buttonName and obj.Parent and obj.Parent.Name == parentName then
            return obj
        end
    end
    return nil
end

local function clearVaultCash()
    local bags = 0
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name=="Money Bag" and obj.Parent and obj.Parent.Name=="VaultCash" then
            local pr = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
            if pr and pr.Enabled then
                AS.firePromptFast(pr)
                bags=bags+1
                task.wait(0.1)
            end
        end
    end
    return bags
end

local function hotelDropoffAndReset()
    moveTo(HOTEL_POS, true)
    task.wait(0.3)
    AS.dwellNear(HOTEL_POS, 2.0, 12)
    clearVaultCash()
    forceResetCharacter()
    local w=0
    while w<6 do task.wait(0.25); w=w+0.25 end
end

local function bankLoop(myGen)
    while state.superTargets.Bank and state.running and NYRA_ENABLED do
        if failsafeActive or isResetting or isRagdolled then task.wait(0.4); continue end
        if myGen ~= teleportSystem.generation then return end
        local btn = findFarmButton("Start Robbery", "Buttons")
        if getButtonStateNyra(btn) ~= "ready" then task.wait(1.0); continue end
        moveTo(btn.Position, true)
        AS.firePromptAt(btn.Position, 3, 8)
        task.wait(BANK_WAIT_AFTER_BUTTON)
        local wave = BANK_WAVES[math.random(1, #BANK_WAVES)]
        for _, pos in ipairs(wave) do
            moveTo(pos, true)
            task.wait(0.03)
            AS.dwellNear(pos, 0.5, FARM_PROMPT_RADIUS)
            clearVaultCash()
        end
        hotelDropoffAndReset()
    end
end

local function casinoLoop(myGen)
    while state.superTargets.Casino and state.running and NYRA_ENABLED do
        if failsafeActive or isResetting or isRagdolled then task.wait(0.4); continue end
        if myGen ~= teleportSystem.generation then return end
        local btn = findFarmButton("Start Robbery", "Buttons")
        if getButtonStateNyra(btn) ~= "ready" then task.wait(1.0); continue end
        moveTo(btn.Position, true)
        AS.firePromptAt(btn.Position, 3, 8)
        task.wait(2)
        local grabs = 0
        for _, pos in ipairs(CASINO_COORDS) do
            moveTo(pos, true)
            task.wait(0.03)
            AS.dwellNear(pos, 0.5, FARM_PROMPT_RADIUS)
            clearVaultCash()
            grabs = grabs + 1
            if grabs % 8 == 0 then
                moveTo(HOTEL_POS, true)
                task.wait(0.3)
                AS.dwellNear(HOTEL_POS, 2.0, 12)
                clearVaultCash()
                forceResetCharacter()
                local w=0
                while w<6 do task.wait(0.25); w=w+0.25 end
            end
        end
        hotelDropoffAndReset()
    end
end

local function jewelryLoop(myGen)
    while state.superTargets.Jewelry and state.running and NYRA_ENABLED do
        if failsafeActive or isResetting then task.wait(0.4); continue end
        if myGen ~= teleportSystem.generation then return end
        if jewelryState.phase == 1 and jewelryState.lastFinishAt > 0 then
            local remaining = JEWELRY_POST_RESET_WAIT - (tick() - jewelryState.lastFinishAt)
            if remaining > 0 then
                local t0 = tick()
                while state.superTargets.Jewelry and state.running and tick() - t0 < remaining do
                    task.wait(0.5)
                end
                if not state.superTargets.Jewelry then return end
            end
            jewelryState.lastFinishAt = 0
        end
        if jewelryState.phase == 1 then
            for i = 1, math.min(JEWELRY_SPLIT_INDEX, #JEWELRY_COORDS) do
                moveTo(JEWELRY_COORDS[i], true)
                task.wait(0.03)
                AS.dwellNear(JEWELRY_COORDS[i], 0.5, FARM_PROMPT_RADIUS)
                clearVaultCash()
            end
            hotelDropoffAndReset()
            jewelryState.phase = 2
        else
            for i = JEWELRY_SPLIT_INDEX + 1, #JEWELRY_COORDS do
                moveTo(JEWELRY_COORDS[i], true)
                task.wait(0.03)
                AS.dwellNear(JEWELRY_COORDS[i], 0.5, FARM_PROMPT_RADIUS)
                clearVaultCash()
            end
            hotelDropoffAndReset()
            jewelryState.phase = 1
            jewelryState.lastFinishAt = tick()
        end
    end
end

local function gunpowderLoop(myGen)
    while state.superTargets.Gunpowder and state.running and NYRA_ENABLED do
        if failsafeActive or isResetting or isRagdolled then task.wait(0.4); continue end
        if myGen ~= teleportSystem.generation then return end
        local btn = findFarmButton("Start Smuggler's Run", "Head")
        if getButtonStateNyra(btn) ~= "ready" then task.wait(1.0); continue end
        moveTo(SMUG_BUTTON_POS, true)
        AS.firePromptAt(SMUG_BUTTON_POS, 3, 10)
        if btn then AS.firePromptAt(btn.Position, 3, 10) end
        task.wait(2)
        local idx = 1
        local t_start = tick()
        while tick() - t_start < 30 do
            local pos = GUNPOWDER_COORDS[idx]
            moveTo(pos, true)
            task.wait(0.03)
            AS.dwellNear(pos, 0.5, FARM_PROMPT_RADIUS)
            clearVaultCash()
            idx = idx % #GUNPOWDER_COORDS + 1
        end
        hotelDropoffAndReset()
    end
end

local nyraRunners = {
    Bank=bankLoop,
    Casino=casinoLoop,
    Jewelry=jewelryLoop,
    Gunpowder=gunpowderLoop
}

local nyraActive = {
    Bank=false,
    Casino=false,
    Jewelry=false,
    Gunpowder=false
}

RunService.Heartbeat:Connect(function()
    if not NYRA_ENABLED then return end
    for name, fn in pairs(nyraRunners) do
        if state.superTargets[name] and not nyraActive[name] then
            nyraActive[name] = true
            local myGen = teleportSystem.generation
            task.spawn(function()
                local ok,err = pcall(fn, myGen)
                if not ok then warn("[XENON] "..name..": "..tostring(err)) end
                nyraActive[name]=false
            end)
        end
        if not state.superTargets[name] then nyraActive[name] = false end
    end
end)

print("[XENON] ✓ nyra loops (gated)")

-- ============================================================
-- EXPORT
-- ============================================================

_G.Xenon = _G.Xenon or {}
local C = _G.Xenon

-- Compatibility alias for the separately hosted Part 2, if it still
-- expects the old global name.
_G.Cleaners = C

C.Players = Players
C.RunService = RunService
C.Workspace = Workspace
C.ReplicatedStorage = ReplicatedStorage
C.TweenService = TweenService
C.VirtualUser = VirtualUser
C.UserInputService = UserInputService
C.CoreGui = CoreGui
C.HttpService = HttpService
C.Lighting = Lighting
C.SoundService = SoundService
C.TeleportService = TeleportService
C.GuiService = GuiService
C.localPlayer = localPlayer
C.FONT = FONT
C.THEME = THEME
C.state = state
C.NYRA_ENABLED = NYRA_ENABLED
C.tunables = tunables
C.XenonConfig = XenonConfig

-- Compatibility property for Part 2 if it still references CleanersConfig.
C.CleanersConfig = XenonConfig

C.TP_ACTIONS_BEFORE_RESET = TP_ACTIONS_BEFORE_RESET
C.TWEEN_ACTIONS_BEFORE_RESET = TWEEN_ACTIONS_BEFORE_RESET
C.EARLY_RESET_PERCENT = EARLY_RESET_PERCENT
C.HARD_RESET_MIN_GAP = HARD_RESET_MIN_GAP
C.antiAdmin = antiAdmin
C.farmHighlights = farmHighlights
C.scanAndHighlight = scanAndHighlight
C.createESP = createESP
C.removeESP = removeESP
C.trackedPlayers = trackedPlayers
C.fpsBoostEnable = fpsBoostEnable
C.fpsBoostDisable = fpsBoostDisable
C.lowGfxEnable = lowGfxEnable
C.lowGfxDisable = lowGfxDisable
C.startBoxesFarm = startBoxesFarm
C.stopBoxesFarm = stopBoxesFarm
C.startFarmModule = startFarmModule
C.warmCache = warmCache
C.forceIdle = forceIdle
C.forceIdleUnder = forceIdleUnder
C.teleportSystem = teleportSystem
C.selectedFarmKey = selectedFarmKey
C.antiAFKConnection = antiAFKConnection
C.sessionStats = sessionStats
C.ADMIN_ROSTER = ADMIN_ROSTER
C.WATCHLIST = WATCHLIST
C.getAdminRosterSnapshot = getAdminRosterSnapshot
C.getAdminCount = function()
    return #ADMIN_ROSTER
end

print("[XENON] ✓ state exported to _G.Xenon")

-- load part2
task.wait(0.2)

local ok2, res2 = pcall(function()
    return game:HttpGet(PART2_URL, true)
end)

if not ok2 or type(res2) ~= "string" or #res2 < 100 then
    warn("[XENON] part2 fetch failed: " .. tostring(res2))
    return
end

local fn2, err2 = loadstring(res2)
if not fn2 then
    warn("[XENON] part2 loadstring failed: " .. tostring(err2))
    return
end

local okRun2, errRun2 = pcall(fn2)
if not okRun2 then
    warn("[XENON] part2 runtime error: " .. tostring(errRun2))
end

print("[XENON] ============================================")
print("[XENON] part1 DONE — part2 loaded")
print("[XENON] ============================================")
