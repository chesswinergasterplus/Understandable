-- UnderstandAble Explorer
-- v1.0

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

if _G.USAWindow then
    pcall(function() _G.USAWindow:Destroy() end)
    _G.USAWindow = nil
end

local Window = Fluent:CreateWindow({
    Title = "UnderstandAble Explorer",
    SubTitle = "v1.0",
    TabWidth = 130,
    Size = UDim2.fromOffset(620, 480),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

_G.USAWindow = Window

local function getHUI()
    if typeof(gethui) == "function" then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    local plr = game:GetService("Players").LocalPlayer
    if plr then
        local pg = plr:FindFirstChild("PlayerGui") or plr:WaitForChild("PlayerGui", 5)
        if pg then return pg end
    end
    return nil
end

local HUI = getHUI()
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Tabs = {
    Explorer = Window:AddTab({ Title = "Explorer", Icon = "folder" }),
    Properties = Window:AddTab({ Title = "Properties", Icon = "sliders" }),
    Tools = Window:AddTab({ Title = "Tools", Icon = "wrench" }),
    Hidden = Window:AddTab({ Title = "Nil/Hidden", Icon = "eye-off" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local SelectedInstance = nil
local SelectionChangedEvent = Instance.new("BindableEvent")
local CurrentToggleKey = Enum.KeyCode.LeftControl

local function copyToClipboard(text)
    if setclipboard then
        pcall(setclipboard, text)
    elseif toclipboard then
        pcall(toclipboard, text)
    end
end

local function getFullPath(instance)
    if not instance then return "" end
    local path = instance.Name
    local parent = instance.Parent
    while parent and parent ~= game do
        local name = parent.Name
        if name:match("^[%a_][%w_]*$") then
            path = name .. "." .. path
        else
            path = '["' .. name:gsub('"', '\\"') .. '"].' .. path
        end
        parent = parent.Parent
    end
    
    if path:match("^Workspace%.") then
        path = "workspace" .. path:sub(10)
    else
        path = "game." .. path
    end
    return path
end

local function getClassDetails(instance)
    local prefix = "[O]"
    local color = Color3.fromRGB(200, 200, 200)
    
    if instance == workspace then
        prefix = "[WS]"
        color = Color3.fromRGB(255, 180, 0)
    elseif instance == game:GetService("Players") then
        prefix = "[PLR]"
        color = Color3.fromRGB(100, 255, 100)
    elseif instance == game:GetService("ReplicatedStorage") then
        prefix = "[RS]"
        color = Color3.fromRGB(255, 100, 255)
    elseif instance == game:GetService("ReplicatedFirst") then
        prefix = "[RF1]"
        color = Color3.fromRGB(255, 80, 180)
    elseif instance == game:GetService("StarterGui") then
        prefix = "[SG]"
        color = Color3.fromRGB(100, 200, 255)
    elseif instance == game:GetService("StarterPlayer") then
        prefix = "[SP]"
        color = Color3.fromRGB(120, 220, 180)
    elseif instance == game:GetService("Lighting") then
        prefix = "[LT]"
        color = Color3.fromRGB(255, 255, 120)
    elseif instance == game:GetService("SoundService") then
        prefix = "[SND]"
        color = Color3.fromRGB(150, 255, 200)
    elseif pcall(function() return game:GetService("CoreGui") end) and instance == game:GetService("CoreGui") then
        prefix = "[CG]"
        color = Color3.fromRGB(255, 100, 100)
    elseif instance == game:GetService("StarterPack") then
        prefix = "[SPK]"
        color = Color3.fromRGB(200, 150, 255)
    elseif instance:IsA("Folder") then
        prefix = "[F]"
        color = Color3.fromRGB(0, 180, 255)
    elseif instance:IsA("LocalScript") then
        prefix = "[LS]"
        color = Color3.fromRGB(255, 220, 0)
    elseif instance:IsA("ModuleScript") then
        prefix = "[MS]"
        color = Color3.fromRGB(150, 220, 50)
    elseif instance:IsA("Script") then
        prefix = "[S]"
        color = Color3.fromRGB(255, 60, 60)
    elseif instance:IsA("RemoteEvent") then
        prefix = "[RE]"
        color = Color3.fromRGB(255, 65, 65)
    elseif instance:IsA("RemoteFunction") then
        prefix = "[RF]"
        color = Color3.fromRGB(255, 140, 60)
    elseif instance:IsA("BindableEvent") then
        prefix = "[BE]"
        color = Color3.fromRGB(70, 210, 255)
    elseif instance:IsA("BasePart") then
        prefix = "[P]"
        color = Color3.fromRGB(255, 120, 0)
    elseif instance:IsA("GuiObject") or instance:IsA("ScreenGui") then
        prefix = "[G]"
        color = Color3.fromRGB(200, 100, 255)
    elseif instance:IsA("Tool") or instance:IsA("Accessory") then
        prefix = "[W]"
        color = Color3.fromRGB(255, 100, 180)
    elseif instance:IsA("Humanoid") then
        prefix = "[H]"
        color = Color3.fromRGB(255, 255, 255)
    elseif instance:IsA("ProximityPrompt") then
        prefix = "[PP]"
        color = Color3.fromRGB(255, 255, 90)
    elseif instance:IsA("ClickDetector") then
        prefix = "[CD]"
        color = Color3.fromRGB(210, 95, 255)
    end
    
    return prefix, color
end

local NodeStates = {}
local CurrentSearchQuery = ""
local RefreshExplorerTree = nil
local PickerActive = false
local PickerConnection = nil
local SelectionBoxInstance = nil

local container = Tabs.Explorer.Container

local ExplorerFrame = Instance.new("Frame")
ExplorerFrame.Size = UDim2.new(1, 0, 0, 390)
ExplorerFrame.BackgroundTransparency = 1
ExplorerFrame.BorderSizePixel = 0
ExplorerFrame.Parent = container

local PickerBtn = Instance.new("TextButton")
PickerBtn.Size = UDim2.new(0, 70, 0, 24)
PickerBtn.Position = UDim2.new(1, -75, 0, 3)
PickerBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
PickerBtn.Text = "3D Pick"
PickerBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
PickerBtn.Font = Enum.Font.GothamBold
PickerBtn.TextSize = 10
PickerBtn.Parent = ExplorerFrame

local pickerCorner = Instance.new("UICorner")
pickerCorner.CornerRadius = UDim.new(0, 4)
pickerCorner.Parent = PickerBtn

local SearchBar = Instance.new("TextBox")
SearchBar.Size = UDim2.new(1, -85, 0, 30)
SearchBar.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
SearchBar.TextColor3 = Color3.fromRGB(240, 240, 245)
SearchBar.PlaceholderText = "Search..."
SearchBar.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
SearchBar.Font = Enum.Font.GothamMedium
SearchBar.TextSize = 12
SearchBar.Text = ""
SearchBar.Parent = ExplorerFrame

local searchCorner = Instance.new("UICorner")
searchCorner.CornerRadius = UDim.new(0, 5)
searchCorner.Parent = SearchBar

local TreeScroll = Instance.new("ScrollingFrame")
TreeScroll.Size = UDim2.new(1, 0, 0, 230)
TreeScroll.Position = UDim2.new(0, 0, 0, 38)
TreeScroll.BackgroundTransparency = 1
TreeScroll.BorderSizePixel = 0
TreeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
TreeScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
TreeScroll.Parent = ExplorerFrame

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 1)
listLayout.Parent = TreeScroll

local ActionPanel = Instance.new("Frame")
ActionPanel.Size = UDim2.new(1, 0, 0, 70)
ActionPanel.Position = UDim2.new(0, 0, 0, 275)
ActionPanel.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
ActionPanel.Parent = ExplorerFrame

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 6)
panelCorner.Parent = ActionPanel

local SelectedLabel = Instance.new("TextLabel")
SelectedLabel.Size = UDim2.new(1, -20, 0, 20)
SelectedLabel.Position = UDim2.new(0, 10, 0, 5)
SelectedLabel.BackgroundTransparency = 1
SelectedLabel.Text = "Target: None"
SelectedLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
SelectedLabel.Font = Enum.Font.GothamBold
SelectedLabel.TextSize = 11
SelectedLabel.TextXAlignment = Enum.TextXAlignment.Left
SelectedLabel.Parent = ActionPanel

local CodePanel = Instance.new("Frame")
CodePanel.Size = UDim2.new(1, 0, 0, 200)
CodePanel.Position = UDim2.new(0, 0, 0, 362)
CodePanel.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
CodePanel.Visible = false
CodePanel.Parent = ExplorerFrame

local codePanelCorner = Instance.new("UICorner")
codePanelCorner.CornerRadius = UDim.new(0, 6)
codePanelCorner.Parent = CodePanel

local CodeHeader = Instance.new("Frame")
CodeHeader.Size = UDim2.new(1, 0, 0, 26)
CodeHeader.BackgroundTransparency = 1
CodeHeader.Parent = CodePanel

local CodeTitle = Instance.new("TextLabel")
CodeTitle.Size = UDim2.new(0.6, -10, 1, 0)
CodeTitle.Position = UDim2.new(0, 10, 0, 0)
CodeTitle.BackgroundTransparency = 1
CodeTitle.Text = ""
CodeTitle.TextColor3 = Color3.fromRGB(200, 200, 210)
CodeTitle.Font = Enum.Font.GothamBold
CodeTitle.TextSize = 11
CodeTitle.TextXAlignment = Enum.TextXAlignment.Left
CodeTitle.Parent = CodeHeader

local CopyCodeBtn = Instance.new("TextButton")
CopyCodeBtn.Size = UDim2.new(0, 70, 0, 20)
CopyCodeBtn.Position = UDim2.new(1, -110, 0.5, -10)
CopyCodeBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
CopyCodeBtn.Text = "Copy"
CopyCodeBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
CopyCodeBtn.Font = Enum.Font.GothamMedium
CopyCodeBtn.TextSize = 10
CopyCodeBtn.Parent = CodeHeader

local copyCorner = Instance.new("UICorner")
copyCorner.CornerRadius = UDim.new(0, 4)
copyCorner.Parent = CopyCodeBtn

CopyCodeBtn.MouseEnter:Connect(function() CopyCodeBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55) end)
CopyCodeBtn.MouseLeave:Connect(function() CopyCodeBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35) end)

local CloseCodeBtn = Instance.new("TextButton")
CloseCodeBtn.Size = UDim2.new(0, 24, 0, 20)
CloseCodeBtn.Position = UDim2.new(1, -30, 0.5, -10)
CloseCodeBtn.BackgroundTransparency = 1
CloseCodeBtn.Text = "×"
CloseCodeBtn.TextColor3 = Color3.fromRGB(150, 150, 160)
CloseCodeBtn.Font = Enum.Font.GothamBold
CloseCodeBtn.TextSize = 16
CloseCodeBtn.Parent = CodeHeader

CloseCodeBtn.MouseEnter:Connect(function() CloseCodeBtn.TextColor3 = Color3.fromRGB(255, 75, 75) end)
CloseCodeBtn.MouseLeave:Connect(function() CloseCodeBtn.TextColor3 = Color3.fromRGB(150, 150, 160) end)

local CodeScroll = Instance.new("ScrollingFrame")
CodeScroll.Size = UDim2.new(1, -8, 1, -32)
CodeScroll.Position = UDim2.new(0, 4, 0, 28)
CodeScroll.BackgroundTransparency = 1
CodeScroll.BorderSizePixel = 0
CodeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
CodeScroll.AutomaticCanvasSize = Enum.AutomaticSize.XY
CodeScroll.Parent = CodePanel

local CodeBox = Instance.new("TextBox")
CodeBox.Size = UDim2.new(1, 0, 1, 0)
CodeBox.BackgroundTransparency = 1
CodeBox.Text = ""
CodeBox.TextColor3 = Color3.fromRGB(210, 210, 220)
CodeBox.ClearTextOnFocus = false
CodeBox.TextEditable = false
CodeBox.MultiLine = true
CodeBox.Font = Enum.Font.Code
CodeBox.TextSize = 11
CodeBox.TextXAlignment = Enum.TextXAlignment.Left
CodeBox.TextYAlignment = Enum.TextYAlignment.Top
CodeBox.Parent = CodeScroll

local currentCodeViewTarget = nil

local function openCodeViewer(instance)
    currentCodeViewTarget = instance
    CodeTitle.Text = instance.ClassName .. ": " .. instance.Name
    CodeBox.Text = "-- Decompiling..."
    CodePanel.Visible = true
    
    local target = instance
    
    task.spawn(function()
        local src = ""
        if decompile then
            local ok, result = pcall(decompile, instance)
            src = ok and result or "-- decompile() failed"
        else
            local ok, result = pcall(function() return instance.Source end)
            src = (ok and result ~= "") and result or "-- decompile() not available"
        end
        
        if currentCodeViewTarget == target then
            CodeBox.Text = src
        end
    end)
end

CloseCodeBtn.MouseButton1Click:Connect(function()
    CodePanel.Visible = false
end)

CopyCodeBtn.MouseButton1Click:Connect(function()
    copyToClipboard(CodeBox.Text)
end)

local buttonContainer = Instance.new("Frame")
buttonContainer.Size = UDim2.new(1, 0, 0, 36)
buttonContainer.Position = UDim2.new(0, 0, 0, 28)
buttonContainer.BackgroundTransparency = 1
buttonContainer.Parent = ActionPanel

local function createActionButton(name, pos, xSize, onClick)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(xSize, -6, 0, 26)
    btn.Position = pos
    btn.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(240, 240, 245)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 10
    btn.Parent = buttonContainer
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn
    
    btn.MouseEnter:Connect(function()
        btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    end)
    btn.MouseLeave:Connect(function()
        btn.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
    end)
    
    btn.MouseButton1Click:Connect(onClick)
    return btn
end

createActionButton("Name", UDim2.new(0, 5, 0, 5), 0.33, function()
    if SelectedInstance then copyToClipboard(SelectedInstance.Name) end
end)

createActionButton("Path", UDim2.new(0.33, 5, 0, 5), 0.33, function()
    if SelectedInstance then copyToClipboard(getFullPath(SelectedInstance)) end
end)

createActionButton("Children", UDim2.new(0.66, 5, 0, 5), 0.34, function()
    if SelectedInstance then
        local names = {}
        for _, c in ipairs(SelectedInstance:GetChildren()) do
            table.insert(names, c.Name)
        end
        if #names > 0 then
            copyToClipboard(table.concat(names, "\n"))
        end
    end
end)

local rowPool = {}

local function getPooledRow()
    local row = table.remove(rowPool)
    if row then
        row.Visible = true
        for _, ch in ipairs(row:GetChildren()) do ch:Destroy() end
        return row
    end
    local r = Instance.new("Frame")
    r.Size = UDim2.new(1, 0, 0, 22)
    r.BackgroundTransparency = 1
    return r
end

local function releaseAllRows()
    for _, obj in ipairs(TreeScroll:GetChildren()) do
        if obj:IsA("Frame") then
            obj.Visible = false
            obj.Parent = nil
            table.insert(rowPool, obj)
        end
    end
end

local function renderNode(instance, depth, layoutOrder)
    local row = getPooledRow()
    row.LayoutOrder = layoutOrder
    row.Parent = TreeScroll
    
    local indent = Instance.new("Frame")
    indent.Size = UDim2.new(0, depth * 14, 1, 0)
    indent.BackgroundTransparency = 1
    indent.Parent = row
    
    local hasChildren = #instance:GetChildren() > 0
    
    local expandBtn = Instance.new("TextButton")
    expandBtn.Size = UDim2.new(0, 14, 0, 14)
    expandBtn.Position = UDim2.new(0, depth * 14 + 2, 0.5, -7)
    expandBtn.BackgroundTransparency = 1
    expandBtn.Text = hasChildren and ((NodeStates[instance] and NodeStates[instance].expanded) and "▼" or "▶") or ""
    expandBtn.TextColor3 = Color3.fromRGB(150, 150, 160)
    expandBtn.Font = Enum.Font.GothamMedium
    expandBtn.TextSize = 9
    expandBtn.Parent = row
    
    if hasChildren then
        expandBtn.MouseButton1Click:Connect(function()
            if not NodeStates[instance] then NodeStates[instance] = {} end
            NodeStates[instance].expanded = not (NodeStates[instance].expanded or false)
            RefreshExplorerTree()
        end)
    end
    
    local prefixText, prefixColor = getClassDetails(instance)
    
    local tagLabel = Instance.new("TextLabel")
    tagLabel.Size = UDim2.new(0, 36, 0, 16)
    tagLabel.Position = UDim2.new(0, depth * 14 + 18, 0.5, -8)
    tagLabel.BackgroundTransparency = 1
    tagLabel.Text = prefixText
    tagLabel.TextColor3 = prefixColor
    tagLabel.Font = Enum.Font.GothamBold
    tagLabel.TextSize = 10
    tagLabel.Parent = row
    
    local nameBtn = Instance.new("TextButton")
    nameBtn.Size = UDim2.new(1, -(depth * 14 + 58), 1, 0)
    nameBtn.Position = UDim2.new(0, depth * 14 + 56, 0, 0)
    nameBtn.BackgroundTransparency = 1
    nameBtn.Text = instance.Name
    nameBtn.TextColor3 = (SelectedInstance == instance) and Color3.fromRGB(0, 210, 255) or Color3.fromRGB(240, 240, 245)
    nameBtn.Font = Enum.Font.GothamMedium
    nameBtn.TextSize = 12
    nameBtn.TextXAlignment = Enum.TextXAlignment.Left
    nameBtn.Parent = row
    
    local lastClickTime = 0
    local lastClickTarget = nil
    
    nameBtn.MouseButton1Click:Connect(function()
        local now = os.clock()
        local isScript = instance:IsA("LocalScript") or instance:IsA("ModuleScript") or instance:IsA("Script")
        if isScript and lastClickTarget == instance and (now - lastClickTime) < 0.35 then
            openCodeViewer(instance)
        end
        lastClickTime = now
        lastClickTarget = instance
        
        SelectedInstance = instance
        SelectedLabel.Text = "Target: " .. instance.Name
        SelectionChangedEvent:Fire(instance)
        RefreshExplorerTree()
    end)
end

local function drawRecursiveTree(parent, depth, count)
    local children = parent:GetChildren()
    table.sort(children, function(a, b) return a.Name:lower() < b.Name:lower() end)
    
    for _, child in ipairs(children) do
        count = count + 1
        renderNode(child, depth, count)
        local state = NodeStates[child]
        if state and state.expanded then
            count = drawRecursiveTree(child, depth + 1, count)
        end
    end
    return count
end

local function drawSearchFlatList(root, query)
    local matches = {}
    local function recurse(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if #matches >= 150 then break end
            if string.find(child.Name:lower(), query, 1, true) or string.find(child.ClassName:lower(), query, 1, true) then
                table.insert(matches, child)
            end
            recurse(child)
        end
    end
    recurse(root)
    for i, m in ipairs(matches) do
        renderNode(m, 0, i)
    end
end

RefreshExplorerTree = function()
    releaseAllRows()
    
    if CurrentSearchQuery == "" then
        local count = 0
        local services = {
            workspace,
            game:GetService("Players"),
            game:GetService("ReplicatedStorage"),
            game:GetService("ReplicatedFirst"),
            game:GetService("StarterGui"),
            game:GetService("StarterPlayer"),
            game:GetService("Lighting"),
            game:GetService("SoundService")
        }
        
        pcall(function()
            local cg = game:GetService("CoreGui")
            if cg then table.insert(services, cg) end
        end)
        pcall(function()
            local sp = game:GetService("StarterPack")
            if sp then table.insert(services, sp) end
        end)
        
        for _, svc in ipairs(services) do
            if svc and typeof(svc) == "Instance" then
                count = count + 1
                renderNode(svc, 0, count)
                local st = NodeStates[svc]
                if st and st.expanded then
                    count = drawRecursiveTree(svc, 1, count)
                end
            end
        end
    else
        drawSearchFlatList(game, CurrentSearchQuery)
    end
end

SearchBar:GetPropertyChangedSignal("Text"):Connect(function()
    CurrentSearchQuery = SearchBar.Text:lower()
    RefreshExplorerTree()
end)

local function togglePicker()
    PickerActive = not PickerActive
    
    if PickerActive then
        PickerBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 80)
        PickerBtn.Text = "Pick..."
        
        local mouse = LocalPlayer:GetMouse()
        
        SelectionBoxInstance = Instance.new("SelectionBox")
        SelectionBoxInstance.LineThickness = 0.05
        SelectionBoxInstance.Color3 = Color3.fromRGB(0, 255, 255)
        SelectionBoxInstance.Parent = HUI or game:GetService("CoreGui")
        
        PickerConnection = RunService.RenderStepped:Connect(function()
            local target = mouse.Target
            if target and target:IsA("BasePart") then
                SelectionBoxInstance.Adornee = target
            else
                SelectionBoxInstance.Adornee = nil
            end
        end)
        
        local clickConn
        clickConn = mouse.Button1Down:Connect(function()
            local target = mouse.Target
            if target then
                SelectedInstance = target
                SelectedLabel.Text = "Target: " .. target.Name
                SelectionChangedEvent:Fire(target)
                
                local parent = target.Parent
                while parent and parent ~= game do
                    if not NodeStates[parent] then NodeStates[parent] = {} end
                    NodeStates[parent].expanded = true
                    parent = parent.Parent
                end
                
                RefreshExplorerTree()
                
                PickerActive = false
                PickerBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
                PickerBtn.Text = "3D Pick"
                if PickerConnection then PickerConnection:Disconnect() end
                if SelectionBoxInstance then SelectionBoxInstance:Destroy() end
                clickConn:Disconnect()
            end
        end)
    else
        PickerBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        PickerBtn.Text = "3D Pick"
        if PickerConnection then PickerConnection:Disconnect() end
        if SelectionBoxInstance then SelectionBoxInstance:Destroy() end
    end
end

PickerBtn.MouseButton1Click:Connect(togglePicker)

RefreshExplorerTree()

local propContainer = Tabs.Properties.Container

local PropertiesFrame = Instance.new("Frame")
PropertiesFrame.Size = UDim2.new(1, 0, 1, 0)
PropertiesFrame.BackgroundTransparency = 1
PropertiesFrame.BorderSizePixel = 0
PropertiesFrame.Parent = propContainer

local PropertiesScroll = Instance.new("ScrollingFrame")
PropertiesScroll.Size = UDim2.new(1, 0, 1, 0)
PropertiesScroll.BackgroundTransparency = 1
PropertiesScroll.BorderSizePixel = 0
PropertiesScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
PropertiesScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
PropertiesScroll.Parent = PropertiesFrame

local propListLayout = Instance.new("UIListLayout")
propListLayout.SortOrder = Enum.SortOrder.LayoutOrder
propListLayout.Padding = UDim.new(0, 4)
propListLayout.Parent = PropertiesScroll

local function clearProperties()
    for _, child in ipairs(PropertiesScroll:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
end

local function createCategoryHeader(text)
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -10, 0, 22)
    header.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
    header.BorderSizePixel = 0
    header.Text = "  " .. text
    header.TextColor3 = Color3.fromRGB(200, 200, 210)
    header.Font = Enum.Font.GothamBold
    header.TextSize = 11
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = PropertiesScroll
    
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 4)
    headerCorner.Parent = header
    
    return header
