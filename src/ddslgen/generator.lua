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

-------------------------------------------------------------
-- Generator is a library for generating synthetic data.
-- 
-- Using the Generator library is a simple two step process.
-- The first step is to provide a "description" of what should be
-- generated. Often times the description is just a `ddsl` type 
-- definition (a ddsl template). Given a description, the 
-- generator library provides a new "generator" object. 
-- The second step is to call the `Generator:generate` method to 
-- obtain an object containing data that fits the descriptions. 
-- 
-- An example is in order.
--     local Gen = require("ddslgen.generator").initialize()
-- 
--     local ShapeType = ddsl.xtypes.struct {
--       ShapeType = {
--         { x = { xtypes.long } },
--         { y = { xtypes.long } },
--         { shapesize = { xtypes.long } },
--         { color = { xtypes.string(128), xtypes.Key } },
--       }
--     }
--     
--     local shapeTypeGen = Gen.aggregateGen(ShapeType)
-- 
--     local aShape = shapeTypeGen:generate()
--
-- In the example above, `ShapeType` is a DDSL datatype describing
-- the canonical ShapeType. The `Gen.aggregateGen` function accepts 
-- the `ShapeType` datatype and produces a generator of ShapeTypes.
-- Finally, `shapeTypeGen:generate()` produces a randomly generated
-- ShapeType. 
--
-- Using the Generator library you can create geneators 
-- for the entire gamut of types supported by DDSL. I.e., you can
-- use the Generator library for primitives, structures, unions,
-- sequences, arrays, typedefs, and more. 
--
-- **Controling Generators** 
--
-- You might be wondering how does the Generator library know
-- what data to produce. By default, the Generator library produces
-- random data. I.e., in the ShapeType example above, the values
-- of `x`, `y`, `shapesize`, and `color` are random. The only thing
-- it knows about these members are the types of these members. 
-- Therefore, `x`, `y`, and `shapesize` are random integers and
-- `color` is a non-empty random string of up to 128 characters.
-- 
-- That does not sound too useful. Therefore the Generator library
-- provides very powerful ways to control how to produce data. In
-- fact the bulk of the library is about "controling" generators
-- rather than actual production. Afterall, all you need to do
-- given a generator is call `Generator:generate`. 
--
-- **Providing A Collection of Generators**
--
-- The Generator library allows you to specify one or more "smaller"
-- generators to create a large generator. If you don't like the 
-- default choice, you can specify a generator you want used. For
-- example, 
-- 
--      local memberGenLib = {}
--    
--      memberGenLib.x         = Gen.rangeGen(100, 200)
--      memberGenLib.y         = Gen.stepperGen(0, 50, 5, true)
--      memberGenLib.color     = Gen.oneOfGen({ "RED", "GREEN", "BLUE" })
--      memberGenLib.shapesize = Gen.constantGen(30)
--    
--      local shapeTypeGen2 = Gen.aggregateGen(ShapeType, memberGenLib)
--
-- `membeGenLib` is a library of generators. In fact, it contains a 
-- generator for every member in `ShapeType`. The generator
-- for `x` is a "range" genrerator that will always produce a random 
-- number in the specified range (inclusive). `stepperGen` produces
-- a generator that will produce values from 0 to 50 in the increments  
-- of 5. After producing 50, it will cycle back to 0 (hence the
-- last argument cycle=true). `oneOfGen` gives a generator that 
-- uses one of the available choices. Finally, `constantGen` produces
-- the given constant everytime. 
-- 
-- The `aggregateGen` function the uses `memberGenLib` and produces
-- a generator that uses the specified generators where needed. As a 
-- consequence, the shape objects produced by the new generator 
-- (`shapetypeGen2`) always satisfy the constraints on member values.
-- 
-- **Providing a Collection of Generators for Members and Types**
-- 
-- A generator library can store not only member-specific generators
-- but also type-specific generators. For instance, the following 
-- example a "stepper generator" for both `x` and `y` because both
-- are longs. 
-- 
--      local memberGenLib = { typeGenLib = {} }
--    
--      memberGenLib.typeGenLib.long = Gen.stepperGen(1, 100, 1, true)
--      memberGenLib.color           = Gen.oneOfGen({ "RED", "GREEN", "BLUE" })
--      memberGenLib.shapesize       = Gen.constantGen(30)
--    
--      local shapeTypeGen3 = Gen.aggregateGen(ShapeType, memberGenLib)
--
-- **Advanced Composition of Generators**
--
-- Generators are designed for composibility from group up.
-- Complex generators can be easily created from basic, simpler
-- generators. As such, generators form an *algebra* with well-defined
-- operations such as `Generator:map`, `Generator:flatMap`, `Generator:where`, 
-- `Generator:zipMany`, `Generator:append`, etc.
-- These operations are also known as *combinators* because 
-- use of these combinators always yields another generator.
-- 
-- Generators support *serial* and *parallel* composition. The 
-- examples we've seen so far show parallel composition as one or
-- more member generators are composed to create a composite generator.
-- Next, we'll see some examples of serial composition. Most
-- member function available in the `Generator` interface 
-- support serial composition.
--
-- The next example shows how the `dayGen` generator can be 
-- created using basic generators, such as a range generator.
-- I.e., xGen is a generator that produces values from 1 to 7. 
-- dayGen is a generator that maps the values produces
-- by xGen to the days of the week.
--
--     local dayOfWeek = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
--     local xGen = Gen.rangeGen(1,7)
--     local dayGen = xGen:map(function(i) 
--                               return dayOfWeek[i]
--                             end)
--     for i=1, 5 do 
--       print("dayGen produced ", dayGen:generate())
--     end
-- 
-- Every time dayGen:generate() is called, xGen:generate() is 
-- also called. `xGen` produces a new random number in the [1..7] 
-- range every time. `dayGen` *maps* the value produced by `xGen`
-- to a day of the week via the function passed to `map`.
-- 
-- `where` and `concat` are commonly needed functions. 
-- `where` selects the values that satsify a given predicate.
-- `concat` simply concatenates two generators. For instance,
-- the following program prints all even numbers between 0..99 
-- followed by the odd numbers in the same range.
--
--     local evenGen = Gen.stepperGen(0, 99)
--                        :where(function(i) return i % 2 == 0 end)
--     local oddGen = Gen.stepperGen(0, 99)
--                       :where(function(i) return i % 2 == 1 end)
--     local allGen = evenGen:concat(oddGen)
--  
--     for i=1, 100 do 
--       print(allGen:generate())
--     end
-- 
-- zipMany is another function supported by generators. 
-- The following example generates a random month in every year 
-- in the 20th century. 
-- 
--     local monthGen = Gen.oneOfGen({ "Jan", "Feb", "Mar",  "Apr", "May", "Jun", 
--                                     "Jul", "Aug", "Sept", "Oct", "Nov", "Dec" })
--     local yearGen = Gen.stepperGen(1900, 1999)
--     local seriesGen = yearGen:zipMany(monthGen, 
--                                       function(year, month) 
--                                         return year .. " " .. month
--                                       end)
--     for i=1, 100 do 
--       print(seriesGen:generate())
--     end
--
-- `zipMany` is the most general version of parallel composition.
--
-- These examples barely scratch the surface of what's possible using
-- generators. There are limitless ways how you can combine and
-- transform generators. 
-- 
-- **Lazy/Eager Evaluation, Infinite Sequences, and Limits**
--
-- One of the salient features of generators is that they are evalutated 
-- lazily. When a generator object is created, it's essentially a 
-- description of what has to be generated. No data is actually produced
-- until `generate()` is called. Each call to `generate()` advances the
-- generator just one step. A generator does not know how many elements
-- it might generate. As a matter of fact many generators are infinite.
-- We've seen many infinite generators already. For instance, `oneOfGen`,
-- `stepperGen` with `cycle=true`, are fundamentally infinite. 
--
-- It is very easy to limit an inifite generator to produce only a certain
-- number of elements. Use `Generator:take` and specify how many elements
-- you need. It's a way to transform infinite generators into finite ones.
--
-- Most example above used a for loop with limited number of iterations to 
-- produce new values. Alternatively, you can check the validity of the
-- return value, which is indicated by the second value returned by the 
-- `generate()` function. You may know already that Lua functions can return 
-- more than one values.
-- 
-- For example, the following program prints all the months once.
--
--     local monthGen = Gen.inOrderGen({ "Jan", "Feb", "Mar",  
--                                       "Apr", "May", "Jun", 
--                                       "Jul", "Aug", "Sept", 
--                                       "Oct", "Nov", "Dec" })
--     local data, valid = nil, true
--     
--     while valid do
--       data, valid = monthGen:generate()
--       if valid then 
--         print(data)
--       end
--     end
--
-- **Other API Features**
--
-- Generators can be forced to evaluate eagerly via the `Generator:toTable`
-- function. It returns a Lua table containing all the values of the generator
-- Needless to say, calling `Generator:toTable` on an infinite generator will block
-- the caller forever and the process will likely run out of memory.
--
-- Stateful computations can be performed during generator evaluation using
-- `Generator:scan` method. It allows programmers to start with an "initial"
-- state and accumulate arbitrary modifications to the state as long as the 
-- generator proceeds.
--
--
-- @module generator
-- @alias Public
-- @author Sumant Tambe
-------------------------------------------------------------

