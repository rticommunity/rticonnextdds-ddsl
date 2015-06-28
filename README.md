# rticonnextdds-ddsl


Data Domain Specific Language

- [Presentation](https://docs.google.com/presentation/d/1UYCS0KznOBapPTgaMkYoG4rC7DERpLhXtl0odkaGOSI/edit#slide=id.g4653da537_05)


## Importing XML


### Command Line


    bin/run xml2ddsl.lua [-t] <xml-file> [ <xml-files> ...]

e.g.:

    cd test/
    ../bin/run xml2ddsl xml-test-simple.xml

or, with tracing on:

    ../bin/run xml2ddsl -t xml-test-simple.xml

### API

    local xml = require('xtypes-xml')

    -- xml.is_trace_on = true -- OPTIONAL: turn on tracing

    local schemas = xml.files2xtypes( { 'xml-test-simple.xml' }) -- array of files