end

local function createPropertyRow(propName, currentValue, valueType, onChanged)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -10, 0, 34)
    row.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
    row.BorderSizePixel = 0
    row.Parent = PropertiesScroll
    
    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 4)
    rowCorner.Parent = row
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0.35, -10, 1, 0)
    nameLabel.Position = UDim2.new(0, 10, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = propName
    nameLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 10
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = row
    
    if valueType == "boolean" then
        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Size = UDim2.new(0, 50, 0, 24)
        toggleBtn.Position = UDim2.new(0.35, 10, 0.5, -12)
        toggleBtn.BackgroundColor3 = currentValue and Color3.fromRGB(60, 180, 80) or Color3.fromRGB(180, 60, 60)
        toggleBtn.Text = currentValue and "True" or "False"
        toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.TextSize = 9
        toggleBtn.Parent = row
        
        local toggleCorner = Instance.new("UICorner")
        toggleCorner.CornerRadius = UDim.new(0, 4)
        toggleCorner.Parent = toggleBtn
        
        toggleBtn.MouseButton1Click:Connect(function()
            local newValue = not currentValue
            currentValue = newValue
            toggleBtn.Text = newValue and "True" or "False"
            toggleBtn.BackgroundColor3 = newValue and Color3.fromRGB(60, 180, 80) or Color3.fromRGB(180, 60, 60)
            onChanged(newValue)
        end)
    else
        local valueBox = Instance.new("TextBox")
        valueBox.Size = UDim2.new(0.65, -20, 0, 24)
        valueBox.Position = UDim2.new(0.35, 10, 0.5, -12)
        valueBox.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
        valueBox.TextColor3 = Color3.fromRGB(240, 240, 245)
        valueBox.Font = Enum.Font.GothamMedium
        valueBox.TextSize = 10
        valueBox.Text = tostring(currentValue)
        valueBox.ClearTextOnFocus = false
        valueBox.Parent = row
        
        local boxCorner = Instance.new("UICorner")
        boxCorner.CornerRadius = UDim.new(0, 3)
        boxCorner.Parent = valueBox
        
        valueBox.FocusLost:Connect(function()
            local newText = valueBox.Text
            local newValue = newText
            
            if valueType == "number" then
                newValue = tonumber(newText)
                if not newValue then
                    valueBox.Text = tostring(currentValue)
                    return
                end
            elseif valueType == "Vector3" then
                local parts = {}
                for num in string.gmatch(newText, "[^,]+") do
                    local n = tonumber(num)
                    if n then table.insert(parts, n) end
                end
                if #parts == 3 then
                    newValue = Vector3.new(parts[1], parts[2], parts[3])
                else
                    valueBox.Text = tostring(currentValue)
                    return
                end
            elseif valueType == "Color3" then
                local parts = {}
                for num in string.gmatch(newText, "[^,]+") do
                    local n = tonumber(num)
                    if n then table.insert(parts, n) end
                end
                if #parts == 3 then
                    newValue = Color3.fromRGB(parts[1], parts[2], parts[3])
                else
                    valueBox.Text = tostring(currentValue)
                    return
                end
            elseif valueType == "CFrame" then
                valueBox.Text = tostring(currentValue)
                return
            end
            
            onChanged(newValue)
        end)
    end
    
    return row
end

local propertyGroups = {
    Transform = {"Position", "CFrame", "Size", "Orientation", "Rotation"},
    Appearance = {"Color", "BrickColor", "Transparency", "Material", "Reflectance", "TextColor3", "BackgroundColor3", "BackgroundTransparency"},
    State = {"Anchored", "CanCollide", "Enabled", "Visible", "Locked", "Archivable"},
    Data = {"Name", "Parent", "Value", "Text", "Brightness", "Volume", "PlaybackSpeed"}
}

local function refreshProperties(instance)
    clearProperties()
    
    if not instance then
        local noSelectionLabel = Instance.new("TextLabel")
        noSelectionLabel.Size = UDim2.new(1, 0, 0, 50)
        noSelectionLabel.BackgroundTransparency = 1
        noSelectionLabel.Text = "No instance selected"
        noSelectionLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
        noSelectionLabel.Font = Enum.Font.GothamMedium
        noSelectionLabel.TextSize = 12
        noSelectionLabel.Parent = PropertiesScroll
        return
    end
    
    local headerLabel = Instance.new("TextLabel")
    headerLabel.Size = UDim2.new(1, -10, 0, 26)
    headerLabel.BackgroundTransparency = 1
    headerLabel.Text = instance.ClassName .. ": " .. instance.Name
    headerLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
    headerLabel.Font = Enum.Font.GothamBold
    headerLabel.TextSize = 13
    headerLabel.TextXAlignment = Enum.TextXAlignment.Left
    headerLabel.Parent = PropertiesScroll
    
    for groupName, propList in pairs(propertyGroups) do
        local groupHasProps = false
        local tempProps = {}
        
        for _, propName in ipairs(propList) do
            local success, currentValue = pcall(function()
                return instance[propName]
            end)
            
            if success and currentValue ~= nil then
                groupHasProps = true
                table.insert(tempProps, {propName, currentValue, typeof(currentValue)})
            end
        end
        
        if groupHasProps then
            createCategoryHeader(groupName)
            for _, propData in ipairs(tempProps) do
                local propName, currentValue, valueType = propData[1], propData[2], propData[3]
                createPropertyRow(propName, currentValue, valueType, function(newValue)
                    pcall(function()
                        instance[propName] = newValue
                    end)
                end)
            end
        end
    end
    
    local attributes = {}
    pcall(function()
        attributes = instance:GetAttributes()
    end)
    
    if next(attributes) then
        createCategoryHeader("Attributes")
        
        for attrName, attrValue in pairs(attributes) do
            local valueType = typeof(attrValue)
            createPropertyRow(attrName, attrValue, valueType, function(newValue)
                pcall(function()
                    instance:SetAttribute(attrName, newValue)
                end)
            end)
        end
    end
end

SelectionChangedEvent.Event:Connect(function(instance)
    refreshProperties(instance)
end)

refreshProperties(nil)

local toolsContainer = Tabs.Tools.Container

local ToolsFrame = Instance.new("Frame")
ToolsFrame.Size = UDim2.new(1, 0, 1, 0)
ToolsFrame.BackgroundTransparency = 1
ToolsFrame.BorderSizePixel = 0
ToolsFrame.Parent = toolsContainer

local ToolsScroll = Instance.new("ScrollingFrame")
ToolsScroll.Size = UDim2.new(1, 0, 1, 0)
ToolsScroll.BackgroundTransparency = 1
ToolsScroll.BorderSizePixel = 0
ToolsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
ToolsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
ToolsScroll.Parent = ToolsFrame

local toolsListLayout = Instance.new("UIListLayout")
toolsListLayout.SortOrder = Enum.SortOrder.LayoutOrder
toolsListLayout.Padding = UDim.new(0, 6)
toolsListLayout.Parent = ToolsScroll

local function createCompactTool(title, buttons)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 32)
    frame.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
    frame.BorderSizePixel = 0
    frame.Parent = ToolsScroll
    
    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 4)
    frameCorner.Parent = frame
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0.3, -10, 1, 0)
    titleLabel.Position = UDim2.new(0, 10, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 10
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = frame
    
    local buttonWidth = (0.7 / #buttons)
    for i, btnData in ipairs(buttons) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(buttonWidth, -8, 0, 24)
        btn.Position = UDim2.new(0.3 + (i-1) * buttonWidth, 4, 0.5, -12)
        btn.BackgroundColor3 = Color3.fromRGB(50, 120, 200)
        btn.Text = btnData.text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 9
        btn.Parent = frame
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 4)
        btnCorner.Parent = btn
        
        btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(70, 140, 220) end)
        btn.MouseLeave:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(50, 120, 200) end)
        btn.MouseButton1Click:Connect(btnData.onClick)
    end
    
    return frame
