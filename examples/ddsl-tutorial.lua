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

local xtypes   = require('ddsl.xtypes')
local xutils   = require('ddsl.xtypes.utils')

local Tutorial = require('tutorial')
local show     = Tutorial.show

--------------------------------------------------------------------------------
-- DDSL Helpers 
--------------------------------------------------------------------------------

local function show_datatype(datatype, description)
    description = description or (tostring(datatype) .. ' datatype:')
    local idl = xutils.visit_model(datatype, { description })
    show(table.concat(idl, '\n\t'))
end

local function show_instance(instance, description)
    description = description or (tostring(instance) .. ' instance:')
    local values = xutils.visit_instance(instance, { description })
    show(table.concat(values, '\n\t'))
end

--------------------------------------------------------------------------------
-- DDSL Lessons 
--------------------------------------------------------------------------------
local tutorial
tutorial = Tutorial:new{

  ------------------------------------------------------------------------------

  { shapetype = function () 
    
      show('--- define a datatype (template) using declarative style ---')
     
      local MAX_COLOR_LEN = xtypes.const{ MAX_COLOR_LEN = { xtypes.long, 128 } }
      show_datatype(MAX_COLOR_LEN)
      
      local ShapeType = xtypes.struct{
        ShapeType = {
          { x = { xtypes.long } },
          { y = { xtypes.long } },
          { shapesize = { xtypes.long } },
          { color = { xtypes.string(MAX_COLOR_LEN), xtypes.Key } },
        }
      }
      show_datatype(ShapeType)
    
      return MAX_COLOR_LEN, ShapeType
    end
  },

  ------------------------------------------------------------------------------

  { shapetype_imperative = function ()
  
      show('--- define the same datatype (template) using imperative style ---')
      
      local MAX_COLOR_LEN = xtypes.const{ MAX_COLOR_LEN = { xtypes.long, 128 } }
      show_datatype(MAX_COLOR_LEN)
            
      local ShapeType = xtypes.struct{ShapeType=xtypes.EMPTY}
      ShapeType[1] = { x = { xtypes.long } }
      ShapeType[2] = { y = { xtypes.long } }
      ShapeType[3] = { shapesize = { xtypes.long } }
      ShapeType[4] = { color = { xtypes.string(MAX_COLOR_LEN), xtypes.Key } }
      
      show_datatype(ShapeType)
      
      return MAX_COLOR_LEN, ShapeType
    end
  },

  ------------------------------------------------------------------------------

  { shapetype_xml_import = function ()

      local xml = require('ddsl.xtypes.xml')
      
      show('--- import datatypes defined in XML ---')
      local datatypes = xml.files2xtypes({
            '../test/xml-test-simple.xml',
      })
        
      show('--- export datatypes to IDL ---')
      for i = 1, #datatypes do
         show_datatype(datatypes[i], tostring(datatypes[i]) .. ':')
      end
      
      return table.unpack(datatypes)
    end
  },
  
  ------------------------------------------------------------------------------

  { shapetype_model_iterators = function ()

      local MAX_COLOR_LEN, ShapeType = tutorial:dolesson('shapetype')
            
      show("--- iterate through the model members ---")
      for i, member in ipairs(ShapeType) do
        local role, roledef = next(member)
        show('', role, roledef[1], roledef[2], roledef[3])
      end
     
      return MAX_COLOR_LEN, ShapeType
    end
  },
  
  ------------------------------------------------------------------------------
 
  { struct_model_operators = function ()

      local MAX_COLOR_LEN, ShapeType = tutorial:dolesson('shapetype')
          
      show('--- add member z ---')
      ShapeType[#ShapeType+1] = { z = { xtypes.string() , xtypes.Key } }
      show_datatype(ShapeType)
      
      show('--- remove member x ---')
      ShapeType[1] = nil
      show_datatype(ShapeType)
      
      show('--- redefine member y ---')
      ShapeType[1] = { y = { xtypes.double } }
      show_datatype(ShapeType)  
      
      show('--- add a base struct ---')
      local Property = xtypes.struct{
        Property = {
          { name  = { xtypes.string(MAX_COLOR_LEN) } },
          { value = { xtypes.string(MAX_COLOR_LEN) } },
        }
      }
      ShapeType[xtypes.BASE] = Property
      show_datatype(ShapeType) 
      show_instance(ShapeType)
        
      return ShapeType
    end
  },
  
  ------------------------------------------------------------------------------

  { shape_instance = function ()

      local MAX_COLOR_LEN, ShapeType = tutorial:dolesson('shapetype')
      
      show('--- create an instance from the datatype (template) ---')
      local shape = xtypes.utils.new_instance(ShapeType) 
      
      -- shape is equivalent to manually defining the following  --
      local shape_manual = {
          x          = 50,
          y          = 30,
          shapesize  = 20,
          color      = 'GREEN',
      }
     
      show('--- initialize the shape instance from shape_manual table ---')
      for role, _ in pairs(shape_manual) do
        shape[role] = shape_manual[role]
        show('\t', role, shape[role])
      end
     
      show_instance(shape)
      
      return MAX_COLOR_LEN, ShapeType, shape
    end  
  },
  
  ------------------------------------------------------------------------------

  { shape_instance_iterators = function ()

      local MAX_COLOR_LEN, ShapeType, shape = tutorial:dolesson('shape_instance')
      
      show("--- iterate through instance members : unordered ---")
      for role, _ in pairs(shape) do
        show('', role, '=', shape[role])
      end
      
      show("--- iterate through instance members : ordered ---")
      for i, member in ipairs(ShapeType) do
        local role = next(member)
        show('', role, '=', shape[role])
      end
     
      return shape
    end
  },
  
  ------------------------------------------------------------------------------

  { shape_accessors = function ()

      local MAX_COLOR_LEN, ShapeType = tutorial:dolesson('shapetype')
    
      show('--- template member values are DDS DynamicData accessor strings ---')
      show_instance(ShapeType)
      
      return ShapeType
    end
  },

  ------------------------------------------------------------------------------

  { inheritance_and_nested_struct_seq = function ()
    
      local MAX_COLOR_LEN, ShapeType = tutorial:dolesson('shapetype')
    
      show('--- define a property struct ---')
      local Property = xtypes.struct{
        Property = {
          { name  = { xtypes.string(MAX_COLOR_LEN) } },
          { value = { xtypes.string(MAX_COLOR_LEN) } },
        }
      }
      show_datatype(Property) 
      
      show('--- define a derived struct with a sequence of properties ---')
      local ShapeTypeWithProperties = xtypes.struct{
        ShapeTypeWithProperties = {
          ShapeType,
          { properties = { Property, xtypes.sequence(3) } },
        }
      }  
      show_datatype(ShapeTypeWithProperties) 
      
      show('--- template member values are DDS DynamicData accessor strings ---')
      show_instance(ShapeTypeWithProperties)
        
        
      show('--- create a new instance ---')
      local shapeWithProperties = xtypes.utils.new_instance(ShapeTypeWithProperties) 
      shapeWithProperties.x = 50
      shapeWithProperties.y = 30
      shapeWithProperties.shapesize = 20
      shapeWithProperties.color = 'GREEN'
      for i = 1, shapeWithProperties.properties() - 1 do
        shapeWithProperties.properties[i].name  = 'name' .. i
        shapeWithProperties.properties[i].value = i
      end
      show_instance(shapeWithProperties)
        
      show('properties capacity', shapeWithProperties.properties(), -- or 
                                   ShapeTypeWithProperties.properties())
      show('properties length', #shapeWithProperties.properties)
      
      return ShapeTypeWithProperties, shapeWithProperties
    end
  },
 
 
   
  { typedef_traversal = function ()
                  
          --- TODO: Add Typdef Traversal ---
          print(MyBooleanTypedef,
                MyBooleanTypedef[1],  -- boolean
                MyBooleanTypedef[2])  -- nil
          print(MyBooleanSeq,
                MyBooleanSeq[1],  -- MyBooleanTypedef2
                MyBooleanSeq[2])  -- sequence(3)
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
-- main --
tutorial:run(arg[1] or 1)
--------------------------------------------------------------------------------



