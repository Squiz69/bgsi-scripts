local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Configuration
local DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1363054781882699910/Qwa5roGAv5rj83wBwCG7BzraXD8xOc7L-eeopKGdvCSug1GhdJzx6sRRNA1tjgmbRW34"
local PLACE_ID = 85896571713843
local egg_priority = "event-1"
local egg_amount = 3
local open_eggs = true
local maxServerSearchTime = 10  -- Changed to 10 seconds
local tweenSpeed = 4.0  -- Increased for faster movement

-- Script variables
local visitedServers = {}
local lastTeleport = 0
local teleportCooldown = 5
local notifiedEggs = {}
local serverSearchTime = 0
local currentTween = nil
local isSearching = false

-- Prioritized list of hatchable eggs
local hatchable_eggs = {
    "event-1", 
    "event-2",
    "rainbow-egg",
    "void-egg",
    "nightmare-egg", 
    "aura-egg"
}

-- Press play button and then optimized button when entering game
local function pressPlayButtons()
    print("Looking for play and optimized buttons...")
    wait(3)
    
    local buttons = {}
    
    if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
        for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if gui:IsA("TextButton") then
                local buttonText = string.lower(gui.Text)
                if buttonText:match("play") or buttonText:match("start") then
                    table.insert(buttons, {button = gui, priority = 1})
                elseif buttonText:match("optimized") or buttonText:match("optimize") then
                    table.insert(buttons, {button = gui, priority = 2})
                end
            end
        end
    end
    
    -- Sort by priority (play first, then optimized)
    table.sort(buttons, function(a, b)
        return a.priority < b.priority
    end)
    
    for _, buttonInfo in ipairs(buttons) do
        pcall(function()
            buttonInfo.button.MouseButton1Click:Fire()
        end)
        wait(0.5)
    end
end

-- Improved Discord webhook notification function with better error handling
local function sendDiscordNotification(eggInfo, eggLuck)
    if not eggInfo then return end
    
    local jobId = game.JobId
    local currentPlayers = #Players:GetPlayers()
    local maxPlayers = Players.MaxPlayers
    
    -- Player info with privacy
    local playerName = LocalPlayer.Name
    local censoredName = string.sub(playerName, 1, 1) .. "***" .. string.sub(playerName, -1)
    
    -- Get height position
    local height = "Unknown"
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        height = math.floor(LocalPlayer.Character.HumanoidRootPart.Position.Y) .. "m"
    end
    
    -- Determine egg type
    local eggType = eggInfo.Name or "Unknown Egg"
    
    -- Create teleport script
    local teleportScript = 'game:GetService("TeleportService"):TeleportToPlaceInstance(' .. 
                          tostring(PLACE_ID) .. ', "' .. jobId .. '", game.Players.LocalPlayer)'
    
    -- Calculate time remaining
    local timeRemaining = "~30 seconds"
    
    -- Create webhook content
    local webhookData = {
        embeds = {
            {
                title = "🔥 25X Luck Egg Found 🔥",
                description = "A rare egg with 25X Luck has been discovered! Join quickly!",
                color = 16776960,
                fields = {
                    {name = "🥚 Egg Type", value = eggType, inline = true},
                    {name = "✨ Luck Multiplier", value = "x" .. tostring(eggLuck or 25), inline = true},
                    {name = "📏 Height", value = height, inline = true},
                    {name = "👥 Server Slots", value = currentPlayers .. "/" .. maxPlayers, inline = true},
                    {name = "⏱️ Time Remaining", value = timeRemaining, inline = true},
                    {name = "👤 Found By", value = censoredName, inline = true},
                    {name = "🆔 Job ID", value = "```" .. jobId .. "```", inline = false},
                    {name = "🚀 Teleport Script", value = "```lua\n" .. teleportScript .. "\n```", inline = false}
                },
                footer = {text = "25x Egg Finder v3.2"}
            }
        }
    }
    
    -- Send webhook with retries
    spawn(function()
        for attempt = 1, 3 do
            local success = pcall(function()
                HttpService:PostAsync(
                    DISCORD_WEBHOOK_URL,
                    HttpService:JSONEncode(webhookData),
                    Enum.HttpContentType.ApplicationJson,
                    false
                )
            end)
            
            if success then
                print("Discord notification sent for: " .. eggType)
                return
            else
                print("Webhook attempt " .. attempt .. " failed, retrying...")
                wait(1)
            end
        end
    end)
end

