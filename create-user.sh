#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="$(dirname "$0")/compose.yml"
API="http://localhost:3100/api/v1/users/register"

usage() {
  echo "Usage: $0 <name> <email> <password>"
  echo "  Example: $0 'John Doe' john@example.com secret123"
  exit 1
}

[[ $# -lt 3 ]] && usage

NAME="$1"
EMAIL="$2"
PASSWORD="$3"

enable_registration() {
  sed -i '' 's/HBOX_OPTIONS_ALLOW_REGISTRATION=false/HBOX_OPTIONS_ALLOW_REGISTRATION=true/' "$COMPOSE_FILE"
  docker compose -f "$COMPOSE_FILE" up -d --wait 2>/dev/null
  sleep 2
}

disable_registration() {
  sed -i '' 's/HBOX_OPTIONS_ALLOW_REGISTRATION=true/HBOX_OPTIONS_ALLOW_REGISTRATION=false/' "$COMPOSE_FILE"
  docker compose -f "$COMPOSE_FILE" up -d --wait 2>/dev/null
}

echo "Temporarily enabling registration..."
enable_registration

echo "Creating user '$NAME' ($EMAIL)..."
HTTP_CODE=$(curl -s -o /tmp/hbox_create_response -w "%{http_code}" -X POST "$API" \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"$NAME\", \"email\": \"$EMAIL\", \"password\": \"$PASSWORD\"}")
RESPONSE=$(cat /tmp/hbox_create_response)

echo "Disabling registration..."
disable_registration

if [[ "$HTTP_CODE" == "204" ]]; then
  # Record 1-year expiry
  EXPIRY=$(date -v +365d "+%Y-%m-%d" 2>/dev/null || date -d "+365 days" "+%Y-%m-%d")
  EXPIRY_FILE="$(dirname "$0")/users-expiry.txt"
  touch "$EXPIRY_FILE"
  echo "${EMAIL} ${EXPIRY}" >> "$EXPIRY_FILE"
  echo "Done. User '$EMAIL' created. Expires: $EXPIRY"
else
  echo "Failed to create user (HTTP $HTTP_CODE). Response: $RESPONSE"
  exit 1
fi
