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
| Плейс — The Bunker | `100255403764514` (из Bunker Helper V5; в `ONLY_PLACE_IDS` на случай отдельного юниверса) |

В коде: `RM_GAME_ID` + `ONLY_PLACE_IDS` (оба выключены = старт в любой игре).

## Структуры игры (подтверждено)

### Общее
- `ReplicatedStorage.Remotes` — `ClickWire`, `Repair`, `Delivery`, `EscapeSnatch`,
  `LoadCharacter`, `FlashCam`, `Kick` (**Kick не трогать — это и есть античит**)
- `ReplicatedStorage.GameState.FusesFried` (bool) — **true = свет вырубили**
  (= есть битые проводы). Ложится в гейт Auto electric.
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

### Ночь 2
- `PowerCell` — Model с `ClickDetector` **вне** Generator; вставка — клик по
  Generator
- Ремоуты: `Repair` (провод 1–4), `Delivery` (Camera/Lock/UVLamp/MotionSensor),
  `EscapeSnatch`, `LoadCharacter` (Revive)
- Координаты новой карты: y ≈ 82 (главный зал/вход/коридоры/доска доставок/укрытие)

### ESP / предметы
- Любой `ClickDetector` / `ProximityPrompt` в workspace = предмет (Item ESP)
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
- Abomination = Model **`BunkerRat`** (в ESP пока не заведено — имена монстров
  бункера не пересекаются с `*mutant*`)

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
   отказано (античит, красная линия) + технически бессмысленно (сервер держит
   свою ссылку).
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
  объектов (LookAt, хитбоксы, DeathHandler)
- ❌ `WalkSpeed` (кик) — только TP walk
- ❌ Подписи CreateLabel в GUI (CreateSection — можно)
- ✅ Везде плавный TweenService, ввод кликами мыши, бекапы перед пушем
  (`ResidenceMassacre_BACKUPS\<файл>_<версия>_<хэш>.lua`)
