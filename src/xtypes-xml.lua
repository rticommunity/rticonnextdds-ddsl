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
Look up the given type name first in the user-defined templates, and 
then in the pre-defined xtype library. 
@param name [in] name of the type to lookup
@return the template referenced, or nil.
--]]
local function lookup_type(name)
  -- first lookup in the templates that we have defined so far
  for i, template in ipairs(templates) do
    if name == template[xtypes.NAME] then
      return template
    end
  end
  
  -- then lookup in the xtypes pre-defined templates
  for i, template in pairs(xtypes) do
    if 'table' == type(template) and
       template[xtypes.KIND] and -- this is a valid X-Type
       name == template[xtypes.NAME] then
      return template
    end
  end
  
  return nil
end

--[[
Map an xml tag to an appropriate X-Types 
   xml tag --> create the corresponding xtype (if appropriate)
Each creation function returns the newly created X-Type template
--]]
local tag2xtype = {

  const = function(tag)
    local template = xtypes.const{[tag.xarg.name] = {
      lookup_type(tag.xarg.type),
      tag.xarg.value, -- automatically coerced from string to the correct type
    }}
    return template
  end,
  
  struct = function (tag)
    local template = xtypes.struct{[tag.xarg.name]=xtypes.EMPTY}

    -- child tags
    for i, child in ipairs(tag) do
      if 'table' == type(child) then -- skip comments
        template[i] = { [child.xarg.name] = { 
          -- type
          child.xarg.stringMaxLength 
              and 
                (('string' == child.xarg.type)
                    and xtypes.string(lookup_type(child.xarg.stringMaxLength))
                    or  xtypes.wstring(lookup_type(child.xarg.stringMaxLength)))
              or lookup_type(child.xarg.type),
             
          -- key?
          child.xarg.key and xtypes.Key           
        }}
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

  local xtype = tag2xtype[xml.label]
  if xtype then -- process this node (and its child nodes)
    table.insert(templates, xtype(xml)) 
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

