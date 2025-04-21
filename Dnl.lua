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
local tweenSpeed = 1.5 -- Speed for tweening (lower = slower)

-- Script variables
local visitedServers = {}
local lastTeleport = 0
local teleportCooldown = 5
local notifiedEggs = {}
local serverSearchTime = 0
local currentTween = nil

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
if gui:IsA("TextButton") and (string.lower(gui.Text) == "play" or string.lower(gui.Text) == "start") then
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

-- Improved Discord webhook notification function
local function sendDiscordNotification(eggInfo, eggLuck)
local jobId = game.JobId
local currentPlayers = #Players:GetPlayers()
local maxPlayers = Players.MaxPlayers

-- Basic player info with privacy
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

-- Create webhook content
local webhookData = {
embeds = {
{
title = "25X Luck Egg Found 🎉",
description = "A rare egg with 25X Luck has been discovered!",
color = 16776960,
fields = {
{name = "Egg Type", value = eggType, inline = true},
{name = "Luck Multiplier", value = "x" .. tostring(eggLuck or 25), inline = true},
{name = "Height", value = height, inline = true},
{name = "Server Slots", value = currentPlayers .. "/" .. maxPlayers, inline = true},
{name = "Time Remaining", value = timeRemaining, inline = true},
{name = "Found By", value = censoredName, inline = true},
{name = "Job ID", value = jobId, inline = false},
{name = "Teleport Script", value = "```lua\n" .. teleportScript .. "\n```", inline = false}
},
timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
}
}
}

-- Send webhook with better error handling
spawn(function()
local success, response = pcall(function()
return HttpService:PostAsync(
DISCORD_WEBHOOK_URL,
HttpService:JSONEncode(webhookData),
Enum.HttpContentType.ApplicationJson,
false
)
end)

if success then
print("Discord notification sent successfully for egg: " .. eggType)
else
print("Failed to send Discord notification: " .. tostring(response))

-- Retry once after a short delay
wait(1)
pcall(function()
HttpService:PostAsync(
DISCORD_WEBHOOK_URL,
HttpService:JSONEncode(webhookData),
Enum.HttpContentType.ApplicationJson,
false
)
print("Discord notification retry successful")
end)
end
end)
end

-- Keep the existing egg detection function since it's working fine
local function find25xLuckyEgg()
print("Searching for 25x lucky eggs...")

-- Common locations to search
local searchLocations = {
workspace,
workspace:FindFirstChild("Eggs"),
workspace:FindFirstChild("LuckyEggs"),
workspace:FindFirstChild("EventEggs"),
workspace:FindFirstChild("World"),
workspace:FindFirstChild("Drops"),
workspace:FindFirstChild("SpawnedEggs")
}

-- Add any egg-related containers recursively
local function addEggContainers(parent)
for _, child in pairs(parent:GetChildren()) do
if string.find(string.lower(child.Name), "egg") or 
string.find(string.lower(child.Name), "luck") or
string.find(string.lower(child.Name), "event") or
string.find(string.lower(child.Name), "drop") then
table.insert(searchLocations, child)
end

-- Limited depth recursion for nested containers
if child:IsA("Folder") or child:IsA("Model") then
addEggContainers(child)
end
end
end

addEggContainers(workspace)

-- Enhanced functions to check for 25x luck indicators
local function checkForLuckIndicator(obj)
-- Record the reason a match was found
local reason = ""

-- Check name
if string.find(string.lower(obj.Name), "25x") or 
string.find(string.lower(obj.Name), "25 luck") or
string.find(string.lower(obj.Name), "25.luck") or
string.find(string.lower(obj.Name), "luck25") then
reason = "Name contains 25x luck indicator"
return true, reason
end

-- Check attributes
for _, attrName in ipairs({"Luck", "LuckMultiplier", "Multiplier", "Boost", "Bonus"}) do
local value = obj:GetAttribute(attrName)
if value and (value == 25 or value == "25" or value == "25x") then
reason = "Attribute " .. attrName .. " is 25"
return true, reason
end
end

