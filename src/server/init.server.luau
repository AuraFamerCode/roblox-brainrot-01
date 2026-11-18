-- BRAINROT TOWER: RIZZ LADDER (Server)
-- Authoritative server: world generation, round timer, ooze physics, character collection.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

Players.CharacterAutoLoads = false

local brainrotNet = Instance.new("RemoteEvent")
brainrotNet.Name = "BrainrotNet"
brainrotNet.Parent = ReplicatedStorage

local endRound: (won: boolean, reason: string) -> ()

-- Atmosphere & Lighting
Lighting.Ambient = Color3.fromRGB(25, 20, 35)
Lighting.Brightness = 1.8
Lighting.FogStart = 40
Lighting.FogEnd = 280
Lighting.FogColor = Color3.fromRGB(16, 10, 26)

local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Saturation, colorCorrection.Contrast = 0.35, 0.2
colorCorrection.TintColor = Color3.fromRGB(250, 240, 255)
colorCorrection.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Intensity, bloom.Size, bloom.Threshold = 0.9, 24, 0.85
bloom.Parent = Lighting

local NEON_PALETTE = {
	Color3.fromRGB(255, 20, 147), -- Magenta
	Color3.fromRGB(0, 240, 255), -- Cyan
	Color3.fromRGB(57, 255, 20), -- Lime
	Color3.fromRGB(255, 130, 0), -- Orange
}

local CHARACTERS = {
	{ name = "SKIBIDI SCRUB", tier = "COMMON [TIER 1]", color = BrickColor.new("Bright yellow"), eyeColor = Color3.fromRGB(255, 255, 255) },
	{ name = "GYATT GATOR", tier = "UNCOMMON [TIER 2]", color = BrickColor.new("Dark green"), eyeColor = Color3.fromRGB(255, 255, 0) },
	{ name = "RIZZ RACCOON", tier = "RARE [TIER 3]", color = BrickColor.new("Medium stone grey"), eyeColor = Color3.fromRGB(0, 240, 255) },
	{ name = "FANUM FOX", tier = "EPIC [TIER 4]", color = BrickColor.new("Bright orange"), eyeColor = Color3.fromRGB(255, 255, 255) },
	{ name = "SIGMA SHARK", tier = "LEGENDARY [TIER 5]", color = BrickColor.new("Cyan"), eyeColor = Color3.fromRGB(255, 0, 120) },
	{ name = "OHIO OTTER", tier = "MYTHIC [TIER 6]", color = BrickColor.new("Reddish brown"), eyeColor = Color3.fromRGB(150, 255, 50) },
	{ name = "GIGA GORILLA", tier = "GODLY [TIER 7]", color = BrickColor.new("Black"), eyeColor = Color3.fromRGB(255, 50, 50) },
	{ name = "BRAINROT OVERLORD", tier = "SECRET [TIER 8]", color = BrickColor.new("Hot pink"), eyeColor = Color3.fromRGB(255, 240, 0) },
}

local RANKS = {
	{ min = 0, max = 0, name = "NOOB" },
	{ min = 1, max = 2, name = "NPC" },
	{ min = 3, max = 4, name = "RIZZLER" },
	{ min = 5, max = 6, name = "SIGMA" },
	{ min = 7, max = 7, name = "ALPHA" },
	{ min = 8, max = 8, name = "BRAINROT LEGEND" },
}

local STOREY_COUNT, STOREY_RAISE, STOREY_RADIUS = 8, 9, 16
local ROUND_DURATION, OOZE_START_Y, OOZE_TOP_LIMIT = 120, -18, 72

local towerFolder: Folder
local oozePart: Part?
local oozeSurface: Part?
local spawnCFrame = CFrame.new(STOREY_RADIUS, 7, 0)
local characterModels: { [number]: Model } = {}
local characterBaseCFrames: { [number]: CFrame } = {}
local collectedStoreys: { [number]: boolean } = {}
local activeConnections: { [string]: RBXScriptConnection } = {}

local roundActive = false
local roundTimer, timeElapsed, score, streak, bestStreak = ROUND_DURATION, 0, 0, 0, 0
local currentOozeY = OOZE_START_Y
local oozeContactDebounce: { [number]: number } = {}

