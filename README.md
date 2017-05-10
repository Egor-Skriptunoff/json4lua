# json4lua
JSON for Lua

### Installation
Just copy "json.lua" to Lua modules' folder.


### Encoding

```lua
local json = require('json')
print(json.encode({ 1, 2, 'fred', {first='mars',second='venus',third='earth'} }))
```
```json
[1,2,"fred",{"first":"mars","second":"venus","third":"earth"}]
```

### Decoding

```lua
local json = require("json")
local testString = [[ { "one":1 , "two":2, "primes":[2,3,5,7] } ]]
local decoded = json.decode(testString)
for k, v in pairs(decoded) do
   print('', k, v)
end
print("Primes are:")
for k, v in ipairs(decoded.primes) do
   print('', k, v)
end
```
```
        one     1
        two     2
        primes  table: 0x8454688
Primes are:
        1       2
        2       3
        3       5
        4       7
```

### Traversing (dry run decoding without creating the result on Lua side) and partial decoding

Traverse is useful to reduce memory usage: no memory-consuming objects are being created in Lua while traversing.  
Function `json.traverse(s, callback, pos)` traverses JSON and invokes user-supplied callback function for each item found inside JSON.  

`callback` function is provided with the following arguments:
```
callback(path, json_type, value, pos, pos_last)
   path      is array of nested JSON identifiers, this array is empty for root JSON element
   json_type is one of "null"/"boolean"/"number"/"string"/"array"/"object"
   value     is element's value for "null"/"boolean"/"number"/"string", nil for "object"/"array"
   pos       is 1-based index of first character of current JSON element
   pos_last  is 1-based index of last character of current JSON element (defined only when value ~= nil)
```
By default, `value` is `nil` for JSON arrays/objects.  
Nevertheless, you can get any array/object decoded (instead of get traversed) while traversing JSON.  
In order to do that, `callback` function must return `true` when invoked for that element (when `value == nil`).  
This array/object (decoded as Lua value) will be sent to you on next invocation of callback function (`value ~= nil`).

Traverse example:

```lua
local json = require("json")
local JSON_string = 
   [[ {"a":true, "b":null, "c":["one","two"], "d":{ "e":{}, "f":[] }, "g":["ten",20,-33.3] } ]]
json.traverse(JSON_string, callback)
-- callback function will be invoked 13 times (if it returns true for array "c" and object "e"):
--           path        json_type  value           pos  pos_last
--           ----------  ---------  --------------  ---  --------
-- callback( {},         "object",  nil,            2,   nil )
-- callback( {"a"},      "boolean", true,           7,   10  )
-- callback( {"b"},      "null",    json.null,      17,  20  )  -- special Lua value for JSON null
-- callback( {"c"},      "array",   nil,            27,  nil )  -- this callback returned true (user wants to decode this array)
-- callback( {"c"},      "array",   {"one", "two"}, 27,  39  )  -- the next invocation brings the result of decoding (value ~= nil)
-- callback( {"d"},      "object",  nil,            46,  nil )
-- callback( {"d", "e"}, "object",  nil,            52,  nil )  -- this callback returned true (user wants to decode this object)
-- callback( {"d", "e"}, "object",  json.empty,     52,  53  )  -- the next invocation brings the result of decoding (special Lua value for empty JSON object)
-- callback( {"d", "f"}, "array",   nil,            60,  nil )
-- callback( {"g"},      "array",   nil,            70,  nil )
-- callback( {"g", 1},   "string",  "ten",          71,  75  )
-- callback( {"g", 2},   "number",  20,             77,  78  )
-- callback( {"g", 3},   "number",  -33.3,          80,  84  )
```

Example of callback function to get `c` and `e` elements been decoded (instead of traversed):

```lua
local result_c, result_e   --  these variables will hold Lua objects for JSON elements "c" and "e"

local function callback(path, json_type, value, pos, pos_last)
   -- print(table.concat(path, '/'), json_type, value, pos, pos_last)
   local elem_name = path[#path]   -- last identifier in element's path
   if elem_name == "c" then 
      result_c = value
   elseif elem_name == "e" then 
      result_e = value
   end
   return elem_name == "c" or elem_name == "e"  -- we want "c" and "e" to be decoded instead of be traversed
end

json.traverse(JSON_string, callback)

-- Now variables "result_c" and "result_e" contain decoded JSON elements "c" and "e"
-- result_c == {"one", "two"}
-- result_e == json.empty
```

### Reading JSON from a file without preloading whole JSON as a huge Lua string

Both functions `json.decode()` and `json.traverse()` can accept JSON as a "loader function" instead of a "whole JSON string".  
This function will be called repeatedly to return next parts (substrings) of JSON.  
An empty string, `nil`, or no value returned from "loader function" means the end of JSON.  
This may be useful for low-memory devices or for traversing huge JSON files.

```lua
-- Open file
local file = assert(io.open('large_json.txt', 'r'))

-- Define loader function for reading the file in 4KByte chunks
local function my_json_loader()
   return file:read(4*1024)   -- 64 Byte chunks are recommended for RAM-restricted devices
end

if you_want_to_traverse_JSON_or_to_decode_JSON_partially then

   -- Prepare callback function
   local function my_callback (path, json_type, value, pos, last_pos)
      -- Do whatever you need here
      -- (see examples on using json.traverse)
   end

   -- Do traverse
   -- Set initial position as 3-rd argument (default 1) if JSON is stored not from the beginning of your file
   json.traverse(my_json_loader, my_callback)

elseif you_want_to_decode_the_whole_JSON then

   -- Do decode
   -- Set initial position as 2-nd argument (default 1) if JSON is stored not from the beginning of your file
   result = json.decode(my_json_loader)

end
   
-- Close file
file:close()
```
