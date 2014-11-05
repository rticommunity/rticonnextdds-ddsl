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

-------------------------------------------------------------------------------
-- Data - meta-data (meta-table) class implementing a semantic data definition 
--        model equivalent to OMG IDL, and easily mappable to various 
--        representations (eg OMG IDL, XML etc)
--
-- @module Data
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
--  In IDL, referenced data types need to be defined first
--    Forward declarations not allowed
--    Forward references not allowed
--  
-- Usage:
-- Definition:
--  Unions:
--   { { case, role = { template, [collection,] [annotation1, annotation2, ...] } } }
--  Structs:
--   { { role = { template, [collection,] [annotation1, annotation2, ...] } } }
--  Typedefs:
--   { template, [collection,] [annotation1, annotation2, ...] }
--   
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
--        Data.KIND
--        Data.DEFN
--        Data.INSTANCES
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
--          [Data.KIND] = Data.STRUCT    -- one of Data.* type definitions
--          [Data.DEFN] = {              -- meta-data for the contained elements
--              user_role1    = Data.String(),
--              user_role2    = UserModule.UserType2,
--				user_role3    = UserModule.UserType3,
--				user_role_seq = UserModule.UserTypeSeq,
--          }             
--          [Data.INSTANCES] = {}       -- table of instances of this model 
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
--          Model[Data.INSTANCES].i1.role1
-- 
--   Extend builtin atoms and annotations by adding to the Data.builtin module:
--       Data.builtin.my_atom = Data.atom{}
--       Data.builtin.my_annotation = Data.annotation{val1=1, val2=y, ...}
--     
-- Implementation:
--    The meta-model pre-defines the following meta-data 
--    attributes for a model element:
--
--       Data.KIND
--          Every model element 'model' is represented as a table with a 
--          non-nil key
--             model[Data.KIND] = one of the Data.* type definitions
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
--       Data.INSTANCES
--          For storing instances of this model element, indexed by instance name
--              model[Data.DEFN].name = one of the instances of this model
--          where 'name' is the name of instance (in a container model element)
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
--    Note that this class (table) is really just the meta-table for the user
--    defined model elements.
--
-- NOTES
--    Self-recursive definitions require a forward declaration, and generate a
--    warning. To create a forward declaration, install the same name twice,
--    first as an empty definition, and then as a full definition. Ignore the warning!
--

local MODEL = function() return 'MODEL' end -- table key for 'model' meta-data 

local Data = {
	-- instance attributes ---
	-- every 'instance' table has this meta-data key defined
	-- the rest of the keys are fields of the instance
	
	-- model meta-data attributes ---
	-- every 'model' meta-data table has these keys defined 
	NAME      = function() return 'NAME' end,  -- table key for 'model name'	
	KIND      = function() return 'KIND' end,  -- table key for the 'model type name' 
	DEFN      = function() return 'DEFN' end,  -- table key for element meta-data
	INSTANCES = function() return 'INSTANCES' end,-- table key for instances of this model
  TEMPLATE  = function() return 'TEMPLATE' end,-- table key for the template instance

		
	-- meta-data types - i.e. list of possible user defined types ---
	-- possible 'model[Data.KIND]' values implemented as closures
	MODULE     = function() return 'module' end,
	STRUCT     = function() return 'struct' end,
	UNION      = function() return 'union' end,
	ENUM       = function() return 'enum' end,
	ATOM       = function() return 'atom' end,
	ANNOTATION = function() return 'annotation' end,
	TYPEDEF    = function() return 'typedef' end,
	CONST      = function() return 'const' end,
	
	BASE       = function() return ' : ' end,    -- struct base
	SWITCH     = function() return 'switch' end, -- union switch
  NS         = function() return '' end,       -- module namespace
}

---
-- Internal Implementation Details
local _ = {
  API = {}
}

--- Create a new 'empty' template
-- @param kind  [in] the kind of template
-- @return a new template ith the correct meta-model
function _.new_template(kind)
 
  local model = {           -- meta-data
    [Data.NAME] = nil,      -- will get populated when inserted into a module
    [Data.KIND] = kind,     -- type of the data model
    [Data.DEFN] = {},       -- will be populated by the declarations
    [Data.INSTANCES] = nil, -- will be populated when the type is defined
    [Data.TEMPLATE] = {},   -- top-level instance to be installed in the module
  }
  local template = model[Data.TEMPLATE]
  template[MODEL] = model

  -- set the template meta-table:
  setmetatable(template, _.API[kind])
  
  return template
end

