local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local state = {
	AutoSpeed = true,
	SpeedDelay = 0.02, -- seconds; lower = faster, 0 = every frame
	AutoRebirth = false,
	Fly = false,
	Noclip = false,
}

local TOGGLE_SPEED_KEY = Enum.KeyCode.F
local TOGGLE_REBIRTH_KEY = Enum.KeyCode.R
local TOGGLE_FLY_KEY = Enum.KeyCode.T
local TOGGLE_NOCLIP_KEY = Enum.KeyCode.N
local TOGGLE_GUI_KEY = Enum.KeyCode.LeftShift
local TOGGLE_GUI_ALT_KEY = Enum.KeyCode.RightShift -- keep the old key working too

-- Rebirth references (filled in by the setup task below)
local RebirthData, RewardCalc, RebirthEvent, leaderstats, RebirthValue, statValue
local rebirthBusy = false

local character, humanoid, rootPart
local flyConnection, flyBody, noclipConnection, noclipAddedConnection
local originalCanCollide = {}
local FLY_SPEED = 50
local FLY_SMOOTHING = 8 -- higher = snappier, lower = floatier
local flyVelocity = Vector3.new(0, 0, 0)

local function make(className, props, children)
	local obj = Instance.new(className)
	for k, v in pairs(props or {}) do
		obj[k] = v
	end
	for _, child in ipairs(children or {}) do
		child.Parent = obj
	end
	return obj
end

local screenGui = make("ScreenGui", {
	Name = "XeonAutoSpeedGui",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})

local main = make("Frame", {
	Name = "Main",
	Size = UDim2.new(0, 280, 0, 360),
	Position = UDim2.new(0, 16, 0.5, -180),
	BackgroundColor3 = Color3.fromRGB(22, 24, 30),
	BorderSizePixel = 0,
	Active = true,
	Parent = screenGui,
}, {
	make("UICorner", { CornerRadius = UDim.new(0, 10) }),
	make("UIStroke", { Color = Color3.fromRGB(60, 70, 90), Thickness = 1 }),
})

make("TextLabel", {
	Size = UDim2.new(1, -20, 0, 40),
	Position = UDim2.new(0, 10, 0, 0),
	BackgroundTransparency = 1,
	Text = "Xeon Auto Speed + Rebirth",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamBold,
	TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = main,
})

make("TextLabel", {
	Size = UDim2.new(1, -20, 0, 18),
	Position = UDim2.new(0, 10, 0, 34),
	BackgroundTransparency = 1,
	Text = "F:Speed R:Rebirth T:Fly N:Noclip Shift:GUI",
	TextColor3 = Color3.fromRGB(150, 160, 175),
	Font = Enum.Font.Gotham,
	TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = main,
})

local statusLabel = make("TextLabel", {
	Size = UDim2.new(1, -20, 0, 20),
	Position = UDim2.new(0, 10, 1, -28),
	BackgroundTransparency = 1,
	Text = "Status: Ready",
	TextColor3 = Color3.fromRGB(140, 200, 140),
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = main,
})

local function setStatus(msg)
	statusLabel.Text = "Status: " .. msg
end

-- ===== Tabs: Main / TPs =====
local tabBar = make("Frame", {
	Name = "TabBar",
	Size = UDim2.new(0, 280, 0, 28),
	Position = UDim2.new(0, 16, 0.5, -214), -- sits just above the main panel
	BackgroundColor3 = Color3.fromRGB(22, 24, 30),
	BorderSizePixel = 0,
	Parent = screenGui,
}, {
	make("UICorner", { CornerRadius = UDim.new(0, 8) }),
	make("UIStroke", { Color = Color3.fromRGB(60, 70, 90), Thickness = 1 }),
})

local mainTabBtn = make("TextButton", {
	Size = UDim2.new(0.5, -3, 1, 0),
	Position = UDim2.new(0, 2, 0, 0),
	BackgroundColor3 = Color3.fromRGB(70, 110, 180),
	BorderSizePixel = 0,
	Text = "Main",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	Parent = tabBar,
}, { make("UICorner", { CornerRadius = UDim.new(0, 6) }) })

