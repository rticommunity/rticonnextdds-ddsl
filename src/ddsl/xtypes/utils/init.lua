--[[
  (c) 2005-2015 Copyright, Real-Time Innovations, All rights reserved.

 Permission to modify and use for internal purposes granted.
 This software is provided "as is", without warranty, express or implied.
--]]

--- DDSL Utilities.
-- @module ddsl.xtypes.utils
-- @author Rajive Joshi

local _M = {

  nslookup                = require 'ddsl.xtypes.utils.nslookup',
  
  to_idl_string_table     = require 'ddsl.xtypes.utils.to_idl_string_table',
  
  to_instance_string_table=require 'ddsl.xtypes.utils.to_instance_string_table',
}

return _M
--============================================================================--
