-- Send a fresh secure link to the latest completed MoisturePilot scan.
local u="https://moisturepilot-farmbot-api-production.up.railway.app"
local d,k=env("MP_DEVICE_ID"),env("MP_DEVICE_KEY")
if not d or not k then
 local r,e=http({url=u.."/v1/farmbot/enroll",method="POST",headers={Authorization="Bearer "..auth_token()}})
 if e or not r or r.status~=201 then toast("Enrollment failed","error");return end
 local q=json.decode(r.body);d=q.device_id;k=q.device_key;env("MP_DEVICE_ID",d);env("MP_DEVICE_KEY",k)
end
local r,e=http({url=u.."/v1/farmbot/dashboard-link",method="POST",headers={
 ["X-Device-ID"]=d,["X-Device-Key"]=k}})
if e or not r or r.status<200 or r.status>=300 then
 toast("Dashboard unavailable","error");return
end
local link=json.decode(r.body).dashboard_url
send_message("info","Secure results: "..link)
toast("Dashboard link sent","success")
