-- BRAINROT TOWER: RIZZ LADDER (Client)
-- HUD display, Rizz rank ladder, streak ticker, end screen, and camera intro.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local brainrotNet = ReplicatedStorage:WaitForChild("BrainrotNet", 20) or ReplicatedStorage:FindFirstChild("BrainrotNet")
assert(brainrotNet, "BrainrotNet RemoteEvent not found")

local RANKS = {
	{ index = 1, name = "NOOB", range = "0" },
	{ index = 2, name = "NPC", range = "1-2" },
	{ index = 3, name = "RIZZLER", range = "3-4" },
	{ index = 4, name = "SIGMA", range = "5-6" },
	{ index = 5, name = "ALPHA", range = "7" },
	{ index = 6, name = "BRAINROT LEGEND", range = "8" },
}

local timerLabel: TextLabel
local countLabel: TextLabel
local progressFill: Frame
local rankItemFrames: { [number]: Frame } = {}
local rankItemLabels: { [number]: TextLabel } = {}
local tickerContainer: Frame
local tickerMainLabel: TextLabel
local tickerSubLabel: TextLabel
local endScreenFrame: Frame
local endTitleLabel: TextLabel
local endReasonLabel: TextLabel
local endStatsLabel: TextLabel
local activeTickerTween: Tween?

local function createLabel(name: string, size: UDim2, pos: UDim2, text: string, color: Color3, fontSize: number, font: Enum.Font, parent: Instance): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.Name = name
	lbl.Size = size
	lbl.Position = pos
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = color
	lbl.TextSize = fontSize
	lbl.Font = font
	lbl.Parent = parent
	return lbl
end

