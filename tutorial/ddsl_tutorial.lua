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

  { intro = function ()
      show([[
      
                      Welcome to the DDSL Tutorial!
                      
        Please open this lua tutorial source file in a code viewer/editor,
        and follow along the lessons, one at a time, at your own pace. 
        
        You can rerun the tutorial, or jump to a specific  lesson simply by
        running this lua script with the lesson number, thus:
            ddsl_tutorial <n>
        where n is the lesson number to jump to or restart from.
      ]]) 
    end 
  },

  ------------------------------------------------------------------------------
  
  { const = function ()
    
      local MAX_COLOR_LEN = xtypes.const{ MAX_COLOR_LEN = { xtypes.long, 128 } }

      local value, datatype
      
      show('--- MAX_COLOR_LEN ---')
      show_datatype(MAX_COLOR_LEN)
            
      value, datatype = MAX_COLOR_LEN()
      
      show('\tvalue    ',  value)     
      assert(value == 128)
      
      show('\tdatatype', datatype)
      assert(datatype == xtypes.long)
                
      return MAX_COLOR_LEN
    end 
  },

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
      local datatypes = xml.filelist2xtypes({
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
         
      show("--- show model attributes ---")
      show('KIND', ShapeType[xtypes.KIND]())
      show('NS', ShapeType[xtypes.NS])
      show('NAME', ShapeType[xtypes.NAME])
      show('QUALIFIERS', ShapeType[xtypes.QUALIFIERS])
      show('BASE', ShapeType[xtypes.BASE])
      show('SWITCH', ShapeType[xtypes.SWITCH])
                     
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
      local shape = xtypes.new_instance(ShapeType) 
      
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
      
      show("--- show model attributes ---")
      show('KIND', shape[xtypes.KIND]())
      show('NS', shape[xtypes.NS])
      show('NAME', shape[xtypes.NAME])
      show('QUALIFIERS', shape[xtypes.QUALIFIERS])
      show('BASE', shape[xtypes.BASE])
      show('SWITCH', shape[xtypes.SWITCH])
      
      show('template', xtypes.template(shape))
      assert(xtypes.template(shape) == ShapeType)
            
      return MAX_COLOR_LEN, ShapeType, shape
    end  
  },
  
  ------------------------------------------------------------------------------

  { shape_instance_iterators = function ()

      local MAX_COLOR_LEN,ShapeType,shape = tutorial:dolesson('shape_instance')
      
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
          { properties = { Property, xtypes.sequence(5) } },
        }
      }  
      show_datatype(ShapeTypeWithProperties) 
      
      show('--- template member values are DDSDynamicData accessor strings ---')
      show_instance(ShapeTypeWithProperties)
        
        
      show('--- create a new instance ---')
      local shapeWithProperties = xtypes.new_instance(ShapeTypeWithProperties) 
      shapeWithProperties.x = 50
      shapeWithProperties.y = 30
      shapeWithProperties.shapesize = 20
      shapeWithProperties.color = 'GREEN'
      for i = 1, shapeWithProperties.properties() - 2 do
        shapeWithProperties.properties[i].name  = 'name' .. i
        shapeWithProperties.properties[i].value = i
      end
      show_instance(shapeWithProperties)
        
      show('properties is_collection ?',
                          xtypes.is_collection(shapeWithProperties.properties))
      assert(xtypes.is_collection(shapeWithProperties.properties) == true)
      assert(shapeWithProperties.properties() == 5)
        
      show('properties capacity', shapeWithProperties.properties(), -- or 
                                   ShapeTypeWithProperties.properties())
      show('properties length', #shapeWithProperties.properties)
      assert(#shapeWithProperties.properties == 3)
       
      return ShapeTypeWithProperties, shapeWithProperties
    end
  },
 
  ------------------------------------------------------------------------------ 
   
  { typedefs = function ()
    
      local MAX_COLOR_LEN, ShapeType = tutorial:dolesson('shapetype')
      local MyShape = xtypes.typedef{ 
        MyShape = { ShapeType } 
      }
      local MyShapeSeq = xtypes.typedef{ 
        MyShapeSeq = { MyShape, xtypes.sequence(7) } 
      }
      local MyShapeSeqArray = xtypes.typedef{ 
        MyShapeSeqArray = { MyShapeSeq, xtypes.array(3,5) } 
      }
  
      local alias, collection_qualifier

      
      show('--- MyShapeSeqArray ---')
      show_datatype(MyShapeSeqArray)
            
      alias, collection_qualifier = MyShapeSeqArray()
      
      show('\talias    ',  alias)     
      assert(alias == MyShapeSeq)
      
      show('\tqualifier', collection_qualifier, 
                          collection_qualifier[xtypes.NAME], 
                          collection_qualifier[1], collection_qualifier[2])
      assert(collection_qualifier[xtypes.NAME] == 'array' and 
             collection_qualifier[1] == 3, collection_qualifier[1] == 5)
         
         
      show('--- MyShapeSeq ---')
      show_datatype(MyShapeSeq) 
            
      alias, collection_qualifier = MyShapeSeq()
      
      show('\talias    ',  alias)     
      assert(alias == MyShape)
      
      show('\tqualifier', collection_qualifier, 
                          collection_qualifier[xtypes.NAME], 
                          collection_qualifier[1])
      assert(collection_qualifier[xtypes.NAME] == 'sequence' and 
             collection_qualifier[1] == 7)
             
             
      show('--- MyShape ---')
      show_datatype(MyShape) 
            
      alias, collection_qualifier = MyShape()
      
      show('\talias    ',  alias)     
      assert(alias == ShapeType)
      
      show('\tqualifier', collection_qualifier)
      assert(collection_qualifier == nil)
             
             
      show('--- resolve ---')
      show('\tMyShapeSeqArray -> ', xtypes.resolve(MyShapeSeqArray)) 
               
      return MAX_COLOR_LEN, ShapeType, MyShape, MyShapeSeq, MyShapeSeqArray
    end 
  },

  ------------------------------------------------------------------------------

  { enum_declarative = function ()
      -- local Weekdays = {}
      -- 
    end
  },
  
  ------------------------------------------------------------------------------

  { enum_imperative = function ()
      -- local Months = {}
      -- 
    end
  },
  
  ------------------------------------------------------------------------------

  { union_declarative = function ()
      -- local MyDiscrim = typedef Weekdays
    end
  },
 
   ------------------------------------------------------------------------------

  { union_imperative = function ()
      -- local MyDiscrim = typedef Months
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



