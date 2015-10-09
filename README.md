
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
     
     
## Modifying Code

- sub-modules 'extend' the parent module; thus new sub-modules can be added 
  independently
  
- run the unit tests

    cd test/
    ./ddsl-xtypes-tester.lua 

  all unit tests should pass before committing code
  
- run the utilities

    cd test/
    ../bin/run xml2ddsl
    ../bin/run xml2ddsl xml-test-connector.xml
    ../bin/run xml2ddsl xml-test-ddsc-types1.xml
    
   Should print out the IDL version of the XML files
   

## Importing XML


### Command Line


    bin/run xml2ddsl [-d] <xml-file> [ <xml-files> ...]

e.g.:

    cd test/
    ../bin/run xml2ddsl xml-test-simple.xml

or, with tracing on:

    ../bin/run xml2ddsl -d xml-test-simple.xml

### API

    local xml = require('ddsl.xtypes.xml')

    -- xml.log.verbosity(xml.log.DEBUG) -- OPTIONAL: turn on debugging

    local schemas = xml.filelist2xtypes{'xml-test-simple.xml'} -- file list

# Versioning

Tags specify the release version numbers.

The version numbering follows the rules of
[semantic versioning](http://semver.org).
