local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Configuration
local DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1363054781882699910/Qwa5roGAv5rj83wBwCG7BzraXD8xOc7L-eeopKGdvCSug1GhdJzx6sRRNA1tjgmbRW34"
local PLACE_ID = 85896571713843
local egg_priority = "event-1"  -- Priority egg to search for
local egg_amount = 3            -- How many eggs to open
local open_eggs = true          -- Whether to open eggs
local maxServerSearchTime = 10  -- Server search time in seconds
local tweenSpeed = 6.0          -- FIXED: Reduced tween speed for more reliability (was 8.0)

-- Script variables
local visitedServers = {}
local lastTeleport = 0
local teleportCooldown = 5
local notifiedEggs = {}
local serverSearchTime = 0
local currentTween = nil
local isSearching = false
local lastEggFoundTime = 0
local eggFoundRecently = false
local initialServerTime = 0
local webhookCooldown = 30
local lastWebhookSent = 0

-- Prioritized list of hatchable eggs
local hatchable_eggs = {
    "event-1", "event-2", "rainbow-egg", "void-egg", "nightmare-egg", "aura-egg"
}

-- FIXED: Optimized play button function with improved detection and interaction methods
local function pressPlayButtons()
    print("Looking for play buttons...")
    
    -- Wait for GUI elements to load properly
    wait(2)
    
    -- Track if we found and pressed any buttons
    local buttonPressed = false
    
    -- First approach: Direct button detection with multiple methods
    for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
        if not buttonPressed and (gui:IsA("TextButton") or gui:IsA("ImageButton")) and gui.Visible then
            local text = ""
            
            -- Get text from the button or its children
            if gui:IsA("TextButton") then
                text = gui.Text:lower()
            elseif gui:FindFirstChild("TextLabel") then
                text = gui:FindFirstChild("TextLabel").Text:lower()
            end
            
            -- Look for any labels that might be children of the button
            for _, child in pairs(gui:GetDescendants()) do
                if child:IsA("TextLabel") and child.Visible then
                    text = text .. " " .. child.Text:lower()
                end
            end
            
            -- Check for common button keywords
            for _, keyword in pairs({"play", "start", "enter", "join", "continue", "ok", "yes", "claim", "next"}) do
                if string.find(text, keyword) then
                    print("Found button with text containing: " .. keyword)
                    
                    -- Try multiple firing methods for maximum compatibility
                    local clickSuccess = false
                    
                    -- Method 1: Direct MouseButton1Click firing
                    pcall(function() 
                        gui.MouseButton1Click:Fire() 
                        clickSuccess = true
                        print("Method 1 success")
                    end)
                    
                    -- Method 2: Fire signal
                    if not clickSuccess then
                        pcall(function() 
                            firesignal(gui.MouseButton1Click) 
                            clickSuccess = true
                            print("Method 2 success")
                        end)
                    end
                    
                    -- Method 3: Use VirtualUser service
                    if not clickSuccess then
                        pcall(function()
                            local VirtualUser = game:GetService("VirtualUser")
                            local position = gui.AbsolutePosition + gui.AbsoluteSize/2
                            VirtualUser:Button1Down(position, workspace.CurrentCamera.CFrame)
                            wait(0.1)
                            VirtualUser:Button1Up(position, workspace.CurrentCamera.CFrame)
                            clickSuccess = true
                            print("Method 3 success")
                        end)
                    end
                    
                    -- Method 4: Try to invoke any attached functions
                    if not clickSuccess then
                        for _, connection in pairs(getconnections(gui.MouseButton1Click)) do
                            pcall(function()
                                connection:Fire()
                                clickSuccess = true
                                print("Method 4 success")
                            end)
                        end
                    end

                    -- If we succeeded with any method, mark as pressed
                    if clickSuccess then
                        buttonPressed = true
                        wait(0.5)
                        break
                    end
                end
            end
        end
    end
    
    -- Second approach: Generic scan for any interactive elements in loading screens
    if not buttonPressed then
        for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if (gui:IsA("Frame") or gui:IsA("ImageLabel")) and gui.Visible and 
               (string.find(string.lower(gui.Name), "load") or 
                string.find(string.lower(gui.Name), "screen") or 
                string.find(string.lower(gui.Name), "menu")) then
                
                -- Find all buttons within this potential menu
                for _, button in pairs(gui:GetDescendants()) do
                    if (button:IsA("TextButton") or button:IsA("ImageButton")) and button.Visible then
                        pcall(function() 
                            button.MouseButton1Click:Fire() 
                            buttonPressed = true
                        end)
                        wait(0.1)
                    end
                end
            end
        end
    end
    
    return buttonPressed
