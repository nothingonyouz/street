-- ==========================================
--  Street Life Remastered - Local Hub
--  UI: VSCodeUILib
-- ==========================================

local currentRunId = math.random(1, 9999999)
getgenv().HubRunId = currentRunId

-- ==========================================
--             SETTINGS
-- ==========================================
getgenv().AutoClean    = getgenv().AutoClean    or false
getgenv().AutoRobCar   = getgenv().AutoRobCar   or false
getgenv().AutoBoxJob   = getgenv().AutoBoxJob   or false
getgenv().AutoDeposit  = getgenv().AutoDeposit  or false
getgenv().AutoCrypto   = getgenv().AutoCrypto   or false
getgenv().AutoESP      = getgenv().AutoESP      or false
getgenv().TotalCryptoProfit = getgenv().TotalCryptoProfit or 0
getgenv().TotalEthProfit    = getgenv().TotalEthProfit    or 0
getgenv().TotalDogeProfit   = getgenv().TotalDogeProfit   or 0
getgenv().AutoCryptoETH     = getgenv().AutoCryptoETH     or false
getgenv().AutoCryptoDOGE    = getgenv().AutoCryptoDOGE    or false

local depositTarget = getgenv().DepositTarget or 50000

-- ==========================================
--             SERVICES
-- ==========================================
local Players             = game:GetService("Players")
local player              = Players.LocalPlayer
local workspace           = game:GetService("Workspace")
local PathfindingService  = game:GetService("PathfindingService")
local TweenService        = game:GetService("TweenService")
local VirtualUser         = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService          = game:GetService("RunService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local UserInputService    = game:GetService("UserInputService")
local Camera              = workspace.CurrentCamera

-- ==========================================
--             ANTI-AFK
-- ==========================================
if getgenv().AntiAfkConnection then getgenv().AntiAfkConnection:Disconnect() end
getgenv().AntiAfkConnection = player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

local map        = workspace:WaitForChild("Map", 9e9)
local jobs       = map:WaitForChild("Jobs", 9e9)
local cleanNpc   = jobs:WaitForChild("CleanNPC", 9e9)
local cleanFolder= cleanNpc:WaitForChild("Clean", 9e9)
local atmsFolder = map:WaitForChild("ATMs", 9e9)

-- ==========================================
--             ESP FOLDER
-- ==========================================
local CoreGui = pcall(function() return game:GetService("CoreGui").Name end)
    and game:GetService("CoreGui") or player:WaitForChild("PlayerGui")

if CoreGui:FindFirstChild("StreetLifeESPFolder") then
    CoreGui.StreetLifeESPFolder:Destroy()
end
local espFolder = Instance.new("Folder")
espFolder.Name  = "StreetLifeESPFolder"
espFolder.Parent = CoreGui

-- ==========================================
--             SILENT AIM SETUP
-- ==========================================
getgenv().SilentAim = getgenv().SilentAim or false
local SA_FOV = getgenv().SA_FOV or 200

if player.PlayerGui:FindFirstChild("SilentAimFOV") then
    player.PlayerGui.SilentAimFOV:Destroy()
end
local fovGui = Instance.new("ScreenGui")
fovGui.Name = "SilentAimFOV"
fovGui.ResetOnSpawn = false
fovGui.IgnoreGuiInset = true
fovGui.Parent = player.PlayerGui

-- ==========================================
--   SILENT AIM SYSTEM (from src slient aim)
-- ==========================================
local SA_FOV_SA = 200  -- Silent Aim FOV (separate from Aimbot)

-- FOV circle
local fovCircle = Instance.new("Frame")
fovCircle.BackgroundTransparency = 1
fovCircle.BorderSizePixel = 0
fovCircle.Size = UDim2.fromOffset(SA_FOV_SA * 2, SA_FOV_SA * 2)
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.Parent = fovGui
Instance.new("UICorner", fovCircle).CornerRadius = UDim.new(1, 0)

local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Color3.fromRGB(255, 255, 255)
fovStroke.Thickness = 1.2
fovStroke.Transparency = 0.3
fovStroke.Parent = fovCircle

local fovDot = Instance.new("Frame")
fovDot.Size = UDim2.fromOffset(8, 8)
fovDot.AnchorPoint = Vector2.new(0.5, 0.5)
fovDot.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
fovDot.BorderSizePixel = 0
fovDot.Visible = false
fovDot.ZIndex = 2
fovDot.Parent = fovGui
Instance.new("UICorner", fovDot).CornerRadius = UDim.new(1, 0)

-- ---- Silent Aim target finder ----
local function getClosestSATarget()
    local mousePos = UserInputService:GetMouseLocation()
    local bestDist = SA_FOV_SA
    local bestHead, bestScreen = nil, nil
    local partName = getgenv().SATargetPart or "Head"
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == player then continue end
        local char = plr.Character
        if not char then continue end
        local hum = char:FindFirstChildWhichIsA("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        if getgenv().SATeamCheck and plr.Team and player.Team and plr.Team == player.Team then continue end
        local part = char:FindFirstChild(partName) or char:FindFirstChild("Head")
        if not part then continue end
        local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end
        local dist = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
        if dist < bestDist then
            bestDist = dist
            bestHead = part
            bestScreen = Vector2.new(sp.X, sp.Y)
        end
    end
    getgenv().CurrentAimTarget = bestHead and Players:GetPlayerFromCharacter(bestHead.Parent) or nil
    return bestHead, bestScreen
end

-- ---- Silent Aim render loop ----
if getgenv().SAFovLoop then getgenv().SAFovLoop:Disconnect() end
getgenv().SAFovLoop = RunService.RenderStepped:Connect(function()
    if getgenv().HubRunId ~= currentRunId then getgenv().SAFovLoop:Disconnect() return end
    local mousePos = UserInputService:GetMouseLocation()

    -- FOV circle follows mouse when SA enabled
    fovCircle.Visible = getgenv().SilentAim and (getgenv().SAShowFOV ~= false)
    if fovCircle.Visible then
        fovCircle.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
    end

    if getgenv().SilentAim then
        local head, screenPos = getClosestSATarget()
        if head and screenPos then
            fovDot.Visible   = true
            fovDot.Position  = UDim2.fromOffset(screenPos.X, screenPos.Y)
            fovStroke.Color  = Color3.fromRGB(255, 50, 50)
            fovStroke.Transparency = 0.1
        else
            fovDot.Visible   = false
            fovStroke.Color  = Color3.fromRGB(255, 255, 255)
            fovStroke.Transparency = 0.3
        end
    else
        fovDot.Visible = false
    end
end)

-- ---- Silent Aim bullet redirect ----
task.spawn(function()
    local ok, Projectile = pcall(require,
        ReplicatedStorage:WaitForChild("Modules", 5)
        and ReplicatedStorage.Modules:WaitForChild("GunFramework", 5)
        and ReplicatedStorage.Modules.GunFramework:WaitForChild("Modules", 5)
        and ReplicatedStorage.Modules.GunFramework.Modules:WaitForChild("Projectile", 5))
    if not ok or not Projectile then return end
    local originalNew = Projectile.new
    Projectile.new = function(params)
        if getgenv().SilentAim and params and params.Origin and params.Direction then
            local head = getClosestSATarget()
            if head then
                params.Direction = (head.Position - params.Origin).Unit
            end
        end
        return originalNew(params)
    end
end)

-- ==========================================
--   AIMBOT SYSTEM (separate, mouse-lock)
-- ==========================================
local AB_FOV = 200
getgenv().Aimbot       = getgenv().Aimbot       or false
getgenv().AimbotLocked = getgenv().AimbotLocked or false

-- Aimbot FOV circle (separate GUI)
if player.PlayerGui:FindFirstChild("AimbotFOVGui") then
    player.PlayerGui.AimbotFOVGui:Destroy()
end
local abGui = Instance.new("ScreenGui")
abGui.Name = "AimbotFOVGui"
abGui.ResetOnSpawn = false
abGui.IgnoreGuiInset = true
abGui.Parent = player.PlayerGui

local abCircle = Instance.new("Frame")
abCircle.BackgroundTransparency = 1
abCircle.BorderSizePixel = 0
abCircle.Size = UDim2.fromOffset(AB_FOV * 2, AB_FOV * 2)
abCircle.AnchorPoint = Vector2.new(0.5, 0.5)
abCircle.Visible = false
abCircle.Parent = abGui
Instance.new("UICorner", abCircle).CornerRadius = UDim.new(1, 0)
local abStroke = Instance.new("UIStroke")
abStroke.Color = Color3.fromRGB(255, 200, 0)
abStroke.Thickness = 1.5
abStroke.Transparency = 0.2
abStroke.Parent = abCircle

local function getClosestABTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local bestDist = AB_FOV
    local bestPart, bestPlr = nil, nil
    local partName = getgenv().AimbotPart or "Head"
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == player then continue end
        local char = plr.Character
        if not char then continue end
        local hum = char:FindFirstChildWhichIsA("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        if getgenv().SATeamCheck and plr.Team and player.Team and plr.Team == player.Team then continue end
        local part = char:FindFirstChild(partName) or char:FindFirstChild("Head")
        if not part then continue end
        local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end
        local dist = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
        if dist < bestDist then
            bestDist = dist; bestPart = part; bestPlr = plr
        end
    end
    return bestPart, bestPlr
end

local aimbotLoop
local function startAimbotLoop()
    if aimbotLoop then aimbotLoop:Disconnect(); aimbotLoop = nil end
    if not getgenv().Aimbot then abCircle.Visible = false return end
    aimbotLoop = RunService.RenderStepped:Connect(function()
        if not getgenv().Aimbot then aimbotLoop:Disconnect() abCircle.Visible = false return end
        local mousePos = UserInputService:GetMouseLocation()

        -- FOV circle always follows mouse when aimbot is on
        abCircle.Visible  = true
        abCircle.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)

        -- Only move mouse when lock key is held/toggled ON
        if not getgenv().AimbotLocked then return end

        -- Get target
        local part
        if getgenv().CurrentAimTarget then
            local char = getgenv().CurrentAimTarget.Character
            local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
            if char and hum and hum.Health > 0 then
                part = char:FindFirstChild(getgenv().AimbotPart or "Head") or char:FindFirstChild("Head")
            else
                getgenv().CurrentAimTarget = nil
            end
        end
        if not part then
            local bestPart, bestPlr = getClosestABTarget()
            part = bestPart
            if bestPlr then getgenv().CurrentAimTarget = bestPlr end
        end
        if not part then return end

        -- Velocity prediction
        local predPos = part.Position
        local pred = getgenv().AimbotPrediction or 0
        if pred > 0 and part.Parent:FindFirstChild("HumanoidRootPart") then
            predPos = predPos + (part.Parent.HumanoidRootPart.AssemblyLinearVelocity * pred)
        end

        local sp, onScreen = Camera:WorldToViewportPoint(predPos)
        if not onScreen then return end
        local smooth = getgenv().AimbotSmooth or 0.15
        local dx = (sp.X - mousePos.X) * smooth
        local dy = (sp.Y - mousePos.Y) * smooth

        -- PC: use mousemoverel / Mobile fallback: lerp camera
        local ok = pcall(function() mousemoverel(dx, dy) end)
        if not ok then
            Camera.CFrame = Camera.CFrame:Lerp(
                CFrame.new(Camera.CFrame.Position, predPos),
                math.clamp(smooth * 2, 0.05, 0.5)
            )
        end
    end)
end

-- ==========================================
--             LOAD UI LIBRARY
-- ==========================================
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/nothingonyouz/uirip/refs/heads/main/VSCodeUILib.lua"))()

-- Mobile-responsive sizing
local vp        = workspace.CurrentCamera.ViewportSize
local isMobile  = vp.X < 500
local isTablet  = vp.X >= 500 and vp.X < 900
-- Mobile: near full-screen, capped at 440h so buttons aren't cut
-- Tablet: slightly reduced width
-- PC: fixed 740x470
local winW = isMobile and math.min(math.floor(vp.X * 0.97), 480)
          or isTablet  and math.min(math.floor(vp.X * 0.90), 680)
          or 740
local winH = isMobile and math.min(math.floor(vp.Y * 0.80), 440)
          or isTablet  and 450
          or 470
local winSize = UDim2.new(0, winW, 0, winH)

-- Logo: split literal so obfuscators don't mangle the asset ID
-- 124163837094498  "1241" .. "63837" .. "094498"
local _logoStr = ("1241") .. ("63837") .. ("094498")
local _logoId  = tonumber(_logoStr)  -- resolves to 124163837094498

local Window = Library:CreateWindow({
    Title          = "Street Life Remastered",
    Subtitle       = "Street Life Remastered - Local Hub",
    Size           = winSize,
    ToggleKey      = Enum.KeyCode.RightShift,
    ConfigFolder   = "StreetLifeHub",
    Logo           = _logoId,
    TogglePosition = isMobile and "right" or "left",
})

Library:Notify({
    Title    = "Street Life Remastered",
    Text     = "Hub loaded. Press RightShift to toggle.",
    Type     = "success",
    Duration = 4,
})

-- ==========================================
--             TAB: FARM
-- ==========================================
local FarmTab     = Window:CreateTab({ Name = "Farm", Icon = "bolt" })
local farmSection = FarmTab:CreateSection("Auto Farm")

farmSection:CreateToggle({
    Name        = "Auto Clean Puddles",
    Description = "Auto clean puddles",
    Default     = getgenv().AutoClean,
    Flag        = "AutoClean",
    Callback    = function(state)
        getgenv().AutoClean = state
        if not state then
            getgenv()._cleanBusy = false
            local hum = player.Character and player.Character:FindFirstChild("Humanoid")
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if hum and hrp then hum:MoveTo(hrp.Position) end
        end
    end,
})

farmSection:CreateToggle({
    Name        = "Auto Rob Car",
    Description = "Auto rob cars",
    Default     = getgenv().AutoRobCar,
    Flag        = "AutoRobCar",
    Callback    = function(state)
        getgenv().AutoRobCar = state
        if not state then
            getgenv()._robBusy = false
            local hum = player.Character and player.Character:FindFirstChild("Humanoid")
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if hum and hrp then hum:MoveTo(hrp.Position) end
        end
    end,
})

farmSection:CreateToggle({
    Name        = "Auto Box Job",
    Description = "Auto box delivery job",
    Default     = getgenv().AutoBoxJob,
    Flag        = "AutoBoxJob",
    Callback    = function(state)
        getgenv().AutoBoxJob = state
        if not state then
            getgenv()._boxBusy = false
            local hum = player.Character and player.Character:FindFirstChild("Humanoid")
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if hum and hrp then hum:MoveTo(hrp.Position) end
        end
    end,
})

-- ==========================================
--         BANKING SECTION (FARM TAB)
-- ==========================================
local bankingSection = FarmTab:CreateSection("Banking")

-- ---- Deposit ----
bankingSection:CreateToggle({
    Name        = "Auto Deposit",
    Description = "Auto deposit on target",
    Default     = getgenv().AutoDeposit,
    Flag        = "AutoDeposit",
    Callback    = function(state) getgenv().AutoDeposit = state end,
})

bankingSection:CreateTextbox({
    Name        = "Deposit Target ($)",
    Description = "Deposit trigger amount",
    Placeholder = tostring(depositTarget),
    Default     = tostring(depositTarget),
    Flag        = "DepositTarget",
    Callback    = function(text)
        local num = tonumber(text)
        if num and num > 0 then depositTarget = num; getgenv().DepositTarget = num end
    end,
})

local depositOnceAmount = 0
bankingSection:CreateTextbox({
    Name        = "Deposit Amount ($)",
    Description = "Amount to deposit (0 = all)",
    Placeholder = "0 = deposit all",
    Default     = "",
    Flag        = "DepositOnceAmount",
    Callback    = function(text)
        local num = tonumber(text)
        depositOnceAmount = (num and num > 0) and math.floor(num) or 0
    end,
})

bankingSection:CreateButton({
    Name        = "Deposit",
    Description = "Deposit cash",
    Callback    = function()
        local moneyObj = player:FindFirstChild("Data") and player.Data:FindFirstChild("Money")
        local cash     = moneyObj and moneyObj.Value or 0
        if cash <= 0 then Library:Notify({ Title="Deposit", Text="No cash to deposit.", Type="warning", Duration=3 }) return end
        local amount = (depositOnceAmount > 0) and math.min(depositOnceAmount, cash) or cash
        local atm = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("ATM")
        if atm then atm:FireServer("Deposit", amount); Library:Notify({ Title="Deposit", Text="Deposited $"..amount, Type="success", Duration=3 })
        else Library:Notify({ Title="Deposit", Text="ATM remote not found.", Type="error", Duration=3 }) end
    end,
})

bankingSection:CreateDivider()

-- ---- Withdraw ----
local withdrawAmount = 0
bankingSection:CreateTextbox({
    Name        = "Withdraw Amount ($)",
    Description = "Amount to withdraw (0 = all)",
    Placeholder = "0 = withdraw all",
    Default     = "",
    Flag        = "WithdrawAmount",
    Callback    = function(text)
        local num = tonumber(text)
        withdrawAmount = (num and num > 0) and math.floor(num) or 0
    end,
})

bankingSection:CreateButton({
    Name        = "Withdraw",
    Description = "Withdraw from bank",
    Callback    = function()
        local bankObj = player:FindFirstChild("Data") and player.Data:FindFirstChild("Bank")
        local bank    = bankObj and bankObj.Value or 0
        if bank <= 0 then Library:Notify({ Title="Withdraw", Text="No money in bank.", Type="warning", Duration=3 }) return end
        local amount = (withdrawAmount > 0) and math.min(withdrawAmount, bank) or bank
        local atm = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("ATM")
        if atm then atm:FireServer("Withdraw", amount); Library:Notify({ Title="Withdraw", Text="Withdrew $"..amount, Type="success", Duration=3 })
        else Library:Notify({ Title="Withdraw", Text="ATM remote not found.", Type="error", Duration=3 }) end
    end,
})


--         WEBHOOK SECTION (FARM TAB)
-- ==========================================
local webhookSection = FarmTab:CreateSection("Discord Webhook")

local webhookURL       = ""
local webhookEnabled   = false
local lastMoneyValue   = 0
local webhookConnection

-- Generic webhook sender (used for start/stop/test notifications)
local function sendWebhook(title, description, color)
    if webhookURL == "" then return end
    local HttpService = game:GetService("HttpService")
    local body = HttpService:JSONEncode({
        username = "Street Life Hub",
        embeds = {{
            color       = color or 1752220,
            author      = { name = title },
            description = description,
 footer = { text = "Street Life Remastered ?? Local Hub" },
        }}
    })
    local fn = (syn and syn.request)
            or (http and http.request)
            or (typeof(request) == "function" and request)
            or (typeof(http_request) == "function" and http_request)
            or nil
    if fn then
        pcall(fn, {
            Url     = webhookURL,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = body,
        })
    end
end

-- Start / stop the Money.Changed listener
local function startWebhookMonitor()
    if webhookConnection then webhookConnection:Disconnect(); webhookConnection = nil end
    local moneyObj = player:FindFirstChild("Data") and player.Data:FindFirstChild("Money")
    if not moneyObj then
        Library:Notify({ Title = "Webhook", Text = "Data.Money not found.", Type = "error", Duration = 4 })
        return
    end
    lastMoneyValue = moneyObj.Value

    webhookConnection = moneyObj.Changed:Connect(function(newValue)
        if not webhookEnabled then return end

        local diff = newValue - lastMoneyValue
        if diff == 0 then lastMoneyValue = newValue return end

        local bankObj = player:FindFirstChild("Data") and player.Data:FindFirstChild("Bank")
        local bankVal = bankObj and math.floor(bankObj.Value) or 0
        local cash    = math.floor(newValue)
        local sign    = diff > 0 and "+" or "-"
        local absDiff = math.abs(math.floor(diff))
        local color   = diff > 0 and 3066993 or 15158332

        -- Reason detection
        local reason, emoji
        if diff > 0 then
            if getgenv().AutoClean then
                reason = "Puddle Cleaning"
                emoji  = "[Clean]"
            elseif getgenv().AutoRobCar then
                reason = "Car Robbery"
                emoji  = "[Rob]"
            elseif getgenv().AutoBoxJob then
                reason = "Box Job"
                emoji  = "[Box]"
            else
                reason = "Income"
                emoji  = "[+]"
            end
        else
            if getgenv().AutoDeposit and absDiff >= depositTarget * 0.9 then
                reason = "Auto Deposit"
                emoji  = "[Bank]"
            elseif getgenv().AutoDepositOnHit then
                reason = "Deposit on Hit"
                emoji  = "[Shield]"
            elseif absDiff >= depositTarget * 0.9 then
                reason = "Withdrawal / Deposit"
                emoji  = "[ATM]"
            else
                reason = "Expense"
                emoji  = "[-]"
            end
        end


        -- Format numbers with commas
        local function fmt(n)
            local s = tostring(math.floor(math.abs(n)))
            local result = ""
            local count = 0
            for i = #s, 1, -1 do
                count = count + 1
                result = s:sub(i, i) .. result
                if count % 3 == 0 and i ~= 1 then result = "," .. result end
            end
            return result
        end

        -- Progress bar: cash portion of total wealth
        local total  = math.max(cash + bankVal, 1)
        local barLen = 12
        local filled = math.floor((cash / total) * barLen)
        local bar    = string.rep("=", filled) .. string.rep("-", barLen - filled)

        local HttpService = game:GetService("HttpService")
        local body = HttpService:JSONEncode({
            username = "Street Life Hub",
            embeds = {{
                color  = color,
                author = { name = player.Name .. " | " .. emoji .. " " .. reason },
                fields = {
                    {
                        name   = "Cash",
                        value  = "$ " .. fmt(cash),
                        inline = true,
                    },
                    {
                        name   = "Bank",
                        value  = "$ " .. fmt(bankVal),
                        inline = true,
                    },
                    {
                        name   = "Change",
                        value  = sign .. "$ " .. fmt(absDiff),
                        inline = true,
                    },
                    {
                        name   = "Cash vs Total  [" .. fmt(cash) .. " / " .. fmt(total) .. "]",
                        value  = "[" .. bar .. "]",
                        inline = false,
                    },
                },
                footer = { text = "Street Life Remastered - Local Hub" },
            }}
        })

        local fn = (syn and syn.request)
                or (http and http.request)
                or (typeof(request) == "function" and request)
                or (typeof(http_request) == "function" and http_request)
                or nil
        if fn then
            pcall(fn, {
                Url     = webhookURL,
                Method  = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body    = body,
            })
        end

        lastMoneyValue = newValue
    end)

    Library:Notify({ Title = "Webhook", Text = "Monitor started.", Type = "success", Duration = 3 })
end

local function stopWebhookMonitor()
    if webhookConnection then webhookConnection:Disconnect(); webhookConnection = nil end
end

webhookSection:CreateTextbox({
    Name        = "Webhook URL",
    Description = "Discord webhook URL",
    Placeholder = "https://discord.com/api/webhooks/...",
    Default     = "",
    Flag        = "WebhookURL",
    Callback    = function(text, enter)
        webhookURL = text
    end,
})

webhookSection:CreateToggle({
    Name        = "Enable Money Alerts",
    Description = "Discord money alerts",
    Default     = false,
    Flag        = "WebhookEnabled",
    Callback    = function(state)
        webhookEnabled = state
        if state then
            if webhookURL == "" then
                Library:Notify({ Title = "Webhook", Text = "Enter a webhook URL first.", Type = "warning", Duration = 4 })
                webhookEnabled = false
                return
            end
            startWebhookMonitor()
            sendWebhook(
                "[Start] Monitoring Started - " .. player.Name,
                "Money alerts are now **active**.\nTracking `Data.Money` changes in real time.",
                3066993
            )
        else
            stopWebhookMonitor()
            if webhookURL ~= "" then
                sendWebhook(
                    "[Stop] Monitoring Stopped - " .. player.Name,
                    "Money alerts have been **disabled**.",
                    15158332
                )
            end
        end
    end,
})

webhookSection:CreateButton({
            "[Test] Test Message - " .. player.Name,
    Description = "Send test webhook message",
    Callback    = function()
        if webhookURL == "" then
            Library:Notify({ Title = "Webhook", Text = "Enter a webhook URL first.", Type = "warning", Duration = 4 })
            return
        end
        local moneyObj = player:FindFirstChild("Data") and player.Data:FindFirstChild("Money")
        local cash     = moneyObj and moneyObj.Value or 0
        sendWebhook(
            "[Test] Test Message - " .. player.Name,
            string.format("Webhook is working!\n**Current Balance:** $%s", tostring(math.floor(cash))),
            1752220
        )
    end,
})

-- ==========================================
--             TAB: CRYPTO
-- ==========================================
local CryptoTab = Window:CreateTab({ Name = "Crypto", Icon = "sliders" })

-- ---- BTC Section ----
local btcSection = CryptoTab:CreateSection("Bitcoin (BTC)")

local lblBtcPrice  = btcSection:CreateLabel("Live BTC: Loading...")
local lblBtcOwned  = btcSection:CreateLabel("Wallet: 0 / 20 BTC")
local lblBtcProfit = btcSection:CreateLabel("Session Profit: $0")

btcSection:CreateDivider()

btcSection:CreateToggle({
    Name        = "Smart Crypto AI Brain - BTC",
    Description = "Smart crypto trading",
    Default     = getgenv().AutoCrypto,
    Flag        = "AutoCrypto",
    Callback    = function(state) getgenv().AutoCrypto = state end,
})

btcSection:CreateButton({
    Name        = "Force Sell All BTC Now",
    Description = "Sell all BTC",
    Callback    = function()
        local phoneMisc    = ReplicatedStorage:FindFirstChild("Misc") and ReplicatedStorage.Misc:FindFirstChild("Phone")
        local currentPrice = phoneMisc and phoneMisc:FindFirstChild("Crypto") and phoneMisc.Crypto.Value
        local myBtc        = player:FindFirstChild("Data") and player.Data:FindFirstChild("Crypto") and player.Data.Crypto.Value
        local phoneRemote  = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Phone")
        if phoneRemote and currentPrice and myBtc and myBtc > 0 then
            for i = 1, myBtc do
                phoneRemote:FireServer("Crypto", "Sell", currentPrice)
                task.wait(0.1)
            end
            Library:Notify({ Title = "BTC", Text = "Sold " .. myBtc .. " BTC", Type = "success", Duration = 3 })
        else
            Library:Notify({ Title = "BTC", Text = "No BTC to sell.", Type = "warning", Duration = 3 })
        end
    end,
})

-- ---- [NEW] ETH Section ----
local ethSection = CryptoTab:CreateSection("Ethereum (ETH)")

local lblEthPrice  = ethSection:CreateLabel("Live ETH: Loading...")
local lblEthOwned  = ethSection:CreateLabel("Wallet: 0 / 20 ETH")
local lblEthProfit = ethSection:CreateLabel("Session Profit: $0")

ethSection:CreateDivider()

ethSection:CreateToggle({
    Name        = "Smart Crypto AI Brain - ETH",
    Description = "Smart crypto trading",
    Default     = false,
    Flag        = "AutoCryptoETH",
    Callback    = function(state) getgenv().AutoCryptoETH = state end,
})

ethSection:CreateButton({
    Name        = "Force Sell All ETH Now",
    Description = "Sell all ETH",
    Callback    = function()
        local phoneMisc    = ReplicatedStorage:FindFirstChild("Misc") and ReplicatedStorage.Misc:FindFirstChild("Phone")
        local currentPrice = phoneMisc and phoneMisc:FindFirstChild("ETH") and phoneMisc.ETH.Value
        local myEth        = player:FindFirstChild("Data") and player.Data:FindFirstChild("ETH") and player.Data.ETH.Value
        local phoneRemote  = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Phone")
        if phoneRemote and currentPrice and myEth and myEth > 0 then
            for i = 1, myEth do
                phoneRemote:FireServer("ETH", "Sell", currentPrice)
                task.wait(0.1)
            end
            Library:Notify({ Title = "ETH", Text = "Sold " .. myEth .. " ETH", Type = "success", Duration = 3 })
        else
            Library:Notify({ Title = "ETH", Text = "No ETH to sell.", Type = "warning", Duration = 3 })
        end
    end,
})

-- ---- [NEW] DOGE Section ----
local dogeSection = CryptoTab:CreateSection("Dogecoin (DOGE)")

local lblDogePrice  = dogeSection:CreateLabel("Live DOGE: Loading...")
local lblDogeOwned  = dogeSection:CreateLabel("Wallet: 0 / 20 DOGE")
local lblDogeProfit = dogeSection:CreateLabel("Session Profit: $0")

dogeSection:CreateDivider()

dogeSection:CreateToggle({
    Name        = "Smart Crypto AI Brain - DOGE",
    Description = "Smart crypto trading",
    Default     = false,
    Flag        = "AutoCryptoDOGE",
    Callback    = function(state) getgenv().AutoCryptoDOGE = state end,
})

dogeSection:CreateButton({
    Name        = "Force Sell All DOGE Now",
    Description = "Sell all DOGE",
    Callback    = function()
        local phoneMisc    = ReplicatedStorage:FindFirstChild("Misc") and ReplicatedStorage.Misc:FindFirstChild("Phone")
        local currentPrice = phoneMisc and phoneMisc:FindFirstChild("DOGE") and phoneMisc.DOGE.Value
        local myDoge       = player:FindFirstChild("Data") and player.Data:FindFirstChild("DOGE") and player.Data.DOGE.Value
        local phoneRemote  = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Phone")
        if phoneRemote and currentPrice and myDoge and myDoge > 0 then
            for i = 1, myDoge do
                phoneRemote:FireServer("DOGE", "Sell", currentPrice)
                task.wait(0.1)
            end
            Library:Notify({ Title = "DOGE", Text = "Sold " .. myDoge .. " DOGE", Type = "success", Duration = 3 })
        else
            Library:Notify({ Title = "DOGE", Text = "No DOGE to sell.", Type = "warning", Duration = 3 })
        end
    end,
})

-- ==========================================
--             TAB: ESP
-- ==========================================
local ESPTab      = Window:CreateTab({ Name = "ESP", Icon = "eye" })
local espSection  = ESPTab:CreateSection("Combat ESP")

local espFillColor    = Color3.fromRGB(255, 50,  50)
local espOutlineColor = Color3.fromRGB(255, 255, 255)
local espShowWeapon   = true
local espShowHealth   = true
local espShowDist     = true
local espShowTeam     = true
local espMaxDist      = 2000  -- studs

espSection:CreateToggle({
    Name        = "Enable Combat ESP",
    Description = "Show player ESP tags",
    Default     = getgenv().AutoESP,
    Flag        = "AutoESP",
    Callback    = function(state)
        getgenv().AutoESP = state
        if not state then
            for _, v in pairs(espFolder:GetChildren()) do
                if v:IsA("BillboardGui") then v.Enabled = false end
            end
            for _, p in pairs(Players:GetPlayers()) do
                if p.Character then
                    local hl = p.Character:FindFirstChild("StreetLifeHighlight")
                    if hl then hl.Enabled = false end
                end
            end
        end
    end,
})

espSection:CreateSlider({
    Name        = "Max Distance (studs)",
    Description = "ESP visibility range",
    Min = 100, Max = 5000, Default = espMaxDist,
    Flag        = "ESPMaxDist",
    Callback    = function(v)
        espMaxDist = v
        -- update existing BillboardGuis live
        for _, gui in pairs(espFolder:GetChildren()) do
            if gui:IsA("BillboardGui") then
                gui.MaxDistance = v
            end
        end
    end,
})

local espVisSection = ESPTab:CreateSection("Display Options")

espVisSection:CreateToggle({
    Name = "Show Weapon",       Default = true,  Flag = "ESPWeapon",
    Callback = function(v) espShowWeapon = v end,
})
espVisSection:CreateToggle({
    Name = "Show Health Bar",   Default = true,  Flag = "ESPHealth",
    Callback = function(v) espShowHealth = v end,
})
espVisSection:CreateToggle({
    Name = "Show Distance",     Default = true,  Flag = "ESPDist",
    Callback = function(v) espShowDist = v end,
})
espVisSection:CreateToggle({
    Name = "Team Color Highlight", Default = true, Flag = "ESPTeam",
    Callback = function(v) espShowTeam = v end,
})

espVisSection:CreateSlider({
    Name = "Tag Width", Description = "ESP card width in pixels",
    Min = 80, Max = 300, Default = 160, Flag = "ESPWidth",
    Callback = function(v)
        for _, gui in pairs(espFolder:GetChildren()) do
            if gui:IsA("BillboardGui") then
                gui.Size = UDim2.fromOffset(v, gui.Size.Y.Offset)
            end
        end
    end,
})

espVisSection:CreateSlider({
    Name = "Tag Height", Description = "ESP card height in pixels",
    Min = 40, Max = 120, Default = 56, Flag = "ESPHeight",
    Callback = function(v)
        for _, gui in pairs(espFolder:GetChildren()) do
            if gui:IsA("BillboardGui") then
                gui.Size = UDim2.fromOffset(gui.Size.X.Offset, v)
            end
        end
    end,
})

local espShowSkeleton = false
local espSkeletonColor = Color3.fromRGB(255, 255, 255)
local espSkeletonThickness = 1.5

espVisSection:CreateToggle({
    Name = "Show Skeleton", Default = false, Flag = "ESPSkeleton",
    Callback = function(v) espShowSkeleton = v
        if not v then
            -- clear existing skeleton lines
            for _, gui in pairs(espFolder:GetChildren()) do
                local sk = gui:FindFirstChild("SkeletonGui")
                if sk then sk:Destroy() end
            end
            -- hide all Drawing lines
            if getgenv()._skelLines then
                for _, playerLines in pairs(getgenv()._skelLines) do
                    for _, ln in pairs(playerLines) do
                        pcall(function() ln.Visible = false end)
                    end
                end
            end
        end
    end,
})

espVisSection:CreateSlider({
    Name = "Skeleton Thickness",
    Description = "Skeleton line thickness",
    Min = 1, Max = 5, Default = 1.5,
    Flag = "ESPSkeletonThickness",
    Callback = function(v)
        espSkeletonThickness = v
        -- update existing lines
        if getgenv()._skelLines then
            for _, playerLines in pairs(getgenv()._skelLines) do
                for _, ln in pairs(playerLines) do
                    pcall(function() ln.Thickness = v end)
                end
            end
        end
    end,
})

espVisSection:CreateDropdown({
    Name = "Skeleton Color",
    Description = "Skeleton line color",
    Options = { "White", "Red", "Orange", "Yellow", "Green", "Cyan", "Blue", "Purple", "Team Color" },
    Default = "White",
    Flag = "ESPSkeletonColor",
    Callback = function(v)
        local colorMap = {
            White  = Color3.fromRGB(255, 255, 255),
            Red    = Color3.fromRGB(255,  80,  80),
            Orange = Color3.fromRGB(255, 160,  40),
            Yellow = Color3.fromRGB(255, 240,  50),
            Green  = Color3.fromRGB( 80, 255, 100),
            Cyan   = Color3.fromRGB( 50, 220, 255),
            Blue   = Color3.fromRGB( 80, 130, 255),
            Purple = Color3.fromRGB(180,  80, 255),
        }
        if v == "Team Color" then
            espSkeletonColor = nil  -- will use team color dynamically
        else
            espSkeletonColor = colorMap[v] or Color3.fromRGB(255, 255, 255)
        end
    end,
})

-- ==========================================
--             TAB: SILENT AIM
-- ==========================================
local AimTab     = Window:CreateTab({ Name = "Silent Aim", Icon = "crosshair" })
local aimSection = AimTab:CreateSection("Silent Aim")

aimSection:CreateToggle({
    Name        = "Enable Silent Aim",
    Description = "Bullet redirect to target",
    Default     = getgenv().SilentAim,
    Flag        = "SilentAim",
    Callback    = function(state)
        getgenv().SilentAim = state
        if not state then fovCircle.Visible = false; fovDot.Visible = false end
    end,
})

aimSection:CreateSlider({
    Name = "FOV Radius", Min = 30, Max = 600, Default = SA_FOV_SA,
    Flag = "SilentAimFOV",
    Callback = function(v)
        SA_FOV_SA = v
        fovCircle.Size = UDim2.fromOffset(v * 2, v * 2)
    end,
})

aimSection:CreateDropdown({
    Name = "Target Part",
    Options = { "Head", "HumanoidRootPart", "UpperTorso", "LowerTorso" },
    Default = "Head", Flag = "SATargetPart",
    Callback = function(v) getgenv().SATargetPart = v end,
})

aimSection:CreateToggle({
    Name = "Show FOV Circle", Default = true, Flag = "SAShowFOV",
    Callback = function(state)
        getgenv().SAShowFOV = state
        if not state then fovCircle.Visible = false end
    end,
})

aimSection:CreateToggle({
    Name = "Team Check", Default = false, Flag = "SATeamCheck",
    Callback = function(v) getgenv().SATeamCheck = v end,
})

getgenv().BulletTracer    = getgenv().BulletTracer    or false
getgenv().TracerColor     = getgenv().TracerColor     or Color3.fromRGB(255, 80, 80)
getgenv().TracerDuration  = getgenv().TracerDuration  or 0.25
getgenv().TracerThickness = getgenv().TracerThickness or 2

do -- [SCOPE] TracerUI
local tracerSection = AimTab:CreateSection("Bullet Tracer")

tracerSection:CreateToggle({
    Name = "Enable Bullet Tracer",
    Description = "Shows a beam line where each bullet travels",
    Default = false, Flag = "BulletTracer",
    Callback = function(v) getgenv().BulletTracer = v end,
})

tracerSection:CreateSlider({
    Name = "Tracer Duration (s?100)",
    Description = "How long each tracer stays visible",
    Min = 5, Max = 100, Default = 25, Flag = "TracerDuration",
    Callback = function(v) getgenv().TracerDuration = v / 100 end,
})

tracerSection:CreateSlider({
    Name = "Tracer Thickness",
    Min = 1, Max = 8, Default = 2, Flag = "TracerThickness",
    Callback = function(v) getgenv().TracerThickness = v end,
})

tracerSection:CreateDropdown({
    Name = "Tracer Color",
    Options = { "Red", "Orange", "Yellow", "Green", "Cyan", "Blue", "Purple", "White" },
    Default = "Red", Flag = "TracerColorName",
    Callback = function(v)
        local colorMap = {
            Red    = Color3.fromRGB(255,  80,  80),
            Orange = Color3.fromRGB(255, 160,  40),
            Yellow = Color3.fromRGB(255, 240,  50),
            Green  = Color3.fromRGB(80,  255, 100),
            Cyan   = Color3.fromRGB(50,  220, 255),
            Blue   = Color3.fromRGB(80,  130, 255),
            Purple = Color3.fromRGB(180,  80, 255),
            White  = Color3.fromRGB(255, 255, 255),
        }
        getgenv().TracerColor = colorMap[v] or Color3.fromRGB(255, 80, 80)
    end,
})

end -- [/SCOPE] TracerUI

-- Tracer spawn helper stored in getgenv to avoid local register overflow
getgenv()._spawnTracer = function(origin, direction, hitDist)
    if not getgenv().BulletTracer then return end
    local dist     = hitDist or 500
    local col      = getgenv().TracerColor or Color3.fromRGB(255,80,80)
    local dur      = getgenv().TracerDuration or 0.25
    local thick    = getgenv().TracerThickness or 2

    -- Use two Attachments on a single Part to drive a Beam
    task.spawn(function()
        local folder = workspace:FindFirstChild("_TracerFolder")
        if not folder then
            folder = Instance.new("Folder")
            folder.Name = "_TracerFolder"
            folder.Parent = workspace
        end

        local endPos = origin + direction.Unit * dist

        -- root part (anchor)
        local root = Instance.new("Part")
        root.Anchored    = true
        root.CanCollide  = false
        root.Transparency = 1
        root.Size        = Vector3.new(0.1, 0.1, 0.1)
        root.CFrame      = CFrame.new(origin)
        root.Parent      = folder

        local a0 = Instance.new("Attachment", root)
        a0.Position = Vector3.zero

        local endPart = Instance.new("Part")
        endPart.Anchored    = true
        endPart.CanCollide  = false
        endPart.Transparency = 1
        endPart.Size        = Vector3.new(0.1, 0.1, 0.1)
        endPart.CFrame      = CFrame.new(endPos)
        endPart.Parent      = folder

        local a1 = Instance.new("Attachment", endPart)
        a1.Position = Vector3.zero

        local beam = Instance.new("Beam")
        beam.Attachment0  = a0
        beam.Attachment1  = a1
        beam.Color        = ColorSequence.new(col)
        beam.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 0.4),
        })
        beam.Width0       = thick * 0.05
        beam.Width1       = thick * 0.02
        beam.Segments     = 1
        beam.FaceCamera   = true
        beam.LightInfluence = 0
        beam.Parent       = root

        task.wait(dur)
        pcall(function() root:Destroy(); endPart:Destroy() end)
    end)
