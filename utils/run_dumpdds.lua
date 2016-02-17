#!/usr/bin/env lua

package.path = '../src/?.lua;../src/?/init.lua;./src/?.lua;./src/?/init.lua;' .. package.path

require('dumpddsl')
require('io')

xtypes = require('ddsl.xtypes')

local xml = require('ddsl.xtypes.xml')
local xutils = require('ddsl.xtypes.utils')

--- @usage
local usage = [[run_dumpddsl <xml-file> [ <xml-files> ...]
Where:
  -d            turn debugging ON
  <xml-file>    is an XML file
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

--[[
  local file = io.open(arg[1], "r")
  local xmlstring = file:read("*a")
  io.close(file)
  
  local ns = xml.string2xtypes(xmlstring)
]]

  print("DDSL Structure ----------------------------------------------------")
  print(dumpDDSL(ns))

  -- print as IDL on stdout
  print("\n\nIDL ---------------------------------------------------------------")
  print(table.concat(xutils.to_idl_string_table(ns), '\n'))
  

end

main(arg)
