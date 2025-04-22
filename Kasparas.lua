local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Configuration
local DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1363054781882699910/Qwa5roGAv5rj83wBwCG7BzraXD8xOc7L-eeopKGdvCSug1GhdJzx6sRRNA1tjgmbRW34"
local PLACE_ID = 85896571713843
local egg_priority = "event-1" -- Priority egg to search for
local egg_amount = 3 -- How many eggs to open
local open_eggs = true -- Whether to open eggs
local maxServerSearchTime = 10 -- Server search time in seconds
local tweenSpeed = 4.0 -- Speed for tweening to eggs

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
local initialServerTime = 0
local webhookCooldown = 30
local lastWebhookSent = 0

-- Fixed play button function
local function pressPlayButtons()
print("Looking for play buttons...")
wait(1)

-- Search for play buttons using multiple methods
for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
if (gui:IsA("TextButton") or gui:IsA("ImageButton")) and gui.Visible then
local text = ""
if gui:IsA("TextButton") then
text = gui.Text:lower()
elseif gui:FindFirstChild("TextLabel") then
text = gui:FindFirstChild("TextLabel").Text:lower()
end

-- Check for common play button texts
for _, keyword in pairs({"play", "start", "enter", "join", "continue", "ok"}) do
if string.find(text, keyword) then
-- Try multiple click methods for reliability
pcall(function() gui:CaptureFocus() end)
pcall(function() gui.MouseButton1Click:Fire() end)
pcall(function() firesignal(gui.MouseButton1Click) end)
pcall(function() gui.Activated:Fire() end)
pcall(function() gui:Activate() end)

-- Try virtual input as fallback
local VirtualUser = game:GetService("VirtualUser")
pcall(function()
local position = gui.AbsolutePosition + gui.AbsoluteSize/2
VirtualUser:Button1Down(position, workspace.CurrentCamera.CFrame)
wait(0.1)
VirtualUser:Button1Up(position, workspace.CurrentCamera.CFrame)
end)

wait(0.5)
return true
end
end
end
end

-- Try to find and fire remote events related to play/join
for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
local name = remote.Name:lower()
for _, keyword in pairs({"play", "start", "enter", "join", "teleport", "loadgame"}) do
if string.find(name, keyword) then
pcall(function() remote:FireServer() end)
wait(0.5)
return true
end
end
end
end

return false
end

-- Optimized priority egg finder
local function findLuckyEgg()
print("Scanning for 25x lucky " .. egg_priority .. " egg...")

local character = LocalPlayer.Character
if not character or not character:FindFirstChild("HumanoidRootPart") then return nil end
local hrp = character.HumanoidRootPart

-- First search method: Look for eggs in workspace with priority name
for _, object in pairs(workspace:GetDescendants()) do
if object:IsA("BasePart") or object:IsA("Model") then
-- Check if object name matches priority egg
local name = object.Name:lower()
if string.find(name, egg_priority:lower()) or string.find(name, "egg") then
local distance = (hrp.Position - (object:IsA("BasePart") and object.Position or 
object:FindFirstChildWhichIsA("BasePart") and 
object:FindFirstChildWhichIsA("BasePart").Position or hrp.Position)).Magnitude

-- Only consider eggs within range
if distance <= 50 then
-- Look for GUI elements that indicate luck multiplier
for _, gui in pairs(object:GetDescendants()) do
if gui:IsA("TextLabel") or gui:IsA("BillboardGui") then
local text = ""
if gui:IsA("TextLabel") then
text = gui.Text:lower()
elseif gui:FindFirstChild("TextLabel") then
text = gui:FindFirstChild("TextLabel").Text:lower()
end

-- Check for 25x luck indicators
if string.find(text, "25x") or string.find(text, "x25") or 
string.find(text, "25 luck") or string.find(text, "luck 25") then
return object, 25
end
end
end

-- Check for attributes that might indicate luck
for _, attrName in pairs({"Luck", "LuckMultiplier", "Multiplier", "Boost"}) do
local value = object:GetAttribute(attrName)
if value and type(value) == "number" and value >= 25 then
return object, value
end
end
end
end
end
end

-- Second search method: Check global GUI for indicators
for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
if gui:IsA("TextLabel") or gui:IsA("TextButton") then
local text = gui.Text:lower()

-- Check for luck indicators with egg name
if (string.find(text, "25x") or string.find(text, "x25")) and
(string.find(text, egg_priority:lower()) or string.find(text, "egg")) then

-- If found in GUI, look for nearby eggs
for _, object in pairs(workspace:GetDescendants()) do
if (object:IsA("BasePart") or object:IsA("Model")) and
(string.find(object.Name:lower(), "egg") or 
string.find(object.Name:lower(), egg_priority:lower())) then

local part = object:IsA("BasePart") and object or 
object:FindFirstChildWhichIsA("BasePart")

if part and (hrp.Position - part.Position).Magnitude <= 50 then
return object, 25
end
end
end
end
end
end

return nil
end