end

-- Hook into Projectile.new to intercept bullet origin+direction
task.spawn(function()
    local RS = game:GetService("ReplicatedStorage")
    local ok, Projectile = pcall(function()
        return require(
            RS:WaitForChild("Modules", 5)
            and RS.Modules:WaitForChild("GunFramework", 5)
            and RS.Modules.GunFramework:WaitForChild("Modules", 5)
            and RS.Modules.GunFramework.Modules:WaitForChild("Projectile", 5)
        )
    end)
    if not ok or not Projectile then return end

    if getgenv()._tracerOrigNew then return end  -- don't double-hook
    getgenv()._tracerOrigNew = Projectile.new

    Projectile.new = function(params)
        -- Fire tracer before bullet redirects (use original direction)
        if params and params.Origin and params.Direction then
            getgenv()._spawnTracer(params.Origin, params.Direction)
        end
        -- Silent Aim redirect (existing hook)
        if getgenv().SilentAim and params and params.Origin and params.Direction then
            local part = getSilentAimTarget and getSilentAimTarget()
            if part then
                params.Direction = (part.Position - params.Origin).Unit
            end
        end
        return getgenv()._tracerOrigNew(params)
    end
end)

-- ---- Aimbot Section ----
local aimbotSection = AimTab:CreateSection("Aimbot ( Support Mobile )")

