local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Discord webhook for notifications
local DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1363054781882699910/Qwa5roGAv5rj83wBwCG7BzraXD8xOc7L-eeopKGdvCSug1GhdJzx6sRRNA1tjgmbRW34"

local PLACE_ID = 85896571713843
local visitedServers = {}

-- All possible hatchable eggs to check
local hatchable_eggs = {
    "event-1", "event-2", "rainbow-egg", "void-egg", "nightmare-egg", "aura-egg"
}

local egg_priority = "event-1" -- Priority egg to look for
local egg_amount = 3 -- How many eggs to open when found
local open_eggs = true -- Set to false if you only want to find eggs without opening

local lastTeleport = 0
local teleportCooldown = 5
local notifiedEggs = {}
local serverSearchTime = 0
local maxServerSearchTime = 60 -- Search a server for maximum 60 seconds before hopping

-- Improved UI interaction - specifically targeting buttons seen in screenshots
local function clickUIButton(buttonType)
    print("Looking for button: " .. buttonType)
    
    -- Determine what to look for based on type
    local buttonPatterns = {}
    local buttonColors = {}
    
    if buttonType == "play" then
        buttonPatterns = {"play", "start", "enter"}
        buttonColors = {Color3.fromRGB(85, 170, 0)} -- Green play button
    elseif buttonType == "quality" or buttonType == "optimize" then
        buttonPatterns = {"quality", "optimize"}
        buttonColors = {Color3.fromRGB(59, 138, 235)} -- Blue button
    end
    
    -- Check all GUIs for buttons matching our criteria
    local guis = {}
    pcall(function() for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do table.insert(guis, gui) end end)
    pcall(function() for _, gui in pairs(game:GetService("CoreGui"):GetDescendants()) do table.insert(guis, gui) end end)
    
    for _, gui in pairs(guis) do
        -- Try to match the button by name, text, or color
        if (gui:IsA("TextButton") or gui:IsA("ImageButton")) then
            local matched = false
            
            -- Check text content
            if gui:IsA("TextButton") then
                local text = string.lower(gui.Text)
                for _, pattern in ipairs(buttonPatterns) do
                    if string.find(text, pattern) then
                        matched = true
                        break
                    end
                end
            end
            
            -- Check button name
            if not matched then
                local name = string.lower(gui.Name)
                for _, pattern in ipairs(buttonPatterns) do
                    if string.find(name, pattern) then
                        matched = true
                        break
                    end
                end
            end
            
            -- Check color for visual matching (approximate)
            if not matched and gui:IsA("GuiObject") and #buttonColors > 0 then
                for _, color in ipairs(buttonColors) do
                    local btnColor = gui.BackgroundColor3
                    local r, g, b = btnColor.R, btnColor.G, btnColor.B
                    local targetR, targetG, targetB = color.R, color.G, color.B
                    
                    -- Allow for some color variation (brightness/saturation)
                    if (math.abs(r - targetR) < 0.3 and 
                        math.abs(g - targetG) < 0.3 and 
                        math.abs(b - targetB) < 0.3) then
                        matched = true
                        break
                    end
                end
            end
            
            -- Also check parent and ancestors for matching frames
            if not matched then
                local parent = gui.Parent
                local depth = 0
                while parent and depth < 3 do
                    if parent:IsA("Frame") or parent:IsA("ImageLabel") then
                        local name = string.lower(parent.Name)
                        for _, pattern in ipairs(buttonPatterns) do
                            if string.find(name, pattern) then
                                matched = true
                                break
                            end
                        end
                        
                        -- Check for color match on parent
                        if not matched and parent:IsA("GuiObject") and #buttonColors > 0 then
                            for _, color in ipairs(buttonColors) do
                                local pColor = parent.BackgroundColor3
                                if (math.abs(pColor.R - color.R) < 0.3 and 
                                    math.abs(pColor.G - color.G) < 0.3 and 
                                    math.abs(pColor.B - color.B) < 0.3) then
                                    matched = true
                                    break
                                end
                            end
                        end
                    end
                    
                    if matched then break end
                    parent = parent.Parent
                    depth = depth + 1
                end
            end
            
            -- If this button matches our criteria, click it
            if matched and gui.Visible then
                print("Found matching button: " .. gui:GetFullName())
                pcall(function() gui.MouseButton1Click:Fire() end)
                pcall(function() firesignal(gui.MouseButton1Click) end)
                pcall(function() firesignal(gui.Activated) end)
                return true
            end
        end
    end
    
    -- If we get here, we couldn't find a matching button
    print("Could not find " .. buttonType .. " button")
    return false
end

