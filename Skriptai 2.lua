local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1363054781882699910/Qwa5roGAv5rj83wBwCG7BzraXD8xOc7L-eeopKGdvCSug1GhdJzx6sRRNA1tjgmbRW34"
local PLACE_ID = 8589657 -- Fixed place ID (replace with correct ID)
local visitedServers = {}

-- Only the hatchable eggs we want to focus on
local hatchable_eggs = {
"event-1", 
"event-2",
"rainbow-egg",
"void-egg",
"nightmare-egg", 
"aura-egg"
}

local egg_priority = "event-1" -- Priority egg to look for
local egg_amount = 3
local open_eggs = true

local lastTeleport = 0
local teleportCooldown = 5
local notifiedEggs = {}
local serverSearchTime = 0

-- Function to simulate button clicks
local function clickButton(button)
if not button then return false end

local function simulateMouseClick(obj)
local absolutePosition
pcall(function()
absolutePosition = obj.AbsolutePosition
end)

if absolutePosition then
local virtualMouse = {
X = absolutePosition.X + (obj.AbsoluteSize.X / 2),
Y = absolutePosition.Y + (obj.AbsoluteSize.Y / 2),
Target = obj
}

for _, event in ipairs({"InputBegan", "InputEnded"}) do
local inputObject = {
UserInputType = Enum.UserInputType.MouseButton1,
Position = Vector2.new(virtualMouse.X, virtualMouse.Y)
}

pcall(function()
UserInputService[event]:Fire(inputObject, false)
end)
end
end
end

local function fireButtonEvents(obj)
for _, event in ipairs({"MouseButton1Click", "Activated", "MouseButton1Down", "MouseButton1Up"}) do
pcall(function()
if obj[event] then
obj[event]:Fire()
end
end)
end
end

local function simulateTouchTap(obj)
local absolutePosition
pcall(function()
absolutePosition = obj.AbsolutePosition
end)

if absolutePosition then
local touchPosition = Vector2.new(
absolutePosition.X + (obj.AbsoluteSize.X / 2),
absolutePosition.Y + (obj.AbsoluteSize.Y / 2)
)

pcall(function()
UserInputService.TouchTap:Fire(touchPosition, obj)
end)
end
end

simulateMouseClick(button)
wait(0.1)
fireButtonEvents(button)
wait(0.1)
simulateTouchTap(button)

return true
end

-- Function to send webhook with better error handling
local function sendWebhook(actionType, info)
local jobId = game.JobId
local serverId = game.PlaceId
local currentPlayers = #game:GetService("Players"):GetPlayers()
local maxPlayers = game:GetService("Players").MaxPlayers

local playerName = LocalPlayer.Name
local censoredName = string.sub(playerName, 1, 1) .. "***" .. string.sub(playerName, -1)

local height = "Unknown"
if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
height = math.floor(LocalPlayer.Character.HumanoidRootPart.Position.Y) .. "m"
end

local teleportScript = 'game:GetService("TeleportService"):TeleportToPlaceInstance(' .. 
serverId .. ', "' .. jobId .. '", game.Players.LocalPlayer)'

local webhookData = {}

if actionType == "EggFound" then
local eggType = "Unknown Egg"
local luckValue = "x25"

if info then
if info.Name then
-- Improve egg type detection
local name = string.lower(info.Name)
if string.find(name, "rainbow") then
eggType = "Rainbow Egg"
elseif string.find(name, "void") then
eggType = "Void Egg"
elseif string.find(name, "nightmare") then
eggType = "Nightmare Egg"
elseif string.find(name, "aura") then
eggType = "Aura Egg"
elseif string.find(name, "event-1") then
eggType = "Event 1 Egg"
elseif string.find(name, "event-2") then
eggType = "Event 2 Egg"
else
eggType = info.Name
end
end

if info.LuckValue then
luckValue = "x" .. tostring(info.LuckValue)
end
end

