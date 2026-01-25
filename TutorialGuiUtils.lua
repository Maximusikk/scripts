local GuiUtils = {}

function GuiUtils.new(params)
	local tutorialGui = params.tutorialGui
	local playerGui = params.playerGui
	local RunService = params.RunService

	local notifyLabel = tutorialGui:WaitForChild("NotifyText")
	local mainGui: ScreenGui? = playerGui:FindFirstChild("MainGui") :: ScreenGui?
	local lastNotifyId = 0

	local questFrame: Frame? = nil
	local progressFill: Frame? = nil
	local progressText: TextLabel? = nil
	local questText: TextLabel? = nil

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

	local function hideNotify()
		showNotify(nil)
	end

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

			local absPos = target.AbsolutePosition
			local absSize = target.AbsoluteSize

			local centerX = absPos.X + absSize.X / 2
			local topY = absPos.Y

			local t = tick() - startTime
			local bob = math.sin(t * (bobSpeed or 4)) * (bobAmp or 6)

			label.Position = UDim2.fromOffset(centerX, topY + (yOffset or -10) + bob)
		end)
	end

	local function ensureQuestUi(): boolean
		if questFrame and questFrame.Parent then
			return true
		end

		questFrame = tutorialGui:FindFirstChild("Quest1Frame")
		if not (questFrame and questFrame:IsA("Frame")) then
			warn("[Tutorial] Quest1Frame not found")
			return false
		end

		local progressBar = questFrame:FindFirstChild("ProgressBar")
		if not (progressBar and progressBar:IsA("Frame")) then
			warn("[Tutorial] ProgressBar not found in Quest1Frame")
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

		local cur = math.clamp(current, 0, target)
		local ratio = (target > 0) and (cur / target) or 0

		questText.Text = text
		progressText.Text = string.format("%d/%d", cur, target)
		progressFill.Size = UDim2.new(ratio, 0, 1, 0)
		questFrame.Visible = true
	end

	local function hideQuest()
		if not ensureQuestUi() then return end
		questFrame.Visible = false
	end

	local function setQuestVisible(visible: boolean)
		if not ensureQuestUi() then return end
		questFrame.Visible = visible
	end

	local function setQuestProgress(rawValue: number, base: number, target: number)
		if not ensureQuestUi() then return end

		base = base or 0
		target = target or 1

		local delta = math.max(0, math.floor((rawValue or 0) - base))
		local current = math.clamp(delta, 0, target)
		local ratio = (target > 0) and (current / target) or 0

		progressText.Text = string.format("%d/%d", current, target)
		progressFill.Size = UDim2.new(ratio, 0, 1, 0)
	end

	return {
		showNotify = showNotify,
		hideNotify = hideNotify,
		getMainGui = getMainGui,
		findOpenInventoryMain = findOpenInventoryMain,
		findInventoryContainer = findInventoryContainer,
		createGuiArrowLabel = createGuiArrowLabel,
		followGuiObject = followGuiObject,
		ensureQuestUi = ensureQuestUi,
		showQuest = showQuest,
		hideQuest = hideQuest,
		setQuestProgress = setQuestProgress,
		setQuestVisible = setQuestVisible,
	}
end

return GuiUtils