--- Populate a template
-- @param template  <<in>> a template, generally empty
-- @param defn      <<in>> template model definition
-- @return populated template 
function _.populate_template(template, defn)
  -- populate the role definitions
  local annotations
  for i, defn_i in ipairs(defn) do 

    -- build the model level annotation list
    if Data.ANNOTATION == _.model_type(defn_i) then     
      annotations = annotations or {}
      table.insert(annotations, defn_i)  

    else --  member definition
      -- insert the model definition entry: invokes meta-table __newindex()
      template[#template+1] = defn_i  
    end
  end

  -- insert the annotations:
  if annotations then -- insert the annotations:
    template[Data.ANNOTATION] = annotations -- invokes meta-table __newindex()
  end

  return template
end

--------------------------------------------------------------------------------
-- Model Definitions -- 
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

--- Define an atomic type
-- @return an immutable table representing an atomic type
-- @usage
--  -- Create an atomic type
--     MyAtom = Data.atom{}
function Data.atom()
  -- create the template
  local template = _.new_template(Data.ATOM) 
  return template
end

--- Atom API meta-table
_.API[Data.ATOM] = {

  __tostring = function(template)
    -- the name or the kind (if no name has been assigned)
    return template[MODEL][Data.NAME] or
      template[MODEL][Data.KIND]() -- evaluate the function
  end,

  __newindex = function (template, key, value)
    -- immutable: do-nothing
  end
}

--------------------------------------------------------------------------------

--- Define an constant
-- @param param  [in] a table containing an atom and the constant value, e.g.
--                       { Data.atom, const_value_of_atom_type }
-- @return a table representing a constant
-- @usage
--  -- Create a constant type
--       MY_CONST = Data.const{Data.<atom>, <const_value_of_atom_type> }
--  
--  -- Examples
--       PI = Data.const{ Data.double, 3.14 }
-- 
--       MY_CONST = Data.const{ Data.short, 10 }
--       
--       MY_STRING = Data.const{ Data.string(), "String Constant" }   
--       
--       MyStringSeq =  Data.typedef{ Data.string, Data.sequence(MY_CONST) }
function Data.const(param) 
  -- pre-condition: parameters are specified
  assert('table' == type(param), 
       table.concat{'invalid type specification: ', tostring(param)})
       
  -- pre-condition: ensure that the 1st parameter is a valid type
  local atom = param[1]
  assert('table' == type(atom), 
         table.concat{'invalid const primitive (atom) type: ', tostring(atom)})
  assert(Data.ATOM == atom[MODEL][Data.KIND], 
         table.concat{'const must of of primitive (atom) type: ', 
                      tostring(atom)})
         
  -- pre-condition: ensure that the 2nd parameter is a valid value
  local value = param[2]
  assert(nil ~= value, 
         table.concat{'const value must be non-nil: ', tostring(value)})
  assert((Data.boolean == atom and 'boolean' == type(value) or
         ((Data.string() == atom or Data.wstring() == atom or Data.char == atom) and 
          'string' == type(value)) or 
         ((Data.short == atom or Data.unsigned_short == atom or 
           Data.long == atom or Data.unsigned_long == atom or 
           Data.long_long == atom or Data.unsigned_long_long == atom or
           Data.float == atom or 
           Data.double == atom or Data.long_double == atom) and 
           'number' == type(value)) or
         ((Data.unsigned_short == atom or 
           Data.unsigned_long == atom or
           Data.unsigned_long_long == atom) and 
           value < 0)), 
         table.concat{'const value must be non-negative and of the type: ', 
                      atom[MODEL][Data.NAME] })
         

  -- char: truncate value to 1st char; warn if truncated
  if (Data.char == atom or Data.wchar == atom) and #value > 1 then
    value = string.sub(value, 1, 1)
    print(table.concat{'WARNING: truncating string value for ',
                       atom[MODEL][Data.NAME],
                       ' constant to: ', value})  
  end
 
  -- integer: truncate value to integer; warn if truncated
  if (Data.short == atom or Data.unsigned_short == atom or 
      Data.long == atom or Data.unsigned_long == atom or 
      Data.long_long == atom or Data.unsigned_long_long == atom) and
      value - math.floor(value) ~= 0 then
    value = math.floor(value)
    print(table.concat{'WARNING: truncating decimal value for integer constant ', 
                       'to: ', value})
  end

  -- create the template
  local template = _.new_template(Data.CONST) 
  template[MODEL][Data.DEFN] = atom
  template[MODEL][Data.INSTANCES] = value
  return template
end


--- Const API meta-table
_.API[Data.CONST] = {

  __tostring = function(const)
    local value = const[MODEL][Data.INSTANCES]
    local atom = const[MODEL][Data.DEFN]
    if Data.char == atom or Data.wchar == atom then
      return table.concat{"'", tostring(value), "'"}
    elseif Data.string() == atom or Data.wstring() == atom then
      return table.concat{'"', tostring(value), '"'}
    else
      return tostring(value)
    end
  end,

  __newindex = function (template, key, value)
    -- immutable: do-nothing
  end,

  -- instance value is obtained by evaluating the table:
  -- eg: MY_CONST()
  __call = function(const)
    return const[MODEL][Data.INSTANCES]
  end,
}

--------------------------------------------------------------------------------

--- Create a typedef. 
-- 
-- Typedefs are aliases for underlying primitive or composite types 
-- @param param [in] the underlying type definition and optional multiplicity
--                   and annotations, e.g.
--                 { template, [collection,] [annotation1, annotation2, ...] } 
-- @return a table represensing the typedef
-- @usage
--  IDL: typedef sequence<MyStruct> MyStructSeq
--  Lua: MyStructSeq = Data.typedef{ Data.MyStruct, Data.sequence() }
--
--  IDL: typedef MyStruct MyStructArray[10][20]
--  Lua: MyStructArray = Data.typedef{ Data.MyStruct, Data.array(10, 20) }
function Data.typedef(param) 
  -- pre-condition: parameters are specified
  assert('table' == type(param), 
       table.concat{'invalid type specification: ', tostring(param)})

  -- pre-condition: ensure that the 1st parameter is a valid type
  local alias = param[1]
  assert('table' == type(alias), 
    table.concat{'undefined alias type for typedef: "', tostring(alias), '"'})
  assert(nil ~= alias[MODEL], 
    table.concat{'alias must be a data model for typedef "', tostring(alias), 
                 '"'})
  local alias_type = alias[MODEL][Data.KIND]
  assert(Data.ATOM == alias_type or
       Data.ENUM == alias_type or
       Data.STRUCT == alias_type or 
       Data.UNION == alias_type or
       Data.TYPEDEF == alias_type,
       table.concat{'alias must be a atom|enum|struct|union|typedef: ', 
                    tostring(alias)})

  -- pre-condition: ensure that the 2nd parameter if present 
  -- is a 'collection' type
  local collection = param[2]  
  assert(nil == collection or
        Data.ARRAY == collection[MODEL] or
        Data.SEQUENCE == collection[MODEL],
    table.concat{'invalid collection for typedef "', tostring(collection), '"'})
 

  -- create the template
  local template = _.new_template(Data.TYPEDEF) 
  template[MODEL][Data.DEFN] = { alias, collection }
  return template
end

--- Atom API meta-table
_.API[Data.TYPEDEF] = {

  __tostring = function(template)
    -- the name or the kind (if no name has been assigned)
    return template[MODEL][Data.NAME] or
      template[MODEL][Data.KIND]() -- evaluate the function
  end,

  __newindex = function (template, key, value)
    -- immutable: do-nothing
  end
}

--------------------------------------------------------------------------------

--- Create an annotation
--  Annotations attributes are not interpreted, and kept intact 
-- @param ...  optional 'default' attributes of the annotation
-- @return an annotation table
-- @usage
--   -- IDL @Key
--     Data.Key
--     Data.Key{GUID=N}
--     
--  --  IDL @Exensibility(EXTENSIBLE_EXTENSIBILITY)
--    Data.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
-- 
--  -- Create user defined annotation @MyAnnotation(value1 = 42, value2 = 42.0)
--     MyAnnotation = Data.annotation{value1 = 42, value2 = 9.0}
--
--  -- Use user defined annotation with custom attributes
--     MyAnnotation{value1 = 942, value2 = 999.0}
--        
function Data.annotation(...)   
  -- create the template
  local template = _.new_template(Data.ANNOTATION)
  local model = template[MODEL]
  
  -- annotation definition function (closure)
  -- NOTE: the attributes passed to the annotation are not interpreted,
  --       and are kept intact; we simply add the MODEL definition
  --   A function that returns a model table, with user defined 
  --   annotation attributes passed as a table of {name = value} pairs
  --      eg: Data.MyAnnotation{value1 = 42, value2 = 42.0}
  model[Data.DEFN] = function (attributes) -- parameters to the annotation
    if attributes then
      assert('table' == type(attributes), 
        table.concat{'table with {name=value, ...} attributes expected: ', 
                   tostring(attributes)})
    end
    local instance = attributes or template
    instance[MODEL] = model
    setmetatable(instance, _.API[Data.ANNOTATION]) -- needed for __tostring()
    return instance   
  end
  
  -- initialize template with the attributes
  template = template(...)
  
  return template
end

--- Annotations API meta-table
_.API[Data.ANNOTATION] = {

  __tostring = function(annotation)
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
      output = string.format('@%s(%s)', annotation[MODEL][Data.NAME], output)
    else
      output = string.format('@%s', annotation[MODEL][Data.NAME])
    end

    return output
  end,

  __newindex = function (template, key, value)
  -- immutable: do-nothing
  end,

  __call = function(annotation, ...)
    return annotation[MODEL][Data.DEFN](...)
  end
}

--------------------------------------------------------------------------------

--- Create an enum type
-- @param param a table representing the enum declaration  
-- @return a table representing the enum data model. The table fields 
-- contain the string index to de-reference the enum's constants in 
-- a top-level DDS Dynamic Data Type 
-- @usage
--    -- Create enum: Declarative style
--    MyEnum = Data.enum{ 
--      { role_1 = ordinal_value },
--      :
--      { role_M = ordinal_value },
--      
--      -- OR --
--
--      role_A,
--      :
--      role_Z,
--      
--      -- OPTIONAL --
--      annotation?,
--       :
--      annotation?,
--    }
--    
-- -- Create enum: Declarative style
--   MyEnum = Data.enum{}
--   
--  -- Get | Set an annotation:
--   print(MyEnum[Data.ANNOTATION])
--   MyEnum[Data.ANNOTATION] = {    
--        Data.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
--      }
--      
--  -- Get | Set a member:
--   print(next(MyEnum[i]))
--   MyEnum[i] = { role = ordinal_value },
--   -- OR --
--   MyEnum[i] = role -- ordinal value = #MyEnum
--
--  -- After either of the above definition, the following post-condition holds:
--    MyEnum.role == ordinal_value
--  
--    
--  -- Iterate over the model definition (ordered):
--    for i, v in ipairs(MyEnum) do print(next(v)) end
--    for i = 1, #MyEnum do print(next(MyEnum[i])) end
--
--  -- Iterate over enum and ordinal values (unordered):
--    for k, v in pairs(MyEnum) do print(k, v) end
--
function Data.enum(param) 
  -- pre-condition: parameters are specified
  assert(nil == param or 'table' == type(param), 
       table.concat{'invalid type specification: ', tostring(param)})
       
  -- create the template
  local template = _.new_template(Data.ENUM)

  -- populate the template
  return _.populate_template(template, param)
end

--- Enum API meta-table
_.API[Data.ENUM] = {

  __tostring = function(template) 
    -- the name or the kind (if no name has been assigned)
    return template[MODEL][Data.NAME] or 
           template[MODEL][Data.KIND]() -- evaluate the function
  end,
  
  __len = function (template)
    return #template[MODEL][Data.DEFN]
  end,

  __ipairs = function(template)
    return ipairs(template[MODEL][Data.DEFN])
  end,

  __index = function (template, key)
    local model = template[MODEL]
    if Data.NAME == key then
      return model[Data.NAME]
    elseif Data.KIND == key then
      return model[Data.KIND]
    else -- delegate to the model definition
       return template[MODEL][Data.DEFN][key]
    end
  end,
  
  __newindex = function (template, key, value)

    local model = template[MODEL]
    local model_defn = model[Data.DEFN]

    if Data.NAME == key then -- set the model name
      rawset(model, Data.NAME, value)

    elseif Data.ANNOTATION == key then -- annotation definition
      -- set the new annotations in the model definition (may be nil)
      model_defn[Data.ANNOTATION] = _.assert_annotation_array(value)

    elseif 'number' == type(key) then -- member definition
      -- clear the old member definition and instance fields
      if model_defn[key] then
        local old_role = next(model_defn[key])

        -- update instances: remove the old_role
        rawset(template, old_role, nil)
      end

      -- set the new member definition
      if nil == value then
        -- nil => remove the key-th member definition
        table.remove(model_defn, key) -- do not want holes in array

      else
        --  Format:
        --    { role = role_defn (i.e. ordinal value) } 
        -- OR 
        --    role 
        local role, role_defn 
        if 'table' ==  type(value) then
          role, role_defn = next(value)        --  { role = value } 
        else
           role, role_defn = value, #template  --    role
        end
        
        -- role must be a string
        assert(type(role) == 'string', 
          table.concat{'invalid member name: ', tostring(role)})

        -- ensure the definition is an ordinal value
        assert('number' == type(role_defn) and 
               math.floor(role_defn) == role_defn, -- integer  
        table.concat{'invalid definition: ', 
                      tostring(role), ' = ', tostring(role_defn) })
          
        -- is the role already defined?
        assert(nil == rawget(template, role),-- check template
          table.concat{'member name already defined: "', role, '"'})
        
        -- insert the new role
        rawset(template, role, role_defn)
        
        -- insert the new member definition
        model_defn[key] = {
          [role] = role_defn   -- map with one entry
        }
      end
    end
  end
}

--------------------------------------------------------------------------------

--- Create a struct type
-- @param param a table representing the struct declaration  
-- @return a table representing the struct data model. The table fields 
-- contain the string index to de-reference the struct's value in 
-- a top-level DDS Dynamic Data Type 
-- @usage
--    -- Create struct: Declarative style
--    MyStruct = Data.struct{OptionalBaseStruct, 
--      { role_1 = { type, multiplicity?, annotation? } },
--      :  
--      { role_M = { type, multiplicity?, annotation? } },
--      annotation?,
--       :
--      annotation?,
--    }
--    
--  -- Create struct: Imperative style
--   MyStruct = Data.struct{}
--   
--  -- Get | Set an annotation:
--   print(MyStruct[Data.ANNOTATION])
--   MyStruct[Data.ANNOTATION] = {    
--        Data.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
--        Data.Nested{'FALSE'},
--      }
--      
--  -- Get | Set a member:
--   print(next(MyStruct[i]))
--   MyStruct[i] = { role = { type, multiplicity?, annotation? } },
--   
--  -- Get | Set base class:
--   print(MyStruct[Data.BASE])
--   MyStruct[Data.BASE] = BaseStruct, -- optional
-- 
-- 
--  -- After either of the above definition, the following post-condition holds:
--    MyStruct.role == 'container.prefix.upto.role'
-- 
--    
--  -- Iterate over the model definition (ordered):
--    for i, v in ipairs(MyStruct) do print(next(v)) end
--    for i = 1, #MyStruct do print(next(MyStruct[i])) end
--
--  -- Iterate over instance members and the indexes (unordered):
--    for k, v in pairs(MyStruct) do print(k, v) end
--
function Data.struct(param) 
  -- pre-condition: parameters are specified
  assert(nil == param or 'table' == type(param), 
       table.concat{'invalid type specification: ', tostring(param)})
       
  -- create the template
  local template = _.new_template(Data.STRUCT)
  template[MODEL][Data.INSTANCES] = {}
  
  -- OPTIONAL base: pop the next element if it is a base model element
  local base
  if Data.STRUCT == _.model_type(param[1]) then
    base = param[1]   table.remove(param, 1)

    -- insert the base class:
    template[Data.BASE] = base -- invokes the meta-table __newindex()
  end

  -- populate the template
  return _.populate_template(template, param)
end

--- Struct API meta-table
_.API[Data.STRUCT] = {

  __tostring = function(template)
    -- the name or the kind (if no name has been assigned)
    return template[MODEL][Data.NAME] or
      template[MODEL][Data.KIND]() -- evaluate the function
  end,

  __len = function (template)
    return #template[MODEL][Data.DEFN]
  end,

  __ipairs = function(template)
    return ipairs(template[MODEL][Data.DEFN])
  end,

  __index = function (template, key)
    local model = template[MODEL]
    if Data.NAME == key then
      return model[Data.NAME]
    elseif Data.KIND == key then
      return model[Data.KIND]
    else -- delegate to the model definition
      return template[MODEL][Data.DEFN][key]
    end
  end,

  __newindex = function (template, key, value)

    local model = template[MODEL]
    local model_defn = model[Data.DEFN]

    if Data.NAME == key then -- set the model name
      rawset(model, Data.NAME, value)

    elseif Data.ANNOTATION == key then -- annotation definition
      -- set the new annotations in the model definition (may be nil)
      model_defn[Data.ANNOTATION] = _.assert_annotation_array(value)

    elseif 'number' == type(key) then -- member definition
      --  Format:
      --  { role = { template, [collection,] [annotation1, annotation2, ...] } }

      -- clear the old member definition and instance fields
      if model_defn[key] then
        local old_role = next(model_defn[key])

        -- update instances: remove the old_role
        if old_role then
          _.update_instances(model, old_role, nil) -- clear the role
        end
    end

    -- set the new member definition
    if nil == value then
      -- nil => remove the key-th member definition
      table.remove(model_defn, key) -- do not want holes in array

    else
      -- get the new role and role_defn
      local role, role_defn = next(value)

      -- role must be a string
      assert(type(role) == 'string',
        table.concat{'invalid member name: ', tostring(role)})

      -- is the role already defined?
      assert(nil == rawget(template, role),-- check template
        table.concat{'member name already defined: "', role, '"'})

      -- create role instance (checks for pre-conditions, may fail!)
      local role_instance = _.create_role_instance(role, role_defn)

      -- update instances: add the new role_defn
      _.update_instances(model, role, role_instance)

      -- insert the new member definition
      local role_defn_copy = {} -- make our own local copy
      for i, v in ipairs(role_defn) do role_defn_copy[i] = v end
      model_defn[key] = {
        [role] = role_defn_copy   -- map with one entry
      }
    end

    elseif Data.BASE == key then -- inherits from 'base' struct

      -- clear the instance fields from the old base struct (if any)
      local old_base = model_defn[Data.BASE]
      while old_base do
        for k, v in pairs(old_base) do
          if 'string' == type(k) then -- copy only the base instance fields
            -- update instances: remove the old_base role
            _.update_instances(model, k, nil) -- clear the role
          end
        end

        -- template is no longer an instance of the base struct
        old_base[MODEL][Data.INSTANCES][template] = nil

        -- visit up the base model inheritance hierarchy
        old_base = old_base[Data.BASE] -- parent base
      end

      -- get the base model, if any:
      local new_base
      if nil ~= value then
        new_base = _.assert_model(Data.STRUCT, value)
      end

      -- populate the instance fields from the base model struct
      local base = new_base
      while base do
        for i = 1, #base[MODEL][Data.DEFN] do
          local base_role, base_role_defn = next(base[MODEL][Data.DEFN][i])

          -- is the base_role already defined?
          assert(nil == rawget(template, base_role),-- check template
            table.concat{'member name already defined: "', base_role, '"'})

          -- create base role instance (checks for pre-conditions, may fail)
          local base_role_instance =
            _.create_role_instance(base_role, base_role_defn)


          -- update instances: add the new role_defn
          _.update_instances(model, base_role, base_role_instance)
        end

        -- visit up the base model inheritance hierarchy
        base = base[MODEL][Data.DEFN][Data.BASE] -- parent base
      end

      -- set the new base in the model definition (may be nil)
      model_defn[Data.BASE] = new_base

      -- template is an instance of the base structs (inheritance hierarchy)
      base = new_base
      while base do
        -- NOTE: Since we don't have a well-defined "name", we make an
        -- and exception, and use the template (instance) itself to
        -- index into the INSTANCES table. This is utilized by the
        -- ._update_instances() to correctly update the template
        base[MODEL][Data.INSTANCES][template] = template

        -- visit up the base model inheritance hierarchy
        base = base[MODEL][Data.DEFN][Data.BASE] -- parent base
      end
    end
  end
}

--------------------------------------------------------------------------------

--- Create a union type
-- @param param a table representing the union declaration  
-- @return a table representing the union data model. The table fields 
-- contain the string index to de-reference the union's value in 
-- a top-level DDS Dynamic Data Type 
-- @usage
--    -- Create union: Declarative style
--    MyUnion = Data.union{ discriminator,
--      { case, 
--        [ { role_1 = { type, multiplicity?, annotation? } } ] },
--      :  
--      { case, 
--        [ { role_M = { type, multiplicity?, annotation? } } ] },
--      { nil, 
--        [ { role_Default = { type, multiplicity?, annotation? } } ] },
--      annotation?,
--       :
--      annotation?,
--    }
--    
-- -- Create union: Imperative style
--   MyUnion = Data.union{ discriminator }
--   
--  -- Get | Set an annotation:
--   print(MyUnion[Data.ANNOTATION])
--   MyUnion[Data.ANNOTATION] = {    
--        Data.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
--      }
--      
--  -- Get | Set a member:
--   print(next(MyUnion[i]))
--   MyUnion[i] = { case, [ { role = { type, multiplicity?, annotation? } } ] },
--   
--  -- Get | Set discriminator:
--   print(MyUnion[Data.SWITCH])
--   MyUnion[Data.SWITCH] = discriminator
-- 
-- 
--  -- After either of the above definition, the following post-condition holds:
--    MyUnion._d == '#'
--    MyUnion.role == 'container.prefix.upto.role'
--  
--    
--  -- Iterate over the model definition (ordered):
--    for i, v in ipairs(MyUnion) do print(v[1], ':', next(v, 1)) end
--    for i = 1, #MyUnion do print(t[i][1], ':', next(MyUnion[i], 1)) end
--
--  -- Iterate over instance members and the indexes (unordered):
--    for k, v in pairs(MyUnion) do print(k, v) end
--
function Data.union(param) 
  -- pre-condition: parameters are specified
  assert(nil == param or 'table' == type(param), 
       table.concat{'invalid type specification: ', tostring(param)})
       
  -- create the template 
  local template = _.new_template(Data.UNION)
  template[MODEL][Data.INSTANCES] = {}
 
 	-- pop the discriminator
	template[Data.SWITCH] = param[1] -- invokes meta-table __newindex()
  table.remove(param, 1)

  -- populate the template
  return _.populate_template(template, param)
end

--- Union API meta-table 
_.API[Data.UNION] = {

  __tostring = function(template) 
    -- the name or the kind (if no name has been assigned)
    return template[MODEL][Data.NAME] or 
           template[MODEL][Data.KIND]() -- evaluate the function
  end,

  __len = function (template)
    return #template[MODEL][Data.DEFN]
  end,

  __ipairs = function(template)
    return ipairs(template[MODEL][Data.DEFN])
  end,

  __index = function (template, key)
    local model = template[MODEL]
    if Data.NAME == key then
      return model[Data.NAME]
    elseif Data.KIND == key then
      return model[Data.KIND]
    else -- delegate to the model definition
       return template[MODEL][Data.DEFN][key]
    end
  end,

  __newindex = function (template, key, value)

    local model = template[MODEL]
    local model_defn = model[Data.DEFN]

    if Data.NAME == key then -- set the model name
      model[Data.NAME] = value

    elseif Data.ANNOTATION == key then -- annotation definition
      -- set the new annotations in the model definition (may be nil)
      model_defn[Data.ANNOTATION] = _.assert_annotation_array(value)

    elseif Data.SWITCH == key then -- switch definition

      local discriminator_type = _.model_type(value)
      assert(Data.ATOM == discriminator_type or
        Data.ENUM == discriminator_type,
        'discriminator type must be an "atom" or an "enum"')
      model[Data.DEFN][Data.SWITCH] = value
      rawset(template, '_d', '#')
     
      -- TODO: ensure that 'cases' are compatible with new discriminator
        
    elseif 'number' == type(key) then -- member definition
      --  Format:
      --   { case,
      --     role = { template, [collection,] [annotation1, annotation2, ...] }
      --   }

      -- clear the old member definition
      if model_defn[key] then
        local old_role = next(model_defn[key], 1) -- 2nd array item

        -- update instances: remove the old_role
        if old_role then
          _.update_instances(model, old_role, nil) -- clear the role
        end
      end

      if nil == value then
        -- remove the key-th member definition
        table.remove(model_defn, key) -- do not want holes in array
      else
        -- set the new role_defn
        local case = _.assert_case(model_defn[Data.SWITCH], value[1])

        -- is the case already defined?
        for i, defn_i in ipairs(model_defn) do
          assert(case ~= defn_i[1],
            table.concat{'case exists: "', tostring(case), '"'})
        end

        -- get the role and definition
        local role, role_defn = next(value, 1) -- 2nd item after the 'case'
 
          -- add the role
        if role then
          -- role must be a string
          assert(type(role) == 'string', 
          table.concat{'invalid member name: ', tostring(role)})
          
          -- is the role already defined?
          assert(nil == rawget(template, role),-- check template
            table.concat{'member name already defined: "', role, '"'})

          local role_instance = _.create_role_instance(role, role_defn)

          -- insert the new member definition
          local role_defn_copy = {} -- make our own local copy
          for i, v in ipairs(role_defn) do role_defn_copy[i] = v end
          model_defn[key] = {
            case,                     -- array of length 1
            [role] = role_defn_copy   -- map with one entry
          }

          -- update instances: add the new role_defn
          _.update_instances(model, role, role_instance)
        else
          model_defn[key] = {
            case,         -- array of length 1
          }
        end
      end
    end
  end
}

--------------------------------------------------------------------------------

--- Create a module 
-- 
-- A module represents a name-space that holds various user defined types
-- @param param a table representing the module declaration  
-- @return a table representing the module data model. The table fields 
-- contain the string index to de-reference the **user-defined** data types
-- @usage
--    -- Create module: Declarative style
--    MyModule    = Data.module{
--      MY_SIZE   = Data.const{...},
--      MyTypedef = Data.typedef{...},
--      MyEnum    = Data.enum{...},
--      MyStruct  = Data.struct{...},
--      MyUnion   = Data.union{...},
--      :
--    }
--    
--  -- Create module: Imperative style
--   MyModule = Data.module{}
--   
--  -- Get | Set a member:
--   print(MyModule[i])
--   MyModule[i] = { role = template }
--    -- or --
--   MyModule.role = template -- inserts at the end: MyModule[#MyModule+1]
--
--  -- After either of the above definition, the following post-condition holds:
--    MyModule.role == template
-- 
--    
--  -- Iterate over the module definition (ordered):
--   for i, v in ipairs(MyModule) do print(next(v)) end
--   for i = 1, #MyModule do print(next(MyModule[i])) end
--
--  -- Iterate over module namespace (unordered):
--   for k, v in pairs(MyModule) do print(k, v) end
--   
function Data.module(param) 
  -- pre-condition: parameters are specified
  assert(nil == param or 'table' == type(param), 
       table.concat{'invalid type specification: ', tostring(param)})
       
  --create the template
  local template = _.new_template(Data.MODULE)
  template[MODEL][Data.DEFN][Data.NS] = {} -- empty namespace
 
  -- populate the template
  return _.populate_template(template, param)
end

--- Module API meta-table
_.API[Data.MODULE] = {

  __tostring = function(template)
    -- the name or the kind (if no name has been assigned)
    return template[MODEL][Data.NAME] or
      template[MODEL][Data.KIND]() -- evaluate the function
  end,

  __len = function (template)
    return #template[MODEL][Data.DEFN]
  end,

  __ipairs = function(template)
    return ipairs(template[MODEL][Data.DEFN])
  end,

  __pairs = function(template)
    return pairs(template[MODEL][Data.DEFN][Data.NS])
  end,

  __index = function (template, key)
    local model = template[MODEL]
    if Data.NAME == key then
      return model[Data.NAME]
    elseif Data.KIND == key then
      return model[Data.KIND]
    elseif 'number' == type(key) then -- delegate to the model definition
      return model[Data.DEFN][key]
    else -- delegate to the module namespace
      return model[Data.DEFN][Data.NS][key]
    end
  end,
  
  __newindex = function (template, key, value)

    local model = template[MODEL]
    local model_defn = model[Data.DEFN]
    
    -- NOTE: Modules are special in two ways
    -- 1. Since a module does not have instances, the model definition
    --    [Data.NS] keys stores by role name
    -- 2. When model elements are added to a module, they are assigned a name
    --    in the context of the module. A model element can belong to 
    --    only one module.
            
    if Data.NAME == key then -- set the model name
      rawset(model, Data.NAME, value)

    elseif Data.ANNOTATION == key then -- annotation definition
      -- set the new annotations in the model definition (may be nil)
      model_defn[Data.ANNOTATION] = _.assert_annotation_array(value)

    elseif 'number' == type(key) then -- member definition
      -- clear the old member definition and instance fields
      if model_defn[key] then
        local old_role = next(model_defn[key])
        
        -- update namespace: remove the old_role
        model_defn[Data.NS][old_role] = nil
      end

      -- set the new member definition
      if nil == value then
        -- nil => remove the key-th member definition
        table.remove(model_defn, key) -- do not want holes in array

      else
        --  Format:
        --    { role = role_defn (i.e. role template) } 
        local role, role_defn = next(value)  
                      
        -- pre-condition: role must be a string
        assert(type(role) == 'string', 
          table.concat{'invalid member name: ', tostring(role)})

        -- pre-condition: ensure the definition is a template
        assert(nil ~= _.model_type(role_defn),
               table.concat{'invalid member definition: ', tostring(role)})
          
        -- is the role already defined?
        assert(nil == rawget(template, role),-- check template
          table.concat{'member name already defined: "', role, '"'})
    
        -- update namespace
        model_defn[Data.NS][role] = role_defn
        
        -- update the module definition
        model_defn[key] = { [role] = role_defn } -- index
        
        -- set the role instance (template) name
        role_defn[MODEL][Data.NAME] = role
      end

    elseif 'string' == type(key) then
      --  Format:
      --    role_defn (i.e. role template)
      local role, role_defn = key, value
  
      -- pre-condition: ensure that the value is nil or a model instance
      assert(nil == value or nil ~= _.model_type(role_defn))

      -- lookup the element to replace
      local position = #model_defn+1 -- append at the end, unless being replaced
      if nil ~= model_defn[Data.NS][role] then -- role already defined?
        for i = #model_defn, 1, -1 do -- count down, latest first
          if next(model_defn[i]) == role then 
            position = i break
          end
        end
      end
      
      -- update namespace
      model_defn[Data.NS][role] = role_defn
     
      -- update the module definition
      if nil == role_defn then
        -- remove the position-th member definition
        table.remove(model_defn, position) -- do not want holes in array
      else
        model_defn[position] = { [role] = role_defn }
        
        -- set the role instance (template) name
        role_defn[MODEL][Data.NAME] = role
      end
    end
  end,
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

--- Get the model type of any arbitrary value
-- @param value  [in] the value for which to retrieve the model type
-- @return the model type or nil (if 'value' does not have a MODEL)
function _.model_type(value)
    return ('table' == type(value) and value[MODEL]) 
           and value[MODEL][Data.KIND]
           or nil
end

--- Ensure that the value is a model element
-- @param kind   [in] expected model element kind
-- @param value  [in] table to check if it is a model element of "kind"
-- @return the model table if the kind matches, or nil
function _.assert_model(kind, value)
    assert('table' == type(value) and 
           value[MODEL] and 
           kind == value[MODEL][Data.KIND],
           table.concat{'expected model kind "', kind(), 
                        '", instead got "', tostring(value), '"'})
    return value
end

--- Ensure all elements in the 'value' array are annotations
-- @return the annotation array
function _.assert_annotation_array(value)
    -- establish valid annotations, if any
    local annotations
    if nil ~= value then
        for i, v in ipairs(value) do
            _.assert_model(Data.ANNOTATION, v)
        end
        annotations = value
    end
    return annotations
end

--- Ensure that case is a valid discriminator value
function _.assert_case(discriminator, case)
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
   elseif Data.ENUM == discriminator[MODEL][Data.KIND] then -- enum
    assert(discriminator[case], err_msg)
   else -- invalid 
    assert(false, err_msg)
   end
  
   return case
end

--- Define a role (member) instance
-- @param #string role - the member name to instantiate (may be 'nil')
-- @param #list<#table> role_defn - array consists of entries in the 
--           { template, [collection,] [annotation1, annotation2, ...] }
--      following order:
--           template - the kind of member to instantiate (previously defined)
--           ...      - optional list of annotations including whether the 
--                      member is an array or sequence    
-- @return the role (member) instance and the role_defn
function _.create_role_instance(role, role_defn)
	local template = role_defn[1]
	
	-- ensure pre-conditions
	assert(nil == role or 'string' == type(role), 
			table.concat{'invalid member name: ', tostring(role)})
	assert('table' == type(template), 
			table.concat{'undefined type for member "', 
						  tostring(role), '": ', tostring(template)})
	assert(nil ~= template[MODEL], 
		   table.concat{'invalid type for struct member "', 
		   tostring(role), '"'})

	local template_type = template[MODEL][Data.KIND]
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
	for j = 2, #role_defn do
		assert('table' == type(role_defn[j]),
				table.concat{'annotation expected "', tostring(role), 
						     '" : ', tostring(role_defn[j])})
		assert(Data.ANNOTATION == role_defn[j][MODEL][Data.KIND],
				table.concat{'not an annotation: "', tostring(role), 
							'" : ', tostring(role_defn[j])})	

		-- is this a collection?
		if not collection and  -- the 1st 'collection' definition is used
		   (Data.ARRAY == role_defn[j][MODEL] or
		    Data.SEQUENCE == role_defn[j][MODEL]) then
			collection = role_defn[j]
		end
	end

	-- populate the role_instance fields
	local role_instance = nil

	if role then -- skip member instance if role is not specified 
		if collection then
			local iterator = template
			for i = 1, #collection - 1  do -- create iterator for inner dimensions
				iterator = Data.seq('', iterator) -- unnamed iterator
			end
			role_instance = Data.seq(role, iterator)
		else
			role_instance = Data.instance(role, template)
		end
	end
	
	return role_instance, role_defn
end

--------------------------------------------------------------------------------
-- Model Instances  ---
--------------------------------------------------------------------------------

--- Create an instance, using another instance as a template
--  Defines a table that can be used to index into an instance of a model
-- 
-- @param	name      <<in>> the role|instance name
-- @param template  <<in>> the template to use for creating an instance; 
--                         must be a model table 
-- @return the newly created instance (seq) that supports indexing by 'name'
-- @usage
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
	-- print('DEBUG Data.instance 1: ', name, template[MODEL][Data.NAME])
	assert(type(name) == 'string', 
		   table.concat{'invalid instance name: ', tostring(name)})
	
	-- ensure valid template
	assert('table' == type(template), 'invalid template!')
	assert(template[MODEL],
		   table.concat{'template must have a model definition: ', tostring(name)})
	local template_type = template[MODEL][Data.KIND]
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
		local defn = template[MODEL][Data.DEFN]
		alias = defn[1]
		alias_type = alias[MODEL][Data.KIND]
		
		for j = 2, #defn do
			if Data.ARRAY == defn[j][MODEL] or 
			   Data.SEQUENCE == defn[j][MODEL] then
				alias_collection = defn[j]
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
  local model = template[MODEL]

  -- create the instance:
  local instance = { -- the underlying model, of which this is an instance
    [MODEL] = template[MODEL],
  }
  for k, v in pairs(template) do
    -- skip meta-data attributes
    if 'string' == type(k) then
      instance[k] = _.prefix(name, v)
    end
  end

  -- cache the instance, so that we can update it when the model changes
  model[Data.INSTANCES][instance] = name

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
	assert('table' == type_template and template[MODEL] or 
	       'function' == type_template, -- collection iterator
		   	  table.concat{'sequence template ',
		   	  			   'must be an instance table or function: "',
		   	 			   tostring(name), '"'})
	if 'table' == type_template then
		local element_type = template[MODEL][Data.KIND]
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

--- Prefix an index value with the given name
-- @param #string name name to prefix with
-- @param #type v index value
-- @return #type index value with the 'name' prefix
function _.prefix(name, v)

    local type_v = type(v)
    local result 
    
    -- prefix the member names
    if 'function' == type_v then -- seq
      result = -- use member as a closure template
        function(j, prefix_j) -- allow further prefixing
          return v(j, table.concat{prefix_j or '', name, '.'}) 
        end

    elseif 'table' == type_v then -- struct or union
      result = Data.instance(name, v) -- use member as template

    elseif 'string' == type_v then -- atom/leaf

      if '#' == v then -- _d: leaf level union discriminator
        result = table.concat{name, '', v} -- no dot separator
      else
        result = table.concat{name, '.', v}
      end

    end
    
    return result
end

--- Propagate member 'role' update to all instances of a model
-- @param #table model the model 
-- @param #string role the role to propagate
-- @param #type value the value of the role instance
function _.update_instances(model, role, role_template)

   -- update template first
   local template = model[Data.TEMPLATE]
   rawset(template, role, role_template)
   
   -- update the remaining member instances:
   for instance, name in pairs(model[Data.INSTANCES]) do
      if instance == template then -- template
          -- do nothing (already updated the template)
      elseif instance == name then -- child struct (model is a base struct)
          rawset(instance, role, role_template) -- no prefix    
      else -- instance: may be user defined or occurring in another type model
          -- prefix the 'name' to the role_template
          rawset(instance, role, _.prefix(name, role_template))
      end
   end
end

--- Fully qualified name of a model element
-- @param instance a model element whose fully qualified name is desired
-- @return the fully qualified name of the instance if any or 
--         the string value of instance
function Data.fqname(instance)
    return 'table' == type(instance) and 
              (instance[MODEL] and 
                instance[MODEL][Data.NAME]) or 
              tostring(instance)
end

--------------------------------------------------------------------------------
--- Builtin Module - Predefined Model Elements
--------------------------------------------------------------------------------

--- 'builtin' module
-- Built-in data types (atomic types) and annotations belong to this module
-- @type [parent=#Data]builtin
Data.builtin = Data.module{}

--- Built-in atomic types
Data.builtin.boolean = Data.atom{}
Data.builtin.octet = Data.atom{}

Data.builtin.char = Data.atom{}
Data.builtin.wchar = Data.atom{}

Data.builtin.float = Data.atom{}
Data.builtin.double = Data.atom{}
Data.builtin.long_double = Data.atom{}

Data.builtin.short = Data.atom{}
Data.builtin.long = Data.atom{}
Data.builtin.long_long = Data.atom{}

Data.builtin.unsigned_short = Data.atom{}
Data.builtin.unsigned_long = Data.atom{}
Data.builtin.unsigned_long_long = Data.atom{}

--- Built-in annotations
Data.builtin.Key = Data.annotation{}
Data.builtin.Extensibility = Data.annotation{}
Data.builtin.ID = Data.annotation{}
Data.builtin.MustUnderstand = Data.annotation{}
Data.builtin.Shared = Data.annotation{}
Data.builtin.BitBound = Data.annotation{}
Data.builtin.BitSet = Data.annotation{}
Data.builtin.Nested = Data.annotation{}
Data.builtin.top_level = Data.annotation{} -- legacy


--- Local helper method to define a string on maximum length 'n'.
-- Used by Data.string() and Data.wstring().
-- 
-- A string of length n (i.e. string<n>) is implemented as an automatically 
-- defined Atom with the correct name.
-- 
-- @function string 
-- @param #number n the maximum length of the string
-- @param #string name the name of the underlying type: string or wstring
-- @return #table the string data model instance, the name under which to 
--                install the atom
function _.string(n, name)
    
  -- construct name of the atom: 'string<n>'
    local dim = n
           
    -- if the dim is a CONST, use its value for validation
    if 'table' == type(n) and 
       'nil' ~= n[MODEL] and 
       Data.CONST == n[MODEL][Data.KIND] then
       dim = n()
    end
     
    -- validate the dimension
    if nil ~= dim then
      assert(type(dim)=='number', 
               table.concat{'invalid string capacity: ', tostring(n)})
      assert(dim > 0, 
             table.concat{'string capacity must be > 0: ', tostring(n)})
        name = table.concat{name, '<', Data.fqname(n), '>'}
    end
            
  -- lookup the atom name in the builtin module
  local instance = Data.builtin[name]
  if nil == instance then
    -- not found => create it
    instance = Data.atom()
    Data.builtin[name] = instance -- install it in the builtin module
  end  
  
  return instance
end 

--- string of length n (i.e. string<n>) is an Atom
-- @function string 
-- @param #number n the maximum length of the string
-- @return #table the string data model instance
function Data.string(n)
  return _.string(n, 'string')
end

--- wstring of length n (i.e. string<n>) is an Atom
-- @function wstring 
-- @param #number n the maximum length of the wstring
-- @return #table the string data model instance
function Data.wstring(n)
  return _.string(n, 'wstring')
end

-- collection() - helper method to define collections, i.e. sequences and arrays
function _.collection(annotation, n, ...)

  -- ensure that we have an array of positive numbers
  local dimensions = {...}
  table.insert(dimensions, 1, n) -- insert n at the begining
  for i, v in ipairs(dimensions) do
    local dim = v
         
    -- if the dim is a CONST, validate its value
    if 'table' == type(v) and 
       'nil' ~= v[MODEL] and 
       Data.CONST == v[MODEL][Data.KIND] then
       dim = v()
    end
   
    -- check if the 'dim' is valid
    assert(type(dim)=='number',  
      table.concat{'invalid collection bound: ', tostring(dim)})
    assert(dim > 0 and dim - math.floor(dim) == 0, -- positive integer  
      table.concat{'collection bound must be > 0: ', dim})
  end
  
  -- return the predefined annotation instance, whose attributes are 
  -- the collection dimension bounds
  return annotation[MODEL][Data.DEFN](dimensions)
end

-- Arrays and Sequences are implemented as a special annotations, whose 
-- attributes are positive integer constants, that specify the dimension bounds
-- NOTE: Since an array or a sequence is an annotation, it can appear anywhere 
--       after a member type declaration; the 1st one is used
Data.builtin.Array = Data.annotation{}
Data.ARRAY = Data.builtin.Array[MODEL]
function Data.array(n, ...)
  return _.collection(Data.builtin.Array, n, ...)
end

Data.builtin.Sequence = Data.annotation{}
Data.SEQUENCE = Data.builtin.Sequence[MODEL]
function Data.sequence(n, ...)
  return _.collection(Data.builtin.Sequence, n, ...)
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

--- For some model elements, the IDL display string is not the same as the model
-- element name. This table maps to the corresponding display string in IDL.
-- #map<#table, #string>

_.IDL_DISPLAY = {
  -- [model element]                 = "Display string in IDL"
  [Data.builtin.long_double]         = "long double",
  [Data.builtin.long_long]           = "long long",
  [Data.builtin.unsigned_short]      = "unsigned short",
  [Data.builtin.unsigned_long]       = "unsigned long",
  [Data.builtin.unsigned_long_long]  = "unsigned long long",
  [Data.builtin.top_level]           = "top-level",
}

setmetatable(_.IDL_DISPLAY, {
    -- default: idl display string is the same as the model name
    __index = function(self, instance) 
        return instance[MODEL] and instance[MODEL][Data.NAME] or nil
    end
})

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
	assert('table' == type(instance), 
	       table.concat{'instance must be a table: "', tostring(instance), '"'})
	assert(instance[MODEL], 'invalid instance')

	local indent_string = indent_string or ''
	local content_indent_string = indent_string
	local model = instance[MODEL]
	local myname = model[Data.NAME]
	local mytype = model[Data.KIND]
	local mydefn = model[Data.DEFN]
		
	-- print('DEBUG print_idl: ', Data, model, mytype(), myname)
	
	-- skip: atomic types, annotations
	if Data.ATOM == mytype or
	   Data.ANNOTATION == mytype then 
	   return instance, indent_string 
	end
    
  if Data.CONST == mytype then
     local atom = mydefn
     print(string.format('%sconst %s %s = %s;', content_indent_string, 
                        _.IDL_DISPLAY[atom], 
                        myname, tostring(instance)))
     return instance, indent_string                              
  end
    
	if Data.TYPEDEF == mytype then
		local defn = mydefn	
    print(string.format('%s%s %s', indent_string,  mytype(),
                                    _.tostring_role(myname, defn)))
		return instance, indent_string 
	end
	
	-- open --
	if (nil ~= myname) then -- not top-level / builtin module
	
		-- print the annotations
		if nil ~=mydefn and nil ~= mydefn[Data.ANNOTATION] then
			for i, annotation in ipairs(mydefn[Data.ANNOTATION]) do
		      print(string.format('%s%s', indent_string, tostring(annotation)))
			end
		end
		
		if Data.UNION == mytype then
			print(string.format('%s%s %s switch (%s) {', indent_string, 
						mytype(), myname, model[Data.DEFN][Data.SWITCH][MODEL][Data.NAME]))
						
		elseif Data.STRUCT == mytype and model[Data.DEFN][Data.BASE] then -- base struct
			print(string.format('%s%s %s : %s {', indent_string, mytype(), 
					myname, model[Data.DEFN][Data.BASE][MODEL][Data.NAME]))
		
		else
			print(string.format('%s%s %s {', indent_string, mytype(), myname))
		end
		content_indent_string = indent_string .. '   '
	end
		
	if Data.MODULE == mytype then 
		for i, defn_i in ipairs(mydefn) do -- walk through the module definition
		  local role, role_defn = next(defn_i)
			Data.print_idl(role_defn, content_indent_string)
		end
		
	elseif Data.STRUCT == mytype then
	 
		for i, defn_i in ipairs(mydefn) do -- walk through the model definition
			if not defn_i[MODEL] then -- skip struct level annotations
			  local role, role_defn = next(defn_i)
        print(string.format('%s%s', content_indent_string,
                            _.tostring_role(role, role_defn)))
			end
		end

	elseif Data.UNION == mytype then 
		for i, defn_i in ipairs(mydefn) do -- walk through the model definition
			if not defn_i[MODEL] then -- skip union level annotations
				local case = defn_i[1]
				
				-- case
				if (nil == case) then
				  print(string.format("%sdefault :", content_indent_string))
				elseif (Data.char == model[Data.DEFN][Data.SWITCH] and nil ~= case) then
					print(string.format("%scase '%s' :", 
						content_indent_string, tostring(case)))
				else
					print(string.format("%scase %s :", 
						content_indent_string, tostring(case)))
				end
				
				-- member element
				local role, role_defn = next(defn_i, #defn_i > 0 and #defn_i or nil)
				print(string.format('%s%s', content_indent_string .. '   ',
				                             _.tostring_role(role, role_defn)))
			end
		end
		
	elseif Data.ENUM == mytype then
		for i, defn_i in ipairs(mydefn) do -- walk through the model definition	
			local role, ordinal = next(defn_i)
			if ordinal then
				print(string.format('%s%s = %s,', content_indent_string, role, 
								    ordinal))
			else
				print(string.format('%s%s,', content_indent_string, role))
			end
		end
	end
	
	-- close --
	if (nil ~= myname) then -- not top-level / builtin module
		print(string.format('%s};\n', indent_string))
	end
	
	return instance, indent_string
end


--- IDL string representation of a role
-- @function tostring_role
-- @param #string role role name
-- @param #list role_defn the definition of the role in the following format:
--           { template, [collection,] [annotation1, annotation2, ...] } 
-- @return #string IDL string representation of the idl member
function _.tostring_role(role, role_defn)

	local template, seq 
	if role_defn then
	  template = role_defn[1]
  	for i = 2, #role_defn do
  		if Data.SEQUENCE == role_defn[i][MODEL] then
  			seq = role_defn[i]
  			break -- 1st 'collection' is used
  		end
  	end
  end

	local output_member = ''		
  if nil == template then return output_member end

	if seq == nil then -- not a sequence
		output_member = string.format('%s %s', _.IDL_DISPLAY[template], role)
	elseif #seq == 0 then -- unbounded sequence
		output_member = string.format('sequence<%s> %s', _.IDL_DISPLAY[template], role)
	else -- bounded sequence
		for i = 1, #seq do
			output_member = string.format('%ssequence<', output_member) 
		end
		output_member = string.format('%s%s', output_member, _.IDL_DISPLAY[template])
		for i = 1, #seq do
			output_member = string.format('%s,%s>', output_member, Data.fqname(seq[i])) 
		end
		output_member = string.format('%s %s', output_member, role)
	end

	-- member annotations:	
	local output_annotations = nil
	for j = 2, #role_defn do
		
		local name = role_defn[j][MODEL][Data.NAME]
		
		if Data.ARRAY == role_defn[j][MODEL] then
			for i = 1, #role_defn[j] do
				output_member = string.format('%s[%s]', output_member, 
				                                 Data.fqname(role_defn[j][i])) 
			end
		elseif Data.SEQUENCE ~= role_defn[j][MODEL] then
			output_annotations = string.format('%s%s ', 
									                        output_annotations or '', 
									                        tostring(role_defn[j]))	
		end
	end

	if output_annotations then
		return string.format('%s; //%s', output_member, output_annotations)
	else
		return string.format('%s;', output_member)
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
	assert('table' == type_instance and instance[MODEL] or 
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
	local mytype = instance[MODEL][Data.KIND]
	local model = model or instance[MODEL]
	local mydefn = model[Data.DEFN]

	-- print('DEBUG index 1: ', mytype(), instance[MODEL][Data.NAME])
			
	-- skip if not an indexable type:
	if Data.STRUCT ~= mytype and Data.UNION ~= mytype then return nil end

	-- preserve the order of model definition
	local result = result or {}	-- must be a top-level type	
					
	-- union discriminator, if any
	if Data.UNION == mytype then
		table.insert(result, instance._d)
	end
		
	-- struct base type, if any
	local base = model[Data.DEFN][Data.BASE]
	if nil ~= base then
		result = Data.index(instance, result, base[MODEL])	
	end
	
	-- walk through the body of the model definition
	-- NOTE: typedefs don't have an array of members	
	for i, defn_i in ipairs(mydefn) do 		
		-- skip annotations
		if not defn_i[MODEL] then
			-- walk through the elements in the order of definition:
			
			local role
		  if Data.STRUCT == mytype then     
        role = next(defn_i)
      elseif Data.UNION == mytype then
        role = next(defn_i, #defn_i > 0 and #defn_i or nil)
      end
			
			local role_instance = instance[role]
			local role_instance_type = type(role_instance)
			-- print('DEBUG index 3: ', role, role_instance)

			if 'table' == role_instance_type then -- composite (nested)
					result = Data.index(role_instance, result)
			elseif 'function' == role_instance_type then -- sequence
				-- length operator
				table.insert(result, role_instance())
	
				-- index 1st element for illustration
				if 'table' == type(role_instance(1)) then -- composite sequence
					Data.index(role_instance(1), result) -- index the 1st element 
				elseif 'function' == type(role_instance(1)) then -- sequence of sequence
					Data.index(role_instance(1), result)
				else -- primitive sequence
					table.insert(result, role_instance(1))
				end
			else -- atom or enum (leaf)
				table.insert(result, role_instance) 
			end
		end
	end

	return result
end

--------------------------------------------------------------------------------
-- Inherit the builtin model elements
setmetatable(Data, {
    __index = Data.builtin
})

return Data
--------------------------------------------------------------------------------
