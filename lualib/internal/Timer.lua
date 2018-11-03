require "internal.coroutine"
require "utils"

local ti = core_timer

local Timer = {}

local TIMER_LIST = {}

function Timer.get_timer()
    if #TIMER_LIST > 0 then
        return table.remove(TIMER_LIST)
    end
    return ti.new()
end

-- 超时器 --
function Timer.timeout(timeout, cb)
    if not timeout or timeout < 0 then
        return
    end
    ti = Timer.get_timer()
    if not ti then
        LOG("INFO", "new timer class error! memory maybe not enough...")
        return
    end
    local timer = {}
    timer.ti = ti
    timer.current_co = co_self()
    timer.cb = cb
    timer.closed = nil
    function timer_out( ... )
        if not timer.closed then
            local ok, msg = pcall(timer.cb)
            if not ok then
               LOG("INFO", "timer_out error:", msg)
            end
        end
        table.insert(TIMER_LIST, timer.ti)
        timer.ti:stop()
        timer = nil
        return
    end
    timer.co = co_new(timer_out)
    timer.ti:start(timeout, timeout, timer.co)
end

-- 定时器 --
function Timer.ti(repeats, cb)
    if not repeats or repeats < 0 then
        return
    end
    local ti = Timer.get_timer()
    if not ti then
        LOG("INFO", "new timer class error! memory maybe not enough...")
        return
    end
    local timer = {}
    timer.ti = ti
    timer.repeats = repeats
    timer.current_co = co_self()
    timer.cb = cb
    timer.closed = nil
    function timer_repeats( ... )
        while 1 do
            if timer.closed then
                table.insert(TIMER_LIST, timer.ti)
                timer.ti:stop()
                timer = nil
                return
            end
            local ok, msg = pcall(timer.cb)
            if not ok then
                table.insert(TIMER_LIST, timer.ti)
                timer.ti:stop()
                timer = nil
                LOG("ERROR", "timer_repeats error:", msg)
                return
            end
            co_suspend()
        end
    end
    timer.co = co_new(timer_repeats)
    timer.ti:start(repeats, repeats, timer.co)
    return timer
end

-- 仅让出执行权 --
function Timer.sleep(second)
    if not second or second < 0 then
        return
    end
    local ti = Timer.get_timer()
    if not ti then
        LOG("INFO", "new timer class error! memory maybe not enough...")
        return
    end
    local timer = { }
    timer.ti = ti
    timer.current_co = co_self()
    timer.co = co_new(function ( ... )
        local co = timer.co
        local ti = timer.ti
        local current_co = timer.current_co
        table.insert(TIMER_LIST, ti)
        ti:stop()
        co_wakeup(current_co)
        timer = nil
    end)
    timer.ti:start(second, second, timer.co)
    return co_suspend()
end

return Timer