# Residence Massacre — заметки разработчика (внутренний файл)

Справочник по игре и скрипту: всё, что вытащено из открытых исходников и проверено в игре.
Публичная документация — в `README.md`.

## Идентификаторы игры

| Что | Значение |
|---|---|
| GameId (вселенная) | `4987467534` — покрывает все плейсы |
| Плейс — лобби | `14437001043` |
| Плейс — Ночь 1 | `14896802601` |
| Плейс — Ночь 2 | `16667550979` |
| Плейс — The Bunker | `100255403764514` (из Bunker Helper V5) |

В v4.29 привязка к игре убрана: проверки `RM_GAME_ID` / `ONLY_PLACE_IDS` при старте больше нет — скрипт стартует в любой игре (эти ID остались справочно: их используют плейс-гейты ТП/паники).

## Структуры игры (подтверждено)

### Общее
- `ReplicatedStorage.Remotes` — `ClickWire`, `Repair`, `Delivery`, `EscapeSnatch`,
  `LoadCharacter`, `FlashCam`, `Kick` (**Kick: сам ремоут НЕ удалять** — v4.21
  юзер просил `Destroy()` «для спокойствия», v4.34 убрали: Ночь 3 кикала с
  Error 267 сразу после запуска; анти-кик теперь только гасит обработчики
  `OnClientEvent` через `getconnections`)
- `ReplicatedStorage.GameState.FusesFried` (bool) — **true = свет вырубили**
  (= есть битые проводы). Ложится в гейт Auto electric.
- `ReplicatedStorage.GameState.Blizzard` (bool) — модификатор метели; запись
  клиента **локальная** (v4.30, из prolover — сервер правки не видит)
- `ReplicatedStorage.GameState.Active` (bool) — цели ночи запущены (v4.30)
- `ReplicatedStorage.Upgrades.Generator` — атрибуты `Max`/`Price` (апгрейды),
  `ReplicatedStorage.Assets.UpgradeShop`/`Gambler` — магазин и гемблер лежат
  в Assets (v4.30, из diddy: показ/лимиты — локально, сервер может валидировать
  цену сам — экспериментальная кнопка)
- `workspace.FrontDoor.SoundPart.Growling` (Sound) — `IsPlaying == true`,
  пока мутант у входной двери (тревога двери, v4.30 из gueston)
- `Character.Sprint.Stam` (+ Max-атрибут) — стамина
- `Character.Breath` (+ Max-атрибут) — кислород; `workspace.Sounds.HeavyBreath`,
  `Lighting.Blur` — задыхание
- `Character.Temperature` — **LocalScript** (а не число!): выключать `Enabled`,
  при выключении тогла включать обратно. `Character.Freeze` — число.
- `Character.Config` мутанта: `Active` / `Seeking` / `Chasing` / `Wandering` (bool)

### Ночь 1
- `workspace.FuseBox.Wires` — провода = **`Part`** с `Sparkles` + `ClickDetector`
  - **битый провод = `Sparkles.Enabled == true`** (сверено с script-sources:
    у битого провода искры включены, `LocalTransparencyModifier = 0`,
    `cd.MaxActivationDistance = 50`; у чинного — невидим, `8`)
  - клик: ремоут `ClickWire:FireServer(w.model)` (путь RMxploitt),
    `ClickDetector` — запасной
- `WrenchGiver` — выдача ключа (`Wrench`), `FuseBox` Detector — открыть ящик
- `workspace.Shack.Generator.Fuel` — **значение топлива 0..100** (их дисплей
  показывает `%.0f%%` с `value/100` для Lerp — шкала НЕ 0..1)
- `workspace.Shack.JerryCan` — канистра; у ClickDetector **нет свойства Position**
  (важно: `.Position` рвётся — позицию брать от модели: `objPos()`)
- `workspace.WoodPile.Detector` — дровяная кучка; камин — `-27.149, 8.7, -118.612`
- Окно Ларри (Auto Scare) — Mutant рядом с `Config.Wandering == false` →
  `FlashCam:FireServer("1")`
- `workspace.Radio.ClickDetector` — старт целей: клики до `GameState.Active`
  (v4.30, из prolover; их точка перед радио `-34.354, 7.800, -58.370`
  с поворотом; радио — прямой ребёнок workspace)

### Ночь 2
- `PowerCell` — Model с `ClickDetector` **вне** Generator; вставка — клик по
  Generator