--! The generator module depends on the "xtypes" module.
local xtypes = require ("ddsl.xtypes")

local Public = {

  --- Max integer value of a byte (0xFF).
  MAX_BYTE    = 0xFF,

  --- Max 16-bit integer value (0x7FFF).
  MAX_INT16   = 0x7FFF, 
  --- Max 32-bit integer value (0x7FFFFFFF).
  MAX_INT32   = 0x7FFFFFFF, 
  --- Max 64-bit integer value (0x7FFFFFFFFFFFFFFF).
  MAX_INT64   = 0x7FFFFFFFFFFFFFFF, 

  --- Max 16-bit unsigned integer value (0xFFFF).
  MAX_UINT16  = 0xFFFF, 
  --- Max 32-bit unsigned integer value (0xFFFFFFFF).
  MAX_UINT32  = 0xFFFFFFFF, 
  --- Max 64-bit unsigned integer value (0x7FFFFFFFFFFFFFFF)
  MAX_UINT64  = 0x7FFFFFFFFFFFFFFF, 

  --- Max value of a float (single precision) (approximately 3.40 * 10^^38)
  MAX_FLOAT   = 3.4028234 * math.pow(10,38),
  --- Max value of a double (double precision) (approximately 1.79 * 10^^308)
  MAX_DOUBLE  = 1.7976931348623157 * math.pow(10, 308),

  --! An sentinel object represeting no value was 
  --! produced by the underlying reactive generator.
  NO_PUSHED_VALUE = { }

  -- Built-in generator objects
  
  -- Bool
  -- Octet
  -- Char
  -- WChar
  -- Float
  -- Double
  -- LongDouble
  -- Short
  -- Long
  -- LongLong
  -- UShort
  -- ULong
  -- ULongLong
  -- String
  -- WString

  -- Generator factory functions.
  -- Most methods produce new generators. 
  -- All methods below are non-instance methods.

  --emptyGen
  --singleGen
  --constantGen
  --oneOfGen
  --numGen

  --boolGen
  --charGen
  --asciiGen
  --wcharGen
  --octetGen
  --shortGen
  --int16Gen
  --int32Gen
  --int64Gen
  --uint16Gen
  --uint32Gen
  --uint64Gen

  --posFloatGen
  --posDoubleGen
  --floatGen
  --doubleGen

  --getPrimitiveGen

  --lowercaseGen
  --uppercaseGen
  --alphaGen
  --alphaNumGen
  --printableGen
  --stringGen
  --nonEmptyStringGen
  
  --coroutineGen
  --concatAllGen
  --alternateGen
  --deferredGen
  
  --rangeGen
  --seqGen
  --arrayGen
  --aggregateGen
  --enumGen

  --newGenerator
  --createGenerator

  --find
  --every
  --foreach
  --sort
  --sortBy
  --partition
  --lastN
 
  --initialize

} -- Public

--- Min value of a float (single precision) (negative `MAX_FLOAT`)
Public.MIN_FLOAT   = -Public.MAX_FLOAT
--- Min value of a double (double precision) (negative `MAX_DOUBLE`)
Public.MIN_DOUBLE  = -Public.MAX_DOUBLE

--- Min value of a 16-bit integer. (-`MAX_INT16`-1) 
Public.MIN_INT16   = -Public.MAX_INT16-1 
--- Min value of a 32-bit integer. (-`MAX_INT32`-1)
Public.MIN_INT32   = -Public.MAX_INT32-1 
--- Min value of a 32-bit integer. (-`MAX_INT64`-1)
Public.MIN_INT64   = -Public.MAX_INT64-1 

setmetatable(Public.NO_PUSHED_VALUE, {
    __tostring = function () return "NO_PUSHED_VALUE" end
})

--- The Generator "interface". The base interface for all pull-based generators.
-- @type Generator
local Generator = { }

--! Generator:new
--! Generator:generate
--! Generator:kind
--! Generator:map
--! Generator:flatMap
--! Generator:concatMap
--! Generator:zipMany
--! Generator:amb
--! Generator:scan
--! Generator:reduce
--! Generator:take
--! Generator:skip
--! Generator:last
--! Generator:concat
--! Generator:append
--! Generator:where
--! Generator:reject
--! Generator:toTable


-- Only private methods/data
local Private = { 
  -- createMemberGenTab
  -- createGeneratorImpl
  -- seqParseGen
}

-- A queue implementation
local Queue = {}
  
--==================================================--
-- Generator member functions

--! @brief Overrides __tostring for all Generators
--! @return A string of the form "Generator: 0xaddress"
function Generator:__tostringx ()
  Generator.__tostring = nil    
  local s = string.gsub(tostring(self), "table", "Generator")
  Generator.__tostring = Generator.__tostringx
  return s
end

Generator.__tostring = Generator.__tostringx    

--! Creates a new generator from an implementation of generate(). 
--!  @param[in] generateFunc A function that implements generate(). 
--!         I.e., the function should accept no arguments and must return a value.
--!  @return A new generator that uses the generateFunc to produce values.
--!  @see   Public.newGenerator 
function Generator:new(generateFunc)
  o = { genImpl = generateFunc }
  setmetatable(o, self)
  self.__index = self
  return o
end

--- Generates a new value or returns nil, false.
--  @treturn generic A new value. It's valid only if the second 
--  value is true. 
--  @treturn bool True if generator has not finished. If the 
--  second value is false, generator is complete. 
function Generator:generate()
  return self.genImpl()
end

--- Creates a new generator that "applies" the given function 
--  to each value generated by the self generator. The resulting
--  generator produces the values returned by the argument function.
--  @tparam function func A function that transforms the input 
--  value to an output value. I.e., the function must accept 
--  one argument and must return a value.
--  @treturn Generator A new generator that generates the result 
--  of applying func.
function Generator:map(func)
  return Generator:new(function () 
           local val, valid = self:generate()
           if valid then
             return func(val), true
           else
             return nil, false
           end
         end)
end

--- Returns a generator that produces values for which
--  the predicate returns true. If the underlying generator 
--  is infinite and no value ever satisfies the predicate,
--  the resulting generator will never produce any value
--  and will block forever (when generate is called).
--  @tparam function predicate A unary function that returns
--  true for the "desirable" values. The values for which
--  predicate returns false, are omitted from the resulting
--  generator.
--  @treturn Generator A new generator
function Generator:where(predicate)
  
  return Generator:new(function()
    local data, valid = self:generate()
    
    while valid and (predicate(data) == false) do
      data, valid  = self:generate()  
    end

    if valid then
      return data, true
    else
      return nil, false
    end

  end)
end

--- Opposite of Generator:where. Returns a generator that 
--  rejects the values for which the predicate returns true. 
--  @tparam function predicate A unary function that returns
--  true for the "undesirable" values. The values for which
--  predicate returns true, are omitted from the resulting
--  generator.
--  @treturn Generator A new generator
function Generator:reject(predicate)
  return self:where(function(i) return predicate(i) == false end)
end

--- Same as Generator:concat
--  @tparam Generator otherGen A generator 
--  @treturn Generator A new generator 
function Generator:append(otherGen) 
  return self:concat(otherGen)
end

