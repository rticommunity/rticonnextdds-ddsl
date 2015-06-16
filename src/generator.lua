xtypes = require ("xtypes")

-- The Generator<T> monad
-- It's the prototype ("class") for all generator objects
-- Every generator has a method named "generate" that 
-- produces a new T. I.e., every Generator looks like below
-- class Generator<T> { T generate() }
local TGenerator = {

  -- All methods of TGenerator are instance methods
  new      = nil,  
  map      = nil,
  flatMap  = nil,
  zip2     = nil,
  amb      = nil,
  generate = nil,   
}

-- Generator package object
local GenPackage   = {

  -- Numeric limits
  MAX_BYTE    = 0xFF,

  MAX_INT16   = 0x7FFF, 
  MAX_INT32   = 0x7FFFFFFF, 
  MAX_INT64   = 0x7FFFFFFFFFFFFFFF, 

  MAX_UINT16  = 0xFFFF, 
  MAX_UINT32  = 0xFFFFFFFF, 
  MAX_UINT64  = 0xFFFFFFFFFFFFFFFF, 

  MAX_FLOAT   = 3.4028234 * math.pow(10,38),
  MAX_DOUBLE  = 1.7976931348623157 * math.pow(10, 308),

  -- Built-in generator objects
  Bool         = nil,
  Octet        = nil, 
  Char         = nil, 
  WChar        = nil, 
  Float        = nil, 
  Double       = nil, 
  LongDouble   = nil, 
  Short        = nil,
  Long         = nil,
  LongLong     = nil,
  UShort       = nil,
  ULong        = nil,
  ULongLong    = nil,
  String       = nil,
  WString      = nil,

  -- Generator factories
  -- Most methods produce new generators. 
  -- All methods below are non-instance methods.
  singleGen         = nil, 
  oneOf             = nil,
  numGen            = nil,

  boolGen           = nil,
  charGen           = nil,
  wcharGen          = nil,
  octetGen          = nil,
  shortGen          = nil,
  int16Gen          = nil,
  int32Gen          = nil,
  int64Gen          = nil,
  uint16Gen         = nil,
  uint32Gen         = nil,
  uint64Gen         = nil,

  posFloatGen       = nil,
  posDoubleGen      = nil,
  floatGen          = nil,
  doubleGen         = nil,

  getPrimitiveGen   = nil,

  lowercaseGen      = nil,
  uppercaseGen      = nil,
  alphaGen          = nil,
  alphaNumGen       = nil,
  printableGen      = nil,
  stringGen         = nil,
  nonEmptyStringGen = nil,

  rangeGen          = nil,
  seqGen            = nil,
  aggregateGen      = nil,
  enumGen           = nil,

  newGen            = nil,

  -- Initialize the random number generator.  
  initialize        = nil,

} -- GenPackage

GenPackage.MIN_FLOAT   = -GenPackage.MAX_FLOAT
GenPackage.MIN_DOUBLE  = -GenPackage.MAX_DOUBLE

GenPackage.MIN_INT16   = -GenPackage.MAX_INT16-1 
GenPackage.MIN_INT32   = -GenPackage.MAX_INT32-1 
GenPackage.MIN_INT64   = -GenPackage.MAX_INT64-1 

-- Only private methods/data
local Private = { 
  createMemberGenTab = nil,
  getGenerator       = nil,
  seqParseGen        = nil
}


-----------------------------------------------------
-------------------- TGenerator ---------------------
-----------------------------------------------------

function TGenerator:new(generatorFunc)
  o = { generate = generatorFunc }
  setmetatable(o, self)
  self.__index = self
  return o
end

function TGenerator:map(func)
  return TGenerator:new(function () 
           return func(self:generate())
         end)
end

function TGenerator:flatMap(func)
  return self:map(function (x) 
           return func(x):generate()
         end)
end

function TGenerator:zip2(otherGen, zipperFunc)
  return TGenerator:new(function () 
           return zipperFunc(self:generate(),
                             otherGen:generate())
         end)
end

function TGenerator:amb(otherGen) 
  return GenPackage.boolGen():flatMap(function (b) 
        return b and self or otherGen
      end)
end

---------------------------------------------------
------------------- GenPackage --------------------
---------------------------------------------------

function GenPackage.singleGen(val)
  return TGenerator:new(function () return val end)
end

