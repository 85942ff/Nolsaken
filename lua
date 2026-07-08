local repo = "https://raw.githubusercontent.com/SyndromeXph/NOL-Obsidian/refs/heads/main/"

local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

Library.ForceCheckbox = false
Library.ShowToggleFrameInKeybinds = true


local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    Workspace = game:GetService("Workspace"),
}
local LocalPlayer = Services.Players.LocalPlayer
local Camera = Services.Workspace.CurrentCamera

local ESPSettings = {
   killerESP = false,
   playerESP = false,
   generatorESP = false,
   itemESP = false,
   pizzaEsp = false,
   pizzaDeliveryEsp = false,
   zombieEsp = false,
   killerTracers = false,
   survivorTracers = false,
   generatorTracers = false,
   itemTracers = false,
   pizzaTracers = false,
   pizzaDeliveryTracers = false,
   zombieTracers = false,
   killerSkinESP = false,
   survivorSkinESP = false,
   killerNameESP = true,
   killerHealthESP = true,
   survivorNameESP = true,
   survivorHealthESP = true,
   killerFillTransparency = 0.7,
   killerOutlineTransparency = 0.3,
   survivorFillTransparency = 0.7,
   survivorOutlineTransparency = 0.3,
   killerColor = Color3.fromRGB(255, 100, 100),
   survivorColor = Color3.fromRGB(100, 255, 100),
   generatorColor = Color3.fromRGB(255, 100, 255),
   itemColor = Color3.fromRGB(100, 200, 255),
   pizzaColor = Color3.fromRGB(255, 200, 0),
   pizzaDeliveryColor = Color3.fromRGB(255, 150, 0),
   zombieColor = Color3.fromRGB(0, 255, 0),
}

local DummyNames = {
   "PizzaDeliveryRig", "Mafiaso1", "Mafiaso2", "Builderman", "Elliot",
   "ShedletskyCORRUPT", "ChancecORRUPT", "ChanceCORRUPT", "Mafia1", "Mafia2",
}

local PlayerESPData = {}
local ObjectESPData = {}
local TracerData = {}

local function IsRagdoll(model)
   local ragdolls = Services.Workspace:FindFirstChild("Ragdolls")
   if not ragdolls then return false end
   return model:IsDescendantOf(ragdolls) or (model.Parent == ragdolls)
end

local function IsSpectating(player)
   if not player then return false end
   local playersFolder = Services.Workspace:FindFirstChild("Players")
   if not playersFolder then return false end
   local spectating = playersFolder:FindFirstChild("Spectating")
   if not spectating then return false end
   return spectating:FindFirstChild(player.Name) ~= nil
end

local function GetGeneratorPart(model)
   if not model then return nil end
   local instances = model:FindFirstChild("Instances")
   if instances then
       local generator = instances:FindFirstChild("Generator")
       if generator then
           local cube = generator:FindFirstChild("Cube.003")
           if cube and cube:IsA("BasePart") then return cube end
           for _, v in ipairs(generator:GetDescendants()) do
               if v:IsA("BasePart") then return v end
           end
       end
   end
   for _, v in ipairs(model:GetDescendants()) do
       if v:IsA("BasePart") then return v end
   end
   return nil
end

local function UpdatePlayerBillboardText(data)
   if not data or not data.model or not data.nameLabel then return end
   
   local model = data.model
   local isKiller = data.isKiller
   
   local actorText = model:GetAttribute("ActorDisplayName") or (isKiller and "杀手" or "幸存者")
   local skinText = model:GetAttribute("SkinNameDisplay")
   
   if actorText == "Noli" and model:GetAttribute("IsFakeNoli") == true then
       actorText = actorText .. " (Fake)"
   end
   
   local displayText = actorText
   
   local showSkin = (isKiller and ESPSettings.killerSkinESP) or (not isKiller and ESPSettings.survivorSkinESP)
   if showSkin and skinText and tostring(skinText) ~= "" then
       displayText = displayText .. " | " .. skinText
   end
   
   local showName = (isKiller and ESPSettings.killerNameESP) or (not isKiller and ESPSettings.survivorNameESP)
   data.nameLabel.Text = showName and displayText or ""
   data.nameLabel.Visible = showName
   
   if data.hpLabel then
       local humanoid = model:FindFirstChild("Humanoid")
       if humanoid then
           local hp = math.floor(humanoid.Health)
           local maxhp = math.floor(humanoid.MaxHealth)
           data.hpLabel.Text = string.format("HP: %d/%d", hp, maxhp)
       end
       local showHealth = (isKiller and ESPSettings.killerHealthESP) or (not isKiller and ESPSettings.survivorHealthESP)
       data.hpLabel.Visible = showHealth
   end
   
   local highlight = model:FindFirstChild("TAOWARE_Highlight")
   if highlight then
       if isKiller then
           highlight.FillTransparency = ESPSettings.killerFillTransparency
           highlight.OutlineTransparency = ESPSettings.killerOutlineTransparency
       else
           highlight.FillTransparency = ESPSettings.survivorFillTransparency
           highlight.OutlineTransparency = ESPSettings.survivorOutlineTransparency
       end
   end
end

local function UpdateGeneratorProgress(data)
   if not data or not data.model or not data.progressLabel then return end
   
   local model = data.model
   local progress = model:FindFirstChild("Progress")
   
   if progress then
       local progressValue = math.floor(progress.Value)
       data.progressLabel.Text = string.format("Progress: %d%%", progressValue)
   end
end

local function CreateESP(model, color, isGenerator, isItem, isPizza, isPizzaDelivery, isZombie, isKiller)
   if not model then return end
   if model:FindFirstChild("TAOWARE_Highlight") then return end
   if isGenerator and model:FindFirstChild("Progress") and model.Progress.Value == 100 then return end
   if IsRagdoll(model) then return end

   local targetPart
   if isGenerator then
       targetPart = GetGeneratorPart(model)
   elseif isItem then
       targetPart = model:FindFirstChild("ItemRoot")
   elseif isPizza or isPizzaDelivery or isZombie then
       targetPart = model:IsA("BasePart") and model or model:FindFirstChildWhichIsA("BasePart", true)
   else
       targetPart = model:FindFirstChild("HumanoidRootPart")
   end

   if not targetPart then return end

   local highlight = Instance.new("Highlight")
   highlight.Name = "TAOWARE_Highlight"
   highlight.Adornee = model
   highlight.FillColor = color
   highlight.OutlineColor = color
   
   if isKiller then
       highlight.FillTransparency = ESPSettings.killerFillTransparency
       highlight.OutlineTransparency = ESPSettings.killerOutlineTransparency
   elseif not isGenerator and not isItem and not isPizza and not isPizzaDelivery and not isZombie then
       highlight.FillTransparency = ESPSettings.survivorFillTransparency
       highlight.OutlineTransparency = ESPSettings.survivorOutlineTransparency
   else
       highlight.FillTransparency = 0.7
       highlight.OutlineTransparency = 0.3
   end
   
   highlight.Parent = model

   local billboard = Instance.new("BillboardGui")
   billboard.Name = "TAOWARE_Billboard"
   billboard.Adornee = targetPart
   billboard.Size = UDim2.new(0, 100, 0, 30)
   billboard.StudsOffset = Vector3.new(0, 4, 0)
   billboard.AlwaysOnTop = true
   billboard.Parent = model

   if not isGenerator and not isItem and not isPizza and not isPizzaDelivery and not isZombie then
       local humanoid = model:FindFirstChild("Humanoid")
       
       local nameLabel = Instance.new("TextLabel")
       nameLabel.Size = UDim2.new(1, 0, 0.33, 0)
       nameLabel.Position = UDim2.new(0, 0, 0, 0)
       nameLabel.BackgroundTransparency = 1
       nameLabel.Text = "Loading..."
       nameLabel.Font = Enum.Font.GothamBlack
       nameLabel.TextColor3 = color
       nameLabel.TextSize = 8
       nameLabel.TextStrokeTransparency = 0.6
       nameLabel.Parent = billboard

       local hpLabel = Instance.new("TextLabel")
       hpLabel.Size = UDim2.new(1, 0, 0.33, 0)
       hpLabel.Position = UDim2.new(0, 0, 0.3, 0)
       hpLabel.BackgroundTransparency = 1
       hpLabel.Text = "HP: " .. (humanoid and string.format("%.0f", humanoid.Health) or "N/A")
       hpLabel.Font = Enum.Font.GothamBlack
       hpLabel.TextColor3 = color
       hpLabel.TextSize = 8
       hpLabel.TextStrokeTransparency = 0.6
       hpLabel.Parent = billboard

       local espData = {
           model = model, 
           nameLabel = nameLabel, 
           hpLabel = hpLabel, 
           color = color,
           isKiller = isKiller
       }
       
       table.insert(PlayerESPData, espData)
       
       UpdatePlayerBillboardText(espData)
       
       model:GetAttributeChangedSignal("ActorDisplayName"):Connect(function()
           UpdatePlayerBillboardText(espData)
       end)
       
       model:GetAttributeChangedSignal("SkinNameDisplay"):Connect(function()
           UpdatePlayerBillboardText(espData)
       end)
       
       model:GetAttributeChangedSignal("IsFakeNoli"):Connect(function()
           UpdatePlayerBillboardText(espData)
       end)
       
       if humanoid then
           humanoid:GetPropertyChangedSignal("Health"):Connect(function()
               UpdatePlayerBillboardText(espData)
           end)
           humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
               UpdatePlayerBillboardText(espData)
           end)
       end
   elseif isGenerator then
       local nameLabel = Instance.new("TextLabel")
       nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
       nameLabel.Position = UDim2.new(0, 0, 0, 0)
       nameLabel.BackgroundTransparency = 1
       nameLabel.Text = "generator"
       nameLabel.Font = Enum.Font.GothamBlack
       nameLabel.TextColor3 = color
       nameLabel.TextSize = 8
       nameLabel.TextStrokeTransparency = 0.6
       nameLabel.Parent = billboard
       
       local progressLabel = Instance.new("TextLabel")
       progressLabel.Size = UDim2.new(1, 0, 0.5, 0)
       progressLabel.Position = UDim2.new(0, 0, 0.5, 0)
       progressLabel.BackgroundTransparency = 1
       progressLabel.Text = "Progress: 0%"
       progressLabel.Font = Enum.Font.GothamBlack
       progressLabel.TextColor3 = color
       progressLabel.TextSize = 8
       progressLabel.TextStrokeTransparency = 0.6
       progressLabel.Parent = billboard
       
       local espData = {
           model = model,
           nameLabel = nameLabel,
           progressLabel = progressLabel,
           highlight = highlight,
           billboard = billboard
       }
       
       table.insert(ObjectESPData, espData)
       
       UpdateGeneratorProgress(espData)
       
       local progress = model:FindFirstChild("Progress")
       if progress then
           progress:GetPropertyChangedSignal("Value"):Connect(function()
               UpdateGeneratorProgress(espData)
           end)
       end
   else
       local displayName = model.Name
       if isPizzaDelivery then displayName = "Pizza Delivery" end
       if isZombie then displayName = "Zombie" end
       
       local textLabel = Instance.new("TextLabel")
       textLabel.Size = UDim2.new(1, 0, 1, 0)
       textLabel.BackgroundTransparency = 1
       textLabel.Text = displayName
       textLabel.Font = Enum.Font.GothamBlack
       textLabel.TextColor3 = color
       textLabel.TextSize = 8
       textLabel.TextStrokeTransparency = 0.6
       textLabel.Parent = billboard

       table.insert(ObjectESPData, {model = model, highlight = highlight, billboard = billboard})
   end
end

local function RemoveESP(model)
   if not model then return end
   for i = #PlayerESPData, 1, -1 do
       if PlayerESPData[i].model == model then
           table.remove(PlayerESPData, i)
       end
   end
   for i = #ObjectESPData, 1, -1 do
       if ObjectESPData[i].model == model then
           table.remove(ObjectESPData, i)
       end
   end
   pcall(function()
       if model:FindFirstChild("TAOWARE_Highlight") then
           model.TAOWARE_Highlight:Destroy()
       end
       if model:FindFirstChild("TAOWARE_Billboard") then
           model.TAOWARE_Billboard:Destroy()
       end
   end)
end

local function CreateTracer(model, part, color)
   if not model or not part or not part:IsA("BasePart") then return end
   if TracerData[model] then return end

   local line = Drawing.new("Line")
   line.Visible = true
   line.Color = color or Color3.fromRGB(255, 255, 255)
   line.Thickness = 2
   line.Transparency = 1

   TracerData[model] = {line = line, part = part}
end

local function RemoveTracer(model)
   if TracerData[model] then
       pcall(function()
           TracerData[model].line.Visible = false
           TracerData[model].line:Remove()
       end)
       TracerData[model] = nil
   end
end

local function UpdateTracers()
   for model, data in pairs(TracerData) do
       local line = data.line
       local part = data.part
       if line and part and part.Parent then
           local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
           if onScreen then
               line.Visible = true
               line.From = Vector2.new(Camera.ViewportSize.X / 2, 0)
               line.To = Vector2.new(pos.X, pos.Y)
           else
               line.Visible = false
           end
       else
           RemoveTracer(model)
       end
   end
end

local noliByUsername = {}
local function clearFakeTags()
   local playersFolder = Services.Workspace:FindFirstChild("Players")
   if not playersFolder then return end
   local killers = playersFolder:FindFirstChild("Killers")
   if not killers then return end
   
   for _, killer in ipairs(killers:GetChildren()) do
       if killer:GetAttribute("ActorDisplayName") == "Noli" then
           killer:SetAttribute("IsFakeNoli", false)
       end
   end
end

local function scanNolis()
   local playersFolder = Services.Workspace:FindFirstChild("Players")
   if not playersFolder then return end
   local killers = playersFolder:FindFirstChild("Killers")
   if not killers then return end
   
   noliByUsername = {}
   for _, killer in ipairs(killers:GetChildren()) do
       if killer:GetAttribute("ActorDisplayName") == "Noli" then
           local username = killer:GetAttribute("Username")
           if username then
               if not noliByUsername[username] then
                   noliByUsername[username] = {}
               end
               table.insert(noliByUsername[username], killer)
           end
       end
   end
   for username, models in pairs(noliByUsername) do
       if #models > 1 then
           for i = 2, #models do
               models[i]:SetAttribute("IsFakeNoli", true)
           end
           models[1]:SetAttribute("IsFakeNoli", false)
       else
           models[1]:SetAttribute("IsFakeNoli", false)
       end
   end
end

local function updateFakeNolis()
   clearFakeTags()
   scanNolis()
end

local function UpdateAllPlayerESPText()
   for _, data in ipairs(PlayerESPData) do
       UpdatePlayerBillboardText(data)
   end
end

local function UpdateESP()
   local mapFolder = Services.Workspace:FindFirstChild("Map")
   if not mapFolder or not mapFolder:FindFirstChild("Ingame") then
       for i = #PlayerESPData, 1, -1 do
           RemoveESP(PlayerESPData[i].model)
       end
       for i = #ObjectESPData, 1, -1 do
           RemoveESP(ObjectESPData[i].model)
       end
       for model in pairs(TracerData) do
           RemoveTracer(model)
       end
       return
   end

   local ingame = mapFolder.Ingame

   local playersFolder = Services.Workspace:FindFirstChild("Players")
   if playersFolder then
       local killers = playersFolder:FindFirstChild("Killers")
       if killers then
           for _, killer in ipairs(killers:GetChildren()) do
               if killer == LocalPlayer.Character then continue end
               if IsRagdoll(killer) then
                   RemoveESP(killer)
                   RemoveTracer(killer)
                   continue
               end
               local player = Services.Players:GetPlayerFromCharacter(killer)
               if not player or IsSpectating(player) then
                   RemoveESP(killer)
                   RemoveTracer(killer)
                   continue
               end

               if ESPSettings.killerESP and not killer:FindFirstChild("TAOWARE_Highlight") and killer:FindFirstChild("HumanoidRootPart") then
                   CreateESP(killer, ESPSettings.killerColor, false, false, false, false, false, true)
               elseif not ESPSettings.killerESP then
                   RemoveESP(killer)
               end

               if ESPSettings.killerTracers and killer:FindFirstChild("HumanoidRootPart") then
                   CreateTracer(killer, killer.HumanoidRootPart, ESPSettings.killerColor)
               else
                   RemoveTracer(killer)
               end
           end
       end

       local survivors = playersFolder:FindFirstChild("Survivors")
       if survivors then
           for _, survivor in ipairs(survivors:GetChildren()) do
               if survivor == LocalPlayer.Character then continue end
               if IsRagdoll(survivor) then
                   RemoveESP(survivor)
                   RemoveTracer(survivor)
                   continue
               end
               local player = Services.Players:GetPlayerFromCharacter(survivor)
               if not player or IsSpectating(player) then
                   RemoveESP(survivor)
                   RemoveTracer(survivor)
                   continue
               end

               if ESPSettings.playerESP and not survivor:FindFirstChild("TAOWARE_Highlight") and survivor:FindFirstChild("HumanoidRootPart") then
                   CreateESP(survivor, ESPSettings.survivorColor, false, false, false, false, false, false)
               elseif not ESPSettings.playerESP then
                   RemoveESP(survivor)
               end

               if ESPSettings.survivorTracers and survivor:FindFirstChild("HumanoidRootPart") then
                   CreateTracer(survivor, survivor.HumanoidRootPart, ESPSettings.survivorColor)
               else
                   RemoveTracer(survivor)
               end
           end
       end
   end

   if ingame:FindFirstChild("Map") then
       for _, gen in ipairs(ingame.Map:GetChildren()) do
           if gen:IsA("Model") and gen.Name:lower():find("generator") and gen.Name ~= "FakeGenerator" then
               if IsRagdoll(gen) then
                   RemoveESP(gen)
                   RemoveTracer(gen)
                   continue
               end
               local progress = gen:FindFirstChild("Progress")
               if ESPSettings.generatorESP and progress and progress.Value < 100 and not gen:FindFirstChild("TAOWARE_Highlight") then
                   CreateESP(gen, ESPSettings.generatorColor, true, false, false, false, false, false)
               elseif (not ESPSettings.generatorESP or (progress and progress.Value >= 100)) then
                   RemoveESP(gen)
               end

               if ESPSettings.generatorTracers and progress and progress.Value < 100 then
                   local part = GetGeneratorPart(gen)
                   if part then
                       CreateTracer(gen, part, ESPSettings.generatorColor)
                   end
               else
                   RemoveTracer(gen)
               end
           end
       end
       
       for _, item in ipairs(ingame.Map:GetDescendants()) do
           if item.Name == "ItemRoot" and item.Parent and item.Parent:IsA("Model") then
               local itemModel = item.Parent
               if ESPSettings.itemESP and not itemModel:FindFirstChild("TAOWARE_Highlight") then
                   CreateESP(itemModel, ESPSettings.itemColor, false, true, false, false, false, false)
               elseif not ESPSettings.itemESP then
                   RemoveESP(itemModel)
               end
               
               if ESPSettings.itemTracers and item:IsA("BasePart") then
                   CreateTracer(itemModel, item, ESPSettings.itemColor)
               else
                   RemoveTracer(itemModel)
               end
           end
       end
   end
   
   for _, pizza in ipairs(ingame:GetChildren()) do
       if pizza.Name == "Pizza" and pizza:IsA("BasePart") then
           if ESPSettings.pizzaEsp and not pizza:FindFirstChild("TAOWARE_Highlight") then
               CreateESP(pizza, ESPSettings.pizzaColor, false, false, true, false, false, false)
           elseif not ESPSettings.pizzaEsp then
               RemoveESP(pizza)
           end
           
           if ESPSettings.pizzaTracers then
               CreateTracer(pizza, pizza, ESPSettings.pizzaColor)
           else
               RemoveTracer(pizza)
           end
       end
   end
   
   for _, delivery in ipairs(ingame:GetChildren()) do
       if delivery:IsA("Model") and table.find(DummyNames, delivery.Name) then
           if ESPSettings.pizzaDeliveryEsp and not delivery:FindFirstChild("TAOWARE_Highlight") then
               local hrp = delivery:FindFirstChild("HumanoidRootPart")
               if hrp then
                   CreateESP(delivery, ESPSettings.pizzaDeliveryColor, false, false, false, true, false, false)
               end
           elseif not ESPSettings.pizzaDeliveryEsp then
               RemoveESP(delivery)
           end
           
           if ESPSettings.pizzaDeliveryTracers then
               local hrp = delivery:FindFirstChild("HumanoidRootPart")
               if hrp then
                   CreateTracer(delivery, hrp, ESPSettings.pizzaDeliveryColor)
               end
           else
               RemoveTracer(delivery)
           end
       end
   end
   
   for _, zombie in ipairs(ingame:GetChildren()) do
       if zombie.Name == "Zombie" and zombie:IsA("Model") then
           if ESPSettings.zombieEsp and not zombie:FindFirstChild("TAOWARE_Highlight") then
               local hrp = zombie:FindFirstChild("HumanoidRootPart")
               if hrp then
                   CreateESP(zombie, ESPSettings.zombieColor, false, false, false, false, true, false)
               end
           elseif not ESPSettings.zombieEsp then
               RemoveESP(zombie)
           end
           
           if ESPSettings.zombieTracers then
               local hrp = zombie:FindFirstChild("HumanoidRootPart")
               if hrp then
                   CreateTracer(zombie, hrp, ESPSettings.zombieColor)
               end
           else
               RemoveTracer(zombie)
           end
       end
   end
end

task.spawn(function()
   while true do
       UpdateESP()
       updateFakeNolis()
       task.wait(0.5)
   end
end)

Services.RunService.RenderStepped:Connect(function()
   UpdateTracers()
end)






local Window = Library:CreateWindow({
	Title = "NOLSAKEN",
	Footer = "被遗弃｜NOLSAKEN TEST",
	NotifySide = "Right",
	ShowCustomCursor = true,
})

local Tabs = {
	Bro = Window:AddTab('绘制', 'eye'),
	Block = Window:AddTab('格挡', 'user'),
	Backstab = Window:AddTab('背刺', 'sword'),   -- 新 Tab
	Sat = Window:AddTab('体力', 'zap'),
	Ability = Window:AddTab('能力', 'star'),
	zdx = Window:AddTab('电机', 'printer'),
	Aimbot = Window:AddTab('自瞄', 'crosshair'),
	tfz = Window:AddTab('杀戮', 'skull'),
	ani = Window:AddTab('反效果', 'cpu'),
	yul = Window:AddTab('娱乐功能', 'cpu'),
	["UI Settings"] = Window:AddTab('UI 调试', 'settings')
}




local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local MapFolder = Workspace:WaitForChild("Map"):WaitForChild("Ingame")

local Settings = {
	Advanced = { Enabled = false, OutlineOnly = true, ShowNametag = false, Color = Color3.fromRGB(0, 255, 255) }
}

local Highlights = {}
local Nametags = {}

local AdvancedNames = {"BuildermanDispenser","BuildermanSentry","HumanoidRootProjectile","Swords","shockwave","Voidstar"}

local function CreateNametag(adornee, text, color)
	if Nametags[adornee] then Nametags[adornee]:Destroy() end
	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = adornee
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = true
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = text
	textLabel.TextColor3 = color
	textLabel.TextStrokeTransparency = 0
	textLabel.TextStrokeColor3 = Color3.new(0,0,0)
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextSize = 6
	textLabel.Parent = billboard
	billboard.Parent = adornee
	Nametags[adornee] = textLabel
end

