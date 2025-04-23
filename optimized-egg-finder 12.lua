local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Configuration
local DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1363054781882699910/Qwa5roGAv5rj83wBwCG7BzraXD8xOc7L-eeopKGdvCSug1GhdJzx6sRRNA1tjgmbRW34"
local PLACE_ID = 85896571713843
local preferredEgg = "event-1"  -- Priority egg to search for
local eggOpenCount = 3          -- How many eggs to open
local enableEggOpening = true   -- Whether to open eggs
local serverSearchDuration = 10 -- Server search time in seconds
local movementSpeed = 6.0       -- Movement speed for approaching eggs

-- Script variables
local serverHistory = {}
local lastServerHop = 0
local serverHopCooldown = 5
local processedEggs = {}
local searchTimer = 0
local activeMovement = nil
local isActivelySeeking = false
local lastEggDetection = 0
local eggInVicinity = false
local serverJoinTime = 0
local notificationCooldown = 30
local lastNotificationTime = 0

-- Target egg types in order of priority
local targetEggTypes = {
    "event-1", "event-2", "rainbow-egg", "void-egg", "nightmare-egg", "aura-egg"
}

-- Handle UI interaction for game entry
local function interactWithGameUI()
    print("Scanning for interface elements...")
    
    -- Allow GUI time to load
    wait(2)
    
    -- Track interaction success
    local interactionSuccessful = false
    
    -- First method: Direct interactive element detection
    for _, element in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
        if not interactionSuccessful and (element:IsA("TextButton") or element:IsA("ImageButton")) and element.Visible then
            local elementText = ""
            
            -- Extract text from button or children
            if element:IsA("TextButton") then
                elementText = element.Text:lower()
            elseif element:FindFirstChild("TextLabel") then
                elementText = element:FindFirstChild("TextLabel").Text:lower()
            end
            
            -- Check label children
            for _, child in pairs(element:GetDescendants()) do
                if child:IsA("TextLabel") and child.Visible then
                    elementText = elementText .. " " .. child.Text:lower()
                end
            end
            
            -- Check for interaction keywords
            for _, term in pairs({"play", "start", "enter", "join", "continue", "ok", "yes", "claim", "next"}) do
                if string.find(elementText, term) then
                    print("Found interactive element containing: " .. term)
                    
                    -- Try multiple interaction methods
                    local interactionAttempt = false
                    
                    -- Method 1: Direct event firing
                    pcall(function() 
                        element.MouseButton1Click:Fire() 
                        interactionAttempt = true
                    end)
                    
                    -- Method 2: Signal firing
                    if not interactionAttempt then
                        pcall(function() 
                            firesignal(element.MouseButton1Click) 
                            interactionAttempt = true
                        end)
                    end
                    
                    -- Method 3: Virtual user input
                    if not interactionAttempt then
                        pcall(function()
                            local VirtualUser = game:GetService("VirtualUser")
                            local elementCenter = element.AbsolutePosition + element.AbsoluteSize/2
                            VirtualUser:Button1Down(elementCenter, workspace.CurrentCamera.CFrame)
                            wait(0.1)
                            VirtualUser:Button1Up(elementCenter, workspace.CurrentCamera.CFrame)
                            interactionAttempt = true
                        end)
                    end
                    
                    -- Method 4: Connection invocation
                    if not interactionAttempt then
                        for _, connection in pairs(getconnections(element.MouseButton1Click)) do
                            pcall(function()
                                connection:Fire()
                                interactionAttempt = true
                            end)
                        end
                    end

                    if interactionAttempt then
                        interactionSuccessful = true
                        wait(0.5)
                        break
                    end
                end
            end
        end
    end
    
    -- Second method: General screen navigation
    if not interactionSuccessful then
        for _, interface in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if (interface:IsA("Frame") or interface:IsA("ImageLabel")) and interface.Visible and 
               (string.find(string.lower(interface.Name), "menu") or 
                string.find(string.lower(interface.Name), "ui") or 
                string.find(string.lower(interface.Name), "screen")) then
                
                -- Locate interactive elements
                for _, control in pairs(interface:GetDescendants()) do
                    if (control:IsA("TextButton") or control:IsA("ImageButton")) and control.Visible then
                        pcall(function() 
                            control.MouseButton1Click:Fire() 
                            interactionSuccessful = true
                        end)
                        wait(0.1)
                    end
                end
            end
        end
    end
    
    return interactionSuccessful
