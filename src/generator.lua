xtypes = require ("xtypes")

local Generator   = {}

local MAX_BYTE    = 0xFF

local MAX_INT16   = 0x7FFF 
local MAX_INT32   = 0x7FFFFFFF 
local MAX_INT64   = 0x7FFFFFFFFFFFFFFF 

local MIN_INT16   = -MAX_INT16-1 
local MIN_INT32   = -MAX_INT32-1 
local MIN_INT64   = -MAX_INT64-1 

local MAX_UINT16  = 0xFFFF 
local MAX_UINT32  = 0xFFFFFFFF 
local MAX_UINT64  = 0xFFFFFFFFFFFFFFFF 

local MAX_FLOAT   = 3.4028234 * math.pow(10,38)
local MAX_DOUBLE  = 1.7976931348623157 * math.pow(10, 308)

local MIN_FLOAT   = -MAX_FLOAT
local MIN_DOUBLE  = -MAX_DOUBLE

function Generator:new(generatorFunc)
  o = { generate = generatorFunc }
  setmetatable(o, self)
  self.__index = self
  return o
end

function Generator:single(val)
  return Generator:new(function () return val end)
end

function Generator:map(func)
  return Generator:new(function () 
           return func(self:generate())
         end)
end

function Generator:flatMap(func)
  return self:map(function (x) 
           return func(x):generate()
         end)
end

function Generator:zip2(otherGen, zipperFunc)
  return Generator:new(function () 
           return zipperFunc(self:generate(),
                             otherGen:generate())
         end)
end

