-- ============================================================
--  RESIDENCE MASSACRE | Fullbright + Speed
--  Клиентский скрипт под Residence Massacre.
--  Только клиентские свойства: Lighting + Humanoid.WalkSpeed.
--  Никакого вмешательства в сервер и обхода защиты.
--
--  Repo:   https://github.com/blegbot1/ResidenceMassacre
--  Loader: raw.../refs/heads/main/ResidenceMassacre.lua
--  Запуск: loadstring(game:HttpGet("https://raw.githubusercontent.com/blegbot1/ResidenceMassacre/refs/heads/main/ResidenceMassacre.lua",true))()
--
--  Ввод сделан через UserInputService + ручной хит-тест,
--  потому что UI игры перехватывает клики по GuiObject'ам.
-- ============================================================

-- Place ID Residence Massacre.
-- Заполни, чтобы скрипт работал ТОЛЬКО в этой игре (nil = в любой).
local ONLY_PLACE_ID = nil

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local LP = Players.LocalPlayer

if ONLY_PLACE_ID and game.PlaceId ~= ONLY_PLACE_ID then
    warn("[RM] это не Residence Massacre (PlaceId " .. tostring(game.PlaceId) .. ") — выход")
    return
end

local G = getgenv()
G.RM_FB = G.RM_FB or true            -- fullbright
G.RM_Bright = G.RM_Bright or 3       -- яркость 0..10
G.RM_NoFog = G.RM_NoFog or true      -- без тумана/теней
G.RM_SpeedOn = G.RM_SpeedOn or false -- ВЫКЛ по умолчанию: скорость чаще всего триггерит кик
G.RM_Speed = G.RM_Speed or 50        -- скорость 0..300
G.RM_Poll = G.RM_Poll or 1           -- как часто возвращать значения (сек)

-- ================= применение =================
-- пишем свойство ТОЛЬКО если оно реально отличается.
-- постоянные записи -> desync -> кик (Error 267)
local function setProp(obj, name, value)
    pcall(function()
        local cur = obj[name]
        local same
        if typeof(value) == "number" then
            same = (typeof(cur) == "number") and math.abs(cur - value) <= 0.01
        else
            same = cur == value
        end
        if not same then
            obj[name] = value
        end
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

LP.CharacterAdded:Connect(function()
    task.wait(0.3)
    applySpeed()
end)

-- ================= интерфейс =================
local BG = Color3.fromRGB(18, 14, 28)
local EL = Color3.fromRGB(26, 20, 40)
local HOVER = Color3.fromRGB(38, 28, 58)
local PURPLE = Color3.fromRGB(150, 90, 235)
local DIM = Color3.fromRGB(120, 115, 135)
local TEXT = Color3.fromRGB(235, 230, 245)

local gui = Instance.new("ScreenGui")
gui.Name = "ResidenceMassacreTool"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999          -- поверх игрового UI
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = LP:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(250, 250)
panel.Position = UDim2.fromOffset(20, 20)
panel.BackgroundColor3 = BG
panel.BorderSizePixel = 0
panel.Active = true
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", panel)
stroke.Color = PURPLE
stroke.Thickness = 1
stroke.Transparency = 0.4

local function mkLabel(parent, text, size)
    local l = Instance.new("TextLabel")
    l.Text = text
    l.Size = size
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.GothamSemibold
    l.TextColor3 = TEXT
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Active = false
    l.Parent = parent
    return l
end

local title = mkLabel(panel, "RESIDENCE MASSACRE | Fullbright", UDim2.new(1, -20, 0, 24))
title.Position = UDim2.fromOffset(10, 6)
title.TextSize = 15

-- всё кликабельное регистрируется тут: {rect(), onClick()}
local buttons = {}
local sliders = {}
local TITLE_H = 26

local function inRect(p, pos, size)
    return p.X >= pos.X and p.X <= pos.X + size.X and p.Y >= pos.Y and p.Y <= pos.Y + size.Y
end

local function mkToggle(y, text, flag)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -20, 0, 26)
    holder.Position = UDim2.fromOffset(10, y)
    holder.BackgroundColor3 = BG
    holder.BorderSizePixel = 0
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
        state.TextColor3 = on and PURPLE or DIM
        holder.BackgroundColor3 = on and EL or BG
    end

    buttons[#buttons + 1] = {
        get = function() return holder.AbsolutePosition, holder.AbsoluteSize end,
        cb = function()
            G[flag] = not G[flag]
            paint()
            applyLight()
            applySpeed()
        end,
        hover = function(on) holder.BackgroundColor3 = on and HOVER or (G[flag] and EL or BG) end,
    }
    paint()