end

-- Enhanced egg detection with better Rift-specific logic
local function detectLuckyEgg()
    print("Scanning environment for high-value eggs...")
    
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return nil end
    
    local rootPart = character.HumanoidRootPart
    local potentialEggs = {}
    
    -- Collect nearby egg objects with refined detection radius
    for _, object in pairs(workspace:GetDescendants()) do
        if object:IsA("BasePart") and not object:IsDescendantOf(character) then
            local distance = (rootPart.Position - object.Position).Magnitude
            if distance <= 75 then  -- Increased radius for better detection
                local objectName = object.Name:lower()
                if string.find(objectName, "egg") or 
                   string.find(objectName, "rift") or 
                   string.find(objectName, preferredEgg:lower()) then
                    table.insert(potentialEggs, object)
                end
            end
        end
    end
    
    -- Rift-specific luck multiplier detection
    for _, egg in pairs(potentialEggs) do
        -- Check for visual indicators in GUI elements
        for _, gui in pairs(egg:GetDescendants()) do
            if gui:IsA("SurfaceGui") or gui:IsA("BillboardGui") or gui:IsA("TextLabel") then
                local displayText = ""
                if gui:IsA("TextLabel") then
                    displayText = gui.Text:lower()
                elseif gui:FindFirstChild("TextLabel") then
                    displayText = gui:FindFirstChild("TextLabel").Text:lower()
                end
                
                -- Look for multiplier indicators
                if (string.find(displayText, "25x") or 
                    string.find(displayText, "x25") or 
                    string.find(displayText, "25 luck") or 
                    string.find(displayText, "luck 25") or
                    string.find(displayText, "25")) and
                   (string.find(displayText, "luck") or string.find(displayText, "multiplier")) then
                    return egg, 25
                end
            end
        end
        
        -- Scan for rift-specific properties and attributes
        local luckAttributes = {
            "Luck", "LuckMultiplier", "Multiplier", "Boost", 
            "LuckValue", "RiftBoost", "EggValue"  -- Added Rift-specific attributes
        }
        
        for _, attrName in pairs(luckAttributes) do
            local value = egg:GetAttribute(attrName)
            if value and type(value) == "number" and value >= 25 then
                return egg, value
            end
        end
        
        -- Check for script values that might indicate luck
        for _, child in pairs(egg:GetDescendants()) do
            if child:IsA("ModuleScript") or child:IsA("Script") then
                local success, result = pcall(function()
                    -- Try to access common property names
                    local props = {"Value", "Luck", "Multiplier"}
                    for _, prop in ipairs(props) do
                        if child[prop] and type(child[prop]) == "number" and child[prop] >= 25 then
                            return child[prop]
                        end
                    end
                    return nil
                end)
                
                if success and result then
                    return egg, result
                end
            end
        end
    end
    
    -- Scan global UI for relevant indicators
    for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
        if gui:IsA("TextLabel") or gui:IsA("TextButton") then
            local labelText = gui.Text:lower()
            
            -- Check for luck indicators with egg reference
            if (string.find(labelText, "25x") or 
                string.find(labelText, "x25") or 
                string.find(labelText, "25 luck")) and
               (string.find(labelText, preferredEgg:lower()) or 
                string.find(labelText, "egg") or 
                string.find(labelText, "rift")) then
                
                -- Find nearest matching egg
                local closestEgg = nil
                local minDistance = 75
                
                for _, egg in pairs(potentialEggs) do
                    local distance = (rootPart.Position - egg.Position).Magnitude
                    if distance < minDistance then
                        closestEgg = egg
                        minDistance = distance
                    end
                end
                
                if closestEgg then
                    return closestEgg, 25
                end
            end
        end
    end
    
    return nil
end

