return function(Core)
    -- UI SETUP
    local secSmartFarm = Core.UI.createSection(Core.Pages.Farm, "Smart Auto-Farm Engine")
    Core.UI.createButton("Select Grid Farm", secSmartFarm, function() Core.UI.popupOverlay.Visible = true end)
    
    -- Filter agar sapling/seed tidak masuk ke dropdown Place
    Core.UI.createInventoryDropdown("Item to Place", "smartFarmItem", secSmartFarm, nil, function(itemName, itemId)
        local n = string.lower(itemName); local id = string.lower(itemId)
        if string.find(n, "sapling") or string.find(id, "sapling") or string.find(n, "seed") or string.find(id, "seed") then return false end
        return true
    end)
    
    Core.UI.createInputRow("Delay Break (ms)", "250", secSmartFarm, 0.35, "smartFarmDelayBox")
    local updateSmartFarmToggle = Core.UI.createToggle("Enable Smart Farm Engine", "smartAutoFarm", secSmartFarm, false)

    local secPlanter = Core.UI.createSection(Core.Pages.Farm, "Auto Planter (Custom Base)")
    Core.UI.createInventoryDropdown("Base Block", "planterBase", secPlanter)
    Core.UI.createInventoryDropdown("Item to Plant", "planterItem", secPlanter)
    Core.UI.createInputRow("Move Speed", "45", secPlanter, 0.35, "planterSpeedBox")
    local updatePlanterToggle = Core.UI.createToggle("Enable Auto Planter", "autoPlanter", secPlanter, false)

    local secBreaker = Core.UI.createSection(Core.Pages.Farm, "Auto Breaker (Zig-Zag)")
    Core.UI.createInventoryDropdown("Target to Break", "breakerTarget", secBreaker)
    Core.UI.createInputRow("Move Speed", "45", secBreaker, 0.35, "breakerSpeedBox")
    Core.UI.createToggle("Enable Auto Breaker", "autoBreaker", secBreaker, false)
    Core.UI.createInputRow("Hit Spam / Break", "55", secBreaker, 0.50, "hitMultiplierBox")
    Core.UI.createToggle("One Hit Break (Burst)", "oneHitBreak", secBreaker, true)

    local secLoot = Core.UI.createSection(Core.Pages.Farm, "Genius Auto-Loot")
    Core.UI.createInputRow("AI Run Speed", "45", secLoot, 0.35, "lootSpeedBox") 
    Core.UI.createToggle("Radar Item Drop", "itemRadar", secLoot, false)
    Core.UI.createToggle("Enable Auto-Loot", "autoLoot", secLoot, false) 

    -- FITUR: INVENTORY & DROP MANAGER
    local secDrop = Core.UI.createSection(Core.Pages.Farm, "Inventory & Drop Manager")
    Core.UI.createInventoryDropdown("Item to Drop", "dropTargetItem", secDrop)
    local dropAmtBox = Core.UI.createInputRow("Amount to Drop", "200", secDrop, 0.35, "dropAmountBox")
    
    local function executeDrop(targetStr, totalToDrop)
        if not targetStr or targetStr == "" then return end
        if Core.Managers.InventoryModule and Core.Managers.InventoryModule.Stacks then
            for i = 1, (Core.Managers.InventoryModule.MaxSlots or 100) do
                if totalToDrop <= 0 then break end
                local stackInfo = Core.Managers.InventoryModule.Stacks[i]
                if stackInfo and stackInfo.Id and stackInfo.Amount and stackInfo.Amount > 0 then
                    local currentID = string.lower(tostring(stackInfo.Id))
                    local itemName = currentID
                    if Core.Managers.ItemsManager and Core.Managers.ItemsManager.ItemsData and Core.Managers.ItemsManager.ItemsData[tostring(stackInfo.Id)] then
                        itemName = string.lower(tostring(Core.Managers.ItemsManager.ItemsData[tostring(stackInfo.Id)].Name or currentID))
                    end
                    
                    if currentID == targetStr or itemName == targetStr then
                        local stackLeft = stackInfo.Amount
                        while stackLeft > 0 and totalToDrop > 0 do
                            local dropNow = math.min(totalToDrop, stackLeft, 200) 
                            pcall(function()
                                local ReplicatedStorage = game:GetService("ReplicatedStorage")
                                local playerDropRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PlayerDrop")
                                local promptRemote = ReplicatedStorage:WaitForChild("Managers"):WaitForChild("UIManager"):WaitForChild("UIPromptEvent")
                                
                                playerDropRemote:FireServer(i)
                                task.wait(0.05)
                                promptRemote:FireServer({
                                    ButtonAction = "drp",
                                    Inputs = { amt = tostring(dropNow) }
                                })
                                task.wait(0.1)
                            end)
                            totalToDrop = totalToDrop - dropNow
                            stackLeft = stackLeft - dropNow
                        end
                    end
                end
            end
        end
    end

    Core.UI.createButton("Drop Amount Now", secDrop, function()
        local target = string.lower(Core.Toggles.dropTargetItem or "auto")
        if target == "auto" then target = Core.Utils.getHeldItem() end
        local amt = tonumber(dropAmtBox.Text) or 200
        task.spawn(function() executeDrop(target, amt) end)
    end)
    Core.UI.createToggle("Auto Drop (Loop)", "autoDropLoop", secDrop, false)

    -- =========================================================================
    -- LOGIC & ENGINE
    -- =========================================================================

    -- [ FPS BOOSTER ] GLOBAL ANCHOR MANAGER 
    -- Mengunci fisik karakter jika salah satu fitur auto menyala agar tidak terjadi FPS Drop
    task.spawn(function()
        while task.wait(0.2) do
            pcall(function()
                local char = Core.LocalPlayer.Character
                local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
                if hrp then
                    local isBotting = Core.Toggles.smartAutoFarm or Core.Toggles.autoPlanter or Core.Toggles.autoBreaker or Core.Toggles.autoLoot
                    if isBotting then
                        if not hrp.Anchored then hrp.Anchored = true end
                    else
                        if hrp.Anchored then hrp.Anchored = false end
                    end
                end
            end)
        end
    end)

    -- LOOP AUTO DROP ITEM
    task.spawn(function()
        while task.wait(1) do
            if Core.Toggles.autoDropLoop then
                local target = string.lower(Core.Toggles.dropTargetItem or "auto")
                if target == "auto" then target = Core.Utils.getHeldItem() end
                local amt = tonumber(dropAmtBox.Text) or 200
                executeDrop(target, amt)
            end
        end
    end)

    -- SMART AUTO FARM ENGINE (AI STATE MACHINE MASTERPIECE)
    local farmPhase = "PLACE" 
    local farmStartPos = nil
    local isOutOfItems = false 

    task.spawn(function()
        while task.wait() do
            pcall(function()
                if Core.Toggles.smartAutoFarm and Core.Managers.MovementState and Core.Remotes.PlayerFistRemote and Core.Remotes.PlayerPlaceRemote then
                    
                    if not farmStartPos then farmStartPos = Core.Managers.MovementState.Position end
                    local startPx = math.floor(farmStartPos.X / Core.Utils.TILE_SIZE + 0.5)
                    local startPy = math.floor(farmStartPos.Y / Core.Utils.TILE_SIZE + 0.5)
                    
                    local targetList = {}
                    for key, isSelected in pairs(Core.Toggles.farmGrids or {}) do
                        if isSelected then
                            local dxStr, dyStr = string.match(key, "([%d%-]+),([%d%-]+)")
                            if dxStr and dyStr then
                                local dx, dy = tonumber(dxStr), tonumber(dyStr)
                                table.insert(targetList, {x = startPx + dx, y = startPy + dy, dx = dx, dy = dy})
                            end
                        end
                    end
                    
                    if #targetList > 0 then
                        -- FASE 1: PLACE ITEM
                        if farmPhase == "PLACE" then
                            table.sort(targetList, function(a, b)
                                if a.dy == b.dy then return a.dx > b.dx end
                                return a.dy > b.dy 
                            end)

                            local itemHabis = false
                            local placedAny = false

                            for i = 1, #targetList do
                                if not Core.Toggles.smartAutoFarm then break end 
                                
                                local targetGrid = Vector2.new(targetList[i].x, targetList[i].y)
                                local hasBlock = false
                                
                                if Core.Managers.WorldManager and Core.Managers.WorldManager.GetTile then
                                    for l = 1, 5 do if Core.Managers.WorldManager.GetTile(targetList[i].x, targetList[i].y, l) then hasBlock = true break end end
                                end
                                
                                if not hasBlock then
                                    local targetStringID = string.lower(Core.Toggles.smartFarmItem or "auto")
                                    if targetStringID == "auto" or targetStringID == "" then
                                        local held = Core.Utils.getHeldItem()
                                        if held then targetStringID = held end
                                    end
                                    
                                    local slotIndexToSend = tonumber(targetStringID) 
                                    if not slotIndexToSend and Core.Managers.InventoryModule and Core.Managers.InventoryModule.Stacks then
                                        local exactMatch, partialMatch = nil, nil
                                        for j = 1, (Core.Managers.InventoryModule.MaxSlots or 100) do
                                            local stackInfo = Core.Managers.InventoryModule.Stacks[j]
                                            if stackInfo and stackInfo.Id and stackInfo.Amount and stackInfo.Amount > 0 then
                                                local currentID = string.lower(tostring(stackInfo.Id))
                                                local itemName = currentID
                                                if Core.Managers.ItemsManager and Core.Managers.ItemsManager.ItemsData and Core.Managers.ItemsManager.ItemsData[tostring(stackInfo.Id)] then
                                                    itemName = string.lower(tostring(Core.Managers.ItemsManager.ItemsData[tostring(stackInfo.Id)].Name or currentID))
                                                end
                                                
                                                if not string.find(currentID, "sapling") and not string.find(itemName, "sapling") and not string.find(currentID, "seed") and not string.find(itemName, "seed") then
                                                    local baseID = Core.Utils.getBaseId(currentID) 
                                                    if baseID == targetStringID or currentID == targetStringID or itemName == targetStringID then 
                                                        exactMatch = j 
                                                        break 
                                                    elseif (string.find(currentID, targetStringID) or string.find(itemName, targetStringID)) and not partialMatch then 
                                                        partialMatch = j 
                                                    end
                                                end
                                            end
                                        end
                                        slotIndexToSend = exactMatch or partialMatch
                                    end
                                    
                                    if slotIndexToSend then 
                                        Core.Remotes.PlayerPlaceRemote:FireServer(targetGrid, slotIndexToSend)
                                        placedAny = true
                                        task.wait(0.05) 
                                    else
                                        itemHabis = true
                                        break
                                    end
                                end
                            end
                            
                            if itemHabis then
                                print("[NLight] Smart Auto-Farm: Item habis! Masuk ke fase panen terakhir...")
                                isOutOfItems = true
                                farmPhase = "BREAK"
                            elseif not placedAny then
                                farmPhase = "BREAK"
                            end

                        -- FASE 2: BREAK ITEM
                        elseif farmPhase == "BREAK" then
                            table.sort(targetList, function(a, b)
                                if a.dy == b.dy then return a.dx > b.dx end
                                return a.dy > b.dy 
                            end)

                            local delayBreakMs = tonumber(Core.Inputs["smartFarmDelayBox"] and Core.Inputs["smartFarmDelayBox"].Text) or 250
                            local brokeAny = false
                            
                            for i = 1, #targetList do
                                if not Core.Toggles.smartAutoFarm then break end
                                
                                local targetGrid = Vector2.new(targetList[i].x, targetList[i].y)
                                local hasBlock = false
                                
                                if Core.Managers.WorldManager and Core.Managers.WorldManager.GetTile then
                                    for l = 1, 5 do if Core.Managers.WorldManager.GetTile(targetList[i].x, targetList[i].y, l) then hasBlock = true break end end
                                end

                                if hasBlock then
                                    local hitsToSend = 25 
                                    for j = 1, hitsToSend do Core.Remotes.PlayerFistRemote:FireServer(targetGrid) end
                                    task.wait(delayBreakMs / 1000)
                                    brokeAny = true
                                    break 
                                end
                            end

                            if not brokeAny then
                                farmPhase = "LOOT"
                            end

                        -- FASE 3: LOOT ITEM
                        elseif farmPhase == "LOOT" then
                            task.wait(0.3) 

                            local dropsFolder = workspace:FindFirstChild("Drops") or workspace:FindFirstChild("DroppedItems") or workspace:FindFirstChild("Items")
                            local itemsToLoot = {}
                            if dropsFolder then
                                for _, v in ipairs(dropsFolder:GetChildren()) do if v:IsA("BasePart") or v:IsA("Model") then table.insert(itemsToLoot, v) end end
                            else
                                for _, obj in ipairs(workspace:GetChildren()) do
                                    if obj:IsA("BasePart") and not obj:IsDescendantOf(Core.LocalPlayer.Character) and not Core.Players:GetPlayerFromCharacter(obj.Parent) and obj.Size.Y < 3 then table.insert(itemsToLoot, obj) end
                                end
                            end
                            
                            local didLoot = false

                            if #itemsToLoot > 0 then
                                table.sort(itemsToLoot, function(a, b)
                                    local posA = a:IsA("BasePart") and a.Position or (a:IsA("Model") and a.PrimaryPart and a.PrimaryPart.Position) or Vector3.new(9999,9999,9999)
                                    local posB = b:IsA("BasePart") and b.Position or (b:IsA("Model") and b.PrimaryPart and b.PrimaryPart.Position) or Vector3.new(9999,9999,9999)
                                    return posA.X < posB.X
                                end)
                                
                                local moveSpeed = 45
                                
                                for _, item in ipairs(itemsToLoot) do
                                    if not Core.Toggles.smartAutoFarm then break end
                                    local part = item:IsA("BasePart") and item or (item:IsA("Model") and item.PrimaryPart)
                                    if part and part.Parent then
                                        local endX = math.floor(part.Position.X / Core.Utils.TILE_SIZE + 0.5)
                                        local endY = math.floor(part.Position.Y / Core.Utils.TILE_SIZE + 0.5)
                                        local distFromStart = math.sqrt((endX - startPx)^2 + (endY - startPy)^2)
                                        
                                        if distFromStart <= 15 and not Core.Pathfinding.isOutOfBounds(endX, endY) and not Core.Pathfinding.isItemTrapped(endX, endY) then
                                            Core.Pathfinding.aiMoveTo(endX, endY, moveSpeed, "smartAutoFarm")
                                            didLoot = true
                                        end
                                    end
                                end
                                
                                if didLoot and Core.Toggles.smartAutoFarm then
                                    Core.Pathfinding.aiMoveTo(startPx, startPy, moveSpeed, "smartAutoFarm")
                                    Core.Managers.MovementState.Position = farmStartPos
                                    Core.Managers.MovementState.OldPosition = farmStartPos
                                end
                            end
                            
                            if isOutOfItems then
                                print("[NLight] Smart Auto-Farm: Siklus terakhir selesai. Bot dimatikan.")
                                Core.Toggles.smartAutoFarm = false
                                if updateSmartFarmToggle then updateSmartFarmToggle() end
                                farmStartPos = nil
                                farmPhase = "PLACE"
                                isOutOfItems = false
                            else
                                farmPhase = "PLACE"
                            end
                        end
                    else
                        Core.Toggles.smartAutoFarm = false
                        if updateSmartFarmToggle then updateSmartFarmToggle() end
                        print("[NLight] Harap pilih minimal satu Grid melalui tombol 'Select Grid Farm'!")
                        task.wait(1)
                    end
                else
                    farmStartPos = nil
                    farmPhase = "PLACE"
                    isOutOfItems = false
                end
            end)
        end
    end)

    -- AUTO PLANTER
    task.spawn(function()
        while task.wait() do
            pcall(function()
                if Core.Toggles.autoPlanter and Core.Managers.MovementState and Core.Remotes.PlayerPlaceRemote then
                    local pPos = Core.Managers.MovementState.Position
                    local plantStr = string.lower(Core.Toggles.planterItem or "auto")
                    local baseStr = string.lower(Core.Toggles.planterBase or "dirt")
                    
                    if plantStr == "auto" or plantStr == "" then local held = Core.Utils.getHeldItem(); if held then plantStr = held end end
                    if baseStr == "auto" or baseStr == "" then local held = Core.Utils.getHeldItem(); if held then baseStr = held else baseStr = "dirt" end end
                    if plantStr == "" or baseStr == "" then return end

                    local slotIndexToSend = tonumber(plantStr)
                    if not slotIndexToSend and Core.Managers.InventoryModule and Core.Managers.InventoryModule.Stacks then
                        local exactMatch, partialMatch = nil, nil
                        for i = 1, (Core.Managers.InventoryModule.MaxSlots or 100) do
                            local stackInfo = Core.Managers.InventoryModule.Stacks[i]
                            if stackInfo and stackInfo.Id and stackInfo.Amount and stackInfo.Amount > 0 then
                                local currentID = string.lower(tostring(stackInfo.Id))
                                local itemName = currentID
                                if Core.Managers.ItemsManager and Core.Managers.ItemsManager.ItemsData and Core.Managers.ItemsManager.ItemsData[tostring(stackInfo.Id)] then
                                    itemName = string.lower(tostring(Core.Managers.ItemsManager.ItemsData[tostring(stackInfo.Id)].Name or currentID))
                                end
                                if currentID == plantStr or itemName == plantStr then exactMatch = i break
                                elseif (string.find(currentID, plantStr) or string.find(itemName, plantStr)) and not partialMatch then partialMatch = i end
                            end
                        end
                        slotIndexToSend = exactMatch or partialMatch
                    end

                    if not slotIndexToSend then
                        print("[NLight] Auto Planter: Item habis atau tidak ditemukan!"); Core.Toggles.autoPlanter = false; updatePlanterToggle(); return
                    end

                    local validSpots = {}
                    local minBound, maxBound = workspace:GetAttribute("WorldMin"), workspace:GetAttribute("WorldMax")
                    if minBound and maxBound and Core.Managers.WorldManager and Core.Managers.WorldManager.GetTile then
                        for x = minBound.X, maxBound.X do
                            for y = minBound.Y, maxBound.Y do
                                local tileBelow = Core.Managers.WorldManager.GetTile(x, y - 1, 1)
                                local tileCurrent = Core.Managers.WorldManager.GetTile(x, y, 1)
                                local isMatchBase = false
                                if tileBelow then
                                    if Core.Managers.ItemsManager and Core.Managers.ItemsManager.ItemsData and Core.Managers.ItemsManager.ItemsData[tileBelow] then
                                        if string.find(string.lower(tostring(Core.Managers.ItemsManager.ItemsData[tileBelow].Name)), baseStr) then isMatchBase = true end
                                    elseif string.find(string.lower(tostring(tileBelow)), baseStr) then isMatchBase = true end
                                end
                                if isMatchBase and not tileCurrent and not Core.Pathfinding.blacklistedSpots[x..","..y] then table.insert(validSpots, {x = x, y = y}) end
                            end
                        end
                    end

                    if #validSpots > 0 then
                        local rows = {}
                        for _, spot in ipairs(validSpots) do rows[spot.y] = rows[spot.y] or {}; table.insert(rows[spot.y], spot) end
                        local targetY, minYDist = validSpots[1].y, math.huge
                        for y, _ in pairs(rows) do
                            local yDist = math.abs(pPos.Y - (y * Core.Utils.TILE_SIZE))
                            if yDist < minYDist then minYDist = yDist; targetY = y end
                        end
                        local rowSpots = rows[targetY]
                        table.sort(rowSpots, function(a, b) return a.x > b.x end)
                        local targetSpot = rowSpots[1]
                        local moveSpeed = tonumber(Core.Inputs["planterSpeedBox"] and Core.Inputs["planterSpeedBox"].Text or "45") or 45
                        
                        if Core.Pathfinding.aiMoveTo(targetSpot.x, targetSpot.y, moveSpeed, "autoPlanter") then
                            Core.Remotes.PlayerPlaceRemote:FireServer(Vector2.new(targetSpot.x, targetSpot.y), slotIndexToSend)
                            task.wait(0.1)
                        else
                            Core.Pathfinding.blacklistedSpots[targetSpot.x..","..targetSpot.y] = true
                        end
                    end
                end
            end)
        end
    end)

    -- AUTO BREAKER
    task.spawn(function()
        while task.wait() do
            pcall(function()
                if Core.Toggles.autoBreaker and Core.Managers.MovementState and Core.Remotes.PlayerFistRemote then
                    local pPos = Core.Managers.MovementState.Position
                    local targetStr = string.lower(Core.Toggles.breakerTarget or "wood")
                    if targetStr == "auto" or targetStr == "" then local held = Core.Utils.getHeldItem(); if held then targetStr = held else targetStr = "wood" end end
                    if targetStr == "" then return end

                    local validSpots = {}
                    local minBound, maxBound = workspace:GetAttribute("WorldMin"), workspace:GetAttribute("WorldMax")
                    if minBound and maxBound and Core.Managers.WorldManager and Core.Managers.WorldManager.GetTile then
                        for x = minBound.X, maxBound.X do
                            for y = minBound.Y, maxBound.Y do
                                local tileCurrent = Core.Managers.WorldManager.GetTile(x, y, 1)
                                if tileCurrent and not Core.Pathfinding.blacklistedSpots[x..","..y] then
                                    local isMatch = false
                                    if Core.Managers.ItemsManager and Core.Managers.ItemsManager.ItemsData and Core.Managers.ItemsManager.ItemsData[tileCurrent] then
                                        if string.find(string.lower(tostring(Core.Managers.ItemsManager.ItemsData[tileCurrent].Name)), targetStr) then isMatch = true end
                                    elseif string.find(string.lower(tostring(tileCurrent)), targetStr) then isMatch = true end
                                    if isMatch then table.insert(validSpots, {x = x, y = y}) end
                                end
                            end
                        end
                    end

                    if #validSpots > 0 then
                        local rows, sortedY = {}, {}
                        for _, spot in ipairs(validSpots) do
                            if not rows[spot.y] then rows[spot.y] = {}; table.insert(sortedY, spot.y) end
                            table.insert(rows[spot.y], spot)
                        end
                        table.sort(sortedY, function(a, b) return a < b end)
                        local targetY, minYDist, yIndex = sortedY[1], math.huge, 1
                        for i, y in ipairs(sortedY) do
                            local yDist = math.abs(pPos.Y - (y * Core.Utils.TILE_SIZE))
                            if yDist < minYDist then minYDist = yDist; targetY = y; yIndex = i end
                        end
                        local rowSpots = rows[targetY]
                        if yIndex % 2 == 0 then table.sort(rowSpots, function(a, b) return a.x < b.x end) else table.sort(rowSpots, function(a, b) return a.x > b.x end) end
                        local targetSpot = rowSpots[1]
                        local moveSpeed = tonumber(Core.Inputs["breakerSpeedBox"] and Core.Inputs["breakerSpeedBox"].Text or "45") or 45
                        
                        if Core.Pathfinding.aiMoveTo(targetSpot.x, targetSpot.y, moveSpeed, "autoBreaker") then
                            local hitsToSend = Core.Toggles.oneHitBreak and (tonumber(Core.Inputs["hitMultiplierBox"] and Core.Inputs["hitMultiplierBox"].Text or "25") or 25) or 1
                            for i = 1, hitsToSend do Core.Remotes.PlayerFistRemote:FireServer(Vector2.new(targetSpot.x, targetSpot.y)) end
                            if not Core.Toggles.antiLag and Core.Managers.PCM and Core.Managers.PCM.SpawnHitParticle then Core.Managers.PCM.SpawnHitParticle(Vector3.new(targetSpot.x * Core.Utils.TILE_SIZE, targetSpot.y * Core.Utils.TILE_SIZE, 0)) end
                            task.wait(0.1)
                        else
                            Core.Pathfinding.blacklistedSpots[targetSpot.x..","..targetSpot.y] = true
                        end
                    end
                end
            end)
        end
    end)

    -- GENIUS AUTO LOOT (Global)
    task.spawn(function()
        while task.wait(0.1) do
            pcall(function()
                if Core.Toggles.autoLoot and Core.Managers.MovementState then
                    local pPos = Core.Managers.MovementState.Position
                    local dropsFolder = workspace:FindFirstChild("Drops") or workspace:FindFirstChild("DroppedItems") or workspace:FindFirstChild("Items")
                    local itemsToLoot = {}
                    if dropsFolder then
                        for _, v in ipairs(dropsFolder:GetChildren()) do
                            if (v:IsA("BasePart") or v:IsA("Model")) and not Core.Pathfinding.blacklistedItems[v] then table.insert(itemsToLoot, v) end
                        end
                    else
                        for _, obj in ipairs(workspace:GetChildren()) do
                            if obj:IsA("BasePart") and not obj:IsDescendantOf(Core.LocalPlayer.Character) and not Core.Players:GetPlayerFromCharacter(obj.Parent) and obj.Size.Y < 3 and not Core.Pathfinding.blacklistedItems[obj] then table.insert(itemsToLoot, obj) end
                        end
                    end
                    if #itemsToLoot > 0 then
                        table.sort(itemsToLoot, function(a, b)
                            local posA = a:IsA("BasePart") and a.Position or (a:IsA("Model") and a.PrimaryPart and a.PrimaryPart.Position) or Vector3.new(9999,9999,9999)
                            local posB = b:IsA("BasePart") and b.Position or (b:IsA("Model") and b.PrimaryPart and b.PrimaryPart.Position) or Vector3.new(9999,9999,9999)
                            return (pPos - posA).Magnitude < (pPos - posB).Magnitude
                        end)
                        local moveSpeed = tonumber(Core.Inputs["lootSpeedBox"] and Core.Inputs["lootSpeedBox"].Text or "45") or 45
                        for _, item in ipairs(itemsToLoot) do
                            if not Core.Toggles.autoLoot then break end
                            local part = item:IsA("BasePart") and item or (item:IsA("Model") and item.PrimaryPart)
                            if part and part.Parent then
                                local endX = math.floor(part.Position.X / Core.Utils.TILE_SIZE + 0.5)
                                local endY = math.floor(part.Position.Y / Core.Utils.TILE_SIZE + 0.5)
                                if Core.Pathfinding.isOutOfBounds(endX, endY) or Core.Pathfinding.isItemTrapped(endX, endY) then
                                    Core.Pathfinding.blacklistedItems[item] = true
                                else
                                    if not Core.Pathfinding.aiMoveTo(endX, endY, moveSpeed, "autoLoot") then Core.Pathfinding.blacklistedItems[item] = true end
                                end
                            end
                        end
                    end
                end
            end)
        end
    end)
end
