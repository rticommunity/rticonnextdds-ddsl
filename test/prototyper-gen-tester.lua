--*****************************************************************************
--*    (c) 2005-2013 Copyright, Real-Time Innovations, All rights reserved.   *
--*                                                                           *
--*         Permission to modify and use for internal purposes granted.       *
--* This software is provided "as is", without warranty, express or implied.  *
--*                                                                           *
--*****************************************************************************

---DataReader Generator using RTI Connext Prototyper
-- Subscribes to the first two shapes topics (Square, Circle) and aggregates 
-- them on the last shape topic (Triangle).
--  
-- HOW TO?
-- rtiddsprototyper -cfgName MyParticipantLibrary::ShapePubSub 
--                  -luaFile prototyper-gen-tester.lua
-- 
-- ShapesDemo: 
--		1. Publish Squares and Circles of different colors  
-- 		2. Subscribe to Triangle topic 
-- 				The Triangles should mirror the Squares and Circles

-- Interface: parameters, shapes, outputs
-- shape: First two readers

package.path = '../src/?.lua;../src/?/init.lua;' .. package.path

local CONTEXT = CONTAINER.CONTEXT
local writer = CONTAINER.WRITER[#CONTAINER.WRITER] -- Triangles

CONTEXT.Gen      = CONTEXT.Gen or require("ddslgen.generator")

CONTEXT.shapeMakerFunc = CONTEXT.shapeMakerFunc or 
function (instance)
  local shape = {}
  
  shape.color = instance['color']
  shape.x = instance['x']
  shape.y = instance['y']
  shape.shapesize = instance['shapesize']
  
  return shape
end

CONTEXT.shapeWriteFunc = CONTEXT.shapeWriteFunc or 
function (shape)
  writer.instance['color'] = shape.color
  writer.instance['x'] = shape.x
  writer.instance['y'] = shape.y
  writer.instance['shapesize'] = shape.shapesize
  
  writer:write()    	
end

CONTEXT.shapePrintFunc = CONTEXT.shapePrintFunc or
function(shape)
  print(shape.color .. ", x = " .. shape.x .. ", y = " .. shape.y)
end

CONTEXT.readerGen1 = CONTEXT.readerGen1 or 
                     CONTEXT.Gen.dataReaderGen(CONTAINER.READER[1], shapeMakerFunc)
                     :tap(CONTEXT.shapePrintFunc)
                     :tap(CONTEXT.shapeWriteFunc)

CONTEXT.readerGen2 = CONTEXT.readerGen2 or 
                     CONTEXT.Gen.dataReaderGen(CONTAINER.READER[2], shapeMakerFunc)
                     :tap(CONTEXT.shapePrintFunc)
                     :tap(CONTEXT.shapeWriteFunc)

CONTEXT.readerGen1:generate()
CONTEXT.readerGen2:generate()

