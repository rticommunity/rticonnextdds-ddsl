#!/usr/bin/env lua
--[[
  (c) 2005-2014 Copyright, Real-Time Innovations, All rights reserved.     
                                                                           
 Permission to modify and use for internal purposes granted.               
 This software is provided "as is", without warranty, express or implied.
--]]

--- Utility to read an XML file and the corresponding Lua table on stdout.
-- @script xml2idl
-- @author Rajive Joshi

--- @usage
local usage = [[Usage: xml2lua <xml-file>]]

package.path = '../../../?.lua;../../../?/init.lua;' .. package.path

local xml = require('ddsl.xtypes.xml.parser')

if #arg == 0 then
  print(usage)
  return
end

local filename = arg[1]
io.input(filename)
local xmlstring = io.read("*a")  
local table = xml.xmlstring2table(xmlstring)
local luastring = xml.table2luastring(table)
print(luastring)
