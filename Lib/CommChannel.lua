
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

local prefix = "⠀" -- U+2800 BRAILLE PATTERN BLANK

local match = string.match
local format = string.format
local gsub = string.gsub
local sub = string.sub

local argLists = { }
setmetatable(argLists, { __mode = "kv" })

local function loadArgs(s)
	if (argLists[s] == nil) then
		local argFunc = loadstring("return "..s)
		if (argFunc) then
			setfenv(argFunc, { })
			local argList = { pcall(argFunc) }
			if (argList[1]) then
				argLists[s] = argList
			end
		end
	end

	return argLists[s]
end

local function onEvent()
	if (arg1 == prefix) then
		local Channel = lib.Channels[arg3]
		local module, func, argString = match(arg2, "^(%a-):(%a-)%((.*)%)$")
		if (module and func and argString) then
			local object = Channel[module]
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

if (lib.Channels == nil) then
	lib.Channels = { ["GUILD"] = { }, ["PARTY"] = { }, ["RAID"] = { }, ["BATTLEGROUND"] = { } }
	
	lib.Slave = CreateFrame("Frame")
	lib.Slave:RegisterEvent("CHAT_MSG_ADDON")
end
lib.Slave:SetScript("OnEvent", onEvent)


--[[
	Object Serialization
]]

local function count(tbl)
	local num = 0
	for _, _ in pairs(tbl) do num = num + 1 end
	return num
end

local function serializeObject(obj)
	if (obj == nil) then
		return "" 
	elseif (type(obj) == "string") then
		return format("%q", obj)
	elseif (type(obj) == "table") then
		local str = "{"
		
		if (next(obj) == nil) then
			return "{}"
		elseif (obj[1] and table.getn(obj) == count(obj)) then
			for i = 1, table.getn(obj) do
				str = str..serializeObject(obj[i])..","
			end
		else
			for key, val in pairs(obj) do
				if (type(key) == "number") then
					str = str.."["..val.."]="
				elseif (type(key) == "string") then
					str = str..val.."="
				else
					error("table key has unsupported type: " .. type(key))
				end

				str = str..serializeObject(val)..","
			end
		end

		return sub(str, 0, -1).."}"
	elseif (type(obj) == "number") then
		return tostring(obj)
	elseif (type(obj) == "boolean") then
		return obj and "true" or "false"
	else
		error("can't serialize a " .. type(obj))
	end
end



--[[
	Public Interface
]]

local clientInterface = { }
local clientMetatable = { __index = clientInterface }

function clientInterface:Call(func, ...)
	lib:Call(self[1], self[2], func, ...)
end

function lib:Create(channel, module, iface)
	local sig = format("CommChannel:Create(%q, %q, [iface])", channel, module)
	local Channel = self.Channels[channel]
	if (Channel == nil) then
		DEFAULT_CHAT_FRAME:AddMessage(sig..": unknown channel")
		return
	end
	
	if (Channel[module]) then
		DEFAULT_CHAT_FRAME:AddMessage(sig..": module is already registered")
		return
	end
	
	if (type(iface) ~= "table") then
		DEFAULT_CHAT_FRAME:AddMessage(sig..": iface has wrong type")
		return
	end
	
	Channel[module] = iface

	return setmetatable({ channel, module }, clientMetatable)
end

function lib:Destroy(channel, module)
	local sig = format("CommChannel:Destroy(%q, %q)", channel, module)
	local Channel = self.Channels[channel]
	if (Channel == nil) then
		DEFAULT_CHAT_FRAME:AddMessage(sig..": unknown channel")
		return
	end
	
	if (Channel[module] == nil) then
		DEFAULT_CHAT_FRAME:AddMessage(sig..": module is not registered")
		return
	end
	
	Channel[module] = nil
end


function lib:Call(channel, module, func, ...)
	local sig = format("CommChannel:Call(%q, %q, %q, ...)", channel, module, func)
	local Channel = self.Channels[channel]
	if (Channel == nil) then
		DEFAULT_CHAT_FRAME:AddMessage(sig..": unknown channel")
		return
	end
	
	local str = ""
	for idx=1,select("#", ...) do
		local ret, tmp = pcall(serializeObject, select(idx, ...))
		if (not ret) then
			tmp = gsub(tmp, "(.*)CommChannel.lua:(%d+): ", "")
			DEFAULT_CHAT_FRAME:AddMessage(sig..": error in serializeObject(): "..tmp)
			return
		end
		
		str = format("%s,%s", str, tmp)
	end
	
	local msg = module..":"..func.."("..sub(str, 2)..")"
	
	if (#msg > (255 - 12)) then
		DEFAULT_CHAT_FRAME:AddMessage(sig..": channelMessage too big")
		return
	end
	
	SendAddonMessage(prefix, msg, channel)
end
