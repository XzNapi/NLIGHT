local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local TS = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- ==========================================
-- MENGAMBIL DATA GAME
-- ==========================================
local MovementState, PCM, WorldManager, ItemsManager, InventoryModule, WorldTiles, TickManager = nil, nil, nil, nil, nil, nil, nil
local Remotes, PlayerFistRemote, PlayerPlaceRemote, PlayerTradeRemote, SignalConstructor, CBRemote, PlayerMovementRemote

task.spawn(function() pcall(function() MovementState = require(LocalPlayer.PlayerScripts:WaitForChild("PlayerMovement")) end) end)
task.spawn(function() pcall(function() PCM = require(ReplicatedStorage:WaitForChild("Managers"):WaitForChild("PlayerClientManager")) end) end)
task.spawn(function() pcall(function() WorldManager = require(ReplicatedStorage:WaitForChild("Managers"):WaitForChild("WorldManager")) end) end)
task.spawn(function() pcall(function() ItemsManager = require(ReplicatedStorage:WaitForChild("Managers"):WaitForChild("ItemsManager")) end) end)
task.spawn(function() pcall(function() InventoryModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Inventory")) end) end)
task.spawn(function() pcall(function() WorldTiles = require(ReplicatedStorage:WaitForChild("WorldTiles")) end) end)
task.spawn(function() pcall(function() TickManager = require(ReplicatedStorage:WaitForChild("Managers"):WaitForChild("TickManager")) end) end)
task.spawn(function() pcall(function() CBRemote = ReplicatedStorage:WaitForChild("CB", 5) end) end)

task.spawn(function()
    pcall(function()
        Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
        if Remotes then
            PlayerFistRemote = Remotes:WaitForChild("PlayerFist", 5)
            PlayerPlaceRemote = Remotes:WaitForChild("PlayerPlaceItem", 5)
            PlayerTradeRemote = Remotes:WaitForChild("PlayerTrade", 5)
            PlayerMovementRemote = Remotes:WaitForChild("PlayerMovementPackets", 5):WaitForChild(LocalPlayer.Name, 5)
            pcall(function() SignalConstructor = require(Remotes:WaitForChild("Signal", 5)) end)
        end
    end)
end)

local TILE_SIZE = 4.5 

local function getGridFromScreen(screenX, screenY)
    local camera = workspace.CurrentCamera
    if not camera then return nil, nil end
    local ray = camera:ViewportPointToRay(screenX, screenY)
    if ray.Direction.Z ~= 0 then
        local distance = -ray.Origin.Z / ray.Direction.Z
        local hitPos = ray.Origin + ray.Direction * distance
        return Vector2.new(math.round(hitPos.X / TILE_SIZE), math.round(hitPos.Y / TILE_SIZE)), hitPos
    end
    return nil, nil
end

local function getBaseId(itemName)
    if ItemsManager and ItemsManager.GetBaseId then return ItemsManager.GetBaseId(itemName) end
    if type(itemName) == "string" then return string.gsub(itemName, "_sapling$", "") end
    return itemName
end

local function getHeldItem()
    if InventoryModule and InventoryModule.GetSelectedHotbarItem then
        local item = InventoryModule.GetSelectedHotbarItem()
        if item and item.Id then return string.lower(tostring(item.Id)) end
    end
    return nil
end

-- ==========================================
-- SYSTEM CONFIG & SAVE DATA
-- ==========================================
local ConfigFile = "NLight_Config.json"
local toggles = { speed = false, infJump = false, fly = false, devTeleport = false, smartAutoFarm = false, autoPlanter = false, autoBreaker = false, godMode = false, antiLag = false, hideNames = false, lockScanner = false, xRay = false, tradeSpy = false, timeWarp = false, timeFreeze = false, signalSpy = false, fakeVip = false, chatSpam = false, chatSpy = false, oneHitBreak = false, autoLoot = false, itemRadar = false, farmGrids = {}, smartFarmItem = "auto", planterItem = "auto", planterBase = "dirt", breakerTarget = "wood" }
local savedInputs = {}
local inputInstances = {}

if readfile and isfile and isfile(ConfigFile) then
    pcall(function()
        local data = HttpService:JSONDecode(readfile(ConfigFile))
        if data.toggles then for k, v in pairs(data.toggles) do toggles[k] = v end end
        if data.inputs then for k, v in pairs(data.inputs) do savedInputs[k] = v end end
    end)
end

task.spawn(function()
    while task.wait(3) do
        if writefile then
            pcall(function()
                local toSave = { toggles = toggles, inputs = {} }
                for k, box in pairs(inputInstances) do toSave.inputs[k] = box.Text end
                writefile(ConfigFile, HttpService:JSONEncode(toSave))
            end)
        end
    end
end)

if hookmetamethod then
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if toggles.godMode and tostring(self.Name) == "PlayerHurtMe" and method == "FireServer" then return end
        return oldNamecall(self, ...)
    end)
end

-- ==========================================
-- UI SETUP & FRAMEWORK
-- ==========================================
local oldGui = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("NLightModern")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui", LocalPlayer.PlayerGui)
gui.Name = "NLightModern"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true 
gui.DisplayOrder = 2147483647 
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global

local Theme = {
    Background = Color3.fromRGB(13, 13, 17), Surface = Color3.fromRGB(22, 22, 28), Item = Color3.fromRGB(30, 30, 38), Border = Color3.fromRGB(45, 45, 55),
    Text = Color3.fromRGB(250, 250, 255), TextMuted = Color3.fromRGB(150, 150, 160), Accent = Color3.fromRGB(99, 102, 241),
    ToggleOff = Color3.fromRGB(55, 55, 65), Success = Color3.fromRGB(34, 197, 94), Danger = Color3.fromRGB(239, 68, 68), Orange = Color3.fromRGB(245, 158, 11)
}

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 380, 0, 380); frame.Position = UDim2.new(0.05, 0, 0.2, 0); frame.BackgroundColor3 = Theme.Background; frame.Active = true; frame.Draggable = true; frame.BorderSizePixel = 0
frame.ZIndex = 1
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12); Instance.new("UIStroke", frame).Color = Theme.Border

