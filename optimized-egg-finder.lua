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
local maxServerSearchTime = 10 -- Reduced to 10 seconds
local tweenSpeed = 4.0 -- Doubled for faster movement

-- Script variables
local visitedServers = {}
local lastTeleport = 0
local teleportCooldown = 5
local notifiedEggs = {}
local serverSearchTime = 0
local currentTween = nil
local isSearching = false
local islandSearchIndex = 1

-- Prioritized list of hatchable eggs
local hatchable_eggs = {
    "event-1", 
    "event-2",
    "rainbow-egg",
    "void-egg",
    "nightmare-egg", 
    "aura-egg"
}

-- Press play button and then optimize button when entering game
local function pressPlayAndOptimize()
    print("Looking for play button...")
    wait(1)
    
    local playButtons = {}
    
    if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
        for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if gui:IsA("TextButton") and (string.lower(gui.Text):match("play") or string.lower(gui.Text):match("start")) then
                table.insert(playButtons, gui)
            end
        end
    end
    
    for _, button in ipairs(playButtons) do
        pcall(function()
            button.MouseButton1Click:Fire()
        end)
        wait(0.5)
    end
    
    -- Wait briefly then look for optimize button
    wait(1)
    print("Looking for optimize button...")
    
    local optimizeButtons = {}
    
    if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
        for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if gui:IsA("TextButton") and (
                string.lower(gui.Text):match("optimize") or 
                string.lower(gui.Text):match("optimized") or
                string.lower(gui.Text):match("fast") or
                string.lower(gui.Text):match("performance")
            ) then
                table.insert(optimizeButtons, gui)
            end
        end
    end
    
    for _, button in ipairs(optimizeButtons) do
        pcall(function()
            button.MouseButton1Click:Fire()
        end)
        wait(0.5)
    end
end

-- Fixed Discord webhook notification function
local function sendDiscordNotification(eggInfo, eggLuck)
    if not eggInfo then return end
    
    local jobId = game.JobId
    local currentPlayers = #Players:GetPlayers()
    local maxPlayers = Players.MaxPlayers
    
    -- Basic player info
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
    
    -- Create webhook content with minimal formatting
    local webhookData = {
        embeds = {
            {
                title = "🔥 25X Luck Egg Found 🔥",
                description = "A rare egg with 25X Luck has been discovered! Join quickly!",
                color = 16776960,
                fields = {
                    {name = "Egg Type", value = eggType, inline = true},
                    {name = "Luck Multiplier", value = "x" .. tostring(eggLuck or 25), inline = true},
                    {name = "Height", value = height, inline = true},
                    {name = "Server Slots", value = currentPlayers .. "/" .. maxPlayers, inline = true},
                    {name = "Found By", value = censoredName, inline = true},
                    {name = "Job ID", value = "```" .. jobId .. "```", inline = false},
                    {name = "Teleport Script", value = "```lua\n" .. teleportScript .. "\n```", inline = false}
                }
            }
        }
    }
    
    -- Send webhook with simplified error handling
    spawn(function()
        pcall(function()
            HttpService:PostAsync(
                DISCORD_WEBHOOK_URL,
                HttpService:JSONEncode(webhookData),
                Enum.HttpContentType.ApplicationJson,
                false
            )
        end)
    end)
end

