-- Регистрация звуков для мода caseopen

-- Правильный способ регистрации звуков в Minetest
minetest.registered_sounds = minetest.registered_sounds or {}

-- Регистрация звука открытия кейса
minetest.registered_sounds["caseopen_case_open"] = {
    filename = minetest.get_modpath("caseopen") .. "/sound/case_open.ogg",
    gain = 1.0,
}

-- Регистрация звука выигрыша
minetest.registered_sounds["caseopen_win"] = {
    filename = minetest.get_modpath("caseopen") .. "/sound/win.ogg", 
    gain = 1.0,
}