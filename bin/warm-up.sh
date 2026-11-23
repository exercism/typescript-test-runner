#!/usr/bin/env bash

# Synopsis:
# Run the test runner once on a small exercise while building the Docker
# image, with NODE_COMPILE_CACHE set (see the Dockerfile). Node saves the
# compiled code of every module it loads (TypeScript, tstyche, expect and
# their dependencies) in that folder. Each run then loads the compiled code instead
# of compiling about 20 MB of JavaScript again.

set -euo pipefail

ROOT="$(realpath "$(dirname "$0")/..")"
WARM_UP_DIR="$(mktemp -d)/warm-up/"

mkdir -p "${WARM_UP_DIR}.meta" "${WARM_UP_DIR}__typetests__"

cat > "${WARM_UP_DIR}.meta/config.json" <<'JSON'
{
  "files": {
    "solution": ["warm-up.ts"],
    "test": ["__typetests__/warm-up.tst.ts", "warm-up.test.ts"]
  }
}
JSON

cat > "${WARM_UP_DIR}warm-up.ts" <<'TS'
export function answer(): number {
  return 42
}
TS

cat > "${WARM_UP_DIR}warm-up.test.ts" <<'TS'
import { answer } from './warm-up'

describe('answer', () => {
  it('is 42', () => {
    expect(answer()).toBe(42)
  })
})
TS

cat > "${WARM_UP_DIR}__typetests__/warm-up.tst.ts" <<'TS'
import { expect, test } from 'tstyche'
import { answer } from '../warm-up.ts'

test('answer returns a number', () => {
  expect(answer()).type.toBe<number>()
})
TS

"${ROOT}/bin/run.sh" warm-up "${WARM_UP_DIR}" "${WARM_UP_DIR}" > /dev/null

# Check the warm-up run passed and ran the test, so a broken runner fails the
# image build
grep -q '"status": "pass"' "${WARM_UP_DIR}results.json"
grep -q '"name": "answer > is 42"' "${WARM_UP_DIR}results.json"

rm -rf "$(dirname "${WARM_UP_DIR}")"