-- Check value objects
local valueNames = {"LuckValue", "MultiplierValue", "Luck", "Multiplier", "Boost", "Bonus"}
for _, valueName in ipairs(valueNames) do
local valueObj = obj:FindFirstChild(valueName)
if valueObj and valueObj:IsA("ValueBase") and valueObj.Value == 25 then
reason = "Value object " .. valueName .. " is 25"
return true, reason
end
end

-- Check text labels
for _, child in pairs(obj:GetDescendants()) do
if child:IsA("TextLabel") or child:IsA("TextButton") then
local text = string.lower(child.Text)
if string.find(text, "25x") or
string.find(text, "25 luck") or
string.find(text, "x25") or
string.find(text, "luck 25") or
string.find(text, "25 times") then
reason = "UI text contains 25x indicator: " .. child.Text
return true, reason
end
end
end

-- Check BillboardGui
for _, billboard in pairs(obj:GetDescendants()) do
if billboard:IsA("BillboardGui") then
for _, label in pairs(billboard:GetDescendants()) do
if label:IsA("TextLabel") and string.find(string.lower(label.Text), "25x") then
reason = "Billboard contains 25x text: " .. label.Text
return true, reason
end
end
end
end

-- Check for special colors often used for rarities
if obj:IsA("BasePart") or obj:IsA("MeshPart") then
-- Check for golden/special color
local color = obj.Color
local isGolden = (color.R > 0.8 and color.G > 0.8 and color.B < 0.3)
local isSpecial = (color.R + color.G + color.B > 2.7) -- Very bright

if isGolden or isSpecial then
-- Check if it has a special material
if obj.Material == Enum.Material.Neon or 
obj.Material == Enum.Material.ForceField or
obj.Material == Enum.Material.Glass then
reason = "Special appearance (color + material)"
return true, reason
end
end
end

-- Check for effects/particles that might indicate rarity
for _, effect in pairs(obj:GetDescendants()) do
if effect:IsA("ParticleEmitter") or effect:IsA("Beam") or effect:IsA("Trail") then
reason = "Has special effects"
return true, reason
end
end

return false, ""
end

-- Search for eggs
local foundEggs = {}

-- Check each location
for _, location in pairs(searchLocations) do
if location then
-- Check all descendants
for _, obj in pairs(location:GetDescendants()) do
if (obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("MeshPart")) then
-- Check if it's one of our target eggs
local isTargetEgg = false
local isPriority = false
local eggType = "unknown"

-- Check for egg-like name
if string.find(string.lower(obj.Name), "egg") or
string.find(string.lower(obj.Name), "luck") then
isTargetEgg = true
eggType = "generic"
end

-- Check if it's one of our priority eggs
for _, eggName in pairs(hatchable_eggs) do
if string.find(string.lower(obj.Name), string.lower(eggName)) then
isTargetEgg = true
eggType = eggName
isPriority = (string.lower(eggName) == string.lower(egg_priority))
break
end
end

-- If it's an egg-like object, check for 25x luck
if isTargetEgg then
local is25xLucky, reason = checkForLuckIndicator(obj)

if is25xLucky then
print("Found potential 25x egg: " .. obj.Name .. " (Reason: " .. reason .. ")")

table.insert(foundEggs, {
Egg = obj,
IsPriority = isPriority,
EggType = eggType,
Reason = reason
})

-- Return immediately if it's the priority egg
if isPriority then
print("Priority egg found! " .. obj.Name)
return obj, 25, reason
end
end
end
end
end
end
end

-- Sort by priority
table.sort(foundEggs, function(a, b)
if a.IsPriority and not b.IsPriority then
return true
elseif not a.IsPriority and b.IsPriority then
return false
else
return a.EggType < b.EggType
end
end)

-- Return the first egg found (if any)
if #foundEggs > 0 then
print("Returning best match egg: " .. foundEggs[1].Egg.Name)
return foundEggs[1].Egg, 25, foundEggs[1].Reason
end

return nil
end

