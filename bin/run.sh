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
  echo "🔗  Exercism remote UUID: $uuid"

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

echo ""
echo "╔═════════════════════════════════════════════════════════════╗"
echo "  🔧 Process input arguments for run                            "
echo "╚═════════════════════════════════════════════════════════════╝"
echo ""


if test -f "$REPORTER"; then
  echo "✔️  Using reporter : $REPORTER"
  echo "✔️  Using test-root: $INPUT"
  echo "✔️  Using base-root: $ROOT"
  echo "✔️  Using setup-env: $SETUP"
else
  echo "✔️  Using reporter : $REPORTER"
  echo "✔️  Using test-root: $INPUT"
  echo "✔️  Using base-root: $ROOT"
  echo "✔️  Using setup-env: $SETUP"

  >&2 echo "❌ Expected reporter.js to exist."
  >&2 echo "❌ Did you forget to 'corepack yarn build' first?"
  >&2 echo ""
  >&2 echo "👁️ The following files exist in the dist folder (build output):"
  >&2 echo $(ls $ROOT/dist)

  exit 1
fi

echo ""
echo "╔═════════════════════════════════════════════════════════════╗"
echo "  🔧 Preparing run                                              "
echo "╚═════════════════════════════════════════════════════════════╝"
echo ""

configuration_file="${INPUT}.meta/config.json"
local_configuration_file="${INPUT}.exercism/config.json"

# Prepare the test file(s)
mkdir -p "${OUTPUT}"

if [[ "${INPUT}" -ef "${OUTPUT}" ]]; then
  echo "Input matches output directory."
  echo "👁️  ${OUTPUT}"
  echo "✔️  Not copying input to output."
  echo ""
else
  echo "Input does not match output directory."
  echo "👁️  ${OUTPUT}"
  echo "✔️  Copying ${INPUT} to output."
  cp -r "${INPUT}/." "${OUTPUT}"
  echo ""
fi

echo "If the solution contains babel.config.js, package.json,        "
echo "or tsconfig.json at the root, these configuration files will   "
echo "be used during the test-runner process which we do not want.   "
echo "The test-runner will therefore temporarily rename these files."
echo ""

# Rename configuration files
if test -f "${OUTPUT}babel.config.js"; then
  echo "✔️  renaming babel.config.js in output so it can be replaced."
  mv "${OUTPUT}babel.config.js" "${OUTPUT}babel.config.js.💥.bak" || true
fi;

if test -f "${OUTPUT}package.json"; then
  echo "✔️  renaming package.json in output so it can be replaced."
  mv "${OUTPUT}package.json" "${OUTPUT}package.json.💥.bak" || true
fi;

if test -f "${OUTPUT}tsconfig.json"; then
  echo "✔️  renaming tsconfig.json in output so it can be replaced."
  mv "${OUTPUT}tsconfig.json" "${OUTPUT}tsconfig.json.💥.bak" || true
fi;

if [[ "${OUTPUT}" =~ "$ROOT" ]]; then
  echo ""
  echo "The output directory seems to be placed inside the test      "
  echo "runner root. This means the CLI tools we run will use the    "
  echo "configuration files as given by the test-runner for running  "
  echo "the tests, which is what we want. No need to turn the output "
  echo "directory into a standalone package."
  echo ""

  echo "✔️  tsconfig.json from root to output"
  cp "${ROOT}/tsconfig.solutions.json" "${OUTPUT}tsconfig.json"
  echo ""
else
  echo ""
  echo "The output directory is likely not placed inside the test    "
  echo "runner root. This means the CLI tools need configuration     "
  echo "files as given and understood by the test-runner for running "
  echo "the tests. Will now turn the output directory into a         "
  echo "standalone package."
  echo ""

  echo "✔️  .yarn cache from root to output"
  cp -r "${ROOT}/.yarn" "${OUTPUT}"

  echo "✔️  .yarnrc.yml from root to output"
  cp "${ROOT}/.yarnrc.yml" "${OUTPUT}/.yarnrc.yml"

  echo "✔️  .yarn.lock from root to output"
  cp "${ROOT}/yarn.lock" "${OUTPUT}/yarn.lock"

  echo "✔️  .pnp.cjs from root to output"
  cp "${ROOT}/.pnp.cjs" "${OUTPUT}/.pnp.cjs"

  echo "✔️  .pnp.loader.mjs from root to output"
  cp "${ROOT}/.pnp.loader.mjs" "${OUTPUT}/.pnp.loader.mjs"

  echo "✔️  babel.config.js from root to output"
  cp "${ROOT}/babel.config.js" "${OUTPUT}babel.config.js"

  echo "✔️  package.json from root to output"
  cp "${ROOT}/package.json" "${OUTPUT}package.json"

  echo "✔️  tsconfig.json from root to output"
  cp "${ROOT}/tsconfig.solutions.json" "${OUTPUT}tsconfig.json"
  echo ""
