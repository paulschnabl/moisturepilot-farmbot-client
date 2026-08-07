local U="https://moisturepilot-farmbot-api-production.up.railway.app/v1/farmbot"
local D,K=env("MP_DEVICE_ID"),env("MP_DEVICE_KEY")
local A,B="MP_GRID_SCAN","MP_GRID_CELL"
local function L(t,s)send_message(t,"MP "..s)end
local function F(s)L("error",s);toast("MP failed","error")end
if not D or D==""or not K or K==""then F("no credentials");return end
local H={["Content-Type"]="application/json",["X-Device-ID"]=D,["X-Device-Key"]=K}
local function Q(p,b)return http({url=U..p,method=b and"POST"or"GET",headers=H,body=b and json.encode(b)})end
local function O(r,e)return not e and r and r.status>=200 and r.status<300 end
local function X(s,r,e)F(s..": "..(r and(r.status.." "..(r.body or""))or inspect(e)))end
local g=photo_grid()
local fw,fh=g.x_spacing_mm+5,g.y_spacing_mm+5
local rx,ry=(g.x_grid_points-1)*g.x_spacing_mm,(g.y_grid_points-1)*g.y_spacing_mm
local nx,ny=math.max(1,math.ceil(2*rx/fw)+1),math.max(1,math.ceil(2*ry/fh)+1)
local sx,sy=nx>1 and rx/(nx-1)or 0,ny>1 and ry/(ny-1)or 0
local N,S,C=nx*ny,env(A),tonumber(env(B))or 1
local r,e
if S and S~=""then
r,e=Q("/scans/"..S)
if not O(r,e)then X("resume check",r,e);return end
if json.decode(r.body).status=="finalized"then
env(A,"");env(B,"");S=nil;C=1
end
end
if not S or S==""then
S=D.."-50-"..utc();local z=garden_size()
r,e=Q("/scans",{scan_id=S,device_id=D,model_size="10cm",garden_width_mm=z.x,garden_height_mm=z.y,metadata={cells=N,x_spacing_mm=sx,y_spacing_mm=sy,camera_footprint_width_mm=fw,camera_footprint_height_mm=fh}})
if not O(r,e)then X("scan create",r,e);return end
env(A,S);env(B,1);C=1
end
local ox,oy,Z=g.x_offset_mm or 0,g.y_offset_mm or 0,g.z
for n=C,N do
local y,a=math.floor((n-1)/nx),(n-1)%nx
local x=y%2==0 and a or nx-1-a
local px,py=g.x_grid_start_mm+x*sx,g.y_grid_start_mm+y*sy
move{x=px,y=py,z=Z}
local im=take_photo_raw()
if not im then F("camera failed at cell "..n);return end
local b={scan_id=S,capture_id="cell-"..n,device_id=D,captured_at=utc(),position={x_mm=px,y_mm=py,z_mm=Z},camera_position={x_mm=px+ox,y_mm=py+oy,z_mm=Z},image_base64=base64.encode(im)}
local ok=false
for i=1,3 do r,e=Q("/observations",b);if O(r,e)then ok=true;break end;wait(5000)end
if not ok then X("upload cell "..n,r,e);return end
env(B,n+1);set_job("MP",{percent=100*n/N})
end
r,e=Q("/scans/"..S)
if not O(r,e)then X("count check",r,e);return end
local got=json.decode(r.body).observation_count or 0
if got<N then env(B,1);F("server has "..got.."/"..N.." photos; run again");return end
r,e=Q("/scans/"..S.."/finalize",{resolution_mm=50,interpolation_power=2})
local done,link=O(r,e),nil
if done then link=json.decode(r.body).dashboard_url else
for i=1,3 do
wait(7000);r,e=Q("/scans/"..S)
if O(r,e)and json.decode(r.body).status=="finalized"then
r,e=Q("/dashboard-link",{})
if O(r,e)then done=true;link=json.decode(r.body).dashboard_url end
break
end
end
end
if not done then X("finalization failed; run again",r,e);return end
env(A,"");env(B,"");complete_job("MP")
if link then L("info","Secure results: "..link)end
