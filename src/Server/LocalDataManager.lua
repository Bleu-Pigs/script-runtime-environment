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

local function printf(message, ...)
    return print(
        string.format(
            message,
            ...
        )
    )
end

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
local notUpdatedYet = {}

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
                return resolve(value[1])
            end
            -- data isn't in cache, let's try to retrieve it

            local dataStore = DataStoreService:GetDataStore(
                self._dataStoreName .."??".. index,
                DATASTORE_SCOPE
            )
            local backupDataStore = DataStoreService:GetOrderedDataStore(
                self._dataStoreName .."??".. index .."!!BACKUP",
                DATASTORE_SCOPE
            )

            for _ = 1, 10 do
                printf(
                    "attempting to retrieve %s",
                    index
                )
                if pcall(
                    function()
                        -- first, let's get the last known entry from backup
                        local lastKnown = backupDataStore:GetSortedAsync(false, 1):GetCurrentPage()
                        if t.table(lastKnown) and t.number(lastKnown[2]) then
                            -- got it!
                            lastKnown = lastKnown[2]
                            printf(
                                "received timestamp %s from backup",
                                lastKnown
                            )
                            -- let's retrieve it from the actual DataStore
                            value = dataStore:GetAsync(lastKnown)
                            printf(
                                "retrieved value %s from DataStore",
                                tostring(value)
                            )
                        else
                            printf("couldnt find entry in backup!")
                            table.foreach(lastKnown, printf)
                        end
                    end
                ) then
                    -- successfully retrieved data
                    self._dataBuffer[index] = {
                        value,
                        true
                    }
                    printf(
                        "saved value %s to index %s in dataBuffer",
                        tostring(value),
                        tostring(index)
                    )
                    return resolve(value)
                end

                -- otherwise, try again after waiting a bit
                wait(1)
            end

            -- if we failed to retrieve it after 10 times, throw an error
            reject("failed to resolve after 10 attempts")
        end
    )
end

function ManagedLocalData.prototype:Set(index, value)
    if t.table(self._dataBuffer[index]) then
        self._dataBuffer[index][1] = value
        self._dataBuffer[index][2] = false
    else
        self._dataBuffer[index] = {
            value,
            false
        }
    end

    return value
end

spawn(
    function()
        while true do
            for _, ManagedLocalData in pairs(activelyManagedLocalData) do
                for index, value in pairs(ManagedLocalData._dataBuffer) do
                    if not value[2] then
                        local dataStore = DataStoreService:GetDataStore(
                            ManagedLocalData._dataStoreName .."??".. index,
                            DATASTORE_SCOPE
                        )
                        local backupDataStore = DataStoreService:GetOrderedDataStore(
                            ManagedLocalData._dataStoreName .."??".. index .."!!BACKUP",
                            DATASTORE_SCOPE
                        )

                        Promise.async(
                            function(resolve)
                                resolve(backupDataStore:GetSortedAsync(false, 1):GetCurrentPage())
                            end
                        ):andThen(
                            function(mostRecentEntry)
                                local timesSaved = 1
                                if t.table(mostRecentEntry) and t.number(mostRecentEntry[1]) then
                                    timesSaved = mostRecentEntry[1] + 1
                                end
                                local timeSavedAt = os.time()

                                return Promise.async(
                                    function(resolve, reject)
                                        backupDataStore:SetAsync(
                                            timesSaved,
                                            timeSavedAt
                                        )
                                        dataStore:SetAsync(
                                            timeSavedAt,
                                            value[1]
                                        )

                                        resolve()
                                    end
                                ):andThen(
                                    function()
                                        printf(
                                            "saved %s successfully",
                                            index
                                        )

                                        value[2] = true
                                    end
                                )
                            end
                        ):catch(
                            function(fatal)
                                printf(
                                    "%s failed\n%s",
                                    index,
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
    assert(
        self == LocalDataManager,
        "expecting ':', not '.' when calling method Get"
    )

    if activelyManagedLocalData[name] then
        return activelyManagedLocalData[name]
    end

    return ManagedLocalData.new(name)
end

return LocalDataManager