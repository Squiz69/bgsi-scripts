local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configuration
local DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1363054781882699910/Qwa5roGAv5rj83wBwCG7BzraXD8xOc7L-eeopKGdvCSug1GhdJzx6sRRNA1tjgmbRW34"
local PLACE_ID = 85896571713843
local egg_priority = "event-1"
local egg_amount = 3
local open_eggs = true
local maxServerSearchTime = 60

-- Script variables
local visitedServers = {}
local lastTeleport = 0
local teleportCooldown = 5
local notifiedEggs = {}
local serverSearchTime = 0

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

-- Send Discord webhook notification
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

-- Create webhook
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

-- Send webhook
pcall(function()
HttpService:PostAsync(
DISCORD_WEBHOOK_URL,
HttpService:JSONEncode(webhookData),
Enum.HttpContentType.ApplicationJson,
false
)
end)
end

-- Improved egg detection
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

-- Add any egg-related containers
for _, child in pairs(workspace:GetChildren()) do
if string.find(string.lower(child.Name), "egg") or 
string.find(string.lower(child.Name), "luck") or
string.find(string.lower(child.Name), "event") or
string.find(string.lower(child.Name), "drop") then
table.insert(searchLocations, child)
end
end

-- Functions to check for 25x luck indicators
local function checkForLuckIndicator(obj)
-- Check name
if string.find(string.lower(obj.Name), "25x") or 
string.find(string.lower(obj.Name), "25 luck") then
return true
end

-- Check attributes
if obj:GetAttribute("Luck") == 25 or 
obj:GetAttribute("LuckMultiplier") == 25 or
obj:GetAttribute("Multiplier") == 25 then
return true
end

-- Check value objects
local valueObj = obj:FindFirstChild("LuckValue") or obj:FindFirstChild("MultiplierValue")
if valueObj and valueObj.Value == 25 then
return true
end

-- Check text labels
for _, child in pairs(obj:GetDescendants()) do
if child:IsA("TextLabel") and (
string.find(string.lower(child.Text), "25x") or
string.find(string.lower(child.Text), "25 luck") or
string.find(string.lower(child.Text), "25%")) then
return true
end
end

return false
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

for _, eggName in pairs(hatchable_eggs) do
if string.find(string.lower(obj.Name), string.lower(eggName)) then
isTargetEgg = true
isPriority = (string.lower(eggName) == string.lower(egg_priority))
break
end
end

-- If it's an egg and has 25x luck, add it to found eggs
if isTargetEgg and checkForLuckIndicator(obj) then
table.insert(foundEggs, {
Egg = obj,
IsPriority = isPriority
})

-- Return immediately if it's the priority egg
if isPriority then
return obj, 25
end
end
end
end
end
end

-- Return the first egg found (if any)
if #foundEggs > 0 then
return foundEggs[1].Egg, 25
end

return nil
end

-- Teleport to egg
local function teleportToEgg(egg)
if not egg then return end

local eggPart
if egg:IsA("BasePart") or egg:IsA("MeshPart") then
eggPart = egg
else
eggPart = egg:FindFirstChildWhichIsA("BasePart") or egg:FindFirstChildWhichIsA("MeshPart")
end

if not eggPart then return end

local character = LocalPlayer.Character
if not character then return end

local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
if not humanoidRootPart then return end

humanoidRootPart.CFrame = CFrame.new(eggPart.Position + Vector3.new(0, 5, 0))
wait(1)
end

-- Open eggs
local function openEgg(egg, amount)
if not open_eggs or not egg then return end

amount = amount or egg_amount

-- Try proximity prompt
local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt")
if prompt then
for i = 1, amount do
fireproximityprompt(prompt)
wait(0.5)
end
return
end

-- Try remotes
local remoteNames = {"OpenEgg", "HatchEgg", "PurchaseEgg", "BuyEgg", "Hatch", "Open"}

-- Look for egg opening remote
local eggRemote
for _, name in pairs(remoteNames) do
local remote = ReplicatedStorage:FindFirstChild(name, true)
if remote and (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
eggRemote = remote
break
end
end

-- If remote found, try to use it
if eggRemote then
local patterns = {
function() eggRemote:FireServer(egg.Name, amount) end,
function() eggRemote:FireServer(egg) end,
function() eggRemote:FireServer() end
}

for _, pattern in ipairs(patterns) do
pcall(pattern)
wait(0.5)
end
end
end

-- Get a random server
local function getRandomServer()
local servers = {}

pcall(function()
local url = "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=100"
local result = HttpService:JSONDecode(game:HttpGet(url))

if result and result.data then
for _, server in ipairs(result.data) do
if server.playing < server.maxPlayers and not visitedServers[server.id] then
table.insert(servers, server)
end
end
end
end)

if #servers > 0 then
-- Sort by player count (fewer is better)
table.sort(servers, function(a, b)
return a.playing < b.playing
end)

return servers[math.random(1, math.min(10, #servers))]
end

visitedServers = {}
return nil
end

-- Server hopping
local function hopToNextServer()
if tick() - lastTeleport < teleportCooldown then return false end

local nextServer = getRandomServer()

if nextServer then
lastTeleport = tick()
visitedServers[nextServer.id] = true

-- Try to teleport
pcall(function()
TeleportService:TeleportToPlaceInstance(PLACE_ID, nextServer.id, LocalPlayer)
end)

return true
end

wait(5)
return false
end

-- Main loop
local function mainLoop()
pressPlayButton()
wait(5)
serverSearchTime = tick()

while wait(1) do
local foundEgg, luckValue = find25xLuckyEgg()

if foundEgg then
-- Check if we've already notified about this egg
local eggId = foundEgg.Name .. "_" .. tostring(foundEgg:GetFullName())
if not notifiedEggs[eggId] then
notifiedEggs[eggId] = tick()

-- Notify, teleport, and open
sendDiscordNotification(foundEgg, luckValue)
teleportToEgg(foundEgg)
openEgg(foundEgg, egg_amount)

serverSearchTime = tick()
wait(3)
end
else
-- Check if we've been searching too long
if tick() - serverSearchTime > maxServerSearchTime then
if hopToNextServer() then
wait(5)
serverSearchTime = tick()
end
end
end
end
end

-- Add visual indicator
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EggFinderGui"
screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 40)
frame.Position = UDim2.new(0.5, -100, 0.9, -20)
frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
frame.BackgroundTransparency = 0.5
frame.BorderSizePixel = 0
frame.Parent = screenGui

local text = Instance.new("TextLabel")
text.Size = UDim2.new(1, 0, 1, 0)
text.BackgroundTransparency = 1
text.TextColor3 = Color3.fromRGB(255, 255, 255)
text.Text = "25x Egg Finder - Looking for: " .. egg_priority
text.Parent = frame

-- Start the script
spawn(function()
pcall(mainLoop)
end)

-- Auto-recovery if script stalls
spawn(function()
while wait(30) do
if tick() - serverSearchTime > 120 then
pcall(mainLoop)
end
end
end)