--[[
  (c) 2005-2014 Copyright, Real-Time Innovations, All rights reserved.     
                                                                           
 Permission to modify and use for internal purposes granted.               
 This software is provided "as is", without warranty, express or implied.
--]]
--[[
-----------------------------------------------------------------------------
 Purpose: Define X-Types in Lua using the DDSL (Data type definition Domain 
           Specific Language)
 Created: Rajive Joshi, 2014 Feb 14
-----------------------------------------------------------------------------
@module xtypes

SUMMARY

  OMG X-Types in Lua (using DDSL)

USAGE
  See the examples in ddsl-xtypes-tester.lua for user defined X-Types in Lua.
   
IMPLEMENTATION

  Note that DDSL does not impose any specific syntax on how the types are 
  expressed in Lua. This module defines the syntax. The general pattern is:
  
     { <name> = { <definition> } } 
  
  Each X-Type constructor is documented in detail, with examples.
  
  To illustrate, here are some role definitions:  
    Unions:
     { { case, role = { template, [collection,] [annotation1, ...] } } }
  
    Structs:
     { { role = { template, [collection,] [annotation1, annotation2, ...] } } }
  
    Typedefs:
     { template, [collection,] [annotation1, annotation2, ...] }
 
-----------------------------------------------------------------------------
--]]

--------------------------------------------------------------------------------
--- X-Types data model defined using the DDSL ---
--------------------------------------------------------------------------------

local xtypes = {

  -- X-types possible KIND values
  ANNOTATION = function() return 'annotation' end,
  ATOM       = function() return 'atom' end,
  CONST      = function() return 'const' end,
  ENUM       = function() return 'enum' end,
  STRUCT     = function() return 'struct' end,
  UNION      = function() return 'union' end,
  MODULE     = function() return 'module' end,
  TYPEDEF    = function() return 'typedef' end,
  
  -- X-types attributes
  BASE       = function() return ' : ' end,    -- inheritance, e.g. struct base
  SWITCH     = function() return 'switch' end, -- choice: e.g.: union switch
  
  -- Concrete X-Types model info interface
  info = {},
  
  -- Meta-tables that define/control the Public API for the X-Type templates
  API = {},
}

-- Instantiate the DDSL core, using the 'info' interface defined here:
local _ = require('ddsl')(xtypes.info)

--- Is the given model element a qualifier?
-- NOTE: collections are qualifiers
-- @param value [in] the model element to check
-- @return the value (qualifier), or nil if it is not a qualifier 
function xtypes.info.is_qualifier_kind(value)
  local kind = _.model_kind(value)
  return (xtypes.ANNOTATION == kind) 
         and value
         or nil
end

--- Is the given model element a collection?
-- @param value [in] the model element to check
-- @return the value (collection), or nil if it is not a collection
function xtypes.info.is_collection_kind(value)
  local model = _.model(value)
  return (xtypes.ARRAY == model or
          xtypes.SEQUENCE == model) 
         and value
         or nil
end

--- Is the given model element an alias (for another type)?
-- @param value [in] the model element to check
-- @return the value (alias), or nil if it is not an alias
function xtypes.info.is_alias_kind(value)
  local kind = _.model_kind(value)
  return (xtypes.TYPEDEF == kind) 
         and value 
         or nil
end

--- Is the given model element a leaf (ie primitive) type?
-- @param value [in] the model element to check
-- @return the value (leaf), or nil if it is not a leaf type
function xtypes.info.is_leaf_kind(value)
  local kind = _.model_kind(value)
  return (xtypes.ATOM == kind or 
          xtypes.ENUM == kind)
         and value
         or nil
end

--- --- Is the given model element a template type?
-- @param value [in] the model element to check
-- @return the value (template), or nil if it is not a template type
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

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

--- Split a decl into a name and defin after ensuring that we don't have an 
-- invalid declaration
-- @param decl [in] a table containing at least one {name=defn} entry 
--                where *name* is a string model name
--                and *defn* is a table containing the definition
-- @return name, def
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

--------------------------------------------------------------------------------
-- X-Types Model Definitions -- 
--------------------------------------------------------------------------------

--- Create an annotation
--  Annotations attributes are not interpreted, and kept intact 
-- @param decl  [in] a table containing an annotation declaration
--                 { name = {...}  }
--    where ...  are the optional 'default' attributes of the annotation
-- @return an annotation table
-- @usage
--   -- IDL @Key
--     xtypes.Key
--     xtypes.Key{GUID=N}
--     
--  --  IDL @Exensibility(EXTENSIBLE_EXTENSIBILITY)
--    xtypes.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
-- 
--  -- Create user defined annotation @MyAnnotation(value1 = 42, value2 = 42.0)
--    local MyAnnotation = xtypes.annotation{
--            MyAnnotation = {value1 = 42, value2 = 9.0}
--    }
--
--  -- Use user defined annotation with custom attributes
--    MyAnnotation{value1 = 942, value2 = 999.0}
--        
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
    local instance = attributes ~= _.EMPTY and attributes or template
    setmetatable(instance, model)
    -- not caching the instance in model[_.INSTANCES] because we don't need it
    return instance   
  end
  
  -- initialize template with the attributes
  template = template(defn)
 
  return template
end

--- Annotations API meta-table
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
      output = string.format('@%s(%s)', model[_.NAME], output)
    else
      output = string.format('@%s', model[_.NAME])
    end

    return output
  end,

  __index = function (template, key)
    local model = _.model(template)
    if _.NAME == key then
      return model[_.NAME]
    elseif _.KIND == key then
      return model[_.KIND]
    end
  end,
  
  __newindex = function (template, key, value)
  -- immutable: do-nothing
  end,

  __call = function(template, ...)
    local model = _.model(template)
    return model[_.DEFN](...)
  end
}

