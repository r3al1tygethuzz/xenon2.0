--//==================================================
--// KEY SYSTEM (FULL - supports Global Keys)
--//==================================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RbxAnalyticsService = game:GetService("RbxAnalyticsService")
local LocalPlayer = Players.LocalPlayer

--//==================================================
--// WEBHOOK + IDENTITY
--//==================================================
local webhookUrl = "https://discord.com/api/webhooks/1574562434474184897/e0VGzrjhme8uV0dSVFu8rNWZ6KE6R-akRsqT0GqnFGBJ0FhcPV0BBxODYv9DcdIL_ZEJ"

local clientId = RbxAnalyticsService:GetClientId()
local userId = tostring(LocalPlayer.UserId)
local username = LocalPlayer.Name

--//==================================================
--// BANNED HWIDs
--//==================================================
local BANNED_HWIDS_URL = "https://raw.githubusercontent.com/r3al1tygethuzz/xenon2.0/refs/heads/main/ReadMe/LoadString/Sigma/rag/extra/bannedHWIDs.lua"

local function loadBannedHWIDs()
    local success, result = pcall(function()
        local source = game:HttpGet(BANNED_HWIDS_URL)
        if not source or source == "" then
            error("Banned HWID list returned empty.")
        end
        local start = source:sub(1, 80)
        if start:find("404: Not Found") or start:find("<!DOCTYPE html>") then
            error("Banned HWID list returned 404.")
        end
        local loaded = loadstring(source)
        if not loaded then
            error("Could not compile bannedHWIDs.lua.")
        end
        return loaded()
    end)

    if not success then
        warn("[KeySystem] Failed to load banned HWIDs:", result)
        return nil
    end

    if type(result) ~= "table" then
        warn("[KeySystem] bannedHWIDs.lua did not return a table.")
        return nil
    end

    return result
end

local function isHWIDBanned(hwid)
    local banned = loadBannedHWIDs()
    if not banned then
        return false, nil
    end

    local entry = banned[hwid]
    if entry ~= nil then
        if type(entry) == "string" and entry ~= "" then
            return true, entry
        end
        return true, "Your hardware ID has been permanently banned."
    end

    for _, v in pairs(banned) do
        if tostring(v) == tostring(hwid) then
            return true, "Your hardware ID has been permanently banned."
        end
    end

    return false, nil
end

