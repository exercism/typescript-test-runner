import { afterEach, describe, expect, jest, test } from '@jest/globals'
import { spawnSync } from 'node:child_process'
import { lstat, mkdtempSync, readFileSync, unlink } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'

const root = resolve(__dirname, '..')
const fixtures = resolve(__dirname, 'fixtures')
const bin = resolve(root, 'bin')
const run = resolve(bin, 'run.sh')

describe('typescript-test-runner', () => {
  jest.setTimeout(120 * 1000)

  describe('passing solution', () => {
    const resultPath = join(fixtures, 'two-fer', 'pass', 'results.json')

    afterEach(() => {
      unlink(resultPath, () => {
        /** noop */
      })
    })

    test('can run the tests', () => {
      const spawned = spawnSync(
        'bash',
        [run, 'two-fer', join(fixtures, 'two-fer', 'pass')],
        {
          stdio: 'pipe',
          cwd: root,
        }
      )

      if (spawned.stderr?.length) {
        console.warn('Did not expect anything logged to stderr.')
        console.warn(spawned.stderr.toString())
      }

      expect(spawned.status).toBe(0)
    })

    test('generates a result.json', () => {
      spawnSync('bash', [run, 'two-fer', join(fixtures, 'two-fer', 'pass')], {
        stdio: 'pipe',
        cwd: root,
      })

      return new Promise((resolve, reject) => {
        lstat(resultPath, (err, _) => {
          expect(err).toBeNull()

          const result = JSON.parse(readFileSync(resultPath).toString()) as {
            status: string
          }
          expect(result.status).toBe('pass')

          if (err) {
            reject(err)
          } else {
            resolve('')
          }
        })
      })
    })

    test('generates a result.json at the correct location', () => {
      const outputDir = mkdtempSync(join(tmpdir(), 'foo-'))

      spawnSync(
        'bash',
        [run, 'clock', join(fixtures, 'clock', 'pass'), outputDir],
        {
          stdio: 'pipe',
          cwd: root,
        }
      )

      return new Promise((resolve, reject) => {
        lstat(join(outputDir, 'results.json'), (err, _) => {
          expect(err).toBeNull()

          if (err) {
            reject(err)
          } else {
            resolve('')
          }
        })
      })
    })
  })

  const failures = ['tests', 'empty']
  failures.forEach((cause) => {
    describe(`failing solution (${cause})`, () => {
      const resultPath = join(
        fixtures,
        'two-fer',
        'fail',
        cause,
        'results.json'
      )

      afterEach(() => {
        unlink(resultPath, () => {
          /** noop */
        })
      })

      test('can run the tests', () => {
        const spawned = spawnSync(
          'bash',
          [run, 'two-fer', join(fixtures, 'two-fer', 'fail', cause)],
          {
            stdio: 'pipe',
            cwd: root,
          }
        )

        // Even when the tests fail, the status should be 0
        // 0: passed
        // 1: tests failed (jest)
        // 2: could not compile (tsc)
        //
        // In case of a captured 1 or 2, they should be converted back to 0
        expect(spawned.status).toBe(0)
      })

      test('generates a result.json', () => {
        spawnSync(
          'bash',
          [run, 'two-fer', join(fixtures, 'two-fer', 'fail', cause)],
          {
            stdio: 'pipe',
            cwd: root,
          }
        )

        return new Promise((resolve, reject) => {
          lstat(resultPath, (err, _) => {
            expect(err).toBeNull()

            const result = JSON.parse(readFileSync(resultPath).toString()) as {
              status: string
            }
            expect(result.status).toBe('fail')

            if (err) {
              reject(err)
            } else {
              resolve('')
            }
          })
        })
      })

      test('generates a result.json at the correct location', () => {
        const outputDir = mkdtempSync(join(tmpdir(), 'foo-'))

        spawnSync(
          'bash',
          [run, 'two-fer', join(fixtures, 'two-fer', 'fail', cause), outputDir],
          {
            stdio: 'pipe',
            cwd: root,
          }
        )

        return new Promise((resolve, reject) => {
          lstat(join(outputDir, 'results.json'), (err, _) => {
            expect(err).toBeNull()

            if (err) {
              reject(err)
            } else {
              resolve('')
            }
          })
        })
      })
    })
  })

  const errors = ['missing', 'syntax', 'malformed_tests']
  errors.forEach((cause) => {
    describe(`error solution (${cause})`, () => {
      const resultPath = join(
        fixtures,
        'two-fer',
        'error',
        cause,
        'results.json'
      )

      afterEach(() => {
        unlink(resultPath, () => {
          /** noop */
        })
      })

      test('can run the tests', () => {
        const spawned = spawnSync(
          'bash',
          [run, 'two-fer', join(fixtures, 'two-fer', 'error', cause)],
          {
            stdio: 'pipe',
            cwd: root,
          }
        )

        // Even when the tests fail, the status should be 0
        // 0: passed
        // 1: tests failed (jest)
        // 2: could not compile (tsc)
        //
        // In case of a captured 1 or 2, they should be converted back to 0
        expect(spawned.status).toBe(0)
      })

      test('generates a result.json', () => {
        spawnSync(
          'bash',
          [run, 'two-fer', join(fixtures, 'two-fer', 'error', cause)],
          {
            stdio: 'pipe',
            cwd: root,
          }
        )

        return new Promise((resolve, reject) => {
          lstat(resultPath, (err, _) => {
            expect(err).toBeNull()

            const result = JSON.parse(readFileSync(resultPath).toString()) as {
              status: string
              message: string | undefined
            }

            expect(result.status).toBe('error')
            expect(result.message).not.toBeUndefined()

            if (err) {
              reject(err)
            } else {
              resolve('')
            }
          })
        })
      })

      test('generates a result.json at the correct location', () => {
        const outputDir = mkdtempSync(join(tmpdir(), 'foo-'))

        spawnSync(
          'bash',
          [
            run,
            'two-fer',
            join(fixtures, 'two-fer', 'error', cause),
            outputDir,
          ],
          {
            stdio: 'pipe',
            cwd: root,
          }
        )

        return new Promise((resolve, reject) => {
          lstat(join(outputDir, 'results.json'), (err, _) => {
            expect(err).toBeNull()

            if (err) {
              reject(err)
            } else {
              resolve('')
            }
          })
        })
      })
    })
  })
})
