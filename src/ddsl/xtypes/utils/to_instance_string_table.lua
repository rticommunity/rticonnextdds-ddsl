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

--- @module ddsl.xtypes.utils

local xtypes = require('ddsl.xtypes')
local log = xtypes.log

--============================================================================--

--- Visit all fields (depth-first) in the given instance and return their string
--  representation as a flattened array of strings.
--  
-- For instance collections, only the 1st element is visited. 
-- @xinstance instance the instance to visit
-- @tparam[opt=nil] {string,...} result the previous results table, to which 
--  the new results from this visit are appended
-- @xtemplate[opt=nil] template template to use to visit the instance; nil means
--  use the instance's template
-- @xtemplate[opt=nil] base the base 'struct' template (if any) to visit the
--  members of the the base 'struct' template
-- @treturn {string,...} the cumulative result of visiting all the fields. Each 
-- field that is visited is inserted into this table. This returned table can 
-- be passed to another call to this method, to build a cumulative table of 
-- instance strings.
-- @function to_instance_string_table
local function to_instance_string_table(instance, result, template, base)
  template = template or xtypes.template(instance)
  
  -- print('DEBUG to_instance_string_table 1: ', instance, template)

  -- initialize the result (or accumulate in the provided result)
  result = result or {}

  -- collection instance
  if xtypes.is_collection(instance) then
        -- ensure 1st element exists for illustration
      local _ = instance[1]

      -- length operator and actual length
      table.insert(result,
             table.concat{#template, ' = ', #instance})

      -- visit all the elements
      for i = 1, tonumber(#instance) or 1 do
        if 'table' == type(instance[i]) then -- composite collection
            -- visit i-th element
            to_instance_string_table(instance[i], result, template[i])
        else -- leaf collection
            table.insert(result,
                table.concat{template[i], ' = ', instance[i]})
        end
      end

      return result
  end

  -- struct or union
  local mytype = instance[xtypes.KIND]()

  -- print('DEBUG index 1: ', mytype(), instance[xtypes.NAME])

  -- skip if not an indexable type:
  if 'struct' ~= mytype and 'union' ~= mytype then return result end

  -- union discriminator, if any
  if 'union' == mytype then
    table.insert(result, table.concat{'_d', ' = ', instance._d})
  end

  -- struct base type, if any
  local mybase = (base or template)[xtypes.BASE]
  if mybase then
    result = to_instance_string_table(instance, result, template, 
                                   xtypes.resolve(mybase))
  end

  -- preserve the order of model definition
  -- walk through the body of the model definition
  -- NOTE: typedefs don't have an array of members
  for i = 1, #(base or template) do
    -- skip annotations
      -- walk through the elements in the order of definition:
      local member = (base or template)[i]
      local role
      if 'struct' == mytype then
        role = member[1]
      elseif 'union' == mytype then
        role = next(member, #member)
      end

      local role_instance = instance[role]
      -- print('DEBUG index 3: ', role, role_instance)

      if 'table' == type(role_instance) then -- composite or collection
        result = to_instance_string_table(role_instance, result, template[role])
      else -- leaf
        table.insert(result,
                  template[role] 
                     and table.concat{template[role],' = ', role_instance}
                     or nil) -- skip for union case with no definition
      end
  end

  return result
end

--============================================================================--
return to_instance_string_table