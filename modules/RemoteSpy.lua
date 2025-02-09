local RemoteSpy = {}
local MAX_LOG_SIZE = 100
local THROTTLE_TIME = 0.1
local lastCall = 0

 Simplified remote tracking with memory limits
local remoteLogs = setmetatable({}, {
    __mode = "k",
    __index = function(t,k)
        rawset(t,k,{
            count = 0,
            lastArgs = {},
            lastScript = nil
        })
        return rawget(t,k)
    end
})

 Safe argument serialization
local function safeSerialize(value)
    local valueType = typeof(value)
    if valueType == "userdata" then
        return ("[%s:%s]"):format(valueType, tostring(value):gsub(" ",""))
    elseif valueType == "table" then
        return "{...}"
    elseif valueType == "function" then
        return "[function]"
    end
    return value
end

 Throttled logging system
local function logRemoteCall(remote, method, args, script)
    local now = tick()
    if now - lastCall < THROTTLE_TIME then return end
    lastCall = now

     Clean arguments
    local cleanArgs = {}
    for i = 1, math.min(5, #args) do  Limit to first 5 args
        cleanArgs[i] = safeSerialize(args[i])
    end

     Update log entry
    local entry = remoteLogs[remote]
    entry.count = entry.count + 1
    entry.lastArgs = cleanArgs
    entry.lastScript = script and tostring(script) or "Unknown"
end

 Generic hook wrapper
local function createSafeHook(original)
    return function(...)
        local success, result = pcall(function()
            local self = ...
            if self and self ~= game then
                local method = getnamecallmethod() or "UnknownMethod"
                local args = {...}
                table.remove(args, 1)  Remove self from args
                
                 Get calling script safely
                local callingScript
                pcall(function()
                    callingScript = getcallingscript()
                    callingScript = callingScript and callingScript:GetFullName() or "UnknownScript"
                end)

                logRemoteCall(self, method, args, callingScript)
            end
            return original(...)
        end)
        
        return success and result or nil
    end
end

 Install hooks with fallbacks
local function installHooks()
    local remoteTypes = {
        "RemoteEvent",
        "RemoteFunction",
        "UnreliableRemoteEvent"
    }

    for _, className in pairs(remoteTypes) do
        local success = pcall(function()
            local instance = Instance.new(className)
            local methodName = className == "RemoteFunction" and "InvokeServer" or "FireServer"
            
            local original
            original = hookfunction(instance[methodName], createSafeHook(original))
        end)
        
        if not success then
            warn("[RemoteSpy] Failed to hook", className)
        end
    end
end

 Initialize with protection
local initSuccess = pcall(function()
    installHooks()
    game.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
            pcall(installHooks)  Safe re-hook attempt
        end
    end)
end)

RemoteSpy.GetLogs = function() return remoteLogs end
RemoteSpy.ClearLogs = function() table.clear(remoteLogs) end
return RemoteSpy