--------------------------------------------------------------------------------
-- Arrays

-- Arrays are implemented as a special annotations, whose 
-- attributes are positive integer constants, that specify the dimension bounds
-- NOTE: Since an array is an annotation, it can appear anywhere 
--       after a member type declaration; the 1st one is used
local array = xtypes.annotation{Array=_.EMPTY}
xtypes.ARRAY = _.model(array)

--- Create/use a array with specified dimensions
-- 
-- Ensures that a valid set of dimension values is passed in. Returns the 
-- array instance, initialized with the specified dimensions.
-- @param n [in] the first dimension
-- @param ... the remaining dimensions
-- @return the array data model
function xtypes.array(n, ...)
  return xtypes.make_collection(array, n, ...)
end

--------------------------------------------------------------------------------
-- Sequences

-- Sequences are implemented as a special annotations, whose 
-- attributes are positive integer constants, that specify the dimension bounds
-- NOTE: Since a sequence is an annotation, it can appear anywhere 
--       after a member type declaration; the 1st one is used
local sequence = xtypes.annotation{Sequence=_.EMPTY}
xtypes.SEQUENCE = _.model(sequence)

--- Create/use a sequence with specified dimensions
-- 
-- Ensures that a valid set of dimension values is passed in. Returns the 
-- sequence instance, initialized with the specified dimensions.
-- @param n [in] the first dimension
-- @param ... the remaining dimensions
-- @return the sequence data model
function xtypes.sequence(n, ...)
  return xtypes.make_collection(sequence, n, ...)
end

--------------------------------------------------------------------------------
--- make_collection
-- Ensure a collection (array or sequence) of the kind specified by the
-- underlying annotation, and retrieve an instance of it with the 
-- specified dimension attributes.
-- 
-- Ensures that a valid set of dimension values is passed in. Returns the 
-- annotation instance, initialized with the specified dimensions.
-- 
-- NOTE: a new annotation instance is created for each dimension. There may be
-- room for optimization by caching the annotation instances.
--  
-- @param annotation [in] the underlying annotation ARRAY or SEQUENCE
-- @param n [in] the first dimension
-- @param ... the remaining dimensions
-- @return the annotation instance describing the collection
function xtypes.make_collection(annotation, n, ...)

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

--------------------------------------------------------------------------------

xtypes.builtin = xtypes.builtin or {}

--- Built-in annotations
xtypes.builtin.Key = xtypes.annotation{Key=_.EMPTY}
xtypes.builtin.Extensibility = xtypes.annotation{Extensibility=_.EMPTY}
xtypes.builtin.ID = xtypes.annotation{ID=_.EMPTY}
xtypes.builtin.Optional = xtypes.annotation{Optional=_.EMPTY}
xtypes.builtin.MustUnderstand = xtypes.annotation{MustUnderstand=_.EMPTY}
xtypes.builtin.Shared = xtypes.annotation{Shared=_.EMPTY}
xtypes.builtin.BitBound = xtypes.annotation{BitBound=_.EMPTY}
xtypes.builtin.BitSet = xtypes.annotation{BitSet=_.EMPTY}
xtypes.builtin.Nested = xtypes.annotation{Nested=_.EMPTY}
xtypes.builtin.top_level = xtypes.annotation{['top-level']=_.EMPTY} -- legacy  

--------------------------------------------------------------------------------

--- Create an atomic type
-- 
-- There are two kinds of atomic types:
--   - un-dimensioned
--   - dimensioned, e.g. bounded size/length (eg string)
--
-- @param decl  [in] a table with a name assigned to an empty table or 
--              a table containing a size/length/dimension value
--                 un-dimensioned:
--                           { name = _.EMPTY }
--                 dimensioned:
--                         { name = {n} }
--                         { name = {const_defined_previously} }
--                   where n a dimension, e.g. max length  
--        and 'name' specifies the underlying atom
--              e.g.: string | wstring
-- @return the atom template (an immutable table)
-- @usage
--  -- Create an un-dimensioned atomic type:
--     local MyAtom = xtypes.atom{MyAtom=_.EMPTY}
--     
--  -- Create a dimensioned atomic type:
--     local string10 = xtypes.atom{string={10}}    -- bounded length string
--     local wstring10 = xtypes.atom{wstring={10}}  -- bounded length wstring
function xtypes.atom(decl)
  local name, defn = xtypes.parse_decl(decl)
  local dim, dim_kind = defn[1], _.model_kind(defn[1])
 
  -- pre-condition: validate the dimension
  local dim_value = xtypes.CONST == dim_kind and dim() or dim
  if nil ~= dim then
    if type(dim_value) ~='number' then
      error(table.concat{'invalid dimension: ', tostring(dim)}, 2)
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


--- Atom API meta-table
xtypes.API[xtypes.ATOM] = {

  __tostring = function(template)
    -- the name or the kind (if no name has been assigned)
    local model = _.model(template)
    return model[_.NAME] or
           model[_.KIND]() -- evaluate the function
  end,

  __index = function (template, key)
    local model = _.model(template)
    if _.NAME == key then
      return model[_.NAME]
    elseif _.KIND == key then
      return model[_.KIND]
    end
  end,
  
  __newindex = function (template, key, value)
    -- immutable: do-nothing
  end
}
    
--------------------------------------------------------------------------------

