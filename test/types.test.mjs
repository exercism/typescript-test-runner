import { join } from 'node:path'
import shelljs from 'shelljs'
import { assertError, assertPass } from './asserts.mjs'
import { fixtures } from './paths.mjs'

shelljs.echo('type tests (only) > documentation solution (smoke test)')
assertPass('tstyche', join(fixtures, 'tstyche', 'documentation'))

shelljs.echo('type tests (only) > failing solution')
assertError('tstyche', join(fixtures, 'tstyche', 'fire'))

shelljs.echo('type tests (only) > passing solution')
assertPass('tstyche', join(fixtures, 'tstyche', 'firefought'))
