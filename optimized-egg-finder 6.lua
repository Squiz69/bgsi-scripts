local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Discord webhook for notifications
local DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1363054781882699910/Qwa5roGAv5rj83wBwCG7BzraXD8xOc7L-eeopKGdvCSug1GhdJzx6sRRNA1tjgmbRW34"

local PLACE_ID = 85896571713843
local visitedServers = {}

-- All possible hatchable eggs to check - add or remove as needed
local hatchable_eggs = {
    "event-1", 
    "event-2",
    "rainbow-egg",
    "void-egg",
    "nightmare-egg", 
    "aura-egg"
}

local egg_priority = "event-1" -- Priority egg to look for
local egg_amount = 3 -- How many eggs to open when found
local open_eggs = true -- Set to false if you only want to find eggs without opening

local lastTeleport = 0
local teleportCooldown = 5
local notifiedEggs = {}
local serverSearchTime = 0
local maxServerSearchTime = 60 -- Search a server for maximum 60 seconds before hopping

-- Enhanced UI interaction - finds and clicks buttons more reliably
local function clickButton(buttonTextPattern, maxWaitTime)
    maxWaitTime = maxWaitTime or 5
    local startTime = tick()
    
    while tick() - startTime < maxWaitTime do
        local buttons = {}
        
        -- Check PlayerGui
        if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
            for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
                if (gui:IsA("TextButton") or gui:IsA("ImageButton")) and 
                   (not buttonTextPattern or 
                    (gui:IsA("TextButton") and string.find(string.lower(gui.Text), buttonTextPattern))) then
                    table.insert(buttons, gui)
                end
            end
        end
        
        -- Check CoreGui
        local success, result = pcall(function()
            for _, gui in pairs(game:GetService("CoreGui"):GetDescendants()) do
                if (gui:IsA("TextButton") or gui:IsA("ImageButton")) and 
                   (not buttonTextPattern or 
                    (gui:IsA("TextButton") and string.find(string.lower(gui.Text), buttonTextPattern))) then
                    table.insert(buttons, gui)
                end
            end
        end)
        
        -- Try clicking all found buttons
        for _, button in ipairs(buttons) do
            pcall(function()
                -- Simulate mouse events
                if button.Visible and button.Active then
                    -- Try multiple methods of clicking
                    button.MouseButton1Click:Fire()
                    
                    -- Try other events
                    for _, event in pairs({"Activated", "MouseButton1Down", "MouseButton1Up"}) do
                        if button[event] then
                            button[event]:Fire()
                        end
                    end
                    
                    -- Try firing with native function if available
                    pcall(function() firesignal(button.MouseButton1Click) end)
                    pcall(function() firesignal(button.Activated) end)
                    
                    print("Clicked button:", button:GetFullName())
                end
            end)
        end
        
        -- If we're looking for a specific button and found it, return true
        if buttonTextPattern and #buttons > 0 then
            return true
        end
        
        wait(0.5)
    end
    
    return false
end

-- Handle the initial startup - press play button when found
local function pressPlayButtonAndLoadGame()
    print("Looking for play button...")
    wait(2) -- Wait for UI to load
    
    -- Common play button texts in Roblox games
    local playTexts = {"play", "start", "enter", "continue", "join"}
    
    -- Try to click any play button
    for _, text in ipairs(playTexts) do
        if clickButton(text, 2) then
            print("Clicked " .. text .. " button")
            wait(1)
            -- Try again with a different text in case there are multiple screens
            for _, text2 in ipairs(playTexts) do
                if text2 ~= text then
                    clickButton(text2, 1)
                end
            end
            break
        end
    end
    
    -- Also try clicking buttons without text matching (image buttons)
    clickButton(nil, 2)
    
    print("Start sequence complete, waiting for game to load")
    wait(3)
end

