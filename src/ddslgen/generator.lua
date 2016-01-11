--[[
  (c) 2005-2014 Copyright, Real-Time Innovations, All rights reserved.     
                                                                           
  Permission to modify and use for internal purposes granted.               
  This software is provided "as is", without warranty, express or implied.
--]]
--[[
-----------------------------------
Purpose: Pull-based data generators
Created: Sumant Tambe, 2015 Jun 12
-----------------------------------
--]]

-------------------------------------------------------------
--! @file
--! @brief Pull-based Generators
--! 
--! The \a public functions in this module create generators
--! of various kinds. The \link Generator \endlink is the
--! prototype ("class") for all generator objects. Every 
--! generator has a method named \link generate \endlink 
--! (among others) that produces a new value. As generators
--! may be stateful, it is important to invoke 
--! methods on all generators using the ":" syntax.
--! 
--! Consider the following example that generates a random day 
--! of the week everytime generate is called.
--!
--! \code {.lua}
--! local Gen = require("generator")
--! Gen.initialize()
--! 
--! local dayOfWeek = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
--! local dayGen = Gen.oneOf(dayOfWeek)
--!
--! for i=1, 5 do 
--!   print("dayGen produced ", dayGen:generate())
--! end
--! \endcode
--! 
--! Generators are designed for composibility from group up.
--! Complex generators can be easily created from basic, simpler
--! generators. As such, generators form an algebra with well-defined
--! operations such as map, flatMap, zipMany, amb (ambiguous), etc.
--! These operations are also known as \a combinators because 
--! use of these combinators always yields another generator.
--!
--! The example below shows how the above dayGen can be created 
--! using a more basic generator, such as a range generator.
--! I.e., xGen is a generator that produces values from 1 to 7. 
--! dayGen is a generator that maps the values produces
--! by xGen to the days of the week.
--!
--! \code {.lua}
--! local dayOfWeek = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
--! local xGen = Gen.rangeGen(1,7)
--! local dayGen = xGen:map(function(i) 
--!                          return dayOfWeek[i]
--!                         end)
--! for i=1, 5 do 
--!   print("xGen produced ", xGen:generate())
--!   print("dayGen produced ", dayGen:generate())
--! end
--! \endcode
--! 
--! It turns out that the values produced by xGen don't correspond to
--! that of dayGen. That's an expected behavior. xGen has no relation 
--! to dayGen beyond basic reuse as seen above. Every time dayGen:generate()
--! is called, xGen:generate() is also called. As xGen has no memory, it
--! produces a new random number in the [1..7] range every time. Therefore, the
--! values of x and days don't correspond.  All the generators available
--! in this module are independent of each other. If you want to capture
--! value dependencies consider using \a reactive generators.
--! 
--! \link zipMany \endlink is another combinator supported by generators. The 
--! following example generates a random month in every year in the 20th century
--! \code {.lua}
--! local monthGen = Gen.oneOf({ "Jan", "Feb", "Mar",  "Apr", "May", "Jun", 
--!                              "Jul", "Aug", "Sept", "Oct", "Nov", "Dec" })
--! local yearGen = Gen.stepperGen(1900, 1999)
--! local seriesGen = yearGen:zipMany(monthGen, 
--!                                   function(year, month) 
--!                                     return year .. " " .. month
--!                                   end)
--! for i=1, 100 do 
--!   print(seriesGen:generate())
--! end
--! \endcode
--!
--! Public functions such as \link aggregateGen \endlink, 
--! \link enumGen \endlink depend on a type definition provided
--! by the Data Domain-Specific Modeling Language (DDSL).
-------------------------------------------------------------

--! The generator module depends on the "xtypes" module.
local xtypes = require ("ddsl.xtypes")

--! The base \a interface for all pull-based generators.
--! All methods of Generator are instance methods
-- Generator:new
-- Generator:generate
-- Generator:kind
-- Generator:map
-- Generator:flatMap
-- Generator:zipMany
-- Generator:amb
-- Generator:scan
-- Generator:take
-- Generator:concat
-- Generator:append
-- Generator:where
-- Generator:toTable
local Generator = { }

