-- 🎨 VAULT SKINS (Config/VaultSkins): every skin as a card - its palette, what it takes, and
-- WEAR / BUY. PREVIEW puts it on YOUR real vault for 20 seconds (everyone can see it: that's
-- half the fun). The flex skin gets a banner of its own at the top.
-- Server: Services/VaultService (SetVaultSkin / PreviewVaultSkin), purchases: MonetizationService.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local VaultSkins = require(Shared.Config.VaultSkins)
local SkinRules = require(Shared.Logic.VaultSkins)
local Monetization = require(Shared.Config.Monetization)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Sounds = require(UI.Sounds)
local ClientState = require(script.Parent.Parent.ClientState)

local VaultSkinsMenu = {}

local player = Players.LocalPlayer

local SECTIONS = {
	{ Title = "🏛 FREE & NET WORTH", Sub = "Grow your best-ever net worth (cash + vault) - they stay yours forever", Kinds = { Free = true, NetWorth = true } },
	{ Title = "✨ ASCENSION", Sub = "One for every Deep South region you open up", Kinds = { Ascension = true } },
	{ Title = "💎 ROBUX", Sub = "Cosmetic only - your vault earns exactly the same", Kinds = { Pass = true } },
}

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 200)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(150, 220, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(170, 255, 220)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 170, 255)),
})

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function passOf(skin)
	return if skin.Unlock.Kind == "Pass" then Monetization.SkinPasses[skin.Unlock.Pass] else nil
end

local function ownsPass(key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end

local function buy(skin)
	local pass = passOf(skin)
	if not pass or pass.Id == 0 then
		Sounds.Play("Error")
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.Id)
end

local function preview(skin)
	Net.Get("PreviewVaultSkin"):FireServer(skin.Id)
end

-- The palette swatch: the skin's colours as a gradient, its icon, four colour chips.
local function swatch(parent: Instance, skin, height: number, iconSize: number): Frame
	local p = skin.Palette
	local frame = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = parent }, {
		Kit.corner(Theme.Radius.Medium),
		Kit.new("UIGradient", {
			Rotation = 25,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, rgb(p.Floor)),
				ColorSequenceKeypoint.new(0.45, rgb(p.Wall)),
				ColorSequenceKeypoint.new(0.8, rgb(p.Trim)),
				ColorSequenceKeypoint.new(1, rgb(p.Glow)),
			}),
		}),
	})
	local icon = Kit.label({ Text = skin.Icon, Size = UDim2.fromScale(1, 1), TextSize = iconSize, Parent = frame })
	Kit.textStroke(Color3.new(0, 0, 0), 1).Parent = icon
	local chips = Kit.new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -6), Size = UDim2.fromOffset(4 * 18, 14), BackgroundTransparency = 1, Parent = frame }, { Kit.list(Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Right) })
	for i, key in { "Wall", "Trim", "Glow", "Carpet" } do
		Kit.new("Frame", { LayoutOrder = i, Size = UDim2.fromOffset(14, 14), BackgroundColor3 = rgb(p[key]), BorderSizePixel = 0, Parent = chips }, { Kit.corner(UDim.new(1, 0)), Kit.stroke(Color3.new(1, 1, 1), 1.5, 0.1) })
	end
	return frame
end

