FROM ghcr.io/getzola/zola:v0.17.1 as zola

WORKDIR /zola-site
COPY . /var/www/zola
RUN ["zola", "build"]