-- Parses admin chat commands for server events (pure, so it's unit-tested):
--   "/event rain"      -> this server only
--   "/event all rain"  -> every live server at once (a hosted "Heist Hour" drop)
-- Returns the event id (resolved through `aliases`) and whether it's global, or nil when the
-- message isn't an event command. An unknown name still returns { Name = name } so the
-- caller can answer with a hint.

local AdminCommand = {}

export type Parsed = { Name: string, EventId: string?, Global: boolean }

function AdminCommand.Parse(message: string, aliases: { [string]: string }): Parsed?
	local text = string.lower(message)
	local scope, name = string.match(text, "^/event%s+(%a+)%s+(%w+)")
	if scope ~= "all" and scope ~= "global" then
		scope, name = nil, string.match(text, "^/event%s+(%w+)")
	end
	if not name then
		return nil
	end
	return { Name = name, EventId = aliases[name], Global = scope ~= nil }
end

return AdminCommand
