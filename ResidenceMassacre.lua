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

-- Проверка, что это Residence Massacre: GameId покрывает все плейсы игры
-- (лобби 14437001043, Ночь 1 14896802601, Ночь 2 16667550979 — из
-- script-sources/residence-massacre; бункер 100255403764514 — из
-- Bunker Helper V5, на случай отдельного юниверса). RM_GAME_ID = 0 и
-- пустой список = везде.
local RM_GAME_ID = 4987467534
local ONLY_PLACE_IDS = { 14437001043, 14896802601, 16667550979, 100255403764514 }

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

local rmCheck = (RM_GAME_ID ~= 0) or (#ONLY_PLACE_IDS > 0)
local rmOkGame = (RM_GAME_ID ~= 0 and game.GameId == RM_GAME_ID)
    or table.find(ONLY_PLACE_IDS, game.PlaceId) ~= nil
if rmCheck and not rmOkGame then
    warn("[RM] это не Residence Massacre (GameId " .. tostring(game.GameId)
        .. ", PlaceId " .. tostring(game.PlaceId) .. ") — выход")
    return
end

local G = getgenv()

-- Защита от повторного запуска в той же сессии: старый прогон
-- замолкает — все его циклы/кадровые подписки выходят по RUN_ID,
-- иначе два прогона дерутся (двойные телепорты, двойной ESP, окна).
getgenv().RM_Run = (getgenv().RM_Run or 0) + 1
local RUN_ID = getgenv().RM_Run
-- старые артефакты прошлого прогона (скрипт выполнили повторно):
-- экраны ESP/плашки + своё окно Rayfield в CoreGui. Чужие хабы в
-- gethui/PlayerGui не трогаем; чужой Rayfield в CoreGui узнаём по
-- signature — на ПЕРВОМ запуске (RM_Run == 1) его не трогаем,
-- иначе убивалось бы любое чужое окно этой библиотеки. На re-run
-- чистим: там обязано быть наше окно прошлого прогона.
-- 1) Старая БИБЛИОТЕКА Rayfield: у неё живут подписки InputBegan
-- (каждый бинд + прятка окна) — без Destroy() клавиша выполняла бы
-- И старый, и новый callback (двойное переключение флагов). Плюс её
-- task.delay(4, LoadConfiguration) мог не успеть отработать.
pcall(function()
    local oldLib = G.RM_RayfieldLib
    if oldLib and type(oldLib.Destroy) == "function" then
        oldLib:Destroy()
    end
end)
G.RM_RayfieldLib = nil
-- 2) Noclip переживал re-run молча: окно пересоздаётся «выкл»
-- (G.RM_Noclip = false), а коллизии остаются выключенными —
-- возвращаем по сохранённой таблице исходных значений
pcall(function()
    local saved = G.RM_NoclipSaved
    if type(saved) == "table" then
        for part, was in pairs(saved) do
            if part and part.Parent then part.CanCollide = was end
        end
    end
end)
G.RM_NoclipSaved = nil
-- 3) Disable Static: новый запуск всегда со стартовым OFF
G.RM_NoStatic = false
pcall(function()
    for _, g in ipairs(game:GetService("CoreGui"):GetChildren()) do
        if g:IsA("ScreenGui") then
            if g.Name == "RM_ESP" or g.Name == "RM_StaminaStatus" then
                g:Destroy()
            else
                local isRF = string.find(string.lower(g.Name),
                    "rayfield", 1, true) ~= nil
                if not isRF then
                    local m = g:FindFirstChild("Main", true)
                    isRF = m ~= nil and m:FindFirstChild("Topbar") ~= nil
                end
                if isRF and getgenv().RM_Run > 1 then g:Destroy() end
            end
        end
    end
end)

if G.RM_FB == nil then G.RM_FB = true end                -- fullbright (+ всегда без тумана)
G.RM_Bright = G.RM_Bright or 3                        -- яркость 0..10
G.RM_TPSpeed = false                                  -- TP walk (ВЫКЛ по умолчанию)
G.RM_TPSpeedVal = G.RM_TPSpeedVal or 50               -- скорость телепорта, studs/s
G.RM_StaminaLock = false                              -- infinite stamina (ВЫКЛ по умолчанию)
G.RM_CamMode = G.RM_CamMode or "game"                 -- камера: game / first / third
G.RM_ActionDelay = G.RM_ActionDelay or 0.1             -- задержка действий, с (кулдауны; слайдер 0.03..5)
G.RM_FuelThreshold = G.RM_FuelThreshold or 50          -- авто-заправка ниже уровня, % (100 = всегда)
G.RM_TweenSpeed = G.RM_TweenSpeed or 500               -- скорость плавных телепортов, студ/с
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

-- ================= плавный телепорт (TweenService) =================
-- Все телепорты (автозабор, авто-заправка, электрика) летят плавно:
-- tween по CFrame HumanoidRootPart, скорость — слайдер «Скорость
-- твинов» (G.RM_TweenSpeed, по умолчанию 500 студ/с, 0.05–3 с).
-- TP walk не тут: он и так двигает каждый кадр маленькими шажками.
local TweenService = game:GetService("TweenService")

-- Возвращает true, только если долетели И скрипт не перезапускали:
-- после Completed:Wait() старый прогон при re-run обязан прекратить
-- свои действия — иначе два прогона тянут персонаж в разные точки.
local function smoothTP(hrp, cf, dur)
    if getgenv().RM_Run ~= RUN_ID then return false end
    if not dur then
        local spd = tonumber(G.RM_TweenSpeed) or 500
        dur = math.clamp(
            (cf.Position - hrp.Position).Magnitude / spd, 0.05, 3)
    end
    local okDone = false
    pcall(function()
        local tw = TweenService:Create(hrp,
            TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            { CFrame = cf })
        tw:Play()
        tw.Completed:Wait()
        okDone = true
    end)
    if getgenv().RM_Run ~= RUN_ID then return false end
    if not hrp or not hrp.Parent then return false end
    return okDone
end

-- re-run посреди автозабора: старый прогон оборвался между телепортом
-- к предмету и возвратом — персонаж бросило у предмета. Новый прогон
-- откатывает на сохранённую точку (один раз, своя плейс-карта).
task.spawn(function()
    local saved = G.RM_TP_Origin
    if type(saved) ~= "table" or type(saved.cf) ~= "CFrame"
        or saved.place ~= game.PlaceId then
        G.RM_TP_Origin = nil
        return
    end
    G.RM_TP_Origin = nil
    pcall(function()
        local ch = LP.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if hrp then
            task.wait(1) -- даём новому прогону поднять GUI
            smoothTP(hrp, saved.cf)
        end
    end)
end)

-- оригинальные значения освещения, снятые при ПЕРВОМ запуске:
-- выключение fullbright/no-fog должно ВОЗВРАЩАТЬ темноту.
-- Снимок живёт в getgenv(): при re-run старый прогон мог уже
-- выкрутить свет — снимок «оригинала» с изменённого состояния
-- сломал бы восстановление (после выключения остался бы fullbright)
local BRIGHT = {"Brightness", "ClockTime", "Ambient", "OutdoorAmbient",
    "ColorShift_Top", "ColorShift_Bottom", "ExposureCompensation",
    "EnvironmentDiffuseScale", "EnvironmentSpecularScale"}
local FOG = {"GlobalShadows", "FogStart", "FogEnd", "FogColor"}
local ORIG = G.RM_ORIG
if not ORIG then
    ORIG = {}
    for _, name in ipairs(BRIGHT) do
        local ok, v = pcall(function() return Lighting[name] end)
        if ok then ORIG[name] = v end
    end
    for _, name in ipairs(FOG) do
        local ok, v = pcall(function() return Lighting[name] end)
        if ok then ORIG[name] = v end
    end
    G.RM_ORIG = ORIG
end

local function restoreGroup(list)
    for _, name in ipairs(list) do
        local v = ORIG[name]
        if v ~= nil then setProp(Lighting, name, v) end
    end
end

-- снимок Atmosphere (туман от неё перебивает Lighting.FogEnd —
-- если гасить только Fog*, туман всё равно остаётся). Снимок в
-- getgenv(): при re-run не переснимаем уже погашенный туман
-- как «оригинал» (иначе выключение не вернёт бы туман вообще)

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
        -- туман через Atmosphere — гасим тоже (иначе он перебивает Fog*)
        pcall(function()
            local a = Lighting:FindFirstChildOfClass("Atmosphere")
            if a then
                if not G.RM_ATM_ORIG then
                    G.RM_ATM_ORIG = { Density = a.Density, Haze = a.Haze, Offset = a.Offset }
                end
                setProp(a, "Density", 0)
                setProp(a, "Haze", 0)
                setProp(a, "Offset", 0)
            end
        end)
    else
        restoreGroup(BRIGHT)
        restoreGroup(FOG)
        -- вернуть туман Atmosphere как было
        pcall(function()
            local o = G.RM_ATM_ORIG
            if o then
                local a = Lighting:FindFirstChildOfClass("Atmosphere")
                if a then
                    setProp(a, "Density", o.Density)
                    setProp(a, "Haze", o.Haze)
                    setProp(a, "Offset", o.Offset)
                end
            end
        end)
    end
end

-- ================= камера: 1-е лицо / 3-е (сзади) =================
-- "game" — как в игре (трогаем один раз), "first"/"third" — держим
-- принудительно каждый кадр, перекрывая локи игры.
local CAM_ORIG = G.RM_CAM_ORIG
if not CAM_ORIG then
    CAM_ORIG = { mode = Enum.CameraMode.Classic, min = 0.5, max = 12.8 }
    pcall(function()
        CAM_ORIG.mode = LP.CameraMode
        CAM_ORIG.min = LP.CameraMinZoomDistance
        CAM_ORIG.max = LP.CameraMaxZoomDistance
    end)
    -- снимок в getgenv(): при re-run не переснимаем камеру,
    -- уже переключенную старым прогоном (иначе «Как в игре»
    -- восстанавливало бы наш же лок 1-го лица)
    G.RM_CAM_ORIG = CAM_ORIG
end

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
local lightConn
lightConn = RunService.RenderStepped:Connect(function()
    if getgenv().RM_Run ~= RUN_ID then
        -- старый прогон отписывается сам — не держим замыкание на кадре
        if lightConn then lightConn:Disconnect() lightConn = nil end
        return
    end
    if G.RM_FB then pcall(applyLight) end
    if G.RM_CamMode ~= "game" then pcall(applyCam) end
end)
-- поздний повтор света: игра может возвращать туман своим скриптом
-- на том же кадре — применим ЕЩЁ РАЗ после всех RenderStepped
pcall(function() RunService:UnbindFromRenderStep("RMLightLate") end)
RunService:BindToRenderStep("RMLightLate", Enum.RenderPriority.Camera.Value + 10, function()
    if getgenv().RM_Run ~= RUN_ID then return end
    if G.RM_FB then pcall(applyLight) end
end)

-- ================= TP walk (speed без WalkSpeed) =================
-- Двигаем HumanoidRootPart телепортами по направлению взгляда.
-- WalkSpeed остаётся штатной — сервер видит телепорты позиции,
-- а не скорость. Shift = ускорение x1.6.
local camFwd, camRight = nil, nil
local standOffset = nil -- реальная высота стойки над землёй (замер, не хардкод)
local CLIMB = 2.5 -- максимум подъёма за шаг: ступени лестницы, пандус, ящик

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

local walkConn, walkWarnAt = nil, 0
walkConn = RunService.RenderStepped:Connect(function(dt)
    if getgenv().RM_Run ~= RUN_ID then
        if walkConn then walkConn:Disconnect() walkConn = nil end
        return
    end
    if not G.RM_TPSpeed or pickupBusy then return end
    local okW, errW = pcall(function()
        local cam = workspace.CurrentCamera
        if not cam then return end
        local ch = LP.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if not hrp or not hrp.Parent then return end

        local x, z, sprint = moveKeys()
        if x == 0 and z == 0 then return end

        -- LookVector ровно вверх/вниз (камера у потолка/пола) даёт
        -- нулевую горизонтальную проекцию: .Unit тут = NaN →
        -- персонаж улетал в пустоту. Без движения — просто выходим.
        local lv, rv = cam.CFrame.LookVector, cam.CFrame.RightVector
        camFwd = Vector3.new(lv.X, 0, lv.Z)
        camRight = Vector3.new(rv.X, 0, rv.Z)
        if camFwd.Magnitude < 0.001 or camRight.Magnitude < 0.001 then return end
        camFwd = camFwd.Unit
        camRight = camRight.Unit

        local spd = (G.RM_TPSpeedVal or 50) * sprint
        local step = spd * math.min(dt, 0.05)
        local stepVec = camFwd * z * step + camRight * x * step

        -- Не проходим сквозь стены/предметы, но МОЖНО лезть по ступеням:
        --  * уровень головы (feet+4): попадание = стена/дверь — блок;
        --  * корпус/колено: вниз от точки попадания (с высоты feet+10) —
        --    поверхность не выше CLIMB = ступенька/пандус, заходим на
        --    неё; выше = предмет — обрезаем шаг перед ним;
        --  * земля под концом шага выше CLIMB — высокий предмет в пути.
        -- Обрезанный шаг = до встречного препятствия минус 0.4 студа.
        local stepLen = stepVec.Magnitude
        if stepLen > 0 then
            local rdir = stepVec.Unit
            local params = RaycastParams.new()
            params.FilterDescendantsInstances = {ch}
            params.IgnoreWater = true
            local feetY = hrp.Position.Y - (standOffset or 2)
            local rayLen = stepLen + 0.4
            local blockD = nil
            local blocked = false

            -- что стоит на месте встречи (для корпуса/колена)
            local function wallThere(pos)
                local probe = workspace:Raycast(
                    Vector3.new(pos.X, feetY + 10, pos.Z),
                    Vector3.new(0, -20, 0), params)
                return (not probe) or (probe.Position.Y - feetY) > CLIMB
            end

            local origins = {
                { Vector3.new(hrp.Position.X, feetY + 4, hrp.Position.Z), true },   -- голова
                { hrp.Position, false },                                             -- корпус
                { Vector3.new(hrp.Position.X, feetY + 0.7, hrp.Position.Z), false }, -- колено
            }
            for _, rec in ipairs(origins) do
                local o, isHead = rec[1], rec[2]
                local h = workspace:Raycast(o, rdir * rayLen, params)
                if h and not h.Instance:IsA("Terrain") then
                    -- голова бьётся только о высокое (это и есть стена),
                    -- корпус/колено — меряем высоту препятствия рейкастом
                    if isHead or wallThere(h.Position) then
                        blocked = true
                        local d = (h.Position - o).Magnitude - 0.4
                        if d < 0 then d = 0 end
                        if not blockD or d < blockD then blockD = d end
                    end
                end
            end

            if not blocked then
                -- земля под концом шага: выше CLIMB — высоко, не туда
                local endPos = hrp.Position + stepVec
                local probe = workspace:Raycast(
                    Vector3.new(endPos.X, feetY + CLIMB + 0.5, endPos.Z),
                    Vector3.new(0, -(CLIMB + 6), 0), params)
                if probe and (probe.Position.Y - feetY) > CLIMB then
                    blocked = true
                end
            end

            if blocked then
                stepVec = rdir * (blockD or 0)
            end
        end
        local np = hrp.Position + stepVec

        -- Держим корпус на земле БЕЗ рывков вверх:
        --  * замеряем реальную высоту стойки (не хардкод "+1");
        --  * рейкаст вниз КАЖДЫЙ тик: раз в 0.1с на лестницах шаг
        --    перепрыгивал ступени и мы вставали внутри;
        --  * подъём больше CLIMB (2.5 студ) не берём — дальше не прыгаем,
        --    вниз опускаем плавно, не более 5 студ за тик.
        do
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

            -- земля под целевой точкой (старт выше запланированного
            -- подъём — иначе следующую ступень не находим)
            local res = workspace:Raycast(
                Vector3.new(np.X, np.Y + 4, np.Z),
                Vector3.new(0, -90, 0), params)
            if res then
                local targetY = res.Position.Y + off
                local rise = targetY - np.Y
                if rise <= 0 then
                    np = Vector3.new(np.X, math.max(targetY, np.Y - 5), np.Z)
                elseif rise <= CLIMB then
                    np = Vector3.new(np.X, targetY, np.Z)
                end
                -- rise > CLIMB: держим текущую высоту — без прыжка вверх
            end
        end

        hrp.CFrame = CFrame.new(np) * (hrp.CFrame - hrp.CFrame.Position)
    end)
    -- молча не глотаем ошибки, но и не спамим каждым кадром:
    -- warn не чаще раза в 5 секунд
    if not okW then
        local now = os.clock()
        if now - walkWarnAt > 5 then
            walkWarnAt = now
            warn("[RM] TP walk: " .. tostring(errW))
        end
    end
end)

