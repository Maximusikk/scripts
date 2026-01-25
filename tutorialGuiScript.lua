-- StarterGui/TutorialGui/LocalScript
-- ✅ Behavior:
-- 1) Slides tutorial -> finish -> interactive quest tutorial starts (arrows/quests)
-- 2) “Dumb mode”: for every block-opening quest we point arrow to the correct block
-- 3) After EVERY hatched NFT we remind player to equip it (Inventory -> click NFT)

local DEBUG_ALWAYS_SHOW_TUTORIAL = true

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local inventoryFolder   = player:WaitForChild("Inventory")
local currencies        = player:WaitForChild("Currencies")
local worldCurrencies   = currencies:WaitForChild("WorldCurrencies")
local world1Currency    = worldCurrencies:WaitForChild("World1")
local gemsCurrency      = currencies:WaitForChild("Gems")
local activeBoostsFolder = player:WaitForChild("ActiveBoostsFolder")

local lastHatchedUuid : string? = nil
-- флаги шага с ховербордом (глобальные для этого скрипта)
local hoverboardStepActive  = false
local hoverboardStepDone    = false

---------------------------------------------------------------------
-- TRACK INVENTORY NFT
---------------------------------------------------------------------

-- ✅ Универсальная проверка "это NFT нода в инвентаре?"
-- У тебя сервер делает Folder-ноды с атрибутами Name/Crust/Background/Power.
-- Поэтому НЕ полагаемся на IsNft (его может не быть).
local function isInventoryNftNode(child: Instance): boolean
	if not child or not child:IsA("Folder") then return false end
	-- Гайд-робот не считаем "хэтчем"
	if child:GetAttribute("IsGuide") == true then return false end

	local nm = child:GetAttribute("Name")
	if typeof(nm) == "string" and nm ~= "" then
		return true
	end

	-- запасной вариант: если в будущем вернёшь IsNft
	if child:GetAttribute("IsNft") == true then
		return true
	end

	return false
end

local knownNfts = {}
for _, child in ipairs(inventoryFolder:GetChildren()) do
	knownNfts[child.Name] = true
end

inventoryFolder.ChildAdded:Connect(function(child: Instance)
	-- ✅ если пришёл гайд-робот (сервер выдал после завершения туториала)
	if child:GetAttribute("IsGuide") == true then
		-- не выключаем GUI туториала, просто уведомляем
		local notifyLabel = script.Parent:FindFirstChild("NotifyText")
		if notifyLabel and notifyLabel:IsA("TextLabel") then
			notifyLabel.Visible = true
			notifyLabel.Text = "You received a Guide Robot!\nIts power matches the average power of your current world."
			task.delay(6, function()
				if notifyLabel and notifyLabel.Parent and notifyLabel.Text:find("Guide Robot") then
					notifyLabel.Visible = false
				end
			end)
		end
		return
	end

	-- оставляю твою логику, но делаю её устойчивой:
	-- если NFT реально новый — фиксируем; если не новый — не перетираем lastHatchedUuid без необходимости
	if not knownNfts[child.Name] then
		knownNfts[child.Name] = true
		if isInventoryNftNode(child) then
			lastHatchedUuid = child.Name
			warn("[Tutorial] Inventory ChildAdded (NEW NFT), lastHatchedUuid =", lastHatchedUuid)
		end
	else
		if isInventoryNftNode(child) then
			-- иногда сервер/клиент создаёт NFT повторно/репликацией,
			-- но если это тот же самый — не перетираем логикой "поздний дубль"
			if lastHatchedUuid ~= child.Name then
				lastHatchedUuid = child.Name
				warn("[Tutorial] Inventory ChildAdded (NFT), lastHatchedUuid =", lastHatchedUuid)
			end
		end
	end
end)

---------------------------------------------------------------------
-- GUI
---------------------------------------------------------------------

local tutorialGui = script.Parent
local mainFrame   = tutorialGui:WaitForChild("MainFrame")

tutorialGui.DisplayOrder = 1000

local mainGui : ScreenGui? = playerGui:FindFirstChild("MainGui")
if mainGui and mainGui.DisplayOrder >= tutorialGui.DisplayOrder then
	mainGui.DisplayOrder = tutorialGui.DisplayOrder - 1
end

local skipBtn     = mainFrame:WaitForChild("SkipBtn")
local notifyLabel = tutorialGui:WaitForChild("NotifyText")

local lastNotifyId = 0

local function showNotify(text: string?, duration: number?)
	lastNotifyId += 1
	local thisId = lastNotifyId

	if not text or text == "" then
		notifyLabel.Visible = false
		notifyLabel.Text = ""
		return
	end

	notifyLabel.Visible = true
	notifyLabel.Text = text

	if duration and duration > 0 then
		task.delay(duration, function()
			if lastNotifyId == thisId then
				notifyLabel.Visible = false
			end
		end)
	end
end

---------------------------------------------------------------------
-- REMOTES
---------------------------------------------------------------------

local ShowTutorialEvent          = ReplicatedStorage:WaitForChild("ShowTutorialEvent")
local PetHatchedEvent            = ReplicatedStorage:WaitForChild("PetHatchedEvent")
local UpdateWallsEvent           = ReplicatedStorage:WaitForChild("UpdateWalls")
local ShowBoostTutorialEvent     = ReplicatedStorage:WaitForChild("ShowBoostTutorialEvent")
local GiveHoverTutorialGemsEvent = ReplicatedStorage:WaitForChild("GiveHoverTutorialGems")
local HoverboardPurchasedEvent   = ReplicatedStorage:WaitForChild("HoverboardPurchasedEvent")

local stepOrder = {
	"1thStep","2thStep","3thStep","4thStep","5thStep","6thStep",
	"7thStep","8thStep","9thStep","10thStep","11thStep","12thStep",
}

local ARROW_ROT_OFFSET = CFrame.Angles(math.rad(-90), 0, 0)

---------------------------------------------------------------------
-- MAIN GUI helpers
---------------------------------------------------------------------

local function getMainGui(): ScreenGui?
	if mainGui and mainGui.Parent then
		return mainGui
	end
	mainGui = playerGui:FindFirstChild("MainGui") :: ScreenGui
	return mainGui
end

-- ищем любой открытый InventoryMainFrame во всех ScreenGui
local function findOpenInventoryMain(): Frame?
	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui") and gui.Enabled ~= false then
			local invMain = gui:FindFirstChild("InventoryMainFrame", true)
			if invMain and invMain:IsA("Frame") and invMain.Visible and invMain.AbsoluteSize.Y > 0 then
				return invMain
			end
		end
	end
	return nil
end

-- для буст-туториала: ищем контейнер инвентаря
local function findInventoryContainer(): Frame?
	local mg = getMainGui()
	if not mg then return nil end

	local inv = mg:FindFirstChild("InventoryFrame")
	if inv and inv:IsA("Frame") then
		return inv
	end

	local invMain = mg:FindFirstChild("InventoryMainFrame", true)
	if invMain and invMain:IsA("Frame") then
		return invMain
	end

	return nil
end

---------------------------------------------------------------------
-- GUI ARROW (унификация, чтобы не было "то так то так")
---------------------------------------------------------------------

local function createGuiArrowLabel(name: string, z: number): TextLabel
	local arrowLabel = Instance.new("TextLabel")
	arrowLabel.Name = name
	arrowLabel.BackgroundTransparency = 1
	arrowLabel.BorderSizePixel = 0
	arrowLabel.Text = "↓"
	arrowLabel.Font = Enum.Font.FredokaOne
	arrowLabel.TextScaled = true
	arrowLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
	arrowLabel.TextStrokeTransparency = 0
	arrowLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	arrowLabel.Size = UDim2.new(0, 80, 0, 80)
	arrowLabel.AnchorPoint = Vector2.new(0.5, 1)
	arrowLabel.ZIndex = z
	arrowLabel.Parent = tutorialGui
	return arrowLabel
end

local function followGuiObject(label: TextLabel, target: GuiObject, yOffset: number?, bobSpeed: number?, bobAmp: number?)
	local startTime = tick()
	return RunService.RenderStepped:Connect(function()
		if not label or not label.Parent then return end
		if not target or not target.Parent then return end

		local absPos  = target.AbsolutePosition
		local absSize = target.AbsoluteSize

		local centerX = absPos.X + absSize.X/2
		local topY    = absPos.Y

		local t = tick() - startTime
		local bob = math.sin(t * (bobSpeed or 4)) * (bobAmp or 6)

		label.Position = UDim2.fromOffset(centerX, topY + (yOffset or -10) + bob)
	end)
end

---------------------------------------------------------------------
-- WORLD ARROWS
-- (фикс мерцания: arrowToken, старые корутины больше не трогают стрелку)
---------------------------------------------------------------------

local worldRoot = Workspace:WaitForChild("PixelWorld1")
local arrowPart : BasePart? = nil
local arrowToken = 0

local function destroyArrow()
	arrowToken += 1
	if arrowPart then
		arrowPart:Destroy()
		arrowPart = nil
	end
end

local startQuest9 -- forward declare

-- Последняя стена (4-я)
local function pointArrowToFinalWall(onReachedWall)
	destroyArrow()
	local myToken = arrowToken

	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart")

	local wallFolder : Instance? = worldRoot:FindFirstChild("Location4Wall")
	if not wallFolder then
		for _, obj in ipairs(worldRoot:GetChildren()) do
			if obj.Name:lower():find("location4") and obj.Name:lower():find("wall") then
				wallFolder = obj
				break
			end
		end
	end

	if not wallFolder then
		warn("[Tutorial] Location4Wall folder not found in PixelWorld1")
		return
	end

	local wallPart : BasePart? = wallFolder:FindFirstChild("Location4Wall")
	if not (wallPart and wallPart:IsA("BasePart")) then
		for _, obj in ipairs(wallFolder:GetDescendants()) do
			if obj:IsA("BasePart") then
				wallPart = obj
				break
			end
		end
	end
	if not wallPart then
		warn("[Tutorial] No wall BasePart found inside Location4Wall")
		return
	end

	local targetPos = wallPart.Position

	local arrowTemplate = ReplicatedStorage:WaitForChild("TutorialArrow")
	local arrow = arrowTemplate:Clone()
	arrow.Name = "TutorialArrowRuntime_WallFinal"
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.Parent = Workspace
	arrowPart = arrow

	local sizeNearPlayer = arrow.Size
	local sizeOnWall     = sizeNearPlayer * 1.7

	local reachedWall    = false
	local wallOffsetY    = 7
	local playerOffsetY  = 4
	local reachDistance  = 12
	local startTime      = tick()

	task.spawn(function()
		while arrowPart and arrowPart.Parent and wallPart.Parent and myToken == arrowToken do
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if not hrp then break end

			local hrpPos = hrp.Position
			targetPos    = wallPart.Position

			if not reachedWall then
				if arrowPart.Size ~= sizeNearPlayer then
					arrowPart.Size = sizeNearPlayer
				end

				local flatTarget = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)
				local arrowPos   = hrpPos + Vector3.new(0, playerOffsetY, 0)
				arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * ARROW_ROT_OFFSET

				local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) - Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude
				if flatDist <= reachDistance then
					reachedWall = true
					startTime = tick()
					if onReachedWall then
						task.spawn(onReachedWall)
					end
				end
			else
				if arrowPart.Size ~= sizeOnWall then
					arrowPart.Size = sizeOnWall
				end

				local t = tick() - startTime
				local yOffset = wallOffsetY + math.sin(t * 2) * 0.5
				local pos = targetPos + Vector3.new(0, yOffset, 0)
				arrowPart.CFrame = CFrame.new(pos, targetPos) * ARROW_ROT_OFFSET
			end

			RunService.RenderStepped:Wait()
		end
	end)
