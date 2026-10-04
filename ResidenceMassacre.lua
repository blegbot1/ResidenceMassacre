-- ============================================================
--  ELITE HUB | Residence Massacre (Fullbright)
--  GUI на библиотеке Rayfield (как в Fort Blox).
--  Только клиентские свойства Lighting — серверная проверка
--  скорости кикает сходу, поэтому Speed убран.
--  Античит НЕ обходим: запись свойств только при изменении,
--  опрос 1с, в покое нагрузка нулевая.
--
--  Repo:   https://github.com/blegbot1/ResidenceMassacre
--  Запуск: loadstring(game:HttpGet("https://raw.githubusercontent.com/blegbot1/ResidenceMassacre/refs/heads/main/ResidenceMassacre.lua",true))()
-- ============================================================

-- Place ID Residence Massacre.
-- Заполни, чтобы скрипт работал ТОЛЬКО в этой игре (nil = в любой).
local ONLY_PLACE_ID = nil

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local LP = Players.LocalPlayer

if ONLY_PLACE_ID and game.PlaceId ~= ONLY_PLACE_ID then
    warn("[RM] это не Residence Massacre (PlaceId " .. tostring(game.PlaceId) .. ") — выход")
    return
end

local G = getgenv()
G.RM_FB = G.RM_FB ~= nil and G.RM_FB or true          -- fullbright
G.RM_Bright = G.RM_Bright or 3                        -- яркость 0..10
G.RM_NoFog = G.RM_NoFog ~= nil and G.RM_NoFog or true -- без тумана/теней
G.RM_Poll = G.RM_Poll or 1                            -- как часто возвращать значения (сек)

-- ================= применение =================
-- пишем свойство ТОЛЬКО если оно реально отличается.
-- постоянные записи -> desync -> кик (Error 267 "Possible exploit")
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

-- ================= Rayfield =================
local Rayfield = nil
local rayUrls = {
    "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua",
    "https://sirius.menu/rayfield",
}
for _, u in ipairs(rayUrls) do
    local ok, res = pcall(function()
        return loadstring(game:HttpGet(u, true))()
    end)
    if ok and type(res) == "table" and res.CreateWindow then
        Rayfield = res
        break
    end
end
if not Rayfield then
    warn("[RM] Rayfield не загрузился — проверь интернет/экзекутор (httpget должен быть разрешён)")
    return
end

-- ================= ELITE HUB theme (black / purple) =================
-- та же таблица темы, что и в Fort Blox — Rayfield принимает её как есть
getgenv().RM_Theme = {
    TextColor = Color3.fromRGB(235, 230, 245),

    Background = Color3.fromRGB(12, 10, 18),
    Topbar = Color3.fromRGB(20, 16, 30),
    Shadow = Color3.fromRGB(5, 4, 10),

    NotificationBackground = Color3.fromRGB(22, 18, 34),
    NotificationActionsBackground = Color3.fromRGB(190, 160, 230),

    TabBackground = Color3.fromRGB(30, 24, 44),
    TabStroke = Color3.fromRGB(60, 44, 90),
    TabBackgroundSelected = Color3.fromRGB(138, 84, 220),
    TabTextColor = Color3.fromRGB(200, 190, 220),
    SelectedTabTextColor = Color3.fromRGB(255, 255, 255),

    ElementBackground = Color3.fromRGB(24, 20, 36),
    ElementBackgroundHover = Color3.fromRGB(36, 30, 54),
    SecondaryElementBackground = Color3.fromRGB(18, 15, 28),
    ElementStroke = Color3.fromRGB(52, 40, 74),
    SecondaryElementStroke = Color3.fromRGB(44, 34, 64),

    SliderBackground = Color3.fromRGB(60, 44, 90),
    SliderProgress = Color3.fromRGB(150, 90, 235),
    SliderStroke = Color3.fromRGB(170, 110, 245),

    ToggleBackground = Color3.fromRGB(30, 24, 44),
    ToggleEnabled = Color3.fromRGB(150, 90, 235),
    ToggleDisabled = Color3.fromRGB(70, 55, 90),
    ToggleEnabledStroke = Color3.fromRGB(180, 130, 250),
    ToggleDisabledStroke = Color3.fromRGB(100, 80, 125),
    ToggleEnabledOuterStroke = Color3.fromRGB(110, 70, 160),
    ToggleDisabledOuterStroke = Color3.fromRGB(60, 48, 80),

    DropdownSelected = Color3.fromRGB(44, 34, 66),
    DropdownUnselected = Color3.fromRGB(22, 18, 34),

    InputBackground = Color3.fromRGB(22, 18, 34),
    InputStroke = Color3.fromRGB(70, 52, 100),
    PlaceholderColor = Color3.fromRGB(120, 105, 150),
}
local ELITE = getgenv().RM_Theme