local function AddHighlight(Obj, Config)
	if Highlights[Obj] then Highlights[Obj]:Destroy() end
	local hl = Instance.new("Highlight")
	hl.Adornee = Obj
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Enabled = Config.Enabled
	hl.OutlineColor = Config.Color
	hl.FillColor = Config.Color
	hl.OutlineTransparency = 0
	local alwaysFill = table.find({"BuildermanDispenser","BuildermanSentry","PizzaDeliveryRig","HumanoidRootProjectile","Swords","shockwave","Voidstar","Shadow"}, Obj.Name)
	hl.FillTransparency = Config.OutlineOnly and 1 or (alwaysFill and 0.65 or 1)
	hl.Parent = Obj
	Highlights[Obj] = hl
	Obj.AncestryChanged:Connect(function(_, parent)
		if not parent then
			if Highlights[Obj] then Highlights[Obj]:Destroy() Highlights[Obj] = nil end
			if Nametags[Obj] then Nametags[Obj].Parent:Destroy() Nametags[Obj] = nil end
		end
	end)
end

local function ApplyToTarget(target, Config)
	if not target or not target.Parent then return end
	AddHighlight(target, Config)
end

local function HandleAdvanced(obj)
	if table.find(AdvancedNames, obj.Name) or (obj.Name == "Shadow" and obj.Parent and obj.Parent.Name == "Shadows") then
		ApplyToTarget(obj, Settings.Advanced)
	end
end

for _, v in ipairs(MapFolder:GetDescendants()) do HandleAdvanced(v) end
MapFolder.DescendantAdded:Connect(HandleAdvanced)

task.spawn(function()
	while task.wait(0.3) do
		for obj, hl in pairs(Highlights) do
			if not hl or not hl.Parent then continue end
			local config = Settings.Advanced
			hl.Enabled = config.Enabled
			hl.OutlineColor = config.Color
			hl.FillColor = config.Color
			hl.OutlineTransparency = 0
			hl.FillTransparency = config.OutlineOnly and 1 or 0.65
			if config.ShowNametag then
				local baseName = obj.Name
				local nameText = baseName
				if Nametags[obj] then
					Nametags[obj].Text = nameText
					Nametags[obj].TextColor3 = config.Color
				else
					CreateNametag(obj, nameText, config.Color)
				end
			else
				if Nametags[obj] then
					Nametags[obj].Parent:Destroy()
					Nametags[obj] = nil
				end
			end
		end
	end
end)

local AdvancedGroup = Tabs.Bro:AddRightGroupbox("技能 ESP", "boxes")

AdvancedGroup:AddCheckbox("AdvancedESP", {
	Text = "ESP 技能",
	Default = false,
	Callback = function(Value)
		Settings.Advanced.Enabled = Value
	end,
})

AdvancedGroup:AddCheckbox("AdvancedOutline", {
	Text = "轮廓",
	Default = false,
	Callback = function(Value)
		Settings.Advanced.OutlineOnly = Value
	end,
})

AdvancedGroup:AddCheckbox("AdvancedNametag", {
	Text = "显示名称",
	Default = false,
	Callback = function(Value)
		Settings.Advanced.ShowNametag = Value
	end,
})

AdvancedGroup:AddLabel("Advanced 颜色"):AddColorPicker("AdvancedColor", {
	Default = Color3.fromRGB(0, 255, 255),
	Title = "颜色",
	Transparency = 0,
	Callback = function(Value)
		Settings.Advanced.Color = Value
	end,
})





-- 杀手ESP设置组
local KillerESPGroup = Tabs.Bro:AddLeftGroupbox("杀手 ESP")

KillerESPGroup:AddCheckbox("KillerESP", {
    Text = "启用杀手 ESP",
    Default = false,
    Callback = function(Value)
        ESPSettings.killerESP = Value
    end,
})

KillerESPGroup:AddCheckbox("KillerTracers", {
    Text = "杀手射线",
    Default = false,
    Callback = function(Value)
        ESPSettings.killerTracers = Value
    end,
})

KillerESPGroup:AddCheckbox("KillerNameESP", {
    Text = "显示杀手名称",
    Default = true,
    Callback = function(Value)
        ESPSettings.killerNameESP = Value
        UpdateAllPlayerESPText()
    end,
})

KillerESPGroup:AddCheckbox("KillerHealthESP", {
    Text = "显示杀手血量",
    Default = true,
    Callback = function(Value)
        ESPSettings.killerHealthESP = Value
        UpdateAllPlayerESPText()
    end,
})

KillerESPGroup:AddCheckbox("KillerSkinESP", {
    Text = "显示杀手皮肤",
    Default = false,
    Callback = function(Value)
        ESPSettings.killerSkinESP = Value
        UpdateAllPlayerESPText()
    end,
})

KillerESPGroup:AddSlider("KillerFillTransparency", {
    Text = "填充透明度",
    Default = 0.7,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Compact = false,
    Callback = function(Value)
        ESPSettings.killerFillTransparency = Value
        UpdateAllPlayerESPText()
    end,
})

KillerESPGroup:AddSlider("KillerOutlineTransparency", {
    Text = "轮廓透明度",
    Default = 0.3,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Compact = false,
    Callback = function(Value)
        ESPSettings.killerOutlineTransparency = Value
        UpdateAllPlayerESPText()
    end,
})

KillerESPGroup:AddLabel("杀手颜色"):AddColorPicker("KillerColor", {
    Default = Color3.fromRGB(255, 100, 100),
    Title = "杀手 ESP 颜色",
    Callback = function(Value)
        ESPSettings.killerColor = Value
    end,
})

-- 幸存者ESP设置组
local SurvivorESPGroup = Tabs.Bro:AddLeftGroupbox("幸存者 ESP")

SurvivorESPGroup:AddCheckbox("SurvivorESP", {
    Text = "启用幸存者 ESP",
    Default = false,
    Callback = function(Value)
        ESPSettings.playerESP = Value
    end,
})

SurvivorESPGroup:AddCheckbox("SurvivorTracers", {
    Text = "幸存者射线",
    Default = false,
    Callback = function(Value)
        ESPSettings.survivorTracers = Value
    end,
})

SurvivorESPGroup:AddCheckbox("SurvivorNameESP", {
    Text = "显示幸存者名称",
    Default = true,
    Callback = function(Value)
        ESPSettings.survivorNameESP = Value
        UpdateAllPlayerESPText()
    end,
})

SurvivorESPGroup:AddCheckbox("SurvivorHealthESP", {
    Text = "显示幸存者血量",
    Default = true,
    Callback = function(Value)
        ESPSettings.survivorHealthESP = Value
        UpdateAllPlayerESPText()
    end,
})

SurvivorESPGroup:AddCheckbox("SurvivorSkinESP", {
    Text = "显示幸存者皮肤",
    Default = false,
    Callback = function(Value)
        ESPSettings.survivorSkinESP = Value
        UpdateAllPlayerESPText()
    end,
})

SurvivorESPGroup:AddSlider("SurvivorFillTransparency", {
    Text = "填充透明度",
    Default = 0.7,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Compact = false,
    Callback = function(Value)
        ESPSettings.survivorFillTransparency = Value
        UpdateAllPlayerESPText()
    end,
})

SurvivorESPGroup:AddSlider("SurvivorOutlineTransparency", {
    Text = "轮廓透明度",
    Default = 0.3,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Compact = false,
    Callback = function(Value)
        ESPSettings.survivorOutlineTransparency = Value
        UpdateAllPlayerESPText()
    end,
})

SurvivorESPGroup:AddLabel("幸存者颜色"):AddColorPicker("SurvivorColor", {
    Default = Color3.fromRGB(100, 255, 100),
    Title = "幸存者 ESP 颜色",
    Callback = function(Value)
        ESPSettings.survivorColor = Value
    end,
})

-- 物品 ESP
local ObjectESPBox = Tabs.Bro:AddRightGroupbox("物品 ESP", "box")

ObjectESPBox:AddCheckbox("GeneratorESP", {
    Text = "电机 ESP",
    Default = false,
    Callback = function(value)
        ESPSettings.generatorESP = value
    end,
}):AddColorPicker("GeneratorColor", {
    Default = ESPSettings.generatorColor,
    Title = "Generator color ",
    Callback = function(value)
        ESPSettings.generatorColor = value
    end,
})




ObjectESPBox:AddCheckbox("ItemESP", {
    Text = "物品 ESP",
    Default = false,
    Callback = function(value)
        ESPSettings.itemESP = value
    end,
}):AddColorPicker("ItemColor", {
    Default = ESPSettings.itemColor,
    Title = "Article color ",
    Callback = function(value)
        ESPSettings.itemColor = value
    end,
})

ObjectESPBox:AddCheckbox("PizzaESP", {
    Text = "披萨 ESP ",
    Default = false,
    Callback = function(value)
        ESPSettings.pizzaEsp = value
    end,
}):AddColorPicker("PizzaColor", {
    Default = ESPSettings.pizzaColor,
    Title = "Pizza color ",
    Callback = function(value)
        ESPSettings.pizzaColor = value
    end,
})



ObjectESPBox:AddCheckbox("TWE", {
    Text = "绊线绘制",
    Default = false,
    Callback = function(state)
        if state then
            -- 初始化 ESP 结构
            ESP.TWE = {
                HighlightedObjects = {},
                Connections = {},
                LastScan = 0,
                ScanInterval = 2,
                Enabled = true
            }
            
            -- 高亮单个对象
            local function highlightObject(obj)
                -- 安全检查
                if not obj or not obj:IsA("BasePart") then return end
                if not obj.Name:match("TaphTripwire") then return end
                if obj:FindFirstChild("TWE_Highlight") then return end
                if ESP.TWE.HighlightedObjects[obj] then return end
                
                pcall(function()
                    -- 创建高亮效果
                    local highlight = Instance.new("Highlight")
                    highlight.Name = "TWE_Highlight"
                    highlight.FillColor = Color3.fromRGB(102, 0, 153)
                    highlight.OutlineColor = Color3.fromRGB(102, 0, 153)
                    highlight.FillTransparency = 0.5
                    highlight.OutlineTransparency = 0
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    highlight.Parent = obj
                    
                    -- 监听对象移除事件
                    local connection = obj.AncestryChanged:Connect(function(_, parent)
                        if not parent then
                            -- 对象被移除，清理高亮
                            if highlight and highlight.Parent then
                                highlight:Destroy()
                            end
                            if ESP.TWE and ESP.TWE.HighlightedObjects[obj] then
                                if ESP.TWE.HighlightedObjects[obj] then
                                    ESP.TWE.HighlightedObjects[obj]:Disconnect()
                                end
                                ESP.TWE.HighlightedObjects[obj] = nil
                            end
                        end
                    end)
                    
                    -- 保存连接
                    ESP.TWE.HighlightedObjects[obj] = connection
                end)
            end

            -- 扫描所有对象
            local function scanObjects()
                if not ESP.TWE or not ESP.TWE.Enabled then return end
                
                local currentTime = tick()
                if currentTime - ESP.TWE.LastScan < ESP.TWE.ScanInterval then
                    return
                end
                ESP.TWE.LastScan = currentTime
                
                -- 扫描现有对象
                pcall(function()
                    for _, obj in ipairs(workspace:GetDescendants()) do
                        if ESP.TWE and ESP.TWE.Enabled then
                            highlightObject(obj)
                        else
                            break
                        end
                    end
                end)
            end

            -- 初始扫描
            task.spawn(scanObjects)
            
            -- 监听新对象添加
            ESP.TWE.Connections.DescendantAdded = workspace.DescendantAdded:Connect(function(obj)
                if ESP.TWE and ESP.TWE.Enabled then
                    highlightObject(obj)
                end
            end)
            
            -- 定期扫描（心跳）
            ESP.TWE.Connections.Heartbeat = game:GetService("RunService").Heartbeat:Connect(function()
                if ESP.TWE and ESP.TWE.Enabled then
                    scanObjects()
                end
            end)
            
        else
            -- 清理所有 ESP 资源
            if ESP.TWE then
                ESP.TWE.Enabled = false
                
                -- 断开所有连接
                if ESP.TWE.Connections then
                    for name, connection in pairs(ESP.TWE.Connections) do
                        pcall(function()
                            if connection then
                                connection:Disconnect()
                            end
                        end)
                    end
                    ESP.TWE.Connections = {}
                end
                
                -- 清理所有高亮对象
                for obj, connection in pairs(ESP.TWE.HighlightedObjects) do
                    pcall(function()
                        -- 断开对象连接
                        if connection then
                            connection:Disconnect()
                        end
                        
                        -- 移除高亮效果
                        if obj and obj:IsDescendantOf(game) then
                            local highlight = obj:FindFirstChild("TWE_Highlight")
                            if highlight then
                                highlight:Destroy()
                            end
                        end
                    end)
                end
                
                -- 清空表
                ESP.TWE.HighlightedObjects = {}
                ESP.TWE = nil
            end
        end
    end
})


ObjectESPBox:AddCheckbox("ST",{
Text = "塔夫空间炸弹绘制",
Callback = function(v)
if not _G.STData then
    _G.STData = {
        connection = nil
    }
end

local data = _G.STData

if data.connection then
    data.connection:Disconnect()
    data.connection = nil
end

if v then
for _, v in ipairs(workspace:GetDescendants()) do
if v:IsA("Model") and v.Name == "SubspaceTripmine" and not v:FindFirstChild("SubspaceTripmine_ESP") then
LibESP:AddESP(v, "", Color3.fromRGB(255, 0, 255), 14, "SubspaceTripmine_ESP")
end
end
data.connection = workspace.DescendantAdded:Connect(function(v)
if v:IsA("Model") and v.Name == "SubspaceTripmine" and not v:FindFirstChild("SubspaceTripmine_ESP") then
LibESP:AddESP(v, "", Color3.fromRGB(255, 0, 255), 14, "SubspaceTripmine_ESP")
end
end)
else
LibESP:Delete("SubspaceTripmine_ESP")
end
end})


-- 特殊 ESP
local SpecialESPBox = Tabs.Bro:AddRightGroupbox("Special esp ","zap")

SpecialESPBox:AddCheckbox("PizzaDeliveryESP", {
    Text = "披萨派送员 ESP",
    Default = false,
    Callback = function(value)
        ESPSettings.pizzaDeliveryEsp = value
    end,
}):AddColorPicker("PizzaDeliveryColor", {
    Default = ESPSettings.pizzaDeliveryColor,
    Title = "Pizza delivery color ",
    Callback = function(value)
        ESPSettings.pizzaDeliveryColor = value
    end,
})

SpecialESPBox:AddCheckbox("ZombieESP", {
    Text = "1x4僵尸 ESP",
    Default = false,
    Callback = function(value)
        ESPSettings.zombieEsp = value
    end,
}):AddColorPicker("ZombieColor", {
    Default = ESPSettings.zombieColor,
    Title = "Zombie Color ",
    Callback = function(value)
        ESPSettings.zombieColor = value
    end,
})








-- 追踪线
local TracerBox = Tabs.Bro:AddRightGroupbox("Trace Line", "spline")



TracerBox:AddCheckbox("GeneratorTracers", {
    Text = "电机追踪线",
    Default = false,
    Callback = function(value)
        ESPSettings.generatorTracers = value
    end,
})

TracerBox:AddCheckbox("ItemTracers", {
    Text = "物品追踪线 ",
    Default = false,
    Callback = function(value)
        ESPSettings.itemTracers = value
    end,
})

TracerBox:AddCheckbox("PizzaTracers", {
    Text = "披萨追踪线",
    Default = false,
    Callback = function(value)
        ESPSettings.pizzaTracers = value
    end,
})

TracerBox:AddCheckbox("PizzaDeliveryTracers", {
    Text = "披萨派送员追踪线",
    Default = false,
    Callback = function(value)
        ESPSettings.pizzaDeliveryTracers = value
    end,
})

TracerBox:AddCheckbox("ZombieTracers", {
    Text = "1x4僵尸追踪线",
    Default = false,
    Callback = function(value)
        ESPSettings.zombieTracers = value
    end,
})




AdvancedGroup:AddCheckbox("NST",{
Text = "地下空间炸弹生成提示",
Default = false,
Callback = function(v)
if not _G.NSTData then
    _G.NSTData = {
        connection = nil
    }
end

local data = _G.NSTData

if data.connection then
    data.connection:Disconnect()
    data.connection = nil
end

if v then
data.connection = workspace.Map.Ingame.DescendantAdded:Connect(function(v)
if v.Name == "SubspaceTripmine" then
Library:Notify("NOL | 报告 \nB地下空间炸弹生成了！")
end
end)
end
end})
AdvancedGroup:AddCheckbox("NEK",{
Text = "实体生成提示",
Default = false,
Callback = function(v)
if not _G.NEKData then
    _G.NEKData = {
        connection = nil
    }
end

local data = _G.NEKData

if data.connection then
    data.connection:Disconnect()
    data.connection = nil
end

if v then
data.connection = workspace.DescendantAdded:Connect(function(v)
if v:IsA("Model") and v.Name == "PizzaDeliveryRig" or v.Name == "Mafia1" or v.Name == "Mafia2" or v.Name == "Mafia3" or v.Name == "Mafia4" then
Library:Notify("NOL | 报告\nEntity '" .. v.Name .. "' 生成了！")
elseif v:IsA("Model") and v.Name == "1x1x1x1Zombie" then
Library:Notify("NOL | 报告\nEntity '1x1x1x1 (zombies)' 生成了！")
end
end)
end
end})



if getgenv().ExistingConnections then
   for _, conn in ipairs(getgenv().ExistingConnections) do
       if conn then
           pcall(function() conn:Disconnect() end)
       end
   end
end

getgenv().ExistingConnections = {}

getgenv().Players = game:GetService("Players")
getgenv().RunService = game:GetService("RunService")
getgenv().LocalPlayer = getgenv().Players.LocalPlayer
getgenv().ReplicatedStorage = game:GetService("ReplicatedStorage")
getgenv().buffer = buffer or require(getgenv().ReplicatedStorage.Buffer)
getgenv().RemoteEvent = getgenv().Rep

local Plrs = getgenv().Players
local RSvc = getgenv().RunService
local LocalP = getgenv().LocalPlayer
local RS = getgenv().ReplicatedStorage
local Workspace = game:GetService("Workspace")

getgenv().AutoBlockSounds = {
  ["12222216"] = true,
  ["71805956520207"] = true,
  ["71834552297085"] = true,
  ["72425554233832"] = true,
  ["75330693422988"] = true,
  ["76467993976301"] = true,
  ["76959687420003"] = true,
  ["77245770579014"] = true,
  ["78298577002481"] = true,
  ["79391273191671"] = true,
  ["79980897195554"] = true,
  ["80516583309685"] = true,
  ["81702359653578"] = true,
  ["82221759983649"] = true,
  ["84116622032112"] = true,
  ["84307400688050"] = true,
  ["85810983952228"] = true,
  ["85853080745515"] = true,
  ["86174610237192"] = true,
  ["86494585504534"] = true,
  ["86833981571073"] = true,
  ["89004992452376"] = true,
  ["89315669689903"] = true,
  ["90878551190839"] = true,
  ["94043596324983"] = true,
  ["95079963655241"] = true,
  ["97894923442490"] = true,
  ["98675142200448"] = true,
  ["99829427721752"] = true,
  ["101199185291628"] = true,
  ["101553872555606"] = true,
  ["101698569375359"] = true,
  ["102228729296384"] = true,
  ["103684883268194"] = true,
  ["104910828105172"] = true,
  ["105200830849301"] = true,
  ["105840448036441"] = true,
  ["106300477136129"] = true,
  ["107444859834748"] = true,
  ["108610718831698"] = true,
  ["108907358619313"] = true,
  ["109348678063422"] = true,
  ["109431876587852"] = true,
  ["110115912768379"] = true,
  ["110372418055226"] = true,
  ["112395455254818"] = true,
  ["112809109188560"] = true,
  ["113037804008732"] = true,
  ["114742322778642"] = true,
  ["115026634746636"] = true,
  ["116581754553533"] = true,
  ["117173212095661"] = true,
  ["117231507259853"] = true,
  ["119089145505438"] = true,
  ["119583605486352"] = true,
  ["119942598489800"] = true,
  ["121954639447247"] = true,
  ["124330645976935"] = true,
  ["124397369810639"] = true,
  ["124903763333174"] = true,
  ["125213046326879"] = true,
  ["127793641088496"] = true,
  ["128856426573270"] = true,
  ["131123355704017"] = true,
  ["131406927389838"] = true,
  ["135448067174226"] = true,
  ["136323728355613"] = true,
  ["136841625231863"] = true,
  ["140242176732868"] = true,
  ["128367348686124"] = true,
  ["116527305931161"] = true
}

getgenv().AutoBlockAnims = {
  ["18885909645"] = true,
  ["70371667919898"] = true,
  ["70447634862911"] = true,
  ["99135633258223"] = true,
  ["74707328554358"] = true,
  ["81299297965542"] = true,
  ["81639435858902"] = true,
  ["82113744478546"] = true,
  ["83251433279852"] = true,
  ["83685305553364"] = true,
  ["83829782357897"] = true,
  ["86204001129974"] = true,
  ["87989533095285"] = true,
  ["88451353906104"] = true,
  ["88970503168421"] = true,
  ["92173139187970"] = true,
  ["93069721274110"] = true,
  ["94162446513587"] = true,
  ["96571077893813"] = true,
  ["97167027849946"] = true,
  ["97433060861952"] = true,
  ["98456918873918"] = true,
  ["99135633258223"] = true,
  ["99829427721752"] = true,
  ["100592913030351"] = true,
  ["105458270463374"] = true,
  ["106538427162796"] = true,
  ["106776364623742"] = true,
  ["106847695270773"] = true,
  ["109230267448394"] = true,
  ["109667959938617"] = true,
  ["114356208094580"] = true,
  ["114506382930939"] = true,
  ["118298475669935"] = true,
  ["120112897026015"] = true,
  ["121086746534252"] = true,
  ["121293883585738"] = true,
  ["122709416391891"] = true,
  ["124705663396411"] = true,
  ["125403313786645"] = true,
  ["126171487400618"] = true,
  ["126355327951215"] = true,
  ["126681776859538"] = true,
  ["126830014841198"] = true,
  ["126896426760253"] = true,
  ["128414736976503"] = true,
  ["129976080405072"] = true,
  ["131430497821198"] = true,
  ["131543461321709"] = true,
  ["133336594357903"] = true,
  ["133363345661032"] = true,
  ["137314737492715"] = true,
  ["138938529389204"] = true,
  ["139309647473555"] = true,
  ["139835501033932"] = true,
  ["109700476007435"] = true,
  ["93366464803829"] = true,
  ["98590570796574"] = true
}

getgenv().AutoBlockEnabled = false
getgenv().KillerFacingCheckEnabled = false
getgenv().wallCheckEnabled = false
getgenv().BoxLength = 7.5
getgenv().BoxWidth = 4.5
getgenv().BoxHeight = 6
getgenv().BoxTransparency = 0.7
getgenv().BoxSafeColor = Color3.fromRGB(0, 255, 0)
getgenv().BoxDangerColor = Color3.fromRGB(255, 0, 0)
getgenv().BoxSizeMultiplier = 1.0
getgenv().BoxForwardOffset = 1.4
getgenv().BoxVisualizationEnabled = false

getgenv().HitboxVisualizationEnabled = false
getgenv().HitboxColor = Color3.fromRGB(255, 255, 255)
getgenv().HitboxTransparency = 0.5
getgenv().processedHitboxes = {}
getgenv().hitboxDetectionLoop = nil

getgenv().KillersFolder = workspace:WaitForChild("Players"):WaitForChild("Killers")
getgenv().SoundHooks = {}
getgenv().AnimHooks = {}
getgenv().SoundBlockedUntil = {}
getgenv().AnimBlockedUntil = {}
getgenv().SoundStartTime = {}
getgenv().AnimStartTime = {}
getgenv().MaxSoundAge = 1.2
getgenv().MaxAnimAge = 1.5
getgenv().lastBlockTime = 0
getgenv().blockCooldown = 0.2
getgenv().BoxVisualizations = {}
getgenv().KillerFacingAngle = 90

