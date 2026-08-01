-- Capture and analyze the FarmBot camera at its current X/Y/Z position.
local url = "https://moisturepilot-farmbot-api.onrender.com"
local device, key = env("MP_DEVICE_ID"), env("MP_DEVICE_KEY")
local model = "10cm"
if not device or not key then
  local r,e=http({url=url.."/v1/farmbot/enroll",method="POST",headers={Authorization="Bearer "..auth_token()}})
  if e or not r or r.status~=201 then toast("Enrollment failed","error");return end
  local q=json.decode(r.body);device=q.device_id;key=q.device_key
  env("MP_DEVICE_ID",device);env("MP_DEVICE_KEY",key)
end
local scan = env("MP_POINT_SCAN")
local headers = { ["Content-Type"]="application/json", ["X-Device-ID"]=device, ["X-Device-Key"]=key }
if not scan or scan == "" then
  scan = device .. "-points-" .. utc()
  local r, e = http({url=url .. "/v1/farmbot/scans", method="POST", headers=headers,
    body=json.encode({scan_id=scan, device_id=device, model_size=model})})
  if e or not r or r.status < 200 or r.status >= 300 then
    toast("Could not create scan", "error"); return
  end
  env("MP_POINT_SCAN", scan)
end
local p = get_xyz()
local ok, photo = pcall(take_photo_raw)
if not ok or not photo then toast("Camera capture failed", "error"); return end
local capture = "point-" .. utc()
local response, err = http({url=url .. "/v1/farmbot/observations", method="POST", headers=headers,
  body=json.encode({scan_id=scan, capture_id=capture, device_id=device, captured_at=utc(),
    position={x_mm=p.x, y_mm=p.y, z_mm=p.z}, model_size=model,
    image_base64=base64.encode(photo), metadata={source="current_position"}})})
if err or not response or response.status < 200 or response.status >= 300 then
  toast("MoisturePilot upload failed", "error")
else
  local result = json.decode(response.body)
  toast("Estimated moisture: " .. result.moisture_rounded .. "%", "success")
end
