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
Templates created from XML. This list is built as the XML is processed.
--]]
local templates = {}

--[[
Look up the template from a name. Searches in several places:
 - in  the pre-defined xtypes, 
 - in the user-defined templates
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
  }
  -- lookup in the deviations table
  if xmlName2Model[name] then return xmlName2Model[name] end

  -- lookup in the xtypes pre-defined templates
  for i, template in pairs(xtypes) do
    if 'table' == type(template) and
       template[xtypes.KIND] and -- this is a valid X-Type
       name == template[xtypes.NAME] then
      return template
    end
  end
  
  -- lookup in the templates that we have defined so far
  for i, template in ipairs(templates) do
    if name == template[xtypes.NAME] then
      return template
    end
  end
  
  print(table.concat{'WARNING: Skipping unresolved name: ', name})
                              
  return nil
end

-- Takes a comma separated dimension string, eg "1,2" and converts it to a table
-- containing the dimensions: {1, 2}
local function dim_string2array(comma_separated_dimension_string)
    local dim = {}
    for w in string.gmatch(comma_separated_dimension_string, "[%w_]+") do
      table.insert(dim, lookup_type(w) or tonumber(w))--TODO
    end
    return dim
end

-- Create a role definition table from an XML tag attributes
-- @param xarg [in] the XML tag's attributes
-- @return the role definition specified by the xml xarg attributes
local function xml_xarg2role_definition(xarg)
  local role_definition = {}
  for k, v in pairs(xarg) do
  
      -- skip the attributes that will be processed with other attributes
      if 'name'             == k or
         'stringMaxLength'  == k or 
         'nonBasicTypeName' == k then
          -- do nothing
        
      -- role_template
      elseif 'type'         == k then
         
        local role_template
        if 'string' == v then
          role_template = xtypes.string(lookup_type(xarg.stringMaxLength) or 
                                        tonumber(xarg.stringMaxLength))--TODO
        elseif 'wstring' == v then
          role_template = xtypes.wstring(lookup_type(xarg.stringMaxLength) or 
                                         tonumber(xarg.stringMaxLength))--TODO
        else
          role_template = xarg.nonBasicTypeName -- NOTE: use nonBasic if defined
                            and lookup_type(xarg.nonBasicTypeName)
                            or  lookup_type(xarg.type)
        end
        
        table.insert(role_definition, 1, role_template) -- at the beginning
        
      -- collection: sequence
      elseif 'sequenceMaxLength' == k then
          local sequence = xtypes.sequence(lookup_type(v) or tonumber(v))--TODO
          table.insert(role_definition, 2, sequence) -- at the 2nd position
              
      -- collection: array
      elseif 'arrayDimensions' == k then
          local array = xtypes.array(dim_string2array(v))
          table.insert(role_definition, 2, array) -- at the 2nd position
          
      -- constant: value              
      elseif 'value' == k then
         table.insert(role_definition, v) -- at the end
        
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
  return role_definition
end

--[[
Map an xml tag to an appropriate X-Types template creation function:
      tag --> action to create X-Type template
Each creation function returns the newly created X-Type template
--]]
local tag2template = {

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

  struct = function (tag)
    local template = xtypes.struct{[tag.xarg.name]=xtypes.EMPTY}

    -- child tags
    for i, child in ipairs(tag) do
      if 'table' == type(child) then -- skip comments
        template[i] = { 
          [child.xarg.name] = xml_xarg2role_definition(child.xarg)
        }
      end
    end
    return template
  end,
}

--[[
Visit all the nodes in the xml table, and a return a table containing the 
xtype definitions
@param xml [in] a table generated from XML
@return an array of xtypes, equivalent to those defined in the xml table
--]]
local function xml2xtypes(xml)

  local xtype = tag2template[xml.label]
  if xtype then -- process this node (and its child nodes)
    table.insert(templates, xtype(xml)) 
    local idl = xtypes.utils.visit_model(templates[#templates], {'IDL:'})
    print(table.concat(idl, '\n\t')) 
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

