# slt2

slt2 is a Lua template processor. Similar to php or jsp, you can embed lua code directly.

## Example

see test.lua

```lua
local slt2 = require('slt2')

local user = {
	name = '<world>'
}

function escapeHTML(str)
	local tt = {
		['&'] = '&amp;',
		['<'] = '&lt;',
		['>'] = '&gt;',
		['"'] = '&quot;',
		["'"] = '&#39;',
	}
	local r = string.gsub(str, '[&<>"\']', tt)
	return r
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

### slt2.loadstring(template, start\_tag, end\_tag, tmpl\_name, omit\_code\_lines)
### slt2.loadfile(filename, start\_tag, end\_tag, omit\_code\_lines)

"Compile" the template from a string or a file, return compiled object.

* start_tag: default "#{"
* end_tag: default "}#"
* omit_code_lines: if set to `true`, slt2 won't output empty lines for lines that only contain lua code

### slt2.render\_co(f, env)

Return a coroutine function which yields a chunk of result every time. You can `coroutine.create` or `coroutine.wrap` on it.

### slt2.render(f, env)

Return render result as a string.

## Standalone commands

* runslt2.lua : render a template with a lua table value
* slt2pp.lua : preprocess a template (inline included files)
* slt2dep.lua : output dependencies of a template file (the included files, like -MD option of gcc)

To install, create a symbolic link to them in your path.

## Compatibility

slt2 has been tested on:

* Lua 5.1
* Lua 5.2
* luajit 2.0

Other versions of Lua are not tested.

## Links

* [Simple Lua Template](http://blog.henix.info/works/simple-lua-template/_.html) (Chinese)

## License

MIT License

## Contribute

Please create an issue, explaining what's the problem you are trying to solve, before you send a pull request. See [issue #5](https://github.com/henix/slt2/issues/5) for an example.
