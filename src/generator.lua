local Generator = {}
local MAXINT = 0x7FFFFFFF 

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

function Generator:numGen()
  return Generator:new(function () 
    return math.random(MAXINT);
  end)
end
  
function Generator:rangeGen(loInt, onePastHiInt)
  return Generator:numGen():map(function (x) 
        return loInt + x % (onePastHiInt - loInt)
      end)
end

function Generator:boolGen()
  return Generator:new(function () 
    return math.random(2) > 1;
  end)
end

function Generator:charGen()
  return Generator:rangeGen(0, 256)
end

function Generator:amb(otherGen) 
  return Generator:boolGen():flatMap(function (b) 
        return b and self or otherGen
      end)
end

function Generator:lowercaseGen()
  local a = 97
  local z = 122
  return Generator:rangeGen(a, z+1)
end

function Generator:uppercaseGen()
  local A = 65
  local Z = 90
  return Generator:rangeGen(A, Z+1)
end

function Generator:alphaGen()
  return Generator:lowercaseGen():amb(
            Generator:uppercaseGen())
end

function Generator:alphaNumGen()
  local zero = 48
  local nine = 57
  return Generator:alphaGen():amb(
            Generator:rangeGen(zero, nine+1))
end

function Generator:printableGen()
  local space = 32
  local tilde = 126
  return Generator:rangeGen(space, tilde+1)
end

function Generator:stringGen(maxLength, charGen)
  charGen = charGen or Generator:printableGen()
  maxLength = maxLength or 256
  local lenGen = Generator:numGen()
                          :map(function (x) 
                                 return x % maxLength
                               end)
  return Generator:boolGen():zip2(
            lenGen,
            function (empty, length) 
              if empty then
                return ""
              else
                local arr = {}
                for i=1,length do
                  arr[i] = string.char(charGen:generate())
                end
                return table.concat(arr)
              end
            end)
end

return Generator 

