local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local TARGET_PLACE_ID = 140374914197602 -- Speed Clicker
if game.PlaceId ~= TARGET_PLACE_ID then
	warn("[Xenon] Wrong game. This script only runs in Speed Clicker (PlaceId " .. TARGET_PLACE_ID .. ").")
	return
end

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

local theme = {
	bg = Color3.fromRGB(17, 19, 27),
	card = Color3.fromRGB(29, 33, 45),
	cardAlt = Color3.fromRGB(37, 42, 58),
	cardHover = Color3.fromRGB(48, 55, 76),
	stroke = Color3.fromRGB(60, 69, 92),
	text = Color3.fromRGB(238, 241, 248),
	muted = Color3.fromRGB(151, 160, 180),
	accent = Color3.fromRGB(96, 130, 255),
	accentAlt = Color3.fromRGB(130, 100, 255),
	green = Color3.fromRGB(64, 190, 110),
	red = Color3.fromRGB(210, 78, 78),
	amber = Color3.fromRGB(255, 183, 94),
	tabActive = Color3.fromRGB(84, 118, 222),
	tabInactive = Color3.fromRGB(36, 41, 56),
}

local activeTab = "Main"
local guiVisible = true

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
	Name = "Xenon",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})

local WINDOW_W, WINDOW_H = 300, 470
local window = make("Frame", {
	Name = "Window",
	Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H),
	Position = UDim2.new(0, 16, 0.5, -WINDOW_H / 2),
	BackgroundColor3 = theme.bg,
	BorderSizePixel = 0,
	Active = true,
	Parent = screenGui,
}, {
	make("UICorner", { CornerRadius = UDim.new(0, 12) }),
	make("UIStroke", { Color = theme.stroke, Thickness = 1 }),
})

-- Accent strip along the top of the window.
make("Frame", {
	Name = "Accent",
	Size = UDim2.new(1, 0, 0, 3),
	BackgroundColor3 = theme.accent,
	BorderSizePixel = 0,
	Parent = window,
}, { make("UICorner", { CornerRadius = UDim.new(0, 3) }) })

make("TextLabel", {
	Size = UDim2.new(1, -24, 0, 28),
	Position = UDim2.new(0, 12, 0, 12),
	BackgroundTransparency = 1,
	Text = "Xenon",
	TextColor3 = theme.text,
	Font = Enum.Font.GothamBold,
	TextSize = 20,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = window,
})

make("TextLabel", {
	Size = UDim2.new(1, -24, 0, 16),
	Position = UDim2.new(0, 12, 0, 40),
	BackgroundTransparency = 1,
	Text = "F Speed | R Rebirth | T Fly | N Noclip | Shift GUI",
	TextColor3 = theme.muted,
	Font = Enum.Font.Gotham,
	TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = window,
})

-- ===== Tabs: Main / TPs =====
local tabBar = make("Frame", {
	Name = "TabBar",
	Size = UDim2.new(1, -24, 0, 30),
	Position = UDim2.new(0, 12, 0, 66),
	BackgroundColor3 = theme.card,
	BorderSizePixel = 0,
	Parent = window,
}, {
	make("UICorner", { CornerRadius = UDim.new(0, 8) }),
	make("UIStroke", { Color = theme.stroke, Thickness = 1 }),
})

local mainTabBtn = make("TextButton", {
	Size = UDim2.new(0.5, -2, 1, -4),
	Position = UDim2.new(0, 2, 0, 2),
	BackgroundColor3 = theme.tabActive,
	BorderSizePixel = 0,
	Text = "Main",
	TextColor3 = theme.text,
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	Parent = tabBar,
}, { make("UICorner", { CornerRadius = UDim.new(0, 6) }) })

local tpTabBtn = make("TextButton", {
	Size = UDim2.new(0.5, -2, 1, -4),
	Position = UDim2.new(0.5, 0, 0, 2),
	BackgroundColor3 = theme.tabInactive,
	BorderSizePixel = 0,
	Text = "TPs",
	TextColor3 = theme.muted,
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	Parent = tabBar,
}, { make("UICorner", { CornerRadius = UDim.new(0, 6) }) })

mainTabBtn.MouseEnter:Connect(function()
	if activeTab ~= "Main" then mainTabBtn.BackgroundColor3 = theme.cardAlt end
end)
mainTabBtn.MouseLeave:Connect(function()
	mainTabBtn.BackgroundColor3 = activeTab == "Main" and theme.tabActive or theme.tabInactive
end)
tpTabBtn.MouseEnter:Connect(function()
	if activeTab ~= "TPs" then tpTabBtn.BackgroundColor3 = theme.cardAlt end
end)
tpTabBtn.MouseLeave:Connect(function()
	tpTabBtn.BackgroundColor3 = activeTab == "TPs" and theme.tabActive or theme.tabInactive
end)