fi

# Put together the path to the test results file
result_file="${OUTPUT}results.json"
echo "The results of this run will be written to 'results.json'."
echo "👁️  ${result_file}"
echo ""
echo "╔═════════════════════════════════════════════════════════════╗"
echo "  🔧 Preparing test suite file(s)                               "
echo "╚═════════════════════════════════════════════════════════════╝"
echo ""

if test -f $configuration_file; then
  echo "There is a configuration file in the expected .meta location "
  echo "which will now be used to determine which test files to prep."
  echo "👁️  ${configuration_file}"
  cat "${configuration_file}"
  echo ""

  cat $configuration_file | jq -c '.files.test[]' | xargs -L 1 "$ROOT/bin/prepare.sh" ${OUTPUT}
else
  if test -f $local_configuration_file; then
    echo "There is a configuration file in the .exercism local       "
    echo "location which will now be used to determine which test    "
    echo "files to prep."
    echo "👁️  ${local_configuration_file}"
    cat "${local_configuration_file}"
    echo ""

    cat $local_configuration_file | jq -c '.files.test[]' | xargs -L 1 "$ROOT/bin/prepare.sh" ${OUTPUT}
  else
    test_file="${SLUG}.test.ts"

    echo "⚠️  No configuration file found. The test-runner will now   "
    echo "   guess which test file(s) to prep based on the input."
    echo ""
    echo "👁️  ${OUTPUT}${test_file}"
    echo ""

    if test -f "${OUTPUT}${test_file}"; then
      "$ROOT/bin/prepare.sh" ${OUTPUT} ${test_file}
    else
      echo ""
      echo "If the solution previously contained configuration files,    "
      echo "they were disabled and now need to be restored."
      echo ""

      # Restore configuration files
      if test -f "${OUTPUT}babel.config.js.💥.bak"; then
        echo "✔️  restoring babel.config.js in output"
        unlink "${OUTPUT}babel.config.js"
        mv "${OUTPUT}babel.config.js.💥.bak" "${OUTPUT}babel.config.js" || true
      fi;

      if test -f "${OUTPUT}package.json.💥.bak"; then
        echo "✔️  restoring package.json in output"
        unlink "${OUTPUT}package.json"
        mv "${OUTPUT}package.json.💥.bak" "${OUTPUT}package.json" || true
      fi;

      if test -f "${OUTPUT}tsconfig.json.💥.bak"; then
        echo "✔️  restoring tsconfig.json in output"
        mv "${OUTPUT}tsconfig.json.💥.bak" "${OUTPUT}tsconfig.json" || true
      fi;

      result="The submitted code cannot be ran by the test-runner. There is no configuration file inside the .meta (or .exercism) directory, and the fallback test file '${test_file}' does not exist. Please fix these issues and resubmit."
      echo "{ \"version\": 1, \"status\": \"error\", \"message\": \"$result\" }" > $result_file
      sed -Ei ':a;N;$!ba;s/\r{0,1}\n/\\n/g' $result_file

      echo "❌ could not run the test suite(s). A valid output exists:"
      echo "${result}"
      echo "---------------------------------------------------------------"

      # Test runner didn't fail!
      exit 0
    fi
  fi
fi

echo ""
echo "╔═════════════════════════════════════════════════════════════╗"
echo "  🔧 Preparing test project                                    "
echo "╚═════════════════════════════════════════════════════════════╝"
echo ""

