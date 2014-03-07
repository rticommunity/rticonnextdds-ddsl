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
-- Created: Rajive Joshi, 2014 Feb 14
-------------------------------------------------------------------------------
-- TODO: Design Overview 
-- TODO: Create a github project for DDSL
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
--     6. Can be used to automatically serialize and de-serialize a sample
--     7. Multiple styles to specify a type
--     8. Can easily add new (meta-data) types and annotations in the meta-model
--     9. Can be used for custom code generation
--    10. Can be used to generate TypeObject/TypeCode on the wire
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
--
-- 
--    This top-level container is special in that:
--    	 1. It defines the atomic types
-- 		 2. Provides an unnamed name-space ('root') that acts like a module
--       3. But is technically not a user-defined module
--
Data = Data or {
	-- instance attributes ---
	-- every 'instance' table has this meta-data key defined
	-- the rest of the keys are fields of the instance
	MODEL      = function() end,  -- table key for 'model' meta-data	
	
		
	-- model meta-data attributes ---
	-- every 'model' meta-data table has these keys defined 
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
	ATOM      = function() return 'atom' end,
}

--------------------------------------------------------------------------------
-- Model Definitions -- 
--------------------------------------------------------------------------------

-- Root Module/namespace:
--    Bootstrap the type-system
--      The Data table acts as un-named module (i.e. namespace) instance
--      Here is the underlying model definition for it.
Data[Data.MODEL] = { 
	[Data.NAME] = nil,     -- unnamed root module
	[Data.TYPE] = Data.MODULE,
	[Data.DEFN] = {},      -- empty
	[Data.INSTANCE] = nil, -- always nil
}

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
	assert(type(name) == 'string', 
		   table.concat{'invalid module name: ', tostring(name)})
	local model = { 
		[Data.NAME] = name,
		[Data.TYPE] = Data.MODULE,
		[Data.DEFN] = {},      -- empty  
		[Data.INSTANCE] = nil, -- always nil
	}  
	local instance = { -- top-level instance to be installed in the module
		[Data.MODEL] = model,
	}
	
	-- inherit from container module
	setmetatable(instance, self)
	self.__index = self

	-- add/replace the definition in the container module
	if self[name] then print('WARNING: replacing ', name) end
	self[name] = instance
	table.insert(self[Data.MODEL][Data.DEFN], instance)
	
	return instance
end

-- Install an atomic type in the module
function Data:Atom(name) 
	assert(type(name) == 'string', 
		   table.concat{'invalid atom name: ', tostring(name)})
	local model = {
		[Data.NAME] = name, 
		[Data.TYPE] = Data.ATOM,
		[Data.DEFN] = nil,      -- always nil
		[Data.INSTANCE] = nil,  -- always nil
	}  
	local instance = { -- top-level instance to be installed in the module
		[Data.MODEL] = model,
	}

	-- add/replace the definition in the container module
	if self[name] then print('WARNING: replacing ', name) end
	self[name] = instance
	table.insert(self[Data.MODEL][Data.DEFN], instance)
	
	return instance
end

function Data:Struct(name, ...) 
	assert(type(name) == 'string', 
		   table.concat{'invalid struct name: ', tostring(name)})
	local model = { -- meta-data defining the struct
		[Data.NAME] = name,
		[Data.TYPE] = Data.STRUCT,
		[Data.DEFN] = {},     -- will be populated as model elements are defined 
		[Data.INSTANCE] = nil,-- will be populated as instances are defined
	}
	local instance = { -- top-level instance to be installed in the module
		[Data.MODEL] = model,
	}
	
	-- populate the model table
	for i, spec in ipairs{...} do	
		local role, element, seq_capacity = spec[1], spec[2], spec[3]		

		assert(type(role) == 'string', 
		  table.concat{'invalid struct member name: ', tostring(role)})
		assert('table' == type(element), 
		  table.concat{'undefined type for struct member "', tostring(role), '"'})
		assert(nil ~= element[Data.MODEL], 
		  table.concat{'invalid type for struct member "', tostring(role), '"'})
	
		local element_type = element[Data.MODEL][Data.TYPE]
		
		-- populate the instance/role fields
		if seq_capacity then -- sequence
			instance[role] = Data.seq(role, element)
		elseif Data.STRUCT == element_type or Data.UNION == element_type then
			instance[role] = Data.struct(role, element)
		else -- enum or primitive 
			instance[role] = role -- leaf is the role name
		end
		
		-- save the meta-data
		-- as an array to get the correct ordering
		table.insert(model[Data.DEFN], { role, element, seq_capacity }) 
	end
	
	-- add/replace the definition in the container module
	if self[name] then print('WARNING: replacing ', name) end
	self[name] = instance
	table.insert(self[Data.MODEL][Data.DEFN], instance)
		
	return instance
