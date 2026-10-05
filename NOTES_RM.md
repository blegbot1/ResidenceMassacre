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

## Источники (что портировано)

| Источник | Что взяли |
|---|---|
| RM Helper (rawscripts) | ~60 ТП-точек (дом/фабрика/лагерь/Spirit/Mansion/Bunker) |
| RMxploitt (GitHub) | клик `ClickWire`, Anti-Freeze, доставки, электрика-логика |
| script-sources/residence-massacre (GitHub, roblox-ts) | GameId/плейсы, `FusesFried`, `Sparkles.Enabled`, шкала топлива, `Config.*` мутанта |
| pastefy / roscripts / MyzorithHub / Spirit Helper | только реклама или VM-обфускация — **брать нечего** |
| scriptblox / rscripts.net | HTTP 403 (JS-челлендж) |

## Известные несделанное (осознанно)

1. **`pickupBusy` без владельца** — токен-владелец не введён: watchdog (30с)
   покрывает залипание, а смена владельца требует правки всех ~8 точек захвата.
2. **Сброс пикеров темы** кнопкой «Сбросить тему» — цвета в пикерах GUI остаются
   старыми (косметика; риск сломать рабочую тему).
3. **Fort Blox**: Kill All / No Spread / Auto Pickup — ждут запроса
   (`EliteHub-FortBlox`: есть `HitRemote`/`ShootRemote`/Killfeed, аимбот).
4. Мелкий мёртвый код (присваивания-пустышки) — не чистил нарочно.

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
