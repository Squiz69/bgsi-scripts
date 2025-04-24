getgenv().config = {
    eggs = {
       -- ["rainbow-egg"] = "Rainbow Egg",
        ["event-1"] = "Pastel Egg",
   --   ["event-2"] = "Bunny Egg",
        ["event-3"] = "Throwback Egg",
     -- ["void-egg"] = "Void Egg",
    --  ["nightmare-egg"] = "Nightmare Egg",
        ["aura-egg"] = "Aura Egg",
    };
    tween_speed = 60; -- in seconds, put this up if u are flinging or getting teleported back
    egg_amount = 3; -- the amount of eggs you want to open (MUST BE ABLE TO OPEN THIS MANY EGGS!!)
};

repeat task.wait() until game:IsLoaded();

local SERVER_HOP = {};
local API, SERVER_PAGES;

local function CREATE_FILE(FILE_NAME, FILE)
    pcall(function()
        makefolder("ServerHopper");
        makefolder("ServerHopper//".. game.PlaceId);
        writefile("ServerHopper//".. game.PlaceId .."//".. FILE_NAME ..".json", FILE);
    end);
end;

local function FETCH_JOB_IDS(AMOUNT)
    local JOB_IDS = {os.date("*t").hour};
    repeat
        task.wait();
        API = game:GetService("HttpService"):JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/".. game.PlaceId .."/servers/Public?sortOrder=Asc&limit=100".. (SERVER_PAGES and "&cursor=".. SERVER_PAGES or "")));
        for i, v in next, API["data"] do
            if v["id"] ~= game.JobId and v["playing"] ~= v["maxPlayers"] then
                if #JOB_IDS < AMOUNT + 1 then
                    table.insert(JOB_IDS, v["id"])
                end
            end
        end
        SERVER_PAGES = API["nextPageCursor"];
    until not SERVER_PAGES or #JOB_IDS >= AMOUNT + 1;
    return JOB_IDS;
end;

local function GET_RANDOM_JOD_ID(TABLE)
    return TABLE[math.random(1, #TABLE)]
end;

function SERVER_HOP:Normal(AMOUNT)
    if AMOUNT == nil then AMOUNT = tonumber(math.huge); end;

    local JOB_IDS = FETCH_JOB_IDS(AMOUNT);

    if not isfile("ServerHopper//".. game.PlaceId .."//normal-jobids.json") then
        CREATE_FILE("normal-jobids", game:GetService("HttpService"):JSONEncode(JOB_IDS));
    end;

    if JOB_IDS[1] ~= os.date("*t").hour then
        CREATE_FILE("normal-jobids", game:GetService("HttpService"):JSONEncode(JOB_IDS));
    end;

    local SELECTED_JOB_ID = GET_RANDOM_JOD_ID(JOB_IDS);

    game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, SELECTED_JOB_ID);
    game:GetService("Players").LocalPlayer.OnTeleport:Connect(function(STATUS)
        if STATUS == Enum.TeleportState.Failed then
            SELECTED_JOB_ID = GET_RANDOM_JOD_ID(JOB_IDS);
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, SELECTED_JOB_ID);
        end;
    end);
end;

local function CheckX25Eggs()
    local FoundEggs = {};

    for i, v in next, game:GetService("Workspace").Rendered.Rifts:GetChildren() do
        if config.eggs[v.Name] then
            if v.Display.SurfaceGui.Icon.Luck.Text == "x25" then
                table.insert(FoundEggs, v)
                print("Found 25x luck egg: " .. v.Name);
            end;
        end;
    end;
    
    return FoundEggs;
end

task.spawn(function()
    local X25Eggs = CheckX25Eggs();

    if #X25Eggs ~= 0 then
        for i, v in next, X25Eggs do
            if game:GetService("Workspace").Rendered.Rifts:FindFirstChild(v.Name) then
                game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("Event"):FireServer("Teleport", "Workspace.Worlds.The Overworld.FastTravel.Spawn");
                task.wait(1);
                local CFrameValue = Instance.new("CFrameValue");
                CFrameValue.Value = game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame;
                CFrameValue:GetPropertyChangedSignal("Value"):Connect(function()
                    game:GetService("Players").LocalPlayer.Character.HumanoidRootPart.CFrame = CFrameValue.Value;
                end);
                game:GetService("TweenService"):Create(CFrameValue, TweenInfo.new(config.tween_speed, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {Value = v.Display.CFrame + Vector3.new(0, 6, 0)}):Play();
                task.wait(config.tween_speed)
                repeat
                    task.wait();
                    game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("Event"):FireServer("HatchEgg", config.eggs[v.Name], config.egg_amount);
                until not game:GetService("Workspace").Rendered.Rifts:FindFirstChild(v.Name);
            end;
        end;
        SERVER_HOP:Normal(20);
    else
        SERVER_HOP:Normal(20);
    end;
end);