getgenv().FireBlockRemote = function()
    local now = tick()
    if now - getgenv().lastBlockTime < getgenv().blockCooldown then return end
    getgenv().lastBlockTime = now
    pcall(function()
        local args = {
            "UseActorAbility",
            { buffer.fromstring("\003\005\000\000\000Block") }
        }
        game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Network"):WaitForChild("Network"):WaitForChild("RemoteEvent"):FireServer(unpack(args))
    end)
end

getgenv().IsKillerFacingPlayer = function(myRoot,killerRoot)
   if not getgenv().KillerFacingCheckEnabled then return true end
   if not myRoot or not killerRoot then return false end
   local dirToPlayer = (myRoot.Position - killerRoot.Position)
   local flatDir = Vector3.new(dirToPlayer.X, 0, dirToPlayer.Z).Unit
   local killerLookDir = Vector3.new(killerRoot.CFrame.LookVector.X, 0, killerRoot.CFrame.LookVector.Z).Unit
   local dotProduct = killerLookDir:Dot(flatDir)
   local angleInDegrees = math.deg(math.acos(math.clamp(dotProduct,-1,1)))
   return angleInDegrees <= getgenv().KillerFacingAngle
end

getgenv().HasLineOfSight = function(targetRoot)
   if not getgenv().wallCheckEnabled then return true end
   local myRoot = LocalP.Character and LocalP.Character:FindFirstChild("HumanoidRootPart")
   if not myRoot then return false end
   local rayParams = RaycastParams.new()
   rayParams.FilterType = Enum.RaycastFilterType.Exclude
   rayParams.IgnoreWater = true
   rayParams.FilterDescendantsInstances = {LocalP.Character}
   local origin = myRoot.Position
   local direction = targetRoot.Position - origin
   local result = workspace:Raycast(origin,direction,rayParams)
   return not result or result.Instance:IsDescendantOf(targetRoot.Parent)
end

getgenv().IsPlayerInBox = function(myRoot, killerRoot)
   if not myRoot or not killerRoot then return false end
   local forward = killerRoot.CFrame.LookVector
   local effectiveLength = getgenv().BoxLength * getgenv().BoxSizeMultiplier
   local forwardOffset = forward * ((effectiveLength/2) + getgenv().BoxForwardOffset)
   local boxPos = killerRoot.Position + forwardOffset
   local boxCFrame = CFrame.lookAt(boxPos, boxPos + forward * 100)
   local relative = myRoot.Position - boxPos
   local localSpace = boxCFrame:VectorToObjectSpace(relative)
   local halfX = (getgenv().BoxWidth * getgenv().BoxSizeMultiplier) / 2
   local halfY = (getgenv().BoxHeight * getgenv().BoxSizeMultiplier) / 2
   local halfZ = effectiveLength / 2
   return math.abs(localSpace.X) <= halfX and math.abs(localSpace.Y) <= halfY and math.abs(localSpace.Z) <= halfZ
end

getgenv().CheckAllBlockConditions = function(myRoot,killerRoot)
   if not myRoot or not killerRoot then return false end
   if not getgenv().IsPlayerInBox(myRoot, killerRoot) then return false end
   if not getgenv().IsKillerFacingPlayer(myRoot,killerRoot) then return false end
   if not getgenv().HasLineOfSight(killerRoot) then return false end
   return true
end

getgenv().GetSoundIdNumeric = function(snd)
   if not snd or not snd.SoundId then return nil end
   local sid = tostring(snd.SoundId)
   return sid:match("%d+")
end

getgenv().GetAnimIdNumeric = function(anim)
   if not anim or not anim.AnimationId then return nil end
   local aid = tostring(anim.AnimationId)
   return aid:match("%d+")
end

getgenv().GetSoundPosition = function(snd)
   if not snd then return nil end
   if snd.Parent and snd.Parent:IsA("BasePart") then
       return snd.Parent.Position,snd.Parent
   end
   if snd.Parent and snd.Parent:IsA("Attachment") and snd.Parent.Parent and snd.Parent.Parent:IsA("BasePart") then
       return snd.Parent.Parent.Position,snd.Parent.Parent
   end
   local found = snd.Parent and snd.Parent:FindFirstChildWhichIsA("BasePart",true)
   return found and found.Position,found or nil,nil
end

getgenv().GetCharFromDescendant = function(inst)
   if not inst then return nil end
   local mdl = inst:FindFirstAncestorOfClass("Model")
   return mdl and mdl:FindFirstChildOfClass("Humanoid") and mdl or nil
end

getgenv().AttemptBlockSound = function(snd)
   if not getgenv().AutoBlockEnabled then return end
   if not snd or not snd:IsA("Sound") then return end
   if not snd.IsPlaying then return end
   local id = getgenv().GetSoundIdNumeric(snd)
   if not id or not getgenv().AutoBlockSounds[id] then return end
   local now = tick()
   if not getgenv().SoundStartTime[snd] then
       getgenv().SoundStartTime[snd] = now
   end
   local soundAge = now - getgenv().SoundStartTime[snd]
   if soundAge > getgenv().MaxSoundAge then return end
   if getgenv().SoundBlockedUntil[snd] and now < getgenv().SoundBlockedUntil[snd] then return end
   local myRoot = LocalP.Character and LocalP.Character:FindFirstChild("HumanoidRootPart")
   if not myRoot then return end
   local pos,part = getgenv().GetSoundPosition(snd)
   if not pos or not part then return end
   local char = getgenv().GetCharFromDescendant(part)
   local plr = char and Plrs:GetPlayerFromCharacter(char)
   if not plr or plr == LocalP then return end
   local hrp = char:FindFirstChild("HumanoidRootPart")
   if not hrp then return end
   if not getgenv().CheckAllBlockConditions(myRoot,hrp) then return end
   getgenv().FireBlockRemote()
   getgenv().SoundBlockedUntil[snd] = now + 0.8
end

getgenv().AttemptBlockAnim = function(animTrack)
   if not getgenv().AutoBlockEnabled then return end
   if not animTrack or not animTrack.Animation then return end
   if not animTrack.IsPlaying then return end
   local id = getgenv().GetAnimIdNumeric(animTrack.Animation)
   if not id or not getgenv().AutoBlockAnims[id] then return end
   local now = tick()
   if not getgenv().AnimStartTime[animTrack] then
       getgenv().AnimStartTime[animTrack] = now
   end
   local animAge = now - getgenv().AnimStartTime[animTrack]
   if animAge > getgenv().MaxAnimAge then return end
   if getgenv().AnimBlockedUntil[animTrack] and now < getgenv().AnimBlockedUntil[animTrack] then return end
   local myRoot = LocalP.Character and LocalP.Character:FindFirstChild("HumanoidRootPart")
   if not myRoot then return end
   local animator = animTrack.Parent
   if not animator or not animator:IsA("Animator") then return end
   local char = getgenv().GetCharFromDescendant(animator)
   if not char then return end
   local plr = Plrs:GetPlayerFromCharacter(char)
   if not plr or plr == LocalP then return end
   local hrp = char:FindFirstChild("HumanoidRootPart")
   if not hrp then return end
   if not getgenv().CheckAllBlockConditions(myRoot,hrp) then return end
   getgenv().FireBlockRemote()
   getgenv().AnimBlockedUntil[animTrack] = now + 0.8
end

getgenv().HookSound = function(snd)
   if not snd or not snd:IsA("Sound") then return end
   if getgenv().SoundHooks[snd] then return end
   local playConn = snd.Played:Connect(function()
       getgenv().SoundStartTime[snd] = tick()
       task.defer(getgenv().AttemptBlockSound,snd)
   end)
   local propConn = snd:GetPropertyChangedSignal("IsPlaying"):Connect(function()
       if snd.IsPlaying then
           if not getgenv().SoundStartTime[snd] then
               getgenv().SoundStartTime[snd] = tick()
           end
           task.defer(getgenv().AttemptBlockSound,snd)
       else
           getgenv().SoundStartTime[snd] = nil
       end
   end)
   local destroyConn
   destroyConn = snd.Destroying:Connect(function()
       if playConn.Connected then playConn:Disconnect() end
       if propConn.Connected then propConn:Disconnect() end
       if destroyConn.Connected then destroyConn:Disconnect() end
       getgenv().SoundHooks[snd] = nil
       getgenv().SoundBlockedUntil[snd] = nil
       getgenv().SoundStartTime[snd] = nil
   end)
   getgenv().SoundHooks[snd] = {playConn,propConn,destroyConn}
   if snd.IsPlaying then
       getgenv().SoundStartTime[snd] = tick()
       task.defer(getgenv().AttemptBlockSound,snd)
   end
end

getgenv().HookAnimator = function(animator)
   if not animator or not animator:IsA("Animator") then return end
   animator.AnimationPlayed:Connect(function(animTrack)
       pcall(function()
           getgenv().AnimStartTime[animTrack] = tick()
           local playConn = animTrack:GetPropertyChangedSignal("IsPlaying"):Connect(function()
               if animTrack.IsPlaying then
                   if not getgenv().AnimStartTime[animTrack] then
                       getgenv().AnimStartTime[animTrack] = tick()
                   end
                   task.defer(getgenv().AttemptBlockAnim,animTrack)
               else
                   getgenv().AnimStartTime[animTrack] = nil
               end
           end)
           animTrack.Stopped:Connect(function()
               if playConn.Connected then playConn:Disconnect() end
               getgenv().AnimBlockedUntil[animTrack] = nil
               getgenv().AnimStartTime[animTrack] = nil
           end)
           if animTrack.IsPlaying then
               task.defer(getgenv().AttemptBlockAnim,animTrack)
           end
       end)
   end)
end

for _,d in ipairs(game:GetDescendants()) do
   if d:IsA("Sound") then pcall(getgenv().HookSound,d) end
   if d:IsA("Animator") then pcall(getgenv().HookAnimator,d) end
end

game.DescendantAdded:Connect(function(d)
   if d:IsA("Sound") then task.defer(getgenv().HookSound,d) end
   if d:IsA("Animator") then task.defer(getgenv().HookAnimator,d) end
end)

getgenv().CreateBoxVisualization = function(killer)
   if not killer or not killer:FindFirstChild("HumanoidRootPart") then return nil end
   local killerRoot = killer.HumanoidRootPart
   local folder = Instance.new("Folder")
   folder.Name = "BoxVisualization"
   folder.Parent = killerRoot
   local box = Instance.new("Part")
   box.Name = "DetectionBox"
   box.Material = Enum.Material.ForceField
   box.Anchored = true
   box.CanCollide = false
   box.Transparency = getgenv().BoxTransparency
   box.Color = getgenv().BoxDangerColor
   box.Size = Vector3.new(
       getgenv().BoxWidth * getgenv().BoxSizeMultiplier,
       getgenv().BoxHeight * getgenv().BoxSizeMultiplier,
       getgenv().BoxLength * getgenv().BoxSizeMultiplier
   )
   box.Parent = folder
   return {folder = folder, box = box, killer = killer}
end

getgenv().UpdateBoxVisualization = function(visData, myRoot)
   if not visData or not visData.folder or not visData.folder.Parent then return end
   if not myRoot or not visData.killer or not visData.killer:FindFirstChild("HumanoidRootPart") then return end
   local killerRoot = visData.killer.HumanoidRootPart
   local forward = killerRoot.CFrame.LookVector
   local effectiveLength = getgenv().BoxLength * getgenv().BoxSizeMultiplier
   local forwardOffset = forward * ((effectiveLength/2) + getgenv().BoxForwardOffset)
   local boxPos = killerRoot.Position + forwardOffset
   visData.box.Size = Vector3.new(
       getgenv().BoxWidth * getgenv().BoxSizeMultiplier,
       getgenv().BoxHeight * getgenv().BoxSizeMultiplier,
       effectiveLength
   )
   visData.box.CFrame = CFrame.lookAt(boxPos, boxPos + forward * 100)
   visData.box.Transparency = getgenv().BoxTransparency
   local shouldBlock = getgenv().IsPlayerInBox(myRoot, killerRoot) and getgenv().CheckAllBlockConditions(myRoot, killerRoot)
   visData.box.Color = shouldBlock and getgenv().BoxSafeColor or getgenv().BoxDangerColor
end

getgenv().AddBoxVisualization = function(killer)
   if not killer:FindFirstChild("HumanoidRootPart") then return end
   if getgenv().BoxVisualizations[killer] then return end
   local visData = getgenv().CreateBoxVisualization(killer)
   getgenv().BoxVisualizations[killer] = visData
end

getgenv().RemoveBoxVisualization = function(killer)
   if getgenv().BoxVisualizations[killer] then
       if getgenv().BoxVisualizations[killer].folder then
           getgenv().BoxVisualizations[killer].folder:Destroy()
       end
       getgenv().BoxVisualizations[killer] = nil
   end
end

getgenv().RefreshBoxVisualizations = function()
   for killer, _ in pairs(getgenv().BoxVisualizations) do
       getgenv().RemoveBoxVisualization(killer)
   end
   if getgenv().BoxVisualizationEnabled then
       for _,killer in ipairs(getgenv().KillersFolder:GetChildren()) do
           getgenv().AddBoxVisualization(killer)
       end
   end
end

getgenv().GetKillerUsernames = function()
   local killerNames = {}
   if Workspace:FindFirstChild("Players") then
       local playersFolder = Workspace.Players
       if playersFolder:FindFirstChild("Killers") then
           local killersFolder = playersFolder.Killers
           for _, killerModel in pairs(killersFolder:GetChildren()) do
               local killerPlayer = Players:GetPlayerFromCharacter(killerModel)
               if killerPlayer then
                   table.insert(killerNames, killerPlayer.Name)
               else
                   table.insert(killerNames, killerModel.Name)
               end
           end
       end
   end
   return killerNames
end

getgenv().FindKillerHitboxes = function()
   local hitboxes = {}
   local killerNames = getgenv().GetKillerUsernames()
   if #killerNames == 0 then return hitboxes end
   local hitboxesFolder = Workspace:FindFirstChild("Hitboxes")
   if not hitboxesFolder then return hitboxes end
   for _, child in pairs(hitboxesFolder:GetChildren()) do
       if child:IsA("BasePart") and string.find(child.Name, "Hitbox") then
           for _, killerName in pairs(killerNames) do
               if string.find(child.Name, killerName) then
                   hitboxes[child] = true
                   break
               end
           end
       end
   end
   return hitboxes
end

getgenv().EnlargeHitbox = function(hitbox)
   if hitbox and hitbox:IsA("BasePart") then
       if not getgenv().processedHitboxes[hitbox] then
           getgenv().processedHitboxes[hitbox] = {
               originalSize = hitbox.Size,
               originalColor = hitbox.Color,
               originalTransparency = hitbox.Transparency,
               originalMaterial = hitbox.Material
           }
           local multiplier = getgenv().BoxSizeMultiplier
           hitbox.Size = hitbox.Size * multiplier
           hitbox.Color = getgenv().HitboxColor
           hitbox.Transparency = getgenv().HitboxTransparency
       else
           local multiplier = getgenv().BoxSizeMultiplier
           local original = getgenv().processedHitboxes[hitbox]
           hitbox.Size = original.originalSize * multiplier
           hitbox.Color = getgenv().HitboxColor
           hitbox.Transparency = getgenv().HitboxTransparency
       end
   end
end

getgenv().StartHitboxVisualization = function()
   if getgenv().hitboxDetectionLoop then return end
   getgenv().hitboxDetectionLoop = RSvc.Heartbeat:Connect(function()
       if not getgenv().HitboxVisualizationEnabled then return end
       local hitboxes = getgenv().FindKillerHitboxes()
       for hitbox, _ in pairs(hitboxes) do
           pcall(getgenv().EnlargeHitbox, hitbox)
       end
   end)
   print("杀手Hitbox可视化已启用")
end

getgenv().StopHitboxVisualization = function()
   if getgenv().hitboxDetectionLoop then
       getgenv().hitboxDetectionLoop:Disconnect()
       getgenv().hitboxDetectionLoop = nil
   end
   for hitbox, originalData in pairs(getgenv().processedHitboxes) do
       if hitbox and hitbox.Parent then
           pcall(function()
               hitbox.Size = originalData.originalSize
               hitbox.Color = originalData.originalColor
               hitbox.Transparency = originalData.originalTransparency
           end)
       end
   end
   getgenv().processedHitboxes = {}
   print("杀手Hitbox可视化已停止")
end

RSvc.Heartbeat:Connect(function()
   if not getgenv().AutoBlockEnabled then return end
   if not getgenv().BoxVisualizationEnabled then return end
   local myRoot = LocalP.Character and LocalP.Character:FindFirstChild("HumanoidRootPart")
   if not myRoot then return end
   for killer, visData in pairs(getgenv().BoxVisualizations) do
       if killer:FindFirstChild("HumanoidRootPart") then
           pcall(getgenv().UpdateBoxVisualization, visData, myRoot)
       end
   end
end)

getgenv().KillersFolder.ChildAdded:Connect(function(killer)
   if getgenv().BoxVisualizationEnabled then
       task.spawn(function()
           local hrp = killer:WaitForChild("HumanoidRootPart",5)
           if hrp then getgenv().AddBoxVisualization(killer) end
       end)
   end
end)

getgenv().KillersFolder.ChildRemoved:Connect(function(killer)
   getgenv().RemoveBoxVisualization(killer)
end)

local BlockLeft = Tabs.Block:AddLeftGroupbox("自动格挡")
local BlockRight = Tabs.Block:AddRightGroupbox("参数调节")

BlockLeft:AddToggle("AutoBlockToggle",{
   Text = "自动格挡",
   Default = false,
   Tooltip = "开启/关闭自动格挡",
   Callback = function(Value)
       getgenv().AutoBlockEnabled = Value
   end,
})

BlockLeft:AddToggle("HitboxVisualization",{
   Text = "碰撞箱可视化",
   Default = false,
   Tooltip = "显示放大的杀手Hitbox(大小与Box一致)",
   Callback = function(Value)
       getgenv().HitboxVisualizationEnabled = Value
       if Value then
           getgenv().StartHitboxVisualization()
       else
           getgenv().StopHitboxVisualization()
       end
   end,
})

BlockLeft:AddToggle("BoxVisualization",{
   Text = "Box可视化",
   Default = false,
   Tooltip = "显示杀手的检测框（Box）",
   Callback = function(Value)
       getgenv().BoxVisualizationEnabled = Value
       getgenv().RefreshBoxVisualizations()
   end,
})

BlockLeft:AddDivider()

BlockLeft:AddToggle("KillerFacingCheck",{
   Text = "杀手面向检测",
   Default = false,
   Tooltip = "仅在杀手面向玩家时格挡",
   Callback = function(Value)
       getgenv().KillerFacingCheckEnabled = Value
   end,
})

BlockLeft:AddToggle("WallCheck",{
   Text = "Wallcheck",
   Default = false,
   Tooltip = "检测是否有墙体遮挡",
   Callback = function(Value)
       getgenv().wallCheckEnabled = Value
   end,
})

BlockLeft:AddSlider("KillerFacingAngle",{
   Text = "杀手面向角度",
   Default = 90,
   Min = 30,
   Max = 180,
   Rounding = 1,
   Tooltip = "杀手面向玩家的角度检测",
   Callback = function(Value)
       getgenv().KillerFacingAngle = Value
   end,
})

BlockLeft:AddSlider("MaxSoundAge",{
   Text = "最大声音检测时长(秒)",
   Default = 1.2,
   Min = 0.5,
   Max = 5,
   Rounding = 1,
   Tooltip = "声音播放超过此时长后将被忽略",
   Callback = function(Value)
       getgenv().MaxSoundAge = Value
   end,
})

BlockLeft:AddSlider("MaxAnimAge",{
   Text = "最大动画检测时长(秒)",
   Default = 1.5,
   Min = 0.5,
   Max = 5,
   Rounding = 1,
   Tooltip = "动画播放超过此时长后将被忽略",
   Callback = function(Value)
       getgenv().MaxAnimAge = Value
   end,
})

BlockRight:AddLabel("Box 尺寸与透明度")
BlockRight:AddSlider("BoxLength",{
   Text = "Box长度",
   Default = 7.5,
   Min = 1,
   Max = 15,
   Rounding = 1,
   Tooltip = "Box的长度(未应用倍数前)",
   Callback = function(Value)
       getgenv().BoxLength = Value
   end,
})
BlockRight:AddSlider("BoxWidth",{
   Text = "Box宽度",
   Default = 4.5,
   Min = 2,
   Max = 15,
   Rounding = 1,
   Tooltip = "Box的宽度(未应用倍数前)",
   Callback = function(Value)
       getgenv().BoxWidth = Value
   end,
})
BlockRight:AddSlider("BoxHeight",{
   Text = "Box高度",
   Default = 6,
   Min = 2,
   Max = 10,
   Rounding = 1,
   Tooltip = "Box的高度(未应用倍数前)",
   Callback = function(Value)
       getgenv().BoxHeight = Value
   end,
})
BlockRight:AddSlider("BoxSizeMultiplier",{
   Text = "Box整体大小倍数",
   Default = 1.0,
   Min = 0.5,
   Max = 3.0,
   Rounding = 2,
   Tooltip = "Box整体大小的放大倍数",
   Callback = function(Value)
       getgenv().BoxSizeMultiplier = Value
   end,
})
BlockRight:AddSlider("BoxForwardOffset",{
   Text = "Box前后位置",
   Default = 1.4,
   Min = -10,
   Max = 10,
   Rounding = 1,
   Tooltip = "Box在杀手前后方向的偏移(负数向后,正数向前)",
   Callback = function(Value)
       getgenv().BoxForwardOffset = Value
   end,
})
BlockRight:AddSlider("BoxTransparency",{
   Text = "Box透明度",
   Default = 0.7,
   Min = 0,
   Max = 1,
   Rounding = 2,
   Tooltip = "Box的透明度(0=完全不透明,1=完全透明)",
   Callback = function(Value)
       getgenv().BoxTransparency = Value
   end,
})

BlockRight:AddDivider()
BlockRight:AddLabel("Box 安全颜色 (玩家在范围内)")
BlockRight:AddSlider("BoxSafeColorR",{
   Text = "红色 (R)",
   Default = 0,
   Min = 0,
   Max = 255,
   Rounding = 0,
   Callback = function(Value)
       local current = getgenv().BoxSafeColor
       getgenv().BoxSafeColor = Color3.fromRGB(Value, current.G * 255, current.B * 255)
   end,
})
BlockRight:AddSlider("BoxSafeColorG",{
   Text = "绿色 (G)",
   Default = 255,
   Min = 0,
   Max = 255,
   Rounding = 0,
   Callback = function(Value)
       local current = getgenv().BoxSafeColor
       getgenv().BoxSafeColor = Color3.fromRGB(current.R * 255, Value, current.B * 255)
   end,
})
BlockRight:AddSlider("BoxSafeColorB",{
   Text = "蓝色 (B)",
   Default = 0,
   Min = 0,
   Max = 255,
   Rounding = 0,
   Callback = function(Value)
       local current = getgenv().BoxSafeColor
       getgenv().BoxSafeColor = Color3.fromRGB(current.R * 255, current.G * 255, Value)
   end,
})

