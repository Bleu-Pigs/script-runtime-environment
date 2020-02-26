local Utilities = {}
local t = require(script.Parent:WaitForChild("t"))

do
    local cache = setmetatable({}, {__mode = "v"})
    function Utilities.Get(Name, BeginAt)
        if cache[Name] then
            return cache[Name]
        end

        assert(t.string(Name), "Expecting string, got ".. typeof(Name))
        if not t.Instance(BeginAt) then 
            BeginAt = game
        end

        local result = game:GetService(Name)
        if not t.Instance(result) then
            result = BeginAt:FindFirstChild(Name, true)
        end
        cache[Name] = result

        return result
    end
end

do
local new = Instance.new
    function Utilities.Create(ClassName, Properties)
        local new = new(ClassName)

        for key, value in next, Properties do
            if not key == "Parent" then
                local _, response = pcall(function() return typeof(new[key]) end)
                if response == "RBXScriptSignal" then
                    new[key]:connect(value)
                elseif response:match("is a callback") then
                    new[key] = value
                else
                    new[key] = value
                end
            end
        end
        new.Parent = Properties.Parent

        return new
    end
end

do
    local Connection = {prototype = {}}
    Connection.__index = Connection.prototype

    function Connection.new(signal, callback)
        local self = setmetatable(
            {
                _connected = true,
                _callback = nil,
                _signal = signal
            },
            Connection
        )

        local function fixedCallback(...)
            if self._connected then
                return callback(...)
            end

            return error(
                "this connection is broken",
                2
            )
        end
        self._callback = fixedCallback

        signal._connections[callback] = self
        return self
    end

    function Connection.prototype:Disconnect()
        self._connected = false
        self._signal._connections[self._callback] = nil
    end

    local Event = {prototype = {}}
    Event.__index = Event.prototype

    function Event.new(signal)
        local self = setmetatable(
            {
                _signal = signal
            },
            Event
        )

        return self
    end

    function Event.prototype:Connect(callback)
        return Connection.new(self._signal, callback)
    end

    function Event.prototype:Wait()
        table.insert(
            self._signal._waiting,
            coroutine.running()
        )

        return coroutine.yield()
    end

    local Signal = {prototype = {}}
    Signal.__index = Signal.prototype

    function Signal.new()
        local self = setmetatable(
            {
                _connections = {},
                _waiting = setmetatable({}, {__mode = "v"})
            },
            Signal
        )
        self.Event = Event.new(self)

        return self
    end

    function Signal.prototype:Fire(...)
        for callback in next, self._callbacks do
            coroutine.resume(coroutine.create(callback), ...)
        end
        for _, waitingThread in next, self._waiting do
            coroutine.resume(waitingThread, ...)
        end
    end

    function Signal.prototype:Destroy()
        for index, connection in next, self._connections do
            connection:Disconnect()
            self._connections[index] = nil
        end
        for index in next, self._waiting do
            self._waiting[index] = nil
        end
        for index in next, self do
            self[index] = nil
        end
    end
end

return Utilities