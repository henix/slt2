--[[
-- slt2 - Simple Lua Template 2
--
-- Project page: https://github.com/henix/slt2
--
-- @License
-- MIT License
--]]

local slt2 = {}

-- escape a string for use in lua patterns
-- (this simply prepends all non alphanumeric characters with '%'
local function escape_pattern(text)
	return text:gsub("([^%w])", "%%%1" --[[function (match) return "%"..match end--]])
end

-- creates an iterator that iterates over all chunks in the given template
-- a chunk is either a template delimited by start_tag and end_tag or a normal text
local function all_chunks(template, start_tag, end_tag)
	-- pattern to match a template chunk
	local pattern = escape_pattern(start_tag) .. ".-" .. escape_pattern(end_tag)
	local position = 1

	return function ()
		if not position then
			return nil
		end

		local template_start, template_end = template:find(pattern, position)

		if template_start == position then -- next chunk is a template chunk
			position = template_end + 1
			return template:sub(template_start, template_end)
		elseif template_start then -- next chunk is a text chunk
			local chunk = template:sub(position, template_start - 1)
			position = template_start
			return chunk
		else -- no template chunk found --> either text chunk until end of file or no chunk at all
			chunk = template:sub(position)
			position = nil
			return (#chunk > 0) and chunk or nil
		end
	end
end

local function read_entire_file(path)
	assert(path)
	local file = assert(io.open(path))
	local file_content = file:read('*a')
	file:close()
	return file_content
end

local function parse_string_literal(string_literal)
	print("string_literal:", string_literal )
	local f = loadstring('return' .. string_literal)
	return f()
end

-- a tree fold on inclusion tree
-- @param init_func: must return a new value when called
local function include_fold(template, start_tag, end_tag, fold_func, init_func)
	local result = init_func()

	start_tag = start_tag or '#{'
	end_tag = end_tag or '}#'
	local start_tag_inc = start_tag..'include:'

	local start1, end1 = string.find(template, start_tag_inc, 1, true)
	local start2 = nil
	local end2 = 0

	while start1 ~= nil do
		if start1 > end2 + 1 then -- for beginning part of file
			result = fold_func(result, string.sub(template, end2 + 1, start1 - 1))
		end
		start2, end2 = string.find(template, end_tag, end1 + 1, true)
		assert(start2, 'end tag "'..end_tag..'" missing')
		do -- recursively include the file
			local filename = assert(loadstring('return '..string.sub(template, end1 + 1, start2 - 1)))()
			assert(filename)
			local fin = assert(io.open(filename))
			-- TODO: detect cyclic inclusion?
			result = fold_func(result, include_fold(fin:read('*a'), start_tag, end_tag, fold_func, init_func), filename)
			fin:close()
		end
		start1, end1 = string.find(template, start_tag_inc, end2 + 1, true)
	end
	result = fold_func(result, string.sub(template, end2 + 1))
	return result
end

-- preprocess included files
-- @return string
function slt2.precompile(template, start_tag, end_tag)
	return table.concat(include_fold(template, start_tag, end_tag, function(acc, v)
		if type(v) == 'string' then
			table.insert(acc, v)
		elseif type(v) == 'table' then
			table.insert(acc, table.concat(v))
		else
			error('Unknown type: '..type(v))
		end
		return acc
	end, function() return {} end))
end

-- unique a list, preserve order
local function stable_uniq(t)
	local existed = {}
	local res = {}
	for _, v in ipairs(t) do
		if not existed[v] then
			table.insert(res, v)
			existed[v] = true
		end
	end
	return res
end

-- @return { string }
function slt2.get_dependency(template, start_tag, end_tag)
	return stable_uniq(include_fold(template, start_tag, end_tag, function(acc, v, name)
		if type(v) == 'string' then
		elseif type(v) == 'table' then
			if name ~= nil then
				table.insert(acc, name)
			end
			for _, subname in ipairs(v) do
				table.insert(acc, subname)
			end
		else
			error('Unknown type: '..type(v))
		end
		return acc
	end, function() return {} end))
end

-- @return { name = string, code = string / function}
function slt2.loadstring(template, start_tag, end_tag, tmpl_name)
	-- compile it to lua code
	local lua_code = {}

	start_tag = start_tag or '#{'
	end_tag = end_tag or '}#'

	local output_func = "coroutine.yield"

	template = slt2.precompile(template, start_tag, end_tag)

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

	local ret = { name = tmpl_name or '=(slt2.loadstring)' }
	if setfenv == nil then -- lua 5.2
		ret.code = table.concat(lua_code, '\n')
	else -- lua 5.1
		ret.code = assert(loadstring(table.concat(lua_code, '\n'), ret.name))
	end
	return ret
end

-- @return { name = string, code = string / function }
function slt2.loadfile(filename, start_tag, end_tag)
	local fin = assert(io.open(filename))
	local all = fin:read('*a')
	fin:close()
	return slt2.loadstring(all, start_tag, end_tag, filename)
end

local mt52 = { __index = _ENV }
local mt51 = { __index = _G }

-- @return a coroutine function
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
	return f
end

-- @return string
function slt2.render(t, env)
	local result = {}
	local co = coroutine.create(slt2.render_co(t, env))
	while coroutine.status(co) ~= 'dead' do
		local ok, chunk = coroutine.resume(co)
		if not ok then
			error(chunk)
		end
		table.insert(result, chunk)
	end
	return table.concat(result)
end

return slt2