- Ремоуты: `Repair` (провод 1–4), `Delivery` (Camera/Lock/UVLamp/MotionSensor),
  `EscapeSnatch`, `LoadCharacter` (Revive)
- Координаты новой карты: y ≈ 82 (главный зал/вход/коридоры/доска доставок/укрытие)

### ESP / предметы
- Любой `ClickDetector` / `ProximityPrompt` в workspace = предмет (Item ESP)
- Модель `Monster` (Воспоминания, юзер-скрин v4.31): **без Humanoid** — только
  `AnimationController`, корень `RootPart`, части Claw/Ribcage/Torso... 
  `modelKind` ловит по точному имени → kind `memmonster`, видится от ОДНОГО тогла Monster ESP (v4.32; раньше — отдельный тогл
  в «Воспоминаниях»);
  `consider` (камерный аим, «Под землю») ищет корень с фолбэком `RootPart`
- `WorkerHead` (Ночь 3) — часть/модель **без** ClickDetector: Item ESP метит
  по имени (v4.30, из gueston); автозабор его не трогает (гейт `e.prompt or e.cd`)
- Топливо/газ: ValueBase с `"fuel"`/`"gas"` в имени → потом атрибут → потом текст

### Фонарь / кабины (Ночь 3, gist yancielsicard2-arch)
- `Character.Flashlight.Battery` или `Backpack.Flashlight.Battery` — NumberValue,
  максимум 130 (Infinite Battery держит `Value < 130 → 130`)
- `ReplicatedStorage.Remotes.OpenDoor` — RemoteEvent; `OnClientEvent(plr, door)`:
  **plr == LocalPlayer → своё открытие, не тревога**; иначе имя игрока + `door.Name`
- Имена папок Ночь 3: `workspace.Zombies`, `Halloween.Pumpkins`, `JerryCans`,
  `AmmoPiles`, `Cabins`, `ItemSpots`, `Shotgun`; модель `GhostChild`,
  часть `WorkerHead`; ремоут `GiveItem` (**не используем** — это выдача предметов)

### Бункер (место `100255403764514`, Bunker Helper V5)
- `workspace.Generator` (ClickDetector), `workspace.JerryCans.JerryCan` —
  заправка та же, что и в Ночи 1 (наш Auto fuel подхватывает)
- `workspace.Ventilation.Debris` — дети с `ClickDetector`: кликать ~7с (чистка)
- `workspace.PowerGrids["1".."4"].Door` (BasePart, искать recursive) — ТП к двери
- Сырые координаты: сейф-плейс `-25.31, 26.0, -150.49`; конец (6 утра)
  `16.30, 17.0, 68.17`; вентиляция `68.36, 17.0, 74.63`; генератор `-31.41, 13.4, -155.57`
- Abomination = Model **`BunkerRat`** — светится в Mutant ESP: `isMutantModel`
  ловит подстроку `bunkerrat` (вместе с `abomination`), носит `Config` и
  идёт в кэш мутантов/аимбота (устаревшая формулировка «в ESP пока не
  заведено — имена не пересекаются с *mutant*» заменена)

### Воспоминания / Хэллоуин 1 (Auto Farm, v4.33–v4.35 — со скринов юзера)

> ⚠ **v4.63: Auto Farm полностью УДАЛЁН из скрипта по запросу юзера** (тогл,
> кнопка и весь цикл из «Воспоминаний», ~780 строк). Секции ниже оставлены
> **только для истории/структуры карты** — фичу не пересоздавать без явного
> запроса юзера.

**«Духовный помощник» (НОВАЯ карта, v4.66 → v4.68 — секция первой в «Воспоминаниях»):**
- **Предметы с ClickDetector:** `Teddy bear` и `Teddy bear2` (дети `Sound`/
  `ClickDetector`/`Mesh`), **часы** — автопоиск по имени (Clock/Alarm/Watch/
  Час/Будильник) среди объектов с ClickDetector, имя печатается в консоль;
  если не найдётся — юзер назовёт имя. **v4.68: обход-фарм УДАЛЁН** (тогл
  «Авто-фарм воспоминаний» + слайдер «Скорость обхода» — юзер: «слишком
  быстро двигаюсь», «давай просто … кликать постоянно, лучше без лампочки»,
  «и всё») — **не пересоздавать**; вместо него тогл «Мишки и часы надо
  мной (авто-клик)»: предметы PivotTo НАД ГОЛОВОЙ игрока (ступеньки по X:
  `x=((i-1)%3-1)*1.6`, `y=2.5+floor((i-1)/3)*1.5`) и кликаются сами,
  ключ кулдауна свой на предмет (`RMIte1..3`), `Radio`/`Lamp` из набора
  убраны («без лампочки»); OFF → возврат по `G.RM_TeddyCFs`.
  `fireThrottle(key, silent, minGap)` — с v4.66 3-й параметр = свой кулдаун.