end
local function pointArrowToFirstGems_Location3(onReachedGems)
	destroyArrow()
	local myToken = arrowToken

	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart")

	-- ищем 3-ю локацию по маркеру LevelOfFolder == 3
	local thirdLocation : Instance? = nil
	for _, obj in ipairs(worldRoot:GetDescendants()) do
		if obj:IsA("IntValue") and obj.Name == "LevelOfFolder" and obj.Value == 3 then
			thirdLocation = obj.Parent
			break
		end
	end
	if not thirdLocation then
		warn("[Tutorial] LevelOfFolder == 3 not found inside PixelWorld1")
		return
	end

	-- ищем ближайший BasePart внутри GemsModel1
	local targetPos : Vector3? = nil
	local nearestDist = math.huge

	for _, obj in ipairs(thirdLocation:GetDescendants()) do
		if obj:IsA("BasePart") then
			local parent = obj.Parent
			if (parent and parent.Name == "GemsModel1") or obj.Name == "GemsModel1" then
				local dist = (obj.Position - root.Position).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					targetPos  = obj.Position
				end
			end
		end
	end

	if not targetPos then
		warn("[Tutorial] No GemsModel1 BasePart found in location 3")
		return
	end

	local arrowTemplate = ReplicatedStorage:FindFirstChild("TutorialArrow")
	if not arrowTemplate or not arrowTemplate:IsA("BasePart") then
		warn("[Tutorial] TutorialArrow (BasePart) not found in ReplicatedStorage")
		return
	end

	local arrow = arrowTemplate:Clone()
	arrow.Name = "TutorialArrowRuntime_Gems3"
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.Parent = Workspace
	arrowPart = arrow

	local sizeNearPlayer = arrow.Size
	local sizeOnGems     = sizeNearPlayer * 1.7

	local reachedGems   = false
	local gemsOffsetY   = 4
	local playerOffsetY = 4
	local reachDistance = 12
	local startTime     = tick()

	task.spawn(function()
		while arrowPart and arrowPart.Parent and myToken == arrowToken do
			if not character.Parent then break end
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if not hrp then break end

			local hrpPos = hrp.Position

			if not reachedGems then
				if arrowPart.Size ~= sizeNearPlayer then
					arrowPart.Size = sizeNearPlayer
				end

				local flatTarget = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)
				local arrowPos   = hrpPos + Vector3.new(0, playerOffsetY, 0)
				arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * ARROW_ROT_OFFSET

				local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) -
					Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude

				if flatDist <= reachDistance then
					reachedGems = true
					startTime = tick()
					if onReachedGems then
						task.spawn(onReachedGems)
					end
				end
			else
				if arrowPart.Size ~= sizeOnGems then
					arrowPart.Size = sizeOnGems
				end

				local t = tick() - startTime
				local yOffset = gemsOffsetY + math.sin(t * 2) * 0.5
				local pos = targetPos + Vector3.new(0, yOffset, 0)
				arrowPart.CFrame = CFrame.new(pos, targetPos) * ARROW_ROT_OFFSET
			end

			RunService.RenderStepped:Wait()
		end
	end)
end
---------------------------------------------------------------------
-- DEV / DEBUG (simulate tutorial progress even if walls are already bought)
---------------------------------------------------------------------

local DEV_FORCE_TUTORIAL_SIM = true
local DEV_USER_IDS = {
	[player.UserId] = true, -- можно оставить так (только для тебя)
	-- [123456789] = true, -- или впиши конкретный UserId
}

local function isDevTutorialSim(): boolean
	return DEV_FORCE_TUTORIAL_SIM == true and DEV_USER_IDS[player.UserId] == true
end

-- "Стена уже открыта?" — если стены/парта нет, или она не коллидится / прозрачная / отмечена атрибутом
local function isWallUnlocked(folderName: string, partName: string?): boolean
	local folder = worldRoot:FindFirstChild(folderName)
	if not folder then
		-- нет папки стены -> скорее всего уже открыто
		return true
	end

	local wallPart: BasePart? = nil
	if partName and partName ~= "" then
		local p = folder:FindFirstChild(partName)
		if p and p:IsA("BasePart") then wallPart = p end
	end

	if not wallPart then
		for _, obj in ipairs(folder:GetDescendants()) do
			if obj:IsA("BasePart") then
				wallPart = obj
				break
			end
		end
	end

	if not wallPart then
		return true
	end

	-- явные маркеры
	if wallPart:GetAttribute("Unlocked") == true then
		return true
	end

	-- типичные признаки "стена убрана"
	if wallPart.CanCollide == false then
		return true
	end

	-- иногда стену просто делают прозрачной
	if wallPart.Transparency >= 0.95 then
		return true
	end

	return false
end

local function pointArrowToFirstCoin(onReachedCoin)
	destroyArrow()
	local myToken = arrowToken

	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart")

	local firstLocation : Instance? = nil
	for _, obj in ipairs(worldRoot:GetDescendants()) do
		if obj:IsA("IntValue") and obj.Name == "LevelOfFolder" and obj.Value == 1 then
			firstLocation = obj.Parent
			break
		end
	end
	if not firstLocation then
		warn("[Tutorial] LevelOfFolder == 1 not found inside PixelWorld1")
		return
	end

	local targetPos : Vector3? = nil
	local nearestDist = math.huge

	for _, obj in ipairs(firstLocation:GetDescendants()) do
		if obj:IsA("BasePart") then
			local parent = obj.Parent
			if (parent and parent.Name == "CoinsModel1") or obj.Name == "CoinsModel1" then
				local dist = (obj.Position - root.Position).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					targetPos  = obj.Position
				end
			end
		end
	end

	if not targetPos then
		warn("[Tutorial] No CoinsModel1 BasePart found in first location")
		return
	end

	local arrowTemplate = ReplicatedStorage:FindFirstChild("TutorialArrow")
	if not arrowTemplate or not arrowTemplate:IsA("BasePart") then
		warn("[Tutorial] TutorialArrow (BasePart) not found in ReplicatedStorage")
		return
	end

	local arrow = arrowTemplate:Clone()
	arrow.Name = "TutorialArrowRuntime"
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.Parent = Workspace
	arrowPart = arrow

	local sizeNearPlayer = arrow.Size
	local sizeOnCoin     = sizeNearPlayer * 1.7

	local reachedCoin   = false
	local coinOffsetY   = 4
	local playerOffsetY = 4
	local reachDistance = 12
	local startTime     = tick()

	task.spawn(function()
		while arrowPart and arrowPart.Parent and myToken == arrowToken do
			if not character.Parent then break end
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if not hrp then break end

			local hrpPos = hrp.Position

			if not reachedCoin then
				if arrowPart.Size ~= sizeNearPlayer then
					arrowPart.Size = sizeNearPlayer
				end

				local flatTarget = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)
				local arrowPos   = hrpPos + Vector3.new(0, playerOffsetY, 0)
				arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * ARROW_ROT_OFFSET

				local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) -
					Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude
				if flatDist <= reachDistance then
					reachedCoin = true
					startTime = tick()
					if onReachedCoin then
						task.spawn(onReachedCoin)
					end
				end
			else
				if arrowPart.Size ~= sizeOnCoin then
					arrowPart.Size = sizeOnCoin
				end

				local t = tick() - startTime
				local yOffset = coinOffsetY + math.sin(t * 2) * 0.5
				local pos = targetPos + Vector3.new(0, yOffset, 0)
				arrowPart.CFrame = CFrame.new(pos, targetPos) * ARROW_ROT_OFFSET
			end

			RunService.RenderStepped:Wait()
		end
	end)
end

local function pointArrowToGrassBlock(onReachedBlock)
	destroyArrow()
	local myToken = arrowToken

	local character = player.Character or player.CharacterAdded:Wait()

	local blocksFolder = worldRoot:WaitForChild("BlocksLocation1")
	local grassBlock   = blocksFolder:FindFirstChild("GrassBlock")
	if not grassBlock or not grassBlock:IsA("BasePart") then
		warn("[Tutorial] GrassBlock not found in BlocksLocation1")
		return
	end

	local targetPos = grassBlock.Position

	local arrowTemplate = ReplicatedStorage:FindFirstChild("TutorialArrow")
	if not arrowTemplate or not arrowTemplate:IsA("BasePart") then
		warn("[Tutorial] TutorialArrow (BasePart) not found in ReplicatedStorage")
		return
	end

	local arrow = arrowTemplate:Clone()
	arrow.Name = "TutorialArrowRuntime_Block"
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.Parent = Workspace
	arrowPart = arrow

	local sizeNearPlayer = arrow.Size
	local sizeOnBlock    = sizeNearPlayer * 1.7

	local reachedBlock   = false
	local blockOffsetY   = 5
	local playerOffsetY  = 4
	local reachDistance  = 12
	local startTime      = tick()

	task.spawn(function()
		while arrowPart and arrowPart.Parent and grassBlock.Parent and myToken == arrowToken do
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if not hrp then break end

			local hrpPos = hrp.Position
			targetPos    = grassBlock.Position

			if not reachedBlock then
				if arrowPart.Size ~= sizeNearPlayer then
					arrowPart.Size = sizeNearPlayer
				end

				local flatTarget = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)
				local arrowPos   = hrpPos + Vector3.new(0, playerOffsetY, 0)
				arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * ARROW_ROT_OFFSET

				local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) -
					Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude
				if flatDist <= reachDistance then
					reachedBlock = true
					startTime = tick()
					if onReachedBlock then
						task.spawn(onReachedBlock)
					end
				end
			else
				if arrowPart.Size ~= sizeOnBlock then
					arrowPart.Size = sizeOnBlock
				end

				local t = tick() - startTime
				local yOffset = blockOffsetY + math.sin(t * 2) * 0.5
				local pos = targetPos + Vector3.new(0, yOffset, 0)
				arrowPart.CFrame = CFrame.new(pos, targetPos) * ARROW_ROT_OFFSET
			end

			RunService.RenderStepped:Wait()
		end
	end)
end

local function pointArrowToWall(onReachedWall)
	destroyArrow()
	local myToken = arrowToken

	local character = player.Character or player.CharacterAdded:Wait()

	local wallFolder = worldRoot:WaitForChild("Location1Wall")
	if not wallFolder then
		warn("[Tutorial] Location1Wall folder not found in PixelWorld1")
		return
	end

	local wallPart = wallFolder:FindFirstChild("Location1Wall")
	if not (wallPart and wallPart:IsA("BasePart")) then
		for _, obj in ipairs(wallFolder:GetDescendants()) do
			if obj:IsA("BasePart") then
				wallPart = obj
				break
			end
		end
	end
	if not wallPart then
		warn("[Tutorial] No wall BasePart found inside Location1Wall")
		return
	end

	local targetPos = wallPart.Position

	local arrowTemplate = ReplicatedStorage:FindFirstChild("TutorialArrow")
	if not arrowTemplate or not arrowTemplate:IsA("BasePart") then
		warn("[Tutorial] TutorialArrow (BasePart) not found in ReplicatedStorage")
		return
	end

	local arrow = arrowTemplate:Clone()
	arrow.Name = "TutorialArrowRuntime_Wall"
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.Parent = Workspace
	arrowPart = arrow

	local sizeNearPlayer = arrow.Size
	local sizeOnWall     = sizeNearPlayer * 1.7

	local reachedWall    = false
	local wallOffsetY    = 6
	local playerOffsetY  = 4
	local reachDistance  = 12
	local startTime      = tick()

	task.spawn(function()
		while arrowPart and arrowPart.Parent and wallPart.Parent and myToken == arrowToken do
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if not hrp then break end

			local hrpPos = hrp.Position
			targetPos    = wallPart.Position

			if not reachedWall then
				if arrowPart.Size ~= sizeNearPlayer then
					arrowPart.Size = sizeNearPlayer
				end

				local flatTarget = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)
				local arrowPos   = hrpPos + Vector3.new(0, playerOffsetY, 0)

				arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * ARROW_ROT_OFFSET

				local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) -
					Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude
				if flatDist <= reachDistance then
					reachedWall = true
					startTime = tick()
					if onReachedWall then
						task.spawn(onReachedWall)
					end
				end
			else
				if arrowPart.Size ~= sizeOnWall then
					arrowPart.Size = sizeOnWall
				end

				local t = tick() - startTime
				local yOffset = wallOffsetY + math.sin(t * 2) * 0.5
				local pos = targetPos + Vector3.new(0, yOffset, 0)

				arrowPart.CFrame = CFrame.new(pos, targetPos) * ARROW_ROT_OFFSET
			end

			RunService.RenderStepped:Wait()
		end
	end)
