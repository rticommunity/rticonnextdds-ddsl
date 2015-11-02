# DDSL - Data Domain Specific Language

- [Introduction](#introduction)
- [Getting Started](#getting-started)
- [Writing Apps](#writing-apps)
- [Versioning](#versioning)
- [Contributing Code](#contributing-code)
- [License](#license)

## Introduction

DDSL provides a way to work with strongly typed data in 
[Lua](http://www.lua.org/about.html), which itself is dynamically typed 
and does not enforce data structure constraints. 

Here is a quick illustration using a `ShapeType` datatype.

IDL:
```idl
struct ShapeType {
    long x;
    long y;
    double shapesize;
    string<128> color; //@Key
};
```

DDSL:
```Lua
local ShapeType = xtypes.struct{
    ShapeType = {
      { x = { xtypes.long } },
      { y = { xtypes.long } },
      { shapesize = { xtypes.long } },
      { color = { xtypes.string(128), xtypes.Key } },
    }
  }
```

An instance created from a DDSL datatype will have a form that adheres to the 
the underlying datatype. For example, an instance of `ShapeType` will 
have the form:
```Lua
shape = {
    x           = 'x',
    y           = 'y',
    shapesize   = 'shapesize',
    color       = 'color'
}
```

DDSL brings the following capabilities to Lua (and therefore to platforms where
Lua can be embedded).

1. DDSL is a language for describing datatypes in [Lua](http://www.lua.org/about.html). It can be used as replacement
for data description in an [IDL](https://en.wikipedia.org/wiki/Interface_description_language). In particular:

   - [DDS X-Types](http://www.omg.org/spec/DDS-XTypes/) can be defined 
     in DDSL.
   - Datatypes can be imported from XML.
   - Datatypes can be exported to IDL.
   
   Unlike static formats (such as IDL or XML or JSON), DDSL brings the full 
   power of the [Lua programming language](http://www.lua.org/start.html) to 
   constructing and manipulating datatypes. The datatypes form a connected 
   graph whose integrity is maintained as new datatypes are defined, 
   existing ones removed, or altered.  

2. DDSL provides a way to create instances from datatypes. The datatype
*structural* constraints are enforced on the instances. For example, only fields
that are allowed by the datatype can be present in an instance. Collection 
bounds are enforced. 

   - Note that for efficiency reasons, non-structural constraints are not 
   enforced on the instances. Thus, an instance field whose underlying
   datatype is a boolean can be assigned a string value. However, such 
   constraints can easily be enforced by user code, if so desired.

3. DDSL provides a way to modify the datatypes dynamically at anytime. All the 
aspects of a datatype, except its `KIND` can be changed. For example, datatype members can be added, removed, or their datatype changed. The datatype 
name, enclosing scopes (namespaces) can be altered. This makes DDSL ideal for 
datatype modeling, synthesis and transformation.

4. DDSL keeps all the instances of a datatype in "sync" with the datatype. Thus, 
if a member is removed from a datatype, the corresponding field is removed from
all the instances of the datatype. When a new member is added, all the 
instances are updated with the new field--- initialized to a default value. If a member's datatype is structurally changed, the corresponding field is reset to 
the default value for the new structure. 

5. The default value of a field in an instance is a dot ('.') separated *string*
formed by navigating to that field from the instance. The default value can be
used as an index into some storage system.

6. Datatypes can be introspected, examined, and traversed. For example, enumerations can be be looked by name or ordinal values. Collection bounds 
can be looked up, aliases can be resolved, and so on. This makes it easy to work with structured data in a dynamic language such as Lua, or any environment where
Lua can be embedded (almost every platform).

7. All of the above make DDSL ideally suited for for writing generators. In particular:

   - *Data generators* that produce instances confirming to some data space or 
   data generation rules/constraints, while adhering to an underlying datatype.
    
   - *Code generators* that produce behavior the context of some operational 
   scenario, while adhering to an underlying datatype.

8. DDSL is designed to integrate nicely with the
[RTI Connector for Connext DDS](https://community.rti.com/downloads/experimental/rticonnextdds-connector) which provides a quick and easy way to access the power and functionality of [RTI Connext DDS](https://community.rti.com) from a 
variety of different scripting languages including JavaScript, Python and Lua. 
RTI Connext DDS is a popular software Connectivity Databus for the 
[Industrial Internet of Things](https://www.rti.com) based on the [Data Distribution Service, a.k.a. DDS](http://portals.omg.org/dds/)
open standard for IoT data connectivity.

![Datatype Algebra Diagram](http://rticommunity.github.io/rticonnextdds-ddsl/topics/doc/datatype_algebra.svg "Datatype Algebra")


## Getting Started

- Minimum requirement: [Lua](http://www.lua.org) 5.1+

```bash
# check the installed lua version
lua -v
```
[Install](http://www.lua.org/start.html) an updated Lua version if needed.

- Get DDSL

```bash
#--- Download the latest bundle:
open http://rticommunity.github.io/rticonnextdds-ddsl/ddsl.zip
#--- unzip or untar the release, e.g.
unzip ddsl.zip   # This will create a directory: ddsl/
#--- We refer to the location of the release as `DDSL_HOME`, e.g.
export DDSL_HOME=/path/to/ddsl/
```

- Read the [ddsl.xtypes](http://rticommunity.github.io/rticonnextdds-ddsl/modules/ddsl.xtypes.html) module overview.

- Browse the [ddsl.xtypes](http://rticommunity.github.io/rticonnextdds-ddsl/modules/ddsl.xtypes.html) API and usage examples.

- Step through the [tutorial](http://rticommunity.github.io/rticonnextdds-ddsl/examples/ddsl_tutorial.lua.html) examples.

```bash
cd tutorial/
lua ddsl_tutorial.lua
```

- Try out the scripts: [xml2idl](http://rticommunity.github.io/rticonnextdds-ddsl/scripts/xml2idl.html).

```bash
cd test/
../bin/run xml2idl xml-test-simple.xml
```
or, with debugging on:
```bash   
../bin/run xml2idl -d xml-test-simple.xml
```

- Look at the the [unit tests](https://github.com/rticommunity/rticonnextdds-ddsl/blob/develop/test/ddsl-xtypes-tester.lua) for more advanced examples.


## Writing Apps
     
- Setup Lua's `package.path` to include `lib/lua` (or `src/` if you want to 
  use the source). Assuming `DDSL_HOME` is the location of the directory where 
  you installed DDSL, set the `LUA_PATH` environment variable as follows.

```bash
export LUA_PATH+=\
 "${DDSL_HOME}/src/?.lua;${DDSL_HOME}/src/?/init.lua;\
  ${DDSL_HOME}/lib/lua/?.lc;${DDSL_HOME}/lib/lua/?/init.lc;"
```

- Create datatypes directly using the [ddsl.xtypes](http://rticommunity.github.io/rticonnextdds-ddsl/modules/ddsl.xtypes.html) module.

```lua
require 'ddsl.xtypes'
```
    
- OR, Import datatypes from XML using the [ddsl.xtypes.xml](http://rticommunity.github.io/rticonnextdds-ddsl/modules/ddsl.xtypes.xml.html)
  module.
  
```lua
require 'ddsl.xtypes.xml'
```

- Output IDL using the [ddsl.xtypes.utils](http://rticommunity.github.io/rticonnextdds-ddsl/modules/ddsl.xtypes.utils.html) module.

```lua
require 'ddsl.xtypes.utils'
```
    
- Create instances and use them in application code. Use the logger
  [logger](http://rticommunity.github.io/rticonnextdds-ddsl/modules/logger.html) module to log messages at different verbosity levels.
  
```lua
require 'logger'
```
    
## Versioning

- DDSL uses [semantic versioning](http://semver.org).

- Annotated tags specify the release version numbers.

- The `master` branch is always the latest stable version.

- The `develop` branch is the work in progress.
 

## Contributing Code

- Ensure dependencies are available on the development host

   - [Lua](http://www.lua.org) 5.1+
   - [LDoc](http://stevedonovan.github.io/ldoc/) 1.4.3+ for documentation

  Install the above, if not present on your system.

- [Fork](https://help.github.com/articles/fork-a-repo/) and clone the repository.

- Setup the client side git hooks in you local clone of the repository (fork)
   
```bash
# setup client side hooks
cd .git/hooks/
ln -s ../../build/scripts/pre-commit.lua pre-commit
```

- [OPTIONAL] Build the public API documentation. 

```bash
cd doc/
ldoc .
# Browse the output: `out/html/index.html`
open out/html/index.html
```

- [OPTIONAL] Build all the documentation, both public and private. This may be helpful if you intend to create new type-systems or data model, or just want to
understand the inner workings.

```bash
cd doc/
ldoc . -all  
# Browse the output: `out/html/index.html`
open out/html/index.html
```

- Review the [Documentation Conventions](http://rticommunity.github.io/rticonnextdds-ddsl/index.html) and 
   [Module Organization](http://rticommunity.github.io/rticonnextdds-ddsl/index.html).

- [OPTIONAL: Eclipse Users] If you use the [Eclipse](https://eclipse.org/home/index.php) IDE, **Import...** the `rticonnextdds-ddsl` project located in 
`build/eclipse`.

```bash
#--- Eclipse > File > Import... > Existing Projects into Workspace
build/eclipse/
```

Eclipse [Lua Development Tools (LDT)](https://eclipse.org/ldt/) provides an excellent IDE for editing Lua code.

- Add/Modify/Update Code
 
- Add unit tests
   
- Pass all the unit tests

```bash
cd test/
lua ddsl-xtypes-tester.lua
```
  
- Update CHANGELOG.md to add a section describing the contribution

```bash
edit CHANGELOG.md
```
      
- Create a candidate build locally.
 
```bash
./build/scripts/new-build.sh
# Output goes to `out/{bin,lib, html}`.
```

- Spot check the candidate build.

```bash
cd test/
../out/bin/run xml2idl xml-test-connector.xml 
# Browse the documentation: `out/html/index.html`
open out/html/index.html
```

- If everything looks great, send a [pull request](https://help.github.com/articles/using-pull-requests/); otherwise continue iterating on the previous
steps.

- Create a new release.
```bash
# update the version number and tag the sources
./build/scripts/new-release.lua
```

## License

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
