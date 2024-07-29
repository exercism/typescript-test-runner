#!/bin/bash

set -euo pipefail

corepack enable yarn
yarn lint
