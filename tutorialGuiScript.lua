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

local InventoryTracker = require(script:WaitForChild("InventoryTracker"))
local UiHelpers = require(script:WaitForChild("UiHelpers"))
local WorldArrows = require(script:WaitForChild("WorldArrows"))
local TutorialBoost = require(script:WaitForChild("TutorialBoost"))
local TutorialInventory = require(script:WaitForChild("TutorialInventory"))
local TutorialQuests = require(script:WaitForChild("TutorialQuests"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local inventoryFolder   = player:WaitForChild("Inventory")
local currencies        = player:WaitForChild("Currencies")
local worldCurrencies   = currencies:WaitForChild("WorldCurrencies")
local world1Currency    = worldCurrencies:WaitForChild("World1")
local gemsCurrency      = currencies:WaitForChild("Gems")
local activeBoostsFolder = player:WaitForChild("ActiveBoostsFolder")

-- флаги шага с ховербордом (глобальные для этого скрипта)
local hoverboardStepActive  = false
local hoverboardStepDone    = false

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

local ui = UiHelpers.new({
	tutorialGui = tutorialGui,
	playerGui = playerGui,
	mainGui = mainGui,
	notifyLabel = notifyLabel,
})

local showNotify = ui.showNotify
local getMainGui = ui.getMainGui
local findOpenInventoryMain = ui.findOpenInventoryMain
local findInventoryContainer = ui.findInventoryContainer
local createGuiArrowLabel = ui.createGuiArrowLabel
local followGuiObject = ui.followGuiObject

local inventoryTracker = InventoryTracker.new({
	inventoryFolder = inventoryFolder,
	onGuideRobot = function()
		showNotify("You received a Guide Robot!\nIts power matches the average power of your current world.", 6)
	end,
})

local extractUuidFromPayload = inventoryTracker.extractUuidFromPayload
local waitForNewHatchedUuid = inventoryTracker.waitForNewHatchedUuid
local getLastHatchedUuid = inventoryTracker.getLastHatchedUuid
local setLastHatchedUuid = inventoryTracker.setLastHatchedUuid

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

local worldRoot = Workspace:WaitForChild("PixelWorld1")
local worldArrows = WorldArrows.new({
	player = player,
	worldRoot = worldRoot,
	replicatedStorage = ReplicatedStorage,
	workspace = Workspace,
	runService = RunService,
	arrowRotOffset = ARROW_ROT_OFFSET,
})

local destroyArrow = worldArrows.destroyArrow
local pointArrowToFinalWall = worldArrows.pointArrowToFinalWall
local pointArrowToFirstGems_Location3 = worldArrows.pointArrowToFirstGems_Location3
local pointArrowToFirstCoin = worldArrows.pointArrowToFirstCoin
local pointArrowToGrassBlock = worldArrows.pointArrowToGrassBlock
local pointArrowToWall = worldArrows.pointArrowToWall
local pointArrowToSecondWall = worldArrows.pointArrowToSecondWall
local pointArrowToUpgradeMachine = worldArrows.pointArrowToUpgradeMachine
local pointArrowToBarnBlock = worldArrows.pointArrowToBarnBlock
local pointArrowToThirdWall = worldArrows.pointArrowToThirdWall
local pointArrowToHoverMesh = worldArrows.pointArrowToHoverMesh

---------------------------------------------------------------------
-- MODULE SETUP
---------------------------------------------------------------------

local function callEnsureQuestUi()
	return ensureQuestUi()
end

local function callShowQuest(...)
	return showQuest(...)
end

local function callHideQuest()
	return hideQuest()
end

local function callGetEarnedCoins()
	return getEarnedCoins()
end

local function callGetEarnedGems()
	return getEarnedGems()
end

local function getProgressText()
	return progressText
end

local function getProgressFill()
	return progressFill
end

local function getQuestFrame()
	return questFrame
end

local boostTutorial

local questApi = TutorialQuests.new({
	player = player,
	playerGui = playerGui,
	worldRoot = worldRoot,
	world1Currency = world1Currency,
	gemsCurrency = gemsCurrency,
	runService = RunService,
	showNotify = showNotify,
	getMainGui = ui.getMainGui,
	createGuiArrowLabel = createGuiArrowLabel,
	followGuiObject = followGuiObject,
	destroyArrow = destroyArrow,
	pointArrowToFinalWall = pointArrowToFinalWall,
	pointArrowToFirstGems_Location3 = pointArrowToFirstGems_Location3,
	pointArrowToFirstCoin = pointArrowToFirstCoin,
	pointArrowToGrassBlock = pointArrowToGrassBlock,
	pointArrowToWall = pointArrowToWall,
	pointArrowToSecondWall = pointArrowToSecondWall,
	pointArrowToUpgradeMachine = pointArrowToUpgradeMachine,
	pointArrowToBarnBlock = pointArrowToBarnBlock,
	pointArrowToThirdWall = pointArrowToThirdWall,
	pointArrowToHoverMesh = pointArrowToHoverMesh,
	ensureQuestUi = callEnsureQuestUi,
	showQuest = callShowQuest,
	hideQuest = callHideQuest,
	getEarnedCoins = callGetEarnedCoins,
	getEarnedGems = callGetEarnedGems,
	getProgressText = getProgressText,
	getProgressFill = getProgressFill,
	getQuestFrame = getQuestFrame,
	giveHoverTutorialGems = function()
		if GiveHoverTutorialGemsEvent then
			GiveHoverTutorialGemsEvent:FireServer()
		end
	end,
	startBoostTutorial = function()
		if boostTutorial then
			boostTutorial.startBoostTutorial()
		end
	end,
	tutorialGui = tutorialGui,
	notifyLabel = notifyLabel,
})

boostTutorial = TutorialBoost.new({
	showNotify = showNotify,
	getMainGui = ui.getMainGui,
	findInventoryContainer = findInventoryContainer,
	createGuiArrowLabel = createGuiArrowLabel,
	followGuiObject = followGuiObject,
	activeBoostsFolder = activeBoostsFolder,
	runService = RunService,
	tutorialGui = tutorialGui,
	onBoostActivated = function()
		task.delay(5, function()
			questApi.startQuest4()
		end)
	end,
})

local inventoryTutorial = TutorialInventory.new({
	showNotify = showNotify,
	getMainGui = ui.getMainGui,
	findOpenInventoryMain = findOpenInventoryMain,
	findInventoryContainer = findInventoryContainer,
	createGuiArrowLabel = createGuiArrowLabel,
	followGuiObject = followGuiObject,
	inventoryFolder = inventoryFolder,
	destroyArrow = destroyArrow,
	pointArrowToGrassBlock = pointArrowToGrassBlock,
	pointArrowToBarnBlock = pointArrowToBarnBlock,
	showQuest = callShowQuest,
	hideQuest = callHideQuest,
	extractUuidFromPayload = extractUuidFromPayload,
	waitForNewHatchedUuid = waitForNewHatchedUuid,
	getLastHatchedUuid = getLastHatchedUuid,
	setLastHatchedUuid = setLastHatchedUuid,
	questState = questApi.state,
	questApi = questApi,
})

questApi.initializeProgress()

world1Currency:GetPropertyChangedSignal("Value"):Connect(questApi.onWorld1Changed)
gemsCurrency:GetPropertyChangedSignal("Value"):Connect(questApi.onGemsChanged)

PetHatchedEvent.OnClientEvent:Connect(inventoryTutorial.handlePetHatched)
HoverboardPurchasedEvent.OnClientEvent:Connect(questApi.handleHoverboardPurchased)
UpdateWallsEvent.OnClientEvent:Connect(questApi.handleUpdateWalls)

ShowBoostTutorialEvent.OnClientEvent:Connect(function()
	boostTutorial.startBoostTutorial()
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
	hideAllSteps()
	mainFrame.Visible = false
	skipBtn.Visible   = false

	questApi.startCoinIntro()
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
