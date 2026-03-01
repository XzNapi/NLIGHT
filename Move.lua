return function(Core)
    -- UI
    local secInfo = Core.UI.createSection(Core.Pages.Move, "Live Status")
    local posDisplay = Core.UI.createLabelDisplay("Current Grid: X: 0, Y: 0", secInfo)

    local secChar = Core.UI.createSection(Core.Pages.Move, "Character")
    Core.UI.createToggle("God Mode (Invincible)", "godMode", secChar)
    Core.UI.createToggle("Admin Teleport (Click)", "devTeleport", secChar)

    local secMove = Core.UI.createSection(Core.Pages.Move, "Movement Adjustments")
    Core.UI.createInputRow("Speed Modifier", "2.0", secMove, 0.35, "speedBox")
    Core.UI.createToggle("Enable Super Speed", "speed", secMove)
    Core.UI.createToggle("Infinite Jump", "infJump", secMove)
    Core.UI.createToggle("Anti-Gravity (Fly)", "fly", secMove)

    -- Logic
    local isHoldingSpace = false

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
