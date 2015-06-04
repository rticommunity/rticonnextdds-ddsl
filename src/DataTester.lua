#!/usr/local/bin/lua
-------------------------------------------------------------------------------
--  (c) 2005-2014 Copyright, Real-Time Innovations, All rights reserved.     --
--                                                                           --
-- Permission to modify and use for internal purposes granted.               --
-- This software is provided "as is", without warranty, express or implied.  --
--                                                                           --
-------------------------------------------------------------------------------
-- File: DataTester.lua 
-- Purpose: Tester for DDSL: Test type definition Domain Specific Language (DSL)
-- Created: Rajive Joshi, 2014 Feb 14
-------------------------------------------------------------------------------

local idl = require "Data"

--------------------------------------------------------------------------------
-- Tester - the unit tests
--------------------------------------------------------------------------------

local Tester = {} -- array of test functions
local Test = {}   -- table to hold the types created by the tests


Tester[#Tester+1] = 'test_builtin'
function Tester:test_builtin()
  for k, v in pairs(idl) do
      print('*** builtin: ', k, v)
  end
end

Tester[#Tester+1] = 'test_module'
function Tester:test_module()

    Test.MyModule = idl.module{MyModule=idl.EMPTY} -- define a module

    self:print(Test.MyModule)
    
    assert(Test.MyModule ~= nil)
end

Tester[#Tester+1] = 'test_submodule'
function Tester:test_submodule()

  Test.Submodule = idl.module{Submodule=idl.EMPTY} -- submodule 
  Test.MyModule[#Test.MyModule+1] = Test.Submodule -- add to module
  
  self:print(Test.Submodule)
  self:print(Test.MyModule)
  
  assert(Test.MyModule.Submodule == Test.Submodule)
end

Tester[#Tester+1] = 'test_enum_imperative'
function Tester:test_enum_imperative()

  local MyEnum = idl.enum{MyEnum=idl.EMPTY}
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

  Test.Days = idl.enum{
    Days = {  
      'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN',
    }
  }
  
  self:print(Test.Days)
  
  assert(Test.Days.MON == 0)
  assert(Test.Days.SUN == 6)
end

Tester[#Tester+1] = 'test_enum2'
function Tester:test_enum2()

  Test.Months = idl.enum{
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

  Test.Submodule[#Test.Submodule+1] = idl.enum{
    Colors = {
      { RED =  -5 },
      { YELLOW =  7 },
      { GREEN = -9 },
      'PINK',
    }
  }
  self:print(Test.Submodule.Colors)
  
  assert(Test.Submodule.Colors.YELLOW == 7)
  assert(Test.Submodule.Colors.GREEN == -9)
  assert(Test.Submodule.Colors.PINK == 3)
end

Tester[#Tester+1] = 'test_struct_imperative'
function Tester:test_struct_imperative()

    local DynamicShapeType = idl.struct{DynamicShapeType=idl.EMPTY}
    DynamicShapeType[1] = { x = { idl.long } }
    DynamicShapeType[2] = { y = { idl.long } }
    DynamicShapeType[3] = { shapesize = { idl.double } }
    DynamicShapeType[4] = { color = { idl.string(128), idl.Key } }
           
    self:print(DynamicShapeType)

    assert(DynamicShapeType.x == 'x')
    assert(DynamicShapeType.y == 'y')
    assert(DynamicShapeType.shapesize == 'shapesize')
    assert(DynamicShapeType.color == 'color')   
    
    
    
    -- redefine shapesize:
    DynamicShapeType[3] = { shapesize = { idl.long } } -- redefine
    print("\n-- redefined: double->long shapesize --\n")
    self:print(DynamicShapeType)
    assert(DynamicShapeType.shapesize == 'shapesize')
 
 
    -- add z:
    DynamicShapeType[#DynamicShapeType+1] = 
                                { z = { idl.string() , idl.Key } }
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
    Bases.Base1 = idl.struct{
      Base1 = {
        { org = { idl.string() } },
      }
    }
    DynamicShapeType[idl.BASE] = Bases.Base1
    print("\n-- added: base class: Base1 --\n")
    self:print(Bases.Base1)
    self:print(DynamicShapeType)
    assert(DynamicShapeType.org == 'org')  
    assert(DynamicShapeType[idl.BASE] == Bases.Base1)
    
    -- redefine base class
    Bases.Base2 = idl.struct{
      Base2 = {
        { pattern = { idl.long } },
      }
    }
    DynamicShapeType[idl.BASE] = Bases.Base2
    print("\n-- replaced: base class: Base2 --\n")
    self:print(Bases.Base2)
    self:print(DynamicShapeType)
    assert(DynamicShapeType.pattern == 'pattern') 
    assert(DynamicShapeType.org == nil)  
    -- assert(DynamicShapeType[idl.BASE] == Bases.Base2)
    
    -- removed base class
    DynamicShapeType[idl.BASE] = nil
    print("\n-- erased base class --\n")
    self:print(DynamicShapeType)
    assert(DynamicShapeType.pattern == nil) 
    -- assert(DynamicShapeType[idl.BASE] == nil)
 
 
    -- add an annotation
    DynamicShapeType[idl.ANNOTATION] = { 
        idl.Extensibility{'EXTENSIBLE_EXTENSIBILITY'} 
    }
    print("\n-- added annotation: @Extensibility --\n")
    self:print(DynamicShapeType)
    -- assert(DynamicShapeType[idl.ANNOTATION][1] ~= nil)
 
    -- add another annotation
    DynamicShapeType[idl.ANNOTATION] = { 
        idl.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
        idl.Nested{'FALSE'},
    }  
    print("\n-- added: annotation: @Nested --\n")
    self:print(DynamicShapeType)
    assert(DynamicShapeType[idl.ANNOTATION][1] ~= nil)
    assert(DynamicShapeType[idl.ANNOTATION][2] ~= nil)
 
    -- clear annotations:
    DynamicShapeType[idl.ANNOTATION] = nil
    print("\n-- erased annotations --\n")
    self:print(DynamicShapeType)
    assert(DynamicShapeType[idl.ANNOTATION] == nil)
    
    
    -- iterate over the struct definition
    print("\n-- struct definition iteration --", DynamicShapeType)
    print(DynamicShapeType[idl.KIND](), DynamicShapeType[idl.NAME], #DynamicShapeType)
    for i, v in ipairs(DynamicShapeType) do
      print(next(v))
    end
    assert(4 == #DynamicShapeType)
end

Tester[#Tester+1] = 'test_struct_basechange'
function Tester:test_struct_basechange()
  Test.BaseStruct = idl.struct{
    BaseStruct = {
      { x = { idl.long } },
      { y = { idl.long } },
    }
  }
  
  Test.DerivedStruct = idl.struct{
    DerivedStruct = {Test.BaseStruct,
      { speed = { idl.double } }
    }
  }
  print("\n-- DerivedStruct --\n")
  self:print(Test.BaseStruct)
  self:print(Test.DerivedStruct)

  assert(Test.DerivedStruct.x == 'x')
  assert(Test.DerivedStruct.y == 'y')
  assert(Test.DerivedStruct.speed == 'speed')
 
 
  -- remove base class
  Test.DerivedStruct[idl.BASE] = nil

  print("\n-- DerivedStruct removed base class --\n")
  self:print(Test.DerivedStruct)
  assert(Test.DerivedStruct.x == nil)
  assert(Test.DerivedStruct.y == nil)
 
   -- change base class and add it
  Test.BaseStruct[1] = { w = { idl.string() } }
  Test.DerivedStruct[idl.BASE] = Test.BaseStruct
  assert(Test.BaseStruct[1].w[1] == idl.string())
  
  print("\n-- DerivedStruct added modified base class --\n")
  self:print(Test.BaseStruct)
  self:print(Test.DerivedStruct)
  assert(Test.DerivedStruct.w == 'w')
  assert(Test.DerivedStruct.y == 'y')


  -- modify a filed in the base class 
  Test.BaseStruct[2] = { z = { idl.string() } }
  assert(Test.BaseStruct[2].z[1] == idl.string())
  
  print("\n-- DerivedStruct base changed from y : long -> z : string --\n")
  self:print(Test.BaseStruct)
  self:print(Test.DerivedStruct)
  assert(Test.DerivedStruct.z == 'z')
end

Tester[#Tester+1] = 'test_struct_nomodule'
function Tester:test_struct_nomodule()
  local ShapeType = idl.struct{
    ShapeType = {
      { x = { idl.long } },
      { y = { idl.long } },
      { shapesize = { idl.long } },
      { color = { idl.string(128), idl.Key } },
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

    Test.Fruit = idl.struct{
      Fruit = {
        { weight = { idl.double } },
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
  
    Test.Name = idl.struct{
      Name = {
        { first = { idl.string(10), idl.Key } },
        { last = { idl.wstring(128) } },
        { nicknames = { idl.string(), idl.sequence(3) } },
        { aliases = { idl.string(7), idl.sequence() } },
        { birthday = { Test.Days, idl.Optional } },
        { favorite = { Test.Submodule.Colors, idl.sequence(2), idl.Optional } },
      }
    }
    self:print(Test.Name)

    assert(Test.Name.first == 'first')
    assert(Test.Name.last == 'last')
    assert(Test.Name.nicknames() == 'nicknames#')
    assert(Test.Name.nicknames(1) == 'nicknames[1]')
    assert(Test.Name.aliases() == 'aliases#')
    assert(Test.Name.aliases(1) == 'aliases[1]')
    assert(Test.Name.birthday == 'birthday')
    assert(Test.Name.favorite() == 'favorite#')
    assert(Test.Name.favorite(1) == 'favorite[1]')
end

Tester[#Tester+1] = 'test_user_annotation'
function Tester:test_user_annotation()

    -- user defined annotation
    Test.MyAnnotation = idl.annotation{
      MyAnnotation = {value1 = 42, value2 = 9.0}
    }
    Test.MyAnnotationStruct = idl.struct{
      MyAnnotationStruct = {
        { id = { idl.long, idl.Key } },
        { org = { idl.long, idl.Key{GUID=3} } },
        { weight = { idl.double, Test.MyAnnotation } }, -- default 
        { height = { idl.double, Test.MyAnnotation{} } },
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

    Test.Address = idl.struct{
      Address = {
        idl.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
        { name = { Test.Name } },
        { street = { idl.string() } },
        { city = { idl.string(10), 
                      Test.MyAnnotation{value1 = 10, value2 = 17} } },
        idl.Nested{'FALSE'},
      }
    }
    self:print(Test.Address)
    
    assert(Test.Address.name.first == 'name.first')
    assert(Test.Address.name.nicknames() == 'name.nicknames#')
    assert(Test.Address.name.nicknames(1) == 'name.nicknames[1]')
    assert(Test.Address.street == 'street')
    assert(Test.Address.city == 'city')
end

Tester[#Tester+1] = 'test_union_imperative'
function Tester:test_union_imperative()

    local DynamicUnion = idl.union{DynamicUnion={idl.char}} -- switch
    DynamicUnion[1] = { 's', m_str = { idl.string() } }
    DynamicUnion[2] = { 'i', m_int = { idl.short } }  
    DynamicUnion[3] = { 'n' } -- no definition
    DynamicUnion[4] = { nil, m_oct = { idl.octet } } -- default case

    --[[ un-comment to test error checking (expected to assert)
    DynamicUnion[#DynamicUnion+1] = 
                                  { 'x', m_oct = { idl.octet } }
    --]]
    
    -- install it in the module
    Test.DynamicUnion = DynamicUnion
    self:print(DynamicUnion)

    assert(DynamicUnion._d == '#')
    assert(DynamicUnion.m_str == 'm_str')
    assert(DynamicUnion.m_int == 'm_int')
    assert(DynamicUnion.m_oct == 'm_oct')
    
    -- redefine m_int:
    DynamicUnion[2] = { 'l', m_int = { idl.long, idl.Key } }  
    print("\n-- redefined: short->long m_int @Key --\n")
    self:print(DynamicUnion)
    assert(DynamicUnion.m_int == 'm_int')
 
 
    -- add m_real:
    DynamicUnion[#DynamicUnion+1] = 
                      { 'r', m_real = { idl.double, idl.Key } }
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
    DynamicUnion[idl.ANNOTATION] = { 
        idl.Extensibility{'EXTENSIBLE_EXTENSIBILITY'} 
    }
    print("\n-- added annotation: @Extensibility --\n")
    self:print(DynamicUnion)
    assert(DynamicUnion[idl.ANNOTATION][1] ~= nil)
    
    -- add another annotation
    DynamicUnion[idl.ANNOTATION] = { 
        idl.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
        idl.Nested{'FALSE'},
    }  
    print("\n-- added: annotation: @Nested --\n")
    self:print(DynamicUnion)
    assert(DynamicUnion[idl.ANNOTATION][1] ~= nil)
    assert(DynamicUnion[idl.ANNOTATION][2] ~= nil)
 
    -- clear annotations:
    DynamicUnion[idl.ANNOTATION] = nil
    print("\n-- erased annotations --\n")
    self:print(DynamicUnion)
    assert(DynamicUnion[idl.ANNOTATION] == nil)
    
    -- iterate over the union definition
    print("\n-- union definition iteration --", DynamicUnion)
    print(DynamicUnion[idl.KIND](), DynamicUnion[idl.NAME], #DynamicUnion)
    for i, v in ipairs(DynamicUnion) do print(v[1], ':', next(v, 1)) end
    assert(5 == #DynamicUnion)
end

Tester[#Tester+1] = 'test_union_imperative2'
function Tester:test_union_imperative2()
    local DynamicUnion2 = idl.union{DynamicUnion2={idl.char}} -- switch
    DynamicUnion2[1] = { 's', m_str = { idl.string() } }
    DynamicUnion2[2] = { 'i', m_int = { idl.short } }  
    DynamicUnion2[3] = { nil, m_oct = { idl.octet } } -- default case
    
    local DynamicStruct2 = idl.struct{
      DynamicStruct2 = {
          { x = { idl.long } },
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
                { 'r', m_real = { idl.double, idl.Key } }
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

  local TestUnion1 = idl.union{
    TestUnion1 = {idl.short,
      { 1, 
          x = { idl.string() } },
      { 2, 
          y = { idl.long_double } },
      { nil, -- default 
          z = { idl.boolean } },
    }
  }
  Test.TestUnion1 = TestUnion1
  
  self:print(TestUnion1)
  
  assert(TestUnion1._d == '#')
  assert(TestUnion1.x == 'x')
  assert(TestUnion1.y == 'y')
  assert(TestUnion1.z == 'z')
  
  print("\n-- changed discriminator: short -> long --")
  TestUnion1[idl.SWITCH] = idl.long
  self:print(TestUnion1)
  assert(TestUnion1._d == '#')
end

Tester[#Tester+1] = 'test_union2'
function Tester:test_union2()

  Test.TestUnion2 = idl.union{
    TestUnion2 = {idl.char,
      { 'c', 
        name = { Test.Name, idl.Key } },
      { 'a', 
        address = { Test.Address } },
      { nil, -- default
        x = { idl.double } },
    }
  }
  self:print(Test.TestUnion2)
  
  -- discriminator
  assert(Test.TestUnion2._d == '#')
  
  -- name
  assert(Test.TestUnion2.name.first == 'name.first')
  assert(Test.TestUnion2.name.nicknames() == 'name.nicknames#')  
  assert(Test.TestUnion2.name.nicknames(1) == 'name.nicknames[1]')

  -- address
  assert(Test.TestUnion2.address.name.first == 'address.name.first')
  assert(Test.TestUnion2.address.name.nicknames() == 'address.name.nicknames#')  
  assert(Test.TestUnion2.address.name.nicknames(1) == 'address.name.nicknames[1]')

  -- x
  assert(Test.TestUnion2.x == 'x')
end

Tester[#Tester+1] = 'test_union3'
function Tester:test_union3()

  Test.TestUnion3 = idl.union{
    TestUnion3 = {Test.Days,
      { 'MON', 
        name = { Test.Name } },
      { 'TUE', 
        address = { Test.Address } },
      { nil, -- default
         x = { idl.double } },    
      idl.Extensibility{'EXTENSIBLE_EXTENSIBILITY',domain=5},
    }
  }
  self:print(Test.TestUnion3)

  -- discriminator
  assert(Test.TestUnion3._d == '#')
  
  -- name
  assert(Test.TestUnion3.name.first == 'name.first')
  assert(Test.TestUnion3.name.nicknames() == 'name.nicknames#')  
  assert(Test.TestUnion3.name.nicknames(1) == 'name.nicknames[1]')

  -- address
  assert(Test.TestUnion3.address.name.first == 'address.name.first')
  assert(Test.TestUnion3.address.name.nicknames() == 'address.name.nicknames#')  
  assert(Test.TestUnion3.address.name.nicknames(1) == 'address.name.nicknames[1]')

  -- x
  assert(Test.TestUnion3.x == 'x')
  
  -- annotation
  assert(Test.TestUnion3[idl.ANNOTATION][1] ~= nil)
end

Tester[#Tester+1] = 'test_union4'
function Tester:test_union4()

  Test.NameOrAddress = idl.union{
    NameOrAddress = {idl.boolean,
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
  assert(Test.NameOrAddress.name.nicknames(1) == 'name.nicknames[1]')

  -- address
  assert(Test.NameOrAddress.address.name.first == 'address.name.first')
  assert(Test.NameOrAddress.address.name.nicknames() == 'address.name.nicknames#')  
  assert(Test.NameOrAddress.address.name.nicknames(1) == 'address.name.nicknames[1]')
end

Tester[#Tester+1] = 'test_struct_complex1'
function Tester:test_struct_complex1()

  Test.Company = idl.struct{
    Company = {
      { entity = { Test.NameOrAddress } },
      { hq = { idl.string(), idl.sequence(2) } },
      { offices = { Test.Address, idl.sequence(10) } },
      { employees = { Test.Name, idl.sequence() } }
    }
  }
  self:print(Test.Company)
  
  -- entity
  assert(Test.Company.entity._d == 'entity#')
  print(Test.Company.entity, Test.Company.entity.name, Test.Company.entity.name.first)
  print(Test.Company.entity.address, Test.Company.entity.address.name, Test.Company.entity.address.name.first)
  assert(Test.Company.entity.name.first == 'entity.name.first')
  assert(Test.Company.entity.name.nicknames() == 'entity.name.nicknames#')  
  assert(Test.Company.entity.name.nicknames(1) == 'entity.name.nicknames[1]')
  assert(Test.Company.entity.address.name.first == 'entity.address.name.first')
  assert(Test.Company.entity.address.name.nicknames() == 'entity.address.name.nicknames#')  
  assert(Test.Company.entity.address.name.nicknames(1) == 'entity.address.name.nicknames[1]')
  
  -- hq
  assert(Test.Company.hq() == 'hq#')
  assert(Test.Company.hq(1) == 'hq[1]')
  
  -- offices
  assert(Test.Company.offices() == 'offices#')
  assert(Test.Company.offices(1).name.first == 'offices[1].name.first')
  assert(Test.Company.offices(1).name.nicknames() == 'offices[1].name.nicknames#')  
  assert(Test.Company.offices(1).name.nicknames(1) == 'offices[1].name.nicknames[1]')

  -- employees
  assert(Test.Company.employees() == 'employees#')
  assert(Test.Company.employees(1).first == 'employees[1].first')
  assert(Test.Company.employees(1).nicknames() == 'employees[1].nicknames#')  
  assert(Test.Company.employees(1).nicknames(1) == 'employees[1].nicknames[1]')
end

Tester[#Tester+1] = 'test_struct_complex2'
function Tester:test_struct_complex2()

  Test.BigCompany = idl.struct{
    BigCompany = {
      { parent = { Test.Company } },
      { divisions = { Test.Company, idl.sequence() } }
    }
  }
  self:print(Test.BigCompany)
 
  -- parent.entity
  assert(Test.BigCompany.parent.entity._d == 'parent.entity#')
  assert(Test.BigCompany.parent.entity.name.first == 'parent.entity.name.first')
  assert(Test.BigCompany.parent.entity.name.nicknames() == 'parent.entity.name.nicknames#')  
  assert(Test.BigCompany.parent.entity.name.nicknames(1) == 'parent.entity.name.nicknames[1]')
  assert(Test.BigCompany.parent.entity.address.name.first == 'parent.entity.address.name.first')
  assert(Test.BigCompany.parent.entity.address.name.nicknames() == 'parent.entity.address.name.nicknames#')  
  assert(Test.BigCompany.parent.entity.address.name.nicknames(1) == 'parent.entity.address.name.nicknames[1]')
  
  -- parent.hq
  assert(Test.BigCompany.parent.hq() == 'parent.hq#')
  assert(Test.BigCompany.parent.hq(1) == 'parent.hq[1]')
  
  -- parent.offices
  assert(Test.BigCompany.parent.offices() == 'parent.offices#')
  assert(Test.BigCompany.parent.offices(1).name.first == 'parent.offices[1].name.first')
  assert(Test.BigCompany.parent.offices(1).name.nicknames() == 'parent.offices[1].name.nicknames#')  
  assert(Test.BigCompany.parent.offices(1).name.nicknames(1) == 'parent.offices[1].name.nicknames[1]')

  -- parent.employees
  assert(Test.BigCompany.parent.employees() == 'parent.employees#')
  assert(Test.BigCompany.parent.employees(1).first == 'parent.employees[1].first')
  assert(Test.BigCompany.parent.employees(1).nicknames() == 'parent.employees[1].nicknames#')  
  assert(Test.BigCompany.parent.employees(1).nicknames(1) == 'parent.employees[1].nicknames[1]')


  -- divisions
  assert(Test.BigCompany.divisions() == 'divisions#')
  assert(Test.BigCompany.divisions(1).entity._d == 'divisions[1].entity#')
  assert(Test.BigCompany.divisions(1).entity.name.first == 'divisions[1].entity.name.first')
  assert(Test.BigCompany.divisions(1).entity.name.nicknames() == 'divisions[1].entity.name.nicknames#')  
  assert(Test.BigCompany.divisions(1).entity.name.nicknames(1) == 'divisions[1].entity.name.nicknames[1]')
  assert(Test.BigCompany.divisions(1).entity.address.name.first == 'divisions[1].entity.address.name.first')
  assert(Test.BigCompany.divisions(1).entity.address.name.nicknames() == 'divisions[1].entity.address.name.nicknames#')  
  assert(Test.BigCompany.divisions(1).entity.address.name.nicknames(1) == 'divisions[1].entity.address.name.nicknames[1]')
  
  -- divisions(1).hq
  assert(Test.BigCompany.divisions(1).hq() == 'divisions[1].hq#')
  assert(Test.BigCompany.divisions(1).hq(1) == 'divisions[1].hq[1]')
  
  -- divisions(1).offices
  assert(Test.BigCompany.divisions(1).offices() == 'divisions[1].offices#')
  assert(Test.BigCompany.divisions(1).offices(1).name.first == 'divisions[1].offices[1].name.first')
  assert(Test.BigCompany.divisions(1).offices(1).name.nicknames() == 'divisions[1].offices[1].name.nicknames#')  
  assert(Test.BigCompany.divisions(1).offices(1).name.nicknames(1) == 'divisions[1].offices[1].name.nicknames[1]')

  -- divisions(1).employees
  assert(Test.BigCompany.divisions(1).employees() == 'divisions[1].employees#')
  assert(Test.BigCompany.divisions(1).employees(1).first == 'divisions[1].employees[1].first')
  assert(Test.BigCompany.divisions(1).employees(1).nicknames() == 'divisions[1].employees[1].nicknames#')  
  assert(Test.BigCompany.divisions(1).employees(1).nicknames(1) == 'divisions[1].employees[1].nicknames[1]')

end

Tester[#Tester+1] = 'test_struct_inheritance1'
function Tester:test_struct_inheritance1()

  Test.FullName = idl.struct{
    FullName = {Test.Name,
      { middle = { idl.string() } },
      idl.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
    }
  }
  self:print(Test.FullName)
  
  -- base: Name
  assert(Test.FullName.first == 'first')
  assert(Test.FullName.last == 'last')
  assert(Test.FullName.nicknames() == 'nicknames#')
  assert(Test.FullName.nicknames(1) == 'nicknames[1]')
  assert(Test.FullName.aliases() == 'aliases#')
  assert(Test.FullName.aliases(1) == 'aliases[1]')
  assert(Test.FullName.birthday == 'birthday')
  assert(Test.FullName.favorite() == 'favorite#')
  assert(Test.FullName.favorite(1) == 'favorite[1]')
  
  -- FullName
  assert(Test.FullName.middle == 'middle')
end

Tester[#Tester+1] = 'test_struct_inheritance2'
function Tester:test_struct_inheritance2()

  Test.Contact = idl.struct{
    Contact = {Test.FullName,
      { address = { Test.Address } },
      { email = { idl.string() } },
    }
  }
  self:print(Test.Contact)

  -- base: FullName
  assert(Test.Contact.first == 'first')
  assert(Test.Contact.last == 'last')
  assert(Test.Contact.nicknames() == 'nicknames#')
  assert(Test.Contact.nicknames(1) == 'nicknames[1]')
  assert(Test.Contact.aliases() == 'aliases#')
  assert(Test.Contact.aliases(1) == 'aliases[1]')
  assert(Test.Contact.birthday == 'birthday')
  assert(Test.Contact.favorite() == 'favorite#')
  assert(Test.Contact.favorite(1) == 'favorite[1]')
  assert(Test.Contact.middle == 'middle')
  
  -- Contact
  assert(Test.Contact.address.name.first == 'address.name.first')
  assert(Test.Contact.address.name.first == 'address.name.first')
  assert(Test.Contact.address.name.nicknames() == 'address.name.nicknames#')
  assert(Test.Contact.address.name.nicknames(1) == 'address.name.nicknames[1]')
  assert(Test.Contact.address.street == 'address.street')
  assert(Test.Contact.address.city == 'address.city')
    
  assert(Test.Contact.email == 'email')
end

Tester[#Tester+1] = 'test_struct_inheritance3'
function Tester:test_struct_inheritance3()

  Test.Tasks = idl.struct{
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
  assert(Test.Tasks.contact.nicknames(1) == 'contact.nicknames[1]')
  assert(Test.Tasks.contact.aliases() == 'contact.aliases#')
  assert(Test.Tasks.contact.aliases(1) == 'contact.aliases[1]')
  assert(Test.Tasks.contact.birthday == 'contact.birthday')
  assert(Test.Tasks.contact.favorite() == 'contact.favorite#')
  assert(Test.Tasks.contact.favorite(1) == 'contact.favorite[1]')
  assert(Test.Tasks.contact.middle == 'contact.middle')
  
  -- Tasks.contact.address
  assert(Test.Tasks.contact.address.name.first == 'contact.address.name.first')
  assert(Test.Tasks.contact.address.name.first == 'contact.address.name.first')
  assert(Test.Tasks.contact.address.name.nicknames() == 'contact.address.name.nicknames#')
  assert(Test.Tasks.contact.address.name.nicknames(1) == 'contact.address.name.nicknames[1]')
  assert(Test.Tasks.contact.address.street == 'contact.address.street')
  assert(Test.Tasks.contact.address.city == 'contact.address.city')
    
  assert(Test.Tasks.contact.email == 'contact.email')
  
  assert(Test.Tasks.day == 'day')
end

Tester[#Tester+1] = 'test_struct_inheritance4'
function Tester:test_struct_inheritance4()

  Test.Calendar = idl.struct{
    Calendar = {
      { tasks = { Test.Tasks, idl.sequence() } },
    }
  }
  self:print(Test.Calendar)
  
  assert(Test.Calendar.tasks() == 'tasks#')
   
  -- tasks(1).contact
  assert(Test.Calendar.tasks(1).contact.first == 'tasks[1].contact.first')
  assert(Test.Calendar.tasks(1).contact.last == 'tasks[1].contact.last')
  assert(Test.Calendar.tasks(1).contact.nicknames() == 'tasks[1].contact.nicknames#')
  assert(Test.Calendar.tasks(1).contact.nicknames(1) == 'tasks[1].contact.nicknames[1]')
  assert(Test.Calendar.tasks(1).contact.aliases() == 'tasks[1].contact.aliases#')
  assert(Test.Calendar.tasks(1).contact.aliases(1) == 'tasks[1].contact.aliases[1]')
  assert(Test.Calendar.tasks(1).contact.birthday == 'tasks[1].contact.birthday')
  assert(Test.Calendar.tasks(1).contact.favorite() == 'tasks[1].contact.favorite#')
  assert(Test.Calendar.tasks(1).contact.favorite(1) == 'tasks[1].contact.favorite[1]')
  assert(Test.Calendar.tasks(1).contact.middle == 'tasks[1].contact.middle')
  
  -- tasks(1).contact.address
  assert(Test.Calendar.tasks(1).contact.address.name.first == 'tasks[1].contact.address.name.first')
  assert(Test.Calendar.tasks(1).contact.address.name.first == 'tasks[1].contact.address.name.first')
  assert(Test.Calendar.tasks(1).contact.address.name.nicknames() == 'tasks[1].contact.address.name.nicknames#')
  assert(Test.Calendar.tasks(1).contact.address.name.nicknames(1) == 'tasks[1].contact.address.name.nicknames[1]')
  assert(Test.Calendar.tasks(1).contact.address.street == 'tasks[1].contact.address.street')
  assert(Test.Calendar.tasks(1).contact.address.city == 'tasks[1].contact.address.city')
    
  assert(Test.Calendar.tasks(1).contact.email == 'tasks[1].contact.email')
  
  assert(Test.Calendar.tasks(1).day == 'tasks[1].day')
end

Tester[#Tester+1] = 'test_struct_recursive'
function Tester:test_struct_recursive()

    -- NOTE: Forward data declarations are not allowed in IDL
    --       still, this is just a test to see how it might work
    
    Test.RecursiveStruct = idl.struct{RecursiveStruct=idl.EMPTY} -- fwd decl
    local RecursiveStruct = idl.struct{
      RecursiveStruct = { -- note: won't get installed as a defn
        { x = { idl.long } },
        { y = { idl.long } },
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

    Test.Atoms = idl.struct{
      Atoms = {
        { myBoolean = { idl.boolean } },
        { myOctet = { idl.octet } },
        { myChar = { idl.char } },
        { myWChar = { idl.wchar } },
        { myFloat = { idl.float } },
        { myDouble = { idl.double } },
        { myLongDouble = { idl.long_double } },
        { myShort = { idl.short } },
        { myLong = { idl.long } },
        { myLongLong = { idl.long_long } },
        { myUnsignedShort = { idl.unsigned_short } },
        { myUnsignedLong = { idl.unsigned_long } },
        { myUnsignedLongLong = { idl.unsigned_long_long } },
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
  Test.MyDouble = idl.typedef{MyDouble = { idl.double} }
  Test.MyDouble2 = idl.typedef{MyDouble2 = { Test.MyDouble } }
  Test.MyString = idl.typedef{MyString = { idl.string(10) } }
  
  Test.MyName = idl.typedef{MyName = { Test.Name } }
  Test.MyName2 = idl.typedef{MyName2 = { Test.MyName} }
  
  Test.MyAddress = idl.typedef{MyAddress = { Test.Address } }
  Test.MyAddress2 = idl.typedef{MyAddress2 = { Test.MyAddress } }
  
  Test.MyTypedef = idl.struct{
    MyTypedef = {
      { rawDouble =  { idl.double } },
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
  assert(Test.MyTypedef.name.nicknames(1) == 'name.nicknames[1]')
  -- myName
  assert(Test.MyTypedef.myName.first == 'myName.first')
  assert(Test.MyTypedef.myName.nicknames() == 'myName.nicknames#')  
  assert(Test.MyTypedef.myName.nicknames(1) == 'myName.nicknames[1]')
  -- myAddress2
  assert(Test.MyTypedef.myAddress2.name.first == 'myAddress2.name.first')
  assert(Test.MyTypedef.myAddress2.name.nicknames() == 'myAddress2.name.nicknames#')  
  assert(Test.MyTypedef.myAddress2.name.nicknames(1) == 'myAddress2.name.nicknames[1]')
end

Tester[#Tester+1] = 'test_typedef_seq'
function Tester:test_typedef_seq()  

  Test.MyDoubleSeq = idl.typedef{
    MyDoubleSeq = {Test.MyDouble, idl.sequence() }}
  Test.MyStringSeq = idl.typedef{
    MyStringSeq = {Test.MyString, idl.sequence(10) }}
  
  Test.NameSeq = idl.typedef{
    NameSeq = {Test.Name, idl.sequence(10) } }
  Test.NameSeqSeq = idl.typedef{
    NameSeqSeq = {Test.NameSeq, idl.sequence(10) }}
  
  Test.MyNameSeq = idl.typedef{
    MyNameSeq = {Test.MyName, idl.sequence(10) }}
  Test.MyNameSeqSeq = idl.typedef{
    MyNameSeqSeq = {Test.MyNameSeq, idl.sequence(10) }}
  
  Test.MyTypedefSeq = idl.struct{
    MyTypedefSeq = {
      { myDoubleSeq = { Test.MyDouble, idl.sequence() } },
      { myDoubleSeqA = { Test.MyDoubleSeq } },
      { myStringSeqA = { Test.MyStringSeq } },
      
      { nameSeq = { Test.Name, idl.sequence() } },
      { nameSeqA = { Test.NameSeq } },
      { nameSeqSeq = { Test.NameSeq, idl.sequence() } },
      { nameSeqSeqA = { Test.NameSeqSeq } },
      { nameSeqSeqASeq = { Test.NameSeqSeq, idl.sequence() } },
    
      { myNameSeq = { Test.MyName, idl.sequence() } },
      { myNameSeqA = { Test.MyNameSeq } },
      { myNameSeqSeq = { Test.MyNameSeq, idl.sequence() } },
      { myNameSeqSeqA = { Test.MyNameSeqSeq } },
      { myNameSeqSeqASeq = { Test.MyNameSeqSeq, idl.sequence() } },
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
  assert(Test.MyTypedefSeq.nameSeq(1).first == 'nameSeq[1].first')  
  assert(Test.MyTypedefSeq.nameSeq(1).nicknames() == 'nameSeq[1].nicknames#') 
  assert(Test.MyTypedefSeq.nameSeq(1).nicknames(1) == 'nameSeq[1].nicknames[1]')  

  -- nameSeqA
  assert(Test.MyTypedefSeq.nameSeqA() == 'nameSeqA#')
  assert(Test.MyTypedefSeq.nameSeqA(1).first == 'nameSeqA[1].first')  
  assert(Test.MyTypedefSeq.nameSeqA(1).nicknames() == 'nameSeqA[1].nicknames#') 
  assert(Test.MyTypedefSeq.nameSeqA(1).nicknames(1) == 'nameSeqA[1].nicknames[1]')  

  -- nameSeqSeq
  assert(Test.MyTypedefSeq.nameSeqSeq() == 'nameSeqSeq#') 
  assert(Test.MyTypedefSeq.nameSeqSeq(1)() == 'nameSeqSeq[1]#')
  assert(Test.MyTypedefSeq.nameSeqSeq(1)(1).first == 'nameSeqSeq[1][1].first')
  assert(Test.MyTypedefSeq.nameSeqSeq(1)(1).nicknames() == 'nameSeqSeq[1][1].nicknames#')
  assert(Test.MyTypedefSeq.nameSeqSeq(1)(1).nicknames(1) == 'nameSeqSeq[1][1].nicknames[1]')
  
  -- nameSeqSeqA
  assert(Test.MyTypedefSeq.nameSeqSeqA() == 'nameSeqSeqA#') 
  assert(Test.MyTypedefSeq.nameSeqSeqA(1)() == 'nameSeqSeqA[1]#')
  assert(Test.MyTypedefSeq.nameSeqSeqA(1)(1).first == 'nameSeqSeqA[1][1].first')
  assert(Test.MyTypedefSeq.nameSeqSeqA(1)(1).nicknames() == 'nameSeqSeqA[1][1].nicknames#')
  assert(Test.MyTypedefSeq.nameSeqSeqA(1)(1).nicknames(1) == 'nameSeqSeqA[1][1].nicknames[1]')

  -- nameSeqSeqASeq
  assert(Test.MyTypedefSeq.nameSeqSeqASeq() == 'nameSeqSeqASeq#') 
  assert(Test.MyTypedefSeq.nameSeqSeqASeq(1)() == 'nameSeqSeqASeq[1]#')
  assert(Test.MyTypedefSeq.nameSeqSeqASeq(1)(1)() == 'nameSeqSeqASeq[1][1]#')
  assert(Test.MyTypedefSeq.nameSeqSeqASeq(1)(1)(1).first == 'nameSeqSeqASeq[1][1][1].first')
  assert(Test.MyTypedefSeq.nameSeqSeqASeq(1)(1)(1).nicknames() == 'nameSeqSeqASeq[1][1][1].nicknames#')
  assert(Test.MyTypedefSeq.nameSeqSeqASeq(1)(1)(1).nicknames(1) == 'nameSeqSeqASeq[1][1][1].nicknames[1]')

  -- myNameSeq
  assert(Test.MyTypedefSeq.myNameSeq() == 'myNameSeq#')
  assert(Test.MyTypedefSeq.myNameSeq(1).first == 'myNameSeq[1].first')  
  assert(Test.MyTypedefSeq.myNameSeq(1).nicknames() == 'myNameSeq[1].nicknames#') 
  assert(Test.MyTypedefSeq.myNameSeq(1).nicknames(1) == 'myNameSeq[1].nicknames[1]')  

  -- myNameSeqA
  assert(Test.MyTypedefSeq.myNameSeqA() == 'myNameSeqA#')
  assert(Test.MyTypedefSeq.myNameSeqA(1).first == 'myNameSeqA[1].first')  
  assert(Test.MyTypedefSeq.myNameSeqA(1).nicknames() == 'myNameSeqA[1].nicknames#') 
  assert(Test.MyTypedefSeq.myNameSeqA(1).nicknames(1) == 'myNameSeqA[1].nicknames[1]')  

  -- myNameSeqSeq
  assert(Test.MyTypedefSeq.myNameSeqSeq() == 'myNameSeqSeq#') 
  assert(Test.MyTypedefSeq.myNameSeqSeq(1)() == 'myNameSeqSeq[1]#')
  assert(Test.MyTypedefSeq.myNameSeqSeq(1)(1).first == 'myNameSeqSeq[1][1].first')
  assert(Test.MyTypedefSeq.myNameSeqSeq(1)(1).nicknames() == 'myNameSeqSeq[1][1].nicknames#')
  assert(Test.MyTypedefSeq.myNameSeqSeq(1)(1).nicknames(1) == 'myNameSeqSeq[1][1].nicknames[1]')
  
  -- myNameSeqSeqA
  assert(Test.MyTypedefSeq.myNameSeqSeqA() == 'myNameSeqSeqA#') 
  assert(Test.MyTypedefSeq.myNameSeqSeqA(1)() == 'myNameSeqSeqA[1]#')
  assert(Test.MyTypedefSeq.myNameSeqSeqA(1)(1).first == 'myNameSeqSeqA[1][1].first')
  assert(Test.MyTypedefSeq.myNameSeqSeqA(1)(1).nicknames() == 'myNameSeqSeqA[1][1].nicknames#')
  assert(Test.MyTypedefSeq.myNameSeqSeqA(1)(1).nicknames(1) == 'myNameSeqSeqA[1][1].nicknames[1]')

  -- myNameSeqSeqASeq
  assert(Test.MyTypedefSeq.myNameSeqSeqASeq() == 'myNameSeqSeqASeq#') 
  assert(Test.MyTypedefSeq.myNameSeqSeqASeq(1)() == 'myNameSeqSeqASeq[1]#')
  assert(Test.MyTypedefSeq.myNameSeqSeqASeq(1)(1)() == 'myNameSeqSeqASeq[1][1]#')
  assert(Test.MyTypedefSeq.myNameSeqSeqASeq(1)(1)(1).first == 'myNameSeqSeqASeq[1][1][1].first')
  assert(Test.MyTypedefSeq.myNameSeqSeqASeq(1)(1)(1).nicknames() == 'myNameSeqSeqASeq[1][1][1].nicknames#')
  assert(Test.MyTypedefSeq.myNameSeqSeqASeq(1)(1)(1).nicknames(1) == 'myNameSeqSeqASeq[1][1][1].nicknames[1]')
end

Tester[#Tester+1] = 'test_arrays1'
function Tester:test_arrays1()

    -- Arrays
    Test.MyArrays1 = idl.struct{
      MyArrays1 = {
        -- 1-D
        { ints = { idl.double, idl.array(3) } },
      
        -- 2-D
        { days = { Test.Days, idl.array(6, 9) } },
        
        -- 3-D
        { names = { Test.Name, idl.array(12, 15, 18) } },
      }
  }
	-- structure with arrays
	self:print(Test.MyArrays1)
	
	-- ints
	assert(Test.MyArrays1.ints() == 'ints#')
	assert(Test.MyArrays1.ints(1) == 'ints[1]')
	
	-- days
	assert(Test.MyArrays1.days() == 'days#')
	assert(Test.MyArrays1.days(1)() == 'days[1]#')
	assert(Test.MyArrays1.days(1)(1) == 'days[1][1]')
	
	-- names
	assert(Test.MyArrays1.names() == 'names#')
	assert(Test.MyArrays1.names(1)() == 'names[1]#')
	assert(Test.MyArrays1.names(1)(1)() == 'names[1][1]#')
	assert(Test.MyArrays1.names(1)(1)(1).first == 'names[1][1][1].first')
	assert(Test.MyArrays1.names(1)(1)(1).nicknames() == 'names[1][1][1].nicknames#')
	assert(Test.MyArrays1.names(1)(1)(1).nicknames(1) == 'names[1][1][1].nicknames[1]')
end

Tester[#Tester+1] = 'test_arrays2'
function Tester:test_arrays2()

    Test.MyArrays2 = idl.union{
      MyArrays2 = {Test.Days,
        -- 1-D
        { 'MON',
          ints = { idl.double, idl.array(3) }},
      
        -- 2-D
        { 'TUE',
          days = { Test.Days, idl.array(6, 9) }},
        
        -- 3-D
        {nil,
          names = { Test.Name, idl.array(12, 15, 18) }},  
      }
  }
	-- union with arrays
	self:print(Test.MyArrays2)
	
	-- ints
	assert(Test.MyArrays2.ints() == 'ints#')
	assert(Test.MyArrays2.ints(1) == 'ints[1]')
	
	-- days
	assert(Test.MyArrays2.days() == 'days#')
	assert(Test.MyArrays2.days(1)() == 'days[1]#')
	assert(Test.MyArrays2.days(1)(1) == 'days[1][1]')
	
	-- names
	assert(Test.MyArrays2.names() == 'names#')
	assert(Test.MyArrays2.names(1)() == 'names[1]#')
	assert(Test.MyArrays2.names(1)(1)() == 'names[1][1]#')
	assert(Test.MyArrays2.names(1)(1)(1).first == 'names[1][1][1].first')
	assert(Test.MyArrays2.names(1)(1)(1).nicknames() == 'names[1][1][1].nicknames#')
	assert(Test.MyArrays2.names(1)(1)(1).nicknames(1) == 'names[1][1][1].nicknames[1]')
end

Tester[#Tester+1] = 'test_arrays3'
function Tester:test_arrays3()
	Test.MyNameArray = idl.typedef{
	   MyNameArray = { Test.Name, idl.array(10) }
	}
	Test.MyNameArray2 = idl.typedef{
	   MyNameArray2 = {Test.MyNameArray, idl.array(10) }
	}
	Test.MyName2x2 = idl.typedef{
	   MyName2x2 = {Test.Name, idl.array(2, 3) }
	}
	
	Test.MyArrays3 = idl.struct{
	 MyArrays3 = {
  		-- 1-D
  		{ myNames = { Test.MyNameArray } },
  
  		-- 2-D
  		{ myNamesArray = { Test.MyNameArray, idl.array(10) } },
  	
  		-- 2-D
  		{ myNames2 = { Test.MyNameArray2 } },
  				
  		-- 3-D
  		{ myNames2Array = { Test.MyNameArray2, idl.array(10) } },
  
  		-- 4-D
  		{ myNames2Array2 = { Test.MyNameArray2, idl.array(10, 20) } },
  		
  		-- 2D: 2x2
  		{ myName2x2 = { Test.MyName2x2 } },
  
  		-- 4D: 2x2 x2x2
  		{ myName2x2x2x2 = { Test.MyName2x2, idl.array(4,5) } },
  	}
  }
  self:print(Test.MyNameArray)
  self:print(Test.MyNameArray2)
  self:print(Test.MyName2x2)
	self:print(Test.MyArrays3)

	-- myNames
	assert(Test.MyArrays3.myNames() == 'myNames#')
	assert(Test.MyArrays3.myNames(1).first == 'myNames[1].first')
	assert(Test.MyArrays3.myNames(1).nicknames() == 'myNames[1].nicknames#')
	assert(Test.MyArrays3.myNames(1).nicknames(1) == 'myNames[1].nicknames[1]')
	
	-- myNamesArray
	assert(Test.MyArrays3.myNamesArray() == 'myNamesArray#')
	assert(Test.MyArrays3.myNamesArray(1)() == 'myNamesArray[1]#')
	assert(Test.MyArrays3.myNamesArray(1)(1).first == 'myNamesArray[1][1].first')
	assert(Test.MyArrays3.myNamesArray(1)(1).nicknames() == 'myNamesArray[1][1].nicknames#')
	assert(Test.MyArrays3.myNamesArray(1)(1).nicknames(1) == 'myNamesArray[1][1].nicknames[1]')
	
	-- myNames2
	assert(Test.MyArrays3.myNames2() == 'myNames2#')
	assert(Test.MyArrays3.myNames2(1)() == 'myNames2[1]#')
	assert(Test.MyArrays3.myNames2(1)(1).first == 'myNames2[1][1].first')
	assert(Test.MyArrays3.myNames2(1)(1).nicknames() == 'myNames2[1][1].nicknames#')
	assert(Test.MyArrays3.myNames2(1)(1).nicknames(1) == 'myNames2[1][1].nicknames[1]')

	-- myNames2Array
	assert(Test.MyArrays3.myNames2Array() == 'myNames2Array#')
	assert(Test.MyArrays3.myNames2Array(1)() == 'myNames2Array[1]#')
	assert(Test.MyArrays3.myNames2Array(1)(1)() == 'myNames2Array[1][1]#')
	assert(Test.MyArrays3.myNames2Array(1)(1)(1).first == 'myNames2Array[1][1][1].first')
	assert(Test.MyArrays3.myNames2Array(1)(1)(1).nicknames() == 'myNames2Array[1][1][1].nicknames#')
	assert(Test.MyArrays3.myNames2Array(1)(1)(1).nicknames(1) == 'myNames2Array[1][1][1].nicknames[1]')

	-- myNames2Array2
	assert(Test.MyArrays3.myNames2Array2() == 'myNames2Array2#')
	assert(Test.MyArrays3.myNames2Array2(1)() == 'myNames2Array2[1]#')
	assert(Test.MyArrays3.myNames2Array2(1)(1)() == 'myNames2Array2[1][1]#')
	assert(Test.MyArrays3.myNames2Array2(1)(1)(1)() == 'myNames2Array2[1][1][1]#')
	assert(Test.MyArrays3.myNames2Array2(1)(1)(1)(1).first == 'myNames2Array2[1][1][1][1].first')
	assert(Test.MyArrays3.myNames2Array2(1)(1)(1)(1).nicknames() == 'myNames2Array2[1][1][1][1].nicknames#')
	assert(Test.MyArrays3.myNames2Array2(1)(1)(1)(1).nicknames(1) == 'myNames2Array2[1][1][1][1].nicknames[1]')

	-- myName2x2
	assert(Test.MyArrays3.myName2x2() == 'myName2x2#')
	assert(Test.MyArrays3.myName2x2(1)() == 'myName2x2[1]#')
	assert(Test.MyArrays3.myName2x2(1)(1).first == 'myName2x2[1][1].first')
	assert(Test.MyArrays3.myName2x2(1)(1).nicknames() == 'myName2x2[1][1].nicknames#')
	assert(Test.MyArrays3.myName2x2(1)(1).nicknames(1) == 'myName2x2[1][1].nicknames[1]')

	-- myName2x2x2x2
	assert(Test.MyArrays3.myName2x2x2x2() == 'myName2x2x2x2#')
	assert(Test.MyArrays3.myName2x2x2x2(1)() == 'myName2x2x2x2[1]#')
	assert(Test.MyArrays3.myName2x2x2x2(1)(1)() == 'myName2x2x2x2[1][1]#')
	assert(Test.MyArrays3.myName2x2x2x2(1)(1)(1)() == 'myName2x2x2x2[1][1][1]#')
	assert(Test.MyArrays3.myName2x2x2x2(1)(1)(1)(1).first == 'myName2x2x2x2[1][1][1][1].first')
	assert(Test.MyArrays3.myName2x2x2x2(1)(1)(1)(1).nicknames() == 'myName2x2x2x2[1][1][1][1].nicknames#')
	assert(Test.MyArrays3.myName2x2x2x2(1)(1)(1)(1).nicknames(1) == 'myName2x2x2x2[1][1][1][1].nicknames[1]')
end

Tester[#Tester+1] = 'test_sequences_multi_dim'
function Tester:test_sequences_multi_dim()
	Test.MyNameSeq1 = idl.typedef{
	   MyNameSeq1 = {Test.Name, idl.sequence(10) }
	}
	Test.MyNameSeq2 = idl.typedef{
	   MyNameSeq2 = {Test.MyNameSeq, idl.sequence(10) }
	}
	Test.MyNameSeq2x2 = idl.typedef{
	   MyNameSeq2x2 = {Test.Name, idl.sequence(2, 3) }
	}
	
	Test.MySeqs3 = idl.struct{
	 MySeqs3 = {
  		-- 1-D
  		{ myNames = { Test.MyNameSeq } },
  
  		-- 2-D
  		{ myNamesSeq = { Test.MyNameSeq1, idl.sequence(10) } },
  	
  		-- 2-D
  		{ myNames2 = { Test.MyNameSeq2 } },
  				
  		-- 3-D
  		{ myNames2Seq = { Test.MyNameSeq2, idl.sequence(10) } },
  
  		-- 4-D
  		{ myNames2Seq2 = { Test.MyNameSeq2, idl.sequence(10, 20) } },
  		
  		-- 2D: 2x2
  		{ myName2x2 = { Test.MyName2x2 } },
  
  		-- 4D: 2x2 x2x2
  		{ myName2x2x2x2 = { Test.MyNameSeq2x2, idl.sequence(4,5) } },
  	}
  }
  self:print(Test.MyNameSeq1)
  self:print(Test.MyNameSeq2)
  self:print(Test.MySeqs3)
	self:print(Test.MyNameSeq2x2)

	-- myNames
	assert(Test.MySeqs3.myNames() == 'myNames#')
	assert(Test.MySeqs3.myNames(1).first == 'myNames[1].first')
	assert(Test.MySeqs3.myNames(1).nicknames() == 'myNames[1].nicknames#')
	assert(Test.MySeqs3.myNames(1).nicknames(1) == 'myNames[1].nicknames[1]')
	
	-- myNamesSeq
	assert(Test.MySeqs3.myNamesSeq() == 'myNamesSeq#')
	assert(Test.MySeqs3.myNamesSeq(1)() == 'myNamesSeq[1]#')
	assert(Test.MySeqs3.myNamesSeq(1)(1).first == 'myNamesSeq[1][1].first')
	assert(Test.MySeqs3.myNamesSeq(1)(1).nicknames() == 'myNamesSeq[1][1].nicknames#')
	assert(Test.MySeqs3.myNamesSeq(1)(1).nicknames(1) == 'myNamesSeq[1][1].nicknames[1]')
	
	-- myNames2
	assert(Test.MySeqs3.myNames2() == 'myNames2#')
	assert(Test.MySeqs3.myNames2(1)() == 'myNames2[1]#')
	assert(Test.MySeqs3.myNames2(1)(1).first == 'myNames2[1][1].first')
	assert(Test.MySeqs3.myNames2(1)(1).nicknames() == 'myNames2[1][1].nicknames#')
	assert(Test.MySeqs3.myNames2(1)(1).nicknames(1) == 'myNames2[1][1].nicknames[1]')

	-- myNames2Seq
	assert(Test.MySeqs3.myNames2Seq() == 'myNames2Seq#')
	assert(Test.MySeqs3.myNames2Seq(1)() == 'myNames2Seq[1]#')
	assert(Test.MySeqs3.myNames2Seq(1)(1)() == 'myNames2Seq[1][1]#')
	assert(Test.MySeqs3.myNames2Seq(1)(1)(1).first == 'myNames2Seq[1][1][1].first')
	assert(Test.MySeqs3.myNames2Seq(1)(1)(1).nicknames() == 'myNames2Seq[1][1][1].nicknames#')
	assert(Test.MySeqs3.myNames2Seq(1)(1)(1).nicknames(1) == 'myNames2Seq[1][1][1].nicknames[1]')

	-- myNames2Seq2
	assert(Test.MySeqs3.myNames2Seq2() == 'myNames2Seq2#')
	assert(Test.MySeqs3.myNames2Seq2(1)() == 'myNames2Seq2[1]#')
	assert(Test.MySeqs3.myNames2Seq2(1)(1)() == 'myNames2Seq2[1][1]#')
	assert(Test.MySeqs3.myNames2Seq2(1)(1)(1)() == 'myNames2Seq2[1][1][1]#')
	assert(Test.MySeqs3.myNames2Seq2(1)(1)(1)(1).first == 'myNames2Seq2[1][1][1][1].first')
	assert(Test.MySeqs3.myNames2Seq2(1)(1)(1)(1).nicknames() == 'myNames2Seq2[1][1][1][1].nicknames#')
	assert(Test.MySeqs3.myNames2Seq2(1)(1)(1)(1).nicknames(1) == 'myNames2Seq2[1][1][1][1].nicknames[1]')

	-- myName2x2
	assert(Test.MySeqs3.myName2x2() == 'myName2x2#')
	assert(Test.MySeqs3.myName2x2(1)() == 'myName2x2[1]#')
	assert(Test.MySeqs3.myName2x2(1)(1).first == 'myName2x2[1][1].first')
	assert(Test.MySeqs3.myName2x2(1)(1).nicknames() == 'myName2x2[1][1].nicknames#')
	assert(Test.MySeqs3.myName2x2(1)(1).nicknames(1) == 'myName2x2[1][1].nicknames[1]')

	-- myName2x2x2x2
	assert(Test.MySeqs3.myName2x2x2x2() == 'myName2x2x2x2#')
	assert(Test.MySeqs3.myName2x2x2x2(1)() == 'myName2x2x2x2[1]#')
	assert(Test.MySeqs3.myName2x2x2x2(1)(1)() == 'myName2x2x2x2[1][1]#')
	assert(Test.MySeqs3.myName2x2x2x2(1)(1)(1)() == 'myName2x2x2x2[1][1][1]#')
	assert(Test.MySeqs3.myName2x2x2x2(1)(1)(1)(1).first == 'myName2x2x2x2[1][1][1][1].first')
	assert(Test.MySeqs3.myName2x2x2x2(1)(1)(1)(1).nicknames() == 'myName2x2x2x2[1][1][1][1].nicknames#')
	assert(Test.MySeqs3.myName2x2x2x2(1)(1)(1)(1).nicknames(1) == 'myName2x2x2x2[1][1][1][1].nicknames[1]')
end

Tester[#Tester+1] = 'test_const'
function Tester:test_const()
  Test.FLOAT = idl.const{FLOAT = { idl.float, 3.14 } }
  Test.DOUBLE = idl.const{DOUBLE = { idl.double, 3.14 * 3.14 } } 
  Test.LDOUBLE = idl.const{LDOUBLE = { idl.long_double, 3.14 * 3.14 * 3.14 }}   
  Test.STRING = idl.const{STRING = { idl.string(), "String Constant" } }   
  Test.BOOL = idl.const{BOOL = { idl.boolean, true } }
  Test.CHAR = idl.const{CHAR = { idl.char, "String Constant" } } -- warning  
  Test.LONG = idl.const{LONG = { idl.long, 10.7 } } -- warning
  Test.LLONG = idl.const{LLONG = { idl.long_long, 10^10 } }
  Test.SHORT = idl.const{SHORT = { idl.short, 5 } }
  Test.WSTRING = idl.const{WSTRING = { idl.wstring(), "WString Constant" } }

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
    local CAPACITY = idl.const{
      CAPACITY = { idl.short, 5 } 
    }
    Test.MyCapacitySeq = idl.typedef{
      MyCapacitySeq = {Test.Name, idl.sequence(CAPACITY, CAPACITY) }
    }
    Test.MyCapacityArr = idl.typedef{
      MyCapacityArr = {Test.Name, idl.array(CAPACITY, CAPACITY) }
    }
    
    Test.MyCapacityStruct = idl.struct{
      MyCapacityStruct = { 
          { myNames = { Test.MyCapacitySeq } },
          { myNames2 = { Test.MyCapacityArr } },
          { myStrings = { idl.string(), 
                         idl.array(CAPACITY, CAPACITY)} },
          { myNums = { idl.double, 
                      idl.sequence(CAPACITY, CAPACITY)} },
          { myStr = { idl.string(CAPACITY) } },                                       
      }
    }                               
    self:print(CAPACITY)
    self:print(Test.MyCapacitySeq)
    self:print(Test.MyCapacityArr)
    self:print(Test.MyCapacityStruct)
    
    assert(CAPACITY() == 5)
    
    -- myNames
    assert(Test.MyCapacityStruct.myNames() == 'myNames#')
    assert(Test.MyCapacityStruct.myNames(1)() == 'myNames[1]#')
    assert(Test.MyCapacityStruct.myNames(1)(1).first == 'myNames[1][1].first')
    assert(Test.MyCapacityStruct.myNames(1)(1).nicknames() == 'myNames[1][1].nicknames#')
    assert(Test.MyCapacityStruct.myNames(1)(1).nicknames(1) == 'myNames[1][1].nicknames[1]')
  
    -- myNames2
    assert(Test.MyCapacityStruct.myNames2() == 'myNames2#')
    assert(Test.MyCapacityStruct.myNames2(1)() == 'myNames2[1]#')
    assert(Test.MyCapacityStruct.myNames2(1)(1).first == 'myNames2[1][1].first')
    assert(Test.MyCapacityStruct.myNames2(1)(1).nicknames() == 'myNames2[1][1].nicknames#')
    assert(Test.MyCapacityStruct.myNames2(1)(1).nicknames(1) == 'myNames2[1][1].nicknames[1]')
   
    -- myStrings
    assert(Test.MyCapacityStruct.myStrings() == 'myStrings#')
    assert(Test.MyCapacityStruct.myStrings(1)() == 'myStrings[1]#')
    assert(Test.MyCapacityStruct.myStrings(1)(1) == 'myStrings[1][1]')
    
    -- myStr
    assert(Test.MyCapacityStruct.myStr == 'myStr')
end

Tester[#Tester+1] = 'test_module_manipulation'
function Tester:test_module_manipulation()

  -- declarative 
  local MyModule = idl.module{
    MyModule = {
      idl.struct{
          ShapeType = {
            { x = { idl.long } },
            { y = { idl.long } },
            { shapesize = { idl.long } },
            { color = { idl.string(128), idl.Key } }
          }
      },
      
      idl.typedef{ 
          StringSeq = { idl.string(10), idl.sequence(10) }
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
  MyModule[3] = idl.module{
    Nested = {
      idl.struct{
        Point = {
          { x = { idl.double } },
          { y = { idl.double } }
        }
      },
    }
  }
  self:print(MyModule)  
  assert(nil ~= MyModule.Nested) 
  assert(MyModule.Nested == MyModule[3]) 
  assert(3 == #MyModule)
   
   
  print("\n-- add to module: last definition: MyEnum ---")
  MyModule[#MyModule+1] = idl.enum{
    MyEnum = {'Q1', 'Q2', 'Q3', 'Q4'}
  }
  self:print(MyModule)
  assert(nil ~= MyModule.MyEnum) 
  assert(4 == #MyModule)
 
 
  print("\n-- change 3rd definition ---")   
  MyModule[3] = idl.enum{
    MyEnum2 = {'SUN', 'MON', 'TUE'}
  }
  self:print(MyModule)
  assert(nil ~= MyModule.MyEnum2)
  assert(4 == #MyModule)  
  
  
  print("\n-- change 3rd definition again ---")
  MyModule[3] = idl.module{
    Sub = {
      idl.struct{
        Point = {
          { coord = { idl.double, idl.sequence(2) } },
        }
      },
    }
  }
  self:print(MyModule)
  assert(nil ~= MyModule.Sub)
  print(MyModule.Sub.Point.coord(1))
  assert('coord[1]' == MyModule.Sub.Point.coord(1))
  assert(4 == #MyModule)  
  
  
  print("\n-- delete from module: 2nd definition ---")
  MyModule[2] = nil
  self:print(MyModule)
  print(MyModule.StringSeq)
  assert(nil == MyModule.StringSeq)
  assert(3 == #MyModule)  


  print("\n-- change MyEnum ---") -- TODO: fix: meta-table not invoked
  MyModule[3] = idl.enum{
    MyEnum = {'JAN', 'FEB', 'MAR'}
  }
  self:print(MyModule)
  assert(nil ~= MyModule.MyEnum and nil ~= MyModule.MyEnum.JAN) 
  assert(MyModule.MyEnum == MyModule[3]) 
  assert(3 == #MyModule)  
   
  print("\n-- module definition iteration (ordered) --")
  print(MyModule[idl.KIND](), MyModule[idl.NAME], #MyModule)
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

  local m = idl.module{
    TopModule = {
      idl.module{
        Constants = {
          idl.const{
            SIZE = { idl.short, 10 }
          }
        }
      },
 
      idl.module{
        Attributes = {
          idl.struct{
            Coord = {
              { x = { idl.double } },
              { y = { idl.double } },
              { z = { idl.double } },
            }
          },
          
          idl.typedef{
            StringSeq = {
              idl.string(10), idl.sequence(10)
            },
          }
        }
      },
    }
  }
  
  m[#m+1] = idl.struct{
    NewShapeType = {
      { coords = { m.Attributes.Coord, idl.sequence(m.Constants.SIZE) } },
      { shapesize = { idl.long } },
      { color = { idl.string(m.Constants.SIZE), idl.Key } }
    }
  }

  self:print(m)
end

---
-- print - helper method to print the IDL and the index for data definition
function Tester:print(instance)
    -- print IDL
    idl.print_idl(instance)
  
    -- print index
    local instance = idl.index(instance)
    if instance == nil then return end
    print('index:')
    for i, v in ipairs(instance) do
        print('',v) 
    end
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

--------------------------------------------------------------------------------
