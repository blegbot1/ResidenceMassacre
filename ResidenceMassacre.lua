-- ============================================================
--  RESIDENCE MASSACRE | Fullbright + Speed
--  Клиентский скрипт под Residence Massacre.
--  Только клиентские свойства: Lighting + Humanoid.WalkSpeed.
--  Никакого вмешательства в сервер и обхода защиты.
--
--  Repo: https://github.com/blegbot1/ResidenceMassacre
--  Loader: raw.../refs/heads/main/ResidenceMassacre.lua
--
--  Респавн подхватывается сам через CharacterAdded.
-- ============================================================

-- Place ID Residence Massacre.
-- Заполни, чтобы скрипт работал ТОЛЬКО в этой игре (nil = в любой).
local ONLY_PLACE_ID = nil

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local LP = Players.LocalPlayer

if ONLY_PLACE_ID and game.PlaceId ~= ONLY_PLACE_ID then
    warn("[RM] это не Residence Massacre (PlaceId " .. tostring(game.PlaceId) .. ") — выход")
    return
end

local G = getgenv()
G.RM_FB = G.RM_FB or true          -- fullbright
G.RM_Bright = G.RM_Bright or 3     -- яркость 0..10
G.RM_NoFog = G.RM_NoFog or true    -- без тумана/теней
G.RM_Speed = G.RM_Speed or 50      -- скорость 0..300
G.RM_SpeedOn = G.RM_SpeedOn or true

-- ---------------- применение ----------------
local function setProp(obj, name, value)
    pcall(function()
        obj[name] = value
    end)
end

local function applyLight()
    if not G.RM_FB then return end
    local b = G.RM_Bright or 3
    setProp(Lighting, "Brightness", b)
    setProp(Lighting, "ClockTime", 14)
    setProp(Lighting, "Ambient", Color3.fromRGB(200, 200, 200))
    setProp(Lighting, "OutdoorAmbient", Color3.fromRGB(200, 200, 200))
    setProp(Lighting, "ColorShift_Top", Color3.fromRGB(255, 255, 255))
    setProp(Lighting, "ColorShift_Bottom", Color3.fromRGB(255, 255, 255))
    setProp(Lighting, "ExposureCompensation", 0.4)
    setProp(Lighting, "EnvironmentDiffuseScale", 1)
    setProp(Lighting, "EnvironmentSpecularScale", 0)
    if G.RM_NoFog then
        setProp(Lighting, "GlobalShadows", false)
        setProp(Lighting, "FogStart", -100000)
        setProp(Lighting, "FogEnd", 100000)
        setProp(Lighting, "FogColor", Color3.fromRGB(255, 255, 255))
    end
end

local function applySpeed()
    if not G.RM_SpeedOn then return end
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if hum and hum.Parent then
        setProp(hum, "WalkSpeed", G.RM_Speed or 50)
    end
end

-- ловим респавн
LP.CharacterAdded:Connect(function()
    task.wait(0.3)
    applySpeed()
end)

-- ---------------- интерфейс ----------------
local BG = Color3.fromRGB(18, 14, 28)
local EL = Color3.fromRGB(24, 18, 38)
local PURPLE = Color3.fromRGB(150, 90, 235)
local TEXT = Color3.fromRGB(235, 230, 245)

local gui = Instance.new("ScreenGui")
gui.Name = "ResidenceMassacreTool"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = LP:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(250, 208)
panel.Position = UDim2.fromOffset(20, 20)
panel.BackgroundColor3 = BG
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", panel)
stroke.Color = PURPLE
stroke.Thickness = 1
stroke.Transparency = 0.4

local function mkLabel(parent, text, size, bold)
    local l = Instance.new("TextLabel")
    l.Text = text
    l.Size = size
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.GothamSemibold
    l.TextColor3 = TEXT
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local title = mkLabel(panel, "RESIDENCE MASSACRE | Fullbright", UDim2.new(1, -20, 0, 24), true)
title.Position = UDim2.fromOffset(10, 8)
title.TextSize = 15

