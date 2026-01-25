local RunService = game:GetService("RunService")

local UiHelpers = {}

function UiHelpers.new(params)
	local tutorialGui = assert(params.tutorialGui, "tutorialGui is required")
	local playerGui = assert(params.playerGui, "playerGui is required")
	local mainGui = params.mainGui
	local notifyLabel = assert(params.notifyLabel, "notifyLabel is required")

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

	return {
		showNotify = showNotify,
		getMainGui = getMainGui,
		findOpenInventoryMain = findOpenInventoryMain,
		findInventoryContainer = findInventoryContainer,
		createGuiArrowLabel = createGuiArrowLabel,
		followGuiObject = followGuiObject,
	}
end

return UiHelpers