function Generator:oneOf(array)
  return Generator:rangeGen(1, #array)
                  :map(function (i)
                         return array[i]
                       end)
end

function Generator:numGen()
  return Generator:new(function () 
    return math.random(MAX_INT32);
  end)
end
  
function Generator:int16Gen()
  return Generator:new(function () 
    return math.random(MIN_INT16, MAX_INT16);
  end)
end
  
function Generator:int32Gen()
  return Generator:new(function () 
    return math.random(MIN_INT32, MAX_INT32);
  end)
end
  
function Generator:int64Gen()
  return Generator:new(function () 
    return math.random(MIN_INT64, MAX_INT64);
  end)
end
  
function Generator:uint16Gen()
  return Generator:new(function () 
    return math.random(0, MAX_UINT16);
  end)
end
  
function Generator:uint32Gen()
  return Generator:new(function () 
    return math.random(0, MAX_UINT32);
  end)
end
  
function Generator:uint64Gen()
  return Generator:new(function () 
    return math.random(0, MAX_UINT64);
  end)
end
  
function Generator:rangeGen(loInt, hiInt)
  return Generator:new(function() 
        return math.random(loInt, hiInt)
      end)
end

function Generator:boolGen()
  return Generator:new(function () 
    return math.random(2) > 1;
  end)
end

function Generator:charGen()
  return Generator:rangeGen(0, MAX_BYTE)
end

function Generator:wcharGen()
  return Generator:rangeGen(0, MAX_INT16)
end

function Generator:octetGen()
  return Generator:rangeGen(0, MAX_BYTE)
end

function Generator:shortGen()
  return Generator:int16Gen()
end

function Generator:posFloatGen()
  return Generator:new(function()
           return math.random() * math.random(0, MAX_INT16)
         end)
end

function Generator:posDoubleGen()
  return Generator:new(function()
           return math.random() * math.random(0, MAX_INT32)
         end)
end

function Generator:floatGen()
  return Generator:boolGen():map(function(b)
           local num = math.random() * math.random(0, MAX_INT16)
           return b and -num or num
         end)
end

function Generator:doubleGen()
  return Generator:boolGen():map(function(b)
           local num = math.random() * math.random(0, MAX_INT32)         
           return b and -num or num
         end)
end

function Generator:amb(otherGen) 
  return Generator:boolGen():flatMap(function (b) 
        return b and self or otherGen
      end)
end

function Generator:lowercaseGen()
  local a = 97
  local z = 122
  return Generator:rangeGen(a, z)
end

function Generator:uppercaseGen()
  local A = 65
  local Z = 90
  return Generator:rangeGen(A, Z)
end

function Generator:alphaGen()
  return Generator:lowercaseGen():amb(
            Generator:uppercaseGen())
end

function Generator:alphaNumGen()
  local zero = 48
  local nine = 57
  return Generator:alphaGen():amb(
            Generator:rangeGen(zero, nine))
end

function Generator:printableGen()
  local space = 32
  local tilde = 126
  return Generator:rangeGen(space, tilde)
end

function Generator:seqGen(elemGen, maxLength)
  elemGen = elemGen or Generator:single("unknown ")
  maxLength = maxLength or MAX_BYTE+1
 
  return 
    Generator:rangeGen(0, maxLength)
             :map(function (length) 
                    local arr = {}
                    for i=1,length do
                      arr[i] = elemGen:generate()
                    end
                    return arr
                  end)
end

function Generator:nonEmptyStringGen(maxLength, charGen)
  charGen = charGen or Generator:printableGen()
  maxLength = maxLength or MAX_BYTE+1

  return 
    Generator:rangeGen(1, maxLength)
             :map(function (length) 
                    local arr = {}
                    for i=1,length do
                      arr[i] = string.char(charGen:generate())
                    end
                    return table.concat(arr)
                  end)
end

function Generator:stringGen(maxLength, charGen)
  return Generator:boolGen():flatMap(
           function (empty)
              return empty 
              and Generator:single("") 
              or  Generator:nonEmptyStringGen(maxLength, charGen)
           end)
end

function Generator:aggregateGen(structtype, genLib)
  local memberGenTab = {}
  genLib = genLib or {}

  for key, val in ipairs(structtype) do
    local member, def = next(val)
    --io.write(member .. ": ")
    for k, kind in ipairs(def) do
      --io.write(tostring(v) .. " ")
      if(genLib[member]) then
        memberGenTab[member] = genLib[member]
      else
        memberGenTab[member] = Generator:getGenerator(kind)
        genLib[member] = memberGenTab[member]
      end
      break
    end
    --print()
  end

  return Generator:new(function () 
           local data = {}
           for member, gen in pairs(memberGenTab) do
             data[member] = gen:generate()
           end
           return data
         end)
end

function Generator:getGenerator(mtype)
  local gen = Generator:getPrimitiveGen(mtype)

  if gen then return gen end

  if mtype[xtypes.KIND]()=="enum" then  -- It's a function. Very surprising
    return Generator:enumGen(mtype)
  elseif mtype[xtypes.KIND]()=="struct" then  -- It's a function. Very surprising
    return Generator:aggregateGen(mtype)
  else
    return Generator:single(tostring(mtype))
  end
end

function Generator:enumGen(enumtype)
  local ordinals = {}
  for idx, enumdef in ipairs(enumtype) do
    local elem, value = next(enumdef)
    ordinals[idx] = value
  end
  return Generator:oneOf(ordinals)
end

function Generator:getPrimitiveGen(kind)
  local ptype = tostring(kind)

  if ptype=="boolean" then
    return Generator.Bool
  elseif ptype=="octet" then
    return Generator.Octet
  elseif ptype=="char" then
    return Generator.Char
  elseif ptype=="wchar" then
    return Generator.WChar
  elseif ptype=="float" then
    return Generator.Float
  elseif ptype=="double" then
    return Generator.Double
  elseif ptype=="long_double" then
    return Generator.LongDouble
  elseif ptype=="short" then
    return Generator.Short
  elseif ptype=="long" then
    return Generator.Long
  elseif ptype=="long_long" then
    return Generator.LongLong
  elseif ptype=="unsigned_short" then
    return Generator.UShort
  elseif ptype=="unsigned_long" then
    return Generator.ULong
  elseif ptype=="unsigned_long_long" then
    return Generator.ULongLong
  elseif ptype=="string" then
    return Generator.String
  elseif ptype=="wstring" then
    return Generator.WString
  elseif ptype=="string<128>" then
    return Generator:nonEmptyStringGen(128)
  else
    return nil
  end
end

Generator.Bool       = Generator:boolGen()
Generator.Octet      = Generator:octetGen()
Generator.Char       = Generator:charGen()
Generator.WChar      = Generator:wcharGen()
Generator.Float      = Generator:floatGen()
Generator.Double     = Generator:doubleGen()
Generator.LongDouble = Generator:doubleGen()
Generator.Short      = Generator:int16Gen()
Generator.Long       = Generator:int32Gen()
Generator.LongLong   = Generator:int64Gen()
Generator.UShort     = Generator:uint16Gen()
Generator.ULong      = Generator:uint32Gen()
Generator.ULongLong  = Generator:uint64Gen()
Generator.String     = Generator:nonEmptyStringGen()
Generator.WString    = Generator:nonEmptyStringGen()

return Generator 

