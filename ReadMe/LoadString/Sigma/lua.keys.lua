--//==================================================
--// KEY SYSTEM (FULL - supports Global Keys)
--//==================================================
local hello = loadstring(game:HttpGet("https://raw.githubusercontent.com/r3al1tygethuzz/xenon2.0/refs/heads/main/ReadMe/LoadString/Sigma/rag/extra/ClickMe4Source/MaybeClickMe%3F/Sike.lua"))()
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RbxAnalyticsService = game:GetService("RbxAnalyticsService")
local LocalPlayer = Players.LocalPlayer

--//==================================================
--// WEBHOOK + IDENTITY
--//==================================================
local webhookUrl = webhook

local clientId = RbxAnalyticsService:GetClientId()
local userId = tostring(LocalPlayer.UserId)
local username = LocalPlayer.Name

--//==================================================
--// HWID CLAIM CONFIG
--//==================================================
local CLAIM_PREFIX = "NYRA-CLAIM|"
local CLAIM_TIMEOUT = 90
local CLAIM_POLL_INTERVAL = 3

local function trim(value)
    local text = tostring(value or "")
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")
    return text
end

-- FNV-1a 32-bit. Must match github_key_store.key_hash().
local function xor32(a, b)
    if bit32 then
        return bit32.bxor(a, b)
    end

    local result, bit = 0, 1
    for _ = 1, 32 do
        local aBit = a % 2
        local bBit = b % 2
        if aBit ~= bBit then
            result = result + bit
        end
        a = (a - aBit) / 2
        b = (b - bBit) / 2
        bit = bit * 2
    end
    return result
end

local function keyHash(key)
    local hash = 2166136261
    local text = tostring(key or ""):upper()

    for index = 1, #text do
        hash = xor32(hash, text:byte(index))

        if bit32 then
            hash = (
                hash
                + bit32.lshift(hash, 1)
                + bit32.lshift(hash, 4)
                + bit32.lshift(hash, 7)
                + bit32.lshift(hash, 8)
                + bit32.lshift(hash, 24)
            ) % 4294967296
        else
            local low = hash % 65536
            local high = math.floor(hash / 65536)
            local mixed = (low * 16777619) % 4294967296
            mixed = (mixed + ((high * 16777619) % 65536) * 65536) % 4294967296
            hash = mixed
        end
    end

    return string.format("%08x", hash)
end

local function postWebhook(payload)
    if not webhookUrl then
        return false
    end

    local success, jsonData = pcall(function()
        return HttpService:JSONEncode(payload)
    end)

    if not success then
        warn("[KeySystem] Could not encode webhook payload:", jsonData)
        return false
    end

    local requestFunction = (syn and syn.request) or (http and http.request) or http_request or request

    if requestFunction then
        local ok, response = pcall(requestFunction, {
            Url = webhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = jsonData
        })
        if not ok then
            return false
        end
        if type(response) == "table" and response.StatusCode and response.StatusCode >= 400 then
            return false
        end
        return true
    end

    local ok = pcall(function()
        HttpService:PostAsync(webhookUrl, jsonData, Enum.HttpContentType.ApplicationJson)
    end)
    return ok
end

--//==================================================
--// BANNED HWIDs
--//==================================================
local BANNED_HWIDS_URL = (type(bannedHwidsUrl) == "string" and bannedHwidsUrl ~= "" and bannedHwidsUrl)
    or "https://raw.githubusercontent.com/r3al1tygethuzz/xenon2.0/refs/heads/main/ReadMe/LoadString/Sigma/rag/extra/bannedHWIDs.lua"

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
    if type(banned) ~= "table" then
        return false, nil
    end

    local entry = banned[hwid]
    if entry ~= nil then
        return true, tostring(entry)
    end

    for key, value in pairs(banned) do
        if tostring(key) == tostring(hwid) then
            return true, tostring(value)
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
        return false
    end

    return true
end

--//==================================================
--// AUTO-OPEN INVITE ON INJECT
--//==================================================
pcall(function()
    if setclipboard then
        setclipboard("https://discord.gg/NVKj9pMxHs")
    end
end)

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Xenon",
        Text = "Join discord.gg/NVKj9pMxHs",
        Duration = 8
    })
end)

