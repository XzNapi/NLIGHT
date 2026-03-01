return function(Core)
    -- ==========================================
    -- 1. INDEPENDENT GRID UI (KHUSUS PABRIK)
    -- ==========================================
    local pabrikGrids = {} -- Variabel Grid khusus Pabrik
    
    local pabrikPopupOverlay = Instance.new("Frame", Core.UI.popupOverlay.Parent)
    pabrikPopupOverlay.Size = UDim2.new(1, 0, 1, 0); pabrikPopupOverlay.BackgroundColor3 = Color3.new(0, 0, 0); pabrikPopupOverlay.BackgroundTransparency = 0.5; pabrikPopupOverlay.Visible = false; pabrikPopupOverlay.Active = true; pabrikPopupOverlay.ZIndex = 100

    local gridPopup = Instance.new("Frame", pabrikPopupOverlay)
    gridPopup.Size = UDim2.new(0, 320, 0, 420); gridPopup.Position = UDim2.new(0.5, -160, 0.5, -210); gridPopup.BackgroundColor3 = Color3.fromRGB(13, 13, 17); gridPopup.ZIndex = 101; Instance.new("UICorner", gridPopup).CornerRadius = UDim.new(0, 12); Instance.new("UIStroke", gridPopup).Color = Color3.fromRGB(45, 45, 55)

    local gridHeader = Instance.new("Frame", gridPopup)
    gridHeader.Size = UDim2.new(1, 0, 0, 50); gridHeader.BackgroundTransparency = 1; gridHeader.ZIndex = 102
    local gridTitleLbl = Instance.new("TextLabel", gridHeader)
    gridTitleLbl.Size = UDim2.new(1, -60, 1, 0); gridTitleLbl.Position = UDim2.new(0, 20, 0, 0); gridTitleLbl.BackgroundTransparency = 1; gridTitleLbl.Text = "PABRIK GRID (8x8)"; gridTitleLbl.Font = Enum.Font.GothamBold; gridTitleLbl.TextSize = 16; gridTitleLbl.TextColor3 = Color3.fromRGB(250, 250, 255); gridTitleLbl.ZIndex = 102; gridTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
    local gridCloseBtn = Instance.new("TextButton", gridHeader)
    gridCloseBtn.Size = UDim2.new(0, 50, 0, 50); gridCloseBtn.Position = UDim2.new(1, -50, 0, 0); gridCloseBtn.BackgroundTransparency = 1; gridCloseBtn.Text = "✕"; gridCloseBtn.Font = Enum.Font.GothamBold; gridCloseBtn.TextSize = 14; gridCloseBtn.TextColor3 = Color3.fromRGB(150, 150, 160); gridCloseBtn.ZIndex = 102; gridCloseBtn.MouseButton1Click:Connect(function() pabrikPopupOverlay.Visible = false end)

    local gridContainer = Instance.new("Frame", gridPopup)
    gridContainer.Size = UDim2.new(0, 284, 0, 284); gridContainer.Position = UDim2.new(0.5, -142, 0, 55); gridContainer.BackgroundTransparency = 1; gridContainer.ZIndex = 102
    local uigrid = Instance.new("UIGridLayout", gridContainer)
    uigrid.CellSize = UDim2.new(0, 32, 0, 32); uigrid.CellPadding = UDim2.new(0, 4, 0, 4); uigrid.SortOrder = Enum.SortOrder.LayoutOrder

    for i = 1, 64 do
        local dx = (i - 1) % 8 - 3
        local row = math.floor((i - 1) / 8)
        local dy = 3 - row 
        local key = tostring(dx) .. "," .. tostring(dy)
        
        local btn = Instance.new("TextButton", gridContainer)
        btn.Text = ""; btn.BackgroundColor3 = pabrikGrids[key] and Color3.fromRGB(245, 158, 11) or Color3.fromRGB(30, 30, 38); btn.ZIndex = 103; Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        
        if dx == 0 and dy == 0 then
            local userPenanda = Instance.new("Frame", btn)
            userPenanda.Size = UDim2.new(0, 28, 0, 28); userPenanda.Position = UDim2.new(0.5, 0, 0.5, 0); userPenanda.AnchorPoint = Vector2.new(0.5, 0.5); userPenanda.BackgroundColor3 = Color3.fromRGB(245, 158, 11); userPenanda.BackgroundTransparency = 0.5; userPenanda.ZIndex = 104; Instance.new("UICorner", userPenanda).CornerRadius = UDim.new(1, 0)
            local lbl = Instance.new("TextLabel", userPenanda); lbl.Size = UDim2.new(1, 0, 0, 10); lbl.Position = UDim2.new(0.5, 0, 0.5, 0); lbl.AnchorPoint = Vector2.new(0.5, 0.5); lbl.BackgroundTransparency = 1; lbl.Text = "ME"; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 10; lbl.TextColor3 = Color3.fromRGB(255, 255, 255); lbl.ZIndex = 105
        end
        btn.MouseButton1Click:Connect(function() pabrikGrids[key] = not pabrikGrids[key]; Core.TS:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = pabrikGrids[key] and Color3.fromRGB(245, 158, 11) or Color3.fromRGB(30, 30, 38)}):Play() end)
    end

    local saveGridBtn = Instance.new("TextButton", gridPopup)
    saveGridBtn.Size = UDim2.new(0, 200, 0, 40); saveGridBtn.Position = UDim2.new(0.5, -100, 1, -55); saveGridBtn.BackgroundColor3 = Color3.fromRGB(34, 197, 94); saveGridBtn.Text = "Done"; saveGridBtn.Font = Enum.Font.GothamBold; saveGridBtn.TextSize = 16; saveGridBtn.TextColor3 = Color3.fromRGB(13, 13, 17); saveGridBtn.ZIndex = 102; saveGridBtn.AutoButtonColor = false; Instance.new("UICorner", saveGridBtn).CornerRadius = UDim.new(0, 8)
    saveGridBtn.MouseButton1Click:Connect(function() pabrikPopupOverlay.Visible = false end)

    -- ==========================================
    -- 2. UI SETUP: TAB PABRIK
    -- ==========================================
    local secSetup = Core.UI.createSection(Core.Pages.Pabrik, "1. Pabrik Position & Grid")
    local savedPosDisplay = Core.UI.createLabelDisplay("Status: POSISI BELUM DI-SAVE!", secSetup)
    local pabrikFarmPos = nil -- Posisi Khusus Pabrik
    
    Core.UI.createButton("Save Current Position", secSetup, function()
        if Core.Managers.MovementState then
            pabrikFarmPos = Core.Managers.MovementState.Position
            local px = math.floor(pabrikFarmPos.X / Core.Utils.TILE_SIZE + 0.5)
            local py = math.floor(pabrikFarmPos.Y / Core.Utils.TILE_SIZE + 0.5)
            savedPosDisplay.Text = string.format("Saved Pos: X: %d, Y: %d", px, py)
        end
    end)
    Core.UI.createButton("Select Grid Pabrik", secSetup, function() pabrikPopupOverlay.Visible = true end)

    local secItems = Core.UI.createSection(Core.Pages.Pabrik, "2. Pabrik Item Configuration")
    Core.UI.createInventoryDropdown("1. Farm Item (Place)", "pabrikFarmItem", secItems)
    Core.UI.createInventoryDropdown("2. Sapling / Seed", "pabrikSapling", secItems)
    Core.UI.createInventoryDropdown("3. Base Block (Soil)", "pabrikBase", secItems)
    Core.UI.createInventoryDropdown("4. Target to Panen", "pabrikTarget", secItems)

    local secEngine = Core.UI.createSection(Core.Pages.Pabrik, "3. Pabrik Engine Control")
    Core.UI.createInputRow("Delay Break (ms)", "250", secEngine, 0.35, "pabrikDelayBox")
    Core.UI.createInputRow("Move Speed", "45", secEngine, 0.35, "pabrikSpeedBox")
    
    local pabrikPhaseDisplay = Core.UI.createLabelDisplay("Phase: IDLE", secEngine)
    local updatePabrikToggle = Core.UI.createToggle("START SMART PABRIK", "smartPabrik", secEngine, false)

    -- ==========================================
    -- 3. SMART PABRIK AI (INDEPENDENT ENGINE)
    -- ==========================================
    -- Utility Independen untuk Mencari Slot Item
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

    -- Otak AI Utama
    task.spawn(function()
        while task.wait(0.1) do
            pcall(function()
                if Core.Toggles.smartPabrik and Core.Managers.MovementState and Core.Remotes.PlayerFistRemote and Core.Remotes.PlayerPlaceRemote then
                    
                    -- Pengecekan Posisi
                    if not pabrikFarmPos then
                        Core.Toggles.smartPabrik = false
                        if updatePabrikToggle then updatePabrikToggle() end
                        print("[NLight Pabrik] GAGAL: Harap 'Save Current Position' terlebih dahulu!")
                        return
                    end

                    local char = Core.LocalPlayer.Character
                    local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
                    local moveSpeed = tonumber(Core.Inputs["pabrikSpeedBox"] and Core.Inputs["pabrikSpeedBox"].Text) or 45
                    local delayBreakMs = tonumber(Core.Inputs["pabrikDelayBox"] and Core.Inputs["pabrikDelayBox"].Text) or 250
                    
                    local startPx = math.floor(pabrikFarmPos.X / Core.Utils.TILE_SIZE + 0.5)
                    local startPy = math.floor(pabrikFarmPos.Y / Core.Utils.TILE_SIZE + 0.5)
                    
                    -- Susun & Urutkan Target Grid (Kanan ke Kiri / X Terbesar ke X Terkecil)
                    local targetList = {}
                    for key, isSelected in pairs(pabrikGrids) do
                        if isSelected then
                            local dx, dy = string.match(key, "([%d%-]+),([%d%-]+)")
                            if dx and dy then table.insert(targetList, {x = startPx + tonumber(dx), y = startPy + tonumber(dy), dx = tonumber(dx), dy = tonumber(dy)}) end
                        end
                    end
                    table.sort(targetList, function(a, b) if a.dy == b.dy then return a.dx > b.dx end; return a.dy > b.dy end)

                    -- ==========================================================
                    -- SIKLUS 1: FARM PLACE -> BREAK -> LOOT
                    -- ==========================================================
                    pabrikPhaseDisplay.Text = "Phase: FARM PLACE"
                    if hrp and not hrp.Anchored then hrp.Anchored = true end 

                    local isOutOfFarmItem = false
                    
                    -- 1A. PLACE ITEM (Mengalir)
                    for _, tGrid in ipairs(targetList) do
                        if not Core.Toggles.smartPabrik then break end 
                        local gridPos = Vector2.new(tGrid.x, tGrid.y)
                        local hasBlock = false
                        
                        if Core.Managers.WorldManager and Core.Managers.WorldManager.GetTile then
                            for l = 1, 5 do if Core.Managers.WorldManager.GetTile(tGrid.x, tGrid.y, l) then hasBlock = true break end end
                        end
                        
                        if not hasBlock then
                            local slotIndex = getSlot(string.lower(Core.Toggles.pabrikFarmItem or "auto"))
                            if slotIndex then 
                                Core.Remotes.PlayerPlaceRemote:FireServer(gridPos, slotIndex)
                                task.wait(0.05) 
                            else
                                isOutOfFarmItem = true
                                break -- Berhenti place jika item habis
                            end
                        end
                    end

                    if not Core.Toggles.smartPabrik then return end

                    -- 1B. BREAK ITEM (Satu Per Satu, dari Kanan ke Kiri)
                    pabrikPhaseDisplay.Text = "Phase: FARM BREAK"
                    for _, tGrid in ipairs(targetList) do
                        if not Core.Toggles.smartPabrik then break end
                        local gridPos = Vector2.new(tGrid.x, tGrid.y)
                        local hasBlock = false
                        
                        if Core.Managers.WorldManager and Core.Managers.WorldManager.GetTile then
                            for l = 1, 5 do if Core.Managers.WorldManager.GetTile(tGrid.x, tGrid.y, l) then hasBlock = true break end end
                        end

                        if hasBlock then
                            for j = 1, 25 do Core.Remotes.PlayerFistRemote:FireServer(gridPos) end
                            task.wait(delayBreakMs / 1000) -- Menunggu blok hancur sebelum lanjut ke blok sebelahnya
                        end
                    end

                    if not Core.Toggles.smartPabrik then return end

                    -- 1C. LOOT DROPS (Ambil drop di sekitar grid)
                    pabrikPhaseDisplay.Text = "Phase: FARM LOOT"
                    if hrp and hrp.Anchored then hrp.Anchored = false end 
                    task.wait(0.3) 
                    
                    local drops = workspace:FindFirstChild("Drops") or workspace:FindFirstChild("DroppedItems") or workspace:FindFirstChild("Items")
                    local itemsToLoot = {}
                    if drops then
                        for _, v in ipairs(drops:GetChildren()) do if (v:IsA("BasePart") or v:IsA("Model")) and not Core.Pathfinding.blacklistedItems[v] then table.insert(itemsToLoot, v) end end
                    else
                        for _, obj in ipairs(workspace:GetChildren()) do if obj:IsA("BasePart") and not obj:IsDescendantOf(char) and not Core.Players:GetPlayerFromCharacter(obj.Parent) and obj.Size.Y < 3 and not Core.Pathfinding.blacklistedItems[obj] then table.insert(itemsToLoot, obj) end end
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
                            Core.Managers.MovementState.Position = pabrikFarmPos
                        end
                    end

                    if not Core.Toggles.smartPabrik then return end

                    -- ==========================================================
                    -- SIKLUS 2: MODE PABRIK (JIKA FARM ITEM HABIS)
                    -- ==========================================================
                    if isOutOfFarmItem then
                        pabrikPhaseDisplay.Text = "Phase: PLANT SAPLING (GLOBAL)"
                        print("[NLight Pabrik] Farm Item Habis! Memulai mode Panen Global...")
                        
                        -- 2A. PLANT SAPLING
                        local baseStr = string.lower(Core.Toggles.pabrikBase or "dirt")
                        
                        while Core.Toggles.smartPabrik do
                            local slotIndex = getSlot(string.lower(Core.Toggles.pabrikSapling or "auto"))
                            if not slotIndex then break end -- Jika sapling habis, berhenti menanam
                            
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
                                local pPos = Core.Managers.MovementState.Position
                                for y, _ in pairs(rows) do local d = math.abs(pPos.Y - (y * Core.Utils.TILE_SIZE)); if d < minYDist then minYDist = d; targetY = y end end
                                local rowSpots = rows[targetY]; table.sort(rowSpots, function(a, b) return a.x > b.x end)
                                local targetSpot = rowSpots[1]
                                
                                if Core.Pathfinding.aiMoveTo(targetSpot.x, targetSpot.y, moveSpeed, "smartPabrik") then
                                    Core.Remotes.PlayerPlaceRemote:FireServer(Vector2.new(targetSpot.x, targetSpot.y), slotIndex)
                                    task.wait(0.1)
                                else Core.Pathfinding.blacklistedSpots[targetSpot.x..","..targetSpot.y] = true end
                            else
                                break -- Tanah penuh
                            end
                        end

                        if not Core.Toggles.smartPabrik then return end

                        -- 2B. WAIT GROW
                        pabrikPhaseDisplay.Text = "Phase: WAITING (GROWING...)"
                        local targetStr = string.lower(Core.Toggles.pabrikTarget or "wood")
                        
                        while Core.Toggles.smartPabrik do
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
                            
                            if foundGrown then break end -- Jika sudah ada yang tumbuh, lanjut Break
                            task.wait(1)
                        end

                        if not Core.Toggles.smartPabrik then return end

                        -- 2C. BREAK TREES (GLOBAL)
                        pabrikPhaseDisplay.Text = "Phase: BREAK TREES (GLOBAL)"
                        while Core.Toggles.smartPabrik do
                            local pPos = Core.Managers.MovementState.Position
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
                                break -- Pohon habis, lanjut ke Loot
                            end
                        end

                        if not Core.Toggles.smartPabrik then return end

                        -- 2D. LOOT TREES (GLOBAL)
                        pabrikPhaseDisplay.Text = "Phase: LOOT TREES (GLOBAL)"
                        task.wait(0.3)
                        
                        while Core.Toggles.smartPabrik do
                            local dps = workspace:FindFirstChild("Drops") or workspace:FindFirstChild("DroppedItems") or workspace:FindFirstChild("Items")
                            local iLoot = {}
                            if dps then
                                for _, v in ipairs(dps:GetChildren()) do if (v:IsA("BasePart") or v:IsA("Model")) and not Core.Pathfinding.blacklistedItems[v] then table.insert(iLoot, v) end end
                            else
                                for _, obj in ipairs(workspace:GetChildren()) do if obj:IsA("BasePart") and not obj:IsDescendantOf(char) and not Core.Players:GetPlayerFromCharacter(obj.Parent) and obj.Size.Y < 3 and not Core.Pathfinding.blacklistedItems[obj] then table.insert(iLoot, obj) end end
                            end

                            if #iLoot > 0 then
                                local pPos = Core.Managers.MovementState.Position
                                table.sort(iLoot, function(a, b)
                                    local pA = a:IsA("BasePart") and a.Position or a.PrimaryPart.Position
                                    local pB = b:IsA("BasePart") and b.Position or b.PrimaryPart.Position
                                    return (pPos - pA).Magnitude < (pPos - pB).Magnitude
                                end)
                                
                                local didLootGlobal = false
                                for _, item in ipairs(iLoot) do
                                    if not Core.Toggles.smartPabrik then break end
                                    local part = item:IsA("BasePart") and item or item.PrimaryPart
                                    if part and part.Parent then
                                        local endX = math.floor(part.Position.X / Core.Utils.TILE_SIZE + 0.5)
                                        local endY = math.floor(part.Position.Y / Core.Utils.TILE_SIZE + 0.5)
                                        if Core.Pathfinding.isOutOfBounds(endX, endY) or Core.Pathfinding.isItemTrapped(endX, endY) then
                                            Core.Pathfinding.blacklistedItems[item] = true
                                        else
                                            if not Core.Pathfinding.aiMoveTo(endX, endY, moveSpeed, "smartPabrik") then Core.Pathfinding.blacklistedItems[item] = true else didLootGlobal = true; break end -- Loot 1 per 1 agar scanning tetap fresh
                                        end
                                    end
                                end
                                if not didLootGlobal then break end
                            else
                                break -- Loot habis
                            end
                        end

                        if not Core.Toggles.smartPabrik then return end

                        -- 2E. KEMBALI KE POSISI AWAL (RESTART LOOP)
                        pabrikPhaseDisplay.Text = "Phase: RETURNING TO BASE"
                        Core.Pathfinding.aiMoveTo(startPx, startPy, moveSpeed, "smartPabrik")
                        Core.Managers.MovementState.Position = pabrikFarmPos
                    end
                else
                    pabrikPhaseDisplay.Text = "Phase: IDLE"
                    local char = Core.LocalPlayer.Character
                    local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
                    if hrp and hrp.Anchored then hrp.Anchored = false end
                end
            end)
        end
    end)
end
