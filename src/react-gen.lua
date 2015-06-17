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
  for i=1, #self.list do
    if self.list[i] then self.list[i]:dispose() end
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
                                if continuation then continuation(func(value)) end
                              end)
                     end 
      })
end

function ReactGen:flatMap(func, innerDisposable)
  local prev = self
  innerDisposable = innerDisposable or CompositeDisposable:new()

  return ReactGen:new(
      { innerDisposable = innerDisposable,
        attachImpl = function (observable, continuation)
                       local outerDisposable = 
                          prev:map(func)
                              :attach(function (nested) 
                                 observable.innerDisposable:add( 
                                   nested:attach(function (op)
                                     if continuation then continuation(op) end
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
  local prev = self
  return ReactGen:new(
        { queue = { first=nil, second=nil }, 
          attachImpl = function(observable, continuation) 
            local disp1 = prev:attach(function (i) 
              if observable.queue.second then
                local zip = zipperFunc(i, observable.queue.second)
                if continuation then continuation(zip) end
                observable.queue = { first=nil, second=nil }
              else
                observable.queue.first = i
              end
            end)

            local disp2 = otherGen:attach(function (j) 
              if observable.queue.first then
                local zip = zipperFunc(observable.queue.first, j)
                if continuation then continuation(zip) end
                observable.queue = { first=nil, second=nil }
              else
                observable.queue.second = j
              end
            end)

            local disposable = CompositeDisposable:new()
            disposable.add(disp1)
            disposable.add(disp2)

            return disposable
          end
        })
end

function ReactGen:where(predicate)
  local prev = self
  return ReactGen:new(
      { attachImpl = function (unused, continuation)
                       return prev:attach(function (value) 
                                if predicate(value) then
                                  if continuation then continuation(value) end
                                end
                              end)
                     end 
      })
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

function Subject:propagate(value)
  for i=1, #self.contList do
    if self.contList[i] then self.contList[i](value) end
  end
end

function findFirstEmpty(list)
  -- local idx = #list + 1
  for i=1, #list do
    if list[i] == nil then 
      return i 
    end  
  end
  return #list + 1
end 

function ReactGenPackage.createSubjectFromPullGen(pullgen)
  if pullgen==nil then
    error "Invalid argument: nil generator." 
  end

  return Subject:new(
            { source   = pullgen,
              contList = { },
              attachImpl = function (sub, continuation)
                             local idx = findFirstEmpty(sub.contList)
                             sub.contList[idx] = continuation
                             return { dispose = function () 
                                                  sub.contList[idx] = nil
                                                end 
                                    }
                           end 
            })
end

return ReactGenPackage