- **Progress атаки:** `NumberValue` `Progress` у каждого входа —
  `Monster/Closet|Door|Vent|Window/Progress` и `MonsterModel`/`1`/`2`/`Progress`.
  **v4.68 (юзер: «находит слишком рано»): уведомление «монстр близко» — с 60%,
  ловушка «прячься» — ТОЛЬКО ≥80%; ветка 0.8 (масштаб 0..1) УБРАНА** — при
  масштабе 0..100 она срабатывала на 0.8%. Если юзер скажет «вообще не
  прячет» — по строкам `[RM] прогресс: Window=…` перекалибруем (может,
  масштаб всё же 0..1 — тогда вернуть dual-порог). Снятие ловушки — ТОЛЬКО
  сброс значения (посреди атаки не выкидывает).
- **Кровать (прятка):** `Bed` → `Detectors/Detector1|Detector2` (дети
  `ClickDetector` + `Pos`), `Hidden` (Bool/Number — формат уточнить),
  `Barrier`, `BedCam`. Прятка v2 (v4.67): TP к **детектору** (не центр
  кровати) → клик → подтверждение (`Hidden` / камера `BedCam`<4стд /
  персонаж у `Pos`) → неудача → `Detector2`; без сигнала 3 попытки;
  выход: `ReplicatedStorage.Remotes.Unhide:FireServer()` (юзер разрешил
  ремоуты) → проверка 1.5с → фолбэк-клик. Каждая ступень в консоли
  (`[RM] кровать: …`); сырые `Progress` печатаются раз в 10с
  (`[RM] прогресс: Window=…`) — **по этим строкам юзера калибруем масштаб**.
- **Рассудок:** `Sanity` (ValueBase, не только NumberValue) под `Humanoid`
  персонажа. **v4.67:** слушатель `Sanity.Changed` → мгновенный возврат 100
  + свип 0.5с; коннект `G.RM_SanityConn` снимается при OFF и в блоке 2g.
  Юзер v4.67: «умираю от рассудка» — если считает СЕРВЕР, клиент не удержит
  (крайность не обходить — красная линия), тогда лечить самой игрой
  (клики по воспоминаниям).
- Мишки следуют по таблице `G.RM_TeddyCFs` (имя→CFrame), возврат при
  выключении и в блоке 2g старта. Клик клиентский (`fireclickdetector`):
  если далеко от СЕРВЕРНОЙ точки предмета — сервер может отбить по
  дистанции (ждём тест юзера).
- `workspace.LivingRoomFurniture.Model.Fireplace` — база: точка стояния =
  (камин → центр `LivingRoomFurniture`)*2.5, пол рейкастом, взгляд на камин
- `workspace.CandyBowl` — миска: direct child `ClickDetector` (+ `Highlight`,
  слоты конфет `1`/`2`/`3` (Mesh/Decal), `Bowl` с `OpenSound`); по юзеру
  полной миски хватает ~3 раза; **наполняется из мешка**: сначала клик
  `FakeCandyBag`, потом клик миски — v4.35 это одна поездка `hfGrabCandy`
  (шаги `hfTrip`: `{FakeCandyBag, CandyBowl}` → возврат к камину)
- `workspace.FrontDoor` — дочь `Hitbox` → `ClickDetector` = раздача конфеты
  ребёнку; рядом `SoundPart.Growling` (наша «Тревога двери»), `CamPart`,
  `RightDoor`, `RootPart`, `lookAt`
  - **v4.61 (скрин юзера)**: кликабельный `Hitbox > ClickDetector` живёт и в
    `RightDoor` — скрипт собирает **все** модели с «door» в имени
    (`G.RM_HfDoors`): посетителя ищем ≤25 стд от любой двери, запоминаем
    `G.RM_HfGrantBox` — раздача едет к хитбоксу именно той двери, где видели
    ребёнка; `hfKidAtDoor` ловит и `child`/`visitor` в имени; раз за стук
    консоль печатает имена моделей у двери, если посетитель не распознан
