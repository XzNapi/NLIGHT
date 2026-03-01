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
    Core.UI.createInventoryDropdown("3. Target to Panen", "pabrikTarget", secItems)

    local secEngine = Core.UI.createSection(Core.Pages.Pabrik, "3. Engine Control")
    Core.UI.createInputRow("Delay Break (ms)", "250", secEngine, 0.35, "pabrikDelayBox")
    Core.UI.createInputRow("Move Speed", "45", secEngine, 0.35, "pabrikSpeedBox")
    
    local pabrikPhaseDisplay = Core.UI.createLabelDisplay("Phase: IDLE", secEngine)
    local updatePabrikToggle = Core.UI.createToggle("START SMART PABRIK", "smartPabrik", secEngine, false)

    -- ==========================================
    -- SMART PABRIK AI (MASTER STATE MACHINE)
    -- ==========================================
    local pabrikPhase = "FARM_PLACE"
    local needToPlant = false -- Pengingat jika item habis dan harus pindah siklus ke Sapling
    
    -- Fungsi aman untuk mencari Slot Inventory
    local function getSlotSafe(targetItem)
        if not targetItem or targetItem == "" or targetItem == "auto" then
            targetItem = Core.Utils.getHeldItem()
        end
        if type(targetItem) ~= "string" then return nil end -- Mencegah crash jika tangan kosong
        
        targetItem = string.lower(targetItem)
        local exactMatch, partialMatch = nil, nil
        
        if Core.Managers.InventoryModule and Core.Managers.InventoryModule.Stacks then
            for j = 1, (Core.Managers.InventoryModule.MaxSlots or 100) do
                local stackInfo = Core.Managers.InventoryModule.Stacks[j]
                if stackInfo and stackInfo.Id and stackInfo.Amount and stackInfo.Amount > 0 then
                    local currentID = string.lower(tostring(stackInfo.Id))
                    local itemName = currentID
                    if Core.Managers.ItemsManager and Core.Managers.ItemsManager.ItemsData and Core.Managers.ItemsManager.ItemsData[tostring(stackInfo.Id)] then
                        itemName = string.lower(tostring(Core.Managers.ItemsManager.ItemsData[tostring(stackInfo.Id)].Name or currentID))
                    end
                    local baseID = Core.Utils.getBaseId(currentID) 
                    if baseID == targetItem or currentID == targetItem or itemName == targetItem then 
                        exactMatch = j 
                        break 
                    elseif (string.find(currentID, targetItem) or string.find(itemName, targetItem)) and not partialMatch then 
                        partialMatch = j 
                    end
                end
            end
        end
        return exactMatch or partialMatch
    end

    task.spawn(function()
        while task.wait() do
            pcall(function()
                if Core.Toggles.smartPabrik and Core.Managers.MovementState and Core.Remotes.PlayerFistRemote and Core.Remotes.PlayerPlaceRemote then
                    
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

                    -- Susun Grid HANYA di area yang dipilih (Mencegah Lag/Crash)
                    local startPx = math.floor(Core.Toggles.pabrikFarmPos.X / Core.Utils.TILE_SIZE + 0.5)
                    local startPy = math.floor(Core.Toggles.pabrikFarmPos.Y / Core.Utils.TILE_SIZE + 0.5)
                    local farmList = {}
                    for key, isSelected in pairs(Core.Toggles.farmGrids or {}) do
                        if isSelected then
                            local dx, dy = string.match(key, "([%d%-]+),([%d%-]+)")
                            if dx and dy then table.insert(farmList, {x = startPx + tonumber(dx), y = startPy + tonumber(dy), dx = tonumber(dx), dy = tonumber(dy)}) end
                        end
                    end
                    
                    if #farmList > 0 then
                        -- ==========================================================
                        -- 1. FASE FARM PLACE
                        -- ==========================================================
                        if pabrikPhase == "FARM_PLACE" then
                            table.sort(farmList, function(a, b) if a.dy == b.dy then return a.dx > b.dx end; return a.dy > b.dy end)
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
                                    local slotIndex = getSlotSafe(Core.Toggles.pabrikFarmItem)
                                    if slotIndex then 
                                        Core.Remotes.PlayerPlaceRemote:FireServer(targetGrid, slotIndex)
                                        placedAny = true
                                        task.wait(0.05) 
                                    else
                                        itemHabis = true
                                        break
                                    end
                                end
                            end
                            
                            -- TRANSISI: Selesaikan siklus Break & Loot dulu meskipun item habis, agar tidak rugi
                            if itemHabis then
                                needToPlant = true
                                pabrikPhase = "FARM_BREAK"
                            elseif not placedAny then
                                pabrikPhase = "FARM_BREAK"
                            end

                        -- ==========================================================
                        -- 2. FASE FARM BREAK
                        -- ==========================================================
                        elseif pabrikPhase == "FARM_BREAK" then
                            table.sort(farmList, function(a, b) if a.dy == b.dy then return a.dx > b.dx end; return a.dy > b.dy end)
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
                                    brokeAny = true
                                    break -- Fokus hancurkan satu-satu
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
                                            Core.Pathfinding.aiMoveTo(endX, endY, moveSpeed, "smartPabrik")
                                            didLoot = true
                                        end
                                    end
                                end
                                
                                if didLoot and Core.Toggles.smartPabrik then
                                    Core.Pathfinding.aiMoveTo(startPx, startPy, moveSpeed, "smartPabrik")
                                    Core.Managers.MovementState.Position = Core.Toggles.pabrikFarmPos
                                end
                            end
                            
                            -- KEPUTUSAN SIKLUS: Jika item tadi habis, masuk ke Sapling, jika tidak ulang Farm!
                            if needToPlant then
                                pabrikPhase = "PLANT_SAPLING"
                            else
                                pabrikPhase = "FARM_PLACE"
                            end

                        -- ==========================================================
                        -- 4. FASE PLANT SAPLING (OTOMATIS SAAT ITEM HABIS)
                        -- ==========================================================
                        elseif pabrikPhase == "PLANT_SAPLING" then
                            table.sort(farmList, function(a, b) if a.dy == b.dy then return a.dx > b.dx end; return a.dy > b.dy end)
                            if hrp and not hrp.Anchored then hrp.Anchored = true end -- Diam di tengah posisi farm
                            
                            local plantedAny = false
                            local saplingHabis = false

                            for i = 1, #farmList do
                                if not Core.Toggles.smartPabrik then break end
                                local targetGrid = Vector2.new(farmList[i].x, farmList[i].y)
                                local hasBlock = false
                                if Core.Managers.WorldManager and Core.Managers.WorldManager.GetTile then
                                    for l = 1, 5 do if Core.Managers.WorldManager.GetTile(farmList[i].x, farmList[i].y, l) then hasBlock = true break end end
                                end
                                
                                if not hasBlock then
                                    local slotIndex = getSlotSafe(Core.Toggles.pabrikSapling)
                                    if slotIndex then
                                        Core.Remotes.PlayerPlaceRemote:FireServer(targetGrid, slotIndex)
                                        plantedAny = true
                                        task.wait(0.05)
                                    else
                                        saplingHabis = true
                                        break
                                    end
                                end
                            end

                            if saplingHabis or not plantedAny then
                                pabrikPhase = "WAIT_GROW"
                            end

                        -- ==========================================================
                        -- 5. FASE WAIT GROW (MENUNGGU PANEN)
                        -- ==========================================================
                        elseif pabrikPhase == "WAIT_GROW" then
                            if hrp and hrp.Anchored then hrp.Anchored = false end
                            local targetStr = string.lower(Core.Toggles.pabrikTarget or "wood")
                            local foundGrown = false
                            
                            -- HANYA MENCARI POHON TUMBUH DI DALAM GRID KITA SENDIRI
                            for i = 1, #farmList do
                                local tile = Core.Managers.WorldManager and Core.Managers.WorldManager.GetTile(farmList[i].x, farmList[i].y, 1)
                                if tile then
                                    local n = Core.Managers.ItemsManager and Core.Managers.ItemsManager.ItemsData[tile] and Core.Managers.ItemsManager.ItemsData[tile].Name or tostring(tile)
                                    if string.find(string.lower(n), targetStr) then 
                                        foundGrown = true
                                        break 
                                    end
                                end
                            end
                            
                            if foundGrown then 
                                pabrikPhase = "BREAK_TREES" 
                            else 
                                pabrikPhaseDisplay.Text = "Phase: WAITING (GROWING...)"
                                task.wait(1) -- Berdiri santai
                            end

                        -- ==========================================================
                        -- 6. FASE BREAK TREES
                        -- ==========================================================
                        elseif pabrikPhase == "BREAK_TREES" then
                            table.sort(farmList, function(a, b) if a.dy == b.dy then return a.dx > b.dx end; return a.dy > b.dy end)
                            if hrp and not hrp.Anchored then hrp.Anchored = true end 
                            
                            local targetStr = string.lower(Core.Toggles.pabrikTarget or "wood")
                            local brokeAny = false
                            
                            for i = 1, #farmList do
                                if not Core.Toggles.smartPabrik then break end
                                local tile = Core.Managers.WorldManager and Core.Managers.WorldManager.GetTile(farmList[i].x, farmList[i].y, 1)
                                
                                if tile then
                                    local n = Core.Managers.ItemsManager and Core.Managers.ItemsManager.ItemsData[tile] and Core.Managers.ItemsManager.ItemsData[tile].Name or tostring(tile)
                                    if string.find(string.lower(n), targetStr) then 
                                        local targetGrid = Vector2.new(farmList[i].x, farmList[i].y)
                                        for j = 1, 25 do Core.Remotes.PlayerFistRemote:FireServer(targetGrid) end
                                        task.wait(delayBreakMs / 1000)
                                        brokeAny = true
                                        break -- Fokus hancurkan satu per satu dari kanan ke kiri
                                    end
                                end
                            end

                            if not brokeAny then
                                pabrikPhase = "LOOT_TREES"
                            end

                        -- ==========================================================
                        -- 7. FASE LOOT TREES
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
                                            Core.Pathfinding.aiMoveTo(endX, endY, moveSpeed, "smartPabrik")
                                            didLoot = true
                                        end
                                    end
                                end
                            end
                            
                            if didLoot and Core.Toggles.smartPabrik then
                                Core.Pathfinding.aiMoveTo(startPx, startPy, moveSpeed, "smartPabrik")
                                Core.Managers.MovementState.Position = Core.Toggles.pabrikFarmPos
                            end
                            
                            -- SIKLUS FULL SELESAI! RESET DAN KEMBALI KE AUTO FARM!
                            needToPlant = false
                            pabrikPhase = "FARM_PLACE"
                        end
                    else
                        Core.Toggles.smartPabrik = false
                        if updatePabrikToggle then updatePabrikToggle() end
                        print("[NLight Pabrik] Harap pilih minimal satu Grid melalui tombol 'Select Grid Farm'!")
                        task.wait(1)
                    end
                else
                    -- KETIKA TOGGLE DIMATIKAN: Reset AI
                    pabrikPhase = "FARM_PLACE"
                    needToPlant = false
                    local char = Core.LocalPlayer.Character
                    local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
                    if hrp and hrp.Anchored then hrp.Anchored = false end
                end
            end)
        end
    end)
end