end

-- Egg detection function
local function findLuckyEgg()
    print("Scanning for 25x lucky " .. egg_priority .. " egg...")
    
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return nil end
    
    local hrp = character.HumanoidRootPart
    local nearbyEggs = {}
    
    -- Collect all nearby potential egg objects
    for _, object in pairs(workspace:GetDescendants()) do
        if object:IsA("BasePart") and not object:IsDescendantOf(character) then
            local distance = (hrp.Position - object.Position).Magnitude
            if distance <= 50 then
                local name = object.Name:lower()
                if string.find(name, "egg") or string.find(name, egg_priority:lower()) then
                    table.insert(nearbyEggs, object)
                end
            end
        end
    end
    
    -- Check for priority egg with 25x luck
    for _, egg in pairs(nearbyEggs) do
        -- Look for GUI elements that might indicate luck
        for _, gui in pairs(egg:GetDescendants()) do
            if gui:IsA("TextLabel") or gui:IsA("BillboardGui") then
                local text = ""
                if gui:IsA("TextLabel") then
                    text = gui.Text:lower()
                elseif gui:FindFirstChild("TextLabel") then
                    text = gui:FindFirstChild("TextLabel").Text:lower()
                end
                
                -- Check for luck indicators
                if string.find(text, "25x") or string.find(text, "x25") or 
                   string.find(text, "25 luck") or string.find(text, "luck 25") then
                    return egg, 25
                end
            end
        end
        
        -- Check for attributes
        for _, attrName in pairs({"Luck", "LuckMultiplier", "Multiplier", "Boost"}) do
            local value = egg:GetAttribute(attrName)
            if value and type(value) == "number" and value >= 25 then
                return egg, value
            end
        end
    end
    
    -- Check global GUI indicators as fallback
    for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
        if gui:IsA("TextLabel") or gui:IsA("TextButton") then
            local text = gui.Text:lower()
            
            -- Check for luck indicators along with egg name
            if (string.find(text, "25x") or string.find(text, "x25")) and
               (string.find(text, egg_priority:lower()) or string.find(text, "egg")) then
                
                -- Look for nearest egg
                local nearestEgg = nil
                local minDistance = 50
                
                for _, egg in pairs(nearbyEggs) do
                    local distance = (hrp.Position - egg.Position).Magnitude
                    if distance < minDistance then
                        nearestEgg = egg
                        minDistance = distance
                    end
                end
                
                if nearestEgg then
                    return nearestEgg, 25
                end
            end
        end
    end
    
    return nil
end

