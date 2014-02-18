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

Data = Data or {}

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

-- TODO: function Data.union(field, type) -- type is required

function Data.len(seq)
	return seq .. '#'
end

function Data.idx(seq, i, field)
	return seq .. '[' .. i .. ']' .. (field and ('.' .. field) or '')
end
