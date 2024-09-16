This is a program to get a list of http endpoints from traefik and create a simple list of links.

It queries traefik's /api/http/routers and gets all rules to get url information. The `jq` equivalent would be `jq '.[].rule'`.  You can test what it pulls by using the following cli call:

```
curl -H 'Host: traefik.example.com' https://<IP>/api/http/routers -k | jq '.[].rule'
```

My personal setup has a LetsEncrypt cert, but since I'm querying on the internal IP and the cert is for the external dns name, it doesn't match, and requires the `-k` (or `--insecure`).

It takes a yaml config file with some parameters. An example has been provided.
This connection is to `<endpoint>/api/http/routers`, with a host header of `host` if set.

* `endpoint`: Host to connect to
* `host`: If the hostname it responds on is different from endpoint, then add this Host header
* `verify_cert`: Whether to verify the cert or not; false for self-signed certs, only used with https scheme
* `scheme`: Which scheme to connect to traefik on, http or https
* `protocols`: Mapping of `using` method to connection scheme
* `prefer`: What protocol to prefer if more than one presented; currently ignored
* `refresh`: Whether to auto-refresh web page
* `refresh_interval`: How often to refresh page
* `bind_port`: Which port to listen on, default 8081
* `bind_ip`: Which interface/ip to listen on, default 127.0.0.1
* `new_window`: Whether to open links in new tab/window, or the same
* `filters`: List of filters for the api call to /api/http/routers; converts `rule` to something usable
* `template`: HTML template for displaying links
* `auth`: Whether to use basic auth or not, default = true
* `auth_type`: What type of auth, basic is only option for now, so basically ignored
* `auth_user`: What user to auth as
* `auth_pass`: What password to use

A dockerfile has been provided to create a docker image.  Just run make docker. Expose the port needed, or even integrate it with traefik with a docker-compose.yml or compose.yml) and map to the internal port used.

This is built with standard development mode.  It can be built with production mode by adding `--production`:

```
shards build --production
```

Release mode gives even more savings.  The binary is smaller by almost 3m.

However, since this isn't a very intensive program, so I don't think it would get you much.

Basic auth is supported. The data is in the config file. So remember to protect the config file the same way you would protect the data.

A docker-compose.yml file is provided.  You can add traefik-links to traefik itself by adding some labels. Of course you can modify it to add networks and other things if needed.
