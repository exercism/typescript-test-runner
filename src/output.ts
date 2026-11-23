import { AstParser, extractTests } from '@exercism/static-analysis'
import type { ExtractedTestCase, ParsedSource } from '@exercism/static-analysis'
import fs from 'fs'
import path from 'path'

interface OutputInterface {
  status: 'fail' | 'pass' | 'error'
  message: string
  tests: OutputTestInterface[]
}

interface OutputTestInterface {
  name: string
  status: 'fail' | 'pass' | 'error'
  message: string
  output: string | null
  test_code: string
  task_id?: number
}

type ExerciseConfig = {
  custom?: {
    'version.tests.compatibility'?: 'jest-27' | 'jest-29'
    'flag.tests.task-per-describe': boolean
    'flag.tests.may-run-long': boolean
    'flag.tests.includes-optional': boolean
    'flag.tests.jest'?: boolean
    'flag.tests.tstyche'?: boolean
  }
}

// One message printed to the console, as buffered by node-test/console.cts
export interface ConsoleEntry {
  type: string
  message: string
  // The stack trace of the console call. The reporter uses it to work out
  // which test printed the message, as Jest did.
  origin: string
}

// One test's result, as reported by Node's test runner
export interface TestOutcome {
  name: string
  // What the test threw, if it failed
  error?: unknown
}

const OUTPUT_VERSION = 3

export class Output {
  private readonly results: Partial<OutputInterface> &
    Pick<OutputInterface, 'tests'>
  private readonly outputDir: string
  private readonly sources: Record<string, ParsedSource>
  private readonly tests: Record<string, ReturnType<typeof extractTests>>
  private readonly config: null | ExerciseConfig

  constructor(outputDir: string) {
    this.outputDir = outputDir
    this.results = { tests: [] }

    this.config = findConfig(outputDir)
    this.sources = {}
    this.tests = {}
  }

  public error(message: string): void {
    this.results.status = 'error'
    this.results.message = message
  }

  // Returns the contents of results.json
  public finish({
    topLevel,
    skipped,
  }: {
    topLevel: number
    skipped: number
  }): string {
    const outcomes = this.results.tests

    // If no test file ran, report that no tests ran. run.sh replaces this
    // with a pass if the type tests ran.
    if (!this.results.status && topLevel === 0) {
      return JSON.stringify(
        {
          version: 1,
          status: 'error',
          message:
            'The submitted code was not subjected to any type or execution ' +
            'tests. It did compile correctly, but something is wrong because ' +
            'at least one test was expected.',
        },
        undefined,
        2
      )
    }

    if (!this.results.status) {
      this.results.status =
        // Skipped tests are checked below. test.skip tests are fine if the
        // exercise reports that there are optional tests.
        //
        outcomes.every((test) => test.status === 'pass') ? 'pass' : 'fail'

      // Divert status if nothing ran
      if (this.results.status === 'pass' && outcomes.length === 0) {
        this.results.status = 'fail'
        this.error(
          'Expected to run at least one test, but none were found. This can ' +
            'happen if the test file(s) (.spec.js) are missing or empty. ' +
            'These files are normally not empty. Revert any changes or report ' +
            'an issue if the problem persists.'
        )
      }

      if (this.results.status === 'pass' && skipped !== 0) {
        if (
          !this.configFlag('flag.tests.includes-optional') &&
          this.config?.custom
        ) {
          this.results.status = 'fail'
          this.error(
            'Expected to see 0 skipped tests and 0 skipped test suites. ' +
              'None of the tests in this exercise are optional. The skipped ' +
              'tests will not show up, but were found during the last run.'
          )
        }
      }
    }

    const parsedSources: Record<
      string,
      {
        program: ParsedSource['program']
        source: ParsedSource['source']
        tests: Record<string, ExtractedTestCase>
      }
    > = {}

    // Every tested test file is indexed and parsed
    this.results.tests
      .map((test) => test.test_code)
      .filter((path, index, self) => self.indexOf(path) === index)
      .forEach((file) => {
        try {
          const [{ program, source }] = AstParser.ANALYZER.parseSync(
            fs.readFileSync(file).toString()
          )
          const tests = extractTests(program)

          parsedSources[file] = {
            program,
            source,
            tests: tests.reduce<Record<string, ExtractedTestCase>>(
              (results, item) => {
                results[item.name(' > ')] = item
                results[item.name(' ' as ' > ')] = item
                return results
              },
              {}
            ),
          }
        } catch (err: unknown) {
          console.error(
            `When trying to parse ${file}, the following error occurred`,
            err
          )
        }
      })

    // Extract the test code, if possible
    const tests = this.results.tests.map((test) => {
      const parsedSource = parsedSources[test.test_code]
      if (!parsedSource) {
        return { ...test, test_code: null }
      }

      const testCase = parsedSource.tests[test.name]
      if (!testCase) {
        return { ...test, test_code: null }
      }

      // Version 3 optionally can output the task ID
      if (this.configFlag('flag.tests.task-per-describe')) {
        return {
          ...test,
          task_id: testCase.topLevelIndex,
          test_code: testCase.testCode(parsedSource.source),
        }
      }

      return {
        ...test,
        test_code: testCase.testCode(parsedSource.source),
      }
    })

    // Re-order the output so that tests output shows below main output
    const { status, message } = this.results

    return JSON.stringify(
      { status, message, tests, version: OUTPUT_VERSION },
      undefined,
      2
    )
  }

