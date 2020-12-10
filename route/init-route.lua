local json = require('cjson')

local function fetch()
    local routes = _G.routes

    -- setup routes cache if empty
    if routes == nil then
        routes = {}
        ngx.log(ngx.ALERT, "Route cache is empty.")
    end

    -- try cached route first

    local redis = require "resty.redis"
    local red = redis:new()

    red:set_timeouts(1000, 1000, 1000)
    local ok, err = red:connect("127.0.0.1", 6379)
    if not ok then
        ngx.log(ngx.ERR, "failed to connect redis: ", err)
        return
    end

    -- redis set is a table in lua
    local route_keys, err = red:smembers("routes")
    if not route_keys then
        ngx.log(ngx.ERR, "failed to get routes table: ", err)
        return
    end

    -- for each member in routes,k is index 1,2.., v is element in set
    for k, v in pairs(route_keys) do
        -- for each element get the related upstreams info,key's value is a string
        local upstream, err = red:get(v)

        if not upstream or upstream == ngx.null then
            ngx.log(ngx.ERR, "failed to get route: ", v, " key not found or err:", err)
        else
            routes[v] = upstream
            ngx.log(ngx.ALERT, "load upstream ", v, " info", " content:", upstream)
        end
    end
    _G.routes_keys = route_keys
    _G.routes = routes
end

local ok, err = ngx.timer.at(0, fetch)
if not ok then
    ngx.log(ngx.ERR, "failed to create timer: ", err)
    return
end
