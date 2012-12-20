--[[
-- slt2 - Simple Lua Template 2
--
-- Project page: https://github.com/henix/slt2
--
-- @License
-- MIT License
--
-- @Copyright
-- Copyright (C) 2012 henix.
--]]

--[[
-- Changelog
--
--	2012-12-20	henix
--		version 2.0
--]]
slt2 = {}

-- process included file
-- @return string
local function precompile(template, start_tag, end_tag)
	local result = {}
	local start_tag_inc = start_tag..'include:'

	local start1, end1 = string.find(template, start_tag_inc, 1, true)
	local start2 = nil
	local end2 = 0

	while start1 ~= nil do
		if start1 > end2 + 1 then -- for beginning part of file
			table.insert(result, string.sub(template, end2 + 1, start1 - 1))
		end
		start2, end2 = string.find(template, end_tag, end1 + 1, true)
		assert(start2, 'end tag "'..end_tag..'" missing')
		do -- recursively include the file
			local filename = assert(loadstring('return '..string.sub(template, end1 + 1, start2 - 1)))()
			assert(filename)
			local fin = assert(io.open(filename))
			-- TODO: detect cyclic inclusion?
			table.insert(result, precompile(fin:read('*a'), start_tag, end_tag))
			fin:close()
		end
		start1, end1 = string.find(template, start_tag_inc, end2 + 1, true)
	end
	table.insert(result, string.sub(template, end2 + 1))
	return table.concat(result)
end

-- @return function
function slt2.loadstring(template, start_tag, end_tag, tmpl_name)
	-- compile it to lua code
	local lua_code = {}

	start_tag = start_tag or '#{'
	end_tag = end_tag or ' }'

	local output_func = "coroutine.yield"

	template = precompile(template, start_tag, end_tag)

	local start1, end1 = string.find(template, start_tag, 1, true)
	local start2 = nil
	local end2 = 0

	local cEqual = string.byte('=', 1)

	while start1 ~= nil do
		if start1 > end2 + 1 then
			table.insert(lua_code, output_func..'('..string.format("%q", string.sub(template, end2 + 1, start1 - 1))..')')
		end
		start2, end2 = string.find(template, end_tag, end1 + 1, true)
		assert(start2, 'end_tag "'..end_tag..'" missing')
		if string.byte(template, end1 + 1) == cEqual then
			table.insert(lua_code, output_func..'('..string.sub(template, end1 + 2, start2 - 1)..')')
		else
			table.insert(lua_code, string.sub(template, end1 + 1, start2 - 1))
		end
		start1, end1 = string.find(template, start_tag, end2 + 1, true)
	end
	table.insert(lua_code, output_func..'('..string.format("%q", string.sub(template, end2 + 1))..')')

	local ret = { name = '=(slt2.loadstring)' }
	if setfenv == nil then -- lua 5.2
		ret.code = table.concat(lua_code, '\n')
	else -- lua 5.1
		ret.code = assert(loadstring(table.concat(lua_code, '\n'), tmpl_name))
	end
	return ret
end

-- @return function
function slt2.loadfile(filename, start_tag, end_tag)
	local fin = assert(io.open(filename))
	local all = fin:read('*a')
	fin:close()
	local ret = slt2.loadstring(all, start_tag, end_tag, filename)
	ret.name = filename
	return ret
end

local mt52 = { __index = _ENV }
local mt51 = { __index = _G }

-- @return a wrapped coroutine
function slt2.render_co(t, env)
	local f
	if setfenv == nil then -- lua 5.2
		if env ~= nil then
			setmetatable(env, mt52)
		end
		f = assert(load(t.code, t.name, 't', env or _ENV))
	else -- lua 5.1
		if env ~= nil then
			setmetatable(env, mt51)
		end
		f = setfenv(t.code, env or _G)
	end
	return coroutine.wrap(f)
end

-- @return string
function slt2.render(t, env)
	local result = {}
	local f = slt2.render_co(t, env)
	local chunk = f()
	while chunk ~= nil do
		table.insert(result, chunk)
		chunk = f()
	end
	return table.concat(result)
end

return slt2