-- Improved webhook notification with better formatting and stealth
local function sendNotification(eggObject, luckMultiplier)
    if not eggObject or tick() - lastNotificationTime < notificationCooldown then return false end
    
    -- Prevent duplicate notifications
    local eggIdentifier = eggObject:GetFullName()
    if processedEggs[eggIdentifier] and tick() - processedEggs[eggIdentifier] < notificationCooldown * 2 then
        return false
    end
    
    processedEggs[eggIdentifier] = tick()
    lastNotificationTime = tick()
    
    -- Gather server information
    local serverID = game.JobId
    local currentPlayers = #Players:GetPlayers()
    local serverCapacity = Players.MaxPlayers
    local username = LocalPlayer.Name
    local privateUsername = string.sub(username, 1, 1) .. "***" .. string.sub(username, -1)
    
    -- Location information
    local locationHeight = "Unknown"
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        locationHeight = math.floor(LocalPlayer.Character.HumanoidRootPart.Position.Y) .. "m"
    end
    
    -- Generate server join command
    local eggName = eggObject.Name or "Unknown Egg"
    local joinCommand = 'game:GetService("TeleportService"):TeleportToPlaceInstance(' .. 
                      tostring(PLACE_ID) .. ', "' .. serverID .. '", game.Players.LocalPlayer)'
    
    -- Stealth webhook data format
    local notificationData = {
        username = "Rift Egg Scanner",  -- Generic, less suspicious name
        avatar_url = "https://i.imgur.com/XQQbAPn.png",
        embeds = {
            {
                title = "📍 Special Egg Located 📍",  -- Less obvious title
                description = "**High-value egg found in current server.**",
                color = 16776960,
                fields = {
                    {name = "Type", value = eggName, inline = true},
                    {name = "Value", value = "x" .. tostring(luckMultiplier or 25), inline = true},
                    {name = "Location", value = locationHeight, inline = true},
                    {name = "Server Status", value = currentPlayers .. "/" .. serverCapacity, inline = true},
                    {name = "Server ID", value = "```" .. serverID .. "```", inline = false},
                    {name = "Join Command", value = "```lua\n" .. joinCommand .. "\n```", inline = false}
                },
                footer = {text = "Egg Scanner v1.2"}, -- Generic version
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }
    }
    
    -- Send webhook with proper retry logic
    local successful = false
    local retryCount = 0
    
    while not successful and retryCount < 3 do
        retryCount = retryCount + 1
        
        successful = pcall(function()
            HttpService:PostAsync(
                DISCORD_WEBHOOK_URL,
                HttpService:JSONEncode(notificationData),
                Enum.HttpContentType.ApplicationJson,
                false
            )
        end)
        
        if successful then
            print("Server notification delivered for: " .. eggName)
        else
            print("Communication attempt " .. retryCount .. "/3 failed")
            
            wait(1)
            
            -- Simplified backup on final attempt
            if retryCount == 2 then
                successful = pcall(function()
                    HttpService:PostAsync(
                        DISCORD_WEBHOOK_URL,
                        HttpService:JSONEncode({
                            content = "**High-value " .. eggName .. " found!**\nServer: " .. serverID .. 
                                    "\nPlayers: " .. currentPlayers .. "/" .. serverCapacity .. 
                                    "\nJoin: ```lua\n" .. joinCommand .. "\n```"
                        }),
                        Enum.HttpContentType.ApplicationJson,
                        false
                    )
                end)
                
                if successful then
                    print("Backup notification method succeeded")
                end
            end
        end
    end
    
    return successful
end

-- Refined movement system for smoother approach
local function approachEgg(egg)
    if not egg then 
        print("No valid target provided")
        return false 
    end
    
    print("Moving to target: " .. egg.Name)
    
    -- Identify the part to approach
    local targetPart
    if egg:IsA("BasePart") then
        targetPart = egg
    else
        targetPart = egg:FindFirstChildWhichIsA("BasePart")
        
        if not targetPart then
            for _, child in pairs(egg:GetDescendants()) do
                if child:IsA("BasePart") then
                    targetPart = child
                    break
                end
            end
        end
    end
    
    if not targetPart then 
        print("No valid part to approach")
        return false 
    end
    
    -- Get character components
    local character = LocalPlayer.Character
    if not character then 
        print("Character not available")
        return false 
    end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not rootPart or not humanoid then 
        print("Character components missing")
        return false 
    end
    
    -- Cancel existing movement
    if activeMovement then
        activeMovement:Cancel()
        activeMovement = nil
    end
    
    -- Calculate approach position at character height
    local approachPosition = Vector3.new(
        targetPart.Position.X,
        rootPart.Position.Y,
        targetPart.Position.Z
    )
    
    -- Check if already at position
    local distanceToTarget = (approachPosition - rootPart.Position).Magnitude
    if distanceToTarget <= 0.1 then
        print("Already at target location")
        return true
    end
    
    -- Improved tween settings for natural movement
    local tweenConfig = TweenInfo.new(
        distanceToTarget / movementSpeed,
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out,
        0,
        false,
        0
    )
    
    -- First orient towards target
    local facingDirection = CFrame.lookAt(
        rootPart.Position,
        Vector3.new(targetPart.Position.X, rootPart.Position.Y, targetPart.Position.Z)
    )
    
    rootPart.CFrame = facingDirection
    wait(0.1)
    
    -- Add slight offset to avoid crowding
    local targetPosition = CFrame.new(
        targetPart.Position.X + (math.random(-20, 20) / 10),
        rootPart.Position.Y, 
        targetPart.Position.Z + (math.random(-20, 20) / 10)
    ) * CFrame.new(0, 0, -3.5)
    
    -- Create and initiate movement
    local movementInitiated = false
    local movementSuccess = pcall(function()
        activeMovement = TweenService:Create(rootPart, tweenConfig, {
            CFrame = targetPosition
        })
        
        activeMovement:Play()
        movementInitiated = true
        
        activeMovement.Completed:Connect(function(state)
            if state == Enum.PlaybackState.Completed then
                print("Movement completed")
            else
                print("Movement interrupted")
            end
            activeMovement = nil
        end)
    end)
    
    -- Fallback if tween fails
    if not movementSuccess or not movementInitiated then
        print("Movement system error - using direct method")
        rootPart.CFrame = targetPosition
        wait(0.5)
        return true
    end
    
    -- Wait for movement to complete with timeout
    local startTime = tick()
    local timeoutDuration = math.max(5, (distanceToTarget / movementSpeed) + 2)
    
    repeat
        wait(0.1)
        if tick() - startTime > timeoutDuration then
            print("Movement timeout - using emergency approach")
            if activeMovement then
                activeMovement:Cancel()
                activeMovement = nil
            end
            
            rootPart.CFrame = CFrame.new(
                targetPart.Position.X + (math.random(-20, 20) / 10),
                rootPart.Position.Y, 
                targetPart.Position.Z + (math.random(-20, 20) / 10)
            ) * CFrame.new(0, 0, -3)
            
            wait(0.5)
            break
        end
    until activeMovement == nil
    
    -- Final approach for natural interaction
    pcall(function()
        humanoid:MoveTo(Vector3.new(
            targetPart.Position.X, 
            rootPart.Position.Y,
            targetPart.Position.Z
        ) - (targetPart.Position - rootPart.Position).Unit * 3)
    end)
    
    print("Approach complete")
    return true
end

-- Improved egg interaction handling
local function interactWithEgg(egg, amount)
    if not enableEggOpening or not egg then return end
    
    amount = amount or eggOpenCount
    print("Interacting with: " .. egg.Name .. " x" .. amount)
    
    -- Check for proximity prompt
    local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt")
    if prompt then
        for i = 1, amount do
            fireproximityprompt(prompt)
            wait(0.2)
        end
        return true
    end
    
    -- Check for click detector
    local detector = egg:FindFirstChildWhichIsA("ClickDetector")
    if detector then
        for i = 1, amount do
            fireclickdetector(detector)
            wait(0.2)
        end
        return true
    end
    
    -- Find relevant remote events - more specific pattern matching for Rift
    for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
        if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
            local remoteName = string.lower(remote.Name)
            -- Enhanced pattern matching for Rift egg systems
            if string.find(remoteName, "egg") or string.find(remoteName, "hatch") or
               string.find(remoteName, "open") or string.find(remoteName, "rift") or
               string.find(remoteName, "claim") or string.find(remoteName, "collect") then
                for i = 1, amount do
                    pcall(function()
                        -- Try different argument patterns
                        remote:FireServer(egg)
                        remote:FireServer(egg.Name)
                        remote:FireServer(egg.Name, amount)
                        remote:FireServer("Open", egg.Name)
                        remote:FireServer("Hatch", egg)
                    end)
                    wait(0.2)
                end
                return true
            end
        end
    end
    
    return false
end

-- Revamped server hopping function
local function findNewServer()
    if tick() - lastServerHop < serverHopCooldown then return false end
    
    if eggInVicinity then
        print("Valuable egg recently found, remaining in current server")
        eggInVicinity = false
        serverJoinTime = tick()
        searchTimer = tick()
        return false
    end
    
    print("Locating optimal server...")
    
    -- Fetch server list with error handling
    local success, serverList = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=100"
        ))
    end)
    
    if success and serverList and serverList.data then
        local viableServers = {}
        
        -- Filter and score servers
        for _, server in ipairs(serverList.data) do
            if server.playing < server.maxPlayers and server.playing > 0 and not serverHistory[server.id] then
                -- Score based on player count (3-8 is ideal for egg spawns)
                local viabilityScore = 100 - math.abs(5 - server.playing) * 10
                table.insert(viableServers, {server = server, score = viabilityScore})
            end
        end
        
        -- Prioritize by score
        table.sort(viableServers, function(a, b) return a.score > b.score end)
        
        -- Select from top scoring servers with slight randomization
        if #viableServers > 0 then
            local selectedServer = viableServers[math.random(1, math.min(3, #viableServers))].server
            
            lastServerHop = tick()
            serverHistory[selectedServer.id] = true
            
            print("Transferring to server: " .. selectedServer.id)
            
            pcall(function()
                TeleportService:TeleportToPlaceInstance(PLACE_ID, selectedServer.id, LocalPlayer)
            end)
            return true
        end
    end
    
    -- Limit server history size
    local historyCount = 0
    for _ in pairs(serverHistory) do historyCount = historyCount + 1 end
    
    if historyCount > 50 then
        serverHistory = {}
    end
    
    wait(2)
    return false
end

-- Enhanced main operational loop
local function operationCycle()
    if isActivelySeeking then return end
    isActivelySeeking = true
    
    print("------- Rift Egg Scanner v1.2 Initialized -------")
    print("Target priority: " .. preferredEgg)
    
    -- Initialize tracking timers
    serverJoinTime = tick()
    searchTimer = tick()
    
    -- Handle game UI interactions
    interactWithGameUI()
    
    while wait(0.5) do
        local targetEgg, luckValue = detectLuckyEgg()
        
        if targetEgg then
            -- Check if this egg has been processed already
            local eggIdentifier = targetEgg:GetFullName()
            
            if not processedEggs[eggIdentifier] or (tick() - processedEggs[eggIdentifier]) > notificationCooldown then
                processedEggs[eggIdentifier] = tick()
                lastEggDetection = tick()
                eggInVicinity = true
                
                print("Located target egg: " .. targetEgg.Name .. " with " .. tostring(luckValue) .. "x value")
                
                -- Send notification before approaching
                sendNotification(targetEgg, luckValue)
                
                -- Approach the egg
                local movementSuccess = approachEgg(targetEgg)
                
                -- Ensure movement completes
                wait(1.5)
                
                -- Attempt interaction
                if movementSuccess then
                    print("Successfully approached egg, initiating interaction")
                    interactWithEgg(targetEgg, eggOpenCount)
                else
                    print("Approach unsuccessful, attempting interaction from current position")
                    interactWithEgg(targetEgg, eggOpenCount)
                end
                
                -- Reset timers
                serverJoinTime = tick()
                searchTimer = tick()
            end
        else
            local timeInServer = tick() - serverJoinTime
            
            -- Check server transition conditions
            if timeInServer > serverSearchDuration and not eggInVicinity then
                print("Server search timeout (" .. serverSearchDuration .. "s), finding new server")
                if findNewServer() then
                    wait(2)
                    serverJoinTime = tick()
                    searchTimer = tick()
                    processedEggs = {}
                    interactWithGameUI()
                end
            elseif eggInVicinity and (tick() - lastEggDetection) > 60 then
                -- Reset egg detection status after timeout
                eggInVicinity = false
            end
        end
    end
    
    isActivelySeeking = false
end

-- Discrete UI design
local interface = Instance.new("ScreenGui")
interface.Name = "RiftEnhancer"  -- Generic, non-suspicious name
interface.ResetOnSpawn = false
interface.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

-- UI frame
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 240, 0, 80)
panel.Position = UDim2.new(0.5, -120, 0.02, 0)
panel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
panel.BackgroundTransparency = 0.3
panel.BorderSizePixel = 1
panel.BorderColor3 = Color3.fromRGB(80, 80, 100)
panel.Parent = interface

local cornerStyle = Instance.new("UICorner")
cornerStyle.CornerRadius = UDim.new(0, 6)
cornerStyle.Parent = panel

-- Panel header
local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, 0, 0.4, 0)
header.Position = UDim2.new(0, 0, 0, 0)
header.BackgroundTransparency = 1
header.TextColor3 = Color3.fromRGB(220, 220, 255)
header.Font = Enum.Font.Gotham
header.TextSize = 14
header.Text = "Rift Enhancement Suite"  -- Generic name
header.Parent = panel

-- Status display
local statusDisplay = Instance.new("TextLabel")
statusDisplay.Size = UDim2.new(1, 0, 0.3, 0)
statusDisplay.Position = UDim2.new(0, 0, 0.4, 0)
statusDisplay.BackgroundTransparency = 1
statusDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
statusDisplay.Font = Enum.Font.Gotham
statusDisplay.TextSize = 14
statusDisplay.Text = "Monitoring: " .. preferredEgg
statusDisplay.Parent = panel

-- Server information
local serverDisplay = Instance.new("TextLabel")
serverDisplay.Size = UDim2.new(1, 0, 0.3, 0)
serverDisplay.Position = UDim2.new(0, 0, 0.7, 0)
serverDisplay.BackgroundTransparency = 1
serverDisplay.TextColor3 = Color3.fromRGB(200, 200, 220)
serverDisplay.Font = Enum.Font.Gotham
serverDisplay.TextSize = 12
serverDisplay.Text = "Server: " .. string.sub(game.JobId, 1, 8) .. "..."
serverDisplay.Parent = panel

-- UI update loop
spawn(function()
    while wait(0.5) do
        if not interface or not interface.Parent then return end
        
        local elapsedTime = tick() - serverJoinTime
        local remainingTime = math.max(0, serverSearchDuration - elapsedTime)
        
        if eggInVicinity then
            statusDisplay.Text = "✓ Target Located"
            statusDisplay.TextColor3 = Color3.fromRGB(100, 255, 150)
        else
            statusDisplay.Text = "Scanning: " .. preferredEgg .. " - " .. math.floor(remainingTime) .. "s"
            
            if remainingTime < 3 then
                statusDisplay.TextColor3 = Color3.fromRGB(255, 180, 180)
            else
                statusDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
        end
        
        -- Update server information
        local playerCount = #Players:GetPlayers()
        local maxPlayers = Players.MaxPlayers
        serverDisplay.Text = "Status: " .. playerCount .. "/" .. maxPlayers .. " | " .. string.sub(game.JobId, 1, 8) .. "..."
    end
end)

-- Launch with error handling
spawn(function()
    while true do
        local success, errorMessage = pcall(operationCycle)
        if not success then
            print("Operation error: " .. tostring(errorMessage))
            isActivelySeeking = false
            wait(2)
        end
    end
end)

-- Automatic recovery system
spawn(function()
    while wait(15) do
        local currentTime = tick()
        if currentTime - searchTimer > 20 and isActivelySeeking then
            print("Operation stalled, restarting...")
            isActivelySeeking = false
            searchTimer = currentTime
            serverJoinTime = currentTime
            wait(1)
            pcall(operationCycle)
        end
    end
end)

print("📊 Rift Enhancement Suite initialized")
