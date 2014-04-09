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
-- NOTES
--    Self-recursive definitions require a forward declaration, and generate a
--    warning. To create a forward declaration, install the same name twice,
--    first as an empty definition, and then as a full definition. Ignore the warning!
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
	TYPEDEF    = function() return 'typedef' end,
	
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
--    - are installed in a nested name space '_' to avoid conflicts
--      with user defined types, and also to stand out in the declarations
--    - are installed as closures so that user can pass in custom attributes
--    - attributes are not interpreted, and are preserved i.e. kept intact 
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
	-- NOTE: the attributes passed to the annotation are not interpreted,
	--       and are kept intact; we simply add the MODEL definition
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
		-- instance.__tostring = Data._.__tostring
		return instance		
	end
	
	-- put all the annotation definitions in a local namespace: _
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
	if 'table' == type(param[1]) 
		and nil ~= param[1][Data.MODEL]
		and Data.ANNOTATION ~= param[1][Data.MODEL][Data.TYPE] then
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
			  table.concat{'undefined type for struct member "', 
			  		tostring(role), '": ', tostring(element)})
			assert(nil ~= element[Data.MODEL], 
			  table.concat{'invalid type for struct member "', 
			  		tostring(role), '"'})
			  		
			local element_type = element[Data.MODEL][Data.TYPE]
			assert(Data.STRUCT == element_type or 
			   Data.UNION == element_type or
			   Data.ATOM == element_type or
			   Data.ENUM == element_type or
			   Data.TYPEDEF == element_type,
			   table.concat{'member must be a struct|union|atom|enum|typedef: ', 
			   				 tostring(name)})
			  		
			-- check for conflicting  member fields
			assert(nil == instance[role], 
				table.concat{'member name already defined: ', role})
					
		
			-- decide if the 3rd entry is a sequence length or not?
			local seq_capacity = 'number' == type(decl[3]) and decl[3] or nil
					
			local collection = nil
			
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
								 
				-- is this an array?
				if 'Array' == decl[j][Data.MODEL][Data.NAME] then
					collection = decl[j]
				end
			end
				
			-- populate the instance/role fields
			if collection then
				local template = element
				for i = 1, #collection - 1  do -- create iterator for inner dimensions
					template = Data.seq('', template) -- unnamed iterator
				end
				instance[role] = Data.seq(role, template)
			elseif seq_capacity then
				instance[role] = Data.seq(role, element)
			else
				instance[role] = Data.instance(role, element)
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
			  table.concat{'undefined type for union member "', 
			  		tostring(role), '": ', tostring(element)})
			assert(nil ~= element[Data.MODEL], 
			  table.concat{'invalid type for union member "', 
			  		tostring(role), '"'})
			 
			local element_type = element[Data.MODEL][Data.TYPE]
			assert(Data.STRUCT == element_type or 
			   Data.UNION == element_type or
			   Data.ATOM == element_type or
			   Data.ENUM == element_type or
			   Data.TYPEDEF == element_type,
			   table.concat{'member must be a struct|union|atom|enum|typedef: ', 
			   				 tostring(name)})
			
			-- decide if the 3rd entry is a sequence length or not?
			local seq_capacity = 'number' == type(decl[1][3]) and decl[1][3] or nil

			local collection = nil
				
			-- ensure that the rest of the declaration entries are annotations	
			-- start with the 3rd or the 4th entry depending upon whether it 
			-- was a sequence or not:
			for j = (seq_capacity and 4 or 3), #decl[1] do
								
				assert('table' == type(decl[1][j]),
					table.concat{'annotation expected: ', tostring(role), 
								 ' : ', tostring(decl[1][j])})
				assert(Data.ANNOTATION == decl[1][j][Data.MODEL][Data.TYPE],
					table.concat{'not an annotation: ', tostring(role), 
								 ' : ', tostring(decl[1][j])})		
			
				-- is this an array?
				if 'Array' == decl[1][j][Data.MODEL][Data.NAME] then
					collection = decl[1][j]
				end
			end
				
			-- populate the instance/role fields
			if collection then
				local template = element
				for i = 1, #collection - 1  do -- create iterator for inner dimensions
					template = Data.seq('', template) -- unnamed iterator
				end
				instance[role] = Data.seq(role, template)
			elseif seq_capacity then
				instance[role] = Data.seq(role, element)
			else
				instance[role] = Data.instance(role, element)
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

