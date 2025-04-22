local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Configuration
local DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1363054781882699910/Qwa5roGAv5rj83wBwCG7BzraXD8xOc7L-eeopKGdvCSug1GhdJzx6sRRNA1tjgmbRW34"
local PLACE_ID = 85896571713843
local egg_priority = "event-1"
local egg_amount = 3
local open_eggs = true
local maxServerSearchTime = 10 -- Server search time in seconds
local tweenSpeed = 4.0

-- Script variables
local visitedServers = {}
local lastTeleport = 0
local teleportCooldown = 5
local notifiedEggs = {}
local serverSearchTime = 0
local currentTween = nil
local isSearching = false
local lastEggFoundTime = 0
local eggFoundRecently = false
local initialServerTime = 0 -- Track when we first entered the server
local webhookCooldown = 30 -- Cooldown between webhook sends for the same egg
local webhookQueue = {} -- Queue for webhook messages
local lastWebhookSent = 0 -- Last time a webhook was sent

-- Prioritized list of hatchable eggs
local hatchable_eggs = {
"event-1", 
"event-2",
"rainbow-egg",
"void-egg",
"nightmare-egg", 
"aura-egg"
}

-- Enhanced egg detection with improved patterns
local function getEggPatterns()
return {
"egg", "pet", "capsule", "lootbox", "crate", "chest", "box", 
"prize", "reward", "drop", "gift", "present", "container"
}
end

-- Fixed button pressing function with better detection and validation
local function pressPlayButtons()
print("Looking for play buttons...")

-- Wait for GUI to load properly
wait(3)

-- Track button press success
local playButtonPressed = false

-- Function to find and click buttons by text patterns
local function findAndClickButton(patterns, waitTime)
if not LocalPlayer or not LocalPlayer:FindFirstChild("PlayerGui") then
return false
end -- FIXED: Changed } to )

for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
if gui:IsA("TextButton") or gui:IsA("ImageButton") then
local buttonText = ""

-- Get text from different button types
if gui:IsA("TextButton") then
buttonText = gui.Text
elseif gui:FindFirstChild("TextLabel") then
buttonText = gui:FindFirstChild("TextLabel").Text
end

buttonText = string.lower(buttonText)

-- Check against patterns
for _, pattern in ipairs(patterns) do
if string.find(buttonText, pattern) then
-- Try multiple methods to click the button
local success = pcall(function()
gui.MouseButton1Click:Fire()
end)

if not success then
pcall(function()
firesignal(gui.MouseButton1Click)
end)
end

if not success then
pcall(function()
gui.Activated:Fire()
end)
end

print("Clicked button with pattern: " .. pattern)
wait(waitTime or 0.5)
return true
end
end
end
end

return false
end

-- First try to find and click play button
playButtonPressed = findAndClickButton({"play", "start", "enter", "join"}, 1)

-- Then try to find and click quality/performance button
if playButtonPressed then
wait(1)
findAndClickButton({"optimized", "optimize", "performance", "quality", "normal", "continue", "ok"}, 0.5)
end
end

-- Optimized Discord webhook function with queue system and rate limiting
local function sendDiscordNotification(eggInfo, eggLuck)
if not eggInfo then return end

-- Create webhook data
local jobId = game.JobId
local currentPlayers = #Players:GetPlayers()
local maxPlayers = Players.MaxPlayers
local playerName = LocalPlayer.Name
local censoredName = string.sub(playerName, 1, 1) .. "***" .. string.sub(playerName, -1)
local height = "Unknown"

if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
height = math.floor(LocalPlayer.Character.HumanoidRootPart.Position.Y) .. "m"
end

local eggType = eggInfo.Name or "Unknown Egg"
local teleportScript = 'game:GetService("TeleportService"):TeleportToPlaceInstance(' .. 
tostring(PLACE_ID) .. ', "' .. jobId .. '", game.Players.LocalPlayer)'

