FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends acme \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /programs
CMD ["sh", "scripts/build-machine-code.sh"]
