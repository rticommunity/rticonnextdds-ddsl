#!/usr/bin/env lua
--[[
  (c) 2005-2015 Copyright, Real-Time Innovations, All rights reserved.     
                                                                           
 Permission to modify and use for internal purposes granted.               
 This software is provided "as is", without warranty, express or implied.
--]]
--[[
 -----------------------------------------------------------------------------
 Purpose: DDSL Tutorial
 Created: Rajive Joshi, 2015 Jul 7
 Usage:
          ../bin/run ddsl-tutorial
    OR
          ./ddsl-tutorial.lua
-----------------------------------------------------------------------------
--]]

package.path = '../src/?.lua;../src/?/init.lua;' .. package.path

local xtypes = require('ddsl.xtypes')
local xutils = require('ddsl.xtypes.utils')

--------------------------------------------------------------------------------
-- Helpers 
--------------------------------------------------------------------------------

local function print_datatype(datatype, description)
    description = description or (tostring(datatype) .. ' datatype:')
    local idl = xutils.visit_model(datatype, { description })
    print(table.concat(idl, '\n\t'))
end

local function print_instance(instance, description)
    description = description or (tostring(instance) .. ' instance:')
    local values = xutils.visit_instance(instance, { description })
    print(table.concat(values, '\n\t'))
end

local function shapetype() 
  local MAX_COLOR_LEN = xtypes.const{ MAX_COLOR_LEN = { xtypes.long, 128 } }
 
  local ShapeType = xtypes.struct{
    ShapeType = {
      { x = { xtypes.long } },
      { y = { xtypes.long } },
      { shapesize = { xtypes.long } },
      { color = { xtypes.string(MAX_COLOR_LEN), xtypes.Key } },
    }
  }
  return MAX_COLOR_LEN, ShapeType
end

--------------------------------------------------------------------------------
-- Lessons 
--------------------------------------------------------------------------------
local lessons = {}

local function intro ()
 
  print('--- Define a datatype using declarative style ---')
 
  local MAX_COLOR_LEN = xtypes.const{ MAX_COLOR_LEN = { xtypes.long, 128 } }
 
  local ShapeType = xtypes.struct{
    ShapeType = {
      { x = { xtypes.long } },
      { y = { xtypes.long } },
      { shapesize = { xtypes.long } },
      { color = { xtypes.string(MAX_COLOR_LEN), xtypes.Key } },
    }
  }
  print_datatype(ShapeType)

  print('--- Create an instance from the datatype ---')
  local shape = xtypes.utils.new_instance(ShapeType) 
  
  -- shape is equivalent to manually defining the following  --
  local shape_manual = {
      x          = 50,
      y          = 30,
      shapesize  = 20,
      color      = 'GREEN',
  }
  
  print("--- Iterate through instance members : unordered ---")
  for role, _ in pairs(shape) do
    shape[role] = shape_manual[role]
    print('\t', role, shape[role])
  end
  
  print("--- Use the helper to print the instance ---")
  print_instance(shape, 'shape:')
  
  print("--- Iterate through instance members : ordered ---")
  for i, member in ipairs(ShapeType) do
    local role = next(member)
    print('', role, '=', shape[role])
  end
  

  print('--- Datatype is a special instance whose values are the accessor strings ---')
  print_instance(ShapeType)
  
  return MAX_COLOR_LEN, ShapeType, shape
end
lessons[#lessons+1] = intro

--------------------------------------------------------------------------------

local function struct_ShapeType_imperative ()

  print('--- Define the same datatype using imperative style ---')
  
  local MAX_COLOR_LEN = xtypes.const{ MAX_COLOR_LEN = { xtypes.long, 128 } }
  
  local ShapeType = xtypes.struct{ShapeType=xtypes.EMPTY}
  ShapeType[1] = { x = { xtypes.long } }
  ShapeType[2] = { y = { xtypes.long } }
  ShapeType[3] = { shapesize = { xtypes.long } }
  ShapeType[4] = { color = { xtypes.string(MAX_COLOR_LEN), xtypes.Key } }
  
  print_datatype(ShapeType)
  
  return MAX_COLOR_LEN, ShapeType
end
lessons[#lessons+1] = struct_ShapeType_imperative

--------------------------------------------------------------------------------

local function xml2idl ()

  local xml = require('ddsl.xtypes.xml')
  
  print('--- Import datatypes defined in XML ---')
  local datatypes = xml.files2xtypes({
        '../test/xml-test-simple.xml',
  })
    
  print('--- Export datatypes to IDL ---')
  for i = 1, #datatypes do
     print_datatype(datatypes[i], tostring(datatypes[i]) .. ':')
  end
end
lessons[#lessons+1] = xml2idl

--------------------------------------------------------------------------------

local function struct_model_operators ()

  local MAX_COLOR_LEN, ShapeType = shapetype()

  print('--- add member z ---')
  ShapeType[#ShapeType+1] = { z = { xtypes.string() , xtypes.Key } }
  print_datatype(ShapeType)
  
  print('--- remove member x ---')
  ShapeType[1] = nil
  print_datatype(ShapeType)
  
  print('--- redefine member y ---')
  ShapeType[1] = { y = { xtypes.double } }
  print_datatype(ShapeType)  
  
  print('--- add a base struct ---')
  local Property = xtypes.struct{
    Property = {
      { name  = { xtypes.string(MAX_COLOR_LEN) } },
      { value = { xtypes.string(MAX_COLOR_LEN) } },
    }
  }
  ShapeType[xtypes.BASE] = Property
  print_datatype(ShapeType) 
  print_instance(ShapeType)
    
  return ShapeType
end
lessons[#lessons+1] = struct_model_operators

--------------------------------------------------------------------------------

local function instances ()

  local MAX_COLOR_LEN, ShapeType = shapetype()

  print('--- define a property struct ---')
  local Property = xtypes.struct{
    Property = {
      { name  = { xtypes.string(MAX_COLOR_LEN) } },
      { value = { xtypes.string(MAX_COLOR_LEN) } },
    }
  }
  
  print('--- define a derived struct with a sequence of properties ---')
  local ShapeTypeWithProperties = xtypes.struct{
    ShapeTypeWithProperties = {
      ShapeType,
      { properties = { Property, xtypes.sequence(3) } },
    }
  }  
  print_datatype(ShapeTypeWithProperties) 
  print_instance(ShapeTypeWithProperties)
    
  print('--- create a new instance ---')
  local shapeWithProperties = xtypes.utils.new_instance(ShapeTypeWithProperties) 
  shapeWithProperties.x = 50
  shapeWithProperties.y = 30
  shapeWithProperties.shapesize = 20
  shapeWithProperties.color = 'GREEN'
  for i = 1, shapeWithProperties.properties() do
    shapeWithProperties.properties[i].name  = 'name' .. i
    shapeWithProperties.properties[i].value = i
  end
  print('properties capacity', shapeWithProperties.properties(), -- or 
                               ShapeTypeWithProperties.properties())
  print('properties length', #shapeWithProperties.properties)
  print_instance(shapeWithProperties)
    
  return ShapeTypeWithProperties, shapeWithProperties
end

lessons[#lessons+1] = instances

--------------------------------------------------------------------------------
-- Execute the Lessons 
--------------------------------------------------------------------------------
for i = 1, #lessons do
  print('\n========== Lesson', i, '==========')
  lessons[i]()
end
--------------------------------------------------------------------------------



