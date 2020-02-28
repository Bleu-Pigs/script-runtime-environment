local Utilities = require(script.Parent:WaitForChild("Utilities"))
local Get = Utilities.Get
local Create = Utilities.Create
local CreateSignal = Utilities.CreateSignal
local t = require(script.Parent:WaitForChild("t"))

local MessageOut = CreateSignal()

local MESSAGE_TYPE = {
    DEBUG = 1,
    OUTPUT = 2,
    WARN = 3,
    ERROR = 4,
    FATAL = 5
}

local function RecordMessage(MessageType, Message, ...)
    if select("#", ...) > 0 then
        for i = 1, select("#", ...) do
            pcall(
                function(...)
                    Message = string.format(Message, select(i, ...))
                end,
                ...
            )
        end
    end
    local newLog = {
        MessageType,
        os.time(),
        debug.traceback(),
        coroutine.running(),
        Message
    }

    MessageOut:Fire(table.unpack(newLog))
end

local Logger = {
    MessageOut = MessageOut.Event,
    MESSAGE_TYPE = MESSAGE_TYPE
}

function Logger.debugf(Message, ...)
    assert(
        t.string(Message),
        string.format(
            "bad argument #1 (expecting string, got %s)",
            typeof(Message)
        )
    )

    RecordMessage(MESSAGE_TYPE.DEBUG, Message, ...)
end

function Logger.printf(Message, ...)
    assert(
        t.string(Message),
        string.format(
            "bad argument #1 (expecting string, got %s)",
            typeof(Message)
        )
    )

    RecordMessage(MESSAGE_TYPE.PRINT, Message, ...)
end

function Logger.warnf(Message, ...)
    assert(
        t.string(Message),
        string.format(
            "bad argument #1 (expecting string, got %s)",
            typeof(Message)
        )
    )

    RecordMessage(MESSAGE_TYPE.WARN, Message, ...)
end

function Logger.errorf(Message, ...)
    assert(
        t.string(Message),
        string.format(
            "bad argument #1 (expecting string, got %s)",
            typeof(Message)
        )
    )

    RecordMessage(MESSAGE_TYPE.ERROR, Message, ...)
end

function Logger.fatalf(Message, ...)
    assert(
        t.string(Message),
        string.format(
            "bad argument #1 (expecting string, got %s)",
            typeof(Message)
        )
    )

    RecordMessage(MESSAGE_TYPE.FATAL, Message, ...)
    return error(
        "an fatal error occurred",
        2
    )
end

function Logger.assert(Condition, Message, ...)
    if not Condition then
        return Logger.fatalf(Message, ...)
    end
end

return Logger