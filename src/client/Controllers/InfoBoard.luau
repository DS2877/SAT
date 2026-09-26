-- The Info Board in the District (built by WorldBuilder, content Config/News): keeps its face
-- live on this client - the featured event's countdown and sign-up count, the red "/announce"
-- strip - and runs the marquee bulbs like a theatre sign.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local News = require(Shared.Config.News)
local NewsBoard = require(Shared.Logic.NewsBoard)

local ClientState = require(script.Parent.Parent.ClientState)

local InfoBoard = {}

local WARM = Color3.fromRGB(255, 220, 120)
local WHITE = Color3.new(1, 1, 1)
local DIM = Color3.fromRGB(120, 90, 50)

local function find(gui: Instance, path: { string }): Instance?
	local node: Instance? = gui
	for _, name in path do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local function setText(gui: Instance, path: { string }, text: string)
	local label = find(gui, path)
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

local function update(panel: Instance)
	local gui = panel:FindFirstChild("InfoFace")
	if not gui then
		return
	end
	local now = math.floor(workspace:GetServerTimeNow())
	local live = workspace:GetAttribute("NewsLiveText")
	local strip = gui:FindFirstChild("Live")
	if strip and strip:IsA("GuiObject") then
		strip.Visible = type(live) == "string" and live ~= ""
		setText(gui, { "Live", "LiveText" }, "📢 " .. (if type(live) == "string" then live else ""))
	end
	local event = NewsBoard.Featured(News.Events, now)
	if event then
		local e = event :: any
		setText(gui, { "Event", "EventTitle" }, ("%s %s"):format(e.Icon, e.Title))
		setText(gui, { "Event", "EventWhen" }, NewsBoard.When(event, now))
		local n = tonumber(workspace:GetAttribute("Signups_" .. event.Id)) or 0
		setText(gui, { "Event", "EventSignups" }, ("👥 %d signed up"):format(n))
		local data = ClientState.Data
		local signedUp = data and data.EventSignups and data.EventSignups[event.Id] ~= nil
		setText(gui, { "Event", "EventHint" }, if signedUp then "✔ YOU'RE SIGNED UP" else "▶ SIGN UP AT THE BOARD")
	else
		setText(gui, { "Event", "EventTitle" }, "More events soon")
		setText(gui, { "Event", "EventWhen" }, "")
		setText(gui, { "Event", "EventSignups" }, "")
		setText(gui, { "Event", "EventHint" }, "")
	end
end

function InfoBoard.Init()
	task.spawn(function()
		local phase = 0
		local ticks = 0
		while true do
			phase = (phase + 1) % 3
			-- Chasing bulbs: every third one lit, stepping along (cheap: colour only).
			for i, bulb in CollectionService:GetTagged("InfoBulb") do
				if bulb:IsA("BasePart") then
					bulb.Color = if (i + phase) % 3 == 0 then WHITE elseif (i + phase) % 3 == 1 then WARM else DIM
				end
			end
			ticks += 1
			if ticks % 3 == 0 then -- the face once a second
				for _, panel in CollectionService:GetTagged("InfoBoard") do
					update(panel)
				end
			end
			task.wait(1 / 3)
		end
	end)
end

return InfoBoard
