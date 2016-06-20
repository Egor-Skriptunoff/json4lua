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