  private configFlag(
    flag: keyof NonNullable<ExerciseConfig['custom']>
  ): boolean {
    if (!this.config?.custom) {
      return false
    }

    return this.config.custom[flag] as boolean
  }

  // The test file failed to load, for example because the solution threw
  // an error when it was imported. Jest called this "Test suite failed to
  // run".
  public suiteFailed(specFilePath: string, error: unknown): void {
    this.error(
      sanitizeErrorMessage(
        specFilePath,
        `  \u001b[1m● \u001b[22mTest suite failed to run\n\n${indent(
          errorHeader(error)
        )}\n`
      )
    )
  }

  public fileFinished(
    specFilePath: string,
    outcomes: TestOutcome[],
    consoleEntries: ConsoleEntry[]
  ): void {
    if (this.results.status === 'error') {
      return
    }

    const consoleOutputs: Record<string, string> = consoleEntries.length
      ? buildOutput(specFilePath, consoleEntries, this.getSource(specFilePath))
      : {}

    const outputs = outcomes.map(({ name, error }) => ({
      name,
      status: error === undefined ? ('pass' as const) : ('fail' as const),
      message:
        error === undefined
          ? ''
          : sanitizeErrorMessage(
              specFilePath,
              failureMessage(specFilePath, error)
            ),
    }))
    const firstFailureIndex = outputs.findIndex(
      (output) => output.status === 'fail'
    )

    this.results.tests.push(
      ...outputs.map((withoutOutput, i, self) => {
        const isFirstFailure =
          firstFailureIndex === i ||
          (firstFailureIndex === -1 && self.length === i + 1)

        const outputMessage = consoleOutputs[withoutOutput.name] || null

        return {
          ...withoutOutput,
          output: isFirstFailure
            ? [consoleOutputs[''], outputMessage].filter(Boolean).join('\n') ||
              null
            : outputMessage,
          test_code: specFilePath,
        }
      })
    )
  }

  // bin/run.sh sets COMPILED_DIR to the folder with the compiled files.
  // This turns a path in that folder into the path of its .ts file.
  public sourceOf(compiledPath: string): string {
    const compiledDir = process.env.COMPILED_DIR
    if (!compiledDir || !compiledPath.startsWith(path.join(compiledDir, '/'))) {
      return compiledPath
    }

    return path
      .join(this.outputDir, path.relative(compiledDir, compiledPath))
      .replace(/\.js$/, '.ts')
  }

  private getSource(specFilePath: string): {
    source: ParsedSource
    tests: ExtractedTestCase[]
  } {
    if (!this.sources[specFilePath]) {
      const [{ program, source }] = AstParser.ANALYZER.parseSync(
        fs.readFileSync(specFilePath).toString()
      )
      this.tests[specFilePath] = extractTests(program)
      this.sources[specFilePath] = { program, source }
    }

    return {
      source: this.sources[specFilePath],
      tests: this.tests[specFilePath],
    }
  }
}

