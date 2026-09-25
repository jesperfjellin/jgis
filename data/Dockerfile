FROM debian:trixie-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends osm2pgsql postgresql-client curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*
COPY osm.lua load-osm.sh post-import.sql /opt/loader/
ENTRYPOINT ["/opt/loader/load-osm.sh"]
