#!/bin/sh
set -e

# Wait for Postgres to be ready (Python-based check)
python - <<PY
import os, time, socket, sys
host = os.environ.get("DB_HOST", "db")
port = int(os.environ.get("DB_PORT", 5432))
for i in range(60):
    try:
        s = socket.create_connection((host, port), timeout=5)
        s.close()
        break
    except Exception:
        time.sleep(1)
else:
    sys.exit("Database not available, exiting")
PY

# Ensure downloads directory exists
mkdir -p /app/downloads

# Run migrations
python manage.py migrate --noinput

# Execute the container CMD
exec "$@"
