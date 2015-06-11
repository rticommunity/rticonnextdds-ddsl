--[[
  (c) 2005-2014 Copyright, Real-Time Innovations, All rights reserved.     
                                                                           
 Permission to modify and use for internal purposes granted.               
 This software is provided "as is", without warranty, express or implied.
--]]
--[[
-----------------------------------------------------------------------------
 Purpose: DDSL: Data type definition Domain Specific Language (DSL) in Lua
 Created: Rajive Joshi, 2014 Feb 14
-----------------------------------------------------------------------------
@module ddsl

SUMMARY

  DDSL is meta-model class implementing the semantic data definition 
  model underlying OMG X-Types. Thus, it can be used to implement 
  OMG X-Types.

USE CASES
 	DDSL serves multiple use-cases:
     - Provides a way of defining OMG IDL equivalent data types (aka models). 
     - Provides for error checking to ensure well-formed type definitions.   
     - Provides a natural way of indexing into a dynamic data sample 
     - Provides a way of creating instances of a data type, for example 
       to stimulate an interface
     - Provides the foundation for automated type (model) reasoning & mapping 
     - Supports multiple styles to specify a type: imperative and declarative
     - Can easily add new (meta-data) types and annotations in the meta-model
     - Extensible: new annotations and atomic types can be easily added, thus
       providing a playground for experimenting with new X-Types features
     - Could be used to automatically serialize and de-serialize a sample
     - Could be used for custom code generation
     - Could be used to generate TypeObject/TypeCode on the wire

 
  Note that in OMG X-Types, referenced data types need to be defined first
    - Forward declarations not allowed
    - Forward references not allowed
  
USAGE
 
    The nomenclature is used to refer to parts of a data type is 
    illustrated using the example below:
    
       // @AnnotationX (qualifier) 
       struct Model {            
          Element1 role1;       // field1  @AnnotationY (qualifier)
          Element2 role2;       // field2
          seq<Element3> role3;  // field3, a collection
          Element4 role4[7][9]  // field4, a multi-dimensional collection
       }   
    where ElementX may be recursively defined as a Model with other parts.

    To create an instance named 'i1' from a model element, Model:
          local i1 = new_instance('i1', Model)
    Now, one can use all the fields of the resulting table, i1. Furthermore, 
    the fields are properly initialized for indexing into DDS dynamic data. 
          i1.role1 = 'i1.role1'

    The leaf elements of the table give a fully qualified string to address a
    field in a dynamic data sample in Lua. 
    
    The [diagram](https://docs.google.com/presentation/d/1UYCS0KznOBapPTgaMkYoG4rC7DERpLhXtl0odkaGOSI/edit#slide=id.g4653da537_05)
    show the DDSL meta-model pictorially.
  
    See xtypes.lua for how to use the DDSL abstraction to define the syntax for
    X-Types in Lua.
    
    See the examples in ddsl-xtypes-tester.lua for user defined X-Types in Lua.

IMPLEMENTATION

    The meta-model pre-defines the following meta-data 
    attributes for a model element (MODEL):

       _.KIND
          Every model represented as a table with a non-nil key
             model[_.KIND] = one of the type definitions
          DDSL meta-model recognizes the following element categories: 
            qualifiers, collections, aliases, leaf, template
          The 'info' interface is used to classify the model elements into one 
          of these categories.
          
       _.NAME
          The name of the model element
   
       _.DEFN
          For storing the child element info
              model[_.DEFN][role] = role model element 

       _.INSTANCES
          For storing instances of this model element, keyed by the instance 
          table. The value is the instance name. The instance name may be ''.
       
       _.TEMPLATE
          The user's 'handle' to the model element.
                 
          It is a special instance used to manipulate the model definition, and 
          create additional instances. Its fields should not be modified. It 
          should be used for accessing a dynamic data sample. New instances 
          should be created from it for storing/caching data samples in Lua.
          
       _.NS
          The namespace model element, to which this model element belongs.
          
   
    An newly created instance (and, therefore also the template instance) will 
    have the following structure:
    <role i.e user_field>
      Either a primitive field
          model.role = 'role'
      Or a composite field 
          model.role = _.new_instance('role', RoleModel)
      or a sequence
          model.role = _.new_instance_collection('role', RoleModel, [capacity])
   
CAVEATS

    Note that if a role definition already exists, it should be cleared before 
    replacing it with a new one.
    
    Note that all the meta-data attributes are functions, so it is 
    straightforward to skip them, when traversing a model table.

-----------------------------------------------------------------------------
--]]

--------------------------------------------------------------------------------
--- Core Attributes and Abstractions ---
--------------------------------------------------------------------------------

local EMPTY = {}  -- initializer/sentinel value to indicate an empty definition
local MODEL = function() return 'MODEL' end -- key for 'model' meta-data 

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
  -- abstract interface that defines the categories of model element (kinds):
  info = {
    is_qualifier_kind = function (v) error('define abstract function!') end,
    is_collection_kind = function (v) error('define abstract function!') end,
    is_alias_kind = function (v) error('define abstract function!') end,
    is_leaf_kind = function (v) error('define abstract function!') end,
    is_template_kind = function (v) error('define abstract function!') end,
  }
}