-- FIXED: Improved Discord webhook notification function with better reliability and formatting
local function sendDiscordNotification(eggInfo, eggLuck)
    if not eggInfo or tick() - lastWebhookSent < webhookCooldown then return false end
    
    -- Prevent redundant notifications
    local eggId = eggInfo:GetFullName()
    if notifiedEggs[eggId] and tick() - notifiedEggs[eggId] < webhookCooldown * 2 then
        return false
    end
    
    notifiedEggs[eggId] = tick()
    lastWebhookSent = tick()
    
    -- Get server and player info
    local jobId = game.JobId
    local playerCount = #Players:GetPlayers()
    local maxPlayers = Players.MaxPlayers
    local playerName = LocalPlayer.Name
    local censoredName = string.sub(playerName, 1, 1) .. "***" .. string.sub(playerName, -1)
    
    -- Get player position
    local height = "Unknown"
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        height = math.floor(LocalPlayer.Character.HumanoidRootPart.Position.Y) .. "m"
    end
    
    -- Create teleport script
    local eggType = eggInfo.Name or "Unknown Egg"
    local teleportScript = 'game:GetService("TeleportService"):TeleportToPlaceInstance(' .. 
                         tostring(PLACE_ID) .. ', "' .. jobId .. '", game.Players.LocalPlayer)'
    
    -- Create webhook data with improved formatting and error catching
    local webhookData = {
        username = "25x Egg Finder",
        avatar_url = "https://i.imgur.com/XQQbAPn.png",
        embeds = {
            {
                title = "🔥 25X Luck " .. eggType .. " Found 🔥",
                description = "**Priority egg with 25X Luck found!** Join quickly!",
                color = 16776960,
                fields = {
                    {name = "🥚 Egg Type", value = eggType, inline = true},
                    {name = "✨ Luck Multiplier", value = "x" .. tostring(eggLuck or 25), inline = true},
                    {name = "📏 Height", value = height, inline = true},
                    {name = "👥 Server Slots", value = playerCount .. "/" .. maxPlayers, inline = true},
                    {name = "🆔 Job ID", value = "```" .. jobId .. "```", inline = false},
                    {name = "🚀 Teleport Script", value = "```lua\n" .. teleportScript .. "\n```", inline = false}
                },
                footer = {text = "25x Priority Egg Finder v4.3"}, -- Updated version number
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }
    }
    
    -- Send webhook with comprehensive error handling and retry logic
    local success = false
    local attempts = 0
    
    while not success and attempts < 3 do
        attempts = attempts + 1
        
        success = pcall(function()
            HttpService:PostAsync(
                DISCORD_WEBHOOK_URL,
                HttpService:JSONEncode(webhookData),
                Enum.HttpContentType.ApplicationJson,
                false
            )
        end)
        
        if success then
            print("Discord notification sent successfully for: " .. eggType)
        else
            print("Webhook send failed, attempt " .. attempts .. "/3")
            
            -- Wait before retry
            wait(1)
            
            -- On final attempt, use simplified payload
            if attempts == 2 then
                -- Simplified fallback with minimal payload
                success = pcall(function()
                    HttpService:PostAsync(
                        DISCORD_WEBHOOK_URL,
                        HttpService:JSONEncode({
                            content = "**25X LUCK " .. eggType .. " FOUND!**\nServer: " .. jobId .. 
                                    "\nPlayers: " .. playerCount .. "/" .. maxPlayers .. 
                                    "\nTeleport: ```lua\n" .. teleportScript .. "\n```"
                        }),
                        Enum.HttpContentType.ApplicationJson,
                        false
                    )
                end)
                
                if success then
                    print("Discord notification sent using fallback method")
                end
            end
        end
    end
    
    return success
end

-- FIXED: Improved tweening function with smoother movement, better reliability and better error handling
local function tweenToEgg(egg)
    if not egg then 
        print("No egg provided to tweenToEgg function")
        return false 
    end
    
    print("Tweening to priority egg: " .. egg.Name)
    
    -- Find the part to tween to
    local eggPart
    if egg:IsA("BasePart") then
        eggPart = egg
    else
        eggPart = egg:FindFirstChildWhichIsA("BasePart")
        
        if not eggPart then
            for _, child in pairs(egg:GetDescendants()) do
                if child:IsA("BasePart") then
                    eggPart = child
                    break
                end
            end
        end
    end
    
    if not eggPart then 
        print("No valid part found in egg")
        return false 
    end
    
    -- Get character and humanoid
    local character = LocalPlayer.Character
    if not character then 
        print("Character not found")
        return false 
    end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoidRootPart or not humanoid then 
        print("HumanoidRootPart or Humanoid not found")
        return false 
    end
    
    -- Cancel any existing tween
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    
    -- Get egg's ground position (same Y level as character)
    local groundPosition = Vector3.new(
        eggPart.Position.X,
        humanoidRootPart.Position.Y,
        eggPart.Position.Z
    )
    
    -- Get distance for tween calculation
    local distance = (groundPosition - humanoidRootPart.Position).Magnitude
    if distance <= 0.1 then
        print("Already at egg position")
        return true
    end
    
    -- FIXED: Adjusted tween info for smoother approach with gradual deceleration
    local tweenInfo = TweenInfo.new(
        distance / tweenSpeed, -- Slower speed for more reliability
        Enum.EasingStyle.Quad, -- Changed from Linear to Quad for smoother movement
        Enum.EasingDirection.Out, -- Changed to Out for deceleration near target
        0,  -- No repeat
        false,  -- Don't reverse
        0  -- No delay
    )
    
    -- Create a new CFrame that faces the egg
    local lookAt = CFrame.lookAt(
        humanoidRootPart.Position, -- Start from current position
        Vector3.new(eggPart.Position.X, humanoidRootPart.Position.Y, eggPart.Position.Z)
    )
    
    -- First orient the character to face the egg
    humanoidRootPart.CFrame = lookAt
    wait(0.1) -- Small delay to allow character to face egg
    
    -- Calculate approach position - slightly further back to prevent collision issues
    local targetCFrame = CFrame.new(
        eggPart.Position.X - (math.random(-15, 15) / 10), -- Add slight offset to avoid crowds
        humanoidRootPart.Position.Y, 
        eggPart.Position.Z - (math.random(-15, 15) / 10)
    ) * CFrame.new(0, 0, -3.5) -- Position slightly away from the egg
    
    -- Create and store the tween with proper error handling
    local tweenStarted = false
    local tweenSuccess = pcall(function()
        currentTween = TweenService:Create(humanoidRootPart, tweenInfo, {
            CFrame = targetCFrame
        })
        
        -- Print additional logging
        print("Starting tween from: " .. tostring(humanoidRootPart.Position))
        print("Tweening to: " .. tostring(targetCFrame.Position))
        print("Distance: " .. tostring(distance) .. " studs")
        print("Estimated time: " .. tostring(distance / tweenSpeed) .. " seconds")
        
        currentTween:Play()
        tweenStarted = true
        
        -- Set up a completion callback
        currentTween.Completed:Connect(function(playbackState)
            if playbackState == Enum.PlaybackState.Completed then
                print("Tween completed successfully")
            else
                print("Tween was cancelled or interrupted")
            end
            currentTween = nil
        end)
    end)
    
    -- If tween creation/start failed, try direct teleportation
    if not tweenSuccess or not tweenStarted then
        print("Failed to start tween - attempting direct teleport")
        -- Fallback: Direct teleport if tweening fails
        humanoidRootPart.CFrame = targetCFrame
        wait(0.5)
        return true
    end
    
    -- Wait for tween to complete with timeout
    local startTime = tick()
    local maxWaitTime = math.max(5, (distance / tweenSpeed) + 2) -- Reasonable timeout
    
    repeat
        wait(0.1)
        -- Check if we've waited too long
        if tick() - startTime > maxWaitTime then
            print("Tween timeout after " .. (tick() - startTime) .. "s - canceling")
            if currentTween then
                currentTween:Cancel()
                currentTween = nil
            end
            
            -- Emergency teleport with small random offset to avoid other players
            humanoidRootPart.CFrame = CFrame.new(
                eggPart.Position.X + (math.random(-20, 20) / 10),
                humanoidRootPart.Position.Y, 
                eggPart.Position.Z + (math.random(-20, 20) / 10)
            ) * CFrame.new(0, 0, -3)
            
            wait(0.5)
            break
        end
    until currentTween == nil
    
    -- Add final approach movement using Humanoid's MoveTo for better animation
    pcall(function()
        humanoid:MoveTo(Vector3.new(
            eggPart.Position.X, 
            humanoidRootPart.Position.Y,
            eggPart.Position.Z
        ) - (eggPart.Position - humanoidRootPart.Position).Unit * 3)
    end)
    
    print("Arrived at priority egg")
    return true
end

-- Egg opening function
local function openEgg(egg, amount)
    if not open_eggs or not egg then return end
    
    amount = amount or egg_amount
    print("Opening egg: " .. egg.Name .. " x" .. amount)
    
    -- Try proximity prompt
    local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt")
    if prompt then
        for i = 1, amount do
            fireproximityprompt(prompt)
            wait(0.2)
        end
        return true
    end
    
    -- Try click detector
    local clickDetector = egg:FindFirstChildWhichIsA("ClickDetector")
    if clickDetector then
        for i = 1, amount do
            fireclickdetector(clickDetector)
            wait(0.2)
        end
        return true
    end
    
    -- Try remote events
    for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
        if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
            local name = string.lower(remote.Name)
            if string.find(name, "egg") or string.find(name, "hatch") or string.find(name, "open") then
                for i = 1, amount do
                    pcall(function()
                        -- Try different argument patterns
                        remote:FireServer(egg)
                        remote:FireServer(egg.Name)
                        remote:FireServer(egg.Name, amount)
                    end)
                    wait(0.2)
                end
                return true
            end
        end
    end
    
    return false
end

-- Server hopping function
local function hopToNextServer()
    if tick() - lastTeleport < teleportCooldown then return false end
    
    -- Don't hop if we found an egg recently
    if eggFoundRecently then
        print("Priority egg found recently, staying in current server")
        eggFoundRecently = false
        initialServerTime = tick()
        serverSearchTime = tick()
        return false
    end
    
    print("Finding new server...")
    
    -- Get server list
    local success, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=100"
        ))
    end)
    
    if success and result and result.data then
        local servers = {}
        
        -- Filter servers
        for _, server in ipairs(result.data) do
            if server.playing < server.maxPlayers and server.playing > 0 and not visitedServers[server.id] then
                -- Score servers (prefer 3-8 players)
                local score = 100 - math.abs(5 - server.playing) * 10
                table.insert(servers, {server = server, score = score})
            end
        end
        
        -- Sort by score
        table.sort(servers, function(a, b) return a.score > b.score end)
        
        -- Select a high-scoring server
        if #servers > 0 then
            local selectedServer = servers[math.random(1, math.min(3, #servers))].server
            
            lastTeleport = tick()
            visitedServers[selectedServer.id] = true
            
            print("Teleporting to server: " .. selectedServer.id)
            
            pcall(function()
                TeleportService:TeleportToPlaceInstance(PLACE_ID, selectedServer.id, LocalPlayer)
            end)
            return true
        end
    end
    
    -- Clean up visited servers list if it gets too large
    if table.getn(visitedServers) > 50 then
        visitedServers = {}
    end
    
    wait(2)
    return false
end

-- Main script loop with fixed egg processing
local function mainLoop()
    if isSearching then return end
    isSearching = true
    
    print("------- 25x Priority Egg Finder v4.3 Started -------")
    print("Priority egg: " .. egg_priority)
    
    -- Initialize timers
    initialServerTime = tick()
    serverSearchTime = tick()
    
    -- Press play buttons when entering game
    pressPlayButtons()
    
    while wait(0.5) do
        local foundEgg, luckValue = findLuckyEgg()
        
        if foundEgg then
            -- Check if we've already notified about this egg
            local eggId = foundEgg:GetFullName()
            
            if not notifiedEggs[eggId] or (tick() - notifiedEggs[eggId]) > webhookCooldown then
                notifiedEggs[eggId] = tick()
                lastEggFoundTime = tick()
                eggFoundRecently = true
                
                print("Found priority 25x egg: " .. foundEgg.Name .. " with " .. tostring(luckValue) .. "x luck")
                
                -- Send notification first
                sendDiscordNotification(foundEgg, luckValue)
                
                -- Fix: Always ensure tweening happens with proper waiting
                local tweenSuccess = tweenToEgg(foundEgg)
                
                -- Add extra wait to ensure tween completes
                wait(1.5) -- Increased wait time for more reliability
                
                -- Try to open the egg
                if tweenSuccess then
                    print("Successfully tweened to egg, now opening")
                    openEgg(foundEgg, egg_amount)
                else
                    print("Tween failed, attempting to open egg anyway")
                    openEgg(foundEgg, egg_amount)
                end
                
                -- Reset timers
                initialServerTime = tick()
                serverSearchTime = tick()
            end
        else
            local totalServerTime = tick() - initialServerTime
            
            -- Hop to next server if max time reached and no egg found recently
            if totalServerTime > maxServerSearchTime and not eggFoundRecently then
                print("Max time in server reached (" .. maxServerSearchTime .. "s), hopping to next server")
                if hopToNextServer() then
                    wait(2)
                    initialServerTime = tick()
                    serverSearchTime = tick()
                    notifiedEggs = {}
                    pressPlayButtons()
                end
            elseif eggFoundRecently and (tick() - lastEggFoundTime) > 60 then
                -- Reset egg found flag after 60 seconds
                eggFoundRecently = false
            end
        end
    end
    
    isSearching = false
end

-- Simple UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EggFinderGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

-- Main frame
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 240, 0, 80)
frame.Position = UDim2.new(0.5, -120, 0.02, 0)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
frame.BackgroundTransparency = 0.2
frame.BorderSizePixel = 2
frame.BorderColor3 = Color3.fromRGB(255, 215, 0)
frame.Parent = screenGui

local cornerRadius = Instance.new("UICorner")
cornerRadius.CornerRadius = UDim.new(0, 8)
cornerRadius.Parent = frame

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0.4, 0)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Text = "25x Priority Egg Finder v4.3"
title.Parent = frame

-- Status
local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, 0, 0.3, 0)
status.Position = UDim2.new(0, 0, 0.4, 0)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(255, 255, 255)
status.Font = Enum.Font.Gotham
status.TextSize = 14
status.Text = "Searching: " .. egg_priority
status.Parent = frame

