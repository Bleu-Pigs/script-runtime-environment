local Core = require(script.Parent:WaitForChild("Core"))
local Create = Core.Utilities.Create
local Get = Core.Utilities.Get
local Promise = Core.Promise
local t = Core.t

local DataStoreService = Get("DataStoreService")

local DATASTORE_SECURITY_KEY = "some random key here"
local REQUEST_TYPES = {
    GET = newproxy(),
    SET = newproxy(),
    UPDATE = newproxy(),
    ONUPDATE = newproxy()
}

local QueuedRequest = {}

local queuedRequests = {}

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

    local request = {
        DataStoreName,
        RequestType,
        Index,
        Value,
        Create(
            "BindableEvent",
            {
                Parent = script
            }
        ),
        0
    }

    return Promise.async(
        function(resolve, reject, onCancel)
            resolve(request[5].Event:Wait())
        end
    )
end

local ManagedLocalData = {prototype = {}}
ManagedLocalData.__index = ManagedLocalData.prototype

local managedDataStores = {}

do
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

    function ManagedLocalData.prototype:GetAsync(Index)
        return QueuedRequest.new(self._dataStoreName, REQUEST_TYPES.GET, Index)
    end

    function ManagedLocalData.prototype:SetAsync(Index, Value)
        return QueuedRequest.new(self._dataStoreName, REQUEST_TYPES.GET, Index, Value)
    end

    function ManagedLocalData.prototype:UpdateAsync(Index, Callback)ert(
            t.callback(Callback),
            string.format(
                "bad argument #2 (expecting function, got %s)",
                typeof(Callback)
            )
        )

        return QueuedRequest.new(self._dataStoreName, REQUEST_TYPES.GET, Index, Callback)
    end

    function ManagedLocalData.prototype:OnUpdate(Index, Callback)
        assert(
            t.callback(Callback),
            string.format(
                "bad argument #2 (expecting function, got %s)",
                typeof(Callback)
            )
        )

        return QueuedRequest.new(self._dataStoreName, self._dataStoreNameBackup, REQUEST_TYPES.GET, Index, Callback)
    end
end

spawn(
    function()
        -- TODO: implement OnClose handler logic
        local request, response
        local dataStore, dataStoreBackup
        local timeSinceLastYield = os.time()
        while true do
            if #queuedRequests > 0 then
                request = table.remove(queuedRequests, 1)
                print("processing request", request)

                if request[6] > 3 then
                    request[5]:Fire("request was unable to process after three attempts")
                else
                    dataStore = DataStoreService:GetDataStore(request[1], DATASTORE_SECURITY_KEY)

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
                                            dataStoreBackup = DataStoreService:GetOrderedDataStore(
                                                request[1] .."_".. tostring(request[3]) .."_Backup"
                                            )

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
                                            dataStoreBackup = DataStoreService:GetOrderedDataStore(
                                                request[1] .."_".. tostring(request[3]) .."_Backup"
                                            )

                                            if t.table(oldData) and t.number(oldData[2]) then
                                                timesChanged = oldData[2] + 1
                                                dataStoreBackup:SetAsync(timesChanged, oldData)
                                            end

                                            return {
                                                request[4](oldData),
                                                timesChanged
                                            }
                                        end
                                    )
                                end
                            )
                        }
                    elseif request[2] == REQUEST_TYPES.ONUPDATE then
                        response = {pcall(request[1].OnUpdate, request[1], request[3], request[4])}
                    end

                    if not response[1] then
                        print(unpack(response))
                        table.insert(queuedRequests, request)
                    else
                        request[5]:Fire(response[2])
                    end
                end
            end

            wait(1)
        end
    end
)

local LocalDataManager = {} do
    function LocalDataManager:Get(Name)
        assert(self == LocalDataManager, "Expected ':' not '.' calling member function Get")
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
end

return LocalDataManager