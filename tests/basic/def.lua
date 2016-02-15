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