-- ================= infinite stamina (разовое обнаружение + лок) =================
-- Не сканируем постоянно: ОДИН раз находим реальную стамину
-- (та, что падает при беге), запоминаем ссылку и дальше крутим
-- только её. Рескан только если значение исчезло (респавн).
-- (дубль сброса не нужен: G.RM_StaminaLock уже = false в дефолтах)
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
    -- без реального разброса (при замере не бегали) это НЕ стамина:
    -- писать max в случайное значение — десинк и кик Error 267.
    -- nil = следующий цикл повторит обнаружение
    if not best or (best.mx - best.mn) < 0.5 then return nil end
    local okN, fn = pcall(function() return best.v:GetFullName() end)
    return { v = best.v, max = best.mx, path = okN and fn or best.v.Name }
end

task.spawn(function()
    while true do
        if getgenv().RM_Run ~= RUN_ID then return end
        pcall(function()
            stamStatus.Visible = G.RM_StaminaLock == true
        end)
        if G.RM_StaminaLock then
            pcall(function()
                -- значение исчезло (респавн) -> переобнаружение
                if stamRef and (not stamRef.v or stamRef.v.Parent == nil) then stamRef = nil end
                if not stamRef then
                    local r = discoverStaminaOnce()
                    -- там 1.2с yield: после re-run мёртвый прогон
                    -- не пишет в чужую стамину
                    if getgenv().RM_Run ~= RUN_ID then return end
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

-- ===== Anti-Freeze: не замерзать =====
-- В игре Character.Temperature — это LocalScript (гасим Enabled, по данным
-- RMxploitt); старый вариант ждал .Value числом и молча ничего не делал.
-- Значения Temperature/Freeze тоже держим, но ТОЛЬКО при отличии —
-- постоянные записи дают десинк и кик (Error 267).
G.RM_AntiFreeze = false -- без флага: всегда стартует выключенным
local tempScriptOff = false -- выключили ли мы LocalScript (чтобы вернуть)
task.spawn(function()
    while true do
        if getgenv().RM_Run ~= RUN_ID then return end
        if G.RM_AntiFreeze then
            pcall(function()
                local ch = LP.Character
                if ch then
                    local t = ch:FindFirstChild("Temperature", true)
                    if t and (t:IsA("LocalScript") or t:IsA("Script")) then
                        if t.Enabled then
                            t.Enabled = false
                            tempScriptOff = true
                        end
                    elseif t and t:IsA("ValueBase")
                        and typeof(t.Value) == "number"
                        and t.Value ~= 20 then
                        t.Value = 20
                    end
                    local f = ch:FindFirstChild("Freeze", true)
                    if f and f:IsA("ValueBase") and typeof(f.Value) == "number"
                        and f.Value ~= 0 then
                        f.Value = 0
                    end
                end
            end)
        end
        task.wait(0.5)
    end
end)

-- ===== Бесконечный кислород (Breath) =====
-- Как стамина: Max-атрибут + значение, запись только при отличии;
-- заодно глушим Blur и HeavyBreath (как в RMxploitt, но аккуратнее).
G.RM_InfO2 = false
task.spawn(function()
    while true do
        if getgenv().RM_Run ~= RUN_ID then return end
        if G.RM_InfO2 then
            pcall(function()
                local ch = LP.Character
                local b = ch and ch:FindFirstChild("Breath", true)
                if b then
                    if b:GetAttribute("Max") ~= 999999 then
                        b:SetAttribute("Max", 999999)
                    end
                    if b:IsA("ValueBase") and typeof(b.Value) == "number"
                        and b.Value ~= 999999 then
                        b.Value = 999999
                    end
                end
                local blur = Lighting:FindFirstChild("Blur")
                if blur and blur:IsA("BlurEffect") and blur.Enabled then
                    blur.Enabled = false
                end
                local snds = workspace:FindFirstChild("Sounds")
                local hb = snds and snds:FindFirstChild("HeavyBreath")
                if hb then
                    if hb.Looped then hb.Looped = false end
                    if hb.Playing then hb.Playing = false end
                end
            end)
        end
        task.wait(0.5)
    end
end)

-- ===== Бесконечный заряд фонаря (Flashlight.Battery) =====
-- Из gist «Night 3» (yancielsicard2-arch): NumberValue Battery лежит в
-- Character.Flashlight или Backpack.Flashlight; держим на 130 (максимум
-- из источника), запись только при отличии — без дёрганья каждые 0.5с.
G.RM_InfBattery = false
task.spawn(function()
    while true do
        if getgenv().RM_Run ~= RUN_ID then return end
        if G.RM_InfBattery then
            pcall(function()
                local function lockB(root)
                    local fl = root and root:FindFirstChild("Flashlight")
                    local bat = fl and fl:FindFirstChild("Battery")
                    if bat and bat:IsA("ValueBase") and typeof(bat.Value) == "number"
                        and bat.Value < 130 then
                        bat.Value = 130
                    end
                end
                lockB(LP.Character)
                lockB(LP.Backpack)
            end)
        end
        task.wait(0.5)
    end
end)

-- ===== Auto Scare: Ларри у окна → флешка (подключение в GUI «Ночь 1») =====
G.RM_AutoScare = false
local scareConn = nil

-- Тревога кабины: слушает RemoteEvent OpenDoor (сервер шлёт OnClientEvent
-- всем клиентам — читаем пассивно). Подключается тоглом в GUI «Ночь 3».
G.RM_CabinAlert = false
local cabinConn = nil
local cabinGen = 0 -- поколение подписки (гонка выкл/пока ждём ремоут)

-- Noclip: подключается тоглом в GUI (здесь только состояние)
G.RM_Noclip = false
local noclipConn = nil
-- исходные CanCollide до включения (чтобы вернуть свои) — лежат в
-- getgenv: при re-run новый прогон вернул бы стены сам (блок старта)
local noclipSaved = G.RM_NoclipSaved or {}
G.RM_NoclipSaved = noclipSaved

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
    if typeof(m) ~= "Instance" or not m:IsA("Model") then return false end
    local n = string.lower(m.Name)
    -- BunkerRat из бункера = Abomination (Bunker Helper V5): тоже носит
    -- Config и должен светиться в ESP мутанта, а не в «монстрах»
    return string.find(n, "mutant", 1, true) ~= nil
        or string.find(n, "abomination", 1, true) ~= nil
        or string.find(n, "bunkerrat", 1, true) ~= nil
end

local function addMutant(m)
    if inCache[m] or not m.Parent then return end
    ensureESPScreen()
    local pg = ESPScreen
    if not pg then return end
    inCache[m] = true
    print("[RM] Мутант появился: " .. m.Name)

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

-- состояние мутанта из Character.Config (читаемо на клиенте, путь сверен
-- с открытым исходником script-sources/residence-massacre):
-- Chasing = бежит за целью, Seeking = ищет, Active = активен
local function boolVal(parent, name)
    local v = parent:FindFirstChild(name)
    if v then
        local ok, val = pcall(function() return v.Value end)
        if ok then return val == true end
    end
    local a = parent:GetAttribute(name)
    return a == true
end

local function mutantState(m)
    local cfg = m:FindFirstChild("Config", true)
    if not cfg then return "", false end
    if boolVal(cfg, "Chasing") then return " — ДОГОНЯЕТ!", true end
    if boolVal(cfg, "Seeking") then return " — ИЩЕТ", false end
    if boolVal(cfg, "Active") then return " — активен", false end
    return "", false
end

-- первичный поиск
pcall(function()
    for _, d in ipairs(workspace:GetDescendants()) do
        if isMutantModel(d) then addMutant(d) end
    end
end)
-- спавн/десавн — события для быстрой реакции.
-- При re-run старый прогон ОТКЛЮЧАЕТСЯ сам: иначе каждый перезапуск
-- оставлял бы ещё по паре обработчиков с мёртвыми кэшами (утечка)
local mutAddConn, mutRemConn
mutAddConn = workspace.DescendantAdded:Connect(function(obj)
    if getgenv().RM_Run ~= RUN_ID then
        if mutAddConn then mutAddConn:Disconnect() mutAddConn = nil end
        return
    end
    if isMutantModel(obj) then addMutant(obj) end
end)
mutRemConn = workspace.DescendantRemoving:Connect(function(obj)
    if getgenv().RM_Run ~= RUN_ID then
        if mutRemConn then mutRemConn:Disconnect() mutRemConn = nil end
        return
    end
    if inCache[obj] then removeMutant(obj) end
end)
-- ПОСТОЯННЫЙ скан: ловит переименования и спавны, которые
-- события не покрывают (модель появилась под другим именем
-- и была переименована в Mutant). Раз в секунду.
task.spawn(function()
    while true do
        if getgenv().RM_Run ~= RUN_ID then return end
        pcall(function()
            for _, d in ipairs(workspace:GetDescendants()) do
                if isMutantModel(d) then addMutant(d) end
            end
            -- погоня: одно сообщение на переход (Config.Chasing)
            for _, e in ipairs(mutantCache) do
                local mm = e.model
                local chasing = false
                if mm and mm.Parent then
                    local cfg = mm:FindFirstChild("Config", true)
                    chasing = cfg ~= nil and boolVal(cfg, "Chasing")
                end
                if chasing and not e.chasing then
                    print("[RM] Мутант: ПРЕСЛЕДУЕТ кого-то (Chasing)")
                end
                e.chasing = chasing
                -- состояние для метки (DОГОНЯЕТ/ИЩЕТ) считаем тут, раз в
                -- секунду, — кадровый рендер просто читает e.state/e.danger
                if mm and mm.Parent then
                    local st, danger = mutantState(mm)
                    e.state = st
                    e.danger = danger
                end
            end
        end)
        task.wait(1)
    end
end)

local mutantDrawConn
mutantDrawConn = RunService.RenderStepped:Connect(function()
    if getgenv().RM_Run ~= RUN_ID then
        if mutantDrawConn then mutantDrawConn:Disconnect() mutantDrawConn = nil end
        return
    end
    pcall(function()
        local on = G.RM_MutantESP
        local lpch = LP.Character
        local myHRP = lpch and lpch:FindFirstChild("HumanoidRootPart")
        for i = #mutantCache, 1, -1 do
            local e = mutantCache[i]
            local m = e.model
            if not e.hl.Parent or not e.gui.Parent then
                -- хайлайт/метку удалили — убираем из кэша и добиваем
                -- уцелевшего «сироту» (иначе дубликат при пересоздании)
                pcall(function() e.hl:Destroy() end)
                pcall(function() e.gui:Destroy() end)
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
                        -- состояние/опасность считает 1-сек скан (e.state):
                        -- глубокий FindFirstChild("Config") каждый кадр — перф
                        local txt = ("MUTANT [%dm] HP %s%s")
                            :format(math.floor(dist), tostring(hp),
                                e.state or "")
                        if e.lblTxt ~= txt then
                            e.lblTxt = txt
                            e.lbl.Text = txt
                        end
                        -- красным при погоне, иначе — обычный цвет ESP
                        local col = e.danger and Color3.fromRGB(255, 60, 60)
                            or G.RM_MutantColor
                        if e.lbl.TextColor3 ~= col then
                            e.lbl.TextColor3 = col
                        end
                        e.gui.Adornee = root
                        show = true
                    end
                end
                if e.hl.Enabled ~= show then e.hl.Enabled = show end
                if e.gui.Enabled ~= show then e.gui.Enabled = show end
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
    -- мутанты/BunkerRat ведутся отдельной секцией выше — без двойного ESP
    if isMutantModel(m) then return nil end
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
    local seenNames = {}
    for owner, it in pairs(interact) do
        local nm = displayName(owner)
        local key = string.lower(nm)
        seenNames[key] = true
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
    -- имена предметов, которых больше нет в мире, убираем из списка:
    -- выпадашка «Что собирать» засорялась старья после респавна
    local nameGone = false
    for key in pairs(itemNames) do
        if not seenNames[key] then
            itemNames[key] = nil
            nameGone = true
        end
    end
    -- в выпадашке появились новые или ушли предметы — обновляем
    if (newName or nameGone) and pickDD and type(pickDD.Refresh) == "function" then
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

-- спавн/десавн — быстрая реакция (без ожидания секундного скана).
-- self-disconnect при re-run — как у mutant-событий выше (утечка)
local espAddConn, espRemConn
espAddConn = workspace.DescendantAdded:Connect(function(obj)
    if getgenv().RM_Run ~= RUN_ID then
        if espAddConn then espAddConn:Disconnect() espAddConn = nil end
        return
    end
    if obj:IsA("Model") then
        local k = modelKind(obj)
        if k and not espBy[obj] then espAdd(obj, k) end
    end
    -- появился ClickDetector/Prompt (предмет/канистра/генератор) —
    -- сразу ресканим предметы, не ждём секундного скана
    if obj:IsA("ClickDetector") or obj:IsA("ProximityPrompt") then
        task.defer(function()
            if getgenv().RM_Run == RUN_ID then pcall(scanItems) end
        end)
    end
end)
espRemConn = workspace.DescendantRemoving:Connect(function(obj)
    if getgenv().RM_Run ~= RUN_ID then
        if espRemConn then espRemConn:Disconnect() espRemConn = nil end
        return
    end
    if espBy[obj] then espRemove(obj) end
end)

pcall(scanEsp)
task.spawn(function()
    while true do
        if getgenv().RM_Run ~= RUN_ID then return end
        local okS, errS = pcall(scanEsp)
        if not okS then print("[RM] скан ESP: " .. tostring(errS)) end
        task.wait(1)
    end
end)

-- ===== автозабор: телепорт рядом → клик → обратно =====
local fireWarned = false

local function fireItem(e)
    local fired = false
    if e.prompt then
        -- запись в replicated-свойство только при отличии: постоянный
        -- одинаковый сет = десинк/кик Error 267
        if e.prompt.HoldDuration ~= 0 then
            pcall(function() e.prompt.HoldDuration = 0 end)
        end
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
    -- кликнуть нечем (функции не экспортированы экзекутором) — не
    -- телепортируемся впустую, повтор через минуту
    local canFire = (e.prompt and typeof(fireproximityprompt) == "function")
        or (e.cd and typeof(fireclickdetector) == "function")
    if not canFire then
        if not fireWarned then
            fireWarned = true
            print("[RM] В экзекуторе нет fireproximityprompt/fireclickdetector — автозабор не сможет кликать предметы")
        end
        e.clickAt = os.clock() + 60
        return
    end

    local dist = (pos - hrp.Position).Magnitude
    pickupBusy = true
    local teleported = false
    local origin = hrp.CFrame
    pcall(function()
        if dist > math.max(maxD - 3, 2) then
            -- телепорт рядом с предметом: для сервера — «игрок стоял рядом».
            -- true только если долетели: после re-run smoothTP вернёт false
            teleported = smoothTP(hrp, CFrame.new(pos + Vector3.new(0, 3, 0))
                * (hrp.CFrame - hrp.CFrame.Position)) == true
        end
    end)
    -- после каждого yield — проверка re-run: старый прогон не кликает
    -- и не телепортирует (его pickupBusy — свой upvalue, новый он не трогает)
    if getgenv().RM_Run ~= RUN_ID then return end
    -- телепортнулись: запоминаем точку возврата в getgenv — новый прогон
    -- (re-run посреди автозабора) откатит персонажа туда сам
    if teleported then
        G.RM_TP_Origin = { cf = origin, place = game.PlaceId }
    end
    if teleported then task.wait(0.1) end -- позиция успевает дойти до сервера
    if getgenv().RM_Run ~= RUN_ID then return end
    pcall(function() fireItem(e) end)
    e.clickAt = os.clock() -- кулдаун по каждой цели — из слайдера «Скорость действий»
    -- цель не исчезла после клика (залипшая дверь/Prompt) — через 2.5с
    -- ставим длинный кулдаун, иначе телепорт-пинг-понг каждые ~0.5с
    task.delay(2.5, function()
        if getgenv().RM_Run == RUN_ID and e.inst and e.inst.Parent then
            e.clickAt = os.clock() + 10
        end
    end)
    if teleported then
        task.wait(0.05)
        if getgenv().RM_Run ~= RUN_ID then return end
        pcall(function() smoothTP(hrp, origin) end)
        G.RM_TP_Origin = nil
    end
    task.wait(0.1)
    pickupBusy = false
end

-- электрику (ящик, провода, ключ) автозабор НЕ трогает — ею занимается
-- Auto electric, иначе будут случайные клики по проводам и ящику
local function isElectric(inst)
    local n = inst
    while n and n ~= workspace do
        local low = string.lower(n.Name)
        if string.find(low, "wire", 1, true)
            or string.find(low, "fuse", 1, true)
            or string.find(low, "wrench", 1, true) then
            return true
        end
        n = n.Parent
    end
    return false
end

-- раз в 0.4с берём ближайший подходящий предмет из списка
task.spawn(function()
    while true do
        if getgenv().RM_Run ~= RUN_ID then return end
        local okP, errP = pcall(function()
            if G.RM_AutoPickup and not pickupBusy then
                local ch = LP.Character
                local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local best, bestD = nil, math.huge
                    for _, e in ipairs(espCache) do
                        if e.kind == "item" and e.inst.Parent
                            and (e.prompt or e.cd)
                            -- генератор/капсула не трогаем — ими занимаются
                            -- Auto fuel и Auto PowerCell (Ночь 2)
                            and not string.find(string.lower(e.itemName or e.inst.Name),
                                "generator", 1, true)
                            and not string.find(string.lower(e.itemName or e.inst.Name),
                                "powercell", 1, true)
                            -- электрику не трогаем — ею занимается Auto electric
                            and not isElectric(e.inst)
                            and (not e.clickAt or os.clock() - e.clickAt
                                >= (tonumber(G.RM_ActionDelay) or 0.1))
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
        if not okP then print("[RM] цикл автозабора: " .. tostring(errP)) end
        task.wait(0.4)
    end
end)

-- ===== авто-топливо: JerryCan → Generator =====
-- Схема: телепорт к канистре → взять (кулдаун ~3с стоим рядом) →
-- телепорт к генератору → подать топливо (кулдаун ~3с) → обратно.
-- Для сервера мы всё время стоим рядом с тем, что жмём.
G.RM_AutoFuel = false -- без флага: всегда стартует выключенным
local lastCanAt = -1e9  -- «нулевой» 0 врёт при маленьком os.clock(): берём −∞
local lastFuelAt = -1e9 -- общий кулдаун цикла авто-заправки (анти-пинг-понг)
local fuelWarned = false
local fuelLvlWarned = false -- предупреждение «значение топлива не найдено»

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
    if not pos or not cd then return false end
    local maxD = cd.MaxActivationDistance or 32
    local dist = (pos - hrp.Position).Magnitude
    if dist > math.max(maxD - 3, 2) then
        pcall(function()
            smoothTP(hrp, CFrame.new(pos + Vector3.new(0, 3, 0))
                * (hrp.CFrame - hrp.CFrame.Position))
        end)
        task.wait(0.1) -- позиция успевает дойти до сервера
        -- после yield мёртвый прогон (re-run) не кликает
        if getgenv().RM_Run ~= RUN_ID then return false end
    end
    if typeof(fireclickdetector) == "function" then
        -- клик засчитываем только если он реально прошёл: иначе
        -- lastCanAt сбрасывается вхолостую и проверка «нет
        -- fireclickdetector» никогда не срабатывает
        return pcall(function() fireclickdetector(cd) end)
    end
    if not fuelWarned then
        fuelWarned = true
        print("[RM] В экзекуторе нет fireclickdetector — авто-заправка не сможет нажимать")
    end
    return false
end

-- текущий уровень топлива генератора в процентах (0..100) или nil,
-- если игра нигде не хранит число, которое мы можем прочитать:
--  1) Value-объект с "fuel" в имени; 2) атрибут; 3) текст над генератором
local function fuelLevel(gen)
    if not gen then return nil end
    local v = nil
    pcall(function()
        for _, d in ipairs(gen:GetDescendants()) do
            if d:IsA("ValueBase") and typeof(d.Value) == "number" then
                local n = string.lower(d.Name)
                if string.find(n, "fuel", 1, true) or string.find(n, "gas", 1, true) then
                    v = d.Value
                    break
                end
            end
        end
        if v == nil then
            for _, name in ipairs({ "Fuel", "fuel", "FuelLevel", "Gas", "gas" }) do
                local a = gen:GetAttribute(name)
                if typeof(a) == "number" then
                    v = a
                    break
                end
            end
        end
        if v == nil then
            for _, d in ipairs(gen:GetDescendants()) do
                if d:IsA("TextLabel") then
                    local t = string.lower(tostring(d.Text or ""))
                    local num = string.match(t, "(%d+)%s*%%")
                        or string.match(t, "fuel%s*[:=]?%s*(%d+)")
                        or string.match(t, "^%s*(%d+)%s*$")
                    if num then
                        v = tonumber(num)
                        break
                    end
                end
            end
        end
    end)
    if v == nil then return nil end
    -- шкала игры 0..100 (сверено: Shack.Generator.Fuel показывают как %);
    -- старое умножение ломалось на значении 1% → 100% и заправка молчала
    if v < 0 then v = 0 end
    if v > 100 then v = 100 end
    return v
end

task.spawn(function()
    while true do
        if getgenv().RM_Run ~= RUN_ID then return end
        local okF, errF = pcall(function()
            if G.RM_AutoFuel and not pickupBusy then
                local ch = LP.Character
                local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local can, cdCan = findByModelName("jerrycan")
                    local gen, cdGen = findByModelName("generator")
                    -- канистра у нас в руках (модель внутри персонажа)
                    local held = can and ch and can:IsDescendantOf(ch)
                    local tookRecently = (os.clock() - lastCanAt) < 15
                    -- порог игрока: пополняем, только когда топлива
                    -- меньше заданного (0 = никогда, 100 = всегда);
                    -- если прочитать не удалось — пополняем всегда
                    local lvl = fuelLevel(gen)
                    local thr = tonumber(G.RM_FuelThreshold) or 50
                    local lowFuel = (lvl == nil) or (lvl < thr)
                    if lvl == nil and not fuelLvlWarned then
                        fuelLvlWarned = true
                        print("[RM] Значение топлива генератора не найдено — порог не работает, заправляю всегда")
                    end
                    -- брать канистру есть смысл только при наличии генератора
                    local wantCan = lowFuel and (cdCan ~= nil) and (not held) and (cdGen ~= nil)
                    local wantGen = lowFuel and (cdGen ~= nil) and (held or tookRecently)
                    -- общий кулдаун ≥3с между нажатиями: без него
                    -- (канистра «в руках» или порог не читается) клик+телепорт
                    -- каждые 0.5с = Error 267 (топливный пинг-понг)
                    if (wantCan or wantGen)
                        and os.clock() - lastFuelAt >= 3 then
                        lastFuelAt = os.clock()
                        pickupBusy = true
                        local origin = hrp.CFrame
                        -- тело в pcall: ошибка (респавн/исчезнувший объект
                        -- посреди действия) не должна навсегда оставить
                        -- pickupBusy=true — иначе выключатся спид,
                        -- автозабор и электрика
                        local okA, errA = pcall(function()
                            local pressedCan = false
                            if wantCan then
                                pressedCan = fuelPress(hrp, can:GetPivot().Position, cdCan)
                                if pressedCan then lastCanAt = os.clock() end
                                task.wait(tonumber(G.RM_ActionDelay) or 0.1) -- кулдаун канистры
                                -- после yield мёртвый прогон не продолжает
                                if getgenv().RM_Run ~= RUN_ID then return end
                            end
                            local canReady = pressedCan or held
                                or ((os.clock() - lastCanAt) < 15)
                            if G.RM_AutoFuel and cdGen and canReady then
                                fuelPress(hrp, gen:GetPivot().Position, cdGen)
                                task.wait(tonumber(G.RM_ActionDelay) or 0.1) -- кулдаун подачи топлива
                                if getgenv().RM_Run ~= RUN_ID then return end
                            end
                        end)
                        -- возвращаемся всегда, даже после ошибки
                        pcall(function() smoothTP(hrp, origin) end)
                        pickupBusy = false
                        if not okA then
                            print("[RM] Auto fuel: " .. tostring(errA))
                        end
                    end
                end
            end
        end)
        if not okF then print("[RM] цикл авто-заправки: " .. tostring(errF)) end
        task.wait(0.5)
    end
end)

-- ===== ручная заправка: кнопка «Заправить сейчас» =====
-- Один полный цикл (канистра → генератор), когда захочет игрок —
-- независимо от Auto fuel и порога. true = запускается, false = занято.
local function fuelManual()
    if pickupBusy then return false end
    task.spawn(function()
        if getgenv().RM_Run ~= RUN_ID then return end
        pickupBusy = true
        local hrp, origin = nil, nil
        local done = false -- дошёл ли до конца (return из pcall = ok=true!)
        local ok, err = pcall(function()
            local ch = LP.Character
            hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            if not hrp then error("нет персонажа") end
            origin = hrp.CFrame -- точка возврата — как можно раньше
            local can, cdCan = findByModelName("jerrycan")
            local gen, cdGen = findByModelName("generator")
            if not (gen and cdGen) then error("генератор не найден") end
            if not (can and cdCan) then error("канистра не найдена") end
            local delay = tonumber(G.RM_ActionDelay) or 0.1
            if not can:IsDescendantOf(ch) then
                if fuelPress(hrp, can:GetPivot().Position, cdCan) then
                    lastCanAt = os.clock()
                end
                task.wait(delay)
            end
            -- после yield — проверка re-run: старый прогон не должен
            -- продолжать телепортировать (кнопка жива до ~10с)
            if getgenv().RM_Run ~= RUN_ID then return end
            if not fuelPress(hrp, gen:GetPivot().Position, cdGen) then
                error("нет fireclickdetector у генератора")
            end
            task.wait(delay)
            done = true
        end)
        -- возвращаемся всегда, даже после ошибки
        if hrp and origin then
            pcall(function() smoothTP(hrp, origin) end)
        end
        pickupBusy = false
        if ok and done then
            print("[RM] Заправка: канистра → генератор ✓")
        elseif ok then
            -- return внутри pcall (перезапуск скрипта) даёт ok=true:
            -- не врём «✓», когда цикл не закрылся
            print("[RM] Ручная заправка прервана — скрипт перезапустили")
        else
            print("[RM] Ручная заправка не удалась: " .. tostring(err))
        end
    end)
    return true
end

-- ===== Ночь 2: капсула PowerCell → генератор =====
-- Схема: свободная капсула (PowerCell ВНЕ Generator, с ClickDetector)
-- → телепорт рядом (обязательно стоя рядом) → клик → доставка к
-- Generator → клик по генератору → вставка. «В руках» = стал потомком
-- персонажа ИЛИ кликнули <15с назад. 4 неудачные вставки → стоп.
G.RM_AutoCell = false -- без флага: всегда стартует выключенным
-- −1e9 вместо 0: при os.clock() < 15 «нулевой» 0 делал wantGrab/wantPut ложными
local cellGrabAt = -1e9 -- последний клик по капсуле (окно доставки 15с)
local cellTriedAt = -1e9 -- последняя попытка вставки (кулдаун попыток)
local cellTries = 0   -- неудачных вставок подряд
local cellWarned = false

-- позиция объекта (Model/BasePart; у Folder — первая деталь).
-- НЕ брать Position у ClickDetector: у него нет такого свойства —
-- только что это рвало ящик/ключ/капсулу в pcall
local function objPos(o)
    if not o then return nil end
    if o:IsA("BasePart") then return o.Position end
    local okp, pos = pcall(function() return o:GetPivot().Position end)
    if okp and typeof(pos) == "Vector3" then return pos end
    local h = o:FindFirstChildWhichIsA("BasePart", true)
    return h and h.Position or nil
end

-- свободная капсула: Model «PowerCell» с ClickDetector, НЕ внутри Generator
local function findLooseCell()
    local gen = findByModelName("generator")
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Model")
            and string.find(string.lower(d.Name), "powercell", 1, true)
            and not (gen and d:IsDescendantOf(gen)) then
            local cd = d:FindFirstChildWhichIsA("ClickDetector", true)
            if cd then return d, cd end
        end
    end
    return nil, nil
end

task.spawn(function()
    while true do
        if getgenv().RM_Run ~= RUN_ID then return end
        local okC, errC = pcall(function()
            if G.RM_AutoCell and not pickupBusy then
                local ch = LP.Character
                local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                if hrp then
                    if cellTries >= 4 and not cellWarned then
                        cellWarned = true
                        print("[RM] Ночь 2: капсула не вставилась 4 раза — авто остановлено. "
                            .. "Включи заново после разбора и скажи, как вставляется вручную")
                    end
                    local gen, cdGen = findByModelName("generator")
                    local cell, cdCell = findLooseCell()
                    -- капсула встала (свободной не осталось) — снимаем
                    -- прошлые неудачи: иначе счётчик памятит старую аварию
                    -- и авто не стартует на следующей ночи
                    if not cell and cellTries > 0 then
                        cellTries = 0
                        cellWarned = false
                    end
                    if cell and cdCell and gen and cdGen and cellTries < 4 then
                        local now = os.clock()
                        local held = cell:IsDescendantOf(ch)
                        local delay = tonumber(G.RM_ActionDelay) or 0.1
                        local dt = now - cellGrabAt
                        -- взять: ещё не взяли и окно доставки вышло
                        local wantGrab = (not held) and dt > 15
                        -- внести: в руках или брали <15с назад; не чаще 2с
                        local wantPut = (held or dt <= 15)
                            and (now - cellTriedAt) > math.max(delay, 2)

                        if wantGrab then
                            pickupBusy = true
                            local origin = hrp.CFrame
                            local okG, errG = pcall(function()
                                -- встанет сам рядом с капсулой и жмёт
                                fuelPress(hrp, objPos(cell), cdCell)
                                cellGrabAt = os.clock()
                                task.wait(delay)
                            end)
                            pcall(function() smoothTP(hrp, origin) end)
                            pickupBusy = false
                            if not okG then
                                print("[RM] Ночь 2 (капсула): " .. tostring(errG))
                            end
                        elseif wantPut then
                            pickupBusy = true
                            local origin = hrp.CFrame
                            -- капсула может быть «в окне доставки», но не
                            -- в руках: клик впустую не должен жечь бюджет
                            local wasHeld = cell:IsDescendantOf(ch)
                            local okG, errG = pcall(function()
                                local pressed = fuelPress(hrp, objPos(gen), cdGen)
                                cellTriedAt = os.clock()
                                -- 4 попытки тратим только когда капсула
                                -- реально в руках И клик прошёл
                                if wasHeld and pressed then
                                    cellTries = cellTries + 1
                                end
                                task.wait(delay)
                            end)
                            pcall(function() smoothTP(hrp, origin) end)
                            pickupBusy = false
                            if not okG then
                                print("[RM] Ночь 2 (вставка): " .. tostring(errG))
                            end
                        end
                    end
                end
            end
        end)
        if not okC then print("[RM] цикл Ночь 2: " .. tostring(errC)) end
        task.wait(0.5)
    end
end)

-- ===== электрика: ящик (FuseBox) + провода + ключ (Wrench) =====
-- Провода ломаются случайно (подсвечены Highlight / искры) и требуют
-- ключ. Порядок: 1) ключа нет → телепорт к WrenchGiver и берём;
-- 2) открываем ящик (Detector); 3) телепорт к битому проводу → клик.
-- Если провод не берётся дважды — щёлкаем ящик ещё раз (вдруг закрыт).
-- Все полёты плавные (TweenService), пока Auto electric включён.
G.RM_AutoElectric = false -- без флага: всегда стартует выключенным
local fuseOpened = false   -- мы открыли ящик (нажатие = toggle)
local wireFixAt = {}       -- [модель провода] = когда чинили (кулдаун 4с)
local wireTries = {}       -- [модель провода] = попыток; 2 → щёлкаем ящик
local wrenchGetAt = -1e9  -- кулдаун добычи ключа (0 врёт при маленьком os.clock)
local elecWarned = false
local elecBrokenSeen = -1   -- сколько битых проводов видели вчера (для отладки)
local elecFried = nil       -- последнее известное FusesFried (свет/проводы)