--- Create/Use a string<n> atom
-- 
-- string of length n (i.e. string<n>) 
-- @param n the maximum length of the string
-- @return the string template
function xtypes.string(n)
  return xtypes.atom{string={n}} -- NOTE: installed as xtypes.builtin.wstring<n>
end

--------------------------------------------------------------------------------

--- Create/Use a wstring<n> atom
-- 
-- wstring of length n (i.e. wstring<n>) 
-- @param n the maximum length of the wstring
-- @return the wstring template
function xtypes.wstring(n)
  return xtypes.atom{wstring={n}} -- NOTE: installed as xtypes.builtin.wstring<n>
end

--------------------------------------------------------------------------------

--- Built-in atomic types
xtypes.builtin.boolean = xtypes.atom{boolean=_.EMPTY}
xtypes.builtin.octet = xtypes.atom{octet=_.EMPTY}

xtypes.builtin.char= xtypes.atom{char=_.EMPTY}
xtypes.builtin.wchar = xtypes.atom{wchar=_.EMPTY}
    
xtypes.builtin.float = xtypes.atom{float=_.EMPTY}
xtypes.builtin.double = xtypes.atom{double=_.EMPTY}
xtypes.builtin.long_double = xtypes.atom{['long double']=_.EMPTY}
    
xtypes.builtin.short = xtypes.atom{short=_.EMPTY}
xtypes.builtin.long = xtypes.atom{long=_.EMPTY}
xtypes.builtin.long_long = xtypes.atom{['long long']=_.EMPTY}
    
xtypes.builtin.unsigned_short = xtypes.atom{['unsigned short']=_.EMPTY}
xtypes.builtin.unsigned_long = xtypes.atom{['unsigned long']=_.EMPTY}
xtypes.builtin.unsigned_long_long = xtypes.atom{['unsigned long long']=_.EMPTY}

--------------------------------------------------------------------------------

