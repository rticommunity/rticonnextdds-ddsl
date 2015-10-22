--[[
    (c) 2005-2015 Copyright, Real-Time Innovations, All rights reserved.
--]]

project='DDSL'
title=[[DDSL Documentation]]
description=[[Data Domain Specific Language]]

full_description = [[
Documentation Conventions:

 - `xtemplate`: a cannonical instance returned by the `ddsl.xtypes` 
                datatype constructors
 - `xinstance`: an instance of a datatype created via `ddsl.xtypes.new_instance`
]]

tparam_alias('xtemplate','xtemplate')
tparam_alias('xinstance','xinstance')

dir='../out/html'

file = {     
    '../src/ddsl/init.lua', 
    
    '../src/ddsl/xtypes/init.lua', 
    '../src/ddsl/xtypes/utils', 
    '../src/ddsl/xtypes/xml', 
    
    '../src/logger.lua',
    
    '../bin',
    
    exclude = {
      '../src/ddsl/version.lua', 
      '../src/ddsl/xtypes/xml/xml2lua.lua', 
    } 
}
topics = { 
    '../README.md',
    './install.md',
}
examples = {
    '../tutorial/ddsl_tutorial.lua',
}

merge=true
boilerplate=true
backtick_references=true
format='markdown'
style='!fixed'
