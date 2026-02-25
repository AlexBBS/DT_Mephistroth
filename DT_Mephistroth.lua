--[[
    Mephistroth помощник отключения клавиш (главный файл)
    Когда BOSS Mephistroth начинает кастовать “Shackles of the Legion!”,
    автоматически отключает WASD и стрелки, через 10 секунд включает обратно.
    Подходит для World of Warcraft Turtle (1.12.x)
    Автор: 果盘杀手, 二狗子 - 天空之城（乌龟拉风服务器）
	Автор2: AlexBBS (гильдия "Москва")
--]]

-- Список клавиш для отключения: стандартные клавиши движения + стрелки
local wasdKeys = { "W", "A", "S", "D", "UP", "DOWN", "LEFT", "RIGHT", "SPACE" } 

-- Таблица для хранения исходных биндов каждой клавиши, чтобы потом восстановить
local originalBindings = {}

-- Таблица локализации (мультиязычность)
local locale = GetLocale()
local L = {}
local CHECK_STEP = 0.1
local DISABLE_DELAY = 1.5
local MAX_TRIES = 16 -- Попыток определения движения. 0.1 мс(CHECK_STEP) * на 15 (MAX_TRIES) = 1.5 Сек
local pending = false
local dbgTicker = nil
local dbgOn = false
local fearStartTime = nil
local fearAccumulated = 0

if locale == "zhCN" then
    L.BOSS_CAST = "Mephistroth begins to cast Shackles of the Legion"
    L.BOSS_CAST_CN = "孟菲斯托斯开始施放军团镣铐"
    L.BIGMSG = "【DT_Mephistroth】警告!!!警告!!!，请松开WASD/方向键！"
elseif locale == "zhTW" then
    L.BOSS_CAST = "Mephistroth begins to cast Shackles of the Legion"
    L.BOSS_CAST_CN = "梅菲斯托斯開始施放軍團鐐銬"
    L.BIGMSG = "【DT_Mephistroth】警告!!!警告!!!，請鬆開WASD/方向鍵！"
else
    L.BOSS_CAST = "Mephistroth begins to cast Shackles of the Legion"
    L.BOSS_CAST_CN = nil
    L.BIGMSG = "[DT_Mephistroth] КТО ДВИНЕТСЯ ТОТ ФРИКАЛИНИ!"
end





local WATCH_DEBUFF_PATTERNS = {
    "shackles of the legion",
    "nathrezim terror",
}


local DTM_DebuffTip = CreateFrame("GameTooltip", "DTM_DebuffTip", UIParent, "GameTooltipTemplate")
DTM_DebuffTip:SetOwner(UIParent, "ANCHOR_NONE")
local _tipName = DTM_DebuffTip:GetName()

local function TipLine(i)
    local fs = _G[_tipName .. "TextLeft" .. i]
    return fs and fs:GetText() or nil
end

local function DebuffMatchesTooltip()
    local i = 1
    while true do
        local tex = UnitDebuff("player", i)
        if not tex then break end

        -- читаем tooltip дебафа
        if DTM_DebuffTip.SetUnitDebuff then
            DTM_DebuffTip:ClearLines()
            DTM_DebuffTip:SetOwner(UIParent, "ANCHOR_NONE")
            DTM_DebuffTip:SetUnitDebuff("player", i)

            -- проверяем несколько строк тултипа
            for lineIdx = 1, 6 do
                local t = TipLine(lineIdx)
                if t then
                    local low = string.lower(t)
                    for _, pat in ipairs(WATCH_DEBUFF_PATTERNS) do
                        if string.find(low, pat, 1, true) then
                            -- возвращаем “что нашли”: обычно первая строка — имя дебафа
                            return TipLine(1) or t
                        end
                    end
                end
            end
        end

        i = i + 1
    end

    return nil
end

