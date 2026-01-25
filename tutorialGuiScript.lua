-- StarterGui/TutorialGui/LocalScript
-- ✅ Behavior:
-- 1) Slides tutorial -> finish -> interactive quest tutorial starts (arrows/quests)
-- 2) “Dumb mode”: for every block-opening quest we point arrow to the correct block
-- 3) After EVERY hatched NFT we remind player to equip it (Inventory -> click NFT)

local DEBUG_ALWAYS_SHOW_TUTORIAL = true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local inventoryFolder = player:WaitForChild("Inventory")
local currencies = player:WaitForChild("Currencies")
local worldCurrencies = currencies:WaitForChild("WorldCurrencies")
local world1Currency = worldCurrencies:WaitForChild("World1")
local gemsCurrency = currencies:WaitForChild("Gems")
local activeBoostsFolder = player:WaitForChild("ActiveBoostsFolder")

local lastHatchedUuid: string? = nil

---------------------------------------------------------------------
-- GUI
---------------------------------------------------------------------

local tutorialGui = script.Parent
local mainFrame = tutorialGui:WaitForChild("MainFrame")

tutorialGui.DisplayOrder = 1000

local mainGui: ScreenGui? = playerGui:FindFirstChild("MainGui")
if mainGui and mainGui.DisplayOrder >= tutorialGui.DisplayOrder then
	mainGui.DisplayOrder = tutorialGui.DisplayOrder - 1
end

local skipBtn = mainFrame:WaitForChild("SkipBtn")
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
-- TRACK INVENTORY NFT
---------------------------------------------------------------------

local function isInventoryNftNode(child: Instance): boolean
	if not child or not child:IsA("Folder") then return false end
	if child:GetAttribute("IsGuide") == true then return false end

	local nm = child:GetAttribute("Name")
	if typeof(nm) == "string" and nm ~= "" then
		return true
	end

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
	if child:GetAttribute("IsGuide") == true then
		showNotify(
			"You received a Guide Robot!\nIts power matches the average power of your current world.",
			6
		)
		return
	end

	if not knownNfts[child.Name] then
		knownNfts[child.Name] = true
		if isInventoryNftNode(child) then
			lastHatchedUuid = child.Name
			warn("[Tutorial] Inventory ChildAdded (NEW NFT), lastHatchedUuid =", lastHatchedUuid)
		end
	else
		if isInventoryNftNode(child) then
			if lastHatchedUuid ~= child.Name then
				lastHatchedUuid = child.Name
				warn("[Tutorial] Inventory ChildAdded (NFT), lastHatchedUuid =", lastHatchedUuid)
			end
		end
	end
end)

---------------------------------------------------------------------
-- REMOTES
---------------------------------------------------------------------

local ShowTutorialEvent = ReplicatedStorage:WaitForChild("ShowTutorialEvent")
local PetHatchedEvent = ReplicatedStorage:WaitForChild("PetHatchedEvent")
local UpdateWallsEvent = ReplicatedStorage:WaitForChild("UpdateWalls")
local ShowBoostTutorialEvent = ReplicatedStorage:WaitForChild("ShowBoostTutorialEvent")
local GiveHoverTutorialGemsEvent = ReplicatedStorage:WaitForChild("GiveHoverTutorialGems")
local HoverboardPurchasedEvent = ReplicatedStorage:WaitForChild("HoverboardPurchasedEvent")

local stepOrder = {
	"1thStep", "2thStep", "3thStep", "4thStep", "5thStep", "6thStep",
	"7thStep", "8thStep", "9thStep", "10thStep", "11thStep", "12thStep",
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
-- MODULE SETUP
---------------------------------------------------------------------

local arrows = require(script:WaitForChild("TutorialGuiArrows"))({
	ReplicatedStorage = ReplicatedStorage,
	Workspace = Workspace,
	RunService = RunService,
	player = player,
	tutorialGui = tutorialGui,
	worldRoot = Workspace:WaitForChild("PixelWorld1"),
	arrowRotOffset = ARROW_ROT_OFFSET,
})

local inventoryModule = require(script:WaitForChild("TutorialGuiInventory"))({
	playerGui = playerGui,
	inventoryFolder = inventoryFolder,
	getMainGui = getMainGui,
	findOpenInventoryMain = findOpenInventoryMain,
	showNotify = showNotify,
	arrows = arrows,
})

local questsModule = require(script:WaitForChild("TutorialGuiQuests"))({
	player = player,
	playerGui = playerGui,
	tutorialGui = tutorialGui,
	worldRoot = Workspace:WaitForChild("PixelWorld1"),
	world1Currency = world1Currency,
	gemsCurrency = gemsCurrency,
	activeBoostsFolder = activeBoostsFolder,
	GiveHoverTutorialGemsEvent = GiveHoverTutorialGemsEvent,
	RunService = RunService,
	arrows = arrows,
	showNotify = showNotify,
	getMainGui = getMainGui,
	findInventoryContainer = findInventoryContainer,
	startEquipBestStep = inventoryModule.startEquipBestStep,
})

inventoryModule.setStartQuest2(questsModule.startQuest2)

world1Currency:GetPropertyChangedSignal("Value"):Connect(questsModule.onWorld1Changed)
gemsCurrency:GetPropertyChangedSignal("Value"):Connect(questsModule.onGemsChanged)

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
	local hatchedUuid = extractUuidFromPayload(payload)
	if not hatchedUuid or hatchedUuid == "" then
		hatchedUuid = waitForNewHatchedUuid(3)
	end

	if hatchedUuid and hatchedUuid ~= "" then
		lastHatchedUuid = hatchedUuid
	else
		warn("[Tutorial] PetHatchedEvent: cannot detect uuid")
	end

	questsModule.handleHatchedNft(hatchedUuid, inventoryModule)
end)

---------------------------------------------------------------------
-- OTHER EVENTS
---------------------------------------------------------------------

HoverboardPurchasedEvent.OnClientEvent:Connect(function(boardName)
	warn("[Tutorial] HoverboardPurchasedEvent, board =", boardName)
	questsModule.handleHoverboardPurchased(boardName)
end)

UpdateWallsEvent.OnClientEvent:Connect(function()
	questsModule.handleWallEvent()
end)

ShowBoostTutorialEvent.OnClientEvent:Connect(function()
	questsModule.startBoostTutorial()
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
	local stepName = stepOrder[index]
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

	hideAllSteps()
	mainFrame.Visible = false
	skipBtn.Visible = false

	questsModule.beginInteractiveTutorial()
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
	mainFrame.Visible = true
	mainFrame.BackgroundTransparency = 0.35

	notifyLabel.Visible = false
	skipBtn.Visible = true

	currentStep = 1
	showStep(currentStep)
end

tutorialGui.Enabled = false
mainFrame.Visible = false
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

ShowTutorialEvent.OnClientEvent:Connect(startTutorial)

if DEBUG_ALWAYS_SHOW_TUTORIAL then
	task.delay(1, function()
		startTutorial()
	end)
end
