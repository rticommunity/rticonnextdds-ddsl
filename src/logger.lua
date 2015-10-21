--[[
  (c) 2005-2015 Copyright, Real-Time Innovations, All rights reserved.     
                                                                           
 Permission to modify and use for internal purposes granted.               
 This software is provided "as is", without warranty, express or implied.
--]]

--- Log messages at different verbosity levels.
-- Keeps track of the current verbosity level, and outputs log messages that
-- are at or below the current verbosity level.
-- @module logger
-- @alias Logger
-- @author Rajive Joshi

local Logger = {

  -- Log names --> verbosity levels
  -- Logger['<name>'] = the numeric verbosity level

  --- SILENT verbosity level
  SILENT  = 0, 
  --- FATAL verbosity level
  FATAL   = 1,
  --- SEVERE verbosity level
  SEVERE  = 2,
  --- ERROR verbosity level
  ERROR   = 3,
  --- WARNING verbosity level
  WARNING = 4;
  --- NOTICE verbosity level
  NOTICE  = 5,
  --- INFO verbosity level
  INFO    = 6;
  --- DEBUG verbosity level
  DEBUG   = 7,
  --- TRACE verbosity level
  TRACE   = 8,
  
  -- Log levels -> names
  -- Logger[i] = string representation of the verbosity level
  'FATAL',
  'SEVERE',
  'ERROR',
  'WARNING';
  'NOTICE',
  'INFO';
  'DEBUG',
  'TRACE',  
}

Logger.__index = Logger


--- Create a new logger object.
-- Use as many or as few logger objects as needed. For example, different
-- logger objects could be used for different categories of 
-- capabilities or functionality in a large software package (e.g. UI, Platform,
-- Connectivity etc.).
-- 
-- NOTE: Any logger object can be used as a factory of logger objects. 
-- @int[opt=ERROR] default_verbosity the default verbosity level of this Logger
function Logger.new(default_verbosity)

  local _verbosity = default_verbosity or Logger.ERROR -- builtin default
  
  --- Get or Set the verbosity level
  -- @int[opt=nil] new_verbosity the new verbosity level. Should be one of 
  -- the verbosity level constants
  -- @treturn int the verbosity level
  -- @function verbosity
  local verbosity = function(new_verbosity)
    if new_verbosity then
      _verbosity = new_verbosity
    end
    return _verbosity
  end
    
  local log = function(verbosity, ...)
    if _verbosity >= verbosity then
      print(Logger[verbosity] .. ': ', ...)
    end
  end

  local logger = { 
    verbosity = verbosity, 
    
    --- Log messages at the FATAL verbosity level
    -- @param ... variadic 
    -- @function fatal
    fatal     = function(...) log(Logger.FATAL, ...) end,
    
    --- Log messages at the SEVERE verbosity level
    -- @param ... variadic 
    -- @function severe
    severe    = function(...) log(Logger.SEVERE, ...) end,
    
    --- Log messages at the ERROR verbosity level
    -- @param ... variadic
    -- @function error
    error     = function(...) log(Logger.ERROR, ...) end,
    
    --- Log messages at the WARNING verbosity level
    -- @param ... variadic
    -- @function warning
    warning   = function(...) log(Logger.WARNING, ...) end,
    
    --- Log messages at the NOTICE verbosity level
    -- @param ... variadic
    -- @function notice
    notice    = function(...) log(Logger.NOTICE, ...) end,
    
    --- Log messages at the INFO verbosity level
    -- @param ... variadic
    -- @function info
    info      = function(...) log(Logger.INFO, ...) end,
    
    --- Log messages at the DEBUG verbosity level
    -- @param ... variadic
    -- @function debug
    debug     = function(...) log(Logger.DEBUG, ...) end,
    
    --- Log messages at the TRACE verbosity level
    -- @param ... variadic
    -- @function trace
    trace     = function(...) log(Logger.TRACE, ...) end,
  }

  setmetatable(logger, Logger)
  
  return logger
end

return Logger

