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
--     1. Provides a way of defining IDL equivalent data types (aka models). Does
--        error checking to ensure well-formed type definitions.  
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
--    11. Extensible: new annotations and atomic types can be easily added
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
--          Data.has(user_role1, Data.String()),
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
--              user_role1    = Data.String(),
--              user_role2    = UserModule.UserType2,
--				user_role3    = UserModule.UserType3,
--				user_role_seq = UserModule.UserTypeSeq,
--          }             
--          [Data.INSTANCE] = {}       -- table of instances of this model 
--                 
--          -- instance fields --
--          user_role1 = 'user_role1'  -- name used to index this 'leaf' field
--          user_role2 = Data.instance('user_role2', UserModule.UserType2)
--          user_role3 = Data.instance('user_role3', UserModule.UserType3)
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
--          i1 = Data.instance('i1', Model)
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
--              model.role = Data.instance('role', RoleModel)
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
	MODEL      = function() return 'MODEL' end,-- table key for 'model' meta-data	
	

	-- model meta-data attributes ---
	-- every 'model' meta-data table has these keys defined 
	NAME      = function() return 'NAME' end,  -- table key for 'model name'	
	TYPE      = function() return 'TYPE' end,  -- table key for the 'model type name' 
	DEFN      = function() return 'DEFN' end,  -- table key for element meta-data
	INSTANCE  = function() return 'INSTANCE' end,-- table key for instances of this model
	
		
	-- meta-data types - i.e. list of possible user defined types ---
	-- possible 'model[Data.TYPE]' values implemented as closures
	MODULE     = function() return 'module' end,
	STRUCT     = function() return 'struct' end,
	UNION      = function() return 'union' end,
	ENUM       = function() return 'enum' end,
	ATOM       = function() return 'atom' end,
	ANNOTATION = function() return 'annotation' end,
	
	-- name-space and meta-table for annotations (to avoid name collisions)
	-- NOTE: ALl of the above could go inside this table
	_		   = {}  
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
	local name = name[1] or name -- accept a table containing a string or a string
	
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
	local name = name[1] or name -- accept a table containing a string or a string

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

-- Annotations are modeled like Atomic types, expect that 
--    - the are installed in a nested name space '_' to avoid conflicts
--      with user defined types, and also to stand out in the declarations
--    - are installed as closures so that user can pass in custom attributes
--
-- Examples:
--        IDL:      @Key
--        Lua:      Data._.Key
--
--        IDL:  	@MyAnnotation(value1 = 42, value2 = 42.0)
--        Lua:      Data._.MyAnnotation{value1 = 42, value2 = 42.0}
function Data:Annotation(name, ...) 	
	assert(type(name) == 'string', 
		   table.concat{'invalid annotation name: ', tostring(name)})
	local model = {
		[Data.NAME] = name, 
		[Data.TYPE] = Data.ANNOTATION,
		[Data.DEFN] = nil,      -- always nil
		[Data.INSTANCE] = nil,  -- always nil
	}  

	-- top-level instance function (closure) to be installed in the module
	--   A function that returns a model table, with user defined 
	--   annotation attributes passed as a table of {name = value} pairs
	--      eg: Data._.MyAnnotation{value1 = 42, value2 = 42.0}
	local instance_fn = function (attributes) -- parameters to the annotation
		if attributes then
			assert('table' == type(attributes), 
		   		    table.concat{'table with {name=value} and/or assertions expected: ', 
		   		    tostring(attributes)})
		end
		local instance = attributes or {}
		instance[Data.MODEL] = model
		setmetatable(instance, Data._) -- for the __tostring() function
		return instance			
	end
	
	-- put all the annotatoon definitions in a local namespace: _
	-- so that the annotation names do not conflict with user defined types	
	local _ = self._ or {}       self._ = _
	
	-- add/replace the definition in the container module
	if _[name] then print('WARNING: replacing ', name) end
	_[name] = instance_fn
	table.insert(self[Data.MODEL][Data.DEFN], instance_fn(...)) -- default attributes
	
	return instance_fn
end