-- Replace teleport with tweening
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
if not humanoidRootPart then 
print("Cannot tween: HumanoidRootPart not found")
return 
end

-- Cancel any existing tween
if currentTween then
currentTween:Cancel()
currentTween = nil
end

-- Create a tween to move to the egg with an offset
local targetPosition = eggPart.Position + Vector3.new(0, 5, 0)
local distance = (targetPosition - humanoidRootPart.Position).Magnitude
local tweenInfo = TweenInfo.new(
distance / (20 * tweenSpeed), -- Time based on distance
Enum.EasingStyle.Quad,
Enum.EasingDirection.Out
)

-- Create and start the tween
currentTween = TweenService:Create(humanoidRootPart, tweenInfo, {
CFrame = CFrame.new(targetPosition)
})

currentTween:Play()

-- Wait for tween to complete
currentTween.Completed:Wait()
currentTween = nil

print("Tweened to egg")
wait(1)
end

-- Open eggs with more reliable methods
local function openEgg(egg, amount)
if not open_eggs or not egg then return end

amount = amount or egg_amount
print("Attempting to open egg: " .. egg.Name .. " x" .. amount)

-- Try proximity prompt first
local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt")
if prompt then
print("Found proximity prompt, triggering...")
for i = 1, amount do
fireproximityprompt(prompt)
wait(0.5)
end
return
end

-- Try click detectors
local clickDetector = egg:FindFirstChildWhichIsA("ClickDetector")
if clickDetector then
print("Found click detector, triggering...")
for i = 1, amount do
fireclickdetector(clickDetector)
wait(0.5)
end
return
end

-- Try remotes with different patterns
local remoteNames = {
"OpenEgg", "HatchEgg", "PurchaseEgg", "BuyEgg", "Hatch", "Open",
"EggOpener", "EggHatcher", "GetEgg", "CollectEgg"
}

