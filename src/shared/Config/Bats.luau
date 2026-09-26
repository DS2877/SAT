-- Bats: the slap weapon everyone carries. Not carrying treasure? A slap sends you flying.
-- Carrying? The first slap SLOWS you (Shaken), the second THROWS you and you DROP it.
--
-- You start with the Wooden Bat. The Bat Shop in the District sells the rest: the first three
-- upgrades only cost Cash, the next seven also need an Ascension level. Every tier slaps
-- further (Knockback, studs/s) and reaches a little further (Range). Bats are kept through
-- Ascension (like benches). Models: Shared/BatModels.

export type Bat = {
	Id: string,
	Name: string,
	Tier: number,
	Price: number,
	RequiredAscension: number,
	Knockback: number, -- horizontal launch speed of a slap (studs/s)
	Range: number, -- studs
	Color: { number }, -- main colour (menu accents, hit burst)
	Trail: { number }, -- swing trail colour
	Tagline: string,
}

local Bats = {}

Bats.StarterId = "wooden_bat"

-- The bat's weld in the right hand, posed like every Roblox melee tool (the Steal-a-* games
-- included): the arm is held out in front (BatFx plays Roblox's own "toolnone" hold
-- animation) and the bat leans FORWARD from the fist, about 35 degrees above level. With the
-- arm held out, the hand's -Y points forward and -Z points up; the bat grows along its +Y.
-- The swing chops it down across the front (with Roblox's "toolslash" arm animation).
-- `sweep` swings it sideways around the (level) arm: + to the right, - across the body.
local function lean(degrees: number, sweep: number?): CFrame
	return CFrame.new(0, -0.35, 0) * CFrame.Angles(0, 0, math.rad(sweep or 0)) * CFrame.Angles(math.rad(-180 + degrees), 0, 0)
end
Bats.Grip = {
	Rest = lean(35),
	WindUp = lean(70, 25),
	Swing = lean(-10, -35),
}

-- Roblox's stock tool animations (the ones the default Animate script uses for Tools).
Bats.Animations = {
	R15 = { Hold = "rbxassetid://507768375", Slash = "rbxassetid://522635514" },
	R6 = { Hold = "rbxassetid://182393478", Slash = "rbxassetid://129967390" },
}

Bats.List = {
	{ Id = "wooden_bat", Name = "Wooden Bat", Tier = 1, Price = 0, RequiredAscension = 0, Knockback = 45, Range = 7, Color = { 170, 120, 70 }, Trail = { 255, 255, 255 }, Tagline = "Trusty. Splintery. Yours." },
	{ Id = "spiked_club", Name = "Spiked Club", Tier = 2, Price = 25000, RequiredAscension = 0, Knockback = 55, Range = 7.25, Color = { 120, 80, 50 }, Trail = { 220, 220, 230 }, Tagline = "Nails. Lots of nails." },
	{ Id = "iron_slugger", Name = "Iron Slugger", Tier = 3, Price = 250000, RequiredAscension = 0, Knockback = 66, Range = 7.5, Color = { 150, 155, 170 }, Trail = { 255, 90, 80 }, Tagline = "Heavy metal. Heavier slaps." },
	{ Id = "golden_slugger", Name = "Golden Slugger", Tier = 4, Price = 2500000, RequiredAscension = 0, Knockback = 78, Range = 7.75, Color = { 255, 200, 50 }, Trail = { 255, 225, 120 }, Tagline = "Rich people slap harder." },
	{ Id = "frostbite", Name = "Frostbite", Tier = 5, Price = 5000000, RequiredAscension = 1, Knockback = 92, Range = 8, Color = { 120, 220, 255 }, Trail = { 170, 240, 255 }, Tagline = "A slap so cold it burns." },
	{ Id = "magma_mauler", Name = "Magma Mauler", Tier = 6, Price = 40000000, RequiredAscension = 2, Knockback = 108, Range = 8.25, Color = { 255, 100, 30 }, Trail = { 255, 140, 40 }, Tagline = "Forged in Mount Cinder. Still hot." },
	{ Id = "thunderclap", Name = "Thunderclap", Tier = 7, Price = 400000000, RequiredAscension = 3, Knockback = 125, Range = 8.5, Color = { 255, 230, 60 }, Trail = { 255, 245, 120 }, Tagline = "You hear it after you land." },
	{ Id = "crystal_crusher", Name = "Crystal Crusher", Tier = 8, Price = 2000000000, RequiredAscension = 4, Knockback = 145, Range = 8.75, Color = { 190, 110, 255 }, Trail = { 220, 150, 255 }, Tagline = "Grown, not made. Hits like a geode." },
	{ Id = "void_breaker", Name = "Void Breaker", Tier = 9, Price = 10000000000, RequiredAscension = 5, Knockback = 165, Range = 9, Color = { 90, 30, 160 }, Trail = { 170, 80, 255 }, Tagline = "Slaps you out of reality for a second." },
	{ Id = "dragons_tail", Name = "Dragon's Tail", Tier = 10, Price = 60000000000, RequiredAscension = 6, Knockback = 190, Range = 9.25, Color = { 220, 40, 40 }, Trail = { 255, 90, 40 }, Tagline = "The dragon wants it back." },
	{ Id = "big_bang", Name = "The Big Bang", Tier = 11, Price = 300000000000, RequiredAscension = 7, Knockback = 220, Range = 9.5, Color = { 120, 200, 255 }, Trail = { 255, 140, 230 }, Tagline = "Where everything started. Where you end up: far away." },
} :: { Bat }

local byId: { [string]: Bat } = {}
for _, bat in Bats.List do
	byId[bat.Id] = bat
end

function Bats.Get(id: string?): Bat?
	return if id then byId[id] else nil
end

-- The bat a save is actually holding (falls back to the starter for unknown/unowned ids).
function Bats.Equipped(data): Bat
	local id = data and data.EquippedBat
	local bat = byId[id or ""]
	if bat and (bat.Price == 0 or (data.OwnedBats and data.OwnedBats[bat.Id])) then
		return bat
	end
	return byId[Bats.StarterId]
end

function Bats.Color(bat: Bat): Color3
	return Color3.fromRGB(bat.Color[1], bat.Color[2], bat.Color[3])
end

function Bats.TrailColor(bat: Bat): Color3
	return Color3.fromRGB(bat.Trail[1], bat.Trail[2], bat.Trail[3])
end

-- Why `data` can't buy `bat` (nil = it can). Pure, shared by the shop UI and the server.
function Bats.BuyProblem(data, bat: Bat): string?
	if bat.Price == 0 or data.OwnedBats[bat.Id] then
		return "Owned"
	end
	if (data.Ascension or 0) < bat.RequiredAscension then
		return "Ascension"
	end
	if (data.Cash or 0) < bat.Price then
		return "Cash"
	end
	return nil
end

return Bats
