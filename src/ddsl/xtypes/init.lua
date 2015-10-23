--[[
  (c) 2005-2014 Copyright, Real-Time Innovations, All rights reserved.

 Permission to modify and use for internal purposes granted.
 This software is provided "as is", without warranty, express or implied.
--]]

--- Datatypes in Lua.
-- Uses the `ddsl` core primitives to implement datatypes (a.k.a. `xtypes`) as 
-- defined by the OMG X-Types specification in Lua. 
-- 
-- The datatypes are equivalent to those specified in OMG IDL. Thus, this 
-- module can serve as an alternative for defining types in Lua,instead of 
-- IDL or XML.
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
-- expressed in Lua, this module defines the syntax. The general pattern is:
--
--    local xtypes = require 'ddsl.xtypes'
--  
--    -- create a datatype of kind 'kind' with the name 'MyType'
--    local mytype = xtypes.<kind>{
--       MyType = { <definition_syntax_for_kind> }
--    }
--
-- The datatypes constructors provide more detail with usage examples.
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
  -- 
  -- @section Kind
  
  --- Annotation kind.
  -- @treturn string 'annotation'
  ANNOTATION = function() return 'annotation' end,
  
  --- Atom kind.
  -- @treturn string 'atom'
  ATOM       = function() return 'atom' end,
  
  --- Constant kind.
  -- @treturn string 'const'
  CONST      = function() return 'const' end,
  
  --- Ennumeration kind.
  -- @treturn string 'enum'
  ENUM       = function() return 'enum' end,
  
  --- Struct kind.
  -- @treturn string 'struct'
  STRUCT     = function() return 'struct' end,
  
  --- Union kind.
  -- @treturn string 'union'
  UNION      = function() return 'union' end,
  
  --- Module kind.
  -- @treturn string 'module'
  MODULE     = function() return 'module' end,
  
  --- Typedef kind.
  -- @treturn string 'typedef'
  TYPEDEF    = function() return 'typedef' end,
  
  --- @section end
  
  
  --==========================================================================--

  --- Concrete X-Types model info interface.
  -- @local
  info = {},

  --- Meta-tables that define/control the Public API for the X-Types.
  -- @local
  API = {},
  
  --- Builtins.
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

--- `ddsl.NS`: Datatype enclosing namespace (enclosing scope).
-- @function NS
local NS                 = _.NS

--- `ddsl.NAME`: Datatype name.
-- @function NAME
local NAME               = _.NAME

--- `ddsl.KIND`: Datatype kind. 
-- @function KIND
local KIND               = _.KIND

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
  local kind = _.model_kind(value)
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
  local kind = _.model_kind(value)
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
  local kind = _.model_kind(value)
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
  local kind = _.model_kind(value)
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
-- Annotations attributes are not interpreted; they are kept intact in the 
-- annotation datatype for retrieval later.
-- @tparam {[string]=...} decl a table containing an annotation declaration
--              { name = {...}  }
--  where ...  are the optional 'default' attributes of the annotation.
-- @treturn table an annotation datatype
-- @usage
--  local xtypes = require 'ddsl.xtypes'
--  
--  -- Create user defined annotation @MyAnnotation(value1 = 42, value2 = 42.0)
--  local MyAnnotation = xtypes.annotation{
--     MyAnnotation = {value1 = 42, value2 = 9.0} -- default attributes
--  }
--
--  -- Use user defined annotation with custom attributes
--  MyAnnotation{value1 = 942, value2 = 999.0}
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
-- @int n the first dimension
-- @param ... the remaining dimensions
-- @treturn table the array qualifier instance
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
-- @int n the first dimension
-- @param ... the remaining dimensions
-- @treturn table the sequence qualifier instance
function xtypes.sequence(n, ...)
  return xtypes.make_collection_qualifier(sequence, n, ...)
end

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
    if  xtypes.CONST == _.model_kind(v) then
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

--- @section end

--============================================================================--
-- Atoms --

--- Create an atomic type.
-- There are two kinds of atomic types:
--   - un-dimensioned
--   - dimensioned, e.g. bounded size/length (eg string)
--
-- @param decl  [in] a table with a name assigned to an empty table or
--              a table containing a size/length/dimension value
--                 un-dimensioned:
--                           { name = EMPTY }
--                 dimensioned:
--                         { name = {n} }
--                         { name = {const_defined_previously} }
--                   where n a dimension, e.g. max length
--        and 'name' specifies the underlying atom
--              e.g.: string | wstring
-- @return the atom template (an immutable table)
-- @usage
--  -- Create an un-dimensioned atomic type:
--  local MyAtom = xtypes.atom{MyAtom=EMPTY}
--
--  -- Create a dimensioned atomic type:
--  local string10 = xtypes.atom{string={10}}    -- bounded length string
--  local wstring10 = xtypes.atom{wstring={10}}  -- bounded length wstring
-- @within Datatypes
function xtypes.atom(decl)
  local name, defn = xtypes.parse_decl(decl)
  local dim, dim_kind = defn[1], _.model_kind(defn[1])

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
-- Constants --

