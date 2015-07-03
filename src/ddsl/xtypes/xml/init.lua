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

--[[
TRACE: turn tracing on/off to help debug XML import
--]]
local interface
local function trace(...) 
  return interface.is_trace_on and print('TRACE: ', ...)
end

--[[
Current namespace (module) inside which the child elements are being defined
NOTE: set when loading module elements; reset to nil when not loading a module
--]]
local ns = nil

--[[
Templates created from XML. This list is built as the XML is processed.
--]]
local template_list = {}

--[[
Look up the template from a name. Searches in several places:
 - in  the pre-defined xtypes, 
 - in the user-defined template_list
 - in the user defined modules (for nested namespaces)
@param name [in] name of the type to lookup
@return the template referenced by name, or nil.
--]]
local function lookup_type(name)

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
  for i, template in pairs(xtypes) do
    if 'table' == type(template) and
       template[xtypes.KIND] and -- this is a valid X-Type
       name == template[xtypes.NAME] then
      return template
    end
  end
  

  -- lookup in the template_list that we have defined so far
  -- NOTE: for path names with a '::' name-space separator for each name-space
  -- segment, lookup the path name in module name-spaces defined so far
  local template_toplevel = nil
  local template = nil
  for w in string.gmatch(name, "[%w_]+") do     
    trace('\t::' .. w .. '::')
    
    -- retrieve the top-level template (for the first capture)
    if not template_toplevel then -- always runs first!
                
      -- is w defined as a top-level namespace so far?
      if not template_toplevel then
        for i, template in ipairs(template_list) do
          if w == template[xtypes.NAME] then
            template_toplevel = template
            break
          end
        end
      end
      
      -- is w defined in the context of the current namespace? (if any)
      if not template_toplevel and ns then 
        local parent = ns
        repeat
          trace('\t\t ::', parent)
          template_toplevel = parent[w]
          parent = parent[xtypes.NS]
        until template_toplevel or not parent
      end
               
      -- set the resolution of w: the first name segment 
      template = template_toplevel
      
      -- could not resolve the first capture => skip the other capture segments
      if not template then break end
      
    else
      -- Now, lookup the template specified by the name segments within the
      -- top-level template's (first w's) name space
      trace('\t\t ..', template[w])
      if 'enum' == template[xtypes.KIND]() then
          template = w
      else
          template = xtypes.utils.template(template[w])
      end
    end
    
    trace('\t\t ->', template)
  end
 
  if not template then
    trace(table.concat{'\tUnresolved name: "', name, 
          '"  in ', ns and xtypes.utils.nsname(ns)})
  end      
                         
  return template
end

