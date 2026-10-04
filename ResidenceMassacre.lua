-- ============================================================
--  ELITE HUB | Residence Massacre (Fullbright + TP Speed +
--  Stamina + Mutant ESP)
--  GUI на библиотеке Rayfield (как в Fort Blox).
--  Клиентские свойства Lighting + TP walk + лок стамины +
--  ESP мутанта (Highlight + метка через стены).
--  Античит НЕ обходим: всё включается вручную и на свой риск.
--
--  Repo:   https://github.com/blegbot1/ResidenceMassacre
--  Запуск: loadstring(game:HttpGet("https://raw.githubusercontent.com/blegbot1/ResidenceMassacre/refs/heads/main/ResidenceMassacre.lua",true))()
-- ============================================================

-- Place ID Residence Massacre.
-- Заполни, чтобы скрипт работал ТОЛЬКО в этой игре (nil = в любой).
local ONLY_PLACE_ID = nil

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
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
G.RM_TPSpeed = false                                  -- TP walk (ВЫКЛ по умолчанию)
G.RM_TPSpeedVal = G.RM_TPSpeedVal or 50               -- скорость телепорта, studs/s
G.RM_StaminaLock = false                              -- infinite stamina (ВЫКЛ по умолчанию)

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

-- оригинальные значения освещения, снятые при запуске:
-- выключение fullbright/no-fog должно ВОЗВРАЩАТЬ темноту,
-- а не оставлять наши записи висеть
local ORIG = {}
local BRIGHT = {"Brightness", "ClockTime", "Ambient", "OutdoorAmbient",
    "ColorShift_Top", "ColorShift_Bottom", "ExposureCompensation",
    "EnvironmentDiffuseScale", "EnvironmentSpecularScale"}
local FOG = {"GlobalShadows", "FogStart", "FogEnd", "FogColor"}
for _, name in ipairs(BRIGHT) do
    local ok, v = pcall(function() return Lighting[name] end)
    if ok then ORIG[name] = v end
end
for _, name in ipairs(FOG) do
    local ok, v = pcall(function() return Lighting[name] end)
    if ok then ORIG[name] = v end
end

local function restoreGroup(list)
    for _, name in ipairs(list) do
        local v = ORIG[name]
        if v ~= nil then setProp(Lighting, name, v) end
    end
end

local function applyLight()
    -- fullbright (или возврат оригинала)
    if G.RM_FB then
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
    else
        restoreGroup(BRIGHT)
    end
    -- no fog / shadows (или возврат оригинала)
    if G.RM_NoFog then
        setProp(Lighting, "GlobalShadows", false)
        setProp(Lighting, "FogStart", -100000)
        setProp(Lighting, "FogEnd", 100000)
        setProp(Lighting, "FogColor", Color3.fromRGB(255, 255, 255))
    else
        restoreGroup(FOG)
    end
end

-- ================= TP walk (speed без WalkSpeed) =================
-- Двигаем HumanoidRootPart телепортами по направлению взгляда.
-- WalkSpeed остаётся штатной — сервер видит телепорты позиции,
-- а не скорость. Shift = ускорение x1.6.
local camFwd, camRight = nil, nil
local groundT = 0
local standOffset = nil -- реальная высота стойки над землёй (замер, не хардкод)

local function moveKeys()
    local x, z = 0, 0
    if UIS:IsKeyDown(Enum.KeyCode.W) then z = z + 1 end
    if UIS:IsKeyDown(Enum.KeyCode.S) then z = z - 1 end
    if UIS:IsKeyDown(Enum.KeyCode.A) then x = x - 1 end
    if UIS:IsKeyDown(Enum.KeyCode.D) then x = x + 1 end
    local sprint = 1
    if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then sprint = 1.6 end
    return x, z, sprint
end

