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

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

-- Проверка на Residence Massacre убрана (v4.29, по запросу юзера): меню
-- и скрипт открываются в ЛЮБОЙ игре. Игровые фичи (генератор/провод/ящик,
-- автозабор и т.п.) сами ничего не найдут и молчат — автофичи выключены
-- по умолчанию; ТП-кнопки и паника по-прежнему защищены своими
-- плейс-гейтами: в чужой игре или чужой карте откажут уведомлением,
-- а не полётом в пустоту.

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
-- v4.37: ссылку гасим ТОЛЬКО при успешном Destroy — раньше она обнулялась
-- всегда, упавший Destroy оставлял старое окно живым навсегда (его бинды
-- работали параллельно с новыми, конфиг перезаписывался старыми Flags)
do
    local destroyed = false
    pcall(function()
        local oldLib = G.RM_RayfieldLib
        if oldLib and type(oldLib.Destroy) == "function" then
            oldLib:Destroy()
            -- Destroy() НЕ отменяет task.delay(4, RayfieldLibrary.LoadConfiguration)
            -- в исходнике Rayfield: таймер смотрит поля таблицы в момент вызова —
            -- глушим их, иначе при re-run в первые 4с старая библиотека прогрузит
            -- конфиг ПОСЛЕ старта нового прогона: колбэки старых элементов запишут
            -- флаги в общий getgenv, а Toggle:Set откатит файл конфига старыми
            -- значениями
            oldLib.LoadConfiguration = function() end
            oldLib.Flags = {}
            destroyed = true
        end
    end)
    if destroyed or G.RM_RayfieldLib == nil then
        G.RM_RayfieldLib = nil
    else
        warn("[RM] старое окно не уничтожено — ссылка осталась для повтора")
    end
end
-- 1b) Подписки старого прогона на события (Auto Scare / Тревога кабины):
-- они живут в локалах замыкания старого прогона и отписываются сами
-- ТОЛЬКО при следующем событии (а события может и не быть) — гасим явно
pcall(function()
    local a, b = G.RM_ScareConn, G.RM_CabinConn
    if typeof(a) == "RBXScriptConnection" then a:Disconnect() end
    if typeof(b) == "RBXScriptConnection" then b:Disconnect() end
    -- v4.37: подписка спавна Anti-Kick жила в локале старого прогона и
    -- отписывалась только на СЛЕДУЮЩЕМ CharacterAdded (а события может
    -- и не быть) — каждый re-run добавлял висячий обработчик
    local c = G.RM_KickConn
    if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
    -- v4.41: подписка мыши под-земли (колбэк глушен RUN_ID, но
    -- соединение жило бы вечно — утечка на каждый re-run)
    local u = G.RM_UnderInput
    if typeof(u) == "RBXScriptConnection" then u:Disconnect() end
end)
G.RM_ScareConn, G.RM_CabinConn = nil, nil
G.RM_KickConn = nil
G.RM_UnderInput = nil
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
-- 2c) Анти-лаг (Potato) переживал re-run: тогл всегда OFF на старте,
-- а детали остались Plastic — возвращаем по атрибутам RM_Pot* (v4.30)
pcall(function()
    for _, o in ipairs(workspace:GetDescendants()) do
        -- v4.37: атрибуты чистим внутри pcall (только при успешной
        -- записи) — иначе упавшая запись стирала исходное значение
        -- безвозвратно, и деталь навсегда оставалась Plastic
        if o:GetAttribute("RM_Pot") then
            pcall(function()
                o.Material = Enum.Material[
                    o:GetAttribute("RM_PotMat") or "Plastic"]
                o.Reflectance = o:GetAttribute("RM_PotRef") or 0
                o:ClearAttribute("RM_Pot")
                o:ClearAttribute("RM_PotMat")
                o:ClearAttribute("RM_PotRef")
            end)
        elseif o:GetAttribute("RM_PotT") then
            pcall(function()
                o.Transparency = o:GetAttribute("RM_PotTrans") or 0
                o:ClearAttribute("RM_PotT")
                o:ClearAttribute("RM_PotTrans")
            end)
        end
    end
    local t = workspace:FindFirstChildOfClass("Terrain")
    if t and t:GetAttribute("RM_PotW") then
        pcall(function()
            t.WaterReflectance = t:GetAttribute("RM_PotWr") or 1
            t.WaterWaveSize = t:GetAttribute("RM_PotWw") or 0.05
            t:ClearAttribute("RM_PotW")
            t:ClearAttribute("RM_PotWr")
            t:ClearAttribute("RM_PotWw")
        end)
    end
end)
-- 2b) Под-землю переживала re-run ещё хуже: кеш исходных коллизий
-- (st.noclipWas) жил в замыкании СТАРОГО прогона и был недостижим —
-- поднимать было нечем (п.1/215). Публикуем кеш в getgenv при
-- погружении; здесь поднимаем персонажа И возвращаем коллизии ОДНО-
-- ВРЕМЕННО (иначе можно застрять в грунте с включёнными коллизиями).
-- Подъём идёт лучом вверх от текущей точки — тот же столб земли,
-- которым персонаж и спускался; если персонажа ещё нет — кеш остаётся
-- в G, дочистит блок if G.RM_UnderActive ниже (фолбэк, если на старте
-- персонажа ещё нет)
pcall(function()
    local saved = G.RM_UnderWas
    if type(saved) == "table" then
        local ch = LP.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if hrp then
            local ok, gy = pcall(function()
                local rp = RaycastParams.new()
                rp.FilterType = Enum.RaycastFilterType.Exclude
                rp.FilterDescendantsInstances = {ch}
                local hit = workspace:Raycast(hrp.Position,
                    Vector3.new(0, 400, 0), rp)
                return hit and hit.Position.Y
            end)
            if ok and type(gy) == "number"
                and gy > hrp.Position.Y + 15 then
                hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                hrp.CFrame = CFrame.new(hrp.Position.X,
                    gy + 3, hrp.Position.Z)
                    * (hrp.CFrame - hrp.CFrame.Position)
                -- v4.37: подняли сами — фолбэк ниже (идёт через несколько
                -- секунд после HttpGet) поднимал ЕЩЁ РАЗ уже из новой
                -- точки и кидал персонажа на крышу; камеру гасим здесь же,
                -- иначе фолбэк (он же восстанавливал камеру) пропущен
                pcall(function()
                    local cam = workspace.CurrentCamera
                    if cam
                        and cam.CameraType == Enum.CameraType.Scriptable then
                        cam.CameraType = Enum.CameraType.Custom
                    end
                end)
                G.RM_UnderActive = false
            end
            for part, was in pairs(saved) do
                if part and part.Parent then part.CanCollide = was end
            end
            G.RM_UnderWas = nil
        end
    end
end)
-- 2d) v4.41: камеру под-земли возвращаем ЗДЕСЬ, а не в конце файла:
-- там блок восстановления идёт ПОСЛЕ CreateWindow (~6с yield'ов), а
-- при неудачной загрузке Rayfield файл делает ранний return — камера
-- оставалась Scriptable навсегда (мёртвый прогон её больше не дёргал,
-- обратно никто не ставил)
pcall(function()
    if G.RM_UnderActive then
        local cam = workspace.CurrentCamera
        if cam and cam.CameraType == Enum.CameraType.Scriptable then
            cam.CameraType = Enum.CameraType.Custom
        end
    end
end)
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
                -- v4.37: свип по «сигнатуре» сносил в CoreGui и ЧУЖИЕ
                -- Rayfield-хабы (у чужого окна та же пара Main/Topbar) —
                -- уничтожаем только по заголовку НАШЕГО окна (ELITE HUB)
                if isRF and getgenv().RM_Run > 1 then
                    local tm = g:FindFirstChild("Main", true)
                    tm = tm and tm:FindFirstChild("Topbar", true)
                    local ours = false
                    if tm then
                        pcall(function()
                            for _, d in ipairs(tm:GetDescendants()) do
                                if (d:IsA("TextLabel")
                                    or d:IsA("TextButton"))
                                    and type(d.Text) == "string"
                                    and string.find(d.Text, "ELITE HUB",
                                        1, true) then
                                    ours = true
                                    return
                                end
                            end
                        end)
                    end
                    if ours then g:Destroy() end
                end
            end
        end
    end
end)

-- ================= Anti-Kick (всегда при старте) =================
-- Глушим КЛИЕНТСКУЮ сторону кика: у ремоута Remotes.Kick отключаем все
-- локальные обработчики OnClientEvent (getconnections → Disconnect) —
-- клиентская кик-логика молчит. Серверный Kick с клиента не блокируется —
-- честное ограничение такого Anti-Kick. Повтор на каждом спавне.
-- v4.34: раньше было kick:Destroy() — Ночь 3 кикала с Error 267 сразу
-- после запуска скрипта (Ночи 1/2 были норм): её анти-чит ждёт, что
-- Remotes.Kick останется в дереве — у игрока с удалённым ремоутом (его
-- WaitForChild("Kick") зависал — это был «Infinite yield» из v4.24)
-- сервер читал поломку и рвал соединение. Ремоут больше НЕ удаляем.
local function antiKick()
    pcall(function()
        local rs = game:GetService("ReplicatedStorage")
        local remotes = rs:WaitForChild("Remotes", 10)
        local kick = remotes and remotes:FindFirstChild("Kick")
        if not kick then return end
        local n = 0
        if getconnections then
            pcall(function()
                for _, c in ipairs(getconnections(kick.OnClientEvent)) do
                    c:Disconnect()
                    n = n + 1
                end
            end)
        end
        print("[RM] Anti-Kick: обработчики Kick отключены — " .. n
            .. (n > 0 and "" or " (нет getconnections в экзекуторе?)")
            .. "; ремоут не удаляем (v4.34)")
    end)
end
task.spawn(antiKick) -- не блокируем старт скрипта, если Remotes грузится дольше
-- страховка: если игра пересоздаст подписки (respawn/смена места)
local kickConn
kickConn = LP.CharacterAdded:Connect(function()
    if getgenv().RM_Run ~= RUN_ID then
        if kickConn then kickConn:Disconnect() kickConn = nil end
        return
    end
    task.wait(2)
    if getgenv().RM_Run ~= RUN_ID then return end
    antiKick()
end)
G.RM_KickConn = kickConn -- v4.37: публикуем — re-run гасит явно (блок 1b)

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

-- п.192: окно паники-ТП — пока активно, автофичи не стартуют (игрока
-- только что спасли в укрытие — лететь за предметом = вытащить его
-- обратно), а автоматические телепорты (в т.ч. возвратные из автодействий)
-- не двигают персонажа. Паника и явные ТП-кнопки идут с force = true
local function panicIdle()
    return os.clock() >= (G.RM_PanicUntil or 0)
end

