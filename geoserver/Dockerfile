# GeoServer with extensions baked in at build time, so containers never
# download anything at startup.
ARG GEOSERVER_VERSION=3.0.1
FROM docker.osgeo.org/geoserver:${GEOSERVER_VERSION}
ARG GEOSERVER_VERSION
ARG EXTENSIONS="vectortiles ogcapi-features"
RUN set -eu; for ext in ${EXTENSIONS}; do \
      curl -fsSL -o /tmp/ext.zip \
        "https://sourceforge.net/projects/geoserver/files/GeoServer/${GEOSERVER_VERSION}/extensions/geoserver-${GEOSERVER_VERSION}-${ext}-plugin.zip/download"; \
      unzip -o -q /tmp/ext.zip '*.jar' -d "${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/"; \
      rm /tmp/ext.zip; \
    done