--[[
	IDL: typedef seq<MyStruct> MyStructSeq
	Lua: Data:Typedef{'MyStructSeq', Data.MyStruct, Data.Seq() }
--]]
function Data:Typedef(param) 
	assert('table' == type(param), 
		   table.concat{'invalid typedef specification: ', tostring(param)})

	-- ensure proper specification
	local name, base, seq_capacity = param[1], param[2], param[3]
	assert('string' == type(name), 
			table.concat{'invalid typedef name: ', tostring(name)})
	assert('table' == type(base), 
		table.concat{'undefined base type for typedef: "', tostring(name), '"'})
	assert(nil ~= base[Data.MODEL], 
		table.concat{'invalid base type for typedef "', tostring(name), '"'})
	assert(nil == seq_capacity or 'number' == type(seq_capacity),
		table.concat{'invalid sequence capacity for typedef "', tostring(name), '"'})

	local model = { -- meta-data defining the typedef
		[Data.NAME] = name,
		[Data.TYPE] = Data.TYPEDEF,
		[Data.DEFN] = { _alias = base, _alias_seq_capacity = seq_capacity }, 
		[Data.INSTANCE] = nil,-- always nil
	}
	local instance = { -- top-level instance to be installed in the module
		[Data.MODEL] = model,
	}
	
	-- like and atomic type, typedefs don't have instance members
	-- these will be defined by the underlying aliased type
					
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

-- An array is implemented as a special annotation, whose attributes are 
-- positive integer constants, which specify the array dimensions
-- NOTE: Since an array is an annotation, it can appear anywhere after
--       a member type declaration
Data:Annotation('Array')
function Data.Array(n, ...)

	-- ensure that we have an array of positive numbers
	local dimensions = {...}
	table.insert(dimensions, 1, n) -- insert n at the begining
	for i, v in ipairs(dimensions) do
		assert(type(v)=='number',  
			table.concat{'invalid array bound: ', tostring(v)})
		assert(v >= 0,  
			table.concat{'array bound must be > 0: ', v})
	end
	
	-- return the predefined Array annotation instance, wose attributes are 
	-- the array dimensions
	return Data._.Array(dimensions)
end

