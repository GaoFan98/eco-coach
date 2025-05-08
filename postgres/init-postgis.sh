#!/bin/bash
set -e

# Function to execute SQL as the postgres user
exec_sql() {
  psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$1"
}

# Create PostGIS and pgRouting extensions in the database
echo "Initializing PostGIS and pgRouting extensions..."
exec_sql "CREATE EXTENSION IF NOT EXISTS postgis;"
exec_sql "CREATE EXTENSION IF NOT EXISTS pgrouting;"

echo "PostGIS and pgRouting extensions initialized successfully." 