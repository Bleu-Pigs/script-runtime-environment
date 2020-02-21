local Utilities = require(script.Parent.Core.Utilities)
local Create = Utilities.Create
local Get = Utilities.Get
local Promise = require(script.Parent.Core.Promises)
local t = require(script.Parent.Core.t)

local DataStoreService = Get("DataStoreService")
local RunService = Get("RunService")

local DATASTORE_SECURITY_KEY = "some random key here"
local REQUEST_TYPES = {
    GET = newproxy(),
    SET = newproxy(),
    UPDATE = newproxy(),
    ONUPDATE = newproxy()
}

local ManagedLocalData = {prototype = {}}
ManagedLocalData.__index = ManagedLocalData.prototype


local managedDataStores = {}
local queuedRequests = {}

function ManagedLocalData.new(Name)
    local self = setmetatable(
        {
            _dataStoreName = Name,
            _dataBuffer = {}
        },
        ManagedLocalData
    )
    managedDataStores[Name] = self

    return self
end

local QueuedRequest = {}
function QueuedRequest.new(DataStoreName, RequestType, Index, Value)
    assert(
        t.string(DataStoreName),
        string.format(
            "bad argument #1 (expecting string, got %s)",
            typeof(DataStoreName)
        )
    )
    assert(
        t.literal(
            REQUEST_TYPES.GET,
            REQUEST_TYPES.SET,
            REQUEST_TYPES.UPDATE,
            REQUEST_TYPES.ONUPDATE
        )(RequestType),
        string.format(
            "bad argument #2 (expecting REQUEST_TYPES Enum, got %s)",
            typeof(RequestType)
        )
    )
    assert(
        t.string(Index),
        string.format(
            "bad argument #3 (expecting string, got %s)",
            typeof(Index)
        )
    )

    local request = {
        DataStoreName,
        RequestType,
        Index,
        Value,
        false,
        nil,
        0
    }

    return Promise.async(
        function(resolve, reject, onCancel)
            local isCancelled
            onCancel(
                function()
                    table.remove(
                        queuedRequests,
                        table.find(
                            queuedRequests,
                            request
                        )
                    )
                    isCancelled = true
                end
            )

            local timeStarted = os.time() + 30
            while not isCancelled do
                if os.time() > timeStarted then
                    table.remove(
                        queuedRequests,
                        table.find(
                            queuedRequests,
                            request
                        )
                    )
                    reject(
                        "The request was not processed in a timely manner"
                    )
                else
                    if request[5] then
                        resolve(request[6])
                        return
                    end
                    wait(1)
                end
            end
        end
    )
end

function ManagedLocalData.prototype:GetAsync(Index)
    assert(
        t.string(Index),
        string.format(
            "bad argument #1 (expecting string, got %s)",
            typeof(Index)
        )
    )

    return QueuedRequest.new(self._dataStore, REQUEST_TYPES.GET, Index)
end

function ManagedLocalData.prototype:SetAsync(Index, Value)
    assert(
        t.string(Index),
        string.format(
            "bad argument #1 (expecting string, got %s)",
            typeof(Index)
        )
    )

    return QueuedRequest.new(self._dataStore, REQUEST_TYPES.GET, Index, Value)
end

function ManagedLocalData.prototype:UpdateAsync(Index, Callback)
    assert(
        t.string(Index),
        string.format(
            "bad argument #1 (expecting string, got %s)",
            typeof(Index)
        )
    )
    assert(
        t.callback(Callback),
        string.format(
            "bad argument #1 (expecting function, got %s)",
            typeof(Callback)
        )
    )

    return QueuedRequest.new(self._dataStore, REQUEST_TYPES.GET, Index, Callback)
end

function ManagedLocalData.prototype:OnUpdate(Index, Callback)
    assert(
        t.string(Index),
        string.format(
            "bad argument #1 (expecting string, got %s)",
            typeof(Index)
        )
    )
    assert(
        t.callback(Callback),
        string.format(
            "bad argument #1 (expecting function, got %s)",
            typeof(Callback)
        )
    )

    return QueuedRequest.new(self._dataStore, self._dataStoreBackup, REQUEST_TYPES.GET, Index, Callback)
end

spawn(
    function()
        -- TODO: implement OnClose handler logic
        local request, response
        local dataStore, dataStoreBackup
        while true do
            if #queuedRequests > 0 then
                request = table.remove(queuedRequests, 1)

                if request[7] > 3 then
                    request[6] = "request failed more than 3 times"
                    request[5] = true
                else
                    dataStore = DataStoreService:GetDataStore(request[1], DATASTORE_SECURITY_KEY)
                    dataStoreBackup = DataStoreService:GetOrderedDataStore(request[1] .. "_Backup", DATASTORE_SECURITY_KEY)

                    if request[2] == REQUEST_TYPES.GET then
                        response = {
                            pcall(
                                function()
                                    local response = dataStore:GetAsync(request[3])
                                    if t.table(response) then
                                        return response[2]
                                    end
                                end
                            )
                        }
                    elseif request[2] == REQUEST_TYPES.SET then
                        response = {
                            pcall(
                                function()
                                    dataStore:UpdateAsync(
                                        request[3],
                                        function(oldData)
                                            local timesChanged = 1
                                            dataStoreBackup = DataStoreService:GetOrderedDataStore(request[3] .."_".. request[3] .."_Backup")

                                            if t.table(oldData) and t.number(oldData[2]) then
                                                timesChanged = oldData[2] + 1
                                                dataStoreBackup:SetAsync(timesChanged, oldData)
                                            end

                                            return {
                                                request[4],
                                                timesChanged
                                            }
                                        end
                                    )

                                    return request[4]
                                end
                            )
                        }
                    elseif request[2] == REQUEST_TYPES.UPDATE then
                        response = {
                            pcall(
                                function()
                                    return dataStore:UpdateAsync(
                                        request[3],
                                        function(oldData)
                                            local timesChanged = 1
                                            dataStoreBackup = DataStoreService:GetOrderedDataStore(request[3] .."_".. request[3] .."_Backup")
                                            
                                            if t.table(oldData) and t.number(oldData[2]) then
                                                timesChanged = oldData[2] + 1
                                                dataStoreBackup:SetAsync(timesChanged, oldData)
                                            end

                                            return request[4](oldData)
                                        end
                                    )
                                end
                            )
                        }
                    elseif request[2] == REQUEST_TYPES.ONUPDATE then
                        response = {pcall(request[1].OnUpdate, request[1], request[3], request[4])}
                    end

                    if not response[1] then
                        table.insert(queuedRequests, request)
                    else
                        request[6] = response[2]
                        request[5] = true
                    end
                end
            end
        end
    end
)

local LocalDataManager = {}

function LocalDataManager:Get(Name)
    assert(t.literal(LocalDataManager)(self), "Expected ':' not '.' calling member function Get")
    assert(
        t.string(Name),
        string.format(
            "bad argument #1 (expecting string, got %s)",
            typeof(Name)
        )
    )

    if managedDataStores[Name] then
        return managedDataStores[Name]
    end

    return ManagedLocalData.new(Name)
end

return LocalDataManager