--// ====================================================================
--// ROUBE UM OVO (STEAL AN EGG) - PROGRESSION HUB v5.0
--// Conta do Zero ao Avançado • Auto Cash • Esteira Contínua • Self-Test
--// ====================================================================

if _G.RoubeUmOvo_Cleanup then
    pcall(_G.RoubeUmOvo_Cleanup)
end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Config = _G.RoubeUmOvo_Config or {}

local State = {
    Running = true,
    AutoProgress = (Config.AutoProgress ~= nil) and Config.AutoProgress or true, -- Evolui Zero -> Avançado sozinho
    AutoEggs = (Config.AutoEggs ~= nil) and Config.AutoEggs or true,
    AutoCash = (Config.AutoCash ~= nil) and Config.AutoCash or true,             -- Coleta dinheiro dos pets na base
    AutoEvents = (Config.AutoEvents ~= nil) and Config.AutoEvents or true,
    AutoTreadmill = (Config.AutoTreadmill ~= nil) and Config.AutoTreadmill or true,
    AutoClaim = (Config.AutoClaim ~= nil) and Config.AutoClaim or true,
    OnlyRarePlus = (Config.OnlyRarePlus ~= nil) and Config.OnlyRarePlus or false,
    SpeedHack = false,
    AntiAFK = true,
    WalkSpeed = Config.WalkSpeed or 26,
    TweenSpeed = Config.MoveSpeed or 54,
    RunningOnTreadmill = false,
    CurrentPhase = "🌱 Fase 1: Conta do Zero",
    PlayerSpeedStat = 0,
    Status = "Iniciando auto-diagnóstico...",
    DiagnosticResult = "Testando módulos...",
    ActionsCount = 0,
    DetectedEggs = 0,
    DetectedEvents = 0
}

local Connections = {}
local ActiveTween = nil
local HomeCFrame = nil
local CustomTreadmillCFrame = nil
local CachedBase = nil
local CachedTreadmillPart = nil

local TargetAttempts = {}
local BlacklistedUntil = {}

local function MarkAttempt(obj)
    if not obj then return end
    local count = (TargetAttempts[obj] or 0) + 1
    TargetAttempts[obj] = count
    if count >= 2 then
        BlacklistedUntil[obj] = os.clock() + 120
        TargetAttempts[obj] = 0
    end
end

local function IsBlacklisted(obj)
    local expiry = BlacklistedUntil[obj]
    if not expiry then return false end
    if os.clock() >= expiry then
        BlacklistedUntil[obj] = nil
        return false
    end
    return true
end

local function CaptureInitialSpawn()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart", 10)
    if hrp then
        HomeCFrame = hrp.CFrame
    end
end
task.spawn(CaptureInitialSpawn)

--// ====================================================================
--// MÓDULO 1: FÍSICA, ESTEIRA CONTÍNUA E MOVIMENTAÇÃO SEGURA
--// ====================================================================

local function GetCharacterParts()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    return char, char:FindFirstChild("HumanoidRootPart"), char:FindFirstChildOfClass("Humanoid")
end

-- Mantém corrida contínua na esteira e WalkSpeed opcional sem engasgos
table.insert(Connections, RunService.Heartbeat:Connect(function()
    if not State.Running then return end
    local _, _, hum = GetCharacterParts()
    if hum and hum.Health > 0 then
        if State.SpeedHack and hum.WalkSpeed ~= State.WalkSpeed then
            hum.WalkSpeed = State.WalkSpeed
        end
        if State.RunningOnTreadmill then
            hum:Move(Vector3.new(0, 0, -1), true)
        end
    end
end))

local NoClipEnabled = false
table.insert(Connections, RunService.Stepped:Connect(function()
    if not State.Running or not NoClipEnabled then return end
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end))

table.insert(Connections, LocalPlayer.Idled:Connect(function()
    if State.Running and State.AntiAFK then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end))

local function SmoothMoveTo(targetCFrame, speedOverride)
    if not targetCFrame or not State.Running then return false end
    local char, hrp, hum = GetCharacterParts()
    if not char or not hrp or not hum or hum.Health <= 0 then return false end

    State.RunningOnTreadmill = false

    if ActiveTween then
        pcall(function() ActiveTween:Cancel() end)
        ActiveTween = nil
    end

    local effectiveSpeed = speedOverride or State.TweenSpeed
    local distance = (hrp.Position - targetCFrame.Position).Magnitude
    if distance <= 4 then
        return true
    end

    NoClipEnabled = true
    local duration = math.clamp(distance / effectiveSpeed, 0.15, 25)
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)

    local completed = false
    ActiveTween = TweenService:Create(hrp, tweenInfo, { CFrame = targetCFrame })

    local conn
    conn = ActiveTween.Completed:Connect(function()
        completed = true
        if conn then conn:Disconnect() end
    end)

    ActiveTween:Play()

    local lastDist = distance
    local checkTimer = 0

    while not completed and State.Running do
        local _, currentHrp, currentHum = GetCharacterParts()
        if not currentHrp or not currentHum or currentHum.Health <= 0 then
            pcall(function() ActiveTween:Cancel() end)
            NoClipEnabled = false
            return false
        end

        currentHrp.AssemblyLinearVelocity = Vector3.zero
        local dt = task.wait(0.05)
        checkTimer = checkTimer + dt

        if checkTimer >= 0.25 then
            checkTimer = 0
            local newDist = (currentHrp.Position - targetCFrame.Position).Magnitude
            if newDist > lastDist + 5 then
                pcall(function() ActiveTween:Cancel() end)
                NoClipEnabled = false
                task.wait(0.25)
                return SmoothMoveTo(targetCFrame, math.max(32, effectiveSpeed * 0.7))
            end
            lastDist = newDist
        end
    end

    NoClipEnabled = false
    return completed