-- Create webhook content (more compact and optimized)
local webhookData = {
embeds = {
{
title = "🔥 25X Luck Egg Found 🔥",
description = "A rare egg with 25X Luck has been discovered! Join quickly!",
color = 16776960,
fields = {
{name = "🥚 Egg Type", value = eggType, inline = true},
{name = "✨ Luck Multiplier", value = "x" .. tostring(eggLuck or 25), inline = true},
{name = "📏 Height", value = height, inline = true},
{name = "👥 Server Slots", value = currentPlayers .. "/" .. maxPlayers, inline = true},
{name = "⏱️ Time Remaining", value = "~60 seconds", inline = true},
{name = "👤 Found By", value = censoredName, inline = true},
{name = "🆔 Job ID", value = "```" .. jobId .. "```", inline = false},
{name = "🚀 Teleport Script", value = "```lua\n" .. teleportScript .. "\n```", inline = false}
},
footer = {text = "25x Egg Finder v3.4"}
}
}
}

-- Add to webhook queue
table.insert(webhookQueue, webhookData)

-- Process webhook queue in a separate thread
if #webhookQueue == 1 then
spawn(function()
processWebhookQueue()
end)
end
end

-- Process webhook queue with rate limiting
local function processWebhookQueue()
while #webhookQueue > 0 do
-- Check if we need to wait for cooldown
local currentTime = tick()
if currentTime - lastWebhookSent < 2 then -- Rate limit to 1 webhook every 2 seconds
wait(2 - (currentTime - lastWebhookSent))
end

-- Get the next webhook data
local webhookData = table.remove(webhookQueue, 1)

-- Send webhook with retry mechanism
local success = false
for attempt = 1, 3 do
success = pcall(function()
HttpService:PostAsync(
DISCORD_WEBHOOK_URL,
HttpService:JSONEncode(webhookData),
Enum.HttpContentType.ApplicationJson,
false
)
end)

if success then
print("Discord notification sent: " .. webhookData.embeds[1].fields[1].value)
lastWebhookSent = tick()
break
else
print("Webhook attempt " .. attempt .. " failed, retrying...")
wait(1)
end
end

if not success then
print("Failed to send webhook after multiple attempts")
end
end
end

-- Enhanced egg detection with multi-method approach
local function findLuckyEgg()
print("Scanning for 25x lucky eggs...")
local eggPatterns = getEggPatterns()

-- Comprehensive scan for luck attributes using multiple detection methods
local function scanForLuckEggs(parent, depth)
if depth > 5 then return {} end

local foundEggs = {}

for _, obj in pairs(parent:GetChildren()) do
if obj ~= Players and obj.Name ~= "Players" then
-- First, check direct attributes for performance
local hasLuckAttribute = false
local luckValue = nil

-- Direct attribute checks (fastest)
for _, attrName in ipairs({"Luck", "LuckMultiplier", "Multiplier", "LuckBoost", "Boost", "Rarity"}) do
local value = obj:GetAttribute(attrName)
if value and type(value) == "number" and value >= 25 then
luckValue = value
hasLuckAttribute = true
break
end
end

-- Check if it has egg-like patterns in name
local isEgg = false
local objNameLower = string.lower(obj.Name)

-- Check for egg patterns in name
for _, pattern in ipairs(eggPatterns) do
if string.find(objNameLower, pattern) then
isEgg = true
break
end
end

-- Check for priority eggs
if not isEgg then
for _, eggName in pairs(hatchable_eggs) do
if string.find(objNameLower, string.lower(eggName)) then
isEgg = true
break
end
end
end

-- Additional detection for egg models
if not isEgg and (obj:IsA("Model") or obj:IsA("Part") or obj:IsA("MeshPart")) then
-- Check for egg-like behaviors
local hasClickDetector = obj:FindFirstChildWhichIsA("ClickDetector") ~= nil
local hasProximityPrompt = obj:FindFirstChildWhichIsA("ProximityPrompt") ~= nil

if hasClickDetector or hasProximityPrompt then
isEgg = true
end
end

if isEgg then
-- If we didn't find luck value in attributes, check value objects
if not luckValue then
for _, valueName in ipairs({"LuckValue", "MultiplierValue", "Luck", "Multiplier", "Rarity", "Value"}) do
local valueObj = obj:FindFirstChild(valueName)
if valueObj and valueObj:IsA("ValueBase") and valueObj.Value >= 25 then
luckValue = valueObj.Value
break
end
end
end

