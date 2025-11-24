"""Simple Alembic wrapper for project migrations.

Usage:
  python scripts/migrate.py revision -m "message"
  python scripts/migrate.py upgrade head

This script sets the ALEMBIC config's sqlalchemy.url from POSTGRES_URL env var or
from src.core.settings_v2.POSTGRES_URL if available, then delegates to alembic.command.
"""
import os
import sys
from alembic.config import Config
from alembic import command

ALEMBIC_INI = os.path.join(os.path.dirname(__file__), '..', 'alembic.ini')


def main(argv):
    if not os.path.exists(ALEMBIC_INI):
        print('alembic.ini not found')
        sys.exit(1)

    cfg = Config(ALEMBIC_INI)

    # Determine DB URL
    url = os.getenv('POSTGRES_URL')
    if not url:
        try:
            sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'src')))
            from src.core.settings_v2 import settings_v2
            url = getattr(settings_v2, 'POSTGRES_URL', None)
        except Exception:
            url = None

    if not url:
        print('POSTGRES_URL environment variable not set and settings_v2.POSTGRES_URL not found')
        sys.exit(1)

    cfg.set_main_option('sqlalchemy.url', url)

    if len(argv) < 1:
        print('Usage: migrate.py <alembic-command> [args...]')
        sys.exit(1)

    cmd = argv[0]
    args = argv[1:]

    if cmd == 'revision':
        message = ' '.join(args) if args else 'migration'
        command.revision(cfg, message=message, autogenerate=True)
    elif cmd == 'upgrade':
        target = args[0] if args else 'head'
        command.upgrade(cfg, target)
    elif cmd == 'downgrade':
        target = args[0] if args else '-1'
        command.downgrade(cfg, target)
    else:
        print('Unsupported alembic wrapper command:', cmd)
        sys.exit(2)


if __name__ == '__main__':
    main(sys.argv[1:])
