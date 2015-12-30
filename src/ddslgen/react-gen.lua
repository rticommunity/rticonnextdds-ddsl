--[[
  (c) 2005-2014 Copyright, Real-Time Innovations, All rights reserved.     
                                                                           
  Permission to modify and use for internal purposes granted.               
  This software is provided "as is", without warranty, express or implied.
--]]
--[[
-------------------------------------------------------------------------------
Purpose: Push-based (reactive) data generators
Created: Sumant Tambe, 2015 Jun 15
-------------------------------------------------------------------------------
--]]

-------------------------------------------------------------
--! @file
--! @brief Push-based (reactive) Generators
--! 
--! The \a public functions in this module create generators
--! that explicitly capture value dependencies. 
--! \link ReactGen \endlink is the prototype ("class") 
--! for all the reactive generators. Every 
--! generator has a method named \link listen \endlink 
--! (among others) that accepts a callback function as 
--! an argument. The callback is called when the reactive
--! generator produces a value. Therefore, the callback 
--! function must accept an argument
--!
--! Here is an example of a simple reactive generator that 
--! prints the values it has produced. 
--!
--! \code {.lua}
--! local ReactGen = require("react-gen")
--! local Gen      = require("generator")
--!
--! local subject = 
--!    ReactGen.toSubject(Gen.rangeGen(1, 7))
--!
--! local disposable = 
--!    subject:listen(function (x) 
--!                     print("x = ", x)
--!                   end)
--! for i=1,5 do
--!   subject:push() 
--! end
--!
--! disposable:dispose()
--! \endcode
--! 
--! The example above prints 5 random values of x between
--! the specifed range. The subject encapsulates the range
--! generator. When \link Subject:push() \endlink is 
--! called, the registered listener receives the random 
--! value produced by the range generator. As subject 
--! is itself a reactive generator, it supports 
--! method \a listen. 
--!
--! The next example shows how dependencies are handled 
--! by reactive generators.
--!
--! A number of \a transforms may also be applied before 
--! calling listen. For instance, the following example 
--! is an adaptation of the day-generator example where
--! the values produced by xGen and dayGen are in sync.
--!
--! \code {.lua}
--! local xGen = ReactGen.toSubject(Gen.rangeGen(1, 7))
--! local dayOfWeek = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
--! local dayGen = xGen:map(function(x) 
--!                           return dayOfWeek[x]
--!                         end)
--!
--! local disposable1 = 
--!    xGen:listen(function (x) 
--!                   print("x = ", x)
--!                end)
--!  
--! local disposable2 = 
--!    dayGen:listen(function (day) 
--!                     print("day = ", day)
--!                  end)
--! for i=1,5 do
--!   xGen:push() 
--! end
--!
--! disposable1:dispose()
--! disposable2:dispose()
--! \endcode
--!
--! A possible output is as follows. Note that x and
--! days are in sync.
--! 
--! \code 
--! x =     2
--! day =   Mon
--! x =     5
--! day =   Thu
--! x =     6
--! day =   Fri
--! x =     7
--! day =   Sat
--! x =     1
--! day =   Sun
--! \endcode
--! 
--! Reactive generators support a number of useful operators
--! to create complex generators. For instance, the following
--! example creates a 2dpoint {x, y} and a 3d point { x, y, z} 
--! where \a y=x*x and \a z=y-x.
--!
--! Note that definition of yGen is dependent on xGen, irrespetive
--! of how yGen is used later on. Likewise, zGen is dependent 
--! only on xGen and yGen irrespective of how it is used later on.
--!
--! \code {.lua}
--! local xGen = ReactGen.toSubject(Gen.rangeGen(1, 100))
--! local yGen = xGen:map(function (x) return x*x end)  
--! local zGen = yGen:zipMany(xGen, function (y, x) return y-x end)  
--!
--! local disposable2d = 
--!   xGen:zipMany(yGen, 
--!                function (x, y) 
--!                  return { x=x, y=y }
--!                end)
--!       :listen(function (point2d) 
--!                 print(" point2d.x = " .. point2d.x ..
--!                       " point2d.y = " .. point2d.y)
--!               end)
--!
--! local disposable3d =  
--!   xGen:zipMany(yGen, zGen, 
--!                function (x, y, z) 
--!                  return { x=x, y=y, z=z }
--!                end)
--!       :listen(function (point3d) 
--!                 print(" point3d.x = " .. point3d.x ..
--!                       " point3d.y = " .. point3d.y ..
--!                       " point3d.z = " .. point3d.z)
--!               end)
--!
--! xGen:push()
--! disposable2d:dispose()
--! print("point2d disposed")  
--!
--! xGen:push()
--! disposable3d:dispose()
--! \endcode
--!
--! A possible output of the above program is
--! \code
--!   point2d.x = 15 point2d.y = 225
--!   point3d.x = 15 point3d.y = 225 point3d.z = 210
--!   point2d disposed
--!   point3d.x = 90 point3d.y = 8100 point3d.z = 8010
--! \endcode
-----------------------------------------------------------

