
local CommChannel = CommChannel("1.0")
oldChannels = CommChannel.Channels or { }
CommChannel.Channels = { }

--[[
	Helper Functions
]]

local function strip(name)
  return string.gsub(name, "%W", "")
end

local prime = 16777213
local function crc(text)
    local counter = 1
    
    for i=1,string.len(text) do
		counter = counter * ((string.byte(text, i) + i) * 17)
	end
    
    counter = math.mod(counter, prime)
    return string.format("%06X", counter)
end

local function channel(prefix, token, length)
	if (token == nil) then
		return nil
	end
	
	return prefix..string.sub(strip(token), 1, length)..crc(token)
end

--[[
	Guild Channel
]]
local function nameGenerate()
	local guildName = GetGuildInfo("player")
	return channel("CommGu", guildName, 8)
end

local function senderValidate(senderName)
	-- FIXME: how to validate guild members ?
	-- for now we just return true
	
	return true
end

local guildChannel = {
	Name = {
		Regexp = "^CommGu(.+)$",
		Generate = nameGenerate,
	},
	Sender = {
		Validate = senderValidate,
	},
	Current = nil,
}

CommChannel:ChannelSpec("guild", guildChannel, oldChannels["guild"])


--[[
	Group Channel
]]

local function getLeader()
	for raidID=1,GetNumRaidMembers() do
		local unitName, unitRank = GetRaidRosterInfo(raidID)
		if (unitRank == 2) then
			return unitName
		end
	end
	
	if (IsPartyLeader()) then
		return UnitName("player")
	elseif (GetNumPartyMembers() > 0) then
		return UnitName("party"..GetPartyLeaderIndex())
	end
	
	return nil
end

local function nameGenerate()
	local unitName = getLeader()
	return channel("CommRa", unitName, 8)
end

local function senderValidate(senderName)
	for raidID=1,GetNumRaidMembers() do
		if (GetRaidRosterInfo(raidID) == senderName) then
			return true
		end
	end
	
	return false
end

local groupChannel = {
	Name = {
		Regexp = "^CommRa(.+)$",
		Generate = nameGenerate,
	},
	Sender = {
		Validate = senderValidate,
	},
	Current = nil,
}

CommChannel:ChannelSpec("group", groupChannel, oldChannels["group"])
