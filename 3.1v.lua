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
local maxServerSearchTime = 60
local tweenSpeed = 2.0 -- Increased speed for faster movement

-- Script variables
local visitedServers = {}
local lastTeleport = 0
local teleportCooldown = 5
local notifiedEggs = {}
local serverSearchTime = 0
local currentTween = nil
local isSearching = false

-- Prioritized list of hatchable eggs
local hatchable_eggs = {
"event-1", 
"event-2",
"rainbow-egg",
"void-egg",
"nightmare-egg", 
"aura-egg"
}

-- Press play button when entering game
local function pressPlayButton()
print("Looking for play button...")
wait(3)

local playButtons = {}

if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
if gui:IsA("TextButton") and (string.lower(gui.Text):match("play") or string.lower(gui.Text):match("start")) then
table.insert(playButtons, gui)
end
end
end

for _, button in ipairs(playButtons) do
pcall(function()
button.MouseButton1Click:Fire()
end)
wait(0.5)
end
end

-- Improved Discord webhook notification function with retries
local function sendDiscordNotification(eggInfo, eggLuck)
-- Prevent sending empty notifications
if not eggInfo then
print("Cannot send notification: Missing egg information")
return
end

local jobId = game.JobId
local currentPlayers = #Players:GetPlayers()
local maxPlayers = Players.MaxPlayers

-- Player info with privacy
local playerName = LocalPlayer.Name
local censoredName = string.sub(playerName, 1, 1) .. "***" .. string.sub(playerName, -1)

-- Get height position
local height = "Unknown"
if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
height = math.floor(LocalPlayer.Character.HumanoidRootPart.Position.Y) .. "m"
end

-- Determine egg type
local eggType = "Unknown Egg"
if eggInfo and eggInfo.Name then
for _, eggName in pairs(hatchable_eggs) do
if string.find(string.lower(eggInfo.Name), string.lower(eggName)) then
eggType = eggInfo.Name
break
end
end
end

-- Create teleport script for users
local teleportScript = 'game:GetService("TeleportService"):TeleportToPlaceInstance(' .. 
tostring(PLACE_ID) .. ', "' .. jobId .. '", game.Players.LocalPlayer)'

-- Calculate time remaining
local timeRemaining = "Unknown"
if serverSearchTime > 0 then
local remainingSeconds = math.max(0, 300 - (tick() - serverSearchTime))
local minutes = math.floor(remainingSeconds / 60)
local seconds = math.floor(remainingSeconds % 60)
timeRemaining = minutes .. "m " .. seconds .. "s"
else
timeRemaining = "~4 minutes"
end

-- Create webhook content with enhanced formatting
local webhookData = {
embeds = {
{
title = "🔥 25X Luck Egg Found 🔥",
description = "A rare egg with 25X Luck has been discovered! Join quickly!",
color = 16776960, -- Gold color
fields = {
{name = "🥚 Egg Type", value = eggType, inline = true},
{name = "✨ Luck Multiplier", value = "x" .. tostring(eggLuck or 25), inline = true},
{name = "📏 Height", value = height, inline = true},
{name = "👥 Server Slots", value = currentPlayers .. "/" .. maxPlayers, inline = true},
{name = "⏱️ Time Remaining", value = timeRemaining, inline = true},
{name = "👤 Found By", value = censoredName, inline = true},
{name = "🆔 Job ID", value = "```" .. jobId .. "```", inline = false},
{name = "🚀 Teleport Script", value = "```lua\n" .. teleportScript .. "\n```", inline = false}
},
timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
footer = {
text = "25x Egg Finder v3.1 | Join now before it's gone!"
}
}
}
}

-- Send webhook with enhanced error handling and retries
spawn(function()
local maxRetries = 3
local retryDelay = 1

for attempt = 1, maxRetries do
local success, response = pcall(function()
return HttpService:PostAsync(
DISCORD_WEBHOOK_URL,
HttpService:JSONEncode(webhookData),
Enum.HttpContentType.ApplicationJson,
false
)
end)

if success then
print("Discord notification sent successfully for egg: " .. eggType .. " (Attempt " .. attempt .. ")")
return
else
print("Failed to send Discord notification (Attempt " .. attempt .. "): " .. tostring(response))

if attempt < maxRetries then
wait(retryDelay)
retryDelay = retryDelay * 2 -- Exponential backoff
end
end
end

print("All webhook sending attempts failed")
end)
end

