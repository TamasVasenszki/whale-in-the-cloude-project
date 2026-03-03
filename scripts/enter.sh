#!/bin/bash

SERVICE=$1

if [ -z "$SERVICE" ]; then
  echo "Usage: ./scripts/enter.sh <service-name>"
  exit 1
fi

# Check if service exists
if ! docker compose config --services | grep -q "^${SERVICE}$"; then
  echo "Service '$SERVICE' not found in docker-compose.yml"
  exit 1
fi

echo "Entering container: $SERVICE"
docker compose exec "$SERVICE" sh
