-----------------------------------------------------------------------------
-- JSON4Lua: JSON encoding / decoding support for the Lua language.
-- json Module.
-- Author: Craig Mason-Jones

-- Version: 1.1.1
-- 2016-09-03

-- This module is released under the MIT License (MIT).
-- Please see LICENCE.txt for details:
-- https://github.com/craigmj/json4lua/blob/master/doc/LICENCE.txt
--
-- USAGE:
-- This module exposes two functions:
--   json.encode(o)
--     Returns the table / string / boolean / number / nil / json.null value as a JSON-encoded string.
--   json.decode(json_string)
--     Returns a Lua object populated with the data encoded in the JSON string json_string.
--
-- REQUIREMENTS:
--   Lua 5.1, Lua 5.2, Lua 5.3 or LuaJIT
--
-- CHANGELOG
--   1.1.0   Modifications made by Egor Skriptunoff, based on version 1.0.0 taken from
--              https://github.com/craigmj/json4lua/blob/40fb13b0ec4a70e36f88812848511c5867bed857/json/json.lua.
--           Added Lua 5.2 and Lua 5.3 compatibility.
--           Removed Lua 5.0 compatibility.
--           Introduced json.empty (Lua counterpart for empty JSON object)
--           Bugs fixed:
--              Attempt to encode Lua table {[10^9]=0} raises an out-of-memory error.
--              Zero bytes '\0' in Lua strings are not escaped by encoder.
--              JSON numbers with capital "E" (as in 1E+100) are not accepted by decoder.
--              All nulls in a JSON arrays are skipped by decoder, sparse arrays could not be loaded correctly.
--              UTF-16 surrogate pairs in JSON strings are not recognised by decoder.
--   1.0.0   Merged Amr Hassan's changes
--   0.9.30  Changed to MIT Licence.
--   0.9.20  Introduction of local Lua functions for private functions (removed _ function prefix).
--           Fixed Lua 5.1 compatibility issues.
--           Introduced json.null to have null values in associative arrays.
--           json.encode() performance improvement (more than 50%) through table_concat rather than ..
--           Introduced decode ability to ignore /**/ comments in the JSON string.
--   0.9.10  Fix to array encoding / decoding to correctly manage nil/null values in arrays.
--   0.9.00  First release
--
-- TO-DO
--   Parser code is inefficient.  It should be rewritten.
-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
-- Module declaration
-----------------------------------------------------------------------------
local json = {}

