# Residence Massacre — Fullbright + Speed

Клиентский скрипт под **Residence Massacre**: **Fullbright** и **настраиваемая скорость**.

Меняет только клиентские свойства (`Lighting`, `Humanoid.WalkSpeed`). Никакого вмешательства в сервер, обхода защиты или античита нет.

---

## Запуск одной строкой

Вставь в executor и нажми Execute:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/blegbot1/ResidenceMassacre/refs/heads/main/ResidenceMassacre.lua",true))()
```

Или используй `loader.lua` — он тянет тот же файл и пишет в консоль причину, если что-то пошло не так.

### Только для Residence Massacre

```lua
if game.PlaceId == ТУТ_ID then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/blegbot1/ResidenceMassacre/refs/heads/main/ResidenceMassacre.lua",true))()
end
```

То же самое можно вписать в начало самого `ResidenceMassacre.lua` — там есть константа `ONLY_PLACE_ID` (по умолчанию `nil`, то есть скрипт стартует в любой игре; впиши ID, и он будет работать только в Residence Massacre).

---

## Возможности

| Элемент | Что делает |
|---|---|
| **Fullbright** | `Brightness`, `ClockTime = 14`, белые `Ambient` / `OutdoorAmbient` / `ColorShift` — видно в тёмных зонах |
| **No fog / shadows** | `GlobalShadows = false`, `FogStart = -100000`, `FogEnd = 100000` |
| **Brightness** | слайдер 0–10, шаг 0.5 |
| **Speed hack** | тогл скорости |
| **Speed** | слайдер 0–300, шаг 1 (по умолчанию 50) |

Окно тёмно-фиолетовое, перетаскивается за верхнюю полосу.

**Про ввод:** клики обрабатываются вручную через `UserInputService` + хит-тест по координатам, а не через `GuiObject.MouseButton1Click`. Так кнопки не перехватываются UI игры (в Residence Massacre стандартные клики по GuiObject не доходили). Подсветка кнопки при наведении есть.

Значения переприменяются **раз в секунду** (слайдер **Check every**, 0.1–5 с) и **только если реально отличаются** — постоянные записи свойств вызывали desync и кик с Error 267. На респавне скрипт цепляется заново через `CharacterAdded`.

**Speed hack по умолчанию ВЫКЛ** — именно скорость чаще всего вызывает кик. Fullbright работает сразу после запуска.

## Флаги (задать до запуска)

```lua
getgenv().RM_FB      = true  -- fullbright
getgenv().RM_Bright  = 3     -- яркость 0..10
getgenv().RM_NoFog   = true  -- без тумана и теней
getgenv().RM_SpeedOn = true
getgenv().RM_Speed   = 50    -- скорость 0..300
```

## Структура

```
ResidenceMassacre/
├── ResidenceMassacre.lua   # сам скрипт
├── loader.lua              # лоадер с raw-ссылки
├── README.md
└── .gitignore
```

## Про античит

Скрипт трогает только клиентские свойства. Если игра серверно возвращает их обратно — обходить её реакцию скрипт не будет.

## Ответственность

Использование — на свой страх и риск, правила игры лучше прочитать.