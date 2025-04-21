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

-- Prioritized list of hatchable eggs
local hatchable_eggs = {
"event-1", "event-2", "rainbow-egg", "void-egg", "nightmare-egg", "aura-egg"
}

-- Egg detection patterns
local eggPatterns = {
"egg", "pet", "capsule", "lootbox", "crate", "chest", "box", 
"prize", "reward", "drop", "gift", "present", "container"
}

-- Fixed play button function
local function pressPlayButtons()
print("Looking for play button...")
wait(3)

-- Find and press play button
local success = false
for _, gui in pairs(game:GetService("CoreGui"):GetDescendants()) do
if gui:IsA("TextButton") and (string.lower(gui.Text):match("play") or string.lower(gui.Text):match("start")) then
pcall(function()
gui.MouseButton1Click:Fire()
end)
success = true
print("Play button pressed")
break
end
end

if not success and LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
if gui:IsA("TextButton") and (string.lower(gui.Text):match("play") or string.lower(gui.Text):match("start")) then
pcall(function()
firesignal(gui.MouseButton1Click)
end)
success = true
print("Play button pressed (method 2)")
break
end
end
end

wait(2)

-- Find and press optimized button
success = false
for _, gui in pairs(game:GetService("CoreGui"):GetDescendants()) do
if gui:IsA("TextButton") and (string.lower(gui.Text):match("optimized") or string.lower(gui.Text):match("optimize")) then
pcall(function()
gui.MouseButton1Click:Fire()
end)
success = true
print("Optimized button pressed")
break
end
end

if not success and LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
if gui:IsA("TextButton") and (string.lower(gui.Text):match("optimized") or string.lower(gui.Text):match("optimize")) then
pcall(function()
firesignal(gui.MouseButton1Click)
end)
success = true
print("Optimized button pressed (method 2)")
break
end
end
end
end

-- Fixed Discord webhook notification
local function sendDiscordNotification(eggInfo, eggLuck)
if not eggInfo then return end

-- Prevent webhook ratelimiting
wait(1)

local jobId = game.JobId
local playerName = LocalPlayer.Name
local censoredName = string.sub(playerName, 1, 1) .. "***" .. string.sub(playerName, -1)
local height = "Unknown"

if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
height = math.floor(LocalPlayer.Character.HumanoidRootPart.Position.Y) .. "m"
end

local eggType = eggInfo.Name or "Unknown Egg"
local teleportScript = 'game:GetService("TeleportService"):TeleportToPlaceInstance(' .. 
tostring(PLACE_ID) .. ', "' .. jobId .. '", game.Players.LocalPlayer)'

local timeRemaining = math.max(0, 300 - (tick() - lastEggFoundTime))
local timeRemainingText = math.floor(timeRemaining) .. " seconds"

-- Simplified webhook data
local webhookData = {
content = "🔥 25X Luck Egg Found: " .. eggType .. " 🔥",
embeds = {
{
title = "25X Luck Egg Found",
description = "Join quickly to get the egg!",
color = 16776960,
fields = {
{name = "Egg Type", value = eggType, inline = true},
{name = "Luck", value = "x" .. tostring(eggLuck or 25), inline = true},
{name = "Time Left", value = timeRemainingText, inline = true},
{name = "Job ID", value = jobId, inline = false},
{name = "Teleport", value = "```lua\n" .. teleportScript .. "\n```", inline = false}
}
}
}
}

-- Try multiple times with error handling
spawn(function()
for attempt = 1, 3 do
local success, response = pcall(function()
return HttpService:RequestAsync({
Url = DISCORD_WEBHOOK_URL,
Method = "POST",
Headers = {
["Content-Type"] = "application/json"
},
Body = HttpService:JSONEncode(webhookData)
})
end)

if success and response.Success then
print("Discord notification sent for: " .. eggType)
return
else
print("Webhook attempt " .. attempt .. " failed, retrying...")
wait(2)
end
end
end)
end

-- Optimized egg detection
local function findLuckyEgg()
local foundEggs = {}

-- Simplified search function
local function scanForEggs(parent, depth)
if not parent or depth > 3 then return end

for _, obj in pairs(parent:GetChildren()) do
if obj ~= Players then
local objNameLower = string.lower(obj.Name)
local isEgg = false

-- Check if name matches patterns
for _, pattern in ipairs(eggPatterns) do
if string.find(objNameLower, pattern) then
isEgg = true
break
end
end

-- Check for priority eggs
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

-- If it's an egg, check for luck value
if isEgg then
local luckValue = nil
local isPriority = false

-- Check attributes
for _, attrName in ipairs({"Luck", "LuckMultiplier", "Multiplier", "Boost"}) do
local value = obj:GetAttribute(attrName)
if value and type(value) == "number" and value >= 25 then
luckValue = value
break
end
end

