--[[
Copyright (C) 2015 Real-Time Innovations, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]

--- DDSL XML Import.
-- Load X-Types in Lua from XML.
-- @module ddsl.xtypes.xml
-- @author Rajive Joshi

local xtypes = require('ddsl.xtypes')
local xutils = require('ddsl.xtypes.utils')
local xmlstring2table = require('ddsl.xtypes.xml.parser').xmlstring2table

local nslookup = xutils.nslookup

--- `logger` to log messages and get/set the verbosity levels
local log = xtypes.log

--============================================================================--
-- State

-- Top-level "root" module to which all the model elements belong
local root_module = xtypes.module{['']=xtypes.EMPTY}
root_module[xtypes.NAME] = nil --  make this a 'root' namespace

-- Cache of files that have been processed so far. If a file is encountered 
-- again, it is skipped. Worked much like the "package.loaded" mechanism 
-- used by require()
local files_loaded = {}

--- Get the top level "root" builtin module namespace. 
-- All the data-types are imported from XML files into this builtin namespace.
-- @treturn xtemplate the root `xtypes.module` namespace for xml import
local function root()
  return root_module 
end

--- Empty the `root` builtin module namespace.
-- Deletes all the entries in the `root` module.
-- @treturn xtemplate the root `xtypes.module` namespace for xml import
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

--============================================================================--
-- Operations

-- Map an xml attribute to an appropriate handler to generate X-Types
--      xml attribute --> action to generate X-Type template (attribute handler)
-- Each handler takes the attribute list and a namespace module as an argument, 
-- and returns an appropriate X-Types model element.
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
                        nslookup(xarg.stringMaxLength, ns)
                        
    end
    
    if 'string' == xarg.type then
      return xtypes.string(stringMaxLength)
    elseif 'wstring' ==  xarg.type then
      return xtypes.wstring(stringMaxLength)
    else
      return xarg.nonBasicTypeName -- NOTE: use nonBasic if defined
                        and nslookup(xarg.nonBasicTypeName, ns)
                        or  nslookup(xarg.type, ns)
    end
  end,
  
  -- collection: sequence
  sequenceMaxLength = function(xarg, ns)
    -- determine the stringMaxLength 
    local sequenceMaxLength -- NOTE: "-1" means unbounded
    if '-1' ~= xarg.sequenceMaxLength then -- bounded
      sequenceMaxLength = tonumber(xarg.sequenceMaxLength) or 
                          nslookup(xarg.sequenceMaxLength, ns) 
                          
    end
    return xtypes.sequence(sequenceMaxLength)
  end,
     
  -- collection: array
  arrayDimensions = function(xarg, ns)
    local dim = {}
    for w in string.gmatch(xarg.arrayDimensions, "[%w_::]+") do
      local dim_i = tonumber(w) or nslookup(w, ns)
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

-- Return the array of annotations by the given xml attribute list. Also output
-- a warning if there are any unrecognized xml attributes
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

-- Return the role definition specified by the given xml attribute list
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

-- Map an xml tag to an appropriate X-Types template creation function (handler)
--      tag --> action to create X-Type template (tag handler)
-- Each handler takes the xml tag and a namespace module as an argument, and 
-- returns a newly created X-Types template or nil
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
    local template = ns and ns[tag.xarg.name] -- already forward_dcl ?

    if not template then
      template = xtypes.enum{
        [tag.xarg.name] = xtypes.EMPTY
      }

      -- add to the module namespace, so we can lookup by name
      if ns then ns[#ns+1] = template end
    end
               
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
    local template = ns and ns[tag.xarg.name] -- already forward_dcl ?
    
    if not template then
      template = xtypes.struct{[tag.xarg.name]=xtypes.EMPTY}
      
      -- add to the module namespace, so we can lookup by name
      if ns then ns[#ns+1] = template end
    end
                  
    -- base type    
    if tag.xarg.baseType or tag.xarg.baseClass then
      template[xtypes.BASE] = nslookup(tag.xarg.baseType or tag.xarg.baseClass, 
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

    local template = ns and ns[tag.xarg.name] -- already forward_dcl ?
    
    -- discriminator
    local disc = xtypes.long -- default
    for i, child in ipairs(tag) do
      if 'table' == type(child) then -- skip comments
        if 'discriminator' == child.label then
          log.debug(tag.label, child.label, 
                           child.xarg.nonBasicTypeName or child.xarg.type)
          disc = xmlattr2xtype.type(child.xarg, ns)     
        end
      end
    end
    
    -- create template, if not already created
    if not template then
      template = xtypes.union{[tag.xarg.name]={disc}}
      
      -- add to the module namespace, so we can lookup by name
      if ns then ns[#ns+1] = template end
    else
      -- set the discriminator
      template[xtypes.SWITCH] = disc
    end

    
    -- cases:
    for i, child in ipairs(tag) do
      if 'table' == type(child) then -- skip comments
      
        if 'case' == child.label then
          local case = {} -- default
          for j, grandchild in ipairs(child) do
            log.debug(tag.label, child.label, grandchild.label, 
                  grandchild.xarg.name or grandchild.xarg.value)
            if 'table' == type(grandchild) then -- skip comments
              if 'caseDiscriminator' == grandchild.label then
                 local caseDiscriminator
                 if 'default' == grandchild.xarg.value then
                   caseDiscriminator = xtypes.EMPTY
                 else
                   if 'enum' == disc[xtypes.KIND]() then
                     local _, enumerator
                     _, enumerator = nslookup(grandchild.xarg.value, ns)
                     assert(enumerator, 'invalid case enumerator: ' ..
                                         grandchild.xarg.value)
                     caseDiscriminator = disc[enumerator]
                     assert(case, 'invalid case value: ' ..
                                   grandchild.xarg.value)
                   else 
                     caseDiscriminator = nslookup(grandchild.xarg.value, ns) or 
                            grandchild.xarg.value
                   end
                 end
                
                 table.insert(case, caseDiscriminator) -- build the case
              elseif 'member' == grandchild.label then
                case[grandchild.xarg.name] = xarg2roledefn(grandchild.xarg, ns)
              end  
            end            
          end
        
          -- create the case entry:
          template[#template+1] = case
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
        else
          -- Certain child tags (eg 'directive') don't require any processing
          log.notice(tag.label, child.label, child.xarg.name, 
                                'Ignoring: Nothing to do!')
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
  
  -- Forward declaration
  forward_dcl = function (tag, ns)
    -- tag.xarg.kind = enum | struct | union
    return tag2template[tag.xarg.kind](tag, ns)
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

-- Visit all the nodes in the xml table, and a return the root module 
-- containing the corresponding xtype definitions
-- @tab xml a table generated from XML
-- @xtemplate ns module namespace into which to import datatypes
-- @treturn xtemplate the 'ns' namespace populated with the datatypes defined 
--   in the xml table
local function xml2xtypes(xml, ns)

  local tag_handler, template = tag2template[xml.label], nil
  if tag_handler then -- process this node (and its child nodes)
  
    log.debug('\n-----\n', xml.label, xml.xarg.name or xml.xarg.file, 'BEGIN')
    template = tag_handler(xml, ns)       
    if template then
      log.debug(table.concat(xutils.to_idl_string_table(template, {'IDL:'}), 
                             '\n\t'))
    end
    log.debug(xml.label, xml.xarg.name or xml.xarg.file, 'END')
      
  else -- don't recognize the label as an xtype, visit the child nodes  
    log.info(xml.label, 'SKIPPING Unrecognized tag in file!')
    
    for i, child in ipairs(xml) do
      if 'table' == type(child) then -- skip comments
        template = xml2xtypes(child, ns) -- recursively process the child nodes
      end
    end
  end
   
  return ns
end

--- Given an XML string, imports the xtype definitions, and returns the 
-- root module populated with the datatypes defined in the XML string.
-- @string xmlstring xml string containing XML datatype definitions
-- @xtemplate[opt=root] ns module namespace into which to import the datatypes
-- @treturn the module namespace populated with the datatypes defined 
--   in the `xmlstring`
local function string2xtypes(xmlstring, ns)
  local xml = xmlstring2table(xmlstring)
  assert(xml)
  
  local template = xml2xtypes(xml, ns or root())
  
  return template
end

--- Given an XML file, imports the xtype definitions, and returns the  
-- root module populated with the datatypes defined in the XML file.
-- @string filename xml file path containing XML datatype definitions
-- @xtemplate[opt=root] ns module namespace into which to import the datatypes
-- @treturn the namespace populated with the datatypes defined in 
--   the XML file `filename`
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

--- Given an array of XML files, imports the xtype definitions and returns the  
-- root module populated with the datatypes defined in the XML files. 
-- Clears the root_module of any definitions, previously imported 
-- by calling `empty`.
-- @tparam {string,...} files array of file paths to XML files containing 
--   datatype definitions
-- @treturn the `root` module namespace populated with the datatypes defined
--  in the xml files given by `files`
local function filelist2xtypes(files)
  empty() -- empty the top-level root module
  for _, file in ipairs(files) do
    log.debug('========= ', file, ' do =========')
    file2xtypes(file, root()) -- import each file into the root ns
    log.debug('--------- ', file, ' end --------')
  end
  return root() -- the fully populated root module
end

--============================================================================--

--- @export
return {
    root          = root,
    empty         = empty,
    
    filelist2xtypes  = filelist2xtypes,
    file2xtypes   = file2xtypes,
    string2xtypes = string2xtypes,
    
    log           = log,
}

