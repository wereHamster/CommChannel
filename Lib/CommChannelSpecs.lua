
local CommChannel = CommChannel("1.0")

--[[
	Guild Channel
]]
local function nameGenerate()
	local guildName = GetGuildInfo("player")
	
	if (guildName) then
		-- remove whitespaces
		guildName = string.gsub(guildName, "[^%w]", "");
		
		return "guildChannel"..guildName
	end
	
	return nil
end

local function senderValidate(senderName)
	-- FIXME: how to validate guild members ?
	-- for now we just return true
	
	return true
end

local guildChannel = {
	Name = {
		Regexp = "^guildChannel(.+)$",
		Generate = nameGenerate,
	},
	Sender = {
		Validate = senderValidate,
	},
	Current = nil,
	Modules = { },
}

CommChannel:ChannelSpec("guild", guildChannel)


--[[
	Raid Channel
]]

local function nameGenerate()
	for raidID=1,GetNumRaidMembers() do
		local unitName, unitRank = GetRaidRosterInfo(raidID)
		if (unitRank == 2) then
			return "raidChannel"..unitName
		end
	end
	
	return nil
end

local function senderValidate(senderName)
	for raidID=1,GetNumRaidMembers() do
		if (GetRaidRosterInfo(raidID) == senderName) then
			return true
		end
	end
	
	return false
end

local raidChannel = {
	Name = {
		Regexp = "^raidChannel(.+)$",
		Generate = nameGenerate,
	},
	Sender = {
		Validate = senderValidate,
	},
	Current = nil,
	Modules = { },
}

CommChannel:ChannelSpec("raid", raidChannel)


--[[
	Sync Channel
]]

local function nameGenerate()
	for raidID=1,GetNumRaidMembers() do
		local unitName, unitRank = GetRaidRosterInfo(raidID)
		if (unitRank == 2) then
			return "syncChannel"..unitName
		end
	end
	
	if (IsPartyLeader()) then
		return "syncChannel"..UnitName("player")
	elseif (GetNumPartyMembers() > 0) then
		return "syncChannel"..UnitName("party"..GetPartyLeaderIndex())
	end
	
	return nil
end

local function senderValidate(senderName)
	for raidID=1,GetNumRaidMembers() do
		local raidName = GetRaidRosterInfo(raidID)
		if (raidName == senderName) then
			return true
		end
	end
	
	for partyID=1,GetNumPartyMembers() do
		if (UnitName("party"..partyID) == senderName) then
			return true
		end
	end
	
	if (UnitName("player") == senderName) then
		return true
	end
	
	return false
end


local syncChannel = {
	Name = {
		Regexp = "^syncChannel(.+)$",
		Generate = nameGenerate,
	},
	Sender = {
		Validate = senderValidate,
	},
	Current = nil,
	Modules = { },
}

CommChannel:ChannelSpec("sync", syncChannel)