BlockRight:AddLabel("Box 危险颜色 (玩家不在范围内)")
BlockRight:AddSlider("BoxDangerColorR",{
   Text = "红色 (R)",
   Default = 255,
   Min = 0,
   Max = 255,
   Rounding = 0,
   Callback = function(Value)
       local current = getgenv().BoxDangerColor
       getgenv().BoxDangerColor = Color3.fromRGB(Value, current.G * 255, current.B * 255)
   end,
})
BlockRight:AddSlider("BoxDangerColorG",{
   Text = "绿色 (G)",
   Default = 0,
   Min = 0,
   Max = 255,
   Rounding = 0,
   Callback = function(Value)
       local current = getgenv().BoxDangerColor
       getgenv().BoxDangerColor = Color3.fromRGB(current.R * 255, Value, current.B * 255)
   end,
})
BlockRight:AddSlider("BoxDangerColorB",{
   Text = "蓝色 (B)",
   Default = 0,
   Min = 0,
   Max = 255,
   Rounding = 0,
   Callback = function(Value)
       local current = getgenv().BoxDangerColor
       getgenv().BoxDangerColor = Color3.fromRGB(current.R * 255, current.G * 255, Value)
   end,
})

BlockRight:AddDivider()
BlockRight:AddLabel("Hitbox 颜色与透明度")
BlockRight:AddSlider("HitboxTransparency",{
   Text = "Hitbox透明度",
   Default = 0.5,
   Min = 0,
   Max = 1,
   Rounding = 2,
   Tooltip = "Hitbox的透明度",
   Callback = function(Value)
       getgenv().HitboxTransparency = Value
   end,
})
BlockRight:AddSlider("HitboxColorR",{
   Text = "红色 (R)",
   Default = 255,
   Min = 0,
   Max = 255,
   Rounding = 0,
   Callback = function(Value)
       local current = getgenv().HitboxColor
       getgenv().HitboxColor = Color3.fromRGB(Value, current.G * 255, current.B * 255)
   end,
})
BlockRight:AddSlider("HitboxColorG",{
   Text = "绿色 (G)",
   Default = 255,
   Min = 0,
   Max = 255,
   Rounding = 0,
   Callback = function(Value)
       local current = getgenv().HitboxColor
       getgenv().HitboxColor = Color3.fromRGB(current.R * 255, Value, current.B * 255)
   end,
})
BlockRight:AddSlider("HitboxColorB",{
   Text = "蓝色 (B)",
   Default = 255,
   Min = 0,
   Max = 255,
   Rounding = 0,
   Callback = function(Value)
       local current = getgenv().HitboxColor
       getgenv().HitboxColor = Color3.fromRGB(current.R * 255, current.G * 255, Value)
   end,
})

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local lp = Players.LocalPlayer

local daggerRemote_Hook = nil
task.spawn(function()
    local modules = ReplicatedStorage:WaitForChild("Modules", 10)
    if modules then
        local net1 = modules:WaitForChild("Network", 5)
        if net1 then
            local net2 = net1:WaitForChild("Network", 5)
            if net2 then
                daggerRemote_Hook = net2:WaitForChild("RemoteEvent", 5)
            end
        end
    end
end)

local TargetRemote_Hook = nil
task.spawn(function()
    local modules = ReplicatedStorage:WaitForChild("Modules", 10)
    if modules then
        local net1 = modules:WaitForChild("Network", 5)
        if net1 then
            local net2 = net1:WaitForChild("Network", 5)
            if net2 then
                TargetRemote_Hook = net2:WaitForChild("UnreliableRemoteEvent", 5)
            end
        end
    end
end)

local spoofData = _G.BackstabSpoofData
if not spoofData then
    spoofData = {
        enabled = false,
        target = nil,
        oldNamecall = nil,
        oldFireServer = nil,
        initialized = false
    }
    _G.BackstabSpoofData = spoofData
end

local function replacePositions(args, targetCF)
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local currentPos = hrp and hrp.Position
    if not currentPos then return args end
    for i = 1, #args do
        local v = args[i]
        local t = typeof(v)
        if t == "CFrame" then
            if (v.Position - currentPos).Magnitude < 25 then args[i] = targetCF end
        elseif t == "Vector3" then
            if (v - currentPos).Magnitude < 25 then args[i] = targetCF.Position end
        elseif t == "table" then
            local copy = {}
            for k, val in pairs(v) do
                local vt = typeof(val)
                if vt == "CFrame" then
                    if (val.Position - currentPos).Magnitude < 25 then copy[k] = targetCF else copy[k] = val end
                elseif vt == "Vector3" then
                    if (val - currentPos).Magnitude < 25 then copy[k] = targetCF.Position else copy[k] = val end
                else copy[k] = val end
            end
            args[i] = copy
        end
    end
    return args
end

local function InitPositionSpoof_Hook()
    if spoofData.initialized then return end
    if not TargetRemote_Hook then task.delay(2, InitPositionSpoof_Hook) return end
    if hookmetamethod then
        spoofData.oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if self == TargetRemote_Hook and (method == "FireServer" or method == "fireServer") and spoofData.enabled and spoofData.target then
                local args = {...}
                args = replacePositions(args, spoofData.target)
                return spoofData.oldNamecall(self, unpack(args))
            end
            return spoofData.oldNamecall(self, ...)
        end))
    else
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        spoofData.oldNamecall = mt.__namecall
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if self == TargetRemote_Hook and (method == "FireServer" or method == "fireServer") and spoofData.enabled and spoofData.target then
                local args = {...}
                args = replacePositions(args, spoofData.target)
                return spoofData.oldNamecall(self, unpack(args))
            end
            return spoofData.oldNamecall(self, ...)
        end)
        setreadonly(mt, true)
    end
    if hookfunction then
        spoofData.oldFireServer = hookfunction(TargetRemote_Hook.FireServer, newcclosure(function(self, ...)
            if self == TargetRemote_Hook and spoofData.enabled and spoofData.target then
                local args = {...}
                args = replacePositions(args, spoofData.target)
                return spoofData.oldFireServer(self, unpack(args))
            end
            return spoofData.oldFireServer(self, ...)
        end))
    end
    spoofData.initialized = true
end
task.spawn(InitPositionSpoof_Hook)

_G.Backstab = _G.Backstab or {}
local cfgHook = _G.Backstab
cfgHook.enabled = false
cfgHook.currentMode = "Behind"
cfgHook.attackType = "Normal"
cfgHook.useHookTeleport = false
cfgHook.matchFacing = false
cfgHook.detectRange = 15
cfgHook.tpDistance = 3
cfgHook.adhesionDuration = 0.6
cfgHook.triggerKey = Enum.KeyCode.Q

local isAttackingHook = false
local cooldownHook = false
local lastTargetHook = nil
local isAliveHook = true

local killerNames_Hook = { "Jason", "c00lkidd", "JohnDoe", "1x1x1x1", "Noli", "Slasher", "Sixer" }

local function getKillersFolder_Hook()
    local playersFolder = workspace:FindFirstChild("Players")
    return playersFolder and playersFolder:FindFirstChild("Killers") or nil
end

local counterAnimIDs_Hook = {
    "126830014841198", "126355327951215", "121086746534252",
    "18885909645", "98456918873918", "105458270463374",
    "83829782357897", "125403313786645", "118298475669935",
    "82113744478546", "70371667919898", "99135633258223",
    "97167027849946", "109230267448394", "139835501033932",
    "126896426760253", "109667959938617", "126681776859538",
    "129976080405072", "121293883585738", "81639435858902",
    "137314737492715", "92173139187970"
}

local function killerPlayingCounterAnim_Hook(killer)
    local humanoid = killer:FindFirstChildOfClass("Humanoid")
    if not humanoid or not humanoid:FindFirstChildOfClass("Animator") then return false end
    for _, track in ipairs(humanoid.Animator:GetPlayingAnimationTracks()) do
        if track.Animation and track.Animation.AnimationId then
            local animIdNum = track.Animation.AnimationId:match("%d+")
            for _, id in ipairs(counterAnimIDs_Hook) do
                if tostring(animIdNum) == id then return true end
            end
        end
    end
    return false
end

local function isBehindTarget_Hook(hrp, targetHRP)
    local distance = (hrp.Position - targetHRP.Position).Magnitude
    if distance > cfgHook.detectRange then return false end
    if cfgHook.currentMode == "Around" then return true
    else
        local direction = -targetHRP.CFrame.LookVector
        local toPlayer = (hrp.Position - targetHRP.Position)
        return toPlayer:Dot(direction) > 0.3
    end
end

local function PerformBackstabHook(targetKiller)
    if isAttackingHook then return end
    isAttackingHook = true
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then isAttackingHook = false return end
    local originalCFrame = hrp.CFrame
    if cfgHook.useHookTeleport then spoofData.enabled = true end
    if daggerRemote_Hook then
        pcall(function() daggerRemote_Hook:FireServer("UseActorAbility", {"Dagger"}) end)
    end
    local startTime = tick()
    local faceConn
    faceConn = RunService.RenderStepped:Connect(function()
        if not isAliveHook or not cfgHook.enabled or tick() - startTime >= cfgHook.adhesionDuration or not targetKiller or not targetKiller.Parent then
            if faceConn then faceConn:Disconnect() end
            if cfgHook.useHookTeleport then
                spoofData.enabled = false
                spoofData.target = nil
            end
            if hrp and hrp.Parent then
                hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
                hrp.AssemblyAngularVelocity = Vector3.new(0,0,0)
                hrp.CFrame = originalCFrame
            end
            isAttackingHook = false
            return
        end
        local ping = 50
        pcall(function()
            local pingStr = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString()
            ping = tonumber(pingStr:match("%d+")) or 50
        end)
        local pingSeconds = ping/1000
        local targetVelocity = targetKiller.AssemblyLinearVelocity
        local pingOffset = targetVelocity * pingSeconds
        local predictedPos = targetKiller.Position + pingOffset
        local targetPos
        if cfgHook.currentMode == "Behind" then
            targetPos = predictedPos - (targetKiller.CFrame.LookVector * cfgHook.tpDistance)
        else
            targetPos = predictedPos + (targetKiller.CFrame.RightVector * cfgHook.tpDistance)
        end
        local newCFrame
        if cfgHook.matchFacing then
            newCFrame = CFrame.new(targetPos) * targetKiller.CFrame.Rotation
        else
            newCFrame = CFrame.lookAt(targetPos, predictedPos)
        end
        if cfgHook.useHookTeleport then spoofData.target = newCFrame end
        hrp.CFrame = newCFrame
    end)
end

local function ManualBackstabHook()
    if not cfgHook.enabled or not isAliveHook or isAttackingHook then return end
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local targetKiller = nil
    local minDist = cfgHook.detectRange
    local killersFolder = getKillersFolder_Hook()
    if killersFolder then
        for _, name in ipairs(killerNames_Hook) do
            local killer = killersFolder:FindFirstChild(name)
            if killer and killer:FindFirstChild("HumanoidRootPart") then
                local kHRP = killer.HumanoidRootPart
                local dist = (kHRP.Position - hrp.Position).Magnitude
                if dist <= minDist then
                    minDist = dist
                    targetKiller = kHRP
                end
            end
        end
    end
    if targetKiller then PerformBackstabHook(targetKiller) end
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp or not isAliveHook then return end
    if input.KeyCode == cfgHook.triggerKey then ManualBackstabHook() end
end)

RunService.RenderStepped:Connect(function()
    if not cfgHook.enabled or not isAliveHook or cooldownHook or cfgHook.attackType == "Normal" or isAttackingHook then return end
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local killersFolder = getKillersFolder_Hook()
    if not killersFolder then return end
    for _, name in ipairs(killerNames_Hook) do
        local killer = killersFolder:FindFirstChild(name)
        if killer and killer:FindFirstChild("HumanoidRootPart") then
            local kHRP = killer.HumanoidRootPart
            if cfgHook.attackType == "Legit" then
                local dist = (kHRP.Position - hrp.Position).Magnitude
                if dist <= cfgHook.detectRange then
                    if cfgHook.currentMode == "Behind" then
                        local directionToTarget = (kHRP.Position - hrp.Position).Unit
                        local dot = hrp.CFrame.LookVector:Dot(directionToTarget)
                        if dot > 0.6 then return end
                    end
                    PerformBackstabHook(kHRP)
                end
                return
            end
            if cfgHook.attackType == "Counter" and not killerPlayingCounterAnim_Hook(killer) then continue end
            if isBehindTarget_Hook(hrp, kHRP) and killer ~= lastTargetHook then
                cooldownHook = true
                lastTargetHook = killer
                PerformBackstabHook(kHRP)
                task.delay(2, function() lastTargetHook = nil; cooldownHook = false end)
                break
            end
        end
    end
end)

_G.Backstab.ManualTrigger = ManualBackstabHook
_G.Backstab.SetEnabled = function(s) cfgHook.enabled = s end
_G.Backstab.SetMode = function(m) cfgHook.currentMode = m end
_G.Backstab.SetAttackType = function(t) cfgHook.attackType = t end
_G.Backstab.SetHookTeleport = function(s) cfgHook.useHookTeleport = s end
_G.Backstab.SetMatchFacing = function(s) cfgHook.matchFacing = s end
_G.Backstab.SetDetectRange = function(v) cfgHook.detectRange = v end
_G.Backstab.SetTpDistance = function(v) cfgHook.tpDistance = v end
_G.Backstab.SetAdhesionDuration = function(v) cfgHook.adhesionDuration = v end
_G.Backstab.SetTriggerKey = function(k) cfgHook.triggerKey = k end

local leftGroup = Tabs.Backstab:AddLeftGroupbox("传送背刺")
leftGroup:AddToggle("HookEnable", {
    Text = "启用背刺",
    Default = false,
    Callback = function(s) _G.Backstab.SetEnabled(s) end
})
leftGroup:AddDropdown("HookMode", {
    Text = "攻击模式",
    Values = { "Behind", "Around" },
    Default = "Behind",
    Callback = function(v) _G.Backstab.SetMode(v) end
})
leftGroup:AddDropdown("HookAttackType", {
    Text = "攻击类型",
    Values = { "Normal", "Counter", "Legit" },
    Default = "Normal",
    Callback = function(v) _G.Backstab.SetAttackType(v) end
})
leftGroup:AddToggle("HookTeleport", {
    Text = "Hook传送 (位置欺骗)",
    Default = false,
    Callback = function(s) _G.Backstab.SetHookTeleport(s) end
})
leftGroup:AddToggle("HookMatchFacing", {
    Text = "同步杀手朝向",
    Default = false,
    Callback = function(s) _G.Backstab.SetMatchFacing(s) end
})
leftGroup:AddSlider("HookDetectRange", {
    Text = "检测范围",
    Min = 5, Max = 50, Default = 15, Rounding = 1,
    Callback = function(v) _G.Backstab.SetDetectRange(v) end
})
leftGroup:AddSlider("HookTpDistance", {
    Text = "背刺偏移距离",
    Min = 1, Max = 10, Default = 3, Rounding = 1,
    Callback = function(v) _G.Backstab.SetTpDistance(v) end
})
leftGroup:AddSlider("HookAdhesion", {
    Text = "贴合持续时间 (秒)",
    Min = 0.1, Max = 2.0, Default = 0.6, Rounding = 2,
    Callback = function(v) _G.Backstab.SetAdhesionDuration(v) end
})
local hookLabel = leftGroup:AddLabel("自定义触发键: ")
hookLabel:AddKeyPicker("HookTriggerKey", {
    Default = "Q",
    NoUI = false,
    Text = "自定义触发键",
    Callback = function(key)
        local enumKey = Enum.KeyCode[key]
        _G.Backstab.SetTriggerKey(enumKey or Enum.KeyCode.Q)
    end
})
leftGroup:AddButton("HookManual", {
    Text = "手动触发一次背刺",
    Callback = function() _G.Backstab.ManualTrigger() end
})

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MVP = Tabs.Sat:AddLeftGroupbox("体力设置")

local StaminaSettings = {
    MaxStamina = 100,
    StaminaGain = 25,
    StaminaLoss = 10,
    SprintSpeed = 28,
    InfiniteGain = 9999
}

local SettingToggles = {
    MaxStamina = false,
    StaminaGain = false,
    StaminaLoss = false,
    SprintSpeed = false
}

local SprintingModule = ReplicatedStorage:WaitForChild("Systems"):WaitForChild("Character"):WaitForChild("Game"):WaitForChild("Sprinting")
local GetModule = function() return require(SprintingModule) end

task.spawn(function()
    while true do
        local m = GetModule()
        for key, value in pairs(StaminaSettings) do
            if SettingToggles[key] then
                m[key] = value
            end
        end
        task.wait(0.5)
    end
end)

local bai = {Spr = false}
local connection

MVP:AddToggle('MyToggle', {
    Text = '无限体力',
    Default = false,
    Tooltip = '无限体力',
    Callback = function(state)
        bai.Spr = state
        local Sprinting = GetModule()

        if state then
            Sprinting.StaminaLoss = 0
            Sprinting.StaminaGain = StaminaSettings.InfiniteGain

            if connection then connection:Disconnect() end
            connection = RunService.Heartbeat:Connect(function()
                if not bai.Spr then return end
                Sprinting.StaminaLoss = 0
                Sprinting.StaminaGain = StaminaSettings.InfiniteGain
            end)
        else
            Sprinting.StaminaLoss = 10
            Sprinting.StaminaGain = 25

            if connection then
                connection:Disconnect()
                connection = nil
            end
        end
    end
})

MVP:AddToggle('MaxStaminaToggle', {
    Text = '启用体力调整',
    Default = false,
    Callback = function(Value)
        SettingToggles.MaxStamina = Value
    end
})

MVP:AddToggle('StaminaGainToggle', {
    Text = '启用体力恢复调整',
    Default = false,
    Callback = function(Value)
        SettingToggles.StaminaGain = Value
    end
})

MVP:AddToggle('StaminaLossToggle', {
    Text = '启用体力消耗调整',
    Default = false,
    Callback = function(Value)
        SettingToggles.StaminaLoss = Value
    end
})

MVP:AddToggle('SprintSpeedToggle', {
    Text = '启用奔跑速度调整',
    Default = false,
    Callback = function(Value)
        SettingToggles.SprintSpeed = Value
    end
})

local MVP2 = Tabs.Sat:AddRightGroupbox("调试设置")

MVP2:AddSlider('InfStaminaGainSlider', {
    Text = '无限体力恢复速度',
    Default = 9999,
    Min = 0,
    Max = 10000,
    Rounding = 0,
    Callback = function(Value)
        StaminaSettings.InfiniteGain = Value
        if bai.Spr then
            local Sprinting = GetModule()
            Sprinting.StaminaGain = Value
        end
    end
})

MVP2:AddSlider('MySlider1', {
    Text = '最大体力值',
    Default = 100,
    Min = 0,
    Max = 9999,
    Rounding = 0,
    Callback = function(Value)
        StaminaSettings.MaxStamina = Value
        if SettingToggles.MaxStamina then
            local Sprinting = GetModule()
            Sprinting.MaxStamina = Value
        end
    end
})

MVP2:AddSlider('MySlider2', {
    Text = '体力恢复速度',
    Default = 25,
    Min = 0,
    Max = 500,
    Rounding = 0,
    Callback = function(Value)
        StaminaSettings.StaminaGain = Value
        if SettingToggles.StaminaGain and not bai.Spr then
            local Sprinting = GetModule()
            Sprinting.StaminaGain = Value
        end
    end
})

MVP2:AddSlider('MySlider3', {
    Text = '体力消耗速度',
    Default = 10,
    Min = 0,
    Max = 800,
    Rounding = 0,
    Callback = function(Value)
        StaminaSettings.StaminaLoss = Value
        if SettingToggles.StaminaLoss and not bai.Spr then
            local Sprinting = GetModule()
            Sprinting.StaminaLoss = Value
        end
    end
})

MVP2:AddSlider('MySlider4', {
    Text = '奔跑速度',
    Default = 28,
    Min = 0,
    Max = 200,
    Rounding = 0,
    Callback = function(Value)
        StaminaSettings.SprintSpeed = Value
        if SettingToggles.SprintSpeed then
            local Sprinting = GetModule()
            Sprinting.SprintSpeed = Value
        end
    end
})

local MainGroup = Tabs.Ability:AddLeftGroupbox("自动钩子 & 自动挣脱")

local function CreateFeatures()
    if not Tabs or not Tabs.Ability then
        warn("UI 容器未找到")
        return
    end

    local function getHookEventName()
        local currentPlayer = game.Players.LocalPlayer
        return currentPlayer and (currentPlayer.Name .. "NosHookQTE") or nil
    end

    -- ===== 修改处：自动挣脱事件名改为杀手名字 + NosHookQTE =====
    local function getEndFlightEventName()
        local killers = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Killers")
        if killers then
            local children = killers:GetChildren()
            if #children > 0 then
                local firstKiller = children[1]
                local username = firstKiller:GetAttribute("Username")
                if username and username ~= "" then
                    return username .. "NosHookQTE"
                end
            end
        end
        return nil
    end
    -- ============================================================

    local function updateEventLabel(text)
        if not eventLabel then return end
        if eventLabel.Text ~= nil then
            eventLabel.Text = text
        elseif eventLabel.SetText then
            eventLabel:SetText(text)
        elseif eventLabel.ChangeText then
            eventLabel:ChangeText(text)
        else
            warn("无法更新标签，请手动检查 UI 库")
        end
    end

    local hookRunning = false
    local hookThread = nil
    local hookInterval = 0.1

    local function fireHookEvent()
        local eventName = getHookEventName()
        if not eventName then return end
        pcall(function()
            local remote = game:GetService("ReplicatedStorage")
                :WaitForChild("Modules")
                :WaitForChild("Network")
                :WaitForChild("Network")
                :WaitForChild("RemoteEvent")
            remote:FireServer(eventName, { buffer.fromstring("\001\001") })
        end)
    end

    MainGroup:AddToggle("HookToggle", {
        Text = "自动钩子",
        Default = false,
        Risky = true,
        Callback = function(state)
            hookRunning = state
            if hookThread then
                task.cancel(hookThread)
                hookThread = nil
            end
            if state then
                local eventName = getHookEventName()
                updateEventLabel("钩子事件: " .. (eventName or "未知"))
                hookThread = task.spawn(function()
                    while hookRunning do
                        fireHookEvent()
                        task.wait(hookInterval)
                    end
                end)
            else
                updateEventLabel("钩子事件: 已停止")
            end
        end,
    })

    MainGroup:AddSlider("HookSpeed", {
        Text = "钩子间隔 (秒)",
        Default = 0.1,
        Min = 0.1,
        Max = 1.0,
        Rounding = 2,
        Callback = function(value)
            hookInterval = value
        end
    })

    local endFlightRunning = false
    local endFlightThread = nil
    local endFlightInterval = 0.1

    local function fireEndFlightEvent()
        local eventName = getEndFlightEventName()
        if not eventName then return end
        pcall(function()
            local remote = game:GetService("ReplicatedStorage")
                :WaitForChild("Modules")
                :WaitForChild("Network")
                :WaitForChild("Network")
                :WaitForChild("RemoteEvent")
            remote:FireServer(eventName, { buffer.fromstring("\001\001") })
        end)
    end

    MainGroup:AddToggle("EndFlightToggle", {
        Text = "自动挣脱",
        Default = false,
        Risky = true,
        Callback = function(state)
            endFlightRunning = state
            if endFlightThread then
                task.cancel(endFlightThread)
                endFlightThread = nil
            end
            if state then
                local eventName = getEndFlightEventName()
                updateEventLabel("挣脱事件: " .. (eventName or "未知"))
                endFlightThread = task.spawn(function()
                    while endFlightRunning do
                        fireEndFlightEvent()
                        task.wait(endFlightInterval)
                    end
                end)
            else
                updateEventLabel("挣脱事件: 已停止")
            end
        end,
    })

    MainGroup:AddSlider("EndFlightSpeed", {
        Text = "挣脱间隔 (秒)",
        Default = 0.1,
        Min = 0.1,
        Max = 1.0,
        Rounding = 2,
        Callback = function(value)
            endFlightInterval = value
        end
    })
end

CreateFeatures()

local Generator = Tabs.zdx:AddLeftGroupbox("自动修机")