local content = make("Frame", {
	Name = "Content",
	Size = UDim2.new(1, -24, 1, -150),
	Position = UDim2.new(0, 12, 0, 102),
	BackgroundTransparency = 1,
	Parent = window,
})

local main = make("Frame", {
	Name = "Main",
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	Active = true,
	Parent = content,
})

local tpFrame = make("Frame", {
	Name = "TPs",
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	Active = true,
	Visible = false,
	Parent = content,
})

-- Footer / status bar
local footer = make("Frame", {
	Name = "Footer",
	Size = UDim2.new(1, -24, 0, 28),
	Position = UDim2.new(0, 12, 1, -34),
	BackgroundColor3 = theme.card,
	BorderSizePixel = 0,
	Parent = window,
}, {
	make("UICorner", { CornerRadius = UDim.new(0, 8) }),
	make("UIStroke", { Color = theme.stroke, Thickness = 1 }),
})

local statusDot = make("Frame", {
	Size = UDim2.new(0, 6, 0, 6),
	Position = UDim2.new(0, 12, 0.5, -3),
	BackgroundColor3 = theme.green,
	BorderSizePixel = 0,
	Parent = footer,
}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })

local statusLabel = make("TextLabel", {
	Size = UDim2.new(1, -38, 1, 0),
	Position = UDim2.new(0, 26, 0, 0),
	BackgroundTransparency = 1,
	Text = "Status: Ready",
	TextColor3 = theme.muted,
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = footer,
})

local function setStatus(msg)
	statusLabel.Text = "Status: " .. msg
end

local function sectionLabel(parent, text, y)
	return make("TextLabel", {
		Size = UDim2.new(1, -4, 0, 16),
		Position = UDim2.new(0, 2, 0, y),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = theme.muted,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	})
end

