--[[
  (c) 2005-2014 Copyright, Real-Time Innovations, All rights reserved.     
                                                                           
 Permission to modify and use for internal purposes granted.               
 This software is provided "as is", without warranty, express or implied.
--]]

--- DDSL Core Abstraction; see `ddsl.xtypes` for a concrete implementation.
-- 
-- Core primitives for the Datatype definition Domain Specific Language 
-- (DDSL). Defines and implements the DDSL meta-model. The core primitive
-- abstractions are:
-- 
--   - datatype (a.k.a. datamodel or model)
--   - instance
--   - collection
--   - alias
--   - qualifier
-- 
-- These primitives can be used to define datatypes according to a set of 
-- datatype construction rules (for example, `ddsl.xtypes`). Thus, DDSL can be 
-- thought of as a meta-model class implementing the semantic data 
-- definition model underlying OMG X-Types.
-- 
-- The DDSL core engine provides the infrastructure to create instances and 
-- instance collections backed by datatypes, to manipulate the underlying 
-- datatypes, keep all the instances in sync with the underlying datatypes.
-- 
-- A datatype is a blueprint for a data structure. Any
-- number of data-objects or instances (a.k.a. `xinstance`) can be created 
-- from a datatype. Every instance is backed by an underlying datatype. The 
-- underlying datatype is never exposed directly; it is always manipulated 
-- through any one of its instances. Thus, any instance can used as a handle 
-- to manipulate the underlying datatype. Any changes made to the underlying
-- datatype are propagated to all its instances---thus keeping all the 
-- instances in "sync" with the underlying datatype.
-- 
-- Any instance can be used as a constructor for new instances of the underlying
-- datatype---when used in this manner, an instance can be thought of as a
-- *template* for creating new instances. More specifically, we refer
-- to the instance returned by a datatype constructor as the *template instance* 
-- (a.k.a. `xtemplate`) for that datatytpe. It is used as the 
-- *cannonical* template instance for creating other instances of the datatype,
-- and as the handle for manipulating the datatype. Its fields should not be 
-- altered, as they are used to initialize the fields of new instances 
-- created from it.
-- 
-- The 
-- [diagram](https://docs.google.com/presentation/d/1UYCS0KznOBapPTgaMkYoG4rC7DERpLhXtl0odkaGOSI/edit#slide=id.ga31862cc3_0_22)
-- shows the DDSl meta-model.
-- 
-- **Nomenclature**
-- 
-- This documentation uses the following nomenclature to refer to parts 
-- of a datatype. Below, the nomenclature is illustrated using an IDL example.
--     // @AnnotationX (annotations are 'qualifiers')
--     struct Model {              //  Datatype
--        Element1 role1;          //  @AnnotationY (a 'qualifier')
--        Element2 role2;          //
--        sequence<Element3> role3;// a one-dimensional 'collection'
--        Element4 role4[7][9]     // a multi-dimensional 'collection'
--     }   
--  where `ElementX` may be recursively defined as another Model (i.e. datatype)
--  composed of other elements.
--   
--  To create an instance (`xinstance`) named `i1` from a datatytype
--  named `Model`:
--        local i1 = `new_instance`(Model, 'i1')
--  Now, one can use all the fields of the resulting table, `i1`. Furthermore, 
--  the fields are properly initialized for indexing into a storage scheme based
--  on flattening out the field names.
--        i1.role1 == 'i1.role1'
--
--  More precisely, a newly created `xinstance` (and, therefore also the 
--  `xtemplate`) will have the fields initialized as follows.
--
--   - For a primitive (i.e. atomic) member role:
--        role = 'role'
--   - For a composite member role:
--        roleX = `new_instance`(ElementX, 'roleX')
--   - For a collection member role (sequences or arrays):
--        roleY = `new_collection`(ElementY, capacity, 'roleY')
--          
-- @module ddsl
-- @alias _
-- @author Rajive Joshi

--============================================================================--
-- Core Attributes and Abstractions

local _ = {
  --- Initializer/sentinel value to indicate an empty datatype definition.
  EMPTY = {},

  --- Attributes.
  -- Every `xinstance` has a metatable that implements the following attributes.
  -- @section Attributes

  --- The namespace model element, to which this model element belongs.
  NS        = function() return '::' end,      -- namespace
  
  --- The name of the model element
  NAME      = function() return 'NAME' end,  -- table key for 'model name'  

  --- Every model represented as a table with a non-nil key
  --     model[KIND] = one of the type definitions
  --  DDSL meta-model recognizes the following element categories: 
  --  qualifiers, collections, aliases, leaf, template
  --  The 'info' interface is used to classify the model elements into one 
  --  of these categories.
  KIND      = function() return 'KIND' end,  -- table key for 'model kind name' 

  --- model definition attributes
  QUALIFIERS = function() return '@' end,      -- table key for qualifiers
     
  --- For storing the child element info
  --     model[_.DEFN][role] = role model element 
  DEFN      = function() return 'DEFN' end,  -- table key for element meta-data

  --- For storing instances of this model element, keyed by the instance 
  --  table. The value is the instance name. The instance name may be ''.
  INSTANCES = function() return 'INSTANCES' end,-- table key for instances
 
  --- The user's 'handle' to the model element.                
  --  It is a special instance used to manipulate the model definition, and 
  --  create additional instances. Its fields should not be modified. It 
  --  should be used for accessing a dynamic data sample. New instances 
  --  should be created from it for storing/caching data samples in Lua. 
  TEMPLATE  = function() return 'TEMPLATE' end,--table key for template instance
  
  --- @section end
  
  --============================== ===========================================--
  
  --- Model info **abstract** interface.
  -- Abstract interface that defines the categories of model element (kinds).
  -- Concerete implementation of a typesystem spply the concrete functions.
  -- 
  -- Each function takes an `xinstance` and returns it if the kind matches, 
  -- otherwise, returns `nil`.
  info = {
    is_qualifier_kind = function (v) error('define abstract function!') end,
    is_collection_kind = function (v) error('define abstract function!') end,
    is_alias_kind = function (v) error('define abstract function!') end,
    is_leaf_kind = function (v) error('define abstract function!') end,
    is_template_kind = function (v) error('define abstract function!') end,
  }
}

--============================================================================--
-- logger

local logger = require('logger')

--- `logger` to log messages and get/set the verbosity levels
_.log = logger.new()

-- extend logger: add a function to get the version:
_.log.version = require('ddsl.version')

--============================================================================--
-- Models 

--- Create a new 'empty' template
-- @param name  [in] the name of the underlying model
-- @param api   [in] a meta-table to control access to this template
-- @return template, model: a new template and its model
-- @within Constructors
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

  -- copy the meta-table methods to the 'model', and make it the metatable
  for k, v in pairs(api) do model[k] = v end
  setmetatable(template, model)

  return template, model
end
 
--- Populate a template
-- @param template  <<in>> a template, generally empty
-- @param defn      <<in>> template model definition
-- @return populated template 
-- @within Constructors
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
-- @within Constructors
function _.create_role_instance(role, role_defn)
  
  _.assert_role(role)
  
  local template = role_defn[1]
  _.assert_template_kind(template) 
  
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
        iterator = _.new_collection(iterator, collection[i], '', true) -- empty
      end
      role_instance = _.new_collection(iterator, collection[1], role, true)
    else
      role_instance = _.new_instance(template, role, true)
    end
  end
  
  return role_instance, role_defn
end


--- Propagate member 'role' update to all instances of a model
-- @param model [in] the model 
-- @param role [in] the role to propagate
-- @param role_template [in] template role instance created 
--                           using create_role_instance()
-- @within Modifiers                          
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
          rawset(instance, role, _.clone(role_template, name))
      end
   end
end

--============================================================================--
-- Instances
      
--- Create an instance, using another instance as a template
--  Defines a table that can be used to index into an instance of a model
-- 
-- @param template  <<in>> the template to use for creating an instance
-- @param name      <<in>> the template role name; maybe nil
--                         non-nil => creating a template instance 
--                         nil => creating an instance for holding data
-- @param is_role_instance <<in>> is this part of a role instance, i.e.
--                   does this instance belong to a template? (default: nil)
-- @return the newly created instance that supports indexing by 'name'
-- @usage
--    -- As an index into DDS dynamic data: sample[]
--    -- MyType.member = _.new_instance(Member, "member")
--    local member = sample[MyType.member] 
--
--    -- As a sample itself
--    local myInstance = _.new_instance(MyType)
--    myInstance.member = "value"
--
-- @within Constructors       
function _.new_instance(template, name, is_role_instance) 
  local model = getmetatable(template)
  _.log.trace('new_instance 1: ', model[_.NAME], name)

  if nil ~= name then _.assert_role(name) end
  _.assert_template_kind(template)
 
  local instance = nil
  
  --========================================================================--
  -- alias? switch the template to the underlying alias
  
  local is_alias_kind = _.info.is_alias_kind(template)
  local alias, alias_collection
  
  if is_alias_kind then
    local defn = model[_.DEFN]
    alias = defn[1]
    
    for j = 2, #defn do
      alias_collection = _.info.is_collection_kind(defn[j])
      if alias_collection then
        _.log.trace('new_instance 2: ', alias_collection, name)
        break -- 1st 'collection' is used
      end
    end
  end

  -- switch template to the underlying alias
  if alias then template = alias end
   
  --========================================================================--
  -- alias is a collection:
 
  -- collection of underlying types (which is not an alias)
  if alias_collection then
    local iterator = template
    for i = #alias_collection, 2, - 1  do -- create for inner dimensions:unnamed
      iterator = _.new_collection(iterator, alias_collection[i], '',
                is_role_instance)
    end
    instance = _.new_collection(iterator, alias_collection[1], name, 
                is_role_instance)
    return instance
  end
  
  --========================================================================--
  -- alias is recursive:

  if is_alias_kind and _.info.is_alias_kind(alias) then
    instance = _.new_instance(template, name, is_role_instance) -- recursive
    return instance
  end

  --========================================================================--
  -- leaf instances

  if _.info.is_leaf_kind(template) then
    instance = name 
    return instance
  end
  
  --========================================================================--
  -- composite instances 
 
  -- Establish the underlying model definition to create an instance
  -- NOTE: aliases do not hold any instances; the instances are held by the
  --       underlying concrete (non-alias) alias type
  model = getmetatable(template)

  -- create the instance:
  local instance = {}
 
  for k, v in pairs(template) do
    -- skip meta-data attributes
    if 'string' == type(k) then
      instance[k] = _.clone(v, name, is_role_instance)
    end
  end

  setmetatable(instance, model)
 
  -- cache the instance, so that we can update it when the model changes
  model[_.INSTANCES][instance] = name

  return instance
end

--- Creates a collection template comprising of elements specified by the 
-- given template or the collection (previously created via this call)
-- 
-- Purpose:
--    Define new named collection of instances
-- Parameters:
-- @param content_template <<in>> - the template describing collection elements 
--               may be an instance table i.e. non-collection type OR
--               may be a collection table i.e. a collection of collections
-- @param capacity - the capacity, ie the maximum number of instances
--                      maybe nil (=> unbounded)
-- @param name <<in>> the template role name; maybe nil
--                         non-nil => creating a template instance 
--                         nil => creating an instance for holding data
-- @param is_role_instance <<in>> is this part of a role instance, i.e.
--                   does this instance belong to a template? (default: nil)
-- @return returns the newly created collection
-- Usage:
--    -- As an index into DDS dynamic data: sample[]
--    -- MyType.mySeq = _.new_collection(MySeq, "mySeq")
--    for i = 1, sample[#MyType.mySeq] do -- length accessor for the collection
--       local element_i = sample[MyType.mySeq[i]] -- access the i-th element
--    end    
--
--    -- As a sample itself
--    local myInstance = _.new_collection(MyType)
--    for i = 1, 10 do
--        myInstance.mySeq[i] = element_i -- access the i-th element
--    end  
--    print(#myInstance.mySeq) -- the actual number of elements
-- @within Constructors
function _.new_collection(content_template, capacity, name, is_role_instance) 
  _.log.trace('new_collection',content_template,capacity,name)

  if nil ~= name then _.assert_role(name) end
  assert(_.is_collection(content_template) or
         _.info.is_template_kind(content_template),
         table.concat{'new_collection(): needs a template or collection'})
  
  -- convert capacity model element into its value
  if _.model_kind(capacity) then capacity = capacity() end
  assert(nil == capacity or 'number' == type(capacity),
         table.concat{'create_collection(): invalid capacity'})
    
  -- create collection instance
  local model = {
     [_.NAME]      = name or '', 
     [_.DEFN]      = { content_template, capacity },
     [_.INSTANCES] = {}, -- the collection of instances 
     [_.TEMPLATE]  = nil,-- non-nil iff is_role_instance (ie part of a template)
  }
  local collection = model[_.INSTANCES]

  -- copy the meta-table methods to the 'model', and make it the metatable
  for k, v in pairs(_.collection_metatable) do model[k] = v end

  -- Does this instance belong to a part of a template?
  if is_role_instance then -- yes
     model[_.TEMPLATE] = collection -- this instance belongs to template!

  
  else -- no
      -- The __len metamethod is needed only for collections belonging to 
      -- a template instance. 
      --
      -- For non-template collection instances, we won't define the __len 
      -- metamethod. Thus the rawleng would be invoked, returning the actual 
      -- length (and this is the fast!)
  
      _.log.trace('new_collection',model.__len,name,content_template,capacity)
      model.__len = nil
  end            

  setmetatable(collection, model)      
  return collection
end


--- Create new named collection of instances based on another collection 
-- Parameters:
-- @param collection  <<in>>  - the template collection 
-- @param name <<in>> the template role name; maybe nil
-- @param is_role_instance <<in>> is this part of a role instance, i.e.
--                   does this instance belong to a template? (default: nil)
-- @return the newly created collection with the given name, and the given
--         collection as the "collection template"
-- @within Constructors
function _.new_collection_instance(collection, name, is_role_instance) 

  local model = getmetatable(collection)   
  
  --  decide on the separator
  local sep = '.'
  if nil == name or  '' == name or  '' == model[_.NAME] then
     sep = ''
  end

  -- create a new collection instance                         
  local new_collection_instance = _.new_collection(
                                model[_.DEFN][1], -- element template
                                model[_.DEFN][2], -- capacity
                                table.concat{name or '', sep, model[_.NAME]},
                                is_role_instance) 

  -- Does this instance belong to a part of a template?
  if not is_role_instance then -- no!
      -- sets its template to the collection we used to create this instance
      local new_collection_model = getmetatable(new_collection_instance)
      new_collection_model[_.TEMPLATE] = collection
  end

  return new_collection_instance                              
end             
                        
-- Is the given value a collection of instances:
function _.is_collection(v) 
  local model = getmetatable(v)
  return model and model[_.KIND] == _.collection_metatable[_.KIND]
end

_.collection_metatable = {    
  [_.KIND] = function() return 'collection' end,

  -- return the capacity; a 'nil' value means that capacity is unbounded 
  __call = function (collection)
     local model = getmetatable(collection)
     local capacity = model[_.DEFN][2] or nil
     return capacity
  end,
  
  __len = function (collection)
      -- NOTE: defined for template instances (i.e. is_role_instance) only
      -- the accessor for collection length
      local model = getmetatable(collection)
      return string.format('%s#', model[_.NAME] or '')
  end,

  __index = function (collection, i)
      _.log.trace('collection __index', collection, i)
      if 'number' ~= type(i) then
        _.log.trace('collection __index.1', collection, i)
        return nil 
      end 
      
      -- enforce capacity
      local model = getmetatable(collection)
      local capacity = model[_.DEFN][2] or nil
      if capacity and i > capacity then
        error(string.format('#%s: index %d exceeds collection capacity of %d', 
                              collection, i, capacity),
              2)
      end
          
      -- NOTE: we got called because collection[i] does not exist
      local name_i = string.format('%s[%d]',model[_.NAME] or '', i)
      local element_i = _.clone(model[_.DEFN][1], name_i, 
                                collection == model[_.TEMPLATE])
      
      rawset(collection, i, element_i)
      return element_i
  end,
  
  __newindex = function (collection, i, v)
      _.log.trace('collection __newindex', collection, i, v)
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
                            collection, getmetatable(element_i)[_.NAME]),
              2)
      end
      return element_i
  end,

  __tostring = function (collection)
      local model = getmetatable(collection)
      local capacity = model[_.DEFN][2] or ''
      return string.format('%s{%s}<%s', model[_.NAME] or '',
                                        model[_.DEFN][1],capacity)
  end,
}

--- Clone a new instance from another instance using the given 'name' prefix
-- @param v [in] an instance (maybe collection) with properly initialized fields
-- @param prefix [in] the name to prefix the instance fields with (maybe nil)
--                    non-nil => creating a template instance
--                    nil     => creating a user instance for holding data
-- @param is_role_instance <<in>> is this part of a role instance, i.e.
--                   does this instance belong to a template? (default: nil)
-- @return new instance with fields properly initialized for 'prefix'
-- @within Constructors
function _.clone(v, prefix, is_role_instance) 

    local type_v = type(v)
    local result 
        
    -- clone the instance  
    if 'table' == type_v then -- collection or struct or union

        if _.is_collection(v) then -- collection
            -- create collection instance for 'prefix'
            result = _.new_collection_instance(v, prefix, is_role_instance)  
        else -- not collection: struct or union
            -- create instance for 'prefix' 
            result = _.new_instance(v, prefix, is_role_instance) 
        end
        
    elseif 'string' == type_v then -- leaf
        --  decide on the separator
        local sep = '.' -- default separator
        if 
          nil == prefix or          -- not a template instance
          '' == prefix or           -- empty prefix (unnamed clone)
          '#' == v                  -- union discriminator: _d      
        then
          sep = ''      
        end
 
        -- create instance for 'prefix'
        result = table.concat{prefix or '', sep, v} -- prefix may be nil
    end
    
    return result
end

--============================================================================--
-- Retrievers

--- Retrieve the model definition underlying an instance
-- The instance would have been created previously using 
--    `new_instance`() or 
--    `new_collection`() or 
--    `new_template`() for a "template" instance
-- @param instance [in] the instance whose model we want to retrieve
-- @return the underlying data model
-- @within Retrievers
function _.model(instance)
  return getmetatable(instance)
end

--- Retrieve the template instance for the given instance
-- The instance would have been created previously using 
--      _.new_instance() or 
--      _.new_collection() or 
--      _._new_template() for a "template" instance
-- @param instance [in] the instance whose template we want to retrieve
-- @return the underlying template
-- @within Retrievers
function _.template(instance)
  local model = getmetatable(instance)
  return model and model[_.TEMPLATE]
end

--- Resolve the alias template to the underlying non-alias template
-- @param template [in] the data model element to resolve 
-- @return the underlying non-alias data model template, unwrapping the 
--         all the collection qualifiers
--         [ [collection_qualifier] ... ] <Non-Alias Template>
-- @within Retrievers
function _.resolve(template)
  local is_alias_kind = template and _.info.is_alias_kind(template)
  if is_alias_kind then
    local alias, collection_qualifier = template()
    if collection_qualifier then
      return collection_qualifier, _.resolve(alias)
    else
      return _.resolve(alias) 
    end
  else 
    return template
  end
end

--- Qualified (scoped) name of a model element relative to a namespace. 
-- Computes the shortest 'distance' (scoped name) to navigate to template 
-- from namespace.
-- 
-- Note that a namespace without an enclosing (NS) namespace and without 
-- a name is a 'root' namespace (i.e the outermost enclosing scope).  
-- @param template [in] the data model element whose qualified name is 
--        desired in the context of the namespace
-- @param namespace [in] the namespace model element; if nil, defaults to the 
--        outermost enclosing scope
-- @return the name of the template relative to the namespace; may be nil
--         (for example when template == namespace) 
-- @within Retrievers
function _.nsname(template, namespace)
  -- pre-conditions:
  assert(nil ~= _.model_kind(template), "nsname(): not a valid template")
  assert(nil == namespace or nil ~= _.model_kind(namespace), 
                                        "nsname(): not a valid namespace")
                           
  -- traverse up the template namespaces, until 'namespace' is found
  local model = getmetatable(template)
  if template == namespace then
    return nil 
  elseif namespace == model[_.NS] or nil == model[_.NS] then
    return model[_.NAME] -- may be nil
  else
    local scopename = _.nsname(model[_.NS], namespace)
    return scopename 
           and table.concat{scopename, '::', model[_.NAME]}
           or  model[_.NAME] 
  end
end

--- Get the root namespace i.e. the outermost enclosing scope for an instance.
-- @param template[in] the instance (or template) whose root is to be determined
-- @return the root namespace ie. the outermost enclosing scope (maybe template)
-- @within Retrievers
function _.nsroot(template)
  -- pre-conditions:
  assert(nil ~= _.model_kind(template), "nsroot(): not a valid template")

  -- traverse up the instance namespace, until 'namespace' is found
  local model = getmetatable(template)
  if model[_.NS] then
    return _.nsroot(model[_.NS])
  else 
    return template -- template is the outermost enclosing scope
  end 
end


--============================================================================--
-- Helpers

--- Get the model type of any arbitrary value
-- @param value  [in] the value for which to retrieve the model type
-- @return the model type or nil (if 'value' does not have a MODEL)
-- @within Helpers
function _.model_kind(value)
  local model = getmetatable(value)
  return model and model[_.KIND]
end

--- Ensure that the value is a model element
-- @param kind   [in] expected model element kind
-- @param value  [in] table to check if it is a model element of "kind"
-- @return the value if the kind matches, or nil
-- @within Helpers
function _.assert_model_kind(kind, value)
    local model = getmetatable(value)
    assert(model and kind == model[_.KIND],
           table.concat{'expected model kind "', kind(), 
                        '", instead got "', tostring(value), '"'})
    return value
end

--- Ensure that value is a qualifier
-- @param qualifier [in] the potential qualifier to check
-- @return the qualifier or nil
-- @within Helpers
function _.assert_qualifier(qualifier)
    assert(_.info.is_qualifier_kind(qualifier), 
           table.concat{'expected qualifier \"', tostring(qualifier), '"'})
    return qualifier
end

--- Ensure all elements in the 'value' array are qualifiers
-- @param value [in] the potential qualifier array to check
-- @return the qualifier array or nil
-- @within Helpers
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
-- @within Helpers
function _.assert_role(role)
  assert('string' == type(role), 
      table.concat{'invalid role name: ', tostring(role)})
  return role
end

--- Ensure that value is a template
-- @param template [in] the potential template to check
-- @return the template or nil
-- @within Helpers
function _.assert_template_kind(template)
    assert(_.info.is_template_kind(template), 
           table.concat{'unexpected template kind \"', tostring(template), '"'})
    return template
end

--============================================================================--
-- Public Interface (of this module):

local interface = {
  log                     = _.log, -- the verbosity logger
  
  -- empty initializer sentinel value
  EMPTY                   = _.EMPTY,

  -- accessors and mutators (meta-attributes for types)
  NS                      = _.NS,
  NAME                    = _.NAME,
  KIND                    = _.KIND,
  QUALIFIERS              = _.QUALIFIERS,
  DEFN                    = _.DEFN,
  INSTANCES               = _.INSTANCES,
  
  
  -- ddsl operations: for building an ontology of models
  new_template            = _.new_template,
  populate_template       = _.populate_template,
  create_role_instance    = _.create_role_instance,
  update_instances        = _.update_instances,
  
  model_kind              = _.model_kind,
  assert_model_kind       = _.assert_model_kind,
  assert_template_kind    = _.assert_template_kind,
  assert_qualifier_array  = _.assert_qualifier_array,
   
  
  -- for users of templates created with ddsl
  new_instance            = _.new_instance,
  new_collection          = _.new_collection,
  is_collection           = _.is_collection,
  
  model                   = _.model,
  template                = _.template,
  resolve                 = _.resolve,
  nsname                  = _.nsname,
  nsroot                  = _.nsroot,
}

-- enforce that the user provides a function to binds the 
-- abstract info interface to an implementation
return function (info_impl) _.info = info_impl return interface end
--============================================================================--
