--[[
  (c) 2005-2014 Copyright, Real-Time Innovations, All rights reserved.

 Permission to modify and use for internal purposes granted.
 This software is provided "as is", without warranty, express or implied.
--]]
--[[
-----------------------------------------------------------------------------
 Purpose: DDSL X-Types Utilities
 Created: Rajive Joshi, 2014 Feb 14
-----------------------------------------------------------------------------
@module dds.xtypes.utils

SUMMARY

    X-Types Utilities

-----------------------------------------------------------------------------
--]]

local xtypes = require('ddsl.xtypes')

--------------------------------------------------------------------------------
-- X-Types Utilities
--------------------------------------------------------------------------------
local xutils = {}

--- @function xutils.visit_instance() - Visit all fields (depth-first) in
--       the given instance and return their values as a linear (flattened)
--       list. For instance collections, the 1st element is visited.
-- @param instance [in] the instance to visit
-- @param result [in] OPTIONAL the index table to which the results are appended
-- @param template [in] OPTIONAL nil means use the instance's template;
-- @param base [in] OPTIONAL the base template (if any) to visit those members
-- @return the cumulative result of visiting all the fields. Each field that is
--         visited is inserted into this table. This returned value table can be
--         passed to another call to this method (to build it cumulatively).
function xutils.visit_instance(instance, result, template, base)
  template = template or xtypes.template(instance)
  
  -- print('DEBUG xutils.visit_instance 1: ', instance, template)

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
            xutils.visit_instance(instance[i], result, template[i])
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
    table.insert(result, table.concat{template._d, ' = ', instance._d})
  end

  -- struct base type, if any
  local mybase = (base or template)[xtypes.BASE]
  if mybase then
    result = xutils.visit_instance(instance, result, template, 
                                   xtypes.resolve(mybase))
  end

  -- preserve the order of model definition
  -- walk through the body of the model definition
  -- NOTE: typedefs don't have an array of members
  for i, member in ipairs(base or template) do
    -- skip annotations
      -- walk through the elements in the order of definition:

      local role
      if 'struct' == mytype then
        role = next(member)
      elseif 'union' == mytype then
        role = next(member, #member > 0 and #member or nil)
      end

      local role_instance = instance[role]
      -- print('DEBUG index 3: ', role, role_instance)

      if 'table' == type(role_instance) then -- composite or collection
        result = xutils.visit_instance(role_instance, result, template[role])
      else -- leaf
        table.insert(result,
                  template[role] 
                     and table.concat{template[role],' = ', role_instance}
                     or nil) -- skip for union case with no definition
      end
  end

  return result
end

--- xutils.visit_model() - Visit all elements (depth-first) of
--       the given model definition and return their values as a linear
--       (flattened) list.
--
--        The default implementation returns the stringified
--        OMG IDL X-Types representation of each model definition element
--
-- @param instance [in] a DDSL instance
-- @param result [in] OPTIONAL the previous results table to which the new 
--               results from this visit are appended
-- @param indent_string [in] the indentation for the string representation
-- @return the cumulative result of visiting all the definition. Each definition
--        that is visited is inserted into this table. This returned table
--        can be passed to another call to this method (to build cumulatively).
function xutils.visit_model(instance, result, indent_string)
	-- pre-condition: ensure valid data-object
	assert(xtypes.template(instance), 'visit_model() requires a DDSL instance!')

	-- initialize the result (or accumulate in the provided result)
  result = result or {}

	local indent_string = indent_string or ''
	local content_indent_string = indent_string
	local myname = instance[xtypes.NAME]
	local mytype = instance[xtypes.KIND]()
  local mymodule = instance[xtypes.NS]

	-- print('DEBUG visit_model: ', Data, model, mytype(), myname)

	-- skip: atomic types, annotations
	if 'atom' == mytype or
	   'annotation' == mytype then
	   return result
	end

  if 'const' == mytype then
    local value, atom = instance()
    if xtypes.char == atom or xtypes.wchar == atom then
      value = table.concat{"'", tostring(value), "'"}
    elseif xtypes.string() == atom or xtypes.wstring() == atom then
      value = table.concat{'"', tostring(value), '"'}
    end
     table.insert(result,
                  string.format('%sconst %s %s = %s;', content_indent_string,
                        atom,
                        myname, value))
     return result
  end

	if 'typedef' == mytype then
    table.insert(result, string.format('%s%s %s', indent_string,  mytype,
                  xutils.tostring_role(myname, { instance() }, mymodule)))
		return result
	end

	-- open --
	if (nil ~= myname) then -- not a 'root' namespace / outermost enclosing scope

		-- print the annotations
		if instance[xtypes.QUALIFIERS] then
    	for i, annotation in ipairs(instance[xtypes.QUALIFIERS]) do
          table.insert(result,
                string.format('%s%s', indent_string, tostring(annotation)))
    	end
    end
    
		if 'union' == mytype then
	
			table.insert(result, string.format('%s%s %s switch (%s) {', indent_string,
						mytype, myname, 
						xtypes.nsname(instance[xtypes.SWITCH], instance[xtypes.NS])))

		elseif 'struct' == mytype and instance[xtypes.BASE] then -- base
			table.insert(result,
			    string.format('%s%s %s : %s {', indent_string, mytype,
					myname, instance[xtypes.BASE][xtypes.NAME]))

		else
			table.insert(result,
			             string.format('%s%s %s {', indent_string, mytype, myname))
		end
		content_indent_string = indent_string .. '   '
	end

	if 'module' == mytype then
		for i, role_template in ipairs(instance) do -- walk the module definition
			result = xutils.visit_model(role_template, result, content_indent_string)
		end

	elseif 'struct' == mytype then

		for i, member in ipairs(instance) do -- walk through the model definition
			  local role, role_defn = next(member)
        table.insert(result, string.format('%s%s', content_indent_string,
                            xutils.tostring_role(role, role_defn, mymodule)))
		end

	elseif 'union' == mytype then
		for i, member in ipairs(instance) do -- walk through the model definition

				local case = member[1]

				-- case
				if (nil == case) then
				  table.insert(result,
				               string.format("%sdefault :", content_indent_string))
        elseif ('enum' == instance[xtypes.SWITCH][xtypes.KIND]()) then
          local scopename
          if instance[xtypes.SWITCH][xtypes.NS] then
            scopename = xtypes.nsname(instance[xtypes.SWITCH][xtypes.NS],
                                     instance[xtypes.NS])
          end
          if scopename then
             case = scopename .. '::' .. case
          end
          table.insert(result, string.format("%scase %s :",
            content_indent_string, tostring(case)))
        elseif (xtypes.char == instance[xtypes.SWITCH]) then
					table.insert(result, string.format("%scase '%s' :",
						content_indent_string, tostring(case)))
				else
					table.insert(result, string.format("%scase %s :",
						content_indent_string, tostring(case)))
				end

				-- member element
				local role, role_defn = next(member, #member > 0 and #member or nil)
				table.insert(result, string.format('%s%s', 
				                      content_indent_string .. '   ',
				                      xutils.tostring_role(role, role_defn, mymodule)))
		end

	elseif 'enum' == mytype then
		for i, defn_i in ipairs(instance) do -- walk through the model definition
			local role, ordinal = next(defn_i)
			
			local seperator, enumerator = '', nil
      if i < #instance then -- not the last one
         seperator = ','
      end
			if ordinal then
				enumerator = string.format('%s%s = %s%s', 
      				                content_indent_string, role, ordinal, seperator)
			else
				enumerator = string.format('%s%s%s', 
				                      content_indent_string, role, seperator)
			end
			table.insert(result, enumerator)
		end
	end

	-- close --
	if (nil ~= myname) then -- not top-level / builtin module
		table.insert(result, string.format('%s};\n', indent_string))
	end

	return result
end


--- IDL string representation of a role
-- @function tostring_role
-- @param #string role role name
-- @param #list role_defn the definition of the role in the following format:
--        { template, [collection_qualifier,] [annotation1, annotation2, ...] }
-- @param module the module to which the owner data model element belongs
-- @return #string IDL string representation of the idl member
function xutils.tostring_role(role, role_defn, module)

  local template, seq
  if role_defn then
    template = role_defn[1]
    for i = 2, #role_defn do
      if 'annotation' == role_defn[i][xtypes.KIND]() and 
         'sequence' == role_defn[i][xtypes.NAME] then
        seq = role_defn[i]
        break -- 1st 'collection' is used
      end
    end
  end

  local output_member = ''
  if nil == template then return output_member end

  -- sequences:
  if seq == nil then -- not a sequence
    output_member = string.format('%s %s', 
                        xtypes.nsname(template, module), role)
  elseif #seq == 0 then -- unbounded sequence
    output_member = string.format('sequence<%s> %s',
                                  xtypes.nsname(template, module), role)
  else -- bounded sequence
    for i = 1, #seq do
      output_member = string.format('%ssequence<', output_member)
    end
    output_member = string.format('%s%s', output_member,
                                  xtypes.nsname(template, module))
    for i = 1, #seq do
      output_member = string.format('%s,%s>', output_member,
             xtypes.template(seq[i]) and 
              xtypes.nsname(seq[i], module) or
              tostring(seq[i]))
    end
    output_member = string.format('%s %s', output_member, role)
  end

  -- member annotations:
  local output_annotations = nil
  for j = 2, #role_defn do

    -- local role_defn_j_model = _.model(role_defn[j])
    local name = role_defn[j][xtypes.NAME]

    if 'annotation' == role_defn[j][xtypes.KIND]() then 
      if 'array' == role_defn[j][xtypes.NAME] then   
        for i = 1, #role_defn[j] do
          output_member = string.format('%s[%s]', output_member,
              xtypes.template(role_defn[j][i]) and
                 xtypes.nsname(role_defn[j][i], module) or
                 tostring(role_defn[j][i]))
        end
      elseif 'sequence' ~= role_defn[j][xtypes.NAME] then  
        output_annotations = string.format('%s%s ',
                                            output_annotations or '',
                                            tostring(role_defn[j]))
      end
    end
  end

  if output_annotations then
    return string.format('%s; //%s', output_member, output_annotations)
  else
    return string.format('%s;', output_member)
  end
end

--------------------------------------------------------------------------------
--- Public Interface (of this module):
local interface = {

  visit_instance          = xutils.visit_instance,
  
  visit_model             = xutils.visit_model,
}

return interface
--------------------------------------------------------------------------------