function VaultSkinsMenu.Build(root: Frame)
	local cards = {}
	local rainbowStrokes: { UIGradient } = {}

	-- TOP BAR: your net worth (what earns skins) and the preview in progress.
	local worthLabel = Kit.label({ Size = UDim2.new(1, -200, 0, 22), Font = Theme.Font.Black, TextSize = Theme.TextSize.Body, TextColor3 = Theme.Color.Cash, TextXAlignment = Enum.TextXAlignment.Left, RichText = true, Parent = root })
	local previewLabel = Kit.label({ Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, -200, 0, 18), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, TextColor3 = Color3.fromRGB(150, 220, 255), TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = root })
	local endPreview = Kit.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(190, 40), Text = "✖ END PREVIEW", TextSize = Theme.TextSize.Small, BackgroundColor3 = Theme.Color.ButtonAlt, TextColor3 = Theme.Color.Text, Visible = false, Parent = root }, function()
		Net.Get("PreviewVaultSkin"):FireServer("")
	end)

	local scroller = Kit.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = root,
	}, { Kit.list(Enum.FillDirection.Vertical, 10), Kit.padding(4) })
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	-- THE FLEX: a banner of its own at the top (hidden once you own it).
	local flexSkin = nil
	for _, skin in VaultSkins.List do
		if skin.Flex then
			flexSkin = skin
		end
	end
	local hero: Frame? = nil
	if flexSkin then
		local pass = passOf(flexSkin)
		local heroFrame = Kit.panel({ LayoutOrder = nextOrder(), Size = UDim2.new(1, -8, 0, 150), BackgroundColor3 = Color3.fromRGB(20, 34, 70), BackgroundTransparency = 0, Parent = scroller })
		hero = heroFrame
		local heroStroke = heroFrame:FindFirstChildOfClass("UIStroke")
		if heroStroke then
			heroStroke.Thickness = 3
			heroStroke.Transparency = 0
			heroStroke.Color = Color3.new(1, 1, 1)
			local g = Kit.new("UIGradient", { Color = RAINBOW, Parent = heroStroke })
			table.insert(rainbowStrokes, g)
		end
		Kit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(70, 110, 180), Color3.fromRGB(25, 30, 70)), Parent = heroFrame })
		local art = swatch(heroFrame, flexSkin, 130, 76)
		art.Position = UDim2.fromOffset(10, 10)
		art.Size = UDim2.fromOffset(150, 130)
		Kit.label({ Text = "👑 THE FLEX • ROBUX ONLY", Position = UDim2.fromOffset(174, 10), Size = UDim2.new(1, -184, 0, 16), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = heroFrame })
		local title = Kit.label({ Text = flexSkin.Name:upper(), Position = UDim2.fromOffset(174, 26), Size = UDim2.new(1, -184, 0, 34), Font = Theme.Font.Display, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Left, Parent = heroFrame })
		local titleGradient = Kit.new("UIGradient", { Color = RAINBOW, Parent = title })
		table.insert(rainbowStrokes, titleGradient)
		Kit.label({ Text = flexSkin.Tagline, Position = UDim2.fromOffset(174, 60), Size = UDim2.new(1, -184, 0, 36), Font = Theme.Font.Bold, TextSize = Theme.TextSize.Small, TextColor3 = Color3.fromRGB(210, 230, 255), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = heroFrame })
		local buttons = Kit.new("Frame", { Position = UDim2.new(0, 174, 1, -50), Size = UDim2.new(1, -184, 0, 42), BackgroundTransparency = 1, Parent = heroFrame }, { Kit.list(Enum.FillDirection.Horizontal, 8) })
		Kit.button({ LayoutOrder = 1, Size = UDim2.new(0.55, -4, 1, 0), Text = if pass and pass.Id ~= 0 then ("💎 BUY • %s %d"):format("R$", pass.Price) else "💎 COMING SOON", TextSize = 18, BackgroundColor3 = Color3.fromRGB(120, 210, 255), TextColor3 = Color3.fromRGB(10, 30, 60), Parent = buttons }, function()
			buy(flexSkin)
		end)
		Kit.button({ LayoutOrder = 2, Size = UDim2.new(0.45, -4, 1, 0), Text = "👀 PREVIEW", TextSize = 18, BackgroundColor3 = Theme.Color.ButtonAlt, TextColor3 = Theme.Color.Text, Parent = buttons }, function()
			preview(flexSkin)
		end)
	end

	for _, section in SECTIONS do
		Kit.label({ LayoutOrder = nextOrder(), Text = section.Title, Size = UDim2.new(1, -8, 0, 26), Font = Theme.Font.Display, TextSize = 22, TextColor3 = Theme.Color.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = scroller })
		Kit.label({ LayoutOrder = nextOrder(), Text = section.Sub, Size = UDim2.new(1, -8, 0, 16), Font = Theme.Font.Bold, TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextDim, TextXAlignment = Enum.TextXAlignment.Left, Parent = scroller })
		local grid = Kit.new("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = scroller }, {
			Kit.new("UIGridLayout", { CellSize = UDim2.new(1 / 3, -8, 0, 262), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		for _, skin in VaultSkins.List do
			if section.Kinds[skin.Unlock.Kind] then
				local card = Kit.panel({ LayoutOrder = skin.Order, BackgroundColor3 = Theme.Color.PanelLight, Parent = grid }, { Kit.padding(8) })
				local stroke = card:FindFirstChildOfClass("UIStroke")
				if skin.Flex and stroke then
					stroke.Thickness = 3
					stroke.Transparency = 0
					stroke.Color = Color3.new(1, 1, 1)
					table.insert(rainbowStrokes, Kit.new("UIGradient", { Color = RAINBOW, Parent = stroke }))
				end
				swatch(card, skin, 92, 50)
				Kit.label({ Text = skin.Name:upper(), Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 22), Font = Theme.Font.Display, TextSize = 19, TextScaled = true, Parent = card })
				Kit.label({ Text = skin.Tagline, Position = UDim2.fromOffset(0, 118), Size = UDim2.new(1, 0, 0, 38), Font = Theme.Font.Bold, TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextDim, TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
				local status = Kit.label({ Text = "", Position = UDim2.fromOffset(0, 158), Size = UDim2.new(1, 0, 0, 18), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, Parent = card })
				local bar = Kit.new("Frame", { Position = UDim2.fromOffset(4, 180), Size = UDim2.new(1, -8, 0, 8), BackgroundColor3 = Color3.fromRGB(30, 34, 50), BorderSizePixel = 0, Visible = false, Parent = card }, { Kit.corner(UDim.new(1, 0)) })
				local fill = Kit.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Color.Cash, BorderSizePixel = 0, Parent = bar }, { Kit.corner(UDim.new(1, 0)) })
				local row = Kit.new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = card }, { Kit.list(Enum.FillDirection.Horizontal, 6) })
				local primary = Kit.button({ LayoutOrder = 1, Size = UDim2.new(0.6, -3, 1, 0), Text = "", TextSize = 16, Parent = row }, nil)
				local previewButton = Kit.button({ LayoutOrder = 2, Size = UDim2.new(0.4, -3, 1, 0), Text = "👀 TRY", TextSize = 15, BackgroundColor3 = Theme.Color.ButtonAlt, TextColor3 = Theme.Color.Text, Parent = row }, function()
					preview(skin)
				end)
				local entry = { Skin = skin, Status = status, Bar = bar, Fill = fill, Primary = primary, Preview = previewButton, Card = card, State = "" }
				primary.Activated:Connect(function()
					if entry.State == "wear" then
						Sounds.Play("Click")
						Net.Get("SetVaultSkin"):FireServer(skin.Id)
					elseif entry.State == "buy" then
						Sounds.Play("Click")
						buy(skin)
					else
						Sounds.Play("Error")
					end
				end)
				table.insert(cards, entry)
			end
		end
	end

	local latest = nil
	local function refresh(data)
		latest = data or latest
		local d = latest
		if not d then
			return
		end
		local worth = tonumber(player:GetAttribute("NetWorth")) or 0
		local peak = math.max(tonumber(d.Stats.PeakNetWorth) or 0, worth)
		worthLabel.Text = ("💰 NET WORTH %s  <font color=\"#B4BACD\">• BEST EVER %s • ASCENSION %d</font>"):format(SkinRules.Short(worth), SkinRules.Short(peak), d.Ascension or 0)
		local view = { Stats = { PeakNetWorth = peak }, Ascension = d.Ascension }
		for _, entry in cards do
			local skin = entry.Skin
			local unlocked = SkinRules.IsUnlocked(skin, view, ownsPass)
			local wearing = d.VaultSkin == skin.Id or (d.VaultSkin == "" and skin.Id == VaultSkins.Default)
			local pass = passOf(skin)
			entry.Bar.Visible = false
			if wearing and unlocked then
				entry.State = "wearing"
				entry.Primary.Text = "✔ WEARING"
				entry.Primary.BackgroundColor3 = Theme.Color.Safe
				entry.Primary.TextColor3 = Color3.fromRGB(10, 40, 16)
				entry.Status.Text = "ON YOUR VAULT"
				entry.Status.TextColor3 = Theme.Color.Safe
			elseif unlocked then
				entry.State = "wear"
				entry.Primary.Text = "WEAR"
				entry.Primary.BackgroundColor3 = Theme.Color.Button
				entry.Primary.TextColor3 = Theme.Color.ButtonText
				entry.Status.Text = if skin.Unlock.Kind == "Pass" then "✔ OWNED" else "✔ UNLOCKED"
				entry.Status.TextColor3 = Theme.Color.Safe
			elseif skin.Unlock.Kind == "Pass" then
				entry.State = if pass and pass.Id ~= 0 then "buy" else "soon"
				entry.Primary.Text = if pass and pass.Id ~= 0 then ("%s %d"):format("R$", pass.Price) else "SOON"
				entry.Primary.BackgroundColor3 = if skin.Flex then Color3.fromRGB(120, 210, 255) else Theme.Color.Gold
				entry.Primary.TextColor3 = Color3.fromRGB(30, 24, 10)
				entry.Status.Text = if skin.Flex then "👑 THE RAREST VAULT" else "ROBUX • COSMETIC ONLY"
				entry.Status.TextColor3 = if skin.Flex then Color3.fromRGB(150, 225, 255) else Theme.Color.Gold
			else
				entry.State = "locked"
				entry.Primary.Text = "🔒 LOCKED"
				entry.Primary.BackgroundColor3 = Theme.Color.Disabled
				entry.Primary.TextColor3 = Theme.Color.TextDim
				local progress = SkinRules.Progress(skin, view)
				entry.Bar.Visible = true
				entry.Fill.Size = UDim2.fromScale(progress, 1)
				entry.Fill.BackgroundColor3 = if skin.Unlock.Kind == "Ascension" then Theme.Color.Secret else Theme.Color.Cash
				if skin.Unlock.Kind == "NetWorth" then
					entry.Status.Text = ("%s • %s / %s"):format(SkinRules.Requirement(skin), SkinRules.Short(peak), SkinRules.Short(skin.Unlock.Value))
				else
					entry.Status.Text = SkinRules.Requirement(skin)
				end
				entry.Status.TextColor3 = Theme.Color.TextDim
			end
		end
		if hero and flexSkin then
			local pass = passOf(flexSkin)
			hero.Visible = not (pass and ownsPass(flexSkin.Unlock.Pass))
		end
	end

	-- The preview countdown, and the rainbow on the flex.
	local lastSecond = -1
	RunService.RenderStepped:Connect(function()
		if not root.Visible then
			return
		end
		local t = os.clock()
		for _, g in rainbowStrokes do
			g.Rotation = (t * 60) % 360
		end
		local untilTime = tonumber(player:GetAttribute("SkinPreviewUntil")) or 0
		local left = math.ceil(untilTime - workspace:GetServerTimeNow())
		if left ~= lastSecond then
			lastSecond = left
			local previewing = left > 0
			endPreview.Visible = previewing
			if previewing then
				local skin = VaultSkins.Get(player:GetAttribute("SkinPreviewId") :: any)
				previewLabel.Text = ("👀 YOUR VAULT IS WEARING %s %s • %ds - go take a look!"):format(skin.Icon, skin.Name:upper(), left)
			else
				previewLabel.Text = "👀 TRY puts any skin on your vault for 20 seconds"
			end
			for _, entry in cards do
				entry.Preview.Text = if previewing and player:GetAttribute("SkinPreviewId") == entry.Skin.Id then ("👀 %ds"):format(left) else "👀 TRY"
			end
		end
	end)

	for _, list in { Monetization.SkinPasses } do
		for key in list do
			player:GetAttributeChangedSignal("Pass_" .. key):Connect(function()
				refresh(nil)
			end)
		end
	end
	player:GetAttributeChangedSignal("NetWorth"):Connect(function()
		if root.Visible then
			refresh(nil)
		end
	end)
	refresh(ClientState.Data)

	return {
		Refresh = refresh,
	}
end

return VaultSkinsMenu
