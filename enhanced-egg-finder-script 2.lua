repeat task.wait() until game:IsLoaded()

-- Services
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Configuration
local DISCORD_WEBHOOK_URL = getgenv().Config and getgenv().Config.Webhook or "https://discord.com/api/webhooks/1363054781882699910/Qwa5roGAv5rj83wBwCG7BzraXD8xOc7L-eeopKGdvCSug1GhdJzx6sRRNA1tjgmbRW34"
local PLACE_ID = 16302670534  -- Bubble Gum Simulator Infinity
local egg_priority = "rainbow-egg"
local egg_amount = 3
local open_eggs = true
local maxServerSearchTime = 10  -- Server search time in seconds
local webhookCooldown = 30
local maxTweenRetries = 3  -- New: Maximum number of tween retry attempts

-- Priority eggs list
local hatchable_eggs = {
    "rainbow-egg", "event-1", "event-2", "void-egg", "nightmare-egg", "aura-egg"
}

-- Script variables
local visitedServers = {}
local lastTeleport = 0
local teleportCooldown = 5
local notifiedEggs = {}
local lastWebhookSent = 0
local currentCFrameValue = nil
local initialServerTime = tick()
local eggFoundRecently = false
local lastEggFoundTime = 0
local isSearching = false

-- Find 25x lucky eggs in Rifts
local function findLuckyEggs()
    local luckyEggs = {}
    
    for _, v in next, game:GetService("Workspace").Rendered.Rifts:GetChildren() do
        if v.Display.SurfaceGui.Icon.Luck.Text == "x25" then
            table.insert(luckyEggs, v)
            print("Found 25x luck egg: " .. v.Name)
        end
    end
    
    return luckyEggs
end

-- Send webhook notification
local function sendWebhook(eggInfo)
    if not eggInfo or tick() - lastWebhookSent < webhookCooldown then return false end
    
    -- Prevent redundant notifications
    local eggId = eggInfo:GetFullName()
    if notifiedEggs[eggId] and tick() - notifiedEggs[eggId] < webhookCooldown * 2 then
        return false
    end
    
    notifiedEggs[eggId] = tick()
    lastWebhookSent = tick()
    
    local name = eggInfo.Name or "Unknown Egg"
    local displayName = name:gsub("-", " "):gsub("^%l", string.upper)
    
    -- Get server info
    local playerCount = #Players:GetPlayers()
    local maxPlayers = Players.MaxPlayers
    local jobId = game.JobId
    
    -- Create formatted message
    local content = "**" .. displayName .. " Found!** :tada:\n" ..
                   "A 25X Luck " .. displayName .. " has been found! :rainbow:\n" ..
                   "Luck: x25\n" ..
                   "Server Slots: " .. playerCount .. "/" .. maxPlayers .. "\n" ..
                   "Job ID: " .. jobId .. "\n" ..
                   "Teleport Script: game:GetService(\"TeleportService\"):TeleportToPlaceInstance(" .. PLACE_ID .. ", \"" .. jobId .. "\", game.Players.LocalPlayer)"
    
    -- Send webhook with error handling
    local success = false
    local attempts = 0
    
    while not success and attempts < 3 do
        attempts = attempts + 1
        
        success = pcall(function()
            HttpService:PostAsync(
                DISCORD_WEBHOOK_URL,
                HttpService:JSONEncode({ ["content"] = content }),
                Enum.HttpContentType.ApplicationJson,
                false
            )
        end)
        
        if success then
            print("Discord notification sent successfully for: " .. name)
        else
            print("Webhook send failed, attempt " .. attempts .. "/3")
            wait(1)
            
            -- On final attempt, use simplified payload
            if attempts == 2 then
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

