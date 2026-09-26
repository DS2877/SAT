-- THE INFO BOARD (District, beside the spawn pavilion): news, the roadmap, announcements and
-- events players can sign up for. Everything here is written by the dev team and shipped
-- with the game - edit this file and push, and it's live on every server. For something
-- urgent between updates, owners/admins can type "/announce <text>" in chat (NewsService):
-- it goes up on every server's board at once.
--
-- Posts: newest FIRST. Kind = "Announcement" (pinned, gold) or "News".
-- Roadmap: Status = "Done" | "Now" | "Next" | "Later".
-- Events: StartsAt = UTC unix time (os.time()), or nil while the date is still "TBA"
-- (players can already sign up and get pinged when it starts). Duration in seconds.

export type Post = { Id: string, Kind: string, Date: string, Icon: string, Title: string, Body: string }
export type RoadmapItem = { Status: string, Icon: string, Title: string, Text: string }
export type Event = { Id: string, Icon: string, Title: string, Text: string, StartsAt: number?, Duration: number }

local News = {}

News.Posts = {
	{
		Id = "2026-09-26-bats",
		Kind = "Announcement",
		Date = "Sep 26",
		Icon = "🏏",
		Title = "BATS ARE HERE",
		Body = "Bonk is gone - everyone now carries a bat. Not carrying? One slap sends you flying. Carrying? The first slap slows you, the second throws you and you DROP the loot. Eleven bats at the Bat Shop, the best ones behind Ascension.",
	},
	{
		Id = "2026-09-25-falls",
		Kind = "News",
		Date = "Sep 25",
		Icon = "💧",
		Title = "THE FALLS, REBUILT",
		Body = "A jungle river valley below the waterfall: a lagoon island with a sunken idol, cascades, stepping stones - and hidden wind rings that throw you forward. Find them.",
	},
	{
		Id = "2026-09-25-trophy",
		Kind = "News",
		Date = "Sep 25",
		Icon = "🏆",
		Title = "TROPHY PEDESTALS",
		Body = "Your best treasure now stands outside your vault, full size, under a spotlight. Everyone walking past sees what you've stolen.",
	},
	{
		Id = "2026-09-24-south",
		Kind = "News",
		Date = "Sep 24",
		Icon = "🌋",
		Title = "THE DEEP SOUTH",
		Body = "Beyond the Waterfall Mountain: Emberfall, Rimeheart and the Starfall Isles. Ascend to open them, then use the waystones in the District to travel fast.",
	},
}

News.Roadmap = {
	{ Status = "Done", Icon = "🏏", Title = "Bats & slap combat", Text = "11 bats, slap to steal" },
	{ Status = "Done", Icon = "🌋", Title = "The Deep South", Text = "3 new regions + storms" },
	{ Status = "Done", Icon = "🏆", Title = "Trophy pedestals", Text = "Show off your best loot" },
	{ Status = "Now", Icon = "🎙", Title = "Heist Hour", Text = "Live dev-hosted events" },
	{ Status = "Now", Icon = "📰", Title = "Info Board", Text = "News, roadmap, sign-ups" },
	{ Status = "Next", Icon = "👑", Title = "The Dev Crown", Text = "One per server. Steal it." },
	{ Status = "Next", Icon = "✨", Title = "Heisted mutation", Text = "Event-only treasure sheen" },
	{ Status = "Later", Icon = "🌪", Title = "Storm Week", Text = "A 7-day seasonal event" },
	{ Status = "Later", Icon = "🗺", Title = "A new region", Text = "You'll see..." },
}

News.Events = {
	{
		Id = "heist_hour_1",
		Icon = "🎙",
		Title = "HEIST HOUR #1",
		Text = "The devs open the vaults on EVERY server: treasure rain, storms, gold rush - live, for 45 minutes. Sign up and we'll ping you the moment it starts.",
		StartsAt = nil, -- date TBA
		Duration = 45 * 60,
	},
}

News.RemindBefore = 10 * 60 -- signed-up players online get a heads-up this long before start
News.LiveAnnouncementHours = 24 -- how long an "/announce" stays pinned on the board

News.StatusColors = {
	Done = { 90, 210, 120 },
	Now = { 255, 200, 60 },
	Next = { 90, 170, 255 },
	Later = { 170, 140, 255 },
}

function News.GetEvent(id: string): Event?
	for _, event in News.Events do
		if event.Id == id then
			return event
		end
	end
	return nil
end

return News