-- String of length n (i.e. string<n>) is an Atom
function Data.String(n)
	local name = 'string'
		
	-- construct name of the atom: 'string<n>'
	if nil ~= n then
		assert(type(n)=='number', 
	           table.concat{'invalid string capacity: ', tostring(n)})
		assert(n > 0, 
		       table.concat{'string capacity must be > 0: ', tostring(n)})
	    name = table.concat{'string<', n, '>'}
	end
	            	
	-- lookup the atom name
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
-- 	  <<in>> name  - the role|instance name
-- 	  <<in>> template - the template to use for creating an instance
--    <<returns>> the newly created instance (seq) that supports 
--                indexing by 'name'
-- Usage:
--    -- As an index into sample[]
--    local myInstance = Data.instance("my", template)
--    local member = sample[myInstance.member] 
--    for i = 1, sample[myInstance.memberSeq()] do -- length of the sequence
--       local element_i = sample[memberSeq(i)] -- access the i-th element
--    end  
--
--    -- As a sample itself
--    local myInstance = Data.instance("my", template)
--    myInstance.member = "value"
--
--    -- NOTE: Assignment not yet supported for sequences:
--    myInstance.memberSeq() = 10 -- length
--    for i = 1, myInstance.memberSeq() do -- length of the sequence
--       memberSeq(i) = "element_i"
--    end  
--
function Data.instance(name, template) 
	-- print('DEBUG Data.instance 1: ', name, template[Data.MODEL][Data.NAME])
	assert(type(name) == 'string', 
		   table.concat{'invalid instance name: ', tostring(name)})
	
	-- ensure valid template
	assert('table' == type(template), 'template missing!')
	assert(template[Data.MODEL],
		   table.concat{'invalid instance template: ', tostring(name)})
	local template_type = template[Data.MODEL][Data.TYPE]
	assert(Data.STRUCT == template_type or 
		   Data.UNION == template_type or
		   Data.ATOM == template_type or
		   Data.ENUM == template_type or
		   Data.TYPEDEF == template_type,
		   table.concat{'template must be a struct|union|atom|enum|typedef: ', 
		   				 tostring(name)})
	local instance = nil

	---------------------------------------------------------------------------
	-- typedef? => get the underlying template:
	---------------------------------------------------------------------------

	local alias_type = template[Data.MODEL][Data.DEFN] and 
			     template[Data.MODEL][Data.DEFN]._alias and 
				 template[Data.MODEL][Data.DEFN]._alias[Data.MODEL][Data.TYPE]
	local alias_sequence = template[Data.MODEL][Data.DEFN] and 
	                  template[Data.MODEL][Data.DEFN]._alias_seq_capacity

	if alias_type then 
		template = template[Data.MODEL][Data.DEFN]._alias
	end

	---------------------------------------------------------------------------
	-- recursive typedefs, i.e. aliases
	---------------------------------------------------------------------------

	-- recursive typedefs:
	-- NOTE: other cases (below) terminate the recursion
	if Data.TYPEDEF == template_type and
	   Data.TYPEDEF == alias_type then -- recursive
		--[[
		print('DEBUG Data.instance 2: ', name, 
			template[Data.MODEL][Data.DEFN]._alias[Data.MODEL][Data.NAME], 
			alias_sequence)
		--]]	
		if alias_sequence then
			instance = Data.seq(name, template)
		else
			instance = Data.instance(name, template)
		end

		return instance
	end

	---------------------------------------------------------------------------
	-- not a recursive typedef
	---------------------------------------------------------------------------
	
	-- sequence of underlying type (which is not a typedef)
	if alias_sequence then -- the sequence of alias elements
		instance = Data.seq(name, template) 
		return instance
	end

	---------------------------------------------------------------------------
	-- leaf instances
	---------------------------------------------------------------------------

	if Data.ATOM == template_type or Data.ENUM == template_type or 
	   Data.ATOM == alias_type or Data.ENUM == alias_type then
		instance = name 
		return instance
	end
	
	---------------------------------------------------------------------------
	-- composite instances 
	---------------------------------------------------------------------------
	-- Data.STRUCT or Data.UNION
	
	-- Establish the underlying model definition to create an instance
	-- NOTE: typedef's do not hold any instances; the instances are held by the
	--       underlying concrete (non-typdef) alias type
	local model = template[Data.MODEL]

	-- try to retrieve the instance from the underlying model
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
						function(j, prefix_j) -- allow further prefixing
							return v(j, table.concat{prefix_j or '', name, '.'}) 
						end
				elseif 'table' == type_v then -- struct or union
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

-- Name: 
--    Data.seq() - creates a sequence, of elements specified by the template
-- Purpose:
--    Define a sequence iterator (closure) for indexing
-- Parameters:
-- 	  <<in>> name  - the role or instance name
-- 	  <<in>> template - the template to use for creating an instance
--                          may be a table when it is an non-collection type OR
--                          may be a closure for collections (sequences/arrays)
--    <<returns>> the newly created closure for indexing a sequence of 
--          of template elements
-- Usage:
--    local mySeq = Data.seq("my", template)
--    for i = 1, sample[mySeq()] do -- length of the sequence
--       local element_i = sample[mySeq(i)] -- access the i-th element
--    end    
function Data.seq(name, template) 

	-- print('DEBUG Data.seq', name, template)

	assert(type(name) == 'string', 
		   table.concat{'sequence name must be a string: ', tostring(name)})
	
	-- ensure valid template
	local type_template = type(template)
	assert('table' == type_template and template[Data.MODEL] or 
	       'function' == type_template, -- collection iterator
		   	  table.concat{'sequence template invalid; ',
		   	  			   'must be an instance for a sequence: ',
		   	 			   tostring(name)})
	if 'table' == type_template then
		local element_type = template[Data.MODEL][Data.TYPE]
		assert(Data.STRUCT == element_type or 
			   Data.UNION == element_type or
			   Data.ENUM == element_type or
			   Data.ATOM == element_type or
			   Data.TYPEDEF == element_type,
			   table.concat{'sequence template must be a ', 
			   				'struct|union|atom|enum|typedef: ', 
			   				 tostring(name)})
	end

	---------------------------------------------------------------------------
	-- return a closure that will generate the correct index string for 'name'
	---------------------------------------------------------------------------
	-- closure behavior:
	--    if no argument is provided then generate the length operator string
	--    else generate the element i access string
	return function (i, prefix_i)
	
		local prefix_i = prefix_i or ''
		return i -- index 
				 and (('table' == type_template) -- composite
					  and 
					  	Data.instance(string.format('%s%s[%d]', prefix_i, name, i), 
					  				  template)
					  or (('function' == type_template -- collection
					       and 
					         function(j, prefix_j) -- allow further prefixing
							     return template(j, 
				  	               string.format('%s%s[%d]', prefix_i, name, i))
								 end
					       or -- primitive
				      	     string.format('%s%s[%d]', prefix_i, name, i))))
				 -- length
			     or string.format('%s%s#', prefix_i, name)
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
		output = string.format('%s%s%s', 
							output or '', -- output or nothing
							output and ',' or '', -- put a comma or not?
							tostring(v))
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

