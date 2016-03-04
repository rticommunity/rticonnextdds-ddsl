--[[
Copyright (C) 2015 Real-Time Innovations, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]

-- A queue implementation
local Queue = {}

function Queue:new ()
  o =  {first = 0, last = -1}
  setmetatable(o, self)
  self.__index = self
  return o
end

function Queue:pushLeft (value)
  local first = self.first - 1
  self.first = first
  self[first] = value
end

function Queue:pushRight (value)
  local last = self.last + 1
  self.last = last
  self[last] = value
end

function Queue:popLeft ()
  local first = self.first
  if first > self.last then error("Queue.popLeft: Queue is empty") end
  local value = self[first]
  self[first] = nil        -- to allow garbage collection
  self.first = first + 1
  return value
end

function Queue:popRight ()
  local last = self.last
  if self.first > last then error("Queue.popRight: Queue is empty") end
  local value = self[last]
  self[last] = nil         -- to allow garbage collection
  self.last = last - 1
  return value
end
    
function Queue:isEmpty ()
  return self.first > self.last
end

return Queue
