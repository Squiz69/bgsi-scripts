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
local tweenSpeed = 4.0          -- Speed for tweening to eggs

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

-- Enhanced play button function with multiple approaches
local function pressPlayButtons()
    print("Looking for play buttons...")
    wait(1)
    
    -- First approach: Direct pattern matching
    local function findAndClickByPattern()
        for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if (gui:IsA("TextButton") or gui:IsA("ImageButton")) then
                local text = ""
                if gui:IsA("TextButton") then
                    text = gui.Text:lower()
                elseif gui:FindFirstChild("TextLabel") then
                    text = gui:FindFirstChild("TextLabel").Text:lower()
                end
                
                for _, keyword in pairs({"play", "start", "enter", "join", "continue", "ok"}) do
                    if string.find(text, keyword) then
                        -- Try multiple click methods
                        pcall(function() gui:CaptureFocus() end)
                        pcall(function() gui.MouseButton1Click:Fire() end)
                        pcall(function() firesignal(gui.MouseButton1Click) end)
                        pcall(function() gui.Activated:Fire() end)
                        pcall(function() gui:Activate() end)
                        wait(0.5)
                        return true
                    end
                end
            end
        end
        return false
    end
    
    -- Second approach: Use virtual input system
    local function simulateClick()
        local VirtualUser = game:GetService("VirtualUser")
        for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if (gui:IsA("TextButton") or gui:IsA("ImageButton")) and gui.Visible then
                local text = ""
                if gui:IsA("TextButton") then
                    text = gui.Text:lower()
                elseif gui:FindFirstChild("TextLabel") then
                    text = gui:FindFirstChild("TextLabel").Text:lower()
                end
                
                for _, keyword in pairs({"play", "start", "enter", "join", "continue", "ok"}) do
                    if string.find(text, keyword) then
                        local position = gui.AbsolutePosition + gui.AbsoluteSize/2
                        pcall(function()
                            VirtualUser:SetKeyDown("0")
                            VirtualUser:SetKeyUp("0")
                            VirtualUser:Button1Down(position, workspace.CurrentCamera.CFrame)
                            wait(0.1)
                            VirtualUser:Button1Up(position, workspace.CurrentCamera.CFrame)
                        end)
                        wait(0.5)
                        return true
                    end
                end
            end
        end
        return false
    end
    
    -- Third approach: Fire remote events
    local function firePlayRemotes()
        for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
            if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
                local name = remote.Name:lower()
                for _, keyword in pairs({"play", "start", "enter", "join", "teleport", "loadgame"}) do
                    if string.find(name, keyword) then
                        pcall(function() remote:FireServer() end)
                        wait(0.5)
                        return true
                    end
                end
            end
        end
        return false
    end
    
    -- Try all methods
    local success = findAndClickByPattern()
    if not success then success = simulateClick() end
    if not success then success = firePlayRemotes() end
    
    -- Quality settings buttons
    wait(1)
    findAndClickByPattern() -- Try again for quality settings
    
    wait(2)
    return success
end

-- Completely redesigned egg detection function
local function findLuckyEgg()
    print("Scanning for 25x lucky " .. egg_priority .. " egg...")
    
    -- Multiple detection methods
    local function checkEggByProximity()
        local character = LocalPlayer.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then return nil end
        
        local hrp = character.HumanoidRootPart
        local nearbyEggs = {}
        
        -- Collect all nearby objects
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
        
        -- Check for priority egg
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
        end
        
        return nil
    end
    
    -- Check by global GUI indicators
    local function checkEggByGUI()
        for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if gui:IsA("TextLabel") or gui:IsA("TextButton") then
                local text = gui.Text:lower()
                
                -- Check for luck indicators along with egg name
                if (string.find(text, "25x") or string.find(text, "x25")) and
                   (string.find(text, egg_priority:lower()) or string.find(text, "egg")) then
                    
                    -- Look for nearby eggs
                    local character = LocalPlayer.Character
                    if character and character:FindFirstChild("HumanoidRootPart") then
                        local hrp = character.HumanoidRootPart
                        
                        for _, object in pairs(workspace:GetDescendants()) do
                            if object:IsA("BasePart") then
                                local distance = (hrp.Position - object.Position).Magnitude
                                if distance <= 50 and 
                                   (string.find(object.Name:lower(), "egg") or 
                                    string.find(object.Name:lower(), egg_priority:lower())) then
                                    return object, 25
                                end
                            end
                        end
                    end
                end
            end
        end
        
        return nil
    end
    
    -- Check for attributes and special properties
    local function checkEggByAttributes()
        for _, object in pairs(workspace:GetDescendants()) do
            if string.find(object.Name:lower(), egg_priority:lower()) or 
               string.find(object.Name:lower(), "egg") then
                
                -- Check for luck attributes
                for _, attrName in pairs({"Luck", "LuckMultiplier", "Multiplier", "Boost"}) do
                    local value = object:GetAttribute(attrName)
                    if value and type(value) == "number" and value >= 25 then
                        return object, value
                    end
                end
                
                -- Check for value objects
                for _, child in pairs(object:GetChildren()) do
                    if child:IsA("IntValue") or child:IsA("NumberValue") then
                        if string.find(child.Name:lower(), "luck") or 
                           string.find(child.Name:lower(), "multi") then
                            if child.Value >= 25 then
                                return object, child.Value
                            end
                        end
                    end
                end
            end
        end
        
        return nil
    end
    
    -- Try all methods
    local egg, luck = checkEggByProximity()
    if egg then return egg, luck end
    
    egg, luck = checkEggByGUI()
    if egg then return egg, luck end
    
    egg, luck = checkEggByAttributes()
    if egg then return egg, luck end
    
    return nil