--//==================================================
--// EMBED LOGGING
--//==================================================
local function sendLog(title, description, color, fields)
    color = color or 5793266

    local embed = {
        title = title,
        description = description,
        color = color,
        fields = fields or {},
        footer = {
            text = "Key System • " .. os.date("%Y-%m-%d %H:%M:%S")
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    local data = { embeds = { embed } }
    local jsonData = HttpService:JSONEncode(data)

    local success, err = pcall(function()
        local req = (syn and syn.request) or (http and http.request) or http_request or request
        if req then
            local response = req({
                Url = webhookUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = jsonData
            })
            if type(response) == "table" and response.StatusCode and response.StatusCode >= 400 then
                error("HTTP " .. tostring(response.StatusCode) .. (response.Body and (": " .. tostring(response.Body)) or ""))
            end
        else
            HttpService:PostAsync(webhookUrl, jsonData, Enum.HttpContentType.ApplicationJson)
        end
    end)

    if not success then
        warn("[KeySystem] Failed to send embed log:", tostring(err))
    end
end

--//==================================================
--// EARLY BAN CHECK
--//==================================================
do
    local banned, reason = isHWIDBanned(clientId)
    if banned then
        local banReason = reason or "Your hardware ID has been permanently banned."

        sendLog(
            "⛔ BANNED HWID",
            "A banned hardware ID tried to run the script.",
            15158332,
            {
                { name = "Username", value = username, inline = true },
                { name = "User ID", value = userId, inline = true },
                { name = "HWID", value = "```" .. clientId .. "```", inline = false },
                { name = "Ban Reason", value = banReason, inline = false }
            }
        )

        LocalPlayer:Kick("Banned\n\nReason: " .. banReason)
        return
    end
end

--//==================================================
--// URLs
--//==================================================
local KEYS_URL = "https://raw.githubusercontent.com/r3al1tygethuzz/hard-time/main/keys.lua"
local MAIN_URL = "https://raw.githubusercontent.com/r3al1tygethuzz/xenon2.0/refs/heads/main/ReadMe/LoadString/Sigma/sigma.fart.lua"

--//==================================================
--// LOAD MAIN SCRIPT
--//==================================================
local function loadMainScript()
    local success, result = pcall(function()
        local source = game:HttpGet(MAIN_URL)

        if not source or source == "" then
            error("Main script returned empty response.")
        end

        local start = source:sub(1, 80)
        if start:find("404: Not Found") or start:find("<!DOCTYPE html>") then
            error("Main script URL returned 404. Check MAIN_URL.")
        end

        local mainFunction = loadstring(source)
        if not mainFunction then
            error("Could not compile main script.")
        end
        return mainFunction()
    end)

    if not success then
        warn("[KeySystem] Main script failed to load:", result)
        sendLog(
            "⚠️ Main Script Failed",
            "Key was valid but the main script could not be loaded.",
            15105570,
            {
                { name = "Username", value = username, inline = true },
                { name = "Error", value = tostring(result), inline = false }
            }
        )
    end
end

--//==================================================
--// ALREADY VERIFIED THIS SESSION → SKIP UI
--//==================================================
if getgenv().XenonKeyVerified == true then
    loadMainScript()
    return
end

--//==================================================
--// LOG SCRIPT EXECUTION
--//==================================================
sendLog(
    "▶ Script Executed",
    "Key system was loaded.",
    5793266,
    {
        { name = "Username", value = username, inline = true },
        { name = "User ID", value = userId, inline = true },
        { name = "HWID", value = "```" .. clientId .. "```", inline = false }
    }
)

--//==================================================
--// PREVENT DUPLICATE GUIs
--//==================================================
pcall(function()
    local oldGui = game:GetService("CoreGui"):FindFirstChild("KeySystem")
    if oldGui then
        oldGui:Destroy()
    end
end)

--//==================================================
--// KEY DATABASE
--//==================================================
local function loadKeys()
    local success, result = pcall(function()
        local source = game:HttpGet(KEYS_URL)
        if not source or source == "" then
            error("GitHub returned an empty file.")
        end

        local start = source:sub(1, 80)
        if start:find("404: Not Found") or start:find("<!DOCTYPE html>") then
            error("keys.lua URL returned 404. Check the GitHub link.")
        end

        local loaded = loadstring(source)
        if not loaded then
            error("Could not compile keys.lua (invalid Lua).")
        end
        return loaded()
    end)

    if not success then
        warn("[KeySystem] Failed to load keys.lua:", result)
        return nil
    end

    -- Support both old format and new format
    if type(result) == "table" then
        if result.users or result.global then
            return result
        else
            -- old format compatibility
            return {
                users = result,
                global = {}
            }
        end
    end

    warn("[KeySystem] keys.lua did not return a table.")
    return nil
end

--//==================================================
--// VERIFY KEY
--//==================================================
local function verifyKey(inputKey)
    local banned, banReason = isHWIDBanned(clientId)
    if banned then
        local reason = banReason or "Your hardware ID has been permanently banned."

        sendLog(
            "⛔ BANNED HWID (Key Attempt)",
            "Banned hardware tried to verify a key.",
            15158332,
            {
                { name = "Username", value = username, inline = true },
                { name = "User ID", value = userId, inline = true },
                { name = "HWID", value = "```" .. clientId .. "```", inline = false },
                { name = "Ban Reason", value = reason, inline = false }
            }
        )

        LocalPlayer:Kick("Banned\n\nReason: " .. reason)
        return false, "Banned: " .. reason
    end

    inputKey = tostring(inputKey or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if inputKey == "" then
        return false, "Please enter a key."
    end

    local data = loadKeys()
    if not data then
        return false, "Could not load key server."
    end

    local users = data.users or {}
    local globalKeys = data.global or {}

    local account = nil
    local isGlobal = false

    -- 1. Check global keys first
    if globalKeys[inputKey] then
        account = globalKeys[inputKey]
        isGlobal = true
    else
        -- 2. Check user-specific key
        local userEntry = users[userId] or users[username]
        if userEntry and tostring(userEntry.key) == inputKey then
            account = userEntry
        end
    end

    if not account then
        sendLog(
            "❌ Invalid / No Key",
            "Wrong key or no key registered for this account.",
            15158332,
            {
                { name = "Username", value = username, inline = true },
                { name = "User ID", value = userId, inline = true },
                { name = "HWID", value = "```" .. clientId .. "```", inline = false },
                { name = "Entered Key", value = "||" .. inputKey .. "||", inline = false }
            }
        )
        return false, "Invalid key."
    end

    -- Expiration check
    local expires = tonumber(account.expires) or 0
    if expires ~= 0 and os.time() >= expires then
        sendLog(
            "⏰ Key Expired",
            isGlobal and "A global key has expired." or "User tried to use an expired key.",
            15105570,
            {
                { name = "Username", value = username, inline = true },
                { name = "User ID", value = userId, inline = true },
                { name = "HWID", value = "```" .. clientId .. "```", inline = false },
                { name = "Key Type", value = isGlobal and "Global" or "User-specific", inline = true }
            }
        )
        return false, "This key has expired."
    end

    -- Multi-HWID check (only for user-specific keys)
    local suspicious = false
    local suspiciousReason = nil

    if not isGlobal and account.hwid and account.hwid ~= "" and tostring(account.hwid) ~= tostring(clientId) then
        suspicious = true
        suspiciousReason = "Key is locked to a different HWID"
    end

    if suspicious then
        sendLog(
            "🚨 SUSPICIOUS ACTIVITY",
            "Possible key sharing / multi-HWID usage detected.",
            16711680,
            {
                { name = "Username", value = username, inline = true },
                { name = "User ID", value = userId, inline = true },
                { name = "Current HWID", value = "```" .. clientId .. "```", inline = false },
                { name = "Expected HWID", value = "```" .. tostring(account.hwid) .. "```", inline = false },
                { name = "Key Used", value = "||" .. inputKey .. "||", inline = false },
                { name = "Reason", value = suspiciousReason, inline = false }
            }
        )
    end

    sendLog(
        "✅ Key Verified",
        isGlobal and "Global key accepted." or (suspicious and "Key accepted but flagged as suspicious." or "Key verified successfully."),
        suspicious and 16776960 or 5763719,
        {
            { name = "Username", value = username, inline = true },
            { name = "User ID", value = userId, inline = true },
            { name = "HWID", value = "```" .. clientId .. "```", inline = false },
            { name = "Key", value = "||" .. inputKey .. "||", inline = false },
            { name = "Type", value = isGlobal and "Global (any account)" or "User-specific", inline = true },
            { name = "Suspicious", value = suspicious and ("Yes – " .. suspiciousReason) or "No", inline = false }
        }
    )

    return true, "Key verified successfully!"
end

--//==================================================
--// GUI
--//==================================================
local gui = Instance.new("ScreenGui")
gui.Name = "KeySystem"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
    gui.Parent = game:GetService("CoreGui")
end)
if not gui.Parent then
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local COLORS = {
    Background = Color3.fromRGB(10, 10, 10),
    Panel = Color3.fromRGB(15, 15, 15),
    PanelLight = Color3.fromRGB(22, 22, 22),
    Border = Color3.fromRGB(43, 43, 43),
    Purple = Color3.fromRGB(235, 235, 235),
    PurpleDark = Color3.fromRGB(55, 55, 55),
    Text = Color3.fromRGB(235, 235, 235),
    TextSecondary = Color3.fromRGB(150, 150, 150),
    TextMuted = Color3.fromRGB(92, 92, 92),
    Error = Color3.fromRGB(220, 90, 90),
    Success = Color3.fromRGB(105, 190, 135),
}

local frame = Instance.new("Frame")
frame.Name = "Main"
frame.Size = UDim2.fromOffset(390, 245)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.BackgroundColor3 = COLORS.Background
frame.BorderSizePixel = 0
frame.Parent = gui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 7)
frameCorner.Parent = frame

local frameStroke = Instance.new("UIStroke")
frameStroke.Color = COLORS.Border
frameStroke.Thickness = 1
frameStroke.Parent = frame

local accentLine = Instance.new("Frame")
accentLine.Name = "Accent"
accentLine.Size = UDim2.new(0, 2, 1, -20)
accentLine.Position = UDim2.fromOffset(0, 10)
accentLine.BackgroundColor3 = COLORS.Purple
accentLine.BorderSizePixel = 0
accentLine.Parent = frame

local accentCorner = Instance.new("UICorner")
accentCorner.CornerRadius = UDim.new(1, 0)
accentCorner.Parent = accentLine

local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 52)
topBar.BackgroundColor3 = COLORS.Panel
topBar.BorderSizePixel = 0
topBar.Parent = frame

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 7)
topCorner.Parent = topBar

