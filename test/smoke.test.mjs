import { join } from 'node:path'
import shelljs from 'shelljs'
import { assertError, assertPass, rejectPass } from './asserts.mjs'
import { fixtures } from './paths.mjs'

/** Test passing */
shelljs.echo('typescript-test-runner > passing solution > no output directory')
assertPass(
  'two-fer',
  join(fixtures, 'two-fer', 'pass'),
  join(fixtures, 'two-fer', 'pass')
)

shelljs.echo(
  'typescript-test-runner > failing solution > with output directory'
)
assertError('clock', join(fixtures, 'clock', 'fail'))

shelljs.echo(
  'typescript-test-runner > passing solution (jest + tstyche) > no output directory'
)
assertPass(
  'lasagna',
  join(fixtures, 'lasagna', 'pass'),
  join(fixtures, 'lasagna', 'pass')
)

/** Test failures */
const failures = ['tests', 'empty']

failures.forEach((cause) => {
  const input = join(fixtures, 'two-fer', 'fail', cause)
  shelljs.echo(
    `typescript-test-runner > failing solution (${cause}) > no output directory`
  )
  rejectPass('two-fer', input, input)

  shelljs.echo(
    `typescript-test-runner > failing solution (${cause}) > with output directory`
  )
  rejectPass('two-fer', input)
})

/** Test errors */
const errors = ['missing', 'syntax', 'malformed_tests']

errors.forEach((cause) => {
  const input = join(fixtures, 'two-fer', 'error', cause)
  shelljs.echo(
    `typescript-test-runner > solution with error (${cause}) > no output directory`
  )
  assertError('two-fer', input, input)

  shelljs.echo(
    `typescript-test-runner > solution with error (${cause}) > with output directory`
  )
  assertError('two-fer', input)
})
