#!/usr/bin/env sh

set -eu

# Read the password from the password file
PASSWORD=$(cat "${REDIS_PASSWORD_FILE}")

# Forward to the entrypoint script from the official redis image
exec docker-entrypoint.sh redis-server --requirepass "${PASSWORD}"
