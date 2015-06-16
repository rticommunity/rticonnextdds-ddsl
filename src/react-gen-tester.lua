local reactGen = require("react-gen")
local Gen = require("generator")

local sub1 = 
  reactGen.createSubjectFromPullGen(Gen.rangeGen(1,50))

local sub2 = 
  reactGen.createSubjectFromPullGen(Gen.rangeGen(1, 5))

local disposable = 
  sub1:map(function (i) 
             --print("i = ", i)
             return 2*i
           end)
      :flatMap(function (j) 
                 --print("j = ", j)
                 return sub2:map(function (v) 
                                  --print("v = ", v)
                                   return j*v 
                                 end)
               end)
      :attach(function (k) 
                --print("k = ", k)
              end)

Gen.initialize()

for i=1,5 do
  --print("Calling sub1 push ", i)
  sub1:push()

  --print("Calling sub2 push")
  sub2:push()
end

print("disposing")
disposable:dispose()

print("Calling sub1 push again")
sub1:push()

print("Calling sub2 push again")
sub2:push()
