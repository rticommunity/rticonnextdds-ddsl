local PullGen = require("generator")

-- Every reative generator accepts a continuation as a 
-- argument to method named "listen". Every continuation 
-- is of type T->(). I.e., it accepts something and does 
-- not return anything. In short, ReactGen looks like below
-- class ReactGen<T> { void listen(T->()) }
  
local ReactGen = {
  new        = nil,
  listen     = nil,
  map        = nil,
  flatMap    = nil,

  propagate  = nil, -- private
  listenImpl = nil, -- private
  cont       = nil, -- private (data)
}

local Disposable = {
  dispose    = nil
}

local Private = {}

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

function ReactGen.kind()
  return "reactive"
end

function ReactGen:listen(continuation) 
  return self:listenImpl(continuation)
end

function ReactGen:propagate(value)
  if self.cont then self.cont(value) end
end

function ReactGen:map(func)
  local prev = self
  return ReactGen:new(
      { listenImpl = function (unused, continuation)
                       return prev:listen(function (value) 
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
        listenImpl = function (observable, continuation)
                       local outerDisposable = 
                          prev:map(func)
                              :listen(function (nested) 
                                 observable.innerDisposable:add( 
                                   nested:listen(function (op)
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

function ReactGen:zip2simple(otherGen, zipperFunc)
  local prev = self
  return ReactGen:new(
        { queue = { first=nil, second=nil }, 
          listenImpl = function(observable, continuation) 

            local disp1 = prev:listen(function (i) 
              if observable.queue.second then
                local zip = zipperFunc(i, observable.queue.second)
                if continuation then continuation(zip) end
                observable.queue = { first=nil, second=nil }
              else
                observable.queue.first = i
              end
            end)

            local disp2 = otherGen:listen(function (j) 
              if observable.queue.first then
                local zip = zipperFunc(observable.queue.first, j)
                if continuation then continuation(zip) end
                observable.queue = { first=nil, second=nil }
              else
                observable.queue.second = j
              end
            end)

            local disposable = CompositeDisposable:new()
            disposable:add(disp1)
            disposable:add(disp2)

            return disposable
          end
        })
end

function Private.tryCall(expectedCacheLen, zipperFunc, cache, continuation)
  local ready = true
   
  for i=1, expectedCacheLen do
    if cache[i] == nil then
      ready = false
      return
    end
  end

  if ready then
    local result = zipperFunc(unpack(cache))
    if continuation then continuation(result) end

    for i=1, #cache do
      cache[i] = nil
    end
  end
end

function Private.zipConcatenate(idx, genList, zipperObj, continuation)
  return genList[idx]:listen(function (value) 
    zipperObj.cache[idx] = value
    Private.tryCall(#genList,
                    zipperObj.zipperFunc, 
                    zipperObj.cache,
                    continuation)
  end)
end

function Private.zipImpl(...)
  local argLen = select("#", ...)
  local zipperFunction = select(argLen, ...)
  local genList = {  }

  for i=1, argLen-1 do
    genList[i] = select(i, ...)
  end

  local zipper = ReactGen:new(
        { cache      = { }, 
          zipperFunc = zipperFunction, 
          listenImpl = function(zipperObj, continuation) 
            local disposable = CompositeDisposable:new()

            for i=1, #genList do 
              disposable:add(
                Private.zipConcatenate(i, genList, zipperObj,
                                       continuation))
            end
            return disposable
          end
        })

  return zipper
end

function ReactGen:zip2(otherGen, zipperFunc)
  return Private.zipImpl(self, otherGen, zipperFunc)
end

function ReactGen:zipMany(...)
  return Private.zipImpl(self, select(1, ...))
end

function ReactGen:where(predicate)
  local prev = self
  return ReactGen:new(
      { listenImpl = function (unused, continuation)
                       return prev:listen(function (value) 
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

function Subject:push(value)
  value = value or self.source:generate()
  self:propagate(value) 
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

function Private.createMemberGenTab(
    structtype, genLib, memoizeGen)

  local pullGenTab         = { }
  local pushGenTab         = { }
  local pushGenMemberNames = { }
  genLib = genLib or { }
  genLib.typeGenLib = genLib.typeGenLib or { }

--  if structtype[xtypes.KIND]() == "struct" and
--  if   structtype[xtypes.BASE] ~= nil then
--    memberGenTab = 
--      Private.createMemberGenTab(
--          structtype[xtypes.BASE], genLib, memoizeGen)
--  end

  local pushIdx = 1
  for idx, val in ipairs(structtype) do
    local member, def = next(val)
    --io.write(member .. ": ")
    if genLib[member] then -- if library already has a generator 
      if(genLib[member].kind() == "pull") then
        --print("pull member = ", member)
        pullGenTab[member] = genLib[member]
      else
        --print("push member = ", member)
        pushGenTab[pushIdx] = genLib[member]
        pushGenMemberNames[pushIdx] = member
        pushIdx = pushIdx + 1
      end
    else
      pullGenTab[member] = PullGen.getGenerator(
                                   def, genLib, memoizeGen)
      if memoizeGen then genLib[member] = memberGenTab[member] end
    end
    --print()
  end

  return pullGenTab, pushGenTab, pushGenMemberNames;
end

function ReactGenPackage.aggregateGen(structtype, genLib, memoize)

  local pullGenTab, pushGenTab, pushGenMemberNames = 
    Private.createMemberGenTab(structtype, genLib, memoize)

  pushGenTab[#pushGenTab+1] = 
         function (...)
            local data = { }
            local argLen = select("#", ...)
            
            for i=1, argLen do
                local name = pushGenMemberNames[i]
                data[name] = select(i, ...)
            end
            
            for member, gen in pairs(pullGenTab) do
              data[member] = gen:generate()
            end

            return data
          end

  return Private.zipImpl(unpack(pushGenTab))
end

function ReactGenPackage.createSubjectFromPullGen(pullgen)
  if pullgen==nil then
    error "Invalid argument: nil generator." 
  end

  return Subject:new(
            { source   = pullgen,
              contList = { },
              listenImpl = function (sub, continuation)
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