end

-- Вторая стена
local function pointArrowToSecondWall(onReachedWall)
	destroyArrow()
	local myToken = arrowToken

	local character = player.Character or player.CharacterAdded:Wait()

	local wallFolder = worldRoot:WaitForChild("Location2Wall")
	if not wallFolder then
		warn("[Tutorial] Location2Wall folder not found in PixelWorld1")
		return
	end

	local wallPart = wallFolder:FindFirstChild("Location2Wall")
	if not (wallPart and wallPart:IsA("BasePart")) then
		for _, obj in ipairs(wallFolder:GetDescendants()) do
			if obj:IsA("BasePart") then
				wallPart = obj
				break
			end
		end
	end
	if not wallPart then
		warn("[Tutorial] No wall BasePart found inside Location2Wall")
		return
	end

	local targetPos = wallPart.Position

	local arrowTemplate = ReplicatedStorage:FindFirstChild("TutorialArrow") or ReplicatedStorage:WaitForChild("TutorialArrow")
	if not arrowTemplate or not arrowTemplate:IsA("BasePart") then
		warn("[Tutorial] TutorialArrow (BasePart) not found in ReplicatedStorage")
		return
	end

	local arrow = arrowTemplate:Clone()
	arrow.Name = "TutorialArrowRuntime_Wall2"
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.Parent = Workspace
	arrowPart = arrow

	local sizeNearPlayer = arrow.Size
	local sizeOnWall     = sizeNearPlayer * 1.7

	local reachedWall    = false
	local wallOffsetY    = 6
	local playerOffsetY  = 4
	local reachDistance  = 12
	local startTime      = tick()

	task.spawn(function()
		while arrowPart and arrowPart.Parent and wallPart.Parent and myToken == arrowToken do
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if not hrp then break end

			local hrpPos = hrp.Position
			targetPos    = wallPart.Position

			if not reachedWall then
				if arrowPart.Size ~= sizeNearPlayer then
					arrowPart.Size = sizeNearPlayer
				end

				local flatTarget = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)
				local arrowPos   = hrpPos + Vector3.new(0, playerOffsetY, 0)

				arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * ARROW_ROT_OFFSET

				local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) -
					Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude
				if flatDist <= reachDistance then
					reachedWall = true
					startTime = tick()
					if onReachedWall then
						task.spawn(onReachedWall)
					end
				end
			else
				if arrowPart.Size ~= sizeOnWall then
					arrowPart.Size = sizeOnWall
				end

				local t = tick() - startTime
				local yOffset = wallOffsetY + math.sin(t * 2) * 0.5
				local pos = targetPos + Vector3.new(0, yOffset, 0)

				arrowPart.CFrame = CFrame.new(pos, targetPos) * ARROW_ROT_OFFSET
			end

			RunService.RenderStepped:Wait()
		end
	end)
end

-- UpgradeMachine
local function pointArrowToUpgradeMachine(onReached)
	destroyArrow()
	local myToken = arrowToken

	local character = player.Character or player.CharacterAdded:Wait()

	local machine = worldRoot:WaitForChild("UpgradeMachine")
	if not machine then
		warn("[Tutorial] UpgradeMachine not found in PixelWorld1")
		return
	end

	local targetPart = machine:FindFirstChild("UpgradeMachineZonePart")
	if not (targetPart and targetPart:IsA("BasePart")) then
		targetPart = machine:FindFirstChild("UpgradePart")
	end
	if not (targetPart and targetPart:IsA("BasePart")) then
		for _, obj in ipairs(machine:GetDescendants()) do
			if obj:IsA("BasePart") then
				targetPart = obj
				break
			end
		end
	end
	if not targetPart then
		warn("[Tutorial] No BasePart found inside UpgradeMachine")
		return
	end

	local targetPos = targetPart.Position

	local arrowTemplate = ReplicatedStorage:FindFirstChild("TutorialArrow")
	if not arrowTemplate or not arrowTemplate:IsA("BasePart") then
		warn("[Tutorial] TutorialArrow (BasePart) not found in ReplicatedStorage")
		return
	end

	local arrow = arrowTemplate:Clone()
	arrow.Name = "TutorialArrowRuntime_UpgradeMachine"
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.Parent = Workspace
	arrowPart = arrow

	local sizeNearPlayer = arrow.Size
	local sizeOnTarget   = sizeNearPlayer * 1.7

	local reached        = false
	local offsetYPlayer  = 4
	local offsetYTarget  = 6
	local reachDistance  = 12
	local startTime      = tick()

	task.spawn(function()
		while arrowPart and arrowPart.Parent and targetPart.Parent and myToken == arrowToken do
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if not hrp then break end

			local hrpPos = hrp.Position
			targetPos    = targetPart.Position

			if not reached then
				if arrowPart.Size ~= sizeNearPlayer then
					arrowPart.Size = sizeNearPlayer
				end

				local flatTarget = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)
				local arrowPos   = hrpPos + Vector3.new(0, offsetYPlayer, 0)

				arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * ARROW_ROT_OFFSET

				local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) -
					Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude
				if flatDist <= reachDistance then
					reached = true
					startTime = tick()
					if onReached then
						task.spawn(onReached)
					end
				end
			else
				if arrowPart.Size ~= sizeOnTarget then
					arrowPart.Size = sizeOnTarget
				end

				local t = tick() - startTime
				local yOffset = offsetYTarget + math.sin(t * 2) * 0.5
				local pos = targetPos + Vector3.new(0, yOffset, 0)

				arrowPart.CFrame = CFrame.new(pos, targetPos) * ARROW_ROT_OFFSET
			end

			RunService.RenderStepped:Wait()
		end
	end)
end
-- ✅ фикс "игрок убежал вперёд": считаем прогресс ОТ СТАРТА интерактивной части туториала
local tutorialStartCoins = 0
local tutorialStartGems  = 0
local function getEarnedCoins(): number
	return math.max(0, (tonumber(world1Currency.Value) or 0) - (tutorialStartCoins or 0))
end

local function getEarnedGems(): number
	return math.max(0, (tonumber(gemsCurrency.Value) or 0) - (tutorialStartGems or 0))
end

-- Универсально показать прогресс квеста в окне
-- ===== QUEST UI (lazy init) =====
local questFrame : Frame? = nil
local progressBar : Frame? = nil
local progressFill : Frame? = nil
local progressText : TextLabel? = nil
local questText : TextLabel? = nil

local function ensureQuestUi(): boolean
	if questFrame and questFrame.Parent then
		return true
	end

	questFrame = tutorialGui:FindFirstChild("Quest1Frame")
	if not (questFrame and questFrame:IsA("Frame")) then
		warn("[Tutorial] Quest1Frame not found")
		return false
	end

	progressBar = questFrame:FindFirstChild("Progressbar")
	if not (progressBar and progressBar:IsA("Frame")) then
		warn("[Tutorial] Progressbar not found")
		return false
	end

	progressFill = progressBar:FindFirstChild("ProgressFill")
	progressText = progressBar:FindFirstChild("ProgressText")
	questText = questFrame:FindFirstChild("QuestText")

	if not (progressFill and progressFill:IsA("Frame")) then
		warn("[Tutorial] ProgressFill not found")
		return false
	end
	if not (progressText and progressText:IsA("TextLabel")) then
		warn("[Tutorial] ProgressText not found")
		return false
	end
	if not (questText and questText:IsA("TextLabel")) then
		warn("[Tutorial] QuestText not found")
		return false
	end

	return true
end

local function showQuest(text: string, current: number, target: number)
	if not ensureQuestUi() then return end

	questFrame.Visible = true
	questText.Text = text

	local cur = math.clamp(math.floor(current or 0), 0, target)
	progressText.Text = string.format("%d/%d", cur, target)

	local ratio = (target > 0) and (cur / target) or 0
	progressFill.Size = UDim2.new(ratio, 0, 1, 0)
end

local function hideQuest()
	if not ensureQuestUi() then return end
	questFrame.Visible = false
end


-- BarnBlock
local function pointArrowToBarnBlock(onReachedBlock)
	destroyArrow()
	local myToken = arrowToken

	local character = player.Character or player.CharacterAdded:Wait()

	local blocks = worldRoot:WaitForChild("BlocksLocation1")
	local barn : BasePart? = blocks:FindFirstChild("BarnBlock")

	if not barn or not barn:IsA("BasePart") then
		for _, obj in ipairs(blocks:GetDescendants()) do
			if obj:IsA("BasePart") and obj.Name == "BarnBlock" then
				barn = obj
				break
			end
		end
	end

	if not barn then
		warn("[Tutorial] BarnBlock not found")
		return
	end

	local targetPos = barn.Position
	local arrowTemplate = ReplicatedStorage:WaitForChild("TutorialArrow")

	local arrow = arrowTemplate:Clone()
	arrow.Name = "TutorialArrowRuntime_Barn"
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.Parent = Workspace
	arrowPart = arrow

	local smallSize = arrow.Size
	local bigSize   = arrow.Size * 1.7
	local reached = false
	local reachDist = 12
	local offsetPlayerY = 4
	local offsetBlockY  = 6
	local startTime = tick()

	task.spawn(function()
		while arrowPart and arrowPart.Parent and barn.Parent and myToken == arrowToken do
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if not hrp then break end

			local hrpPos = hrp.Position
			targetPos = barn.Position

			if not reached then
				if arrowPart.Size ~= smallSize then
					arrowPart.Size = smallSize
				end

				local flatTarget = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)
				local arrowPos   = hrpPos + Vector3.new(0, offsetPlayerY, 0)
				arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * ARROW_ROT_OFFSET

				local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) -
					Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude

				if flatDist <= reachDist then
					reached = true
					startTime = tick()
					if onReachedBlock then
						task.spawn(onReachedBlock)
					end
				end
			else
				if arrowPart.Size ~= bigSize then
					arrowPart.Size = bigSize
				end

				local t = tick() - startTime
				local yoff = offsetBlockY + math.sin(t * 2) * 0.5
				local pos = targetPos + Vector3.new(0, yoff, 0)
				arrowPart.CFrame = CFrame.new(pos, targetPos) * ARROW_ROT_OFFSET
			end

			RunService.RenderStepped:Wait()
		end
	end)
end

