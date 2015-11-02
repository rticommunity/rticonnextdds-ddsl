#!/usr/bin/env lua
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
