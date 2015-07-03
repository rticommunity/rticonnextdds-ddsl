#!/usr/bin/env lua
--[[
  (c) 2005-2015 Copyright, Real-Time Innovations, All rights reserved.     
                                                                           
 Permission to modify and use for internal purposes granted.               
 This software is provided "as is", without warranty, express or implied.
--]]
--[[
-------------------------------------------------------------------------------
Purpose: Utility to read an XML file as DDSL, and print the equivalent IDL
Created: Rajive Joshi, 2015 Jun 26
-------------------------------------------------------------------------------
--]]

package.path = '?.lua;?/init.lua;' .. package.path

local xtypes = require('ddsl.xtypes')
local xml = require('ddsl.xtypes.xml')

local function main(arg)
  if #arg == 0 then
    print('Usage: ' .. arg[0] .. [[' [-t] <xml-file> [ <xml-files> ...]
    
    where:
      -t            turn tracing ON
      <xml-file>    is an XML file
    
    Imports all the XML files into a single X-Types global namespace. 
    Cross-references between files are resolved. However, duplicates 
    definitions are not permitted within a global namespace. 
    
    If there could be duplicates (ie multiple global namespaces), those files 
    should be processed in separate command line invocations of this utility.
    ]])
    return
  end

  -- turn on tracing?
  if '-t' == arg[1] then 
    table.remove(arg, 1) -- pop the argument
    xml.is_trace_on = true
  end

  -- import XML files
  local schemas = xml.files2xtypes(arg)

  -- print on stdout
  print('\n********* DDSL: Global X-Types Namespace *********')
  for _, schema in ipairs(schemas) do
    -- print IDL
    local idl = xtypes.utils.visit_model(schema, {'\t'})
    print(table.concat(idl, '\n\t'))

    -- print the result of visiting each field
    --local fields = xtypes.utils.visit_instance(instance, {'instance:'})
    --print(table.concat(fields, '\n\t'))
    
    -- TODO: print the DDSL representation
  end  
  print('\n********* DDSL: ' .. #schemas .. ' elements *********')
end

main(arg)
