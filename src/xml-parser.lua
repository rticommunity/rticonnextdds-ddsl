--[[
  (c) 2005-2014 Copyright, Real-Time Innovations, All rights reserved.     
                                                                           
 Permission to modify and use for internal purposes granted.               
 This software is provided "as is", without warranty, express or implied.
--]]
--[[
-------------------------------------------------------------------------------
Purpose: Load an XML file and construct a Lua table
-------------------------------------------------------------------------------

Given an XML string, return a Lua table, as follows:

XML String:
    <tag attr1=value1 attr2=value2>
      <child1> ... </child1>
      <child2> ... </child2>
      <!--comment -->
    </tag>

Lua:
    tag = {
      -- array: children: tag[i] --
      { -- child1: recursive },
      { -- child2: recursive },  
      "<!--comment ",
    
      -- map: tag name and attributes: tag.label, tag.xarg --
      xarg  = { -- may be empty
        attr1 = value1
        attr2 = value2
      }
      label = "tag",
      [empty=1,] -- iff there are no child tags
    }
--]]

local table2string

local function val_to_str ( v )
  if "string" == type( v ) then
    v = string.gsub( v, "\n", "\\n" )
    if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
      return "'" .. v .. "'"
    end
    return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
  else
    return "table" == type( v ) and table2string( v ) or
      tostring( v )
  end
end

local function key_to_str ( k )
  if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
    return k
  else
    return "[" .. val_to_str( k ) .. "]"
  end
end

table2string = function ( tbl )
  local result, done = {}, {}
  for k, v in ipairs( tbl ) do
    table.insert( result, val_to_str( v ) )
    done[ k ] = true
  end
  for k, v in pairs( tbl ) do
    if not done[ k ] then
      table.insert( result,
        key_to_str( k ) .. "=" .. val_to_str( v ) )
    end
  end
  return "\n{\n" .. table.concat( result, ",\n" ) .. "\n}"
end

local function parseargs(s)
  local arg = {}
  string.gsub(s, "([%w:]+)%s*=%s*([\"'])(.-)%2", function (w, _, a)
    arg[w] = a
  end)
  return arg
end
    
local function collect(s)
  local stack = {}
  local top = {}
  table.insert(stack, top)
  local ni,c,label,xarg, empty
  local i, j = 1, 1
  while true do
    ni,j,c,label,xarg, empty = string.find(s, "<(%/?)([%w:_]+)(.-)(%/?)>", i)
    if not ni then break end
    local text = string.sub(s, i, ni-1)
    if not string.find(text, "^%s*$") then
      table.insert(top, text)
    end
    if empty == "/" then  -- empty element tag
      table.insert(top, {label=label, xarg=parseargs(xarg), empty=1})
    elseif c == "" then   -- start tag
      top = {label=label, xarg=parseargs(xarg)}
      table.insert(stack, top)   -- new level
    else  -- end tag
      local toclose = table.remove(stack)  -- remove top
      top = stack[#stack]
      if #stack < 1 then
        error("nothing to close with "..label)
      end
      if toclose.label ~= label then
        error("trying to close "..toclose.label.." with "..label)
      end
      table.insert(top, toclose)
    end
    i = j+1
  end
  local text = string.sub(s, i)
  if not string.find(text, "^%s*$") then
    table.insert(stack[#stack], text)
  end
  if #stack > 1 then
    error("unclosed "..stack[#stack].label)
  end
  return stack[1]
end

-------------------------------------------------------------------------------
-- Public interface
local interface = {
  xmlstring2table   = collect,
  table2luastring   = table2string,
}

return interface


