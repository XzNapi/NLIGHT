return function(Core)
    -- UI SETUP
    local secChatSpam = Core.UI.createSection(Core.Pages.Misc, "Chat Exploits (CB Bypass)")
    Core.UI.createInputRow("Spam Text", "NLight On Top!", secChatSpam, 0.45, "spamMsgBox")
    Core.UI.createInputRow("Spam Delay (Sec)", "2", secChatSpam, 0.45, "spamDelayBox")
    Core.UI.createToggle("Enable Auto Spammer", "chatSpam", secChatSpam, true)
    Core.UI.createToggle("Global Chat Spy (F9 Console)", "chatSpy", secChatSpam)

    local secVisual = Core.UI.createSection(Core.Pages.Misc, "Client Visuals")
    local oldPunch
    if Core.Managers.PCM then oldPunch = Core.Managers.PCM.PunchAnimation end
    Core.UI.createToggle("Anti-Lag VFX (No Punch)", "antiLag", secVisual, false, function(state)
        pcall(function()
            if Core.Managers.PCM and oldPunch then
                Core.Managers.PCM.PunchAnimation = function(player, pos)
                    if state and player == Core.LocalPlayer then return end
                    return oldPunch(player, pos)
                end
            end
        end)
    end)
    Core.UI.createToggle("Hide Player Names", "hideNames", secVisual, false)

    local secAdmin = Core.UI.createSection(Core.Pages.Misc, "Admin & Security")
    -- Mod Detector (Auto-Disconnect)
    Core.UI.createToggle("Mod Detector (Auto-Disconnect)", "modDetector", secAdmin, true)
    Core.UI.createToggle("Fake VIP (Cosmetic)", "fakeVip", secAdmin, false, function(state)
        pcall(function()
            if state then
                Core.LocalPlayer:SetAttribute("namePrefix", "[NLight VIP] "); Core.LocalPlayer:SetAttribute("nameColor", Color3.fromRGB(255, 215, 0))
            else
                Core.LocalPlayer:SetAttribute("namePrefix", ""); Core.LocalPlayer:SetAttribute("nameColor", Color3.fromRGB(255, 255, 255))
            end
        end)
    end)

    local secSpy = Core.UI.createSection(Core.Pages.Misc, "Developer Tools")
    Core.UI.createToggle("Trade Spy (Console F9)", "tradeSpy", secSpy)
    Core.UI.createToggle("Signal Spy (Console F9)", "signalSpy", secSpy)
    local copyItemsBtn = Core.UI.createButton("Scan & Copy Items (Clip)", secSpy, function()
        pcall(function()
            if Core.Managers.ItemsManager and Core.Managers.ItemsManager.ItemsData then
                local resultStr = "=== NLIGHT ITEM DATABASE ===\n"
                for id, data in pairs(Core.Managers.ItemsManager.ItemsData) do resultStr = resultStr .. "ID: " .. tostring(id) .. " | Name: " .. tostring(data.Name or "Unknown") .. "\n" end
                if setclipboard then setclipboard(resultStr) else print(resultStr) end
            end
        end)
    end)

    -- ==========================================
    -- LOGIC & LOOPS
    -- ==========================================

    -- [SISTEM KEAMANAN: MOD DETECTOR]
    local function isMod(player)
        if player == Core.LocalPlayer then return false end
        local prefix = tostring(player:GetAttribute("namePrefix") or "")
        local name = player.Name
        local display = player.DisplayName
        if string.find(name, "@") or string.find(display, "@") or string.find(prefix, "@") then return true end
        return false
    end

    Core.Players.PlayerAdded:Connect(function(player)
        if Core.Toggles.modDetector then
            task.wait(1) 
            pcall(function()
                if isMod(player) then
                    Core.LocalPlayer:Kick("\n[🛡️ NLight Security]\nMod/Admin (" .. player.Name .. ") terdeteksi masuk ke World!\nSistem otomatis memutuskan koneksi untuk menghindari Banned.")
                end
            end)
        end
    end)

    task.spawn(function()
        while task.wait(1) do
            pcall(function()
                if Core.Toggles.modDetector then
                    for _, p in ipairs(Core.Players:GetPlayers()) do
                        if isMod(p) then
                            Core.LocalPlayer:Kick("\n[🛡️ NLight Security]\nMod/Admin (" .. p.Name .. ") terdeteksi di dalam World!\nSistem otomatis memutuskan koneksi untuk menghindari Banned.")
                            break
                        end
                    end
                end
            end)
        end
    end)

    -- [SISTEM CHAT SPAM - ANTI SENSOR BYPASS]
    local spamCounter = 0 -- Inisialisasi angka awal
    
    task.spawn(function()
        while task.wait() do
            pcall(function()
                if Core.Toggles.chatSpam then
                    local delayTime = tonumber(Core.Inputs["spamDelayBox"] and Core.Inputs["spamDelayBox"].Text) or 2
                    if delayTime < 0.5 then delayTime = 0.5 end 
                    
                    local baseMsg = Core.Inputs["spamMsgBox"] and Core.Inputs["spamMsgBox"].Text or ""
                    
                    if baseMsg ~= "" then
                        -- Menggabungkan teks asli dengan angka berputar
                        local finalMsg = baseMsg .. " " .. tostring(spamCounter)
                        
                        if Core.Remotes.CBRemote then 
                            Core.Remotes.CBRemote:FireServer(finalMsg)
                        else 
                            local foundCB = Core.ReplicatedStorage:FindFirstChild("CB")
                            if foundCB then foundCB:FireServer(finalMsg) end 
                        end
                        
                        -- Logika putaran angka: Tambah 1, jika lewat dari 10 kembali ke 0
                        spamCounter = spamCounter + 1
                        if spamCounter > 10 then
                            spamCounter = 0
                        end
                    end
                    task.wait(delayTime)
                end
            end)
        end
    end)

    -- [SISTEM SPY REMOTES]
    task.spawn(function()
        if Core.Remotes.CBRemote and Core.Remotes.SignalConstructor and type(Core.Remotes.SignalConstructor) == "function" then
            pcall(function()
                local dummySignal = Core.Remotes.SignalConstructor()
                local signalMetatable = getmetatable(dummySignal)
                if signalMetatable and signalMetatable.Fire then
                    local oldFire = signalMetatable.Fire
                    signalMetatable.Fire = function(self, ...)
                        if Core.Toggles.signalSpy then
                            local args = {...}; local argString = ""
                            for i, v in ipairs(args) do argString = argString .. tostring(v) .. (i < #args and ", " or "") end
                            print("[SIGNAL SPY] Fired: (" .. argString .. ")")
                        end
                        return oldFire(self, ...)
                    end
                end
            end)
        end
        if Core.Remotes.PlayerTradeRemote then
            Core.Remotes.PlayerTradeRemote.OnClientEvent:Connect(function(state, p1, p1Items, p2, p2Items)
                if Core.Toggles.tradeSpy and state == 10 then
                    pcall(function()
                        print("\n--- [TRADE INTERCEPTED] ---")
                        print(tostring(p1) .. " MENDAPATKAN DARI " .. tostring(p2) .. ":")
                        if type(p2Items) == "table" then
                            for _, item in pairs(p2Items) do
                                local name = (Core.Managers.ItemsManager and Core.Managers.ItemsManager.ItemsData[item.Id] and Core.Managers.ItemsManager.ItemsData[item.Id].Name) or tostring(item.Id)
                                print(" + " .. tostring(item.Amount) .. "x " .. name)
                            end
                        end
                        print("---------------------------\n")
                    end)
                end
            end)
        end
    end)

    -- [SISTEM CHAT SPY]
    task.spawn(function()
        if Core.TextChatService then
            Core.TextChatService.MessageReceived:Connect(function(textChatMessage)
                if Core.Toggles.chatSpy and textChatMessage.TextSource then
                    pcall(function()
                        if textChatMessage.TextSource.UserId ~= Core.LocalPlayer.UserId then
                            local senderName = textChatMessage.TextSource.Name
                            local channelName = tostring(textChatMessage.TextChannel.Name)
                            local msgText = tostring(textChatMessage.Text)
                            print("[🕵️ CHAT SPY] " .. senderName .. " [" .. channelName .. "]: " .. msgText)
                        end
                    end)
                end
            end)
        end
    end)

    -- [SISTEM HIDE NAMES]
    task.spawn(function()
        while task.wait(1) do
            pcall(function()
                for _, p in ipairs(Core.Players:GetPlayers()) do
                    if p.Character then
                        local hum = p.Character:FindFirstChild("Humanoid")
                        if hum then hum.DisplayDistanceType = Core.Toggles.hideNames and Enum.HumanoidDisplayDistanceType.None or Enum.HumanoidDisplayDistanceType.Viewer end
                        for _, obj in ipairs(p.Character:GetDescendants()) do
                            if obj:IsA("BillboardGui") then obj.Enabled = not Core.Toggles.hideNames end
                        end
                    end
                end
            end)
        end
    end)
end
