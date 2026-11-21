FROM node:lts-slim@sha256:cb4e8f7c443347358b7875e717c29e27bf9befc8f5a26cf18af3c3dec80e58c5 AS runner
# lts-slim == 24.18.0-bookworm-slim

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

# Install the packages into node_modules instead of using Plug'n'Play. Each
# run links its output directory to this folder and calls the tools in
# node_modules/.bin directly, so it no longer copies the yarn cache or runs
# `yarn install`.
ENV YARN_NODE_LINKER=node-modules

# Build the test runner
RUN set -ex; \
  # install all the development modules (used for building)
  corepack yarn cache clean; \
  corepack yarn install; \
  corepack yarn build; \
  # the packages are in node_modules now, so the cache is no longer needed
  corepack yarn cache clean;
  # corepack yarn cache clean; \
  #
  # install only the node_modules we need for production
  # I don't know how to get this to work with zero-installs enabled
  #
  # TODO: corepack yarn workspaces focus --production;

# Disable network for corepack
ENV COREPACK_ENABLE_NETWORK=0
ENV COREPACK_ENABLE_STRICT=0

# Prefer offline mode for yarn
ENV YARN_ENABLE_OFFLINE_MODE=1
ENV YARN_ENABLE_HARDENED_MODE=0

# Let's check to be certain
RUN corepack yarn --version

# Node saves the compiled code of each module it loads in this folder, and
# reuses it in later runs. bin/warm-up.sh runs the test runner once to fill
# it, so each run skips compiling TypeScript, tstyche and Jest.
ENV NODE_COMPILE_CACHE=/opt/test-runner/.node-compile-cache
RUN set -ex; \
  bin/warm-up.sh; \
  # remove Jest's cache from the warm-up, so runs start with an empty one
  rm -rf /tmp/jest_*

ENTRYPOINT [ "/opt/test-runner/bin/run.sh" ]

# Record the files read by a run. A separate stage keeps strace out of the
# final image.
FROM runner AS prefetch-list
RUN set -ex; \
  apt-get update; \
  apt-get install strace -y; \
  bin/record-prefetch-list.sh /tmp/prefetch-list

FROM runner
COPY --from=prefetch-list /tmp/prefetch-list /opt/test-runner/.prefetch-list
