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

# install our test runner to /opt
WORKDIR /opt/test-runner
COPY . .

# Build the test runner
RUN set -ex; \
  corepack enable; \
  corepack pack; \
  # install all the development modules (used for building)
  yarn install; \
  yarn build; \
  # clean our yarn cache
  yarn cache clean; \
  # install only the node_modules we need for production
  yarn workspaces focus --production;

COPY ./corepack.tgz ./corepack.tgz

USER appuser
ENTRYPOINT [ "/opt/test-runner/bin/run.sh" ]
