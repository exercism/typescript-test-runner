// Finds the tests in a test file, so the reporter can show each test's code
// and work out which test printed each console message.
//
// This used to be done by @exercism/static-analysis, which parses with
// @typescript-eslint/typescript-estree. That package converts TypeScript's
// syntax tree into another format, and took about 0.4s of each run. This file
// walks TypeScript's own syntax tree instead. Node loads TypeScript from the
// image's compile cache, so parsing the test file takes a few tens of
// milliseconds.
//
// The JavaScript runner's tests.ts does the same with acorn, on the same
// rules, because its test files are plain JavaScript.
import ts from 'typescript'

interface Position {
  /** The line, counted from 1 */
  line: number
  /** The column, counted from 0 */
  column: number
}

interface TestFunction {
  loc: { start: Position; end: Position }
}

type Range = readonly [start: number, end: number]

export interface TestCase {
  /** Where the function passed to test(...) starts and ends */
  testNode: TestFunction
  description: string[]
  test: string
  /** The number of top-level describe blocks up to and including this test */
  topLevelIndex: number
  name: (glue?: string) => string
  testCode: (source: string) => string
}

export interface ParsedTests {
  source: string
  tests: TestCase[]
}

const DESCRIBES = ['describe', 'xdescribe']
const TESTS = ['test', 'xtest', 'it', 'xit']
const MODIFIERS = ['skip', 'only']

function isIdentifier(node: ts.Node, names: string[]): boolean {
  return ts.isIdentifier(node) && names.includes(node.text)
}

// describe('...'), describe.skip('...'), xdescribe.only('...') and so on
function isDescribe(node: ts.Expression): node is ts.CallExpression {
  if (!ts.isCallExpression(node)) return false
  const callee = node.expression
  if (ts.isIdentifier(callee)) return DESCRIBES.includes(callee.text)
  if (ts.isPropertyAccessExpression(callee)) {
    return (
      isIdentifier(callee.expression, DESCRIBES) &&
      isIdentifier(callee.name, MODIFIERS)
    )
  }
  return (
    ts.isElementAccessExpression(callee) &&
    isIdentifier(callee.expression, DESCRIBES) &&
    ts.isStringLiteral(callee.argumentExpression) &&
    MODIFIERS.includes(callee.argumentExpression.text)
  )
}

// test('...'), it.skip('...'), xtest.only('...') and so on
function isTest(node: ts.Expression): node is ts.CallExpression {
  if (!ts.isCallExpression(node)) return false
  const callee = node.expression
  if (ts.isIdentifier(callee)) return TESTS.includes(callee.text)
  return (
    ts.isPropertyAccessExpression(callee) &&
    isIdentifier(callee.expression, TESTS) &&
    isIdentifier(callee.name, MODIFIERS)
  )
}

function isTestFunction(
  node: ts.Node | undefined
): node is ts.FunctionExpression | ts.ArrowFunction {
  return (
    node !== undefined &&
    (ts.isFunctionExpression(node) || ts.isArrowFunction(node))
  )
}

/**
 * Finds the tests in the same way as @exercism/static-analysis did. Tests
 * and describe blocks named with anything other than a string literal (such
 * as a template literal) are left out.
 */
export function parseTests(source: string): ParsedTests {
  const file = ts.createSourceFile(
    'test.ts',
    source,
    ts.ScriptTarget.Latest,
    true,
    ts.ScriptKind.TS
  )

  const positionOf = (offset: number): Position => {
    const { line, character } = file.getLineAndCharacterOfPosition(offset)
    return { line: line + 1, column: character }
  }
  const rangeOf = (node: ts.Node): Range => [node.getStart(file), node.end]

  const tests: TestCase[] = []
  const description: string[] = []
  let topLevelDescribes = 0

  function visit(node: ts.Node): void {
    if (ts.isExpressionStatement(node)) {
      const { expression } = node

      if (isDescribe(expression)) {
        const [nameArgument] = expression.arguments
        if (!nameArgument || !ts.isStringLiteral(nameArgument)) return

        if (description.length === 0) topLevelDescribes += 1
        description.push(nameArgument.text)
        ts.forEachChild(node, visit)
        description.pop()
        return
      }

      if (isTest(expression)) {
        const [nameArgument, testArgument] = expression.arguments
        if (
          nameArgument &&
          ts.isStringLiteral(nameArgument) &&
          isTestFunction(testArgument)
        ) {
          const { body } = testArgument
          const [start, end] = rangeOf(testArgument)
          tests.push(
            createTestCase(
              { loc: { start: positionOf(start), end: positionOf(end) } },
              ts.isBlock(body) ? body.statements.map(rangeOf) : [rangeOf(body)],
              [...description],
              nameArgument.text,
              topLevelDescribes
            )
          )
        }
        return
      }
    }

    ts.forEachChild(node, visit)
  }

  visit(file)
  return { source, tests }
}

function createTestCase(
  testNode: TestFunction,
  codeRanges: Range[],
  description: string[],
  test: string,
  topLevelIndex: number
): TestCase {
  return {
    testNode,
    description,
    test,
    topLevelIndex,
    name(glue = ' > '): string {
      return [...description, test].join(glue)
    },
    testCode(source: string): string {
      return codeRanges
        .map(([start, end]) => source.substring(start, end))
        .join('\n')
    },
  }
}
