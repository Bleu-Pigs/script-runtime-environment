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
            _dataStore = DataStoreService:GetDataStore(Name, DATASTORE_SECURITY_KEY),
            _dataStoreBackup = DataStoreService:GetOrderedDataStore(Name, DATASTORE_SECURITY_KEY),
            _dataBuffer = {}
        },
        ManagedLocalData
    )
    managedDataStores[Name] = self

    return self
end

local QueuedRequest = {}
function QueuedRequest.new(RequestingDataStore, DataStoreBackup, RequestType, Index, Value)
    assert(
        t.Instance(RequestingDataStore),
        string.format(
            "bad argument #1 (expecting Instance, got %s)",
            typeof(RequestingDataStore)
        )
    )
    assert(
        RequestingDataStore:IsA("GlobalDataStore"),
        string.format(
            "bad argument #1 (expecting Class GlobalDataStore, got %s)",
            RequestingDataStore.ClassName
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
            "bad argument #1 (expecting REQUEST_TYPES Enum, got %s)",
            typeof(RequestType)
        )
    )

    local request = {
        RequestingDataStore,
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
        while true do
            if #queuedRequests > 0 then
                request = table.remove(queuedRequests, 1)

                if request[7] > 3 then
                    request[6] = "request failed more than 3 times"
                    request[5] = true
                else
                    if request[2] == REQUEST_TYPES.GET then
                        response = {pcall(request[1].GetAsync, request[1], request[3])}
                    elseif request[2] == REQUEST_TYPES.SET then
                        response = {
                            pcall(
                                request[1].UpdateAsync,
                                request[1],
                                request[3],
                                function()
                                    return request[4]
                                end
                            )
                        }
                    elseif request[2] == REQUEST_TYPES.UPDATE then
                        response = {pcall(request[1].GetAsync, request[1], request[3], request[4])}
                    elseif request[2] == REQUEST_TYPES.ONUPDATE then
                        response = {pcall(request[1].GetAsync, request[1], request[3], request[4])}
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