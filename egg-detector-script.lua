local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1363054781882699910/Qwa5roGAv5rj83wBwCG7BzraXD8xOc7L-eeopKGdvCSug1GhdJzx6sRRNA1tjgmbRW34"
local PLACE_ID = 85896571713843
local visitedServers = {}

local open_eggs = true
local lastTeleport = 0
local teleportCooldown = 5
local notifiedEggs = {}
local serverSearchTime = 0

-- Improved button click simulation with more robust methods
local function clickButton(button)
    if not button then return false end
    
    -- Method 1: Virtual input simulation
    local function simulateMouseClick(obj)
        -- Get absolute position for accurate clicking
        local absolutePosition
        pcall(function()
            absolutePosition = obj.AbsolutePosition
        end)
        
        if absolutePosition then
            -- Create virtual mouse events
            local virtualMouse = {
                X = absolutePosition.X + (obj.AbsoluteSize.X/2),
                Y = absolutePosition.Y + (obj.AbsoluteSize.Y/2),
                Target = obj
            }
            
            -- Trigger mouse events in sequence
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
    
    -- Method 2: Direct event invocation
    local function fireButtonEvents(obj)
        for _, event in ipairs({"MouseButton1Click", "Activated", "MouseButton1Down", "MouseButton1Up"}) do
            pcall(function()
                if obj[event] then
                    obj[event]:Fire()
                end
            end)
        end
    end
    
    -- Method 3: TouchTap for mobile
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
    
    -- Try all methods
    simulateMouseClick(button)
    wait(0.1)
    fireButtonEvents(button)
    wait(0.1)
    simulateTouchTap(button)
    
    return true
end

-- Enhanced play button detection and clicking functionality
local function pressPlayButton()
    wait(2)
    
    local possibleButtonNames = {
        "PlayButton", "Play", "Start", "StartButton", "GoButton", "EnterGame", 
        "JoinGame", "Continue", "Enter", "Go", "Begin", "Launch"
    }
    
    local buttonsFound = {}
    
    -- Function to check if a GUI element could be a play button
    local function isLikelyPlayButton(obj)
        if not (obj:IsA("TextButton") or obj:IsA("ImageButton")) then
            return false
        end
        
        -- Check if visible
        if obj.Visible == false then
            return false
        end
        
        -- Check button name
        local objNameLower = string.lower(obj.Name)
        for _, btnName in ipairs(possibleButtonNames) do
            if string.find(objNameLower, string.lower(btnName)) then
                return true
            end
        end
        
        -- Check button text if it's a TextButton
        if obj:IsA("TextButton") and obj.Text then
            local textLower = string.lower(obj.Text)
            for _, btnName in ipairs(possibleButtonNames) do
                if string.find(textLower, string.lower(btnName)) then
                    return true
                end
            end
        end
        
        -- Check for common visual characteristics of play buttons
        if obj.BackgroundColor3 and (
           (obj.BackgroundColor3.R > 0.5 and obj.BackgroundColor3.G > 0.7 and obj.BackgroundColor3.B < 0.3) or -- Green
           (obj.BackgroundColor3.R > 0.7 and obj.BackgroundColor3.G > 0.5 and obj.BackgroundColor3.B < 0.3))   -- Yellow/Orange
        then
            return true
        end
        
        return false
    end
    
    -- Check player GUI
    if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
        for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if isLikelyPlayButton(gui) then
                table.insert(buttonsFound, gui)
            end
        end
    end
    
    -- Check CoreGui
    pcall(function()
        for _, gui in pairs(game:GetService("CoreGui"):GetDescendants()) do
            if isLikelyPlayButton(gui) then
                table.insert(buttonsFound, gui)
            end
        end
    end)
    
    -- Sort buttons by size (larger buttons are more likely the main play button)
    table.sort(buttonsFound, function(a, b)
        local aSize = pcall(function() return a.AbsoluteSize.X * a.AbsoluteSize.Y end) and a.AbsoluteSize.X * a.AbsoluteSize.Y or 0
        local bSize = pcall(function() return b.AbsoluteSize.X * b.AbsoluteSize.Y end) and b.AbsoluteSize.X * b.AbsoluteSize.Y or 0
        return aSize > bSize
    end)
    
    -- Click the buttons, prioritizing larger ones
    local clickedAny = false
    for _, button in ipairs(buttonsFound) do
        if clickButton(button) then
            clickedAny = true
            wait(1)
        end
    end
    
    -- If no specific buttons found, try clicking anything that looks interactive
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

