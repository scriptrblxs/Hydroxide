local RemoteSpy = {}
local MAX_LOG_ENTRIES = 50
local THROTTLE_DELAY = 0.2
local lastProcess = 0
local callQueue = {}

 Simplified log storage with FIFO structure
local remoteLogs = {}
local logMeta = {
    __index = function(t, k)
        return rawget(t, k) or {count=0, args={}, script="Unknown"}
    end
}
setmetatable(remoteLogs, logMeta)

 Safe value serialization with error handling
local function safeSerialize(value)
    local success, result = pcall(function()
        local t = typeof(value)
        if t == "userdata" then
            return ("<%s:%s>"):format(t, tostring(value):sub(1, 20))
        elseif t == "table" then
            return "{...}"
        elseif t == "function" then
            return "func"
        end
        return tostring(value):sub(1, 50)
    end)
    return success and result or "[Serialization Error]"
end

 Batch process queued calls
local function processQueue()
    if tick() - lastProcess < THROTTLE_DELAY then return end
    lastProcess = tick()
    
    for remote, data in pairs(callQueue) do
        remoteLogs[remote] = {
            count = remoteLogs[remote].count + data.count,
            args = data.args,
            script = data.script
        }
        callQueue[remote] = nil
    end
    
     Maintain log size
    while #remoteLogs > MAX_LOG_ENTRIES do
        table.remove(remoteLogs, 1)
    end
end

 Namecall hook for all remote interactions
local namecallHook
namecallHook = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if method == "FireServer" or method == "InvokeServer" then
        local args = {...}
        local cleanArgs = {}
        for i = 1, math.min(3, #args) do
            cleanArgs[i] = safeSerialize(args[i])
        end
        
        local callingScript
        pcall(function()
            callingScript = getcallingscript()
            callingScript = callingScript and callingScript.Name or "Unknown"
        end)

        callQueue[self] = {
            count = (callQueue[self] and callQueue[self].count + 1) or 1,
            args = cleanArgs,
            script = callingScript
        }
    end
    processQueue()
    return namecallHook(self, ...)
end))

RemoteSpy.GetLogs = function() return remoteLogs end
RemoteSpy.ClearLogs = function() table.clear(remoteLogs) end
return RemoteSpy