end

local function InteractWithTarget(instance)
    if not instance then return end
    local _, hrp = GetCharacterParts()

    local prompt = instance:FindFirstChildWhichIsA("ProximityPrompt", true)
        or (instance.Parent and instance.Parent:FindFirstChildWhichIsA("ProximityPrompt", true))

    if prompt and prompt.Enabled then
        pcall(function()
            if fireproximityprompt then
                fireproximityprompt(prompt)
            end
            prompt:InputHoldBegin()
            task.wait((prompt.HoldDuration or 0) + 0.12)
            prompt:InputHoldEnd()
        end)
    end

    local clicker = instance:FindFirstChildWhichIsA("ClickDetector", true)
        or (instance.Parent and instance.Parent:FindFirstChildWhichIsA("ClickDetector", true))

    if clicker and fireclickdetector then
        pcall(function() fireclickdetector(clicker) end)
    end

    if hrp and firetouchinterest then
        local parts = {}
        if instance:IsA("BasePart") then
            table.insert(parts, instance)
        end
        for _, p in ipairs(instance:GetDescendants()) do
            if p:IsA("BasePart") then
                table.insert(parts, p)
            end
        end
        for _, p in ipairs(parts) do
            pcall(function()
                firetouchinterest(hrp, p, 0)
                task.wait(0.03)
                firetouchinterest(hrp, p, 1)
            end)
        end
    end
end

--// ====================================================================
--// MÓDULO 2: DETECÇÃO DE PROGRESSO (ZERO -> AVANÇADO), BASE E COLETA
--// ====================================================================

local function ParseAbbreviatedNumber(str)
    if not str then return 0 end
    local clean = tostring(str):upper():gsub(",", "."):gsub("[^0-9%.KMBT]", "")
    local num = tonumber(clean:match("[0-9%.]+")) or 0
    if clean:find("T") then return num * 1e12 end
    if clean:find("B") then return num * 1e9 end
    if clean:find("M") then return num * 1e6 end
    if clean:find("K") then return num * 1e3 end
    return num
end

-- Detecta se a conta ainda está no início ou já atingiu nível avançado
local function UpdateAccountProgression()
    local detectedSpeed = 0

    -- 1. Tenta ler pelo leaderstats ou atributos do jogador
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        for _, stat in ipairs(ls:GetChildren()) do
            local n = stat.Name:lower()
            if n:find("speed") or n:find("velocidade") or n:find("power") or n:find("step") then
                local val = tonumber(stat.Value) or ParseAbbreviatedNumber(stat.Value)
                if val > detectedSpeed then
                    detectedSpeed = val
                end
            end
        end
    end

    for _, attrVal in pairs(LocalPlayer:GetAttributes()) do
        if type(attrVal) == "number" and attrVal > detectedSpeed and attrVal < 1e15 then
            detectedSpeed = attrVal
        end
    end

    State.PlayerSpeedStat = detectedSpeed

    if State.AutoProgress then
        if detectedSpeed >= 2500 then
            State.CurrentPhase = "🔥 Fase 2: Avançado (Raros+)"
            State.OnlyRarePlus = true
        else
            State.CurrentPhase = "🌱 Fase 1: Conta do Zero"
            State.OnlyRarePlus = false
        end
    else
        State.CurrentPhase = State.OnlyRarePlus and "🎯 Manual: Só Raros+" or "🎯 Manual: Todos Ovos"
    end
end

local function FindMyBase()
    if CachedBase and CachedBase.Parent then
        return CachedBase
    end

    local userName = LocalPlayer.Name:lower()
    local displayName = LocalPlayer.DisplayName:lower()
    local userIdStr = tostring(LocalPlayer.UserId)

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("Folder") then
            local objName = obj.Name:lower()
            if objName:find(userName, 1, true) or objName:find(displayName, 1, true) or objName:find(userIdStr, 1, true) then
                CachedBase = obj
                return obj
            end
            for _, attrVal in pairs(obj:GetAttributes()) do
                local s = tostring(attrVal):lower()
                if s == userName or s == userIdStr then
                    CachedBase = obj
                    return obj
                end
            end
        end
    end
    return nil
end

-- Coleta automaticamente o dinheiro gerado pelos pets na sua base
local function CollectBaseCash()
    local _, hrp = GetCharacterParts()
    if not hrp or not firetouchinterest then return end

    local base = FindMyBase()
    local searchParts = {}

    if base then
        for _, desc in ipairs(base:GetDescendants()) do
            if desc:IsA("BasePart") then
                table.insert(searchParts, desc)
            end
        end
    elseif HomeCFrame then
        for _, desc in ipairs(Workspace:GetDescendants()) do
            if desc:IsA("BasePart") and (desc.Position - HomeCFrame.Position).Magnitude <= 45 then
                table.insert(searchParts, desc)
            end
        end
    end

    for _, part in ipairs(searchParts) do
        if part:FindFirstChildOfClass("TouchTransmitter") then
            local fullPath = part:GetFullName():lower()
            if (fullPath:find("cash") or fullPath:find("money") or fullPath:find("coin")
                or fullPath:find("collect") or fullPath:find("pad") or fullPath:find("slot")
                or fullPath:find("earn") or fullPath:find("dinheiro"))
                and not fullPath:find("sell") and not fullPath:find("vender") and not fullPath:find("robux") then
                pcall(function()
                    firetouchinterest(hrp, part, 0)
                    firetouchinterest(hrp, part, 1)
                end)
            end
        end
    end
