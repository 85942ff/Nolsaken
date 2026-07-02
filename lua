local repo = "https://raw.githubusercontent.com/SyndromeXph/NOL-Obsidian/refs/heads/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

Library.ForceCheckbox = false
Library.ShowToggleFrameInKeybinds = true


local LibESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/ImamGV/Script/main/ESP"))()

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
	Bro = Window:AddTab('绘制', 'eye'),           -- 别名，指向 Visual
	Block = Window:AddTab('格挡', 'user'),        -- 别名，指向 zdg
	Sat = Window:AddTab('体力', 'zap'),
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
   local args = {"UseActorAbility", {buffer.fromstring("\3\5\0\0\0Block")}}
   game:GetService("ReplicatedStorage").Modules.Network.RemoteEvent:FireServer(unpack(args))
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

local SpecialAimbot = Tabs.Aimbot:AddLeftGroupbox("访客自瞄")

-- 默认距离设置
local aimbotGroup = SpecialAimbot or Tabs.Aimbot or Tabs.zdg or Tabs
if not aimbotGroup then
    error("无法找到 UI 群组，请检查你的 UI 框架变量名")
end

local defaultAimDistance = 100
local aimDistanceSettings = { GAA = defaultAimDistance }
local aimSmoothnessSettings = { GAA = 20 }
local aimDurationSettings = { GAA = 25 }

pcall(function()
    aimbotGroup:AddSlider("GAA_Distance", {
        Text = "访客自瞄距离",
        Default = defaultAimDistance,
        Min = 10,
        Max = 500,
        Rounding = 1,
        Callback = function(value)
            aimDistanceSettings.GAA = value
        end
    })
end)
pcall(function()
    aimbotGroup:AddSlider("GAA_Smoothness", {
        Text = "相机平滑度",
        Default = aimSmoothnessSettings.GAA,
        Min = 5,
        Max = 100,
        Rounding = 1,
        Callback = function(value)
            aimSmoothnessSettings.GAA = value
        end
    })
end)
pcall(function()
    aimbotGroup:AddSlider("GAA_Duration", {
        Text = "相机锁定持续时间(帧)",
        Default = aimDurationSettings.GAA,
        Min = 10,
        Max = 200,
        Rounding = 1,
        Callback = function(value)
            aimDurationSettings.GAA = value
        end
    })
end)

local function SmoothCameraLookAt(currentCamCF, targetPos, smoothness)
    local targetLook = (targetPos - currentCamCF.Position).Unit
    local currentLook = currentCamCF.LookVector
    local newLook = currentLook:Lerp(targetLook, 1 / smoothness)
    return CFrame.lookAt(currentCamCF.Position, currentCamCF.Position + newLook * 100)
end

local function getNearestKiller()
    local killersFolder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Killers")
    if not killersFolder then return nil end
    local myHRP = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end
    local nearest, nearestDist = nil, math.huge
    for _, killer in ipairs(killersFolder:GetChildren()) do
        if killer:IsA("Model") and killer:FindFirstChild("HumanoidRootPart") then
            local dist = (killer.HumanoidRootPart.Position - myHRP.Position).Magnitude
            if dist < nearestDist and dist <= aimDistanceSettings.GAA then
                nearestDist = dist
                nearest = killer
            end
        end
    end
    return nearest
end

local activeAimConnection = nil

local function executeAim()
    if activeAimConnection then
        activeAimConnection:Disconnect()
        activeAimConnection = nil
    end
    local targetKiller = getNearestKiller()
    if not targetKiller or not targetKiller:FindFirstChild("HumanoidRootPart") then return end
    local smoothness = aimSmoothnessSettings.GAA
    local duration = aimDurationSettings.GAA
    local iterations = 0
    local conn
    conn = game:GetService("RunService").RenderStepped:Connect(function()
        iterations = iterations + 1
        if iterations <= duration then
            local currentCamCF = workspace.CurrentCamera.CFrame
            local targetPos = targetKiller.HumanoidRootPart.Position
            workspace.CurrentCamera.CFrame = SmoothCameraLookAt(currentCamCF, targetPos, smoothness)
        else
            conn:Disconnect()
            if activeAimConnection == conn then activeAimConnection = nil end
        end
    end)
    activeAimConnection = conn
