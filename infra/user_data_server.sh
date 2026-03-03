#!/bin/bash
set -euxo pipefail

APP_IMAGE="${APP_IMAGE}"

dnf update -y

# Install Docker
dnf install -y docker
systemctl enable docker
systemctl start docker

# Install docker compose plugin (works on AL2023)
dnf install -y docker-compose-plugin

# Prepare app directory
mkdir -p /opt/whale
cd /opt/whale

# Write docker-compose.aws.yml
cat > docker-compose.aws.yml <<'YAML'
services:
  nginx:
    image: nginx:1.27-alpine
    ports:
      - "8080:80"
    volumes:
      - ./files:/usr/share/nginx/html:ro
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - api1
      - api2
    networks:
      - public_net

  api1:
    image: ${APP_IMAGE}
    environment:
      - INSTANCE_NAME=api1
      - DB_HOST=
      - DB_PORT=
      - DB_USER=
      - DB_PASSWORD=
      - DB_NAME=
    networks:
      - public_net
      - internal_net

  api2:
    image: ${APP_IMAGE}
    environment:
      - INSTANCE_NAME=api2
      - DB_HOST=
      - DB_PORT=
      - DB_USER=
      - DB_PASSWORD=
      - DB_NAME=
    networks:
      - public_net
      - internal_net

networks:
  public_net:
  internal_net:
    internal: true
YAML

# Write nginx config
mkdir -p nginx
cat > nginx/default.conf <<'NGINX'
upstream backend {
    server api1:3000;
    server api2:3000;
}

server {
    listen 80;

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }

    location /api/ {
        proxy_pass http://backend/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
NGINX

# Write static file
mkdir -p files
cat > files/index.html <<'HTML'
<!doctype html>
<html>
  <head><meta charset="utf-8"><title>Whale in the Cloud</title></head>
  <body>
    <h1>Whale in the Cloud</h1>
    <p>Try <code>/api/health</code></p>
  </body>
</html>
HTML

# Create .env for compose (no secrets)
cat > .env <<EOF
ECR_APP_IMAGE=${APP_IMAGE}
EOF

# Pull & run
docker compose --env-file .env -f docker-compose.aws.yml pull
docker compose --env-file .env -f docker-compose.aws.yml up -d