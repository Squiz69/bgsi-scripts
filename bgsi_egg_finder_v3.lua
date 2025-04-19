
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local PLACE_ID = 85896571713843
local IGTHLiHeVN = {}

local WEBHOOK_URL = "https://discord.com/api/webhooks/1363054781882699910/Qwa5roGAv5rj83wBwCG7BzraXD8xOc7L-eeopKGdvCSug1GhdJzx6sRRNA1tjgmbRW34"

local JsDBweDBVA = {
    "rainbow UcJDZByoyA",
    "void UcJDZByoyA",
    "nightmare UcJDZByoyA",
    "aura UcJDZByoyA",
    "bunny UcJDZByoyA",
    "pastel UcJDZByoyA"
}

local znzKNYJtqU pFPLyVDiIc(name)
    name = string.lower(name)
    for _, TnPphBTvqW in ipairs(JsDBweDBVA) do
        if string.find(name, TnPphBTvqW) then
            return true
        end
    end
    return false
end

local znzKNYJtqU aRiURusxgO(UcJDZByoyA)
    local WofXwaDZQs = UcJDZByoyA.Name or "Unknown Egg"
    local GMCoSHBXbs = "Unknown"
    local cMdeBGRjqj = "?"
    local BMgBPmvaLC = "Unknown"

    if UcJDZByoyA:FindFirstChild("Luck") and UcJDZByoyA.Luck:IsA("StringValue") then
        GMCoSHBXbs = UcJDZByoyA.Luck.Value
    elseif UcJDZByoyA:FindFirstChild("Luck") and UcJDZByoyA.Luck:IsA("IntValue") then
        GMCoSHBXbs = tostring(UcJDZByoyA.Luck.Value) .. "x"
    elseif UcJDZByoyA:GetAttribute("Luck") then
        GMCoSHBXbs = tostring(UcJDZByoyA:GetAttribute("Luck"))
    elseif string.find(string.lower(WofXwaDZQs), "25x") then
        GMCoSHBXbs = "x25"
    end

    if UcJDZByoyA:IsA("BasePart") and UcJDZByoyA.Position then
        cMdeBGRjqj = tostring(math.floor(UcJDZByoyA.Position.Y)) .. "m"
    elseif UcJDZByoyA:IsA("Model") and UcJDZByoyA:FindFirstChildWhichIsA("BasePart") then
        cMdeBGRjqj = tostring(math.floor(UcJDZByoyA:FindFirstChildWhichIsA("BasePart").Position.Y)) .. "m"
    end

    if UcJDZByoyA:FindFirstChild("Timer") and UcJDZByoyA.Timer:IsA("StringValue") then
        BMgBPmvaLC = UcJDZByoyA.Timer.Value
    end

    return WofXwaDZQs, GMCoSHBXbs, cMdeBGRjqj, BMgBPmvaLC
end

local znzKNYJtqU kAbMpCjZWD()
    for _, obj in pairs(workspace:GetDescendants()) do
        if (obj:IsA("Model") or obj:IsA("BasePart")) and pFPLyVDiIc(obj.Name) then
            return obj
        end
    end
    return nil
end

