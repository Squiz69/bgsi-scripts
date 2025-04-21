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

local function clickButton(button)
    if not button then return false end

    local function simulateMouseClick(obj)
        local absolutePosition
        pcall(function()
            absolutePosition = obj.AbsolutePosition
        end)
        
        if absolutePosition then
            local virtualMouse = {
                X = absolutePosition.X + (obj.AbsoluteSize.X/2),
                Y = absolutePosition.Y + (obj.AbsoluteSize.Y/2),
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
                absolutePosition.X + (obj.AbsoluteSize.X/2),
                absolutePosition.Y + (obj.AbsoluteSize.Y/2)
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

local function pressPlayButton()
    wait(2)
    
    local possibleButtonNames = {
        "PlayButton", "Play", "Start", "StartButton", "GoButton", "EnterGame", 
        "JoinGame", "Continue", "Enter", "Go", "Begin", "Launch"
    }
    
    local buttonsFound = {}

    local function isLikelyPlayButton(obj)
        if not (obj:IsA("TextButton") or obj:IsA("ImageButton")) then
            return false
        end
        
        if obj.Visible == false then
            return false
        end
        
        local objNameLower = string.lower(obj.Name)
        for _, btnName in ipairs(possibleButtonNames) do
            if string.find(objNameLower, string.lower(btnName)) then
                return true
            end
        end
        
        if obj:IsA("TextButton") and obj.Text then
            local textLower = string.lower(obj.Text)
            for _, btnName in ipairs(possibleButtonNames) do
                if string.find(textLower, string.lower(btnName)) then
                    return true
                end
            end
        end
        
        if obj.BackgroundColor3 and (
           (obj.BackgroundColor3.R > 0.5 and obj.BackgroundColor3.G > 0.7 and obj.BackgroundColor3.B < 0.3) or
           (obj.BackgroundColor3.R > 0.7 and obj.BackgroundColor3.G > 0.5 and obj.BackgroundColor3.B < 0.3)) then
            return true
        end
        
        return false
    end

    if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
        for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if isLikelyPlayButton(gui) then
                table.insert(buttonsFound, gui)
            end
        end
    end
    
    pcall(function()
        for _, gui in pairs(game:GetService("CoreGui"):GetDescendants()) do
            if isLikelyPlayButton(gui) then
                table.insert(buttonsFound, gui)
            end
        end
    end)
    
    table.sort(buttonsFound, function(a, b)
        local aSize = pcall(function() return a.AbsoluteSize.X * a.AbsoluteSize.Y end) and a.AbsoluteSize.X * a.AbsoluteSize.Y or 0
        local bSize = pcall(function() return b.AbsoluteSize.X * b.AbsoluteSize.Y end) and b.AbsoluteSize.X * b.AbsoluteSize.Y or 0
        return aSize > bSize
    end)
    
    local clickedAny = false
    for _, button in ipairs(buttonsFound) do
        if clickButton(button) then
            clickedAny = true
            wait(1)
        end
    end
    
    if not clickedAny and LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
        local possibleInteractives = {}
        
        for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if (gui:IsA("TextButton") or gui:IsA("ImageButton")) and gui.Visible then
                table.insert(possibleInteractives, gui)
            end
        end
        
        for _, interactive in ipairs(possibleInteractives) do
            clickButton(interactive)
            wait(0.5)
        end
    end
    
    wait(2)
end

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
    
    -- Use pcall to catch any HTTP request errors
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
    end
end

local function scanFor25xEggs()
    local allEggs = {}
    local x25Eggs = {}
    local containers = {workspace}
    
    -- Add more common container names that might have eggs
    local commonContainers = {
        "Eggs", "LuckyEggs", "RareEggs", "EventEggs", "SpawnedEggs", 
        "GameEggs", "World", "Maps", "Drops", "Collectibles", "Items",
        "LuckEggs", "BoostEggs", "SpecialEggs"
    }
    
    -- First find potential containers
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
    
    -- Also look for containers with "egg" in the name
    for _, obj in pairs(workspace:GetDescendants()) do
        if (obj:IsA("Folder") or obj:IsA("Model")) and 
           string.find(string.lower(obj.Name), "egg") then
            table.insert(containers, obj)
        end
    end
    
    -- Function to determine if an object is likely an egg
    local function isLikelyEgg(obj)
        if not (obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("MeshPart")) then
            return false
        end
        
        local name = string.lower(obj.Name)
        
        -- Check if it's one of our hatchable eggs
        local isHatchable = false
        for _, eggType in ipairs(hatchable_eggs) do
            if string.find(name, string.lower(eggType)) then
                isHatchable = true
                break
            end
        end
        
        if not isHatchable and
           not (string.find(name, "egg") or 
                string.find(name, "lucky") or 
                string.find(name, "boost") or
                string.find(name, "25x")) then
            return false
        end
        
        -- Check attributes
        if obj:GetAttribute("IsEgg") or
           obj:GetAttribute("Luck") or
           obj:GetAttribute("Multiplier") or
           obj:GetAttribute("EggType") then
            return true
        end
        
        -- Check if it has a proximity prompt
        if obj:FindFirstChildWhichIsA("ProximityPrompt") then
            return true
        end
        
        return true
    end
    
    -- Function to get an egg's luck value
    local function getEggLuckValue(egg)
        -- First try to get luck value from attributes
        local luckValue = egg:GetAttribute("Luck") or 
                         egg:GetAttribute("Multiplier") or
                         egg:GetAttribute("LuckMultiplier") or
                         egg:GetAttribute("LuckBoost") or
                         egg:GetAttribute("Boost")
        
        if luckValue and type(luckValue) == "number" then
            return luckValue
        end
        
        -- Look for a label with luck value
        local luckLabel = egg:FindFirstChild("LuckMultiplier") or 
                         egg:FindFirstChild("MultiplierLabel") or
                         egg:FindFirstChild("LuckValue") or
                         egg:FindFirstChild("BoostValue")
        
        if luckLabel and luckLabel:IsA("TextLabel") and luckLabel.Text then
            local textValue = string.match(luckLabel.Text, "(%d+)x")
            if textValue then
                return tonumber(textValue)
            end
        end
        
        -- Check for luck value in name
        local name = string.lower(egg.Name)
        local nameValue = string.match(name, "(%d+)x")
        if nameValue then
            return tonumber(nameValue)
        end
        
        -- Specifically check for "25" and "luck" or "boost"
        if (string.find(name, "25") or string.find(name, "x25")) and 
           (string.find(name, "luck") or string.find(name, "boost")) then
            return 25
        end
        
        return nil
    end
    
    -- Scan all containers for eggs
    for _, container in pairs(containers) do
        for _, obj in pairs(container:GetDescendants()) do
            if isLikelyEgg(obj) then
                local eggInfo = {
                    Object = obj,
                    Name = obj.Name,
                    LuckValue = getEggLuckValue(obj),
                    Id = obj:GetFullName()
                }
                
                table.insert(allEggs, eggInfo)
                
                -- Only add to x25Eggs if it's a 25x luck egg and it's one of our hatchable eggs
                if eggInfo.LuckValue == 25 then
                    local isHatchable = false
                    local name = string.lower(eggInfo.Name)
                    
                    for _, eggType in ipairs(hatchable_eggs) do
                        if string.find(name, string.lower(eggType)) then
                            isHatchable = true
                            break
                        end
                    end
                    
                    if isHatchable then
                        table.insert(x25Eggs, eggInfo)
                    end
                end
            end
        end
    end
    
    -- Also check GUI elements for 25x luck indicators
    if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
        for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if gui:IsA("TextLabel") and gui.Visible and gui.Text then
                local text = string.lower(gui.Text)
                if string.find(text, "25x") and 
                   (string.find(text, "luck") or string.find(text, "boost")) then
                    -- Find the closest egg that might match this text
                    local closestEgg = nil
                    local closestDistance = math.huge
                    
                    for _, eggInfo in ipairs(allEggs) do
                        -- Only look at eggs that aren't already 25x
                        if eggInfo.LuckValue ~= 25 then
                            local egg = eggInfo.Object
                            local eggPosition = nil
                            
                            pcall(function()
                                if egg:IsA("BasePart") or egg:IsA("MeshPart") then
                                    eggPosition = egg.Position
                                elseif egg:IsA("Model") and egg.PrimaryPart then
                                    eggPosition = egg.PrimaryPart.Position
                                end
                            end)
                            
                            if eggPosition and LocalPlayer.Character and 
                               LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                local distance = (LocalPlayer.Character.HumanoidRootPart.Position - eggPosition).Magnitude
                                if distance < closestDistance then
                                    -- Check if it's a hatchable egg
                                    local name = string.lower(eggInfo.Name)
                                    local isHatchable = false
                                    
                                    for _, eggType in ipairs(hatchable_eggs) do
                                        if string.find(name, string.lower(eggType)) then
                                            isHatchable = true
                                            break
                                        end
                                    end
                                    
                                    if isHatchable then
                                        closestDistance = distance
                                        closestEgg = eggInfo
                                    end
                                end
                            end
                        end
                    end
                    
                    if closestEgg and closestDistance < 50 then
                        closestEgg.LuckValue = 25
                        table.insert(x25Eggs, closestEgg)
                    end
                end
            end
        end
    end
    
    -- Get new eggs that we haven't notified about yet
    local newEggs = {}
    for _, eggInfo in ipairs(x25Eggs) do
        if not notifiedEggs[eggInfo.Id] then
            notifiedEggs[eggInfo.Id] = tick()
            table.insert(newEggs, eggInfo)
        end
    end
    
    -- Prioritize eggs based on the egg_priority setting
    table.sort(newEggs, function(a, b)
        local aName = string.lower(a.Name)
        local bName = string.lower(b.Name)
        
        -- Prioritize the egg_priority
        local aIsPriority = string.find(aName, string.lower(egg_priority)) ~= nil
        local bIsPriority = string.find(bName, string.lower(egg_priority)) ~= nil
        
        if aIsPriority and not bIsPriority then
            return true
        elseif not aIsPriority and bIsPriority then
            return false
        end
        
        -- Both are priority or neither is priority, sort by other factors
        return aName < bName  -- Simple alphabetical as fallback
    end)
    
    if #newEggs > 0 then
        sendWebhook("EggFound", newEggs[1])
        return newEggs[1].Object
    end
    
    if #allEggs > 0 and #x25Eggs == 0 and serverSearchTime > 20 then
        sendWebhook("NoEggsFound")
    end
    
    return nil
end

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
    
    if #visitedServers > 100 then
        visitedServers = {}  -- Reset the visited servers list if we've checked too many
    end

    return nil
end

local function teleportToEgg(egg)
    if not egg then return end
    
    local eggPart
    if egg:IsA("BasePart") or egg:IsA("MeshPart") then
        eggPart = egg
    elseif egg:IsA("Model") and egg.PrimaryPart then
        eggPart = egg.PrimaryPart
    else
        -- Try to find any BasePart in the egg
        for _, child in pairs(egg:GetDescendants()) do
            if child:IsA("BasePart") or child:IsA("MeshPart") then
                eggPart = child
                break
            end
        end
    end
    
    if not eggPart then return end
    
    -- Check if the player's character exists
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    -- Teleport to the egg
    local humanoidRootPart = LocalPlayer.Character.HumanoidRootPart
    local targetPosition = eggPart.Position + Vector3.new(0, 5, 0) -- Position slightly above the egg
    humanoidRootPart.CFrame = CFrame.new(targetPosition)
    
    -- Try to find and click any proximity prompt
    wait(0.5)
    local proximityPrompt = egg:FindFirstChildWhichIsA("ProximityPrompt")
    if proximityPrompt then
        proximityPrompt:InputHoldBegin()
        wait(proximityPrompt.HoldDuration + 0.1)
        proximityPrompt:InputHoldEnd()
    end
end

local function collectEgg(egg)
    if not egg then return end
    
    teleportToEgg(egg)
    
    -- Also check if there are any nearby GUI elements that could be related to collecting the egg
    if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
        local eggPosition = nil
        
        pcall(function()
            if egg:IsA("BasePart") or egg:IsA("MeshPart") then
                eggPosition = egg.Position
            elseif egg:IsA("Model") and egg.PrimaryPart then
                eggPosition = egg.PrimaryPart.Position
            end
        end)
        
        if eggPosition and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            -- Find all buttons within a reasonable distance
            local buttons = {}
            for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
                if (gui:IsA("TextButton") or gui:IsA("ImageButton")) and gui.Visible then
                    local textLower = ""
                    if gui:IsA("TextButton") and gui.Text then
                        textLower = string.lower(gui.Text)
                    end
                    
                    -- Look for buttons that might be for collecting eggs
                    if string.find(textLower, "collect") or 
                       string.find(textLower, "grab") or
                       string.find(textLower, "pick") or
                       string.find(textLower, "egg") or
                       string.find(textLower, "claim") then
                        table.insert(buttons, gui)
                    end
                end
            end
            
            -- Click all potential collection buttons
            for _, button in ipairs(buttons) do
                clickButton(button)
                wait(0.2)
            end
        end
    end
end

-- Main loop
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
