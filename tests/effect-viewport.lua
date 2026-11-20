local E=...
local function near(a,b)
 assert(math.abs(a-b)<1e-7,string.format("%.9f != %.9f",a,b))
end
local function dot(a,b,offset)
 return a[1]*b[offset]+a[2]*b[offset+1]+a[3]*b[offset+2]
end
local function offsets(slot,point,frameWidth,halfFovTangent)
 local scene,actor=slot.scene,slot.actor
 local axes,eye=scene.SetCameraOrientationByAxisVectorsArgs,scene.SetCameraPositionArgs
 local position=actor.SetPositionArgs
 local relative={}
 for i=1,3 do relative[i]=point[i]*actor.scale+position[i]-eye[i]end
 local pixelsPerUnit=frameWidth/(2*halfFovTangent*dot(relative,axes,1))
 return dot(relative,axes,4)*pixelsPerUnit,dot(relative,axes,7)*pixelsPerUnit
end

-- Force of Nature Impact's fitted origin/scale as reported by the Forever catalogue.
local origin={.030246257781982422,-.10769903659820557,.11916017532348633}
local scale=.35974042655500893
E.CrestBakes["DRUID:balance"]={{
 fileID=166205,name="Forceofnature impact",scale=scale,
 originX=origin[1],originY=origin[2],originZ=origin[3],
 azimuth=0,elevation=0,trailAngle=90,trailX=3,trailY=-4,trailOpacity=32,trailSize=27,
}}
Mock.class="DRUID"
Mock.event("ADDON_LOADED","Epicast");Mock.advance(0)
E.OpenOptions();E.SetDeveloperMode(true);E.SelectCrest("spells","balance")
E.SetCrestEnabled(E.draft,"spells","balance",true);E.Apply()
E.EffectLibrary.Open()
local p=E.EffectLibrary.window
p.tabs.config:Click()
local s=p.layerControls;s.Select("fx1")
Mock.advance(0)
local crest=E.GetEntry("spells","balance")
local live=crest.addedEffectSlots[1].nativeSmoke.slots[1]
local preview=p.crestPreview.addedEffectSlots[1].nativeSmoke.slots[1]
local starts={live.actor.animationStarts,preview.actor.animationStarts}

for _,size in ipairs({27,10,5,100,200})do
 s.inputs.trailSize.slider.Slider:SetValue(size);Mock.advance(0)
 if p.saveAll:IsEnabled()then p.saveAll:Click()end
 assert(E.GetAddedEffects(E.GetEffectLibraryTarget())[1].trailSize==size)
 for i,slot in ipairs({live,preview})do
  local scene=slot.scene
  local width=scene:GetWidth()
  local oldWidth=576*(crest.art:GetWidth()/150)*size/100
  local tangent=math.tan(scene.SetCameraFieldOfViewArgs[1]/2)
  assert(width>oldWidth and width<=oldWidth+192 and tangent<=1.00000001)
  near(scene:GetHeight(),width)
  near(width/tangent,oldWidth/.375)
  near(slot.anchorX,crest.art:GetWidth()*(.5+3/150))
  near(slot.anchorY,crest.art:GetHeight()*(-.5-4/150))
  local x,y=offsets(slot,origin,width,tangent)
  near(x,0);near(y,0)
  for _,point in ipairs({{3.0767,1.5306,3.5939},{-3.0162,-1.746,-3.3556}})do
   local oldX,oldY=offsets(slot,point,oldWidth,.375)
   local newX,newY=offsets(slot,point,width,tangent)
   near(oldX,newX);near(oldY,newY)
  end
  if size<=27 then
   -- Sample a particle above the old frustum. Its projected location remains
   -- identical and the larger surface can retain it even at the minimum size.
   local particle={origin[1],origin[2],origin[3]+3.5/scale}
   local _,top=offsets(slot,particle,width,tangent)
   assert(top>oldWidth/2 and top<width/2)
  end
  assert(slot.actor:GetModelFileID()==166205 and slot.actor.animationStarts==starts[i])
 end
end
assert(crest.addedEffectSlots[1].nativeSmoke.slots[1]==live)
assert(p.crestPreview.addedEffectSlots[1].nativeSmoke.slots[1]==preview)
print("PASS: Force of Nature Impact keeps its scale and origin from 5–200%, with extra particle room in the live and preview ModelScenes")