aimbotSection:CreateToggle({
    Name        = "Enable Aimbot",
    Description = "Mouse aim toward target ? uses camera on mobile",
    Default     = getgenv().Aimbot,
    Flag        = "Aimbot",
    Callback    = function(state)
        getgenv().Aimbot = state
        if not state then
            getgenv().AimbotLocked = false
            getgenv().CurrentAimTarget = nil
            abCircle.Visible = false
        end
        startAimbotLoop()
    end,
})

-- Aimbot lock mode: Hold = hold key/button, Toggle = press to toggle
getgenv().AimbotLockMode = getgenv().AimbotLockMode or "Hold"

aimbotSection:CreateDropdown({
    Name     = "Lock Mode",
    Description = "Hold or toggle lock mode",
    Options  = { "Hold", "Toggle" },
    Default  = "Hold",
    Flag     = "AimbotLockMode",
    Callback = function(v)
        getgenv().AimbotLockMode = v
        getgenv().AimbotLocked = false
        getgenv().CurrentAimTarget = nil
    end,
})

aimbotSection:CreateKeybind({
    Name        = "Lock Key (PC)",
    Description = "Hold mode: hold to aim | Toggle mode: press to switch",
    Default     = Enum.KeyCode.Q,
    Flag        = "AimbotLockKey",
    Callback    = function(key)
        if not getgenv().Aimbot then return end
        if getgenv().AimbotLockMode == "Toggle" then
            getgenv().AimbotLocked = not getgenv().AimbotLocked
            if not getgenv().AimbotLocked then getgenv().CurrentAimTarget = nil end
        end
    end,
})

-- Mobile AIM button (on-screen, only shown when aimbot enabled)
local aimBtnGui = Instance.new("ScreenGui")
aimBtnGui.Name = "AimbotMobileBtn"
aimBtnGui.ResetOnSpawn = false
aimBtnGui.IgnoreGuiInset = true
aimBtnGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
aimBtnGui.Parent = player.PlayerGui

local aimMobileBtn = Instance.new("TextButton")
aimMobileBtn.Size = UDim2.fromOffset(72, 72)
aimMobileBtn.Position = UDim2.new(1, -90, 0.5, -36)
aimMobileBtn.AnchorPoint = Vector2.new(0, 0)
aimMobileBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
aimMobileBtn.BackgroundTransparency = 0.25
aimMobileBtn.TextColor3 = Color3.fromRGB(255, 200, 0)
aimMobileBtn.Text = "AIM"
aimMobileBtn.Font = Enum.Font.GothamBlack
aimMobileBtn.TextSize = 17
aimMobileBtn.AutoButtonColor = false
aimMobileBtn.Visible = false  -- shown only when aimbot is ON
aimMobileBtn.Parent = aimBtnGui
local _abCorner = Instance.new("UICorner", aimMobileBtn)
_abCorner.CornerRadius = UDim.new(1, 0)
local _abStroke = Instance.new("UIStroke", aimMobileBtn)
_abStroke.Color = Color3.fromRGB(255, 200, 0)
_abStroke.Thickness = 2

-- touch press: activate aim
aimMobileBtn.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch
    or i.UserInputType == Enum.UserInputType.MouseButton1 then
        if not getgenv().Aimbot then return end
        if getgenv().AimbotLockMode == "Hold" then
            getgenv().AimbotLocked = true
        else
            getgenv().AimbotLocked = not getgenv().AimbotLocked
            if not getgenv().AimbotLocked then getgenv().CurrentAimTarget = nil end
        end
        local active = getgenv().AimbotLocked
        aimMobileBtn.BackgroundColor3 = active and Color3.fromRGB(255, 200, 0) or Color3.fromRGB(18, 18, 22)
        aimMobileBtn.TextColor3 = active and Color3.fromRGB(20, 20, 20) or Color3.fromRGB(255, 200, 0)
    end
end)
-- touch release: if Hold mode, release lock
aimMobileBtn.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch
    or i.UserInputType == Enum.UserInputType.MouseButton1 then
        if getgenv().AimbotLockMode == "Hold" then
            getgenv().AimbotLocked = false
            getgenv().CurrentAimTarget = nil
            aimMobileBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
            aimMobileBtn.TextColor3 = Color3.fromRGB(255, 200, 0)
        end
    end
end)

-- Show/hide mobile button when Aimbot toggle changes
-- (hooked inside the toggle callback via RunService)
RunService.Heartbeat:Connect(function()
    aimMobileBtn.Visible = getgenv().Aimbot == true
end)

