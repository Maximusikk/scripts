local GuiArrowHelpers = {}

function GuiArrowHelpers.createGuiArrowLabel(tutorialGui: ScreenGui, name: string, z: number): TextLabel
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

function GuiArrowHelpers.followGuiObject(
	runService: RunService,
	label: TextLabel,
	target: GuiObject,
	yOffset: number?,
	bobSpeed: number?,
	bobAmp: number?
)
	local startTime = tick()
	return runService.RenderStepped:Connect(function()
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

return GuiArrowHelpers
