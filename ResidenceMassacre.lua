-- ============================================================
--  ELITE HUB | Residence Massacre (Fullbright + TP Speed +
--  Stamina + ESP + автозабор)
--  GUI на библиотеке Rayfield (как в Fort Blox): Main / ESP / Settings.
--  Свет каждый кадр без мерцания, камера 1-е/3-е лицо,
--  ESP игроков/монстров/мутантов/предметов + автозабор предметов
--  (тепелерт рядом → клик → обратно, сервер видит «стоял рядом»).
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
G.RM_FB = G.RM_FB ~= nil and G.RM_FB or true          -- fullbright (+ всегда без тумана)
G.RM_Bright = G.RM_Bright or 3                        -- яркость 0..10
G.RM_TPSpeed = false                                  -- TP walk (ВЫКЛ по умолчанию)
G.RM_TPSpeedVal = G.RM_TPSpeedVal or 50               -- скорость телепорта, studs/s
G.RM_StaminaLock = false                              -- infinite stamina (ВЫКЛ по умолчанию)
G.RM_CamMode = G.RM_CamMode or "game"                 -- камера: game / first / third
G.RM_ActionDelay = G.RM_ActionDelay or 3               -- задержка действий, с (кулдауны)
local pickupBusy = false                              -- идёт автозабор (TP walk ждёт)

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
        -- туман и тени всегда убраны, пока fullbright включён
        -- (отдельной кнопки «No fog» больше нет)
        setProp(Lighting, "GlobalShadows", false)
        setProp(Lighting, "FogStart", -100000)
        setProp(Lighting, "FogEnd", 100000)
        setProp(Lighting, "FogColor", Color3.fromRGB(255, 255, 255))
    else
        restoreGroup(BRIGHT)
        restoreGroup(FOG)
    end
end

-- ================= камера: 1-е лицо / 3-е (сзади) =================
-- "game" — как в игре (трогаем один раз), "first"/"third" — держим
-- принудительно каждый кадр, перекрывая локи игры.
local CAM_ORIG = { mode = Enum.CameraMode.Classic, min = 0.5, max = 12.8 }
pcall(function()
    CAM_ORIG.mode = LP.CameraMode
    CAM_ORIG.min = LP.CameraMinZoomDistance
    CAM_ORIG.max = LP.CameraMaxZoomDistance
end)

local function camViewName()
    if G.RM_CamMode == "first" then return "1-е лицо" end
    if G.RM_CamMode == "third" then return "3-е (сзади)" end
    return "Как в игре"
end

local function applyCam()
    pcall(function()
        if G.RM_CamMode == "first" then
            setProp(LP, "CameraMode", Enum.CameraMode.LockFirstPerson)
        elseif G.RM_CamMode == "third" then
            setProp(LP, "CameraMode", Enum.CameraMode.Classic)
            setProp(LP, "CameraMinZoomDistance", 6)
            setProp(LP, "CameraMaxZoomDistance", 15)
        else
            setProp(LP, "CameraMode", CAM_ORIG.mode)
            setProp(LP, "CameraMinZoomDistance", CAM_ORIG.min)
            setProp(LP, "CameraMaxZoomDistance", CAM_ORIG.max)
        end
    end)
end
pcall(applyCam)

-- Свет и камера перепроверяются на КАЖДОМ кадре (запись — только если
-- что-то реально изменилось). Раньше опрос раз в секунду давал
-- мерцание: игра успевала вернуть темноту между опросами.
RunService.RenderStepped:Connect(function()
    if G.RM_FB then pcall(applyLight) end
    if G.RM_CamMode ~= "game" then pcall(applyCam) end
end)

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
    if not G.RM_TPSpeed or pickupBusy then return end
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
        local stepVec = camFwd * z * step + camRight * x * step

        -- Не проходим сквозь стены/предметы при спиде: рейкаст по
        -- направлению движения от корпуса и от колена. Низкие объекты
        -- (ступеньки/мусор до 1.5 студ) не блокируем — земной снап их
        -- и так перешагивает; всё выше — останавливаемся перед ним.
        local stepLen = stepVec.Magnitude
        if stepLen > 0 then
            local rdir = stepVec.Unit
            local params = RaycastParams.new()
            params.FilterDescendantsInstances = {ch}
            params.IgnoreWater = true
            local feetY = hrp.Position.Y - (standOffset or 2)
            local allow = stepLen
            local origins = {
                hrp.Position,
                Vector3.new(hrp.Position.X, feetY + 0.7, hrp.Position.Z),
            }
            for _, o in ipairs(origins) do
                local h = workspace:Raycast(o, rdir * (stepLen + 0.4), params)
                if h and not h.Instance:IsA("Terrain") then
                    local topY = h.Position.Y
                    pcall(function()
                        if h.Instance:IsA("BasePart") then
                            local cf, sz = h.Instance:GetBoundingBox()
                            topY = cf.Position.Y + sz.Y / 2
                        end
                    end)
                    if topY > feetY + 1.5 then
                        local d = (h.Position - o).Magnitude - 0.4
                        if d < allow then allow = math.max(d, 0) end
                    end
                end
            end
            if allow < stepLen then
                stepVec = rdir * allow
            end
        end
        local np = hrp.Position + stepVec

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
-- Общий контейнер ESP: ScreenGui в CoreGui — ESC/очистка PlayerGui
-- его не трогают, watchdog пересоздаёт при удалении.
local ESPScreen = nil
local function ensureESPScreen()
    pcall(function()
        if ESPScreen and ESPScreen.Parent then
            if not ESPScreen.Enabled then ESPScreen.Enabled = true end
            return
        end
        local sg = Instance.new("ScreenGui")
        sg.Name = "RM_ESP"
        sg.ResetOnSpawn = false
        sg.DisplayOrder = 100000
        sg.Parent = game:GetService("CoreGui")
        ESPScreen = sg
    end)