end

function Data:Union(param) 
	assert('table' ~= param, 
		   table.concat{'invalid union specification: ', tostring(param)})

	local name = param[1]   table.remove(param, 1)
	assert('string' == type(name), 
		   table.concat{'invalid union name: ', tostring(name)})
		   
	local discriminator = param[1]   table.remove(param, 1)
	assert('table' ~= discriminator, 
			table.concat{'invalid union discriminator', name})
	assert(nil ~= discriminator[Data.MODEL], 
			table.concat{'undefined union discriminator type: ', name})
			
	local model = { -- meta-data defining the struct
		[Data.NAME] = name,
		[Data.TYPE] = Data.UNION,
		[Data.DEFN] = {},     -- will be populated as model elements are defined 
		[Data.INSTANCE] = nil,-- will be populated as instances are defined
	}
	local instance = { -- top-level instance to be installed in the module
		[Data.MODEL] = model,
	}
	
	-- add the discriminator
	model[Data.DEFN]._d = discriminator
	instance._d = '#'

	-- populate the model table
	-- print('DEBUG Union 1: ', name, discriminator[Data.MODEL][Data.TYPE](), discriminator[Data.MODEL][Data.NAME])			
	for i, spec in ipairs(param) do	
		local case = nil
		if #spec > 1 then case = spec[1]  table.remove(spec, 1) end -- case
		
		local role, element, seq_capacity = spec[1][1], spec[1][2], spec[1][3]
		-- print('DEBUG Union 2: ', case, role, element, seq_capacity)
				
		Data.assert_case(case, discriminator)
		assert(type(role) == 'string', 
		  table.concat{'invalid union member name: ', tostring(role)})
		assert('table' == type(element), 
		  table.concat{'undefined type for union member "', tostring(role), '"'})
		assert(nil ~= element[Data.MODEL], 
		  table.concat{'invalid type for union member "', tostring(role), '"'})
	
		local element_type = element[Data.MODEL][Data.TYPE]
		
		-- populate the instance/role fields
		if seq_capacity then -- sequence
			instance[role] = Data.seq(role, element)
		elseif Data.STRUCT == element_type or Data.UNION == element_type then 
			instance[role] = Data.struct(role, element)
		else -- enum or atom 
			instance[role] = role -- leaf is the role name
		end
				
		-- save the meta-data
		-- as an array to get the correct ordering
		-- NOTE: default case is stored a 'nil'
		table.insert(model[Data.DEFN], { case, {role, element, seq_capacity} }) 
	end
	
	-- add/replace the definition in the container module
	if self[name] then print('WARNING: replacing ', name) end
	self[name] = instance
	table.insert(self[Data.MODEL][Data.DEFN], instance)
		
	return instance
end

function Data:Enum(name, ...) 
	assert(type(name) == 'string', 
		   table.concat{'invalid enum name: ', tostring(name)})
	local model = { -- meta-data defining the struct
		[Data.NAME] = name,
		[Data.TYPE] = Data.ENUM,
		[Data.DEFN] = {},     -- will be populated as enumerations
		[Data.INSTANCE] = nil,-- always nil
	}
	local instance = { -- top-level instance to be installed in the module
		[Data.MODEL] = model,
	}
	
	-- populate the model table
	for i, spec in ipairs{...} do	
		local role, ordinal = spec[1], spec[2]	
		assert(type(role) == 'string', 
				table.concat{'invalid enum member: ', tostring(role)})
		assert(nil == ordinal or 'number' == type(ordinal), 
		     table.concat{'invalid enum ordinal value: ', tostring(ordinal) })
				
		if ordinal then
			assert(math.floor(ordinal) == ordinal, -- integer 
			 table.concat{'enum ordinal not an integer: ', tostring(ordinal) }) 
		end
					
		-- populate the enum elements
		local myordinal = ordinal or (i - 1) -- ordinals start at 0		
		instance[role] = myordinal
		
		-- save the meta-data specification
		-- as an array to get the correct ordering when printing/visiting
		table.insert(model[Data.DEFN], { role, ordinal }) 
	end
	
	-- add/replace the definition in the container module
	if self[name] then print('WARNING: replacing ', name) end
	self[name] = instance
	table.insert(self[Data.MODEL][Data.DEFN], instance)
		
	return instance