end

local aimConnection = nil
local function setupGuestAim(enabled)
    if aimConnection then
        aimConnection:Disconnect()
        aimConnection = nil
    end
    if not enabled then
        if activeAimConnection then
            activeAimConnection:Disconnect()
            activeAimConnection = nil
        end
        return
    end
    local player = game.Players.LocalPlayer
    local character = player.Character
    if not character then
        player.CharacterAdded:Wait()
        character = player.Character
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end
    
    local targetAnimIds = {
        ["rbxassetid://103601716322988"] = true,
    ["rbxassetid://133491532453922"] = true,
    ["rbxassetid://86371356500204"] = true,
    ["rbxassetid://76649505662612"] = true,
    ["rbxassetid://81698196845041"] = true,
    ["rbxassetid://111918351126361"] = true,
    ["rbxassetid://77894750279891"] = true,
    ["rbxassetid://99050723653468"] = true,
    ["rbxassetid://119181003138006"] = true,
    ["rbxassetid://18885919947"] = true,
    ["rbxassetid://106527725058030"] = true,
    ["rbxassetid://139929602101552"] = true
}
    
    aimConnection = animator.AnimationPlayed:Connect(function(animationTrack)
        if animationTrack.Animation and animationTrack.Animation.AnimationId then
            local animId = animationTrack.Animation.AnimationId
            for _, id in ipairs(targetAnimIds) do
                if animId == id then
                    executeAim()
                    break
                end
            end
        end
    end)
end

pcall(function()
    aimbotGroup:AddToggle("GuestAimToggle", {
        Text = "访客相机自瞄（出拳时触发）",
        Default = false,
        Callback = function(v)
            setupGuestAim(v)
        end
    })
end)

print("访客自瞄已加载，触发动画ID: 130013637722362 或 122875546317402")

local aimbotNoilsounds = {
    "rbxassetid://90382006346718"
}
local aimbotNoilsounds2 = {
    "rbxassetid://134547841416465"
}
local Noloop = nil
local No2loop = nil

local aimSettings = {
    maxDistance = 50,
    lockTime = 3.3
}

local g = Tabs.Aimbot:AddRightGroupbox('Noli自瞄')

g:AddSlider('AimDistance', {
    Text = '自瞄距离',
    Default = aimSettings.maxDistance,
    Min = 10,
    Max = 100,
    Rounding = 0,
    Compact = false,
    Callback = function(value)
        aimSettings.maxDistance = value
    end
})

g:AddSlider('LockTime', {
    Text = '自瞄锁定时长 (秒)',
    Default = aimSettings.lockTime,
    Min = 0.5,
    Max = 5,
    Rounding = 1,
    Compact = false,
    Callback = function(value)
        aimSettings.lockTime = value
    end
})

local function SmoothLookAt(currentCF, targetPos, smoothness)
    local targetLook = (targetPos - currentCF.Position).Unit
    local currentLook = currentCF.LookVector
    local newLook = currentLook:Lerp(targetLook, 1 / smoothness)
    return CFrame.lookAt(currentCF.Position, currentCF.Position + newLook * 100)
end

local function getNearestSurvivor()
    local player = game.Players.LocalPlayer
    local nearest, nearestDist = nil, math.huge
    for _, p in ipairs(game.Players:GetPlayers()) do
        if p ~= player then
            local char = p.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local myHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if myHRP then
                    local dist = (char.HumanoidRootPart.Position - myHRP.Position).Magnitude
                    if dist < nearestDist and dist <= aimSettings.maxDistance then
                        nearestDist = dist
                        nearest = char
                    end
                end
            end
        end
    end
    return nearest
end

local function executeAim()
    local player = game.Players.LocalPlayer
    local target = getNearestSurvivor()
    if not target or not target:FindFirstChild("HumanoidRootPart") then return end
    local myHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    local smoothness = 30
    local maxIterations = math.floor(aimSettings.lockTime / 0.016)
    local iterations = 0
    local conn
    conn = game:GetService("RunService").RenderStepped:Connect(function()
        iterations = iterations + 1
        if iterations <= maxIterations then
            if myHRP and myHRP.Parent and target.Parent then
                local currentCF = myHRP.CFrame
                local targetPos = target.HumanoidRootPart.Position
                myHRP.CFrame = SmoothLookAt(currentCF, targetPos, smoothness)
                workspace.CurrentCamera.CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position, targetPos)
            else
                conn:Disconnect()
            end
        else
            conn:Disconnect()
        end
    end)