if test -d "${OUTPUT}node_modules"; then
  echo "⚠️  Did not expect node_modules in output directory. This is likely an "
  echo "   issue with the given solution or it is old. These will be ignored."
  echo ""
fi

# In case it's not yet enabled
echo "✔️  enabling corepack"
corepack enable yarn;

echo "✔️  yarn version now: $(YARN_ENABLE_OFFLINE_MODE=1 corepack yarn --version)"
echo ""

if test -f "${OUTPUT}package.json"; then
  echo "✔️  standalone package found installing packages from cache"
  echo ""
  ls -aln1 "$OUTPUT"
  echo ""
  cd "${OUTPUT}" && YARN_ENABLE_NETWORK=false YARN_ENABLE_HARDENED_MODE=false YARN_ENABLE_OFFLINE_MODE=true YARN_ENABLE_GLOBAL_CACHE=false corepack yarn install --immutable
fi;

echo ""
echo "╔═════════════════════════════════════════════════════════════╗"
echo "  ➤  Step 1/3: Build (tests: does it compile?)                "
echo "╚═════════════════════════════════════════════════════════════╝"
echo ""

# Disable auto exit
set +e

# Run tsc
# cp -r "$ROOT/node_modules/@types" "$INPUT/node_modules"

if test -f "${OUTPUT}tsconfig.json"; then
  echo "✔️  found a tsconfig.json (as expected)" #. Re-configuring."

  # replace "include": ["src"],
  # sed -i 's/"include": \["src"\],/"\/\/ include": ["src"],/' "${OUTPUT}tsconfig.json"

  # replace "exclude": ["test", "node_modules"]
  # sed -i 's/"exclude": \["test", "node_modules"\]/"exclude": ["test", "node_modules", ".meta\/*", "__typetests__\/*", "*.test.ts", "*.tst.ts"]/' "${OUTPUT}tsconfig.json"

  echo "👁️  ${OUTPUT}tsconfig.json"
  cat "${OUTPUT}tsconfig.json"
  echo ""
fi;

echo "⚙️  corepack yarn run tsc"
echo ""
tsc_result="$( cd "${OUTPUT}" && YARN_ENABLE_OFFLINE_MODE=1 corepack yarn run tsc --noEmit 2>&1 )"
test_exit=$?

echo "$tsc_result" > $result_file

# if test -f "${OUTPUT}tsconfig.json"; then
  # echo "✔️  found a tsconfig.json (as expected). Restoring."

  # replace "include": ["src"],
  # sed -i 's/"\/\/ include": \["src"\],/"include": ["src"],/' "${OUTPUT}tsconfig.json"

  # replace "exclude": ["test", "node_modules"]
  # sed -i 's/"exclude": \["test", "node_modules", ".meta\/*", "__typetests__\/*", "*.test.ts", "*.tst.ts"\]/"exclude": ["test", "node_modules"]/' "${OUTPUT}tsconfig.json"
# fi;

if [ $test_exit -eq 2 ]; then
  echo ""
  echo "❌ tsc compilation failed"
  echo ""
  echo "If the solution previously contained configuration files,    "
  echo "they were disabled and now need to be restored."
  echo ""

  # Restore configuration files
  if test -f "${OUTPUT}babel.config.js.💥.bak"; then
    echo "✔️  restoring babel.config.js in output"
    unlink "${OUTPUT}babel.config.js"
    mv "${OUTPUT}babel.config.js.💥.bak" "${OUTPUT}babel.config.js" || true
  fi;

  if test -f "${OUTPUT}package.json.💥.bak"; then
    echo "✔️  restoring package.json in output"
    unlink "${OUTPUT}package.json"
    mv "${OUTPUT}package.json.💥.bak" "${OUTPUT}package.json" || true
  fi;

  if test -f "${OUTPUT}tsconfig.json.💥.bak"; then
    echo "✔️  restoring tsconfig.json in output"
    unlink "${OUTPUT}tsconfig.json"
    mv "${OUTPUT}tsconfig.json.💥.bak" "${OUTPUT}tsconfig.json" || true
  fi;

  # Compose the message to show to the student
  #
  # TODO: interpret the tsc_result lines and pull out the source.
  #       We actually already have code to do this, given the cursor position
  #
  tsc_result=$(cat $result_file | jq -Rsa . | sed -e 's/^"//' -e 's/"$//')
  tsc_result="The submitted code didn't compile. We have collected the errors encountered during compilation. At this moment the error messages are not very read-friendly, but it's a start. We are working on a more helpful output.\n-------------------------------\n$tsc_result"
  echo "{ \"version\": 1, \"status\": \"error\", \"message\": \"$tsc_result\" }" > $result_file
  sed -Ei ':a;N;$!ba;s/\r{0,1}\n/\\n/g' $result_file

  echo "❌ tsc compilation failed with a valid output:"
  echo "${tsc_result}"
  echo ""
  echo "---------------------------------------------------------------"
  echo "The results of this run have been written to 'results.json'."
  echo "👁️  ${result_file}"

  # Test runner didn't fail!
  exit 0
