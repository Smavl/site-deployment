# Multi-stage build for Zola static site
FROM ghcr.io/getzola/zola:v0.20.0 AS builder

# Install git to clone repositories
RUN apk add --no-cache git

# Clone the zola-site repo with all submodules (includes theme)
RUN git clone --recurse-submodules https://github.com/Smavl/zola-site.git /zola-site

# Build the static site
WORKDIR /zola-site/page
RUN zola build --base-url "https://smavl.rocks"

# Production stage - lightweight Caddy server
FROM caddy:2.8-alpine

# Install git for cloning BackdoorBag
RUN apk add --no-cache git

# Clone BackdoorBag project
RUN git clone https://github.com/Smavl/BackdoorBag /var/www/projects/backdoorbag

# Copy built site from builder stage
COPY --from=builder /zola-site/page/public /var/www/zola/public

# Copy Caddy configuration
COPY Caddyfile /etc/caddy/Caddyfile

# Expose HTTP and HTTPS ports
EXPOSE 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD wget --spider -q http://localhost:80 || exit 1
