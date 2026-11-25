--// ROUBE UM OVO (STEAL AN EGG) - AUTO MISSÕES & AUTO FARM
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

-- Configurações iniciais (podem ser alteradas pelo painel Streamlit ou pela UI no jogo)
local Config = _G.RoubeUmOvo_Config or {}

local State = {
    Running = true,
    AutoEggs = (Config.AutoEggs ~= nil) and Config.AutoEggs or true,
    AutoEvents = (Config.AutoEvents ~= nil) and Config.AutoEvents or true,
    AutoTreadmill = (Config.AutoTreadmill ~= nil) and Config.AutoTreadmill or true,
    AutoClaim = (Config.AutoClaim ~= nil) and Config.AutoClaim or true,
    AntiAFK = true,
    MoveSpeed = Config.MoveSpeed or 135,
    Status = "Inicializando..."
}

local Connections = {}
local ActiveTween = nil
local HomeCFrame = nil
local CachedBase = nil

local function CaptureInitialSpawn()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart", 10)
    if hrp then
        HomeCFrame = hrp.CFrame
    end
end
task.spawn(CaptureInitialSpawn)

local function GetCharacterParts()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    return char, char:FindFirstChild("HumanoidRootPart"), char:FindFirstChildOfClass("Humanoid")
end

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

local function SmoothMoveTo(targetCFrame)
    if not targetCFrame or not State.Running then return false end
    local char, hrp, hum = GetCharacterParts()
    if not char or not hrp or not hum or hum.Health <= 0 then return false end

    if ActiveTween then
        pcall(function() ActiveTween:Cancel() end)
        ActiveTween = nil
    end

    local distance = (hrp.Position - targetCFrame.Position).Magnitude
    if distance <= 4 then
        hrp.CFrame = targetCFrame
        return true
    end

    NoClipEnabled = true
    local duration = math.clamp(distance / State.MoveSpeed, 0.15, 12)
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)

    local completed = false
    ActiveTween = TweenService:Create(hrp, tweenInfo, { CFrame = targetCFrame })

    local conn
    conn = ActiveTween.Completed:Connect(function()
        completed = true
        if conn then conn:Disconnect() end
    end)

    ActiveTween:Play()

    while not completed and State.Running do
        local _, currentHrp, currentHum = GetCharacterParts()
        if not currentHrp or not currentHum or currentHum.Health <= 0 then
            pcall(function() ActiveTween:Cancel() end)
            NoClipEnabled = false
            return false
        end
        currentHrp.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.05)
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
            else
                prompt:InputHoldBegin()
                task.wait((prompt.HoldDuration or 0) + 0.08)
                prompt:InputHoldEnd()
            end
        end)
        return
    end

    local clicker = instance:FindFirstChildWhichIsA("ClickDetector", true)
        or (instance.Parent and instance.Parent:FindFirstChildWhichIsA("ClickDetector", true))

    if clicker and fireclickdetector then
        pcall(function() fireclickdetector(clicker) end)
        return
    end

    local part = instance:IsA("BasePart") and instance or instance:FindFirstChildWhichIsA("BasePart", true)
    if part and hrp and firetouchinterest then
        pcall(function()
            firetouchinterest(hrp, part, 0)
            task.wait(0.05)
            firetouchinterest(hrp, part, 1)
        end)
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

local function GetTreadmillCFrame()
    local base = FindMyBase()
    local searchRoot = base or Workspace
    local _, hrp = GetCharacterParts()
    local bestCF, bestDist = nil, 250

    for _, desc in ipairs(searchRoot:GetDescendants()) do
        local n = desc.Name:lower()
        if n:find("treadmill") or n:find("esteira") or n:find("speedpad") then
            local part = desc:IsA("BasePart") and desc or desc:FindFirstChildWhichIsA("BasePart", true)
            if part then
                if base then
                    return part.CFrame + Vector3.new(0, 3, 0)
                elseif hrp then
                    local d = (hrp.Position - part.Position).Magnitude
                    if d < bestDist then
                        bestDist = d
                        bestCF = part.CFrame + Vector3.new(0, 3, 0)
                    end
                end
            end
        end
    end
    return bestCF
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
        if part and (part.Position - HomeCFrame.Position).Magnitude < 35 then
            return true
        end
    end
    return false
