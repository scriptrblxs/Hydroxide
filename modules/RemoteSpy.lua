local owner = "24rr"
local branch = "revision"

 Enhanced environment validation with additional fallbacks
local function validateEnvironment()
     Core function safety net
    local env = getgenv()
    
     Essential function fallbacks
    if not env.getscriptclosure and not env.get_script_function then
        env.getscriptclosure = function() return nil end
    end
    
    if not env.isXClosure then
        env.isXClosure = function() return false end
    end

     Improved closure detection fallback
    if not env.isLClosure then
        env.isLClosure = function(f)
            return type(f) == "function" and not env.isXClosure(f)
        end
    end

     GC fallback for executors without proper GC access
    if not env.getGc then
        env.getGc = function()
            return setmetatable({}, {
                __pairs = function() return next, {} end
            })
        end
    end

     Web request fallback for executors without async support
    if not game.HttpGetAsync then
        game.HttpGetAsync = function(self, url)
            return game:HttpGet(url)
        end
    end
end

validateEnvironment()

local function webImport(file)
    local success, result = pcall(function()
        local url = ("https://raw.githubusercontent.com/%s/Hydroxide/%s/%s.lua"):format(owner, branch, file)
        local content = game:HttpGetAsync(url)
        return loadstring(content, file .. '.lua')()
    end)
    
    if not success then
        warn("[Hydroxide] Failed to load", file, ":", result)
        return function() end
    end
    return result
end


local function waitForCharacter()
    local player = game:GetService("Players").LocalPlayer
    repeat task.wait() until player.Character
    return player.Character
end

local function safeInitialize()
    local character = waitForCharacter()
    local humanoid = character:WaitForChild("Humanoid")
    
    
    if not humanoid or not character:FindFirstChild("HumanoidRootPart") then
        warn("Hydroxide: Missing critical character components")
        return false
    end
    
    
    require(script.modules.RemoteSpy)
    return true
end

pcall(safeInitialize)

 Safer initialization with error suppression
local function initialize()
    local success = pcall(function()
        webImport("init")
        webImport("ui/main")
    end)
    
    if not success and not iswindowactive then
         Fallback UI warning for headless environments
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Hydroxide Warning",
            Text = "Failed to initialize UI components",
            Duration = 10
        })
    end
end

 Protected execution with multiple fallbacks
for _ = 1, 3 do   Retry mechanism
    local success, err = pcall(initialize)
    if success then break end
    warn("[Hydroxide] Initialization attempt failed:", err)
    task.wait(1)
end 
