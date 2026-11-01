# Base images are pinned by immutable digest (supply-chain hardening): a tag can
# be silently repointed, a digest cannot, and Docker verifies content on pull.
# Refresh a digest when bumping a version:
#   tok=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/<repo>:pull" | jq -r .token)
#   curl -sI -H "Authorization: Bearer $tok" -H "Accept: application/vnd.oci.image.index.v1+json" \
#     https://registry-1.docker.io/v2/library/<repo>/manifests/<tag> | grep -i docker-content-digest

# Stage 1: Clone repositories
# alpine 3.24
FROM alpine:3.24@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a AS cloner

# Install git
RUN apk add --no-cache git

# Clone the zola-site repo with all submodules (includes theme)
RUN git clone --recurse-submodules https://github.com/Smavl/zola-site.git /zola-site

# Clone BackdoorBag project
RUN git clone https://github.com/Smavl/BackdoorBag /backdoorbag

# Stage 2: Build with Zola using the official image
# zola v0.23.4
FROM ghcr.io/getzola/zola:v0.23.4@sha256:b1b5cbf8abe8c5da983372d1baaeb87a5fbe231fc8cf35dbefeb778d301ba237 AS builder

# Copy the cloned site from previous stage
COPY --from=cloner /zola-site/page /site

# Build using Zola (the image has zola as entrypoint)
WORKDIR /site
RUN ["/zola", "build", "--base-url", "https://smavl.rocks"]

# Stage 3: Production - Caddy server
# caddy 2.11.7-alpine
FROM caddy:2.11.7-alpine@sha256:e70b164da81ef698b3ad19af799ea6086ce6d9e48ed4079eb9fe26f6fbf14ee5

# Copy BackdoorBag from cloner stage
COPY --from=cloner /backdoorbag /var/www/projects/backdoorbag

# Copy built site from builder stage
COPY --from=builder /site/public /var/www/zola/public

# Copy Caddy configuration
COPY Caddyfile /etc/caddy/Caddyfile

# Expose HTTP and HTTPS ports
EXPOSE 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD wget --spider -q http://localhost/health || exit 1
