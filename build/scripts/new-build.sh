# Copyright (C) 2015 Real-Time Innovations, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#-------------------------------------------------------------------------------
# Purpose: Build the DDSL lib/lua binaries
# Created: Rajive Joshi, 2015 Oct 19

DDSLHOME=$(cd $(dirname "$0")/../..; pwd -P)
cd ${DDSLHOME}
echo `pwd`

#------------------------------------------------------------------------------
# output dir:

OUTPUT=out

# remove the old one:
rm -rf ${OUTPUT}
echo "Deleted ${OUTPUT}/"

#------------------------------------------------------------------------------
# lib:

LIB_SRC="\
ddsl/version \
ddsl/init \
ddsl/xtypes/init \
ddsl/xtypes/utils/init ddsl/xtypes/utils/nslookup \
ddsl/xtypes/utils/to_idl_string_table \
ddsl/xtypes/utils/to_instance_string_table \
ddsl/xtypes/xml/parser ddsl/xtypes/xml/init \
logger \
"

for file in ${LIB_SRC}; do
    # NOTE: luac must correspond to the lua interpreter used to load these files
	mkdir -p "${OUTPUT}/lib/lua/`dirname $file`"
    #luac -o ${OUTPUT}/lib/lua/${file}.lc ${DDSLHOME}/src/${file}.lua
    cp -p ${DDSLHOME}/src/${file}.lua ${OUTPUT}/lib/lua/${file}.lua 
done
echo "Created/Updated ${OUTPUT}/lib/lua!"

#------------------------------------------------------------------------------
# bin:

BIN_SRC="\
xml2idl \
"

mkdir -p ${OUTPUT}/bin
for file in ${BIN_SRC}; do
	# NOTE: luac must correspond to the lua interpreter used to load these files
    #luac -o ${OUTPUT}/bin/${file}.lc ${DDSLHOME}/bin/${file}.lua
    #chmod a+x ${OUTPUT}/bin/${file}.lc
    cp -p ${DDSLHOME}/bin/${file}.lua ${OUTPUT}/bin/${file}.lua 
    chmod a+x ${OUTPUT}/bin/${file}.lua
done

# run script:
cp -p  ${DDSLHOME}/bin/run ${OUTPUT}/bin

echo "Created/Updated ${OUTPUT}/bin!"

#------------------------------------------------------------------------------
# examples:

EXAMPLE_SRC="\
ddsl_tutorial.lua \
tutorial.lua \
types.xml
"

mkdir -p ${OUTPUT}/tutorial
for file in ${EXAMPLE_SRC}; do
	cp -p ${DDSLHOME}/tutorial/${file} ${OUTPUT}/tutorial/${file}
done
echo "Created/Updated ${OUTPUT}/tutorial!"

#------------------------------------------------------------------------------
# doc:

DOC_SRC="\
datatype_algebra.svg \
"

mkdir -p ${OUTPUT}/html/topics/doc
for file in ${DOC_SRC}; do
cp -p ${DDSLHOME}/doc/${file} ${OUTPUT}/html/topics/doc/
done

cd ${DDSLHOME}/doc
ldoc .

echo "Created/Updated ${OUTPUT}/html!"

#------------------------------------------------------------------------------
# Bundle

cd ${DDSLHOME}/${OUTPUT}

ln -s . ddsl
zip -r html/ddsl ddsl/lib ddsl/bin ddsl/tutorial ddsl/html
rm -f ddsl

echo "Created ${OUTPUT}/html/ddsl.zip!"

#------------------------------------------------------------------------------
exit 0 # success