-- Improved webhook function with better status reporting
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
                    color = 5814783, -- Blue
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
                    color = 3066993, -- Green
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
                    description = "Searched for 25x eggs but none were found in this server.",
                    color = 15548997, -- Red
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
    
    pcall(function()
        HttpService:PostAsync(
            DISCORD_WEBHOOK_URL,
            jsonData,
            Enum.HttpContentType.ApplicationJson,
            false
        )
    end)
end

-- Completely revamped egg detection function
local function scanFor25xEggs()
    -- Track all eggs with their properties
    local allEggs = {}
    local x25Eggs = {}
    
    -- Define all possible egg containers
    local containers = {workspace}
    
    -- Add common egg containers
    local commonContainers = {"Eggs", "LuckyEggs", "RareEggs", "EventEggs", "SpawnedEggs", 
                             "GameEggs", "World", "Maps", "Drops", "Collectibles"}
    
    for _, containerName in ipairs(commonContainers) do
        local container = workspace:FindFirstChild(containerName)
        if container then
            table.insert(containers, container)
            
            -- Also add children of these containers as they might be world folders
            for _, child in pairs(container:GetChildren()) do
                if child:IsA("Folder") or child:IsA("Model") then
                    table.insert(containers, child)
                end
            end
        end
    end
    
    -- Add any folder/model with "egg" in the name
    for _, obj in pairs(workspace:GetDescendants()) do
        if (obj:IsA("Folder") or obj:IsA("Model")) and 
           string.find(string.lower(obj.Name), "egg") then
            table.insert(containers, obj)
        end
    end
    
    -- Function to check if an object is likely an egg
    local function isLikelyEgg(obj)
        if not (obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("MeshPart")) then
            return false
        end
        
        local name = string.lower(obj.Name)
        
        -- Check name patterns
        if string.find(name, "egg") or 
           string.find(name, "lucky") or 
           string.find(name, "rare") or 
           string.find(name, "boost") then
            return true
        end
        
        -- Check for common egg attributes
        if obj:GetAttribute("IsEgg") or
           obj:GetAttribute("Luck") or
           obj:GetAttribute("Multiplier") or
           obj:GetAttribute("EggType") then
            return true
        end
        
        -- Check for proximity prompts that suggest it's interactable
        if obj:FindFirstChildWhichIsA("ProximityPrompt") then
            return true
        end
        
        return false
    end
    
    -- Function to extract luck value from an egg
    local function getEggLuckValue(egg)
        -- Check direct attributes first
        local luckValue = egg:GetAttribute("Luck") or 
                         egg:GetAttribute("Multiplier") or
                         egg:GetAttribute("LuckMultiplier") or
                         egg:GetAttribute("LuckBoost")
        
        if luckValue and type(luckValue) == "number" then
            return luckValue
        end
        
        -- Check for UI elements that might display luck value
        local luckLabel = egg:FindFirstChild("LuckMultiplier") or 
                         egg:FindFirstChild("MultiplierLabel") or
                         egg:FindFirstChild("LuckValue")
        
        if luckLabel and luckLabel:IsA("TextLabel") and luckLabel.Text then
            -- Try to extract a number from the text (e.g., "25x Luck" -> 25)
            local textValue = string.match(luckLabel.Text, "(%d+)x")
            if textValue then
                return tonumber(textValue)
            end
        end
        
        -- Check name for luck value
        local name = string.lower(egg.Name)
        local nameValue = string.match(name, "(%d+)x")
        if nameValue then
            return tonumber(nameValue)
        end
        
        -- Check for special names that indicate 25x
        if string.find(name, "25") and 
          (string.find(name, "luck") or string.find(name, "boost")) then
            return 25
        end
        
        return nil
    end
    
    -- First pass: collect all eggs and their properties
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
                
                -- If it's a 25x egg, add to special list
                if eggInfo.LuckValue == 25 then
                    table.insert(x25Eggs, eggInfo)
                end
            end
        end
    end
    
    -- Second pass: check GUI elements for egg indicators
    if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
        for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if gui:IsA("TextLabel") and gui.Visible and gui.Text then
                local text = string.lower(gui.Text)
                if string.find(text, "25x") and string.find(text, "luck") then
                    -- Try to find what egg this UI element might be referring to
                    local closestEgg = nil
                    local closestDistance = math.huge
                    
                    for _, eggInfo in ipairs(allEggs) do
                        if eggInfo.LuckValue ~= 25 then -- Only consider eggs without confirmed luck value
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
                                    closestDistance = distance
                                    closestEgg = eggInfo
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
    
    -- Only return eggs we haven't notified about yet
    local newEggs = {}
    for _, eggInfo in ipairs(x25Eggs) do
        if not notifiedEggs[eggInfo.Id] then
            notifiedEggs[eggInfo.Id] = tick()
            table.insert(newEggs, eggInfo)
        end
    end
    
    -- If we found any eggs, send notification and return the first one
    if #newEggs > 0 then
        sendWebhook("EggFound", newEggs[1])
        return newEggs[1].Object
    end
    
    -- If we scanned and found nothing, notify
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
    
    -- If we've checked all servers, reset and try again
    if #visitedServers > 100 then
        visitedServers = {}
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
    
    humanoidRootPart.CFrame = CFrame.new(eggPart.Position + Vector3.new(0, 5, 0))
    
    wait(1)
