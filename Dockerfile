FROM ghcr.io/getzola/zola:v0.20.0 AS zola

COPY ./zola-site/page /var/www/zola
WORKDIR /var/www/zola
RUN ["zola", "--root", "/var/www/zola", "build", "--base-url", "http://localhost"]