- `workspace.BatteryCrate` — зарядка фонаря: direct `ClickDetector` (+ 4×
  `Battery`, `Center`, `Main`) — кликать стоя рядом
- **Меню стука** «Open / Unnoticed» — GUI в `PlayerGui`, ищем ОБЕ кнопки
  (тексты EN/RU: open/открыт, unnoticed/не замечен/ignore/pretend);
  клик через `getconnections(...MouseButton1Click)[1]:Fire()`, фолбэк
  `VirtualInputManager:SendMouseButtonEvent(x, y, 0, game, 1)`; хэндлер
  `hfClickBtn` общий
- **Выбор по ESP** (v4.35): ребёнок = модель `GhostChild`/имя со «kid»
  ≤25 стд от `FrontDoor` (`hfKidAtDoor`, тот же паттерн что Kid Detector) →
  добираем конфеты мешок→миска и жмём «Открыть»; иначе → «Не замечать»;
  каждые 5 с осмотр двери `hfDoorWho()` печатает в консоль
  «у двери — ребёнок/монстр/пусто» (монстр = `Monster` ≤25 стд от двери)
- Клавиша **F** (фонарик) = `VirtualInputManager:SendKeyEvent(true/false,
  Enum.KeyCode.F, false, game)` — VIM дают не все экзекуторы: если нет,
  одноразовый notify и фарм просит жать F самому
- Монстр: модель `Monster` (kind `memmonster` в ESP-кэше — позиция всегда
  доступна); «у окна» = ≤12 стд от `BasePart`/`Model` с «window» в имени
  (контейнер `Windows` из сканов исключён), кэш окон обновляется раз в 5 с
- `workspace.FakeCandyBag` (ClickDetector, Union, Texture, DoritosBagDisplay)
  — **мешок с конфетами, шаг 1 цикла** (v4.35): юзер объяснил — его нужно
  класть в миску, и уже из миски раздавать детям
- Тогл без флага (OFF на старте), цикл под тройным guard: `RUN_ID` +
  поколение `hfGen` + `hfBusy`/`pickupBusy`/`dupBusy`; вставка целиком в
  `do…end` (лимит 200 локальных luac в main уже упирался)

## Источники (что портировано)

