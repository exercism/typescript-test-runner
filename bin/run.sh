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

# Read the files a run needs into the page cache, 8 at a time, in the
# background. The Docker image records the list at build time. On a machine
# where the image's files are not in the page cache yet, Node read them one
# at a time as it needed them, which took several seconds per run.
if test -f "${ROOT}/.prefetch-list"; then
  ( nice -n 19 xargs -P 8 -n 50 -a "${ROOT}/.prefetch-list" cat > /dev/null 2>&1 & )
fi
REPORTER="$ROOT/dist/reporter.mjs"
SETUP="$ROOT/dist/setup.cjs"

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

echo "If the solution contains package.json or tsconfig.json at the  "
echo "root, these configuration files will                          "
echo "be used during the test-runner process which we do not want.   "
echo "The test-runner will therefore temporarily rename these files."
echo ""

# Rename configuration files
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

  if test -f "${OUTPUT}yarn.lock"; then
    echo "✔️  renaming yarn.lock in output to prevent yarn from      "
    echo "   interpreting this directory as a standalone package."
    mv "${OUTPUT}yarn.lock" "${OUTPUT}yarn.lock.💥.bak" || true
  fi;

  echo ""
else
  echo ""
  echo "The output directory is likely not placed inside the test    "
  echo "runner root. This means the CLI tools need configuration     "
  echo "files as given and understood by the test-runner for running "
  echo "the tests. Will now turn the output directory into a         "
  echo "standalone package."
  echo ""

  # Link to the runner's node_modules, so tsc and tstyche find the types and
  # packages they need. Node resolves the link to the real folder.
  if ! test -e "${OUTPUT}node_modules"; then
    echo "✔️  node_modules from root to output (link)"
    ln -s "${ROOT}/node_modules" "${OUTPUT}node_modules"
  fi

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

  # Every exercise has at most one test file for Node's test runner. The
  # other test files are type tests (*.tst.ts).
  test_file=$(jq -r '[.files.test[] | select(endswith(".test.ts"))][0] // empty' "${configuration_file}")
else
  if test -f $local_configuration_file; then
    echo "There is a configuration file in the .exercism local       "
    echo "location which will now be used to determine which test    "
    echo "files to prep."
    echo "👁️  ${local_configuration_file}"
    cat "${local_configuration_file}"
    echo ""

    cat $local_configuration_file | jq -c '.files.test[]' | xargs -L 1 "$ROOT/bin/prepare.sh" ${OUTPUT}

    # Every exercise has at most one test file for Node's test runner. The
    # other test files are type tests (*.tst.ts).
    test_file=$(jq -r '[.files.test[] | select(endswith(".test.ts"))][0] // empty' "${local_configuration_file}")
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
      if test -f "${OUTPUT}package.json.💥.bak"; then
        echo "✔️  restoring package.json in output"
        if test -f "${OUTPUT}package.json"; then
          unlink "${OUTPUT}package.json"
        fi
        mv "${OUTPUT}package.json.💥.bak" "${OUTPUT}package.json" || true
      fi;

      if test -f "${OUTPUT}tsconfig.json.💥.bak"; then
        echo "✔️  restoring tsconfig.json in output"
        mv "${OUTPUT}tsconfig.json.💥.bak" "${OUTPUT}tsconfig.json" || true
      fi;

      if test -f "${OUTPUT}yarn.lock.💥.bak"; then
        echo "✔️  restoring yarn.lock in output"
        if test -f "${OUTPUT}yarn.lock"; then
          unlink "${OUTPUT}yarn.lock"
        fi
        mv "${OUTPUT}yarn.lock.💥.bak" "${OUTPUT}yarn.lock" || true
      fi;

      result="The submitted code cannot be ran by the test-runner. There is no configuration file inside the .meta (or .exercism) directory, and the fallback test file '${test_file}' does not exist. Please fix these issues and resubmit."
      echo "{ \"version\": 1, \"status\": \"error\", \"message\": \"${result}\" }" > $result_file
      sed -Ei ':a;N;$!ba;s/\r{0,1}\n/\\n/g' $result_file

      echo "❌ could not run the test suite(s). A valid output exists:"
      echo "${result}"
      echo "---------------------------------------------------------------"

      # Test runner didn't fail!
      exit 0
    fi
  fi
fi

