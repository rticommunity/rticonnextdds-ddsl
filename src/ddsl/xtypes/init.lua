--[[
  (c) 2005-2014 Copyright, Real-Time Innovations, All rights reserved.

 Permission to modify and use for internal purposes granted.
 This software is provided "as is", without warranty, express or implied.
--]]

--- Datatypes in Lua.
-- Uses the `ddsl` core primitives to implement datatypes (a.k.a. `xtypes`) as 
-- defined by the OMG X-Types specification in Lua. 
-- 
-- The datatypes are equivalent to those described by the [X-Types](
-- http://www.omg.org/spec/DDS-XTypes/) specification. Thus, this module 
-- can serve as an alternative for defining types in Lua, instead of in [IDL](
-- https://en.wikipedia.org/wiki/Interface_description_language) or XML.
-- 
-- A datatype is a blueprint for a data structure. Any
-- number of data-objects or instances (a.k.a. `xinstance`) can be created 
-- from a datatype. Each instance is backed by the underlying datatype from 
-- which it was created. The datatype constraints are enforced on the 
-- instances---for example a `struct` instance can only have the fields defined
-- in the `struct` datatype; sequence and array bounds are enforced. 
-- Furthermore, if the datatype structure changes, those changes are propagated
-- to all the instances.
-- 
-- Operators to manipulate datatypes (i.e. structure) are also provided. Thus, 
-- for a `struct` datatype, new members can be added, existing ones can be 
-- removed or modified. Since every instance is backed by a datatype, any
-- instance can be used as a handle to manipulate the underlying datatype. 
-- Changes are propagated to all the other instances, to ensure consistency.
-- 
-- Since every instance is backed by a datatype, a new instance can be created
-- from any instance using `new_instance`. A datatype constructor returns 
-- a *template instance* (a.k.a. `xtemplate`) that can be used as cannonical 
-- instance to refer to the datatype.  
-- 
-- Each field in the template instance is 
-- initialized to a flattened out accessor `string` that can be used retrive 
-- that field's value in some storage system. For example, the accessor strings 
-- can be directly used for data access in Lua scripts used with the 
-- *RTI Connext DDS Prototyper* (see **Section 8.4, Data Access API** in the 
-- [RTI Connext DDS Prototyper Getting Started Guide](
-- https://community.rti.com/static/documentation/connext-dds/5.2.0/doc/manuals/connext_dds/prototyper/RTI_ConnextDDS_CoreLibraries_Prototyper_GettingStarted.pdf)).
-- 
-- 
-- **General Syntax**
--
-- Since `ddsl` does not impose any specific syntax on how datatypes are
-- expressed in Lua, this module defines the syntax. The general syntax and 
-- patterns common to all datatypes are illsurated below.
--
--    local xtypes = require 'ddsl.xtypes'
--  
--    -- create a datatype of kind 'kind' with the name 'MyType'
--    -- NOTE: `mytype` is the template instance for `MyType` (i.e. `xtemplate`)
--    local mytype = xtypes.<kind>{
--       MyType = { <definition_syntax_for_kind> }
--    }
--    
--
--    -- create an instance to use in user application code
--    local myinstance = xtypes.`new_instance`(mytype)
--    
--    -- print the datatype underlying an instance
--    print(tostring(myinstance)) -- or simply
--    print(myinstance) 
--    
--    
--    -- get the template instance
--    assert(xtypes.`template`(myinstance) == mytype)
--    
--    
--    -- print the kind of a datatype
--    -- NOTE: the kind is immutable, i.e. cannot be changed after creation
--    print(mytype[xtypes.`KIND`]())
--
--  
--    -- get the name of a datatype
--    print(mytype[xtypes.`NAME`])
--
--    -- set the name of a datatype
--    mytype[xtypes.`NAME`] = 'MyTypeNewName'
--
--
--    -- get the enclosing namespace of a datatype
--    print(mytype[xtypes.`NS`])
--
--    -- set the enclosing namespace of a datatype
--    mytype[xtypes.`NS`] = `YourType` -- defined elsewhere; maybe `nil`
--    
--    
--    -- get the qualifiers associated with a datatype
--    print(mytype[xtypes.`QUALIFIERS`])
--
--    -- set the qualifiers associated with a datatype
--    mytype[xtypes.`QUALIFIERS`] = { 
--      xtypes.`Nested`, 
--      xtypes.`Extensibility`{'FINAL_EXTENSIBILITY'},
--    }
--    
--    -- Get the qualified name (i.e. scoped name) of a datatype:
--    print(xtypes.`nsname`(mytype)
--  
--    -- Get the outermost enclosing scope of a datatype:
--    print(xtypes.`nsroot`(mytype)
--  
-- The datatype constructors provide more usage examples, specific to each type.
--
-- @module ddsl.xtypes
-- @alias xtypes.builtin
-- @author Rajive Joshi

local xtypes = {

  --- Datatype Kinds.
  -- 
  -- Use these to get and set the corresponding datatype attribute.
  -- @usage
  --  -- get the kind of a datatype
  --  print(mytype[`KIND`]()) -- evaluate the kind to get the description
  -- 
  --  -- use the kind of a datatype to make decisions
  --  if `STRUCT` == mytype[`KIND`] then 
  --    ... 
  --  else
  --    ...
  --  end
  -- @section Kind
  
  --- Annotation kind.
  -- @treturn string 'annotation'
  ANNOTATION = function() return 'annotation' end,
  
  --- Atom kind.
  -- @treturn string 'atom'
  ATOM       = function() return 'atom' end,
  
  --- Ennumeration kind.
  -- @treturn string 'enum'
  ENUM       = function() return 'enum' end,
  
  --- Struct kind.
  -- @treturn string 'struct'
  STRUCT     = function() return 'struct' end,
  
  --- Union kind.
  -- @treturn string 'union'
  UNION      = function() return 'union' end,

  --- Typedef kind.
  -- @treturn string 'typedef'
  TYPEDEF    = function() return 'typedef' end,
  
  --- Constant kind.
  -- @treturn string 'const'
  CONST      = function() return 'const' end,
  
  --- Module kind.
  -- @treturn string 'module'
  MODULE     = function() return 'module' end,
  
  --- @section end
  
  
  --==========================================================================--

  --- Concrete X-Types model info interface.
  -- @local
  info = {},

  --- Meta-tables that define/control the Public API for the X-Types.
  -- @local
  API = {},
  
  --- Builtins.
  -- @local
  builtin = {},
}

--============================================================================--
-- Local bindings for selected DDSL functionality

-- Instantiate the DDSL core, using the 'info' interface defined here:
local _ = require('ddsl')(xtypes.info)

local log                = _.log

--- `ddsl.EMPTY`: Empty datatype definition for use as initializer in 
-- datatype constructors.
-- @usage
--  local xtypes = require 'ddsl.xtypes'
--  
--  -- create an empty datatype of kind 'kind' with the name 'MyType'
--  local mytype = xtypes.<kind>{
--     MyType = EMPTY
--  }
--  @table EMPTY
local EMPTY             = _.EMPTY

--- Datatype Attributes.
-- 
-- Use these to get and set the corresponding datatype attribute.
-- @usage
--  -- get the name of a datatype
--  print(mytype[NAME])
--       
--  -- set the name of a datatype
--  mytype[NAME] = 'MyTypeNewName' 
-- @section DatatypeAttributes

--- `ddsl.KIND`: Datatype kind. 
-- @function KIND
local KIND               = _.KIND

--- `ddsl.NAME`: Datatype name.
-- @function NAME
local NAME               = _.NAME

--- `ddsl.NS`: Datatype enclosing namespace (enclosing scope).
-- @function NS
local NS                 = _.NS

--- `ddsl.QUALIFIERS`: Datatype qualifiers (annotations).
-- @function QUALIFIERS
local QUALIFIERS         =  _.QUALIFIERS

--- Datatype of the base `struct` (inheritance)
-- @treturn string ' : '
-- @function BASE
local BASE              = function() return ' : ' end

--- Datatype of a `union` discriminator (switch).
-- @treturn string 'switch'
-- @function SWITCH
local SWITCH            = function() return 'switch' end

--- @section end
  
--============================================================================--
-- DDSL info interface implementation for X-Types

--- Is the given model element a qualifier?
-- NOTE: collections are qualifiers
-- @xinstance value the model element to check
-- @treturn xinstance the value (qualifier), or nil if it is not a qualifier
-- @function info.is_qualifier_kind
-- @local
function xtypes.info.is_qualifier_kind(value)
  local kind = _.kind(value)
  return (xtypes.ANNOTATION == kind)
         and value
         or nil
end

--- Is the given model element a collection?
-- @xinstance value the model element to check
-- @treturn xinstance the value (collection), or nil if it is not a collection
-- @function info.is_collection_kind
-- @local
function xtypes.info.is_collection_kind(value)
  local model = _.model(value)
  return (xtypes.ARRAY == model or
          xtypes.SEQUENCE == model)
         and value
         or nil
end

--- Is the given model element an alias (for another type)?
-- @xinstance value the model element to check
-- @treturn xinstance the value (alias), or nil if it is not an alias
-- @function info.is_alias_kind
-- @local
function xtypes.info.is_alias_kind(value)
  local kind = _.kind(value)
  return (xtypes.TYPEDEF == kind)
         and value
         or nil
end

--- Is the given model element a leaf (ie primitive) type?
-- @xinstance value the model element to check
-- @treturn xinstance the value (leaf), or nil if it is not a leaf type
-- @function info.is_leaf_kind
-- @local
function xtypes.info.is_leaf_kind(value)
  local kind = _.kind(value)
  return (xtypes.ATOM == kind or
          xtypes.ENUM == kind)
         and value
         or nil
end

--- Is the given model element a template type?
-- @xinstance value the model element to check
-- @treturn xinstance the value (template), or nil if it is not a template type
-- @function info.is_template_kind
-- @local
function xtypes.info.is_template_kind(value)
  local kind = _.kind(value)
  return (xtypes.ATOM == kind or
          xtypes.ENUM == kind or
          xtypes.STRUCT == kind or
          xtypes.UNION == kind or
          xtypes.TYPEDEF == kind)
        and value
        or nil
end

--============================================================================--
-- Helpers --

--- Ensure that we have a valid declaration, and if so, split it into a 
-- name and an underlying definition.
-- @tparam {[string]=...} decl a table containing at least one {name=defn} 
--   entry where *name* is a string model name
--   and *defn* is a table containing the definition.
-- @treturn string name
-- @treturn table  defn
-- @local
function xtypes.parse_decl(decl)
  -- pre-condition: decl is a table
  assert('table' == type(decl),
    table.concat{'parse_decl(): invalid declaration: ', tostring(decl)})

  local name, defn = next(decl)

  assert('string' == type(name),
    table.concat{'parse_decl(): invalid model name: ', tostring(name)})

  assert('table' == type(defn),
  table.concat{'parse_decl(): invalid model definition: ', tostring(defn)})

  return name, defn
end

--============================================================================--
-- Qualifiers --

--- Datatype Qualifiers.
-- @section DatatypeQualifiers

-- Annotations --

--- Create an annotation.
-- Annotations qualify a datatype or a member of the datatype. Except for 
-- `array` and `sequence` qualifiers, annotation contents are opaque to 
-- DDSL; they are kept intact and may be interpreted in the user's context.
-- @tparam {[string]=...} decl a table containing an annotation name and 
--  definition, where ...  are the optional *default* attributes 
--  of the annotation.
-- @treturn table an annotation datatype template (`xtemplate`)
-- @usage
--  -- Create user defined annotation @MyAnnotation(value1 = 42, value2 = 42.0)
--  local MyAnnotation = xtypes.`annotation`{
--     MyAnnotation = {value1 = 42, value2 = 9.0} -- default attributes
--  }
--
--  -- Use user defined annotation with custom attributes
--  MyAnnotation{value1 = 942, value2 = 999.0}
--  
--  -- Print the annotation contents (value1, value2)
--  for k, v in pairs(MyAnnotation) do
--    print(k, v)
--  end
--  
--  -- Use builtin annotation `Key`
--  xtypes.Key
--
--  -- Use builtin annotation `Extensibility`
--  xtypes.Extensibility{'EXTENSIBLE_EXTENSIBILITY'}  
function xtypes.annotation(decl)
  local name, defn = xtypes.parse_decl(decl)

  -- create the template
  local template = _.new_template(name, xtypes.ANNOTATION,
                                  xtypes.API[xtypes.ANNOTATION])
  local model = _.model(template)

  -- annotation definition function (closure)
  -- NOTE: the attributes passed to the annotation are not interpreted,
  --       and are kept intact; we simply add the MODEL definition
  --   A function that returns a model table, with user defined
  --   annotation attributes passed as a table of {name = value} pairs
  --      eg: xtypes.MyAnnotation{value1 = 42, value2 = 42.0}
  model[_.DEFN] = function (attributes) -- parameters to the annotation
    if attributes then
      assert('table' == type(attributes),
        table.concat{'table with {name=value, ...} attributes expected: ',
                   tostring(attributes)})
    end
    local instance = attributes ~= EMPTY and attributes or template
    setmetatable(instance, model)
    -- not caching the instance in model[_.INSTANCES] because we don't need it
    return instance
  end

  -- initialize template with the attributes
  template = template(defn)

  return template
end

-- Annotations API meta-table
xtypes.API[xtypes.ANNOTATION] = {

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

    local model = _.model(annotation)
    if output then
      output = string.format('@%s(%s)', model[NAME] or '', output)
    else
      output = string.format('@%s', model[NAME] or '')
    end

    return output
  end,

  __index = function (template, key)
    local model = _.model(template)
    return model[key]
  end,

  __newindex = function (template, key, value)
  -- immutable: do-nothing
  end,

  -- create an annotation instance
  __call = function(template, ...)
    local model = _.model(template)
    return model[_.DEFN](...)
  end
}


-- Collections: Arrays & Sequences --

-- Arrays are implemented as a special annotations, whose
-- attributes are positive integer constants, that specify the dimension bounds
-- NOTE: Since an array is an annotation, it can appear anywhere
--       after a member type declaration; the 1st one is used
local array = xtypes.annotation{array=EMPTY}
xtypes.ARRAY = _.model(array)

--- Create an array qualifier with the specified dimensions.
-- Ensures that a valid set of dimension values is passed in. Returns the
-- array datatype qualifier, initialized with the specified dimensions.
-- An array qualifier is interpreted by DDSL as a *collection* qualifier.
-- @int n the first dimension
-- @param ... the remaining dimensions
-- @treturn table the array qualifier instance (`xtemplate`)
function xtypes.array(n, ...)
  return xtypes.make_collection_qualifier(array, n, ...)
end

-- Sequences are implemented as a special annotations, whose
-- attributes are positive integer constants, that specify the dimension bounds
-- NOTE: Since a sequence is an annotation, it can appear anywhere
--       after a member type declaration; the 1st one is used
local sequence = xtypes.annotation{sequence=EMPTY}
xtypes.SEQUENCE = _.model(sequence)

--- Create a sequence qualifier with the specified dimensions.
-- Ensures that a valid set of dimension values is passed in. Returns the
-- sequence datatype qualifier, initialized with the specified dimensions.
-- A sequence qualifier is interpreted by DDSL as a *collection* qualifier.
-- @int n the first dimension
-- @param ... the remaining dimensions
-- @treturn table the sequence qualifier instance (`xtemplate`)
function xtypes.sequence(n, ...)
  return xtypes.make_collection_qualifier(sequence, n, ...)
end

--- @section end

--- Make a collection qualifier instance.
-- Ensures that a valid set of dimension values is passed in. Returns the
-- annotation instance, initialized with the specified dimensions.
--
-- NOTE: a new annotation instance is created for each call. There may be
-- room for optimization by caching the annotation instances.
--
-- @xinstance annotation the underlying annotation ARRAY or SEQUENCE
-- @int n the first dimension
-- @param ... the remaining dimensions
-- @treturn table the qualifier annotation instance describing the collection
-- @local
function xtypes.make_collection_qualifier(annotation, n, ...)

  -- ensure that we have an array of positive numbers
  local dimensions = {...}
  table.insert(dimensions, 1, n) -- insert n at the beginning
  for i, v in ipairs(dimensions) do
    local dim = v

    -- if the dim is a CONST, use its value for validation
    if  xtypes.CONST == _.kind(v) then
       dim = v()
    end

    -- check if the 'dim' is valid
    if not(type(dim)=='number') then
      error(table.concat{'invalid collection bound: ', tostring(dim)}, 2)
    end
    if not(dim > 0 and dim - math.floor(dim) == 0) then -- positive integer
      error(table.concat{'collection bound must be an integer > 0: ', dim}, 2)
    end
  end

  -- return the predefined annotation instance, whose attributes are
  -- the collection dimension bounds
  return annotation(dimensions)
end

--============================================================================--
-- Atoms --

--- Create an atomic datatype.
-- There are two kinds of atomic types:
-- 
--   - un-dimensioned
--   - dimensioned, e.g. bounded size/length (e.g. `string`<n>)
--   
-- @tparam {[string]=EMPTY|{int}|const} decl a table containing an atom name
--  mapped to and `EMPTY` initializer (for undimensioned atoms) or a a table 
--  containing an integral *dimension* (for dimensioned atoms). The dimension 
--  could also be an integral `const` datatype.
-- @treturn table an atom datatype template (`xtemplate`)
-- @usage
--  -- Create an un-dimensioned atomic datatype named 'MyAtom':
--  local MyAtom = xtypes.atom{
--    MyAtom = EMPTY
--  }
--
--  -- Create a dimensioned atomic type:
--  local string10 = xtypes.atom{string={10}}        -- bounded length string
--  local wstring10 = xtypes.atom{wstring={10}}      -- bounded length wstring
-- 
--  -- Create a dimensioned atomic type, where 'MAXLEN' is a `const`:
--  local StringMaxlen = xtypes.atom{string=MAXLEN} -- bounded length string
-- @within Datatypes
function xtypes.atom(decl)
  local name, defn = xtypes.parse_decl(decl)
  local dim, dim_kind = defn[1], _.kind(defn[1])

  -- pre-condition: validate the dimension
  local dim_value = xtypes.CONST == dim_kind and dim() or dim
  if nil ~= dim then
    if type(dim_value) ~='number' then
      error(table.concat{'invalid dimension: ',tostring(dim), ' = ', dim_value},
            2)
    end
    if not(dim_value > 0 and dim_value - math.floor(dim_value) == 0) then
      error(table.concat{'dimension must be an integer > 0: ', tostring(dim)},
            2)
    end
  end

  -- build up the atom template name:
  if xtypes.CONST == dim_kind then
    name = table.concat{name, '<', _.nsname(dim), '>'}
  elseif nil ~= dim then
    name = table.concat{name, '<', tostring(dim), '>'}
  end

  -- lookup the atom name in the builtins
  local template = xtypes.builtin[name]
  if nil == template then
    -- not found => create it
    local model
    template, model = _.new_template(name, xtypes.ATOM, xtypes.API[xtypes.ATOM])
    model[_.DEFN][1] = dim -- may be nil
    xtypes.builtin[name] = template -- NOTE: install it in the builtin module
  end

  return template
end


-- Atom API meta-table
xtypes.API[xtypes.ATOM] = {

  __tostring = function(template)
    -- the name or the kind (if no name has been assigned)
    local model = _.model(template)
    return model[NAME] or
           model[KIND]() -- evaluate the function
  end,

  __index = function (template, key)
    local model = _.model(template)
    return model[key]
  end,

  __newindex = function (template, key, value)
    -- immutable: do-nothing
  end
}


--============================================================================--
-- Enums --

--- Create an enum datatype.
-- @tparam {[string]={string,string,[string]=int,[string]=int,...} decl a 
--  table containing an enum name mapped to a table (which is an array of 
--  strings or a map of strings to ordinal values, or a mix of both). 
--  For example,
--     { MyEnum = { { str1 = ord1 }, { str2 = ord2 }, ... } }
--  or  
--     { MyEnum = { str1, str2, ... } }
--  or a mix of the above
--     { MyEnum = { strA, strB, { str1 = ord1 }, { str2 = ord2 }, ... } }
-- @treturn table an enum datatype template  (`xtemplate`)
--   The table is a map of enumerator strings to their ordinal values.
-- @usage
--  -- Create enum: declarative style
--  local MyEnum = xtypes.`enum`{
--    MyEnum = {
--          { role_1 = ordinal_1 },
--          :
--          { role_M = ordinal_M },
--
--          -- OR --
--
--          role_A,
--          :
--          role_Z,
--
--          -- OPTIONAL --
--          `annotation`_x,
--          :
--          `annotation`_z,
--    }
--  }
--  
--  -- Create enum: imperative style (start with `EMPTY`)
--  MyEnum = xtypes.`enum`{
--    MyEnum = xtypes.`EMPTY`
--  }  
--
--
--  -- Get the i-th member:
--  print(table.unpack{MyEnum[i]}) -- role_i, ordinal_i
--   
--  -- Set the i-th member:
--  MyEnum[i] = { new_role_i = new_ordinal_i }
--  -- OR --
--  MyEnum[i] = role -- `ordinal` value = #MyEnum
--
--  -- After setting the i-th member, the following post-conditions hold:
--  MyEnum.role_i     == ordinal_i
--  MyEnum(ordinal_i) == role_i
--
--  -- Delete the i-th member:
--  MyEnum[i] = nil
--  
--  
--  -- Get the number of enumerators in the enum:
--  print(#MyEnum)
-- 
--  -- Iterate over the model definition (ordered):
--  for i = 1, #MyEnum do print(table.unpack(MyEnum[i])) end
--
--  -- Iterate over enum and ordinal values (unordered):
--  for k, v in pairs(MyEnum) do print(k, v) end
--  
--  -- Lookup the enumerator name for an ordinal value:
--  print(MyEnum(ordinal)) -- role
-- @within Datatypes
function xtypes.enum(decl)
  local name, defn = xtypes.parse_decl(decl)

  -- create the template
  local template = _.new_template(name, xtypes.ENUM, xtypes.API[xtypes.ENUM])

  -- populate the template
  return _.populate_template(template, defn)
end

-- Enum API meta-table
xtypes.API[xtypes.ENUM] = {

  __tostring = function(template)
    -- the name or the kind (if no name has been assigned)
    local model = _.model(template)
    return model[NAME] or
           model[KIND]() -- evaluate the function
  end,

  __len = function (template)
    local model = _.model(template)
    return #model[_.DEFN]
  end,

  __index = function (template, key)
    local model = _.model(template)
      
    local value = model[key]
    if value then -- does the model have it? (KIND, NAME, NS)
      return value
      
    elseif 'number' == type(key) then -- get from the model definition and pack
       -- enumerator, ordinal_value
       local enumerator, ordinal = next(model[_.DEFN][key]) 
       return table.pack(enumerator, ordinal)
 
    else -- delegate to the model definition
      return model[_.DEFN][key]
    end
  end,

  __newindex = function (template, key, value)

    local model = _.model(template)
    local model_defn = model[_.DEFN]

    if NAME == key then -- set the model name
      rawset(model, NAME, value)

    elseif QUALIFIERS == key then -- annotation definition
      -- set the new qualifiers in the model definition (may be nil)
      model_defn[QUALIFIERS] = _.assert_qualifier_array(value)

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
          table.concat{template[NAME] or '', 
                       ' : invalid member name: ', tostring(role)})

        -- ensure the definition is an ordinal value
        assert('number' == type(role_defn) and
               math.floor(role_defn) == role_defn, -- integer
        table.concat{template[NAME] or '', 
                      ' : invalid definition: ',
                      tostring(role), ' = ', tostring(role_defn) })

        -- is the role already defined?
        assert(nil == rawget(template, role),-- check template
          table.concat{template[NAME] or '', 
                       ' : member name already defined: "', role, '"'})

        -- insert the new role
        rawset(template, role, role_defn)

        -- insert the new member definition
        model_defn[key] = {
          [role] = role_defn   -- map with one entry
        }
      end
    end
  end,
  
  -- Lookup the enumerator string, given an ordinal value
  -- @param ordinal[in] the ordinal value
  -- @param the enumerator string or 'nil' if it is not a valid ordinal value
  __call = function(template, ordinal)
    for k, v in pairs(template) do
      if v == ordinal then return k end
    end
    return nil 
  end,
}

--============================================================================--
-- Structs --

--- Create a struct datatype.
-- @tparam {[string]={[string]={...},{[string]={...},...} decl a table 
--  containing a struct name mapped  to a table (which is an array of strings
--  mapped to member definitions). For example,
--    { MyStruct = { { role1 = {...}, { role2 = {...} }, ... } }
--  where the member definition for a role is,
--    { role = { xtemplate, [array | sequence,] [annotation, ...] } }
-- @treturn table a struct datatype template (`xtemplate`).  
--   The table is a map of the role names to flattened out strings that 
--   represent the path from the enclosing top-level struct scope to the role. 
--   The string values may be be used to retrieve the field values from 
--   some storage system.
-- @usage
--  -- Create struct: declarative style
--  local MyStruct = xtypes.`struct`{
--    MyStruct = { 
--      [<optional base `struct`>], -- base `struct` must be the 1st item
--    
--      {role_1={xtemplate_1, [`array`_1|`sequence`_1,] [`annotation`_1,...]}},
--        :
--      {role_M={xtemplate_M, [`array`_M|`sequence`_M,] [`annotation`_M,...]}},
--      
--      -- OPTIONAL --
--      `annotation`_x,
--       :
--      `annotation`_z,
--    }
--  }
--
--  -- OR Create struct: imperative style (start with base `struct` or `EMPTY`)
--  local MyStruct = xtypes.`struct`{
--    MyStruct = { <optional base `struct`> } | xtypes.`EMPTY`
--  }
--  
--  
--  -- Get the i-th member:
--  print(table.unpack(MyStruct[i])) -- role_i, value_i
-- 
--  -- Set the i-th member:
--  MyStruct[i] = { new_role = { new_xtemplate, 
--                                [new_`array` | new_`sequence`,] 
--                                [new_`annotation`, ...] } }
--  
--  -- After setting the i-th member, the following post-condition holds:
--  -- NOTE: also holds for roles defined in the base `struct` datatype
--  MyStruct.role == 'prefix.enclosing.scope.path.to.role'
--  
--  -- Delete the i-th member:
--  MyStruct[i] = nil
--
--
--  -- Get the base class:
--   print(MyStruct[xtypes.`BASE`])
--   
--  -- Set base class:
--   MyStruct[xtypes.`BASE`] = `YourStruct` -- defined elsewhere
--
--
--  -- Get the number of members in the struct (not including base struct):
--  print(#MyStruct)
--  
--  -- Iterate over the model definition (ordered):
--  -- NOTE: does NOT show the roles defined in the base `struct` datatype
--  for i = 1, #MyStruct do print(table.unpack(MyStruct[i])) end
--
--  -- Iterate over instance members and the indexes (unordered):
--  -- NOTE: shows roles defined in the base `struct` datatype
--  for k, v in pairs(MyStruct) do print(k, v) end
-- @within Datatypes
function xtypes.struct(decl)
  local name, defn = xtypes.parse_decl(decl)

  -- create the template
  local template, model = _.new_template(name, xtypes.STRUCT,
                                               xtypes.API[xtypes.STRUCT])
  model[_.INSTANCES] = {}

  -- OPTIONAL base: pop the next element if it is a base model element
  local base
  if xtypes.STRUCT == _.kind(_.resolve(defn[1])) then
    base = defn[1]   table.remove(defn, 1)

    -- insert the base class:
    template[BASE] = base -- invokes the meta-table __newindex()
  end

  -- populate the template
  return _.populate_template(template, defn)
end

-- Struct API meta-table
xtypes.API[xtypes.STRUCT] = {

  __tostring = function(template)
    -- the name or the kind (if no name has been assigned)
    local model = _.model(template)
    return model[NAME] or
           model[KIND]() -- evaluate the function
  end,

  __len = function (template)
    local model = _.model(template)
    return #model[_.DEFN]
  end,

  __index = function (template, key)
    local model = _.model(template)
    
    local value = model[key]
    if value then -- does the model have it? (KIND, NAME, NS)
      return value
      
    elseif 'number' == type(key) then -- get from the model definition and pack
      local role, roledef = next(model[_.DEFN][key])
      
      -- role, template, [collection,] [annotation1, annotation2, ...]
      return table.pack(role, table.unpack(roledef))
 
    else -- delegate to the model definition
      return model[_.DEFN][key]
    end
  end,

  __newindex = function (template, key, value)

    local model = _.model(template)
    local model_defn = model[_.DEFN]

    if NAME == key then -- set the model name
      rawset(model, NAME, value)

    elseif QUALIFIERS == key then -- annotation definition
      -- set the new qualifiers in the model definition (may be nil)
      model_defn[QUALIFIERS] = _.assert_qualifier_array(value)

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

        -- is the role already defined?
        assert(nil == rawget(template, role),-- check template
          table.concat{template[NAME] or '', 
                       ' : member name already defined: "', role, '"'})
  
        -- create role instance (checks for pre-conditions, may fail!)
        local role_instance = _.create_role_instance(role, role_defn)
  
        -- update instances: add the new role_instance
        _.update_instances(model, role, role_instance)
  
        -- insert the new member definition
        local role_defn_copy = {} -- make our own local copy
        for i, v in ipairs(role_defn) do role_defn_copy[i] = v end
        model_defn[key] = {
          [role] = role_defn_copy   -- map with one entry
        }
      end

    elseif BASE == key then -- inherits from 'base' struct

      -- clear the instance fields from the old base struct (if any)
      local old_base = _.resolve(model_defn[BASE])
      while old_base do
        for k, v in pairs(old_base) do
          if 'string' == type(k) then -- copy only the base instance fields
            -- update instances: remove the old_base role
            _.update_instances(model, k, nil) -- clear the role
          end
        end

        -- template is no longer an instance of the base struct
        local old_base_model = _.model(old_base)
        old_base_model[_.INSTANCES][template] = nil

        -- visit up the base model inheritance hierarchy
        old_base = _.resolve(old_base[BASE]) -- parent base
      end

      -- get the base model, if any:
      local new_base
      if nil ~=value and 
         _.assert_kind(xtypes.STRUCT, _.resolve(value)) then
        new_base = value
      end

      -- populate the instance fields from the base model struct
      local base = new_base
      while base do
        local base_model = _.model(_.resolve(base)) -- base may be a typedef
        for i = 1, #base_model[_.DEFN] do
          local base_role, base_role_defn = next(base_model[_.DEFN][i])

          -- is the base_role already defined?
          assert(nil == rawget(template, base_role),-- check template
            table.concat{template[NAME] or '', 
                         ' : member name already defined: "', base_role, '"'})

          -- create base role instance (checks for pre-conditions, may fail)
          local base_role_instance =
            _.create_role_instance(base_role, base_role_defn)


          -- update instances: add the new base_role_instance
          _.update_instances(model, base_role, base_role_instance)
        end

        -- visit up the base model inheritance hierarchy
        base = base_model[_.DEFN][BASE] -- parent base
      end

      -- set the new base in the model definition (may be nil)
      model_defn[BASE] = new_base

      -- template is an instance of the base structs (inheritance hierarchy)
      base = new_base
      while base do
        local base_model = _.model(_.resolve(base)) -- base may be a typedef

        -- NOTE: Use empty string as the 'instance' name of the base struct
        base_model[_.INSTANCES][template] = '' -- empty instance name

        -- visit up the base model inheritance hierarchy
        base = base_model[_.DEFN][BASE] -- parent base
      end

    else
        -- accept the key if it is defined in the model definition
        -- e.g. could have been an optional member that was removed
        for i = 1, #model_defn do
          if key == next(model_defn[i]) then
              rawset(template, key, value)
          end
        end
    end
  end
}

--============================================================================--
-- Unions --

--- Create a union datatype.
-- @tparam {[string]={xtemplate,{case,[string]={...}},...} decl a table 
--  containing a union name mapped to a table as follows.
--    { 
--      MyUnion = { 
--          xtemplate,
--          { case1, [ role1 = {...} ] }, 
--          { case2, [ role2 = {...} ] }, 
--          ... 
--          { nil,   [ role2 = {...} ] } -- default
--      }
--    }
--  where the member definition for a role is,
--    { role = { xtemplate, [array | sequence,] [annotation, ...] } }
-- @treturn table an union datatype template (`xtemplate`).
--   The table is a map of the role names to flattened out strings that 
--   represent the path from the enclosing top-level union scope to the role.
--   The string values may be be used to retrieve the field values from 
--   some storage system.
-- @usage
--  -- Create union: declarative style
--  local MyUnion = xtypes.`union`{
--    MyUnion = {
--      <discriminator `atom` or `enum`>,  -- must be the 1st item
--
--      { case1,
--        [{role_1={xtemplate_1,[`array`_1|`sequence`_1,][`annotation`_1,...]}}]
--      },
--        :
--      { caseM,
--        [{role_M={xtemplate_M,[`array`_M|`sequence`_M,][`annotation`_M,...]}}]
--      },
--
--      { nil, -- default
--        [{role={xtemplate,[`array`|`sequence`,][`annotation`,...]}}]
--
--      -- OPTIONAL --
--      `annotation`_x,
--       :
--      `annotation`_z,
--    }
--  }
--  
--  -- OR Create union: imperative style (start with `EMPTY`)
--  local MyUnion = xtypes.`union`{
--    MyUnion = { <discriminator `atom` or `enum`> }
--  }
--
--  -- Get the i-th member:
--  print(table.unpack(MyUnion[i])) -- role_i, value_i
-- 
--  -- Set the i-th member:
--   MyUnion[i] = { case, [ { role = { xtemplate, 
--                                      [`array` | `sequence`,] 
--                                      [`annotation`, ...] } } ] },
--                                      
--  -- After setting the i-th member, the following post-condition holds:
--  MyStruct.role == 'prefix.enclosing.scope.path.to.role'
--
--  -- Delete the i-th member:
--  MyUnion[i] = nil  
--
--  
--  -- Get the discriminator:
--   print(MyUnion[xtypes.`SWITCH`])
--
--  -- Set the discriminator:
--   MyUnion[xtypes.`SWITCH`] = <discriminator `atom` or `enum`>
--
-- -- After setting the discriminator, the following post-condition holds:
--  MyUnion._d == '#'
--
--  
-- -- Get the number of members in the union:
--  print(#MyUnion)
--  
--  -- Iterate over the model definition (ordered):
--  for i = 1, #MyUnion do print(table.unpack(MyUnion[i])) end
--
--  -- Iterate over instance members and the indexes (unordered):
--  for k, v in pairs(MyUnion) do print(k, v) end
--  
-- -- Retrieve the currectly selected member
-- NOTE: i.e. the member selected by current discriminator value, `MyUnion._d`
-- print(MyUnion()) -- may be `nil`
-- @within Datatypes
function xtypes.union(decl)
  local name, defn = xtypes.parse_decl(decl)

  -- create the template
  local template, model = _.new_template(name, xtypes.UNION,
                                               xtypes.API[xtypes.UNION])
  model[_.INSTANCES] = {}

 	-- pop the discriminator
	template[SWITCH] = defn[1] -- invokes meta-table __newindex()
  table.remove(defn, 1)

  -- populate the template
  return _.populate_template(template, defn)
end

-- Union API meta-table
xtypes.API[xtypes.UNION] = {

  __tostring = function(template)
    -- the name or the kind (if no name has been assigned)
    local model = _.model(template)
    return model[NAME] or
           model[KIND]() -- evaluate the function
  end,

  __len = function (template)
    local model = _.model(template)
    return #model[_.DEFN]
  end,

  __index = function (template, key)
    local model = _.model(template)
    
    local value = model[key]
    if value then -- does the model have it? (KIND, NAME, NS)
      return value
      
    elseif 'number' == type(key) then -- get from the model definition and pack
      local case = model[_.DEFN][key][1]
      local role, roledef = next(model[_.DEFN][key], 1) -- case and 1 or nil)
                         -- next(member, #member > 0 and #member or nil)
      
       -- case, role, template, [collection,] [annotation1, annotation2, ...]
      if roledef then 
        return table.pack(case, role, table.unpack(roledef))
      else
        return table.pack(case) -- just the case, no member
      end
 
    else -- delegate to the model definition
      return model[_.DEFN][key]
    end
  end,

  __newindex = function (template, key, value)

    local model = _.model(template)
    local model_defn = model[_.DEFN]

    if NAME == key then -- set the model name
      model[NAME] = value

    elseif QUALIFIERS == key then -- annotation definition
      -- set the new qualifiers in the model definition (may be nil)
      model_defn[QUALIFIERS] = _.assert_qualifier_array(value)

    elseif SWITCH == key then -- switch definition

      local discriminator = value
  
      -- pre-condition: ensure discriminator is of a valid type
      xtypes.assert_case(discriminator, nil)-- nil => validate discriminator

      -- pre-condition: ensure that 'cases' are compatible with discriminator
      for i, v in ipairs(model_defn) do
        xtypes.assert_case(discriminator, v[1])
      end

      -- update the discriminator
      model[_.DEFN][SWITCH] = discriminator
      rawset(template, '_d', '#')

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
        local case = xtypes.assert_case(model_defn[SWITCH], value[1])

        -- is the case already defined?
        for i, defn_i in ipairs(model_defn) do
          assert(case ~= defn_i[1],
            table.concat{template[NAME] or '', 
                         ' : case exists: "', tostring(case), '"'})
        end

        -- get the role and definition
        local role, role_defn = next(value, 1) -- 2nd item after the 'case'

          -- add the role
        if role then

          -- is the role already defined?
          assert(nil == rawget(template, role),-- check template
            table.concat{template[NAME] or '', 
                        ' : member name already defined: "', role, '"'})

          local role_instance = _.create_role_instance(role, role_defn)

          -- insert the new member definition
          local role_defn_copy = {} -- make our own local copy
          for i, v in ipairs(role_defn) do role_defn_copy[i] = v end
          model_defn[key] = {
            case,                     -- array of length 1
            [role] = role_defn_copy   -- map with one entry
          }

          -- update instances: add the new role_instance
          _.update_instances(model, role, role_instance)
        else
          model_defn[key] = {
            case,         -- array of length 1
          }
        end
      end

    else
        -- accept the key if it is a discriminator value:
        if '_d' == key then 
          rawset(template, key, value) 
          
        -- accept the key if it is defined in the model definition
        -- e.g. could have been an optional member that was removed
        else
          for i = 1, #model_defn do
            if key == next(model_defn[i]) then
                rawset(template, key, value)
            end
          end
        end
    end
  end,
  
  -- Get the selected member
  -- @param the selected member, based on the current discriminator value _d,
  --        or 'nil' if the discriminator does not match any case
  __call = function(template)
    local model = _.model(template)
    
    for i, v in ipairs(model[_.DEFN]) do
      if template._d == v[1] then 
        local role = next(v, 1)
        return template[role]
      end
    end
    return nil -- no match 
  end,
}

--- Ensure that case and discriminator are valid and compatible, and if so, 
-- return the case value to use.
-- The input case value may be converted to the correct type required 
-- by the discriminator.
-- @xinstance discriminator a discriminator datatype
-- @param case a case value
-- @return nil if the discriminator or the case is not valid or if the case is
--   not compatible with the discriminator; otherwise the (coverted) case 
--   value to use.
-- @local  
function xtypes.assert_case(discriminator, case)
  local err_msg
  if nil == case then 
    err_msg = table.concat{'invalid union discriminator: "', 
                                              tostring(discriminator), '"' }
  else
    err_msg = table.concat{'invalid union case: "', tostring(case), '"'}
  end

  -- resolve the discriminator to the underlying type:
  local discriminator = _.resolve(discriminator)

  -- enum
  if xtypes.ENUM == discriminator[KIND] then -- enum
    assert(nil == case or nil ~= discriminator(case), 
      err_msg)

  -- boolean
  elseif xtypes.builtin.boolean == discriminator then 
    if 'false' == case or '0' == case then 
      case = false
    elseif 'true' == case or '1' == case then 
      case = true
    end
    assert(nil == case or true == case or false == case, 
      err_msg)

  -- character
  elseif xtypes.builtin.char == discriminator or 
    xtypes.builtin.wchar == discriminator then 
    assert(nil == case or 
      'string' == type(case) and 1 == string.len(case) or
      math.floor(tonumber(case)) == tonumber(case), -- ordinal value
      err_msg)

  -- integral signed
  elseif xtypes.builtin.octet == discriminator or 
    xtypes.builtin.short == discriminator or
    xtypes.builtin.long == discriminator or
    xtypes.builtin.long_long == discriminator then
    local int_case = tonumber(case)
    assert(nil == case or 
           nil ~= int_case and math.floor(int_case) == int_case, 
          err_msg)
    case = int_case
    
  -- integral unsigned
  elseif xtypes.builtin.unsigned_short == discriminator or
    xtypes.builtin.unsigned_long == discriminator or
    xtypes.builtin.unsigned_long_long == discriminator then
    local uint_case = tonumber(case)
    assert(nil == case or
           nil ~= uint_case and math.floor(uint_case) == uint_case
           and uint_case >= 0, 
      err_msg)
    case = uint_case
    
  else -- invalid
    assert(false, err_msg)
  end

  return case
end

--============================================================================--
-- Typedefs --

--- Create a typedef `alias` datatype.
-- Typedefs are aliases for underlying datatypes.
-- @tparam {[string]={xtemplate,[array|sequence,][annotation,...]}} decl a table
-- containing a typedef mapped to an array as follows.
--    { MyTypedef = { xtemplate, [array | sequence,] [annotation, ...] } }
-- where `xtemplate` is the underlying type definition, optionally followed by
-- and `array` or `sequence` qualifiers to specify the multiplicity, 
-- optionally followed by annotations.
-- @treturn table an typedef datatype template (`xtemplate`).
-- @usage
--  -- Create a typedef datatype:
--  local MyTypedef = xtypes.`typedef`{
--    MyTypedef = { `xtemplate`, [`array` | `sequence`,] [`annotation`, ...] }
--  } 
-- 
--  -- Retreive the typedef definition
--  print(MyTypedef()) -- `xtemplate`, [`array` | `sequence`]
-- 
--  -- Resolve a typedef to the underlying non-typedef datatype and a list 
--  -- of collection qualifiers
--  print(xtypes.`resolve`(MyTypedef)) 
-- 
-- 
--  -- Example: typedef sequence<MyStruct> MyStructSeq
--  local MyStructSeq = xtypes.`typedef`{
--    MyStructSeq = { xtypes.MyStruct, xtypes.`sequence`() }
--  }
--  
--  print(MyStructSeq()) --     MyStruct     @sequence(10)
--
--
--  -- Example: typedef MyStruct MyStructArray[10][20]
--  local MyStructArray = xtypes.`typedef`{
--    MyStructArray = { xtypes.MyStruct, xtypes.`array`(10, 20) }
--  }
--  
--  print(MyStructArray()) --   MyStruct     @array(10, 20)
-- @within Datatypes
function xtypes.typedef(decl)
  local name, defn = xtypes.parse_decl(decl)

  -- pre-condition: ensure that the 1st defn element is a valid type
  local alias = defn[1]
  _.assert_template_kind(alias)

  -- pre-condition: ensure that the 2nd defn element if present
  -- is a 'collection' kind
  local collection_qualifier = defn[2]
  if collection and not xtypes.info.is_collection_kind(collection) then
    error(table.concat{'expected sequence or array, got: ', tostring(value)},
          2)
  end

  -- create the template
  local template, model = _.new_template(name, xtypes.TYPEDEF,
                                               xtypes.API[xtypes.TYPEDEF])
  model[_.DEFN] = { alias, collection_qualifier }
  return template
end

-- Atom API meta-table
xtypes.API[xtypes.TYPEDEF] = {

  __tostring = function(template)
    -- the name or the kind (if no name has been assigned)
    local model = _.model(template)
    return model[NAME] or
           model[KIND]() -- evaluate the function
  end,

  __index = function (template, key)
    local model = _.model(template)    
    return model[key]
  end,

  __newindex = function (template, key, value)
    -- immutable: do-nothing
  end,

  -- alias and collection information is obtained by evaluating the table:
  -- @return alias, collection_qualifier
  -- eg: my_typedef()
  __call = function(template)
    local model = _.model(template)
    return model[_.DEFN][1], model[_.DEFN][2] -- datatype, collection_qualifier
  end,
}

--============================================================================--
-- Constants --

--- Create a constant.
-- @tparam {[string]={atom,value}} decl a table containing a constant name
--   mapped to an array containing an `atom` and a value of the atom datatype.
--   NOTE: this method will try to convert the value to the correct type,
--   if not already so (for example, if the value is a string).
-- @treturn table a constant.
-- @usage
--  -- Create a constant datatype
--  local MY_CONST = xtypes.`const`{
--    MY_CONST = { `atom`, <const_value> }
--  }
--
--  -- Get the const value and the underlying atomic datatype
--  print(MY_CONST()) --    value      `atom`
--
--
--  -- Examples:
--  local MAXLEN = xtypes.`const`{
--    MAXLEN = { xtypes.short, 128 }
--  }
--  print(MAXLEN()) -- 128  short
-- 
--  local PI = xtypes.`const`{
--    PI = { xtypes.`double`, 3.14 }
--  }
--  print(PI()) -- 3.14  double
-- 
--  local MY_STRING = xtypes.`const`{
--    MY_STRING = { xtypes.`string`(128), "My String Constant" }
--  }
--  print(MY_STRING()) -- My String Constant      string<128>
-- 
-- 
--  -- Use a const datatype
--  local MyStringSeq =  xtypes.`typedef`{
--    MyStringSeq = { xtypes.`string`, xtypes.`sequence`(MAXLEN) }
--  }
-- @within Datatypes
function xtypes.const(decl)
  local name, defn = xtypes.parse_decl(decl)

  -- pre-condition: ensure that the 1st defn declaration is a valid type
  local atom = _.assert_kind(xtypes.ATOM, _.resolve(defn[1]))

  -- pre-condition: ensure that the 2nd defn declaration is a valid value
  local value = defn[2]
  assert(nil ~= value,
         table.concat{name, ' : const value must be non-nil: ',
                      tostring(value)})

  -- convert value to the correct type:
  local coercedvalue = nil
  if xtypes.builtin.boolean == atom then
      if 'boolean' ~= type(value) then
          if 'false' == value or '0' == value then coercedvalue = false
          elseif 'true' == value or '1' == value then coercedvalue = true
          else coercedvalue = not not value -- toboolean
          end
          if nil ~= coercedvalue then
             log.info(table.concat{name, 
                                ' : converting to boolean: "', value,
                                '" -> ', tostring(coercedvalue)})
          else
             log.notice(table.concat{name, 
                                ' : converting to boolean: "', value,
                                '" -> nil'})
          end
      end
  elseif xtypes.string() == atom or
         xtypes.wstring() == atom or
         xtypes.builtin.char == atom then
      if 'string' ~= type(value) then
          coercedvalue = tostring(value)
          if nil ~= coercedvalue then
             log.info(table.concat{name, ' : converting to string: "', value,
                                '" -> "', coercedvalue, '"'})
          else
             log.notice(table.concat{name, 
                                ' : converting to string: "', value,
                                '" -> nil'})
          end
      end
  elseif xtypes.builtin.short == atom or
         xtypes.builtin.unsigned_short == atom or
         xtypes.builtin.long == atom or
         xtypes.builtin.unsigned_long == atom or
         xtypes.builtin.long_long == atom or
         xtypes.builtin.unsigned_long_long == atom or
         xtypes.builtin.float == atom or
         xtypes.builtin.double == atom or
         xtypes.builtin.long_double == atom then
      if 'number' ~= type(value) then
          coercedvalue = tonumber(value)
          if nil ~= coercedvalue then
             log.info(table.concat{name, ' : converting to number: "', value,
                                '" -> ', coercedvalue})
          else
             log.notice(table.concat{name, 
                                ' : converting to number: "', value,
                                '" -> nil'})
          end
      end
  end
  if nil ~= coercedvalue then value = coercedvalue end

  local model = _.model(atom)
  if xtypes.builtin.unsigned_short == atom or
     xtypes.builtin.unsigned_long == atom or
     xtypes.builtin.unsigned_long_long == atom then
     if value < 0 then
       log.notice(table.concat{name, 
                        ' : const value of "', value, ' of type "',
                        type(value),
                        '" must be non-negative and of the type: ',
                        model[NAME] or ''})
     end
  end

  -- char: truncate value to 1st char; warn if truncated
  if (xtypes.builtin.char == atom or xtypes.builtin.wchar == atom) and
      #value > 1 then
    value = string.sub(value, 1, 1)
    log.notice(table.concat{name, ' : truncating string value for ',
                                  model[NAME] or '',
                                  ' constant to: ', value})
  end

  -- integer: truncate value to integer; warn if truncated
  if (xtypes.builtin.short == atom or xtypes.builtin.unsigned_short == atom or
      xtypes.builtin.long == atom or xtypes.builtin.unsigned_long == atom or
      xtypes.builtin.long_long == atom or
      xtypes.builtin.unsigned_long_long == atom) and
      'number' == type(value) and
      value - math.floor(value) ~= 0 then
    value = math.floor(value)
    log.notice(table.concat{name, 
                   ' : truncating decimal value for integer constant',
                   ' to: ', value})
  end

  -- create the template
  local template, model =
                   _.new_template(name, xtypes.CONST, xtypes.API[xtypes.CONST])
  model[_.DEFN] = { atom, value } -- { atom, value [,expression] }
  return template
end


-- Const API meta-table
xtypes.API[xtypes.CONST] = {

  __tostring = function(template)
    local model = _.model(template)
    return model[NAME] or
           model[KIND]() -- evaluate the function
  end,

  __index = function (template, key)
    local model = _.model(template)
    return model[key]
  end,

  __newindex = function (template, key, value)
    -- immutable: do-nothing
  end,

  -- instance value and datatype is obtained by evaluating the table:
  -- eg: MY_CONST()
  __call = function(template)
    local model = _.model(template)
    return model[_.DEFN][2], model[_.DEFN][1] -- value, datatype
  end,
}

--============================================================================--
-- Modules --

--- Create a module namespace.
-- A module is an name-space for holding (enclosing) datatypes.
-- @tparam {[string]={xtemplate,...} decl  a table containing a module name 
--   mapped to an array of datatypes (`xtemplate`)  
-- @treturn table a module namespace.
--   The table is a map of the datatype names to `xtemplate` canonical 
--   instances. 
-- @usage
--    -- Create module: declarative style
--    local MyModule = xtypes.`module`{
--      MyModule = {
--        xtypes.`const`{...},
--        :
--        xtypes.`enum`{...},
--        :
--        xtypes.`struct`{...},
--        :
--        xtypes.`union`{...},
--        :
--        xtypes.`typedef`{...},
--        :
--        xtypes.`module`{...}, -- nested module name-space
--        :
--      }
--    }
--    
--  -- Create module: imperative style (start with `EMPTY`)
--  local MyModule = xtypes.`module`{
--    MyModule = xtypes.EMPTY
--  }
--
--  -- Get the i-th member:
--  print(MyModule[i])
--   
--  -- Set the i-th member:
--  MyModule[i] = `xtemplate`
--  
--  -- After setting the i-th member, the following post-condition holds:
--  MyModule.name == `xtemplate` -- where: name = `xtemplate`[xtypes.`NAME`]
--
--  -- Delete the i-th member:
--  MyModule[i] = nil  
--
--
-- -- Get the number of members in the module:
--  print(#MyModule)
--  
--  -- Iterate over the module definition (ordered):
--  for i = 1, #MyModule do print(MyModule[i]) end
--
--  -- Iterate over module namespace (unordered):
--  for k, v in pairs(MyModule) do print(k, v) end
-- @within Datatypes
function xtypes.module(decl)
  local name, defn = xtypes.parse_decl(decl)

  --create the template
  local template = _.new_template(name, xtypes.MODULE,
                                  xtypes.API[xtypes.MODULE])

  -- populate the template
  return _.populate_template(template, defn)
end

-- Module API meta-table
xtypes.API[xtypes.MODULE] = {

  __tostring = function(template)
    -- the name or the kind (if no name has been assigned)
    local model = _.model(template)
    return model[NAME] or
           model[KIND]() -- evaluate the function
  end,

  __len = function (template)
    local model = _.model(template)
    return #model[_.DEFN]
  end,

  __index = function (template, key)
    local model = _.model(template)
    
    local value = model[key]
    if value then -- does the model have it? (KIND, NAME, NS)
      return value
      
    else -- delegate to the model definition
      return model[_.DEFN][key]
    end
  end,

  __newindex = function (template, key, value)

    local model = _.model(template)
    local model_defn = model[_.DEFN]

    if NAME == key then -- set the model name
      rawset(model, NAME, value)

    elseif QUALIFIERS == key then -- annotation definition
      -- set the new qualifiers in the model definition (may be nil)
      model_defn[QUALIFIERS] = _.assert_qualifier_array(value)

    elseif 'number' == type(key) then -- member definition
      -- clear the old member definition and instance fields
      if model_defn[key] then
        local old_role_model = _.model(model_defn[key])
        local old_role = old_role_model[NAME]

        -- update namespace: remove the old_role
        rawset(template, old_role, nil)
      end

      -- set the new member definition
      if nil == value then
        -- nil => remove the key-th member definition
        table.remove(model_defn, key) -- do not want holes in array

      else
        --  Format:
        --    role_template

        -- pre-condition: value must be a model instance (template)
        assert(nil ~= _.kind(value),
               table.concat{template[NAME] or '', 
                      ' : invalid template: ', tostring(value)})

        local role_template = value
        local role = role_template[NAME]

        -- is the role already defined?
        assert(nil == rawget(template, role),
          table.concat{template[NAME] or '', 
                       ' : member name already defined: "', role, '"'})

				-- update the module definition
        model_defn[key] = role_template

        -- move the model element to this module
        local role_model = _.model(role_template)
        role_model[NS] = template

        -- update namespace: add the role
        rawset(template, role, role_template)
      end
    end
  end,
}

--============================================================================--
-- Built-in atomic types

--- Builtin Datatypes.
-- Builtin *atomic* datatypes.
-- @section BuiltinTypes

--- boolean.
xtypes.builtin.boolean = xtypes.atom{boolean=EMPTY}

--- octet.
xtypes.builtin.octet = xtypes.atom{octet=EMPTY}

--- char.
xtypes.builtin.char= xtypes.atom{char=EMPTY}

--- wide char.
xtypes.builtin.wchar = xtypes.atom{wchar=EMPTY}

--- float.
xtypes.builtin.float = xtypes.atom{float=EMPTY}

--- double.
xtypes.builtin.double = xtypes.atom{double=EMPTY}

--- long double.
xtypes.builtin.long_double = xtypes.atom{['long double']=EMPTY}

--- short.
xtypes.builtin.short = xtypes.atom{short=EMPTY}

--- long.
xtypes.builtin.long = xtypes.atom{long=EMPTY}

--- long long.
xtypes.builtin.long_long = xtypes.atom{['long long']=EMPTY}

--- unsigned short.
xtypes.builtin.unsigned_short = xtypes.atom{['unsigned short']=EMPTY}

--- unsigned long.
xtypes.builtin.unsigned_long = xtypes.atom{['unsigned long']=EMPTY}

--- unsigned long long.
xtypes.builtin.unsigned_long_long = xtypes.atom{['unsigned long long']=EMPTY}


-- strings and wstrings --

--- `string<n>`: string of length n.
-- @int n the maximum length of the string
-- @treturn xtemplate the string datatype
function xtypes.string(n)
  return xtypes.atom{string={n}} --NOTE: installed as xtypes.builtin.wstring<n>
end

--- `wstring<n>`:wstring of length n.
-- @int n the maximum length of the wstring
-- @treturn xtemplate the wstring datatype
function xtypes.wstring(n)
  return xtypes.atom{wstring={n}} --NOTE: installed as xtypes.builtin.wstring<n>
end

--- @section end

--============================================================================--
-- Built-in annotations

--- Builtin Annotations.
-- 
-- Use these to qualify the datatype structure. Some apply to datatypes,
-- while others apply to datatype members.
-- 
-- @section BuiltinAnnotations

--- Datatype member is a *key* field. `@Key`
xtypes.builtin.Key = xtypes.annotation{Key=EMPTY}

--- Datatype member id. `@ID{n}`
xtypes.builtin.ID = xtypes.annotation{ID=EMPTY}

--- Datatype member is optional. `@Optional`
xtypes.builtin.Optional = xtypes.annotation{Optional=EMPTY}

--- Datatype member is required. `@MustUnderstand`
xtypes.builtin.MustUnderstand = xtypes.annotation{MustUnderstand=EMPTY}

--- Datatype member is shared. `@Shared`
xtypes.builtin.Shared = xtypes.annotation{Shared=EMPTY}

--- `enum` datatype is bit-bound. `@BitBound{n}`
xtypes.builtin.BitBound = xtypes.annotation{BitBound=EMPTY}

--- `enum` datatype is a bit-set. `@BitSet`
xtypes.builtin.BitSet = xtypes.annotation{BitSet=EMPTY}

--- Datatype extensibility.
--  `@Extensibility{'EXTENSIBLE_EXTENSIBILITY'|'MUTABLE_EXTENSIBILITY'|'FINAL_EXTENSIBILITY}`
xtypes.builtin.Extensibility = xtypes.annotation{Extensibility=EMPTY}

--- Datatype is not top-level it is nexted. `@Nested`
xtypes.builtin.Nested = xtypes.annotation{Nested=EMPTY}

--- Datatype may (or may not) be top-level. `@top_level{false}`
xtypes.builtin.top_level = xtypes.annotation{['top-level']=EMPTY} -- legacy

--- @section end

--============================================================================--
-- xtypes public interface

return {
  --- `logger` to log messages and get/set the verbosity levels
  log                = log,

  EMPTY              = EMPTY,
  
  --==========================================================================--
  -- Datatype Attributes

  KIND               = KIND,
  NAME               = NAME,
  NS                 = NS,
  QUALIFIERS         = QUALIFIERS,  
  BASE               = BASE,
  SWITCH             = SWITCH,

  --==========================================================================--
  -- Datatype Operations
   
  --- `ddsl.nsname`: fully qualified name within the enclosing scope.
  -- @function nsname 
  nsname                  = _.nsname,

  --- `ddsl.nsroot`: outermost enclosing `root` namespace.
  -- @function nsroot 
  nsroot                  = _.nsroot,
  
  --- `ddsl.resolve`: resolve a typedef
  -- @function resolve 
  resolve                 = _.resolve,
  
  --- `ddsl.template`: get the *cannonical* template instance (`xtemplate`)
  -- @function template 
  template                = _.template,
  
  --- `ddsl.new_instance`: create a new instance (`xinstance`)
  -- @function new_instance
  new_instance            = _.new_instance,
  
  --- `ddsl.new_collection`: create a new collection of instances (`xinstances`)
  -- @function new_collection
  new_collection          = _.new_collection,
  
  --- `ddsl.is_collection`: is this a collection of instances (`xinstances`) ?
  -- @function is_collection
  is_collection           = _.is_collection,


  --==========================================================================--
  -- Datatype Kinds
  
  ANNOTATION         = xtypes.ANNOTATION,
  ATOM               = xtypes.ATOM,
  CONST              = xtypes.CONST,
  ENUM               = xtypes.ENUM,
  STRUCT             = xtypes.STRUCT,
  UNION              = xtypes.UNION,
  MODULE             = xtypes.MODULE,
  TYPEDEF            = xtypes.TYPEDEF,

  --==========================================================================--
  -- Datatypes
  -- NOTE: the doc comments are already exported for these items
 
   -- composite types
  const              = xtypes.const,
  enum               = xtypes.enum,
  struct             = xtypes.struct,
  union              = xtypes.union,
  module             = xtypes.module,

  -- typedefs (aliases)
  typedef            = xtypes.typedef,
  
  -- qualifiers
  annotation         = xtypes.annotation,
  array              = xtypes.array,
  sequence           = xtypes.sequence,

  -- pre-defined annotations
  Key                = xtypes.builtin.Key,
  Extensibility      = xtypes.builtin.Extensibility,
  ID                 = xtypes.builtin.ID,
  Optional           = xtypes.builtin.Optional,
  MustUnderstand     = xtypes.builtin.MustUnderstand,
  Shared             = xtypes.builtin.Shared,
  BitBound           = xtypes.builtin.BitBound,
  BitSet             = xtypes.builtin.BitSet,
  Nested             = xtypes.builtin.Nested,
  top_level          = xtypes.builtin.top_level,


  -- pre-defined atomic types
  boolean            = xtypes.builtin.boolean,

  octet              = xtypes.builtin.octet,
  char               = xtypes.builtin.char,
  wchar              = xtypes.builtin.wchar,

  float              = xtypes.builtin.float,
  double             = xtypes.builtin.double,
  long_double        = xtypes.builtin.long_double,

  short              = xtypes.builtin.short,
  long               = xtypes.builtin.long,
  long_long          = xtypes.builtin.long_long,

  unsigned_short     = xtypes.builtin.unsigned_short,
  unsigned_long      = xtypes.builtin.unsigned_long,
  unsigned_long_long = xtypes.builtin.unsigned_long_long,

  string             = xtypes.string,
  wstring            = xtypes.wstring,
}
