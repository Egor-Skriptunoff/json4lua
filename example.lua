-- Example script for module "json.lua".
-- Demonstrates the functionality of the module.

local json = require('json')

------------------------
-- encoding/decoding an object
------------------------
local Lua_object = {
  "t[1]", "t[2]", [-1]="t[-1]", -- integer indices will be converted to a string keys
  str = 'Hello',
  num = 17.4375,
  array = {2, 3.0, 5.5},
  nullval = json.null,
  bool = false,
  emptobj = json.empty, -- empty JSON object {}
  emptarr = {},         -- empty JSON array []
  -- the following members are not encodable to JSON, they will be skipped by encoder:
  bad_number = 1/0,   -- Inf and NaN are not available in JSON
  func = math.sin,    -- function
  [json.null] = 0,    -- key is not convertible to a string
  [true] = 1,         -- key is not convertible to a string
  [3.5] = 2           -- numbers with fractional part are prohibited to be converted to a string keys
}
-- Encoding
local JSON_text = json.encode(Lua_object)
print'Encoded JSON text:'
print(JSON_text)
-- Decoding
local result = json.decode(JSON_text)
print'The decoded table "result":'
for k, v in pairs(result) do print('', k, v) end
print'The decoded table "result.array":'
for k, v in pairs(result.array) do print('', k, v) end

------------------------
-- encoding/decoding an array
------------------------
print()
local Lua_array = { {x=1, y=2}, 2.5, {[10^9] = "mlrd"} }
Lua_array[7] = "arr[7]"
Lua_array[11] = json.null

local JSON_text = json.encode(Lua_array)
print'Encoded JSON text:'
print(JSON_text)

-- Now JSON decode the JSON string
local result = json.decode(JSON_text)
print ("The decoded table result:")
for k, v in pairs(result) do print('', k, v) end

------------------------
-- decoding a JSON string containing UTF-16 surrogate pairs
------------------------
print()
local someJSON = [[ "Test \u00A7 \"\ud834\udd1e\" \\\uD83D\uDE02\/ " ]]
print('JSON: <'..someJSON..'>')
print('Decoded: <'..json.decode(someJSON)..'>')  -->  Test § "𝄞" \😂/
