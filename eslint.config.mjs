// @ts-check

import config from '@exercism/eslint-config-tooling'

export default [
  ...config,
  {
    ignores: [
      '.appends/**/*',
      '.github/**/*',
      '.vscode/**/*',
      '.yarn/**/*',
      'bin/**/*',
      'dist/**/*',
      'test/fixtures/**/*',
      'test_exercises/**/*',
      '.pnp.*',
      'babel.config.js',
      'jest.config.js',
      'jest.runner.config.js',
    ],
  },
]
