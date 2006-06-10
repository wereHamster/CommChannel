
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
elseif (lib.libVersion) then
	if (lib.libVersion >= libMinor) then
		return
	else
		lib.libVersion = libMinor
	end
end

--[[
	The AddOn
]]

--[[
	Manager Frame
]]

local delay = 0
local delayMap = {
	["PLAYER_ENTERING_WORLD"] = 8,
	["GUILD_ROSTER_UPDATE"] = 4,
	["PARTY_MEMBERS_CHANGED"] = 2,
	["RAID_ROSTER_UPDATE"] = 2,
}

local memoizeResults = { }
setmetatable(memoizeResults, { __mode = "kv" })

local function memoizeLoadstring(s)
	if (memoizeResults[s] == nil) then
		memoizeResults[s] = loadstring("return "..s)
	end

	return memoizeResults[s]
end

local function onEvent()
	if (event == "CHAT_MSG_CHANNEL") then
		for _, Spec in self.Specs do
			if (Spec.Current and arg8 == GetChannelName(Spec.Current)) then
				if (Spec.Sender.Validate(arg2)) then
					local _, _, module, func, argString = string.find(arg1, "(%a+):(%a+)%((.*)%)")
					if (module and func and argString) then
						local object = Spec.Modules[module]
						if (object and object[func]) then
							local argFunc = memoizeLoadstring(argString)
							
							if (argFunc) then
								setfenv(argFunc, { })
								
								local argList = { pcall(argFunc) }
								if (argList[1]) then
									argList[1] = moduleObject
									object[func](unpack(argList))
								end
							end
						end
					end
				end
			end
		end
	else
		local channelDelay = delayMap[event]
		if (channelDelay) then
			if (lib.Slave.Delay < channelDelay) then
				lib.Slave.Delay = channelDelay
				lib.Slave:Show()
				DEFAULT_CHAT_FRAME:AddMessage("Going to manage channels due to "..event)
			end
		end
	end
end

local function onUpdate()
	-- TODO: use CHAT_MSG_CHANNEL_NOTICE to find out when we've joined the channels
	
	if (arg1 > 1/5) then
		return
	end
	
	delay = delay - arg1
	if (delay < 0) then
		lib:Manage()
		this:Hide()
	end
end

if (lib.Slave == nil) then
	lib.Slave = CreateFrame("Frame", "HealSyncSlave")

	lib.Slave:RegisterEvent("PLAYER_ENTERING_WORLD")
	lib.Slave:RegisterEvent("GUILD_ROSTER_UPDATE")
	lib.Slave:RegisterEvent("PARTY_MEMBERS_CHANGED")
	lib.Slave:RegisterEvent("RAID_ROSTER_UPDATE")
	lib.Slave:RegisterEvent("CHAT_MSG_CHANNEL")

	lib.Slave:SetScript("OnEvent", onEvent)
	lib.Slave:SetScript("OnUpdate", onUpdate)
	
	lib.Slave.Delay = 0
end


--[[
	Private Interface
]]

function lib:Manage()
--	local sig = string.format("CommChannel:Manage()")

	for _, Spec in self.Specs do		
		if (next(Spec.Modules)) then
			Spec.Current = Spec.Name.Generate()
			if (Spec.Current) then
				Spec.Current = string.sub(Spec.Current, 1, 26)
				JoinChannelByName(Spec.Current)
				
--				DEFAULT_CHAT_FRAME:AddMessage(sig..": joining: "..Spec.Current)
			end
		end
		
		local channelList = { GetChannelList() }
		local channelListCount = table.getn(channelList)
		
		for listIndex=1, channelListCount, 2 do
			local chatChannelName = channelList[listIndex + 1]
			
			if (string.find(chatChannelName, Spec.Name.Regexp)) then
				if (chatChannelName ~= Spec.Current) then
--					DEFAULT_CHAT_FRAME:AddMessage(sig..": leaving stale channel: "..chatChannelName)
					LeaveChannelByName(chatChannelName)
				elseif (next(Spec.Modules) == nil) then