-- Check for UI elements with luck indicators
if not luckValue then
for _, child in pairs(obj:GetDescendants()) do
if child:IsA("TextLabel") or child:IsA("TextButton") then
local text = string.lower(child.Text)

-- Multiple patterns for luck indicators
local multiplierPatterns = {
"(%d+)%s*x%s*luck",
"x%s*(%d+)%s*luck",
"luck%s*x%s*(%d+)",
"(%d+)%s*times",
"(%d+)%s*%%",
"(%d+)%s*multiplier",
"multi%s*(%d+)",
"x(%d+)"
}

for _, pattern in ipairs(multiplierPatterns) do
local multiplierMatch = text:match(pattern)
if multiplierMatch then
local value = tonumber(multiplierMatch)
if value and value >= 25 then
luckValue = value
break
end
end
end

if luckValue then break end
end
end
end

-- If we found a luck value of 25+, add it to results
if luckValue and luckValue >= 25 then
local isPriority = false
for _, name in pairs(hatchable_eggs) do
if string.find(objNameLower, string.lower(name)) then
isPriority = (string.lower(name) == string.lower(egg_priority))
if isPriority then break end
end
end

table.insert(foundEggs, {
Egg = obj,
LuckValue = luckValue,
IsPriority = isPriority
})

print("Found luck egg: " .. obj.Name .. " with " .. luckValue .. "x luck")