Generator:AddSlider("RepairSpeed", {
    Text = "修机速度 (s)",
    Default = 4,
    Min = 1,
    Max = 5,
    Rounding = 1,
    Compact = false,
    Callback = function(v)
        _G.CustomSpeed = v
    end
})

Generator:AddToggle("AutoGenerator",{
    Text = "自动修机",
    Default = false,
    Callback = function(v)
        _G.AutoGen = v
        task.spawn(function()
            while _G.AutoGen do
                if game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("PuzzleUI") then
                    local delayTime = _G.CustomSpeed or 4
                    
                    wait(delayTime)
                    
                    for _,v in ipairs(workspace["Map"]["Ingame"]["Map"]:GetChildren()) do
                        if v.Name == "Generator" then
                            v["Remotes"]["RE"]:FireServer()
                        end
                    end
                end
                wait()
            end
        end)
    end
})

local GeneratorGroup = Tabs.zdx:AddLeftGroupbox("秒修机")

local genState = { enabled = false, interval = 2, task = nil }

local function repairGenerators()
    local mapFolder = workspace:FindFirstChild("Map")
    if not mapFolder then return end
    local ingameFolder = mapFolder:FindFirstChild("Ingame")
    if not ingameFolder then return end
    local mapSubFolder = ingameFolder:FindFirstChild("Map")
    if not mapSubFolder then return end
    
    for _, obj in ipairs(mapSubFolder:GetChildren()) do
        if obj.Name == "Generator" and obj:FindFirstChild("Progress") and obj.Progress.Value < 100 then
            local remote = obj:FindFirstChild("Remotes") and obj.Remotes:FindFirstChild("RE")
            if remote then
                pcall(function() remote:FireServer() end)
            end
        end
    end
end

local function startGeneratorLoop()
    if genState.task then return end
    genState.task = task.spawn(function()
        while genState.enabled do
            repairGenerators()
            task.wait(genState.interval)
        end
        genState.task = nil
    end)
end

local function stopGeneratorLoop()
    if genState.task then
        task.cancel(genState.task)
        genState.task = nil
    end
end

GeneratorGroup:AddToggle("AutoGenToggle", {
    Text = "秒修机",
    Default = false,
    Callback = function(v)
        genState.enabled = v
        if v then
            startGeneratorLoop()
        else
            stopGeneratorLoop()
        end
    end
})

GeneratorGroup:AddSlider("GenInterval", {
    Text = "执行间隔 (秒)",
    Min = 0.5,
    Max = 5,
    Default = 2,
    Rounding = 1,
    Callback = function(v)
        genState.interval = v
        if genState.enabled then
            stopGeneratorLoop()
            startGeneratorLoop()
        end
    end
})

GeneratorGroup:AddButton({
    Text = "立即修理一次",
    Func = function()
        repairGenerators()
        Library:Notify("已尝试修理所有发电机", 2)
    end
})

print("[Obsidian UI] 自动快速发电机模块已加载")

-- ==================== 连线修机核心 ====================
do
    local CONFIG = {
        AutoConnect = false,
        ConnectionSpeed = 1,
        MaxWaitTime = 3,
        NodesPerUpdate = 5,
    }

    local function getDirection(currentRow, currentCol, otherRow, otherCol)
        if otherRow < currentRow then return "up" end
        if otherRow > currentRow then return "down" end
        if otherCol < currentCol then return "left" end
        if otherCol > currentCol then return "right" end
        return nil
    end

    local function getConnections(prev, curr, nextnode)
        local connections = {}
        if prev and curr then
            local dir = getDirection(curr.row, curr.col, prev.row, prev.col)
            if dir == "up" then dir = "down"
            elseif dir == "down" then dir = "up"
            elseif dir == "left" then dir = "right"
            elseif dir == "right" then dir = "left" end
            if dir then connections[dir] = true end
        end
        if nextnode and curr then
            local dir = getDirection(curr.row, curr.col, nextnode.row, nextnode.col)
            if dir then connections[dir] = true end
        end
        return connections
    end

    local function isNeighbourLocal(r1, c1, r2, c2)
        if r2 == r1 - 1 and c2 == c1 then return "up" end
        if r2 == r1 + 1 and c2 == c1 then return "down" end
        if r2 == r1 and c2 == c1 - 1 then return "left" end
        if r2 == r1 and c2 == c1 + 1 then return "right" end
        return false
    end

    local function coordKey(node)
        return string.format("%d-%d", node.row, node.col)
    end

    local function orderPathFromEndpoints(path, endpoints)
        if not path or #path == 0 then return path end

        local startEndpoint
        for _, ep in ipairs(endpoints or {}) do
            for _, n in ipairs(path) do
                if n.row == ep.row and n.col == ep.col then
                    startEndpoint = { row = ep.row, col = ep.col }
                    break
                end
            end
            if startEndpoint then break end
        end

        if not startEndpoint then
            local inPath = {}
            for _, n in ipairs(path) do inPath[coordKey(n)] = n end

            for _, n in ipairs(path) do
                local neighbours = 0
                local dirs = { { n.row - 1, n.col }, { n.row + 1, n.col }, { n.row, n.col - 1 }, { n.row, n.col + 1 } }
                for _, dir in ipairs(dirs) do
                    local r, c = dir[1], dir[2]
                    if inPath[string.format("%d-%d", r, c)] then neighbours = neighbours + 1 end
                end
                if neighbours == 1 then
                    startEndpoint = { row = n.row, col = n.col }
                    break
                end
            end
        end

        if not startEndpoint then
            startEndpoint = { row = path[1].row, col = path[1].col }
        end

        local remaining = {}
        for _, n in ipairs(path) do remaining[coordKey(n)] = { row = n.row, col = n.col } end

        local ordered = {}
        local current = { row = startEndpoint.row, col = startEndpoint.col }
        table.insert(ordered, { row = current.row, col = current.col })
        remaining[coordKey(current)] = nil

        while true do
            local size = 0
            for _ in pairs(remaining) do size = size + 1 end
            if size <= 0 then break end

            local foundNext = false
            for key, node in pairs(remaining) do
                if isNeighbourLocal(current.row, current.col, node.row, node.col) then
                    table.insert(ordered, { row = node.row, col = node.col })
                    remaining[key] = nil
                    current = node
                    foundNext = true
                    break
                end
            end
            if not foundNext then return path end
        end
        return ordered
    end

    local function drawSolutionOneByOne(puzzle)
        if not puzzle or not puzzle.Solution then return end

        local totalPaths = #puzzle.Solution
        local indices = {}
        for i = 1, totalPaths do table.insert(indices, i) end

        for i = totalPaths, 2, -1 do
            local j = math.random(i)
            indices[i], indices[j] = indices[j], indices[i]
        end

        for _, colorIndex in ipairs(indices) do
            local path = puzzle.Solution[colorIndex]
            local endpoints = puzzle.targetPairs and puzzle.targetPairs[colorIndex] or nil
            local orderedPath = orderPathFromEndpoints(path, endpoints)

            puzzle.paths = puzzle.paths or {}
            puzzle.paths[colorIndex] = {}
            puzzle.gridConnections = puzzle.gridConnections or {}

            for i = 1, #orderedPath do
                local node = orderedPath[i]
                table.insert(puzzle.paths[colorIndex], { row = node.row, col = node.col })

                local prev = orderedPath[i - 1]
                local nextNode = orderedPath[i + 1]
                local conn = getConnections(prev, node, nextNode)
                puzzle.gridConnections[string.format("%d-%d", node.row, node.col)] = conn

                if i % CONFIG.NodesPerUpdate == 0 or i == #orderedPath then
                    pcall(function() puzzle:updateGui() end)
                    task.wait(CONFIG.ConnectionSpeed)
                end
            end

            pcall(function() puzzle:checkForWin() end)
            task.wait(CONFIG.ConnectionSpeed * 0.5)
        end

        pcall(function() puzzle:updateGui() end)
        pcall(function() puzzle:checkForWin() end)
    end

    local function setupHook()
        local flowGamePath = ReplicatedStorage:WaitForChild("Modules", 5)
        if not flowGamePath then return false end

        local misc = flowGamePath:FindFirstChild("Minigames")
        if not misc then return false end

        local flowGameManager = misc:FindFirstChild("FlowGameManager")
        if not flowGameManager then return false end

        local flowGame = flowGameManager:FindFirstChild("FlowGame")
        if not flowGame then return false end

        local success, FlowGameModule = pcall(require, flowGame)
        if not success or not FlowGameModule then return false end

        if not FlowGameModule.new then return false end

        local oldNew = FlowGameModule.new
        FlowGameModule.new = function(...)
            local args = { ... }
            local output = { oldNew(unpack(args)) }
            local puzzle = output[1]

            if puzzle and puzzle.Solution and CONFIG.AutoConnect then
                task.spawn(function()
                    local startTime = tick()
                    while CONFIG.AutoConnect and tick() - startTime < CONFIG.MaxWaitTime do
                        if LocalPlayer.PlayerGui:FindFirstChild("PuzzleUI") then
                            drawSolutionOneByOne(puzzle)
                            break
                        end
                        task.wait(0.3)
                    end
                end)
            end

            return unpack(output)
        end

        return true
    end

    setupHook()

    -- 对外暴露配置接口（供 UI 回调使用）
    getgenv().FlowConnect = {
        SetEnabled = function(v) CONFIG.AutoConnect = v end,
        SetSpeed = function(v) CONFIG.ConnectionSpeed = math.max(0.001, v) end,
        GetStatus = function() return CONFIG.AutoConnect, CONFIG.ConnectionSpeed end,
    }
end

-- ===== UI 控件（放入 Tabs.zdx 的合适位置） =====
local ConnectGroup = Tabs.zdx:AddLeftGroupbox("连线修机")

ConnectGroup:AddSlider("ConnectSpeed", {
    Text = "连线速度",
    Default = 0.1,
    Min = 0.1,
    Max = 5,
    Rounding = 1,
    Compact = false,
    Callback = function(v)
        getgenv().FlowConnect.SetSpeed(v)
    end
})

ConnectGroup:AddToggle("AutoConnectToggle", {
    Text = "启用连线",
    Default = false,
    Callback = function(v)
        getgenv().FlowConnect.SetEnabled(v)
    end
})

if Tabs.zdx then
    local instantGroup = Tabs.zdx:AddLeftGroupbox("秒互动")
    local instantInteractRunning = false
    local instantInteractThread = nil
    local instantInteractConn = nil

    local function startInstantInteract()
        if instantInteractRunning then return end
        instantInteractRunning = true
        local promptService = game:GetService("ProximityPromptService")
        instantInteractConn = promptService.PromptButtonHoldBegan:Connect(function(prompt)
            prompt.HoldDuration = 0
        end)
        instantInteractThread = task.spawn(function()
            while instantInteractRunning do
                for _, prompt in next, workspace:GetDescendants() do
                    if prompt:IsA("ProximityPrompt") then
                        prompt.HoldDuration = 0
                    end
                end
                task.wait(1)
            end
        end)
    end

    local function stopInstantInteract()
        instantInteractRunning = false
        if instantInteractThread then task.cancel(instantInteractThread); instantInteractThread = nil end
        if instantInteractConn then instantInteractConn:Disconnect(); instantInteractConn = nil end
    end

    instantGroup:AddToggle("InstantInteractToggle", {
        Text = "秒互动",
        Default = false,
        Callback = function(state)
            if state then startInstantInteract() else stopInstantInteract() end
        end
    })
else
    warn("修机标签页不存在，无法添加秒互动")
end

local KillerSurvival = Tabs.zdx:AddRightGroupbox('传送修机[危险]')

KillerSurvival:AddButton({
    Text = '传送到发电机',
    Func = function()
        local player = game.Players.LocalPlayer
        local character = player.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then return end
        
        local generators = workspace.Map.Ingame.Map:GetChildren()
        for _, generator in ipairs(generators) do
            if generator.Name == "Generator" and 
               generator:FindFirstChild("Progress") and 
               generator.Progress.Value < 100 then
                
                local generatorPart = generator:FindFirstChild("Main") or  
                                     generator:FindFirstChild("Model") or
                                     generator:FindFirstChild("Base")
                
                if generatorPart then
                    character.HumanoidRootPart.CFrame = generatorPart.CFrame + Vector3.new(0, 3, 0)
                    return  
                end
            end
        end
        warn("没有找到可修理的发电机")
    end
})

local ZZ = Tabs.zdx:AddRightGroupbox('切换服务器')

ZZ:AddButton({
    Text = "Switching server", 
    Func = function()
        local TeleportService = game:GetService("TeleportService")
        local Players = game:GetService("Players")
        local HttpService = game:GetService("HttpService")
        
        local requestFunc = http_request or syn.request or request
        if not requestFunc then return end
            
        local url = "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
        local response = requestFunc({Url = url, Method = "GET"})
        
        if response.StatusCode == 200 then
            local data = HttpService:JSONDecode(response.Body)
            if data and data.data and #data.data > 0 then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, data.data[math.random(1, #data.data)].id, Players.LocalPlayer)
            end
        end
    end
})

local generalGroup
local survivorGroup
local killerGroup

if Tabs.Aimbot.AddRightGroupbox then
    generalGroup = Tabs.Aimbot:AddLeftGroupbox("通用自瞄")
    survivorGroup = Tabs.Aimbot:AddLeftGroupbox("杀手自瞄")
    killerGroup = Tabs.Aimbot:AddRightGroupbox("幸存者自瞄")
else
    generalGroup = Tabs.Aimbot:AddLeftGroupbox("通用自瞄")
    survivorGroup = Tabs.Aimbot:AddLeftGroupbox("杀手自瞄")
    killerGroup = Tabs.Aimbot:AddLeftGroupbox("幸存者自瞄")
end

if not generalGroup or not survivorGroup or not killerGroup then
    error("无法创建 UI 分栏，请检查你的 UI 框架变量名")
end

local settings = {
    distance = 100,
    smoothness = 20,
    duration = 50,
    targetPath = "auto",
    globalSound = false,
    debug = true,
    silentAim = false,
    janeDoe = false,
    janeDoeAxe = false,
    chance = false,
    dusekkar = false,
    onex4 = false,
    cookidd = false,
    noilStar = false,
    noilVoid = false,
    punch = false,
}

local function debugPrint(...)
    if settings.debug then
        print("[通用自瞄调试]", ...)
    end
end

pcall(function()
    generalGroup:AddSlider("GAA_Distance", {
        Text = "自瞄距离",
        Default = settings.distance,
        Min = 10,
        Max = 500,
        Rounding = 1,
        Callback = function(v) settings.distance = v end
    })
end)
pcall(function()
    generalGroup:AddSlider("GAA_Smoothness", {
        Text = "相机平滑度",
        Default = settings.smoothness,
        Min = 0,
        Max = 100,
        Rounding = 1,
        Callback = function(v) settings.smoothness = v end
    })
end)
pcall(function()
    generalGroup:AddSlider("GAA_Duration", {
        Text = "锁定时间 ",
        Default = settings.duration,
        Min = 1,
        Max = 200,
        Rounding = 1,
        Callback = function(v) settings.duration = v end
    })
end)
pcall(function()
    generalGroup:AddTextbox("GAA_TargetPath", {
        Text = "目标路径（留空自动探测）",
        Default = "",
        Placeholder = "例如: workspace.Players",
        Callback = function(v)
            settings.targetPath = (v ~= "" and v) or "auto"
        end
    })
end)
pcall(function()
    generalGroup:AddToggle("SilentAimToggle", {
        Text = "静默自瞄（杀手）",
        Default = false,
        Callback = function(v) toggleModule("SilentAim", v) end
    })
end)
pcall(function()
    generalGroup:AddToggle("SoundTriggerToggle", {
        Text = "声音触发自瞄",
        Default = false,
        Callback = function(v) toggleModule("SoundTrigger", v) end
    })
end)

pcall(function()
    survivorGroup:AddToggle("Onex4Toggle", {
        Text = "1x4 自瞄",
        Default = false,
        Callback = function(v) toggleModule("1x4", v) end
    })
end)
pcall(function()
    survivorGroup:AddToggle("CookiddToggle", {
        Text = "C00kidd 自瞄（相机）",
        Default = false,
        Callback = function(v) toggleModule("C00kidd", v) end
    })
end)
pcall(function()
    survivorGroup:AddToggle("JohnDoeToggle", {
        Text = "JohnDoe 自瞄（相机）",
        Default = false,
        Callback = function(v) toggleModule("JohnDoe", v) end
    })
end)
pcall(function()
    survivorGroup:AddToggle("NosferatuToggle", {
        Text = "Nosferatu 自瞄（相机）",
        Default = false,
        Callback = function(v) toggleModule("Nosferatu", v) end
    })
end)
pcall(function()
    survivorGroup:AddToggle("NoilStarToggle", {
        Text = "Noil 星星炸弹自瞄",
        Default = false,
        Callback = function(v) toggleModule("NoilStar", v) end
    })
end)
pcall(function()
    survivorGroup:AddToggle("NoilVoidToggle", {
        Text = "Noil 虚空冲刺自瞄",
        Default = false,
        Callback = function(v) toggleModule("NoilVoid", v) end
    })
end)

pcall(function()
    killerGroup:AddToggle("JaneDoeToggle", {
        Text = "Jane Doe 自瞄",
        Default = false,
        Callback = function(v) toggleModule("JaneDoe", v) end
    })
end)
pcall(function()
    killerGroup:AddToggle("JaneDoeAxeToggle", {
        Text = "Jane Doe 斧头自瞄",
        Default = false,
        Callback = function(v) toggleModule("JaneDoeAxe", v) end
    })
end)
pcall(function()
    killerGroup:AddToggle("ChanceToggle", {
        Text = "Chance 自瞄",
        Default = false,
        Callback = function(v) toggleModule("Chance", v) end
    })
end)
pcall(function()
    killerGroup:AddToggle("DusekkarToggle", {
        Text = "Dusekkar 自瞄（相机）",
        Default = false,
        Callback = function(v) toggleModule("Dusekkar", v) end
    })
end)
pcall(function()
    killerGroup:AddToggle("PunchToggle", {
        Text = "拳击自瞄",
        Default = false,
        Callback = function(v) toggleModule("Punch", v) end
    })
end)

-- ========== 核心功能（不变） ==========
local function getTargetsFromPath(pathString)
    if pathString == "auto" then return nil end
    local parts = {}
    for part in string.gmatch(pathString, "[^%.]+") do
        table.insert(parts, part)
    end
    local current = _G
    for _, part in ipairs(parts) do
        current = current[part]
        if not current then break end
    end
    return current
end

function getNearestTarget()
    local player = game.Players.LocalPlayer
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    local myHRP = player.Character.HumanoidRootPart
    local nearest, nearestDist = nil, math.huge

    local targetContainer = nil
    local path = settings.targetPath

    if path == "auto" then
        local candidates = {
            workspace:FindFirstChild("Players"),
            workspace:FindFirstChild("Characters"),
            workspace:FindFirstChild("Living"),
            workspace:FindFirstChild("Game") and workspace.Game:FindFirstChild("Players"),
            workspace:FindFirstChild("Model") and workspace.Model:FindFirstChild("Players"),
        }
        for _, container in ipairs(candidates) do
            if container and (container:IsA("Folder") or container:IsA("Model")) then
                local hasPlayer = false
                for _, child in ipairs(container:GetChildren()) do
                    if child:IsA("Model") and child:FindFirstChild("HumanoidRootPart") then
                        hasPlayer = true
                        break
                    end
                end
                if hasPlayer then
                    targetContainer = container
                    debugPrint("自动探测到目标容器:", container:GetFullName())
                    break
                end
            end
        end
        if not targetContainer then
            debugPrint("未探测到专用容器，将遍历workspace所有带Humanoid的模型")
            targetContainer = workspace
        end
    else
        local obj = getTargetsFromPath(path)
        if obj then
            targetContainer = obj
            debugPrint("使用用户指定路径:", path)
        else
            debugPrint("用户指定路径无效，回退到自动探测")
            targetContainer = workspace
        end
    end

    local function processModel(model)
        if model:IsA("Model") and model:FindFirstChild("HumanoidRootPart") then
            if model == player.Character then return end
            local hrp = model.HumanoidRootPart
            local dist = (hrp.Position - myHRP.Position).Magnitude
            if dist < nearestDist and dist <= settings.distance then
                nearestDist = dist
                nearest = model
            end
        end
    end

    if targetContainer == workspace then
        for _, child in ipairs(workspace:GetChildren()) do
            processModel(child)
        end
    else
        for _, child in ipairs(targetContainer:GetChildren()) do
            processModel(child)
        end
    end

    if nearest then
        debugPrint("锁定目标:", nearest:GetFullName(), "距离:", nearestDist)
    end
    return nearest
end

function SmoothCameraLookAt(currentCamCF, targetPos, progress)
    local targetLook = (targetPos - currentCamCF.Position).Unit
    local currentLook = currentCamCF.LookVector
    local newLook = currentLook:Lerp(targetLook, progress)
    return CFrame.lookAt(currentCamCF.Position, currentCamCF.Position + newLook * 100)
end

local activeAimConnection = nil
function executeAim()
    if activeAimConnection then
        activeAimConnection:Disconnect()
        activeAimConnection = nil
    end

    local target = getNearestTarget()
    if not target or not target:FindFirstChild("HumanoidRootPart") then
        return
    end

    local totalFrames = settings.duration
    local smoothPower = settings.smoothness / 100
    local currentFrame = 0
    local conn

    conn = game:GetService("RunService").RenderStepped:Connect(function()
        currentFrame = currentFrame + 1
        local progress = math.clamp(currentFrame / totalFrames, 0, 1)
        progress = progress ^ (1 - smoothPower)

        if currentFrame <= totalFrames then
            local currentCamCF = workspace.CurrentCamera.CFrame
            local targetPos = target.HumanoidRootPart.Position
            workspace.CurrentCamera.CFrame = SmoothCameraLookAt(currentCamCF, targetPos, progress)
        else
            conn:Disconnect()
            if activeAimConnection == conn then
                activeAimConnection = nil
            end
        end
    end)

    activeAimConnection = conn
end

local triggerConnections = {}
local function clearConnections()
    for _, conn in ipairs(triggerConnections) do
        conn:Disconnect()
    end
    triggerConnections = {}
end

local modules = {}

function registerTriggerModule(name, enableFunc, disableFunc)
    modules[name] = {
        enabled = false,
        enable = enableFunc,
        disable = disableFunc,
    }
end

function toggleModule(name, state)
    local mod = modules[name]
    if not mod then return end
    if state and not mod.enabled then
        mod.enable()
        mod.enabled = true
        debugPrint("模块 " .. name .. " 已启用")
    elseif not state and mod.enabled then
        mod.disable()
        mod.enabled = false
        debugPrint("模块 " .. name .. " 已禁用")
    end
end

local function getPlayingAnimationIds(humanoid)
    local ids = {}
    if humanoid then
        for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
            if track.Animation and track.Animation.AnimationId then
                local id = track.Animation.AnimationId:match("%d+")
                if id then ids[id] = true end
            end
        end
    end
    return ids
end

