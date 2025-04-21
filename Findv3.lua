local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1363054781882699910/Qwa5roGAv5rj83wBwCG7BzraXD8xOc7L-eeopKGdvCSug1GhdJzx6sRRNA1tjgmbRW34"
local PLACE_ID = 85896571713843
local visitedServers = {}

local open_eggs = true
local lastTeleport = 0
local teleportCooldown = 5
local notifiedEggs = {}

local function pressPlayButton()
    wait(3)
    
    local buttons = {}
    local checkFunctions = {
        function() return game:GetService("StarterGui"):GetDescendants() end,
        function() return LocalPlayer.PlayerGui:GetDescendants() end,
        function() return game:GetService("CoreGui"):GetDescendants() end
    }
    
    for _, getDescendants in ipairs(checkFunctions) do
        local success, descendants = pcall(getDescendants)
        if success then
            for _, gui in pairs(descendants) do
                if (gui:IsA("TextButton") or gui:IsA("ImageButton")) and 
                   (gui.Visible == true) and 
                   (not gui.Text or string.lower(gui.Text) == "play" or 
                    string.lower(gui.Text) == "start" or 
                    string.find(string.lower(gui.Name), "play") or 
                    string.find(string.lower(gui.Name), "start")) then
                    table.insert(buttons, gui)
                end
            end
        end
    end
    
    for _, button in ipairs(buttons) do
        pcall(function()
            for _, event in ipairs({"MouseButton1Click", "Activated", "MouseButton1Down", "MouseButton1Up"}) do
                if button[event] then
                    button[event]:Fire()
                end
            end
        end)
        wait(0.5)
    end
    
    if GuiService:IsTenFootInterface() or game:GetService("UserInputService").TouchEnabled then
        for _, getDescendants in ipairs(checkFunctions) do
            local success, descendants = pcall(getDescendants)
            if success then
                for _, gui in pairs(descendants) do
                    if (gui:IsA("ImageButton") or gui:IsA("TextButton")) and gui.Visible == true then
                        pcall(function()
                            for _, event in ipairs({"TouchTap", "MouseButton1Click", "Activated"}) do
                                if gui[event] then
                                    gui[event]:Fire()
                                end
                            end
                        end)
                        wait(0.5)
                    end
                end
            end
        end
    end
end

