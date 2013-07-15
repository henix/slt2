# slt2

slt2 is a Lua template processor.

## Example

see test.lua

```lua
local slt2 = require('slt2')

local user = {
	name = '<world>'
}

function escapeHTML(str)
	local tt = {
		['<'] = '&lt;',
		['>'] = '&gt;'
	}
	str = string.gsub(str, '&', '&amp;')
	str = string.gsub(str, '[<>]', tt)
	return str
end

local tmpl = slt2.loadstring([[<span>
#{ if user ~= nil then }#
Hello, #{= escapeHTML(user.name) }#!
#{ else }#
<a href="/login">login</a>
#{ end }#
</span>
]])

io.write(slt2.render(tmpl, {user = user}))
```

## Template Syntax

* #{ lua code }# : embed lua code
* #{= expression }# : embed lua expression
* #{include: 'file' }# : include another template

NOTE: don't specify a cyclic inclusion

## API Reference

### slt2.loadstring(template, start\_tag, end\_tag, tmpl\_name)
### slt2.loadfile(filename, start\_tag, end\_tag)

"Compile" the template from a string or a file, return compiled object.

* start_tag: default "#{"
* end_tag: default "}#"

### slt2.render\_co(f, env)

Return a coroutine function which yields a chunk of result every time. You can `coroutine.create` or `coroutine.wrap` on it.

### slt2.render(f, env)

Return render result as a string.

## Standalone command

See `runslt2.lua`, to install, link it in your path.

## Compatibility

slt2 has been tested on:

* Lua 5.1
* Lua 5.2
* luajit 2.0

Other versions of Lua are not tested.

## Links

* [slt](https://code.google.com/p/slt/)
* [Simple Lua Template 0.1 发布](http://blog.henix.info/blog/simple-lua-template.html) (Chinese)
