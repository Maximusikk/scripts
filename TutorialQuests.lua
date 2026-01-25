local TutorialQuests = {}

function TutorialQuests.new(ctx)
	local player = assert(ctx.player, "player is required")
	local playerGui = assert(ctx.playerGui, "playerGui is required")
	local worldRoot = assert(ctx.worldRoot, "worldRoot is required")
	local world1Currency = assert(ctx.world1Currency, "world1Currency is required")
	local gemsCurrency = assert(ctx.gemsCurrency, "gemsCurrency is required")
	local runService = assert(ctx.runService, "runService is required")

	local showNotify = assert(ctx.showNotify, "showNotify is required")
	local getMainGui = assert(ctx.getMainGui, "getMainGui is required")
	local createGuiArrowLabel = assert(ctx.createGuiArrowLabel, "createGuiArrowLabel is required")
	local followGuiObject = assert(ctx.followGuiObject, "followGuiObject is required")

	local destroyArrow = assert(ctx.destroyArrow, "destroyArrow is required")
	local pointArrowToFinalWall = assert(ctx.pointArrowToFinalWall, "pointArrowToFinalWall is required")
	local pointArrowToFirstGems_Location3 = assert(ctx.pointArrowToFirstGems_Location3, "pointArrowToFirstGems_Location3 is required")
	local pointArrowToFirstCoin = assert(ctx.pointArrowToFirstCoin, "pointArrowToFirstCoin is required")
	local pointArrowToGrassBlock = assert(ctx.pointArrowToGrassBlock, "pointArrowToGrassBlock is required")
	local pointArrowToWall = assert(ctx.pointArrowToWall, "pointArrowToWall is required")
	local pointArrowToSecondWall = assert(ctx.pointArrowToSecondWall, "pointArrowToSecondWall is required")
	local pointArrowToUpgradeMachine = assert(ctx.pointArrowToUpgradeMachine, "pointArrowToUpgradeMachine is required")
	local pointArrowToBarnBlock = assert(ctx.pointArrowToBarnBlock, "pointArrowToBarnBlock is required")
	local pointArrowToThirdWall = assert(ctx.pointArrowToThirdWall, "pointArrowToThirdWall is required")
	local pointArrowToHoverMesh = assert(ctx.pointArrowToHoverMesh, "pointArrowToHoverMesh is required")

	local ensureQuestUi = ctx.ensureQuestUi
	local showQuest = ctx.showQuest
	local hideQuest = ctx.hideQuest
	local getEarnedCoins = ctx.getEarnedCoins
	local getEarnedGems = ctx.getEarnedGems
	local getProgressText = ctx.getProgressText
	local getProgressFill = ctx.getProgressFill
	local getQuestFrame = ctx.getQuestFrame

	local giveHoverTutorialGems = ctx.giveHoverTutorialGems
	local startBoostTutorial = ctx.startBoostTutorial
	local tutorialGui = ctx.tutorialGui
	local notifyLabel = ctx.notifyLabel

	local state = {
		quest1Active = false,
		quest1Finished = false,
		quest2Active = false,
		quest2Finished = false,
		quest3Active = false,
		quest3Finished = false,
		quest4Active = false,
		quest4Finished = false,
		quest5Active = false,
		quest5Finished = false,
		quest6Active = false,
		quest6Finished = false,
		quest7Active = false,
		quest7Finished = false,
		quest8Active = false,
		quest8Finished = false,
		quest9Active = false,
		quest9Finished = false,
		questListening1 = false,
		firstCoinAcknowledged = false,
		wantFinalWallPurchase = false,
		extraBlocksGoal = 2,
		extraBlocksOpened = 0,
		wantExtraBlocks = false,
		wantWallPurchase = false,
		wantSecondWallPurchase = false,
		wantThirdWallPurchase = false,
		wantUpgradeMachine = false,
		wantBarnPhase1 = false,
		wantBarnPhase2 = false,
		barnOpenedPhase1 = 0,
		barnOpenedPhase2 = 0,
		hoverboardStepActive = false,
		hoverboardStepDone = false,
	}

	local handleWall1Purchased
	local handleWall2Purchased
	local handleWall3Purchased
	local handleFinalWallPurchased
	local onWorld1Changed
	local onGemsChanged

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

	local function setQuestProgress(rawValue: number, base: number, target: number)
		if ensureQuestUi and not ensureQuestUi() then return end

		base = base or 0
		target = target or 1

		local delta = math.max(0, math.floor((rawValue or 0) - base))
		local current = math.clamp(delta, 0, target)
		local ratio = (target > 0) and (current / target) or 0

		local progressText = getProgressText and getProgressText()
		local progressFill = getProgressFill and getProgressFill()

		progressText.Text = string.format("%d/%d", current, target)
		progressFill.Size = UDim2.new(ratio, 0, 1, 0)
	end

	local function initQuestUi()
		if ensureQuestUi then
			ensureQuestUi()
		end

		local questFrame = getQuestFrame and getQuestFrame()
		if questFrame then
			questFrame.Visible = false
		end
	end

	local QUEST1_TARGET = 150
	local QUEST2_TARGET = 300
	local QUEST3_TARGET = 500
	local QUEST4_TARGET = 1000
	local QUEST5_TARGET_GEMS = 500
	local QUEST6_TARGET = 600
	local QUEST7_TARGET = 1200
	local QUEST8_TARGET = 2000
	local QUEST9_TARGET = 5000

	local quest1BaseCoins = 0
	local quest2BaseCoins = 0
	local quest3BaseCoins = 0
	local quest4BaseCoins = 0
	local quest5BaseGems = 0
	local quest6BaseCoins = 0
	local quest7BaseCoins = 0
	local quest8BaseCoins = 0
	local quest9BaseCoins = 0

	local upgradeArrowGui: TextLabel? = nil
	local upgradeArrowConn: RBXScriptConnection? = nil
	local upgradeBtnConn: RBXScriptConnection? = nil

	local upgradeStepActive = false
	local upgradeStepDone = false

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

	local function delta(earned: number, base: number): number
		return math.max(0, math.floor((earned or 0) - (base or 0)))
	end

	local startQuest9

	local function completeHoverboardStep(boardName: string?)
		if state.hoverboardStepDone then
			return
		end

		state.hoverboardStepDone = true
		state.hoverboardStepActive = false

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
			if startQuest9 then
				startQuest9()
			end
		end)
	end

	local function startUpgradeButtonStep()
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

			local upgradeBtn: GuiButton? = folder:FindFirstChild("UpgradeBtn")
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
				upgradeStepDone = true
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
				runService.RenderStepped:Wait()
			end
		end)
	end

	local function startGoToFinalWallStep()
		state.wantFinalWallPurchase = true

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

	local function startExtraBlocksOpenStep()
		state.wantExtraBlocks = true
		state.extraBlocksOpened = 0

		showQuest("Open 2 blocks", state.extraBlocksOpened, state.extraBlocksGoal)

		showNotify("Now open 2 more blocks!\nFollow the arrow and press E (or tap) to open.", 0)

		pointArrowToGrassBlock(function()
			showNotify("Press E on PC or tap the E button on mobile to open the block.", 0)
		end)
	end

	local function startGoToWallStep()
		state.wantWallPurchase = true

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
		state.wantSecondWallPurchase = true

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
		state.wantUpgradeMachine = true

		showNotify("Great! You have enough gems.\nFollow the arrow to the upgrade machine!", 0)
		local mg = getMainGui()
		if mg then
			mg.Enabled = true
		end
		forceEnableUpgradeGui()

		pointArrowToUpgradeMachine(function()
			showNotify("Stand on the glowing area to open the upgrade menu,\nthen buy your first speed upgrade!", 0)
			startUpgradeButtonStep()
		end)
	end

	local function startBarnPhase1()
		state.wantBarnPhase1 = true
		state.barnOpenedPhase1 = 0

		showQuest("Open Barn block (1 time)", state.barnOpenedPhase1, 1)

		showNotify("Nice! Now open the Barn block once.\nFollow the arrow to the Barn block!", 0)

		pointArrowToBarnBlock(function()
			showNotify("Press E on PC or tap the E button on mobile\nto open the Barn block!", 0)
		end)
	end

	local function startBarnPhase2()
		state.wantBarnPhase2 = true
		state.barnOpenedPhase2 = 0

		showQuest("Open Barn block (2 more times)", state.barnOpenedPhase2, 2)

		showNotify("Awesome! Now open the Barn block 2 more times!\nFollow the arrow to the Barn block.", 0)

		pointArrowToBarnBlock(function()
			showNotify("Keep opening the Barn block to complete the quest!", 0)
		end)
	end

	local function startGoToThirdWallStep()
		state.wantThirdWallPurchase = true

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
		state.hoverboardStepActive = true
		state.hoverboardStepDone = false

		showNotify("You received 10,000 Gems!\nFollow the arrow to the hoverboard stand!", 0)

		pointArrowToHoverMesh(function()
			showNotify("Press E on PC or tap the E button on mobile\nto buy your first hoverboard!", 0)
		end)
	end

	local function startQuest1()
		if state.quest1Active or state.quest1Finished then return end
		state.quest1Active = true

		local earned = getEarnedCoins()
		quest1BaseCoins = earned

		showQuest("Farm 150 coins", 0, QUEST1_TARGET)
		onWorld1Changed()
	end

	local function startQuest2()
		if state.quest2Active or state.quest2Finished then return end
		state.quest2Active = true

		local earned = getEarnedCoins()
		quest2BaseCoins = earned

		showQuest("Farm 300 coins", 0, QUEST2_TARGET)
		showNotify("Great! Now farm 300 coins with your NFT!", 4)

		onWorld1Changed()
	end

	local function startQuest3()
		if state.quest3Active or state.quest3Finished then return end
		state.quest3Active = true

		local earned = getEarnedCoins()
		quest3BaseCoins = earned

		showQuest("Farm 500 coins", 0, QUEST3_TARGET)
		showNotify("Farm 500 coins to unlock the next area!", 4)

		onWorld1Changed()
	end

	local function startQuest4()
		if state.quest4Active or state.quest4Finished then return end
		state.quest4Active = true

		local earned = getEarnedCoins()
		quest4BaseCoins = earned

		showQuest("Farm 1000 coins", 0, QUEST4_TARGET)
		showNotify("Use your 2x Coins boost and farm 1000 coins\nto buy the next wall!", 5)

		onWorld1Changed()
	end

	local function startQuest5Gems()
		if state.quest5Active or state.quest5Finished then return end
		state.quest5Active = true

		showQuest("Farm 500 gems", getEarnedGems(), QUEST5_TARGET_GEMS)
		showNotify("Now farm 500 gems to buy your first upgrade!", 4)

		onGemsChanged()
	end

	local function startQuest6()
		if state.quest6Active or state.quest6Finished then return end
		state.quest6Active = true

		local earned = getEarnedCoins()
		quest6BaseCoins = earned

		showQuest("Farm 600 coins", 0, QUEST6_TARGET)
		showNotify("Great! Now farm 600 coins and get ready to open the Barn block!", 4)

		onWorld1Changed()
	end

	local function startQuest7()
		if state.quest7Active or state.quest7Finished then return end
		state.quest7Active = true

		local earned = getEarnedCoins()
		quest7BaseCoins = earned

		showQuest("Farm 1200 coins", 0, QUEST7_TARGET)
		showNotify("Now farm 1200 coins to open the Barn block even more!", 4)

		onWorld1Changed()
	end

	local function startQuest8()
		if state.quest8Active or state.quest8Finished then return end
		state.quest8Active = true

		local earned = getEarnedCoins()
		quest8BaseCoins = earned

		showQuest("Farm 2000 coins", 0, QUEST8_TARGET)
		showNotify("Great! Now farm 2000 coins to unlock the next area!", 4)

		onWorld1Changed()
	end

	startQuest9 = function()
		if state.quest9Active or state.quest9Finished then return end
		state.quest9Active = true

		local earned = getEarnedCoins()
		quest9BaseCoins = earned

		showQuest("Farm 5000 coins", 0, QUEST9_TARGET)
		showNotify("Final step! Farm 5000 coins to unlock the last wall and finish the tutorial!", 4)

		onWorld1Changed()
	end

	onWorld1Changed = function()
		local earned = getEarnedCoins()

		if state.questListening1 and not state.quest1Finished then
			if (not state.firstCoinAcknowledged) and earned > 0 then
				state.firstCoinAcknowledged = true
				destroyArrow()
				showNotify("Nice! Keep farming coins like that!", 0)

				task.delay(5, function()
					if state.quest1Finished then return end
					startQuest1()
				end)
			end
		end

		if state.quest1Active and not state.quest1Finished then
			local cur = delta(earned, quest1BaseCoins)
			showQuest("Farm 150 coins", cur, QUEST1_TARGET)

			if cur >= QUEST1_TARGET then
				state.quest1Active = false
				state.quest1Finished = true
				hideQuest()
				startGoToGrassBlockStep()
				return
			end
		end

		if state.quest2Active and not state.quest2Finished then
			local cur = delta(earned, quest2BaseCoins)
			showQuest("Farm 300 coins", cur, QUEST2_TARGET)

			if cur >= QUEST2_TARGET then
				state.quest2Active = false
				state.quest2Finished = true
				hideQuest()
				startExtraBlocksOpenStep()
				return
			end
		end

		if state.quest3Active and not state.quest3Finished then
			local cur = delta(earned, quest3BaseCoins)
			showQuest("Farm 500 coins", cur, QUEST3_TARGET)

			if cur >= QUEST3_TARGET then
				state.quest3Active = false
				state.quest3Finished = true
				hideQuest()
				startGoToWallStep()
				return
			end
		end

		if state.quest4Active and not state.quest4Finished then
			local cur = delta(earned, quest4BaseCoins)
			showQuest("Farm 1000 coins", cur, QUEST4_TARGET)

			if cur >= QUEST4_TARGET then
				state.quest4Active = false
				state.quest4Finished = true
				hideQuest()
				startGoToSecondWallStep()
				return
			end
		end

		if state.quest6Active and not state.quest6Finished then
			local cur = delta(earned, quest6BaseCoins)
			showQuest("Farm 600 coins", cur, QUEST6_TARGET)

			if cur >= QUEST6_TARGET then
				state.quest6Active = false
				state.quest6Finished = true
				hideQuest()
				startBarnPhase1()
				return
			end
		end

		if state.quest7Active and not state.quest7Finished then
			local cur = delta(earned, quest7BaseCoins)
			showQuest("Farm 1200 coins", cur, QUEST7_TARGET)

			if cur >= QUEST7_TARGET then
				state.quest7Active = false
				state.quest7Finished = true
				hideQuest()
				startBarnPhase2()
				return
			end
		end

		if state.quest8Active and not state.quest8Finished then
			local cur = delta(earned, quest8BaseCoins)
			showQuest("Farm 2000 coins", cur, QUEST8_TARGET)

			if cur >= QUEST8_TARGET then
				state.quest8Active = false
				state.quest8Finished = true
				hideQuest()
				startGoToThirdWallStep()
				return
			end
		end

		if state.quest9Active and not state.quest9Finished then
			local cur = delta(earned, quest9BaseCoins)
			showQuest("Farm 5000 coins", cur, QUEST9_TARGET)

			if cur >= QUEST9_TARGET then
				state.quest9Active = false
				state.quest9Finished = true
				hideQuest()
				startGoToFinalWallStep()
				return
			end
		end
	end

	onGemsChanged = function()
		local earned = getEarnedGems()

		if state.quest5Active and not state.quest5Finished then
			showQuest("Farm 500 gems", earned, QUEST5_TARGET_GEMS)
			if earned >= QUEST5_TARGET_GEMS then
				state.quest5Active = false
				state.quest5Finished = true
				hideQuest()
				startGoToUpgradeMachineStep()
				return
			end
		end
	end

	handleWall1Purchased = function()
		state.wantWallPurchase = false
		destroyArrow()

		showNotify(
			"Awesome! You unlocked the next area!\nYou also received a free 2x Coins boost.",
			0
		)

		if startBoostTutorial then
			startBoostTutorial()
		end
	end

	handleWall2Purchased = function()
		state.wantSecondWallPurchase = false
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
		state.wantThirdWallPurchase = false
		destroyArrow()

		if giveHoverTutorialGems then
			giveHoverTutorialGems()
		end

		showNotify("Awesome! You unlocked a new area\nand received 10,000 Gems!", 5)

		task.delay(5, function()
			startGoToHoverMeshStep()
		end)
	end

	handleFinalWallPurchased = function()
		state.wantFinalWallPurchase = false
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

	local function handleUpdateWalls()
		if state.wantWallPurchase then
			handleWall1Purchased()
			return
		end

		if state.wantSecondWallPurchase then
			handleWall2Purchased()
			return
		end

		if state.wantThirdWallPurchase then
			handleWall3Purchased()
			return
		end

		if state.wantFinalWallPurchase then
			handleFinalWallPurchased()
			return
		end
	end

	local function handleHoverboardPurchased(boardName)
		warn("[Tutorial] HoverboardPurchasedEvent, board =", boardName)

		if not state.hoverboardStepActive then
			return
		end

		completeHoverboardStep(boardName)
	end

	local function startCoinIntro()
		local mg = getMainGui()
		if mg then
			mg.Enabled = true
		end
		tutorialStartCoins = tonumber(world1Currency.Value) or 0
		tutorialStartGems = tonumber(gemsCurrency.Value) or 0

		quest1BaseCoins = tonumber(world1Currency.Value) or 0
		state.questListening1 = true
		state.firstCoinAcknowledged = false
		setQuestProgress(quest1BaseCoins, quest1BaseCoins, QUEST1_TARGET)

		showNotify("Follow the arrow to the coin and click it\nso your NFT starts farming it for you!", 0)

		pointArrowToFirstCoin(function()
			showNotify("Great! Now click the coin to collect your first coins!", 0)
		end)
	end

	initQuestUi()

	return {
		state = state,
		startQuest1 = startQuest1,
		startQuest2 = startQuest2,
		startQuest3 = startQuest3,
		startQuest4 = startQuest4,
		startQuest5Gems = startQuest5Gems,
		startQuest6 = startQuest6,
		startQuest7 = startQuest7,
		startQuest8 = startQuest8,
		startQuest9 = startQuest9,
		setQuestProgress = setQuestProgress,
		onWorld1Changed = onWorld1Changed,
		onGemsChanged = onGemsChanged,
		handleUpdateWalls = handleUpdateWalls,
		handleHoverboardPurchased = handleHoverboardPurchased,
		initializeProgress = function()
			quest1BaseCoins = tonumber(world1Currency.Value) or 0
			setQuestProgress(quest1BaseCoins, quest1BaseCoins, QUEST1_TARGET)
		end,
		startCoinIntro = startCoinIntro,
		startGoToGrassBlockStep = startGoToGrassBlockStep,
		startExtraBlocksOpenStep = startExtraBlocksOpenStep,
		startBarnPhase1 = startBarnPhase1,
		startBarnPhase2 = startBarnPhase2,
		startGoToThirdWallStep = startGoToThirdWallStep,
	}
end

return TutorialQuests
