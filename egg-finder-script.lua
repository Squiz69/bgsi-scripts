repeat task.wait() until game:IsLoaded()

local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

getgenv().WEBHOOK = "INPUT_WEBHOOK_HERE"
print(WEBHOOK)

local PLACE_ID = 16302670534
local egg_priority = "rainbow-egg"
local egg_amount = 3
local open_eggs = true
local maxServerSearchTime = 10
local webhookCooldown = 30
local maxTweenRetries = 3

local hatchable_eggs = {
    "rainbow-egg", "event-1", "event-2", "void-egg", "nightmare-egg", "aura-egg"
}

local lastTeleport = 0
local teleportCooldown = 5
local notifiedEggs = {}
local lastWebhookSent = 0
local currentCFrameValue = nil
local initialServerTime = tick()
local eggFoundRecently = false
local lastEggFoundTime = 0
local isSearching = false

local SERVER_HOP = {}
local API, SERVER_PAGES

local function CREATE_FILE(FILE_NAME, FILE)
    pcall(function()
        makefolder("ServerHopper")
        makefolder("ServerHopper//".. game.PlaceId)
        writefile("ServerHopper//".. game.PlaceId .."//".. FILE_NAME ..".json", FILE)
    end)
end

local function FETCH_JOB_IDS(AMOUNT)
    local JOB_IDS = {os.date("*t").hour}
    repeat
        task.wait()
        API = game:GetService("HttpService"):JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/".. game.PlaceId .."/servers/Public?sortOrder=Asc&limit=100".. (SERVER_PAGES and "&cursor=".. SERVER_PAGES or "")))
        for i, v in next, API["data"] do
            if v["id"] ~= game.JobId and v["playing"] ~= v["maxPlayers"] then
                if #JOB_IDS < AMOUNT + 1 then
                    table.insert(JOB_IDS, v["id"])
                end
            end
        end
        SERVER_PAGES = API["nextPageCursor"]
    until not SERVER_PAGES or #JOB_IDS >= AMOUNT + 1
    return JOB_IDS
end

local function GET_RANDOM_JOD_ID(TABLE)
    return TABLE[math.random(1, #TABLE)]
end

function SERVER_HOP:Normal(AMOUNT)
    if AMOUNT == nil then AMOUNT = tonumber(math.huge) end

    local JOB_IDS = FETCH_JOB_IDS(AMOUNT)

    if not isfile("ServerHopper//".. game.PlaceId .."//normal-jobids.json") then
        CREATE_FILE("normal-jobids", game:GetService("HttpService"):JSONEncode(JOB_IDS))
    end

    if JOB_IDS[1] ~= os.date("*t").hour then
        CREATE_FILE("normal-jobids", game:GetService("HttpService"):JSONEncode(JOB_IDS))
    end

    local SELECTED_JOB_ID = GET_RANDOM_JOD_ID(JOB_IDS)

    game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, SELECTED_JOB_ID)
    game:GetService("Players").LocalPlayer.OnTeleport:Connect(function(STATUS)
        if STATUS == Enum.TeleportState.Failed then
            SELECTED_JOB_ID = GET_RANDOM_JOD_ID(JOB_IDS)
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, SELECTED_JOB_ID)
        end
    end)
end

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

