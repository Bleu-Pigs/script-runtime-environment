return function(api)

api.prototype = {}
api.__index = api.prototype

function api.new()
    local self = setmetatable(
        {
            _threadToSession = setmetatable({}, {__mode = "k"})
        },
        api
    )

    return self
end

local Session = {prototype = {}}
Session.__index = Session.prototype

function api:createSession()
    local newSession = setmetatable(
        {
            _manager = self,
            _thread = setmetatable({}, {__mode = "k"}),
            _data = {}
        },
        Session
    )

    return newSession
end

function Session:addThread(coroutineThread)
    if not coroutineThread then
        coroutineThread = coroutine.running()
    end
    if self._manager._threadToSession[coroutineThread] then
        return false, string.format(
            "%s is already registered to a Session"
        )
    end

    self._manager._threadToSession[coroutineThread] = self
    table.insert(self._threads, coroutineThread)

    return true
end

function Session:removeThread(coroutineThread)
    if not coroutineThread then
        coroutineThread = coroutine.running()
    end
    if not self._manager._threadToSession[coroutineThread] then
        return false, string.format(
            "%s is not associated to a Session"
        )
    end

    self._manager._threadToSession[coroutineThread] = nil
    table.remove(self._threads, table.find(self._threads, coroutineThread))

    return true
end

function Session:destroy()
    for _, thread in next, self._threads do
        self._manager._threadToSession[thread] = nil
    end
    for key, _ in next, self do
        self[key] = nil
    end
    self = nil

    return true
end

end,
function(api)

end