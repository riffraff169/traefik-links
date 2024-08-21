all: bin/traefik-links

bin/traefik-links:
	shards build

format:
	crystal tool format src/*.cr