local function sendWebhook(eggInfo)
    if not eggInfo or tick() - lastWebhookSent < webhookCooldown then return false end
    
    local eggId = eggInfo:GetFullName()
    if notifiedEggs[eggId] and tick() - notifiedEggs[eggId] < webhookCooldown * 2 then
        return false
    end
    
    notifiedEggs[eggId] = tick()
    lastWebhookSent = tick()
    
    local name = eggInfo.Name or "Unknown Egg"
    local displayName = name:gsub("-", " "):gsub("^%l", string.upper)
    
    local playerCount = #Players:GetPlayers()
    local maxPlayers = Players.MaxPlayers
    local jobId = game.JobId
    
    local content = "**" .. displayName .. " Found!** :tada:\n" ..
                   "A 25X Luck " .. displayName .. " has been found! :rainbow:\n" ..
                   "Luck: x25\n" ..
                   "Server Slots: " .. playerCount .. "/" .. maxPlayers .. "\n" ..
                   "Job ID: " .. jobId .. "\n" ..
                   "Teleport Script: game:GetService(\"TeleportService\"):TeleportToPlaceInstance(" .. PLACE_ID .. ", \"" .. jobId .. "\", game.Players.LocalPlayer)"
    
    local success = false
    local attempts = 0
    
    while not success and attempts < 3 do
        attempts = attempts + 1
        
        success = pcall(function()
            HttpService:PostAsync(
                getgenv().WEBHOOK,
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
            
            if attempts == 2 then
                success = pcall(function()
                    HttpService:PostAsync(
                        getgenv().WEBHOOK,
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

local function tweenToEgg(egg)
    if not egg then 
        print("No egg provided to tweenToEgg function")
        return false 
    end
    
    print("Tweening to egg: " .. egg.Name)
    
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
    
    local retryCount = 0
    local tweenSuccess = false
    
    while not tweenSuccess and retryCount < maxTweenRetries do
        retryCount = retryCount + 1
        print("Tween attempt " .. retryCount .. "/" .. maxTweenRetries)
        
        if currentCFrameValue then
            pcall(function() currentCFrameValue:Destroy() end)
            currentCFrameValue = nil
        end
        
        local CFrameValue = Instance.new("CFrameValue")
        currentCFrameValue = CFrameValue
        CFrameValue.Value = humanoidRootPart.CFrame
        
        CFrameValue:GetPropertyChangedSignal("Value"):Connect(function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = CFrameValue.Value
            end
        end)
        
        local offset = Vector3.new(0, 6 + retryCount, 0)
        if retryCount > 1 then
            offset = offset + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
        end
        
        local targetCFrame = eggPart.CFrame + offset
        
        tweenSuccess = pcall(function()
            local tween = TweenService:Create(
                CFrameValue,
                TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
                {Value = targetCFrame}
            )
            
            tween:Play()
            tween.Completed:Wait()
        end)
        
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
    
    if currentCFrameValue then
        pcall(function() currentCFrameValue:Destroy() end)
        currentCFrameValue = nil
    end
    
    return tweenSuccess
end

local function openEgg(egg, amount)
    if not open_eggs or not egg then return false end
    
    amount = amount or egg_amount
    print("Opening egg: " .. egg.Name .. " x" .. amount)
    
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
    
    local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt")
    if prompt then
        for i = 1, amount do
            fireproximityprompt(prompt)
            wait(0.2)
        end
        return true
    end
    
    local clickDetector = egg:FindFirstChildWhichIsA("ClickDetector")
    if clickDetector then
        for i = 1, amount do
            fireclickdetector(clickDetector)
            wait(0.2)
        end
        return true
    end
    
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

local function useAutoHatchFunction(eggType)
    local success = pcall(function()
        if not getgenv().Functions then
            getgenv().Functions = {}
        end
        
        getgenv().Functions.AutoHatchEgg = true
        
        task.spawn(function()
            while getgenv().Functions.AutoHatchEgg do
                task.wait()
                game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("Event"):FireServer("HatchEgg", eggType or "Common Egg", 1)
                task.wait(0.2)
            end
        end)
        
        task.delay(3, function()
            getgenv().Functions.AutoHatchEgg = false
        end)
    end)
    
    return success
end

local function hopToNextServer()
    if tick() - lastTeleport < teleportCooldown then 
        print("Teleport on cooldown, waiting...")
        return false 
    end
    
    if eggFoundRecently then
        print("Priority egg found recently, staying in current server")
        return false
    end
    
    print("Finding new server using SERVER_HOP module...")
    lastTeleport = tick()
    
    pcall(function()
        SERVER_HOP:Normal(20)
    end)
    
    wait(5)
    return true
end

local function createUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "EggFinderGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 240, 0, 100)
    frame.Position = UDim2.new(0.5, -120, 0.02, 0)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 2
    frame.BorderColor3 = Color3.fromRGB(255, 215, 0)
    frame.Parent = screenGui
    
    local cornerRadius = Instance.new("UICorner")
    cornerRadius.CornerRadius = UDim.new(0, 8)
    cornerRadius.Parent = frame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0.3, 0)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 215, 0)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.Text = "25x Priority Egg Finder"
    title.Parent = frame
    
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, 0, 0.25, 0)
    status.Position = UDim2.new(0, 0, 0.3, 0)
    status.BackgroundTransparency = 1
    status.TextColor3 = Color3.fromRGB(255, 255, 255)
    status.Font = Enum.Font.Gotham
    status.TextSize = 14
    status.Text = "Scanning for eggs..."
    status.Parent = frame
    
    local timerLabel = Instance.new("TextLabel")
    timerLabel.Size = UDim2.new(1, 0, 0.2, 0)
    timerLabel.Position = UDim2.new(0, 0, 0.55, 0)
    timerLabel.BackgroundTransparency = 1
    timerLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
    timerLabel.Font = Enum.Font.Gotham
    timerLabel.TextSize = 13
    timerLabel.Text = "Time left: " .. tostring(maxServerSearchTime) .. "s"
    timerLabel.Parent = frame
    
    local serverInfo = Instance.new("TextLabel")
    serverInfo.Size = UDim2.new(1, 0, 0.25, 0)
    serverInfo.Position = UDim2.new(0, 0, 0.75, 0)
    serverInfo.BackgroundTransparency = 1
    serverInfo.TextColor3 = Color3.fromRGB(200, 200, 200)
    serverInfo.Font = Enum.Font.Gotham
    serverInfo.TextSize = 12
    serverInfo.Text = "Server: " .. string.sub(game.JobId, 1, 8) .. "..."
    serverInfo.Parent = frame
    
    spawn(function()
        while wait(0.5) do
            if not screenGui or not screenGui.Parent then return end
            
            local timeSpent = tick() - initialServerTime
            local timeLeft = math.max(0, maxServerSearchTime - timeSpent)
            
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
            
            local playerCount = #Players:GetPlayers()
            local maxPlayers = Players.MaxPlayers
            serverInfo.Text = "Players: " .. playerCount .. "/" .. maxPlayers .. " | ID: " .. string.sub(game.JobId, 1, 8) .. "..."
        end
    end)
    
    return screenGui
end

local function main()
    print("------- 25x Priority Egg Finder Started -------")
    createUI()
    
    while wait(1) do
        local timeInServer = tick() - initialServerTime
        if timeInServer > maxServerSearchTime and not eggFoundRecently then
            print("Max time in server reached, preparing to hop")
            hopToNextServer()
            initialServerTime = tick()
            continue
        end
        
        local luckyEggs = findLuckyEggs()
        
        if #luckyEggs > 0 then
            eggFoundRecently = true
            lastEggFoundTime = tick()
            initialServerTime = tick()
            
            for _, egg in ipairs(luckyEggs) do
                sendWebhook(egg)
                
                local tweenSuccess = tweenToEgg(egg)
                wait(1)
                
                if tweenSuccess then
                    local openSuccess = openEgg(egg, egg_amount)
                    
                    if not openSuccess then
                        print("Regular egg opening failed, trying Alternative method...")
                        useAutoHatchFunction(egg.Name)
                    end
                else
                    print("All tween attempts failed, trying direct interaction")
                    openEgg(egg, egg_amount)
                    useAutoHatchFunction(egg.Name)
                end
                
                wait(2)
            end
        elseif eggFoundRecently and (tick() - lastEggFoundTime) > 60 then
            eggFoundRecently = false
        end
    end
end

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