end

local remoteFrame = Instance.new("Frame")
remoteFrame.Size = UDim2.new(1, -10, 0, 70)
remoteFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
remoteFrame.BorderSizePixel = 0
remoteFrame.Parent = ToolsScroll

local remoteCorner = Instance.new("UICorner")
remoteCorner.CornerRadius = UDim.new(0, 4)
remoteCorner.Parent = remoteFrame

local remoteTitle = Instance.new("TextLabel")
remoteTitle.Size = UDim2.new(1, -20, 0, 18)
remoteTitle.Position = UDim2.new(0, 10, 0, 4)
remoteTitle.BackgroundTransparency = 1
remoteTitle.Text = "Remote Injector"
remoteTitle.TextColor3 = Color3.fromRGB(240, 240, 245)
remoteTitle.Font = Enum.Font.GothamBold
remoteTitle.TextSize = 11
remoteTitle.TextXAlignment = Enum.TextXAlignment.Left
remoteTitle.Parent = remoteFrame

local argsBox = Instance.new("TextBox")
argsBox.Size = UDim2.new(1, -20, 0, 24)
argsBox.Position = UDim2.new(0, 10, 0, 26)
argsBox.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
argsBox.TextColor3 = Color3.fromRGB(240, 240, 245)
argsBox.PlaceholderText = "args..."
argsBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
argsBox.Font = Enum.Font.GothamMedium
argsBox.TextSize = 10
argsBox.Text = ""
argsBox.ClearTextOnFocus = false
argsBox.Parent = remoteFrame