--					DEFAULT_CHAT_FRAME:AddMessage(sig..": leaving channel with no registered modules "..chatChannelName)
					LeaveChannelByName(chatChannelName)
				end
			end
		end
	end
end

function lib:ChannelSpec(channel, spec)
	local sig = string.format("CommChannel:Channel(%s, [spec])", name)
	if (self.Specs == nil) then
		self.Specs = { }
	end

	self.Specs[channel] = spec
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
function clientInterface:Call(func, ...)
	lib:Call(self.channel, self.module, func, unpack(arg))
end

function lib:Create(channel, module, iface)
	local sig = string.format("CommChannel:Create(%q, %q, [iface])", channel, module)
	local Spec = self.Specs[channel]
	if (Spec == nil) then
		DEFAULT_CHAT_FRAME:AddMessage(sig..": unknown channel")
		return
	end
	
	if (Spec.Modules[module]) then
		DEFAULT_CHAT_FRAME:AddMessage(sig..": module is already registered")
		return
	end
	
	if (type(iface) ~= "table") then
		DEFAULT_CHAT_FRAME:AddMessage(sig..": iface has wrong type")
		return
	end
	
	Spec.Modules[module] = iface

	local clientModule = { }
	setmetatable(clientModule, { __index = clientInterface })
	clientModule.channel = channel
	clientModule.module = module

	return clientModule
end

function lib:Destroy(channel, module)
	local sig = string.format("CommChannel:Destroy(%q, %q)", channel, module)
	local Spec = self.Specs[channel]
	if (Spec == nil) then
		DEFAULT_CHAT_FRAME:AddMessage(sig..": unknown channel")
		return
	end
	
	if (Spec.Modules[module] == nil) then
		DEFAULT_CHAT_FRAME:AddMessage(sig..": module is not registered")
		return
	end
	
	Spec.Modules[module] = nil

	if (lib.Slave.Delay < 4) then
		lib.Slave.Delay = 4
		lib.Slave:Show()
	end
end


function lib:Call(channel, module, func, ...)
	local sig = string.format("CommChannel:Call(%q, %q, %q, ...)", channel, module, func)
	local Spec = self.Specs[channel]
	if (Spec == nil) then
		DEFAULT_CHAT_FRAME:AddMessage(sig..": unknown channel")
		return
	end
	
	arg.n = nil
	local statusSuccess, objectString = pcall(serializeObject, arg)
	
	if (not statusSuccess) then
		local errorString = string.gsub(objectString, "Interface\\AddOns\\CommChannel\\CommChannel.lua:(%d+): ", "")
		DEFAULT_CHAT_FRAME:AddMessage(sig..": error in serializeObject(): "..errorString)
		return
	end
	
	local serializedString = string.sub(objectString, 2, string.len(objectString) - 1)
	local channelMessage = module..":"..func.."("..serializedString..")"
	
	if (string.len(channelMessage) > 255) then
		DEFAULT_CHAT_FRAME:AddMessage(sig..": channelMessage too big")
		return
	end
	
	if (Spec.Current) then
--		DEFAULT_CHAT_FRAME:AddMessage(sig..": sending message to channel: "..channelMessage)
		SendChatMessage(channelMessage, "CHANNEL", nil, GetChannelName(Spec.Current))
	else
--		DEFAULT_CHAT_FRAME:AddMessage(sig..": no active channel")
	end
end




this = CreateFrame("Frame", "HealSyncSlave")

this:RegisterEvent("PLAYER_ENTERING_WORLD")
--this:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
this:RegisterEvent("GUILD_ROSTER_UPDATE")
this:RegisterEvent("PARTY_MEMBERS_CHANGED")
this:RegisterEvent("RAID_ROSTER_UPDATE")
this:RegisterEvent("CHAT_MSG_CHANNEL")

this:SetScript("OnEvent", onEvent)
this:SetScript("OnUpdate", onUpdate)
