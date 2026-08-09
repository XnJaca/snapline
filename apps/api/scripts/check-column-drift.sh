#!/usr/bin/env bash
# Verifica que las entities coincidan con las tablas en columnas y tipos.
#
# Solo mira columnas y tablas a propósito. El esquema es deliberadamente más rico
# que las entities —CHECK, índices parciales, triggers, RLS, FK de company_id— así
# que schema:log siempre reporta esas diferencias y no son drift.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=$(npx typeorm-ts-node-commonjs schema:log -d src/config/datasource.ts 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
DRIFT=$(echo "$OUT" | grep -E '^(CREATE TABLE|DROP TABLE|ALTER TABLE .* (ADD|DROP|ALTER) COLUMN)' || true)

if [ -n "$DRIFT" ]; then
  echo "✗ drift entre entities y base:"
  echo "$DRIFT"
  exit 1
fi
echo "✓ sin drift de columnas — las entities coinciden con el esquema"