-- Третья стена
local function pointArrowToThirdWall(onReachedWall)
	destroyArrow()
	local myToken = arrowToken

	local character = player.Character or player.CharacterAdded:Wait()

	local wallFolder = worldRoot:WaitForChild("Location3Wall")
	if not wallFolder then
		warn("[Tutorial] Location3Wall folder not found in PixelWorld1")
		return
	end

	local wallPart = wallFolder:FindFirstChild("Location3Wall")
	if not (wallPart and wallPart:IsA("BasePart")) then
		for _, obj in ipairs(wallFolder:GetDescendants()) do
			if obj:IsA("BasePart") then
				wallPart = obj
				break
			end
		end
	end
	if not wallPart then
		warn("[Tutorial] No wall BasePart found inside Location3Wall")
		return
	end

	local targetPos = wallPart.Position

	local arrowTemplate = ReplicatedStorage:WaitForChild("TutorialArrow")
	if not arrowTemplate or not arrowTemplate:IsA("BasePart") then
		warn("[Tutorial] TutorialArrow (BasePart) not found in ReplicatedStorage")
		return
	end

	local arrow = arrowTemplate:Clone()
	arrow.Name = "TutorialArrowRuntime_Wall3"
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.Parent = Workspace
	arrowPart = arrow

	local sizeNearPlayer = arrow.Size
	local sizeOnWall     = sizeNearPlayer * 1.7

	local reachedWall    = false
	local wallOffsetY    = 7
	local playerOffsetY  = 4
	local reachDistance  = 12
	local startTime      = tick()

	task.spawn(function()
		while arrowPart and arrowPart.Parent and wallPart.Parent and myToken == arrowToken do
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if not hrp then break end

			local hrpPos = hrp.Position
			targetPos    = wallPart.Position

			if not reachedWall then
				if arrowPart.Size ~= sizeNearPlayer then
					arrowPart.Size = sizeNearPlayer
				end

				local flatTarget = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)
				local arrowPos   = hrpPos + Vector3.new(0, playerOffsetY, 0)

				arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * ARROW_ROT_OFFSET

				local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) -
					Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude
				if flatDist <= reachDistance then
					reachedWall = true
					startTime = tick()
					if onReachedWall then
						task.spawn(onReachedWall)
					end
				end
			else
				if arrowPart.Size ~= sizeOnWall then
					arrowPart.Size = sizeOnWall
				end

				local t = tick() - startTime
				local yOffset = wallOffsetY + math.sin(t * 2) * 0.5
				local pos = targetPos + Vector3.new(0, yOffset, 0)

				arrowPart.CFrame = CFrame.new(pos, targetPos) * ARROW_ROT_OFFSET
			end

			RunService.RenderStepped:Wait()
		end
	end)
end

---------------------------------------------------------------------
-- Hoverboard step helpers
---------------------------------------------------------------------

local function completeHoverboardStep(boardName: string?)
	if hoverboardStepDone then
		return
	end

	hoverboardStepDone   = true
	hoverboardStepActive = false

	destroyArrow()

	local nameText = tostring(boardName or "your hoverboard")
	showNotify(
		string.format(
			"Awesome! You bought %s!\nUse your hoverboard to move much faster.",
			nameText
		),
		7
	)

	task.delay(2, function()
		startQuest9()
	end)
end

-- HoverMesh (стойка ховерборда)
local function pointArrowToHoverMesh(onReached)
	destroyArrow()
	local myToken = arrowToken

	local character = player.Character or player.CharacterAdded:Wait()

	local hoverPart : BasePart? = worldRoot:FindFirstChild("HoverMesh")
	if not (hoverPart and hoverPart:IsA("BasePart")) then
		for _, obj in ipairs(worldRoot:GetDescendants()) do
			if obj:IsA("BasePart") and obj.Name == "HoverMesh" then
				hoverPart = obj
				break
			end
		end
	end

	if not hoverPart then
		warn("[Tutorial] HoverMesh not found under PixelWorld1")
		return
	end

	local targetPos = hoverPart.Position

	local arrowTemplate = ReplicatedStorage:WaitForChild("TutorialArrow")
	if not arrowTemplate or not arrowTemplate:IsA("BasePart") then
		warn("[Tutorial] TutorialArrow (BasePart) not found in ReplicatedStorage")
		return
	end

	local arrow = arrowTemplate:Clone()
	arrow.Name = "TutorialArrowRuntime_Hover"
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.Parent = Workspace
	arrowPart = arrow

	local sizeNearPlayer = arrow.Size
	local sizeOnTarget   = sizeNearPlayer * 1.7

	local reached       = false
	local playerOffsetY = 4
	local targetOffsetY = 6
	local reachDistance = 12
	local startTime     = tick()

	task.spawn(function()
		while arrowPart and arrowPart.Parent and hoverPart.Parent and myToken == arrowToken do
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if not hrp then break end

			local hrpPos = hrp.Position
			targetPos    = hoverPart.Position

			if not reached then
				if arrowPart.Size ~= sizeNearPlayer then
					arrowPart.Size = sizeNearPlayer
				end

				local flatTarget = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)
				local arrowPos   = hrpPos + Vector3.new(0, playerOffsetY, 0)

				arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * ARROW_ROT_OFFSET

				local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) -
					Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude
				if flatDist <= reachDistance then
					reached = true
					startTime = tick()
					if onReached then
						task.spawn(onReached)
					end
				end
			else
				if arrowPart.Size ~= sizeOnTarget then
					arrowPart.Size = sizeOnTarget
				end

				local t = tick() - startTime
				local yOffset = targetOffsetY + math.sin(t * 2) * 0.5
				local pos = targetPos + Vector3.new(0, yOffset, 0)

				arrowPart.CFrame = CFrame.new(pos, targetPos) * ARROW_ROT_OFFSET
			end

			RunService.RenderStepped:Wait()
		end
	end)
end

---------------------------------------------------------------------
-- UPGRADE ARROW (GUI)
---------------------------------------------------------------------

local upgradeArrowGui  : TextLabel? = nil
local upgradeArrowConn : RBXScriptConnection? = nil
local upgradeBtnConn   : RBXScriptConnection? = nil

local upgradeStepActive = false
local upgradeStepDone   = false

local function cleanupUpgradeArrow()
	if upgradeArrowConn then
		upgradeArrowConn:Disconnect()
		upgradeArrowConn = nil
	end
	if upgradeBtnConn then
		upgradeBtnConn:Disconnect()
		upgradeBtnConn = nil
	end
	if upgradeArrowGui then
		upgradeArrowGui:Destroy()
		upgradeArrowGui = nil
	end
end

local startUpgradeButtonStep

---------------------------------------------------------------------
-- QUESTS
---------------------------------------------------------------------
local QUEST1_TARGET       = 150
local QUEST2_TARGET       = 300
local QUEST3_TARGET       = 500
local QUEST4_TARGET       = 1000 -- 2-я стена
local QUEST5_TARGET_GEMS  = 500  -- гемы на апгрейд
local QUEST6_TARGET       = 600  -- 600 монет после апгрейда скорости
local QUEST7_TARGET       = 1200 -- ещё 1200 монет
local QUEST8_TARGET       = 2000 -- фарм на 3-ю стену
local QUEST9_TARGET       = 5000

local quest9BaseCoins = 0

local quest1Active, quest1Finished = false, false
local quest2Active, quest2Finished = false, false
local quest3Active, quest3Finished = false, false
local quest4Active, quest4Finished = false, false
local quest5Active, quest5Finished = false, false
local quest6Active, quest6Finished = false, false
local quest7Active, quest7Finished = false, false
local quest8Active, quest8Finished = false, false
local quest9Active, quest9Finished = false, false

local questListening1       = false
local quest1BaseCoins       = 0
local quest2BaseCoins       = 0
local quest3BaseCoins       = 0
local quest4BaseCoins       = 0
local quest5BaseGems        = 0
local quest6BaseCoins       = 0
local quest7BaseCoins       = 0
local quest8BaseCoins       = 0

local wantFinalWallPurchase = false
local firstCoinAcknowledged = false

local extraBlocksGoal   = 2
local extraBlocksOpened = 0
local wantExtraBlocks   = false

local wantWallPurchase       = false
local wantSecondWallPurchase = false
local wantThirdWallPurchase  = false
local wantUpgradeMachine     = false

local wantBarnPhase1      = false
local wantBarnPhase2      = false
local barnOpenedPhase1    = 0
local barnOpenedPhase2    = 0

local function setQuestProgress(rawValue: number, base: number, target: number)
	if not ensureQuestUi() then return end

	base   = base   or 0
	target = target or 1

	local delta   = math.max(0, math.floor((rawValue or 0) - base))
	local current = math.clamp(delta, 0, target)
	local ratio   = (target > 0) and (current / target) or 0

	progressText.Text = string.format("%d/%d", current, target)
	progressFill.Size = UDim2.new(ratio, 0, 1, 0)
end
local onWorld1Changed
local onGemsChanged

local function startQuest1()
	if quest1Active or quest1Finished then return end
	quest1Active = true

	local earned = getEarnedCoins()
	quest1BaseCoins = earned  -- ✅ стартовая база именно для этого квеста

	showQuest("Farm 150 coins", 0, QUEST1_TARGET)
	onWorld1Changed()
end


local function startQuest2()
	if quest2Active or quest2Finished then return end
	quest2Active = true

	local earned = getEarnedCoins()
	quest2BaseCoins = earned

	showQuest("Farm 300 coins", 0, QUEST2_TARGET)
	showNotify("Great! Now farm 300 coins with your NFT!", 4)

	onWorld1Changed()
end

local function startQuest3()
	if quest3Active or quest3Finished then return end
	quest3Active = true

	local earned = getEarnedCoins()
	quest3BaseCoins = earned

	showQuest("Farm 500 coins", 0, QUEST3_TARGET)
	showNotify("Farm 500 coins to unlock the next area!", 4)

	onWorld1Changed()
end

local function startQuest4()
	if quest4Active or quest4Finished then return end
	quest4Active = true

	local earned = getEarnedCoins()
	quest4BaseCoins = earned

	showQuest("Farm 1000 coins", 0, QUEST4_TARGET)
	showNotify("Use your 2x Coins boost and farm 1000 coins\nto buy the next wall!", 5)

	onWorld1Changed()
end

local function startQuest5Gems()
	if quest5Active or quest5Finished then return end
	quest5Active = true

	showQuest("Farm 500 gems", getEarnedGems(), QUEST5_TARGET_GEMS)
	showNotify("Now farm 500 gems to buy your first upgrade!", 4)

	onGemsChanged()
end

local function startQuest6()
	if quest6Active or quest6Finished then return end
	quest6Active = true

	local earned = getEarnedCoins()
	quest6BaseCoins = earned

	showQuest("Farm 600 coins", 0, QUEST6_TARGET)
	showNotify("Great! Now farm 600 coins and get ready to open the Barn block!", 4)

	onWorld1Changed()
end

local function startQuest7()
	if quest7Active or quest7Finished then return end
	quest7Active = true

	local earned = getEarnedCoins()
	quest7BaseCoins = earned

	showQuest("Farm 1200 coins", 0, QUEST7_TARGET)
	showNotify("Now farm 1200 coins to open the Barn block even more!", 4)

	onWorld1Changed()
end


local function startQuest8()
	if quest8Active or quest8Finished then return end
	quest8Active = true

	local earned = getEarnedCoins()
	quest8BaseCoins = earned

	showQuest("Farm 2000 coins", 0, QUEST8_TARGET)
	showNotify("Great! Now farm 2000 coins to unlock the next area!", 4)

	onWorld1Changed()
end


startQuest9 = function()
	if quest9Active or quest9Finished then return end
	quest9Active = true

	local earned = getEarnedCoins()
	quest9BaseCoins = earned

	showQuest("Farm 5000 coins", 0, QUEST9_TARGET)
	showNotify("Final step! Farm 5000 coins to unlock the last wall and finish the tutorial!", 4)

	onWorld1Changed()
end
-- forward declares (важно для Lua scope!)
local handleWall1Purchased
local handleWall2Purchased
local handleWall3Purchased
local handleFinalWallPurchased