local argsCorner = Instance.new("UICorner")
argsCorner.CornerRadius = UDim.new(0, 3)
argsCorner.Parent = argsBox

local fireBtn = Instance.new("TextButton")
fireBtn.Size = UDim2.new(0.48, -7, 0, 20)
fireBtn.Position = UDim2.new(0, 10, 1, -24)
fireBtn.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
fireBtn.Text = "Fire"
fireBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
fireBtn.Font = Enum.Font.GothamBold
fireBtn.TextSize = 10
fireBtn.Parent = remoteFrame

local fireBtnCorner = Instance.new("UICorner")
fireBtnCorner.CornerRadius = UDim.new(0, 4)
fireBtnCorner.Parent = fireBtn

local genBtn = Instance.new("TextButton")
genBtn.Size = UDim2.new(0.48, -7, 0, 20)
genBtn.Position = UDim2.new(0.52, 7, 1, -24)
genBtn.BackgroundColor3 = Color3.fromRGB(80, 180, 255)
genBtn.Text = "Gen Script"
genBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
genBtn.Font = Enum.Font.GothamBold
genBtn.TextSize = 10
genBtn.Parent = remoteFrame

local genBtnCorner = Instance.new("UICorner")
genBtnCorner.CornerRadius = UDim.new(0, 4)
genBtnCorner.Parent = genBtn