function createAnimationTrigger(moduleName, animIds, targetType, useCamera)
    local humanoid = nil
    local hrp = nil
    local isActive = false
    local lastTriggerTime = 0

    local function getTarget()
        if targetType then
            local folder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild(targetType)
            if not folder then return nil end
            local player = game.Players.LocalPlayer
            if not hrp then return nil end
            local closest, closestDist = nil, math.huge
            for _, model in ipairs(folder:GetChildren()) do
                if model:IsA("Model") and model:FindFirstChild("HumanoidRootPart") and model ~= player.Character then
                    local dist = (model.HumanoidRootPart.Position - hrp.Position).Magnitude
                    if dist < closestDist and dist <= settings.distance then
                        closestDist = dist
                        closest = model
                    end
                end
            end
            return closest
        else
            return getNearestTarget()
        end
    end

    local function onRenderStep()
        if not isActive or not humanoid or not hrp then return end
        local playing = getPlayingAnimationIds(humanoid)
        local triggered = false
        for id in pairs(animIds) do
            if playing[id] then triggered = true break end
        end
        if triggered then
            lastTriggerTime = tick()
            local target = getTarget()
            if target and target:FindFirstChild("HumanoidRootPart") then
                if useCamera then
                    local targetPos = target.HumanoidRootPart.Position
                    local cam = workspace.CurrentCamera
                    local direction = (targetPos - cam.CFrame.Position).Unit
                    cam.CFrame = CFrame.lookAt(cam.CFrame.Position, cam.CFrame.Position + direction)
                else
                    local direction = (target.HumanoidRootPart.Position - hrp.Position).Unit
                    local yRot = math.atan2(-direction.X, -direction.Z)
                    hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, yRot, 0)
                    if targetType == "Dusekkar" or targetType == "JaneDoe" then
                        workspace.CurrentCamera.CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position, target.HumanoidRootPart.Position)
                    end
                end
            end
        end
    end

    local function setupCharacter(char)
        if char == game.Players.LocalPlayer.Character then
            humanoid = char:WaitForChild("Humanoid")
            hrp = char:WaitForChild("HumanoidRootPart")
        end
    end

    local function enable()
        isActive = true
        local player = game.Players.LocalPlayer
        if player.Character then setupCharacter(player.Character) end
        player.CharacterAdded:Connect(setupCharacter)
        local conn = game:GetService("RunService").RenderStepped:Connect(onRenderStep)
        table.insert(triggerConnections, conn)
        return conn
    end

    local function disable()
        isActive = false
        humanoid = nil
        hrp = nil
    end

    registerTriggerModule(moduleName, enable, disable)
end

-- ========== 替换后的静默自瞄（来自第二段） ==========
local silentAimEnabled = false
local silentAimDistance = 100
local silentAimConnection = nil
local silentTarget = nil

function isKiller()
    local killersFolder = workspace.Players and workspace.Players:FindFirstChild("Killers")
    local LocalPlayer = game.Players.LocalPlayer
    if killersFolder and LocalPlayer.Character then
        for _, v in ipairs(killersFolder:GetChildren()) do
            if v == LocalPlayer.Character then return true end
        end
    end
    return false
end

function getClosestSurvivor()
    local survivorsFolder = workspace.Players and workspace.Players:FindFirstChild("Survivors")
    if not survivorsFolder then return nil end
    local LocalPlayer = game.Players.LocalPlayer
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
    local myPos = char.HumanoidRootPart.Position
    local closest = nil
    local shortest = math.huge
    for _, model in ipairs(survivorsFolder:GetChildren()) do
        if model:IsA("Model") and model:FindFirstChild("HumanoidRootPart") then
            local dist = (model.HumanoidRootPart.Position - myPos).Magnitude
            if dist < shortest and dist <= silentAimDistance then
                shortest = dist
                closest = model
            end
        end
    end
    return closest
end

function faceTarget(model)
    if not model or not model:FindFirstChild("HumanoidRootPart") then return end
    local LocalPlayer = game.Players.LocalPlayer
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local root = char.HumanoidRootPart
    local targetPos = model.HumanoidRootPart.Position
    root.CFrame = CFrame.new(root.Position, Vector3.new(targetPos.X, root.Position.Y, targetPos.Z))
end

function StartSilentAim()
    if silentAimConnection then silentAimConnection:Disconnect() end
    silentAimConnection = game:GetService("RunService").Heartbeat:Connect(function()
        if not silentAimEnabled or not isKiller() then return end
        silentTarget = getClosestSurvivor()
        if silentTarget then faceTarget(silentTarget) end
    end)
end

registerTriggerModule("SilentAim",
    function()
        silentAimEnabled = true
        StartSilentAim()
    end,
    function()
        silentAimEnabled = false
        if silentAimConnection then
            silentAimConnection:Disconnect()
            silentAimConnection = nil
        end
    end
)

-- ========== 修正后可用的 Noil 自瞄（第二段修复） ==========
local johnaim = false
local Noloop = nil
local No2loop = nil

local aimbotNoilsounds = {
    "StarBomb", "StarBombTrail", "StarBombExplosion"
}

local aimbotNoilsounds2 = {
    "VoidRush", "VoidRushTrail"
}

function NoilStarAim(state)
    johnaim = state
    local LocalPlayer = game.Players.LocalPlayer
    -- 确保角色存在且为 Noli（否则发出警告并返回）
    if LocalPlayer.Character and LocalPlayer.Character.Name ~= "Noli" and state then
        warn("角色不是 Noli")
        return
    end
    if state then
        if Noloop then Noloop:Disconnect() end
        -- 等待角色 HumanoidRootPart 出现
        local char = LocalPlayer.Character
        if not char then return end
        local rootPart = char:FindFirstChild("HumanoidRootPart")
        if not rootPart then
            -- 如果还没加载，等待它出现
            rootPart = char:WaitForChild("HumanoidRootPart")
        end
        Noloop = rootPart.ChildAdded:Connect(function(child)
            if not johnaim then return end
            for _, v in pairs(aimbotNoilsounds) do
                if child.Name == v then
                    -- 获取所有其他玩家
                    local survivors = {}
                    for _, player in pairs(game.Players:GetPlayers()) do
                        if player ~= LocalPlayer then
                            local character = player.Character
                            if character and character:FindFirstChild("HumanoidRootPart") then
                                table.insert(survivors, character)
                            end
                        end
                    end
                    -- 找最近的
                    local nearestSurvivor = nil
                    local shortestDistance = math.huge
                    local playerHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if not playerHRP then return end
                    for _, survivor in pairs(survivors) do
                        local survivorHRP = survivor.HumanoidRootPart
                        local distance = (survivorHRP.Position - playerHRP.Position).Magnitude
                        if distance < shortestDistance then
                            shortestDistance = distance
                            nearestSurvivor = survivor
                        end
                    end
                    if nearestSurvivor then
                        local nearestHRP = nearestSurvivor.HumanoidRootPart
                        if playerHRP then
                            local num = 1
                            while num <= 50 do
                                task.wait(0.01)
                                num = num + 1
                                workspace.CurrentCamera.CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position, nearestHRP.Position)
                                playerHRP.CFrame = CFrame.lookAt(playerHRP.Position, Vector3.new(nearestHRP.Position.X, nearestHRP.Position.Y, nearestHRP.Position.Z))
                            end
                        end
                    end
                end
            end
        end)
    else
        if Noloop then
            Noloop:Disconnect()
            Noloop = nil
        end
    end
end

function NoilVoidAim(state)
    johnaim = state
    local LocalPlayer = game.Players.LocalPlayer
    if LocalPlayer.Character and LocalPlayer.Character.Name ~= "Noli" and state then
        warn("角色不是 Noli")
        return
    end
    if state then
        if No2loop then No2loop:Disconnect() end
        local char = LocalPlayer.Character
        if not char then return end
        local rootPart = char:FindFirstChild("HumanoidRootPart")
        if not rootPart then
            rootPart = char:WaitForChild("HumanoidRootPart")
        end
        No2loop = rootPart.ChildAdded:Connect(function(child)
            if not johnaim then return end
            for _, v in pairs(aimbotNoilsounds2) do
                if child.Name == v then
                    local survivors = {}
                    for _, player in pairs(game.Players:GetPlayers()) do
                        if player ~= LocalPlayer then
                            local character = player.Character
                            if character and character:FindFirstChild("HumanoidRootPart") then
                                table.insert(survivors, character)
                            end
                        end
                    end
                    local nearestSurvivor = nil
                    local shortestDistance = math.huge
                    local playerHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if not playerHRP then return end
                    for _, survivor in pairs(survivors) do
                        local survivorHRP = survivor.HumanoidRootPart
                        local distance = (survivorHRP.Position - playerHRP.Position).Magnitude
                        if distance < shortestDistance then
                            shortestDistance = distance
                            nearestSurvivor = survivor
                        end
                    end
                    if nearestSurvivor then
                        local nearestHRP = nearestSurvivor.HumanoidRootPart
                        if playerHRP then
                            local num = 1
                            while num <= 50 do
                                task.wait(0.01)
                                num = num + 1
                                workspace.CurrentCamera.CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position, nearestHRP.Position)
                                playerHRP.CFrame = CFrame.lookAt(playerHRP.Position, Vector3.new(nearestHRP.Position.X, nearestHRP.Position.Y, nearestHRP.Position.Z))
                            end
                        end
                    end
                end
            end
        end)
    else
        if No2loop then
            No2loop:Disconnect()
            No2loop = nil
        end
    end
end

-- 注册 Noil 模块（直接调用上述函数）
registerTriggerModule("NoilStar",
    function()
        NoilStarAim(true)
    end,
    function()
        NoilStarAim(false)
    end
)

registerTriggerModule("NoilVoid",
    function()
        NoilVoidAim(true)
    end,
    function()
        NoilVoidAim(false)
    end
)

-- ========== 其他原有模块（完全不变） ==========
createAnimationTrigger("JaneDoe", {
    ["106527725058030"] = true,
    ["139929602101552"] = true,
}, "Killers", false)

createAnimationTrigger("JaneDoeAxe", {
    ["111918351126361"] = true,
}, "Killers", false)

createAnimationTrigger("Chance", {
    ["103601716322988"] = true,
    ["133491532453922"] = true,
    ["86371356500204"] = true,
    ["76649505662612"] = true,
    ["81698196845041"] = true
}, "Killers", false)

createAnimationTrigger("Dusekkar", {
    ["77894750279891"] = true,
}, "Killers", true)

createAnimationTrigger("1x4", {
    ["99050723653468"] = true,
    ["119181003138006"] = true
}, "Survivors", false)

createAnimationTrigger("C00kidd", {
    ["18885919947"] = true
}, "Survivors", true)

createAnimationTrigger("JohnDoe", {
    ["127172483138092"] = true
}, "Survivors", true)

createAnimationTrigger("Nosferatu", {
    ["79282445348798"] = true,
    ["128009545282102"] = true
}, "Survivors", true)

createAnimationTrigger("Punch", {
    ["108911997126897"] = true,
    ["82137285150006"] = true,
    ["129843313690921"] = true,
    ["140703210927645"] = true,
    ["136007065400978"] = true,
    ["86096387000557"] = true,
    ["87259391926321"] = true,
    ["86709774283672"] = true,
    ["108807732150251"] = true,
    ["138040001965654"] = true
}, "Killers", false)

-- ========== SoundTrigger 模块（不变） ==========
local soundTriggerEnabled = false
local soundConnections = {}
local globalSoundConn = nil

local targetSoundIds = {
    "rbxassetid://120944766765949",
    "rbxassetid://92445809840331",
    "rbxassetid://89315669689903",
    "rbxassetid://77069367360935",
    "rbxassetid://123979582011869",
    "rbxassetid://109525294317144",
    "rbxassetid://105934041806374",
    "rbxassetid://132331977491979",
    "rbxassetid://128009545282102",
    "rbxassetid://79282445348798"
}

local function onSoundPlayed(sound)
    if not soundTriggerEnabled then return end
    local soundId = sound.SoundId
    for _, id in ipairs(targetSoundIds) do
        if soundId == id then
            debugPrint("捕获到目标声音:", soundId)
            executeAim()
            break
        end
    end
end

local function bindSound(sound)
    if not sound:IsA("Sound") then return end
    local conn = sound.Played:Connect(function()
        onSoundPlayed(sound)
    end)
    table.insert(soundConnections, conn)
end

local function setupSoundTrigger()
    local function bindAll(container)
        for _, obj in ipairs(container:GetDescendants()) do
            if obj:IsA("Sound") then
                bindSound(obj)
            end
        end
    end
    local player = game.Players.LocalPlayer
    if player.Character then
        bindAll(player.Character)
    end
    local charConn = player.CharacterAdded:Connect(function(char)
        task.wait(0.2)
        bindAll(char)
    end)
    table.insert(soundConnections, charConn)

    if settings.globalSound then
        globalSoundConn = workspace.DescendantAdded:Connect(function(child)
            if child:IsA("Sound") then
                bindSound(child)
            end
        end)
        table.insert(soundConnections, globalSoundConn)
        bindAll(workspace)
    end
end

registerTriggerModule("SoundTrigger",
    function() 
        soundTriggerEnabled = true
        setupSoundTrigger()
    end,
    function()
        soundTriggerEnabled = false
        for _, conn in ipairs(soundConnections) do
            conn:Disconnect()
        end
        soundConnections = {}
        if globalSoundConn then globalSoundConn:Disconnect() end
        globalSoundConn = nil
    end
)

local function CreateHitboxFeatures()
    local KK_Left = Tabs.tfz:AddLeftGroupbox("碰撞箱")
    local KK_Right = Tabs.tfz:AddRightGroupbox("参数调节")

    local HitboxTrackingEnabled = false
    local HeartbeatConnection = nil
    local MaxDistance = 12
    local IgnoreNPCs = false
    local IgnoreSurvivors = false

    local AttackAnimations = {
    ["rbxassetid://131430497821198"] = true,
    ["rbxassetid://83829782357897"] = true,
    ["rbxassetid://126830014841198"] = true,
    ["rbxassetid://126355327951215"] = true,
    ["rbxassetid://121086746534252"] = true,
    ["rbxassetid://105458270463374"] = true,
    ["rbxassetid://127172483138092"] = true,
    ["rbxassetid://18885919947"] = true,
    ["rbxassetid://18885909645"] = true,
    ["rbxassetid://87259391926321"] = true,
    ["rbxassetid://106014898528300"] = true,
    ["rbxassetid://86545133269813"] = true,
    ["rbxassetid://89448354637442"] = true,
    ["rbxassetid://90499469533503"] = true,
    ["rbxassetid://116618003477002"] = true,
    ["rbxassetid://106086955212611"] = true,
    ["rbxassetid://107640065977686"] = true,
    ["rbxassetid://77124578197357"] = true,
    ["rbxassetid://101771617803133"] = true,
    ["rbxassetid://134958187822107"] = true,
    ["rbxassetid://111313169447787"] = true,
    ["rbxassetid://71685573690338"] = true,
    ["rbxassetid://129843313690921"] = true,
    ["rbxassetid://97623143664485"] = true,
    ["rbxassetid://136007065400978"] = true,
    ["rbxassetid://86096387000557"] = true,
    ["rbxassetid://108807732150251"] = true,
    ["rbxassetid://138040001965654"] = true,
    ["rbxassetid://73502073176819"] = true,
    ["rbxassetid://86709774283672"] = true,
    ["rbxassetid://140703210927645"] = true,
    ["rbxassetid://96173857867228"] = true,
    ["rbxassetid://121255898612475"] = true,
    ["rbxassetid://98031287364865"] = true,
    ["rbxassetid://119462383658044"] = true,
    ["rbxassetid://77448521277146"] = true,
    ["rbxassetid://103741352379819"] = true,
    ["rbxassetid://131696603025265"] = true,
    ["rbxassetid://122503338277352"] = true,
    ["rbxassetid://97648548303678"] = true,
    ["rbxassetid://94162446513587"] = true,
    ["rbxassetid://84426150435898"] = true,
    ["rbxassetid://93069721274110"] = true,
    ["rbxassetid://114620047310688"] = true,
    ["rbxassetid://97433060861952"] = true,
    ["rbxassetid://82183356141401"] = true,
    ["rbxassetid://100592913030351"] = true,
    ["rbxassetid://121293883585738"] = true,
    ["rbxassetid://70447634862911"] = true,
    ["rbxassetid://92173139187970"] = true,
    ["rbxassetid://106847695270773"] = true,
    ["rbxassetid://125403313786645"] = true,
    ["rbxassetid://81639435858902"] = true,
    ["rbxassetid://137314737492715"] = true,
    ["rbxassetid://120112897026015"] = true,
    ["rbxassetid://82113744478546"] = true,
    ["rbxassetid://118298475669935"] = true,
    ["rbxassetid://126681776859538"] = true,
    ["rbxassetid://129976080405072"] = true,
    ["rbxassetid://109667959938617"] = true,
    ["rbxassetid://74707328554358"] = true,
    ["rbxassetid://133336594357903"] = true,
    ["rbxassetid://86204001129974"] = true,
    ["rbxassetid://124243639579224"] = true,
    ["rbxassetid://70371667919898"] = true,
    ["rbxassetid://131543461321709"] = true,
    ["rbxassetid://136323728355613"] = true,
    ["rbxassetid://109230267448394"] = true,
    ["rbxassetid://104744456957363"] = true,
    ["rbxassetid://106538427162796"] = true,
    ["rbxassetid://117451341682452"] = true,
    ["rbxassetid://122580527125278"] = true,
    ["rbxassetid://125504560920616"] = true,
    ["rbxassetid://126896426760253"] = true,
    ["rbxassetid://128923537868786"] = true,
    ["rbxassetid://129491851057694"] = true,
    ["rbxassetid://134053005930385"] = true,
    ["rbxassetid://135884061951801"] = true,
    ["rbxassetid://139321362207112"] = true,
    ["rbxassetid://139835501033932"] = true,
    ["rbxassetid://140042539182927"] = true,
    ["rbxassetid://140061272138793"] = true,
    ["rbxassetid://108018357044094"] = true,
    ["rbxassetid://126171487400618"] = true,
    ["rbxassetid://99135633258223"] = true,
    ["rbxassetid://81299297965542"] = true,
    ["rbxassetid://83251433279852"] = true,
    ["rbxassetid://83685305553364"] = true,
    ["rbxassetid://87989533095285"] = true,
    ["rbxassetid://88451353906104"] = true,
    ["rbxassetid://88970503168421"] = true,
    ["rbxassetid://96571077893813"] = true,
    ["rbxassetid://97167027849946"] = true,
    ["rbxassetid://98456918873918"] = true,
    ["rbxassetid://99829427721752"] = true,
    ["rbxassetid://106776364623742"] = true,
    ["rbxassetid://114356208094580"] = true,
    ["rbxassetid://114506382930939"] = true,
    ["rbxassetid://122709416391891"] = true,
    ["rbxassetid://124705663396411"] = true,
    ["rbxassetid://128414736976503"] = true,
    ["rbxassetid://133363345661032"] = true,
    ["rbxassetid://138938529389204"] = true,
    ["rbxassetid://139309647473555"] = true,
    ["rbxassetid://109700476007435"] = true,
    ["rbxassetid://93366464803829"] = true,
    ["rbxassetid://98590570796574"] = true,
    ["rbxassetid://119062842291223"] = true,
    ["rbxassetid://124269076578545"] = true,
}

    local function isPlayingAttackAnimation(humanoid)
        if not humanoid then return false end
        for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
            local animId = track.Animation and track.Animation.AnimationId
            if animId and AttackAnimations[animId] then
                local length = track.Length
                if length > 0 and (track.TimePosition / length) < 0.75 then
                    return true
                end
            end
        end
        return false
    end

    local function getTargets(ignoreSurvivors, ignoreNPCs)
        local targets = {}
        if not ignoreSurvivors then
            local survivors = workspace.Players:FindFirstChild("Survivors")
            if survivors then
                for _, child in ipairs(survivors:GetChildren()) do
                    if child:IsA("Model") and child:FindFirstChild("HumanoidRootPart") and child ~= game.Players.LocalPlayer.Character then
                        table.insert(targets, child)
                    end
                end
            end
        end
        if not ignoreNPCs then
            local npcsFolder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("NPCs")
            if npcsFolder then
                for _, child in ipairs(npcsFolder:GetChildren()) do
                    if child:IsA("Model") and child:FindFirstChild("HumanoidRootPart") then
                        table.insert(targets, child)
                    end
                end
            end
        end
        return targets
    end

    local function calculateVelocity(myRoot, targetRoot, ping)
        if not myRoot or not targetRoot then return nil end
        local offset = targetRoot.Position - myRoot.Position
        local randomVec = Vector3.new(math.random(-150, 150)/100, 0, math.random(-150, 150)/100)
        local targetVel = targetRoot.Velocity or Vector3.zero
        local compensation = targetVel * (ping * 1.25)
        local desired = offset + randomVec + compensation
        local timeFactor = math.max(ping * 2, 0.05)
        return desired / timeFactor
    end

    KK_Left:AddToggle("HitboxTrackingToggle", {
        Text = "碰撞箱追踪",
        Default = false,
        Risky = true,
        Callback = function(state)
            HitboxTrackingEnabled = state
            if HeartbeatConnection then
                HeartbeatConnection:Disconnect()
                HeartbeatConnection = nil
            end
            if not state then return end

            local player = game.Players.LocalPlayer
            local character = player.Character or player.CharacterAdded:Wait()
            local humanoid = character:WaitForChild("Humanoid")
            local rootPart = character:WaitForChild("HumanoidRootPart")

            local charAddedConn
            charAddedConn = player.CharacterAdded:Connect(function(newChar)
                character = newChar
                humanoid = character:WaitForChild("Humanoid")
                rootPart = character:WaitForChild("HumanoidRootPart")
            end)

            HeartbeatConnection = game:GetService('RunService').Heartbeat:Connect(function()
                if not HitboxTrackingEnabled or not rootPart or not humanoid then return end

                if not isPlayingAttackAnimation(humanoid) then return end

                local targets = getTargets(IgnoreSurvivors, IgnoreNPCs)
                local closestTarget = nil
                local closestDist = MaxDistance
                for _, t in ipairs(targets) do
                    local tRoot = t:FindFirstChild("HumanoidRootPart")
                    if tRoot then
                        local dist = (tRoot.Position - rootPart.Position).Magnitude
                        if dist < closestDist then
                            closestDist = dist
                            closestTarget = t
                        end
                    end
                end

                if not closestTarget then return end
                local targetRoot = closestTarget:FindFirstChild("HumanoidRootPart")
                if not targetRoot then return end

                local ping = player:GetNetworkPing()
                local neededVel = calculateVelocity(rootPart, targetRoot, ping)
                if neededVel then
                    local oldVel = rootPart.Velocity
                    rootPart.Velocity = neededVel
                    task.wait()
                    if rootPart and rootPart.Parent then
                        rootPart.Velocity = oldVel
                    end
                end
            end)

            local cleanupConn
            cleanupConn = game:GetService("RunService").Stepped:Connect(function()
                if not HitboxTrackingEnabled then
                    if HeartbeatConnection then HeartbeatConnection:Disconnect() end
                    if charAddedConn then charAddedConn:Disconnect() end
                    if cleanupConn then cleanupConn:Disconnect() end
                    HeartbeatConnection = nil
                end
            end)
        end,
    })

    KK_Right:AddSlider("DistanceSlider", {
        Text = "距离",
        Default = 12,
        Min = 1,
        Max = 250,
        Rounding = 0,
        Callback = function(value)
            MaxDistance = value
        end
    })

    KK_Right:AddDropdown("IgnoreTargetsDropdown", {
        Values = { "NPC", "幸存者" },
        Default = {},
        Multi = true,
        Text = "忽略目标",
        Callback = function(selected)
            IgnoreNPCs = false
            IgnoreSurvivors = false
            for _, v in ipairs(selected) do
                if v == "NPC" then IgnoreNPCs = true end
                if v == "幸存者" then IgnoreSurvivors = true end
            end
        end
    })
end

CreateHitboxFeatures()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local uiConnections = {}   

local REAL_CHARACTER = player.Character or player.CharacterAdded:Wait()
local REAL_HRP = REAL_CHARACTER:WaitForChild("HumanoidRootPart")
local GHOST_CHARACTER = nil
local GHOST_HRP = nil
local GHOST_HUMANOID = nil
local IS_INVISIBLE = false
local GHOST_CONNECTIONS = {}
local VOID_DEPTH = -500
local ORIGINAL_POS = nil

