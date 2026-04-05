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
    Main = Window:AddTab({ Title = "AutoFarm", Icon = "home" }),
    Raid = Window:AddTab({ Title = "Raid", Icon = "swords" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options

do
    Fluent:Notify({
        Title = "Hubhub Loaded",
        Content = "by biaw",
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
        Title = "Select Target Mobs",
        Values = {"None"},
        Multi = true,
        Default = {},
    })

    local PriorityMobDropdown = Tabs.Main:AddDropdown("PriorityMob", {
        Title = "Select Priority Mob",
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
            MobDropdown:SetValue({[mobNames[1]] = true})
            PriorityMobDropdown:SetValues(mobNames)
            PriorityMobDropdown:SetValue("None")
        else
            MobDropdown:SetValues({"None"})
            MobDropdown:SetValue({})
            PriorityMobDropdown:SetValues({"None"})
            PriorityMobDropdown:SetValue("None")
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
        local targetMobsTable = Options.SelectedMob.Value
        local priorityMobName = Options.PriorityMob and Options.PriorityMob.Value or "None"
        
        local hasTarget = false
        if type(targetMobsTable) == "table" then
            for k,v in pairs(targetMobsTable) do
                if v and k ~= "None" then hasTarget = true; break end
            end
        end
        if priorityMobName ~= "None" then hasTarget = true end

        if not targetWorld or not hasTarget then return nil end
        
        local worldsToScan = {}
        if targetWorld == "All Worlds" then
            worldsToScan = {"World1", "World2", "World3", "World4", "World5"}
        else
            table.insert(worldsToScan, targetWorld)
        end

        local fallbackMob = nil

        for _, wName in ipairs(worldsToScan) do
            local worldInfo = workspace:FindFirstChild(wName)
            if worldInfo then
                local enemyFolder = worldInfo:FindFirstChild("Enemy")
                if enemyFolder then
                    for _, mob in ipairs(enemyFolder:GetChildren()) do
                        if mob:IsA("Model") then
                            local isPriority = (mob.Name == priorityMobName)
                            local isSelected = (type(targetMobsTable) == "table" and targetMobsTable[mob.Name])
                            
                            if isPriority or isSelected then
                                local hrp = mob:FindFirstChild("HumanoidRootPart")
                                if hrp then
                                    -- Specific check for this game's Attackable attribute
                                    local attackable = mob:GetAttribute("Attackable")
                                    if attackable ~= false then
                                        local isAlive = false
                                        if attackable == true then 
                                            isAlive = true 
                                        else
                                            -- Fallbacks
                                            local humanoid = mob:FindFirstChild("Humanoid")
                                            if humanoid then
                                                if humanoid.Health > 0 then isAlive = true end
                                            else
                                                local healthVal = mob:FindFirstChild("Health") or mob:FindFirstChild("health")
                                                if healthVal and (healthVal:IsA("IntValue") or healthVal:IsA("NumberValue")) then
                                                    if healthVal.Value > 0 then isAlive = true end
                                                end
                                            end
                                        end
                                        if isAlive then
                                            if isPriority then
                                                return mob
                                            elseif not fallbackMob then
                                                fallbackMob = mob
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        return fallbackMob
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

    local safeWorldCF = nil
    Tabs.Raid:AddButton({
        Title = "Set Safe Return Position",
        Description = "Click this to lock your world position. The script will always teleport you back here after a Raid.",
        Callback = function()
            local char = Player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                safeWorldCF = char.HumanoidRootPart.CFrame
                Fluent:Notify({Title="Position Saved", Content="Successfully locked return coordinate.", Duration=3})
            end
        end
    })

    local wasInDungeon = false
    
    local function IsInDungeon()
        -- First check if the Dungeon UI is actively visible on the screen
        pcall(function()
            local dungeonUI = Player.PlayerGui.Main.HUD.Dungeon
            if dungeonUI and dungeonUI.Visible then
                return true
            end
        end)
        
        -- Fallback check: Are there any enemy mobs inside the TowerRaid folder?
        local towerRaid = workspace:FindFirstChild("TowerRaid")
        if towerRaid then
            for _, rFolder in ipairs(towerRaid:GetChildren()) do
                if rFolder:FindFirstChild("Enemy") and #rFolder.Enemy:GetChildren() > 0 then
                    return true
                end
            end
        end
        return false
    end

    local function ToggleAutoFarm(state)
        autoFarmRunning = state
        if state then
            task.spawn(function()
                local currentMob = nil
                while autoFarmRunning do
                    local character = Player.Character
                    if character and character:FindFirstChild("HumanoidRootPart") then
                        
                        local currentlyInDungeon = IsInDungeon()
                        local raidFarmToggled = Options.RaidFarm and Options.RaidFarm.Value
                        
                        if currentlyInDungeon then
                            -- We are actively inside a raid/dungeon! Pause World Farm.
                            if not wasInDungeon then
                                wasInDungeon = true
                            end
                        else
                            -- We are NOT in a dungeon.
                            if wasInDungeon then
                                -- We just finished or left the dungeon! Teleport back to where we were farming.
                                if safeWorldCF then
                                    character.HumanoidRootPart.CFrame = safeWorldCF
                                end
                                wasInDungeon = false
                                task.wait(0.5) -- Short delay to allow map chunks to load
                            else
                                -- Normal World Farming Sequence
                                -- Drop current target if it's dead, missing, or user switched targets
                                local targetMobsTable = Options.SelectedMob.Value
                                local isCurrentValid = type(targetMobsTable) == "table" and currentMob and targetMobsTable[currentMob.Name]

                                if not currentMob or not currentMob.Parent or not isCurrentValid or not IsMobAlive(currentMob) then
                                    currentMob = GetNextMob()
                                end
                                
                                if currentMob then
                                    local targetHRP = currentMob:FindFirstChild("HumanoidRootPart")
                                    if targetHRP then
                                        -- Teleport to the mob
                                        character.HumanoidRootPart.CFrame = targetHRP.CFrame
                                    end
                                end
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
                                if attackable ~= false then
                                    if attackable == true then return mob end
                                    
                                    local isAlive = false
                                    local humanoid = mob:FindFirstChild("Humanoid")
                                    if humanoid then
                                        if humanoid.Health > 0 then isAlive = true end
                                    else
                                        local healthVal = mob:FindFirstChild("Health") or mob:FindFirstChild("health")
                                        if healthVal and (healthVal:IsA("IntValue") or healthVal:IsA("NumberValue")) then
                                            if healthVal.Value > 0 then isAlive = true end
                                        end
                                    end
                                    if isAlive then
                                        return mob
                                    end
                                end
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

    local RaidFarmToggle = Tabs.Raid:AddToggle("RaidFarm", {Title = "Auto Farm Tower Raid", Default = false })
    RaidFarmToggle:OnChanged(function()
        ToggleRaidFarm(Options.RaidFarm.Value)
    end)

    -- =====================================
    -- Auto Join Tower Raid
    -- =====================================
    local autoJoinTowerRunning = false

    local function ToggleAutoJoinTower(state)
        autoJoinTowerRunning = state
        if state then
            task.spawn(function()
                local remotesFolder = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
                local joinTowerRaid = remotesFolder:WaitForChild("JoinTowerRaid")
                while autoJoinTowerRunning do
                    if joinTowerRaid:IsA("RemoteEvent") then
                        joinTowerRaid:FireServer()
                    elseif joinTowerRaid:IsA("RemoteFunction") then
                        pcall(function() joinTowerRaid:InvokeServer() end)
                    end
                    task.wait(10) -- Safely attempts an auto-join every 10 seconds
                end
            end)
        end
    end

    local AutoJoinTowerToggle = Tabs.Raid:AddToggle("AutoJoinTower", {Title = "Auto Join Tower Raid", Default = false })
    AutoJoinTowerToggle:OnChanged(function()
        ToggleAutoJoinTower(Options.AutoJoinTower.Value)
    end)

    local RaidTimerLabel = Tabs.Raid:AddParagraph({
        Title = "Tower Raid Information",
        Content = "Calculating..."
    })

    task.spawn(function()
        local playerGui = Player:WaitForChild("PlayerGui")
        while true do
            -- 1. Calculate the Global 30-Minute Real World Timer
            local dateInfo = os.date("!*t")
            local targetMin = (dateInfo.min < 30) and 30 or 60
            local minsLeft = targetMin - dateInfo.min - 1
            local secsLeft = 60 - dateInfo.sec
            if secsLeft == 60 then
                minsLeft = minsLeft + 1
                secsLeft = 0
            end
            local predictedTimer = string.format("%02d:%02d", minsLeft, secsLeft)

            -- 2. Read the local active wave timer if we are inside
            local waveStatus = "Dungeon Inactive"
            pcall(function()
                local timeLabel = playerGui.Main.HUD.Dungeon.RaidsCountdown.StartTimerFrame.Info.Time
                if timeLabel and timeLabel.Text then
                    waveStatus = timeLabel.Text
                end
            end)

            -- 3. Update UI
            RaidTimerLabel:SetDesc(
                "Predicted Next Global Raid: " .. predictedTimer .. "\n" ..
                "Current Wave Timer: " .. waveStatus
            )
            
            task.wait(1)
        end
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
            -- Ignore the VIP Chest specified by user
            local chestName = chest.Name
            local lowerName = string.lower(chestName)
            if chestName ~= "VIPChest" and chestName ~= "GroupRewardsChest" and not string.match(lowerName, "vip") then
                
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
                    local touched = false
                    if chest:IsA("BasePart") then
                        if chest:FindFirstChildWhichIsA("TouchTransmitter") then
                            firetouchinterest(hrp, chest, 0)
                            firetouchinterest(hrp, chest, 1)
                            touched = true
                        end
                    elseif chest:IsA("Model") or chest:IsA("Folder") then
                        for _, part in ipairs(chest:GetDescendants()) do
                            if part:IsA("BasePart") and part:FindFirstChildWhichIsA("TouchTransmitter") then
                                firetouchinterest(hrp, part, 0)
                                firetouchinterest(hrp, part, 1)
                                touched = true
                                break -- Only touch once per chest model to save network resources!
                            end
                        end
                    end
                    
                    -- If we successfully submitted a touch packet, wait 0.1s before touching the 
                    -- next chest so the Roblox network thread doesn't completely freeze handling 500 packets in 1 frame
                    if touched then
                        task.wait(0.1) 
                    end
                end
            end
        end
    end

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
                    task.wait(1)
                end
            end)
        end
    end

    local AutoChestToggle = Tabs.Main:AddToggle("AutoChest", {Title = "Auto Collect Chests", Default = false })
    AutoChestToggle:OnChanged(function()
        ToggleAutoChest(Options.AutoChest.Value)
    end)

    -- =====================================
    -- Universal Auto Roll System
    -- =====================================
    local autoRollRunning = false

    local RollDropdown = Tabs.Main:AddDropdown("SelectedRoll", {
        Title = "Select Power to Roll",
        Values = {"None"},
        Multi = false,
        Default = 1,
    })

    -- Dynamically read all Roll remotes so it updates automatically
    task.spawn(function()
        local remotesFolder = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
        local rollOptions = {}
        for _, remote in ipairs(remotesFolder:GetChildren()) do
            if string.match(remote.Name, "^Roll") then
                table.insert(rollOptions, remote.Name)
            end
        end
        if #rollOptions > 0 then
            table.sort(rollOptions)
            RollDropdown:SetValues(rollOptions)
            RollDropdown:SetValue(rollOptions[1])
        end
    end)

    local function ToggleAutoRoll(state)
        autoRollRunning = state
        if state then
            task.spawn(function()
                local remotesFolder = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
                while autoRollRunning do
                    local targetRoll = Options.SelectedRoll.Value
                    if targetRoll and targetRoll ~= "None" then
                        -- Check both ReplicatedStorage and Workspace dynamically just in case
                        local rollRemote = remotesFolder:FindFirstChild(targetRoll) or workspace:FindFirstChild(targetRoll, true)
                        
                        if rollRemote then
                            if rollRemote:IsA("RemoteEvent") then
                                rollRemote:FireServer()
                            elseif rollRemote:IsA("RemoteFunction") then
                                pcall(function() rollRemote:InvokeServer() end)
                            end
                        end
                    end
                    task.wait(0.1) -- Fires heavily, skipping anime animations
                end
            end)
        end
    end

    local AutoRollToggle = Tabs.Main:AddToggle("AutoRoll", {Title = "Auto Roll (Instant)", Default = false })
    AutoRollToggle:OnChanged(function()
        ToggleAutoRoll(Options.AutoRoll.Value)
    end)

    -- =====================================
    -- Anti-AFK
    -- =====================================
    local antiAfkConnection
    local antiAfkLoopRunning = false
    local VirtualUser = game:GetService("VirtualUser")
    local VirtualInputManager = game:GetService("VirtualInputManager")

    local function ToggleAntiAfk(state)
        antiAfkLoopRunning = state
        if state then
            -- 1. Exploit level Idled disable (if executor supports getconnections)
            pcall(function()
                for _, connection in ipairs(getconnections(Player.Idled)) do
                    connection:Disable()
                end
            end)

            -- 2. Standard Idled fallback
            if not antiAfkConnection then
                antiAfkConnection = Player.Idled:Connect(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end

            -- 3. In-Game Custom AFK Bypass (Fires hardware input every 5 minutes)
            task.spawn(function()
                while antiAfkLoopRunning do
                    task.wait(60) -- Trigger every 60 seconds (much more aggressively)
                    if antiAfkLoopRunning then
                        pcall(function()
                            -- Simulate a realistic meaningless keypress (F15) to reset custom game AFK timers
                            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F15, false, game)
                            task.wait(0.1)
                            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F15, false, game)
                            
                            -- Spoof a slight mouse movement
                            local pos = game:GetService("UserInputService"):GetMouseLocation()
                            VirtualInputManager:SendMouseMoveEvent(pos.X + 2, pos.Y + 2, game)
                            task.wait(0.1)
                            VirtualInputManager:SendMouseMoveEvent(pos.X, pos.Y, game)
                            
                            -- Force Character Physics update (bypasses velocity/position trackers)
                            local char = game.Players.LocalPlayer.Character
                            if char then
                                local hum = char:FindFirstChild("Humanoid")
                                if hum then
                                    hum.Jump = true
                                end
                            end
                        end)
                    end
                end
            end)
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
