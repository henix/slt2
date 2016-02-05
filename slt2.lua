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

-- splits a template into chunks
-- chunks are either a template delimited by start_tag and end_tag
-- or a text chunk (everything else)
-- @return table
function slt2.lex(template, start_tag, end_tag, output)
	local output = output or {}
	local include_pattern = "^" .. escape_pattern(start_tag) .. "include:(.-)" .. escape_pattern(end_tag)

	for chunk in all_chunks(template, start_tag, end_tag) do
		-- handle includes
		local include_path_literal = chunk:match(include_pattern)
		if include_path_literal then -- include chunk
			local path = parse_string_literal(include_path_literal)
			local included_template = read_entire_file(path)
			slt2.lex(included_template, start_tag, end_tag, output)
			-- FIXME: This can result in 2 text chunks following each other
		else -- other chunk
			table.insert(output, chunk)
		end

	end

	return output
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
function slt2.loadstring(template, template_name, options)
	options = options or {}
	options.start_tag = options.start_tag or '#{'
	options.end_tag = options.end_tag or '}#'
	options.template_name = template_name or '=(slt2.loadstring)'

	local output_function = "coroutine.yield"

	-- split the template string into chunks
	local lexed_template = slt2.lex(template, options.start_tag, options.end_tag)

	-- pattern to match different kinds of templates
	local expression_pattern = escape_pattern(options.start_tag) .. "=(.-)" .. escape_pattern(options.end_tag)
	local code_pattern = escape_pattern(options.start_tag) .. "([^=].-)" .. escape_pattern(options.end_tag)

	-- table of code fragments the template is compiled into
	local lua_code = {}

	for i, chunk in ipairs(lexed_template) do
		-- check if the chunk is a template (either code or expression)
		local expression = chunk:match(expression_pattern)
		local code = expression and nil or chunk:match(code_pattern)

		if expression then
			table.insert(lua_code, output_function..'('..expression..')')
		elseif code then
			table.insert(lua_code, code)
		else
			table.insert(lua_code, output_function..'('..string.format("%q", chunk)..')')
		end
	end

	local complete_template = {
		name = options.template_name,
		code = table.concat(lua_code, '\n') --TODO: Check if this works with Lua 5.1
	}

	return complete_template
end

-- @return { name = string, code = string / function }
function slt2.loadfile(filename, start_tag, end_tag)
	local file_content = read_entire_file(filename)
	local options = {
		start_tag = start_tag,
		end_tag = end_tag
	}
	return slt2.loadstring(file_content, filename, options)
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
