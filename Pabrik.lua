return function(Core)
    -- ==========================================
    -- UI SETUP: SMART PABRIK
    -- ==========================================
    local secSetup = Core.UI.createSection(Core.Pages.Pabrik, "1. Pabrik Position & Grid")
    
    local savedPosDisplay = Core.UI.createLabelDisplay("Status: POSISI BELUM DI-SAVE!", secSetup)
    Core.UI.createButton("Save Current Position", secSetup, function()
        if Core.Managers.MovementState then
            local p = Core.Managers.MovementState.Position
            Core.Toggles.pabrikFarmPos = p
            local px = math.floor(p.X / Core.Utils.TILE_SIZE + 0.5)
            local py = math.floor(p.Y / Core.Utils.TILE_SIZE + 0.5)
            savedPosDisplay.Text = string.format("Saved Pos: X: %d, Y: %d", px, py)
        end
    end)
    Core.UI.createButton("Select Grid Farm", secSetup, function() Core.UI.popupOverlay.Visible = true end)

    local secItems = Core.UI.createSection(Core.Pages.Pabrik, "2. Pabrik Item Configuration")
    Core.UI.createInventoryDropdown("1. Farm Item (Place)", "pabrikFarmItem", secItems)
    Core.UI.createInventoryDropdown("2. Sapling / Seed", "pabrikSapling", secItems)
    Core.UI.createInventoryDropdown("3. Base Block (Soil)", "pabrikBase", secItems)
    Core.UI.createInventoryDropdown("4. Target to Panen", "pabrikTarget", secItems)

    local secEngine = Core.UI.createSection(Core.Pages.Pabrik, "3. Engine Control")
    Core.UI.createInputRow("Delay Break (ms)", "250", secEngine, 0.35, "pabrikDelayBox")
    Core.UI.createInputRow("Move Speed", "45", secEngine, 0.35, "pabrikSpeedBox")
    
    local pabrikPhaseDisplay = Core.UI.createLabelDisplay("Phase: IDLE", secEngine)
    local updatePabrikToggle = Core.UI.createToggle("START SMART PABRIK", "smartPabrik", secEngine, false)

    -- ==========================================
    -- SMART PABRIK AI (MASTER STATE MACHINE)
    -- ==========================================
    local pabrikPhase = "FARM_PLACE"
    
    -- Utility untuk mencari slot item
    local function getSlot(targetStringID)
        if targetStringID == "auto" or targetStringID == "" then targetStringID = Core.Utils.getHeldItem() end
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
                    local baseID = Core.Utils.getBaseId(currentID) 
                    if baseID == targetStringID or currentID == targetStringID or itemName == targetStringID then exactMatch = j break 
                    elseif (string.find(currentID, targetStringID) or string.find(itemName, targetStringID)) and not partialMatch then partialMatch = j end
                end
            end
            slotIndexToSend = exactMatch or partialMatch
        end
        return slotIndexToSend
    end

    task.spawn(function()
        while task.wait() do
            pcall(function()
                if Core.Toggles.smartPabrik and Core.Managers.MovementState and Core.Remotes.PlayerFistRemote and Core.Remotes.PlayerPlaceRemote then
                    
                    -- Proteksi: Harus set posisi dulu
                    if not Core.Toggles.pabrikFarmPos then
                        Core.Toggles.smartPabrik = false
                        if updatePabrikToggle then updatePabrikToggle() end
                        print("[NLight Pabrik] GAGAL: Harap 'Save Current Position' terlebih dahulu!")
                        task.wait(1)
                        return
                    end

                    local char = Core.LocalPlayer.Character
                    local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
                    local moveSpeed = tonumber(Core.Inputs["pabrikSpeedBox"] and Core.Inputs["pabrikSpeedBox"].Text) or 45
                    local delayBreakMs = tonumber(Core.Inputs["pabrikDelayBox"] and Core.Inputs["pabrikDelayBox"].Text) or 250
                    
                    pabrikPhaseDisplay.Text = "Phase: " .. pabrikPhase

                    -- Susun Target Grid Farm
                    local startPx = math.floor(Core.Toggles.pabrikFarmPos.X / Core.Utils.TILE_SIZE + 0.5)
                    local startPy = math.floor(Core.Toggles.pabrikFarmPos.Y / Core.Utils.TILE_SIZE + 0.5)
                    local farmList = {}
                    for key, isSelected in pairs(Core.Toggles.farmGrids or {}) do
                        if isSelected then
                            local dx, dy = string.match(key, "([%d%-]+),([%d%-]+)")
                            if dx and dy then table.insert(farmList, {x = startPx + tonumber(dx), y = startPy + tonumber(dy), dx = tonumber(dx), dy = tonumber(dy)}) end
                        end
                    end
                    table.sort(farmList, function(a, b) if a.dy == b.dy then return a.dx > b.dx end; return a.dy > b.dy end)

                    -- ==========================================================
                    -- 1. FASE FARM PLACE
                    -- ==========================================================
                    if pabrikPhase == "FARM_PLACE" then
                        if hrp and not hrp.Anchored then hrp.Anchored = true end 

                        local itemHabis = false
                        local placedAny = false

                        for i = 1, #farmList do
                            if not Core.Toggles.smartPabrik then break end 
                            local targetGrid = Vector2.new(farmList[i].x, farmList[i].y)
                            local hasBlock = false
                            if Core.Managers.WorldManager and Core.Managers.WorldManager.GetTile then
                                for l = 1, 5 do if Core.Managers.WorldManager.GetTile(farmList[i].x, farmList[i].y, l) then hasBlock = true break end end
                            end
                            
                            if not hasBlock then
                                local slotIndex = getSlot(string.lower(Core.Toggles.pabrikFarmItem or "auto"))
                                if slotIndex then 
                                    Core.Remotes.PlayerPlaceRemote:FireServer(targetGrid, slotIndex)
                                    placedAny = true; task.wait(0.05) 
                                else
                                    itemHabis = true; break
                                end
                            end
                        end
                        
                        -- TRANSISI FASE
                        if itemHabis then
                            pabrikPhase = "PLANT_SAPLING"
                        elseif not placedAny then
                            pabrikPhase = "FARM_BREAK"
                        end

                    -- ==========================================================
                    -- 2. FASE FARM BREAK
                    -- ==========================================================
                    elseif pabrikPhase == "FARM_BREAK" then
                        if hrp and not hrp.Anchored then hrp.Anchored = true end 
                        local brokeAny = false
                        
                        for i = 1, #farmList do
                            if not Core.Toggles.smartPabrik then break end
                            local targetGrid = Vector2.new(farmList[i].x, farmList[i].y)
                            local hasBlock = false
                            if Core.Managers.WorldManager and Core.Managers.WorldManager.GetTile then
                                for l = 1, 5 do if Core.Managers.WorldManager.GetTile(farmList[i].x, farmList[i].y, l) then hasBlock = true break end end
                            end

                            if hasBlock then
                                for j = 1, 25 do Core.Remotes.PlayerFistRemote:FireServer(targetGrid) end
                                task.wait(delayBreakMs / 1000)
                                brokeAny = true; break 
                            end
                        end

                        if not brokeAny then pabrikPhase = "FARM_LOOT" end

                    -- ==========================================================
                    -- 3. FASE FARM LOOT
                    -- ==========================================================
                    elseif pabrikPhase == "FARM_LOOT" then
                        if hrp and hrp.Anchored then hrp.Anchored = false end 
                        task.wait(0.3) 
                        local drops = workspace:FindFirstChild("Drops") or workspace:FindFirstChild("Items") or workspace:GetChildren()
                        local itemsToLoot = {}
                        for _, v in ipairs(drops) do
                            if (v:IsA("BasePart") or v:IsA("Model")) and not Core.Players:GetPlayerFromCharacter(v.Parent) and (v:IsA("BasePart") and v.Size.Y < 3 or v:IsA("Model")) then 
                                table.insert(itemsToLoot, v) 
                            end
                        end
                        
                        local didLoot = false
                        if #itemsToLoot > 0 then
                            table.sort(itemsToLoot, function(a, b)
                                local pA = a:IsA("BasePart") and a.Position or a.PrimaryPart.Position
                                local pB = b:IsA("BasePart") and b.Position or b.PrimaryPart.Position
                                return pA.X < pB.X
                            end)
                            
                            for _, item in ipairs(itemsToLoot) do
                                if not Core.Toggles.smartPabrik then break end
                                local part = item:IsA("BasePart") and item or item.PrimaryPart
                                if part and part.Parent then
                                    local endX = math.floor(part.Position.X / Core.Utils.TILE_SIZE + 0.5)
                                    local endY = math.floor(part.Position.Y / Core.Utils.TILE_SIZE + 0.5)
                                    local dist = math.sqrt((endX - startPx)^2 + (endY - startPy)^2)
                                    if dist <= 15 and not Core.Pathfinding.isOutOfBounds(endX, endY) and not Core.Pathfinding.isItemTrapped(endX, endY) then
                                        Core.Pathfinding.aiMoveTo(endX, endY, moveSpeed, "smartPabrik"); didLoot = true
                                    end
                                end
                            end
                            if didLoot and Core.Toggles.smartPabrik then
                                Core.Pathfinding.aiMoveTo(startPx, startPy, moveSpeed, "smartPabrik")
                                Core.Managers.MovementState.Position = Core.Toggles.pabrikFarmPos
                            end
                        end
                        pabrikPhase = "FARM_PLACE"

                    -- ==========================================================
                    -- 4. FASE PLANT SAPLING (GLOBAL)
                    -- ==========================================================
                    elseif pabrikPhase == "PLANT_SAPLING" then
                        if hrp and hrp.Anchored then hrp.Anchored = false end
                        local pPos = Core.Managers.MovementState.Position
                        local baseStr = string.lower(Core.Toggles.pabrikBase or "dirt")
                        local slotIndex = getSlot(string.lower(Core.Toggles.pabrikSapling or "auto"))
                        
                        if not slotIndex then 
                            pabrikPhase = "WAIT_GROW" -- Sapling habis, tunggu pohon tumbuh
                        else
                            local validSpots = {}
                            local minB, maxB = workspace:GetAttribute("WorldMin"), workspace:GetAttribute("WorldMax")
                            if minB and maxB and Core.Managers.WorldManager and Core.Managers.WorldManager.GetTile then
                                for x = minB.X, maxB.X do
                                    for y = minB.Y, maxB.Y do
                                        local tileBelow = Core.Managers.WorldManager.GetTile(x, y - 1, 1)
                                        local tileCurrent = Core.Managers.WorldManager.GetTile(x, y, 1)
                                        local isMatch = false
                                        if tileBelow then
                                            local n = Core.Managers.ItemsManager and Core.Managers.ItemsManager.ItemsData[tileBelow] and Core.Managers.ItemsManager.ItemsData[tileBelow].Name or tileBelow
                                            if string.find(string.lower(tostring(n)), baseStr) then isMatch = true end
                                        end
                                        if isMatch and not tileCurrent and not Core.Pathfinding.blacklistedSpots[x..","..y] then table.insert(validSpots, {x=x, y=y}) end
                                    end
                                end
                            end

                            if #validSpots > 0 then
                                local rows = {}; for _, s in ipairs(validSpots) do rows[s.y] = rows[s.y] or {}; table.insert(rows[s.y], s) end
                                local targetY, minYDist = validSpots[1].y, math.huge
                                for y, _ in pairs(rows) do local d = math.abs(pPos.Y - (y * Core.Utils.TILE_SIZE)); if d < minYDist then minYDist = d; targetY = y end end
                                local rowSpots = rows[targetY]; table.sort(rowSpots, function(a, b) return a.x > b.x end)
                                local targetSpot = rowSpots[1]
                                
                                if Core.Pathfinding.aiMoveTo(targetSpot.x, targetSpot.y, moveSpeed, "smartPabrik") then
                                    Core.Remotes.PlayerPlaceRemote:FireServer(Vector2.new(targetSpot.x, targetSpot.y), slotIndex)
                                    task.wait(0.1)
                                else Core.Pathfinding.blacklistedSpots[targetSpot.x..","..targetSpot.y] = true end
                            else
                                pabrikPhase = "WAIT_GROW" -- Tanah penuh, tunggu panen
                            end
                        end

                    -- ==========================================================
                    -- 5. FASE WAIT GROW (MENUNGGU PANEN)
                    -- ==========================================================
                    elseif pabrikPhase == "WAIT_GROW" then
                        if hrp and hrp.Anchored then hrp.Anchored = false end
                        local targetStr = string.lower(Core.Toggles.pabrikTarget or "wood")
                        local foundGrown = false
                        local minB, maxB = workspace:GetAttribute("WorldMin"), workspace:GetAttribute("WorldMax")
                        if minB and maxB and Core.Managers.WorldManager and Core.Managers.WorldManager.GetTile then
                            for x = minB.X, maxB.X do
                                for y = minB.Y, maxB.Y do
                                    local tile = Core.Managers.WorldManager.GetTile(x, y, 1)
                                    if tile then
                                        local n = Core.Managers.ItemsManager and Core.Managers.ItemsManager.ItemsData[tile] and Core.Managers.ItemsManager.ItemsData[tile].Name or tile
                                        if string.find(string.lower(tostring(n)), targetStr) then foundGrown = true; break end
                                    end
                                end
                                if foundGrown then break end
                            end
                        end
                        
                        if foundGrown then 
                            pabrikPhase = "BREAK_TREES" 
                        else 
                            pabrikPhaseDisplay.Text = "Phase: WAITING (GROWING...)"
                            task.wait(1) -- Berdiri santai menunggu pohon tumbuh
                        end

                    -- ==========================================================
                    -- 6. FASE BREAK TREES (GLOBAL)
                    -- ==========================================================
                    elseif pabrikPhase == "BREAK_TREES" then
                        if hrp and hrp.Anchored then hrp.Anchored = false end
                        local pPos = Core.Managers.MovementState.Position
                        local targetStr = string.lower(Core.Toggles.pabrikTarget or "wood")
                        local validSpots = {}
                        local minB, maxB = workspace:GetAttribute("WorldMin"), workspace:GetAttribute("WorldMax")
                        if minB and maxB and Core.Managers.WorldManager and Core.Managers.WorldManager.GetTile then
                            for x = minB.X, maxB.X do
                                for y = minB.Y, maxB.Y do
                                    local tile = Core.Managers.WorldManager.GetTile(x, y, 1)
                                    if tile and not Core.Pathfinding.blacklistedSpots[x..","..y] then
                                        local n = Core.Managers.ItemsManager and Core.Managers.ItemsManager.ItemsData[tile] and Core.Managers.ItemsManager.ItemsData[tile].Name or tile
                                        if string.find(string.lower(tostring(n)), targetStr) then table.insert(validSpots, {x=x, y=y}) end
                                    end
                                end
                            end
                        end

                        if #validSpots > 0 then
                            local rows, sortedY = {}, {}; for _, s in ipairs(validSpots) do if not rows[s.y] then rows[s.y]={}; table.insert(sortedY, s.y) end; table.insert(rows[s.y], s) end
                            table.sort(sortedY, function(a, b) return a < b end)
                            local targetY, minYDist, yIndex = sortedY[1], math.huge, 1
                            for i, y in ipairs(sortedY) do local d = math.abs(pPos.Y - (y * Core.Utils.TILE_SIZE)); if d < minYDist then minYDist = d; targetY = y; yIndex = i end end
                            local rowSpots = rows[targetY]
                            if yIndex % 2 == 0 then table.sort(rowSpots, function(a, b) return a.x < b.x end) else table.sort(rowSpots, function(a, b) return a.x > b.x end) end
                            local targetSpot = rowSpots[1]
                            
                            if Core.Pathfinding.aiMoveTo(targetSpot.x, targetSpot.y, moveSpeed, "smartPabrik") then
                                for i = 1, 25 do Core.Remotes.PlayerFistRemote:FireServer(Vector2.new(targetSpot.x, targetSpot.y)) end
                                task.wait(0.1)
                            else Core.Pathfinding.blacklistedSpots[targetSpot.x..","..targetSpot.y] = true end
                        else
                            pabrikPhase = "LOOT_TREES" -- Semua pohon habis, waktunya ambil drop
                        end

                    -- ==========================================================
                    -- 7. FASE LOOT TREES (GLOBAL)
                    -- ==========================================================
                    elseif pabrikPhase == "LOOT_TREES" then
                        if hrp and hrp.Anchored then hrp.Anchored = false end
                        task.wait(0.3)
                        local drops = workspace:FindFirstChild("Drops") or workspace:FindFirstChild("Items") or workspace:GetChildren()
                        local itemsToLoot = {}
                        for _, v in ipairs(drops) do
                            if (v:IsA("BasePart") or v:IsA("Model")) and not Core.Pathfinding.blacklistedItems[v] and not Core.Players:GetPlayerFromCharacter(v.Parent) and (v:IsA("BasePart") and v.Size.Y < 3 or v:IsA("Model")) then 
                                table.insert(itemsToLoot, v) 
                            end
                        end

                        if #itemsToLoot > 0 then
                            local pPos = Core.Managers.MovementState.Position
                            table.sort(itemsToLoot, function(a, b)
                                local pA = a:IsA("BasePart") and a.Position or a.PrimaryPart.Position
                                local pB = b:IsA("BasePart") and b.Position or b.PrimaryPart.Position
                                return (pPos - pA).Magnitude < (pPos - pB).Magnitude
                            end)
                            
                            for _, item in ipairs(itemsToLoot) do
                                if not Core.Toggles.smartPabrik then break end
                                local part = item:IsA("BasePart") and item or item.PrimaryPart
                                if part and part.Parent then
                                    local endX = math.floor(part.Position.X / Core.Utils.TILE_SIZE + 0.5)
                                    local endY = math.floor(part.Position.Y / Core.Utils.TILE_SIZE + 0.5)
                                    if Core.Pathfinding.isOutOfBounds(endX, endY) or Core.Pathfinding.isItemTrapped(endX, endY) then
                                        Core.Pathfinding.blacklistedItems[item] = true
                                    else
                                        if not Core.Pathfinding.aiMoveTo(endX, endY, moveSpeed, "smartPabrik") then Core.Pathfinding.blacklistedItems[item] = true end
                                    end
                                end
                            end
                        else
                            -- SIKLUS SELESAI! KEMBALI KE POSISI AUTO FARM
                            if Core.Toggles.pabrikFarmPos then
                                local targetX = math.floor(Core.Toggles.pabrikFarmPos.X / Core.Utils.TILE_SIZE + 0.5)
                                local targetY = math.floor(Core.Toggles.pabrikFarmPos.Y / Core.Utils.TILE_SIZE + 0.5)
                                Core.Pathfinding.aiMoveTo(targetX, targetY, moveSpeed, "smartPabrik")
                            end
                            pabrikPhase = "FARM_PLACE"
                        end
                    end
                else
                    pabrikPhase = "FARM_PLACE"
                    local char = Core.LocalPlayer.Character
                    local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
                    if hrp and hrp.Anchored then hrp.Anchored = false end
                end
            end)
        end
    end)
end