end

local function GetDeliverCFrame()
    local base = FindMyBase()
    if base then
        for _, desc in ipairs(base:GetDescendants()) do
            local n = desc.Name:lower()
            if (n:find("pen") or n:find("hatch") or n:find("nest") or n:find("drop") or n:find("deliver") or n:find("garden")) then
                if desc:IsA("BasePart") then
                    return desc.CFrame + Vector3.new(0, 3, 0)
                elseif desc:IsA("Model") and desc.PrimaryPart then
                    return desc.PrimaryPart.CFrame + Vector3.new(0, 3, 0)
                end
            end
        end
    end
    return HomeCFrame
end

local TreadmillKeywords = {
    "treadmill", "esteira", "conveyor", "belt", "speed",
    "train", "workout", "run", "gym", "velocidade"
}

local function FindTreadmillPart()
    if CachedTreadmillPart and CachedTreadmillPart.Parent then
        return CachedTreadmillPart
    end

    local base = FindMyBase()
    local candidates = {}

    if base then
        for _, desc in ipairs(base:GetDescendants()) do
            if desc:IsA("BasePart") then
                table.insert(candidates, desc)
            end
        end
    elseif HomeCFrame then
        for _, desc in ipairs(Workspace:GetDescendants()) do
            if desc:IsA("BasePart") and (desc.Position - HomeCFrame.Position).Magnitude <= 55 then
                table.insert(candidates, desc)
            end
        end
    end

    for _, part in ipairs(candidates) do
        local fullPath = part:GetFullName():lower()
        for _, kw in ipairs(TreadmillKeywords) do
            if fullPath:find(kw, 1, true) and not fullPath:find("shop") and not fullPath:find("loja") then
                CachedTreadmillPart = part
                return part
            end
        end
    end

    for _, part in ipairs(candidates) do
        if part.AssemblyLinearVelocity.Magnitude > 0.5 and part.Size.X >= 3 and part.Size.Z >= 3 then
            CachedTreadmillPart = part
            return part
        end
    end

    for _, part in ipairs(candidates) do
        if part:FindFirstChildOfClass("TouchTransmitter") then
            local fullPath = part:GetFullName():lower()
            if not fullPath:find("pen") and not fullPath:find("hatch") and not fullPath:find("drop") and not fullPath:find("sell") then
                CachedTreadmillPart = part
                return part
            end
        end
    end

    return nil
end

local function IsCarryingEgg()
    local char = LocalPlayer.Character
    if not char then return false end

    for _, item in ipairs(char:GetChildren()) do
        local n = item.Name:lower()
        if (item:IsA("Tool") or item:IsA("Model") or item:IsA("Accessory")) and (n:find("egg") or n:find("ovo")) then
            return true
        end
    end

    if char:GetAttribute("CarryingEgg") or char:GetAttribute("HasEgg") or LocalPlayer:GetAttribute("CarryingEgg") then
        return true
    end
    return false
end

local RarityWeights = {
    divine = 100, eternal = 90, secret = 80, cosmic = 70,
    mythic = 60, legendary = 50, epic = 40, rare = 30, uncommon = 20, common = 10
}

local function GetRarityScore(nameLower)
    for key, score in pairs(RarityWeights) do
        if nameLower:find(key, 1, true) then
            return score
        end
    end
    return 15
end

local function IsInsideMyBase(obj)
    local base = FindMyBase()
    if base and obj:IsDescendantOf(base) then
        return true
    end
    if HomeCFrame then
        local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
        if part and (part.Position - HomeCFrame.Position).Magnitude < 38 then
            return true
        end
    end
    return false
end

local function IsInsideOtherPlayerBase(obj)
    local curr = obj.Parent
    while curr and curr ~= Workspace do
        local n = curr.Name:lower()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                if n:find(plr.Name:lower(), 1, true) or n:find(tostring(plr.UserId), 1, true) then
                    return true
                end
            end
        end
        if n:find("fuse") or n:find("shop") or n:find("loja") or n:find("vender") or n:find("sell") then
            return true
        end
        curr = curr.Parent
    end
    return false
end

local function FindBestBiomeEgg()
    local _, hrp = GetCharacterParts()
    if not hrp then return nil, nil end

    local bestTarget, bestPart, bestPriority = nil, nil, -math.huge
    local validCount = 0

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if (obj:IsA("Model") or obj:IsA("BasePart"))
            and not IsInsideMyBase(obj)
            and not IsInsideOtherPlayerBase(obj)
            and not IsBlacklisted(obj) then

            local n = obj.Name:lower()
            if (n:find("egg") or n:find("ovo"))
                and not n:find("guardian")
                and not n:find("shop")
                and not n:find("ui")
                and not n:find("machine")
                and not n:find("royal") then

                local rarity = GetRarityScore(n)
                if not State.OnlyRarePlus or rarity >= 30 then
                    local part = obj:IsA("BasePart") and obj or (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true))
                    if part and part.Transparency < 0.9 then
                        local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                            or (obj.Parent and obj.Parent:FindFirstChildWhichIsA("ProximityPrompt", true))
                        local hasActivePrompt = (prompt ~= nil and prompt.Enabled)
                        local hasClick = obj:FindFirstChildWhichIsA("ClickDetector", true) ~= nil
                        local hasTouch = obj:FindFirstChildWhichIsA("TouchTransmitter", true) ~= nil

                        if hasActivePrompt or hasClick or hasTouch then
                            validCount = validCount + 1
                            local dist = (hrp.Position - part.Position).Magnitude
                            local priority = (rarity * 2.5) - dist
                            if priority > bestPriority then
                                bestPriority = priority
                                bestTarget = obj
                                bestPart = part
                            end
                        end
                    end
                end
            end
        end
    end

    State.DetectedEggs = validCount
    return bestTarget, bestPart
