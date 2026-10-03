-- ============================================================
--  RESIDENCE MASSACRE — LOADER
--  Загружает актуальный скрипт с GitHub.
--
--  ОДНА СТРОКА ДЛЯ ЗАПУСКА (вставь в executor):
--  loadstring(game:HttpGet("https://raw.githubusercontent.com/blegbot1/ResidenceMassacre/refs/heads/main/ResidenceMassacre.lua",true))()
--
--  Автозапуск только в этой игре:
--  if game.PlaceId == ТУТ_ID then
--      loadstring(game:HttpGet("https://raw.githubusercontent.com/blegbot1/ResidenceMassacre/refs/heads/main/ResidenceMassacre.lua",true))()
--  end
-- ============================================================

local URL = "https://raw.githubusercontent.com/blegbot1/ResidenceMassacre/refs/heads/main/ResidenceMassacre.lua"

-- защита только от случайного двойного запуска (5 секунд)
local g = getgenv()
local now = os.clock()
if g.RM_LOADED_AT and (now - g.RM_LOADED_AT) < 5 then
    warn("[RESIDENCE MASSACRE] только что запущен, подожди 5 сек")
    return
end
g.RM_LOADED_AT = now

print("[RESIDENCE MASSACRE] загрузка:", URL)

local ok, err = pcall(function()
    local src = game:HttpGet(URL, true)
    if type(src) ~= "string" or #src < 100 then
        error("пустой или битый ответ")
    end
    local chunk = loadstring(src, "ResidenceMassacre")
    if not chunk then
        error("loadstring вернул nil — синтаксис сломан")
    end
    chunk()
end)

if not ok then
    g.RM_LOADED_AT = nil
    warn("[RESIDENCE MASSACRE] ошибка загрузки:", err)
    error("[RESIDENCE MASSACRE] не удалось загрузить скрипт: " .. tostring(err))
end

print("[RESIDENCE MASSACRE] готово")