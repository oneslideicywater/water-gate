local json = require('cjson')
local http = require "resty.http"
local redis = require "resty.redis"
local red = redis:new()

red:set_timeouts(1000, 1000, 1000)
local ok, err = red:connect("127.0.0.1", 6379)
if not ok then
    ngx.log(ngx.ERR, "failed to connect redis: ", err)
    return
end

local uri = ngx.var.request_uri

local action = ""
if uri == "/route/add" then
    action = "create"
elseif uri == "/route/delete" then
    action = "delete"
elseif uri == "/route/full-reload" then
    action = "full-reload"
elseif uri == "/route/increment-reload" then
    action = "increment-reload"
elseif uri == "/route/query" then
    action = "query"
else
    ngx.log(ngx.ERR, "wrong action on route", action)
    return
end




local function add_route(key, route)
    -- todo: transaction needed here
    ngx.log(ngx.ALERT, "add route: ", key)
    local ok, err = red:sadd("routes", key)
    if not ok then
        ngx.log(ngx.ERR, "failed to add", key, " to routes table: ", err)
        ngx.say("failed")
        return
    end
    local ok, err = red:set(key, route)
    if not ok then
        ngx.log(ngx.ERR, "failed to add", key, " to routes table: ", err)
        ngx.say("failed")
        return
    end
    ngx.say("success")
end


local function delete_route(key)
    -- todo: transaction needed here
    ngx.log(ngx.ALERT, "delete route: ", key)
    local ok, err = red:srem("routes", key)
    if not ok then
        ngx.log(ngx.ERR, "failed to delete", key, " to routes table: ", err)
        ngx.say("failed")
        return
    end
    local ok, err = red:del(key)
    if not ok then
        ngx.log(ngx.ERR, "failed to delete", key, " to routes table: ", err)
        ngx.say("failed")
        return
    end
    ngx.say("success")
end

-- [[
-- route_full_reload action reload full routes table from redis,and update global route table in lua VM
-- it's actually a make a local copy of route table,finally make a re-reference to point to local copy.
-- old table is recycle by GC after then.
-- ]]
local function route_full_reload()
    -- redis set is a table in lua
    local routes = {}
    local route_keys, err = red:smembers("routes")
    if not route_keys then
        ngx.log(ngx.ERR, "failed to get routes table: ", err)
        ngx.say("failed")
        return
    end

    -- for each member in routes,k is index 1,2.., v is element in set
    for k, v in pairs(route_keys) do
        -- for each element get the related upstreams info
        local upstream, err = red:get(v)

        if not upstream or upstream == ngx.null then
            ngx.log(ngx.ERR, "failed to get route: ", v, " key not found or err:", err)
            ngx.say("failed")
        else
            routes[v] = upstream
            ngx.log(ngx.ALERT, "load upstream ", v, " info", " content:", upstream)
        end
    end
    _G.routes_keys = route_keys
    _G.routes = routes
    ngx.say("success")
end

-- [[
--   query route table already taking effect
-- ]]
local function query()
    local rsp;
    local routes = _G.routes
    local route_list = {} -- new array

    for k, v in pairs(routes) do
        route_list[k]=json.decode(v)
    end
    rsp = json.encode(route_list)
    ngx.say(rsp)
end



ngx.req.read_body()

local req_body = ngx.req.get_body_data()
-- req body
local body
if  req_body ~= nil then
    ngx.log(ngx.ERR,req_body)
    body = json.decode(req_body)
end


if action == "create" then
    local app = body["app"]
    add_route(app, req_body)
    -- refresh local cache
    _G.routes[app]=req_body

elseif action == "delete" then
    -- batch delete route
    for k, v in pairs(body) do
        delete_route(v)
        -- refresh local cache
        _G.routes[v] = nil
    end
elseif action == "full-reload" then
    -- full reload info from redis
    route_full_reload()
elseif action == "query" then
    query()
end


