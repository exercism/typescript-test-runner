# Exercism TypeScript Test Runner

[![typescript-test-runner / deploy](https://github.com/exercism/typescript-test-runner/actions/workflows/deploy.yml/badge.svg)](https://github.com/exercism/typescript-test-runner/actions/workflows/deploy.yml) [![typescript-test-runner / main](https://github.com/exercism/typescript-test-runner/actions/workflows/ci.js.yml/badge.svg)](https://github.com/exercism/typescript-test-runner/actions/workflows/ci.js.yml)

The Docker image for automatically run tests on TypeScript solutions submitted to [exercism][web-exercism].

> At this moment, the input path _must_ be relative to the `package.json` of this respository.
> `jest` doesn't like running outside of its tree. This might change in the future.

## Installation

Clone this repository and then run:

```bash
corepack enable yarn
corepack yarn install
```

You'll need at least Node LTS for this to work.

```
corepack yarn build
```

## Usage

If you're developing this, you can run this via `yarn` or the provided shell script.

- `.sh` enabled systems (UNIX, WSL): `corepack yarn execute:dev`
- `.bat` fallback (cmd.exe, Git Bash for Windows): _unsupported_

You'll want these `:dev` variants because it will _build_ the required code (it will transpile from TypeScript to JavaScript, which is necessary to run this in Node environments, unlike Deno environments).
When on Windows, if you're using Git Bash for Windows or a similar terminal, the `.sh` files will work, but will open a new window (which closes after execution).
The `.bat` scripts will work in the same terminal.
In this case it might be much easier to run `bin/run.sh` directly, so a new shell won't open.

You can also manually build using `corepack yarn` or `corepack yarn build`, and then run the script directly: `./bin/run.sh arg1 arg2 arg3`.

## Running the Solution's Tests

To run a solution's tests, do the following:

1. Open terminal in project's root
2. Run `./bin/run.sh <exercise-slug> <path-to-solution-folder> [<path-to-output-folder>]`

For example:

```shell
$ ./bin/run.sh two-fer ./test/fixtures/two-fer/pass

PASS  test/fixtures/two-fer/pass/two-fer.spec.js
Test Suites: 1 passed, 1 total
Tests:       3 passed, 3 total
Snapshots:   0 total
Time:        2.817s
Find the output at:
test/fixtures/two-fer/pass/results.json
```

## Running the Tests of a Remote Solution

Instead of passing in an `<exercises-slug>` and `<path-to-solution-folder>`, you can also directly pass in an `https://exercism.io` url, as long as you have the `exercism` CLI installed.

You can pass the following type of URLs:

- Published solutions: `/tracks/typescript/exercises/<slug>/<id>`
- Mentor solutions: `/mentor/solutions/<id>`
- Your solutions: `/my/solutions/<id>`
- Private solutions: `/solutions/<id>`

For example:

```
$ ./bin/run.sh https://exercism.io/my/solutions/c3b826d95cb54441a8f354d7663e9e16
Exercism remote UUID: c3b826d95cb54441a8f354d7663e9e16

Downloaded to
C:\Users\Derk-Jan\Exercism\typescript\clock
PASS  tmp/clock/c3b826d95cb54441a8f354d7663e9e16/clock/clock.spec.js
Test Suites: 1 passed, 1 total
Tests:       52 passed, 52 total
Snapshots:   0 total
Time:        2.987s
Find the output at:
./tmp/clock/c3b826d95cb54441a8f354d7663e9e16/clock/results.json
```

As you can see, it will be copied to a local directory.
It's up to you to clean-up this directory.

## Running the Solution's Tests in Docker container

_This script is provided for testing purposes_

To run a solution's test in the Docker container, do the following:

1. Open terminal in project's root
2. Run `./run-in-docker.sh <exercise-slug> <relative-path-to-solution-folder>`

## Maintaining

The `package.json` needs to be in-sync with the [`typescript` exercise `package.json`][git-typescript].

Ensure SDKs are installed if using vscode to interopt with Yarn PnP:

```shell
corepack yarn dlx @yarnpkg/sdks vscode

➤ YN0000: ┌ Generating SDKs inside .yarn/sdks
➤ YN0000: │ ✓ Eslint
➤ YN0000: │ ✓ Prettier
➤ YN0000: │ ✓ Typescript
➤ YN0000: │ • 5 SDKs were skipped based on your root dependencies
➤ YN0000: └ Completed
➤ YN0000: ┌ Generating settings
➤ YN0000: │ ✓ Vscode (new ✨)
➤ YN0000: └ Completed
```

### Testing

Running the tests of the test-runner itself can be achieved by using the `test` script from `package.json`.
The tests delegate to the _build output_, which is why `corepack yarn test` first calls `corepack yarn build` before running `corepack yarn test:bare`.

You can run individual test sets:

```shell
$ corepack yarn node test/skip.test.mjs

skipping via test.skip > passing solution
assert pass
```

Or turn on output by setting `SILENT=0`. On Windows (requires Git Bash or similar) that would become:

```shell
$ corepack yarn dlx cross-env SILENT=0 corepack yarn node test/skip.test.mjs

➤ YN0000: · Yarn 4.3.1
➤ YN0000: ┌ Resolution step
➤ YN0085: │ + cross-env@npm:7.0.3, cross-spawn@npm:7.0.3, isexe@npm:2.0.0, path-key@npm:3.1.1, shebang-command@npm:2.0.0, shebang-regex@npm:3.0.0, which@npm:2.0.2
➤ YN0000: └ Completed
➤ YN0000: ┌ Fetch step
➤ YN0000: └ Completed
➤ YN0000: ┌ Link step
➤ YN0000: └ Completed
➤ YN0000: · Done in 0s 232ms

skipping via test.skip > passing solution

╔═════════════════════════════════════════════════════════════╗
  🔧 Process input arguments for run
╚═════════════════════════════════════════════════════════════╝

✔️  Using reporter : C:/Users/Derk-Jan/Documents/GitHub/exercism/typescript-test-runner/dist/reporter.js
✔️  Using test-root: C:/Users/Derk-Jan/Documents/GitHub/exercism/typescript-test-runner/test/fixtures/pythagorean-triplet/chroth7/
✔️  Using base-root: C:/Users/Derk-Jan/Documents/GitHub/exercism/typescript-test-runner
✔️  Using setup-env: C:/Users/Derk-Jan/Documents/GitHub/exercism/typescript-test-runner/dist/jest/setup.js

╔═════════════════════════════════════════════════════════════╗
  🔧 Preparing run
╚═════════════════════════════════════════════════════════════╝

Input does not match output directory.
👁️  C:/Users/Derk-Jan/AppData/Local/Temp/foo-xbaeYM/
✔️  Copying C:/Users/Derk-Jan/Documents/GitHub/exercism/typescript-test-runner/test/fixtures/pythagorean-triplet/chroth7/ to output.

If the solution contains babel.config.js, package.json,
or tsconfig.json at the root, these configuration files will
be used during the test-runner process which we do not want.
The test-runner will therefore temporarily rename these files.

✔️  renaming babel.config.js in output so it can be replaced.
✔️  renaming package.json in output so it can be replaced.
✔️  renaming tsconfig.json in output so it can be replaced.

The output directory is likely not placed inside the test
runner root. This means the CLI tools need configuration
files as given and understood by the test-runner for running
the tests. Will now turn the output directory into a
standalone package.

✔️  .yarn cache from root to output
✔️  .yarnrc.yml from root to output
✔️  .yarn.lock from root to output
✔️  .pnp.cjs from root to output
✔️  .pnp.loader.mjs from root to output
✔️  babel.config.js from root to output
✔️  package.json from root to output
✔️  tsconfig.json from root to output

The results of this run will be written to 'results.json'.
👁️  C:/Users/Derk-Jan/AppData/Local/Temp/foo-xbaeYM/results.json

╔═════════════════════════════════════════════════════════════╗
  🔧 Preparing test suite file(s)
╚═════════════════════════════════════════════════════════════╝

There is a configuration file in the expected .meta location
which will now be used to determine which test files to prep.
👁️  C:/Users/Derk-Jan/Documents/GitHub/exercism/typescript-test-runner/test/fixtures/pythagorean-triplet/chroth7/.meta/config.json
{
  "blurb": "There exists exactly one Pythagorean triplet for which a + b + c = 1000. Find the product a * b * c.",
  "authors": ["mdowds"],
  "contributors": ["masters3d", "mdmower", "SleeplessByte"],
  "files": {
    "solution": ["pythagorean-triplet.ts"],
    "test": ["pythagorean-triplet.test.ts"],
    "example": [".meta/proof.ci.ts"]
  },
  "source": "Problem 9 at Project Euler",
  "source_url": "http://projecteuler.net/problem=9"
}

Enabling tests in C:/Users/Derk-Jan/AppData/Local/Temp/foo-xbaeYM/pythagorean-triplet.test.ts

╔═════════════════════════════════════════════════════════════╗
  🔧 Preparing test project
╚═════════════════════════════════════════════════════════════╝

✔️  enabling corepack
✔️  yarn version now: 4.3.1

✔️  standalone package found installing packages from cache

total 3779
drwxr-xr-x 1 197612 197612      0 Jul 31 23:03 .
drwxr-xr-x 1 197612 197612      0 Jul 31 23:03 ..
drwxr-xr-x 1 197612 197612      0 Jul 31 23:03 .docs
-rw-r--r-- 1 197612 197612    132 Jul 31 23:03 .eslintignore
-rw-r--r-- 1 197612 197612    518 Jul 31 23:03 .eslintrc
drwxr-xr-x 1 197612 197612      0 Jul 31 23:03 .meta
-rwxr-xr-x 1 197612 197612 884757 Jul 31 23:03 .pnp.cjs
-rw-r--r-- 1 197612 197612  73628 Jul 31 23:03 .pnp.loader.mjs
drwxr-xr-x 1 197612 197612      0 Jul 31 23:03 .yarn
-rw-r--r-- 1 197612 197612    235 Jul 31 23:03 .yarnrc.yml
-rw-r--r-- 1 197612 197612    257 Jul 31 23:03 babel.config.js
-rw-r--r-- 1 197612 197612    374 Jul 31 23:03 babel.config.js.💥.bak
-rw-r--r-- 1 197612 197612   2332 Jul 31 23:03 expected_results.json
-rw-r--r-- 1 197612 197612    407 Jul 31 23:03 jest.config.js
-rw-r--r-- 1 197612 197612   2182 Jul 31 23:03 package.json
-rw-r--r-- 1 197612 197612    992 Jul 31 23:03 package.json.💥.bak
-rw-r--r-- 1 197612 197612   1902 Jul 31 23:03 pythagorean-triplet.test.ts
-rw-r--r-- 1 197612 197612   1461 Jul 31 23:03 pythagorean-triplet.ts
-rw-r--r-- 1 197612 197612   2332 Jul 31 23:03 results.json
-rw-r--r-- 1 197612 197612   1262 Jul 31 23:03 tsconfig.json
-rw-r--r-- 1 197612 197612    487 Jul 31 23:03 tsconfig.json.💥.bak
-rw-r--r-- 1 197612 197612 249470 Jul 31 23:03 yarn.lock

➤ YN0000: · Yarn 4.3.1
➤ YN0000: ┌ Project validation
➤ YN0090: │ Offline work is enabled; Yarn won't fetch packages from the remote registry if it can avoid it
➤ YN0000: └ Completed
➤ YN0000: ┌ Resolution step
➤ YN0000: └ Completed in 0s 502ms
➤ YN0000: ┌ Post-resolution validation
➤ YN0060: │ eslint is listed by your project with version 9.8.0 (pc52f3), which doesn't satisfy what @exercism/eslint-config-tooling and other dependencies request (but they have non-overlapping ranges!).
➤ YN0002: │ @exercism/typescript-test-runner@workspace:. doesn't provide @babel/core (p9b671), requested by babel-jest.
➤ YN0086: │ Some peer dependencies are incorrectly met by your project; run yarn explain peer-requirements <hash> for details, where <hash> is the six-letter p-prefixed code.
➤ YN0086: │ Some peer dependencies are incorrectly met by dependencies; run yarn explain peer-requirements for details.
➤ YN0000: └ Completed
➤ YN0000: ┌ Fetch step
➤ YN0000: └ Completed
➤ YN0000: ┌ Link step
➤ YN0000: │ ESM support for PnP uses the experimental loader API and is therefore experimental
➤ YN0008: │ core-js@npm:3.37.1 must be rebuilt because its dependency tree changed
➤ YN0000: └ Completed in 0s 239ms
➤ YN0000: · Done with warnings in 0s 952ms

╔═════════════════════════════════════════════════════════════╗
  ➤  Step 1/3: Build (tests: does it compile?)
╚═════════════════════════════════════════════════════════════╝

✔️  found a tsconfig.json (as expected)
👁️  C:/Users/Derk-Jan/AppData/Local/Temp/foo-xbaeYM/tsconfig.json
{
  "extends": "@tsconfig/node20/tsconfig.json",
  "compilerOptions": {
    // Allows you to use the newest syntax, and have access to console.log
    // https://www.typescriptlang.org/tsconfig#lib
    "lib": ["ES2020", "dom"],
    // Make sure typescript is configured to output ESM
    // https://gist.github.com/sindresorhus/a39789f98801d908bbc7ff3ecc99d99c#how-can-i-make-my-typescript-project-output-esm
    "module": "Node16",
    // Since this project is using babel, TypeScript may target something very
    // high, and babel will make sure it runs on your local Node version.
    // https://babeljs.io/docs/en/
    "target": "ES2020", // ESLint doesn't support this yet: "es2022",

    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,

    // Because jest-resolve isn't like node resolve, the absolute path must be .ts
    "allowImportingTsExtensions": true,
    "noEmit": true,

    // Because we'll be using babel: ensure that Babel can safely transpile
    // files in the TypeScript project.
    //
    // https://babeljs.io/docs/en/babel-plugin-transform-typescript/#caveats
    "isolatedModules": true
  },
  "exclude": [".meta/*", "__typetests__/*", "*.test.ts", "*.tst.ts"]
}

⚙️  corepack yarn run tsc


✅ tsc compilation success

╔═════════════════════════════════════════════════════════════╗
  ➤  Step 2/3: Type tests (tests: are the types as expected?)
╚═════════════════════════════════════════════════════════════╝

✅ no type tests (*.tst.ts) discovered.

╔═════════════════════════════════════════════════════════════╗
  ➤  Step 3/3: Execution (tests: does the solution work?)
╚═════════════════════════════════════════════════════════════╝

✔️  jest tests (*.test.ts) discovered.
C:\Users\Derk-Jan\AppData\Local\Temp\foo-xbaeYM\pythagorean-triplet.test.ts

⚙️  corepack yarn jest <...>

✅ all tests (*.test.ts) passed.

If the solution previously contained configuration files,
they were disabled and now need to be restored.

✔️  restoring babel.config.js in output
✔️  restoring package.json in output
✔️  restoring tsconfig.json in output

---------------------------------------------------------------
The results of this run have been written to 'results.json'.
👁️  C:/Users/Derk-Jan/AppData/Local/Temp/foo-xbaeYM/results.json

assert pass
```

[web-exercism]: https://exercism.io
[git-automated-tests]: https://github.com/exercism/automated-tests
[git-typescript]: https://github.com/exercism/typescript
