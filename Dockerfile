# Stage 1: Clone and build
FROM alpine:latest AS builder

# Install git and dependencies for Zola
RUN apk add --no-cache git curl

# Download and install Zola
RUN curl -sL https://github.com/getzola/zola/releases/download/v0.20.0/zola-v0.20.0-x86_64-unknown-linux-musl.tar.gz | tar xz -C /usr/local/bin

# Clone the zola-site repo with all submodules (includes theme)
RUN git clone --recurse-submodules https://github.com/Smavl/zola-site.git /zola-site

# Build the static site
WORKDIR /zola-site/page
RUN zola build --base-url "https://smavl.rocks"

# Clone BackdoorBag project
RUN git clone https://github.com/Smavl/BackdoorBag /backdoorbag

# Stage 2: Production - Caddy server
FROM caddy:2.8-alpine

# Copy BackdoorBag from builder stage
COPY --from=builder /backdoorbag /var/www/projects/backdoorbag

# Copy built site from builder stage
COPY --from=builder /zola-site/page/public /var/www/zola/public

# Copy Caddy configuration
COPY Caddyfile /etc/caddy/Caddyfile

# Expose HTTP and HTTPS ports
EXPOSE 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD wget --spider -q http://localhost:80 || exit 1