local tpTabBtn = make("TextButton", {
	Size = UDim2.new(0.5, -3, 1, 0),
	Position = UDim2.new(0.5, 1, 0, 0),
	BackgroundColor3 = Color3.fromRGB(35, 40, 52),
	BorderSizePixel = 0,
	Text = "TPs",
	TextColor3 = Color3.fromRGB(200, 205, 215),
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	Parent = tabBar,
}, { make("UICorner", { CornerRadius = UDim.new(0, 6) }) })

local tpFrame = make("Frame", {
	Name = "TPs",
	Size = UDim2.new(0, 280, 0, 360),
	Position = UDim2.new(0, 16, 0.5, -180),
	BackgroundColor3 = Color3.fromRGB(22, 24, 30),
	BorderSizePixel = 0,
	Active = true,
	Visible = false,
	Parent = screenGui,
}, {
	make("UICorner", { CornerRadius = UDim.new(0, 10) }),
	make("UIStroke", { Color = Color3.fromRGB(60, 70, 90), Thickness = 1 }),
})

make("TextLabel", {
	Size = UDim2.new(1, -20, 0, 22),
	Position = UDim2.new(0, 10, 0, 8),
	BackgroundTransparency = 1,
	Text = "Teleports",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = tpFrame,
})

local teleports = {
	{ label = "TP 1", pos = Vector3.new(13763, 0, -18525) },
	{ label = "TP 2", pos = Vector3.new(13888, 0, -18530) },
	{ label = "TP 3", pos = Vector3.new(13892, 0, 38846) },
	{ label = "TP 4", pos = Vector3.new(13768, 0, 38864) },
}

local function teleportTo(pos, label)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		setStatus("Teleport failed: no character")
		return false
	end

	local target = CFrame.new(pos)
	local ok = pcall(function()
		-- Re-apply for a few frames so a server correction doesn't snap you back.
		for _ = 1, 3 do
			if not hrp.Parent then break end
			hrp.CFrame = target
			hrp.Velocity = Vector3.new(0, 0, 0)
			task.wait()
		end
	end)

	setStatus(ok and ("Teleported to " .. label) or "Teleport failed")
	return ok
end

for i, tp in ipairs(teleports) do
	local btn = make("TextButton", {
		Size = UDim2.new(1, -20, 0, 32),
		Position = UDim2.new(0, 10, 0, 36 + (i - 1) * 40),
		BackgroundColor3 = Color3.fromRGB(45, 70, 120),
		BorderSizePixel = 0,
		Text = tp.label .. "  |  " .. tp.pos.X .. ", " .. tp.pos.Y .. ", " .. tp.pos.Z,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.Gotham,
		TextSize = 11,
		Parent = tpFrame,
	}, { make("UICorner", { CornerRadius = UDim.new(0, 6) }) })

	btn.MouseButton1Click:Connect(function()
		teleportTo(tp.pos, tp.label)
	end)
end

make("TextLabel", {
	Size = UDim2.new(1, -20, 0, 30),
	Position = UDim2.new(0, 10, 0, 206),
	BackgroundTransparency = 1,
	Text = "If the server snaps you back, turn off Fly and try again.",
	TextColor3 = Color3.fromRGB(150, 160, 175),
	Font = Enum.Font.Gotham,
	TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = tpFrame,
})

local activeTab = "Main"
local guiVisible = true

local function switchTab(name)
	activeTab = name
	main.Visible = guiVisible and name == "Main"
	tpFrame.Visible = guiVisible and name == "TPs"
	mainTabBtn.BackgroundColor3 = name == "Main" and Color3.fromRGB(70, 110, 180) or Color3.fromRGB(35, 40, 52)
	tpTabBtn.BackgroundColor3 = name == "TPs" and Color3.fromRGB(70, 110, 180) or Color3.fromRGB(35, 40, 52)
end

local function setGuiVisible(visible)
	guiVisible = visible
	tabBar.Visible = visible
	main.Visible = visible and activeTab == "Main"
	tpFrame.Visible = visible and activeTab == "TPs"
