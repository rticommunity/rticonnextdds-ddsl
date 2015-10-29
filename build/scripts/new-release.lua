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

--- Update the version number and create an annotated tag.
-- @usage 
--    build/scripts/update-version.lua
-- @author Rajive Joshi

--============================================================================--

--- Update version number.
-- @string file the lua file to update with the new version number
-- @treturn boolean the status of updating the file: true | false
local function update_version(file)
  -- NOTE: The current working directory for hook scripts is always set to the
  -- root of the repository

  local status
  
  status = os.execute([[echo "return '`git describe`'" >]] .. file)
  if not status then return status end
  
  local version = loadfile(file)
  if not version then return false end
  
  print('Committing version number: ', version())
  status = os.execute([[echo git add ]] .. file)
  if not status then return status end
  
  status = os.execute([[echo git commit -m ]] .. version())
  if not status then return status end
  
  print('-> Updated version: ', version())
  
  return status
end

--============================================================================--

--- Create annotated tag
-- @treturn boolean the status of tagging
local function tag_release(file)
 
  local answer, status
  repeat
     io.write("Enter tag name: ")
     io.flush()
     answer=io.read()
  until answer ~= nil and answer ~= ''
  print('  Tag name: ', answer)
  
  -- first create a lightweight tag
  status = os.execute([[echo "git tag ]] .. answer .. [["]])
  if not status then return status end
  
  -- use this to update the version number
  status = update_version('src/ddsl/version.lua')
  if not status then 
    print('  Failed to updated version number\n  Aborting!')
    os.exit(status) 
  end 
  
  -- delete the a lightweight tag
  status = os.execute([[echo "git tag -d ]] .. answer .. [["]])
  if not status then return status end
  
  -- create an annotated tag
  status = os.execute([[echo "git tag -a ]] .. answer .. [["]])
  if not status then return status end
  print('-> Tagged release: ', answer)
    
  return status
end

--============================================================================--

--- main
local function main()
  local status = true
  
  status = tag_release()
  if not status then
    print('  Failed to tag release!\n  Use "git tag" to review existing tags')
    os.exit(status)
  end
  os.exit(status)
end

--============================================================================--
main()
