local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Hubhub",
    SubTitle = "by biaw",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true, 
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl 
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "home" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options

do
    Fluent:Notify({
        Title = "Script Loaded",
        Content = "Auto farm and auto click initialized.",
        Duration = 5 
    })

    Tabs.Main:AddParagraph({
        Title = "Notice",
        Content = "Be sure to equip your weapon before using these features."
    })

    -- =====================================
    -- Auto Clicker
    -- =====================================
    local clickLoopActive = false
    local autoClickConnection

    local function ToggleAutoClick(state)
        clickLoopActive = state
        if state then
            task.spawn(function()
                -- Wait for remote to exist and store it safely
                local remotesFolder = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
                local remoteClick = remotesFolder:WaitForChild("Clicked")
                
                -- Heartbeat is used to click as fast as possible without causing client engine lag
                autoClickConnection = game:GetService("RunService").Heartbeat:Connect(function()
                    if clickLoopActive then
                        remoteClick:FireServer()
                    end
                end)
            end)
        else
            -- Cleanup the connection to save resources
            if autoClickConnection then
                autoClickConnection:Disconnect()
                autoClickConnection = nil
            end
        end
    end

    local AutoClickToggle = Tabs.Main:AddToggle("AutoClick", {Title = "Auto Click", Default = false })
    AutoClickToggle:OnChanged(function()
        ToggleAutoClick(Options.AutoClick.Value)
    end)


    -- =====================================
    -- Auto Farm Mobs
    -- =====================================
    local autoFarmRunning = false
    local Player = game.Players.LocalPlayer

    local worldsList = {"All Worlds", "World1", "World2", "World3", "World4", "World5"}
    local WorldDropdown = Tabs.Main:AddDropdown("SelectedWorld", {
        Title = "Select Target World",
        Values = worldsList,
        Multi = false,
        Default = 1,
    })

    local MobDropdown = Tabs.Main:AddDropdown("SelectedMob", {
        Title = "Select Target Mob",
        Values = {"None"},
        Multi = false,
        Default = 1,
    })

    local function UpdateMobList(worldName)
        local mobNames = {}
        local found = {}

        local function scanWorld(wName)
            local worldInfo = workspace:FindFirstChild(wName)
            if worldInfo then
                local enemyFolder = worldInfo:FindFirstChild("Enemy")
                if enemyFolder then
                    for _, mob in ipairs(enemyFolder:GetChildren()) do
                        if mob:IsA("Model") and not found[mob.Name] then
                            found[mob.Name] = true
                            table.insert(mobNames, mob.Name)
                        end
                    end
                end
            end
        end

        if worldName == "All Worlds" then
            for i=1, 5 do scanWorld("World"..i) end
        else
            scanWorld(worldName)
        end

        if #mobNames > 0 then
            MobDropdown:SetValues(mobNames)
            MobDropdown:SetValue(mobNames[1])
        else
            MobDropdown:SetValues({"None"})
            MobDropdown:SetValue("None")
        end
    end

    WorldDropdown:OnChanged(function(Value)
        UpdateMobList(Value)
    end)

    Tabs.Main:AddButton({
        Title = "Refresh Mob List",
        Description = "Updates the mob list for the selected world.",
        Callback = function()
            UpdateMobList(Options.SelectedWorld.Value)
        end
    })

    -- Populates the mob list safely on load
    task.spawn(function()
        UpdateMobList(worldsList[1])
    end)

    -- Locates the specific mob selected by the user
    local function GetNextMob()
        local targetWorld = Options.SelectedWorld.Value
        local targetMob = Options.SelectedMob.Value
        
        if not targetWorld or targetMob == "None" or targetMob == "" then return nil end
        
        local worldsToScan = {}
        if targetWorld == "All Worlds" then
            worldsToScan = {"World1", "World2", "World3", "World4", "World5"}
        else
            table.insert(worldsToScan, targetWorld)
        end

        for _, wName in ipairs(worldsToScan) do
            local worldInfo = workspace:FindFirstChild(wName)
            if worldInfo then
                local enemyFolder = worldInfo:FindFirstChild("Enemy")
                if enemyFolder then
                    for _, mob in ipairs(enemyFolder:GetChildren()) do
                        if mob:IsA("Model") and mob.Name == targetMob then
                            local hrp = mob:FindFirstChild("HumanoidRootPart")
                            if hrp then
                                -- Specific check for this game's Attackable attribute
                                local attackable = mob:GetAttribute("Attackable")
                                if attackable == false then continue end
                                if attackable == true then return mob end
                                
                                -- Fallbacks
                                local humanoid = mob:FindFirstChild("Humanoid")
                                if humanoid then
                                    if humanoid.Health <= 0 then continue end
                                else
                                    local healthVal = mob:FindFirstChild("Health") or mob:FindFirstChild("health")
                                    if healthVal and (healthVal:IsA("IntValue") or healthVal:IsA("NumberValue")) then
                                        if healthVal.Value <= 0 then continue end
                                    else
                                        continue 
                                    end
                                end
                                return mob
                            end
                        end
                    end
                end
            end
        end
        return nil
    end

    -- Confirms whether our cached mob is still valid and alive
    local function IsMobAlive(mob)
        if not mob or not mob.Parent then return false end
        local hrp = mob:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        
        -- Specific check for this game's Attackable attribute
        local attackable = mob:GetAttribute("Attackable")
        if attackable == false then return false end
        if attackable == true then return true end

        local humanoid = mob:FindFirstChild("Humanoid")
        if humanoid then
            if humanoid.Health <= 0 then return false end
        else
            local healthVal = mob:FindFirstChild("Health") or mob:FindFirstChild("health")
            if healthVal and (healthVal:IsA("IntValue") or healthVal:IsA("NumberValue")) then
                if healthVal.Value <= 0 then return false end
            else
                return false
            end
        end
        return true
    end

    local function ToggleAutoFarm(state)
        autoFarmRunning = state
        if state then
            task.spawn(function()
                local currentMob = nil
                while autoFarmRunning do
                    local character = Player.Character
                    if character and character:FindFirstChild("HumanoidRootPart") then
                        -- Check if we need to find a new target
                        -- Drop current target if it's dead, missing, or if the user changed the selected mob
                        if not currentMob or not currentMob.Parent or currentMob.Name ~= Options.SelectedMob.Value or not IsMobAlive(currentMob) then
                            currentMob = GetNextMob()
                        end
                        
                        if currentMob then
                            local targetHRP = currentMob:FindFirstChild("HumanoidRootPart")
                            if targetHRP then
                                -- Teleport on top of/to the mob CFrame
                                character.HumanoidRootPart.CFrame = targetHRP.CFrame
                            end
                        end
                    end
                    -- task.wait() prevents game freezes
                    task.wait()
                end
            end)
        end
    end

    local AutoFarmToggle = Tabs.Main:AddToggle("AutoFarm", {Title = "Auto Farm Mobs", Default = false })
    AutoFarmToggle:OnChanged(function()
        ToggleAutoFarm(Options.AutoFarm.Value)
    end)

    -- =====================================
    -- Auto Farm Tower Raid
    -- =====================================
    local raidFarmRunning = false

    local function GetNextRaidMob()
        local towerRaid = workspace:FindFirstChild("TowerRaid")
        if towerRaid then
            for _, raidFolder in ipairs(towerRaid:GetChildren()) do
                local enemyFolder = raidFolder:FindFirstChild("Enemy")
                if enemyFolder then
                    for _, mob in ipairs(enemyFolder:GetChildren()) do
                        if mob:IsA("Model") then
                            local hrp = mob:FindFirstChild("HumanoidRootPart")
                            if hrp then
                                local attackable = mob:GetAttribute("Attackable")
                                if attackable == false then continue end
                                if attackable == true then return mob end
                                
                                local humanoid = mob:FindFirstChild("Humanoid")
                                if humanoid then
                                    if humanoid.Health <= 0 then continue end
                                else
                                    local healthVal = mob:FindFirstChild("Health") or mob:FindFirstChild("health")
                                    if healthVal and (healthVal:IsA("IntValue") or healthVal:IsA("NumberValue")) then
                                        if healthVal.Value <= 0 then continue end
                                    else
                                        continue 
                                    end
                                end
                                return mob
                            end
                        end
                    end
                end
            end
        end
        return nil
    end

    local function ToggleRaidFarm(state)
        raidFarmRunning = state
        if state then
            task.spawn(function()
                local currentRaidMob = nil
                while raidFarmRunning do
                    local character = Player.Character
                    if character and character:FindFirstChild("HumanoidRootPart") then
                        if not currentRaidMob or not currentRaidMob.Parent or not IsMobAlive(currentRaidMob) then
                            currentRaidMob = GetNextRaidMob()
                        end
                        
                        if currentRaidMob then
                            local targetHRP = currentRaidMob:FindFirstChild("HumanoidRootPart")
                            if targetHRP then
                                character.HumanoidRootPart.CFrame = targetHRP.CFrame
                            end
                        end
                    end
                    task.wait()
                end
            end)
        end
    end

    local RaidFarmToggle = Tabs.Main:AddToggle("RaidFarm", {Title = "Auto Farm Tower Raid", Default = false })
    RaidFarmToggle:OnChanged(function()
        ToggleRaidFarm(Options.RaidFarm.Value)
    end)

    -- =====================================
    -- Auto Collect Chests
    -- =====================================
    local autoChestRunning = false

    local function CollectChests()
        local chestsFolder = workspace:FindFirstChild("Chests")
        if not chestsFolder then return end

        local character = Player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        for _, chest in ipairs(chestsFolder:GetChildren()) do
            -- Detect if the chest has a visible Timer indicating it's on cooldown
            local isOnCooldown = false
            local billboard = chest:FindFirstChild("BillboardGui", true)
            if billboard then
                for _, descendant in ipairs(billboard:GetDescendants()) do
                    if descendant:IsA("TextLabel") and descendant.Text then
                        -- Check for time format pattern: Digit(s) : Digit(s)
                        if string.match(descendant.Text, "%d+:%d+") then
                            isOnCooldown = true
                            break
                        end
                    end
                end
            end
            
            if not isOnCooldown then
                if chest:IsA("BasePart") then
                    if chest:FindFirstChildWhichIsA("TouchTransmitter") then
                        firetouchinterest(hrp, chest, 0)
                        firetouchinterest(hrp, chest, 1)
                    end
                elseif chest:IsA("Model") or chest:IsA("Folder") then
                    for _, part in ipairs(chest:GetDescendants()) do
                        if part:IsA("BasePart") and part:FindFirstChildWhichIsA("TouchTransmitter") then
                            firetouchinterest(hrp, part, 0)
                            firetouchinterest(hrp, part, 1)
                        end
                    end
                end
            end
        end
    end

    local ChestDelaySlider = Tabs.Main:AddSlider("ChestDelay", {
        Title = "Check Chests Every (Minutes)",
        Description = "How often the script tries to collect chests to avoid server spam.",
        Default = 5,
        Min = 1,
        Max = 60,
        Rounding = 0,
    })

    local function ToggleAutoChest(state)
        autoChestRunning = state
        if state then
            task.spawn(function()
                while autoChestRunning do
                    if type(firetouchinterest) == "function" then
                        CollectChests()
                    else
                        Fluent:Notify({
                            Title = "Error",
                            Content = "Your executor lacks firetouchinterest support!",
                            Duration = 3
                        })
                        autoChestRunning = false
                    end
                    
                    -- Wait for the specified minutes, checking every second if we toggled it off
                    local delaySeconds = Options.ChestDelay.Value * 60
                    for i = 1, delaySeconds do
                        if not autoChestRunning then break end
                        task.wait(1)
                    end
                end
            end)
        end
    end

    local AutoChestToggle = Tabs.Main:AddToggle("AutoChest", {Title = "Auto Collect Chests", Default = false })
    AutoChestToggle:OnChanged(function()
        ToggleAutoChest(Options.AutoChest.Value)
    end)

    -- =====================================
    -- Anti-AFK
    -- =====================================
    local antiAfkConnection
    local VirtualUser = game:GetService("VirtualUser")

    local function ToggleAntiAfk(state)
        if state then
            if not antiAfkConnection then
                antiAfkConnection = Player.Idled:Connect(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                    
                    Fluent:Notify({
                        Title = "Anti-AFK",
                        Content = "Roblox tried kicking you but Anti-AFK prevented it!",
                        Duration = 5
                    })
                end)
            end
        else
            if antiAfkConnection then
                antiAfkConnection:Disconnect()
                antiAfkConnection = nil
            end
        end
    end

    local AntiAfkToggle = Tabs.Main:AddToggle("AntiAfk", {Title = "Anti-AFK", Default = true })
    AntiAfkToggle:OnChanged(function()
        ToggleAntiAfk(Options.AntiAfk.Value)
    end)

    -- Initialize default state
    ToggleAntiAfk(true)
end

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})

InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/specific-game")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)
SaveManager:LoadAutoloadConfig()
