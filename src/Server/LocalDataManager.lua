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

local DataStoreService = Get("DataStoreService")

local REQUESTS = {
    Get = newproxy(),
    Set = newproxy(),
    Update = newproxy(),
    OnUpdate = newproxy()
}
local DATASTORE_SCOPE = "insert some security key here"


local ManagedLocalData = {prototype = {}}
ManagedLocalData.__index = ManagedLocalData.prototype
local activelyManagedLocalData = {}

function ManagedLocalData.new(name)
    assert(
        t.string(name),
        string.format(
            "bad argument #1 (expecting string, got %s)",
            typeof(name)
        )
    )

    local self = setmetatable(
        {
            _dataStoreName = name,
            _dataBuffer = {},
            _dataUpdateCallbacks = {}
        },
        ManagedLocalData
    )

    activelyManagedLocalData[name] = self
    return self
end

function ManagedLocalData.prototype:Get(index)
    return Promise.async(
        function(resolve, reject)
            local value = self._dataBuffer[index]
            if t.table(value) then
                return value[1]
            end

            -- data may not be cached, let's attempt to get it
            local response = {
                pcall(
                    self._dataStore.GetAsync,
                    self._dataStore,
                    index
                )
            }

            if response[1] then
                self._dataBuffer[index] = {
                    value,
                    os.time(),
                    true
                }
                resolve(value)
            else
                for i = 1, 10 do
                    wait(1)
                    response = {
                        pcall(
                            self._dataStore.GetAsync,
                            self._dataStore,
                            index
                        )
                    }

                    if response[1] then
                        self._dataBuffer[index] = {
                            value,
                            os.time(),
                            true
                        }
                        return resolve(value)
                    end
                end

                reject(response[2])
            end
        end
    )
end

function ManagedLocalData.prototype:Set(index, value)
    self._dataBuffer[index] = {
        value,
        os.time(),
        false
    }

    return value
end

spawn(
    function()
        while true do
            for _, ManagedLocalData in pairs(activelyManagedLocalData) do
                for index, value in pairs(ManagedLocalData._dataBuffer) do
                    if not value[3] and value[2] > (os.time() - 10) then
                        -- data needs to be pushed to DataStore
                        local dataStore = DataStoreService:GetDataStore(
                            self._dataStoreName .."??".. index,
                            DATASTORE_SCOPE
                        )
                        local backupDataStore = DataStoreService:GetOrderedDataStore(
                            self._dataStoreName .."??".. index .."!!BACKUP",
                            DATASTORE_SCOPE
                        )

                        Promise.async(
                            function(resolve)
                                resolve(backupDataStore:GetOrderdAsync(false, 1):GetCurrentPage()[1])
                            end
                        ):andThen(
                            function(mostRecentEntry)
                                local timesSaved = 1
                                if t.table(mostRecentEntry) then
                                    timesSaved = mostRecentEntry[1] + 1
                                end

                                local timeSavedAt = os.time()

                                backupDataStore:SetAsync(
                                    timesSaved,
                                    timeSavedAt
                                )
                                dataStore:SetAsync(
                                    timeSavedAt,
                                    value[1]
                                )
                            end
                        )
                    end
                end
            end

            wait(10)
        end
    end
)

local LocalDataManager = {}

function LocalDataManager:Get(name)
    if activelyManagedLocalData[name] then
        return activelyManagedLocalData[name]
    end

    return ManagedLocalData.new(name)
end

return LocalDataManager