--- Create a constant.
-- @param decl  [in] a table containing a constant declaration
--                   { name = { xtypes.atom, const_value_of_atom_type } }
--        NOTE: this method will try to convert the value to the correct type,
--              if not so already
-- @return the const template (an immutable table)
-- @usage
--  -- Create a constant type
--       local MY_CONST = xtypes.const{
--          MY_CONST = { xtypes.<atom>, <const_value> }
--       }
--
--  -- Examples
--       local PI = xtypes.const{
--          PI = { xtypes.double, 3.14 }
--       }
--
--       local MY_SHORT = xtypes.const{
--            MY_SHORT = { xtypes.short, 10 }
--       }
--
--       local MY_STRING = xtypes.const{
--          MY_STRING = { xtypes.string(), "String Constant" }
--       }
--
--       local MyStringSeq =  xtypes.typedef{
--             MyStringSeq = { xtypes.string, xtypes.sequence(MY_CONST) }
--       }
--       
--     Get the const value and the underlying atomic datatype
--          print( PI() ) -- 3.14  double
-- @within Datatypes
function xtypes.const(decl)
  local name, defn = xtypes.parse_decl(decl)

  -- pre-condition: ensure that the 1st defn declaration is a valid type
  local atom = _.assert_model_kind(xtypes.ATOM, _.resolve(defn[1]))

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
-- Enums --

