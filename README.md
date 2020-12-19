# water-gateway

## how-to set-up

### prerequisites

1.  openresty for route
2.  redis for routes storage 


###  Step 1: nginx.conf
add the following to `${open-resty-home}/nginx/conf/nginx.conf`,typically `${open-resty-home}=/usr/local/openresty`

```bash
location / {
        add_header 'Access-Control-Allow-Origin' $http_origin;
        add_header 'Access-Control-Allow-Credentials' 'true';
	    add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS';
	    add_header 'Access-Control-Allow-Headers' 'DNT,web-token,app-token,Authorization,Accept,Origin,Keep-Alive,User-Agent,X-Mx-ReqToken,X-Data-Type,X-Auth-Token,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range';
	    add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range';
            if ($request_method = 'OPTIONS') {
		add_header 'Access-Control-Max-Age' 1728000;
		add_header 'Content-Type' 'text/plain; charset=utf-8';
		add_header 'Content-Length' 0;
		return 204;
        }

            root   html;
            index  index.html index.htm;
            content_by_lua_file /usr/local/openresty/lualib/gateway/content.lua;
}
 
location ~ /route {
            default_type application/json;
            content_by_lua_file /usr/local/openresty/lualib/gateway/route/route-curd.lua ;
}   
```
###  Step 2: copy files

copy the whole repo into `${open-resty-home}/lualib/gateway`

make the nginx running like that

```bash
nginx -c /usr/local/openresty/nginx/conf/nginx.conf -s reload
```


### Step 3: add a route

gateway has 4 basic curd interface for route,document edited for later....

now, make a post HTTP request on `${ip}/route/add`,and body is as follows:

```json
{
  "app": "sample-app",
  "path": "/",
  "upstreams": [
    "192.168.10.1:8080",
    "192.168.10.1:8081",
    "192.168.10.1:8082",
    "192.168.10.1:8083"
  ],
  "protocol": "http",
  "lb": "round-robin",
  "health-check": {
    "mode": "active",
    "period": "10",
    "timeout": "1",
    "path": "/status"
  },
  "plugins": [
    {
      "plugin": "limit-count",
      "max_conn_num": "1000",
      "max_req_freq": "1000"
    }
  ],
  "access-control": {
    "allow": {
      "relation": "and",
      "roles": [],
      "apps": [],
      "ip_list": []
    },
    "forbidden": {
      "relation": "and",
      "roles": [],
      "ip_list": []
    }
  },
  "endpoints": [
    {
      "path": "/user/info",
      "method": "get"
    }
  ]
}
```
### Step 4: check the response and load-balance

for details API,reference doc [document API](/route-crud.adoc).

for example,running a spring-boot web application. expose endpoint at `/sample-app/create`,

```java
@SpringBootApplication
@RestController
@RequestMapping("sample-app")
public class DemoApplication {
    @Autowired
    Environment environment;

    public String getPort(){
        return environment.getProperty("local.server.port");
    }

    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }
    @GetMapping("/hello")
    public String hello(){
        String port=System.getenv("server.port");
        return "hello from"+getPort();
    }

    @PostMapping("/create")
    public Map<String, String> create(@RequestBody Map<String,String> maps,@RequestParam String hello,@RequestParam String world){
        maps.put("port",getPort());
        maps.put("hello",world);
        return maps;

    }
}


```

request the gateway like this

```bash
POST http://${gatewayip}
```
with request body

```json
{
    "app": "sample-app",
    "path": "/create",
    "request": {
        "method": "post",
        "body": "{\"app\":\"sample\",\"path\":\"/open/apps\"}",
        "header": "",
        "params": "hello=hello&world=world"
    }
}
```

you got response from upstream:

```json
{"app":"sample","path":"/open/apps","port":"8083","hello":"world"}
```
