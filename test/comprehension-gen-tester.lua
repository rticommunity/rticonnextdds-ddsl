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

package.path = '../src/?.lua;../src/?/init.lua;' .. package.path

local xtypes         = require("ddsl.xtypes")
local ReactGen       = require("ddslgen.react-gen")
local Gen            = require("ddslgen.generator")
local Comprehension  = require("ddslgen.comprehension")

function xtypes.constraint(str)
  return xtypes.annotation{ Constraint = str }
end

Tester = {}

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

Tester[#Tester+1] = "test_comprehension"
function Tester.test_comprehension()
  local disposable
  
  --local xGen = Gen.rangeGen(0, 20)
  local xGen = ReactGen.toSubject(Gen.rangeGen(0, 20))
  
  local yGen = 
    Comprehension.parse("[ x*x | x <- xGen ]", { xGen = xGen } ) 

  local pointGen = 
    xGen:zipMany(yGen, function (x, y) 
                         return { x = x, y = y }
                       end)
    
  if pointGen:kind() == "push" then
    pointGen, disposable = Gen.toGenerator(pointGen, xGen)
  end
  
  for i=1, 5 do
    local point = pointGen:generate()
    printv("point.x = " .. point.x .. ", point.y = " .. point.y)
  end
  
  if disposable then disposable:dispose() end
end

Tester[#Tester+1] = "test_constrained_shape_y"
function Tester.test_constrained_shape_y()

  local ShapeType = xtypes.struct{
    ShapeType = {
      { x = { xtypes.long } },
      { y = { xtypes.long, xtypes.constraint{ "[ x*x | x <- xGen]" } } },
      { shapesize = { xtypes.long } },
      { color = { xtypes.string(128), xtypes.Key } },
    }
  }
  
  assert('x'         == ShapeType.x)
  assert('y'         == ShapeType.y)
  assert('shapesize' == ShapeType.shapesize)
  assert('color'     == ShapeType.color)   

  local shapeGenLib = {}
  local xMin, xMax = 0, 20
  local constraint

  shapeGenLib.x         = ReactGen.toSubject(Gen.rangeGen(xMin, xMax))

  local role, roledef = next(ShapeType[2])        -- roledef = ShapeType[2].y
  if roledef[2][xtypes.KIND]() == "annotation" then 
    constraint    = table.concat(roledef[2])  -- the constraint string
    printv(role, constraint)
  end

  shapeGenLib.y         = Comprehension.parse(constraint, { xGen = shapeGenLib.x } ) 
  shapeGenLib.color     = Gen.oneOfGen({ "RED", "GREEN", "BLUE" })
  shapeGenLib.shapesize = Gen.constantGen(30)

  local shapeReactGen = ReactGen.aggregateGen(ShapeType, shapeGenLib)
  local shapeGen, disposable = Gen.toGenerator(shapeReactGen, shapeGenLib.x)

  for i=1, 5 do
    local shape = shapeGen:generate()

    assert(shape.x >= xMin and shape.x <= xMax)
    assert(shape.y == shape.x*shape.x)
    assert(shape.color == "RED" or shape.color == "GREEN" or shape.color == "BLUE")
    assert(shape.shapesize == 30)

    printv("shape.x = " .. shape.x)
    printv("shape.y = " .. shape.y)
    printv("shape.color = " .. shape.color)
    printv("shape.shapesize = " .. shape.shapesize)
    printv()
  end
  
  disposable:dispose()
end

Tester[#Tester+1] = "test_constrained_shape"
function Tester.test_constrained_shape()

  local xMin, xMax = 0, 20

  local ShapeType = xtypes.struct{
    ShapeType = {
      { x         = { xtypes.long,        
                      xtypes.constraint{ "[ v   | v <- rangeGen(0,20) ]"} } },
      { y         = { xtypes.long,        
                      xtypes.constraint{ "[ v*v | v <- $x ]" } } },
      { shapesize = { xtypes.long,        
                      xtypes.constraint{ "[ v+5 | v <- $x ]" } } },
      { color     = { xtypes.string(128), 
                      xtypes.constraint{ "[ v   | v <- constantGen('BLUE') ]" } } },
    }
  }
  
  assert('x'         == ShapeType.x)
  assert('y'         == ShapeType.y)
  assert('shapesize' == ShapeType.shapesize)
  assert('color'     == ShapeType.color)   

  local shapeGenLib, kind, root = Comprehension.createGenLibFromConstraints(ShapeType)

  assert((kind == "push" and root) or kind == "pull")
  assert(shapeGenLib.x)
  assert(shapeGenLib.y)
  assert(shapeGenLib.shapesize)
  assert(shapeGenLib.color)
 
  local shapeGen, disposable

  if kind == "pull" then
    shapeGen = Gen.aggregateGen(ShapeType, shapeGenLib)
  else
    local shapeReactGen = ReactGen.aggregateGen(ShapeType, shapeGenLib)
    shapeGen, disposable = Gen.toGenerator(shapeReactGen, root)
  end

  for i=1, 5 do
    local shape = shapeGen:generate()

    if kind == "pull" then
      assert(shape.x >= xMin and shape.x <= xMax)
      assert(shape.y == shape.x*shape.x)
      assert(shape.color == "RED" or shape.color == "GREEN" or shape.color == "BLUE")
      assert(shape.shapesize == shape.x + 5)
    end

    printv("shape.x = " .. shape.x)
    printv("shape.y = " .. shape.y)
    printv("shape.color = " .. shape.color)
    printv("shape.shapesize = " .. shape.shapesize)
    printv()
  end
  
  if disposable then disposable:dispose() end
end

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

--[[
  kind = "push"
  if kind == "push" then
    local genCat = { x = "push", y = "push", shapesize = "pull", color = "pull" }
    shapeGenLib.x, root   = ReactGen.toSubject(Gen.rangeGen(xMin, xMax))
    --shapeGenLib.y         = Comprehension.parse("[ v*v | v <- xGen ]", { xGen = shapeGenLib.x } ) 
    shapeGenLib.y         = Comprehension.parseConstraint("[ v*v | v <- $x ]", shapeGenLib, genCat) 
    shapeGenLib.color     = Gen.constantGen("BLUE")
    shapeGenLib.shapesize = Gen.constantGen(30)
  else
    shapeGenLib.x         = Gen.rangeGen(xMin, xMax)
    --shapeGenLib.y         = Comprehension.parse("[ v*v | v <- xGen ]", { xGen = shapeGenLib.x } ) 
    shapeGenLib.y         = Comprehension.parseConstraint("[ v*v | v <- rangeGen(0,30) ]", 
                                                          shapeGenLib) 
    shapeGenLib.color     = Gen.constantGen("BLUE")
    shapeGenLib.shapesize = Gen.constantGen(30)
  end
]]
