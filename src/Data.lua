-------------------------------------------------------------------------------
--  (c) 2005-2014 Copyright, Real-Time Innovations, All rights reserved.     --
--                                                                           --
-- Permission to modify and use for internal purposes granted.               --
-- This software is provided "as is", without warranty, express or implied.  --
--                                                                           --
-------------------------------------------------------------------------------
-- File: xtypes.lua 
-- Purpose: DDSL: Data type definition Domain Specific Language (DSL) in Lua
-- Created: Rajive Joshi, 2014 Feb 14
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Data - meta-data (meta-table) class implementing a semantic data definition 
--        model equivalent to OMG X-Types, and easily mappable to various 
--        representations (eg OMG IDL, XML etc)
--
-- @module interface
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
--        _.NAME
--        _.KIND
--        _.DEFN
--        _.INSTANCES
--    The leaf elements of the table give a fully qualified string to address a
--    field in a dynamic data sample in Lua. 
--
--    Thus, an element definition in Lua:
-- 		 UserModule:Struct('UserType',
--          xtypes.has(user_role1, xtypes.String()),
--          xtypes.contains(user_role2, UserModule.UserType2),
--          xtypes.contains(user_role3, UserModule.UserType3),
--          xtypes.has_list(user_role_seq, UserModule.UserTypeSeq),
--          :
--       )
--    results in the following table ('model') being defined:
--       UserModule.UserType = {
--          [_.NAME] = 'UserType'     -- name of this model 
--          [_.KIND] = xtypes.STRUCT    -- one of xtypes.* type definitions
--          [_.DEFN] = {              -- meta-data for the contained elements
--              user_role1    = xtypes.String(),
--              user_role2    = UserModule.UserType2,
--				user_role3    = UserModule.UserType3,
--				user_role_seq = UserModule.UserTypeSeq,
--          }             
--          [_.INSTANCES] = {}       -- table of instances of this model 
--                 
--          -- instance fields --
--          user_role1 = 'user_role1'  -- name used to index this 'leaf' field
--          user_role2 = _.create_instance('user_role2', UserModule.UserType2)
--          user_role3 = _.create_instance('user_role3', UserModule.UserType3)
--          user_role_seq = _.create_collection('user_role_seq', UserModule.UserTypeSeq)
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
--          i1 = _.create_instance('i1', Model)
--    Now, one can instance all the fields of the resulting table
--          i1.role1 = 'i1.role1'
--    or 
--          Model[_.INSTANCES].i1.role1
-- 
--   Extend builtin atoms and annotations by adding to the xtypes.builtin module:
--       xtypes.builtin.my_atom = xtypes.atom{}
--       xtypes.builtin.my_annotation = xtypes.annotation{val1=1, val2=y, ...}
--     
-- Implementation:
--    The meta-model pre-defines the following meta-data 
--    attributes for a model element:
--
--       _.KIND
--          Every model element 'model' is represented as a table with a 
--          non-nil key
--             model[_.KIND] = one of the xtypes.* type definitions
--
--       _.NAME
--          For named i.e. composite model elements
--             model[_.NAME] = name of the model element
--          For primitive/atomic model elements 
--             model[_.NAME] = nil
--          This property can be used to determine if a model element is 
--			primitive.
--   
--       _.DEFN
--          For storing the child element info
--              model[_.DEFN][role] = role model element 
--
--       _.INSTANCES
--          For storing instances of this model element, indexed by instance name
--              model[_.DEFN].name = one of the instances of this model
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
--              model.role = _.create_instance('role', RoleModel)
--          or a sequence
--              model.role = _.create_collection('role', RoleModel)
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

local EMPTY = {}  -- initializer/sentinel value to indicate an empty definition
local MODEL = function() return 'MODEL' end -- key for 'model' meta-data 

--- DDSL Core Engine ---
local _ = {
  -- model attributes
  -- every 'model' meta-data table has these keys defined 
  NS        = function() return '' end,      -- namespace
  NAME      = function() return 'NAME' end,  -- table key for 'model name'  
  KIND      = function() return 'KIND' end,  -- table key for the 'model type name' 
  DEFN      = function() return 'DEFN' end,  -- table key for element meta-data
  INSTANCES = function() return 'INSTANCES' end,-- table key for instances of this model
  TEMPLATE  = function() return 'TEMPLATE' end,-- table key for the template instance

  -- model definition attributes
  QUALIFIERS = function() return '' end,        -- table key for qualifiers
}

--- Create a new 'empty' template
-- @param name  [in] the name of the underlying model
-- @param kind  [in] the kind of underlying model
-- @param api   [in] a meta-table to control access to this template
-- @return a new template with the correct meta-model
function _.new_template(name, kind, api)

  local model = {           -- meta-data
    [_.NS]   = nil,      -- namespace: module to which this model belongs
    [_.NAME] = name,     -- string: name of the model with the namespace
    [_.KIND] = kind,     -- type of the data model
    [_.DEFN] = {},       -- will be populated by the declarations
    [_.INSTANCES] = nil, -- will be populated when the type is defined
    [_.TEMPLATE] = {},   -- top-level instance to be installed in the module
  }
  local template = model[_.TEMPLATE]
  template[MODEL] = model

  -- set the template meta-table:
  setmetatable(template, api)
  
  return template
end

--- Populate a template
-- @param template  <<in>> a template, generally empty
-- @param defn      <<in>> template model definition
-- @return populated template 
function _.populate_template(template, defn)
  -- populate the role definitions
  local qualifiers
  for i, defn_i in ipairs(defn) do 

    -- build the model level annotation list
    if _.is_qualifier(defn_i) then        
      qualifiers = qualifiers or {}
      table.insert(qualifiers, defn_i)  

    else --  member definition
      -- insert the model definition entry: invokes meta-table __newindex()
      template[#template+1] = defn_i  
    end
  end

  -- insert the qualifiers:
  if qualifiers then -- insert the qualifiers:
    template[_.QUALIFIERS] = qualifiers -- invokes meta-table __newindex()
  end

  return template
end

--------------------------------------------------------------------------------
-- Model Instances  ---
--------------------------------------------------------------------------------

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
  
  _.assert_role(role)
  
  local template = role_defn[1]
  _.assert_template(template) 
  
  -- pre-condition: ensure that the rest of the member definition entries are 
  -- annotations: also look for the 1st 'collection' annotation (if any)
  local collection = nil
  for j = 2, #role_defn do
    _.assert_qualifier(role_defn[j])

    -- is this a collection?
    if not collection then  -- the 1st 'collection' definition is used
      collection = _.is_collection(role_defn[j])
    end
  end

  -- populate the role_instance fields
  local role_instance = nil

  if role then -- skip member instance if role is not specified 
    if collection then
      local iterator = template
      for i = 1, #collection - 1  do -- create iterator for inner dimensions
        iterator = _.create_collection('', iterator) -- unnamed iterator
      end
      role_instance = _.create_collection(role, iterator)
    else
      role_instance = _.create_instance(role, template)
    end
  end
  
  return role_instance, role_defn
end


--- Propagate member 'role' update to all instances of a model
-- @param model [in] the model 
-- @param role [in] the role to propagate
-- @param role_template [in] template role instance created 
--                           using create_role_instance()
function _.update_instances(model, role, role_template)

   -- update template first
   local template = model[_.TEMPLATE]
   rawset(template, role, role_template)
   
   -- update the remaining member instances:
   for instance, name in pairs(model[_.INSTANCES]) do
      if instance == template then -- template
          -- do nothing (already updated the template) 
      else -- instance: may be user defined or occurring in another type model
          -- prefix the 'name' to the role_template
          rawset(instance, role, _.prefix(name, role_template))
      end
   end
end
       
--- Create an instance, using another instance as a template
--  Defines a table that can be used to index into an instance of a model
-- 
-- @param name      <<in>> the role|instance name
-- @param template  <<in>> the template to use for creating an instance; 
--                         must be a model table 
-- @return the newly created instance (seq) that supports indexing by 'name'
-- @usage
--    -- As an index into sample[]
--    local myInstance = _.create_instance("my", template)
--    local member = sample[myInstance.member] 
--    for i = 1, sample[myInstance.memberSeq()] do -- length of the sequence
--       local element_i = sample[memberSeq(i)] -- access the i-th element
--    end  
--
--    -- As a sample itself
--    local myInstance = _.create_instance("my", template)
--    myInstance.member = "value"
--
--    -- NOTE: Assignment not yet supported for sequences:
--    myInstance.memberSeq() = 10 -- length
--    for i = 1, myInstance.memberSeq() do -- length of the sequence
--       memberSeq(i) = "element_i"
--    end  
--
function _.create_instance(name, template) 
  -- print('DEBUG xtypes.instance 1: ', name, template[MODEL][_.NAME])

  _.assert_role(name)
  _.assert_template(template)
 
  local instance = nil
  
  ---------------------------------------------------------------------------
  -- alias? switch the template to the underlying alias
  ---------------------------------------------------------------------------
  local is_alias = _.is_alias(template)
  local alias, alias_collection
  
  if is_alias then
    local defn = template[MODEL][_.DEFN]
    alias = defn[1]
    
    for j = 2, #defn do
      alias_collection = _.is_collection(defn[j])
      if alias_collection then
        -- print('DEBUG xtypes.instance 2: ', name, alias_collection)
        break -- 1st 'collection' is used
      end
    end
  end

  -- switch template to the underlying alias
  if alias then template = alias end
   
  ---------------------------------------------------------------------------
  -- alias is a collection:
  ---------------------------------------------------------------------------
  
  -- collection of underlying types (which is not an alias)
  if alias_collection then
    local iterator = template
    for i = 1, #alias_collection - 1  do -- create iterator for inner dimensions
      iterator = _.create_collection('', iterator) -- unnamed iterator
    end
    instance = _.create_collection(name, iterator)
    return instance
  end
  
  ---------------------------------------------------------------------------
  -- alias is recursive:
  ---------------------------------------------------------------------------

  if is_alias and _.is_alias(alias) then
    instance = _.create_instance(name, template) -- recursive
    return instance
  end

  ---------------------------------------------------------------------------
  -- leaf instances
  ---------------------------------------------------------------------------
 
  if _.is_leaf(template) then
    instance = name 
    return instance
  end
  
  ---------------------------------------------------------------------------
  -- composite instances 
  ---------------------------------------------------------------------------
  
  -- Establish the underlying model definition to create an instance
  -- NOTE: aliases do not hold any instances; the instances are held by the
  --       underlying concrete (non-alias) alias type
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
  model[_.INSTANCES][instance] = name

  return instance
end

-- Name: 
--    _.create_collection() - creates a sequence, of elements specified by the template
-- Purpose:
--    Define a sequence iterator (closure) for indexing
-- Parameters:
--    <<in>> name  - the role or instance name
--    <<in>> template - the template to use for creating an instance
--                          may be a table when it is an non-collection type OR
--                          may be a closure for collections (sequences/arrays)
--    <<returns>> the newly created closure for indexing a sequence of 
--          of template elements
-- Usage:
--    local mySeq = _.create_collection("my", template)
--    for i = 1, sample[mySeq()] do -- length of the sequence
--       local element_i = sample[mySeq(i)] -- access the i-th element
--    end    
function _.create_collection(name, template) 
  -- print('DEBUG xtypes.seq', name, template)

  -- pre-condition: ensure valid template
  local type_template = type(template)
  assert('table' == type_template and template[MODEL] or 
         'function' == type_template, -- collection iterator
          table.concat{'sequence template ',
                   'must be an instance table or function: "',
                 tostring(name), '"'})
  if 'table' == type_template then
    _.assert_template(template)
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
              _.create_instance(string.format('%s%s[%d]', prefix_i, name, i), 
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
-- @param name name to prefix with (may be an empty string '')
-- @param v index value
-- @return index value with the 'name' prefix
function _.prefix(name, v)

    local type_v = type(v)
    local result 
    
    --  the separator to use (empty, if name is an empty string)
    local sep = ('' == name) and '' or '.'
    
    -- prefix the member names
    if 'function' == type_v then -- seq
      result = -- use member as a closure template
        function(j, prefix_j) -- allow further prefixing
          return v(j, table.concat{prefix_j or '', name, sep}) 
        end

    elseif 'table' == type_v then -- struct or union
      result = _.create_instance(name, v) -- use member as template

    elseif 'string' == type_v then -- atom/leaf

      if '#' == v then -- _d: leaf level union discriminator
        result = table.concat{name, v} -- no separator
      else
        result = table.concat{name, sep, v}
      end

    end
    
    return result
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

--- Name of a model element relative to a namespace
-- @param template [in] the data model element whose name is desired in 
--        the context of the namespace
-- @param namespace [in] the namespace; if nil, finds the full absolute 
--                    fully qualified name of the model element
-- @return the name of the template relative to the namespace
function _.nsname(template, namespace)
  -- pre-conditions:
  assert(nil ~= _.model_kind(template), "nsname(): not a valid template")
  assert(nil == namespace or nil ~= _.model_kind(namespace), 
                                        "nsname(): not a valid namespace")
                           
  -- traverse up the template namespaces, until 'module' is found
  local model = template[MODEL]
  if namespace == model[_.NS] or nil == model[_.NS] then
    return model[_.NAME]
  else
    return table.concat{_.nsname(model[_.NS], namespace), '::', model[_.NAME]}
  end
end

--- Get the model type of any arbitrary value
-- @param value  [in] the value for which to retrieve the model type
-- @return the model type or nil (if 'value' does not have a MODEL)
function _.model_kind(value)
    return ('table' == type(value) and value[MODEL]) 
           and value[MODEL][_.KIND]
           or nil
end

--- Ensure that the value is a model element
-- @param kind   [in] expected model element kind
-- @param value  [in] table to check if it is a model element of "kind"
-- @return the model table if the kind matches, or nil
function _.assert_model(kind, value)
    assert('table' == type(value) and 
           value[MODEL] and 
           kind == value[MODEL][_.KIND],
           table.concat{'expected model kind "', kind(), 
                        '", instead got "', tostring(value), '"'})
    return value
end

--- Ensure that value is a collection
-- @param collection [in] the potential collection to check
-- @return the collection or nil
function _.assert_collection(collection)
    assert(_.is_collection(collection), 
           table.concat{'expected collection \"', tostring(collection), '"'})
    return collection
end

--- Ensure that value is a qualifier
-- @param qualifier [in] the potential qualifier to check
-- @return the qualifier or nil
function _.assert_qualifier(qualifier)
    assert(_.is_qualifier(qualifier), 
           table.concat{'expected qualifier \"', tostring(qualifier), '"'})
    return qualifier
end

--- Ensure all elements in the 'value' array are qualifiers
-- @param value [in] the potential qualifier array to check
-- @return the qualifier array or nil
function _.assert_qualifier_array(value)
    -- establish valid qualifiers, if any
    if nil == value then return nil end
    
    local count = 0    
    for k, v in pairs(value) do
        assert('number' == type(k), 
                table.concat{'invalid qualifier array "', 
                              tostring(value), '"'})
        _.assert_qualifier(v)
        count = count + 1
    end

    --all keys are numerical: check if they are sequential and start with 1
    for i = 1, count do
      if nil == value[i] then 
         assert(table.concat{'invalid qualifier array "', tostring(value), '"'})
      end
    end
  
    return value
end

--- Ensure that the role name is valid
-- @param role        [in] the role name
-- @return role if valid; nil otherwise
function _.assert_role(role)
  assert('string' == type(role), 
      table.concat{'invalid role name: ', tostring(role)})
  return role
end

--- Ensure that value is a template
-- @param templat [in] the potential template to check
-- @return the qualifier or nil
function _.assert_template(template)
    assert(_.is_template(template), 
           table.concat{'expected template \"', tostring(template), '"'})
    return template
end

--- Split a decl into after ensuring that we don't have an invalid declaration
-- @param decl [in] a table containing at least one {name=defn} entry 
--                where *name* is a string model name
--                and *defn* is a table containing the definition
-- @return name, def
function _.parse_decl(decl)
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
--- X-Types model defined using the DDSL ---
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
  
  -- x-types attributes
  BASE       = function() return ' : ' end,    -- inheritance, e.g. struct base
  SWITCH     = function() return 'switch' end, -- choice: e.g.: union switch
  
  -- Meta-tables that define/control the Public API 
  API = {},
}

--- Is the given model element a qualifier?
-- NOTE: collections are qualifiers
-- @param value [in] the model element to check
-- @return the value (qualifier), or nil if it is not a qualifier 
function _.is_qualifier(value)
  local kind = _.model_kind(value)
  return (xtypes.ANNOTATION == kind) 
         and value
         or nil
end

--- Is the given model element a collection?
-- @param value [in] the model element to check
-- @return the value (collection), or nil if it is not a collection
function _.is_collection(value)
  local kind = value and value[MODEL]
  return (xtypes.ARRAY == kind or
          xtypes.SEQUENCE == kind) 
         and value
         or nil
end

--- Is the given model element an alias (for another type)?
-- @param value [in] the model element to check
-- @return the value (alias), or nil if it is not an alias
function _.is_alias(value)
  local kind = _.model_kind(value)
  return (xtypes.TYPEDEF == kind) 
         and value 
         or nil
end

--- Is the given model element a leaf (ie primitive) type?
-- @param value [in] the model element to check
-- @return the value (leaf), or nil if it is not a leaf type
function _.is_leaf(value)
  local kind = _.model_kind(value)
  return (xtypes.ATOM == kind or 
          xtypes.ENUM == kind)
         and value
         or nil
end

--- --- Is the given model element a template type?
-- @param value [in] the model element to check
-- @return the value (template), or nil if it is not a template type
function _.is_template(value)
  local kind = _.model_kind(value)
  return (xtypes.ATOM == kind or
          xtypes.ENUM == kind or
          xtypes.STRUCT == kind or 
          xtypes.UNION == kind or
          xtypes.TYPEDEF == kind)
        and value
        or nil
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
  local name, defn = _.parse_decl(decl)
  
  -- create the template
  local template = _.new_template(name, xtypes.ANNOTATION, xtypes.API[xtypes.ANNOTATION])
  local model = template[MODEL]
  
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
    instance[MODEL] = model
    setmetatable(instance, xtypes.API[xtypes.ANNOTATION]) -- needed for __tostring()
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

    if output then
      output = string.format('@%s(%s)', annotation[MODEL][_.NAME], output)
    else
      output = string.format('@%s', annotation[MODEL][_.NAME])
    end

    return output
  end,

  __newindex = function (template, key, value)
  -- immutable: do-nothing
  end,

  __call = function(annotation, ...)
    return annotation[MODEL][_.DEFN](...)
  end
}

--------------------------------------------------------------------------------
-- Arrays

-- Arrays are implemented as a special annotations, whose 
-- attributes are positive integer constants, that specify the dimension bounds
-- NOTE: Since an array is an annotation, it can appear anywhere 
--       after a member type declaration; the 1st one is used
local array = xtypes.annotation{Array=EMPTY}
xtypes.ARRAY = array[MODEL]

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
local sequence = xtypes.annotation{Sequence=EMPTY}
xtypes.SEQUENCE = sequence[MODEL]

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
    assert(type(dim)=='number',  
      table.concat{'invalid collection bound: ', tostring(dim)})
    assert(dim > 0 and dim - math.floor(dim) == 0, -- positive integer  
      table.concat{'collection bound must be an integer > 0: ', dim})
  end
  
  -- return the predefined annotation instance, whose attributes are 
  -- the collection dimension bounds
  return annotation(dimensions)
end

--------------------------------------------------------------------------------

xtypes.builtin = xtypes.builtin or {}

--- Built-in annotations
xtypes.builtin.Key = xtypes.annotation{Key=EMPTY}
xtypes.builtin.Extensibility = xtypes.annotation{Extensibility=EMPTY}
xtypes.builtin.ID = xtypes.annotation{ID=EMPTY}
xtypes.builtin.Optional = xtypes.annotation{Optional=EMPTY}
xtypes.builtin.MustUnderstand = xtypes.annotation{MustUnderstand=EMPTY}
xtypes.builtin.Shared = xtypes.annotation{Shared=EMPTY}
xtypes.builtin.BitBound = xtypes.annotation{BitBound=EMPTY}
xtypes.builtin.BitSet = xtypes.annotation{BitSet=EMPTY}
xtypes.builtin.Nested = xtypes.annotation{Nested=EMPTY}
xtypes.builtin.top_level = xtypes.annotation{['top-level']=EMPTY} -- legacy  

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
--     local MyAtom = xtypes.atom{MyAtom=EMPTY}
--     
--  -- Create a dimensioned atomic type:
--     local string10 = xtypes.atom{string={10}}    -- bounded length string
--     local wstring10 = xtypes.atom{wstring={10}}  -- bounded length wstring
function xtypes.atom(decl)
  local name, defn = _.parse_decl(decl)
  local dim, dim_kind = defn[1], _.model_kind(defn[1])
 
  -- pre-condition: validate the dimension
  local dim_value = xtypes.CONST == dim_kind and dim() or dim
  if nil ~= dim then
    assert(type(dim_value)=='number',
      table.concat{'invalid dimension: ', tostring(dim)})
    assert(dim_value > 0 and dim_value - math.floor(dim_value) == 0, 
      table.concat{'dimension must be an integer > 0: ', tostring(dim)})
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
    template = _.new_template(name, xtypes.ATOM, xtypes.API[xtypes.ATOM]) 
    template[MODEL][_.DEFN][1] = dim -- may be nil
    xtypes.builtin[name] = template -- NOTE: install it in the builtin module
  end

  return template
end


--- Atom API meta-table
xtypes.API[xtypes.ATOM] = {

  __tostring = function(template)
    -- the name or the kind (if no name has been assigned)
    return template[MODEL][_.NAME] or
      template[MODEL][_.KIND]() -- evaluate the function
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
xtypes.builtin.boolean = xtypes.atom{boolean=EMPTY}
xtypes.builtin.octet = xtypes.atom{octet=EMPTY}

xtypes.builtin.char= xtypes.atom{char=EMPTY}
xtypes.builtin.wchar = xtypes.atom{wchar=EMPTY}
    
xtypes.builtin.float = xtypes.atom{float=EMPTY}
xtypes.builtin.double = xtypes.atom{double=EMPTY}
xtypes.builtin.long_double = xtypes.atom{['long double']=EMPTY}
    
xtypes.builtin.short = xtypes.atom{short=EMPTY}
xtypes.builtin.long = xtypes.atom{long=EMPTY}
xtypes.builtin.long_long = xtypes.atom{['long long']=EMPTY}
    
xtypes.builtin.unsigned_short = xtypes.atom{['unsigned short']=EMPTY}
xtypes.builtin.unsigned_long = xtypes.atom{['unsigned long']=EMPTY}
xtypes.builtin.unsigned_long_long = xtypes.atom{['unsigned long long']=EMPTY}

--------------------------------------------------------------------------------

--- Define an constant
-- @param decl  [in] a table containing a constant declaration
--                   { name = { xtypes.atom, const_value_of_atom_type } }
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
  local name, defn = _.parse_decl(decl)
       
  -- pre-condition: ensure that the 1st defn declaration is a valid type
  local atom = _.assert_model(xtypes.ATOM, defn[1])
         
  -- pre-condition: ensure that the 2nd defn declaration is a valid value
  local value = defn[2]
  assert(nil ~= value, 
         table.concat{'const value must be non-nil: ', tostring(value)})
  assert((xtypes.builtin.boolean == atom and 'boolean' == type(value) or
         ((xtypes.string() == atom or xtypes.wstring() == atom or xtypes.builtin.char == atom) and 
          'string' == type(value)) or 
         ((xtypes.builtin.short == atom or xtypes.builtin.unsigned_short == atom or 
           xtypes.builtin.long == atom or xtypes.builtin.unsigned_long == atom or 
           xtypes.builtin.long_long == atom or xtypes.builtin.unsigned_long_long == atom or
           xtypes.builtin.float == atom or 
           xtypes.builtin.double == atom or xtypes.builtin.long_double == atom) and 
           'number' == type(value)) or
         ((xtypes.builtin.unsigned_short == atom or 
           xtypes.builtin.unsigned_long == atom or
           xtypes.builtin.unsigned_long_long == atom) and 
           value < 0)), 
         table.concat{'const value must be non-negative and of the type: ', 
                      atom[MODEL][_.NAME] })
         

  -- char: truncate value to 1st char; warn if truncated
  if (xtypes.builtin.char == atom or xtypes.builtin.wchar == atom) and #value > 1 then
    value = string.sub(value, 1, 1)
    print(table.concat{'WARNING: truncating string value for ',
                       atom[MODEL][_.NAME],
                       ' constant to: ', value})  
  end
 
  -- integer: truncate value to integer; warn if truncated
  if (xtypes.builtin.short == atom or xtypes.builtin.unsigned_short == atom or 
      xtypes.builtin.long == atom or xtypes.builtin.unsigned_long == atom or 
      xtypes.builtin.long_long == atom or xtypes.builtin.unsigned_long_long == atom) and
      value - math.floor(value) ~= 0 then
    value = math.floor(value)
    print(table.concat{'WARNING: truncating decimal value for integer constant ', 
                       'to: ', value})
  end

  -- create the template
  local template = _.new_template(name, xtypes.CONST, xtypes.API[xtypes.CONST]) 
  template[MODEL][_.DEFN] = atom
  template[MODEL][_.INSTANCES] = value
  return template
end


--- Const API meta-table
xtypes.API[xtypes.CONST] = {

  __tostring = function(template)
    return template[MODEL][_.NAME] or
      template[MODEL][_.KIND]() -- evaluate the function  
  end,

  __newindex = function (template, key, value)
    -- immutable: do-nothing
  end,

  -- instance value is obtained by evaluating the table:
  -- eg: MY_CONST()
  __call = function(template)
    return template[MODEL][_.INSTANCES]
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
--   MyEnum = xtypes.enum{MyEnum=EMPTY}
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
  local name, defn = _.parse_decl(decl)
    
  -- create the template
  local template = _.new_template(name, xtypes.ENUM, xtypes.API[xtypes.ENUM])

  -- populate the template
  return _.populate_template(template, defn)
end

--- Enum API meta-table
xtypes.API[xtypes.ENUM] = {

  __tostring = function(template) 
    -- the name or the kind (if no name has been assigned)
    return template[MODEL][_.NAME] or 
           template[MODEL][_.KIND]() -- evaluate the function
  end,
  
  __len = function (template)
    return #template[MODEL][_.DEFN]
  end,

  __ipairs = function(template)
    return ipairs(template[MODEL][_.DEFN])
  end,

  __index = function (template, key)
    local model = template[MODEL]
    if _.NAME == key then
      return model[_.NAME]
    elseif _.KIND == key then
      return model[_.KIND]
    else -- delegate to the model definition
       return template[MODEL][_.DEFN][key]
    end
  end,
  
  __newindex = function (template, key, value)

    local model = template[MODEL]
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
--   local MyStruct = xtypes.struct{MyStruct={OptionalBaseStruct}|xtypes.EMPTY}
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
  local name, defn = _.parse_decl(decl)
       
  -- create the template
  local template = _.new_template(name, xtypes.STRUCT, xtypes.API[xtypes.STRUCT])
  template[MODEL][_.INSTANCES] = {}
  
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
    return template[MODEL][_.NAME] or
      template[MODEL][_.KIND]() -- evaluate the function
  end,

  __len = function (template)
    return #template[MODEL][_.DEFN]
  end,

  __ipairs = function(template)
    return ipairs(template[MODEL][_.DEFN])
  end,

  __index = function (template, key)
    local model = template[MODEL]
    if _.NAME == key then
      return model[_.NAME]
    elseif _.KIND == key then
      return model[_.KIND]
    else -- delegate to the model definition
      return template[MODEL][_.DEFN][key]
    end
  end,

  __newindex = function (template, key, value)

    local model = template[MODEL]
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
        old_base[MODEL][_.INSTANCES][template] = nil

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
        for i = 1, #base[MODEL][_.DEFN] do
          local base_role, base_role_defn = next(base[MODEL][_.DEFN][i])

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
        base = base[MODEL][_.DEFN][xtypes.BASE] -- parent base
      end

      -- set the new base in the model definition (may be nil)
      model_defn[xtypes.BASE] = new_base

      -- template is an instance of the base structs (inheritance hierarchy)
      base = new_base
      while base do
        -- NOTE: Use empty string as the 'instance' name of the base struct
        base[MODEL][_.INSTANCES][template] = '' -- empty instance name

        -- visit up the base model inheritance hierarchy
        base = base[MODEL][_.DEFN][xtypes.BASE] -- parent base
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
  local name, defn = _.parse_decl(decl)
       
  -- create the template 
  local template = _.new_template(name, xtypes.UNION, xtypes.API[xtypes.UNION])
  template[MODEL][_.INSTANCES] = {}
 
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
    return template[MODEL][_.NAME] or 
           template[MODEL][_.KIND]() -- evaluate the function
  end,

  __len = function (template)
    return #template[MODEL][_.DEFN]
  end,

  __ipairs = function(template)
    return ipairs(template[MODEL][_.DEFN])
  end,

  __index = function (template, key)
    local model = template[MODEL]
    if _.NAME == key then
      return model[_.NAME]
    elseif _.KIND == key then
      return model[_.KIND]
    else -- delegate to the model definition
       return template[MODEL][_.DEFN][key]
    end
  end,

  __newindex = function (template, key, value)

    local model = template[MODEL]
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
--   for i, v in ipairs(MyModule) do print(v) end
--   for i = 1, #MyModule do print(MyModule[i]) end
--
--  -- Iterate over module namespace (unordered):
--   for k, v in pairs(MyModule) do print(k, v) end
--   
function xtypes.module(decl) 
  local name, defn = _.parse_decl(decl)
       
  --create the template
  local template = _.new_template(name, xtypes.MODULE, xtypes.API[xtypes.MODULE])

  -- populate the template
  return _.populate_template(template, defn)
end

--- Module API meta-table
xtypes.API[xtypes.MODULE] = {

  __tostring = function(template)
    -- the name or the kind (if no name has been assigned)
    return template[MODEL][_.NAME] or
      template[MODEL][_.KIND]() -- evaluate the function
  end,

  __len = function (template)
    return #template[MODEL][_.DEFN]
  end,

  __ipairs = function(template)
    return ipairs(template[MODEL][_.DEFN])
  end,

  __index = function (template, key)
    local model = template[MODEL]
    if _.NAME == key then
      return model[_.NAME]
    elseif _.KIND == key then
      return model[_.KIND]
    else -- delegate to the model definition
      return model[_.DEFN][key]
    end
  end,
  
  __newindex = function (template, key, value)

    local model = template[MODEL]
    local model_defn = model[_.DEFN]
                
    if _.NAME == key then -- set the model name
      rawset(model, _.NAME, value)

    elseif _.QUALIFIERS == key then -- annotation definition
      -- set the new qualifiers in the model definition (may be nil)
      model_defn[_.QUALIFIERS] = _.assert_qualifier_array(value)

    elseif 'number' == type(key) then -- member definition
      -- clear the old member definition and instance fields
      if model_defn[key] then
        local old_role = model_defn[key][MODEL][_.NAME]
        
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
        local role = role_template[MODEL][_.NAME]                  
                     
        -- is the role already defined?
        assert(nil == rawget(template, role),
          table.concat{'member name already defined: "', role, '"'})
            
				-- update the module definition
        model_defn[key] = role_template 
    
        -- move the model element to this module 
        role_template[MODEL][_.NS] = template
        
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
  local name, defn = _.parse_decl(decl)

  -- pre-condition: ensure that the 1st defn element is a valid type
  local alias = defn[1]
  _.assert_template(alias)

  -- pre-condition: ensure that the 2nd defn element if present 
  -- is a 'collection' type
  local collection = defn[2] and _.assert_collection(defn[2])

  -- create the template
  local template = _.new_template(name, xtypes.TYPEDEF, xtypes.API[xtypes.TYPEDEF]) 
  template[MODEL][_.DEFN] = { alias, collection }
  return template
end

--- Atom API meta-table
xtypes.API[xtypes.TYPEDEF] = {

  __tostring = function(template)
    -- the name or the kind (if no name has been assigned)
    return template[MODEL][_.NAME] or
      template[MODEL][_.KIND]() -- evaluate the function
  end,

  __newindex = function (template, key, value)
    -- immutable: do-nothing
  end
}

--------------------------------------------------------------------------------
-- X-Types Error Checking and Validation
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
   elseif xtypes.ENUM == discriminator[MODEL][_.KIND] then -- enum
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
      if xtypes.SEQUENCE == role_defn[i][MODEL] then
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
    output_member = string.format('sequence<%s> %s', _.nsname(template, module), role)
  else -- bounded sequence
    for i = 1, #seq do
      output_member = string.format('%ssequence<', output_member) 
    end
    output_member = string.format('%s%s', output_member, _.nsname(template, module))
    for i = 1, #seq do
      output_member = string.format('%s,%s>', output_member, 
                _.model_kind(seq[i]) and _.nsname(seq[i], module) or tostring(seq[i])) 
    end
    output_member = string.format('%s %s', output_member, role)
  end

  -- member annotations:  
  local output_annotations = nil
  for j = 2, #role_defn do
    
    local name = role_defn[j][MODEL][_.NAME]
    
    if xtypes.ARRAY == role_defn[j][MODEL] then
      for i = 1, #role_defn[j] do
        output_member = string.format('%s[%s]', output_member, 
           _.model_kind(role_defn[j][i]) and 
               _.nsname(role_defn[j][i], module) or tostring(role_defn[j][i]) ) 
      end
    elseif xtypes.SEQUENCE ~= role_defn[j][MODEL] then
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


-- xutils.print_idl() - prints OMG IDL representation of a data model
--
-- Purpose:
-- 		Generate equivalent OMG IDL representation from a data model
-- Parameters:
--    <<in>> model - the data model element
--    <<in>> indent_string - the indentation string to apply
--    <<return>> model, indent_string for chaining
-- Usage:
--         xutils.print_idl(model) 
--           or
--         xutils.print_idl(model, '   ')
function xutils.print_idl(instance, indent_string)
	-- pre-condition: ensure valid instance
	assert(_.model_kind(instance), 'invalid instance')

	local indent_string = indent_string or ''
	local content_indent_string = indent_string
	local model = instance[MODEL]
	local myname = model[_.NAME]
	local mytype = model[_.KIND]
	local mydefn = model[_.DEFN]
  local mymodule = model[_.NS]
  		
	-- print('DEBUG print_idl: ', Data, model, mytype(), myname)
	
	-- skip: atomic types, annotations
	if xtypes.ATOM == mytype or
	   xtypes.ANNOTATION == mytype then 
	   return instance, indent_string 
	end
    
  if xtypes.CONST == mytype then
    local atom = mydefn
    local value = instance()
    local atom = instance[MODEL][_.DEFN]
    if xtypes.builtin.char == atom or xtypes.builtin.wchar == atom then
      value = table.concat{"'", tostring(value), "'"}
    elseif xtypes.string() == atom or xtypes.wstring() == atom then
      value = table.concat{'"', tostring(value), '"'}
    end
     print(string.format('%sconst %s %s = %s;', content_indent_string, 
                        atom, 
                        myname, value))
     return instance, indent_string                              
  end
    
	if xtypes.TYPEDEF == mytype then
		local defn = mydefn	
    print(string.format('%s%s %s', indent_string,  mytype(),
                                    xutils.tostring_role(myname, defn, mymodule)))
		return instance, indent_string 
	end
	
	-- open --
	if (nil ~= myname) then -- not top-level / builtin module
	
		-- print the annotations
		if nil ~=mydefn and nil ~= mydefn[_.QUALIFIERS] then
			for i, annotation in ipairs(mydefn[_.QUALIFIERS]) do
		      print(string.format('%s%s', indent_string, tostring(annotation)))
			end
		end
		
		if xtypes.UNION == mytype then
			print(string.format('%s%s %s switch (%s) {', indent_string, 
						mytype(), myname, model[_.DEFN][xtypes.SWITCH][MODEL][_.NAME]))
						
		elseif xtypes.STRUCT == mytype and model[_.DEFN][xtypes.BASE] then -- base struct
			print(string.format('%s%s %s : %s {', indent_string, mytype(), 
					myname, model[_.DEFN][xtypes.BASE][MODEL][_.NAME]))
		
		else
			print(string.format('%s%s %s {', indent_string, mytype(), myname))
		end
		content_indent_string = indent_string .. '   '
	end
		
	if xtypes.MODULE == mytype then 
		for i, role_template in ipairs(mydefn) do -- walk through the module definition
			xutils.print_idl(role_template, content_indent_string)
		end
		
	elseif xtypes.STRUCT == mytype then
	 
		for i, defn_i in ipairs(mydefn) do -- walk through the model definition
			if not defn_i[MODEL] then -- skip struct level annotations
			  local role, role_defn = next(defn_i)
        print(string.format('%s%s', content_indent_string,
                            xutils.tostring_role(role, role_defn, mymodule)))
			end
		end

	elseif xtypes.UNION == mytype then 
		for i, defn_i in ipairs(mydefn) do -- walk through the model definition
			if not defn_i[MODEL] then -- skip union level annotations
				local case = defn_i[1]
				
				-- case
				if (nil == case) then
				  print(string.format("%sdefault :", content_indent_string))
				elseif (xtypes.builtin.char == model[_.DEFN][xtypes.SWITCH] and nil ~= case) then
					print(string.format("%scase '%s' :", 
						content_indent_string, tostring(case)))
				else
					print(string.format("%scase %s :", 
						content_indent_string, tostring(case)))
				end
				
				-- member element
				local role, role_defn = next(defn_i, #defn_i > 0 and #defn_i or nil)
				print(string.format('%s%s', content_indent_string .. '   ',
				                             xutils.tostring_role(role, role_defn, mymodule)))
			end
		end
		
	elseif xtypes.ENUM == mytype then
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
				
-- @function xutils.index Visit the fields in the instance that are specified 
--           in the model
-- @param instance the instance to index
-- @param result OPTIONAL the index table to which the results are appended
-- @param model OPTIONAL nil means use the instance's model;
--              needed to support inheritance and typedefs
-- @result the cumulative index, that can be passed to another call to this method
function xutils.index(instance, result, model) 
	-- ensure valid instance
	local type_instance = type(instance)
	-- print('DEBUG xutils.index 1: ', instance) 
	assert('table' == type_instance and instance[MODEL] or 
	       'function' == type_instance, -- sequence iterator
		   table.concat{'invalid instance: ', tostring(instance)})
	
	-- sequence iterator
	if 'function' == type_instance then
		table.insert(result, instance())
		
		-- index 1st element for illustration
		if 'table' == type(instance(1)) then -- composite sequence
			xutils.index(instance(1), result) -- index the 1st element 
		elseif 'function' == type(instance(1)) then -- sequence of sequence
			xutils.index(instance(1), result)
		else -- primitive sequence
			table.insert(result, instance(1))
		end
		return result
	end
	
	-- struct or union
	local mytype = instance[MODEL][_.KIND]
	local model = model or instance[MODEL]
	local mydefn = model[_.DEFN]

	-- print('DEBUG index 1: ', mytype(), instance[MODEL][_.NAME])
			
	-- skip if not an indexable type:
	if xtypes.STRUCT ~= mytype and xtypes.UNION ~= mytype then return nil end

	-- preserve the order of model definition
	local result = result or {}	-- must be a top-level type	
					
	-- union discriminator, if any
	if xtypes.UNION == mytype then
		table.insert(result, instance._d)
	end
		
	-- struct base type, if any
	local base = model[_.DEFN][xtypes.BASE]
	if nil ~= base then
		result = xutils.index(instance, result, base[MODEL])	
	end
	
	-- walk through the body of the model definition
	-- NOTE: typedefs don't have an array of members	
	for i, defn_i in ipairs(mydefn) do 		
		-- skip annotations
		if not defn_i[MODEL] then
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

			if 'table' == role_instance_type then -- composite (nested)
					result = xutils.index(role_instance, result)
			elseif 'function' == role_instance_type then -- sequence
				-- length operator
				table.insert(result, role_instance())
	
				-- index 1st element for illustration
				if 'table' == type(role_instance(1)) then -- composite sequence
					xutils.index(role_instance(1), result) -- index the 1st element 
				elseif 'function' == type(role_instance(1)) then -- sequence of sequence
					xutils.index(role_instance(1), result)
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
--- Public Interface (of this module):
local interface = {
  -- empty initializer sentinel value
  EMPTY              = EMPTY,
  
  
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
    
  
  -- utilities
  print_idl          = xutils.print_idl,
  index              = xutils.index,
}

return interface
--------------------------------------------------------------------------------