end

local function FindBestBiomeEgg()
    local _, hrp = GetCharacterParts()
    if not hrp then return nil, nil end

    local bestTarget, bestPart, bestPriority = nil, nil, -math.huge

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if (obj:IsA("Model") or obj:IsA("BasePart")) and not IsInsideMyBase(obj) then
            local n = obj.Name:lower()
            if (n:find("egg") or n:find("ovo")) and not n:find("guardian") and not n:find("shop") and not n:find("ui") then
                local part = obj:IsA("BasePart") and obj or (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true))
                if part and part.Transparency < 0.9 then
                    local hasPrompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true) ~= nil
                    local hasTouch = part:FindFirstChildOfClass("TouchTransmitter") ~= nil
                    local parentName = obj.Parent and obj.Parent.Name:lower() or ""
                    if hasPrompt or hasTouch or parentName:find("egg") or parentName:find("nest") then
                        local dist = (hrp.Position - part.Position).Magnitude
                        local rarity = GetRarityScore(n)
                        local priority = (rarity * 15) - dist
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

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if (obj:IsA("Model") or obj:IsA("BasePart")) and not IsInsideMyBase(obj) then
            local n = obj.Name:lower()
            for _, kw in ipairs(EventKeywords) do
                if n:find(kw, 1, true) then
                    local part = obj:IsA("BasePart") and obj or (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true))
                    if part and part.Transparency < 0.9 then
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

local StatusLabelRef = nil

local function CreateMobileUI()
    local existing = PlayerGui:FindFirstChild("RoubeUmOvo_AutoMissionUI")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RoubeUmOvo_AutoMissionUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = PlayerGui

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 250, 0, 245)
    mainFrame.Position = UDim2.new(0.04, 0, 0.22, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = mainFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 185, 255)
    stroke.Thickness = 1.5
    stroke.Parent = mainFrame

    local topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.Size = UDim2.new(1, 0, 0, 34)
    topBar.BackgroundColor3 = Color3.fromRGB(26, 30, 42)
    topBar.BorderSizePixel = 0
    topBar.Parent = mainFrame

    local topCorner = Instance.new("UICorner")
    topCorner.CornerRadius = UDim.new(0, 10)
    topCorner.Parent = topBar

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -45, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "AUTO MISSÕES • OVO"
    title.TextColor3 = Color3.fromRGB(240, 245, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = topBar

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 28, 0, 24)
    minBtn.Position = UDim2.new(1, -33, 0.5, -12)
    minBtn.BackgroundColor3 = Color3.fromRGB(45, 52, 70)
    minBtn.Text = "-"
    minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 16
    minBtn.Parent = topBar

    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 6)
    minCorner.Parent = minBtn

    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -16, 1, -42)
    content.Position = UDim2.new(0, 8, 0, 38)
    content.BackgroundTransparency = 1
    content.Parent = mainFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 6)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = content

    local statusBox = Instance.new("TextLabel")
    statusBox.Size = UDim2.new(1, 0, 0, 26)
    statusBox.BackgroundColor3 = Color3.fromRGB(28, 34, 48)
    statusBox.Text = "Status: Ativo"
    statusBox.TextColor3 = Color3.fromRGB(110, 235, 180)
    statusBox.Font = Enum.Font.GothamSemibold
    statusBox.TextSize = 11
    statusBox.LayoutOrder = 1
    statusBox.Parent = content
    StatusLabelRef = statusBox

    local stCorner = Instance.new("UICorner")
    stCorner.CornerRadius = UDim.new(0, 6)
    stCorner.Parent = statusBox

    local function AddToggle(order, labelText, stateKey)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = State[stateKey] and Color3.fromRGB(22, 115, 85) or Color3.fromRGB(45, 48, 60)
        btn.Text = labelText .. ": " .. (State[stateKey] and "ON" or "OFF")
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 12
        btn.LayoutOrder = order
        btn.Parent = content

        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 6)
        bCorner.Parent = btn

        btn.MouseButton1Click:Connect(function()
            State[stateKey] = not State[stateKey]
            btn.BackgroundColor3 = State[stateKey] and Color3.fromRGB(22, 115, 85) or Color3.fromRGB(45, 48, 60)
            btn.Text = labelText .. ": " .. (State[stateKey] and "ON" or "OFF")
        end)
    end

    AddToggle(2, "Auto Roubar & Entregar", "AutoEggs")
    AddToggle(3, "Auto Itens de Evento", "AutoEvents")
    AddToggle(4, "Auto Esteira (Speed)", "AutoTreadmill")
    AddToggle(5, "Auto Resgatar Missões", "AutoClaim")

    local minimized = false
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        content.Visible = not minimized
        mainFrame.Size = minimized and UDim2.new(0, 250, 0, 34) or UDim2.new(0, 250, 0, 245)
        minBtn.Text = minimized and "+" or "-"
    end)

    local dragging, dragInput, dragStart, startPos
    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    topBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    table.insert(Connections, UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end))
