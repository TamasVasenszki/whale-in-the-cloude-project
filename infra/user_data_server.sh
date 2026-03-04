#!/bin/bash
set -euxo pipefail

APP_IMAGE="${APP_IMAGE}"

retry() {
  local n=0
  until [ $n -ge 5 ]; do
    "$@" && break
    n=$((n+1))
    sleep 5
  done
  if [ $n -ge 5 ]; then
    echo "Command failed after retries: $*" >&2
    exit 1
  fi
}

retry dnf update -y

# Install & start Docker
retry dnf install -y docker
systemctl enable docker
systemctl start docker

# Allow ec2-user to run docker without sudo (useful for demo/debug)
usermod -aG docker ec2-user || true

# Install Docker Compose v2 as a Docker CLI plugin (repo-independent)
mkdir -p /usr/local/lib/docker/cli-plugins
retry curl -L "https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Sanity check: must exist
docker compose version

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
APP_IMAGE=${APP_IMAGE}
EOF

# --- ECR login so docker can pull private images ---
AWS_REGION="eu-central-1"
ECR_REGISTRY="554422868760.dkr.ecr.eu-central-1.amazonaws.com"

# aws cli might not be present on this AMI
if ! command -v aws >/dev/null 2>&1; then
  retry dnf install -y awscli
fi

aws ecr get-login-password --region eu-central-1 \
  | docker login --username AWS --password-stdin 554422868760.dkr.ecr.eu-central-1.amazonaws.com

# Pull & run (use sudo to avoid any socket permission edge cases)
sudo docker compose --env-file .env -f docker-compose.aws.yml pull
sudo docker compose --env-file .env -f docker-compose.aws.yml up -d