-- Improved egg detection function focused on luck traits
local function findLuckyEgg()
print("Searching for 25x lucky eggs...")

-- Common locations to search recursively from workspace
local function scanWorkspace(parent, depth)
if depth > 5 then return {} end -- Limit recursion depth

local foundEggs = {}

for _, obj in pairs(parent:GetChildren()) do
-- Skip players and their characters to improve performance
if obj ~= Players and obj.Name ~= "Players" then
-- Check if this object is a potential egg
if (obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("MeshPart")) then
-- Check for egg-like properties
local isEgg = string.find(string.lower(obj.Name), "egg") ~= nil

-- Check if it's in our hatchable list
for _, eggName in pairs(hatchable_eggs) do
if string.find(string.lower(obj.Name), string.lower(eggName)) then
isEgg = true
break
end
end

if isEgg then
-- FOCUSED LUCK CHECK - specifically look for luck attributes
local luckValue = nil
local detectionReason = nil

-- Direct luck attribute check (primary method)
for _, attrName in ipairs({"Luck", "LuckMultiplier", "Multiplier", "Boost", "Bonus"}) do
local value = obj:GetAttribute(attrName)
if value and type(value) == "number" and value >= 25 then
luckValue = value
detectionReason = "Luck attribute: " .. attrName .. " = " .. value
break
end
end

-- Check value objects with luck traits
if not luckValue then
for _, valueName in ipairs({"LuckValue", "MultiplierValue", "Luck", "Multiplier", "Boost"}) do
local valueObj = obj:FindFirstChild(valueName)
if valueObj and valueObj:IsA("ValueBase") and valueObj.Value >= 25 then
luckValue = valueObj.Value
detectionReason = "Value object: " .. valueName .. " = " .. luckValue
break
end
end
end

-- Check for UI elements with luck indicators
if not luckValue then
for _, child in pairs(obj:GetDescendants()) do
if child:IsA("TextLabel") or child:IsA("TextButton") then
local text = string.lower(child.Text)
local multiplierMatch = text:match("(%d+)%s*x%s*luck") or text:match("x%s*(%d+)%s*luck")

if multiplierMatch then
local value = tonumber(multiplierMatch)
if value and value >= 25 then
luckValue = value
detectionReason = "UI text indicator: " .. child.Text
break
end
end
end
end
end

-- If we found a luck value of 25+, add it to results
if luckValue and luckValue >= 25 then
local isPriority = false
for _, name in pairs(hatchable_eggs) do
if string.find(string.lower(obj.Name), string.lower(name)) then
isPriority = (string.lower(name) == string.lower(egg_priority))
if isPriority then break end
end
end

table.insert(foundEggs, {
Egg = obj,
LuckValue = luckValue,
IsPriority = isPriority,
Reason = detectionReason
})

print("Found luck egg: " .. obj.Name .. " with " .. luckValue .. "x luck (" .. detectionReason .. ")")