end

mainTabBtn.MouseButton1Click:Connect(function() switchTab("Main") end)
tpTabBtn.MouseButton1Click:Connect(function() switchTab("TPs") end)
switchTab("Main")

-- Drag (all panels move together)
do
	local panels = { main, tpFrame, tabBar }
	local dragging, dragStart, startPos
	for _, frame in ipairs(panels) do
		frame.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				startPos = {}
				for _, p in ipairs(panels) do
					startPos[p] = p.Position
				end
			end
		end)
	end
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			for _, p in ipairs(panels) do
				local sp = startPos[p]
				p.Position = UDim2.new(sp.X.Scale, sp.X.Offset + delta.X, sp.Y.Scale, sp.Y.Offset + delta.Y)
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

-- Auto Speed toggle
local row = make("Frame", {
	Size = UDim2.new(1, -20, 0, 34),
	Position = UDim2.new(0, 10, 0, 58),
	BackgroundColor3 = Color3.fromRGB(32, 35, 44),
	BorderSizePixel = 0,
	Parent = main,
}, { make("UICorner", { CornerRadius = UDim.new(0, 6) }) })

make("TextLabel", {
	Size = UDim2.new(1, -80, 1, 0),
	Position = UDim2.new(0, 10, 0, 0),
	BackgroundTransparency = 1,
	Text = "Auto Speed",
	TextColor3 = Color3.fromRGB(235, 235, 235),
	Font = Enum.Font.GothamSemibold,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = row,
})

local speedBtn = make("TextButton", {
	Size = UDim2.new(0, 56, 0, 24),
	Position = UDim2.new(1, -64, 0.5, -12),
	BackgroundColor3 = Color3.fromRGB(50, 180, 90),
	BorderSizePixel = 0,
	Text = "ON",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	Parent = row,
}, { make("UICorner", { CornerRadius = UDim.new(0, 6) }) })

local function refreshSpeed()
	speedBtn.Text = state.AutoSpeed and "ON" or "OFF"
	speedBtn.BackgroundColor3 = state.AutoSpeed and Color3.fromRGB(50, 180, 90) or Color3.fromRGB(180, 60, 60)
end

speedBtn.MouseButton1Click:Connect(function()
	state.AutoSpeed = not state.AutoSpeed
	refreshSpeed()
	setStatus("Auto Speed: " .. (state.AutoSpeed and "ON" or "OFF"))
end)

-- Speed delay control
local delayRow = make("Frame", {
	Size = UDim2.new(1, -20, 0, 34),
	Position = UDim2.new(0, 10, 0, 98),
	BackgroundColor3 = Color3.fromRGB(32, 35, 44),
	BorderSizePixel = 0,
	Parent = main,
}, { make("UICorner", { CornerRadius = UDim.new(0, 6) }) })

make("TextLabel", {
	Size = UDim2.new(0, 90, 1, 0),
	Position = UDim2.new(0, 10, 0, 0),
	BackgroundTransparency = 1,
	Text = "Speed Delay",
	TextColor3 = Color3.fromRGB(235, 235, 235),
	Font = Enum.Font.GothamSemibold,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = delayRow,
})

local delayBox = make("TextBox", {
	Size = UDim2.new(0, 70, 0, 24),
	Position = UDim2.new(1, -78, 0.5, -12),
	BackgroundColor3 = Color3.fromRGB(45, 48, 58),
	BorderSizePixel = 0,
	Text = tostring(state.SpeedDelay),
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.Gotham,
	TextSize = 12,
	ClearTextOnFocus = false,
	Parent = delayRow,
}, { make("UICorner", { CornerRadius = UDim.new(0, 6) }) })

delayBox.FocusLost:Connect(function()
	local n = tonumber(delayBox.Text)
	if n then
		state.SpeedDelay = math.clamp(n, 0, 5)
	end
	delayBox.Text = tostring(state.SpeedDelay)
	setStatus("Speed delay: " .. state.SpeedDelay)
end)

