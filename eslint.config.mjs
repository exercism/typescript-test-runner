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
      'jest.config.js',
    ],
  },
  {
    // The shared config includes eslint-plugin-jest, which reads Jest's
    // version from the jest package. The runner no longer installs Jest.
    settings: { jest: { version: 29 } },
  },
]
