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
local maxServerSearchTime = 10 -- Shorter search time for faster server hopping
local tweenSpeed = 4.0 -- Fast movement

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
local scriptStartTime = tick()

-- Prioritized list of hatchable eggs
local hatchable_eggs = {
"event-1", 
"event-2",
"rainbow-egg",
"void-egg",
"nightmare-egg", 
"aura-egg"
}

-- Enhanced egg detection patterns
local function getEggPatterns()
return {
"egg", "pet", "capsule", "lootbox", "crate", "chest", "box", 
"prize", "reward", "drop", "gift", "present", "container"
}
end

-- Press play button and then optimized button when entering game with proper timing
-- Taken and improved from the 2nd example
local function pressPlayButtons()
print("Looking for play button...")
wait(3) -- Wait 3 seconds for the play button

local playButtonPressed = false

-- Find and press play button
if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
if gui:IsA("TextButton") then
local buttonText = string.lower(gui.Text)
if buttonText:match("play") or buttonText:match("start") then
pcall(function()
gui.MouseButton1Click:Fire()
end)
playButtonPressed = true
print("Play button pressed")
break
end
end
end
end

if playButtonPressed then
print("Looking for optimized button...")
wait(2) -- Wait 2 seconds for optimized button

if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
if gui:IsA("TextButton") then
local buttonText = string.lower(gui.Text)
if buttonText:match("optimized") or buttonText:match("optimize") then
pcall(function()
gui.MouseButton1Click:Fire()
end)
print("Optimized button pressed")
break
end
end
end
end
end
end

-- Enhanced Discord webhook notification with better timer calculation
local function sendDiscordNotification(eggInfo, eggLuck)
if not eggInfo then return end

-- Wait 1 second to allow time for the webhook to process
wait(1)

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
local eggType = eggInfo.Name or "Unknown Egg"

-- Create teleport script
local teleportScript = 'game:GetService("TeleportService"):TeleportToPlaceInstance(' .. 
tostring(PLACE_ID) .. ', "' .. jobId .. '", game.Players.LocalPlayer)'

-- Calculate time remaining - eggs typically despawn after 5 minutes (300 seconds)
local eggLifetime = 300 -- seconds
local timeElapsed = tick() - lastEggFoundTime
local timeRemaining = math.max(0, eggLifetime - timeElapsed)
local timeRemainingText = math.floor(timeRemaining) .. " seconds"

-- Create webhook content
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
{name = "⏱️ Time Remaining", value = timeRemainingText, inline = true},
{name = "👤 Found By", value = censoredName, inline = true},
{name = "🆔 Job ID", value = "```" .. jobId .. "```", inline = false},
{name = "🚀 Teleport Script", value = "```lua\n" .. teleportScript .. "\n```", inline = false}
},
footer = {text = "25x Egg Finder v4.0"},
timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
}
}
}

-- Send webhook with retries
spawn(function()
for attempt = 1, 3 do
local success = pcall(function()
HttpService:PostAsync(
DISCORD_WEBHOOK_URL,
HttpService:JSONEncode(webhookData),
Enum.HttpContentType.ApplicationJson,
false
)
end)

if success then
print("Discord notification sent for: " .. eggType)
return
else
print("Webhook attempt " .. attempt .. " failed, retrying...")
wait(1)
end
end
print("Failed to send webhook after multiple attempts")
end)
end

-- Improved egg detection that combines both approaches
local function findLuckyEgg()
print("Scanning for 25x lucky eggs...")
local eggPatterns = getEggPatterns()
local foundEggs = {}

-- Enhanced recursive search function
local function scanForLuckEggs(parent, depth)
if not parent or depth > 4 then return {} end -- Limit depth for performance

local results = {}

for _, obj in pairs(parent:GetChildren()) do
if obj ~= Players and obj.Name ~= "Players" then
-- Check if it matches egg patterns
local isEgg = false
local objNameLower = string.lower(obj.Name)

-- Match against egg patterns
for _, pattern in ipairs(eggPatterns) do
if string.find(objNameLower, pattern) then
isEgg = true
break
end
end

-- Match against priority eggs
for _, eggName in pairs(hatchable_eggs) do
if string.find(objNameLower, string.lower(eggName)) then
isEgg = true
break
end
end

-- Additional detection for egg-like objects
if not isEgg and (obj:IsA("Model") or obj:IsA("Part") or obj:IsA("MeshPart")) then
-- Check if it has egg-like behaviors
local hasClickDetector = obj:FindFirstChildWhichIsA("ClickDetector") ~= nil
local hasProximityPrompt = obj:FindFirstChildWhichIsA("ProximityPrompt") ~= nil

if hasClickDetector or hasProximityPrompt then
isEgg = true
end
end

