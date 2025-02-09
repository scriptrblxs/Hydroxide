local RemoteSpy = {}
local MAX_LOG_SIZE = 20
local THROTTLE_TIME = 0.5
local lastProcess = 0
local callCount = 0

local CRITICAL_CLASSES = {
    ["ControllerService"] = true,
    ["ControlModule"] = true,
    ["CameraModule"] = true,
    ["CharacterSound"] = true
}

local PATH_PATTERNS = {
    "PlayerScripts", "PlayerModule", "CharacterSounds", 
    "CameraSystem", "ControlScript", "RbxCharacter"
}

local remoteLogs = setmetatable({}, {__mode = "k"})
local logMeta = {
    __index = function(t, k)
        return {count=0, arg="", script="Unknown"}
    end
}
setmetatable(remoteLogs, logMeta)

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

local function createSafeHook()
    return function(self, ...)
        if isCritical(self) or isProtectedPath(self) then
            return originalNamecall(self, ...)
        end

        
    end
end

local function initialize()
    pcall(function()
        local originalNamecall
        originalNamecall = hookmetamethod(game, "__namecall", createSafeHook())
    end)
end

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

local function isCritical(instance)
    return CRITICAL_CLASSES[instance.ClassName] or CRITICAL_CLASSES[instance.Name]
end

local function isProtectedPath(instance)
    local success, path = pcall(function()
        return instance:GetFullName():lower()
    end)
    if not success then return true end
    
    for _, pattern in ipairs(PATH_PATTERNS) do
        if path:find(pattern:lower(), 1, true) then
            return true
        end
    end
    return false
end

local function isBlacklisted(remote)
    local success, path = pcall(function()
        return remote:GetFullName()
    end)
    if not success then return true end
    
    for pattern in pairs(CRITICAL_CLASSES) do
        if path:find(pattern, 1, true) then
            return true
        end
    end
    return false
end

local MEMORY_LIMITS = {
    MAX_LOG_ENTRIES = 15,
    MAX_ARG_LENGTH = 20,
    GC_INTERVAL = 30
}

local function enforceMemorySafety()
    collectgarbage()
    if #remoteLogs > MEMORY_LIMITS.MAX_LOG_ENTRIES then
        table.clear(remoteLogs)
    end
end

task.spawn(function()
    while true do
        enforceMemorySafety()
        task.wait(MEMORY_LIMITS.GC_INTERVAL)
    end
end)

return RemoteSpy
