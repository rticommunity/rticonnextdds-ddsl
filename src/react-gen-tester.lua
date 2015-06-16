local reactGen = require("react-gen")
local Gen = require("generator")

local sub1 = 
  reactGen.createSubjectFromPullGen(Gen.singleGen(5))

local sub2 = 
  reactGen.createSubjectFromPullGen(Gen.Double)

local observable = 
     sub1:map(function (i) 
                print("i = ", i)
                return 2*i 
              end)
         :flatMap(function (j) 
                    print("j = ", j)
                    return sub2 
                  end)
         :map(function (k) 
                print("k = ", k)
                return 2*k 
              end)

Gen.initialize()

sub1:push()
sub2:push()