# Look for type tests (*.tst.ts). If there are any, bin/compile.cjs runs
# them with tstyche after the type check, and step 2 reads the results.
has_type_test=false
type_tests=""
if test -d "${OUTPUT}__typetests__/"; then
  type_tests=$(ls -aln1 "${OUTPUT}__typetests__/" | grep "tst.ts$" || true)
  if [ -n "${type_tests}" ]; then
    has_type_test=true
  fi
fi

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

# bin/compile.cjs type-checks the solution as `tsc --noEmit` does, with the
# same output and exit code. It then writes the JavaScript and source maps
# into COMPILED_DIR, and Node runs those files as they are.
COMPILED_DIR="$(mktemp -d)"
export COMPILED_DIR
trap 'rm -rf "${COMPILED_DIR}"' EXIT

echo "⚙️  tsc"
echo ""
tsc_result="$( cd "${OUTPUT}" && TYPE_TESTS="${has_type_test}" node "${ROOT}/bin/compile.cjs" "${COMPILED_DIR}" 2>&1 )"
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
  if test -f "${OUTPUT}package.json.💥.bak"; then
    echo "✔️  restoring package.json in output"
    if test -f "${OUTPUT}package.json"; then
      unlink "${OUTPUT}package.json"
    fi
    mv "${OUTPUT}package.json.💥.bak" "${OUTPUT}package.json" || true
  fi;

  if test -f "${OUTPUT}tsconfig.json.💥.bak"; then
    echo "✔️  restoring tsconfig.json in output"
    unlink "${OUTPUT}tsconfig.json"
    mv "${OUTPUT}tsconfig.json.💥.bak" "${OUTPUT}tsconfig.json" || true
  fi;

  if test -f "${OUTPUT}yarn.lock.💥.bak"; then
    echo "✔️  restoring yarn.lock in output"
    if test -f "${OUTPUT}yarn.lock"; then
      unlink "${OUTPUT}yarn.lock"
    fi
    mv "${OUTPUT}yarn.lock.💥.bak" "${OUTPUT}yarn.lock" || true
  fi;

  # Compose the message to show to the student
  #
  # TODO: interpret the tsc_result lines and pull out the source.
  #       We actually already have code to do this, given the cursor position
  #
  tsc_result="$(cat $result_file | jq -Rsa . | sed -e 's/^"//' -e 's/"$//')"
  tsc_result="The submitted code didn't compile. We have collected the errors encountered during compilation. At this moment the error messages are not very read-friendly, but it's a start. We are working on a more helpful output.\n-------------------------------\n${tsc_result}"
  echo "{ \"version\": 1, \"status\": \"error\", \"message\": \"${tsc_result}\" }" > $result_file
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

if test -d "${OUTPUT}__typetests__/"; then
  if [ -z "${type_tests}" ]; then
    # TODO: check the config file to see if tstyche tests were expected or not
    echo "✅ no type tests (*.tst.ts) discovered."
  else
    echo "✔️  type tests discovered."
    # List the files found above. Asking tstyche to list them (--listFiles)
    # started it an extra time.
    echo "${type_tests}"

    echo ""
    echo "⚙️  tstyche"
    echo ""
    # bin/compile.cjs ran tstyche in step 1, and wrote its output to these
    # files. Starting the tstyche command took about 3 seconds more.

    tstyche_error_output="$(cat "${OUTPUT}tstyche.stderr.txt")"

    if [ -z "${tstyche_error_output}" ]; then
      echo "✅ all tests (*.tst.ts) passed."
    else
      tstyche_result=$(echo "${tstyche_error_output}" | jq -Rsa . | sed -e 's/^"//' -e 's/"$//' | sed -E ':a;N;$!ba;s/\r{0,1}\n/\\n/g')
      tstyche_result="The submitted code did compile but at least one of the type-tests failed. We have collected the failing test encountered. At this moment the error messages are not very read-friendly, but it's a start. We are working on a more helpful output.\n-------------------------------\n${tstyche_result}"
      echo "{ \"version\": 1, \"status\": \"error\", \"message\": \"${tstyche_result}\" }" > $result_file
      sed -Ei ':a;N;$!ba;s/\r{0,1}\n/\\n/g' $result_file

      echo "❌ not all tests (*.tst.ts) passed."

      echo ""
      echo "If the solution previously contained configuration files,    "
      echo "they were disabled and now need to be restored."
      echo ""

      # Restore configuration files
      if test -f "${OUTPUT}package.json.💥.bak"; then
        echo "✔️  restoring package.json in output"
        if test -f "${OUTPUT}package.json"; then
          unlink "${OUTPUT}package.json"
        fi
        mv "${OUTPUT}package.json.💥.bak" "${OUTPUT}package.json" || true
      fi;

      if test -f "${OUTPUT}tsconfig.json.💥.bak"; then
        echo "✔️  restoring tsconfig.json in output"
        mv "${OUTPUT}tsconfig.json.💥.bak" "${OUTPUT}tsconfig.json" || true
      fi;

      if test -f "${OUTPUT}yarn.lock.💥.bak"; then
        echo "✔️  restoring yarn.lock in output"
        if test -f "${OUTPUT}yarn.lock"; then
          unlink "${OUTPUT}yarn.lock"
        fi
        mv "${OUTPUT}yarn.lock.💥.bak" "${OUTPUT}yarn.lock" || true
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
  #       flag.tests.tstyche

  echo "✅ no type tests (*.tst.ts) discovered."