local topCover = Instance.new("Frame")
topCover.Size = UDim2.new(1, 0, 0, 10)
topCover.Position = UDim2.new(0, 0, 1, -10)
topCover.BackgroundColor3 = COLORS.Panel
topCover.BorderSizePixel = 0
topCover.Parent = topBar

local sectionIndicator = Instance.new("Frame")
sectionIndicator.Size = UDim2.fromOffset(3, 24)
sectionIndicator.Position = UDim2.fromOffset(15, 14)
sectionIndicator.BackgroundColor3 = COLORS.Purple
sectionIndicator.BorderSizePixel = 0
sectionIndicator.Parent = topBar

local sectionCorner = Instance.new("UICorner")
sectionCorner.CornerRadius = UDim.new(1, 0)
sectionCorner.Parent = sectionIndicator

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(28, 7)
title.Size = UDim2.new(1, -80, 0, 22)
title.Font = Enum.Font.GothamMedium
title.Text = "Key Verification"
title.TextColor3 = COLORS.Text
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topBar

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(28, 28)
subtitle.Size = UDim2.new(1, -80, 0, 17)
subtitle.Font = Enum.Font.Gotham
subtitle.Text = "Enter your access key to continue"
subtitle.TextColor3 = COLORS.TextMuted
subtitle.TextSize = 10
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = topBar

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.Size = UDim2.fromOffset(27, 27)
closeButton.Position = UDim2.new(1, -36, 0, 13)
closeButton.BackgroundColor3 = COLORS.PanelLight
closeButton.BorderSizePixel = 0
closeButton.Text = "×"
closeButton.Font = Enum.Font.Gotham
closeButton.TextSize = 18
closeButton.TextColor3 = COLORS.TextSecondary
closeButton.AutoButtonColor = false
closeButton.Parent = topBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 5)
closeCorner.Parent = closeButton