-- Optimized egg detection to focus on prioritized eggs and islands
local function findLuckyEgg()
    print("Searching for 25x lucky eggs in islands...")
    
    -- Find all islands in workspace
    local islands = {}
    
    -- Look for common island-related objects
    for _, obj in pairs(workspace:GetChildren()) do
        if obj:IsA("Model") or obj:IsA("Folder") then
            if string.lower(obj.Name):match("island") or
               string.lower(obj.Name):match("zone") or
               string.lower(obj.Name):match("area") or
               string.lower(obj.Name):match("world") then
                table.insert(islands, obj)
            end
        end
    end
    
    -- If no islands found, use workspace as fallback
    if #islands == 0 then
        islands = {workspace}
    end
    
    -- If islandSearchIndex is beyond the number of islands, reset it
    if islandSearchIndex > #islands then
        islandSearchIndex = 1
    end
    
    -- Get the next island to search
    local currentIsland = islands[islandSearchIndex]
    islandSearchIndex = islandSearchIndex + 1
    
    print("Searching island: " .. currentIsland.Name .. " (" .. islandSearchIndex - 1 .. "/" .. #islands .. ")")
    
    -- Function to scan for eggs with luck traits
    local function scanForEggs(parent, depth)
        if depth > 3 then return nil end -- Limit depth to improve performance
        
        for _, obj in pairs(parent:GetChildren()) do
            -- Skip players
            if obj ~= Players and obj.Name ~= "Players" then
                -- Check if this object is a potential egg
                local nameCheck = string.find(string.lower(obj.Name), "egg") ~= nil
                for _, eggName in pairs(hatchable_eggs) do
                    if string.find(string.lower(obj.Name), string.lower(eggName)) then
                        nameCheck = true
                        break
                    end
                end
                
                if nameCheck and (obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("MeshPart")) then
                    -- Check for luck attributes
                    local luckValue = nil
                    
                    -- Direct attribute checks
                    for _, attrName in ipairs({"Luck", "LuckMultiplier", "Multiplier", "Boost", "Bonus"}) do
                        local value = obj:GetAttribute(attrName)
                        if value and type(value) == "number" and value >= 25 then
                            return obj, value
                        end
                    end
                    
                    -- Value object checks
                    for _, valueName in ipairs({"LuckValue", "MultiplierValue", "Luck", "Multiplier", "Boost"}) do
                        local valueObj = obj:FindFirstChild(valueName)
                        if valueObj and valueObj:IsA("ValueBase") and valueObj.Value >= 25 then
                            return obj, valueObj.Value
                        end
                    end
                    
                    -- UI text checks for luck indicators
                    for _, child in ipairs(obj:GetDescendants()) do
                        if child:IsA("TextLabel") or child:IsA("TextButton") then
                            local text = string.lower(child.Text)
                            local multiplierMatch = text:match("(%d+)%s*x%s*luck") or text:match("x%s*(%d+)%s*luck")
                            if multiplierMatch then
                                local value = tonumber(multiplierMatch)
                                if value and value >= 25 then
                                    return obj, value
                                end
                            end
                        end
                    end
                    
                    -- Check for the priority egg specifically
                    if string.find(string.lower(obj.Name), string.lower(egg_priority)) then
                        -- Extra deep check for priority eggs
                        for _, child in ipairs(obj:GetDescendants()) do
                            if child:IsA("ValueBase") and child.Value >= 25 then
                                return obj, child.Value
                            end
                        end
                    end
                end
                
                -- Recursively check children with depth limit
                local foundEgg, luckValue = scanForEggs(obj, depth + 1)
                if foundEgg then
                    return foundEgg, luckValue
                end
            end
        end
        
        return nil
    end
    
    return scanForEggs(currentIsland, 0)
end

-- Faster tweening function with improved performance
local function tweenToEgg(egg)
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
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoidRootPart or not humanoid then return end
    
    -- Cancel any existing tween
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    
    -- Direct tween to target (faster)
    local targetPosition = eggPart.Position + Vector3.new(0, 5, 0)
    local distance = (targetPosition - humanoidRootPart.Position).Magnitude
    
    -- Fast tween directly to target
    local tweenInfo = TweenInfo.new(
        distance / (80 * tweenSpeed), -- Much faster movement
        Enum.EasingStyle.Linear
    )
    
    currentTween = TweenService:Create(humanoidRootPart, tweenInfo, {
        CFrame = CFrame.new(targetPosition)
    })
    
    currentTween:Play()
    currentTween.Completed:Wait()
    currentTween = nil
end

-- Simplified egg opening function
local function openEgg(egg, amount)
    if not open_eggs or not egg then return end
    
    amount = amount or egg_amount
    
    -- Try proximity prompt (most common)
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
    
    -- Try common remotes
    local remotePatterns = {"OpenEgg", "HatchEgg", "BuyEgg", "PurchaseEgg", "Hatch", "Open"}
    
    for _, pattern in ipairs(remotePatterns) do
        for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
            if remote:IsA("RemoteEvent") and string.find(remote.Name:lower(), pattern:lower()) then
                for i = 1, amount do
                    pcall(function() remote:FireServer(egg) end)
                    pcall(function() remote:FireServer(egg.Name) end)
                    wait(0.2)
                end
                return
            end
        end
    end
end

-- Optimized server hopping
local function hopToNextServer()
    if tick() - lastTeleport < teleportCooldown then return false end
    
    lastTeleport = tick()
    
    local success, result = pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=50"
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    
    if success and result and result.data then
        -- Find a server with some players but not full
        for _, server in ipairs(result.data) do
            if server.playing < server.maxPlayers and server.playing > 0 and not visitedServers[server.id] then
                visitedServers[server.id] = true
                
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(PLACE_ID, server.id, LocalPlayer)
                end)
                
                return true
            end
        end
    end
    
    return false
