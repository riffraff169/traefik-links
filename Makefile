all: bin/traefik-links

bin/traefik-links: src/main.cr src/config.cr src/router.cr
	shards build

format:
	crystal tool format src/*.cr

docker:
	docker build -t traefik-links .