local ORBIT_STATE = {
    yaw = 0,
    pitch = math.rad(-20),
    distance = 12,
    keysDown = {},
    ghostSpeed = 24,
    sensitivity = 0.25,
    autoRestart = true
}

local Network = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Network"):WaitForChild("Network")
local UnreliableRemoteEvent = Network:WaitForChild("UnreliableRemoteEvent")

local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function base64Encode(data)
    local result = ""
    local padding = ""
    if typeof(data) == "buffer" then data = buffer.readstring(data, 0, buffer.len(data)) end
    local pad = 3 - (#data % 3)
    if pad ~= 3 then
        data = data .. string.rep("\0", pad)
        padding = string.rep("=", pad)
    end
    for i = 1, #data, 3 do
        local a, b, c = string.byte(data, i, i + 2)
        local n = a * 65536 + b * 256 + c
        local d = math.floor(n / 262144) % 64 + 1
        local e = math.floor(n / 4096) % 64 + 1
        local f = math.floor(n / 64) % 64 + 1
        local g = n % 64 + 1
        result = result .. b64chars:sub(d, d) .. b64chars:sub(e, e) .. b64chars:sub(f, f) .. b64chars:sub(g, g)
    end
    return result:sub(1, -1 - #padding) .. padding
end

local function buildPositionPacket(x, y, z, instanceId, stateCode)
    instanceId = instanceId or 0
    stateCode = stateCode or 55536
    local payload = ""
    payload = payload .. string.pack("<f", x)
    payload = payload .. string.pack("<f", y)
    payload = payload .. string.pack("<f", z)
    payload = payload .. string.pack("<I4", instanceId)
    payload = payload .. string.pack("<I4", stateCode)
    payload = payload .. string.rep("\0", 10)

    local base64Str = base64Encode(payload)
    local jsonStr = string.format('{"m":null,"t":"buffer","base64":"%s"}', base64Str)
    local bufferStr = "\nK\0\0\0" .. jsonStr

    local buf = buffer.create(#bufferStr)
    buffer.writestring(buf, 0, bufferStr)
    return { 1, { buf } }
end

local function sendSinglePacket(x, y, z)
    local args = buildPositionPacket(x, y, z)
    UnreliableRemoteEvent:FireServer(unpack(args))
end

-- ============================================
-- 攻击配置系统 (吸血鬼)
-- ============================================
local PACKET_CONFIG = {
    burstCount = 8,
    burstInterval = 0.015,
    preDelay = 0,
    postDelay = 0.05,
    jitterAmount = 0.3,
    useJitter = true,
    usePreBurst = true,
    usePostBurst = true,
    preBurstCount = 3,
    postBurstCount = 3,
    useCustomDuration = false,
    defaultDuration = 0.3,
    customDuration = 0.6,
}

local RANGE_CONFIG = { enabled = false, extendDistance = 10 }
local PREDICT_CONFIG = { enabled = true, distance = 5 }

local WALL_CONFIG = {
    enabled = true,              -- 是否启用墙体检测
    raycastDistance = 50,       -- 射线检测最大距离
    wallOffset = 1.5,          -- 贴墙偏移距离 (studs)
    fallbackOffset = 3,        -- 备用偏移距离
    checkHeightOffset = 2,     -- 检测高度偏移 (从腰部检测)
    maxAdjustment = 15,        -- 最大位置调整距离
    useSmartRaycast = true,    -- 使用智能多方向射线检测
    rayDirections = 8,         -- 环绕检测的射线数量
    minClearance = 1.2,        -- 最小 clearance 距离
}

local function getRaycastIgnoreList()
    local ignoreList = {}
    if REAL_CHARACTER then
        for _, part in ipairs(REAL_CHARACTER:GetDescendants()) do
            if part:IsA("BasePart") then
                table.insert(ignoreList, part)
            end
        end
    end
    if GHOST_CHARACTER then
        for _, part in ipairs(GHOST_CHARACTER:GetDescendants()) do
            if part:IsA("BasePart") then
                table.insert(ignoreList, part)
            end
        end
    end
    return ignoreList
end

local function isWallBlocking(startPos, endPos, targetCharacter)
    local direction = (endPos - startPos)
    local distance = direction.Magnitude
    if distance < 0.001 then return false end
    direction = direction.Unit

    local ignoreList = getRaycastIgnoreList()
    -- 将目标角色加入忽略列表
    if targetCharacter then
        for _, part in ipairs(targetCharacter:GetDescendants()) do
            if part:IsA("BasePart") then
                table.insert(ignoreList, part)
            end
        end
    end

    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = ignoreList
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.IgnoreWater = true

    local result = Workspace:Raycast(startPos, direction * distance, raycastParams)

    if result then
        -- 有碰撞，说明有墙阻挡
        return true, result.Position, result.Normal, result.Instance
    end

    return false, nil, nil, nil
end

local function findValidAttackPosition(targetRoot, preferredPos, targetCharacter)
    if not WALL_CONFIG.enabled then return preferredPos end
    if not targetRoot then return preferredPos end

    local targetPos = targetRoot.Position
    local targetUp = Vector3.new(0, 1, 0)

    -- 首先检测从 preferredPos 到 targetPos 是否被墙阻挡
    local checkStart = preferredPos + Vector3.new(0, WALL_CONFIG.checkHeightOffset, 0)
    local checkEnd = targetPos + Vector3.new(0, WALL_CONFIG.checkHeightOffset, 0)

    local isBlocked, hitPos, hitNormal, hitPart = isWallBlocking(checkStart, checkEnd, targetCharacter)

    if not isBlocked then
        -- 没有被阻挡，直接返回 preferredPos
        return preferredPos
    end

    -- 被阻挡了，需要找到墙另一侧的有效位置
    -- 策略1: 沿着法线方向偏移到墙的另一侧 (靠近目标的一侧)
    if hitNormal then
        local wallSidePos = hitPos + hitNormal * WALL_CONFIG.wallOffset
        wallSidePos = Vector3.new(wallSidePos.X, preferredPos.Y, wallSidePos.Z)

        -- 验证这个位置是否能看到目标
        local verifyStart = wallSidePos + Vector3.new(0, WALL_CONFIG.checkHeightOffset, 0)
        local verifyBlocked = isWallBlocking(verifyStart, checkEnd, targetCharacter)

        if not verifyBlocked then
            return wallSidePos
        end
    end

    -- 策略2: 智能环绕检测 - 在目标周围多个方向寻找无阻挡位置
    if WALL_CONFIG.useSmartRaycast then
        local bestPos = nil
        local bestDistance = math.huge

        for i = 1, WALL_CONFIG.rayDirections do
            local angle = (i / WALL_CONFIG.rayDirections) * math.pi * 2
            local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))

            -- 从目标位置向外发射射线，找到墙的位置
            local rayStart = targetPos + Vector3.new(0, WALL_CONFIG.checkHeightOffset, 0)
            local rayDir = dir * WALL_CONFIG.raycastDistance

            local ignoreList = getRaycastIgnoreList()
            if targetCharacter then
                for _, part in ipairs(targetCharacter:GetDescendants()) do
                    if part:IsA("BasePart") then
                        table.insert(ignoreList, part)
                    end
                end
            end

            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = ignoreList
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            raycastParams.IgnoreWater = true

            local result = Workspace:Raycast(rayStart, rayDir, raycastParams)

            if result then
                -- 找到墙了，在墙的另一侧 (靠近目标的一侧) 放置攻击位置
                local candidatePos = result.Position - dir * WALL_CONFIG.wallOffset
                candidatePos = Vector3.new(candidatePos.X, preferredPos.Y, candidatePos.Z)

                -- 验证这个位置到目标是否无阻挡
                local verifyBlocked2 = isWallBlocking(
                    candidatePos + Vector3.new(0, WALL_CONFIG.checkHeightOffset, 0),
                    checkEnd,
                    targetCharacter
                )

                if not verifyBlocked2 then
                    local dist = (candidatePos - preferredPos).Magnitude
                    if dist < bestDistance then
                        bestDistance = dist
                        bestPos = candidatePos
                    end
                end
            else
                -- 这个方向没有墙，可以直接使用
                local candidatePos = targetPos + dir * WALL_CONFIG.wallOffset
                candidatePos = Vector3.new(candidatePos.X, preferredPos.Y, candidatePos.Z)
                local dist = (candidatePos - preferredPos).Magnitude
                if dist < bestDistance then
                    bestDistance = dist
                    bestPos = candidatePos
                end
            end
        end

        if bestPos then
            return bestPos
        end
    end

    -- 策略3: 备用方案 - 直接放在目标位置附近，稍微向 preferredPos 方向偏移
    local toPreferred = (preferredPos - targetPos)
    if toPreferred.Magnitude > 0.001 then
        toPreferred = toPreferred.Unit
        local fallbackPos = targetPos + toPreferred * WALL_CONFIG.fallbackOffset
        fallbackPos = Vector3.new(fallbackPos.X, preferredPos.Y, fallbackPos.Z)
        return fallbackPos
    end

    -- 最终备用: 直接返回目标位置上方
    return targetPos + Vector3.new(0, 0.5, 0)
end

-- 动态获取基准位置（隐身时以幽灵为基准）
local function getMyPosition()
    if IS_INVISIBLE and GHOST_HRP then
        return GHOST_HRP.Position
    elseif REAL_HRP then
        return REAL_HRP.Position
    end
    return Vector3.new(0, 0, 0)
end

local function getDynamicPosition(targetRoot, dragRatio, targetCharacter)
    if not targetRoot or not targetRoot.Parent then return nil end
    local targetPos = targetRoot.Position
    dragRatio = dragRatio or 0

    if PREDICT_CONFIG.enabled and dragRatio > 0 then
        local predictVec = targetRoot.CFrame.LookVector
        if targetRoot.AssemblyLinearVelocity.Magnitude > 1 then
            predictVec = targetRoot.AssemblyLinearVelocity.Unit
        end
        local offset = predictVec * (PREDICT_CONFIG.distance * dragRatio)
        targetPos = targetPos + offset
    end

    local finalPos = targetPos

    if RANGE_CONFIG.enabled then
        local myPos = getMyPosition()
        local toTarget = targetPos - myPos
        local distance = toTarget.Magnitude
        if distance >= 0.001 and RANGE_CONFIG.extendDistance < distance then
            finalPos = myPos + toTarget.Unit * RANGE_CONFIG.extendDistance
        end
    end

    -- 墙体检测修正: 确保构造的位置能实际打到目标
    finalPos = findValidAttackPosition(targetRoot, finalPos, targetCharacter)

    return finalPos
end

local function sendPositionBurst(targetRoot, count, interval, targetCharacter)
    count = count or PACKET_CONFIG.burstCount
    interval = interval or PACKET_CONFIG.burstInterval

    for i = 1, count do
        local ratio = 1 - (i / count)
        local pos = getDynamicPosition(targetRoot, ratio, targetCharacter)
        if not pos then break end

        local sendX, sendY, sendZ = pos.X, pos.Y, pos.Z
        if PACKET_CONFIG.useJitter then
            local jitter = PACKET_CONFIG.jitterAmount
            sendX = sendX + (math.random() - 0.5) * jitter * 2
            sendY = sendY + (math.random() - 0.5) * jitter * 0.5
            sendZ = sendZ + (math.random() - 0.5) * jitter * 2
        end

        sendSinglePacket(sendX, sendY, sendZ)
        if i < count and interval > 0 then task.wait(interval) end
    end
end

local function getSendDuration()
    return PACKET_CONFIG.useCustomDuration and PACKET_CONFIG.customDuration or PACKET_CONFIG.defaultDuration
end

local function sendPositionSustained(targetRoot, duration, targetCharacter)
    duration = duration or getSendDuration()
    local startTime = tick()
    local dragCycle = 0.2 

    while tick() - startTime < duration do
        local elapsed = tick() - startTime
        local cycleProgress = (elapsed % dragCycle) / dragCycle
        local pos = getDynamicPosition(targetRoot, 1 - cycleProgress, targetCharacter)
        if pos then sendSinglePacket(pos.X, pos.Y, pos.Z) end
        task.wait(0.03)
    end
end

local function sendAttackSequence(targetRoot, targetCharacter)
    if not targetRoot then return end
    if PACKET_CONFIG.usePreBurst then sendPositionBurst(targetRoot, PACKET_CONFIG.preBurstCount, 0.01, targetCharacter) end
    sendPositionBurst(targetRoot, PACKET_CONFIG.burstCount, PACKET_CONFIG.burstInterval, targetCharacter)
    local duration = getSendDuration()
    if duration > 0 then sendPositionSustained(targetRoot, duration, targetCharacter) end
    if PACKET_CONFIG.usePostBurst then
        task.wait(PACKET_CONFIG.postDelay)
        sendPositionBurst(targetRoot, PACKET_CONFIG.postBurstCount, 0.02, targetCharacter)
    end
end

local LOCKED_SURVIVOR = nil
local ALL_SURVIVORS = {}

local function getSurvivors()
    local survivorsList = {}
    local myPos = getMyPosition()

    local function addSurvivor(survivor)
        if survivor ~= REAL_CHARACTER and survivor ~= GHOST_CHARACTER then
            local root = survivor:FindFirstChild("HumanoidRootPart") or survivor:FindFirstChild("PrimaryPart")
            if root then
                local exists = false
                for _, existing in ipairs(survivorsList) do
                    if existing.character == survivor then exists = true break end
                end
                if not exists then
                    table.insert(survivorsList, {
                        character = survivor, root = root,
                        name = survivor.Name, distance = (root.Position - myPos).Magnitude
                    })
                end
            end
        end
    end

    local survivorsFolder = Workspace:FindFirstChild("Players") and Workspace.Players:FindFirstChild("Survivors")
    if survivorsFolder then for _, s in ipairs(survivorsFolder:GetChildren()) do addSurvivor(s) end end
    local altFolder = Workspace:FindFirstChild("Survivors")
    if altFolder then for _, s in ipairs(altFolder:GetChildren()) do addSurvivor(s) end end

    table.sort(survivorsList, function(a, b) return a.distance < b.distance end)
    return survivorsList
end

local function getAttackTarget()
    if LOCKED_SURVIVOR then
        local root = LOCKED_SURVIVOR:FindFirstChild("HumanoidRootPart") or LOCKED_SURVIVOR:FindFirstChild("PrimaryPart")
        if root then
            return { character = LOCKED_SURVIVOR, root = root, name = LOCKED_SURVIVOR.Name, isLocked = true }
        else LOCKED_SURVIVOR = nil end
    end
    local survivors = getSurvivors()
    if #survivors > 0 then survivors[1].isLocked = false return survivors[1] end
    return nil
end

local ATTACK_MODE = { single = true, aoe = false }

local function attackTarget()
    if ATTACK_MODE.aoe then
        local survivors = getSurvivors()
        if #survivors == 0 then return false end
        local count = math.min(#survivors, 8)
        task.spawn(function()
            for i = 1, count do
                if survivors[i].root then sendAttackSequence(survivors[i].root, survivors[i].character) end
                if i < count then task.wait(0.05) end
            end
        end)
        return true
    else
        local target = getAttackTarget()
        if target and target.root then sendAttackSequence(target.root, target.character) return true end
        return false
    end
end

local enableInvisibility, disableInvisibility, quickRestart

local function voidAnchor(character)
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true; part.CanCollide = false; part.Transparency = 1
        elseif part:IsA("Decal") or part:IsA("Texture") then part.Transparency = 1
        elseif part:IsA("BillboardGui") or part:IsA("SurfaceGui") then part.Enabled = false
        end
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.PlatformStand = true; humanoid.AutoRotate = false; humanoid.WalkSpeed = 0; humanoid.JumpPower = 0 end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.CFrame = CFrame.new(hrp.Position.X, VOID_DEPTH, hrp.Position.Z) end
end

local function createGhostCharacter(realChar)
    local oldArchivable = realChar.Archivable
    realChar.Archivable = true
    local ghost = realChar:Clone()
    realChar.Archivable = oldArchivable
    ghost.Name = player.Name .. "_Ghost"

    for _, desc in ipairs(ghost:GetDescendants()) do
        if desc:IsA("Script") or desc:IsA("LocalScript") then desc:Destroy() end
    end

    local ghostHRP = ghost:WaitForChild("HumanoidRootPart")
    local ghostHum = ghost:WaitForChild("Humanoid")
    ghostHum.PlatformStand = false; ghostHum.WalkSpeed = ORBIT_STATE.ghostSpeed; ghostHum.JumpPower = 50

    for _, part in ipairs(ghost:GetDescendants()) do
        if part:IsA("BasePart") then part.Anchored = false; part.CanCollide = true end
    end
    ghost.Parent = Workspace
    return ghost, ghostHRP
end

local function startOrbitControl()
    for _, conn in ipairs(GHOST_CONNECTIONS) do pcall(function() conn:Disconnect() end) end
    GHOST_CONNECTIONS = {}

    if not GHOST_CHARACTER then return end
    GHOST_HUMANOID = GHOST_CHARACTER:FindFirstChildOfClass("Humanoid")
    if GHOST_HRP and ORIGINAL_POS then GHOST_HRP.CFrame = ORIGINAL_POS + Vector3.new(0, 3, 0) end

    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    UserInputService.MouseIconEnabled = false
    camera.CameraType = Enum.CameraType.Scriptable

    if ORBIT_STATE.yaw == 0 and ORBIT_STATE.pitch == math.rad(-20) then
        local look = camera.CFrame.LookVector
        ORBIT_STATE.yaw = math.atan2(-look.X, -look.Z)
    end
    ORBIT_STATE.keysDown = {}

    table.insert(GHOST_CONNECTIONS, UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then ORBIT_STATE.keysDown[input.KeyCode] = true end
    end))
    table.insert(GHOST_CONNECTIONS, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Keyboard then ORBIT_STATE.keysDown[input.KeyCode] = nil end
    end))
    table.insert(GHOST_CONNECTIONS, UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            ORBIT_STATE.yaw = ORBIT_STATE.yaw - math.rad(input.Delta.X * ORBIT_STATE.sensitivity)
            ORBIT_STATE.pitch = math.clamp(ORBIT_STATE.pitch - math.rad(input.Delta.Y * ORBIT_STATE.sensitivity), -math.rad(80), math.rad(80))
        elseif input.UserInputType == Enum.UserInputType.MouseWheel then
            ORBIT_STATE.distance = math.clamp(ORBIT_STATE.distance - input.Position.Z * 2, 5, 40)
        end
    end))

    table.insert(GHOST_CONNECTIONS, RunService.RenderStepped:Connect(function()
        if not IS_INVISIBLE or not GHOST_HRP then return end
        local moveX, moveZ = 0, 0
        if ORBIT_STATE.keysDown[Enum.KeyCode.W] then moveZ = -1 end
        if ORBIT_STATE.keysDown[Enum.KeyCode.S] then moveZ = 1 end
        if ORBIT_STATE.keysDown[Enum.KeyCode.A] then moveX = -1 end
        if ORBIT_STATE.keysDown[Enum.KeyCode.D] then moveX = 1 end

        local rawMoveVec = Vector3.new(moveX, 0, moveZ)
        if rawMoveVec.Magnitude > 0 then rawMoveVec = rawMoveVec.Unit end
        local worldMoveVec = CFrame.Angles(0, ORBIT_STATE.yaw, 0) * rawMoveVec

        if GHOST_HUMANOID then
            GHOST_HUMANOID.WalkSpeed = ORBIT_STATE.ghostSpeed
            GHOST_HUMANOID:Move(worldMoveVec, false)
            if ORBIT_STATE.keysDown[Enum.KeyCode.Space] then GHOST_HUMANOID.Jump = true end
        end

        local targetPos = GHOST_HRP.Position + Vector3.new(0, 1.5, 0)
        local camRotation = CFrame.Angles(0, ORBIT_STATE.yaw, 0) * CFrame.Angles(ORBIT_STATE.pitch, 0, 0)
        camera.CFrame = CFrame.new(targetPos + camRotation * Vector3.new(0, 0, ORBIT_STATE.distance), targetPos)

        if REAL_HRP then
            local ghostLook = GHOST_HRP.CFrame.LookVector
            REAL_HRP.CFrame = CFrame.new(GHOST_HRP.Position.X, VOID_DEPTH, GHOST_HRP.Position.Z) * CFrame.Angles(0, math.atan2(ghostLook.X, ghostLook.Z), 0)
        end
    end))
end

enableInvisibility = function()
    if IS_INVISIBLE then return end
    IS_INVISIBLE = true
    if not REAL_CHARACTER then return end
    if not ORIGINAL_POS then ORIGINAL_POS = REAL_HRP.CFrame end

    voidAnchor(REAL_CHARACTER)
    GHOST_CHARACTER, GHOST_HRP = createGhostCharacter(REAL_CHARACTER)
    startOrbitControl()
end

disableInvisibility = function()
    if not IS_INVISIBLE then return end
    IS_INVISIBLE = false
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = true
    camera.CameraType = Enum.CameraType.Custom

    for _, conn in ipairs(GHOST_CONNECTIONS) do pcall(function() conn:Disconnect() end) end
    GHOST_CONNECTIONS = {}

    if GHOST_CHARACTER then GHOST_CHARACTER:Destroy(); GHOST_CHARACTER = nil; GHOST_HRP = nil end
    if REAL_CHARACTER and REAL_CHARACTER.Parent then
        for _, part in ipairs(REAL_CHARACTER:GetDescendants()) do
            if part:IsA("BasePart") then part.Anchored = false; part.CanCollide = true; part.Transparency = 0
            elseif part:IsA("Decal") or part:IsA("Texture") then part.Transparency = 0
            elseif part:IsA("BillboardGui") or part:IsA("SurfaceGui") then part.Enabled = true end
        end
        local hum = REAL_CHARACTER:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false; hum.AutoRotate = true; hum.WalkSpeed = 16; hum.JumpPower = 50 end
        if REAL_HRP and ORIGINAL_POS then REAL_HRP.CFrame = ORIGINAL_POS + Vector3.new(0, 5, 0) end
        camera.CameraSubject = hum
    end
end

quickRestart = function()
    if not IS_INVISIBLE then return end
    local savedPos = GHOST_HRP and GHOST_HRP.CFrame or ORIGINAL_POS
    local savedYaw, savedPitch, savedDist = ORBIT_STATE.yaw, ORBIT_STATE.pitch, ORBIT_STATE.distance
    disableInvisibility()
    task.wait(0.1)

    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") and savedPos then
        char.HumanoidRootPart.CFrame = savedPos + Vector3.new(0, 5, 0)
    end
    task.wait(0.1)

    local currentChar = player.Character
    if currentChar and currentChar:FindFirstChild("HumanoidRootPart") then
        ORIGINAL_POS = currentChar.HumanoidRootPart.CFrame
    end
    task.wait(0.1)
    enableInvisibility()
    ORBIT_STATE.yaw, ORBIT_STATE.pitch, ORBIT_STATE.distance = savedYaw, savedPitch, savedDist
end


