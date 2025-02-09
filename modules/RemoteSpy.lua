local RemoteSpy = {}
local cache = {}
local limit = 20
local last = 0

local bad = {
    ["ControlModule"]=true,
    ["CameraModule"]=true,
    ["CharacterSound"]=true,
    ["ControllerService"]=true
}

local function safe(v)
    if type(v)=="userdata" then
        return ("<%s>"):format(tostring(v):match("%u%a+") or "obj")
    end
    return type(v)=="table" and "{}" or type(v)=="function" and "func" or v
end

local original
original = hookmetamethod(game, "__namecall", function(s, ...)
    if bad[s.ClassName] or bad[s.Name] then
        return original(s, ...)
    end
    
    local n = getnamecallmethod()
    if n=="FireServer" or n=="InvokeServer" then
        local a = {...}
        local t = {
            args = {},
            time = os.time(),
            method = n
        }
        
        for i=1,math.min(2,#a) do
            t.args[i] = safe(a[i])
        end
        
        if #cache >= limit then
            table.remove(cache,1)
        end
        
        table.insert(cache,t)
    end
    
    return original(s, ...)
end)

RemoteSpy.GetLogs = function() return cache end
RemoteSpy.Clear = function() table.clear(cache) end

return RemoteSpy
