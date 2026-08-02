local U="https://moisturepilot-farmbot-api-production.up.railway.app"
local A=U.."/v1/farmbot"
local function ok(r,e)return not e and r and r.status>=200 and r.status<300 end
for i=1,18 do local r=http({url=U.."/health"});if r and r.status==200 then break end;wait(5000)end
local D,K=env("MP_DEVICE_ID"),env("MP_DEVICE_KEY")
if not D or not K then
 local r,e=http({url=A.."/enroll",method="POST",headers={Authorization="Bearer "..auth_token()}})
 if not ok(r,e)or r.status~=201 then toast("Enrollment failed","error");return end
 local j=json.decode(r.body);D=j.device_id;K=j.device_key
 env("MP_DEVICE_ID",D);env("MP_DEVICE_KEY",K)
end
local H={["Content-Type"]="application/json",["X-Device-ID"]=D,["X-Device-Key"]=K}
local function post(p,b)return http({url=A..p,method="POST",headers=H,body=json.encode(b)})end
local g=photo_grid()
local fw,fh=g.x_spacing_mm+5,g.y_spacing_mm+5
local rx,ry=(g.x_grid_points-1)*g.x_spacing_mm,(g.y_grid_points-1)*g.y_spacing_mm
local nx,ny=math.max(1,math.ceil(2*rx/fw)+1),math.max(1,math.ceil(2*ry/fh)+1)
local sx,sy=nx>1 and rx/(nx-1)or 0,ny>1 and ry/(ny-1)or 0
local S=env("MP_SCAN50")
if not S or S==""then S=D.."-50-"..utc()end
local z=garden_size()
local r,e=post("/scans",{scan_id=S,device_id=D,garden_width_mm=z.x,garden_height_mm=z.y,metadata={cells=nx*ny,photo_overlap_percent=50,x_spacing_mm=sx,y_spacing_mm=sy,camera_footprint_width_mm=fw,camera_footprint_height_mm=fh}})
if not ok(r,e)then toast("Scan create failed","error");return end
env("MP_SCAN50",S)
local xo,yo=g.x_offset_mm or 0,g.y_offset_mm or 0
local n=0
for y=0,ny-1 do for a=0,nx-1 do
 n=n+1
 local x=y%2==0 and a or nx-1-a
 move_absolute({x=g.x_grid_start_mm+x*sx,y=g.y_grid_start_mm+y*sy,z=g.z,safe_z=true})
 local p=get_xyz()
 local pass,img=pcall(take_photo_raw)
 if not pass or not img then send_message("error","Camera failed at cell "..n)else
  local b={scan_id=S,capture_id="cell-"..n,device_id=D,captured_at=utc(),position={x_mm=p.x,y_mm=p.y},camera_position={x_mm=p.x+xo,y_mm=p.y+yo},image_base64=base64.encode(img)}
  local sent=false
  for i=1,2 do r,e=post("/observations",b);if ok(r,e)then sent=true;break end;wait(1500)end
  if not sent then send_message("error","Upload failed: "..n)end
 end
end end
local done,link=false
for i=1,3 do
 r,e=post("/scans/"..S.."/finalize",{resolution_mm=50,interpolation_power=2})
 if ok(r,e)then done=true;link=json.decode(r.body).dashboard_url;break end
 wait(5000)
end
if done then
 env("MP_SCAN50","");toast("Moisture map complete","success")
 if link then send_message("info","Secure results: "..link)end
else toast("Finalization failed; scan saved","error")end
