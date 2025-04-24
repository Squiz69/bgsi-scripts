local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Configuration
local DISCORD_WEBHOOK_URL = getgenv().Config and getgenv().Config.Webhook or "https://discord.com/api/webhooks/1363054781882699910/Qwa5roGAv5rj83wBwCG7BzraXD8xOc7L-eeopKGdvCSug1GhdJzx6sRRNA1tjgmbRW34"
local PLACE_ID = 85896571713843
local egg_priority = "event-1"  -- Updated priority egg to rainbow-egg
local egg_amount = 3            -- How many eggs to open
local open_eggs = true          -- Whether to open eggs
local maxServerSearchTime = 10  -- Server search time in seconds
local fallbackImage = "https://i.imgur.com/XQQbAPn.png" -- Fallback image for webhook

-- Script variables
local visitedServers = {}
local lastTeleport = 0
local teleportCooldown = 5
local notifiedEggs = {}
local serverSearchTime = 0
local isSearching = false
local lastEggFoundTime = 0
local eggFoundRecently = false
local initialServerTime = 0
local webhookCooldown = 30
local lastWebhookSent = 0
local currentCFrameValue = nil
local timerFixed = false  -- Flag to track if timer has been fixed

-- Prioritized list of hatchable eggs
local hatchable_eggs = {
    "rainbow-egg", "event-1", "event-2", "void-egg", "nightmare-egg", "aura-egg"
}

-- NEW EGG DETECTION FUNCTION
local function findLuckyEgg()
    print("Scanning for 25x lucky eggs in Rifts...")
    
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return nil end
    
    -- Use the new detection method that looks in the Rifts folder
    for _, v in next, game:GetService("Workspace").Rendered.Rifts:GetChildren() do
        if v.Display.SurfaceGui.Icon.Luck.Text == "x25" then
            print("Found 25x luck egg: " .. v.Name)
            return v, 25
        end
    end
    
    return nil
end

-- IMPROVED WEBHOOK FUNCTION WITH NEW FORMAT
local function sendWebhook(eggInfo, luckValue)
    if not eggInfo or tick() - lastWebhookSent < webhookCooldown then return false end
    
    -- Prevent redundant notifications
    local eggId = eggInfo:GetFullName()
    if notifiedEggs[eggId] and tick() - notifiedEggs[eggId] < webhookCooldown * 2 then
        return false
    end
    
    notifiedEggs[eggId] = tick()
    lastWebhookSent = tick()
    
    local player = LocalPlayer
    local name = eggInfo.Name or "Unknown Egg"
    local displayName = name:gsub("-", " "):gsub("^%l", string.upper) -- Convert "rainbow-egg" to "Rainbow Egg"
    
    -- Calculate height (dummy value - replace with actual height if available)
    local height = "12630"
    
    -- Calculate time left (dummy value - replace with actual time if available)
    local timeLeft = "44"
    
    -- Get server info
    local playerCount = #Players:GetPlayers()
    local maxPlayers = Players.MaxPlayers
    local serverVersion = "v9737" -- Replace with actual version if available
    local jobId = game.JobId
    
    -- Create custom formatted message
    local content = "**" .. displayName .. " Found!** :tada:\n" ..
                   "A 25X Luck " .. displayName .. " has been found! :rainbow:\n" ..
                   "Luck :four_leaf_clover:\nx25\n" ..
                   "Height :straight_ruler:\n" .. height .. "m\n" ..
                   "Time Left :alarm_clock:\n" .. timeLeft .. " seconds\n" ..
                   "Server Slots :busts_in_silhouette:\n" .. playerCount .. "/" .. maxPlayers .. "\n" ..
                   "Server Version\n" .. serverVersion .. "\n" ..
                   "Job ID\n" .. jobId .. "\n" ..
                   "Web Browser\n" .. "https://www.roblox.com/games/start?placeId=16302670534&launchData=" .. PLACE_ID .. "/" .. jobId .. "\n" ..
                   "Teleport Script\n" .. "game:GetService(\"TeleportService\"):TeleportToPlaceInstance(\"" .. PLACE_ID .. "\", \"" .. jobId .. "\", game.Players.LocalPlayer)"
    
    -- Simple webhook data
    local data = {
        ["content"] = content
    }
    
    -- Send webhook with error handling
    local success = false
    local attempts = 0
    
    while not success and attempts < 3 do
        attempts = attempts + 1
        
        success = pcall(function()
            HttpService:PostAsync(
                DISCORD_WEBHOOK_URL,
                HttpService:JSONEncode(data),
                Enum.HttpContentType.ApplicationJson,
                false
            )
        end)
        
        if success then
            print("Discord notification sent successfully for: " .. name)
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
                            content = "**25X LUCK " .. displayName .. " FOUND!**\nServer: " .. game.JobId
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

