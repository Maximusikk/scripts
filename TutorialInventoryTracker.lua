local InventoryTracker = {}

function InventoryTracker.new(params)
	local inventoryFolder = params.inventoryFolder
	local showNotify = params.showNotify
	local RunService = params.RunService

	local lastHatchedUuid: string? = nil
	local knownNfts = {}

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

	for _, child in ipairs(inventoryFolder:GetChildren()) do
		knownNfts[child.Name] = true
	end

	inventoryFolder.ChildAdded:Connect(function(child: Instance)
		if child:GetAttribute("IsGuide") == true then
			if showNotify then
				showNotify(
					"You received a Guide Robot!\nIts power matches the average power of your current world.",
					6
				)
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

	local function getLastHatchedUuid(): string?
		return lastHatchedUuid
	end

	local function setLastHatchedUuid(uuid: string?)
		lastHatchedUuid = uuid
	end

	local function waitForNewHatchedUuid(timeout)
		local start = tick()
		local first = lastHatchedUuid
		repeat
			if lastHatchedUuid and lastHatchedUuid ~= first then
				return lastHatchedUuid
			end
			RunService.Heartbeat:Wait()
		until tick() - start > (timeout or 3)
		return lastHatchedUuid
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

	return {
		getLastHatchedUuid = getLastHatchedUuid,
		setLastHatchedUuid = setLastHatchedUuid,
		waitForNewHatchedUuid = waitForNewHatchedUuid,
		extractUuidFromPayload = extractUuidFromPayload,
	}
end

return InventoryTracker
