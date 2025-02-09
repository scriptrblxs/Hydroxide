local RemoteSpy = {}
local log = {}
local max = 10
local delay = 0.2
local last = 0

local unsafe = {
    ["ControlModule"]=true,
    ["CameraModule"]=true,
    ["CharacterSound"]=true,
    ["ControllerService"]=true,
    ["PlayerScripts"]=true,
    ["CoreGui"]=true,
    ["Sound"]=true
}

local function basicVal(v)
    return type(v) == "userdata" and "..." or v
end

local fireOriginal
fireOriginal = hookfunction(Instance.new("RemoteEvent").FireServer, function(s, ...)
    if unsafe[s.ClassName] or unsafe[s.Name] then
        return fireOriginal(s, ...)
    end
    
    local now = tick()
    if now - last < delay then
        return fireOriginal(s, ...)
    end
    
    if #log >= max then
        log = {}
    end
    
    log[#log+1] = {
        args = {basicVal(({...})[1])},
        time = os.time()
    }
    
    last = now
    return fireOriginal(s, ...)
end)

RemoteSpy.GetLogs = function() return log end
RemoteSpy.Clear = function() log = {} end

return RemoteSpy