---------------------------------------------------------------------
-- “DUMB MODE”: block pointing steps (always show arrow for opening blocks)
---------------------------------------------------------------------

local function startGoToFinalWallStep()
	wantFinalWallPurchase = true

	if isDevTutorialSim() and isWallUnlocked("Location4Wall", "Location4Wall") then
		showNotify("[DEV] Final wall already unlocked → simulating purchase…", 2)
		task.delay(0.3, handleFinalWallPurchased)
		return
	end

	showNotify("Awesome! You have enough coins.\nFollow the arrow to the last wall!", 0)

	pointArrowToFinalWall(function()
		showNotify("Press E on PC or tap the E button on mobile\nto buy and finish the tutorial!", 0)
	end)
end


local function startGoToGrassBlockStep()
	showNotify("Awesome! You farmed enough coins.\nFollow the arrow to the 150-coin block!", 0)

	pointArrowToGrassBlock(function()
		showNotify("Press E on PC or tap the E button on mobile to open the block.", 0)
	end)
end

-- ✅ NEW: “open 2 more blocks” always points arrow to a block
local function startExtraBlocksOpenStep()
	wantExtraBlocks   = true
	extraBlocksOpened = 0

	-- ✅ квест-окно со счётчиком
	showQuest("Open 2 blocks", extraBlocksOpened, extraBlocksGoal)

	showNotify("Now open 2 more blocks!\nFollow the arrow and press E (or tap) to open.", 0)

	pointArrowToGrassBlock(function()
		showNotify("Press E on PC or tap the E button on mobile to open the block.", 0)
	end)
end

local function startGoToWallStep()
	wantWallPurchase = true

	-- DEV: если стена уже открыта — симулируем покупку и идём дальше
	if isDevTutorialSim() and isWallUnlocked("Location1Wall", "Location1Wall") then
		showNotify("[DEV] Wall 1 already unlocked → simulating purchase…", 2)
		task.delay(0.3, handleWall1Purchased)
		return
	end

	showNotify("Great! You have enough coins.\nFollow the arrow to the white wall!", 0)

	pointArrowToWall(function()
		showNotify("Press E on PC or tap the E button on mobile\nto buy and open the next area!", 0)
	end)
end


local function startGoToSecondWallStep()
	wantSecondWallPurchase = true

	if isDevTutorialSim() and isWallUnlocked("Location2Wall", "Location2Wall") then
		showNotify("[DEV] Wall 2 already unlocked → simulating purchase…", 2)
		task.delay(0.3, handleWall2Purchased)
		return
	end

	showNotify("Great! You have enough coins.\nFollow the arrow to the next white wall!", 0)

	pointArrowToSecondWall(function()
		showNotify("Press E on PC or tap the E button on mobile\nto buy and open the new area!", 0)
	end)
end


local function forceEnableUpgradeGui()
	local ug = playerGui:FindFirstChild("UpgradeGui")
	if ug and ug:IsA("ScreenGui") then
		ug.Enabled = true
	end
end

local function startGoToUpgradeMachineStep()
	wantUpgradeMachine = true

	showNotify("Great! You have enough gems.\nFollow the arrow to the upgrade machine!", 0)
	local mg = getMainGui()
	if mg then
		mg.Enabled = true
	end
	forceEnableUpgradeGui()

	pointArrowToUpgradeMachine(function()
		showNotify("Stand on the glowing area to open the upgrade menu,\nthen buy your first speed upgrade!", 0)

		if startUpgradeButtonStep then
			startUpgradeButtonStep()
		else
			warn("[Tutorial] startUpgradeButtonStep is nil")
		end
	end)
end

local function startBarnPhase1()
	wantBarnPhase1   = true
	barnOpenedPhase1 = 0

	showQuest("Open Barn block (1 time)", barnOpenedPhase1, 1)

	showNotify("Nice! Now open the Barn block once.\nFollow the arrow to the Barn block!", 0)

	pointArrowToBarnBlock(function()
		showNotify("Press E on PC or tap the E button on mobile\nto open the Barn block!", 0)
	end)
end

local function startBarnPhase2()
	wantBarnPhase2   = true
	barnOpenedPhase2 = 0

	showQuest("Open Barn block (2 more times)", barnOpenedPhase2, 2)

	showNotify("Awesome! Now open the Barn block 2 more times!\nFollow the arrow to the Barn block.", 0)

	pointArrowToBarnBlock(function()
		showNotify("Keep opening the Barn block to complete the quest!", 0)
	end)
end

local function startGoToThirdWallStep()
	wantThirdWallPurchase = true

	if isDevTutorialSim() and isWallUnlocked("Location3Wall", "Location3Wall") then
		showNotify("[DEV] Wall 3 already unlocked → simulating purchase…", 2)
		task.delay(0.3, handleWall3Purchased)
		return
	end

	showNotify("Great! Follow the arrow to the next white wall\nand unlock a new area!", 0)

	pointArrowToThirdWall(function()
		showNotify("Press E on PC or tap the E button on mobile\nto buy and open the new area!", 0)
	end)
end


local function startGoToHoverMeshStep()
	hoverboardStepActive = true
	hoverboardStepDone   = false

	showNotify("You received 10,000 Gems!\nFollow the arrow to the hoverboard stand!", 0)

	pointArrowToHoverMesh(function()
		showNotify("Press E on PC or tap the E button on mobile\nto buy your first hoverboard!", 0)
	end)
end

---------------------------------------------------------------------
-- UPGRADE BUTTON STEP (GUI ARROW)
---------------------------------------------------------------------
local function delta(earned: number, base: number): number
	return math.max(0, math.floor((earned or 0) - (base or 0)))
end

startUpgradeButtonStep = function()
	if upgradeStepDone or upgradeStepActive then return end
	upgradeStepActive = true

	local function tryAttachArrow(): boolean
		local upgradeGui = playerGui:FindFirstChild("UpgradeGui")
		if not (upgradeGui and upgradeGui:IsA("ScreenGui") and upgradeGui.Enabled) then
			return false
		end

		local border = upgradeGui:FindFirstChild("UpgradesBorderFrame")
		if not (border and border:IsA("Frame")) then return false end

		local main = border:FindFirstChild("UpgradesMainFrame")
		if not (main and main:IsA("Frame")) then return false end

		local scroll = main:FindFirstChild("ScrollingFrame")
		if not (scroll and scroll:IsA("ScrollingFrame")) then return false end

		local speedRow = scroll:FindFirstChild("UpgradePlayerSpeed")
		if not (speedRow and speedRow:IsA("Frame")) then
			for _, obj in ipairs(scroll:GetChildren()) do
				if obj:IsA("Frame") and obj.Name:find("Speed") then
					speedRow = obj
					break
				end
			end
		end
		if not speedRow then
			warn("[Tutorial] UpgradePlayerSpeed row not found")
			return false
		end

		local innerFrame = speedRow:FindFirstChild("Frame")
		if not (innerFrame and innerFrame:IsA("Frame")) then
			warn("[Tutorial] inner Frame in UpgradePlayerSpeed not found")
			return false
		end

		local folder = innerFrame:FindFirstChild("Folder")
		if not (folder and folder:IsA("Folder")) then
			warn("[Tutorial] Folder in UpgradePlayerSpeed not found")
			return false
		end

		local upgradeBtn : GuiButton? = folder:FindFirstChild("UpgradeBtn")
		if not (upgradeBtn and upgradeBtn:IsA("GuiButton")) then
			for _, obj in ipairs(upgradeGui:GetDescendants()) do
				if obj:IsA("GuiButton") and obj.Name == "UpgradeBtn" then
					upgradeBtn = obj
					break
				end
			end
		end

		if not upgradeBtn then
			warn("[Tutorial] UpgradeBtn (speed) not found")
			return false
		end

		upgradeArrowGui = createGuiArrowLabel("UpgradeArrowHint", 120)
		showNotify("Tap this button to buy your first speed upgrade!", 0)

		upgradeArrowConn = followGuiObject(upgradeArrowGui, upgradeBtn, -10, 4, 6)

		if upgradeBtnConn then
			upgradeBtnConn:Disconnect()
		end

		upgradeBtnConn = upgradeBtn.MouseButton1Click:Connect(function()
			if not upgradeStepActive then return end

			upgradeStepActive = false
			upgradeStepDone   = true
			cleanupUpgradeArrow()

			showNotify("Nice! You bought your first speed upgrade.\nNow you can move faster!", 5)

			task.delay(1, function()
				startQuest6()
			end)
		end)

		return true
	end

	if tryAttachArrow() then
		return
	end

	task.spawn(function()
		while upgradeStepActive and not upgradeStepDone do
			if tryAttachArrow() then
				break
			end
			RunService.RenderStepped:Wait()
		end
	end)
end

---------------------------------------------------------------------
-- COINS / GEMS CHANGE HANDLERS
---------------------------------------------------------------------

onWorld1Changed = function()
	local earned = getEarnedCoins()

	-- Твой "пинок" после первого прироста монет (оставляю как есть по смыслу)
	if questListening1 and not quest1Finished then
		if (not firstCoinAcknowledged) and earned > 0 then
			firstCoinAcknowledged = true
			destroyArrow()
			showNotify("Nice! Keep farming coins like that!", 0)

			task.delay(5, function()
				if quest1Finished then return end
				startQuest1()
				notifyLabel.Visible = false
			end)
		end
	end

	-- Q1
	if quest1Active and not quest1Finished then
		local cur = delta(earned, quest1BaseCoins)
		showQuest("Farm 150 coins", cur, QUEST1_TARGET)

		if cur >= QUEST1_TARGET then
			quest1Active = false
			quest1Finished = true
			hideQuest()
			startGoToGrassBlockStep()
			return
		end
	end

	-- Q2
	if quest2Active and not quest2Finished then
		local cur = delta(earned, quest2BaseCoins)
		showQuest("Farm 300 coins", cur, QUEST2_TARGET)

		if cur >= QUEST2_TARGET then
			quest2Active = false
			quest2Finished = true
			hideQuest()
			startExtraBlocksOpenStep()
			return
		end
	end

	-- Q3
	if quest3Active and not quest3Finished then
		local cur = delta(earned, quest3BaseCoins)
		showQuest("Farm 500 coins", cur, QUEST3_TARGET)

		if cur >= QUEST3_TARGET then
			quest3Active = false
			quest3Finished = true
			hideQuest()
			startGoToWallStep()
			return
		end
	end

	-- Q4
	if quest4Active and not quest4Finished then
		local cur = delta(earned, quest4BaseCoins)
		showQuest("Farm 1000 coins", cur, QUEST4_TARGET)

		if cur >= QUEST4_TARGET then
			quest4Active = false
			quest4Finished = true
			hideQuest()
			startGoToSecondWallStep()
			return
		end
	end

	-- Q6
	if quest6Active and not quest6Finished then
		local cur = delta(earned, quest6BaseCoins)
		showQuest("Farm 600 coins", cur, QUEST6_TARGET)

		if cur >= QUEST6_TARGET then
			quest6Active = false
			quest6Finished = true
			hideQuest()
			startBarnPhase1()
			return
		end
	end

	-- Q7
	if quest7Active and not quest7Finished then
		local cur = delta(earned, quest7BaseCoins)
		showQuest("Farm 1200 coins", cur, QUEST7_TARGET)

		if cur >= QUEST7_TARGET then
			quest7Active = false
			quest7Finished = true
			hideQuest()
			startBarnPhase2()
			return
		end
	end

	-- Q8
	if quest8Active and not quest8Finished then
		local cur = delta(earned, quest8BaseCoins)
		showQuest("Farm 2000 coins", cur, QUEST8_TARGET)

		if cur >= QUEST8_TARGET then
			quest8Active = false
			quest8Finished = true
			hideQuest()
			startGoToThirdWallStep()
			return
		end
	end

	-- Q9
	if quest9Active and not quest9Finished then
		local cur = delta(earned, quest9BaseCoins)
		showQuest("Farm 5000 coins", cur, QUEST9_TARGET)

		if cur >= QUEST9_TARGET then
			quest9Active = false
			quest9Finished = true
			hideQuest()
			startGoToFinalWallStep()
			return
		end
	end