local PullGen = require("ddslgen.generator")

-- Every reative generator accepts a continuation as a 
-- argument to method named "listen". Every continuation 
-- is of type T->(). I.e., it accepts something and does 
-- not return anything. In short, ReactGen looks like below
-- class ReactGen<T> { void listen(T->()) }
  
--! The base \a interface for all push-based generators.
--! All methods of Generator are instance methods
-- ReactGen:new
-- ReactGen:kind
-- ReactGen:map
-- ReactGen:flatMap
-- ReactGen:zipMany
-- ReactGen:zipTwoDebug
-- ReactGen:where
-- ReactGen:listen
-- ReactGen:cont (private data)
local ReactGen = { }


--! The base interface for receiving notifications
--! from Reactive Generators.
-- Observer:onNext
-- Observer:onCompleted
local Observer = { }

--! The base \a interface for all Disposables
-- Disposable:new
-- Disposable:dispose
-- Disposable:isDisposed
local Disposable = { }

--! A collection of subjects
-- SubjectGroup:add
-- SubjectGroup:addMany
-- SubjectGroup:push
local SubjectGroup = { }

-- ReactGen package object exported outside
local Public = { }

local PrivatePackage  = {}

--------------------------------------------------------------
---------------- Implementation ------------------------------
--------------------------------------------------------------

--! @brief Creates a new disposable from an implementation 
--!        of dispose.
--! @param[in] impl A closure that implements the dispose
--!            function. Accepts no arguments, returns nothing.
--! @return A new disposable
function Disposable:new(o)
  o = o or { }
  if not o.deleted then
    o.deleted = false
  end
  if not o.name then
    o.name = "Disposable"
  end
  setmetatable(o, self)
  self.__index = self
  return o
end

--! @brief Overrides __tostring for Disposables
--! @return A string of the form "Disposable: 0xaddress"

function Disposable:__tostringx ()
  Disposable.__tostring = nil    
  local s = string.gsub(tostring(self), "table", self.name)
  Disposable.__tostring = Disposable.__tostringx
  return s
end
Disposable.__tostring = Disposable.__tostringx    

--! @brief Dispose off the underlying resources if they are 
--!        not already.
--! @return Nothing
function Disposable:dispose()
  if not self.deleted then
    self:disposeImpl()
    self.deleted = true
  end
end

--! @brief Reports whether the underlying resources are disposed.
--! @return boolean. true if disposed. false otherwise.
function Disposable:isDisposed()
  return self.deleted
end

--! A disposable that contains zero or one 
--! disposable. It disposes the old one (if any) when 
--! a new disposable is added. I.e., it represents a 
--! disposable whose underlying disposable can be 
--! swapped for another disposable which causes the 
--! previous underlying disposable to be disposed.
-- SerialDisposable:new
-- SerialDisposable:add
-- SerialDisposable:dispose
-- SerialDisposable:isDisposed
local SerialDisposable = Disposable:new()

