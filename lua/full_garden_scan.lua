local u="https://moisturepilot-farmbot-api.onrender.com"
for a=1,18 do local r=http({url=u.."/health"});if r and r.status==200 then break end;wait(5000)end
local d,k=env("MP_DEVICE_ID"),env("MP_DEVICE_KEY")
if not d or not k then
 local r,e=http({url=u.."/v1/farmbot/enroll",method="POST",headers={Authorization="Bearer "..auth_token()}})
 if e or not r or r.status~=201 then toast("Enrollment failed","error");return end
 local q=json.decode(r.body);d=q.device_id;k=q.device_key;env("MP_DEVICE_ID",d);env("MP_DEVICE_KEY",k)
end
local g=photo_grid()
local fw,fh=g.x_spacing_mm+5,g.y_spacing_mm+5
local rx,ry=(g.x_grid_points-1)*g.x_spacing_mm,(g.y_grid_points-1)*g.y_spacing_mm
local nx,ny=math.max(1,math.ceil(rx/(fw/2))+1),math.max(1,math.ceil(ry/(fh/2))+1)
local sx,sy=nx>1 and rx/(nx-1)or 0,ny>1 and ry/(ny-1)or 0
local s=env("MP_SCAN50")
local h={["Content-Type"]="application/json",["X-Device-ID"]=d,["X-Device-Key"]=k}
if not s or s==""then s=d.."-50-"..utc()end
local z=garden_size()
local r,e=http({url=u.."/v1/farmbot/scans",method="POST",headers=h,body=json.encode({scan_id=s,
 device_id=d,garden_width_mm=z.x,garden_height_mm=z.y,metadata={cells=nx*ny,photo_overlap_percent=50,x_spacing_mm=sx,y_spacing_mm=sy,
 camera_footprint_width_mm=fw,camera_footprint_height_mm=fh}})})
if e or not r or r.status<200 or r.status>=300 then toast("Scan create failed","error");return end
env("MP_SCAN50",s)
local xo,yo=g.x_offset_mm or 0,g.y_offset_mm or 0
local n=0
for y=0,ny-1 do for a=0,nx-1 do
 n=n+1
 local x=y%2==0 and a or nx-1-a
 move_absolute({x=g.x_grid_start_mm+x*sx,y=g.y_grid_start_mm+y*sy,z=g.z,safe_z=true})
 local p=get_xyz()
 local ok,img=pcall(take_photo_raw)
 if not ok or not img then send_message("error","Camera failed at cell "..n)else
  local b=json.encode({scan_id=s,capture_id="cell-"..n,device_id=d,captured_at=utc(),
   position={x_mm=p.x,y_mm=p.y},camera_position={x_mm=p.x+xo,y_mm=p.y+yo},
   image_base64=base64.encode(img)})
  local sent=false
  for q=1,2 do
   local r,e=http({url=u.."/v1/farmbot/observations",method="POST",headers=h,body=b})
   if not e and r and r.status>=200 and r.status<300 then sent=true;break end
   wait(1500)
  end
  if not sent then send_message("error","Upload failed: "..n)end
 end
end end
local done,link=false,nil
for a=1,3 do
 local r,e=http({url=u.."/v1/farmbot/scans/"..s.."/finalize",method="POST",headers=h,
  body=json.encode({resolution_mm=50,interpolation_power=2})})
 if not e and r and r.status>=200 and r.status<300 then
  done=true;link=json.decode(r.body).dashboard_url;break
 end
 wait(5000)
end
if done then
 env("MP_SCAN50","")
 toast("Moisture map complete","success")
 if link then send_message("info","Secure results: "..link)end
else
 toast("Finalization failed; scan saved","error")
end