Data:Atom{'float'}
Data:Atom{'double'}

Data:Atom{'long'}
Data:Atom{'unsigned_long'}
Data:Atom{'long_long'}

Data:Atom{'short'}
Data:Atom{'unsigned_short'}

Data:Atom{'char'}
Data:Atom{'octet'}
Data:Atom{'boolean'}

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
Data:Annotation('top_level') -- legacy

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
	   return instance, indent_string 
	end
	
	if Data.TYPEDEF == mytype then
		local base, seq_capacity = mydefn._alias, mydefn._alias_seq_capacity
		if seq_capacity then
			print(string.format('%s%s seq<%s%s> %s;\n', indent_string, mytype(), 
							    base[Data.MODEL][Data.NAME], 
							    seq_capacity == -1 and '' or ',' .. seq_capacity,
							    myname))
		else
			print(string.format('%s%s %s %s;\n', indent_string, mytype(), 
							    base[Data.MODEL][Data.NAME], 
							    myname))
		end
		return instance, indent_string 
	end
	
	-- open --
	if (nil ~= myname) then -- not top-level
	
		-- print the annotations
		for i, decl in ipairs(mydefn) do
			if decl[Data.MODEL] and Data.ANNOTATION == decl[Data.MODEL][Data.TYPE] then
				print(string.format('%s%s', indent_string, tostring(decl)))
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
		print(string.format('%s};\n', indent_string))
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
--              needed to support inheritance and typedefs
-- @result the cumulative index, that can be passed to another call to this method
function Data.index(instance, result, model) 
	-- ensure valid instance
	local type_instance = type(instance)
	-- print('DEBUG Data.index 1: ', instance) 
	assert('table' == type_instance and instance[Data.MODEL] or 
	       'function' == type_instance, -- sequence iterator
		   table.concat{'invalid instance: ', tostring(instance)})
	
	-- sequence iterator
	if 'function' == type_instance then
		table.insert(result, instance())
		
		-- index 1st element for illustration
		if 'table' == type(instance(1)) then -- composite sequence
			Data.index(instance(1), result) -- index the 1st element 
		elseif 'function' == type(instance(1)) then -- sequence of sequence
			Data.index(instance(1), result)
		else -- primitive sequence
			table.insert(result, instance(1))
		end
		return result
	end
	
	-- struct or union
	local mytype = instance[Data.MODEL][Data.TYPE]
	local model = model or instance[Data.MODEL]
	local mydefn = model[Data.DEFN]

	-- print('DEBUG index 1: ', mytype(), instance[Data.MODEL][Data.NAME])
			
	-- skip if not an indexable type:
	if Data.STRUCT ~= mytype and Data.UNION ~= mytype then return nil end

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
	-- NOTE: typedefs don't have an array of members	
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
			local instance_member_type = type(instance_member)
			-- print('DEBUG index 3: ', role, seq_capacity, instance_member)

			if 'table' == instance_member_type then -- composite (nested)
					result = Data.index(instance_member, result)
			elseif 'function' == instance_member_type then -- sequence
				-- length operator
				table.insert(result, instance_member())
	
				-- index 1st element for illustration
				if 'table' == type(instance_member(1)) then -- composite sequence
					Data.index(instance_member(1), result) -- index the 1st element 
				elseif 'function' == type(instance_member(1)) then -- sequence of sequence
					Data.index(instance_member(1), result)
				else -- primitive sequence
					table.insert(result, instance_member(1))
				end
			else -- atom or enum (leaf)
				table.insert(result, instance_member) 
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
--[[
local testModule = Data:create_module();
local testEnum   = testModule:create_enum();
Test:add()
--]]
 
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
	Data._.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
	{ 'name', Test.Name },
	{ 'street', Data.String() },
	{ 'city',  Data.String(), Data._.MyAnnotation{value1 = 10, value2 = 17} },
	-- Data._.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
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
	{ 'middle',  Data.String() },
	Data._.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
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

