
--[[
	Embedded Library Stub
]]

local libName, libMajor, libMinor = "CommChannel", "1.0", tonumber(string.sub("$Revision$", 12, -3))
local libMetatable = { __call = function(self, major) self[major] = self[major] or { }; return self[major] end }

if (getglobal(libName) == nil) then
	setglobal(libName, setmetatable({ }, libMetatable))
end

local lib = getglobal(libName)(libMajor)
if (lib.libVersion and lib.libVersion >= libMinor) then
	return
end

lib.libVersion = libMinor

--[[
	The AddOn
]]

local prefix = "⠀" -- U+2800 BRAILLE PATTERN BLANK

local match = string.match
local format = string.format
local gsub = string.gsub
local sub = string.sub

local argLists = setmetatable({ }, { __mode = "kv" })
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

local function onEvent(self, event, arg1, arg2, arg3)
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
	self.Channels[channel][module] = iface
	return setmetatable({ channel, module }, clientMetatable)
end

function lib:Destroy(channel, module)
	self.Channels[channel][module] = nil
end

function lib:Call(channel, module, func, ...)	
	local str = ""
	for idx=1,select("#", ...) do
		local ret, tmp = pcall(serializeObject, select(idx, ...))
		if (not ret) then
			tmp = gsub(tmp, "(.*)CommChannel.lua:(%d+): ", "")
			DEFAULT_CHAT_FRAME:AddMessage("CommChannel: error in serialization: "..tmp)
			return
		end
		
		str = format("%s,%s", str, tmp)
	end
	
	SendAddonMessage(prefix, module..":"..func.."("..sub(str, 2)..")", channel)
end
