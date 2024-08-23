all: bin/traefik-links

bin/traefik-links: src/main.cr

src/main.cr:
	shards build

format:
	crystal tool format src/*.cr
