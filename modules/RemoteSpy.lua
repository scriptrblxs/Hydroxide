local RemoteSpy = {}
local Remote = import("objects/Remote")

local requiredMethods = {
    ["checkCaller"] = true,
    ["newCClosure"] = true,
    ["hookFunction"] = true,
    ["isReadOnly"] = true,
    ["setReadOnly"] = true,
    ["getInfo"] = true,
    ["getMetatable"] = true,
    ["setClipboard"] = true,
    ["getNamecallMethod"] = true,
    ["getCallingScript"] = true,
}

local remoteMethods = {
    FireServer = true,
    InvokeServer = true,
    Fire = true,
    Invoke = true,
    UnreliableFireServer = true
}

local remotesViewing = {
    RemoteEvent = true,
    UnreliableRemoteEvent = true,
    RemoteFunction = false,
    BindableEvent = false,
    BindableFunction = false
}

local methodHooks = {
    RemoteEvent = Instance.new("RemoteEvent").FireServer,
    UnreliableRemoteEvent = Instance.new("UnreliableRemoteEvent").UnreliableFireServer,
    RemoteFunction = Instance.new("RemoteFunction").InvokeServer,
    BindableEvent = Instance.new("BindableEvent").Fire,
    BindableFunction = Instance.new("BindableFunction").Invoke
}

local currentRemotes = setmetatable({}, {__mode = "v"})
local remoteLogs = {}
local maxLogs = 50

local remoteDataEvent = Instance.new("BindableEvent")
local eventSet = false

local function connectEvent(callback)
    remoteDataEvent.Event:Connect(callback)

    if not eventSet then
        eventSet = true
    end
end

local function safeHook(original, hook)
    local success, hooked = pcall(function()
        return hookFunction(original, hook)
    end)
    return success and hooked or original
end

local function handleRemoteCall(remote, method, callScript, ...)
    local args = {...}
    
    local sanitizedArgs = {}
    for i, v in pairs(args) do
        sanitizedArgs[i] = typeof(v) == "userdata" and tostring(v) or v
    end

    if #remoteLogs >= maxLogs then
        table.remove(remoteLogs, 1)
    end

    table.insert(remoteLogs, {
        Remote = remote,
        Method = method,
        Args = sanitizedArgs,
        Script = callScript,
        Timestamp = os.time()
    })
end

local function installHooks()
    local remotes = {
        "RemoteEvent",
        "RemoteFunction",
        "UnreliableRemoteEvent"
    }

    for _, className in ipairs(remotes) do
        local instance = Instance.new(className)
        local method = className == "RemoteFunction" and "InvokeServer" or "FireServer"
        
        local original
        original = safeHook(instance[method], function(self, ...)
            if self == instance then return original(self, ...) end
            
            local callScript
            pcall(function()
                callScript = getCallingScript()
                callScript = callScript and callScript:GetFullName() or "Unknown"
            end)

            handleRemoteCall(self, method, callScript, ...)
            return original(self, ...)
        end)
    end
end

local success, err = pcall(installHooks)
if not success then
    warn("[RemoteSpy] Failed to install hooks:", err)
end

RemoteSpy.RemotesViewing = remotesViewing
RemoteSpy.CurrentRemotes = currentRemotes
RemoteSpy.ConnectEvent = connectEvent
RemoteSpy.RequiredMethods = requiredMethods
RemoteSpy.GetLogs = function() return remoteLogs end
RemoteSpy.ClearLogs = function() table.clear(remoteLogs) end
return RemoteSpy