--! @brief Creates a new SerialDisposable. 
--! @return A new SerialDisposable
function SerialDisposable:new()  
  o = Disposable:new{ disposable = nil, 
                      name = "SerialDisposable" } 
  setmetatable(o, self)
  self.__index = self
  return o
end

--! @brief Replaces the underlying disposable (if any) with the
--! input disposable. Disposes the underlying disposable.
--! @param[in] newDisposable An input disposable that will 
--! take place of the old disposable.
--! @return Nothing
function SerialDisposable:add(newDisposable)
  if self.deleted==true then
    if newDisposable then newDisposable:dispose() end
  else
    if self.disposable then
      self.disposable:dispose()
    end
    self.disposable = newDisposable
  end
end

--! @brief Dispose the underlying disposable (if any)
--! Dispose any future disposable added to self.
--! @return Nothing
function SerialDisposable:disposeImpl()
  self:add(nil)
end

--! A disposable that contains zero or more disposables. 
-- CompositeDisposable:new
-- CompositeDisposable:add
-- CompositeDisposable:dispose
-- CompositeDisposable:isDisposed
local CompositeDisposable = Disposable:new()

--! @brief Creates a new CompositeDisposable. 
--! @return A new CompositeDisposable
function CompositeDisposable:new()
  o = Disposable:new{ list = { }, 
                      count = 0,
                      maxIdx = 0,
                      name = "CompositeDisposable" }
  setmetatable(o, self)
  self.__index = self
  return o
end

--! @brief Adds a disposable to the existing collection of
--! disposable. 
--! @param[in] disposable An input disposable
--! @return Nothing
function CompositeDisposable:add(disposable)
  if self.deleted==true then
    if disposable then disposable:dispose() end
  elseif disposable then 
    local idx = PrivatePackage.findFirstEmpty(self.list, self.maxIdx)
    self.list[idx] = disposable
    if idx > self.maxIdx then self.maxIdx = idx end
    self.count = self.count + 1
    --print("self.count = ", self.count, "self.maxIdx = ", self.maxIdx)
  end 
end

--! @brief Remove a previously added disposable
--! @param[in] disposable A disposable to remove
--! @return true if removed successfuly, false otherwise. 
--!         Returns true for nil input
function CompositeDisposable:remove(disposable)
  if disposable then
    for i=1, self.maxIdx do
      if self.list[i] == disposable then
        self.list[i] = nil
        self.count = self.count - 1
        if i == self.maxIdx then
          local j = self.maxIdx - 1
          while self.list[j] == nil and j > 0 do
            j = j - 1
          end
          self.maxIdx = j
        end
        return true
      end
    end
    return false
  end
  return true
end

--! @brief Disposes all the underlyin disposables. Any future
--! disposables added to self will also be disposed. 
--! @return Nothing
function CompositeDisposable:disposeImpl()
  for i=1, self.maxIdx do
    if self.list[i] then 
      self.list[i]:dispose() 
    end
  end
  self.list = {}
  self.count = 0
  self.maxIdx = 0
end

--! @brief Creates a new Observer object from onNext and onCompleted 
--!        functions.
--! @return a new Observer object
function Observer:new(nextfunc, completedfunc)
  o = { }
  if nextfunc then o.onNext = nextfunc end
  if completedfunc then o.onCompleted = completedfunc end
  setmetatable(o, self)
  self.__index = self
  return o
end

--! @brief The default no-op onNext function
--! @return Nothing
function Observer:onNext(value) 
end

--! @brief The default no-op onCompleted function
--! @return Nothing
function Observer:onCompleted() 
end

--! @brief Overrides __tostring for Observer 
--! @return A string of the form "Observer: 0xaddress"
function Observer:__tostringx ()
  Observer.__tostring = nil    
  local s = string.gsub(tostring(self), "table", "Observer")
  Observer.__tostring = Observer.__tostringx
  return s
end

Observer.__tostring = Observer.__tostringx    

--! @brief Overrides __tostring for ReactGen 
--! @return A string of the form "ReactiveGenerator: 0xaddress"

