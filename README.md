This is a program to get a list of http endpoints from traefik and create a simple link of lists with them.

It queries traefik's /api/http/routers and gets all rules to get url information. The `jq` equivalent would be `jq '.[].rule'`.  You can test what it pulls by using the following cli call:

```
curl -H 'Host: traefik.example.com' https://<IP>/api/http/routers -k | jq '.[].rule'
```

My personal setup has a LetsEncrypt cert, but since I'm querying on the internal IP and the cert is for the external dns name, it doesn't match, and requires the `-k` (or `--insecure`).

It takes a yaml config file with some parameters. An example has been provided.

* `url`: Traefik's api@internal URL
* `host`: If the hostname it responds on is different from url, then add this Host header
* `template`: HTML template for displaying links
* `filters`: List of filters for the api call to /api/http/routers

