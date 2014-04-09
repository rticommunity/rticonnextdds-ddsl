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

Test.Days = Data.enum{
	'MON', 'TUE', 'WED', 'THU',
}

Test.Subtest = {}

Test.Subtest.Colors = Data.enum2{
	RED   = 5,
	BLUE  = 7,
	GREEN = 9,
}

Test.Name = Data.instance2{
	first = Data.STRING,
	last  = Data.STRING,
}

Test.Address = Data.instance2{
	name    = Data.instance('name', Test.Name),
	street  = Data.STRING,
	city    = Data.STRING,
}
--]]

--[[ ALTERNATE Syntax:
local MyTest = Data:Module('MyTest')

MyTest:Struct('Address') {
-- MyTest:Struct{Address = {
	{ name = Test.Name },
	{ street = Data.String() },
	{ city = Data.String() },
	{ coord = Data.Seq(Data.double, 2) },
}-- }

MyTest:Union('TestUnion1')(Test.Days) {
-- MyTest:Union{TestUnion1 = Data.switch(Test.Days) {

	{ 'MON', 
		{name = Test.Name},
	{ 'TUE', 
		{address = Test.Address}},
	{ -- default
		{x = Data.double}},		
}-- }

MyTest:Enum('Months') { 
-- MyTest:Enum{Months = { 
	{ JAN = 1 },
	{ FEB = 2 },
	{ MAR = 3 },
}--}
--]]

---[[ SKIP TESTS --

local Test = Data:Module{'Test'}
--[[
local testModule = Data:create_module();
local testEnum   = testModule:create_enum();
Test:add()
--]]
 
Test:Enum{'Days', 
	{'MON'}, {'TUE'}, {'WED'}, {'THU'}, {'FRI'}, {'SAT'}, {'SUN'}
}

Test:Enum{'Months', 
	{ 'JAN', 1 },
	{ 'FEB', 2 },
	{ 'MAR', 3 }
}

Test:Module('Subtest') -- alternate syntax

Test.Subtest:Enum{'Colors', 
	{ 'RED',   -5 },
	{ 'BLUE',  7 },
	{ 'GREEN', -9 },
	{ 'PINK' }
}

Test.Subtest:Struct{'Fruit', 
	{ 'weight', Data.double },
	{ 'color' , Test.Subtest.Colors}
}

Test:Struct{'Name',
	{ 'first', Data.String(10), Data._.Key{} },
	{ 'last',  Data.String() }, 
	{ 'nicknames',  Data.String(10), Data.Seq(3) },
	{ 'aliases',  Data.String(5), Data.Seq() },
	{ 'birthday', Test.Days, Data._.Optional{} },
	{ 'favorite', Test.Subtest.Colors, Data.Seq(2), Data._.Optional{} },
}

-- user defined annotation
Data:Annotation('MyAnnotation', {value1 = 42, value2 = 42.0})

Test:Struct{'Address',
	Data._.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
	{ 'name', Test.Name },
	{ 'street', Data.String() },
	{ 'city',  Data.String(), Data._.MyAnnotation{value1 = 10, value2 = 17} },
	-- Data._.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
}

Test:Union{'TestUnion1', Test.Days,
	{ 'MON', 
		{'name', Test.Name}},
	{ 'TUE', 
		{'address', Test.Address}},
	{ -- default
		{'x', Data.double}},		
	Data._.Extensibility{'EXTENSIBLE_EXTENSIBILITY',domain=5},
}

Test:Union{'TestUnion2', Data.char,
	{ 'c', 
		{'name', Test.Name, Data._.Key{} }},
	{ 'a', 
		{'address', Test.Address}},
	{ -- default
		{'x', Data.double}},
}

Test:Union{'TestUnion3', Data.short,
	{ 1, 
		{'x', Data.String()}},
	{ 2, 
		{'y', Data.double}},
	{ -- default
		{'z', Data.boolean}},
}

Test:Union{'NameOrAddress', Data.boolean,
	{ true, 
		{'name', Test.Name}},
	{ false, 
		{'address', Test.Address}},
}

Test:Struct{'Company',
	{ 'entity', Test.NameOrAddress},
	{ 'hq', Data.String(), Data.Seq(2) },
	{ 'offices', Test.Address, Data.Seq(10) },
	{ 'employees', Test.Name, Data.Seq() }
}

Test:Struct{'BigCompany',
	{ 'parent', Test.Company},
	{ 'divisions', Test.Company, Data.Seq()}
}

Test:Struct{'FullName', Test.Name,
	{ 'middle',  Data.String() },
	Data._.Extensibility{'EXTENSIBLE_EXTENSIBILITY'},
}

Test:Struct{'Contact', Test.FullName,
	{ 'address',  Test.Address },
	{ 'email',  Data.String() },
}

Test:Struct{'Tasks',
	{ 'contact',  Test.Contact },
	{ 'day',  Test.Days },
}

Test:Struct{'Calendar',
	{ 'tasks',  Test.Tasks, Data.Seq() },
}

-- typedefs

Test:Typedef{'MyDouble', Data.double}
Test:Typedef{'MyDouble2', Test.MyDouble}
Test:Typedef{'MyString', Data.String(10)}

Test:Typedef{'MyName', Test.Name }
Test:Typedef{'MyName2', Test.MyName }

Test:Typedef{'MyAddress', Test.Address }
Test:Typedef{'MyAddress2', Test.MyAddress }

Test:Struct{'MyTypedef',
	{ 'rawDouble', Data.double },
	{ 'myDouble', Test.MyDouble },
	{ 'myDouble2', Test.MyDouble2 },
	
	{ 'name',  Test.Name },
	{ 'myName',  Test.MyName },
	{ 'myName2',  Test.MyName2 },
	
	{ 'address', Test.Address },
	{ 'myAddress', Test.MyAddress },
	{ 'myAddress2', Test.MyAddress2 },
}


function Test:test_typedef()	
	self:print(self.MyDouble)
	self:print(self.MyDouble2)	
	self:print(self.MyString)
				
	self:print(self.MyName)
	self:print(self.MyName2)
	
	self:print(self.MyAddress)
	self:print(self.MyAddress2)
	
	self:print(self.MyTypedef)
end


Test:Typedef{'MyDoubleSeq', Test.MyDouble, Data.Seq() }
Test:Typedef{'MyStringSeq', Test.MyString, Data.Seq(10) }

Test:Typedef{'NameSeq', Test.Name, Data.Seq(10) }
Test:Typedef{'NameSeqSeq', Test.NameSeq, Data.Seq(10) }

Test:Typedef{'MyNameSeq', Test.MyName, Data.Seq(10) }
Test:Typedef{'MyNameSeqSeq', Test.MyNameSeq, Data.Seq(10) }

Test:Struct{'MyTypedefSeq',
    { 'myDoubleSeq', Test.MyDouble, Data.Seq() },
	{ 'myDoubleSeqA', Test.MyDoubleSeq },
	{ 'myStringSeqA', Test.MyStringSeq },
	
	{ 'nameSeq', Test.Name, Data.Seq() },
	{ 'nameSeqA', Test.NameSeq },
	{ 'nameSeqSeq', Test.NameSeq, Data.Seq() },
	{ 'nameSeqSeqA', Test.NameSeqSeq },
	{ 'nameSeqSeqASeq', Test.NameSeqSeq, Data.Seq() },

	{ 'myNameSeq', Test.MyName, Data.Seq() },
	{ 'myNameSeqA', Test.MyNameSeq },
	{ 'myNameSeqSeq', Test.MyNameSeq, Data.Seq() },
	{ 'myNameSeqSeqA', Test.MyNameSeqSeq },
	{ 'myNameSeqSeqASeq', Test.MyNameSeqSeq, Data.Seq() },
}

function Test:test_typedef_seq()	
	self:print(self.MyDoubleSeq)
	self:print(self.MyStringSeq)
	
	self:print(self.NameSeq)
	self:print(self.NameSeqSeq)

	self:print(self.MyNameSeq)
	self:print(self.MyNameSeqSeq)
	
	self:print(self.MyTypedefSeq)
	
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

-- Arrays
Test:Struct{'MyArrays1',
	-- 1-D
	{ 'ints', Data.double, Data.Array(3) },

	-- 2-D
	{ 'days', Test.Days, Data.Array(6, 9) },
	
	-- 3-D
	{ 'names', Test.Name, Data.Array(12, 15, 18) },
}

function Test:test_arrays1()
	-- structure with arrays
	self:print(Test.MyArrays1)
	
	assert(Test.MyArrays1.ints() == 'ints#')
	assert(Test.MyArrays1.ints(1) == 'ints[1]')
	
	assert(Test.MyArrays1.days() == 'days#')
	assert(Test.MyArrays1.days(1)() == 'days[1]#')
	assert(Test.MyArrays1.days(1)(1) == 'days[1][1]')
	
	assert(Test.MyArrays1.names() == 'names#')
	assert(Test.MyArrays1.names(1)() == 'names[1]#')
	assert(Test.MyArrays1.names(1)(1)() == 'names[1][1]#')
	assert(Test.MyArrays1.names(1)(1)(1).first == 'names[1][1][1].first')
	assert(Test.MyArrays1.names(1)(1)(1).nicknames() == 'names[1][1][1].nicknames#')
	assert(Test.MyArrays1.names(1)(1)(1).nicknames(1) == 'names[1][1][1].nicknames[1]')
end

Test:Union{'MyArrays2', Test.Days,
	-- 1-D
	{ 'MON',
		{'ints', Data.double, Data.Array(3) }},

	-- 2-D
	{ 'TUE',
		{ 'days', Test.Days, Data.Array(6, 9) }},
	
	-- 3-D
	{--
		{ 'names', Test.Name, Data.Array(12, 15, 18) }},	
}

function Test:test_arrays2()
	-- union with arrays
	self:print(Test.MyArrays2)
	
	assert(Test.MyArrays2.ints() == 'ints#')
	assert(Test.MyArrays2.ints(1) == 'ints[1]')
	
	assert(Test.MyArrays2.days() == 'days#')
	assert(Test.MyArrays2.days(1)() == 'days[1]#')
	assert(Test.MyArrays2.days(1)(1) == 'days[1][1]')
	
	assert(Test.MyArrays2.names() == 'names#')
	assert(Test.MyArrays2.names(1)() == 'names[1]#')
	assert(Test.MyArrays2.names(1)(1)() == 'names[1][1]#')
	assert(Test.MyArrays2.names(1)(1)(1).first == 'names[1][1][1].first')
	assert(Test.MyArrays2.names(1)(1)(1).nicknames() == 'names[1][1][1].nicknames#')
	assert(Test.MyArrays2.names(1)(1)(1).nicknames(1) == 'names[1][1][1].nicknames[1]')
end

function Test:Xtest_arrays3()
	Test:Typedef{'MyNameArray', Test.Name, Data.Array(10) }
	Test:Typedef{'MyNameArray2', Test.Name, Data.Array(10, 10) }

	Test:Struct{'MyArrays3',
		-- 1-D
		{ 'myNames', Test.MyNameArray },
		
		-- 2-D
		{ 'myNamesArray', Test.MyNameArray, Data.Array(10) },
		
		-- 2-D
		{ 'myNames2', Test.MyNameArray2 },
		
		-- 3-D
		{ 'myNames2Array', Test.MyNameArray2, Data.Array(10) },

		-- 4-D
		{ 'myNames2Array2', Test.MyNameArray2, Data.Array(10, 20) },
	}

	self:print(Test.MyArrays3)
	
end

function Test.print_index(instance)
	local instance = Data.index(instance)
	if instance == nil then return end
	
	print('\nindex:')
	for i, v in ipairs(instance) do
		print('   ', v)	
	end
end

function Test:print(instance)
	Data.print_idl(instance)
	self.print_index(instance)
end

function Test:test_struct_basic()
	self:print(Test.Name)
end

function Test:test_struct_nested()
	self:print(Test.Address)
end

function Test:test_module()
	self:print(Test)
end

function Test:test_submodule()
	self:print(Test.Subtest)
end

function Test:test_root()
	self:print(Data)
end

function Test:test_enum()
	Data.print_idl(Test.Days)
	Data.print_idl(Test.Months)
	Data.print_idl(Test.Subtest.Colors)
end

function Test:test_union()
	self:print(Test.TestUnion1)
	self:print(Test.TestUnion2)
	self:print(Test.TestUnion3)
	self:print(Test.NameOrAddress)
end

function Test:test_struct_complex()
	self:print(Test.Company)
	self:print(Test.BigCompany)
end

function Test:test_struct_inheritance()
	self:print(Test.FullName)
	self:print(Test.Contact)
	self:print(Test.Tasks)
	self:print(Test.Calendar)
end

-- main() - run the list of tests passed on the command line
--          if no command line arguments are passed in, run all the tests
function Test:main()
	if #arg > 0 then -- run selected tests passed in from the command line
		for i, test in ipairs (arg) do
			print('\n--- ' .. test .. ' ---')
			Test[test](Test) -- run the test
		end
	else -- run all  the tests
		for k, v in pairs (self) do
			if type(k) == "string" and string.sub(k, 1,4) == "test" then
				print('\n--- ' .. k .. ' ---')
				v(self) 
			end
		end
	end
end

Test:main()
 
-- SKIP TESTS --]]
--------------------------------------------------------------------------------