local function getRank(s: number): (string, number)
	for index, rankInfo in RANKS do
		if s >= rankInfo.min and s <= rankInfo.max then
			return rankInfo.name, index
		end
	end
	return "NOOB", 1
end

local function broadcastState()
	local rankName, rankIndex = getRank(score)
	brainrotNet:FireAllClients({
		action = "update",
		timeRemaining = math.max(0, math.ceil(roundTimer)),
		score = score,
		total = STOREY_COUNT,
		streak = streak,
		bestStreak = bestStreak,
		rank = rankName,
		rankIndex = rankIndex,
		oozeY = currentOozeY,
	})
end

local function makePart(size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, canCollide: boolean, parent: Instance): Part
	local p = Instance.new("Part")
	p.Size, p.CFrame, p.Color, p.Material = size, cf, color, mat
	p.CanCollide, p.Anchored, p.Parent = canCollide, true, parent
	return p
end

-- Build 8-Storey Spiral Tower
local function buildTower()
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then baseplate:Destroy() end
	if towerFolder then towerFolder:Destroy() end

	towerFolder = Instance.new("Folder")
	towerFolder.Name = "BrainrotTower"
	towerFolder.Parent = workspace

	makePart(Vector3.new(44, 2, 44), CFrame.new(0, -6, 0), Color3.fromRGB(15, 15, 20), Enum.Material.Metal, true, towerFolder)

	local storeyCFrames: { [number]: CFrame } = {}
	for i = 1, STOREY_COUNT do
		local angle = (i - 1) * math.rad(30)
		local platformCF = CFrame.new(STOREY_RADIUS * math.cos(angle), 5 + (i - 1) * STOREY_RAISE, STOREY_RADIUS * math.sin(angle)) * CFrame.Angles(0, -angle, 0)
		storeyCFrames[i] = platformCF
		local neonColor = NEON_PALETTE[((i - 1) % #NEON_PALETTE) + 1]

		local platform = makePart(Vector3.new(26, 2, 26), platformCF, Color3.fromRGB(22, 22, 28), Enum.Material.SmoothPlastic, true, towerFolder)
		platform.Name = "StoreyPlatform_" .. i

		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range, light.Parent = neonColor, 1.8, 22, platform

		local edges = {
			{ Vector3.new(26, 0.4, 0.6), CFrame.new(0, 1.1, 12.7) },
			{ Vector3.new(26, 0.4, 0.6), CFrame.new(0, 1.1, -12.7) },
			{ Vector3.new(0.6, 0.4, 24.8), CFrame.new(12.7, 1.1, 0) },
			{ Vector3.new(0.6, 0.4, 24.8), CFrame.new(-12.7, 1.1, 0) },
		}
		for _, e in edges do
			makePart(e[1], platformCF * e[2], neonColor, Enum.Material.Neon, false, towerFolder)
		end

		if i < STOREY_COUNT then
			local midAngle = angle + math.rad(15)
			local ladderCF = CFrame.new(STOREY_RADIUS * math.cos(midAngle), 5 + (i - 1) * STOREY_RAISE + 5.5, STOREY_RADIUS * math.sin(midAngle)) * CFrame.Angles(0, -midAngle + math.rad(90), 0)
			local ladder = Instance.new("TrussPart")
			ladder.Name, ladder.Size, ladder.CFrame = "Ladder_" .. i, Vector3.new(2, STOREY_RAISE, 2), ladderCF
			ladder.Anchored, ladder.Color, ladder.Parent = true, neonColor, towerFolder
			makePart(Vector3.new(0.4, STOREY_RAISE, 2.2), ladderCF * CFrame.new(1.1, 0, 0), neonColor, Enum.Material.Neon, false, towerFolder)
		end
	end

	spawnCFrame = storeyCFrames[1] * CFrame.new(0, 2, 0)

	for p = 1, 4 do
		local pillarAngle = (p - 1) * (math.pi / 2)
		makePart(Vector3.new(1.8, 110, 1.8), CFrame.new(11.5 * math.cos(pillarAngle), 40, 11.5 * math.sin(pillarAngle)), Color3.fromRGB(18, 18, 24), Enum.Material.Metal, true, towerFolder)
	end

	oozePart = Instance.new("Part")
	oozePart.Name, oozePart.Shape = "CringeOoze", Enum.PartType.Cylinder
	oozePart.Size, oozePart.Anchored, oozePart.CanCollide = Vector3.new(160, 21, 21), true, false
	oozePart.Material, oozePart.Color, oozePart.Transparency = Enum.Material.Neon, Color3.fromRGB(170, 0, 255), 0.5
	oozePart.CFrame = CFrame.new(0, OOZE_START_Y, 0) * CFrame.Angles(0, 0, math.rad(90))
	oozePart.Parent = towerFolder

	oozeSurface = makePart(Vector3.new(21, 1.2, 21), CFrame.new(0, OOZE_START_Y, 0), Color3.fromRGB(120, 0, 255), Enum.Material.Neon, false, towerFolder)
	oozeSurface.Transparency = 0.3

	local oozeParticles = Instance.new("ParticleEmitter")
	oozeParticles.Color = ColorSequence.new(Color3.fromRGB(180, 0, 255), Color3.fromRGB(0, 255, 120))
	oozeParticles.Size, oozeParticles.Rate = NumberSequence.new(0.8, 2.2), 28
	oozeParticles.Speed, oozeParticles.SpreadAngle = NumberRange.new(4, 10), Vector2.new(35, 35)
	oozeParticles.Parent = oozeSurface

	local oozeLight = Instance.new("PointLight")
	oozeLight.Color, oozeLight.Brightness, oozeLight.Range, oozeLight.Parent = Color3.fromRGB(180, 0, 255), 3, 26, oozeSurface

	return storeyCFrames
end

-- Build a procedural brainrot character on a storey
local function buildBrainrot(index: number, storeyCF: CFrame)
	local charInfo = CHARACTERS[index]
	local model = Instance.new("Model")
	model.Name = charInfo.name

	local body = makePart(Vector3.new(2.4, 2.8, 1.8), storeyCF * CFrame.new(0, 3.4, 0), charInfo.color.Color, Enum.Material.SmoothPlastic, false, model)
	body.Name = "Body"
	model.PrimaryPart = body

	local head = makePart(Vector3.new(1.6, 1.6, 1.6), body.CFrame * CFrame.new(0, 2.2, 0), charInfo.color.Color, Enum.Material.SmoothPlastic, false, model)
	head.Name, head.Anchored = "Head", false
	local hw = Instance.new("WeldConstraint")
	hw.Part0, hw.Part1, hw.Parent = body, head, head

	for eyeIdx, eyePos in { Vector3.new(-0.4, 0.2, -0.85), Vector3.new(0.4, 0.2, -0.85) } do
		local eye = makePart(Vector3.new(0.35, 0.35, 0.2), head.CFrame * CFrame.new(eyePos), charInfo.eyeColor, Enum.Material.Neon, false, model)
		eye.Name, eye.Anchored = "Eye_" .. eyeIdx, false
		local ew = Instance.new("WeldConstraint")
		ew.Part0, ew.Part1, ew.Parent = head, eye, eye
	end

	local bb = Instance.new("BillboardGui")
	bb.Name, bb.Size, bb.StudsOffset = "InfoTag", UDim2.fromOffset(180, 52), Vector3.new(0, 3.8, 0)
	bb.AlwaysOnTop, bb.MaxDistance, bb.Adornee, bb.Parent = true, 140, head, head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size, nameLabel.BackgroundTransparency = UDim2.new(1, 0, 0.55, 0), 1
	nameLabel.Text, nameLabel.TextColor3 = charInfo.name, Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency, nameLabel.TextSize, nameLabel.Font = 0.2, 18, Enum.Font.FredokaOne
	nameLabel.Parent = bb

	local tierLabel = Instance.new("TextLabel")
	tierLabel.Position, tierLabel.Size, tierLabel.BackgroundTransparency = UDim2.new(0, 0, 0.55, 0), UDim2.new(1, 0, 0.45, 0), 1
	tierLabel.Text, tierLabel.TextColor3 = charInfo.tier, NEON_PALETTE[((index - 1) % #NEON_PALETTE) + 1]
	tierLabel.TextStrokeTransparency, tierLabel.TextSize, tierLabel.Font = 0.4, 13, Enum.Font.GothamBold
	tierLabel.Parent = bb

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color, sparkles.Size = ColorSequence.new(charInfo.eyeColor), NumberSequence.new(0.2, 0.5)
	sparkles.Rate, sparkles.Speed, sparkles.Parent = 12, NumberRange.new(1, 3), body

	model.Parent = towerFolder
	characterModels[index] = model
	characterBaseCFrames[index] = body.CFrame
	return model
end

-- Collect brainrot character
local function collectBrainrot(player: Player, index: number)
	if not roundActive or collectedStoreys[index] then return end
	collectedStoreys[index] = true
	score += 1
	streak += 1
	bestStreak = math.max(bestStreak, streak)

	local charInfo = CHARACTERS[index]
	local pos = characterBaseCFrames[index] and characterBaseCFrames[index].Position or Vector3.zero

	local burstPart = makePart(Vector3.new(0.5, 0.5, 0.5), CFrame.new(pos), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false, towerFolder)
	burstPart.Transparency = 1
	local burst = Instance.new("ParticleEmitter")
	burst.Color = ColorSequence.new(NEON_PALETTE[((index - 1) % #NEON_PALETTE) + 1])
	burst.Size, burst.Speed = NumberSequence.new(0.6, 2.0), NumberRange.new(8, 22)
	burst.SpreadAngle, burst.Parent = Vector2.new(180, 180), burstPart
	burst:Emit(40)
	task.delay(1.2, function()
		if burstPart then burstPart:Destroy() end
	end)

	if characterModels[index] then
		characterModels[index]:Destroy()
		characterModels[index] = nil
	end

	local tickerText = (streak >= 3) and ("SIGMA STREAK x" .. streak .. "!") or (charInfo.name .. " COLLECTED!")
	local tickerSub = (streak >= 3) and ("RIZZ +1  x" .. streak) or "+1 RIZZ"
	local tickerColor = (streak >= 3) and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(0, 240, 255)

	brainrotNet:FireClient(player, {
		action = "ticker",
		text = tickerText,
		subtext = tickerSub,
		color = tickerColor,
	})

	broadcastState()

	if score >= STOREY_COUNT then
		endRound(true, "All 8 Brainrot Characters Collected!")
	end
end

-- Update Cringe Ooze position and detect hazard collisions
local function updateOoze(dt: number)
	if not roundActive or not oozePart or not oozeSurface then return end

	local speed = 0.55
	if timeElapsed >= 90 then
		speed = 1.35
	elseif timeElapsed >= 60 then
		speed = 1.05
	elseif timeElapsed >= 30 then
		speed = 0.78
	end

	currentOozeY = math.min(OOZE_TOP_LIMIT + 2, currentOozeY + speed * dt)
	oozePart.CFrame = CFrame.new(0, currentOozeY + 80, 0) * CFrame.Angles(0, 0, math.rad(90))
	oozeSurface.Position = Vector3.new(0, currentOozeY, 0)

	if currentOozeY >= OOZE_TOP_LIMIT then
		endRound(false, "The Cringe Ooze engulfed the tower!")
		return
	end

	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local rootPos = root.Position
			local horizDist = math.sqrt(rootPos.X * rootPos.X + rootPos.Z * rootPos.Z)
			local inShaftOoze = (horizDist <= 11.5) and (rootPos.Y <= currentOozeY + 4)
			local fallenInPit = (rootPos.Y < -4)
			local submerged = (rootPos.Y <= currentOozeY + 1.5)

			if (inShaftOoze or fallenInPit or submerged) and (now - (oozeContactDebounce[player.UserId] or 0) > 1.2) then
				oozeContactDebounce[player.UserId] = now
				streak = 0
				brainrotNet:FireClient(player, {
					action = "ticker",
					text = "OOZED! STREAK LOST",
					subtext = "Respawned at Storey 1",
					color = Color3.fromRGB(255, 60, 60),
				})
				root.CFrame = spawnCFrame + Vector3.new(0, 3, 0)
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				broadcastState()
			end
		end
	end
end

-- End current round (Win or Lose)
endRound = function(won: boolean, reason: string)
	if not roundActive then return end
	roundActive = false

	local finalTime = math.floor(timeElapsed * 10) / 10
	local rankName = getRank(score)

	brainrotNet:FireAllClients({
		action = "endRound",
		won = won,
		title = won and "WIN" or "CRINGE",
		reason = reason,
		timeTaken = finalTime,
		score = score,
		total = STOREY_COUNT,
		bestStreak = bestStreak,
		rank = rankName,
	})
end

-- Start a fresh round
local function startRound()
	roundActive = true
	roundTimer = ROUND_DURATION
	timeElapsed, score, streak, bestStreak = 0, 0, 0, 0
	currentOozeY = OOZE_START_Y
	collectedStoreys, oozeContactDebounce = {}, {}

	for _, player in Players:GetPlayers() do
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not char or not char:FindFirstChild("HumanoidRootPart") or (hum and hum.Health <= 0) then
			player:LoadCharacter()
		else
			local root = char:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				root.CFrame = spawnCFrame + Vector3.new(0, 3, 0)
				root.AssemblyLinearVelocity = Vector3.zero
			end
		end
	end

	broadcastState()
end

-- Deterministically reset world and rebuild everything
local function resetWorld()
	for _, conn in activeConnections do conn:Disconnect() end
	activeConnections = {}

	local storeyCFrames = buildTower()
	for i = 1, STOREY_COUNT do
		buildBrainrot(i, storeyCFrames[i])
	end

	startRound()

	activeConnections["heartbeat"] = RunService.Heartbeat:Connect(function(dt)
		if not roundActive then return end
		timeElapsed += dt
		roundTimer = math.max(0, ROUND_DURATION - timeElapsed)

		local t = os.clock()
		for i = 1, STOREY_COUNT do
			if not collectedStoreys[i] and characterModels[i] and characterModels[i].PrimaryPart then
				local baseCF = characterBaseCFrames[i]
				if baseCF then
					characterModels[i].PrimaryPart.CFrame = baseCF * CFrame.new(0, math.sin(t * 3.2 + i) * 0.5, 0) * CFrame.Angles(0, t * 1.6, 0)
				end
			end
		end

		updateOoze(dt)

		for _, player in Players:GetPlayers() do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				for i = 1, STOREY_COUNT do
					if not collectedStoreys[i] and characterModels[i] and characterModels[i].PrimaryPart then
						if (root.Position - characterModels[i].PrimaryPart.Position).Magnitude <= 5.8 then
							collectBrainrot(player, i)
						end
					end
				end
			end
		end

		if roundTimer <= 0 then
			endRound(false, "TIME EXPIRED! The Brainrot Tower faded away...")
		end

		if math.floor(timeElapsed * 10) % 5 == 0 then
			broadcastState()
		end
	end)

	brainrotNet:FireAllClients({ action = "reset" })
end

-- Player lifecycle management
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		local root = char:WaitForChild("HumanoidRootPart", 5)
		if root and root:IsA("BasePart") then
			root.CFrame = spawnCFrame + Vector3.new(0, 3, 0)
		end
		local hum = char:WaitForChild("Humanoid", 5)
		if hum and hum:IsA("Humanoid") then
			hum.JumpHeight = 9.8
			hum.Died:Connect(function()
				task.delay(1.5, function()
					if player and player.Parent and roundActive then
						player:LoadCharacter()
					end
				end)
			end)
		end
	end)

	player:LoadCharacter()
	broadcastState()
end)

Players.PlayerRemoving:Connect(function(player)
	oozeContactDebounce[player.UserId] = nil
end)

brainrotNet.OnServerEvent:Connect(function(player, data)
	if type(data) == "table" and data.action == "restart" then
		if not roundActive then
			resetWorld()
		end
	end
end)

resetWorld()
