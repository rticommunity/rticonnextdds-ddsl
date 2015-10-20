#!/usr/bin/env lua
--[[
  (c) 2005-2015 Copyright, Real-Time Innovations, All rights reserved.     
                                                                           
 Permission to modify and use for internal purposes granted.               
 This software is provided "as is", without warranty, express or implied.
--]]

--- Load XML files and output the equivalent IDL for types contained therein.
-- @script xml2idl
-- @author Rajive Joshi

package.path = '../src/?.lua;../src/?/init.lua;' .. package.path

local xtypes = require('ddsl.xtypes')
local xml = require('ddsl.xtypes.xml')
local xutils = require('ddsl.xtypes.utils')

--- @usage
local usage = [[xml2idl [-d] <xml-file> [ <xml-files> ...]
    where:
      -d            turn debugging ON
      <xml-file>    is an XML file
    
    Imports all the XML files into a single X-Types global namespace. 
    Cross-references between files are resolved. However, duplicates 
    definitions are not permitted within a global namespace. 
    
    If there could be duplicates (ie multiple global namespaces), those files 
    should be processed in separate command line invocations of this utility.
]]
    
local function main(arg)
  if #arg == 0 then
    print(usage)
    return
  end

  -- turn on tracing?
  if '-d' == arg[1] then 
    table.remove(arg, 1) -- pop the argument
    xml.log.verbosity(xml.log.DEBUG)
  end

  -- import XML files
  local ns = xml.filelist2xtypes(arg)

  -- print as IDL on stdout
  print(table.concat(xutils.to_idl_string_table(ns), '\n'))
  
  -- TODO: print the DDSL representation  
end

main(arg)
