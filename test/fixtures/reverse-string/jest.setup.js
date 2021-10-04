/// <reference path="jest.d.ts" />

/**
 * Registers the task for the concept exercise
 * 
 * @param {*} taskId 
 * @param  {...any} args 
 * @returns {void}
 */
test.task = function task(taskId, ...args) {
  // The test runner will execute the following line of code
  // but this doesn't (need to) happen when you're running
  // tests locally. 
  //
  // console.log(`@exercism/typescript:task:${taskId}`)

  return test.apply(this, args)
}