--- Creates a new generator that appends otherGen to self.
--  @tparam Generator otherGen A generator 
--  @treturn Generator A new generator 
function Generator:concat(otherGen) 
  local first = true
  return  Generator:new(function () 
            if first then 
              local value, valid = self:generate()
              if valid then
                return value, valid
              else
                first = false
              end
            end
            
            if first == false then
              return otherGen:generate()
            end
          end)
end

--- Creates a new generator that returns only the first 
--  count values. For example,
--    Gen.inOrderGen({1,2,3,4,5}):take(2) 
--  returns a generator that produces 1 and 2.
--  @tparam int count (optional) A positive number. If count is not
--  provided take has no effect.
--  @treturn Generator A new generator 
function Generator:take(count) 
  if count < 0 then
    error "Generator:take: Invalid argument. Negative count" 
  end
  
  if count == nil then return self end
  
  local i = 0
  return Generator:new(function () 
           if i < count then
             local val, valid = self:generate() 
             i = i + 1
             if valid then
               return val, true
             end
           end
           return nil, false
         end)
end

--- Creates a new generator that skips the first 
--  count values. For example,
--    Gen.inOrderGen({1,2,3,4,5}):skip(3) 
--  return a generator that produces 4 and 5.
--  @tparam int count (optional) A positive number. If count is
--  not provided, the resulting generator is empty.
--  @treturn Generator A new generator 
function Generator:skip(count) 
  if count < 0 then
    error "Generator:skip: Invalid argument. Negative count" 
  end

  if count == nil then return Public.emptyGen() end
  
  local i = -1
 
  return Generator:new(function () 
            local data, valid
            
            repeat
              data, valid = self:generate()
              if i < count then i = i + 1 end
            until not (i < count and valid)
            
            if valid then 
              return data, true
            else
              return nil, false
            end
         end)
end

--- Creates a new generator that produces only the last 
--  (at most) count values. For example,
--    Gen.inOrderGen({1,2,3,4,5}):last(2) 
--    Gen.inOrderGen({1,2,3,4,5}):last(7) 
--  return generators that produce [4,5] and [1,2,3,4,5] respectively.
--  @tparam int count (optional) A positive number. If count is not
--  provided, it defaults to 1.
--  @treturn Generator A new generator 
function Generator:last(count) 
  count = count or 1
  
  if count < 0 then
    error "Generator:skip: Invalid argument. Negative count" 
  end

  local i = 0
  local plenty = 0
  local storage = {}
  local first = true
  
  if count == 0 then return Public.emptyGen() end
  
  return Generator:new(function () 
            local data = nil
            local valid = true

            if first then
              while valid do
                data, valid = self:generate()
                if valid then 
                  if plenty < count then
                    plenty = plenty + 1
                  end
                  storage[i] = data 
                  i = (i + 1) % count
                end
              end
              first = false
              if plenty ~= count then
                i = 0
              end
            end

            if storage[i] then
              local temp = storage[i]
              storage[i] = nil
              i = (i + 1) % count
              return temp, true
            end
            
            return nil, false
         end)
end

--- Creates a new generator that applies the given function to each 
--  value generated by the self generator and invokes generate() on 
--  the return value till it ends. When the inner Generator ends,
--  flatMap repeats the process with the next object in the source 
--  generator till it ends. 
--  
--  Effectively, flatMap flattens `Generator[Generator[T]]` to `Generator[T]`. 
--  If any of the inner Generators are infinite, flatMap will never get 
--  to the next inner Generator. 
--
--  This function may be alternative called concatMap.
--  @tparam function func A function that transforms the input value to 
--  a generator. I.e., the function should accept one argument and must 
--  return a generator. If func is missing, self must be a 
--  Generator[Generator[T]]. 
--  @treturn Generator A new generator that returns the values generated 
--  by the generator produced by func.
function Generator:flatMap(func)
  local nestedGen = nil
  func = func or function(g) return g end
  
  return Generator:new(function () 
           while true do  
             if nestedGen == nil then 
               while true do
                 local val, valid = self:generate()
                 if valid then 
                   nestedGen = func(val)
                   break
                 else
                   return nil, false
                 end 
               end
             end

             local nested_val, nested_valid = nestedGen:generate()
             if nested_valid then
               return nested_val, true
             else
               nestedGen = nil
             end
           end
         end)
end

--- See `Generator:flatMap`
function Generator:concatMap(func)
  return self:flatMap(func)
end