-- Return immediately if it's the priority egg
if isPriority then
return {foundEggs[#foundEggs]}
end
end
end
end

-- Recursively check children (with depth limit)
local childResults = scanWorkspace(obj, depth + 1)
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
local results = scanWorkspace(workspace, 0)

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
return bestResult.Egg, bestResult.LuckValue, bestResult.Reason
end

return nil
end

-- Improved tweening function with obstacle avoidance
local function tweenToEgg(egg)
if not egg then 
print("Cannot tween: No egg provided")
return 
end

print("Attempting to tween to egg: " .. egg.Name)

local eggPart
if egg:IsA("BasePart") or egg:IsA("MeshPart") then
eggPart = egg
else
eggPart = egg:FindFirstChildWhichIsA("BasePart") or egg:FindFirstChildWhichIsA("MeshPart")
end

if not eggPart then 
print("Cannot tween: No physical part found in egg")
return 
end

local character = LocalPlayer.Character
if not character then 
print("Cannot tween: Character not found")
return 
end

local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
local humanoid = character:FindFirstChildOfClass("Humanoid")
if not humanoidRootPart or not humanoid then 
print("Cannot tween: Missing required character parts")
return 
end

-- Cancel any existing tween
if currentTween then
currentTween:Cancel()
currentTween = nil
end

-- Create a higher target position to avoid obstacles
local targetPosition = eggPart.Position + Vector3.new(0, 10, 0)
local distance = (targetPosition - humanoidRootPart.Position).Magnitude

-- First tween up high to avoid obstacles
local upPosition = humanoidRootPart.Position + Vector3.new(0, 50, 0)
local upTweenInfo = TweenInfo.new(
0.5, -- Quick movement upward
Enum.EasingStyle.Quad,
Enum.EasingDirection.Out
)

currentTween = TweenService:Create(humanoidRootPart, upTweenInfo, {
CFrame = CFrame.new(upPosition)
})

currentTween:Play()
currentTween.Completed:Wait()

-- Then tween to the target
local mainTweenInfo = TweenInfo.new(
distance / (40 * tweenSpeed), -- Faster movement
Enum.EasingStyle.Linear,
Enum.EasingDirection.Out
)

currentTween = TweenService:Create(humanoidRootPart, mainTweenInfo, {
CFrame = CFrame.new(targetPosition)
})

currentTween:Play()
currentTween.Completed:Wait()
currentTween = nil

-- Final approach to get right next to the egg
local finalPosition = eggPart.Position + Vector3.new(0, 3, 0)
local finalTweenInfo = TweenInfo.new(
0.5,
Enum.EasingStyle.Quad,
Enum.EasingDirection.Out
)

currentTween = TweenService:Create(humanoidRootPart, finalTweenInfo, {
CFrame = CFrame.new(finalPosition)
})

currentTween:Play()
currentTween.Completed:Wait()
currentTween = nil

print("Successfully tweened to egg")
wait(0.5)
end

-- Improved egg opening function
local function openEgg(egg, amount)
if not open_eggs or not egg then return end

amount = amount or egg_amount
print("Attempting to open egg: " .. egg.Name .. " x" .. amount)

-- Try proximity prompt using fireproximityprompt (most common)
local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt")
if prompt then
print("Found proximity prompt, triggering...")
for i = 1, amount do
fireproximityprompt(prompt)
wait(0.3)
end
return
end

-- Try click detectors using fireclickdetector
local clickDetector = egg:FindFirstChildWhichIsA("ClickDetector")
if clickDetector then
print("Found click detector, triggering...")
for i = 1, amount do
fireclickdetector(clickDetector)
wait(0.3)
end
return
end

-- Common remote patterns for egg opening
local remotePatterns = {
{name = "OpenEgg", args = {egg}},
{name = "HatchEgg", args = {egg.Name, amount}},
{name = "PurchaseEgg", args = {egg.Name}},
{name = "BuyEgg", args = {egg.Name, amount}},
{name = "Hatch", args = {}},
{name = "Open", args = {egg}},
{name = "CollectEgg", args = {egg}},
{name = "GetEgg", args = {egg.Name}}
}

-- Additional patterns with just the egg name as a string
for _, pattern in ipairs(remotePatterns) do
table.insert(remotePatterns, {name = pattern.name, args = {egg.Name}})
end

-- Function to find and fire remotes
local function findAndFireRemotes(parent)
for _, remote in pairs(parent:GetDescendants()) do
if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
for _, pattern in ipairs(remotePatterns) do
if string.find(remote.Name:lower(), pattern.name:lower()) then
print("Found remote: " .. remote.Name .. ", attempting to fire...")

for i = 1, amount do
pcall(function()
remote:FireServer(unpack(pattern.args))
end)
wait(0.3)
end
end
end
end
end
end

-- Search for remotes in egg and ReplicatedStorage
findAndFireRemotes(egg)
findAndFireRemotes(ReplicatedStorage)

print("Egg open attempts completed")
end

-- Enhanced server hopping with better server selection
local function getRandomServer()
local servers = {}
local pageSize = 100
local maxPages = 5 -- Limit pages to check
local baseUrl = "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=" .. pageSize
local nextPageCursor = ""

-- Try to get up to 5 pages of servers
for page = 1, maxPages do
local success, result = pcall(function()
local url = baseUrl
if nextPageCursor and nextPageCursor ~= "" then
url = url .. "&cursor=" .. HttpService:UrlEncode(nextPageCursor)
end
return HttpService:JSONDecode(game:HttpGet(url))
end)

if success and result and result.data then
for _, server in ipairs(result.data) do
if server.playing < server.maxPlayers and server.playing > 0 and not visitedServers[server.id] then
table.insert(servers, server)
end
end

-- Get cursor for next page
if result.nextPageCursor then
nextPageCursor = result.nextPageCursor
else
break -- No more pages
end
else
break -- Error getting page
end

-- If we have enough servers, no need to query more pages
if #servers >= 20 then
break
end

wait(0.2) -- Small delay between API calls
end

if #servers > 0 then
-- Score servers based on player count (prefer servers with 3-8 players)
for i, server in ipairs(servers) do
local playerCount = server.playing
local score = 100 - math.abs(5 - playerCount) * 10 -- Optimal count is 5 players

-- Avoid nearly full servers
if playerCount > server.maxPlayers * 0.8 then
score = score - 50
end

server.score = score
end

-- Sort by score (highest first)
table.sort(servers, function(a, b)
return a.score > b.score
end)

-- Pick one of the top 5 servers randomly
return servers[math.random(1, math.min(5, #servers))]
end

-- If we've visited too many servers, reset the list
if table.getn(visitedServers) > 50 then
print("Resetting visited servers list")
visitedServers = {}
return getRandomServer()
end

return nil
end

-- Improved server hopping function
local function hopToNextServer()
if tick() - lastTeleport < teleportCooldown then 
print("Teleport on cooldown, waiting...")
return false 
end

print("Looking for a new server...")
local nextServer = getRandomServer()

if nextServer then
lastTeleport = tick()
visitedServers[nextServer.id] = true

print("Teleporting to server: " .. nextServer.id .. " with " .. nextServer.playing .. " players")

-- Use a gradual teleport approach
local attempts = 0
local maxAttempts = 3
local success = false

while attempts < maxAttempts and not success do
attempts = attempts + 1
success = pcall(function()
TeleportService:TeleportToPlaceInstance(PLACE_ID, nextServer.id, LocalPlayer)
end)

if not success then
print("Teleport attempt " .. attempts .. " failed, retrying...")
wait(1 * attempts) -- Increasing delay between attempts
end
end

if success then
return true
else
print("All teleport attempts failed, will try another server")
wait(teleportCooldown)
return hopToNextServer() -- Try another server
end
else
print("No suitable servers found, waiting before retry")
wait(5)
end

return false
end

-- Main loop with improved error handling and performance
local function mainLoop()
if isSearching then return end
isSearching = true

print("------- 25x Egg Finder v3.1 Started -------")
print("Priority egg: " .. egg_priority)
pressPlayButton()
wait(3)
serverSearchTime = tick()

while wait(1) do
local foundEgg, luckValue, reason = findLuckyEgg()

if foundEgg then
-- Check if we've already notified about this egg
local eggId = foundEgg.Name .. "_" .. tostring(foundEgg:GetFullName())

-- Only process if we haven't seen this egg recently (or it's been 60+ seconds)
if not notifiedEggs[eggId] or (tick() - notifiedEggs[eggId]) > 60 then
notifiedEggs[eggId] = tick()

print("Found 25x egg: " .. foundEgg.Name .. " with " .. tostring(luckValue) .. "x luck (" .. (reason or "Unknown") .. ")")

-- Notify, tween, and open
sendDiscordNotification(foundEgg, luckValue)
tweenToEgg(foundEgg)
openEgg(foundEgg, egg_amount)

-- Reset server search time since we found something
serverSearchTime = tick()
wait(2)
else
-- Already saw this egg recently
print("Already processed this egg, continuing search...")
wait(2)
end
else
-- Check if we've been searching too long in this server
local searchTime = tick() - serverSearchTime
print("Searched for " .. math.floor(searchTime) .. " seconds out of " .. maxServerSearchTime .. " max time")

if searchTime > maxServerSearchTime then
print("Maximum search time reached, hopping to next server")
if hopToNextServer() then
wait(3)
serverSearchTime = tick()
-- Clear notified eggs when server hopping
notifiedEggs = {}
pressPlayButton()
wait(3)
end
end
end
end

isSearching = false
end

-- Enhanced UI with more information and better styling
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EggFinderGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

-- Main frame
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 280, 0, 100)
frame.Position = UDim2.new(0.5, -140, 0.9, -50)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
frame.BackgroundTransparency = 0.2
frame.BorderSizePixel = 2
frame.BorderColor3 = Color3.fromRGB(255, 215, 0)
frame.Parent = screenGui

-- Corner rounding
local cornerRadius = Instance.new("UICorner")
cornerRadius.CornerRadius = UDim.new(0, 8)
cornerRadius.Parent = frame

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0.3, 0)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.Text = "🔍 25x Egg Finder v3.1"
title.Parent = frame

-- Status
local status = Instance.new("TextLabel")
local searchIcon = Instance.new("TextLabel")
local timeIcon = Instance.new("TextLabel")

-- Search status
searchIcon.Size = UDim2.new(0.1, 0, 0.3, 0)
searchIcon.Position = UDim2.new(0.05, 0, 0.3, 0)
searchIcon.BackgroundTransparency = 1
searchIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
searchIcon.Font = Enum.Font.GothamBold
searchIcon.TextSize = 16
searchIcon.Text = "🎯"
searchIcon.Parent = frame

status.Size = UDim2.new(0.85, 0, 0.3, 0)
status.Position = UDim2.new(0.15, 0, 0.3, 0)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(255, 255, 255)
status.Font = Enum.Font.Gotham
status.TextSize = 14
status.TextXAlignment = Enum.TextXAlignment.Left
status.Text = "Looking for: " .. egg_priority
status.Parent = frame

-- Time status
timeIcon.Size = UDim2.new(0.1, 0, 0.3, 0)
timeIcon.Position = UDim2.new(0.05, 0, 0.6, 0)
timeIcon.BackgroundTransparency = 1
timeIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
timeIcon.Font = Enum.Font.GothamBold
timeIcon.TextSize = 16
timeIcon.Text = "⏱️"
timeIcon.Parent = frame

local timeStatus = Instance.new("TextLabel")
timeStatus.Size = UDim2.new(0.85, 0, 0.3, 0)
timeStatus.Position = UDim2.new(0.15, 0, 0.6, 0)
timeStatus.BackgroundTransparency = 1
timeStatus.TextColor3 = Color3.fromRGB(255, 255, 255)
timeStatus.Font = Enum.Font.Gotham
timeStatus.TextSize = 14
timeStatus.TextXAlignment = Enum.TextXAlignment.Left
timeStatus.Text = "Time left: " .. maxServerSearchTime .. "s"
timeStatus.Parent = frame

-- Update status text periodically with better performance
spawn(function()
while wait(0.5) do
if not screenGui or not screenGui.Parent then return end

local timeSpent = tick() - serverSearchTime
local timeLeft = math.max(0, maxServerSearchTime - timeSpent)

status.Text = "Looking for: " .. egg_priority
timeStatus.Text = "Time left: " .. math.floor(timeLeft) .. "s"

if timeLeft < 10 then
timeStatus.TextColor3 = Color3.fromRGB(255, 100, 100) -- Red when almost time to hop
else
timeStatus.TextColor3 = Color3.fromRGB(255, 255, 255)
end
end
end)

-- Start the script with improved error handling and auto-restart
spawn(function()
while true do
local success, errorMsg = pcall(mainLoop)
if not success then
print("Script error: " .. tostring(errorMsg))

-- Update UI to show error
if status and status.Parent then
status.TextColor3 = Color3.fromRGB(255, 0, 0)
status.Text = "Error: Restarting..."
end

-- Wait and retry
isSearching = false
wait(3)
end
end
end)

-- Better auto-recovery mechanism
spawn(function()
while wait(15) do
local currentTime = tick()
if currentTime - serverSearchTime > 90 and isSearching then
print("Script appears stalled, restarting...")
isSearching = false
serverSearchTime = currentTime
wait(1)
pcall(mainLoop)
end
end
end)

print("🚀 25x Egg Finder v3.1 initialized successfully")