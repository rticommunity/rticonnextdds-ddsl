#!/usr/local/bin/lua
-------------------------------------------------------------------------------
--  (c) 2005-2014 Copyright, Real-Time Innovations, All rights reserved.     --
--                                                                           --
-- Permission to modify and use for internal purposes granted.               --
-- This software is provided "as is", without warranty, express or implied.  --
--                                                                           --
-------------------------------------------------------------------------------
-- File: Data.lua 
-- Purpose: DDSL: Data type definition Domain Specific Language (DSL) in Lua
-- Created: Rajive Joshi, 2014 Feb 13
-------------------------------------------------------------------------------
-- TODO: Design Overview 
-- TODO: Create a github project for DDSL
--
-------------------------------------------------------------------------------

-- Data - singleton meta-data class implementing a semantic data definition 
--        model equivalent to OMG IDL, and easily mappable to various 
--        representations (eg OMG IDL, XML etc)
--
-- Purpose: 
-- 	   Serves several purposes
--     1. Provides a way of defining IDL equivalent data types (aka models) 
--     2. Provides helper methods to generate equivalent IDL  
--     3. Provides a natural way of indexing into a dynamic data sample 
--     4. Provides a way of creating instances of a data type, for example 
--        to stimulate an interface.
--     5. Provides the foundation for automated type (model) reasoning & mapping 
-- 
-- Usage:
--    Nomenclature
--        The nomenclature is used to refer to parts of a data type is 
--        illustrated using the example below:
--           struct Model {
--              Element1 role1;       // field1
--              Element2 role2;       // field2
--              seq<Element3> role3;  // field3
--           }   
--        where Element may be recursively defined as a Model with other parts.
--
--    Every user defined (model) is a table with the following meta-data keys
--        Data.NAME
--        Data.TYPE
--        Data.DEFN
--        Data.INSTANCE
--    The leaf elements of the table give a fully qualified string to address a
--    field in a dynamic data sample in Lua. 
--
--    Thus, an element definition in Lua:
-- 		 UserModule:Struct('UserType',
--          Data.has(user_role1, Data.string),
--          Data.contains(user_role2, UserModule.UserType2),
--          Data.contains(user_role3, UserModule.UserType3),
--          Data.has_list(user_role_seq, UserModule.UserTypeSeq),
--          :
--       )
--    results in the following table ('model') being defined:
--       UserModule.UserType = {
--          [Data.NAME] = 'UserType'     -- name of this model 
--          [Data.TYPE] = Data.STRUCT    -- one of Data.* type definitions
--          [Data.DEFN] = {              -- meta-data for the contained elements
--              user_role1    = Data.string,
--              user_role2    = UserModule.UserType2,
--				user_role3    = UserModule.UserType3,
--				user_role_seq = UserModule.UserTypeSeq,
--          }             
--          [Data.INSTANCE] = {}       -- table of instances of this model 
--                 
--          -- instance fields --
--          user_role1 = 'user_role1'  -- name used to index this 'leaf' field
--          user_role2 = Data.struct('user_role2', UserModule.UserType2)
--          user_role3 = Data.struct('user_role3', UserModule.UserType3)
--          user_role_seq = Data.seq('user_role_seq', UserModule.UserTypeSeq)
--          :
--       }
--    and also returns the above table.
--
--    The default UserModule is 'Data' (this class/table). A user defined
--    module is instantiated as follows
--       Data:Module('UserModule')
--    Submodules can be defined in a similar manner.
--       UserModule:Module('UserSubmodule')
--   
--    Note that if a definition already exists, it is cleared and re-defined.
--
--    To create an instance named 'i1' from a structure named 'Model'
--          i1 = Data.struct('i1', Model)
--    Now, one can instance all the fields of the resulting table
--          i1.role1 = 'i1.role1'
--    or 
--          Model[Data.INSTANCE].i1.role1
-- 
-- Implementation:
--    The meta-model pre-defines the following meta-data 
--    attributes for a model element:
--
--       Data.TYPE
--          Every model element 'model' is represented as a table with a 
--          non-nil key
--             model[Data.TYPE] = one of the Data.* type definitions
--
--       Data.NAME
--          For named i.e. composite model elements
--             model[Data.NAME] = name of the model element
--          For primitive/atomic model elements 
--             model[Data.NAME] = nil
--          This property can be used to determine if a model element is 
--			primitive.
--   
--       Data.DEFN
--          For storing the child element info
--              model[Data.DEFN][role] = role model element 
--
--       Data.INSTANCE
--          For storing instances of this model element, indexed by instance name
--              model[Data.DEFN].user = one of the instances of this model
--          where 'user' is the name of instance (in a container model element)
--
--    Note that instances do not have these the last two meta-data attributes.
--
--    The rest of the attributes are user defined fields of the model, as if 
--    it were a top-level instance:
--       <role i.e user_field>
--          Either a primitive field
--              model.role = 'role'
--          Or a composite field 
--              model.role = Data.struct('role', RoleModel)
--          or a sequence
--              model.role = Data.seq('role', RoleModel)
--
--    Note that all the meta-data attributes are functions, so it is 
--    straightforward to skip them, when traversing a model table.
Data = Data or {
	-- meta-data attributes ---
	-- every 'model' table has these keys defined 
	NAME      = function() end,  -- table key for 'model name'	
	TYPE      = function() end,  -- table key for the 'model type name' 
	DEFN      = function() end,  -- table key for element meta-data
	INSTANCE  = function() end,  -- table key for instances of this model
	
		
	-- meta-data types - i.e. list of possible user defined types ---
	-- possible 'model[Data.TYPE]' values implemented as closures
	MODULE    = function() return 'module' end,
	STRUCT    = function() return 'struct' end,
	UNION     = function() return 'union' end,
	ENUM      = function() return 'enum' end,
	ATOM      = function() return '' end,


	-- meta-data annotations ---
	-- sequence annotation (qualifier) on the base user-defined types
	-- return the length of the sequence or -1 for unbounded sequences
	SEQ       = function(n) return n == nil and -1 or 
							      (assert(type(n)=='number') and n) end,
							      
							     
	-- This top-level container is special in that:
	--  1. It defines the atomic types
	--  2. Provides an unnamed name-space ('root') that acts like a module
    --  3. But is technically not a user-defined module
}

