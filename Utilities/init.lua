return function(api, Core)

local getCache = setmetatable({}, {__mode = "v"})
function api.Get(NameOfInstance, BeginSearchIn)
    if getCache[NameOfInstance] then
        return NameOfInstance
    end
    if BeginSearchIn == nil then
        BeginSearchIn = game
    end

    local result = game:GetService(NameOfInstance)
    if not result then
        result = BeginSearchIn:FindFirstChild(NameOfInstance, true)
    end
    getCache[NameOfInstance] = result

    return result
end

function api.Create(ClassName, Properties)
    local new = Instance.new(ClassName)

    for key, value in next, Properties do
        if not key == "Parent" then
            local _, response = pcall(function() return typeof(new[key]) end)
            if response == "RBXScriptSignal" then
                new[key]:connect(value)
            elseif response:match("is a callback") then
                new[key] = value
            else
                new[key] = value
            end
        end
    end
    new.Parent = Properties.Parent

    return new
end


end,
function(api)

end