-- Временный “слушатель” аур: включаем на N секунд из DisableWASD()
local DTM_AuraWatchFrame = CreateFrame("Frame")
DTM_AuraWatchFrame:RegisterEvent("PLAYER_AURAS_CHANGED")
DTM_AuraWatchFrame:RegisterEvent("UNIT_AURA")

local _watchActive = false
local _watchUntil = 0
local _watchAnnounced = false

local function StartWatchDebuffs(seconds)
    _watchActive = true
    _watchAnnounced = false
    _watchUntil = GetTime() + (seconds or 12)

    -- сразу проверим (вдруг дебаф уже висит)
    local found = DebuffMatchesTooltip()
    if found then
        _watchAnnounced = true
        _watchActive = false
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[DT_Mephistroth]|r Обнаружен дебафф: " .. found)
    end
end

DTM_AuraWatchFrame:SetScript("OnEvent", function()
    if not _watchActive then return end

    -- для UNIT_AURA фильтруем юнит
    if event == "UNIT_AURA" and arg1 and arg1 ~= "player" then
        return
    end

    if GetTime() > _watchUntil then
        _watchActive = false
        return
    end

    if _watchAnnounced then return end

    local found = DebuffMatchesTooltip()
    if found then
        _watchAnnounced = true
        _watchActive = false
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[DT_Mephistroth]|r Обнаружен дебафф: " .. found)
    end
end)

-- Диагностика: показать как реально называются дебаффы и что в тултипе
SLASH_DTMDUMP1 = "/dtmdump"
SlashCmdList["DTMDUMP"] = function()
    DEFAULT_CHAT_FRAME:AddMessage("|cffffff00[DT_Mephistroth]|r Debuff dump:")
    local i = 1
    while UnitDebuff("player", i) do
        DTM_DebuffTip:ClearLines()
        DTM_DebuffTip:SetOwner(UIParent, "ANCHOR_NONE")
        if DTM_DebuffTip.SetUnitDebuff then
            DTM_DebuffTip:SetUnitDebuff("player", i)
        end
        local name = TipLine(1) or "<?>"
        local l2 = TipLine(2) or ""
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  #%d: %s %s", i, name, (l2 ~= "" and ("- "..l2) or "")))
        i = i + 1
    end
end
















-- Функция показа большого сообщения крупным шрифтом
local function ShowBigMessage(msg)
    if not DT_Mephistroth_BigMsg then
        local f = CreateFrame("Frame", "DT_Mephistroth_BigMsg", UIParent)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetWidth(800) -- Шире
        f:SetHeight(800) -- Выше
        f:SetPoint("CENTER", 0, 0)
        -- Чёрный фон
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture(0, 0, 0, 0.6) -- В 1.12 используется SetTexture вместо SetColorTexture
        f.bg = bg
        local text = f:CreateFontString(nil, "OVERLAY")
        text:SetFont("Fonts\\FRIZQT__.TTF", 120, "OUTLINE") -- Ещё крупнее шрифт
        text:SetAllPoints()
        text:SetJustifyH("CENTER")
        text:SetJustifyV("MIDDLE")
        text:SetTextColor(1, 0, 0) -- Красный цвет
        f.text = text
        f:Hide()
    end
    DT_Mephistroth_BigMsg.text:SetText(msg)
    DT_Mephistroth_BigMsg.text:SetTextColor(1, 0, 0) -- Каждый раз принудительно красный
    DT_Mephistroth_BigMsg:Show()
    -- Автоскрытие через 10 секунд
    DT_Timer.After(10, function() DT_Mephistroth_BigMsg:Hide() end)
end

-- Проверка: движется ли игрок
local playerMoveState = { lastX=nil, lastY=nil, lastTime=0, lastMoving=false }