end
		
		
-- meta-data annotations ---
-- sequence annotation (qualifier) on the base user-defined types
-- return the length of the sequence or -1 for unbounded sequences
function Data.Seq(n) 
	return n == nil and -1 
	                or (assert(type(n)=='number', 
	                    table.concat{'invalid sequence capacity: ', tostring(n)}) 
	                    and n) 
end

--------------------------------------------------------------------------------
-- Model Instances  ---
--------------------------------------------------------------------------------

-- Data.struct() - creates an instance of a structure model element
-- Purpose:
--    Define a table that can be used to index into an instance of a model
-- Parameters:
-- 	  <<in>> role  - the role|instance name
-- 	  <<in>> model - the model element (table) to be instantiated
--    <<returns>> the newly created instance that supports indexing by 'role'
-- Usage:
function Data.struct(name, template) 
	-- print('DEBUG Data.struct: ', name, template[Data.MODEL][Data.NAME])
	assert(type(name) == 'string', 
		   table.concat{'invalid instance name: ', tostring(name)})
	
	-- ensure valid template
	assert('table' == type(template), 'template missing!')
	assert(template[Data.MODEL],
		   table.concat{'invalid instance template: ', tostring(name)})
	assert(Data.STRUCT == template[Data.MODEL][Data.TYPE] or 
		   Data.UNION == template[Data.MODEL][Data.TYPE],
		   table.concat{'template must be a struct or union: ', tostring(name)})

	-- try to retrieve the instance from the template
	template[Data.INSTANCE] = template[Data.INSTANCE] or {}
	local instance = template[Data.INSTANCE][name]
	
	-- not found => create the instance:
	if not instance then 
		instance = { -- the underlying model, of which this is an instance 
			[Data.MODEL] = template[Data.MODEL], 		
		}
		for k, v in pairs(template) do
			local type_v = type(v)
			
			-- skip meta-data attributes
			if 'string' == type(k) then 
				-- prefix the member names
				if 'function' == type_v then -- seq
					instance[k] = -- use member as a closure template
						function(i, prefix) -- allow further prefixing
							return v(i, table.concat{prefix or '', name, '.'}) 
						end
				elseif 'table' == type_v then -- struct
					instance[k] = Data.struct(name, v) -- use member as template
				elseif 'string' == type_v then -- atom/leaf
					if '#' == v then -- _d: leaf level union discriminator
						instance[k] = table.concat{name, '', v} -- no dot separator
					else
						instance[k] = table.concat{name, '.', v}
					end
				end
			end
		end
		
		-- cache the instance, so that we can reuse it the next time!
		template[Data.INSTANCE][name] = instance
	end
	
	return instance
end

function Data.seq(name, template) 
	-- print('DEBUG Data.seq', name, template[Data.MODEL][Data.NAME])
	assert(type(name) == 'string', 
		   table.concat{'invalid instance name', tostring(name)})
	
	-- ensure valid template
	assert('table' == type(template), 'template missing!')
	assert(template[Data.MODEL] and 
		   (Data.STRUCT == template[Data.MODEL][Data.TYPE] or 
		    Data.UNION == template[Data.MODEL][Data.TYPE] or
		  	Data.ENUM == template[Data.MODEL][Data.TYPE] or
		    Data.ATOM == template[Data.MODEL][Data.TYPE]),
		    table.concat{'invalid template for seq: ', tostring(name)})
		  
	-- return a closure that will generate the correct index string for 'name'
	--    if no argument is provided then generate the length operator string
	--    else generate the element i access string
	return function (i, prefix)
	
		local prefix = prefix or ''
		return i -- index 
				 and ((Data.STRUCT == template[Data.MODEL][Data.TYPE] or 
		   			   Data.UNION == template[Data.MODEL][Data.TYPE])
					  -- composite
					  and 
					  	Data.struct(string.format('%s%s[%d]', prefix, name, i), 
					  				 template)
					  or -- primitive
				      	string.format('%s%s[%d]', prefix, name, i))
				 -- length
			     or string.format('%s%s#', prefix, name)
	end
end

-- Ensure that case is a valid discriminator value
function Data.assert_case(case, discriminator)
	-- TODO: implement assert_case
	return case
end
		
--------------------------------------------------------------------------------
-- Predefined Types
--------------------------------------------------------------------------------

-- Data:Atom('double')

Data:Atom('string')
Data:Atom('double')
Data:Atom('long')
Data:Atom('short')
Data:Atom('boolean')
Data:Atom('char')
Data:Atom('octet')