--//==================================================
--// REMEMBER KEY (persist across sessions)
--//==================================================
local function loadSavedKey()
    local ok, value = pcall(function()
        if readfile and isfile and isfile("xenon_key.txt") then
            return readfile("xenon_key.txt")
        end
        return nil
    end)
    if ok and type(value) == "string" and value ~= "" then
        return value
    end
    return nil
end

local function saveKey(key)
    pcall(function()
        if writefile then
            writefile("xenon_key.txt", key)
        end
    end)
end

--//==================================================
--// ALREADY VERIFIED THIS SESSION → SKIP UI
--//==================================================
if getgenv().XenonKeyVerified == true then
    local ok = loadMainScript()
    if ok then
        return
    end
    -- Main script failed; fall through to the key UI.
    getgenv().XenonKeyVerified = nil
end

local savedKey = loadSavedKey()
if savedKey then
    local ok, valid, message = pcall(function()
        return verifyKey(savedKey)
    end)
    if ok and valid then
        getgenv().XenonKeyVerified = true
        local loaded = loadMainScript()
        if loaded then
            return
        end
        getgenv().XenonKeyVerified = nil
    else
        -- Key no longer valid: delete saved key and show UI.
        pcall(function()
            if delfile and isfile and isfile("xenon_key.txt") then
                delfile("xenon_key.txt")
            end
        end)
    end
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
local function cacheBustedUrl(url)
    local separator = url:find("?") and "&" or "?"
    return url
        .. separator
        .. "t="
        .. tostring(os.time())
        .. "&r="
        .. tostring(math.random(100000, 999999))
end

local function normalizeDatabase(raw)
    if type(raw) ~= "table" then
        return nil
    end

    if type(raw.keys) == "table" or type(raw.global) == "table" then
        return {
            keys = type(raw.keys) == "table" and raw.keys or {},
            global = type(raw.global) == "table" and raw.global or {},
        }
    end

    if type(raw.users) == "table" then
        local converted = { keys = {}, global = {} }

        for _, entry in pairs(raw.users) do
            if type(entry) == "table" and entry.key then
                converted.keys[tostring(entry.key)] = {
                    expires = tonumber(entry.expires) or 0,
                    hwid = entry.hwid,
                }
            end
        end

        for _, entry in pairs(raw.global or {}) do
            if type(entry) == "table" and entry.key then
                converted.global[tostring(entry.key)] = {
                    expires = tonumber(entry.expires) or 0,
                }
            end
        end

        return converted
    end

    local converted = { keys = {}, global = {} }

    for name, entry in pairs(raw) do
        if type(entry) == "table" and entry.expires ~= nil then
            converted.keys[tostring(name)] = {
                expires = tonumber(entry.expires) or 0,
                hwid = entry.hwid,
            }
        end
    end

    return converted
end

