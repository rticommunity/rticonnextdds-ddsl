--[[
  (c) 2005-2015 Copyright, Real-Time Innovations, All rights reserved.     
                                                                           
 Permission to modify and use for internal purposes granted.               
 This software is provided "as is", without warranty, express or implied.
--]]
--[[
-------------------------------------------------------------------------------
Purpose: Logger, to log messages at different verbosity levels 
Created: Rajive Joshi, 2015 Oct 08
-------------------------------------------------------------------------------
--]]

--- A Logger Class
-- Keeps track of the current verbosity level, and outputs log messages that
-- are at or below the current verbosity level
local Logger = {

  --- Log names --> verbosity levels
  -- Logger['<name>'] = the numeric verbosity level
  SILENT  = 0,
  FATAL   = 1,
  SEVERE  = 2,
  ERROR   = 3,
  WARNING = 4;
  NOTICE  = 5,
  INFO    = 6;
  DEBUG   = 7,
  TRACE   = 8,
  
  --- Log levels -> names
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


--- Create a new Logger instance
-- @param default_verbosity[in] the default verbosity level of this Logger
function Logger.new(default_verbosity)

  local _verbosity = default_verbosity or Logger.ERROR -- builtin default
  
  --- Get or Set the verbosity level
  -- @param new_verbosity[in] OPTIONAL the new level. Should be one of 
  -- the constants defined in the Logger class.
  -- @return the resultant verbosity level
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
    
    fatal     = function(...) log(Logger.FATAL, ...) end,
    severe    = function(...) log(Logger.SEVERE, ...) end,
    error     = function(...) log(Logger.ERROR, ...) end,
    warning   = function(...) log(Logger.WARNING, ...) end,
    notice    = function(...) log(Logger.NOTICE, ...) end,
    info      = function(...) log(Logger.INFO, ...) end,
    debug     = function(...) log(Logger.DEBUG, ...) end,
    trace     = function(...) log(Logger.TRACE, ...) end,
  }

  setmetatable(logger, Logger)
  
  return logger
end

return Logger

