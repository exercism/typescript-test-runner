import { join } from 'node:path'
import shelljs from 'shelljs'
import { assertPass } from './asserts.mjs'
import { fixtures } from './paths.mjs'

// run this file like:
// corepack yarn dlx cross-env SILENT=0 corepack yarn node test/dev.test.mjs

shelljs.echo(
  'typescript-test-runner > passing solution (jest + tstyche) > no output directory'
)
assertPass(
  'lasagna',
  join(fixtures, 'lasagna', 'pass'),
  join(fixtures, 'lasagna', 'pass')
)