local function loadKeys(useCacheBuster)
    local urls = {}
    if useCacheBuster then
        table.insert(urls, cacheBustedUrl(KEYS_URL))
    end
    table.insert(urls, KEYS_URL)

    for _, url in ipairs(urls) do
        local success, result = pcall(function()
            local source = game:HttpGet(url)
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

        if success then
            local database = normalizeDatabase(result)
            if database then
                return database
            end
        else
            warn("[KeySystem] Failed to load keys.lua from", url, ":", result)
        end
    end

    return nil
end

local function lookupKey(entries, inputKey)
    if type(entries) ~= "table" then
        return nil, nil
    end

    if entries[inputKey] ~= nil then
        return inputKey, entries[inputKey]
    end

    local wanted = inputKey:upper()

    for name, entry in pairs(entries) do
        if tostring(name):upper() == wanted then
            return tostring(name), entry
        end
    end

    return nil, nil
end

local function currentTime()
    if DateTime and DateTime.now then
        local ok, value = pcall(function()
            return DateTime.now().UnixTimestamp
        end)
        if ok and type(value) == "number" and value > 0 then
            return value
        end
    end
    return os.time()
end

local function isExpired(entry)
    local expires = tonumber(entry and entry.expires) or 0
    if expires == 0 then
        return false
    end
    -- Guard against a clock that is behind the key server.
    return currentTime() >= (expires - 5)
end

local function claimKey(inputKey)
    local claimedHash = keyHash(inputKey)
    local nonce = tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))

    local sent = postWebhook({
        content = CLAIM_PREFIX .. claimedHash .. "|" .. clientId .. "|" .. nonce,
        username = "Nyra Key Claim",
        allowed_mentions = { parse = {} },
    })

    if not sent then
        return false, "network"
    end

    local deadline = currentTime() + CLAIM_TIMEOUT

    while currentTime() < deadline do
        task.wait(CLAIM_POLL_INTERVAL)

        local database = loadKeys(true)

        if database then
            local _, entry = lookupKey(database.keys, inputKey)

            if entry then
                local bound = entry.hwid

                if bound == nil or tostring(bound) == "" then
                    -- Not bound yet; keep waiting.
                elseif tostring(bound) == tostring(clientId) then
                    return true, "bound"
                else
                    return false, "locked"
                end
            end
        end
    end

    -- One extra retry: the GitHub raw CDN may lag behind.
    task.wait(5)
    local database = loadKeys(true)
    if database then
        local _, entry = lookupKey(database.keys, inputKey)
        if entry then
            local bound = entry.hwid
            if bound == nil or tostring(bound) == "" then
                -- Still unbound; retry the claim once.
                local sent = postWebhook({
                    content = CLAIM_PREFIX .. claimedHash .. "|" .. clientId .. "|" .. tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999)),
                    username = "Nyra Key Claim",
                    allowed_mentions = { parse = {} },
                })
                if sent then
                    local retryDeadline = os.time() + 20
                    while os.time() < retryDeadline do
                        task.wait(2)
                        local db2 = loadKeys(true)
                        if db2 then
                            local _, e2 = lookupKey(db2.keys, inputKey)
                            if e2 then
                                local b2 = e2.hwid
                                if b2 ~= nil and tostring(b2) ~= "" then
                                    if tostring(b2) == tostring(clientId) then
                                        return true, "bound"
                                    else
                                        return false, "locked"
                                    end
                                end
                            end
                        end
                    end
                end
            elseif tostring(bound) == tostring(clientId) then
                return true, "bound"
            else
                return false, "locked"
            end
        end
    end

    return false, "timeout"
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

        LocalPlayer:Kick("Xenon HWID Ban - discord.gg/NVKj9pMxHs\n\nReason: " .. reason)
        return false, "Banned: " .. reason
    end

    inputKey = trim(inputKey)
    if inputKey == "" then
        return false, "Please enter a key."
    end

    local data = loadKeys(true)
    if not data then
        return false, "Could not load key server."
    end

    local _, globalEntry = lookupKey(data.global, inputKey)

    if globalEntry then
        if isExpired(globalEntry) then
            sendLog(
                "⏰ Key Expired",
                "A global key has expired.",
                15105570,
                {
                    { name = "Username", value = username, inline = true },
                    { name = "User ID", value = userId, inline = true },
                    { name = "HWID", value = "```" .. clientId .. "```", inline = false },
                    { name = "Key Type", value = "Global", inline = true }
                }
            )
            return false, "This key has expired."
        end

        sendLog(
            "✅ Key Verified",
            "Global key accepted.",
            5763719,
            {
                { name = "Username", value = username, inline = true },
                { name = "User ID", value = userId, inline = true },
                { name = "HWID", value = "```" .. clientId .. "```", inline = false },
                { name = "Key", value = "||" .. inputKey .. "||", inline = false },
                { name = "Type", value = "Global (any device)", inline = true }
            }
        )

        return true, "Key verified successfully!"
    end

    local _, keyEntry = lookupKey(data.keys, inputKey)

    if not keyEntry then
        sendLog(
            "❌ Invalid Key",
            "A key that does not exist was entered.",
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

    if isExpired(keyEntry) then
        sendLog(
            "⏰ Key Expired",
            "An expired HWID key was entered.",
            15105570,
            {
                { name = "Username", value = username, inline = true },
                { name = "User ID", value = userId, inline = true },
                { name = "HWID", value = "```" .. clientId .. "```", inline = false },
                { name = "Key Type", value = "HWID", inline = true }
            }
        )
        return false, "This key has expired."
    end

    local boundHwid = keyEntry.hwid

    if boundHwid ~= nil and tostring(boundHwid) ~= "" then
        if tostring(boundHwid) ~= tostring(clientId) then
            -- GitHub raw CDN can serve stale data; retry a few times.
            local retries = 0
            while retries < 3 do
                retries = retries + 1
                task.wait(4)
                local freshData = loadKeys(true)
                if freshData then
                    local _, freshEntry = lookupKey(freshData.keys, inputKey)
                    if freshEntry then
                        local freshHwid = freshEntry.hwid
                        if freshHwid == nil or tostring(freshHwid) == "" then
                            boundHwid = nil
                            break
                        elseif tostring(freshHwid) == tostring(clientId) then
                            boundHwid = freshHwid
                            break
                        else
                            boundHwid = freshHwid
                        end
                    end
                end
            end

            if boundHwid ~= nil and tostring(boundHwid) ~= "" and tostring(boundHwid) ~= tostring(clientId) then
                sendLog(
                    "🚨 KEY LOCKED",
                    "A key bound to another device was used.",
                    16711680,
                    {
                        { name = "Username", value = username, inline = true },
                        { name = "User ID", value = userId, inline = true },
                        { name = "Current HWID", value = "```" .. clientId .. "```", inline = false },
                        { name = "Bound HWID", value = "```" .. tostring(boundHwid) .. "```", inline = false },
                        { name = "Key", value = "||" .. inputKey .. "||", inline = false }
                    }
                )
                return false, "This key is locked to another device."
            end
        end
    else
        -- First use: send a claim so the bot binds this HWID to the key.
        -- Then poll until the bind is confirmed (or timeout).
        local claimedHash = keyHash(inputKey)
        local nonce = tostring(currentTime()) .. "-" .. tostring(math.random(100000, 999999))

        postWebhook({
            content = CLAIM_PREFIX .. claimedHash .. "|" .. clientId .. "|" .. nonce,
            username = "Nyra Key Claim",
            allowed_mentions = { parse = {} },
        })

        -- Poll briefly for confirmation (best-effort).
        local deadline = currentTime() + 15
        local bound = false
        local lockedToOther = false
        local otherHwid = nil
        while currentTime() < deadline do
            task.wait(3)
            local freshData = loadKeys(true)
            if freshData then
                local _, freshEntry = lookupKey(freshData.keys, inputKey)
                if freshEntry then
                    local fh = freshEntry.hwid
                    if fh ~= nil and tostring(fh) ~= "" then
                        if tostring(fh) == tostring(clientId) then
                            bound = true
                        else
                            lockedToOther = true
                            otherHwid = tostring(fh)
                        end
                        break
                    end
                end
            end
        end

        if lockedToOther then
            sendLog(
                "🚨 KEY LOCKED",
                "A key bound to another device was used.",
                16711680,
                {
                    { name = "Username", value = username, inline = true },
                    { name = "User ID", value = userId, inline = true },
                    { name = "Current HWID", value = "```" .. clientId .. "```", inline = false },
                    { name = "Bound HWID", value = "```" .. otherHwid .. "```", inline = false },
                    { name = "Key", value = "||" .. inputKey .. "||", inline = false }
                }
            )
            return false, "This key is locked to another device."
        end

        -- If still unbound after polling, grant access anyway (best-effort).
        -- The claim was sent; the bot will bind it asynchronously.
        -- A subsequent use on a different device will be caught by the
        -- server-side staff-key safety check.
        if not bound then
            warn("[KeySystem] Bind not confirmed in time; granting access anyway.")
        end

        sendLog(
            "🔒 Key Claim Sent",
            "An unbound key is being locked to this device.",
            3447003,
            {
                { name = "Username", value = username, inline = true },
                { name = "User ID", value = userId, inline = true },
                { name = "HWID", value = "```" .. clientId .. "```", inline = false },
                { name = "Key", value = "||" .. inputKey .. "||", inline = false }
            }
        )
    end

    sendLog(
        "✅ Key Verified",
        "HWID key accepted.",
        5763719,
        {
            { name = "Username", value = username, inline = true },
            { name = "User ID", value = userId, inline = true },
            { name = "HWID", value = "```" .. clientId .. "```", inline = false },
            { name = "Key", value = "||" .. inputKey .. "||", inline = false },
            { name = "Type", value = "HWID", inline = true }
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

    saveKey(input.Text)

    task.wait(0.7)
    gui:Destroy()

    local loaded = loadMainScript()
    if not loaded then
        warn("[KeySystem] Main script failed to load after verification.")
    end
    return
end

verifyButton.MouseButton1Click:Connect(performVerification)

input.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        performVerification()
    end
end)
