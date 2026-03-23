#!/bin/bash
set -e

echo "Running database migrations..."
if [ -n "$POSTGRES_URL" ]; then
    python -c "
import re, pathlib
ini = pathlib.Path('alembic.ini')
text = ini.read_text()
text = re.sub(r'sqlalchemy\.url\s*=.*', 'sqlalchemy.url = $POSTGRES_URL'.replace('+asyncpg', '+psycopg').replace('+aiopg', '+psycopg'), text)
ini.write_text(text)
" 2>/dev/null && alembic upgrade head 2>&1 || echo "Migration skipped or failed (non-fatal)"
else
    echo "POSTGRES_URL not set — skipping migrations"
fi

# If arguments were passed, execute them (useful for dev mode or debugging)
# Otherwise, start supervisor to run the unified services.
if [ $# -gt 0 ]; then
    echo "Executing command: $@"
    exec "$@"
else
    echo "Starting supervisor..."
    exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
fi