function buildOutput(
  specFilePath: string,
  buffer: ConsoleEntry[],
  { tests }: { source: ParsedSource; tests: ExtractedTestCase[] }
): Record<string, string> {
  const outputs = buffer.reduce<Record<string, string[]>>((outputs, entry) => {
    // The origin stack trace will look something like this:
    //
    //   at twoFer (<specFile>:4:11)
    //   at Object.<anonymous> (<specFilePath>:5:12)
    //
    // We want to extract the :5:12) part, convert it to a proper line, column
    // and then look in the test file which test is "around" it. This only
    // works if the test file looks like this:
    //
    // test('my-test', () => {
    //   ...
    //   codeThatEventuallyResultsInLog();
    //   ...
    // })

    let foundTest: ExtractedTestCase | undefined
    // Using find because it will break when something is found!
    entry.origin.split('\n').find((originLine) => {
      if (!originLine.includes(specFilePath)) {
        return undefined
      }

      const [control, line, column] = originLine
        .slice(originLine.indexOf(specFilePath) + specFilePath.length)
        .split(':')

      // Stacktrace didn't look like what we expected
      if (control !== '') {
        return undefined
      }

      const messageLoc = {
        line: Number(line),
        column: Number(column.slice(0, column.length - 1)),
      }
      return (foundTest = tests.find(({ testNode }) => {
        if (messageLoc.line < testNode.loc.start.line) {
          return false
        }
        if (messageLoc.line > testNode.loc.end.line) {
          return false
        }
        if (
          messageLoc.line === testNode.loc.start.line &&
          messageLoc.column < testNode.loc.start.column
        ) {
          return false
        }
        if (
          messageLoc.line === testNode.loc.end.line &&
          messageLoc.column > testNode.loc.end.column
        ) {
          return false
        }

        return true
      }))
    })

    const testName = foundTest?.name(' > ') ?? ''
    const sanitized = `[${entry.type}] ${sanitizeErrorMessage(
      specFilePath,
      entry.message
    )}`

    outputs[testName] = outputs[testName] || []
    outputs[testName].push(sanitized)

    return outputs
  }, {})

  return Object.keys(outputs).reduce<Record<string, string>>((results, key) => {
    const message = (outputs[key] || []).join('\n') || ''
    if (message.length <= 500) {
      results[key] = message
    } else {
      results[key] = message
        .slice(0, 500 - '... (500 chars max)'.length)
        .concat('... (500 chars max)')
    }

    return results
  }, {})
}

// Jest showed the error with the stack frames inside the solution, and cut
// the stack at the test itself. Node's stack also goes on into the test
// runner, so cut it at the first frame in the test file, and leave out the
// frames inside Node.
function failureMessage(specFilePath: string, error: unknown): string {
  const stack =
    error instanceof Error && typeof error.stack === 'string'
      ? error.stack
      : String(error)

  const lines = stack.split('\n')
  const firstFrame = lines.findIndex((line) => FRAME.test(line))
  if (firstFrame === -1) {
    return stack
  }

  const frames = lines.slice(firstFrame)
  const testFrame = frames.findIndex((line) => line.includes(specFilePath))

  return lines
    .slice(0, firstFrame)
    .concat(
      frames
        .slice(0, testFrame === -1 ? undefined : testFrame)
        .filter((line) => !line.includes('(node:') && !line.includes(' node:'))
    )
    .join('\n')
    .trimEnd()
}

const FRAME = /^\s+at /

function errorHeader(error: unknown): string {
  return error instanceof Error
    ? `${error.name}: ${error.message}`
    : String(error)
}

function indent(text: string): string {
  return text
    .split('\n')
    .map((line) => `    ${line}`)
    .join('\n')
}

function sanitizeErrorMessage(specFilePath: string, message: string): string {
  const dirs = [
    ...(process.env.COMPILED_DIR ? [process.env.COMPILED_DIR] : []),
    path.dirname(specFilePath),
    path.dirname(path.dirname(specFilePath)),
    process.cwd(),
    path.dirname(process.cwd()),
  ]

  dirs.forEach((sensitivePath) => {
    while (message.includes(sensitivePath)) {
      message = message.replace(sensitivePath, '<solution>')
    }
  })

  if (message.includes('SyntaxError: <solution>')) {
    return message.slice(message.indexOf('SyntaxError: <solution>'))
  }

  return removeImportNames(message)
}

// tsc compiles `import { twoFer } from './two-fer'` to `two_fer_1.twoFer`,
// and calls it as `(0 , two_fer_1.twoFer)()`. Node names those in its
// errors, so this removes the parts tsc added and leaves the names the
// student wrote.
function removeImportNames(message: string): string {
  return message
    .replace(
      /\(0 , [A-Za-z_$][\w$]*_\d+\.default\) is not a function/g,
      'the default export is not a function'
    )
    .replace(
      /\(0 , [A-Za-z_$][\w$]*_\d+\.([\w$]+)\) is not a function/g,
      '$1 is not a function'
    )
    .replace(
      /\b[A-Za-z_$][\w$]*_\d+\.([\w$.]+) is not a function/g,
      '$1 is not a function'
    )
}

function findConfig(rootDir: string): null | ExerciseConfig {
  const configPaths = [
    path.join(rootDir, '.meta', 'config.json'),
    path.join(rootDir, '.exercism', 'config.json'),
  ]

  const actualConfigPath = configPaths.find((potentialPath) =>
    fs.existsSync(potentialPath)
  )

  if (!actualConfigPath) {
    return null
  }

  return JSON.parse(
    fs.readFileSync(actualConfigPath).toString()
  ) as ExerciseConfig
}
