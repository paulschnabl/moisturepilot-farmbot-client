local U="https://moisturepilot-farmbot-api-production.up.railway.app/v1/farmbot"
local D,K=env("MP_DEVICE_ID"),env("MP_DEVICE_KEY")
local function L(t,s)send_message(t,"MP "..s)end
local function F(s)L("error",s);toast("MoisturePilot failed","error")end
if not D or D==""or not K or K==""then F("credentials missing");return end
local H={["Content-Type"]="application/json",["X-Device-ID"]=D,["X-Device-Key"]=K}
local function P(p,b)return http({url=U..p,method="POST",headers=H,body=json.encode(b)})end

local grid=photo_grid()
job="Photo Grid"
local S=env("MP_GRID_SCAN")
if not S or S==""then
 S=D.."-grid-"..utc()
 local z=garden_size()
 local r,e=P("/scans",{scan_id=S,device_id=D,model_size="10cm",garden_width_mm=z.x,garden_height_mm=z.y,metadata={grid_strategy="farmbot_photo_grid",cells=grid.total,photo_overlap_mm=5,x_spacing_mm=grid.x_spacing_mm,y_spacing_mm=grid.y_spacing_mm,camera_footprint_width_mm=grid.x_spacing_mm+5,camera_footprint_height_mm=grid.y_spacing_mm+5}})
 if e or not r or r.status<200 or r.status>=300 then F("scan create failed");return end
 env("MP_GRID_SCAN",S);env("MP_GRID_CELL",1)
end
env("MP_GRID_ERROR","")

grid.each(function(cell)
    if env("MP_GRID_ERROR")=="1"or cell.count<(tonumber(env("MP_GRID_CELL"))or 1)then return end
    set_job(job,{
        percent=100*(cell.count-0.5)/grid.total,
        status="Moving"
    })
    move{x=cell.x,y=cell.y,z=cell.z}
    set_job(job,{
        percent=100*(cell.count/grid.total),
        status="Taking photo"
    })
    local msg="Taking photo "..cell.count.." of "..grid.total
    send_message("info",msg)
    local img=take_photo_raw()
    if not img then env("MP_GRID_ERROR","1");F("camera failed at cell "..cell.count);return end
    local b={scan_id=S,capture_id="cell-"..cell.count,device_id=D,captured_at=utc(),position={x_mm=cell.x,y_mm=cell.y,z_mm=cell.z},camera_position={x_mm=cell.x+grid.x_offset_mm,y_mm=cell.y+grid.y_offset_mm,z_mm=cell.z},image_base64=base64.encode(img)}
    local sent=false
    for i=1,2 do
        local r,e=P("/observations",b)
        if not e and r and r.status>=200 and r.status<300 then sent=true;break end
        wait(1500)
    end
    if not sent then env("MP_GRID_ERROR","1");F("upload failed at cell "..cell.count);return end
    env("MP_GRID_CELL",cell.count+1)
end)

if env("MP_GRID_ERROR")=="1"then F("run again to resume");return end
local done,link=false
for i=1,3 do
 local r,e=P("/scans/"..S.."/finalize",{resolution_mm=50,interpolation_power=2})
 if not e and r and r.status>=200 and r.status<300 then done=true;link=json.decode(r.body).dashboard_url;break end
 wait(5000)
end
if not done then F("finalization failed; run again");return end
env("MP_GRID_SCAN","");env("MP_GRID_CELL","");complete_job(job)
toast("Moisture map complete","success")
if link then L("info","Secure results: "..link)end
