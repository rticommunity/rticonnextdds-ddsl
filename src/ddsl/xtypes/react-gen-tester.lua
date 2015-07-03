local ReactGen = require("dds.xtypes.react-gen")
local Gen      = require("ddsl.xtypes.generator")
local xtypes   = require("ddsl.xtypes")

local Tester = {}

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

  local shapeGenLib = { }

  shapeGenLib.x         = ReactGen.createSubjectFromPullGen(Gen.rangeGen(0, 200))
  shapeGenLib.y         = shapeGenLib.x:map(function (x) return 2*x end)
  shapeGenLib.color     = Gen.oneOf({ "RED", "GREEN", "BLUE" })
  shapeGenLib.shapesize = Gen.rangeGen(20, 30)

--    shapeGenLib.x:zip2(shapeGenLib.y, 
--                       function(x, y)
--                         return { x = x, 
--                                  y = y,
--                                 color = shapeGenLib.color:generate(),
--                                 shapesize = shapeGenLib.shapesize:generate()
--                                }
--                       end)

  local reactiveShapeGen = 
      ReactGen.aggregateGen(ShapeType, shapeGenLib)
              :listen(function (shape) 
                        print("shape.x         = ", shape.x)
                        print("shape.y         = ", shape.y)
                        print("shape.color     = ", shape.color)
                        print("shape.shapesize = ", shape.shapesize)
                        print()
                      end)

  for i=1, 5 do
    shapeGenLib.x:push()
    --reactYGen:push()
  end
end

Tester[#Tester+1] = "test_react_gen"
function Tester.test_react_gen()

  local sub1 = 
    ReactGen.createSubjectFromPullGen(Gen.rangeGen(1, 50))

  local sub2 = 
    ReactGen.createSubjectFromPullGen(Gen.rangeGen(1, 5))

  local disp1 = 
    sub1:map(function (i) 
               print("i = ", i)
               return 2*i
             end)
        :flatMap(function (j) 
                   print("j = ", j)
                   return sub2:map(function (v) 
                                     print("v = ", v)
                                     return j*v 
                                   end)
                 end)
        :listen(function (k) 
                  print("k = ", k)
                end)

  local disp2 = 
    sub1:zip2(sub2, function (x, y)
                      print("x=", x, " y=", y)
                      return x+y
                    end)
        :where(function (z) return z % 2 == 0 end)
        :listen(function (z) print("z = ", z) end)

  for i=1,2 do
    print("Calling sub1 push ", i)
    sub1:push()

    print("Calling sub2 push")
    sub2:push()
  end

  print("disposing disp1")
  disp1:dispose()

  print("Calling sub1 push again")
  sub1:push()

  print("Calling sub2 push again")
  sub2:push()

end

---
-- print - helper method to print the IDL and the index for data definition
function Tester.print(instance)
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