--------------------------------------------------------------------------------
-- Model Element Definitions 
--------------------------------------------------------------------------------

function Data:Atom(name) 
	local model = {
		[Data.NAME] = name, 
		[Data.TYPE] = Data.ATOM,
		[Data.DEFN] = nil,   
		[Data.INSTANCE] = nil,
	}  
	self[name] = model -- add it to the namespace
	return model
end

-- Data:Module() - creates a new module
-- Purpose:
--    Create a user defined namespace, that inherits from the 'Data' namespace
-- Parameters:
-- 	  <<in>> name - module name to be created
--    <<returns>> the newly created namespace, also inserted into the calling
--                namespace
-- Usage:
--    To define a module called 'UserModule'
--       Data:Module('UserModule')
--    which results in the following being defined and returned
--       Data.UserModule = {
--          [Data.NAME] = 'UserModule'
--          [Data.TYPE] = Data.MODULE 
--       }
--   The UserModule table extends the 'Data' table, and inherits all the methods.
--   User defined types defined in the 'UserModule' will live in that table
--   namespace.
function Data:Module(name) 
	local model = { 
		[Data.NAME] = name,
		[Data.TYPE] = Data.MODULE,
		[Data.DEFN] = nil,   
		[Data.INSTANCE] = nil,
	}  
	
	-- inherit
	setmetatable(model, self)
	self.__index = self

	-- add it to the container module
	self[name] = model
	
	return model
end

function Data:Struct(name, ...) 
	local model = { 
		[Data.NAME] = name,
		[Data.TYPE] = Data.STRUCT,
		[Data.DEFN] = {},     -- will be populated as model elements are defined 
		[Data.INSTANCE] = nil,-- will be populated as instances are defined
	}
	
	-- populate the model table
	for i, field in ipairs{...} do	
		local role, element, seq_capacity = field[1], field[2], field[3]		
		local element_type = element[Data.TYPE]
				
		-- save the meta-data
		-- as an array to get the correct ordering:
		model[Data.DEFN][i] = { role, element, seq_capacity } -- skip the rest 
		-- as a table to get lookup the definition of a field
		model[Data.DEFN][role] = model[Data.DEFN][i] 
		
		-- populate the instance/role fields
		if seq_capacity then -- sequence
			model[role] = Data.seq(role, element)
		elseif Data.STRUCT == element_type then -- composite type
			model[role] = Data.struct(role, element)
		else -- enum or primitive 
			model[role] = role -- leaf is the role name
		end
	end
	
	-- add/replace the definition in the container model (module)
	self[name] = model
		
	return model
end


