#!/usr/bin/env node
/*****************************************************************
 * (c) Copyright, Real-Time Innovations, $Date$. 
 * All rights reserved.
 * No duplications, whole or partial, manual or electronic, may be made
 * without express written permission.  Any such copies, or
 * revisions thereof, must display this notice unaltered.
 * This code contains trade secrets of Real-Time Innovations, Inc.
 *
 *     modification history
 *     ---------------------
 *
 *
 */

// This command uses the rti.ddsl.js together with lua.vm.js to
// load DDS inside node.js and access the type information from LUA.
// 

ddsl = require("rti.ddsl.js");


// Main code starts here
// -------------------------------------------------------------------------------------------------------
if (process.argv.length != 3) {
    console.log("Usage: dumpddsl <xmlFilename>");
    process.exit(1);
}

var fileName = process.argv[2];

console.log("Creating instance...");
me = new ddsl.RTIDDSL(true);
console.log("Instance created");

me.loadDDSL();
root = me.buildFromFile(fileName);
if (!root) {
    console.log("Failed to load XML file: '" + fileName + "'");
    process.exit(1);
}
console.log("XML file successfully loaded. Type dump:");
console.log(me.dumpTree(root));



