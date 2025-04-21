local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

-- Discord webhook for notifications
local DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1363054781882699910/Qwa5roGAv5rj83wBwCG7BzraXD8xOc7L-eeopKGdvCSug1GhdJzx6sRRNA1tjgmbRW34"

local PLACE_ID = 85896571713843
local visitedServers = {}

local egg_amount = 3
local open_eggs = true
local lastTeleport = 0
local teleportCooldown = 5

-- Handle the initial startup - press play button when found
local function pressPlayButton()
    print("Looking for play button...")
    
    -- Wait for game UI to load
    wait(3)
    
    -- Check various potential play button locations
    local playButtons = {}
    
    -- Check for play button in starter GUI
    local starterGui = game:GetService("StarterGui")
    if starterGui then
        for _, gui in pairs(starterGui:GetDescendants()) do
            if gui:IsA("TextButton") and (string.lower(gui.Text) == "play" or string.lower(gui.Text) == "start") then
                table.insert(playButtons, gui)
            end
        end
    end
    
    -- Check for play button in PlayerGui
    if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
        for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if gui:IsA("TextButton") and (string.lower(gui.Text) == "play" or string.lower(gui.Text) == "start") then
                table.insert(playButtons, gui)
            end
        end
    end
    
    -- Check in core GUI elements
    local coreGui = game:GetService("CoreGui")
    if coreGui then
        for _, gui in pairs(coreGui:GetDescendants()) do
            if gui:IsA("TextButton") and (string.lower(gui.Text) == "play" or string.lower(gui.Text) == "start") then
                table.insert(playButtons, gui)
            end
        end
    end
    
    -- Find buttons by common GUI name patterns
    local commonGuiNames = {"PlayButton", "StartButton", "MenuUI", "StartMenu", "MainMenu"}
    for _, guiName in ipairs(commonGuiNames) do
        local guiObject = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild(guiName, true)
        if guiObject then
            for _, child in pairs(guiObject:GetDescendants()) do
                if child:IsA("TextButton") then
                    table.insert(playButtons, child)
                end
            end
        end
    end
    
    -- Try to press any play buttons found
    for _, button in ipairs(playButtons) do
        print("Attempting to click play button: " .. button:GetFullName())
        pcall(function()
            -- Simulate a click by firing the mouse events
            for _, event in ipairs({"MouseButton1Click", "Activated", "MouseButton1Down", "MouseButton1Up"}) do
                if button[event] then
                    button[event]:Fire()
                end
            end
        end)
        wait(1)
    end
    
    -- If on mobile, check for touch interface
    if GuiService:IsTenFootInterface() or game:GetService("UserInputService").TouchEnabled then
        print("Mobile device detected, checking for mobile UI elements...")
        -- Try to find mobile-specific buttons
        local mobileButtons = {}
        
        if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
            for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
                if gui:IsA("ImageButton") or gui:IsA("TextButton") then
                    if string.lower(gui.Name):find("mobile") or string.lower(gui.Name):find("touch") then
                        table.insert(mobileButtons, gui)
                    end
                end
            end
        end
        
        -- Try to press any mobile buttons found
        for _, button in ipairs(mobileButtons) do
            print("Attempting to click mobile button: " .. button:GetFullName())
            pcall(function()
                for _, event in ipairs({"TouchTap", "MouseButton1Click", "Activated"}) do
                    if button[event] then
                        button[event]:Fire()
                    end
                end
            end)
            wait(1)
        end
    end
    
    print("Play button check complete")
end