end

local EventKeywords = {
    "butterfly", "borboleta", "spark", "feather", "pena",
    "debris", "soul", "alma", "pearl", "perola", "token", "infected"
}

local function FindEventCollectible()
    local _, hrp = GetCharacterParts()
    if not hrp then return nil, nil end

    local closestObj, closestPart, minDist = nil, nil, math.huge
    local evCount = 0

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if (obj:IsA("Model") or obj:IsA("BasePart"))
            and not IsInsideMyBase(obj)
            and not IsInsideOtherPlayerBase(obj)
            and not IsBlacklisted(obj) then

            local n = obj.Name:lower()
            for _, kw in ipairs(EventKeywords) do
                if n:find(kw, 1, true) then
                    local part = obj:IsA("BasePart") and obj or (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true))
                    if part and part.Transparency < 0.9 then
                        evCount = evCount + 1
                        local d = (hrp.Position - part.Position).Magnitude
                        if d < minDist then
                            minDist = d
                            closestObj = obj
                            closestPart = part
                        end
                    end
                    break
                end
            end
        end
    end

    State.DetectedEvents = evCount
    return closestObj, closestPart
end

local function ClaimQuestsAndIndex()
    for _, guiObj in ipairs(PlayerGui:GetDescendants()) do
        if (guiObj:IsA("TextButton") or guiObj:IsA("ImageButton")) and guiObj.Visible then
            local txt = guiObj:IsA("TextButton") and guiObj.Text:lower() or ""
            local nameL = guiObj.Name:lower()

            if txt:find("claim") or txt:find("resgatar") or txt:find("collect") or nameL:find("claim") then
                if not txt:find("robux") and not txt:find("r$") and not nameL:find("robux") then
                    pcall(function()
                        if getconnections then
                            for _, conn in ipairs(getconnections(guiObj.MouseButton1Click)) do
                                conn:Fire()
                            end
                            for _, conn in ipairs(getconnections(guiObj.Activated)) do
                                conn:Fire()
                            end
                        end
                    end)
                end
            end
        end
    end

    for _, remote in ipairs(ReplicatedStorage:GetDescendants()) do
        if remote:IsA("RemoteEvent") then
            local rn = remote.Name:lower()
            if (rn:find("quest") or rn:find("mission") or rn:find("index") or rn:find("reward"))
                and (rn:find("claim") or rn:find("collect") or rn:find("complete")) then
                pcall(function()
                    remote:FireServer()
                end)
            end
        end
    end
end

-- Auto-Diagnóstico de Integridade (valida todos os módulos ao iniciar)
local function RunSelfDiagnostic()
    local passed = 0
    local total = 5

    local _, hrp = GetCharacterParts()
    if hrp then passed = passed + 1 end
    if firetouchinterest or fireproximityprompt then passed = passed + 1 end
    if FindMyBase() or HomeCFrame then passed = passed + 1 end
    if FindTreadmillPart() then passed = passed + 1 end
    local eggObj = FindBestBiomeEgg()
    local evObj = FindEventCollectible()
    if eggObj or evObj or State.DetectedEggs >= 0 then passed = passed + 1 end

    State.DiagnosticResult = string.format("Auto-Teste: %d/%d módulos OK", passed, total)
end

--// ====================================================================
--// MÓDULO 3: PAINEL PROFISSIONAL MOBILE (DELTA HUB v5.0)
--// ====================================================================

local UIRefs = {
    PhaseText = nil,
    StatusText = nil,
    RadarText = nil,
    DiagText = nil
}

local Palette = {
    BgMain = Color3.fromRGB(15, 17, 26),
    BgHeader = Color3.fromRGB(22, 26, 39),
    BgCard = Color3.fromRGB(24, 28, 42),
    Stroke = Color3.fromRGB(45, 53, 78),
    Accent = Color3.fromRGB(0, 195, 255),
    Success = Color3.fromRGB(16, 185, 129),
    OffPill = Color3.fromRGB(55, 62, 82),
    Danger = Color3.fromRGB(220, 53, 69),
    TextPrimary = Color3.fromRGB(244, 246, 252),
    TextSecondary = Color3.fromRGB(155, 165, 190)
}

local function MakeDraggable(handle, targetFrame)
    local dragging, dragInput, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = targetFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    table.insert(Connections, UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            targetFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end))
end

