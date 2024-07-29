FROM node:20-bookworm-slim AS runner
# Node.js 20 (curently LTS)
# Debian bookwork

# fetch latest security updates
RUN set -ex; \
  apt-get update; \
  apt-get upgrade -y; \
  # curl is required to fetch our webhook from github
  # unzip is required for unzipping payloads in development
  apt-get install curl unzip jq -y; \
  rm -rf /var/lib/apt/lists/*

# add a non-root user to run our code as
RUN adduser --disabled-password --gecos "" appuser
RUN mkdir -p /home/appuser/.cache

# install our test runner to /opt
WORKDIR /opt/test-runner
COPY . .

# Build the test runner
RUN set -ex; \
  corepack enable; \
  corepack pack -o ./corepack.tgz; \
  # install all the development modules (used for building)
  yarn cache clean; \
  yarn install; \
  yarn build; \
  # yarn cache clean; \
  #
  # install only the node_modules we need for production
  #   This is disabled because yarn workspaces focus --production will still use
  #   the global cache (even when we don't want it to). The global cache cannot
  #   be written to in our Docker set-up.
  #
  # TODO: yarn workspaces focus --production;

USER appuser
ENTRYPOINT [ "/opt/test-runner/bin/run.sh" ]