local titleBar = Instance.new("Frame", frame)
titleBar.Size = UDim2.new(1, 0, 0, 50); titleBar.BackgroundTransparency = 1; titleBar.ZIndex = 2
local title = Instance.new("TextLabel", titleBar)
title.Text = "NLIGHT"; title.Font = Enum.Font.GothamBlack; title.TextSize = 18; title.TextColor3 = Theme.Text; title.BackgroundTransparency = 1; title.Size = UDim2.new(1, -20, 1, 0); title.Position = UDim2.new(0, 20, 0, 0); title.TextXAlignment = Enum.TextXAlignment.Left; title.ZIndex = 2

local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Text = "✕"; closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 14; closeBtn.Size = UDim2.new(0, 50, 1, 0); closeBtn.Position = UDim2.new(1, -50, 0, 0); closeBtn.BackgroundTransparency = 1; closeBtn.TextColor3 = Theme.TextMuted; closeBtn.ZIndex = 2
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)
local minBtn = Instance.new("TextButton", titleBar)
minBtn.Text = "—"; minBtn.Font = Enum.Font.GothamBold; minBtn.TextSize = 14; minBtn.Size = UDim2.new(0, 50, 1, 0); minBtn.Position = UDim2.new(1, -90, 0, 0); minBtn.BackgroundTransparency = 1; minBtn.TextColor3 = Theme.TextMuted; minBtn.ZIndex = 2

local openBtn = Instance.new("TextButton", gui)
openBtn.Size = UDim2.new(0, 45, 0, 45); openBtn.Position = UDim2.new(0.02, 0, 0.5, 0); openBtn.BackgroundColor3 = Theme.Surface; openBtn.Text = "NL"; openBtn.Font = Enum.Font.GothamBlack; openBtn.TextSize = 14; openBtn.TextColor3 = Theme.Accent; openBtn.Visible = false; openBtn.Active = true; openBtn.Draggable = true; openBtn.ZIndex = 1; Instance.new("UICorner", openBtn).CornerRadius = UDim.new(1, 0); Instance.new("UIStroke", openBtn).Color = Theme.Border

local tabBar = Instance.new("ScrollingFrame", frame)
tabBar.Size = UDim2.new(1, -40, 0, 35); tabBar.Position = UDim2.new(0, 20, 0, 50); tabBar.BackgroundTransparency = 1; tabBar.ScrollBarThickness = 0; tabBar.CanvasSize = UDim2.new(0, 0, 0, 0); tabBar.AutomaticCanvasSize = Enum.AutomaticSize.X; tabBar.ZIndex = 2
local tabLayout = Instance.new("UIListLayout", tabBar); tabLayout.FillDirection = Enum.FillDirection.Horizontal; tabLayout.SortOrder = Enum.SortOrder.LayoutOrder; tabLayout.Padding = UDim.new(0, 20)

