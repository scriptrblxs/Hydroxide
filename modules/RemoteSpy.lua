local RemoteSpy = {}
local MAX_ENTRIES = 30
local THROTTLE = 0.3
local lastUpdate = tick()
local callBuffer = {}

 Simplified log storage with FIFO structure
local remoteLogs = {}
local logMeta = {
    __index = function(t, k)
        return {count=0, args={}, script="Unknown"}
    end
}
setmetatable(remoteLogs, logMeta)

 Robust value sanitization
local function safeValue(v)
    local t = typeof(v)
    if t == "userdata" then
        return ("<%s>"):format(tostring(v):match("%w+$") or t)
    end
    return t == "table" and "{}" or t == "function" and "func" or v
end

 Batch processing with throttling
local function processBuffer()
    if tick() - lastUpdate < THROTTLE then return end
    
    for remote, entry in pairs(callBuffer) do
        remoteLogs[remote] = {
            count = remoteLogs[remote].count + entry.count,
            args = entry.args,
            script = entry.script
        }
        callBuffer[remote] = nil
    end
    
     Maintain log size
    if #remoteLogs > MAX_ENTRIES then
        table.remove(remoteLogs, 1)
    end
    lastUpdate = tick()
end

 Single hook point using namecall
local originalNamecall
originalNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if method == "FireServer" or method == "InvokeServer" then
        local args = {...}
        local clean = {}
        for i = 1, math.min(2, #args) do   Only first 2 args
            clean[i] = safeValue(args[i])
        end
        
        local caller = "Unknown"
        pcall(function()
            local s = getcallingscript()
            caller = s and s.Name or caller
        end)

        callBuffer[self] = {
            count = (callBuffer[self] and callBuffer[self].count + 1) or 1,
            args = clean,
            script = caller
        }
    end
    processBuffer()
    return originalNamecall(self, ...)
end)

RemoteSpy.GetLogs = function() return remoteLogs end
RemoteSpy.ClearLogs = function()
    table.clear(remoteLogs)
    table.clear(callBuffer)
end

return RemoteSpy