function ReactGen:__tostringx ()
  ReactGen.__tostring = nil    
  local s = string.gsub(tostring(self), "table", "ReactiveGenerator")
  ReactGen.__tostring = ReactGen.__tostringx
  return s
end

ReactGen.__tostring = ReactGen.__tostringx    

--! @brief Creates a new reactive generator. This method
--! is reserved for internal use only.
function ReactGen:new(o)
  o =  o or { } 
  setmetatable(o, self)
  self.__index = self
  return o
end

--! @brief Returns the generator \a kind. 
--! @return "push"
function ReactGen:kind()
  return "push"
end

--! @brief Register a callback to receive the values produced
--! by the generator.
--! @param observer An object that implements the Observer interface
--!        or a function accepting one argument.
--! @return A disposable. Disposable must be disposed when
--!         notifications are no longer desired.
function ReactGen:listen(observer) 
  if observer then
    if type(observer) == "function" then
      return self:listenImpl(Observer:new(function (_, value)
               observer(value)
             end))
    else
      return self:listenImpl(observer)
    end
  else
    return self:listenImpl(Observer:new(function (_, value) end))
  end
end

--! @brief Creates a new generator that applies the given function to each 
--!        value generated by the self generator. 
--! @param[in] func A function that transforms input value to an output value.
--!        I.e., the function should accept one argument and must return a value.
--! @return A new generator that generates the result of applying func.
function ReactGen:map(func)
  local prev = self
  return ReactGen:new(
      { listenImpl = 
             function (unused, observer)
               return prev:listen(
                        Observer:new(function (_, value) 
                                       if observer then 
                                         observer:onNext(func(value)) 
                                       end
                                     end, 
                                     observer.onCompleted)) 
             end 
      })
end

--! @brief Creates a new generator that applies the given function to each 
--!        value generated by the self generator. 
--! @param[in] func A function that transforms input value to an output value.
--!        I.e., the function should accept one argument and must return a value.
--! @return A new generator that generates the result of applying func.
function ReactGen:take(max)
  local prev = self
  local count = 0
  return ReactGen:new(
      { listenImpl = 
             function (unused, observer)
               local disposable = CompositeDisposable:new()
               disposable:add(prev:listen(
                        Observer:new(function (_, value) 
                                       if count < max then 
                                         if observer then 
                                           observer:onNext(value) 
                                         end
                                         count = count + 1
                                       else
                                         observer:onCompleted()
                                         disposable:dispose()
                                       end
                                     end, 
                                     observer.onCompleted)
                                 ))
               return disposable
             end 
      })
end

--! @brief Creates a new generator that applies the given 
--! function to each value generated by the self generator. 
--! The argument function must return a \link ReactGen \endlink object.
--! Effectively, it flattens ReactGen<ReactGen<T>> to ReactGen<T>
--! @param[in] func A function that transforms the input value to a ReactGen generator.
--!        I.e., the function should accept one argument and must return a
--! ReactGen generator. Every generator returned by the i
--! function is automatically subscribed (listened) to and 
--! the values produced by them are forwarded to the callback.
--! @return A new generator that produces the values produced
--! by the generator returned by func.
function ReactGen:flatMap(func)
  return PrivatePackage.flatMapImpl(self, func)
end