-- Disallow user defined atoms!
Data.Atom = nil
	
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
function Data.has(name, model, sequence)
	return { name, model, sequence }
end

function Data.case(value, name, model)
	return { value, name, model }
end 

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
function Data.print_idl(instance, indent_string)
	-- ensure valid instance
	assert('table' == type(instance), 'instance missing!')
	assert(instance[Data.MODEL], 'invalid instance')

	local indent_string = indent_string or ''
	local content_indent_string = indent_string
	local model = instance[Data.MODEL]
	local myname = model[Data.NAME]
	local mytype = model[Data.TYPE]
	local mydefn = model[Data.DEFN]
		
	-- print('DEBUG print_idl: ', Data, model, mytype(), myname)
	
	-- skip atomic types
	if Data.ATOM == mytype then return result, indent_string end
	
	-- open --
	if (nil ~= myname) then -- not top-level
		if Data.UNION == mytype then
			print(string.format('\n%s%s %s switch (%s) {', indent_string, 
						mytype(), myname, mydefn._d[Data.MODEL][Data.NAME]))
		else
			print(string.format('\n%s%s %s {', indent_string, mytype(), myname))
		end
		content_indent_string = indent_string .. '   '
	end
		
	if Data.MODULE == mytype then 
		for i, member in ipairs(mydefn) do -- walk through the module definition
			Data.print_idl(member, content_indent_string)
		end
		
	elseif Data.STRUCT == mytype then 
		for i, spec in ipairs(mydefn) do -- walk through the model definition
			local role, element, seq_max_size = spec[1], spec[2], spec[3]		

			if seq_max_size == nil then -- not a sequence
				print(string.format('%s%s %s;', content_indent_string, 
									element[Data.MODEL][Data.NAME], role))
			elseif seq_max_size < 0 then -- unbounded sequence
				print(string.format('%sseq<%s> %s;', content_indent_string, 
									element[Data.MODEL][Data.NAME], role))
			else -- bounded sequence
				print(string.format('%sseq<%s,%d> %s;', content_indent_string, 
						    element[Data.MODEL][Data.NAME], seq_max_size, role))
			end
		end

	elseif Data.UNION == mytype then 
		for i, spec in ipairs(mydefn) do -- walk through the model definition
			local case = spec[1]
			local role, element, seq_max_size = spec[2][1], spec[2][2], spec[2][3]		

			-- case
			local case_string = (nil == case) and 'default' or tostring(case)
			if (Data.char == mydefn._d and nil ~= case) then
				print(string.format("case '%s' :", case_string))
			else
				print(string.format("case %s :", case_string))
			end
			
			-- definition
			if seq_max_size == nil then -- not a sequence
				print(string.format('   %s%s %s;', content_indent_string, 
									element[Data.MODEL][Data.NAME], role))
			elseif seq_max_size < 0 then -- unbounded sequence
				print(string.format('   %sseq<%s> %s;', content_indent_string, 
									element[Data.MODEL][Data.NAME], role))
			else -- bounded sequence
				print(string.format('   %sseq<%s,%d> %s;', content_indent_string, 
						    element[Data.MODEL][Data.NAME], seq_max_size, role))
			end
		end
		
	elseif Data.ENUM == mytype then
		for i, spec in ipairs(mydefn) do -- walk through the model definition	
			local role, ordinal = spec[1], spec[2]
			if ordinal then
				print(string.format('%s%s = %s,', content_indent_string, role, 
								    ordinal))
			else
				print(string.format('%s%s,', content_indent_string, role))
			end
		end
	end
	
	-- close --
	if (nil ~= myname) then -- not top-level
		print(string.format('%s};', indent_string))
	end
	
	return instance, indent_string
end


function Data.index(instance, result) 
	-- ensure valid instance
	assert('table' == type(instance), 'instance missing!')
	assert(instance[Data.MODEL], 'invalid instance')
	local mytype = instance[Data.MODEL][Data.TYPE]
	
	local mydefn = instance[Data.MODEL][Data.DEFN]
	
	-- skip if not an indexable type:
	if Data.STRUCT ~= mytype and Data.UNION ~= mytype then return result end
	
	-- print('DEBUG index: ', mytype(), instance[Data.MODEL][Data.NAME])
			
	-- preserve the order of model definition
	local result = result or {}	-- must be a top-level type	
	
	-- discriminator
	if Data.UNION == mytype then
		table.insert(result, instance._d) 
	end
	
	-- walk through the body of the model definition	
	for i, spec in ipairs(mydefn) do 
		local role, element, seq_max_size 
		
		if Data.STRUCT == mytype then
			 role, element, seq_max_size = spec[1], spec[2], spec[3]
		elseif Data.UNION == mytype then
			 role, element, seq_max_size = spec[2][1], spec[2][2], spec[2][3]
		end
		
		local instance_member = instance[role]
		if seq_max_size == nil then -- not a sequence
			if 'table' == type(instance_member) then -- composite (nested)
				result = Data.index(instance_member, result)
			else -- atom (leaf)
				table.insert(result, instance_member) 
			end
		else -- sequence
			-- length operator
			table.insert(result, instance_member())

			-- index 1st element for illustration
			if 'table' == type(instance_member(1)) then -- composite sequence
				Data.index(instance_member(1), result) -- index the 1st element 
			else -- primitive sequence
				table.insert(result, instance_member(1))
			end
		end
	end

	return result