function Data:Struct(param) 
	assert('table' == type(param), 
		   table.concat{'invalid struct specification: ', tostring(param)})

	-- pop the name
	local name = param[1]   table.remove(param, 1)
	assert('string' == type(name), 
		   table.concat{'invalid struct name: ', tostring(name)})
		   
	-- OPTIONAL base: pop the next element if it is a base model element
	local base
	if 'table' == type(param[1]) and nil ~= param[1][Data.MODEL] then
		base = param[1]   table.remove(param, 1)
		assert(Data.STRUCT == base[Data.MODEL][Data.TYPE], 
			table.concat{'base type must be a struct: ', name})
	end

	local model = { -- meta-data defining the struct
		[Data.NAME] = name,
		[Data.TYPE] = Data.STRUCT,
		[Data.DEFN] = {},     -- will be populated as model elements are defined 
		[Data.INSTANCE] = nil,-- will be populated as instances are defined
	}
	local instance = { -- top-level instance to be installed in the module
		[Data.MODEL] = model,
	}
	
	-- add the base
	if base then
		-- install base class:
		model[Data.DEFN]._base = base
		
		-- populate the instance fields from the base type
		for k, v in pairs(base) do
			if 'string' == type(k) then -- copy only the base type instance fields 
				instance[k] = v
			end
		end
	end
	
	-- populate the model table
	for i, decl in ipairs(param) do	
	
		if decl[Data.MODEL] then -- annotation at the Struct level
			assert(Data.ANNOTATION == decl[Data.MODEL][Data.TYPE],
					table.concat{'not an annotation: ', tostring(decl)})		
		else -- struct member definition
			local role, element = decl[1], decl[2]	
	
			assert('string' == type(role), 
			  table.concat{'invalid struct member name: ', tostring(role)})
			assert('table' == type(element), 
			  table.concat{'undefined type for struct member "', tostring(role), '"'})
			assert(nil ~= element[Data.MODEL], 
			  table.concat{'invalid type for struct member "', tostring(role), '"'})
		
			local element_type = element[Data.MODEL][Data.TYPE]
			
			-- check for conflicting  member fields
			assert(nil == instance[role], 
				table.concat{'member name already defined: ', role})
					
		
			-- decide if the 3rd entry is a sequence length or not?
			local seq_capacity = 'number' == type(decl[3]) and decl[3] or nil
					
			-- ensure that the rest of the declaration entries are annotations:	
			-- start with the 3rd or the 4th entry depending upon whether it 
			-- was a sequence or not:
			for j = (seq_capacity and 4 or 3), #decl do
				assert('table' == type(decl[j]),
					table.concat{'annotation expected: ', tostring(role), 
								 ' : ', tostring(decl[j])})
				assert(Data.ANNOTATION == decl[j][Data.MODEL][Data.TYPE],
					table.concat{'not an annotation: ', tostring(role), 
								 ' : ', tostring(decl[j])})		
			end
					
			-- populate the instance/role fields
			if seq_capacity then -- sequence
				instance[role] = Data.seq(role, element)
			elseif Data.STRUCT == element_type or Data.UNION == element_type then
				instance[role] = Data.instance(role, element)
			else -- enum or primitive 
				instance[role] = role -- leaf is the role name
			end
		end
		
		-- save the meta-data
		-- as an array to get the correct ordering
		table.insert(model[Data.DEFN], decl) 
	end
	
	-- add/replace the definition in the container module
	if self[name] then print('WARNING: replacing ', name) end
	self[name] = instance
	table.insert(self[Data.MODEL][Data.DEFN], instance)
		
	return instance
end

