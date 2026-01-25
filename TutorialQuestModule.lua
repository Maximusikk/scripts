-- ModuleScript: TutorialQuestModule

local QuestModule = {}

function QuestModule.new(context)
	local player = context.player
	local playerGui = context.playerGui
	local worldRoot = context.worldRoot
	local world1Currency = context.world1Currency
	local gemsCurrency = context.gemsCurrency
	local activeBoostsFolder = context.activeBoostsFolder
	local GiveHoverTutorialGemsEvent = context.GiveHoverTutorialGemsEvent

	local showNotify = context.showNotify
	local showQuest = context.showQuest
	local hideQuest = context.hideQuest
	local ensureQuestUi = context.ensureQuestUi
	local setQuestProgress = context.setQuestProgress
	local getMainGui = context.getMainGui
	local findInventoryContainer = context.findInventoryContainer

	local arrow = context.arrow
	local inventory = context.inventory

	local DEV_FORCE_TUTORIAL_SIM = true
	local DEV_USER_IDS = {
		[player.UserId] = true,
	}

	local function isDevTutorialSim(): boolean
		return DEV_FORCE_TUTORIAL_SIM == true and DEV_USER_IDS[player.UserId] == true
	end

	local function isWallUnlocked(folderName: string, partName: string?): boolean
		local folder = worldRoot:FindFirstChild(folderName)
		if not folder then
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

		if wallPart:GetAttribute("Unlocked") == true then
			return true
		end

		if wallPart.CanCollide == false then
			return true
		end

		if wallPart.Transparency >= 0.95 then
			return true
		end

		return false
	end

	local tutorialStartCoins = 0
	local tutorialStartGems  = 0
	local function getEarnedCoins(): number
		return math.max(0, (tonumber(world1Currency.Value) or 0) - (tutorialStartCoins or 0))
	end

	local function getEarnedGems(): number
		return math.max(0, (tonumber(gemsCurrency.Value) or 0) - (tutorialStartGems or 0))
	end

	local questFrame : Frame? = nil

	local function ensureQuestWindow(): boolean
		if ensureQuestUi() then
			questFrame = context.questFrame()
			return true
		end
		return false
	end

	local function delta(earned: number, base: number): number
		return math.max(0, math.floor((earned or 0) - (base or 0)))
	end

	local QUEST1_TARGET       = 150
	local QUEST2_TARGET       = 300
	local QUEST3_TARGET       = 500
	local QUEST4_TARGET       = 1000
	local QUEST5_TARGET_GEMS  = 500
	local QUEST6_TARGET       = 600
	local QUEST7_TARGET       = 1200
	local QUEST8_TARGET       = 2000
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

	local upgradeArrowGui  : TextLabel? = nil
	local upgradeArrowConn : RBXScriptConnection? = nil
	local upgradeBtnConn   : RBXScriptConnection? = nil

	local upgradeStepActive = false
	local upgradeStepDone   = false

	local hoverboardStepActive  = false
	local hoverboardStepDone    = false

	local boostTutorialActive = false
	local boostArrowGui  : TextLabel? = nil
	local boostArrowConn : RBXScriptConnection? = nil
	local boostBtnConn   : RBXScriptConnection? = nil

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

	local onWorld1Changed
	local onGemsChanged

	local function startQuest1()
		if quest1Active or quest1Finished then return end
		quest1Active = true

		local earned = getEarnedCoins()
		quest1BaseCoins = earned

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

	local function startQuest9()
		if quest9Active or quest9Finished then return end
		quest9Active = true

		local earned = getEarnedCoins()
		quest9BaseCoins = earned

		showQuest("Farm 5000 coins", 0, QUEST9_TARGET)
		showNotify("Final step! Farm 5000 coins to unlock the last wall and finish the tutorial!", 4)

		onWorld1Changed()
	end

	local function startGoToFinalWallStep()
		wantFinalWallPurchase = true

		if isDevTutorialSim() and isWallUnlocked("Location4Wall", "Location4Wall") then
			showNotify("[DEV] Final wall already unlocked → simulating purchase…", 2)
			task.delay(0.3, context.handleFinalWallPurchased)
			return
		end

		showNotify("Awesome! You have enough coins.\nFollow the arrow to the last wall!", 0)

		arrow.pointArrowToFinalWall(function()
			showNotify("Press E on PC or tap the E button on mobile\nto buy and finish the tutorial!", 0)
		end)
	end

	local function startGoToGrassBlockStep()
		showNotify("Awesome! You farmed enough coins.\nFollow the arrow to the 150-coin block!", 0)

		arrow.pointArrowToGrassBlock(function()
			showNotify("Press E on PC or tap the E button on mobile to open the block.", 0)
		end)
	end

	local function startExtraBlocksOpenStep()
		wantExtraBlocks   = true
		extraBlocksOpened = 0

		showQuest("Open 2 blocks", extraBlocksOpened, extraBlocksGoal)

		showNotify("Now open 2 more blocks!\nFollow the arrow and press E (or tap) to open.", 0)

		arrow.pointArrowToGrassBlock(function()
			showNotify("Press E on PC or tap the E button on mobile to open the block.", 0)
		end)
	end

	local function startGoToWallStep()
		wantWallPurchase = true

		if isDevTutorialSim() and isWallUnlocked("Location1Wall", "Location1Wall") then
			showNotify("[DEV] Wall 1 already unlocked → simulating purchase…", 2)
			task.delay(0.3, context.handleWall1Purchased)
			return
		end

		showNotify("Great! You have enough coins.\nFollow the arrow to the white wall!", 0)

		arrow.pointArrowToWall(function()
			showNotify("Press E on PC or tap the E button on mobile\nto buy and open the next area!", 0)
		end)
	end

	local function startGoToSecondWallStep()
		wantSecondWallPurchase = true

		if isDevTutorialSim() and isWallUnlocked("Location2Wall", "Location2Wall") then
			showNotify("[DEV] Wall 2 already unlocked → simulating purchase…", 2)
			task.delay(0.3, context.handleWall2Purchased)
			return
		end

		showNotify("Great! You have enough coins.\nFollow the arrow to the next white wall!", 0)

		arrow.pointArrowToSecondWall(function()
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

		arrow.pointArrowToUpgradeMachine(function()
			showNotify("Stand on the glowing area to open the upgrade menu,\nthen buy your first speed upgrade!", 0)

			context.startUpgradeButtonStep()
		end)
	end

	local function startBarnPhase1()
		wantBarnPhase1   = true
		barnOpenedPhase1 = 0

		showQuest("Open Barn block (1 time)", barnOpenedPhase1, 1)

		showNotify("Nice! Now open the Barn block once.\nFollow the arrow to the Barn block!", 0)

		arrow.pointArrowToBarnBlock(function()
			showNotify("Press E on PC or tap the E button on mobile\nto open the Barn block!", 0)
		end)
	end

	local function startBarnPhase2()
		wantBarnPhase2   = true
		barnOpenedPhase2 = 0

		showQuest("Open Barn block (2 more times)", barnOpenedPhase2, 2)

		showNotify("Awesome! Now open the Barn block 2 more times!\nFollow the arrow to the Barn block.", 0)

		arrow.pointArrowToBarnBlock(function()
			showNotify("Keep opening the Barn block to complete the quest!", 0)
		end)
	end

	local function startGoToThirdWallStep()
		wantThirdWallPurchase = true

		if isDevTutorialSim() and isWallUnlocked("Location3Wall", "Location3Wall") then
			showNotify("[DEV] Wall 3 already unlocked → simulating purchase…", 2)
			task.delay(0.3, context.handleWall3Purchased)
			return
		end

		showNotify("Great! Follow the arrow to the next white wall\nand unlock a new area!", 0)

		arrow.pointArrowToThirdWall(function()
			showNotify("Press E on PC or tap the E button on mobile\nto buy and open the new area!", 0)
		end)
	end

	local function startGoToHoverMeshStep()
		hoverboardStepActive = true
		hoverboardStepDone   = false

		showNotify("You received 10,000 Gems!\nFollow the arrow to the hoverboard stand!", 0)

		arrow.pointArrowToHoverMesh(function()
			showNotify("Press E on PC or tap the E button on mobile\nto buy your first hoverboard!", 0)
		end)
	end

	local function completeHoverboardStep(boardName: string?)
		if hoverboardStepDone then
			return
		end

		hoverboardStepDone   = true
		hoverboardStepActive = false

		arrow.destroyArrow()

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

	context.startUpgradeButtonStep = function()
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

			upgradeArrowGui = arrow.createGuiArrowLabel("UpgradeArrowHint", 120)
			showNotify("Tap this button to buy your first speed upgrade!", 0)

			upgradeArrowConn = arrow.followGuiObject(upgradeArrowGui, upgradeBtn, -10, 4, 6)

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
				context.RunService.RenderStepped:Wait()
			end
		end)
	end

	local function waitForCoinsBoostActivated(timeout: number?): boolean
		timeout = timeout or 25
		local t0 = tick()

		while tick() - t0 < timeout do
			local val = activeBoostsFolder:FindFirstChild("2xCoinsBoost")
			if val and val:IsA("IntValue") and val.Value > 0 then
				return true
			end
			context.RunService.Heartbeat:Wait()
		end

		return false
	end

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
		boostArrowGui = arrow.createGuiArrowLabel("BoostActivateArrowHint", 90)
		boostArrowConn = arrow.followGuiObject(boostArrowGui, boostBtn, -10, 4, 6)

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

	local function showBoostSelectTabStep()
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
					context.RunService.Heartbeat:Wait()
				end
			end)
			return
		end

		showNotify("In Inventory, open the Boosts tab.", 0)

		cleanupBoostArrow()
		boostArrowGui = arrow.createGuiArrowLabel("BoostsTabArrowHint", 80)
		boostArrowConn = arrow.followGuiObject(boostArrowGui, tabBtn, -10, 4, 6)

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
		boostArrowGui = arrow.createGuiArrowLabel("BoostInventoryArrowHint", 80)
		boostArrowConn = arrow.followGuiObject(boostArrowGui, inventoryBtn, -10, 4, 6)

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

		if context.tutorialGui then
			context.tutorialGui.Enabled = true
		end

		local mg = getMainGui()
		if mg then
			mg.Enabled = true
		end

		showBoostInventoryStep()
	end

	context.handleWall1Purchased = function()
		wantWallPurchase = false
		arrow.destroyArrow()

		showNotify(
			"Awesome! You unlocked the next area!\nYou also received a free 2x Coins boost.",
			0
		)

		startBoostTutorial()
	end

	context.handleWall2Purchased = function()
		wantSecondWallPurchase = false
		arrow.destroyArrow()

		showNotify("Awesome! You unlocked another area!\nNow I'll show you what Gems are!", 0)

		task.delay(1, function()
			showNotify("Follow the arrow to the Gems (purple crystals) and click them!", 0)

			arrow.pointArrowToFirstGems_Location3(function()
				showNotify("Nice! These are Gems.\nCollect 500 Gems to buy your first upgrade!", 6)

				task.delay(6, function()
					startQuest5Gems()
				end)
			end)
		end)
	end

	context.handleWall3Purchased = function()
		wantThirdWallPurchase = false
		arrow.destroyArrow()

		if GiveHoverTutorialGemsEvent then
			GiveHoverTutorialGemsEvent:FireServer()
		end

		showNotify("Awesome! You unlocked a new area\nand received 10,000 Gems!", 5)

		task.delay(5, function()
			startGoToHoverMeshStep()
		end)
	end

	context.handleFinalWallPurchased = function()
		wantFinalWallPurchase = false
		arrow.destroyArrow()

		showNotify("YOU DID IT! 🎉\nTutorial completed.\nYou will receive your Guide Robot reward!", 8)

		task.delay(8, function()
			if context.tutorialGui then
				context.tutorialGui.Enabled = false
			end
			if context.notifyLabel then
				context.notifyLabel.Visible = false
			end
		end)
	end

	local function handleUpdateWalls()
		if wantWallPurchase then
			context.handleWall1Purchased()
			return
		end

		if wantSecondWallPurchase then
			context.handleWall2Purchased()
			return
		end

		if wantThirdWallPurchase then
			context.handleWall3Purchased()
			return
		end

		if wantFinalWallPurchase then
			context.handleFinalWallPurchased()
			return
		end
	end

	local function onWorld1Changed()
		local earned = getEarnedCoins()

		if questListening1 and not quest1Finished then
			if (not firstCoinAcknowledged) and earned > 0 then
				firstCoinAcknowledged = true
				arrow.destroyArrow()
				showNotify("Nice! Keep farming coins like that!", 0)

				task.delay(5, function()
					if quest1Finished then return end
					startQuest1()
					context.notifyLabel.Visible = false
				end)
			end
		end

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

	local function onGemsChanged()
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
		local first = context.lastHatchedUuid()
		repeat
			if context.lastHatchedUuid() and context.lastHatchedUuid() ~= first then
				return context.lastHatchedUuid()
			end
			context.RunService.Heartbeat:Wait()
		until tick() - start > (timeout or 3)
		return context.lastHatchedUuid()
	end

	local function handlePetHatched(payload)
		if not quest1Finished then
			return
		end

		local hatchedUuid = extractUuidFromPayload(payload)
		if not hatchedUuid or hatchedUuid == "" then
			hatchedUuid = waitForNewHatchedUuid(3)
		end

		if hatchedUuid and hatchedUuid ~= "" then
			context.setLastHatchedUuid(hatchedUuid)
		else
			warn("[Tutorial] PetHatchedEvent: cannot detect uuid")
		end

		if not quest2Active
			and not quest2Finished
			and not wantExtraBlocks
			and not quest3Active
			and not quest3Finished
			and not inventory.isInventoryStepDone()
			and not inventory.isNftClickStepDone()
		then
			arrow.destroyArrow()

			inventory.setFirstNftUuid(context.lastHatchedUuid())
			warn("[Tutorial] First hatch, firstNftUuid =", context.lastHatchedUuid())

			showNotify("Nice! You opened the block and got your first NFT!", 0)

			task.delay(1.5, function()
				if not inventory.isInventoryStepDone() and not inventory.isNftClickStepDone() then
					inventory.showInventoryHint()
				end
			end)

			return
		end

		if wantExtraBlocks then
			extraBlocksOpened += 1

			showQuest("Open 2 blocks", extraBlocksOpened, extraBlocksGoal)

			if extraBlocksOpened < extraBlocksGoal then
				showNotify(
					string.format("Nice! %d/%d blocks opened.\nOpen %d more blocks!",
						extraBlocksOpened, extraBlocksGoal, extraBlocksGoal - extraBlocksOpened
					),
					0
				)

				arrow.pointArrowToGrassBlock(function()
					showNotify("Press E on PC or tap the E button on mobile to open the block.", 0)
				end)

				return
			end

			wantExtraBlocks = false
			arrow.destroyArrow()
			hideQuest()

			showNotify("Awesome! You opened 2 more blocks!\nNow let's auto-equip the best NFTs!", 0)

			inventory.setEquipReminderCooldown(8)

			task.delay(0.8, function()
				inventory.startEquipBestStep(function()
					showNotify("Great! Now farm 500 coins!", 2)
					task.delay(2, function()
						startQuest3()
					end)
				end)
			end)

			return
		end

		if wantBarnPhase1 then
			barnOpenedPhase1 += 1
			showQuest("Open Barn block (1 time)", barnOpenedPhase1, 1)

			wantBarnPhase1 = false
			arrow.destroyArrow()
			hideQuest()

			showNotify("Great! You opened the Barn block.\nNow farm 1200 coins!", 0)
			startQuest7()
			return
		end

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

				arrow.pointArrowToBarnBlock(function()
					showNotify("Press E on PC or tap the E button on mobile\nto open the Barn block!", 0)
				end)
			else
				wantBarnPhase2 = false
				arrow.destroyArrow()
				hideQuest()

				showNotify("Awesome! You opened the Barn block 3 times!\nNow farm 2000 coins to unlock a new area!", 0)
				startQuest8()
			end

			return
		end

		if hatchedUuid and hatchedUuid ~= "" then
			if not wantExtraBlocks
				and not wantBarnPhase1
				and not wantBarnPhase2
				and not inventory.isEquipBestStepActive()
				and not inventory.isInventoryStepActive()
				and not inventory.isNftClickStepActive()
			then
				inventory.showEquipReminderForUuid(hatchedUuid)
			end
		end
	end

	local function startInteractiveTutorial()
		tutorialStartCoins = tonumber(world1Currency.Value) or 0
		tutorialStartGems  = tonumber(gemsCurrency.Value) or 0

		quest1BaseCoins        = tonumber(world1Currency.Value) or 0
		questListening1        = true
		firstCoinAcknowledged  = false
		setQuestProgress(quest1BaseCoins, quest1BaseCoins, QUEST1_TARGET)

		showNotify("Follow the arrow to the coin and click it\nso your NFT starts farming it for you!", 0)

		arrow.pointArrowToFirstCoin(function()
			showNotify("Great! Now click the coin to collect your first coins!", 0)
		end)
	end

	local function connectSignals()
		ensureQuestWindow()
		if questFrame then
			questFrame.Visible = false
		end

		quest1BaseCoins = tonumber(world1Currency.Value) or 0
		setQuestProgress(quest1BaseCoins, quest1BaseCoins, QUEST1_TARGET)

		world1Currency:GetPropertyChangedSignal("Value"):Connect(onWorld1Changed)
		gemsCurrency:GetPropertyChangedSignal("Value"):Connect(onGemsChanged)
	end

	return {
		connectSignals = connectSignals,
		startInteractiveTutorial = startInteractiveTutorial,
		handleUpdateWalls = handleUpdateWalls,
		handlePetHatched = handlePetHatched,
		handleHoverboardPurchased = function(boardName)
			if not hoverboardStepActive then
				return
			end
			completeHoverboardStep(boardName)
		end,
		startBoostTutorial = startBoostTutorial,
		isQuest1Finished = function() return quest1Finished end,
		startQuest2 = startQuest2,
		setQuestFrame = function(frame)
			questFrame = frame
		end,
	}
end

return QuestModule
