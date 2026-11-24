// Runs the track's Jest-style test files on Node's built-in test runner.
//
// bin/run.sh preloads this file with `node --require`, so it runs before the
// test file loads. bin/compile.cjs has already written the solution and the
// test file as JavaScript, and Node loads those files as native ES modules.
// Jest used to load every file through Babel first.
//
// bin/compile.cjs also rewrote the import paths in that JavaScript, so Node
// finds every file without a module hook. Before the test file loads, this
// file loads jest-globals.mjs, which provides the Jest API on top of
// node:test.
//
// Worker threads started by a solution also run this file, because they
// inherit Node's options. Only the main thread needs it, and loading the
// Jest API would make every worker start much more slowly.
import { isMainThread } from 'node:worker_threads'

if (isMainThread) {
  // Jest ran with --colors, which makes chalk colour the messages from
  // `expect`. Node has no such option, so this adds the flag to the process's
  // arguments, where chalk looks for it, before Jest's packages load.
  process.argv.push('--colors')

  // jest-globals.mjs is an ES module, and Node can require it because it has
  // no top-level await.
  require('./jest-globals.mjs')
}
