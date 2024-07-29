#!/bin/bash

# Synopsis:
# Automatically tests exercism's TS track solutions against corresponding test files.
# Takes two-three arguments and makes sure all the tests are run

# Arguments:
# $1: exercise slug
# $2: path to solution folder (with trailing slash)
# $3: path to output directory (with trailing slash) (defaults to $2)

# Output:
# Writes the tests output to the output directory

# Example:
# ./run.sh two-fer path/to/two-fer/solution/folder/
# ./run.sh two-fer path/to/two-fer/solution/folder/ path/to/output-directory/

if [[ $1 != http?(s)://* ]]; then
  if [ -z "$2" ] ; then
    echo "Requires at least 2 arguments:"
    echo "1: exercise slug"
    echo "2: path to solution folder (with trailing slash)"
    echo "3: (optional) path to output directory (with trailing slash) (defaults to \$2)"
    echo ""
    echo "Usage:"
    echo "  run.sh two-fer path/to/two-fer/solution/folder/ [path/to/output-directory/]"
    exit 1
  fi

  if [ -z "$3" ] ; then
    OUTPUT="$2"
  else
    OUTPUT="$3"
  fi

  INPUT="$2"
  SLUG="$1"
else
  # This block allows you to download a solution and run the tests on it. This
  # allows passing in any solution URL your locally installed exercism CLI has
  # access to:
  #
  # - published: https://exercism.io/tracks/typescript/exercises/clock/solutions/c3b826d95cb54441a8f354d7663e9e16
  # - private: https://exercism.io/solutions/c3b826d95cb54441a8f354d7663e9e16
  #
  uuid=$(basename $1)
  echo "Exercism remote UUID: $uuid"

  result=$(exercism download --uuid="${uuid}" | sed -n 1p) || exit $?
  echo $result

  SLUG=$(basename $result)
  TMP="./tmp/${SLUG}/${uuid}/"

  # Jest really doesn't like it when the input files are outside the CWD process
  # tree. Instead of trying to resolve that, the code here copies the downloaded
  # solution to a local temporary directory.
  #
  # This will fail if the cwd is not writable.
  #
  mkdir -p "$TMP"
  cp "$result" "$TMP" -r

  INPUT="$TMP$SLUG/"
  OUTPUT=$INPUT
fi

# Forces a trailing slash
INPUT="${INPUT//\\//}"
INPUT="${INPUT%/}/"

# Forces a trailing slash
OUTPUT="${OUTPUT//\\//}"
OUTPUT="${OUTPUT%/}/"

set -euo pipefail

ROOT="$(realpath $(dirname "$0")/..)"
REPORTER="$ROOT/dist/reporter.js"
SETUP="$ROOT/dist/jest/setup.js"
CONFIG="$ROOT/jest.runner.config.js"

if test -f "$REPORTER"; then
  echo "Using reporter : $REPORTER"
  echo "Using test-root: $INPUT"
  echo "Using base-root: $ROOT"
  echo "Using setup-env: $SETUP"

  echo ""
else
  >&2 echo "Expected reporter.js to exist. Did you forget to yarn build first?"
  >&2 echo "Using reporter : $REPORTER"
  >&2 echo "Using test-root: $INPUT"
  >&2 echo "Using base-root: $ROOT"
  >&2 echo "Using setup-env: $SETUP"
  >&2 echo ""
  >&2 echo "The following files exist in the dist folder (build output):"
  >&2 echo $(ls $ROOT/dist)
  exit 1
fi

echo ""

configuration_file="${INPUT}.meta/config.json"
local_configuration_file="${INPUT}.exercism/config.json"

# Prepare the test file(s)
mkdir -p "${OUTPUT}"

if [[ "${INPUT}" -ef "${OUTPUT}" ]]; then
  echo "${INPUT} matches ${OUTPUT}. Not copying input to output."
else
  echo "Copying ${INPUT} to ${OUTPUT}."
  cp -r "${INPUT}/." "${OUTPUT}"
  cp -r "${ROOT}/.yarn" "${OUTPUT}"
  cp "${ROOT}/.yarnrc.yml" "${OUTPUT}/.yarnrc.yml"
  cp "${ROOT}/yarn.lock" "${OUTPUT}/yarn.lock"
  cp "${ROOT}/.pnp.cjs" "${OUTPUT}/.pnp.cjs"
  cp "${ROOT}/.pnp.cjs" "${OUTPUT}/.pnp.loader.mjs"

  # Rename babel.config.js and package.json
  if test -f "${OUTPUT}babel.config.js"; then
    mv "${OUTPUT}babel.config.js" "${OUTPUT}babel.config.js.__exercism.bak" || true
  fi;

  if test -f "${OUTPUT}package.json"; then
    mv "${OUTPUT}package.json" "${OUTPUT}package.json.__exercism.bak" || true
  fi;
fi

# Rename babel.config.js and package.json
echo "Disabling babel.config.js and package.json from input, if any"
if test -f "${OUTPUT}babel.config.js"; then
  mv "${OUTPUT}babel.config.js" "${OUTPUT}babel.config.js.__exercism.bak" || true
fi;

if test -f "${OUTPUT}package.json"; then
  mv "${OUTPUT}package.json" "${OUTPUT}package.json.__exercism.bak" || true
fi;

if [[ "${OUTPUT}" =~ "$ROOT" ]]; then
  echo "Test runnner root contains output directory. No need to turn output directory into a standalone package."
else
  echo "Test runnner root does not contain output directory. Turning output directory into a standalone package."

  # Turn into standalone package
  cp "${ROOT}/package.json" "${OUTPUT}package.json"
fi

if test -f $configuration_file; then
  echo "Using ${configuration_file} as base configuration"
  cat $configuration_file | jq -c '.files.test[]' | xargs -L 1 "$ROOT/bin/prepare.sh" ${OUTPUT}
else
  if test -f $local_configuration_file; then
    echo "Using ${local_configuration_file} as base configuration"
    cat $local_configuration_file | jq -c '.files.test[]' | xargs -L 1 "$ROOT/bin/prepare.sh" ${OUTPUT}
  else
    test_file="${SLUG}.test.ts"
    echo "No configuration given. Falling back to ${test_file}"
    "$ROOT/bin/prepare.sh" ${OUTPUT} ${test_file}
  fi;
fi;

if test -d "${OUTPUT}node_modules"; then
  echo "Did not expect node_modules in output directory, but here we are"
fi;

# Put together the path to the test results file
result_file="${OUTPUT}results.json"

# Check yarn
if test -f "$ROOT/corepack.tgz"; then
  COREPACK_ENABLE_NETWORK=0 corepack install -g "$ROOT/corepack.tgz"
else
  echo "Did not find '$ROOT/corepack.tgz'. You either need network access or run corepack pack first when network is enabled."
  ls -aln1 "$ROOT"

fi;

YARN_ENABLE_OFFLINE_MODE=1 yarn -v
echo ""
echo "------------------------------------"

if test -f "${OUTPUT}package.json"; then
  echo "Standalone package found" #, installing packages from cache"

  ls -aln1 "$OUTPUT"
  ls -aln1 "$OUTPUT/.yarn/cache"

  cd "${OUTPUT}" && YARN_ENABLE_NETWORK=false YARN_ENABLE_OFFLINE_MODE=true YARN_ENABLE_GLOBAL_CACHE=false yarn install --immutable
fi;

# Disable auto exit
set +e

# Run tsc
# cp -r "$ROOT/node_modules/@types" "$INPUT/node_modules"

if test -f "${OUTPUT}tsconfig.json"; then
  echo "Found tsconfig.json; disabling test compilation"
  sed -i 's/, "\.meta\/\*"//' "${OUTPUT}tsconfig.json"
  sed -i 's/"node_modules"/"node_modules", "*.test.ts", ".meta\/*"/' "${OUTPUT}tsconfig.json"
fi;

echo "Running tsc"
tsc_result="$( cd "${OUTPUT}" && "YARN_ENABLE_OFFLINE_MODE=1 yarn run tsc" --noEmit 2>&1 )"
test_exit=$?

echo "$tsc_result" > $result_file
sed -i 's/"/\\"/g' $result_file

if test -f "${OUTPUT}tsconfig.json"; then
  echo "Found tsconfig.json; enabling test compilation"
  sed -i 's/\["\*"\]/["*", ".meta\/*"]/' "${OUTPUT}tsconfig.json"
  sed -i 's/"node_modules", "\*\.test\.ts", "\.meta\/\*"/"node_modules"/' "${OUTPUT}tsconfig.json"
fi;

if [ $test_exit -eq 2 ]
then
  echo "tsc compilation failed"

  # Restore babel.config.js and package.json
  if test -f "${OUTPUT}package.config.json"; then
    unlink "${OUTPUT}package.config.json"
  fi;

  if test -f "${OUTPUT}babel.config.js.__exercism.bak"; then
    mv "${OUTPUT}babel.config.js.__exercism.bak" "${OUTPUT}babel.config.js" || true
  fi;

  if test -f "${OUTPUT}package.json.__exercism.bak"; then
    mv "${OUTPUT}package.json.__exercism.bak" "${OUTPUT}package.json" || true
  fi;

  # Compose the message to show to the student
  #
  # TODO: interpret the tsc_result lines and pull out the source.
  #       We actually already have code to do this, given the cursor position
  #
  tsc_result=$(cat $result_file)
  tsc_result="The submitted code didn't compile. We have collected the errors encountered during compilation. At this moment the error messages are not very read-friendly, but it's a start. We are working on a more helpful output.\n-------------------------------\n$tsc_result"
  echo "{ \"version\": 1, \"status\": \"error\", \"message\": \"$tsc_result\" }" > $result_file
  sed -Ei ':a;N;$!ba;s/\r{0,1}\n/\\n/g' $result_file
  # Test runner didn't fail!
  exit 0
else
  echo "tsc compilation success"
fi

echo "---------------------------------------------------------------"
echo "Running tests via jest"

# Run tests
cd "${OUTPUT}" && YARN_ENABLE_OFFLINE_MODE=1 yarn run jest "${OUTPUT}*" \
                  --bail 1 \
                  --ci \
                  --colors \
                  --config ${CONFIG} \
                  --noStackTrace \
                  --outputFile="${result_file}" \
                  --passWithNoTests \
                  --reporters "${REPORTER}" \
                  --roots "${OUTPUT}" \
                  --setupFilesAfterEnv ${SETUP} \
                  --verbose false \
                  --testLocationInResults

# Convert exit(1) (jest worked, but there are failing tests) to exit(0)
test_exit=$?

# Restore babel.config.js and package.json
if test -f "${OUTPUT}package.config.json"; then
  unlink "${OUTPUT}package.config.json"
fi;

if test -f "${OUTPUT}babel.config.js.__exercism.bak"; then
  mv "${OUTPUT}babel.config.js.__exercism.bak" "${OUTPUT}babel.config.js" || true
fi;

if test -f "${OUTPUT}package.json.__exercism.bak"; then
  mv "${OUTPUT}package.json.__exercism.bak" "${OUTPUT}package.json" || true
fi;

echo ""
echo "---------------------------------------------------------------"
echo "Find the output at:"
echo $result_file

if [ $test_exit -eq 1 ]
then
  exit 0
else
  exit $test_exit
fi
