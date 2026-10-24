local _, ns = ...

-- Settings as text, to export, import and share. Encode writes a Lua-like table; Decode reads it
-- back with its own parser: it only accepts tables, strings, numbers and booleans, so a pasted
-- text can never run code (never loadstring). Pack/Unpack wrap it in printable base64 behind the
-- "OBUI1:" prefix, safe to paste in chat or a website.
local Serialize = {}
ns.Serialize = Serialize

local function keyText(k)
  if type(k) == "number" then return "[" .. string.format("%.14g", k) .. "]" end
  if k:match("^[%a_][%w_]*$") then return k end
  return "[" .. string.format("%q", k) .. "]"
end

local function encode(v, depth)
  local t = type(v)
  if t == "number" then return string.format("%.14g", v) end
  if t == "boolean" then return v and "true" or "false" end
  if t == "string" then return (string.format("%q", v):gsub("\\\n", "\\n")) end
  if t ~= "table" then return "nil" end
  if depth > 30 then error("table too deep") end
  local keys = {}
  for k in pairs(v) do
    if type(k) == "string" or type(k) == "number" then keys[#keys + 1] = k end
  end
  table.sort(keys, function(a, b)
    if type(a) == type(b) then return a < b end
    return type(a) == "number"
  end)
  local parts = {}
  for _, k in ipairs(keys) do
    local x = v[k]
    local tx = type(x)
    if tx == "number" or tx == "string" or tx == "boolean" or tx == "table" then
      parts[#parts + 1] = keyText(k) .. "=" .. encode(x, depth + 1)
    end
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

function Serialize.Encode(v) return encode(v, 0) end

-- ------------------------------------------------------------------ the parser
local ESC = { n = "\n", r = "\r", t = "\t", ["\\"] = "\\", ['"'] = '"', ["'"] = "'", a = "\a", b = "\b", f = "\f", v = "\v" }

function Serialize.Decode(s)
  if type(s) ~= "string" or #s > 1000000 then error("invalid text") end
  local pos = 1
  local function fail(msg) error(msg .. " at " .. pos, 0) end
  local function ws()
    pos = s:find("[^ \t\r\n]", pos) or #s + 1
  end
  local value
  local function str()
    local quote = s:sub(pos, pos)
    pos = pos + 1
    local out = {}
    while true do
      local c = s:sub(pos, pos)
      if c == "" then fail("unfinished string") end
      if c == quote then pos = pos + 1; break end
      if c == "\\" then
        local n = s:sub(pos + 1, pos + 1)
        if ESC[n] then
          out[#out + 1] = ESC[n]; pos = pos + 2
        elseif n == "\n" then
          out[#out + 1] = "\n"; pos = pos + 2
        elseif n:match("%d") then
          local d = s:match("^%d%d?%d?", pos + 1)
          local code = tonumber(d)
          if code > 255 then fail("bad escape") end
          out[#out + 1] = string.char(code); pos = pos + 1 + #d
        else
          fail("bad escape")
        end
      else
        out[#out + 1] = c; pos = pos + 1
      end
    end
    return table.concat(out)
  end
  local function number()
    local n = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
    if not n or n == "" or n == "-" then fail("bad number") end
    pos = pos + #n
    local v = tonumber(n)
    if not v then fail("bad number") end
    return v
  end
  local function tbl(depth)
    if depth > 30 then fail("too deep") end
    pos = pos + 1
    local t, index = {}, 1
    while true do
      ws()
      local c = s:sub(pos, pos)
      if c == "}" then pos = pos + 1; return t end
      local key
      local ident = s:match("^[%a_][%w_]*", pos)
      if ident and ident ~= "true" and ident ~= "false" and s:match("^[%a_][%w_]*%s*=", pos) then
        key = ident
        pos = pos + #ident
        ws(); pos = pos + 1 -- "="
      elseif c == "[" then
        pos = pos + 1; ws()
        key = value(depth + 1)
        if type(key) ~= "string" and type(key) ~= "number" then fail("bad key") end
        ws()
        if s:sub(pos, pos) ~= "]" then fail("expected ]") end
        pos = pos + 1; ws()
        if s:sub(pos, pos) ~= "=" then fail("expected =") end
        pos = pos + 1
      end
      ws()
      local v = value(depth + 1)
      if key == nil then key = index; index = index + 1 end
      t[key] = v
      ws()
      local sep = s:sub(pos, pos)
      if sep == "," or sep == ";" then pos = pos + 1
      elseif sep ~= "}" then fail("expected , or }") end
    end
  end
  function value(depth)
    ws()
    local c = s:sub(pos, pos)
    if c == "{" then return tbl(depth or 0) end
    if c == '"' or c == "'" then return str() end
    if c == "-" or c:match("%d") then return number() end
    if s:sub(pos, pos + 3) == "true" then pos = pos + 4; return true end
    if s:sub(pos, pos + 4) == "false" then pos = pos + 5; return false end
    fail("unexpected input")
  end
  local result = value(0)
  ws()
  if pos <= #s then fail("trailing text") end
  return result
end

-- ------------------------------------------------------------------ base64 (plain arithmetic: Lua 5.1)
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local DEC = {}
for i = 1, 64 do DEC[B64:sub(i, i)] = i - 1 end

local function b64encode(data)
  local out = {}
  for i = 1, #data, 3 do
    local a, b, c = data:byte(i, i + 2)
    local n = a * 65536 + (b or 0) * 256 + (c or 0)
    local c1, c2 = math.floor(n / 262144) % 64, math.floor(n / 4096) % 64
    local c3, c4 = math.floor(n / 64) % 64, n % 64
    out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
      .. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
  end
  return table.concat(out)
end

local function b64decode(text)
  text = text:gsub("%s", "")
  if #text % 4 ~= 0 or text:find("[^%w%+/=]") then error("invalid text", 0) end
  local out = {}
  for i = 1, #text, 4 do
    local q = text:sub(i, i + 3)
    local a, b, c, d = DEC[q:sub(1, 1)], DEC[q:sub(2, 2)], DEC[q:sub(3, 3)], DEC[q:sub(4, 4)]
    if not a or not b then error("invalid text", 0) end
    local n = a * 262144 + b * 4096 + (c or 0) * 64 + (d or 0)
    out[#out + 1] = string.char(math.floor(n / 65536) % 256)
    if c then out[#out + 1] = string.char(math.floor(n / 256) % 256) end
    if d then out[#out + 1] = string.char(n % 256) end
  end
  return table.concat(out)
end

function Serialize.Pack(v) return "OBUI1:" .. b64encode(Serialize.Encode(v)) end

function Serialize.Unpack(text)
  local body = type(text) == "string" and text:match("^%s*OBUI1:(.-)%s*$")
  if not body then error("not an ObsidianUI text", 0) end
  return Serialize.Decode(b64decode(body))
end
