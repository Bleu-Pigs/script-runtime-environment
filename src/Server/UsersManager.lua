--[[
    Goals:
    - Create unified data management between Local and Roaming data profiles
]]

local Core = require(script.Parent.Core)
local LocalDataManager = Core.LocalDataManager
local t = Core.t

local UsersLocalData = LocalDataManager:Get("Users")

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
            _localData = UsersLocalData:GetAsync(Player.userId):expect() or {}
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

return UsersManager