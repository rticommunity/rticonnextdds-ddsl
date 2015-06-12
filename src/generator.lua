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
           return math.random() * MAX_FLOAT
         end)
end

function Generator:posDoubleGen()
  return Generator:new(function()
           return math.random() * MAX_DOUBLE
         end)
end

function Generator:floatGen()
  return Generator:boolGen()(function(b)
           return b and math.random() * MAX_FLOAT
                    or  math.random() * MIN_FLOAT
         end)
end

function Generator:doubleGen()
  return Generator:boolGen()(function(b)
           return b and math.random() * MAX_DOUBLE
                    or  math.random() * MIN_DOUBLE
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

function Generator:nonEmptyStringGen(maxLength, charGen)
  charGen = charGen or Generator:printableGen()
  maxLength = maxLength or MAX_BYTE

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
    io.write(member .. ": ")
    for k, v in ipairs(def) do
      io.write(tostring(v) .. " ")
      if(genLib[member]) then
        memberGenTab[member] = genLib[member]
      else
        memberGenTab[member] = Generator:getGenForKind(tostring(v))
        genLib[member] = memberGenTab[member]
      end
      break
    end
    print()
  end

  return Generator:new(function () 
           local data = {}
           for member, gen in pairs(memberGenTab) do
             data[member] = gen:generate()
           end
           return data
         end)
end

function Generator:getGenForKind(mtype)
  if mtype=="boolean" then
    return Generator:boolGen()
  elseif mtype=="octet" then
    return Generator:octetGen()
  elseif mtype=="char" then
    return Generator:charGen()
  elseif mtype=="wchar" then
    return Generator:wcharGen()
  elseif mtype=="float" then
    return Generator:floatGen()
  elseif mtype=="double" then
    return Generator:doubleGen()
  elseif mtype=="long_double" then
    return Generator:doubleGen()
  elseif mtype=="short" then
    return Generator:int16Gen()
  elseif mtype=="long" then
    return Generator:int32Gen()
  elseif mtype=="long_long" then
    return Generator:int64Gen()
  elseif mtype=="unsigned_short" then
    return Generator:uint16Gen()
  elseif mtype=="unsigned_long" then
    return Generator:uint32Gen()
  elseif mtype=="unsigned_long_long" then
    return Generator:uint64Gen()
  elseif mtype=="string" then
    return Generator:nonEmptyStringGen()
  elseif mtype=="wstring" then
    return Generator:nonEmptyStringGen()
  elseif mtype=="string<128>" then
    return Generator:nonEmptyStringGen(128)
  else
    return Generator:single(mtype)
  end
end

return Generator 

