--[[
    Goals:
    - Create unified data management between Local and Roaming data profiles
]]

local Core = require(script.Parent)
local Utilities = Core.Utilities
local Create = Utilities.Create
local CreateSignal = Utilities.CreateSignal 
local Get = Utilities.Get
local Logger = Core.Logger
local Promise = Core.Promise
local t = Core.t

local UsersLocalData = LocalDataManager:Get("Users")
local Players = Get("Players")

local usersCached = setmetatable({}, {__index = "k"})

local User = {prototype = {}}
User.__index = User.prototype

function User.new(Player)
    assert(
        t.Instance(Player),
        string.format(
            "bad argument #1 (expecting Instance, got %s)",
            tostring(Player)
        )
    )
    assert(
        Player:IsA("Player"),
        string.format(
            "bad argument #1 (expecting RBXClass Player, got %s)",
            Player.ClassName
        )
    )

    local self = setmetatable(
        {
            _instance = Player,
            _roamingData = {},
            _localData = UsersLocalData:Get(Player.userId) or {}
        },
        User
    )
    usersCached[Player] = self

    return self
end

function User.prototype:SetRoaming(Index, Value)
    self._roamingData[Index] = Value
    return Value
end

function User.prototype:GetRoaming(Index)
    return self._roamingData[Index]
end
function User.prototype:SetLocal(Index, Value)
    self._localData[Index] = Value
    return Value
end

function User.prototype:GetLocal(Index)
    return self._localData[Index]
end

function User.prototype:GetPlayer()
    return self._instance
end

local UsersManager = {}

function UsersManager:Get(Player)
    assert(
        self == UsersManager,
        "Expected ':' not '.' calling member function Get"
    )
    assert(
        t.Instance(Player),
        string.format(
            "bad argument #1 (expecting Instance, got %s)",
            typeof(Player)
        )
    )

    if usersCached[Player] then
        return usersCached[Player]
    end

    return User.new(Player)
end

do
    UsersManager._playerJoinedSignal = CreateSignal()
    UsersManager.PlayerJoined = UsersManager._playerJoinedSignal.Event 
    UsersManager._playerLeftSignal = CreateSignal()
    UsersManager.PlayerLeft = UsersManager._playerLeftSignal.Event

    Players.PlayerAdded:connect(
        function(newPlayer)
            UsersManager._playerJoinedSignal:Fire(UsersManager:Get(newPlayer))
        end
    )
    Players.PlayerRemoving:connect(
        function(leavingPlayer)
            local leaving = UsersManager:Get(leavingPlayer)
            UsersLocalData:Set(leaving.userId, leaving._localData)
            UsersManager._playerLeftSignal:Fire(leaving)
        end
    )
end

return UsersManager