-- Auto Rebirth toggle + manual fire
local rebirthRow = make("Frame", {
	Size = UDim2.new(1, -20, 0, 34),
	Position = UDim2.new(0, 10, 0, 138),
	BackgroundColor3 = Color3.fromRGB(32, 35, 44),
	BorderSizePixel = 0,
	Parent = main,
}, { make("UICorner", { CornerRadius = UDim.new(0, 6) }) })

make("TextLabel", {
	Size = UDim2.new(0, 112, 1, 0),
	Position = UDim2.new(0, 10, 0, 0),
	BackgroundTransparency = 1,
	Text = "Auto Rebirth",
	TextColor3 = Color3.fromRGB(235, 235, 235),
	Font = Enum.Font.GothamSemibold,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = rebirthRow,
})

local nowBtn = make("TextButton", {
	Size = UDim2.new(0, 46, 0, 24),
	Position = UDim2.new(1, -116, 0.5, -12),
	BackgroundColor3 = Color3.fromRGB(70, 110, 180),
	BorderSizePixel = 0,
	Text = "NOW",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamBold,
	TextSize = 11,
	Parent = rebirthRow,
}, { make("UICorner", { CornerRadius = UDim.new(0, 6) }) })

local rebirthBtn = make("TextButton", {
	Size = UDim2.new(0, 56, 0, 24),
	Position = UDim2.new(1, -64, 0.5, -12),
	BackgroundColor3 = Color3.fromRGB(180, 60, 60),
	BorderSizePixel = 0,
	Text = "OFF",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	Parent = rebirthRow,
}, { make("UICorner", { CornerRadius = UDim.new(0, 6) }) })

local rebirthInfo = make("TextLabel", {
	Size = UDim2.new(1, -20, 0, 16),
	Position = UDim2.new(0, 10, 0, 176),
	BackgroundTransparency = 1,
	Text = "Rebirth: loading...",
	TextColor3 = Color3.fromRGB(170, 180, 200),
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = main,
})

local function refreshRebirth()
	rebirthBtn.Text = state.AutoRebirth and "ON" or "OFF"
	rebirthBtn.BackgroundColor3 = state.AutoRebirth and Color3.fromRGB(50, 180, 90) or Color3.fromRGB(180, 60, 60)
end

-- Fly toggle
local flyRow = make("Frame", {
	Size = UDim2.new(1, -20, 0, 34),
	Position = UDim2.new(0, 10, 0, 196),
	BackgroundColor3 = Color3.fromRGB(32, 35, 44),
	BorderSizePixel = 0,
	Parent = main,
}, { make("UICorner", { CornerRadius = UDim.new(0, 6) }) })

make("TextLabel", {
	Size = UDim2.new(1, -80, 1, 0),
	Position = UDim2.new(0, 10, 0, 0),
	BackgroundTransparency = 1,
	Text = "Fly (WASD / Space / Ctrl)",
	TextColor3 = Color3.fromRGB(235, 235, 235),
	Font = Enum.Font.GothamSemibold,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = flyRow,
})

local flyBtn = make("TextButton", {
	Size = UDim2.new(0, 56, 0, 24),
	Position = UDim2.new(1, -64, 0.5, -12),
	BackgroundColor3 = Color3.fromRGB(180, 60, 60),
	BorderSizePixel = 0,
	Text = "OFF",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	Parent = flyRow,
}, { make("UICorner", { CornerRadius = UDim.new(0, 6) }) })

-- Noclip toggle
local noclipRow = make("Frame", {
	Size = UDim2.new(1, -20, 0, 34),
	Position = UDim2.new(0, 10, 0, 234),
	BackgroundColor3 = Color3.fromRGB(32, 35, 44),
	BorderSizePixel = 0,
	Parent = main,
}, { make("UICorner", { CornerRadius = UDim.new(0, 6) }) })

make("TextLabel", {
	Size = UDim2.new(1, -80, 1, 0),
	Position = UDim2.new(0, 10, 0, 0),
	BackgroundTransparency = 1,
	Text = "Noclip",
	TextColor3 = Color3.fromRGB(235, 235, 235),
	Font = Enum.Font.GothamSemibold,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = noclipRow,
})

