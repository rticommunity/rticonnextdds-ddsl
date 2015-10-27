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
  -- For example, if the metatable, `model` defines the datatype
  -- model, then the `KIND` table key specifies the kind of datatype model.
  --     model[KIND] = <the datatype model kind>
  -- @section Attributes

  --- Immutable data(type) model kind.  Cannot be changed after a datatype 
  -- model is constructed.
  KIND      = function() return 'KIND' end, 

  --- Name of the data(type) model.
  NAME      = function() return 'NAME' end, 

  --- Namespace a data(type) model belongs to.
  NS        = function() return '::' end,
  
  --- Qualifiers associated with a data(type) model.
  QUALIFIERS = function() return '@' end,
     
  --- Data(type) model definition. 
  -- @local
  DEFN      = function() return 'DEFN' end,

  --- Data(type) model instances. For storing instances of a model, keyed 
  -- by a `xinstance` (table). The value is the instance `NAME`. 
  -- The instance `NAME` may be empty: ''.
  -- @local
  INSTANCES = function() return 'INSTANCES' end,-- table key for instances
 
  --- Data(type) model *cannonical* instance: the user's *handle* to the
  -- datatype.                
  -- 
  -- It is a special instance used to manipulate the data(type) model and 
  -- create additional instances. Its fields should not be modified. It 
  -- field values are flattened out strings that can be used to access the 
  -- field values in some storage system. 
  -- 
  -- New data(type) instances should be created from the template instance.
  -- @local
  TEMPLATE  = function() return 'TEMPLATE' end,--table key for template instance
  
  --- @section end
  
  --============================== ===========================================--
  
  --- Data(type) Model info **abstract** interface that defines the categories 
  -- of model element (kinds).
  -- 
  -- The DDSL meta-model recognizes the following element categories: 
  -- qualifiers, collections, aliases, leaf, template.
  -- Concrete implementations of a type system (e.g. `ddsl.xtypes`) supply 
  -- the concrete implementation functions to classify the data(type) model 
  -- elements into one of these categories.
  -- 
  -- Each function below takes an `xinstance` and returns:
  -- 
  --   - the `xinstance` itself, if it is of the kind, 
  --   - otherwise, returns `nil`
  --   
  --  Note that a model element may satisfy several of these categories. For 
  --  example a leaf model element could act as a template for instances.
  --  @local
  info = {
    is_qualifier_kind = function (v) error('define abstract function!') end,
    -- is this a qualifier model element?
    
    is_collection_kind = function (v) error('define abstract function!') end,
    -- is this a collection model element?
    
    is_alias_kind = function (v) error('define abstract function!') end,
    -- is this an alias for another model element or a collection 
    -- of model elements?
    
    is_leaf_kind = function (v) error('define abstract function!') end,
    -- is this a leaf model element, that cannot be further composed of 
    -- other model elements?
    
    is_template_kind = function (v) error('define abstract function!') end,
    -- is this a model element that acts as a template for creating instances?
  }
}

--============================================================================--
-- logger

local logger = require('logger')

--- `logger` to log messages and get/set the verbosity levels.
-- This module extends the logger to add a `version` field.
-- @usage
--  -- show version
--  print(`ddsl.log`.version)
_.log = logger.new()

_.log.version = require('ddsl.version')

--============================================================================--
-- Models 

--- Create a new 'empty' template.
-- @string name the name of the underlying datatype model
-- @param kind the kind of the underlying datatype model
-- @tparam table api a meta-table to control access to this template, 
--   encapsulating the rules and constraints for the datatype model
-- @treturn table a new (empty) template backed by an underlying 
--   data(type) model
-- @within Constructors
-- @local
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
 
--- Populate a template.
-- @tparam table template a template, generally empty
-- @tparam table defn an array of definition elements for the template `KIND`
-- @treturn table template populated with the definition elements
-- @within Constructors
-- @local
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

--- Create a role (member) instance.
-- @string role the member role name to instantiate (may be empty i.e. ' ')
-- @tparam {table,...} role_defn array of entries in the format
--    { xtemplate, [collection_qualifier,] [annotation_1, annotation_2, ...] }
-- where:
-- 
--  - `xtemplate` is the the template instance for the member's datatype
--  - `collection_qualifier` is a collection qualifier annotation (if any)
--  - `annotation_i` are optional annotations (if any)
-- @treturn table role_instance (member) instance 
-- @treturn table `role_defn` (that was passed in)
-- @within Constructors
-- @local
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


--- Propagate member 'role' update to all instances of the model.
-- @tparam table model the datatype model 
-- @string role the role to propagate
-- @xtemplate role_template the new template role instance (already 
--  created using `create_role_instance`) to propagate; may be nil
-- @within Modifiers
-- @local                    
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
      