end

local function Noaimbot(state)
    if Noloop then Noloop:Disconnect() end
    if not state then
        Noloop = nil
        return
    end
    local player = game.Players.LocalPlayer
    if player.Character and player.Character.Name ~= "Noli" then
        Library:Notify("角色不对，可能出现错误", nil, 4590657391)
        return
    end
    local character = player.Character
    if not character then
        player.CharacterAdded:Wait()
        character = player.Character
    end
    Noloop = character.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("Sound") then
            for _, soundId in ipairs(aimbotNoilsounds) do
                if descendant.SoundId == soundId then
                    executeAim()
                    break
                end
            end
        end
    end)
end

local function No2aimbot(state)
    if No2loop then No2loop:Disconnect() end
    if not state then
        No2loop = nil
        return
    end
    local player = game.Players.LocalPlayer
    if player.Character and player.Character.Name ~= "Noli" then
        Library:Notify("角色不对，可能出现错误", nil, 4590657391)
        return
    end
    local character = player.Character
    if not character then
        player.CharacterAdded:Wait()
        character = player.Character
    end
    No2loop = character.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("Sound") then
            for _, soundId in ipairs(aimbotNoilsounds2) do
                if descendant.SoundId == soundId then
                    executeAim()
                    break
                end
            end
        end
    end)
end

g:AddToggle('NoilStarBomb', {
    Text = 'Noil星炸弹自瞄',
    Default = false,
    Callback = function(state)
        Noaimbot(state)
    end
})

g:AddToggle('NoilVoidRush', {
    Text = 'Noil冲刺自瞄',
    Default = false,
    Callback = function(state)
        No2aimbot(state)
    end
})

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

local function CreateFeatures()
    if not Tabs or not Tabs.tfz then
        warn("UI 容器未找到")
        return
    end

    local MainGroup = Tabs.tfz:AddLeftGroupbox("传送 & 吸血鬼")

    local player = game.Players.LocalPlayer
    if not player then
        warn("无法获取 LocalPlayer")
        return
    end

    local function getEventName()
        local currentPlayer = game.Players.LocalPlayer
        if not currentPlayer then return nil end
        return "" .. currentPlayer.Name .. "NosEndFlight"
    end

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

    local teleportRunning = false
    local teleportThread = nil
    local teleportInterval = 0.1

    local vampireRunning = false
    local vampireThread = nil
    local vampireInterval = 0.1

    local function teleportToFirstSurvivor()
        local survivors = workspace.Players:FindFirstChild("Survivors")
        if not survivors then return end
        local list = survivors:GetChildren()
        if #list == 0 then return end

        local survivor = list[1]
        local targetPart = survivor and (survivor:FindFirstChild("PrimaryPart") or survivor:FindFirstChild("HumanoidRootPart"))
        if not targetPart then return end

        local localPlayer = game.Players.LocalPlayer
        local char = localPlayer and localPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            pcall(function()
                root.CFrame = targetPart.CFrame
            end)
        end
    end

    local function fireVampireEvent()
        local eventName = getEventName()
        if not eventName then return end

        if vampireRunning then
            updateEventLabel("吸血鬼事件: " .. eventName)
        end

        pcall(function()
            local remote = game:GetService("ReplicatedStorage")
                :WaitForChild("Modules")
                :WaitForChild("Network")
                :WaitForChild("RemoteEvent")
            remote:FireServer(eventName, { buffer.fromstring("\1\1") })
        end)
    end

    MainGroup:AddToggle("TeleportToggle", {
        Text = "传送幸存者",
        Default = false,
        Risky = true,
        Callback = function(state)
            teleportRunning = state
            teleportThread = nil
            if state then
                teleportThread = task.spawn(function()
                    while teleportRunning do
                        teleportToFirstSurvivor()
                        task.wait(teleportInterval)
                    end
                end)
            end
        end,
    })

    MainGroup:AddSlider("TeleportSpeed", {
        Text = "传送间隔",
        Default = 0.1,
        Min = 0,
        Max = 1.0,
        Rounding = 1,
        Callback = function(value)
            teleportInterval = value
        end
    })

    MainGroup:AddToggle("VampireToggle", {
        Text = "吸血鬼杀戮",
        Default = false,
        Risky = true,
        Callback = function(state)
            vampireRunning = state
            vampireThread = nil
            if state then
                local eventName = getEventName()
                if eventName then
                    updateEventLabel("吸血鬼事件: " .. eventName)
                end
                vampireThread = task.spawn(function()
                    while vampireRunning do
                        fireVampireEvent()
                        task.wait(vampireInterval)
                    end
                end)
            else
                updateEventLabel("吸血鬼事件: 未启用")
            end
        end,
    })

    MainGroup:AddSlider("VampireSpeed", {
        Text = "吸血鬼间隔",
        Default = 0.1,
        Min = 0,
        Max = 2.0,
        Rounding = 1,
        Callback = function(value)
            vampireInterval = value
        end
    })
