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
--    build/scripts/new-release.lua
-- @author Rajive Joshi

--============================================================================--

--- Update version number.
-- @string file the lua file to update with the new version number
-- @treturn boolean the status of updating the file: true | false
-- @treturn string the version string 
local function update_version(file)
  -- NOTE: The current working directory for hook scripts is always set to the
  -- root of the repository

  local status
  
  status = os.execute([[echo "return '`git describe --tags`'" >]] .. file)
  if not status then return status end
  
  local version = loadfile(file)
  if not version then return false end
  
  print('Committing version number: ', version())
  status = os.execute([[git add ]] .. file)
  if not status then return status end
  
  status = os.execute([[git commit -m ]] .. version())
  if not status then return status end
  
  print('-> Updated version: ', version())
  
  return status, version()
end

--============================================================================--

--- Create annotated tag
-- @treturn boolean the status of tagging: true | false
-- @treturn string the version string 
-- @treturn string the tag name
local function tag_release(file)
 
  local answer, status, version
  repeat
     io.write("Enter tag name: ")
     io.flush()
     answer=io.read()
  until answer ~= nil and answer ~= ''
  print('  Tag name: ', answer)
  
  -- first create a lightweight tag
  status, version = os.execute([[git tag ]] .. answer)
  if not status then return status end
  
  -- use this to update the version number
  status, version = update_version('src/ddsl/version.lua')
  if not status then 
    print('  Failed to update version number\n  Aborting!')
    os.exit(status) 
  end 
  
  -- delete the a lightweight tag
  status = os.execute([[git tag -d ]] .. answer)
  if not status then return status end
  
  -- create an annotated tag
  status = os.execute([[git tag -m 'Version ]] ..version.. [[ ' -a ]] .. answer)
  if not status then return status end
  print('-> Tagged release: ', answer)
    
  return status, version, answer
end

--============================================================================--

--- Update gh-pages
-- @string version the version number
local function update_gh_pages(version)
  local status
  
  status = os.execute([[./build/scripts/new-build.sh]])
  if not status then 
    print('  Failed to create new build\n  Aborting!')
    os.exit(status)
  end
  
  status = os.execute([[git checkout gh-pages]])
  if not status then 
    print('  Failed to checkout gh-pages\n  Aborting!')
    os.exit(status)
  end
  
  status = os.execute([[mv out .out; rm -rf *; mv .out/html/* .; git add *]])
  if not status then 
    print('  Failed to update gh-pages content\n  Aborting!')
    os.exit(status)
  end
  
  status = os.execute([[mv .out out; git commit -m 'Version ]]..version..[[']])
  if not status then 
    print('  Failed to commit gh-page update\n  Aborting!')
    os.exit(status)
  end
  
  print([[
  TODO gh-pages:
   - Review the gh-pages update
          git status
          ls
          git log
   - If it looks good, push the updates to the github server:
          git push origin gh-pages
   ]])
  
  return status
end

--============================================================================--

--- main
local function main()
  local status, version, tagname = true
  
  status, version, tagname = tag_release()
  if not status then
    print('  Failed to tag release!\n  Use "git tag" to review existing tags')
    os.exit(status)
  end
  
  status = update_gh_pages(version)
  if not status then
    print('  Failed to update gh-pages!\n Review the gh-pages branch!')
    os.exit(status)
  end
  
  print([[
  TODO master:
   - If everything looks good, push the updates to the origin:
          git push origin ]] .. tagname .. [[
   - Switch to a code branch: 
          git checkout master
   - Push the code branch (if not already done):
          git push origin master
   ]])
  os.exit(status)
end

--============================================================================--
main()