local function makeRow(parent, y, labelText, labelWidth)
	local row = make("Frame", {
		Size = UDim2.new(1, -4, 0, 34),
		Position = UDim2.new(0, 2, 0, y),
		BackgroundColor3 = theme.card,
		BorderSizePixel = 0,
		Parent = parent,
	}, {
		make("UICorner", { CornerRadius = UDim.new(0, 8) }),
		make("UIStroke", { Color = theme.stroke, Thickness = 1, Transparency = 0.35 }),
	})

	make("TextLabel", {
		Size = UDim2.new(0, labelWidth, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		BackgroundTransparency = 1,
		Text = labelText,
		TextColor3 = theme.text,
		Font = Enum.Font.GothamSemibold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	return row
end

local function makeToggle(parent, initialText, initialColor)
	return make("TextButton", {
		Size = UDim2.new(0, 58, 0, 26),
		Position = UDim2.new(1, -64, 0.5, -13),
		BackgroundColor3 = initialColor,
		BorderSizePixel = 0,
		Text = initialText,
		TextColor3 = theme.text,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		Parent = parent,
	}, { make("UICorner", { CornerRadius = UDim.new(0, 6) }) })
end

-- ===== Main tab controls =====
sectionLabel(main, "AUTOMATION", 2)

local speedRow = makeRow(main, 22, "Auto Speed", 150)
local speedBtn = makeToggle(speedRow, "ON", theme.green)

local delayRow = makeRow(main, 62, "Speed Delay", 96)
local delayBox = make("TextBox", {
	Size = UDim2.new(0, 70, 0, 24),
	Position = UDim2.new(1, -78, 0.5, -12),
	BackgroundColor3 = theme.cardAlt,
	BorderSizePixel = 0,
	Text = tostring(state.SpeedDelay),
	TextColor3 = theme.text,
	Font = Enum.Font.Gotham,
	TextSize = 12,
	ClearTextOnFocus = false,
	Parent = delayRow,
}, {
	make("UICorner", { CornerRadius = UDim.new(0, 6) }),
	make("UIStroke", { Color = theme.stroke, Thickness = 1, Transparency = 0.5 }),
})

delayBox.FocusLost:Connect(function()
	local n = tonumber(delayBox.Text)
	if n then
		state.SpeedDelay = math.clamp(n, 0, 5)
	end
	delayBox.Text = tostring(state.SpeedDelay)
	setStatus("Speed delay: " .. state.SpeedDelay)
end)

local rebirthRow = makeRow(main, 102, "Auto Rebirth", 112)
local nowBtn = make("TextButton", {
	Size = UDim2.new(0, 44, 0, 26),
	Position = UDim2.new(1, -114, 0.5, -13),
	BackgroundColor3 = theme.tabActive,
	BorderSizePixel = 0,
	Text = "NOW",
	TextColor3 = theme.text,
	Font = Enum.Font.GothamBold,
	TextSize = 11,
	Parent = rebirthRow,
}, { make("UICorner", { CornerRadius = UDim.new(0, 6) }) })

local rebirthBtn = makeToggle(rebirthRow, "OFF", theme.red)

local rebirthInfo = make("TextLabel", {
	Size = UDim2.new(1, -4, 0, 22),
	Position = UDim2.new(0, 2, 0, 142),
	BackgroundColor3 = theme.cardAlt,
	BorderSizePixel = 0,
	Text = "Rebirth: loading...",
	TextColor3 = theme.muted,
	Font = Enum.Font.Gotham,
	TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = main,
}, { make("UICorner", { CornerRadius = UDim.new(0, 6) }) })

sectionLabel(main, "MOVEMENT", 174)

local flyRow = makeRow(main, 194, "Fly (WASD / Space / Ctrl)", 176)
local flyBtn = makeToggle(flyRow, "OFF", theme.red)

local noclipRow = makeRow(main, 234, "Noclip", 150)
local noclipBtn = makeToggle(noclipRow, "OFF", theme.red)

local flySpeedRow = makeRow(main, 274, "Fly Speed", 96)
local flySpeedBox = make("TextBox", {
	Size = UDim2.new(0, 70, 0, 24),
	Position = UDim2.new(1, -78, 0.5, -12),
	BackgroundColor3 = theme.cardAlt,
	BorderSizePixel = 0,
	Text = tostring(FLY_SPEED),
	TextColor3 = theme.text,
	Font = Enum.Font.Gotham,
	TextSize = 12,
	ClearTextOnFocus = false,
	Parent = flySpeedRow,
}, {
	make("UICorner", { CornerRadius = UDim.new(0, 6) }),
	make("UIStroke", { Color = theme.stroke, Thickness = 1, Transparency = 0.5 }),
})

flySpeedBox.FocusLost:Connect(function()
	local n = tonumber(flySpeedBox.Text)
	if n then
		FLY_SPEED = math.clamp(n, 1, 300)
	end
	flySpeedBox.Text = tostring(FLY_SPEED)
	setStatus("Fly speed: " .. FLY_SPEED)
end)

-- ===== TPs tab =====
make("TextLabel", {
	Size = UDim2.new(1, -8, 0, 20),
	Position = UDim2.new(0, 4, 0, 2),
	BackgroundTransparency = 1,
	Text = "Teleport locations",
	TextColor3 = theme.text,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = tpFrame,
})

local tpList = make("ScrollingFrame", {
	Name = "TPList",
	Size = UDim2.new(1, -4, 1, -28),
	Position = UDim2.new(0, 2, 0, 26),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = theme.accent,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	Parent = tpFrame,
}, {
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 8),
	}),
	make("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local teleportGroups = {
	{
		name = "Map 1 TPs",
		points = {
			{ label = "Map 1 TP 1", pos = Vector3.new(578, 414, 11778) },
			{ label = "Map 1 TP 2", pos = Vector3.new(453, 0, 10793) },
			{ label = "Map 1 TP 3", pos = Vector3.new(575, 0, 8937) },
			{ label = "Map 1 TP 4", pos = Vector3.new(453, 0, 8480) },
		},
	},
	{
		name = "Map 2 TPs",
		points = {
			{ label = "Map 2 TP 1", pos = Vector3.new(1476, 0, 9497) },
			{ label = "Map 2 TP 2", pos = Vector3.new(1599, 0, 9099) },
			{ label = "Map 2 TP 3", pos = Vector3.new(1603, 0, 10865) },
			{ label = "Map 2 TP 4", pos = Vector3.new(1478, 0, 10639) },
		},
	},
	{
		name = "Other TPs",
		points = {
			{ label = "TP 1", pos = Vector3.new(15814, 0, -34889) },
			{ label = "TP 2", pos = Vector3.new(15934, 0, -34888) },
			{ label = "TP 3", pos = Vector3.new(15815, 0, 55220) },
			{ label = "TP 4", pos = Vector3.new(15939, 0, 55214) },
		},
	},
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

local order = 0
local function nextOrder()
	order += 1
	return order
end

for _, group in ipairs(teleportGroups) do
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Text = group.name,
		TextColor3 = theme.accent,
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = nextOrder(),
		Parent = tpList,
	})

	for _, tp in ipairs(group.points) do
		local btn = make("TextButton", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = theme.cardAlt,
			BorderSizePixel = 0,
			Text = tp.label .. "  |  " .. tp.pos.X .. ", " .. tp.pos.Y .. ", " .. tp.pos.Z,
			TextColor3 = theme.text,
			Font = Enum.Font.Gotham,
			TextSize = 11,
			LayoutOrder = nextOrder(),
			Parent = tpList,
		}, {
			make("UICorner", { CornerRadius = UDim.new(0, 7) }),
			make("UIStroke", { Color = theme.stroke, Thickness = 1, Transparency = 0.4 }),
		})

		btn.MouseEnter:Connect(function() btn.BackgroundColor3 = theme.cardHover end)
		btn.MouseLeave:Connect(function() btn.BackgroundColor3 = theme.cardAlt end)
		btn.MouseButton1Click:Connect(function()
			teleportTo(tp.pos, tp.label)
		end)
	end