--[[
Map an xml attribute to an appropriate handler to generate X-Types
      xml attribute --> action to generate X-Type template (attribute handler)
Each handler takes the attribute list as an argument, and returns an 
appropriate X-Types model element.
--]]
local xmlattr2xtype   -- forward declaration
xmlattr2xtype = {
  -- skip these:
  name             = xtypes.EMPTY,
  nonBasicTypeName = xtypes.EMPTY,
  stringMaxLength  = xtypes.EMPTY,
  baseType         = xtypes.EMPTY,
  
  -- role_template
  type = function(xarg)
    -- determine the stringMaxLength 
    local stringMaxLength -- NOTE: "-1" means unbounded
    if xarg.stringMaxLength and '-1' ~= xarg.stringMaxLength then -- bounded
      stringMaxLength = tonumber(xarg.stringMaxLength) or
                        lookup_type(xarg.stringMaxLength)
                        
    end
    
    if 'string' == xarg.type then
      return xtypes.string(stringMaxLength)
    elseif 'wstring' ==  xarg.type then
      return xtypes.wstring(stringMaxLength)
    else
      return xarg.nonBasicTypeName -- NOTE: use nonBasic if defined
                        and lookup_type(xarg.nonBasicTypeName)
                        or  lookup_type(xarg.type)
    end
  end,
  
  -- collection: sequence
  sequenceMaxLength = function(xarg)
    -- determine the stringMaxLength 
    local sequenceMaxLength -- NOTE: "-1" means unbounded
    if '-1' ~= xarg.sequenceMaxLength then -- bounded
      sequenceMaxLength = tonumber(xarg.sequenceMaxLength) or 
                          lookup_type(xarg.sequenceMaxLength) 
                          
    end
    return xtypes.sequence(sequenceMaxLength)
  end,
     
  -- collection: array
  arrayDimensions = function(xarg)
    local dim = {}
    for w in string.gmatch(xarg.arrayDimensions, "[%w_::]+") do
      local dim_i = tonumber(w) or lookup_type(w)
      table.insert(dim, dim_i)       
      trace('\tdim = ', dim_i)
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
        print(table.concat{'WARNING: Skipping unrecognized XML attribute: ',
                            k, ' = ', v})      
      end
    end
    return annotations
end

--[[
Return the role definition specified by the given xml attribute list
--]]
local function xarg2roledefn(xarg)

    -- annotations
    local role_defn = xarg2annotations(xarg)
    
    -- collection
    if xarg.arrayDimensions then 
      table.insert(role_defn, 1, xmlattr2xtype.arrayDimensions(xarg))
    end
    if xarg.sequenceMaxLength then
      table.insert(role_defn, 1, xmlattr2xtype.sequenceMaxLength(xarg))
    end
        
    -- role template
    table.insert(role_defn, 1, xmlattr2xtype.type(xarg))
    
    return role_defn
end

--[[
Map an xml tag to an appropriate X-Types template creation function (handler):
      tag --> action to create X-Type template (tag handler)
Each handler takes the xml tag as an argument, and returns a newly 
created X-Types template or nil
--]]
local tag2template   -- forward declaration
local xmlfile2xtypes -- forward declaration
tag2template = {

  typedef = function(tag)  
    local template = xtypes.typedef{
      [tag.xarg.name] = xarg2roledefn(tag.xarg)
    }

    -- annotations
    template[xtypes.QUALIFIERS] = xarg2annotations(tag.xarg)

    return template
  end,
  
  const = function(tag)
    local template = xtypes.const{
      [tag.xarg.name] = { 
        xmlattr2xtype.type(tag.xarg), xmlattr2xtype.value(tag.xarg) 
      }
    }
    
    -- annotations
    template[xtypes.QUALIFIERS] = xarg2annotations(tag.xarg)
    
    return template
  end,
    
  enum = function(tag)
    local template = xtypes.enum{
      [tag.xarg.name] = xtypes.EMPTY
    }
    
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
  
  struct = function (tag)
    local template = xtypes.struct{[tag.xarg.name]=xtypes.EMPTY}
         
    -- base type    
    if tag.xarg.baseType then
      template[xtypes.BASE] = lookup_type(tag.xarg.baseType)
    end
  
    -- child tags
    for i, child in ipairs(tag) do
      if 'table' == type(child) and 'member' == child.label then-- skip comments
        trace(tag.label, child.label, child.xarg.name)
        template[#template+1] = { [child.xarg.name] = xarg2roledefn(child.xarg) }
      end
    end
    
    -- annotations
    template[xtypes.QUALIFIERS] = xarg2annotations(tag.xarg)
    
    return template
  end,
  
  union = function (tag)
    
    local template

    -- child tags
    for i, child in ipairs(tag) do
      if 'table' == type(child) then -- skip comments
      
        if 'discriminator' == child.label then
          local disc = xmlattr2xtype.type(child.xarg)
          template=xtypes.union{[tag.xarg.name]={
                xmlattr2xtype.type(child.xarg)
          }}
        
        elseif 'case' == child.label then
          local case = nil -- default
          for j, grandchild in ipairs(child) do
            trace(tag.label, child.label, grandchild.label, 
                  grandchild.xarg.name or grandchild.xarg.value)
            if 'table' == type(grandchild) then -- skip comments
              if 'caseDiscriminator' == grandchild.label then
                 if 'default' ~= grandchild.xarg.value then
                   case = lookup_type(grandchild.xarg.value) or 
                          grandchild.xarg.value
                 end
              elseif 'member' == grandchild.label then
                template[#template+1] = { 
                  case, 
                      [grandchild.xarg.name] = xarg2roledefn(grandchild.xarg)
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
  
  module = function (tag)
    -- create a new module only if it is not yet defined:
    local template = lookup_type(tag.xarg.name) 
    if not template then
      template = xtypes.module{[tag.xarg.name]=xtypes.EMPTY}
      
      -- add to paremt ns upon creation, so that child nodes can navigate 
      -- to the parent namespace to lookup names:
      if ns then ns[#ns+1] = template  end
    end
            
    -- set this module as the name-space context
    local prev_ns = ns        
    ns = template -- set the namespace context in which to load the children
    trace('ns', ns and xtypes.utils.nsname(ns))
            
    -- child tags
    for i, child in ipairs(tag) do
      if 'table' == type(child) then -- skip comments
        trace(tag.label, child.label, child.xarg.name)
        local tag_handler = tag2template[child.label]

        if tag_handler then
          local xtype = tag_handler(child)
        
          -- add to this module if not already so
          -- NOTE: a 'module' child would have already been added by the
          -- module tag handler (this function)
          if 'module' ~= child.label then template[#template+1] = xtype end
        end
      end
    end

    -- annotations
    template[xtypes.QUALIFIERS] = xarg2annotations(tag.xarg)

    ns = prev_ns-- done with loading name-space: reset context to previous state
    return template
  end,
  
  include = function (tag)
    local file = tag.xarg.file
    if file then 
      xmlfile2xtypes(file) 
      trace(tag.label, tag.xarg.file, 'DONE!')
    end
    return nil
  end,
  
  -- Legacy tags
  valuetype = function (tag)
      print('WARNING: Importing valuetype as a struct')
      return tag2template.struct(tag)
  end,

  sparse_valuetype = function (tag)
      print('WARNING: Importing sparse_valuetype as a struct')
      return tag2template.struct(tag)
  end,
}

    
--[[
Visit all the nodes in the xml table, and a return a table containing the 
xtype definitions
@param xml [in] a table generated from XML
@return an array of xtypes, equivalent to those defined in the xml table
--]]
local function xml2xtypes(xml)

  local tag_handler = tag2template[xml.label]
  if tag_handler then -- process this node (and its child nodes)
    trace('\n-----\n', xml.label, xml.xarg.name or xml.xarg.file)
    local template = tag_handler(xml)
    
    if template then
      trace(table.concat(xutils.visit_model(template, {'IDL:'}), '\n\t'))
     
      -- insert it in the template_list, if not already there:
      local already_in_template_list = false
      for i = 1, #template_list do
        if template == template_list[i] then 
          already_in_template_list=true break 
        end
      end
      if not already_in_template_list then     
        table.insert(template_list, template)
      end
    end
  else -- don't recognize the label as an xtype, visit the child nodes  
    -- process the child nodes
    for i, child in ipairs(xml) do
      if 'table' == type(child) then -- skip comments
        xml2xtypes(child)
      end
    end
  end
  
  return template_list
end

--[[
Given an XML string, loads the xtype definitions, and return them
@param xmlstring [in] xml string containing XML type definitions
@return an array of xtypes, equivalent to those defined in the xml table
--]]
local function xmlstring2xtypes(xmlstring)
  local xml = xmlstring2table(xmlstring)
  return xml2xtypes(xml)
end

--[[
Cache of files that have been processed so far. If a file is encountered again,
it is skipped. Worked much like the package.loaded mechanism used by require()
--]]
local files_loaded = {}

--[[
Given an XML file, loads the xtype definitions, and return them
@param filename [in] xml file containing XML type definitions
@return an array of xtypes, equivalent to those defined in the xml file
--]]
function xmlfile2xtypes(filename)
  if not files_loaded[filename] then
    io.input(filename)
    local xmlstring = io.read("*all")
    files_loaded[filename] = true
    return xmlstring2xtypes(xmlstring)
  end
end

--[[
Given an array of XML files, loads the xtype definitions in a single global 
X-Types namespaces, and returns the list of loaded DDSL schemas
@param filenames [in] array of xml file names containing XML type definitions
@return an array of xtypes, equivalent to those defined in the xml files
--]]
local function xmlfiles2xtypes(files)
  local schemas
  for i = 1, #files do
    local file = files[i]
    print('========= ', file, ' do =========')
    schemas = xmlfile2xtypes(file)
    print('--------- ', file, ' end --------')
  end
  return schemas
end

-------------------------------------------------------------------------------
interface = {
    string2xtypes = xmlstring2xtypes,
    file2xtypes   = xmlfile2xtypes,
    files2xtypes  = xmlfiles2xtypes,
    is_trace_on   = false, -- turn on tracing?
    
    -- clear the list of templates
    clear         = function() template_list = {} end,
}

return interface
