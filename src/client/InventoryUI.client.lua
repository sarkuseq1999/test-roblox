-- Press I to open inventory. Click an item to equip / consume.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local ItemConfig = require(Shared.Config.ItemConfig)

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "InventoryUI"
screen.ResetOnSpawn = false
screen.Parent = pg

-- Always-visible toggle button in the bottom-left.
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "InventoryToggle"
toggleBtn.AnchorPoint = Vector2.new(0, 1)
toggleBtn.Position = UDim2.new(0, 12, 1, -12)
toggleBtn.Size = UDim2.new(0, 140, 0, 34)
toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
toggleBtn.BorderSizePixel = 0
toggleBtn.Font = Enum.Font.GothamSemibold
toggleBtn.TextSize = 14
toggleBtn.TextColor3 = Color3.fromRGB(255, 240, 200)
toggleBtn.Text = "Inventory (I)"
toggleBtn.Parent = screen

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -16, 0.5, 0)
panel.Size = UDim2.new(0, 320, 0, 460)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screen

local function togglePanel()
	panel.Visible = not panel.Visible
end
toggleBtn.MouseButton1Click:Connect(togglePanel)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(255, 240, 200)
title.Text = "Inventory  (I to close)"
title.Parent = panel

local equippedFrame = Instance.new("Frame")
equippedFrame.Position = UDim2.new(0, 8, 0, 36)
equippedFrame.Size = UDim2.new(1, -16, 0, 60)
equippedFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
equippedFrame.BorderSizePixel = 0
equippedFrame.Parent = panel

local equippedTitle = Instance.new("TextLabel")
equippedTitle.Size = UDim2.new(1, -8, 0, 18)
equippedTitle.Position = UDim2.new(0, 4, 0, 2)
equippedTitle.BackgroundTransparency = 1
equippedTitle.Font = Enum.Font.GothamSemibold
equippedTitle.TextSize = 13
equippedTitle.TextXAlignment = Enum.TextXAlignment.Left
equippedTitle.TextColor3 = Color3.fromRGB(220, 220, 200)
equippedTitle.Text = "Equipped"
equippedTitle.Parent = equippedFrame

local weaponLbl = Instance.new("TextLabel")
weaponLbl.Position = UDim2.new(0, 8, 0, 22)
weaponLbl.Size = UDim2.new(1, -16, 0, 16)
weaponLbl.BackgroundTransparency = 1
weaponLbl.Font = Enum.Font.Gotham
weaponLbl.TextSize = 13
weaponLbl.TextXAlignment = Enum.TextXAlignment.Left
weaponLbl.TextColor3 = Color3.fromRGB(255, 240, 200)
weaponLbl.Parent = equippedFrame

local chestLbl = weaponLbl:Clone()
chestLbl.Position = UDim2.new(0, 8, 0, 40)
chestLbl.Parent = equippedFrame

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.new(0, 8, 0, 102)
list.Size = UDim2.new(1, -16, 1, -110)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ScrollBarThickness = 6
list.Parent = panel

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 4)
layout.Parent = list

local rarityColors = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(120, 220, 120),
	Rare = Color3.fromRGB(120, 160, 240),
	Epic = Color3.fromRGB(180, 110, 230),
	Legendary = Color3.fromRGB(240, 180, 60),
}

local function rebuild(snapshot)
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	weaponLbl.Text = "Weapon: " .. (snapshot.equipment.Weapon and ItemConfig.Get(snapshot.equipment.Weapon).name or "—")
	chestLbl.Text = "Chest:  " .. (snapshot.equipment.Chest and ItemConfig.Get(snapshot.equipment.Chest).name or "—")
	for i, entry in ipairs(snapshot.inventory) do
		local def = ItemConfig.Get(entry.id)
		if def then
			local btn = Instance.new("TextButton")
			btn.LayoutOrder = i
			btn.Size = UDim2.new(1, 0, 0, 32)
			btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
			btn.BorderSizePixel = 0
			btn.AutoButtonColor = true
			btn.Font = Enum.Font.Gotham
			btn.TextSize = 14
			btn.TextXAlignment = Enum.TextXAlignment.Left
			btn.TextColor3 = rarityColors[def.rarity] or Color3.fromRGB(220, 220, 220)
			btn.Text = string.format("  %s%s   [%s]", def.name, entry.qty > 1 and " x" .. entry.qty or "", def.slot)
			btn.Parent = list
			btn.MouseButton1Click:Connect(function()
				if def.slot == "Weapon" or def.slot == "Chest" then
					Remotes.Event("UseItem"):FireServer("equip", i)
				elseif def.consume then
					Remotes.Event("UseItem"):FireServer("consume", i)
				end
			end)
		end
	end
end

Remotes.Event("InventoryUpdated").OnClientEvent:Connect(rebuild)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.I then
		togglePanel()
	end
end)

ContextActionService:BindActionAtPriority("ToggleInventory", function(_, state)
	if state == Enum.UserInputState.Begin then
		togglePanel()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.I)
