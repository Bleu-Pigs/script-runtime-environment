local Utilities = {}

do
    local cache = setmetatable({}, {__mode = "v"})
    function Utilities.Get(Name, BeginAt)
        if cache[Name] then
            return cache[Name]
        end

        assert(api.t.string(Name), "Expecting string, got ".. typeof(Name))
        if not api.t.Instance(BeginAt) then 
            BeginAt = game
        end

        local result = game:GetService(Name)
        if not api.t.Instance(result) then
            result = BeginAt:FindFirstChild(Name, true)
        end
        cache[Name] = result

        return result
    end
end

do
local new = Instance.new
    function Utilities.Create(ClassName, Properties)
        local new = new(ClassName)

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
end

return Utilities