end


onGemsChanged = function()
	local earned = getEarnedGems()

	if quest5Active and not quest5Finished then
		showQuest("Farm 500 gems", earned, QUEST5_TARGET_GEMS)
		if earned >= QUEST5_TARGET_GEMS then
			quest5Active = false
			quest5Finished = true
			hideQuest()
			startGoToUpgradeMachineStep()
			return
		end
	end
end


ensureQuestUi()
if questFrame then
	questFrame.Visible = false
end

quest1BaseCoins = tonumber(world1Currency.Value) or 0
setQuestProgress(quest1BaseCoins, quest1BaseCoins, QUEST1_TARGET)

world1Currency:GetPropertyChangedSignal("Value"):Connect(onWorld1Changed)
gemsCurrency:GetPropertyChangedSignal("Value"):Connect(onGemsChanged)

---------------------------------------------------------------------
-- INVENTORY + NFT CLICK (first time teaching + utilities for dumb mode)
---------------------------------------------------------------------



local inventoryStepActive = false
local inventoryStepDone   = false
local inventoryArrowGui : TextLabel? = nil
local inventoryArrowConn : RBXScriptConnection? = nil
local inventoryBtnConn   : RBXScriptConnection? = nil

local nftClickStepActive = false
local nftClickStepDone   = false
local nftArrowGui  : TextLabel? = nil
local nftArrowConn : RBXScriptConnection? = nil
local nftSlotConn  : RBXScriptConnection? = nil

local firstNftUuid : string? = nil

local function cleanupInventoryArrow()
	if inventoryArrowConn then
		inventoryArrowConn:Disconnect()
		inventoryArrowConn = nil
	end
	if inventoryBtnConn then
		inventoryBtnConn:Disconnect()
		inventoryBtnConn = nil
	end
	if inventoryArrowGui then
		inventoryArrowGui:Destroy()
		inventoryArrowGui = nil
	end
end

local function cleanupNftArrow()
	if nftArrowConn then
		nftArrowConn:Disconnect()
		nftArrowConn = nil
	end
	if nftSlotConn then
		nftSlotConn:Disconnect()
		nftSlotConn = nil
	end
	if nftArrowGui then
		nftArrowGui:Destroy()
		nftArrowGui = nil
	end
end

local function findNftSlotForTutorial(uuid: string?): GuiObject?
	local mg = getMainGui()
	if not mg then return nil end

	local invFrame = mg:FindFirstChild("InventoryFrame")
	if not invFrame or not invFrame:IsA("Frame") then return nil end

	local invMain = invFrame:FindFirstChild("InventoryMainFrame")
	if not invMain or not invMain:IsA("Frame") then
		invMain = invFrame:FindFirstChild("InventoryMainFrame", true)
	end
	if not invMain or not invMain:IsA("Frame") then return nil end

	local scrollNfts = invMain:FindFirstChild("ScrollingFrameNfts")
	if not scrollNfts or not scrollNfts:IsA("ScrollingFrame") then return nil end

	local grid : Frame? = nil
	local notEq = scrollNfts:FindFirstChild("NotEquippedFrameSlots")
	if notEq and notEq:IsA("Frame") then
		local g = notEq:FindFirstChild("Grid")
		if g and g:IsA("Frame") then
			grid = g
		else
			grid = notEq
		end
	end

	if not grid then
		for _, obj in ipairs(scrollNfts:GetDescendants()) do
			if obj:IsA("Frame")
				and obj.Name == "Grid"
				and obj:FindFirstChildWhichIsA("UIGridLayout")
			then
				grid = obj
				break
			end
		end
	end

	if not grid then
		warn("[Tutorial] Inventory Grid not found under ScrollingFrameNfts")
		return nil
	end

	local function slotMatchesUuid(slot: GuiObject, wantUuid: string): boolean
		if slot.Name == wantUuid then
			return true
		end

		local v1 = slot:FindFirstChild("Uuid")
		if v1 and v1:IsA("StringValue") and v1.Value == wantUuid then
			return true
		end

		local v2 = slot:FindFirstChild("UUID")
		if v2 and v2:IsA("StringValue") and v2.Value == wantUuid then
			return true
		end

		local attr1 = slot:GetAttribute("Uuid")
		if typeof(attr1) == "string" and attr1 == wantUuid then
			return true
		end

		local attr2 = slot:GetAttribute("UUID")
		if typeof(attr2) == "string" and attr2 == wantUuid then
			return true
		end

		local attr3 = slot:GetAttribute("uuid")
		if typeof(attr3) == "string" and attr3 == wantUuid then
			return true
		end

		for _, obj in ipairs(slot:GetDescendants()) do
			if obj:IsA("ObjectValue") and obj.Value and obj.Value:IsA("Instance") then
				local inst = obj.Value
				if inst.Parent == inventoryFolder and inst.Name == wantUuid then
					return true
				end
			end
		end

		return false
	end

	if uuid and uuid ~= "" then
		for _, child in ipairs(grid:GetChildren()) do
			if child:IsA("GuiObject") and child:GetAttribute("IsNftCard") == true then
				if slotMatchesUuid(child, uuid) then
					warn("[Tutorial] Matched NFT slot by uuid:", uuid, "→", child:GetFullName())
					return child
				end
			end
		end
		warn("[Tutorial] NFT slot for uuid not found, uuid =", uuid, " — fallback to first card")
	end

	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("GuiObject") and child:GetAttribute("IsNftCard") == true then
			return child
		end
	end

	return nil
end

local function completeNftClickStep()
	if nftClickStepDone then return end
	nftClickStepDone   = true
	nftClickStepActive = false
	cleanupNftArrow()

	showNotify("Great! Your NFT is equipped.\nNow close the inventory.", 0)

	local mg = getMainGui()
	if not mg then
		startQuest2()
		return
	end

	local invFrame = mg:FindFirstChild("InventoryFrame")
	if not invFrame or not invFrame:IsA("Frame") then
		startQuest2()
		return
	end

	if not invFrame.Visible then
		startQuest2()
		return
	end

	local conn
	conn = invFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not invFrame.Visible then
			conn:Disconnect()
			startQuest2()
		end
	end)
end

local function startNftClickStep()
	if nftClickStepDone or nftClickStepActive then return end

	local mg = getMainGui()
	if not mg then
		completeNftClickStep()
		return
	end

	local invFrame = mg:FindFirstChild("InventoryFrame")
	if not invFrame or not invFrame:IsA("Frame") then
		completeNftClickStep()
		return
	end

	if not invFrame.Visible then
		local conn
		conn = invFrame:GetPropertyChangedSignal("Visible"):Connect(function()
			if invFrame.Visible then
				conn:Disconnect()
				startNftClickStep()
			end
		end)
		return
	end

	local slot
	for _ = 1, 30 do
		slot = findNftSlotForTutorial(firstNftUuid)
		if slot then break end
		task.wait(0.1)
	end

	if not slot then
		warn("[Tutorial] NFT slot not found even after waiting, skipping click step")
		completeNftClickStep()
		return
	end

	local clickArea = slot:FindFirstChild("ClickArea")
	if not (clickArea and clickArea:IsA("GuiButton")) then
		clickArea = slot
	end

	nftClickStepActive = true
	showNotify("Tap this NFT to equip it!", 0)

	cleanupNftArrow()
	nftArrowGui = createGuiArrowLabel("NftArrowHint", 60)
	nftArrowConn = followGuiObject(nftArrowGui, clickArea, -10, 4, 6)

	nftSlotConn = clickArea.MouseButton1Click:Connect(function()
		if nftClickStepActive then
			completeNftClickStep()
		end
	end)
end

local function completeInventoryStep()
	if inventoryStepDone then return end
	inventoryStepDone   = true
	inventoryStepActive = false

	cleanupInventoryArrow()

	showNotify("Inventory is open.\nNow click on your new NFT!", 0)

	task.delay(0.5, function()
		startNftClickStep()
	end)
end

local function showInventoryHint()
	if inventoryStepDone then return end

	local mg = getMainGui()
	if not mg then
		completeInventoryStep()
		return
	end

	local buttons = mg:FindFirstChild("Buttons")
	if not buttons then
		completeInventoryStep()
		return
	end

	local inventoryBtn = buttons:FindFirstChild("InventoryBtn")
	if not (inventoryBtn and inventoryBtn:IsA("GuiButton")) then
		completeInventoryStep()
		return
	end

	inventoryStepActive = true
	showNotify("Open your Inventory to see your NFT!", 0)

	cleanupInventoryArrow()
	inventoryArrowGui = createGuiArrowLabel("InventoryArrowHint", 50)
	inventoryArrowConn = followGuiObject(inventoryArrowGui, inventoryBtn, -10, 4, 6)

	inventoryBtnConn = inventoryBtn.MouseButton1Click:Connect(function()
		if inventoryStepActive then
			completeInventoryStep()
		end
	end)
end
---------------------------------------------------------------------
-- EQUIP BEST tutorial step (после 2 грязевых блоков)
---------------------------------------------------------------------

local equipBestStepActive = false
local equipBestStepDone   = false

local equipBestArrowGui  : TextLabel? = nil
local equipBestArrowConn : RBXScriptConnection? = nil
local equipBestBtnConn   : RBXScriptConnection? = nil

local function cleanupEquipBestArrow()
	if equipBestArrowConn then
		equipBestArrowConn:Disconnect()
		equipBestArrowConn = nil
	end
	if equipBestBtnConn then
		equipBestBtnConn:Disconnect()
		equipBestBtnConn = nil
	end
	if equipBestArrowGui then
		equipBestArrowGui:Destroy()
		equipBestArrowGui = nil
	end
end

-- MainGui -> InventoryFrame -> EquipBestBtnFrame -> (TextButton/ImageButton)
local function findEquipBestButton(): GuiButton?
	local mg = getMainGui()
	if not mg then return nil end

	local invFrame = mg:FindFirstChild("InventoryFrame", true)
	if not (invFrame and invFrame:IsA("Frame")) then return nil end

	local container = invFrame:FindFirstChild("EquipBestBtnFrame", true)
	if not container then return nil end

	for _, ch in ipairs(container:GetChildren()) do
		if ch:IsA("GuiButton") then
			return ch
		end
	end

	local btn = container:FindFirstChildWhichIsA("GuiButton", true)
	return btn
end
-- Функция для проверки, открыт ли инвентарь
local function isInventoryOpen()
	local invFrame = findOpenInventoryMain()
	return invFrame ~= nil
end

