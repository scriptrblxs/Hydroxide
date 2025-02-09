local RemoteSpy = {}
local MAX_LOG_SIZE = 20
local THROTTLE_TIME = 0.5
local lastProcess = 0
local callCount = 0

local BLACKLISTED_PATHS = {
    ["Players.LocalPlayer.PlayerScripts"] = true,
    ["PlayerModule"] = true,
    ["CameraModule"] = true,
    ["RbxCharacterSounds"] = true
}

 Ultra-safe log storage with weak keys
local remoteLogs = setmetatable({}, {__mode = "k"})
local logMeta = {
    __index = function(t, k)
        return {count=0, arg="", script="Unknown"}
    end
}
setmetatable(remoteLogs, logMeta)

 Bulletproof value sanitization
local function ultraSafeValue(v)
    local success, result = pcall(function()
        local t = typeof(v)
        if t == "userdata" then
            return ("<%s>"):format(tostring(v):match("%u%a+") or t)
        end
        return t == "table" and "{}"
              or t == "function" and "func"
              or tostring(v):sub(1, 25)
    end)
    return success and result or "?"
end

 Protected hook implementation
local function createProtectedHook(original)
    return function(self, ...)
        local args = {...}
        pcall(function()
            local method = getnamecallmethod()
            if (method == "FireServer" or method == "InvokeServer") then
                callCount = callCount + 1
                
                 Only track first argument
                local cleanArg = ultraSafeValue(args[1])
                local caller = "Unknown"
                
                pcall(function()
                    local s = getcallingscript()
                    caller = s and s.Name or caller
                end)

                remoteLogs[self] = {
                    count = remoteLogs[self].count + 1,
                    arg = cleanArg,
                    script = caller
                }

                 Auto-clean when reaching limit
                if callCount % MAX_LOG_SIZE == 0 then
                    for k in pairs(remoteLogs) do
                        if not k.Parent then
                            remoteLogs[k] = nil
                        end
                    end
                end
            end
        end)
        
        return original(self, ...)
    end
end

 Safe initialization
local function initialize()
    pcall(function()
        local originalNamecall
        originalNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            if not isBlacklisted(self) then
                createProtectedHook(originalNamecall)(self, ...)
            end
            return originalNamecall(self, ...)
        end)
    end)
end

 Throttled processing
local function safeProcess()
    if tick() - lastProcess < THROTTLE_TIME then return end
    lastProcess = tick()
    
    pcall(function()
         Force GC cleanup periodically
        if callCount % (MAX_LOG_SIZE * 2) == 0 then
            collectgarbage()
        end
    end)
end

 Start protected processing loop
task.spawn(function()
    while true do
        safeProcess()
        task.wait(THROTTLE_TIME)
    end
end)

initialize()

RemoteSpy.GetLogs = function() return remoteLogs end
RemoteSpy.ClearLogs = function()
    table.clear(remoteLogs)
    callCount = 0
end

local function isBlacklisted(remote)
    local success, path = pcall(function()
        return remote:GetFullName()
    end)
    if not success then return true end
    
    for pattern in pairs(BLACKLISTED_PATHS) do
        if path:find(pattern, 1, true) then
            return true
        end
    end
    return false
end

return RemoteSpy