-- Fixed webhook function with improved reliability
local function sendDiscordNotification(eggInfo, eggLuck)
if not eggInfo or tick() - lastWebhookSent < webhookCooldown then return false end

-- Prevent duplicate notifications
local eggId = eggInfo:GetFullName()
if notifiedEggs[eggId] and tick() - notifiedEggs[eggId] < webhookCooldown * 2 then
return false
end

notifiedEggs[eggId] = tick()
lastWebhookSent = tick()

-- Server information
local jobId = game.JobId
local playerCount = #Players:GetPlayers()
local maxPlayers = Players.MaxPlayers
local playerName = LocalPlayer.Name
local eggType = eggInfo.Name or "Unknown Egg"

-- Position info
local height = "Unknown"
if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
height = math.floor(LocalPlayer.Character.HumanoidRootPart.Position.Y) .. "m"
end

-- Create teleport script
local teleportScript = 'game:GetService("TeleportService"):TeleportToPlaceInstance(' .. 
tostring(PLACE_ID) .. ', "' .. jobId .. '", game.Players.LocalPlayer)'

-- Webhook data with proper structure
local webhookData = {
content = "", -- Leave blank for embeds only
embeds = {
{
title = "🔥 25X Luck " .. eggType .. " Found 🔥",
description = "**Priority egg with 25X Luck found!** Join quickly!",
color = 16776960, -- Yellow
fields = {
{name = "🥚 Egg Type", value = eggType, inline = true},
{name = "✨ Luck", value = "x" .. tostring(eggLuck or 25), inline = true},
{name = "📏 Height", value = height, inline = true},
{name = "👥 Players", value = playerCount .. "/" .. maxPlayers, inline = true},
{name = "⏱️ Time Left", value = "~60 seconds", inline = true},
{name = "🆔 Job ID", value = "```" .. jobId .. "```", inline = false},
{name = "🚀 Teleport", value = "```lua\n" .. teleportScript .. "\n```", inline = false}
},
footer = {text = "25x Priority Egg Finder v4.2"}
}
}
}

-- Send webhook with fallback
local success = pcall(function()
HttpService:PostAsync(
DISCORD_WEBHOOK_URL,
HttpService:JSONEncode(webhookData),
Enum.HttpContentType.ApplicationJson,
false
)
end)

-- Fallback to simpler format if failed
if not success then
wait(1)

local simpleData = {
content = "**25X LUCK " .. eggType .. " FOUND!**\nServer: " .. jobId .. 
"\nPlayers: " .. playerCount .. "/" .. maxPlayers .. 
"\nTeleport: ```" .. teleportScript .. "```"
}

success = pcall(function()
HttpService:PostAsync(
DISCORD_WEBHOOK_URL,
HttpService:JSONEncode(simpleData),
Enum.HttpContentType.ApplicationJson,
false
)
end)
end

print("Discord notification " .. (success and "sent successfully" or "failed") .. " for: " .. eggType)
return success
end

-- Streamlined tween function
local function tweenToEgg(egg)
if not egg then return false end

print("Tweening to priority egg: " .. egg.Name)

-- Find the part to tween to
local eggPart
if egg:IsA("BasePart") then
eggPart = egg
else
eggPart = egg:FindFirstChildWhichIsA("BasePart")

if not eggPart then
for _, child in pairs(egg:GetDescendants()) do
if child:IsA("BasePart") then
eggPart = child
break
end
end
end
end

if not eggPart then return false end

-- Get character and humanoid
local character = LocalPlayer.Character
if not character then return false end

local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
if not humanoidRootPart then return false end

-- Cancel existing tween
if currentTween then
currentTween:Cancel()
currentTween = nil
end

-- Create tween to egg position
local targetPosition = eggPart.Position + Vector3.new(0, 3, 0)
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

return true
end

-- Simplified egg opening function
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
return true
end

-- Try click detector
local clickDetector = egg:FindFirstChildWhichIsA("ClickDetector")
if clickDetector then
for i = 1, amount do
fireclickdetector(clickDetector)
wait(0.2)
end
return true
end

-- Try common remote events
for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
local name = remote.Name:lower()
if string.find(name, "egg") or string.find(name, "hatch") or string.find(name, "open") or string.find(name, "buy") then
for i = 1, amount do
pcall(function() remote:FireServer(egg) end)
pcall(function() remote:FireServer(egg.Name) end)
pcall(function() remote:FireServer(egg.Name, amount) end)
wait(0.2)
end
return true
end
end
end

return false
end

-- Server hopping function
local function hopToNextServer()
if tick() - lastTeleport < teleportCooldown then return false end

-- Stay in server if egg found recently
if eggFoundRecently then
print("Priority egg found recently, staying in current server")
eggFoundRecently = false
initialServerTime = tick()
serverSearchTime = tick()
return false
end

print("Finding new server...")

-- Get server list
local servers = {}
local success, result = pcall(function()
return HttpService:JSONDecode(game:HttpGet(
"https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=100"
))
end)