local noclipBtn = make("TextButton", {
	Size = UDim2.new(0, 56, 0, 24),
	Position = UDim2.new(1, -64, 0.5, -12),
	BackgroundColor3 = Color3.fromRGB(180, 60, 60),
	BorderSizePixel = 0,
	Text = "OFF",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	Parent = noclipRow,
}, { make("UICorner", { CornerRadius = UDim.new(0, 6) }) })

-- Fly speed control
local flySpeedRow = make("Frame", {
	Size = UDim2.new(1, -20, 0, 34),
	Position = UDim2.new(0, 10, 0, 272),
	BackgroundColor3 = Color3.fromRGB(32, 35, 44),
	BorderSizePixel = 0,
	Parent = main,
}, { make("UICorner", { CornerRadius = UDim.new(0, 6) }) })

make("TextLabel", {
	Size = UDim2.new(0, 90, 1, 0),
	Position = UDim2.new(0, 10, 0, 0),
	BackgroundTransparency = 1,
	Text = "Fly Speed",
	TextColor3 = Color3.fromRGB(235, 235, 235),
	Font = Enum.Font.GothamSemibold,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = flySpeedRow,
})

local flySpeedBox = make("TextBox", {
	Size = UDim2.new(0, 70, 0, 24),
	Position = UDim2.new(1, -78, 0.5, -12),
	BackgroundColor3 = Color3.fromRGB(45, 48, 58),
	BorderSizePixel = 0,
	Text = tostring(FLY_SPEED),
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.Gotham,
	TextSize = 12,
	ClearTextOnFocus = false,
	Parent = flySpeedRow,
}, { make("UICorner", { CornerRadius = UDim.new(0, 6) }) })

flySpeedBox.FocusLost:Connect(function()
	local n = tonumber(flySpeedBox.Text)
	if n then
		FLY_SPEED = math.clamp(n, 1, 300)
	end
	flySpeedBox.Text = tostring(FLY_SPEED)
	setStatus("Fly speed: " .. FLY_SPEED)
end)

-- Fly / Noclip
local function refreshFly()
	flyBtn.Text = state.Fly and "ON" or "OFF"
	flyBtn.BackgroundColor3 = state.Fly and Color3.fromRGB(50, 180, 90) or Color3.fromRGB(180, 60, 60)
end

local function refreshNoclip()
	noclipBtn.Text = state.Noclip and "ON" or "OFF"
	noclipBtn.BackgroundColor3 = state.Noclip and Color3.fromRGB(50, 180, 90) or Color3.fromRGB(180, 60, 60)
end

local function stopFly()
	if flyConnection then
		flyConnection:Disconnect()
		flyConnection = nil
	end

	if flyBody then
		pcall(function() flyBody:Destroy() end)
		flyBody = nil
	end

	flyVelocity = Vector3.new(0, 0, 0)

	if humanoid then
		pcall(function()
			-- Undo the old PlatformStand state so walking/flying works after toggling off.
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end)
	end

	if rootPart then
		pcall(function()
			rootPart.Velocity = Vector3.new(0, 0, 0)
			rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		end)
	end
end

local function startFly()
	stopFly()
	if not humanoid or not rootPart then return end

	-- No PlatformStand: it can leave the Humanoid stuck after the first toggle.
	-- Flying state + BodyVelocity gives smooth movement and restores cleanly.
	pcall(function()
		humanoid.PlatformStand = false
		humanoid:ChangeState(Enum.HumanoidStateType.Flying)
	end)

	flyBody = Instance.new("BodyVelocity")
	flyBody.Name = "XeonFlyVelocity"
	flyBody.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	flyBody.P = 10000
	flyBody.Velocity = Vector3.new(0, 0, 0)
	flyBody.Parent = rootPart

	-- Heartbeat provides the real frame delta, so speed stays frame-rate independent.
	flyConnection = RunService.Heartbeat:Connect(function(dt)
		if not state.Fly or not rootPart or not rootPart.Parent or not humanoid then return end
		if not flyBody or not flyBody.Parent then return end
		dt = math.clamp(dt, 0, 0.1)

		local dir = Vector3.new(0, 0, 0)
		local cf = rootPart.CFrame
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cf.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cf.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cf.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cf.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.C) then
			dir -= Vector3.new(0, 1, 0)
		end
		if dir.Magnitude > 0 then dir = dir.Unit end

		flyVelocity = flyVelocity:Lerp(dir * FLY_SPEED, math.clamp(dt * FLY_SMOOTHING, 0, 1))
		flyBody.Velocity = flyVelocity
	end)
