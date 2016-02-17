
function dumpvar(data)
    -- cache of tables already printed, to avoid infinite recursive loops
    local tablecache = {}
    local buffer = ""
    local padder = "    "
 
    local function _dumpvar(d, depth)
        local t = type(d)
        local str = tostring(d)
        if (t == "table") then
            if (tablecache[str]) then
                -- table already dumped before, so we dont
                -- dump it again, just mention it
                buffer = buffer.." -><"..str..">\n"
            else
                tablecache[str] = (tablecache[str] or 0) + 1
                buffer = buffer.."(table name='"..str.."') {\n"
                for k, v in pairs(d) do
                    buffer = buffer..string.rep(padder, depth+1).."["..k.."] => "
                    _dumpvar(v, depth+1)
                end
                buffer = buffer..string.rep(padder, depth).."}"
                meta=getmetatable(d)
                if (meta ~= nil) then
                    buffer = buffer..", META={"
                    for mk, mv in pairs(meta) do
                        buffer = buffer..string.rep(padder, depth+1).."["..tostring(mk).."]: "..tostring(mv).."\n"
                    end
                    buffer = buffer..string.rep(padder, depth).."}"
                end
                buffer = buffer.."\n"
            end
        elseif (t == "number") then
            buffer = buffer.."(" .. t .. ") "..str.."\n"
        else
            buffer = buffer.."(" .. t .. ") \""..str.."\"\n"
        end
    end
    _dumpvar(data, 0)
    return buffer
end


function rawstring(N)
    local retVal = nil
    if (type(N) == type({})) then
        local mt = getmetatable(N)
        setmetatable(N, nil)
        retVal = tostring(N)
        setmetatable(N, mt)
    end
    return retVal
end