-- Generator package object exported outside
local Public;
Public = {

  -- Numeric limits
  MAX_BYTE    = 0xFF,

  MAX_INT16   = 0x7FFF, 
  MAX_INT32   = 0x7FFFFFFF, 
  MAX_INT64   = 0x7FFFFFFFFFFFFFFF, 

  MAX_UINT16  = 0xFFFF, 
  MAX_UINT32  = 0xFFFFFFFF, 
  MAX_UINT64  = 0x7FFFFFFFFFFFFFFF, 

  MAX_FLOAT   = 3.4028234 * math.pow(10,38),
  MAX_DOUBLE  = 1.7976931348623157 * math.pow(10, 308),

  -- An object represeting no value was produced
  -- by the underlying reactive generator.
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
  --oneOf
  --numGen

  --boolGen
  --charGen
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
  
  --initialize

} -- Public

Public.MIN_FLOAT   = -Public.MAX_FLOAT
Public.MIN_DOUBLE  = -Public.MAX_DOUBLE

Public.MIN_INT16   = -Public.MAX_INT16-1 
Public.MIN_INT32   = -Public.MAX_INT32-1 
Public.MIN_INT64   = -Public.MAX_INT64-1 

setmetatable(Public.NO_PUSHED_VALUE, {
    __tostring = function () return "NO_PUSHED_VALUE" end
})

-- Only private methods/data
local Private;
Private = { 
  -- createMemberGenTab
  -- createGeneratorImpl
  -- seqParseGen
}


-----------------------------------------------------
-------------------- Generator ---------------------
-----------------------------------------------------

--! @brief Overrides __tostring for all Generators
--! @return A string of the form "Generator: 0xaddress"

function Generator:__tostringx ()
  Generator.__tostring = nil    
  local s = string.gsub(tostring(self), "table", "Generator")
  Generator.__tostring = Generator.__tostringx
  return s
end

Generator.__tostring = Generator.__tostringx    

--! @brief Creates a new generator from an implementation of generate(). 
--! @param[in] generateFunc A function that implements generate(). 
--!        I.e., the function should accept no arguments and must return a value.
--! @return A new generator that uses the generateFunc to produce values.
--! @see   \link Public.newGenerator \endlink

function Generator:new(generateFunc)
  o = { genImpl = generateFunc }
  setmetatable(o, self)
  self.__index = self
  return o
end

--! @brief Generates a new value.
--! @return A new value 

function Generator:generate()
  return self.genImpl()
end

--! @brief Determines the generator "kind". Either "pull" or "push"
--! @return A string. Either "pull" or "push"

function Generator:kind()
  return "pull"
end

--! @brief Creates a new generator that applies the given function to each 
--!        value generated by the self generator. 
--! @param[in] func A function that transforms input value to an output value.
--!        I.e., the function should accept one argument and must return a value.
--! @return A new generator that generates the result of applying func.

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

--! @brief Creates a new generator that applies the given function to each 
--!        value generated by the self generator and invokes generate() on 
--!        the return value. Effectively, it flattens Generator<Generator<T>> 
--!        to Generator<T>
--! @param[in] func A function that transforms the input value to a generator.
--!        I.e., the function should accept one argument and must return a generator.
--!        If func is missing, self must be a Generator<Generator<T>>. 
--! @return A new generator that returns the values generated by the generator 
--!         produced by func.

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

--! @brief Creates a new generator that applies the given function to the values
--!        generated by the argument generators. This function accepts arbitrary
--!        number of geneators as arguments (including zero). The last argument 
--!        must be a function that accepts as many arguments as there are 
--!        generators (including self). 
--! @param[in] ... Zero or more generators separated by comma. Followed by a zipperFunc.
--! @param[in] zipperFunc A function that zips one or more values into one.
--!        I.e., the function should accept \a N arguments and must return a value.
--! @return A new generator that generates the result of applying the zipper function.

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

--! @brief Creates a new generator that returns values produced by the 
--!        argument generators (self, otherGen) non-derministically.
--! @param[in] otherGen A generator 
--! @return A new generator 

function Generator:amb(otherGen) 
  return Public.boolGen():flatMap(function (b) 
        return b and self or otherGen
      end)
end

--! @brief Same as Generator:concat
--! @param[in] otherGen A generator 
--! @return A new generator 