-- модель/папка/деталь по части имени; needCD = обязателен ClickDetector
local function elecFind(sub, needCD)
    local low = string.lower(sub)
    for _, d in ipairs(workspace:GetDescendants()) do
        if (d:IsA("Model") or d:IsA("Folder") or d:IsA("BasePart"))
            and string.find(string.lower(d.Name), low, 1, true) then
            local cd = needCD and d:FindFirstChildWhichIsA("ClickDetector", true)
                or nil
            if not needCD or cd then
                return d, cd
            end
        end
    end
    return nil, nil
end

-- битый провод: подсветка включена (контур) или летят искры —
-- Sparkles.Enabled == true сверено с открытым исходником
-- script-sources/residence-massacre
local function wireBroken(w)
    local res = false
    pcall(function()
        local hl = w:FindFirstChild("Highlight", true)
        if hl and hl:IsA("Highlight") and hl.Enabled
            and (hl.FillTransparency or 0) < 0.9 then
            res = true
        end
    end)
    if not res then
        local sp = w:FindFirstChild("Sparkles", true)
        if sp then
            -- отдельные pcall: если у объекта нет Enabled, доступ падает
            -- и убивал бы весь блок — Value пробуем независимо
            local okE, en = pcall(function() return sp.Enabled end)
            if okE and typeof(en) == "boolean" then
                res = en
            else
                local okV, val = pcall(function() return sp.Value end)
                if okV and typeof(val) == "boolean" then res = val end
            end
        end
    end
    return res
