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

# Community modules have no release zips, only nightly builds. Released jars of
# the same version are published to the OSGeo Maven repository, so fetch those
# instead. Their dependencies must already be in the image (check the module's
# pom when adding one); the sha1 files guard against truncated downloads.
ARG COMMUNITY_MODULES="gs-ogcapi-tiles"
RUN set -eu; lib="${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib"; \
    for mod in ${COMMUNITY_MODULES}; do \
      url="https://repo.osgeo.org/repository/release/org/geoserver/community/${mod}/${GEOSERVER_VERSION}/${mod}-${GEOSERVER_VERSION}.jar"; \
      curl -fsSL -o "${lib}/${mod}-${GEOSERVER_VERSION}.jar" "${url}"; \
      echo "$(curl -fsSL "${url}.sha1")  ${lib}/${mod}-${GEOSERVER_VERSION}.jar" | sha1sum -c -; \
    done
