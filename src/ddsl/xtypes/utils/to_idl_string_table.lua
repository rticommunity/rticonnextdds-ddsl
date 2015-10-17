--[[
  (c) 2005-2015 Copyright, Real-Time Innovations, All rights reserved.

 Permission to modify and use for internal purposes granted.
 This software is provided "as is", without warranty, express or implied.
--]]
--[[
-----------------------------------------------------------------------------
 Purpose: DDSL X-Types Utilities: to_idl_string_table()
 Created: Rajive Joshi, 2014 Feb 14
-----------------------------------------------------------------------------
--]]

local xtypes = require('ddsl.xtypes')
local log = xtypes.log

--------------------------------------------------------------------------------

--- IDL string representation of a role
-- @function tostring_role
-- @param member[in] a member definition in the following format:
--  { role, template, [collection_qualifier,] [annotation1, annotation2, ...] }
-- @param module the module to which the owner data model element belongs
-- @return IDL string representation of the idl member
local function tostring_member(member, module)

  local role = member[1]    table.remove(member, 1) -- pop off the role
  local role_defn = member
    
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

--- to_idl_string_table() - Visit all elements (depth-first) of
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
local function to_idl_string_table(instance, result, indent_string)
	-- pre-condition: ensure valid data-object
	assert(xtypes.template(instance), 'to_idl_string_table() requires a DDSL instance!')

	-- initialize the result (or accumulate in the provided result)
  result = result or {}

	local indent_string = indent_string or ''
	local content_indent_string = indent_string
	local myname = instance[xtypes.NAME]
	local mytype = instance[xtypes.KIND]()
  local mymodule = instance[xtypes.NS]

	-- print('DEBUG to_idl_string_table: ', Data, model, mytype(), myname)

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
                  tostring_member({ myname,  instance() }, mymodule)))
		return result
	end

	-- open --
	if (nil ~= myname) then -- not a 'root' namespace / outermost enclosing scope

		-- print the annotations
		if instance[xtypes.QUALIFIERS] then
      for i = 1, #instance[xtypes.QUALIFIERS] do
    	    local annotation = instance[xtypes.QUALIFIERS][i]
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
		for i = 1, #instance do -- walk the module definition
			result = to_idl_string_table(instance[i], result, content_indent_string)
		end

	elseif 'struct' == mytype then

		for i = 1, #instance do -- walk through the model definition
		    local member = instance[i]
        table.insert(result, string.format('%s%s', content_indent_string,
                            tostring_member(member, mymodule)))
		end

	elseif 'union' == mytype then
		for i = 1, #instance do -- walk through the model definition
        local member = instance[i]
        	
				-- case
			 local case = member[1]
				if (nil == case) then
				  table.insert(result,
				               string.format("%sdefault :", content_indent_string))
        elseif ('enum' == instance[xtypes.SWITCH][xtypes.KIND]()) then
          case = instance[xtypes.SWITCH](case) -- lookup the enumerator name
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
				table.remove(member, 1) -- pop the 1st element (case)
				table.insert(result, string.format('%s%s', 
				                      content_indent_string .. '   ',
				                      tostring_member(member, mymodule)))
		end

	elseif 'enum' == mytype then
		for i = 1, #instance do -- walk through the model definition
			local role, ordinal = table.unpack(instance[i])
						
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

--------------------------------------------------------------------------------
return to_idl_string_table
--------------------------------------------------------------------------------