else
  echo ""
  echo "✅ tsc compilation success"
fi

echo ""
echo "╔═════════════════════════════════════════════════════════════╗"
echo "  ➤  Step 2/3: Type tests (tests: are the types as expected?) "
echo "╚═════════════════════════════════════════════════════════════╝"
echo ""

has_type_test=false

if test -d "${OUTPUT}__typetests__/"; then
  type_tests=$(ls -aln1 "${OUTPUT}__typetests__/" | grep "tst.ts$")

  if [ -z "${type_tests}" ]; then
    # TODO: check the config file to see if tstyche tests were expected or not
    echo "✅ no type tests (*.tst.ts) discovered."
  else
    has_type_test=true
    echo "✔️  type tests discovered."
    cd "${OUTPUT}" && corepack yarn tstyche --listFiles

    echo ""
    echo "⚙️  corepack yarn tstyche"
    echo ""
    cd "${OUTPUT}" && corepack yarn tstyche --failFast 2> "${OUTPUT}tstyche.stderr.txt" 1> "${OUTPUT}tstyche.stdout.txt"

    tstyche_error_output=$(cat "${OUTPUT}tstyche.stderr.txt")

    if [ -z "${tstyche_error_output}" ]; then
      echo "✅ all tests (*.tst.ts) passed."
    else
      tstyche_result=$(echo $tstyche_error_output | jq -Rsa . | sed -e 's/^"//' -e 's/"$//')
      tstyche_result="The submitted code did compile but at least one of the type-tests failed. We have collected the failing test encountered. At this moment the error messages are not very read-friendly, but it's a start. We are working on a more helpful output.\n-------------------------------\n${tstyche_result}"
      echo "{ \"version\": 1, \"status\": \"error\", \"message\": \"$tstyche_result\" }" > $result_file
      sed -Ei ':a;N;$!ba;s/\r{0,1}\n/\\n/g' $result_file

      echo "❌ not all tests (*.tst.ts) passed."

      echo ""
      echo "If the solution previously contained configuration files,    "
      echo "they were disabled and now need to be restored."
      echo ""

      # Restore configuration files
      if test -f "${OUTPUT}babel.config.js.💥.bak"; then
        echo "✔️  restoring babel.config.js in output"
        unlink "${OUTPUT}babel.config.js"
        mv "${OUTPUT}babel.config.js.💥.bak" "${OUTPUT}babel.config.js" || true
      fi;

      if test -f "${OUTPUT}package.json.💥.bak"; then
        echo "✔️  restoring package.json in output"
        unlink "${OUTPUT}package.json"
        mv "${OUTPUT}package.json.💥.bak" "${OUTPUT}package.json" || true
      fi;

      if test -f "${OUTPUT}tsconfig.json.💥.bak"; then
        echo "✔️  restoring tsconfig.json in output"
        mv "${OUTPUT}tsconfig.json.💥.bak" "${OUTPUT}tsconfig.json" || true
      fi;

      echo ""
      echo "---------------------------------------------------------------"
      echo "The results of this run have been written to 'results.json'."
      echo "👁️  ${result_file}"

      # Test runner didn't fail!
      exit 0
    fi;

    # TODO: use results from tstyche
  fi;
else
  # TODO: check the config file to see if tstyche tests were expected or not
  echo "✅ no type tests (*.tst.ts) discovered."
fi;

