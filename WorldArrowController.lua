local WorldArrowController = {}

local function findBasePartInFolder(folder: Instance): BasePart?
	for _, obj in ipairs(folder:GetDescendants()) do
		if obj:IsA("BasePart") then
			return obj
		end
	end
	return nil
end

function WorldArrowController.new(options)
	local player = options.player
	local worldRoot = options.worldRoot
	local runService = options.RunService
	local replicatedStorage = options.ReplicatedStorage
	local workspaceRef = options.Workspace
	local arrowRotationOffset = options.arrowRotationOffset

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
				local lower = obj.Name:lower()
				if lower:find("location4") and lower:find("wall") then
					wallFolder = obj
					break
				end
			end
		end

		if not wallFolder then
			warn("[Tutorial] Location4Wall folder not found in PixelWorld1")
			return
		end

		local wallPart: BasePart? = wallFolder:FindFirstChild("Location4Wall")
		if not (wallPart and wallPart:IsA("BasePart")) then
			wallPart = findBasePartInFolder(wallFolder)
		end
		if not wallPart then
			warn("[Tutorial] No wall BasePart found inside Location4Wall")
			return
		end

		local targetPos = wallPart.Position

		local arrowTemplate = replicatedStorage:WaitForChild("TutorialArrow")
		local arrow = arrowTemplate:Clone()
		arrow.Name = "TutorialArrowRuntime_WallFinal"
		arrow.Anchored = true
		arrow.CanCollide = false
		arrow.Parent = workspaceRef
		arrowPart = arrow

		local sizeNearPlayer = arrow.Size
		local sizeOnWall = sizeNearPlayer * 1.7

		local reachedWall = false
		local wallOffsetY = 7
		local playerOffsetY = 4
		local reachDistance = 12
		local startTime = tick()

		task.spawn(function()
			while arrowPart and arrowPart.Parent and wallPart.Parent and myToken == arrowToken do
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if not hrp then break end

				local hrpPos = hrp.Position
				targetPos = wallPart.Position

				if not reachedWall then
					if arrowPart.Size ~= sizeNearPlayer then
						arrowPart.Size = sizeNearPlayer
					end

					local flatTarget = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)
					local arrowPos = hrpPos + Vector3.new(0, playerOffsetY, 0)
					arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * arrowRotationOffset

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
					arrowPart.CFrame = CFrame.new(pos, targetPos) * arrowRotationOffset
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
		arrow.Parent = workspaceRef
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
					arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * arrowRotationOffset

					local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) -
						Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude

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
					arrowPart.CFrame = CFrame.new(pos, targetPos) * arrowRotationOffset
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

		local firstLocation: Instance? = nil
		for _, obj in ipairs(worldRoot:GetDescendants()) do
			if obj:IsA("IntValue") and obj.Name == "LevelOfFolder" and obj.Value == 1 then
				firstLocation = obj.Parent
				break
			end
		end
		if not firstLocation then
			warn("[Tutorial] LevelOfFolder == 1 not found inside PixelWorld1")
			return
		end

		local targetPos: Vector3? = nil
		local nearestDist = math.huge

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
		arrow.Name = "TutorialArrowRuntime"
		arrow.Anchored = true
		arrow.CanCollide = false
		arrow.Parent = workspaceRef
		arrowPart = arrow

		local sizeNearPlayer = arrow.Size
		local sizeOnCoin = sizeNearPlayer * 1.7

		local reachedCoin = false
		local coinOffsetY = 4
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
					arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * arrowRotationOffset

					local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) -
						Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude
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
					arrowPart.CFrame = CFrame.new(pos, targetPos) * arrowRotationOffset
				end

				runService.RenderStepped:Wait()
			end
		end)
	end

	local function pointArrowToGrassBlock(onReachedBlock)
		destroyArrow()
		local myToken = arrowToken

		local character = player.Character or player.CharacterAdded:Wait()

		local blocksFolder = worldRoot:WaitForChild("BlocksLocation1")
		local grassBlock = blocksFolder:FindFirstChild("GrassBlock")
		if not grassBlock or not grassBlock:IsA("BasePart") then
			warn("[Tutorial] GrassBlock not found in BlocksLocation1")
			return
		end

		local targetPos = grassBlock.Position

		local arrowTemplate = replicatedStorage:FindFirstChild("TutorialArrow")
		if not arrowTemplate or not arrowTemplate:IsA("BasePart") then
			warn("[Tutorial] TutorialArrow (BasePart) not found in ReplicatedStorage")
			return
		end

		local arrow = arrowTemplate:Clone()
		arrow.Name = "TutorialArrowRuntime_Block"
		arrow.Anchored = true
		arrow.CanCollide = false
		arrow.Parent = workspaceRef
		arrowPart = arrow

		local sizeNearPlayer = arrow.Size
		local sizeOnBlock = sizeNearPlayer * 1.7

		local reachedBlock = false
		local blockOffsetY = 5
		local playerOffsetY = 4
		local reachDistance = 12
		local startTime = tick()

		task.spawn(function()
			while arrowPart and arrowPart.Parent and grassBlock.Parent and myToken == arrowToken do
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if not hrp then break end

				local hrpPos = hrp.Position
				targetPos = grassBlock.Position

				if not reachedBlock then
					if arrowPart.Size ~= sizeNearPlayer then
						arrowPart.Size = sizeNearPlayer
					end

					local flatTarget = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)
					local arrowPos = hrpPos + Vector3.new(0, playerOffsetY, 0)
					arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * arrowRotationOffset

					local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) -
						Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude
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
					local pos = targetPos + Vector3.new(0, yOffset, 0)
					arrowPart.CFrame = CFrame.new(pos, targetPos) * arrowRotationOffset
				end

				runService.RenderStepped:Wait()
			end
		end)
	end

	local function pointArrowToWall(onReachedWall)
		destroyArrow()
		local myToken = arrowToken

		local character = player.Character or player.CharacterAdded:Wait()

		local wallFolder = worldRoot:WaitForChild("Location1Wall")
		if not wallFolder then
			warn("[Tutorial] Location1Wall folder not found in PixelWorld1")
			return
		end

		local wallPart = wallFolder:FindFirstChild("Location1Wall")
		if not (wallPart and wallPart:IsA("BasePart")) then
			wallPart = findBasePartInFolder(wallFolder)
		end
		if not wallPart then
			warn("[Tutorial] No wall BasePart found inside Location1Wall")
			return
		end

		local targetPos = wallPart.Position

		local arrowTemplate = replicatedStorage:FindFirstChild("TutorialArrow")
		if not arrowTemplate or not arrowTemplate:IsA("BasePart") then
			warn("[Tutorial] TutorialArrow (BasePart) not found in ReplicatedStorage")
			return
		end

		local arrow = arrowTemplate:Clone()
		arrow.Name = "TutorialArrowRuntime_Wall"
		arrow.Anchored = true
		arrow.CanCollide = false
		arrow.Parent = workspaceRef
		arrowPart = arrow

		local sizeNearPlayer = arrow.Size
		local sizeOnWall = sizeNearPlayer * 1.7

		local reachedWall = false
		local wallOffsetY = 6
		local playerOffsetY = 4
		local reachDistance = 12
		local startTime = tick()

		task.spawn(function()
			while arrowPart and arrowPart.Parent and wallPart.Parent and myToken == arrowToken do
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if not hrp then break end

				local hrpPos = hrp.Position
				targetPos = wallPart.Position

				if not reachedWall then
					if arrowPart.Size ~= sizeNearPlayer then
						arrowPart.Size = sizeNearPlayer
					end

					local flatTarget = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)
					local arrowPos = hrpPos + Vector3.new(0, playerOffsetY, 0)

					arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * arrowRotationOffset

					local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) -
						Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude
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

					arrowPart.CFrame = CFrame.new(pos, targetPos) * arrowRotationOffset
				end

				runService.RenderStepped:Wait()
			end
		end)
	end

	local function pointArrowToSecondWall(onReachedWall)
		destroyArrow()
		local myToken = arrowToken

		local character = player.Character or player.CharacterAdded:Wait()

		local wallFolder = worldRoot:WaitForChild("Location2Wall")
		if not wallFolder then
			warn("[Tutorial] Location2Wall folder not found in PixelWorld1")
			return
		end

		local wallPart = wallFolder:FindFirstChild("Location2Wall")
		if not (wallPart and wallPart:IsA("BasePart")) then
			wallPart = findBasePartInFolder(wallFolder)
		end
		if not wallPart then
			warn("[Tutorial] No wall BasePart found inside Location2Wall")
			return
		end

		local targetPos = wallPart.Position

		local arrowTemplate = replicatedStorage:FindFirstChild("TutorialArrow") or replicatedStorage:WaitForChild("TutorialArrow")
		if not arrowTemplate or not arrowTemplate:IsA("BasePart") then
			warn("[Tutorial] TutorialArrow (BasePart) not found in ReplicatedStorage")
			return
		end

		local arrow = arrowTemplate:Clone()
		arrow.Name = "TutorialArrowRuntime_Wall2"
		arrow.Anchored = true
		arrow.CanCollide = false
		arrow.Parent = workspaceRef
		arrowPart = arrow

		local sizeNearPlayer = arrow.Size
		local sizeOnWall = sizeNearPlayer * 1.7

		local reachedWall = false
		local wallOffsetY = 6
		local playerOffsetY = 4
		local reachDistance = 12
		local startTime = tick()

		task.spawn(function()
			while arrowPart and arrowPart.Parent and wallPart.Parent and myToken == arrowToken do
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if not hrp then break end

				local hrpPos = hrp.Position
				targetPos = wallPart.Position

				if not reachedWall then
					if arrowPart.Size ~= sizeNearPlayer then
						arrowPart.Size = sizeNearPlayer
					end

					local flatTarget = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)
					local arrowPos = hrpPos + Vector3.new(0, playerOffsetY, 0)

					arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * arrowRotationOffset

					local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) -
						Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude
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

					arrowPart.CFrame = CFrame.new(pos, targetPos) * arrowRotationOffset
				end

				runService.RenderStepped:Wait()
			end
		end)
	end

	local function pointArrowToUpgradeMachine(onReached)
		destroyArrow()
		local myToken = arrowToken

		local character = player.Character or player.CharacterAdded:Wait()

		local machine = worldRoot:WaitForChild("UpgradeMachine")
		if not machine then
			warn("[Tutorial] UpgradeMachine not found in PixelWorld1")
			return
		end

		local targetPart = machine:FindFirstChild("UpgradeMachineZonePart")
		if not (targetPart and targetPart:IsA("BasePart")) then
			targetPart = machine:FindFirstChild("UpgradePart")
		end
		if not (targetPart and targetPart:IsA("BasePart")) then
			for _, obj in ipairs(machine:GetDescendants()) do
				if obj:IsA("BasePart") then
					targetPart = obj
					break
				end
			end
		end
		if not targetPart then
			warn("[Tutorial] No BasePart found inside UpgradeMachine")
			return
		end

		local targetPos = targetPart.Position

		local arrowTemplate = replicatedStorage:FindFirstChild("TutorialArrow")
		if not arrowTemplate or not arrowTemplate:IsA("BasePart") then
			warn("[Tutorial] TutorialArrow (BasePart) not found in ReplicatedStorage")
			return
		end

		local arrow = arrowTemplate:Clone()
		arrow.Name = "TutorialArrowRuntime_UpgradeMachine"
		arrow.Anchored = true
		arrow.CanCollide = false
		arrow.Parent = workspaceRef
		arrowPart = arrow

		local sizeNearPlayer = arrow.Size
		local sizeOnTarget = sizeNearPlayer * 1.7

		local reached = false
		local offsetYPlayer = 4
		local offsetYTarget = 6
		local reachDistance = 12
		local startTime = tick()

		task.spawn(function()
			while arrowPart and arrowPart.Parent and targetPart.Parent and myToken == arrowToken do
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if not hrp then break end

				local hrpPos = hrp.Position
				targetPos = targetPart.Position

				if not reached then
					if arrowPart.Size ~= sizeNearPlayer then
						arrowPart.Size = sizeNearPlayer
					end

					local flatTarget = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)
					local arrowPos = hrpPos + Vector3.new(0, offsetYPlayer, 0)

					arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * arrowRotationOffset

					local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) -
						Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude
					if flatDist <= reachDistance then
						reached = true
						startTime = tick()
						if onReached then
							task.spawn(onReached)
						end
					end
				else
					if arrowPart.Size ~= sizeOnTarget then
						arrowPart.Size = sizeOnTarget
					end

					local t = tick() - startTime
					local yOffset = offsetYTarget + math.sin(t * 2) * 0.5
					local pos = targetPos + Vector3.new(0, yOffset, 0)

					arrowPart.CFrame = CFrame.new(pos, targetPos) * arrowRotationOffset
				end

				runService.RenderStepped:Wait()
			end
		end)
	end

	local function pointArrowToBarnBlock(onReachedBlock)
		destroyArrow()
		local myToken = arrowToken

		local character = player.Character or player.CharacterAdded:Wait()

		local blocks = worldRoot:WaitForChild("BlocksLocation1")
		local barn: BasePart? = blocks:FindFirstChild("BarnBlock")

		if not barn or not barn:IsA("BasePart") then
			for _, obj in ipairs(blocks:GetDescendants()) do
				if obj:IsA("BasePart") and obj.Name == "BarnBlock" then
					barn = obj
					break
				end
			end
		end

		if not barn then
			warn("[Tutorial] BarnBlock not found")
			return
		end

		local targetPos = barn.Position
		local arrowTemplate = replicatedStorage:WaitForChild("TutorialArrow")

		local arrow = arrowTemplate:Clone()
		arrow.Name = "TutorialArrowRuntime_Barn"
		arrow.Anchored = true
		arrow.CanCollide = false
		arrow.Parent = workspaceRef
		arrowPart = arrow

		local smallSize = arrow.Size
		local bigSize = arrow.Size * 1.7
		local reached = false
		local reachDist = 12
		local offsetPlayerY = 4
		local offsetBlockY = 6
		local startTime = tick()

		task.spawn(function()
			while arrowPart and arrowPart.Parent and barn.Parent and myToken == arrowToken do
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if not hrp then break end

				local hrpPos = hrp.Position
				targetPos = barn.Position

				if not reached then
					if arrowPart.Size ~= smallSize then
						arrowPart.Size = smallSize
					end

					local flatTarget = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)
					local arrowPos = hrpPos + Vector3.new(0, offsetPlayerY, 0)
					arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * arrowRotationOffset

					local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) -
						Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude

					if flatDist <= reachDist then
						reached = true
						startTime = tick()
						if onReachedBlock then
							task.spawn(onReachedBlock)
						end
					end
				else
					if arrowPart.Size ~= bigSize then
						arrowPart.Size = bigSize
					end

					local t = tick() - startTime
					local yoff = offsetBlockY + math.sin(t * 2) * 0.5
					local pos = targetPos + Vector3.new(0, yoff, 0)
					arrowPart.CFrame = CFrame.new(pos, targetPos) * arrowRotationOffset
				end

				runService.RenderStepped:Wait()
			end
		end)
	end

	local function pointArrowToThirdWall(onReachedWall)
		destroyArrow()
		local myToken = arrowToken

		local character = player.Character or player.CharacterAdded:Wait()

		local wallFolder = worldRoot:WaitForChild("Location3Wall")
		if not wallFolder then
			warn("[Tutorial] Location3Wall folder not found in PixelWorld1")
			return
		end

		local wallPart = wallFolder:FindFirstChild("Location3Wall")
		if not (wallPart and wallPart:IsA("BasePart")) then
			wallPart = findBasePartInFolder(wallFolder)
		end
		if not wallPart then
			warn("[Tutorial] No wall BasePart found inside Location3Wall")
			return
		end

		local targetPos = wallPart.Position

		local arrowTemplate = replicatedStorage:WaitForChild("TutorialArrow")
		if not arrowTemplate or not arrowTemplate:IsA("BasePart") then
			warn("[Tutorial] TutorialArrow (BasePart) not found in ReplicatedStorage")
			return
		end

		local arrow = arrowTemplate:Clone()
		arrow.Name = "TutorialArrowRuntime_Wall3"
		arrow.Anchored = true
		arrow.CanCollide = false
		arrow.Parent = workspaceRef
		arrowPart = arrow

		local sizeNearPlayer = arrow.Size
		local sizeOnWall = sizeNearPlayer * 1.7

		local reachedWall = false
		local wallOffsetY = 7
		local playerOffsetY = 4
		local reachDistance = 12
		local startTime = tick()

		task.spawn(function()
			while arrowPart and arrowPart.Parent and wallPart.Parent and myToken == arrowToken do
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if not hrp then break end

				local hrpPos = hrp.Position
				targetPos = wallPart.Position

				if not reachedWall then
					if arrowPart.Size ~= sizeNearPlayer then
						arrowPart.Size = sizeNearPlayer
					end

					local flatTarget = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)
					local arrowPos = hrpPos + Vector3.new(0, playerOffsetY, 0)
					arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * arrowRotationOffset

					local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) -
						Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude
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
					arrowPart.CFrame = CFrame.new(pos, targetPos) * arrowRotationOffset
				end

				runService.RenderStepped:Wait()
			end
		end)
	end

	local function pointArrowToHoverMesh(onReached)
		destroyArrow()
		local myToken = arrowToken

		local character = player.Character or player.CharacterAdded:Wait()

		local hoverPart: BasePart? = worldRoot:FindFirstChild("HoverMesh")
		if not (hoverPart and hoverPart:IsA("BasePart")) then
			for _, obj in ipairs(worldRoot:GetDescendants()) do
				if obj:IsA("BasePart") and obj.Name == "HoverMesh" then
					hoverPart = obj
					break
				end
			end
		end

		if not hoverPart then
			warn("[Tutorial] HoverMesh not found under PixelWorld1")
			return
		end

		local targetPos = hoverPart.Position

		local arrowTemplate = replicatedStorage:WaitForChild("TutorialArrow")
		if not arrowTemplate or not arrowTemplate:IsA("BasePart") then
			warn("[Tutorial] TutorialArrow (BasePart) not found in ReplicatedStorage")
			return
		end

		local arrow = arrowTemplate:Clone()
		arrow.Name = "TutorialArrowRuntime_Hover"
		arrow.Anchored = true
		arrow.CanCollide = false
		arrow.Parent = workspaceRef
		arrowPart = arrow

		local sizeNearPlayer = arrow.Size
		local sizeOnTarget = sizeNearPlayer * 1.7

		local reached = false
		local playerOffsetY = 4
		local targetOffsetY = 7
		local reachDistance = 12
		local startTime = tick()

		task.spawn(function()
			while arrowPart and arrowPart.Parent and hoverPart.Parent and myToken == arrowToken do
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if not hrp then break end

				local hrpPos = hrp.Position
				targetPos = hoverPart.Position

				if not reached then
					if arrowPart.Size ~= sizeNearPlayer then
						arrowPart.Size = sizeNearPlayer
					end

					local flatTarget = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)
					local arrowPos = hrpPos + Vector3.new(0, playerOffsetY, 0)
					arrowPart.CFrame = CFrame.new(arrowPos, flatTarget) * arrowRotationOffset

					local flatDist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) -
						Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude
					if flatDist <= reachDistance then
						reached = true
						startTime = tick()
						if onReached then
							task.spawn(onReached)
						end
					end
				else
					if arrowPart.Size ~= sizeOnTarget then
						arrowPart.Size = sizeOnTarget
					end

					local t = tick() - startTime
					local yOffset = targetOffsetY + math.sin(t * 2) * 0.5
					local pos = targetPos + Vector3.new(0, yOffset, 0)
					arrowPart.CFrame = CFrame.new(pos, targetPos) * arrowRotationOffset
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
		pointArrowToThirdWall = pointArrowToThirdWall,
		pointArrowToUpgradeMachine = pointArrowToUpgradeMachine,
		pointArrowToBarnBlock = pointArrowToBarnBlock,
		pointArrowToHoverMesh = pointArrowToHoverMesh,
	}
end

return WorldArrowController