--------------------------------------------------------------------------------
-- Models  ---
--------------------------------------------------------------------------------
 
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
-- @param #string role - the member name to instantiate (may be '')
-- @param #list<#table> role_defn - array consists of entries in the 
--           { template, [collection,] [annotation1, annotation2, ...] }
--      following order:
--           template - the kind of member to instantiate (previously defined)
--           collection - collection annotation (if any)
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
        iterator = _.new_instance_collection('', iterator, collection[i]) -- unnamed iterator
      end
      role_instance = _.new_instance_collection(role, iterator, collection[1])
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
-- @param template  <<in>> the template to use for creating an instance
-- @return the newly created instance that supports indexing by 'name'
-- @usage
--    -- As an index into DDS dynamic data: sample[]
--    local myInstance = _.new_instance("my", template)
--    local member = sample[myInstance.member] 
--    for i = 1, sample[myInstance.memberSeq()] do -- length of the sequence
--       local element_i = sample[memberSeq[i]] -- access the i-th element
--    end  
--
--    -- As a sample itself
--    local myInstance = _.new_instance("my", template)
--    myInstance.member = "value"
--    for i = 1, 10 do -- length of the sequence
--       myInstance.memberSeq[i] = element_i -- NOTE: capacity is enforced
--    end  
--    print(#myInstance.memberSeq)
--
function _.new_instance(name, template) 
  -- print('DEBUG new_instance 1: ', name, template[MODEL][_.NAME])

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
        -- print('DEBUG new_instance 2: ', name, alias_collection)
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
      iterator = _.new_instance_collection('', iterator, alias_collection[i]) -- unnamed
    end
    instance = _.new_instance_collection(name, iterator, alias_collection[1])
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

-- Creates a collection of instances specified by the template or the instance 
-- collection previously created via this call
-- 
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
--    -- As an index into DDS dynamic data: sample[]
--    local mySeq = _.new_instance_collection("my", template)
--    for i = 1, sample[mySeq()] do -- length accessor for the collection
--       local element_i = sample[mySeq[i]] -- access the i-th element
--    end    
--
--    -- As a sample itself
--    local mySeq = _.new_instance_collection("my", template)
--    for i = 1, 10 do
--        mySeq[i]] = element_i -- access the i-th element
--    end  
--    print(#mySeq) -- the actual number of elements
function _.new_instance_collection(name, template_or_collection, capacity) 
  -- print('DEBUG new_instance_collection', name, template_or_collection)

  _.assert_role(name)
  assert(_.is_instance_collection(template_or_collection) or
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
function _.is_instance_collection(v) 
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

        if _.is_instance_collection(v) then -- collection
            -- multi-dimensional collection
            if '' == v[_.NAME] then sep = '' end 
            
            -- create collection instance for 'prefix'
            result = _.new_instance_collection(table.concat{prefix, sep, v[_.NAME]}, 
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
-- @param namespace [in] the namespace model element; if nil, finds the full 
--                absolute fully qualified name of the model element
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
-- @param role [in] the role name
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

--------------------------------------------------------------------------------
--- Public Interface (of this module):
-- 
local interface = {
  -- empty initializer sentinel value
  EMPTY                   = EMPTY,
  MODEL                   = MODEL,
   
  -- accesors and mutators (meta-attributes for types)
  NS                      = _.NS,
  NAME                    = _.NAME,
  KIND                    = _.KIND,
  DEFN                    = _.DEFN,
  INSTANCES               = _.INSTANCES,
  QUALIFIERS              = _.QUALIFIERS,
  
  -- ddsl operations
  new_template            = _.new_template,
  populate_template       = _.populate_template,
  create_role_instance    = _.create_role_instance,
  update_instances        = _.update_instances,
  
  model_kind              = _.model_kind,
  assert_model            = _.assert_model,
  assert_collection       = _.assert_collection,
  assert_template         = _.assert_template,
  assert_qualifier_array  = _.assert_qualifier_array,
   
  
  -- for users of templates created with ddsl
  nsname                  = _.nsname,
  new_instance            = _.new_instance,
  new_instance_collection = _.new_instance_collection,
  is_instance_collection  = _.is_instance_collection,
}

-- enforce that the user provides a function to binds the 
-- abstract info interface to an implementation
return function (info_impl) _.info = info_impl return interface end
--------------------------------------------------------------------------------
