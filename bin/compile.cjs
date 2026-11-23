#!/usr/bin/env node

// Synopsis:
// Type-check the solution exactly as `tsc --noEmit` does, then write the
// JavaScript into an output folder, so Node can run the tests without a
// transformer.

// Arguments:
// $1: folder to write the JavaScript and source maps to

// Output:
// The same output and exit code as `tsc --noEmit`, run in the current folder.

const fs = require('node:fs')
const path = require('node:path')
const { stripVTControlCharacters } = require('node:util')
const ts = require('typescript')

const outDir = path.resolve(process.argv[2])
const rootDir = process.cwd()
const setupModule = path.resolve(__dirname, '../dist/node-test/setup.cjs')

// Change the imports while writing the JavaScript, so Node can load the
// compiled files without a resolve hook:
// - './two-fer.ts' becomes './two-fer.js', the name of the compiled file.
// - '@jest/globals' becomes the runner's setup module, which gives the
//   tests describe, it and Jest's expect on Node's test runner.
function rewriteSpecifier(specifier) {
  if (specifier === '@jest/globals') {
    return setupModule
  }
  if (specifier.startsWith('.') && specifier.endsWith('.ts')) {
    return specifier.replace(/\.ts$/, '.js')
  }
  return specifier
}

function rewriteImports(context) {
  const { factory } = context
  const visit = (node) => {
    if (
      (ts.isImportDeclaration(node) || ts.isExportDeclaration(node)) &&
      node.moduleSpecifier &&
      ts.isStringLiteral(node.moduleSpecifier)
    ) {
      const specifier = rewriteSpecifier(node.moduleSpecifier.text)
      if (specifier !== node.moduleSpecifier.text) {
        const literal = factory.createStringLiteral(specifier)
        return ts.isImportDeclaration(node)
          ? factory.updateImportDeclaration(
              node,
              node.modifiers,
              node.importClause,
              literal,
              node.attributes
            )
          : factory.updateExportDeclaration(
              node,
              node.modifiers,
              node.isTypeOnly,
              node.exportClause,
              literal,
              node.attributes
            )
      }
    }
    return node
  }
  return (sourceFile) => ts.visitEachChild(sourceFile, visit, context)
}

const transformers = { before: [rewriteImports] }

// Write source maps that point back at the original .ts files. Node reads
// them (--enable-source-maps) for stack traces and for the origin of console
// output, so both name the .ts lines the student wrote.
function writeWithSourceMap(jsFile, code, map, sourceFile) {
  const parsed = JSON.parse(map)
  parsed.sources = sourceFile
    ? [sourceFile]
    : parsed.sources.map((source) =>
        path.resolve(path.dirname(jsFile), parsed.sourceRoot || '', source)
      )
  delete parsed.sourceRoot
  fs.mkdirSync(path.dirname(jsFile), { recursive: true })
  fs.writeFileSync(`${jsFile}.map`, JSON.stringify(parsed))
  fs.writeFileSync(jsFile, code)
}

function outputPathOf(file) {
  return path.join(outDir, path.relative(rootDir, file).replace(/\.ts$/, '.js'))
}

// The test files are not part of the type check (tsconfig.json excludes
// them), so only their types are removed. This takes a few milliseconds
// per file and does not type-check them, which matches what Babel did.
function transpileTestFiles(program, options) {
  const inProgram = new Set(
    program.getSourceFiles().map((file) => path.resolve(file.fileName))
  )

  const walk = (dir) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name)
      if (entry.isDirectory()) {
        if (!['node_modules', '.meta', '__typetests__'].includes(entry.name)) {
          walk(full)
        }
      } else if (
        entry.name.endsWith('.ts') &&
        !entry.name.endsWith('.d.ts') &&
        !inProgram.has(full)
      ) {
        const { outputText, sourceMapText, diagnostics } = ts.transpileModule(
          fs.readFileSync(full, 'utf8'),
          {
            fileName: full,
            reportDiagnostics: true,
            transformers,
            compilerOptions: {
              ...options,
              module: ts.ModuleKind.CommonJS,
              sourceMap: true,
              inlineSourceMap: false,
              outDir: undefined,
              rootDir: undefined,
            },
          }
        )
        // TypeScript still writes JavaScript for a test file with a syntax
        // error. Babel stopped with a SyntaxError instead, so the compiled
        // file throws one, which the reporter shows as the suite failing to
        // run.
        const syntaxError = diagnostics.find(
          (diagnostic) =>
            diagnostic.file &&
            diagnostic.category === ts.DiagnosticCategory.Error
        )
        if (syntaxError) {
          const { line, character } = ts.getLineAndCharacterOfPosition(
            syntaxError.file,
            syntaxError.start
          )
          const message = ts.flattenDiagnosticMessageText(
            syntaxError.messageText,
            ' '
          )
          // Show the student the lines around the error, as Babel's code
          // frame did. TypeScript's own format starts with a line that
          // repeats the message, so that line is dropped.
          const context = stripVTControlCharacters(
            ts.formatDiagnosticsWithColorAndContext([syntaxError], {
              getCurrentDirectory: () => rootDir,
              getCanonicalFileName: (fileName) => fileName,
              getNewLine: () => '\n',
            })
          )
            .split('\n')
            .slice(1)
            .join('\n')
            .trimEnd()
          const error = `${full}: ${message} (${line + 1}:${character})\n${context}\n`
          fs.mkdirSync(path.dirname(outputPathOf(full)), { recursive: true })
          fs.writeFileSync(
            outputPathOf(full),
            `throw new SyntaxError(${JSON.stringify(error)})\n`
          )
          continue
        }

        writeWithSourceMap(outputPathOf(full), outputText, sourceMapText, full)
      }
    }
  }

  walk(rootDir)
}

function emit(program) {
  const options = program.getCompilerOptions()

  // The type check above ran with tsconfig.json's options (noEmit). Turn
  // on emitting only now, so the output and exit code stay those of
  // `tsc --noEmit`. Emitting reuses the program tsc already parsed and
  // checked.
  options.noEmit = false
  options.outDir = outDir
  options.rootDir = rootDir
  options.sourceMap = true
  options.declaration = false
  options.noEmitOnError = false

  const outputs = new Map()
  program.emit(
    undefined,
    (fileName, text) => outputs.set(fileName, text),
    undefined,
    false,
    transformers
  )
  for (const [fileName, text] of outputs) {
    if (fileName.endsWith('.js')) {
      writeWithSourceMap(fileName, text, outputs.get(`${fileName}.map`))
    }
  }

  transpileTestFiles(program, options)
}

ts.executeCommandLine(
  ts.sys,
  (program) => {
    if (typeof program.getCompilerOptions !== 'function') {
      return
    }
    if (typeof program.getProgram === 'function') {
      program = program.getProgram()
    }
    emit(program)
  },
  process.argv.slice(3)
)