function Data:Union(param) 
	assert('table' == type(param), 
		   table.concat{'invalid union specification: ', tostring(param)})

	-- pop the name
	local name = param[1]   table.remove(param, 1)
	assert('string' == type(name), 
		   table.concat{'invalid union name: ', tostring(name)})
		   
	-- pop the discriminator
	local discriminator = param[1]   table.remove(param, 1)
	assert('table' == type(discriminator), 
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
	for i, decl in ipairs(param) do	

		if decl[Data.MODEL] then -- annotation at the Union level
			assert(Data.ANNOTATION == decl[Data.MODEL][Data.TYPE],
					table.concat{'not an annotation: ', tostring(decl)})
			-- save the meta-data
			table.insert(model[Data.DEFN], decl) 	
				
		else -- union member definition
			local case = nil
			if #decl > 1 then case = decl[1]  table.remove(decl, 1) end -- case
			
			local role, element = decl[1][1], decl[1][2]
			-- print('DEBUG Union 2: ', case, role, element)
					
			Data.assert_case(case, discriminator)
			assert('string' == type(role), 
			  table.concat{'invalid union member name: ', tostring(role)})
			assert('table' == type(element), 
			  table.concat{'undefined type for union member "', tostring(role), '"'})
			assert(nil ~= element[Data.MODEL], 
			  table.concat{'invalid type for union member "', tostring(role), '"'})
		
			local element_type = element[Data.MODEL][Data.TYPE]
			
		
			-- decide if the 3rd entry is a sequence length or not?
			local seq_capacity = 'number' == type(decl[1][3]) and decl[1][3] or nil
					
			-- ensure that the rest of the declaration entries are annotations	
			-- start with the 3rd or the 4th entry depending upon whether it 
			-- was a sequence or not:
			for j = (seq_capacity and 4 or 3), #decl do
				assert('table' == type(decl[1][j]),
					table.concat{'annotation expected: ', tostring(role), 
								 ' : ', tostring(decl[1][j])})
				assert(Data.ANNOTATION == decl[1][j][Data.MODEL][Data.TYPE],
					table.concat{'not an annotation: ', tostring(role), 
								 ' : ', tostring(decl[1][j])})		
			end
			
			
			-- populate the instance/role fields
			if seq_capacity then -- sequence
				instance[role] = Data.seq(role, element)
			elseif Data.STRUCT == element_type or Data.UNION == element_type then 
				instance[role] = Data.instance(role, element)
			else -- enum or atom 
				instance[role] = role -- leaf is the role name
			end

			-- save the meta-data
			-- as an array to get the correct ordering
			-- NOTE: default case is stored as a 'nil'
			table.insert(model[Data.DEFN], { case, decl[1] }) 
		end
	end
	
	-- add/replace the definition in the container module
	if self[name] then print('WARNING: replacing ', name) end
	self[name] = instance
	table.insert(self[Data.MODEL][Data.DEFN], instance)
		
	return instance
end

function Data:Enum(param) 
	assert('table' == type(param), 
		   table.concat{'invalid enum specification: ', tostring(param)})

	-- pop the name
	local name = param[1]   table.remove(param, 1)
	assert('string' == type(name), 
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
	for i, decl in ipairs(param) do	
		local role, ordinal = decl[1], decl[2]	
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
	                           table.concat{'invalid sequence capacity: ', 
	                                        tostring(n)}) 
	                    and (assert(n > 0, 
		                         table.concat{'sequence capacity must be > 0: ', 
		                         tostring(n)})
		                     and n))
end


-- String of length n (i.e. string<n>) is an Atom
function Data.String(n)
	local name = 'string'
		
	if nil ~= n then
		assert(type(n)=='number', 
	           table.concat{'invalid string capacity: ', tostring(n)})
		assert(n > 0, 
		       table.concat{'string capacity must be > 0: ', tostring(n)})
	    name = table.concat{'string<', n, '>'}
	end
	            	
	-- lookup the name
	local instance = Data[name]
	if nil == instance then
		-- not found => create it
		instance = Data:Atom{name}
	end	 
	
	return instance
end 

--------------------------------------------------------------------------------
-- Model Instances  ---
--------------------------------------------------------------------------------

-- Data.instance() - creates an instance, using another instance as a template
-- Purpose:
--    Define a table that can be used to index into an instance of a model
-- Parameters:
-- 	  <<in>> role  - the role|instance name
-- 	  <<in>> model - the model element (table) to be instantiated
--    <<returns>> the newly created instance that supports indexing by 'role'
-- Usage:
function Data.instance(name, template) 
	-- print('DEBUG Data.instance: ', name, template[Data.MODEL][Data.NAME])
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
	local model = template[Data.MODEL]
	model[Data.INSTANCE] = model[Data.INSTANCE] or {}
	local instance = model[Data.INSTANCE][name]
	
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
					instance[k] = Data.instance(name, v) -- use member as template
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
		model[Data.INSTANCE][name] = instance
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
					  	Data.instance(string.format('%s%s[%d]', prefix, name, i), 
					  				 template)
					  or -- primitive
				      	string.format('%s%s[%d]', prefix, name, i))
				 -- length
			     or string.format('%s%s#', prefix, name)
	end
end

