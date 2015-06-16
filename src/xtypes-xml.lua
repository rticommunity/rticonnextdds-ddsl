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

local is_trace_on = true
function trace(...) 
  if is_trace_on then return print('TRACE: ', ...) end
end


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
  for i, template in ipairs(templates) do
    if name == template[xtypes.NAME] then
      return template
    end
  end
  
  trace(table.concat{'Skipping unresolved name: "', name, '"'})
                              
  return nil
end

-- Takes a comma separated dimension string, eg "1,2" and converts it to a table
-- containing the dimensions: {1, 2}
local function dim_string2array(comma_separated_dimension_string)
    local dim = {}
    for w in string.gmatch(comma_separated_dimension_string, "[%w_]+") do
      table.insert(dim, lookup_type(w) or tonumber(w))
      trace('dim = ', w, lookup_type(w))
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
          stringMaxLength = lookup_type(xarg.stringMaxLength) or 
                            tonumber(xarg.stringMaxLength)
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
          sequenceMaxLength = lookup_type(xarg.sequenceMaxLength) or 
                              tonumber(xarg.sequenceMaxLength)
        end
        sequence = xtypes.sequence(sequenceMaxLength)
         
      -- collection: array
      elseif 'arrayDimensions' == k then
        array = xtypes.array(dim_string2array(v))
    
      -- constant: value              
      elseif 'value' == k then
        value = lookup_type(v) or v -- use the string literal if not found
        
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
    
  enum = function(tag)
    local template = xtypes.enum{
      [tag.xarg.name] = xtypes.EMPTY
    }
    
    -- child tags
    local member_count = 0
    for i, child in ipairs(tag) do
      if 'table' == type(child) then -- skip comments
        member_count = member_count + 1
        if child.xarg.value then
          template[member_count] = { 
              [child.xarg.name] = tonumber(child.xarg.value) 
          }
        else
          template[member_count] = child.xarg.name
        end
      end
    end
    return template
  end,
  
  struct = function (tag)
    local template = xtypes.struct{[tag.xarg.name]=xtypes.EMPTY}

    -- child tags
    local member_count = 0
    for i, child in ipairs(tag) do
      if 'table' == type(child) then -- skip comments
        member_count = member_count + 1
        trace(tag.label, child.label, child.xarg.name)
        template[member_count] = { 
          [child.xarg.name] = xml_xarg2role_definition(child.xarg)
        }
      end
    end
    return template
  end,
  
  union = function (tag)
    
    local template

    -- child tags
    local member_count = 0
    for i, child in ipairs(tag) do
      if 'table' == type(child) then -- skip comments
      
        if 'discriminator' == child.label then
          template=xtypes.union{[tag.xarg.name]={lookup_type(child.xarg.type)}}
        
        elseif 'case' == child.label then
          member_count = member_count + 1
          local case = nil -- default
          for j, grandchild in ipairs(child) do
            trace(tag.label, child.label, grandchild.label, 
                  grandchild.xarg.name or grandchild.xarg.value)
            if 'table' == type(grandchild) then -- skip comments
              if 'caseDiscriminator' == grandchild.label then
                 if 'default' ~= grandchild.xarg.value then
                   case = lookup_type(grandchild.xarg.value) or 
                          tonumber(grandchild.xarg.value) -- TODO
                 end
              else -- member
                template[member_count] = { 
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
  
  -- module
}

-- Legacy tags:
tag2template.valuetype = function (tag)
    print('WARNING: Importing valuetype as a struct')
    return tag2template.struct(tag)
end
    
    
--[[
Visit all the nodes in the xml table, and a return a table containing the 
xtype definitions
@param xml [in] a table generated from XML
@return an array of xtypes, equivalent to those defined in the xml table
--]]
local function xml2xtypes(xml)

  local xtype = tag2template[xml.label]
  if xtype then -- process this node (and its child nodes)
    trace(xml.label, xml.xarg.name)
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