end

-- Completely redesigned webhook function
local function sendDiscordNotification(eggInfo, eggLuck)
    if not eggInfo or tick() - lastWebhookSent < webhookCooldown then return false end
    
    -- Safety check to prevent redundant notifications
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
    
    -- Get player position/height
    local height = "Unknown"
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        height = math.floor(LocalPlayer.Character.HumanoidRootPart.Position.Y) .. "m"
    end
    
    -- Create teleport script
    local eggType = eggInfo.Name or "Unknown Egg"
    local teleportScript = 'game:GetService("TeleportService"):TeleportToPlaceInstance(' .. 
                         tostring(PLACE_ID) .. ', "' .. jobId .. '", game.Players.LocalPlayer)'
    
    -- Calculate timestamp
    local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    
    -- Create an enhanced webhook with more reliable formatting
    local webhookData = {
        username = "25x Egg Finder",
        avatar_url = "https://i.imgur.com/XQQbAPn.png", -- Egg icon
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
                    {name = "⏱️ Time Remaining", value = "~60 seconds", inline = true},
                    {name = "👤 Found By", value = censoredName, inline = true},
                    {name = "🆔 Job ID", value = "```" .. jobId .. "```", inline = false},
                    {name = "🚀 Teleport Script", value = "```lua\n" .. teleportScript .. "\n```", inline = false}
                },
                footer = {text = "25x Priority Egg Finder v4.1"},
                timestamp = timestamp
            }
        }
    }
    
    -- Send webhook with multiple retries and fallback methods
    local function attemptWebhookSend()
        local success = pcall(function()
            HttpService:PostAsync(
                DISCORD_WEBHOOK_URL,
                HttpService:JSONEncode(webhookData),
                Enum.HttpContentType.ApplicationJson,
                false
            )
        end)
        return success
    end
    
    -- Try alternative formatting if first attempt fails
    local function tryAlternativeFormat()
        -- Simpler format
        local simpleData = {
            content = "**25X LUCK " .. eggType .. " FOUND!**\nServer: " .. jobId .. 
                     "\nPlayers: " .. playerCount .. "/" .. maxPlayers .. 
                     "\nTeleport: ```lua\n" .. teleportScript .. "\n```"
        }
        
        return pcall(function()
            HttpService:PostAsync(
                DISCORD_WEBHOOK_URL,
                HttpService:JSONEncode(simpleData),
                Enum.HttpContentType.ApplicationJson,
                false
            )
        end)
    end
    
    -- Try sending with multiple methods
    for attempt = 1, 3 do
        if attemptWebhookSend() then
            print("Discord notification sent successfully for: " .. eggType)
            return true
        else
            print("Webhook attempt " .. attempt .. " failed, retrying...")
            wait(1)
        end
    end
    
    -- Try alternative format as last resort
    if tryAlternativeFormat() then
        print("Discord notification sent with alternative format")
        return true
    end
    
    print("All webhook attempts failed!")
    return false
end

-- Optimized tween movement function
local function tweenToEgg(egg)
    if not egg then return false end
    
    print("Tweening to priority egg: " .. egg.Name)
    
    -- Find the part to tween to
    local eggPart
    if egg:IsA("BasePart") or egg:IsA("MeshPart") then
        eggPart = egg
    else
        eggPart = egg:FindFirstChildWhichIsA("BasePart") or egg:FindFirstChildWhichIsA("MeshPart")
        
        if not eggPart then
            for _, child in pairs(egg:GetDescendants()) do
                if child:IsA("BasePart") or child:IsA("MeshPart") then
                    eggPart = child
                    break
                end
            end
        end
    end
    
    if not eggPart then 
        print("No valid part found to tween to")
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
    
    -- Create tween to egg position
    local targetPosition = eggPart.Position + Vector3.new(0, 3, 0)
    local distance = (targetPosition - humanoidRootPart.Position).Magnitude
    
    local tweenInfo = TweenInfo.new(
        distance / (100 * tweenSpeed),
        Enum.EasingStyle.Linear
    )
    
    currentTween = TweenService:Create(humanoidRootPart, tweenInfo, {
        CFrame = CFrame.new(targetPosition)
    })
    
    currentTween:Play()
    currentTween.Completed:Wait()
    currentTween = nil
    
    print("Arrived at priority egg")
    return true
end