fireBtn.MouseButton1Click:Connect(function()
    if not SelectedInstance then
        Fluent:Notify({Title = "Tools", Content = "No instance selected", Duration = 3})
        return
    end
    
    local success, err = pcall(function()
        local args = {}
        if argsBox.Text ~= "" then
            local loadFunc = loadstring("return {" .. argsBox.Text .. "}")
            if loadFunc then
                args = loadFunc()
            end
        end
        
        if SelectedInstance:IsA("RemoteEvent") then
            SelectedInstance:FireServer(unpack(args))
            Fluent:Notify({Title = "Remote", Content = "Fired", Duration = 2})
        elseif SelectedInstance:IsA("RemoteFunction") then
            SelectedInstance:InvokeServer(unpack(args))
            Fluent:Notify({Title = "Remote", Content = "Invoked", Duration = 2})
        else
            Fluent:Notify({Title = "Remote", Content = "Not a Remote", Duration = 3})
        end
    end)
    
    if not success then
        Fluent:Notify({Title = "Remote", Content = "Error", Duration = 3})
    end
end)

genBtn.MouseButton1Click:Connect(function()
    if not SelectedInstance then
        Fluent:Notify({Title = "Tools", Content = "No instance selected", Duration = 3})
        return
    end
    
    if SelectedInstance:IsA("RemoteEvent") or SelectedInstance:IsA("RemoteFunction") then
        local path = getFullPath(SelectedInstance)
        local method = SelectedInstance:IsA("RemoteEvent") and "FireServer" or "InvokeServer"
        local argsText = argsBox.Text ~= "" and argsBox.Text or ""
        
        local script = string.format([[local args = {%s}
%s:%s(unpack(args))]], argsText, path, method)
        
        copyToClipboard(script)
        Fluent:Notify({Title = "Remote", Content = "Copied to clipboard", Duration = 2})
    else
        Fluent:Notify({Title = "Remote", Content = "Not a Remote", Duration = 3})
    end
end)

