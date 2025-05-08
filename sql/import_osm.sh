#!/bin/bash
set -e

# Load environment variables from .env file if it exists
if [ -f ../.env ]; then
  export $(grep -v '^#' ../.env | xargs)
fi

# Configuration
CITY=${1:-"tokyo"}  # Default to Tokyo if no city specified
PG_USER=${PG_USER:-"dbadmin"}
PG_DB=${PG_DB:-"ecocoach"}
TEMP_DIR="/tmp/osm_import"

# Ensure temp directory exists
mkdir -p ${TEMP_DIR}

echo "Downloading OSM data for ${CITY}..."

# Get Japan/Tokyo data from Geofabrik
if [ "$CITY" = "tokyo" ]; then
  echo "Using Geofabrik to download Tokyo data"
  # Download Japan extract from Geofabrik
  wget -O ${TEMP_DIR}/japan-latest.osm.pbf https://download.geofabrik.de/asia/japan-latest.osm.pbf
  
  # Extract Tokyo area using osmium
  echo "Extracting Tokyo area..."
  apt-get update && apt-get install -y osmium-tool
  
  # Tokyo bounding box
  BBOX="139.6,35.5,140.0,35.8"
  osmium extract -b $BBOX ${TEMP_DIR}/japan-latest.osm.pbf -o ${TEMP_DIR}/${CITY}.osm.pbf
  
  OSM_FILE="${TEMP_DIR}/${CITY}.osm.pbf"
elif [ "$CITY" = "new-york" ]; then
  # NYC data directly from Geofabrik
  wget -O ${TEMP_DIR}/${CITY}.osm.pbf https://download.geofabrik.de/north-america/us/new-york-latest.osm.pbf
  OSM_FILE="${TEMP_DIR}/${CITY}.osm.pbf"
else
  echo "Unknown city: ${CITY}"
  exit 1
fi

# Import OSM data into PostgreSQL with osm2pgsql
echo "Importing OSM data into PostgreSQL..."
osm2pgsql --create --database ${PG_DB} --username ${PG_USER} --host postgres \
          --hstore --latlong \
          --style /usr/share/osm2pgsql/default.style \
          ${OSM_FILE}

# Extract road network for pgrouting
echo "Creating road network for routing..."
psql -U ${PG_USER} -d ${PG_DB} -h postgres -c "
-- Create edges table from OSM data
INSERT INTO edges (id, source, target, distance_m, geom)
SELECT 
  osm_id AS id,
  0 AS source,  -- Will be populated by pgr_createTopology
  0 AS target,  -- Will be populated by pgr_createTopology
  ST_Length(way::geography) AS distance_m,
  way AS geom
FROM planet_osm_line
WHERE highway IN ('motorway', 'trunk', 'primary', 'secondary', 'tertiary', 'residential', 'service', 'cycleway')
  AND way IS NOT NULL;

-- Create network topology
SELECT pgr_createTopology('edges', 0.0001, 'geom', 'id');

-- Update air quality values (placeholder random values for demonstration)
UPDATE edges SET air_pm25 = random() * 25;  -- Random PM2.5 values from 0-25

-- Update accident risk values (placeholder random values for demonstration)
UPDATE edges SET accident_risk = random() * 10;  -- Random risk values from 0-10

-- Create materialized view for faster access
REFRESH MATERIALIZED VIEW mv_edge_costs;
"

echo "OSM import and road network creation complete!" 