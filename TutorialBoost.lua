local TutorialBoost = {}

function TutorialBoost.new(ctx)
	local showNotify = assert(ctx.showNotify, "showNotify is required")
	local getMainGui = assert(ctx.getMainGui, "getMainGui is required")
	local findInventoryContainer = assert(ctx.findInventoryContainer, "findInventoryContainer is required")
	local createGuiArrowLabel = assert(ctx.createGuiArrowLabel, "createGuiArrowLabel is required")
	local followGuiObject = assert(ctx.followGuiObject, "followGuiObject is required")
	local activeBoostsFolder = assert(ctx.activeBoostsFolder, "activeBoostsFolder is required")
	local RunService = assert(ctx.runService, "runService is required")
	local onBoostActivated = ctx.onBoostActivated
	local tutorialGui = ctx.tutorialGui

	local boostTutorialActive = false
	local boostArrowGui: TextLabel? = nil
	local boostArrowConn: RBXScriptConnection? = nil
	local boostBtnConn: RBXScriptConnection? = nil

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

	local showBoostSelectTabStep

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

		local boostBtn: GuiButton? = boostsScroll:FindFirstChild("2xCoinsBtn", true)
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

					if onBoostActivated then
						onBoostActivated()
					end
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

	return {
		startBoostTutorial = startBoostTutorial,
	}
end

return TutorialBoost
