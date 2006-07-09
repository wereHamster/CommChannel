
--[[
	Embedded Library Stub
]]

local libName, libMajor, libMinor = "CommChannel", "1.0", tonumber(string.sub("$Revision$", 12, -3))

local libMetatable = {
	__call = function(stub, major, minor)
		if (minor) then
			stub[major] = { }
			stub[major].libVersion = minor
		end
		return stub[major]
	end,
}

if (getglobal(libName) == nil) then
	setglobal(libName, setmetatable({ }, libMetatable))
end

local stub = getglobal(libName)

local lib = stub(libMajor)
if (lib == nil) then
	lib = stub(libMajor, libMinor)
elseif (lib.libVersion >= libMinor) then
	return
else
	lib.libVersion = libMinor
end

--[[
	The AddOn
]]

local function encode(text)
	text = string.gsub(text, "([h°])", "°%1")
	return text.."°"
end

local function decode(text)
	text = string.gsub(text, "([Ss])h", "%1")
	text = string.gsub(text, "°([h°])", "%1")
	text = string.gsub(text, "^(.*)°.-$", "%1")
	return text
end
--[[
	Manager Frame
]]

local delayMap = {
	["PLAYER_ENTERING_WORLD"] = 8,
	["GUILD_ROSTER_UPDATE"] = 4,
	["PARTY_MEMBERS_CHANGED"] = 2,
	["RAID_ROSTER_UPDATE"] = 2,
	["CHAT_MSG_RAID"] = 2,
}

local argLists = { }
setmetatable(argLists, { __mode = "kv" })

local function loadArgs(s)
	if (argLists[s] == nil) then
		argFunc = loadstring("return "..s)
		if (argFunc) then
			setfenv(argFunc, { })
			argList = { pcall(argFunc) }
			if (argList[1]) then
				argLists[s] = argList
			end
		end
	end

	return argLists[s]
end

local function onEvent()
	if (event == "CHAT_MSG_CHANNEL") then
		for _, Channel in lib.Channels do
			if (Channel.Spec.Current and arg8 == GetChannelName(Channel.Spec.Current)) then
				if (Channel.Spec.Sender.Validate(arg2)) then
					arg1 = decode(arg1)
					local _, _, module, func, argString = string.find(arg1, "(%a-):(%a-)%((.*)%)")
					if (module and func and argString) then
						local object = Channel.Modules[module]
						if (object and object[func]) then
							local argList = loadArgs(argString)
							
							if (argList) then
								argList[1] = object
								object[func](unpack(argList))
							end
						end
					end
				end
			end
		end
		
		return
	elseif (event == "CHAT_MSG_RAID") then
		local _, _, token = string.find(arg1, "Securing CommChannel: (.*)")
		if (token) then
			lib.Channels["raid"].Spec.Name.Token = (token == "(none)") and nil or token
		end
	end
	
	lib:UpdateChannels(assert(delayMap[event]))
end

local function onUpdate()
	-- TODO: use CHAT_MSG_CHANNEL_NOTICE to find out when we've joined the channels
	if (arg1 > 1/5) then
		return
	end
	
	lib.Slave.Delay = lib.Slave.Delay - arg1
	if (lib.Slave.Delay < 0) then
		if (lib.Slave.Action == "Leave") then
			lib.Slave.Action = "Join"
			lib.Slave.Delay = 1
			
			leaveChannels()
		else
			lib.Slave.Action = nil
			lib.Slave:Hide()
			
			joinChannels()
		end
	end
end

if (lib.Slave == nil) then
	lib.Slave = CreateFrame("Frame", "CommChannelSlave")

	lib.Slave:RegisterEvent("PLAYER_ENTERING_WORLD")
	lib.Slave:RegisterEvent("GUILD_ROSTER_UPDATE")
	lib.Slave:RegisterEvent("PARTY_MEMBERS_CHANGED")
	lib.Slave:RegisterEvent("RAID_ROSTER_UPDATE")
	lib.Slave:RegisterEvent("CHAT_MSG_CHANNEL")
	lib.Slave:RegisterEvent("CHAT_MSG_RAID")

	lib.Slave:SetScript("OnEvent", onEvent)
	lib.Slave:SetScript("OnUpdate", onUpdate)
	
	lib.Slave.Delay = 0
end


--[[
	Private Functions
]]

function leaveChannels()
--	local sig = string.format("leaveChannels()")

	for k, Channel in lib.Channels do
		Channel.Spec.Current = next(Channel.Modules) and Channel.Spec.Name.Generate() or nil
		
		local channelList = { GetChannelList() }
		local channelListCount = table.getn(channelList)
		
		for listIndex=1, channelListCount, 2 do
			local chatChannelName = channelList[listIndex + 1]
			
			if (string.find(chatChannelName, Channel.Spec.Name.Regexp)) then
				if (chatChannelName ~= Channel.Spec.Current) then
--					DEFAULT_CHAT_FRAME:AddMessage(sig..": leaving stale channel: "..chatChannelName)
					LeaveChannelByName(chatChannelName)
				elseif (next(Channel.Modules) == nil) then
--					DEFAULT_CHAT_FRAME:AddMessage(sig..": leaving channel with no registered modules "..chatChannelName)
					LeaveChannelByName(chatChannelName)
				end
			end
		end
	end
end

function joinChannels()
--	local sig = string.format("joinChannels()")

	for k, Channel in lib.Channels do
		if (next(Channel.Modules)) then
			if (Channel.Spec.Current) then
				Channel.Spec.Current = string.sub(Channel.Spec.Current, 1, 26)
				JoinChannelByName(Channel.Spec.Current)
				
