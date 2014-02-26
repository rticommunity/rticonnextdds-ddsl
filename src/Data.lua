#!/usr/local/bin/lua
-------------------------------------------------------------------------------
--  (c) 2005-2014 Copyright, Real-Time Innovations, All rights reserved.     --
--                                                                           --
--         Permission to modify and use for internal purposes granted.       --
-- This software is provided "as is", without warranty, express or implied.  --
--                                                                           --
-------------------------------------------------------------------------------
-- File: Data.lua 
-- Purpose: Meta-Data (singleton) class to provide helpers for defining 
--          naturally addressable DataTypes in Lua
-- Created: Rajive Joshi, 2014 Feb 13
-------------------------------------------------------------------------------
-- TODO: Design Overview 
--
-------------------------------------------------------------------------------

Data = Data or {
	-- type meta-data definitions are closures to ensure immutability ---
	
	TYPE      = '__typeinfo', -- name of the type definition closure
	
	-- structural types ---
	MODULE    = function() return 'module', name end,
	ENUM      = function() return 'enum', name end,
	STRUCT    = function() return 'struct' end,
	UNION     = function() return 'union' end,
	SEQ       = function() return 'seq' end,

	-- primitive types ---
	STRING    = function() return 'string' end,
}

function Data.print(name, model, indent_string) 
	local indent_string = indent_string or ''
	local content_indent_string = indent_string .. '   '
	local mytypeinfo = model[Data.TYPE] or Data.MODULE -- default type
	local mytypename = mytypeinfo()
	local myname = name
	
	-- open --
	print(string.format('%s%s %s {', indent_string, mytypename, myname))
			
			
	-- recursively print each element ---
	if Data.MODULE == mytypeinfo then 
		for field, element in pairs(model) do
			-- recursively print the contained elements ---
			if (type(element) == 'table') then
				Data.print(field, element, content_indent_string)
			end	
		end
		
	elseif Data.ENUM == mytypeinfo then 
		for field, ord in pairs(model) do		
			if ord ~= mytypeinfo then 
				print(content_indent_string .. field .. ' = ' .. ord .. ',')
			end
		end
		
	elseif Data.STRUCT == mytypeinfo then
		for field, element in pairs(model) do	
			if field ~= Data.TYPE then
				if type(element) == 'function' then -- primitive type
					print(content_indent_string .. element() 
					.. '  ' .. field .. ';')
				else -- structural type
					print(content_indent_string .. element[Data.TYPE]() 
					.. '  ' .. field .. ';')
				end
			end
		end
		
	elseif Data.STRING == mytypeinfo then
		print(content_indent_string .. string .. '   ' .. name .. ',')
	end
	
	-- close --
	print(string.format('%s};\n', indent_string))
end

-- creates a new namespace: returns a namespace table 
function Data.namespace(name) 
	result = { [Data.TYPE] = Data.NAMESPACE(name) }  
	return result
end

-- the 'model' is an array of strings and the ordinal values are assigned 
-- automatically starting at 0
function Data.enum(model) 
	local result = { [Data.TYPE] = Data.ENUM }
	for i, field in ipairs(model) do
		result[field] = i - 1 -- shift to a 0 based indexing
	end
	return result
end

-- the 'model' is a table of 'name = ordinal value' pairs
function Data.enum2(model) 
	local result = { [Data.TYPE] = Data.ENUM }
	for field, value in pairs(model) do
		result[field] = value
	end
	return result
end

function Data.struct2(model) -- model must be a table
	model[Data.TYPE] = Data.STRUCT 
	return model
end

function Data.struct(field, type) -- type is required
	-- lookup result
	Data[type] = Data[type] or {}
	local result = Data[type][field] 
	
	-- cache the result, so that we can reuse it the next time!
	if not result then 
		result = {}
		for k, v in pairs(type) do
			result[k] = field .. '.' .. v
		end
		Data[type][field] = result
	end
	
	return result
end

function Data.seq(field, type) -- type is OPTIONAL
	return function (i)
		return i and (type and Data.struct(field .. '[' .. i .. ']', type)
				           or field .. '[' .. i .. ']')
			     or field .. '#'
	end
end

-- TODO: function Data.union(field1, type1, field2, type2, ...) -- types required
--[[
function Data.union(field, type, ...) -- type is required
	local result = Data.struct(field, type)
	result._d = field .. '#'
	return result
end
--]]

function Data.len(seq)
	return seq .. '#'
end

function Data.idx(seq, i, field)
	return seq .. '[' .. i .. ']' .. (field and ('.' .. field) or '')
end

--------------------------------------------------------------------------------
-- TESTS 
--------------------------------------------------------------------------------

---[[ SKIP TESTS --

local Test = Test or {}

Test.Days = Data.enum{
	'MON', 'TUE', 'WED', 'THU',
}

Test.Subtest = {}

Test.Subtest.Colors = Data.enum2{
	RED   = 5,
	BLUE  = 7,
	GREEN = 9,
}

Test.Name = Data.struct2{
	first   = Data.STRING,
	last    = Data.STRING,
}

--[[
Test:struct3('Name', {
	first   = Data.STRING,
	last    = Data.STRING,
})
--]]

Test.Address = Data.struct2{
	name    = Test.Name,
	street  = Data.STRING,
	city    = Data.STRING,
}

function Test:test_enum()
	print('\n--- test enums ---')
	Data.print('Days', Test.Days)
	Data.print('Colors', Test.Subtest.Colors)
end

function Test:test_module()
	print('\n--- test module ---')
	Data.print('Test', Test)
	Data.print('Subtest', Test.Subtest)
end

function Test:main()
	for k, v in pairs (self) do
		if string.sub(k, 1,4) == "test" then
			v(self) 
		end
	end
end

Test:main()
 
-- SKIP TESTS --]]
--------------------------------------------------------------------------------