local function sendDiscordNotification(info, isEgg)
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
                           '"' .. PLACE_ID .. '", "' .. jobId .. '", game.Players.LocalPlayer)'
    
    local webhookData
    
    if isEgg then
        local eggType = "Unknown Egg"
        if info and info.Name then
            if string.find(string.lower(info.Name), "rainbow") then
                eggType = "Rainbow Egg"
            elseif string.find(string.lower(info.Name), "golden") then
                eggType = "Golden Egg"
            elseif string.find(string.lower(info.Name), "lucky") then
                eggType = "Lucky Egg"
            else
                eggType = info.Name .. " Egg"
            end
        end
        
        webhookData = {
            embeds = {
                {
                    title = "Egg Found 🎉",
                    description = "An egg with 25X Luck has been discovered!",
                    color = 16776960,
                    fields = {
                        {name = "Egg Type", value = eggType, inline = true},
                        {name = "Luck", value = "x25", inline = true},
                        {name = "Height", value = height, inline = true},
                        {name = "Server Slots", value = currentPlayers .. "/" .. maxPlayers, inline = true},
                        {name = "Time Remaining", value = "4 minutes", inline = true},
                        {name = "Found By", value = censoredName, inline = true},
                        {name = "Job ID", value = jobId, inline = false},
                        {name = "Teleport Script", value = "```lua\n" .. teleportScript .. "\n```", inline = false}
                    },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                }
            }
        }
    elseif info.Name == "Server Hop" then
        webhookData = {
            embeds = {
                {
                    title = "Server Hopping 🔄",
                    description = "Moving to a new server to find 25x eggs...",
                    color = 5814783,
                    fields = {
                        {name = "Current Server", value = jobId, inline = true},
                        {name = "Target Server", value = info.TargetServer or "Unknown", inline = true},
                        {name = "Target Players", value = info.TargetPlayers or "Unknown", inline = true}
                    },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                }
            }
        }
    else
        webhookData = {
            embeds = {
                {
                    title = "Server Joined",
                    description = "Bot has joined a new server to search for 25x eggs",
                    color = 5814783,
                    fields = {
                        {name = "Server ID", value = jobId, inline = true},
                        {name = "Players", value = currentPlayers .. "/" .. maxPlayers, inline = true},
                        {name = "Bot Name", value = censoredName, inline = true}
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

local function find25xLuckyEgg()
    local eggContainers = {workspace}
    
    local commonFolders = {"Eggs", "LuckyEggs", "EventEggs", "Maps", "SpawnedEggs", "World"}
    for _, name in ipairs(commonFolders) do
        local folder = workspace:FindFirstChild(name)
        if folder then
            table.insert(eggContainers, folder)
            for _, subfolder in pairs(folder:GetChildren()) do
                if subfolder:IsA("Folder") or subfolder:IsA("Model") then
                    table.insert(eggContainers, subfolder)
                end
            end
        end
    end
    
    for _, container in pairs(eggContainers) do
        for _, obj in pairs(container:GetDescendants()) do
            local name = string.lower(obj.Name)
            
            if (obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("MeshPart")) then
                if string.find(name, "25x") or string.find(name, "25 x") or
                   (string.find(name, "luck") and string.find(name, "25")) then
                    local eggId = obj:GetFullName()
                    if not notifiedEggs[eggId] then
                        notifiedEggs[eggId] = tick()
                        sendDiscordNotification(obj, true)
                        return obj
                    end
                end
                
                if obj:GetAttribute("Luck") == 25 or 
                   obj:GetAttribute("Multiplier") == 25 or
                   obj:GetAttribute("LuckMultiplier") == 25 then
                    local eggId = obj:GetFullName()
                    if not notifiedEggs[eggId] then
                        notifiedEggs[eggId] = tick()
                        sendDiscordNotification(obj, true)
                        return obj
                    end
                end
                
                local uiLabel = obj:FindFirstChild("LuckMultiplier") or obj:FindFirstChild("MultiplierLabel")
                if uiLabel and uiLabel:IsA("TextLabel") and string.find(uiLabel.Text, "25x") then
                    local eggId = obj:GetFullName()
                    if not notifiedEggs[eggId] then
                        notifiedEggs[eggId] = tick()
                        sendDiscordNotification(obj, true)
                        return obj
                    end
                end
            end
        end
    end
    
    if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
        for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if gui:IsA("TextLabel") and gui.Visible and string.find(gui.Text, "25x") and 
               string.find(string.lower(gui.Text), "luck") then
                local model = gui
                for i = 1, 5 do
                    if model and model.Parent and model.Parent:IsA("Model") then
                        local eggId = model.Parent:GetFullName()
                        if not notifiedEggs[eggId] then
                            notifiedEggs[eggId] = tick()
                            sendDiscordNotification(model.Parent, true)
                            return model.Parent
                        end
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
    
    humanoidRootPart.CFrame = CFrame.new(eggPart.Position + Vector3.new(0, 5, 0))
    
    wait(1)
end

local function openEgg(egg)
    if not open_eggs or not egg then return end
    
    local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt")
    if prompt then
        fireproximityprompt(prompt)
        wait(1)
        return
    end
    
    local potentialRemoteNames = {"OpenEgg", "HatchEgg", "OpenEggs", "PurchaseEgg", "BuyEgg", "Open", "Hatch"}
    local remoteFolders = {ReplicatedStorage:FindFirstChild("RemoteEvents"), ReplicatedStorage:FindFirstChild("Remotes"), ReplicatedStorage}
    
    local openEggRemote
    for _, folder in pairs(remoteFolders) do
        if folder then
            for _, remoteName in ipairs(potentialRemoteNames) do
                local remote = folder:FindFirstChild(remoteName)
                if remote and (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
                    openEggRemote = remote
                    break
                end
            end
            
            if openEggRemote then break end
            
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
    
    if openEggRemote then
        local openEggPatterns = {
            function() openEggRemote:FireServer(egg.Name, "Single") end,
            function() openEggRemote:FireServer(egg.Name) end,
            function() openEggRemote:FireServer(egg) end,
            function() openEggRemote:FireServer() end,
            function() openEggRemote:FireServer(egg.Name, 1) end,
            function() openEggRemote:FireServer("Open", egg.Name) end
        }
        
        for _, openPattern in ipairs(openEggPatterns) do
            pcall(openPattern)
            wait(0.5)
        end
    end
    
    if game:GetService("UserInputService").TouchEnabled then
        pcall(function()
            local touch = {
                UserInputType = Enum.UserInputType.Touch,
                Position = egg.Position,
                Target = egg
            }
            game:GetService("UserInputService").TouchTap:Fire(touch)
        end)
        wait(0.5)
    end
end

local function hopToNextServer()
    if tick() - lastTeleport < teleportCooldown then return false end
    
    local nextServer = getRandomServer()
    
    if nextServer then
        lastTeleport = tick()
        visitedServers[nextServer.id] = true
        
        local hopInfo = {
            Name = "Server Hop",
            TargetServer = nextServer.id,
            TargetPlayers = nextServer.playing .. "/" .. nextServer.maxPlayers
        }
        
        sendDiscordNotification(hopInfo, false)
        
        pcall(function()
            TeleportService:TeleportToPlaceInstance(PLACE_ID, nextServer.id, LocalPlayer)
        end)
        return true
    else
        visitedServers = {}
        return false
    end
end

local function mainLoop()
    pressPlayButton()
    wait(5)
    
    sendDiscordNotification({Name = "Server Joined"}, false)
    
    while wait(1) do
        local foundEgg = find25xLuckyEgg()
        
        if foundEgg then
            teleportToEgg(foundEgg)
            openEgg(foundEgg)
            wait(3)
        else
            hopToNextServer()
        end
        
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
end

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

spawn(function()
    pcall(mainLoop)
end)