-- Enhanced tween to egg location with retry mechanism
local function tweenToEgg(egg)
    if not egg then 
        print("No egg provided to tweenToEgg function")
        return false 
    end
    
    print("Tweening to egg: " .. egg.Name)
    
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
    
    -- Retry loop for tweening
    local retryCount = 0
    local tweenSuccess = false
    
    while not tweenSuccess and retryCount < maxTweenRetries do
        retryCount = retryCount + 1
        print("Tween attempt " .. retryCount .. "/" .. maxTweenRetries)
        
        -- Clean up previous CFrameValue
        if currentCFrameValue then
            pcall(function() currentCFrameValue:Destroy() end)
            currentCFrameValue = nil
        end
        
        -- Create new CFrameValue
        local CFrameValue = Instance.new("CFrameValue")
        currentCFrameValue = CFrameValue
        CFrameValue.Value = humanoidRootPart.CFrame
        
        -- Connect property changed signal
        CFrameValue:GetPropertyChangedSignal("Value"):Connect(function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = CFrameValue.Value
            end
        end)
        
        -- Create target CFrame with offset to avoid getting stuck
        -- Use different offsets for different retry attempts
        local offset = Vector3.new(0, 6 + retryCount, 0)
        if retryCount > 1 then
            -- Add some random variation for subsequent attempts
            offset = offset + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
        end
        
        local targetCFrame = eggPart.CFrame + offset
        
        -- Create and play tween
        tweenSuccess = pcall(function()
            local tween = TweenService:Create(
                CFrameValue,
                TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
                {Value = targetCFrame}
            )
            
            tween:Play()
            tween.Completed:Wait()
        end)
        
        -- Check if we're close enough to consider it a success
        if LocalPlayer.Character and eggPart then
            local distance = (LocalPlayer.Character.HumanoidRootPart.Position - eggPart.Position).Magnitude
            if distance < 15 then
                tweenSuccess = true
                print("Tween successful - character is within range of egg")
            else
                print("Tween failed - character is too far from egg (distance: " .. math.floor(distance) .. ")")
                wait(1)
            end
        end
    end
    
    -- Clean up
    if currentCFrameValue then
        pcall(function() currentCFrameValue:Destroy() end)
        currentCFrameValue = nil
    end
    
    return tweenSuccess
end

-- Enhanced egg opening function with the new approach
local function openEgg(egg, amount)
    if not open_eggs or not egg then return false end
    
    amount = amount or egg_amount
    print("Opening egg: " .. egg.Name .. " x" .. amount)
    
    -- Try Framework approach (new integration)
    local success = pcall(function()
        local eggType = egg.Name or "Common Egg"
        local framework = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
            and game:GetService("ReplicatedStorage").Shared:FindFirstChild("Framework")
            and game:GetService("ReplicatedStorage").Shared.Framework:FindFirstChild("Network")
            and game:GetService("ReplicatedStorage").Shared.Framework.Network:FindFirstChild("Remote")
            and game:GetService("ReplicatedStorage").Shared.Framework.Network.Remote:FindFirstChild("Event")
        
        if framework then
            print("Using Framework.Network.Remote.Event approach to open eggs")
            for i = 1, amount do
                framework:FireServer("HatchEgg", eggType, 1)
                wait(0.2)
            end
            return true
        end
    end)
    
    if success then
        print("Successfully opened egg using Framework approach")
        return true
    end
    
    -- Try proximity prompt as fallback
    local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt")
    if prompt then
        for i = 1, amount do
            fireproximityprompt(prompt)
            wait(0.2)
        end
        return true
    end
    
    -- Try click detector as another fallback
    local clickDetector = egg:FindFirstChildWhichIsA("ClickDetector")
    if clickDetector then
        for i = 1, amount do
            fireclickdetector(clickDetector)
            wait(0.2)
        end
        return true
    end
    
    -- Try remote events as last resort
    for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
        if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
            local name = string.lower(remote.Name)
            if string.find(name, "egg") or string.find(name, "hatch") or string.find(name, "open") then
                for i = 1, amount do
                    pcall(function()
                        remote:FireServer(egg)
                        remote:FireServer(egg.Name)
                    end)
                    wait(0.2)
                end
                return true
            end
        end
    end
    
    return false
end

-- Alternative egg opening function using getgenv().Functions approach
local function useAutoHatchFunction(eggType)
    local success = pcall(function()
        if not getgenv().Functions then
            getgenv().Functions = {}
        end
        
        -- Set up the auto hatch function
        getgenv().Functions.AutoHatchEgg = true
        
        -- Run the auto hatch function for a short period
        task.spawn(function()
            while getgenv().Functions.AutoHatchEgg do
                task.wait()
                -- Try to trigger the egg hatch event
                game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("Event"):FireServer("HatchEgg", eggType or "Common Egg", 1)
                task.wait(0.2)  -- Small delay between hatches
            end
        end)
        
        -- Run for a few seconds then turn off
        task.delay(3, function()
            getgenv().Functions.AutoHatchEgg = false
        end)
    end)
    
    return success
end

