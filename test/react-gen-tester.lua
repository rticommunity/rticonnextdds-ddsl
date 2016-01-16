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
Purpose: Unit-testing push-based (reactive) data generators
Created: Sumant Tambe, 2015 Jun 15
-------------------------------------------------------------------------------
--]]
package.path = '../src/?.lua;../src/?/init.lua;' .. package.path

local xtypes   = require("ddsl.xtypes")
local xutils   = require("ddsl.xtypes.utils")
local Gen      = require("ddslgen.generator")
local ReactGen = require("ddslgen.react-gen")

local Tester = {}

local verbose = true

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

function Tester.printShape(shape)
  printv("shape.x         = ", shape.x)
  printv("shape.y         = ", shape.y)
  printv("shape.color     = ", shape.color)
  printv("shape.shapesize = ", shape.shapesize)
  printv()
end

Tester[#Tester+1] = "test_react_day"
function Tester.test_react_day()
   local xGen = ReactGen.toSubject(Gen.stepperGen(1, 7))
   local dayOfWeek = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
   local dayGen = xGen:map(function(x) 
                             return dayOfWeek[x]
                           end)

   local xCount, dayCount = 1, 1

   local disposable1 = 
      xGen:listen(function (x) 
                     assert(x==xCount)
                     xCount = xCount + 1
                     printv("x = ", x)
                  end)
    
   local disposable2 = 
      dayGen:listen(function (day) 
                       assert(day == dayOfWeek[dayCount])
                       dayCount = dayCount + 1
                       printv("day = ", day)
                    end)
   for i=1,5 do
     xGen:push() 
   end

   disposable1:dispose()
   disposable2:dispose()
end

Tester[#Tester+1] = "test_react_point3d"
function Tester.test_react_point3d()
 local xAnswer = { 1, 2, 3,  4,  5,  6,  7,  8,  9,  10 }
 local yAnswer = { 1, 4, 9, 16, 25, 36, 49, 64, 81, 100 }
 local zAnswer = { 0, 2, 6, 12, 20, 30, 42, 56, 72,  90 }
 local xCount, yCount, zCount = 1, 1, 1

 local xGen = ReactGen.toSubject(Gen.stepperGen(1, 10))
 local yGen = xGen:map(function (x) return x*x end)  
 local zGen = yGen:zipTwoDebug(xGen, function (y, x) return y-x end)  

 local disposable2d = 
   xGen:zipTwoDebug(yGen, 
                function (x, y) 
                  return { x=x, y=y }
                end)
       :listen(function (point2d) 
                 assert(xAnswer[xCount] == point2d.x)
                 assert(yAnswer[yCount] == point2d.y)
                 xCount = xCount + 1
                 yCount = yCount + 1
                 printv(" point2d.x = " .. point2d.x ..
                       " point2d.y = " .. point2d.y)
               end)

 local disposable3d =  
   xGen:zipMany(yGen, zGen, 
                function (x, y, z) 
                  return { x=x, y=y, z=z }
                end)
       :listen(function (point3d) 
                 assert(zAnswer[zCount] == point3d.z)
                 zCount = zCount + 1
                 printv(" point3d.x = " .. point3d.x ..
                       " point3d.y = " .. point3d.y ..
                       " point3d.z = " .. point3d.z)
               end)
 for i=1, #xAnswer do
   xGen:push()
 end
 
 disposable2d:dispose()
 disposable3d:dispose()
end

Tester[#Tester+1] = 'test_struct_gen'
function Tester.test_struct_gen()
  local xAnswer = { 0, 1, 1, 2, 3,  5,  8, 13, 21, 34 }
  local yAnswer = { 0, 2, 2, 4, 6, 10, 16, 26, 42, 68 }
  local xCount, yCount = 1, 1 

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

  local shapeGenLib = { }

  local subject = ReactGen.toSubject(Gen.fibonacciGen())
  shapeGenLib.x          = subject
  shapeGenLib.y          = shapeGenLib.x:map(function (x) return 2*x end)
  shapeGenLib.color      = Gen.oneOfGen({ "RED", "GREEN", "BLUE" })
  shapeGenLib.shapesize  = Gen.rangeGen(20, 30)

  local reactiveShapeGen = ReactGen.aggregateGen(ShapeType, shapeGenLib)

  local disposable = 
    reactiveShapeGen:listen(function (shape) 
                              assert(shape.x == xAnswer[xCount])
                              assert(shape.y == yAnswer[yCount])
                              assert(shape.shapesize >= 20 and shape.shapesize <= 30)
                              assert(shape.color == "RED" or 
                                     shape.color == "GREEN" or 
                                     shape.color == "BLUE")
                              xCount = xCount + 1
                              yCount = yCount + 1
                              Tester.printShape(shape)
                            end)
  
  for i=1, #xAnswer do
    subject:push()
  end

  disposable:dispose()
end

Tester[#Tester+1] = "test_roundtrip"
function Tester.test_roundtrip()
  local answer = { 21, 22, 23, 24, 25, 26, 27, 28, 29, 30 }
  local subject    = ReactGen.toSubject(Gen.stepperGen(21,30))
  local rangegen, disposable = Gen.toGenerator(subject, subject)

  for i=1, #answer do
    local value, valid = rangegen:generate()
    assert(answer[i] == value)
    printv(value, valid)
  end

  disposable:dispose()
  local value, valid = rangegen:generate()
  assert(value == nil)
  assert(valid == false)
  printv(value, valid)
end

Tester[#Tester+1] = "test_react_seq"
function Tester.test_react_seq()

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

  local shapeGenLib = { }

  shapeGenLib.x         = ReactGen.toSubject(Gen.rangeGen(0, 200))
  shapeGenLib.y         = shapeGenLib.x:map(function (x) return 2*x end)
  shapeGenLib.color     = Gen.oneOfGen({ "RED", "GREEN", "BLUE" })
  shapeGenLib.shapesize = Gen.rangeGen(20, 30)

  local reactiveShapeGen = ReactGen.aggregateGen(ShapeType, shapeGenLib)
  local subGrp = ReactGen.SubjectGroup:new({shapeGenLib.x})
  local shapeGen, disposable = Gen.toGenerator(reactiveShapeGen, subGrp)

  local shapeSeqGen = Gen.seqGen(shapeGen, 5)
  local shapeSeq = shapeSeqGen:generate()
  
  for i=1, #shapeSeq do
    assert(shapeSeq[i].y == 2*shapeSeq[i].x)
    assert(shapeSeq[i].color == "RED" or 
           shapeSeq[i].color == "GREEN" or
           shapeSeq[i].color == "BLUE")
    assert(shapeSeq[i].shapesize >= 20 and shapeSeq[i].shapesize <= 30)
    Tester.printShape(shapeSeq[i]) 
  end

  disposable:dispose()
end

Tester[#Tester+1] = "test_react_gen"
function Tester.test_react_gen()

  local s1Answer = { 1, 2, 3, 4,  5,  6,  7,  8,  9, 10 }
  local s2Answer = { 2, 4, 6, 8, 10, 12, 14, 16, 18, 20 }
  local s1Count, s2Count = 1, 1

  local sub1 = 
    ReactGen.toSubject(Gen.stepperGen(1, 10))

  local sub2 = 
    ReactGen.toSubject(Gen.stepperGen(11, 20))

  local disp1 = 
    sub1:map(function (i) 
               assert(i == s1Answer[s1Count])
               s1Count = s1Count + 1 
               printv("i = ", i)
               return 2*i
             end)
        :listen(function (j) 
                  assert(j == s2Answer[s1Count-1])
                  printv("j = ", j)
                end)

  local disp2 = 
    sub1:zipMany(sub2, function (i, k)
                          assert(k == i+10)
                          s2Count = s2Count + 1
                          printv("i=", i, " k=", k)
                          return i+k
                       end)
        :where(function (x) return x % 2 == 0 end)
        :listen(function (y) printv("y = ", y) end)

  for i=1, #s1Answer do
    printv("Calling sub1 push ", i)
    sub1:push()

    printv("Calling sub2 push")
    sub2:push()
  end

  printv("disposing disp1")
  disp1:dispose()

  printv("Calling sub1 push again")
  sub1:push()

  printv("Calling sub2 push again")
  sub2:push()
  
  assert(s1Count == s2Count)
end

Tester[#Tester+1] = "test_flatmap_gen"
function Tester.test_flatmap_gen()
  local xAnswer = { 0, 1, 1, 2, 3,  5 }
  local yAnswer = { 0, 2, 2, 4, 6, 10 }
  local kAnswer = { 0, 
                    0, 4, 
                    0, 6,  6, 
                    0, 8,  8,  16, 
                    0, 10, 10, 20, 30, 
                    0, 12, 12, 24, 36, 60 }
  local xCount, yCount, kCount = 1, 1, 1 

  local sub1 = 
    ReactGen.toSubject(Gen.fibonacciGen())

  local sub2 = 
    ReactGen.toSubject(Gen.stepperGen(1, 6))

  local disp1 = 
    sub1:map(function (i) 
               assert(i == xAnswer[xCount])
               xCount = xCount + 1
               printv("i = ", i)
               return 2*i
             end)
        :flatMap(function (j) 
                   assert(j == yAnswer[yCount])
                   yCount = yCount + 1
                   printv("j = ", j)
                   return sub2:map(function (v) 
                                     printv("v = ", v)
                                     return j*v 
                                   end)
                 end)
        :listen(function (k) 
                  assert(k == kAnswer[kCount])
                  kCount = kCount + 1
                  printv("k = ", k)
                end)

  local disp2 = 
    sub1:zipMany(sub2, function (x, y)
                         assert(x == xAnswer[y])
                         printv("x=", x, " y=", y)
                         return x+y
                       end)
        :listen(function (z) 
                  printv("z = ", z) 
                end)

  for i=1, #xAnswer - 1 do
    printv("Calling sub1 push ", i)
    sub1:push()

    printv("Calling sub2 push")
    sub2:push()
  end

  printv("disposing disp2")
  disp2:dispose()

  printv("Calling sub1 push again")
  sub1:push()

  printv("Calling sub2 push again")
  sub2:push()
  
  printv("disposing disp1")
  disp1:dispose()
  
  printv("Calling sub1 push again")
  sub1:push()

  printv("Calling sub2 push again")
  sub2:push()

end

Tester[#Tester+1] = "test_flatmap_take"
function Tester.test_flatmap_take()
  local iAnswer = { 0, 1,  1,  2,  3,  5 }
  local jAnswer = { 0, 2,  2,  4,  6, 10 }
  local kAnswer = { 4, 6, 16, 20, 30, 36, 60 }
  local iCount, jCount, kCount = 1, 1, 1 

  local sub1 = 
    ReactGen.toSubject(Gen.fibonacciGen())

  local sub2 = 
    ReactGen.toSubject(Gen.stepperGen(1, 6))

  local disp1 = 
    sub1:map(function (i) 
               printv("i = ", i)
               assert(i == iAnswer[iCount])
               iCount = iCount + 1
               return 2*i
             end)
        :flatMap(function (j) 
                   printv("j = ", j)
                   assert(j == jAnswer[jCount])
                   jCount = jCount + 1
                   return sub2:map(function (v) 
                                     printv("v = ", v)
                                     return j*v 
                                   end)
                              :take(j/2)
                 end)
        :listen(function (k) 
                  printv("k = ", k)
                  assert(k == kAnswer[kCount])
                  kCount = kCount + 1
                end)

  for i=1, #iAnswer - 1 do
    printv("Calling sub1 push ", i)
    sub1:push()

    printv("Calling sub2 push")
    sub2:push()
  end

  printv("Calling sub1 push again")
  sub1:push()

  printv("Calling sub2 push again")
  sub2:push()
  
  printv("disposing disp1")
  disp1:dispose()
  
  printv("Calling sub1 push again")
  sub1:push()

  printv("Calling sub2 push again")
  sub2:push()

end

Tester[#Tester+1] = "test_memory"
function Tester.test_memory()
  
  local sub1 = 
    ReactGen.toSubject(Gen.stepperGen(1, 1000, 1, true), false)

  local sub2 = 
    ReactGen.toSubject(Gen.stepperGen(), false)

  local disp1 = 
    sub1:map(function (i) 
               return i
             end)
        :flatMap(function (j) 
                   return sub2:map(function (v) 
                                     return v 
                                   end)
                              :take(j)
                 end)
        :listen()
        --[[:listen(function (v) io.write(string.format("%d ", v)) end)]]

  printv(collectgarbage("collect"))
  printv(collectgarbage("stop"))
  printv("before looping memory = ", collectgarbage("count"))
  for i=1, 10000 do
    sub1:push()
    sub2:push()
    if i % 2000 == 0 then
      printv("memory = ", collectgarbage("count"))
      collectgarbage("collect")
      collectgarbage("stop")
    end
  end
  printv("before dispose memory = ", collectgarbage("count"))
  sub1:complete() -- alternatively, disp1:dispose()
  printv(collectgarbage("collect"))
  printv("after dispose ", collectgarbage("count"))

end

Tester[#Tester+1] = "test_scan"
function Tester.test_scan()
  
  local answer = { 1, 3, 6, 10, 15, 21, 28, 36, 45, 55 }

  local subject = 
    ReactGen.toSubject(Gen.stepperGen(1, 10))

  local disposable =
    subject:scan(function (sum, value) return sum + value end, 0)
           :listen(function (sum) assert(answer[i] == sum) end)

  disposable:dispose()

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