-- NEW IMPROVED TWEEN FUNCTION USING CFRAMEVALUE
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
    if not humanoidRootPart then 
        print("HumanoidRootPart not found")
        return false 
    end
    
    -- Clean up previous CFrameValue if it exists
    if currentCFrameValue then
        pcall(function() 
            currentCFrameValue:Destroy() 
        end)
        currentCFrameValue = nil
    end
    
    -- Create new CFrameValue and connect it
    local CFrameValue = Instance.new("CFrameValue")
    currentCFrameValue = CFrameValue
    CFrameValue.Value = humanoidRootPart.CFrame
    
    -- Connect property changed signal to update character position
    CFrameValue:GetPropertyChangedSignal("Value"):Connect(function()
        -- Make sure character and humanoid root part still exist
        if game:GetService("Players").LocalPlayer.Character and 
           game:GetService("Players").LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            game:GetService("Players").LocalPlayer.Character.HumanoidRootPart.CFrame = CFrameValue.Value
        end
    end)
    
    -- Create target CFrame (adding a small Y offset to avoid getting stuck)
    local targetCFrame = eggPart.CFrame + Vector3.new(0, 6, 0)
    
    -- Create and play the tween
    local tweenSuccess = pcall(function()
        local tween = game:GetService("TweenService"):Create(
            CFrameValue,
            TweenInfo.new(10, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
            {Value = targetCFrame}
        )
        
        tween:Play()
        
        -- Wait for tween to complete
        tween.Completed:Wait()
    end)
    
    -- Clean up
    if CFrameValue then
        pcall(function() 
            CFrameValue:Destroy() 
        end)
        currentCFrameValue = nil
    end
    
    return tweenSuccess
end

-- Egg opening function
local function openEgg(egg, amount)
    if not open_eggs or not egg then return false end
    
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
    
    -- Reset timer even if we couldn't find a server
    initialServerTime = tick()
    
    wait(2)
    return false
end

-- Main script loop with fixed timer handling
local function mainLoop()
    if isSearching then return end
    isSearching = true
    
    print("------- 25x Priority Egg Finder v5.1 Started -------")
    print("Priority egg: " .. egg_priority)
    
    -- Initialize timers properly once at the start
    if not timerFixed then
        initialServerTime = tick()
        serverSearchTime = tick()
        timerFixed = true
    end
    
    -- Keep track of priority eggs found
    local foundPriorityEgg = false
    
    while wait(0.5) do
        local foundEgg, luckValue = findLuckyEgg()
        
        -- Reset foundPriorityEgg status for this loop iteration
        foundPriorityEgg = false
        
        if foundEgg then
            -- Check if we've already notified about this egg
            local eggId = foundEgg:GetFullName()
            
            if not notifiedEggs[eggId] or (tick() - notifiedEggs[eggId]) > webhookCooldown then
                notifiedEggs[eggId] = tick()
                lastEggFoundTime = tick()
                eggFoundRecently = true
                foundPriorityEgg = true
                
                print("Found priority 25x egg: " .. foundEgg.Name .. " with " .. tostring(luckValue) .. "x luck")
                
                -- Send notification first
                sendWebhook(foundEgg, luckValue)
                
                -- Use new tween method
                local tweenSuccess = tweenToEgg(foundEgg)
                
                -- Add extra wait to ensure tween completes
                wait(1.5)
                
                -- Try to open the egg
                if tweenSuccess then
                    print("Successfully tweened to egg, now opening")
                    openEgg(foundEgg, egg_amount)
                else
                    print("Tween failed, attempting to open egg anyway")
                    openEgg(foundEgg, egg_amount)
                end
                
                -- Reset timers ONLY if this was a priority egg
                initialServerTime = tick()
                serverSearchTime = tick()
            end
        end
        
        -- FIXED: Don't reset timer unless the max server time is reached
        if not foundPriorityEgg then
            local totalServerTime = tick() - initialServerTime
            
            -- Hop to next server if max time reached and no egg found recently
            if totalServerTime > maxServerSearchTime and not eggFoundRecently then
                print("Max time in server reached (" .. maxServerSearchTime .. "s), hopping to next server")
                if hopToNextServer() then
                    wait(2)
                    -- Reset timers after server hop
                    notifiedEggs = {}
                    -- Don't reset initialServerTime here, only in hopToNextServer
                end
            elseif eggFoundRecently and (tick() - lastEggFoundTime) > 60 then
                -- Reset egg found flag after 60 seconds
                eggFoundRecently = false
            end
        end
    end
    
    isSearching = false
end

-- Simple UI with improved design
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EggFinderGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

-- Main frame
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 240, 0, 100)  -- Made taller for more info
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
title.Size = UDim2.new(1, 0, 0.3, 0)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Text = "25x Priority Egg Finder v5.1"
title.Parent = frame

-- Status
local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, 0, 0.25, 0)
status.Position = UDim2.new(0, 0, 0.3, 0)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(255, 255, 255)
status.Font = Enum.Font.Gotham
status.TextSize = 14
status.Text = "Searching: " .. egg_priority
status.Parent = frame

-- Timer
local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(1, 0, 0.2, 0)
timerLabel.Position = UDim2.new(0, 0, 0.55, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
timerLabel.Font = Enum.Font.Gotham
timerLabel.TextSize = 13
timerLabel.Text = "Time left: " .. tostring(maxServerSearchTime) .. "s"
timerLabel.Parent = frame

-- Server info
local serverInfo = Instance.new("TextLabel")
serverInfo.Size = UDim2.new(1, 0, 0.25, 0)
serverInfo.Position = UDim2.new(0, 0, 0.75, 0)
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
        
        -- Update timer text
        timerLabel.Text = "Time left: " .. math.floor(timeLeft) .. "s"
        
        if eggFoundRecently then
            status.Text = "🥚 Priority Egg Found!"
            status.TextColor3 = Color3.fromRGB(0, 255, 100)
            timerLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
        else
            status.Text = "Searching: " .. egg_priority
            
            if timeLeft < 3 then
                status.TextColor3 = Color3.fromRGB(255, 100, 100)
                timerLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            else
                status.TextColor3 = Color3.fromRGB(255, 255, 255)
                timerLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
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
            wait(1)
            pcall(mainLoop)
        end
    end
end)

print("🚀 25x Priority Egg Finder v5.1 initialized")
