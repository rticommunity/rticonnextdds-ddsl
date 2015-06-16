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
  attachImpl = nil, -- private
  cont       = nil, -- private (data)
}

local Disposable = {
  dispose    = nil
}

function Disposable:new(o)
  o =  o or { } 
  setmetatable(o, self)
  self.__index = self
  return o
end

function Disposable:dispose()
  -- no-op
end

local SerialDisposable = 
  Disposable:new({ disposable = nil, isDisposed = false })

function SerialDisposable:add(newDisposable)
  if isDisposed==true then
    if newDisposable then newDisposable:dispose() end
  else
    if self.disposable then
      self.disposable:dispose()
    end
    self.disposable = newDisposable
  end
end

function SerialDisposable:dispose()
  self:add(nil)
  self.isDisposed = true
end

local CompositeDisposable = 
  Disposable:new({ list = {}, isDisposed = false })

function CompositeDisposable:add(disposable)
  if isDisposed==true then
    if disposable then disposable:dispose() end
  elseif disposable then 
    self.list[#self.list+1] = disposable
  end 
end

function CompositeDisposable:dispose()
  for i, d in ipairs(self.list) do
    d:dispose()
  end
  self.list = {}
  self.isDisposed = true
end

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
  local prev = self
  return ReactGen:new(
      { attachImpl = function (unused, continuation)
                       return prev:attach(function (value) 
                                continuation(func(value))
                              end)
                     end 
      })
end

function ReactGen:flatMap(func)
  local prev = self
  local innerDisposable = CompositeDisposable:new()

  return ReactGen:new(
      { innerDisposable = innerDisposable,
        attachImpl = function (observable, continuation)
                       local outerDisposable = 
                          prev:map(func)
                              :attach(function (nested) 
                                 observable.innerDisposable:add( 
                                   nested:attach(function (op)
                                     continuation(op)
                                   end))
                               end)

                       return { dispose = function () 
                                            innerDisposable:dispose()
                                            outerDisposable:dispose()
                                          end 
                              }
                     end 
      })
end

function ReactGen:zip2(otherGen, zipperFunc)
  
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
                                                  subject.cont = nil
                                                end 
                                    }
                           end 
            })
end

return ReactGenPackage

