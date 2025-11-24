# Stage 1: Clone repositories
FROM alpine:latest AS cloner

# Install git
RUN apk add --no-cache git

# Clone the zola-site repo with all submodules (includes theme)
RUN git clone --recurse-submodules https://github.com/Smavl/zola-site.git /zola-site

# Clone BackdoorBag project
RUN git clone https://github.com/Smavl/BackdoorBag /backdoorbag

# Stage 2: Build with Zola using the official image
FROM ghcr.io/getzola/zola:v0.20.0 AS builder

# Copy the cloned site from previous stage
COPY --from=cloner /zola-site/page /site

# Build using Zola (the image has zola as entrypoint)
WORKDIR /site
RUN ["/bin/zola", "build", "--base-url", "https://smavl.rocks"]

# Stage 3: Production - Caddy server
FROM caddy:2.8-alpine

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
    CMD wget --spider -q http://localhost:80 || exit 1
