-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Variables
local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local holdingKey = false
local aimbotKey = Enum.KeyCode.F
local espEnabled = false
local espLines = {}
local lockedPlayer = nil
local playerstickEnabled = false
local playerstickTarget = nil
local playerstickDistance = 4 -- Distance to maintain behind the player
local fireRate = 0.1  -- Adjust as needed (fire rate in seconds)

-- GUI Elements (Minimalistic GUI, feel free to customize)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AimbotESPPlayerstickGUI"
screenGui.Parent = game.CoreGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 200, 0, 200)
mainFrame.Position = UDim2.new(0, 10, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 2
mainFrame.BorderColor3 = Color3.fromRGB(255, 255, 255)
mainFrame.Visible = true
mainFrame.Parent = screenGui

local openCloseButton = Instance.new("TextButton")
openCloseButton.Size = UDim2.new(0, 50, 0, 50)
openCloseButton.Position = UDim2.new(0, 10, 0, 10)
openCloseButton.Text = "Close"
openCloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
openCloseButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
openCloseButton.Parent = screenGui

local keyBindLabel = Instance.new("TextLabel")
keyBindLabel.Size = UDim2.new(0, 180, 0, 30)
keyBindLabel.Position = UDim2.new(0, 10, 0, 70)
keyBindLabel.Text = "Aimbot Key: " .. aimbotKey.Name
keyBindLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
keyBindLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
keyBindLabel.Parent = mainFrame

local changeKeyButton = Instance.new("TextButton")
changeKeyButton.Size = UDim2.new(0, 180, 0, 30)
changeKeyButton.Position = UDim2.new(0, 10, 0, 110)
changeKeyButton.Text = "Change Key"
changeKeyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
changeKeyButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
changeKeyButton.Parent = mainFrame

local espToggleButton = Instance.new("TextButton")
espToggleButton.Size = UDim2.new(0, 180, 0, 30)
espToggleButton.Position = UDim2.new(0, 10, 0, 150)
espToggleButton.Text = "ESP: OFF"
espToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
espToggleButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
espToggleButton.Parent = mainFrame

local playerstickToggleButton = Instance.new("TextButton")
playerstickToggleButton.Size = UDim2.new(0, 180, 0, 30)
playerstickToggleButton.Position = UDim2.new(0, 10, 0, 190)
playerstickToggleButton.Text = "Playerstick: OFF"
playerstickToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
playerstickToggleButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
playerstickToggleButton.Parent = mainFrame

-- Crosshair
local crosshair = Drawing.new("Circle")
crosshair.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
crosshair.Radius = 3
crosshair.Color = Color3.fromRGB(255, 0, 0)
crosshair.Filled = true
crosshair.Visible = true

-- Functions
local function getClosestPlayerToCursor()
    local closestPlayer = nil
    local shortestDistance = math.huge

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character and player.Character:FindFirstChild("Head") then
            local head = player.Character.Head
            local screenPoint, onScreen = camera:WorldToScreenPoint(head.Position)

            if onScreen then
                local mousePos = UserInputService:GetMouseLocation()
                local distance = (Vector2.new(mousePos.X, mousePos.Y) - Vector2.new(screenPoint.X, screenPoint.Y)).magnitude

                if distance < shortestDistance then
                    -- Wallcheck
                    local ray = Ray.new(camera.CFrame.Position, (head.Position - camera.CFrame.Position).unit * 500)
                    local part = workspace:FindPartOnRayWithIgnoreList(ray, {localPlayer.Character, camera})

                    if part and part:IsDescendantOf(player.Character) then
                        closestPlayer = player
                        shortestDistance = distance
                    end
                end
            end
        end
    end

    return closestPlayer
end

local function aimAt(target)
    if target and target.Character and target.Character:FindFirstChild("Head") then
        local head = target.Character.Head
        camera.CFrame = CFrame.new(camera.CFrame.Position, head.Position)
    end
end

local function createEspLine(player)
    local espLine = Drawing.new("Line")
    espLine.Thickness = 2
    espLine.Color = Color3.fromRGB(255, 0, 0)
    espLine.Visible = false
    espLines[player] = espLine
end

local function updateEspLine(player)
    local character = player.Character
    if character and character:FindFirstChild("Head") then
        local head = character.Head
        local headPosition, onScreen = camera:WorldToViewportPoint(head.Position)
        local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

        local line = espLines[player]
        if line then
            if onScreen then
                line.From = center
                line.To = Vector2.new(headPosition.X, headPosition.Y)
                line.Visible = espEnabled
            else
                line.Visible = false
            end
        end
    else
        if espLines[player] then
            espLines[player].Visible = false
        end
    end
end

local function removeEspLine(player)
    if espLines[player] then
        espLines[player]:Remove()
        espLines[player] = nil
    end
end

local function updateAllEspLines()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            if not espLines[player] then
                createEspLine(player)
            end
            updateEspLine(player)
        end
    end
    for player, line in pairs(espLines) do
        if not Players:FindFirstChild(player.Name) then
            removeEspLine(player)
        end
    end
end

local function stickPlayerBehind(target)
    if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
        local humanoidRootPart = target.Character.HumanoidRootPart
        local direction = (camera.CFrame.Position - humanoidRootPart.Position).unit
        local newPosition = humanoidRootPart.Position + direction * playerstickDistance

        localPlayer.Character:SetPrimaryPartCFrame(CFrame.new(newPosition))
    end
end

-- Event Listeners
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed then
        if input.KeyCode == aimbotKey then
            holdingKey = true
        elseif input.KeyCode == Enum.KeyCode.Q then  -- Example: Toggle playerstick with 'Q'
            playerstickEnabled = not playerstickEnabled
            playerstickToggleButton.Text = "Playerstick: " .. (playerstickEnabled and "ON" or "OFF")
            if not playerstickEnabled then
                playerstickTarget = nil
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, processed)
    if input.KeyCode == aimbotKey then
        holdingKey = false
        lockedPlayer = nil
    end
end)

RunService.RenderStepped:Connect(function()
    if holdingKey then
        if not lockedPlayer or not lockedPlayer.Character or not lockedPlayer.Character:FindFirstChild("Head") then
            lockedPlayer = getClosestPlayerToCursor()
        end
        aimAt(lockedPlayer)
    end
    if espEnabled then
        updateAllEspLines()
    end
    if playerstickEnabled and playerstickTarget then
        stickPlayerBehind(playerstickTarget)
    end
end)

openCloseButton.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
    openCloseButton.Text = mainFrame.Visible and "Close" or "Open"
end)

changeKeyButton.MouseButton1Click:Connect(function()
    changeKeyButton.Text = "Press a Key..."
    local connection
    connection = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Keyboard then
            aimbotKey = input.KeyCode
            keyBindLabel.Text = "Aimbot Key: " .. aimbotKey.Name
            changeKeyButton.Text = "Change Key"
            connection:Disconnect()
        end
    end)
end)

espToggleButton.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    espToggleButton.Text = "ESP: " .. (espEnabled and "ON" or "OFF")
    if not espEnabled then
        for _, line in pairs(espLines) do
            line.Visible = false
        end
    end
end)

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        if espEnabled then
            createEspLine(player)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    removeEspLine(player)
    if playerstickTarget == player then
        playerstickTarget = nil
    end
end)

-- Initialize ESP lines for existing players
for _, player in pairs(Players:GetPlayers()) do
    if player ~= localPlayer then
        createEspLine(player)
    end
end
