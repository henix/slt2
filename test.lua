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
