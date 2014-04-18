#!/usr/local/bin/lua
-------------------------------------------------------------------------------
--  (c) 2005-2014 Copyright, Real-Time Innovations, All rights reserved.     --
--                                                                           --
-- Permission to modify and use for internal purposes granted.               --
-- This software is provided "as is", without warranty, express or implied.  --
--                                                                           --
-------------------------------------------------------------------------------
-- File: DataTester.lua 
-- Purpose: Tester for DDSL: Data type definition Domain Specific Language (DSL)
-- Created: Rajive Joshi, 2014 Feb 14
-------------------------------------------------------------------------------

local data = require "Data"

local Data -- top-level data-space (to be defined using 'data' methods)

--------------------------------------------------------------------------------
-- Tester - the unit tests
--------------------------------------------------------------------------------

local Tester = {} -- array of test functions

Tester[#Tester+1] = 'test_module'
function Tester:test_module()

    Data = data.module{} -- define a module

    self:print(Data)
    
    assert(Data ~= nil)
end

Tester[#Tester+1] = 'test_submodule'
function Tester:test_submodule()

  Data.Submodule = data.module{} -- submodule 
  
  self:print(Data.Submodule)
  
  assert(Data.Submodule ~= nil)
end

Tester[#Tester+1] = 'test_enum1'
function Tester:test_enum1()

  Data.Days = data.enum{
    {'MON'}, {'TUE'}, {'WED'}, {'THU'}, {'FRI'}, {'SAT'}, {'SUN'}
  }
  
  self:print(Data.Days)
  
  assert(Data.Days.MON == 0)
  assert(Data.Days.SUN == 6)
end

Tester[#Tester+1] = 'test_enum2'
function Tester:test_enum2()

  Data.Months = data.enum{
    { 'OCT', 10 },
    { 'NOV', 11 },
    { 'DEC', 12 }
  }

  self:print(Data.Months)
  
  assert(Data.Months.OCT == 10)
  assert(Data.Months.DEC == 12)
end

Tester[#Tester+1] = 'test_submodule_enum'
function Tester:test_submodule_enum()

  Data.Submodule.Colors = data.enum{
    { 'RED',   -5 },
    { 'YELLOW',  7 },
    { 'GREEN', -9 },
    { 'PINK' }
  }
  self:print(Data.Submodule.Colors)
  
  assert(Data.Submodule.Colors.YELLOW == 7)
  assert(Data.Submodule.Colors.GREEN == -9)
  assert(Data.Submodule.Colors.PINK == 3)
end

Tester[#Tester+1] = 'test_submodule_struct'
function Tester:test_submodule_struct()

    Data.Submodule.Fruit = data.struct{
      { 'weight', data.double },
      { 'color' , Data.Submodule.Colors },
    }
    
    self:print(Data.Submodule.Fruit)
    
    assert(Data.Submodule.Fruit.weight == 'weight')
    assert(Data.Submodule.Fruit.color == 'color')
end

Tester[#Tester+1] = 'test_user_annotation'
function Tester:test_user_annotation()

    -- user defined annotation
    Data.MyAnnotation = data.annotation{value1 = 42, value2 = 9.0}
    Data.MyAnnotationStruct = data.struct{
      { 'id',     data.long, data.Key },
      { 'org',    data.long, data.Key{GUID=3} },
      { 'weight', data.double, Data.MyAnnotation }, -- default 
      { 'height', data.double, Data.MyAnnotation{} },
      { 'color' , Data.Submodule.Colors, 
                  Data.MyAnnotation{value1 = 10} },
    }
    
    self:print(Data.MyAnnotation)
    self:print(Data.MyAnnotationStruct)
     
    assert(Data.MyAnnotation ~= nil)
    assert(Data.MyAnnotation.value1 == 42)
    assert(Data.MyAnnotation.value2 == 9.0)
end

Tester[#Tester+1] = 'test_atoms'
function Tester:test_atoms()

    Data.Atoms = data.struct{
      { 'myBoolean', data.boolean },
      { 'myOctet', data.octet },
      { 'myChar', data.char },
      { 'myWChar', data.wchar },
      { 'myFloat', data.float },
      { 'myDouble', data.double },
      { 'myLongDouble', data.long_double },
      { 'myShort', data.short },
      { 'myLong', data.long },
      { 'myLongLong', data.long_long },
      { 'myUnsignedShort', data.unsigned_short },
      { 'myUnsignedLong', data.unsigned_long },
      { 'myUnsignedLongLong', data.unsigned_long_long },
    }
    
    self:print(Data.Atoms)
    
    assert(Data.Atoms.myBoolean == 'myBoolean')
    for k, v in pairs(Data.Atoms) do
        if 'string' == type(k) then assert(k == v) end
    end
end

Tester[#Tester+1] = 'test_struct_basic'
function Tester:test_struct_basic()
  
    Data.Name = data.struct{
      -- { first = { data.string(10), data.Key } },
      { 'first', data.string(10), data.Key },
      { 'last',  data.wstring() },
      { 'nicknames',  data.string(), data.sequence(3) },
      { 'aliases',  data.string(7), data.sequence() },
      { 'birthday', Data.Days, data.Optional },
      { 'favorite', Data.Submodule.Colors, data.sequence(2), data.Optional },
    }
    
    self:print(Data.Name)

    assert(Data.Name.first == 'first')
    assert(Data.Name.last == 'last')
    assert(Data.Name.nicknames() == 'nicknames#')
    assert(Data.Name.nicknames(1) == 'nicknames[1]')
    assert(Data.Name.aliases() == 'aliases#')
    assert(Data.Name.aliases(1) == 'aliases[1]')
    assert(Data.Name.birthday == 'birthday')
    assert(Data.Name.favorite() == 'favorite#')
    assert(Data.Name.favorite(1) == 'favorite[1]')
end

Tester[#Tester+1] = 'test_struct_nested'
function Tester:test_struct_nested()

    Data.Address = data.struct{
      data.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
      { 'name', Data.Name },
      { 'street', data.string() },
      { 'city',  data.string(10), 
                    Data.MyAnnotation{value1 = 10, value2 = 17} },
      data.Nested{'FALSE'},
    }

    self:print(Data.Address)
    
    assert(Data.Address.name.first == 'name.first')
    assert(Data.Address.name.nicknames() == 'name.nicknames#')
    assert(Data.Address.name.nicknames(1) == 'name.nicknames[1]')
    assert(Data.Address.street == 'street')
    assert(Data.Address.city == 'city')
end

Tester[#Tester+1] = 'test_union1'
function Tester:test_union1()

  Data.TestUnion1 = data.union{data.short,
    { 1, 
      {'x', data.string() }},
    { 2, 
      {'y', data.long_double }},
    { -- default
      {'z', data.boolean}},
  }

  self:print(Data.TestUnion1)
  
  assert(Data.TestUnion1._d == '#')
  assert(Data.TestUnion1.x == 'x')
  assert(Data.TestUnion1.y == 'y')
  assert(Data.TestUnion1.z == 'z')
end

Tester[#Tester+1] = 'test_union2'
function Tester:test_union2()

  Data.TestUnion2 = data.union{data.char,
    { 'c', 
      {'name', Data.Name, data.Key }},
    { 'a', 
      {'address', Data.Address}},
    { -- default
      {'x', data.double}},
  }

  self:print(Data.TestUnion2)
  
  -- discriminator
  assert(Data.TestUnion2._d == '#')
  
  -- name
  assert(Data.TestUnion2.name.first == 'name.first')
  assert(Data.TestUnion2.name.nicknames() == 'name.nicknames#')  
  assert(Data.TestUnion2.name.nicknames(1) == 'name.nicknames[1]')

  -- address
  assert(Data.TestUnion2.address.name.first == 'address.name.first')
  assert(Data.TestUnion2.address.name.nicknames() == 'address.name.nicknames#')  
  assert(Data.TestUnion2.address.name.nicknames(1) == 'address.name.nicknames[1]')

  -- x
  assert(Data.TestUnion2.x == 'x')
end

Tester[#Tester+1] = 'test_union3'
function Tester:test_union3()

  Data.TestUnion3 = data.union{Data.Days,
    { 'MON', 
      {'name', Data.Name}},
    { 'TUE', 
      {'address', Data.Address}},
    { -- default
      {'x', data.double}},    
    data.Extensibility{'EXTENSIBLE_EXTENSIBILITY',domain=5},
  }

  self:print(Data.TestUnion3)

  -- discriminator
  assert(Data.TestUnion3._d == '#')
  
  -- name
  assert(Data.TestUnion3.name.first == 'name.first')
  assert(Data.TestUnion3.name.nicknames() == 'name.nicknames#')  
  assert(Data.TestUnion3.name.nicknames(1) == 'name.nicknames[1]')

  -- address
  assert(Data.TestUnion3.address.name.first == 'address.name.first')
  assert(Data.TestUnion3.address.name.nicknames() == 'address.name.nicknames#')  
  assert(Data.TestUnion3.address.name.nicknames(1) == 'address.name.nicknames[1]')

  -- x
  assert(Data.TestUnion3.x == 'x')
  
  -- annotation
  assert(Data.TestUnion3[data.MODEL][data.ANNOTATION][1] ~= nil)
end

Tester[#Tester+1] = 'test_union4'
function Tester:test_union4()

  Data.NameOrAddress = data.union{data.boolean,
    { true, 
      {'name', Data.Name}},
    { false, 
      {'address', Data.Address}},
  }
  
  self:print(Data.NameOrAddress)

  -- discriminator
  assert(Data.NameOrAddress._d == '#')
  
  -- name
  assert(Data.NameOrAddress.name.first == 'name.first')
  assert(Data.NameOrAddress.name.nicknames() == 'name.nicknames#')  
  assert(Data.NameOrAddress.name.nicknames(1) == 'name.nicknames[1]')

  -- address
  assert(Data.NameOrAddress.address.name.first == 'address.name.first')
  assert(Data.NameOrAddress.address.name.nicknames() == 'address.name.nicknames#')  
  assert(Data.NameOrAddress.address.name.nicknames(1) == 'address.name.nicknames[1]')
end

Tester[#Tester+1] = 'test_struct_complex1'
function Tester:test_struct_complex1()

  Data.Company = data.struct{
    { 'entity', Data.NameOrAddress},
    { 'hq', data.string(), data.sequence(2) },
    { 'offices', Data.Address, data.sequence(10) },
    { 'employees', Data.Name, data.sequence() }
  }

  self:print(Data.Company)
 
  -- TODO: fix failing test
  --[[ 
  -- entity
  assert(Data.Company.entity._d == 'entity#')
  assert(Data.Company.entity.name.first == 'entity.name.first')
  assert(Data.Company.entity.name.nicknames() == 'entity.name.nicknames#')  
  assert(Data.Company.entity.name.nicknames(1) == 'entity.name.nicknames[1]')
  assert(Data.Company.entity.address.name.first == 'entity.address.name.first')
  assert(Data.Company.entity.address.name.nicknames() == 'entity.address.name.nicknames#')  
  assert(Data.Company.entity.address.name.nicknames(1) == 'entity.address.name.nicknames[1]')
  --]]
  
  -- hq
  assert(Data.Company.hq() == 'hq#')
  assert(Data.Company.hq(1) == 'hq[1]')
  
  -- offices
  assert(Data.Company.offices() == 'offices#')
  assert(Data.Company.offices(1).name.first == 'offices[1].name.first')
  assert(Data.Company.offices(1).name.nicknames() == 'offices[1].name.nicknames#')  
  assert(Data.Company.offices(1).name.nicknames(1) == 'offices[1].name.nicknames[1]')

  -- employees
  assert(Data.Company.employees() == 'employees#')
  assert(Data.Company.employees(1).first == 'employees[1].first')
  assert(Data.Company.employees(1).nicknames() == 'employees[1].nicknames#')  
  assert(Data.Company.employees(1).nicknames(1) == 'employees[1].nicknames[1]')
end

Tester[#Tester+1] = 'test_struct_complex2'
function Tester:test_struct_complex2()

  Data.BigCompany = data.struct{
    { 'parent', Data.Company},
    { 'divisions', Data.Company, data.sequence()}
  }

  self:print(Data.BigCompany)

  -- TODO: fix failing test
  --[[ 
  -- parent.entity
  assert(Data.BigCompany.parent.entity._d == 'parent.entity#')
  assert(Data.BigCompany.parent.entity.name.first == 'parent.entity.name.first')
  assert(Data.BigCompany.parent.entity.name.nicknames() == 'parent.entity.name.nicknames#')  
  assert(Data.BigCompany.parent.entity.name.nicknames(1) == 'parent.entity.name.nicknames[1]')
  assert(Data.BigCompany.parent.entity.address.name.first == 'parent.entity.address.name.first')
  assert(Data.BigCompany.parent.entity.address.name.nicknames() == 'parent.entity.address.name.nicknames#')  
  assert(Data.BigCompany.parent.entity.address.name.nicknames(1) == 'parent.entity.address.name.nicknames[1]')
  --]]
  
  -- parent.hq
  assert(Data.BigCompany.parent.hq() == 'parent.hq#')
  assert(Data.BigCompany.parent.hq(1) == 'parent.hq[1]')
  
  -- parent.offices
  assert(Data.BigCompany.parent.offices() == 'parent.offices#')
  assert(Data.BigCompany.parent.offices(1).name.first == 'parent.offices[1].name.first')
  assert(Data.BigCompany.parent.offices(1).name.nicknames() == 'parent.offices[1].name.nicknames#')  
  assert(Data.BigCompany.parent.offices(1).name.nicknames(1) == 'parent.offices[1].name.nicknames[1]')

  -- parent.employees
  assert(Data.BigCompany.parent.employees() == 'parent.employees#')
  assert(Data.BigCompany.parent.employees(1).first == 'parent.employees[1].first')
  assert(Data.BigCompany.parent.employees(1).nicknames() == 'parent.employees[1].nicknames#')  
  assert(Data.BigCompany.parent.employees(1).nicknames(1) == 'parent.employees[1].nicknames[1]')


  -- divisions
  assert(Data.BigCompany.divisions() == 'divisions#')
  
  -- TODO: fix failing test
  --[[ 
  -- divisions(1).entity
  assert(Data.BigCompany.divisions(1).entity._d == 'divisions[1].entity#')
  assert(Data.BigCompany.divisions(1).entity.name.first == 'divisions[1].entity.name.first')
  assert(Data.BigCompany.divisions(1).entity.name.nicknames() == 'divisions[1].entity.name.nicknames#')  
  assert(Data.BigCompany.divisions(1).entity.name.nicknames(1) == 'divisions[1].entity.name.nicknames[1]')
  assert(Data.BigCompany.divisions(1).entity.address.name.first == 'divisions[1].entity.address.name.first')
  assert(Data.BigCompany.divisions(1).entity.address.name.nicknames() == 'divisions[1].entity.address.name.nicknames#')  
  assert(Data.BigCompany.divisions(1).entity.address.name.nicknames(1) == 'divisions[1].entity.address.name.nicknames[1]')
  --]]
  
  -- divisions(1).hq
  assert(Data.BigCompany.divisions(1).hq() == 'divisions[1].hq#')
  assert(Data.BigCompany.divisions(1).hq(1) == 'divisions[1].hq[1]')
  
  -- divisions(1).offices
  assert(Data.BigCompany.divisions(1).offices() == 'divisions[1].offices#')
  assert(Data.BigCompany.divisions(1).offices(1).name.first == 'divisions[1].offices[1].name.first')
  assert(Data.BigCompany.divisions(1).offices(1).name.nicknames() == 'divisions[1].offices[1].name.nicknames#')  
  assert(Data.BigCompany.divisions(1).offices(1).name.nicknames(1) == 'divisions[1].offices[1].name.nicknames[1]')

  -- divisions(1).employees
  assert(Data.BigCompany.divisions(1).employees() == 'divisions[1].employees#')
  assert(Data.BigCompany.divisions(1).employees(1).first == 'divisions[1].employees[1].first')
  assert(Data.BigCompany.divisions(1).employees(1).nicknames() == 'divisions[1].employees[1].nicknames#')  
  assert(Data.BigCompany.divisions(1).employees(1).nicknames(1) == 'divisions[1].employees[1].nicknames[1]')

end

Tester[#Tester+1] = 'test_struct_inheritance1'
function Tester:test_struct_inheritance1()

  Data.FullName = data.struct{Data.Name,
    { 'middle',  data.string() },
    data.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
  }

  self:print(Data.FullName)
  
  -- base: Name
  assert(Data.FullName.first == 'first')
  assert(Data.FullName.last == 'last')
  assert(Data.FullName.nicknames() == 'nicknames#')
  assert(Data.FullName.nicknames(1) == 'nicknames[1]')
  assert(Data.FullName.aliases() == 'aliases#')
  assert(Data.FullName.aliases(1) == 'aliases[1]')
  assert(Data.FullName.birthday == 'birthday')
  assert(Data.FullName.favorite() == 'favorite#')
  assert(Data.FullName.favorite(1) == 'favorite[1]')
  
  -- FullName
  assert(Data.FullName.middle == 'middle')
end

Tester[#Tester+1] = 'test_struct_inheritance2'
function Tester:test_struct_inheritance2()

  Data.Contact = data.struct{Data.FullName,
    { 'address',  Data.Address },
    { 'email',  data.string() },
  }

  self:print(Data.Contact)

  -- base: FullName
  assert(Data.Contact.first == 'first')
  assert(Data.Contact.last == 'last')
  assert(Data.Contact.nicknames() == 'nicknames#')
  assert(Data.Contact.nicknames(1) == 'nicknames[1]')
  assert(Data.Contact.aliases() == 'aliases#')
  assert(Data.Contact.aliases(1) == 'aliases[1]')
  assert(Data.Contact.birthday == 'birthday')
  assert(Data.Contact.favorite() == 'favorite#')
  assert(Data.Contact.favorite(1) == 'favorite[1]')
  assert(Data.Contact.middle == 'middle')
  
  -- Contact
  assert(Data.Contact.address.name.first == 'address.name.first')
  assert(Data.Contact.address.name.first == 'address.name.first')
  assert(Data.Contact.address.name.nicknames() == 'address.name.nicknames#')
  assert(Data.Contact.address.name.nicknames(1) == 'address.name.nicknames[1]')
  assert(Data.Contact.address.street == 'address.street')
  assert(Data.Contact.address.city == 'address.city')
    
  assert(Data.Contact.email == 'email')
end

Tester[#Tester+1] = 'test_struct_inheritance3'
function Tester:test_struct_inheritance3()

  Data.Tasks = data.struct{
    { 'contact',  Data.Contact },
    { 'day',  Data.Days },
  }

  self:print(Data.Tasks)

  -- Tasks.contact
  assert(Data.Tasks.contact.first == 'contact.first')
  assert(Data.Tasks.contact.last == 'contact.last')
  assert(Data.Tasks.contact.nicknames() == 'contact.nicknames#')
  assert(Data.Tasks.contact.nicknames(1) == 'contact.nicknames[1]')
  assert(Data.Tasks.contact.aliases() == 'contact.aliases#')
  assert(Data.Tasks.contact.aliases(1) == 'contact.aliases[1]')
  assert(Data.Tasks.contact.birthday == 'contact.birthday')
  assert(Data.Tasks.contact.favorite() == 'contact.favorite#')
  assert(Data.Tasks.contact.favorite(1) == 'contact.favorite[1]')
  assert(Data.Tasks.contact.middle == 'contact.middle')
  
  -- Tasks.contact.address
  assert(Data.Tasks.contact.address.name.first == 'contact.address.name.first')
  assert(Data.Tasks.contact.address.name.first == 'contact.address.name.first')
  assert(Data.Tasks.contact.address.name.nicknames() == 'contact.address.name.nicknames#')
  assert(Data.Tasks.contact.address.name.nicknames(1) == 'contact.address.name.nicknames[1]')
  assert(Data.Tasks.contact.address.street == 'contact.address.street')
  assert(Data.Tasks.contact.address.city == 'contact.address.city')
    
  assert(Data.Tasks.contact.email == 'contact.email')
  
  assert(Data.Tasks.day == 'day')
end

Tester[#Tester+1] = 'test_struct_inheritance4'
function Tester:test_struct_inheritance4()

  Data.Calendar = data.struct{
    { 'tasks',  Data.Tasks, data.sequence() },
  }

  self:print(Data.Calendar)
  
  assert(Data.Calendar.tasks() == 'tasks#')
   
  -- tasks(1).contact
  assert(Data.Calendar.tasks(1).contact.first == 'tasks[1].contact.first')
  assert(Data.Calendar.tasks(1).contact.last == 'tasks[1].contact.last')
  assert(Data.Calendar.tasks(1).contact.nicknames() == 'tasks[1].contact.nicknames#')
  assert(Data.Calendar.tasks(1).contact.nicknames(1) == 'tasks[1].contact.nicknames[1]')
  assert(Data.Calendar.tasks(1).contact.aliases() == 'tasks[1].contact.aliases#')
  assert(Data.Calendar.tasks(1).contact.aliases(1) == 'tasks[1].contact.aliases[1]')
  assert(Data.Calendar.tasks(1).contact.birthday == 'tasks[1].contact.birthday')
  assert(Data.Calendar.tasks(1).contact.favorite() == 'tasks[1].contact.favorite#')
  assert(Data.Calendar.tasks(1).contact.favorite(1) == 'tasks[1].contact.favorite[1]')
  assert(Data.Calendar.tasks(1).contact.middle == 'tasks[1].contact.middle')
  
  -- tasks(1).contact.address
  assert(Data.Calendar.tasks(1).contact.address.name.first == 'tasks[1].contact.address.name.first')
  assert(Data.Calendar.tasks(1).contact.address.name.first == 'tasks[1].contact.address.name.first')
  assert(Data.Calendar.tasks(1).contact.address.name.nicknames() == 'tasks[1].contact.address.name.nicknames#')
  assert(Data.Calendar.tasks(1).contact.address.name.nicknames(1) == 'tasks[1].contact.address.name.nicknames[1]')
  assert(Data.Calendar.tasks(1).contact.address.street == 'tasks[1].contact.address.street')
  assert(Data.Calendar.tasks(1).contact.address.city == 'tasks[1].contact.address.city')
    
  assert(Data.Calendar.tasks(1).contact.email == 'tasks[1].contact.email')
  
  assert(Data.Calendar.tasks(1).day == 'tasks[1].day')
end

Tester[#Tester+1] = 'test_typedef'
function Tester:test_typedef()  

  -- typedefs
  Data.MyDouble = data.typedef{data.double}
  Data.MyDouble2 = data.typedef{Data.MyDouble}
  Data.MyString = data.typedef{data.string(10) }
  
  Data.MyName = data.typedef{Data.Name}
  Data.MyName2 = data.typedef{Data.MyName}
  
  Data.MyAddress = data.typedef{Data.Address}
  Data.MyAddress2 = data.typedef{Data.MyAddress}
  
  Data.MyTypedef = data.struct{
    { 'rawDouble', data.double },
    { 'myDouble', Data.MyDouble },
    { 'myDouble2', Data.MyDouble2 },
    
    { 'name',  Data.Name },
    { 'myName',  Data.MyName },
    { 'myName2',  Data.MyName2 },
    
    { 'address', Data.Address },
    { 'myAddress', Data.MyAddress },
    { 'myAddress2', Data.MyAddress2 },
  }

  self:print(Data.MyDouble)
  self:print(Data.MyDouble2)  
  self:print(Data.MyString)
        
  self:print(Data.MyName)
  self:print(Data.MyName2)
  
  self:print(Data.MyAddress)
  self:print(Data.MyAddress2)
  
  self:print(Data.MyTypedef)
  
  -- rawDouble
  assert(Data.MyTypedef.rawDouble == 'rawDouble')
  assert(Data.MyTypedef.myDouble == 'myDouble')
  assert(Data.MyTypedef.myDouble2 == 'myDouble2')
  -- name
  assert(Data.MyTypedef.name.first == 'name.first')
  assert(Data.MyTypedef.name.nicknames() == 'name.nicknames#')  
  assert(Data.MyTypedef.name.nicknames(1) == 'name.nicknames[1]')
  -- myName
  assert(Data.MyTypedef.myName.first == 'myName.first')
  assert(Data.MyTypedef.myName.nicknames() == 'myName.nicknames#')  
  assert(Data.MyTypedef.myName.nicknames(1) == 'myName.nicknames[1]')
  -- myAddress2
  assert(Data.MyTypedef.myAddress2.name.first == 'myAddress2.name.first')
  assert(Data.MyTypedef.myAddress2.name.nicknames() == 'myAddress2.name.nicknames#')  
  assert(Data.MyTypedef.myAddress2.name.nicknames(1) == 'myAddress2.name.nicknames[1]')
end

Tester[#Tester+1] = 'test_typedef_seq'
function Tester:test_typedef_seq()  

  Data.MyDoubleSeq = data.typedef{Data.MyDouble, data.sequence() }
  Data.MyStringSeq = data.typedef{Data.MyString, data.sequence(10) }
  
  Data.NameSeq = data.typedef{Data.Name, data.sequence(10) }
  Data.NameSeqSeq = data.typedef{Data.NameSeq, data.sequence(10) }
  
  Data.MyNameSeq = data.typedef{Data.MyName, data.sequence(10) }
  Data.MyNameSeqSeq = data.typedef{Data.MyNameSeq, data.sequence(10) }
  
  Data.MyTypedefSeq = data.struct{
    { 'myDoubleSeq', Data.MyDouble, data.sequence() },
    { 'myDoubleSeqA', Data.MyDoubleSeq },
    { 'myStringSeqA', Data.MyStringSeq },
    
    { 'nameSeq', Data.Name, data.sequence() },
    { 'nameSeqA', Data.NameSeq },
    { 'nameSeqSeq', Data.NameSeq, data.sequence() },
    { 'nameSeqSeqA', Data.NameSeqSeq },
    { 'nameSeqSeqASeq', Data.NameSeqSeq, data.sequence() },
  
    { 'myNameSeq', Data.MyName, data.sequence() },
    { 'myNameSeqA', Data.MyNameSeq },
    { 'myNameSeqSeq', Data.MyNameSeq, data.sequence() },
    { 'myNameSeqSeqA', Data.MyNameSeqSeq },
    { 'myNameSeqSeqASeq', Data.MyNameSeqSeq, data.sequence() },
  }

  self:print(Data.MyDoubleSeq)
  self:print(Data.MyStringSeq)
  
  self:print(Data.NameSeq)
  self:print(Data.NameSeqSeq)

  self:print(Data.MyNameSeq)
  self:print(Data.MyNameSeqSeq)
  
  self:print(Data.MyTypedefSeq)
  
  -- nameSeq
  assert(Data.MyTypedefSeq.nameSeq() == 'nameSeq#')
  assert(Data.MyTypedefSeq.nameSeq(1).first == 'nameSeq[1].first')  
  assert(Data.MyTypedefSeq.nameSeq(1).nicknames() == 'nameSeq[1].nicknames#') 
  assert(Data.MyTypedefSeq.nameSeq(1).nicknames(1) == 'nameSeq[1].nicknames[1]')  

  -- nameSeqA
  assert(Data.MyTypedefSeq.nameSeqA() == 'nameSeqA#')
  assert(Data.MyTypedefSeq.nameSeqA(1).first == 'nameSeqA[1].first')  
  assert(Data.MyTypedefSeq.nameSeqA(1).nicknames() == 'nameSeqA[1].nicknames#') 
  assert(Data.MyTypedefSeq.nameSeqA(1).nicknames(1) == 'nameSeqA[1].nicknames[1]')  

  -- nameSeqSeq
  assert(Data.MyTypedefSeq.nameSeqSeq() == 'nameSeqSeq#') 
  assert(Data.MyTypedefSeq.nameSeqSeq(1)() == 'nameSeqSeq[1]#')
  assert(Data.MyTypedefSeq.nameSeqSeq(1)(1).first == 'nameSeqSeq[1][1].first')
  assert(Data.MyTypedefSeq.nameSeqSeq(1)(1).nicknames() == 'nameSeqSeq[1][1].nicknames#')
  assert(Data.MyTypedefSeq.nameSeqSeq(1)(1).nicknames(1) == 'nameSeqSeq[1][1].nicknames[1]')
  
  -- nameSeqSeqA
  assert(Data.MyTypedefSeq.nameSeqSeqA() == 'nameSeqSeqA#') 
  assert(Data.MyTypedefSeq.nameSeqSeqA(1)() == 'nameSeqSeqA[1]#')
  assert(Data.MyTypedefSeq.nameSeqSeqA(1)(1).first == 'nameSeqSeqA[1][1].first')
  assert(Data.MyTypedefSeq.nameSeqSeqA(1)(1).nicknames() == 'nameSeqSeqA[1][1].nicknames#')
  assert(Data.MyTypedefSeq.nameSeqSeqA(1)(1).nicknames(1) == 'nameSeqSeqA[1][1].nicknames[1]')

  -- nameSeqSeqASeq
  assert(Data.MyTypedefSeq.nameSeqSeqASeq() == 'nameSeqSeqASeq#') 
  assert(Data.MyTypedefSeq.nameSeqSeqASeq(1)() == 'nameSeqSeqASeq[1]#')
  assert(Data.MyTypedefSeq.nameSeqSeqASeq(1)(1)() == 'nameSeqSeqASeq[1][1]#')
  assert(Data.MyTypedefSeq.nameSeqSeqASeq(1)(1)(1).first == 'nameSeqSeqASeq[1][1][1].first')
  assert(Data.MyTypedefSeq.nameSeqSeqASeq(1)(1)(1).nicknames() == 'nameSeqSeqASeq[1][1][1].nicknames#')
  assert(Data.MyTypedefSeq.nameSeqSeqASeq(1)(1)(1).nicknames(1) == 'nameSeqSeqASeq[1][1][1].nicknames[1]')

  -- myNameSeq
  assert(Data.MyTypedefSeq.myNameSeq() == 'myNameSeq#')
  assert(Data.MyTypedefSeq.myNameSeq(1).first == 'myNameSeq[1].first')  
  assert(Data.MyTypedefSeq.myNameSeq(1).nicknames() == 'myNameSeq[1].nicknames#') 
  assert(Data.MyTypedefSeq.myNameSeq(1).nicknames(1) == 'myNameSeq[1].nicknames[1]')  

  -- myNameSeqA
  assert(Data.MyTypedefSeq.myNameSeqA() == 'myNameSeqA#')
  assert(Data.MyTypedefSeq.myNameSeqA(1).first == 'myNameSeqA[1].first')  
  assert(Data.MyTypedefSeq.myNameSeqA(1).nicknames() == 'myNameSeqA[1].nicknames#') 
  assert(Data.MyTypedefSeq.myNameSeqA(1).nicknames(1) == 'myNameSeqA[1].nicknames[1]')  

  -- myNameSeqSeq
  assert(Data.MyTypedefSeq.myNameSeqSeq() == 'myNameSeqSeq#') 
  assert(Data.MyTypedefSeq.myNameSeqSeq(1)() == 'myNameSeqSeq[1]#')
  assert(Data.MyTypedefSeq.myNameSeqSeq(1)(1).first == 'myNameSeqSeq[1][1].first')
  assert(Data.MyTypedefSeq.myNameSeqSeq(1)(1).nicknames() == 'myNameSeqSeq[1][1].nicknames#')
  assert(Data.MyTypedefSeq.myNameSeqSeq(1)(1).nicknames(1) == 'myNameSeqSeq[1][1].nicknames[1]')
  
  -- myNameSeqSeqA
  assert(Data.MyTypedefSeq.myNameSeqSeqA() == 'myNameSeqSeqA#') 
  assert(Data.MyTypedefSeq.myNameSeqSeqA(1)() == 'myNameSeqSeqA[1]#')
  assert(Data.MyTypedefSeq.myNameSeqSeqA(1)(1).first == 'myNameSeqSeqA[1][1].first')
  assert(Data.MyTypedefSeq.myNameSeqSeqA(1)(1).nicknames() == 'myNameSeqSeqA[1][1].nicknames#')
  assert(Data.MyTypedefSeq.myNameSeqSeqA(1)(1).nicknames(1) == 'myNameSeqSeqA[1][1].nicknames[1]')

  -- myNameSeqSeqASeq
  assert(Data.MyTypedefSeq.myNameSeqSeqASeq() == 'myNameSeqSeqASeq#') 
  assert(Data.MyTypedefSeq.myNameSeqSeqASeq(1)() == 'myNameSeqSeqASeq[1]#')
  assert(Data.MyTypedefSeq.myNameSeqSeqASeq(1)(1)() == 'myNameSeqSeqASeq[1][1]#')
  assert(Data.MyTypedefSeq.myNameSeqSeqASeq(1)(1)(1).first == 'myNameSeqSeqASeq[1][1][1].first')
  assert(Data.MyTypedefSeq.myNameSeqSeqASeq(1)(1)(1).nicknames() == 'myNameSeqSeqASeq[1][1][1].nicknames#')
  assert(Data.MyTypedefSeq.myNameSeqSeqASeq(1)(1)(1).nicknames(1) == 'myNameSeqSeqASeq[1][1][1].nicknames[1]')
end

Tester[#Tester+1] = 'test_arrays1'
function Tester:test_arrays1()

    -- Arrays
    Data.MyArrays1 = data.struct{
      -- 1-D
      { 'ints', data.double, data.array(3) },
    
      -- 2-D
      { 'days', Data.Days, data.array(6, 9) },
      
      -- 3-D
      { 'names', Data.Name, data.array(12, 15, 18) },
    }

	-- structure with arrays
	self:print(Data.MyArrays1)
	
	-- ints
	assert(Data.MyArrays1.ints() == 'ints#')
	assert(Data.MyArrays1.ints(1) == 'ints[1]')
	
	-- days
	assert(Data.MyArrays1.days() == 'days#')
	assert(Data.MyArrays1.days(1)() == 'days[1]#')
	assert(Data.MyArrays1.days(1)(1) == 'days[1][1]')
	
	-- names
	assert(Data.MyArrays1.names() == 'names#')
	assert(Data.MyArrays1.names(1)() == 'names[1]#')
	assert(Data.MyArrays1.names(1)(1)() == 'names[1][1]#')
	assert(Data.MyArrays1.names(1)(1)(1).first == 'names[1][1][1].first')
	assert(Data.MyArrays1.names(1)(1)(1).nicknames() == 'names[1][1][1].nicknames#')
	assert(Data.MyArrays1.names(1)(1)(1).nicknames(1) == 'names[1][1][1].nicknames[1]')
end

Tester[#Tester+1] = 'test_arrays2'
function Tester:test_arrays2()

    Data.MyArrays2 = data.union{Data.Days,
      -- 1-D
      { 'MON',
        {'ints', data.double, data.array(3) }},
    
      -- 2-D
      { 'TUE',
        { 'days', Data.Days, data.array(6, 9) }},
      
      -- 3-D
      {--
        { 'names', Data.Name, data.array(12, 15, 18) }},  
    }

	-- union with arrays
	self:print(Data.MyArrays2)
	
	-- ints
	assert(Data.MyArrays2.ints() == 'ints#')
	assert(Data.MyArrays2.ints(1) == 'ints[1]')
	
	-- days
	assert(Data.MyArrays2.days() == 'days#')
	assert(Data.MyArrays2.days(1)() == 'days[1]#')
	assert(Data.MyArrays2.days(1)(1) == 'days[1][1]')
	
	-- names
	assert(Data.MyArrays2.names() == 'names#')
	assert(Data.MyArrays2.names(1)() == 'names[1]#')
	assert(Data.MyArrays2.names(1)(1)() == 'names[1][1]#')
	assert(Data.MyArrays2.names(1)(1)(1).first == 'names[1][1][1].first')
	assert(Data.MyArrays2.names(1)(1)(1).nicknames() == 'names[1][1][1].nicknames#')
	assert(Data.MyArrays2.names(1)(1)(1).nicknames(1) == 'names[1][1][1].nicknames[1]')
end

Tester[#Tester+1] = 'test_arrays3'
function Tester:test_arrays3()
	Data.MyNameArray = data.typedef{Data.Name, data.array(10) }
	Data.MyNameArray2 = data.typedef{Data.MyNameArray, data.array(10) }
	Data.MyName2x2 = data.typedef{Data.Name, data.array(2, 3) }
	
	Data.MyArrays3 = data.struct{
		-- 1-D
		{ 'myNames', Data.MyNameArray },

		-- 2-D
		{ 'myNamesArray', Data.MyNameArray, data.array(10) },
	
		-- 2-D
		{ 'myNames2', Data.MyNameArray2 },
				
		-- 3-D
		{ 'myNames2Array', Data.MyNameArray2, data.array(10) },

		-- 4-D
		{ 'myNames2Array2', Data.MyNameArray2, data.array(10, 20) },
		
		-- 2D: 2x2
		{ 'myName2x2', Data.MyName2x2 },

		-- 4D: 2x2 x2x2
		{ 'myName2x2x2x2', Data.MyName2x2, data.array(4,5) },
	}

    self:print(Data.MyNameArray)
    self:print(Data.MyNameArray2)
    self:print(Data.MyName2x2)
	self:print(Data.MyArrays3)

	-- myNames
	assert(Data.MyArrays3.myNames() == 'myNames#')
	assert(Data.MyArrays3.myNames(1).first == 'myNames[1].first')
	assert(Data.MyArrays3.myNames(1).nicknames() == 'myNames[1].nicknames#')
	assert(Data.MyArrays3.myNames(1).nicknames(1) == 'myNames[1].nicknames[1]')
	
	-- myNamesArray
	assert(Data.MyArrays3.myNamesArray() == 'myNamesArray#')
	assert(Data.MyArrays3.myNamesArray(1)() == 'myNamesArray[1]#')
	assert(Data.MyArrays3.myNamesArray(1)(1).first == 'myNamesArray[1][1].first')
	assert(Data.MyArrays3.myNamesArray(1)(1).nicknames() == 'myNamesArray[1][1].nicknames#')
	assert(Data.MyArrays3.myNamesArray(1)(1).nicknames(1) == 'myNamesArray[1][1].nicknames[1]')
	
	-- myNames2
	assert(Data.MyArrays3.myNames2() == 'myNames2#')
	assert(Data.MyArrays3.myNames2(1)() == 'myNames2[1]#')
	assert(Data.MyArrays3.myNames2(1)(1).first == 'myNames2[1][1].first')
	assert(Data.MyArrays3.myNames2(1)(1).nicknames() == 'myNames2[1][1].nicknames#')
	assert(Data.MyArrays3.myNames2(1)(1).nicknames(1) == 'myNames2[1][1].nicknames[1]')

	-- myNames2Array
	assert(Data.MyArrays3.myNames2Array() == 'myNames2Array#')
	assert(Data.MyArrays3.myNames2Array(1)() == 'myNames2Array[1]#')
	assert(Data.MyArrays3.myNames2Array(1)(1)() == 'myNames2Array[1][1]#')
	assert(Data.MyArrays3.myNames2Array(1)(1)(1).first == 'myNames2Array[1][1][1].first')
	assert(Data.MyArrays3.myNames2Array(1)(1)(1).nicknames() == 'myNames2Array[1][1][1].nicknames#')
	assert(Data.MyArrays3.myNames2Array(1)(1)(1).nicknames(1) == 'myNames2Array[1][1][1].nicknames[1]')

	-- myNames2Array2
	assert(Data.MyArrays3.myNames2Array2() == 'myNames2Array2#')
	assert(Data.MyArrays3.myNames2Array2(1)() == 'myNames2Array2[1]#')
	assert(Data.MyArrays3.myNames2Array2(1)(1)() == 'myNames2Array2[1][1]#')
	assert(Data.MyArrays3.myNames2Array2(1)(1)(1)() == 'myNames2Array2[1][1][1]#')
	assert(Data.MyArrays3.myNames2Array2(1)(1)(1)(1).first == 'myNames2Array2[1][1][1][1].first')
	assert(Data.MyArrays3.myNames2Array2(1)(1)(1)(1).nicknames() == 'myNames2Array2[1][1][1][1].nicknames#')
	assert(Data.MyArrays3.myNames2Array2(1)(1)(1)(1).nicknames(1) == 'myNames2Array2[1][1][1][1].nicknames[1]')

	-- myName2x2
	assert(Data.MyArrays3.myName2x2() == 'myName2x2#')
	assert(Data.MyArrays3.myName2x2(1)() == 'myName2x2[1]#')
	assert(Data.MyArrays3.myName2x2(1)(1).first == 'myName2x2[1][1].first')
	assert(Data.MyArrays3.myName2x2(1)(1).nicknames() == 'myName2x2[1][1].nicknames#')
	assert(Data.MyArrays3.myName2x2(1)(1).nicknames(1) == 'myName2x2[1][1].nicknames[1]')

	-- myName2x2x2x2
	assert(Data.MyArrays3.myName2x2x2x2() == 'myName2x2x2x2#')
	assert(Data.MyArrays3.myName2x2x2x2(1)() == 'myName2x2x2x2[1]#')
	assert(Data.MyArrays3.myName2x2x2x2(1)(1)() == 'myName2x2x2x2[1][1]#')
	assert(Data.MyArrays3.myName2x2x2x2(1)(1)(1)() == 'myName2x2x2x2[1][1][1]#')
	assert(Data.MyArrays3.myName2x2x2x2(1)(1)(1)(1).first == 'myName2x2x2x2[1][1][1][1].first')
	assert(Data.MyArrays3.myName2x2x2x2(1)(1)(1)(1).nicknames() == 'myName2x2x2x2[1][1][1][1].nicknames#')
	assert(Data.MyArrays3.myName2x2x2x2(1)(1)(1)(1).nicknames(1) == 'myName2x2x2x2[1][1][1][1].nicknames[1]')
end

Tester[#Tester+1] = 'test_sequences_multi_dim'
function Tester:test_sequences_multi_dim()
	Data.MyNameSeq1 = data.typedef{Data.Name, data.sequence(10) }
	Data.MyNameSeq2 = data.typedef{Data.MyNameSeq, data.sequence(10) }
	Data.MyNameSeq2x2 = data.typedef{Data.Name, data.sequence(2, 3) }
	
	Data.MySeqs3 = data.struct{
		-- 1-D
		{ 'myNames', Data.MyNameSeq },

		-- 2-D
		{ 'myNamesSeq', Data.MyNameSeq1, data.sequence(10) },
	
		-- 2-D
		{ 'myNames2', Data.MyNameSeq2 },
				
		-- 3-D
		{ 'myNames2Seq', Data.MyNameSeq2, data.sequence(10) },

		-- 4-D
		{ 'myNames2Seq2', Data.MyNameSeq2, data.sequence(10, 20) },
		
		-- 2D: 2x2
		{ 'myName2x2', Data.MyName2x2 },

		-- 4D: 2x2 x2x2
		{ 'myName2x2x2x2', Data.MyNameSeq2x2, data.sequence(4,5) },
	}

    self:print(Data.MyNameSeq1)
    self:print(Data.MyNameSeq2)
    self:print(Data.MySeqs3)
	self:print(Data.MyNameSeq2x2)

	-- myNames
	assert(Data.MySeqs3.myNames() == 'myNames#')
	assert(Data.MySeqs3.myNames(1).first == 'myNames[1].first')
	assert(Data.MySeqs3.myNames(1).nicknames() == 'myNames[1].nicknames#')
	assert(Data.MySeqs3.myNames(1).nicknames(1) == 'myNames[1].nicknames[1]')
	
	-- myNamesSeq
	assert(Data.MySeqs3.myNamesSeq() == 'myNamesSeq#')
	assert(Data.MySeqs3.myNamesSeq(1)() == 'myNamesSeq[1]#')
	assert(Data.MySeqs3.myNamesSeq(1)(1).first == 'myNamesSeq[1][1].first')
	assert(Data.MySeqs3.myNamesSeq(1)(1).nicknames() == 'myNamesSeq[1][1].nicknames#')
	assert(Data.MySeqs3.myNamesSeq(1)(1).nicknames(1) == 'myNamesSeq[1][1].nicknames[1]')
	
	-- myNames2
	assert(Data.MySeqs3.myNames2() == 'myNames2#')
	assert(Data.MySeqs3.myNames2(1)() == 'myNames2[1]#')
	assert(Data.MySeqs3.myNames2(1)(1).first == 'myNames2[1][1].first')
	assert(Data.MySeqs3.myNames2(1)(1).nicknames() == 'myNames2[1][1].nicknames#')
	assert(Data.MySeqs3.myNames2(1)(1).nicknames(1) == 'myNames2[1][1].nicknames[1]')

	-- myNames2Seq
	assert(Data.MySeqs3.myNames2Seq() == 'myNames2Seq#')
	assert(Data.MySeqs3.myNames2Seq(1)() == 'myNames2Seq[1]#')
	assert(Data.MySeqs3.myNames2Seq(1)(1)() == 'myNames2Seq[1][1]#')
	assert(Data.MySeqs3.myNames2Seq(1)(1)(1).first == 'myNames2Seq[1][1][1].first')
	assert(Data.MySeqs3.myNames2Seq(1)(1)(1).nicknames() == 'myNames2Seq[1][1][1].nicknames#')
	assert(Data.MySeqs3.myNames2Seq(1)(1)(1).nicknames(1) == 'myNames2Seq[1][1][1].nicknames[1]')

	-- myNames2Seq2
	assert(Data.MySeqs3.myNames2Seq2() == 'myNames2Seq2#')
	assert(Data.MySeqs3.myNames2Seq2(1)() == 'myNames2Seq2[1]#')
	assert(Data.MySeqs3.myNames2Seq2(1)(1)() == 'myNames2Seq2[1][1]#')
	assert(Data.MySeqs3.myNames2Seq2(1)(1)(1)() == 'myNames2Seq2[1][1][1]#')
	assert(Data.MySeqs3.myNames2Seq2(1)(1)(1)(1).first == 'myNames2Seq2[1][1][1][1].first')
	assert(Data.MySeqs3.myNames2Seq2(1)(1)(1)(1).nicknames() == 'myNames2Seq2[1][1][1][1].nicknames#')
	assert(Data.MySeqs3.myNames2Seq2(1)(1)(1)(1).nicknames(1) == 'myNames2Seq2[1][1][1][1].nicknames[1]')

	-- myName2x2
	assert(Data.MySeqs3.myName2x2() == 'myName2x2#')
	assert(Data.MySeqs3.myName2x2(1)() == 'myName2x2[1]#')
	assert(Data.MySeqs3.myName2x2(1)(1).first == 'myName2x2[1][1].first')
	assert(Data.MySeqs3.myName2x2(1)(1).nicknames() == 'myName2x2[1][1].nicknames#')
	assert(Data.MySeqs3.myName2x2(1)(1).nicknames(1) == 'myName2x2[1][1].nicknames[1]')

	-- myName2x2x2x2
	assert(Data.MySeqs3.myName2x2x2x2() == 'myName2x2x2x2#')
	assert(Data.MySeqs3.myName2x2x2x2(1)() == 'myName2x2x2x2[1]#')
	assert(Data.MySeqs3.myName2x2x2x2(1)(1)() == 'myName2x2x2x2[1][1]#')
	assert(Data.MySeqs3.myName2x2x2x2(1)(1)(1)() == 'myName2x2x2x2[1][1][1]#')
	assert(Data.MySeqs3.myName2x2x2x2(1)(1)(1)(1).first == 'myName2x2x2x2[1][1][1][1].first')
	assert(Data.MySeqs3.myName2x2x2x2(1)(1)(1)(1).nicknames() == 'myName2x2x2x2[1][1][1][1].nicknames#')
	assert(Data.MySeqs3.myName2x2x2x2(1)(1)(1)(1).nicknames(1) == 'myName2x2x2x2[1][1][1][1].nicknames[1]')
end

Tester[#Tester+1] = 'test_const'
function Tester:test_const()
  Data.FLOAT = data.const{data.float, 3.14 }
  Data.DOUBLE = data.const{data.double, 3.14 * 3.14 }  
  Data.LDOUBLE = data.const{data.long_double, 3.14 * 3.14 * 3.14 }   
  Data.STRING = data.const{data.string(), "String Constant" }   
  Data.BOOL = data.const{data.boolean, true } 
  Data.CHAR = data.const{data.char, "String Constant" } -- warning  
  Data.LONG = data.const{data.long, 10.7 } -- warning
  Data.LLONG = data.const{data.long_long, 10^10 }
  Data.SHORT = data.const{data.short, 5 }
  Data.WSTRING = data.const{data.wstring(), "WString Constant" }

  self:print(Data.FLOAT)
  self:print(Data.DOUBLE)
  self:print(Data.LDOUBLE)
  self:print(Data.STRING)
  self:print(Data.BOOL)
  self:print(Data.CHAR)
  self:print(Data.LONG)
  self:print(Data.LLONG)
  self:print(Data.SHORT)
  self:print(Data.WSTRING)
   
  assert(Data.FLOAT() == 3.14)
  assert(Data.DOUBLE() == 3.14 * 3.14)
  assert(Data.LDOUBLE() == 3.14 * 3.14 * 3.14)
  assert(Data.STRING() == "String Constant")
  assert(Data.BOOL() == true)
  assert(Data.CHAR() == 'S') -- warning printed
  assert(Data.LONG() == 10)  -- warning printed
  assert(Data.LLONG() == 10^10)  
  assert(Data.SHORT() == 5)  
  assert(Data.WSTRING() == "WString Constant")
end

Tester[#Tester+1] = 'test_const_bounds'
function Tester:test_const_bounds()
    Data.CAPACITY = data.const{data.short, 5 }
    Data.MyCapacitySeq = data.typedef{Data.Name, 
                      data.sequence(Data.CAPACITY, Data.CAPACITY) }
    Data.MyCapacityArr = data.typedef{Data.Name, 
                      data.array(Data.CAPACITY, Data.CAPACITY) }
  
    Data.MyCapacityStruct = data.struct{ 
        { 'myNames', Data.MyCapacitySeq },
        { 'myNames2', Data.MyCapacityArr },
        { 'myStrings', data.string(), 
                       data.array(Data.CAPACITY, Data.CAPACITY)},
        { 'myNums', data.double, 
                    data.sequence(Data.CAPACITY, Data.CAPACITY)},
        { 'myStr', data.string(Data.CAPACITY) },                                       
    }
                                 
    self:print(Data.CAPACITY)
    self:print(Data.MyCapacitySeq)
    self:print(Data.MyCapacityArr)
    self:print(Data.MyCapacityStruct)
    
    assert(Data.CAPACITY() == 5)
    
    -- myNames
    assert(Data.MyCapacityStruct.myNames() == 'myNames#')
    assert(Data.MyCapacityStruct.myNames(1)() == 'myNames[1]#')
    assert(Data.MyCapacityStruct.myNames(1)(1).first == 'myNames[1][1].first')
    assert(Data.MyCapacityStruct.myNames(1)(1).nicknames() == 'myNames[1][1].nicknames#')
    assert(Data.MyCapacityStruct.myNames(1)(1).nicknames(1) == 'myNames[1][1].nicknames[1]')
  
    -- myNames2
    assert(Data.MyCapacityStruct.myNames2() == 'myNames2#')
    assert(Data.MyCapacityStruct.myNames2(1)() == 'myNames2[1]#')
    assert(Data.MyCapacityStruct.myNames2(1)(1).first == 'myNames2[1][1].first')
    assert(Data.MyCapacityStruct.myNames2(1)(1).nicknames() == 'myNames2[1][1].nicknames#')
    assert(Data.MyCapacityStruct.myNames2(1)(1).nicknames(1) == 'myNames2[1][1].nicknames[1]')
   
    -- myStrings
    assert(Data.MyCapacityStruct.myStrings() == 'myStrings#')
    assert(Data.MyCapacityStruct.myStrings(1)() == 'myStrings[1]#')
    assert(Data.MyCapacityStruct.myStrings(1)(1) == 'myStrings[1][1]')
    
    -- myStr
    assert(Data.MyCapacityStruct.myStr == 'myStr')
end

Tester[#Tester+1] = 'test_struct_recursive'
function Tester:test_struct_recursive()

    -- NOTE: Forward data declarations are not allowed in IDL
    --       still, this is just a test to see how it might work
    
    Data.RecursiveStruct = data.struct{} -- fwd decl
    local RecursiveStruct = data.struct{ -- note: won't get installed as a defn
      { 'x', data.long },
      { 'y', data.long },
      { 'child', Data.RecursiveStruct },
    }
    Data.RecursiveStruct = nil -- erase from module
    Data.RecursiveStruct = RecursiveStruct -- reinstall it
    
    self:print(Data.RecursiveStruct)
    
    assert('x' == Data.RecursiveStruct.x)
    assert('y' == Data.RecursiveStruct.y)
    
    -- assert('child.x' == Data.RecursiveStruct.child.x)
end

Tester[#Tester+1] = 'test_dynamic_struct'
function Tester:test_dynamic_struct()

    local DynamicShapeType = data.struct{}
    DynamicShapeType.x = { data.long }
    DynamicShapeType.y = { data.long }
    DynamicShapeType.shapesize = { data.double }
    DynamicShapeType.color = { data.string(128), data.Key  }
        
    
    -- install it under the name 'ShapeType' in the module
    Data.ShapeType = DynamicShapeType
    self:print(DynamicShapeType)

    assert(DynamicShapeType.x == 'x')
    assert(DynamicShapeType.y == 'y')
    assert(DynamicShapeType.shapesize == 'shapesize')
    assert(DynamicShapeType.color == 'color')   
    
    
    
    -- redefine shapesize:
    DynamicShapeType.shapesize = nil -- erase member (for redefinition)
    DynamicShapeType.shapesize = { data.long } -- redefine it
    print("\n** redefined: double->long shapesize **\n")
    self:print(DynamicShapeType)
    assert(DynamicShapeType.shapesize == 'shapesize')
 
 
    -- add z:
    DynamicShapeType.z = { data.string() , data.Key }
    print("\n** added: string z @Key **\n")
    self:print(DynamicShapeType)
    assert(DynamicShapeType.z == 'z') 
    
    
    -- remove z:
    DynamicShapeType.z = nil -- erase member (for redefinition)
    DynamicShapeType.z = nil -- redefine it as empty
    print("\n** removed: string z **\n")
    self:print(DynamicShapeType)
    assert(DynamicShapeType.z == nil) 
    
       
    -- add a base class
    local Bases = data.module{}
    Bases.Base1 = data.struct{
        { 'org', data.string() },
    }
    DynamicShapeType[data.BASE] = Bases.Base1
    print("\n** added: base class: Base1 **\n")
    self:print(Bases.Base1)
    self:print(DynamicShapeType)
    assert(DynamicShapeType.org == 'org')  
    -- assert(DynamicShapeType[data.MODEL][data.BASE] == Bases.Base1)
    
    -- redefine base class
    Bases.Base2 = data.struct{
        { 'pattern', data.long },
    }
    DynamicShapeType[data.BASE] = Bases.Base2
    print("\n** replaced: base class: Base2 **\n")
    self:print(Bases.Base2)
    self:print(DynamicShapeType)
    assert(DynamicShapeType.pattern == 'pattern') 
    assert(DynamicShapeType.org == nil)  
    -- assert(DynamicShapeType[data.MODEL][data.BASE] == Bases.Base2)
    
    -- removed base class
    DynamicShapeType[data.BASE] = nil
    print("\n** erased base class **\n")
    self:print(DynamicShapeType)
    assert(DynamicShapeType.pattern == nil) 
    -- assert(DynamicShapeType[data.MODEL][data.BASE] == nil)
 
 
    -- add an annotation
    DynamicShapeType[data.ANNOTATION] = { 
        data.Extensibility{'EXTENSIBLE_EXTENSIBILITY'} 
    }
    print("\n** added annotation: @Extensibility **\n")
    self:print(DynamicShapeType)
    -- assert(DynamicShapeType[data.MODEL][data.ANNOTATION][1] ~= nil)
 
    -- add another annotation
    DynamicShapeType[data.ANNOTATION] = { 
        data.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
        data.Nested{'FALSE'},
    }  
    print("\n** added: annotation: @Nested **\n")
    self:print(DynamicShapeType)
    -- assert(DynamicShapeType[data.MODEL][data.ANNOTATION][1] ~= nil)
    -- assert(DynamicShapeType[data.MODEL][data.ANNOTATION][2] ~= nil)
 
    -- clear annotations:
    DynamicShapeType[data.ANNOTATION] = nil
    print("\n** erased annotations **\n")
    self:print(DynamicShapeType)
    -- assert(DynamicShapeType[data.MODEL][data.ANNOTATION] == nil)
end

Tester[#Tester+1] = 'test_dynamic_union'
function Tester:test_dynamic_union()

    local DynamicUnion = data.union{data.char} -- switch
    DynamicUnion[data.MODEL][1] = { 's', m_str = { data.string() } }
    DynamicUnion[data.MODEL][2] = { 'i', m_int = { data.short } }  
    DynamicUnion[data.MODEL][3] = { nil, m_oct = { data.octet } } -- default case

    -- install it under the name 'ShapeType' in the module
    Data.DynamicUnion = DynamicUnion
    self:print(DynamicUnion)

    assert(DynamicUnion._d == '#')
    assert(DynamicUnion.m_str == 'm_str')
    assert(DynamicUnion.m_int == 'm_int')
    assert(DynamicUnion.m_oct == 'm_oct')



    -- redefine m_int:
    DynamicUnion[data.MODEL][2] = { 'l', m_int = { data.long, data.Key } }  
    print("\n** redefined: short->long m_int @Key **\n")
    self:print(DynamicUnion)
    assert(DynamicUnion.m_int == 'm_int')
 
 
 
    -- add m_real:
    DynamicUnion[data.MODEL][4] = { 'r', m_real = { data.double, data.Key } }
    print("\n** added: double m_real @Key **\n")
    self:print(DynamicUnion)
    assert(DynamicUnion.m_real == 'm_real')
    
    -- remove m_real:
    DynamicUnion[data.MODEL][4] = nil -- erase m_real
    print("\n** removed: double m_real **\n")
    self:print(DynamicUnion)
    assert(DynamicUnion.m_real == nil) 
 
 
 
    -- add an annotation
    DynamicUnion[data.MODEL][data.ANNOTATION] = { 
        data.Extensibility{'EXTENSIBLE_EXTENSIBILITY'} 
    }
    print("\n** added annotation: @Extensibility **\n")
    self:print(DynamicUnion)
    assert(DynamicUnion[data.MODEL][data.ANNOTATION][1] ~= nil)
    
    -- add another annotation
    DynamicUnion[data.MODEL][data.ANNOTATION] = { 
        data.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
        data.Nested{'FALSE'},
    }  
    print("\n** added: annotation: @Nested **\n")
    self:print(DynamicUnion)
    assert(DynamicUnion[data.MODEL][data.ANNOTATION][1] ~= nil)
    assert(DynamicUnion[data.MODEL][data.ANNOTATION][2] ~= nil)
 
    -- clear annotations:
    DynamicUnion[data.MODEL][data.ANNOTATION] = nil
    print("\n** erased annotations **\n")
    self:print(DynamicUnion)
    assert(DynamicUnion[data.MODEL][data.ANNOTATION] == nil)
end

Tester[#Tester+1] = 'test_root'
function Tester:test_root()
  self:print(Data)
end

Tester[#Tester+1] = 'test_struct_nomodule'
function Tester:test_struct_nomodule()
  local ShapeType = data.struct{
    { 'x', data.long },
    { 'y', data.long },
    { 'shapesize', data.long },
    { 'color', data.string(128), data.Key },
  }
  
  self:print(ShapeType)
  
  assert('x' == ShapeType.x)
  assert('y' == ShapeType.y)
  assert('shapesize' == ShapeType.shapesize)
  assert('color' == ShapeType.color)   
end

---
-- print - helper method to print the IDL and the index for data definition
function Tester:print(instance)
    -- print IDL
    data.print_idl(instance)
  
    -- print index
    local instance = data.index(instance)
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
  	end
end

Tester:main()

--------------------------------------------------------------------------------
