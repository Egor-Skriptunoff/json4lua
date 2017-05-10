-- Example script for module "json.lua".
-- Demonstrates the functionality of the module.

local json = require('json')


print()
print('------------------------------------------')
print('-- encoding/decoding an object')
print('------------------------------------------')
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


print()
print('------------------------------------------')
print('-- encoding/decoding an array')
print('------------------------------------------')
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


print()
print('------------------------------------------')
print('-- decoding a JSON string containing UTF-16 surrogate pairs')
print('------------------------------------------')
local someJSON = [[ "Test \u00A7 \"\ud834\udd1e\" \\\uD83D\uDE02\/ " ]]
print('JSON: <'..someJSON..'>')
print('Decoded: <'..json.decode(someJSON)..'>')  -->  Test § "𝄞" \😂/


print()
print('------------------------------------------')
print('-- decoding a JSON array with omitted values')
print('------------------------------------------')
local input_JSON = [[ [,,42,,] ]]
local result = json.decode(input_JSON)
print ("The decoded result is a table:")
for k, v in pairs(result) do print('', k, v) end


print()
print('------------------------------------------')
print('-- decoding a JSON object with omitted values')
print('------------------------------------------')
local input_JSON = [[ {,,a:true,,,a$b_5:-0.01e99,,} ]]
local result = json.decode(input_JSON)
print("The decoded result is a table:")
for k, v in pairs(result) do print('', type(k), k, type(v), v) end


print()
print('------------------------------------------')
print('-- show information passed to callback function during JSON traverse')
print('------------------------------------------')
local function callback(path, json_type, value, pos, pos_last)
   print(table.concat(path, '/'), json_type, value, pos, pos_last)
end

print('path', 'j_type', 'value', 'pos', 'pos_last')
json.traverse([[ 42 ]], callback)

print()
print('path', 'j_type', 'value', 'pos', 'pos_last')
json.traverse([[ {"a":true, "b":null, "c":["one","two"], "d":{ "e":{}, "f":[] } } ]], callback)


print()
print('------------------------------------------')
print('-- show information passed to callback function during JSON traverse-and-partially-decode')
print('------------------------------------------')
local function callback(path, json_type, value, pos, pos_last)
   print(table.concat(path, '/'), json_type, value, pos, pos_last)
   local elem_name = path[#path]
   return elem_name == "c" or elem_name == "e"  -- we want to decode elements "c" and "e" while traversing
end

print('path', 'j_type', 'value', 'pos', 'pos_last')
json.traverse([[ {"a":true, "b":null, "c":["one","two"], "d":{ "e":{}, "f":[] } } ]], callback)


print()
print('------------------------------------------')
print('-- traversing JSON string to search for data')
print('------------------------------------------')
local input_JSON = [[ { "the_answer":42, "greeting":"Hello", "Fermat_primes":[3, 5, 17, 257, 65537], "math_consts":{ "e":2.72, "pi":3.14 } } ]]
-- All we need to know from this JSON is: all Fermat primes, math constant "e" and greeting word

local function my_callback (path, json_type, value)
   if
      -- full check: whole path array and json_type are checked to be what we want
      #path == 1
      and path[1] == "greeting"
      and json_type == "string"
   then
      print("greeting word = "..value)
   elseif
      -- simplified check: we assume here that field with name "e" is unique inside this JSON
      path[#path] == "e"
   then
      print("math const e = "..value)
   elseif
      -- print all numeric items inside "Fermat_primes"
      #path == 2    -- depth == 2 for elements inside array "Fermat_primes"
      and path[1] == "Fermat_primes"
      and json_type == "number"
   then
      print("F"..path[2].." = "..value)  -- path[2] = index (1-based) inside JSON array
   end
end

-- Traverse and print all needed values
json.traverse(input_JSON, my_callback)


print()
print('------------------------------------------')
print('-- partial decoding of JSON while traversing it')
print('------------------------------------------')

local input_JSON = [[ { "the_answer":42, "greeting":"Hello", "Fermat_primes":[3, 5, 17, 257, 65537], "math_consts":{ "e":2.72, "pi":3.14 } } ]]
-- All we need to know from this JSON is: all Fermat primes, math constant "e" and greeting word
-- But, unlike previous example, now we need these values stored in Lua variables (Fermat primes JSON array should be decoded as Lua array)
local FP, e, greeting

local function my_callback (path, json_type, value)
   if
      -- full check: whole path array and json_type are checked to be what we want
      #path == 1
      and path[1] == "greeting"
      and json_type == "string"
   then
      greeting = value
   elseif
      -- simplified check: we assume here that field with name "e" is unique inside this JSON
      path[#path] == "e"
   then
      e = value
   elseif
      -- print all numeric items inside "Fermat_primes"
      #path == 1    -- depth == 1 for array "Fermat_primes" itself
      and path[1] == "Fermat_primes"
      and json_type == "array"
   then
      FP = value   -- this line will be executed twice: first time "value" is nil
      return true  -- return true to signal "yes, we need this array decoded as Lua object"
   end
end

-- Do traverse and partial decoding to get all the values we need
json.traverse(input_JSON, my_callback)

-- Now all values are ready in Lua variables
print("greeting word = "..greeting)
print("math const e = "..e)
print("The Fermat_primes array:")
for k, v in ipairs(FP) do print('', k, v) end


print()
print('------------------------------------------')
print('-- traverse large JSON file')
print('------------------------------------------')
-- Open file
local file = assert(io.open('large_json.txt', 'r'))

-- Define loader function which will read the file in 4KByte chunks
local function my_json_loader()
   return file:read(4*1024)
end

-- Prepare callback function for traverse
local function my_callback (path, json_type, value, pos, last_pos)
   -- Do whatever you need here
   -- (see previous examples on using json.traverse)
end

-- Do traverse
-- Set initial position as 3-rd argument (default 1) if JSON is stored not from the beginning of your file
json.traverse(my_json_loader, my_callback)

-- Close file
file:close()
