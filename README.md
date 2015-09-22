
    (c) 2005-2015 Copyright, Real-Time Innovations, All rights reserved.    
                                                                            
     RTI grants Licensee a license to use, modify, compile, and create          
     derivative works of the Software.  Licensee has the right to distribute    
     object form only for use with RTI products. The Software is provided       
     "as is", with no warranty of any type, including any warranty for fitness  
     for any purpose. RTI is under no obligation to maintain or support the     
     Software.  RTI shall not be liable for any incidental or consequential     
     damages arising out of the use or inability to use the software.           
                                                                            
                                                                                                                                                      
# rticonnextdds-ddsl


## Data Domain Specific Language (DDSL)

The purpose of DDSL is to slice and dice data-types.

- [Presentation](https://docs.google.com/presentation/d/1UYCS0KznOBapPTgaMkYoG4rC7DERpLhXtl0odkaGOSI/edit#slide=id.g4653da537_05)

- [Tutorial](examples/ddsl-tutorial.lua)



## Core Concepts

Every DDSL data-object has two sides (like the faces of the coin):

- the template which describes its blueprint (i.e. type or schema)

- the instance which embodies the member fields and their values
     


## Importing XML


### Command Line


    bin/run xml2ddsl [-t] <xml-file> [ <xml-files> ...]

e.g.:

    cd test/
    ../bin/run xml2ddsl xml-test-simple.xml

or, with tracing on:

    ../bin/run xml2ddsl -t xml-test-simple.xml

### API

    local xml = require('ddsl.xtypes.xml')

    -- xml.is_trace_on = true -- OPTIONAL: turn on tracing

    local schemas = xml.files2xtypes( { 'xml-test-simple.xml' } ) -- file list

# Versioning

Tags specify the release version numbers.

The version numbering follows the rules of
[semantic versioning](http://semver.org).
