local Core = {prototype = {}}
Core.__index = Core.prototype

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

local ModulesManager = {prototype = {}}
ModulesManager.__index = ModulesManager.prototype

function ModulesManager.new()
    local self = setmetatable(
        {
            _cached = {}
        },
        ModulesManager
    )

    return self
end

function ModulesManager:load(ModuleScript)
    if self._cached[ModuleScript.Name] then
        return false, string.format(
            "%s is already loaded",
            ModuleScript.Name
        )
    end

    local newCachedModule = CachedModule.new(ModuleScript)
    self._cached[ModuleScript.Name] = newCachedModule

    return true
end

function ModulesManager:unload(ModuleName)
    if not self._cached[ModuleName] then
        return false, string.format(
            "%s is already unloaded",
            ModuleName
        )
    end

    local unloadingModule = self._cached[ModuleName]
    self:Stop(ModuleName)
    for key, value in next, unloadingModule do
        unloadingModule[key] = nil
    end
    self._cached[ModuleName] = nil

    return true
end