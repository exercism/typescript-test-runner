// Synopsis:
// Preloaded (node --require) before the tests run under Node's built-in test
// runner. It gives the tests the parts of Jest they use: describe, it, test,
// xit, xtest, xdescribe, the hooks, Jest's own `expect` and `jest.fn`. Tests
// get them as globals, or by importing `@jest/globals`, which bin/compile.cjs
// points at this module.

import * as nodeTest from 'node:test'
import { expect } from 'expect'
import { ModuleMocker } from 'jest-mock'
import { captureConsole } from './console.cjs'

captureConsole()

// The tests call Node's functions directly, so Node records the test file
// and line of each test. The tests in the track take no arguments and no
// timeout, so Jest's and Node's signatures agree.
export const { describe, it, test } = nodeTest
export const xdescribe = describe.skip
export const xit = it.skip
export const xtest = test.skip

export const beforeAll = nodeTest.before
export const afterAll = nodeTest.after
export const beforeEach = nodeTest.beforeEach
export const afterEach = nodeTest.afterEach

const mocker = new ModuleMocker(globalThis)
export const jest = {
  fn: mocker.fn.bind(mocker),
  spyOn: mocker.spyOn.bind(mocker),
  clearAllMocks: mocker.clearAllMocks.bind(mocker),
  resetAllMocks: mocker.resetAllMocks.bind(mocker),
  restoreAllMocks: mocker.restoreAllMocks.bind(mocker),
}

export { expect }

Object.assign(globalThis, {
  it,
  test,
  xit,
  xtest,
  describe,
  xdescribe,
  beforeAll,
  afterAll,
  beforeEach,
  afterEach,
  expect,
  jest,
})