--! @brief Creates a new reactive generator that applies the given function to the values
--!        generated by the argument generators. This function accepts two geneators as arguments. The last argument 
--!        must be a function that accepts two arguments.
--! @param[in] otherGen The other generator to zip with
--! @param[in] zipperFunc A function that zips two values into one.
--! @return A new generator that generates the result of applying the zipper function.
function ReactGen:zipTwoDebug(otherGen, zipperFunc)
  local prev = self
  return ReactGen:new(
        { queue = { first=nil, second=nil }, 
          listenImpl = function(observable, observer) 
            local disposable = CompositeDisposable:new()
            local disp1      = CompositeDisposable:new()
            local disp2      = CompositeDisposable:new()

            disp1:add(prev:listen(Observer:new(function (_, i) 
              if observable.queue.second then
                local zip = zipperFunc(i, observable.queue.second)
                if observer then observer:onNext(zip) end
                observable.queue = { first=nil, second=nil }
              else
                observable.queue.first = i
              end
            end, 
            function () 
              observer:onCompleted()
              disp2:dispose()
              observable.queue = { }
            end)))

            disp2:add(otherGen:listen(Observer:new(function (_, j) 
              if observable.queue.first then
                local zip = zipperFunc(observable.queue.first, j)
                if observer then observer:onNext(zip) end
                observable.queue = { first=nil, second=nil }
              else
                observable.queue.second = j
              end
            end,
            function ()
              observer:onCompleted()
              disp1:dispose()
              observable.queue = { }
            end)))

            disposable:add(disp1)
            disposable:add(disp2)

            return disposable
          end
        })
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
function ReactGen:zipMany(...)
  return PrivatePackage.zipImpl(self, select(1, ...))
end

--! @brief Creates a new generator that produces values that 
--! satisfy the predicate.
--! @param predicate[in] A function taking one argument and
--! return true/false 
--! @return A new ReactGen.
function ReactGen:where(predicate)
  local prev = self
  return ReactGen:new(
      { listenImpl = function (unused, observer)
                       return prev:listen(Observer:new(function (_, value) 
                                if predicate(value) and observer then
                                  observer:onNext(value)
                                end
                              end,
                              observer.onCompleted))
                     end 
      })
end

--! @brief Creates a new generator that reduces values according
--!        to the reducer function 
--! @param reduderFunc [in] A function that reduces the sequence
--!        produced by the generator. Takes two arguments and 
--!        returns reduced value.
--! @param init [in] initial state for the reducer function.
--! @return A new ReactGen.
function ReactGen:scan(reducerFunc, init)
  local prev = self
  local state = init
  return ReactGen:new(
      { listenImpl = function (unused, observer)
                       return prev:listen(Observer:new(function (_, value) 
                                state = reducerFunc(state, value)
                                if observer then
                                  observer:onNext(state)
                                end
                              end,
                              observer.onCompleted))
                     end 
      })
end

--! @brief Subject "implements" the ReactGen "interface" 
--! and also provides a way to push values to all the
--! registered callbacks. When multiple observers are
--! present, the observers are invoked in the same
--! order in which they were added (even when some
--! subscriptions are disposed.)
-- Every subject has the following
-- source = The true source of data
-- push   = The method that triggers generation and
--          pushes the value down the continuration
local Subject = ReactGen:new()

--! @brief Create a new subject from a pull generator.
--! @return a new Subject
function Subject:new(pullgen, appendOnly)
  if appendOnly == nil then
    appendOnly = true
  end
  o = ReactGen:new{ source       = pullgen, 
                    appendOnly   = appendOnly,
                    observerList = { },
                    maxIdx       = 0,
                    subCount     = 0,
                    completed    = false }
  setmetatable(o, self)
  self.__index = self
  return o
end

--! @brief Push a value to all the registered callbacks.
--! @param[in] value (optional) A value. When none is 
--! provided, the underlying pull-based generator is used.
--! @return Nothing
function Subject:push(value)
  if not self.completed then
    local valid = false

    if value == nil then
      value, valid = self.source:generate()
    else
      valid = true
    end

    for i=1, self.maxIdx do
      if self.observerList[i] then 
        if valid then
          self.observerList[i]:onNext(value) 
        else
          self.observerList[i]:onCompleted()
          self.observerList[i] = nil
        end
      end
    end

    if not valid then
      self.observerList = { }
      self.maxIdx = 0
      self.subCount = 0
      self.completed = true
    end
    return valid
  end
  return false
end

--! @brief Complete a Subject. A completed subject can no longer
--!        push new values and accept new observers. 
--! @return Nothing
function Subject:complete()
  if not self.completed then
    for i=1, self.maxIdx do
      if self.observerList[i] then 
          self.observerList[i]:onCompleted()
          self.observerList[i] = nil
      end
    end

    self.observerList = { }
    self.maxIdx = 0
    self.subCount = 0
    self.completed = true
  end