-- Hold mode: UIS keyboard support
if getgenv().AimbotHoldConn then getgenv().AimbotHoldConn:Disconnect() end
if getgenv().AimbotHoldEndConn then getgenv().AimbotHoldEndConn:Disconnect() end

getgenv().AimbotHoldConn = UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    local lockKey = getgenv()["AimbotLockKey"] or Enum.KeyCode.Q
    if input.KeyCode == lockKey and getgenv().Aimbot and getgenv().AimbotLockMode == "Hold" then
        getgenv().AimbotLocked = true
    end
end)

getgenv().AimbotHoldEndConn = UserInputService.InputEnded:Connect(function(input)
    local lockKey = getgenv()["AimbotLockKey"] or Enum.KeyCode.Q
    if input.KeyCode == lockKey and getgenv().AimbotLockMode == "Hold" then
        getgenv().AimbotLocked = false
        getgenv().CurrentAimTarget = nil
    end
end)

aimbotSection:CreateSlider({
    Name        = "Smoothness",
    Description = "Higher = slower, smoother aim",
    Min = 1, Max = 100, Default = 15,
    Flag        = "AimbotSmooth",
    Callback    = function(v) getgenv().AimbotSmooth = v / 100 end,
})

aimbotSection:CreateSlider({
    Name        = "Prediction",
    Description = "Lead target based on velocity (0 = off)",
    Min = 0, Max = 50, Default = 0,
    Flag        = "AimbotPrediction",
    Callback    = function(v) getgenv().AimbotPrediction = v / 100 end,
})

aimbotSection:CreateDropdown({
    Name        = "Aim Part",
    Description = "Body part to aim at",
    Options     = { "Head", "HumanoidRootPart", "UpperTorso", "LowerTorso" },
    Default     = "Head",
    Flag        = "AimbotPart",
    Callback    = function(v)
        getgenv().AimbotPart   = v
        getgenv().SATargetPart = v
    end,
})

aimbotSection:CreateSlider({
    Name        = "FOV Radius",
    Description = "Aimbot scan radius in pixels",
    Min = 30, Max = 600, Default = 200,
    Flag        = "AimbotFOV",
    Callback    = function(v)
        AB_FOV = v
        abCircle.Size = UDim2.fromOffset(v * 2, v * 2)
    end,
})

aimbotSection:CreateToggle({
    Name        = "Team Check",
    Description = "Skip players on your team",
    Default     = false,
    Flag        = "AimbotTeamCheck",
    Callback    = function(v) getgenv().SATeamCheck = v end,
})

-- ==========================================
--         TAB: SHOP (All Categories)
-- ==========================================
local ShopTab = Window:CreateTab({ Name = "Shop", Icon = "home" })

-- ?? remote helpers ??????????????????????????????????????????????
local function _gunRemote()
    return ReplicatedStorage:FindFirstChild("Remotes")
        and ReplicatedStorage.Remotes:FindFirstChild("GunBuy")
end
-- Remotes.Buy ???????? Mask/Vest/Merchant/Supplies ?????????????????
local function _buyRemote()
    return ReplicatedStorage:FindFirstChild("Remotes")
        and ReplicatedStorage.Remotes:FindFirstChild("Buy")
end
local function _suppliesRemote() return _buyRemote() end
local function _merchantRemote() return _buyRemote() end

-- ?? helper: build dropdown label + map ??????????????????????????
local function buildDropdown(list)
    -- list = { { label, remoteName, price, extra... }, ... }
    local opts, map = {}, {}
    for _, v in ipairs(list) do
        table.insert(opts, v[1])
        map[v[1]] = v
    end
    return opts, map
end

-- ????????????????????????????????????????????????
-- 1. FIREARMS
-- ????????????????????????????????????????????????
do -- [SCOPE] Firearms
local gunSection = ShopTab:CreateSection("Firearms")
local gunList = {
    { "Ruger ($800)",           "Ruger",       800  },
    { "Makarov ($1000)",        "Makarov",     1000 },
    { "Glock17 ($1200)",        "Glock17",     1200 },
    { "M&P9 ($2500)",           "M&P9",        2500 },
    { "Mac ($3000) [Lv.3]",     "Mac",         3000 },
    { "Tec-9 ($3500) [Lv.5]",   "Tec-9",       3500 },
    { "Thompson ($4000)",       "Thompson",    4000 },
    { "G36C ($4000)",           "G36C",        4000 },
    { "Spas ($4500)",           "Spas",        4500 },
    { "UMP ($4800) [Lv.5]",     "UMP",         4800 },
    { "AK-12 ($5000)",          "AK-12",       5000 },
    { "Perun ($5000)",          "Perun",       5000 },
    { "Shotgun ($5000) [Lv.5]", "Shotgun",     5000 },
    { "AUG ($5000) [Lv.5]",     "AUG",         5000 },
    { "ARPistol ($5000) [Lv.5]","ARPistol",    5000 },
    { "Glock19X ($5000) [Lv.3]","Glock19X",    5000 },
    { "Draco ($5200) [Lv.5]",   "Draco",       5200 },
    { "GlockSwitch ($5400) [Lv.5]","GlockSwitch",5400},
    { "HoneyBadger ($5500) [Lv.5]","HoneyBadger",5500},
    { "AK-47 ($6500) [Lv.5]",  "AK-47",       6500 },
    { "Vector ($7000) [Lv.5]",  "Vector",      7000 },
    { "BinaryG17 ($7000) [Lv.10]","BinaryG17", 7000 },
    { "MP5 ($7500) [Lv.10]",    "MP5",         7500 },
    { "Micro Uzi ($7500)",      "Micro Uzi",   7500 },
    { "Famas ($8000)",          "Famas",       8000 },
    { "TSR-15 ($8000) [Lv.10]", "TSR-15",      8000 },
    { "AKS-74U ($8500) [Lv.15]","AKS-74U",    8500 },
    { "Hi-Point ($500)",        "Hi-Point",     500 },
    { "SpringFieldXDExt ($1500)","SpringFieldXDExt",1500},
    { "FullyMicroARP ($6000) [Lv.5]","FullyMicroARP",6000},
    { "ProPad ($3000)",         "ProPad",      3000 },
}
local gunOpts, gunMap = buildDropdown(gunList)
local selGun = gunOpts[1]
gunSection:CreateDropdown({
    Name = "Select Gun", Options = gunOpts, Default = gunOpts[1], Flag = "ShopGun",
    Callback = function(v) selGun = v end,
})
gunSection:CreateButton({
    Name = "Buy Gun",
    Callback = function()
        local r = _gunRemote(); local g = gunMap[selGun]
        if r and g then
            r:FireServer(g[2], g[3])
            Library:Notify({ Title="Shop", Text="Bought "..g[2], Type="success", Duration=2 })
        else
            Library:Notify({ Title="Shop", Text="Remote not found", Type="error", Duration=3 })
        end
    end,
})
end -- [/SCOPE] Firearms

-- ?? Ammo ????????????????????????????????????????????????????????
do -- [SCOPE] Ammo
local ammoSection = ShopTab:CreateSection("Ammo")
local ammoList = {
    { "Pistol Ammo (x50)",  "Pistol Ammo",  50  },
    { "Shotgun Ammo (x100)","Shotgun Ammo", 100 },
    { "SMG Ammo (x100)",    "SMG Ammo",     100 },
    { "Rifle Ammo (x100)",  "Rifle Ammo",   100 },
}
local ammoOpts, ammoMap = buildDropdown(ammoList)
local selAmmo = ammoOpts[1]
ammoSection:CreateDropdown({
    Name = "Select Ammo", Options = ammoOpts, Default = ammoOpts[1], Flag = "ShopAmmo",
    Callback = function(v) selAmmo = v end,
})
ammoSection:CreateButton({
    Name = "Buy Ammo",
    Callback = function()
        local r = _gunRemote(); local a = ammoMap[selAmmo]
        if r and a then
            r:FireServer(a[2], a[3])
            Library:Notify({ Title="Shop", Text="Bought "..a[2], Type="success", Duration=2 })
        else
            Library:Notify({ Title="Shop", Text="Remote not found", Type="error", Duration=3 })
        end
    end,
})

end -- [/SCOPE] Ammo

-- ?? Supplies / Gear ?????????????????????????????????????????????
-- ?? Seeds / Farm ????????????????????????????????????????????????
do -- [SCOPE] Seeds
local seedSection = ShopTab:CreateSection("Seeds & Farm")
-- remote: Remotes.Supplies:FireServer("Lemon")
local function _seedRemote()
    return ReplicatedStorage:FindFirstChild("Remotes")
        and ReplicatedStorage.Remotes:FindFirstChild("Supplies")
end
local seedList = {
    { "Tomato",    "Tomato"    },
    { "SunFlower", "SunFlower" },
    { "Pumpkin",   "Pumpkin"   },
    { "Lemon",     "Lemon"     },
}
local seedOpts = {}; local seedNames = {}
for _, v in ipairs(seedList) do
    table.insert(seedOpts, v[1])
    seedNames[v[1]] = v[2]
end
local selSeed = seedOpts[1]
seedSection:CreateDropdown({
    Name = "Select Seed", Options = seedOpts, Default = seedOpts[1], Flag = "ShopSeed",
    Callback = function(v) selSeed = v end,
})
seedSection:CreateButton({
    Name = "Buy Seed",
    Callback = function()
        local r = _seedRemote()
        local name = seedNames[selSeed]
        if r and name then
            r:FireServer(name)
            Library:Notify({ Title="Seeds", Text="Bought "..name, Type="success", Duration=2 })
        else
            Library:Notify({ Title="Seeds", Text="Remote not found.", Type="error", Duration=3 })
        end
    end,
})
end -- [/SCOPE] Seeds

-- ?? Merchant ??????????????????????????????????????????????????
do -- [SCOPE] Merchant
local merchantSection = ShopTab:CreateSection("Merchant")
-- remote: Remotes.Buy:FireServer(name, price)
local merchantList = {
    { "MentosBag",  "MentosBag",  300  },
    { "C4",         "C4",         2000 },
    { "Bat",        "Bat",        750  },
    { "Card",       "Card",       1000 },
    { "Knife",      "Knife",      500  },
    { "DuffleBag",  "DuffleBag",  500  },
    { "LockPick",   "LockPick",   500  },
    { "Firework",   "Firework",   500  },
}
local merchantOpts, merchantMap = buildDropdown(merchantList)
local selMerchant = merchantOpts[1]
merchantSection:CreateDropdown({
    Name = "Select Item", Options = merchantOpts, Default = merchantOpts[1], Flag = "ShopMerchant",
    Callback = function(v) selMerchant = v end,
})
merchantSection:CreateButton({
    Name = "Buy from Merchant",
    Callback = function()
        local r = _buyRemote()
        local m = merchantMap[selMerchant]
        if r and m then
            r:FireServer(m[2], m[3])
            Library:Notify({ Title="Merchant", Text="Bought "..m[2], Type="success", Duration=2 })
        else
            Library:Notify({ Title="Merchant", Text="Remote not found.", Type="error", Duration=3 })
        end
    end,
})
end -- [/SCOPE] Merchant

-- ?? Buy Mask ?????????????????????????????????????????????????????
do -- [SCOPE] Mask
local maskSection = ShopTab:CreateSection("Buy Mask")
-- remote: Remotes.Buy:FireServer(name, qty)
local maskList = {
    { "SkiMask",    "SkiMask",    50  },
    { "Bandana",    "Bandana",    50  },
    { "HackerMask", "HackerMask", 75  },
    { "RedSki",     "RedSki",     75  },
    { "BlueSki",    "BlueSki",    75  },
    { "Balaclava",  "Balaclava",  50  },
    { "ClownMask",  "ClownMask",  75  },
    { "GhostFace",  "GhostFace",  100 },
    { "Jason Mask", "Jason Mask", 100 },
}
local maskOpts, maskMap = buildDropdown(maskList)
local selMask = maskOpts[1]
maskSection:CreateDropdown({
    Name = "Select Mask", Options = maskOpts, Default = maskOpts[1], Flag = "ShopMask",
    Callback = function(v) selMask = v end,
})
maskSection:CreateButton({
    Name = "Buy Mask",
    Callback = function()
        local r = _buyRemote()
        local m = maskMap[selMask]
        if r and m then
            r:FireServer(m[2], m[3])
            Library:Notify({ Title="Mask", Text="Bought "..m[2], Type="success", Duration=2 })
        else
            Library:Notify({ Title="Mask", Text="Remote not found.", Type="error", Duration=3 })
        end
    end,
})
end -- [/SCOPE] Mask

local MiscTab = Window:CreateTab({ Name = "Misc", Icon = "person" })

-- ---- Anti AFK ----
local miscAfkSection = MiscTab:CreateSection("Anti AFK")

