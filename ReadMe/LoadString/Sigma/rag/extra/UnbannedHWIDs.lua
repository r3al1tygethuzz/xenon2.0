local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local state = {
	AutoSpeed = true,
	SpeedDelay = 0.02, -- seconds; lower = faster, 0 = every frame
}

local TOGGLE_SPEED_KEY = Enum.KeyCode.F
local TOGGLE_GUI_KEY = Enum.KeyCode.RightShift

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
	Size = UDim2.new(0, 280, 0, 170),
	Position = UDim2.new(0, 16, 0.5, -85),
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
	Text = "Xeon Auto Speed",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = main,
})

make("TextLabel", {
	Size = UDim2.new(1, -20, 0, 18),
	Position = UDim2.new(0, 10, 0, 34),
	BackgroundTransparency = 1,
	Text = "F: Speed | RightShift: Hide GUI",
	TextColor3 = Color3.fromRGB(150, 160, 175),
	Font = Enum.Font.Gotham,
	TextSize = 11,
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
	Position = UDim2.new(0, 10, 0, 62),
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
	Position = UDim2.new(0, 10, 0, 102),
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

-- Keybinds
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == TOGGLE_SPEED_KEY then
		state.AutoSpeed = not state.AutoSpeed
		refreshSpeed()
		setStatus("Auto Speed: " .. (state.AutoSpeed and "ON" or "OFF"))
	elseif input.KeyCode == TOGGLE_GUI_KEY then
		main.Visible = not main.Visible
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

setStatus("Loaded")
print("[Xeon Auto Speed] Loaded. F = toggle, RightShift = hide GUI")