end

mkToggle(34, "Fullbright", "RM_FB")
mkToggle(64, "No fog / shadows", "RM_NoFog")
mkToggle(94, "Speed hack", "RM_SpeedOn")

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
    bar.Size = UDim2.new(1, 0, 0, 10)
    bar.Position = UDim2.fromOffset(0, 20)
    bar.BackgroundColor3 = EL
    bar.BorderSizePixel = 0
    bar.Parent = holder
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.fromScale(0, 1)
    fill.BackgroundColor3 = PURPLE
    fill.BorderSizePixel = 0
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local function paint()
        local v = G[flag]
        val.Text = tostring(v) .. (stepTxt or "")
        fill.Size = UDim2.fromScale(math.clamp((v - min) / (max - min), 0, 1), 1)
    end

    local function setFromX(x)
        local size = bar.AbsoluteSize.X
        if size <= 0 then return end
        local frac = math.clamp((x - bar.AbsolutePosition.X) / size, 0, 1)
        local v = min + (max - min) * frac
        v = math.floor(v / step + 0.5) * step
        G[flag] = v
        paint()
        applyLight()
        applySpeed()
    end

    sliders[#sliders + 1] = {
        get = function() return bar.AbsolutePosition, bar.AbsoluteSize end,
        onDown = function(p) setFromX(p.X) end,
        onMove = function(p) setFromX(p.X) end,
    }
    paint()
end

mkSlider(126, "Brightness", "RM_Bright", 0, 10, 0.5, "")
mkSlider(166, "Speed", "RM_Speed", 0, 300, 1, " st")
mkSlider(206, "Check every", "RM_Poll", 0.1, 5, 0.1, " s")

-- ================= ввод (ручной хит-тест) =================
local draggingPanel = false
local draggingSlider = nil
local dragOff = Vector2.new(0, 0)
local hoverBtn = nil

local function isDown(input)
    local t = input.UserInputType
    return t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
end

UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if not isDown(input) then return end
    local p = input.Position
    if not inRect(p, panel.AbsolutePosition, panel.AbsoluteSize) then return end

    -- слайдер?
    for _, s in ipairs(sliders) do
        local pos, size = s.get()
        if inRect(p, pos, size) then
            draggingSlider = s
            s.onDown(p)
            return
        end
    end

    -- кнопка?
    for _, b in ipairs(buttons) do
        local pos, size = b.get()
        if inRect(p, pos, size) then
            b.cb()
            return
        end
    end

    -- иначе тянем окно за шапку
    if p.Y <= panel.AbsolutePosition.Y + TITLE_H then
        draggingPanel = true
        dragOff = Vector2.new(p.X - panel.AbsolutePosition.X, p.Y - panel.AbsolutePosition.Y)
    end
end)

UIS.InputMoved:Connect(function(input)
    local p = input.Position
    if draggingSlider then
        draggingSlider.onMove(p)
        return
    end
    if draggingPanel then
        panel.Position = UDim2.new(0, p.X - dragOff.X, 0, p.Y - dragOff.Y)
        return
    end
    -- подсветка кнопки под курсором
    local inside = inRect(p, panel.AbsolutePosition, panel.AbsoluteSize)
    local newHover = nil
    if inside then
        for i, b in ipairs(buttons) do
            local pos, size = b.get()
            if inRect(p, pos, size) then
                newHover = i
                break
            end
        end
    end
    if newHover ~= hoverBtn then
        if hoverBtn and buttons[hoverBtn] and buttons[hoverBtn].hover then
            buttons[hoverBtn].hover(false)
        end
        hoverBtn = newHover
        if hoverBtn and buttons[hoverBtn].hover then
            buttons[hoverBtn].hover(true)
        end
    end
end)

UIS.InputEnded:Connect(function(input)
    if isDown(input) then
        draggingPanel = false
        draggingSlider = nil
    end
end)

-- ================= главный цикл =================
-- Опрос раз в секунду: реже = меньше нагрузки и риска кика.
-- setProp пишет только при реальном отличии, в покое нагрузка нулевая.
task.spawn(function()
    while true do
        applyLight()
        applySpeed()
        local poll = G.RM_Poll or 1
        if poll < 0.1 then poll = 0.1 end
        task.wait(poll)
    end
end)

print("[RESIDENCE MASSACRE] Fullbright + Speed loaded | drag = move window, drag slider = set value")