end

local function SetStatus(text)
    State.Status = text
    if StatusLabelRef and StatusLabelRef.Parent then
        StatusLabelRef.Text = "Status: " .. text
    end
end

CreateMobileUI()

task.spawn(function()
    while State.Running do
        if State.AutoClaim then
            pcall(ClaimQuestsAndIndex)
        end
        task.wait(3)
    end
end)

task.spawn(function()
    while State.Running do
        local success, err = pcall(function()
            local _, hrp, hum = GetCharacterParts()
            if not hrp or not hum or hum.Health <= 0 then
                SetStatus("Aguardando personagem...")
                task.wait(1)
                return
            end

            if State.AutoEggs and IsCarryingEgg() then
                local deliverCF = GetDeliverCFrame()
                if deliverCF then
                    SetStatus("Entregando ovo na base...")
                    SmoothMoveTo(deliverCF)
                    task.wait(0.35)
                end
                return
            end

            if State.AutoEvents then
                local evObj, evPart = FindEventCollectible()
                if evObj and evPart then
                    SetStatus("Coletando item de evento...")
                    if SmoothMoveTo(evPart.CFrame + Vector3.new(0, 2, 0)) then
                        InteractWithTarget(evObj)
                        task.wait(0.2)
                    end
                    return
                end
            end

            if State.AutoEggs then
                local eggObj, eggPart = FindBestBiomeEgg()
                if eggObj and eggPart then
                    SetStatus("Indo para: " .. eggObj.Name)
                    if SmoothMoveTo(eggPart.CFrame + Vector3.new(0, 2.5, 0)) then
                        InteractWithTarget(eggObj)
                        task.wait(0.35)
                    end
                    return
                end
            end

            if State.AutoTreadmill then
                local tmCF = GetTreadmillCFrame()
                if tmCF then
                    SetStatus("Farmando velocidade na esteira...")
                    SmoothMoveTo(tmCF)
                    task.wait(1.5)
                    return
                end
            end

            SetStatus("Aguardando respawn de alvos...")
            task.wait(1)
        end)

        if not success then
            SetStatus("Recuperando ciclo...")
            warn("[RoubeUmOvo AutoMissões] Aviso capturado: " .. tostring(err))
            task.wait(1)
        end

        task.wait(0.15)
    end
end)

_G.RoubeUmOvo_Cleanup = function()
    State.Running = false
    NoClipEnabled = false
    if ActiveTween then
        pcall(function() ActiveTween:Cancel() end)
    end
    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    local ui = PlayerGui:FindFirstChild("RoubeUmOvo_AutoMissionUI")
    if ui then ui:Destroy() end
end
