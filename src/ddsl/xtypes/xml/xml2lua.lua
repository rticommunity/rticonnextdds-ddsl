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