--- Creates a new generator that applies the given function to the values
--  generated by the argument generators. This function accepts arbitrary
--  number of geneators as arguments (including zero). The last argument 
--  must be a function that accepts as many arguments as there are 
--  generators (including self). 
--  @tparam Generator ... Zero or more generators separated by comma. 
--  @tparam function zipperFunc A function that aggregates one or more values 
--  into one. I.e., the function should accept as many arguments as there are 
--  generators and must return a value. The value generated by the self generator
--  is the first value passed to the function.
--  @treturn Generator A new generator that generates the result of applying 
--  the zipper function.
function Generator:zipMany(...)
  local argLen = select("#", ...)
  local zipperFunc = select(argLen, ...)
  
  if type(zipperFunc) ~= "function" then
    error "Error: zipMany: Invalid arguments"
  end
  
  local genList = { self }

  for i=1, argLen-1 do
    genList[#genList+1] = select(i, ...)
  end

  return Generator:new(function () 
           local tuple = {}
           for i=1, argLen do
              local ti, ti_valid = genList[i]:generate()
              if ti_valid then
                tuple[i] = ti
              else
                return nil, false
              end
           end
           return zipperFunc(table.unpack(tuple)), true
         end)
end

--- Creates a new generator that returns the values produced by the 
--  argument generators (self and otherGen) non-derministically.
--  amb stands for ambiguous.
--  @tparam Generator otherGen A generator 
--  @treturn Generator A new generator 
function Generator:amb(otherGen) 
  return Public.boolGen():flatMap(function (b) 
        return b and self or otherGen
      end)
end

--- Creates a new generator that reduces values according
--  to the reducer function. The resulting generator
--  produces as many values as in the source generator.
--  For example,
--    Gen.inOrderGen({1,2,3,4,5})
--       :scan(function (sum, i) return sum+i end, 0) 
--  returns a generator that produces [1,3,6,10,15].
--  @tparam function reducerFunc A function that reduces the 
--  sequence produced by the generator. Takes two arguments and 
--  returns the reduced value. The first argument is the accumulated
--  value, which is same as init for the first call.
--  @param init initial state for the reducer function.
--  @treturn Generator A new generator.
function Generator:scan(reducerFunc, init)
  return Generator:new(function ()
                         local val, valid = self:generate()
                         if valid then 
                           init = reducerFunc(init, val)
                           return init, true
                         else
                           return nil, false
                         end
                       end)
end

--- Creates a new single value generator that reduces the 
--  values according to the reducer function. Given
--  a generator self and reducer function f, the following
--  two expressions are equivalent.
--    self:reduce(f, init) 
--    self:scan(f, init):last()
--  If self is infinite, this function never returns.
--  @tparam function reducerFunc A function that reduces the sequence
--  produced by the generator. Takes two arguments and 
--  returns the reduced value. The first argument is the accumulated
--  value, which is same as init for the first call.
--  @param init The initial state for the reducer function.
--  @treturn Generator A new generator.
function Generator:reduce(reducerFunc, init)
  local first = true
  
  --! Alternative slightly inefficient implementation
  --! return self:scan(reducerFunc, init):last()
  
  return Generator:new(function ()
                        if first then 
                          repeat
                            local value, valid = self:generate()
                            if valid then 
                              init = reducerFunc(init, value)
                            end
                          until valid == false 
                        end
                        
                        if first then
                          first = false
                          return init, true
                        else
                           return nil, false
                        end
                      end)
end

-- GroupByOp class
local GroupByOp = Generator:new()

function GroupByOp:new(srcGen, keySelector)
  local gop = { srcGen      = srcGen,
                keySelector = keySelector,
                queues      = {},
                innerGenTab = {},
                innerGenQ   = Queue:new()
              }
  gop.genImpl = function() return gop:generateGroup() end
  setmetatable(gop, self)
  self.__index = self
  return gop
end 

--! GroupByOp.generateCommon returns true if it is able to produce something
--! meaningful. The function operates in two modes depending
--! upon how it is called. Two modes use the same function because
--! largrly same things need to happen in both cases. 
--! The mode determines when the while loop ends.
--! 
--! Mode1: matchKey == nil
--! First, when the outermost generator invokes GroupByOp.generateCommon, 
--! it does not pass matchKey. In this case, GroupByOpgenerate function 
--! is looking for the next *group*.
--!
--! Mode1: matchKey ~= nil
--! Second, when an inner generator invokes generateCommon, it passes a matchKey. 
--! because the inner generator is looking for a value matching a specific key.
--! 
--! In both cases, the source generator usually advances and may hit
--! the end. As the source generator is producing values, they must be
--! put into right buckets. 
--!
--! The while loop ends only when there's something meaningful to return
--! or the source generator ends. Whether there's something meaningful
--! to return depends on the *mode*. I.e., when matchKey is non-nil,
--! the while loop checks in a key-specific queue otherwise it checks
--! in the generator queue.
--!
--! Finally, the last return statement depends on the *mode* and return
--! true if the function was successful in producing something that the 
--! mode wanted.
function GroupByOp.generateCommon(gop, matchKey)
  local data, valid = nil, true

  while (valid and     matchKey and gop.queues[matchKey]:isEmpty()) or 
        (valid and not matchKey and gop.innerGenQ:isEmpty()) do
  
    data, valid = gop.srcGen:generate()
    
    if valid then
      local key = gop.keySelector(data)
      
      if key == nil then 
        error("groupBy: key can't be nil") 
      end
      
      if gop.queues[key] == nil then
        gop.queues[key] = Queue:new()
      end
      
      gop.queues[key]:pushRight(data)

      if gop.innerGenTab[key] == nil then
        gop.innerGenTab[key] = Generator:new(function()
          return gop:generateGroupMember(key)
        end)
        
        gop.innerGenTab[key].getKey = 
          function() return key end
          
        gop.innerGenQ:pushRight(gop.innerGenTab[key])
      end
    end
  end

  if matchKey then
    return not gop.queues[matchKey]:isEmpty()
  else
    return not gop.innerGenQ:isEmpty()
  end
  
end  

--! Invoke GroupByOp.generateCommon in Mode 2
function GroupByOp.generateGroupMember(gop, key)
  if gop:generateCommon(key) then
    return gop.queues[key]:popLeft(), true
  else
    gop.queues[key] = nil
    gop.innerGenTab[key] = nil
    return nil, false
  end
end

--! Invoke GroupByOp.generateCommon in Mode 1
function GroupByOp.generateGroup(gop)
  if gop:generateCommon() then
    return gop.innerGenQ:popLeft(), true
  else
    return nil, false
  end
end

--- Creates a generator of "keyed generators" according to a keySelector function.
--  Each keyed-generator, as the name suggests, is itself a Generator. 
--  Each keyed-generator produces one or more values of the same "key" in the order
--  they appear in the source generator. The key can be obtained by calling
--  getKey() on the keyed-generator.
--
--  This method is implemented by using deferred execution. The immediate return value 
--  is a Generator that stores all the information that is required to perform the action. 
--  The keyed-generator objects are produced in an order based on the order of the elements 
--  in source that produced the first key of each keyed-generator. Elements in a grouping 
--  are produced in the order they appear in the source.
--
--  The groupBy combinator has some limitations when used with infinite generators. 
--  @tparam function keySelector A unary function that return the "key" part of each
--  object produced by the source generator.
--  @treturn Generator A generator of keyed-generators.   
function Generator:groupBy(keySelector)
  return GroupByOp:new(self, keySelector)
end

--- Returns a generator that repeats the objects produced by the source generator
--  after the source generator ends. If the source is empty, the resulting genrator 
--  is also empty.
--  @treturn Generator A generator that repeats the objects produced by the source 
--  generator
function Generator:repeatAll()
  local buf = {}
  local done = false
  local i = 0
  
  return Generator:new(function()
    if not done then    
      local data, valid = self:generate()
      if valid then 
        buf[#buf+1] = data
        return data, true
      end
      done = true
    end
    
    if #buf == 0 then
      return nil, false
    else
      i = (i % #buf) + 1
      return buf[i], true
    end
  end)
end

--- Returns the generator kind (either "pull" or "push").
--  @treturn string Either "pull" or "push"
function Generator:kind()
  return "pull"
end

--- Returns a table containing all the elements produced
--  by the generator. Note that this function may not
--  return and may cause excessive memory consumption
--  if the underlying generator is very large or infinite.
--  If the function returns, the generator is completely
--  exhausted.
--  @treturn table A table containing all the values
--  produced by the generator.
function Generator:toTable()
  local data = {}
  
  while true do
    local value, valid = self:generate();
    
    if valid then
      data[#data+1] = value
    else
      return data
    end
  end
end

--- Generator factory functions
-- @section FactoryFunctions

--- Creates a single value generator.
--  @param val A value
--  @treturn Generator A single value generator that
--  produces val.
function Public.singleGen(val)
  local done = false
  return Generator:new(function () 
                         if done == false then
                           done = true
                           return val, true 
                         else 
                           return nil, false
                         end
                       end)
end

--- Creates a infinite constant-value generator.
--  @param val A value
--  @return A constant value generator that produces
--  val infinitely.
function Public.constantGen(val)
  return Generator:new(function () return val, true end)
end

--- Creates an empty generator.
--  @treturn Generator An empty generator. 
function Public.emptyGen()
  return Generator:new(function () return nil, false end)
end

--- Creates a generator that produces one of the
--  items specified in the input array. If the input
--  array is empty, the resulting generator is empty.
--  Otherwise, the resulting generator is infinite.
--  @tparam array array An array of values to choose from.
--  @treturn Generator A generator.
function Public.oneOfGen(array)
  local len = #array
  return Generator:new(function ()
                         if len == 0 then
                           return nil, false
                         else
                           return array[math.random(1, len)], true
                         end
                       end)
end

--- Creates a generator that produces positive integers in
--  range 1 to Public.MAX_INT32.
--  @treturn int A generator that produces positive integers.
function Public.numGen()
  return Generator:new(function () 
    return math.random(Public.MAX_INT32), true
  end)
end
  
--- Creates a generator that produces integers
--  in the range of Public.MIN_INT16 and Public.MAX_INT16.
--  @return A generator of integers.
function Public.int16Gen()
  return Generator:new(function () 
    return math.random(Public.MIN_INT16, 
                       Public.MAX_INT16), true
  end)
end

--- Creates a generator that produces integers
--  in the range of Public.MIN_INT32 and Public.MAX_INT32.
--  @treturn Generator A generator of integers.
function Public.int32Gen()
  return Generator:new(function () 
    return math.random(Public.MIN_INT32, 
                       Public.MAX_INT32), true
  end)
end
  
--- Creates a generator that produces integers
--  in the range of Public.MIN_INT64/4 and Public.MAX_INT64/4.
--  @treturn Generator A generator of integers.
function Public.int64Gen()
  return Generator:new(function () 
    return math.random(Public.MIN_INT64/4, 
                       Public.MAX_INT64/4), true
  end)
end
  
--- Creates a generator that produces positive integers
--  no larger than Public.MAX_UINT16.
--  @treturn Generator A generator of integers.
function Public.uint16Gen()
  return Generator:new(function () 
    return math.random(0, Public.MAX_UINT16), true
  end)
end

--- Creates a generator that produces positive integers
--  no larger than Public.MAX_UINT32.
--  @treturn Generator A generator of integers.
function Public.uint32Gen()
  return Generator:new(function () 
    return math.random(0, Public.MAX_UINT32), true
  end)
end
  
--- Creates a generator that produces positive integers
--  no larger than Public.MAX_UINT64.
--  @treturn Generator A generator of integers.
function Public.uint64Gen()
  return Generator:new(function () 
    return math.random(0, Public.MAX_UINT64), true
  end)
end
  
--- Creates a generator that produces integer values 
--  in the specified range (inclusive).
--  @tparam int loInt The lower integer
--  @tparam int hiInt The higher integer
--  @treturn Generator A generator of integers.
function Public.rangeGen(loInt, hiInt)
  if hiInt < loInt then
    return Public.emptyGen();
  else
    return Generator:new(function() 
             return math.random(loInt, hiInt), true
           end)
  end
end

--- Creates a generator that produces boolean
--  values non-deterministically.
--  @treturn Generator A generator of booleans.
function Public.boolGen()
  return Generator:new(function () 
    return math.random(2) > 1, true;
  end)
end

--- Creates a generator that produces integer values 
--  in the range of 0 and 127 (inclusive).
--  @treturn Generator A generator of integers
function Public.asciiGen()
  return Public.rangeGen(0, 127)
end

--- Creates a generator that produces integer values 
--  in the range of 0 and Public.MAX_BYTE.
--  @treturn Generator A generator of integers
function Public.charGen()
  return Public.rangeGen(0, Public.MAX_BYTE)
end

--- Creates a generator that produces integer values 
--  in the range of 0 and Public.MAX_INT16.
--  @treturn Generator A generator of integers
function Public.wcharGen()
  return Public.rangeGen(0, Public.MAX_INT16)
end

--- Creates a generator that produces integer values 
--  in the range of 0 and Public.MAX_BYTE.
--  @treturn Generator A generator of integers.
function Public.octetGen()
  return Public.rangeGen(0, Public.MAX_BYTE)
end

--- Creates a generator that produces integers
--  in the range of Public.MIN_INT16 and Public.MAX_INT16.
--  @treturn Generator A generator of integers.
function Public.shortGen()
  return Public.int16Gen()
end

--- Creates a generator that produces positive floating
--  point numbers in the range of 0 and Public.MAX_INT16
--  @treturn Generator A generator of floating point numbers.
function Public.posFloatGen()
  return Generator:new(function()
           return math.random() * math.random(0, Public.MAX_INT16), true
         end)
end

--- Creates a generator that produces positive floating 
--  point numbersin the range of 0 and Public.MAX_INT32.
--  @treturn Generator A generator of floating point numbers.
function Public.posDoubleGen()
  return Generator:new(function()
           return math.random() * math.random(0, Public.MAX_INT32), true
         end)
end

--- Creates a generator that produces floating point numbers
--  in the range of negative Public.MAX_INT16 and Public.MAX_INT16.
--  @treturn Generator A generator of floating point numbers.
function Public.floatGen()
  return Public.boolGen():map(function(b)
           local num = math.random() * math.random(0, Public.MAX_INT16)
           if b then
             return num
           else
             return -num
           end
         end)
end

--- Creates a generator that produces floating point numbers
--  in the range of negative Public.MAX_INT32 to Public.MAX_INT32.
--  @treturn Generator A generator of floating point numbers.
function Public.doubleGen()
  return Public.boolGen():map(function(b)
           local num = math.random() * math.random(0, Public.MAX_INT32)         
           if b then
             return num
           else
             return -num
           end
         end)
end

--- Creates a generator that produces floating point numbers
--  in the range of negative Public.MAX_INT64 to Public.MAX_INT64.
--  @treturn Generator A generator of floating point numbers.
function Public.longDoubleGen()
  return Public.boolGen():map(function(b)
           local num = math.random() * math.random(0, Public.MAX_INT64)         
           if b then
             return num
           else
             return -num
           end
         end)
end

--- Creates a generator that produces lowercase alphabets
--  @treturn Generator A generator of integers
function Public.lowercaseGen()
  local a = 97
  local z = 122
  return Public.rangeGen(a, z)
end

--- Creates a generator that produces uppercase alphabets
--  @treturn Generator A generator of integers
function Public.uppercaseGen()
  local A = 65
  local Z = 90
  return Public.rangeGen(A, Z)
end

--- Creates a generator that produces lowercase and uppercase alphabets
--  @treturn Generator A generator of integers
function Public.alphaGen()
  return Public.lowercaseGen():amb(
            Public.uppercaseGen())
end

--- Creates a generator that produces alphabets and digits
--  @treturn Generator A generator of integers
function Public.alphaNumGen()
  local zero = 48
  local nine = 57
  return Public.alphaGen():amb(
            Public.rangeGen(zero, nine))
end

--- Creates a generator that produces printable characters
--  @treturn Generator A generator of integers
function Public.printableGen()
  local space = 32
  local tilde = 126
  return Public.rangeGen(space, tilde)
end

--- Creates a generator that produces a sequence  
--  no larger than maxLength containing elements
--  generated by the input generator. Possibly empty.
--  @tparam Generator elemGen An element generator
--  @tparam int maxLength Maximum size of the sequence.
--  @treturn Generator A generator of sequences. 
function Public.seqGen(elemGen, maxLength)
  elemGen = elemGen or Public.constantGen("unknown ")
  maxLength = maxLength or Public.MAX_BYTE+1
 
  return 
    Public.rangeGen(0, maxLength)
          :map(function (length) 
                 local arr = {}
                 for i=1,length do
                   local arr_i, valid = elemGen:generate()
                   if valid then
                     arr[i] = arr_i
                    else
                     return nil, false
                   end
                 end
                 return arr, true
               end)
end

--- Creates a generator that produces an array  
--  of exactly length elements generated by the
--  input generator. 
--  @tparam Generator elemGen An element generator
--  @tparam int length The size of the array.
--  @treturn Generator A generator of arrays. 
function Public.arrayGen(elemGen, length)
  elemGen = elemGen or Public.constantGen("unknown ")

  if length==nil or length < 0 then
    error "Error: Invalid array length."
  end
 
  return 
    Generator:new(function ()
                    local arr = {}
                    for i=1,length do
                      local arr_i, valid = elemGen:generate()
                      if valid then
                        arr[i] = arr_i
                      else
                        return nil, false
                      end
                    end
                    return arr, true
                  end)
end

--- Creates a generator that produces non-empty strings
--  @tparam int maxLength (optional) The maximum length of the string. 256 by default
--  @tparam Generator charGen (optional) A generator for characters.
--  By default Public.printableGen() generator.
--  @treturn Generator A generator of non-empty strings. 
function Public.nonEmptyStringGen(maxLength, charGen)
  charGen = charGen or Public.printableGen()
  maxLength = maxLength or Public.MAX_BYTE+1

  return 
    Public.rangeGen(1, maxLength)
             :map(function (length) 
                    local arr = {}
                    for i=1,length do
                      local arr_i, valid = charGen:generate()
                      if valid then
                        arr[i] = string.char(arr_i)
                      else
                        return nil, false
                      end
                    end
                    return table.concat(arr), true
                  end)
end

--- Creates a generator that produces (possibly empty) strings
--  @tparam int maxLength (optional) The maximum length of the string. 256 by default
--  @tparam Generator charGen (optional) A generator for characters.
--  By default Public.printableGen() generator.
--  @tparam int emptyPeriod (optional) Indicates the desirable frequency of 
--  empty strings. 1 out of every emptyPeriod strings shall be
--  empty (distributed uniformly). Default 10
--  @treturn Generator A generator of possibly empty strings.
function Public.stringGen(maxLength, charGen, emptyPeriod)
  charGen     = charGen or Public.printableGen()
  maxLength   = maxLength or Public.MAX_BYTE+1
  emptyPeriod = emptyPeriod or 10

  return 
    Public.rangeGen(1, maxLength)
         :map(function (length) 
                local arr = {}
                local nonempty = math.random(1, emptyPeriod) > 1
                if nonempty then
                  for i=1,length do
                    local arr_i, valid = charGen:generate()
                    if valid then
                      arr[i] = string.char(arr_i)
                    else
                      return nil, false
                    end
                  end
                end
                return table.concat(arr), true
              end)
end

--- Creates a generator from a Lua coroutine. 
--  @tparam lua-coroutine coro A coroutine. Any arguments after 
--  coro are passed to the coroutine at the first resume.
--  @treturn Generator A generator that uses the input coroutine 
--  as the true source of data.
function Public.coroutineGen(coro, ...)
  local args = { ... }
  local first = true
  local _, value = nil
  
  return Generator:new(function ()
          if coroutine.status(coro) == "dead" then
            return nil, false
          else
            if first then
              first = false
              _, value = coroutine.resume(coro, table.unpack(args))
            else
              _, value = coroutine.resume(coro)
            end

            if coroutine.status(coro) == "dead" then
              if value then
                return value, true
              else
                return nil, false
              end
            else
              return value, true
            end
          end
         end)
end

--- Creates a generator that concatinates all the input generators
--  @tparam Generator ... A comma-separated list of generators
--  @treturn Generator A generator that concatenates all the input generators.
function Public.concatAllGen(...)
  local args = { ... }
  
  return Public.stepperGen(1, #args)
               :flatMap(function (i)
                          return args[i]
                        end)
end

--- Creates a generator that alternates sequentially between all the input generators
--  @tparam Generator ... A comma-separated list of generators
--  @treturn Generator A generator that alternates sequentially between the input generators.
function Public.alternateGen(...)
  local args = { ... }
  local active = {}
  local search = true
   
  for i = 1, #args do 
    active[i] = true
  end
  
  local stepper = Public.stepperGen(1, #args, 1, true)
  
  return Generator:new(function ()
    if search then
      search = false
      for i = 1, #args do
        local idx = stepper:generate()
        if active[idx] then
          local value, valid = args[idx]:generate()
          if valid then
            search = true
            return value, valid
          else
            active[idx] = false
          end
        end
      end
    end
    return nil, false
  end)
end

--- Creates a lazy generator that is equivalent to the generator returned 
--  by the thunk function. The objective of deferredGen is to delay
--  the invocation of the thunk until absolutely needed. In a way,
--  it supports lazy evaluation.
--  @tparam function thunk A zero-argument function that returns a generator. 
--  This is generally expected to be a small function with a single statement 
--  that returns a generator. 
--  @treturn Generator A new generator 
function Public.deferredGen(thunk)
  return Public.singleGen(0xDEADBEEF):flatMap(thunk)
end

--- Creates a new generator from a user-supplied implementation of generate function 
--  @tparam function generateFunc A function that implements generate(). 
--  I.e., the function should accept no arguments and must return a value.
--  @treturn Generator A new generator that uses the generateFunc to produce values.
function Public.newGenerator(generateFunc)
  return Generator:new(generateFunc)
end

--- Creates a new generator of fibonacci numbers
--  @treturn Generator A new generator of fibonacci numbers
function Public.fibonacciGen()
  local a = 0
  local b = 1
  return Generator:new(function ()
           local c = a;
           a = b
           b = c+b
           return c, true
         end)
end  

--- Creates a stepper generator, which generates numbers in a sequence. 
--  It behaves much like a for loop.
--  @tparam int start (optinoal) The beginning value. Default=1
--  @tparam int max   (optional) The maximum value. Default=math.huge
--  @tparam int step  (optional) The step size. default=1
--  @tparam bool cycle (optional) Whether to repeat the numbers cyclically. Default=false
--  @treturn Generator A new generator that generates numbers in steps.
function Public.stepperGen(start, max, step, cycle)
  start = start or 1
  max   = max   or math.huge
  step  = step  or 1
  cycle = cycle or false
  
  if step >= 0 then
    if start > max then
      return Public.emptyGen();
    end
  else
    if start < max then
      return Public.emptyGen();
    end
  end

  local current = start
  local init = false

  return Generator:new(function ()
           if init==false then 
             init = true
           else
             if step >= 0 then
               if current + step <= max then 
                  current = current + step
               else
                 if cycle then 
                   current = start 
                 else
                   return nil, false
                 end
               end
             else
               if current + step >= max then 
                  current = current + step
               else
                 if cycle then 
                   current = start 
                 else
                   return nil, false
                 end
               end
             end
           end
           return current, true 
         end)
end  

--- Creates a generator that produces all the permutations of the values  
--  in the input array. When the generator ends, the input array is
--  back to its original state.
--  @tparam array src The array containing values. May be empty.
--  @treturn Generator A new generator that produces all permutations.
function Public.permutationGen(src)
  return Public.coroutineGen(coroutine.create(function()
           Private.permute(src, 1, #src)
         end))
end

--- Returns a generator that produces objects from the source generator 
--  as long as the conditionGen generator produces objects.
--  @tparam Generator srcGen The source generator
--  @tparam Generator conditionGen The "condition" generator. 
--  @treturn Generator A generator that produces objects from the source 
--  generator as long as the conditionGen generator produces objects.
function Public.doWhileGen(srcGen, conditionGen)
  return conditionGen:map(function(c)
            local data, valid = srcGen:generate()
            return data
          end)
end

--- Creates a generator that produces values from the input array in order.
--  @tparam array array The array containing values. May be empty.
--  @tparam bool cycle (optional) Whether to repeat the values cyclically. Default=false
--  @treturn Generator A new generator that produces values from the input array.
function Public.inOrderGen(array, cycle)
  if #array == 0 then
    return Public.emptyGen()
  end

  cycle = cycle or false

  return Public.stepperGen(1, #array, 1, cycle)
               :map(function (i)
                      return array[i]
                    end)
end

--! Convert a reactive generator to a pull-based generator
--!  @param reactGen The input reactive generator
--!  @param subjectGroup A group of subjects that when pushed produce
--!  a single value through the reactive generator.
--!  @return A pair of pull-based generator and a disposable.
function Public.toGenerator(reactGen, subjectGroup)
  local ret = Public.NO_PUSHED_VALUE
  
  local disposable = 
    reactGen:listen(function (val) ret = val end)

  local gen = Generator:new(function ()
          if disposable:isDisposed() then
            return nil, false
          end
          ret = Public.NO_PUSHED_VALUE
          subjectGroup:push()
          -- ret should be updated by now.
          -- If not, you get NO_PUSHED_VALUE!"
          return ret, true
      end)

  return gen, disposable
end

--- Generator algorithm functions
-- @section AlgorithmFunctions

--- Returns the first value that satisfies the predicate. 
--  If the generator is infinite and no value ever satisfies 
--  the predicate, the function blocks forever. 
--  @tparam Generator generator Input generator
--  @tparam function predicate A unary function that returns true/false.
--  @return The first value satisfying the predicate
function Public.find(generator, predicate)
  return generator:where(predicate):take(1):generate()
end

--- Returns true if every value produced by the generator 
--  satisfies the predicate. 
--  @tparam Generator generator Input generator
--  @tparam function predicate A unary function that returns true/false.
--  @return true/false
function Public.every(generator, predicate)
  return 
    Public.find(generator, 
                function(i) 
                  return predicate(i) == false 
                end) == nil
end

--- Invokes a function on every generated value
--  @tparam Generator generator Input generator
--  @tparam function func A unary function
function Public.foreach(generator, func)
    repeat 
      local data, valid = generator:generate()
      if valid then func(data) end
    until valid == false
end

--- Sorts the values produced by the generator
--  @tparam Generator generator Input generator
--  @tparam function func (optional) A binary comparator function
--  @treturn table A sorted table of generated values.
function Public.sort(generator, func)
    local data = generator:toTable()
    table.sort(data, func)
    return data
end

--- Sorts the values produced by the generator with 
--  object.property as key.
--  @tparam Generator generator Input generator
--  @tparam string property The algorithm uses object[property] to sort. 
--  For example, to sort with person.name, pass "name"
--  @tparam function func (optional) A binary comparator function 
--  for property
--  @treturn table A sorted table
function Public.sortBy(generator, property, func)
    local data = generator:toTable()
    if func then
      table.sort(data,function (i, j) 
                         return func(i[property], j[property])
                      end)
    else 
      table.sort(data,function (i, j) 
                         return i[property] < j[property]
                      end)
    end
    return data
end

--- Splits the values produced by the generator into buckets
--  determind by the groupingFunc. 
--  @tparam Generator generator Input generator
--  @tparam function groupingFunc A unary function that identifies 
--  a bucket for input value. bucket is also a "key"
--  @treturn table A table of tables. The table contains buckets identified by
--  by the groupingFunc. Each bucket contains at least one element.
function Public.partition(generator, groupingFunc)
    local data = {}
    Public.foreach(generator, 
                   function (i) 
                     local key = groupingFunc(i)
                     data[key] = data[key] or {}
                     local bucket = data[key]
                     bucket[#bucket+1] = i 
                   end)
    return data
end

--- Returns a table containing the last N generated values
--  @tparam Generator generator Input generator
--  @tparam int count (optional) Last count values are returned. Default 1.
--  @treturn table A table containing last N values
function Public.lastN(generator, count)
    count = count or 1
    return generator:last(count):toTable()
end

--- Initialize the generator library. 
--  @tparam int seed (optional) The seed for the random number generator
--  @return The generator module reference.
function Public.initialize(seed)
  seed = seed or os.time()
  math.randomseed(seed)
  return Public
end

--- Generator factory functions for DDSL types
-- @section DDSLFunctions

--- Creates a generator that produces structured type instances conforming
--  the aggregateType defined using DDSL.
--  @tparam xtemplate aggregateType The xtypes type definition as per DDSL.
--  @tparam GeneratorLin genLib (optional) A library of generators for members 
--  and types. I.e., if aggregateType contains a member named "x", genLib[x] 
--  generator is used if it exists. If genLib[x] does not exist and x has type
--  T, then genLib.typeGenLib[T] is used if it exists.
--  @tparam bool memoizeGen (optional) true if the member-specific generators 
--  should  be cached in genLib. false otherwise.
--  @treturn Generator A generator of values of structured types.
function Public.aggregateGen(aggregateType, genLib, memoizeGen)

  genLib = genLib or { }
  genLib.typeGenLib = genLib.typeGenLib or { } 
  local gen = nil
  
  if genLib.typeGenLib[aggregateType[xtypes.NAME]] then
    return genLib.typeGenLib[aggregateType[xtypes.NAME]]
  end

  if aggregateType[xtypes.KIND]() == "union" then
    gen = Private.zunionGen(aggregateType, genLib, memoizeGen)
  else -- struct
    local memberGenTab 
      = Private.zcreateMemberGenTab(
            aggregateType, genLib, memoizeGen)

    gen = Generator:new(function () 
             local data = {}
             for member, gen in pairs(memberGenTab) do
               local val, valid = gen:generate()
               if valid then
                 data[member] = val
               else
                 return nil, false
               end
             end
             return data, true
           end)
  end
  
  if memoizeGen then
    genLib.typeGenLib[aggregateType[xtypes.NAME]] = gen
  end
  
  return gen
end

--- Creates a generator from an xtypes typedef definition.
--  @tparam xtemplate typedef A xtypes typedef definition as per DDSL.
--  @tparam GeneratorLib genLib (optional) A library of generators for members and types.
--  @tparam bool memoizeGen (optional) true if the member-specific generators should
--  be cached in genLib. false otherwise.
--  @treturn Generator A generator of values of the typedef type.
function Public.typedefGen(typedef, genLib, memoizeGen)
    local typename = typedef[xtypes.NAME]
    genLib = genLib or { }
    genLib.typeGenLib = genLib.typeGenLib or { }
    
    if genLib.typeGenLib[typename] then
      return genLib.typeGenLib[typename]
    else
      local gen = Private.zcreateGeneratorImpl({ typedef() }, genLib, memoizeGen)
      if memoizeGen then
        genLib.typeGenLib[typename] = gen
      end
      return gen
    end
end

--- Creates a generator for enumerations
--  @tparam xtemplate enumtype An xtypes type definition of enumeration as per DDSL.
--  @tparam GeneratorLib genLib (optional) A library of generators for members and types.
--  If a generator exists in the library, it will be used.
--  @tparam bool memoizeGen (optional) true if the member-specific generators should
--  be cached in genLib. false otherwise.
--  @treturn Generator A generator of enumeration values.
function Public.enumGen(enumtype, genLib, memoizeGen)
  local typename = enumtype[xtypes.NAME]
  genLib = genLib or { }
  genLib.typeGenLib = genLib.typeGenLib or { }
  
  if genLib.typeGenLib[typename] then
      return genLib.typeGenLib[typename]
  else
    local ordinals = {}
    for idx = 1, #enumtype do
      local elem, value = next(enumtype[idx])
      ordinals[idx] = value
    end
    local gen = Public.oneOfGen(ordinals)
    if memoizeGen then
      genLib.typeGenLib[typename] = gen
    end
    return gen
  end
end

--- Creates a generator from role definition as per DDSL
--  @tparam xtemplate roledef Any role definition as per DDSL
--  @tparam GeneratorLib genLib (optional) A library of generators for members and types.
--  If a generator exists in the library, it will be used.
--  @tparam bool memoizeGen (optional) true if the member-specific generators should
--  be cached in genLib. false otherwise.
--  @treturn Generator A generator of values of type defined in roledef.
function Public.createGenerator(roledef, genLib, memoizeGen)
  local typename = roledef[xtypes.NAME]
  genLib = genLib or {}
  genLib.typeGenLib = genLib.typeGenLib or {}
  
  if genLib.typeGenLib[typename] then
    return genLib.typeGenLib[typename]
  else
    local gen = Private.zcreateGeneratorImpl(roledef, genLib, memoizeGen)
    if memoizeGen then
      genLib.typeGenLib[typename] = gen
    end
    return gen
  end
end

--- Returns a generator for the specified primitive type as 
--  specified in the `BuiltinGenerators` section.
--  @tparam string ptype The name of the primitive type in string format.
--  E.g., "boolean", "char", "long double", "long_double", "string", 
--  "string<128>", etc.
--  @tparam GeneratorLib genLib (optional) A library of generators for members and types.
--  If a generator exists in the library, it will be used.
--  @tparam bool memoizeGen (optional) true if the member-specific generators should
--  be cached in genLib. false otherwise.
--  @treturn Generator A generator of primitives.
function Public.getPrimitiveGen(ptype, genLib, memoizeGen)
  genLib = genLib or {}
  genLib.typeGenLib = genLib.typeGenLib or {}
  local gen = nil
  
  --print(ptype)
  
  if genLib.typeGenLib[ptype] then
    return genLib.typeGenLib[ptype]
  else
    if ptype=="bool" then
      gen = Public.Bool
    elseif ptype=="boolean" then
      gen = Public.Bool
    elseif ptype=="octet" then
      gen = Public.Octet
    elseif ptype=="char" then
      gen = Public.Char
    elseif ptype=="wchar" then
      gen = Public.WChar
    elseif ptype=="float" then
      gen = Public.Float
    elseif ptype=="double" then
      gen = Public.Double
    elseif ptype=="short" then
      gen = Public.Short
    elseif ptype=="long" then
      gen = Public.Long
    elseif ptype=="long_double" then
      gen = Public.LongDouble
    elseif ptype=="long double" then
      gen = Public.LongDouble
    elseif ptype=="long_long" then
      gen = Public.LongLong
    elseif ptype=="long long" then
      gen = Public.LongLong
    elseif ptype=="unsigned_short" then
      gen = Public.UShort
    elseif ptype=="unsigned short" then
      gen = Public.UShort
    elseif ptype=="unsigned_long" then
      gen = Public.ULong
    elseif ptype=="unsigned long" then
      gen = Public.ULong
    elseif ptype=="unsigned_long_long" then
      gen = Public.ULongLong
    elseif ptype=="unsigned long long" then
      gen = Public.ULongLong
    elseif ptype=="string" then
      gen = Public.String
    elseif ptype=="wstring" then
      gen = Public.WString
    end
    
    if gen == nil then
      local isString = string.find(ptype, "string") or
                       string.find(ptype, "wstring")

      if isString then
        local lt    = string.find(ptype, "<")
        local gt    = string.find(ptype, ">")
        local bound = string.sub(ptype, lt+1, gt-1)
        gen = Public.nonEmptyStringGen(tonumber(bound))
      end
    end
    
    if gen and memoizeGen then
      genLib.typeGenLib[ptype] = gen
    end
    
    return gen

  end
end

function Private.zcreateMemberGenTab(structtype, genLib, memoizeGen)

  local memberGenTab = { }
  genLib = genLib or { }
  genLib.typeGenLib = genLib.typeGenLib or { }

  --  if structtype[xtypes.KIND]() == "struct" and
  if structtype[xtypes.BASE] ~= nil then
    memberGenTab = 
      Private.zcreateMemberGenTab(
          structtype[xtypes.BASE], genLib, memoizeGen)
  end

  for idx = 1, #structtype do
    local member, def = next(structtype[idx])    
    if genLib[member] then -- if library already has a generator 
      memberGenTab[member] = genLib[member]
    else
      memberGenTab[member] = Private.zcreateGeneratorImpl(
                                def, genLib, memoizeGen)
      if memoizeGen then genLib[member] = memberGenTab[member] end
    end
    --print()
  end

  return memberGenTab;
end

function Private.zcreateGeneratorImpl(roledef, genLib, memoizeGen)
  local gen = nil
  local kind = nil

  if roledef[xtypes.KIND] then
    local kind = roledef[xtypes.KIND]()
    
    if kind == "const" then 
      local constVal, constType = roledef()
      gen = Public.constantGen(constVal)
    elseif kind == "atom" then  
      gen = Public.getPrimitiveGen(roledef[xtypes.NAME], genLib, memoizeGen)
    elseif kind == "enum" then  
      gen = Public.enumGen(roledef, genLib, memoizeGen)
    elseif kind == "struct" or kind == "union" then  
      gen = Public.aggregateGen(roledef, genLib, memoizeGen)
    elseif kind == "typedef" then 
      gen = Public.typedefGen(roledef, genLib, memoizeGen)
    else
      error "Error: Unsupported xtypes.KIND"
    end
  else
    local kind = roledef[1][xtypes.KIND]()
    
    if kind == "atom" then  
      gen = Public.getPrimitiveGen(roledef[1][xtypes.NAME], genLib, memoizeGen)
    elseif kind == "enum" then  
      gen = Public.enumGen(roledef[1], genLib, memoizeGen)
    elseif kind == "struct" or kind == "union" then  
      gen = Public.aggregateGen(roledef[1], genLib, memoizeGen)
    elseif kind == "typedef" then 
      gen = Public.typedefGen(roledef[1], genLib, memoizeGen)
    else
      error "Error: Unsupported xtypes.KIND"
    end
  end
    

  if roledef[xtypes.KIND] == nil then
    for i=2, #roledef do
      local info = tostring(roledef[i])
      if string.find(info, "sequence") then
        gen = Private.zsequenceParseGen(gen, info)
      elseif string.find(info, "optional") then
        gen = gen:amb(Public.singleGen(nil))
      elseif string.find(info, "array") then
        gen = Private.zarrayParseGen(gen, info)
      end
    end
  end
  
  return gen
end

function Private.zarrayParseGen(gen, info)
  local o = 7 -- open parenthesis "@Array(...)"
  local close = string.find(info, ")")
  
  if close == nil then -- unbounded array 
    error "Error: Unbounded Array!"
  else
    local bounds = string.sub(info, o+1, close-1)
    for bound in string.gmatch(bounds, "%d") do
      --print(bound)
      gen = Public.arrayGen(gen, tonumber(bound))
    end
  end

  return gen
end

function Private.zsequenceParseGen(gen, info)
  local o = 10 -- open parenthesis "@Sequence(...)"
  local close = string.find(info, ")")
  
  if close == nil then -- unbounded sequence
    gen = Public.seqGen(gen)
  else
    local bound = string.sub(info, o+1, close-1)
    --print(tonumber(bound))
    gen = Public.seqGen(gen, tonumber(bound))
  end

  return gen
end

function Private.zunionGen(unionType, genLib, memoizeGen)

  local memberGenTab = { }
  local caseMemberTab = { }
  genLib = genLib or { }
  genLib.typeGenLib = genLib.typeGenLib or { }

  local caseSeq = {}
  for i = 1, #unionType do -- walk through the model definition
    local case = unionType[i]
    local member, roledef = next(case, #case)        
    
    -- caseDiscriminator
    for _, caseDiscriminator in ipairs(case) do
      if (xtypes.EMPTY == caseDiscriminator) then
        caseSeq[#caseSeq+1] = xtypes.EMPTY
      else
        caseSeq[#caseSeq+1] = caseDiscriminator
      end
      caseMemberTab[caseDiscriminator] = member
    end
    
    -- member
    if genLib[member] then -- if library already has a generator 
      memberGenTab[member] = genLib[member]
    else
      memberGenTab[member] = Private.zcreateGeneratorImpl(roledef, genLib, memoizeGen)
      if memoizeGen then genLib[member] = memberGenTab[member] end
    end

  end
  
  if genLib._d then
    memberGenTab._d = genLib._d
  else
    memberGenTab._d = Public.oneOfGen(caseSeq)
    if memoizeGen then genLib._d = memberGenTab._d end
  end
  
  return Generator:new(function () 
          local data = {}
          data._d = memberGenTab._d:generate()
          if data._d == nil then return nil, false end
          
          local member = caseMemberTab[data._d]
          if memberGenTab[member] == nil then return nil, false end
          
          local value, valid = memberGenTab[member]:generate()
          if valid then
            data[member] = value
            return data, true
          else
            return nil, false
          end
         end)
end

function Private.swap(tab, i, j)
  local temp = tab[i]
  tab[i] = tab[j]
  tab[j] = temp
end

function Private.permute(src, b, N)
  if b > N then
    coroutine.yield(src)
  else
    for i = b, N do
      Private.swap(src, i, b)
      Private.permute(src, b+1, N)
      Private.swap(src, i, b)
    end
  end
end

function Queue:new ()
  o =  {first = 0, last = -1}
  setmetatable(o, self)
  self.__index = self
  return o
end

function Queue:pushLeft (value)
  local first = self.first - 1
  self.first = first
  self[first] = value
end

function Queue:pushRight (value)
  local last = self.last + 1
  self.last = last
  self[last] = value
end

function Queue:popLeft ()
  local first = self.first
  if first > self.last then error("Queue.popLeft: Queue is empty") end
  local value = self[first]
  self[first] = nil        -- to allow garbage collection
  self.first = first + 1
  return value
end

function Queue:popRight ()
  local last = self.last
  if self.first > last then error("Queue.popRight: Queue is empty") end
  local value = self[last]
  self[last] = nil         -- to allow garbage collection
  self.last = last - 1
  return value
end
    
function Queue:isEmpty ()
  return self.first > self.last
end


--- Builtin generators
-- @section BuiltinGenerators 

--- A random boolean generator with 50-50 probability.
Public.Bool       = Public.boolGen()

--- A generator of uniformly distributed integers in
--  range 0 to Public.MAX_BYTE (inclusive)
Public.Octet      = Public.octetGen()

--- A generator of printable characters in range 
-- 32 (i.e, space) and 126 (i.e., tilde) (inclusive).
Public.Char       = Public.printableGen()

--- A generator that produces integer values in the
--  range of 0 and Public.MAX_INT16 (inclusive).
Public.WChar      = Public.wcharGen()

--- A generator that produces floating point numbers in the 
--  range of negative Public.MAX_INT16 and Public.MAX_INT16 (inclusive).
Public.Float      = Public.floatGen()

--- A generator that produces floating point numbers in the 
--  range of negative Public.MAX_INT32 and Public.MAX_INT32 (inclusive).
Public.Double = Public.doubleGen()

--- A generator that produces floating point numbers in the 
--  range of negative Public.MAX_INT64 and Public.MAX_INT64 (inclusive).
Public.LongDouble = Public.longDoubleGen()

--- A generator that produces integers in the range of 
--  Public.MIN_INT16 and Public.MAX_INT16 (inclusive).
Public.Short      = Public.int16Gen()

--- A generator that produces integers in the range of 
--  Public.MIN_INT32 and Public.MAX_INT32 (inclusive).
Public.Long       = Public.int32Gen()

--- A generator that produces integers in the range of 
--  Public.MIN_INT64 and Public.MAX_INT64 (inclusive).
Public.LongLong   = Public.int64Gen()

--- A generator that produces unsigned integers in the range of 
--  0 and Public.MAX_UINT16 (inclusive).
Public.UShort     = Public.uint16Gen()

--- A generator that produces unsigned integers in the range of 
--  0 and Public.MAX_UINT32 (inclusive).
Public.ULong      = Public.uint32Gen()

--- A generator that produces unsigned integers in the range of 
--  0 and Public.MAX_UINT64 (inclusive).
Public.ULongLong  = Public.uint64Gen()

--- A generator of non-empty strings. Maximum length 256.
Public.String     = Public.nonEmptyStringGen()

--- A generator of non-empty strings. Maximum length 256.
Public.WString    = Public.nonEmptyStringGen()

Public.Generator  = Generator

return Public
