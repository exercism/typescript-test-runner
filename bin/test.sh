#!/bin/bash

set -euo pipefail

corepack enable yarn
yarn build || exit
yarn test:bare
