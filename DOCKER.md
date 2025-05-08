# Docker Setup for Edge-Eco-Coach

This document describes how to run the Edge-Eco-Coach application locally using Docker.

## Prerequisites

- Docker and Docker Compose
- .env file with necessary configuration (see .env.example)

## Quick Start

1. Create a `.env` file based on `.env.example`:

```bash
cp .env.example .env
```

2. Edit the `.env` file with your configuration, especially:
   - Database credentials
   - OpenAQ API key (sign up at https://openaq.org/request-api-key/)
   - Tokyo bounding box coordinates: `CITY_BOUNDING_BOX=[139.6, 35.5, 140.0, 35.8]`

3. Start the services:

```bash
docker-compose up -d
```

## Services

The Docker Compose setup includes the following services:

- **postgres**: PostgreSQL database with PostGIS and pgRouting extensions
- **route-generator**: Python-based Lambda function for route optimization
- **route-serve**: TypeScript-based Lambda function for serving routes via API
- **tile-edge**: Lambda@Edge function simulation for tile optimization
- **tile-server**: Vector tile server
- **osm-importer**: One-time service to import OpenStreetMap data for Tokyo

## Endpoints

- Route API: http://localhost:3000/route?home=35.6,139.7&work=35.7,139.8
- Tile Server: http://localhost:8081
- Tile Edge: http://localhost:8080/tiles/{z}/{x}/{y}

## Monitoring

To view logs from a specific service:

```bash
docker-compose logs -f [service-name]
```

For example:

```bash
docker-compose logs -f route-serve
```

## Importing OSM Data

By default, the OSM importer service will run automatically and import data for Tokyo. To manually import data:

```bash
docker-compose run --rm osm-importer bash /app/sql/import_osm.sh tokyo
```

## Testing the Mobile App

Update the mobile app configuration to use the local Docker services:

1. Edit `mobile-app/app.json`:

```json
"extra": {
  "apiUrl": "http://localhost:3000",
  "tilesUrl": "http://localhost:8080"
}
```

2. Run the mobile app:

```bash
cd mobile-app
npm install
npm start
```

## Cleanup

To stop all services:

```bash
docker-compose down
```

To remove all data (including the database volume):

```bash
docker-compose down -v
``` 