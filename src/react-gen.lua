-- local PullGen = require("generator")

-- Every reative generator accepts a continuation as a 
-- argument to method named "register". Every continuation 
-- is of type T->(). I.e., it accepts something and does 
-- not return anything. In short, ReactGen looks like below
-- class ReactGen<T> { void register(T->()) }
  
local ReactGen = {
  new      = nil,
  cont     = nil,
  register = nil,
  map      = nil,
  flatMap  = nil,
}

function ReactGen:new()
  o = { } 
  setmetatable(o, self)
  self.__index = self
  return o
end

function ReactGen:register(continuation) 
  if continuation==nil then
    error "Invalid argument: nil continuation." 
  end
  self.cont = continuation
end

function ReactGen:map(func)
  local nextGen = ReactGen:new()
  
  self:register(
      function (input)
        local output = func(input)
        if nextGen.cont then nextGen.cont(output) end
      end)

  return nextGen
end

function ReactGen:flatMap(func)
  local nextGen = ReactGen:new()
  
  self:register(
      function (input)
        local output = func(input)
        output:register(function (op) 
          if nextGen.cont then nextGen.cont(op) end
        end)
      end)

  return nextGen
end

-- Subject inherts from ReactGen and has the following
-- source = The true source of data
-- push   = The method that triggers generation and
--          pushes the value down the continuration
local Subject = ReactGen:new()

local ReactGenPackage = {}

function Subject:push()
  if self.cont then self.cont(self.source:generate()) end
end

function ReactGenPackage.createSubjectFromPullGen(pullgen)
  if pullgen==nil then
    error "Invalid argument: nil generator." 
  end
  local subject = Subject:new()
  subject.source = pullgen
  return subject
end

return ReactGenPackage

