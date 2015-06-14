#!/usr/local/bin/lua
--[[
  (c) 2005-2014 Copyright, Real-Time Innovations, All rights reserved.     
                                                                           
 Permission to modify and use for internal purposes granted.               
 This software is provided "as is", without warranty, express or implied.
--]]
--[[
 -----------------------------------------------------------------------------
 Purpose: Test Lua X-Types and Domain Specific Language (DDSL)
 Created: Rajive Joshi, 2014 Feb 14
-----------------------------------------------------------------------------
--]]

local xtypes = require('xtypes')

--------------------------------------------------------------------------------
-- Tester - the unit tests
--------------------------------------------------------------------------------

local Tester = {} -- array of test functions
local Test = {}   -- table to hold the types created by the tests


Tester[#Tester+1] = 'test_builtin'
function Tester:test_builtin()
  for k, v in pairs(xtypes) do
      print('*** builtin: ', k, v)
  end
end

Tester[#Tester+1] = 'test_module'
function Tester:test_module()

    Test.MyModule = xtypes.module{MyModule=xtypes.EMPTY} -- define a module

    self:print(Test.MyModule)
    
    assert(Test.MyModule ~= nil)
end

Tester[#Tester+1] = 'test_submodule'
function Tester:test_submodule()

  Test.Submodule = xtypes.module{Submodule=xtypes.EMPTY} -- submodule 
  Test.MyModule[#Test.MyModule+1] = Test.Submodule -- add to module
  
  self:print(Test.Submodule)
  self:print(Test.MyModule)
  
  assert(Test.MyModule.Submodule == Test.Submodule)
end

Tester[#Tester+1] = 'test_enum_imperative'
function Tester:test_enum_imperative()

  local MyEnum = xtypes.enum{MyEnum=xtypes.EMPTY}
  MyEnum[1] = { JAN = #MyEnum }
  MyEnum[2] = { FEB = 102 }
  MyEnum[3] = { MAR = #MyEnum }
  MyEnum[4] = { APR = #MyEnum }
  MyEnum[5] = { MAY = 105 }
  MyEnum[6] = 'JUN'

  self:print(MyEnum)
  
  assert(MyEnum.JAN == 0)
  assert(MyEnum.FEB == 102)
  assert(MyEnum.MAR == 2)
  assert(MyEnum.APR == 3)
  assert(MyEnum.MAY == 105)
  assert(MyEnum.JUN == 5)
  
  -- delete an entry
  print("\n-- deleted 3rd entry --\n")
  MyEnum[3] = nil
  self:print(MyEnum)
  assert(MyEnum.MAR == nil)
 
   -- change 1st entry
  print("\n-- changed 1st entry --\n")
  MyEnum[1] = { JAN = 100 }
  self:print(MyEnum)
  assert(MyEnum.JAN == 100)
  
  assert(5 == #MyEnum)
end

Tester[#Tester+1] = 'test_enum1'
function Tester:test_enum1()

  Test.Days = xtypes.enum{Days = {  
      'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN',
  }}
  
  self:print(Test.Days)
  
  assert(Test.Days.MON == 0)
  assert(Test.Days.SUN == 6)
end

Tester[#Tester+1] = 'test_enum2'
function Tester:test_enum2()

  Test.Months = xtypes.enum{
    Months = {
      { OCT = 10 },
      { NOV = 11 },
      { DEC = 12 }
    }
  }
  
  self:print(Test.Months)
  
  assert(Test.Months.OCT == 10)
  assert(Test.Months.DEC == 12)
end

Tester[#Tester+1] = 'test_enum_submodule'
function Tester:test_enum_submodule()

  Test.Submodule[#Test.Submodule+1] = xtypes.enum{Colors = {
      { RED =  -5 },
      { YELLOW =  7 },
      { GREEN = -9 },
      'PINK',
  }}
  self:print(Test.Submodule.Colors)
  
  assert(Test.Submodule.Colors.YELLOW == 7)
  assert(Test.Submodule.Colors.GREEN == -9)
  assert(Test.Submodule.Colors.PINK == 3)
end

Tester[#Tester+1] = 'test_struct_imperative'
function Tester:test_struct_imperative()

    local DynamicShapeType = xtypes.struct{DynamicShapeType=xtypes.EMPTY}
    DynamicShapeType[1] = { x = { xtypes.long } }
    DynamicShapeType[2] = { y = { xtypes.long } }
    DynamicShapeType[3] = { shapesize = { xtypes.double } }
    DynamicShapeType[4] = { color = { xtypes.string(128), xtypes.Key } }
           
    self:print(DynamicShapeType)

    assert(DynamicShapeType.x == 'x')
    assert(DynamicShapeType.y == 'y')
    assert(DynamicShapeType.shapesize == 'shapesize')
    assert(DynamicShapeType.color == 'color')   
    
    
    
    -- redefine shapesize:
    DynamicShapeType[3] = { shapesize = { xtypes.long } } -- redefine
    print("\n-- redefined: double->long shapesize --\n")
    self:print(DynamicShapeType)
    assert(DynamicShapeType.shapesize == 'shapesize')
 
 
    -- add z:
    DynamicShapeType[#DynamicShapeType+1] = 
                                { z = { xtypes.string() , xtypes.Key } }
    print("\n-- added: string z @Key --\n")
    self:print(DynamicShapeType)
    assert(DynamicShapeType.z == 'z') 
    
    
    -- remove z:
    DynamicShapeType[#DynamicShapeType] = nil 
    print("\n-- removed: string z --\n")
    self:print(DynamicShapeType)
    assert(DynamicShapeType.z == nil) 

       
    -- add a base class
    local Bases = {}
    Bases.Base1 = xtypes.struct{
      Base1 = {
        { org = { xtypes.string() } },
      }
    }
    DynamicShapeType[xtypes.BASE] = Bases.Base1
    print("\n-- added: base class: Base1 --\n")
    self:print(Bases.Base1)
    self:print(DynamicShapeType)
    assert(DynamicShapeType.org == 'org')  
    assert(DynamicShapeType[xtypes.BASE] == Bases.Base1)
    
    -- redefine base class
    Bases.Base2 = xtypes.struct{
      Base2 = {
        { pattern = { xtypes.long } },
      }
    }
    DynamicShapeType[xtypes.BASE] = Bases.Base2
    print("\n-- replaced: base class: Base2 --\n")
    self:print(Bases.Base2)
    self:print(DynamicShapeType)
    assert(DynamicShapeType.pattern == 'pattern') 
    assert(DynamicShapeType.org == nil)  
    -- assert(DynamicShapeType[xtypes.BASE] == Bases.Base2)
    
    -- removed base class
    DynamicShapeType[xtypes.BASE] = nil
    print("\n-- erased base class --\n")
    self:print(DynamicShapeType)
    assert(DynamicShapeType.pattern == nil) 
    -- assert(DynamicShapeType[xtypes.BASE] == nil)
 
 
    -- add an annotation
    DynamicShapeType[xtypes.QUALIFIERS] = { 
        xtypes.Extensibility{'EXTENSIBLE_EXTENSIBILITY'} 
    }
    print("\n-- added annotation: @Extensibility --\n")
    self:print(DynamicShapeType)
    -- assert(DynamicShapeType[xtypes.QUALIFIERS][1] ~= nil)
 
    -- add another annotation
    DynamicShapeType[xtypes.QUALIFIERS] = { 
        xtypes.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
        xtypes.Nested{'FALSE'},
    }  
    print("\n-- added: annotation: @Nested --\n")
    self:print(DynamicShapeType)
    assert(DynamicShapeType[xtypes.QUALIFIERS][1] ~= nil)
    assert(DynamicShapeType[xtypes.QUALIFIERS][2] ~= nil)
 
    -- clear annotations:
    DynamicShapeType[xtypes.QUALIFIERS] = nil
    print("\n-- erased annotations --\n")
    self:print(DynamicShapeType)
    assert(DynamicShapeType[xtypes.QUALIFIERS] == nil)
    
    
    -- iterate over the struct definition
    print("\n-- struct definition iteration --", DynamicShapeType)
    print(DynamicShapeType[xtypes.KIND](), DynamicShapeType[xtypes.NAME], #DynamicShapeType)
    for i, v in ipairs(DynamicShapeType) do
      print(next(v))
    end
    assert(4 == #DynamicShapeType)
end

Tester[#Tester+1] = 'test_struct_basechange'
function Tester:test_struct_basechange()
  Test.BaseStruct = xtypes.struct{BaseStruct = {
      { x = { xtypes.long } },
      { y = { xtypes.long } },
  }}
  
  Test.DerivedStruct = xtypes.struct{
    DerivedStruct = {Test.BaseStruct,
      { speed = { xtypes.double } }
    }
  }
  print("\n-- DerivedStruct --\n")
  self:print(Test.BaseStruct)
  self:print(Test.DerivedStruct)

  assert(Test.DerivedStruct.x == 'x')
  assert(Test.DerivedStruct.y == 'y')
  assert(Test.DerivedStruct.speed == 'speed')
 
 
  -- remove base class
  Test.DerivedStruct[xtypes.BASE] = nil

  print("\n-- DerivedStruct removed base class --\n")
  self:print(Test.DerivedStruct)
  assert(Test.DerivedStruct.x == nil)
  assert(Test.DerivedStruct.y == nil)
 
   -- change base class and add it
  Test.BaseStruct[1] = { w = { xtypes.string() } }
  Test.DerivedStruct[xtypes.BASE] = Test.BaseStruct
  assert(Test.BaseStruct[1].w[1] == xtypes.string())
  
  print("\n-- DerivedStruct added modified base class --\n")
  self:print(Test.BaseStruct)
  self:print(Test.DerivedStruct)
  assert(Test.DerivedStruct.w == 'w')
  assert(Test.DerivedStruct.y == 'y')


  -- modify a filed in the base class 
  Test.BaseStruct[2] = { z = { xtypes.string() } }
  assert(Test.BaseStruct[2].z[1] == xtypes.string())
  
  print("\n-- DerivedStruct base changed from y : long -> z : string --\n")
  self:print(Test.BaseStruct)
  self:print(Test.DerivedStruct)
  assert(Test.DerivedStruct.z == 'z')
end

Tester[#Tester+1] = 'test_struct_nomodule'
function Tester:test_struct_nomodule()
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
end

Tester[#Tester+1] = 'test_struct_submodule'
function Tester:test_struct_submodule()

    Test.Fruit = xtypes.struct{
      Fruit = {
        { weight = { xtypes.double } },
        { color = { Test.Submodule.Colors } },
      }
    }
    Test.Submodule[#Test.Submodule+1] = Test.Fruit
    self:print(Test.Submodule)

    assert(Test.Submodule.Fruit == Test.Fruit) 
    assert(Test.Submodule.Fruit.weight == 'weight')
    assert(Test.Submodule.Fruit.color == 'color')
end

Tester[#Tester+1] = 'test_struct_basic'
function Tester:test_struct_basic()
  
    Test.Name = xtypes.struct{
      Name = {
        { first = { xtypes.string(10), xtypes.Key } },
        { last = { xtypes.wstring(128) } },
        { nicknames = { xtypes.string(), xtypes.sequence(3) } },
        { aliases = { xtypes.string(7), xtypes.sequence() } },
        { birthday = { Test.Days, xtypes.Optional } },
        { favorite = { Test.Submodule.Colors, xtypes.sequence(2), xtypes.Optional } },
      }
    }
    self:print(Test.Name)

    assert(Test.Name.first == 'first')
    assert(Test.Name.last == 'last')
    assert(Test.Name.nicknames() == 'nicknames#')
    assert(Test.Name.nicknames[1] == 'nicknames[1]')
    assert(Test.Name.aliases() == 'aliases#')
    assert(Test.Name.aliases[1] == 'aliases[1]')
    assert(Test.Name.birthday == 'birthday')
    assert(Test.Name.favorite() == 'favorite#')
    assert(Test.Name.favorite[1] == 'favorite[1]')
end

Tester[#Tester+1] = 'test_user_annotation'
function Tester:test_user_annotation()

    -- user defined annotation
    Test.MyAnnotation = xtypes.annotation{
      MyAnnotation = {value1 = 42, value2 = 9.0}
    }
    Test.MyAnnotationStruct = xtypes.struct{
      MyAnnotationStruct = {
        { id = { xtypes.long, xtypes.Key } },
        { org = { xtypes.long, xtypes.Key{GUID=3} } },
        { weight = { xtypes.double, Test.MyAnnotation } }, -- default 
        { height = { xtypes.double, Test.MyAnnotation{} } },
        { color = { Test.Submodule.Colors, 
                    Test.MyAnnotation{value1 = 10} } },
      }
    }
    self:print(Test.MyAnnotation)
    self:print(Test.MyAnnotationStruct)
     
    assert(Test.MyAnnotation ~= nil)
    assert(Test.MyAnnotation.value1 == 42)
    assert(Test.MyAnnotation.value2 == 9.0)
end

Tester[#Tester+1] = 'test_struct_nested'
function Tester:test_struct_nested()

    Test.Address = xtypes.struct{
      Address = {
        xtypes.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
        { name = { Test.Name } },
        { street = { xtypes.string() } },
        { city = { xtypes.string(10), 
                      Test.MyAnnotation{value1 = 10, value2 = 17} } },
        xtypes.Nested{'FALSE'},
      }
    }
    self:print(Test.Address)
    
    assert(Test.Address.name.first == 'name.first')
    assert(Test.Address.name.nicknames() == 'name.nicknames#')
    assert(Test.Address.name.nicknames[1] == 'name.nicknames[1]')
    assert(Test.Address.street == 'street')
    assert(Test.Address.city == 'city')
end

Tester[#Tester+1] = 'test_union_imperative'
function Tester:test_union_imperative()

    local DynamicUnion = xtypes.union{DynamicUnion={xtypes.char}} -- switch
    DynamicUnion[1] = { 's', m_str = { xtypes.string() } }
    DynamicUnion[2] = { 'i', m_int = { xtypes.short } }  
    DynamicUnion[3] = { 'n' } -- no definition
    DynamicUnion[4] = { nil, m_oct = { xtypes.octet } } -- default case

    --[[ un-comment to test error checking (expected to assert)
    DynamicUnion[#DynamicUnion+1] = 
                                  { 'x', m_oct = { xtypes.octet } }
    --]]
    
    -- install it in the module
    Test.DynamicUnion = DynamicUnion
    self:print(DynamicUnion)

    assert(DynamicUnion._d == '#')
    assert(DynamicUnion.m_str == 'm_str')
    assert(DynamicUnion.m_int == 'm_int')
    assert(DynamicUnion.m_oct == 'm_oct')
    
    -- redefine m_int:
    DynamicUnion[2] = { 'l', m_int = { xtypes.long, xtypes.Key } }  
    print("\n-- redefined: short->long m_int @Key --\n")
    self:print(DynamicUnion)
    assert(DynamicUnion.m_int == 'm_int')
 
 
    -- add m_real:
    DynamicUnion[#DynamicUnion+1] = 
                      { 'r', m_real = { xtypes.double, xtypes.Key } }
    print("\n-- added: double m_real @Key --\n")
    self:print(DynamicUnion)
    assert(DynamicUnion.m_real == 'm_real')
    
    -- remove m_real:
    local case = DynamicUnion[1] -- save the case
    DynamicUnion[1] = nil -- erase m_real
    print("\n-- removed: double m_str --\n")
    self:print(DynamicUnion)
    assert(DynamicUnion.m_str == nil) 
 
  
    -- check the accessor syntax - returned value must be assignable
    -- add the previously saved case1 at the end, under a new value
    case[1] = 'S'
    DynamicUnion[#DynamicUnion+1] = case 
    print("\n-- re-inserted modified case for m_str at the end --\n")
    self:print(DynamicUnion)
    assert(DynamicUnion.m_str == 'm_str')

   
    -- add an annotation
    DynamicUnion[xtypes.QUALIFIERS] = { 
        xtypes.Extensibility{'EXTENSIBLE_EXTENSIBILITY'} 
    }
    print("\n-- added annotation: @Extensibility --\n")
    self:print(DynamicUnion)
    assert(DynamicUnion[xtypes.QUALIFIERS][1] ~= nil)
    
    -- add another annotation
    DynamicUnion[xtypes.QUALIFIERS] = { 
        xtypes.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
        xtypes.Nested{'FALSE'},
        Test.MyAnnotation{x=2},
    }  
    print("\n-- added: annotation: @Nested and MyAnnotation --\n")
    self:print(DynamicUnion)
    assert(DynamicUnion[xtypes.QUALIFIERS][1] ~= nil)
    assert(DynamicUnion[xtypes.QUALIFIERS][2] ~= nil)
    assert(DynamicUnion[xtypes.QUALIFIERS][3] ~= nil)
     
    -- clear annotations:
    DynamicUnion[xtypes.QUALIFIERS] = nil
    print("\n-- erased annotations --\n")
    self:print(DynamicUnion)
    assert(DynamicUnion[xtypes.QUALIFIERS] == nil)
    
    -- iterate over the union definition
    print("\n-- union definition iteration --", DynamicUnion)
    print(DynamicUnion[xtypes.KIND](), DynamicUnion[xtypes.NAME], #DynamicUnion)
    for i, v in ipairs(DynamicUnion) do print(v[1], ':', next(v, 1)) end
    assert(5 == #DynamicUnion)
end

Tester[#Tester+1] = 'test_union_imperative2'
function Tester:test_union_imperative2()
    local DynamicUnion2 = xtypes.union{DynamicUnion2={xtypes.char}} -- switch
    DynamicUnion2[1] = { 's', m_str = { xtypes.string() } }
    DynamicUnion2[2] = { 'i', m_int = { xtypes.short } }  
    DynamicUnion2[3] = { nil, m_oct = { xtypes.octet } } -- default case
    
    local DynamicStruct2 = xtypes.struct{
      DynamicStruct2 = {
          { x = { xtypes.long } },
          { u = { DynamicUnion2 } },
      }
    }
    Test.DynamicUnion2 = DynamicUnion2
    Test.DynamicStruct = DynamicStruct2
    
    self:print(DynamicUnion2)
    self:print(DynamicStruct2)
    
    assert(DynamicStruct2.x == 'x')
    assert(DynamicStruct2.u._d == 'u#')
    assert(DynamicStruct2.u.m_str == 'u.m_str')
    assert(DynamicStruct2.u.m_int == 'u.m_int')
    assert(DynamicStruct2.u.m_oct == 'u.m_oct')
    
    -- add a member to the union, the struct should be updated
    DynamicUnion2[#DynamicUnion2 + 1] =
                { 'r', m_real = { xtypes.double, xtypes.Key } }
    print("\n-- added to union: double m_real @Key --\n")
    self:print(DynamicUnion2)
    assert(DynamicUnion2.m_real == 'm_real')
    self:print(DynamicStruct2)
    assert(DynamicStruct2.u.m_real == 'u.m_real')
    
    -- remove a member from the union, the struct should be updated
    DynamicUnion2[1] = nil -- erase m_str
    print("\n-- removed: string m_str --\n")
    self:print(DynamicUnion2)
    assert(DynamicUnion2.m_str == nil)
    self:print(DynamicStruct2)
    assert(DynamicUnion2.m_str == nil) 
end

Tester[#Tester+1] = 'test_union1'
function Tester:test_union1()

  local TestUnion1 = xtypes.union{
    TestUnion1 = {xtypes.short,
      { 1, 
          x = { xtypes.string() } },
      { 2, 
          y = { xtypes.long_double } },
      { nil, -- default 
          z = { xtypes.boolean } },
    }
  }
  Test.TestUnion1 = TestUnion1
  
  self:print(TestUnion1)
  
  assert(TestUnion1._d == '#')
  assert(TestUnion1.x == 'x')
  assert(TestUnion1.y == 'y')
  assert(TestUnion1.z == 'z')
  
  print("\n-- changed discriminator: short -> long --")
  TestUnion1[xtypes.SWITCH] = xtypes.long
  self:print(TestUnion1)
  assert(TestUnion1._d == '#')
end

Tester[#Tester+1] = 'test_union2'
function Tester:test_union2()

  Test.TestUnion2 = xtypes.union{
    TestUnion2 = {xtypes.char,
      { 'c', 
        name = { Test.Name, xtypes.Key } },
      { 'a', 
        address = { Test.Address } },
      { nil, -- default
        x = { xtypes.double } },
    }
  }
  self:print(Test.TestUnion2)
  
  -- discriminator
  assert(Test.TestUnion2._d == '#')
  
  -- name
  assert(Test.TestUnion2.name.first == 'name.first')
  assert(Test.TestUnion2.name.nicknames() == 'name.nicknames#')  
  assert(Test.TestUnion2.name.nicknames[1] == 'name.nicknames[1]')

  -- address
  assert(Test.TestUnion2.address.name.first == 'address.name.first')
  assert(Test.TestUnion2.address.name.nicknames() == 'address.name.nicknames#')  
  assert(Test.TestUnion2.address.name.nicknames[1] == 'address.name.nicknames[1]')

  -- x
  assert(Test.TestUnion2.x == 'x')
end

Tester[#Tester+1] = 'test_union3'
function Tester:test_union3()

  Test.TestUnion3 = xtypes.union{
    TestUnion3 = {Test.Days,
      { 'MON', 
        name = { Test.Name } },
      { 'TUE', 
        address = { Test.Address } },
      { nil, -- default
         x = { xtypes.double } },    
      xtypes.Extensibility{'EXTENSIBLE_EXTENSIBILITY',domain=5},
    }
  }
  self:print(Test.TestUnion3)

  -- discriminator
  assert(Test.TestUnion3._d == '#')
  
  -- name
  assert(Test.TestUnion3.name.first == 'name.first')
  assert(Test.TestUnion3.name.nicknames() == 'name.nicknames#')  
  assert(Test.TestUnion3.name.nicknames[1] == 'name.nicknames[1]')

  -- address
  assert(Test.TestUnion3.address.name.first == 'address.name.first')
  assert(Test.TestUnion3.address.name.nicknames() == 'address.name.nicknames#')  
  assert(Test.TestUnion3.address.name.nicknames[1] == 'address.name.nicknames[1]')

  -- x
  assert(Test.TestUnion3.x == 'x')
  
  -- annotation
  assert(Test.TestUnion3[xtypes.QUALIFIERS][1] ~= nil)
end

Tester[#Tester+1] = 'test_union4'
function Tester:test_union4()

  Test.NameOrAddress = xtypes.union{
    NameOrAddress = {xtypes.boolean,
      { true, 
         name = { Test.Name } },
      { false, 
         address =  { Test.Address } },
    }
  }
  self:print(Test.NameOrAddress)

  -- discriminator
  assert(Test.NameOrAddress._d == '#')
  
  -- name
  assert(Test.NameOrAddress.name.first == 'name.first')
  assert(Test.NameOrAddress.name.nicknames() == 'name.nicknames#')  
  assert(Test.NameOrAddress.name.nicknames[1] == 'name.nicknames[1]')

  -- address
  assert(Test.NameOrAddress.address.name.first == 'address.name.first')
  assert(Test.NameOrAddress.address.name.nicknames() == 'address.name.nicknames#')  
  assert(Test.NameOrAddress.address.name.nicknames[1] == 'address.name.nicknames[1]')
end

Tester[#Tester+1] = 'test_struct_complex1'
function Tester:test_struct_complex1()

  Test.Company = xtypes.struct{
    Company = {
      { entity = { Test.NameOrAddress } },
      { hq = { xtypes.string(), xtypes.sequence(2) } },
      { offices = { Test.Address, xtypes.sequence(10) } },
      { employees = { Test.Name, xtypes.sequence() } }
    }
  }
  self:print(Test.Company)
  
  -- entity
  assert(Test.Company.entity._d == 'entity#')
  print(Test.Company.entity, Test.Company.entity.name, Test.Company.entity.name.first)
  print(Test.Company.entity.address, Test.Company.entity.address.name, Test.Company.entity.address.name.first)
  assert(Test.Company.entity.name.first == 'entity.name.first')
  assert(Test.Company.entity.name.nicknames() == 'entity.name.nicknames#')  
  assert(Test.Company.entity.name.nicknames[1] == 'entity.name.nicknames[1]')
  assert(Test.Company.entity.address.name.first == 'entity.address.name.first')
  assert(Test.Company.entity.address.name.nicknames() == 'entity.address.name.nicknames#')  
  assert(Test.Company.entity.address.name.nicknames[1] == 'entity.address.name.nicknames[1]')
  
  -- hq
  assert(Test.Company.hq() == 'hq#')
  assert(Test.Company.hq[1] == 'hq[1]')
  
  -- offices
  assert(Test.Company.offices() == 'offices#')
  assert(Test.Company.offices[1].name.first == 'offices[1].name.first')
  assert(Test.Company.offices[1].name.nicknames() == 'offices[1].name.nicknames#')  
  assert(Test.Company.offices[1].name.nicknames[1] == 'offices[1].name.nicknames[1]')

  -- employees
  assert(Test.Company.employees() == 'employees#')
  assert(Test.Company.employees[1].first == 'employees[1].first')
  assert(Test.Company.employees[1].nicknames() == 'employees[1].nicknames#')  
  assert(Test.Company.employees[1].nicknames[1] == 'employees[1].nicknames[1]')
end

Tester[#Tester+1] = 'test_struct_complex2'
function Tester:test_struct_complex2()

  Test.BigCompany = xtypes.struct{
    BigCompany = {
      { parent = { Test.Company } },
      { divisions = { Test.Company, xtypes.sequence() } }
    }
  }
  self:print(Test.BigCompany)
 
  -- parent.entity
  assert(Test.BigCompany.parent.entity._d == 'parent.entity#')
  assert(Test.BigCompany.parent.entity.name.first == 'parent.entity.name.first')
  assert(Test.BigCompany.parent.entity.name.nicknames() == 'parent.entity.name.nicknames#')  
  assert(Test.BigCompany.parent.entity.name.nicknames[1] == 'parent.entity.name.nicknames[1]')
  assert(Test.BigCompany.parent.entity.address.name.first == 'parent.entity.address.name.first')
  assert(Test.BigCompany.parent.entity.address.name.nicknames() == 'parent.entity.address.name.nicknames#')  
  assert(Test.BigCompany.parent.entity.address.name.nicknames[1] == 'parent.entity.address.name.nicknames[1]')
  
  -- parent.hq
  assert(Test.BigCompany.parent.hq() == 'parent.hq#')
  assert(Test.BigCompany.parent.hq[1] == 'parent.hq[1]')
  
  -- parent.offices
  assert(Test.BigCompany.parent.offices() == 'parent.offices#')
  assert(Test.BigCompany.parent.offices[1].name.first == 'parent.offices[1].name.first')
  assert(Test.BigCompany.parent.offices[1].name.nicknames() == 'parent.offices[1].name.nicknames#')  
  assert(Test.BigCompany.parent.offices[1].name.nicknames[1] == 'parent.offices[1].name.nicknames[1]')

  -- parent.employees
  assert(Test.BigCompany.parent.employees() == 'parent.employees#')
  assert(Test.BigCompany.parent.employees[1].first == 'parent.employees[1].first')
  assert(Test.BigCompany.parent.employees[1].nicknames() == 'parent.employees[1].nicknames#')  
  assert(Test.BigCompany.parent.employees[1].nicknames[1] == 'parent.employees[1].nicknames[1]')


  -- divisions
  assert(Test.BigCompany.divisions() == 'divisions#')
  assert(Test.BigCompany.divisions[1].entity._d == 'divisions[1].entity#')
  assert(Test.BigCompany.divisions[1].entity.name.first == 'divisions[1].entity.name.first')
  assert(Test.BigCompany.divisions[1].entity.name.nicknames() == 'divisions[1].entity.name.nicknames#')  
  assert(Test.BigCompany.divisions[1].entity.name.nicknames[1] == 'divisions[1].entity.name.nicknames[1]')
  assert(Test.BigCompany.divisions[1].entity.address.name.first == 'divisions[1].entity.address.name.first')
  assert(Test.BigCompany.divisions[1].entity.address.name.nicknames() == 'divisions[1].entity.address.name.nicknames#')  
  assert(Test.BigCompany.divisions[1].entity.address.name.nicknames[1] == 'divisions[1].entity.address.name.nicknames[1]')
  
  -- divisions[1].hq
  assert(Test.BigCompany.divisions[1].hq() == 'divisions[1].hq#')
  assert(Test.BigCompany.divisions[1].hq[1] == 'divisions[1].hq[1]')
  
  -- divisions[1].offices
  assert(Test.BigCompany.divisions[1].offices() == 'divisions[1].offices#')
  assert(Test.BigCompany.divisions[1].offices[1].name.first == 'divisions[1].offices[1].name.first')
  assert(Test.BigCompany.divisions[1].offices[1].name.nicknames() == 'divisions[1].offices[1].name.nicknames#')  
  assert(Test.BigCompany.divisions[1].offices[1].name.nicknames[1] == 'divisions[1].offices[1].name.nicknames[1]')

  -- divisions[1].employees
  assert(Test.BigCompany.divisions[1].employees() == 'divisions[1].employees#')
  assert(Test.BigCompany.divisions[1].employees[1].first == 'divisions[1].employees[1].first')
  assert(Test.BigCompany.divisions[1].employees[1].nicknames() == 'divisions[1].employees[1].nicknames#')  
  assert(Test.BigCompany.divisions[1].employees[1].nicknames[1] == 'divisions[1].employees[1].nicknames[1]')

end

Tester[#Tester+1] = 'test_struct_inheritance1'
function Tester:test_struct_inheritance1()

  Test.FullName = xtypes.struct{
    FullName = {Test.Name,
      { middle = { xtypes.string() } },
      xtypes.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
    }
  }
  self:print(Test.FullName)
  
  -- base: Name
  assert(Test.FullName.first == 'first')
  assert(Test.FullName.last == 'last')
  assert(Test.FullName.nicknames() == 'nicknames#')
  assert(Test.FullName.nicknames[1] == 'nicknames[1]')
  assert(Test.FullName.aliases() == 'aliases#')
  assert(Test.FullName.aliases[1] == 'aliases[1]')
  assert(Test.FullName.birthday == 'birthday')
  assert(Test.FullName.favorite() == 'favorite#')
  assert(Test.FullName.favorite[1] == 'favorite[1]')
  
  -- FullName
  assert(Test.FullName.middle == 'middle')
end

Tester[#Tester+1] = 'test_struct_inheritance2'
function Tester:test_struct_inheritance2()

  Test.Contact = xtypes.struct{
    Contact = {Test.FullName,
      { address = { Test.Address } },
      { email = { xtypes.string() } },
    }
  }
  self:print(Test.Contact)

  -- base: FullName
  assert(Test.Contact.first == 'first')
  assert(Test.Contact.last == 'last')
  assert(Test.Contact.nicknames() == 'nicknames#')
  assert(Test.Contact.nicknames[1] == 'nicknames[1]')
  assert(Test.Contact.aliases() == 'aliases#')
  assert(Test.Contact.aliases[1] == 'aliases[1]')
  assert(Test.Contact.birthday == 'birthday')
  assert(Test.Contact.favorite() == 'favorite#')
  assert(Test.Contact.favorite[1] == 'favorite[1]')
  assert(Test.Contact.middle == 'middle')
  
  -- Contact
  assert(Test.Contact.address.name.first == 'address.name.first')
  assert(Test.Contact.address.name.first == 'address.name.first')
  assert(Test.Contact.address.name.nicknames() == 'address.name.nicknames#')
  assert(Test.Contact.address.name.nicknames[1] == 'address.name.nicknames[1]')
  assert(Test.Contact.address.street == 'address.street')
  assert(Test.Contact.address.city == 'address.city')
    
  assert(Test.Contact.email == 'email')
end

Tester[#Tester+1] = 'test_struct_inheritance3'
function Tester:test_struct_inheritance3()

  Test.Tasks = xtypes.struct{
    Tasks = {
      { contact = { Test.Contact } },
      { day = { Test.Days } },
    }
  }
  self:print(Test.Tasks)

  -- Tasks.contact
  assert(Test.Tasks.contact.first == 'contact.first')
  assert(Test.Tasks.contact.last == 'contact.last')
  assert(Test.Tasks.contact.nicknames() == 'contact.nicknames#')
  assert(Test.Tasks.contact.nicknames[1] == 'contact.nicknames[1]')
  assert(Test.Tasks.contact.aliases() == 'contact.aliases#')
  assert(Test.Tasks.contact.aliases[1] == 'contact.aliases[1]')
  assert(Test.Tasks.contact.birthday == 'contact.birthday')
  assert(Test.Tasks.contact.favorite() == 'contact.favorite#')
  assert(Test.Tasks.contact.favorite[1] == 'contact.favorite[1]')
  assert(Test.Tasks.contact.middle == 'contact.middle')
  
  -- Tasks.contact.address
  assert(Test.Tasks.contact.address.name.first == 'contact.address.name.first')
  assert(Test.Tasks.contact.address.name.first == 'contact.address.name.first')
  assert(Test.Tasks.contact.address.name.nicknames() == 'contact.address.name.nicknames#')
  assert(Test.Tasks.contact.address.name.nicknames[1] == 'contact.address.name.nicknames[1]')
  assert(Test.Tasks.contact.address.street == 'contact.address.street')
  assert(Test.Tasks.contact.address.city == 'contact.address.city')
    
  assert(Test.Tasks.contact.email == 'contact.email')
  
  assert(Test.Tasks.day == 'day')
end

Tester[#Tester+1] = 'test_struct_inheritance4'
function Tester:test_struct_inheritance4()

  Test.Calendar = xtypes.struct{
    Calendar = {
      { tasks = { Test.Tasks, xtypes.sequence() } },
    }
  }
  self:print(Test.Calendar)
  
  assert(Test.Calendar.tasks() == 'tasks#')
   
  -- tasks[1].contact
  assert(Test.Calendar.tasks[1].contact.first == 'tasks[1].contact.first')
  assert(Test.Calendar.tasks[1].contact.last == 'tasks[1].contact.last')
  assert(Test.Calendar.tasks[1].contact.nicknames() == 'tasks[1].contact.nicknames#')
  assert(Test.Calendar.tasks[1].contact.nicknames[1] == 'tasks[1].contact.nicknames[1]')
  assert(Test.Calendar.tasks[1].contact.aliases() == 'tasks[1].contact.aliases#')
  assert(Test.Calendar.tasks[1].contact.aliases[1] == 'tasks[1].contact.aliases[1]')
  assert(Test.Calendar.tasks[1].contact.birthday == 'tasks[1].contact.birthday')
  assert(Test.Calendar.tasks[1].contact.favorite() == 'tasks[1].contact.favorite#')
  assert(Test.Calendar.tasks[1].contact.favorite[1] == 'tasks[1].contact.favorite[1]')
  assert(Test.Calendar.tasks[1].contact.middle == 'tasks[1].contact.middle')
  
  -- tasks[1].contact.address
  assert(Test.Calendar.tasks[1].contact.address.name.first == 'tasks[1].contact.address.name.first')
  assert(Test.Calendar.tasks[1].contact.address.name.first == 'tasks[1].contact.address.name.first')
  assert(Test.Calendar.tasks[1].contact.address.name.nicknames() == 'tasks[1].contact.address.name.nicknames#')
  assert(Test.Calendar.tasks[1].contact.address.name.nicknames[1] == 'tasks[1].contact.address.name.nicknames[1]')
  assert(Test.Calendar.tasks[1].contact.address.street == 'tasks[1].contact.address.street')
  assert(Test.Calendar.tasks[1].contact.address.city == 'tasks[1].contact.address.city')
    
  assert(Test.Calendar.tasks[1].contact.email == 'tasks[1].contact.email')
  
  assert(Test.Calendar.tasks[1].day == 'tasks[1].day')
end

Tester[#Tester+1] = 'test_struct_recursive'
function Tester:test_struct_recursive()

    -- NOTE: Forward data declarations are not allowed in IDL
    --       still, this is just a test to see how it might work
    
    Test.RecursiveStruct = xtypes.struct{RecursiveStruct=xtypes.EMPTY} -- fwd decl
    local RecursiveStruct = xtypes.struct{
      RecursiveStruct = { -- note: won't get installed as a defn
        { x = { xtypes.long } },
        { y = { xtypes.long } },
        { child = { Test.RecursiveStruct } },
      }
    }
    Test.RecursiveStruct = nil -- erase from module
    Test.RecursiveStruct = RecursiveStruct -- reinstall it
    
    self:print(Test.RecursiveStruct)
    
    assert('x' == Test.RecursiveStruct.x)
    assert('y' == Test.RecursiveStruct.y)
    
    -- assert('child.x' == Test.RecursiveStruct.child.x)
end

Tester[#Tester+1] = 'test_atoms'
function Tester:test_atoms()

    Test.Atoms = xtypes.struct{
      Atoms = {
        { myBoolean = { xtypes.boolean } },
        { myOctet = { xtypes.octet } },
        { myChar = { xtypes.char } },
        { myWChar = { xtypes.wchar } },
        { myFloat = { xtypes.float } },
        { myDouble = { xtypes.double } },
        { myLongDouble = { xtypes.long_double } },
        { myShort = { xtypes.short } },
        { myLong = { xtypes.long } },
        { myLongLong = { xtypes.long_long } },
        { myUnsignedShort = { xtypes.unsigned_short } },
        { myUnsignedLong = { xtypes.unsigned_long } },
        { myUnsignedLongLong = { xtypes.unsigned_long_long } },
      }
    }
    self:print(Test.Atoms)
    
    assert(Test.Atoms.myBoolean == 'myBoolean')
    for k, v in pairs(Test.Atoms) do
        if 'string' == type(k) then assert(k == v) end
    end
end

Tester[#Tester+1] = 'test_typedef'
function Tester:test_typedef()  

  -- typedefs
  Test.MyDouble = xtypes.typedef{MyDouble = { xtypes.double} }
  Test.MyDouble2 = xtypes.typedef{MyDouble2 = { Test.MyDouble } }
  Test.MyString = xtypes.typedef{MyString = { xtypes.string(10) } }
  
  Test.MyName = xtypes.typedef{MyName = { Test.Name } }
  Test.MyName2 = xtypes.typedef{MyName2 = { Test.MyName} }
  
  Test.MyAddress = xtypes.typedef{MyAddress = { Test.Address } }
  Test.MyAddress2 = xtypes.typedef{MyAddress2 = { Test.MyAddress } }
  
  Test.MyTypedef = xtypes.struct{
    MyTypedef = {
      { rawDouble =  { xtypes.double } },
      { myDouble =  { Test.MyDouble } },
      { myDouble2 =  { Test.MyDouble2 } },
      
      { name =  { Test.Name } },
      { myName =  { Test.MyName } },
      { myName2 =  { Test.MyName2 } },
      
      { address =  { Test.Address } },
      { myAddress =  { Test.MyAddress } },
      { myAddress2 =  { Test.MyAddress2 } },
    }
  }
  self:print(Test.MyDouble)
  self:print(Test.MyDouble2)  
  self:print(Test.MyString)
        
  self:print(Test.MyName)
  self:print(Test.MyName2)
  
  self:print(Test.MyAddress)
  self:print(Test.MyAddress2)
  
  self:print(Test.MyTypedef)
  
  -- rawDouble
  assert(Test.MyTypedef.rawDouble == 'rawDouble')
  assert(Test.MyTypedef.myDouble == 'myDouble')
  assert(Test.MyTypedef.myDouble2 == 'myDouble2')
  -- name
  assert(Test.MyTypedef.name.first == 'name.first')
  assert(Test.MyTypedef.name.nicknames() == 'name.nicknames#')  
  assert(Test.MyTypedef.name.nicknames[1] == 'name.nicknames[1]')
  -- myName
  assert(Test.MyTypedef.myName.first == 'myName.first')
  assert(Test.MyTypedef.myName.nicknames() == 'myName.nicknames#')  
  assert(Test.MyTypedef.myName.nicknames[1] == 'myName.nicknames[1]')
  -- myAddress2
  assert(Test.MyTypedef.myAddress2.name.first == 'myAddress2.name.first')
  assert(Test.MyTypedef.myAddress2.name.nicknames() == 'myAddress2.name.nicknames#')  
  assert(Test.MyTypedef.myAddress2.name.nicknames[1] == 'myAddress2.name.nicknames[1]')
end

Tester[#Tester+1] = 'test_resolve'
function Tester:test_resolve()  
 
  local MyBooleanTypedef = xtypes.typedef{
    MyBooleanTypedef = { xtypes.boolean }
  }
  local MyBooleanTypedef2 = xtypes.typedef{
    MyBooleanTypedef2 = { MyBooleanTypedef }
  }
  local MyBooleanSeq = xtypes.typedef{
    MyBooleanSeq = { MyBooleanTypedef2, xtypes.sequence(3) }
  }
  
  assert(xtypes.utils.resolve(nil) == nil)
  assert(xtypes.utils.resolve(xtypes.boolean) == xtypes.boolean)
  assert(xtypes.utils.resolve(MyBooleanSeq) == xtypes.boolean)
  print('resolve(MyBooleanSeq) = ', xtypes.utils.resolve(MyBooleanSeq))
end

Tester[#Tester+1] = 'test_typedef_seq'
function Tester:test_typedef_seq()  

  Test.MyDoubleSeq = xtypes.typedef{
    MyDoubleSeq = {Test.MyDouble, xtypes.sequence() }}
  Test.MyStringSeq = xtypes.typedef{
    MyStringSeq = {Test.MyString, xtypes.sequence(10) }}
  
  Test.NameSeq = xtypes.typedef{
    NameSeq = {Test.Name, xtypes.sequence(10) } }
  Test.NameSeqSeq = xtypes.typedef{
    NameSeqSeq = {Test.NameSeq, xtypes.sequence(10) }}
  
  Test.MyNameSeq = xtypes.typedef{
    MyNameSeq = {Test.MyName, xtypes.sequence(10) }}
  Test.MyNameSeqSeq = xtypes.typedef{
    MyNameSeqSeq = {Test.MyNameSeq, xtypes.sequence(10) }}
  
  Test.MyTypedefSeq = xtypes.struct{
    MyTypedefSeq = {
      { myDoubleSeq = { Test.MyDouble, xtypes.sequence() } },
      { myDoubleSeqA = { Test.MyDoubleSeq } },
      { myStringSeqA = { Test.MyStringSeq } },
      
      { nameSeq = { Test.Name, xtypes.sequence() } },
      { nameSeqA = { Test.NameSeq } },
      { nameSeqSeq = { Test.NameSeq, xtypes.sequence() } },
      { nameSeqSeqA = { Test.NameSeqSeq } },
      { nameSeqSeqASeq = { Test.NameSeqSeq, xtypes.sequence() } },
    
      { myNameSeq = { Test.MyName, xtypes.sequence() } },
      { myNameSeqA = { Test.MyNameSeq } },
      { myNameSeqSeq = { Test.MyNameSeq, xtypes.sequence() } },
      { myNameSeqSeqA = { Test.MyNameSeqSeq } },
      { myNameSeqSeqASeq = { Test.MyNameSeqSeq, xtypes.sequence() } },
    }
  }
  self:print(Test.MyDoubleSeq)
  self:print(Test.MyStringSeq)
  
  self:print(Test.NameSeq)
  self:print(Test.NameSeqSeq)

  self:print(Test.MyNameSeq)
  self:print(Test.MyNameSeqSeq)
  
  self:print(Test.MyTypedefSeq)
  
  -- nameSeq
  assert(Test.MyTypedefSeq.nameSeq() == 'nameSeq#')
  assert(Test.MyTypedefSeq.nameSeq[1].first == 'nameSeq[1].first')  
  assert(Test.MyTypedefSeq.nameSeq[1].nicknames() == 'nameSeq[1].nicknames#') 
  assert(Test.MyTypedefSeq.nameSeq[1].nicknames[1] == 'nameSeq[1].nicknames[1]')  

  -- nameSeqA
  assert(Test.MyTypedefSeq.nameSeqA() == 'nameSeqA#')
  assert(Test.MyTypedefSeq.nameSeqA[1].first == 'nameSeqA[1].first')  
  assert(Test.MyTypedefSeq.nameSeqA[1].nicknames() == 'nameSeqA[1].nicknames#') 
  assert(Test.MyTypedefSeq.nameSeqA[1].nicknames[1] == 'nameSeqA[1].nicknames[1]')  

  -- nameSeqSeq
  assert(Test.MyTypedefSeq.nameSeqSeq() == 'nameSeqSeq#') 
  assert(Test.MyTypedefSeq.nameSeqSeq[1]() == 'nameSeqSeq[1]#')
  assert(Test.MyTypedefSeq.nameSeqSeq[1][1].first == 'nameSeqSeq[1][1].first')
  assert(Test.MyTypedefSeq.nameSeqSeq[1][1].nicknames() == 'nameSeqSeq[1][1].nicknames#')
  assert(Test.MyTypedefSeq.nameSeqSeq[1][1].nicknames[1] == 'nameSeqSeq[1][1].nicknames[1]')
  
  -- nameSeqSeqA
  assert(Test.MyTypedefSeq.nameSeqSeqA() == 'nameSeqSeqA#') 
  assert(Test.MyTypedefSeq.nameSeqSeqA[1]() == 'nameSeqSeqA[1]#')
  assert(Test.MyTypedefSeq.nameSeqSeqA[1][1].first == 'nameSeqSeqA[1][1].first')
  assert(Test.MyTypedefSeq.nameSeqSeqA[1][1].nicknames() == 'nameSeqSeqA[1][1].nicknames#')
  assert(Test.MyTypedefSeq.nameSeqSeqA[1][1].nicknames[1] == 'nameSeqSeqA[1][1].nicknames[1]')

  -- nameSeqSeqASeq
  assert(Test.MyTypedefSeq.nameSeqSeqASeq() == 'nameSeqSeqASeq#') 
  assert(Test.MyTypedefSeq.nameSeqSeqASeq[1]() == 'nameSeqSeqASeq[1]#')
  assert(Test.MyTypedefSeq.nameSeqSeqASeq[1][1]() == 'nameSeqSeqASeq[1][1]#')
  assert(Test.MyTypedefSeq.nameSeqSeqASeq[1][1][1].first == 'nameSeqSeqASeq[1][1][1].first')
  assert(Test.MyTypedefSeq.nameSeqSeqASeq[1][1][1].nicknames() == 'nameSeqSeqASeq[1][1][1].nicknames#')
  assert(Test.MyTypedefSeq.nameSeqSeqASeq[1][1][1].nicknames[1] == 'nameSeqSeqASeq[1][1][1].nicknames[1]')

  -- myNameSeq
  assert(Test.MyTypedefSeq.myNameSeq() == 'myNameSeq#')
  assert(Test.MyTypedefSeq.myNameSeq[1].first == 'myNameSeq[1].first')  
  assert(Test.MyTypedefSeq.myNameSeq[1].nicknames() == 'myNameSeq[1].nicknames#') 
  assert(Test.MyTypedefSeq.myNameSeq[1].nicknames[1] == 'myNameSeq[1].nicknames[1]')  

  -- myNameSeqA
  assert(Test.MyTypedefSeq.myNameSeqA() == 'myNameSeqA#')
  assert(Test.MyTypedefSeq.myNameSeqA[1].first == 'myNameSeqA[1].first')  
  assert(Test.MyTypedefSeq.myNameSeqA[1].nicknames() == 'myNameSeqA[1].nicknames#') 
  assert(Test.MyTypedefSeq.myNameSeqA[1].nicknames[1] == 'myNameSeqA[1].nicknames[1]')  

  -- myNameSeqSeq
  assert(Test.MyTypedefSeq.myNameSeqSeq() == 'myNameSeqSeq#') 
  assert(Test.MyTypedefSeq.myNameSeqSeq[1]() == 'myNameSeqSeq[1]#')
  assert(Test.MyTypedefSeq.myNameSeqSeq[1][1].first == 'myNameSeqSeq[1][1].first')
  assert(Test.MyTypedefSeq.myNameSeqSeq[1][1].nicknames() == 'myNameSeqSeq[1][1].nicknames#')
  assert(Test.MyTypedefSeq.myNameSeqSeq[1][1].nicknames[1] == 'myNameSeqSeq[1][1].nicknames[1]')
  
  -- myNameSeqSeqA
  assert(Test.MyTypedefSeq.myNameSeqSeqA() == 'myNameSeqSeqA#') 
  assert(Test.MyTypedefSeq.myNameSeqSeqA[1]() == 'myNameSeqSeqA[1]#')
  assert(Test.MyTypedefSeq.myNameSeqSeqA[1][1].first == 'myNameSeqSeqA[1][1].first')
  assert(Test.MyTypedefSeq.myNameSeqSeqA[1][1].nicknames() == 'myNameSeqSeqA[1][1].nicknames#')
  assert(Test.MyTypedefSeq.myNameSeqSeqA[1][1].nicknames[1] == 'myNameSeqSeqA[1][1].nicknames[1]')

  -- myNameSeqSeqASeq
  assert(Test.MyTypedefSeq.myNameSeqSeqASeq() == 'myNameSeqSeqASeq#') 
  assert(Test.MyTypedefSeq.myNameSeqSeqASeq[1]() == 'myNameSeqSeqASeq[1]#')
  assert(Test.MyTypedefSeq.myNameSeqSeqASeq[1][1]() == 'myNameSeqSeqASeq[1][1]#')
  assert(Test.MyTypedefSeq.myNameSeqSeqASeq[1][1][1].first == 'myNameSeqSeqASeq[1][1][1].first')
  assert(Test.MyTypedefSeq.myNameSeqSeqASeq[1][1][1].nicknames() == 'myNameSeqSeqASeq[1][1][1].nicknames#')
  assert(Test.MyTypedefSeq.myNameSeqSeqASeq[1][1][1].nicknames[1] == 'myNameSeqSeqASeq[1][1][1].nicknames[1]')
end

Tester[#Tester+1] = 'test_arrays1'
function Tester:test_arrays1()

    -- Arrays
    Test.MyArrays1 = xtypes.struct{
      MyArrays1 = {
        -- 1-D
        { ints = { xtypes.double, xtypes.array(3) } },
      
        -- 2-D
        { days = { Test.Days, xtypes.array(6, 9) } },
        
        -- 3-D
        { names = { Test.Name, xtypes.array(12, 15, 18) } },
      }
  }
	-- structure with arrays
	self:print(Test.MyArrays1)
	
	-- ints
	assert(Test.MyArrays1.ints() == 'ints#')
	assert(Test.MyArrays1.ints[1] == 'ints[1]')
	
	-- days
	assert(Test.MyArrays1.days() == 'days#')
	assert(Test.MyArrays1.days[1]() == 'days[1]#')
	assert(Test.MyArrays1.days[1][1] == 'days[1][1]')
	
	-- names
	assert(Test.MyArrays1.names() == 'names#')
	assert(Test.MyArrays1.names[1]() == 'names[1]#')
	assert(Test.MyArrays1.names[1][1]() == 'names[1][1]#')
	assert(Test.MyArrays1.names[1][1][1].first == 'names[1][1][1].first')
	assert(Test.MyArrays1.names[1][1][1].nicknames() == 'names[1][1][1].nicknames#')
	assert(Test.MyArrays1.names[1][1][1].nicknames[1] == 'names[1][1][1].nicknames[1]')
end

Tester[#Tester+1] = 'test_arrays2'
function Tester:test_arrays2()

    Test.MyArrays2 = xtypes.union{
      MyArrays2 = {Test.Days,
        -- 1-D
        { 'MON',
          ints = { xtypes.double, xtypes.array(3) }},
      
        -- 2-D
        { 'TUE',
          days = { Test.Days, xtypes.array(6, 9) }},
        
        -- 3-D
        {nil,
          names = { Test.Name, xtypes.array(12, 15, 18) }},  
      }
  }
	-- union with arrays
	self:print(Test.MyArrays2)
	
	-- ints
	assert(Test.MyArrays2.ints() == 'ints#')
	assert(Test.MyArrays2.ints[1] == 'ints[1]')
	
	-- days
	assert(Test.MyArrays2.days() == 'days#')
	assert(Test.MyArrays2.days[1]() == 'days[1]#')
	assert(Test.MyArrays2.days[1][1] == 'days[1][1]')
	
	-- names
	assert(Test.MyArrays2.names() == 'names#')
	assert(Test.MyArrays2.names[1]() == 'names[1]#')
	assert(Test.MyArrays2.names[1][1]() == 'names[1][1]#')
	assert(Test.MyArrays2.names[1][1][1].first == 'names[1][1][1].first')
	assert(Test.MyArrays2.names[1][1][1].nicknames() == 'names[1][1][1].nicknames#')
	assert(Test.MyArrays2.names[1][1][1].nicknames[1] == 'names[1][1][1].nicknames[1]')
end

Tester[#Tester+1] = 'test_arrays3'
function Tester:test_arrays3()
	Test.MyNameArray = xtypes.typedef{
	   MyNameArray = { Test.Name, xtypes.array(10) }
	}
	Test.MyNameArray2 = xtypes.typedef{
	   MyNameArray2 = {Test.MyNameArray, xtypes.array(10) }
	}
	Test.MyName2x2 = xtypes.typedef{
	   MyName2x2 = {Test.Name, xtypes.array(2, 3) }
	}
	
	Test.MyArrays3 = xtypes.struct{
	 MyArrays3 = {
  		-- 1-D
  		{ myNames = { Test.MyNameArray } },
  
  		-- 2-D
  		{ myNamesArray = { Test.MyNameArray, xtypes.array(10) } },
  	
  		-- 2-D
  		{ myNames2 = { Test.MyNameArray2 } },
  				
  		-- 3-D
  		{ myNames2Array = { Test.MyNameArray2, xtypes.array(10) } },
  
  		-- 4-D
  		{ myNames2Array2 = { Test.MyNameArray2, xtypes.array(10, 20) } },
  		
  		-- 2D: 2x2
  		{ myName2x2 = { Test.MyName2x2 } },
  
  		-- 4D: 2x2 x2x2
  		{ myName2x2x2x2 = { Test.MyName2x2, xtypes.array(4,5) } },
  	}
  }
  self:print(Test.MyNameArray)
  self:print(Test.MyNameArray2)
  self:print(Test.MyName2x2)
	self:print(Test.MyArrays3)

	-- myNames
	assert(Test.MyArrays3.myNames() == 'myNames#')
	assert(Test.MyArrays3.myNames[1].first == 'myNames[1].first')
	assert(Test.MyArrays3.myNames[1].nicknames() == 'myNames[1].nicknames#')
	assert(Test.MyArrays3.myNames[1].nicknames[1] == 'myNames[1].nicknames[1]')
	
	-- myNamesArray
	assert(Test.MyArrays3.myNamesArray() == 'myNamesArray#')
	assert(Test.MyArrays3.myNamesArray[1]() == 'myNamesArray[1]#')
	assert(Test.MyArrays3.myNamesArray[1][1].first == 'myNamesArray[1][1].first')
	assert(Test.MyArrays3.myNamesArray[1][1].nicknames() == 'myNamesArray[1][1].nicknames#')
	assert(Test.MyArrays3.myNamesArray[1][1].nicknames[1] == 'myNamesArray[1][1].nicknames[1]')
	
	-- myNames2
	assert(Test.MyArrays3.myNames2() == 'myNames2#')
	assert(Test.MyArrays3.myNames2[1]() == 'myNames2[1]#')
	assert(Test.MyArrays3.myNames2[1][1].first == 'myNames2[1][1].first')
	assert(Test.MyArrays3.myNames2[1][1].nicknames() == 'myNames2[1][1].nicknames#')
	assert(Test.MyArrays3.myNames2[1][1].nicknames[1] == 'myNames2[1][1].nicknames[1]')

	-- myNames2Array
	assert(Test.MyArrays3.myNames2Array() == 'myNames2Array#')
	assert(Test.MyArrays3.myNames2Array[1]() == 'myNames2Array[1]#')
	assert(Test.MyArrays3.myNames2Array[1][1]() == 'myNames2Array[1][1]#')
	assert(Test.MyArrays3.myNames2Array[1][1][1].first == 'myNames2Array[1][1][1].first')
	assert(Test.MyArrays3.myNames2Array[1][1][1].nicknames() == 'myNames2Array[1][1][1].nicknames#')
	assert(Test.MyArrays3.myNames2Array[1][1][1].nicknames[1] == 'myNames2Array[1][1][1].nicknames[1]')

	-- myNames2Array2
	assert(Test.MyArrays3.myNames2Array2() == 'myNames2Array2#')
	assert(Test.MyArrays3.myNames2Array2[1]() == 'myNames2Array2[1]#')
	assert(Test.MyArrays3.myNames2Array2[1][1]() == 'myNames2Array2[1][1]#')
	assert(Test.MyArrays3.myNames2Array2[1][1][1]() == 'myNames2Array2[1][1][1]#')
	assert(Test.MyArrays3.myNames2Array2[1][1][1][1].first == 'myNames2Array2[1][1][1][1].first')
	assert(Test.MyArrays3.myNames2Array2[1][1][1][1].nicknames() == 'myNames2Array2[1][1][1][1].nicknames#')
	assert(Test.MyArrays3.myNames2Array2[1][1][1][1].nicknames[1] == 'myNames2Array2[1][1][1][1].nicknames[1]')

	-- myName2x2
	assert(Test.MyArrays3.myName2x2() == 'myName2x2#')
	assert(Test.MyArrays3.myName2x2[1]() == 'myName2x2[1]#')
	assert(Test.MyArrays3.myName2x2[1][1].first == 'myName2x2[1][1].first')
	assert(Test.MyArrays3.myName2x2[1][1].nicknames() == 'myName2x2[1][1].nicknames#')
	assert(Test.MyArrays3.myName2x2[1][1].nicknames[1] == 'myName2x2[1][1].nicknames[1]')

	-- myName2x2x2x2
	assert(Test.MyArrays3.myName2x2x2x2() == 'myName2x2x2x2#')
	assert(Test.MyArrays3.myName2x2x2x2[1]() == 'myName2x2x2x2[1]#')
	assert(Test.MyArrays3.myName2x2x2x2[1][1]() == 'myName2x2x2x2[1][1]#')
	assert(Test.MyArrays3.myName2x2x2x2[1][1][1]() == 'myName2x2x2x2[1][1][1]#')
	assert(Test.MyArrays3.myName2x2x2x2[1][1][1][1].first == 'myName2x2x2x2[1][1][1][1].first')
	assert(Test.MyArrays3.myName2x2x2x2[1][1][1][1].nicknames() == 'myName2x2x2x2[1][1][1][1].nicknames#')
	assert(Test.MyArrays3.myName2x2x2x2[1][1][1][1].nicknames[1] == 'myName2x2x2x2[1][1][1][1].nicknames[1]')
end

Tester[#Tester+1] = 'test_sequences_multi_dim'
function Tester:test_sequences_multi_dim()
	Test.MyNameSeq1 = xtypes.typedef{
	   MyNameSeq1 = {Test.Name, xtypes.sequence(10) }
	}
	Test.MyNameSeq2 = xtypes.typedef{
	   MyNameSeq2 = {Test.MyNameSeq, xtypes.sequence(10) }
	}
	Test.MyNameSeq2x2 = xtypes.typedef{
	   MyNameSeq2x2 = {Test.Name, xtypes.sequence(2, 3) }
	}
	
	Test.MySeqs3 = xtypes.struct{
	 MySeqs3 = {
  		-- 1-D
  		{ myNames = { Test.MyNameSeq } },
  
  		-- 2-D
  		{ myNamesSeq = { Test.MyNameSeq1, xtypes.sequence(10) } },
  	
  		-- 2-D
  		{ myNames2 = { Test.MyNameSeq2 } },
  				
  		-- 3-D
  		{ myNames2Seq = { Test.MyNameSeq2, xtypes.sequence(10) } },
  
  		-- 4-D
  		{ myNames2Seq2 = { Test.MyNameSeq2, xtypes.sequence(10, 20) } },
  		
  		-- 2D: 2x2
  		{ myName2x2 = { Test.MyName2x2 } },
  
  		-- 4D: 2x2 x2x2
  		{ myName2x2x2x2 = { Test.MyNameSeq2x2, xtypes.sequence(4,5) } },
  	}
  }
  self:print(Test.MyNameSeq1)
  self:print(Test.MyNameSeq2)
  self:print(Test.MySeqs3)
	self:print(Test.MyNameSeq2x2)

	-- myNames
	assert(Test.MySeqs3.myNames() == 'myNames#')
	assert(Test.MySeqs3.myNames[1].first == 'myNames[1].first')
	assert(Test.MySeqs3.myNames[1].nicknames() == 'myNames[1].nicknames#')
	assert(Test.MySeqs3.myNames[1].nicknames[1] == 'myNames[1].nicknames[1]')
	
	-- myNamesSeq
	assert(Test.MySeqs3.myNamesSeq() == 'myNamesSeq#')
	assert(Test.MySeqs3.myNamesSeq[1]() == 'myNamesSeq[1]#')
	assert(Test.MySeqs3.myNamesSeq[1][1].first == 'myNamesSeq[1][1].first')
	assert(Test.MySeqs3.myNamesSeq[1][1].nicknames() == 'myNamesSeq[1][1].nicknames#')
	assert(Test.MySeqs3.myNamesSeq[1][1].nicknames[1] == 'myNamesSeq[1][1].nicknames[1]')
	
	-- myNames2
	assert(Test.MySeqs3.myNames2() == 'myNames2#')
	assert(Test.MySeqs3.myNames2[1]() == 'myNames2[1]#')
	assert(Test.MySeqs3.myNames2[1][1].first == 'myNames2[1][1].first')
	assert(Test.MySeqs3.myNames2[1][1].nicknames() == 'myNames2[1][1].nicknames#')
	assert(Test.MySeqs3.myNames2[1][1].nicknames[1] == 'myNames2[1][1].nicknames[1]')

	-- myNames2Seq
	assert(Test.MySeqs3.myNames2Seq() == 'myNames2Seq#')
	assert(Test.MySeqs3.myNames2Seq[1]() == 'myNames2Seq[1]#')
	assert(Test.MySeqs3.myNames2Seq[1][1]() == 'myNames2Seq[1][1]#')
	assert(Test.MySeqs3.myNames2Seq[1][1][1].first == 'myNames2Seq[1][1][1].first')
	assert(Test.MySeqs3.myNames2Seq[1][1][1].nicknames() == 'myNames2Seq[1][1][1].nicknames#')
	assert(Test.MySeqs3.myNames2Seq[1][1][1].nicknames[1] == 'myNames2Seq[1][1][1].nicknames[1]')

	-- myNames2Seq2
	assert(Test.MySeqs3.myNames2Seq2() == 'myNames2Seq2#')
	assert(Test.MySeqs3.myNames2Seq2[1]() == 'myNames2Seq2[1]#')
	assert(Test.MySeqs3.myNames2Seq2[1][1]() == 'myNames2Seq2[1][1]#')
	assert(Test.MySeqs3.myNames2Seq2[1][1][1]() == 'myNames2Seq2[1][1][1]#')
	assert(Test.MySeqs3.myNames2Seq2[1][1][1][1].first == 'myNames2Seq2[1][1][1][1].first')
	assert(Test.MySeqs3.myNames2Seq2[1][1][1][1].nicknames() == 'myNames2Seq2[1][1][1][1].nicknames#')
	assert(Test.MySeqs3.myNames2Seq2[1][1][1][1].nicknames[1] == 'myNames2Seq2[1][1][1][1].nicknames[1]')

	-- myName2x2
	assert(Test.MySeqs3.myName2x2() == 'myName2x2#')
	assert(Test.MySeqs3.myName2x2[1]() == 'myName2x2[1]#')
	assert(Test.MySeqs3.myName2x2[1][1].first == 'myName2x2[1][1].first')
	assert(Test.MySeqs3.myName2x2[1][1].nicknames() == 'myName2x2[1][1].nicknames#')
	assert(Test.MySeqs3.myName2x2[1][1].nicknames[1] == 'myName2x2[1][1].nicknames[1]')

	-- myName2x2x2x2
	assert(Test.MySeqs3.myName2x2x2x2() == 'myName2x2x2x2#')
	assert(Test.MySeqs3.myName2x2x2x2[1]() == 'myName2x2x2x2[1]#')
	assert(Test.MySeqs3.myName2x2x2x2[1][1]() == 'myName2x2x2x2[1][1]#')
	assert(Test.MySeqs3.myName2x2x2x2[1][1][1]() == 'myName2x2x2x2[1][1][1]#')
	assert(Test.MySeqs3.myName2x2x2x2[1][1][1][1].first == 'myName2x2x2x2[1][1][1][1].first')
	assert(Test.MySeqs3.myName2x2x2x2[1][1][1][1].nicknames() == 'myName2x2x2x2[1][1][1][1].nicknames#')
	assert(Test.MySeqs3.myName2x2x2x2[1][1][1][1].nicknames[1] == 'myName2x2x2x2[1][1][1][1].nicknames[1]')
end

Tester[#Tester+1] = 'test_const'
function Tester:test_const()
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

  self:print(Test.FLOAT)
  self:print(Test.DOUBLE)
  self:print(Test.LDOUBLE)
  self:print(Test.STRING)
  self:print(Test.BOOL)
  self:print(Test.CHAR)
  self:print(Test.LONG)
  self:print(Test.LLONG)
  self:print(Test.SHORT)
  self:print(Test.WSTRING)
   
  assert(Test.FLOAT() == 3.14)
  assert(Test.DOUBLE() == 3.14 * 3.14)
  assert(Test.LDOUBLE() == 3.14 * 3.14 * 3.14)
  assert(Test.STRING() == "String Constant")
  assert(Test.BOOL() == true)
  assert(Test.CHAR() == 'S') -- warning printed
  assert(Test.LONG() == 10)  -- warning printed
  assert(Test.LLONG() == 10^10)  
  assert(Test.SHORT() == 5)  
  assert(Test.WSTRING() == "WString Constant")
end

Tester[#Tester+1] = 'test_const_bounds'
function Tester:test_const_bounds()
    local CAPACITY = xtypes.const{
      CAPACITY = { xtypes.short, 5 } 
    }
    Test.MyCapacitySeq = xtypes.typedef{
      MyCapacitySeq = {Test.Name, xtypes.sequence(CAPACITY, CAPACITY) }
    }
    Test.MyCapacityArr = xtypes.typedef{
      MyCapacityArr = {Test.Name, xtypes.array(CAPACITY, CAPACITY) }
    }
    
    Test.MyCapacityStruct = xtypes.struct{
      MyCapacityStruct = { 
          { myNames = { Test.MyCapacitySeq } },
          { myNames2 = { Test.MyCapacityArr } },
          { myStrings = { xtypes.string(), 
                         xtypes.array(CAPACITY, CAPACITY)} },
          { myNums = { xtypes.double, 
                      xtypes.sequence(CAPACITY, CAPACITY)} },
          { myStr = { xtypes.string(CAPACITY) } },                                       
      }
    }                               
    self:print(CAPACITY)
    self:print(Test.MyCapacitySeq)
    self:print(Test.MyCapacityArr)
    self:print(Test.MyCapacityStruct)
    
    assert(CAPACITY() == 5)
    
    -- myNames
    assert(Test.MyCapacityStruct.myNames() == 'myNames#')
    assert(Test.MyCapacityStruct.myNames[1]() == 'myNames[1]#')
    assert(Test.MyCapacityStruct.myNames[1][1].first == 'myNames[1][1].first')
    assert(Test.MyCapacityStruct.myNames[1][1].nicknames() == 'myNames[1][1].nicknames#')
    assert(Test.MyCapacityStruct.myNames[1][1].nicknames[1] == 'myNames[1][1].nicknames[1]')
  
    -- myNames2
    assert(Test.MyCapacityStruct.myNames2() == 'myNames2#')
    assert(Test.MyCapacityStruct.myNames2[1]() == 'myNames2[1]#')
    assert(Test.MyCapacityStruct.myNames2[1][1].first == 'myNames2[1][1].first')
    assert(Test.MyCapacityStruct.myNames2[1][1].nicknames() == 'myNames2[1][1].nicknames#')
    assert(Test.MyCapacityStruct.myNames2[1][1].nicknames[1] == 'myNames2[1][1].nicknames[1]')
   
    -- myStrings
    assert(Test.MyCapacityStruct.myStrings() == 'myStrings#')
    assert(Test.MyCapacityStruct.myStrings[1]() == 'myStrings[1]#')
    assert(Test.MyCapacityStruct.myStrings[1][1] == 'myStrings[1][1]')
    
    -- myStr
    assert(Test.MyCapacityStruct.myStr == 'myStr')
end

Tester[#Tester+1] = 'test_collection_bounds'
function Tester:test_collection_bounds()

  local CAPACITY = xtypes.const{
    CAPACITY = { xtypes.short, 5 } 
  }
  local BoundsTest = xtypes.struct{
    BoundsTest = {
        { long1SeqX  = { xtypes.long, xtypes.sequence(3) } },
        { long2SeqX  = { xtypes.long, xtypes.sequence(CAPACITY) } },
        { long1ArrX  = { xtypes.long, xtypes.array(CAPACITY) } },
        { long2ArrXX = { xtypes.long, xtypes.array(3, CAPACITY) } },
        { longUSeqX  = { xtypes.long, xtypes.sequence() } }, -- unbounded
    }
  }
  
  self:print(BoundsTest)  
  
  -- 1D Seq
  assert(BoundsTest.long1SeqX() == 'long1SeqX#')
  assert(BoundsTest.long1SeqX[1] == 'long1SeqX[1]')
  assert(BoundsTest.long1SeqX[3] == 'long1SeqX[3]')
  assert(not print(pcall(function() return BoundsTest.long1SeqX[4] end)))
  
 -- 1D Seq with X-Types defined constant
  assert(BoundsTest.long2SeqX() == 'long2SeqX#')
  assert(BoundsTest.long2SeqX[1] == 'long2SeqX[1]')
  assert(BoundsTest.long2SeqX[5] == 'long2SeqX[5]')
  assert(not print(pcall(function() return BoundsTest.long2SeqX[6] end)))

 -- 1D Array with X-Types defined constant
  assert(BoundsTest.long1ArrX() == 'long1ArrX#')
  assert(BoundsTest.long1ArrX[1] == 'long1ArrX[1]')
  assert(BoundsTest.long1ArrX[5] == 'long1ArrX[5]')
  assert(not print(pcall(function() return BoundsTest.long1ArrX[6] end)))
  
 -- 2D Array with X-Types defined constant for one bound
  assert(BoundsTest.long2ArrXX() == 'long2ArrXX#')
  assert(BoundsTest.long2ArrXX[1]() == 'long2ArrXX[1]#')
  assert(BoundsTest.long2ArrXX[3]() == 'long2ArrXX[3]#')
  assert(not print(pcall(function() return #BoundsTest.long2ArrXX[4] end)))
  
  assert(BoundsTest.long2ArrXX[3][5] == 'long2ArrXX[3][5]')
  assert(not print(pcall(function() return BoundsTest.long2ArrXX[1][6] end)))
  assert(not print(pcall(function() return BoundsTest.long2ArrXX[4][1] end)))
  assert(not print(pcall(function() return BoundsTest.long2ArrXX[4][6] end)))
  
 -- Unbounded sequence
  assert(BoundsTest.longUSeqX() == 'longUSeqX#')
  assert(BoundsTest.longUSeqX[1] == 'longUSeqX[1]')
  assert(BoundsTest.longUSeqX[999] == 'longUSeqX[999]')
end

Tester[#Tester+1] = 'test_assignment'
function Tester:test_assignment()

  local AssignTemplate = xtypes.struct{
    AssignTemplate = {
        { long0      = { xtypes.long }, },
        { long1SeqX  = { xtypes.long, xtypes.sequence(3) } },
        { long2ArrXX = { xtypes.long, xtypes.array(3, 5) } },
        { longUSeqX  = { xtypes.long, xtypes.sequence() } }, -- unbounded
    }
  }
  
  -- create an instance to store values
  -- NOTE: we don't want to clobber the template
  local Assign = xtypes.utils.new_instance(AssignTemplate)
  
  self:print(Assign)
  print()
  
  -- atomic member
  Assign.long0 = 100   
  print('Assign.long0', Assign.long0)
  assert(Assign.long0 == 100)
  
  
  -- 1D Seq
  Assign.long1SeqX[1] = 100  -- NOTE: already instantiated by print()
  print('Assign.long1SeqX[1]', Assign.long1SeqX[1]) 
  assert(Assign.long1SeqX[1] == 100)
    
  Assign.long1SeqX[2] = 200  
  print('Assign.long1SeqX[2]', Assign.long1SeqX[2]) 
  assert(Assign.long1SeqX[2] == 200)

  assert(not print(pcall(function() Assign.long1SeqX[4] = 400 end)))

  -- Length: 1D Seq
  print('Assign.long1SeqX()', Assign.long1SeqX()) 
  assert(Assign.long1SeqX() == 'long1SeqX#')
  print('#Assign.long1SeqX', #Assign.long1SeqX) 
  assert(#Assign.long1SeqX == 2)
  
  

  -- 2D Array
  Assign.long2ArrXX[1][1] = 100*100  -- NOTE: already instantiated by print()
  print('Assign.long2ArrXX[1][1]', Assign.long2ArrXX[1][1]) 
  assert(Assign.long2ArrXX[1][1] == 100*100)

  Assign.long2ArrXX[1][2] = 100*200  
  print('Assign.long2ArrXX[1][2]', Assign.long2ArrXX[1][2]) 
  assert(Assign.long2ArrXX[1][2] == 100*200)

  Assign.long2ArrXX[2][1] = 200*100  
  print('Assign.long2ArrXX[2][1]', Assign.long2ArrXX[2][1]) 
  assert(Assign.long2ArrXX[2][1] == 200*100)  
  
  Assign.long2ArrXX[2][2] = 200*200  
  print('Assign.long2ArrXX[2][2]', Assign.long2ArrXX[2][2]) 
  assert(Assign.long2ArrXX[2][2] == 200*200)  
  
  assert(not print(pcall(function() Assign.long2ArrXX[3] = 'XXXrandomXXX' end)))
  
  assert(not print(pcall(function() Assign.long2ArrXX[4][1] = 400*100 end)))
  assert(not print(pcall(function() Assign.long2ArrXX[1][6] = 100*600 end)))

  
  -- Length: 2D Array
  print('Assign.long2ArrXX()', Assign.long2ArrXX()) 
  assert(Assign.long2ArrXX() == 'long2ArrXX#')
  print('#Assign.long2ArrXX', #Assign.long2ArrXX) 
  assert(#Assign.long2ArrXX == 3)

  print('Assign.long2ArrXX[1]()', Assign.long2ArrXX[1]()) 
  assert(Assign.long2ArrXX[1]() == 'long2ArrXX[1]#')
  print('#Assign.long2ArrXX[1]', #Assign.long2ArrXX[1]) 
  assert(#Assign.long2ArrXX[1] == 2)
  
    
  -- Unbounded Seq
  for i = 1, 17 do
    Assign.longUSeqX[i] = 100 * i 
    print(string.format('Assign.longUSeqX[%d]', i), Assign.longUSeqX[i]) 
    assert(Assign.longUSeqX[i] == 100 * i)
  end
  Assign.longUSeqX[999] = 100 * 999 -- add hole
  print(string.format('Assign.longUSeqX[%d]', 999), Assign.longUSeqX[999]) 
  assert(Assign.longUSeqX[999] == 100 * 999)
    
  -- Length: Unbounded Seq
  print('Assign.longUSeqX()', Assign.longUSeqX()) 
  assert(Assign.longUSeqX() == 'longUSeqX#')
  print('#Assign.longUSeqX', #Assign.longUSeqX) 
  assert(#Assign.longUSeqX == 17) -- NOTE: hole is is not counted (Lua array)
  self:print(Assign)    
end

Tester[#Tester+1] = 'test_module_manipulation'
function Tester:test_module_manipulation()

  -- declarative 
  local MyModule = xtypes.module{
    MyModule = {
      xtypes.struct{
          ShapeType = {
            { x = { xtypes.long } },
            { y = { xtypes.long } },
            { shapesize = { xtypes.long } },
            { color = { xtypes.string(128), xtypes.Key } }
          }
      },
      
      xtypes.typedef{ 
          StringSeq = { xtypes.string(10), xtypes.sequence(10) }
      },
    }
  }
  
  print("\n-- declarative module definition ---")
  self:print(MyModule)
  
  assert(nil ~= MyModule.ShapeType) 
  assert('x' == MyModule.ShapeType.x)
  assert('y' ==  MyModule.ShapeType.y)
  assert('shapesize' ==  MyModule.ShapeType.shapesize)
  assert('color' ==  MyModule.ShapeType.color)   
  
  assert(nil ~= MyModule.StringSeq) 
  assert(2 == #MyModule)

  print("\n-- add to module: 3rd definition: Nested::Point ---")
  MyModule[3] = xtypes.module{
    Nested = {
      xtypes.struct{
        Point = {
          { x = { xtypes.double } },
          { y = { xtypes.double } }
        }
      },
    }
  }
  self:print(MyModule)  
  assert(nil ~= MyModule.Nested) 
  assert(MyModule.Nested == MyModule[3]) 
  assert(3 == #MyModule)
   
   
  print("\n-- add to module: last definition: MyEnum ---")
  MyModule[#MyModule+1] = xtypes.enum{
    MyEnum = {'Q1', 'Q2', 'Q3', 'Q4'}
  }
  self:print(MyModule)
  assert(nil ~= MyModule.MyEnum) 
  assert(4 == #MyModule)
 
 
  print("\n-- change 3rd definition ---")   
  MyModule[3] = xtypes.enum{
    MyEnum2 = {'SUN', 'MON', 'TUE'}
  }
  self:print(MyModule)
  assert(nil ~= MyModule.MyEnum2)
  assert(4 == #MyModule)  
  
  
  print("\n-- change 3rd definition again ---")
  MyModule[3] = xtypes.module{
    Sub = {
      xtypes.struct{
        Point = {
          { coord = { xtypes.double, xtypes.sequence(2) } },
        }
      },
    }
  }
  self:print(MyModule)
  assert(nil ~= MyModule.Sub)
  print(MyModule.Sub.Point.coord[1])
  assert('coord[1]' == MyModule.Sub.Point.coord[1])
  assert(4 == #MyModule)  
  
  
  print("\n-- delete from module: 2nd definition ---")
  MyModule[2] = nil
  self:print(MyModule)
  print(MyModule.StringSeq)
  assert(nil == MyModule.StringSeq)
  assert(3 == #MyModule)  


  print("\n-- change MyEnum ---")
  MyModule[3] = nil
  MyModule[3] = xtypes.enum{
    MyEnum = {'JAN', 'FEB', 'MAR'}
  }
  self:print(MyModule)
  assert(nil ~= MyModule.MyEnum and nil ~= MyModule.MyEnum.JAN) 
  assert(MyModule.MyEnum == MyModule[3]) 
  assert(3 == #MyModule)  
   
  print("\n-- module definition iteration (ordered) --")
  print(MyModule[xtypes.KIND](), MyModule[xtypes.NAME], #MyModule)
  for i, v in ipairs(MyModule) do print(v) end
  assert(3 == #MyModule)
  
  print("\n-- module namespace iteration (unordered) --")
  for k, v in pairs(MyModule) do print(k, v) end
  
  Test.MyModule[#Test.MyModule+1] = MyModule
end

Tester[#Tester+1] = 'test_root'
function Tester:test_root()
  self:print(Test.MyModule)
end

Tester[#Tester+1] = 'test_ns'
function Tester:test_ns()

  local m = xtypes.module{
    TopModule = {
      xtypes.module{
        Constants = {
          xtypes.const{
            SIZE = { xtypes.short, 10 }
          }
        }
      },
 
      xtypes.module{
        Attributes = {
          xtypes.struct{
            Coord = {
              { x = { xtypes.double } },
              { y = { xtypes.double } },
              { z = { xtypes.double } },
            }
          },
          
          xtypes.typedef{
            StringSeq = {
              xtypes.string(10), xtypes.sequence(10)
            },
          }
        }
      },
    }
  }
  
  m[#m+1] = xtypes.struct{
    NewShapeType = {
      { coords = { m.Attributes.Coord, xtypes.sequence(m.Constants.SIZE) } },
      { shapesize = { xtypes.long } },
      { color = { xtypes.string(m.Constants.SIZE), xtypes.Key } }
    }
  }

  self:print(m)
end

Tester[#Tester+1] = 'test_xml'
function Tester:test_xml()
  local xmlfile2xtypes = require('xtypes-xml').xmlfile2xtypes
  
  local schemas = xmlfile2xtypes('xtypes-xml-tester.xml')
  
  for i = 1, #schemas do
    self:print(schemas[i])
  end
end

Tester[#Tester+1] = 'test_xml_advanced'
function Tester:test_xml_advancedX()
  local xmlfile2xtypes = require('xtypes-xml').xmlfile2xtypes
  
  local schemas = xmlfile2xtypes('types1.xml')
  
  for i = 1, #schemas do
    self:print(schemas[i])
  end
end

Tester[#Tester+1] = 'test_api'
function Tester:test_api()
  -- NOTE: This test also serves as an illustration of the xtypes user API
  
  print('-- template --') 
  
  local ShapeType = xtypes.struct{ShapeType = {
    { x = { xtypes.long } },
    { y = { xtypes.long } },
    { shapesize = { xtypes.long } },
    { color = { xtypes.string(128), xtypes.Key, xtypes.ID{10} } },
    xtypes.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
    xtypes.top_level{},
  }}

  self:print(ShapeType)

  print('-- instance --') 
  local shape = xtypes.utils.new_instance(ShapeType)
  shape.x = 50
  shape.y = 150
  shape.shapesize = 20
  shape.color = 'GREEN'
  
  self:print(shape)
  
  
  
  print('--- Model API ---') 
  
  -- type:
  print('NAME = ', ShapeType[xtypes.NAME], 
        'KIND = ', ShapeType[xtypes.KIND](),
        'BASE = ', ShapeType[xtypes.BASE])
  for i, qualifier in ipairs(ShapeType[xtypes.QUALIFIERS]) do
     print(table.concat{'qualifier[', i, '] = '}, qualifier)  -- use tostring
     print('\t',                          -- OR construct ourselves     
            qualifier[xtypes.NAME],       --    annotation/collection name
            table.concat(qualifier, ' ')) --    annotation/collection attributes
  end
  
  -- members:
  for i = 1, #ShapeType do
    local role, role_definition = next(ShapeType[i])
    print(table.concat{'role[', i, '] = '}, 
                  role,               -- member name
                  role_definition[1]) -- member type
                  
    -- member qualifiers (annotations/collection)
    for j = 1, #role_definition do
      print('\t\t',
            role_definition[j],
            'NAME = ', role_definition[j][xtypes.NAME],   -- member type name
            'KIND = ', role_definition[j][xtypes.KIND]()) -- member type kind
      if 'annotation' == role_definition[j][xtypes.KIND]() and
         #role_definition[j] > 0 then 
            print('\t\t\t\t', table.concat(role_definition[j], ' '))--attributes
      end
    end
  end

  print('--- Instance API ---') 

  -- given an instance, retrieve the template from the instance
  assert(xtypes.utils.template(shape) == ShapeType)

  print('-- ordered ---')
  
  print('ShapeType:')
  for i = 1, #ShapeType do
    local role = next(ShapeType[i])
    print('', role, '=', ShapeType[role]) -- default members values
  end

  print('shape:')
  for i = 1, #ShapeType do
    local role = next(ShapeType[i])
    print('', role, '=', shape[role])     -- shape instance members
  end
    
  print('-- unordered ---')
  print('shape:')
  for role, value in pairs(shape) do
    print('', role, value)
  end
  
end

---
-- print - helper method to print the IDL and the index for data definition
function Tester:print(instance)
    -- print IDL
    local idl = xtypes.utils.visit_model(instance, {'model (IDL):'})
    print(table.concat(idl, '\n\t'))
    
    -- print the result of visiting each field
    local fields = xtypes.utils.visit_instance(instance, {'instance:'})
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
    		
    		print('\nAll tests completed successfully!')
  	end
end

Tester:main()

--------------------------------------------------------------------------------