end

-- есть ли ключ (Tool «Wrench»/«ключ») в рюкзаке или в руках
local function findWrenchTool()
    local function test(t)
        if not t:IsA("Tool") then return false end
        local n = string.lower(t.Name)
        return string.find(n, "wrench", 1, true) ~= nil
            or string.find(n, "ключ", 1, true) ~= nil
    end
    local bp = LP:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if test(t) then return t end
        end
    end
    local ch = LP.Character
    if ch then
        for _, t in ipairs(ch:GetChildren()) do
            if test(t) then return t end
        end
    end
    return nil
end

-- битые провода: {model, cd} из папки/модели «Wires»
local function brokenWires()
    local wires = elecFind("wires", false)
    if not wires then return {} end
    local out = {}
    for _, w in ipairs(wires:GetChildren()) do
        if w:IsA("Model") or w:IsA("Folder") or w:IsA("BasePart") then
            if wireBroken(w) then
                -- CD может не быть: кликаем ремоутом ClickWire (так делает
                -- рабочий RMxploitt), CD — запасной вариант
                local cd = w:FindFirstChildWhichIsA("ClickDetector", true)
                out[#out + 1] = { model = w, cd = cd }
            end
        end
    end
    return out
end

-- полёт к точке (сохраняем поворот корпуса) + осесть у цели
local function elecTP(hrp, worldPos, height)
    smoothTP(hrp, CFrame.new(worldPos + Vector3.new(0, height or 2, 0))
        * (hrp.CFrame - hrp.CFrame.Position))
    task.wait(0.1)
    -- после yield: мёртвый прогон (re-run) не шлёт клики/FireServer —
    -- вызывающие обязаны проверить возврат (см. guard'ы ниже)
    if getgenv().RM_Run ~= RUN_ID then return end
end

local function elecClickBox(hrp, origin)
    local box, bcd = elecFind("fusebox", true)
    if not bcd then return false end
    pickupBusy = true
    local okB, errB = pcall(function()
        local pos = objPos(box)
        if pos then elecTP(hrp, pos, 2) end
        -- re-run во время полёта: старый прогон не щёлкает ящиком
        if getgenv().RM_Run ~= RUN_ID then return end
        -- toggle засчитываем только при реальном клике
        if pcall(function() fireclickdetector(bcd) end) then
            fuseOpened = not fuseOpened
        end
        task.wait(0.3)
    end)
    -- возвращаемся всегда, даже после ошибки (респавн/исчез объект)
    pcall(function() smoothTP(hrp, origin) end)
    pickupBusy = false
    if not okB then
        print("[RM] Электрика (ящик): " .. tostring(errB))
    end
    return true
end

task.spawn(function()
    while true do
        if getgenv().RM_Run ~= RUN_ID then return end
        local okE, errE = pcall(function()
            if G.RM_AutoElectric and not pickupBusy then
                local ch = LP.Character
                local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                if hrp and typeof(fireclickdetector) == "function" then
                    -- GameState.FusesFried: true = свет вырубили (проводы
                    -- горят), false = питание ок → сканировать нечего
                    local fried = nil
                    pcall(function()
                        local gs = game:FindFirstChild("ReplicatedStorage")
                        gs = gs and gs:FindFirstChild("GameState")
                        local f = gs and gs:FindFirstChild("FusesFried")
                        if f then fried = (f.Value == true) end
                    end)
                    if fried ~= elecFried then
                        elecFried = fried
                        if fried == true then
                            print("[RM] Электрика: питание вырубили "
                                .. "(FusesFried) — чиню провода")
                            -- новая авария: ящик закрыт, счётчики чисты
                            fuseOpened = false
                            wireTries = {}
                            wireFixAt = {}
                        elseif fried == false then
                            print("[RM] Электрика: питание восстановлено")
                        end
                    end
                    if fried == false then
                        return -- питание ок — нечего чинить
                    end

                    local broken = brokenWires()
                    local now = os.clock()

                    -- отладка детектора: печатаем только при СМЕНЕ
                    -- количества битых — тихо в обычном режиме
                    if #broken ~= elecBrokenSeen then
                        elecBrokenSeen = #broken
                        print("[RM] Электрика: битых проводов " .. #broken
                            .. (#broken > 0 and " — чиню" or " — простой"))
                        local wires = elecFind("wires", false)
                        if wires then
                            for _, w in ipairs(wires:GetChildren()) do
                                if w:IsA("Model") or w:IsA("Folder")
                                    or w:IsA("BasePart") then
                                    pcall(function()
                                        local h = w:FindFirstChild("Highlight", true)
                                        local s = w:FindFirstChild("Sparkles", true)
                                        local st = w:FindFirstChild("Status", true)
                                        local sv = "-"
                                        if st then
                                            pcall(function() sv = tostring(st.Value) end)
                                            if sv == "-" then
                                                pcall(function() sv = tostring(st.Text) end)
                                            end
                                        end
                                        print(string.format(
                                            "[RM]   %s: HL=%s/%s SP=%s ST=%s",
                                            w.Name,
                                            h and tostring(h.Enabled) or "-",
                                            h and tostring(h.FillTransparency) or "-",
                                            s and tostring(s.Enabled) or "-",
                                            sv))
                                    end)
                                end
                            end
                        end
                    end

                    -- 1) ключ: нет → телепорт к WrenchGiver и берём
                    if #broken > 0 and not findWrenchTool()
                        and (now - wrenchGetAt) > 4 then
                        local giver, gcd = elecFind("wrenchgiver", true)
                        if gcd then
                            pickupBusy = true
                            local origin = hrp.CFrame
                            local okW, errW = pcall(function()
                                local pos = objPos(giver)
                                if pos then elecTP(hrp, pos, 3) end
                                if getgenv().RM_Run ~= RUN_ID then return end
                                pcall(function() fireclickdetector(gcd) end)
                                task.wait(0.6) -- выдача инструмента
                            end)
                            wrenchGetAt = os.clock()
                            pcall(function() smoothTP(hrp, origin) end)
                            pickupBusy = false
                            if not okW then
                                print("[RM] Электрика (ключ): " .. tostring(errW))
                            end
                            if not findWrenchTool() and not elecWarned then
                                elecWarned = true
                                print("[RM] Электрика: ключ (Wrench) не появился после WrenchGiver")
                            end
                        elseif not elecWarned then
                            elecWarned = true
                            print("[RM] Электрика: WrenchGiver не найден в workspace")
                        end
                    end

                    if #broken > 0 and findWrenchTool() then
                        -- 2) открываем ящик (один раз на аварию)
                        if not fuseOpened then
                            elecClickBox(hrp, hrp.CFrame)
                        end

                        -- 3) чиним первый битый провод (кулдаун 4с на провод)
                        local w = broken[1]
                        if w and (not wireFixAt[w.model]
                            or (now - wireFixAt[w.model]) > 4) then
                            if (wireTries[w.model] or 0) >= 2 then
                                -- дважды не берётся — возможно, ящик закрыт:
                                -- щёлкаем его и пробуем провод снова
                                wireTries[w.model] = 0
                                elecClickBox(hrp, hrp.CFrame)
                            else
                                pickupBusy = true
                                local origin = hrp.CFrame
                                local okW, errW = pcall(function()
                                    -- ключ в руки, если лежит в рюкзаке
                                    local tool = findWrenchTool()
                                    local hum = ch:FindFirstChildOfClass("Humanoid")
                                    if tool and hum and tool.Parent ~= ch then
                                        hum:EquipTool(tool)
                                    end
                                    local pos = objPos(w.model)
                                    if pos then elecTP(hrp, pos, 2) end
                                    -- re-run во время полёта: сервер-действия
                                    -- старого прогона (FireServer/клик) — стоп
                                    if getgenv().RM_Run ~= RUN_ID then return end
                                    -- сначала ремоут ClickWire (проверенный
                                    -- путь RMxploitt), без него — ClickDetector
                                    local cr = nil
                                    pcall(function()
                                        local rf = game:FindFirstChild(
                                            "ReplicatedStorage")
                                        rf = rf and rf:FindFirstChild("Remotes")
                                        cr = rf and rf:FindFirstChild(
                                            "ClickWire")
                                    end)
                                    if cr then
                                        pcall(function()
                                            cr:FireServer(w.model)
                                        end)
                                    elseif w.cd then
                                        pcall(function()
                                            fireclickdetector(w.cd)
                                        end)
                                    end
                                    task.wait(tonumber(G.RM_ActionDelay) or 0.1)
                                end)
                                -- кулдауны ставим всегда: после ошибки не
                                -- должно быть мгновенного повтора по кругу
                                wireFixAt[w.model] = os.clock()
                                wireTries[w.model] = (wireTries[w.model] or 0) + 1
                                pcall(function() smoothTP(hrp, origin) end)
                                pickupBusy = false
                                if not okW then
                                    print("[RM] Электрика (провод): " .. tostring(errW))
                                end
                            end
                        end
                    end
                end
            end
        end)
        if not okE then print("[RM] цикл электрики: " .. tostring(errE)) end
        task.wait(0.6)
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
local espDrawConn
espDrawConn = RunService.RenderStepped:Connect(function()
    if getgenv().RM_Run ~= RUN_ID then
        if espDrawConn then espDrawConn:Disconnect() espDrawConn = nil end
        return
    end
    pcall(function()
        local ch = LP.Character
        local myHRP = ch and ch:FindFirstChild("HumanoidRootPart")
        for i = #espCache, 1, -1 do
            local e = espCache[i]
            local inst = e.inst
            if not inst or not inst.Parent or not e.hl.Parent
                or not e.gui.Parent then
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
                local txt = nil
                if kindOn(e.kind) and myHRP and pos then
                    local dist = (pos - myHRP.Position).Magnitude
                    local color = kindColor(e.kind)
                    if e.hl.FillColor ~= color then e.hl.FillColor = color end
                    if e.lbl.TextColor3 ~= color then e.lbl.TextColor3 = color end
                    if e.kind == "item" then
                        txt = ("%s [%dm]"):format(e.itemName or inst.Name, math.floor(dist))
                    else
                        local hum = inst:FindFirstChildOfClass("Humanoid")
                        local hp = (hum and hum.Health > 0) and math.floor(hum.Health) or "?"
                        txt = ("%s [%dm] HP %s"):format(inst.Name, math.floor(dist), tostring(hp))
                    end
                    show = true
                end
                -- строки/Enabled не переписываем каждый кадр (GC + layout):
                -- только при реальном изменении
                if txt and e.lblTxt ~= txt then
                    e.lblTxt = txt
                    e.lbl.Text = txt
                end
                if e.hl.Enabled ~= show then e.hl.Enabled = show end
                if e.gui.Enabled ~= show then e.gui.Enabled = show end
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
    -- бинд аимбота уже повешен выше — снимаем, ранний выход не должен
    -- оставлять висеть чужой RenderStep до перезапуска
    pcall(function() RunService:UnbindFromRenderStep("RMAimMonster") end)
    return
end
-- держим ссылку на библиотеку: при re-run убиваем её целиком
-- (см. блок старта) — иначе её InputBegan-подписки живут вечно
G.RM_RayfieldLib = Rayfield

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
    local busySince = nil
    while true do
        if getgenv().RM_Run ~= RUN_ID then return end
        pcall(function()
            -- страховка: pickupBusy завис дольше 30с (нормальное
            -- действие ≤ ~16с даже на макс. задержке) — сбрасываем,
            -- иначе навсегда выключатся спид/автозабор/заправка
            if pickupBusy then
                busySince = busySince or os.clock()
                if os.clock() - busySince > 30 then
                    pickupBusy = false
                    busySince = nil
                    print("[RM] страховка: зависшее авто-действие сброшено")
                end
            else
                busySince = nil
            end
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

Main:CreateToggle({
    Name = "Fullbright",
    CurrentValue = G.RM_FB,
    Flag = "RM_FB",
    Callback = function(v)
        local old = G.RM_FB
        G.RM_FB = v
        applyLight()
        -- уведомляем только при реальном изменении: автозагрузка конфига
        -- Rayfield (+4с) дёргает Set и с тем же значением (цепочка or у
        -- false падает в nil) — иначе самопроизвольные «Fullbright: …»
        if old ~= v then
            notify("Fullbright: " .. (v and "ON" or "OFF"), 2)
        end
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

-- ================= вкладка Игрок (скорость, стамина, автозабор) =================
local PlayerTab = Window:CreateTab("Игрок", 4483362458)

PlayerTab:CreateSection("Скорость")
-- Speed через TP walk (WalkSpeed не трогаем):
-- без флага, всегда стартует выключенным
local speedToggle
speedToggle = PlayerTab:CreateToggle({
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

PlayerTab:CreateSlider({
    Name = "TP speed",
    Range = {10, 300},
    Increment = 5,
    Suffix = " st/s",
    CurrentValue = G.RM_TPSpeedVal,
    Flag = "RM_TPSpeedVal",
    Callback = function(v)
        G.RM_TPSpeedVal = v
    end,
})

-- без флага: значение живёт в getgenv до конца сессии — re-run
-- стартует с последнего значения слайдера (сброс только перезапуском Roblox)
PlayerTab:CreateSlider({
    Name = "Скорость твинов",
    Range = {50, 1000},
    Increment = 10,
    Suffix = " st/s",
    CurrentValue = G.RM_TweenSpeed,
    Callback = function(v)
        G.RM_TweenSpeed = v
    end,
})

PlayerTab:CreateKeybind({
    Name = "Бинд Speed (TP walk)",
    CurrentKeybind = "B",
    Flag = "RM_BindSpeed",
    Callback = function()
        speedToggle:Set(not G.RM_TPSpeed)
    end,
})

PlayerTab:CreateSection("Стамина")
-- без флага, всегда стартует выключенным
local stamToggle
stamToggle = PlayerTab:CreateToggle({
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

PlayerTab:CreateKeybind({
    Name = "Бинд стамины",
    CurrentKeybind = "N",
    Flag = "RM_BindStam",
    Callback = function()
        stamToggle:Set(not G.RM_StaminaLock)
    end,
})

PlayerTab:CreateSection("Кислород")
local o2Toggle
o2Toggle = PlayerTab:CreateToggle({
    Name = "Infinite O2",
    CurrentValue = false,
    Callback = function(v)
        G.RM_InfO2 = v
        notify("Infinite O2: " .. (v and "ON" or "OFF"), 2)
    end,
})
PlayerTab:CreateKeybind({
    Name = "Бинд Infinite O2",
    CurrentKeybind = "V",
    Flag = "RM_BindO2",
    Callback = function()
        o2Toggle:Set(not G.RM_InfO2)
    end,
})

PlayerTab:CreateSection("Фонарь")
-- без флага, как у Infinite O2: всегда стартует выключенным
PlayerTab:CreateToggle({
    Name = "Infinite Battery",
    CurrentValue = false,
    Callback = function(v)
        G.RM_InfBattery = v
        notify("Infinite Battery: " .. (v and "ON" or "OFF"), 2)
    end,
})

PlayerTab:CreateSection("Температура")
local freezeToggle
freezeToggle = PlayerTab:CreateToggle({
    Name = "Anti-Freeze",
    CurrentValue = false,
    Callback = function(v)
        G.RM_AntiFreeze = v
        if not v and tempScriptOff then
            -- вернуть LocalScript Temperature, который мы погасили
            pcall(function()
                local ch = LP.Character
                local t = ch and ch:FindFirstChild("Temperature", true)
                if t and (t:IsA("LocalScript") or t:IsA("Script")) then
                    t.Enabled = true
                end
            end)
            tempScriptOff = false
        end
        notify("Anti-Freeze: " .. (v and "ON" or "OFF"), 2)
    end,
})
PlayerTab:CreateKeybind({
    Name = "Бинд Anti-Freeze",
    CurrentKeybind = "M",
    Flag = "RM_BindFreeze",
    Callback = function()
        freezeToggle:Set(not G.RM_AntiFreeze)
    end,
})

PlayerTab:CreateSection("Noclip")
local noclipToggle
noclipToggle = PlayerTab:CreateToggle({
    Name = "Noclip",
    CurrentValue = false,
    Callback = function(v)
        G.RM_Noclip = v
        if v then
            if noclipConn then noclipConn:Disconnect() noclipConn = nil end
            noclipConn = RunService.Stepped:Connect(function()
                if getgenv().RM_Run ~= RUN_ID then
                    -- re-run: коннект отписывается сам, иначе живёт вечно
                    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
                    return
                end
                pcall(function()
                    local ch = LP.Character
                    if ch then
                        for _, p in ipairs(ch:GetDescendants()) do
                            if p:IsA("BasePart") then
                                -- помним исходное значение: при выключении
                                -- вернём СВОИ коллизии, а не все подряд
                                if noclipSaved[p] == nil then
                                    noclipSaved[p] = p.CanCollide
                                end
                                if p.CanCollide then p.CanCollide = false end
                            end
                        end
                    end
                end)
            end)
            notify("Noclip ON — идёшь сквозь стены", 2)
        else
            if noclipConn then noclipConn:Disconnect() noclipConn = nil end
            pcall(function()
                for part, was in pairs(noclipSaved) do
                    if part.Parent then part.CanCollide = was end
                end
            end)
            noclipSaved = {}
            G.RM_NoclipSaved = noclipSaved -- alias для следующего прогона
            notify("Noclip OFF", 2)
        end
    end,
})
PlayerTab:CreateKeybind({
    Name = "Бинд Noclip",
    CurrentKeybind = "F",
    Flag = "RM_BindNoclip",
    Callback = function()
        noclipToggle:Set(not G.RM_Noclip)
    end,
})

PlayerTab:CreateSection("Прочее")
PlayerTab:CreateButton({
    Name = "Снять анкор (разморозка)",
    Callback = function()
        pcall(function()
            local ch = LP.Character
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            if hrp and hrp.Anchored then
                hrp.Anchored = false
                notify("Анкор снят", 2)
            else
                notify("Персонаж не заанкорен", 2)
            end
        end)
    end,
})

-- ===== Disable Static: глушение помех (паттерн Fullbright) =====
-- Ищем оверлеи помех (static/noise/vhs/glitch) в PlayerGui/CoreGui,
-- гасим Enabled и помечаем атрибутом RM_NoStatic (переживает re-run);
-- выключение и новый запуск возвращают всё, как было.
local function staticScan()
    pcall(function()
        local roots = { LP:FindFirstChildOfClass("PlayerGui"),
            game:GetService("CoreGui") }
        for _, root in ipairs(roots) do
            if root then
                for _, g in ipairs(root:GetDescendants()) do
                    if (g:IsA("GuiObject") or g:IsA("ScreenGui"))
                        and g.Enabled
                        and g:GetAttribute("RM_NoStatic") ~= true then
                        local n = string.lower(g.Name)
                        if (string.find(n, "static", 1, true)
                            or string.find(n, "noise", 1, true)
                            or string.find(n, "vhs", 1, true)
                            or string.find(n, "glitch", 1, true))
                            and string.sub(n, 1, 3) ~= "rm_" then -- свои не трогаем
                            g:SetAttribute("RM_NoStatic", true)
                            g.Enabled = false
                        end
                    end
                end
            end
        end
    end)
end
local function staticRestore()
    pcall(function()
        local roots = { LP:FindFirstChildOfClass("PlayerGui"),
            game:GetService("CoreGui") }
        for _, root in ipairs(roots) do
            if root then
                for _, g in ipairs(root:GetDescendants()) do
                    if g:GetAttribute("RM_NoStatic") == true then
                        g:SetAttribute("RM_NoStatic", nil)
                        g.Enabled = true
                    end
                end
            end
        end
    end)
end
-- новый запуск стартует с тоглом OFF — гасимое прошлым прогоном возвращаем
task.spawn(function()
    task.wait(1) -- даём старому прогону выйти по RUN_ID (гонка со сканом)
    if getgenv().RM_Run ~= RUN_ID then return end
    staticRestore()
end)
local staticGen = 0
PlayerTab:CreateToggle({
    Name = "Disable Static (глушить помехи)",
    CurrentValue = false,
    Callback = function(v)
        G.RM_NoStatic = v
        staticGen = staticGen + 1
        local gen = staticGen
        if not v then
            staticRestore()
            notify("Static: помехи возвращены", 2)
            return
        end
        notify("Static: глушу помехи (static/noise/vhs/glitch)", 3)
        task.spawn(function()
            local hinted = false
            -- помехи могут появляться заново (погоня) — скан каждую секунду
            while G.RM_NoStatic and gen == staticGen do
                if getgenv().RM_Run ~= RUN_ID then return end
                staticScan()
                if not hinted then
                    hinted = true
                    -- оверлеи с нашими именами не нашлись — скажи имя из
                    -- Explorer, добавлю паттерн
                    local marked = false
                    pcall(function()
                        local pg = LP:FindFirstChildOfClass("PlayerGui")
                        if pg then
                            for _, g in ipairs(pg:GetDescendants()) do
                                if g:GetAttribute("RM_NoStatic") == true then
                                    marked = true
                                    break
                                end
                            end
                        end
                    end)
                    if not marked then
                        notify("Static: оверлеи static/noise/vhs не найдены —"
                            .. " скажи реальное имя помех из Explorer", 6)
                    end
                end
                task.wait(1)
            end
        end)
    end,
})

PlayerTab:CreateSection("Автозабор")
-- без флага: значение живёт в getgenv до конца сессии (re-run
-- продолжает с последнего); слайдер опускается до 0.03
PlayerTab:CreateSlider({
    Name = "Скорость действий",
    Range = {0.03, 5},
    Increment = 0.01,
    Suffix = " s",
    CurrentValue = G.RM_ActionDelay,
    Callback = function(v)
        G.RM_ActionDelay = v
    end,
})

local pickToggle
pickToggle = PlayerTab:CreateToggle({
    Name = "Auto pickup",
    CurrentValue = false,
    Callback = function(v)
        G.RM_AutoPickup = v
        notify("Auto pickup: " .. (v and "ON" or "OFF"), 2)
    end,
})
pickDD = PlayerTab:CreateDropdown({
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

PlayerTab:CreateKeybind({
    Name = "Бинд Auto pickup",
    CurrentKeybind = "H",
    Flag = "RM_BindPick",
    Callback = function()
        pickToggle:Set(not G.RM_AutoPickup)
    end,
})

-- ================= вкладки по ночам =================
-- Ночь 1: провода + заправка генератора
-- Ночь 2: капсула PowerCell → генератор
-- Ночь 3: монстр → аимбот
local Night1 = Window:CreateTab("Ночь 1", 4483362458)

Night1:CreateSection("Генератор")
local fuelToggle
fuelToggle = Night1:CreateToggle({
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

Night1:CreateKeybind({
    Name = "Бинд Auto fuel",
    CurrentKeybind = "J",
    Flag = "RM_BindFuel",
    Callback = function()
        fuelToggle:Set(not G.RM_AutoFuel)
    end,
})

Night1:CreateSlider({
    Name = "Порог топлива",
    Range = {0, 100},
    Increment = 5,
    Suffix = " %",
    CurrentValue = G.RM_FuelThreshold,
    Flag = "RM_FuelThreshold",
    Callback = function(v)
        G.RM_FuelThreshold = v
    end,
})

Night1:CreateButton({
    Name = "Заправить сейчас (вручную)",
    Callback = function()
        if fuelManual() then
            notify("Заправка: еду за канистрой к генератору", 4)
        else
            notify("Идёт другое действие — подожди секунду", 3)
        end
    end,
})

Night1:CreateSection("Электрика")
Night1:CreateToggle({
    Name = "Auto electric",
    CurrentValue = false,
    Callback = function(v)
        G.RM_AutoElectric = v
        if v then
            -- чистое состояние на каждый включ (ящик/счётчики/кулдауны)
            fuseOpened = false
            wireTries = {}
            wireFixAt = {}
            elecWarned = false
            elecBrokenSeen = -1
            elecFried = nil
        end
        if v and typeof(fireclickdetector) ~= "function" then
            notify("Auto electric: в экзекуторе нет fireclickdetector", 5)
        else
            notify("Auto electric: " .. (v and "ON" or "OFF"), 2)
        end
    end,
})

Night1:CreateSection("Камин")
Night1:CreateButton({
    Name = "Подбросить дрова",
    Callback = function()
        if pickupBusy then
            notify("Занято — идёт другое действие", 2)
            return
        end
        local ch = LP.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if not hrp then
            notify("Нет персонажа", 2)
            return
        end
        local wp = workspace:FindFirstChild("WoodPile")
        local det = wp and wp:FindFirstChild("Detector", true)
        local cd = det and det:FindFirstChildWhichIsA("ClickDetector", true)
        if not cd then
            notify("Дровяная кучка не найдена", 3)
            print("[RM] камин: WoodPile/Detector/ClickDetector нет")
            return
        end
        local origin = hrp.CFrame
        local detWas = det:IsA("BasePart") and det.CanCollide or nil
        pickupBusy = true
        local ok, err = pcall(function()
            if det:IsA("BasePart") then det.CanCollide = false end
            -- точка возврата в getgenv: re-run посреди действия
            -- откатит персонажа сам (как автозабор)
            G.RM_TP_Origin = { cf = origin, place = game.PlaceId }
            smoothTP(hrp, CFrame.new(-27.149, 8.7, -118.612))
            task.wait(0.25)
            if getgenv().RM_Run ~= RUN_ID then return end
            fireclickdetector(cd)
            task.wait(0.25)
            if getgenv().RM_Run ~= RUN_ID then return end
            smoothTP(hrp, CFrame.new(-45.114, 7.85, -60.241))
            task.wait(0.5)
        end)
        -- вернуть коллизию дровяной кучки, какой она была (всегда:
        -- объект наш, а не персонажа — и мёртвому прогону это нужно)
        pcall(function()
            if detWas ~= nil and det:IsA("BasePart") then
                det.CanCollide = detWas
            end
        end)
        if getgenv().RM_Run == RUN_ID then
            -- живой прогон: возврат, снятие флага, ответ.
            -- мёртвый оставляет RM_TP_Origin — новый прогон откатит сам
            pcall(function() smoothTP(hrp, origin) end)
            G.RM_TP_Origin = nil
            pickupBusy = false
            if ok then
                notify("Дрова подброшены в камин", 2)
            else
                print("[RM] камин: " .. tostring(err))
                notify("Камин: ошибка — смотри консоль", 3)
            end
        end
    end,
})

Night1:CreateSection("Камера")
Night1:CreateToggle({
    Name = "Auto Scare (флешка при Ларри у окна)",
    CurrentValue = false,
    Callback = function(v)
        G.RM_AutoScare = v
        if v then
            if scareConn then scareConn:Disconnect() scareConn = nil end
            scareConn = workspace.ChildAdded:Connect(function(obj)
                if getgenv().RM_Run ~= RUN_ID then
                    -- re-run: подписка отписывается сам
                    if scareConn then scareConn:Disconnect() scareConn = nil end
                    return
                end
                if not G.RM_AutoScare then return end
                if obj.Name ~= "Mutant" then return end
                local inside = false
                pcall(function()
                    local cfg = obj:FindFirstChild("Config")
                    local w = cfg and cfg:FindFirstChild("Wandering")
                    inside = (w ~= nil and w.Value == false)
                end)
                if inside then
                    notify("Ларри у окна — флешка через 1.5с", 3)
                    task.delay(1.5, function()
                        if getgenv().RM_Run == RUN_ID and G.RM_AutoScare then
                            pcall(function()
                                local rf = game:FindFirstChild(
                                    "ReplicatedStorage")
                                rf = rf and rf:FindFirstChild("Remotes")
                                local fc = rf
                                    and rf:FindFirstChild("FlashCam")
                                if fc then fc:FireServer("1") end
                            end)
                        end
                    end)
                else
                    notify("Ларри появился снаружи", 3)
                end
            end)
            notify("Auto Scare ON (нужна установленная камера)", 3)
        else
            if scareConn then
                scareConn:Disconnect()
                scareConn = nil
            end
            notify("Auto Scare OFF", 2)
        end
    end,
})
-- общий кулдаун на «горячие» кнопки с FireServer: двойной клик или
-- зажатие не должны шлеть серию одинаковых вызовов — тот же риск
-- Error 267, что мы уже лечили у автозаправки. Ключ включает аргумент
-- (Repair/Delivery — это 4+4 РАЗНЫХ кнопки, у каждой свой кулдаун).
local fireAt = {}
local function fireThrottle(key)
    local now = os.clock()
    if fireAt[key] and now - fireAt[key] < 2 then
        notify("Подожди пару секунд между нажатиями (кулдаун 2с)", 1)
        return false
    end
    fireAt[key] = now
    return true
end

Night1:CreateButton({
    Name = "Флешнуть камеру",
    Callback = function()
        if not fireThrottle("FlashCam") then return end
        local ok, err = pcall(function()
            local rf = game:FindFirstChild("ReplicatedStorage")
            rf = rf and rf:FindFirstChild("Remotes")
            local fc = rf and rf:FindFirstChild("FlashCam")
            if not fc then error("нет ремоута FlashCam") end
            fc:FireServer("1")
        end)
        if ok then
            notify("Флешка (камера 1)", 2)
        else
            print("[RM] FlashCam: " .. tostring(err))
            notify("FlashCam: ошибка — смотри консоль", 3)
        end
    end,
})

local Night2 = Window:CreateTab("Ночь 2", 4483362458)
Night2:CreateSection("Генератор")
local cellToggle
cellToggle = Night2:CreateToggle({
    Name = "Auto PowerCell",
    CurrentValue = false,
    Callback = function(v)
        G.RM_AutoCell = v
        if v then
            cellTries = 0
            cellWarned = false
            cellGrabAt = -1e9
            cellTriedAt = -1e9
            notify("Auto PowerCell ON — капсула → генератор", 3)
        else
            notify("Auto PowerCell OFF", 2)
        end
    end,
})
Night2:CreateKeybind({
    Name = "Бинд PowerCell",
    CurrentKeybind = "K",
    Flag = "RM_BindCell",
    Callback = function()
        cellToggle:Set(not G.RM_AutoCell)
    end,
})

Night2:CreateSection("Ремоуты")
local function n2Fire(remoteName, ...)
    local args = { ... } -- ... нельзя брать внутри вложенной функции
    local ok, err = pcall(function()
        local rf = game:FindFirstChild("ReplicatedStorage")
        rf = rf and rf:FindFirstChild("Remotes")
        local r = rf and rf:FindFirstChild(remoteName)
        if not r then error("нет ремоута " .. remoteName) end
        r:FireServer(unpack(args))
    end)
    return ok, err
end
for i = 1, 4 do
    local n = tostring(i)
    Night2:CreateButton({
        Name = "Починить провод " .. n,
        Callback = function()
            if not fireThrottle("Repair" .. n) then return end
            local ok, err = n2Fire("Repair", n)
            if ok then
                notify("Провод " .. n .. ": отправлен (если RepairWorker жив)",
                    3)
            else
                print("[RM] Ночь 2 Repair: " .. tostring(err))
                notify("Repair: ошибка — смотри консоль", 3)
            end
        end,
    })
end
for _, item in ipairs({ "Camera", "Lock", "UVLamp", "MotionSensor" }) do
    local nm = item
    Night2:CreateButton({
        Name = "Доставка: " .. nm,
        Callback = function()
            if not fireThrottle("Delivery" .. nm) then return end
            local ok, err = n2Fire("Delivery", nm)
            if ok then
                notify("Доставка заказана: " .. nm, 2)
            else
                print("[RM] Ночь 2 Delivery: " .. tostring(err))
                notify("Delivery: ошибка — смотри консоль", 3)
            end
        end,
    })
end
Night2:CreateButton({
    Name = "Escape-Snatch (вырваться)",
    Callback = function()
        if not fireThrottle("EscapeSnatch") then return end
        local ok, err = n2Fire("EscapeSnatch")
        if ok then
            notify("Попытка вырваться", 2)
        else
            print("[RM] EscapeSnatch: " .. tostring(err))
            notify("Ошибка — смотри консоль", 3)
        end
    end,
})
Night2:CreateButton({
    Name = "Revive (воскрешение)",
    Callback = function()
        if not fireThrottle("LoadCharacter") then return end
        local ok, err = n2Fire("LoadCharacter")
        if ok then
            notify("Воскрешение...", 2)
        else
            print("[RM] LoadCharacter: " .. tostring(err))
            notify("Ошибка — смотри консоль", 3)
        end
    end,
})

local Night3 = Window:CreateTab("Ночь 3", 4483362458)
Night3:CreateSection("Аимбот")
Night3:CreateKeybind({
    Name = "Бинд аимбота (зажать)",
    CurrentKeybind = "C",
    HoldToInteract = true,
    Flag = "RM_BindAim",
    Callback = function(on)
        G.RM_AimMonster = (on == true)
    end,
})

Night3:CreateSection("Тревога кабины")
Night3:CreateToggle({
    Name = "Кто-то лезет в кабину",
    CurrentValue = false,
    Callback = function(v)
        G.RM_CabinAlert = v
        cabinGen = cabinGen + 1
        local gen = cabinGen
        if cabinConn then cabinConn:Disconnect() cabinConn = nil end
        if v then
            task.spawn(function()
                local rs = game:FindFirstChild("ReplicatedStorage")
                local remotes = rs and rs:FindFirstChild("Remotes")
                local rem = remotes and remotes:FindFirstChild("OpenDoor")
                if not rem and remotes then
                    rem = remotes:WaitForChild("OpenDoor", 10)
                end
                -- могли выключить/переключить тогл, пока ждали ремоут
                if not (G.RM_CabinAlert and gen == cabinGen) then return end
                if rem and rem:IsA("RemoteEvent") then
                    cabinConn = rem.OnClientEvent:Connect(function(plr, door)
                        if getgenv().RM_Run ~= RUN_ID then
                            -- re-run: подписка отписывается сам
                            if cabinConn then
                                cabinConn:Disconnect() cabinConn = nil
                            end
                            return
                        end
                        if plr == LP then return end -- свой вход — не тревога
                        local who = (typeof(plr) == "Instance" and plr:IsA("Player"))
                            and plr.Name or "Кто-то (возможно, бот)"
                        local what = (typeof(door) == "Instance") and door.Name or "дверь"
                        notify("Вторжение в кабину: " .. who
                            .. " открывает «" .. what .. "»", 4)
                    end)
                    notify("Тревога кабины: ON", 3)
                else
                    notify("Тревога кабины: RemoteEvent OpenDoor не найден", 3)
                end
            end)
        else
            notify("Тревога кабины: OFF", 2)
        end
    end,
})

Night3:CreateSection("Kid Detector")
G.RM_KidDetect = false -- без флага: всегда стартует выключенным
Night3:CreateToggle({
    Name = "Детект ребёнка (GhostChild)",
    CurrentValue = false,
    Callback = function(v)
        G.RM_KidDetect = v
        notify(v and "Kid Detector: ON" or "Kid Detector: OFF", 2)
    end,
})
-- движок kid detector (snippet ScriptBlox 55878): раз в секунду ищем
-- детей (GhostChild/kid) в workspace; новое появление — в консоль,
-- появление рядом (<60м) — уведомление. Имена — из gist «Night 3».
task.spawn(function()
    local known = {}
    while true do
        if getgenv().RM_Run ~= RUN_ID then return end
        if G.RM_KidDetect then
            pcall(function()
                local lpch = LP.Character
                local myHRP = lpch and lpch:FindFirstChild("HumanoidRootPart")
                local now = {}
                for _, d in ipairs(workspace:GetDescendants()) do
                    if d:IsA("Model") then
                        local n = string.lower(d.Name)
                        if string.find(n, "ghostchild", 1, true)
                            or string.find(n, "kid", 1, true) then
                            now[d] = true
                            if not known[d] then
                                local md = nil
                                pcall(function()
                                    if myHRP then
                                        md = (d:GetPivot().Position
                                            - myHRP.Position).Magnitude
                                    end
                                end)
                                local tag = md and (" [" .. math.floor(md) .. "м]") or ""
                                print("[RM] Kid Detector: " .. d.Name .. tag)
                                if md and md < 60 then
                                    notify("Ребёнок рядом: " .. d.Name
                                        .. " " .. math.floor(md) .. "м", 4)
                                end
                            end
                        end
                    end
                end
                for k in pairs(known) do
                    if not now[k] then
                        local okN, nm = pcall(function() return k.Name end)
                        print("[RM] Kid Detector: ушёл "
                            .. (okN and tostring(nm) or "?"))
                    end
                end
                known = now
            end)
        else
            known = {}
        end
        task.wait(1)
    end
end)

-- ================= вкладка ТП: точки из RM Helper =================
-- Координаты/имена объектов — из RM Helper (rawscripts). Летим
-- плавно через общий smoothTP (не рывком, как у них).
local TPTab = Window:CreateTab("ТП", 4483362458)

local function tpToPoint(cf)
    local ch = LP.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    if not hrp then
        notify("ТП: нет персонажа", 2)
        return
    end
    pcall(function() smoothTP(hrp, cf) end)
end

local function tpToNames(names, offset)
    offset = offset or Vector3.new(0, 5, 4)
    for _, name in ipairs(names) do
        local o = workspace:FindFirstChild(name)
        if o then
            local pos = nil
            pcall(function()
                if o:IsA("Model") and o.PrimaryPart then
                    pos = o.PrimaryPart.Position
                elseif o:IsA("BasePart") then
                    pos = o.Position
                else
                    local h = o:FindFirstChild("Handle")
                    if h then pos = h.Position end
                end
            end)
            if pos then
                tpToPoint(CFrame.new(pos + offset))
                return
            end
        end
    end
    notify("ТП: не нашёл «" .. tostring(names[1]) .. "»", 3)
end

-- gate: необязательная функция → ok, почему. Сырой CF чужой карты =
-- пустота (координаты между плейсами не пересекаются), поэтому «наши»
-- точки летят только со своего плейса/своей карты — иначе notify.
local function tpBtn(title, cf, gate)
    TPTab:CreateButton({
        Name = title,
        Callback = function()
            if gate then
                local ok, why = gate()
                if not ok then
                    notify("ТП: " .. tostring(why), 3)
                    return
                end
            end
            tpToPoint(cf)
        end,
    })
end
local function tpBtnNames(title, names, offset)
    TPTab:CreateButton({
        Name = title,
        Callback = function() tpToNames(names, offset) end,
    })
end

-- координаты: дом/фабрика из RM Helper, доп. точки из RMxploitt
local LOC = {
    home     = CFrame.new(-34.18, 9.54, -47.09),
    living   = CFrame.new(-30.45, 9.54, -48.73),
    bedroom  = CFrame.new(-26.48, 25.29, -70.10),
    bathroom = CFrame.new(-30.76, 25.26, -52.87),
    floor2   = CFrame.new(-3.90, 25.29, -71.19),
    ladder   = CFrame.new(-0.17, 9.29, -81.32),
    power    = CFrame.new(-1.48, 6.19, -95.05),
    oxygen   = CFrame.new(-79.69, 6.29, -127.54),
    elec     = CFrame.new(-79.09, 6.17, -132.72),
    safe1    = CFrame.new(-79.71, 21.27, -124.94),
    safe2    = CFrame.new(-15.41, 25.29, -53.18),
    n2stor   = CFrame.new(-73.50, 6.17, -125.30),
    n2tower  = CFrame.new(-95.80, 6.17, -100.50),
    n2office = CFrame.new(-60.30, 6.17, -110.40),
    sn2      = CFrame.new(-78.81, 19.27, -134.28),
    -- доп. точки Ночи 1 (RMxploitt)
    entrance = CFrame.new(-11.036, 7.73, -31.822),
    woodpile = CFrame.new(-27.149, 8.7, -118.612),
    fireplace= CFrame.new(-45.114, 7.85, -60.241),
    barricade= CFrame.new(-43.144, 25.3, -68.021),
    shackgen = CFrame.new(-76.039, 4.675, -133.78),
    -- Ночь 2, новая карта (RMxploitt, y≈82)
    n2main   = CFrame.new(-304.235, 82.4, -6.777),
    n2entr   = CFrame.new(-217.417, 82.4, 65.412),
    n2corr1  = CFrame.new(-303.846, 82.4, 50.169),
    n2corr2  = CFrame.new(-293.11, 82.4, -89.501),
    n2board  = CFrame.new(-282.224, 82.4, 14.674),
    n2safe   = CFrame.new(-339.321, 82.4, -40.622),
}

-- ==== гейты карт для сырых точек ====
-- Дом/завод (y≈6-26): только плейсы Ночи 1/Ночи 2; на Ночи 2 ещё и
-- по высоте персонажа — старая (y≈6-26) и новая (y≈82) карты не
-- сосуществуют в одном workspace. Бункер/лобби/Ночь 3 получают эти
-- координаты как «пустоту» — не летим.
local function gateOldFactory()
    local pid = game.PlaceId
    if pid ~= 14896802601 and pid ~= 16667550979 then
        return false, "точка дом/завод — только на плейсе Ночи 1/Ночи 2"
    end
    if pid == 16667550979 then
        local ch = LP.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if hrp and hrp.Position.Y > 40 then
            return false, "ты на НОВОЙ карте Ночи 2 — это точка старой"
        end
    end
    return true
end
-- Новая карта Ночи 2 (y≈82): только её плейс и только стоя на ней
local function gateNewN2()
    if game.PlaceId ~= 16667550979 then
        return false, "новая карта — только на плейсе Ночи 2"
    end
    local ch = LP.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    if hrp and hrp.Position.Y < 40 then
        return false, "ты на СТАРОЙ карте Ночи 2 — точки y≈82 туда не летят"
    end
    return true
end

TPTab:CreateSection("Ночь 1 — дом")
tpBtn("Дом (спавн)", LOC.home, gateOldFactory)
tpBtn("Гостиная", LOC.living, gateOldFactory)
tpBtn("Спальня", LOC.bedroom, gateOldFactory)
tpBtn("Ванная", LOC.bathroom, gateOldFactory)
tpBtn("Этаж 2", LOC.floor2, gateOldFactory)
tpBtn("Лестница", LOC.ladder, gateOldFactory)

TPTab:CreateSection("Ночь 1 — цели")
tpBtn("Пульт питания", LOC.power, gateOldFactory)
tpBtn("Кислородный генератор", LOC.oxygen, gateOldFactory)
tpBtn("Электрогенератор", LOC.elec, gateOldFactory)

TPTab:CreateSection("Ночь 1 — укрытия")
tpBtn("Укрытие 1 (крыша)", LOC.safe1, gateOldFactory)
tpBtn("Укрытие 2 (спальня)", LOC.safe2, gateOldFactory)

TPTab:CreateSection("Ночь 2 — завод")
-- их n2gen = те же координаты, что и наш Электрогенератор (старая карта)
tpBtn("Генератор (Ночь 2)", LOC.elec, gateOldFactory)
tpBtn("Склад питания", LOC.n2stor, gateOldFactory)
tpBtn("Радиовышка", LOC.n2tower, gateOldFactory)
tpBtn("Офис", LOC.n2office, gateOldFactory)
-- из RMUH (GitHub): панели давления (имя в workspace, иначе «не нашёл»)
tpBtnNames("PressurePanels", {"PressurePanels"}, Vector3.new(0, 5, 3))

TPTab:CreateSection("Ночь 2 — укрытие")
tpBtn("Укрытие (Ночь 2)", LOC.sn2, gateOldFactory)

TPTab:CreateSection("Ночь 2 — новая карта")
tpBtn("Главный зал", LOC.n2main, gateNewN2)
tpBtn("Вход", LOC.n2entr, gateNewN2)
tpBtn("Коридор 1", LOC.n2corr1, gateNewN2)
tpBtn("Коридор 2", LOC.n2corr2, gateNewN2)
tpBtn("Доска доставок", LOC.n2board, gateNewN2)
tpBtn("Укрытие (далеко)", LOC.n2safe, gateNewN2)

TPTab:CreateSection("Ночь 1 — доп. точки")
tpBtn("Вход в дом", LOC.entrance, gateOldFactory)
tpBtn("Дровяная кучка", LOC.woodpile, gateOldFactory)
tpBtn("Камин", LOC.fireplace, gateOldFactory)
tpBtn("Баррикады", LOC.barricade, gateOldFactory)
tpBtn("Генератор (Shack)", LOC.shackgen, gateOldFactory)
-- из frank590-star (Night 1, GitHub) и GitHubTestei
tpBtn("Сарай (Shack)", CFrame.new(-79, 4.5, -129), gateOldFactory)
tpBtn("Щиток (FuseBox)", CFrame.new(-1, 4.5, -92.5), gateOldFactory)
tpBtn("Вход с улицы", CFrame.new(-11.5, 4.6, -24.2), gateOldFactory)
tpBtn("Второй этаж (доски)", CFrame.new(-40, 23, -68), gateOldFactory)

TPTab:CreateSection("Ночь 3 — лагерь")
tpBtnNames("Лодж", {"Lodge", "MainLodge"}, Vector3.new(0, 5, 10))
tpBtnNames("Коттедж 1", {"Cabin1", "Cabin_1"})
tpBtnNames("Коттедж 2", {"Cabin2", "Cabin_2"})
tpBtnNames("Коттедж 3", {"Cabin3", "Cabin_3"})
tpBtnNames("Коттедж 4", {"Cabin4", "Cabin_4"})
tpBtnNames("Бункер", {"Bunker", "BunkerDoor"}, Vector3.new(0, 5, 10))
tpBtnNames("Костёр", {"Campfire", "Fireplace"})

TPTab:CreateSection("Ночь 3 — предметы")
tpBtnNames("Канистра", {"JerryCan", "GasCan"}, Vector3.new(0, 3, 3))
tpBtnNames("Дробовик", {"Shotgun"}, Vector3.new(0, 3, 3))
tpBtnNames("Патроны", {"Shell", "ShotgunShell"}, Vector3.new(0, 3, 3))
tpBtnNames("Bloxy Cola", {"BloxyCola"}, Vector3.new(0, 3, 3))
tpBtnNames("Мармеладка", {"Marshmallow"}, Vector3.new(0, 3, 3))
tpBtnNames("Фотоловушка", {"TrailCamera"}, Vector3.new(0, 3, 3))
tpBtnNames("Батарейка", {"Battery"}, Vector3.new(0, 3, 3))
tpBtnNames("WorkerHead", {"WorkerHead"}, Vector3.new(0, 3, 3))
tpBtnNames("Патроны (AmmoPiles)", {"AmmoPiles"}, Vector3.new(0, 3, 3))
-- тыквы из RMUH (Pumpkin_1..7.Spot): к ближайшей случайной
TPTab:CreateButton({
    Name = "Тыква (случайный Spot, Ночь 3)",
    Callback = function()
        local spots = {}
        for i = 1, 7 do
            local o = workspace:FindFirstChild("Pumpkin_" .. i)
            if o then
                pcall(function()
                    local s = o:FindFirstChild("Spot", true)
                    local pos = nil
                    if s and s:IsA("BasePart") then
                        pos = s.Position
                    elseif o:IsA("Model") and o.PrimaryPart then
                        pos = o.PrimaryPart.Position
                    end
                    if pos then spots[#spots + 1] = pos end
                end)
            end
        end
        if #spots == 0 then
            notify("Тыквы не найдены (это Ночь 3?)", 3)
            return
        end
        local p = spots[math.random(#spots)]
        tpToPoint(CFrame.new(p + Vector3.new(0, 3, 3)))
    end,
})

-- (точки укрытия Ночи 3 не было ни в одном исходнике — убрали
-- копипасту с safe1 Ночи 1)

TPTab:CreateSection("Spirit")
tpBtnNames("Кровать (спрятаться)", {"Bed", "PlayerBed"}, Vector3.new(0, 5, -6))
tpBtnNames("Лампа", {"Lamp", "LightSwitch"}, Vector3.new(0, 5, 3))
tpBtnNames("Шкаф", {"Closet", "Wardrobe"}, Vector3.new(0, 5, 3))
tpBtnNames("Мишка", {"Bear", "TeddyBear", "Teddy"}, Vector3.new(0, 5, 3))
tpBtnNames("Стол / часы", {"Desk", "Clock", "AlarmClock"}, Vector3.new(0, 5, 3))
tpBtnNames("Вентиляция", {"Vent", "AirVent"}, Vector3.new(0, 5, 3))
tpBtnNames("Приставка", {"Console", "GameConsole"}, Vector3.new(0, 5, 3))

TPTab:CreateSection("Mansion")
tpBtnNames("Чаша с конфетами", {"CandyBowl", "Bowl"}, Vector3.new(0, 5, 3))
tpBtnNames("Напольные часы", {"GrandfatherClock", "Clock"}, Vector3.new(0, 5, 3))
tpBtnNames("Камин", {"Fireplace"}, Vector3.new(0, 5, 5))
tpBtnNames("Подвал", {"Basement", "BasementDoor"}, Vector3.new(0, 5, 5))
tpBtnNames("Кухня", {"Kitchen"}, Vector3.new(0, 5, 5))
tpBtnNames("Столовая", {"DiningRoom", "Dining"}, Vector3.new(0, 5, 5))
tpBtnNames("Гостевая", {"GuestBedroom", "GuestRoom"}, Vector3.new(0, 5, 5))
tpBtnNames("Серая комната", {"GreyBedroom", "GreyRoom"}, Vector3.new(0, 5, 5))
tpBtnNames("Жёлтая комната", {"YellowRoom", "Catwalk"}, Vector3.new(0, 5, 5))
-- из RMUH (GitHub)
tpBtnNames("Haunted Mansion", { "HauntedMansion", "Haunted Mansion" },
    Vector3.new(0, 5, 10))
tpBtnNames("FakeCandyBag", {"FakeCandyBag"}, Vector3.new(0, 5, 3))

TPTab:CreateSection("Bunker")
tpBtnNames("Вход", {"Bunker", "BunkerDoor"}, Vector3.new(0, 5, 10))
tpBtnNames("Внутри", {"BunkerInside", "BunkerRoom"}, Vector3.new(0, 5, 5))
tpBtnNames("SafeSpot (бункер)", {"SafeSpot"}, Vector3.new(0, 5, 3))
-- Плейс «The Bunker» (100255403764514) и структуры — из Bunker Helper
-- V5 (pastefy). Сырые координаты работают ТОЛЬКО в этом плейсе, иначе
-- улетаешь в пустоту чужой карты — стопим через inBunker().
local function inBunker()
    if game.PlaceId == 100255403764514 then return true end
    notify("Это только в плейсе «The Bunker»", 3)
    return false
end
local function bunkerBtn(title, cf)
    TPTab:CreateButton({
        Name = title,
        Callback = function()
            if inBunker() then tpToPoint(cf) end
        end,
    })
end
bunkerBtn("Бункер: сейф-плейс", CFrame.new(-25.3077145, 25.9999943, -150.490356,
    -0.601064324, -1.01536057e-09, -0.799200654,
    1.33655895e-08, 1, -1.13224878e-08,
    0.799200654, -1.13224878e-08, -0.601064324))
bunkerBtn("Бункер: конец (6 утра)", CFrame.new(16.2996006, 16.9999943, 68.173172,
    -0.944833934, -4.709448836e-08, 0.327549726,
    -3.33766472e-08, 1, 4.75014801e-08,
    -0.327549726, 3.33766472e-08, -0.944833934))
bunkerBtn("Бункер: вентиляция (ТП)", CFrame.new(68.3592224, 16.9999943, 74.6261444,
    -0.999991238, -9.77371215e-08, 0.00418279972,
    -9.77379742e-08, 1, 2.32150453e-13,
    -0.00418279972, 4.09047467e-11, -0.999991238))
for i = 1, 4 do
    TPTab:CreateButton({
        Name = "Бункер: грид " .. i,
        Callback = function()
            if not inBunker() then return end
            local ok = pcall(function()
                local pg = workspace:FindFirstChild("PowerGrids")
                local g = pg and pg:FindFirstChild(tostring(i))
                local door = g and g:FindFirstChild("Door", true)
                if door and door:IsA("BasePart") then
                    tpToPoint(CFrame.new(door.Position + Vector3.new(0, 5, 0)))
                else
                    error("дверь грида не найдена")
                end
            end)
            if not ok then notify("Грид " .. i .. ": дверь не найдена", 3) end
        end,
    })
end
-- Чистка вентиляции: ТП к Debris → 7с кликов по ClickDetector-деталям
-- (как автопровод, только кликаем) → возврат. pickupBusy — общая блокировка.
TPTab:CreateButton({
    Name = "Бункер: почистить вентиляцию",
    Callback = function()
        if not inBunker() then return end
        if pickupBusy then notify("Уже занято (автозабор)", 2) return end
        pickupBusy = true
        task.spawn(function()
            local ch = LP.Character
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            if not hrp then pickupBusy = false return end
            local origin = hrp.CFrame -- точка возврата — как можно раньше
            -- возврат при re-run: новый прогон откатит персонажа сам
            G.RM_TP_Origin = { cf = origin, place = game.PlaceId }
            pcall(function()
                smoothTP(hrp, CFrame.new(68.3592224, 16.9999943, 74.6261444,
                    -0.999991238, -9.77371215e-08, 0.00418279972,
                    -9.77379742e-08, 1, 2.32150453e-13,
                    -0.00418279972, 4.09047467e-11, -0.999991238))
            end)
            task.wait(0.6)
            local untilAt = os.clock() + 7
            local stale = false
            while os.clock() < untilAt do
                if getgenv().RM_Run ~= RUN_ID then
                    -- re-run: НЕ делаем return мимо возврата — просто
                    -- выходим из цикла, а дальше «мёртвый» прогон сам
                    -- разберётся: он не трогает персонажа, а RM_TP_Origin
                    -- оставит новому прогону на откат
                    stale = true
                    break
                end
                pcall(function()
                    local v = workspace:FindFirstChild("Ventilation")
                    local d = v and v:FindFirstChild("Debris")
                    if d and typeof(fireclickdetector) == "function" then
                        for _, c in ipairs(d:GetChildren()) do
                            local cd = c:FindFirstChildOfClass("ClickDetector")
                            if cd then fireclickdetector(cd) end
                        end
                    end
                end)
                task.wait(0.15)
            end
            if stale then return end
            pcall(function() smoothTP(hrp, origin) end)
            G.RM_TP_Origin = nil
            pickupBusy = false
            notify("Вентиляция: debris обработан", 3)
        end)
    end,
})

-- ================= паника: случайное безопасное укрытие (бинд G) =================
-- Идея из ревью идей: при погоне — быстрый слёт в укрытие. Сырые
-- координаты чужой карты = пустота, поэтому свой список по плейсу,
-- для Ночи 2 ещё и по высоте (старая карта y≈6-26, новая y≈82),
-- для карт без своих точек (Ночь 3/лобби) — укрытие по имени.
local PANIC_N1 = {
    { "Укрытие 1 (крыша)", LOC.safe1 },
    { "Укрытие 2 (спальня)", LOC.safe2 },
}
local PANIC_N2_OLD = {
    { "Укрытие (Ночь 2)", LOC.sn2 },
    { "Укрытие 1 (крыша)", LOC.safe1 },
    { "Офис", LOC.n2office },
}
local PANIC_N2_NEW = {
    { "Укрытие (далеко)", LOC.n2safe },
    { "Вход (новая карта)", LOC.n2entr },
}
local PANIC_BUNKER = {
    { "Бункер: сейф-плейс", CFrame.new(-25.3077145, 25.9999943, -150.490356) },
}
local panicNames = { "Cabin4", "Cabin3", "Cabin2", "Cabin1", "Lodge",
    "Closet", "Wardrobe", "Bed" }

local function panicTP()
    if getgenv().RM_Run ~= RUN_ID then return end
    local ch = LP.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    if not hrp then
        notify("Паника: нет персонажа", 2)
        return
    end
    local pid = game.PlaceId
    local list = nil
    if pid == 14896802601 then
        list = PANIC_N1
    elseif pid == 16667550979 then
        -- карта Ночи 2 определяется высотой персонажа
        list = (hrp.Position.Y > 40) and PANIC_N2_NEW or PANIC_N2_OLD
    elseif pid == 100255403764514 then
        list = PANIC_BUNKER
    end
    if list and #list > 0 then
        local pick = list[math.random(#list)]
        pcall(function() smoothTP(hrp, pick[2]) end)
        if getgenv().RM_Run ~= RUN_ID then return end
        notify("Паника → " .. pick[1], 3)
        return
    end
    -- своих координат под эту карту нет — ищем укрытие по имени
    for _, name in ipairs(panicNames) do
        local o = workspace:FindFirstChild(name)
        if o then
            local pos = nil
            pcall(function()
                if o:IsA("Model") and o.PrimaryPart then
                    pos = o.PrimaryPart.Position
                elseif o:IsA("BasePart") then
                    pos = o.Position
                else
                    local h = o:FindFirstChild("Handle")
                    if h then pos = h.Position end
                end
            end)
            if pos then
                pcall(function()
                    smoothTP(hrp, CFrame.new(pos + Vector3.new(0, 5, 3)))
                end)
                if getgenv().RM_Run ~= RUN_ID then return end
                notify("Паника → " .. name, 3)
                return
            end
        end
    end
    notify("Паника: укрытий не нашёл", 3)
end

TPTab:CreateKeybind({
    Name = "Бинд паники (случайное укрытие)",
    CurrentKeybind = "G",
    Flag = "RM_BindPanic",
    Callback = function() panicTP() end,
})
TPTab:CreateButton({
    Name = "Паника: случайное укрытие",
    Callback = function() panicTP() end,
})

-- ================= вкладка ESP (только ESP) =================
-- Безопасное создание ColorPicker: у старой/чужой версии Rayfield
-- метода может не быть — раньше это роняло весь скрипт на первом же
-- пикере (всё после — Settings, маркер — пропадало).
local function mkPicker(parent, settings)
    if type(parent.CreateColorPicker) ~= "function" then
        notify("В этой версии Rayfield нет ColorPicker — цвета пропущены", 5)
        return
    end
    return parent:CreateColorPicker(settings)
end
-- Реестр колбэков цвета: ColorPicker:Set у Rayfield НЕ вызывает
-- Callback (в отличие от Toggle) — автозагрузка конфига (+4с)
-- подставляет цвет в GUI, а наше G.*/RM_Theme остаётся дефолтным.
-- На +5с прогоняем сохранённые цвета через эти же колбэки.
local colorResync = {} -- flagName -> колбэк
local function colorCb(flag, fn)
    colorResync[flag] = fn
    return fn
end

local ESP = Window:CreateTab("ESP", 4483362458)

ESP:CreateSection("Игроки")
ESP:CreateToggle({
    Name = "Player ESP",
    CurrentValue = G.RM_PlayerESP,
    Flag = "RM_PlayerESP",
    Callback = function(v)
        local old = G.RM_PlayerESP
        G.RM_PlayerESP = v
        if old ~= v then
            notify("Player ESP: " .. (v and "ON" or "OFF"), 2)
        end
    end,
})
mkPicker(ESP, {
    Name = "Player ESP color",
    Color = G.RM_PlayerColor,
    Flag = "RM_PlayerColor",
    Callback = colorCb("RM_PlayerColor", function(v)
        G.RM_PlayerColor = v
    end),
})

ESP:CreateSection("Монстры")
ESP:CreateToggle({
    Name = "Monster ESP",
    CurrentValue = G.RM_MonsterESP,
    Flag = "RM_MonsterESP",
    Callback = function(v)
        local old = G.RM_MonsterESP
        G.RM_MonsterESP = v
        if old ~= v then
            notify("Monster ESP: " .. (v and "ON" or "OFF"), 2)
        end
    end,
})
mkPicker(ESP, {
    Name = "Monster ESP color",
    Color = G.RM_MonsterColor,
    Flag = "RM_MonsterColor",
    Callback = colorCb("RM_MonsterColor", function(v)
        G.RM_MonsterColor = v
    end),
})
ESP:CreateToggle({
    Name = "Mutant ESP",
    CurrentValue = G.RM_MutantESP,
    Flag = "RM_MutantESP",
    Callback = function(v)
        local old = G.RM_MutantESP
        G.RM_MutantESP = v
        if old ~= v then
            notify("Mutant ESP: " .. (v and "ON" or "OFF"), 2)
        end
    end,
})
mkPicker(ESP, {
    Name = "Mutant ESP color",
    Color = G.RM_MutantColor,
    Flag = "RM_MutantColor",
    Callback = colorCb("RM_MutantColor", function(v)
        G.RM_MutantColor = v
        for _, e in ipairs(mutantCache) do
            pcall(function()
                e.hl.FillColor = v
                e.lbl.TextColor3 = v
            end)
        end
    end),
})
ESP:CreateSection("Предметы")
ESP:CreateToggle({
    Name = "Item ESP",
    CurrentValue = G.RM_ItemESP,
    Flag = "RM_ItemESP",
    Callback = function(v)
        local old = G.RM_ItemESP
        G.RM_ItemESP = v
        if old ~= v then
            notify("Item ESP: " .. (v and "ON" or "OFF"), 2)
        end
    end,
})
mkPicker(ESP, {
    Name = "Item ESP color",
    Color = G.RM_ItemColor,
    Flag = "RM_ItemColor",
    Callback = colorCb("RM_ItemColor", function(v)
        G.RM_ItemColor = v
    end),
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
        if getgenv().RM_Run ~= RUN_ID then return end
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


mkPicker(SettingsTab, {
    Name = "Акцент",
    Color = getgenv().RM_Theme.TabBackgroundSelected,
    Flag = "RM_ThemeAccent",
    Callback = colorCb("RM_ThemeAccent", function(c)
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
    end),
})

mkPicker(SettingsTab, {
    Name = "Фон окна",
    Color = getgenv().RM_Theme.Background,
    Flag = "RM_ThemeBg",
    Callback = colorCb("RM_ThemeBg", function(c)
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
    end),
})

mkPicker(SettingsTab, {
    Name = "Текст",
    Color = getgenv().RM_Theme.TextColor,
    Flag = "RM_ThemeText",
    Callback = colorCb("RM_ThemeText", function(c)
        setThemeKeys({
            TextColor = c,
            TabTextColor = c:Lerp(Color3.new(0, 0, 0), 0.25),
            SelectedTabTextColor = c,
        })
    end),
})

-- Конфиг Rayfield подгружается на +4с и зовёт ColorPicker:Set БЕЗ
-- Callback (Toggle'ы он дёргает, пикеры — нет): GUI показывает
-- сохранённый цвет, а G.*/RM_Theme остаются дефолтными до касания.
-- Прогоняем сохранённые цвета через наши же колбэки.
task.delay(5, function()
    if getgenv().RM_Run ~= RUN_ID then return end
    pcall(function()
        local flags = Rayfield.Flags
        if type(flags) ~= "table" then return end
        for flag, fn in pairs(colorResync) do
            local f = flags[flag]
            if f and f.Color then
                fn(f.Color)
            end
        end
    end)
end)

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


print("[RESIDENCE MASSACRE] v4.20 rayfield loaded | РЕВИЗИЯ: при re-run гасится старая библиотека Rayfield (старые бинды больше не дёргают новые тоглы), noclip возвращает коллизии и самоотписывается, scare/cabin-коннекты самоотписываются, guard'ы в «дровах»/вентиляции/панике + откат RM_TP_Origin, стартовый сброс RM_NoStatic | ГЕЙТЫ ТП: сырые точки другой карты (плейс+высота) больше не кидают в пустоту | КУЛДАУН 2с на кнопки FireServer (анти-двойной клик) | КОНФИГ: уведомления только при реальном изменении, цвета пикеров докручиваются на +5с, ColorPicker создаётся безопасно (нет метода — пропуск, а не смерть скрипта) | v4.19: Паника-ТП (G), Kid Detector, Disable Static, бункер-ТП | ESP | Settings")