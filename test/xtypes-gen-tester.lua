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
--[[
-------------------------------------------------------------------------------
Purpose: Unit-testing pull-based data generators
Created: Sumant Tambe, 2015 Jun 12
-------------------------------------------------------------------------------
--]]
package.path = '../src/?.lua;../src/?/init.lua;' .. package.path

local xtypes = require("ddsl.xtypes")
local xutils = require("ddsl.xtypes.utils")
local Gen    = require("ddslgen.generator")
local bit    = require("bit32")

local verbose = false 
local printv = nil

if tonumber(string.gmatch(_VERSION,"%d.%d")()) >= 5.3 then
  printv = function(...) if verbose then print(...) end end
else
  printv = function(...) 
    if verbose then
      local args = {...} 
      print(table.unpack(args)) 
    end
  end 
end

local Tester = {}

function print_table_recursive (t, topname)  
    local print_r_cache={}
    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(t)]) then
            print(indent.."*"..tostring(t))
        else
            print_r_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in pairs(t) do
                    if (type(val)=="table") then
                        print(indent.."["..pos.."] => "..tostring(t).." {")
                        sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
                        print(indent..string.rep(" ",string.len(pos)+6).."}")
                    elseif (type(val)=="string") then
                        print(indent.."["..pos..'] => "'..val..'"')
                    else
                        print(indent.."["..pos.."] => "..tostring(val))
                    end
                end
            else
                print(indent..tostring(t))
            end
        end
    end
    if (type(t)=="table") then
        print(topname .. " {")
        sub_print_r(t,"  ")
        print("}")
    else
        sub_print_r(t,"  ")
    end
    print()
end

