# ELITE BRIGHT — Fullbright + Speed

Универсальный клиентский скрипт для Roblox: **Fullbright** и **настраиваемая скорость**.
Работает в любой игре (изначально сделано под **Residence Massacre**).

---

## Запуск одной строкой

Вставь в executor и нажми Execute:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/blegbot1/EliteBright-Speed/refs/heads/main/Fullbright_Speed.lua",true))()
```

Или используй `loader.lua` — он тянет тот же файл с проверкой ошибок.

### Автозапуск при входе в игру

Впиши строку выше в **Autoexec** экзекутора. Чтобы работало **только** в нужной игре:

```lua
if game.PlaceId == ТУТ_ID_ИГРЫ then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/blegbot1/EliteBright-Speed/refs/heads/main/Fullbright_Speed.lua",true))()
end
```

---

## Возможности

| Элемент | Что делает |
|---|---|
| **Fullbright** | `Lighting.Brightness`, `ClockTime = 14`, белые `Ambient` / `OutdoorAmbient` / `ColorShift` — видно во всех тёмных зонах |
| **No fog / shadows** | `GlobalShadows = false`, `FogStart = -100000`, `FogEnd = 100000` — без тумана |
| **Brightness** | слайдер 0–10, шаг 0.5 |
| **Speed hack** | тогл скорости |
| **Speed** | слайдер 0–300, шаг 1 (по умолчанию 50) |

Окно можно **перетаскивать** за верхнюю полосу. Тёмно-фиолетовая тема, как у ELITE HUB.

Все значения переприменяются **каждые 0.05 сек** — игры обычно сбрасывают свет и `WalkSpeed` своими скриптами. На респавне скрипт цепляется заново через `CharacterAdded`, перезаходить не нужно.

## Флаги (можно задать до запуска)

```lua
getgenv().EB_FB      = true  -- fullbright
getgenv().EB_Bright  = 3     -- яркость 0..10
getgenv().EB_NoFog   = true  -- без тумана и теней
getgenv().EB_SpeedOn = true
getgenv().EB_Speed   = 50    -- скорость 0..300
```

## Структура

```
EliteBright-Speed/
├── Fullbright_Speed.lua   # сам скрипт
├── loader.lua             # лоадер с raw-ссылки
├── README.md
└── .gitignore
```

## Про античит

Скрипт меняет **только клиентские свойства** (`Lighting`, `Humanoid.WalkSpeed`) — никакого обхода защиты, инжектов или вмешательства в сеть. Если игра серверно возвращает эти значения обратно, обходить её реакцию скрипт не будет.

## Ответственность

Использование — на свой страх и риск. Правила игры стоит прочитать перед запуском.