local function PlayerIsMoving()
    if moveEventSeen then
        return moving
    end

    if SetMapToCurrentZone then SetMapToCurrentZone() end
    local x, y = GetPlayerMapPosition("player")
    local now = GetTime()

    if not x or not y then
        return playerMoveState.lastMoving
    end

    if not playerMoveState.lastX then
        playerMoveState.lastX, playerMoveState.lastY = x, y
        playerMoveState.lastTime = now
        playerMoveState.lastMoving = false
        return false
    end

    local dt = now - (playerMoveState.lastTime or 0)
    if dt < 0.1 then
        return playerMoveState.lastMoving
    end

    local dx = x - playerMoveState.lastX
    local dy = y - playerMoveState.lastY
    local moved = (dx*dx + dy*dy) > 1e-10

    playerMoveState.lastX, playerMoveState.lastY = x, y
    playerMoveState.lastTime = now
    playerMoveState.lastMoving = moved

    return moved
end

local dbgFrame = CreateFrame("Frame")
local dbgAcc = 0
local dbgOn = false

local function DbgMsg(s)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[DTMDBG]|r "..s)
end

local function StartMoveDebug()
    if dbgOn then return end
    dbgOn = true
    dbgAcc = 0
    DbgMsg("debug ON (OnUpdate)")

    dbgFrame:SetScript("OnUpdate", function()
        dbgAcc = dbgAcc + arg1
        if dbgAcc < 0.2 then return end
        dbgAcc = 0

        if SetMapToCurrentZone then SetMapToCurrentZone() end
        local x, y = GetPlayerMapPosition("player")

        DbgMsg(string.format(
            "evtSeen=%s movingEvt=%s  x=%.5f y=%.5f  PlayerIsMoving()=%s",
            tostring(moveEventSeen), tostring(moving),
            x or -1, y or -1,
            tostring(PlayerIsMoving())
        ))
    end)
end

local function StopMoveDebug()
    if not dbgOn then return end
    dbgOn = false
    dbgFrame:SetScript("OnUpdate", nil)
    DbgMsg("debug OFF")
end

