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
        
        -- Fallback check: Are there any enemy mobs inside the Raid folders?
        local raidFolders = {"TowerRaid", "WisteriaRaid"}
        for _, raidName in ipairs(raidFolders) do
            local masterRaidFolder = workspace:FindFirstChild(raidName)
            if masterRaidFolder then
                for _, rFolder in ipairs(masterRaidFolder:GetChildren()) do
                    if rFolder:FindFirstChild("Enemy") and #rFolder.Enemy:GetChildren() > 0 then
                        return true
                    end
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
        local raidFolders = {"TowerRaid", "WisteriaRaid"}
        for _, raidName in ipairs(raidFolders) do
            local masterRaidFolder = workspace:FindFirstChild(raidName)
            if masterRaidFolder then
                for _, raidFolder in ipairs(masterRaidFolder:GetChildren()) do
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

    local RaidFarmToggle = Tabs.Raid:AddToggle("RaidFarm", {Title = "Auto Farm Raid (Tower/W4)", Default = false })
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

    -- =====================================
    -- Auto Leave Tower Raid
    -- =====================================

    -- Slider: leave Tower Raid after X rooms cleared
    Tabs.Raid:AddSlider("TowerLeaveWave", {
        Title = "Tower Raid — Leave at Room #",
        Description = "Auto-leave when \"Room Cleared: X\" reaches this number",
        Default = 5,
        Min = 1,
        Max = 999,
        Rounding = 0,
    })

    -- ✅ Confirmed: HUD.Dungeon.OldDungeon.Wave.Wave → Text = "Room Cleared: 5"
    local function GetCurrentTowerWave()
        local wave = nil
        pcall(function()
            local playerGui = Player:WaitForChild("PlayerGui", 5)
            if not playerGui then return end
            local waveLabel = playerGui
                :WaitForChild("Main", 3)
                :FindFirstChild("HUD")
            if not waveLabel then return end
            local dungeon = waveLabel:FindFirstChild("Dungeon")
            if not dungeon then return end
            local oldDungeon = dungeon:FindFirstChild("OldDungeon")
            if not oldDungeon then return end
            local waveFolder = oldDungeon:FindFirstChild("Wave")
            if not waveFolder then return end
            local label = waveFolder:FindFirstChild("Wave")
            if label and label:IsA("TextLabel") then
                -- Text format: "Room Cleared: 5"
                local n = string.match(label.Text, "Room%s*Cleared:%s*(%d+)")
                       or tonumber(string.match(label.Text, "(%d+)"))
                if n then wave = tonumber(n) end
            end
        end)
        return wave
    end

    local autoLeaveTowerRunning = false

    local function ToggleAutoLeaveTower(state)
        autoLeaveTowerRunning = state
        if state then
            task.spawn(function()
                local remotesFolder = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 15)
                if not remotesFolder then return end
                local leaveRemote = remotesFolder:FindFirstChild("LeaveRaid")
                               or remotesFolder:FindFirstChild("EndRaid")
                while autoLeaveTowerRunning do
                    if IsInDungeon() then
                        local w = GetCurrentTowerWave()
                        local leaveAt = Options.TowerLeaveWave and Options.TowerLeaveWave.Value or 5
                        if w and w >= leaveAt then
                            Fluent:Notify({
                                Title = "Tower Raid",
                                Content = "Room " .. tostring(w) .. " cleared! Leaving.",
                                Duration = 3
                            })
                            if leaveRemote then
                                if leaveRemote:IsA("RemoteEvent") then leaveRemote:FireServer()
                                elseif leaveRemote:IsA("RemoteFunction") then pcall(function() leaveRemote:InvokeServer() end) end
                            end
                            task.wait(3)
                            local character = Player.Character
                            if character and character:FindFirstChild("HumanoidRootPart") and safeWorldCF then
                                character.HumanoidRootPart.CFrame = safeWorldCF
                            end
                            task.wait(5)
                        end
                    end
                    task.wait(2)
                end
            end)
        end
    end

    local AutoLeaveTowerToggle = Tabs.Raid:AddToggle("AutoLeaveTower", {Title = "Auto Leave Tower Raid at Room #", Default = false })
    AutoLeaveTowerToggle:OnChanged(function()
        ToggleAutoLeaveTower(Options.AutoLeaveTower.Value)
    end)

    -- =====================================
    -- Auto Join/Open Wisteria Raid (W4)
    -- =====================================

    -- Slider: wave number to auto-leave at — goes up to 999 so no practical cap
    Tabs.Raid:AddSlider("WisteriaLeaveWave", {
        Title = "W4 Raid — Leave at Wave #",
        Description = "Auto-leave when this wave number is reached",
        Default = 5,
        Min = 1,
        Max = 999,
        Rounding = 0,
    })

    -- Reads the CURRENT in-raid wave from confirmed HUD paths (from screenshot):
    --   PlayerGui.Main.HUD.Dungeon.RaidsInfo.WavesFrame.Wave  (primary)
    --   PlayerGui.Main.HUD.Dungeon.OldDungeon.Wave.Wave        (secondary)
    local function GetCurrentWisteriaWave()
        local wave = nil

        pcall(function()
            local playerGui = Player:WaitForChild("PlayerGui", 5)
            if not playerGui then return end
            local main = playerGui:WaitForChild("Main", 3)
            if not main then return end
            local hud = main:FindFirstChild("HUD")
            if not hud then return end
            local dungeon = hud:FindFirstChild("Dungeon")
            if not dungeon then return end

            -- ✅ Primary: HUD.Dungeon.RaidsInfo.WavesFrame.Wave
            local raidsInfo = dungeon:FindFirstChild("RaidsInfo")
            if raidsInfo then
                local wavesFrame = raidsInfo:FindFirstChild("WavesFrame")
                if wavesFrame then
                    local waveLabel = wavesFrame:FindFirstChild("Wave")
                    if waveLabel and waveLabel:IsA("TextLabel") then
                        local n = tonumber(waveLabel.Text)
                               or tonumber(string.match(waveLabel.Text, "(%d+)"))
                        if n then wave = n; return end
                    end
                    -- WavesLabel might show "3/10" format
                    local wavesLabel = wavesFrame:FindFirstChild("WavesLabel")
                    if wavesLabel and wavesLabel:IsA("TextLabel") then
                        local n = string.match(wavesLabel.Text, "(%d+)%s*/%s*%d+")
                               or string.match(wavesLabel.Text, "[Ww]ave%s*(%d+)")
                               or tonumber(wavesLabel.Text)
                        if n then wave = tonumber(n); return end
                    end
                end
            end

        end)

        return wave
    end

    local function HasOpenWisteriaSlot()
        local wisteriaFolder = workspace:FindFirstChild("WisteriaRaid")
        if not wisteriaFolder then return true end
        for _, slot in ipairs(wisteriaFolder:GetChildren()) do
            if slot:IsA("Folder") or slot:IsA("Model") then
                local inUse = slot:GetAttribute("InUse")
                if inUse == false or inUse == nil then return true end
            end
        end
        return false
    end

    local function FireRemoteSafe(remote)
        if not remote then return end
        if remote:IsA("RemoteEvent") then
            remote:FireServer()
        elseif remote:IsA("RemoteFunction") then
            pcall(function() remote:InvokeServer() end)
        end
    end

    -- Shared leave logic used by both Join and Open loops
    local function DoLeaveWisteria(leaveRemote)
        local leaveWave = Options.WisteriaLeaveWave and Options.WisteriaLeaveWave.Value or 5
        Fluent:Notify({
            Title = "W4 Raid",
            Content = "Wave " .. tostring(leaveWave) .. " reached! Leaving.",
            Duration = 3
        })
        FireRemoteSafe(leaveRemote)
        task.wait(3)
        local character = Player.Character
        if character and character:FindFirstChild("HumanoidRootPart") and safeWorldCF then
            character.HumanoidRootPart.CFrame = safeWorldCF
        end
    end

    -- ── AUTO JOIN (JoinWisteriaRaid) ──
    local autoJoinWisteriaRunning = false

    local function ToggleAutoJoinWisteria(state)
        autoJoinWisteriaRunning = state
        if state then
            task.spawn(function()
                local remotesFolder = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 15)
                if not remotesFolder then return end
                local joinRemote  = remotesFolder:FindFirstChild("JoinWisteriaRaid")
                local leaveRemote = remotesFolder:FindFirstChild("LeaveRaid")
                               or remotesFolder:FindFirstChild("EndRaid")
                local justLeft = false
                while autoJoinWisteriaRunning do
                    if IsInDungeon() then
                        justLeft = false
                        local w = GetCurrentWisteriaWave()
                        local leaveWave = Options.WisteriaLeaveWave and Options.WisteriaLeaveWave.Value or 5
                        if w and w >= leaveWave then
                            DoLeaveWisteria(leaveRemote)
                            justLeft = true
                            task.wait(5)
                        end
                        task.wait(2)
                    else
                        if justLeft then task.wait(5); justLeft = false
                        else
                            if HasOpenWisteriaSlot() then
                                FireRemoteSafe(joinRemote)
                            end
                            task.wait(8)
                        end
                    end
                end
            end)
        end
    end

    local AutoJoinWisteriaToggle = Tabs.Raid:AddToggle("AutoJoinWisteria", {Title = "Auto Join W4 Raid (JoinWisteriaRaid)", Default = false })
    AutoJoinWisteriaToggle:OnChanged(function()
        ToggleAutoJoinWisteria(Options.AutoJoinWisteria.Value)
    end)

    -- ── AUTO OPEN (OpenWisteriaRaid) ──
    local autoOpenWisteriaRunning = false

    local function ToggleAutoOpenWisteria(state)
        autoOpenWisteriaRunning = state
        if state then
            task.spawn(function()
                local remotesFolder = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 15)
                if not remotesFolder then return end
                local openRemote  = remotesFolder:FindFirstChild("OpenWisteriaRaid")
                local leaveRemote = remotesFolder:FindFirstChild("LeaveRaid")
                               or remotesFolder:FindFirstChild("EndRaid")
                local justLeft = false
                while autoOpenWisteriaRunning do
                    if IsInDungeon() then
                        justLeft = false
                        local w = GetCurrentWisteriaWave()
                        local leaveWave = Options.WisteriaLeaveWave and Options.WisteriaLeaveWave.Value or 5
                        if w and w >= leaveWave then
                            DoLeaveWisteria(leaveRemote)
                            justLeft = true
                            task.wait(5)
                        end
                        task.wait(2)
                    else
                        if justLeft then task.wait(5); justLeft = false
                        else
                            if HasOpenWisteriaSlot() then
                                FireRemoteSafe(openRemote)
                            end
                            task.wait(8)
                        end
                    end
                end
            end)
        end
    end

    local AutoOpenWisteriaToggle = Tabs.Raid:AddToggle("AutoOpenWisteria", {Title = "Auto Open W4 Raid (OpenWisteriaRaid)", Default = false })
    AutoOpenWisteriaToggle:OnChanged(function()
        ToggleAutoOpenWisteria(Options.AutoOpenWisteria.Value)
    end)

    -- ── AUTO LEAVE (standalone — works without Join/Open) ──
    local autoLeaveWisteriaRunning = false

    local function ToggleAutoLeaveWisteria(state)
        autoLeaveWisteriaRunning = state
        if state then
            task.spawn(function()
                local remotesFolder = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 15)
                if not remotesFolder then return end
                local leaveRemote = remotesFolder:FindFirstChild("LeaveRaid")
                               or remotesFolder:FindFirstChild("EndRaid")
                while autoLeaveWisteriaRunning do
                    if IsInDungeon() then
                        local w = GetCurrentWisteriaWave()
                        local leaveWave = Options.WisteriaLeaveWave and Options.WisteriaLeaveWave.Value or 5
                        if w and w >= leaveWave then
                            DoLeaveWisteria(leaveRemote)
                            task.wait(6) -- cooldown after leaving
                        end
                    end
                    task.wait(2)
                end
            end)
        end
    end

    local AutoLeaveWisteriaToggle = Tabs.Raid:AddToggle("AutoLeaveWisteria", {Title = "Auto Leave W4 Raid at Wave #", Default = false })
    AutoLeaveWisteriaToggle:OnChanged(function()
        ToggleAutoLeaveWisteria(Options.AutoLeaveWisteria.Value)
    end)

    -- Manual leave button — press any time to immediately leave the current raid
    Tabs.Raid:AddButton({
        Title = "Leave Raid Now",
        Description = "Immediately fires LeaveRaid and returns you to your saved position.",
        Callback = function()
            local remotesFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
            if remotesFolder then
                local leaveRemote = remotesFolder:FindFirstChild("LeaveRaid")
                                 or remotesFolder:FindFirstChild("EndRaid")
                FireRemoteSafe(leaveRemote)
                task.wait(1)
                local character = Player.Character
                if character and character:FindFirstChild("HumanoidRootPart") and safeWorldCF then
                    character.HumanoidRootPart.CFrame = safeWorldCF
                end
                Fluent:Notify({Title = "W4 Raid", Content = "Left raid manually.", Duration = 3})
            end
        end
    })

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
    -- Anti-AFK (Multi-Layer Rejoin Bypass)
    -- =====================================
    local antiAfkActive = false
    local antiAfkConnections = {}

    local function StopAntiAfk()
        antiAfkActive = false
        for _, conn in ipairs(antiAfkConnections) do
            if conn and conn.Connected then
                conn:Disconnect()
            end
        end
        antiAfkConnections = {}
    end

    local function ToggleAntiAfk(state)
        if state then
            if antiAfkActive then return end -- Already running
            antiAfkActive = true

            -- ── Layer 1: VirtualUser on Roblox's engine Idle event (20-min timer) ──
            pcall(function()
                local VirtualUser = game:GetService("VirtualUser")
                local conn = Player.Idled:Connect(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
                table.insert(antiAfkConnections, conn)
            end)

            -- ── Layer 2: Periodic fake input every 25s to outrun game-side timers ──
            -- Many games have their OWN AFK kick timers (often 60-300s).
            -- Simulating input prevents those from ever triggering.
            task.spawn(function()
                local VirtualUser = game:GetService("VirtualUser")
                local UIS = game:GetService("UserInputService")
                while antiAfkActive do
                    pcall(function()
                        -- Simulate mouse movement + a button press to reset ALL idle counters
                        VirtualUser:CaptureController()
                        VirtualUser:ClickButton2(Vector2.new())
                        VirtualUser:MoveMouse(Vector2.new(1, 0), Vector2.new(0, 0))
                    end)
                    task.wait(25)
                end
            end)

            -- ── Layer 3: Simulate character activity every 45s ──
            -- Some games check whether your Humanoid has moved recently.
            -- A tiny CFrame nudge keeps the server-side activity tracker satisfied.
            task.spawn(function()
                while antiAfkActive do
                    pcall(function()
                        local character = Player.Character
                        if character then
                            local hrp = character:FindFirstChild("HumanoidRootPart")
                            local humanoid = character:FindFirstChild("Humanoid")
                            if hrp and humanoid and humanoid.Health > 0 then
                                -- Tiny nudge: shift 0.05 studs and back so physics registers movement
                                local origin = hrp.CFrame
                                hrp.CFrame = origin * CFrame.new(0.05, 0, 0)
                                task.wait(0.05)
                                hrp.CFrame = origin
                            end
                        end
                    end)
                    task.wait(45)
                end
            end)

            -- ── Layer 4: Block ALL AutoRejoin Vectors ──
            -- This game uses AutoRejoinRun / AutoRejoinTeleport / AutoRejoinTrain
            -- remotes in ReplicatedStorage. Rejoin can happen 3 ways:
            --   A) Server fires remote → client LocalScript calls TeleportService  [block OnClientEvent]
            --   B) Client LocalScript detects AFK → fires remote to server → server kicks [block FireServer]
            --   C) Server calls TeleportService or player:Kick() directly            [hook metamethod]
            -- We cover ALL three below.
            task.spawn(function()
                local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 15)
                if not remotes then return end

                local REJOIN_REMOTES = {
                    "AutoRejoinRun",
                    "AutoRejoinTeleport",
                    "AutoRejoinTrain",
                }

                -- ── 4A: Disconnect existing OnClientEvent listeners + dummy absorber ──
                local function NukeRejoinListeners()
                    for _, remoteName in ipairs(REJOIN_REMOTES) do
                        local remote = remotes:FindFirstChild(remoteName)
                        if remote and remote:IsA("RemoteEvent") then
                            if getconnections then
                                for _, conn in ipairs(getconnections(remote.OnClientEvent)) do
                                    pcall(function() conn:Disconnect() end)
                                end
                            end
                            -- Dummy absorber swallows any future server fires
                            remote.OnClientEvent:Connect(function() end)
                        end
                    end
                end

                NukeRejoinListeners()
                -- Re-check every 30s in case the game script reconnects
                task.spawn(function()
                    while antiAfkActive do
                        task.wait(30)
                        NukeRejoinListeners()
                    end
                end)

                -- ── 4B: Block client→server "report AFK" FireServer calls ──
                -- If the LocalScript fires AutoRejoin*:FireServer() to tell the
                -- server to kick this player, intercept and swallow it.
                if hookmetamethod and getnamecallmethod then
                    pcall(function()
                        local rejoinSet = {}
                        for _, name in ipairs(REJOIN_REMOTES) do
                            local r = remotes:FindFirstChild(name)
                            if r then rejoinSet[r] = true end
                        end

                        local mt = getrawmetatable(game)
                        local oldNamecall = mt.__namecall
                        setreadonly(mt, false)
                        mt.__namecall = newcclosure(function(self, ...)
                            local method = getnamecallmethod()
                            -- Block FireServer on any of the AutoRejoin remotes
                            if rejoinSet[self] and (method == "FireServer" or method == "InvokeServer") then
                                return -- swallow silently
                            end
                            -- Block TeleportService (vector C) — only while anti-AFK is on
                            if antiAfkActive then
                                local ok, ts = pcall(function() return game:GetService("TeleportService") end)
                                if ok and self == ts and (
                                    method == "Teleport" or
                                    method == "TeleportAsync" or
                                    method == "TeleportToPlaceInstance" or
                                    method == "TeleportPartyAsync"
                                ) then
                                    return -- block ALL teleports while anti-AFK is active
                                end
                            end
                            return oldNamecall(self, ...)
                        end)
                        setreadonly(mt, true)
                    end)
                end

                -- ── 4C: Hook player:Kick() to prevent server-initiated kicks ──
                -- Some games call player:Kick() directly. We override the method.
                pcall(function()
                    local oldKick = Player.Kick
                    Player.Kick = function(self, ...)
                        if antiAfkActive then
                            -- Silently ignore kick calls while anti-AFK is running
                            return
                        end
                        return oldKick(self, ...)
                    end
                end)
            end)

        else
            StopAntiAfk()
        end
    end

    local AntiAfkToggle = Tabs.Main:AddToggle("AntiAfk", {Title = "Anti-AFK (Multi-Layer)", Default = true })
    AntiAfkToggle:OnChanged(function()
        ToggleAntiAfk(Options.AntiAfk.Value)
    end)

    -- Initialize default state immediately on load
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
