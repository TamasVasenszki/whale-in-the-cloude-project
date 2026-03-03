#!/bin/bash

SERVICE=$1

if [ -z "$SERVICE" ]; then
  echo "Usage: ./scripts/logs.sh <service-name>"
  exit 1
fi

# Check if service exists
if ! docker compose config --services | grep -q "^${SERVICE}$"; then
  echo "Service '$SERVICE' not found in docker-compose.yml"
  exit 1
fi

echo "Showing last 50 log lines for: $SERVICE"
docker compose logs "$SERVICE" --tail=50
