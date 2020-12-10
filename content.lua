local json = require('cjson')
local http = require('resty.http')

ngx.req.read_body()
local req_body = ngx.req.get_body_data()

local body
if  req_body ~= nil then
    ngx.log(ngx.ERR,req_body)
    body = json.decode(req_body)
else
    ngx.say("failed to route, route not found")
end


-- route key
local app = body["app"]
-- route path
local action = body["path"]
-- route request info
local request = body["request"]

-- param: app key in redis,contains upstream info
local function selectUpstream(app)

    local routes = _G.routes[app]
    ngx.log(ngx.ERR,"routes cache: ",app,":",routes)
    -- decode upstream info
    local upstreams = json.decode(routes)


    -- get upstream list
    local instances = upstreams["upstreams"]


    -- random select a host
    local selected = math.floor(math.random() * #instances) + 1

    -- ngx.log(ngx.ERR,"protocol",upstreams["protocol"],"selected upstream",upstreams["upstreams"][selected])

    -- upstream url
    local url = upstreams["protocol"] .. "://" .. upstreams["upstreams"][selected]
    return url;
end

local url = selectUpstream(app)

if url ~= nil then
    -- route request to backend
    url = url .. "/" .. app .. action
    ngx.log(ngx.ALERT, "url=", url)
end

local function httpAgent(path, request)
    local httpc = http.new()
    local res, err = httpc:request_uri(url, {

        method = request["method"],
        query = request["params"],
        body = request["body"],
        headers = {
            ["Content-Type"] = "application/json;charset=UTF-8",
            ["Accept"] = "*/*",
            ["Accept-Encoding"] = "gzip, deflate, br"
        },
        keepalive_timeout = 60,
        keepalive_pool = 10

    })

    return res["body"]
end

local res = httpAgent(url,request)
ngx.say(res)