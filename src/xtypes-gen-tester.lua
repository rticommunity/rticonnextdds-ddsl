local xtypes = require("xtypes")
local Gen = require("generator")

local Tester = {}
local Test = {}

Tester[#Tester+1] = 'test_module'
function Tester:test_module()

    Test.MyModule = xtypes.module{MyModule=xtypes.EMPTY} -- define a module

    self:print(Test.MyModule)
    
    assert(Test.MyModule ~= nil)
end

function ShapeTypeGen(shapetype)
  for key, val in ipairs(shapetype) do
    local role, def = next(val)
    print(role)
    for k, v in ipairs(def) do
      print(v)
    end
    print()
  end
end

Tester[#Tester+1] = 'test_struct_generation'
function Tester:test_struct_generation()
  local ShapeType = xtypes.struct{
    ShapeType = {
      { x = { xtypes.long } },
      { y = { xtypes.long } },
      { shapesize = { xtypes.long } },
      { color = { xtypes.string(128), xtypes.Key } },
    }
  }
  self:print(ShapeType)
  
  assert('x' == ShapeType.x)
  assert('y' == ShapeType.y)
  assert('shapesize' == ShapeType.shapesize)
  assert('color' == ShapeType.color)   

  ShapeTypeGen(ShapeType)
end

Tester[#Tester+1] = 'test_generators'
function Tester:test_generators() 
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
  if #arg > 0 then -- run selected tests passed in from the command line
    self:test_module() -- always run this one to initialize the module
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
