-- local PullGen = require("generator")

-- Every reative generator accepts a continuation as a 
-- argument to method named "attach". Every continuation 
-- is of type T->(). I.e., it accepts something and does 
-- not return anything. In short, ReactGen looks like below
-- class ReactGen<T> { void attach(T->()) }
  
local ReactGen = {
  new        = nil,
  attach     = nil,
  map        = nil,
  flatMap    = nil,

  propagate  = nil, -- private
  cont       = nil, -- private
  attachImpl = nil -- private
}

function ReactGen:new(o)
  o =  o or { } 
  setmetatable(o, self)
  self.__index = self
  return o
end

function ReactGen:attach(continuation) 
  return self:attachImpl(continuation)
end

function ReactGen:propagate(value)
  if self.cont then self.cont(value) end
end

function ReactGen:map(func)
  local nextGen = ReactGen:new()
  
  local disposable = 
      self:attach(
          function (input)
            nextGen:propagate(func(input))
          end)

  return nextGen
end

function ReactGen:flatMap(func)
  local nextGen = ReactGen:new()
  
  self:attach(
      function (input)
        local output = func(input)
        output:attach(function (op) 
                          nextGen:propagate(op)
                        end)
      end)

  return nextGen
end

function ReactGen:zip2(zipperFunc)
  
end

-- Subject inherts from ReactGen and has the following
-- source = The true source of data
-- push   = The method that triggers generation and
--          pushes the value down the continuration
local Subject = ReactGen:new()

local ReactGenPackage = {}

function Subject:push()
  self:propagate(self.source:generate()) 
end

function ReactGenPackage.createSubjectFromPullGen(pullgen)
  if pullgen==nil then
    error "Invalid argument: nil generator." 
  end

  return Subject:new(
            { source = pullgen,
              attachImpl = function (subject, continuation)
                             subject.cont = continuation
                             return { dispose = function () 
                                                 subject.cont   = nil
                                               end 
                                    }
                           end 
            })
end

return ReactGenPackage

