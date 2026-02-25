#!/bin/bash
set -e

echo "=== Running local-stack database init ==="

# 1. Create roles
echo "Creating roles..."
for f in /migrations/00_init/*.sql; do
    [ -f "$f" ] && echo "  Applying: $(basename $f)" && psql -U postgres -d pattern_db -f "$f"
done

echo "=== Database init complete. Schema will be managed by Alembic. ==="