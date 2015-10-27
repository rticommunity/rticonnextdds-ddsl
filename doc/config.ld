--[[
    (c) 2005-2015 Copyright, Real-Time Innovations, All rights reserved.
--]]

project='DDSL'
title=[[DDSL Documentation]]
description=[[Data Domain Specific Language]]

full_description = [[

- [README](topics/README.md.html) 
  first!

- [Source Code (github)](https://github.com/rticommunity/rticonnextdds-ddsl).


### Documentation Conventions

- `xtemplate`: a cannonical instance returned by the `ddsl.xtypes` 
                datatype constructors
- `xinstance`: an instance of a datatype created via `ddsl.xtypes.new_instance`()


### Module Organization

Sub-modules *extend* the parent module. New sub-modules can be added 
independently to extend the functionality of a base module. This approach 
allows us to create a modular extensible code base, without cluttering the 
core modules (`ddsl` and `ddsl.xtypes`).

- `ddsl.xtypes` extends the abstract module `ddsl` 
- `ddsl.xtypes.xml` extends `ddsl.xtypes` to import from XML
- `ddsl.xtypes.utils` extends `ddsl.xtypes` to provide useful utility functions
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
    '../CHANGELOG.md',
}
examples = {
    '../tutorial',
    exclude = {
      '../tutorial/tutorial.lua',
    }
}

merge=true
boilerplate=true
backtick_references=true
format='markdown'
style='!fixed'