-- Возвращает true, только если долетели И скрипт не перезапускали:
-- после ожидания старый прогон при re-run обязан прекратить
-- свои действия — иначе два прогона тянут персонаж в разные точки.
local function smoothTP(hrp, cf, dur, force)
    -- v4.37: nil-гард САМЫМ ПЕРВЫМ — раньше разыменование hrp в расчёте
    -- dur шло ДО гарда (гард в конце был мёртвым кодом при hrp == nil)
    if not hrp or not hrp.Parent then return false end
    if getgenv().RM_Run ~= RUN_ID then return false end
    -- п.192: окно паники блокирует не-force телепорты — игрок остаётся
    -- в укрытии (возвраты автозабора/заправки/камена не откатывают его)
    if not force and not panicIdle() then return false end
    if not dur then
        local spd = tonumber(G.RM_TweenSpeed) or 500
        dur = math.clamp(
            (cf.Position - hrp.Position).Magnitude / spd, 0.05, 3)
    end
    local okDone = false
    pcall(function()
        -- п.220+192: новый твин отменяет предыдущий (ссылка общая в G):
        -- два твина на одном HRP дрались за CFrame (re-run, паника vs
        -- автозабор) — победитель был случаен
        local prev = G.RM_Tween
        if typeof(prev) == "Tween" then
            pcall(function() prev:Cancel() end)
        end
        local tw = TweenService:Create(hrp,
            TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            { CFrame = cf })
        G.RM_Tween = tw
        tw:Play()
        -- п.82/193: Completed:Wait() БЕЗ таймаута: при уничтоженном HRP
        -- событие может не прийти — поток бинда/цикла вис бы навсегда.
        -- Ждём не дольше длительности + запас (Cancel разбудит раньше)
        local t0 = os.clock()
        while tw.PlaybackState == Enum.PlaybackState.Playing
            and os.clock() - t0 < dur + 1 do
            task.wait(0.05)
        end
        okDone = tw.PlaybackState == Enum.PlaybackState.Completed
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
    -- v4.36: type() для CFrame даёт "userdata" — условие было истинно
    -- ВСЕГДА и откат RM_TP_Origin не работал ни разу; правим на typeof()
    if type(saved) ~= "table" or typeof(saved.cf) ~= "CFrame"
        or saved.place ~= game.PlaceId then
        G.RM_TP_Origin = nil
        return
    end
    pcall(function()
        local ch = LP.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if hrp then
            task.wait(1) -- даём новому прогону поднять GUI
            -- v4.36: точку снимаем ТОЛЬКО когда возврат случился —
            -- иначе (окно паники/отменённый твин) она остаётся в G
            -- и следующий re-run попробует снова
            if smoothTP(hrp, saved.cf) then
                G.RM_TP_Origin = nil
            end
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
    -- набор в чате / поиске Rayfield не должен двигать персонажа
    -- (IsKeyDown не знает про gameProcessed — спрашиваем фокус сам)
    if UIS:GetFocusedTextBox() then return 0, 0, 1 end
    if UIS:IsKeyDown(Enum.KeyCode.W) then z = z + 1 end
    if UIS:IsKeyDown(Enum.KeyCode.S) then z = z - 1 end
    if UIS:IsKeyDown(Enum.KeyCode.A) then x = x - 1 end
    if UIS:IsKeyDown(Enum.KeyCode.D) then x = x + 1 end
    local sprint = 1
    if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then sprint = 1.6 end
    return x, z, sprint
end

local walkConn, walkWarnAt = nil, 0
-- params рейкастов TP walk: раньше создавалось 2 штуки за кадр при
-- движении — держим один, пересоздаём только при смене персонажа
local walkParams, walkParamsCh = nil, nil
local function walkParamsFor(ch)
    if walkParamsCh ~= ch then
        walkParams = RaycastParams.new()
        walkParams.IgnoreWater = true
        walkParams.FilterDescendantsInstances = { ch }
        walkParamsCh = ch
    end
    return walkParams
end
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
        -- v4.36: диагональ W+D давала √2 скорости — нормируем пару
        -- (только когда её магнитуда > 1, чтобы не тормозить дробный ввод)
        local kx, kz = x, z
        local mag = math.sqrt(kx * kx + kz * kz)
        if mag > 1 then
            kx, kz = kx / mag, kz / mag
        end
        local stepVec = camFwd * kz * step + camRight * kx * step

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
            local params = walkParamsFor(ch)
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
            local params = walkParamsFor(ch)

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

        -- v4.36: при обрезанном в ноль шаге здесь каждый кадр писался
        -- идентичный CFrame — пишем только если позиция реально изменилась
        if (np - hrp.Position).Magnitude > 1e-4 then
            hrp.CFrame = CFrame.new(np) * (hrp.CFrame - hrp.CFrame.Position)
        end
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
                    -- v4.36: тогл выключили, пока шло обнаружение (1.2с) —
                    -- не присваиваем ссылку и не пишем в чужое значение
                    if not G.RM_StaminaLock then return end
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
-- re-run: прошлый прогон мог погасить Character.Temperature (LocalScript)
-- и уйти не выключив — возвращаем; персонаж может ещё грузиться,
-- поэтому с короткими повторами (только пока RUN_ID жив)
task.spawn(function()
    for _ = 1, 20 do
        if getgenv().RM_Run ~= RUN_ID then return end
        if not G.RM_TempScriptOff then return end
        local done = false
        pcall(function()
            local t = LP.Character
                and LP.Character:FindFirstChild("Temperature", true)
            if t and (t:IsA("LocalScript") or t:IsA("Script")) then
                t.Enabled = true
                G.RM_TempScriptOff = nil
                done = true
            end
        end)
        if done then return end
        task.wait(0.5)
    end
end)
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
                            G.RM_TempScriptOff = true -- переживает re-run
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
-- v4.37: кулдаун уведомления кабины (иначе nil-арифметика в обработчике)
local cabinLastAt = -1e9

-- Тревога двери (v4.30, из gueston): мутант у входной двери — на клиенте
-- слышен ров Growling на FrontDoor.SoundPart. Не conn, а нить-опрос:
-- нить сама гаснет по G.RM_DoorAlert/RUN_ID, re-run дочищает сам
G.RM_DoorAlert = false
local doorAlertGen = 0

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
        -- v4.36: при NumberValue 0/1 (ok=true, val≠true) раньше выходили
        -- здесь и атрибут (где честное true) уже не проверяли — статус
        -- «ДОГОНЯЕТ» в ESP молча не детектировался
        if ok and type(val) == "boolean" then return val end
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
    if kind == "memmonster" then return G.RM_MonsterColor end
    return G.RM_ItemColor
end

local function kindOn(kind)
    if kind == "player" then return G.RM_PlayerESP == true end
    if kind == "monster" then return G.RM_MonsterESP == true end
    -- «Monster» (Воспоминания): под ОДНИМ тоглом Monster ESP (v4.32 —
    -- юзер просил «1 нажать и всё подсвечивалось»)
    if kind == "memmonster" then return G.RM_MonsterESP == true end
    return G.RM_ItemESP == true
end

-- модель = игрок / монстр / ничего.
-- Мутанты пропускаются — их ведёт отдельная секция выше.
local function modelKind(m)
    if not m:IsA("Model") or not m.Parent then return nil end
    -- v4.36: модель, вынесенная из workspace (пулинг NPC в
    -- ReplicatedStorage при смене волн), оставалась «живой» в espCache
    -- навсегда — аимбот/«под землю» целились в фантома вне карты;
    -- gone-цикл сравнивает только Parent, поэтому фильтруем здесь
    if not m:IsDescendantOf(workspace) then return nil end
    local plr = Players:GetPlayerFromCharacter(m)
    if plr then
        if plr == LP then return nil end
        return "player"
    end
    -- «Monster» (Воспоминания): модель монстра БЕЗ Humanoid — только
    -- AnimationController, корень называется RootPart (v4.31, юзер-скрин)
    if string.lower(m.Name) == "monster" then return "memmonster" end
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

local lastItemScan = 0 -- момент последнего полного скана (дебаунс событий спавна)
local function scanItems()
    lastItemScan = os.clock()
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
        elseif d.Name == "WorkerHead"
            and (d:IsA("BasePart") or d:IsA("Model")) then
            -- голова рабочего (Ночь 3): предмет БЕЗ ClickDetector —
            -- ESP-метка по имени (из gueston); в автозабор не идёт
            -- (там гейт e.prompt or e.cd)
            if not interact[d] then interact[d] = {} end
            seen[d] = true
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
    -- сразу ресканим предметы, не ждём секундного скана. Но дебаунс:
    -- при массовом спавне (волнами) полный обход workspace за КАЖДЫЙ
    -- объект давал микрофризы 5–20мс; секундный тик scanEsp всё доберёт
    if obj:IsA("ClickDetector") or obj:IsA("ProximityPrompt")
        or obj.Name == "WorkerHead" then
        task.defer(function()
            if getgenv().RM_Run ~= RUN_ID then return end
            if os.clock() - lastItemScan < 0.5 then return end
            pcall(scanItems)
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

-- v4.39: убрали отдельный проход перед циклом — первая же итерация
-- делала ровно такой же скан до первого task.wait(1): на старте шло
-- 4 полных обхода workspace подряд (двойной микрофриз + удвоение
-- стоимости секундного скана)
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
            -- v4.39: ОДИН тип взаимодействия за проход (prompt
            -- предпочтительнее cd) и fired — ТОЛЬКО при успехе pcall:
            -- раньше шлись ОБА remote сразу и fired=true даже при
            -- упавшем pcall — до ~2 fire-вызовов/с + повторы (Error 267)
            fired = pcall(function() fireproximityprompt(e.prompt) end)
        end
    end
    if not fired and e.cd
        and typeof(fireclickdetector) == "function" then
        fired = pcall(function() fireclickdetector(e.cd) end)
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
        local raw = tostring(s)
        local ls = string.lower(raw)
        -- v4.37: Luau string.lower НЕ трогает кириллицу (только ASCII) —
        -- дефолтный «Все» оставалось с заглавной, не совпадало с «все»,
        -- и режим «Все» не собирал НИЧЕГО, пока не выберешь имена руками
        if ls == "all" or ls == "все" or raw == "Все" then return true end
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

    -- v4.37: погашенное взаимодействие не читалось НИГДЕ: Enabled=false
    -- или радиус 0 давали порог 2 стада → ОБЯЗАТЕЛЬНЫЙ ТП к «мёртвой»
    -- точке и fire впустую каждые ~10с (тот самый пинг-понг ТП)
    local dead = false
    pcall(function()
        if e.prompt and e.prompt.Enabled == false then dead = true end
        if e.cd and e.cd.Enabled == false then dead = true end
    end)
    if dead then
        e.clickAt = os.clock() + 15
        return
    end

    -- радиус активации: самый жёсткий из найденных взаимодействий
    local maxD = 32
    if e.prompt then maxD = math.min(maxD, e.prompt.MaxActivationDistance or 10) end
    if e.cd then maxD = math.min(maxD, e.cd.MaxActivationDistance or 32) end
    if maxD <= 0 then -- радиус 0 = взаимодействие погашено
        e.clickAt = os.clock() + 15
        return
    end
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
            -- v4.37: точку возврата пишем ДО твина (yield ~3с): раньше
            -- она писалась после guard'а re-run, и при re-run посреди
            -- твина новый прогон не находил точку — персонаж бросался
            -- у предмета навсегда (свой прогон при этом не кликал)
            if getgenv().RM_Run == RUN_ID then
                G.RM_TP_Origin = { cf = origin, place = game.PlaceId }
            end
            -- телепорт рядом с предметом: для сервера — «игрок стоял рядом».
            -- true только если долетели: после re-run smoothTP вернёт false
            teleported = smoothTP(hrp, CFrame.new(pos + Vector3.new(0, 3, 0))
                * (hrp.CFrame - hrp.CFrame.Position)) == true
            if not teleported and getgenv().RM_Run == RUN_ID then
                G.RM_TP_Origin = nil -- не телепортировались — точка лишняя
            end
        end
    end)
    -- после каждого yield — проверка re-run: старый прогон не кликает
    -- и не телепортирует (его pickupBusy — свой upvalue, новый он не трогает)
    if getgenv().RM_Run ~= RUN_ID then return end
    if teleported then task.wait(0.1) end -- позиция успевает дойти до сервера
    if getgenv().RM_Run ~= RUN_ID then return end
    pcall(function() fireItem(e) end)
    e.clickAt = os.clock() -- кулдаун по каждой цели — из слайдера «Скорость действий»
    -- цель не исчезла после клика (залипшая дверь/Prompt) — через 2.5с
    -- ставим длинный кулдаун, иначе телепорт-пинг-понг каждые ~0.5с
    task.delay(2.5, function()
        if getgenv().RM_Run == RUN_ID and e.inst and e.inst.Parent then
            -- v4.39: лимит попыток — цель «не берётся» вечно: раньше
            -- +10с на каждую попытку БЕСКОНЕЧНО (ТП туда-обратно каждые
            -- ~10с весь раунд); после 3 заходов — минута
            e.tries = (e.tries or 0) + 1
            e.clickAt = os.clock() + ((e.tries or 1) >= 3 and 60 or 10)
        end
    end)
    if teleported then
        task.wait(0.05)
        if getgenv().RM_Run ~= RUN_ID then return end
        -- v4.37: возврат без проверки = «бросание» у предмета, а точка
        -- всё равно стиралась — следующий прогон уже не откатывал;
        -- при неудаче (паника/re-run) точку оставляем для rollback'а
        local retOk = false
        pcall(function() retOk = smoothTP(hrp, origin) end)
        if retOk and getgenv().RM_Run == RUN_ID then
            G.RM_TP_Origin = nil
        end
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
            or string.find(low, "wrench", 1, true)
            -- v4.39: комментарий ниже обещал не трогать электрику, но
            -- матчился только wire/fuse/wrench: ящик/ключ в других
            -- написаниях (ElectricalBox, Ключ) автозабор телепортируясь
            -- всё равно щёлкал — чужая цель, гонки с Auto electric
            or string.find(low, "electr", 1, true)
            or string.find(low, "ключ", 1, true)
            or string.find(n.Name, "Ключ", 1, true) then
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
            if G.RM_AutoPickup and not pickupBusy and panicIdle() then
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
                            -- v4.39: канистру ведёт Auto fuel сама —
                            -- клик автозабора сбивал бы held/tookRecently
                            -- и дёргал цикл заправки (гонка фич)
                            and not string.find(string.lower(e.itemName or e.inst.Name),
                                "jerrycan", 1, true)
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
-- v4.39: ближайший к игроку и без деко-дублей (модель ВНУТРИ такой же
-- модели) — раньше возвращалась ПЕРВАЯ попавшаяся: авто-заправка летела
-- к деко-генератору на другом конце карты (клик впустую + пинг-понг ТП),
-- а fuelLevel снимал уровень не с того генератора (порог срабатывал не тогда)
local function findByModelName(sub)
    local low = string.lower(sub)
    local myPos = nil
    pcall(function()
        local hrp = LP.Character
            and LP.Character:FindFirstChild("HumanoidRootPart")
        if hrp then myPos = hrp.Position end
    end)
    local best, bestCd, bestD = nil, nil, nil
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Model")
            and string.find(string.lower(d.Name), low, 1, true) then
            local nested = false
            local p = d.Parent
            while p and p ~= workspace do
                if p:IsA("Model") and string.find(string.lower(p.Name),
                    low, 1, true) then
                    nested = true
                    break
                end
                p = p.Parent
            end
            local cd = d:FindFirstChildWhichIsA("ClickDetector", true)
            if cd then
                -- без персонажа дистанция неизвестна — берём первого
                -- (поведение как раньше)
                local dist = 0
                if myPos then
                    local okP, pv = pcall(function()
                        return d:GetPivot().Position
                    end)
                    dist = (okP and typeof(pv) == "Vector3")
                        and (pv - myPos).Magnitude or math.huge
                end
                -- «деко» (модель ВНУТРИ такой же) — только фолбэком:
                -- при наличии нормального кандидата не берём
                if nested then dist = dist + 1e6 end
                if bestD == nil or dist < bestD then
                    best, bestCd, bestD = d, cd, dist
                end
            end
        end
    end
    return best, bestCd
end

-- встать рядом с целью (если далеко) и нажать её
local function fuelPress(hrp, pos, cd)
    if not pos or not cd then return false end
    -- v4.37: проверка кликера САМОЙ ПЕРВОЙ (раньше стояла после ТП) —
    -- без fireclickdetector каждый тик уводил персонажа к цели и
    -- обратно, клик не шёл, счётчики не растут → вечный пинг-понг
    -- «канистра/капсула ↔ генератор», который не останавливал ни один
    -- стоп-бюджет
    if typeof(fireclickdetector) ~= "function" then
        if not fuelWarned then
            fuelWarned = true
            print("[RM] В экзекуторе нет fireclickdetector — авто-заправка не сможет нажимать")
        end
        return false
    end
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
    -- клик засчитываем только если он реально прошёл: иначе
    -- lastCanAt сбрасывается вхолостую
    return pcall(function() fireclickdetector(cd) end)
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
            if G.RM_AutoFuel and not pickupBusy and panicIdle() then
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
                        -- v4.39: точка возврата в getgenv (re-run посреди
                        -- рейса → новый прогон откатит; раньше цикл её
                        -- не писал вообще)
                        G.RM_TP_Origin = { cf = origin,
                            place = game.PlaceId }
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
                        -- возвращаемся всегда, даже после ошибки;
                        -- v4.39: точку снимаем ТОЛЬКО при удачном возврате
                        local backOk = false
                        pcall(function()
                            backOk = smoothTP(hrp, origin) == true
                        end)
                        if backOk and getgenv().RM_Run == RUN_ID then
                            G.RM_TP_Origin = nil
                        end
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
            -- v4.39: в getgenv — re-run посреди рейса → новый прогон
            -- откатит персонажа (раньше ручная заправка не писала точку)
            G.RM_TP_Origin = { cf = origin, place = game.PlaceId }
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
        -- возвращаемся всегда, даже после ошибки; v4.39: точку снимаем
        -- ТОЛЬКО при удачном возврате — иначе она стиралась и когда
        -- персонаж остался у цели (откат не работал)
        if hrp and origin then
            local backOk = false
            pcall(function() backOk = smoothTP(hrp, origin) == true end)
            if backOk and getgenv().RM_Run == RUN_ID then
                G.RM_TP_Origin = nil
            end
        end
        pickupBusy = false
        -- v4.37: ручная заправка не продлевала общий кулдаун — авто
        -- кликал генератор через ~0.7с после ручного (нарушение
        -- «≥3с между нажатиями генератора» = Error 267)
        lastFuelAt = os.clock()
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
local cellGenShown = nil -- последний выбранный генератор (для отладки)

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

-- генератор для ВСТАВКИ капсулы (Ночь 2): нужный слот —
-- Generator.Detector.ClickDetector (детектор вставки, со скриншота юзера),
-- а НЕ верхний ClickDetector модели. Моделей с "generator" в имени в
-- workspace может быть несколько (деко/старая карта) — берём кандидата
-- с Detector (ближайшего к игроку), без Detector — ближайший вообще.
local function findCellGen()
    local myPos = nil
    pcall(function()
        local hrp = LP.Character
            and LP.Character:FindFirstChild("HumanoidRootPart")
        myPos = hrp and hrp.Position
    end)
    local function pick(withDetector)
        local b, bcd, bd = nil, nil, nil
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("Model")
                and string.find(string.lower(d.Name), "generator", 1, true) then
                local det = d:FindFirstChild("Detector")
                local cd = det
                    and det:FindFirstChildWhichIsA("ClickDetector", true)
                if not withDetector then
                    cd = cd or d:FindFirstChildWhichIsA("ClickDetector", true)
                end
                if cd then
                    local pos = objPos(d)
                    local dist = (myPos and pos)
                        and (pos - myPos).Magnitude or 0
                    if not b or dist < bd then
                        b, bcd, bd = d, cd, dist
                    end
                end
            end
        end
        return b, bcd
    end
    local g, cd = pick(true) -- слот вставки = Generator.Detector
    if g then return g, cd end
    return pick(false)       -- запасной путь: любой ClickDetector
end

-- капсула внутри ЛЮБОЙ модели-генератор (их в workspace может быть
-- несколько) — такую не берём
local function insideAnyGen(d)
    local a = d:FindFirstAncestorWhichIsA("Model")
    while a do
        if string.find(string.lower(a.Name), "generator", 1, true) then
            return true
        end
        a = a:FindFirstAncestorWhichIsA("Model")
    end
    return false
end

-- свободная капсула: Model «PowerCell» с ClickDetector, НЕ внутри Generator
local function findLooseCell()
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Model")
            and string.find(string.lower(d.Name), "powercell", 1, true)
            and not insideAnyGen(d) then
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
            if G.RM_AutoCell and not pickupBusy and panicIdle() then
                local ch = LP.Character
                local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                if hrp then
                    -- капсула встала (свободной не осталось) — снимаем
                    -- прошлые неудачи. v4.37: сброс ПЕРЕД печатью стопа:
                    -- раньше порядок был обратный и счётчик от прошлой
                    -- ночи давал ложный «авто остановлено», после чего
                    -- цикл тут же продолжал работать
                    if not cell and cellTries > 0 then
                        cellTries = 0
                        cellWarned = false
                    end
                    if cell and cellTries >= 4 and not cellWarned then
                        cellWarned = true
                        print("[RM] Ночь 2: капсула не вставилась 4 раза — авто остановлено. "
                            .. "Включи заново после разбора и скажи, как вставляется вручную")
                    end
                    local gen, cdGen = findCellGen()
                    local cell, cdCell = findLooseCell()
                    -- отладка: один раз на каждый новый выбор — в консоли
                    -- видно, КАКОЙ генератор взят для вставки
                    if gen and gen:GetFullName() ~= cellGenShown then
                        cellGenShown = gen:GetFullName()
                        print("[RM] Ночь 2: слот вставки → " .. cellGenShown)
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
                            -- v4.37: первая вставка не раньше 2с после
                            -- взятия — сервер должен успеть зарепликать
                            -- подбор («клик+ТП раз в 0.5с» = Error 267)
                            and (now - cellGrabAt) >= 2

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
                                -- телепорт к СЛОТУ (Detector), а не к центру
                                -- модели: кликаем именно детектор вставки
                                local slot = objPos(cdGen.Parent) or objPos(gen)
                                local pressed = fuelPress(hrp, slot, cdGen)
                                cellTriedAt = os.clock()
                                -- 4 попытки жжём за ЛЮБУЮ попытку
                                -- вставки с кликом. v4.37: раньше только
                                -- «капсула в руках + клик» — если игра
                                -- не кладёт её в персонес, wasHeld всегда
                                -- false, бюджет не расходовался никогда и
                                -- цикл «капсула ↔ генератор» шёл бесконечно
                                if pressed then
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
local fuseOpened = false   -- намеренное состояние ящика (см. elecClickBox)
local wireFixAt = {}       -- [модель провода] = когда чинили (кулдаун 4с)
local wireTries = {}       -- [модель провода] = попыток; 2 → щёлкаем ящик
local wireReseat = {}      -- [модель провода] = пересадок ящика подряд (бэкофф)
local elecWireIdx = 0      -- v4.38: round-robin по битым проводам
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

-- п.89: toggle засчитывался по успеху КЛИЕНТСКОГО вызова (pcall лишь
-- значит «не упало») — сервер мог не изменить состояние, флаг расходился
-- с ящиком и питал вечный flip-flop (п.88). Теперь состояние = НАМЕРЕНИЕ:
-- mode "open" (дефолт) — один клик с намерением открыть; "reseat" —
-- щёлкнуть дважды (закрыть→открыть) одним рейсом, вернув намеренное
-- открытое состояние — шаг «2) открываем» перестаёт драться с шагом «3)»
local function elecClickBox(hrp, origin, mode)
    local box, bcd = elecFind("fusebox", true)
    if not bcd then return false end
    pickupBusy = true
    -- v4.38: точка возврата в getgenv — при re-run посреди рейса новый
    -- прогон откатит персонажа (раньше электрика вообще не писала
    -- G.RM_TP_Origin: зависший у ящика персонаж оставался навсегда)
    G.RM_TP_Origin = { cf = origin, place = game.PlaceId }
    local okB, errB = pcall(function()
        local pos = objPos(box)
        if pos then elecTP(hrp, pos, 2) end
        -- re-run во время полёта: старый прогон не щёлкает ящиком
        if getgenv().RM_Run ~= RUN_ID then return end
        if pcall(function() fireclickdetector(bcd) end) then
            if mode == "reseat" then
                fuseOpened = false -- намеренно закрыли
                task.wait(0.3)
                if getgenv().RM_Run ~= RUN_ID then return end
                if pcall(function() fireclickdetector(bcd) end) then
                    fuseOpened = true -- намеренно открыли
                end
            else
                fuseOpened = true -- намеренное «открыть»
            end
        end
        task.wait(0.3)
    end)
    -- возвращаемся всегда, даже после ошибки (респавн/исчез объект);
    -- v4.38: точку снимаем ТОЛЬКО при удачном возврате — иначе она
    -- стиралась и когда персонаж остался у ящика (откат не работал)
    local backOk = false
    pcall(function() backOk = smoothTP(hrp, origin) == true end)
    if backOk and getgenv().RM_Run == RUN_ID then
        G.RM_TP_Origin = nil
    end
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
            if G.RM_AutoElectric and not pickupBusy and panicIdle() then
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
                            wireReseat = {}
                            elecWireIdx = 0
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
                            -- v4.38: точка возврата в getgenv (re-run
                            -- посреди рейса → новый прогон откатит)
                            G.RM_TP_Origin = { cf = origin,
                                place = game.PlaceId }
                            local okW, errW = pcall(function()
                                local pos = objPos(giver)
                                if pos then elecTP(hrp, pos, 3) end
                                if getgenv().RM_Run ~= RUN_ID then return end
                                pcall(function() fireclickdetector(gcd) end)
                                task.wait(0.6) -- выдача инструмента
                            end)
                            wrenchGetAt = os.clock()
                            local backOk = false
                            pcall(function()
                                backOk = smoothTP(hrp, origin) == true
                            end)
                            if backOk and getgenv().RM_Run == RUN_ID then
                                G.RM_TP_Origin = nil
                            end
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

                        -- 3) чиним битый провод (кулдаун 4с на провод).
                        -- v4.38: round-robin — раньше всегда брался
                        -- broken[1]: «нечинящийся» первый провод лишал
                        -- помощи все остальные
                        local w = nil
                        for k = 1, #broken do
                            local idx = ((elecWireIdx + k - 1) % #broken) + 1
                            local cand = broken[idx]
                            if not wireFixAt[cand.model]
                                or (now - wireFixAt[cand.model]) > 4 then
                                w = cand
                                elecWireIdx = idx
                                break
                            end
                        end
                        if w then
                            if (wireTries[w.model] or 0) >= 2 then
                                -- дважды не берётся — возможно, ящик закрыт
                                -- или завис: пересаживаем его ОДНИМ рейсом
                                -- (закрыть→открыть) и пробуем провод снова;
                                -- флаг остаётся «открыт» — без flip-flop
                                -- между шагами «2) открываем» и «3)» (п.88)
                                wireTries[w.model] = 0
                                local rs = (wireReseat[w.model] or 0) + 1
                                wireReseat[w.model] = rs
                                if rs >= 3 then
                                    -- v4.38: 3 пересадки подряд без результата —
                                    -- провод явно не берётся; длинный бэкофф,
                                    -- иначе рейс к ящику крутится ВЕЧНО
                                    -- (TP пинг-понг + клики каждые ~10с)
                                    wireReseat[w.model] = 0
                                    wireFixAt[w.model] = os.clock() + 46
                                    print("[RM] Электрика: провод "
                                        .. w.model.Name
                                        .. " не берётся после 3 пересадок"
                                        .. " ящика — пауза ~50с")
                                else
                                    elecClickBox(hrp, hrp.CFrame, "reseat")
                                end
                            else
                                pickupBusy = true
                                local origin = hrp.CFrame
                                -- v4.38: точка возврата в getgenv
                                G.RM_TP_Origin = { cf = origin,
                                    place = game.PlaceId }
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
                                    -- v4.38: если FireServer упал — фолбэк на
                                    -- ClickDetector (раньше падение гасило
                                    -- клик молча: тик впустую, попытка сгорала)
                                    local sent = false
                                    if cr then
                                        sent = pcall(function()
                                            cr:FireServer(w.model)
                                        end)
                                    end
                                    if not sent and w.cd then
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
                                local backOk = false
                                pcall(function()
                                    backOk = smoothTP(hrp, origin) == true
                                end)
                                if backOk and getgenv().RM_Run == RUN_ID then
                                    G.RM_TP_Origin = nil
                                end
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
            or model:FindFirstChild("RootPart", true)
        if root then
            local d = (root.Position - myPos).Magnitude
            if d < bestD then best, bestD = root, d end
        end
    end
    for _, e in ipairs(espCache) do
        if e.kind == "monster" or e.kind == "memmonster" then
            consider(e.inst)
        end
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
                -- позицию ищем ТОЛЬКО у включённых категорий: раньше
                -- GetPivot/FindFirstChild считались каждый кадр и при
                -- выключенном ESP (лишние вызовы + GC 40-80 строк/кадр)
                local on = kindOn(e.kind)
                local show = false
                local pos = nil
                if on then
                    if e.kind == "item" then
                        -- pcall(fn, obj) без замыкания — аллокации меньше
                        local ok, cf = pcall(inst.GetPivot, inst)
                        if ok and cf then pos = cf.Position end
                    else
                        local root = inst:FindFirstChild("HumanoidRootPart")
                            or inst:FindFirstChild("Head")
                            or inst:FindFirstChild("RootPart")
                        if root then pos = root.Position end
                    end
                end
                local txt = nil
                if on and myHRP and pos then
                    local dist = (pos - myHRP.Position).Magnitude
                    local color = kindColor(e.kind)
                    if e.hl.FillColor ~= color then e.hl.FillColor = color end
                    if e.lbl.TextColor3 ~= color then e.lbl.TextColor3 = color end
                    if e.kind == "item" then
                        txt = ("%s [%dm]"):format(e.itemName or inst.Name, math.floor(dist))
                    elseif e.kind == "memmonster" then
                        -- у «Monster» нет Humanoid — HP не показываем
                        txt = ("%s [%dm]"):format(inst.Name, math.floor(dist))
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
    -- п.212: HttpGet — yield (1–5с). Пока старый прогон сидел в
    -- загрузке, мог пройти re-run: новый прогон уже сбросил
    -- G.RM_RayfieldLib и нарисует своё окно — старому нельзя ни
    -- дописывать G (2400), ни рисовать ВТОРОЕ окно (два меню) и
    -- затирать ссылку живой библиотеки мёртвой
    if getgenv().RM_Run ~= RUN_ID then
        pcall(function()
            if type(res) == "table"
                and type(res.Destroy) == "function" then
                res:Destroy()
            end
        end)
        return
    end
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
-- в getgenv, а не локалом: лимит 200 локальных на чанк (v4.38) —
-- точка отсчёта санити биндов от ЗАГРУЗКИ библиотеки, а не CreateWindow
G.RM_LibLoadedAt = os.clock()

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
    -- дефолтный хоткей Rayfield — K, а K у нас «Auto PowerCell»:
    -- без своего ключа одно нажатие и прятало окно, и переключало фичу.
    -- ПРАВИЛЬНО — только EnumItem: строку Rayfield прогоняет через
    -- string.upper ("RightShift" → "RIGHTSHIFT") и Enum.KeyCode[...] с
    -- неверным регистром кидает ошибку в CreateWindow — всё окно не
    -- создавалось (так и сломалось в v4.22). EnumItem-ветка пишет
    -- в конфиг keybind.Name ("RightShift") — как надо
    ToggleUIKeybind = Enum.KeyCode.RightShift,
})
-- v4.37: CreateWindow даёт ~5.7с yield'ов (первый запуск) — при re-run
-- в это время новое окно уже уничтожало старое; продолжать строить на
-- мёртвом окне = сиротские вкладки и InputBegan-бинды, которые Destroy
-- уже никогда не отключит (двойные срабатывания каждого бинда на весь сессион)
if getgenv().RM_Run ~= RUN_ID then
    pcall(function() Rayfield:Destroy() end)
    return
