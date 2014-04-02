#!/usr/local/bin/lua
-------------------------------------------------------------------------------
--  (c) 2005-2014 Copyright, Real-Time Innovations, All rights reserved.     --
--                                                                           --
-- Permission to modify and use for internal purposes granted.               --
-- This software is provided "as is", without warranty, express or implied.  --
--                                                                           --
-------------------------------------------------------------------------------
-- File: xml2lua.lua 
-- Purpose: DDSL: Data type definition Domain Specific Language (DSL) in Lua
-- Created: Rajive Joshi, 2014 Apr 1

-------------------------------------------------------------------------------
-- {{{ XML Parser Begin
-------------------------------------------------------------------------------
function table.val_to_str ( v )
  if "string" == type( v ) then
    v = string.gsub( v, "\n", "\\n" )
    if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
      return "'" .. v .. "'"
    end
    return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
  else
    return "table" == type( v ) and table.tostring( v ) or
      tostring( v )
  end
end

function table.key_to_str ( k )
  if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
    return k
  else
    return "[" .. table.val_to_str( k ) .. "]"
  end
end

function table.tostring( tbl )
  local result, done = {}, {}
  for k, v in ipairs( tbl ) do
    table.insert( result, table.val_to_str( v ) )
    done[ k ] = true
  end
  for k, v in pairs( tbl ) do
    if not done[ k ] then
      table.insert( result,
        table.key_to_str( k ) .. "=" .. table.val_to_str( v ) )
    end
  end
  return "\n{\n" .. table.concat( result, ",\n" ) .. "\n}"
end
function parseargs(s)
  local arg = {}
  string.gsub(s, "([%w:]+)=([\"'])(.-)%2", function (w, _, a)
    arg[w] = a
  end)
  return arg
end
    
function collect(s)
  local stack = {}
  local top = {}
  table.insert(stack, top)
  local ni,c,label,xarg, empty
  local i, j = 1, 1
  while true do
    ni,j,c,label,xarg, empty = string.find(s, "<(%/?)([%w:]+)(.-)(%/?)>", i)
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
-- }}} XML Parser End
-------------------------------------------------------------------------------

----------------------------------------------------------------------------
-- Output Lua

require('Data')

local xmlfile = arg[1]
print('xmlfile = ', xmlfile)
io.input(xmlfile)
xmlString = io.read("*all")
xmlTable = collect(xmlString)
-- print(table.tostring(xmlTable));


print('*** xml -> lua ***')

-- @result the cumulative result, that can be passed to another call to this method
function xml_visitor(xml, data) 
	data = data or Data -- global unnamed name-space called 'Data'
	indent_string = indent_string or ''
	
	for i, v in ipairs(xml) do
		if 'table' == type(v) then
			local result = nil

			if Data.MODULE() == v.label then
				result = emit_module(data, v.xarg)
				-- recurse into the module
				xml_visitor(v, result, indent_string .. '   ')
			elseif Data.TYPEDEF() == v.label then
				result = emit_typedef(data, v.xarg)
			elseif Data.ENUM() == v.label then
				result = emit_enum(data, v.xarg, v)
			elseif Data.STRUCT() == v.label then
				result = emit_struct(data, v.xarg, v)
			else 
				-- recurse into the XML until on of the above is found
				xml_visitor(v, data)
			end
			
			if result then 
				Data.print_idl(result) 
				-- Test:print(result) 
			end
		end
	end
end

function emit_module(data, xarg)
	return data:Module{xarg.name}
end

function emit_typedef(data, xarg)
	return data:Typedef(emit_member(data, xarg))
end

function emit_struct(data, xarg, children)
	-- forward declaration:
	-- install empty definition, just in case one of the member references it
	data:Struct{xarg.name}
	
	-- name
	local decl = {xarg.name}
		
	-- members
	for i, member in ipairs(children) do	    
		table.insert(decl, emit_member(data, member.xarg))
	end
	
	-- annotations
	decl = append_annotations(decl, xarg)

	return data:Struct(decl) -- ignore the warning of the replacement definition
end

function emit_member(data, xarg)
	-- print('DEBUG emit_member', data, xarg.name, xarg.type)

	-- name
	local decl_i = {xarg.name}

	-- kind / type 
	local kind = xarg.type
	if 'string' == xarg.type then
		kind = Data.String(tonumber(xarg.stringMaxLength))
	elseif 'char' == xarg.type then
		kind = Data.char
	elseif 'octet' == xarg.type then
		kind = Data.octet
	elseif 'short' == xarg.type then
		kind = Data.short
	elseif 'long' == xarg.type then
		kind = Data.long
	elseif 'double' == xarg.type then
		kind = Data.double
	elseif 'longLong' == xarg.type then
		kind = Data.long_long
	elseif 'boolean' == xarg.type then
		kind = Data.boolean
	elseif 'nonBasic' == xarg.type then
		kind = data[xarg.nonBasicTypeName]
	end

	table.insert(decl_i, kind)

	-- multiplicity: Seq()
	if xarg.sequenceMaxLength then
		table.insert(decl_i, Data.Seq(tonumber(xarg.sequenceMaxLength)))
	end

	-- annotations
	decl_i = append_annotations(decl_i, xarg)
	
	return decl_i
end

function append_annotations(decl, xarg)
	assert(nil ~= decl, 'decl must be non-nil')
	for attribute, value in pairs(xarg) do
		if 'key' == attribute then 
			table.insert(decl, Data._.Key{})
		elseif 'topLevel' == attribute then
			table.insert(decl, Data._.top_level{value})
		end
	end
	
	return decl
end

function emit_enum(data, xarg, children)

	-- name
	local decl = {xarg.name}

	-- members
	for i, member in ipairs(children) do	    
		table.insert(decl, {member.xarg.name})
	end
	
	-- annotations
	decl = append_annotations(decl, xarg)

	return data:Enum(decl)
end

xml_visitor(xmlTable)

-- Data.print_idl(Data)
