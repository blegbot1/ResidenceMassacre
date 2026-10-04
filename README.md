# Residence Massacre — Fullbright

Клиентский скрипт под **Residence Massacre**: **Fullbright** (видно в темноте).

Меняет только клиентские свойства `Lighting`. Никакого вмешательства в сервер, обхода защиты или античита нет.

> **Speed убран:** у игры серверная проверка скорости — кикает сразу на движении. Обходить её не будем.

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

Окно **ELITE HUB** на библиотеке **Rayfield** (чёрно-фиолетовая тема, плавный градиент на шапке), как в Fort Blox. Конфиг хранится в папке `RMScripts`.

Значения переприменяются **раз в секунду** (слайдер **Check every**, 0.1–5 с) и **только если реально отличаются** — постоянные записи свойств вызывали desync и кик с Error 267.

**Скорости в скрипте нет** — сервер Residence Massacre валидирует скорость движения и кикает без обхода античита. Fullbright работает сразу после запуска.

## Флаги (задать до запуска)

```lua
getgenv().RM_FB      = true  -- fullbright
getgenv().RM_Bright  = 3     -- яркость 0..10
getgenv().RM_NoFog   = true  -- без тумана и теней
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