local tabPages, tabButtons = {}, {}
local contentArea = Instance.new("Frame", frame)
contentArea.Size = UDim2.new(1, 0, 1, -100); contentArea.Position = UDim2.new(0, 0, 0, 100); contentArea.BackgroundTransparency = 1; contentArea.ZIndex = 2
local activeIndicator = Instance.new("Frame", frame)
activeIndicator.Size = UDim2.new(0, 30, 0, 3); activeIndicator.BackgroundColor3 = Theme.Accent; activeIndicator.BorderSizePixel = 0; activeIndicator.Position = UDim2.new(0, 20, 0, 85); activeIndicator.ZIndex = 2; Instance.new("UICorner", activeIndicator).CornerRadius = UDim.new(1,0)

local function createTab(name)
    local tabBtn = Instance.new("TextButton", tabBar)
    tabBtn.Size = UDim2.new(0, 0, 1, 0); tabBtn.AutomaticSize = Enum.AutomaticSize.X; tabBtn.Text = string.upper(name); tabBtn.Font = Enum.Font.GothamBold; tabBtn.TextSize = 12; tabBtn.BackgroundTransparency = 1; tabBtn.TextColor3 = Theme.TextMuted; tabBtn.ZIndex = 2
    table.insert(tabButtons, tabBtn)

    local tabPage = Instance.new("ScrollingFrame", contentArea)
    tabPage.Size = UDim2.new(1, 0, 1, 0); tabPage.CanvasSize = UDim2.new(0, 0, 0, 0); tabPage.AutomaticCanvasSize = Enum.AutomaticSize.Y; tabPage.BackgroundTransparency = 1; tabPage.ScrollBarThickness = 4; tabPage.ScrollBarImageColor3 = Theme.Border; tabPage.Visible = false; tabPage.ZIndex = 2
    local pageLayout = Instance.new("UIListLayout", tabPage); pageLayout.Padding = UDim.new(0, 15); pageLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    Instance.new("UIPadding", tabPage).PaddingTop = UDim.new(0, 5); Instance.new("UIPadding", tabPage).PaddingBottom = UDim.new(0, 20)
    table.insert(tabPages, tabPage)

    tabBtn.MouseButton1Click:Connect(function()
        for _, btn in ipairs(tabButtons) do btn.TextColor3 = Theme.TextMuted end
        for _, page in ipairs(tabPages) do page.Visible = false end
        tabBtn.TextColor3 = Theme.Text; tabPage.Visible = true
        TS:Create(activeIndicator, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Position = UDim2.new(0, tabBtn.AbsolutePosition.X - frame.AbsolutePosition.X, 0, 85), Size = UDim2.new(0, tabBtn.AbsoluteSize.X, 0, 3)}):Play()
    end)
    return tabPage, tabBtn
end

local function createSection(parent, titleText)
    local section = Instance.new("Frame", parent)
    section.Size = UDim2.new(0.92, 0, 0, 0); section.AutomaticSize = Enum.AutomaticSize.Y; section.BackgroundColor3 = Theme.Surface; section.ZIndex = 3
    Instance.new("UICorner", section).CornerRadius = UDim.new(0, 10); Instance.new("UIStroke", section).Color = Theme.Border
    local title = Instance.new("TextLabel", section)
    title.Size = UDim2.new(1, -30, 0, 35); title.Position = UDim2.new(0, 15, 0, 0); title.BackgroundTransparency = 1; title.Text = string.upper(titleText); title.TextColor3 = Theme.Accent; title.Font = Enum.Font.GothamBold; title.TextSize = 11; title.TextXAlignment = Enum.TextXAlignment.Left; title.ZIndex = 3
    local content = Instance.new("Frame", section)
    content.Size = UDim2.new(1, 0, 0, 0); content.Position = UDim2.new(0, 0, 0, 35); content.AutomaticSize = Enum.AutomaticSize.Y; content.BackgroundTransparency = 1; content.ZIndex = 3
    local layout = Instance.new("UIListLayout", content)
    layout.Padding = UDim.new(0, 8); layout.HorizontalAlignment = Enum.HorizontalAlignment.Center; layout.SortOrder = Enum.SortOrder.LayoutOrder
    Instance.new("UIPadding", content).PaddingBottom = UDim.new(0, 15)
    return content
end

