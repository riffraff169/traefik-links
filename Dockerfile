FROM crystallang/crystal
WORKDIR /src
RUN mkdir /src/src
COPY src/* /src/src
COPY shard.yml /src
RUN shards build

FROM crystallang/crystal
COPY --from=0 /src/bin/traefik-links /usr/local/bin
WORKDIR /traefik-links
RUN mkdir -p /traefik-links/assets /traefik-links/templates
COPY examples/config.yml /traefik-links
COPY assets/* /traefik-links/assets
COPY templates/* /traefik-links/templates
CMD ["/usr/local/bin/traefik-links", "-c", "config.yml"]
