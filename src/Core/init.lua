local Core = {}
Core.Promise = require(script:WaitForChild("Promise"))
Core.t = require(script:WaitForChild("t"))
Core.Utilities = require(script:WaitForChild("Utilities"))
Core.Logger = require(script:WaitForChild("Logger"))

Core.Logger.MessageOut:Connect(
    function(messageType, timeRecorded, traceback, runningThread, message)
        print(
            string.format(
                "%s @ %d\n[[\n%s\n]]\n%s\n%s",
                messageType,
                timeRecorded,
                message,
                traceback,
                tostring(runningThread)
            )
        )
    end
)

return Core