-- Enhanced egg opening function with multiple approaches
local function openEgg(egg, amount)
    if not open_eggs or not egg then return end
    
    amount = amount or egg_amount
    print("Opening egg: " .. egg.Name .. " x" .. amount)
    
    -- Try proximity prompt
    local function tryProximityPrompt()
        local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt")
        if prompt then
            for i = 1, amount do
                fireproximityprompt(prompt)
                wait(0.2)
            end
            return true
        end
        return false
    end
    
    -- Try click detector
    local function tryClickDetector()
        local clickDetector = egg:FindFirstChildWhichIsA("ClickDetector")
        if clickDetector then
            for i = 1, amount do
                fireclickdetector(clickDetector)
                wait(0.2)
            end
            return true
        end
        return false
    end
    
    -- Try remote events
    local function tryRemoteEvents()
        local remotePatterns = {
            {name = "OpenEgg", args = {egg}},
            {name = "HatchEgg", args = {egg.Name, amount}},
            {name = "PurchaseEgg", args = {egg.Name}},
            {name = "BuyEgg", args = {egg.Name, amount}},
            {name = "Hatch", args = {}},
            {name = "Open", args = {egg}},
            {name = "CollectEgg", args = {egg}}
        }
        
        for _, pattern in ipairs(remotePatterns) do
            table.insert(remotePatterns, {name = pattern.name, args = {egg.Name}})
        end
        
        local success = false
        for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
            if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
                for _, pattern in ipairs(remotePatterns) do
                    if string.find(string.lower(remote.Name), string.lower(pattern.name)) then
                        for i = 1, amount do
                            pcall(function()
                                remote:FireServer(unpack(pattern.args))
                                success = true
                            end)
                            wait(0.2)
                        end
                    end
                end
            end
        end
        return success
    end
    
    -- Try virtual input
    local function tryVirtualInput()
        local VirtualUser = game:GetService("VirtualUser")
        if egg:IsA("BasePart") then
            for i = 1, amount do
                pcall(function()
                    local position = egg.Position
                    VirtualUser:SetKeyDown("0")
                    VirtualUser:SetKeyUp("0")
                    VirtualUser:Button1Down(Vector2.new(position.X, position.Y), workspace.CurrentCamera.CFrame)
                    wait(0.1)
                    VirtualUser:Button1Up(Vector2.new(position.X, position.Y), workspace.CurrentCamera.CFrame)
                end)
                wait(0.2)
            end
            return true
        end
        return false
    end
    
    -- Try all methods
    local success = tryProximityPrompt()
    if not success then success = tryClickDetector() end
    if not success then success = tryRemoteEvents() end
    if not success then success = tryVirtualInput() end
    
    return success
end

-- Efficient server hopping
local function getRandomServer()
    local servers = {}
    local pageSize = 100
    local baseUrl = "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=" .. pageSize
    
    local success, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(baseUrl))
    end)
    
    if success and result and result.data then
        for _, server in ipairs(result.data) do
            if server.playing < server.maxPlayers and server.playing > 0 and not visitedServers[server.id] then
                table.insert(servers, server)
            end
        end
    end

    if #servers > 0 then
        -- Score servers (prefer 3-8 players)
        table.sort(servers, function(a, b)
            local scoreA = 100 - math.abs(5 - a.playing) * 10
            local scoreB = 100 - math.abs(5 - b.playing) * 10
            return scoreA > scoreB
        end)
        
        return servers[math.random(1, math.min(3, #servers))]
    end

    -- Clean up visited servers list if it gets too large
    if table.getn(visitedServers) > 50 then
        visitedServers = {}
    end

    return nil
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
    local nextServer = getRandomServer()
    
    if nextServer then
        lastTeleport = tick()
        visitedServers[nextServer.id] = true
        
        print("Teleporting to server: " .. nextServer.id)
        
        local success = pcall(function()
            TeleportService:TeleportToPlaceInstance(PLACE_ID, nextServer.id, LocalPlayer)
        end)
        
        return success
    end
    
    wait(2)
    return false
end

-- Main script loop
local function mainLoop()
    if isSearching then return end
    isSearching = true
    
    print("------- 25x Priority Egg Finder v4.1 Started -------")
    print("Priority egg: " .. egg_priority)
    
    -- Initialize timers
    initialServerTime = tick()
    serverSearchTime = tick()
    
    -- Press play buttons when entering game
    pressPlayButtons()
    wait(1)
    
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
                
                -- Send notification
                local webhookSuccess = sendDiscordNotification(foundEgg, luckValue)
                
                -- Try a different approach if webhook failed
                if not webhookSuccess then
                    print("First webhook attempt failed, trying alternative approach")
                    wait(1)
                    sendDiscordNotification(foundEgg, luckValue)
                end
                
                -- Tween to the egg
                tweenToEgg(foundEgg)
                
                -- Try to open the egg
                openEgg(foundEgg, egg_amount)
                
                -- Reset timers
                initialServerTime = tick()
                serverSearchTime = tick()
                wait(1)
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
                    wait(1)
                end
            elseif eggFoundRecently and (tick() - lastEggFoundTime) > 60 then
                -- Reset egg found flag after 60 seconds
                eggFoundRecently = false
            end
        end
    end
    
    isSearching = false
end

-- Simplified UI
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
title.Text = "25x Priority Egg Finder v4.1"
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

print("🚀 25x Priority Egg Finder v4.1 initialized")