local function CreateCoreFeatures()
    -- 自动适配标签页（如果 Tabs.tfz 不存在，尝试创建或使用其他标签页）
    local targetTab = Tabs.tfz or Tabs.Main or Tabs.Backstab or Tabs.Bro or Tabs.Block
    
    if not targetTab then
        -- 如果没有任何标签页，创建一个新的
        targetTab = Window:AddTab('杀戮', 'skull')
        Tabs.tfz = targetTab
    end
    
    local leftGroup = targetTab:AddLeftGroupbox("碰撞箱Pro")
    local rightGroup = targetTab:AddRightGroupbox("参数调节")

    -- ---------- 左侧：功能按钮与主开关 ----------
    local statusLabel = leftGroup:AddLabel("状态: 正常模式 | 狂暴模式")

    leftGroup:AddToggle("LeftClickTrigger", {
        Text = "左键触发追踪网",
        Default = true,
        Callback = function(state)
            leftClickTrigger = state
        end
    })

    leftGroup:AddToggle("AutoAttackLoop", {
        Text = "强制循环追踪",
        Default = false,
        Callback = function(state)
            autoAttackLoop = state
            if state then
                task.spawn(function()
                    while autoAttackLoop do
                        attackTarget()
                        task.wait(0.1)
                    end
                end)
            end
        end
    })

    leftGroup:AddToggle("AOEMode", {
        Text = "全图追踪",
        Default = false,
        Callback = function(state)
            ATTACK_MODE.aoe = state
            ATTACK_MODE.single = not state
        end
    })

    -- ---------- 右侧：全部参数调节 ----------
    rightGroup:AddLabel("轨道摄像机与幽灵")

    rightGroup:AddSlider("GhostSpeed", {
        Text = "幽灵移动速度",
        Min = 16,
        Max = 100,
        Default = 24,
        Callback = function(val)
            ORBIT_STATE.ghostSpeed = val
        end
    })

    rightGroup:AddSlider("Sensitivity", {
        Text = "鼠标视角灵敏度",
        Min = 0.05,
        Max = 1.0,
        Default = 0.25,
        Callback = function(val)
            ORBIT_STATE.sensitivity = val
        end
    })

    rightGroup:AddLabel("预判拖拽网设置")

    rightGroup:AddToggle("PredictEnabled", {
        Text = "启用前方拖拽至基准点",
        Default = true,
        Callback = function(state)
            PREDICT_CONFIG.enabled = state
        end
    })

    rightGroup:AddSlider("PredictDistance", {
        Text = "网端预判距离 (studs)",
        Min = 1,
        Max = 20,
        Default = 5,
        Callback = function(val)
            PREDICT_CONFIG.distance = val
        end
    })

    rightGroup:AddToggle("RangeEnabled", {
        Text = "启用伪长臂延展",
        Default = false,
        Callback = function(state)
            RANGE_CONFIG.enabled = state
        end
    })

    rightGroup:AddSlider("RangeDistance", {
        Text = "延展距离 (studs)",
        Min = 0,
        Max = 100,
        Default = 10,
        Callback = function(val)
            RANGE_CONFIG.extendDistance = val
        end
    })

    rightGroup:AddLabel("爆发与持续发包")

    rightGroup:AddSlider("BurstCount", {
        Text = "主连发包数量",
        Min = 1,
        Max = 20,
        Default = 8,
        Rounding = 1,
        Callback = function(val)
            PACKET_CONFIG.burstCount = math.floor(val)
        end
    })

    rightGroup:AddSlider("BurstInterval", {
        Text = "连发包间隔(秒)",
        Min = 0.001,
        Max = 0.1,
        Default = 0.015,
        Callback = function(val)
            PACKET_CONFIG.burstInterval = val
        end
    })

    rightGroup:AddToggle("CustomDuration", {
        Text = "使用自定义持续追踪时间",
        Default = false,
        Callback = function(state)
            PACKET_CONFIG.useCustomDuration = state
        end
    })

    rightGroup:AddSlider("CustomDurationVal", {
        Text = "自定义追踪时间(秒)",
        Min = 0.1,
        Max = 2.0,
        Default = 0.6,
        Callback = function(val)
            PACKET_CONFIG.customDuration = val
        end
    })

    rightGroup:AddSlider("JitterAmount", {
        Text = "位置随机抖动 (Jitter)",
        Min = 0,
        Max = 2,
        Default = 0.3,
        Callback = function(val)
            PACKET_CONFIG.jitterAmount = val
        end
    })

    rightGroup:AddLabel("墙体穿透修正系统")

    rightGroup:AddToggle("WallEnabled", {
        Text = "启用墙体检测修正",
        Default = true,
        Callback = function(state)
            WALL_CONFIG.enabled = state
        end
    })

    rightGroup:AddSlider("WallOffset", {
        Text = "贴墙偏移距离",
        Min = 0.5,
        Max = 5,
        Default = 1.5,
        Callback = function(val)
            WALL_CONFIG.wallOffset = val
        end
    })

    rightGroup:AddSlider("RayDirections", {
        Text = "环绕检测射线数",
        Min = 4,
        Max = 16,
        Default = 8,
        Rounding = 1,
        Callback = function(val)
            WALL_CONFIG.rayDirections = math.floor(val)
        end
    })

    rightGroup:AddSlider("RaycastDistance", {
        Text = "射线检测距离",
        Min = 10,
        Max = 100,
        Default = 50,
        Callback = function(val)
            WALL_CONFIG.raycastDistance = val
        end
    })

    rightGroup:AddSlider("CheckHeight", {
        Text = "检测高度偏移",
        Min = 0,
        Max = 5,
        Default = 2,
        Callback = function(val)
            WALL_CONFIG.checkHeightOffset = val
        end
    })

    -- ---------- 事件绑定（保持不变） ----------
    table.insert(uiConnections, UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if leftClickTrigger and input.UserInputType == Enum.UserInputType.MouseButton1 then
            if not attackCooldown then
                attackCooldown = true
                attackTarget()
                task.delay(0.3, function()
                    attackCooldown = false
                end)
            end
        end
    end))

    table.insert(uiConnections, player.CharacterAdded:Connect(function(newChar)
        if IS_INVISIBLE then
            disableInvisibility()
        end
        REAL_CHARACTER = newChar
        REAL_HRP = newChar:WaitForChild("HumanoidRootPart")
    end))
end

-- 调用函数创建UI
CreateCoreFeatures()

local ZZ = Tabs.ani:AddLeftGroupbox('Noli反效果')
do
noliDeleterActive = false
deletionConnection = nil
allowedNoli = nil
isVoidRushCrashed = false
characterCheckLoop = nil
voidRushOverrideActive = false
voidRushState = {}
RunService = game:GetService("RunService")

function deleteNewNoli()
    killersFolder = workspace:WaitForChild("Players")
    killers = killersFolder:WaitForChild("Killers")
    
    allowedNoli = killers:FindFirstChild("Noli")
    if not allowedNoli then
        return
    end
    
    if deletionConnection then
        deletionConnection:Disconnect()
        deletionConnection = nil
    end
    
    deletionConnection = RunService.Heartbeat:Connect(function()
        allowedNoli = killers:FindFirstChild("Noli")
        
        if not allowedNoli then
            if deletionConnection then
                deletionConnection:Disconnect()
                deletionConnection = nil
            end
            return
        end
        
        for _, child in killers:GetChildren() do
            if child.Name == "Noli" and child ~= allowedNoli then
                child:Destroy()
            end
        end
    end)
end

ZZ:AddToggle("NoliDeleter", {
    Text = "反假Noli",
    Default = false,
    Callback = function(enabled)
        noliDeleterActive = enabled
        
        if enabled then
            if deletionConnection then
                deletionConnection:Disconnect()
                deletionConnection = nil
            end
            
            local success, err = pcall(function()
                deleteNewNoli()
            end)
            
            if not success then
                noliDeleterActive = false
            end
        else
            if deletionConnection then
                deletionConnection:Disconnect()
                deletionConnection = nil
            end
            allowedNoli = nil
        end
    end
})

ZZ:AddToggle("VoidRushOverride", {
    Text = "Noli自由冲刺[需要锁定视角]",
    Default = false,
    Callback = function(enabled)
        voidRushOverrideActive = enabled
        
        if voidRushState.monitorTask then
            task.cancel(voidRushState.monitorTask)
            voidRushState.monitorTask = nil
        end
        
        if voidRushState.overrideConnection then
            voidRushState.overrideConnection:Disconnect()
            voidRushState.overrideConnection = nil
        end
        
        if voidRushState.characterAddedConnection then
            voidRushState.characterAddedConnection:Disconnect()
            voidRushState.characterAddedConnection = nil
        end
        
        if enabled then
            LocalPlayer = game:GetService("Players").LocalPlayer
            ORIGINAL_DASH_SPEED = 60
            DEFAULT_WALK_SPEED = 16
            
            function setupCharacter()
                if LocalPlayer.Character then
                    Character = LocalPlayer.Character
                    Humanoid = Character:FindFirstChildOfClass("Humanoid")
                    HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
                    
                    if Humanoid then
                        Humanoid.WalkSpeed = DEFAULT_WALK_SPEED
                        Humanoid.AutoRotate = true
                    end
                    
                    return Character, Humanoid, HumanoidRootPart
                end
                return nil, nil, nil
            end
            
            function startOverride(Humanoid, HumanoidRootPart)
                if voidRushState.overrideConnection then return end
                
                voidRushState.overrideConnection = RunService.RenderStepped:Connect(function()
                    if not Humanoid or not HumanoidRootPart or not voidRushOverrideActive then
                        return
                    end
                    
                    Humanoid.WalkSpeed = ORIGINAL_DASH_SPEED
                    Humanoid.AutoRotate = false
                    
                    direction = HumanoidRootPart.CFrame.LookVector
                    horizontalDirection = Vector3.new(direction.X, 0, direction.Z).Unit
                    Humanoid:Move(horizontalDirection)
                end)
            end
            
            function stopOverride()
                if voidRushState.overrideConnection then
                    voidRushState.overrideConnection:Disconnect()
                    voidRushState.overrideConnection = nil
                end
                
                Character, Humanoid = setupCharacter()
                if Humanoid then
                    Humanoid.WalkSpeed = DEFAULT_WALK_SPEED
                    Humanoid.AutoRotate = true
                    Humanoid:Move(Vector3.new(0, 0, 0))
                end
            end
            
            function monitorVoidRush()
                while voidRushOverrideActive do
                    Character, Humanoid, HumanoidRootPart = setupCharacter()
                    
                    if Character and Humanoid and HumanoidRootPart then
                        local voidRushStateAttr = Character:GetAttribute("VoidRushState")
                        if voidRushStateAttr == "Dashing" then
                            startOverride(Humanoid, HumanoidRootPart)
                        else
                            stopOverride()
                        end
                    end
                    
                    task.wait()
                end
                stopOverride()
            end
            
            voidRushState.monitorTask = task.spawn(monitorVoidRush)
            
            voidRushState.characterAddedConnection = LocalPlayer.CharacterAdded:Connect(function(newChar)
                if voidRushOverrideActive then
                    local Humanoid = newChar:WaitForChildOfClass("Humanoid")
                    local HumanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
                    Humanoid.WalkSpeed = DEFAULT_WALK_SPEED
                    Humanoid.AutoRotate = true
                end
            end)
        end
    end
})
end

ZZ = Tabs.yul:AddLeftGroupbox('绕过飞行')

CFSpeed = 50
CFLoop = nil

function StartCFly()
    local speaker = game.Players.LocalPlayer
    local character = speaker.Character
    if not character then return end
    
    local humanoid = character:FindFirstChildOfClass('Humanoid')
    local head = character:WaitForChild("Head")
    
    if not humanoid or not head then return end
    
    humanoid.PlatformStand = true
    head.Anchored = true
    
    if CFLoop then 
        CFLoop:Disconnect() 
        CFLoop = nil
    end
    
    CFLoop = RunService.Heartbeat:Connect(function(deltaTime)
        if not character or not humanoid or not head then 
            if CFLoop then 
                CFLoop:Disconnect() 
                CFLoop = nil
            end
            return 
        end
        
        local moveDirection = humanoid.MoveDirection * (CFSpeed * deltaTime)
        local headCFrame = head.CFrame
        local camera = workspace.CurrentCamera
        local cameraCFrame = camera.CFrame
        local cameraOffset = headCFrame:ToObjectSpace(cameraCFrame).Position
        cameraCFrame = cameraCFrame * CFrame.new(-cameraOffset.X, -cameraOffset.Y, -cameraOffset.Z + 1)
        local cameraPosition = cameraCFrame.Position
        local headPosition = headCFrame.Position

        local objectSpaceVelocity = CFrame.new(cameraPosition, Vector3.new(headPosition.X, cameraPosition.Y, headPosition.Z)):VectorToObjectSpace(moveDirection)
        head.CFrame = CFrame.new(headPosition) * (cameraCFrame - cameraPosition) * CFrame.new(objectSpaceVelocity)
    end)
end

function StopCFly()
    local speaker = game.Players.LocalPlayer
    local character = speaker.Character
    
    if CFLoop then
        CFLoop:Disconnect()
        CFLoop = nil
    end
    
    if character then
        local humanoid = character:FindFirstChildOfClass('Humanoid')
        local head = character:FindFirstChild("Head")
        
        if humanoid then
            humanoid.PlatformStand = false
        end
        if head then
            head.Anchored = false
        end
    end
end

ZZ:AddToggle("CFlyToggle", {
    Text = "飞行",
    Default = false,
    Callback = function(Value)
        if Value then
            StartCFly()
        else
            StopCFly()
        end
    end
})

ZZ:AddSlider("CFlySpeed", {
    Text = "飞行速度",
    Default = 50,
    Min = 1,
    Max = 200,
    Rounding = 1,
    Callback = function(Value)
        CFSpeed = Value
    end
})

FunGroup = Tabs.yul:AddRightGroupbox("后空翻")

ff_connection = nil
ff_enabled = false
ff_cd = false
jumpHeight = 72  -- 默认高度: 6 * 12 = 72
jumpDistance = 35  -- 默认距离

function Flip()
    if ff_cd then
        return
    end
    ff_cd = true
character = game.Players.LocalPlayer.Character
    if not character then
        ff_cd = false
        return
    end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local Humanoid = character:FindFirstChildOfClass("Humanoid")
    local animator = Humanoid and Humanoid:FindFirstChildOfClass("Animator")
    if not hrp or not Humanoid then
        ff_cd = false
        return
    end
    local savedTracks = {}
    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            savedTracks[#savedTracks + 1] = { track = track, time = track.TimePosition }
            track:Stop(0)
        end
    end
    Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, false)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
    local duration = 0.45
    local steps = 120
    local startCFrame = hrp.CFrame
    local forwardVector = startCFrame.LookVector
    local upVector = Vector3.new(0, 1, 0)
    task.spawn(function()
        local startTime = tick()
        for i = 1, steps do
            local t = i / steps
            local height = jumpHeight * (t - t ^ 2)  -- 使用滑块调节的高度
            local nextPos = startCFrame.Position + forwardVector * (jumpDistance * t) + upVector * height    
            local rotation = startCFrame.Rotation * CFrame.Angles(-math.rad(i * (360 / steps)), 0, 0)

            hrp.CFrame = CFrame.new(nextPos) * rotation
            local elapsedTime = tick() - startTime
            local expectedTime = (duration / steps) * i
            local waitTime = expectedTime - elapsedTime
            if waitTime > 0 then
                task.wait(waitTime)
            end
        end

        hrp.CFrame = CFrame.new(startCFrame.Position + forwardVector * jumpDistance) * startCFrame.Rotation
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
        Humanoid:ChangeState(Enum.HumanoidStateType.Running)

        if animator then
            for _, data in ipairs(savedTracks) do
                local track = data.track
                track:Play()
                track.TimePosition = data.time
            end
        end
        task.wait(0.25)
        ff_cd = false
    end)
end

sausageHolder = nil
originalSize = nil
ff_button = nil

function SetFrontFlip(bool)
    ff_enabled = bool
    if ff_enabled == true then
        pcall(function()
            sausageHolder = game.CoreGui.TopBarApp.TopBarApp.UnibarLeftFrame.UnibarMenu["2"]
            originalSize = sausageHolder.Size.X.Offset
            ff_button = Instance.new("Frame", sausageHolder)
            ff_button.Size = UDim2.new(0, 48, 0, 44)
            ff_button.BackgroundTransparency = 1
            ff_button.BorderSizePixel = 0
            ff_button.Position = UDim2.new(0, sausageHolder.Size.X.Offset - 48, 0, 0)
            
            imageButton = Instance.new("ImageButton", ff_button)
            imageButton.BackgroundTransparency = 1
            imageButton.BorderSizePixel = 0
            imageButton.Size = UDim2.new(0, 36, 0, 36)
            imageButton.AnchorPoint = Vector2.new(0.5, 0.5)
            imageButton.Position = UDim2.new(0.5, 0, 0.5, 0)
            imageButton.Image = "rbxthumb://type=Asset&id=2714338264&w=150&h=150"
            
            ff_connection = imageButton.Activated:Connect(Flip)
            sausageHolder.Size = UDim2.new(0, originalSize + 48, 0, sausageHolder.Size.Y.Offset)
            task.wait()
            ff_button.Position = UDim2.new(0, sausageHolder.Size.X.Offset - 48, 0, 0)
            
            task.spawn(function()
                pcall(function()
                    repeat
                        sausageHolder.Size = UDim2.new(0, originalSize + 48, 0, sausageHolder.Size.Y.Offset)
                        task.wait()
                        ff_button.Position = UDim2.new(0, sausageHolder.Size.X.Offset - 48, 0, 0)
                    until ff_enabled == false
                end)
            end)
        end)
    elseif ff_enabled == false then
        if ff_connection then
            ff_connection:Disconnect()
            ff_connection = nil
        end
        if ff_button then
            ff_button:Destroy()
            ff_button = nil
        end
        if sausageHolder then
            sausageHolder.Size = UDim2.new(0, originalSize, 0, sausageHolder.Size.Y.Offset)
        end
    end
end

FunGroup:AddToggle("Frontflip", {
    Text = "显示后空翻按钮",
    Default = false,
    Tooltip = "启用后空翻功能",
    Callback = function(Value)
        SetFrontFlip(Value)
        Library:Notify({
            Title = "后空翻",
            Description = Value and "后空翻已启用" or "后空翻已禁用",
            Time = 3,
        })
    end,
})

FunGroup:AddSlider("JumpHeight", {
    Text = "跳跃高度",
    Default = 72,
    Min = 20,
    Max = 200,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        jumpHeight = Value
        Library:Notify({
            Title = "跳跃高度",
            Description = "已设置为: " .. Value,
            Time = 2,
        })
    end,
    Tooltip = "调节后空翻的跳跃高度",
})

FunGroup:AddSlider("JumpDistance", {
    Text = "跳跃距离",
    Default = 35,
    Min = 10,
    Max = 100,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        jumpDistance = Value
        Library:Notify({
            Title = "跳跃距离",
            Description = "已设置为: " .. Value,
            Time = 2,
        })
    end,
    Tooltip = "调节后空翻的跳跃距离",
})

if not Tabs.yul then
    Tabs.yul = Window:AddTab('娱乐功能', 'cpu')
end

CameraGroup = Tabs.yul:AddLeftGroupbox("视野")
RunService = game:GetService("RunService")
fovvalue = 70
fovenabled = false
renderConnection = nil

CameraGroup:AddSlider("FieldOfView", {
    Text = "视野范围",
    Default = 70,
    Min = 60,
    Max = 120,
    Rounding = 1,
    Compact = true,
    Callback = function(v)
        pcall(function()
            fovvalue = v
            if fovenabled then
                workspace.CurrentCamera.FieldOfView = v
            end
        end)
    end,
})

CameraGroup:AddCheckbox("CustomFOV", {
    Text = "启用自定义视野",
    Default = false,
    Callback = function(v)
        pcall(function()
            fovenabled = v
            if v then
                workspace.CurrentCamera.FieldOfView = fovvalue
                if not renderConnection then
                    renderConnection = RunService.RenderStepped:Connect(function()
                        if fovenabled then
                            workspace.CurrentCamera.FieldOfView = fovvalue
                        end
                    end)
                end
            else
                workspace.CurrentCamera.FieldOfView = 70
                if renderConnection then
                    renderConnection:Disconnect()
                    renderConnection = nil
                end
            end
        end)
    end,
})

InvisibleGroup = Tabs.yul:AddRightGroupbox("隐身")
invisibleEnabled = false
invisibleDisconnect = nil

function StartInvisible()
    Players = game:GetService("Players")
    player = Players.LocalPlayer
    character = player.Character or player.CharacterAdded:Wait()
    if not character then return nil end
    rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end
    originalCFrame = rootPart.CFrame
    rootPart.CFrame = originalCFrame + Vector3.new(0, -300, 0)
    rootPart.Anchored = true
    task.wait(1)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local TargetRemote = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Network"):WaitForChild("Network"):WaitForChild("UnreliableRemoteEvent")
    local OldNamecall, OldFireServer, DiedConnection, RemovingConnection
    local function DisconnectSpy()
        if DiedConnection then DiedConnection:Disconnect() end
        if RemovingConnection then RemovingConnection:Disconnect() end
        if OldNamecall then
            if hookmetamethod then
                hookmetamethod(game, "__namecall", OldNamecall)
            else
                local mt = getrawmetatable(game)
                setreadonly(mt, false)
                mt.__namecall = OldNamecall
                setreadonly(mt, true)
            end
        end
        if OldFireServer then
            hookfunction(TargetRemote.FireServer, OldFireServer)
        end
    end
    RemovingConnection = player.CharacterRemoving:Connect(DisconnectSpy)
    if player.Character then
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            DiedConnection = humanoid.Died:Connect(DisconnectSpy)
        end
    end
    if hookmetamethod then
        OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if self == TargetRemote and (method == "FireServer" or method == "fireServer") then
                return
            end
            return OldNamecall(self, ...)
        end))
    else
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        OldNamecall = mt.__namecall
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if self == TargetRemote and (method == "FireServer" or method == "fireServer") then
                return
            end
            return OldNamecall(self, ...)
        end)
        setreadonly(mt, true)
    end
    if hookfunction then
        OldFireServer = hookfunction(TargetRemote.FireServer, newcclosure(function(self, ...)
            if self == TargetRemote then
                return
            end
            return OldFireServer(self, ...)
        end))
    end
    task.wait(1)
    rootPart.Anchored = false
    rootPart.CFrame = originalCFrame
    return DisconnectSpy
end

InvisibleGroup:AddToggle("InvisibleToggle", {
    Text = "启用隐身",
    Default = false,
    Callback = function(Value)
        if Value then
            if not invisibleEnabled then
                invisibleDisconnect = StartInvisible()
                invisibleEnabled = true
            end
        else
            if invisibleEnabled then
                if invisibleDisconnect then
                    invisibleDisconnect()
                    invisibleDisconnect = nil
                end
                invisibleEnabled = false
            end
        end
    end
})


MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("菜单", "wrench")

MenuGroup:AddToggle("KeybindMenuOpen", {
	Default = Library.KeybindFrame.Visible,
	Text = "打开快捷键菜单",
	Callback = function(value)
		Library.KeybindFrame.Visible = value
	end,
})
MenuGroup:AddToggle("ShowCustomCursor", {
	Text = "自定义光标",
	Default = true,
	Callback = function(Value)
		Library.ShowCustomCursor = Value
	end,
})
MenuGroup:AddDropdown("NotificationSide", {
	Values = { "Left", "Right" },
	Default = "Right",
	Text = "通知位置",
	Callback = function(Value)
		Library:SetNotifySide(Value)
	end,
})
MenuGroup:AddDropdown("DPIDropdown", {
	Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
	Default = "100%",
	Text = "DPI缩放",
	Callback = function(Value)
		Value = Value:gsub("%%", "")
		local DPI = tonumber(Value)
		Library:SetDPIScale(DPI)
	end,
})
MenuGroup:AddDivider()
MenuGroup:AddLabel("菜单快捷键")
	:AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "菜单快捷键" })

MenuGroup:AddButton("卸载", function()
	Library:Unload()
end)

Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

ThemeManager:SetFolder("MyScriptHub")
SaveManager:SetFolder("MyScriptHub/specific-game")
SaveManager:SetSubFolder("specific-place")

SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])
SaveManager:LoadAutoloadConfig()