createCompactTool("Teleport", {
    {text = "To Object", onClick = function()
        if not SelectedInstance or not SelectedInstance:IsA("BasePart") then
            Fluent:Notify({Title = "Teleport", Content = "Select a BasePart", Duration = 3})
            return
        end
        
        pcall(function()
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                char.HumanoidRootPart.CFrame = SelectedInstance.CFrame + Vector3.new(0, 5, 0)
                Fluent:Notify({Title = "Teleport", Content = "Done", Duration = 2})
            end
        end)
    end},
    {text = "To Me", onClick = function()
        if not SelectedInstance or not SelectedInstance:IsA("BasePart") then
            Fluent:Notify({Title = "Teleport", Content = "Select a BasePart", Duration = 3})
            return
        end
        
        pcall(function()
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                SelectedInstance.CFrame = char.HumanoidRootPart.CFrame + char.HumanoidRootPart.CFrame.LookVector * 5
                Fluent:Notify({Title = "Teleport", Content = "Done", Duration = 2})
            end
        end)
    end}
})

createCompactTool("Toggle", {
    {text = "Transparency", onClick = function()
        if not SelectedInstance or not SelectedInstance:IsA("BasePart") then
            Fluent:Notify({Title = "Toggle", Content = "Select a BasePart", Duration = 3})
            return
        end
        
        pcall(function()
            SelectedInstance.Transparency = SelectedInstance.Transparency == 0 and 1 or 0
        end)
    end},
    {text = "CanCollide", onClick = function()
        if not SelectedInstance or not SelectedInstance:IsA("BasePart") then
            Fluent:Notify({Title = "Toggle", Content = "Select a BasePart", Duration = 3})
            return
        end
        
        pcall(function()
            SelectedInstance.CanCollide = not SelectedInstance.CanCollide
        end)
    end}
})