--				DEFAULT_CHAT_FRAME:AddMessage(sig..": joining: "..Channel.Spec.Current)
			end
		end
	end
end

function lib:UpdateChannels(delay)
	if (lib.Slave.Delay < delay or lib.Slave.Action == "Join") then
		lib.Slave.Delay = delay
		lib.Slave.Action = "Leave"
		lib.Slave:Show()
	end
end

function lib:ChannelSpec(channel, spec, old)
--	local sig = string.format("CommChannel:Channel(%s, [spec])", channel)

	self.Channels[channel] = { }
	self.Channels[channel].Spec = spec
	self.Channels[channel].Modules = old and old.Modules or { }
end



--[[
	Object Serialization
]]

local function getTableCount(luaTable)
	local tableCount = 0
	
	for _, _ in pairs(luaTable) do 
		tableCount = tableCount + 1
	end
	
	return tableCount
end

local function serializeObject(luaObject)
	if (luaObject == nil) then
		return "" 
	elseif type(luaObject) == "string" then
		return string.format("%q", luaObject)
	elseif type(luaObject) == "table" then
		local serializedString = "{"
 
		if luaObject[1] and table.getn(luaObject) == getTableCount(luaObject) then
			for i = 1, table.getn(luaObject) do
				serializedString = serializedString..serializeObject(luaObject[i])..","
			end
		else
			for tableKey, tableValue in pairs(luaObject) do
				if (type(tableKey) == "number") then
					serializedString = serializedString.."["..tableKey.."]="
				elseif (type(tableKey) == "string") then
					serializedString = serializedString..tableKey.."="
				else
					error("table key has unsupported type: " .. type(luaObject))
				end

				serializedString = serializedString..serializeObject(tableValue)..","
			end
		end

		return string.sub(serializedString, 0, string.len(serializedString) - 1).."}"
	elseif type(luaObject) == "number" then
		return tostring(luaObject)
	elseif type(luaObject) == "boolean" then
		return luaObject and "true" or "false"
	else
		error("can't serialize a " .. type(luaObject))
	end
end



--[[
	Public Interface
]]

local clientInterface = { }
local clientMetatable = { __index = clientInterface }

function clientInterface:Call(func, ...)
	lib:Call(self.channel, self.module, func, unpack(arg))
end

function lib:Create(channel, module, iface)
	local sig = string.format("CommChannel:Create(%q, %q, [iface])", channel, module)
	local Channel = self.Channels[channel]
	if (Channel == nil) then
		DEFAULT_CHAT_FRAME:AddMessage(sig..": unknown channel")
		return
	end
	
	if (Channel.Modules[module]) then
		DEFAULT_CHAT_FRAME:AddMessage(sig..": module is already registered")
		return
	end
	
	if (type(iface) ~= "table") then
		DEFAULT_CHAT_FRAME:AddMessage(sig..": iface has wrong type")
		return
	end
	
	Channel.Modules[module] = iface

	local clientModule = { }
	setmetatable(clientModule, clientMetatable)
	clientModule.channel = channel
	clientModule.module = module

	return clientModule
end

function lib:Destroy(channel, module)
	local sig = string.format("CommChannel:Destroy(%q, %q)", channel, module)
	local Channel = self.Channels[channel]
	if (Channel == nil) then
		DEFAULT_CHAT_FRAME:AddMessage(sig..": unknown channel")
		return
	end
	
	if (Channel.Modules[module] == nil) then
		DEFAULT_CHAT_FRAME:AddMessage(sig..": module is not registered")
		return
	end
	
	Channel.Modules[module] = nil

	lib:UpdateChannels(4)
end


function lib:Call(channel, module, func, ...)
	local sig = string.format("CommChannel:Call(%q, %q, %q, ...)", channel, module, func)
	local Channel = self.Channels[channel]
	if (Channel == nil) then
		DEFAULT_CHAT_FRAME:AddMessage(sig..": unknown channel")
		return
	end
	
	arg.n = nil
	local success, msg = pcall(serializeObject, arg)
	
	if (not success) then
		msg = string.gsub(msg, "Interface\\AddOns\\(.*)\\CommChannel.lua:(%d+): ", "")
		DEFAULT_CHAT_FRAME:AddMessage(sig..": error in serializeObject(): "..msg)
		return
	end
	
	local msg = string.sub(msg, 2, string.len(msg) - 1)
	msg = encode(module..":"..func.."("..msg..")")
	
	if (string.len(msg) > 255) then
		DEFAULT_CHAT_FRAME:AddMessage(sig..": channelMessage too big")
		return
	end
	
	if (Channel.Spec.Current) then
--		DEFAULT_CHAT_FRAME:AddMessage(sig..": sending message to channel: "..channelMessage)
		SendChatMessage(msg, "CHANNEL", nil, GetChannelName(Channel.Spec.Current))
	else
--		DEFAULT_CHAT_FRAME:AddMessage(sig..": no active channel")
	end
end

function lib:Secure(channel, token)
	local sig = string.format("CommChannel:Secure(%q, %q)", channel, token)
	
	if (channel == "raid") then
		for raidID=1,GetNumRaidMembers() do
			local name, rank = GetRaidRosterInfo(raidID)
			if (name == UnitName("player")) then
				if (rank < 2) then
					DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: Only the raid leader can secure the raid channel.", sig))
					return
				end
			end
		end
		
		SendChatMessage("RAID", "Securing CommChannel: "..(token or "(none)"))
	else
		DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: Channel not supported.", sig))
	end
end