-- Функция для отображения подсказки по инвентарю и кнопке Equip Best
local function startEquipBestStep(onDone)
	if equipBestStepDone then
		if onDone then onDone() end
		return
	end
	equipBestStepActive = true

	local localInvArrowGui : TextLabel?
	local localInvArrowConn : RBXScriptConnection?
	local localInvBtnConn : RBXScriptConnection?

	local function cleanupLocalInventoryArrow()
		if localInvArrowConn then
			localInvArrowConn:Disconnect()
			localInvArrowConn = nil
		end
		if localInvBtnConn then
			localInvBtnConn:Disconnect()
			localInvBtnConn = nil
		end
		if localInvArrowGui then
			localInvArrowGui:Destroy()
			localInvArrowGui = nil
		end
	end

	-- Helper to start Equip Best button arrow
	local function attachEquipBestButton()
		local btn = findEquipBestButton()
		if not btn then
			warn("[Tutorial] EquipBest button not found, skipping step")
			equipBestStepActive = false
			equipBestStepDone = true
			cleanupEquipBestArrow()
			cleanupLocalInventoryArrow()
			if onDone then onDone() end
			return
		end
		showNotify("Press EQUIP BEST to instantly equip the strongest NFTs!", 0)
		cleanupEquipBestArrow()
		equipBestArrowGui = createGuiArrowLabel("EquipBestArrowHint", 95)
		equipBestArrowConn = followGuiObject(equipBestArrowGui, btn, -10, 4, 6)
		if equipBestBtnConn then equipBestBtnConn:Disconnect() end
		equipBestBtnConn = btn.MouseButton1Click:Connect(function()
			if not equipBestStepActive then return end
			equipBestStepActive = false
			equipBestStepDone = true
			cleanupEquipBestArrow()
			cleanupLocalInventoryArrow()
			showNotify("Nice! Now your strongest NFTs are equipped.", 4)
			task.delay(0.8, function()
				if onDone then onDone() end
			end)
		end)
	end

	-- Check if inventory is already open
	if isInventoryOpen() then
		attachEquipBestButton()
		return
	end

	-- Inventory is CLOSED → show independent hint to open it
	local mg = getMainGui()
	if not mg then
		equipBestStepActive = false
		equipBestStepDone = true
		if onDone then onDone() end
		return
	end

	local buttons = mg:FindFirstChild("Buttons")
	local inventoryBtn = buttons and buttons:FindFirstChild("InventoryBtn")
	if not (inventoryBtn and inventoryBtn:IsA("GuiButton")) then
		equipBestStepActive = false
		equipBestStepDone = true
		if onDone then onDone() end
		return
	end

	showNotify("Tip: Open Inventory first to equip your strongest NFTs.", 0)
	localInvArrowGui = createGuiArrowLabel("EquipBest_InvArrow", 90)
	localInvArrowConn = followGuiObject(localInvArrowGui, inventoryBtn, -10, 4, 6)

	localInvBtnConn = inventoryBtn.MouseButton1Click:Connect(function()
		cleanupLocalInventoryArrow()
		-- Now wait briefly for inventory to fully appear
		task.delay(0.2, function()
			if equipBestStepActive then
				attachEquipBestButton()
			end
		end)
	end)

	-- Optional: auto-cleanup if step gets interrupted
end


---------------------------------------------------------------------
-- DUMB MODE: Equip reminder after ANY hatched NFT (Inventory -> click NFT)
---------------------------------------------------------------------

local equipReminderActive = false
local equipReminderCooldownUntil = 0

local function showEquipReminderForUuid(uuid: string?)
	-- анти-спам
	if tick() < equipReminderCooldownUntil then return end
	equipReminderCooldownUntil = tick() + 6

	if equipReminderActive then return end
	equipReminderActive = true

	-- не ломаем “первое обучение”
	if nftClickStepActive or inventoryStepActive then
		equipReminderActive = false
		return
	end

	-- чистим старые стрелки
	cleanupInventoryArrow()
	cleanupNftArrow()

	-- 1) стрелка на Inventory
	local mg = getMainGui()
	if not mg then
		equipReminderActive = false
		return
	end

	local buttons = mg:FindFirstChild("Buttons")
	local inventoryBtn = buttons and buttons:FindFirstChild("InventoryBtn")
	if not (inventoryBtn and inventoryBtn:IsA("GuiButton")) then
		equipReminderActive = false
		return
	end

	showNotify("New NFT!\nOpen Inventory and EQUIP it (tap the NFT).", 0)

	inventoryArrowGui = createGuiArrowLabel("EquipInventoryArrowHint", 70)
	inventoryArrowConn = followGuiObject(inventoryArrowGui, inventoryBtn, -10, 4, 6)

	if inventoryBtnConn then inventoryBtnConn:Disconnect() end
	inventoryBtnConn = inventoryBtn.MouseButton1Click:Connect(function()
		cleanupInventoryArrow()

		task.delay(0.2, function()
			firstNftUuid = uuid

			local slot
			for _ = 1, 30 do
				slot = findNftSlotForTutorial(firstNftUuid)
				if slot then break end
				task.wait(0.1)
			end

			if not slot then
				showNotify("Open Inventory and equip the new NFT (choose a stronger one).", 4)
				equipReminderActive = false
				return
			end

			local clickArea = slot:FindFirstChild("ClickArea")
			if not (clickArea and clickArea:IsA("GuiButton")) then
				clickArea = slot
			end

			showNotify("Tap the new NFT to EQUIP it!", 0)

			nftArrowGui = createGuiArrowLabel("EquipNftArrowHint", 70)
			nftArrowConn = followGuiObject(nftArrowGui, clickArea, -10, 4, 6)

			if nftSlotConn then nftSlotConn:Disconnect() end
			nftSlotConn = clickArea.MouseButton1Click:Connect(function()
				cleanupNftArrow()
				showNotify("Nice! If it's stronger — keep it equipped.\nClose Inventory and continue!", 3)
				equipReminderActive = false
			end)

			-- если закрыл инвентарь — выходим
			local invFrame = mg:FindFirstChild("InventoryFrame")
			if invFrame and invFrame:IsA("Frame") then
				local conn
				conn = invFrame:GetPropertyChangedSignal("Visible"):Connect(function()
					if not invFrame.Visible then
						if conn then conn:Disconnect() end
						cleanupNftArrow()
						equipReminderActive = false
					end
				end)
			end
		end)
	end)
end

---------------------------------------------------------------------
-- PetHatchedEvent
---------------------------------------------------------------------

local function extractUuidFromPayload(payload): string?
	if typeof(payload) == "string" then
		return payload
	end

	if typeof(payload) == "Instance" then
		return payload.Name
	end

	if typeof(payload) == "table" then
		if typeof(payload.uuid) == "string" then
			return payload.uuid
		end
		if typeof(payload.id) == "string" then
			return payload.id
		end
		if typeof(payload.Uuid) == "string" then
			return payload.Uuid
		end
		if typeof(payload[1]) == "string" then
			return payload[1]
		end
		if typeof(payload[1]) == "Instance" then
			return payload[1].Name
		end
	end

	return nil
end

local function waitForNewHatchedUuid(timeout)
	local start = tick()
	local first = lastHatchedUuid
	repeat
		if lastHatchedUuid and lastHatchedUuid ~= first then
			return lastHatchedUuid
		end
		RunService.Heartbeat:Wait()
	until tick() - start > (timeout or 3)
	return lastHatchedUuid
end

PetHatchedEvent.OnClientEvent:Connect(function(payload)
	-- туториал ещё не начался
	if not quest1Finished then
		return
	end

	-----------------------------------------------------------------
	-- UUID
	-----------------------------------------------------------------
	local hatchedUuid = extractUuidFromPayload(payload)
	if not hatchedUuid or hatchedUuid == "" then
		hatchedUuid = waitForNewHatchedUuid(3)
	end

	if hatchedUuid and hatchedUuid ~= "" then
		lastHatchedUuid = hatchedUuid
	else
		warn("[Tutorial] PetHatchedEvent: cannot detect uuid")
	end

	-----------------------------------------------------------------
	-- 1) ПЕРВОЕ ЯЙЦО — Inventory -> клик по NFT
	-----------------------------------------------------------------
	if not quest2Active
		and not quest2Finished
		and not wantExtraBlocks
		and not quest3Active
		and not quest3Finished
		and not inventoryStepDone
		and not nftClickStepDone
	then
		destroyArrow()

		firstNftUuid = lastHatchedUuid
		warn("[Tutorial] First hatch, firstNftUuid =", firstNftUuid)

		showNotify("Nice! You opened the block and got your first NFT!", 0)

		task.delay(1.5, function()
			if not inventoryStepDone and not nftClickStepDone then
				showInventoryHint()
			end
		end)

		return
	end

	-----------------------------------------------------------------
	-- 2) КВЕСТ: «ОТКРОЙ 2 БЛОКА»
	-----------------------------------------------------------------
	if wantExtraBlocks then
		extraBlocksOpened += 1

		-- ✅ обновляем окно квеста
		showQuest("Open 2 blocks", extraBlocksOpened, extraBlocksGoal)

		if extraBlocksOpened < extraBlocksGoal then
			showNotify(
				string.format("Nice! %d/%d blocks opened.\nOpen %d more blocks!",
					extraBlocksOpened, extraBlocksGoal, extraBlocksGoal - extraBlocksOpened
				),
				0
			)

			pointArrowToGrassBlock(function()
				showNotify("Press E on PC or tap the E button on mobile to open the block.", 0)
			end)

			return
		end

		-- ✅ выполнено
		wantExtraBlocks = false
		destroyArrow()
		hideQuest()

		showNotify("Awesome! You opened 2 more blocks!\nNow let's auto-equip the best NFTs!", 0)

		equipReminderCooldownUntil = tick() + 8
		equipReminderActive = false

		task.delay(0.8, function()
			startEquipBestStep(function()
				showNotify("Great! Now farm 500 coins!", 2)
				task.delay(2, function()
					startQuest3()
				end)
			end)
		end)

		return
	end


	-----------------------------------------------------------------
	-- 3) BARN PHASE 1 (1 раз)
	-----------------------------------------------------------------
	if wantBarnPhase1 then
		barnOpenedPhase1 += 1
		showQuest("Open Barn block (1 time)", barnOpenedPhase1, 1)

		wantBarnPhase1 = false
		destroyArrow()
		hideQuest()

		showNotify("Great! You opened the Barn block.\nNow farm 1200 coins!", 0)
		startQuest7()
		return
	end

	-----------------------------------------------------------------
	-- 4) BARN PHASE 2 (2 раза)
	-----------------------------------------------------------------
	if wantBarnPhase2 then
		barnOpenedPhase2 += 1
		showQuest("Open Barn block (2 more times)", barnOpenedPhase2, 2)

		if barnOpenedPhase2 < 2 then
			showNotify(
				string.format("Nice! %d/2 Barn blocks opened.\nOpen %d more!",
					barnOpenedPhase2, 2 - barnOpenedPhase2
				),
				0
			)

			pointArrowToBarnBlock(function()
				showNotify("Press E on PC or tap the E button on mobile\nto open the Barn block!", 0)
			end)
		else
			wantBarnPhase2 = false
			destroyArrow()
			hideQuest()

			showNotify("Awesome! You opened the Barn block 3 times!\nNow farm 2000 coins to unlock a new area!", 0)
			startQuest8()
		end

		return
	end


	-----------------------------------------------------------------
	-- 5) DUMB MODE: напоминание экипировать NFT
	-----------------------------------------------------------------
	if hatchedUuid and hatchedUuid ~= "" then
		if not wantExtraBlocks
			and not wantBarnPhase1
			and not wantBarnPhase2
			and not equipBestStepActive
			and not inventoryStepActive
			and not nftClickStepActive
		then
			showEquipReminderForUuid(hatchedUuid)
		end
	end
end)

---------------------------------------------------------------------
-- BOOST TUTORIAL (3 шага: Inventory -> Boosts tab -> Boost button)
---------------------------------------------------------------------

local boostTutorialActive = false
local boostArrowGui  : TextLabel? = nil
local boostArrowConn : RBXScriptConnection? = nil
local boostBtnConn   : RBXScriptConnection? = nil

