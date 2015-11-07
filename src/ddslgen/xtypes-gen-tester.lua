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

package.path = '../../?.lua;../../?/init.lua;' .. package.path

local xtypes = require("ddsl.xtypes")
local xutils = require("ddsl.xtypes.utils")
local Gen    = require("ddsl.xtypes.generator")

local Tester = {}

function getAllData(t, prevData)
  -- if prevData == nil, start empty, otherwise start with prevData
  local data = prevData or {}

  -- copy all the attributes from t
  for k,v in pairs(t) do
    data[k] = data[k] or v
  end

  -- get t's metatable, or exit if not existing
  local mt = getmetatable(t)
  if type(mt)~='table' then return data end

  -- get the __index from mt, or exit if not table
  local index = mt.__index
  if type(index)~='table' then return data end

  -- include the data from index into data, recursively, and return
  return getAllData(index, data)
end

--[[Tester[#Tester+1] = 'test_union_gen'
function Tester:test_union_gen()

  local TestUnion = xtypes.union{
    TestUnion = {xtypes.short,
      { 1,   x = { xtypes.string() } },
      { 2,   y = { xtypes.long_double } },
      { nil, z = { xtypes.boolean } }, -- default
    }
  }
  
  self:print(TestUnion)
  
  assert(TestUnion._d == '#')
  assert(TestUnion.x == 'x')
  assert(TestUnion.y == 'y')
  assert(TestUnion.z == 'z')
 
  local memoize = false
  local lib = {}
  local unionGen = Gen.aggregateGen(TestUnion, lib, memoize)
  local union = unionGen:generate()

  print("union._d = ", union._d)

end]]

Tester[#Tester+1] = 'test_struct_gen'
function Tester.test_struct_gen()
  local ShapeType = xtypes.struct{
    ShapeType = {
      { x = { xtypes.long } },
      { y = { xtypes.long } },
      { shapesize = { xtypes.long } },
      { color = { xtypes.string(128), xtypes.Key } },
    }
  }
  Tester.print(ShapeType)
  
  assert('x'         == ShapeType.x)
  assert('y'         == ShapeType.y)
  assert('shapesize' == ShapeType.shapesize)
  assert('color'     == ShapeType.color)   

  local shapeGenLib = {}
  shapeGenLib.x         = Gen.rangeGen(0, 200)
  shapeGenLib.y         = Gen.rangeGen(0, 200)
  shapeGenLib.color     = Gen.oneOf({ "RED", "GREEN", "BLUE" })
  shapeGenLib.shapesize = Gen.rangeGen(20, 30)

  local memoize = false
  local ShapeTypeGen = Gen.aggregateGen(ShapeType, shapeGenLib, memoize)
  local shape = ShapeTypeGen:generate()

  print("shape.x = " .. shape.x)
  print("shape.y = " .. shape.y)
  print("shape.color = " .. shape.color)
  print("shape.shapesize = " .. shape.shapesize)

  return ShapeTypeGen
end

Tester[#Tester+1] = 'test_seq_gen'
function Tester.test_seq_gen()
  local seqGen = Gen.seqGen(Gen.Float, 5)
  local seq = seqGen:generate()
  for k, v in ipairs(seq) do
    print(k, v)
  end
end

Tester[#Tester+1] = 'test_aggregate_gen'
function Tester.test_aggregate_gen()
  local ShapeTypeGen = Tester.test_struct_gen()
  print()

  local seqGen = Gen.seqGen(ShapeTypeGen, 3)
  local seq = seqGen:generate()

  for k, shape in ipairs(seq) do
    for member, value in pairs(shape) do
      print(member, value)
    end
    print()
  end
end

Tester[#Tester+1] = 'test_base_gen'
function Tester.test_base_gen()
    
  local Geometry = xtypes.module{
    Geometry = {
      xtypes.struct{
        Point = {
          { x = { xtypes.float } },
          { y = { xtypes.float } }
        }
      },
    }
  }

  Geometry[#Geometry+1] = xtypes.struct {
    ThreeDPoint = { 
      { z = { xtypes.double } }
    }
  }

  Geometry.ThreeDPoint[xtypes.BASE] = 
    Geometry.Point
  
  Tester.print(Geometry)
 
  assert(Geometry.ThreeDPoint.z == 'z')
 
  local PointGen = Gen.aggregateGen(Geometry.ThreeDPoint)
  local point = PointGen:generate()
  print(point.x, point.y, point.z)

end

Tester[#Tester+1] = 'test_struct_moderate'
function Tester.test_struct_moderate()
  
  local Test = {}
  Test.Color = xtypes.enum{Colors = {
      { RED =  -5 },
      { YELLOW =  7 },
      { GREEN = -9 },
      'PINK',
  }}

  Test.Point = xtypes.struct {
      Point = {
        { x = { xtypes.float } },
        { y = { xtypes.float } }
      }
  }

  Test.Name = xtypes.struct{
    Name = {
      { first     = { xtypes.string(10),   xtypes.Key         } },
      { last      = { xtypes.wstring(128)                     } },
      { nicknames = { xtypes.string(40),   xtypes.sequence(3) } },
      { aliases   = { xtypes.string(),     xtypes.sequence()  } },
      { birthday  = { xtypes.long,         xtypes.Optional    } },
      { multidim  = { xtypes.long,         xtypes.sequence(3),
                                           xtypes.sequence(4) } },
      { favorite  = { Test.Color,          xtypes.sequence(2), xtypes.Optional } },
      { trajectory= { Test.Point,          xtypes.sequence(3) } }
    }
  }
  Tester.print(Test.Name)

  assert(Test.Name.first == 'first')
  assert(Test.Name.last == 'last')
  assert(#Test.Name.nicknames == 'nicknames#')
  assert(Test.Name.nicknames[1] == 'nicknames[1]')
  assert(#Test.Name.aliases == 'aliases#')
  assert(Test.Name.aliases[1] == 'aliases[1]')
  assert(Test.Name.birthday == 'birthday')
  assert(#Test.Name.favorite == 'favorite#')
  assert(Test.Name.favorite[1] == 'favorite[1]')

  assert(Test.Color.YELLOW == 7)
  assert(Test.Color.GREEN == -9)
  assert(Test.Color.PINK == 3)

  local genLib = {} -- empty user-defined generator library
  local memoizeGen = true -- cache/dont-cache generators
  local nameGen = Gen.aggregateGen(Test.Name, genLib, memoizeGen)
  local name = nameGen:generate()

  print("first = ", name.first)
  print("last = ", name.last)
  print("#nicknames = ", #name.nicknames)
  print("nicknames[1] = ", name.nicknames[1])
  print("nicknames[2] = ", name.nicknames[2])
  print("nicknames[3] = ", name.nicknames[3])
  print("#aliases = ", #name.aliases)
  print("aliases[1] = ", name.aliases[1])
  print("birthday = ", name.birthday)
  print("#multidim = ", #name.multidim)
  for i, arr in ipairs(name.multidim) do
    if #arr==0 then  
      io.write("empty sequence") 
    end

    for j, val in ipairs(arr) do
      io.write(string.format("%d ", val))
    end
    print()
  end

  if name.favorite then 
    print("#favorite = ", #name.favorite) 
    print("favorite[1] = ", name.favorite[1])
    print("favorite[2] = ", name.favorite[2])
  else
    print("favorite = ", name.favorite)
  end

  print("#trajectory = ", #name.trajectory)
  for i, point in ipairs(name.trajectory) do
    print("point.x =", point.x, "point.y = ", point.y)
  end

  print("\nCached member generators: ")
  for k, v in pairs(genLib) do
    print(k, v)
  end
  
  print("\nCached type generators: ")
  for k, v in pairs(genLib.typeGenLib) do
    print(k, v)
  end
end

Tester[#Tester+1] = 'test_nested_struct_gen'
function Tester.test_nested_struct_gen()
    
  local Geometry = xtypes.module{
    Geometry = {
      xtypes.struct{
        Point = {
          { x = { xtypes.double } },
          { y = { xtypes.double } }
        }
      },
    }
  }

  Geometry[#Geometry+1] = 
    xtypes.struct {
      Test = {
        { point  = { Geometry[1]  } }, -- = Geometry.Point
        { x      = { xtypes.float } },
      }
    }
  
  Tester.print(Geometry)
 
  assert(Geometry.Test.x == 'x')
 
  local testGen = Gen.aggregateGen(Geometry.Test)
  local testObj = testGen:generate()
  print(testObj.point.x, testObj.point.y, testObj.x)

end

Tester[#Tester+1] = 'test_enum_gen'
function Tester.test_enum_gen()
  local Geometry = xtypes.module { Geometry = xtypes.EMPTY }
  
  Geometry[#Geometry+1] = xtypes.enum{ Days = {  
     'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN',
  }}

  Geometry[#Geometry+1] = 
    xtypes.struct {
      Test = {
        { s   = { xtypes.short  } },
        { d   = { xtypes.double } },
        { day = { Geometry[1]   } } -- = Geometry.Days
      }
    }
  
  Tester.print(Geometry)
 
  assert(Geometry.Test.s == 's')
  assert(Geometry.Days.MON == 0)
  assert(Geometry.Days.SUN == 6)
 
  local testGen = Gen.aggregateGen(Geometry.Test)
  local testObject = testGen:generate()

  print(testObject.s, testObject.d, testObject.day)

end

Tester[#Tester+1] = 'test_primitive_gen'
function Tester.test_primitive_gen() 
  numGen      = Gen.numGen()
  boolGen     = Gen.boolGen()
  charGen     = Gen.charGen()
  alphaNumGen = Gen.alphaNumGen()
  stringGen   = Gen.stringGen()

  math.randomseed(os.time())

  for i=1,5 do 
    print(numGen:generate()) 
    print(boolGen:generate()) 
    local c = alphaNumGen:generate();
    print(string.format("%d:'%c'", c, c))
    print(stringGen:generate()) 
    print()
  end
end

Tester[#Tester+1] = 'test_fibonacciGen'
function Tester.test_fibonacciGen()
  local fiboGen = Gen.fibonacciGen()
  print("Generating fibonacci numbers")
  for i=1,15 do 
    io.write(string.format("%d ", fiboGen:generate()))
  end
  print()
end

Tester[#Tester+1] = 'test_stepGen'
function Tester.test_stepGen()
  local gen = Gen.stepGen(-1,-10, -1, false)
  print("Generating number series")
  for i=1,20 do 
    io.write(string.format("%d ", gen:generate()))
  end
  print()
end

Tester[#Tester+1] = 'test_fromSequenceGen'
function Tester.test_fromSequenceGen()
  local array = { 10, 20, 30 }
  local gen = Gen.inOrderGen(array, false)
  print("Generating numbers from an array")
  for i=1,20 do 
    io.write(string.format("%d ", gen:generate()))
  end
  print()
end

--
-- print - helper method to print the IDL and the index for data definition
function Tester.print(instance)
    -- print IDL
    local idl = xutils.to_idl_string_table(instance, {'model (IDL):'})
    print(table.concat(idl, '\n\t'))
    
    -- print the result of visiting each field
    local fields = xutils.to_instance_string_table(instance, {'instance:'})
    print(table.concat(fields, '\n\t'))
end
---
-- main() - run the list of tests passed on the command line
--          if no command line arguments are passed in, run all the tests
function Tester:main()
  Gen.initialize()

  if #arg > 0 then -- run selected tests passed in from the command line
    for i, test in ipairs (arg) do
      if 'test_module' ~= test then -- skip, cuz already ran it
        print('\n--- ' .. test .. ' ---')
        self[test](self) -- run the test
      end
    end
  else -- run all  the tests
    for k, v in ipairs (self) do
      print('\n--- Test ' .. k .. ' : ' .. v .. ' ---')
      if self[v] then self[v](self) end 
    end
    print('\n All tests completed successfully!')
  end
end

Tester:main()