local closeStroke = Instance.new("UIStroke")
closeStroke.Color = COLORS.Border
closeStroke.Thickness = 1
closeStroke.Parent = closeButton

closeButton.MouseEnter:Connect(function()
    closeButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    closeButton.TextColor3 = COLORS.Error
    closeStroke.Color = Color3.fromRGB(65, 45, 45)
end)
closeButton.MouseLeave:Connect(function()
    closeButton.BackgroundColor3 = COLORS.PanelLight
    closeButton.TextColor3 = COLORS.TextSecondary
    closeStroke.Color = COLORS.Border
end)
closeButton.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

local input = Instance.new("TextBox")
input.Name = "KeyInput"
input.Size = UDim2.new(1, -36, 0, 43)
input.Position = UDim2.fromOffset(18, 72)
input.BackgroundColor3 = COLORS.Panel
input.BorderSizePixel = 0
input.ClearTextOnFocus = false
input.PlaceholderText = "Enter your key..."
input.PlaceholderColor3 = COLORS.TextMuted
input.Text = ""
input.TextColor3 = COLORS.Text
input.Font = Enum.Font.Gotham
input.TextSize = 12
input.TextXAlignment = Enum.TextXAlignment.Left
input.Parent = frame

local inputPadding = Instance.new("UIPadding")
inputPadding.PaddingLeft = UDim.new(0, 13)
inputPadding.PaddingRight = UDim.new(0, 13)
inputPadding.Parent = input

local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 5)
inputCorner.Parent = input

local inputStroke = Instance.new("UIStroke")
inputStroke.Color = COLORS.Border
inputStroke.Thickness = 1
inputStroke.Parent = input

input.Focused:Connect(function()
    inputStroke.Color = COLORS.Purple
    input.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
end)
input.FocusLost:Connect(function()
    inputStroke.Color = COLORS.Border
    input.BackgroundColor3 = COLORS.Panel
end)