local function CreateProfessionalUI()
    local existing = PlayerGui:FindFirstChild("RoubeUmOvo_ProHub")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RoubeUmOvo_ProHub"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = PlayerGui

    local miniPill = Instance.new("TextButton")
    miniPill.Name = "MiniPill"
    miniPill.Size = UDim2.new(0, 145, 0, 36)
    miniPill.Position = UDim2.new(0.04, 0, 0.22, 0)
    miniPill.BackgroundColor3 = Palette.BgHeader
    miniPill.Text = "🥚 OVO HUB • Abrir"
    miniPill.TextColor3 = Palette.TextPrimary
    miniPill.Font = Enum.Font.GothamBold
    miniPill.TextSize = 12
    miniPill.Visible = false
    miniPill.Parent = screenGui
    Instance.new("UICorner", miniPill).CornerRadius = UDim.new(1, 0)
    local miniStroke = Instance.new("UIStroke", miniPill)
    miniStroke.Color = Palette.Accent
    miniStroke.Thickness = 1.5

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 292, 0, 375)
    mainFrame.Position = UDim2.new(0.04, 0, 0.15, 0)
    mainFrame.BackgroundColor3 = Palette.BgMain
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Parent = screenGui
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)
    local mainStroke = Instance.new("UIStroke", mainFrame)
    mainStroke.Color = Palette.Stroke
    mainStroke.Thickness = 1.5

    local topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.Size = UDim2.new(1, 0, 0, 40)
    topBar.BackgroundColor3 = Palette.BgHeader
    topBar.BorderSizePixel = 0
    topBar.Parent = mainFrame
    Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 12)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -85, 1, 0)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🥚 ROUBE UM OVO • v5.0"
    title.TextColor3 = Palette.TextPrimary
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = topBar

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 28, 0, 26)
    minBtn.Position = UDim2.new(1, -66, 0.5, -13)
    minBtn.BackgroundColor3 = Palette.BgCard
    minBtn.Text = "—"
    minBtn.TextColor3 = Palette.TextPrimary
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 13
    minBtn.Parent = topBar
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 26)
    closeBtn.Position = UDim2.new(1, -34, 0.5, -13)
    closeBtn.BackgroundColor3 = Palette.Danger
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.Parent = topBar
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, -16, 0, 32)
    tabBar.Position = UDim2.new(0, 8, 0, 46)
    tabBar.BackgroundColor3 = Palette.BgCard
    tabBar.BorderSizePixel = 0
    tabBar.Parent = mainFrame
    Instance.new("UICorner", tabBar).CornerRadius = UDim.new(0, 8)

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tabLayout.Padding = UDim.new(0, 4)
    tabLayout.Parent = tabBar

    local pageHolder = Instance.new("Frame")
    pageHolder.Size = UDim2.new(1, -16, 1, -88)
    pageHolder.Position = UDim2.new(0, 8, 0, 84)
    pageHolder.BackgroundTransparency = 1
    pageHolder.Parent = mainFrame

    local pages = {}
    local tabButtons = {}

    local function CreatePage(name)
        local page = Instance.new("Frame")
        page.Name = name
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.Visible = false
        page.Parent = pageHolder

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 5)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = page

        pages[name] = page
        return page
    end

    local pageMissions = CreatePage("Missoes")
    local pageSettings = CreatePage("Ajustes")
    local pageStatus = CreatePage("Status")

    local function SelectTab(tabKey)
        for key, page in pairs(pages) do
            page.Visible = (key == tabKey)
        end
        for key, btn in pairs(tabButtons) do
            local active = (key == tabKey)
            btn.BackgroundColor3 = active and Palette.Accent or Color3.fromRGB(0, 0, 0)
            btn.BackgroundTransparency = active and 0 or 1
            btn.TextColor3 = active and Color3.fromRGB(10, 15, 25) or Palette.TextSecondary
        end
    end

    local function AddTabButton(tabKey, labelText)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.315, 0, 0, 24)
        btn.BackgroundTransparency = 1
        btn.Text = labelText
        btn.TextColor3 = Palette.TextSecondary
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.Parent = tabBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        btn.MouseButton1Click:Connect(function()
            SelectTab(tabKey)
        end)
        tabButtons[tabKey] = btn
    end

    AddTabButton("Missoes", "🎯 Missões")
    AddTabButton("Ajustes", "⚡ Speed")
    AddTabButton("Status", "📊 Status")

    local function AddToggleCard(parentPage, order, titleText, subtitleText, stateKey, onChanged)
        local card = Instance.new("TextButton")
        card.Size = UDim2.new(1, 0, 0, 41)
        card.BackgroundColor3 = Palette.BgCard
        card.Text = ""
        card.AutoButtonColor = false
        card.LayoutOrder = order
        card.Parent = parentPage
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
        Instance.new("UIStroke", card).Color = Palette.Stroke

        local lblTitle = Instance.new("TextLabel")
        lblTitle.Size = UDim2.new(1, -64, 0, 17)
        lblTitle.Position = UDim2.new(0, 10, 0, 5)
        lblTitle.BackgroundTransparency = 1
        lblTitle.Text = titleText
        lblTitle.TextColor3 = Palette.TextPrimary
        lblTitle.Font = Enum.Font.GothamSemibold
        lblTitle.TextSize = 11.5
        lblTitle.TextXAlignment = Enum.TextXAlignment.Left
        lblTitle.Parent = card

        local lblSub = Instance.new("TextLabel")
        lblSub.Size = UDim2.new(1, -64, 0, 13)
        lblSub.Position = UDim2.new(0, 10, 0, 23)
        lblSub.BackgroundTransparency = 1
        lblSub.Text = subtitleText
        lblSub.TextColor3 = Palette.TextSecondary
        lblSub.Font = Enum.Font.Gotham
        lblSub.TextSize = 9.5
        lblSub.TextXAlignment = Enum.TextXAlignment.Left
        lblSub.Parent = card

        local switchBg = Instance.new("Frame")
        switchBg.Size = UDim2.new(0, 42, 0, 22)
        switchBg.Position = UDim2.new(1, -52, 0.5, -11)
        switchBg.BackgroundColor3 = State[stateKey] and Palette.Success or Palette.OffPill
        switchBg.BorderSizePixel = 0
        switchBg.Parent = card
        Instance.new("UICorner", switchBg).CornerRadius = UDim.new(1, 0)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 16, 0, 16)
        knob.Position = State[stateKey] and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.BorderSizePixel = 0
        knob.Parent = switchBg
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        local function RefreshVisual()
            local isOn = State[stateKey]
            TweenService:Create(switchBg, TweenInfo.new(0.18), {
                BackgroundColor3 = isOn and Palette.Success or Palette.OffPill
            }):Play()
            TweenService:Create(knob, TweenInfo.new(0.18), {
                Position = isOn and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
            }):Play()
        end

        card.MouseButton1Click:Connect(function()
            State[stateKey] = not State[stateKey]
            RefreshVisual()
            if onChanged then
                pcall(onChanged, State[stateKey])
            end
        end)
    end

    -- ABA 1: MISSÕES (6 opções completas)
    AddToggleCard(pageMissions, 1, "Auto Evolução (Zero ➔ Avançado)", "Adapta ovos e metas conforme sua conta sobe", "AutoProgress")
    AddToggleCard(pageMissions, 2, "Auto Roubar & Entregar Ovos", "Coleta ovos nos biomas e leva ao cercado", "AutoEggs")
    AddToggleCard(pageMissions, 3, "Auto Coletar Dinheiro ($)", "Recolhe renda dos pets na base sozinho", "AutoCash")
    AddToggleCard(pageMissions, 4, "Auto Itens de Evento", "Pega borboletas, sparks, penas e tokens", "AutoEvents")
    AddToggleCard(pageMissions, 5, "Auto Esteira (Corrida Contínua)", "Treina velocidade na esteira automaticamente", "AutoTreadmill")
    AddToggleCard(pageMissions, 6, "Auto Resgatar Missões & Índice", "Coleta recompensas de Quests e Pet Index", "AutoClaim")

    -- ABA 2: SPEED & AJUSTES
    AddToggleCard(pageSettings, 1, "Forçar WalkSpeed (Opcional)", "Deixe OFF se o servidor puxar para trás", "SpeedHack", function(isOn)
        local _, _, hum = GetCharacterParts()
        if hum and not isOn then
            hum.WalkSpeed = 16
        end
    end)

    local walkCard = Instance.new("Frame")
    walkCard.Size = UDim2.new(1, 0, 0, 68)
    walkCard.BackgroundColor3 = Palette.BgCard
    walkCard.LayoutOrder = 2
    walkCard.Parent = pageSettings
    Instance.new("UICorner", walkCard).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", walkCard).Color = Palette.Stroke

    local walkTitle = Instance.new("TextLabel")
    walkTitle.Size = UDim2.new(1, -20, 0, 20)
    walkTitle.Position = UDim2.new(0, 10, 0, 6)
    walkTitle.BackgroundTransparency = 1
    walkTitle.Text = "WalkSpeed Manual (Seguro: 22-34): " .. tostring(State.WalkSpeed)
    walkTitle.TextColor3 = Palette.TextPrimary
    walkTitle.Font = Enum.Font.GothamSemibold
    walkTitle.TextSize = 11
    walkTitle.TextXAlignment = Enum.TextXAlignment.Left
    walkTitle.Parent = walkCard

    local function UpdateWalkSpeed(newVal)
        State.WalkSpeed = math.clamp(newVal, 16, 120)
        walkTitle.Text = "WalkSpeed Manual (Seguro: 22-34): " .. tostring(State.WalkSpeed)
    end

    local wButtons = {
        { txt = "-4",  x = 10, w = 36, act = function() UpdateWalkSpeed(State.WalkSpeed - 4) end, col = Palette.TextPrimary },
        { txt = "+4",  x = 50, w = 36, act = function() UpdateWalkSpeed(State.WalkSpeed + 4) end, col = Palette.TextPrimary },
        { txt = "20",  x = 94, w = 40, act = function() UpdateWalkSpeed(20) end, col = Palette.Accent },
        { txt = "26",  x = 138, w = 40, act = function() UpdateWalkSpeed(26) end, col = Palette.Success },
        { txt = "34",  x = 182, w = 42, act = function() UpdateWalkSpeed(34) end, col = Palette.Accent },
        { txt = "45",  x = 228, w = 42, act = function() UpdateWalkSpeed(45) end, col = Palette.TextSecondary }
    }
    for _, b in ipairs(wButtons) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, b.w, 0, 28)
        btn.Position = UDim2.new(0, b.x, 0, 30)
        btn.BackgroundColor3 = Palette.BgHeader
        btn.Text = b.txt
        btn.TextColor3 = b.col
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.Parent = walkCard
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        btn.MouseButton1Click:Connect(b.act)
    end

    local tweenCard = Instance.new("Frame")
    tweenCard.Size = UDim2.new(1, 0, 0, 68)
    tweenCard.BackgroundColor3 = Palette.BgCard
    tweenCard.LayoutOrder = 3
    tweenCard.Parent = pageSettings
    Instance.new("UICorner", tweenCard).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", tweenCard).Color = Palette.Stroke

    local tweenTitle = Instance.new("TextLabel")
    tweenTitle.Size = UDim2.new(1, -20, 0, 20)
    tweenTitle.Position = UDim2.new(0, 10, 0, 6)
    tweenTitle.BackgroundTransparency = 1
    tweenTitle.Text = "Velocidade Auto Farm (Anti-Bug): " .. tostring(State.TweenSpeed)
    tweenTitle.TextColor3 = Palette.TextPrimary
    tweenTitle.Font = Enum.Font.GothamSemibold
    tweenTitle.TextSize = 11
    tweenTitle.TextXAlignment = Enum.TextXAlignment.Left
    tweenTitle.Parent = tweenCard

    local function UpdateTweenSpeed(newVal)
        State.TweenSpeed = math.clamp(newVal, 30, 140)
        tweenTitle.Text = "Velocidade Auto Farm (Anti-Bug): " .. tostring(State.TweenSpeed)
    end

    local tButtons = {
        { txt = "-10", x = 10, w = 36, act = function() UpdateTweenSpeed(State.TweenSpeed - 10) end, col = Palette.TextPrimary },
        { txt = "+10", x = 50, w = 36, act = function() UpdateTweenSpeed(State.TweenSpeed + 10) end, col = Palette.TextPrimary },
        { txt = "38",  x = 94, w = 54, act = function() UpdateTweenSpeed(38) end, col = Palette.Accent },
        { txt = "54",  x = 154, w = 54, act = function() UpdateTweenSpeed(54) end, col = Palette.Success },
        { txt = "75",  x = 214, w = 56, act = function() UpdateTweenSpeed(75) end, col = Palette.Accent }
    }
    for _, b in ipairs(tButtons) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, b.w, 0, 28)
        btn.Position = UDim2.new(0, b.x, 0, 30)
        btn.BackgroundColor3 = Palette.BgHeader
        btn.Text = b.txt
        btn.TextColor3 = b.col
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.Parent = tweenCard
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        btn.MouseButton1Click:Connect(b.act)
    end

    AddToggleCard(pageSettings, 4, "Anti-AFK Automático", "Evita desconexão após 20 min ocioso", "AntiAFK")

    -- ABA 3: STATUS, AUTO-TESTE & CALIBRAÇÃO
    local function CreateInfoBox(order, initialText, textColor)
        local box = Instance.new("TextLabel")
        box.Size = UDim2.new(1, 0, 0, 31)
        box.BackgroundColor3 = Palette.BgCard
        box.Text = initialText
        box.TextColor3 = textColor or Palette.TextPrimary
        box.Font = Enum.Font.GothamSemibold
        box.TextSize = 10.5
        box.TextWrapped = true
        box.LayoutOrder = order
        box.Parent = pageStatus
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)
        Instance.new("UIStroke", box).Color = Palette.Stroke
        return box
    end

    UIRefs.PhaseText = CreateInfoBox(1, "Modo: " .. State.CurrentPhase, Palette.Accent)
    UIRefs.StatusText = CreateInfoBox(2, "Atividade: Inicializando...", Palette.Success)
    UIRefs.RadarText = CreateInfoBox(3, "Radar: Buscando alvos...", Palette.TextPrimary)
    UIRefs.DiagText = CreateInfoBox(4, State.DiagnosticResult, Palette.TextSecondary)

    local saveBaseBtn = Instance.new("TextButton")
    saveBaseBtn.Size = UDim2.new(1, 0, 0, 33)
    saveBaseBtn.BackgroundColor3 = Palette.Accent
    saveBaseBtn.Text = "📍 Salvar Posição Atual como Minha Base"
    saveBaseBtn.TextColor3 = Color3.fromRGB(10, 15, 25)
    saveBaseBtn.Font = Enum.Font.GothamBold
    saveBaseBtn.TextSize = 11
    saveBaseBtn.LayoutOrder = 5
    saveBaseBtn.Parent = pageStatus
    Instance.new("UICorner", saveBaseBtn).CornerRadius = UDim.new(0, 8)

    saveBaseBtn.MouseButton1Click:Connect(function()
        local _, hrp = GetCharacterParts()
        if hrp then
            HomeCFrame = hrp.CFrame
            CachedBase = nil
            CachedTreadmillPart = nil
            FindMyBase()
            RunSelfDiagnostic()
            UIRefs.DiagText.Text = "Base salva! " .. State.DiagnosticResult
        end
    end)

    local saveTmBtn = Instance.new("TextButton")
    saveTmBtn.Size = UDim2.new(1, 0, 0, 33)
    saveTmBtn.BackgroundColor3 = Palette.Success
    saveTmBtn.Text = "🏃 Salvar Posição Atual como Minha Esteira"
    saveTmBtn.TextColor3 = Color3.fromRGB(10, 15, 25)
    saveTmBtn.Font = Enum.Font.GothamBold
    saveTmBtn.TextSize = 11
    saveTmBtn.LayoutOrder = 6
    saveTmBtn.Parent = pageStatus
    Instance.new("UICorner", saveTmBtn).CornerRadius = UDim.new(0, 8)

    saveTmBtn.MouseButton1Click:Connect(function()
        local _, hrp = GetCharacterParts()
        if hrp then
            CustomTreadmillCFrame = hrp.CFrame
            UIRefs.DiagText.Text = "Esteira calibrada com sucesso!"
        end
    end)

    minBtn.MouseButton1Click:Connect(function()
        miniPill.Position = mainFrame.Position
        mainFrame.Visible = false
        miniPill.Visible = true
    end)

    miniPill.MouseButton1Click:Connect(function()
        mainFrame.Position = miniPill.Position
        miniPill.Visible = false
        mainFrame.Visible = true
    end)

    closeBtn.MouseButton1Click:Connect(function()
        if _G.RoubeUmOvo_Cleanup then
            _G.RoubeUmOvo_Cleanup()
        end
    end)

    MakeDraggable(topBar, mainFrame)
    MakeDraggable(miniPill, miniPill)
    SelectTab("Missoes")
