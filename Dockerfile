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

# Install yarn so it will be available read-only
# https://github.com/nodejs/corepack/issues/183#issue-1379672431
# https://github.com/nodejs/corepack/blob/bc13d40037d0b1bfd386e260ae741f55505b5c7c/tests/main.test.ts#L483
RUN mkdir -p /idk/corepack
ENV COREPACK_HOME=/idk/corepack

RUN set -ex; \
  corepack enable yarn;
  # corepack pack -o ./corepack.tgz; \
  # COREPACK_ENABLE_NETWORK=0 corepack install -g ./corepack.tgz;

# https://github.com/nodejs/corepack/pull/446#issue-2218976611
RUN corepack install
RUN corepack yarn --version
# https://github.com/nodejs/corepack/issues/414#issuecomment-2096218732
# https://github.com/nodejs/corepack/blob/bc13d40037d0b1bfd386e260ae741f55505b5c7c/sources/folderUtils.ts#L26-L31
RUN chmod 444 /idk/corepack/lastKnownGood.json
RUN chmod 555 /idk/corepack

# Build the test runner
RUN set -ex; \
  # install all the development modules (used for building)
  yarn cache clean; \
  yarn install; \
  yarn build;
  # yarn cache clean; \
  #
  # install only the node_modules we need for production
  # I don't know how to get this to work with zero-installs enabled
  #
  # TODO: yarn workspaces focus --production;

# Disable network for corepack
ENV COREPACK_ENABLE_NETWORK=0
ENV COREPACK_ENABLE_STRICT=0

# Prefer offline mode for yarn
ENV YARN_ENABLE_OFFLINE_MODE=1
ENV YARN_ENABLE_HARDENED_MODE=0

# Because I cry myself to sleep
ENV DEBUG=*

# Let's check to be certain
RUN yarn --version

ENTRYPOINT [ "/opt/test-runner/bin/run.sh" ]
