#!/usr/bin/env lua
--[[
Copyright (C) 2015 Real-Time Innovations, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]

--- git pre-commit hook
-- @usage 
--  Installation:
--     ln -s pre-commit.lua .git/hooks/pre-commit
-- @author Rajive Joshi

--============================================================================--

--- Starts program cmd in a separated process and captures its stdout
-- @string cmd the command to run
-- @bool[opt=nil] is_raw non-nil => return the raw output without processing 
-- @treturn string the output of 'cmd' (to stdout)
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

--============================================================================--

--- Pass tests on prospective commit:
-- @treturn boolean the status of running tests: true | false
local function pass_tests()
  os.execute('git stash -q --keep-index')
  
  print('  Running tests...')  
  local status = os.execute(
    [[cd test; ./ddsl-xtypes-tester.lua >/dev/null]]
  )
  
  os.execute('git stash pop -q')
  return status
end

--============================================================================--

--- main
-- Run the pre-commit script
local function main()
  print('pre-commit hook:')
  local status = pass_tests()
  if not status then
    print('  Failed to pass tests\n  Aborting!')
    os.exit(status)
  end
  os.exit(status)
end

--============================================================================--
main()
