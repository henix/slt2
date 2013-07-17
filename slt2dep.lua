#!/usr/bin/env lua

local slt2 = require('slt2')

if #arg > 1 then
	print('Usage: slt2dep.lua filename')
	os.exit(1)
end

local content

if #arg == 1 then
	local fin = assert(io.open(arg[1]))
	content = fin:read('*a')
	fin:close()
else
	content = io.read('*a')
end

print(table.concat(slt2.get_dependency(content), '\t'))