-- Special function to handle "Bubble Gum Simulator" UI
local function handleBubbleGumUI()
    print("Checking for Bubble Gum Simulator specific UI elements")
    
    -- First check if we're on the quality/optimize screen
    local qualityFound = false
    local playFound = false
    
    pcall(function()
        for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if gui:IsA("TextLabel") then
                local text = string.lower(gui.Text)
                if string.find(text, "quality") then
                    qualityFound = true
                end
            elseif gui:IsA("TextButton") and string.lower(gui.Text) == "play" then
                playFound = true
            end
        end
    end)
    
    if qualityFound then
        -- First try clicking the Optimized button (blue phone icon)
        print("Quality screen detected, clicking Optimized")
        clickUIButton("optimize")
        wait(1)
        
        -- Then look for Play button
        if playFound then
            print("Play button detected")
            clickUIButton("play")
            return true
        end
    else
        -- Just try the play button directly
        print("Trying direct play button")
        clickUIButton("play")
        return true
    end
    
    return false
end

-- Optimized function to find 25x lucky eggs
local function find25xLuckyEgg()
    print("Searching for 25x lucky eggs...")
    local foundEggs = {}
    
    -- Function to check if an object has 25x luck
    local function checkLuck(obj)
        if typeof(obj) ~= "Instance" then return nil end
        
        -- Quick name check for common 25x indicators
        local name = string.lower(obj.Name)
        if string.find(name, "25x") or string.find(name, "25 luck") then
            return 25
        end
        
        -- Check attributes for luck values
        for _, attrName in ipairs({"Luck", "LuckMultiplier", "Multiplier"}) do
            local value = obj:GetAttribute(attrName)
            if value == 25 or value == "25x" or value == "25" then
                return 25
            end
        end
        
        -- Check value objects
        for _, valueName in ipairs({"LuckValue", "MultiplierValue", "Luck"}) do
            local valueObj = obj:FindFirstChild(valueName)
            if valueObj and valueObj.Value == 25 then
                return 25
            end
        end
        
        -- Check TextLabels in descendants
        for _, child in ipairs(obj:GetDescendants()) do
            if child:IsA("TextLabel") then
                local text = string.lower(child.Text)
                if string.find(text, "25x") or string.find(text, "25 luck") then
                    return 25
                end
            end
        end
        
        return nil
    end
    
    -- Container priority to check
    local containers = {
        workspace:FindFirstChild("Eggs"),
        workspace:FindFirstChild("LuckyEggs"),
        workspace:FindFirstChild("EventEggs"),
        workspace
    }
    
    -- Add egg-related containers
    for _, child in pairs(workspace:GetChildren()) do
        if string.find(string.lower(child.Name), "egg") then
            table.insert(containers, child)
        end
    end
    
    -- Check if object is a target egg
    local function isTargetEgg(obj)
        local name = string.lower(obj.Name)
        for _, eggName in pairs(hatchable_eggs) do
            if string.find(name, string.lower(eggName)) then
                return true, string.lower(eggName) == string.lower(egg_priority)
            end
        end
        return false, false
    end
    
    -- Search containers
    for _, container in pairs(containers) do
        if container then
            for _, obj in pairs(container:GetDescendants()) do
                if obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("MeshPart") then
                    local isEgg, isPriority = isTargetEgg(obj)
                    
                    if isEgg then
                        local luckValue = checkLuck(obj)
                        
                        if luckValue == 25 then
                            print("Found 25x egg: " .. obj.Name)
                            table.insert(foundEggs, {
                                Egg = obj,
                                IsPriority = isPriority,
                                LuckValue = luckValue
                            })
                            
                            if isPriority then
                                return obj, luckValue
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Return priority egg if found
    for _, eggData in ipairs(foundEggs) do
        if eggData.IsPriority then
            return eggData.Egg, eggData.LuckValue
        end
    end
    
    -- Or return the first egg found
    if #foundEggs > 0 then
        return foundEggs[1].Egg, foundEggs[1].LuckValue
    end
    
    return nil
end

-- Teleport to egg
local function teleportToEgg(egg)
    if not egg then return end
    
    local eggPart = egg:IsA("BasePart") and egg or egg:FindFirstChildWhichIsA("BasePart")
    if not eggPart then return end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    print("Teleporting to 25x egg at " .. tostring(eggPart.Position))
    humanoidRootPart.CFrame = CFrame.new(eggPart.Position + Vector3.new(0, 5, 0))
    
    wait(1)
end

-- Open egg function (condensed)
local function openEgg(egg, amount)
    if not open_eggs or not egg then return end
    
    amount = amount or egg_amount
    print("Opening egg " .. egg.Name .. " x" .. amount)
    
    -- Method 1: Try proximity prompt
    local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt")
    if prompt then
        for i = 1, amount do
            pcall(function() fireproximityprompt(prompt) end)
            wait(0.5)
        end
        return
    end
    
    -- Method 2: Find and use remote
    local remotes = {
        ReplicatedStorage:FindFirstChild("OpenEgg"),
        ReplicatedStorage:FindFirstChild("HatchEgg"),
        ReplicatedStorage:FindFirstChild("RemoteEvents"):FindFirstChild("OpenEgg")
    }
    
    -- Add any remotes with "egg" in name
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) and
           string.find(string.lower(obj.Name), "egg") then
            table.insert(remotes, obj)
        end
    end
    
    -- Try firing remotes with different argument patterns
    for _, remote in ipairs(remotes) do
        if remote then
            pcall(function() remote:FireServer(egg.Name, amount) end)
            pcall(function() remote:FireServer(egg) end)
            pcall(function() remote:FireServer() end)
            wait(0.5)
        end
    end