local function notify(text, dur)
    pcall(function()
        Rayfield:Notify({ Title = "ELITE HUB", Content = text, Duration = dur or 3 })
    end)
end

local Window = Rayfield:CreateWindow({
    Name = "ELITE HUB | Residence Massacre",
    LoadingTitle = "ELITE HUB",
    LoadingSubtitle = "Residence Massacre | Fullbright",
    Theme = ELITE,
    ConfigurationSaving = { Enabled = true, FolderName = "RMScripts", FileName = "ResidenceMassacre" },
    KeySystem = false,
})

-- плавный фиолетовый градиент на шапке окна (только фон, без иконок/текста)
pcall(function()
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    local topbar = nil
    for _, g in ipairs(pg:GetChildren()) do
        if g:IsA("ScreenGui") then
            local m = g:FindFirstChild("Main", true)
            if m then
                local tb = m:FindFirstChild("Topbar")
                if tb then topbar = tb break end
            end
        end
    end
    if not topbar then return end
    local targets = {topbar}
    for _, child in ipairs(topbar:GetChildren()) do
        -- только обычные контейнеры-фреймы (пропускаем кнопки/иконки/текст/поиск)
        if child:IsA("Frame") and child.Name ~= "Search" and not child:FindFirstChildWhichIsA("GuiObject", true) then
            targets[#targets + 1] = child
        end
    end
    for _, d in ipairs(targets) do
        if d:IsA("Frame") and not d:FindFirstChildOfClass("UIGradient") then
            local g = Instance.new("UIGradient")
            g.Name = "EliteGradient"
            g.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 90, 235)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(105, 55, 190)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(45, 25, 75)),
            })
            g.Rotation = 0
            pcall(function() d.BackgroundTransparency = 0 end)
            g.Parent = d
        end
    end
end)

-- ================= вкладка =================
local Main = Window:CreateTab("Main", 4483362458)

Main:CreateLabel("Fullbright | клиентские свойства | без обхода античита")

Main:CreateToggle({
    Name = "Fullbright",
    CurrentValue = G.RM_FB,
    Flag = "RM_FB",
    Callback = function(v)
        G.RM_FB = v
        applyLight()
        notify("Fullbright: " .. (v and "ON" or "OFF"), 2)
    end,
})

Main:CreateToggle({
    Name = "No fog / shadows",
    CurrentValue = G.RM_NoFog,
    Flag = "RM_NoFog",
    Callback = function(v)
        G.RM_NoFog = v
        applyLight()
    end,
})

Main:CreateSlider({
    Name = "Brightness",
    Range = {0, 10},
    Increment = 0.5,
    CurrentValue = G.RM_Bright,
    Flag = "RM_Bright",
    Callback = function(v)
        G.RM_Bright = v
        applyLight()
    end,
})

Main:CreateSlider({
    Name = "Check every",
    Range = {0.1, 5},
    Increment = 0.1,
    Suffix = " s",
    CurrentValue = G.RM_Poll,
    Flag = "RM_Poll",
    Callback = function(v)
        G.RM_Poll = v
    end,
})

Main:CreateLabel("Speed убран: серверная проверка кикает на движении")

-- ================= главный цикл =================
-- Опрос раз в секунду: реже = меньше нагрузки и риска кика.
-- setProp пишет только при реальном отличии, в покое нагрузка нулевая.
task.spawn(function()
    while true do
        pcall(applyLight)
        local poll = G.RM_Poll or 1
        if poll < 0.1 then poll = 0.1 end
        task.wait(poll)
    end
end)

print("[RESIDENCE MASSACRE] v3.0 rayfield loaded | ELITE HUB | Fullbright работает, Speed удалён")