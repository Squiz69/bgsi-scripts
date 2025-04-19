local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local PLACE_ID = 85896571713843
local visitedServers = {}

local WEBHOOK_URL = "https://discord.com/api/webhooks/1363054781882699910/Qwa5roGAv5rj83wBwCG7BzraXD8xOc7L-eeopKGdvCSug1GhdJzx6sRRNA1tjgmbRW34" -- Replace with your real webhook

local targetEggs = {
    "rainbow-egg",
    "void-egg",
    "nightmare-egg",
    "aura-egg",
    "event-1",
    "event-2"
}

local egg_amount = 3
local egg_priority = "event-1"
local open_eggs = true
local hatchable_eggs = {"event-1", "event-2"}

local function isTargetEgg(name)
    name = string.lower(name)
    for _, eggName in ipairs(targetEggs) do
        if string.find(name, eggName) then
            return true
        end
    end
    return false
end

local function findTargetEgg()
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            if isTargetEgg(obj.Name) then
                return obj
            end
        end
    end
    return nil
end

-- Function to get a random unvisited server
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

local function teleportToEgg(egg)
    if egg then
        local eggPart = egg:FindFirstChildWhichIsA("BasePart")
        if eggPart then
            local position = eggPart.Position
            LocalPlayer:MoveTo(position)
            print("Teleporting to the egg at position: " .. tostring(position))
        else
            warn("No BasePart found for the egg!")
        end
    else
        warn("Egg not found for teleporting!")
    end
end

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

local function sendEggWebhook(serverInfo, jobId, egg, found)
    local eggType, luck, height, timeRemaining = extractEggData(egg)
    local foundBy = LocalPlayer.Name
    local joinLink = "https://www.roblox.com/games/" .. PLACE_ID .. "?jobId=" .. jobId
    local teleportScript = string.format("game:GetService(\"TeleportService\"):TeleportToPlaceInstance(\"%s\", \"%s\", game.Players.LocalPlayer)", tostring(PLACE_ID), jobId)

    local data = {
        content = "Egg Search Result 🎉\n" .. (found and "An egg with **" .. luck .. " Luck** has been discovered!" or "No egg found with 25x luck."),
        embeds = {{
            title = "🥚 Boost Egg Info",
            fields = {
                { name = "Egg Type", value = eggType or "N/A", inline = true },
                { name = "Luck", value = luck or "N/A", inline = true },
                { name = "Height", value = height or "N/A", inline = true },
                { name = "Server Slots", value = string.format("%d/%d", serverInfo.playing, serverInfo.maxPlayers), inline = true },
                { name = "Time Remaining", value = timeRemaining or "N/A", inline = true },
                { name = "Found By", value = foundBy, inline = true },
                { name = "Job ID", value = jobId or "N/A" },
                { name = "Join Link", value = "[Web Browser](" .. joinLink .. ")" },
                { name = "Teleport Script", value = "```lua\n" .. teleportScript .. "\n```" }
            },
            color = found and 65280 or 16711680 -- Green if egg found, Red if not
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

local function openEgg(egg)
    local replicated = game:GetService("ReplicatedStorage")
    local remoteFolder = replicated:FindFirstChild("RemoteEvents") or replicated
    local openEggRemote = remoteFolder:FindFirstChild("OpenEgg")

    if openEggRemote then
        openEggRemote:FireServer(egg.Name, "Single")
        warn("🎉 Opened egg:", egg.Name)
    else
        warn("❌ Could not find egg-opening RemoteEvent.")
    end
end

-- Function to hop to another server
local function hopToAnotherServer()
    local nextServer = getRandomServer()
    if nextServer then
        visitedServers[nextServer.id] = true
        warn("❌ No target egg found. Hopping to another server...")
        TeleportService:TeleportToPlaceInstance(PLACE_ID, nextServer.id, LocalPlayer)
    else
        warn("⚠️ No unvisited servers found. Retrying...")
        task.wait(10)  -- Wait before retrying
        hopToAnotherServer()  -- Retry if no server is found
    end
end

-- 🔁 Main loop
local function startEggSearch()
    local foundEgg = findTargetEgg()

    if foundEgg then
        print("🎯 Found egg:", foundEgg.Name)
        sendEggWebhook({playing = #Players:GetPlayers(), maxPlayers = Players.MaxPlayers}, game.JobId, foundEgg, true)
        teleportToEgg(foundEgg)
        openEgg(foundEgg)
    else
        print("⚠️ No egg found. Hopping to another server...")
        sendEggWebhook(nil, game.JobId, nil, false)
        hopToAnotherServer()  -- Hop to another server if no egg is found
    end
end

startEggSearch()