end

local function setFly(on)
	state.Fly = on
	refreshFly()
	if on then
		startFly()
		setStatus("Fly: ON")
	else
		stopFly()
		setStatus("Fly: OFF")
	end
end

local function applyNoclipTo(obj)
	if obj:IsA("BasePart") and obj.CanCollide then
		if originalCanCollide[obj] == nil then
			originalCanCollide[obj] = true
		end
		obj.CanCollide = false
	end
end

local function stopNoclip()
	if noclipConnection then
		noclipConnection:Disconnect()
		noclipConnection = nil
	end
	if noclipAddedConnection then
		noclipAddedConnection:Disconnect()
		noclipAddedConnection = nil
	end
	for obj, value in pairs(originalCanCollide) do
		if obj and obj.Parent then
			obj.CanCollide = value
		end
	end
	table.clear(originalCanCollide)
end

local function startNoclip()
	stopNoclip()
	if not character then return end

	-- Cover parts added mid-session (tools, accessories, respawn limbs).
	noclipAddedConnection = character.DescendantAdded:Connect(function(obj)
		if state.Noclip then applyNoclipTo(obj) end
	end)

	-- Stepped runs before physics, so the collision change applies that same frame.
	noclipConnection = RunService.Stepped:Connect(function()
		if not state.Noclip or not character then return end
		for _, obj in ipairs(character:GetDescendants()) do
			applyNoclipTo(obj)
		end
	end)
end

local function setNoclip(on)
	state.Noclip = on
	refreshNoclip()
	if on then
		startNoclip()
		setStatus("Noclip: ON")
	else
		stopNoclip()
		setStatus("Noclip: OFF")
	end
end

flyBtn.MouseButton1Click:Connect(function()
	setFly(not state.Fly)
end)

noclipBtn.MouseButton1Click:Connect(function()
	setNoclip(not state.Noclip)
end)

local function setupCharacter(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	rootPart = char:WaitForChild("HumanoidRootPart")
	if state.Noclip then startNoclip() end
	if state.Fly then startFly() else stopFly() end
end

player.CharacterAdded:Connect(setupCharacter)
if player.Character then
	task.spawn(function()
		setupCharacter(player.Character)
	end)
end

local function readyToRebirth()
	local ok, result = pcall(function()
		return RebirthData ~= nil
			and type(RebirthData.canRebirth) == "function"
			and RebirthData.canRebirth(player) == true
	end)
	return ok and result == true
end

local function fireRebirth(manual)
	if not RebirthEvent then
		if manual then setStatus("Rebirth not available") end
		return false
	end
	if rebirthBusy then return false end
	if not readyToRebirth() then
		if manual then setStatus("Rebirth not ready") end
		return false
	end

	rebirthBusy = true
	local ok = pcall(function()
		RebirthEvent:FireServer()
	end)
	if ok then
		setStatus("Rebirth requested")
		-- Wait for the server to apply it so the auto loop doesn't double-fire.
		local elapsed = 0
		while readyToRebirth() and elapsed < 2 do
			elapsed += task.wait(0.1)
		end
		task.wait(0.2)
	else
		setStatus("Rebirth fire failed")
	end
	rebirthBusy = false
	return ok
end

rebirthBtn.MouseButton1Click:Connect(function()
	state.AutoRebirth = not state.AutoRebirth
	refreshRebirth()
	setStatus("Auto Rebirth: " .. (state.AutoRebirth and "ON" or "OFF"))
end)

nowBtn.MouseButton1Click:Connect(function()
	fireRebirth(true)
end)

-- Keybinds
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- Handle the GUI key BEFORE the gameProcessed check.
	-- LeftShift is often consumed by the game (sprint), which sets gameProcessed = true.
	if input.KeyCode == TOGGLE_GUI_KEY or input.KeyCode == TOGGLE_GUI_ALT_KEY then
		setGuiVisible(not guiVisible)
		return
	end

	if gameProcessed then return end
	if input.KeyCode == TOGGLE_SPEED_KEY then
		state.AutoSpeed = not state.AutoSpeed
		refreshSpeed()
		setStatus("Auto Speed: " .. (state.AutoSpeed and "ON" or "OFF"))
	elseif input.KeyCode == TOGGLE_REBIRTH_KEY then
		state.AutoRebirth = not state.AutoRebirth
		refreshRebirth()
		setStatus("Auto Rebirth: " .. (state.AutoRebirth and "ON" or "OFF"))
	elseif input.KeyCode == TOGGLE_FLY_KEY then
		setFly(not state.Fly)
	elseif input.KeyCode == TOGGLE_NOCLIP_KEY then
		setNoclip(not state.Noclip)
	end
end)