-- Improved server hopping function
local function hopToNextServer()
    if tick() - lastTeleport < teleportCooldown then 
        print("Teleport on cooldown, waiting...")
        return false 
    end
    
    -- Don't hop if we found an egg recently
    if eggFoundRecently then
        print("Priority egg found recently, staying in current server")
        return false
    end
    
    print("Finding new server...")
    
    -- Get server list with error handling
    local success, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=100"
        ))
    end)
    
    if not success or not result or not result.data then
        print("Error fetching server list")
        wait(3)
        return false
    end
    
    local servers = {}
    
    -- Filter and score servers
    for _, server in pairs(result.data) do
        if type(server) == "table" and server.id and server.playing and server.maxPlayers then
            if server.playing < server.maxPlayers and server.playing > 0 and not visitedServers[server.id] then
                -- Score servers (prefer 3-8 players)
                local score = 100 - math.abs(5 - server.playing) * 10
                table.insert(servers, {server = server, score = score})
            end
        end
    end
    
    print("Found " .. #servers .. " valid servers to hop to")
    
    -- Sort by score and select server
    if #servers > 0 then
        table.sort(servers, function(a, b) return a.score > b.score end)
        local selectedIndex = math.random(1, math.min(3, #servers))
        local selectedServer = servers[selectedIndex].server
        
        if selectedServer and selectedServer.id then
            lastTeleport = tick()
            visitedServers[selectedServer.id] = true
            
            print("Teleporting to server: " .. selectedServer.id .. " with " .. selectedServer.playing .. " players")
            
            local teleportSuccess = pcall(function()
                TeleportService:TeleportToPlaceInstance(PLACE_ID, selectedServer.id, LocalPlayer)
            end)
            
            if teleportSuccess then
                print("Teleport request sent successfully")
                wait(5)
                return true
            else
                print("Teleport failed, retrying in 3 seconds...")
                wait(3)
            end
        end
    else
        print("No suitable servers found, clearing visited servers list")
        visitedServers = {}
    end
    
    wait(2)
    return false
end

-- Create UI
local function createUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "EggFinderGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    
    -- Main frame
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 240, 0, 100)
    frame.Position = UDim2.new(0.5, -120, 0.02, 0)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 2
    frame.BorderColor3 = Color3.fromRGB(255, 215, 0)
    frame.Parent = screenGui
    
    -- Corner radius
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
    title.Text = "25x Priority Egg Finder"
    title.Parent = frame
    
    -- Status
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, 0, 0.25, 0)
    status.Position = UDim2.new(0, 0, 0.3, 0)
    status.BackgroundTransparency = 1
    status.TextColor3 = Color3.fromRGB(255, 255, 255)
    status.Font = Enum.Font.Gotham
    status.TextSize = 14
    status.Text = "Scanning for eggs..."
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
    
    -- Update UI function
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
                status.Text = "Scanning for 25x eggs..."
                
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
    
    return screenGui
end

-- Main function
local function main()
    print("------- 25x Priority Egg Finder Started -------")
    createUI()
    
    while wait(1) do
        -- Check if we need to server hop based on time in server
        local timeInServer = tick() - initialServerTime
        if timeInServer > maxServerSearchTime and not eggFoundRecently then
            print("Max time in server reached, preparing to hop")
            hopToNextServer()
            initialServerTime = tick()
            continue
        end
        
        -- Scan for 25x lucky eggs
        local luckyEggs = findLuckyEggs()
        
        -- Handle found eggs
        if #luckyEggs > 0 then
            eggFoundRecently = true
            lastEggFoundTime = tick()
            initialServerTime = tick() -- Reset timer when eggs are found
            
            -- Process each found egg with priority
            for _, egg in ipairs(luckyEggs) do
                -- Notify about the egg
                sendWebhook(egg)
                
                -- Tween to the egg with retry logic
                local tweenSuccess = tweenToEgg(egg)
                wait(1)
                
                -- Try to open it using all available methods
                if tweenSuccess then
                    -- Try the regular egg opening first
                    local openSuccess = openEgg(egg, egg_amount)
                    
                    -- If that fails, try the getgenv approach
                    if not openSuccess then
                        print("Regular egg opening failed, trying Alternative method...")
                        useAutoHatchFunction(egg.Name)
                    end
                else
                    print("All tween attempts failed, trying direct interaction")
                    openEgg(egg, egg_amount)
                    -- Also try the alternative method as a last resort
                    useAutoHatchFunction(egg.Name)
                end
                
                wait(2)
            end
        elseif eggFoundRecently and (tick() - lastEggFoundTime) > 60 then
            -- Reset egg found flag after 60 seconds of no new eggs
            eggFoundRecently = false
        end
    end
end

-- Start the script with error handling
spawn(function()
    while true do
        local success, errorMsg = pcall(main)
        if not success then
            print("Error: " .. tostring(errorMsg))
            wait(5)
        end
    end
end)

print("🚀 25x Priority Egg Finder initialized")