local function createToggle(text, stateKey, parent, isDanger, callback)
    local container = Instance.new("TextButton", parent)
    container.Size = UDim2.new(0.92, 0, 0, 40); container.BackgroundColor3 = Theme.Item; container.Text = ""; container.AutoButtonColor = false; container.ZIndex = 4
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 6)
    local lbl = Instance.new("TextLabel", container); lbl.Size = UDim2.new(1, -60, 1, 0); lbl.Position = UDim2.new(0, 15, 0, 0); lbl.BackgroundTransparency = 1; lbl.Text = text; lbl.TextColor3 = isDanger and Theme.Danger or Theme.Text; lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 13; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 4
    local track = Instance.new("Frame", container); track.Size = UDim2.new(0, 34, 0, 18); track.Position = UDim2.new(1, -45, 0.5, -9); track.BackgroundColor3 = Theme.ToggleOff; track.ZIndex = 4; Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    local knob = Instance.new("Frame", track); knob.Size = UDim2.new(0, 12, 0, 12); knob.Position = UDim2.new(0, 3, 0.5, -6); knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255); knob.ZIndex = 5; Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    local activeColor = isDanger and Theme.Danger or Theme.Accent
    local function updateVisuals()
        TS:Create(knob, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Position = toggles[stateKey] and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)}):Play()
        TS:Create(track, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {BackgroundColor3 = toggles[stateKey] and activeColor or Theme.ToggleOff}):Play()
    end
    updateVisuals() 
    container.MouseButton1Click:Connect(function() toggles[stateKey] = not toggles[stateKey]; updateVisuals(); if callback then callback(toggles[stateKey]) end end)
    return function() updateVisuals() end 
end

local function createInputRow(labelTxt, defaultVal, parent, boxWidth, stateKey)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(0.92, 0, 0, 40); container.BackgroundColor3 = Theme.Item; container.ZIndex = 4; Instance.new("UICorner", container).CornerRadius = UDim.new(0, 6)
    local lbl = Instance.new("TextLabel", container); lbl.Size = UDim2.new(1 - (boxWidth or 0.35) - 0.1, 0, 1, 0); lbl.Position = UDim2.new(0, 15, 0, 0); lbl.BackgroundTransparency = 1; lbl.Text = labelTxt; lbl.TextColor3 = Theme.Text; lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 13; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 4
    local boxContainer = Instance.new("Frame", container); boxContainer.Size = UDim2.new(boxWidth or 0.35, 0, 0, 26); boxContainer.Position = UDim2.new(1 - (boxWidth or 0.35) - 0.05, 0, 0.5, -13); boxContainer.BackgroundColor3 = Theme.Background; boxContainer.ZIndex = 4; Instance.new("UICorner", boxContainer).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", boxContainer).Color = Theme.Border
    local box = Instance.new("TextBox", boxContainer); box.Size = UDim2.new(1, 0, 1, 0); box.BackgroundTransparency = 1; box.ZIndex = 5; 
    local actualDefault = (stateKey and savedInputs[stateKey]) and savedInputs[stateKey] or defaultVal
    box.Text = tostring(actualDefault); box.Font = Enum.Font.GothamBold; box.TextSize = 12; box.TextColor3 = Theme.Accent; box.ClearTextOnFocus = false
    if stateKey then inputInstances[stateKey] = box end
    return box
end

local function createButton(text, parent, callback)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(0.92, 0, 0, 40); btn.BackgroundColor3 = Theme.Item; btn.Text = text; btn.Font = Enum.Font.GothamBold; btn.TextSize = 13; btn.TextColor3 = Theme.Text; btn.AutoButtonColor = false; btn.ZIndex = 4; Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", btn).Color = Theme.Border
    btn.MouseEnter:Connect(function() TS:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(45, 45, 55)}):Play() end)
    btn.MouseLeave:Connect(function() TS:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Theme.Item}):Play() end)
    btn.MouseButton1Down:Connect(function() TS:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Theme.Accent}):Play() end)
    btn.MouseButton1Up:Connect(function() TS:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(45, 45, 55)}):Play() end)
    if callback then btn.MouseButton1Click:Connect(callback) end
    return btn
end

local function createLabelDisplay(text, parent)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(0.92, 0, 0, 30); container.BackgroundColor3 = Theme.Background; container.ZIndex = 4; Instance.new("UICorner", container).CornerRadius = UDim.new(0, 6)
    local lbl = Instance.new("TextLabel", container); lbl.Size = UDim2.new(1, -20, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0); lbl.BackgroundTransparency = 1; lbl.Text = text; lbl.TextColor3 = Theme.Accent; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 11; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 4
    return lbl
end

