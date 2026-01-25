local WorldArrows = {}

function WorldArrows.new(params)
	local player = assert(params.player, "player is required")
	local worldRoot = assert(params.worldRoot, "worldRoot is required")
	local replicatedStorage = assert(params.replicatedStorage, "replicatedStorage is required")
	local workspace = assert(params.workspace, "workspace is required")
	local runService = assert(params.runService, "runService is required")
	local arrowRotOffset = params.arrowRotOffset or CFrame.Angles(math.rad(-90), 0, 0)

	local arrowPart: BasePart? = nil
	local arrowToken = 0

	local function destroyArrow()
		arrowToken += 1
		if arrowPart then
			arrowPart:Destroy()
			arrowPart = nil
		end
	end

	local function pointArrowToFinalWall(onReachedWall)
		destroyArrow()
		local myToken = arrowToken

		local character = player.Character or player.CharacterAdded:Wait()
		character:WaitForChild("HumanoidRootPart")

		local wallFolder: Instance? = worldRoot:FindFirstChild("Location4Wall")
		if not wallFolder then
			for _, obj in ipairs(worldRoot:GetChildren()) do
				if obj.Name:lower():find("location4") and obj.Name:lower():find("wall") then
					wallFolder = obj
					break
				end
			end
		end

		if not wallFolder then
			warn("[Tutorial] Location4Wall folder not found in PixelWorld1")
			return
		end

		local wallPartLocal: BasePart? = wallFolder:FindFirstChild("Location4Wall")
		if not (wallPartLocal and wallPartLocal:IsA("BasePart")) then
			for _, obj in ipairs(wallFolder:GetDescendants()) do
				if obj:IsA("BasePart") then
					wallPartLocal = obj
					break
				end
			end
		end
		if not wallPartLocal then
			warn("[Tutorial] No wall BasePart found inside Location4Wall")
			return
		end

		local targetPos = wallPartLocal.Position

		local arrowTemplate = replicatedStorage:WaitForChild("TutorialArrow")
		local arrow = arrowTemplate:Clone()
		arrow.Name = "TutorialArrowRuntime_WallFinal"
		arrow.Anchored = true
		arrow.CanCollide = false
		arrow.Parent = workspace
		arrowPart = arrow

		local sizeNearPlayer = arrow.Size
		local sizeOnWall = sizeNearPlayer * 1.7

		local reachedWall = false
		local wallOffsetY = 7
		local playerOffsetY = 4
		local reachDistance = 12
		local startTime = tick()

		task.spawn(function()
			while arrowPart and arrowPart.Parent and wallPartLocal.Parent and myToken == arrowToken do
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if not hrp then break end

				local hrpPos = hrp.Position
				targetPos = wallPartLocal.Position

				if not reachedWall then
					if arrowPart.Size ~= sizeNearPlayer then
						arrowPart.Size = sizeNearPlayer
					end

					local flatTarget = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)
					local arrowPos = hrpPos + Vector3.new(0, playerOffsetY, 0)
					arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * arrowRotOffset

					local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) - Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude
					if flatDist <= reachDistance then
						reachedWall = true
						startTime = tick()
						if onReachedWall then
							task.spawn(onReachedWall)
						end
					end
				else
					if arrowPart.Size ~= sizeOnWall then
						arrowPart.Size = sizeOnWall
					end

					local t = tick() - startTime
					local yOffset = wallOffsetY + math.sin(t * 2) * 0.5
					local pos = targetPos + Vector3.new(0, yOffset, 0)
					arrowPart.CFrame = CFrame.new(pos, targetPos) * arrowRotOffset
				end

				runService.RenderStepped:Wait()
			end
		end)
	end

	local function pointArrowToFirstGems_Location3(onReachedGems)
		destroyArrow()
		local myToken = arrowToken

		local character = player.Character or player.CharacterAdded:Wait()
		local root = character:WaitForChild("HumanoidRootPart")

		local thirdLocation: Instance? = nil
		for _, obj in ipairs(worldRoot:GetDescendants()) do
			if obj:IsA("IntValue") and obj.Name == "LevelOfFolder" and obj.Value == 3 then
				thirdLocation = obj.Parent
				break
			end
		end
		if not thirdLocation then
			warn("[Tutorial] LevelOfFolder == 3 not found inside PixelWorld1")
			return
		end

		local targetPos: Vector3? = nil
		local nearestDist = math.huge

		for _, obj in ipairs(thirdLocation:GetDescendants()) do
			if obj:IsA("BasePart") then
				local parent = obj.Parent
				if (parent and parent.Name == "GemsModel1") or obj.Name == "GemsModel1" then
					local dist = (obj.Position - root.Position).Magnitude
					if dist < nearestDist then
						nearestDist = dist
						targetPos = obj.Position
					end
				end
			end
		end

		if not targetPos then
			warn("[Tutorial] No GemsModel1 BasePart found in location 3")
			return
		end

		local arrowTemplate = replicatedStorage:FindFirstChild("TutorialArrow")
		if not arrowTemplate or not arrowTemplate:IsA("BasePart") then
			warn("[Tutorial] TutorialArrow (BasePart) not found in ReplicatedStorage")
			return
		end

		local arrow = arrowTemplate:Clone()
		arrow.Name = "TutorialArrowRuntime_Gems3"
		arrow.Anchored = true
		arrow.CanCollide = false
		arrow.Parent = workspace
		arrowPart = arrow

		local sizeNearPlayer = arrow.Size
		local sizeOnGems = sizeNearPlayer * 1.7

		local reachedGems = false
		local gemsOffsetY = 4
		local playerOffsetY = 4
		local reachDistance = 12
		local startTime = tick()

		task.spawn(function()
			while arrowPart and arrowPart.Parent and myToken == arrowToken do
				if not character.Parent then break end
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if not hrp then break end

				local hrpPos = hrp.Position

				if not reachedGems then
					if arrowPart.Size ~= sizeNearPlayer then
						arrowPart.Size = sizeNearPlayer
					end

					local flatTarget = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)
					local arrowPos = hrpPos + Vector3.new(0, playerOffsetY, 0)
					arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * arrowRotOffset

					local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) - Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude

					if flatDist <= reachDistance then
						reachedGems = true
						startTime = tick()
						if onReachedGems then
							task.spawn(onReachedGems)
						end
					end
				else
					if arrowPart.Size ~= sizeOnGems then
						arrowPart.Size = sizeOnGems
					end

					local t = tick() - startTime
					local yOffset = gemsOffsetY + math.sin(t * 2) * 0.5
					local pos = targetPos + Vector3.new(0, yOffset, 0)
					arrowPart.CFrame = CFrame.new(pos, targetPos) * arrowRotOffset
				end

				runService.RenderStepped:Wait()
			end
		end)
	end

	local function pointArrowToFirstCoin(onReachedCoin)
		destroyArrow()
		local myToken = arrowToken

		local character = player.Character or player.CharacterAdded:Wait()
		local root = character:WaitForChild("HumanoidRootPart")

		local targetPos: Vector3? = nil
		local nearestDist = math.huge

		local firstLocation: Instance? = nil
		for _, obj in ipairs(worldRoot:GetDescendants()) do
			if obj:IsA("IntValue") and obj.Name == "LevelOfFolder" and obj.Value == 1 then
				firstLocation = obj.Parent
				break
			end
		end

		if firstLocation then
			for _, obj in ipairs(firstLocation:GetDescendants()) do
				if obj:IsA("BasePart") then
					local parent = obj.Parent
					if (parent and parent.Name == "CoinsModel1") or obj.Name == "CoinsModel1" then
						local dist = (obj.Position - root.Position).Magnitude
						if dist < nearestDist then
							nearestDist = dist
							targetPos = obj.Position
						end
					end
				end
			end
		end

		if not targetPos then
			for _, obj in ipairs(worldRoot:GetDescendants()) do
				if obj:IsA("BasePart") and obj.Name == "Coin1" then
					local dist = (obj.Position - root.Position).Magnitude
					if dist < nearestDist then
						nearestDist = dist
						targetPos = obj.Position
					end
				end
			end
		end

		if not targetPos then
			warn("[Tutorial] No CoinsModel1 BasePart found in first location")
			return
		end

		local arrowTemplate = replicatedStorage:FindFirstChild("TutorialArrow")
		if not arrowTemplate or not arrowTemplate:IsA("BasePart") then
			warn("[Tutorial] TutorialArrow (BasePart) not found in ReplicatedStorage")
			return
		end

		local arrow = arrowTemplate:Clone()
		arrow.Name = "TutorialArrowRuntime_Coin1"
		arrow.Anchored = true
		arrow.CanCollide = false
		arrow.Parent = workspace
		arrowPart = arrow

		local sizeNearPlayer = arrow.Size
		local sizeOnCoin = sizeNearPlayer * 1.7

		local reachedCoin = false
		local coinOffsetY = 3
		local playerOffsetY = 4
		local reachDistance = 12
		local startTime = tick()

		task.spawn(function()
			while arrowPart and arrowPart.Parent and myToken == arrowToken do
				if not character.Parent then break end
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if not hrp then break end

				local hrpPos = hrp.Position

				if not reachedCoin then
					if arrowPart.Size ~= sizeNearPlayer then
						arrowPart.Size = sizeNearPlayer
					end

					local flatTarget = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)
					local arrowPos = hrpPos + Vector3.new(0, playerOffsetY, 0)
					arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * arrowRotOffset

					local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) - Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude

					if flatDist <= reachDistance then
						reachedCoin = true
						startTime = tick()
						if onReachedCoin then
							task.spawn(onReachedCoin)
						end
					end
				else
					if arrowPart.Size ~= sizeOnCoin then
						arrowPart.Size = sizeOnCoin
					end

					local t = tick() - startTime
					local yOffset = coinOffsetY + math.sin(t * 2) * 0.5
					local pos = targetPos + Vector3.new(0, yOffset, 0)
					arrowPart.CFrame = CFrame.new(pos, targetPos) * arrowRotOffset
				end

				runService.RenderStepped:Wait()
			end
		end)
	end

	local function pointArrowToGrassBlock(onReachedBlock)
		destroyArrow()
		local myToken = arrowToken

		local character = player.Character or player.CharacterAdded:Wait()
		local root = character:WaitForChild("HumanoidRootPart")

		local blocksFolder = worldRoot:WaitForChild("BlocksLocation1")
		local targetBlock: BasePart? = nil
		local nearestDist = math.huge

		for _, obj in ipairs(blocksFolder:GetDescendants()) do
			if obj:IsA("BasePart") then
				if obj.Parent and obj.Parent.Name == "GrassBlock" then
					local dist = (obj.Position - root.Position).Magnitude
					if dist < nearestDist then
						nearestDist = dist
						targetBlock = obj
					end
				end
			end
		end

		if not targetBlock then
			warn("[Tutorial] No GrassBlock found in BlocksLocation1")
			return
		end

		local arrowTemplate = replicatedStorage:FindFirstChild("TutorialArrow")
		if not arrowTemplate or not arrowTemplate:IsA("BasePart") then
			warn("[Tutorial] TutorialArrow (BasePart) not found in ReplicatedStorage")
			return
		end

		local arrow = arrowTemplate:Clone()
		arrow.Name = "TutorialArrowRuntime_GrassBlock"
		arrow.Anchored = true
		arrow.CanCollide = false
		arrow.Parent = workspace
		arrowPart = arrow

		local sizeNearPlayer = arrow.Size
		local sizeOnBlock = sizeNearPlayer * 1.7

		local reachedBlock = false
		local blockOffsetY = 5
		local playerOffsetY = 4
		local reachDistance = 12
		local startTime = tick()

		task.spawn(function()
			while arrowPart and arrowPart.Parent and myToken == arrowToken do
				if not character.Parent then break end
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if not hrp then break end

				local hrpPos = hrp.Position

				if not reachedBlock then
					if arrowPart.Size ~= sizeNearPlayer then
						arrowPart.Size = sizeNearPlayer
					end

					local flatTarget = Vector3.new(targetBlock.Position.X, hrpPos.Y, targetBlock.Position.Z)
					local arrowPos = hrpPos + Vector3.new(0, playerOffsetY, 0)
					arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * arrowRotOffset

					local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) - Vector3.new(targetBlock.Position.X, 0, targetBlock.Position.Z)).Magnitude

					if flatDist <= reachDistance then
						reachedBlock = true
						startTime = tick()
						if onReachedBlock then
							task.spawn(onReachedBlock)
						end
					end
				else
					if arrowPart.Size ~= sizeOnBlock then
						arrowPart.Size = sizeOnBlock
					end

					local t = tick() - startTime
					local yOffset = blockOffsetY + math.sin(t * 2) * 0.5
					local pos = targetBlock.Position + Vector3.new(0, yOffset, 0)
					arrowPart.CFrame = CFrame.new(pos, targetBlock.Position) * arrowRotOffset
				end

				runService.RenderStepped:Wait()
			end
		end)
	end

	local function pointArrowToWall(onReachedWall)
		destroyArrow()
		local myToken = arrowToken

		local character = player.Character or player.CharacterAdded:Wait()
		character:WaitForChild("HumanoidRootPart")

		local wallFolder = worldRoot:WaitForChild("Location1Wall")
		local wallPartLocal: BasePart? = wallFolder:FindFirstChild("Location1Wall")
		if not (wallPartLocal and wallPartLocal:IsA("BasePart")) then
			for _, obj in ipairs(wallFolder:GetDescendants()) do
				if obj:IsA("BasePart") then
					wallPartLocal = obj
					break
				end
			end
		end

		if not wallPartLocal then
			warn("[Tutorial] No BasePart found in Location1Wall")
			return
		end

		local targetPos = wallPartLocal.Position

		local arrowTemplate = replicatedStorage:WaitForChild("TutorialArrow")
		local arrow = arrowTemplate:Clone()
		arrow.Name = "TutorialArrowRuntime_Wall1"
		arrow.Anchored = true
		arrow.CanCollide = false
		arrow.Parent = workspace
		arrowPart = arrow

		local sizeNearPlayer = arrow.Size
		local sizeOnWall = sizeNearPlayer * 1.7

		local reachedWall = false
		local wallOffsetY = 7
		local playerOffsetY = 4
		local reachDistance = 12
		local startTime = tick()

		task.spawn(function()
			while arrowPart and arrowPart.Parent and wallPartLocal.Parent and myToken == arrowToken do
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if not hrp then break end

				local hrpPos = hrp.Position
				targetPos = wallPartLocal.Position

				if not reachedWall then
					if arrowPart.Size ~= sizeNearPlayer then
						arrowPart.Size = sizeNearPlayer
					end

					local flatTarget = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)
					local arrowPos = hrpPos + Vector3.new(0, playerOffsetY, 0)
					arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * arrowRotOffset

					local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) - Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude

					if flatDist <= reachDistance then
						reachedWall = true
						startTime = tick()
						if onReachedWall then
							task.spawn(onReachedWall)
						end
					end
				else
					if arrowPart.Size ~= sizeOnWall then
						arrowPart.Size = sizeOnWall
					end

					local t = tick() - startTime
					local yOffset = wallOffsetY + math.sin(t * 2) * 0.5
					local pos = targetPos + Vector3.new(0, yOffset, 0)
					arrowPart.CFrame = CFrame.new(pos, targetPos) * arrowRotOffset
				end

				runService.RenderStepped:Wait()
			end
		end)
	end

	local function pointArrowToSecondWall(onReachedWall)
		destroyArrow()
		local myToken = arrowToken

		local character = player.Character or player.CharacterAdded:Wait()
		character:WaitForChild("HumanoidRootPart")

		local wallFolder = worldRoot:WaitForChild("Location2Wall")
		local wallPartLocal: BasePart? = wallFolder:FindFirstChild("Location2Wall")
		if not (wallPartLocal and wallPartLocal:IsA("BasePart")) then
			for _, obj in ipairs(wallFolder:GetDescendants()) do
				if obj:IsA("BasePart") then
					wallPartLocal = obj
					break
				end
			end
		end

		if not wallPartLocal then
			warn("[Tutorial] No BasePart found in Location2Wall")
			return
		end

		local targetPos = wallPartLocal.Position

		local arrowTemplate = replicatedStorage:WaitForChild("TutorialArrow")
		local arrow = arrowTemplate:Clone()
		arrow.Name = "TutorialArrowRuntime_Wall2"
		arrow.Anchored = true
		arrow.CanCollide = false
		arrow.Parent = workspace
		arrowPart = arrow

		local sizeNearPlayer = arrow.Size
		local sizeOnWall = sizeNearPlayer * 1.7

		local reachedWall = false
		local wallOffsetY = 7
		local playerOffsetY = 4
		local reachDistance = 12
		local startTime = tick()

		task.spawn(function()
			while arrowPart and arrowPart.Parent and wallPartLocal.Parent and myToken == arrowToken do
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if not hrp then break end

				local hrpPos = hrp.Position
				targetPos = wallPartLocal.Position

				if not reachedWall then
					if arrowPart.Size ~= sizeNearPlayer then
						arrowPart.Size = sizeNearPlayer
					end

					local flatTarget = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)
					local arrowPos = hrpPos + Vector3.new(0, playerOffsetY, 0)
					arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * arrowRotOffset

					local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) - Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude

					if flatDist <= reachDistance then
						reachedWall = true
						startTime = tick()
						if onReachedWall then
							task.spawn(onReachedWall)
						end
					end
				else
					if arrowPart.Size ~= sizeOnWall then
						arrowPart.Size = sizeOnWall
					end

					local t = tick() - startTime
					local yOffset = wallOffsetY + math.sin(t * 2) * 0.5
					local pos = targetPos + Vector3.new(0, yOffset, 0)
					arrowPart.CFrame = CFrame.new(pos, targetPos) * arrowRotOffset
				end

				runService.RenderStepped:Wait()
			end
		end)
	end

	local function pointArrowToUpgradeMachine(onReached)
		destroyArrow()
		local myToken = arrowToken

		local character = player.Character or player.CharacterAdded:Wait()
		character:WaitForChild("HumanoidRootPart")

		local machine = worldRoot:WaitForChild("UpgradeMachine")
		local machinePart: BasePart? = nil

		if machine:IsA("BasePart") then
			machinePart = machine
		else
			for _, obj in ipairs(machine:GetDescendants()) do
				if obj:IsA("BasePart") then
					machinePart = obj
					break
				end
			end
		end

		if not machinePart then
			warn("[Tutorial] UpgradeMachine BasePart not found")
			return
		end

		local targetPos = machinePart.Position

		local arrowTemplate = replicatedStorage:WaitForChild("TutorialArrow")
		local arrow = arrowTemplate:Clone()
		arrow.Name = "TutorialArrowRuntime_UpgradeMachine"
		arrow.Anchored = true
		arrow.CanCollide = false
		arrow.Parent = workspace
		arrowPart = arrow

		local sizeNearPlayer = arrow.Size
		local sizeOnMachine = sizeNearPlayer * 1.7

		local reachedMachine = false
		local machineOffsetY = 5
		local playerOffsetY = 4
		local reachDistance = 12
		local startTime = tick()

		task.spawn(function()
			while arrowPart and arrowPart.Parent and machinePart.Parent and myToken == arrowToken do
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if not hrp then break end

				local hrpPos = hrp.Position
				targetPos = machinePart.Position

				if not reachedMachine then
					if arrowPart.Size ~= sizeNearPlayer then
						arrowPart.Size = sizeNearPlayer
					end

					local flatTarget = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)
					local arrowPos = hrpPos + Vector3.new(0, playerOffsetY, 0)
					arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * arrowRotOffset

					local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) - Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude

					if flatDist <= reachDistance then
						reachedMachine = true
						startTime = tick()
						if onReached then
							task.spawn(onReached)
						end
					end
				else
					if arrowPart.Size ~= sizeOnMachine then
						arrowPart.Size = sizeOnMachine
					end

					local t = tick() - startTime
					local yOffset = machineOffsetY + math.sin(t * 2) * 0.5
					local pos = targetPos + Vector3.new(0, yOffset, 0)
					arrowPart.CFrame = CFrame.new(pos, targetPos) * arrowRotOffset
				end

				runService.RenderStepped:Wait()
			end
		end)
	end

	local function pointArrowToBarnBlock(onReachedBlock)
		destroyArrow()
		local myToken = arrowToken

		local character = player.Character or player.CharacterAdded:Wait()
		local root = character:WaitForChild("HumanoidRootPart")

		local blocks = worldRoot:WaitForChild("BlocksLocation1")
		local targetBlock: BasePart? = nil
		local nearestDist = math.huge

		for _, obj in ipairs(blocks:GetDescendants()) do
			if obj:IsA("BasePart") then
				if obj.Parent and obj.Parent.Name == "BarnBlock" then
					local dist = (obj.Position - root.Position).Magnitude
					if dist < nearestDist then
						nearestDist = dist
						targetBlock = obj
					end
				end
			end
		end

		if not targetBlock then
			warn("[Tutorial] No BarnBlock found in BlocksLocation1")
			return
		end

		local arrowTemplate = replicatedStorage:FindFirstChild("TutorialArrow")
		if not arrowTemplate or not arrowTemplate:IsA("BasePart") then
			warn("[Tutorial] TutorialArrow (BasePart) not found in ReplicatedStorage")
			return
		end

		local arrow = arrowTemplate:Clone()
		arrow.Name = "TutorialArrowRuntime_BarnBlock"
		arrow.Anchored = true
		arrow.CanCollide = false
		arrow.Parent = workspace
		arrowPart = arrow

		local sizeNearPlayer = arrow.Size
		local sizeOnBlock = sizeNearPlayer * 1.7

		local reachedBlock = false
		local blockOffsetY = 5
		local playerOffsetY = 4
		local reachDistance = 12
		local startTime = tick()

		task.spawn(function()
			while arrowPart and arrowPart.Parent and myToken == arrowToken do
				if not character.Parent then break end
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if not hrp then break end

				local hrpPos = hrp.Position

				if not reachedBlock then
					if arrowPart.Size ~= sizeNearPlayer then
						arrowPart.Size = sizeNearPlayer
					end

					local flatTarget = Vector3.new(targetBlock.Position.X, hrpPos.Y, targetBlock.Position.Z)
					local arrowPos = hrpPos + Vector3.new(0, playerOffsetY, 0)
					arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * arrowRotOffset

					local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) - Vector3.new(targetBlock.Position.X, 0, targetBlock.Position.Z)).Magnitude

					if flatDist <= reachDistance then
						reachedBlock = true
						startTime = tick()
						if onReachedBlock then
							task.spawn(onReachedBlock)
						end
					end
				else
					if arrowPart.Size ~= sizeOnBlock then
						arrowPart.Size = sizeOnBlock
					end

					local t = tick() - startTime
					local yOffset = blockOffsetY + math.sin(t * 2) * 0.5
					local pos = targetBlock.Position + Vector3.new(0, yOffset, 0)
					arrowPart.CFrame = CFrame.new(pos, targetBlock.Position) * arrowRotOffset
				end

				runService.RenderStepped:Wait()
			end
		end)
	end

	local function pointArrowToThirdWall(onReachedWall)
		destroyArrow()
		local myToken = arrowToken

		local character = player.Character or player.CharacterAdded:Wait()
		character:WaitForChild("HumanoidRootPart")

		local wallFolder = worldRoot:WaitForChild("Location3Wall")
		local wallPartLocal: BasePart? = wallFolder:FindFirstChild("Location3Wall")
		if not (wallPartLocal and wallPartLocal:IsA("BasePart")) then
			for _, obj in ipairs(wallFolder:GetDescendants()) do
				if obj:IsA("BasePart") then
					wallPartLocal = obj
					break
				end
			end
		end

		if not wallPartLocal then
			warn("[Tutorial] No BasePart found in Location3Wall")
			return
		end

		local targetPos = wallPartLocal.Position

		local arrowTemplate = replicatedStorage:WaitForChild("TutorialArrow")
		local arrow = arrowTemplate:Clone()
		arrow.Name = "TutorialArrowRuntime_Wall3"
		arrow.Anchored = true
		arrow.CanCollide = false
		arrow.Parent = workspace
		arrowPart = arrow

		local sizeNearPlayer = arrow.Size
		local sizeOnWall = sizeNearPlayer * 1.7

		local reachedWall = false
		local wallOffsetY = 7
		local playerOffsetY = 4
		local reachDistance = 12
		local startTime = tick()

		task.spawn(function()
			while arrowPart and arrowPart.Parent and wallPartLocal.Parent and myToken == arrowToken do
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if not hrp then break end

				local hrpPos = hrp.Position
				targetPos = wallPartLocal.Position

				if not reachedWall then
					if arrowPart.Size ~= sizeNearPlayer then
						arrowPart.Size = sizeNearPlayer
					end

					local flatTarget = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)
					local arrowPos = hrpPos + Vector3.new(0, playerOffsetY, 0)
					arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * arrowRotOffset

					local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) - Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude

					if flatDist <= reachDistance then
						reachedWall = true
						startTime = tick()
						if onReachedWall then
							task.spawn(onReachedWall)
						end
					end
				else
					if arrowPart.Size ~= sizeOnWall then
						arrowPart.Size = sizeOnWall
					end

					local t = tick() - startTime
					local yOffset = wallOffsetY + math.sin(t * 2) * 0.5
					local pos = targetPos + Vector3.new(0, yOffset, 0)
					arrowPart.CFrame = CFrame.new(pos, targetPos) * arrowRotOffset
				end

				runService.RenderStepped:Wait()
			end
		end)
	end

	local function pointArrowToHoverMesh(onReached)
		destroyArrow()
		local myToken = arrowToken

		local character = player.Character or player.CharacterAdded:Wait()
		character:WaitForChild("HumanoidRootPart")

		local hoverPart: BasePart? = worldRoot:FindFirstChild("HoverMesh")
		if not hoverPart then
			for _, obj in ipairs(worldRoot:GetDescendants()) do
				if obj:IsA("BasePart") and obj.Name == "HoverMesh" then
					hoverPart = obj
					break
				end
			end
		end

		if not hoverPart then
			warn("[Tutorial] HoverMesh not found")
			return
		end

		local targetPos = hoverPart.Position

		local arrowTemplate = replicatedStorage:WaitForChild("TutorialArrow")
		local arrow = arrowTemplate:Clone()
		arrow.Name = "TutorialArrowRuntime_HoverMesh"
		arrow.Anchored = true
		arrow.CanCollide = false
		arrow.Parent = workspace
		arrowPart = arrow

		local sizeNearPlayer = arrow.Size
		local sizeOnHover = sizeNearPlayer * 1.7

		local reachedHover = false
		local hoverOffsetY = 5
		local playerOffsetY = 4
		local reachDistance = 12
		local startTime = tick()

		task.spawn(function()
			while arrowPart and arrowPart.Parent and hoverPart.Parent and myToken == arrowToken do
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if not hrp then break end

				local hrpPos = hrp.Position
				targetPos = hoverPart.Position

				if not reachedHover then
					if arrowPart.Size ~= sizeNearPlayer then
						arrowPart.Size = sizeNearPlayer
					end

					local flatTarget = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)
					local arrowPos = hrpPos + Vector3.new(0, playerOffsetY, 0)
					arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * arrowRotOffset

					local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) - Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude

					if flatDist <= reachDistance then
						reachedHover = true
						startTime = tick()
						if onReached then
							task.spawn(onReached)
						end
					end
				else
					if arrowPart.Size ~= sizeOnHover then
						arrowPart.Size = sizeOnHover
					end

					local t = tick() - startTime
					local yOffset = hoverOffsetY + math.sin(t * 2) * 0.5
					local pos = targetPos + Vector3.new(0, yOffset, 0)
					arrowPart.CFrame = CFrame.new(pos, targetPos) * arrowRotOffset
				end

				runService.RenderStepped:Wait()
			end
		end)
	end

	return {
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
	}
end

return WorldArrows