SLASH_DTMDBG1 = "/dtmdbg"
SlashCmdList["DTMDBG"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "on" then
        StartMoveDebug()
    else
        StopMoveDebug()
    end
end

local function WarnRestore3s()
    DEFAULT_CHAT_FRAME:AddMessage("WASD включится через 3 секунды")

end

local function PlayerIsFeared()
    local i = 1
    while true do
        local buff = UnitDebuff("player", i)
        if not buff then break end

        buff = string.lower(buff)
        if string.find(buff, "fear")
           or string.find(buff, "страх")
           or string.find(buff, "ужас") then
            return true
        end
        i = i + 1
    end
    return false
end
local function UpdateFearTime()
    local now = GetTime()
    local feared = PlayerIsFeared()

    if feared then
        if not fearStartTime then
            fearStartTime = now
        end
    else
        if fearStartTime then
            fearAccumulated = fearAccumulated + (now - fearStartTime)
            fearStartTime = nil
        end
    end
end
-- Функция восстановления исходных биндов WASD и связанных клавиш
local function RestoreWASD()
    -- Проходим по сохранённым биндам
    for key, action in pairs(originalBindings) do
        -- Восстанавливаем исходное действие (например MOVEFORWARD и т.п.)
        SetBinding(key, action)
    end
    -- Сохраняем текущий набор биндов, чтобы восстановление точно применилось
    SaveBindings(GetCurrentBindingSet())
	disabled = false
	DT_MEPH:Sound("begi")
end

-- Реальное отключение клавиш движения
local function ReallyDisableWASD()
    -- если фир ещё идёт — добираем время
    if fearStartTime then
        fearAccumulated = fearAccumulated + (GetTime() - fearStartTime)
        fearStartTime = nil
    end

    local RESTORE_TOTAL = 8.5
    local restoreDelay = RESTORE_TOTAL - fearAccumulated
    if restoreDelay < 0 then restoreDelay = 0 end

    -- сбрасываем на следующий каст
    fearAccumulated = 0

    for _, key in ipairs(wasdKeys) do
        originalBindings[key] = GetBindingAction(key)
        SetBinding(key)
    end
    SaveBindings(GetCurrentBindingSet())

    DT_Timer.After(restoreDelay, RestoreWASD)
end
-- ==== ГЛАВНОЕ: DisableWASD ====
-- Проверяем движение 1.5 сек (15 раз по 0.1).
-- Если в окне был момент "стою" -> отключаем ровно в t=1.5 сек (компенсируем оставшееся время)
-- DISABLE_DELAY = 1.5
-- CHECK_STEP = 0.1
-- MAX_TRIES = 15  -- обязательно соответствует 1.5/0.1

local function DisableWASD()
    DT_MEPH:Sound("stoyat")
    DEFAULT_CHAT_FRAME:AddMessage("WASD Выключиться через 1.5 секунды")
	StartWatchDebuffs(12)
    if pending == true then return end
    pending = true

    local tries = 0
    local hadStop = false

    -- чтобы писать об обнаружении только один раз за этот запуск
    local debuffAnnounced = false

    local function poll()
        tries = tries + 1

        -- ОБЯЗАТЕЛЬНО каждый тик
        UpdateFearTime()

        -- >>> НОВОЕ: проверяем дебаффы
		if not debuffAnnounced then
			local found = DebuffMatchesTooltip()
			if found then
				debuffAnnounced = true
				DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[DT_Mephistroth]|r Обнаружен дебафф: "..found)
			end
		end
        -- <<< НОВОЕ

        local feared = PlayerIsFeared()
        local isMoving = PlayerIsMoving() == true

        if feared then
            isMoving = true
        end

        if isMoving == false then
            hadStop = true
        end

        if tries >= MAX_TRIES then
            pending = false
            UpdateFearTime()

            if hadStop == true and PlayerIsMoving() == false and not PlayerIsFeared() then
                ReallyDisableWASD()
            else
                ShowBigMessage("НУ ЧТО, ТЫ ВСЕ ПРОЕБАЛ!")
                DT_MEPH:Sound("krasava")
            end
            return
        end

        DT_Timer.After(CHECK_STEP, poll)
    end

    DT_Timer.After(CHECK_STEP, poll)
end



-- Обработчик событий чата
-- Когда ловим фразу “Mephistroth begins to cast Shackles ...” — отключаем клавиши на 10 секунд
local function OnChatMessage(event, message)
    if not message then return end
    -- Проверяем, что это нужная реплика босса (с учётом локализации)
    if string.find(message, L.BOSS_CAST)
        or (L.BOSS_CAST_CN and string.find(message, L.BOSS_CAST_CN)) then
        DisableWASD()
        ShowBigMessage(L.BIGMSG)
    end
end

-- Создаём Frame для отслеживания событий чата
local frame = CreateFrame("Frame")
-- Регистрируем событие эмоутов/криков рейдового босса
frame:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
-- Регистрируем канал рейд-лидера
frame:RegisterEvent("CHAT_MSG_RAID_LEADER")
-- Регистрируем рейд-чат (если нужно)
-- frame:RegisterEvent("CHAT_MSG_RAID")
-- Назначаем обработчик событий: при событии вызываем OnChatMessage
frame:SetScript("OnEvent", function()
    -- Отладка в чат (если нужно)
    -- DEFAULT_CHAT_FRAME:AddMessage("Event: " .. event .. ", Message: " .. arg1)
    -- Обработка события
    OnChatMessage(event, arg1)
end)


-- ==== ТЕСТ ====

SLASH_DTMTEST1 = "/dtmtest"
SlashCmdList["DTMTEST"] = function()
    DisableWASD()
end

SLASH_DTMRESTORE1 = "/dtmrestore"
SlashCmdList["DTMRESTORE"] = function()
    DEFAULT_CHAT_FRAME:AddMessage("ТЕСТ WASD: включено")
    RestoreWASD()
end

SLASH_DTMDBG1 = "/dtmdbg"
SlashCmdList["DTMDBG"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "on" then
        StartMoveDebug()
    else
        StopMoveDebug()
    end
end

