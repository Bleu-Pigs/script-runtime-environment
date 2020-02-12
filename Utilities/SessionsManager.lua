local SessionsManager = {}
local threadToSession = setmetatable(
    {},
    {
        __mode = "k"
    }
)

local objectSession = {prototype = {}}

function SessionsManager.new(coroutineThread)
    if threadToSession[coroutineThread] then
        return false, string.format(
            "%s is already registered to a Session"
        )
    end

    local newSession = setmetatable(
        {
            _data = {},
            _threads = setmetatable({}, {__mode = "v"})
        },
        objectSession
    )
    threadToSession[coroutineThread] = newSession

    return newSession
end

function objectSession:addThread(coroutineThread)
    if not coroutineThread then
        coroutineThread = coroutine.running()
    end
    if threadToSession[coroutineThread] then
        return false, string.format(
            "%s is already registered to a Session"
        )
    end

    threadToSession[coroutineThread] = self
    table.insert(self._threads, coroutineThread)

    return true 
end

function objectSession:removeThread(coroutineThread)
    if not coroutineThread then
        coroutineThread = coroutine.running()
    end
    if not threadToSession[coroutineThread] then
        return false, string.format(
            "%s is not associated to a Session"
        )
    end

    threadToSession[coroutineThread] = nil
    table.remove(self._threads, table.find(self._threads, coroutineThread))

    return true
end

function objectSession:destroy()
    for key, thread in next, self._threads do
        threadToSession[thread] = nil
    end
    for key, value in next, self do
        self[key] = nil
    end
    self = nil

    return true
end

return SessionsManager