-- typedefs

Test:Typedef{'MyDouble', Data.double}
Test:Typedef{'MyDouble2', Test.MyDouble}
Test:Typedef{'MyString', Data.String(10)}

Test:Typedef{'MyName', Test.Name }
Test:Typedef{'MyName2', Test.MyName }

Test:Typedef{'MyAddress', Test.Address }
Test:Typedef{'MyAddress2', Test.MyAddress }

Test:Struct{'MyTypedef',
	{ 'rawDouble', Data.double },
	{ 'myDouble', Test.MyDouble },
	{ 'myDouble2', Test.MyDouble2 },
	
	{ 'name',  Test.Name },
	{ 'myName',  Test.MyName },
	{ 'myName2',  Test.MyName2 },
	
	{ 'address', Test.Address },
	{ 'myAddress', Test.MyAddress },
	{ 'myAddress2', Test.MyAddress2 },
}


function Test:test_typedef()	
	self:print(self.MyDouble)
	self:print(self.MyDouble2)	
	self:print(self.MyString)
				
	self:print(self.MyName)
	self:print(self.MyName2)
	
	self:print(self.MyAddress)
	self:print(self.MyAddress2)
	
	self:print(self.MyTypedef)
end


Test:Typedef{'MyDoubleSeq', Test.MyDouble, Data.Seq() }
Test:Typedef{'MyStringSeq', Test.MyString, Data.Seq(10) }

Test:Typedef{'NameSeq', Test.Name, Data.Seq(10) }
Test:Typedef{'NameSeqSeq', Test.NameSeq, Data.Seq(10) }

Test:Typedef{'MyNameSeq', Test.MyName, Data.Seq(10) }
Test:Typedef{'MyNameSeqSeq', Test.MyNameSeq, Data.Seq(10) }

Test:Struct{'MyTypedefSeq',
    { 'myDoubleSeq', Test.MyDouble, Data.Seq() },
	{ 'myDoubleSeqA', Test.MyDoubleSeq },
	{ 'myStringSeqA', Test.MyStringSeq },
	
	{ 'nameSeq', Test.Name, Data.Seq() },
	{ 'nameSeqA', Test.NameSeq },
	{ 'nameSeqSeq', Test.NameSeq, Data.Seq() },
	{ 'nameSeqSeqA', Test.NameSeqSeq },
	{ 'nameSeqSeqASeq', Test.NameSeqSeq, Data.Seq() },

	{ 'myNameSeq', Test.MyName, Data.Seq() },
	{ 'myNameSeqA', Test.MyNameSeq },
	{ 'myNameSeqSeq', Test.MyNameSeq, Data.Seq() },
	{ 'myNameSeqSeqA', Test.MyNameSeqSeq },
	{ 'myNameSeqSeqASeq', Test.MyNameSeqSeq, Data.Seq() },
}