end

-- Server hopping (condensed)
local function hopToNextServer()
    if tick() - lastTeleport < teleportCooldown then return false end
    
    print("Hopping to a new server")
    
    -- Get server list
    local servers = {}
    pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?limit=100"
        local result = HttpService:JSONDecode(game:HttpGet(url))
        
        for _, server in ipairs(result.data) do
            if server.playing < server.maxPlayers and not visitedServers[server.id] then
                table.insert(servers, server)
            end
        end
    end)
    
    -- Sort by player count (fewer is better)
    if #servers > 0 then
        table.sort(servers, function(a, b) return a.playing < b.playing end)
        local server = servers[math.random(1, math.min(10, #servers))]
        
        lastTeleport = tick()
        visitedServers[server.id] = true
        
        pcall(function() TeleportService:TeleportToPlaceInstance(PLACE_ID, server.id, LocalPlayer) end)
        return true
    else
        -- Reset visited servers if none found
        visitedServers = {}
        return false
    end
end

-- Create simple status UI
local function createStatusUI()
    pcall(function()
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "EggFinderStatus"
        screenGui.Parent = game:GetService("CoreGui")
        
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 200, 0, 40)
        frame.Position = UDim2.new(0.5, -100, 0.9, -20)
        frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        frame.BackgroundTransparency = 0.5
        frame.BorderSizePixel = 0
        frame.Parent = screenGui
        
        local text = Instance.new("TextLabel")
        text.Size = UDim2.new(1, 0, 1, 0)
        text.BackgroundTransparency = 1
        text.TextColor3 = Color3.fromRGB(255, 255, 255)
        text.Text = "25x Egg Finder - Looking for: " .. egg_priority
        text.Parent = frame
        
        -- Update status
        game:GetService("RunService").Heartbeat:Connect(function()
            if tick() % 1 < 0.1 then
                local timeSpent = tick() - serverSearchTime
                local minutes = math.floor(timeSpent / 60)
                local seconds = math.floor(timeSpent % 60)
                
                text.Text = "25x Egg Finder - " .. egg_priority .. " - " .. 
                            minutes .. "m " .. seconds .. "s"
            end
        end)
    end)
end

-- Improved initial game handling specifically for Bubble Gum Simulator
local function gameStartupSequence()
    print("Starting game sequence...")
    wait(3) -- Wait for UI to load
    
    -- First try the Bubble Gum Simulator specific UI handler
    if handleBubbleGumUI() then
        print("Used Bubble Gum UI handler")
    else
        -- If that doesn't work, try the general button detection
        print("Trying general button detection")
        
        -- Try common game startup buttons
        clickUIButton("play")
        wait(1)
        clickUIButton("optimize")
        wait(1)
        clickUIButton("play")
    end
    
    print("Game startup sequence complete")
    wait(5) -- Wait for game to load
end

-- Main loop
local function mainLoop()
    -- Handle initial game startup
    gameStartupSequence()
    
    -- Create status UI
    createStatusUI()
    
    -- Reset server search time
    serverSearchTime = tick()
    
    -- Main egg finding loop
    while wait(1) do
        local foundEgg, luckValue = find25xLuckyEgg()
        
        if foundEgg then
            print("Found 25x lucky egg: " .. foundEgg.Name)
            
            -- Check if already notified
            local eggId = foundEgg.Name .. "_" .. tostring(foundEgg:GetFullName())
            if not notifiedEggs[eggId] then
                notifiedEggs[eggId] = tick()
                
                -- Send Discord notification about the egg
                pcall(function()
                    local webhookData = {
                        embeds = {{
                            title = "25X Luck Egg Found!",
                            description = "Found a " .. foundEgg.Name .. " with 25X Luck",
                            color = 16776960
                        }}
                    }
                    
                    HttpService:PostAsync(
                        DISCORD_WEBHOOK_URL,
                        HttpService:JSONEncode(webhookData),
                        Enum.HttpContentType.ApplicationJson
                    )
                end)
                
                -- Teleport to and open
                teleportToEgg(foundEgg)
                openEgg(foundEgg, egg_amount)
                
                -- Reset search timer
                serverSearchTime = tick()
                wait(3)
            end
        else
            -- Check if we should hop servers
            if tick() - serverSearchTime > maxServerSearchTime then
                print("No eggs found, hopping to next server")
                if hopToNextServer() then
                    wait(10)
                    serverSearchTime = tick()
                end
            end
        end
    end
end

print("Starting Optimized 25x Luck Egg Finder")

-- Start main loop
spawn(function()
    pcall(mainLoop)
end)

-- Recovery system
spawn(function()
    while wait(30) do
        if tick() - serverSearchTime > 120 then
            print("Script stalled, restarting...")
            pcall(mainLoop)
        end
    end
end)