end
ensureESPScreen()
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
    ensureESPScreen()
    local pg = ESPScreen
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
            if not e.hl.Parent or not e.gui.Parent then
                -- хайлайт/метку удалили — убираем из кэша,
                -- постоянный скан пересоздаст их сам
                if m then inCache[m] = nil end
                table.remove(mutantCache, i)
            elseif not m or not m.Parent or not isMutantModel(m) then
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

-- ================= ESP: игроки / монстры / предметы =================
-- Второй движок (мутанты ведутся отдельной секцией выше):
-- Highlight + метка через стены, всё лежит в CoreGui.
-- Скан workspace раз в 1с + события спавна/десавна.
-- Предметы ItemSpots: ESP + автозабор (тепелерт → взять → вернуться).
G.RM_PlayerESP = G.RM_PlayerESP or false
G.RM_PlayerColor = G.RM_PlayerColor or Color3.fromRGB(80, 255, 120)
G.RM_MonsterESP = G.RM_MonsterESP or false
G.RM_MonsterColor = G.RM_MonsterColor or Color3.fromRGB(255, 140, 0)
G.RM_ItemESP = G.RM_ItemESP or false
G.RM_ItemColor = G.RM_ItemColor or Color3.fromRGB(255, 220, 60)
G.RM_AutoPickup = false -- без флага: всегда стартует выключенным
G.RM_PickList = G.RM_PickList or {"Все"} -- что забирать (сохраняется)

local espCache = {} -- array {inst, kind, hl, gui, lbl, ...}
local espBy = {} -- Instance -> entry
local pickDD = nil -- выпадашка «Что забирать» (заполняется при создании GUI)

local function kindColor(kind)
    if kind == "player" then return G.RM_PlayerColor end
    if kind == "monster" then return G.RM_MonsterColor end
    return G.RM_ItemColor
end

local function kindOn(kind)
    if kind == "player" then return G.RM_PlayerESP == true end
    if kind == "monster" then return G.RM_MonsterESP == true end
    return G.RM_ItemESP == true
end

-- модель = игрок / монстр / ничего.
-- Мутанты пропускаются — их ведёт отдельная секция выше.
local function modelKind(m)
    if not m:IsA("Model") or not m.Parent then return nil end
    local plr = Players:GetPlayerFromCharacter(m)
    if plr then
        if plr == LP then return nil end
        return "player"
    end
    if not m:FindFirstChildOfClass("Humanoid") then return nil end
    if string.find(string.lower(m.Name), "mutant", 1, true) then return nil end
    return "monster"
end

