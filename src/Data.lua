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

-- Data - meta-data (meta-table) class implementing a semantic data definition 
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
--    Note that this class (table) is really just the meta-table for the user
--    defined model elements.
--
-- NOTES
--    Self-recursive definitions require a forward declaration, and generate a
--    warning. To create a forward declaration, install the same name twice,
--    first as an empty definition, and then as a full definition. Ignore the warning!
--
local Data = {
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
-- @param name =  the name of the annotation
-- @param ...  = optional attributes that are preserved by the annotation
-- @return the annotation closure and the underlying model definition
--          instance_fn = the instance function to instantiate this annotation
--          model = the data model describing this annotation
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
	
	return instance_fn, model
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

			-- save the meta-data
			table.insert(model[Data.DEFN], decl) 		
		else -- struct member definition
			local role, template = decl[1], decl[2]
			local member_instance, member_definition = Data.create_member(decl)
		
			-- check for conflicting  member fields
			assert(nil == instance[role], 
			  	   table.concat{'member name already defined: ', role})
	
			-- insert the role
			instance[role] = member_instance
			
			-- save the meta-data
			-- as an array to get the correct ordering
			table.insert(model[Data.DEFN], member_definition) 
		end
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
	local discriminator_type = discriminator[Data.MODEL][Data.TYPE]
	assert(Data.ATOM == discriminator_type or
		   Data.ENUM == discriminator_type,
		   table.concat{'discriminator must be an atom|enum: ', 
		   				 tostring(name)})
		   				 
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
			
			local member_instance, member_definition = Data.create_member(decl[1])

			-- insert the role
			instance[role] = member_instance
			
			-- save the meta-data
			-- as an array to get the correct ordering
			-- NOTE: default case is stored as a 'nil'
			table.insert(model[Data.DEFN], { case, member_definition }) 
		end
	end
	
	-- add/replace the definition in the container module
	if self[name] then print('WARNING: replacing ', name) end
	self[name] = instance
	table.insert(self[Data.MODEL][Data.DEFN], instance)
		
	return instance
end

--[[
	IDL: typedef sequence<MyStruct> MyStructSeq
	Lua: Data:Typedef{'MyStructSeq', Data.MyStruct, Data.Sequence() }
	
	IDL: typedef MyStruct MyStructArray[10][20]
	Lua: Data:Typedef{'MyStructArray', Data.MyStruct, Data.Array(10, 20) }
--]]
function Data:Typedef(param) 
	assert('table' == type(param), 
		   table.concat{'invalid typedef specification: ', tostring(param)})

	-- ensure proper specification
	local name = param[1]
	assert('string' == type(name), 
			table.concat{'invalid typedef name: ', tostring(name)})

	local alias = param[2]
	assert('table' == type(alias), 
		table.concat{'undefined alias type for typedef: "', tostring(name), '"'})
	assert(nil ~= alias[Data.MODEL], 
		table.concat{'alias must be a data model for typedef "', tostring(name), '"'})
	local alias_type = alias[Data.MODEL][Data.TYPE]
	assert(Data.ATOM == alias_type or
		   Data.ENUM == alias_type or
		   Data.STRUCT == alias_type or 
		   Data.UNION == alias_type or
		   Data.TYPEDEF == alias_type,
		   table.concat{'alias must be a atom|enum|struct|union|typedef: ', 
		   				 tostring(name)})
		   		
	local collection = param[3]	 
	assert(nil == collection or 'number' == type(collection) or
		   Data.ARRAY == collection[Data.MODEL] or
		   Data.SEQUENCE == collection[Data.MODEL],
		table.concat{'invalid collection for typedef "', tostring(name), '"'})


	local model = { -- meta-data defining the typedef
		[Data.NAME] = name,
		[Data.TYPE] = Data.TYPEDEF,
		[Data.DEFN] = {}, -- exactly 1 entry: '', underlying alias, array/sequence
		[Data.INSTANCE] = nil,
	}
	local instance = { -- top-level instance to be installed in the module
		[Data.MODEL] = model,
	}
	
	-- create definition
	local member_instance, member_definition = 
				Data.create_member{ nil, alias, collection }
	
	-- NOTE: we reused the create_member() function method, because it already
	--       does all the work  that we need to do. We ignore the 
	--       'member_instance' because the instance fields are
	--       defined by the underlying alias model definition! The 
	--       member_instance will be nil, since the role was 'nil'
			
	-- save the meta-data
	table.insert(model[Data.DEFN], member_definition) 
	
	-- add/replace the definition in the container module
	if self[name] then print('WARNING: replacing ', name) end
	self[name] = instance
	table.insert(self[Data.MODEL][Data.DEFN], instance)
		
	return instance
end

-- create_member() - define a struct or union member (without the case)
-- @param member_definition - array consists of entries in the following order:
--           role     - the member role to instantiate (may be 'nil')
--           template - the kind of member to instantiate (previously defined)
--           ...      - optional list of annotations including whether the 
--                      member is an array or sequence    
-- @return the member instance and the member definition
function Data.create_member(member_definition)
	local role, template = member_definition[1], member_definition[2]
	
	-- ensure pre-conditions
	assert(nil == role or 'string' == type(role), 
			table.concat{'invalid member name: ', tostring(role)})
	assert('table' == type(template), 
			table.concat{'undefined type for member "', 
						  tostring(role), '": ', tostring(template)})
	assert(nil ~= template[Data.MODEL], 
		   table.concat{'invalid type for struct member "', 
		   tostring(role), '"'})

	local template_type = template[Data.MODEL][Data.TYPE]
	assert(Data.ATOM == template_type or
		   Data.ENUM == template_type or
		   Data.STRUCT == template_type or 
		   Data.UNION == template_type or
		   Data.TYPEDEF == template_type,
		   table.concat{'member "', tostring(role), 
					    '" must be a atom|enum|struct|union|typedef: '})

	-- ensure that the rest of the member definition entries are annotations:	
	-- also look for the 1st 'collection' annotation (if any)
	local collection = nil
	for j = 3, #member_definition do
		assert('table' == type(member_definition[j]),
				table.concat{'annotation expected "', tostring(role), 
						     '" : ', tostring(member_definition[j])})
		assert(Data.ANNOTATION == member_definition[j][Data.MODEL][Data.TYPE],
				table.concat{'not an annotation: "', tostring(role), 
							'" : ', tostring(member_definition[j])})	

		-- is this a collection?
		if not collection and  -- the 1st 'collection' definition is used
		   (Data.ARRAY == member_definition[j][Data.MODEL] or
		    Data.SEQUENCE == member_definition[j][Data.MODEL]) then
			collection = member_definition[j]
		end
	end

	-- populate the member_instance fields
	local member_instance = nil

	if role then -- don't compute member instance if role is not specified 
		if collection then
			local iterator = template
			for i = 1, #collection - 1  do -- create iterator for inner dimensions
				iterator = Data.seq('', iterator) -- unnamed iterator
			end
			member_instance = Data.seq(role, iterator)
		else
			member_instance = Data.instance(role, template)
		end
	end
	
	return member_instance, member_definition
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

-- Arrays and Sequences are implemented as a special annotations, whose 
-- attributes are positive integer constants, that specify the dimension bounds
-- NOTE: Since an array or a sequence is an annotation, it can appear anywhere 
--       after a member type declaration; the 1st one is used
local tmp_fn, tmp_model = Data:Annotation('Array')
Data.ARRAY = tmp_model -- 'Array' annotation's data model
function Data.Array(n, ...)
	return Data._Collection(Data._.Array, n, ...)
end

tmp_fn, tmp_model = Data:Annotation('Sequence')
Data.SEQUENCE = tmp_model -- 'Sequence' annotation's data model
function Data.Sequence(n, ...)
	return Data._Collection(Data._.Sequence, n, ...)
end

-- _Collection() - helper method to define collections, i.e. sequences and arrays
function Data._Collection(annotation, n, ...)

	-- ensure that we have an array of positive numbers
	local dimensions = {...}
	table.insert(dimensions, 1, n) -- insert n at the begining
	for i, v in ipairs(dimensions) do
		assert(type(v)=='number',  
			table.concat{'invalid collection bound: ', tostring(v)})
		assert(v >= 0,  
			table.concat{'collection bound must be > 0: ', v})
	end
	
	-- return the predefined annotation instance, whose attributes are 
	-- the collection dimension bounds
	return annotation(dimensions)
end

--------------------------------------------------------------------------------
-- Model Instances  ---
--------------------------------------------------------------------------------

-- Data.instance() - creates an instance, using another instance as a template
-- Purpose:
--    Define a table that can be used to index into an instance of a model
-- Parameters:
-- 	  <<in>> name  - the role|instance name
-- 	  <<in>> template - the template to use for creating an instance; must be a
--                      a model table 
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
	assert('table' == type(template), 'invalid template!')
	assert(template[Data.MODEL],
		   table.concat{'template must have a model definition: ', tostring(name)})
	local template_type = template[Data.MODEL][Data.TYPE]
	assert(Data.ATOM == template_type or
		   Data.ENUM == template_type or
		   Data.STRUCT == template_type or 
		   Data.UNION == template_type or
		   Data.TYPEDEF == template_type,
		   table.concat{'template must be a atom|enum|struct|union|typedef: ', 
		   				 tostring(name)})
	local instance = nil

	---------------------------------------------------------------------------
	-- typedef? switch the template to the underlying alias
	---------------------------------------------------------------------------

	local alias, alias_type, alias_sequence, alias_collection
	
	if Data.TYPEDEF == template_type then
		local decl = template[Data.MODEL][Data.DEFN][1]
		alias = decl[2]
		alias_type = alias[Data.MODEL][Data.TYPE]
		
		for i = 3, #decl do
			if Data.ARRAY == decl[i][Data.MODEL] or 
			   Data.SEQUENCE == decl[i][Data.MODEL] then
				alias_collection = decl[i]
				-- print('DEBUG Data.instance 2: ', name, alias_collection)
				break -- 1st 'collection' is used
			end
		end
	end

	-- switch template to the underlying alias
	if alias then template = alias end
	 
	---------------------------------------------------------------------------
	-- typedef is a collection:
	---------------------------------------------------------------------------
	
	-- collection of underlying types (which is not a typedef)
	if alias_sequence then -- the sequence of alias elements
		instance = Data.seq(name, template) 
		return instance
	end

	if  alias_collection then
		local iterator = template
		for i = 1, #alias_collection - 1  do -- create iterator for inner dimensions
			iterator = Data.seq('', iterator) -- unnamed iterator
		end
		instance = Data.seq(name, iterator)
		return instance
	end
	
	---------------------------------------------------------------------------
	-- typedef is recursive:
	---------------------------------------------------------------------------
	
	if Data.TYPEDEF == template_type and Data.TYPEDEF == alias_type then
		instance = Data.instance(name, template) -- recursive
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
		   	  table.concat{'sequence template ',
		   	  			   'must be an instance table or function: "',
		   	 			   tostring(name), '"'})
	if 'table' == type_template then
		local element_type = template[Data.MODEL][Data.TYPE]
		assert(Data.ATOM == element_type or
			   Data.ENUM == element_type or
			   Data.STRUCT == element_type or 
			   Data.UNION == element_type or
			   Data.TYPEDEF == element_type,
			   table.concat{'sequence template must be a ', 
			   				'atom|enum|struct|union|typedef: ', 
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
		local decl = mydefn[1]
		local alias, collection = decl[2], decl[3]
		if collection then
			print(string.format('%s%s sequence<%s%s> %s;\n', indent_string, mytype(), 
							    alias[Data.MODEL][Data.NAME], 
							    #collection == 0 and '' or ',' .. collection[1],
							    myname))
		else
			print(string.format('%s%s %s %s;\n', indent_string, mytype(), 
							    alias[Data.MODEL][Data.NAME], 
							    myname))
		end
		return instance, indent_string 
	end
	
	-- open --
	if (nil ~= myname) then -- not top-level
	
		-- print the annotations
		if nil ~=mydefn then
			for i, decl in ipairs(mydefn) do
				if decl[Data.MODEL] and Data.ANNOTATION == decl[Data.MODEL][Data.TYPE] then
					print(string.format('%s%s', indent_string, tostring(decl)))
				end
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
-- decl is { role, element, [collection,] [annotation1, annotation2, ...] }
function Data.print_idl_member(decl, content_indent_string)
	
	local role, element = decl[1], decl[2]
	local seq
	for i = 3, #decl do
		if Data.SEQUENCE == decl[i][Data.MODEL] then
			seq = decl[i]
			break -- 1st 'collection' is used
		end
	end

	local output_member = ''		
	if seq == nil then -- not a sequence
		output_member = string.format('%s%s %s', content_indent_string, 
		element[Data.MODEL][Data.NAME], role)
	elseif #seq == 0 then -- unbounded sequence
		output_member = string.format('%ssequence<%s> %s', content_indent_string, 
		element[Data.MODEL][Data.NAME], role)
	else -- bounded sequence
		output_member = string.format('%s', content_indent_string)
		for i = 1, #seq do
			output_member = string.format('%ssequence<', output_member) 
		end
		output_member = string.format('%s%s', output_member, 
											  element[Data.MODEL][Data.NAME])
		for i = 1, #seq do
			output_member = string.format('%s,%d>', output_member, seq[i]) 
		end
		output_member = string.format('%s %s', output_member, role)
	end

	-- member annotations:	
	--   start with the 3rd or the 4th entry depending upon whether it 
	--   was a sequence or not:
	local output_annotations = nil
	for j = 3, #decl do
		
		local name = decl[j][Data.MODEL][Data.NAME]
		
		if Data.ARRAY == decl[j][Data.MODEL] then
			for i = 1, #decl[j] do
				output_member = string.format('%s[%d]', output_member, decl[j][i]) 
			end
		elseif Data.SEQUENCE ~= decl[j][Data.MODEL] then
			output_annotations = string.format('%s%s ', 
									output_annotations or '', 
									tostring(decl[j]))	
		end
	end

	if output_annotations then
		print(string.format('%s; //%s', output_member, output_annotations))
	else
		print(string.format('%s;', output_member))
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
		local role, element 
		
		-- skip annotations
		if not decl[Data.MODEL] then
			-- walk through the elements in the order of definition:
			if Data.UNION == mytype then
				role, element = decl[2][1], decl[2][2]
			else -- Data.STRUCT or Data.TYPEDEF
				 role, element = decl[1], decl[2]
			end
			
			local instance_member = instance[role]
			local instance_member_type = type(instance_member)
			-- print('DEBUG index 3: ', role, instance_member)

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
return Data:Module{''} -- global module (unnamed)
--return Data._
--------------------------------------------------------------------------------
