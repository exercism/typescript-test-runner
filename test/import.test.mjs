import { join } from 'node:path'
import shelljs from 'shelljs'
import { assertPass } from './asserts.mjs'
import { fixtures } from './paths.mjs'

shelljs.echo('importing node:crypto > passing solution')
assertPass('dnd-character', join(fixtures, 'dnd-character', 'peerreynders'))
