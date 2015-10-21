--[[
  (c) 2005-2015 Copyright, Real-Time Innovations, All rights reserved.

 Permission to modify and use for internal purposes granted.
 This software is provided "as is", without warranty, express or implied. 
--]]

--- @module ddsl.xtypes.utils

local xtypes = require('ddsl.xtypes')
local log = xtypes.log
    
--- Look up the xtypes template referenced by a qualified name.
-- 
--  Searches in several places:
--  
--   - in  the pre-defined xtypes, 
--   - in the enclosing or global scope
--   
-- @string name qualifed name (i.e. optionally scoped with `::`) of the 
--   datatype to lookup
-- @xtemplate ns the scope (or namespace) to lookup the name in
-- @treturn xtemplate the template referenced by name, or nil
-- @treturn ?string the template member, if any, identified by name 
--  (e.g. enum value)
-- @function nslookup
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
return nslookup
--------------------------------------------------------------------------------