-- First try to find remotes in the egg itself
local eggRemote
for _, name in pairs(remoteNames) do
local remote = egg:FindFirstChild(name, true)
if remote and (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
eggRemote = remote
break
end
end

-- Then look in ReplicatedStorage
if not eggRemote then
for _, name in pairs(remoteNames) do
local remote = ReplicatedStorage:FindFirstChild(name, true)
if remote and (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
eggRemote = remote
break
end
end
end

-- If remote found, try multiple patterns
if eggRemote then
print("Found remote: " .. eggRemote.Name .. ", firing with different patterns...")

local patterns = {
function() eggRemote:FireServer(egg) end,
function() eggRemote:FireServer(egg.Name, amount) end,
function() eggRemote:FireServer(egg.Name) end,
function() eggRemote:FireServer(amount) end,
function() eggRemote:FireServer() end,
function() eggRemote:FireServer(egg, amount) end
}

for _, pattern in ipairs(patterns) do
pcall(pattern)
wait(0.5)
end
else
print("No egg opening mechanism found")
end
end

-- Improved server hopping function
local function getRandomServer()
local servers = {}

-- Try getting servers with error handling
local success, result = pcall(function()
local url = "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=100"
return HttpService:JSONDecode(game:HttpGet(url))
end)

if not success or not result or not result.data then
-- Try alternative API endpoint
success, result = pcall(function()
local url = "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Desc&limit=100"
return HttpService:JSONDecode(game:HttpGet(url))
end)
end

if success and result and result.data then
for _, server in ipairs(result.data) do
if server.playing < server.maxPlayers and not visitedServers[server.id] then
table.insert(servers, server)
end
end
else
print("Failed to get server list")
end

if #servers > 0 then
-- Sort by player count (fewer is better for finding eggs)
table.sort(servers, function(a, b)
return a.playing < b.playing
end)

-- Pick a random server from the top 10 (or fewer if less available)
return servers[math.random(1, math.min(10, #servers))]
end

-- If we've visited all servers, reset the list
if next(visitedServers) ~= nil then
print("Resetting visited servers list")
visitedServers = {}
return getRandomServer()
end

return nil
end

-- Server hopping with better error handling
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

-- Try to teleport with better error handling
local success = pcall(function()
TeleportService:TeleportToPlaceInstance(PLACE_ID, nextServer.id, LocalPlayer)
end)

if not success then
print("Failed to teleport, retrying...")
wait(1)

success = pcall(function()
TeleportService:TeleportToPlaceInstance(PLACE_ID, nextServer.id, LocalPlayer)
end)

if not success then
print("Second teleport attempt failed, will try again later")
wait(teleportCooldown)
return false
end
end

return true
else
print("No suitable servers found, waiting before retry")
wait(5)
end

return false
end

-- Main loop with improved detection and debugging
local function mainLoop()
print("------- 25x Egg Finder Started -------")
print("Priority egg: " .. egg_priority)
pressPlayButton()
wait(5)
serverSearchTime = tick()

while wait(1) do
local foundEgg, luckValue, reason = find25xLuckyEgg()

if foundEgg then
-- Check if we've already notified about this egg
local eggId = foundEgg.Name .. "_" .. tostring(foundEgg:GetFullName())
if not notifiedEggs[eggId] then
notifiedEggs[eggId] = tick()

print("Found 25x egg: " .. foundEgg.Name .. " (Reason: " .. (reason or "Unknown") .. ")")

-- Notify, tween, and open
sendDiscordNotification(foundEgg, luckValue)
tweenToEgg(foundEgg)
openEgg(foundEgg, egg_amount)

-- Reset server search time since we found something
serverSearchTime = tick()
wait(3)
else
-- If already notified, wait a bit before next search
print("Already notified about this egg, continuing search...")
wait(3)
end
else
-- Check if we've been searching too long in this server
local searchTime = tick() - serverSearchTime
print("Searched for " .. math.floor(searchTime) .. " seconds out of " .. maxServerSearchTime .. " max time")

if searchTime > maxServerSearchTime then
print("Maximum search time reached, hopping to next server")
if hopToNextServer() then
wait(5)
serverSearchTime = tick()
-- Clear notified eggs when server hopping
notifiedEggs = {}
pressPlayButton()
wait(5)
end
end
end
end
end

-- Add visual indicator with more information
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EggFinderGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 250, 0, 80)
frame.Position = UDim2.new(0.5, -125, 0.9, -40)
frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
frame.BackgroundTransparency = 0.5
frame.BorderSizePixel = 2
frame.BorderColor3 = Color3.fromRGB(255, 255, 0)
frame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0.5, 0)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 255, 0)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 16
title.Text = "25x Egg Finder v3"
title.Parent = frame

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, 0, 0.5, 0)
status.Position = UDim2.new(0, 0, 0.5, 0)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(255, 255, 255)
status.Font = Enum.Font.SourceSans
status.TextSize = 14
status.Text = "Looking for: " .. egg_priority
status.Parent = frame

-- Update status text periodically
spawn(function()
while wait(1) do
local timeSpent = tick() - serverSearchTime
local timeLeft = math.max(0, maxServerSearchTime - timeSpent)
status.Text = "Looking for: " .. egg_priority .. "\nTime left: " .. math.floor(timeLeft) .. "s"
end
end)

-- Start the script with improved error handling
spawn(function()
local success, errorMsg = pcall(mainLoop)
if not success then
print("Script error: " .. tostring(errorMsg))

-- Update UI to show error
if status and status.Parent then
status.TextColor3 = Color3.fromRGB(255, 0, 0)
status.Text = "Error: Script crashed! Restarting..."
end

-- Wait and retry
wait(5)
success, errorMsg = pcall(mainLoop)

if not success then
-- Try one more time with basic error handling
print("Second attempt failed: " .. tostring(errorMsg))
if status and status.Parent then
status.Text = "Critical error - Please restart script"
end
end
end
end)

-- Auto-recovery if script stalls
spawn(function()
while wait(30) do
local currentTime = tick()
if currentTime - serverSearchTime > 120 then
print("Script appears stalled, restarting...")
serverSearchTime = currentTime -- Reset the timer
pcall(mainLoop)
end
end
end)

print("Script initialized successfully")