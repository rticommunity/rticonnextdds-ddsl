local xtypes = require("xtypes")
local Gen = require("generator")

local Tester = {}
local ShapeTypeGen = {}

Tester[#Tester+1] = 'test_struct_gen'
function Tester:test_struct_gen()
  local ShapeType = xtypes.struct{
    ShapeType = {
      { x = { xtypes.long } },
      { y = { xtypes.long } },
      { shapesize = { xtypes.long } },
      { color = { xtypes.string(128), xtypes.Key } },
    }
  }
  self:print(ShapeType)
  
  assert('x'         == ShapeType.x)
  assert('y'         == ShapeType.y)
  assert('shapesize' == ShapeType.shapesize)
  assert('color'     == ShapeType.color)   

  local shapeGenLib = {}
  shapeGenLib.x         = Gen:rangeGen(0, 200)
  shapeGenLib.y         = Gen:rangeGen(0, 200)
  shapeGenLib.color     = Gen:oneOf({ "RED", "GREEN", "BLUE" })
  shapeGenLib.shapesize = Gen:rangeGen(20, 30)

  ShapeTypeGen = Gen:aggregateGen(ShapeType, shapeGenLib)
  local shape = ShapeTypeGen:generate()

  print("shape.x = " .. shape.x)
  print("shape.y = " .. shape.y)
  print("shape.color = " .. shape.color)
  print("shape.shapesize = " .. shape.shapesize)
end

Tester[#Tester+1] = 'test_seq_gen'
function Tester:test_seq_gen()
  local seqGen = Gen:seqGen(Gen.Float, 5)
  local seq = seqGen:generate()
  for k, v in ipairs(seq) do
    print(k, v)
  end
end

Tester[#Tester+1] = 'test_aggregate_gen'
function Tester:test_aggregate_gen()
  Tester:test_struct_gen()
  print()

  local seqGen = Gen:seqGen(ShapeTypeGen, 3)
  local seq = seqGen:generate()

  for k, shape in ipairs(seq) do
    for member, value in pairs(shape) do
      print(member, value)
    end
    print()
  end
end

Tester[#Tester+1] = 'test_base_gen'
function Tester:test_base_gen()
    
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
  
  self:print(Geometry)
 
  assert(Geometry.ThreeDPoint.z == 'z')
 
  local PointGen = Gen:aggregateGen(Geometry.ThreeDPoint)
  local point = PointGen:generate()
  print(point.x, point.y, point.z)

end

Tester[#Tester+1] = 'test_struct_basic'
function Tester:test_struct_basic()
  
    local Test = {}
    Test.Name = xtypes.struct{
      Name = {
        { first = { xtypes.string(10), xtypes.Key } },
        { last = { xtypes.wstring(128) } },
        { nicknames = { xtypes.string(40), xtypes.sequence(3) } },
--        { aliases = { xtypes.string(7), xtypes.sequence() } },
--        { birthday = { Test.Days, xtypes.Optional } },
--        { favorite = { Test.Submodule.Colors, xtypes.sequence(2), xtypes.Optional } },
      }
    }
    self:print(Test.Name)

    assert(Test.Name.first == 'first')
    assert(Test.Name.last == 'last')
    assert(Test.Name.nicknames() == 'nicknames#')
--    assert(Test.Name.nicknames[1] == 'nicknames[1]')
--    assert(Test.Name.aliases() == 'aliases#')
--    assert(Test.Name.aliases[1] == 'aliases[1]')
--    assert(Test.Name.birthday == 'birthday')
--    assert(Test.Name.favorite() == 'favorite#')
--    assert(Test.Name.favorite[1] == 'favorite[1]')

    local nameGen = Gen:aggregateGen(Test.Name)
    local name = nameGen:generate()
    print("first = ", name.first)
    print("last = ", name.last)
    print("nicknames = ", name.nicknames)
end

Tester[#Tester+1] = 'test_nested_struct_gen'
function Tester:test_nested_struct_gen()
    
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
        { point  = { Geometry[1]  } },
        { x      = { xtypes.float } },
      }
    }
  
  self:print(Geometry)
 
  assert(Geometry.Test.x == 'x')
 
  local testGen = Gen:aggregateGen(Geometry.Test)
  local testObj = testGen:generate()
  print(testObj.point.x, testObj.point.y, testObj.x)

end

Tester[#Tester+1] = 'test_enum_gen'
function Tester:test_enum_gen()
  local Geometry = xtypes.module { Geometry = xtypes.EMPTY }
  
  Geometry[#Geometry+1] = xtypes.enum{ Days = {  
     'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN',
  }}

  Geometry[#Geometry+1] = 
    xtypes.struct {
      Test = {
        { s   = { xtypes.short  } },
        { d   = { xtypes.double } },
        { day = { Geometry[1]   } }
      }
    }
  
  self:print(Geometry)
 
  assert(Geometry.Test.s == 's')
  assert(Geometry.Days.MON == 0)
  assert(Geometry.Days.SUN == 6)
 
  local testGen = Gen:aggregateGen(Geometry.Test)
  local testObject = testGen:generate()
  print(testObject.s, testObject.d, testObject.day)

end

Tester[#Tester+1] = 'test_primitive_gen'
function Tester:test_primitive_gen() 
  numGen      = Gen:numGen()
  boolGen     = Gen:boolGen()
  charGen     = Gen:charGen()
  alphaNumGen = Gen:alphaNumGen()
  stringGen   = Gen:stringGen()

  math.randomseed(os.time())

  for i=1,5 do 
    print(numGen:generate()) 
    print(boolGen:generate()) 
    local c = alphaNumGen.generate();
    print(string.format("%d:'%c'", c, c))
    print(stringGen:generate()) 
    print()
  end
end

function fibonacciGen()
  local a = 0
  local b = 1
  return Gen:new(function ()
           local c = a;
           a = b
           b = c+b
           return b
         end)
end  

Tester[#Tester+1] = 'test_fibonacciGen'
function Tester:test_fibonacciGen()
  local fiboGen     = fibonacciGen()
  print("Generating fibonacci numbers")
  for i=1,5 do 
    io.write(string.format("%d ", fiboGen.generate()))
  end
end

---
-- print - helper method to print the IDL and the index for data definition
function Tester:print(instance)
    -- print IDL
    local idl = xtypes.utils.visit_model(instance, {'idl:'})
    print(table.concat(idl, '\n\t'))
    
    -- print the result of visiting each field
    local fields = xtypes.utils.visit_instance(instance, {'index:'})
    print(table.concat(fields, '\n\t'))
end

---
-- main() - run the list of tests passed on the command line
--          if no command line arguments are passed in, run all the tests
function Tester:main()
  math.randomseed(os.time())
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
