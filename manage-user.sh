#!/usr/bin/env bash
set -euo pipefail

EXPIRY_FILE="$(dirname "$0")/users-expiry.txt"
VOLUME="mrzlzrd_homebox_homebox-data"
CONTAINER="mrzlzrd_homebox-homebox-1"

usage() {
  echo "Usage:"
  echo "  $0 expire <email>              Lock account now"
  echo "  $0 extend <email> [days]       Extend account (default: 365 days) + print reset link"
  echo "  $0 status                      List all tracked users and their expiry"
  echo "  $0 check                       Lock any accounts past their expiry date"
  exit 1
}

[[ $# -lt 1 ]] && usage

sqlite_exec() {
  docker run --rm -v "$VOLUME:/data" alpine sh -c \
    "apk add -q sqlite 2>/dev/null && sqlite3 /data/homebox.db \"$1\""
}

lock_account() {
  local email="$1"
  sqlite_exec "UPDATE users SET password = 'LOCKED' WHERE email = '${email}'"
  # Also invalidate all active sessions
  sqlite_exec "DELETE FROM auth_tokens WHERE user_auth_tokens = (SELECT id FROM users WHERE email = '${email}')"
  echo "Locked: $email"
}

reset_link() {
  local email="$1"
  docker exec "$CONTAINER" /app/api reset-password --email="$email" 2>/dev/null
}

set_expiry() {
  local email="$1"
  local days="${2:-365}"
  local expiry
  expiry=$(date -v "+${days}d" "+%Y-%m-%d" 2>/dev/null || date -d "+${days} days" "+%Y-%m-%d")

  # Update or insert in expiry file
  touch "$EXPIRY_FILE"
  if grep -q "^${email} " "$EXPIRY_FILE"; then
    sed -i '' "s|^${email} .*|${email} ${expiry}|" "$EXPIRY_FILE"
  else
    echo "${email} ${expiry}" >> "$EXPIRY_FILE"
  fi
  echo "$expiry"
}

get_expiry() {
  local email="$1"
  touch "$EXPIRY_FILE"
  grep "^${email} " "$EXPIRY_FILE" | awk '{print $2}' || echo "none"
}

case "$1" in
  expire)
    [[ $# -lt 2 ]] && usage
    lock_account "$2"
    ;;

  extend)
    [[ $# -lt 2 ]] && usage
    EMAIL="$2"
    DAYS="${3:-365}"
    EXPIRY=$(set_expiry "$EMAIL" "$DAYS")
    echo "Expiry set to: $EXPIRY"
    echo "Generating password reset link..."
    LINK=$(reset_link "$EMAIL")
    echo "Reset link (expires in 1 hour): $LINK"
    echo "Send this link to the user to let them set a new password."
    ;;

  status)
    touch "$EXPIRY_FILE"
    TODAY=$(date "+%Y-%m-%d")
    printf "%-35s %-12s %s\n" "EMAIL" "EXPIRY" "STATE"
    printf "%-35s %-12s %s\n" "-----" "------" "-----"
    while read -r email expiry; do
      if [[ "$expiry" < "$TODAY" ]]; then
        state="EXPIRED"
      else
        state="active"
      fi
      printf "%-35s %-12s %s\n" "$email" "$expiry" "$state"
    done < "$EXPIRY_FILE"
    ;;

  check)
    touch "$EXPIRY_FILE"
    TODAY=$(date "+%Y-%m-%d")
    while read -r email expiry; do
      if [[ "$expiry" < "$TODAY" ]]; then
        echo "Expiring: $email (expired $expiry)"
        lock_account "$email"
      fi
    done < "$EXPIRY_FILE"
    echo "Check complete."
    ;;

  *)
    usage
    ;;
esac