-- Ensure that case is a valid discriminator value
function Data.assert_case(case, discriminator)
	if nil == case then return case end -- default case 

	local err_msg = table.concat{'invalid case value: ', tostring(case)}
	
	if Data.long == discriminator or -- integral type
	   Data.short == discriminator or 
	   Data.octet == discriminator then
		assert(tonumber(case) and math.floor(case) == case, err_msg)	   
	 elseif Data.char == discriminator then -- character
	 	assert('string' == type(case) and 1 == string.len(case), err_msg)	
	 elseif Data.boolean == discriminator then -- boolean
		assert(true == case or false == case, err_msg)
	 elseif Data.ENUM == discriminator[Data.MODEL][Data.TYPE] then -- enum
	 	assert(discriminator[case], err_msg)
	 else -- invalid 
	 	assert(false, err_msg)
	 end
	
	 return case
end

-- Print an annotation
function Data._.__tostring(annotation)
	-- output the attributes if any
	local output = nil

	-- assertions
	for i, v in ipairs(annotation) do
		if 'string' == type(v) then
			output = string.format('%s%s%s', 
			output or '', -- output or nothing
			output and ',' or '', -- put a comma or not?
			tostring(v))
		end
	end
	
	-- name value pairs {name=value}
	for k, v in pairs(annotation) do
		if 'string' == type(k) then
			output = string.format('%s%s%s=%s', 
						output or '', -- output or nothing
						output and ',' or '', -- put a comma or not?
						tostring(k), tostring(v))
		end
	end
	
	if output then
		output = string.format('@%s(%s)', annotation[Data.MODEL][Data.NAME], output)	
	else
		output = string.format('@%s', annotation[Data.MODEL][Data.NAME])
	end
	
	return output
end

--------------------------------------------------------------------------------
-- Predefined Types
--------------------------------------------------------------------------------

Data:Atom{'double'}
Data:Atom{'long'}
Data:Atom{'short'}
Data:Atom{'boolean'}
Data:Atom{'char'}
Data:Atom{'octet'}


--------------------------------------------------------------------------------
-- Predefined Annotations
--------------------------------------------------------------------------------

Data:Annotation('Key')
Data:Annotation('Optional')
Data:Annotation('Extensibility')
Data:Annotation('ID')
Data:Annotation('MustUnderstand')
Data:Annotation('Shared')
Data:Annotation('BitBound')
Data:Annotation('BitSet')
Data:Annotation('Nested')

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
-- TODO: delete?
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
	
	-- skip: atomic types, annotations
	if Data.ATOM == mytype or
	   Data.ANNOTATION == mytype then 
	   return result, indent_string 
	end
	
	-- open --
	if (nil ~= myname) then -- not top-level
	
		-- print the annotations
		for i, decl in ipairs(mydefn) do
			if decl[Data.MODEL] and Data.ANNOTATION == decl[Data.MODEL][Data.TYPE] then
				print(tostring(decl))
			end
		end
	
		if Data.UNION == mytype then
			print(string.format('%s%s %s switch (%s) {', indent_string, 
						mytype(), myname, mydefn._d[Data.MODEL][Data.NAME]))
		elseif Data.STRUCT == mytype and model[Data.DEFN]._base then
			print(string.format('%s%s %s : %s {', indent_string, mytype(), 
					myname, model[Data.DEFN]._base[Data.MODEL][Data.NAME]))
		else
			print(string.format('%s%s %s {', indent_string, mytype(), myname))
		end
		content_indent_string = indent_string .. '   '
	end
		
	if Data.MODULE == mytype then 
		for i, member in ipairs(mydefn) do -- walk through the module definition
			Data.print_idl(member, content_indent_string)
		end
		
	elseif Data.STRUCT == mytype then
	 
		for i, decl in ipairs(mydefn) do -- walk through the model definition
			if not decl[Data.MODEL] then -- skip struct level annotations
				Data.print_idl_member(decl, content_indent_string)
			end
		end

	elseif Data.UNION == mytype then 
		for i, decl in ipairs(mydefn) do -- walk through the model definition
			if not decl[Data.MODEL] then -- skip union level annotations
				local case = decl[1]
				
				-- case
				local case_string = (nil == case) and 'default' or tostring(case)
				if (Data.char == mydefn._d and nil ~= case) then
					print(string.format("%scase '%s' :", 
						content_indent_string, case_string))
				else
					print(string.format("%scase %s :", 
						content_indent_string, case_string))
				end
				
				-- member element
				Data.print_idl_member(decl[2], content_indent_string .. '   ')
			end
		end
		
	elseif Data.ENUM == mytype then
		for i, decl in ipairs(mydefn) do -- walk through the model definition	
			local role, ordinal = decl[1], decl[2]
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