--- Create an instance, using another instance as a template.
-- @xtemplate  template the template to use for creating an instance
-- @string[opt=nil] name the template role name; maybe nil
-- 
--   - non-nil => creating a cannonical template instance 
--   - nil => creating an instance for holding data
-- @bool[opt=nil] is_role_instance is the new instance going to be a part of 
--   a role instance, i.e. will the new instance belong to a `xtemplate`?
-- @treturn xinstance newly created instance that supports indexing by `name`
-- @usage
--  -- As an index into some storage system: sample[]
--  local myInstance = ddsl.`new_instance`(MyType, "myInstance")
--  local member = sample[myInstance.member] -- = sample["myInstance.member"]
--
--  -- As storage for data itself
--  local myInstance = ddsl.`new_instance`(MyType)
-- myInstance.member = "value"
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

--- Creates a new named collection of instances based on an element template. 
-- The collection is comprised of elements specified by the given template 
-- or collection (previously created via a call to this function).
-- @xtemplate content_template the collection element element datatype template
--  
--   - may be a template i.e. `xtemplate` (i.e. a non-collection) OR
--   - may be a collection (i.e. creating a collection of collections)
-- @param[opt=nil] capacity the capacity, i.e. the maximum number of instances;
--   nil => unbounded
-- @string[opt=nil] name role name, if the new instance will be a member of 
--   another instance.
-- 
--  - non-nil => creating a template instance 
--  - nil => creating an instance for holding data
-- @bool[opt=nil] is_role_instance is the new collection going to be part of 
--   a role instance, i.e. will it belong to a template?
-- @treturn xinstance returns the newly created collection instance
-- @usage
--  -- As an index into DDS dynamic data: sample[]
--  local myInstance = ddsl.`new_collection`(MyType, 10, "myInstance")
--  for i = 1, sample[#myInstance] do     -- = sample['myInstance#']
--    -- access the i-th element
--    print(sample[myInstance[i].member])  -- = sample["myInstance[i].member"]
--  end    
-- 
--  -- As a storage for data itself
--  local myInstance = ddsl.`new_collection`(MyType, 10)
--  for i = 1, 5 do
--    print(myInstance[i].member) -- get the i-th element = "member"
--    myInstance[i].member = i    -- set the i-th element
--  end  
--  
--  -- the actual number of elements
--  print(#myInstance)  -- 5
--  
--  -- the collection capacity
--  print(myInstance()) -- 10
-- @within Constructors
function _.new_collection(content_template, capacity, name, is_role_instance) 
  _.log.trace('new_collection',content_template,capacity,name)

  if nil ~= name then _.assert_role(name) end
  assert(_.is_collection(content_template) or
         _.info.is_template_kind(content_template),
         table.concat{'new_collection(): needs a template or collection'})
  
  -- convert capacity model element into its value
  if _.kind(capacity) then capacity = capacity() end
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


--- Create new named collection of instances based on another collection. Wraps
-- `new_collection`.
-- @xinstance collection the template for the new collection
-- @string[opt=nil] name the template role name; maybe nil
-- @bool[opt=nil] is_role_instance is the new collection to be created going to 
--  be part of a role instance, i.e. will it belong to a template?
-- @treturn xinstance a newly created collection with the given name, and the 
--  given collection as the *collection template*
-- @within Constructors
-- @local
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
                        
--- Is the given object a collection of instances?
-- @xinstance v the object to check
-- @treturn boolean|nil true if v is a collection, false or nil otherwise 
-- @within Helpers
function _.is_collection(v) 
  local model = getmetatable(v)
  return model and model[_.KIND] == _.collection_metatable[_.KIND]
end

--- Collection meta-model.
-- @local
_.collection_metatable = {

  [_.KIND] = function() return 'collection' end,
  -- the datatype `KIND`

  __call = function (collection)
     local model = getmetatable(collection)
     local capacity = model[_.DEFN][2] or nil
     return capacity
  end,
  -- return the capacity; a 'nil' value means that capacity is unbounded 
  
  __len = function (collection)
      -- NOTE: defined for template instances (i.e. is_role_instance) only
      -- the accessor for collection length
      local model = getmetatable(collection)
      return string.format('%s#', model[_.NAME] or '')
  end,
  -- get the length
  
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
  -- get the i-th element
  
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
  -- set the i-th element
  
  __tostring = function (collection)
      local model = getmetatable(collection)
      local capacity = model[_.DEFN][2] or ''
      return string.format('%s{%s}<%s', model[_.NAME] or '',
                                        model[_.DEFN][1],capacity)
  end,
  -- show the datatype as a string
}

--- Clone a new instance from another instance using the given `name` prefix.
-- @xinstance v an instance (maybe collection) with properly initialized fields
-- @string[opt=nil] prefix the name to prefix the instance fields with
-- 
--   - non-nil => creating a template instance
--   - nil     => creating a user instance for holding data
-- @bool[opt=nil] is_role_instance is the new instance going to be part of a 
--   role instance, i.e. will it belong to a template?
-- @treturn xinstance a new instance with fields properly initialized 
--   for `prefix`
-- @within Constructors
-- @local
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

--- Retrieve the datatype model underlying an instance.
-- The instance would have been created previously using `new_instance`() or 
-- `new_collection`() or `new_template`().
-- @xinstance instance the instance whose model we want to retrieve
-- @treturn table the underlying datatype model
-- @within Retrievers
-- @local
function _.model(instance)
  return getmetatable(instance)
end

--- Retrieve the (*cannonical*) template instance.
-- The instance would have been created previously using `new_instance`() or 
-- `new_collection`() or `new_template`().
-- @xinstance instance the instance whose template we want to retrieve
-- @treturn xtemplate the underlying template (*cannonical*) instance
-- @within Retrievers
function _.template(instance)
  local model = getmetatable(instance)
  return model and model[_.TEMPLATE]
end

--- Resolve an alias template to the underlying non-alias template and the 
-- collection qualifiers that wrap that non-alias template.
-- @xinstance template the alias datatype template to resolve 
-- @treturn ... variadic number of return values consisting of the underlying 
--  non-alias datatype template, and the collection qualifiers wrapping it
--    [ [collection_qualifier,] ... ] <Non-Alias Template>
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

--- Qualified (scoped) name of a datatype model relative to a namespace. 
-- Computes the shortest *distance* (scoped name) to navigate to the datatype 
-- template from namespace. Each name segment is separated by '::'.
-- @xinstance template the datatype whose qualified name is 
--  desired in the context of the namespace
-- @xtemplate[opt=nil] namespace the namespace datatype; if nil, defaults to 
--  template's outermost enclosing scope (`root` namespace)
-- @treturn string the qualified name of the datatype relative to the 
--   namespace; may be nil (for example when template == namespace). 
-- @within Retrievers
function _.nsname(template, namespace)
  -- pre-conditions:
  assert(nil ~= _.kind(template), "nsname(): not a valid template")
  assert(nil == namespace or nil ~= _.kind(namespace), 
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

--- Get the root namespace (the outermost enclosing scope) for an instance.
-- Note that a namespace without an enclosing namespace is the outermost 
-- enclosing scope.  
-- @xinstance template the instance (or template) whose root is to be determined
-- @treturn xtemplate the root namespace ie. the outermost enclosing scope 
--   (NOTE: maybe template itself)
-- @within Retrievers
function _.nsroot(template)
  -- pre-conditions:
  assert(nil ~= _.kind(template), "nsroot(): not a valid template")

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

--- Get the datatype kind for any arbitrary object.
-- @xinstance value the object for which to retrieve the model type
-- @return the datatype `KIND` or nil (if 'value' is not a valid datatype)
-- @within Retrievers
function _.kind(value)
  local model = getmetatable(value)
  return model and model[_.KIND]
end

--- Ensure that an object is a valid datatype of the given kind.
-- @param kind   the expected model element `KIND`
-- @xinstance value  the object to check if it is a datatype model of `kind`
-- @treturn xinstance|nil the value if the kind matches, or nil otherwise
-- @within Helpers
function _.assert_kind(kind, value)
    local model = getmetatable(value)
    assert(model and kind == model[_.KIND],
           table.concat{'expected model kind "', kind(), 
                        '", instead got "', tostring(value), '"'})
    return value
end

--- Ensure that a given object is a datatype qualifier.
-- @xinstance qualifier the object to check if it is a qualifier
-- @treturn xinstance|nil the qualifier or nil otherwise (not a qualifier) 
-- @within Helpers
-- @local
function _.assert_qualifier(qualifier)
    assert(_.info.is_qualifier_kind(qualifier), 
           table.concat{'expected qualifier \"', tostring(qualifier), '"'})
    return qualifier
end

--- Ensure that all elements in the given array are datatype qualifiers.
-- @tparam {xinstance,...} value the potential qualifier array to check
-- @treturn {xinstance,...}|nil the `value` qualifier array or nil 
--   otherwise (not a qualifier array)
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

--- Ensure that a given role name is valid.
-- @string role the role name to check
-- @treturn role|nil the role if valid; nil otherwise
-- @within Helpers
-- @local
function _.assert_role(role)
  assert('string' == type(role), 
      table.concat{'invalid role name: ', tostring(role)})
  return role
end

--- Ensure that a given object is a datatype template.
-- @xinstance template the potential object to check if it is a datatype template
-- @treturn xtemplate|nil the template or nil (not a valid template)
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
  KIND                    = _.KIND,
  NAME                    = _.NAME,
  NS                      = _.NS,
  QUALIFIERS              = _.QUALIFIERS,
  DEFN                    = _.DEFN,
  INSTANCES               = _.INSTANCES,
  
  
  -- ddsl operations: for building an ontology of models
  new_template            = _.new_template,
  populate_template       = _.populate_template,
  create_role_instance    = _.create_role_instance,
  update_instances        = _.update_instances,
  
  kind                    = _.kind,
  assert_kind             = _.assert_kind,
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