end

--! @brief Overrides __tostring for Subjects 
--! @return A string of the form "Subject: 0xaddress"

function Subject:__tostringx ()
  Subject.__tostring = nil    
  local s = string.gsub(tostring(self), "table", "Subject")
  Subject.__tostring = Subject.__tostringx
  return s
end
Subject.__tostring = Subject.__tostringx    

--! @brief Create a reactive generator for a composite type
--! using a library of input generators.
--! @param structtype[in] A DDSL definition of a struct type
--! @param genLib[in] (optional) A collection of generators. 
--! Generatorsmay be pull-based or reactive.
--! @param memoize[in] (optional) A flag to indicate whether
--! to cache the generators in the genLib.
--! @return A reactive generator for a composite type.
function Public.aggregateGen(structtype, genLib, memoize)

  local pullGenTab, pushGenTab, pushGenMemberNames = 
    PrivatePackage.createMemberGenTab(structtype, genLib, memoize)

  pushGenTab[#pushGenTab+1] = 
         function (...)
            local data = { }
            local argLen = select("#", ...)
            
            for i=1, argLen do
                local name = pushGenMemberNames[i]
                data[name] = select(i, ...)
            end
            
            for member, gen in pairs(pullGenTab) do
              local val, valid = gen:generate()
              if valid then 
                data[member] = val
              else
                local msg = string.format("ReactGen:aggregateGen: " .. 
                      "Pull-based generator for '%s' terminated", member)
                error(msg)
              end
            end

            return data
          end

  return PrivatePackage.zipImpl(table.unpack(pushGenTab))
end

--! @brief Converts a pull-based generator to a reactive
--! generator.
--! @param pullgen[in] A pull-based generator.
--! @param appendOnly[in] (Optional) If true, observers are 
--! appended to to the inner list. If false, the first
--! empty position is found in the list. Default true.
--! @return Returns a subject that encapsulates the
--! pull-based generator.
--! @see \link Subject:push \endlink
function Public.toSubject(pullgen, appendOnly)
  if pullgen==nil then
    error "Invalid argument: nil pull-based generator." 
  end
  
  local subject = Subject:new(pullgen, appendOnly)
  return subject, subject
end

function Subject:listenImpl(observer)
  if not self.completed then
    local sub = self
    local idx = 0
    if sub.appendOnly then
      sub.maxIdx = sub.maxIdx + 1
      idx = sub.maxIdx
    else
      idx = PrivatePackage.findFirstEmpty(sub.observerList, sub.maxIdx)
      if idx > sub.maxIdx then
        sub.maxIdx = idx
      end
    end
    sub.observerList[idx] = observer
    sub.subCount = sub.subCount + 1
    return Disposable:new(
        { disposeImpl = function () 
                          sub.observerList[idx] = nil
                          sub.subCount = sub.subCount - 1
                          --[[print("Disposed idx = ", idx, 
                                " subCount = ", sub.subCount,
                                " sub.maxIdx = ", sub.maxIdx)]]
                          if idx == sub.maxIdx then
                            --print("equal")
                            while sub.observerList[idx] == nil and idx > 0 do 
                              idx = idx - 1
                            end
                            sub.maxIdx = idx
                          end
                        end
        })
  end
end 

--! @brief Creates a new SubjectGroup.
--! @param listOfSubjects[in] (optional) A list of subjects.
--! @return A new SubjectGroup containing the input subjects.
function SubjectGroup:new(listOfSubjects)
  o = { } 
  o.list = listOfSubjects or {} 
  setmetatable(o, self)
  self.__index = self
  return o
end

--! @brief Add a subject to the group.
--! @param subject[in] The input subject.
--! @return self
function SubjectGroup:add(subject)
  self.list[#self.list+1] = subject
  return self
end

--! @brief Add multiple subjects to the subject group.
--! @param subjectList[in] (optional) A list of subjects.
--! @return self
function SubjectGroup:addMany(subjectList)
  for i=1, #subjectList do
    self.list[#self.list+1] = subjectList[i]
  end
  return self
end

--! @brief Invoke push on all the underlying subjects.
--! @return Nothing
function SubjectGroup:push()
  for i=1, #self.list do
    self.list[i]:push()
  end
end

----------------------------------------------------------------
--------------------- PrivatePackage --------------------------
----------------------------------------------------------------
function PrivatePackage.flatMapImpl(
    self, func, innerDisposable)
  local prev = self
  innerDisposable = innerDisposable or CompositeDisposable:new()

  return ReactGen:new(
      { innerDisp = innerDisposable,
        listenImpl = 
            function (observable, observer)
               local outerDisposable = 
                  prev:map(func)
                      :listen(Observer:new(function (_, nested) 
                         local disp = nil
                         disp =  nested:listen(Observer:new(function (_, op)
                                                 if observer then 
                                                   observer:onNext(op) 
                                                 end
                                               end,
                                               function () 
                                                 innerDisposable:remove(disp)
                                               end))
                         observable.innerDisp:add(disp) 
                       end,
                       function () 
                         observer:onCompleted()
                         innerDisposable:dispose()
                       end))

               return Disposable:new{
                          disposeImpl = function () 
                                          innerDisposable:dispose()
                                          outerDisposable:dispose()
                                        end 
                        }
             end 
      })
end

function PrivatePackage.tryCall(expectedCacheLen, zipperFunc, cache, observer)
  local ready = true
   
  for i=1, expectedCacheLen do
    if cache[i] == nil then
      ready = false
      return
    end
  end

  if ready then
    local result = zipperFunc(table.unpack(cache))
    if observer then observer:onNext(result) end

    for i=1, #cache do
      cache[i] = nil
    end
  end
end

function PrivatePackage.zipImpl(...)
  local argLen = select("#", ...)
  local zipperFunction = select(argLen, ...)
  local genList = {  }

  for i=1, argLen-1 do
    genList[i] = select(i, ...)
  end

  local zipper = ReactGen:new(
        { cache      = { }, 
          zipperFunc = zipperFunction, 
          listenImpl = function(zipperObj, observer) 
            local disposable = CompositeDisposable:new()

            for idx=1, #genList do 
              disposable:add(
                 genList[idx]:listen(Observer:new(
                          function (_, value) 
                            zipperObj.cache[idx] = value
                            PrivatePackage.tryCall(#genList,
                                                   zipperObj.zipperFunc, 
                                                   zipperObj.cache,
                                                   observer)
                          end,
                          function ()
                            observer:onCompleted()
                            disposable:dispose()
                          end)))
            end
            return disposable
          end
        })

  return zipper
end

function PrivatePackage.findFirstEmpty(list, maxIdx)
  for i=1, maxIdx do
    if list[i] == nil then 
      return i 
    end  
  end
  return maxIdx + 1
end 

function PrivatePackage.createMemberGenTab(
    structtype, genLib, memoizeGen)

  local pullGenTab         = { }
  local pushGenTab         = { }
  local pushGenMemberNames = { }
  genLib = genLib or { }
  genLib.typeGenLib = genLib.typeGenLib or { }

--  if structtype[xtypes.KIND]() == "struct" and
--  if   structtype[xtypes.BASE] ~= nil then
--    memberGenTab = 
--      PrivatePackage.createMemberGenTab(
--          structtype[xtypes.BASE], genLib, memoizeGen)
--  end

  local pushIdx = 1
  for idx = 1, #structtype do
    local member, def = next(structtype[idx])
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
      pullGenTab[member] = PullGen.CreateGenerator(def, genLib, memoizeGen)
      if memoizeGen then genLib[member] = memberGenTab[member] end
    end
    --print()
  end
 
  return pullGenTab, pushGenTab, pushGenMemberNames;
end
  
Public.SubjectGroup = SubjectGroup
  
return Public

