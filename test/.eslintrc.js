module.exports = {
  root: true,
  parserOptions: {
    tsconfigRootDir: __dirname,
    project: ['./tsconfig.json'],
  },
  plugins: ['jest'],
  globals: {
    'jest/globals': true,
  },
  extends: ['@exercism/eslint-config-tooling', 'plugin:jest/recommended'],
}
