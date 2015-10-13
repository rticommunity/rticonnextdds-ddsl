--[[
  (c) 2005-2015 Copyright, Real-Time Innovations, All rights reserved.

 Permission to modify and use for internal purposes granted.
 This software is provided "as is", without warranty, express or implied.
--]]
--[[
-----------------------------------------------------------------------------
 Purpose: DDSL X-Types Utilities
 Created: Rajive Joshi, 2014 Feb 14
-----------------------------------------------------------------------------
@module ddsl.xtypes.utils

SUMMARY

    X-Types Utilities

-----------------------------------------------------------------------------
--]]

--------------------------------------------------------------------------------
--- Public Interface (of this module):
local interface = {
  nslookup                = require 'ddsl.xtypes.utils.nslookup',
  
  visit_model             = require 'ddsl.xtypes.utils.to_idl_string_table',
  
  visit_instance          = require 'ddsl.xtypes.utils.to_instance_string_table',
}

return interface
--------------------------------------------------------------------------------
