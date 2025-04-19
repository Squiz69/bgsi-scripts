
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local PLACE_ID = 85896571713843
local visitedServers = {}

local WEBHOOK_URL = "https://discord.com/api/webhooks/1363054781882699910/Qwa5roGAv5rj83wBwCG7BzraXD8xOc7L-eeopKGdvCSug1GhdJzx6sRRNA1tjgmbRW34" -- 🔁 Replace with your real webhook

local targetEggs = {
    "rainbow egg",
    "void egg",
    "nightmare egg",
    "aura egg",
    "bunny egg",
    "pastel egg"
}

-- 🔍 Check if name matches target eggs
local function isTargetEgg(name)
    name = string.lower(name)
    for _, eggName in ipairs(targetEggs) do
        if string.find(name, eggName) then
            return true
        end
    end
    return false
end

-- 📊 Extract real properties from the egg
local function extractEggData(egg)
    local eggType = egg.Name or "Unknown Egg"
    local luck = "Unknown"
    local height = "?"
    local timeRemaining = "Unknown"

    if egg:FindFirstChild("Luck") and egg.Luck:IsA("StringValue") then
        luck = egg.Luck.Value
    elseif egg:FindFirstChild("Luck") and egg.Luck:IsA("IntValue") then
        luck = tostring(egg.Luck.Value) .. "x"
    elseif egg:GetAttribute("Luck") then
        luck = tostring(egg:GetAttribute("Luck"))
    elseif string.find(string.lower(eggType), "25x") then
        luck = "x25"
    end

    if egg:IsA("BasePart") and egg.Position then
        height = tostring(math.floor(egg.Position.Y)) .. "m"
    elseif egg:IsA("Model") and egg:FindFirstChildWhichIsA("BasePart") then
        height = tostring(math.floor(egg:FindFirstChildWhichIsA("BasePart").Position.Y)) .. "m"
    end

    if egg:FindFirstChild("Timer") and egg.Timer:IsA("StringValue") then
        timeRemaining = egg.Timer.Value
    end

    return eggType, luck, height, timeRemaining
end

-- 🥚 Locate target egg in workspace
local function findTargetEgg()
    for _, obj in pairs(workspace:GetDescendants()) do
        if (obj:IsA("Model") or obj:IsA("BasePart")) and isTargetEgg(obj.Name) then
            return obj
        end
    end
    return nil
end

-- 🌐 Get a random unvisited server
local function getRandomServer()
    local servers = {}
    local url = "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=100"

    local success, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(url))
    end)

    if success and result and result.data then
        for _, server in ipairs(result.data) do
            if server.playing < server.maxPlayers and not visitedServers[server.id] then
                table.insert(servers, server)
            end
        end
    end

    if #servers > 0 then
        return servers[math.random(1, #servers)]
    end

    return nil
end

-- 📩 Send Discord webhook with egg info
local function sendEggWebhook(serverInfo, jobId, egg)
    local eggType, luck, height, timeRemaining = extractEggData(egg)
    local foundBy = LocalPlayer.Name
    local joinLink = "https://www.roblox.com/games/" .. PLACE_ID .. "?jobId=" .. jobId
    local teleportScript = string.format("game:GetService(\"TeleportService\"):TeleportToPlaceInstance(\"%s\", \"%s\", game.Players.LocalPlayer)", tostring(PLACE_ID), jobId)

    local data = {
        content = "Egg Found 🎉\nAn egg with **" .. luck .. " Luck** has been discovered!",
        embeds = {{
            title = "🥚 Boost Egg Info",
            fields = {
                { name = "Egg Type", value = eggType, inline = true },
                { name = "Luck", value = luck, inline = true },
                { name = "Height", value = height, inline = true },
                { name = "Server Slots", value = string.format("%d/%d", serverInfo.playing, serverInfo.maxPlayers), inline = true },
                { name = "Time Remaining", value = timeRemaining, inline = true },
                { name = "Found By", value = foundBy, inline = true },
                { name = "Job ID", value = jobId },
                { name = "Join Link", value = "[Web Browser](" .. joinLink .. ")" },
                { name = "Teleport Script", value = "```lua\n" .. teleportScript .. "\n```" }
            },
            color = 65280
        }}
    }

    local jsonData = HttpService:JSONEncode(data)

    local success, response = pcall(function()
        return HttpService:PostAsync(WEBHOOK_URL, jsonData, Enum.HttpContentType.ApplicationJson)
    end)

    if success then
        warn("✅ Webhook sent successfully!")
    else
        warn("❌ Failed to send webhook:", response)
    end
end

-- 🧨 Automatically opens the egg if found
local function openEgg(egg)
    local eggName = egg.Name
    local replicated = game:GetService("ReplicatedStorage")
    local remoteFolder = replicated:FindFirstChild("RemoteEvents") or replicated
    local openEggRemote = remoteFolder:FindFirstChild("OpenEgg")

    if openEggRemote and openEggRemote:IsA("RemoteEvent") then
        openEggRemote:FireServer(eggName, "Single") -- or "Triple"
        warn("🎉 Opened egg:", eggName)
    else
        warn("❌ Could not find egg-opening RemoteEvent.")
    end
end

-- 🔁 Main loop
local function searchLoop()
    while true do
        task.wait(5)
        local egg = findTargetEgg()
        if egg then
            local jobId = game.JobId
            print("🎯 Boost egg found:", egg.Name)

            local currentServer = {
                playing = #Players:GetPlayers(),
                maxPlayers = Players.MaxPlayers
            }

            sendEggWebhook(currentServer, jobId, egg)
            openEgg(egg)
            break
        else
            local nextServer = getRandomServer()
            if nextServer then
                visitedServers[nextServer.id] = true
                warn("❌ No target egg found. Hopping to another server...")
                TeleportService:TeleportToPlaceInstance(PLACE_ID, nextServer.id, LocalPlayer)
                break
            else
                warn("⚠️ No unvisited servers found. Retrying...")
            end
        end
    end
end

searchLoop()
