#!/bin/bash
set -e

# Load environment variables from .env file if it exists
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Configuration
TILE_BUCKET=${TILE_BUCKET:-"eco-coach-tiles"}  # Use from env or default
CITY=${1:-"new-york"}  # Default to New York if no city specified
PG_USER=${PG_USER:-"dbadmin"}
PG_DB=${PG_DB:-"ecocoach"}
TEMP_DIR="/tmp/osm_import"
MIN_ZOOM=${MIN_ZOOM:-8}
MAX_ZOOM=${MAX_ZOOM:-16}
TILE_DIR="${TEMP_DIR}/tiles"

# Ensure temp directories exist
mkdir -p ${TEMP_DIR}
mkdir -p ${TILE_DIR}

echo "Starting vector tile generation for ${CITY}..."

# ... rest of the script ... 