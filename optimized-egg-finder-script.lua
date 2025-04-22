local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
local serverHopTime = 60 -- Search a server for maximum 60 seconds before hopping
local serverStartTime = 0

-- Enhanced UI interaction - finds and clicks buttons manually
local function clickButton(buttonTextPattern, maxWaitTime)
    maxWaitTime = maxWaitTime or 5
    local startTime = tick()
    
    while tick() - startTime < maxWaitTime do
        -- Check PlayerGui
        if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
            for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
                if (gui:IsA("TextButton") or gui:IsA("ImageButton")) and 
                   (not buttonTextPattern or 
                    (gui:IsA("TextButton") and string.lower(gui.Text):find(buttonTextPattern))) then
                    
                    pcall(function()
                        if gui.Visible and gui.Active then
                            -- Try clicking through multiple methods
                            print("Clicking button:", gui:GetFullName())
                            gui.MouseButton1Click:Fire()
                            
                            -- Try fireclick if available in this environment
                            pcall(function() firesignal(gui.MouseButton1Click) end)
                            pcall(function() gui.Activated:Fire() end)
                            
                            -- Try to visually click the button (more reliable)
                            local position = gui.AbsolutePosition + gui.AbsoluteSize/2
                            game:GetService("VirtualUser"):ClickButton1(Vector2.new(position.X, position.Y))
                            
                            return true
                        end
                    end)
                end
            end
        end
        
        wait(0.5)
    end
    
    return false
end