-- Auto true on load anti afk already runs at top, this just makes it visible/controllable
miscAfkSection:CreateToggle({
    Name        = "Anti AFK",
 Description = "Prevent AFK kick enabled automatically on load",
    Default     = true,
    Flag        = "AntiAFK",
    Callback    = function(state)
        if getgenv().AntiAfkConnection then
            getgenv().AntiAfkConnection:Disconnect()
            getgenv().AntiAfkConnection = nil
        end
        if state then
            getgenv().AntiAfkConnection = player.Idled:Connect(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end,
})

-- ---- Infinity Stamina ----
local miscStamSection = MiscTab:CreateSection("Stamina")
local staminaLoop

miscStamSection:CreateToggle({
    Name        = "Infinity Stamina",
    Description = "Max stamina always",
    Default     = false,
    Flag        = "InfStamina",
    Callback    = function(state)
        if state then
            staminaLoop = RunService.Heartbeat:Connect(function()
                local ok = pcall(function()
                    player.Data.Stamina.Value = 99999999
                end)
                if not ok then end
            end)
        else
            if staminaLoop then staminaLoop:Disconnect(); staminaLoop = nil end
        end
    end,
})

-- ---- Float / Hover ----
local miscFloatSection = MiscTab:CreateSection("Float / Hover")
local floatEnabled  = false
local floatHeight   = getgenv().FloatHeight or 5   -- studs above ground
local floatLoop

local function updateFloat()
    if floatLoop then floatLoop:Disconnect(); floatLoop = nil end
    if not floatEnabled then return end

    floatLoop = RunService.Heartbeat:Connect(function()
        if getgenv().HubRunId ~= currentRunId then floatLoop:Disconnect() return end
        local char = player.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChild("Humanoid")
        if not (hrp and hum) then return end

        local params = RaycastParams.new()
        params.FilterDescendantsInstances = { char }
        params.FilterType = Enum.RaycastFilterType.Exclude
        local result  = workspace:Raycast(hrp.Position, Vector3.new(0, -(floatHeight + 80), 0), params)
        local groundY = result and result.Position.Y or (hrp.Position.Y - floatHeight)
        local targetY = groundY + floatHeight

        -- AlignPosition: stable hover, XZ completely free
        local att = hrp:FindFirstChild("FloatAtt")
        if not att then
            att        = Instance.new("Attachment")
            att.Name   = "FloatAtt"
            att.Parent = hrp
        end
        local ap = hrp:FindFirstChild("FloatAlignPos")
        if not ap then
            ap                     = Instance.new("AlignPosition")
            ap.Name                = "FloatAlignPos"
            ap.Mode                = Enum.PositionAlignmentMode.OneAttachment
            ap.Attachment0         = att
            ap.MaxForce            = 100000
            ap.MaxVelocity         = 50
            ap.Responsiveness      = 35
            ap.ForceLimitMode      = Enum.ForceLimitMode.PerAxis
            ap.MaxAxesForce        = Vector3.new(0, 100000, 0)  -- Y only
            ap.RigidityEnabled     = false
            ap.Parent              = hrp
        end
        ap.Position = Vector3.new(hrp.Position.X, targetY, hrp.Position.Z)
    end)
end

miscFloatSection:CreateToggle({
    Name        = "Enable Float",
    Description = "Float at fixed height",
    Default     = false,
    Flag        = "FloatEnabled",
    Callback    = function(state)
        floatEnabled = state
        if not state then
            local char = player.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local ap  = hrp:FindFirstChild("FloatAlignPos")
                local att = hrp:FindFirstChild("FloatAtt")
                if ap  then ap:Destroy()  end
                if att then att:Destroy() end
            end
        end
        updateFloat()
    end,
})

miscFloatSection:CreateSlider({
    Name        = "Float Height (studs)",
    Description = "Float height (studs)",
    Min         = 1, Max = 50, Default = floatHeight,
    Flag        = "FloatHeight",
    Callback    = function(v)
        floatHeight = v
        getgenv().FloatHeight = v
    end,
})

-- ---- Anti Ragdoll ----
local miscRagSection = MiscTab:CreateSection("Anti Ragdoll")

miscRagSection:CreateButton({
    Name        = "Apply Anti Ragdoll",
    Description = "Remove ragdoll scripts",
    Callback    = function()
        local targets = {
            {game:GetService("CoreGui"),          "RobloxGui/CoreScripts/PlayerRagdoll"},
            {game:GetService("CoreGui"),          "RobloxGui/Modules/Common/RagdollRigging"},
            {game:GetService("ReplicatedStorage"), "Remotes/Ragdoll"},
            {game:GetService("ReplicatedStorage"), "CmdrClient/Commands/ragdoll"},
            {game:GetService("StarterPlayer"),    "StarterCharacterScripts/Ragdoll"},
        }
        local removed = 0
        for _, entry in ipairs(targets) do
            local root, path = entry[1], entry[2]
            local parts = string.split(path, "/")
            local obj = root
            for _, part in ipairs(parts) do
                obj = obj and obj:FindFirstChild(part)
            end
            if obj then
                pcall(function() obj:Destroy() end)
                removed = removed + 1
            end
        end
        -- Also disable on current character via BallSocketConstraints
        local char = player.Character
        if char then
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") then
                    pcall(function() v.Enabled = false end)
                end
            end
        end
        Library:Notify({
            Title    = "Anti Ragdoll",
            Text     = "Removed " .. removed .. " ragdoll instance(s). Constraints disabled.",
            Type     = "success",
            Duration = 4,
        })
    end,
})

miscRagSection:CreateToggle({
    Name        = "Auto Anti Ragdoll on Respawn",
    Description = "Auto anti-ragdoll on respawn",
    Default     = false,
    Flag        = "AutoAntiRagdoll",
    Callback    = function(state)
        if state then
            player.CharacterAdded:Connect(function(char)
                if not getgenv()["AutoAntiRagdoll"] then return end
                task.wait(1)
                for _, v in ipairs(char:GetDescendants()) do
                    if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") then
                        pcall(function() v.Enabled = false end)
                    end
                end
                local ragRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Ragdoll")
                if ragRemote then pcall(function() ragRemote:Destroy() end) end
            end)
        end
    end,
})

-- ==========================================
--        INF AMMO / GUN MODS
-- ==========================================
local miscGunSection = MiscTab:CreateSection("Inf Ammo / Gun Mods")

getgenv().InfAmmo  = getgenv().InfAmmo  or false
getgenv().NoRecoil = getgenv().NoRecoil or false

miscGunSection:CreateToggle({
    Name = "Infinite Ammo",
    Description = "Keeps ammo/clip at 999 every frame",
    Default = getgenv().InfAmmo, Flag = "InfAmmo",
    Callback = function(v) getgenv().InfAmmo = v end,
})
miscGunSection:CreateToggle({
    Name = "No Recoil",
    Description = "Compensates camera pitch kick when shooting",
    Default = getgenv().NoRecoil, Flag = "NoRecoil",
    Callback = function(v) getgenv().NoRecoil = v end,
})

do
    local _shoot, _prevPitch = false, nil
    local _cam = workspace.CurrentCamera
    if getgenv()._infAmmoConn  then getgenv()._infAmmoConn:Disconnect()  end
    if getgenv()._shootConn    then getgenv()._shootConn:Disconnect()    end
    if getgenv()._shootEndConn then getgenv()._shootEndConn:Disconnect() end
    getgenv()._shootConn = UserInputService.InputBegan:Connect(function(i, gp)
        if gp then return end
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            _shoot = true; _prevPitch = nil
        end
    end)
    getgenv()._shootEndConn = UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            _shoot = false; _prevPitch = nil
        end
    end)
    getgenv()._infAmmoConn = RunService.Stepped:Connect(function()
        local char = player.Character; if not char then return end
        if getgenv().InfAmmo then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then
                for _, v in pairs(tool:GetDescendants()) do
                    if v:IsA("IntValue") or v:IsA("NumberValue") then
                        local n = string.lower(v.Name)
                        if string.find(n,"ammo") or string.find(n,"clip") or string.find(n,"mag") then v.Value = 999 end
                    end
                end
                for name, val in pairs(tool:GetAttributes()) do
                    local n = string.lower(name)
                    if type(val)=="number" and (string.find(n,"ammo") or string.find(n,"clip")) then
                        tool:SetAttribute(name, 999)
                    end
                end
            end
        end
        if getgenv().NoRecoil and _shoot then
            local _, curPitch = _cam.CFrame:ToEulerAnglesYXZ()
            if _prevPitch ~= nil then
                local delta = curPitch - _prevPitch
                if delta < -0.0008 then
                    local comp = math.deg(-delta) * (_cam.ViewportSize.Y / _cam.FieldOfView) * 0.85
                    pcall(function() mousemoverel(0, comp) end)
                end
            end
            _prevPitch = curPitch
        elseif not _shoot then _prevPitch = nil end
    end)
end

-- ==========================================
--        COMBAT PROTECTION
-- ==========================================
local miscCombatSection = MiscTab:CreateSection("Combat Protection")

getgenv().AutoDepositOnHit = getgenv().AutoDepositOnHit or false
local depositOnHitConn

local function setupDepositOnHit(enabled)
    if depositOnHitConn then depositOnHitConn:Disconnect(); depositOnHitConn = nil end
    if not enabled then return end

    local char = player.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local lastHp = hum.Health
    depositOnHitConn = hum.HealthChanged:Connect(function(newHp)
        if not getgenv().AutoDepositOnHit then return end
 -- = HP
        if newHp < lastHp then
            local moneyObj = player:FindFirstChild("Data") and player.Data:FindFirstChild("Money")
            local cash = moneyObj and moneyObj.Value or 0
            if cash > 0 then
                local atmRemote = ReplicatedStorage:FindFirstChild("Remotes")
                    and ReplicatedStorage.Remotes:FindFirstChild("ATM")
                if atmRemote then
                    atmRemote:FireServer("Deposit", cash)
                    Library:Notify({ Title = "Combat Protection", Text = "Deposited $"..math.floor(cash).." (took damage)", Type = "warning", Duration = 3 })
                end
            end
        end
        lastHp = newHp
    end)
end

-- re-setup on respawn
player.CharacterAdded:Connect(function()
    task.wait(1)
    if getgenv().AutoDepositOnHit then
        setupDepositOnHit(true)
    end
end)

miscCombatSection:CreateToggle({
    Name        = "Auto Deposit on Hit",
    Description = "Auto deposit on hit",
    Default     = getgenv().AutoDepositOnHit,
    Flag        = "AutoDepositOnHit",
    Callback    = function(state)
        getgenv().AutoDepositOnHit = state
        setupDepositOnHit(state)
    end,
})

-- ---- Escape Death ----
getgenv().EscapeDeath = getgenv().EscapeDeath or false
local escapeConn

local function setupEscapeDeath(enabled)
    if escapeConn then escapeConn:Disconnect(); escapeConn = nil end
    if not enabled then return end

    local char = player.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not (hum and hrp) then return end

    escapeConn = hum.HealthChanged:Connect(function(newHp)
        if not getgenv().EscapeDeath then return end
        if newHp > 0 and newHp < 50 then
 -- 100 studs HP = 100
            local safePos = hrp.CFrame * CFrame.new(0, 100, 0)
            hrp.CFrame = safePos

 -- keep re-anchoring 0.1
            local holdConn
            holdConn = RunService.Heartbeat:Connect(function()
                if not getgenv().EscapeDeath or hum.Health <= 0 then
                    holdConn:Disconnect()
                    return
                end
                if hum.Health >= 100 then
                    holdConn:Disconnect()
 -- HP
                    hrp.CFrame = safePos * CFrame.new(0, -100, 0)
                    return
                end
 --
                if (hrp.Position - safePos.Position).Magnitude > 5 then
                    hrp.CFrame = safePos
                end
            end)
        end
    end)
end

player.CharacterAdded:Connect(function()
    task.wait(1)
    if getgenv().EscapeDeath then setupEscapeDeath(true) end
end)

miscCombatSection:CreateToggle({
    Name        = "Escape Death",
    Description = "Escape when low HP",
    Default     = getgenv().EscapeDeath,
    Flag        = "EscapeDeath",
    Callback    = function(state)
        getgenv().EscapeDeath = state
        setupEscapeDeath(state)
    end,
})

-- ---- Camera / Noclip ----
local miscCamSection = MiscTab:CreateSection("Camera / Noclip")

-- Camera Noclip:
getgenv().CamNoclip = getgenv().CamNoclip or false
local camNoclipConn
local camNoclipChanged = {}  -- { [part] = originalCanCollide }

miscCamSection:CreateToggle({
    Name        = "Camera Noclip",
    Description = "Camera clips through walls",
    Default     = getgenv().CamNoclip,
    Flag        = "CamNoclip",
    Callback    = function(state)
        getgenv().CamNoclip = state
        if camNoclipConn then camNoclipConn:Disconnect(); camNoclipConn = nil end

 -- restore part
        for part, orig in pairs(camNoclipChanged) do
            pcall(function() part.CanCollide = orig end)
        end
        camNoclipChanged = {}

        if not state then return end

        camNoclipConn = RunService.RenderStepped:Connect(function()
            if not getgenv().CamNoclip then
                camNoclipConn:Disconnect()
                for part, orig in pairs(camNoclipChanged) do
                    pcall(function() part.CanCollide = orig end)
                end
                camNoclipChanged = {}
                return
            end

            local cam  = workspace.CurrentCamera
            local char = player.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            if not (cam and hrp) then return end

            local camPos = cam.CFrame.Position
            local hrpPos = hrp.Position

 -- restore parts frame raycast
            for part, orig in pairs(camNoclipChanged) do
                pcall(function() part.CanCollide = orig end)
            end
            camNoclipChanged = {}

 -- raycast HRP
            local params = RaycastParams.new()
            params.FilterDescendantsInstances = { char, cam }
            params.FilterType = Enum.RaycastFilterType.Exclude

            local dir = hrpPos - camPos
            local remaining = dir
            local origin = camPos
 -- cast HRP part
            for _ = 1, 10 do
                local result = workspace:Raycast(origin, remaining, params)
                if not result then break end
                local part = result.Instance
                if part and part:IsA("BasePart") and not part.Locked then
                    if camNoclipChanged[part] == nil then
                        camNoclipChanged[part] = part.CanCollide
                    end
                    part.CanCollide = false
 -- part filter cast
                    params.FilterDescendantsInstances = { char, cam, part }
                    local hit = result.Position
                    local newDir = hrpPos - hit
                    if newDir.Magnitude < 0.1 then break end
                    origin    = hit + newDir.Unit * 0.01
                    remaining = hrpPos - origin
                else
                    break
                end
            end
        end)
    end,
})

-- Noclip:
getgenv().Noclip = getgenv().Noclip or false
local noclipConn

miscCamSection:CreateToggle({
    Name        = "Noclip",
    Description = "Character clips through walls",
    Default     = getgenv().Noclip,
    Flag        = "Noclip",
    Callback    = function(state)
        getgenv().Noclip = state
        if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
        if state then
            noclipConn = RunService.Stepped:Connect(function()
                if not getgenv().Noclip then noclipConn:Disconnect() return end
                local char = player.Character
                if not char then return end
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end)
        else
            local char = player.Character
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = true end
                end
            end
        end
    end,
})

-- FOV: lock RenderStepped
local fovLocked   = 70
local fovLockConn
miscCamSection:CreateSlider({
    Name        = "Camera FOV",
    Description = "Lock camera FOV (game won't reset it)",
    Min         = 30, Max = 120, Default = 70,
    Flag        = "CameraFOV",
    Callback    = function(v)
        fovLocked = v
        workspace.CurrentCamera.FieldOfView = v
        if not fovLockConn then
            fovLockConn = RunService.RenderStepped:Connect(function()
                if workspace.CurrentCamera.FieldOfView ~= fovLocked then
                    workspace.CurrentCamera.FieldOfView = fovLocked
                end
            end)
        end
    end,
})

miscCamSection:CreateButton({
    Name        = "Reset FOV",
    Description = "Reset FOV to 70",
    Callback    = function()
        fovLocked = 70
        if fovLockConn then fovLockConn:Disconnect(); fovLockConn = nil end
        workspace.CurrentCamera.FieldOfView = 70
        Library:Notify({ Title = "Camera", Text = "FOV reset to 70", Type = "info", Duration = 2 })
    end,
})

-- ==========================================
--        MISC: EQUIP GLOVES
-- ==========================================
do -- [SCOPE] Gloves
local miscGloveSection = MiscTab:CreateSection("Equip Gloves")
local gloveColors = { "Black", "Blue", "Cyan", "Green", "Grey", "Indigo", "Orange", "Red", "Violet", "White", "Yellow" }
local selectedGlove = "Black"
local gloveRgbRunning = false

local function equipGlove(color)
    local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Gloves")
    if remote then remote:FireServer(color) end
end