RunService.RenderStepped:Connect(function(dt)
    if not G.RM_TPSpeed then return end
    pcall(function()
        local cam = workspace.CurrentCamera
        if not cam then return end
        local ch = LP.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if not hrp or not hrp.Parent then return end

        local x, z, sprint = moveKeys()
        if x == 0 and z == 0 then return end

        camFwd = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z).Unit
        camRight = Vector3.new(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z).Unit

        local spd = (G.RM_TPSpeedVal or 50) * sprint
        local step = spd * math.min(dt, 0.05)
        local np = hrp.Position + camFwd * z * step + camRight * x * step

        -- Держим корпус на земле БЕЗ рывков вверх:
        --  * замеряем реальную высоту стойки (не хардкод "+1");
        --  * рейкаст вниз раз в 0.1с;
        --  * подъём больше 1.5 студа (мусор/объект на полу) игнорируем,
        --    вниз опускаем плавно, не более 5 студ за тик.
        local now = os.clock()
        if now - groundT > 0.1 then
            groundT = now
            local params = RaycastParams.new()
            params.FilterDescendantsInstances = {ch}
            params.IgnoreWater = true

            -- эталон: сколько корпус реально стоит над землёй прямо сейчас
            local under = workspace:Raycast(hrp.Position, Vector3.new(0, -30, 0), params)
            if under then
                local off = hrp.Position.Y - under.Position.Y
                if off >= 0 and off < 6 then
                    standOffset = off
                end
            end
            local off = standOffset or 2

            -- земля под целевой точкой (старт чуть выше — ловим подъём)
            local res = workspace:Raycast(
                Vector3.new(np.X, np.Y + 2, np.Z),
                Vector3.new(0, -80, 0), params)
            if res then
                local targetY = res.Position.Y + off
                local rise = targetY - np.Y
                if rise <= 0 then
                    np = Vector3.new(np.X, math.max(targetY, np.Y - 5), np.Z)
                elseif rise <= 1.5 then
                    np = Vector3.new(np.X, targetY, np.Z)
                end
                -- rise > 1.5: держим текущую высоту — без прыжка вверх
            end
        end

        hrp.CFrame = CFrame.new(np) * (hrp.CFrame - hrp.CFrame.Position)
    end)
end)

-- ================= infinite stamina (разовое обнаружение + лок) =================
-- Не сканируем постоянно: ОДИН раз находим реальную стамину
-- (та, что падает при беге), запоминаем ссылку и дальше крутим
-- только её. Рескан только если значение исчезло (респавн).
G.RM_StaminaLock = G.RM_StaminaLock or false
local stamNames = {"stam", "stmina", "energy", "fatigue", "sprint", "endurance"}
local stamRef = nil     -- {v=Instance, max=number, path=string}
local stamNoteOnce = false

-- плашка внизу экрана: показывает, что бесконечная стамина ВКЛ.
-- Лежит в CoreGui (не в PlayerGui): игра при ESC правит только PlayerGui.
local stamStatus, stamStatusGui = nil, nil
local function ensureStatusGui()
    pcall(function()
        if stamStatusGui and stamStatusGui.Parent then return end
        local CoreGui = game:GetService("CoreGui")
        local sg = Instance.new("ScreenGui")
        sg.Name = "RM_StaminaStatus"
        sg.ResetOnSpawn = false
        sg.DisplayOrder = 100000
        sg.Parent = CoreGui

        local lbl = Instance.new("TextLabel")
        lbl.Name = "Status"
        lbl.AnchorPoint = Vector2.new(0.5, 1)
        lbl.Position = UDim2.new(0.5, 0, 1, -20)
        lbl.Size = UDim2.fromOffset(260, 24)
        lbl.BackgroundColor3 = Color3.fromRGB(18, 14, 28)
        lbl.BackgroundTransparency = 0.3
        lbl.BorderSizePixel = 0
        lbl.Font = Enum.Font.GothamBold
        lbl.TextColor3 = Color3.fromRGB(120, 255, 140)
        lbl.TextSize = 13
        lbl.Text = "БЕСКОНЕЧНАЯ СТАМИНА: ВКЛ"
        lbl.Visible = false
        Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 6)
        lbl.Parent = sg

        stamStatusGui = sg
        stamStatus = lbl
    end)
end
ensureStatusGui()

local function isStamCandidate(v)
    if not (v:IsA("NumberValue") or v:IsA("IntValue") or v:IsA("IntConstrainedValue")) then
        return false
    end
    local n = string.lower(v.Name)
    for _, s in ipairs(stamNames) do
        if string.find(n, s, 1, true) then return true end
    end
    return false
