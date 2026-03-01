return function(Core)
    -- UI SETUP
    local secCamera = Core.UI.createSection(Core.Pages.World, "Camera & Viewport")
    Core.UI.createButton("Unlock Camera Max Zoom", secCamera, function() pcall(function() Core.LocalPlayer.CameraMaxZoomDistance = 100000 end) end)
    Core.UI.createToggle("Lock Scanner (Show Borders)", "lockScanner", secCamera, false, function(state)
        pcall(function()
            if Core.Managers.WorldManager then
                for _, col in pairs(Core.Managers.WorldManager.RenderedTiles) do
                    for _, layers in pairs(col) do
                        if layers[5] then layers[5].ImageTransparency = state and 0.3 or 1; layers[5].ImageColor3 = state and Color3.fromRGB(255, 255, 0) or Color3.new(1,1,1) end
                    end
                end
            end
        end)
    end)
    Core.UI.createToggle("X-Ray (Hide Terrain)", "xRay", secCamera, false, function(state)
        pcall(function()
            if Core.Managers.WorldManager then
                for _, col in pairs(Core.Managers.WorldManager.RenderedTiles) do
                    for _, layers in pairs(col) do if layers[1] then layers[1].Visible = not state end end
                end
            end
        end)
    end)

    local secTime = Core.UI.createSection(Core.Pages.World, "Engine Time")
    local tpsBox = Core.UI.createInputRow("Time Warp TPS (Max 200)", "100", secTime, 0.35, "tpsBox")
    local function updateEngineTime()
        pcall(function()
            if not Core.Managers.TickManager then return end
            if Core.Toggles.timeFreeze then Core.Managers.TickManager.TPS = 0.00001
            elseif Core.Toggles.timeWarp then Core.Managers.TickManager.TPS = math.clamp(tonumber(Core.Inputs["tpsBox"] and Core.Inputs["tpsBox"].Text) or 100, 1, 200) 
            else Core.Managers.TickManager.TPS = 20 end
        end)
    end
    Core.UI.createToggle("Enable Time Warp", "timeWarp", secTime, false, updateEngineTime)
    Core.UI.createToggle("Freeze Time (Za Warudo)", "timeFreeze", secTime, true, updateEngineTime)

    local secData = Core.UI.createSection(Core.Pages.World, "Data Dumper")
    Core.UI.createButton("Dump Map Structure (F9)", secData, function()
        pcall(function()
            if Core.Managers.WorldTiles then
                print("\n--- [MAP DUMPED] ---")
                for x, col in pairs(Core.Managers.WorldTiles) do
                    if type(col) == "table" then
                        for y, layers in pairs(col) do
                            for layerZ, data in pairs(layers) do print(string.format("Grid[%s, %s] L%s = ID: %s", x, y, layerZ, type(data)=="table" and tostring(data[1]) or tostring(data))) end
                        end
                    end
                end
                print("--------------------\n")
            end
        end)
    end)
end
