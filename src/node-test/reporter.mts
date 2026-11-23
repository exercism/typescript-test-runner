// Synopsis:
// A reporter for Node's built-in test runner (node --test-reporter). It
// collects every test's result and writes results.json (version 3) to the
// reporter's destination, in the same shape as the Jest reporter did.

import path from 'node:path'
import type { TestOutcome } from '../output.js'
import { consoleEntries } from './console.cjs'

interface TestFailure extends Error {
  cause?: unknown
}

// The parts of Node's test runner events used here. The runner's
// @types/node is kept at the version used to type-check solutions, which
// does not describe all of them.
type TestEvent =
  | { type: 'test:start'; data: { name: string; nesting: number } }
  | {
      type: 'test:pass' | 'test:fail'
      data: {
        name: string
        nesting: number
        file?: string
        skip?: string | boolean
        todo?: string | boolean
        details: { type?: 'suite' | 'test'; error?: unknown }
      }
    }
  | { type: 'test:summary'; data: { counts: { topLevel: number } } }
  | { type: 'other'; data: unknown }

export default async function* reporter(
  source: AsyncIterable<TestEvent>
): AsyncGenerator<string> {
  // The repo's own CI installs the packages with Yarn Plug'n'Play. There,
  // with --test-isolation=none, a package imported while Node loads the
  // reporter does not resolve. Loading it once the run has started works.
  const { Output } = await import('../output.js')
  const output = new Output(process.cwd())
  const ancestors: string[] = []
  const outcomes = new Map<string, TestOutcome[]>()
  let skipped = 0

  for await (const event of source) {
    switch (event.type) {
      case 'test:start':
        // Tests run one at a time, so the tests started before this one at
        // a lower nesting level are the describe blocks around it.
        ancestors.length = event.data.nesting
        ancestors.push(event.data.name)
        break

      case 'test:pass':
      case 'test:fail': {
        const { data } = event
        if (data.details.type !== 'test' || !data.file) {
          break
        }

        const specFilePath = output.sourceOf(data.file)
        const error = data.details.error as TestFailure | undefined

        // Node reports a test named after the test file itself when the
        // file fails to load, or when it loads but defines no tests. Jest
        // reported both as "Test suite failed to run".
        if (data.nesting === 0 && path.resolve(data.name) === data.file) {
          output.suiteFailed(
            specFilePath,
            error ?? 'Your test suite must contain at least one test.'
          )
          break
        }

        if (data.skip || data.todo) {
          skipped += 1
          break
        }

        const fileOutcomes = outcomes.get(specFilePath) ?? []
        fileOutcomes.push({
          name: ancestors.slice(0, data.nesting).concat(data.name).join(' > '),
          error: error ? (error.cause ?? error) : undefined,
        })
        outcomes.set(specFilePath, fileOutcomes)
        break
      }

      case 'test:summary':
        for (const [specFilePath, fileOutcomes] of outcomes) {
          output.fileFinished(specFilePath, fileOutcomes, consoleEntries)
        }

        yield output.finish({
          topLevel: event.data.counts.topLevel,
          skipped,
        })
        break
    }
  }
}