end

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
    -- подпись нашего окна — заголовок из Name CreateWindow; без неё
    -- поиск брал ПЕРВЫЙ попавшийся Rayfield (часто чужой хаб в CoreGui):
    -- ensureEliteProtection/keybindSweep/градиент мутировали ЧУЖОЙ GUI,
    -- а своё окно оставалось без ESC-защиты (v4.38; локалом вне чанка —
    -- лимит 200)
    local function guiIsOurs(g)
        local m = g:FindFirstChild("Main", true)
        local top = m and m:FindFirstChild("Topbar", true)
        if not top then return false end
        local ours = false
        pcall(function()
            for _, d in ipairs(top:GetDescendants()) do
                if (d:IsA("TextLabel") or d:IsA("TextButton"))
                    and type(d.Text) == "string"
                    and string.find(d.Text, "ELITE HUB", 1, true) then
                    ours = true
                    return
                end
            end
        end)
        return ours
    end

    local found = nil
    pcall(function()
        local containers = {CoreGuiSvc, LP:FindFirstChildOfClass("PlayerGui")}
        pcall(function()
            if type(gethui) == "function" then
                containers[#containers + 1] = gethui()
            end
        end)
        -- мелкий обход (дёшево): только окна с нашим заголовком
        for _, c in ipairs(containers) do
            if c then
                for _, g in ipairs(c:GetChildren()) do
                    if guiIsRayfield(g) and guiIsOurs(g) then
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
                        if guiIsRayfield(g) and guiIsOurs(g) then
                            found = g
                            break
                        end
                    end
                end
                if found then break end
            end
        end
        -- страховка (старое поведение): если заголовок не нашли — берём
        -- первый Rayfield-подобный: защита от ESC лучше её отсутствия
        if not found then
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

-- ==== бинды Rayfield: пустой бинд без ошибок и без ложных срабатываний ==
-- Триггер Rayfield: (RF 3291) input.KeyCode == Enum.KeyCode[CurrentKeybind].
-- Варианты «пустого» бинда и почему они НЕ работают:
--  * "None" → Enum.KeyCode["None"] кидает ошибку на КАЖДОМ вводе
--    (тот же механизм, что сломал ToggleUIKeybind в v4.22) — спам в консоли;
--  * "Unknown" → ловушка v4.26: для кликов ЛКМ/ПКМ/колесо и тапов Roblox
--    отдаёт input.KeyCode = Enum.KeyCode.Unknown (DevForum 4073073; и фильтр
--    RF 3277 в режиме захвата доказывает, что такие события приходят) →
--    КАЖДЫЙ клик совпадал и запускал все 10 биндов сразу;
--  * "ButtonX" (геймпад) → валидный KeyCode (ошибок нет), но клавиатура,
--    мышь и тап никогда не дают этот KeyCode — бинд по-настоящему пуст.
--    Назначение реальной клавиши кликом по боксу работает как обычно.
-- Витрину (Text бокса) возвращаем в «None» свипом — только по TextBox
-- с именем "KeybindBox", чтобы не трогать поиск по вкладкам.
-- Санити конфига (старые "None"/"Unknown"/мусор): проходы на +4.6/5.6/7.6с —
-- запас против гонки с task.delay(4, LoadConfiguration) у Rayfield (RF 4258);
-- кнопка «Сбросить бинды» в Settings.
local keybindCfgs = {} -- все cfg наших CreateKeybind (санити/сброс)

local function keybindSweep()
    pcall(function()
        if not eliteGui or not eliteGui.Parent then findEliteGui() end
        if not eliteGui then return end
        for _, d in ipairs(eliteGui:GetDescendants()) do
            if d:IsA("TextBox") and d.Name == "KeybindBox" then
                local t = d.Text
                if t == "Unknown" or t == "ButtonX" then
                    d.Text = "None" -- витрина: в cfg остаётся ButtonX
                end
            end
        end
    end)
end

local function shadowKeybind(tab)
    local orig = tab.CreateKeybind
    if type(orig) ~= "function" then return end
    tab.CreateKeybind = function(self, cfg)
        if type(cfg) == "table" then
            if cfg.CurrentKeybind == "None" then
                cfg.CurrentKeybind = "ButtonX"
            end
            keybindCfgs[#keybindCfgs + 1] = cfg
        end
        return orig(self, cfg)
    end
end

-- каждый Window:CreateTab проходит через обёртку — бинды чинятся во
-- ВСЕХ вкладках, включая создаваемые позже
do
    local origTab = Window.CreateTab
    if type(origTab) == "function" then
        Window.CreateTab = function(self, ...)
            -- v4.37: CreateTab тоже yield'ит (~0.1с на вкладку) — при
            -- re-run дальше строить на уничтоженном окне нельзя; мёртвому
            -- прогону возвращаем стаб, чтобы код ниже не упал по nil
            if getgenv().RM_Run ~= RUN_ID then
                local stub = {}
                setmetatable(stub, { __index = function()
                    return function() return stub end
                end })
                return stub
            end
            local tab = origTab(self, ...)
            pcall(shadowKeybind, tab)
            return tab
        end
    end
end

-- витрина → «None»: когда GUI собран (+1с)
task.delay(1, function()
    if getgenv().RM_Run ~= RUN_ID then return end
    keybindSweep()
end)
-- санити старого конфига: Rayfield грузит его на +4с (RF 4258) и мог
-- вернуть "None"/"Unknown" (ошибки ввода / ложные срабатывания) —
-- чистим тремя проходами против гонки на медленном чтении файла
local function keybindSanitize()
    for _, cfg in ipairs(keybindCfgs) do
        pcall(function()
            local v = cfg.CurrentKeybind
            local bad = false
            if type(v) ~= "string" or v == "None" or v == "Unknown"
                or v == "ScrollWheel"
                or string.sub(v, 1, 10) == "MouseButton" then
                bad = true
            else
                -- v4.37: белый список не ловил мусор из правленого руками
                -- конфига ("", "q", "RIGHTSHIFT") — Enum.KeyCode[мусор]
                -- кидает ошибку на КАЖДОМ вводе; валидность — через pcall
                local okE, enum = pcall(function()
                    return Enum.KeyCode[v]
                end)
                bad = (not okE) or enum == nil
            end
            if bad then cfg:Set("ButtonX") end
        end)
    end
    keybindSweep()
end
-- v4.37: проход сразу после сборки вкладок (конфиг мог вернуть невалидный
-- бинд ещё при создании элемента) + проход от tLib: LoadConfiguration
-- срабатывает через 4с от ЗАГРУЗКИ библиотеки, а не от CreateWindow —
-- раньше невалидный бинд жил ~5–6.5с (ошибки на каждом вводе; "Unknown"
-- запускал ВСЕ бинды на каждый клик — ловушка v4.26)
task.delay(1, function()
    if getgenv().RM_Run ~= RUN_ID then return end
    keybindSanitize()
end)
task.delay(math.max(0.1, 4.3 - (os.clock()
    - (G.RM_LibLoadedAt or os.clock()))), function()
    if getgenv().RM_Run ~= RUN_ID then return end
    keybindSanitize()
end)
for _, at in ipairs({4.6, 5.6, 7.6}) do
    task.delay(at, function()
        if getgenv().RM_Run ~= RUN_ID then return end
        keybindSanitize()
    end)
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
    CurrentKeybind = "None",
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
    CurrentKeybind = "None",
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
    CurrentKeybind = "None",
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
        if not v and (tempScriptOff or G.RM_TempScriptOff) then
            -- вернуть LocalScript Temperature, который мы погасили
            pcall(function()
                local ch = LP.Character
                local t = ch and ch:FindFirstChild("Temperature", true)
                if t and (t:IsA("LocalScript") or t:IsA("Script")) then
                    t.Enabled = true
                end
            end)
            tempScriptOff = false
            G.RM_TempScriptOff = nil
        end
        notify("Anti-Freeze: " .. (v and "ON" or "OFF"), 2)
    end,
})
PlayerTab:CreateKeybind({
    Name = "Бинд Anti-Freeze",
    CurrentKeybind = "None",
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
            local parts, partsAt = {}, 0 -- кеш частей: GetDescendants раз
            -- в 0.5с, а не 60 раз/с (и noclipSaved не копит мёртвые части)
            noclipConn = RunService.Stepped:Connect(function()
                if getgenv().RM_Run ~= RUN_ID then
                    -- re-run: коннект отписывается сам, иначе живёт вечно
                    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
                    return
                end
                pcall(function()
                    local ch = LP.Character
                    if ch then
                        if os.clock() - partsAt > 0.5 then
                            partsAt = os.clock()
                            table.clear(parts)
                            for _, d in ipairs(ch:GetDescendants()) do
                                if d:IsA("BasePart") then
                                    parts[#parts + 1] = d
                                end
                            end
                            -- v4.41: выкидываем записи о частях, которых
                            -- больше нет: при включённом Noclip через
                            -- респавн/смену раунда копились мёртвые
                            -- части — рост памяти за долгую сессию
                            for sp in pairs(noclipSaved) do
                                if not sp.Parent then
                                    noclipSaved[sp] = nil
                                end
                            end
                        end
                        for _, p in ipairs(parts) do
                            if p.Parent and p:IsA("BasePart") then
                                -- помним исходное значение: при выключении
                                -- вернём СВОИ коллизии, а не все подряд
                                if noclipSaved[p] == nil then
                                    -- п.141: под-землю уже выключила
                                    -- коллизию — оригинал лежит в её
                                    -- кеше (G.RM_UnderWas), берём его,
                                    -- а не текущее false
                                    local uw = G.RM_UnderWas
                                    if type(uw) == "table"
                                        and uw[p] ~= nil then
                                        noclipSaved[p] = uw[p]
                                    else
                                        noclipSaved[p] = p.CanCollide
                                    end
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
    CurrentKeybind = "None",
    Flag = "RM_BindNoclip",
    Callback = function()
        noclipToggle:Set(not G.RM_Noclip)
    end,
})

-- ================= под землю при опасности (вместо God Mode) ========
-- God Mode не спасал — сервер сам перезаписывает HP. Вместо него по
-- запросу юзера: монстр ближе радиуса (слайдер, 100 ст по умолчанию) →
-- персонаж УХОДИТ ПОД ЗЕМЛЮ. Камера и ходьба остаются прежними («для
-- себя ничего не изменилось»), а сервер видит персонажа глубоко под
-- поверхностью — монстр его не достаёт.
-- Механика: CameraType=Scriptable + орбита камеры над точкой персонажа
-- (XZ персонажа, Y = поверхность под ним); Y персонажа пинится каждый
-- кадр, на время ухода коллизии выключены (свой noclip с возвратом
-- исходных); XZ двигает штатный контроллер — WASD работает как обычно,
-- т.к. направление ввода считается от текущей (нашей) камеры.
-- Всплытие: монстр дальше радиуса + гистерезис 30 (или тогл OFF).
G.RM_Under = false              -- тогл (без флага: всегда OFF на старте)
G.RM_DangerR = G.RM_DangerR or 100 -- радиус опасности (слайдер с флагом)
local under = nil           -- состояние погружения: nil = на поверхности
local underScanAt = 0       -- последний скан опасности
local UNDER_DEPTH = 40      -- глубина под поверхностью, ст

-- ближайший монстр/мутант (кэши ESP заполняются всегда, тоглы ESP не
-- нужны — секундный scanEsp и mutant-скан крутятся с самого старта)
local function underNearest(fromPos)
    local best
    local function consider(inst)
        if not inst or not inst.Parent then return end
        local root = inst:FindFirstChild("HumanoidRootPart", true)
            or inst:FindFirstChild("Head", true)
            or inst:FindFirstChild("RootPart", true)
        if root then
            local d = (root.Position - fromPos).Magnitude
            if not best or d < best then best = d end
        end
    end
    for _, e in ipairs(espCache) do
        if e.kind == "monster" or e.kind == "memmonster" then
            consider(e.inst)
        end
    end
    for _, e in ipairs(mutantCache) do consider(e.model) end
    return best
end

local function underRay(pos, dir)
    local res = nil
    pcall(function()
        local p = RaycastParams.new()
        p.FilterType = Enum.RaycastFilterType.Exclude
        p.FilterDescendantsInstances = {LP.Character}
        local hit = workspace:Raycast(pos, dir, p)
        res = hit and hit.Position.Y
    end)
    return res
end

-- пол под ногами (на поверхности — луч вниз от груди)
local function underGroundY(pos)
    return underRay(pos, Vector3.new(0, -700, 0))
end

-- поверхность над головой (под землёй — луч вверх: первый потолок =
-- изнанка земли). Нужна, пока персонаж уже под землёй
local function underCeilY(pos)
    return underRay(pos, Vector3.new(0, 400, 0))
end

local function underFinish()
    local st = under
    if not st then return end
    under = nil
    G.RM_UnderActive = false
    -- вернуть свои коллизии (если не включён обычный Noclip — он со
    -- своим кешем восстановит сам)
    pcall(function()
        if not G.RM_Noclip then
            for part, was in pairs(st.noclipWas) do
                if part.Parent then part.CanCollide = was end
            end
        end
    end)
    pcall(function()
        local cam = workspace.CurrentCamera
        if st.prevCam then cam.CameraType = st.prevCam end
    end)
    G.RM_UnderWas = nil -- коллизии возвращены — кеш больше не нужен
    print("[RM] Под землю: всплытие")
end

local function underStart(hrp, cam)
    local gy = underGroundY(hrp.Position)
    if not gy then gy = hrp.Position.Y - 3 end
    local st = {
        char = LP.Character,
        groundY = gy,
        standOff = hrp.Position.Y - gy, -- высота стояния (для всплытия)
        curY = hrp.Position.Y,          -- пин-высота (переход к цели)
        diving = true,                  -- true = держимся под землёй
        noclipWas = {},                 -- исходные коллизии частей
        parts = {}, partsAt = 0,
        groundAt = 0, lastT = os.clock(),
        prevCam = cam and cam.CameraType,
        yaw = 0, pitch = 0.2, zoom = 14,
    }
    -- орбита из текущей камеры — без видимого скачка при погружении
    pcall(function()
        local dir = -cam.CFrame.LookVector
        st.pitch = math.asin(math.clamp(dir.Y, -1, 1))
        st.yaw = math.atan2(dir.X, dir.Z)
        st.zoom = math.clamp((cam.CFrame.Position
            - (hrp.Position + Vector3.new(0, 2.2, 0))).Magnitude, 6, 45)
    end)
    under = st
    G.RM_UnderActive = true
    -- п.1/215+141: кеш исходных коллизий публикуем в getgenv сразу —
    -- при re-run стартовый блок (2b) вернёт его, а Noclip при включении
    -- возьмёт оригинал из него, а не своё текущее false
    G.RM_UnderWas = st.noclipWas
    print("[RM] Под землю: погружение, глубина " .. UNDER_DEPTH .. " ст")
end

local function underFrame()
    -- self-disconnect при re-run: иначе прошлый прогон живёт вечно
    if getgenv().RM_Run ~= RUN_ID then
        pcall(function() RunService:UnbindFromRenderStep("RMUnderground") end)
        return
    end
    local okU, errU = pcall(function()
        local cam = workspace.CurrentCamera
        local ch = LP.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        local now = os.clock()
        if not hrp then
            if under then underFinish() end
            return
        end
        -- респавн под землёй: чистим состояние, скан переоценит угрозу
        if under and under.char ~= ch then underFinish() end

        -- авто-погружение/всплытие: скан каждые 0.35с
        if now - underScanAt > 0.35 then
            underScanAt = now
            local R = G.RM_DangerR or 100
            -- дистанция меряем от ТОЧКИ НА ПОВЕРХНОСТИ (ghost): монстр,
            -- стоящий над тобой, — это всё ещё опасно, под землёй мы
            local gp = under
                and Vector3.new(hrp.Position.X, under.groundY,
                    hrp.Position.Z)
                or hrp.Position
            local d = underNearest(gp)
            if not under and d and d < R then
                underStart(hrp, cam)
            elseif under and under.diving and (not d or d > R + 30) then
                under.diving = false -- монстр ушёл — всплываем
            elseif under and not under.diving and d and d < R then
                under.diving = true -- вернулся — снова вниз
            end
        end
        local st = under
        if not st then return end

        -- поверхность под точкой обновляем, пока под землёй (0.4с):
        -- земля неровная, ghost-камера идёт по рельефу
        if st.diving and now - st.groundAt > 0.4 then
            st.groundAt = now
            local gy = underCeilY(hrp.Position)
            if gy then st.groundY = gy end
        end

        local dt = math.min(now - st.lastT, 0.1) -- потолок на свитчах
        st.lastT = now

        -- цель Y: под землёй / поверхность + линейный переход
        local goalY = st.diving
            and (st.groundY - UNDER_DEPTH)
            or (st.groundY + st.standOff)
        local dy = goalY - st.curY
        local step = dt * 140 -- скорость ухода/всплытия (~0.3с)
        if math.abs(dy) <= step then
            st.curY = goalY
        else
            st.curY = st.curY + (dy > 0 and step or -step)
        end
        -- пин Y: гравитация тянет вниз, кадр держит высоту (XZ не
        -- трогаем — ими владеет штатный контроллер/WASD и твины ТП)
        local pos = hrp.Position
        if math.abs(pos.Y - st.curY) > 0.02 then
            local v = hrp.AssemblyLinearVelocity
            hrp.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
            hrp.CFrame = CFrame.new(pos.X, st.curY, pos.Z)
                * (hrp.CFrame - hrp.CFrame.Position)
        end

        -- сквозь землю: свои коллизии всё время состояния (кеш 0.5с,
        -- как у Noclip — не дёргаем GetDescendants каждый кадр)
        if now - st.partsAt > 0.5 then
            st.partsAt = now
            table.clear(st.parts)
            for _, dd in ipairs(ch:GetDescendants()) do
                if dd:IsA("BasePart") then
                    st.parts[#st.parts + 1] = dd
                end
            end
        end
        for _, pp in ipairs(st.parts) do
            if pp.Parent and pp:IsA("BasePart") then
                if st.noclipWas[pp] == nil then
                    -- п.141: Noclip уже выключил коллизию — оригинал
                    -- живёт в его кеше (G.RM_NoclipSaved), берём его,
                    -- а не текущее false (иначе после включения/выключения
                    -- Noclip посреди погружения коллизии отняты навсегда)
                    local ns = G.RM_NoclipSaved
                    if G.RM_Noclip and type(ns) == "table"
                        and ns[pp] ~= nil then
                        st.noclipWas[pp] = ns[pp]
                    else
                        st.noclipWas[pp] = pp.CanCollide
                    end
                end
                if pp.CanCollide then pp.CanCollide = false end
            end
        end

        -- камера: орбита над точкой персонажа (Y поверхности) —
        -- «для себя ничего не изменилось», мы просто смотрим сверху
        local tgt = Vector3.new(pos.X, st.groundY, pos.Z)
            + Vector3.new(0, 2.2, 0)
        local cp = math.cos(st.pitch)
        local dirv = Vector3.new(cp * math.sin(st.yaw),
            math.sin(st.pitch), cp * math.cos(st.yaw))
        cam.CameraType = Enum.CameraType.Scriptable
        cam.CFrame = CFrame.lookAt(tgt + dirv * st.zoom, tgt)

        -- всплыли полностью — полное восстановление
        if not st.diving and st.curY >= goalY - 0.01 then
            underFinish()
        end
    end)
    -- v4.41: раньше ошибка кадра глушилась пустым pcall — под-землю
    -- «просто переставала работать» без строки в консоли; печатаем
    -- один раз за прогон, чтобы не заливать лог каждый кадр
    if not okU and G.RM_UnderErr ~= RUN_ID then
        G.RM_UnderErr = RUN_ID
        print("[RM] под землю (кадр): " .. tostring(errU))
    end
end

-- мышь: тянем вид (колесо — зум), только пока под землёй и только когда
-- фокус не в чате/поиске (как у TP walk — не вращаем камеру при наборе)
local underM1
local function underInput(on)
    if underM1 then underM1:Disconnect() underM1 = nil end
    G.RM_UnderInput = nil -- v4.41: публикуем — re-run гасит явно (блок 1b)
    if not on then return end
    underM1 = UIS.InputChanged:Connect(function(inp, gp)
        if getgenv().RM_Run ~= RUN_ID or not G.RM_Under or not under then
            return
        end
        if gp then return end -- курсор над GUI — камеру не дёргаем
        if inp.UserInputType == Enum.UserInputType.MouseMovement then
            if UIS:GetFocusedTextBox() then return end
            under.yaw = under.yaw - inp.Delta.X * 0.004
            under.pitch = math.clamp(
                under.pitch + inp.Delta.Y * 0.004, -0.5, 1.35)
        elseif inp.UserInputType == Enum.UserInputType.MouseWheel then
            under.zoom = math.clamp(under.zoom - inp.Position.Z * 2.5, 6, 45)
        end
    end)
    G.RM_UnderInput = underM1
end

local function setUnder(on, silent)
    G.RM_Under = on == true
    if on then
        pcall(function()
            RunService:UnbindFromRenderStep("RMUnderground")
            -- приоритет Camera.Value: после штатной камеры и ДО аимбота
            -- (тот на +1 — его lookAt сохранит нашу позицию камеры)
            RunService:BindToRenderStep("RMUnderground",
                Enum.RenderPriority.Camera.Value, underFrame)
        end)
        underInput(true)
        if not silent then
            notify("Под землю: ON — монстр ближе "
                .. tostring(G.RM_DangerR or 100)
                .. " ст → уход под землю", 4)
        end
    else
        pcall(function() RunService:UnbindFromRenderStep("RMUnderground") end)
        underInput(false)
        -- п.140: ручной OFF посреди погружения — поднимаем персонажа
        -- на поверхность ДО underFinish: без пина гравитация тянет его
        -- вниз, и он залипает в грунте (или падает в пустоту)
        pcall(function()
            local st = under
            if st then
                local ch = LP.Character
                local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                if hrp and st.curY < st.groundY + st.standOff - 1 then
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    hrp.CFrame = CFrame.new(hrp.Position.X,
                        st.groundY + st.standOff, hrp.Position.Z)
                        * (hrp.CFrame - hrp.CFrame.Position)
                end
            end
        end)
        underFinish()
        if not silent then notify("Под землю: OFF", 2) end
    end
end

-- re-run: предыдущий прогон мог остаться под землёй (камера Scriptable,
-- персонаж ниже поверхности) — восстанавливаем ДО создания тогла
if G.RM_UnderActive then
    G.RM_UnderActive = false
    pcall(function()
        local cam = workspace.CurrentCamera
        if cam and cam.CameraType == Enum.CameraType.Scriptable then
            cam.CameraType = Enum.CameraType.Custom
        end
    end)
    pcall(function()
        local ch = LP.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if hrp then
            local gy = underCeilY(hrp.Position)
            if gy and gy > hrp.Position.Y + 15 then
                hrp.CFrame = CFrame.new(
                    hrp.Position.X, gy + 3, hrp.Position.Z)
            end
        end
    end)
    -- п.215: если на старте персонажа ещё не было (блок 2b не смог
    -- восстановить) — возвращаем коллизии из опубликованного кеша здесь
    pcall(function()
        local saved = G.RM_UnderWas
        if type(saved) == "table" then
            for part, was in pairs(saved) do
                if part and part.Parent then part.CanCollide = was end
            end
            G.RM_UnderWas = nil
        end
    end)
end

PlayerTab:CreateSection("Спасение от монстра")
PlayerTab:CreateToggle({
    Name = "Под землю при опасности (вместо God Mode)",
    CurrentValue = false,
    Callback = function(v) setUnder(v) end,
})
PlayerTab:CreateSlider({
    Name = "Радиус опасности",
    Range = {30, 300},
    Increment = 10,
    Suffix = " st",
    CurrentValue = G.RM_DangerR,
    Flag = "RM_DangerR",
    Callback = function(v)
        G.RM_DangerR = v
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
                            and string.sub(n, 1, 3) ~= "rm_" -- свои не трогаем
                            and not (eliteGui and g:IsDescendantOf(eliteGui))
                            then -- и собственное окно не гасим (иначе тогл не выключить)
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
    -- тогл успили включить за эту секунду — не мешаем новому скану
    -- (restore включил бы только что погашенные помехи → мерцание)
    if G.RM_NoStatic then return end
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
                        -- те же корни, что и в staticScan: он гасит помехи
                        -- и в PlayerGui, и в CoreGui — иначе подсказка
                        -- врала «не найдено» для overlay из CoreGui
                        local roots = { LP:FindFirstChildOfClass("PlayerGui"),
                            game:GetService("CoreGui") }
                        for _, root in ipairs(roots) do
                            if root then
                                for _, g in ipairs(root:GetDescendants()) do
                                    if g:GetAttribute("RM_NoStatic") == true then
                                        marked = true
                                        break
                                    end
                                end
                            end
                            if marked then break end
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
    CurrentKeybind = "None",
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
    CurrentKeybind = "None",
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

-- общий кулдаун на «горячие» кнопки с FireServer: двойной клик или
-- зажатие не должны слать серию одинаковых вызовов — тот же риск
-- Error 267, что мы уже лечили у автозаправки. Перенесён сюда выше
-- первых кнопок: лексический скоуп требует объявления ДО первого
-- Callback. П.157: Repair/Delivery делят ключ НА РЕМОУТ, не на аргумент:
-- сервер кулдаунит remote, а не его параметры — 8 кнопок подряд
-- рвали соединение (Error 267).
-- v4.37: кулдауны в getgenv — серверный кулдаун глобальный, а локальная
-- таблица умирала при re-run: первый же выстрел после перезапуска шёл
-- мгновенно (пара LoadCharacter быстрее 2с = Error 267)
local fireAt = G.RM_FireAt or {}
G.RM_FireAt = fireAt
-- silent=true — для автомата (радио/флешка/поездки фарма): иначе каждая
-- пропущенная попытка сыпала бы «Подожди пару секунд» в notify
local function fireThrottle(key, silent)
    local now = os.clock()
    if fireAt[key] and now - fireAt[key] < 2 then
        if not silent then
            notify("Подожди пару секунд между нажатиями (кулдаун 2с)", 1)
        end
        return false
    end
    fireAt[key] = now
    return true
end

Night1:CreateButton({
    Name = "Заправить сейчас (вручную)",
    Callback = function()
        -- п.136: кнопка шла мимо всех лимитеров — серия быстрых кликов =
        -- шквал FireServer (Error 267) и ложный «успех». Держим общий
        -- кулдаун авто-заправки и штампуем его, чтобы автофича не
        -- стартовала сразу после ручной
        if os.clock() - lastFuelAt < 3 then
            notify("Заправка: подожди пару секунд", 2)
            return
        end
        -- v4.43: преусловия ДО штампа — раньше неудачный проход
        -- (занято) жёг 2с кулдауна, и честное нажатие через 0.5с
        -- откатывалось «Подожди пару секунд»
        if pickupBusy then
            notify("Идёт другое действие — подожди секунду", 3)
            return
        end
        if not fireThrottle("FuelManual") then return end
        lastFuelAt = os.clock()
        if fuelManual() then
            notify("Заправка: еду за канистрой к генератору", 4)
        else
            notify("Идёт другое действие — подожди секунду", 3)
        end
    end,
})

-- из diddy (GitHub): магазин апгрейдов лежит в RS.Assets, лимиты
-- генератора — атрибуты RS.Upgrades.Generator. Клиентские правки
-- реплицируются не всегда — честный notify о результате
Night1:CreateButton({
    Name = "Бесплатные апгрейды (эксп.)",
    Callback = function()
        if not fireThrottle("Upgrades") then return end
        local genFound, moved = false, 0
        local upOk, errUp = pcall(function()
            local rs = game:FindFirstChild("ReplicatedStorage")
            local up = rs and rs:FindFirstChild("Upgrades")
            local gen = up and up:FindFirstChild("Generator")
            if gen then
                gen:SetAttribute("Max", 1e20)
                gen:SetAttribute("Price", 0)
                genFound = true
            end
            local assets = rs and rs:FindFirstChild("Assets")
            if assets then
                for _, nm in ipairs({"UpgradeShop", "Gambler"}) do
                    local m = assets:FindFirstChild(nm)
                    if m then
                        m.Parent = workspace
                        moved = moved + 1
                    end
                end
            end
        end)
        if not upOk then
            -- v4.43: ошибка раньше глушилась пустым pcall — notify
            -- врал «не найдено», хотя упало что-то другое
            print("[RM] апгрейды: " .. tostring(errUp))
            notify("Апгрейды: ошибка — смотри консоль", 3)
            return
        end
        if genFound then
            notify("Апгрейды: лимиты сняты (Max=∞, Price=0) — локально", 4)
            notify("Если сервер не доверяет клиенту, цену задаст он", 4)
        elseif moved > 0 then
            notify("Магазин апгрейдов показан локально", 3)
        else
            notify("ReplicatedStorage.Upgrades не найдено", 3)
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
        -- v4.36: единственная горячая кнопка зоны мимо лимитера —
        -- серия нажатий быстрее 2с = Error 267; v4.43: штамп ПОСЛЕ
        -- преусловий — «нет персонажа»/«кучка не найдена» раньше
        -- жгли 2с впустую
        if not fireThrottle("Fireplace") then return end
        local origin = hrp.CFrame
        local detWas = det:IsA("BasePart") and det.CanCollide or nil
        pickupBusy = true
        local ok, err = pcall(function()
            if det:IsA("BasePart") then det.CanCollide = false end
            -- точка возврата в getgenv: re-run посреди действия
            -- откатит персонажа сам (как автозабор)
            G.RM_TP_Origin = { cf = origin, place = game.PlaceId }
            -- v4.36: ТП без проверки = клик «с пола» и ложный успех
            if not smoothTP(hrp, CFrame.new(-27.149, 8.7, -118.612)) then
                error("телепорт к дровам не прошёл (паника/re-run?)")
            end
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
            -- v4.36: точку снимаем только когда возврат реально случился
            -- (неудачный ТП = персонаж у дров, откатит следующий re-run)
            local retOk = false
            pcall(function() retOk = smoothTP(hrp, origin) end)
            if retOk then
                G.RM_TP_Origin = nil
            end
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

-- запуск целей Ночи 1: из prolover (Night 1) — ТП к радио и клики до
-- GameState.Active. pickupBusy-гвард + возврат на место как у камина
Night1:CreateSection("Старт ночи")
Night1:CreateButton({
    Name = "Запустить цели (радио)",
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
        local rs = game:FindFirstChild("ReplicatedStorage")
        local gs = rs and rs:FindFirstChild("GameState")
        local act = gs and gs:FindFirstChild("Active")
        local radio = workspace:FindFirstChild("Radio")
        local cd = radio and radio:FindFirstChild("ClickDetector")
        if not (act and act:IsA("BoolValue")) then
            notify("GameState.Active не найден — это не Ночь 1?", 3)
            return
        end
        if act.Value then
            notify("Цели уже активны", 2)
            return
        end
        if not cd then
            notify("Радио не найдено — не та карта?", 3)
            return
        end
        -- v4.43: штамп ПОСЛЕ преусловий (как камин) — любая проверка
        -- выше раньше жгла кулдаун, и честный повтор откатывался
        if not fireThrottle("Radio") then return end
        local origin = hrp.CFrame
        pickupBusy = true
        local started = false
        local ok, err = pcall(function()
            G.RM_TP_Origin = { cf = origin, place = game.PlaceId }
            -- v4.36: ТП без проверки = 12с холостых кликов издалека
            if not smoothTP(hrp, CFrame.new(-34.3541336, 7.79997444, -58.3701172,
                0.619202912, -3.47004629e-08, -0.785230994,
                5.68393368e-08, 1, 6.29901742e-10,
                0.785230994, -4.50220448e-08, 0.619202912)) then
                error("телепорт к радио не прошёл (паника/re-run?)")
            end
            local t0 = os.clock()
            while os.clock() - t0 < 12 do
                if getgenv().RM_Run ~= RUN_ID then return end
                if act.Value then
                    started = true
                    break
                end
                -- v4.36: раньше жали каждые 0.5с до 24 раз подряд мимо
                -- лимитера (шквал FireServer = Error 267) — через throttle
                -- (silent: цикл не должен сыпать notify на каждом промахе)
                if fireThrottle("RadioTick", true) then
                    fireclickdetector(cd)
                end
                task.wait(0.5)
            end
            if act.Value then started = true end
        end)
        -- v4.36: точку снимаем только при удачном возврате и своём прогоне
        local retOk = false
        pcall(function() retOk = smoothTP(hrp, origin) end)
        if retOk and getgenv().RM_Run == RUN_ID then
            G.RM_TP_Origin = nil
        end
        pickupBusy = false
        if getgenv().RM_Run == RUN_ID then
            if ok and started then
                notify("Цели Ночи 1 запущены", 3)
            elseif ok then
                notify("Радио молчит — цели не стартовали", 3)
            else
                print("[RM] радио: " .. tostring(err))
                notify("Радио: ошибка — смотри консоль", 3)
            end
        end
    end,
})

Night1:CreateSection("Погода")
-- re-run: тогл всегда OFF на старте, а локально выключенная метель
-- осталась бы — возвращаем исходное значение один раз при загрузке
pcall(function()
    local rs = game:FindFirstChild("ReplicatedStorage")
    local gs = rs and rs:FindFirstChild("GameState")
    local bl = gs and gs:FindFirstChild("Blizzard")
    if bl and bl:IsA("BoolValue") then
        if G.RM_BlizzardWas ~= nil and bl.Value ~= G.RM_BlizzardWas then
            bl.Value = G.RM_BlizzardWas
        end
        -- v4.36: кэш сбрасывался ДАЖЕ когда Blizzard не найден (карта не
        -- реплицирована) — локально выключенная метель оставалась
        -- выключенной навсегда, повторной попытки восстановления нет
        G.RM_BlizzardWas = nil
    end
end)
Night1:CreateToggle({
    Name = "Отключить метель (Blizzard)",
    CurrentValue = false,
    Callback = function(v)
        local bl = nil
        pcall(function()
            local rs = game:FindFirstChild("ReplicatedStorage")
            local gs = rs and rs:FindFirstChild("GameState")
            local b = gs and gs:FindFirstChild("Blizzard")
            if b and b:IsA("BoolValue") then bl = b end
        end)
        if not bl then
            notify("Метель: GameState.Blizzard не найден", 3)
            return
        end
        if v then
            if G.RM_BlizzardWas == nil then
                G.RM_BlizzardWas = bl.Value
            end
            bl.Value = false
            notify("Метель: OFF (локально)", 2)
        else
            -- v4.36: `A and B or C` при B == false давал true —
            -- «как было» ВКЛЮЧАЛО метель, которой не было
            if G.RM_BlizzardWas ~= nil then
                bl.Value = G.RM_BlizzardWas
            else
                bl.Value = true
            end
            G.RM_BlizzardWas = nil
            notify("Метель: как было", 2)
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
            -- v4.43: общий обработчик — и для ChildAdded, и для уже
            -- существующего Mutant: включение тогла посреди волны
            -- раньше не видело его вплоть до следующего спавна
            local function onMutant(obj)
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
                        -- v4.36: авто-флешка шла мимо лимитера и гонялась
                        -- с ручной кнопкой (два FireServer("1") быстрее 2с
                        -- = Error 267); ChildAdded плодил параллельные delay
                        if getgenv().RM_Run == RUN_ID and G.RM_AutoScare
                            and fireThrottle("FlashCam", true) then
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
            end
            scareConn = workspace.ChildAdded:Connect(function(obj)
                if getgenv().RM_Run ~= RUN_ID then
                    -- re-run: подписка отписывается сам
                    if scareConn then scareConn:Disconnect() scareConn = nil end
                    return
                end
                if not G.RM_AutoScare then return end
                onMutant(obj)
            end)
            G.RM_ScareConn = scareConn -- блок старта гасит его при re-run
            -- v4.43: Mutant мог быть уже на месте (тогл включён
            -- посреди волны) — ChildAdded его не видит
            local exist = nil
            pcall(function() exist = workspace:FindFirstChild("Mutant") end)
            if exist then onMutant(exist) end
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
    CurrentKeybind = "None",
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
            if not fireThrottle("Repair") then return end
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
            if not fireThrottle("Delivery") then return end
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
-- п.163: dupBusy объявлен ДО Revive: Revive посреди идущей серии =
-- пара LoadCharacter быстрее кулдауна (Error 267) — серия первична,
-- Revive ждёт её конца
local dupBusy = false
Night2:CreateButton({
    Name = "Revive (воскрешение)",
    Callback = function()
        if dupBusy then
            notify("Идёт серия дюпа — подожди её конца", 2)
            return
        end
        -- v4.37: респавн посреди ТП автозабора/поездки фарма ломал
        -- всё: клик уходил со спавна, возврат шёл на мёртвый HRP
        if pickupBusy or not panicIdle() then
            notify("Идёт другое действие — подожди", 2)
            return
        end
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

-- ================= дюп предметов (по механике юзера) ===============
-- Юзер сам нашёл дюп: каждое воскрешение (ремоут LoadCharacter)
-- дублирует предметы — новый набор выдаётся снова, старый остаётся.
-- Оформляем отдельной кнопкой-серийой: N повторов с паузой 2.5с
-- (> кулдауна fireThrottle 2с — иначе шквал FireServer = Error 267).
-- Серия идёт в task.spawn: GUI не блокируется, повторная кнопка
-- не пускает вторую серию (dupBusy).
G.RM_DupN = math.clamp(G.RM_DupN or 5, 1, 10) -- повторов (слайдер)

-- UI дюпа общий для всех трёх ночей (по просьбе юзера — «добавь во
-- все ночи»). Без Flag: три слайдера с одним флагом конфликтуют бы в
-- конфиге, а G.RM_DupN переживает re-run через getgenv (сброс —
-- только перезапуском Roblox).
local function makeDupUI(tab)
    tab:CreateSection("Дюп предметов")
    tab:CreateSlider({
        Name = "Повторов дюпа",
        Range = {1, 10},
        Increment = 1,
        CurrentValue = G.RM_DupN,
        Callback = function(v)
            G.RM_DupN = v
        end,
    })
    tab:CreateButton({
        Name = "Дюп предметов (серия воскрешений)",
        Callback = function()
            if dupBusy then
                notify("Дюп: серия уже идёт", 2)
                return
            end
            -- v4.37: серия респавнов посреди автодействий = сломанные
            -- ТП/клики соседних фич — ждём их конца (как они ждут нас)
            if pickupBusy or not panicIdle() then
                notify("Идёт другое действие — подожди", 2)
                return
            end
            local n = math.clamp(G.RM_DupN or 5, 1, 10)
            dupBusy = true
            notify("Дюп: серия ×" .. n .. " — воскрешения каждые 2.5с", 3)
            task.spawn(function()
                for i = 1, n do
                    if getgenv().RM_Run ~= RUN_ID then return end
                    -- п.167: перед КАЖДЫМ выстрелом — общий лимитер
                    -- fireAt: клик Revive/другой кнопки посреди серии не
                    -- даёт пару LoadCharacter быстрее кулдауна (шквал =
                    -- Error 267); пауза самой серии 2.5с — для i > 1
                    if i > 1 then
                        task.wait(2.5)
                        if getgenv().RM_Run ~= RUN_ID then return end
                    end
                    local since = fireAt["LoadCharacter"]
                    if since and os.clock() - since < 2 then
                        task.wait(2.1 - (os.clock() - since))
                        if getgenv().RM_Run ~= RUN_ID then return end
                    end
                    local ok, err = n2Fire("LoadCharacter")
                    fireAt["LoadCharacter"] = os.clock() -- синк кулдауна
                    print("[RM] Дюп " .. i .. "/" .. n .. ": "
                        .. (ok and "отправлено" or tostring(err)))
                    if not ok then
                        notify("Дюп: ошибка на " .. i .. "/" .. n
                            .. " — смотри консоль", 3)
                        break
                    end
                end
                dupBusy = false
                if getgenv().RM_Run == RUN_ID then
                    notify("Дюп: серия ×" .. n
                        .. " завершена — забери старый набор (Auto pickup)", 5)
                end
            end)
        end,
    })
end
makeDupUI(Night1)
makeDupUI(Night2)

local Night3 = Window:CreateTab("Ночь 3", 4483362458)
Night3:CreateSection("Аимбот")
Night3:CreateKeybind({
    Name = "Бинд аимбота (зажать)",
    CurrentKeybind = "None",
    HoldToInteract = true,
    Flag = "RM_BindAim",
    Callback = function(on)
        -- п.172: Rayfield зовёт HoldToInteract-колбэк из Stepped БЕЗ
        -- pcall и вне keybindConnections — зомби-цикл старого прогона
        -- после re-run залипал бы G.RM_AimMonster = true до отпускания
        -- клавиши (новый тогл показывал бы OFF, а камера горела);
        -- guard по RUN_ID старого прогона его убивает
        if getgenv().RM_Run ~= RUN_ID then return end
        pcall(function()
            G.RM_AimMonster = (on == true)
        end)
    end,
})
makeDupUI(Night3)

-- новая вкладка «Воспоминания»: детект ребёнка и тревога кабины
-- переехали сюда из «Ночи 3» (по просьбе юзера)
local MemoriesTab = Window:CreateTab("Воспоминания", 4483362458)
MemoriesTab:CreateSection("Тревога кабины")
MemoriesTab:CreateToggle({
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
                if getgenv().RM_Run ~= RUN_ID then return end -- re-run во время ожидания
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
                        -- v4.37: payload не гарантирован Player (см. ветку
                        -- who ниже) — сравниваем и с именем/UserId
                        if plr == LP or plr == LP.Name
                            or plr == LP.UserId then
                            return -- свой вход — не тревожит
                        end
                        local who = (typeof(plr) == "Instance" and plr:IsA("Player"))
                            and plr.Name or "Кто-то (возможно, бот)"
                        local what = (typeof(door) == "Instance") and door.Name or "дверь"
                        -- v4.37: у кабины не было кулдауна (у двери есть 15с):
                        -- в лобби на 4–6 игроков уведомления шли пачками и
                        -- вытесняли остальные тревоги
                        if os.clock() - cabinLastAt < 5 then return end
                        cabinLastAt = os.clock()
                        notify("Вторжение в кабину: " .. who
                            .. " открывает «" .. what .. "»", 4)
                    end)
                    G.RM_CabinConn = cabinConn -- блок старта гасит его при re-run
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

-- из gueston (GitHub, Mansion incident): на входной двери играет
-- Growling, когда мутант у порога. Опрос 0.5с, кулдаун уведомлений 15с
MemoriesTab:CreateSection("Тревога двери")
G.RM_DoorAlert = false -- без флага: всегда стартует выключенным
MemoriesTab:CreateToggle({
    Name = "Мутант у входной двери (Growling)",
    CurrentValue = false,
    Callback = function(v)
        G.RM_DoorAlert = v
        doorAlertGen = doorAlertGen + 1
        local gen = doorAlertGen
        if v then
            notify("Тревога двери: ON", 3)
            task.spawn(function()
                -- v4.37: 0 вместо -1e9 — первые ~15с os.clock() условие
                -- ложно, тревога молчит, хотя мутант у двери (скрипт сам
                -- чинил такой же «нулевой» сентинел в других кулдаунах)
                local last = -1e9
                while G.RM_DoorAlert and gen == doorAlertGen do
                    if getgenv().RM_Run ~= RUN_ID then return end
                    local playing = false
                    pcall(function()
                        local fd = workspace:FindFirstChild("FrontDoor")
                        local sp = fd and fd:FindFirstChild("SoundPart")
                        local g = sp and sp:FindFirstChild("Growling")
                        playing = (g and g:IsA("Sound") and g.IsPlaying)
                            or false
                    end)
                    if playing and os.clock() - last >= 15 then
                        last = os.clock()
                        notify("⚠ Мутант у ВХОДНОЙ двери!", 5)
                    end
                    task.wait(0.5)
                end
            end)
        else
            notify("Тревога двери: OFF", 2)
        end
    end,
})

MemoriesTab:CreateSection("Kid Detector")
G.RM_KidDetect = false -- без флага: всегда стартует выключенным
MemoriesTab:CreateToggle({
    Name = "Детект ребёнка (GhostChild)",
    CurrentValue = false,
    Callback = function(v)
        G.RM_KidDetect = v
        notify(v and "Kid Detector: ON" or "Kid Detector: OFF", 2)
    end,
})
-- v4.42: «kid» как ПОДСТРОКА ловила любые модели с этим набором букв;
-- границы слова: kid / kid2 / kid_model — да, Kidnap/skid — нет.
-- В getgenv, а не локалом: лимит 200 локальных на чанк
G.RM_KidName = function(s)
    local low = string.lower(s)
    local i = 1
    while true do
        local a, b = string.find(low, "kid", i, true)
        if not a then return false end
        local before = a > 1 and string.sub(low, a - 1, a - 1) or ""
        local after = string.sub(low, b + 1, b + 1)
        local bl = before ~= "" and string.match(before, "%a") ~= nil
        local al = after ~= "" and string.match(after, "%a") ~= nil
        if not bl and not al then return true end
        i = b + 1
    end
end
-- движок kid detector (snippet ScriptBlox 55878): раз в секунду ищем
-- детей (GhostChild/kid) в workspace; новое появление — в консоль,
-- появление рядом (<60м) — уведомление. Имена — из gist «Night 3».
task.spawn(function()
    local known = {}
    local kidCd = {} -- [lower имя] = когда объявляли (кулдаун 30с, v4.42)
    while true do
        if getgenv().RM_Run ~= RUN_ID then return end
        if G.RM_KidDetect then
            local okK, errK = pcall(function()
                local lpch = LP.Character
                local myHRP = lpch and lpch:FindFirstChild("HumanoidRootPart")
                local now = {}
                for _, d in ipairs(workspace:GetDescendants()) do
                    if d:IsA("Model") then
                        local n = string.lower(d.Name)
                        if string.find(n, "ghostchild", 1, true)
                            or G.RM_KidName(n) then
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
                                -- v4.42: кулдаун на ИМЯ (30с) — стриминг
                                -- (исчез/появился за тик) спамил консоль
                                -- и уведомлениями каждую секунду
                                local key = string.lower(tostring(d.Name))
                                local lastA = kidCd[key]
                                if not lastA or os.clock() - lastA > 30 then
                                    kidCd[key] = os.clock()
                                    print("[RM] Kid Detector: " .. d.Name .. tag)
                                    if md and md < 60 then
                                        notify("Ребёнок рядом: " .. d.Name
                                            .. " " .. math.floor(md) .. "м", 4)
                                    end
                                end
                            end
                        end
                    end
                end
                for k in pairs(known) do
                    if not now[k] then
                        local okN, nm = pcall(function() return k.Name end)
                        local nmx = okN and tostring(nm) or "?"
                        local key = string.lower(nmx)
                        local lastA = kidCd[key]
                        -- v4.42: тот же кулдаун 30с — флаттер стриминга
                        -- писал «появился/ушёл» каждую секунду
                        if not lastA or os.clock() - lastA > 30 then
                            kidCd[key] = os.clock()
                            print("[RM] Kid Detector: ушёл " .. nmx)
                        end
                    end
                end
                known = now
            end)
            if not okK then
                -- молчаливый pcall прятал бы ошибки скана: тогл ON,
                -- а детект молчит — пишем причину в консоль
                print("[RM] Kid Detector: ошибка скана: " .. tostring(errK))
            end
        else
            known = {}
        end
        task.wait(1)
    end
end)

-- «Monster» (Воспоминания) светится от ОБЩЕГО тогла Monster ESP во вкладке
-- ESP (v4.32): юзер попросил «1 нажать и всё подсвечивалось» — отдельный
-- тогл из «Воспоминаний» убран (G.RM_MemMonsterESP больше не используется)

-- ============== Auto Farm: Хэллоуин (Воспоминания, v4.35) ============
-- По описанию юзера (уточнение v4.35: цепочка мешок → миска → детям,
-- на стук решаем по ESP ребёнок ли это; для чужих — «Не замечать»):
-- 1) база — СПЕРЕДИ камина (LivingRoomFurniture/Model/Fireplace); переезды
--    идут общим smoothTP = TweenService (с отменой предыдущего твина)
-- 2) конфеты цепочкой: FakeCandyBag (мешок) → CandyBowl (миска, слоты
--    1/2/3 — полной хватает ~3 раза) — одна поездка, два клика; конфета
--    «из миски» в руках = флаг candyHeld + поиск «candy» в персонаже
-- 3) стук в дверь (меню «Open / Unnoticed» в PlayerGui, тексты EN/RU):
--    каждые 5с осмотр двери — консоль пишет «у двери — ребёнок/монстр/
--    пусто»; ребёнок (GhostChild у двери) → добираем конфеты мешок→миска
--    и жмём «Открыть», затем раздача через FrontDoor.Hitbox.ClickDetector
--    (строго при конфете в руках); не ребёнок → жмём «Не замечать»
-- 4) монстр (модель Monster) у окна (Window-части ≤12 стд) → клавиша F
--    (VirtualInputManager); батарея Flashlight.Battery (макс 130), меньше
--    40 — едем заряжаться на BatteryCrate.ClickDetector
-- 5) после поездки — возврат к камину; дальше 6 стд от точки — возврат сам
-- (весь блок в do…end: иначе локальные переполняют лимит 200 luac в main)
do
local hfBusy = false
local hfGen = 0
local hfWin = {}
local hfWinAt = 0
local hfFWarned = false
local hfMenuAt = 0

local function hfFind(name)
    return workspace:FindFirstChild(name, true)
end

-- пол под точкой (луч вниз): корень HRP стоит на пол + 3 стд
local function hfFloorCF(pos, lookAt)
    local y = pos.Y
    pcall(function()
        local p = RaycastParams.new()
        p.FilterType = Enum.RaycastFilterType.Exclude
        p.FilterDescendantsInstances = {LP.Character}
        local hit = workspace:Raycast(pos + Vector3.new(0, 40, 0),
            Vector3.new(0, -160, 0), p)
        if hit then y = hit.Position.Y + 3 end
    end)
    if lookAt then
        return CFrame.lookAt(Vector3.new(pos.X, y, pos.Z), lookAt)
    end
    return CFrame.new(pos.X, y, pos.Z)
end

-- «перед камином»: камин у стены, открытая часть смотрит в комнату —
-- идём от камина к центру LivingRoomFurniture на 2.5 стд, взгляд на камин
local function hfFireplaceCF()
    local fp = hfFind("Fireplace")
    if not fp then return nil end
    local piv = fp:GetPivot()
    local base = hfFind("LivingRoomFurniture") or workspace
    local toCenter = base:GetPivot().Position - piv.Position
    local dir = (toCenter.Magnitude > 1) and toCenter.Unit
        or Vector3.new(0, 0, 1)
    return hfFloorCF(piv.Position + dir * 2.5, piv.Position)
end

local function hfBowlObj() return hfFind("CandyBowl") end
local function hfBagObj() return hfFind("FakeCandyBag") end
local function hfHitboxObj()
    local d = hfFind("FrontDoor")
    return d and d:FindFirstChild("Hitbox")
end
local function hfCrateObj() return hfFind("BatteryCrate") end

-- поездка по шагам: ТП рядом (TweenService) → клик по ClickDetector
-- каждый шаг, в конце возврат на исходную точку.
-- шаги = { { get=fn, key="HF...", tag="Имя" }, ... }
local function hfTrip(steps)
    -- v4.36: окно паники — поездки не стартуют (как у старых автофич):
    -- раньше фарм мог вытащить игрока из укрытия и поставить ложный
    -- candyHeld, кликая «с пола» (smoothTP вернул false)
    if hfBusy or pickupBusy or dupBusy or not panicIdle() then
        return false
    end
    local ch = LP.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local objs = {}
    for _, s in ipairs(steps) do
        local o = s.get()
        if not o then
            print("[RM] авто-фарм: не нашёл " .. s.tag)
            return false
        end
        objs[#objs + 1] = o
    end
    local origin = hrp.CFrame
    hfBusy = true
    -- v4.36: hfBusy локален — держим и общий pickupBusy, иначе
    -- автозабор/заправка стартуют посреди поездки и два актора
    -- телепортируют один HRP (чужой твин отменяет наш)
    pickupBusy = true
    local ok, err = pcall(function()
        G.RM_TP_Origin = { cf = origin, place = game.PlaceId }
        for i, s in ipairs(steps) do
            -- v4.36: тогл выключили / скрипт перезапустили посреди
            -- поездки — дальше не ТП и не жмём уже чужие кнопки
            if getgenv().RM_Run ~= RUN_ID or not G.RM_HalloFarm then
                error("фарм выключен посреди поездки")
            end
            local p = objs[i]:GetPivot().Position
            -- v4.36: ТП без проверки = клики «с пола» (сервер отбрасывает
            -- по дистанции), а поездка всё равно возвращала true
            if not smoothTP(hrp, hfFloorCF(p + Vector3.new(0, 1, 0), p)) then
                error("телепорт не прошёл (паника/re-run)")
            end
            task.wait(0.35)
            if typeof(fireclickdetector) ~= "function" then
                error("нет fireclickdetector")
            end
            local cd = objs[i]:FindFirstChild("ClickDetector")
            if not cd then error("нет ClickDetector у " .. s.tag) end
            -- v4.36: раньше промах лимитера маскировался под успех —
            -- клика не было, а поездка возвращала true (ложный candyHeld,
            -- вечная «зарядка» без результата); ждём кулдаун и кликаем
            local got = false
            for _ = 1, 6 do
                -- silent: до 6 ожиданий за поездку не должны сыпать
                -- «Подожди пару секунд» в notify
                if fireThrottle(s.key, true) then
                    got = true
                    break
                end
                task.wait(0.5)
            end
            if not got then
                error("лимитер клика не дал пройти (" .. s.tag .. ")")
            end
            fireclickdetector(cd)
            task.wait(0.5)
        end
    end)
    pcall(function() smoothTP(hrp, origin) end)
    -- v4.36: мёртвый прогон не стирает origin, записанный новым (re-run)
    if getgenv().RM_Run == RUN_ID then
        G.RM_TP_Origin = nil
    end
    hfBusy = false
    pickupBusy = false
    if not ok then
        print("[RM] авто-фарм: " .. tostring(err))
        return false
    end
    return true
end

-- «мешок → миска»: одна поездка, два клика, возврат к камину
local function hfGrabCandy()
    return hfTrip({
        { get = hfBagObj, key = "HFBag", tag = "FakeCandyBag" },
        { get = hfBowlObj, key = "HFBowl", tag = "CandyBowl" },
    })
end

-- конфета в руках: наш флаг ИЛИ объект «candy» в персонаже/рюкзаке
local function hfCandySeen()
    local found = false
    pcall(function()
        for _, cont in ipairs({ LP.Character, LP.Backpack }) do
            if cont and not found then
                for _, o in ipairs(cont:GetDescendants()) do
                    if o.Name:lower():find("candy", 1, true)
                        and (not o:IsA("BoolValue") or o.Value) then
                        found = true
                        break
                    end
                end
            end
        end
    end)
    return found
end

-- батарея фонаря (Flashlight.Battery, максимум 130)
local function hfBattery()
    local v = nil
    pcall(function()
        for _, cont in ipairs({ LP.Character, LP.Backpack }) do
            local fl = cont and cont:FindFirstChild("Flashlight")
            local bat = fl and fl:FindFirstChild("Battery")
            if bat and bat:IsA("ValueBase")
                and typeof(bat.Value) == "number" then
                v = bat.Value
                break
            end
        end
    end)
    return v
end

-- нажать F (VirtualInputManager — дают не все экзекуторы; фолбэк — notify)
local function hfPressF()
    local ok = false
    pcall(function()
        local V = game:GetService("VirtualInputManager")
        V:SendKeyEvent(true, Enum.KeyCode.F, false, game)
        task.wait(0.05)
        V:SendKeyEvent(false, Enum.KeyCode.F, false, game)
        ok = true
    end)
    if not ok and not hfFWarned then
        hfFWarned = true
        notify("Auto Farm: экзекутор не даёт VirtualInputManager — F жать самому", 5)
    end
    return ok
end

-- позиция монстра: кэш ESP (kind memmonster заполняется всегда) + фолбэк
local function hfMonsterPos()
    for _, e in ipairs(espCache) do
        if e.kind == "memmonster" and e.inst and e.inst.Parent then
            local r = e.inst:FindFirstChild("RootPart")
            if r then return r.Position end
            local p = e.inst:GetPivot()
            return p.Position
        end
    end
    local m = hfFind("Monster")
    if m then
        local r = m:FindFirstChild("RootPart")
        if r then return r.Position end
        return m:GetPivot().Position
    end
    return nil
end

-- окна: части/модели с «window» в имени (кроме контейнера «Windows»), кэш 5с
local function hfWindows(now)
    if now - hfWinAt < 5 then return hfWin end
    hfWinAt = now
    local list = {}
    for _, o in ipairs(workspace:GetDescendants()) do
        local n = o.Name:lower()
        if n:find("window", 1, true) then
            if o:IsA("BasePart") then
                list[#list + 1] = o.Position
            elseif o:IsA("Model") and n ~= "windows" then
                list[#list + 1] = o:GetPivot().Position
            end
        end
    end
    hfWin = list
    return hfWin
end

local function hfAtWindow(now)
    local mp = hfMonsterPos()
    if not mp then return false end
    for _, wp in ipairs(hfWindows(now)) do
        if (wp - mp).Magnitude < 12 then return true end
    end
    return false
end

-- клик по кнопке меню (getconnections → фолбэк клик VirtualInputManager)
local function hfClickBtn(btn)
    local clicked = false
    pcall(function()
        local cons = getconnections
            and getconnections(btn.MouseButton1Click)
        if cons and cons[1] then
            cons[1]:Fire()
            clicked = true
        end
    end)
    if not clicked then
        pcall(function()
            local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2
            game:GetService("VirtualInputManager"):SendMouseButtonEvent(
                math.floor(pos.X), math.floor(pos.Y), 0, game, 1)
            clicked = true
        end)
    end
    return clicked
end

-- кнопки меню стука в дверь: «Открыть» (open/открыт) и «Не замечать»
-- (unnoticed / не замечен / ignore / pretend) — тексты EN и RU
local function hfMenuBtns()
    local res = { open = nil, no = nil }
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return res end
    -- v4.42: кнопка должна быть видна ЦЕЛИКОМ: btn.Visible мало —
    -- предки могли быть скрыты (скрытый фрейм/выключенный ScreenGui/
    -- чужой хаб в PlayerGui — его «Ignore»/«Open» хватались раньше)
    local function shown(g)
        local n = g
        while n and n ~= pg do
            if n:IsA("GuiObject") and not n.Visible then return false end
            if n:IsA("LayerCollector") and not n.Enabled then
                return false
            end
            n = n.Parent
        end
        return true
    end
    for _, o in ipairs(pg:GetDescendants()) do
        local btn = nil
        if o:IsA("TextButton") then
            btn = o
        elseif o:IsA("TextLabel") then
            btn = o:FindFirstAncestorWhichIsA("TextButton")
        end
        if btn and btn.Visible and shown(btn) then
            local raw = btn.Text or ""
            local t = raw:lower()
            -- v4.37: :lower() в Luau не трогает кириллицу — «Открыть»
            -- оставалось с заглавной «О» и не совпадало с «откр»;
            -- сверяем и СЫРОЙ текст (заглавная первая буква)
            if not res.open and (t:find("open", 1, true)
                or t:find("откр", 1, true)
                or raw:find("Откр", 1, true)) then
                res.open = btn
            end
            if not res.no and (t:find("unnoticed", 1, true)
                or t:find("не замечать", 1, true)
                or t:find("не замечен", 1, true)
                or raw:find("Не замеч", 1, true)
                or t:find("ignore", 1, true)
                or t:find("pretend", 1, true)) then
                res.no = btn
            end
        end
    end
    return res
end

-- ребёнок у двери: модель GhostChild/kid рядом с FrontDoor (≤25 стд) —
-- тот же паттерн поиска, что у Kid Detector
local function hfKidAtDoor()
    local d = hfFind("FrontDoor")
    if not d then return false end
    -- v4.42: GetPivot объекта, убитого между поиском и вызовом, кидал
    -- ошибку МИМО pcall ниже — итерация фарма падала целиком
    local dp = nil
    pcall(function() dp = d:GetPivot().Position end)
    if not dp then return false end
    local found = false
    pcall(function()
        for _, o in ipairs(workspace:GetDescendants()) do
            if not found and o:IsA("Model") then
                local n = o.Name
                if n == "GhostChild" or G.RM_KidName(n) then
                    local okP, p = pcall(function()
                        return o:GetPivot().Position
                    end)
                    if okP and (p - dp).Magnitude < 25 then
                        found = true
                    end
                end
            end
        end
    end)
    return found
end

-- осмотр двери (раз в 5с, в консоль): кто там — ребёнок / монстр / пусто
local function hfDoorWho()
    local d = hfFind("FrontDoor")
    if not d then return "нет двери" end
    local dp = nil
    -- v4.42: как в hfKidAtDoor — GetPivot убитого объекта не должен
    -- ронять вызывающий код
    pcall(function() dp = d:GetPivot().Position end)
    if not dp then return "нет двери" end
    if hfKidAtDoor() then return "ребёнок" end
    local mp = hfMonsterPos()
    if mp and (mp - dp).Magnitude < 25 then return "монстр" end
    return "пусто"
end

MemoriesTab:CreateSection("Auto Farm (Хэллоуин)")
G.RM_HalloFarm = false -- без флага: всегда стартует выключенным
MemoriesTab:CreateToggle({
    Name = "Auto Farm (камин/конфеты/дверь/фонарь)",
    CurrentValue = false,
    Callback = function(v)
        G.RM_HalloFarm = v
        hfGen = hfGen + 1
        local gen = hfGen
        if v then
            notify("Auto Farm: ON — камин, мешок → миска, дверь (ребёнок → Open, чужой → Не замечать), окно → F", 3)
            task.spawn(function()
                local candyHeld = false
                local lastF = 0
                local grantAt = 0
                local doorLookAt = 0
                local chargeNotifyAt = 0
                -- v4.42: шаг цикла — в функции: одна упавшая итерация
                -- раньше убивала весь цикл фарма (незащищённые GetPivot
                -- и пр.) — фича «просто переставала работать» до
                -- повторного тогла; ошибку пишем один раз за прогон
                local function step()
                    -- v4.36: в окне паники фарм замирает (как старые
                    -- автофичи), а не таскает игрока из укрытия к камину
                    if pickupBusy or dupBusy or hfBusy or not panicIdle() then
                        task.wait(0.5)
                    else
                        local acted = false
                        local now = os.clock()

                        -- 1) монстр у окна: F (села батарея — зарядка)
                        if not acted and hfAtWindow(now)
                            and now - lastF >= 4 then
                            local bat = hfBattery()
                            if bat == nil or bat >= 40 or G.RM_InfBattery then
                                if hfPressF() then
                                    lastF = now
                                    acted = true
                                    print("[RM] авто-фарм: окно → F (батарея "
                                        .. tostring(bat) .. ")")
                                end
                            else
                                -- v4.36: notify на каждой итерации, пока
                                -- батарея села — троттлим раз в 12 с
                                if os.clock() - chargeNotifyAt > 12 then
                                    chargeNotifyAt = os.clock()
                                    notify("Auto Farm: батарея "
                                        .. math.floor(bat)
                                        .. " — заряжаюсь", 3)
                                end
                                acted = hfTrip({ { get = hfCrateObj,
                                    key = "HFCrate", tag = "BatteryCrate" } })
                            end
                        end

                        -- 2) осмотр двери каждые 5с — консоль пишет, кто там
                        if not acted and now - doorLookAt >= 5 then
                            doorLookAt = now
                            print("[RM] авто-фарм: у двери — " .. hfDoorWho())
                        end

                        -- 3) меню стука: ребёнок → конфеты + «Открыть»;
                        --    не ребёнок (монстр/пусто) → «Не замечать»
                        if not acted and now - hfMenuAt >= 1.5 then
                            local menu = hfMenuBtns()
                            if menu.open or menu.no then
                                hfMenuAt = now -- любая обработка меню раз в 1.5с
                                local kid = hfKidAtDoor()
                                if kid and menu.open then
                                    if not (candyHeld or hfCandySeen()) then
                                        acted = hfGrabCandy()
                                        if acted then
                                            candyHeld = true
                                            print("[RM] авто-фарм: мешок → миска"
                                                .. " → конфета (видна: "
                                                .. tostring(hfCandySeen()) .. ")")
                                        end
                                    end
                                    if not acted and hfClickBtn(menu.open) then
                                        acted = true
                                        grantAt = now + 1.5
                                        print("[RM] авто-фарм: ребёнок → «Открыть»")
                                    end
                                elseif menu.no and not kid then
                                    if hfClickBtn(menu.no) then
                                        acted = true
                                        print("[RM] авто-фарм: не ребёнок → «Не замечать»")
                                    end
                                end
                                -- ребёнок без кнопки «Открыть» / чужой без
                                -- кнопки «Не замечать» — ждём следующих тиков
                            end
                        end

                        -- 4) раздача: конфета → Hitbox (строго при конфете)
                        if not acted and grantAt > 0 and now >= grantAt then
                            if now - grantAt > 18.5 then
                                grantAt = 0 -- окно раздачи прошло
                                -- v4.36: ложный candyHeld не переживает
                                -- истёкшее окно — иначе лишняя поездка
                                -- в Hitbox и ложный print «конфета отдана»
                                candyHeld = hfCandySeen()
                            elseif not (candyHeld or hfCandySeen()) then
                                acted = hfGrabCandy()
                                if acted then candyHeld = true end
                            else
                                acted = hfTrip({ { get = hfHitboxObj,
                                    key = "HFDoor", tag = "FrontDoor" } })
                                if acted then
                                    candyHeld = false
                                    grantAt = 0
                                    print("[RM] авто-фарм: конфета отдана")
                                end
                            end
                        end

                        -- 5) запас конфет: мешок → миска (пока не раздача)
                        if not acted and grantAt == 0
                            and not (candyHeld or hfCandySeen()) then
                            acted = hfGrabCandy()
                            if acted then candyHeld = true end
                        end

                        -- 6) база: дальше 6 стд от камина — возвращаемся
                        if not acted then
                            local cf = hfFireplaceCF()
                            local ch = LP.Character
                            local hrp = ch
                                and ch:FindFirstChild("HumanoidRootPart")
                            if cf and hrp then
                                local d = (hrp.CFrame.Position - cf.Position)
                                    .Magnitude
                                if d > 6 then
                                    smoothTP(hrp, cf)
                                    acted = true
                                end
                            end
                        end
                    end
                end
                while G.RM_HalloFarm and gen == hfGen do
                    if getgenv().RM_Run ~= RUN_ID then return end
                    local okF, errF = pcall(step)
                    if not okF and G.RM_HfErr ~= RUN_ID then
                        G.RM_HfErr = RUN_ID
                        print("[RM] авто-фарм (итерация): " .. tostring(errF))
                    end
                    task.wait(0.6)
                end
            end)
        else
            notify("Auto Farm: OFF", 2)
        end
    end,
})

MemoriesTab:CreateButton({
    Name = "Проверить объекты фарма",
    Callback = function()
        local function mark(o, nm)
            return nm .. (o and " ✓" or " ✗")
        end
        local d = hfFind("FrontDoor")
        local res = {
            mark(hfFind("Fireplace"), "камин"),
            mark(hfFind("FakeCandyBag"), "мешок"),
            mark(hfFind("CandyBowl"), "миска"),
            mark(d and d:FindFirstChild("Hitbox"), "Hitbox двери"),
            mark(hfFind("BatteryCrate"), "зарядка"),
            mark(hfFind("Monster"), "монстр"),
        }
        local bat = hfBattery()
        res[#res + 1] = "батарея " .. (bat and math.floor(bat) or "?")
        -- v4.36: раньше передавали now+999 — метка кэша уходила в
        -- будущее на 16.6 минут, и окно-F молча переставало
        -- обновляться; сбрасываем кэш и обновляем честно
        hfWinAt = 0
        local wins = hfWindows(os.clock())
        res[#res + 1] = "окон " .. tostring(#wins)
        local s = table.concat(res, ", ")
        print("[RM] авто-фарм: " .. s)
        notify("Фарм: " .. s, 7)
    end,
})
end -- do Auto Farm (Хэллоуин)

-- ================= вкладка ТП: точки из RM Helper =================
-- Координаты/имена объектов — из RM Helper (rawscripts). Летим
-- плавно через общий smoothTP (не рывком, как у них).
local TPTab = Window:CreateTab("ТП", 4483362458)

local function tpToPoint(cf)
    local ch = LP.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    -- v4.41: как в панике — у трупа HRP есть, телепорт трупа врал бы
    -- об успехе; плюс кнопки раньше игнорировали мьютекс: пока летел
    -- автозабор, своим возвратом он откатывал ручной ТП обратно к предмету
    if not hrp or not hum or hum.Health <= 0 then
        notify("ТП: нет живого персонажа", 2)
        return
    end
    if pickupBusy then
        notify("ТП: подожди — идёт действие", 2)
        return
    end
    pickupBusy = true
    local okTp = false
    -- force: явный ТП игрока работает и в окне паники (п.192 блокирует
    -- только автоматические телепорты — возвраты автодействий)
    pcall(function() okTp = smoothTP(hrp, cf, nil, true) == true end)
    pickupBusy = false
    if getgenv().RM_Run ~= RUN_ID then return end
    if not okTp then notify("ТП: не удался", 2) end
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
-- из gueston (GitHub): «SafeZone» — точка в воздухе над картой
-- (y=30). Безопасная высота: упадёшь обратно, если крыши нет
tpBtn("Сейфзона (воздух)", CFrame.new(-14, 30, -122), gateOldFactory)

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
        -- v4.41: окно паники (15с) — чистка длиной ~11с увела бы
        -- персонажа из укрытия, а возврат заблокировала бы сама же
        -- паника: игрок остался бы у вентиляции с горящим мьютексом
        if not panicIdle() then
            notify("Вентиляция: идёт окно паники — жди", 2)
            return
        end
        if pickupBusy then notify("Уже занято (автозабор)", 2) return end
        local hum = LP.Character
            and LP.Character:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then
            notify("Вентиляция: нет живого персонажа", 2)
            return
        end
        pickupBusy = true
        task.spawn(function()
            local ch = LP.Character
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            if not hrp then pickupBusy = false return end
            local origin = hrp.CFrame -- точка возврата — как можно раньше
            -- возврат при re-run: новый прогон откатит персонажа сам
            G.RM_TP_Origin = { cf = origin, place = game.PlaceId }
            local okTp = false
            pcall(function()
                okTp = smoothTP(hrp, CFrame.new(68.3592224, 16.9999943, 74.6261444,
                    -0.999991238, -9.77371215e-08, 0.00418279972,
                    -9.77379742e-08, 1, 2.32150453e-13,
                    -0.00418279972, 4.09047467e-11, -0.999991238))
            end)
            if getgenv().RM_Run ~= RUN_ID then return end
            if not okTp then
                -- не долетели (ошибка твина) — клики не начинаем;
                -- точку снимаем только при удачном возврате, иначе
                -- она остаётся новому прогону на откат
                local backOk = false
                pcall(function() backOk = smoothTP(hrp, origin) == true end)
                if backOk and getgenv().RM_Run == RUN_ID then
                    G.RM_TP_Origin = nil
                end
                pickupBusy = false
                notify("Вентиляция: ТП не удался", 2)
                return
            end
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
            -- v4.41: возврат с проверкой — точку снимаем ТОЛЬКО при
            -- удачном возврате (при re-run посреди твина она остаётся
            -- новому прогону на откат), notify не врёт про успех
            local backOk = false
            pcall(function() backOk = smoothTP(hrp, origin) == true end)
            if backOk and getgenv().RM_Run == RUN_ID then
                G.RM_TP_Origin = nil
            end
            pickupBusy = false
            if getgenv().RM_Run == RUN_ID then
                notify(backOk and "Вентиляция: debris обработан"
                    or "Вентиляция: клики сделаны, возврат не удался", 3)
            end
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

local panicAt = 0 -- п.193: кулдаун повторной паники (удержание бинда)
local function panicTP()
    if getgenv().RM_Run ~= RUN_ID then return end
    -- п.193: удержание бинда/двойное нажатие не запускает параллельные
    -- твины (Rayfield диспатчит каждое нажатие в отдельном потоке)
    if os.clock() - panicAt < 4 then
        -- v4.36: кулдаун глотал нажатие молча — юзер думал, что уже
        -- в укрытии, и погибал; плюс кулдаун жёгся даже на трупе
        notify("Паника: перезарядка — жди пару секунд", 2)
        return
    end
    local ch = LP.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    -- п.193(в): у трупа HRP есть — телепорт трупа и «Паника → ...»
    -- врал бы об успехе
    if not hrp or not hum or hum.Health <= 0 then
        notify("Паника: нет персонажа", 2)
        return
    end
    -- v4.36: кулдаун жжём только после проверки персонажа
    panicAt = os.clock()
    -- п.192: окно паники — автофичи не стартуют, их возвратные ТП не
    -- откатывают игрока из укрытия; на время полёта держим мьютекс
    -- (если автофича уже летела — её флаг мы вернём как есть)
    G.RM_PanicUntil = os.clock() + 15
    local hadBusy = pickupBusy
    pickupBusy = true
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
        local okTp = false
        pcall(function()
            okTp = smoothTP(hrp, pick[2], nil, true)
        end)
        -- v4.41: не воскрешаем сброшенный кем-то флаг: автофича могла
        -- финишировать за время нашего ТП (её return ставит
        -- pickupBusy=false) — слепое hadBusy=true навсегда оставляло
        -- мьютекс занятым, и все фичи вставали до перезапуска скрипта
        if pickupBusy then pickupBusy = hadBusy end
        if getgenv().RM_Run ~= RUN_ID then return end
        -- smoothTP возвращает false при re-run/ошибке твина — не врём «Паника →»
        notify(okTp and ("Паника → " .. pick[1]) or "Паника: ТП не удался", 3)
        -- v4.36: ТП не удался — окно паники снимаем: 15 с автофичи
        -- были мертвы за неудачу, а игрок так и стоял на месте
        if not okTp then
            G.RM_PanicUntil = os.clock()
        end
        return
    end
    -- своих координат под эту карту нет — ищем укрытие по имени
    for _, name in ipairs(panicNames) do
        -- v4.36: сперва как раньше (top-level), затем рекурсивный
        -- фолбэк — вложенные укрытия давали «укрытий не нашёл»
        -- с СОЖЖЁННЫМ кулдауном и открытым окном паники
        local o = workspace:FindFirstChild(name)
            or workspace:FindFirstChild(name, true)
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
                local okN = false
                pcall(function()
                    okN = smoothTP(hrp,
                        CFrame.new(pos + Vector3.new(0, 5, 3)), nil, true)
                end)
                -- см. комментарий выше: мьютекс не воскрешаем
                if pickupBusy then pickupBusy = hadBusy end
                if getgenv().RM_Run ~= RUN_ID then return end
                notify(okN and ("Паника → " .. name)
                    or "Паника: ТП не удался", 3)
                -- v4.36: неудача не должна оставлять окно паники открытым
                if not okN then
                    G.RM_PanicUntil = os.clock()
                end
                return
            end
        end
    end
    if pickupBusy then pickupBusy = hadBusy end
    notify("Паника: укрытий не нашёл", 3)
end

TPTab:CreateKeybind({
    Name = "Бинд паники (случайное укрытие)",
    CurrentKeybind = "None",
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

-- ручной сброс всех биндов в «None»: одна кнопка обнуляет весь список
-- (в cfg — валидный ButtonX, в витрине — «None»; старые мусорные значения
-- из конфига тоже уходят в ButtonX через общий санити)
SettingsTab:CreateSection("Бинды")
SettingsTab:CreateButton({
    Name = "Сбросить все бинды (None)",
    Callback = function()
        local n = 0
        for _, cfg in ipairs(keybindCfgs) do
            pcall(function()
                cfg:Set("ButtonX")
                n = n + 1
            end)
        end
        keybindSweep()
        notify("Бинды сброшены (" .. n .. ") — назначь заново кликом "
            .. "по боксу бинда", 4)
    end,
})

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
            -- v4.37: пин гарантированно ДРУГИМ цветом: при b.R == 1
            -- (красный фон) обе записи совпадали с текущим значением →
            -- сигнал не срабатывал и дропдауны/лейблы/инпуты/бинды
            -- оставались под старой темой
            local tmp = (b.R + b.G + b.B < 3)
                and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
            main.BackgroundColor3 = tmp
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
        if typeof(v) ~= "string" then v = "Как в игре" end -- пустой CurrentOption
        local prev = G.RM_CamMode
        if v == "1-е лицо" then
            G.RM_CamMode = "first"
        elseif v == "3-е (сзади)" then
            G.RM_CamMode = "third"
        else
            G.RM_CamMode = "game"
        end
        applyCam()
        -- LoadConfiguration зовёт Set и с НЕ изменившимся значением
        -- (ссылки таблиц после JSONDecode не равны) — без этой проверки
        -- каждое открытие дублировало бы «Камера: Как в игре»
        if G.RM_CamMode ~= prev then
            notify("Камера: " .. tostring(v), 2)
        end
    end,
})


-- из prolover (Night 1): Plastic-материал, ноль отражений, декали/текстуры
-- спрятаны, вода гладкая — кадры дешевеют. Состояние в атрибутах
-- RM_Pot*: re-run-блок старта возвращает детали сам (п. 2c сверху)
SettingsTab:CreateSection("Производительность")
SettingsTab:CreateToggle({
    Name = "Анти-лаг (Potato)",
    CurrentValue = false,
    Callback = function(v)
        local n = 0
        local ok, err = pcall(function()
            if v then
                -- v4.37: pcall на КАЖДЫЙ объект — одна «неудобная» деталь
                -- раньше рвала весь проход: часть уже перекрашена, остаток
                -- нет, счётчик врёл, юзер видел просто «ошибка» (частично
                -- включённый режим выглядит включённым полностью). Плюс
                -- Terrain (он IsA("BasePart")) пропускаем: вешал мусорные
                -- атрибуты в deprecated-свойства (вода идёт своей веткой)
                local terrain = workspace:FindFirstChildOfClass("Terrain")
                for _, o in ipairs(workspace:GetDescendants()) do
                    if o:IsA("BasePart") and o ~= terrain
                        and not o:GetAttribute("RM_Pot") then
                        local okO = pcall(function()
                            o:SetAttribute("RM_Pot", 1)
                            o:SetAttribute("RM_PotMat", o.Material.Name)
                            o:SetAttribute("RM_PotRef", o.Reflectance)
                            o.Material = Enum.Material.Plastic
                            o.Reflectance = 0
                        end)
                        if okO then n = n + 1 end
                    elseif (o:IsA("Decal") or o:IsA("Texture"))
                        and not o:GetAttribute("RM_PotT") then
                        local okO = pcall(function()
                            o:SetAttribute("RM_PotT", 1)
                            o:SetAttribute("RM_PotTrans", o.Transparency)
                            o.Transparency = 1
                        end)
                        if okO then n = n + 1 end
                    end
                end
                pcall(function()
                    local t = workspace:FindFirstChildOfClass("Terrain")
                    if t and not t:GetAttribute("RM_PotW") then
                        t:SetAttribute("RM_PotW", 1)
                        t:SetAttribute("RM_PotWr", t.WaterReflectance)
                        t:SetAttribute("RM_PotWw", t.WaterWaveSize)
                        t.WaterReflectance = 0
                        t.WaterWaveSize = 0
                        n = n + 1
                    end
                end)
                notify("Анти-лаг: ON (" .. n .. " объектов; детали плоские)", 3)
            else
                for _, o in ipairs(workspace:GetDescendants()) do
                    if o:GetAttribute("RM_Pot") then
                        -- v4.37: атрибуты — ТОЛЬКО при успешной записи
                        -- материала: иначе исходное значение терялось
                        -- навсегда (повторить восстановление было нечем),
                        -- а OFF выглядело успешным
                        local okO = pcall(function()
                            o.Material = Enum.Material[
                                o:GetAttribute("RM_PotMat") or "Plastic"]
                            o.Reflectance = o:GetAttribute("RM_PotRef") or 0
                            o:ClearAttribute("RM_Pot")
                            o:ClearAttribute("RM_PotMat")
                            o:ClearAttribute("RM_PotRef")
                        end)
                        if okO then n = n + 1 end
                    elseif o:GetAttribute("RM_PotT") then
                        local okO = pcall(function()
                            o.Transparency =
                                o:GetAttribute("RM_PotTrans") or 0
                            o:ClearAttribute("RM_PotT")
                            o:ClearAttribute("RM_PotTrans")
                        end)
                        if okO then n = n + 1 end
                    end
                end
                pcall(function()
                    local t = workspace:FindFirstChildOfClass("Terrain")
                    if t and t:GetAttribute("RM_PotW") then
                        t.WaterReflectance = t:GetAttribute("RM_PotWr") or 1
                        t.WaterWaveSize = t:GetAttribute("RM_PotWw") or 0.05
                        t:ClearAttribute("RM_PotW")
                        t:ClearAttribute("RM_PotWr")
                        t:ClearAttribute("RM_PotWw")
                        n = n + 1
                    end
                end)
                notify("Анти-лаг: OFF (восстановлено " .. n .. ")", 3)
            end
        end)
        if not ok then
            print("[RM] анти-лаг: " .. tostring(err))
            notify("Анти-лаг: ошибка — смотри консоль", 3)
        end
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
        -- ColorPicker шлёт колбэк на каждый шаг мыши: GetDescendants в
        -- recolorGradient дебаунсим тем же токеном, что и тему (0.2с)
        local accMine = themeToken
        task.delay(0.2, function()
            if getgenv().RM_Run ~= RUN_ID or accMine ~= themeToken then return end
            recolorGradient(c)
        end)
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
            -- v4.37: сбрасываем и сами пикеры — иначе GUI показывает
            -- старые цвета, а Flags[].Color остаётся кастомным: при
            -- следующем старте LoadConfiguration (+4с) и colorResync
            -- (+5с) накатывают кастом обратно — «Сброс» отменял сам
            -- скрипт. Set у ColorPicker Callback НЕ зовёт — это ок:
            -- RM_Theme уже скопирован целиком выше
            pcall(function()
                local flags = Rayfield.Flags
                if type(flags) ~= "table" then return end
                local dflt = {
                    RM_ThemeAccent = DEFAULT_THEME.TabBackgroundSelected,
                    RM_ThemeBg = DEFAULT_THEME.Background,
                    RM_ThemeText = DEFAULT_THEME.TextColor,
                }
                for nm, dv in pairs(dflt) do
                    local f = flags[nm]
                    if f and dv and type(f.Set) == "function" then
                        f:Set(dv)
                    end
                end
            end)
            changeThemeNow()
            recolorGradient(Color3.fromRGB(150, 90, 235))
            notify("Тема сброшена", 2)
        end,
    })
end)


print("[RESIDENCE MASSACRE] v4.44 rayfield loaded | v4.44: Ночь 1 — fireThrottle штампует ПОСЛЕ преусловий (Заправить сейчас: pickupBusy до штампа; камин: персонаж+дровяная кучка; радио: все 4 проверки — раньше неудачный проход жёг 2с кулдауна и честный повтор откатывался «Подожди пару секунд»); «Бесплатные апгрейды»: ошибка pcall пишется в консоль и notify (раньше молча глушилась и врал «не найдено»); Auto Scare: при включении сканирует уже существующего Mutant (тогл посреди волны раньше не видел его до следующего спавна) — общий обработчик onMutant для ChildAdded и первого скана | v4.43: Auto Farm / Kid Detector — шаг цикла фарма обёрнут в pcall (одна упавшая итерация — незащищённые GetPivot в hfKidAtDoor/hfDoorWho — убивала ВЕСЬ цикл: фарм «просто переставал работать» до повторного тогла; ошибка пишется один раз за прогон), hfMenuBtns проверяет видимость ВСЕХ предков (скрытый фрейм/выключенный ScreenGui/чужой хаб в PlayerGui — его «Ignore»/«Open» хватались раньше), «kid» ищется с границами слова (Kidnap/skid не берутся — Kid Detector и дверь фарма), кулдаун детектора 30с на имя (стриминг: исчез/появился за тик спамил консоль и уведомления каждую секунду), хелпер G.RM_KidName в getgenv (лимит 200 локальных чанка) | v4.42: Main/Игрок — камера под-земли возвращается в СТАРТОВОМ блоке (раньше блок восстановления стоял после CreateWindow ~6с yield'ов, а при неудачной загрузке Rayfield файл вообще делал ранний return — камера оставалась Scriptable навсегда); подписка мыши под-земли underM1 публикуется в getgenv и гасится при re-run (колбэк глушен RUN_ID, но соединение жило вечно — утечка на каждый перезапуск); Noclip: кеш noclipSaved выкидывает записи о частях, которых больше нет (при включённом Noclip через респавн/смену раунда копились мёртвые части — рост памяти); кадр под-земли: ошибка pcall печатается один раз за прогон (раньше глушилась молча — фича просто «переставала работать» без строки в консоли) | v4.41: ТП/паника — panicTP не «воскрешает» сброшенный флаг pickupBusy (автофича могла финишировать за время ТП паники — слепое hadBusy=true навсегда оставляло мьютекс занятым и все фичи вставали до перезапуска); кнопки ТП: проверка живого персонажа (телепорт трупа врал об успехе) + уважение мьютекса (раньше игнорировали pickupBusy — возврат автозабора откатывал ручной ТП обратно к предмету) + notify при неудаче; чистка вентиляции: gate окна паники, проверка здоровья, результат исходного ТП (клики не начинаются если не долетели), возврат с retOk (точка снимается только при удачном возврате) и честный notify | v4.40: автозабор/авто-заправка — fireItem шлёт ОДИН тип взаимодействия за проход (prompt предпочтительнее) и fired только при успехе pcall (раньше уходили ОБА remote и fired=true даже при упавшем pcall — до ~2 fire-вызовов/с); лимит попыток залипшей цели: после 3 заходов кулдаун минута вместо вечных +10с (ТП туда-обратно весь раунд); isElectric дописаны electr/ключ/Ключ (ящик/ключ в других написаниях автозабор щёлкал — гонка с Auto electric); jerrycan исключён из автозабора (канистру ведёт Auto fuel сам, клик сбивал held/tookRecently); findByModelName: ближайший к игроку кандидат, деко-дубли (модель внутри такой же) — только фолбэком (раньше первая попавшаяся: заправка летела к деко-генератору на другом конце карты, fuelLevel снимал уровень не с того генератора); авто-заправка (цикл и ручная) пишет G.RM_TP_Origin и снимает только при удачном возврате; убран двойной скан ESP на старте (4 обхода workspace подряд) | v4.39: автоэлектрика — round-robin по битым проводам (раньше всегда брался broken[1]: «нечинящийся» первый провод лишал помощи все остальные), бэкофф после 3 неудачных пересадок ящика подряд (раньше рейс к ящику ↔ пересадка крутись ВЕЧНО каждые ~10с — TP пинг-понг), все три рейса электрики (ящик/ключ/провод) пишут G.RM_TP_Origin и снимают её только при удачном возврате — при re-run посреди полёта новый прогон откатывал персонажа (раньше электрика не писала точку возврата вообще), FireServer в ClickWire при падении фолбэчит на ClickDetector (раньше падение гасило клик молча и попытка сгорала); лимит 200 локальных чанка: tLib → G.RM_LibLoadedAt, guiIsOurs внутрь findEliteGui | v4.38: батчи 7a–7b (Rayfield-зона + старт + ESP/Settings) — re-run во время CreateWindow/CreateTab (~6.5с yield'ов) теперь обрывается guard'ом и стабом-вкладкой (раньше строительство шло на уничтоженном окне: сиротские вкладки и InputBegan-бинды, которые Destroy уже никогда не отключал — двойные срабатывания каждого бинда); санити биндов: проход от загрузки библиотеки (tLib+4.3с) и сразу после сборки вкладок + валидация через Enum.KeyCode вместо белого списка (мусор из правленого конфига: пустая строка/«q»/«RIGHTSHIFT» ловился только поздними проходами); findEliteGui и свип старых окон — по заголовку «ELITE HUB» (чужой Rayfield-хаб в CoreGui больше не мутируется и не сносится, своё окно нашлось по подписи); ссылка на старую библиотеку гасится только при успешном Destroy; подписка спавна Anti-Kick публикуется в getgenv и гасится при re-run (раньше висела до следующего CharacterAdded); двойной подъём из-под земли: блок 2b сбрасывает RM_UnderActive и восстанавливает камеру после своего подъёма (фолбэк через ~5с поднимал ЕЩЁ РАЗ из новой точки — на крышу); «Сбросить тему» сбрасывает и сами пикеры (Flags[].Color) — иначе LoadConfiguration/+5с colorResync возвращали кастом при следующем старте; Анти-лаг: pcall на каждый объект (единичная ошибка не рвала весь проход), Terrain пропускается (писал мусор в deprecated-свойства), атрибуты RM_Pot* чистятся только при успешной записи — иначе исходный материал терялся навсегда; пин фона в changeThemeNow при R==1 (сигнал не срабатывал — элементы оставались старой темой) | v4.37: кулдауны fireThrottle переехали в getgenv (локальная таблица умирала при re-run: первый выстрел после перезапуска мгновенно = Error 267) + тихий режим для автомата (радио/флешка/поездки фарма больше не сыплют «Подожди пару секунд» на каждой пропущенной попытке); fuelPress: проверка fireclickdetector ПЕРЕД ТП (без кликера каждый тик уводил персонажа к цели — вечный пинг-понг, который не останавливал ни один стоп-бюджет); ручная заправка штампует lastFuelAt в конце (авто не кликало генератор через 0.7с после ручного); Ночь 2 PowerCell: сброс cellTries ПЕРЕД печатью стопа (счётчик от прошлой ночи давал ложный «авто остановлено»), бюджет попыток жжётся за ЛЮБУЮ попытку вставки (раньше только «в руках+клик» — если капсула не попадает в персонес, цикл канистра↔генератор был бесконечен), первая вставка не раньше 2с после взятия; Тревога двери: кулдаун с -1e9 вместо 0 (первые ~15с os.clock() тревога молчала); Тревога кабины: кулдаун 5с (шла пачками в лобби) + фильтр своего входа по Name/UserId; автозабор: «Что забирать: Все» не работал вовсе — string.lower в Luau не трогает кириллицу, «Все» не совпадало с «все»; точка возврата doPickup пишется ДО твина и снимается только при удачном возврате; Enabled=false/радиус 0 = без ТП к «мёртвой» точке; кнопки Revive/Дюп ждут окончания автодействий (респавн посреди ТП ломал всё); hfMenuBtns сверяет и сырой текст («Открыть» с заглавной не матчилось :lower()); smoothTP: nil-гард первым (гард в конце был мёртвым кодом) | v4.36: ночной баг-хант (15 агентов по зонам, батчи 1–4) — откат RM_TP_Origin оживлён (type→typeof: type(CFrame)=userdata, условие было истинно всегда) и снимается ТОЛЬКО при удачном возврате (камин/радио); TP walk: нормировка диагонали W+D (√2 скорости), CFrame пишется только при отличии позиции; стамина: после 1.2с обнаружения проверяется и G.RM_StaminaLock (тогл выключили — не пишем в чужое); Ночь 1: радио кликает через fireThrottle (было до 24 кликов по 0.5с мимо лимитера = Error 267), авто-флешка под ОБЩИМ лимитером с ручной кнопкой, у Blizzard вылечена and/or-ловушка («как было» ВКЛЮЧАЛО метель при кэше false) и кэш не выбрасывается когда Blizzard не найден, кнопка «Подбросить дрова» под fireThrottle, ТП к дровам/радио проверяется (ложные «Дрова подброшены»/«Цели запущены» без ТП убраны); паника: notify при перезарядке (раньше молча глотала), кулдаун жжётся после проверки персонажа (труп не сжигал), окно паники снимается при неудачном ТП и при «укрытий не нашёл» (раньше 15с автофич были мертвы), рекурсивный фолбэк поиска укрытий; ESP: boolVal при NumberValue не перекрывал атрибут («ДОГОНЯЕТ/ИЩЕТ» мог не детектиться), modelKind фильтрует модели вне workspace (фантомы в espCache кормили аимбот); Auto Farm: panicIdle в цикле и hfTrip (фарм не вытаскивает из укрытия), hfTrip жёсткий — ТП под проверкой, лимитер клика ДОЖИДАЕТСЯ (промах = false, не ложный true), guard выключения/re-run посреди поездки, общий pickupBusy (автозабор не влезет в поездку), матчер меню понимает «не замечать» (раньше только «не замечен» — RU-ветка никогда не срабатывала), кэш окон не замораживается на 16 мин после кнопки проверки, notify зарядки троттлен, candyHeld сбрасывается при истечении окна раздачи | v4.35: Auto Farm по уточнённой механике юзера — цепочка конфет FakeCandyBag (мешок) → CandyBowl (миска) одной поездкой с двумя кликами (hfTrip теперь принимает шаги), на стук в дверь смотрим по ESP: ребёнок (GhostChild ≤25 стд от FrontDoor) → добираем конфеты и жмём «Открыть», иначе → «Не замечать» (тексты EN/RU), каждые 5с осмотр двери в консоль (ребёнок/монстр/пусто), раздача через Hitbox только при конфете, кнопка проверки показывает и мешок | v4.34: фикс кика Error 267 на Ночи 3 сразу после запуска — Anti-Kick больше НЕ удаляет Remotes.Kick (Destroy резал дерево; анти-чит Ночи 3 требует его наличие — отсюда 267 и старый Infinite yield WaitForChild(\"Kick\") из v4.24): теперь только getconnections:Disconnect на все OnClientEvent (клиентская кик-логика молчит, ремоут на месте), повтор на спавне сохранён, в консоль пишется число отключённых обработчиков | v4.33: Auto Farm (Хэллоуин, вкладка «Воспоминания»; тогл без флага — OFF на старте): база спереди камина (LivingRoomFurniture/Model/Fireplace, TweenService = общий smoothTP), конфеты CandyBowl.ClickDetector (слоты 1/2/3, хватает ~3 раза → клик-наполнение), меню ребёнка «Open» кликается само (getconnections → фолбэк VIM), раздача через FrontDoor.Hitbox.ClickDetector строго при конфете в руках (флаг + поиск candy), монстр у окна (Window-части ≤12 стд) → F через VirtualInputManager, батарея <40/130 → зарядка BatteryCrate; кнопка «Проверить объекты фарма» (✓/✗ пути) | v4.32: «Monster» из Воспоминаний подсвечивается ОДНИМ тоглом Monster ESP (вкладка ESP → Монстры) — один клик = и обычные монстры, и «Monster»; отдельный тогл из «Воспоминаний» убран | v4.31: ESP на монстра «Monster» из Воспоминаний — у модели нет Humanoid (только AnimationController, корень RootPart), раньше modelKind её отбрасывал: новый kind «memmonster» + тогл «ESP монстра (Monster)» во вкладке «Воспоминания» (цвет общий с Monster ESP), подпись «имя [дистанция]» без HP, RootPart-фолбэк позиции; камерный аим и «Под землю при опасности» теперь замечают и этого монстра (consider + RootPart) | v4.30: порт полезного из чужих скриптов (скан 14 репозиториев): «Запустить цели (радио)» — ТП к радио + клики до GameState.Active с возвратом на место (prolover), «Отключить метель» — GameState.Blizzard локально с откатом при re-run (prolover), «Бесплатные апгрейды (эксп.)» — RS.Upgrades.Generator Max/Price + показ UpgradeShop/Gambler, честный notify что сервер может не доверять клиенту (diddy), «Тревога двери» — опрос Growling на FrontDoor.SoundPart, кулдаун уведомлений 15с (gueston), «Анти-лаг (Potato)» — Plastic + ноль отражений + декали/текстуры + вода, кэш исходных значений в атрибутах RM_Pot*, восстановление при re-run и на OFF (prolover), WorkerHead (Ночь 3) в Item ESP — предмет без ClickDetector, гейт автозабора e.prompt or e.cd его не трогает (gueston), ТП «Сейфзона (воздух)» y=30 (gueston) | v4.29: убрана проверка на Residence Massacre (GameId/PlaceIds) — меню и скрипт открываются в ЛЮБОЙ игре (игровые фичи молчат, ТП-гейты от улета в пустоту защищают) | ФИКСЫ v4.28 (баг-хант 20 зон, 233 находки, отчёт BUGHUNT_v4.26.md): Под землю — кэш коллизий публикуется в getgenv (re-run возвращает коллизии + поднимает на поверхность), ручной OFF поднимает с глубины, Noclip↔Под-землю читают чужие кэши | автоэлектрика — состояние ящика = намерение клика, а не слепой toggle (flip-flop «шаг 2/шаг 3» убран), пересадка ящика одним рейсом | Паника-ТП — кулдаун 4с, труп не телепортируется, окно паники 15с (автофичи не стартуют, возвраты не откатывают из укрытия, мьютекс на время полёта), ТП-кнопки с force | smoothTP — новый твин отменяет предыдущий (два твина больше не дрались за CFrame) + таймаут ожидания (уничтоженный HRP больше не вешает поток) | «Заправить сейчас» через лимитер (анти-Error 267) | серия дюпа — лимитер на КАЖДОМ шаге, Revive блок при серии | hold-бинд аимбота — guard от зомби-цикла после re-run | Repair/Delivery — общий кулдаун на ремоут (8 кнопок не рвут соединение) | v4.27: сентинел пустого бинда Unknown → ButtonX — Roblox отдаёт input.KeyCode = Enum.KeyCode.Unknown на клики мыши/колесо/тап (DevForum 4073073; фильтр RF 3277) → v4.26 запускал ВСЕ 10 биндов на каждый клик; свип витрины только по TextBox «KeybindBox», санити старого конфига — 3 прохода (4.6/5.6/7.6с) против гонки с LoadConfiguration | v4.26: бинды «None» (под капотом тогда был Unknown — ошибки ввода убраны), автосанити + кнопка «Сбросить все бинды» в Settings, Дюп во ВСЕХ ночах (Н1/Н2/Н3) | v4.25: Дюп предметов — слайдер «Повторов дюпа» + кнопка-серия: ×N воскрешений (LoadCharacter) с паузой 2.5с, одиночный дюп — кнопка Revive | HOTFIX (v4.24): ToggleUIKeybind = Enum.KeyCode.RightShift — строка \"RightShift\" падала в assert валидации Rayfield (string.upper даёт RIGHTSHIFT ≠ RightShift), CreateWindow не создавал окно — меню не открывалось c v4.22 | НОВОЕ (v4.23): «Под землю при опасности» вместо God Mode — монстр ближе радиуса (слайдер «Радиус опасности», 100 ст) → персонаж уходит под землю (сервер видит его там — монстр не достаёт), камера и ходьба как обычно (orb-камера над точкой, WASD штатным контроллером), всплытие когда монстр дальше радиуса+30 или тогл OFF | v4.22: Генератор Н2 — вставка капсулы в Generator.Detector.ClickDetector (больше не летит к чужому генератору; выбранный слот пишется в консоль), вкладка «Воспоминания» (Kid Detector + Тревога кабины переехали из Ночи 3), ВСЕ бинды по умолчанию None | Anti-Kick (Destroy Remotes.Kick при старте + на спавне), Бессмертие/God Mode (тогл в «Игрок») | РЕВИЗИЯ (два независимых ревью: аудит биндов/флагов/кадрового кода + строки 2400-конец): ToggleUIKeybind=RightShift — K (Auto PowerCell) больше не прячет окно Rayfield, отмена отложенного LoadConfiguration старой библиотеки при re-run (откат конфига в первые 4с), гонка стартового restore Disable Static, подсказка Static ищет помехи и в CoreGui, дедуп notify «Камера», scareConn/cabinConn гасятся в блоке старта (утечка на re-run), TP walk не двигает персонаж при наборе в чате, 1 RaycastParams на кадр вместо 2, ESP-рендер считает позицию только для включённых категорий, дебаунс рескана предметов 0.5с | v4.21: Anti-Kick + God Mode + ревью 2400-3783 | v4.20: гашение старой Rayfield, гейты ТП, кулдаун FireServer | v4.19: Паника-ТП (G), Kid Detector | ESP | Settings")