-- Return immediately if it's the priority egg
if isPriority then
return {foundEggs[#foundEggs]}
end
end
end

-- Recursively check children (with depth limit)
local childResults = scanForLuckEggs(obj, depth + 1)
for _, result in ipairs(childResults) do
table.insert(foundEggs, result)

-- Return immediately if we found a priority egg
if result.IsPriority then
return {result}
end
end
end
end

return foundEggs
end

-- Perform the scan
local results = scanForLuckEggs(workspace, 0)

-- Scan ReplicatedStorage for egg data
local storageResults = scanForLuckEggs(ReplicatedStorage, 0)
for _, result in ipairs(storageResults) do
table.insert(results, result)
end

-- Sort results by priority then luck value
table.sort(results, function(a, b)
if a.IsPriority and not b.IsPriority then
return true
elseif not a.IsPriority and b.IsPriority then
return false
else
return (a.LuckValue or 0) > (b.LuckValue or 0)
end
end)

-- Return the best egg found
if #results > 0 then
local bestResult = results[1]
return bestResult.Egg, bestResult.LuckValue
end

return nil
end

-- Improved tween movement with safety checks
local function tweenToEgg(egg)
if not egg then return end

print("Tweening to egg: " .. egg.Name)

local eggPart
if egg:IsA("BasePart") or egg:IsA("MeshPart") then
eggPart = egg
else
eggPart = egg:FindFirstChildWhichIsA("BasePart") or egg:FindFirstChildWhichIsA("MeshPart")

-- If no part found directly, search deeper
if not eggPart then
for _, child in pairs(egg:GetDescendants()) do
if child:IsA("BasePart") or child:IsA("MeshPart") then
eggPart = child
break
end
end
end
end

if not eggPart then 
print("No valid part found to tween to")
return 
end

local character = LocalPlayer.Character
if not character then 
print("Character not found")
return 
end

local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
local humanoid = character:FindFirstChildOfClass("Humanoid")
if not humanoidRootPart or not humanoid then 
print("HumanoidRootPart or Humanoid not found")
return 
end

-- Cancel any existing tween
if currentTween then
currentTween:Cancel()
currentTween = nil
end

-- Direct high-speed tween to target
local targetPosition = eggPart.Position + Vector3.new(0, 5, 0)
local distance = (targetPosition - humanoidRootPart.Position).Magnitude

-- Fast tween directly to target
local tweenInfo = TweenInfo.new(
distance / (100 * tweenSpeed), -- Much faster movement
Enum.EasingStyle.Linear
)

currentTween = TweenService:Create(humanoidRootPart, tweenInfo, {
CFrame = CFrame.new(targetPosition)
})

currentTween:Play()
currentTween.Completed:Wait()
currentTween = nil

print("Arrived at egg")
end

-- Enhanced egg opening function with more interaction methods
local function openEgg(egg, amount)
if not open_eggs or not egg then return end

amount = amount or egg_amount
print("Opening egg: " .. egg.Name .. " x" .. amount)

-- Try proximity prompt
local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt")
if prompt then
for i = 1, amount do
fireproximityprompt(prompt)
wait(0.2)
end
return
end

-- Try click detector
local clickDetector = egg:FindFirstChildWhichIsA("ClickDetector")
if clickDetector then
for i = 1, amount do
fireclickdetector(clickDetector)
wait(0.2)
end
return
end

-- Try common remote patterns for egg opening
local remotePatterns = {
{name = "OpenEgg", args = {egg}},
{name = "HatchEgg", args = {egg.Name, amount}},
{name = "PurchaseEgg", args = {egg.Name}},
{name = "BuyEgg", args = {egg.Name, amount}},
{name = "Hatch", args = {}},
{name = "Open", args = {egg}},
{name = "CollectEgg", args = {egg}}
}

-- Try with egg name string
for _, pattern in ipairs(remotePatterns) do
table.insert(remotePatterns, {name = pattern.name, args = {egg.Name}})
end

-- Find and fire remotes
for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
for _, pattern in ipairs(remotePatterns) do
if string.find(string.lower(remote.Name), string.lower(pattern.name)) then
for i = 1, amount do
pcall(function()
remote:FireServer(unpack(pattern.args))
end)
wait(0.2)
end
end
end
end
end
end

-- Efficient server hopping with caching
local function getRandomServer()
local servers = {}
local pageSize = 100
local baseUrl = "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=" .. pageSize

-- Get one page of servers
local success, result = pcall(function()
return HttpService:JSONDecode(game:HttpGet(baseUrl))
end)

if success and result and result.data then
for _, server in ipairs(result.data) do
if server.playing < server.maxPlayers and server.playing > 0 and not visitedServers[server.id] then
table.insert(servers, server)
end
end
end

if #servers > 0 then
-- Score servers (prefer 3-8 players)
for i, server in ipairs(servers) do
local playerCount = server.playing
local score = 100 - math.abs(5 - playerCount) * 10
server.score = score
end

table.sort(servers, function(a, b)
return a.score > b.score
end)

return servers[math.random(1, math.min(3, #servers))]
end

-- Clean up visited servers if too many
if table.getn(visitedServers) > 50 then
visitedServers = {}
end

return nil
end

-- Fixed server hop function that respects egg found state
local function hopToNextServer()
if tick() - lastTeleport < teleportCooldown then return false end

-- Don't hop if we found an egg recently (stay in this server)
if eggFoundRecently then
print("Egg found recently, staying in current server")
eggFoundRecently = false -- Reset flag
initialServerTime = tick() -- Reset initial server time
serverSearchTime = tick() -- Reset search time
return false
end

print("Finding new server...")
local nextServer = getRandomServer()

if nextServer then
lastTeleport = tick()
visitedServers[nextServer.id] = true

print("Teleporting to: " .. nextServer.id)

local success = pcall(function()
TeleportService:TeleportToPlaceInstance(PLACE_ID, nextServer.id, LocalPlayer)
end)

return success
end

wait(2)
return false
end

-- Fixed main loop with proper timer management
local function mainLoop()
if isSearching then return end
isSearching = true

print("------- 25x Egg Finder v3.4 Started -------")
print("Priority egg: " .. egg_priority)

-- Initialize timers
initialServerTime = tick()
serverSearchTime = tick()

-- Press play buttons when entering game
pressPlayButtons()
wait(2)

while wait(0.5) do
local foundEgg, luckValue = findLuckyEgg()

if foundEgg then
-- Check if we've already notified about this egg
local eggId = foundEgg.Name .. "_" .. tostring(foundEgg:GetFullName())

if not notifiedEggs[eggId] or (tick() - notifiedEggs[eggId]) > webhookCooldown then
notifiedEggs[eggId] = tick()
lastEggFoundTime = tick()
eggFoundRecently = true -- Set flag to prevent server hopping

print("Found 25x egg: " .. foundEgg.Name .. " with " .. tostring(luckValue) .. "x luck")

-- First tween to the egg
tweenToEgg(foundEgg)

-- Then send notification
sendDiscordNotification(foundEgg, luckValue)

-- Try to open the egg
openEgg(foundEgg, egg_amount)

-- FIXED: Reset both timer values when an egg is found
initialServerTime = tick()
serverSearchTime = tick()
wait(1)
end
else
-- FIXED: Check time since initialServerTime to prevent timer reset issues
local totalServerTime = tick() - initialServerTime
local searchTime = tick() - serverSearchTime

-- Don't hop if we found an egg recently
if totalServerTime > maxServerSearchTime and not eggFoundRecently then
print("Max time in server reached (" .. maxServerSearchTime .. "s), hopping to next server")
if hopToNextServer() then
wait(2)
initialServerTime = tick() -- Reset initial time
serverSearchTime = tick() -- Reset search time
notifiedEggs = {}
pressPlayButtons()
wait(2)
end
elseif eggFoundRecently and (tick() - lastEggFoundTime) > 60 then
-- Reset egg found flag after 60 seconds
eggFoundRecently = false
end
end
end

isSearching = false
end

-- Enhanced UI at the top of the screen
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EggFinderGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

-- Main frame
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 240, 0, 80)
frame.Position = UDim2.new(0.5, -120, 0.02, 0)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
frame.BackgroundTransparency = 0.2
frame.BorderSizePixel = 2
frame.BorderColor3 = Color3.fromRGB(255, 215, 0)
frame.Parent = screenGui

local cornerRadius = Instance.new("UICorner")
cornerRadius.CornerRadius = UDim.new(0, 8)
cornerRadius.Parent = frame

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0.4, 0)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Text = "25x Egg Finder v3.4"
title.Parent = frame

-- Status
local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, 0, 0.3, 0)
status.Position = UDim2.new(0, 0, 0.4, 0)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(255, 255, 255)
status.Font = Enum.Font.Gotham
status.TextSize = 14
status.Text = "Searching: " .. egg_priority
status.Parent = frame

-- Server info
local serverInfo = Instance.new("TextLabel")
serverInfo.Size = UDim2.new(1, 0, 0.3, 0)
serverInfo.Position = UDim2.new(0, 0, 0.7, 0)
serverInfo.BackgroundTransparency = 1
serverInfo.TextColor3 = Color3.fromRGB(200, 200, 200)
serverInfo.Font = Enum.Font.Gotham
serverInfo.TextSize = 12
serverInfo.Text = "Server: " .. string.sub(game.JobId, 1, 8) .. "..."
serverInfo.Parent = frame

-- Fixed status update function without timer reset issues
spawn(function()
while wait(0.5) do
if not screenGui or not screenGui.Parent then return end

-- FIXED: Always calculate based on initial server time
local timeSpent = tick() - initialServerTime
local timeLeft = math.max(0, maxServerSearchTime - timeSpent)

if eggFoundRecently then
status.Text = "🥚 Egg Found: " .. egg_priority
status.TextColor3 = Color3.fromRGB(0, 255, 100)
else
status.Text = "Searching: " .. egg_priority .. " - " .. math.floor(timeLeft) .. "s"

if timeLeft < 3 then
status.TextColor3 = Color3.fromRGB(255, 100, 100)
else
status.TextColor3 = Color3.fromRGB(255, 255, 255)
end
end

-- Update server info
local playerCount = #Players:GetPlayers()
local maxPlayers = Players.MaxPlayers
serverInfo.Text = "Players: " .. playerCount .. "/" .. maxPlayers .. " | ID: " .. string.sub(game.JobId, 1, 8) .. "..."
end
end)

-- Auto-restart on error
spawn(function()
while true do
local success, errorMsg = pcall(mainLoop)
if not success then
print("Error: " .. tostring(errorMsg))
isSearching = false
wait(2)
end
end
end)

-- Auto-recovery if stalled
spawn(function()
while wait(15) do
local currentTime = tick()
if currentTime - serverSearchTime > 20 and isSearching then
print("Script appears stalled, restarting...")
isSearching = false
serverSearchTime = currentTime
initialServerTime = currentTime -- FIXED: Also reset the initial time
wait(1)
pcall(mainLoop)
end
end
end)

print("🚀 25x Egg Finder v3.4 initialized")