do
   -----------------------------------------------------------------------------
   -- Imports and dependencies
   -----------------------------------------------------------------------------
   local math, string, table = require'math', require'string', require'table'
   local math_floor, math_max, math_type = math.floor, math.max, math.type or function() end
   local string_char, string_sub, string_find, string_format = string.char, string.sub, string.find, string.format
   local table_insert, table_concat = table.insert, table.concat
   local type, tostring, pairs, assert = type, tostring, pairs, assert
   local loadstring = loadstring or load

   -----------------------------------------------------------------------------
   -- Public functions
   -----------------------------------------------------------------------------
   -- function json.encode(v)
   -- function json.decode(s)

   --- The json.null table allows one to specify a null value in an associative array (which is otherwise
   -- discarded if you set the value with 'nil' in Lua. Simply set t = { first=json.null }
   local null = {"This Lua table is used to designate JSON null value, compare with json.null"}
   json.null = setmetatable(null, {
      __tostring = function() return 'null' end
   })

   --- The json.empty table allows one to specify an empty JSON object.
   -- To encode empty JSON array use usual empty Lua table.
   -- Example: t = { empty_object=json.empty, empty_array={} }
   local empty = {}
   json.empty = setmetatable(empty, {
      __tostring = function() return '{}' end,
      __newindex = function() error("json.empty is an read-only Lua table", 2) end
   })

   -----------------------------------------------------------------------------
   -- Private functions
   -----------------------------------------------------------------------------
   local decode
   local decode_scanArray
   local decode_scanComment
   local decode_scanConstant
   local decode_scanNumber
   local decode_scanObject
   local decode_scanString
   local decode_scanWhitespace
   local encodeString
   local isArray
   local isEncodable
   local isConvertibleToString
   local isRegularNumber

   -----------------------------------------------------------------------------
   -- PUBLIC FUNCTIONS
   -----------------------------------------------------------------------------
   --- Encodes an arbitrary Lua object / variable.
   -- @param v The Lua object / variable to be JSON encoded.
   -- @return String containing the JSON encoding (codepage of Lua strings is preserved)
   function json.encode(v)
      -- Handle nil and null values
      if v == nil or v == null then
         return 'null'
      end

      if v == empty then
         return '{}'
      end

      local vtype = type(v)

      -- Handle strings
      if vtype == 'string' then
         return '"'..encodeString(v)..'"'
      end

      -- Handle booleans
      if vtype=='boolean' then
         return tostring(v)
      end

      if vtype=='number' then
         assert(isRegularNumber(v), 'numeric values Inf and NaN are unsupported')
         return math_type(vtype) == 'integer' and tostring(v) or string_format('%.17g', v)
      end

      -- Handle tables
      if vtype=='table' then
         local rval = {}
         -- Consider arrays separately
         local bArray, maxCount = isArray(v)
         if bArray then
            for i = 1,maxCount do
               table_insert(rval, json.encode(v[i]))
            end
         else  -- An object, not an array
            for i,j in pairs(v) do
               if isConvertibleToString(i) and isEncodable(j) then
                  table_insert(rval, '"'..encodeString(i)..'":'..json.encode(j))
               end
            end
         end
         if bArray then
            return '['..table_concat(rval,',')..']'
         else
            return '{'..table_concat(rval,',')..'}'
         end
      end

      assert(false,'encode attempt to encode unsupported type '..vtype..':'..tostring(v))
   end

   --- Decodes a JSON string and returns the decoded value as a Lua data structure / value.
   -- @param s The string to scan.
   -- @return Lua object The object that was scanned, as a Lua table / string / number / boolean or json.null.
   function json.decode(s)
      return (decode(s, 1))
   end

   --- Decodes a JSON string and returns the decoded value as a Lua data structure / value.
   -- @param s The string to scan.
   -- @param startPos Starting position where the JSON string is located.
   -- @return Lua object, number The object that was scanned, as a Lua table / string / number / boolean or json.null,
   -- and the position of the first character after the scanned JSON object.
   function decode(s, startPos)
      startPos = decode_scanWhitespace(s,startPos)
      assert(startPos<=#s, 'Unterminated JSON encoded object found at position in ['..s..']')
      local curChar = string_sub(s,startPos,startPos)
      -- Object
      if curChar=='{' then
         return decode_scanObject(s,startPos)
      end
      -- Array
      if curChar=='[' then
         return decode_scanArray(s,startPos)
      end
      -- Number
      if string_find("-0123456789", curChar, 1, true) then
         return decode_scanNumber(s,startPos)
      end
      -- String
      if curChar=='"' then
         return decode_scanString(s,startPos)
      end
      if string_sub(s,startPos,startPos+1)=='/*' then
         return decode(s, decode_scanComment(s,startPos))
      end
      -- Otherwise, it must be a constant
      return decode_scanConstant(s,startPos)
   end

   -----------------------------------------------------------------------------
   -- Internal, PRIVATE functions.
   -- Following a Python-like convention, I have prefixed all these 'PRIVATE'
   -- functions with an underscore.
   -----------------------------------------------------------------------------

   --- Scans an array from JSON into a Lua object
   -- startPos begins at the start of the array.
   -- Returns the array and the next starting position
   -- @param s The string being scanned.
   -- @param startPos The starting position for the scan.
   -- @return table, int The scanned array as a table, and the position of the next character to scan.
   function decode_scanArray(s,startPos)
      local array = {}  -- The return value
      local object
      assert(string_sub(s,startPos,startPos)=='[','decode_scanArray called but array does not start at position '..startPos..' in string:\n'..s)
      startPos = startPos + 1
      -- Infinite loop for array elements
      repeat
         startPos = decode_scanWhitespace(s,startPos)
         assert(startPos<=#s,'JSON String ended unexpectedly scanning array.')
         local curChar = string_sub(s,startPos,startPos)
         if (curChar==']') then
            return array, startPos+1
         end
         if (curChar==',') then
            startPos = decode_scanWhitespace(s,startPos+1)
         end
         assert(startPos<=#s, 'JSON String ended unexpectedly scanning array.')
         object, startPos = decode(s,startPos)
         table_insert(array,object)
      until false
   end

   --- Scans a comment and discards the comment.
   -- Returns the position of the next character following the comment.
   -- @param string s The JSON string to scan.
   -- @param int startPos The starting position of the comment
   function decode_scanComment(s, startPos)
      assert( string_sub(s,startPos,startPos+1)=='/*', "decode_scanComment called but comment does not start at position "..startPos)
      local endPos = string_find(s,'*/',startPos+2)
      assert(endPos~=nil, "Unterminated comment in string at "..startPos)
      return endPos+2
   end

   --- Scans for given constants: true, false or null
   -- Returns the appropriate Lua type, and the position of the next character to read.
   -- @param s The string being scanned.
   -- @param startPos The position in the string at which to start scanning.
   -- @return object, int The object (true, false or nil) and the position at which the next character should be
   -- scanned.
   function decode_scanConstant(s, startPos)
      local consts = { ["true"] = true, ["false"] = false, ["null"] = null }
      local constNames = {"true","false","null"}

      for i,k in pairs(constNames) do
         if string_sub(s,startPos, startPos + #k -1 )==k then
            return consts[k], startPos + #k
         end
      end
      assert(nil, 'Failed to scan constant from string '..s..' at starting position '..startPos)
   end

   --- Scans a number from the JSON encoded string.
   -- (in fact, also is able to scan numeric +- eqns, which is not
   -- in the JSON spec.)
   -- Returns the number, and the position of the next character
   -- after the number.
   -- @param s The string being scanned.
   -- @param startPos The position at which to start scanning.
   -- @return number, int The extracted number and the position of the next character to scan.
   function decode_scanNumber(s,startPos)
      local endPos = startPos+1
      local acceptableChars = "+-0123456789.eE"
      while endPos<=#s and string_find(acceptableChars, string_sub(s,endPos,endPos), 1, true) do
         endPos = endPos + 1
      end
      local stringValue = 'return '..string_sub(s,startPos, endPos-1)
      local stringEval = loadstring(stringValue)
      assert(stringEval, 'Failed to scan number [ '..stringValue..'] in JSON string at position '..startPos..' : '..endPos)
      return stringEval(), endPos
   end

   --- Scans a JSON object into a Lua object.
   -- startPos begins at the start of the object.
   -- Returns the object and the next starting position.
   -- @param s The string being scanned.
   -- @param startPos The starting position of the scan.
   -- @return table, int The scanned object as a table and the position of the next character to scan.
   function decode_scanObject(s,startPos)
      local object = empty
      assert(string_sub(s,startPos,startPos)=='{','decode_scanObject called but object does not start at position '..startPos..' in string:\n'..s)
      startPos = startPos + 1
      repeat
         startPos = decode_scanWhitespace(s,startPos)
         assert(startPos<=#s, 'JSON string ended unexpectedly while scanning object.')
         local curChar = string_sub(s,startPos,startPos)
         if (curChar=='}') then
            return object,startPos+1
         end
         if (curChar==',') then
            startPos = decode_scanWhitespace(s,startPos+1)
         end
         assert(startPos<=#s, 'JSON string ended unexpectedly scanning object.')
         -- Scan the key
         local key, value
         key, startPos = decode(s,startPos)
         assert(startPos<=#s, 'JSON string ended unexpectedly searching for value of key '..key)
         startPos = decode_scanWhitespace(s,startPos)
         assert(startPos<=#s, 'JSON string ended unexpectedly searching for value of key '..key)
         assert(string_sub(s,startPos,startPos)==':','JSON object key-value assignment mal-formed at '..startPos)
         startPos = decode_scanWhitespace(s,startPos+1)
         assert(startPos<=#s, 'JSON string ended unexpectedly searching for value of key '..key)
         value, startPos = decode(s,startPos)
         if object == empty then
            object = {}
         end
         object[key]=value
      until false  -- infinite loop while key-value pairs are found
   end

   -- START SoniEx2
   -- Initialize some things used by decode_scanString
   -- You know, for efficiency
   local escapeSequences = {
      ["\\t"] = "\t",
      ["\\f"] = "\f",
      ["\\r"] = "\r",
      ["\\n"] = "\n",
      ["\\b"] = "\b"
   }
   setmetatable(escapeSequences, {__index = function(t,k)
      -- skip "\" aka strip escape
      return string_sub(k,2)
   end})
   -- END SoniEx2

   --- Scans a JSON string from the opening inverted comma to the end of the string.
   -- Returns the string extracted as a Lua string,
   -- and the position of the next non-string character
   -- (after the closing inverted comma).
   -- @param s The string being scanned.
   -- @param startPos The starting position of the scan.
   -- @return string, int The extracted string as a Lua string, and the next character to parse.
   function decode_scanString(s,startPos)
      assert(startPos, 'decode_scanString() called without start position')
      -- START SoniEx2
      assert(string_sub(s,startPos,startPos) == '"','decode_scanString called for a non-string')
      local surrogate_pair_started
      local t = {}
      local i,j = startPos,startPos
      while string_find(s, '"', j+1) ~= j+1 do
         local oldj = j
         i,j = string_find(s, "\\.", j+1)
         local x,y = string_find(s, '"', oldj+1)
         if not i or x < i then
            i,j = x,y-1
         end
         table_insert(t, string_sub(s, oldj+1, i-1))
         if string_sub(s, i, j) == "\\u" then
            local a = string_sub(s,j+1,j+4)
            j = j + 4
            local n = tonumber(a, 16)
            assert(n, "String decoding failed: bad Unicode escape "..a.." at position "..i.." : "..j)
            -- Handling of UTF-16 surrogate pairs
            if n >= 0xD800 and n < 0xDC00 then
               surrogate_pair_started, n = n
            elseif n >= 0xDC00 and n < 0xE000 then
               n, surrogate_pair_started = surrogate_pair_started and (surrogate_pair_started - 0xD800) * 0x400 + (n - 0xDC00) + 0x10000
            end
            if n then
               -- Convert unicode codepoint n (0..0x10FFFF) to UTF-8 string
               local x
               if n < 0x80 then
                  x = string_char(n % 0x80)
               elseif n < 0x800 then
                  -- [110x xxxx] [10xx xxxx]
                  x = string_char(0xC0 + (math_floor(n/64) % 0x20), 0x80 + (n % 0x40))
               elseif n < 0x10000 then
                  -- [1110 xxxx] [10xx xxxx] [10xx xxxx]
                  x = string_char(0xE0 + (math_floor(n/64/64) % 0x10), 0x80 + (math_floor(n/64) % 0x40), 0x80 + (n % 0x40))
               else
                  -- [1111 0xxx] [10xx xxxx] [10xx xxxx] [10xx xxxx]
                  x = string_char(0xF0 + (math_floor(n/64/64/64) % 8), 0x80 + (math_floor(n/64/64) % 0x40), 0x80 + (math_floor(n/64) % 0x40), 0x80 + (n % 0x40))
               end
               table_insert(t, x)
            end
         else
            table_insert(t, escapeSequences[string_sub(s, i, j)])
         end
      end
      table_insert(t,string_sub(j, j+1))
      assert(string_find(s, '"', j+1), 'String decoding failed: missing closing " at position '..j..'(for string at position '..startPos..')')
      return table_concat(t), j+2
      -- END SoniEx2
   end

   --- Scans a JSON string skipping all whitespace from the current start position.
   -- Returns the position of the first non-whitespace character, or nil if the whole end of string is reached.
   -- @param s The string being scanned
   -- @param startPos The starting position where we should begin removing whitespace.
   -- @return int The first position where non-whitespace was encountered, or #s+1 if the end of string
   -- was reached.
   function decode_scanWhitespace(s,startPos)
      local whitespace=" \n\r\t"
      while string_find(whitespace, string_sub(s,startPos,startPos), 1, true) and startPos <= #s do
         startPos = startPos + 1
      end
      return startPos
   end

   --- Encodes a string to be JSON-compatible.
   -- This just involves back-quoting inverted commas, back-quotes and newlines, I think ;-)
   -- @param s The string to return as a JSON encoded (i.e. backquoted string)
   -- @return The string appropriately escaped.
   local escapeList = {
         ['"']  = '\\"',
         ['\\'] = '\\\\',
         ['/']  = '\\/',
         ['\b'] = '\\b',
         ['\f'] = '\\f',
         ['\n'] = '\\n',
         ['\r'] = '\\r',
         ['\t'] = '\\t',
         ['\127'] = '\\u007F'
   }
   function encodeString(s)
      if type(s)=='number' then
         s = math_type(s) == 'integer' and tostring(s) or string_format('%.f', s)
      end
      return s:gsub(".", function(c) return escapeList[c] or c:byte() < 32 and string.format('\\u%04X', c:byte()) end)
   end

   -- Determines whether the given Lua type is an array or a table / dictionary.
   -- We consider any table an array if it has indexes 1..n for its n items, and no
   -- other data in the table.
   -- I think this method is currently a little 'flaky', but can't think of a good way around it yet...
   -- @param t The table to evaluate as an array
   -- @return boolean, number True if the table can be represented as an array, false otherwise. If true,
   -- the second returned value is the maximum
   -- number of indexed elements in the array.
   function isArray(t)
      -- Next we count all the elements, ensuring that any non-indexed elements are not-encodable
      -- (with the possible exception of 'n')
      local maxIndex = 0
      for k,v in pairs(t) do
         if (type(k)=='number' and math_floor(k)==k and 1<=k and k<=1000000) then  -- k,v is an indexed pair
            if not isEncodable(v) then return false end  -- All array elements must be encodable
            maxIndex = math_max(maxIndex,k)
         elseif not (k == 'n' and v == #t) then  -- if it is n, then n does not hold the number of elements
            if isConvertibleToString(k) and isEncodable(v) then return false end
         end -- End of k,v not an indexed pair
      end  -- End of loop across all pairs
      return true, maxIndex
   end

   --- Determines whether the given Lua object / table / variable can be JSON encoded. The only
   -- types that are JSON encodable are: string, boolean, number, nil, table and special table json.null.
   -- In this implementation, all other types are ignored.
   -- @param o The object to examine.
   -- @return boolean True if the object should be JSON encoded, false if it should be ignored.
   function isEncodable(o)
      local t = type(o)
      return t=='string' or t=='boolean' or t=='number' and isRegularNumber(o) or t=='nil' or t=='table'
   end

   --- Determines whether the given Lua object / table / variable can be a JSON key.
   -- Integer Lua numbers are allowed to be considered as valid string keys in JSON.
   -- @param o The object to examine.
   -- @return boolean True if the object can be converted to a string, false if it should be ignored.
   function isConvertibleToString(o)
      local t = type(o)
      return t=='string' or t=='number' and isRegularNumber(o) and (math_type(o) == 'integer' or math_floor(o) == o)
   end

   local is_Inf_or_NaN = {[tostring(1/0)]=true, [tostring(-1/0)]=true, [tostring(0/0)]=true}
   --- Determines whether the given Lua number is a regular number or Inf/Nan.
   -- @param v The number to examine.
   -- @return boolean True if the number is a regular number which may be encoded in JSON.
   function isRegularNumber(v)
      return not is_Inf_or_NaN[tostring(v)]
   end

end

return json