webhookData = {
embeds = {
{
title = "🥚 25x Luck Egg Found! 🎯",
description = "A 25x luck egg has been discovered in this server!",
color = 16776960,
fields = {
{name = "Egg Type", value = eggType, inline = true},
{name = "Luck Boost", value = luckValue, inline = true},
{name = "Height", value = height, inline = true},
{name = "Server", value = currentPlayers .. "/" .. maxPlayers .. " players", inline = true},
{name = "Time Estimate", value = "~4 minutes remaining", inline = true},
{name = "Bot Name", value = censoredName, inline = true},
{name = "Server ID", value = jobId, inline = false},
{name = "Join Script", value = "```lua\n" .. teleportScript .. "\n```", inline = false}
},
timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
}
}
}
elseif actionType == "ServerHop" then
webhookData = {
embeds = {
{
title = "🔄 Server Hopping",
description = "No 25x eggs found after " .. math.floor(serverSearchTime) .. " seconds of searching. Changing servers...",
color = 5814783,
fields = {
{name = "Current Server", value = jobId, inline = true},
{name = "Target Server", value = info and info.targetId or "Finding new server...", inline = true},
{name = "Server Status", value = currentPlayers .. "/" .. maxPlayers .. " players", inline = true},
{name = "Servers Checked", value = #visitedServers, inline = true},
{name = "Bot Name", value = censoredName, inline = true}
},
timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
}
}
}
elseif actionType == "ServerJoined" then
webhookData = {
embeds = {
{
title = "🚀 Server Joined",
description = "Bot has joined a new server and started scanning for 25x eggs",
color = 3066993,
fields = {
{name = "Server ID", value = jobId, inline = true},
{name = "Server Status", value = currentPlayers .. "/" .. maxPlayers .. " players", inline = true},
{name = "Bot Name", value = censoredName, inline = true},
{name = "Servers Visited", value = #visitedServers, inline = true}
},
timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
}
}
}
elseif actionType == "NoEggsFound" then
webhookData = {
embeds = {
{
title = "🔍 No 25x Eggs Found",
description = "Searched for 25x hatchable eggs but none were found in this server.",
color = 15548997,
fields = {
{name = "Server ID", value = jobId, inline = true},
{name = "Search Time", value = math.floor(serverSearchTime) .. " seconds", inline = true},
{name = "Server Status", value = currentPlayers .. "/" .. maxPlayers .. " players", inline = true},
{name = "Bot Name", value = censoredName, inline = true},
{name = "Next Action", value = "Will hop to a new server shortly", inline = true}
},
timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
}
}
}
end

local jsonData = HttpService:JSONEncode(webhookData)

-- Safely attempt to send the request
local success, response = pcall(function()
return HttpService:PostAsync(
DISCORD_WEBHOOK_URL,
jsonData,
Enum.HttpContentType.ApplicationJson,
false
)
end)

if not success then
print("Webhook send failed: " .. tostring(response))
else
print("Webhook sent successfully!")
end
end

-- Main loop function to start the bot
local function main()
-- Announce that we've joined a server
sendWebhook("ServerJoined")

serverSearchTime = 0
local startTime = tick()

-- Main scanning loop
while true do
serverSearchTime = tick() - startTime

-- Press play button if needed to get into the game
pressPlayButton()

-- Scan for eggs
local targetEgg = scanFor25xEggs()

-- If we found a 25x egg
if targetEgg then
-- Try to collect it
collectEgg(targetEgg)

-- If we want to open eggs
if open_eggs then
-- Wait a bit and look for any hatch buttons
wait(1)

if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
local hatchButtons = {}
for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
if (gui:IsA("TextButton") or gui:IsA("ImageButton")) and gui.Visible then
local textLower = ""
if gui:IsA("TextButton") and gui.Text then
textLower = string.lower(gui.Text)
end

if string.find(textLower, "hatch") or 
string.find(textLower, "open") or
string.find(textLower, "use") or
string.find(textLower, "egg") then
table.insert(hatchButtons, gui)
end
end
end

-- Try to click hatch buttons
for i = 1, egg_amount do
for _, button in ipairs(hatchButtons) do
clickButton(button)
wait(0.5)
end
wait(1)
end
end
end

-- Wait to give the player time to join
wait(45)

-- Server hop after waiting
local currentTime = tick()
if currentTime - lastTeleport >= teleportCooldown then
lastTeleport = currentTime

-- Find a new server
local nextServer = getRandomServer()
if nextServer then
visitedServers[nextServer.id] = true
sendWebhook("ServerHop", {targetId = nextServer.id})
wait(1)

pcall(function()
TeleportService:TeleportToPlaceInstance(PLACE_ID, nextServer.id, LocalPlayer)
end)
end
end
else
-- If we've been searching for more than 60 seconds with no egg, server hop
if serverSearchTime > 60 then
local currentTime = tick()
if currentTime - lastTeleport >= teleportCooldown then
lastTeleport = currentTime

-- Find a new server
local nextServer = getRandomServer()
if nextServer then
visitedServers[nextServer.id] = true
sendWebhook("ServerHop", {targetId = nextServer.id})
wait(1)

pcall(function()
TeleportService:TeleportToPlaceInstance(PLACE_ID, nextServer.id, LocalPlayer)
end)
end
end
end
end

wait(1)
end
end

-- Start the script
main()