local function cleanupBoostArrow()
	if boostArrowConn then
		boostArrowConn:Disconnect()
		boostArrowConn = nil
	end
	if boostBtnConn then
		boostBtnConn:Disconnect()
		boostBtnConn = nil
	end
	if boostArrowGui then
		boostArrowGui:Destroy()
		boostArrowGui = nil
	end
end

local function waitForCoinsBoostActivated(timeout: number?): boolean
	timeout = timeout or 25
	local t0 = tick()

	while tick() - t0 < timeout do
		local val = activeBoostsFolder:FindFirstChild("2xCoinsBoost")
		if val and val:IsA("IntValue") and val.Value > 0 then
			return true
		end
		RunService.Heartbeat:Wait()
	end

	return false
end

HoverboardPurchasedEvent.OnClientEvent:Connect(function(boardName)
	warn("[Tutorial] HoverboardPurchasedEvent, board =", boardName)

	if not hoverboardStepActive then
		return
	end

	completeHoverboardStep(boardName)
end)

local function findBoostsTabButton(): GuiButton?
	local mg = getMainGui()
	if not mg then return nil end

	local invFrame = mg:FindFirstChild("InventoryFrame")
	if not (invFrame and invFrame:IsA("Frame")) then return nil end

	local selectGroup = invFrame:FindFirstChild("SelectGroup", true)
	if not selectGroup then return nil end

	local btn = selectGroup:FindFirstChild("SelectBoostsInventory", true)
	if btn and btn:IsA("GuiButton") then
		return btn
	end

	if btn and (btn:IsA("ImageButton") or btn:IsA("TextButton")) then
		return btn :: any
	end

	return nil
end

local showBoostSelectTabStep -- forward

local function showBoostActivateButtonStep()
	if not boostTutorialActive then return end

	local invContainer = findInventoryContainer()
	if not invContainer then
		warn("[BoostTutorial] Inventory container not found")
		return
	end

	local invMain = invContainer:FindFirstChild("InventoryMainFrame", true)
	if not (invMain and invMain:IsA("Frame")) then
		warn("[BoostTutorial] InventoryMainFrame not found")
		return
	end

	local boostsScroll = invMain:FindFirstChild("ScrollingFrameBoosts", true)
	if not (boostsScroll and boostsScroll:IsA("ScrollingFrame")) then
		warn("[BoostTutorial] ScrollingFrameBoosts not found")
		return
	end

	local boostBtn : GuiButton? = boostsScroll:FindFirstChild("2xCoinsBtn", true)
	if not (boostBtn and boostBtn:IsA("GuiButton")) then
		warn("[BoostTutorial] 2xCoinsBtn not found")
		return
	end

	showNotify("Tap the 2x Coins boost to activate it!", 0)

	cleanupBoostArrow()
	boostArrowGui = createGuiArrowLabel("BoostActivateArrowHint", 90)
	boostArrowConn = followGuiObject(boostArrowGui, boostBtn, -10, 4, 6)

	if boostBtnConn then boostBtnConn:Disconnect() end
	boostBtnConn = boostBtn.MouseButton1Click:Connect(function()
		if not boostTutorialActive then return end

		task.spawn(function()
			local ok = waitForCoinsBoostActivated(25)
			cleanupBoostArrow()
			boostTutorialActive = false

			if ok then
				local secsLeft = 0
				local val = activeBoostsFolder:FindFirstChild("2xCoinsBoost")
				if val and val:IsA("IntValue") then
					secsLeft = tonumber(val.Value) or 0
				end
				local minutes = math.max(1, math.floor((secsLeft / 60) + 0.5))

				showNotify(
					string.format("Nice! 2x Coins is now active for about %d minutes.\nGood luck farming!", minutes),
					5
				)

				task.delay(5, function()
					startQuest4()
				end)
			else
				showNotify("Boost wasn't activated. You can try again later.", 4)
			end
		end)
	end)
end

showBoostSelectTabStep = function()
	if not boostTutorialActive then return end

	local tabBtn = findBoostsTabButton()
	if not tabBtn then
		task.spawn(function()
			for _ = 1, 60 do
				if not boostTutorialActive then return end
				tabBtn = findBoostsTabButton()
				if tabBtn then
					showBoostSelectTabStep()
					return
				end
				RunService.Heartbeat:Wait()
			end
		end)
		return
	end

	showNotify("In Inventory, open the Boosts tab.", 0)

	cleanupBoostArrow()
	boostArrowGui = createGuiArrowLabel("BoostsTabArrowHint", 80)
	boostArrowConn = followGuiObject(boostArrowGui, tabBtn, -10, 4, 6)

	if boostBtnConn then boostBtnConn:Disconnect() end
	boostBtnConn = tabBtn.MouseButton1Click:Connect(function()
		if not boostTutorialActive then return end
		cleanupBoostArrow()

		task.delay(0.15, function()
			if boostTutorialActive then
				showBoostActivateButtonStep()
			end
		end)
	end)
end

local function showBoostInventoryStep()
	if not boostTutorialActive then return end

	local mg = getMainGui()
	if not mg then
		warn("[BoostTutorial] MainGui not found")
		return
	end

	local buttons = mg:FindFirstChild("Buttons")
	if not buttons then
		warn("[BoostTutorial] Buttons frame not found")
		return
	end

	local inventoryBtn = buttons:FindFirstChild("InventoryBtn")
	if not (inventoryBtn and inventoryBtn:IsA("GuiButton")) then
		warn("[BoostTutorial] InventoryBtn not found")
		return
	end

	showNotify("You received a free 2x Coins boost!\nOpen your Inventory to see your boosts.", 0)

	cleanupBoostArrow()
	boostArrowGui = createGuiArrowLabel("BoostInventoryArrowHint", 80)
	boostArrowConn = followGuiObject(boostArrowGui, inventoryBtn, -10, 4, 6)

	if boostBtnConn then boostBtnConn:Disconnect() end
	boostBtnConn = inventoryBtn.MouseButton1Click:Connect(function()
		if not boostTutorialActive then return end
		cleanupBoostArrow()

		task.delay(0.15, function()
			if boostTutorialActive then
				showBoostSelectTabStep()
			end
		end)
	end)
end

local function startBoostTutorial()
	if boostTutorialActive then
		warn("[BoostTutorial] already active")
		return
	end

	boostTutorialActive = true

	if tutorialGui then
		tutorialGui.Enabled = true
	end

	local mg = getMainGui()
	if mg then
		mg.Enabled = true
	end

	showBoostInventoryStep()
end

---------------------------------------------------------------------
-- WALLS, BOOST TUTORIAL, 2-я и 3-я стена + ховерборд
---------------------------------------------------------------------
---------------------------------------------------------------------
-- Wall purchase handlers (used by real event AND dev-simulation)
---------------------------------------------------------------------

-- Wall purchase handlers (used by real event AND dev-simulation)

handleWall1Purchased = function()
	wantWallPurchase = false
	destroyArrow()

	showNotify(
		"Awesome! You unlocked the next area!\nYou also received a free 2x Coins boost.",
		0
	)

	startBoostTutorial()
end

handleWall2Purchased = function()
	wantSecondWallPurchase = false
	destroyArrow()

	showNotify("Awesome! You unlocked another area!\nNow I'll show you what Gems are!", 0)

	task.delay(1, function()
		showNotify("Follow the arrow to the Gems (purple crystals) and click them!", 0)

		pointArrowToFirstGems_Location3(function()
			showNotify("Nice! These are Gems.\nCollect 500 Gems to buy your first upgrade!", 6)

			task.delay(6, function()
				startQuest5Gems()
			end)
		end)
	end)
end

handleWall3Purchased = function()
	wantThirdWallPurchase = false
	destroyArrow()

	-- в проде ты выдаёшь гемы через сервер
	if GiveHoverTutorialGemsEvent then
		GiveHoverTutorialGemsEvent:FireServer()
	end

	showNotify("Awesome! You unlocked a new area\nand received 10,000 Gems!", 5)

	task.delay(5, function()
		startGoToHoverMeshStep()
	end)
end

handleFinalWallPurchased = function()
	wantFinalWallPurchase = false
	destroyArrow()

	showNotify("YOU DID IT! 🎉\nTutorial completed.\nYou will receive your Guide Robot reward!", 8)

	task.delay(8, function()
		if tutorialGui then
			tutorialGui.Enabled = false
		end
		if notifyLabel then
			notifyLabel.Visible = false
		end
	end)
end


UpdateWallsEvent.OnClientEvent:Connect(function(...)
	-- 1-я стена (после Quest3)
	if wantWallPurchase then
		handleWall1Purchased()
		return
	end

	-- 2-я стена (после Quest4)
	if wantSecondWallPurchase then
		handleWall2Purchased()
		return
	end

	-- 3-я стена (после Quest8)
	if wantThirdWallPurchase then
		handleWall3Purchased()
		return
	end

	-- финальная стена (после Quest9)
	if wantFinalWallPurchase then
		handleFinalWallPurchased()
		return
	end
end)



ShowBoostTutorialEvent.OnClientEvent:Connect(function()
	if not boostTutorialActive then
		startBoostTutorial()
	end
end)

---------------------------------------------------------------------
-- SLIDES
---------------------------------------------------------------------

local function hideAllSteps()

	for _, name in ipairs(stepOrder) do
		local frame = mainFrame:FindFirstChild(name)
		if frame then
			frame.Visible = false
		end
	end
end

local function showStep(index: number)
	hideAllSteps()
	local stepName  = stepOrder[index]
	local stepFrame = stepName and mainFrame:FindFirstChild(stepName)
	if stepFrame then
		stepFrame.Visible = true
	end
end

---------------------------------------------------------------------
-- START / FINISH
---------------------------------------------------------------------

local function showAfterTutorialHint()
	local mg = getMainGui()
	if mg then
		mg.Enabled = true
	end
	tutorialStartCoins = tonumber(world1Currency.Value) or 0
	tutorialStartGems  = tonumber(gemsCurrency.Value) or 0

	hideAllSteps()
	mainFrame.Visible = false
	skipBtn.Visible   = false

	quest1BaseCoins        = tonumber(world1Currency.Value) or 0
	questListening1        = true
	firstCoinAcknowledged  = false
	setQuestProgress(quest1BaseCoins, quest1BaseCoins, QUEST1_TARGET)

	showNotify("Follow the arrow to the coin and click it\nso your NFT starts farming it for you!", 0)

	pointArrowToFirstCoin(function()
		showNotify("Great! Now click the coin to collect your first coins!", 0)
	end)
end

local currentStep = 1

local function finishTutorial()
	showAfterTutorialHint()
end

local function startTutorial()
	local mg = getMainGui()
	if mg then
		mg.Enabled = false
	end

	tutorialGui.Enabled = true
	mainFrame.Visible   = true
	mainFrame.BackgroundTransparency = 0.35

	notifyLabel.Visible = false
	skipBtn.Visible     = true

	currentStep = 1
	showStep(currentStep)
end

tutorialGui.Enabled = false
mainFrame.Visible   = false
notifyLabel.Visible = false
hideAllSteps()

for _, name in ipairs(stepOrder) do
	local frame = mainFrame:FindFirstChild(name)
	if frame then
		local nextBtn = frame:FindFirstChildWhichIsA("TextButton", true)
		if nextBtn then
			nextBtn.MouseButton1Click:Connect(function()
				currentStep += 1

				if currentStep > #stepOrder then
					finishTutorial()
					return
				end

				showStep(currentStep)
			end)
		end
	end
end

skipBtn.MouseButton1Click:Connect(function()
	finishTutorial()
end)

-- ✅ only once (you had it duplicated)
ShowTutorialEvent.OnClientEvent:Connect(startTutorial)

if DEBUG_ALWAYS_SHOW_TUTORIAL then
	task.delay(1, function()
		startTutorial()
	end)
end
