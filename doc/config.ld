--[[
    (c) 2005-2015 Copyright, Real-Time Innovations, All rights reserved.
--]]

project='DDSL'
title=[[DDSL Documentation]]
description=[[Data Domain Specific Language]]

full_description = [[
Documentation Conventions:

 - `xtemplate`: a datatype defined via the `ddsl.xtypes` API
 - `xinstance`: an instance of a datatype created via `ddsl.xtypes.new_instance`
]]

tparam_alias('xtemplate','xtemplate')
tparam_alias('xinstance','xinstance')

dir='../out/html'

file = { 
    '../src/logger.lua',
    '../src/ddsl/xtypes/utils', 
    '../src/ddsl/xtypes/xml', 
    '../bin',
    exclude = {
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