-- Enhanced function to send Discord webhook notification
local function sendDiscordNotification(eggInfo, eggLuck)
    local jobId = game.JobId
    local serverId = game.PlaceId
    local serverStats = game:GetService("Players"):GetPlayers()
    local currentPlayers = #serverStats
    local maxPlayers = game:GetService("Players").MaxPlayers
    
    -- Get player name with censoring for privacy
    local playerName = LocalPlayer.Name
    local censoredName = string.sub(playerName, 1, 1) .. "***" .. string.sub(playerName, -1)
    
    -- Get current height (if applicable)
    local height = "Unknown"
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        height = math.floor(LocalPlayer.Character.HumanoidRootPart.Position.Y) .. "m"
    end
    
    -- Determine egg type based on name
    local eggType = "Unknown Egg"
    if eggInfo and eggInfo.Name then
        for _, eggName in pairs(hatchable_eggs) do
            if string.find(string.lower(eggInfo.Name), string.lower(eggName)) then
                eggType = eggName
                break
            end
        end
        
        if eggType == "Unknown Egg" then
            eggType = eggInfo.Name -- Use the original name if not matched
        end
    end
    
    -- Create teleport script for users to join
    local teleportScript = 'game:GetService("TeleportService"):TeleportToPlaceInstance(' .. 
                           tostring(PLACE_ID) .. ', "' .. jobId .. '", game.Players.LocalPlayer)'
    
    -- Calculate estimated time remaining
    local timeRemaining = "~4 minutes"
    if serverSearchTime > 0 then
        local remainingSeconds = math.max(0, 300 - (tick() - serverSearchTime))
        local minutes = math.floor(remainingSeconds / 60)
        local seconds = math.floor(remainingSeconds % 60)
        timeRemaining = minutes .. "m " .. seconds .. "s"
    end
    
    -- Create webhook message
    local webhookData = {
        embeds = {
            {
                title = "25X Luck Egg Found 🎉",
                description = "A rare egg with 25X Luck has been discovered!",
                color = 16776960, -- Yellow color
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
    
    -- Send the webhook
    pcall(function()
        HttpService:PostAsync(
            DISCORD_WEBHOOK_URL,
            HttpService:JSONEncode(webhookData),
            Enum.HttpContentType.ApplicationJson,
            false
        )
        print("Discord notification sent successfully!")
    end)
end

-- Optimized function to find 25x lucky eggs
local function find25xLuckyEgg()
    print("Searching for 25x lucky eggs...")
    local foundEggs = {}
    
    -- Function to check if an object has 25x luck
    local function checkForLuckValue(obj)
        -- Skip non-objects
        if typeof(obj) ~= "Instance" then return nil end
        
        -- Check name for 25x indicators
        local name = string.lower(obj.Name)
        if string.find(name, "25x") or 
           string.find(name, "25 luck") or 
           string.find(name, "25 x") or 
           string.find(name, "25%") then
            return 25
        end
        
        -- Check attributes for luck values
        for _, attrName in ipairs({"Luck", "LuckMultiplier", "Multiplier", "Bonus", "Rarity"}) do
            local value = obj:GetAttribute(attrName)
            if value == 25 or value == "25x" or value == "25" then
                return 25
            end
        end
        
        -- Check child values
        for _, valueName in ipairs({"LuckValue", "MultiplierValue", "Stats", "Luck", "Multiplier"}) do
            local valueObj = obj:FindFirstChild(valueName)
            if valueObj and (valueObj:IsA("NumberValue") or valueObj:IsA("StringValue")) then
                local value = valueObj.Value
                if value == 25 or value == "25" or value == "25x" then
                    return 25
                end
            end
        end
        
        -- Check TextLabels
        for _, child in pairs(obj:GetDescendants()) do
            if child:IsA("TextLabel") then
                local text = string.lower(child.Text)
                if string.find(text, "25x") or 
                   string.find(text, "25 x") or 
                   string.find(text, "25%%") or
                   string.find(text, "25 luck") then
                    return 25
                end
            end
        end
        
        -- Check BillboardGuis
        local billboard = obj:FindFirstChildWhichIsA("BillboardGui")
        if billboard then
            for _, label in pairs(billboard:GetDescendants()) do
                if label:IsA("TextLabel") then
                    local text = string.lower(label.Text)
                    if string.find(text, "25x") or
                       string.find(text, "25 luck") then
                        return 25
                    end
                end
            end
        end
        
        return nil
    end
    
    -- Priority containers to check
    local containersToCheck = {
        workspace,
        workspace:FindFirstChild("Eggs"),
        workspace:FindFirstChild("LuckyEggs"),
        workspace:FindFirstChild("EventEggs"),
        workspace:FindFirstChild("World"),
        workspace:FindFirstChild("Drops"),
        workspace:FindFirstChild("GameObjects"),
        workspace:FindFirstChild("SpawnedEggs")
    }
    
    -- Add potential containers based on naming patterns
    for _, child in pairs(workspace:GetChildren()) do
        if string.find(string.lower(child.Name), "egg") or
           string.find(string.lower(child.Name), "luck") or
           string.find(string.lower(child.Name), "event") or
           string.find(string.lower(child.Name), "drop") then
            table.insert(containersToCheck, child)
        end
    end
    
    -- Helper function to determine if an object is a target egg
    local function isTargetEgg(obj)
        local name = string.lower(obj.Name)
        for _, eggName in pairs(hatchable_eggs) do
            if string.find(name, string.lower(eggName)) then
                return true, string.lower(eggName) == string.lower(egg_priority)
            end
        end
        return false, false
    end
    
    -- Check each container for eggs
    for _, container in pairs(containersToCheck) do
        if container then
            -- Look for models, parts, and mesh parts that could be eggs
            for _, obj in pairs(container:GetDescendants()) do
                if obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("MeshPart") then
                    local isEgg, isPriority = isTargetEgg(obj)
                    
                    -- If it looks like an egg, check if it has 25x luck
                    if isEgg then
                        local luckValue = checkForLuckValue(obj)
                        
                        if luckValue == 25 then
                            print("Found 25x egg: " .. obj.Name)
                            table.insert(foundEggs, {
                                Egg = obj,
                                IsPriority = isPriority,
                                LuckValue = luckValue
                            })
                            
                            -- Return priority eggs immediately
                            if isPriority then
                                return obj, luckValue
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Also check GUI elements for egg indicators
    if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
        for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if gui:IsA("TextLabel") and (
               string.find(gui.Text, "25x") or
               string.find(gui.Text, "25 x Luck") or
               string.find(gui.Text, "25% Luck")) then
                
                -- Try to find a parent that might be related to the egg
                local currentObj = gui
                for i = 1, 5 do -- Go up to 5 levels up
                    if currentObj and currentObj.Parent then
                        currentObj = currentObj.Parent
                        
                        local name = string.lower(currentObj.Name)
                        local isTargetEgg = false
                        local isPriority = false
                        
                        for _, eggName in pairs(hatchable_eggs) do
                            if string.find(name, string.lower(eggName)) then
                                isTargetEgg = true
                                isPriority = (string.lower(eggName) == string.lower(egg_priority))
                                break
                            end
                        end
                        
                        if isTargetEgg or string.find(name, "egg") then
                            print("Found 25x egg via GUI: " .. currentObj.Name)
                            table.insert(foundEggs, {
                                Egg = currentObj,
                                IsPriority = isPriority,
                                LuckValue = 25
                            })
                            
                            if isPriority then
                                return currentObj, 25
                            end
                            
                            break
                        end
                    end
                end
            end
        end
    end
    
    -- Return the first priority egg if found
    for _, eggData in ipairs(foundEggs) do
        if eggData.IsPriority then
            return eggData.Egg, eggData.LuckValue
        end
    end
    
    -- Or return the first egg if any found
    if #foundEggs > 0 then
        return foundEggs[1].Egg, foundEggs[1].LuckValue
    end
    
    return nil
end

-- Teleport to the egg location
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
    
    print("Teleporting to 25x egg at " .. tostring(eggPart.Position))
    humanoidRootPart.CFrame = CFrame.new(eggPart.Position + Vector3.new(0, 5, 0))
    
    wait(1)
end

-- Improved function to open eggs
local function openEgg(egg, amount)
    if not open_eggs or not egg then return end
    
    amount = amount or egg_amount
    print("Attempting to open egg " .. egg.Name .. " x" .. amount)
    
    -- Method 1: Try proximity prompt if available
    local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt")
    if prompt then
        print("Found proximity prompt, triggering it")
        for i = 1, amount do
            -- Try different prompt firing methods
            pcall(function() fireproximityprompt(prompt) end)
            pcall(function() prompt:InputHoldBegin() wait(prompt.HoldDuration + 0.1) prompt:InputHoldEnd() end)
            wait(0.5)
        end
        return
    end
    
    -- Method 2: Look for common egg opening remotes
    local remoteNames = {
        "OpenEgg", "HatchEgg", "PurchaseEgg", "BuyEgg", 
        "Hatch", "Open", "EggOpen", "HatchEvent"
    }
    
    local remoteFolders = {
        ReplicatedStorage:FindFirstChild("RemoteEvents"),
        ReplicatedStorage:FindFirstChild("Remotes"),
        ReplicatedStorage:FindFirstChild("Events"),
        ReplicatedStorage
    }
    
    -- Try to find the egg opening remote
    local eggRemote
    for _, folder in pairs(remoteFolders) do
        if folder then
            -- Check direct children first
            for _, name in pairs(remoteNames) do
                local remote = folder:FindFirstChild(name)
                if remote and (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
                    eggRemote = remote
                    break
                end
            end
            
            -- If not found, search deeper with pattern matching
            if not eggRemote then
                for _, obj in pairs(folder:GetDescendants()) do
                    if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) and
                       (string.find(string.lower(obj.Name), "egg") or
                        string.find(string.lower(obj.Name), "hatch") or
                        string.find(string.lower(obj.Name), "open")) then
                        eggRemote = obj
                        break
                    end
                end
            end
            
            if eggRemote then break end
        end
    end
    
    -- If remote found, try different argument patterns
    if eggRemote then
        print("Found egg opening remote: " .. eggRemote:GetFullName())
        
        -- Most common remote argument patterns
        local patterns = {
            function() eggRemote:FireServer(egg.Name, amount) end,
            function() eggRemote:FireServer(egg) end,
            function() eggRemote:FireServer() end,
            function() eggRemote:FireServer(egg.Name) end,
            function() eggRemote:FireServer("Open", egg.Name) end,
            function() eggRemote:FireServer(egg.Name, 1) end,
            function() eggRemote:FireServer({EggName = egg.Name, Amount = amount}) end,
            function() eggRemote:FireServer({Type = egg.Name, Amount = amount}) end
        }
        
        for i, pattern in ipairs(patterns) do
            pcall(pattern)
            wait(0.5)
        end
    else
        print("Could not find egg opening remote")
    end
end

-- Get a random server that we haven't visited
local function getRandomServer()
    local servers = {}
    local success, result
    
    -- Attempt to get server list
    pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=100"
        success, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(url))
        end)
    end)

    if success and result and result.data then
        for _, server in ipairs(result.data) do
            if server.playing < server.maxPlayers and not visitedServers[server.id] then
                table.insert(servers, server)
            end
        end
    end

    if #servers > 0 then
        -- Choose a server with fewer players for better chances
        table.sort(servers, function(a, b)
            return a.playing < b.playing
        end)
        
        -- Return a server from the top 25% least populated
        local index = math.random(1, math.max(1, math.floor(#servers / 4)))
        return servers[index]
    end

    -- If no eligible servers found, clear visited list and try again
    print("No eligible servers found, clearing visited list")
    visitedServers = {}
    return nil
end

-- Improved server hopping with better error handling
local function hopToNextServer()
    if tick() - lastTeleport < teleportCooldown then return false end
    
    print("Hopping to a new server")
    local nextServer = getRandomServer()
    
    if nextServer then
        lastTeleport = tick()
        visitedServers[nextServer.id] = true
        
        -- Try to teleport to the new server
        local teleportSuccess = false
        pcall(function()
            TeleportService:TeleportToPlaceInstance(PLACE_ID, nextServer.id, LocalPlayer)
            teleportSuccess = true
        end)
        
        -- If teleport fails, try a different method
        if not teleportSuccess then
            pcall(function()
                TeleportService:Teleport(PLACE_ID, LocalPlayer, nil, nextServer.id)
            end)
        end
        
        return true
    else
        -- If no servers found, wait a bit and try again
        print("No suitable servers found, waiting to retry...")
        wait(5)
        return false
    end
end

-- Add visual indicator for users
local function createStatusUI()
    pcall(function()
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "EggFinderGui"
        
        -- Handle different platforms
        if game:GetService("RunService"):IsStudio() then
            screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        else
            screenGui.Parent = game:GetService("CoreGui")
        end
        
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 220, 0, 50)
        frame.Position = UDim2.new(0.5, -110, 0.9, -25)
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
        
        -- Update status function
        game:GetService("RunService").Heartbeat:Connect(function()
            pcall(function()
                -- Update the status text every second with server time
                if tick() % 1 < 0.1 then
                    local timeSpent = tick() - serverSearchTime
                    local minutes = math.floor(timeSpent / 60)
                    local seconds = math.floor(timeSpent % 60)
                    
                    text.Text = "25x Egg Finder - " .. egg_priority .. " - " .. 
                                minutes .. "m " .. seconds .. "s"
                end
            end)
        end)
    end)
end

-- Main script loop
local function mainLoop()
    -- Handle initial play button and game loading
    pressPlayButtonAndLoadGame()
    
    -- Create UI
    createStatusUI()
    
    -- Reset server search time for this server
    serverSearchTime = tick()
    
    -- Start the egg finding loop
    while wait(1) do
        local foundEgg, luckValue = find25xLuckyEgg()
        
        if foundEgg then
            print("Found a 25x lucky egg: " .. foundEgg.Name)
            
            -- Check if we've already notified about this egg
            local eggId = foundEgg.Name .. "_" .. tostring(foundEgg:GetFullName())
            if not notifiedEggs[eggId] then
                notifiedEggs[eggId] = tick()
                
                -- Send notification about the egg
                sendDiscordNotification(foundEgg, luckValue)
                
                -- Teleport to and open the egg
                teleportToEgg(foundEgg)
                openEgg(foundEgg, egg_amount)
                
                -- Reset search time since we found something
                serverSearchTime = tick()
                
                -- Wait before continuing search
                wait(3)
            end
        else
            -- Check if we've been searching too long with no results
            if tick() - serverSearchTime > maxServerSearchTime then
                print("No 25x eggs found in " .. math.floor(tick() - serverSearchTime) .. " seconds. Hopping to next server.")
                if hopToNextServer() then
                    -- Wait after teleport attempt
                    wait(10) 
                    
                    -- Reset search time for new server
                    serverSearchTime = tick()
                end
            end
        end
    end
end

print("Starting Optimized 25x Luck Egg Finder v2.0")

-- Start the main loop
spawn(function()
    pcall(mainLoop)
end)

-- Setup auto retry if script errors
spawn(function()
    while wait(30) do
        if tick() - serverSearchTime > 120 then
            print("Script may have stalled. Attempting recovery...")
            pcall(mainLoop)
        end
    end
end)