local function mkToggle(y, text, flag)
    local holder = Instance.new("TextButton")
    holder.Size = UDim2.new(1, -20, 0, 26)
    holder.Position = UDim2.fromOffset(10, y)
    holder.BackgroundColor3 = EL
    holder.Text = ""
    holder.AutoButtonColor = false
    holder.Parent = panel
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 6)

    local lbl = mkLabel(holder, text, UDim2.new(1, -60, 1, 0))
    lbl.Position = UDim2.fromOffset(8, 0)
    lbl.TextSize = 13

    local state = mkLabel(holder, "", UDim2.new(0, 44, 1, 0))
    state.Position = UDim2.new(1, -52, 0, 0)
    state.TextXAlignment = Enum.TextXAlignment.Right
    state.TextSize = 13

    local function paint()
        local on = G[flag]
        state.Text = on and "ON" or "OFF"
        state.TextColor3 = on and PURPLE or Color3.fromRGB(120, 115, 135)
        holder.BackgroundColor3 = on and EL or BG
    end

    holder.MouseButton1Click:Connect(function()
        G[flag] = not G[flag]
        paint()
        applyLight()
        applySpeed()
    end)
    paint()
    return holder
end

mkToggle(38, "Fullbright", "RM_FB")
mkToggle(68, "No fog / shadows", "RM_NoFog")
mkToggle(98, "Speed hack", "RM_SpeedOn")

-- слайдеры: brightness + speed
local function mkSlider(y, text, flag, min, max, step, stepTxt)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -20, 0, 34)
    holder.Position = UDim2.fromOffset(10, y)
    holder.BackgroundTransparency = 1
    holder.Parent = panel

    local lbl = mkLabel(holder, text, UDim2.new(0.6, 0, 0, 16))
    lbl.Position = UDim2.fromOffset(0, 0)
    lbl.TextSize = 13

    local val = mkLabel(holder, "", UDim2.new(0.4, 0, 0, 16))
    val.Position = UDim2.new(0.6, 0, 0, 0)
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.TextSize = 13
    val.TextColor3 = PURPLE

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 8)
    bar.Position = UDim2.fromOffset(0, 20)
    bar.BackgroundColor3 = EL
    bar.Parent = holder
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.fromScale(0, 1)
    fill.BackgroundColor3 = PURPLE
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local function paint()
        local v = G[flag]
        val.Text = tostring(v) .. (stepTxt or "")
        fill.Size = UDim2.fromScale(math.clamp((v - min) / (max - min), 0, 1), 1)
    end

    local dragging = false
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
            input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
            input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or
            input.UserInputType == Enum.UserInputType.Touch then
            local pos = input.Position.X
            local size = bar.AbsoluteSize.X
            if size <= 0 then return end
            local frac = math.clamp((pos - bar.AbsolutePosition.X) / size, 0, 1)
            local v = min + (max - min) * frac
            v = math.floor(v / step + 0.5) * step
            G[flag] = v
            paint()
            applyLight()
            applySpeed()
        end
    end)

    paint()
end

mkSlider(130, "Brightness", "RM_Bright", 0, 10, 0.5, "")
mkSlider(170, "Speed", "RM_Speed", 0, 300, 1, " st")

-- перетаскивание окна
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local p = input.Position
        local pos = panel.AbsolutePosition
        local size = panel.AbsoluteSize
        if p.X >= pos.X and p.X <= pos.X + size.X and p.Y >= pos.Y and p.Y <= pos.Y + 26 then
            local ox = p.X - pos.X
            local oy = p.Y - pos.Y
            local dragging = true
            local conn
            conn = UIS.InputChanged:Connect(function(i2)
                if dragging then
                    panel.Position = UDim2.new(0, i2.Position.X - ox, 0, i2.Position.Y - oy)
                end
            end)
            UIS.InputEnded:Connect(function()
                dragging = false
                if conn then
                    conn:Disconnect()
                    conn = nil
                end
            end)
        end
    end
end)

-- ---------------- главный цикл ----------------
task.spawn(function()
    while true do
        -- форсим каждый кадр: игры часто сбрасывают свет и скорость
        applyLight()
        applySpeed()
        task.wait(0.05)
    end
end)

print("[RESIDENCE MASSACRE] Fullbright + Speed loaded | drag sliders, top bar = move window")