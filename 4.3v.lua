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
local maxServerSearchTime = 10
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
local scriptStartTime = tick()

-- Prioritized eggs
local hatchable_eggs = {
"event-1", "event-2", "rainbow-egg", "void-egg", "nightmare-egg", "aura-egg"
}

-- Egg patterns
local eggPatterns = {
"egg", "pet", "capsule", "lootbox", "crate", "chest", "box", 
"prize", "reward", "drop", "gift", "present", "container"
}

-- Better error handling for all functions
local function safeCall(func, ...)
local success, result = pcall(func, ...)
if not success then
print("Error: " .. tostring(result))
end
return success, result
end

-- Improved button pressing with multiple fallback methods
local function pressPlayButtons()
print("Looking for play button...")
wait(3)

-- Methods to try for pressing buttons
local buttonMethods = {
function(button)
button.MouseButton1Click:Fire()
end,
function(button)
firesignal(button.MouseButton1Click)
end,
function(button)
button:Activate()
end,
function(button)
for _, event in pairs(getconnections(button.MouseButton1Click)) do
event:Fire()
end
end
}

-- Try to find and press play button with multiple methods
local playButtonPressed = false

for _, interface in ipairs({game:GetService("CoreGui"), Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")}) do
if not interface then continue end

for _, gui in pairs(interface:GetDescendants()) do
if gui:IsA("TextButton") and (string.lower(gui.Text):match("play") or string.lower(gui.Text):match("start")) then
for _, method in ipairs(buttonMethods) do
local success = pcall(method, gui)
if success then
playButtonPressed = true
print("Play button pressed")
break
end
end
if playButtonPressed then break end
end
end
if playButtonPressed then break end
end

wait(2)

-- Try to find and press optimized button
if playButtonPressed then
print("Looking for optimized button...")

for _, interface in ipairs({game:GetService("CoreGui"), Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")}) do
if not interface then continue end

for _, gui in pairs(interface:GetDescendants()) do
if gui:IsA("TextButton") and (string.lower(gui.Text):match("optimized") or string.lower(gui.Text):match("optimize")) then
for _, method in ipairs(buttonMethods) do
local success = pcall(method, gui)
if success then
print("Optimized button pressed")
break
end
end
end
end
end
end
end

-- Safe UI creation without relying on PlayerGui
local function createUI()
local success, result = pcall(function()
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EggFinderGui"
screenGui.ResetOnSpawn = false

-- Try different parent methods for compatibility
pcall(function()
screenGui.Parent = game:GetService("CoreGui")
end)

if not screenGui.Parent then
pcall(function()
screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end)
end

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 220, 0, 90)
frame.Position = UDim2.new(0.5, -110, 0.02, 0)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
frame.BackgroundTransparency = 0.2
frame.BorderSizePixel = 2
frame.BorderColor3 = Color3.fromRGB(255, 215, 0)
frame.Parent = screenGui

local cornerRadius = Instance.new("UICorner")
cornerRadius.CornerRadius = UDim.new(0, 8)
cornerRadius.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0.3, 0)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Text = "25x Egg Finder v4.3"
title.Parent = frame

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, 0, 0.3, 0)
status.Position = UDim2.new(0, 0, 0.35, 0)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(255, 255, 255)
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.Text = "Searching: " .. egg_priority
status.Parent = frame

local serverInfo = Instance.new("TextLabel")
serverInfo.Size = UDim2.new(1, 0, 0.3, 0)
serverInfo.Position = UDim2.new(0, 0, 0.7, 0)
serverInfo.BackgroundTransparency = 1
serverInfo.TextColor3 = Color3.fromRGB(200, 200, 200)
serverInfo.Font = Enum.Font.Gotham
serverInfo.TextSize = 10
serverInfo.Text = "Starting..."
serverInfo.Parent = frame

return {
gui = screenGui,
frame = frame,
status = status,
serverInfo = serverInfo,
title = title
}
end)

if success then
return result
else
print("Failed to create UI: " .. tostring(result))
return nil
end
end

-- Simplified webhook sending
local function sendDiscordNotification(eggInfo, eggLuck)
if not eggInfo then return end

local jobId = game.JobId
local currentPlayers = #Players:GetPlayers()
local maxPlayers = Players.MaxPlayers or 10

-- Create webhook data
local webhookData = {
content = "🔥 25X Luck Egg Found: " .. eggInfo.Name .. " 🔥\nServer ID: " .. jobId,
embeds = {
{
title = "🥚 25X Luck Egg Found",
description = "A rare egg with 25X Luck has been discovered!",
color = 16776960,
fields = {
{name = "Egg Type", value = eggInfo.Name, inline = true},
{name = "Luck", value = "x" .. tostring(eggLuck or 25), inline = true},
{name = "Server", value = currentPlayers .. "/" .. maxPlayers, inline = true},
{name = "Job ID", value = "```" .. jobId .. "```", inline = false}
}
}
}
}

-- Try multiple webhook sending methods
spawn(function()
for attempt = 1, 3 do
-- Try method 1
local success = pcall(function()
HttpService:PostAsync(
DISCORD_WEBHOOK_URL,
HttpService:JSONEncode(webhookData),
Enum.HttpContentType.ApplicationJson,
false
)
end)

if success then
print("Discord notification sent for: " .. eggInfo.Name)
return
end

-- Try method 2
success = pcall(function()
HttpService:RequestAsync({
Url = DISCORD_WEBHOOK_URL,
Method = "POST",
Headers = {
["Content-Type"] = "application/json"
},
Body = HttpService:JSONEncode(webhookData)
})
end)

if success then
print("Discord notification sent for: " .. eggInfo.Name .. " (method 2)")
return
end

print("Webhook attempt " .. attempt .. " failed, retrying...")
wait(2)
end
end)
end

-- Combined egg detection from both scripts
local function findLuckyEgg()
local foundEggs = {}

-- Scan a parent for eggs
local function scanForEggs(parent, depth)
if not parent or depth > 3 then return end

for _, obj in pairs(parent:GetChildren()) do
if obj ~= Players then
-- Check if name matches patterns
local objNameLower = string.lower(obj.Name)
local isEgg = false

for _, pattern in ipairs(eggPatterns) do
if string.find(objNameLower, pattern) then
isEgg = true
break
end
end

-- Check for priority egg names
for _, eggName in pairs(hatchable_eggs) do
if string.find(objNameLower, string.lower(eggName)) then
isEgg = true
break
end
end

-- Check if it has interactive components
if not isEgg and (obj:IsA("Model") or obj:IsA("Part") or obj:IsA("MeshPart")) then
isEgg = obj:FindFirstChildWhichIsA("ClickDetector") or obj:FindFirstChildWhichIsA("ProximityPrompt")
end

-- Check for luck value
if isEgg then
local luckValue = 25 -- Default to 25 for safety
local isPriority = false

-- Check attributes first
for _, attrName in ipairs({"Luck", "LuckMultiplier", "Multiplier", "LuckBoost"}) do
local value = obj:GetAttribute(attrName)
if value and type(value) == "number" and value >= 25 then
luckValue = value
break
end
end

-- Check value objects
if not luckValue or luckValue == 25 then
for _, valueName in ipairs({"LuckValue", "MultiplierValue", "Luck", "Multiplier"}) do
local valueObj = obj:FindFirstChild(valueName)
if valueObj and valueObj:IsA("ValueBase") and valueObj.Value >= 25 then
luckValue = valueObj.Value
break
end
end
end

-- Check text labels for luck indicators
if not luckValue or luckValue == 25 then
for _, child in pairs(obj:GetDescendants()) do
if child:IsA("TextLabel") or child:IsA("TextButton") then
local text = string.lower(child.Text)

if string.find(text, "25x") or 
string.find(text, "x25") or 
string.find(text, "25 luck") then
luckValue = 25
break
end
end
end
end

-- Check if it's a priority egg
for _, name in pairs(hatchable_eggs) do
if string.find(objNameLower, string.lower(name)) then
isPriority = (string.lower(name) == string.lower(egg_priority))
break
end
end

table.insert(foundEggs, {
Egg = obj,
LuckValue = luckValue,
IsPriority = isPriority
})
end

-- Scan children
scanForEggs(obj, depth + 1)
end
end
end

-- Scan workspace and ReplicatedStorage
pcall(function() scanForEggs(workspace, 0) end)
pcall(function() scanForEggs(ReplicatedStorage, 0) end)

-- Sort by priority
table.sort(foundEggs, function(a, b)
if a.IsPriority and not b.IsPriority then
return true
elseif not a.IsPriority and b.IsPriority then
return false
else
return (a.LuckValue or 0) > (b.LuckValue or 0)
end
end)

-- Return best egg
if #foundEggs > 0 then
return foundEggs[1].Egg, foundEggs[1].LuckValue
end

return nil
end

-- Movement to egg with fallback to direct teleport
local function tweenToEgg(egg)
if not egg then return end

-- Find physical part
local eggPart
if egg:IsA("BasePart") or egg:IsA("MeshPart") then
eggPart = egg
else
eggPart = egg:FindFirstChildWhichIsA("BasePart") or egg:FindFirstChildWhichIsA("MeshPart")

if not eggPart then
for _, child in pairs(egg:GetDescendants()) do
if child:IsA("BasePart") or child:IsA("MeshPart") then
eggPart = child
break
end
end
end
end

if not eggPart then return end

local character = Players.LocalPlayer.Character
if not character then return end

local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
if not humanoidRootPart then return end

-- Try tween first
pcall(function()
-- Cancel existing tween
if currentTween then
currentTween:Cancel()
currentTween = nil
end

-- Create new tween
local targetPosition = eggPart.Position + Vector3.new(0, 5, 0)
local distance = (targetPosition - humanoidRootPart.Position).Magnitude

local tweenInfo = TweenInfo.new(
math.min(distance / (50 * tweenSpeed), 2),
Enum.EasingStyle.Linear
)

currentTween = TweenService:Create(humanoidRootPart, tweenInfo, {
CFrame = CFrame.new(targetPosition)
})

currentTween:Play()
end)

-- Fallback to direct teleport
wait(0.5)
pcall(function()
humanoidRootPart.CFrame = CFrame.new(eggPart.Position + Vector3.new(0, 5, 0))
end)
end

-- Improved egg interaction
local function openEgg(egg)
if not open_eggs or not egg then return end

-- Try proximity prompt
local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt")
if prompt then
for i = 1, egg_amount do
pcall(function() fireproximityprompt(prompt) end)
wait(0.2)
end
return
end

-- Try click detector
local clickDetector = egg:FindFirstChildWhichIsA("ClickDetector")
if clickDetector then
for i = 1, egg_amount do
pcall(function() fireclickdetector(clickDetector) end)
wait(0.2)
end
return
end

-- Try common remote events for eggs
local remotePatterns = {
{name = "OpenEgg", args = {egg}},
{name = "HatchEgg", args = {egg.Name}},
{name = "BuyEgg", args = {egg.Name}},
{name = "Hatch", args = {egg}},
{name = "Open", args = {egg}},
{name = "CollectEgg", args = {egg}}
}

for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
for _, pattern in ipairs(remotePatterns) do
if string.find(string.lower(remote.Name), string.lower(pattern.name)) then
for i = 1, egg_amount do
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

-- Simplified server hopping
local function hopToNextServer()
if tick() - lastTeleport < teleportCooldown then return false end

if eggFoundRecently then
eggFoundRecently = false
serverSearchTime = tick()
return false
end

print("Server hopping...")

-- Get a list of servers
local success, servers = pcall(function()
local result = {}
local baseUrl = "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=50"
local data = HttpService:JSONDecode(game:HttpGet(baseUrl))

for _, server in ipairs(data.data) do
if server.playing < server.maxPlayers and server.playing > 0 and not visitedServers[server.id] then
table.insert(result, server)
end
end

return result
end)

if success and #servers > 0 then
-- Choose a random server from the top 3
local server = servers[math.random(1, math.min(3, #servers))]
visitedServers[server.id] = true

pcall(function()
TeleportService:TeleportToPlaceInstance(PLACE_ID, server.id, Players.LocalPlayer)
end)

lastTeleport = tick()
return true
end

-- Direct teleport if server list fails
pcall(function()
TeleportService:Teleport(PLACE_ID, Players.LocalPlayer)
end)

lastTeleport = tick()
return true
end

-- Main logic with timer counting UP (not down)
local function mainLoop()
if isSearching then return end
isSearching = true

print("------- 25x Egg Finder v4.3 Started -------")
pcall(pressPlayButtons)
wait(2)
serverSearchTime = tick()

-- Create UI
local ui = createUI()

-- Main loop
while wait(0.5) do
-- Update UI if available
if ui and ui.status and ui.serverInfo then
pcall(function()
-- Important change: timer counts UP instead of DOWN
local timeSpent = tick() - serverSearchTime

if eggFoundRecently then
ui.status.Text = "🥚 Egg Found: " .. egg_priority
ui.status.TextColor3 = Color3.fromRGB(0, 255, 100)
else
-- Show elapsed time (counting up)
ui.status.Text = "Searching: " .. egg_priority .. " - " .. math.floor(timeSpent) .. "s"
ui.status.TextColor3 = timeSpent > (maxServerSearchTime - 3) and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(255, 255, 255)
end

ui.serverInfo.Text = "Server: " .. string.sub(game.JobId, 1, 8) .. " | " .. 
math.floor(tick() - scriptStartTime) .. "s"
end)
end

-- Find eggs
local foundEgg, luckValue = findLuckyEgg()

if foundEgg then
local eggId = foundEgg.Name .. "_" .. tostring(foundEgg:GetFullName())

if not notifiedEggs[eggId] or (tick() - notifiedEggs[eggId]) > 30 then
notifiedEggs[eggId] = tick()
lastEggFoundTime = tick()
eggFoundRecently = true

print("Found 25x egg: " .. foundEgg.Name)

-- Move to egg
tweenToEgg(foundEgg)

-- Send notification
pcall(function() sendDiscordNotification(foundEgg, luckValue or 25) end)

-- Try to open egg
pcall(function() openEgg(foundEgg) end)

serverSearchTime = tick()
wait(1)
end
else
local searchTime = tick() - serverSearchTime

if searchTime > maxServerSearchTime and not eggFoundRecently then
if hopToNextServer() then
wait(2)
serverSearchTime = tick()
notifiedEggs = {}
pcall(pressPlayButtons)
wait(2)
end
elseif eggFoundRecently and (tick() - lastEggFoundTime) > 60 then
eggFoundRecently = false
end
end
end

isSearching = false
end

-- Start with error handling
spawn(function()
while true do
local success, errorMsg = pcall(mainLoop)
if not success then
print("Script error: " .. tostring(errorMsg))
isSearching = false
wait(5)
-- Try to recover UI
pcall(createUI)
end
end
end)

-- Auto-recovery for stalled script
spawn(function()
while wait(15) do
local currentTime = tick()
if currentTime - serverSearchTime > 20 and isSearching then
print("Script appears stalled, restarting...")
isSearching = false
wait(1)
pcall(mainLoop)
end
end
end)

print("🚀 25x Egg Finder v4.3 initialized")