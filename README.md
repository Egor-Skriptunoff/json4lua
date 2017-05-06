# json4lua
JSON for Lua

### Installation
Just copy json.lua to Lua modules' folder.


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

### Traversing (decoding JSON without creating the result on Lua side)

Function  `json.traverse(s, callback, pos)`  traverses JSON and invokes user-supplied callback function
```
   callback function arguments: (path, json_type, value, pos)
      path      is array of nested JSON identifiers, this array is empty for root JSON element
      json_type is one of "null"/"boolean"/"number"/"string"/"array"/"object"
      value     is defined when json_type is "boolean"/"number"/"string", otherwise value == nil
      pos       is 1-based index of first character of current JSON element inside JSON string
```
```lua
json.traverse([[ 42 ]], callback)
-- will invoke callback function 1 time:
   callback( {},         "number",  42,    2  )
```
```lua
json.traverse([[ {"a":true, "b":null, "c":["one","two"], "d":{ "e":{}, "f":[] } } ]], callback)
-- will invoke callback function 9 times:
   callback( {},         "object",  nil,   2  )
   callback( {"a"},      "boolean", true,  7  )
   callback( {"b"},      "null",    nil,   17 )
   callback( {"c"},      "array",   nil,   27 )
   callback( {"c", 1},   "string",  "one", 28 )
   callback( {"c", 2},   "string",  "two", 34 )
   callback( {"d"},      "object",  nil,   46 )
   callback( {"d", "e"}, "object",  nil,   52 )
   callback( {"d", "f"}, "array",   nil,   60 )
```


### Reading JSON chunk-by-chunk

Both decoder functions `json.decode()` and `json.traverse()` can accept JSON as a "loader function" instead of a string.  
This function will be called repeatedly to return next parts (substrings) of JSON string.  
An empty string, nil, or no value returned from "loader function" means the end of JSON string.  
This may be useful for low-memory devices or for traversing huge JSON files.


### Partial decoding of arbitrary element inside JSON

Instead of decoding whole JSON, you can decode its arbitrary element (e.g, array or object) by specifying the position where this element starts.  
In order to do that, at first you have to traverse JSON to get all positions you need.


### Partial decoding of JSON with reading JSON from file

```lua
-- This is content of "data.txt" file:
-- {"aa":["qq",{"k1":23,"gg":"YAY","Fermat_primes":[3, 5, 17, 257, 65537],"bb":0}]}

-- We want to extract (as Lua array) only "Fermat_primes" from this JSON
-- without loading whole JSON to Lua.

local json = require('json')

-- Open file
local file = io.open('data.txt', 'r')

-- Define loader function which will read the file in 64-byte chunks
local function my_json_loader()
   return file:read(64)
end

local position  -- We need to know the position of Fermat primes array inside this JSON

-- Prepare callback function for traverse
local function my_callback (path, json_type, value, pos)
   if #path == 3
      and path[1] == "aa"
      and path[2] == 2
      and path[3] == "Fermat_primes"
      and json_type == "array"
   then
      position = pos
   end
end

-- Step #1: Traverse to get the position
file:seek("set", 0)
json.traverse(my_json_loader, my_callback)

-- Step #2: Decode only Fermat_primes array
file:seek("set", position - 1)
local FP = json.decode(my_json_loader)

print('Fermat_primes:'); for k, v in ipairs(FP) do print(k, v) end

-- Close file
file:close()
```

Output:

```
Fermat_primes:
1  3
2  5
3  17
4  257
5  65537
```