miscGloveSection:CreateDropdown({
    Name = "Glove Color", Description = "Select glove color",
    Options = gloveColors, Default = "Black", Flag = "GloveColor",
    Callback = function(v) selectedGlove = v end,
})
miscGloveSection:CreateButton({
    Name = "Equip Glove", Description = "Equip glove",
    Callback = function()
        equipGlove(selectedGlove)
        Library:Notify({ Title="Gloves", Text="Equipped "..selectedGlove, Type="success", Duration=2 })
    end,
})
miscGloveSection:CreateToggle({
    Name = "RGB Gloves", Description = "RGB cycle glove colors",
    Default = false, Flag = "GloveRGB",
    Callback = function(state)
        gloveRgbRunning = state
        if not state then return end
        task.spawn(function()
            local i = 1
            while gloveRgbRunning do
                local color = gloveColors[i]
                local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Gloves")
                if remote then remote:FireServer(color) end
                i = (i % #gloveColors) + 1
                task.wait(0.15)
            end
        end)
    end,
})
end -- [/SCOPE] Gloves

-- ==========================================
-- ==========================================
--     INVENTORY VIEWER (?? Misc)
-- ==========================================
do -- [SCOPE] Inventory
local invSection    = MiscTab:CreateSection("Inventory Viewer")
local selectedInvPlayer = ""

local function getPlayerNames()
    local names = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then table.insert(names, plr.Name) end
    end
    if #names == 0 then table.insert(names, "(No other players)") end
    return names
end

local invDropdown = invSection:CreateDropdown({
    Name = "Select Player", Options = getPlayerNames(),
    Default = getPlayerNames()[1] or "", Flag = "InvPlayer",
    Callback = function(v) selectedInvPlayer = v end,
})

local lblInvName   = invSection:CreateLabel("Name: -")
local lblInvCash   = invSection:CreateLabel("Cash: -")
local lblInvBank   = invSection:CreateLabel("Bank: -")
local lblInvLevel  = invSection:CreateLabel("Level: -")
local lblInvHealth = invSection:CreateLabel("Health: -")
local lblInvTeam   = invSection:CreateLabel("Team: -")
local lblInvTool1  = invSection:CreateLabel("Tools: -")

invSection:CreateButton({
    Name = "View Inventory",
    Callback = function()
        if selectedInvPlayer == "" or selectedInvPlayer == "(No other players)" then
            Library:Notify({ Title="Inventory", Text="Select a player first.", Type="warning", Duration=3 })
            return
        end
        local target = Players:FindFirstChild(selectedInvPlayer)
        if not target then
            Library:Notify({ Title="Inventory", Text="Player not found.", Type="error", Duration=3 })
            return
        end
        local data  = target:FindFirstChild("Data")
        local cash  = data and data:FindFirstChild("Money") and math.floor(data.Money.Value) or "N/A"
        local bank  = data and data:FindFirstChild("Bank")  and math.floor(data.Bank.Value)  or "N/A"
        local level = data and data:FindFirstChild("Level") and data.Level.Value or "N/A"
        local char  = target.Character
        local hum   = char and char:FindFirstChildWhichIsA("Humanoid")
        local hp    = hum and math.floor(hum.Health).."/"..math.floor(hum.MaxHealth) or "N/A"
        local team  = target.Team and target.Team.Name or "None"
        local tools = {}
        if char then for _, v in pairs(char:GetChildren()) do if v:IsA("Tool") then table.insert(tools, v.Name) end end end
        lblInvName:Set("Name: "..target.Name)
        lblInvCash:Set("Cash: $"..tostring(cash))
        lblInvBank:Set("Bank: $"..tostring(bank))
        lblInvLevel:Set("Level: "..tostring(level))
        lblInvHealth:Set("Health: "..hp)
        lblInvTeam:Set("Team: "..team)
        lblInvTool1:Set("Tools: "..(#tools > 0 and table.concat(tools, ", ") or "None"))
        Library:Notify({ Title="Inventory", Text="Loaded "..target.Name, Type="success", Duration=2 })
    end,
})
invSection:CreateButton({
    Name = "Refresh Player List",
    Callback = function()
        invDropdown:Refresh(getPlayerNames())
        Library:Notify({ Title="Inventory", Text="Refreshed.", Type="info", Duration=2 })
    end,
})
end -- [/SCOPE] Inventory

-- ==========================================
--     CAR MODS (?? Misc)
-- ==========================================
do -- [SCOPE] Vehicles

-- ?? Car Mods ?????????????????????????????????????????????????????
local carModSection = MiscTab:CreateSection("Car Mods")

getgenv().CarFly         = getgenv().CarFly         or false
getgenv().CarSpeed       = getgenv().CarSpeed       or false
getgenv().CarSpeedAmount = getgenv().CarSpeedAmount or 150

carModSection:CreateToggle({
    Name = "Car Fly", Description = "Fly your vehicle with WASD",
    Default = false, Flag = "CarFly",
    Callback = function(v) getgenv().CarFly = v end,
})
carModSection:CreateToggle({
    Name = "Car Speed Boost", Description = "Boost car speed",
    Default = false, Flag = "CarSpeedBoost",
    Callback = function(v) getgenv().CarSpeed = v end,
})
carModSection:CreateSlider({
    Name = "Speed Amount", Min = 50, Max = 500, Default = 150, Flag = "CarSpeedAmount",
    Callback = function(v) getgenv().CarSpeedAmount = v end,
})

if getgenv()._carModConn then getgenv()._carModConn:Disconnect() end
getgenv()._carModConn = RunService.Stepped:Connect(function(_, dt)
    local char = player.Character; if not char then return end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local inCar = hum and hum.SeatPart and hum.SeatPart:IsA("VehicleSeat")
    if not inCar then return end
    local seat = hum.SeatPart
    local cam  = workspace.CurrentCamera
    if getgenv().CarSpeed and not getgenv().CarFly and seat.AssemblyLinearVelocity.Magnitude > 5 then
        seat.AssemblyLinearVelocity = seat.AssemblyLinearVelocity + (seat.CFrame.LookVector * (getgenv().CarSpeedAmount * dt))
    end
    if getgenv().CarFly then
        local spd = getgenv().CarSpeedAmount
        local vel = Vector3.new(0,0,0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) or seat.Throttle == 1  then vel = vel + cam.CFrame.LookVector  * spd end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) or seat.Throttle == -1 then vel = vel - cam.CFrame.LookVector  * spd end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) or seat.Steer == -1    then vel = vel - cam.CFrame.RightVector * spd end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) or seat.Steer == 1     then vel = vel + cam.CFrame.RightVector * spd end
        seat.AssemblyLinearVelocity  = vel
        seat.AssemblyAngularVelocity = Vector3.new(0,0,0)
    end
end)

-- Mobile FLY button
local carFlyBtnGui = Instance.new("ScreenGui")
carFlyBtnGui.Name = "CarFlyMobileBtn"
carFlyBtnGui.ResetOnSpawn = false
carFlyBtnGui.IgnoreGuiInset = true
carFlyBtnGui.Parent = player.PlayerGui
local carFlyBtn = Instance.new("TextButton")
carFlyBtn.Size = UDim2.fromOffset(65, 65)
carFlyBtn.Position = UDim2.new(1, -80, 0.7, -32)
carFlyBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
carFlyBtn.BackgroundTransparency = 0.25
carFlyBtn.TextColor3 = Color3.fromRGB(100, 200, 255)
carFlyBtn.Text = "FLY"
carFlyBtn.Font = Enum.Font.GothamBlack
carFlyBtn.TextSize = 15
carFlyBtn.AutoButtonColor = false
carFlyBtn.Visible = false
carFlyBtn.Parent = carFlyBtnGui
Instance.new("UICorner", carFlyBtn).CornerRadius = UDim.new(1, 0)
local _cfStk = Instance.new("UIStroke", carFlyBtn)
_cfStk.Color = Color3.fromRGB(100, 200, 255); _cfStk.Thickness = 2
carFlyBtn.MouseButton1Click:Connect(function()
    getgenv().CarFly = not getgenv().CarFly
    local on = getgenv().CarFly
    carFlyBtn.BackgroundColor3 = on and Color3.fromRGB(100,200,255) or Color3.fromRGB(18,18,22)
    carFlyBtn.TextColor3       = on and Color3.fromRGB(20,20,20)    or Color3.fromRGB(100,200,255)
end)
RunService.Heartbeat:Connect(function()
    local c = player.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    carFlyBtn.Visible = h and h.SeatPart and h.SeatPart:IsA("VehicleSeat") or false
end)

end -- [/SCOPE] Vehicles

-- ==========================================
--          TAB: STORAGE
-- ==========================================
do -- [SCOPE] Storage
local StorageTab   = Window:CreateTab({ Name = "Storage", Icon = "minus" })
local storeSection = StorageTab:CreateSection("Trunk / Storage")

-- Open StorageUI button
storeSection:CreateButton({
    Name = "Open Storage UI",
    Description = "Clone StorageUI from Misc and open it",
    Callback = function()
        local misc = ReplicatedStorage:FindFirstChild("Misc")
        local tmpl = misc and misc:FindFirstChild("StorageUI")
        if not tmpl then
            Library:Notify({ Title="Storage", Text="StorageUI not found.", Type="error", Duration=3 })
            return
        end
        local existing = player.PlayerGui:FindFirstChild("StorageUI")
        if existing then existing:Destroy() end
        local clone = tmpl:Clone()
        clone.Parent = player.PlayerGui
        pcall(function() clone.Enabled = true end)
        Library:Notify({ Title="Storage", Text="Storage UI opened.", Type="success", Duration=2 })
    end,
})

local function _storageRemote()
    return ReplicatedStorage:FindFirstChild("Remotes")
        and ReplicatedStorage.Remotes:FindFirstChild("Storage")
end

local GUN_KEYWORDS = {
    "ruger","makarov","glock","m&p","mac","tec","thompson","g36","spas","ump",
    "ak","perun","shotgun","aug","arpistol","draco","honeybadger","vector",
    "binary","mp5","uzi","famas","tsr","aks","hi-point","springfield",
    "fullymicro","propad","pistol ammo","smg ammo","rifle ammo","shotgun ammo",
    "c4","rpg","lockpick","switch","drum","skorpion",
}
local function isGun(name)
    local low = string.lower(name)
    for _, kw in ipairs(GUN_KEYWORDS) do
        if string.find(low, kw, 1, true) then return true end
    end
    return false
end
local function getStorageGuns()
    local guns = {}
    pcall(function()
        local scroll = player.PlayerGui:FindFirstChild("StorageUI")
            and player.PlayerGui.StorageUI:FindFirstChild("Main")
            and player.PlayerGui.StorageUI.Main:FindFirstChild("BackpackScroll")
        if scroll then
            for _, child in ipairs(scroll:GetChildren()) do
                local lbl = child:FindFirstChild("TextLabel")
                if lbl and lbl.Text ~= "" and lbl.Text ~= "BackpackTemplate" then
                    if isGun(lbl.Text) then table.insert(guns, lbl.Text) end
                end
            end
        end
    end)
    if #guns == 0 then table.insert(guns, "(Open StorageUI first)") end
    return guns
end
local function getBackpackGuns()
    local guns = {}
    local function scan(parent)
        for _, tool in ipairs(parent:GetChildren()) do
            if tool:IsA("Tool") and isGun(tool.Name) then
                table.insert(guns, tool.Name)
            end
        end
    end
    if player.Character then scan(player.Character) end
    scan(player.Backpack)
    if #guns == 0 then table.insert(guns, "(No guns in backpack)") end
    return guns
end

local selStorageGun, selBackpackGun = "", ""

local storageDropdown = storeSection:CreateDropdown({
    Name = "Storage Guns", Options = getStorageGuns(),
    Default = getStorageGuns()[1] or "", Flag = "StorageGun",
    Callback = function(v) selStorageGun = v end,
})
storeSection:CreateButton({
    Name = "Grab from Storage",
    Callback = function()
        if selStorageGun == "" or selStorageGun == "(Open StorageUI first)" then
            Library:Notify({ Title="Storage", Text="Select a gun first.", Type="warning", Duration=3 })
            return
        end
        local r = _storageRemote()
        if r then r:FireServer("Grab", selStorageGun)
            Library:Notify({ Title="Storage", Text="Grabbed "..selStorageGun, Type="success", Duration=2 })
        else
            Library:Notify({ Title="Storage", Text="Remote not found.", Type="error", Duration=3 })
        end
    end,
})
storeSection:CreateButton({
    Name = "Refresh Storage List",
    Callback = function()
        storageDropdown:Refresh(getStorageGuns())
        Library:Notify({ Title="Storage", Text="Refreshed.", Type="info", Duration=2 })
    end,
})

local depositSection = StorageTab:CreateSection("Deposit to Storage")
local backpackDropdown = depositSection:CreateDropdown({
    Name = "Backpack Guns", Options = getBackpackGuns(),
    Default = getBackpackGuns()[1] or "", Flag = "BackpackGun",
    Callback = function(v) selBackpackGun = v end,
})
depositSection:CreateButton({
    Name = "Deposit to Storage",
    Callback = function()
        if selBackpackGun == "" or selBackpackGun == "(No guns in backpack)" then
            Library:Notify({ Title="Storage", Text="Select a gun first.", Type="warning", Duration=3 })
            return
        end
        local r = _storageRemote()
        if r then r:FireServer("Deposit", selBackpackGun)
            Library:Notify({ Title="Storage", Text="Deposited "..selBackpackGun, Type="success", Duration=2 })
        else
            Library:Notify({ Title="Storage", Text="Remote not found.", Type="error", Duration=3 })
        end
    end,
})
depositSection:CreateButton({
    Name = "Refresh Backpack List",
    Callback = function()
        backpackDropdown:Refresh(getBackpackGuns())
        Library:Notify({ Title="Storage", Text="Refreshed.", Type="info", Duration=2 })
    end,
})
end -- [/SCOPE] Storage

-- ==========================================
--          TAB: OPEN UI
-- ==========================================
do -- [SCOPE] OpenUI
local OpenUITab = Window:CreateTab({ Name = "Open UI", Icon = "info" })
local uiSection = OpenUITab:CreateSection("Game UIs (Clone & Open)")

local UI_LIST = {
    "GunStoreUI","MaskUI","MerchantUI","SuppliesUI","StorageUI",
    "TrunkUI","BlackMarketUI","CarDealerUI","GarageUI","GlovesUI",
    "DripUI","ClothingUI","TattooUI","JewelryUI","GiftingUI",
    "WheelUI","DailyUI","LootingUI","ComputerUI","PDCamerasUI",
    "ProPadUI","RadioUI","BoomboxUI","GymUI","ChickenUI",
    "DeliUI","FlashUI","FrostyUI","TheIceUI","ChangelogUI",
    "BoatDealerUI","BoatStationUI","StationUI","CarUI","SecurityCameraUI",
    "PunchBagUI","ReloadUI","OnboardingUI","TrollBanUI",
}
local selUI = UI_LIST[1]
uiSection:CreateDropdown({
    Name = "Select UI", Options = UI_LIST, Default = UI_LIST[1], Flag = "OpenUISelect",
    Callback = function(v) selUI = v end,
})
uiSection:CreateButton({
    Name = "Open Selected UI",
    Description = "Clone from ReplicatedStorage.Misc  PlayerGui",
    Callback = function()
        local misc = ReplicatedStorage:FindFirstChild("Misc")
        if not misc then
            Library:Notify({ Title="Open UI", Text="Misc not found.", Type="error", Duration=3 })
            return
        end
        local tmpl = misc:FindFirstChild(selUI)
        if not tmpl then
            Library:Notify({ Title="Open UI", Text=selUI.." not in Misc.", Type="error", Duration=3 })
            return
        end
        local existing = player.PlayerGui:FindFirstChild(selUI)
        if existing then existing:Destroy() end
        local clone = tmpl:Clone()
        clone.Parent = player.PlayerGui
        pcall(function() clone.Enabled = true end)
        pcall(function()
            for _, v in ipairs(clone:GetDescendants()) do
                if v:IsA("Frame") or v:IsA("ScrollingFrame") then
                    v.Visible = true
                end
            end
        end)
        Library:Notify({ Title="Open UI", Text="Opened "..selUI, Type="success", Duration=2 })
    end,
})
uiSection:CreateButton({
    Name = "Close Selected UI",
    Callback = function()
        local existing = player.PlayerGui:FindFirstChild(selUI)
        if existing then
            existing:Destroy()
            Library:Notify({ Title="Open UI", Text="Closed "..selUI, Type="info", Duration=2 })
        else
            Library:Notify({ Title="Open UI", Text=selUI.." not open.", Type="warning", Duration=2 })
        end
    end,
})
end -- [/SCOPE] OpenUI

-- ==========================================
--             TAB: SETTINGS
-- ==========================================
local SettingsTab = Window:CreateTab({ Name = "Settings", Icon = "settings" })
SettingsTab:CreateConfigSection("Config Manager")

local infoSection = SettingsTab:CreateSection("About")
infoSection:CreateLabel("Street Life Remastered - Local Hub")
infoSection:CreateLabel("Made by LocalscriptX")
infoSection:CreateKeybind({
    Name        = "UI Toggle Key",
    Description = "UI toggle key",
    Default     = Enum.KeyCode.RightShift,
    Flag        = "ui_toggle",
    Callback    = function(key) Window:SetToggleKey(key) end,
})
infoSection:CreateButton({
    Name     = "Unload UI",
    Callback = function() Window:Destroy() end,
})

