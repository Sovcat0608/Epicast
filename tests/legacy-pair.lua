local E=...
-- Keep the existing two-art renderer/trigger regression fixtures intact. The
-- old pair is still shipped for Resources and old configuration compatibility.
-- Only these fixtures select that dormant path; mage-crests.lua exercises the
-- real default Mage bank, migration and combined effect stack without overrides.
local classBank=E.ClassBank
E.ClassBank=function(db,class)
 if(class or E.ActiveClass())=='MAGE'then return nil end
 return classBank(db,class)
end
