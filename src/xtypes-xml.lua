--[[
  (c) 2005-2014 Copyright, Real-Time Innovations, All rights reserved.     
                                                                           
 Permission to modify and use for internal purposes granted.               
 This software is provided "as is", without warranty, express or implied.
--]]
--[[
-------------------------------------------------------------------------------
Purpose: Load X-Types in Lua from an XML file
Created: Rajive Joshi, 2014 Apr 1
-------------------------------------------------------------------------------
--]]

local xtypes = require('xtypes')
local xmlstring2table = require('xml-parser').xmlstring2table

--[[
TRACE: turn tracing on/off to help debug XML import
--]]
local is_trace_on = true -- turn on tracing?
local function trace(...) 
  return is_trace_on and print('TRACE: ', ...)
end

--[[
Current namespace (module) inside which the child elements are being defined
NOTE: set when loading module elements; reset to nil when not loading a module
--]]
local ns = nil


--[[
Templates created from XML. This list is built as the XML is processed.
--]]
local templates = {}

--[[
Look up the template from a name. Searches in several places:
 - in  the pre-defined xtypes, 
 - in the user-defined templates
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
    
    key              = xtypes.Key,
    optional         = xtypes.Optional,
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
  

  -- lookup in the templates that we have defined so far
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
        for i, template in ipairs(templates) do
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
      template = xtypes.utils.template(template[w])
    end
    
    trace('\t\t ->', template)
  end
 
  if not template then
    trace(table.concat{'\tSkipping unresolved name: "', name, 
          '"  ns = ', ns and xtypes.utils.nsname(ns)})
  end      
                         
  return template
end

-- Takes a comma separated dimension string, eg "1,2" and converts it to a table
-- containing the dimensions: {1, 2}
local function dim_string2array(comma_separated_dimension_string)
    local dim = {}
    for w in string.gmatch(comma_separated_dimension_string, "[%w_]+") do
      local dim_i = tonumber(w) or lookup_type(w)
      table.insert(dim, dim_i)       
      trace('\tdim = ', dim_i)
    end
    return table.unpack(dim)
end

-- Create a role definition table from an XML tag attributes
-- @param xarg [in] the XML tag's attributes
-- @return the role definition specified by the xml xarg attributes
local function xml_xarg2role_definition(xarg)
  local role_definition = {}
  local role_template, sequence, array, value 
  
  -- process the xarg and cache the attributes as they are traversed
  for k, v in pairs(xarg) do
  
      -- skip the attributes that will be processed with other attributes
      if 'name'             == k or
         'stringMaxLength'  == k or 
         'nonBasicTypeName' == k then
          -- do nothing
        
      -- role_template
      elseif 'type'         == k then
        
        -- determine the stringMaxLength 
        local stringMaxLength -- NOTE: "-1" means unbounded
        if xarg.stringMaxLength and '-1' ~= xarg.stringMaxLength then -- bounded
          stringMaxLength = tonumber(xarg.stringMaxLength) or
                            lookup_type(xarg.stringMaxLength)
                            
        end
        
        if 'string' == v then
          role_template = xtypes.string(stringMaxLength)
        elseif 'wstring' == v then
          role_template = xtypes.wstring(stringMaxLength)
        else
          role_template = xarg.nonBasicTypeName -- NOTE: use nonBasic if defined
                            and lookup_type(xarg.nonBasicTypeName)
                            or  lookup_type(xarg.type)
        end
        
      -- collection: sequence
      elseif 'sequenceMaxLength' == k then
        -- determine the stringMaxLength 
        local sequenceMaxLength -- NOTE: "-1" means unbounded
        if '-1' ~= xarg.sequenceMaxLength then -- bounded
          sequenceMaxLength = tonumber(xarg.sequenceMaxLength) or 
                              lookup_type(xarg.sequenceMaxLength) 
                              
        end
        sequence = xtypes.sequence(sequenceMaxLength)
         
      -- collection: array
      elseif 'arrayDimensions' == k then
        array = xtypes.array(dim_string2array(v))
    
      -- constant: value              
      elseif 'value' == k then
        value = v -- let the constant definition do the conversion from string 
        
      -- annotations         
      else
        local annotation = lookup_type(k) 
        if annotation then
          table.insert(role_definition, annotation) -- at the end
        else
          print(table.concat{'WARNING: Skipping unrecognized XML attribute: ',
                              k, ' = ', v})
        end
      end
  end
  
  -- insert the cached attributes in the correct order to for a role definition
  
  -- value
  if value then -- const
    table.insert(role_definition, 1, value) 
  end 
  
  -- collection:
  if array then
    table.insert(role_definition, 1, array) 
  end
  if sequence then 
    table.insert(role_definition, 1, sequence) 
  end
  
  -- role template will always be present, and must be the first item
  table.insert(role_definition, 1, role_template)

  return role_definition
end

--[[
Map an xml tag to an appropriate X-Types template creation function:
      tag --> action to create X-Type template
Each creation function returns the newly created X-Type template
--]]
local tag2template
tag2template = {

  typedef = function(tag)  
    local template = xtypes.typedef{
      [tag.xarg.name] = xml_xarg2role_definition(tag.xarg)
    }
    return template
  end,
  
  const = function(tag)
    local template = xtypes.const{
      [tag.xarg.name] = xml_xarg2role_definition(tag.xarg)
    }
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
    return template
  end,
  
  struct = function (tag)
    local template = xtypes.struct{[tag.xarg.name]=xtypes.EMPTY}

    -- child tags
    for i, child in ipairs(tag) do
      if 'table' == type(child) and 'member' == child.label then-- skip comments
        trace(tag.label, child.label, child.xarg.name)
        template[#template+1] = { 
          [child.xarg.name] = xml_xarg2role_definition(child.xarg)
        }
      end
    end
    return template
  end,
  
  union = function (tag)
    
    local template

    -- child tags
    for i, child in ipairs(tag) do
      if 'table' == type(child) then -- skip comments
      
        if 'discriminator' == child.label then
          template=xtypes.union{[tag.xarg.name]={lookup_type(child.xarg.type)}}
        
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
                      [grandchild.xarg.name] = 
                                    xml_xarg2role_definition(grandchild.xarg)
                }
              end
            end
          end
        end
      end
    end
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
    
    ns = prev_ns-- done with loading name-space: reset context to previous state
    return template
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
    trace('\n-----\n', xml.label, xml.xarg.name)
    table.insert(templates, tag_handler(xml)) 
    trace(table.concat(
                    xtypes.utils.visit_model(templates[#templates], {'IDL:'}), 
                    '\n\t'))
  else -- don't recognize the label as an xtype, visit the child nodes  
    -- process the child nodes
    for i, child in ipairs(xml) do
      if 'table' == type(child) then -- skip comments
        xml2xtypes(child)
      end
    end
  end
  
  return templates
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
Given an XML file, loads the xtype definitions, and return them
@param filename [in] xml file containing XML type definitions
@return an array of xtypes, equivalent to those defined in the xml table
--]]
local function xmlfile2xtypes(filename)
  io.input(filename)
  local xmlstring = io.read("*all")
  return xmlstring2xtypes(xmlstring)
end

-------------------------------------------------------------------------------
local interface = {
    xmlstring2xtypes = xmlstring2xtypes,
    xmlfile2xtypes   = xmlfile2xtypes,
}

return interface