end

local function SetStatus(text)
    State.Status = text
    if UIRefs.StatusText and UIRefs.StatusText.Parent then
        UIRefs.StatusText.Text = "Atividade: " .. text
    end
end

CreateProfessionalUI()
task.spawn(RunSelfDiagnostic)

--// ====================================================================
--// MÓDULO 4: ORQUESTRADOR PARALELO (AUTO CASH, QUESTS E FARM)
--// ====================================================================

task.spawn(function()
    while State.Running do
        pcall(UpdateAccountProgression)

        if State.AutoCash then
            pcall(CollectBaseCash)
        end

        if State.AutoClaim then
            pcall(ClaimQuestsAndIndex)
        end

        if UIRefs.PhaseText and UIRefs.PhaseText.Parent then
            UIRefs.PhaseText.Text = State.CurrentPhase
        end
        if UIRefs.RadarText and UIRefs.RadarText.Parent then
            UIRefs.RadarText.Text = string.format(
                "Radar: %d ovos | %d eventos | %d entregas",
                State.DetectedEggs, State.DetectedEvents, State.ActionsCount
            )
        end
        if UIRefs.DiagText and UIRefs.DiagText.Parent then
            UIRefs.DiagText.Text = State.DiagnosticResult
        end

        task.wait(2.5)
    end
end)