local function espAdd(inst, kind)
    if not inst or espBy[inst] then return end
    ensureESPScreen()
    local container = ESPScreen
    if not container then return end
    local hl = Instance.new("Highlight")
    hl.Name = "RM_ESP_HL"
    hl.FillColor = kindColor(kind)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = (kind == "item") and 0.75 or 0.55
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = inst
    hl.Parent = container

    local gui = Instance.new("BillboardGui")
    gui.Name = "RM_ESP_LBL"
    gui.Size = (kind == "item") and UDim2.fromOffset(180, 22) or UDim2.fromOffset(220, 34)
    gui.AlwaysOnTop = true
    gui.MaxDistance = 1000000
    gui.Adornee = inst
    gui.Parent = container

    local lbl = Instance.new("TextLabel")
    lbl.Name = "Text"
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextColor3 = kindColor(kind)
    lbl.TextStrokeTransparency = 0
    lbl.TextSize = (kind == "item") and 12 or 14
    lbl.Text = ""
    lbl.Parent = gui

    local e = {inst = inst, kind = kind, hl = hl, gui = gui, lbl = lbl}
    espCache[#espCache + 1] = e
    espBy[inst] = e
end

local function espRemove(inst)
    local e = espBy[inst]
    if not e then return end
    espBy[inst] = nil
    pcall(function() e.hl:Destroy() end)
    pcall(function() e.gui:Destroy() end)
    for i = #espCache, 1, -1 do
        if espCache[i] == e then
            table.remove(espCache, i)
        end
    end
end

-- ===== предметы / интерактив =====
-- Не привязываемся к структуре папок: предмет = ЛЮБОЙ ClickDetector
-- или ProximityPrompt в workspace (ItemSpots/BloxyCola, Food, JerryCan,
-- Generator...). Владелец = модель-контейнер или ближайший предок-модель.
local itemNames = {} -- lowername -> имя для выпадашки

local GENERIC_NAMES = {
    spot = true, part = true, model = true, main = true,
    handle = true, block = true, item = true,
}

-- имя для метки/выпадашки: у обезличенного контейнера ("Spot"/"Part")
-- берём имя вложенной модели предмета (BloxyCola/Food/...)
local function displayName(owner)
    if not owner:IsA("Model") then return owner.Name end
    if not GENERIC_NAMES[string.lower(owner.Name)] then return owner.Name end
    for _, ch in ipairs(owner:GetChildren()) do
        if ch:IsA("Model") and ch:FindFirstChild("Handle", true) then
            return ch.Name
        end
    end
    return owner.Name
end

-- кому принадлежит взаимодействие: сама модель или предок-модель.
-- персонажи игроков и NPC пропускаем — у них свои типы ESP.
local function interactOwner(obj)
    local par = obj.Parent
    if not par then return nil end
    local m = par
    if not par:IsA("Model") then
        m = par:FindFirstAncestorOfClass("Model")
    end
    if not m then return par end
    if Players:GetPlayerFromCharacter(m) then return nil end
    if m:FindFirstChildOfClass("Humanoid") then return nil end
    return m
end

local function pickOptions()
    local opts = {"Все"}
    local names = {}
    for _, n in pairs(itemNames) do
        names[#names + 1] = n
    end
    table.sort(names, function(a, b)
        return string.lower(a) < string.lower(b)
    end)
    for _, n in ipairs(names) do
        opts[#opts + 1] = n
    end
    return opts
end

local function scanItems()
    local seen = {}
    local interact = {} -- owner -> {cd=, prompt=}
    local newName = false
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ClickDetector") or d:IsA("ProximityPrompt") then
            local owner = interactOwner(d)
            if owner and owner.Parent then
                seen[owner] = true
                local it = interact[owner]
                if not it then
                    it = {}
                    interact[owner] = it
                end
                if d:IsA("ClickDetector") then
                    it.cd = d
                else
                    it.prompt = d
                end
            end
        end
    end
    -- зарегистрировать/обновить найденные предметы
    for owner, it in pairs(interact) do
        local nm = displayName(owner)
        local key = string.lower(nm)
        if not itemNames[key] then
            itemNames[key] = nm
            newName = true
        end
        if not espBy[owner] then espAdd(owner, "item") end
        local e = espBy[owner]
        if e then
            e.itemName = nm
            e.cd = it.cd
            e.prompt = it.prompt
        end
    end
    -- предмет исчез (забрали / респавн) — убираем метку
    local gone = {}
    for inst, e in pairs(espBy) do
        if e.kind == "item" and not seen[inst] then
            gone[#gone + 1] = inst
        end
    end
    for _, inst in ipairs(gone) do
        espRemove(inst)
    end
    -- в выпадашке появились новые имена предметов
    if newName and pickDD and type(pickDD.Refresh) == "function" then
        pcall(function() pickDD:Refresh(pickOptions()) end)
    end
end

local function scanEsp()
    -- игроки — напрямую из Players
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local c = plr.Character
            if not espBy[c] then espAdd(c, "player") end
        end
    end
    -- монстры: Model + Humanoid без владельца-игрока
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Model") and d.Parent then
            local k = modelKind(d)
            if k and not espBy[d] then
                espAdd(d, k)
            end
        end
    end
    -- удалённые / переименованные (не предметы — их ведёт scanItems)
    local gone = {}
    for inst, e in pairs(espBy) do
        if e.kind ~= "item" then
            if not inst.Parent or modelKind(inst) ~= e.kind then
                gone[#gone + 1] = inst
            end
        end
    end
    for _, inst in ipairs(gone) do
        espRemove(inst)
    end
    scanItems()
end

-- спавн/десавн — быстрая реакция (без ожидания секундного скана)
workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("Model") then
        local k = modelKind(obj)
        if k and not espBy[obj] then espAdd(obj, k) end
    end
    -- появился ClickDetector/Prompt (предмет/канистра/генератор) —
    -- сразу ресканим предметы, не ждём секундного скана
    if obj:IsA("ClickDetector") or obj:IsA("ProximityPrompt") then
        task.defer(function() pcall(scanItems) end)
    end
end)
workspace.DescendantRemoving:Connect(function(obj)
    if espBy[obj] then espRemove(obj) end
end)

pcall(scanEsp)
task.spawn(function()
    while true do
        pcall(scanEsp)
        task.wait(1)
    end
end)

-- ===== автозабор: телепорт рядом → клик → обратно =====
local fireWarned = false

local function fireItem(e)
    local fired = false
    if e.prompt then
        pcall(function() e.prompt.HoldDuration = 0 end)
        if typeof(fireproximityprompt) == "function" then
            pcall(function() fireproximityprompt(e.prompt) end)
            fired = true
        end
    end
    if e.cd and typeof(fireclickdetector) == "function" then
        pcall(function() fireclickdetector(e.cd) end)
        fired = true
    end
    if not fired and (e.prompt or e.cd) and not fireWarned then
        fireWarned = true
        print("[RM] В экзекуторе нет fireproximityprompt/fireclickdetector — автозабор не сможет кликать предметы")
    end
    return fired
end

local function itemPos(e)
    local ok, pos = pcall(function() return e.inst:GetPivot().Position end)
    if ok and typeof(pos) == "Vector3" then return pos end
    return nil
end

local function pickSelected(name)
    if not name then return false end
    local sel = G.RM_PickList
    if typeof(sel) == "string" then sel = {sel} end
    if not sel or #sel == 0 then return false end
    local ln = string.lower(name)
    for _, s in ipairs(sel) do
        local ls = string.lower(tostring(s))
        if ls == "все" or ls == "all" then return true end
        if ls == ln then return true end
    end
    return false
end

local function doPickup(e)
    if pickupBusy then return end
    local ch = LP.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp.Parent then return end
    local pos = itemPos(e)
    if not pos then return end

    -- радиус активации: самый жёсткий из найденных взаимодействий
    local maxD = 32
    if e.prompt then maxD = math.min(maxD, e.prompt.MaxActivationDistance or 10) end
    if e.cd then maxD = math.min(maxD, e.cd.MaxActivationDistance or 32) end
    if not e.prompt and not e.cd then maxD = 10 end -- только Remote — держимся ближе

    local dist = (pos - hrp.Position).Magnitude
    pickupBusy = true
    local teleported = false
    local origin = hrp.CFrame
    pcall(function()
        if dist > math.max(maxD - 3, 2) then
            -- телепорт рядом с предметом: для сервера — «игрок стоял рядом»
            hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
                * (hrp.CFrame - hrp.CFrame.Position)
            teleported = true
        end
    end)
    if teleported then task.wait(0.15) end -- позиция успевает дойти до сервера
    pcall(function() fireItem(e) end)
    e.clickAt = os.clock() -- кулдаун по каждой цели — из слайдера «Скорость действий»
    if teleported then
        task.wait(0.1)
        pcall(function() hrp.CFrame = origin end)
    end
    task.wait(0.15)
    pickupBusy = false
end

-- раз в 0.4с берём ближайший подходящий предмет из списка
task.spawn(function()
    while true do
        pcall(function()
            if G.RM_AutoPickup and not pickupBusy then
                local ch = LP.Character
                local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local best, bestD = nil, math.huge
                    for _, e in ipairs(espCache) do
                        if e.kind == "item" and e.inst.Parent
                            and (e.prompt or e.cd)
                            -- генератор не трогаем — им занимается Auto fuel
                            and not string.find(string.lower(e.itemName or e.inst.Name),
                                "generator", 1, true)
                            and (not e.clickAt or os.clock() - e.clickAt
                                >= (tonumber(G.RM_ActionDelay) or 3))
                            and pickSelected(e.itemName) then
                            local pos = itemPos(e)
                            if pos then
                                local d = (pos - hrp.Position).Magnitude
                                if d < bestD then
                                    best, bestD = e, d
                                end
                            end
                        end
                    end
                    if best then doPickup(best) end
                end
            end
        end)
        task.wait(0.4)
    end
end)

-- ===== авто-топливо: JerryCan → Generator =====
-- Схема: телепорт к канистре → взять (кулдаун ~3с стоим рядом) →
-- телепорт к генератору → подать топливо (кулдаун ~3с) → обратно.
-- Для сервера мы всё время стоим рядом с тем, что жмём.
G.RM_AutoFuel = false -- без флага: всегда стартует выключенным
local lastCanAt = 0
local fuelWarned = false

-- ищем модель по части имени (generator / jerrycan) с её ClickDetector
local function findByModelName(sub)
    local low = string.lower(sub)
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Model") and string.find(string.lower(d.Name), low, 1, true) then
            local cd = d:FindFirstChildWhichIsA("ClickDetector", true)
            if cd then
                return d, cd
            end
        end
    end
    return nil, nil
end

-- встать рядом с целью (если далеко) и нажать её
local function fuelPress(hrp, pos, cd)
    local maxD = cd.MaxActivationDistance or 32
    local dist = (pos - hrp.Position).Magnitude
    if dist > math.max(maxD - 3, 2) then
        pcall(function()
            hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
                * (hrp.CFrame - hrp.CFrame.Position)
        end)
        task.wait(0.15) -- позиция успевает дойти до сервера
    end
    if typeof(fireclickdetector) == "function" then
        pcall(function() fireclickdetector(cd) end)
        return true
    end
    if not fuelWarned then
        fuelWarned = true
        print("[RM] В экзекуторе нет fireclickdetector — авто-заправка не сможет нажимать")
    end
    return false
end

task.spawn(function()
    while true do
        pcall(function()
            if G.RM_AutoFuel and not pickupBusy then
                local ch = LP.Character
                local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local can, cdCan = findByModelName("jerrycan")
                    local gen, cdGen = findByModelName("generator")
                    -- канистра у нас в руках (модель внутри персонажа)
                    local held = can and ch and can:IsDescendantOf(ch)
                    local tookRecently = (os.clock() - lastCanAt) < 15
                    -- брать канистру есть смысл только при наличии генератора
                    local wantCan = (cdCan ~= nil) and (not held) and (cdGen ~= nil)
                    local wantGen = (cdGen ~= nil) and (held or tookRecently)
                    if wantCan or wantGen then
                        pickupBusy = true
                        local origin = hrp.CFrame
                        local pressedCan = false
                        if wantCan then
                            pressedCan = fuelPress(hrp, can:GetPivot().Position, cdCan)
                            if pressedCan then lastCanAt = os.clock() end
                            task.wait(tonumber(G.RM_ActionDelay) or 3) -- кулдаун канистры
                        end
                        local canReady = pressedCan or held
                            or ((os.clock() - lastCanAt) < 15)
                        if G.RM_AutoFuel and cdGen and canReady then
                            fuelPress(hrp, gen:GetPivot().Position, cdGen)
                            task.wait(tonumber(G.RM_ActionDelay) or 3) -- кулдаун подачи топлива
                        end
                        pcall(function() hrp.CFrame = origin end)
                        pickupBusy = false
                    end
                end
            end
        end)
        task.wait(0.5)
    end
end)

-- ===== аимбот на монстра (камера, бинд) =====
-- Пока зажат бинд — камера доводится до ближайшего монстра/мутанта
-- в радиусе 200 студ. Только камера: выстрелов и урона нет.
G.RM_AimMonster = false -- без флага: всегда стартует выключенным
local AIM_RANGE = 200

local function aimTarget()
    local ch = LP.Character
    local myPos = ch and ch:FindFirstChild("HumanoidRootPart")
        and ch.HumanoidRootPart.Position
    if not myPos then return nil end
    local best, bestD = nil, AIM_RANGE
    local function consider(model)
        if not model or not model.Parent then return end
        local root = model:FindFirstChild("HumanoidRootPart", true)
            or model:FindFirstChild("Head", true)
        if root then
            local d = (root.Position - myPos).Magnitude
            if d < bestD then best, bestD = root, d end
        end
    end
    for _, e in ipairs(espCache) do
        if e.kind == "monster" then consider(e.inst) end
    end
    for _, e in ipairs(mutantCache) do
        consider(e.model)
    end
    return best
end

pcall(function() RunService:UnbindFromRenderStep("RMAimMonster") end)
RunService:BindToRenderStep("RMAimMonster", Enum.RenderPriority.Camera.Value + 1, function()
    -- приоритет выше Camera — перекрываем штатную камеру после её апдейта
    if not G.RM_AimMonster then return end
    pcall(function()
        local cam = workspace.CurrentCamera
        local target = aimTarget()
        if cam and target then
            cam.CFrame = CFrame.lookAt(cam.CFrame.Position, target.Position)
        end
    end)
end)

-- ===== рендер меток/хайлайтов каждый кадр =====
RunService.RenderStepped:Connect(function()
    pcall(function()
        local ch = LP.Character
        local myHRP = ch and ch:FindFirstChild("HumanoidRootPart")
        for i = #espCache, 1, -1 do
            local e = espCache[i]
            local inst = e.inst
            if not inst or not inst.Parent or not e.hl.Parent then
                -- инстанс или сам хайлайт удалили — чистим
                if inst then espBy[inst] = nil end
                pcall(function() e.hl:Destroy() end)
                pcall(function() e.gui:Destroy() end)
                table.remove(espCache, i)
            else
                local show = false
                local pos = nil
                if e.kind == "item" then
                    local ok, piv = pcall(function() return inst:GetPivot().Position end)
                    if ok then pos = piv end
                else
                    local root = inst:FindFirstChild("HumanoidRootPart")
                        or inst:FindFirstChild("Head")
                    if root then pos = root.Position end
                end
                if kindOn(e.kind) and myHRP and pos then
                    local dist = (pos - myHRP.Position).Magnitude
                    local color = kindColor(e.kind)
                    if e.hl.FillColor ~= color then e.hl.FillColor = color end
                    if e.lbl.TextColor3 ~= color then e.lbl.TextColor3 = color end
                    if e.kind == "item" then
                        e.lbl.Text = ("%s [%dm]"):format(e.itemName or inst.Name, math.floor(dist))
                    else
                        local hum = inst:FindFirstChildOfClass("Humanoid")
                        local hp = (hum and hum.Health > 0) and math.floor(hum.Health) or "?"
                        e.lbl.Text = ("%s [%dm] HP %s"):format(inst.Name, math.floor(dist), tostring(hp))
                    end
                    show = true
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

-- ==== поиск окна Rayfield: CoreGui / gethui() / RobloxGui / PlayerGui ====
-- Rayfield сам может жить в gethui() или внутри RobloxGui —
-- обычный обход детей PlayerGui его не находит.
local CoreGuiSvc = game:GetService("CoreGui")
local eliteGui = nil
local eliteWasFound = false
local eliteLostNotified = false

local function guiIsRayfield(g)
    if not g:IsA("ScreenGui") then return false end
    if string.find(string.lower(g.Name), "rayfield", 1, true) then return true end
    local m = g:FindFirstChild("Main", true)
    return m ~= nil and m:FindFirstChild("Topbar") ~= nil
end

local function findEliteGui()
    local found = nil
    pcall(function()
        local containers = {CoreGuiSvc, LP:FindFirstChildOfClass("PlayerGui")}
        pcall(function()
            if type(gethui) == "function" then
                containers[#containers + 1] = gethui()
            end
        end)
        -- мелкий обход (дёшево)
        for _, c in ipairs(containers) do
            if c then
                for _, g in ipairs(c:GetChildren()) do
                    if guiIsRayfield(g) then
                        found = g
                        break
                    end
                end
            end
            if found then break end
        end
        -- глубокий: RobloxGui и папка gethui
        if not found then
            for _, c in ipairs(containers) do
                if c then
                    for _, g in ipairs(c:GetDescendants()) do
                        if guiIsRayfield(g) then
                            found = g
                            break
                        end
                    end
                end
                if found then break end
            end
        end
    end)
    eliteGui = found
end

findEliteGui()
if eliteGui then
    eliteWasFound = true
else
    print("[RM] Окно Rayfield не найдено — ESC-защита для него не применяется")
end

-- плавный фиолетовый градиент на шапке окна (только фон, без иконок/текста)
pcall(function()
    if not eliteGui then return end
    local m = eliteGui:FindFirstChild("Main", true)
    local topbar = m and m:FindFirstChild("Topbar")
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
-- Игра при ESC выключает/удаляет чужие ScreenGuis. Держим окно
-- в CoreGui с DisplayOrder 100000, включаем выключенное,
-- ищем заново удалённое.
local function ensureEliteProtection()
    if not eliteGui or not eliteGui.Parent then return end
    pcall(function()
        if eliteGui.DisplayOrder < 100000 then
            eliteGui.DisplayOrder = 100000
        end
        eliteGui.ResetOnSpawn = false
        if not eliteGui.Enabled then
            eliteGui.Enabled = true
        end
        if eliteGui.Parent ~= CoreGuiSvc then
            eliteGui.Parent = CoreGuiSvc
        end
    end)
end

ensureEliteProtection()

task.spawn(function()
    while true do
        pcall(function()
            -- контейнер ESP: жив? иначе пересоздаём
            ensureESPScreen()
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
                findEliteGui()
                if eliteGui then
                    eliteWasFound = true
                    pcall(ensureEliteProtection)
                elseif eliteWasFound and not eliteLostNotified then
                    eliteLostNotified = true
                    print("[RM] Окно Rayfield удалили — перезапусти скрипт")
                end
            else
                pcall(ensureEliteProtection)
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

-- ===== Speed через TP walk (WalkSpeed не трогаем) =====
-- без флага: не сохраняется в конфиг, всегда стартует выключенным
local speedToggle
speedToggle = Main:CreateToggle({
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

Main:CreateKeybind({
    Name = "Бинд TP speed",
    CurrentKeybind = "B",
    Flag = "RM_BindSpeed",
    Callback = function()
        speedToggle:Set(not G.RM_TPSpeed)
    end,
})

-- ===== Infinite stamina (автопоиск) =====
-- без флага: не сохраняется в конфиг, всегда стартует выключенным
local stamToggle
stamToggle = Main:CreateToggle({
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

Main:CreateKeybind({
    Name = "Бинд стамины",
    CurrentKeybind = "N",
    Flag = "RM_BindStam",
    Callback = function()
        stamToggle:Set(not G.RM_StaminaLock)
    end,
})

-- ================= вкладка ESP (весь ESP + автозабор) =================
local ESP = Window:CreateTab("ESP", 4483362458)

ESP:CreateSection("Игроки")
ESP:CreateToggle({
    Name = "Player ESP",
    CurrentValue = G.RM_PlayerESP,
    Flag = "RM_PlayerESP",
    Callback = function(v)
        G.RM_PlayerESP = v
        notify("Player ESP: " .. (v and "ON" or "OFF"), 2)
    end,
})
ESP:CreateColorPicker({
    Name = "Player ESP color",
    Color = G.RM_PlayerColor,
    Flag = "RM_PlayerColor",
    Callback = function(v)
        G.RM_PlayerColor = v
    end,
})

ESP:CreateSection("Монстры")
ESP:CreateToggle({
    Name = "Monster ESP",
    CurrentValue = G.RM_MonsterESP,
    Flag = "RM_MonsterESP",
    Callback = function(v)
        G.RM_MonsterESP = v
        notify("Monster ESP: " .. (v and "ON" or "OFF"), 2)
    end,
})
ESP:CreateColorPicker({
    Name = "Monster ESP color",
    Color = G.RM_MonsterColor,
    Flag = "RM_MonsterColor",
    Callback = function(v)
        G.RM_MonsterColor = v
    end,
})
ESP:CreateToggle({
    Name = "Mutant ESP",
    CurrentValue = G.RM_MutantESP,
    Flag = "RM_MutantESP",
    Callback = function(v)
        G.RM_MutantESP = v
        notify("Mutant ESP: " .. (v and "ON" or "OFF"), 2)
    end,
})
ESP:CreateColorPicker({
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
ESP:CreateLabel("Монстры: модель с Humanoid (не игрок); мутанты — по имени. Метка: имя, дистанция, HP.")

ESP:CreateSection("Предметы")
ESP:CreateToggle({
    Name = "Item ESP",
    CurrentValue = G.RM_ItemESP,
    Flag = "RM_ItemESP",
    Callback = function(v)
        G.RM_ItemESP = v
        notify("Item ESP: " .. (v and "ON" or "OFF"), 2)
    end,
})
ESP:CreateColorPicker({
    Name = "Item ESP color",
    Color = G.RM_ItemColor,
    Flag = "RM_ItemColor",
    Callback = function(v)
        G.RM_ItemColor = v
    end,
})

ESP:CreateSlider({
    Name = "Скорость действий",
    Range = {0.1, 5},
    Increment = 0.1,
    Suffix = " s",
    CurrentValue = G.RM_ActionDelay,
    Flag = "RM_ActionDelay",
    Callback = function(v)
        G.RM_ActionDelay = v
    end,
})
ESP:CreateLabel("Скорость действий: кулдауны автозабора и авто-заправки (0.1–5 с; меньше = быстрее, но игра даёт ~3с)")

ESP:CreateLabel("Автозабор: телепорт к предмету → взять → обратно. Для сервера — «стоял рядом и забрал».")
local pickToggle
pickToggle = ESP:CreateToggle({
    Name = "Auto pickup",
    CurrentValue = false,
    Callback = function(v)
        G.RM_AutoPickup = v
        notify("Auto pickup: " .. (v and "ON" or "OFF"), 2)
    end,
})
pickDD = ESP:CreateDropdown({
    Name = "Что забирать",
    Options = pickOptions(),
    CurrentOption = G.RM_PickList,
    MultipleOptions = true,
    Flag = "RM_PickList",
    Callback = function(opt)
        if typeof(opt) == "string" then opt = {opt} end
        G.RM_PickList = opt or {"Все"}
    end,
})
ESP:CreateLabel("Что забирать: можно выбрать несколько. «Все» = всё подряд.")

ESP:CreateKeybind({
    Name = "Бинд Auto pickup",
    CurrentKeybind = "H",
    Flag = "RM_BindPick",
    Callback = function()
        pickToggle:Set(not G.RM_AutoPickup)
    end,
})

ESP:CreateSection("Генератор")
ESP:CreateLabel("Автотопливо: телепорт к JerryCan → взять (3с) → к Generator → подать топливо (3с) → обратно")
local fuelToggle
fuelToggle = ESP:CreateToggle({
    Name = "Auto fuel",
    CurrentValue = false,
    Callback = function(v)
        G.RM_AutoFuel = v
        if v and typeof(fireclickdetector) ~= "function" then
            notify("Auto fuel: в экзекуторе нет fireclickdetector — нажимать нечем", 5)
        else
            notify("Auto fuel: " .. (v and "ON" or "OFF"), 2)
        end
    end,
})

ESP:CreateKeybind({
    Name = "Бинд Auto fuel",
    CurrentKeybind = "J",
    Flag = "RM_BindFuel",
    Callback = function()
        fuelToggle:Set(not G.RM_AutoFuel)
    end,
})

ESP:CreateSection("Аимбот")
ESP:CreateLabel("Аимбот на монстра: зажми бинд — камера наводится на ближайшего монстра/мутанта (до 200 м)")
ESP:CreateKeybind({
    Name = "Бинд аимбота (зажать)",
    CurrentKeybind = "C",
    HoldToInteract = true,
    Flag = "RM_BindAim",
    Callback = function(on)
        G.RM_AimMonster = (on == true)
    end,
})

-- ================= вкладка Settings (кастомизация темы) =================
local SettingsTab = Window:CreateTab("Settings", 4483362458)

-- снимок дефолтной темы — для кнопки сброса
local DEFAULT_THEME = {}
for k, v in pairs(getgenv().RM_Theme) do
    DEFAULT_THEME[k] = v
end

local themeToken = 0
local function changeThemeNow()
    -- палитру тянем мышью — применяем через 0.2с тишины,
    -- иначе ModifyTheme шлёт уведомление на каждый шажок пикера
    themeToken = themeToken + 1
    local mine = themeToken
    task.delay(0.2, function()
        if mine ~= themeToken then return end
        pcall(function()
            if type(Window.ModifyTheme) == "function" then
                Window.ModifyTheme(getgenv().RM_Theme)
            elseif type(Rayfield.ChangeTheme) == "function" then
                Rayfield:ChangeTheme(getgenv().RM_Theme)
            end
        end)
        -- элементы Rayfield перекрашиваются только при смене
        -- BackgroundColor3 у Main — дёргаем его принудительно
        pcall(function()
            if not eliteGui then return end
            local main = eliteGui:FindFirstChild("Main", true)
            if not main then return end
            local b = getgenv().RM_Theme.Background
            main.BackgroundColor3 = Color3.new(math.min(b.R + 0.01, 1), b.G, b.B)
            main.BackgroundColor3 = b
        end)
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

SettingsTab:CreateSection("Камера")
SettingsTab:CreateDropdown({
    Name = "Вид",
    Options = {"Как в игре", "1-е лицо", "3-е (сзади)"},
    CurrentOption = {camViewName()},
    Flag = "RM_CamView",
    Callback = function(opt)
        local v = (typeof(opt) == "table") and opt[1] or opt
        if v == "1-е лицо" then
            G.RM_CamMode = "first"
        elseif v == "3-е (сзади)" then
            G.RM_CamMode = "third"
        else
            G.RM_CamMode = "game"
        end
        applyCam()
        notify("Камера: " .. tostring(v), 2)
    end,
})
SettingsTab:CreateLabel("1-е лицо — всегда впереди; 3-е — камера позади; «Как в игре» не трогает камеру.")

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

print("[RESIDENCE MASSACRE] v4.2 rayfield loaded | бинды + аимбот на монстра + скорость действий + анти-клип при спиде | предметы/автозабор/Auto fuel | ESP | свет | камера 1/3 | Settings")