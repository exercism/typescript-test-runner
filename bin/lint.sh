#!/usr/bin/env bash

set -euo pipefail

corepack enable yarn
yarn lint