-- Auto Speed loop
task.spawn(function()
	local ok, increaseSpeed = pcall(function()
		return ReplicatedStorage:WaitForChild("IncreaseSpeed", 10)
	end)
	if not ok or not increaseSpeed then
		warn("[Xeon Auto Speed] IncreaseSpeed remote not found")
		setStatus("IncreaseSpeed not found")
		return
	end

	while true do
		if state.AutoSpeed then
			pcall(function()
				increaseSpeed:FireServer()
			end)
		end
		local d = tonumber(state.SpeedDelay) or 0.02
		if d <= 0 then
			task.wait()
		else
			task.wait(d)
		end
	end
end)

-- Rebirth setup + Auto Rebirth loop
task.spawn(function()
	local ok, err = pcall(function()
		RebirthData = require(ReplicatedStorage:WaitForChild("RebirthData", 10))
		RewardCalc = require(ReplicatedStorage:WaitForChild("RewardCalc", 10))
		RebirthEvent = ReplicatedStorage:WaitForChild("RebirthEvent", 10)
		leaderstats = player:WaitForChild("leaderstats", 10)
		RebirthValue = leaderstats:WaitForChild("Rebirth", 10)
		statValue = leaderstats:WaitForChild(RebirthData.STAT, 10)
	end)

	if not ok or not RebirthData or not RebirthEvent or not RebirthValue or not statValue then
		warn("[Xeon Auto Speed] Rebirth setup failed: " .. tostring(err))
		rebirthInfo.Text = "Rebirth: not available"
		setStatus("Rebirth not found")
		return
	end

	setStatus("Rebirth ready")
	print("[Xeon Auto Speed] Rebirth ready. Stat: " .. tostring(RebirthData.STAT))

	local function fmt(n)
		n = math.floor(n)
		if RewardCalc and type(RewardCalc.roundNumber) == "function" then
			return tostring(RewardCalc.roundNumber(n))
		end
		return tostring(n)
	end

	local function updateInfo()
		local okInfo, req = pcall(function()
			return RebirthData.requiredFor(RebirthValue.Value)
		end)
		if not okInfo or not req then return end
		local cur = statValue.Value
		rebirthInfo.Text = "Rebirth " .. RebirthValue.Value .. " -> " .. (RebirthValue.Value + 1)
			.. " | " .. fmt(math.min(cur, req)) .. " / " .. fmt(req) .. " " .. RebirthData.STAT
	end

	updateInfo()
	statValue:GetPropertyChangedSignal("Value"):Connect(updateInfo)
	RebirthValue:GetPropertyChangedSignal("Value"):Connect(updateInfo)

	while true do
		if state.AutoRebirth and readyToRebirth() then
			fireRebirth(false)
		end
		task.wait(0.1)
	end
end)

setStatus("Loaded")
print("[Xeon Auto Speed] Loaded. F=speed R=rebirth T=fly N=noclip LeftShift/RightShift=show/hide GUI. Tabs: Main / TPs")