end

CreateFeatures()

local ZZ = Tabs.ani:AddLeftGroupbox('Noli反效果')

local noliDeleterActive = false
local deletionConnection = nil
local allowedNoli = nil
local isVoidRushCrashed = false
local characterCheckLoop = nil
local voidRushOverrideActive = false
local voidRushState = {}
local RunService = game:GetService("RunService")

local function deleteNewNoli()
    local killersFolder = workspace:WaitForChild("Players")
    local killers = killersFolder:WaitForChild("Killers")
    
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
            local LocalPlayer = game:GetService("Players").LocalPlayer
            local ORIGINAL_DASH_SPEED = 60
            local DEFAULT_WALK_SPEED = 16
            
            local function setupCharacter()
                if LocalPlayer.Character then
                    local Character = LocalPlayer.Character
                    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
                    local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
                    
                    if Humanoid then
                        Humanoid.WalkSpeed = DEFAULT_WALK_SPEED
                        Humanoid.AutoRotate = true
                    end
                    
                    return Character, Humanoid, HumanoidRootPart
                end
                return nil, nil, nil
            end
            
            local function startOverride(Humanoid, HumanoidRootPart)
                if voidRushState.overrideConnection then return end
                
                voidRushState.overrideConnection = RunService.RenderStepped:Connect(function()
                    if not Humanoid or not HumanoidRootPart or not voidRushOverrideActive then
                        return
                    end
                    
                    Humanoid.WalkSpeed = ORIGINAL_DASH_SPEED
                    Humanoid.AutoRotate = false
                    
                    local direction = HumanoidRootPart.CFrame.LookVector
                    local horizontalDirection = Vector3.new(direction.X, 0, direction.Z).Unit
                    Humanoid:Move(horizontalDirection)
                end)
            end
            
            local function stopOverride()
                if voidRushState.overrideConnection then
                    voidRushState.overrideConnection:Disconnect()
                    voidRushState.overrideConnection = nil
                end
                
                local Character, Humanoid = setupCharacter()
                if Humanoid then
                    Humanoid.WalkSpeed = DEFAULT_WALK_SPEED
                    Humanoid.AutoRotate = true
                    Humanoid:Move(Vector3.new(0, 0, 0))
                end
            end
            
            local function monitorVoidRush()
                while voidRushOverrideActive do
                    local Character, Humanoid, HumanoidRootPart = setupCharacter()
                    
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

local ZZ = Tabs.ani:AddRightGroupbox('谢德反效果')