function Generator:append(otherGen) 
  return self:concat(otherGen)
end

--! @brief Creates a new generator that appends otherGen to this.
--! @param[in] otherGen A generator 
--! @return A new generator 

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

--! @brief Creates a new generator that returns values produced by the 
--!        argument generators (self, otherGen) non-derministically.
--! @param[in] otherGen A generator 
--! @return A new generator 

function Generator:take(count) 
  if count < 0 then
    error "Generator:take: Invalid argument. Negative count" 
  end

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

--! @brief Creates a new generator that reduces values according
--!        to the reducer function 
--! @param reduderFunc [in] A function that reduces the sequence
--!        produced by the generator. Takes two arguments and 
--!        returns reduced value.
--! @param init [in] initial state for the reducer function.
--! @return A new ReactGen.
function Generator:scan(reducerFunc, init)
  local prev = self
  local state = init
  return Generator:new(function ()
                         local val, valid = prev:generate()
                         if valid then 
                           state = reducerFunc(state, val)
                           return state, true
                         else
                           return nil, false
                         end
                       end)
end

--! @brief  Returns a table containing all the elements produced     
--!         by the generator. Note that this function may not
--!         return and may cause excessive memory consumption
--!         if the underlying generator is very large or infinite.
--! @return A table
--! @post   If the function returns, the generator is completely
--!         exhausted.
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

--! @brief  Returns a generator that produces values for which
--!         the predicate returns true. If the underlying generator 
--!         is infinite and no value ever satisfies the predicate,
--!         the function will block foreever.
--! @return A new generator
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

--! @brief  Returns a generator that produces values for which
--!         the predicate returns false. If the underlying generator 
--!         is infinite and no value ever satisfies the predicate,
--!         the function will block foreever.
--! @return A new generator
function Generator:filter(predicate)
  return self:where(function(i) return predicate(i) == false end)
end

---------------------------------------------------
------------------- Public ------------------------
---------------------------------------------------

--! @brief Creates a single value generator.
--! @param[in] val A value/object
--! @return A single value generator

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

--! @brief Creates a never-ending constant value generator.
--! @param[in] val A value/object
--! @return A constant value generator

function Public.constantGen(val)
  return Generator:new(function () return val, true end)
end

--! @brief Creates an empty generator.
--! @return An empty generator

function Public.emptyGen()
  return Generator:new(function () return nil, false end)
end

--! @brief Creates a generator that produces one of the
--!        items specified in the input array.
--! @param[in] array An array of values to choose from.
--! @return A generator.

function Public.oneOf(array)
  local len = #array
  return Generator:new(function ()
                         if len == 0 then
                           return nil, false
                         else
                           return array[math.random(1, len)], true
                         end
                       end)
end

--! @brief Creates a generator that produces positive integers.
--! @return A generator 

function Public.numGen()
  return Generator:new(function () 
    return math.random(Public.MAX_INT32), true
  end)
end
  
--! @brief Creates a generator that produces integers
--!        in the range of \link MIN_INT16 \endlink and 
--!        \link MAX_INT16 \endlink.
--! @return A generator of integers.

function Public.int16Gen()
  return Generator:new(function () 
    return math.random(Public.MIN_INT16, 
                       Public.MAX_INT16), true
  end)
end

--! @brief Creates a generator that produces integers
--!        in the range of \link MIN_INT32 \endlink and 
--!        \link MAX_INT32 \endlink.
--! @return A generator of integers.
  
function Public.int32Gen()
  return Generator:new(function () 
    return math.random(Public.MIN_INT32, 
                       Public.MAX_INT32), true
  end)
end
  
--! @brief Creates a generator that produces integers
--!        in the range of \link MIN_INT64/4 \endlink and 
--!        \link MAX_INT64/4 \endlink.
--! @return A generator of integers.

function Public.int64Gen()
  return Generator:new(function () 
    return math.random(Public.MIN_INT64/4, 
                       Public.MAX_INT64/4), true
  end)
end
  
--! @brief Creates a generator that produces positive integers
--!        no larger than \link MAX_UINT16 \endlink.
--! @return A generator of integers.

function Public.uint16Gen()
  return Generator:new(function () 
    return math.random(0, Public.MAX_UINT16), true
  end)
