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
--   { { case, role = { template, [collection,] [annotation1, ...] } } }
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
--          user_role2 = _.new_instance('user_role2', UserModule.UserType2)
--          user_role3 = _.new_instance('user_role3', UserModule.UserType3)
--          user_role_seq = _.new_collection('user_role_seq', 
--                                              UserModule.UserTypeSeq)
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
--          i1 = _.new_instance('i1', Model)
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
--          For storing instances of this model element, indexed by instance 
--          name
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
--              model.role = _.new_instance('role', RoleModel)
--          or a sequence
--              model.role = _.new_collection('role', RoleModel)
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
--    first as an empty definition, and then as a full definition. Ignore the 
--    warning!
--

local EMPTY = {}  -- initializer/sentinel value to indicate an empty definition
local MODEL = function() return 'MODEL' end -- key for 'model' meta-data 

--- DDSL Core Engine ---
local _ = {
  -- model attributes
  -- every 'model' meta-data table has these keys defined 
  NS        = function() return '' end,      -- namespace
  NAME      = function() return 'NAME' end,  -- table key for 'model name'  
  KIND      = function() return 'KIND' end,  -- table key for 'model kind name' 
  DEFN      = function() return 'DEFN' end,  -- table key for element meta-data
  INSTANCES = function() return 'INSTANCES' end,-- table key for instances
  TEMPLATE  = function() return 'TEMPLATE' end,--table key for template instance

  -- model definition attributes
  QUALIFIERS = function() return '' end,        -- table key for qualifiers
  
  -- model info interface
  -- abstract interface that define the categories of model interface
  info = {
    is_qualifier_kind = function (v) error('define abstract function!') end,
    is_collection_kind = function (v) error('define abstract function!') end,
    is_alias_kind = function (v) error('define abstract function!') end,
    is_leaf_kind = function (v) error('define abstract function!') end,
    is_template_kind = function (v) error('define abstract function!') end,
  }
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

--------------------------------------------------------------------------------
-- Models  ---
--------------------------------------------------------------------------------
  
--- Populate a template
-- @param template  <<in>> a template, generally empty
-- @param defn      <<in>> template model definition
-- @return populated template 
function _.populate_template(template, defn)
  -- populate the role definitions
  local qualifiers
  for i, defn_i in ipairs(defn) do 

    -- build the model level annotation list
    if _.info.is_qualifier_kind(defn_i) then        
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
      collection = _.info.is_collection_kind(role_defn[j])
    end
  end

  -- populate the role_instance fields
  local role_instance = nil

  if role then -- skip member instance if role is not specified 
    if collection then
      local iterator = template
      for i = #collection, 2, -1  do -- create iterator for inner dimensions
        iterator = _.new_collection('', iterator, collection[i]) -- unnamed iterator
      end
      role_instance = _.new_collection(role, iterator, collection[1])
    else
      role_instance = _.new_instance(role, template)
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
          rawset(instance, role, _.clone(name, role_template))
      end
   end
end

--------------------------------------------------------------------------------
-- Model Instances  ---
--------------------------------------------------------------------------------
       
--- Create an instance, using another instance as a template
--  Defines a table that can be used to index into an instance of a model
-- 
-- @param name      <<in>> the role|instance name
-- @param template  <<in>> the template to use for creating an instance; 
--                         must be a model table 
-- @return the newly created instance (seq) that supports indexing by 'name'
-- @usage
--    -- As an index into sample[]
--    local myInstance = _.new_instance("my", template)
--    local member = sample[myInstance.member] 
--    for i = 1, sample[myInstance.memberSeq()] do -- length of the sequence
--       local element_i = sample[memberSeq(i)] -- access the i-th element
--    end  
--
--    -- As a sample itself
--    local myInstance = _.new_instance("my", template)
--    myInstance.member = "value"
--
--    -- NOTE: Assignment not yet supported for sequences:
--    myInstance.memberSeq() = 10 -- length
--    for i = 1, myInstance.memberSeq() do -- length of the sequence
--       memberSeq(i) = "element_i"
--    end  
--
function _.new_instance(name, template) 
  -- print('DEBUG xtypes.create_instance 1: ', name, template[MODEL][_.NAME])

  _.assert_role(name)
  _.assert_template(template)
 
  local instance = nil
  
  ---------------------------------------------------------------------------
  -- alias? switch the template to the underlying alias
  ---------------------------------------------------------------------------
  local is_alias_kind = _.info.is_alias_kind(template)
  local alias, alias_collection
  
  if is_alias_kind then
    local defn = template[MODEL][_.DEFN]
    alias = defn[1]
    
    for j = 2, #defn do
      alias_collection = _.info.is_collection_kind(defn[j])
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
    for i = #alias_collection, 2, - 1  do -- create for inner dimensions
      iterator = _.new_collection('', iterator, alias_collection[i]) -- unnamed
    end
    instance = _.new_collection(name, iterator, alias_collection[1])
    return instance
  end
  
  ---------------------------------------------------------------------------
  -- alias is recursive:
  ---------------------------------------------------------------------------

  if is_alias_kind and _.info.is_alias_kind(alias) then
    instance = _.new_instance(name, template) -- recursive
    return instance
  end

  ---------------------------------------------------------------------------
  -- leaf instances
  ---------------------------------------------------------------------------
 
  if _.info.is_leaf_kind(template) then
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
      instance[k] = _.clone(name, v)
    end
  end

  -- cache the instance, so that we can update it when the model changes
  model[_.INSTANCES][instance] = name

  return instance
end

-- Name: 
--    _.new_collection() - creates a collection of instances specified by 
--                         the template or collection of instances
-- Purpose:
--    Define new named collection of instances
-- Parameters:
--    <<in>> name  - the collection instance name
--    <<in>> template_or_collection - the template or collection to use
--               may be an instance table when it is an non-collection type OR
--               may be a collection table for a collection of collection
--    <<in>> capacity - the capacity, ie the maximum number of instances
--                      maybe nil (=> unbounded)
--    <<returns>> the newly created collection of instances
-- Usage:
--    local mySeq = _.new_collection("my", template)
--    for i = 1, sample[mySeq()] do -- length accessor for the collection
--       local element_i = sample[mySeq[i]] -- access the i-th element
--    end    
function _.new_collection(name, template_or_collection, capacity) 
  -- print('DEBUG create_collection', name, template_or_collection)

  _.assert_role(name)
  assert(_.is_collection_instance(template_or_collection) or
         _.info.is_template_kind(template_or_collection),
         table.concat{'create_collection(): needs a template or collection'})
  
  -- convert capacity model element into its value
  if _.model_kind(capacity) then capacity = capacity() end
  assert(nil == capacity or 'number' == type(capacity),
         table.concat{'create_collection(): invalid capacity'})
    
  -- create collection instance
  local collection = { 
     [_.NAME]      = name, 
     [_.TEMPLATE]  = template_or_collection,
     [_.INSTANCES] = capacity,
   }
  
  -- set the template meta-table:
  setmetatable(collection, _.collection_metatable)

  return collection
end

-- Is the given value a collection of instances:
function _.is_collection_instance(v) 
  return getmetatable(v) == _.collection_metatable
end

_.collection_metatable = {    
  __call = function (collection)
      -- the accessor for collection length
      -- NOTE: the length operator returns the actual number of elements
      return string.format('%s#', collection[_.NAME])
  end,
  
  __index = function (collection, i)
      -- print('DEBUG collection __index', collection, i)
      if 'number' ~= type(i) then
        -- print('DEBUG collection __index.1', collection, i)
        return nil 
      end 

      -- enforce capacity
      local capacity = rawget(collection, _.INSTANCES) or nil
      if capacity and i > collection[_.INSTANCES] then
        error(string.format('#%s: index %d exceeds collection capacity', 
                              collection, i),
              2)
      end
          
      -- NOTE: we got called because collection[i] does not exist
      local name_i = string.format('%s[%d]', collection[_.NAME], i)
      local element_i = _.clone(name_i, collection[_.TEMPLATE])
      
      rawset(collection, i, element_i)
      return element_i
  end,
  
  __newindex = function (collection, i, v)
      -- print('DEBUG collection __newindex', collection, i, v)
      local element_i = collection[i]
      if 'table' ~= type(element_i) then -- replace with the new value
        element_i = v
        rawset(collection, i, element_i)
      else 
        -- NOTE: In order to preserve the integrity of the user defined data 
        -- types, we only allow assignment of leaf elements. Thus, wholesale
        -- assignment of a composite or collection element is not allowed. 
        -- 
        -- Generally, this is not an issue, as the composite or collection
        -- tables will be further dereferenced by a . or [] operator 
        error(string.format('#%s: assignment not permitted for ' ..
                            'non-leaf member %s', 
                            collection, element_i[_.NAME]),
              2)
      end
      return element_i
  end,

  __tostring = function (collection)
      local capacity = rawget(collection, _.INSTANCES) or ''
      return string.format('%s{%s}<%s', 
                          collection[_.NAME], collection[_.TEMPLATE], capacity)
  end,
}

--- Clone a new instance from another instance using the given 'name' prefix
-- @param name [in] name (maybe empty, '') to prefix the instance fields with 
-- @param v [in] an instance (maybe collection) with properly initialized fields  
-- @return new instance with fields properly initialized for 'prefix'
function _.clone(prefix, v) 

    local type_v = type(v)
    local result 
    
    --  decide on the separator
    local sep = '.' -- default separator
    if 
      '' == prefix or                          -- empty prefix (unnamed clone)
      '#' == v                                 -- union discriminator: _d      
    then
      sep = ''      
    end
    
    -- clone the instance  
    if 'table' == type_v then -- collection or struct or union

        if _.is_collection_instance(v) then -- collection
            -- multi-dimensional collection
            if '' == v[_.NAME] then sep = '' end 
            
            -- create collection instance for 'prefix'
            result = _.new_collection(table.concat{prefix, sep, v[_.NAME]}, 
                                      v[_.TEMPLATE], v[_.INSTANCES])  
        else -- not collection: struct or union
            -- create instance for 'prefix'
            result = _.new_instance(prefix, v) -- use member as template   
        end
        
    elseif 'string' == type_v then -- leaf
        -- create instance for 'prefix'
        result = table.concat{prefix, sep, v}
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
    assert(_.info.is_collection_kind(collection), 
           table.concat{'expected collection \"', tostring(collection), '"'})
    return collection
end

--- Ensure that value is a qualifier
-- @param qualifier [in] the potential qualifier to check
-- @return the qualifier or nil
function _.assert_qualifier(qualifier)
    assert(_.info.is_qualifier_kind(qualifier), 
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
-- @return the template or nil
function _.assert_template(template)
    assert(_.info.is_template_kind(template), 
           table.concat{'unexpected template kind \"', tostring(template), '"'})
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
--- Public Interface (of this module):
-- 
local interface = {
  -- empty initializer sentinel value
  EMPTY                  = EMPTY,
  MODEL                  = MODEL,
   
  -- accesors and mutators (meta-attributes for types)
  NS                     = _.NS,
  NAME                   = _.NAME,
  KIND                   = _.KIND,
  DEFN                   = _.DEFN,
  INSTANCES              = _.INSTANCES,
  QUALIFIERS             = _.QUALIFIERS,
  
  -- operations
  parse_decl             = _.parse_decl,
  new_template           = _.new_template,
  populate_template      = _.populate_template,
  create_role_instance   = _.create_role_instance,
  update_instances       = _.update_instances,
  
  model_kind             = _.model_kind,
  assert_model           = _.assert_model,
  assert_collection      = _.assert_collection,
  assert_template        = _.assert_template,
  assert_qualifier_array = _.assert_qualifier_array,
  
  -- new_instance        = _.new_instance,
  -- new_collection      = _.new_collection,
  is_collection_instance = _.is_collection_instance,  -- for index (generalize?)
  
  nsname                 = _.nsname,
  
  
  -- abstract interface --> implementation to be provided by the user
  info                  = function (info_impl) _.info = info_impl end,
}

return interface
--------------------------------------------------------------------------------
