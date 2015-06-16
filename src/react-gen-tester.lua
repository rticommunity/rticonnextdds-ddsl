local reactGen = require("react-gen")
local Gen = require("generator")

local sub1 = 
  reactGen.createSubjectFromPullGen(Gen.rangeGen(1,50))

local disposable = sub1:attach(function (val) 
  print("val = ", val)
  end)
--[[
local sub2 = reactGen.createSubjectFromPullGen(Gen.singleGen(5))

local observable = 
     sub1:map(function (i) 
                print("i = ", i)
                return 2*i 
              end)
         :flatMap(function (j) 
                    print("j = ", j)
                    return sub2:map(function (v) 
                                      return j*v 
                                    end)
                  end)
         :map(function (k) 
                print("k = ", k)
                return 2*k 
              end)
]]
Gen.initialize()

print("Calling push")
sub1:push()
disposable:dispose()
print("Calling push again")
sub1:push()

--sub2:push()

