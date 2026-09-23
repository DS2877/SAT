-- Unified UI design system: every screen pulls typography, color, spacing and motion from here.

local Theme = {}

Theme.Font = {
	Display = Enum.Font.FredokaOne, -- big adventurous headings / numbers
	Bold = Enum.Font.GothamBold,
	Body = Enum.Font.GothamMedium,
	Black = Enum.Font.GothamBlack,
}

Theme.TextSize = {
	Hero = 34,
	Title = 26,
	Heading = 20,
	Body = 17,
	Small = 14,
	Tiny = 12,
}

Theme.Color = {
	Panel = Color3.fromRGB(18, 22, 38),
	PanelLight = Color3.fromRGB(32, 38, 62),
	PanelStroke = Color3.fromRGB(255, 255, 255),
	Text = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(180, 186, 205),
	Gold = Color3.fromRGB(255, 200, 60),
	Cash = Color3.fromRGB(120, 235, 120),
	Strength = Color3.fromRGB(255, 150, 70),
	Danger = Color3.fromRGB(255, 70, 80),
	Warn = Color3.fromRGB(255, 190, 70),
	Info = Color3.fromRGB(110, 190, 255),
	Reward = Color3.fromRGB(255, 210, 80),
	Safe = Color3.fromRGB(90, 230, 120),
	Secret = Color3.fromRGB(190, 110, 255),
	Button = Color3.fromRGB(255, 196, 50),
	ButtonText = Color3.fromRGB(40, 28, 10),
	ButtonAlt = Color3.fromRGB(58, 66, 100),
	Disabled = Color3.fromRGB(80, 84, 100),
}

Theme.Transparency = {
	Panel = 0.12,
	PanelSoft = 0.3,
	Stroke = 0.82,
}

Theme.Radius = {
	Small = UDim.new(0, 8),
	Medium = UDim.new(0, 14),
	Large = UDim.new(0, 20),
	Round = UDim.new(1, 0),
}

Theme.Space = { XS = 4, S = 8, M = 12, L = 18, XL = 26 }

Theme.Motion = {
	Fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Normal = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Pop = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Slow = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
}

Theme.ToneColor = {
	Info = Theme.Color.Info,
	Warn = Theme.Color.Warn,
	Danger = Theme.Color.Danger,
	Reward = Theme.Color.Reward,
	Safe = Theme.Color.Safe,
}

return Theme
