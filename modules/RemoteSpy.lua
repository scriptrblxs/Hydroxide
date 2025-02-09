local RemoteSpy = {}
local cache = {}
local limit = 15
local cooldown = 0.1
local lastCall = 0

local protected = {
    ["ControlModule"] = true,
    ["CameraModule"] = true,
    ["CharacterSound"] = true,
    ["ControllerService"] = true,
    ["PlayerScripts"] = true,
    ["CoreGui"] = true
}

local function atomicSafe(v)
    return (type(v) == "userdata" and "<ud>") or v
end

local originalFire, originalInvoke

local function safeHook(self, ...)
    if protected[self.ClassName] or protected[self.Name] then
        return originalFire(self, ...)
    end
    
    if tick() - lastCall < cooldown then
        return originalFire(self, ...)
    end
    
    local args = {...}
    local entry = {
        method = "FireServer",
        args = {atomicSafe(args[1])},
        time = os.time()
    }
    
    if #cache >= limit then
        cache = {}
    end
    
    cache[#cache + 1] = entry
    lastCall = tick()
    
    return originalFire(self, ...)
end

local function install()
    local event = Instance.new("RemoteEvent")
    originalFire = hookfunction(event.FireServer, safeHook)
    
    local func = Instance.new("RemoteFunction")
    originalInvoke = hookfunction(func.InvokeServer, function(self, ...)
        return protected[self.ClassName] and originalInvoke(self, ...)
    end)
end

pcall(install)

RemoteSpy.GetLogs = function() return cache end
RemoteSpy.Clear = function() cache = {} end

return RemoteSpy
