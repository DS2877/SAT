-- Pure rules for the Info Board (Config/News): event status, which event to feature, the
-- countdown text, and whether a player has unread posts. Unit-tested (tests/run.luau).

local NewsBoard = {}

export type Event = { Id: string, StartsAt: number?, Duration: number }

-- "TBA" (no date yet), "Upcoming", "Live" or "Ended".
function NewsBoard.Status(event: Event, now: number): string
	local startsAt = event.StartsAt
	if not startsAt then
		return "TBA"
	elseif now < startsAt then
		return "Upcoming"
	elseif now < startsAt + event.Duration then
		return "Live"
	end
	return "Ended"
end

-- The event to feature: live first, then the soonest upcoming, then one still TBA.
function NewsBoard.Featured(events: { Event }, now: number): Event?
	local best, bestRank, bestTime = nil, math.huge, math.huge
	for _, event in events do
		local status = NewsBoard.Status(event, now)
		local rank = if status == "Live" then 1 elseif status == "Upcoming" then 2 elseif status == "TBA" then 3 else nil
		local time = event.StartsAt or math.huge
		if rank and (rank < bestRank or (rank == bestRank and time < bestTime)) then
			best, bestRank, bestTime = event, rank, time
		end
	end
	return best
end

-- "2d 4h", "3h 12m", "12m 05s", "45s".
function NewsBoard.Countdown(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local d, h, m, s = seconds // 86400, (seconds % 86400) // 3600, (seconds % 3600) // 60, seconds % 60
	if d > 0 then
		return ("%dd %dh"):format(d, h)
	elseif h > 0 then
		return ("%dh %02dm"):format(h, m)
	elseif m > 0 then
		return ("%dm %02ds"):format(m, s)
	end
	return ("%ds"):format(s)
end

-- One line for the board / an event card.
function NewsBoard.When(event: Event, now: number): string
	local status = NewsBoard.Status(event, now)
	if status == "TBA" then
		return "DATE COMING SOON"
	elseif status == "Upcoming" then
		return "STARTS IN " .. NewsBoard.Countdown((event.StartsAt :: number) - now)
	elseif status == "Live" then
		return "🔴 LIVE NOW • " .. NewsBoard.Countdown((event.StartsAt :: number) + event.Duration - now) .. " LEFT"
	end
	return "ENDED"
end

-- Posts are newest first: anything above the one the player last read is new.
function NewsBoard.UnreadCount(posts: { { Id: string } }, lastSeenId: string?): number
	for i, post in posts do
		if post.Id == lastSeenId then
			return i - 1
		end
	end
	return #posts
end

return NewsBoard
