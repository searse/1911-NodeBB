FROM node:lts as build
ENV NODE_ENV=production \
    DAEMON=false \
    SILENT=false \
    USER=nodebb \
    UID=1001 \
    GID=1001
WORKDIR /usr/src/app/
COPY . /usr/src/app/
# Install corepack to allow usage of other package managers
RUN corepack enable
# Removing unnecessary files for us
RUN find . -mindepth 1 -maxdepth 1 -name '.*' ! -name '.' ! -name '..' -exec bash -c 'echo "Deleting {}"; rm -rf {}' \;
# Prepare package.json
RUN cp /usr/src/app/install/package.json /usr/src/app/
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
    apt-get -y --no-install-recommends install \
        tini
RUN groupadd --gid ${GID} ${USER} \
    && useradd --uid ${UID} --gid ${GID} --home-dir /usr/src/app/ --shell /bin/bash ${USER} \
    && chown -R ${USER}:${USER} /usr/src/app/
USER ${USER}
RUN npm install --omit=dev \
    && rm -rf .npm
    # TODO: generate lockfiles for each package manager
    ## pnpm import \
FROM node:lts-slim AS final
ENV NODE_ENV=production \
    DAEMON=false \
    SILENT=false \
    USER=nodebb \
    UID=1001 \
    GID=1001 \
    PORT=4567
WORKDIR /usr/src/app/
RUN corepack enable \
    && groupadd --gid ${GID} ${USER} \
    && useradd --uid ${UID} --gid ${GID} --home-dir /usr/src/app/ --shell /bin/bash ${USER} \
    && mkdir -p /usr/src/app/logs/ /opt/config/ \
    && chown -R ${USER}:${USER} /usr/src/app/ /opt/config/
COPY --from=build --chown=${USER}:${USER} /usr/src/app/ /usr/src/app/install/docker/setup.json /usr/src/app/
COPY --from=build --chown=${USER}:${USER} /usr/bin/tini /usr/src/app/install/docker/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && chmod +x /usr/local/bin/tini

# Create a script to handle Render-specific configuration
RUN echo '#!/bin/bash\n\
# Create config.json if it does not exist\n\
if [ ! -f /usr/src/app/config.json ]; then\n\
  echo "Creating initial config.json..."\n\
  cat > /usr/src/app/config.json << EOF\n\
{\n\
  "url": "${url:-http://localhost:4567}",\n\
  "port": "${PORT:-4567}",\n\
  "database": {\n\
    "mongo": {\n\
      "uri": "${database__mongo__uri}",\n\
      "database": "${database__mongo__database:-nodebb}"\n\
    }\n\
  }\n\
}\n\
EOF\n\
  chown ${USER}:${USER} /usr/src/app/config.json\n\
fi\n\
\n\
# Run the original entrypoint script\n\
exec /usr/local/bin/entrypoint.sh "$@"\n\
' > /usr/local/bin/render-entrypoint.sh

RUN chmod +x /usr/local/bin/render-entrypoint.sh

USER ${USER}
EXPOSE 4567
VOLUME ["/usr/src/app/node_modules", "/usr/src/app/build", "/usr/src/app/public/uploads", "/opt/config/"]

# Modified for Render: use our new entrypoint script
ENTRYPOINT ["tini", "--", "/usr/local/bin/render-entrypoint.sh"]

# Default command if no arguments provided
CMD ["node", "loader.js"]