return function(Core)
    -- UI
    local secInfo = Core.UI.createSection(Core.Pages.Move, "Live Status")
    local posDisplay = Core.UI.createLabelDisplay("Current Grid: X: 0, Y: 0", secInfo)

    local secChar = Core.UI.createSection(Core.Pages.Move, "Character")
    Core.UI.createToggle("God Mode (Invincible)", "godMode", secChar)
    Core.UI.createToggle("Anti Punch (No Knockback)", "antiPunch", secChar)
    Core.UI.createToggle("Admin Teleport (Click)", "devTeleport", secChar)

    local secMove = Core.UI.createSection(Core.Pages.Move, "Movement Adjustments")
    Core.UI.createInputRow("Speed Modifier", "2.0", secMove, 0.35, "speedBox")
    Core.UI.createToggle("Enable Super Speed", "speed", secMove)
    Core.UI.createToggle("Infinite Jump", "infJump", secMove)
    Core.UI.createToggle("Anti-Gravity (Fly)", "fly", secMove)

    -- Logic
    local isHoldingSpace = false
    local lockedX = nil -- Variabel untuk menyimpan posisi

    Core.UIS.InputBegan:Connect(function(input, gpe)
        if input.KeyCode == Enum.KeyCode.Space then isHoldingSpace = true end
        if gpe then return end 
        local isTouchOrClick = (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton3)
        if isTouchOrClick and Core.Toggles.devTeleport and Core.Managers.MovementState then
            local targetGrid = Core.Utils.getGridFromScreen(input.Position.X, input.Position.Y)
            if targetGrid then
                local newPos = Vector3.new(targetGrid.X, targetGrid.Y, 0) * Core.Utils.TILE_SIZE
                Core.Managers.MovementState.Position = newPos
                Core.Managers.MovementState.OldPosition = newPos
                Core.Managers.MovementState.VelocityX, Core.Managers.MovementState.VelocityY = 0, 0
                lockedX = newPos.X -- Update kunci posisi saat teleport
            end
        end
    end)

    Core.UIS.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Space then isHoldingSpace = false end
    end)

    Core.RS.RenderStepped:Connect(function()
        pcall(function()
            if Core.Toggles.godMode and Core.LocalPlayer.Character and Core.LocalPlayer.Character:FindFirstChild("Humanoid") then 
                Core.LocalPlayer.Character.Humanoid.Health = Core.LocalPlayer.Character.Humanoid.MaxHealth 
            end
            
            if Core.Managers.MovementState then
                -- ANTI PUNCH LOGIC (Aggressive Position Lock)
                if Core.Toggles.antiPunch then
                    -- Jika player sedang TIDAK berjalan
                    if Core.Managers.MovementState.MoveX == 0 then
                        if not lockedX then
                            lockedX = Core.Managers.MovementState.Position.X
                        else
                            local currentX = Core.Managers.MovementState.Position.X
                            local diff = math.abs(currentX - lockedX)
                            
                            -- Jika game menggeser kita karena dipukul (selisih kecil-menengah)
                            if diff > 0 and diff < 15 then
                                -- Tarik balik secara paksa ke posisi semula
                                Core.Managers.MovementState.Position = Vector3.new(lockedX, Core.Managers.MovementState.Position.Y, Core.Managers.MovementState.Position.Z)
                                Core.Managers.MovementState.OldPosition = Core.Managers.MovementState.Position
                                Core.Managers.MovementState.VelocityX = 0
                            elseif diff >= 15 then
                                -- Jika tiba-tiba pindah jauh (misal teleport / respawn), reset kunci
                                lockedX = currentX
                            end
                        end
                    else
                        -- Jika player sedang berjalan, lepaskan kunci
                        lockedX = nil
                    end

                    -- Matikan Physics Roblox (Untuk memastikan karakter tidak memantul secara visual)
                    local char = Core.LocalPlayer.Character
                    local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
                    if hrp then
                        hrp.Velocity = Vector3.new(0, hrp.Velocity.Y, 0)
                        hrp.RotVelocity = Vector3.zero
                    end
                else
                    lockedX = nil
                end

                -- SPEED & MOVEMENT LOGIC
                if Core.Toggles.speed and Core.Managers.MovementState.MoveX ~= 0 then 
                    Core.Managers.MovementState.VelocityX = Core.Managers.MovementState.MoveX * (tonumber(Core.Inputs["speedBox"] and Core.Inputs["speedBox"].Text) or 2.0) 
                end
                if Core.Toggles.infJump then 
                    Core.Managers.MovementState.RemainingJumps = 999; Core.Managers.MovementState.MaxJump = 999 
                end
                if Core.Toggles.fly then 
                    Core.Managers.MovementState.VelocityY = 0
                    if isHoldingSpace then 
                        Core.Managers.MovementState.Position = Core.Managers.MovementState.Position + Vector3.new(0, 0.4, 0) 
                    end 
                end
            end
        end)
    end)

    task.spawn(function()
        while task.wait(0.1) do
            if Core.Managers.MovementState then
                local px = math.floor(Core.Managers.MovementState.Position.X / Core.Utils.TILE_SIZE + 0.5)
                local py = math.floor(Core.Managers.MovementState.Position.Y / Core.Utils.TILE_SIZE + 0.5)
                posDisplay.Text = string.format("  X: %d, Y: %d", px, py)
            end
        end
    end)
end