| Источник | Что взяли |
|---|---|
| RM Helper (rawscripts) | ~60 ТП-точек (дом/фабрика/лагерь/Spirit/Mansion/Bunker) |
| RMxploitt (GitHub) | клик `ClickWire`, Anti-Freeze, доставки, электрика-логика |
| script-sources/residence-massacre (GitHub, roblox-ts) | GameId/плейсы, `FusesFried`, `Sparkles.Enabled`, шкала топлива, `Config.*` мутанта |
| Bunker Helper V5 (pastefy `moI6tr9z`, читаемый) | плейс бункера, `Ventilation.Debris`, `PowerGrids[i].Door`, `BunkerRat`, сырые CF (сейф/конец/вент/ген) |
| gist «Night 3» (yancielsicard2-arch, читаемый, лёгкая арифметическая обфускация) | `Flashlight.Battery`→130, `OpenDoor` (тревога кабины), папки Ночи 3 (`Zombies/Halloween.Pumpkins/AmmoPiles/Cabins/ItemSpots`) |
| ScriptBlox | **челлендж решён**: HMAC-SHA256(cookie=`ScR1ptBlx`, данные=`encodeURIComponent(UA)+time`) → cookie `__scriptblox_validation=?token...` + `__scriptblox_ua_`; API **`/api/script/<slug>`** отдаёт JSON с кодом; описания фич вытаскиваются с карточек. Коды большинства скриптов — под логином/обфусцированы |
| pastefy / roscripts / MyzorithHub / Spirit Helper | только реклама или VM-обфускация — **брать нечего** |
| rscripts.net | HTTP 403 |
| youdontknow-creator/RMUH (GitHub, читаемый) → **перенесено v4.19** | ТП: `PressurePanels`, `Pumpkin_1..7.Spot` (случайная тыква), `WorkerHead`, `AmmoPiles`, `HauntedMansion`, `FakeCandyBag`, `SafeSpot`; табы Night 1/2/3, Spirit Helper, Mansion Incident. Пропущено: `kick.Name = ""` (античит — красная линия), бункер-точки y≈82 (не знаю карту — в пустоту не летим), `FuseBox:FireServer(fios…`, «Auto Memorie (Wip)» |
| GitHubTestei/ResidenceMassacre (Rayfield, читаемый) → **частично v4.19** | добавлена точка «Второй этаж (доски)» `(-40,23,-68)`; остальные 3 CF `(-80,4,-134)/(-5,4,-98)` — дубли наших Shack/Power; названия кнопок (TP O2/power box/radio) без координат — пропущены |
| frank590-star (Night 1, читаемый) → **перенесено v4.19** | `Shack=(-79,4.5,-129)`, `FuseBox=(-1,4.5,-92.5)` — кнопки ТП; `Entrance≈наша (дубль)`; `workspace.Mutant.Spy/Asphyxia/HotChocolate` — не проверено, не трогал |
| TheGuestON / Pixeluted (GitHub) | ТП-точки (`FrontDoor/SoundPart/Growling`, ген `-79.725,4.675,-132.755`); Pixeluted старый (2023), содержит обходы (adonis/hookmetamethod) — только структуры |
| ScriptBlox-снippets выдачи → **частично v4.19** | 55878: **kid detector** — СДЕЛАН (тогл «Детект ребёнка (GhostChild)», с v4.22 во вкладке **Воспоминания**, переехал из «Ночи 3»); 241706 auto-wire/Larry notifier — наш auto electric покрывает, notifier не делал; 61029 esp abomination — покрыто расширением Mutant ESP |
| GitHub-скан (2026-10, новый проход) | новых работающих raw/gist/pastefy с кодом СВЕРХ известных не найдено; обф подтверждён: ApexScript0x/RM (MoonVeil 242КБ), manfac9000 (таблица `\068\066…`), flopa2677 (MoonSec); TheGuestON-лоадер → pastebin `PTg2vat8` = 404 |
| residencemassacreprolover/rmprolover (GitHub, читаемый luau-проект mspaint/Obsidian, только Ночь 1) → **перенесено v4.30** | «Запустить цели (радио)» (их CF перед радио + `GameState.Active` с возвратом), «Отключить метель» (`GameState.Blizzard`), «Анти-лаг (Potato)» (Plastic/Reflectance/декали/вода, ORIG-значения в атрибутах). Не взято: Bypass Anticheat (`kick.Name` — красная линия), Trolling (`PlayerMutant` Kill/Trap, фонарь на игрока — гриф), бейджи Electrocuted/Asphyxia, Loop Flash камер (дубль «Флешнуть камеру»), Phase Through Doors (дубль Noclip) |
| TheGuestON (GitHub, **обновлён 2026-07**, UniverseX) → **перенесено v4.30** | «Тревога двери» (`FrontDoor.SoundPart.Growling`, кулдаун 15с), `WorkerHead` в Item ESP (метка по имени — предмета без ClickDetector не было в ESP), ТП «Сейфзона» `(-14, 30, -122)`. Не взято: Window ESP (`Windows.Window[].Monster` + анимации — дубль Auto Scare), «Spawned Entity» (дубль уведомления Auto Scare) |
| thediddydaddler1234/residence-massacre (GitHub, читаемый) → **перенесено v4.30** | кнопка «Бесплатные апгрейды (эксп.)»: `Upgrades.Generator` Max/Price + показ `UpgradeShop`/`Gambler` из `RS.Assets` |
| krepkiioreshek14 / p1shenak (FONDI) / fish991×3 (Fiszok) / balios / gordu / dexter (2026-09 свежие) | мусор: копии с TP по ночам + Noclip (у нас всё есть глубже), FONDI — SpeedHack/Fly/God (против правил проекта), dexter — файл «test», balios — пусто; hanzo `Auto Spirit Helper` — wearedevs-обфускация |
| rawscripts.net → KINGHUB01/BlackKing-obf (через furaf-лоадер с ключом `ScriptVault10`) | 96КБ: читаема только ESP-шапка (имя+дистанция+HP у игроков — уже есть), тело — PUC-обфускация: пропущено |

## Известные несделанное (осознанно)

1. **`pickupBusy` без владельца** — токен-владелец не введён (ревью v4.19 снова
   подсветило: watchdog после сброса не помнит, что поток «старый» — редкая
   гонка на двойной телепорт). Лечится только правкой всех ~10 точек захвата
   (`local tok = busyOn()/busyOff(tok)`) — отложено, watchdog (30с) покрывает.
2. **Сброс пикеров темы** кнопкой «Сбросить тему» — цвета в пикерах GUI остаются
   старыми (косметика; риск сломать рабочую тему).
