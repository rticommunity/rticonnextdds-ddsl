#!/usr/bin/env lua
--[[
  (c) 2005-2015 Copyright, Real-Time Innovations, All rights reserved.     
                                                                           
 Permission to modify and use for internal purposes granted.               
 This software is provided "as is", without warranty, express or implied.
--]]
--[[
-------------------------------------------------------------------------------
Purpose: git pre-commit hook
Created: Rajive Joshi, 2015 Oct 13
Installation:
        ln -s pre-commit.lua .git/hooks/pre-commit
-------------------------------------------------------------------------------
--]]

-------------------------------------------------------------------------------

--- Starts program cmd in a separated process and captures its stdout
-- @param cmd[in] the command to run
-- @param is_raw[in] non-nil => return the raw output without processing 
-- @return the output of 'cmd' (to stdout)
function os.capture(cmd, is_raw)
  local f = assert(io.popen(cmd, 'r'))
  local s = assert(f:read('*a'))
  f:close()
  if is_raw then return s end
  s = string.gsub(s, '^%s+', '') -- remove spaces at the beginning of each line
  s = string.gsub(s, '%s+$', '') -- remove spaces at the end of each line
  s = string.gsub(s, '[\n\r]+', ' ') -- remove blank lines
  return s
end

-------------------------------------------------------------------------------

--- Pass tests on prospective commit:
-- @return the status of running tests: true | false
local function passtests()
  os.execute('git stash -q --keep-index')
  
  print('  Running tests...')  
  local status = os.execute(
    [[cd test; ./ddsl-xtypes-tester.lua >/dev/null]]
  )
  
  os.execute('git stash pop -q')
  return status
end

-------------------------------------------------------------------------------

--- Update version number.
-- @param file the lua file to update with the new version number
-- @return the status of updating the file: true | false
local function update_version(file)
  -- NOTE: The current working directory for hook scripts is always set to the
  -- root of the repository
 
  local status = os.execute(
    [[echo "return '`git describe`'" >]] .. file
  )
  if not status then return status end
  
  local version = loadfile(file)
  if not version then return false end
  
  print('  Committing version number: ', version())
  return os.execute('git add ' .. file)
end

-------------------------------------------------------------------------------

--- main
-- Run the pre-commit script
local function main()
  print('pre-commit hook:')
  local status = passtests()
  if not status then -- failed!
    print('  Tests must pass in order to commit!\n  Aborting commit!')
    os.exit(status)
  end
  
  status = update_version('src/ddsl/version.lua')
  if not status then -- failed!
    print('  Version number update failed!\n  Aborting commit!')
    os.exit(status) 
  end 

  os.exit(status)
end

-------------------------------------------------------------------------------
main()
-------------------------------------------------------------------------------