-- ==========================================
--             HELPER FUNCTIONS
-- ==========================================
-- Pathfinding walk with sprint (hold LeftShift via VirtualInputManager), checks toggle each waypoint
local function walkTo(targetPosition, checkToggle)
    local char = player.Character
    local hum  = char and char:FindFirstChild("Humanoid")
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not (hum and hrp and hum.Health > 0) then return false end

    local function stopShift()
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
    end
    local function toggleOff()
        return checkToggle and not getgenv()[checkToggle]
    end

    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game)

    local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
    local ok   = pcall(function() path:ComputeAsync(hrp.Position, targetPosition) end)
    if ok and path.Status == Enum.PathStatus.Success then
        for _, wp in ipairs(path:GetWaypoints()) do
            if getgenv().HubRunId ~= currentRunId then stopShift() return false end
            if hum.Health <= 0                    then stopShift() return false end
            if toggleOff()                         then stopShift() hum:MoveTo(hrp.Position) return false end
            hum:MoveTo(wp.Position)
            local t = 0
            while t < 20 and (hrp.Position - wp.Position).Magnitude > 4 do
                if hum.Health <= 0 then stopShift() return false end
                if toggleOff()     then stopShift() hum:MoveTo(hrp.Position) return false end
                task.wait(0.1); t = t + 1
            end
        end
    end

    stopShift()
    return true
end

local function getClosestPuddle()
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local closest, best = nil, math.huge
    for _, v in pairs(cleanFolder:GetChildren()) do
        if v:IsA("BasePart") then
            local prompt = v:FindFirstChildOfClass("ProximityPrompt")
            if prompt and prompt.Enabled then
                local d = (hrp.Position - v.Position).Magnitude
                if d < best then best = d; closest = v end
            end
        end
    end
    return closest
end

-- Returns closest car's H part (regardless of highlight state - we check after arriving)
local function getClosestRobCar(blacklist)
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, nil, nil end
    local interactions = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Interactions")
    if not interactions then return nil, nil, nil end

    local closest, bestDist, bestH, bestPrompt = nil, math.huge, nil, nil
    for _, car in pairs(interactions:GetChildren()) do
        local window = car:FindFirstChild("Window")
        if not window then continue end
        local hPart = window:FindFirstChild("H")
        if not hPart then continue end
 -- blacklisted cars
        if blacklist and blacklist[hPart] then continue end

        local prompt = hPart:FindFirstChildOfClass("ProximityPrompt")
        if not prompt then continue end

        local d = (hrp.Position - hPart.Position).Magnitude
        if d < bestDist then
            bestDist   = d
            closest    = car
            bestH      = hPart
            bestPrompt = prompt
        end
    end
    return closest, bestH, bestPrompt
end

local function getClosestATM()
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local atmModels = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("ATMModels")
    if not atmModels then return nil end
    local closest, best = nil, math.huge
    for _, atm in ipairs(atmModels:GetChildren()) do
 -- BasePart reference
        local ref = atm:FindFirstChildWhichIsA("BasePart") or (atm:IsA("BasePart") and atm)
        if ref then
            local d = (hrp.Position - ref.Position).Magnitude
            if d < best then best = d; closest = atm end
        end
    end
    return closest
end

function performDeposit(forceAll)
    local moneyObj = player:FindFirstChild("Data") and player.Data:FindFirstChild("Money")
    local cash     = moneyObj and moneyObj.Value or 0
    local amount   = forceAll and cash or depositTarget
    if cash <= 0 or amount <= 0 then return end
 -- / fire ATM remote
    local atmRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("ATM")
    if atmRemote then
        atmRemote:FireServer("Deposit", amount)
    end
end

-- ==========================================
--        BOX JOB HELPERS
-- ==========================================

-- Waypoints Take <-> Deliver ( Take Deliver)
-- Waypoints Take -> Deliver (WP1=, WP3=)
getgenv()._BOX_WAYPOINTS = {
    Vector3.new(167.904694, 53.0421753, 272.030823),  -- WP1
    Vector3.new(132.276764, 66.7908478, 272.213104),  -- WP2
    Vector3.new(131.682892, 66.7908554, 256.117126),  -- WP3
}

local function walkThroughWaypoints(waypoints, toggleName)
    for i, pos in ipairs(waypoints) do
        if not getgenv()[toggleName] then return false end
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        if (hrp.Position - pos).Magnitude < 8 then
            print("[BoxJob] WP" .. i .. " skipped (already close)")
            continue
        end
        print("[BoxJob] Walking to WP" .. i .. " -> " .. tostring(pos))
        local ok = walkTo(pos, toggleName)
        print("[BoxJob] WP" .. i .. " reached:", ok)
        if not ok then return false end
        task.wait(0.2)
    end
    return true
end

local function reverseTable(t)
    local r = {}
    for i = #t, 1, -1 do r[#r+1] = t[i] end
    return r
end

local function getBoxPoint(name)
    local boxJob = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Jobs")
        and workspace.Map.Jobs:FindFirstChild("BoxJob")
    if not boxJob then return nil, nil end
    local point = boxJob:FindFirstChild(name)
    if not point then return nil, nil end
    local pos = point:IsA("BasePart") and point.Position
        or (point.PrimaryPart and point.PrimaryPart.Position)
        or (point:FindFirstChildWhichIsA("BasePart") and point:FindFirstChildWhichIsA("BasePart").Position)
    return point, pos
end

local function performTakeBox()
    if not getgenv().AutoBoxJob then return false end

    local takePoint, takePos = getBoxPoint("Take")
    if not takePos then print("[BoxJob] Take point not found!") return false end

    print("[BoxJob] Walking to Take...")
    if not walkTo(takePos, "AutoBoxJob") then print("[BoxJob] Failed to reach Take") return false end
    if not getgenv().AutoBoxJob then return false end

    task.wait(0.5)
    local prompt = takePoint:FindFirstChild("Take") and takePoint.Take:FindFirstChild("Interact")
    print("[BoxJob] Take prompt:", prompt and tostring(prompt.Enabled) or "nil")
    if prompt and prompt.Enabled then
        fireproximityprompt(prompt)
        print("[BoxJob] Fired Take prompt")
        task.wait(0.5)
    end
    return getgenv().AutoBoxJob
end

local function performDeliverBox()
    if not getgenv().AutoBoxJob then return false end

    -- WP1 -> WP2 -> WP3
    print("[BoxJob] Going to Deliver via waypoints...")
    if not walkThroughWaypoints(getgenv()._BOX_WAYPOINTS, "AutoBoxJob") then return false end

    local deliverPoint, deliverPos = getBoxPoint("Deliver")
    if not deliverPos then print("[BoxJob] Deliver point not found!") return false end

    print("[BoxJob] Walking to Deliver...")
    if not walkTo(deliverPos, "AutoBoxJob") then print("[BoxJob] Failed to reach Deliver") return false end
    if not getgenv().AutoBoxJob then return false end

    task.wait(0.5)
    local prompt = deliverPoint:FindFirstChild("Deliver") and deliverPoint.Deliver:FindFirstChild("Interact")
    print("[BoxJob] Deliver prompt:", prompt and tostring(prompt.Enabled) or "nil")
    if prompt and prompt.Enabled then
        fireproximityprompt(prompt)
        print("[BoxJob] Fired Deliver prompt")
        task.wait(0.5)
    end

 -- WP3 -> WP2 -> WP1
    print("[BoxJob] Returning via waypoints (reverse)...")
    if not walkThroughWaypoints(reverseTable(getgenv()._BOX_WAYPOINTS), "AutoBoxJob") then return false end
    print("[BoxJob] Back at ground floor, looping...")

    return getgenv().AutoBoxJob
end

-- ==========================================
--             ESP SYSTEM (MODERN COMBAT)
-- ==========================================

do -- [SCOPE] ESP

-- Team colors
local function getTeamColor(plr)
    if plr.Team then
        local n = plr.Team.Name
        if n == "PD"        then return Color3.fromRGB(80, 160, 255)  end
        if n == "Prisoner"  then return Color3.fromRGB(255, 100, 40)  end
        if n == "Civilians" then return Color3.fromRGB(180, 220, 255) end
    end
    return Color3.fromRGB(220, 220, 220)
end

-- Weapon cache
getgenv()._weaponCache     = getgenv()._weaponCache     or {}
getgenv()._weaponCacheTime = getgenv()._weaponCacheTime or {}
local weaponCache     = getgenv()._weaponCache
local weaponCacheTime = getgenv()._weaponCacheTime

local function getCachedWeapon(plr)
    local now = tick()
    if weaponCache[plr] and (now - (weaponCacheTime[plr] or 0)) < 0.6 then
        return weaponCache[plr]
    end
    local char = plr.Character
    local tool = char and char:FindFirstChildWhichIsA("Tool")
    weaponCache[plr]     = tool and tool.Name or nil
    weaponCacheTime[plr] = now
    return weaponCache[plr]
end

-- ?? CREATE ESP TAG ???????????????????????????????????????????????
local function getOrCreateESP(plr)
    local existing = espFolder:FindFirstChild(plr.Name .. "_ESP")
    if existing then return existing end

    -- BillboardGui: 160w ? 56h, floats above head
    local gui = Instance.new("BillboardGui")
    gui.Name          = plr.Name .. "_ESP"
    gui.Parent        = espFolder
    gui.AlwaysOnTop   = true
    gui.Size          = UDim2.fromOffset(160, 56)
    gui.StudsOffset   = Vector3.new(0, 3.2, 0)
    gui.LightInfluence = 0
    gui.MaxDistance   = espMaxDist

    -- ?? outer card ??????????????????????????????????????????????
    local card = Instance.new("Frame", gui)
    card.Name                  = "BG"
    card.Size                  = UDim2.new(1, 0, 1, 0)
    card.BackgroundColor3      = Color3.fromRGB(8, 8, 12)
    card.BackgroundTransparency = 0.18
    card.BorderSizePixel       = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 5)

    -- thin accent border
    local border = Instance.new("UIStroke", card)
    border.Name         = "BGStroke"
    border.Thickness    = 1.2
    border.Color        = Color3.fromRGB(80, 80, 110)
    border.Transparency = 0.25

    -- ?? top accent bar (colored by team) ????????????????????????
    local accentBar = Instance.new("Frame", card)
    accentBar.Name              = "AccentBar"
    accentBar.Size              = UDim2.new(1, 0, 0, 2)
    accentBar.Position          = UDim2.new(0, 0, 0, 0)
    accentBar.BackgroundColor3  = Color3.fromRGB(80, 160, 255)
    accentBar.BorderSizePixel   = 0
    local accentCorner = Instance.new("UICorner", accentBar)
    accentCorner.CornerRadius   = UDim.new(0, 5)

    -- ?? name label ??????????????????????????????????????????????
    local nameLabel = Instance.new("TextLabel", card)
    nameLabel.Name              = "NameLabel"
    nameLabel.Size              = UDim2.new(1, -8, 0, 15)
    nameLabel.Position          = UDim2.new(0, 4, 0, 3)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font              = Enum.Font.GothamBold
    nameLabel.TextSize          = 10
    nameLabel.RichText          = true
    nameLabel.Text              = plr.Name
    nameLabel.TextXAlignment    = Enum.TextXAlignment.Left
    nameLabel.TextStrokeTransparency = 0.4
    nameLabel.TextStrokeColor3  = Color3.new(0, 0, 0)
    nameLabel.TextColor3        = Color3.fromRGB(240, 240, 255)

    -- ?? HP bar background ????????????????????????????????????????
    local hpBg = Instance.new("Frame", card)
    hpBg.Name                  = "HPBg"
    hpBg.Size                  = UDim2.new(1, -8, 0, 6)
    hpBg.Position              = UDim2.new(0, 4, 0, 20)
    hpBg.BackgroundColor3      = Color3.fromRGB(25, 25, 35)
    hpBg.BorderSizePixel       = 0
    Instance.new("UICorner", hpBg).CornerRadius = UDim.new(1, 0)

    -- HP bar fill
    local hpFill = Instance.new("Frame", hpBg)
    hpFill.Name                = "HPFill"
    hpFill.Size                = UDim2.new(1, 0, 1, 0)
    hpFill.BackgroundColor3    = Color3.fromRGB(80, 220, 100)
    hpFill.BorderSizePixel     = 0
    Instance.new("UICorner", hpFill).CornerRadius = UDim.new(1, 0)

    -- HP text overlay (inside bar area)
    local hpText = Instance.new("TextLabel", card)
    hpText.Name                 = "HPText"
    hpText.Size                 = UDim2.new(1, -8, 0, 8)
    hpText.Position             = UDim2.new(0, 4, 0, 29)
    hpText.BackgroundTransparency = 1
    hpText.Font                 = Enum.Font.GothamMedium
    hpText.TextSize             = 7
    hpText.RichText             = true
    hpText.Text                 = "100%"
    hpText.TextXAlignment       = Enum.TextXAlignment.Left
    hpText.TextStrokeTransparency = 0.5
    hpText.TextColor3           = Color3.fromRGB(160, 200, 160)

    -- ?? info row: dist + weapon ??????????????????????????????????
    local infoLabel = Instance.new("TextLabel", card)
    infoLabel.Name              = "InfoLabel"
    infoLabel.Size              = UDim2.new(1, -8, 0, 10)
    infoLabel.Position          = UDim2.new(0, 4, 0, 43)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Font              = Enum.Font.Gotham
    infoLabel.TextSize          = 7
    infoLabel.RichText          = true
    infoLabel.Text              = ""
    infoLabel.TextXAlignment    = Enum.TextXAlignment.Left
    infoLabel.TextStrokeTransparency = 0.5
    infoLabel.TextColor3        = Color3.fromRGB(140, 140, 170)

    -- resize gui to fit
    gui.Size = UDim2.fromOffset(160, 56)

    return gui
end

-- ?? ESP LOOP ?????????????????????????????????????????????????????
getgenv()._espTickMap = getgenv()._espTickMap or {}
local espTickMap    = getgenv()._espTickMap
local ESP_RATE      = 0.05

