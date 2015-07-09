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
    Step though one lesson at a time. Look at the code (this file) side by side.
          ../bin/run ddsl-tutorial [starting_lesson_number]
    OR
          ./ddsl-tutorial.lua [starting_lesson_number]
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

--------------------------------------------------------------------------------
-- Lessons 
--------------------------------------------------------------------------------
local lessons
lessons = {

  ------------------------------------------------------------------------------

  { shapetype = function () 
    
      print('--- define a datatype (template) using declarative style ---')
     
      local MAX_COLOR_LEN = xtypes.const{ MAX_COLOR_LEN = { xtypes.long, 128 } }
      print_datatype(MAX_COLOR_LEN)
      
      local ShapeType = xtypes.struct{
        ShapeType = {
          { x = { xtypes.long } },
          { y = { xtypes.long } },
          { shapesize = { xtypes.long } },
          { color = { xtypes.string(MAX_COLOR_LEN), xtypes.Key } },
        }
      }
      print_datatype(ShapeType)
    
      return MAX_COLOR_LEN, ShapeType
    end
  },

  ------------------------------------------------------------------------------

  { shapetype_imperative = function ()
  
      print('--- define the same datatype (template) using imperative style ---')
      
      local MAX_COLOR_LEN = xtypes.const{ MAX_COLOR_LEN = { xtypes.long, 128 } }
      print_datatype(MAX_COLOR_LEN)
            
      local ShapeType = xtypes.struct{ShapeType=xtypes.EMPTY}
      ShapeType[1] = { x = { xtypes.long } }
      ShapeType[2] = { y = { xtypes.long } }
      ShapeType[3] = { shapesize = { xtypes.long } }
      ShapeType[4] = { color = { xtypes.string(MAX_COLOR_LEN), xtypes.Key } }
      
      print_datatype(ShapeType)
      
      return MAX_COLOR_LEN, ShapeType
    end
  },

  ------------------------------------------------------------------------------

  { shapetype_xml_import = function ()

      local xml = require('ddsl.xtypes.xml')
      
      print('--- import datatypes defined in XML ---')
      local datatypes = xml.files2xtypes({
            '../test/xml-test-simple.xml',
      })
        
      print('--- export datatypes to IDL ---')
      for i = 1, #datatypes do
         print_datatype(datatypes[i], tostring(datatypes[i]) .. ':')
      end
      
      return table.unpack(datatypes)
    end
  },

  ------------------------------------------------------------------------------

  { shape_instance = function ()

      local MAX_COLOR_LEN, ShapeType = lessons[1].shapetype()
      
      print('--- create an instance from the datatype (template) ---')
      local shape = xtypes.utils.new_instance(ShapeType) 
      
      -- shape is equivalent to manually defining the following  --
      local shape_manual = {
          x          = 50,
          y          = 30,
          shapesize  = 20,
          color      = 'GREEN',
      }
     
      print('--- initialize the shape instance from shape_manual table ---')
      for role, _ in pairs(shape_manual) do
        shape[role] = shape_manual[role]
        print('\t', role, shape[role])
      end
     
      print_instance(shape)
      
      return MAX_COLOR_LEN, ShapeType, shape
    end  
  },
  
  ------------------------------------------------------------------------------

  { shape_instance_iterators = function ()

      local MAX_COLOR_LEN, ShapeType, shape = lessons[4].shape_instance()
    
      print("--- iterate through instance members : unordered ---")
      for role, _ in pairs(shape) do
        print('', role, '=', shape[role])
      end
      
      print("--- iterate through instance members : ordered ---")
      for i, member in ipairs(ShapeType) do
        local role = next(member)
        print('', role, '=', shape[role])
      end
     
      return shape
    end
  },
  
  ------------------------------------------------------------------------------

  { shape_accessors = function ()

      local MAX_COLOR_LEN, ShapeType = lessons[1].shapetype()
    
      print('--- template member values are DDS DynamicData accessor strings ---')
      print_instance(ShapeType)
      
      return ShapeType
    end
  },
  
  ------------------------------------------------------------------------------
 
  { struct_model_operators = function ()

      local MAX_COLOR_LEN, ShapeType = lessons[1].shapetype()
    
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
  },
  
  ------------------------------------------------------------------------------

  { shape_with_properties = function ()
    
      local MAX_COLOR_LEN, ShapeType = lessons[1].shapetype()
    
      print('--- define a property struct ---')
      local Property = xtypes.struct{
        Property = {
          { name  = { xtypes.string(MAX_COLOR_LEN) } },
          { value = { xtypes.string(MAX_COLOR_LEN) } },
        }
      }
      print_datatype(Property) 
      
      print('--- define a derived struct with a sequence of properties ---')
      local ShapeTypeWithProperties = xtypes.struct{
        ShapeTypeWithProperties = {
          ShapeType,
          { properties = { Property, xtypes.sequence(3) } },
        }
      }  
      print_datatype(ShapeTypeWithProperties) 
      
      print('--- template member values are DDS DynamicData accessor strings ---')
      print_instance(ShapeTypeWithProperties)
        
        
      print('--- create a new instance ---')
      local shapeWithProperties = xtypes.utils.new_instance(ShapeTypeWithProperties) 
      shapeWithProperties.x = 50
      shapeWithProperties.y = 30
      shapeWithProperties.shapesize = 20
      shapeWithProperties.color = 'GREEN'
      for i = 1, shapeWithProperties.properties() - 1 do
        shapeWithProperties.properties[i].name  = 'name' .. i
        shapeWithProperties.properties[i].value = i
      end
      print_instance(shapeWithProperties)
        
      print('properties capacity', shapeWithProperties.properties(), -- or 
                                   ShapeTypeWithProperties.properties())
      print('properties length', #shapeWithProperties.properties)
      
      return ShapeTypeWithProperties, shapeWithProperties
    end
  },
 
 
  --[[ Lesson Template: copy and paste the content to create the next lesson

  ------------------------------------------------------------------------------

  { next_lesson_title = function ()
        
    end 
  },

  --]]
}

--------------------------------------------------------------------------------
-- main
--------------------------------------------------------------------------------
local starting_lesson = arg[1] or 1

print('========== Welcome to the DDSL tutorial! ==========')
print('--- Step though one lesson at a time. Look at the code side by side ---')
print('starting at lesson', starting_lesson, ' of ', #lessons)

for i = starting_lesson, #lessons do
  local title, lesson = next(lessons[i])
  
  print('\nPress RETURN to go to the next lesson...')
  io.read()
  
  print('========== Lesson', i .. '/' .. #lessons, title, '==========')
  lesson() -- run the lesson
end
print('\n========== Congratulations on completing the DDSL tutorial!! ==========')
--------------------------------------------------------------------------------