end

-- Main loop with improved island rotation
local function mainLoop()
    if isSearching then return end
    isSearching = true
    
    print("------- 25x Egg Finder Started -------")
    pressPlayAndOptimize()
    wait(1)
    serverSearchTime = tick()
    
    while wait(0.1) do -- Faster loop interval
        local foundEgg, luckValue = findLuckyEgg()
        
        if foundEgg then
            local eggId = foundEgg.Name .. "_" .. tostring(foundEgg:GetFullName())
            
            if not notifiedEggs[eggId] or (tick() - notifiedEggs[eggId]) > 30 then
                notifiedEggs[eggId] = tick()
                
                print("Found 25x egg: " .. foundEgg.Name .. " with " .. tostring(luckValue) .. "x luck")
                
                sendDiscordNotification(foundEgg, luckValue)
                tweenToEgg(foundEgg)
                openEgg(foundEgg, egg_amount)
                
                serverSearchTime = tick() -- Reset timer since we found something
            end
        else
            -- Check if we've been searching too long in this server
            local searchTime = tick() - serverSearchTime
            
            if searchTime > maxServerSearchTime then
                print("Maximum search time reached, hopping to next server")
                if hopToNextServer() then
                    wait(2)
                    serverSearchTime = tick()
                    notifiedEggs = {}
                    islandSearchIndex = 1
                    pressPlayAndOptimize()
                    wait(1)
                end
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

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 240, 0, 80)
frame.Position = UDim2.new(0.5, -120, 0.9, -40)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
frame.BackgroundTransparency = 0.2
frame.BorderSizePixel = 2
frame.BorderColor3 = Color3.fromRGB(255, 215, 0)
frame.Parent = screenGui

local cornerRadius = Instance.new("UICorner")
cornerRadius.CornerRadius = UDim.new(0, 6)
cornerRadius.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0.4, 0)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Text = "🔍 25x Egg Finder"
title.Parent = frame

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, 0, 0.3, 0)
status.Position = UDim2.new(0, 0, 0.4, 0)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(255, 255, 255)
status.Font = Enum.Font.Gotham
status.TextSize = 14
status.Text = "Looking for: " .. egg_priority
status.Parent = frame

local timeStatus = Instance.new("TextLabel")
timeStatus.Size = UDim2.new(1, 0, 0.3, 0)
timeStatus.Position = UDim2.new(0, 0, 0.7, 0)
timeStatus.BackgroundTransparency = 1
timeStatus.TextColor3 = Color3.fromRGB(255, 255, 255)
timeStatus.Font = Enum.Font.Gotham
timeStatus.TextSize = 14
timeStatus.Text = "Time left: " .. maxServerSearchTime .. "s"
timeStatus.Parent = frame

-- Update UI
spawn(function()
    while wait(0.5) do
        if not screenGui or not screenGui.Parent then return end
        
        local timeSpent = tick() - serverSearchTime
        local timeLeft = math.max(0, maxServerSearchTime - timeSpent)
        
        status.Text = "Looking for: " .. egg_priority .. " (Island " .. islandSearchIndex .. ")"
        timeStatus.Text = "Time left: " .. math.floor(timeLeft) .. "s"
        
        if timeLeft < 3 then
            timeStatus.TextColor3 = Color3.fromRGB(255, 100, 100)
        else
            timeStatus.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end
end)

-- Start with error handling
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

print("🚀 25x Egg Finder initialized")