end

-- короткое наблюдение (~1.2с): кто реально падает — тот и стамина
local function discoverStaminaOnce()
    local cands = {}
    local roots = {LP, LP.Character}
    for _, r in ipairs(roots) do
        if r then
            for _, d in ipairs(r:GetDescendants()) do
                if isStamCandidate(d) then
                    local ok, cur = pcall(function() return d.Value end)
                    if ok and type(cur) == "number" then
                        cands[#cands + 1] = {v = d, mn = cur, mx = cur}
                    end
                end
            end
        end
    end
    if #cands == 0 then return nil end
    -- наблюдаем 1.2с (в это время беги!), фиксируем мин/макс
    local t0 = os.clock()
    while os.clock() - t0 < 1.2 do
        for _, c in ipairs(cands) do
            if c.v.Parent then
                local ok, val = pcall(function() return c.v.Value end)
                if ok and type(val) == "number" then
                    if val < c.mn then c.mn = val end
                    if val > c.mx then c.mx = val end
                end
            end
        end
        task.wait(0.1)
    end
    -- кандидат с самым большим разбросом = тот, что реально падает при беге
    local best = cands[1]
    for i = 2, #cands do
        if (cands[i].mx - cands[i].mn) > (best.mx - best.mn) then
            best = cands[i]
        end
    end
    local okN, fn = pcall(function() return best.v:GetFullName() end)
    return { v = best.v, max = best.mx, path = okN and fn or best.v.Name }
end

task.spawn(function()
    while true do
        pcall(function()
            stamStatus.Visible = G.RM_StaminaLock == true
        end)
        if G.RM_StaminaLock then
            pcall(function()
                -- значение исчезло (респавн) -> переобнаружение
                if stamRef and (not stamRef.v or stamRef.v.Parent == nil) then stamRef = nil end
                if not stamRef then
                    local r = discoverStaminaOnce()
                    if r then
                        stamRef = r
                    elseif not stamNoteOnce then
                        stamNoteOnce = true
                        print("[RM] Стамина: значение не найдено — если не работает, скажи имя поля из Explorer")
                    end
                end
                -- крутим только одну ссылку, пишем только при отличии
                if stamRef then
                    local ok, cur = pcall(function() return stamRef.v.Value end)
                    if ok and type(cur) == "number" and cur < stamRef.max - 0.01 then
                        pcall(function() stamRef.v.Value = stamRef.max end)
                    end
                end
            end)
        end
        task.wait(0.2)
    end
end)

-- ================= Mutant ESP =================
-- Красный хайлайт + метка (дистанция и HP) через стены.
-- Постоянный скан workspace раз в 1с + события
-- DescendantAdded/Removing на спавн и десавн мутанта.
G.RM_MutantESP = G.RM_MutantESP or false
G.RM_MutantColor = G.RM_MutantColor or Color3.fromRGB(255, 40, 40)

local mutantCache = {} -- array {model, hl, gui, lbl}
local inCache = {}     -- model -> true

local function isMutantModel(m)
    return typeof(m) == "Instance" and m:IsA("Model")
        and string.find(string.lower(m.Name), "mutant", 1, true) ~= nil
end

local function addMutant(m)
    if inCache[m] or not m.Parent then return end
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    inCache[m] = true

    local hl = Instance.new("Highlight")
    hl.Name = "RM_MutantHL"
    hl.FillColor = G.RM_MutantColor
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.55
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = m
    hl.Parent = pg

    local gui = Instance.new("BillboardGui")
    gui.Name = "RM_MutantLabel"
    gui.Size = UDim2.fromOffset(220, 34)
    gui.AlwaysOnTop = true
    gui.MaxDistance = 1000000
    gui.Parent = pg

    local lbl = Instance.new("TextLabel")
    lbl.Name = "Text"
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextColor3 = G.RM_MutantColor
    lbl.TextStrokeTransparency = 0
    lbl.TextSize = 14
    lbl.Text = "MUTANT"
    lbl.Parent = gui

    mutantCache[#mutantCache + 1] = {model = m, hl = hl, gui = gui, lbl = lbl}
end

local function removeMutant(m)
    if not inCache[m] then return end
    inCache[m] = nil
    for i = #mutantCache, 1, -1 do
        local e = mutantCache[i]
        if e.model == m then
            pcall(function() e.hl:Destroy() end)
            pcall(function() e.gui:Destroy() end)
            table.remove(mutantCache, i)
        end
    end
end

-- первичный поиск
pcall(function()
    for _, d in ipairs(workspace:GetDescendants()) do
        if isMutantModel(d) then addMutant(d) end
    end
end)
-- спавн/десавн — события для быстрой реакции
workspace.DescendantAdded:Connect(function(obj)
    if isMutantModel(obj) then addMutant(obj) end
end)
workspace.DescendantRemoving:Connect(function(obj)
    if inCache[obj] then removeMutant(obj) end
end)
-- ПОСТОЯННЫЙ скан: ловит переименования и спавны, которые
-- события не покрывают (модель появилась под другим именем
-- и была переименована в Mutant). Раз в секунду.
task.spawn(function()
    while true do
        pcall(function()
            for _, d in ipairs(workspace:GetDescendants()) do
                if isMutantModel(d) then addMutant(d) end
            end
        end)
        task.wait(1)
    end
end)

RunService.RenderStepped:Connect(function()
    pcall(function()
        local on = G.RM_MutantESP
        local lpch = LP.Character
        local myHRP = lpch and lpch:FindFirstChild("HumanoidRootPart")
        for i = #mutantCache, 1, -1 do
            local e = mutantCache[i]
            local m = e.model
            if not m or not m.Parent or not isMutantModel(m) then
                -- удалена или переименована — убираем метку и хайлайт
                pcall(function() e.hl:Destroy() end)
                pcall(function() e.gui:Destroy() end)
                if m then inCache[m] = nil end
                table.remove(mutantCache, i)
            else
                local show = false
                if on and myHRP then
                    local root = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Head")
                    if root then
                        local dist = (root.Position - myHRP.Position).Magnitude
                        local hum = m:FindFirstChildOfClass("Humanoid")
                        local hp = (hum and hum.Health > 0) and math.floor(hum.Health) or "?"
                        e.lbl.Text = ("MUTANT [%dm] HP %s"):format(math.floor(dist), tostring(hp))
                        e.gui.Adornee = root
                        show = true
                    end
                end
                e.hl.Enabled = show
                e.gui.Enabled = show
            end
        end
    end)
end)

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

-- ================= защита GUI от ESC =================
-- Игра при ESC выключает/удаляет чужие ScreenGuis в PlayerGui и не
-- возвращает их. Переносим окно в CoreGui, держим DisplayOrder 100000
-- и каждые 0.2с: включаем обратно выключенное, пересоздаём/ищем
-- удалённое.
local CoreGui = game:GetService("CoreGui")
local eliteGui = nil
local eliteWasFound = false
local eliteLostNotified = false

local function findEliteGui()
    pcall(function()
        eliteGui = nil
        -- сначала по имени Rayfield (если видно), потом по структуре Main > Topbar
        for _, container in ipairs({CoreGui, LP:FindFirstChildOfClass("PlayerGui")}) do
            if container then
                for _, g in ipairs(container:GetChildren()) do
                    if g:IsA("ScreenGui") and string.find(string.lower(g.Name), "rayfield", 1, true) then
                        eliteGui = g
                        break
                    end
                end
                if not eliteGui then
                    for _, g in ipairs(container:GetChildren()) do
                        if g:IsA("ScreenGui") then
                            local m = g:FindFirstChild("Main", true)
                            if m and m:FindFirstChild("Topbar") then
                                eliteGui = g
                                break
                            end
                        end
                    end
                end
            end
            if eliteGui then break end
        end
    end)
end

findEliteGui()
if eliteGui then
    eliteWasFound = true
    pcall(function()
        eliteGui.Parent = CoreGui
        eliteGui.DisplayOrder = 100000
        eliteGui.ResetOnSpawn = false
    end)
else
    print("[RM] Окно Rayfield не найдено — ESC-защита для него не применяется")
end

task.spawn(function()
    while true do
        pcall(function()
            -- плашка стамины: живая? иначе пересоздаём
            ensureStatusGui()
            if stamStatusGui and stamStatusGui.Parent then
                if stamStatusGui.DisplayOrder < 100000 then
                    stamStatusGui.DisplayOrder = 100000
                end
                if not stamStatusGui.Enabled then
                    stamStatusGui.Enabled = true
                end
            end
            -- окно Rayfield
            if not eliteGui or not eliteGui.Parent then
                eliteGui = nil
                findEliteGui()
                if eliteGui then
                    pcall(function() eliteGui.Parent = CoreGui end)
                elseif eliteWasFound and not eliteLostNotified then
                    eliteLostNotified = true
                    print("[RM] Окно Rayfield удалили — перезапусти скрипт")
                end
            end
            if eliteGui and eliteGui.Parent then
                if eliteGui.DisplayOrder < 100000 then
                    eliteGui.DisplayOrder = 100000
                end
                if not eliteGui.Enabled then
                    eliteGui.Enabled = true
                end
                if eliteGui.Parent ~= CoreGui then
                    pcall(function() eliteGui.Parent = CoreGui end)
                end
            end
        end)
        task.wait(0.2)
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

-- ===== Speed через TP walk (WalkSpeed не трогаем) =====
-- без флага: не сохраняется в конфиг, всегда стартует выключенным
Main:CreateToggle({
    Name = "Speed (TP walk)",
    CurrentValue = false,
    Callback = function(v)
        G.RM_TPSpeed = v
        if v then
            notify("TP speed ON — WASD = бег, Shift = x1.6. Сервер видит телепорты", 5)
        else
            notify("TP speed OFF", 2)
        end
    end,
})

Main:CreateSlider({
    Name = "TP speed",
    Range = {10, 300},
    Increment = 5,
    Suffix = " st/s",
    CurrentValue = G.RM_TPSpeedVal,
    Callback = function(v)
        G.RM_TPSpeedVal = v
    end,
})

Main:CreateLabel("Speed (TP walk): сервер видит телепорты, не скорость — но и телепорты могут палиться")

-- ===== Infinite stamina (автопоиск) =====
-- без флага: не сохраняется в конфиг, всегда стартует выключенным
Main:CreateToggle({
    Name = "Infinite stamina",
    CurrentValue = false,
    Callback = function(v)
        G.RM_StaminaLock = v
        pcall(function() stamStatus.Visible = v end)
        if v then
            print("[RM] Бесконечная стамина: ВКЛ")
            notify("Stamina ON — побегай 2-3 секунды, скрипт зафиксирует значение", 5)
        else
            print("[RM] Бесконечная стамина: ВЫКЛ")
            notify("Stamina OFF", 2)
        end
    end,
})

-- ===== Mutant ESP =====
Main:CreateToggle({
    Name = "Mutant ESP",
    CurrentValue = G.RM_MutantESP,
    Flag = "RM_MutantESP",
    Callback = function(v)
        G.RM_MutantESP = v
        notify("Mutant ESP: " .. (v and "ON" or "OFF"), 2)
    end,
})

Main:CreateColorPicker({
    Name = "Mutant ESP color",
    Color = G.RM_MutantColor,
    Flag = "RM_MutantColor",
    Callback = function(v)
        G.RM_MutantColor = v
        for _, e in ipairs(mutantCache) do
            pcall(function()
                e.hl.FillColor = v
                e.lbl.TextColor3 = v
            end)
        end
    end,
})

Main:CreateLabel("Mutant ESP: хайлайт и метка HP видны сквозь стены")

-- ================= вкладка Settings (кастомизация темы) =================
local SettingsTab = Window:CreateTab("Settings", 4483362458)

-- снимок дефолтной темы — для кнопки сброса
local DEFAULT_THEME = {}
for k, v in pairs(getgenv().RM_Theme) do
    DEFAULT_THEME[k] = v
end

local function changeThemeNow()
    pcall(function()
        if type(Rayfield.ChangeTheme) == "function" then
            Rayfield:ChangeTheme(getgenv().RM_Theme)
        end
    end)
end

-- перекрасить градиент на шапке (нарисован заранее, тема сама его не трогает)
local function recolorGradient(c)
    pcall(function()
        if not eliteGui or not eliteGui.Parent then return end
        local topbar = eliteGui:FindFirstChild("Topbar", true)
        if not topbar then return end
        for _, g in ipairs(topbar:GetDescendants()) do
            if g:IsA("UIGradient") and g.Name == "EliteGradient" then
                g.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, c),
                    ColorSequenceKeypoint.new(0.5, c:Lerp(Color3.new(0, 0, 0), 0.35)),
                    ColorSequenceKeypoint.new(1, c:Lerp(Color3.new(0, 0, 0), 0.7)),
                })
            end
        end
    end)