3. **Fort Blox**: Kill All / No Spread / Auto Pickup — ждут запроса
   (`EliteHub-FortBlox`: есть `HitRemote`/`ShootRemote`/Killfeed, аимбот).
4. Мелкий мёртвый код (присваивания-пустышки) — не чистил нарочно.
5. **Кэширование обходов workspace** (авто-заправка ~4 обхода/0.5с, тик
   электрики 2–3 обхода) — перф-замечания обоих ревью, отложено: рискованно
   ломать рабочие поиски ради скорости.
6. **Disable Static**: имена реальных оверлеев помех неизвестны — если паттерны
   static/noise/vhs/glitch ничего не найдут, скрипт попросит имя из Explorer.
7. **Кик `Remotes.Kick`** — юзер просил `:Destroy()` «для спокойствия»;
   v4.21 сделали по явной просьбе, **v4.34 откатили к щадящему варианту**:
   `Destroy()` удалял ремоут, на который ждёт анти-чит Ночи 3, — кик
   Error 267 сразу после запуска. Сейчас: ремоут на месте, отключаются
   только обработчики `OnClientEvent` (`getconnections`). Серверный кик
   всё равно не блокируется (и раньше не блокировался).
8. **Именные ТП (`tpBtnNames`)** — гейт плейса не ставил: объект существует =
   позиция надёжна (не пустота), но на чужой карте одноимённый объект (Bed/
   Clock/Fireplace) может увести к «чужому» — риск только косметический.
9. **re-run быстрее 4 с** — `task.delay(4, LoadConfiguration)` СТАРОЙ библиотеки
   может успеть позвать `Set` после её `Destroy()` (edge: значения те же,
   уведомления гасятся проверкой `old ~= v`).
10. **`RM_CamView`** (Flag) хранит локализованную подпись, не `G.RM_CamMode` —
    вместо переименования задокументирован приоритет GUI-конфига в README.
11. **Guard в каждом keybind-callback не нужен** — `Rayfield:Destroy()` на старой
    библиотеке рвёт `keybindConnections` целиком; свой `RUN_ID`-guard оставлен
    только в `panicTP` (yield внутри).
12. **Гриф/дубли из чужих скриптов (v4.30-скан)** — `PlayerMutant` Kill/Trap,
    «фонарь на игрока», Window ESP, «Spawned Entity», бейджи Electrocuted/
    Asphyxia осознанно НЕ делаем: не полезно для прохождения, дублирует Auto
    Scare или провоцирует других игроков.
13. **Лимиты апгрейдов** — клиентская запись в ReplicatedStorage не
    реплицируется на сервер; кнопка «Бесплатные апгрейды (эксп.)» ставит
    атрибуты и честно сообщает, что сервер может цену валидировать сам.
14. **`FakeCandyBag` включён в фарм с v4.35** — юзер раскрыл механику: это
    мешок с конфетами, его содержимое кладётся в миску `CandyBowl`, и уже
    из миски раздаётся детям через `FrontDoor.Hitbox`. Цепочка идёт одной
    поездкой (шаги `hfTrip`), порядок: камин → мешок → миска → камин.

## Правки-паттерны (повторять)

- Guard `getgenv().RM_Run ~= RUN_ID` во всех циклах/`task.*` живущих дольше тика
- Код до `notify` (~1875) — только `print`
- Запись свойства — только если отличается (анти-десинк/кик Error 267)
- `pcall` с yield — ок; **yield НЕ вложен в pcall с return-потоком ломать**
- Сентинелы кулдаунов — `-1e9` (не `0`: `os.clock()` бывает < 15 на старте)
- У `ClickDetector` **нет** `.Position` — только `objPos()` от модели
- Бинды Rayfield: строковый `CurrentKeybind` + `Flag`; тоглы автокнопок — без Flag

## Правила проекта (红线)

- ❌ Обход античита / киков (`Kick`), иммунитеты через `Delete/Destroy` игровых
  объектов (LookAt, хитбоксы, DeathHandler). `Destroy()` ремоутов запрещён
  вовсе: у `Remotes.Kick` он и дал кик Error 267 на Ночи 3 (v4.34) —
  анти-кик работает только отключением подписок (`getconnections`)
- ❌ `WalkSpeed` (кик) — только TP walk
- ❌ Подписи CreateLabel в GUI (CreateSection — можно)
- ✅ Везде плавный TweenService, ввод кликами мыши, бекапы перед пушем
  (`ResidenceMassacre_BACKUPS\<файл>_<версия>_<хэш>.lua`)
