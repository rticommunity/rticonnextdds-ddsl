# Build the DDSL lib/lua binaries
# Created: Rajive Joshi, 2015 Oct 19

DDSLHOME=$(cd $(dirname "$0")/..; pwd -P)
cd ${DDSLHOME}

#------------------------------------------------------------------------------
# output dir:

OUTPUT=out
mkdir -p ${OUTPUT}

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
    luac -o ${OUTPUT}/lib/lua/${file}.lc ${DDSLHOME}/src/${file}.lua
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
    luac -o ${OUTPUT}/lib/lua/${file}.lc ${DDSLHOME}/bin/${file}.lua
    chmod a+x ${OUTPUT}/bin/${file}
done

# run script:
cp -p  ${DDSLHOME}/bin/run ${OUTPUT}/bin

echo "Created/Updated ${OUTPUT}/bin!"

#------------------------------------------------------------------------------
# doc:

cd ${DDSLHOME}/doc
ldoc .

echo "Created/Updated ${OUTPUT}/html!"
#------------------------------------------------------------------------------