createCompactTool("Actions", {
    {text = "Destroy", onClick = function()
        if not SelectedInstance then
            Fluent:Notify({Title = "Actions", Content = "No instance selected", Duration = 3})
            return
        end
        
        pcall(function()
            local name = SelectedInstance.Name
            SelectedInstance:Destroy()
            SelectedInstance = nil
            Fluent:Notify({Title = "Actions", Content = name .. " destroyed", Duration = 2})
        end)
    end},
    {text = "Save", onClick = function()
        local target = SelectedInstance or game
        
        if not saveinstance then
            Fluent:Notify({Title = "Actions", Content = "saveinstance() not supported", Duration = 3})
            return
        end
        
        local success, err = pcall(function()
            saveinstance(target)
        end)
        
        if success then
            Fluent:Notify({Title = "Actions", Content = "Saved", Duration = 2})
        else
            Fluent:Notify({Title = "Actions", Content = "Failed", Duration = 3})
        end
    end},
    {text = "Decompile", onClick = function()
        if not SelectedInstance then
            Fluent:Notify({Title = "Actions", Content = "No instance selected", Duration = 3})
            return
        end
        
        if not (SelectedInstance:IsA("LocalScript") or SelectedInstance:IsA("ModuleScript") or SelectedInstance:IsA("Script")) then
            Fluent:Notify({Title = "Actions", Content = "Not a script", Duration = 3})
            return
        end
        
        local success, result = pcall(function()
            if decompile then
                return decompile(SelectedInstance)
            else
                return SelectedInstance.Source
            end
        end)
        
        if success and result then
            copyToClipboard(result)
            Fluent:Notify({Title = "Actions", Content = "Copied to clipboard", Duration = 2})
        else
            Fluent:Notify({Title = "Actions", Content = "Failed", Duration = 3})
        end
    end}
})

local hiddenContainer = Tabs.Hidden.Container

local HiddenFrame = Instance.new("Frame")
HiddenFrame.Size = UDim2.new(1, 0, 1, 0)
HiddenFrame.BackgroundTransparency = 1
HiddenFrame.BorderSizePixel = 0
HiddenFrame.Parent = hiddenContainer

local ModeToggle = Instance.new("Frame")
ModeToggle.Size = UDim2.new(1, -10, 0, 32)
ModeToggle.Position = UDim2.new(0, 5, 0, 5)
ModeToggle.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
ModeToggle.BorderSizePixel = 0
ModeToggle.Parent = HiddenFrame

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 4)
toggleCorner.Parent = ModeToggle

local nilBtn = Instance.new("TextButton")
nilBtn.Size = UDim2.new(0.48, -5, 0, 26)
nilBtn.Position = UDim2.new(0, 5, 0.5, -13)
nilBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
nilBtn.Text = "Nil Instances"
nilBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
nilBtn.Font = Enum.Font.GothamBold
nilBtn.TextSize = 10
nilBtn.Parent = ModeToggle

local nilCorner = Instance.new("UICorner")
nilCorner.CornerRadius = UDim.new(0, 4)
nilCorner.Parent = nilBtn

local modBtn = Instance.new("TextButton")
modBtn.Size = UDim2.new(0.48, -5, 0, 26)
modBtn.Position = UDim2.new(0.52, 5, 0.5, -13)
modBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
modBtn.Text = "Loaded Modules"
modBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
modBtn.Font = Enum.Font.GothamBold
modBtn.TextSize = 10
modBtn.Parent = ModeToggle

local modCorner = Instance.new("UICorner")
modCorner.CornerRadius = UDim.new(0, 4)
modCorner.Parent = modBtn

local HiddenScroll = Instance.new("ScrollingFrame")
HiddenScroll.Size = UDim2.new(1, -10, 1, -47)
HiddenScroll.Position = UDim2.new(0, 5, 0, 42)
HiddenScroll.BackgroundTransparency = 1
HiddenScroll.BorderSizePixel = 0
HiddenScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
HiddenScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
HiddenScroll.Parent = HiddenFrame

local hiddenListLayout = Instance.new("UIListLayout")
hiddenListLayout.SortOrder = Enum.SortOrder.LayoutOrder
hiddenListLayout.Padding = UDim.new(0, 3)
hiddenListLayout.Parent = HiddenScroll

local currentMode = "nil"

local function clearHiddenList()
    for _, child in ipairs(HiddenScroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
end

local function createHiddenItem(instance)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 26)
    row.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
    row.BorderSizePixel = 0
    row.Parent = HiddenScroll
    
    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 4)
    rowCorner.Parent = row
    
    local prefixText, prefixColor = getClassDetails(instance)
    
    local tagLabel = Instance.new("TextLabel")
    tagLabel.Size = UDim2.new(0, 40, 1, 0)
    tagLabel.Position = UDim2.new(0, 5, 0, 0)
    tagLabel.BackgroundTransparency = 1
    tagLabel.Text = prefixText
    tagLabel.TextColor3 = prefixColor
    tagLabel.Font = Enum.Font.GothamBold
    tagLabel.TextSize = 10
    tagLabel.Parent = row
    
    local nameBtn = Instance.new("TextButton")
    nameBtn.Size = UDim2.new(1, -50, 1, 0)
    nameBtn.Position = UDim2.new(0, 45, 0, 0)
    nameBtn.BackgroundTransparency = 1
    nameBtn.Text = instance.Name
    nameBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
    nameBtn.Font = Enum.Font.GothamMedium
    nameBtn.TextSize = 11
    nameBtn.TextXAlignment = Enum.TextXAlignment.Left
    nameBtn.Parent = row
    
    nameBtn.MouseButton1Click:Connect(function()
        SelectedInstance = instance
        SelectionChangedEvent:Fire(instance)
        Fluent:Notify({Title = "Hidden", Content = "Selected: " .. instance.Name, Duration = 2})
    end)
end

local function loadNilInstances()
    clearHiddenList()
    
    local nilInsts = {}
    pcall(function()
        if getnilinstances then
            nilInsts = getnilinstances()
        end
    end)
    
    if #nilInsts == 0 then
        local noDataLabel = Instance.new("TextLabel")
        noDataLabel.Size = UDim2.new(1, 0, 0, 50)
        noDataLabel.BackgroundTransparency = 1
        noDataLabel.Text = "No nil instances found"
        noDataLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
        noDataLabel.Font = Enum.Font.GothamMedium
        noDataLabel.TextSize = 11
        noDataLabel.Parent = HiddenScroll
        return
    end
    
    for _, inst in ipairs(nilInsts) do
        createHiddenItem(inst)
    end
end