-- Handle the initial startup - press play button manually
local function pressPlayButtonManually()
    print("Looking for play button...")
    wait(3) -- Wait for UI to load
    
    -- Common play button texts in Roblox games
    local playTexts = {"play", "start", "enter", "continue", "join"}
    
    -- Try to click any play button
    for _, text in ipairs(playTexts) do
        if clickButton(text, 3) then
            print("Clicked " .. text .. " button")
            wait(2)
            
            -- Check for any secondary confirmation
            for _, text2 in ipairs(playTexts) do
                clickButton(text2, 1)
            end
            
            break
        end
    end
    
    -- Also try clicking any buttons (in case they're image buttons)
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        for _, gui in pairs(playerGui:GetDescendants()) do
            if (gui:IsA("TextButton") or gui:IsA("ImageButton")) and gui.Visible then
                pcall(function()
                    local position = gui.AbsolutePosition + gui.AbsoluteSize/2
                    game:GetService("VirtualUser"):ClickButton1(Vector2.new(position.X, position.Y))
                end)
                wait(0.2)
            end
        end
    end
    
    print("Start sequence complete")
    wait(5) -- Give time for game to load
end

-- Enhanced function to send Discord webhook notification
local function sendDiscordNotification(riftInfo, luckValue)
    local jobId = game.JobId
    local serverId = game.PlaceId
    local currentPlayers = #Players:GetPlayers()
    local maxPlayers = Players.MaxPlayers
    
    -- Get player name with censoring for privacy
    local playerName = LocalPlayer.Name
    local censoredName = string.sub(playerName, 1, 1) .. "***" .. string.sub(playerName, -1)
    
    -- Get current height (if applicable)
    local height = "Unknown"
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        height = math.floor(LocalPlayer.Character.HumanoidRootPart.Position.Y) .. "m"
    end
    
    -- Create teleport script for users to join
    local teleportScript = 'game:GetService("TeleportService"):TeleportToPlaceInstance(' .. 
                           tostring(PLACE_ID) .. ', "' .. jobId .. '", game.Players.LocalPlayer)'
    
    -- Calculate estimated time remaining
    local timeRemaining = math.max(0, serverHopTime - (tick() - serverStartTime))
    local minutes = math.floor(timeRemaining / 60)
    local seconds = math.floor(timeRemaining % 60)
    
    -- Create webhook message
    local webhookData = {
        embeds = {
            {
                title = "25X Luck Rift Found 🎉",
                description = "A rare rift with 25X Luck has been discovered!",
                color = 16776960, -- Yellow color
                fields = {
                    {name = "Rift Type", value = riftInfo.Name, inline = true},
                    {name = "Luck Multiplier", value = "x" .. tostring(luckValue), inline = true},
                    {name = "Height", value = height, inline = true},
                    {name = "Server Slots", value = currentPlayers .. "/" .. maxPlayers, inline = true},
                    {name = "Server Hop In", value = minutes .. "m " .. seconds .. "s", inline = true},
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

-- Function to find 25x lucky rifts and eggs on rifts
local function find25xLuckyRift()
    print("Searching for 25x lucky rifts...")
    local foundRifts = {}
    
    -- Function to check if an object has 25x luck
    local function checkForLuckValue(obj)
        -- Skip non-objects
        if typeof(obj) ~= "Instance" then return nil end
        
        -- Check name for 25x indicators
        local name = string.lower(obj.Name)
        if string.find(name, "25x") or 
           string.find(name, "25 luck") or 
           string.find(name, "25%") then
            return 25
        end
        
        -- Check attributes for luck values
        for _, attrName in ipairs({"Luck", "LuckMultiplier", "Multiplier", "Bonus"}) do
            local value = obj:GetAttribute(attrName)
            if value == 25 or value == "25x" or value == "25" then
                return 25
            end
        end
        
        -- Check child values
        for _, valueName in ipairs({"LuckValue", "MultiplierValue", "Stats", "Luck"}) do
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
                   string.find(text, "25 luck") or 
                   string.find(text, "25%%") then
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
    
    -- First check for rifts specifically
    local riftContainers = {
        workspace:FindFirstChild("Rifts"),
        workspace:FindFirstChild("PortalRifts"),
        workspace:FindFirstChild("WorldRifts"),
        workspace:FindFirstChild("EventRifts"),
        workspace
    }
    
    -- Add more potential rift containers
    for _, child in pairs(workspace:GetChildren()) do
        if string.find(string.lower(child.Name), "rift") or
           string.find(string.lower(child.Name), "portal") then
            table.insert(riftContainers, child)
        end
    end
    
    -- Check each container for rifts with 25x luck
    for _, container in pairs(riftContainers) do
        if container then
            for _, obj in pairs(container:GetDescendants()) do
                if (obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("MeshPart")) and
                   (string.find(string.lower(obj.Name), "rift") or 
                    string.find(string.lower(obj.Name), "portal")) then
                    
                    local luckValue = checkForLuckValue(obj)
                    if luckValue == 25 then
                        print("Found 25x rift: " .. obj.Name)
                        table.insert(foundRifts, {
                            Rift = obj,
                            LuckValue = luckValue
                        })
                    end
                end
            end
        end
    end
    
    -- Now check for eggs spawned on rifts
    local eggContainers = {
        workspace:FindFirstChild("Eggs"),
        workspace:FindFirstChild("LuckyEggs"),
        workspace:FindFirstChild("EventEggs"),
        workspace:FindFirstChild("Drops")
    }
    
    -- Function to determine if an egg is on a rift
    local function isEggOnRift(egg)
        local eggPart
        if egg:IsA("BasePart") or egg:IsA("MeshPart") then
            eggPart = egg
        else
            eggPart = egg:FindFirstChildWhichIsA("BasePart") or egg:FindFirstChildWhichIsA("MeshPart")
        end
        
        if not eggPart then return false end
        
        -- Look for rift parts nearby
        local nearbyParts = workspace:GetPartBoundsInRadius(eggPart.Position, 20)
        for _, part in pairs(nearbyParts) do
            local parent = part.Parent
            if parent and (string.find(string.lower(parent.Name), "rift") or 
                          string.find(string.lower(part.Name), "rift") or
                          string.find(string.lower(parent.Name), "portal")) then
                return true
            end
        end
        
        return false
    end
    
    -- Check for eggs on rifts
    for _, container in pairs(eggContainers) do
        if container then
            for _, obj in pairs(container:GetDescendants()) do
                if (obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("MeshPart")) then
                    local isEgg = false
                    
                    -- Check if it's an egg
                    for _, eggName in pairs(hatchable_eggs) do
                        if string.find(string.lower(obj.Name), string.lower(eggName)) then
                            isEgg = true
                            break
                        end
                    end
                    
                    -- If it's an egg, check if it has 25x luck and is on a rift
                    if isEgg then
                        local luckValue = checkForLuckValue(obj)
                        if luckValue == 25 and isEggOnRift(obj) then
                            print("Found 25x egg on rift: " .. obj.Name)
                            table.insert(foundRifts, {
                                Rift = obj,
                                LuckValue = luckValue
                            })
                        end
                    end
                end
            end
        end
    end
    
    -- Return the first found rift/egg if any
    if #foundRifts > 0 then
        return foundRifts[1].Rift, foundRifts[1].LuckValue
    end
    
    return nil
end

-- Teleport to the rift location
local function teleportToRift(rift)
    if not rift then return end
    
    local riftPart
    if rift:IsA("BasePart") or rift:IsA("MeshPart") then
        riftPart = rift
    else
        riftPart = rift:FindFirstChildWhichIsA("BasePart") or rift:FindFirstChildWhichIsA("MeshPart")
    end
    
    if not riftPart then return end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    print("Teleporting to 25x rift at " .. tostring(riftPart.Position))
    humanoidRootPart.CFrame = CFrame.new(riftPart.Position + Vector3.new(0, 5, 0))
    
    wait(1)
end

-- Function to interact with eggs on rifts
local function interactWithEgg(egg, amount)
    if not open_eggs or not egg then return end
    
    amount = amount or egg_amount
    print("Attempting to open egg " .. egg.Name .. " x" .. amount)
    
    -- Method 1: Try proximity prompt if available
    local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt")
    if prompt then
        print("Found proximity prompt, triggering it")
        for i = 1, amount do
            pcall(function() fireproximityprompt(prompt) end)
            wait(0.5)
        end
        return
    end
    
    -- Method 2: Look for common egg opening remotes
    local remoteNames = {"OpenEgg", "HatchEgg", "PurchaseEgg", "BuyEgg", "Hatch", "Open"}
    
    for _, name in pairs(remoteNames) do
        local remote = ReplicatedStorage:FindFirstChild(name, true)
        if remote and (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
            print("Found egg remote: " .. remote:GetFullName())
            
            -- Try different argument patterns
            pcall(function() remote:FireServer(egg.Name, amount) end)
            pcall(function() remote:FireServer(egg) end)
            pcall(function() remote:FireServer() end)
            
            wait(0.5)
            return
        end
    end
end

-- Get a random server that we haven't visited
local function getRandomServer()
    local servers = {}
    
    -- Attempt to get server list
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
        -- Choose a server with fewer players for better chances
        table.sort(servers, function(a, b)
            return a.playing < b.playing
        end)
        
        -- Return a server from the top 25% least populated
        local index = math.random(1, math.max(1, math.floor(#servers / 4)))
        return servers[index]
    end

    -- If no eligible servers found, clear visited list
    print("No eligible servers found, clearing visited list")
    visitedServers = {}
    return nil
end

-- Server hopping with error handling
local function hopToNextServer()
    if tick() - lastTeleport < teleportCooldown then return false end
    
    print("Hopping to a new server")
    local nextServer = getRandomServer()
    
    if nextServer then
        lastTeleport = tick()
        visitedServers[nextServer.id] = true
        
        -- Try to teleport to the new server
        pcall(function()
            TeleportService:TeleportToPlaceInstance(PLACE_ID, nextServer.id, LocalPlayer)
        end)
        
        return true
    else
        wait(5)
        return false
    end
end

-- Add visual indicator with countdown timer
local function createStatusUI()
    pcall(function()
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "RiftFinderGui"
        
        -- Set the parent based on context
        pcall(function()
            screenGui.Parent = game:GetService("CoreGui")
        end)
        
        if not screenGui.Parent then
            screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
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
        text.Text = "25x Rift Finder - Server hop in: " .. serverHopTime .. "s"
        text.Parent = frame
        
        -- Update status with countdown timer
        RunService.Heartbeat:Connect(function()
            pcall(function()
                if tick() % 0.5 < 0.1 then
                    local timeLeft = math.max(0, serverHopTime - (tick() - serverStartTime))
                    local minutes = math.floor(timeLeft / 60)
                    local seconds = math.floor(timeLeft % 60)
                    
                    text.Text = "25x Rift Finder - Hop in: " .. 
                                minutes .. "m " .. seconds .. "s"
                end
            end)
        end)
    end)
end

-- Main script loop
local function mainLoop()
    -- Handle initial play button pressing
    pressPlayButtonManually()
    
    -- Create UI with countdown timer
    createStatusUI()
    
    -- Reset server search time for this server
    serverStartTime = tick()
    
    -- Start the rift finding loop
    while wait(1) do
        -- Check if it's time to hop servers
        if tick() - serverStartTime > serverHopTime then
            print("No 25x rifts found in " .. serverHopTime .. " seconds. Hopping to next server.")
            if hopToNextServer() then
                wait(10)
                serverStartTime = tick()
            end
        end
        
        -- Look for 25x lucky rifts
        local foundRift, luckValue = find25xLuckyRift()
        
        if foundRift then
            print("Found a 25x lucky rift: " .. foundRift.Name)
            
            -- Check if we've already notified about this rift
            local riftId = foundRift.Name .. "_" .. tostring(foundRift:GetFullName())
            if not notifiedEggs[riftId] then
                notifiedEggs[riftId] = tick()
                
                -- Send notification about the rift
                sendDiscordNotification(foundRift, luckValue)
                
                -- Teleport to and interact with any eggs on the rift
                teleportToRift(foundRift)
                interactWithEgg(foundRift, egg_amount)
                
                -- Reset server hop timer since we found something
                serverStartTime = tick()
                
                -- Wait before continuing search
                wait(3)
            end
        end
    end
end

print("Starting Optimized 25x Luck Rift Finder v1.0")

-- Start the main loop
spawn(function()
    pcall(mainLoop)
end)

-- Setup auto retry if script errors
spawn(function()
    while wait(30) do
        if tick() - serverStartTime > serverHopTime + 30 then
            print("Script may have stalled. Attempting recovery...")
            pcall(mainLoop)
        end
    end
end)
