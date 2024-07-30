#!/usr/bin/env bash

set -euo pipefail

corepack enable yarn
corepack yarn build || exit
corepack yarn test:bare
