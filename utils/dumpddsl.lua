-- dumpDDS navigates through the DDSL object
-- Does not end the output buffer with a newline
xtypes = require('ddsl.xtypes')
function dumpDDSL(top)
  local indentString="  "
  local out=""
  local tableCache = {}     -- Avoid to repeat referenced types. Cache modules, structs, enums names here

  local function _dumpDDSL(top, indent)
    local k=top[xtypes.KIND]()

    --=============================== MODULE ====================================--
    if (k == xtypes.MODULE()) then
      -- Module: iterate through elements of the module
      name=tostring(top)
      out = out .. string.rep(indentString, indent) .. k .. " " .. name
      if (tableCache[name] == nil) then
        out = out .. " = {\n"
        for i=1,#top do
          _dumpDDSL(top[i], indent+1)
          out = out .. "\n"
        end
        out = out .. string.rep(indentString, indent) .. "}"
        tableCache[name] = true
      end

    --=============================== STRUCT ====================================--
    elseif (k == xtypes.STRUCT()) then
      -- Struct: elements are structProperties
      --     s = xtypes.struct { Shape = { { x = { xtypes.long} }, {y = { xtypes.long } }, { color={enumColor, xtypes.key} } }}
      -- Iterates through all the properties, each property is a table like this one:
      --     { x = { type, attrib, ...} } 
      name=tostring(top)
      out = out .. string.rep(indentString, indent) .. k .. " " .. name
      if (tableCache[name] == nil) then
        out = out .. " = {\n"
        for i=1,#top do
          propName,propDef=next(top[i])
          -- propDef is an array where the 1st element is the type, followed by the annotations
          propType = propDef[1]

          out = out .. string.rep(indentString, indent+1) .. propName .. ": "
          _dumpDDSL(propType, 0)
          if (#propDef > 1) then
            -- Append also all the annotations
            for j=2,#propDef do
              out = out .. ", "; _dumpDDSL(propDef[j], 0)
            end
          end
          out = out .. ";\n"
        end
        out = out .. string.rep(indentString, indent) .. "}"
        tableCache[name] = true
      end

    --=============================== ENUM ======================================--
    elseif (k == xtypes.ENUM()) then
      -- Enum nodes are arrays similar to structs
      --     foo = xtypes.enum { Color = { { Black = 1 }, { Red = 2 }, { Blue = 3 } } }
      name=tostring(top)
      out = out .. string.rep(indentString, indent) .. k .. " " .. name
      if (tableCache[name] == nil) then
        out = out .. " = {\n"
        for i=1,#top do
          enumName,enumValue = next(top[i])
          out = out .. string.rep(indentString, indent+1) .. enumName .. " = " .. enumValue .. ";\n"
        end
        out = out .. string.rep(indentString, indent) .. "}"
        tableCache[name] = true
      end

    --=============================== UNION =====================================--
    elseif (k == xtypes.UNION()) then
      -- Union
      --     u = xtypes.union { MyUnion = { xtypes.long} }
      --     u[1] = { '1', m1 = {xtypes.long} }
      --     u[2] = { '2', m2 = {xtypes.float} }
      --     u[3] = { xtypes.EMPTY, m3 = {xtypes.short} }
      -- Iterates through all the members
      name=tostring(top)
      
      out = out .. string.rep(indentString, indent) .. k .. " " .. name
      if (tableCache[name] == nil) then
        -- Compose '    union MyUnion (discrType) { '
        discriminator = top[xtypes.SWITCH]
        out = out .. " ("
        _dumpDDSL(discriminator, 0)
        out = out .. ") = {\n"
        for i=1,#top do
          caseDef = top[i]
          -- caseDef has exactly 2 elements: a number containing the discriminator value
          -- and a key-value record where key=field name, value=field definition
--[[
          for k,v in pairs(caseDef) do
            if type(k) == type(1) then
              caseVal = v
            else 
              caseName=k
              caseObj=v
            end
          end
]]--
          local k,caseVal = next(caseDef, nil)
          local caseName,caseObj=next(caseDef, k);
          -- Note: caseVal can be a number or the xtables.EMPTY object (for default)
          out = out .. string.rep(indentString, indent+1) .. "case " .. tostring(caseVal) .. ": " .. caseName .. ": "
          _dumpDDSL(caseObj[1], 0)
          if (#caseObj > 1) then
            -- Append also all the annotations
            for j=2,#caseObj do
              out = out .. ", "; _dumpDDSL(caseObj[j], 0)
            end
          end
          out = out .. ";\n"
        end
        out = out .. string.rep(indentString, indent) .. "}"
        tableCache[name] = true
      end


    --=============================== TYPEDEF ===================================--
    elseif (k == xtypes.TYPEDEF()) then
      name=tostring(top)
      out = out .. string.rep(indentString, indent) .. k .. " " .. name
      if (tableCache[name] == nil) then
        out = out .. " = "
        _dumpDDSL(top(), 0)
        out = out .. ";"
        tableCache[name] = true
      end

    --=============================== ANNOTATION ================================--
    elseif (k == xtypes.ANNOTATION ()) then
      out = out .. string.rep(indentString, indent) .. tostring(top)

    --=============================== ATOM ======================================--
    elseif (k == xtypes.ATOM()) then
      out = out .. string.rep(indentString, indent) .. tostring(top)

    --=============================== CONST =====================================--
    elseif (k == xtypes.CONST()) then
      -- Invoke the object to obtain a pair value, type
      -- print("CONST - out=" .. out);
      v,t=top()
      out = out .. string.rep(indentString, indent) .. k .. ": " .. tostring(top) .. " ";
      _dumpDDSL(t, 0)
      out = out .. " = " .. tostring(v)

    --===========================================================================--
    else
      out = out .. string.rep(indentString, indent) .. "Error: unknwon kind=" .. k
    end
  end

  _dumpDDSL(top, 0)
  return out
end