-- UPDATE PENTING: MENAMBAHKAN PARAMETER filterFunc
local function createInventoryDropdown(labelTxt, stateKey, parent, callback, filterFunc)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(0.92, 0, 0, 40); container.BackgroundColor3 = Theme.Item; container.ClipsDescendants = true; container.ZIndex = 6; Instance.new("UICorner", container).CornerRadius = UDim.new(0, 6)
    local lbl = Instance.new("TextLabel", container); lbl.Size = UDim2.new(0.5, 0, 0, 40); lbl.Position = UDim2.new(0, 15, 0, 0); lbl.BackgroundTransparency = 1; lbl.Text = labelTxt; lbl.TextColor3 = Theme.Text; lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 13; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 6
    local btnContainer = Instance.new("Frame", container); btnContainer.Size = UDim2.new(0.45, 0, 0, 26); btnContainer.Position = UDim2.new(0.5, 0, 0, 7); btnContainer.BackgroundColor3 = Theme.Background; btnContainer.ZIndex = 6; Instance.new("UICorner", btnContainer).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", btnContainer).Color = Theme.Border
    local mainBtn = Instance.new("TextButton", btnContainer); mainBtn.Size = UDim2.new(1, -5, 1, 0); mainBtn.Position = UDim2.new(0, 5, 0, 0); mainBtn.BackgroundTransparency = 1; toggles[stateKey] = toggles[stateKey] or "auto"; mainBtn.Text = "▶ " .. toggles[stateKey]; mainBtn.Font = Enum.Font.GothamBold; mainBtn.TextSize = 11; mainBtn.TextColor3 = Theme.Accent; mainBtn.TextTruncate = Enum.TextTruncate.AtEnd; mainBtn.TextXAlignment = Enum.TextXAlignment.Left; mainBtn.ZIndex = 7
    local optionList = Instance.new("ScrollingFrame", container); optionList.Size = UDim2.new(1, 0, 0, 120); optionList.Position = UDim2.new(0, 0, 0, 40); optionList.BackgroundTransparency = 1; optionList.ScrollBarThickness = 2; optionList.ScrollBarImageColor3 = Theme.Border; optionList.ZIndex = 7
    local listLayout = Instance.new("UIListLayout", optionList); listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    local isOpen = false
    mainBtn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        if isOpen then
            for _, child in ipairs(optionList:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
            local rawItems, addedItems = {}, {}
            if InventoryModule and InventoryModule.Stacks then
                for i = 1, (InventoryModule.MaxSlots or 100) do
                    local stackInfo = InventoryModule.Stacks[i]
                    if stackInfo and stackInfo.Id and stackInfo.Amount and stackInfo.Amount > 0 then
                        local itemId = tostring(stackInfo.Id)
                        local itemName = ItemsManager and ItemsManager.ItemsData and ItemsManager.ItemsData[itemId] and ItemsManager.ItemsData[itemId].Name or itemId
                        
                        -- CEK FILTER FUNC DISINI
                        local isAllowed = true
                        if filterFunc then
                            isAllowed = filterFunc(string.lower(itemName), string.lower(itemId))
                        end
                        
                        if isAllowed and not addedItems[itemName] then 
                            table.insert(rawItems, itemName)
                            addedItems[itemName] = true 
                        end
                    end
                end
            end
            table.sort(rawItems); table.insert(rawItems, 1, "auto")
            for _, opt in ipairs(rawItems) do
                local optBtn = Instance.new("TextButton", optionList); optBtn.Size = UDim2.new(1, 0, 0, 30); optBtn.BackgroundColor3 = Theme.Surface; optBtn.Text = "  " .. opt; optBtn.Font = Enum.Font.GothamMedium; optBtn.TextSize = 11; optBtn.TextColor3 = Theme.TextMuted; optBtn.BorderSizePixel = 0; optBtn.TextXAlignment = Enum.TextXAlignment.Left; optBtn.TextTruncate = Enum.TextTruncate.AtEnd; optBtn.ZIndex = 8
                optBtn.MouseEnter:Connect(function() optBtn.TextColor3 = Theme.Text end); optBtn.MouseLeave:Connect(function() optBtn.TextColor3 = Theme.TextMuted end)
                optBtn.MouseButton1Click:Connect(function() toggles[stateKey] = opt; mainBtn.Text = "▶ " .. opt; isOpen = false; TS:Create(container, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Size = UDim2.new(0.92, 0, 0, 40)}):Play(); if callback then callback(opt) end end)
            end
            local contentHeight = #rawItems * 30; optionList.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
            local displayHeight = math.min(contentHeight, 120); optionList.Size = UDim2.new(1, 0, 0, displayHeight)
            TS:Create(container, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Size = UDim2.new(0.92, 0, 0, 40 + displayHeight)}):Play()
        else TS:Create(container, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Size = UDim2.new(0.92, 0, 0, 40)}):Play() end
    end)
end

-- ==========================================
-- POPUP GRID UI (8x8)
-- ==========================================
local popupOverlay = Instance.new("Frame", gui)
popupOverlay.Size = UDim2.new(1, 0, 1, 0); popupOverlay.BackgroundColor3 = Color3.new(0, 0, 0); popupOverlay.BackgroundTransparency = 0.5; popupOverlay.Visible = false; popupOverlay.Active = true; popupOverlay.ZIndex = 100

