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

# Prometheus JMX exporter, loaded as a Java agent (see EXTRA_JAVA_OPTS in
# docker-compose.yml). Exposes JVM and Tomcat metrics on port 9404.
ARG JMX_EXPORTER_VERSION=1.6.0
ARG JMX_EXPORTER_SHA256=a95983fd96e865d2bcdf911cc500e7c82808c27ab9fd226bf96732b6c3d8c46e
RUN set -eu; mkdir -p /opt/jmx; \
    curl -fsSL -o /opt/jmx/jmx_prometheus_javaagent.jar \
      "https://github.com/prometheus/jmx_exporter/releases/download/${JMX_EXPORTER_VERSION}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar"; \
    echo "${JMX_EXPORTER_SHA256}  /opt/jmx/jmx_prometheus_javaagent.jar" | sha256sum -c -
COPY jmx-exporter.yaml /opt/jmx/config.yaml

# Replace Tomcat's default access log with one JSON object per request,
# including the duration (%D, microseconds) and the GeoWebCache cache result.
# The image's startup script renders conf/server.xml from /opt/config/server.xml,
# so the template is patched.
# Alloy tails these files from the shared logs volume. Files rotate daily and
# are kept for two days.
RUN set -eu; conf=/opt/config/server.xml; \
    sed -i '/<Valve className="org.apache.catalina.valves.AccessLogValve"/,/\/>/c\
        <Valve className="org.apache.catalina.valves.JsonAccessLogValve" directory="logs" \
               prefix="access" suffix=".json" maxDays="2" buffered="false" \
               pattern="%m %U %q %s %b %D %{geowebcache-cache-result}o" />' "$conf"; \
    grep -q JsonAccessLogValve "$conf"