end

local function openEgg(egg)
    if not open_eggs or not egg then return end
    
    -- Method 1: Try proximity prompt first
    local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt")
    if prompt then
        pcall(function()
            fireproximityprompt(prompt)
        end)
        wait(0.5)
        return
    end
    
    -- Method 2: Try to find the remote event
    local remoteNames = {"OpenEgg", "HatchEgg", "OpenEggs", "PurchaseEgg", "BuyEgg", 
                        "Open", "Hatch", "CollectEgg", "ClaimEgg", "GetEgg"}
                        
    local remoteFolders = {
        ReplicatedStorage:FindFirstChild("RemoteEvents"),
        ReplicatedStorage:FindFirstChild("Remotes"),
        ReplicatedStorage:FindFirstChild("Events"),
        ReplicatedStorage
    }
    
    -- Find all potential egg-related remotes
    local potentialRemotes = {}
    
    for _, folder in pairs(remoteFolders) do
        if folder then
            -- Direct check by name
            for _, remoteName in ipairs(remoteNames) do
                local remote = folder:FindFirstChild(remoteName)
                if remote and (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
                    table.insert(potentialRemotes, remote)
                end
            end
            
            -- Deep search
            for _, obj in pairs(folder:GetDescendants()) do
                if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then
                    local name = string.lower(obj.Name)
                    if string.find(name, "egg") or 
                       string.find(name, "hatch") or
                       string.find(name, "open") or
                       string.find(name, "collect") or
                       string.find(name, "claim") or
                       string.find(name, "purchase") or
                       string.find(name, "buy") then
                        table.insert(potentialRemotes, obj)
                    end
                end
            end
        end
    end
    
    -- Try common argument patterns with all potential remotes
    local argPatterns = {
        {egg},
        {egg.Name},
        {egg.Name, "Single"},
        {egg.Name, 1},
        {"Open", egg.Name},
        {"Claim", egg.Name},
        {"Collect", egg.Name},
        {egg:GetFullName()},
        {}  -- Some remotes don't need arguments
    }
    
    for _, remote in ipairs(potentialRemotes) do
        for _, args in ipairs(argPatterns) do
            pcall(function()
                if remote:IsA("RemoteEvent") then
                    remote:FireServer(unpack(args))
                elseif remote:IsA("RemoteFunction") then
                    remote:InvokeServer(unpack(args))
                end
            end)
            wait(0.2)
        end
    end
    
    -- Method 3: Try to click the egg directly
    pcall(function()
        if egg:IsA("BasePart") or egg:IsA("MeshPart") then
            -- Virtual mouse click
            local clickPos = egg.Position
            
            -- Create a touch event for mobile
            if UserInputService.TouchEnabled then
                local touchEvent = {
                    UserInputType = Enum.UserInputType.Touch,
                    Position = Vector2.new(egg.Position.X, egg.Position.Y),
                    Target = egg
                }
                UserInputService.TouchTap:Fire(touchEvent)
            end
            
            -- Create mouse events
            local mouseEvent = {
                UserInputType = Enum.UserInputType.MouseButton1,
                Position = Vector2.new(egg.Position.X, egg.Position.Y),
                Target = egg
            }
            UserInputService.InputBegan:Fire(mouseEvent, false)
            wait(0.1)
            UserInputService.InputEnded:Fire(mouseEvent, false)
        end
    end)
    
    wait(0.5)
end

local function hopToNextServer()
    if tick() - lastTeleport < teleportCooldown then return false end
    
    local nextServer = getRandomServer()
    
    if nextServer then
        lastTeleport = tick()
        visitedServers[nextServer.id] = true
        
        sendWebhook("ServerHop", {
            targetId = nextServer.id,
            targetPlayers = nextServer.playing .. "/" .. nextServer.maxPlayers
        })
        
        pcall(function()
            TeleportService:TeleportToPlaceInstance(PLACE_ID, nextServer.id, LocalPlayer)
        end)
        return true
    else
        -- If no servers found, reset visited list and try again
        visitedServers = {}
        return false
    end
end

-- Clean up notified eggs cache to prevent memory bloat
local function cleanupNotifiedEggs()
    local now = tick()
    local count = 0
    
    for id, time in pairs(notifiedEggs) do
        count = count + 1
        
        -- Remove eggs older than 1 hour
        if now - time > 3600 then
            notifiedEggs[id] = nil
        end
    end
    
    -- If still too many entries, remove oldest
    if count > 100 then
        local oldest = math.huge
        local oldestId = nil
        
        for id, time in pairs(notifiedEggs) do
            if time < oldest then
                oldest = time
                oldestId = id
            end
        end
        
        if oldestId then
            notifiedEggs[oldestId] = nil
        end
    end
end

local function mainLoop()
    -- First run the play button press
    pressPlayButton()
    wait(5)
    
    -- Send initial server join webhook
    sendWebhook("ServerJoined")
    
    -- Start the server search timer
    serverSearchTime = 0
    local lastServerUpdate = tick()
    
    -- Create status UI for mobile
    local statusLabel
    if UserInputService.TouchEnabled then
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "25xEggBotGui"
        pcall(function()
            screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        end)
        
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 200, 0, 50)
        frame.Position = UDim2.new(0.5, -100, 0.9, -25)
        frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        frame.BackgroundTransparency = 0.5
        frame.BorderSizePixel = 0
        frame.Parent = screenGui
        
        statusLabel = Instance.new("TextLabel")
        statusLabel.Size = UDim2.new(1, 0, 1, 0)
        statusLabel.BackgroundTransparency = 1
        statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        statusLabel.Text = "25x Egg Bot: Searching..."
        statusLabel.Parent = frame
    end
    
    -- Main scanning loop
    while wait(1) do
        -- Update search time
        local now = tick()
        serverSearchTime = serverSearchTime + (now - lastServerUpdate)
        lastServerUpdate = now
        
        -- Update status if available
        if statusLabel then
            statusLabel.Text = "25x Egg Bot: Searching... " .. math.floor(serverSearchTime) .. "s"
        end
        
        -- Look for eggs
        local foundEgg = scanFor25xEggs()
        
        if foundEgg then
            -- Update status
            if statusLabel then
                statusLabel.Text = "25x Egg Bot: Egg Found!"
            end
            
            -- Go to the egg and try to open it
            teleportToEgg(foundEgg)
            openEgg(foundEgg)
            
            -- Wait a bit before continuing search
            wait(3)
            
            -- Reset search timer
            serverSearchTime = 0
        else
            -- If we've been in this server for too long with no eggs, hop
            if serverSearchTime > 60 then
                if statusLabel then
                    statusLabel.Text = "25x Egg Bot: Hopping Servers..."
                end
                
                hopToNextServer()
                serverSearchTime = 0
            end
        end
        
        -- Clean up old notified eggs occasionally
        if math.random(1, 60) == 1 then
            cleanupNotifiedEggs()
        end
    end
end

-- Start the script
spawn(function()
    pcall(mainLoop)
end)