Tester[#Tester+1] = 'test_coroutine'
function Tester:test_coroutine()
  local coro = coroutine.create(function ()
           for i=1,10 do
             if i % 2 == 0 then coroutine.yield(i) else coroutine.yield(nil) end
           end
           return 11
         end)
  
  local coGen = Gen.coroutineGen(coro)
  for i = 1, 13 do
    if i <= 10 then
      if i % 2 == 0 then 
        assert(coGen:generate() == i) 
      else 
        assert(coGen:generate() == nil)
      end
    elseif i == 11 then
      assert(coGen:generate() == 11)
    elseif i == 12 then
      assert(coGen:generate() == nil)
    elseif i == 13 then
      assert(coGen:generate() == nil)
    end
  end
end

Tester[#Tester+1] = 'test_const'
function Tester:test_const()
  local Test = {} 
  
  Test.FLOAT = xtypes.const{FLOAT = { xtypes.float, 3.14 } }
  Test.DOUBLE = xtypes.const{DOUBLE = { xtypes.double, 3.14 * 3.14 } } 
  Test.LDOUBLE = xtypes.const{LDOUBLE = { xtypes.long_double, 3.14 * 3.14 * 3.14 }}   
  Test.STRING = xtypes.const{STRING = { xtypes.string(), "String Constant" } }   
  Test.BOOL = xtypes.const{BOOL = { xtypes.boolean, true } }
  Test.CHAR = xtypes.const{CHAR = { xtypes.char, "String Constant" } } -- warning  
  Test.LONG = xtypes.const{LONG = { xtypes.long, 10.7 } } -- warning
  Test.LLONG = xtypes.const{LLONG = { xtypes.long_long, 10^10 } }
  Test.SHORT = xtypes.const{SHORT = { xtypes.short, 5 } }
  Test.WSTRING = xtypes.const{WSTRING = { xtypes.wstring(), "WString Constant" } }

  Tester.print(Test.FLOAT)
  Tester.print(Test.DOUBLE)
  Tester.print(Test.LDOUBLE)
  Tester.print(Test.STRING)
  Tester.print(Test.BOOL)
  Tester.print(Test.CHAR)
  Tester.print(Test.LONG)
  Tester.print(Test.LLONG)
  Tester.print(Test.SHORT)
  Tester.print(Test.WSTRING)
   
  local value, datatype 
  
  value, datatype = Test.FLOAT()
  assert(value == 3.14 and datatype == xtypes.float)
  assert(#Test.FLOAT == 0)
  
  assert(Test.DOUBLE() == 3.14 * 3.14)
  assert(Test.LDOUBLE() == 3.14 * 3.14 * 3.14)
  assert(Test.STRING() == "String Constant")
  assert(Test.BOOL() == true)
  assert(Test.CHAR() == 'S') -- warning printed
  assert(Test.LONG() == 10)  -- warning printed
  assert(Test.LLONG() == 10^10)  
  assert(Test.SHORT() == 5)  
  assert(Test.WSTRING() == "WString Constant")
  
  assert(Gen.createGenerator(Test.FLOAT):generate() == 3.14)
  assert(Gen.createGenerator(Test.DOUBLE):generate() == 3.14 * 3.14)
  assert(Gen.createGenerator(Test.LDOUBLE):generate() == 3.14 * 3.14 * 3.14)
  assert(Gen.createGenerator(Test.STRING):generate() == "String Constant")
  assert(Gen.createGenerator(Test.BOOL):generate() == true)
  assert(Gen.createGenerator(Test.FLOAT):generate() == 3.14)
  assert(Gen.createGenerator(Test.CHAR):generate() == 'S')
  assert(Gen.createGenerator(Test.LONG):generate() == 10)
  assert(Gen.createGenerator(Test.LLONG):generate() == 10^10)
  assert(Gen.createGenerator(Test.SHORT):generate() == 5)
  assert(Gen.createGenerator(Test.WSTRING):generate() == "WString Constant")
  
end

Tester[#Tester+1] = 'test_xml_advanced'
function Tester:test_xml_advanced()
  local xml = require('ddsl.xtypes.xml')
   
  local testfiles = {
    'xml-test-simple.xml',
    'xml-test-connector.xml',
    'xml-test-ddsc-types1.xml',
    'xml-test-union-enum.xml',
    '../tutorial/json.xml',
  }
  
  -- xml.log.verbosity(xml.log.TRACE)

  for _, file in ipairs(testfiles) do
  
    xml.empty() -- empty the root module, to prevent collisions between files
    
    if verbose then print('========= ', file, ' begin ======') end
    local ns = xml.file2xtypes(file)
    --Tester.print(ns)
    for i = 1, #ns do
      if ns[i][xtypes.KIND]() ~= "module" then
        local value = Gen.createGenerator(ns[i]):generate()
        assert(value ~= nil)
        if verbose then print_table_recursive(value, ns[i][xtypes.NAME]) end
      end
    end
    if verbose then print('--------- ', file, ' end --------') end
    
  end
end


Tester[#Tester+1] = 'test_union_gen'
function Tester:test_union_gen()

  local Point = xtypes.struct{
    Point = {
      { x = { xtypes.long } },
      { y = { xtypes.long } }
    }
  }

  local MyDouble = xtypes.typedef{MyDouble = { xtypes.long_double} }  
  
  local TestUnion = xtypes.union{
    TestUnion = {xtypes.long,
      { 3,   
        x = { xtypes.string() } },
      { 2, 4, 5,   
        y = { MyDouble } },
      { xtypes.EMPTY, 
        z = { xtypes.boolean } }, -- default
      { 6, 
        point = { Point } }
    }
  }
  
  Tester.print(TestUnion)
  
  assert(TestUnion._d == '#')
  assert(TestUnion.x == 'x')
  assert(TestUnion.y == 'y')
  assert(TestUnion.z == 'z')
  assert(TestUnion.point.x == 'point.x')
  assert(TestUnion.point.y == 'point.y')
 
  local memoize = false
  local lib = {}
  local unionGen = Gen.aggregateGen(TestUnion, lib, memoize)
  local union = unionGen:generate()

  if union._d == 3 then
    assert(type(union.x) == "string")
    assert(union.y == nil)
    assert(union.z == nil)
    assert(union.point == nil)
  elseif union._d == 2 or union._d == 4 or union._d == 5 then
    assert(type(union.y) == "number")
    assert(union.x == nil)
    assert(union.z == nil)
    assert(union.point == nil)
  elseif union._d == 6 then
    assert(type(union.point.x) == "number")
    assert(type(union.point.y) == "number")
    assert(union.x == nil)
    assert(union.y == nil)
    assert(union.z == nil)
  elseif union._d == xtypes.EMPTY then
    assert(type(union.z) == "boolean")
    assert(union.x == nil)
    assert(union.y == nil)
    assert(union.point == nil)
  else
    error "Unknown value of discriminator"
  end

end

Tester[#Tester+1] = 'test_union_enum_gen'
function Tester:test_union_enum_gen()

  local Test = { }

  Test.Days = xtypes.enum{Days = {  
      'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN',
  }}
  
  Test.Name =  xtypes.struct{ 
    Name = {
      { first = { xtypes.string(20)  } },
      { second = { xtypes.string(20) } }
    }
  }
  
  Test.Address = xtypes.struct{ 
    Address = {
      { first = { xtypes.string(20)  } },
      { second = { xtypes.string(20) } }
    }
  }
  
  -- discriminator could be a typedef:
  Test.MyDays = xtypes.typedef{MyDays = { Test.Days} }
  
  Test.TestUnion3 = xtypes.union{
    TestUnion3 = {Test.MyDays,
      { Test.Days.MON,
        name = { Test.Name } },
      { Test.Days.TUE, 
        Test.Days.WED,
        address = { Test.Address } },
      { xtypes.EMPTY, -- default
         x = { xtypes.double } },    
      xtypes.Extensibility{'EXTENSIBLE_EXTENSIBILITY',domain=5},
    }
  }
  Tester.print(Test.TestUnion3)

  -- discriminator
  assert(Test.TestUnion3._d == '#')
  
  -- name
  assert(Test.TestUnion3.name.first == 'name.first')

  -- address
  assert(Test.TestUnion3.address.first == 'address.first')

  -- x
  assert(Test.TestUnion3.x == 'x')
  
  -- annotation
  assert(Test.TestUnion3[xtypes.QUALIFIERS][1] ~= nil)
 
  local memoize = false
  local lib = {}
  local unionGen = Gen.aggregateGen(Test.TestUnion3, lib, memoize)
  local union = unionGen:generate()

  if union._d == Test.Days.MON then
    assert(type(union.name.first) == "string")
    assert(type(union.name.second) == "string")
    assert(union.address == nil)
    assert(union.x == nil)
    --print(union.name.first .. " " .. union.name.second)
  elseif union._d == Test.Days.TUE or union._d == Test.Days.WED then
    assert(type(union.address.first) == "string")
    assert(type(union.address.second) == "string")
    assert(union.name == nil)
    assert(union.x == nil)
    --print(union.address.first .. " " .. union.address.second)
  elseif union._d == xtypes.EMPTY then
    assert(type(union.x) == "number")
    assert(union.name == nil)
    assert(union.address == nil)
    --print(union.x)
  else
    error "Unknown value of discriminator"
  end

end

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
  local xMin, xMax, yMin, yMax, sMin, sMax  = 0, 200, 0, 200, 20, 30

  shapeGenLib.x         = Gen.rangeGen(xMin, xMax)
  shapeGenLib.y         = Gen.rangeGen(yMin, yMax)
  shapeGenLib.color     = Gen.oneOfGen({ "RED", "GREEN", "BLUE" })
  shapeGenLib.shapesize = Gen.rangeGen(sMin, sMax)

  local memoize = false 
  local ShapeTypeGen = Gen.aggregateGen(ShapeType, shapeGenLib, memoize)
  local shape = ShapeTypeGen:generate()

  assert(shape.x >= xMin and shape.x <= xMax)
  assert(shape.y >= yMin and shape.y <= yMax)
  assert(shape.color == "RED" or shape.color == "GREEN" or shape.color == "BLUE")
  assert(shape.shapesize >= sMin and shape.shapesize <= sMax)

  printv("shape.x = " .. shape.x)
  printv("shape.y = " .. shape.y)
  printv("shape.color = " .. shape.color)
  printv("shape.shapesize = " .. shape.shapesize)

  return ShapeTypeGen
end

Tester[#Tester+1] = 'test_seq_gen'
function Tester.test_seq_gen()
  local length = 5
  local seqGen = Gen.seqGen(Gen.Float, length)
  local seq = seqGen:generate()

  assert(#seq <= length and #seq >= 0)

  for k, v in ipairs(seq) do
    assert(type(v) == "number")
    printv(k, v)
  end
end

Tester[#Tester+1] = 'test_aggregateseq_gen'
function Tester.test_aggregateseq_gen()
  local ShapeTypeGen = Tester.test_struct_gen()
  printv()

  local length = 3
  local seqGen = Gen.seqGen(ShapeTypeGen, length)
  local seq = seqGen:generate()
  
  assert(#seq <= length and #seq >= 0)

  for k, shape in ipairs(seq) do
    assert(shape.x) 
    assert(shape.y) 
    assert(shape.color)
    assert(shape.shapesize)
    for member, value in pairs(shape) do
      if member == "x" or member == "y" or member == "shapesize" then
        assert(type(value) == "number")
      else
        assert(type(value) == "string")
      end
      printv(member, value)
    end
    printv()
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

  assert(type(point.x) == "number")
  assert(type(point.y) == "number")
  assert(type(point.z) == "number")

  printv(point.x, point.y, point.z)

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

  assert(type(name.first) == "string" and #name.first <= 10) 
  printv("first = ", name.first)
  assert(type(name.last) == "string" and #name.last <= 128) 
  printv("last = ", name.last)
  assert(type(name.nicknames) == "table" and #name.nicknames <= 3) 
  printv("#nicknames = ", #name.nicknames)
  for i=1, #name.nicknames do
    if name.nicknames[i] then
      assert(type(name.nicknames[i]) == "string")
      assert(#name.nicknames[i] <= 40)
      printv(string.format("name.nicknames[%d] = %s", i, name.nicknames[i]))
    end
  end
  assert(type(name.aliases) == "table" and #name.aliases <= 256) 
  printv("#aliases = ", #name.aliases)
  for i=1, #name.aliases do
    if name.aliases[i] then
      assert(type(name.aliases[i]) == "string")
      assert(#name.aliases[i] <= 256)
      printv(string.format("name.aliases[%d] = %s", i, name.aliases[i]))
    end
  end
  if name.birthday then
    assert(type(name.birthday) == "number")
  end
  printv("birthday = ", name.birthday)
  assert(type(name.multidim) == "table")
  printv("#multidim = ", #name.multidim)
  for i=1, #name.multidim do
    for j=1, #name.multidim[i] do
      assert(type(name.multidim[i][j]=="number"))
    end
  end
  for i, arr in ipairs(name.multidim) do
    if #arr==0 then  
      printv("empty sequence")
    end

    for j, val in ipairs(arr) do
      printv(string.format("%d ", val))
    end
    printv()
  end

  if name.favorite then 
    assert(type(name.favorite) == "table")
    printv("#name.favorite = ", #name.favorite)
    for i=1, #name.favorite do
      assert(type(name.favorite[i]) == "number")
      printv(string.format("name.favorite[%d] = %s", i, 
                  Test.Color(name.favorite[i])))
    end
  else
    printv("name.favorite = ", Test.Color(name.favorite))
  end

  printv("#trajectory = ", #name.trajectory)
  for i, point in ipairs(name.trajectory) do
    assert(type(name.trajectory[i]) == "table")
    assert(type(name.trajectory[i].x) == "number")
    assert(type(name.trajectory[i].y) == "number")
    printv("point.x =", point.x, "point.y = ", point.y)
  end

  printv("\nCached member generators: ")
  for k, v in pairs(genLib) do
    printv(k, v)
  end
  
  printv("\nCached type generators: ")
  for k, v in pairs(genLib.typeGenLib) do
    printv(k, v)
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
        { point  = { Geometry.Point  } },
        { x      = { xtypes.float } },
      }
    }
  
  Tester.print(Geometry)
 
  assert(Geometry.Test.x == 'x')
 
  local testGen = Gen.aggregateGen(Geometry.Test)
  local testObj = testGen:generate()
  assert(type(testObj.point.x) == "number")
  assert(type(testObj.point.y) == "number")
  assert(type(testObj.x) == "number")
  printv(testObj.point.x, testObj.point.y, testObj.x)

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
        { day = { Geometry.Days   } }
      }
    }
  
  Tester.print(Geometry)
 
  assert(Geometry.Test.s == 's')
  assert(Geometry.Days.MON == 0)
  assert(Geometry.Days.SUN == 6)
 
  local testGen = Gen.aggregateGen(Geometry.Test)
  local testObject = testGen:generate()

  assert(type(testObject.s) == "number")
  assert(type(testObject.d) == "number")
  assert(type(testObject.day) == "number")
  printv(testObject.s, testObject.d, Geometry.Days(testObject.day))

end

Tester[#Tester+1] = 'test_array_gen'
function Tester:test_array_gen()

  local Test = {}

  Test.Days = xtypes.enum{Days = {  
      'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN',
  }}
  

  Test.MyStruct = xtypes.struct{
    MyStruct = {
      -- 1-D
      { doubles = { xtypes.double, xtypes.array(3) } },
    
      -- 2-D
      { days = { Test.Days, xtypes.array(6, 9) } },
      
    }
  }
  -- structure with arrays
  self.print(Test.MyStruct)
  
  -- ints
  assert(#Test.MyStruct.doubles== 'doubles#')
  assert(Test.MyStruct.doubles[1] == 'doubles[1]')
  
  -- days
  assert(#Test.MyStruct.days == 'days#')
  assert(#Test.MyStruct.days[1] == 'days[1]#')
  assert(Test.MyStruct.days[1][1] == 'days[1][1]')
  
  local MyStructGen = Gen.aggregateGen(Test.MyStruct)
  local myStruct = MyStructGen:generate()

  assert(#myStruct.doubles == 3)
  for i=1, #myStruct.doubles do
    assert(type(myStruct.doubles[i]) == "number")
    if verbose then io.write(string.format(myStruct.doubles[i] .. " ")) end 
  end
  printv()
  assert(#myStruct.days == 9)
  for i=1, #myStruct.days do
    for j=1, #myStruct.days[i] do
      assert(type(myStruct.days[i][j]) == "number")
      if verbose then 
        io.write(string.format(Test.Days(myStruct.days[i][j]) .. " ")) 
      end
    end
    printv()
  end
end

Tester[#Tester+1] = 'test_typedef_gen'
function Tester.test_typedef_gen() 

  local Test = {}

  Test.Name = xtypes.struct{
    Name = {
      { first     = { xtypes.string(10),   xtypes.Key         } },
      { last      = { xtypes.wstring(128)                     } },
      { nicknames = { xtypes.string(40),   xtypes.sequence(3) } },
      { birthday  = { xtypes.long,         xtypes.Optional    } },
    }
  }

  -- typedefs
  Test.MyDouble = xtypes.typedef{MyDouble = { xtypes.double} }
  Test.MyDouble2 = xtypes.typedef{MyDouble2 = { Test.MyDouble } }
  Test.MyString = xtypes.typedef{MyString = { xtypes.string(10) } }
  
  Test.MyName  = xtypes.typedef{MyName = { Test.Name } }
  Test.MyName2 = xtypes.typedef{MyName2 = { Test.MyName} }
  Test.Vector  = xtypes.typedef{ Vector = { xtypes.long, xtypes.sequence(4) } }
  Test.Matrix  = xtypes.typedef{ Matrix = { Test.Vector, xtypes.array(5) } }
  
  Test.MyTypedef = xtypes.struct{
    MyTypedef = {
      { rawDouble =  { xtypes.double } },
      { myDouble =  { Test.MyDouble } },
      { myDouble2 =  { Test.MyDouble2 } },
      { myDoubleSeq = { Test.MyDouble2, xtypes.array(3) } },
      
      { name =  { Test.Name } },
      { myName =  { Test.MyName } },
      { myName2 =  { Test.MyName2 } },
      
      { vector = { Test.Vector } },
      { matrix = { Test.Matrix } }
    }
  }
  Tester.print(Test.MyDouble)
  Tester.print(Test.MyDouble2)  
  Tester.print(Test.MyString)
        
  Tester.print(Test.MyName)
  Tester.print(Test.MyName2)
  
  Tester.print(Test.MyTypedef)
  
  -- rawDouble
  assert(Test.MyTypedef.rawDouble == 'rawDouble')
  assert(Test.MyTypedef.myDouble == 'myDouble')
  assert(Test.MyTypedef.myDouble2 == 'myDouble2')
  -- name
  assert(Test.MyTypedef.name.first == 'name.first')
  assert(#Test.MyTypedef.name.nicknames == 'name.nicknames#')  
  assert(Test.MyTypedef.name.nicknames[1] == 'name.nicknames[1]')
  
  -- myName
  assert(Test.MyTypedef.myName.first == 'myName.first')
  assert(#Test.MyTypedef.myName.nicknames == 'myName.nicknames#')  
  assert(Test.MyTypedef.myName.nicknames[1] == 'myName.nicknames[1]')

  local doubleGen = Gen.typedefGen(Test.MyDouble2)
  local value = doubleGen:generate()
  assert(type(value) == "number")

  local vectorGen = Gen.typedefGen(Test.Vector)
  local vector = vectorGen:generate()
  for idx = 1, #vector do
    assert(type(vector[idx]) == "number")
  end

  local matrixGen = Gen.typedefGen(Test.Matrix)
  local matrix = matrixGen:generate()
  for i = 1, #matrix do
    local row = matrix[i]
    for j = 1, #row do
      assert(type(row[j]) == "number")
    end
  end

  local structgen = Gen.aggregateGen(Test.MyTypedef)
  local struct = structgen:generate()
  assert(type(struct.rawDouble) == "number")
  assert(type(struct.myDouble) == "number")
  assert(type(struct.myDouble2) == "number")

  for idx = 1, #struct.myDoubleSeq do 
    assert(type(struct.myDoubleSeq[idx]) == "number")
  end
  
  assert(type(struct.name.last) == "string")
  for idx = 1, #struct.name.nicknames do 
    assert(type(struct.name.nicknames[idx]) == "string")
  end
  assert(type(struct.name.birthday) == "number")
 
  assert(type(struct.myName.last) == "string")
  for idx = 1, #struct.myName.nicknames do 
    assert(type(struct.myName.nicknames[idx]) == "string")
  end
  assert(type(struct.myName.birthday) == "number")
 
  assert(type(struct.myName2.last) == "string")
  for idx = 1, #struct.myName2.nicknames do 
    assert(type(struct.myName2.nicknames[idx]) == "string")
  end
  assert(type(struct.myName2.birthday) == "number")

  for idx = 1, #struct.vector do 
    assert(type(struct.vector[idx]) == "number")
  end
  
  for i = 1, #struct.matrix do
    local row = struct.matrix[i]
    for j = 1, #row do
      assert(type(row[j]) == "number")
    end
  end

end

Tester[#Tester+1] = 'test_day_gen'
function Tester.test_day_gen() 
    local dayOfWeek = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
    local xGen    = Gen.rangeGen(1,7)
    local dayGen = xGen:map(function(i) 
                              return dayOfWeek[i]
                            end)
    for i=1, 5 do 
      local x = xGen:generate()
      local day = dayGen:generate()
      assert(x >= 1 and x <= 7)
      printv("xGen produced ", x)
      printv("dayGen produced ", day)
    end
end

Tester[#Tester+1] = 'test_primitive_gen'
function Tester.test_primitive_gen() 
  numGen        = Gen.numGen()
  floatGen      = Gen.floatGen()
  doubleGen     = Gen.doubleGen()
  longDoubleGen = Gen.longDoubleGen()
  boolGen       = Gen.boolGen()
  charGen       = Gen.charGen()
  alphaNumGen   = Gen.alphaNumGen()
  stringGen     = Gen.stringGen()

  math.randomseed(os.time())

  for i=1,5 do 
    local num = numGen:generate() 
    local float = floatGen:generate() 
    local double = doubleGen:generate() 
    local ldouble = longDoubleGen:generate() 
    local bool = boolGen:generate() 
    local c = alphaNumGen:generate();
    local str = stringGen:generate() 

    assert(type(num) == "number")
    assert(type(float) == "number")
    assert(type(double) == "number")
    assert(type(ldouble) == "number")
    assert(type(bool) == "boolean")
    assert(type(c) == "number")
    assert(type(str) == "string")

    printv(num) 
    printv(float) 
    printv(double) 
    printv(ldouble) 
    printv(bool) 
    printv(string.format("%d:'%c'", c, c))
    printv(str) 
    printv()
  end
end

Tester[#Tester+1] = 'test_fibonacciGen'
function Tester.test_fibonacciGen()
  local answer = { 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377 } 
  local fiboGen = Gen.fibonacciGen()
  printv("Generating fibonacci numbers")
  for i=1,15 do 
    local value = fiboGen:generate()
    assert(value == answer[i])
    if verbose then io.write(string.format("%d ", value)) end
  end
  printv()
end

Tester[#Tester+1] = 'test_stepGen'
function Tester.test_stepGen()
  local answer = { -1, -2, -3, -4, -5, -6, -7, -8, -9, -10 } 
  local gen = Gen.stepperGen(-1,-10, -1, false)
  printv("Generating number series")
  for i=1,20 do 
    local val, valid = gen:generate()
    if valid then
      assert(answer[i] == val)
      if versbose then io.write(string.format("%d ", val)) end
    end
  end
  printv()
end

Tester[#Tester+1] = 'test_inOrderGen'
function Tester.test_inOrderGen()
  local array = { 10, 20, 30, 40 }
  local gen = Gen.inOrderGen(array, true)
  printv("Generating numbers from an array")
  for i=1, 5 * #array do 
    local val, valid = gen:generate()
    if valid then
      local idx = i % #array
      if idx == 0 then idx = #array end 
      assert(val == array[idx])
      if verbose then io.write(string.format("%d ", val)) end
    end
  end
  printv()
end

function Set (list)
  local set = {}
  for _, l in ipairs(list) do set[l] = true end
  return set
end

Tester[#Tester+1] = 'test_months'
function Tester.test_months()
 local array = { "Jan", "Feb", "Mar",  "Apr", "May", "Jun", 
                 "Jul", "Aug", "Sept", "Oct", "Nov", "Dec" }
 local set = Set(array)
 local monthGen = Gen.oneOfGen(array)
 local yearGen = Gen.stepperGen(1900, 1912)
 local seriesGen = yearGen:zipMany(monthGen, 
                                   function(year, month) 
                                     return { year = year, month = month }
                                   end)
                           
 for i=1, 12 do 
   local val, valid = seriesGen:generate()
   if valid then
     assert(val.year == 1899 + i)
     assert(set[val.month])
     printv(val.year, val.month)
   end
  end
end

Tester[#Tester+1] = 'test_flatMap'
function Tester.test_flatMap()
  local days = { "Sun", "Mon", "Tue",  "Wed", "Thu", "Fri", "Sat" }
  local incrGen = Gen.stepperGen(1, 7)
                     :flatMap(function (i) 
                                return Gen.inOrderGen(days):take(i)
                              end)
       
  local output, val, valid = {}, nil, true

  while valid do 
    val, valid = incrGen:generate()
    if valid then
      output[#output+1] = val
    end
  end

  local answer = { "Sun", 
                   "Sun", "Mon",
                   "Sun", "Mon", "Tue",
                   "Sun", "Mon", "Tue", "Wed",
                   "Sun", "Mon", "Tue", "Wed", "Thu",
                   "Sun", "Mon", "Tue", "Wed", "Thu", "Fri",
                   "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }

  for i=1, #answer do
    assert(output[i] == answer[i])
    i = i + 1
  end

end

Tester[#Tester+1] = 'test_scan'
function Tester.test_scan()
  
  local answer = { 1, 3, 6, 10, 15, 21, 28, 36, 45, 55 }

  local gen = Gen.stepperGen(1, 10)
                 :scan(function (sum, value) return sum + value end, 0)
  
  for i=1, #answer do
    assert(answer[i] == gen:generate())
  end
  
end

Tester[#Tester+1] = 'test_take'
function Tester.test_take()
  
  local answer = { 1, 2, 3, 4, 5 }

  local gen = Gen.stepperGen(1, 10)
                 :take(5)
  
  for i=1, #answer do
    assert(answer[i] == gen:generate())
  end
  
  assert(nil == Gen.stepperGen(1, 10):take(0):generate())
  
end

Tester[#Tester+1] = 'test_skip'
function Tester.test_skip()
  
  local answer = { 1, 2, 3, 4, 5 }
  local skip = 2
  local gen = Gen.stepperGen(1, 5)
                 :skip(skip)
  
  for i=1+skip, #answer do
    assert(answer[i] == gen:generate())
  end
  
  local gen = Gen.stepperGen(1, 5)
                 :skip(0)
  
  for i=1, #answer do
    assert(answer[i] == gen:generate())
  end
  
end

Tester[#Tester+1] = 'test_last'
function Tester.test_last()
  
  local answer = { 10, 20, 30, 40, 50 }
  local last = 3
  local gen = Gen.stepperGen(10, 50, 10)
                 :last(last)
  
  for i=#answer-last+1, #answer do
    local val = gen:generate()
    assert(answer[i] == val)
  end
 
 
  local last = 7
  local gen = Gen.stepperGen(10, 50, 10)
                 :last(last)
  
  for i=1, #answer do
    local val = gen:generate()
    assert(answer[i] == val)
  end

  assert(nil == gen:generate())
  assert(nil == gen:generate())
  
end

Tester[#Tester+1] = 'test_reduce'
function Tester.test_reduce()
  
  local gen = Gen.stepperGen(1, 5)
                 :reduce(function (sum, i) return sum+i end, 0)
  
  assert(gen:generate() == 15)

  local gen  = Gen.stepperGen(1, 5)
                  :reduce(function (sum, i) return sum+i end, 0)
  local gen2 = Gen.stepperGen(1, 5)
                  :scan(function (sum, i) return sum+i end, 0)
                  :last()
                  
  assert(gen:generate() == gen2:generate())
  assert(Gen.emptyGen():reduce():generate() == 
         Gen:emptyGen():scan():last():generate())
    
end


Tester[#Tester+1] = 'test_concat'
function Tester.test_concat()
  
  local answer = { 1, 3, 6, 10, 15, 21, 28, 36, 45, 55 }

  local seg1 = Gen.inOrderGen({ 1, 3, 6, 10 })
  local seg2 = Gen.inOrderGen({ 15, 21, 28, 36, 45, 55 })
  local gen = seg1:concat(seg2)
  
  for i=1, #answer do
    assert(answer[i] == gen:generate())
  end
  
  local seg2 = Gen.inOrderGen(answer)
  local gen = Gen.emptyGen():concat(seg2)
  
  for i=1, #answer do
    assert(answer[i] == gen:generate())
  end
  
  local seg1 = Gen.inOrderGen(answer)
  local gen = seg1:concat(Gen.emptyGen())
  
  for i=1, #answer do
    assert(answer[i] == gen:generate())
  end
  
end

Tester[#Tester+1] = 'test_concatAll'
function Tester.test_concatAll()
  
  local answer = { 1, 3, 6, 10, 15, 21, 28, 36, 45, 55 }

  local seg1 = Gen.inOrderGen({ 1, 3, 6 })
  local seg2 = Gen.inOrderGen({ 10, 15, 21 })
  local seg3 = Gen.inOrderGen({ 28, 36, 45 })
  local seg4 = Gen.inOrderGen({ 55 })
  local gen = Gen.concatAllGen(seg1, seg2, seg3, seg4)
  
  for i=1, #answer+1 do
    assert(answer[i] == gen:generate())
  end
 
  assert(nil == Gen.concatAllGen(Gen.emptyGen(), Gen.emptyGen()):generate())
  
end

function inorder(node)
  -- Function inspired by http://okmij.org/ftp/continuations/generators.html

  if node then
    return Gen.concatAllGen(Gen.deferredGen(function() return inorder(node.left) end), 
                            Gen.singleGen(node.data), 
                            Gen.deferredGen(function() return inorder(node.right) end))
  end
  return Gen.emptyGen()
end

Tester[#Tester+1] = 'test_inorderTraversal'
function Tester.test_inorderTraversal()
  -- Test inspired by http://okmij.org/ftp/continuations/generators.html
  
  local answer = { 3, 5, 6, 8, 10, 17, 21 }
  local root = { data  = 10, 
                 left  = { data  = 6, 
                           left  = { data = 3, right = { data = 5 } },
                           right = { data = 8 } 
                         },
                 right = { data  = 21, 
                           left = { data = 17 },
                         } 
               }
  
  local gen = inorder(root)
  
  for i=1, #answer+1 do
    assert(answer[i] == gen:generate())
  end
 
end

Tester[#Tester+1] = 'test_alternateGen'
function Tester.test_alternateGen()
  
  local answer = { 1, 10, 28, 55, 3, 15, 36, 6, 21, 45, nil }

  local seg1 = Gen.inOrderGen({  1,  3,  6 })
  local seg2 = Gen.inOrderGen({ 10, 15, 21 })
  local seg3 = Gen.inOrderGen({ 28, 36, 45 })
  local seg4 = Gen.inOrderGen({ 55 })
  local gen = Gen.alternateGen(seg1, seg2, seg3, seg4)
  
  for i=1, #answer+1 do
    assert(answer[i] == gen:generate())
  end
 
  assert(nil == Gen.alternateGen(Gen.emptyGen()):generate())
 
end

Tester[#Tester+1] = 'test_toTable'
function Tester.test_toTable()
  
  local answer = { 1, 10, 28, 55, 3, 15, 36, 6, 21, 45, nil }
  local gen = Gen.inOrderGen(answer)
  local all = gen:toTable();
  
  for i=1, #answer do
    assert(answer[i] == all[i])
  end
 
  assert(nil == Gen.alternateGen(Gen.emptyGen()):generate())
 
end

Tester[#Tester+1] = 'test_where_reject_find_every'
function Tester.test_where_reject_find_every()
  
  local data = { 1, 10, 28, 55, 3, 15, 36, 6, 21, 45 }
  local even = { 10, 28, 36, 6, }
  local odd  = { 1, 55, 3, 15, 21, 45 }
  
  local evenGen = Gen.inOrderGen(data)
                     :where(function (i) return i % 2 == 0 end)
  
  local oddGen = Gen.inOrderGen(data)
                    :reject(function (i) return i % 2 == 0 end)
  
  for i=1, #even do
    assert(even[i] == evenGen:generate())
  end
 
  for i=1, #odd do
    assert(odd[i] == oddGen:generate())
  end

  assert(Gen.find(Gen.inOrderGen(data),
                  function (i) return i == 15 end) == 15)
  
  assert(Gen.find(Gen.inOrderGen(data),
                  function (i) return i == -777 end) == nil)
  
  assert(Gen.every(Gen.inOrderGen(data),
                   function (i) return i < 100 end))
  
  assert(Gen.every(Gen.inOrderGen(data),
                   function (i) return i < 55 end) == false)
  
end

Tester[#Tester+1] = 'test_sort'
function Tester.test_sort()
  
  local data   = { 1, 10, 28, 55,  3, 15, 36,  6, 21, 45 }
  local answer = { 1,  3,  6, 10, 15, 21, 28, 36, 45, 55 }
  local sorted = Gen.sort(Gen.inOrderGen(data), 
                          function (i,j) return i < j end)
  
  for i = 1, #answer do
    assert(answer[i] == sorted[i])
  end

  local data   = { { name = "Z" },
                   { name = "M" },
                   { name = "P" },
                   { name = "A" } }
  
  local answer = { { name = "A" },
                   { name = "M" },
                   { name = "P" },
                   { name = "Z" } }
  
  local sorted = Gen.sortBy(Gen.inOrderGen(data), "name")
  
  for i = 1, #answer do
    assert(answer[i].name == sorted[i].name)
  end
  
end


Tester[#Tester+1] = 'test_groupby1'
function Tester.test_groupby1()
  
  local data   = { 1,2,3,4,5,6,7,8,9,10 }
  local gop = Gen.inOrderGen(data)
                 :groupBy(function (x) return x % 2 end)
                   
  local g1 = gop:generate()
  local g2 = gop:generate()
  local g3 = gop:generate()

  assert(gop.kind() == "pull")  

  assert(g1 ~= nil) 
  assert(g1.kind() == "pull")
  assert(g1.getKey() == 1)

  assert(g2 ~= nil)
  assert(g2.kind() == "pull")
  assert(g2.getKey() == 0)

  assert(g3 == nil)
  
  for i = 1, #data/2 do
    local value = g1:generate()
    assert((value % 2) == 1) 
  end 
  
  for i = 1, #data/2 do
    local value = g2:generate()
    assert((value % 2) == 0) 
  end 
  
  assert(g1:generate() == nil)
  assert(g2:generate() == nil)
end

Tester[#Tester+1] = 'test_groupby2'
function Tester.test_groupby2()
  
  local data   = { 1,2,3,4,5,6,7,8,9,10 }
  local gop = Gen.inOrderGen(data)
                 :groupBy(function (x) return x % 2 end)
  assert(gop.kind() == "pull")
  
  local g1 = gop:generate()
  assert(g1 ~= nil)
  assert(g1.kind() == "pull")
  assert(g1.getKey() == 1)
  
  for i = 1, #data/2 do
    local value = g1:generate()
    assert((value % 2) == 1) 
  end 

  assert(g1:generate() == nil)

  local g2 = gop:generate()
  assert(g2 ~= nil)
  assert(g2.kind() == "pull")
  assert(g2.getKey() == 0)  
  
  for i = 1, #data/2 do
    local value = g2:generate()
    assert((value % 2) == 0) 
  end 
 
  assert(g2:generate() == nil)
  
  local g3 = gop:generate()
  assert(g3 == nil)
end

Tester[#Tester+1] = 'test_groupby_infinite'
function Tester.test_groupby_infinite()
  local groups = Gen.rangeGen(1, 20000):generate()
  local gop = Gen.stepperGen() -- infinite
                 :groupBy(function (x) return x % groups end)
  local innerGenArr = {}
  local innerGenLastValue = {}
  
  for j = 1, groups do
    innerGenArr[j] = gop:generate()
    innerGenLastValue[j] = 0
  end
  
  local rangeGen = Gen.rangeGen(1, groups)
  for i = 1, 1000*1000 do
    local j = rangeGen:generate()  
    local val = innerGenArr[j]:generate()
    assert(val > innerGenLastValue[j])
    innerGenLastValue[j] = val
  end
end

Tester[#Tester+1] = 'test_groupby_inf_alternate'
function Tester.test_groupby_inf_alternate()
  local groups = Gen.rangeGen(1, 20000):generate()
  
  local allInnerGenTab = 
      Gen.stepperGen() -- infinite
         :groupBy(function (x) return x % groups end)
         :take(groups)
         :toTable()

  local j = 1
  local altGen = Gen.alternateGen(table.unpack(allInnerGenTab))
  for i = 1, 1000*1000 do  
    local val = altGen:generate()
    assert((val % groups) == j) 
    j = (j + 1) % groups
  end
end

Tester[#Tester+1] = 'test_groupby_inf_sequence_limited'
function Tester.test_groupby_inf_sequence_limited()
  local groups = Gen.rangeGen(1, 20000):generate()
  local limit = Gen.rangeGen(1, 200):generate()

  printv("Testing with " .. groups .. 
         " groups of " .. limit .. " size each.")

  local dataGen = 
      Gen.stepperGen() -- infinite
         :groupBy(function (x) return x % groups end)
         :map(function(grp) return grp:take(limit) end)
         :flatMap()
         :take(groups * limit)

  local mod = 1
  for i = 1, groups do  
    for j = 1, limit do
      local val = dataGen:generate()
      assert((val % groups) == mod) 
    end
    mod = (mod + 1) % groups
  end

  assert(dataGen:generate() == nil)
end

Tester[#Tester+1] = 'test_foreach'
function Tester.test_foreach()
  
  local sum = 0
  local data   = { 1, 10, 28, 55,  3, 15, 36,  6, 21, 45 }
  Gen.foreach(Gen.inOrderGen(data), function (i) sum = sum + i end)  
  
  local total = 
    Gen.inOrderGen(data):reduce(function (init, i) return init + i end, 0):generate()
  
  assert(sum == total)

end

Tester[#Tester+1] = 'test_typeGenLib'
function Tester.test_typeGenLib()
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

  local shapeGenLib = { typeGenLib = {} }
  local min, max = 0, 200

  shapeGenLib.typeGenLib.long = Gen.rangeGen(min, max)
  shapeGenLib.color           = Gen.oneOfGen({ "RED", "GREEN", "BLUE" })

  local ShapeTypeGen = Gen.aggregateGen(ShapeType, shapeGenLib)
  local shape = ShapeTypeGen:generate()

  assert(shape.x >= min and shape.x <= max)
  assert(shape.y >= min and shape.y <= max)
  assert(shape.color == "RED" or shape.color == "GREEN" or shape.color == "BLUE")
  assert(shape.shapesize >= min and shape.shapesize <= max)

  printv("shape.x = " .. shape.x)
  printv("shape.y = " .. shape.y)
  printv("shape.color = " .. shape.color)
  printv("shape.shapesize = " .. shape.shapesize)

  return ShapeTypeGen
end

function Tester.makePowerSetGen(src)
  return Gen.stepperGen(0, math.pow(2, #src)-1)
            :map(function(n)
                  local set = {}
                  local i = 1
                  while n > 0 do
                    if bit.band(n, 1) > 0 then
                      set[#set+1] = src[i]
                    end
                    i = i + 1;
                    n = bit.rshift(n, 1)
                  end
                  
                  return set
                 end)
end

function head(tab)
  return tab[1]
end

function tail(tab)
  return { table.unpack(tab, 2, #tab) }
end

function Tester.makePowerSetGenRecursive(src)
-- This implemenation is inspired by the following Haskell implemenation
-- powerset :: [a] -> [[a]]
-- powerset [] = [[]]
-- powerset (x:xs) = xss ++ map (x:) xss
--                   where xss = powerset xs

  if #src == 0 then
    return Gen.singleGen({}) 
  end
  
  return Gen.concatAllGen(
            Tester.makePowerSetGenRecursive(tail(src)),
            Tester.makePowerSetGenRecursive(tail(src))
                  :map(function(s)
                         s[#s+1] = head(src)
                         return s
                       end))
end

Tester[#Tester+1] = 'test_powerset'
function Tester.test_powerset()
  local src = { "Generators", "are", "kind", "of", "awesome" }
  local powerSetSize = math.pow(2, #src)
  
  local powersetGen = {}
  powersetGen[1] = Tester.makePowerSetGen(src)
  powersetGen[2] = Tester.makePowerSetGenRecursive(src)
  
  local data, valid = nil, true
  local i = 0

  for g = 1, #powersetGen do
    while valid do
      data, valid = powersetGen[g]:generate()

      if valid then i = i + 1 end

      if valid and verbose then 
        print_table_recursive(data, "A powerset member") 
      end
    end
 
    assert(i == powerSetSize)
  end
end

function math.fact(n)
  if n == 0 then
    return 1
  else
    return n * math.fact(n-1)
  end
end

Tester[#Tester+1] = 'test_permutations'
function Tester.test_permutations()
  local src = { 1, 2, 3, 4 }
  local permGen = Gen.permutationGen(src)

  local data, valid, i  = nil, true, 0

  while valid do
    data, valid = permGen:generate()
    if valid then 
      i = i + 1
      printv(table.unpack(data)) 
    end
  end
  
  assert(i == math.fact(#src))
end

Tester[#Tester+1] = 'test_repeatMany'
function Tester.test_repeatMany()
  local src = { 1, 2, 3, 4 }
  local repeatGen = Gen.inOrderGen(src):repeatMany()
  local stepperGen = Gen.stepperGen(1, 4, 1, true)
  
  for i = 1, 8 do
    assert(repeatGen:generate() == stepperGen:generate())
  end
  
  assert(Gen.emptyGen():repeatMany():generate() == nil)
end

Tester[#Tester+1] = 'test_dowhile'
function Tester.test_dowhile()
  local count = 10
  local srcGen = Gen.stepperGen()
  local condGen = Gen.stepperGen():take(count)
  local dowhileGen = Gen.doWhileGen(srcGen, condGen)
  
  for i = 1, count do
    assert(dowhileGen:generate() == i)
  end
  
  assert(dowhileGen:generate() == nil)
  
end

-- print - helper method to print the IDL and the index for data definition
function Tester.print(instance)
    if verbose then
      -- print IDL
      local idl = xutils.to_idl_string_table(instance, {'model (IDL):'})
      print(table.concat(idl, '\n\t'))
    
      -- print the result of visiting each field
      local fields = xutils.to_instance_string_table(instance, {'instance:'})
      print(table.concat(fields, '\n\t'))
    end
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
    print('\nAll tests completed successfully!\nChange verbose=true for detailed output.')
  end
end

Tester:main()