ZZ:AddToggle("RemoveStunningKiller", {
    Text = "反谢德挥剑速度", 
    Default = false,
    Callback = function(v)
        if not _G.StunningKillerCleanup then _G.StunningKillerCleanup = {} end
        local connections = _G.StunningKillerCleanup

        for _, conn in pairs(connections) do
            if typeof(conn) == "RBXScriptConnection" then
                conn:Disconnect()
            end
        end
        _G.StunningKillerCleanup = {}

        if not v then return end

        local function CleanStunningKillers()
            local survivorsFolder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Survivors")
            if not survivorsFolder then return end
            
            local survivorList = survivorsFolder:GetChildren()
            for i = 1, #survivorList, 5 do
                task.spawn(function()
                    for j = i, math.min(i + 4, #survivorList) do
                        local survivor = survivorList[j]
                        local stunningKiller = survivor:FindFirstChild("StunningKiller")
                        if stunningKiller then
                            stunningKiller:Destroy()
                        end
                    end
                end)
            end
        end

        task.spawn(CleanStunningKillers)

        connections.heartbeat = game:GetService("RunService").Heartbeat:Connect(function()
            task.wait(2)
            CleanStunningKillers()
        end)

        local survivorsFolder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Survivors")
        if survivorsFolder then
            connections.descendantAdded = survivorsFolder.DescendantAdded:Connect(function(descendant)
                if descendant.Name == "StunningKiller" then
                    descendant:Destroy()
                end
            end)
        end
    end
})

local ZZ2 = Tabs.ani:AddRightGroupbox('NOOB 反效果')

ZZ2:AddToggle("RemoveSlateskin", {
    Text = "反Noob石板速度", 
    Default = false,
    Callback = function(v)
        if not _G.SlateskinCleanup then _G.SlateskinCleanup = {} end
        local connections = _G.SlateskinCleanup

        for _, conn in pairs(connections) do
            if typeof(conn) == "RBXScriptConnection" then
                conn:Disconnect()
            end
        end
        _G.SlateskinCleanup = {}

        if not v then return end

        local function CleanSlateskins()
            local survivorsFolder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Survivors")
            if not survivorsFolder then return end
            
            local survivorList = survivorsFolder:GetChildren()
            for i = 1, #survivorList, 5 do
                task.spawn(function()
                    for j = i, math.min(i + 4, #survivorList) do
                        local survivor = survivorList[j]
                        local slateskin = survivor:FindFirstChild("SlateskinStatus")
                        if slateskin then
                            slateskin:Destroy()
                        end
                    end
                end)
            end
        end

        task.spawn(CleanSlateskins)

        connections.heartbeat = game:GetService("RunService").Heartbeat:Connect(function()
            task.wait(2)
            CleanSlateskins()
        end)

        local survivorsFolder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Survivors")
        if survivorsFolder then
            connections.descendantAdded = survivorsFolder.DescendantAdded:Connect(function(descendant)
                if descendant.Name == "SlateskinStatus" then
                    descendant:Destroy()
                end
            end)
        end
    end
})

local Disabled = Tabs.ani:AddLeftGroupbox('访客反效果')

Disabled:AddToggle("RemoveSlowed", {
    Text = "反缓慢", 
    Default = false,
    Callback = function(v)
        if not _G.SlowedCleanup then _G.SlowedCleanup = {} end
        local connections = _G.SlowedCleanup

        for _, conn in pairs(connections) do
            if typeof(conn) == "RBXScriptConnection" then
                conn:Disconnect()
            end
        end
        _G.SlowedCleanup = {}

        if not v then return end

        local function CleanSlowedStatuses()
            local survivorsFolder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Survivors")
            if not survivorsFolder then return end
            
            for _, survivor in ipairs(survivorsFolder:GetDescendants()) do
                if survivor.Name == "SlowedStatus" then
                    survivor:Destroy()
                end
            end
        end

        task.spawn(CleanSlowedStatuses)

        connections.heartbeat = game:GetService("RunService").Heartbeat:Connect(function()
            task.wait(1.5)
            CleanSlowedStatuses()
        end)

        local survivorsFolder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Survivors")
        if survivorsFolder then
            connections.descendantAdded = survivorsFolder.DescendantAdded:Connect(function(descendant)
                if descendant.Name == "SlowedStatus" then
                    descendant:Destroy()
                end
            end)
        end
    end
})

Disabled:AddToggle("RemoveBlockingSlow", {
    Text = "反格挡速度", 
    Default = false,
    Callback = function(v)
        if not _G.BlockingCleanup then _G.BlockingCleanup = {} end
        local connections = _G.BlockingCleanup

        for _, conn in pairs(connections) do
            if typeof(conn) == "RBXScriptConnection" then
                conn:Disconnect()
            end
        end
        _G.BlockingCleanup = {}

        if not v then return end

        local function CleanStatuses()
            local survivorsFolder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Survivors")
            if not survivorsFolder then return end
            
            for _, survivor in ipairs(survivorsFolder:GetDescendants()) do
                if survivor.Name == "ResistanceStatus" or survivor.Name == "GuestBlocking" then
                    survivor:Destroy()
                end
            end
        end

        task.spawn(CleanStatuses)

        connections.heartbeat = game:GetService("RunService").Heartbeat:Connect(function()
            task.wait(1.5)
            CleanStatuses()
        end)

        local survivorsFolder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Survivors")
        if survivorsFolder then
            connections.descendantAdded = survivorsFolder.DescendantAdded:Connect(function(descendant)
                if descendant.Name == "ResistanceStatus" or descendant.Name == "GuestBlocking" then
                    descendant:Destroy()
                end
            end)
        end
    end
})

Disabled:AddToggle("RemovePunchSlow", {
    Text = "反拳击速度", 
    Default = false,
    Callback = function(v)
        if not _G.PunchCleanup then _G.PunchCleanup = {} end
        local connections = _G.PunchCleanup

        for _, conn in pairs(connections) do
            if typeof(conn) == "RBXScriptConnection" then
                conn:Disconnect()
            end
        end
        _G.PunchCleanup = {}

        if not v then return end

        local function CleanStatuses()
            local survivorsFolder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Survivors")
            if not survivorsFolder then return end
            
            for _, survivor in ipairs(survivorsFolder:GetDescendants()) do
                if survivor.Name == "ResistanceStatus" or survivor.Name == "PunchAbility" then
                    survivor:Destroy()
                end
            end
        end

        task.spawn(CleanStatuses)

        connections.heartbeat = game:GetService("RunService").Heartbeat:Connect(function()
            task.wait(1.5)
            CleanStatuses()
        end)

        local survivorsFolder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Survivors")
        if survivorsFolder then
            connections.descendantAdded = survivorsFolder.DescendantAdded:Connect(function(descendant)
                if descendant.Name == "ResistanceStatus" or descendant.Name == "PunchAbility" then
                    descendant:Destroy()
                end
            end)
        end
    end
})

Disabled:AddToggle("RemoveChargeEnded", {
    Text = "反冲刺结束后效果", 
    Default = false,
    Callback = function(v)
        if not _G.ChargeEndedCleanup then _G.ChargeEndedCleanup = {} end
        local connections = _G.ChargeEndedCleanup

        for _, conn in pairs(connections) do
            if typeof(conn) == "RBXScriptConnection" then
                conn:Disconnect()
            end
        end
        _G.ChargeEndedCleanup = {}

        if not v then return end

        local function CleanChargeEndedEffects()
            local survivorsFolder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Survivors")
            if not survivorsFolder then return end
            
            for _, survivor in ipairs(survivorsFolder:GetDescendants()) do
                if survivor.Name == "GuestChargeEnded" then
                    survivor:Destroy()
                end
            end
        end

        task.spawn(CleanChargeEndedEffects)

        connections.heartbeat = game:GetService("RunService").Heartbeat:Connect(function()
            task.wait(1.5)
            CleanChargeEndedEffects()
        end)

        local survivorsFolder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Survivors")
        if survivorsFolder then
            connections.descendantAdded = survivorsFolder.DescendantAdded:Connect(function(descendant)
                if descendant.Name == "GuestChargeEnded" then
                    descendant:Destroy()
                end
            end)
        end
    end
})

local ZZ = Tabs.yul:AddLeftGroupbox('绕过飞行')

local CFSpeed = 50
local CFLoop = nil

local function StartCFly()
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

local function StopCFly()
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

local FunGroup = Tabs.yul:AddRightGroupbox("后空翻")

local ff_connection = nil
local ff_enabled = false
local ff_cd = false
local jumpHeight = 72  -- 默认高度: 6 * 12 = 72
local jumpDistance = 35  -- 默认距离

local function Flip()
    if ff_cd then
        return
    end
    ff_cd = true
    local character = game.Players.LocalPlayer.Character
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

local sausageHolder = nil
local originalSize = nil
local ff_button = nil

local function SetFrontFlip(bool)
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
            
            local imageButton = Instance.new("ImageButton", ff_button)
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

local CameraGroup = Tabs.yul:AddLeftGroupbox("视野")
local RunService = game:GetService("RunService")
local fovvalue = 70
local fovenabled = false
local renderConnection = nil

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


local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("菜单", "wrench")

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