-- Check for luck value if it's an egg
local luckValue = nil
local isPriority = false

if isEgg then
-- Check attributes first (most direct)
for _, attrName in ipairs({"Luck", "LuckMultiplier", "Multiplier", "LuckBoost", "Boost", "Rarity"}) do
local value = obj:GetAttribute(attrName)
if value and type(value) == "number" and value >= 25 then
luckValue = value
break
end
end

-- Check value objects
if not luckValue then
for _, valueName in ipairs({"LuckValue", "MultiplierValue", "Luck", "Multiplier", "Rarity", "Value"}) do
local valueObj = obj:FindFirstChild(valueName)
if valueObj and valueObj:IsA("ValueBase") and valueObj.Value >= 25 then
luckValue = valueObj.Value
break
end
end
end

-- Check text labels for luck indicators
if not luckValue then
for _, child in pairs(obj:GetDescendants()) do
if child:IsA("TextLabel") or child:IsA("TextButton") then
local text = string.lower(child.Text)

-- Look for luck multiplier patterns
if string.find(text, "25x") or 
string.find(text, "x25") or 
string.find(text, "25 luck") or
string.find(text, "25 times") then
luckValue = 25
break
end

-- Try to extract numeric value
local multiplierPatterns = {
"(%d+)%s*x%s*luck",
"x%s*(%d+)%s*luck",
"luck%s*x%s*(%d+)",
"(%d+)%s*times",
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
end

if luckValue then break end
end
end

-- Check for priority egg
for _, name in pairs(hatchable_eggs) do
if string.find(objNameLower, string.lower(name)) then
isPriority = (string.lower(name) == string.lower(egg_priority))
if isPriority then break end
end
end

-- If we found a luck value of 25+, add it to results
if luckValue and luckValue >= 25 then
table.insert(results, {
Egg = obj,
LuckValue = luckValue,
IsPriority = isPriority
})

print("Found luck egg: " .. obj.Name .. " with " .. luckValue .. "x luck")

-- Return immediately if it's the priority egg
if isPriority then
return {results[#results]}
end
end
end

-- Recursively check children
local childResults = scanForLuckEggs(obj, depth + 1)
for _, result in ipairs(childResults) do
table.insert(results, result)

-- Return immediately if we found a priority egg
if result.IsPriority then
return {result}
end
end
end
end

return results
end

-- Scan workspace and ReplicatedStorage
local workspaceResults = scanForLuckEggs(workspace, 0)
local storageResults = scanForLuckEggs(ReplicatedStorage, 0)

-- Combine results
for _, result in ipairs(workspaceResults) do
table.insert(foundEggs, result)
end

for _, result in ipairs(storageResults) do
table.insert(foundEggs, result)
end

-- Sort results by priority then luck value
table.sort(foundEggs, function(a, b)
if a.IsPriority and not b.IsPriority then
return true
elseif not a.IsPriority and b.IsPriority then
return false
else
return (a.LuckValue or 0) > (b.LuckValue or 0)
end
end)

-- Return the best egg found
if #foundEggs > 0 then
local bestResult = foundEggs[1]
return bestResult.Egg, bestResult.LuckValue
end

return nil
end

-- Improved tween movement
local function tweenToEgg(egg)
if not egg then return end

print("Tweening to egg: " .. egg.Name)

-- Find the physical part to tween to
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
if not humanoidRootPart then 
print("HumanoidRootPart not found")
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
distance / (100 * tweenSpeed),
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

-- Enhanced egg opening function
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

-- Extended list of common remote patterns for egg opening
local remotePatterns = {
{name = "OpenEgg", args = {egg}},
{name = "HatchEgg", args = {egg.Name, amount}},
{name = "PurchaseEgg", args = {egg.Name}},
{name = "BuyEgg", args = {egg.Name, amount}},
{name = "Hatch", args = {}},
{name = "Open", args = {egg}},
{name = "CollectEgg", args = {egg}},
{name = "GetEgg", args = {egg.Name}},
{name = "PickupEgg", args = {egg}},
{name = "Collect", args = {egg}},
{name = "Purchase", args = {egg.Name}},
{name = "Buy", args = {egg.Name}},
{name = "UseEgg", args = {egg}},
{name = "Use", args = {egg}}
}

-- Try with egg name string
for _, pattern in ipairs(remotePatterns) do
table.insert(remotePatterns, {name = pattern.name, args = {egg.Name}})
end

-- Add egg ID variants
if egg:GetAttribute("ID") then
local eggId = egg:GetAttribute("ID")
for _, pattern in ipairs(remotePatterns) do
table.insert(remotePatterns, {name = pattern.name, args = {eggId}})
end
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

-- Improved server hopping
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

if table.getn(visitedServers) > 50 then
visitedServers = {}
end

return nil
end

-- Server hop (but won't hop if an egg was found recently)
local function hopToNextServer()
if tick() - lastTeleport < teleportCooldown then return false end

-- Don't hop if we found an egg recently (stay in this server)
if eggFoundRecently then
print("Egg found recently, staying in current server")
eggFoundRecently = false -- Reset flag
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

-- Optimized main loop with improved egg handling and auto-timer
local function mainLoop()
if isSearching then return end
isSearching = true

print("------- 25x Egg Finder v4.0 Started -------")
print("Priority egg: " .. egg_priority)
pressPlayButtons()
wait(2)
serverSearchTime = tick()

while wait(0.5) do
local foundEgg, luckValue = findLuckyEgg()

if foundEgg then
-- Check if we've already notified about this egg
local eggId = foundEgg.Name .. "_" .. tostring(foundEgg:GetFullName())

if not notifiedEggs[eggId] or (tick() - notifiedEggs[eggId]) > 30 then
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

-- Reset search time to stay in this server longer
serverSearchTime = tick()
wait(1)
end
else
-- Check if we've been searching too long in this server
local searchTime = tick() - serverSearchTime

-- Don't hop if we found an egg recently
if searchTime > maxServerSearchTime and not eggFoundRecently then
print("Max search time reached (" .. maxServerSearchTime .. "s), hopping to next server")
if hopToNextServer() then
wait(2)
serverSearchTime = tick()
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

-- Enhanced UI with auto-timer display
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EggFinderGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

-- Main frame (moved to top of screen)
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 240, 0, 100) -- Slightly taller for more info
frame.Position = UDim2.new(0.5, -120, 0.02, 0) -- Positioned at top
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
frame.BackgroundTransparency = 0.2
frame.BorderSizePixel = 2
frame.BorderColor3 = Color3.fromRGB(255, 215, 0)
frame.Parent = screenGui

local cornerRadius = Instance.new("UICorner")
cornerRadius.CornerRadius = UDim.new(0, 8)
cornerRadius.Parent = frame

-- Add shadow effect
local shadow = Instance.new("ImageLabel")
shadow.Size = UDim2.new(1.1, 0, 1.2, 0)
shadow.Position = UDim2.new(-0.05, 0, -0.1, 0)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://131313131" -- Shadow image (replace with actual shadow asset if needed)
shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
shadow.ImageTransparency = 0.6
shadow.ZIndex = frame.ZIndex - 1
shadow.Parent = frame

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0.3, 0)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Text = "25x Egg Finder v4.0"
title.Parent = frame

-- Status
local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, 0, 0.25, 0)
status.Position = UDim2.new(0, 0, 0.3, 0)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(255, 255, 255)
status.Font = Enum.Font.Gotham
status.TextSize = 14
status.Text = "Searching: " .. egg_priority
status.Parent = frame

-- Server info
local serverInfo = Instance.new("TextLabel")
serverInfo.Size = UDim2.new(1, 0, 0.25, 0)
serverInfo.Position = UDim2.new(0, 0, 0.55, 0)
serverInfo.BackgroundTransparency = 1
serverInfo.TextColor3 = Color3.fromRGB(200, 200, 200)
serverInfo.Font = Enum.Font.Gotham
serverInfo.TextSize = 12
serverInfo.Text = "Server: " .. string.sub(game.JobId, 1, 8) .. "..."
serverInfo.Parent = frame

-- Running time
local runningTime = Instance.new("TextLabel")
runningTime.Size = UDim2.new(1, 0, 0.2, 0)
runningTime.Position = UDim2.new(0, 0, 0.8, 0)
runningTime.BackgroundTransparency = 1
runningTime.TextColor3 = Color3.fromRGB(150, 200, 255)
runningTime.Font = Enum.Font.Gotham
runningTime.TextSize = 11
runningTime.Text = "Running: 0m 0s"
runningTime.Parent = frame

-- Update status with more information
spawn(function()
while wait(0.5) do
if not screenGui or not screenGui.Parent then return end

-- Update search time info
local timeSpent = tick() - serverSearchTime
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

-- Update running time
local totalRunTime = tick() - scriptStartTime
local minutes = math.floor(totalRunTime / 60)
local seconds = math.floor(totalRunTime % 60)
runningTime.Text = "Running: " .. minutes .. "m " .. seconds .. "s"
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
while wait(10) do
local currentTime = tick()
if currentTime - serverSearchTime > 15 and isSearching then
print("Script appears stalled, restarting...")
isSearching = false
serverSearchTime = currentTime
wait(1)
pcall(mainLoop)
end
end
end)

print("🚀 25x Egg Finder v4.0 initialized")