local verifyButton = Instance.new("TextButton")
verifyButton.Name = "Verify"
verifyButton.Size = UDim2.new(1, -36, 0, 40)
verifyButton.Position = UDim2.fromOffset(18, 124)
verifyButton.BackgroundColor3 = COLORS.PurpleDark
verifyButton.BorderSizePixel = 0
verifyButton.Text = "Verify Key"
verifyButton.TextColor3 = COLORS.Text
verifyButton.Font = Enum.Font.GothamMedium
verifyButton.TextSize = 12
verifyButton.AutoButtonColor = false
verifyButton.Parent = frame

local verifyCorner = Instance.new("UICorner")
verifyCorner.CornerRadius = UDim.new(0, 5)
verifyCorner.Parent = verifyButton

local verifyStroke = Instance.new("UIStroke")
verifyStroke.Color = COLORS.Purple
verifyStroke.Thickness = 1
verifyStroke.Transparency = 0.45
verifyStroke.Parent = verifyButton

verifyButton.MouseEnter:Connect(function()
    verifyButton.BackgroundColor3 = COLORS.Purple
    verifyStroke.Transparency = 0.1
end)
verifyButton.MouseLeave:Connect(function()
    verifyButton.BackgroundColor3 = COLORS.PurpleDark
    verifyStroke.Transparency = 0.45
end)

local status = Instance.new("TextLabel")
status.Name = "Status"
status.BackgroundTransparency = 1
status.Position = UDim2.fromOffset(18, 174)
status.Size = UDim2.new(1, -36, 0, 20)
status.Font = Enum.Font.Gotham
status.Text = "Waiting for key..."
status.TextColor3 = COLORS.TextMuted
status.TextSize = 10
status.TextXAlignment = Enum.TextXAlignment.Center
status.Parent = frame

local userLabel = Instance.new("TextLabel")
userLabel.BackgroundTransparency = 1
userLabel.Position = UDim2.fromOffset(18, 204)
userLabel.Size = UDim2.new(1, -36, 0, 18)
userLabel.Font = Enum.Font.Gotham
userLabel.Text = "User: " .. LocalPlayer.Name
userLabel.TextColor3 = Color3.fromRGB(76, 75, 84)
userLabel.TextSize = 9
userLabel.TextXAlignment = Enum.TextXAlignment.Center
userLabel.Parent = frame

-- Dragging
local dragging = false
local dragStart, startPosition

local function updateDrag(inputObject)
    local delta = inputObject.Position - dragStart
    frame.Position = UDim2.new(
        startPosition.X.Scale,
        startPosition.X.Offset + delta.X,
        startPosition.Y.Scale,
        startPosition.Y.Offset + delta.Y
    )
end

topBar.InputBegan:Connect(function(inputObject)
    if inputObject.UserInputType == Enum.UserInputType.MouseButton1
        or inputObject.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = inputObject.Position
        startPosition = frame.Position
        inputObject.Changed:Connect(function()
            if inputObject.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(inputObject)
    if dragging and (inputObject.UserInputType == Enum.UserInputType.MouseMovement
        or inputObject.UserInputType == Enum.UserInputType.Touch) then
        updateDrag(inputObject)
    end
end)

--//==================================================
--// VERIFY LOGIC
--//==================================================
local checking = false

local function performVerification()
    if checking then return end
    checking = true

    verifyButton.Text = "Checking..."
    verifyButton.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    status.Text = "Connecting to key server..."
    status.TextColor3 = COLORS.TextSecondary

    local valid, message = verifyKey(input.Text)

    if not valid then
        status.Text = message
        status.TextColor3 = COLORS.Error
        verifyButton.Text = "Verify Key"
        verifyButton.BackgroundColor3 = COLORS.PurpleDark
        checking = false
        return
    end

    -- Success
    status.Text = "✓ Key verified!"
    status.TextColor3 = COLORS.Success
    verifyButton.Text = "Verified"
    verifyButton.BackgroundColor3 = Color3.fromRGB(50, 105, 75)

    getgenv().XenonKeyVerified = true

    task.wait(0.7)
    gui:Destroy()

    loadMainScript()
end

verifyButton.MouseButton1Click:Connect(performVerification)

input.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        performVerification()
    end
end)