-- Function to specifically find 25x luck eggs
-- Function to send Discord webhook notification
local function sendDiscordNotification(eggInfo)
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
    
    -- Determine egg type based on name or appearance
    local eggType = "Unknown Egg"
    if eggInfo and eggInfo.Name then
        if string.find(string.lower(eggInfo.Name), "rainbow") then
            eggType = "Rainbow Egg"
        elseif string.find(string.lower(eggInfo.Name), "golden") then
            eggType = "Golden Egg"
        elseif string.find(string.lower(eggInfo.Name), "lucky") then
            eggType = "Lucky Egg"
        else
            eggType = eggInfo.Name .. " Egg"
        end
    end
    
    -- Create teleport script
    local teleportScript = 'game:GetService("TeleportService"):TeleportToPlaceInstance(' .. 
                           '"' .. PLACE_ID .. '", "' .. jobId .. '", game.Players.LocalPlayer)'
    
    -- Create webhook message
    local webhookData = {
        content = "",
        embeds = {
            {
                title = "Egg Found 🎉",
                description = "An egg with 25X Luck has been discovered!",
                color = 16776960, -- Yellow color
                fields = {
                    {name = "Egg Type", value = eggType, inline = true},
                    {name = "Luck", value = "x25", inline = true},
                    {name = "Height", value = height, inline = true},
                    {name = "Server Slots", value = currentPlayers .. "/" .. maxPlayers, inline = true},
                    {name = "Time Remaining", value = "4 minutes", inline = true},
                    {name = "Found By", value = censoredName, inline = true},
                    {name = "Job ID", value = jobId, inline = false},
                    {name = "Join Link", value = "Web Browser", inline = false},
                    {name = "Teleport Script", value = "```lua\n" .. teleportScript .. "\n```", inline = false}
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }
    }
    
    -- Convert to JSON
    local jsonData = HttpService:JSONEncode(webhookData)
    
    -- Send the webhook
    local success, response = pcall(function()
        return HttpService:PostAsync(
            DISCORD_WEBHOOK_URL,
            jsonData,
            Enum.HttpContentType.ApplicationJson,
            false
        )
    end)
    
    if success then
        print("Discord notification sent successfully!")
    else
        print("Failed to send Discord notification: " .. tostring(response))
    end
end

local function find25xLuckyEgg()
    print("Searching for 25x lucky eggs...")
    
    -- Method 1: Check common egg container folders
    local containerPaths = {
        workspace,
        workspace:FindFirstChild("Eggs"),
        workspace:FindFirstChild("LuckyEggs"),
        workspace:FindFirstChild("EventEggs"),
        workspace:FindFirstChild("Maps"),
        workspace:FindFirstChild("SpawnedEggs")
    }
    
    -- Common parent names that might contain eggs
    local parentNames = {"Eggs", "LuckyEggs", "RareEggs", "SpecialEggs", "WorldEggs"}
    for _, parent in pairs(workspace:GetChildren()) do
        if table.find(parentNames, parent.Name) then
            table.insert(containerPaths, parent)
        end
    end
    
    -- Add any obvious egg folders
    for _, obj in pairs(workspace:GetChildren()) do
        if string.find(string.lower(obj.Name), "egg") then
            table.insert(containerPaths, obj)
        end
    end
    
    -- Search all potential containers specifically for 25x eggs
    for _, container in pairs(containerPaths) do
        if container then
            for _, obj in pairs(container:GetDescendants()) do
                -- ONLY check for 25x eggs by name patterns
                local name = string.lower(obj.Name)
                if (obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("MeshPart")) and 
                   string.find(name, "25x") then
                    print("Found 25x luck egg: " .. obj.Name)
                    -- Send Discord notification
                    sendDiscordNotification(obj)
                    return obj
                end
                
                -- Check by attributes for 25x
                if obj:GetAttribute("Luck") == 25 or obj:GetAttribute("Multiplier") == 25 then
                    print("Found 25x egg by attribute: " .. obj.Name)
                    -- Send Discord notification
                    sendDiscordNotification(obj)
                    return obj
                end
                
                -- Check for UI elements that might indicate 25x
                local uiLabel = obj:FindFirstChild("LuckMultiplier") or obj:FindFirstChild("MultiplierLabel")
                if uiLabel and uiLabel:IsA("TextLabel") and string.find(uiLabel.Text, "25x") then
                    print("Found 25x egg by UI label: " .. obj.Name)
                    -- Send Discord notification
                    sendDiscordNotification(obj)
                    return obj
                end
            end
        end
    end
    
    -- Method 2: Check GUI elements for indicators of 25x eggs
    if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
        for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if gui:IsA("TextLabel") and string.find(gui.Text, "25x") and string.find(string.lower(gui.Text), "luck") then
                local model = gui
                -- Traverse up to find a potential model that might be the egg
                for i = 1, 5 do
                    if model and model.Parent and model.Parent:IsA("Model") then
                        print("Found potential 25x egg via GUI: " .. model.Parent.Name)
                        -- Send Discord notification
                        sendDiscordNotification(model.Parent)
                        return model.Parent
                    end
                    if model and model.Parent then
                        model = model.Parent
                    else
                        break
                    end
                end
            end
        end
    end
    
    print("No 25x eggs found in this server")
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

    return nil
end

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

local function openEgg(egg)
    if not open_eggs or not egg then return end
    
    -- Method 1: Try proximity prompt if available (most modern approach)
    local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt")
    if prompt then
        print("Found proximity prompt, trying to trigger it")
        fireproximityprompt(prompt)
        wait(1)
        return
    end
    
    -- Method 2: Common RemoteEvent patterns
    local potentialRemoteNames = {
        "OpenEgg", "HatchEgg", "OpenEggs", "PurchaseEgg", "BuyEgg", 
        "OpenLuckyEgg", "Hatch", "Open", "EggOpen"
    }
    
    -- Check in common remote folders
    local remoteFolders = {
        ReplicatedStorage:FindFirstChild("RemoteEvents"),
        ReplicatedStorage:FindFirstChild("Remotes"),
        ReplicatedStorage:FindFirstChild("Remote"),
        ReplicatedStorage:FindFirstChild("Events"),
        ReplicatedStorage
    }
    
    -- Try to find the remote
    local openEggRemote
    for _, folder in pairs(remoteFolders) do
        if folder then
            for _, remoteName in ipairs(potentialRemoteNames) do
                local remote = folder:FindFirstChild(remoteName)
                if remote and remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
                    openEggRemote = remote
                    break
                end
            end
            
            if openEggRemote then break end
            
            -- Deep search
            for _, obj in pairs(folder:GetDescendants()) do
                if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) and 
                   (string.find(string.lower(obj.Name), "egg") or 
                    string.find(string.lower(obj.Name), "hatch") or
                    string.find(string.lower(obj.Name), "open")) then
                    openEggRemote = obj
                    break
                end
            end
            
            if openEggRemote then break end
        end
    end
    
    -- Method 3: Use the remote we found
    if openEggRemote then
        print("Found egg opening remote: " .. openEggRemote.Name)
        
        -- Try different argument patterns based on common implementations
        local openEggPatterns = {
            function() openEggRemote:FireServer(egg.Name, "Single") end,
            function() openEggRemote:FireServer(egg.Name) end,
            function() openEggRemote:FireServer(egg) end,
            function() openEggRemote:FireServer() end,
            function() openEggRemote:FireServer(egg.Name, 1) end,
            function() openEggRemote:FireServer("Open", egg.Name) end
        }
        
        for i, openPattern in ipairs(openEggPatterns) do
            print("Trying egg open pattern #" .. i)
            pcall(openPattern)
            wait(1)
        end
    else
        print("Could not find egg opening remote")
    end
    
    -- Method 4: For mobile, try to simulate a touch/tap on the egg
    if game:GetService("UserInputService").TouchEnabled then
        print("Mobile device detected, trying to simulate touch on egg")
        pcall(function()
            local touch = {
                UserInputType = Enum.UserInputType.Touch,
                Position = egg.Position,
                Target = egg
            }
            game:GetService("UserInputService").TouchTap:Fire(touch)
        end)
        wait(1)
    end
end

local function hopToNextServer()
    if tick() - lastTeleport < teleportCooldown then return false end
    
    print("Hopping to a new server")
    local nextServer = getRandomServer()
    
    if nextServer then
        lastTeleport = tick()
        visitedServers[nextServer.id] = true
        
        -- Send server hop notification to Discord
        pcall(function()
            local hopInfo = {
                Name = "Server Hop"
            }
            
            -- Create webhook message for server hopping
            local webhookData = {
                content = "",
                embeds = {
                    {
                        title = "Server Hopping 🔄",
                        description = "Moving to a new server to find 25x eggs...",
                        color = 5814783, -- Blue color
                        fields = {
                            {name = "Current Server", value = game.JobId, inline = true},
                            {name = "Target Server", value = nextServer.id, inline = true},
                            {name = "Target Players", value = nextServer.playing .. "/" .. nextServer.maxPlayers, inline = true}
                        },
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                    }
                }
            }
            
            -- Convert to JSON
            local jsonData = HttpService:JSONEncode(webhookData)
            
            -- Send the webhook
            HttpService:PostAsync(
                DISCORD_WEBHOOK_URL,
                jsonData,
                Enum.HttpContentType.ApplicationJson,
                false
            )
        end)
        
        -- Teleport to the new server
        pcall(function()
            TeleportService:TeleportToPlaceInstance(PLACE_ID, nextServer.id, LocalPlayer)
        end)
        return true
    else
        visitedServers = {}
        return false
    end
end

-- Keep track of already notified eggs to prevent duplicate notifications
local notifiedEggs = {}

local function mainLoop()
    -- First check if we need to press play
    pressPlayButton()
    
    -- Wait a bit to ensure the game is fully loaded
    wait(5)
    
    -- Send initial webhook with server information
    pcall(function()
        local serverInfo = {
            Name = "Server Joined"
        }
        sendDiscordNotification(serverInfo)
    end)
    
    -- Now begin the egg finding loop
    while wait(1) do
        local foundEgg = find25xLuckyEgg()
        
        if foundEgg then
            print("Found a 25x lucky egg: " .. foundEgg.Name)
            
            -- Check if we've already notified about this egg to prevent spam
            local eggIdentifier = foundEgg.Name .. "_" .. tostring(foundEgg:GetFullName())
            if not notifiedEggs[eggIdentifier] then
                notifiedEggs[eggIdentifier] = tick() -- Store when we found it
                
                -- Only keep track of the last 50 eggs to prevent memory buildup
                if #notifiedEggs > 50 then
                    local oldestTime = math.huge
                    local oldestKey = nil
                    for key, time in pairs(notifiedEggs) do
                        if time < oldestTime then
                            oldestTime = time
                            oldestKey = key
                        end
                    end
                    if oldestKey then
                        notifiedEggs[oldestKey] = nil
                    end
                end
            end
            
            teleportToEgg(foundEgg)
            openEgg(foundEgg)
            wait(3)
        else
            hopToNextServer()
        end
    end
end

print("Starting Bubble Gum Simulator 25x Luck Egg Script")

-- Add script loading indicators for mobile users
if game:GetService("UserInputService").TouchEnabled then
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "25xEggBotGui"
    screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 50)
    frame.Position = UDim2.new(0.5, -100, 0.9, -25)
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 0.5
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, 0, 1, 0)
    text.BackgroundTransparency = 1
    text.TextColor3 = Color3.fromRGB(255, 255, 255)
    text.Text = "25x Egg Bot Active"
    text.Parent = frame
end

-- Start the main loop
spawn(function()
    pcall(mainLoop)
end)