function Test:test_typedef_seq()	
	self:print(self.MyDoubleSeq)
	self:print(self.MyStringSeq)
	
	self:print(self.NameSeq)
	self:print(self.NameSeqSeq)

	self:print(self.MyNameSeq)
	self:print(self.MyNameSeqSeq)
	
	self:print(self.MyTypedefSeq)
	
	-- nameSeq
	assert(Test.MyTypedefSeq.nameSeq() == 'nameSeq#')
	assert(Test.MyTypedefSeq.nameSeq(1).first == 'nameSeq[1].first')	
	assert(Test.MyTypedefSeq.nameSeq(1).nicknames() == 'nameSeq[1].nicknames#')	
	assert(Test.MyTypedefSeq.nameSeq(1).nicknames(1) == 'nameSeq[1].nicknames[1]')	

	-- nameSeqA
	assert(Test.MyTypedefSeq.nameSeqA() == 'nameSeqA#')
	assert(Test.MyTypedefSeq.nameSeqA(1).first == 'nameSeqA[1].first')	
	assert(Test.MyTypedefSeq.nameSeqA(1).nicknames() == 'nameSeqA[1].nicknames#')	
	assert(Test.MyTypedefSeq.nameSeqA(1).nicknames(1) == 'nameSeqA[1].nicknames[1]')	

	-- nameSeqSeq
	assert(Test.MyTypedefSeq.nameSeqSeq() == 'nameSeqSeq#')	
	assert(Test.MyTypedefSeq.nameSeqSeq(1)() == 'nameSeqSeq[1]#')
	assert(Test.MyTypedefSeq.nameSeqSeq(1)(1).first == 'nameSeqSeq[1][1].first')
	assert(Test.MyTypedefSeq.nameSeqSeq(1)(1).nicknames() == 'nameSeqSeq[1][1].nicknames#')
	assert(Test.MyTypedefSeq.nameSeqSeq(1)(1).nicknames(1) == 'nameSeqSeq[1][1].nicknames[1]')
	
	-- nameSeqSeqA
	assert(Test.MyTypedefSeq.nameSeqSeqA() == 'nameSeqSeqA#')	
	assert(Test.MyTypedefSeq.nameSeqSeqA(1)() == 'nameSeqSeqA[1]#')
	assert(Test.MyTypedefSeq.nameSeqSeqA(1)(1).first == 'nameSeqSeqA[1][1].first')
	assert(Test.MyTypedefSeq.nameSeqSeqA(1)(1).nicknames() == 'nameSeqSeqA[1][1].nicknames#')
	assert(Test.MyTypedefSeq.nameSeqSeqA(1)(1).nicknames(1) == 'nameSeqSeqA[1][1].nicknames[1]')

	-- nameSeqSeqASeq
	assert(Test.MyTypedefSeq.nameSeqSeqASeq() == 'nameSeqSeqASeq#')	
	assert(Test.MyTypedefSeq.nameSeqSeqASeq(1)() == 'nameSeqSeqASeq[1]#')
	assert(Test.MyTypedefSeq.nameSeqSeqASeq(1)(1)() == 'nameSeqSeqASeq[1][1]#')
	assert(Test.MyTypedefSeq.nameSeqSeqASeq(1)(1)(1).first == 'nameSeqSeqASeq[1][1][1].first')
	assert(Test.MyTypedefSeq.nameSeqSeqASeq(1)(1)(1).nicknames() == 'nameSeqSeqASeq[1][1][1].nicknames#')
	assert(Test.MyTypedefSeq.nameSeqSeqASeq(1)(1)(1).nicknames(1) == 'nameSeqSeqASeq[1][1][1].nicknames[1]')

	-- myNameSeq
	assert(Test.MyTypedefSeq.myNameSeq() == 'myNameSeq#')
	assert(Test.MyTypedefSeq.myNameSeq(1).first == 'myNameSeq[1].first')	
	assert(Test.MyTypedefSeq.myNameSeq(1).nicknames() == 'myNameSeq[1].nicknames#')	
	assert(Test.MyTypedefSeq.myNameSeq(1).nicknames(1) == 'myNameSeq[1].nicknames[1]')	

	-- myNameSeqA
	assert(Test.MyTypedefSeq.myNameSeqA() == 'myNameSeqA#')
	assert(Test.MyTypedefSeq.myNameSeqA(1).first == 'myNameSeqA[1].first')	
	assert(Test.MyTypedefSeq.myNameSeqA(1).nicknames() == 'myNameSeqA[1].nicknames#')	
	assert(Test.MyTypedefSeq.myNameSeqA(1).nicknames(1) == 'myNameSeqA[1].nicknames[1]')	

	-- myNameSeqSeq
	assert(Test.MyTypedefSeq.myNameSeqSeq() == 'myNameSeqSeq#')	
	assert(Test.MyTypedefSeq.myNameSeqSeq(1)() == 'myNameSeqSeq[1]#')
	assert(Test.MyTypedefSeq.myNameSeqSeq(1)(1).first == 'myNameSeqSeq[1][1].first')
	assert(Test.MyTypedefSeq.myNameSeqSeq(1)(1).nicknames() == 'myNameSeqSeq[1][1].nicknames#')
	assert(Test.MyTypedefSeq.myNameSeqSeq(1)(1).nicknames(1) == 'myNameSeqSeq[1][1].nicknames[1]')
	
	-- myNameSeqSeqA
	assert(Test.MyTypedefSeq.myNameSeqSeqA() == 'myNameSeqSeqA#')	
	assert(Test.MyTypedefSeq.myNameSeqSeqA(1)() == 'myNameSeqSeqA[1]#')
	assert(Test.MyTypedefSeq.myNameSeqSeqA(1)(1).first == 'myNameSeqSeqA[1][1].first')
	assert(Test.MyTypedefSeq.myNameSeqSeqA(1)(1).nicknames() == 'myNameSeqSeqA[1][1].nicknames#')
	assert(Test.MyTypedefSeq.myNameSeqSeqA(1)(1).nicknames(1) == 'myNameSeqSeqA[1][1].nicknames[1]')

	-- myNameSeqSeqASeq
	assert(Test.MyTypedefSeq.myNameSeqSeqASeq() == 'myNameSeqSeqASeq#')	
	assert(Test.MyTypedefSeq.myNameSeqSeqASeq(1)() == 'myNameSeqSeqASeq[1]#')
	assert(Test.MyTypedefSeq.myNameSeqSeqASeq(1)(1)() == 'myNameSeqSeqASeq[1][1]#')
	assert(Test.MyTypedefSeq.myNameSeqSeqASeq(1)(1)(1).first == 'myNameSeqSeqASeq[1][1][1].first')
	assert(Test.MyTypedefSeq.myNameSeqSeqASeq(1)(1)(1).nicknames() == 'myNameSeqSeqASeq[1][1][1].nicknames#')
	assert(Test.MyTypedefSeq.myNameSeqSeqASeq(1)(1)(1).nicknames(1) == 'myNameSeqSeqASeq[1][1][1].nicknames[1]')