-- the 'model' is an array of strings and the ordinal values are assigned 
-- automatically starting at 0
function Data.enum(model) 
	local result = { [Data.TYPE] = Data.ENUM }
	for i, element in ipairs(model) do
		result[element] = i - 1 -- shift to a 0 based indexing
	end
	return result
end

-- the 'model' is a table of 'name = ordinal value' pairs
function Data.enum2(model) 
	local result = { [Data.TYPE] = Data.ENUM }
	for element, value in pairs(model) do
		result[element] = value
	end
	return result
end

--------------------------------------------------------------------------------
-- Relationship Definitions
--------------------------------------------------------------------------------

-- Data:has() - containment relationship
-- Purpose:
--    Create a nested model element
-- Parameters:
--    <<in>> name - name used to refer to the contained model element
--    <<in>> model - the contained  model element
--    <<return>> a table containing the name and a table that can be used 
--               to index into the 
-- Usage:
--    To define a contained element
--       Data.has('name', model)
--    which results in the following being defined and returned
--       { name, model_instance_table_for_indexing_using_name }
--
--    Thus, for example, if 
--       model = { 
--                 first = 'first',
--                 last  = 'last',
--                  :  
--               }
--    the returned value will be an array of two elements:
--      t =   { 'name',  { 
--                           first = 'name.first',
--                           last  = 'name.last',
--                            :  
--                        } 
--             }
--   such that in the returned table can index the nested elements:
--       t[2].first = 'name.first'
--       t[2].last  = 'name.last'
--  and so on. 
function Data.has(name, model)
	return {name, model}
end

function Data.has_list(name, model, n)
	return { name, model, Data.SEQ, n }
end 

--------------------------------------------------------------------------------
-- Model Element Instances  ---
--------------------------------------------------------------------------------

-- Data.struct() - creates an instance of a structure model element
-- Purpose:
--    Define a table that can be used to index into an instance of a model
-- Parameters:
-- 	  <<in>> role  - the role|instance name
-- 	  <<in>> model - the model element (table) to be instantiated
--    <<returns>> the newly created instance that supports indexing by 'role'
-- Usage:
-- TODO:
function Data.struct(role, model) -- type is required
	model[Data.INSTANCE] = model[Data.INSTANCE] or {}
	local result = model[Data.INSTANCE][role]
	
	-- print('DEBUG Data.struct: ', role, model[Data.NAME], model[Data.TYPE]())
	
	-- cache the result, so that we can reuse it the next time!
	if not result then 
		result = { [Data.NAME] = model[Data.NAME],
				   [Data.TYPE] = model[Data.TYPE],
		}
		for k, v in pairs(model) do
			local type_v = type(v)
			-- skip meta-data attributes
			if type(k) ~= 'function' then 
				if type_v == 'function' then -- seq: prefix the field name
					result[k] = function(i, prefix) -- allow further prefixing
									return v(i, prefix or '' .. role .. '.') 
								end
				elseif type_v == 'table' then -- nested struct: prefix field names
					result[k] = Data.struct(role, v) -- create from instance
				else -- simple struct: prefix the field names
					result[k] = role .. '.' .. v
				end
			end
		end
		model[Data.INSTANCE][role] = result
	end
	
	return result
end

function Data.seq(role, model) -- type is OPTIONAL
	-- print('DEBUG Data.seq', role, model[Data.TYPE](), model[Data.NAME])
	return function (i, prefix)
		local prefix = prefix or ''
		return i -- index 
				 and (model[Data.TYPE] == Data.ATOM
					  -- primitive
				      and string.format('%s%s[%d]', prefix, role, i)
					  -- composite
					  or Data.struct(string.format('%s%s[%d]', prefix, role, i), model))
				 -- length
			     or string.format('%s%s#', prefix, role)
	end
end

-- TODO: function Data.union(role1, type1, role2, type2, ...) -- types required
--[[
function Data.union(role, type, ...) -- type is required
	local result = Data.struct(role, type)
	result._d = role .. '#'
	return result
end
--]]

-- TODO: remove
function Data.len(seq)
	return seq .. '#'
end
-- TODO: remove
function Data.idx(seq, i, role)
	return seq .. '[' .. i .. ']' .. (role and ('.' .. role) or '')
end


--------------------------------------------------------------------------------
-- Predefined Types
--------------------------------------------------------------------------------

-- Data:Atom('double')

Data:Atom('string')
Data:Atom('double')

-- Disallow user defined atoms!
Data.Atom = nil

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