local gridPopup = Instance.new("Frame", popupOverlay)
gridPopup.Size = UDim2.new(0, 320, 0, 420); gridPopup.Position = UDim2.new(0.5, -160, 0.5, -210); gridPopup.BackgroundColor3 = Theme.Background; gridPopup.ZIndex = 101; Instance.new("UICorner", gridPopup).CornerRadius = UDim.new(0, 12); Instance.new("UIStroke", gridPopup).Color = Theme.Border

local gridHeader = Instance.new("Frame", gridPopup)
gridHeader.Size = UDim2.new(1, 0, 0, 50); gridHeader.BackgroundTransparency = 1; gridHeader.ZIndex = 102

local gridTitleLbl = Instance.new("TextLabel", gridHeader)
gridTitleLbl.Size = UDim2.new(1, -60, 1, 0); gridTitleLbl.Position = UDim2.new(0, 20, 0, 0); gridTitleLbl.BackgroundTransparency = 1; gridTitleLbl.Text = "SELECT GRID (8x8)"; gridTitleLbl.Font = Enum.Font.GothamBold; gridTitleLbl.TextSize = 16; gridTitleLbl.TextColor3 = Theme.Text; gridTitleLbl.ZIndex = 102; gridTitleLbl.TextXAlignment = Enum.TextXAlignment.Left

local gridCloseBtn = Instance.new("TextButton", gridHeader)
gridCloseBtn.Size = UDim2.new(0, 50, 0, 50); gridCloseBtn.Position = UDim2.new(1, -50, 0, 0); gridCloseBtn.BackgroundTransparency = 1; gridCloseBtn.Text = "✕"; gridCloseBtn.Font = Enum.Font.GothamBold; gridCloseBtn.TextSize = 14; gridCloseBtn.TextColor3 = Theme.TextMuted; gridCloseBtn.ZIndex = 102; gridCloseBtn.MouseButton1Click:Connect(function() popupOverlay.Visible = false end)

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
    btn.Text = ""; btn.BackgroundColor3 = toggles.farmGrids[key] and Theme.Orange or Theme.Item; btn.ZIndex = 103; Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
    if dx == 0 and dy == 0 then
        local userPenanda = Instance.new("Frame", btn)
        userPenanda.Size = UDim2.new(0, 28, 0, 28); userPenanda.Position = UDim2.new(0.5, 0, 0.5, 0); userPenanda.AnchorPoint = Vector2.new(0.5, 0.5); userPenanda.BackgroundColor3 = Theme.Orange; userPenanda.BackgroundTransparency = 0.5; userPenanda.ZIndex = 104; Instance.new("UICorner", userPenanda).CornerRadius = UDim.new(1, 0)
        local userIconContainer = Instance.new("Frame", userPenanda)
        userIconContainer.Size = UDim2.new(0, 14, 0, 14); userIconContainer.Position = UDim2.new(0.5, 0, 0.4, 0); userIconContainer.AnchorPoint = Vector2.new(0.5, 0.5); userIconContainer.BackgroundColor3 = Color3.fromRGB(255, 255, 255); userIconContainer.ZIndex = 105; Instance.new("UICorner", userIconContainer).CornerRadius = UDim.new(1, 0)
        local userIcon = Instance.new("ImageLabel", userIconContainer); userIcon.Size = UDim2.new(1, 0, 1, 0); userIcon.BackgroundTransparency = 1; userIcon.Image = "rbxassetid://15264843997"; userIcon.ImageColor3 = Theme.Orange; userIcon.ZIndex = 106
        local lbl = Instance.new("TextLabel", userPenanda); lbl.Size = UDim2.new(1, 0, 0, 10); lbl.Position = UDim2.new(0.5, 0, 0.75, 0); lbl.AnchorPoint = Vector2.new(0.5, 0.5); lbl.BackgroundTransparency = 1; lbl.Text = "ME"; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 7; lbl.TextColor3 = Theme.Orange; lbl.ZIndex = 105
    end
    btn.MouseButton1Click:Connect(function() toggles.farmGrids[key] = not toggles.farmGrids[key]; TS:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = toggles.farmGrids[key] and Theme.Orange or Theme.Item}):Play() end)
end

