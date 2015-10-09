--[[
  (c) 2005-2014 Copyright, Real-Time Innovations, All rights reserved.     
                                                                           
 Permission to modify and use for internal purposes granted.               
 This software is provided "as is", without warranty, express or implied.
--]]
--[[
-------------------------------------------------------------------------------
Purpose: Load X-Types in Lua from an XML file
Created: Rajive Joshi, 2015 Jun 16
------------------------------------------------------------------------------
--]]

local xtypes = require('ddsl.xtypes')
local xutils = require('ddsl.xtypes.utils')
local xmlstring2table = require('ddsl.xtypes.xml.parser').xmlstring2table

local log = xtypes.log

--------------------------------------------------------------------------------
-- (Lua) Module State

--[[
Top-level "root" module to which all the model elements belong
--]]
local root_module = xtypes.module{['']=xtypes.EMPTY}

--[[
Cache of files that have been processed so far. If a file is encountered again,
it is skipped. Worked much like the "package.loaded" mechanism used by require()
--]]
local files_loaded = {}

--[[
Get the top level "root" module. All the data-types are imported into 
this builtin namespace
--]]
local function root()
  return root_module 
end

--[[
Empty the "root" module to which all the model elements belong
@return the top level root module
--]]
local function empty() 

  -- empty the root module
  for i = #root_module, 1, -1 do
    root_module[i] = nil
  end
  assert(#root_module == 0, tostring('#root_module=' .. #root_module))

  -- clear the list of files loaded
  for k, _ in pairs(files_loaded) do
    files_loaded[k] = nil
  end
  assert(#files_loaded == 0, tostring('#files_loaded=' .. #files_loaded))
  
  return root_module
end

--------------------------------------------------------------------------------

--[[
Look up the template from a name. Searches in several places:
 - in  the pre-defined xtypes, 
 - in the enclosing or global scope
@param name [in] qualifed (i.e. scoped) name of the datatype to lookup
@param ns [in] the scope (or namespace) to lookup the name in
@return the template referenced by name, or nil
@return the template member, if any, identified by name (e.g. enum value)
--]]
local function lookup(name, ns)

  assert(nil ~= ns)
  local template = nil        -- template identified by name
  local template_member = nil -- template member identified by name
    
  -----------------------------------------------------------------------------
  -- lookup xtype builtins
  -----------------------------------------------------------------------------
 
  -- deviations specific to XML representation  
  local xmlName2Model = {
    unsignedShort    = xtypes.unsigned_short,
    unsignedLong     = xtypes.unsigned_long,
    longLong         = xtypes.long_long,
    unsignedLongLong = xtypes.unsigned_long_long,
    longDouble       = xtypes.long_double,
  }
  -- lookup in the deviations table
  local template = xmlName2Model[name] 
  if nil ~= template then return template end


  -- lookup in the xtypes pre-defined templates
  for i, datatype in pairs(xtypes) do
    if 'table' == type(datatype) and
       datatype[xtypes.KIND] and -- this is a valid X-Type
       name == datatype[xtypes.NAME] then
       template = datatype
       break
    end
  end
    
  -----------------------------------------------------------------------------
  -- lookup in scope 'ns'
  -----------------------------------------------------------------------------

  if not template and ns then 
    -- split into identifiers with a '::' separator for each identifier
    -- each iteration of the loop resolves one identifier of the qualified name
    for w in string.gmatch(name, "[%w_]+") do     
      log.debug('\t"' .. w .. '"') -- capture to resolve in this iteration
      
      -- retrieve the template for the 1st capture
      if not template then -- 1st capture: always runs first!
    
        -- determine the enclosing scope to start searching from:
        local parent = '::' == name:sub(1,2) 
                       and root() -- file|global scope 
                       or ns      -- relative scope

        -- is w defined in the context of the specified scope?
        repeat
          log.debug('\t\t ::', parent)
          template = parent[w]
          parent = parent[xtypes.NS]
        until template or not parent

      else -- 2nd capture onwards
        
        -- keep track of the scope resolved so far
        ns = template 
                
        -- Found
        if ns[w] then   
          -- Lookup in the scope resolved so far
          log.debug('\t\t ..', ns[w])
   
          -- lookup the template identified by 'w'
          template = xtypes.template(ns[w])  
 
          -- alternatively: if 'w' is an enum member, accept it
          -- NOTE: in this case, the value of template will be nil
          if 'enum' == ns[xtypes.KIND]() then
            template_member = w -- ENUM member
          end
            
        -- Not Found
        else
          template = nil
        end
      end
      
      
      -- For each capture, check for IDL scoping rules:
      -- Does 'w' refer to an enum value within an enclosing scope?
      if not template then
        if 'module' == ns[xtypes.KIND]() then
          -- IDL NOTE:
          --   Enumeration value names are introduced into the enclosing scope
          --   and then are treated like any other declaration in that scope
          for _, datatype in ipairs(ns) do
            if 'enum' == datatype[xtypes.KIND]() and datatype[w] then
              template_member = w -- ENUM member
              break -- resolved!
            end
          end
        end
      end
      
      log.debug('\t   ->', template or template_member) -- result of resolution

      -- could not resolve the capture => skip remaining capture segments
      if nil == template or nil ~= template_member then break end  
    end
  end
  
  -----------------------------------------------------------------------------
  -- result

  if nil == template and nil == template_member then
    log.notice('\t=>', table.concat{'Unresolved name: "', name, '"'})
  end      
                         
  return template, template_member
end

--[[
Map an xml attribute to an appropriate handler to generate X-Types
      xml attribute --> action to generate X-Type template (attribute handler)
Each handler takes the attribute list and a namespace module as an argument, 
and returns an appropriate X-Types model element.
--]]
local xmlattr2xtype   -- forward declaration
xmlattr2xtype = {
  -- skip these:
  name             = xtypes.EMPTY,
  nonBasicTypeName = xtypes.EMPTY,
  stringMaxLength  = xtypes.EMPTY,
  baseType         = xtypes.EMPTY,
  baseClass        = xtypes.EMPTY,
  visibility       = xtypes.EMPTY,
  typeModifier     = xtypes.EMPTY,
  required         = xtypes.EMPTY,
            
  -- role_template
  type = function(xarg, ns)
    -- determine the stringMaxLength 
    local stringMaxLength -- NOTE: "-1" means unbounded
    if xarg.stringMaxLength and '-1' ~= xarg.stringMaxLength then -- bounded
      stringMaxLength = tonumber(xarg.stringMaxLength) or
                        lookup(xarg.stringMaxLength, ns)
                        
    end
    
    if 'string' == xarg.type then
      return xtypes.string(stringMaxLength)
    elseif 'wstring' ==  xarg.type then
      return xtypes.wstring(stringMaxLength)
    else
      return xarg.nonBasicTypeName -- NOTE: use nonBasic if defined
                        and lookup(xarg.nonBasicTypeName, ns)
                        or  lookup(xarg.type, ns)
    end
  end,
  
  -- collection: sequence
  sequenceMaxLength = function(xarg, ns)
    -- determine the stringMaxLength 
    local sequenceMaxLength -- NOTE: "-1" means unbounded
    if '-1' ~= xarg.sequenceMaxLength then -- bounded
      sequenceMaxLength = tonumber(xarg.sequenceMaxLength) or 
                          lookup(xarg.sequenceMaxLength, ns) 
                          
    end
    return xtypes.sequence(sequenceMaxLength)
  end,
     
  -- collection: array
  arrayDimensions = function(xarg, ns)
    local dim = {}
    for w in string.gmatch(xarg.arrayDimensions, "[%w_::]+") do
      local dim_i = tonumber(w) or lookup(w, ns)
      table.insert(dim, dim_i)       
      log.debug('\tdim = ', dim_i)
    end
    return xtypes.array(table.unpack(dim))          
  end,
  
  -- constant: value              
  value = function(xarg)
      return xarg.value -- let the constant definition do the conversion
  end,
  
  -- annotations
  annotations = {
    key           = function() return xtypes.Key end,
    optional      = function() return xtypes.Optional end,
    topLevel      = function() return xtypes.top_level end,
    id            = function(xarg) return xtypes.ID{xarg.id} end,
    extensibility = function(xarg) 
      return xtypes.Extensibility{xarg.extensibility} 
    end,
  }
}

--[[
Return the array of annotations by the given xml attribute list. Also output
a warning if there are any unrecognized xml attributes
--]]
local function xarg2annotations(xarg)
    -- annotations
    local annotations = {}
    for k, v in pairs(xarg) do
      if xmlattr2xtype.annotations[k] then 
        table.insert(annotations, xmlattr2xtype.annotations[k](xarg))  
      elseif not xmlattr2xtype[k] then
        log.info(xarg.name, table.concat{
                        ' : Skipping unrecognized XML attribute: ',
                        k, ' = ', v})      
      end
    end
    return annotations
end

--[[
Return the role definition specified by the given xml attribute list
--]]
local function xarg2roledefn(xarg, ns)

    -- annotations
    local role_defn = xarg2annotations(xarg)
    
    -- collection
    if xarg.arrayDimensions then 
      table.insert(role_defn, 1, xmlattr2xtype.arrayDimensions(xarg, ns))
    end
    if xarg.sequenceMaxLength then
      table.insert(role_defn, 1, xmlattr2xtype.sequenceMaxLength(xarg, ns))
    end
        
    -- role template
    table.insert(role_defn, 1, xmlattr2xtype.type(xarg, ns))
    
    return role_defn
end

--[[
Map an xml tag to an appropriate X-Types template creation function (handler):
      tag --> action to create X-Type template (tag handler)
Each handler takes the xml tag and a namespace module as an argument, and 
returns a newly created X-Types template or nil
--]]
local tag2template   -- forward declaration
local file2xtypes -- forward declaration
tag2template = {

  typedef = function(tag, ns)  
    local template = xtypes.typedef{
      [tag.xarg.name] = xarg2roledefn(tag.xarg, ns)
    }

    -- add to the module namespace, so we can lookup by name
    if ns then ns[#ns+1] = template end
          
    -- annotations
    template[xtypes.QUALIFIERS] = xarg2annotations(tag.xarg)

    return template
  end,
  
  const = function(tag, ns)
    local template = xtypes.const{
      [tag.xarg.name] = { 
        xmlattr2xtype.type(tag.xarg, ns), xmlattr2xtype.value(tag.xarg, ns) 
      }
    }

    -- add to the module namespace, so we can lookup by name
    if ns then ns[#ns+1] = template end
              
    -- annotations
    template[xtypes.QUALIFIERS] = xarg2annotations(tag.xarg)
    
    return template
  end,
    
  enum = function(tag, ns)
    local template = xtypes.enum{
      [tag.xarg.name] = xtypes.EMPTY
    }

    -- add to the module namespace, so we can lookup by name
    if ns then ns[#ns+1] = template end
              
    -- child tags
    for i, child in ipairs(tag) do
      if 'table' == type(child) then -- skip comments
        if child.xarg.value then
          template[#template+1] = { 
              [child.xarg.name] = tonumber(child.xarg.value) 
          }
        else
          template[#template+1] = child.xarg.name
        end
      end
    end
    
    -- annotations
    template[xtypes.QUALIFIERS] = xarg2annotations(tag.xarg)

    return template
  end,
  
  struct = function (tag, ns)
    local template = xtypes.struct{[tag.xarg.name]=xtypes.EMPTY}
    
    -- add to the module namespace, so we can lookup by name
    if ns then ns[#ns+1] = template end
                   
    -- base type    
    if tag.xarg.baseType or tag.xarg.baseClass then
      template[xtypes.BASE] = lookup(tag.xarg.baseType or tag.xarg.baseClass, 
                                     ns)
    end
  
    -- child tags
    for i, child in ipairs(tag) do
      if 'table' == type(child) and 'member' == child.label then-- skip comments
        log.debug(tag.label, child.label, child.xarg.name)
        template[#template+1] = 
                        { [child.xarg.name] = xarg2roledefn(child.xarg, ns) }
      end
    end
    
    -- annotations
    template[xtypes.QUALIFIERS] = xarg2annotations(tag.xarg)
    
    return template
  end,
  
  union = function (tag, ns)
    
    local template
    local disc
    
    -- child tags
    for i, child in ipairs(tag) do
      if 'table' == type(child) then -- skip comments
      
        if 'discriminator' == child.label then
          log.debug(tag.label, child.label, 
                           child.xarg.nonBasicTypeName or child.xarg.type)
          disc = xmlattr2xtype.type(child.xarg, ns)
          template=xtypes.union{[tag.xarg.name]={disc}}
          
          -- add to the module namespace, so we can lookup by name
          if ns then ns[#ns+1] = template end
      
        elseif 'case' == child.label then
          local case = nil -- default
          for j, grandchild in ipairs(child) do
            log.debug(tag.label, child.label, grandchild.label, 
                  grandchild.xarg.name or grandchild.xarg.value)
            if 'table' == type(grandchild) then -- skip comments
              if 'caseDiscriminator' == grandchild.label then
                 if 'default' ~= grandchild.xarg.value then
                 
                   if 'enum' == disc[xtypes.KIND]() then
                     local _
                     _, case = lookup(grandchild.xarg.value, ns)
                     assert(case, 'invalid case: ' .. grandchild.xarg.value)
                   else 
                     case = lookup(grandchild.xarg.value, ns) or 
                            grandchild.xarg.value
                   end
                 end
              elseif 'member' == grandchild.label then
                template[#template+1] = { 
                  case, 
                    [grandchild.xarg.name] = xarg2roledefn(grandchild.xarg, ns)
                }
              end
            end
          end
        end
      end
    end
    
    -- annotations
    template[xtypes.QUALIFIERS] = xarg2annotations(tag.xarg)
    
    return template
  end,
  
  module = function (tag, ns)
    -- create a new module only if it is not yet defined in the current ns:
    local template = ns[tag.xarg.name]
    if not template then
      template = xtypes.module{[tag.xarg.name]=xtypes.EMPTY}

      -- add to the module namespace, so we can lookup by name
      if ns then ns[#ns+1] = template end
    end
                        
    -- child tags
    for i, child in ipairs(tag) do
      if 'table' == type(child) then -- skip comments
        log.debug(tag.label, child.label, child.xarg.name)
        
        local tag_handler = tag2template[child.label]
        if tag_handler then
          local xtype = tag_handler(child, template) -- change ns to this module
        end
      end
    end

    -- annotations
    template[xtypes.QUALIFIERS] = xarg2annotations(tag.xarg)

    return template
  end,
  
  include = function (tag, ns)
    local file, template = tag.xarg.file, nil
    if file then 
      template = file2xtypes(file, ns) 
    end
    return template
  end,
  
  -- Legacy tags
  valuetype = function (tag, ns)
      log.info(tag.xarg.name, ' : Importing valuetype as a struct')
      return tag2template.struct(tag, ns)
  end,

  sparse_valuetype = function (tag, ns)
      log.info(tag.xarg.name, ' : Importing sparse_valuetype as a struct')
      return tag2template.struct(tag, ns)
  end,
}

    
--[[
Visit all the nodes in the xml table, and a return the root module 
containing the corresponding xtype definitions
@param xml [in] a table generated from XML
@param ns [in] module namespace into which to import datatypes
@return the 'ns' namespace populated with the datatypes defined in the xml table
--]]
local function xml2xtypes(xml, ns)

  local tag_handler, template = tag2template[xml.label], nil
  if tag_handler then -- process this node (and its child nodes)
  
    log.debug('\n-----\n', xml.label, xml.xarg.name or xml.xarg.file, 'BEGIN')
    template = tag_handler(xml, ns)       
    if template then
      log.debug(table.concat(xutils.visit_model(template, {'IDL:'}), '\n\t'))
    end
    log.debug(xml.label, xml.xarg.name or xml.xarg.file, 'END')
      
  else -- don't recognize the label as an xtype, visit the child nodes  

    for i, child in ipairs(xml) do
      if 'table' == type(child) then -- skip comments
        template = xml2xtypes(child, ns) -- recursively process the child nodes
      end
    end
  end
   
  return ns
end

--[[
Given an XML string, loads the xtype definitions, and returns the  
root module populated with the datatypes defined in the XML string
@param xmlstring [in] xml string containing XML datatype definitions
@param ns [in] module namespace into which to import datatypes
@return the root module populated with the datatypes defined in the xml string
--]]
local function string2xtypes(xmlstring, ns)
  local xml = xmlstring2table(xmlstring)
  assert(xml)
  
  local template = xml2xtypes(xml, ns or root())
  
  return template
end


--[[
Given an XML file, loads the xtype definitions, and returns the  
root module populated with the datatypes defined in the XML file
@param filename [in] xml file containing XML datatype definitions
@param ns [in] module namespace into which to import datatypes
@return the root module populated with the datatypes defined in the xml string
--]]
function file2xtypes(filename, ns)
  
  log.debug('***', filename, files_loaded[filename])
  local template 
  if not files_loaded[filename] then
    
    -- load the file into a string
    local file = assert(io.open(filename, 'r'))
    local xmlstring = file:read("*a")
    files_loaded[filename] = true
    file:close()
    
    -- process the string
    ns = ns or root()
    log.debug('***', filename, ns)
    template = string2xtypes(xmlstring, ns)
  end
  
  return template -- nil, if the file has been already loaded
end


--[[
Given an array of XML files, loads the xtype definitions, and returns the  
root module populated with the datatypes defined in the XML files. 
Note: Clears the root_module of any definitions, previously imported

@param filenames [in] array of xml filenames containing XML datatype definitions
@return the root module populated with the datatypes defined in the xml files
--]]
local function filelist2xtypes(files)
  empty() -- empty the top-level root module
  for _, file in ipairs(files) do
    log.debug('========= ', file, ' do =========')
    file2xtypes(file, root()) -- import each file into the root ns
    log.debug('--------- ', file, ' end --------')
  end
  return root() -- the fully populated root module
end

-------------------------------------------------------------------------------
interface = {
    root          = root,
    empty         = empty,
    
    filelist2xtypes  = filelist2xtypes,
    file2xtypes   = file2xtypes,
    string2xtypes = string2xtypes,
    
    log           = log, -- logger object to change the verbosity levels
}

return interface
