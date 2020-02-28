--[[

- Adaptable soft limit based on numOfPlayers with hard limit of 20
- Automatic retries up to set limit
- Data buffer to reduce impact on request budget

]]

local Core = require(script.Parent.Core)
local Get = Core.Utilities.Get
local Create = Core.Utilities.Create
local t = Core.t
local Promise = Core.Promise
local Logger = Core.Logger

local DataStoreService = Get("DataStoreService")
local MessagingService = Get("MessagingService")

local REQUESTS = {
    Get = newproxy(),
    Set = newproxy(),
    Update = newproxy(),
    OnUpdate = newproxy()
}
local DATASTORE_SCOPE = "insert some security key here"


local ManagedLocalData = {prototype = {}}
ManagedLocalData.__index = ManagedLocalData.prototype
local activeManagedLocalData = {}

function ManagedLocalData.new(name)
    Logger.assert(
        t.string(name),
        "bad argument #1 (expecting string, got %s)",
        typeof(name)
    )

    local self = setmetatable(
        {
            _dataStore = DataStoreService:GetDataStore(name, DATASTORE_SCOPE),
            _dataBuffer = {}
        },
        ManagedLocalData
    )

    activeManagedLocalData[name] = self
    return self
end

function ManagedLocalData.prototype:Get(index)
    local value = self._dataBuffer[index]
    if t.table(value) then
        Logger.debugf(
            "retrieved %s from dataBuffer\n%s",
            tostring(index),
            tostring(value)
        )
        return value[1]
    end

    -- data isn't in cache, let's try to retrieve it
    Logger.debugf(
        "%s is not cached locally, retrieving from DataStore %s",
        tostring(index),
        self._dataStore.Name
    )

    for _ = 1, 10 do
        if pcall(
            function()
                    Logger.debugf(
                        "retrieving to retrieve %s from DataStore",
                        tostring(index)
                    )
                    value = self._dataStore:GetAsync(index)
                -- end
            end
        ) then
            Logger.debugf(
                "saving %s to dataBuffer",
                tostring(value)
            )
            self._dataBuffer[index] = {
                value,
                true
            }
            return value
        end

        wait(1)
    end
end

function ManagedLocalData.prototype:Set(index, value)
    Logger.assert(
        t.any(index),
        "bad argument #1 (cannot be nil)"
    )
    
    self._dataBuffer[index] = {
        value,
        false
    }

    return value
end

spawn(
    function()
        while true do
            for _, ManagedLocalData in pairs(activeManagedLocalData) do
                for index, value in pairs(ManagedLocalData._dataBuffer) do
                    if not value[2] then
                        Logger.debugf(
                            "%s has yet to been saved",
                            tostring(index)
                        )

                        Promise.async(
                            function(resolve)
                                if value[1] == nil then
                                    ManagedLocalData._dataStore:RemoveAsync(index)
                                else
                                    ManagedLocalData._dataStore:UpdateAsync(
                                        index,
                                        function()
                                            return value[1]
                                        end
                                    )
                                end

                                Logger.debugf(
                                    "saved %s successfully",
                                    index
                                )

                                value[2] = true
                                resolve()
                            end
                        ):catch(
                            function(fatal)
                                Logger.errorf(
                                    "%s failed\n%s",
                                    tostring(index),
                                    fatal
                                )

                                value[2] = false
                            end
                        )
                    end
                end
            end

            wait(1)
        end
    end
)

local LocalDataManager = {}

function LocalDataManager:Get(name)
    Logger.assert(
        self == LocalDataManager,
        "expecting ':', not '.' when calling method Get"
    )

    if activeManagedLocalData[name] then
        return activeManagedLocalData[name]
    end

    return ManagedLocalData.new(name)
end

return LocalDataManager