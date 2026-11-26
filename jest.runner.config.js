module.exports = {
  verbose: true,
  modulePathIgnorePatterns: ['package.json'],
  // bin/compile.cjs has already turned the TypeScript into JavaScript (see
  // bin/run.sh), so Jest runs the files as they are.
  transform: {},
  // The tests import the solution as './two-fer.ts'. The compiled files sit
  // next to each other as .js files.
  moduleNameMapper: {
    '^(\\.{1,2}/.*)\\.ts$': '$1.js',
  },
  // The compiled files are in a temporary folder, outside the solution, so
  // packages such as `expect` are found in the test runner's node_modules.
  modulePaths: ['<rootDir>/node_modules'],
  reporters: [],
}