if getgenv().ESPLoop then getgenv().ESPLoop:Disconnect() end
getgenv().ESPLoop = RunService.Heartbeat:Connect(function()
    if not getgenv().AutoESP then return end
    if getgenv().HubRunId ~= currentRunId then getgenv().ESPLoop:Disconnect() return end

    local now   = tick()
    local myHrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

    for _, plr in pairs(Players:GetPlayers()) do
        if plr == player then continue end
        if (now - (espTickMap[plr] or 0)) < ESP_RATE then continue end
        espTickMap[plr] = now

        local char = plr.Character
        local hum  = char and char:FindFirstChild("Humanoid")
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")

        if hum and hrp and hum.Health > 0 then
            local teamCol = espShowTeam and getTeamColor(plr) or Color3.fromRGB(200, 200, 220)
            local dist    = myHrp and math.floor((myHrp.Position - hrp.Position).Magnitude) or 0
            local hp      = math.floor(hum.Health)
            local maxHp   = math.max(math.floor(hum.MaxHealth), 1)
            local hpPct   = math.clamp(hp / maxHp, 0, 1)

            local gui = getOrCreateESP(plr)
            gui.Adornee   = hrp
            gui.Enabled   = true
            gui.MaxDistance = espMaxDist

            local bg = gui.BG

            -- accent bar color = team
            bg.AccentBar.BackgroundColor3 = teamCol

            -- border color = team
            local stroke = bg:FindFirstChild("BGStroke")
            if stroke then
                stroke.Color = teamCol
                stroke.Transparency = 0.5
            end

            -- name: team-colored + HP number right
            bg.NameLabel.Text = string.format(
                "<font color='rgb(%d,%d,%d)'><b>%s</b></font>" ..
                "<font color='rgb(100,100,120)'>  %d/%d</font>",
                math.floor(teamCol.R*255), math.floor(teamCol.G*255), math.floor(teamCol.B*255),
                plr.Name, hp, maxHp
            )

            -- HP bar fill + color gradient greenyellowred
            if espShowHealth then
                bg.HPBg.Visible   = true
                bg.HPText.Visible = true
                bg.HPBg.HPFill.Size = UDim2.new(hpPct, 0, 1, 0)

                local r = math.floor(255 * (1 - hpPct) * 2)
                local g = math.floor(255 * math.min(hpPct * 2, 1))
                bg.HPBg.HPFill.BackgroundColor3 = Color3.fromRGB(
                    math.clamp(r, 0, 255), math.clamp(g, 0, 255), 40
                )

                bg.HPText.Text = string.format(
                    "<font color='rgb(%d,%d,40)'>%d%%</font>",
                    math.clamp(r, 0, 255), math.clamp(g, 0, 255),
                    math.floor(hpPct * 100)
                )
            else
                bg.HPBg.Visible   = false
                bg.HPText.Visible = false
            end

            -- info row
            local weapon = espShowWeapon and getCachedWeapon(plr) or nil
            local distStr = espShowDist
                and string.format("<font color='rgb(100,180,255)'>??%dm</font>  ", dist)
                or ""
            local weapStr = weapon
                and string.format("<font color='rgb(255,210,80)'>??%s</font>", weapon)
                or (espShowWeapon and "<font color='rgb(80,80,100)'>Unarmed</font>" or "")
            bg.InfoLabel.Text    = distStr .. weapStr
            bg.InfoLabel.Visible = espShowDist or espShowWeapon

            -- Highlight
            local hl = char:FindFirstChild("StreetLifeHighlight")
            if not hl then
                hl = Instance.new("Highlight")
                hl.Name   = "StreetLifeHighlight"
                hl.Parent = char
            end
            hl.FillColor           = espFillColor
            hl.FillTransparency    = 0.78
            local isLocked         = getgenv().CurrentAimTarget == plr
            hl.OutlineColor        = isLocked and Color3.fromRGB(255, 255, 0)
                or (espShowTeam and teamCol or espOutlineColor)
            hl.OutlineTransparency = isLocked and 0 or 0.08
            hl.Enabled             = true

            -- Skeleton drawing
            if espShowSkeleton then
                local skGui = gui:FindFirstChild("SkeletonGui")
                if not skGui then
                    skGui = Instance.new("BillboardGui")
                    skGui.Name          = "SkeletonGui"
                    skGui.AlwaysOnTop   = true
                    skGui.Size          = UDim2.fromOffset(0, 0)
                    skGui.StudsOffsetWorldSpace = Vector3.zero
                    skGui.Adornee       = hrp
                    skGui.Parent        = gui
                end
                -- draw bones via Drawing API (Lines)
                pcall(function()
                    local function getPos(n)
                        local p = char:FindFirstChild(n)
                        return p and Camera:WorldToViewportPoint(p.Position) or nil
                    end
                    local bones = {
                        {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
                        {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
                        {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
                        {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
                        {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
                    }
                    -- cache Drawing lines per player
                    if not getgenv()._skelLines then getgenv()._skelLines = {} end
                    if not getgenv()._skelLines[plr] then
                        getgenv()._skelLines[plr] = {}
                        for i = 1, #bones do
                            local ln = Drawing.new("Line")
                            ln.Thickness = espSkeletonThickness
                            ln.Color = espSkeletonColor or teamCol
                            ln.Transparency = 0.7
                            ln.Visible = false
                            getgenv()._skelLines[plr][i] = ln
                        end
                    end
                    local lines = getgenv()._skelLines[plr]
                    -- determine skeleton color (use setting or team color)
                    local skelColor = espSkeletonColor or teamCol
                    for i, pair in ipairs(bones) do
                        local s = getPos(pair[1]); local e = getPos(pair[2])
                        if s and e then
                            lines[i].From      = Vector2.new(s.X, s.Y)
                            lines[i].To        = Vector2.new(e.X, e.Y)
                            lines[i].Color     = skelColor
                            lines[i].Thickness = espSkeletonThickness
                            lines[i].Visible   = true
                        else
                            lines[i].Visible = false
                        end
                    end
                end)
            else
                -- hide skeleton lines if disabled
                if getgenv()._skelLines and getgenv()._skelLines[plr] then
                    for _, ln in pairs(getgenv()._skelLines[plr]) do
                        pcall(function() ln.Visible = false end)
                    end
                end
            end

        else
            local gui = espFolder:FindFirstChild(plr.Name .. "_ESP")
            if gui then gui.Enabled = false end
            local hl = char and char:FindFirstChild("StreetLifeHighlight")
            if hl then hl.Enabled = false end
        end
    end
end)
end -- [/SCOPE] ESP

-- ==========================================
-- ==========================================
--             CRYPTO BRAIN
-- ==========================================

local function getPhoneRemote()
    return ReplicatedStorage:FindFirstChild("Remotes")
        and ReplicatedStorage.Remotes:FindFirstChild("Phone")
end
local function getPhoneMisc()
    return ReplicatedStorage:FindFirstChild("Misc")
        and ReplicatedStorage.Misc:FindFirstChild("Phone")
end

-- Per-coin state (stored in getgenv to avoid top-level local slots)
getgenv()._coinStates = getgenv()._coinStates or {
    BTC  = { history = {}, lastPrice = 0, avgBuy = 0, busy = false },
    ETH  = { history = {}, lastPrice = 0, avgBuy = 0, busy = false },
    DOGE = { history = {}, lastPrice = 0, avgBuy = 0, busy = false },
}
local coinStates = getgenv()._coinStates

-- Config
getgenv()._coinConfig = {
    BTC  = { priceKey="Crypto", event="Crypto", walletKey="Crypto",
             flag="AutoCrypto",     profit="TotalCryptoProfit" },
    ETH  = { priceKey="ETH",    event="ETH",    walletKey="ETH",
             flag="AutoCryptoETH",  profit="TotalEthProfit"   },
    DOGE = { priceKey="DOGE",   event="DOGE",   walletKey="DOGE",
             flag="AutoCryptoDOGE", profit="TotalDogeProfit"  },
}

getgenv()._coinLabels = getgenv()._coinLabels or {}
local coinLabels = getgenv()._coinLabels

-- runCoinTrader stored in getgenv to avoid local register overflow
getgenv()._runCoinTrader = function(sym)
    local coinConfig = getgenv()._coinConfig
    local coinStates = getgenv()._coinStates
    local coinLabels = getgenv()._coinLabels
    local cfg   = coinConfig[sym]
    local state = coinStates[sym]
    if state.busy then return end

    local misc     = getPhoneMisc()
    local priceObj = misc and misc:FindFirstChild(cfg.priceKey)
    local myData   = player:FindFirstChild("Data")
    local wallet   = myData and myData:FindFirstChild(cfg.walletKey)
    local bank     = myData and myData:FindFirstChild("Bank")
    local remote   = getPhoneRemote()

    local lbl = coinLabels[sym]
    if lbl and priceObj and wallet then
        lbl[1]:Set("Live " .. sym .. ": $" .. tostring(priceObj.Value))
        lbl[2]:Set("Wallet: " .. tostring(wallet.Value) .. " / 20 " .. sym)
        lbl[3]:Set("Session Profit: $" .. tostring(math.floor(getgenv()[cfg.profit] or 0)))
    end

    if not (priceObj and wallet and bank and remote) then return end
    if not getgenv()[cfg.flag] then return end

    local price = priceObj.Value
    local owned = wallet.Value
    local cash  = bank.Value

    if price == state.lastPrice then return end
    state.lastPrice = price

    table.insert(state.history, price)
    if #state.history > 15 then table.remove(state.history, 1) end
    if #state.history < 5 then return end

    local sum = 0
    for _, p in ipairs(state.history) do sum = sum + p end
    local avg   = sum / #state.history
    local buyAt  = avg * 0.97
    local sellAt = avg * 1.03

    if price <= buyAt and cash >= price and owned < 20 then
        state.busy = true
        task.spawn(function()
            local canAfford = math.floor(cash / price)
            local toBuy = math.min(canAfford, 20 - owned)
            if toBuy > 0 then
                for i = 1, toBuy do
                    if not getgenv()[cfg.flag] then break end
                    pcall(function() remote:FireServer(cfg.event, "Purchase", price) end)
                    task.wait(0.2)
                end
                local newTotal = owned + toBuy
                state.avgBuy = owned == 0 and price
                    or ((state.avgBuy * owned) + (price * toBuy)) / newTotal
            end
            task.wait(2); state.busy = false
        end)
        return
    end

    if owned > 0 and price >= sellAt and (state.avgBuy == 0 or price > state.avgBuy) then
        state.busy = true
        task.spawn(function()
            local profit = state.avgBuy > 0 and ((price - state.avgBuy) * owned) or 0
            getgenv()[cfg.profit] = (getgenv()[cfg.profit] or 0) + profit
            for i = 1, owned do
                if not getgenv()[cfg.flag] then break end
                pcall(function() remote:FireServer(cfg.event, "Sell", price) end)
                task.wait(0.2)
            end
            state.avgBuy = 0
            task.wait(2); state.busy = false
        end)
    end
end

local function handleSmartCryptoTrader() getgenv()._runCoinTrader("BTC")  end
local function handleSmartEthTrader()    getgenv()._runCoinTrader("ETH")  end
local function handleSmartDogeTrader()   getgenv()._runCoinTrader("DOGE") end


-- ==========================================
--      WIRE COIN LABELS (must be after UI)
-- ==========================================
coinLabels["BTC"]  = { lblBtcPrice,  lblBtcOwned,  lblBtcProfit  }
coinLabels["ETH"]  = { lblEthPrice,  lblEthOwned,  lblEthProfit  }
coinLabels["DOGE"] = { lblDogePrice, lblDogeOwned, lblDogeProfit }

-- ==========================================
--             MAIN AUTOMATION LOOP
-- ==========================================
if getgenv()._mainLoop then
    task.cancel(getgenv()._mainLoop)
    getgenv()._mainLoop = nil
end

getgenv()._mainLoop = task.spawn(function()
    while getgenv().HubRunId == currentRunId do
        task.wait(0.5)

        -- Crypto traders (always poll even when flags are off, to update labels)
        pcall(handleSmartCryptoTrader)
        pcall(handleSmartEthTrader)
        pcall(handleSmartDogeTrader)

        local char = player.Character
        local hum  = char and char:FindFirstChild("Humanoid")
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if not (hum and hrp and hum.Health > 0) then continue end

        local moneyObj = player:FindFirstChild("Data") and player.Data:FindFirstChild("Money")
        local cash     = moneyObj and moneyObj.Value or 0

        -- ===== AUTO DEPOSIT (instant, no walk) =====
        if getgenv().AutoDeposit and cash >= depositTarget then
            local atmRemote = ReplicatedStorage:FindFirstChild("Remotes")
                and ReplicatedStorage.Remotes:FindFirstChild("ATM")
            if atmRemote then atmRemote:FireServer("Deposit", depositTarget) end
            task.wait(1)
        end

        -- ===== AUTO CLEAN (independent) =====
        if getgenv().AutoClean and not getgenv()._cleanBusy then
            getgenv()._cleanBusy = true
            task.spawn(function()
                local targetPuddle = getClosestPuddle()
                if targetPuddle then
                    local reached = walkTo(targetPuddle.Position, "AutoClean")
                    if reached and getgenv().AutoClean and getgenv().HubRunId == currentRunId then
                        task.wait(0.3)
                        local prompt = targetPuddle:FindFirstChildOfClass("ProximityPrompt")
                        if prompt and prompt.Enabled then
                            fireproximityprompt(prompt)
                            local timeout = 0
                            while targetPuddle.Parent and prompt.Enabled and timeout < 40
                                and getgenv().AutoClean and getgenv().HubRunId == currentRunId do
                                local ch = player.Character
                                local hm = ch and ch:FindFirstChild("Humanoid")
                                if hm and hm.Health <= 0 then break end
                                task.wait(0.25); timeout = timeout + 1
                                if timeout % 4 == 0 then pcall(fireproximityprompt, prompt) end
                            end
                        end
                    end
                end
                getgenv()._cleanBusy = false
            end)
        end

        -- ===== AUTO ROB CAR (independent) =====
        if getgenv().AutoRobCar and not getgenv()._robBusy then
            getgenv()._robBusy = true
            task.spawn(function()
                if not getgenv()._robBlacklist then getgenv()._robBlacklist = {} end
                local _, hPart, prompt = getClosestRobCar(getgenv()._robBlacklist)
                if hPart and prompt then
                    local function tryWalkToH()
                        local offsets = {
                            Vector3.new(0,0,0), Vector3.new(3,0,0), Vector3.new(-3,0,0),
                            Vector3.new(0,0,3), Vector3.new(0,0,-3), Vector3.new(3,0,3),
                            Vector3.new(-3,0,3), Vector3.new(3,0,-3), Vector3.new(-3,0,-3),
                            Vector3.new(5,0,0), Vector3.new(-5,0,0), Vector3.new(0,0,5), Vector3.new(0,0,-5),
                        }
                        local base = hPart.Position
                        local hrp2 = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                        if hrp2 then
                            table.sort(offsets, function(a,b)
                                return (hrp2.Position-(base+a)).Magnitude < (hrp2.Position-(base+b)).Magnitude
                            end)
                        end
                        for _, offset in ipairs(offsets) do
                            if not getgenv().AutoRobCar then return false end
                            local target = base + offset
                            local path2 = PathfindingService:CreatePath({AgentRadius=2,AgentHeight=5,AgentCanJump=true})
                            local hrp3 = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                            local ok2 = pcall(function() path2:ComputeAsync(hrp3 and hrp3.Position or target, target) end)
                            if ok2 and path2.Status == Enum.PathStatus.Success then
                                if walkTo(target, "AutoRobCar") then return true end
                            end
                        end
                        return false
                    end
                    local reached = tryWalkToH()
                    if reached and getgenv().AutoRobCar then
                        local highlight = nil
                        for tick = 1, 10 do
                            if not getgenv().AutoRobCar then break end
                            highlight = hPart:FindFirstChild("Highlight")
                            if highlight and highlight.Enabled then break end
                            task.wait(0.5)
                        end
                        if highlight and highlight.Enabled and prompt.Enabled then
                            local promptBack = true
                            local robRound = 0
                            while promptBack and getgenv().AutoRobCar do
                                robRound = robRound + 1
                                for i = 1, 5 do pcall(fireproximityprompt, prompt) task.wait(0.15) end
                                local robTimeout = 0
                                repeat
                                    pcall(fireproximityprompt, prompt)
                                    task.wait(0.1); robTimeout = robTimeout + 1
                                    local hl = hPart:FindFirstChild("Highlight")
                                    if not hl or not hl.Enabled then break end
                                until robTimeout >= 150 or not getgenv().AutoRobCar
                                task.wait(2)
                                local hlNext = hPart:FindFirstChild("Highlight")
                                promptBack = hlNext and hlNext.Enabled and prompt.Enabled
                            end
                            getgenv()._robBlacklist = {}
                        else
                            getgenv()._robBlacklist[hPart] = true
                        end
                    end
                else
                    getgenv()._robBlacklist = {}
                    task.wait(3)
                end
                getgenv()._robBusy = false
            end)
        end

        -- ===== AUTO BOX JOB (independent) =====
        if getgenv().AutoBoxJob and not getgenv()._boxBusy then
            getgenv()._boxBusy = true
            task.spawn(function()
                local taken = performTakeBox()
                if taken then performDeliverBox() end
                getgenv()._boxBusy = false
            end)
        end

        task.wait(0.3)
    end
end)
