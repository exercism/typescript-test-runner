// This file is only used by jest.runner.config.js, when running the
// test-runner. The tool itself uses typescript's compilation instead.
module.exports = {
  presets: [[require('@exercism/babel-preset-typescript'), { corejs: '3.37' }]],
  plugins: [],
}
