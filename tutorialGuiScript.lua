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

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local inventoryFolder   = player:WaitForChild("Inventory")
local currencies        = player:WaitForChild("Currencies")
local worldCurrencies   = currencies:WaitForChild("WorldCurrencies")
local world1Currency    = worldCurrencies:WaitForChild("World1")
local gemsCurrency      = currencies:WaitForChild("Gems")
local activeBoostsFolder = player:WaitForChild("ActiveBoostsFolder")

local lastHatchedUuid : string? = nil

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
-- QUEST UI (lazy init)
---------------------------------------------------------------------

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

---------------------------------------------------------------------
-- MODULES
---------------------------------------------------------------------

local ArrowHelpers = require(script:WaitForChild("TutorialArrowHelpers"))
local InventoryModule = require(script:WaitForChild("TutorialInventoryModule"))
local QuestModule = require(script:WaitForChild("TutorialQuestModule"))

local worldRoot = Workspace:WaitForChild("PixelWorld1")

local arrow = ArrowHelpers.new({
	player = player,
	tutorialGui = tutorialGui,
	worldRoot = worldRoot,
	ReplicatedStorage = ReplicatedStorage,
	Workspace = Workspace,
	RunService = RunService,
	ARROW_ROT_OFFSET = ARROW_ROT_OFFSET,
})

local questModule

local inventoryModule = InventoryModule.new({
	playerGui = playerGui,
	inventoryFolder = inventoryFolder,
	showNotify = showNotify,
	getMainGui = getMainGui,
	findOpenInventoryMain = findOpenInventoryMain,
	arrow = arrow,
	onNftEquipped = function()
		if questModule then
			questModule.startQuest2()
		end
	end,
})

questModule = QuestModule.new({
	player = player,
	playerGui = playerGui,
	worldRoot = worldRoot,
	world1Currency = world1Currency,
	gemsCurrency = gemsCurrency,
	activeBoostsFolder = activeBoostsFolder,
	GiveHoverTutorialGemsEvent = GiveHoverTutorialGemsEvent,
	showNotify = showNotify,
	showQuest = showQuest,
	hideQuest = hideQuest,
	ensureQuestUi = ensureQuestUi,
	setQuestProgress = setQuestProgress,
	getMainGui = getMainGui,
	findInventoryContainer = findInventoryContainer,
	arrow = arrow,
	inventory = inventoryModule,
	RunService = RunService,
	tutorialGui = tutorialGui,
	notifyLabel = notifyLabel,
	lastHatchedUuid = function()
		return lastHatchedUuid
	end,
	setLastHatchedUuid = function(uuid)
		lastHatchedUuid = uuid
	end,
	questFrame = function()
		return questFrame
	end,
})

questModule.connectSignals()

---------------------------------------------------------------------
-- PET + WALL + BOOST EVENTS
---------------------------------------------------------------------

PetHatchedEvent.OnClientEvent:Connect(function(payload)
	questModule.handlePetHatched(payload)
end)

UpdateWallsEvent.OnClientEvent:Connect(function()
	questModule.handleUpdateWalls()
end)

HoverboardPurchasedEvent.OnClientEvent:Connect(function(boardName)
	questModule.handleHoverboardPurchased(boardName)
end)

ShowBoostTutorialEvent.OnClientEvent:Connect(function()
	questModule.startBoostTutorial()
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

	hideAllSteps()
	mainFrame.Visible = false
	skipBtn.Visible   = false

	questModule.startInteractiveTutorial()
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

ShowTutorialEvent.OnClientEvent:Connect(startTutorial)

if DEBUG_ALWAYS_SHOW_TUTORIAL then
	task.delay(1, function()
		startTutorial()
	end)
end
