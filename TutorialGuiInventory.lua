local function createTutorialGuiInventory(context)
	local playerGui = context.playerGui
	local inventoryFolder = context.inventoryFolder
	local getMainGui = context.getMainGui
	local findOpenInventoryMain = context.findOpenInventoryMain
	local showNotify = context.showNotify
	local arrows = context.arrows

	local startQuest2Fn = context.startQuest2 or function() end

	local inventoryStepActive = false
	local inventoryStepDone = false
	local inventoryArrowGui: TextLabel? = nil
	local inventoryArrowConn: RBXScriptConnection? = nil
	local inventoryBtnConn: RBXScriptConnection? = nil

	local nftClickStepActive = false
	local nftClickStepDone = false
	local nftArrowGui: TextLabel? = nil
	local nftArrowConn: RBXScriptConnection? = nil
	local nftSlotConn: RBXScriptConnection? = nil

	local firstNftUuid: string? = nil

	local equipBestStepActive = false
	local equipBestStepDone = false

	local equipBestArrowGui: TextLabel? = nil
	local equipBestArrowConn: RBXScriptConnection? = nil
	local equipBestBtnConn: RBXScriptConnection? = nil

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

		local grid: Frame? = nil
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
		nftClickStepDone = true
		nftClickStepActive = false
		cleanupNftArrow()

		showNotify("Great! Your NFT is equipped.\nNow close the inventory.", 0)

		local mg = getMainGui()
		if not mg then
			startQuest2Fn()
			return
		end

		local invFrame = mg:FindFirstChild("InventoryFrame")
		if not invFrame or not invFrame:IsA("Frame") then
			startQuest2Fn()
			return
		end

		if not invFrame.Visible then
			startQuest2Fn()
			return
		end

		local conn
		conn = invFrame:GetPropertyChangedSignal("Visible"):Connect(function()
			if not invFrame.Visible then
				conn:Disconnect()
				startQuest2Fn()
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
		nftArrowGui = arrows.createGuiArrowLabel("NftArrowHint", 60)
		nftArrowConn = arrows.followGuiObject(nftArrowGui, clickArea, -10, 4, 6)

		nftSlotConn = clickArea.MouseButton1Click:Connect(function()
			if nftClickStepActive then
				completeNftClickStep()
			end
		end)
	end

	local function completeInventoryStep()
		if inventoryStepDone then return end
		inventoryStepDone = true
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
		inventoryArrowGui = arrows.createGuiArrowLabel("InventoryArrowHint", 50)
		inventoryArrowConn = arrows.followGuiObject(inventoryArrowGui, inventoryBtn, -10, 4, 6)

		inventoryBtnConn = inventoryBtn.MouseButton1Click:Connect(function()
			if inventoryStepActive then
				completeInventoryStep()
			end
		end)
	end

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

	local function isInventoryOpen()
		local invFrame = findOpenInventoryMain()
		return invFrame ~= nil
	end

	local function startEquipBestStep(onDone)
		if equipBestStepDone then
			if onDone then onDone() end
			return
		end
		equipBestStepActive = true

		local localInvArrowGui: TextLabel?
		local localInvArrowConn: RBXScriptConnection?
		local localInvBtnConn: RBXScriptConnection?

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
			equipBestArrowGui = arrows.createGuiArrowLabel("EquipBestArrowHint", 95)
			equipBestArrowConn = arrows.followGuiObject(equipBestArrowGui, btn, -10, 4, 6)
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

		if isInventoryOpen() then
			attachEquipBestButton()
			return
		end

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
		localInvArrowGui = arrows.createGuiArrowLabel("EquipBest_InvArrow", 90)
		localInvArrowConn = arrows.followGuiObject(localInvArrowGui, inventoryBtn, -10, 4, 6)

		localInvBtnConn = inventoryBtn.MouseButton1Click:Connect(function()
			cleanupLocalInventoryArrow()
			task.delay(0.2, function()
				if equipBestStepActive then
					attachEquipBestButton()
				end
			end)
		end)
	end

	local equipReminderActive = false
	local equipReminderCooldownUntil = 0

	local function showEquipReminderForUuid(uuid: string?)
		if tick() < equipReminderCooldownUntil then return end
		equipReminderCooldownUntil = tick() + 6

		if equipReminderActive then return end
		equipReminderActive = true

		if nftClickStepActive or inventoryStepActive then
			equipReminderActive = false
			return
		end

		cleanupInventoryArrow()
		cleanupNftArrow()

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

		inventoryArrowGui = arrows.createGuiArrowLabel("EquipInventoryArrowHint", 70)
		inventoryArrowConn = arrows.followGuiObject(inventoryArrowGui, inventoryBtn, -10, 4, 6)

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

				nftArrowGui = arrows.createGuiArrowLabel("EquipNftArrowHint", 70)
				nftArrowConn = arrows.followGuiObject(nftArrowGui, clickArea, -10, 4, 6)

				if nftSlotConn then nftSlotConn:Disconnect() end
				nftSlotConn = clickArea.MouseButton1Click:Connect(function()
					cleanupNftArrow()
					showNotify("Nice! If it's stronger — keep it equipped.\nClose Inventory and continue!", 3)
					equipReminderActive = false
				end)

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

	return {
		setStartQuest2 = function(fn)
			startQuest2Fn = fn
		end,
		setFirstNftUuid = function(uuid)
			firstNftUuid = uuid
		end,
		showInventoryHint = showInventoryHint,
		startEquipBestStep = startEquipBestStep,
		showEquipReminderForUuid = showEquipReminderForUuid,
		isInventoryStepDone = function()
			return inventoryStepDone
		end,
		isNftClickStepDone = function()
			return nftClickStepDone
		end,
		isInventoryStepActive = function()
			return inventoryStepActive
		end,
		isNftClickStepActive = function()
			return nftClickStepActive
		end,
		isEquipBestStepActive = function()
			return equipBestStepActive
		end,
		setEquipReminderCooldown = function(untilTime)
			equipReminderCooldownUntil = untilTime
		end,
		resetEquipReminder = function()
			equipReminderActive = false
		end,
	}
end

return createTutorialGuiInventory