end

--! @brief Creates a generator that produces positive integers
--!        no larger than \link MAX_UINT32 \endlink.
--! @return A generator of integers.

function Public.uint32Gen()
  return Generator:new(function () 
    return math.random(0, Public.MAX_UINT32), true
  end)
end
  
--! @brief Creates a generator that produces positive integers
--!        no larger than \link MAX_UINT64 \endlink.
--! @return A generator of integers.

function Public.uint64Gen()
  return Generator:new(function () 
    return math.random(0, Public.MAX_UINT64), true
  end)
end
  
--! @brief Creates a generator that produces integer values 
--!        in the specified range (inclusive).
--! @param[in] loInt The lower integer
--! @param[in] hiInt The higher integer
--! @return A generator of integers.

function Public.rangeGen(loInt, hiInt)
  if hiInt < loInt then
    return Public.emptyGen();
  else
    return Generator:new(function() 
             return math.random(loInt, hiInt), true
           end)
  end
end

--! @brief Creates a generator that produces boolean
--!        values non-deterministically.
--! @return A generator of booleans.

function Public.boolGen()
  return Generator:new(function () 
    return math.random(2) > 1, true;
  end)
end

--! @brief Creates a generator that produces integer values 
--!        in the range of 0 and \link MAX_BYTE \endlink
--! @return A generator of integers

function Public.charGen()
  return Public.rangeGen(0, Public.MAX_BYTE)
end

--! @brief Creates a generator that produces integer values 
--!        in the range of 0 and \link MAX_INT16 \endlink
--! @return A generator of integers

function Public.wcharGen()
  return Public.rangeGen(0, Public.MAX_INT16)
end

--! @brief Creates a generator that produces integer values 
--!        in the range of 0 and \link MAX_BYTE \endlink
--! @return A generator of integers.

function Public.octetGen()
  return Public.rangeGen(0, Public.MAX_BYTE)
end

--! @brief Creates a generator that produces integers
--!        in the range of \link MIN_INT16 \endlink and 
--!        \link MAX_INT16 \endlink.
--! @return A generator of integers.

function Public.shortGen()
  return Public.int16Gen()
end

--! @brief Creates a generator that produces positive floating
--!         point numbers in the range of 0 and \link MAX_INT16 \endlink
--! @return A generator of floating point numbers.

function Public.posFloatGen()
  return Generator:new(function()
           return math.random() * math.random(0, Public.MAX_INT16), true
         end)
end

--! @brief Creates a generator that produces positive floating 
--!         point numbersin the range of 0 and \link MAX_INT32 \endlink
--! @return A generator of floating point numbers.

function Public.posDoubleGen()
  return Generator:new(function()
           return math.random() * math.random(0, Public.MAX_INT32), true
         end)
end

--! @brief Creates a generator that produces floating point numbers
--!        in the range of negative \link MAX_INT16 and \link MAX_INT16 \endlink
--! @return A generator of floating point numbers.

function Public.floatGen()
  return Public.boolGen():map(function(b)
           local num = math.random() * math.random(0, Public.MAX_INT16)
           if b then
             return num, true
           else
             return -num, true
           end
         end)
end

--! @brief Creates a generator that produces floating point numbers
--!        in the range of negative \link MAX_INT32 and \link MAX_INT32 \endlink
--! @return A generator of floating point numbers.

function Public.doubleGen()
  return Public.boolGen():map(function(b)
           local num = math.random() * math.random(0, Public.MAX_INT32)         
           if b then
             return num, true
           else
             return -num, true
           end
         end)
end

--! @brief Creates a generator that produces lowercase alphabets
--! @return A generator of integers

function Public.lowercaseGen()
  local a = 97
  local z = 122
  return Public.rangeGen(a, z)
end

--! @brief Creates a generator that produces uppercase alphabets
--! @return A generator of integers

function Public.uppercaseGen()
  local A = 65
  local Z = 90
  return Public.rangeGen(A, Z)
end

--! @brief Creates a generator that produces lowercase and uppercase alphabets
--! @return A generator of integers

function Public.alphaGen()
  return Public.lowercaseGen():amb(
            Public.uppercaseGen())
end

