#!/bin/bash
set -e

echo "=== Running local-stack database init ==="

# 1. Create roles
echo "Creating roles..."
for f in /migrations/00_init/*.sql; do
    [ -f "$f" ] && echo "  Applying: $(basename $f)" && psql -U postgres -d pattern_db -f "$f"
done

# 2. Middleware migrations (sorted)
echo "Running middleware migrations..."
for f in $(ls /migrations/01_middleware/*.sql 2>/dev/null | sort); do
    echo "  Applying: $(basename $f)"
    psql -U postgres -d pattern_db -f "$f" || echo "  WARNING: $(basename $f) had errors (may be idempotent)"
done

# 3. Backend migrations (sorted)
echo "Running backend migrations..."
for f in $(ls /migrations/02_backend/*.sql 2>/dev/null | sort); do
    echo "  Applying: $(basename $f)"
    psql -U postgres -d pattern_db -f "$f" || echo "  WARNING: $(basename $f) had errors (may be idempotent)"
done

# 4. Seed data
echo "Running seed data..."
for f in $(ls /migrations/50_seed/*.sql 2>/dev/null | sort); do
    echo "  Applying: $(basename $f)"
    psql -U postgres -d pattern_db -f "$f" || echo "  WARNING: $(basename $f) had errors"
done

echo "=== Database init complete ==="