-- Build client HUD and panels (avoiding top-left corner)
local function buildHud(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "BrainrotHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	-- 1. Top-Center Bar
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.AnchorPoint = Vector2.new(0.5, 0)
	topBar.Position = UDim2.new(0.5, 0, 0, 18)
	topBar.Size = UDim2.fromOffset(430, 66)
	topBar.BackgroundColor3 = Color3.fromRGB(18, 14, 28)
	topBar.BackgroundTransparency = 0.15
	topBar.BorderSizePixel = 0
	topBar.Parent = gui

	local topCorner = Instance.new("UICorner")
	topCorner.CornerRadius = UDim.new(0, 12); topCorner.Parent = topBar
	local topStroke = Instance.new("UIStroke")
	topStroke.Color = Color3.fromRGB(0, 240, 255); topStroke.Thickness = 2; topStroke.Parent = topBar

	createLabel("Title", UDim2.new(1, 0, 0.45, 0), UDim2.new(0, 0, 0, 2), "⚡ BRAINROT TOWER ⚡", Color3.fromRGB(255, 230, 0), 17, Enum.Font.FredokaOne, topBar)
	timerLabel = createLabel("Timer", UDim2.new(0.5, -12, 0.42, 0), UDim2.new(0, 12, 0.42, 0), "⏱ 120s", Color3.fromRGB(255, 255, 255), 15, Enum.Font.GothamBold, topBar)
	timerLabel.TextXAlignment = Enum.TextXAlignment.Left
	countLabel = createLabel("Collected", UDim2.new(0.5, -12, 0.42, 0), UDim2.new(0.5, 0, 0.42, 0), "👑 0 / 8", Color3.fromRGB(0, 240, 255), 15, Enum.Font.GothamBold, topBar)
	countLabel.TextXAlignment = Enum.TextXAlignment.Right

	local progressBg = Instance.new("Frame")
	progressBg.Size = UDim2.new(1, -24, 0, 6)
	progressBg.Position = UDim2.new(0, 12, 1, -10)
	progressBg.BackgroundColor3 = Color3.fromRGB(35, 30, 50)
	progressBg.BorderSizePixel = 0
	progressBg.Parent = topBar
	local pbc = Instance.new("UICorner"); pbc.CornerRadius = UDim.new(1, 0); pbc.Parent = progressBg

	progressFill = Instance.new("Frame")
	progressFill.Size = UDim2.new(0, 0, 1, 0)
	progressFill.BackgroundColor3 = Color3.fromRGB(255, 20, 147)
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBg
	local pfc = Instance.new("UICorner"); pfc.CornerRadius = UDim.new(1, 0); pfc.Parent = progressFill

	-- 2. Right-Side Rank Ladder Panel
	local ladderPanel = Instance.new("Frame")
	ladderPanel.AnchorPoint = Vector2.new(1, 0.5)
	ladderPanel.Position = UDim2.new(1, -16, 0.5, 0)
	ladderPanel.Size = UDim2.fromOffset(190, 275)
	ladderPanel.BackgroundColor3 = Color3.fromRGB(16, 12, 24)
	ladderPanel.BackgroundTransparency = 0.2
	ladderPanel.BorderSizePixel = 0
	ladderPanel.Parent = gui

	local ldc = Instance.new("UICorner"); ldc.CornerRadius = UDim.new(0, 10); ldc.Parent = ladderPanel
	local lds = Instance.new("UIStroke"); lds.Color = Color3.fromRGB(255, 20, 147); lds.Thickness = 1.8; lds.Parent = ladderPanel
	createLabel("Header", UDim2.new(1, 0, 0, 32), UDim2.new(0, 0, 0, 0), "👑 RIZZ LADDER", Color3.fromRGB(255, 215, 0), 14, Enum.Font.FredokaOne, ladderPanel)

	for i = #RANKS, 1, -1 do
		local rankData = RANKS[i]
		local rowIdx = #RANKS - i + 1
		local itemFrame = Instance.new("Frame")
		itemFrame.Size = UDim2.new(1, -14, 0, 34)
		itemFrame.Position = UDim2.new(0, 7, 0, 34 + (rowIdx - 1) * 38)
		itemFrame.BackgroundColor3 = Color3.fromRGB(25, 22, 38)
		itemFrame.BackgroundTransparency = 0.7
		itemFrame.BorderSizePixel = 0
		itemFrame.Parent = ladderPanel
		local ic = Instance.new("UICorner"); ic.CornerRadius = UDim.new(0, 6); ic.Parent = itemFrame

		local itemLabel = createLabel("Label", UDim2.new(1, -10, 1, 0), UDim2.new(0, 8, 0, 0), rankData.range .. "  " .. rankData.name, Color3.fromRGB(180, 180, 195), 12, Enum.Font.GothamBold, itemFrame)
		itemLabel.TextXAlignment = Enum.TextXAlignment.Left
		rankItemFrames[i] = itemFrame
		rankItemLabels[i] = itemLabel
	end

	-- 3. Center Streak Ticker
	tickerContainer = Instance.new("Frame")
	tickerContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	tickerContainer.Position = UDim2.new(0.5, 0, 0.32, 0)
	tickerContainer.Size = UDim2.fromOffset(400, 64)
	tickerContainer.BackgroundTransparency = 1
	tickerContainer.Parent = gui

	tickerMainLabel = createLabel("MainText", UDim2.new(1, 0, 0.6, 0), UDim2.new(0, 0, 0, 0), "", Color3.fromRGB(255, 215, 0), 28, Enum.Font.FredokaOne, tickerContainer)
	tickerMainLabel.TextStrokeTransparency = 0.3
	tickerSubLabel = createLabel("SubText", UDim2.new(1, 0, 0.4, 0), UDim2.new(0, 0, 0.6, 0), "", Color3.fromRGB(255, 255, 255), 16, Enum.Font.GothamBold, tickerContainer)
	tickerSubLabel.TextStrokeTransparency = 0.5

	-- 4. End Screen Card
	endScreenFrame = Instance.new("Frame")
	endScreenFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	endScreenFrame.Position = UDim2.fromScale(0.5, 0.5)
	endScreenFrame.Size = UDim2.fromOffset(440, 330)
	endScreenFrame.BackgroundColor3 = Color3.fromRGB(14, 10, 22)
	endScreenFrame.BackgroundTransparency = 0.05
	endScreenFrame.BorderSizePixel = 0
	endScreenFrame.Visible = false
	endScreenFrame.Parent = gui

	local ec = Instance.new("UICorner"); ec.CornerRadius = UDim.new(0, 16); ec.Parent = endScreenFrame
	local es = Instance.new("UIStroke"); es.Name = "EndStroke"; es.Color = Color3.fromRGB(57, 255, 20); es.Thickness = 2.5; es.Parent = endScreenFrame

	endTitleLabel = createLabel("Title", UDim2.new(1, 0, 0, 50), UDim2.new(0, 0, 0, 16), "WIN", Color3.fromRGB(57, 255, 20), 36, Enum.Font.FredokaOne, endScreenFrame)
	endReasonLabel = createLabel("Reason", UDim2.new(1, -30, 0, 26), UDim2.new(0, 15, 0, 68), "", Color3.fromRGB(220, 220, 235), 14, Enum.Font.Gotham, endScreenFrame)

	endStatsLabel = createLabel("Stats", UDim2.new(1, -40, 0, 120), UDim2.new(0, 20, 0, 104), "", Color3.fromRGB(240, 240, 255), 15, Enum.Font.GothamBold, endScreenFrame)
	endStatsLabel.BackgroundColor3 = Color3.fromRGB(22, 16, 34)
	endStatsLabel.BackgroundTransparency = 0.4
	local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 8); sc.Parent = endStatsLabel

	local rBtn = Instance.new("TextButton")
	rBtn.Size = UDim2.new(1, -40, 0, 46)
	rBtn.Position = UDim2.new(0, 20, 1, -62)
	rBtn.BackgroundColor3 = Color3.fromRGB(255, 20, 147)
	rBtn.Text = "PRESS R TO RESTART"
	rBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	rBtn.TextSize = 16
	rBtn.Font = Enum.Font.FredokaOne
	rBtn.Parent = endScreenFrame
	local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 10); rc.Parent = rBtn

	rBtn.Activated:Connect(function()
		brainrotNet:FireServer({ action = "restart" })
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

-- Highlight current rank on ladder
local function setRank(rankIndex: number)
	for i, frame in rankItemFrames do
		local label = rankItemLabels[i]
		if i == rankIndex then
			frame.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
			frame.BackgroundTransparency = 0.15
			if label then label.TextColor3 = Color3.fromRGB(15, 12, 25) end
		else
			frame.BackgroundColor3 = Color3.fromRGB(25, 22, 38)
			frame.BackgroundTransparency = 0.7
			if label then label.TextColor3 = Color3.fromRGB(180, 180, 195) end
		end
	end
end

-- Pop streak text and smoothly fade
local function showTicker(text: string, subtext: string, color: Color3)
	if activeTickerTween then activeTickerTween:Cancel() end
	tickerMainLabel.Text = text
	tickerMainLabel.TextColor3 = color
	tickerMainLabel.TextTransparency = 0
	tickerSubLabel.Text = subtext or ""
	tickerSubLabel.TextTransparency = 0
	tickerContainer.Position = UDim2.new(0.5, 0, 0.34, 0)

	local tweenInfo = TweenInfo.new(1.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
	activeTickerTween = TweenService:Create(tickerContainer, tweenInfo, { Position = UDim2.new(0.5, 0, 0.28, 0) })
	TweenService:Create(tickerMainLabel, tweenInfo, { TextTransparency = 1 }):Play()
	TweenService:Create(tickerSubLabel, tweenInfo, { TextTransparency = 1 }):Play()
	activeTickerTween:Play()
end

-- Present victory or defeat end screen card
local function showEndScreen(data: any)
	local won = data.won
	endTitleLabel.Text = won and "WIN" or "CRINGE"
	endTitleLabel.TextColor3 = won and Color3.fromRGB(57, 255, 20) or Color3.fromRGB(255, 20, 80)

	local stroke = endScreenFrame:FindFirstChild("EndStroke")
	if stroke and stroke:IsA("UIStroke") then
		stroke.Color = won and Color3.fromRGB(57, 255, 20) or Color3.fromRGB(255, 20, 80)
	end

	endReasonLabel.Text = data.reason or ""
	endStatsLabel.Text = string.format("Time Taken: %.1fs\nBrainrot Collected: %d / %d\nBest Streak: x%d\nFinal Rank: %s",
		data.timeTaken or 0, data.score or 0, data.total or 8, data.bestStreak or 0, data.rank or "NOOB")
	endScreenFrame.Visible = true
end

-- Short cinematic camera intro tween on spawn
local function playIntroCamera(char: Model)
	local root = char:WaitForChild("HumanoidRootPart", 5)
	local cam = workspace.CurrentCamera
	if not root or not root:IsA("BasePart") or not cam then return end

	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.new(root.Position + Vector3.new(0, -2, -18), root.Position + Vector3.new(0, 24, 0))
	local tween = TweenService:Create(cam, TweenInfo.new(1.6, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(root.Position + Vector3.new(0, 6, -14), root.Position + Vector3.new(0, 2, 0)),
	})
	tween:Play()
	tween.Completed:Connect(function()
		cam.CameraType = Enum.CameraType.Custom
	end)
end

buildHud()
setRank(1)

if player.Character then
	task.spawn(playIntroCamera, player.Character)
end
player.CharacterAdded:Connect(playIntroCamera)

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.R then
		brainrotNet:FireServer({ action = "restart" })
	end
end)

brainrotNet.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	if data.action == "update" then
		timerLabel.Text = "⏱ " .. tostring(data.timeRemaining) .. "s"
		countLabel.Text = "👑 " .. tostring(data.score) .. " / " .. tostring(data.total)
		progressFill.Size = UDim2.new(math.clamp((data.score or 0) / (data.total or 8), 0, 1), 0, 1, 0)
		setRank(data.rankIndex or 1)
	elseif data.action == "ticker" then
		showTicker(data.text, data.subtext, data.color)
	elseif data.action == "endRound" then
		showEndScreen(data)
	elseif data.action == "reset" then
		endScreenFrame.Visible = false
		timerLabel.Text = "⏱ 120s"
		countLabel.Text = "👑 0 / 8"
		progressFill.Size = UDim2.new(0, 0, 1, 0)
		setRank(1)
	end
end)
