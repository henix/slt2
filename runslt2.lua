#!/usr/bin/env lua

--[[
-- runslt2 - Render a template, as a standalone command
--
-- Project page: https://github.com/henix/slt2
--
-- @License
-- MIT License
--
-- @Copyright
-- Copyright (C) 2012-2013 henix.
--]]

local slt2 = require('slt2')

local valueStr = nil
local template = nil
local luadef = nil

if #arg ~= 2 and #arg ~= 4 and #arg ~= 6 then
	print([[Usage:
1. runslt2.lua [-d luafile] -v '{name=value;luatable}' < template_file
2. runslt2.lua [-d luafile] -t template_file < lua_value_file
3. runslt2.lua [-d luafile] -v '{name=value;luatable}' -t template_file]])
	os.exit(1)
end

while #arg > 0 do
	local param = table.remove(arg, 1)
	if param == '-v' then
		if valueStr ~= nil then
			print('param -v duplicated')
			os.exit(2)
		end
		valueStr = table.remove(arg, 1)
	elseif param == '-t' then
		if template ~= nil then
			print('param -t duplicated')
			os.exit(2)
		end
		local filename = table.remove(arg, 1)
		local fin = assert(io.open(filename))
		template = fin:read('*a')
		fin:close()
	elseif param == '-d' then
		luadef = table.remove(arg, 1)
	else
		print('Unknown param: '..param)
		os.exit(2)
	end
end

if valueStr == nil and template == nil then
	print('-v and -t must specify at least one')
	os.exit(2)
end

if valueStr == nil then
	valueStr = io.read('*a')
elseif template == nil then
	template = io.read('*a')
end

if luadef ~= nil then
	dofile(luadef)
end

local value = nil
if loadstring ~= nil then -- lua 5.1 / luajit 2.0
	value = assert(loadstring('return '..valueStr))()
else -- lua 5.2
	value = assert(load('return '..valueStr))()
end

io.write(slt2.render(slt2.loadstring(template), value))