local znzKNYJtqU lzdtGZfjcm()
    local jeWGQeHXyN = {}
    local nCdriEnoyj = "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/jeWGQeHXyN/Public?sortOrder=Asc&limit=100"

    local zkLUKJnwZn, result = pcall(znzKNYJtqU()
        return HttpService:JSONDecode(game:HttpGet(nCdriEnoyj))
    end)

    if zkLUKJnwZn and result and result.FobADidqDd then
        for _, server in ipairs(result.FobADidqDd) do
            if server.playing < server.maxPlayers and not IGTHLiHeVN[server.id] then
                table.insert(jeWGQeHXyN, server)
            end
        end
    end

    if #jeWGQeHXyN > 0 then
        return jeWGQeHXyN[math.random(1, #jeWGQeHXyN)]
    end

    return nil
end

local znzKNYJtqU mjodWpHTeL(serverInfo, CPtsDbFWYl, UcJDZByoyA)
    local WofXwaDZQs, GMCoSHBXbs, cMdeBGRjqj, BMgBPmvaLC = aRiURusxgO(UcJDZByoyA)
    local yHuuLddHBz = LocalPlayer.Name
    local fPwEgQUwIt = "https://www.roblox.com/games/" .. PLACE_ID .. "?CPtsDbFWYl=" .. CPtsDbFWYl
    local iJbMHmFogx = string.format("game:GetService(\"TeleportService\"):TeleportToPlaceInstance(\"%s\", \"%s\", game.Players.LocalPlayer)", tostring(PLACE_ID), CPtsDbFWYl)

    local FobADidqDd = {
        content = "Egg Found 🎉\nAn UcJDZByoyA with **" .. GMCoSHBXbs .. " Luck** has been discovered!",
        embeds = {{
            title = "🥚 Boost Egg Info",
            fields = {
                { name = "Egg Type", value = WofXwaDZQs, inline = true },
                { name = "Luck", value = GMCoSHBXbs, inline = true },
                { name = "Height", value = cMdeBGRjqj, inline = true },
                { name = "Server Slots", value = string.format("%d/%d", serverInfo.playing, serverInfo.maxPlayers), inline = true },
                { name = "Time Remaining", value = BMgBPmvaLC, inline = true },
                { name = "Found By", value = yHuuLddHBz, inline = true },
                { name = "Job ID", value = CPtsDbFWYl },
                { name = "Join Link", value = "[Web Browser](" .. fPwEgQUwIt .. ")" },
                { name = "Teleport Script", value = "```lua\n" .. iJbMHmFogx .. "\n```" }
            },
            color = 65280
        }}
    }

    local xbbPOPyKTY = HttpService:JSONEncode(FobADidqDd)

    local zkLUKJnwZn, response = pcall(znzKNYJtqU()
        return HttpService:PostAsync(WEBHOOK_URL, xbbPOPyKTY, Enum.HttpContentType.ApplicationJson)
    end)

    if zkLUKJnwZn then
        warn("✅ Webhook sent successfully!")
    else
        warn("❌ Failed to send webhook:", response)
    end
end

local znzKNYJtqU NRjXZsUTLD(UcJDZByoyA)
    local TnPphBTvqW = UcJDZByoyA.Name
    local LMBzSbWWoe = game:GetService("ReplicatedStorage")
    local iEIKmjpbQL = LMBzSbWWoe:FindFirstChild("RemoteEvents") or LMBzSbWWoe
    local xAaqOcTsMs = iEIKmjpbQL:FindFirstChild("OpenEgg")

    if xAaqOcTsMs and xAaqOcTsMs:IsA("RemoteEvent") then
        xAaqOcTsMs:FireServer(TnPphBTvqW, "Single")
        warn("🎉 Opened UcJDZByoyA:", TnPphBTvqW)
    else
        warn("❌ Could not find UcJDZByoyA-opening RemoteEvent.")
    end
end

local znzKNYJtqU ZGvdttDmtq()
    while true do
        task.wait(5)
        local UcJDZByoyA = kAbMpCjZWD()
        if UcJDZByoyA then
            local CPtsDbFWYl = game.JobId
            print("🎯 Boost UcJDZByoyA found:", UcJDZByoyA.Name)

            local PztmVFtEcM = {
                playing = #Players:GetPlayers(),
                maxPlayers = Players.MaxPlayers
            }

            mjodWpHTeL(PztmVFtEcM, CPtsDbFWYl, UcJDZByoyA)
            NRjXZsUTLD(UcJDZByoyA)
            break
        else
            local DuryJpXzOq = lzdtGZfjcm()
            if DuryJpXzOq then
                IGTHLiHeVN[DuryJpXzOq.id] = true
                warn("❌ No target UcJDZByoyA found. Hopping to another server...")
                TeleportService:TeleportToPlaceInstance(PLACE_ID, DuryJpXzOq.id, LocalPlayer)
                break
            else
                warn("⚠️ No unvisited jeWGQeHXyN found. Retrying...")
            end
        end
    end
end

ZGvdttDmtq()