-- Optimized egg detection focused specifically on 25x luck
local function findLuckyEgg()
    print("Scanning for 25x lucky eggs...")
    
    -- Fast scan for luck attributes
    local function scanForLuckEggs(parent, depth)
        if depth > 4 then return {} end
        
        local foundEggs = {}
        
        for _, obj in pairs(parent:GetChildren()) do
            if obj ~= Players and obj.Name ~= "Players" then
                -- First, check direct attributes for performance
                local hasLuckAttribute = false
                local luckValue = nil
                
                -- Direct attribute checks (fastest)
                for _, attrName in ipairs({"Luck", "LuckMultiplier", "Multiplier"}) do
                    local value = obj:GetAttribute(attrName)
                    if value and type(value) == "number" and value >= 25 then
                        luckValue = value
                        hasLuckAttribute = true
                        break
                    end
                end
                
                -- Check if it has egg in name
                local isEgg = false
                if hasLuckAttribute or string.find(string.lower(obj.Name), "egg") then
                    isEgg = true
                    
                    -- Check for priority eggs
                    for _, eggName in pairs(hatchable_eggs) do
                        if string.find(string.lower(obj.Name), string.lower(eggName)) then
                            isEgg = true
                            break
                        end
                    end
                end
                
                if isEgg then
                    -- If we didn't find luck value in attributes, check value objects
                    if not luckValue then
                        for _, valueName in ipairs({"LuckValue", "MultiplierValue", "Luck"}) do
                            local valueObj = obj:FindFirstChild(valueName)
                            if valueObj and valueObj:IsA("ValueBase") and valueObj.Value >= 25 then
                                luckValue = valueObj.Value
                                break
                            end
                        end
                    end
                    
                    -- Check for UI elements with luck indicators
                    if not luckValue then
                        for _, child in pairs(obj:GetDescendants()) do
                            if child:IsA("TextLabel") or child:IsA("TextButton") then
                                local text = string.lower(child.Text)
                                local multiplierMatch = text:match("(%d+)%s*x%s*luck") or text:match("x%s*(%d+)%s*luck")
                                
                                if multiplierMatch then
                                    local value = tonumber(multiplierMatch)
                                    if value and value >= 25 then
                                        luckValue = value
                                        break
                                    end
                                end
                            end
                        end
                    end
                    
                    -- If we found a luck value of 25+, add it to results
                    if luckValue and luckValue >= 25 then
                        local isPriority = false
                        for _, name in pairs(hatchable_eggs) do
                            if string.find(string.lower(obj.Name), string.lower(name)) then
                                isPriority = (string.lower(name) == string.lower(egg_priority))
                                if isPriority then break end
                            end
                        end
                        
                        table.insert(foundEggs, {
                            Egg = obj,
                            LuckValue = luckValue,
                            IsPriority = isPriority
                        })
                        
                        print("Found luck egg: " .. obj.Name .. " with " .. luckValue .. "x luck")
                        
                        -- Return immediately if it's the priority egg
                        if isPriority then
                            return {foundEggs[#foundEggs]}
                        end
                    end
                end
                
                -- Recursively check children (with depth limit)
                local childResults = scanForLuckEggs(obj, depth + 1)
                for _, result in ipairs(childResults) do
                    table.insert(foundEggs, result)
                    
                    -- Return immediately if we found a priority egg
                    if result.IsPriority then
                        return {result}
                    end
                end
            end
        end
        
        return foundEggs
    end
    
    -- Perform the scan
    local results = scanForLuckEggs(workspace, 0)
    
    -- Sort results by priority then luck value
    table.sort(results, function(a, b)
        if a.IsPriority and not b.IsPriority then
            return true
        elseif not a.IsPriority and b.IsPriority then
            return false
        else
            return (a.LuckValue or 0) > (b.LuckValue or 0)
        end
    end)
    
    -- Return the best egg found
    if #results > 0 then
        local bestResult = results[1]
        return bestResult.Egg, bestResult.LuckValue
    end
    
    return nil
end

-- Faster tween movement
local function tweenToEgg(egg)
    if not egg then return end
    
    print("Tweening to egg: " .. egg.Name)
    
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
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoidRootPart or not humanoid then return end
    
    -- Cancel any existing tween
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    
    -- Direct high-speed tween to target
    local targetPosition = eggPart.Position + Vector3.new(0, 5, 0)
    local distance = (targetPosition - humanoidRootPart.Position).Magnitude
    
    -- Fast tween directly to target
    local tweenInfo = TweenInfo.new(
        distance / (100 * tweenSpeed), -- Much faster movement
        Enum.EasingStyle.Linear
    )
    
    currentTween = TweenService:Create(humanoidRootPart, tweenInfo, {
        CFrame = CFrame.new(targetPosition)
    })
    
    currentTween:Play()
    currentTween.Completed:Wait()
    currentTween = nil
    
    print("Arrived at egg")
end

-- Streamlined egg opening function
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
        return
    end
    
    -- Try click detector
    local clickDetector = egg:FindFirstChildWhichIsA("ClickDetector")
    if clickDetector then
        for i = 1, amount do
            fireclickdetector(clickDetector)
            wait(0.2)
        end
        return
    end
    
    -- Common remote patterns
    local remotePatterns = {
        {name = "OpenEgg", args = {egg}},
        {name = "HatchEgg", args = {egg.Name, amount}},
        {name = "PurchaseEgg", args = {egg.Name}},
        {name = "BuyEgg", args = {egg.Name, amount}},
        {name = "Hatch", args = {}},
        {name = "Open", args = {egg}},
        {name = "CollectEgg", args = {egg}},
        {name = "GetEgg", args = {egg.Name}}
    }
    
    -- Try with egg name string
    for _, pattern in ipairs(remotePatterns) do
        table.insert(remotePatterns, {name = pattern.name, args = {egg.Name}})
    end
    
    -- Find and fire remotes
    for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
        if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
            for _, pattern in ipairs(remotePatterns) do
                if string.find(remote.Name:lower(), pattern.name:lower()) then
                    for i = 1, amount do
                        pcall(function()
                            remote:FireServer(unpack(pattern.args))
                        end)
                        wait(0.2)
                    end
                end
            end
        end
    end
end

-- Efficient server hopping
local function getRandomServer()
    local servers = {}
    local pageSize = 100
    local baseUrl = "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=" .. pageSize
    
    -- Get one page of servers
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
        for i, server in ipairs(servers) do
            local playerCount = server.playing
            local score = 100 - math.abs(5 - playerCount) * 10
            server.score = score
        end
        
        table.sort(servers, function(a, b)
            return a.score > b.score
        end)
        
        return servers[math.random(1, math.min(3, #servers))]
    end

    if table.getn(visitedServers) > 50 then
        visitedServers = {}
    end

    return nil
end

-- Quick server hop
local function hopToNextServer()
    if tick() - lastTeleport < teleportCooldown then return false end
    
    print("Finding new server...")
    local nextServer = getRandomServer()
    
    if nextServer then
        lastTeleport = tick()
        visitedServers[nextServer.id] = true
        
        print("Teleporting to: " .. nextServer.id)
        
        local success = pcall(function()
            TeleportService:TeleportToPlaceInstance(PLACE_ID, nextServer.id, LocalPlayer)
        end)
        
        return success
    end
    
    wait(2)
    return false
end

-- Optimized main loop
local function mainLoop()
    if isSearching then return end
    isSearching = true
    
    print("------- 25x Egg Finder v3.2 Started -------")
    print("Priority egg: " .. egg_priority)
    pressPlayButtons()
    wait(2)
    serverSearchTime = tick()
    
    while wait(0.5) do
        local foundEgg, luckValue = findLuckyEgg()
        
        if foundEgg then
            -- Check if we've already notified about this egg
            local eggId = foundEgg.Name .. "_" .. tostring(foundEgg:GetFullName())
            
            if not notifiedEggs[eggId] or (tick() - notifiedEggs[eggId]) > 30 then
                notifiedEggs[eggId] = tick()
                
                print("Found 25x egg: " .. foundEgg.Name .. " with " .. tostring(luckValue) .. "x luck")
                
                sendDiscordNotification(foundEgg, luckValue)
                tweenToEgg(foundEgg)
                openEgg(foundEgg, egg_amount)
                
                serverSearchTime = tick()
                wait(1)
            end
        else
            -- Check if we've been searching too long in this server
            local searchTime = tick() - serverSearchTime
            
            if searchTime > maxServerSearchTime then
                print("Max search time reached (" .. maxServerSearchTime .. "s), hopping to next server")
                if hopToNextServer() then
                    wait(2)
                    serverSearchTime = tick()
                    notifiedEggs = {}
                    pressPlayButtons()
                    wait(2)
                end
            end
        end
    end
    
    isSearching = false
end

-- Minimal UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EggFinderGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

-- Main frame
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 220, 0, 70)
frame.Position = UDim2.new(0.5, -110, 0.95, -35)
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
title.Size = UDim2.new(1, 0, 0.5, 0)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Text = "25x Egg Finder v3.2"
title.Parent = frame

-- Status
local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, 0, 0.5, 0)
status.Position = UDim2.new(0, 0, 0.5, 0)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(255, 255, 255)
status.Font = Enum.Font.Gotham
status.TextSize = 14
status.Text = "Searching: " .. egg_priority
status.Parent = frame

-- Update status
spawn(function()
    while wait(0.5) do
        if not screenGui or not screenGui.Parent then return end
        
        local timeSpent = tick() - serverSearchTime
        local timeLeft = math.max(0, maxServerSearchTime - timeSpent)
        
        status.Text = egg_priority .. " - " .. math.floor(timeLeft) .. "s left"
        
        if timeLeft < 3 then
            status.TextColor3 = Color3.fromRGB(255, 100, 100)
        else
            status.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end
end)

-- Auto-restart on error
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
    while wait(10) do
        local currentTime = tick()
        if currentTime - serverSearchTime > 15 and isSearching then
            print("Script appears stalled, restarting...")
            isSearching = false
            serverSearchTime = currentTime
            wait(1)
            pcall(mainLoop)
        end
    end
end)

print("🚀 25x Egg Finder v3.2 initialized")
