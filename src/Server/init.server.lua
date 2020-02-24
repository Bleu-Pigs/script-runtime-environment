local Server = require(script:WaitForChild("Core"))
Server.LocalDataManager = require(script:WaitForChild("LocalDataManager"))
Server.UsersManager = require(script:WaitForChild("UsersManager"))

Server.Utilities.Get("Players").PlayerAdded:connect(
    function(newPlayer)
        local User = Server.UsersManager:Get(newPlayer)
        print(User:GetInstance(), "has joined the Game!")

        if User:GetLocal("didSet") then
            print("LocalDataManager is functional!")
        else
            User:SetLocal("didSet", true)
            print("Set test variable")
        end
    end
)

Server.Utilities.Get("Players").PlayerRemoving:connect(
    function(leavingPlayer)
        print(leavingPlayer, "has left the Game!")
    end
)