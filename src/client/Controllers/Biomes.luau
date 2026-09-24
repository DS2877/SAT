-- Regions feel different: while you stand in one, the colour grading and haze shift to its
-- mood (Config/Regions), and crossing into a new region plays a cinematic title card with its
-- danger stars and the strength we recommend. Secrets found get their own card.
-- Presentation only: discovery rewards are granted by the server (Services/Exploration).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Regions = require(Shared.Config.Regions)
local Zones = require(Shared.Util.Zones)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Sounds = require(UI.Sounds)
local ClientState = require(script.Parent.Parent.ClientState)

local Biomes = {}

local player = Players.LocalPlayer
local CARD_COOLDOWN = 90 -- seconds before the same region's card may show again
local MOOD_TWEEN = TweenInfo.new(3, Enum.EasingStyle.Sine)

local card: Frame
local header: TextLabel
local title: TextLabel
local stars: TextLabel
local tagline: TextLabel
local footer: TextLabel
local cardToken = nil
local lastShown: { [string]: number } = {}

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function applyMood(area: string)
	local info = Regions.Info[area] or Regions.Info.District
	local mood = info.Mood
	local grade = Lighting:FindFirstChild("BaseGrade")
	if grade and grade:IsA("ColorCorrectionEffect") then
		Kit.tween(grade, MOOD_TWEEN, { TintColor = rgb(mood.Tint), Saturation = mood.Saturation, Contrast = mood.Contrast })
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		-- Ambience owns the atmosphere's colours (day/night); regions only own density + haze.
		Kit.tween(atmosphere, MOOD_TWEEN, { Density = mood.Density, Haze = mood.Haze })
	end
end

-- Fades a label and its outline together (instantly when `info` is nil).
local function fade(label: TextLabel, transparency: number, info: TweenInfo?)
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if info then
		Kit.tween(label, info, { TextTransparency = transparency })
		if stroke then
			Kit.tween(stroke, info, { Transparency = transparency })
		end
	else
		label.TextTransparency = transparency
		if stroke then
			stroke.Transparency = transparency
		end
	end
end

local function showCard(headerText: string, titleText: string, color: Color3, starText: string, taglineText: string, footerText: string, footerColor: Color3)
	header.Text = headerText
	title.Text = titleText
	title.TextColor3 = color
	stars.Text = starText
	tagline.Text = taglineText
	footer.Text = footerText
	footer.TextColor3 = footerColor
	card.Visible = true
	for _, label in { header, title, stars, tagline, footer } do
		fade(label, 1, nil)
		fade(label, 0, TweenInfo.new(0.6))
	end
	card.Position = UDim2.fromScale(0.5, 0.2)
	Kit.tween(card, TweenInfo.new(0.8, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.17) })
	local token = {}
	cardToken = token
	task.delay(4, function()
		if cardToken ~= token then
			return
		end
		for _, label in { header, title, stars, tagline, footer } do
			fade(label, 1, TweenInfo.new(0.8))
		end
		task.wait(0.8)
		if cardToken == token then
			card.Visible = false
		end
	end)
end

-- isNew: first visit ever (sent by the server with the discovery bonus).
local function regionCard(area: string, isNew: boolean, bonus: number?)
	local info = Regions.Info[area]
	local balance = GameConfig.Regions[area]
	if not info or not balance then
		return
	end
	local now = os.clock()
	if not isNew then
		-- A first visit is announced by the server (RegionDiscovered) instead.
		if not ClientState.Milestone("Region_" .. area) then
			return
		end
		if lastShown[area] and now - lastShown[area] < CARD_COOLDOWN then
			return
		end
	end
	lastShown[area] = now
	local strength = player:GetAttribute("Strength")
	local ready = type(strength) == "number" and strength >= balance.RecommendedStrength
	local footerText = ("RECOMMENDED STRENGTH %s"):format(Kit.shortNumber(balance.RecommendedStrength))
	if not ready and type(strength) == "number" then
		footerText ..= ("  •  YOU: %s"):format(Kit.shortNumber(strength))
	end
	if bonus and bonus > 0 then
		footerText = ("+%s DISCOVERY BONUS  •  %s"):format(Kit.formatCash(bonus), footerText)
	end
	showCard(
		if isNew then "⭐ NEW REGION DISCOVERED ⭐" else "ENTERING",
		info.Title,
		rgb(info.Color),
		"DANGER " .. Regions.Stars(balance.Danger),
		info.Tagline,
		footerText,
		if ready then Theme.Color.Cash else Color3.fromRGB(255, 150, 70)
	)
	Sounds.Play(if isNew then "RareDiscovery" else "Event", if isNew then 1 else 0.4)
end

local function buildCard(gui: ScreenGui)
	card = Kit.new("Frame", {
		Name = "RegionCard",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.17),
		Size = UDim2.fromOffset(620, 170),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}, { Kit.list(Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Center) })
	local function line(order: number, height: number, font: Enum.Font, color: Color3): TextLabel
		local label = Kit.label({
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, height),
			Font = font,
			TextScaled = true,
			TextColor3 = color,
			Parent = card,
		})
		Kit.new("UIStroke", { Thickness = 3, Color = Color3.new(0, 0, 0), Parent = label })
		return label
	end
	header = line(1, 22, Theme.Font.Black, Color3.fromRGB(255, 230, 150))
	title = line(2, 58, Theme.Font.Display, Color3.new(1, 1, 1))
	stars = line(3, 26, Theme.Font.Display, Color3.fromRGB(255, 90, 70))
	tagline = line(4, 20, Theme.Font.Bold, Color3.new(1, 1, 1))
	footer = line(5, 20, Theme.Font.Black, Theme.Color.Cash)
end

function Biomes.Init(gui: ScreenGui)
	buildCard(gui)
	Net.Get("Feedback").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.Type == "RegionDiscovered" and type(payload.Area) == "string" then
			regionCard(payload.Area, true, tonumber(payload.Reward))
			return
		elseif payload.Type ~= "SecretFound" then
			return
		end
		for _, secret in Regions.Secrets do
			if secret.Id == payload.Id then
				local amount = tonumber(payload.Reward) or 0
				showCard("🔮 SECRET FOUND 🔮", secret.Title, Color3.fromRGB(200, 130, 255), "", secret.Text, if amount > 0 then "+" .. Kit.formatCash(amount) else "", Theme.Color.Cash)
				Sounds.Play("BigReward")
			end
		end
	end)

	local current, candidate, seen = "District", "District", 0
	applyMood(current)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local area = Zones.AreaId(root.Position)
				-- Must stay in the new area for a second: no flicker when walking a border.
				if area == candidate then
					seen += 1
				else
					candidate, seen = area, 1
				end
				if candidate ~= current and seen >= 2 then
					current = candidate
					applyMood(current)
					regionCard(current, false, nil)
				end
			end
		end
	end)
end

return Biomes
