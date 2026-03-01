return function(Core)
    -- ==========================================
    -- UI SETUP: SMART PABRIK
    -- ==========================================
    local secSetup = Core.UI.createSection(Core.Pages.Pabrik, "1. Set Coordinates")

    -- 1. SET POSISI KARAKTER
    local charPosLabel = Core.UI.createLabelDisplay("Char Pos: BELUM DI-SAVE!", secSetup)
    Core.UI.createButton("Save Character Position", secSetup, function()
        if Core.Managers.MovementState then
            Core.Toggles.pabrikCharPos = Core.Managers.MovementState.Position
            local px = math.floor(Core.Toggles.pabrikCharPos.X / Core.Utils.TILE_SIZE + 0.5)
            local py = math.floor(Core.Toggles.pabrikCharPos.Y / Core.Utils.TILE_SIZE + 0.5)
            charPosLabel.Text = string.format("Char Pos: X: %d, Y: %d", px, py)
        end
    end)

    -- 2. SET TARGET ITEM / GRID
    local targetLabel = Core.UI.createLabelDisplay("Targets: 0 Area Disimpan", secSetup)
    Core.Toggles.pabrikTargets = Core.Toggles.pabrikTargets or {}
    
    local isRecording = false
    local recordBtn
    recordBtn = Core.UI.createButton("Set Target (Click/Punch Area)", secSetup, function()
        isRecording = not isRecording
        if isRecording then
            recordBtn.Text = "Stop Setting & Save Targets"
            -- Ubah warna jadi merah saat recording
            Core.TS:Create(recordBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(239, 68, 68)}):Play()
        else
            recordBtn.Text = "Set Target (Click/Punch Area)"
            -- Kembalikan warna
            Core.TS:Create(recordBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(30, 30, 38)}):Play()
        end
    end)

    Core.UI.createButton("Clear All Targets", secSetup, function()
        Core.Toggles.pabrikTargets = {}
        targetLabel.Text = "Targets: 0 Area Disimpan"
    end)

    -- Event listener untuk merekam klik/punch pemain ke layar saat "isRecording" nyala
    Core.UIS.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if not isRecording then return end
        
        local isTouchOrClick = (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
        if isTouchOrClick then
            local targetGrid = Core.Utils.getGridFromScreen(input.Position.X, input.Position.Y)
            if targetGrid then
                -- Cek apakah grid tersebut sudah ada di daftar agar tidak duplikat
                local exists = false
                for _, v in ipairs(Core.Toggles.pabrikTargets) do
                    if v.x == targetGrid.X and v.y == targetGrid.Y then exists = true; break end
                end
                
                if not exists then
                    table.insert(Core.Toggles.pabrikTargets, {x = targetGrid.X, y = targetGrid.Y})
                    targetLabel.Text = "Targets: " .. #Core.Toggles.pabrikTargets .. " Area Disimpan"
                end
            end
        end
    end)

    -- 3. MESIN SMART PABRIK
    local secEngine = Core.UI.createSection(Core.Pages.Pabrik, "2. Smart Auto Pabrik")
    Core.UI.createInventoryDropdown("Item to Place", "pabrikPlaceItem", secEngine)
    Core.UI.createInputRow("Delay Break (ms)", "250", secEngine, 0.35, "pabrikDelayBox")
    local updatePabrikToggle = Core.UI.createToggle("Enable Smart Auto Pabrik", "smartPabrik", secEngine, false)

    -- ==========================================
    -- SMART PABRIK AI (MASTER STATE MACHINE)
    -- ==========================================
    local pabrikPhase = "PLACE"
    local isOutOfItems = false

    task.spawn(function()
        while task.wait() do
            pcall(function()
                if Core.Toggles.smartPabrik and Core.Managers.MovementState and Core.Remotes.PlayerFistRemote and Core.Remotes.PlayerPlaceRemote then
                    
                    -- Proteksi: Cek apakah Posisi dan Target sudah diset
                    if not Core.Toggles.pabrikCharPos or #Core.Toggles.pabrikTargets == 0 then
                        Core.Toggles.smartPabrik = false
                        if updatePabrikToggle then updatePabrikToggle() end
                        print("[NLight Pabrik] GAGAL: Set Posisi Karakter & Target Area terlebih dahulu!")
                        task.wait(1)
                        return
                    end

                    local char = Core.LocalPlayer.Character
                    local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
                    if hrp and not hrp.Anchored then hrp.Anchored = true end 

                    -- Copy Target List untuk diurutkan
                    local tList = {}
                    for _, v in ipairs(Core.Toggles.pabrikTargets) do table.insert(tList, v) end
                    
                    -- Urutkan Target: Kanan ke Kiri (X Terbesar ke Terkecil)
                    table.sort(tList, function(a, b)
                        if a.y == b.y then return a.x > b.x end
                        return a.y > b.y 
                    end)

                    -- ==========================================================
                    -- FASE 1: PLACE ITEM (DARI KANAN KE KIRI)
                    -- ==========================================================
                    if pabrikPhase == "PLACE" then
                        local itemHabis = false
                        local placedAny = false

                        for i = 1, #tList do
                            if not Core.Toggles.smartPabrik then break end 
                            local targetGrid = Vector2.new(tList[i].x, tList[i].y)
                            local hasBlock = false
                            
                            if Core.Managers.WorldManager and Core.Managers.WorldManager.GetTile then
                                for l = 1, 5 do if Core.Managers.WorldManager.GetTile(targetGrid.X, targetGrid.Y, l) then hasBlock = true break end end
                            end
                            
                            if not hasBlock then
                                local targetStringID = string.lower(Core.Toggles.pabrikPlaceItem or "auto")
                                if targetStringID == "auto" or targetStringID == "" then targetStringID = Core.Utils.getHeldItem() or "auto" end
                                
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
                                
                                if slotIndexToSend then 
                                    Core.Remotes.PlayerPlaceRemote:FireServer(targetGrid, slotIndexToSend)
                                    placedAny = true
                                    task.wait(0.05) 
                                else
                                    itemHabis = true; break
                                end
                            end
                        end
                        
                        if itemHabis then
                            print("[NLight Pabrik] Item habis! Masuk ke fase panen terakhir...")
                            isOutOfItems = true
                            pabrikPhase = "BREAK"
                        elseif not placedAny then
                            pabrikPhase = "BREAK"
                        end

                    -- ==========================================================
                    -- FASE 2: BREAK ITEM (DARI KANAN KE KIRI - SATU PER SATU)
                    -- ==========================================================
                    elseif pabrikPhase == "BREAK" then
                        local delayBreakMs = tonumber(Core.Inputs["pabrikDelayBox"] and Core.Inputs["pabrikDelayBox"].Text) or 250
                        local brokeAny = false
                        
                        for i = 1, #tList do
                            if not Core.Toggles.smartPabrik then break end
                            local targetGrid = Vector2.new(tList[i].x, tList[i].y)
                            local hasBlock = false
                            
                            if Core.Managers.WorldManager and Core.Managers.WorldManager.GetTile then
                                for l = 1, 5 do if Core.Managers.WorldManager.GetTile(targetGrid.X, targetGrid.Y, l) then hasBlock = true break end end
                            end

                            if hasBlock then
                                local hitsToSend = 25 
                                for j = 1, hitsToSend do Core.Remotes.PlayerFistRemote:FireServer(targetGrid) end
                                task.wait(delayBreakMs / 1000)
                                brokeAny = true; break 
                            end
                        end

                        if not brokeAny then pabrikPhase = "LOOT" end

                    -- ==========================================================
                    -- FASE 3: LOOT ITEM (DARI KIRI KE KANAN)
                    -- ==========================================================
                    elseif pabrikPhase == "LOOT" then
                        task.wait(0.3) 

                        local dropsFolder = workspace:FindFirstChild("Drops") or workspace:FindFirstChild("DroppedItems") or workspace:FindFirstChild("Items")
                        local itemsToLoot = {}
                        if dropsFolder then
                            for _, v in ipairs(dropsFolder:GetChildren()) do if v:IsA("BasePart") or v:IsA("Model") then table.insert(itemsToLoot, v) end end
                        else
                            for _, obj in ipairs(workspace:GetChildren()) do
                                if obj:IsA("BasePart") and not obj:IsDescendantOf(char) and not Core.Players:GetPlayerFromCharacter(obj.Parent) and obj.Size.Y < 3 then table.insert(itemsToLoot, obj) end
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
                            local charX = math.floor(Core.Toggles.pabrikCharPos.X / Core.Utils.TILE_SIZE + 0.5)
                            local charY = math.floor(Core.Toggles.pabrikCharPos.Y / Core.Utils.TILE_SIZE + 0.5)

                            for _, item in ipairs(itemsToLoot) do
                                if not Core.Toggles.smartPabrik then break end
                                local part = item:IsA("BasePart") and item or (item:IsA("Model") and item.PrimaryPart)
                                if part and part.Parent then
                                    local endX = math.floor(part.Position.X / Core.Utils.TILE_SIZE + 0.5)
                                    local endY = math.floor(part.Position.Y / Core.Utils.TILE_SIZE + 0.5)
                                    local distFromStart = math.sqrt((endX - charX)^2 + (endY - charY)^2)
                                    
                                    if distFromStart <= 20 and not Core.Pathfinding.isOutOfBounds(endX, endY) and not Core.Pathfinding.isItemTrapped(endX, endY) then
                                        Core.Pathfinding.aiMoveTo(endX, endY, moveSpeed, "smartPabrik")
                                        didLoot = true
                                    end
                                end
                            end
                            
                            if didLoot and Core.Toggles.smartPabrik then
                                -- KEMBALI KE POSISI KARAKTER YANG DISAVE
                                Core.Pathfinding.aiMoveTo(charX, charY, moveSpeed, "smartPabrik")
                                Core.Managers.MovementState.Position = Core.Toggles.pabrikCharPos
                                Core.Managers.MovementState.OldPosition = Core.Toggles.pabrikCharPos
                            end
                        end
                        
                        if isOutOfItems then
                            print("[NLight Pabrik] Siklus terakhir selesai. Bot dimatikan.")
                            Core.Toggles.smartPabrik = false
                            if updatePabrikToggle then updatePabrikToggle() end
                            pabrikPhase = "PLACE"
                            isOutOfItems = false
                            if hrp and hrp.Anchored then hrp.Anchored = false end
                        else
                            pabrikPhase = "PLACE"
                        end
                    end
                else
                    pabrikPhase = "PLACE"
                    isOutOfItems = false
                    local char = Core.LocalPlayer.Character
                    local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
                    if hrp and hrp.Anchored then hrp.Anchored = false end
                end
            end)
        end
    end)
end
