--[[
]]

local LocalDataManager = require(script.Parent.LocalDataManager)
local Utilities = require(script.Parent.Core.Utilities)
local Create = Utilities.Create
local Get = Utilities.Get
local Promise = require(script.Parent.Core.Promises)
local t = require(script.Parent.Core.t)

local UserDataStore = LocalDataManager:Get("Users")

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
            _roamingData = {}
            _localData = UserDataStore:GetAsync(Player.userId):expect() or {}
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