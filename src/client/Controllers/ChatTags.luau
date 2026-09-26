-- Chat name tags: VIP pass owners get a gold [VIP] prefix, Ascended players their title.
-- Only for the modern TextChatService (legacy chat has no per-message hook).

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local ChatTags = {}

function ChatTags.Init()
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		return
	end
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local properties = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		local speaker = source and Players:GetPlayerByUserId(source.UserId)
		if speaker then
			local prefix = message.PrefixText
			local title = speaker:GetAttribute("Title")
			if type(title) == "string" and title ~= "" then
				prefix = ('<font color="#C896FF">[%s]</font> %s'):format(title, prefix)
			end
			if speaker:GetAttribute("Pass_VIP") then
				prefix = '<font color="#FFD23C">[VIP]</font> ' .. prefix
			end
			properties.PrefixText = prefix
		end
		return properties
	end
end

return ChatTags
