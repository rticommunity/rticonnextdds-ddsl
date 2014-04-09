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

Data = require "Data"

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
	{ 'nicknames',  Data.String(10), Data.Seq(3) },
	{ 'aliases',  Data.String(5), Data.Seq() },
	{ 'birthday', Data.Days, Data._.Optional{} },
	{ 'favorite', Data.Subtest.Colors, Data.Seq(2), Data._.Optional{} },
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
		{'y', Data.double}},
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
	{ 'hq', Data.String(), Data.Seq(2) },
	{ 'offices', Data.Address, Data.Seq(10) },
	{ 'employees', Data.Name, Data.Seq() }
}

Data:Struct{'BigCompany',
	{ 'parent', Data.Company},
	{ 'divisions', Data.Company, Data.Seq()}
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
	{ 'tasks',  Data.Tasks, Data.Seq() },
}

-- typedefs
Data:Typedef{'MyDouble', Data.double}
Data:Typedef{'MyDouble2', Data.MyDouble}
Data:Typedef{'MyString', Data.String(10)}

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
			
Data:Typedef{'MyDoubleSeq', Data.MyDouble, Data.Seq() }
Data:Typedef{'MyStringSeq', Data.MyString, Data.Seq(10) }

Data:Typedef{'NameSeq', Data.Name, Data.Seq(10) }
Data:Typedef{'NameSeqSeq', Data.NameSeq, Data.Seq(10) }

Data:Typedef{'MyNameSeq', Data.MyName, Data.Seq(10) }
Data:Typedef{'MyNameSeqSeq', Data.MyNameSeq, Data.Seq(10) }

Data:Struct{'MyTypedefSeq',
    { 'myDoubleSeq', Data.MyDouble, Data.Seq() },
	{ 'myDoubleSeqA', Data.MyDoubleSeq },
	{ 'myStringSeqA', Data.MyStringSeq },
	
	{ 'nameSeq', Data.Name, Data.Seq() },
	{ 'nameSeqA', Data.NameSeq },
	{ 'nameSeqSeq', Data.NameSeq, Data.Seq() },
	{ 'nameSeqSeqA', Data.NameSeqSeq },
	{ 'nameSeqSeqASeq', Data.NameSeqSeq, Data.Seq() },

	{ 'myNameSeq', Data.MyName, Data.Seq() },
	{ 'myNameSeqA', Data.MyNameSeq },
	{ 'myNameSeqSeq', Data.MyNameSeq, Data.Seq() },
	{ 'myNameSeqSeqA', Data.MyNameSeqSeq },
	{ 'myNameSeqSeqASeq', Data.MyNameSeqSeq, Data.Seq() },
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

Tester[#Tester+1] = 'test_module'
function Tester:test_module()
		self:print(Data)
end

Tester[#Tester+1] = 'test_submodule'
function Tester:test_submodule()
	self:print(Data.Subtest)
end

Tester[#Tester+1] = 'test_root'
function Tester:test_root()
	self:print(Data)
end

Tester[#Tester+1] = 'test_enum'
function Tester:test_enum()
	Data.print_idl(Data.Days)
	Data.print_idl(Data.Months)
	Data.print_idl(Data.Subtest.Colors)
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
	
	assert(Data.MyArrays1.ints() == 'ints#')
	assert(Data.MyArrays1.ints(1) == 'ints[1]')
	
	assert(Data.MyArrays1.days() == 'days#')
	assert(Data.MyArrays1.days(1)() == 'days[1]#')
	assert(Data.MyArrays1.days(1)(1) == 'days[1][1]')
	
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
	
	assert(Data.MyArrays2.ints() == 'ints#')
	assert(Data.MyArrays2.ints(1) == 'ints[1]')
	
	assert(Data.MyArrays2.days() == 'days#')
	assert(Data.MyArrays2.days(1)() == 'days[1]#')
	assert(Data.MyArrays2.days(1)(1) == 'days[1][1]')
	
	assert(Data.MyArrays2.names() == 'names#')
	assert(Data.MyArrays2.names(1)() == 'names[1]#')
	assert(Data.MyArrays2.names(1)(1)() == 'names[1][1]#')
	assert(Data.MyArrays2.names(1)(1)(1).first == 'names[1][1][1].first')
	assert(Data.MyArrays2.names(1)(1)(1).nicknames() == 'names[1][1][1].nicknames#')
	assert(Data.MyArrays2.names(1)(1)(1).nicknames(1) == 'names[1][1][1].nicknames[1]')
end

Tester[#Tester+1] = 'test_arrays3'
function Tester:Xtest_arrays3()
	Data:Typedef{'MyNameArray', Data.Name, Data.Array(10) }
	Data:Typedef{'MyNameArray2', Data.Name, Data.Array(10, 10) }

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
	}

	self:print(Data.MyArrays3)
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