-- Helper method
-- Given a member declaration, print the equivalent IDL
-- decl is { role, element, [seq_capacity,] [annotation1, annotation2, ...] }
function Data.print_idl_member(decl, content_indent_string)
	
	local role, element = decl[1], decl[2]
	local seq_capacity = 'number' == type(decl[3]) and decl[3] or nil
	
	local output_member = ''		
	if seq_capacity == nil then -- not a sequence
		output_member = string.format('%s%s %s;', content_indent_string, 
		element[Data.MODEL][Data.NAME], role)
	elseif seq_capacity < 0 then -- unbounded sequence
		output_member = string.format('%sseq<%s> %s;', content_indent_string, 
		element[Data.MODEL][Data.NAME], role)
	else -- bounded sequence
		output_member = string.format('%sseq<%s,%d> %s;', content_indent_string, 
		element[Data.MODEL][Data.NAME], seq_capacity, role)
	end

	-- member annotations:	
	--   start with the 3rd or the 4th entry depending upon whether it 
	--   was a sequence or not:
	local output_annotations = nil
	for j = (seq_capacity and 4 or 3), #decl do
		output_annotations = string.format('%s%s ', 
		output_annotations or '', 
		tostring(decl[j]))	
	end

	if output_annotations then
		print(string.format('%s //%s', output_member, output_annotations))
	else
		print(output_member)
	end
end

				
-- @function Data.index Visit the fields in the instance that are specified 
--           in the model
-- @param instance the instance to index
-- @param result OPTIONAL the index table to which the results are appended
-- @param model OPTIONAL nil means use the instance's model;
--              needed to support inheritance
-- @result the cumulative index, that can be passed to another call to this method
function Data.index(instance, result, model) 
	-- ensure valid instance
	assert('table' == type(instance), 'instance missing!')
	assert(instance[Data.MODEL], 'invalid instance')
	local mytype = instance[Data.MODEL][Data.TYPE]
	local model = model or instance[Data.MODEL]
	local mydefn = model[Data.DEFN]
	
	-- skip if not an indexable type:
	if Data.STRUCT ~= mytype and Data.UNION ~= mytype then return result end
	
	-- print('DEBUG index: ', mytype(), instance[Data.MODEL][Data.NAME])
			
	-- preserve the order of model definition
	local result = result or {}	-- must be a top-level type	
	
	
	-- union discriminator, if any
	if Data.UNION == mytype then
		table.insert(result, instance._d) 
	end
	
	-- struct base type, if any
	local base = mydefn._base
	if nil ~= base then
		result = Data.index(instance, result, base[Data.MODEL])	
	end
	
	-- walk through the body of the model definition	
	for i, decl in ipairs(mydefn) do 
		local role, element, seq_capacity 
		
		-- skip annotations
		if not decl[Data.MODEL] then
			-- walk through the elements in the order of definition:
			if Data.STRUCT == mytype then
				 role, element = decl[1], decl[2]
				 seq_capacity = 'number' == type(decl[3]) and decl[3] or nil
			elseif Data.UNION == mytype then
				role, element = decl[2][1], decl[2][2]
				seq_capacity = 'number' == type(decl[2][3]) and decl[2][3] or nil
			end
			
			local instance_member = instance[role]
			if nil == seq_capacity then -- not a sequence
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
	end

	return result
end

--------------------------------------------------------------------------------
-- TESTS 
--------------------------------------------------------------------------------

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

Test.Name = Data.instance2{
	first = Data.STRING,
	last  = Data.STRING,
}

Test.Address = Data.instance2{
	name    = Data.instance('name', Test.Name),
	street  = Data.STRING,
	city    = Data.STRING,
}
--]]