end

make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundColor3 = theme.card,
	BorderSizePixel = 0,
	Text = "If the server snaps you back, turn off Fly and try again.",
	TextColor3 = theme.muted,
	Font = Enum.Font.Gotham,
	TextSize = 10,
	TextWrapped = true,
	LayoutOrder = nextOrder(),
	Parent = tpList,
}, { make("UICorner", { CornerRadius = UDim.new(0, 7) }) })

make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundColor3 = Color3.fromRGB(53, 42, 32),
	BorderSizePixel = 0,
	Text = "You cannot TP to these wins unless you have the map unlocked.",
	TextColor3 = theme.amber,
	Font = Enum.Font.Gotham,
	TextSize = 10,
	TextWrapped = true,
	LayoutOrder = nextOrder(),
	Parent = tpList,
}, { make("UICorner", { CornerRadius = UDim.new(0, 7) }) })

local function switchTab(name)
	activeTab = name
	main.Visible = name == "Main"
	tpFrame.Visible = name == "TPs"
	mainTabBtn.BackgroundColor3 = name == "Main" and theme.tabActive or theme.tabInactive
	tpTabBtn.BackgroundColor3 = name == "TPs" and theme.tabActive or theme.tabInactive
	mainTabBtn.TextColor3 = name == "Main" and theme.text or theme.muted
	tpTabBtn.TextColor3 = name == "TPs" and theme.text or theme.muted
end

local function setGuiVisible(visible)
	guiVisible = visible
	window.Visible = visible
end

mainTabBtn.MouseButton1Click:Connect(function() switchTab("Main") end)
tpTabBtn.MouseButton1Click:Connect(function() switchTab("TPs") end)
switchTab("Main")

-- Drag (the whole window moves as one)
do
	local dragging, dragStart, startPos
	window.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = window.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			window.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

local function refreshSpeed()
	speedBtn.Text = state.AutoSpeed and "ON" or "OFF"
	speedBtn.BackgroundColor3 = state.AutoSpeed and theme.green or theme.red
end

speedBtn.MouseButton1Click:Connect(function()
	state.AutoSpeed = not state.AutoSpeed
	refreshSpeed()
	setStatus("Auto Speed: " .. (state.AutoSpeed and "ON" or "OFF"))
end)

local function refreshRebirth()
	rebirthBtn.Text = state.AutoRebirth and "ON" or "OFF"
	rebirthBtn.BackgroundColor3 = state.AutoRebirth and theme.green or theme.red
end

rebirthBtn.MouseButton1Click:Connect(function()
	state.AutoRebirth = not state.AutoRebirth
	refreshRebirth()
	setStatus("Auto Rebirth: " .. (state.AutoRebirth and "ON" or "OFF"))
end)

-- Fly / Noclip
local function refreshFly()
	flyBtn.Text = state.Fly and "ON" or "OFF"
	flyBtn.BackgroundColor3 = state.Fly and theme.green or theme.red
end

local function refreshNoclip()
	noclipBtn.Text = state.Noclip and "ON" or "OFF"
	noclipBtn.BackgroundColor3 = state.Noclip and theme.green or theme.red
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
	flyBody.Name = "XenonFlyVelocity"
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
		warn("[Xenon] IncreaseSpeed remote not found")
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
		warn("[Xenon] Rebirth setup failed: " .. tostring(err))
		rebirthInfo.Text = "Rebirth: not available"
		setStatus("Rebirth not found")
		return
	end

	setStatus("Rebirth ready")
	print("[Xenon] Rebirth ready. Stat: " .. tostring(RebirthData.STAT))

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
print("[Xenon] Loaded. F=speed R=rebirth T=fly N=noclip LeftShift/RightShift=show/hide GUI. Tabs: Main / TPs")
