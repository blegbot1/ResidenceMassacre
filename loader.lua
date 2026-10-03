-- ============================================================
--  ELITE BRIGHT | Fullbright + Speed — LOADER
--  Запускай в любой Roblox-игре (изначально делалось под
--  Residence Massacre).
--
--  ОДНА СТРОКА ДЛЯ ЗАПУСКА (вставь в executor):
--  loadstring(game:HttpGet("https://raw.githubusercontent.com/blegbot1/EliteBright-Speed/refs/heads/main/Fullbright_Speed.lua",true))()
-- ============================================================

local URL = "https://raw.githubusercontent.com/blegbot1/EliteBright-Speed/refs/heads/main/Fullbright_Speed.lua"

-- защита только от случайного двойного запуска (5 секунд)
local g = getgenv()
local now = os.clock()
if g.EB_LOADED_AT and (now - g.EB_LOADED_AT) < 5 then
    warn("[ELITE BRIGHT] только что запущен, подожди 5 сек")
    return
end
g.EB_LOADED_AT = now

print("[ELITE BRIGHT] загрузка:", URL)

local ok, err = pcall(function()
    local src = game:HttpGet(URL, true)
    if type(src) ~= "string" or #src < 100 then
        error("пустой или битый ответ")
    end
    local chunk = loadstring(src, "Fullbright_Speed")
    if not chunk then
        error("loadstring вернул nil — синтаксис сломан")
    end
    chunk()
end)

if not ok then
    g.EB_LOADED_AT = nil
    warn("[ELITE BRIGHT] ошибка загрузки:", err)
    error("[ELITE BRIGHT] не удалось загрузить скрипт: " .. tostring(err))
end

print("[ELITE BRIGHT] готово")