local saveGridBtn = Instance.new("TextButton", gridPopup)
saveGridBtn.Size = UDim2.new(0, 200, 0, 40); saveGridBtn.Position = UDim2.new(0.5, -100, 1, -55); saveGridBtn.BackgroundColor3 = Theme.Success; saveGridBtn.Text = "Done"; saveGridBtn.Font = Enum.Font.GothamBold; saveGridBtn.TextSize = 16; saveGridBtn.TextColor3 = Color3.fromRGB(13, 13, 17); saveGridBtn.ZIndex = 102; saveGridBtn.AutoButtonColor = false; Instance.new("UICorner", saveGridBtn).CornerRadius = UDim.new(0, 8)
saveGridBtn.MouseButton1Click:Connect(function() popupOverlay.Visible = false end)

local function toggleMenu() frame.Visible = not frame.Visible; openBtn.Visible = not frame.Visible end
minBtn.MouseButton1Click:Connect(toggleMenu); openBtn.MouseButton1Click:Connect(toggleMenu)

-- TABS
local pageMove = createTab("Move")
local pageFarm = createTab("Farm")
local pageWorld = createTab("World")
local pageMisc = createTab("Misc")
tabButtons[1].TextColor3 = Theme.Text; pageMove.Visible = true; task.spawn(function() task.wait(0.1); activeIndicator.Position = UDim2.new(0, tabButtons[1].AbsolutePosition.X - frame.AbsolutePosition.X, 0, 85); activeIndicator.Size = UDim2.new(0, tabButtons[1].AbsoluteSize.X, 0, 3) end)

-- ==========================================
-- PATHFINDING CORE
-- ==========================================
local blacklistedItems, blacklistedSpots, passableTilesCache, solidTilesCache = {}, {}, {}, {}
task.spawn(function() while task.wait(5) do blacklistedSpots = {}; blacklistedItems = {}; passableTilesCache = {}; solidTilesCache = {} end end)

local function isOutOfBounds(x, y)
    local minB, maxB = workspace:GetAttribute("WorldMin"), workspace:GetAttribute("WorldMax")
    if minB and maxB and (x < minB.X or x > maxB.X or y < minB.Y or y > maxB.Y) then return true end
    if WorldTiles and type(WorldTiles) == "table" and rawget(WorldTiles, x) == nil and rawget(WorldTiles, tostring(x)) == nil then return true end
    return false
end

local function isTileSolidForPathfinding(x, y)
    if not WorldManager or not WorldManager.GetTile then return false end
    local tileId = WorldManager.GetTile(x, y, 1)
    if not tileId then return false end
    if passableTilesCache[tileId] then return false end
    if solidTilesCache[tileId] then return true end
    local name = string.lower(tostring((ItemsManager and ItemsManager.ItemsData and ItemsManager.ItemsData[tileId] and ItemsManager.ItemsData[tileId].Name) or tileId))
   
    if string.find(name, "sapling") then 
        passableTilesCache[tileId] = true 
        return false 
    end
    solidTilesCache[tileId] = true 
    return true
end

local function isLineOfSightClear(x0, y0, x1, y1)
    local dx, dy = math.abs(x1 - x0), math.abs(y1 - y0)
    local sx, sy = (x0 < x1 and 1 or -1), (y0 < y1 and 1 or -1)
    local err = dx - dy
    while true do
        if isOutOfBounds(x0, y0) or isTileSolidForPathfinding(x0, y0) then return false end 
        if x0 == x1 and y0 == y1 then break end
        local e2 = 2 * err
        if e2 > -dy then err = err - dy; x0 = x0 + sx end
        if e2 < dx then err = err + dx; y0 = y0 + sy end
    end
    return true
end

local function getPath(startX, startY, endX, endY)
    local open, closed, nodeGrid = {}, {}, {}
    local startNode = {x = startX, y = startY, g = 0, f = 0, parent = nil}
    table.insert(open, startNode); nodeGrid[startX .. "," .. startY] = startNode
    local iter = 0
    local dirs = {{dx=1, dy=0, cost=10}, {dx=-1, dy=0, cost=10}, {dx=0, dy=1, cost=10}, {dx=0, dy=-1, cost=10}, {dx=1, dy=1, cost=14}, {dx=1, dy=-1, cost=14}, {dx=-1, dy=1, cost=14}, {dx=-1, dy=-1, cost=14}}
    while #open > 0 do
        iter = iter + 1; if iter % 1000 == 0 then task.wait() end
        local currIdx, currNode = 1, open[1]
        for i = 2, #open do if open[i].f < currNode.f then currNode = open[i]; currIdx = i end end
        table.remove(open, currIdx)
        local key = currNode.x .. "," .. currNode.y; closed[key] = true
        if currNode.x == endX and currNode.y == endY then
            local path, temp = {}, currNode
            while temp do table.insert(path, 1, Vector2.new(temp.x, temp.y)); temp = temp.parent end
            return path
        end
        for _, d in ipairs(dirs) do
            local nx, ny = currNode.x + d.dx, currNode.y + d.dy; local nKey = nx .. "," .. ny
            if not closed[nKey] then
                local isSolid = isOutOfBounds(nx, ny) or ((nx ~= endX or ny ~= endY) and (isTileSolidForPathfinding(nx, ny) or (d.cost == 14 and (isTileSolidForPathfinding(currNode.x + d.dx, currNode.y) or isTileSolidForPathfinding(currNode.x, currNode.y + d.dy)))))
                if not isSolid then
                    local g = currNode.g + d.cost; local h = 10 * (math.abs(nx - endX) + math.abs(ny - endY)) + (14 - 20) * math.min(math.abs(nx - endX), math.abs(ny - endY)); local f = g + h
                    local existingNode = nodeGrid[nKey]
                    if not existingNode or g < existingNode.g then
                        if not existingNode then local newNode = {x=nx, y=ny, g=g, f=f, parent=currNode}; table.insert(open, newNode); nodeGrid[nKey] = newNode else existingNode.g = g; existingNode.f = f; existingNode.parent = currNode end
                    end
                end
            end
        end
    end
    return nil
