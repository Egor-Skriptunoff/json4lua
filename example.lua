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

------------------------
-- decoding a JSON array with omitted values
------------------------
print()
local test_string = [[ [,,42,,] ]]
local result = json.decode(test_string)
print ("The decoded table result:")
for k, v in pairs(result) do print('', k, v) end

------------------------
-- decoding a JSON object with omitted values
------------------------
print()
local test_string = [[ {,,a:true,,,a$b_5:-0.01e99,,} ]]
local result = json.decode(test_string)
print ("The decoded table result:")
for k, v in pairs(result) do print('', type(k), k, type(v), v) end

------------------------
-- show information passed to callback function during JSON traverse
------------------------
local function callback(path, json_type, value, pos)
   print('callback', table.concat(path, '/'), json_type, value, pos)
end

print()
print('--------', 'path', 'j_type', 'value', 'pos')
json.traverse([[ 42 ]], callback)

print()
print('--------', 'path', 'j_type', 'value', 'pos')
json.traverse([[ {"a":true, "b":null, "c":["one","two"], "d":{ "e":{}, "f":[] } } ]], callback)

------------------------
-- traversing JSON string to search for data
------------------------
print()
local test_string = [[ { "the_answer":42, "greeting":"Hello", "Fermat_primes":[3, 5, 17, 257, 65537], "math_consts":{ "e":2.72, "pi":3.14 } } ]]

-- All we need to know from this JSON is: all Fermat primes, math constant "e" and greeting word
local e, greeting
local function my_callback (path, json_type, value)
   if
      -- print all numeric items of "Fermat_primes"
      #path == 2
      and path[1] == "Fermat_primes"
      and json_type == "number"
   then
      print("F"..path[2].." = "..value)  -- index (1-based) and value
   elseif
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
   end
end

-- Do traversing (and print Fermat primes on-the-fly)
json.traverse(test_string, my_callback)

-- Show what was saved during the traverse
print(e, greeting)


------------------------
-- partial decoding of JSON
------------------------
-- If you want to decode only some element (i.e, array) inside JSON instead of decoding of whole JSON,
-- you can at first traverse JSON to get position of your element
-- and then decode this element by specifying its position

print()
local test_string = [[ { "the_answer":42, "greeting":"Hello", "Fermat_primes":[3, 5, 17, 257, 65537], "math_consts":{ "e":2.72, "pi":3.14 } } ]]

-- We need to know the position of Fermat primes inside this JSON
local position
local function my_callback (path, json_type, value, pos)
   if #path == 1
      and path[1] == "Fermat_primes"
      and json_type == "array"
   then
      position = pos
   end
end
-- Do traversing to get the position
json.traverse(test_string, my_callback)
-- Show the position of Fermat_primes inside JSON string
print(position)
-- Do partial decoding to get Fermat_primes
local result = json.decode(test_string, position)
print ("The Fermat_primes array (as result of partial decoding):")
for k, v in ipairs(result) do print('', k, v) end


------------------------
-- partial decoding of JSON with reading JSON from file
------------------------
-- This is content of "data.txt" file:
-- {"aa":["qq",{"k1":23,"gg":"YAY","Fermat_primes":[3, 5, 17, 257, 65537],"bb":0}]}
-- We want to extract only Fermat primes from this JSON (and save it as Lua array)

print()

-- Open file
local file = io.open('data.txt', 'r')

-- Define loader function which will read the file in 64-byte chunks
local function my_json_loader()
   return file:read(64)
end

-- Prepare callback function for traverse
local position  -- We need to know the position of Fermat primes inside this JSON
local function my_callback (path, json_type, value, pos)
   if #path == 3
      and path[1] == "aa"
      and path[2] == 2
      and path[3] == "Fermat_primes"
      and json_type == "array"
   then -- remember position of this array to decode it on step #2
      position = pos
   end
end

-- Step #1: Traverse to get the position
file:seek("set", 0)
json.traverse(my_json_loader, my_callback)

-- Step #2: Decode only Fermat_primes
file:seek("set", position - 1)
local FP = json.decode(my_json_loader)
print('Fermat_primes:')
for k, v in ipairs(FP) do print(k, v) end

-- Close file
file:close()