-- Data.print_idl() - prints OMG IDL representation of a data model
--
-- Purpose:
-- 		Generate equivalent OMG IDL representation from a data model
-- Parameters:
--    <<in>> model - the data model element
--    <<in>> indent_string - the indentation string to apply
--    <<return>> model, indent_string for chaining
-- Usage:
--         Data.print_idl(model) 
--           or
--         Data.print_idl(model, '   ')
function Data.print_idl(model, indent_string) 
	local model = model or Data  -- treat nil model as top-level 'Data'
	local indent_string = indent_string or ''
	local content_indent_string = indent_string
	local mytype = model[Data.TYPE]
	local myname = model[Data.NAME]
	local mymeta = model[Data.DEFN]
		
	-- print('DEBUG print_idl: ', Data, model, mytype(), myname)
	
	-- open --
	if (Data ~= model) then -- not top-level
		print(string.format('\n%s%s %s {', indent_string, mytype(), myname))
		content_indent_string = indent_string .. '   '
	end
		
	if Data == model or -- top-level
	   Data.MODULE == mytype then 
		for k, v in pairs(model) do
			-- print('DEBUG print_idl module: ', Data, k, v)
			if 'string' == type(k) and 'table' == type(v) and 
			    nil ~= v[Data.TYPE] and -- skip entries that are not model elements
			   	Data.ATOM ~=v[Data.TYPE] then -- skip atomic types
				-- print each model element ---
				Data.print_idl(v, content_indent_string)
			end
		end
		
	elseif Data.STRUCT == mytype then
		for i, field in ipairs(mymeta) do
			local role, element, seq_max_size = field[1], field[2], field[3]		

			if seq_max_size == nil then 
				print(string.format('%s%s %s;', content_indent_string, 
												element[Data.NAME], role))
			elseif seq_max_size < 0 then -- unbounded sequence
				print(string.format('%sseq<%s> %s;', content_indent_string, 
								element[Data.NAME], 
								role))
			else -- bounded sequence
				print(string.format('%sseq<%s,%d> %s;', content_indent_string, 
							   element[Data.NAME], 
							   seq_max_size,
							   role))

			end
		end

	elseif Data.ENUM == mytype then 
		for role, ord in pairs(model) do		
			if ord ~= mytype then 
				print(string.format('%s%s = %s,', content_indent_string, 
												  role, ord))
			end
		end
	end
	
	-- close --
	if (Data ~= model) then -- not top-level
		print(string.format('%s};', indent_string))
	end
	
	return model, indent_string
end


function Data.index(model, result) 
	local mytype = model[Data.TYPE]
	
	-- only meaningful for top-level types that can be instantiated:
	if (Data.STRUCT ~= mytype and Data.UNION ~= mytype) then
		return result
	end

	local result = result or {}	-- must be a top-level type, ie a struct or union	
	for k, v in pairs(model) do
		local type_k, type_v = type(k), type(v) 
		-- skip meta-data attributes
		
		if 'string' == type(k) then
			if 'table' == type_v then -- composite (nested)
				result = Data.index(v, result)
				
			elseif 'function' == type_v then -- sequence
			
				-- length operator
				table.insert(result, v())
				
				-- index 1 for illustration
				if 'table' == type(v(1)) then -- composite sequence
					Data.index(v(1), result) -- recurse for the 1st element
				else -- primitive sequence
					table.insert(result, v(1))
				end
			
			elseif 'string' == type_v then -- leaf
				table.insert(result, v) 
			end
		end
	end
	return result
end

--------------------------------------------------------------------------------
-- TESTS 
--------------------------------------------------------------------------------