echo ""
echo "╔═════════════════════════════════════════════════════════════╗"
echo "  ➤  Step 3/3: Execution (tests: does the solution work?)     "
echo "╚═════════════════════════════════════════════════════════════╝"
echo ""

jest_tests=$(cd "${OUTPUT}" && corepack yarn jest --listTests --passWithNoTests) || false

if [ -z "${jest_tests}" ]; then
  echo "✔️  no jest tests (*.test.ts) discovered."
  if [ "$has_type_test" = true ]; then
    # TODO: check the config file to see if jest tests were expected or not
    echo ""
    echo "✅  did run type tests, so this is fine."

    # TODO: use results from tstyche
    runner_result="The type tests ran correctly. We are working on showing the individual tests results but for now, everything is fine!"
    echo "{ \"version\": 1, \"status\": \"pass\", \"message\": \"$runner_result\" }" > $result_file
  else
    echo "❌ neither type tests, nor execution tests ran"
    runner_result="The submitted code was not subjected to any type or execution tests. It did compile correctly, but something is wrong because at least one test was expected."
    echo "{ \"version\": 1, \"status\": \"error\", \"message\": \"$runner_result\" }" > $result_file
    sed -Ei ':a;N;$!ba;s/\r{0,1}\n/\\n/g' $result_file
  fi

  echo ""
  echo "If the solution previously contained configuration files,    "
  echo "they were disabled and now need to be restored."
  echo ""

  # Restore configuration files
  if test -f "${OUTPUT}babel.config.js.💥.bak"; then
    echo "✔️  restoring babel.config.js in output"
    unlink "${OUTPUT}babel.config.js"
    mv "${OUTPUT}babel.config.js.💥.bak" "${OUTPUT}babel.config.js" || true
  fi;

  if test -f "${OUTPUT}package.json.💥.bak"; then
    echo "✔️  restoring package.json in output"
    unlink "${OUTPUT}package.json"
    mv "${OUTPUT}package.json.💥.bak" "${OUTPUT}package.json" || true
  fi;

  if test -f "${OUTPUT}tsconfig.json.💥.bak"; then
    echo "✔️  restoring tsconfig.json in output"
    mv "${OUTPUT}tsconfig.json.💥.bak" "${OUTPUT}tsconfig.json" || true
  fi;

  echo ""
  echo "---------------------------------------------------------------"
  echo "The results of this run have been written to 'results.json'."
  echo "👁️  ${result_file}"

  # Test runner didn't fail!
  exit 0
fi

echo "✔️  jest tests (*.test.ts) discovered."
echo $jest_tests

# Run tests
echo ""
echo "⚙️  corepack yarn jest <...>"
echo ""

cd "${OUTPUT}" && YARN_ENABLE_OFFLINE_MODE=1 corepack yarn run jest "${OUTPUT}*" \
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

if [ $test_exit -eq 1 ]; then
  echo "❌ not all tests (*.test.ts) passed."
else
  echo "✅ all tests (*.test.ts) passed."
fi;

echo ""
echo "If the solution previously contained configuration files,    "
echo "they were disabled and now need to be restored."
echo ""

# Restore configuration files
if test -f "${OUTPUT}babel.config.js.💥.bak"; then
  echo "✔️  restoring babel.config.js in output"
  unlink "${OUTPUT}babel.config.js"
  mv "${OUTPUT}babel.config.js.💥.bak" "${OUTPUT}babel.config.js" || true
fi;

if test -f "${OUTPUT}package.json.💥.bak"; then
  echo "✔️  restoring package.json in output"
  unlink "${OUTPUT}package.json"
  mv "${OUTPUT}package.json.💥.bak" "${OUTPUT}package.json" || true
fi;

if test -f "${OUTPUT}tsconfig.json.💥.bak"; then
  echo "✔️  restoring tsconfig.json in output"
  mv "${OUTPUT}tsconfig.json.💥.bak" "${OUTPUT}tsconfig.json" || true
fi;

echo ""
echo "---------------------------------------------------------------"
echo "The results of this run have been written to 'results.json'."
echo "👁️  ${result_file}"
echo ""

if [ $test_exit -eq 1 ]; then
  exit 0
else
  exit $test_exit
fi