-- Server info
local serverInfo = Instance.new("TextLabel")
serverInfo.Size = UDim2.new(1, 0, 0.3, 0)
serverInfo.Position = UDim2.new(0, 0, 0.7, 0)
serverInfo.BackgroundTransparency = 1
serverInfo.TextColor3 = Color3.fromRGB(200, 200, 200)
serverInfo.Font = Enum.Font.Gotham
serverInfo.TextSize = 12
serverInfo.Text = "Server: " .. string.sub(game.JobId, 1, 8) .. "..."
serverInfo.Parent = frame

-- Status update function
spawn(function()
    while wait(0.5) do
        if not screenGui or not screenGui.Parent then return end
        
        local timeSpent = tick() - initialServerTime
        local timeLeft = math.max(0, maxServerSearchTime - timeSpent)
        
        if eggFoundRecently then
            status.Text = "🥚 Priority Egg Found!"
            status.TextColor3 = Color3.fromRGB(0, 255, 100)
        else
            status.Text = "Searching: " .. egg_priority .. " - " .. math.floor(timeLeft) .. "s"
            
            if timeLeft < 3 then
                status.TextColor3 = Color3.fromRGB(255, 100, 100)
            else
                status.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
        end
        
        -- Update server info
        local playerCount = #Players:GetPlayers()
        local maxPlayers = Players.MaxPlayers
        serverInfo.Text = "Players: " .. playerCount .. "/" .. maxPlayers .. " | ID: " .. string.sub(game.JobId, 1, 8) .. "..."
    end
end)

-- Start the script with error handling
spawn(function()
    while true do
        local success, errorMsg = pcall(mainLoop)
        if not success then
            print("Error: " .. tostring(errorMsg))
            isSearching = false
            wait(2)
        end
    end
end)

-- Auto-recovery if stalled
spawn(function()
    while wait(15) do
        local currentTime = tick()
        if currentTime - serverSearchTime > 20 and isSearching then
            print("Script appears stalled, restarting...")
            isSearching = false
            serverSearchTime = currentTime
            initialServerTime = currentTime
            wait(1)
            pcall(mainLoop)
        end
    end
end)

print("🚀 25x Priority Egg Finder v4.3 initialized")
