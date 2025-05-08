FROM postgres:15

# Install PostGIS and pgRouting packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        postgresql-15-postgis-3 \
        postgresql-15-pgrouting \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy initialization script 
COPY ./init-postgis.sh /docker-entrypoint-initdb.d/10-init-postgis.sh
RUN chmod +x /docker-entrypoint-initdb.d/10-init-postgis.sh 