--[[ ALTERNATE Syntax:
local MyTest = Data:Module('MyTest')

MyTest:Struct('Address') {
-- MyTest:Struct{Address = {
	{ name = Test.Name },
	{ street = Data.String() },
	{ city = Data.String() },
	{ coord = Data.Seq(Data.double, 2) },
}-- }

MyTest:Union('TestUnion1')(Test.Days) {
-- MyTest:Union{TestUnion1 = Data.switch(Test.Days) {

	{ 'MON', 
		{name = Test.Name},
	{ 'TUE', 
		{address = Test.Address}},
	{ -- default
		{x = Data.double}},		
}-- }

MyTest:Enum('Months') { 
-- MyTest:Enum{Months = { 
	{ JAN = 1 },
	{ FEB = 2 },
	{ MAR = 3 },
}--}
--]]

---[[ SKIP TESTS --

local Test = Data:Module{'Test'}

Test:Enum{'Days', 
	{'MON'}, {'TUE'}, {'WED'}, {'THU'}, {'FRI'}, {'SAT'}, {'SUN'}
}

Test:Enum{'Months', 
	{ 'JAN', 1 },
	{ 'FEB', 2 },
	{ 'MAR', 3 }
}

Test:Module('Subtest') -- alternate syntax

Test.Subtest:Enum{'Colors', 
	{ 'RED',   -5 },
	{ 'BLUE',  7 },
	{ 'GREEN', -9 },
	{ 'PINK' }
}

Test.Subtest:Struct{'Fruit', 
	{ 'weight', Data.double },
	{ 'color' , Test.Subtest.Colors}
}

Test:Struct{'Name',
	{ 'first', Data.String(10), Data._.Key{} },
	{ 'last',  Data.String() }, 
	{ 'nicknames',  Data.String(10), Data.Seq(3) },
	{ 'aliases',  Data.String(5), Data.Seq() },
	{ 'birthday', Test.Days, Data._.Optional{} },
	{ 'favorite', Test.Subtest.Colors, Data.Seq(2), Data._.Optional{} },
}

-- user defined annotation
Data:Annotation('MyAnnotation', {value1 = 42, value2 = 42.0})

Test:Struct{'Address',
	{ 'name', Test.Name },
	{ 'street', Data.String() },
	{ 'city',  Data.String(), Data._.MyAnnotation{value1 = 10, value2 = 17} },
	Data._.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
}

Test:Union{'TestUnion1', Test.Days,
	{ 'MON', 
		{'name', Test.Name}},
	{ 'TUE', 
		{'address', Test.Address}},
	{ -- default
		{'x', Data.double}},		
	Data._.Extensibility{'EXTENSIBLE_EXTENSIBILITY',domain=5},
}

Test:Union{'TestUnion2', Data.char,
	{ 'c', 
		{'name', Test.Name, Data._.Key{} }},
	{ 'a', 
		{'address', Test.Address}},
	{ -- default
		{'x', Data.double}},
}

Test:Union{'TestUnion3', Data.short,
	{ 1, 
		{'x', Data.String()}},
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

Test:Struct{'Company',
	{ 'entity', Test.NameOrAddress},
	{ 'hq', Data.String(), Data.Seq(2) },
	{ 'offices', Test.Address, Data.Seq(10) },
	{ 'employees', Test.Name, Data.Seq() }
}

Test:Struct{'BigCompany',
	{ 'parent', Test.Company},
	{ 'divisions', Test.Company, Data.Seq()}
}

Test:Struct{'FullName', Test.Name,
	{ 'middle',  Data.String() }
}

Test:Struct{'Contact', Test.FullName,
	{ 'address',  Test.Address },
	{ 'email',  Data.String() },
}

Test:Struct{'Tasks',
	{ 'contact',  Test.Contact },
	{ 'day',  Test.Days },
}

Test:Struct{'Calendar',
	{ 'tasks',  Test.Tasks, Data.Seq() },
}


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

function Test:test_struct_nested()
	self:print(Test.Address)
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

function Test:test_union()
	self:print(Test.TestUnion1)
	self:print(Test.TestUnion2)
	self:print(Test.TestUnion3)
	self:print(Test.NameOrAddress)
end

function Test:test_struct_complex()
	self:print(Test.Company)
	self:print(Test.BigCompany)
end

function Test:test_struct_inheritance()
	self:print(Test.FullName)
	self:print(Test.Contact)
	self:print(Test.Tasks)
	self:print(Test.Calendar)
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
