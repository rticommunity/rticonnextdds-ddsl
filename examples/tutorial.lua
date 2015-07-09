--[[
  (c) 2005-2015 Copyright, Real-Time Innovations, All rights reserved.     
                                                                           
 Permission to modify and use for internal purposes granted.               
 This software is provided "as is", without warranty, express or implied.
--]]
--[[
 -----------------------------------------------------------------------------
 Purpose: Tutorial Helpers
 Created: Rajive Joshi, 2015 Jul 8
 Usage:
    Helpers to step through a tutorial, one lesson at a time.      
-----------------------------------------------------------------------------
--]]

--- Switch to control whether the show() prints any output or not?
local is_show = true

--- Show the given arguments (on the stdout)
-- @param ... the arguments
local function show(...) return is_show and print(...) end

--------------------------------------------------------------------------------

local is_show_stack = {}  -- stack of previous 'is_show' states

local function show_off()     -- supress output
  is_show_stack[#is_show_stack+1] = is_show -- save on the stack
  is_show = false
end

local function show_restore() -- restore output
  is_show = is_show_stack[#is_show_stack]
  is_show_stack[#is_show_stack] = nil -- pop the stack
end

--------------------------------------------------------------------------------
local Tutorial = {}

--- Create a new tutorial
-- @param lessons[in] an array of lessons with the following structure
--
--      {
--        { title1 = function ()
--        
--             return result1
--          end 
--        },
--        
--        { title2 = function ()
--              
--              return result2
--          end 
--        },
--        
--        :
--      }
--          
function Tutorial:new(lessons)
  lessons = lessons or {}
  setmetatable(lessons, self)
  self.__index = self
  return lessons
end

--------------------------------------------------------------------------------

--- Do a specific lesson silently (do show output)
-- @param title[in] 
-- @return the results of the lesson
function Tutorial:dolesson(title)

  -- find the lesson (if any)  
  local lesson, result
  for i = 1, #self do
    local title_i, lesson_i = next(self[i])
    if title == title_i then lesson = lesson_i break end
  end
  
  -- ensure that we found the lesson (else, invalid reference)
  assert(lesson)
  
  show_off() 
  result = table.pack(lesson())
  show_restore()
  
  return table.unpack(result)
end

--------------------------------------------------------------------------------

function Tutorial:run(starting_lesson)
  
  show('========== Welcome to the tutorial! ==========')
  show('--- Step though one lesson at a time. Look at the code side by side ---')
  show('starting at lesson', starting_lesson, ' of ', #self)
  
  for i = starting_lesson, #self do
    local title, lesson = next(self[i])
    
    show('\n========== Lesson', i .. '/' .. #self, title)
    lesson() -- run the lesson
  
    show('\nPress RETURN to go to the next lesson...')
    io.read()
  end
  show('\n========== Congratulations on completing the tutorial!! ==========')
end

--------------------------------------------------------------------------------

Tutorial.show  = show

--------------------------------------------------------------------------------
  
return Tutorial