--! @brief Creates a generator that produces alphabets and digits
--! @return A generator of integers

function Public.alphaNumGen()
  local zero = 48
  local nine = 57
  return Public.alphaGen():amb(
            Public.rangeGen(zero, nine))
end

--! @brief Creates a generator that produces printable characters
--! @return A generator of integers

function Public.printableGen()
  local space = 32
  local tilde = 126
  return Public.rangeGen(space, tilde)
end

--! @brief Creates a generator that produces a sequence  
--!        no larger than maxLength containing elements
--!        generated by the input generator. Possibly empty.
--! @param[in] elemGen An element generator
--! @param[in] maxLength Maximum size of the sequence.
--! @return A generator of sequences. 

function Public.seqGen(elemGen, maxLength)
  elemGen = elemGen or Public.singleGen("unknown ")
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

--! @brief Creates a generator that produces an array  
--!        of exactly length elements generated by the
--!        input generator. 
--! @param[in] elemGen An element generator
--! @param[in] length The size of the array.
--! @return A generator of arrays. 

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

--! @brief Creates a generator that produces non-empty strings
--! @param[in] maxLength (optional) The maximum length of the string. 256 by default
--! @param[in] charGen (optional) A generator for characters.
--!        By default \link printableGen() \endlink generator.
--! @return A generator of non-empty strings. 

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

--! @brief Creates a generator that produces (possibly empty) strings
--! @param[in] maxLength (optional) The maximum length of the string. 256 by default
--! @param[in] charGen (optional) A generator for characters.
--!            By default \link printableGen() \endlink generator.
--! @param[in] emptyPeriod (optional) Indicates the desirable frequency of 
--!            empty strings. 1 out of every emptyPeriod strings shall be
--!            empty (distributed unformly). Default 10
--! @return A generator of possibly empty strings.
 
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

--! @brief Creates a generator from a Lua coroutine. 
--! @param[in] coro A coroutine. Any arguments after coro are passed 
--!            to the coroutine at the first resume.
--! @return A generator that uses the input coroutine as the true
--!         source of data.
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

