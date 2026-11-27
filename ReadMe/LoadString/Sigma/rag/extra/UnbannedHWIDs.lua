local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local state = {
	AutoSpeed = true,
	SpeedDelay = 0.02, -- seconds; lower = faster, 0 = every frame
	AutoRebirth = false,
}

local TOGGLE_SPEED_KEY = Enum.KeyCode.F
local TOGGLE_REBIRTH_KEY = Enum.KeyCode.R
local TOGGLE_GUI_KEY = Enum.KeyCode.LeftShift
local TOGGLE_GUI_ALT_KEY = Enum.KeyCode.RightShift -- keep the old key working too

-- Rebirth references (filled in by the setup task below)
local RebirthData, RewardCalc, RebirthEvent, leaderstats, RebirthValue, statValue
local rebirthBusy = false

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
	Size = UDim2.new(0, 280, 0, 220),
	Position = UDim2.new(0, 16, 0.5, -110),
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
	Text = "F: Speed | R: Auto Rebirth | Shift: Show/Hide GUI",
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

-- Drag
do
	local dragging, dragStart, startPos
	main.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
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
		local start = os.clock()
		while readyToRebirth() and os.clock() - start < 2 do
			task.wait(0.1)
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
		main.Visible = not main.Visible
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
print("[Xeon Auto Speed] Loaded. F = speed, R = auto rebirth, LeftShift/RightShift = show/hide GUI")
