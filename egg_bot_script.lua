
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

-- Webhook URL
local DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1363054781882699910/Qwa5roGAv5rj83wBwCG7BzraXD8xOc7L-eeopKGdvCSug1GhdJzx6sRRNA1tjgmbRW34"
local PLACE_ID = 85896571713843
local visitedServers = {}

-- Target eggs list and related variables
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

local lastTeleport = 0
local teleportCooldown = 5
local notifiedEggs = {}
local serverSearchTime = 0

-- Webhook function to send updates
local function sendWebhook(actionType, info)
    local jobId = game.JobId
    local serverId = game.PlaceId
    local currentPlayers = #game:GetService("Players"):GetPlayers()
    local maxPlayers = game:GetService("Players").MaxPlayers

    local playerName = LocalPlayer.Name
    local censoredName = string.sub(playerName, 1, 1) .. "***" .. string.sub(playerName, -1)
    
    local webhookData = {}

    if actionType == "EggFound" then
        local eggType = "Unknown Egg"
        local luckValue = "x25"
        
        if info then
            -- Determine egg type
            if info.Name then
                if string.find(string.lower(info.Name), "rainbow") then
                    eggType = "Rainbow Egg"
                elseif string.find(string.lower(info.Name), "golden") then
                    eggType = "Golden Egg"
                elseif string.find(string.lower(info.Name), "lucky") then
                    eggType = "Lucky Egg"
                else
                    eggType = info.Name
                end
            end
            
            -- Get luck value if available
            if info.LuckValue then
                luckValue = "x" .. tostring(info.LuckValue)
            end
        end
        
        webhookData = {
            embeds = {
                {
                    title = "🥚 25x Luck Egg Found! 🎯",
                    description = "A 25x luck egg has been discovered in this server!",
                    color = 16776960, -- Yellow
                    fields = {
                        {name = "Egg Type", value = eggType, inline = true},
                        {name = "Luck Boost", value = luckValue, inline = true},
                        {name = "Bot Name", value = censoredName, inline = true},
                        {name = "Server ID", value = jobId, inline = false},
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
                    description = "No 25x eggs found. Changing servers...",
                    color = 5814783, -- Blue
                    fields = {
                        {name = "Current Server", value = jobId, inline = true},
                        {name = "Server Status", value = currentPlayers .. "/" .. maxPlayers .. " players", inline = true},
                    },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                }
            }
        }
    end

    local jsonData = HttpService:JSONEncode(webhookData)

    pcall(function()
        HttpService:PostAsync(DISCORD_WEBHOOK_URL, jsonData, Enum.HttpContentType.ApplicationJson, false)
    end)
end

-- Check if the egg matches the target list
local function isTargetEgg(eggName)
    for _, targetEgg in ipairs(targetEggs) do
        if string.lower(eggName) == string.lower(targetEgg) then
            return true
        end
    end
    return false
end

-- Check for eggs with 25x luck trait
local function has25xLuck(egg)
    local luckValue = egg:GetAttribute("Luck") or egg:GetAttribute("Multiplier") or egg:GetAttribute("LuckMultiplier") or egg:GetAttribute("LuckBoost")
    if luckValue == 25 then
        return true
    end
    return false
end

-- Function to scan for eggs with the 25x luck trait and match the target eggs
local function scanForEggs()
    local allEggs = {}
    local targetEggsFound = {}

    -- Add common egg containers
    local containers = {workspace}
    local commonContainers = {"Eggs", "LuckyEggs", "RareEggs", "EventEggs", "SpawnedEggs", "GameEggs", "World", "Maps", "Drops", "Collectibles"}

    for _, containerName in ipairs(commonContainers) do
        local container = workspace:FindFirstChild(containerName)
        if container then
            table.insert(containers, container)
            
            for _, child in pairs(container:GetChildren()) do
                if child:IsA("Folder") or child:IsA("Model") then
                    table.insert(containers, child)
                end
            end
        end
    end

    for _, obj in pairs(workspace:GetDescendants()) do
        if (obj:IsA("Folder") or obj:IsA("Model")) and string.find(string.lower(obj.Name), "egg") then
            table.insert(containers, obj)
        end
    end

    -- Function to check if the egg is in the target list
    local function isLikelyEgg(obj)
        if not (obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("MeshPart")) then
            return false
        end
        
        local name = string.lower(obj.Name)
        
        -- Check if it matches any target egg
        if isTargetEgg(name) then
            return true
        end
        
        return false
    end

    local function getEggLuckValue(egg)
        local luckValue = egg:GetAttribute("Luck") or egg:GetAttribute("Multiplier") or egg:GetAttribute("LuckMultiplier") or egg:GetAttribute("LuckBoost")
        
        if luckValue and type(luckValue) == "number" then
            return luckValue
        end
        
        return nil
    end
    
    for _, container in pairs(containers) do
        for _, obj in pairs(container:GetDescendants()) do
            if isLikelyEgg(obj) then
                local eggInfo = {
                    Object = obj,
                    Name = obj.Name,
                    LuckValue = getEggLuckValue(obj),
                    Id = obj:GetFullName()
                }

                -- If the egg is in the target list and has 25x luck, send webhook
                if isTargetEgg(obj.Name) and has25xLuck(eggInfo.Object) then
                    table.insert(targetEggsFound, eggInfo)
                    sendWebhook("EggFound", eggInfo)
                end
            end
        end
    end
    
    if #targetEggsFound > 0 then
        return targetEggsFound
    else
        return nil
    end
end

-- Function to open eggs in priority
local function openEggsInPriority(eggs)
    -- Open the egg based on the priority set by egg_priority
    for _, egg in ipairs(eggs) do
        if egg.Name == egg_priority then
            -- Check if the egg has 25x luck and open it
            if has25xLuck(egg.Object) then
                teleportToEgg(egg.Object)
                openEgg(egg.Object)
                print("Opened 25x Luck Egg: " .. egg.Name)
                return
            end
        end
    end
end

-- Main loop to process found eggs and interact with them
local function mainLoop()
    -- First, try to press the play button
    pressPlayButton()
    wait(5)

    -- Scan for eggs
    local eggsFound = scanForEggs()

    -- If we found eggs, proceed with interacting
    if eggsFound then
        -- Prioritize the eggs
        openEggsInPriority(eggsFound)
    else
        -- If no eggs found, try hopping to another server
        hopToNextServer()
    end
end

-- Start the script
spawn(function()
    pcall(mainLoop)
end)
