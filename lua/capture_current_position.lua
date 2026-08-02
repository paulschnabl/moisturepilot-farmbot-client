local U="https://moisturepilot-farmbot-api-production.up.railway.app"
local D,K=env("MP_DEVICE_ID"),env("MP_DEVICE_KEY")
local function L(t,s)send_message(t,"MP "..s)end
local function F(s)L("error",s);toast("MoisturePilot failed","error")end
local function T(v)
 if v==nil then return "nil" end
 if type(v)=="string"then return string.sub(v,1,180)end
 return inspect(v)
end
if not D or D=="" or not K or K==""then F("credentials missing");return end
local H={["Content-Type"]="application/json",["X-Device-ID"]=D,["X-Device-Key"]=K}
local S=env("MP_POINT_SCAN")
if not S or S==""then
 S=D.."-points-"..utc();L("info","1 create scan")
 local r,e=http({url=U.."/v1/farmbot/scans",method="POST",headers=H,body=json.encode({scan_id=S,device_id=D,model_size="10cm"})})
 if e then F("scan transport "..T(e));return end
 if not r then F("scan no response");return end
 L("info","scan HTTP "..r.status.." "..T(r.body))
 if r.status<200 or r.status>=300 then F("scan rejected");return end
 env("MP_POINT_SCAN",S)
else L("info","1 saved scan "..S)end
L("info","2 position")
local p=get_xyz()
L("info","position "..p.x..","..p.y..","..p.z)
L("info","3 photo")
local img=take_photo_raw()
if not img then F("camera returned nil");return end
L("info","4 base64")
local enc=base64.encode(img)
L("info","5 json")
local body=json.encode({scan_id=S,capture_id="point-"..utc(),device_id=D,captured_at=utc(),position={x_mm=p.x,y_mm=p.y,z_mm=p.z},model_size="10cm",image_base64=enc,metadata={source="current_position"}})
L("info","6 upload")
local r,e=http({url=U.."/v1/farmbot/observations",method="POST",headers=H,body=body})
if e then F("upload transport "..T(e));return end
if not r then F("upload no response");return end
L(r.status>=200 and r.status<300 and "info"or"error","upload HTTP "..r.status.." "..T(r.body))
if r.status<200 or r.status>=300 then F("upload rejected");return end
local j=json.decode(r.body)
if not j or not j.moisture_rounded then F("no moisture value");return end
toast("Estimated moisture: "..j.moisture_rounded.."%","success")