local function loadModules()
    clearHiddenList()
    
    local modules = {}
    pcall(function()
        if getloadedmodules then
            modules = getloadedmodules()
        end
    end)
    
    if #modules == 0 then
        local noDataLabel = Instance.new("TextLabel")
        noDataLabel.Size = UDim2.new(1, 0, 0, 50)
        noDataLabel.BackgroundTransparency = 1
        noDataLabel.Text = "No loaded modules found"
        noDataLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
        noDataLabel.Font = Enum.Font.GothamMedium
        noDataLabel.TextSize = 11
        noDataLabel.Parent = HiddenScroll
        return
    end
    
    for _, mod in ipairs(modules) do
        if mod:IsA("ModuleScript") then
            createHiddenItem(mod)
        end
    end
end

nilBtn.MouseButton1Click:Connect(function()
    currentMode = "nil"
    nilBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
    nilBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    modBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    modBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    loadNilInstances()
end)

modBtn.MouseButton1Click:Connect(function()
    currentMode = "modules"
    modBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
    modBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    nilBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    nilBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    loadModules()
end)

loadNilInstances()

local settingsContainer = Tabs.Settings.Container

local SettingsFrame = Instance.new("Frame")
SettingsFrame.Size = UDim2.new(1, 0, 1, 0)
SettingsFrame.BackgroundTransparency = 1
SettingsFrame.BorderSizePixel = 0
SettingsFrame.Parent = settingsContainer

local SettingsScroll = Instance.new("ScrollingFrame")
SettingsScroll.Size = UDim2.new(1, 0, 1, 0)
SettingsScroll.BackgroundTransparency = 1
SettingsScroll.BorderSizePixel = 0
SettingsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
SettingsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
SettingsScroll.Parent = SettingsFrame

local settingsListLayout = Instance.new("UIListLayout")
settingsListLayout.SortOrder = Enum.SortOrder.LayoutOrder
settingsListLayout.Padding = UDim.new(0, 6)
settingsListLayout.Parent = SettingsScroll

local keybindFrame = Instance.new("Frame")
keybindFrame.Size = UDim2.new(1, -10, 0, 60)
keybindFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
keybindFrame.BorderSizePixel = 0
keybindFrame.Parent = SettingsScroll

local keybindCorner = Instance.new("UICorner")
keybindCorner.CornerRadius = UDim.new(0, 4)
keybindCorner.Parent = keybindFrame

local keybindLabel = Instance.new("TextLabel")
keybindLabel.Size = UDim2.new(1, -20, 0, 20)
keybindLabel.Position = UDim2.new(0, 10, 0, 8)
keybindLabel.BackgroundTransparency = 1
keybindLabel.Text = "Toggle Keybind"
keybindLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
keybindLabel.Font = Enum.Font.GothamBold
keybindLabel.TextSize = 11
keybindLabel.TextXAlignment = Enum.TextXAlignment.Left
keybindLabel.Parent = keybindFrame

local keybindBtn = Instance.new("TextButton")
keybindBtn.Size = UDim2.new(1, -20, 0, 24)
keybindBtn.Position = UDim2.new(0, 10, 1, -30)
keybindBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 200)
keybindBtn.Text = "LeftControl"
keybindBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
keybindBtn.Font = Enum.Font.GothamBold
keybindBtn.TextSize = 10
keybindBtn.Parent = keybindFrame

local keybindBtnCorner = Instance.new("UICorner")
keybindBtnCorner.CornerRadius = UDim.new(0, 4)
keybindBtnCorner.Parent = keybindBtn

local listening = false
local keyConnection = nil

keybindBtn.MouseButton1Click:Connect(function()
    if listening then return end
    
    listening = true
    keybindBtn.Text = "Press any key..."
    keybindBtn.BackgroundColor3 = Color3.fromRGB(200, 120, 50)
    
    keyConnection = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        
        if input.UserInputType == Enum.UserInputType.Keyboard then
            CurrentToggleKey = input.KeyCode
            keybindBtn.Text = input.KeyCode.Name
            keybindBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 200)
            listening = false
            keyConnection:Disconnect()
        end
    end)
end)

local toggleParent = HUI or game:GetService("CoreGui")

local function makeDraggable(frame)
    local dragging, dragInput, dragStart, startPos
    
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local MobileToggle = Instance.new("TextButton")
MobileToggle.Name = "UA_MobileToggle"
MobileToggle.Size = UDim2.new(0, 50, 0, 50)
MobileToggle.Position = UDim2.new(0.05, 0, 0.15, 0)
MobileToggle.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
MobileToggle.Text = "UA"
MobileToggle.TextColor3 = Color3.fromRGB(240, 240, 245)
MobileToggle.Font = Enum.Font.GothamBold
MobileToggle.TextSize = 16
MobileToggle.ZIndex = 99999
MobileToggle.Parent = toggleParent

local mobCorner = Instance.new("UICorner")
mobCorner.CornerRadius = UDim.new(0, 25)
mobCorner.Parent = MobileToggle

local mobStroke = Instance.new("UIStroke")
mobStroke.Color = Color3.fromRGB(0, 210, 255)
mobStroke.Thickness = 2
mobStroke.Parent = MobileToggle

local mobGradient = Instance.new("UIGradient")
mobGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 80, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 210, 255))
})
mobGradient.Parent = mobStroke

makeDraggable(MobileToggle)

local dragTime = 0
MobileToggle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragTime = os.clock()
    end
end)

MobileToggle.Activated:Connect(function()
    if os.clock() - dragTime < 0.25 then
        Window:Minimize()
    end
end)

local toggleConn = UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == CurrentToggleKey then
        Window:Minimize()
    end
end)

Window.Root.Destroying:Connect(function()
    if toggleConn then toggleConn:Disconnect() end
    if MobileToggle then MobileToggle:Destroy() end
    if PickerConnection then PickerConnection:Disconnect() end
    if SelectionBoxInstance then SelectionBoxInstance:Destroy() end
end)

task.delay(0.6, function()
    pcall(function()
        if Window.Root then
            if Window.Root:IsA("ScreenGui") then
                Window.Root.Enabled = true
                Window.Root.ResetOnSpawn = false
                Window.Root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            end
        end
    end)
end)

task.delay(1, function()
    pcall(function()
        if Tabs.Explorer and Tabs.Explorer.Container then
            Tabs.Explorer.Container.Visible = true
        end
    end)
end)

Fluent:Notify({
    Title = "UnderstandAble Explorer",
    Content = "Loaded successfully!",
    Duration = 3
})
