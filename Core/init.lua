local ModulesManager = {}
do
    local loadedModules = {}
    local objectModule = {prototype = {}}
    objectModule.__index = objectModule.prototype

    function ModulesManager:load(ModuleScript)
        if loadedModules[ModuleScript.Name] then
            return false, string.format(
                "%s is already loaded into ModulesManager",
                ModuleScript.Name
            )
        end

        local newModuleObject = setmetatable(
            {
                _module = ModuleScript:clone(),
                _api = {}
            },
            objectModule
        )
        
        newModuleObject.started = newModuleObject._bindableStarted.Event
        newModuleObject.stopping = newModuleObject._bindableStopping.Event
        local controller = {require(newModuleObject._module:clone())}
        newModuleObject._controller = {
            start = controller[1],
            stop = controller[2]
        } 
        loadedModules[ModuleScript.Name] = newModuleObject
        return true
    end

    function ModulesManager:unload(stringNameOfModule)
        local unloadingModule = loadedModules[stringNameOfModule]
        if not unloadingModule then
            return false, string.format(
                "%s is already unloaded from ModulesManager",
                stringNameOfModule.Name
            )
        end

        ModulesManager:stop(stringNameOfModule)
        unloadingModule._bindableStarted:destroy()
        unloadingModule._bindableStopping:destroy()
        unloadingModule._controller.start = nil
        unloadingModule._controller.stop = nil 
    
        return true
    end

    function ModulesManager:start(stringNameOfModule, ...)
        local moduleData = loadedModules[stringNameOfModule]
        if not moduleData then
            return false, string.format(
                "%s is not a loaded Module",
                stringNameOfModule
            )
        end

        moduleData._thread = coroutine.create(moduleData._controller.start)
        local response = {coroutine.resume(moduleData._thread, moduleData._api, ...)}
        if response[1] then
            moduleData._bindableStarted:fire(moduleData._api)
        end
        return unpack(response)
    end

    function ModulesManager:stop(stringNameOfModule, ...)
        local moduleData = loadedModules[stringNameOfModule]
        if not moduleData then
            return false, string.format(
                "%s is not a loaded Module",
                stringNameOfModule
            )
        end

        moduleData._bindableStopping:fire()
        return coroutine.resume(
            coroutine.create(
                function()
                    local success, failureReason = pcall(moduleData._controller.stop)
                    for key, value in next, moduleData._api do
                        moduleData._api[key] = nil
                    end
                    return success, failureReason
                end
            )
        )
    end
end

local Core = {
    ModulesManager = ModulesManager
}
return Core