task.spawn(function()
    while State.Running do
        local success, err = pcall(function()
            local _, hrp, hum = GetCharacterParts()
            if not hrp or not hum or hum.Health <= 0 then
                State.RunningOnTreadmill = false
                SetStatus("Aguardando personagem...")
                task.wait(1)
                return
            end

            -- 1. Entrega imediatamente se estiver segurando um ovo
            if State.AutoEggs and IsCarryingEgg() then
                State.RunningOnTreadmill = false
                local deliverCF = GetDeliverCFrame()
                if deliverCF then
                    SetStatus("Entregando ovo no cercado...")
                    if SmoothMoveTo(deliverCF) then
                        State.ActionsCount = State.ActionsCount + 1
                    end
                    task.wait(0.35)
                end
                return
            end

            -- 2. Rouba o melhor ovo disponível conforme a fase (Zero ou Avançado)
            if State.AutoEggs then
                local eggObj, eggPart = FindBestBiomeEgg()
                if eggObj and eggPart then
                    State.RunningOnTreadmill = false
                    SetStatus("Roubando: " .. eggObj.Name)
                    if SmoothMoveTo(eggPart.CFrame + Vector3.new(0, 1.8, 0)) then
                        InteractWithTarget(eggObj)
                        task.wait(0.35)
                        if IsCarryingEgg() then
                            TargetAttempts[eggObj] = 0
                            return
                        else
                            MarkAttempt(eggObj)
                        end
                    end
                end
            end

            -- 3. Coleta itens de evento disponíveis
            if State.AutoEvents then
                local evObj, evPart = FindEventCollectible()
                if evObj and evPart then
                    State.RunningOnTreadmill = false
                    SetStatus("Coletando evento: " .. evObj.Name)
                    if SmoothMoveTo(evPart.CFrame + Vector3.new(0, 2, 0)) then
                        InteractWithTarget(evObj)
                        State.ActionsCount = State.ActionsCount + 1
                        MarkAttempt(evObj)
                        task.wait(0.25)
                    end
                    return
                end
            end

            -- 4. Esteira Contínua (mantém corrida ativa no Heartbeat sem pausas)
            if State.AutoTreadmill then
                local tmPart = FindTreadmillPart()
                local targetTmCF = CustomTreadmillCFrame or (tmPart and (tmPart.CFrame + Vector3.new(0, 2.5, 0)))

                if targetTmCF then
                    SetStatus("Correndo na esteira (+Speed)...")
                    local distToTm = (hrp.Position - targetTmCF.Position).Magnitude
                    if distToTm > 4.5 then
                        SmoothMoveTo(targetTmCF)
                    end

                    State.RunningOnTreadmill = true
                    if tmPart and firetouchinterest then
                        pcall(function()
                            firetouchinterest(hrp, tmPart, 0)
                            firetouchinterest(hrp, tmPart, 1)
                        end)
                    end
                    task.wait(0.5)
                    return
                end
            end

            State.RunningOnTreadmill = false
            SetStatus("Aguardando respawn de alvos...")
            task.wait(0.8)
        end)

        if not success then
            State.RunningOnTreadmill = false
            SetStatus("Recuperando ciclo...")
            warn("[RoubeUmOvo v5.0] Aviso capturado: " .. tostring(err))
            task.wait(1)
        end

        task.wait(0.15)
    end
end)

_G.RoubeUmOvo_Cleanup = function()
    State.Running = false
    State.RunningOnTreadmill = false
    NoClipEnabled = false
    local _, _, hum = GetCharacterParts()
    if hum then
        pcall(function() hum.WalkSpeed = 16 end)
    end
    if ActiveTween then
        pcall(function() ActiveTween:Cancel() end)
    end
    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    local ui = PlayerGui:FindFirstChild("RoubeUmOvo_ProHub")
    if ui then ui:Destroy() end
end