--! @brief Creates a generator that concatinates all the input generators
--! @param[in] A comma-separated list of generators
--! @return A generator that concatenates all the input generators.
function Public.concatAllGen(...)
  local args = { ... }
  
  return Public.stepperGen(1, #args)
               :flatMap(function (i)
                          return args[i]
                        end)
end

--! @brief Creates a generator that alternates sequentially between all the input generators
--! @param[in] A comma-separated list of generators
--! @return A generator that alternates sequentially between the input generators.
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

--! @brief Creates a generator that is equivalent to the generator returned 
--!        by the thunk function. The objective of deferredGen is to delay
--!        the invocation of the thunk until absolutely needed. In a way,
--!        it supports lazy evaluation.
--! @param[in] thunk A zero-argument function that returns a generator. This is 
--!            generally expected to be a small function with a single statement 
--!            that returns a generator. 
--! @return A new generator 
function Public.deferredGen(thunk)
  return Public.singleGen(0xDEADBEEF):flatMap(thunk)
end

--! @brief Creates a generator that produces structured type instances.
--! @param[in] aggregateType The \link xtypes \endlink type definition 
--!        as per DDSL.
--! @param[in,out] genLib (optional) A library of generators for members and types.
--!        I.e., if aggregateType contains a member named "x", genLib.x generator
--!        is used if it exists. 
--! @param[in] memoizeGen (optional) true if the member-specific generators should
--!            be cached in genLib. false otherwise.
--! @return A generator of values of structured types.

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

--! @brief Creates a generator from a typedef definition.
--! @param[in] typedef The \link xtypes \endlink typedef definition 
--!        as per DDSL.
--! @param[in,out] genLib (optional) A library of generators for members and types.
--! @param[in] memoizeGen (optional) true if the member-specific generators should
--!            be cached in genLib. false otherwise.
--! @return A generator of values of the typedef type.

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

--! @brief Creates a generator for enumerations
--! @param[in] enumtype The \link xtypes \endlink type definition of enumeration
--!        as per DDSL.
--! @param[in,out] genLib (optional) A library of generators for members and types.
--!            If a generator exists in the library, it will be used.
--! @param[in] memoizeGen (optional) true if the member-specific generators should
--!            be cached in genLib. false otherwise.
--! @return A generator of enumeration values.

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
    local gen = Public.oneOf(ordinals)
    if memoizeGen then
      genLib.typeGenLib[typename] = gen
    end
    return gen
  end
end

--! @brief Creates a generator from role definition as per DDSL
--! @param[in] roledef The role definition as per DDSL
--! @param[in,out] genLib (optional) A library of generators for members and types.
--!            If a generator exists in the library, it will be used.
--! @param[in] memoizeGen (optional) true if the member-specific generators should
--!        be cached in genLib. false otherwise.
--! @return A generator of values of type defined in roledef.

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

--! @brief Returns a generator for the specified primitive type.
--! @param[in] ptype The name of the primitive type in string format.
--!        E.g., "boolean", "char", "long_double", "string", "string<128>", etc.
--! @param[in,out] genLib (optional) A library of generators for members and types.
--!            If a generator exists in the library, it will be used.
--! @param[in] memoizeGen (optional) true if the member-specific generators should
--!        be cached in genLib. false otherwise.
--! @return A generator of primitives.

function Public.getPrimitiveGen(ptype, genLib, memoizeGen)
  genLib = genLib or {}
  genLib.typeGenLib = genLib.typeGenLib or {}
  local gen = nil
  
  --print(ptype)
  
  if genLib.typeGenLib[ptype] then
    return genLib.typeGenLib[ptype]
  else
    if ptype=="boolean" then
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

--! @brief Creates a new generator from an implementation of generate(). 
--! @param[in] generateFunc A function that implements generate(). 
--!        I.e., the function should accept no arguments and must return a value.
--! @return A new generator that uses the generateFunc to produce values.
--! @see   \link Generator.new \endlink

function Public.newGenerator(generateFunc)
  return Generator:new(generateFunc)
end

--! @brief Creates a new generator of fibonacci numbers
--! @return A new generator of fibonacci numbers

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

--! @brief Creates a stepper generator, which generates numbers in a sequence. 
--!        It behaves much like a for loop.
--! @param[in] start (optinoal) The beginning value. Default=1
--! @param[in] max   (optional) The maximum value. Default=math.huge
--! @param[in] step  (optional) The step size. default=1
--! @param[in] cycle (optional) Whether to repeat the numbers cyclically. Default=false
--! @return A new generator that generates numbers in steps.

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

--! @brief Creates a generator that produces values from the input array in order.
--! @param[in] array The array containing values. Must be non-empty
--! @param[in] cycle (optional) Whether to repeat the values cyclically. Default=false
--! @return A new generator that produces values from the input array.

function Public.inOrderGen(array, cycle)
  if #array == 0 then error "Error: Empty sequence" end
  cycle = cycle or false

  return Public.stepperGen(1, #array, 1, cycle)
               :map(function (i)
                      return array[i]
                    end)
end

--! @brief Initialize the generator library. 
--! @param[in] seed (optional) The seed for the random number generator
--! @return Nothing

function Public.initialize(seed)
  seed = seed or os.time()
  math.randomseed(seed)
end

--! @brief Convert a reactive generator to a pull-based generator
--! @param[in] reactGen The input reactive generator
--! @param[in] subjectGroup A group of subjects that when pushed produce
--!        a single value through the reactive generator.
--! @return A pair of pull-based generator and a disposable.

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
    memberGenTab._d = Public.oneOf(caseSeq)
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

Public.Bool       = Public.boolGen()
Public.Octet      = Public.octetGen()
Public.Char       = Public.charGen()
Public.WChar      = Public.wcharGen()
Public.Float      = Public.floatGen()
Public.Double     = Public.doubleGen()
Public.LongDouble = Public.doubleGen()
Public.Short      = Public.int16Gen()
Public.Long       = Public.int32Gen()
Public.LongLong   = Public.int64Gen()
Public.UShort     = Public.uint16Gen()
Public.ULong      = Public.uint32Gen()
Public.ULongLong  = Public.uint64Gen()
Public.String     = Public.nonEmptyStringGen()
Public.WString    = Public.nonEmptyStringGen()

Public.Generator  = Generator

return Public
