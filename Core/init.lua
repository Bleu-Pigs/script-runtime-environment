local Core = {prototype = {}}
Core.__index = Core.prototype

local ModulesManager = {prototype = {}}
ModulesManager.__index = ModulesManager.prototype

local CachedModule = {prototype = {}}
CachedModule.__index = CachedModule.prototype

function CachedModule.new(ModuleScript)
    ModuleScript.Archivable = true
    local self = setmetatable(
        {   
            -- clone the module so there's reduced risk of Modification
            _safeModule = ModuleScript:Clone(),
            _api = {},
            _controller = {},
            _events = {}
        },
        CachedModule
    )

    local requiredController = {require(self._safeModule)}
    self._controller.start = requiredController[1]
    self._controller.stop = requiredController[2]

    self._events.started = Instance.new("BindableEvent", self._safeModule)
    self._events.stopping = Instance.new("BindableEvent", self._safeModule)
    self.Started = self._events.started.Event
    self.Stopping = self._events.stopping.Event

    return self
end