--- Create an enum type
-- @param decl  [in] a table containing an enum declaration
--        { EnumName = { { str1 = ord1 }, { str2 = ord2 }, ... } }
--    or  { EnumName = { str1, str2, ... } }
--    or a mix of the above
-- @return The enum template. A table representing the enum data model.
-- The table fields  contain the string index to de-reference the enum's
-- constants in a top-level DDS Dynamic Data Type
-- @usage
--    -- Create enum: Declarative style
--    local MyEnum = xtypes.enum{
--      MyEnum = {
--          { role_1 = ordinal_value },
--          :
--          { role_M = ordinal_value },
--
--          -- OR --
--
--          role_A,
--          :
--          role_Z,
--
--          -- OPTIONAL --
--          annotation?,
--          :
--          annotation?,
--      }
--    }
--
-- -- Create enum: Declarative style
--   MyEnum = xtypes.enum{MyEnum=EMPTY}
--
--  -- Get | Set an annotation:
--   print(MyEnum[QUALIFIERS])
--   MyEnum[QUALIFIERS] = {
--        xtypes.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
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
--    for i = 1, #MyEnum do print(table.unpack(MyEnum[i])) end
--
--  -- Iterate over enum and ordinal values (unordered):
--    for k, v in pairs(MyEnum) do print(k, v) end
--  
--  -- Lookup the enumerator name for an ordinal value:
--     print(MyEmum(i))
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

--- Create a struct type
-- @param decl  [in] a table containing a struct declaration
--      { Name = { { role1 = {...}, { role2 = {...} }, ... } }
-- @return The struct template. A table representing the struct data model.
-- The table fields contain the string index to de-reference the struct's
-- value in a top-level DDS Dynamic Data Type
-- @usage
--   Structs:
--   { { role = { template, [collection_qualifier,] [annotation1, ...] } } }
-- 
--    -- Create struct: Declarative style
--    local MyStruct = xtypes.struct{
--      MyStruct = {OptionalBaseStruct,
--        { role_1 = { type, multiplicity?, annotation? } },
--        :
--        { role_M = { type, multiplicity?, annotation? } },
--        annotation?,
--         :
--        annotation?,
--      }
--    }
--
--  -- Create struct: Imperative style
--   local MyStruct = xtypes.struct{MyStruct={OptionalBaseStruct}|xtypes.EMPTY}
--
--  -- Get | Set an annotation:
--   print(MyStruct[QUALIFIERS])
--   MyStruct[QUALIFIERS] = {
--        xtypes.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
--        xtypes.Nested{'FALSE'},
--      }
--
--  -- Get | Set a member:
--   print(next(MyStruct[i]))
--   MyStruct[i] = { role = { type, multiplicity?, annotation? } },
--
--  -- Get | Set base class:
--   print(MyStruct[BASE])
--   MyStruct[BASE] = BaseStruct, -- optional
--
--
--  -- After either of the above definition, the following post-condition holds:
--    MyStruct.role == 'container.prefix.upto.role'
--
--
--  -- Iterate over the model definition (ordered):
--    for i = 1, #MyStruct do print(table.unpack(MyStruct[i])) end
--
--  -- Iterate over instance members and the indexes (unordered):
--    for k, v in pairs(MyStruct) do print(k, v) end
--    
-- @within Datatypes
function xtypes.struct(decl)
  local name, defn = xtypes.parse_decl(decl)

  -- create the template
  local template, model = _.new_template(name, xtypes.STRUCT,
                                               xtypes.API[xtypes.STRUCT])
  model[_.INSTANCES] = {}

  -- OPTIONAL base: pop the next element if it is a base model element
  local base
  if xtypes.STRUCT == _.model_kind(_.resolve(defn[1])) then
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
         _.assert_model_kind(xtypes.STRUCT, _.resolve(value)) then
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

--- Create a union type
-- @param decl  [in] a table containing a union declaration
--      { Name = {discriminator, { case, role = {...} }, ... } }
-- @return The union template. A table representing the union data model.
-- The table fields contain the string index to de-reference the union's value
-- in a top-level DDS Dynamic Data Type
-- @usage
--   Unions:
--    { { case, role = { template, [collection_qualifier,] [annotation1, ...] } } }
-- 
--    -- Create union: Declarative style
--    local MyUnion = xtypes.union{
--      MyUnion = {discriminator,
--        { case,
--         [ { role_1 = { type, multiplicity?, annotation? } } ] },
--        :
--        { case,
--         [ { role_M = { type, multiplicity?, annotation? } } ] },
--        { nil,
--         [ { role_Default = { type, multiplicity?, annotation? } } ] },
--        annotation?,
--         :
--       annotation?,
--      }
--    }
--
-- -- Create union: Imperative style
--   local MyUnion = xtypes.union{MyUnion={discriminator}}
--
--  -- Get | Set an annotation:
--   print(MyUnion[QUALIFIERS])
--   MyUnion[QUALIFIERS] = {
--        xtypes.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
--      }
--
--  -- Get | Set a member:
--   print(next(MyUnion[i]))
--   MyUnion[i] = { case, [ { role = { type, multiplicity?, annotation? } } ] },
--
--  -- Get | Set discriminator:
--   print(MyUnion[SWITCH])
--   MyUnion[SWITCH] = discriminator
--
--
--  -- After either of the above definition, the following post-condition holds:
--    MyUnion._d == '#'
--    MyUnion.role == 'container.prefix.upto.role'
--
--
--  -- Iterate over the model definition (ordered):
--    for i = 1, #MyUnion do print(table.unpack(MyUnion[i])) end
--
--  -- Iterate over instance members and the indexes (unordered):
--    for k, v in pairs(MyUnion) do print(k, v) end
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
-- the discriminator.
-- @xinstance discriminator a discriminator datatype
-- @param case a case value
-- @return nil if the discriminator or the case is not valid or if the case is
--   not compatible with the discriminator; otherwise the case value to use.
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
-- Modules --

--- Create a module
--
-- A module represents a name-space that holds various user defined types
-- @param decl  [in] a table containing a sequence of templates (model elements)
--      { Name = { const{...}, typedef{...}, enum{...},
--                 struct{...}, union{...}, module{...}, ... } }
-- @return The module template. A table representing the module data model.
-- The table fields contain the templates to produce string indices to
-- de-reference the **user-defined** data types
-- @usage
--    -- Create module: Declarative style
--    local MyModule = xtypes.module{
--      MyModule = {
--        -- templates ---
--        xtypes.const{...},
--        xtypes.typedef{...},
--        xtypes.enum{...},
--        xtypes.struct{...},
--        xtypes.union{...},
--        xtypes.module{...}, -- nested name-space
--        :
--      }
--    }
--  -- Create module: Imperative style
--   local MyModule = xtypes.module{MyModule=xtypes.EMPTY}
--
--  -- Get | Set a member:
--   print(MyModule[i])
--   MyModule[i] = template
--
--  -- After either of the above definition, the following post-condition holds:
--    MyModule.role == template
--  where 'role' is the name of the template
--
--  The the fully qualified name of the template includes the fully qualified
--  module name (i.e. nested within the module namespace hierarchy).
--
--  -- Iterate over the module definition (ordered):
--   for i = 1, #MyModule do print(MyModule[i]) end
--
--  -- Iterate over module namespace (unordered):
--   for k, v in pairs(MyModule) do print(k, v) end
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
        assert(nil ~= _.model_kind(value),
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
-- Typedefs --

--- Create a typedef.
--
-- Typedefs are aliases for underlying primitive or composite types
-- @param decl  [in] a table containing a typedef declaration
--      { name = { template, [collection_qualifier,]
--                           [annotation1, annotation2, ...] }  }
-- i.e. the underlying type definition and optional multiplicity and annotations
-- @return the typedef template
-- @usage
--   Typedefs:
--  { template, [collection_qualifier,] [annotation1, annotation2, ...] }
-- 
--  IDL: typedef sequence<MyStruct> MyStructSeq
--  Lua: local MyStructSeq = xtypes.typedef{
--            MyStructSeq = { xtypes.MyStruct, xtypes.sequence() }
--       }
--
--  IDL: typedef MyStruct MyStructArray[10][20]
--  Lua: local MyStructArray = xtypes.typedef{
--          MyStructArray = { xtypes.MyStruct, xtypes.array(10, 20) }
--       }
--       
--  Show the underlying datatype
--     print( MyStructSeq() )
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

  NS                 = NS,
  NAME               = NAME,
  KIND               = KIND,
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