-- Check values
if not luckValue then
for _, valueName in ipairs({"LuckValue", "Luck", "Multiplier", "Value"}) do
local valueObj = obj:FindFirstChild(valueName)
if valueObj and valueObj:IsA("ValueBase") and valueObj.Value >= 25 then
luckValue = valueObj.Value
break
end
end
end

-- Check for priority
for _, name in pairs(hatchable_eggs) do
if string.find(objNameLower, string.lower(name)) then
isPriority = (string.lower(name) == string.lower(egg_priority))
break
end
end

-- Add to results if it has luck
if luckValue and luckValue >= 25 then
table.insert(foundEggs, {
Egg = obj,
LuckValue = luckValue,
IsPriority = isPriority
})

-- Return immediately for priority eggs
if isPriority then return end
end
end

-- Scan children
scanForEggs(obj, depth + 1)
end
end
end

-- Scan workspace and storage
scanForEggs(workspace, 0)
scanForEggs(ReplicatedStorage, 0)

-- Sort by priority then luck
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

-- Simplified tween movement
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

local character = LocalPlayer.Character
if not character then return end

local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
if not humanoidRootPart then return end

-- Cancel existing tween
if currentTween then
currentTween:Cancel()
currentTween = nil
end

-- Simple direct tween
local targetPosition = eggPart.Position + Vector3.new(0, 5, 0)
local distance = (targetPosition - humanoidRootPart.Position).Magnitude
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
end

-- Simplified egg opening
local function openEgg(egg, amount)
if not open_eggs or not egg then return end

amount = amount or egg_amount

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

-- Try common remotes
local remotes = {
{name = "OpenEgg", args = {egg}},
{name = "HatchEgg", args = {egg.Name, amount}},
{name = "BuyEgg", args = {egg.Name}}
}

for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
if (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
for _, pattern in ipairs(remotes) do
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

-- Simplified server hopping
local function hopToNextServer()
if tick() - lastTeleport < teleportCooldown then return false end

if eggFoundRecently then
eggFoundRecently = false
serverSearchTime = tick()
return false
end

-- Get servers
local servers = {}
local success, result = pcall(function()
return HttpService:JSONDecode(game:HttpGet(
"https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=100"
))
end)

if success and result and result.data then
for _, server in ipairs(result.data) do
if server.playing < server.maxPlayers and server.playing > 0 and not visitedServers[server.id] then
table.insert(servers, server)
end
end
end

if #servers > 0 then
local server = servers[math.random(1, math.min(3, #servers))]
lastTeleport = tick()
visitedServers[server.id] = true

pcall(function()
TeleportService:TeleportToPlaceInstance(PLACE_ID, server.id, LocalPlayer)
end)

return true
end

wait(2)
return false
end

-- Streamlined main loop
local function mainLoop()
if isSearching then return end
isSearching = true

print("------- 25x Egg Finder v4.1 Started -------")
pressPlayButtons()
wait(2)
serverSearchTime = tick()

while wait(0.5) do
local foundEgg, luckValue = findLuckyEgg()

if foundEgg then
local eggId = foundEgg.Name .. "_" .. tostring(foundEgg:GetFullName())

if not notifiedEggs[eggId] or (tick() - notifiedEggs[eggId]) > 30 then
notifiedEggs[eggId] = tick()
lastEggFoundTime = tick()
eggFoundRecently = true

-- Tween to egg
tweenToEgg(foundEgg)

-- Send notification
sendDiscordNotification(foundEgg, luckValue)

-- Open egg
openEgg(foundEgg, egg_amount)

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
pressPlayButtons()
wait(2)
end
elseif eggFoundRecently and (tick() - lastEggFoundTime) > 60 then
eggFoundRecently = false
end
end
end

isSearching = false
end

-- Simple UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EggFinderGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = game:GetService("CoreGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 80)
frame.Position = UDim2.new(0.5, -100, 0.02, 0)
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
title.Text = "25x Egg Finder v4.1"
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
serverInfo.Text = "Server: " .. string.sub(game.JobId, 1, 8) .. "..."
serverInfo.Parent = frame

-- Update UI
spawn(function()
while wait(0.5) do
if not screenGui or not screenGui.Parent then return end

local timeSpent = tick() - serverSearchTime
local timeLeft = math.max(0, maxServerSearchTime - timeSpent)

if eggFoundRecently then
status.Text = "🥚 Egg Found: " .. egg_priority
status.TextColor3 = Color3.fromRGB(0, 255, 100)
else
status.Text = "Searching: " .. egg_priority .. " - " .. math.floor(timeLeft) .. "s"
status.TextColor3 = timeLeft < 3 and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(255, 255, 255)
end

serverInfo.Text = "Players: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers .. 
" | " .. math.floor(tick() - scriptStartTime) .. "s"
end
end)

-- Error recovery
spawn(function()
while true do
local success, errorMsg = pcall(mainLoop)
if not success then
print("Error: " .. tostring(errorMsg))
isSearching = false
wait(5)
end
end
end)

print("🚀 25x Egg Finder v4.1 initialized")