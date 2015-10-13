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

local log = xtypes.log

--------------------------------------------------------------------------------
-- X-Types Utilities
--------------------------------------------------------------------------------
local xutils = {}
                           
--- Look up the xtypes template referenced by a qualified name
-- Searches in several places:
--    - in  the pre-defined xtypes, 
--    - in the enclosing or global scope
-- @param name [in] qualifed (i.e. scoped) name of the datatype to lookup
-- @param ns [in] the scope (or namespace) to lookup the name in
-- @return the template referenced by name, or nil
-- @return the template member, if any, identified by name (e.g. enum value)
local function nslookup(name, ns)

  assert(nil ~= ns)
  local template = nil        -- template identified by name
  local template_member = nil -- template member identified by name
    
  -----------------------------------------------------------------------------
  -- lookup xtype builtins
  -----------------------------------------------------------------------------
 
  -- deviations specific to XML representation  
  local xmlName2Model = {
    unsignedShort    = xtypes.unsigned_short,
    unsignedLong     = xtypes.unsigned_long,
    longLong         = xtypes.long_long,
    unsignedLongLong = xtypes.unsigned_long_long,
    longDouble       = xtypes.long_double,
  }
  -- lookup in the deviations table
  local template = xmlName2Model[name] 
  if nil ~= template then return template end


  -- lookup in the xtypes pre-defined templates
  for i, datatype in pairs(xtypes) do
    if 'table' == type(datatype) and
       datatype[xtypes.KIND] and -- this is a valid X-Type
       name == datatype[xtypes.NAME] then
       template = datatype
       break
    end
  end
    
  -----------------------------------------------------------------------------
  -- lookup in scope 'ns'
  -----------------------------------------------------------------------------

  if not template and ns then 
    -- split into identifiers with a '::' separator for each identifier
    -- each iteration of the loop resolves one identifier of the qualified name
    for w in string.gmatch(name, "[%w_]+") do     
      log.debug('\t"' .. w .. '"') -- capture to resolve in this iteration
      
      -- retrieve the template for the 1st capture
      if not template then -- 1st capture: always runs first!
    
        -- determine the enclosing scope to start searching from:
        local parent = '::' == name:sub(1,2) 
                       and xtypes.nsroot(ns) -- file|global scope
                       or ns                 -- relative scope

        -- is w defined in the context of the specified scope?
        repeat
          log.debug('\t\t ::', parent)
          template = parent[w]
          parent = parent[xtypes.NS]
        until template or not parent

      else -- 2nd capture onwards
        
        -- keep track of the scope resolved so far
        ns = template 
                
        -- Found
        if ns[w] then   
          -- Lookup in the scope resolved so far
          log.debug('\t\t ..', ns[w])
   
          -- lookup the template identified by 'w'
          template = xtypes.template(ns[w])  
 
          -- alternatively: if 'w' is an enum member, accept it
          -- NOTE: in this case, the value of template will be nil
          if 'enum' == ns[xtypes.KIND]() then
            template_member = w -- ENUM member
          end
            
        -- Not Found
        else
          template = nil
        end
      end
      
      
      -- For each capture, check for IDL scoping rules:
      -- Does 'w' refer to an enum value within an enclosing scope?
      if not template then
        if 'module' == ns[xtypes.KIND]() then
          -- IDL NOTE:
          --   Enumeration value names are introduced into the enclosing scope
          --   and then are treated like any other declaration in that scope
          for i = 1, #ns do
            local datatype = ns[i]
            if 'enum' == datatype[xtypes.KIND]() and datatype[w] then
              template_member = w -- ENUM member
              break -- resolved!
            end
          end
        end
      end
      
      log.debug('\t   ->', template or template_member) -- result of resolution

      -- could not resolve the capture => skip remaining capture segments
      if nil == template or nil ~= template_member then break end  
    end
  end
  
  -----------------------------------------------------------------------------
  -- result

  if nil == template and nil == template_member then
    log.notice('\t=>', table.concat{'Unresolved name: "', name, '"'})
  end      
                         
  return template, template_member
end

--------------------------------------------------------------------------------

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
  for i = 1, #(base or template) do
    -- skip annotations
      -- walk through the elements in the order of definition:
      local member = (base or template)[i]
      local role
      if 'struct' == mytype then
        role = member[1]
      elseif 'union' == mytype then
        role = member[2]
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
                  xutils.tostring_role({ myname,  instance() }, mymodule)))
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
			result = xutils.visit_model(instance[i], result, content_indent_string)
		end

	elseif 'struct' == mytype then

		for i = 1, #instance do -- walk through the model definition
		    local member = instance[i]
        table.insert(result, string.format('%s%s', content_indent_string,
                            xutils.tostring_role(member, mymodule)))
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
				                      xutils.tostring_role(member, mymodule)))
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


--- IDL string representation of a role
-- @function tostring_role
-- @param member[in] a member definition in the following format:
--  { role, template, [collection_qualifier,] [annotation1, annotation2, ...] }
-- @param module the module to which the owner data model element belongs
-- @return IDL string representation of the idl member
function xutils.tostring_role(member, module)

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
--- Public Interface (of this module):
local interface = {
  nslookup                = nslookup,
  
  visit_instance          = xutils.visit_instance,
  
  visit_model             = xutils.visit_model,
}

return interface
--------------------------------------------------------------------------------