if success and result and result.data then
-- Filter for available servers
for _, server in ipairs(result.data) do
if server.playing < server.maxPlayers and server.playing > 0 and not visitedServers[server.id] then
-- Prioritize servers with 3-8 players
local score = 100 - math.abs(5 - server.playing) * 10
table.insert(servers, {id = server.id, score = score})
end
end

-- Sort by score and select top server
table.sort(servers, function(a, b) return a.score > b.score end)

if #servers > 0 then
local nextServer = servers[math.random(1, math.min(3, #servers))]
lastTeleport = tick()
visitedServers[nextServer.id] = true

print("Teleporting to server: " .. nextServer.id)

local success = pcall(function()
TeleportService:TeleportToPlaceInstance(PLACE_ID, nextServer.id, LocalPlayer)
end)

return success
end
end

-- Clean up visited servers if list gets too big
if table.getn(visitedServers) > 50 then
visitedServers = {}
end

wait(2)
return false
end

-- Simplified main loop
local function mainLoop()
if isSearching then return end
isSearching = true

print("------- 25x Priority Egg Finder v4.2 Started -------")
print("Priority egg: " .. egg_priority)

initialServerTime = tick()
serverSearchTime = tick()

-- Press play buttons when entering game
pressPlayButtons()
wait(1)

while wait(0.5) do
local foundEgg, luckValue = findLuckyEgg()

if foundEgg then
-- Check if we've already notified about this egg
local eggId = foundEgg:GetFullName()

if not notifiedEggs[eggId] or (tick() - notifiedEggs[eggId]) > webhookCooldown then
notifiedEggs[eggId] = tick()
lastEggFoundTime = tick()
eggFoundRecently = true

print("Found priority 25x egg: " .. foundEgg.Name .. " with " .. tostring(luckValue) .. "x luck")

-- Send notification
sendDiscordNotification(foundEgg, luckValue)

-- Tween to and open the egg
tweenToEgg(foundEgg)
openEgg(foundEgg, egg_amount)

-- Reset timers
initialServerTime = tick()
serverSearchTime = tick()
wait(1)
end
else
local totalServerTime = tick() - initialServerTime

-- Hop to next server if max time reached
if totalServerTime > maxServerSearchTime and not eggFoundRecently then
print("Max time in server reached (" .. maxServerSearchTime .. "s), hopping to next server")
if hopToNextServer() then
wait(2)
initialServerTime = tick()
serverSearchTime = tick()
notifiedEggs = {}
pressPlayButtons()
wait(1)
end
elseif eggFoundRecently and (tick() - lastEggFoundTime) > 60 then
eggFoundRecently = false
end
end
end

isSearching = false
end

-- Minimal UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EggFinderGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

-- Main frame
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 60)
frame.Position = UDim2.new(0.5, -100, 0.02, 0)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
frame.BackgroundTransparency = 0.2
frame.BorderSizePixel = 2
frame.BorderColor3 = Color3.fromRGB(255, 215, 0)
frame.Parent = screenGui

local cornerRadius = Instance.new("UICorner")
cornerRadius.CornerRadius = UDim.new(0, 6)
cornerRadius.Parent = frame

-- Status
local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, 0, 0.6, 0)
status.Position = UDim2.new(0, 0, 0, 0)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(255, 215, 0)
status.Font = Enum.Font.GothamBold
status.TextSize = 14
status.Text = "25x Egg Finder: " .. egg_priority
status.Parent = frame

-- Server info
local serverInfo = Instance.new("TextLabel")
serverInfo.Size = UDim2.new(1, 0, 0.4, 0)
serverInfo.Position = UDim2.new(0, 0, 0.6, 0)
serverInfo.BackgroundTransparency = 1
serverInfo.TextColor3 = Color3.fromRGB(200, 200, 200)
serverInfo.Font = Enum.Font.Gotham
serverInfo.TextSize = 12
serverInfo.Text = "Server: " .. string.sub(game.JobId, 1, 8) .. "..."
serverInfo.Parent = frame

-- Status update
spawn(function()
while wait(0.5) do
if not screenGui or not screenGui.Parent then return end

local timeSpent = tick() - initialServerTime
local timeLeft = math.max(0, maxServerSearchTime - timeSpent)

if eggFoundRecently then
status.Text = "🥚 Priority Egg Found!"
status.TextColor3 = Color3.fromRGB(0, 255, 100)
else
status.Text = egg_priority .. " - " .. math.floor(timeLeft) .. "s"

if timeLeft < 3 then
status.TextColor3 = Color3.fromRGB(255, 100, 100)
else
status.TextColor3 = Color3.fromRGB(255, 215, 0)
end
end

local playerCount = #Players:GetPlayers()
local maxPlayers = Players.MaxPlayers
serverInfo.Text = playerCount .. "/" .. maxPlayers .. " | " .. string.sub(game.JobId, 1, 8)
end
end)

-- Start with error handling
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
initialServerTime = currentTime
wait(1)
pcall(mainLoop)
end
end
end)

print("🚀 25x Priority Egg Finder v4.2 initialized")