end

local function aiMoveTo(endX, endY, moveSpeed, toggleKey)
    local startX, startY = math.floor(MovementState.Position.X / TILE_SIZE + 0.5), math.floor(MovementState.Position.Y / TILE_SIZE + 0.5)
    local path = isLineOfSightClear(startX, startY, endX, endY) and {Vector2.new(startX, startY), Vector2.new(endX, endY)} or getPath(startX, startY, endX, endY)
    if path then
        for i = 2, #path do
            if not toggles[toggleKey] then break end
            local nodePos = Vector3.new(path[i].X, path[i].Y, 0) * TILE_SIZE
            while toggles[toggleKey] do
                local currentPos = MovementState.Position
                local distToNode = (nodePos - currentPos).Magnitude
                if distToNode < 0.5 then MovementState.Position = nodePos; break end
                local dt = task.wait()
                local step = (nodePos - currentPos).Unit * moveSpeed * dt
                if step.Magnitude > distToNode then MovementState.Position = nodePos; break else MovementState.Position = currentPos + step; MovementState.OldPosition = MovementState.Position; MovementState.VelocityX, MovementState.VelocityY = 0, 0 end
            end
        end
        return true
    end
    return false
end

-- ==========================================
-- INJEKSI MODULE (CORE ENVIRONMENT)
-- ==========================================
local Core = {
    Players = Players, LocalPlayer = LocalPlayer, UIS = UIS, RS = RS, TS = TS,
    Managers = { MovementState = MovementState, PCM = PCM, WorldManager = WorldManager, ItemsManager = ItemsManager, InventoryModule = InventoryModule, WorldTiles = WorldTiles, TickManager = TickManager },
    Remotes = { PlayerFistRemote = PlayerFistRemote, PlayerPlaceRemote = PlayerPlaceRemote, PlayerTradeRemote = PlayerTradeRemote, PlayerMovementRemote = PlayerMovementRemote, CBRemote = CBRemote, SignalConstructor = SignalConstructor },
    Toggles = toggles, Inputs = inputInstances,
    UI = { createSection = createSection, createToggle = createToggle, createInputRow = createInputRow, createDropdown = createDropdown, createInventoryDropdown = createInventoryDropdown, createButton = createButton, createLabelDisplay = createLabelDisplay, popupOverlay = popupOverlay },
    Utils = { TILE_SIZE = TILE_SIZE, getGridFromScreen = getGridFromScreen, getBaseId = getBaseId, getHeldItem = getHeldItem },
    Pathfinding = { aiMoveTo = aiMoveTo, isOutOfBounds = isOutOfBounds, isItemTrapped = isItemTrapped, blacklistedItems = blacklistedItems, blacklistedSpots = blacklistedSpots },
    Pages = { Move = pageMove, Farm = pageFarm, World = pageWorld, Misc = pageMisc }
}

-- [!] GANTI URL DI BAWAH INI DENGAN RAW URL GITHUB REPOSITORY KAMU
local GITHUB_REPO = "https://raw.githubusercontent.com/XzNapi/NLIGHT/main/"

local function loadModule(name)
    local success, result = pcall(function() return loadstring(game:HttpGet(GITHUB_REPO .. name .. ".lua"))() end)
    if success and type(result) == "function" then task.spawn(function() result(Core) end) else warn("[NLight] Gagal memuat modul: " .. name) end
end

loadModule("Move")
loadModule("Farm")
loadModule("World")
loadModule("Misc")
