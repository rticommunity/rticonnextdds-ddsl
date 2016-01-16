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

globalGen     = require("ddslgen.generator")
globalPushGen = require("ddslgen.react-gen")
local xtypes  = require("ddsl.xtypes")

local Public = {}
local Private = {}

function Public.parse(expression, genLib)
  local expr = "x*x"
  local vars = { "x" }
  local gens = { "xGen" }
  local chunk = ""
  
  for i=1,#vars do
    chunk = chunk .. "local " .. vars[i] .. " = select(" .. i .. ", ...);"
  end

  chunk = chunk .. "return " .. expr
  local func, err = Private.loadstring(chunk)
   
  if err ~= nil then
    print(err)
    return nil
  end
  
  for i=1, #gens do
    return genLib[gens[i]]:map(func)
  end
end

function Private.getDependency(str) 
  local var
  for sub in string.gmatch(str, "$(%a+)") do 
    var = sub
    break 
  end 
  return var
end

function Public.parseConstraint(role, expression, genLib, genCat)
  local tokens, i = {}, 1
  local gen, genFunc, err

  for str in string.gmatch(expression, "%S+") do
    tokens[i] = str
    i = i + 1
  end

  local expr = tokens[2]
  local var  = tokens[4]

  if genCat[role] == "pull" then
    genFunc, err  = Private.loadstring(" return globalGen." .. tokens[6])
  else
    local parentvar = Private.getDependency(tokens[6])  
    if parentvar then
      genFunc, err = function () return genLib[parentvar] end, nil
    else
      genFunc, err  = Private.loadstring(" local gen = globalGen." .. 
                                         tokens[6] .. 
                                         " return globalPushGen.toSubject(gen)")

    end
  end

  if err then 
    print(err) 
    return nil
  else
    gen = genFunc()
  end
  
  local chunk = "local " .. var .. " = select(1, ...); return " .. expr
  local func, err = Private.loadstring(chunk)
   
  if err then
    print(err)
    return nil
  end
  
  return gen:map(func), gen
end

function Public.createGenLibFromConstraints(structtype)
  local lib, kind, root = {}, "pull", nil
  local genCat, rootMember = Private.toposort(structtype)

  for i=1, #structtype do
    local role, roledef = next(structtype[i])
    for j=1, #roledef do
      if roledef[j][xtypes.KIND]() == "annotation" then 
        local gen, genroot = Public.parseConstraint(role, table.concat(roledef[j]), lib, genCat)
        lib[role] = gen
        if gen:kind() == "push" and role == rootMember then
          root = genroot
          kind = "push"
        end
      end
    end
  end

  return lib, kind, root
end

function Private.toposort(structtype)
  local topology = {}
  local rootMember

  for i=1, #structtype do
    local role, roledef = next(structtype[i])
    for j=1, #roledef do
      if roledef[j][xtypes.KIND]() == "annotation" then 
        local expression = table.concat(roledef[j])
        local tokens, i = { }, 1

        for str in string.gmatch(expression, "%S+") do
          tokens[i] = str
          i = i + 1
        end

        local var  = tokens[4]
        local parentvar = Private.getDependency(tokens[6])  
        if parentvar then
          topology[role] = "push"
          topology[parentvar] = "push"
          rootMember = parentvar
        else
          topology[role] = "pull"
        end
      end
    end
  end

  return topology, rootMember
end

if tonumber(string.gmatch(_VERSION,"%d.%d")()) >= 5.3 then
    Private.loadstring = function(str) return load(str) end
  else
    Private.loadstring = function(str) return loadstring(str) end
end

return Public