end

-- Arrays
Test:Struct{'MyArrays1',
	-- 1-D
	{ 'ints', Data.double, Data.Array(3) },

	-- 2-D
	{ 'days', Test.Days, Data.Array(6, 9) },
	
	-- 3-D
	{ 'names', Test.Name, Data.Array(12, 15, 18) },
}

Test:Union{'MyArrays2', Test.Days,
	-- 1-D
	{ 'MON',
		{'ints', Data.double, Data.Array(3) }},

	-- 2-D
	{ 'TUE',
		{ 'days', Test.Days, Data.Array(6, 9) }},
	
	-- 3-D
	{--
		{ 'names', Test.Name, Data.Array(12, 15, 18) }},	
}

function Test:test_arrays()
	-- structure with arrays
	self:print(Test.MyArrays1)
	
	assert(Test.MyArrays1.ints() == 'ints#')
	assert(Test.MyArrays1.ints(1) == 'ints[1]')
	
	assert(Test.MyArrays1.days() == 'days#')
	assert(Test.MyArrays1.days(1)() == 'days[1]#')
	assert(Test.MyArrays1.days(1)(1) == 'days[1][1]')
	
	assert(Test.MyArrays1.names() == 'names#')
	assert(Test.MyArrays1.names(1)() == 'names[1]#')
	assert(Test.MyArrays1.names(1)(1)() == 'names[1][1]#')
	assert(Test.MyArrays1.names(1)(1)(1).first == 'names[1][1][1].first')
	assert(Test.MyArrays1.names(1)(1)(1).nicknames() == 'names[1][1][1].nicknames#')
	assert(Test.MyArrays1.names(1)(1)(1).nicknames(1) == 'names[1][1][1].nicknames[1]')

	-- union with arrays
	self:print(Test.MyArrays2)
	
	assert(Test.MyArrays2.ints() == 'ints#')
	assert(Test.MyArrays2.ints(1) == 'ints[1]')
	
	assert(Test.MyArrays2.days() == 'days#')
	assert(Test.MyArrays2.days(1)() == 'days[1]#')
	assert(Test.MyArrays2.days(1)(1) == 'days[1][1]')
	
	assert(Test.MyArrays2.names() == 'names#')
	assert(Test.MyArrays2.names(1)() == 'names[1]#')
	assert(Test.MyArrays2.names(1)(1)() == 'names[1][1]#')
	assert(Test.MyArrays2.names(1)(1)(1).first == 'names[1][1][1].first')
	assert(Test.MyArrays2.names(1)(1)(1).nicknames() == 'names[1][1][1].nicknames#')
	assert(Test.MyArrays2.names(1)(1)(1).nicknames(1) == 'names[1][1][1].nicknames[1]')
end

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