fi;

echo ""
echo "╔═════════════════════════════════════════════════════════════╗"
echo "  ➤  Step 3/3: Execution (tests: does the solution work?)     "
echo "╚═════════════════════════════════════════════════════════════╝"
echo ""

if test -n "${test_file}" && test -f "${OUTPUT}${test_file}"; then
  echo "⚙️  node --test ${test_file}"
  echo ""

  # Run the tests with Node's built-in test runner. setup.cjs provides the
  # Jest API the tests use, and reporter.mjs writes results.json. Node runs
  # the JavaScript written by bin/compile.cjs.
  #
  # --enable-source-maps makes stack traces and console origins name the .ts
  # lines, as with Jest.
  # --test-isolation=none runs the test file in this process, instead of
  # starting another one, and lets the reporter read the console messages.
  # --test-force-exit stops the process once the tests have finished, even
  # if the solution leaves a timer running.
  cd "${OUTPUT}" && TEST_FILE="${OUTPUT}${test_file}" RESULTS_FILE="${result_file}" node \
    --require "${SETUP}" \
    --enable-source-maps \
    --test \
    --test-isolation=none \
    --test-force-exit \
    --test-reporter="${REPORTER}" \
    "${COMPILED_DIR}/${test_file%.ts}.js"

  # Convert exit(1) (the tests ran, but some failed) to exit(0)
  test_exit=$?

  if [ $test_exit -eq 1 ]; then
    echo "❌ not all tests (*.test.ts) passed."
  else
    echo "✅ all tests (*.test.ts) passed."
  fi;
elif [ "$has_type_test" = true ]; then
  test_exit=0
  echo "✔️  no tests (*.test.ts) discovered."
  echo ""
  echo "✅  did run type tests, so this is fine."

  # TODO: use results from tstyche
  runner_result="The type tests ran correctly. We are working on showing the individual tests results but for now, everything is fine!"
  echo "{ \"version\": 1, \"status\": \"pass\", \"message\": \"${runner_result}\" }" > $result_file
else
  # Version 3 output can't have an empty list of tests, so this uses the
  # version 1 format, which has no tests key.
  test_exit=0
  echo "{ \"version\": 1, \"status\": \"error\", \"message\": \"The submitted code was not subjected to any type or execution tests. It did compile correctly, but something is wrong because at least one test was expected.\" }" > "${result_file}"
  echo "❌ neither type tests, nor execution tests ran"
fi;

echo ""
echo "If the solution previously contained configuration files,    "
echo "they were disabled and now need to be restored."
echo ""

# Restore configuration files
if test -f "${OUTPUT}package.json.💥.bak"; then
  echo "✔️  restoring package.json in output"
  if test -f "${OUTPUT}package.json"; then
    unlink "${OUTPUT}package.json"
  fi
  mv "${OUTPUT}package.json.💥.bak" "${OUTPUT}package.json" || true
fi;

if test -f "${OUTPUT}tsconfig.json.💥.bak"; then
  echo "✔️  restoring tsconfig.json in output"
  mv "${OUTPUT}tsconfig.json.💥.bak" "${OUTPUT}tsconfig.json" || true
fi;

if test -f "${OUTPUT}yarn.lock.💥.bak"; then
  echo "✔️  restoring yarn.lock in output"
  if test -f "${OUTPUT}yarn.lock"; then
    unlink "${OUTPUT}yarn.lock"
  fi
  mv "${OUTPUT}yarn.lock.💥.bak" "${OUTPUT}yarn.lock" || true
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