---[[ SKIP TESTS --

-- Equivalent to:
--    Data.Test = {
--        [Data.TYPE] = Data.MODULE 
--        [Data.NAME] = 'Test'
--    }
-- NOTE: if you want Test to be local, declare it as a local first
--       eg:
--           local Test
--           Data:Module('Test')
local Test = Data:Module('Test')

--[[
--
-- Equivalent to:
--    Test.Month = {
--        [Data.NAME] = 'Month'
--        [Data.TYPE] = Data.ENUM 
--        MON         = 0
--        TUE         = 1
--		  WED         = 2
--    }
Test:Enum{'Days', 
	'MON', 'TUE', 'WED', -- ' THU', 'FRI', 'SAT', 'SUN'
}

Test:Module("Subtest")

Test.Subtest:Enum{'Colors', 
	RED   = 5,
	BLUE  = 7,
	GREEN = 9,
}

--]]

-- Equivalent to:
--    Test.Name = {
--        [Data.NAME] = 'Name'
--        [Data.TYPE] = Data.STRUCT 
--        first       = 'first'
--        last        = 'last'
--        favorite    = 'favorite'
--    }  
Test:Struct('Name', 
	{'first', Data.string}, --	{ first = Data.string },
	{'last',  Data.string},
	{'nicknames',  Data.string, Data.SEQ(3) },
	{'aliases',  Data.string, Data.SEQ() }
	-- Data.has('favorite', Test.Subtest.Colors),
)


-- Equivalent to:
--    Test.Address = {
--        [Data.NAME] = 'Address'
--        [Data.TYPE] = Data.STRUCT 
--        name        = Data.struct('name', Test.Name)
--        street      = 'street'
--        city        = 'city'
--    }  

Test:Struct('Address',
	Data.has('name', Test.Name),
	Data.has('street', Data.string),
	Data.has('city',  Data.string)
)

-- Equivalent to:
--    Test.Directory = {
--        [Data.NAME] = 'Company'
--        [Data.TYPE] = Data.STRUCT 
--        info        = Data.union('info', Test.NameOrAddress)
--        employees   = Data.seq('employees', Test.Name)
--        coord       = Data.seq('coord', Data.string)
--    }  
Test:Struct('Company',
	-- {'info', Test.NameOrAddress),
	{ 'offices', Test.Address, Data.SEQ(10) },
	{ 'employees', Test.Name, Data.SEQ() },
	{ 'hq', Data.string, Data.SEQ(2) }
)

--[[
-- Equivalent to:
--    Test.FullName = {
--        [Data.NAME] = 'FullName'
--        [Data.TYPE] = Data.STRUCT 
--        first       = 'first'
--        last        = 'last'
--        middle      = 'middle'
--    }  
Test:Struct{'FullName',
	Data.extends(Test.Name),  -- extends base type
	Data.has('middle',  Data.string),
}

-- Equivalent to:
--    Test.NameOrAddress = {
--        [Data.NAME] = 'NameOrAddress'
--        [Data.TYPE] = Data.UNION 
--        name        = Data.struct('name', Test.Name)
--        address     = Data.struct('address', Test.Address)
--    }  
Test:Union{'NameOrAddress',
	Data.contains('name', Test.Name),
	Data.contains('address', Test.Address),
}

--[[
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
	first = Data.STRING,
	last  = Data.STRING,
}

Test.Address = Data.struct2{
	name    = Data.struct('name', Test.Name),
	street  = Data.STRING,
	city    = Data.STRING,
}
--]]

function Test.print_index(model)
	local result = Data.index(model)
	if result == nil then return end
	
	print('\nindex:')
	for i, v in ipairs(result) do
		print('   ', v)	
	end
end

function Test:print(model)
	Data.print_idl(model)
	self.print_index(model)
end

function Test:test_struct_basic()
	self:print(Test.Name)
end

function Test:test_struct_composite()
	self:print(Test.Address)
end

function Test:test_struct_seq()
	self:print(Test.Company)
end

function Test:test_module()
	self:print(Test)
end

function Test:test_root()
	self:print(Data)
end

function Test:Xtest_submodule()
	self:print(Test.Submodule)
end


function Test:Xtest_struct_inheritance()
	-- Inheritance
	print(Test.FullName[Data.NAME])
	for i, v in ipairs(Data.index(Test.FullName)) do
		print(v)	
	end
		
	-- Union
	print(Test.NameOrAddress[Data.NAME])
	for i, v in ipairs(Data.index(Test.NameOrAddress)) do
		print(v)	
	end
	
	-- Sequences and Unions
	print(Test.Company[Data.NAME])
	for i, v in ipairs(Data.index(Test.Company)) do
		print(v)	
	end
	--]]
end

function Test:Xtest_enum()
	Data.print_idl(Test.Days)
	Data.print_idl(Test.Subtest.Colors)
end

-- main() - run the list of tests passed on the command line
--          if no command line arguments are passed in, run all the tests
function Test:main()
	if #arg > 0 then -- run selected tests passed in from the command line
		for i, test in ipairs (arg) do
			print('\n--- ' .. test .. ' ---')
			Test[test](Test) -- run the test
		end
	else -- run all  the tests
		for k, v in pairs (self) do
			if type(k) == "string" and string.sub(k, 1,4) == "test" then
				print('\n--- ' .. k .. ' ---')
				v(self) 
			end
		end
	end
end

Test:main()
 
-- SKIP TESTS --]]
--------------------------------------------------------------------------------
