--[[
    DT_Timer — библиотека таймеров
    Предоставляет функции After, NewTimer, NewTicker и т.п., совместимо с клиентом 1.12
    Используется в аддоне для отложенного выполнения и циклического запуска задач
--]]

-- Генерация таймера
local function GenerateTimer()
    local Timer = CreateFrame("Frame")
    local TimerObject = {}

    Timer.Infinite = 0  -- -1 бесконечный цикл, 0 остановка, 1..n выполнить цикл n раз
    Timer.ElapsedTime = 0

    -- Запуск таймера
    function Timer:Start(duration, callback)
        if type(duration) ~= "number" then
            duration = 0
        end

        self:SetScript("OnUpdate", function()
            self.ElapsedTime = self.ElapsedTime + arg1

            -- Достигли заданного времени — выполняем callback
            if self.ElapsedTime >= duration and type(callback) == "function" then
                callback()
                self.ElapsedTime = 0

                -- Проверяем, нужно ли продолжать циклы
                if self.Infinite == 0 then
                    self:SetScript("OnUpdate", nil)
                elseif self.Infinite > 0 then
                    self.Infinite = self.Infinite - 1
                end
            end
        end)
    end

    -- Проверка: отменён ли таймер
    function TimerObject:IsCancelled()
        return not Timer:GetScript("OnUpdate")
    end

    -- Отмена таймера
    function TimerObject:Cancel()
        if Timer:GetScript("OnUpdate") then
            Timer:SetScript("OnUpdate", nil)
            Timer.Infinite = 0
            Timer.ElapsedTime = 0
        end
    end

    return Timer, TimerObject
end

-- Эмуляция библиотеки DT_Timer
if not DT_Timer then
    DT_Timer = {
        -- Выполнить callback через duration секунд
        After = function(duration, callback)
            GenerateTimer():Start(duration, callback)
        end,
        -- Создать одноразовый таймер
        NewTimer = function(duration, callback)
            local timer, timerObj = GenerateTimer()
            timer:Start(duration, callback)
            return timerObj
        end,
        -- Создать циклический таймер (ticker), можно указать число повторов
        NewTicker = function(duration, callback, ...)
            local timer, timerObj = GenerateTimer()
            local iterations = unpack(arg)

            if type(iterations) ~= "number" or iterations < 0 then
                iterations = 0  -- Бесконечный цикл
            end

            timer.Infinite = iterations - 1
            timer:Start(duration, callback)
            return timerObj
        end
    }
end