--- Define an constant
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
function xtypes.const(decl) 
  local name, defn = xtypes.parse_decl(decl)
       
  -- pre-condition: ensure that the 1st defn declaration is a valid type
  local atom = _.assert_model(xtypes.ATOM, _.resolve(defn[1]))
         
  -- pre-condition: ensure that the 2nd defn declaration is a valid value
  local value = defn[2]
  assert(nil ~= value, 
         table.concat{'const value must be non-nil: ', tostring(value)})

  -- convert value to the correct type:
  local coercedvalue = nil
  if xtypes.builtin.boolean == atom then 
      if 'boolean' ~= type(value) then
          if 'false' == value then coercedvalue = false 
          elseif 'true' == value then coercedvalue = true 
          else coercedvalue = not not value -- toboolean
          end
          if nil ~= coercedvalue then
             print(table.concat{'INFO: converting to boolean: "', value,
                                '" -> "', tostring(coercedvalue), '"'}) 
          else 
             print(table.concat{'WARNING: converting to boolean: "', value,
                                '" -> "nil"'}) 
          end
      end
  elseif xtypes.string() == atom or 
         xtypes.wstring() == atom or 
         xtypes.builtin.char == atom then
      if 'string' ~= type(value) then 
          if nil ~= coercedvalue then
             coercedvalue = tostring(value) 
             print(table.concat{'INFO: converting to string: "', value,
                                '" -> "', coercedvalue, '"'}) 
          else 
             print(table.concat{'WARNING: converting to string: "', value,
                                '" -> "nil"'}) 
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
             print(table.concat{'INFO: converting to number: "', value,
                                '" -> "', coercedvalue, '"'}) 
          else
             print(table.concat{'WARNING: converting to number: "', value,
                                '" -> "nil"'}) 
          end
      end
  end
  if nil ~= coercedvalue then value = coercedvalue end
  
  local model = _.model(atom)
  if xtypes.builtin.unsigned_short == atom or 
     xtypes.builtin.unsigned_long == atom or
     xtypes.builtin.unsigned_long_long == atom then
     if value < 0 then 
       print(table.concat{'INFO: const value of "', value, ' of type "', 
                        type(value),
                        '" must be non-negative and of the type: ', 
                        model[_.NAME] })
     end                   
  end
                      
  -- char: truncate value to 1st char; warn if truncated
  if (xtypes.builtin.char == atom or xtypes.builtin.wchar == atom) and 
      #value > 1 then
    value = string.sub(value, 1, 1)
    print(table.concat{'WARNING: truncating string value for ',
                       model[_.NAME],
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
    print(table.concat{'WARNING: truncating decimal value for integer constant', 
                       ' to: ', value})
  end

  -- create the template
  local template, model = 
                   _.new_template(name, xtypes.CONST, xtypes.API[xtypes.CONST]) 
  model[_.DEFN] = atom
  model[_.INSTANCES] = value
  return template
end


--- Const API meta-table
xtypes.API[xtypes.CONST] = {

  __tostring = function(template)
    local model = _.model(template)
    return model[_.NAME] or
           model[_.KIND]() -- evaluate the function  
  end,

  __index = function (template, key)
    local model = _.model(template)
    if _.NAME == key then
      return model[_.NAME]
    elseif _.KIND == key then
      return model[_.KIND]
    end
  end,
  
  __newindex = function (template, key, value)
    -- immutable: do-nothing
  end,

  -- instance value is obtained by evaluating the table:
  -- eg: MY_CONST()
  __call = function(template)
    local model = _.model(template)
    return model[_.INSTANCES]
  end,
}

--------------------------------------------------------------------------------

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
--   MyEnum = xtypes.enum{MyEnum=_.EMPTY}
--   
--  -- Get | Set an annotation:
--   print(MyEnum[_.QUALIFIERS])
--   MyEnum[_.QUALIFIERS] = {    
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
--    for i, v in ipairs(MyEnum) do print(next(v)) end
--    for i = 1, #MyEnum do print(next(MyEnum[i])) end
--
--  -- Iterate over enum and ordinal values (unordered):
--    for k, v in pairs(MyEnum) do print(k, v) end
--
function xtypes.enum(decl) 
  local name, defn = xtypes.parse_decl(decl)
    
  -- create the template
  local template = _.new_template(name, xtypes.ENUM, xtypes.API[xtypes.ENUM])

  -- populate the template
  return _.populate_template(template, defn)
end

--- Enum API meta-table
xtypes.API[xtypes.ENUM] = {

  __tostring = function(template) 
    -- the name or the kind (if no name has been assigned)
    local model = _.model(template)
    return model[_.NAME] or 
           model[_.KIND]() -- evaluate the function
  end,
  
  __len = function (template)
    local model = _.model(template)
    return #model[_.DEFN]
  end,

  __ipairs = function(template)
    local model = _.model(template)
    return ipairs(model[_.DEFN])
  end,

  __index = function (template, key)
    local model = _.model(template)
    if _.NAME == key then
      return model[_.NAME]
    elseif _.KIND == key then
      return model[_.KIND]
    else -- delegate to the model definition
       return model[_.DEFN][key]
    end
  end,
  
  __newindex = function (template, key, value)

    local model = _.model(template)
    local model_defn = model[_.DEFN]

    if _.NAME == key then -- set the model name
      rawset(model, _.NAME, value)

    elseif _.QUALIFIERS == key then -- annotation definition
      -- set the new qualifiers in the model definition (may be nil)
      model_defn[_.QUALIFIERS] = _.assert_qualifier_array(value)

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
-- @param decl  [in] a table containing a struct declaration
--      { Name = { { role1 = {...}, { role2 = {...} }, ... } } 
-- @return The struct template. A table representing the struct data model. 
-- The table fields contain the string index to de-reference the struct's 
-- value in a top-level DDS Dynamic Data Type 
-- @usage
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
--   local MyStruct = xtypes.struct{MyStruct={OptionalBaseStruct}|xtypes._.EMPTY}
--   
--  -- Get | Set an annotation:
--   print(MyStruct[_.QUALIFIERS])
--   MyStruct[_.QUALIFIERS] = {    
--        xtypes.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
--        xtypes.Nested{'FALSE'},
--      }
--      
--  -- Get | Set a member:
--   print(next(MyStruct[i]))
--   MyStruct[i] = { role = { type, multiplicity?, annotation? } },
--   
--  -- Get | Set base class:
--   print(MyStruct[xtypes.BASE])
--   MyStruct[xtypes.BASE] = BaseStruct, -- optional
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
function xtypes.struct(decl) 
  local name, defn = xtypes.parse_decl(decl)
       
  -- create the template
  local template, model = _.new_template(name, xtypes.STRUCT, 
                                               xtypes.API[xtypes.STRUCT])
  model[_.INSTANCES] = {}
  
  -- OPTIONAL base: pop the next element if it is a base model element
  local base
  if xtypes.STRUCT == _.model_kind(defn[1]) then
    base = defn[1]   table.remove(defn, 1)

    -- insert the base class:
    template[xtypes.BASE] = base -- invokes the meta-table __newindex()
  end

  -- populate the template
  return _.populate_template(template, defn)
end

--- Struct API meta-table
xtypes.API[xtypes.STRUCT] = {

  __tostring = function(template)
    -- the name or the kind (if no name has been assigned)
    local model = _.model(template)
    return model[_.NAME] or
           model[_.KIND]() -- evaluate the function
  end,

  __len = function (template)
    local model = _.model(template)
    return #model[_.DEFN]
  end,

  __ipairs = function(template)
    local model = _.model(template)
    return ipairs(model[_.DEFN])
  end,

  __index = function (template, key)
    local model = _.model(template)
    if _.NAME == key then
      return model[_.NAME]
    elseif _.KIND == key then
      return model[_.KIND]
    else -- delegate to the model definition
      return model[_.DEFN][key]
    end
  end,

  __newindex = function (template, key, value)

    local model = _.model(template)
    local model_defn = model[_.DEFN]

    if _.NAME == key then -- set the model name
      rawset(model, _.NAME, value)

    elseif _.QUALIFIERS == key then -- annotation definition
      -- set the new qualifiers in the model definition (may be nil)
      model_defn[_.QUALIFIERS] = _.assert_qualifier_array(value)

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
        table.concat{'member name already defined: "', role, '"'})

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

    elseif xtypes.BASE == key then -- inherits from 'base' struct

      -- clear the instance fields from the old base struct (if any)
      local old_base = model_defn[xtypes.BASE]
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
        old_base = old_base[xtypes.BASE] -- parent base
      end

      -- get the base model, if any:
      local new_base
      if nil ~= value then
        new_base = _.assert_model(xtypes.STRUCT, value)
      end

      -- populate the instance fields from the base model struct
      local base = new_base
      while base do
        local base_model = _.model(base)
        for i = 1, #base_model[_.DEFN] do
          local base_role, base_role_defn = next(base_model[_.DEFN][i])

          -- is the base_role already defined?
          assert(nil == rawget(template, base_role),-- check template
            table.concat{'member name already defined: "', base_role, '"'})

          -- create base role instance (checks for pre-conditions, may fail)
          local base_role_instance =
            _.create_role_instance(base_role, base_role_defn)


          -- update instances: add the new base_role_instance
          _.update_instances(model, base_role, base_role_instance)
        end

        -- visit up the base model inheritance hierarchy
        base = base_model[_.DEFN][xtypes.BASE] -- parent base
      end

      -- set the new base in the model definition (may be nil)
      model_defn[xtypes.BASE] = new_base

      -- template is an instance of the base structs (inheritance hierarchy)
      base = new_base
      while base do
        local base_model = _.model(base)
        
        -- NOTE: Use empty string as the 'instance' name of the base struct
        base_model[_.INSTANCES][template] = '' -- empty instance name

        -- visit up the base model inheritance hierarchy
        base = base_model[_.DEFN][xtypes.BASE] -- parent base
      end
    end
  end
}

--------------------------------------------------------------------------------

--- Create a union type
-- @param decl  [in] a table containing a union declaration
--      { Name = {discriminator, { case, role = {...} }, ... } } 
-- @return The union template. A table representing the union data model. 
-- The table fields contain the string index to de-reference the union's value
-- in a top-level DDS Dynamic Data Type 
-- @usage
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
--   print(MyUnion[_.QUALIFIERS])
--   MyUnion[_.QUALIFIERS] = {    
--        xtypes.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
--      }
--      
--  -- Get | Set a member:
--   print(next(MyUnion[i]))
--   MyUnion[i] = { case, [ { role = { type, multiplicity?, annotation? } } ] },
--   
--  -- Get | Set discriminator:
--   print(MyUnion[xtypes.SWITCH])
--   MyUnion[xtypes.SWITCH] = discriminator
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
function xtypes.union(decl) 
  local name, defn = xtypes.parse_decl(decl)
       
  -- create the template 
  local template, model = _.new_template(name, xtypes.UNION, 
                                               xtypes.API[xtypes.UNION])
  model[_.INSTANCES] = {}
 
 	-- pop the discriminator
	template[xtypes.SWITCH] = defn[1] -- invokes meta-table __newindex()
  table.remove(defn, 1)

  -- populate the template
  return _.populate_template(template, defn)
end

--- Union API meta-table 
xtypes.API[xtypes.UNION] = {

  __tostring = function(template) 
    -- the name or the kind (if no name has been assigned)
    local model = _.model(template)
    return model[_.NAME] or 
           model[_.KIND]() -- evaluate the function
  end,

  __len = function (template)
    local model = _.model(template)
    return #model[_.DEFN]
  end,

  __ipairs = function(template)
    local model = _.model(template)
    return ipairs(model[_.DEFN])
  end,

  __index = function (template, key)
    local model = _.model(template)
    if _.NAME == key then
      return model[_.NAME]
    elseif _.KIND == key then
      return model[_.KIND]
    else -- delegate to the model definition
       return model[_.DEFN][key]
    end
  end,

  __newindex = function (template, key, value)

    local model = _.model(template)
    local model_defn = model[_.DEFN]

    if _.NAME == key then -- set the model name
      model[_.NAME] = value

    elseif _.QUALIFIERS == key then -- annotation definition
      -- set the new qualifiers in the model definition (may be nil)
      model_defn[_.QUALIFIERS] = _.assert_qualifier_array(value)

    elseif xtypes.SWITCH == key then -- switch definition

      local discriminator, discriminator_type = value, _.model_kind(value)
      
      -- pre-condition: ensure discriminator is an atom or enum
      assert(xtypes.ATOM == discriminator_type or
        xtypes.ENUM == discriminator_type,
        'discriminator type must be an "atom" or an "enum"')
     
      -- pre-condition: ensure that 'cases' are compatible with discriminator
      for i, v in ipairs(model_defn) do
        xtypes.assert_case(discriminator, v[1])
      end
     
      -- update the discriminator
      model[_.DEFN][xtypes.SWITCH] = discriminator
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
        local case = xtypes.assert_case(model_defn[xtypes.SWITCH], value[1])

        -- is the case already defined?
        for i, defn_i in ipairs(model_defn) do
          assert(case ~= defn_i[1],
            table.concat{'case exists: "', tostring(case), '"'})
        end

        -- get the role and definition
        local role, role_defn = next(value, 1) -- 2nd item after the 'case'
 
          -- add the role
        if role then
          
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

          -- update instances: add the new role_instance
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
--   local MyModule = xtypes.module{MyModule=xtypes._.EMPTY}
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
--   for i, v in ipairs(MyModule) do print(v) end
--   for i = 1, #MyModule do print(MyModule[i]) end
--
--  -- Iterate over module namespace (unordered):
--   for k, v in pairs(MyModule) do print(k, v) end
--   
function xtypes.module(decl) 
  local name, defn = xtypes.parse_decl(decl)
       
  --create the template
  local template = _.new_template(name, xtypes.MODULE, 
                                  xtypes.API[xtypes.MODULE])

  -- populate the template
  return _.populate_template(template, defn)
end

--- Module API meta-table
xtypes.API[xtypes.MODULE] = {

  __tostring = function(template)
    -- the name or the kind (if no name has been assigned)
    local model = _.model(template)
    return model[_.NAME] or
           model[_.KIND]() -- evaluate the function
  end,

  __len = function (template)
    local model = _.model(template)
    return #model[_.DEFN]
  end,

  __ipairs = function(template)
    local model = _.model(template)
    return ipairs(model[_.DEFN])
  end,

  __index = function (template, key)
    local model = _.model(template)
    if _.NAME == key then
      return model[_.NAME]
    elseif _.KIND == key then
      return model[_.KIND]
    else -- delegate to the model definition
      return model[_.DEFN][key]
    end
  end,
  
  __newindex = function (template, key, value)

    local model = _.model(template)
    local model_defn = model[_.DEFN]
                
    if _.NAME == key then -- set the model name
      rawset(model, _.NAME, value)

    elseif _.QUALIFIERS == key then -- annotation definition
      -- set the new qualifiers in the model definition (may be nil)
      model_defn[_.QUALIFIERS] = _.assert_qualifier_array(value)

    elseif 'number' == type(key) then -- member definition
      -- clear the old member definition and instance fields
      if model_defn[key] then
        local old_role_model = _.model(model_defn[key])
        local old_role = old_role_model[_.NAME]
        
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
               table.concat{'invalid template: ', tostring(value)})
               
        local role_template = value
        local role = role_template[_.NAME]                  
                     
        -- is the role already defined?
        assert(nil == rawget(template, role),
          table.concat{'member name already defined: "', role, '"'})
            
				-- update the module definition
        model_defn[key] = role_template 
    
        -- move the model element to this module 
        local role_model = _.model(role_template)
        role_model[_.NS] = template
        
        -- update namespace: add the role
        rawset(template, role, role_template)
      end
    end
  end,
}

--------------------------------------------------------------------------------

--- Create a typedef. 
-- 
-- Typedefs are aliases for underlying primitive or composite types 
-- @param decl  [in] a table containing a typedef declaration
--      { name = { template, [collection,] [annotation1, annotation2, ...] }  }
-- i.e. the underlying type definition and optional multiplicity and annotations                
-- @return the typedef template
-- @usage
--  IDL: typedef sequence<MyStruct> MyStructSeq
--  Lua: local MyStructSeq = xtypes.typedef{ 
--            MyStructSeq = { xtypes.MyStruct, xtypes.sequence() } 
--       }
--
--  IDL: typedef MyStruct MyStructArray[10][20]
--  Lua: local MyStructArray = xtypes.typedef{ 
--          MyStructArray = { xtypes.MyStruct, xtypes.array(10, 20) }
--       }
function xtypes.typedef(decl) 
  local name, defn = xtypes.parse_decl(decl)

  -- pre-condition: ensure that the 1st defn element is a valid type
  local alias = defn[1]
  _.assert_template(alias)

  -- pre-condition: ensure that the 2nd defn element if present 
  -- is a 'collection' kind
  local collection = defn[2]
  if collection and not xtypes.info.is_collection_kind(collection) then
    error(table.concat{'expected sequence or array, got: ', tostring(value)},
          2)     
  end
 
  -- create the template
  local template, model = _.new_template(name, xtypes.TYPEDEF, 
                                               xtypes.API[xtypes.TYPEDEF]) 
  model[_.DEFN] = { alias, collection }
  return template
end

--- Atom API meta-table
xtypes.API[xtypes.TYPEDEF] = {

  __tostring = function(template)
    -- the name or the kind (if no name has been assigned)
    local model = _.model(template)
    return model[_.NAME] or
           model[_.KIND]() -- evaluate the function
  end,

  __index = function (template, key)
    local model = _.model(template)
    if _.NAME == key then
      return model[_.NAME]
    elseif _.KIND == key then
      return model[_.KIND]
    end
  end,
  
  __newindex = function (template, key, value)
    -- immutable: do-nothing
  end,
  
  -- alias information is obtained by evaluating the table:
  -- @return { alias, collection }
  -- eg: my_typedef()
  __call = function(template)
    local model = _.model(template)
    return model[_.DEFN]
  end,
}

--------------------------------------------------------------------------------
-- Error Checking and Validation
--------------------------------------------------------------------------------

--- Ensure that case is a valid discriminator value
-- @return the case
function xtypes.assert_case(discriminator, case)
  if nil == case then return case end -- default case 

  local err_msg = table.concat{'invalid case value: ', tostring(case)}
  
  if xtypes.builtin.long == discriminator or -- integral type
     xtypes.builtin.short == discriminator or 
     xtypes.builtin.octet == discriminator then
    assert(tonumber(case) and math.floor(case) == case, err_msg)     
   elseif xtypes.builtin.char == discriminator then -- character
    assert('string' == type(case) and 1 == string.len(case), err_msg) 
   elseif xtypes.builtin.boolean == discriminator then -- boolean
    assert(true == case or false == case, err_msg)
   elseif xtypes.ENUM == discriminator[_.KIND] then -- enum
    assert(discriminator[case], err_msg)
   else -- invalid 
    assert(false, err_msg)
   end
  
   return case
end

--------------------------------------------------------------------------------
-- X-Types Utilities
--------------------------------------------------------------------------------
local xutils = {}

-- @function xutils.visit_instance() - Visit all fields (depth-first) in 
--       the given instance and return their values as a linear (flattened) 
--       list. For instance collections, the 1st element is visited.
-- @param instance [in] the instance to visit
-- @param result [in] OPTIONAL the index table to which the results are appended
-- @param model [in] OPTIONAL nil means use the instance's model;
--              needed to support inheritance and typedefs
-- @return the cumulative result of visiting all the fields. Each field that is
--         visited is inserted into this table. This returned value table can be 
--         passed to another call to this method (to build it cumulatively).
function xutils.visit_instance(instance, result, model) 
  local template = instance 
  -- local template _.template(instance) -- TODO
  
  -- print('DEBUG xutils.visit_instance 1: ', instance, template) 
 
  -- initialize the result (or accumulate in the provided result)
  result = result or {} 

  -- collection instance
  if _.is_collection(instance) then
        -- ensure 1st element exists for illustration
      local _ = instance[1]
      
      -- length operator and actual length
      table.insert(result, template() .. ' = ' ..  #instance)
          
      -- visit all the elements
      for i = 1, #instance do 
        if 'table' == type(instance[i]) then -- composite collection
            xutils.visit_instance(instance[i], result) -- visit i-th element 
        else -- leaf collection
            table.insert(result, template[i] .. ' = ' .. instance[i])
        end
      end
      
      return result
  end
  
  -- struct or union
  local mytype = _.model_kind(instance)
  local model = model or _.model(instance)
  local mydefn = model[_.DEFN]
  
  -- print('DEBUG index 1: ', mytype(), _.model(instance)[_.NAME])
      
  -- skip if not an indexable type:
  if xtypes.STRUCT ~= mytype and xtypes.UNION ~= mytype then return result end
          
  -- union discriminator, if any
  if xtypes.UNION == mytype then
    table.insert(result, template._d .. ' = ' .. instance._d)
  end
    
  -- struct base type, if any
  local base = model[_.DEFN][xtypes.BASE]
  if nil ~= base then
    result = xutils.visit_instance(instance, result, _.model(base)) 
  end
  
  -- preserve the order of model definition
  -- walk through the body of the model definition
  -- NOTE: typedefs don't have an array of members  
  for i, defn_i in ipairs(mydefn) do    
    -- skip annotations
      -- walk through the elements in the order of definition:
      
      local role
      if xtypes.STRUCT == mytype then     
        role = next(defn_i)
      elseif xtypes.UNION == mytype then
        role = next(defn_i, #defn_i > 0 and #defn_i or nil)
      end
      
      local role_instance = instance[role]
      local role_instance_type = type(role_instance)
      -- print('DEBUG index 3: ', role, role_instance)

      if 'table' == role_instance_type then -- composite or collection
        result = xutils.visit_instance(role_instance, result)
      else -- leaf
        table.insert(result, template[role] 
                                and template[role] .. ' = ' .. role_instance
                                or nil) 
      end
  end

  return result
end

-- xutils.visit_model() - Visit all elements (depth-first) of 
--       the given model definition and return their values as a linear 
--       (flattened) list. 
--       
--        The default implementation returns the stringified
--        OMG IDL X-Types representation of each model definition element
--
-- @param model [in] the model element
-- @param result [in] OPTIONAL the index table to which the results are appended
-- @param indent_string [in] the indentation for the string representation
-- @return the cumulative result of visiting all the definition. Each definition
--        that is visited is inserted into this table. This returned table 
--        can be passed to another call to this method (to build cumulatively).
function xutils.visit_model(instance, result, indent_string)
	-- pre-condition: ensure valid instance
	assert(_.model_kind(instance), 'invalid instance')
	
	-- initialize the result (or accumulate in the provided result)
  result = result or {} 

	local indent_string = indent_string or ''
	local content_indent_string = indent_string
	local model = _.model(instance)
	local myname = model[_.NAME]
	local mytype = model[_.KIND]
	local mydefn = model[_.DEFN]
  local mymodule = model[_.NS]
  		
	-- print('DEBUG visit_model: ', Data, model, mytype(), myname)
	
	-- skip: atomic types, annotations
	if xtypes.ATOM == mytype or
	   xtypes.ANNOTATION == mytype then 
	   return result
	end
    
  if xtypes.CONST == mytype then
    local atom = mydefn
    local value = instance()
    local atom = model[_.DEFN]
    if xtypes.builtin.char == atom or xtypes.builtin.wchar == atom then
      value = table.concat{"'", tostring(value), "'"}
    elseif xtypes.string() == atom or xtypes.wstring() == atom then
      value = table.concat{'"', tostring(value), '"'}
    end
     table.insert(result, 
                  string.format('%sconst %s %s = %s;', content_indent_string, 
                        atom, 
                        myname, value))
     return result
  end
    
	if xtypes.TYPEDEF == mytype then
		local defn = mydefn	
    table.insert(result, string.format('%s%s %s', indent_string,  mytype(),
                                xutils.tostring_role(myname, defn, mymodule)))
		return result 
	end
	
	-- open --
	if (nil ~= myname) then -- not top-level / builtin module
	
		-- print the annotations
		if nil ~=mydefn and nil ~= mydefn[_.QUALIFIERS] then
			for i, annotation in ipairs(mydefn[_.QUALIFIERS]) do
		      table.insert(result,
		            string.format('%s%s', indent_string, tostring(annotation)))
			end
		end
		
		if xtypes.UNION == mytype then
			table.insert(result, string.format('%s%s %s switch (%s) {', indent_string, 
						mytype(), myname, model[_.DEFN][xtypes.SWITCH][_.NAME]))
						
		elseif xtypes.STRUCT == mytype and model[_.DEFN][xtypes.BASE] then -- base
			table.insert(result,
			    string.format('%s%s %s : %s {', indent_string, mytype(), 
					myname, model[_.DEFN][xtypes.BASE][_.NAME]))
		
		else
			table.insert(result, 
			             string.format('%s%s %s {', indent_string, mytype(), myname))
		end
		content_indent_string = indent_string .. '   '
	end
		
	if xtypes.MODULE == mytype then 
		for i, role_template in ipairs(mydefn) do -- walk through module definition
			result = xutils.visit_model(role_template, result, content_indent_string)
		end
		
	elseif xtypes.STRUCT == mytype then
	 
		for i, defn_i in ipairs(mydefn) do -- walk through the model definition
			  local role, role_defn = next(defn_i)
        table.insert(result, string.format('%s%s', content_indent_string,
                            xutils.tostring_role(role, role_defn, mymodule)))
		end

	elseif xtypes.UNION == mytype then 
		for i, defn_i in ipairs(mydefn) do -- walk through the model definition

				local case = defn_i[1]
				
				-- case
				if (nil == case) then
				  table.insert(result,
				               string.format("%sdefault :", content_indent_string))
				elseif (xtypes.builtin.char == model[_.DEFN][xtypes.SWITCH] 
				        and nil ~= case) then
					table.insert(result, string.format("%scase '%s' :", 
						content_indent_string, tostring(case)))
				else
					table.insert(result, string.format("%scase %s :", 
						content_indent_string, tostring(case)))
				end
				
				-- member element
				local role, role_defn = next(defn_i, #defn_i > 0 and #defn_i or nil)
				table.insert(result, string.format('%s%s', content_indent_string .. '   ',
				                      xutils.tostring_role(role, role_defn, mymodule)))
		end
		
	elseif xtypes.ENUM == mytype then
		for i, defn_i in ipairs(mydefn) do -- walk through the model definition	
			local role, ordinal = next(defn_i)
			if ordinal then
				table.insert(result, string.format('%s%s = %s,', content_indent_string, role, 
								    ordinal))
			else
				table.insert(result, string.format('%s%s,', content_indent_string, role))
			end
		end
	end
	
	-- close --
	if (nil ~= myname) then -- not top-level / builtin module
		table.insert(result, string.format('%s};\n', indent_string))
	end
	
	return result
end


--- IDL string representation of a role
-- @function tostring_role
-- @param #string role role name
-- @param #list role_defn the definition of the role in the following format:
--           { template, [collection,] [annotation1, annotation2, ...] } 
-- @param module the module to which the owner data model element belongs
-- @return #string IDL string representation of the idl member
function xutils.tostring_role(role, role_defn, module)

  local template, seq 
  if role_defn then
    template = role_defn[1]
    for i = 2, #role_defn do
      if xtypes.SEQUENCE == _.model(role_defn[i]) then
        seq = role_defn[i]
        break -- 1st 'collection' is used
      end
    end
  end

  local output_member = ''    
  if nil == template then return output_member end

  if seq == nil then -- not a sequence
    output_member = string.format('%s %s', _.nsname(template, module), role)
  elseif #seq == 0 then -- unbounded sequence
    output_member = string.format('sequence<%s> %s', 
                                  _.nsname(template, module), role)
  else -- bounded sequence
    for i = 1, #seq do
      output_member = string.format('%ssequence<', output_member) 
    end
    output_member = string.format('%s%s', output_member, 
                                  _.nsname(template, module))
    for i = 1, #seq do
      output_member = string.format('%s,%s>', output_member, 
                _.model_kind(seq[i]) and _.nsname(seq[i], module) or 
                tostring(seq[i])) 
    end
    output_member = string.format('%s %s', output_member, role)
  end

  -- member annotations:  
  local output_annotations = nil
  for j = 2, #role_defn do
    
    local role_defn_j_model = _.model(role_defn[j])
    local name = role_defn_j_model[_.NAME]
    
    if xtypes.ARRAY == role_defn_j_model then
      for i = 1, #role_defn[j] do
        output_member = string.format('%s[%s]', output_member, 
           _.model_kind(role_defn[j][i]) and 
               _.nsname(role_defn[j][i], module) or tostring(role_defn[j][i]) ) 
      end
    elseif xtypes.SEQUENCE ~= role_defn_j_model then
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

--------------------------------------------------------------------------------
--- Public Interface (of this module):
local interface = {
  -- empty initializer sentinel value
  EMPTY              = _.EMPTY,
  
  
  -- accesors and mutators (meta-attributes for types)
  NAME               = _.NAME,
  KIND               = _.KIND,
  QUALIFIERS         = _.QUALIFIERS,
  BASE               = xtypes.BASE,
  SWITCH             = xtypes.SWITCH,
  
    
  -- qualifiers
  annotation         = xtypes.annotation,
  array              = xtypes.array,
  sequence           = xtypes.sequence,


  -- pre-defined annotations
  Key                = xtypes.builtin.Key,   
  Extensibility      = xtypes.builtin.Extensibility,
  ID                 = xtypes.builtin.ID,
  Optional           = xtypes.Optional,
  MustUnderstand     = xtypes.builtin.MustUnderstand,
  Shared             = xtypes.builtin.Shared,
  BitBound           = xtypes.builtin.BitBound,
  BitSet             = xtypes.builtin.BitSet,
  Nested             = xtypes.builtin.Nested,
  top_level          = xtypes.builtin.top_level,


  -- atomic types
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

  
  -- composite types
  const              = xtypes.const,
  enum               = xtypes.enum,
  struct             = xtypes.struct,
  union              = xtypes.union,
  module             = xtypes.module,
      

  -- typedefs (aliases)
  typedef            = xtypes.typedef,
    
  
  -- utilities --> model
  utils              = {
    nsname                  = _.nsname,
    resolve                 = _.resolve,
    template                = _.template,
    new_instance            = _.new_instance,
    new_collection          = _.new_collection,
    is_collection           = _.is_collection,
    visit_instance          = xutils.visit_instance,
    visit_model             = xutils.visit_model,
  }
}

return interface
--------------------------------------------------------------------------------