function GenPackage.oneOf(array)
  return GenPackage.rangeGen(1, #array)
                  :map(function (i)
                         return array[i]
                       end)
end

function GenPackage.numGen()
  return TGenerator:new(function () 
    return math.random(GenPackage.MAX_INT32);
  end)
end
  
function GenPackage.int16Gen()
  return TGenerator:new(function () 
    return math.random(GenPackage.MIN_INT16, 
                       GenPackage.MAX_INT16);
  end)
end
  
function GenPackage.int32Gen()
  return TGenerator:new(function () 
    return math.random(GenPackage.MIN_INT32, 
                       GenPackage.MAX_INT32);
  end)
end
  
function GenPackage.int64Gen()
  return TGenerator:new(function () 
    return math.random(GenPackage.MIN_INT64, 
                       GenPackage.MAX_INT64);
  end)
end
  
function GenPackage.uint16Gen()
  return TGenerator:new(function () 
    return math.random(0, GenPackage.MAX_UINT16);
  end)
end
  
function GenPackage.uint32Gen()
  return TGenerator:new(function () 
    return math.random(0, GenPackage.MAX_UINT32);
  end)
end
  
function GenPackage.uint64Gen()
  return TGenerator:new(function () 
    return math.random(0, GenPackage.MAX_UINT64);
  end)
end
  
function GenPackage.rangeGen(loInt, hiInt)
  return TGenerator:new(function() 
        return math.random(loInt, hiInt)
      end)
end

function GenPackage.boolGen()
  return TGenerator:new(function () 
    return math.random(2) > 1;
  end)
end

function GenPackage.charGen()
  return GenPackage.rangeGen(0, GenPackage.MAX_BYTE)
end

function GenPackage.wcharGen()
  return GenPackage.rangeGen(0, GenPackage.MAX_INT16)
end

function GenPackage.octetGen()
  return GenPackage.rangeGen(0, GenPackage.MAX_BYTE)
end

function GenPackage.shortGen()
  return GenPackage.int16Gen()
end

function GenPackage.posFloatGen()
  return TGenerator:new(function()
           return math.random() * math.random(0, GenPackage.MAX_INT16)
         end)
end

function GenPackage.posDoubleGen()
  return TGenerator:new(function()
           return math.random() * math.random(0, GenPackage.MAX_INT32)
         end)
end

function GenPackage.floatGen()
  return GenPackage.boolGen():map(function(b)
           local num = math.random() * math.random(0, GenPackage.MAX_INT16)
           return b and -num or num
         end)
end

function GenPackage.doubleGen()
  return GenPackage.boolGen():map(function(b)
           local num = math.random() * math.random(0, GenPackage.MAX_INT32)         
           return b and -num or num
         end)
end

function GenPackage.lowercaseGen()
  local a = 97
  local z = 122
  return GenPackage.rangeGen(a, z)
end

function GenPackage.uppercaseGen()
  local A = 65
  local Z = 90
  return GenPackage.rangeGen(A, Z)
end

function GenPackage.alphaGen()
  return GenPackage.lowercaseGen():amb(
            GenPackage.uppercaseGen())
end

function GenPackage.alphaNumGen()
  local zero = 48
  local nine = 57
  return GenPackage.alphaGen():amb(
            GenPackage.rangeGen(zero, nine))
end

function GenPackage.printableGen()
  local space = 32
  local tilde = 126
  return GenPackage.rangeGen(space, tilde)
end

function GenPackage.seqGen(elemGen, maxLength)
  elemGen = elemGen or GenPackage.singleGen("unknown ")
  maxLength = maxLength or GenPackage.MAX_BYTE+1
 
  return 
    GenPackage.rangeGen(0, maxLength)
             :map(function (length) 
                    local arr = {}
                    for i=1,length do
                      arr[i] = elemGen:generate()
                    end
                    return arr
                  end)
end

function GenPackage.nonEmptyStringGen(maxLength, charGen)
  charGen = charGen or GenPackage.printableGen()
  maxLength = maxLength or GenPackage.MAX_BYTE+1

  return 
    GenPackage.rangeGen(1, maxLength)
             :map(function (length) 
                    local arr = {}
                    for i=1,length do
                      arr[i] = string.char(charGen:generate())
                    end
                    return table.concat(arr)
                  end)
end

function GenPackage.stringGen(maxLength, charGen)
  return GenPackage.boolGen():flatMap(
           function (empty)
              return empty 
              and GenPackage.singleGen("") 
              or  GenPackage.nonEmptyStringGen(maxLength, charGen)
           end)
end

function Private.createMemberGenTab(
    structtype, 
    genLib, 
    memoizeGen)

  local memberGenTab = { }
  genLib = genLib or { }
  genLib.typeGenLib = genLib.typeGenLib or { }

  if structtype[xtypes.BASE] ~= nil then
    memberGenTab = 
      Private.createMemberGenTab(
          structtype[xtypes.BASE], genLib, memoizeGen)
  end

  for idx, val in ipairs(structtype) do
    local member, def = next(val)
    --io.write(member .. ": ")
    if genLib[member] then -- if library already has a generator 
      memberGenTab[member] = genLib[member]
    else
      memberGenTab[member] = Private.getGenerator(
                                def, genLib, memoizeGen)
      if memoizeGen then genLib[member] = memberGenTab[member] end
    end
    --print()
  end

  return memberGenTab;
end

function Private.getGenerator(
    roledef, genLib, memoizeGen)
  local gen = nil
  local baseTypename = tostring(roledef[1])

  if genLib.typeGenLib[baseTypename] == nil then -- if genertor isn't there

    if roledef[1][xtypes.KIND]() == "atom" then  -- It's a function!
      gen = GenPackage.getPrimitiveGen(baseTypename)
    elseif roledef[1][xtypes.KIND]() == "enum" then  -- It's a function!
      gen = GenPackage.enumGen(roledef[1])
    elseif roledef[1][xtypes.KIND]() == "struct" then  -- It's a function!
      gen = GenPackage.aggregateGen(roledef[1], genLib, memoizeGen)
    end
    if memoizeGen then genLib.typeGenLib[baseTypename] = gen end

  else 
    gen = genLib.typeGenLib[baseTypename] -- cache the generator
  end

  for i=2, #roledef do
    --io.write(tostring(roledef[i]) .. " ")
    local info = tostring(roledef[i])
    if string.find(info, "Sequence") then
      gen = Private.sequenceParseGen(gen, info)
    elseif string.find(info, "Optional") then
      gen = gen:amb(GenPackage.singleGen(nil))
    end
  end

  return gen
end

function Private.sequenceParseGen(gen, info)
  local o = 10 -- open parenthesis "@Sequence(...)"
  local close = string.find(info, ")")
  
  if close == nil then -- unbounded sequence
    gen = GenPackage.seqGen(gen)
  else
    local bound = string.sub(info, o+1, close-1)
    --print(tonumber(bound))
    gen = GenPackage.seqGen(gen, tonumber(bound))
  end

  return gen
end

function GenPackage.aggregateGen(
    structtype, genLib, memoizeGen)

  local memberGenTab 
    = Private.createMemberGenTab(
          structtype, genLib, memoizeGen)

  return TGenerator:new(function () 
           local data = {}
           for member, gen in pairs(memberGenTab) do
             data[member] = gen:generate()
           end
           return data
         end)
end

function GenPackage.enumGen(enumtype)
  local ordinals = {}
  for idx, enumdef in ipairs(enumtype) do
    local elem, value = next(enumdef)
    ordinals[idx] = value
  end
  return GenPackage.oneOf(ordinals)
end

function GenPackage.getPrimitiveGen(ptype)

  if ptype=="boolean" then
    return GenPackage.Bool
  elseif ptype=="octet" then
    return GenPackage.Octet
  elseif ptype=="char" then
    return GenPackage.Char
  elseif ptype=="wchar" then
    return GenPackage.WChar
  elseif ptype=="float" then
    return GenPackage.Float
  elseif ptype=="double" then
    return GenPackage.Double
  elseif ptype=="long_double" then
    return GenPackage.LongDouble
  elseif ptype=="short" then
    return GenPackage.Short
  elseif ptype=="long" then
    return GenPackage.Long
  elseif ptype=="long_long" then
    return GenPackage.LongLong
  elseif ptype=="unsigned_short" then
    return GenPackage.UShort
  elseif ptype=="unsigned_long" then
    return GenPackage.ULong
  elseif ptype=="unsigned_long_long" then
    return GenPackage.ULongLong
  elseif ptype=="string" then
    return GenPackage.String
  elseif ptype=="wstring" then
    return GenPackage.WString
  end
  
  local isString = string.find(ptype, "string") or
                   string.find(ptype, "wstring")

  if isString then
    local lt    = string.find(ptype, "<")
    local gt    = string.find(ptype, ">")
    local bound = string.sub(ptype, lt+1, gt-1)
    return GenPackage.nonEmptyStringGen(tonumber(bound))
  else
    return nil
  end
end

function GenPackage.initialize(seed)
  seed = seed or os.time()
  math.randomseed(seed)
end

function GenPackage.newGen(func)
  return TGenerator:new(func)
end

GenPackage.Bool       = GenPackage.boolGen()
GenPackage.Octet      = GenPackage.octetGen()
GenPackage.Char       = GenPackage.charGen()
GenPackage.WChar      = GenPackage.wcharGen()
GenPackage.Float      = GenPackage.floatGen()
GenPackage.Double     = GenPackage.doubleGen()
GenPackage.LongDouble = GenPackage.doubleGen()
GenPackage.Short      = GenPackage.int16Gen()
GenPackage.Long       = GenPackage.int32Gen()
GenPackage.LongLong   = GenPackage.int64Gen()
GenPackage.UShort     = GenPackage.uint16Gen()
GenPackage.ULong      = GenPackage.uint32Gen()
GenPackage.ULongLong  = GenPackage.uint64Gen()
GenPackage.String     = GenPackage.nonEmptyStringGen()
GenPackage.WString    = GenPackage.nonEmptyStringGen()

return GenPackage