end

local function setThemeKeys(map)
    local t = getgenv().RM_Theme
    for k, v in pairs(map) do
        t[k] = v
    end
    changeThemeNow()
end

SettingsTab:CreateLabel("— Кастомизация темы ELITE HUB —")

SettingsTab:CreateColorPicker({
    Name = "Акцент",
    Color = getgenv().RM_Theme.TabBackgroundSelected,
    Flag = "RM_ThemeAccent",
    Callback = function(c)
        setThemeKeys({
            Accent = c,
            TabBackgroundSelected = c,
            ToggleEnabled = c,
            SliderProgress = c,
            SliderStroke = c:Lerp(Color3.new(1, 1, 1), 0.2),
            ToggleEnabledStroke = c:Lerp(Color3.new(1, 1, 1), 0.3),
            ToggleEnabledOuterStroke = c:Lerp(Color3.new(0, 0, 0), 0.3),
            NotificationActionsBackground = c:Lerp(Color3.new(1, 1, 1), 0.35),
            DropdownSelected = c:Lerp(Color3.new(0, 0, 0), 0.5),
        })
        recolorGradient(c)
    end,
})

SettingsTab:CreateColorPicker({
    Name = "Фон окна",
    Color = getgenv().RM_Theme.Background,
    Flag = "RM_ThemeBg",
    Callback = function(c)
        setThemeKeys({
            Background = c,
            Topbar = c:Lerp(Color3.new(1, 1, 1), 0.07),
            Shadow = c:Lerp(Color3.new(0, 0, 0), 0.5),
            ElementBackground = c:Lerp(Color3.new(1, 1, 1), 0.06),
            ElementBackgroundHover = c:Lerp(Color3.new(1, 1, 1), 0.16),
            SecondaryElementBackground = c:Lerp(Color3.new(0, 0, 0), 0.2),
            InputBackground = c:Lerp(Color3.new(0, 0, 0), 0.1),
            NotificationBackground = c:Lerp(Color3.new(1, 1, 1), 0.05),
            TabBackground = c:Lerp(Color3.new(1, 1, 1), 0.12),
            DropdownUnselected = c:Lerp(Color3.new(0, 0, 0), 0.05),
        })
    end,
})

SettingsTab:CreateColorPicker({
    Name = "Текст",
    Color = getgenv().RM_Theme.TextColor,
    Flag = "RM_ThemeText",
    Callback = function(c)
        setThemeKeys({
            TextColor = c,
            TabTextColor = c:Lerp(Color3.new(0, 0, 0), 0.25),
            SelectedTabTextColor = c,
        })
    end,
})

pcall(function()
    SettingsTab:CreateButton({
        Name = "Сбросить тему (ELITE)",
        Callback = function()
            for k, v in pairs(DEFAULT_THEME) do
                getgenv().RM_Theme[k] = v
            end
            changeThemeNow()
            recolorGradient(Color3.fromRGB(150, 90, 235))
            notify("Тема сброшена", 2)
        end,
    })
end)

SettingsTab:CreateLabel("Окно перетаскивается за шапку. Тема сохраняется в конфиге.")

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

print("[RESIDENCE MASSACRE] v3.9 rayfield loaded | Settings: кастомизация темы | без рывка вверх при TP Speed | GUI в CoreGui (ESC)")