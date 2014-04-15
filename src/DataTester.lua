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

local Data = require "Data"

--[[
local Test = Test or {}

Data.Days = Data.enum{
	'MON', 'TUE', 'WED', 'THU',
}

Data.Subtest = {}

Data.Subtest.Colors = Data.enum2{
	RED   = 5,
	BLUE  = 7,
	GREEN = 9,
}

Data.Name = Data.instance2{
	first = Data.STRING,
	last  = Data.STRING,
}

Data.Address = Data.instance2{
	name    = Data.instance('name', Data.Name),
	street  = Data.STRING,
	city    = Data.STRING,
}
--]]

--[[ ALTERNATE Syntax:
local MyTest = Data:Module('MyTest')

MyData:Struct('Address') {
-- MyData:Struct{Address = {
	{ name = Data.Name },
	{ street = Data.String() },
	{ city = Data.String() },
	{ coord = Data.Seq(Data.double, 2) },
}-- }

MyData:Union('TestUnion1')(Data.Days) {
-- MyData:Union{TestUnion1 = Data.switch(Data.Days) {

	{ 'MON', 
		{name = Data.Name},
	{ 'TUE', 
		{address = Data.Address}},
	{ -- default
		{x = Data.double}},		
}-- }

MyData:Enum('Months') { 
-- MyData:Enum{Months = { 
	{ JAN = 1 },
	{ FEB = 2 },
	{ MAR = 3 },
}--}
--]]

--------------------------------------------------------------------------------
-- Data Definitions
--------------------------------------------------------------------------------

Data:Enum{'Days', 
	{'MON'}, {'TUE'}, {'WED'}, {'THU'}, {'FRI'}, {'SAT'}, {'SUN'}
}

Data:Enum{'Months', 
	{ 'JAN', 1 },
	{ 'FEB', 2 },
	{ 'MAR', 3 }
}

Data:Module('Subtest') -- alternate syntax

Data.Subtest:Enum{'Colors', 
	{ 'RED',   -5 },
	{ 'BLUE',  7 },
	{ 'GREEN', -9 },
	{ 'PINK' }
}

Data.Subtest:Struct{'Fruit', 
	{ 'weight', Data.double },
	{ 'color' , Data.Subtest.Colors}
}

Data:Struct{'Name',
	{ 'first', Data.String(10), Data._.Key{} },
	{ 'last',  Data.String() }, 
	{ 'nicknames',  Data.String(10), Data.Sequence(3) },
	{ 'aliases',  Data.String(5), Data.Sequence() },
	{ 'birthday', Data.Days, Data._.Optional{} },
	{ 'favorite', Data.Subtest.Colors, Data.Sequence(2), Data._.Optional{} },
}

-- user defined annotation
Data:Annotation('MyAnnotation', {value1 = 42, value2 = 42.0})

Data:Struct{'Address',
	Data._.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
	{ 'name', Data.Name },
	{ 'street', Data.String() },
	{ 'city',  Data.String(), Data._.MyAnnotation{value1 = 10, value2 = 17} },
	-- Data._.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
}

Data:Union{'TestUnion1', Data.Days,
	{ 'MON', 
		{'name', Data.Name}},
	{ 'TUE', 
		{'address', Data.Address}},
	{ -- default
		{'x', Data.double}},		
	Data._.Extensibility{'EXTENSIBLE_EXTENSIBILITY',domain=5},
}

Data:Union{'TestUnion2', Data.char,
	{ 'c', 
		{'name', Data.Name, Data._.Key{} }},
	{ 'a', 
		{'address', Data.Address}},
	{ -- default
		{'x', Data.double}},
}

Data:Union{'TestUnion3', Data.short,
	{ 1, 
		{'x', Data.String()}},
	{ 2, 
		{'y', Data.long_double}},
	{ -- default
		{'z', Data.boolean}},
}

Data:Union{'NameOrAddress', Data.boolean,
	{ true, 
		{'name', Data.Name}},
	{ false, 
		{'address', Data.Address}},
}

Data:Struct{'Company',
	{ 'entity', Data.NameOrAddress},
	{ 'hq', Data.String(), Data.Sequence(2) },
	{ 'offices', Data.Address, Data.Sequence(10) },
	{ 'employees', Data.Name, Data.Sequence() }
}

Data:Struct{'BigCompany',
	{ 'parent', Data.Company},
	{ 'divisions', Data.Company, Data.Sequence()}
}

Data:Struct{'FullName', Data.Name,
	{ 'middle',  Data.String() },
	Data._.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
}

Data:Struct{'Contact', Data.FullName,
	{ 'address',  Data.Address },
	{ 'email',  Data.String() },
}

Data:Struct{'Tasks',
	{ 'contact',  Data.Contact },
	{ 'day',  Data.Days },
}

Data:Struct{'Calendar',
	{ 'tasks',  Data.Tasks, Data.Sequence() },
}

-- typedefs
Data:Typedef{'MyDouble', Data.double}
Data:Typedef{'MyDouble2', Data.MyDouble}
Data:Typedef{'MyString', Data.String(10) }

Data:Typedef{'MyName', Data.Name }
Data:Typedef{'MyName2', Data.MyName }

Data:Typedef{'MyAddress', Data.Address }
Data:Typedef{'MyAddress2', Data.MyAddress }

Data:Struct{'MyTypedef',
	{ 'rawDouble', Data.double },
	{ 'myDouble', Data.MyDouble },
	{ 'myDouble2', Data.MyDouble2 },
	
	{ 'name',  Data.Name },
	{ 'myName',  Data.MyName },
	{ 'myName2',  Data.MyName2 },
	
	{ 'address', Data.Address },
	{ 'myAddress', Data.MyAddress },
	{ 'myAddress2', Data.MyAddress2 },
}
			
Data:Typedef{'MyDoubleSeq', Data.MyDouble, Data.Sequence() }
Data:Typedef{'MyStringSeq', Data.MyString, Data.Sequence(10) }

Data:Typedef{'NameSeq', Data.Name, Data.Sequence(10) }
Data:Typedef{'NameSeqSeq', Data.NameSeq, Data.Sequence(10) }

Data:Typedef{'MyNameSeq', Data.MyName, Data.Sequence(10) }
Data:Typedef{'MyNameSeqSeq', Data.MyNameSeq, Data.Sequence(10) }

Data:Struct{'MyTypedefSeq',
    { 'myDoubleSeq', Data.MyDouble, Data.Sequence() },
	{ 'myDoubleSeqA', Data.MyDoubleSeq },
	{ 'myStringSeqA', Data.MyStringSeq },
	
	{ 'nameSeq', Data.Name, Data.Sequence() },
	{ 'nameSeqA', Data.NameSeq },
	{ 'nameSeqSeq', Data.NameSeq, Data.Sequence() },
	{ 'nameSeqSeqA', Data.NameSeqSeq },
	{ 'nameSeqSeqASeq', Data.NameSeqSeq, Data.Sequence() },

	{ 'myNameSeq', Data.MyName, Data.Sequence() },
	{ 'myNameSeqA', Data.MyNameSeq },
	{ 'myNameSeqSeq', Data.MyNameSeq, Data.Sequence() },
	{ 'myNameSeqSeqA', Data.MyNameSeqSeq },
	{ 'myNameSeqSeqASeq', Data.MyNameSeqSeq, Data.Sequence() },
}

-- Arrays
Data:Struct{'MyArrays1',
	-- 1-D
	{ 'ints', Data.double, Data.Array(3) },

	-- 2-D
	{ 'days', Data.Days, Data.Array(6, 9) },
	
	-- 3-D
	{ 'names', Data.Name, Data.Array(12, 15, 18) },
}

Data:Union{'MyArrays2', Data.Days,
	-- 1-D
	{ 'MON',
		{'ints', Data.double, Data.Array(3) }},

	-- 2-D
	{ 'TUE',
		{ 'days', Data.Days, Data.Array(6, 9) }},
	
	-- 3-D
	{--
		{ 'names', Data.Name, Data.Array(12, 15, 18) }},	
}

--------------------------------------------------------------------------------
-- Tester - the unit tests
--------------------------------------------------------------------------------

local Tester = {} -- array of test functions

-- print - helper method to print the IDL and the index for an data definition
function Tester:print(instance)
	Data.print_idl(instance)

	-- print index
	local instance = Data.index(instance)
	if instance == nil then return end
	
	print('index:')
	for i, v in ipairs(instance) do
		print('   ', v)	
	end
end

Tester[#Tester+1] = 'test_struct_basic'
function Tester:test_struct_basic()
	self:print(Data.Name)
end

Tester[#Tester+1] = 'test_struct_nested'
function Tester:test_struct_nested()
	self:print(Data.Address)
end

Tester[#Tester+1] = 'test_submodule'
function Tester:test_submodule()
	self:print(Data.Subtest)
end

Tester[#Tester+1] = 'test_module'
function Tester:test_module()
    self:print(Data)
end

Tester[#Tester+1] = 'test_enum'
function Tester:test_enum()
	self:print(Data.Days)
	self:print(Data.Months)
	self:print(Data.Subtest.Colors)
end

Tester[#Tester+1] = 'test_union'
function Tester:test_union()
	self:print(Data.TestUnion1)
	self:print(Data.TestUnion2)
	self:print(Data.TestUnion3)
	self:print(Data.NameOrAddress)
end

Tester[#Tester+1] = 'test_struct_complex'
function Tester:test_struct_complex()
	self:print(Data.Company)
	self:print(Data.BigCompany)
end

Tester[#Tester+1] = 'test_struct_inheritance'
function Tester:test_struct_inheritance()
	self:print(Data.FullName)
	self:print(Data.Contact)
	self:print(Data.Tasks)
	self:print(Data.Calendar)
end

Tester[#Tester+1] = 'test_typedef'
function Tester:test_typedef()	
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
	Data:Typedef{'MyNameArray', Data.Name, Data.Array(10) }
	Data:Typedef{'MyNameArray2', Data.MyNameArray, Data.Array(10) }
	Data:Typedef{'MyName2x2', Data.Name, Data.Array(2, 3) }
	
	Data:Struct{'MyArrays3',
		-- 1-D
		{ 'myNames', Data.MyNameArray },

		-- 2-D
		{ 'myNamesArray', Data.MyNameArray, Data.Array(10) },
	
		-- 2-D
		{ 'myNames2', Data.MyNameArray2 },
				
		-- 3-D
		{ 'myNames2Array', Data.MyNameArray2, Data.Array(10) },

		-- 4-D
		{ 'myNames2Array2', Data.MyNameArray2, Data.Array(10, 20) },
		
		-- 2D: 2x2
		{ 'myName2x2', Data.MyName2x2 },

		-- 4D: 2x2 x2x2
		{ 'myName2x2x2x2', Data.MyName2x2, Data.Array(4,5) },
	}

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
	Data:Typedef{'MyNameSeq1', Data.Name, Data.Sequence(10) }
	Data:Typedef{'MyNameSeq2', Data.MyNameSeq, Data.Sequence(10) }
	Data:Typedef{'MyNameSeq2x2', Data.Name, Data.Sequence(2, 3) }
	
	Data:Struct{'MySeqs3',
		-- 1-D
		{ 'myNames', Data.MyNameSeq },

		-- 2-D
		{ 'myNamesSeq', Data.MyNameSeq1, Data.Sequence(10) },
	
		-- 2-D
		{ 'myNames2', Data.MyNameSeq2 },
				
		-- 3-D
		{ 'myNames2Seq', Data.MyNameSeq2, Data.Sequence(10) },

		-- 4-D
		{ 'myNames2Seq2', Data.MyNameSeq2, Data.Sequence(10, 20) },
		
		-- 2D: 2x2
		{ 'myName2x2', Data.MyName2x2 },

		-- 4D: 2x2 x2x2
		{ 'myName2x2x2x2', Data.MyNameSeq2x2, Data.Sequence(4,5) },
	}

	self:print(Data.MySeqs3)

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
  Data:Const{'FLOAT', Data.float, 3.14 }
  Data:Const{'DOUBLE', Data.double, 3.14 * 3.14 }  
  Data:Const{'LDOUBLE', Data.long_double, 3.14 * 3.14 * 3.14 }   
  Data:Const{'STRING', Data.string, "String Constant" }   
  Data:Const{'BOOL', Data.boolean, true } 
  Data:Const{'CHAR', Data.char, "String Constant" } -- warning  
  Data:Const{'LONG', Data.long, 10.7 } -- warning
  Data:Const{'LLONG', Data.long_long, 10^10 }
  Data:Const{'SHORT', Data.short, 5 }
  Data:Const{'WSTRING', Data.wstring, "WString Constant" }
  
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
    Data:Const{'CAPACITY', Data.short, 5 }
    Data:Typedef{'MyCapacitySeq', Data.Name, 
                                  Data.Sequence(Data.CAPACITY, Data.CAPACITY) }
    Data:Typedef{'MyCapacityArr', Data.Name, 
                                  Data.Array(Data.CAPACITY, Data.CAPACITY) }
  
    Data:Struct{'MyCapacityStruct', 
        { 'myNames', Data.MyCapacitySeq },
        { 'myNames2', Data.MyCapacityArr },
        { 'myStrings', Data.String(), Data.Array(Data.CAPACITY, Data.CAPACITY)},
        { 'myNums', Data.double, Data.Sequence(Data.CAPACITY,
                                                 Data.CAPACITY)},
        { 'myStr', Data.String(Data.CAPACITY) },                                       
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

Tester[#Tester+1] = 'test_root'
function Tester:test_root()
  self:print(Data)
end

-- main() - run the list of tests passed on the command line
--          if no command line arguments are passed in, run all the tests
function Tester:main()
	if #arg > 0 then -- run selected tests passed in from the command line
		for i, test in ipairs (arg) do
			print('\n--- ' .. test .. ' ---')
			self[test](self) -- run the test
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