end

--------------------------------------------------------------------------------
-- TESTS 
--------------------------------------------------------------------------------

---[[ SKIP TESTS --

local Test = Data:Module('Test')

Test:Enum('Days', 
	{'MON'}, {'TUE'}, {'WED'}, {'THU'}, {'FRI'}, {'SAT'}, {'SUN'}
)

Test:Enum('Months', 
	{ 'JAN', 1 },
	{ 'FEB', 2 },
	{ 'MAR', 3 }
)

Test:Module("Subtest")

Test.Subtest:Enum('Colors', 
	{ 'RED',   -5 },
	{ 'BLUE',  7 },
	{ 'GREEN', -9 },
	{ 'PINK' }
)

Test.Subtest:Struct('Fruit', 
	{ 'weight', Data.double },
	{ 'color' , Test.Subtest.Colors}
)

Test:Struct('Name', 
	{'first', Data.string},
	{'last',  Data.string},
	{'nicknames',  Data.string, Data.Seq(3) },
	{'aliases',  Data.string, Data.Seq() },
	{'birthday', Test.Days },
	{'favorite', Test.Subtest.Colors, Data.Seq(2) }
)

Test:Struct('Address',
	Data.has('name', Test.Name),
	Data.has('street', Data.string),
	Data.has('city',  Data.string)
)

Test:Union{'Chores', Test.Days,
	{ 'MON', 
		{'name', Test.Name}},
	{ 'TUE', 
		{'address', Test.Address}},
	{ -- default
		{'x', Data.double}},		
}

Test:Union{'TestUnion1', Data.char,
	{ 'c', 
		{'name', Test.Name}},
	{ 'a', 
		{'address', Test.Address}},
	{ -- default
		{'x', Data.double}},
}

Test:Union{'TestUnion2', Data.short,
	{ 1, 
		{'x', Data.string}},
	{ 2, 
		{'y', Data.double}},
	{ -- default
		{'z', Data.boolean}},
}

Test:Union{'NameOrAddress', Data.boolean,
	{ true, 
		{'name', Test.Name}},
	{ false, 
		{'address', Test.Address}},
}

Test:Struct('Company',
	{ 'entity', Test.NameOrAddress},
	{ 'hq', Data.string, Data.Seq(2) },
	{ 'offices', Test.Address, Data.Seq(10) },
	{ 'employees', Test.Name, Data.Seq() }
)

Test:Struct('BigCompany',
	{ 'parent', Test.Company},
	{ 'divisions', Test.Company, Data.Seq()}
)

--[[
  
Test:Struct{'FullName',
	Data.extends(Test.Name),  -- extends base type
	Data.has('middle',  Data.string),
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

function Test.print_index(instance)
	local instance = Data.index(instance)
	if instance == nil then return end
	
	print('\nindex:')
	for i, v in ipairs(instance) do
		print('   ', v)	
	end
end

function Test:print(instance)
	Data.print_idl(instance)
	self.print_index(instance)
end

function Test:test_struct_basic()
	self:print(Test.Name)
end

function Test:test_struct_composite()
	self:print(Test.Address)
end

function Test:test_union()
	self:print(Test.Chores)
	self:print(Test.TestUnion1)
	self:print(Test.TestUnion2)
	self:print(Test.NameOrAddress)
end

function Test:test_struct_complex()
	self:print(Test.Company)
	self:print(Test.BigCompany)
end

function Test:test_module()
	self:print(Test)
end

function Test:test_submodule()
	self:print(Test.Subtest)
end

function Test:test_root()
	self:print(Data)
end

function Test:test_enum()
	Data.print_idl(Test.Days)
	Data.print_idl(Test.Months)
	Data.print_idl(Test.Subtest.Colors)
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
