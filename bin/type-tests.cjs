// Synopsis:
// Run the type tests (*.tst.ts) with tstyche, in the process of
// bin/compile.cjs, on the files already parsed by its type check.
//
// Running the tstyche command took about 3 seconds for one small test file.
// It loaded its own copy of TypeScript and parsed and bound the standard
// library and the Node types again, twice: once for tsconfig.json, which
// excludes the type tests, and once more for a default project for the test
// file. Parsing and binding these files is almost all of the type check's
// time, while checking the solution takes about 10 ms. Here tstyche checks
// the test files in a program that reuses the parsed files of the type
// check, so only the test files are parsed again.
//
// The type tests use the compiler options of the type check. Exercises list
// the type tests in their own tsconfig.json, so students' type tests run
// with these options too.

const fs = require('node:fs')

let tstyche

// tstyche loads TypeScript itself, and changes it so the type checker gives
// access to the type relations used by the matchers. The type check uses
// this copy, so both use the same parsed files.
async function loadTypeScript() {
  tstyche = await import('tstyche/tstyche')
  return new tstyche.StoreService().load('current')
}

// Return a program for the test files that reuses the files parsed by the
// type check. The options match, so the files parse the same.
function createTypeTestProgram(ts, checkedProgram, testFiles) {
  const options = { ...checkedProgram.getCompilerOptions() }
  const host = ts.createCompilerHost(options)
  const getSourceFile = host.getSourceFile
  host.getSourceFile = (fileName, ...rest) =>
    checkedProgram.getSourceFile(fileName) ?? getSourceFile(fileName, ...rest)

  return ts.createProgram({
    rootNames: [...checkedProgram.getRootFileNames(), ...testFiles],
    options,
    host,
  })
}

// tstyche gets a language service for each test file from TypeScript's
// project service. This one answers from the program above. tstyche only
// calls the methods below.
function createCompiler(ts, checkedProgram, getProgram) {
  const configFileName = checkedProgram.getCompilerOptions().configFilePath

  const languageService = {
    getProgram,
    getSyntacticDiagnostics: (fileName) =>
      getProgram().getSyntacticDiagnostics(
        getProgram().getSourceFile(fileName)
      ),
    // The same as the language service: the semantic diagnostics, and the
    // declaration diagnostics if the options ask for declarations.
    getSemanticDiagnostics: (fileName) => {
      const program = getProgram()
      const sourceFile = program.getSourceFile(fileName)
      const diagnostics = program.getSemanticDiagnostics(sourceFile)
      if (!ts.getEmitDeclarations(program.getCompilerOptions())) {
        return diagnostics.slice()
      }
      return [...diagnostics, ...program.getDeclarationDiagnostics(sourceFile)]
    },
  }

  class ProjectService {
    setCompilerOptionsForInferredProjects() {}
    openClientFile() {
      return { configFileName }
    }
    closeClientFile() {}
    getDefaultProjectForFile() {
      return { getLanguageService: () => languageService }
    }
  }

  return Object.create(ts, {
    server: {
      value: Object.create(ts.server, {
        ProjectService: { value: ProjectService },
      }),
    },
  })
}

function fileWriter(fileName) {
  const fd = fs.openSync(fileName, 'w')
  return { write: (text) => fs.writeSync(fd, text) }
}

// Run tstyche as `tstyche --failFast` does, in the current folder.
async function run(ts, checkedProgram) {
  let typeTestProgram
  const compiler = createCompiler(ts, checkedProgram, () => typeTestProgram)

  class StoreService extends tstyche.StoreService {
    async load() {
      return compiler
    }
  }
  const storeService = new StoreService()

  const outputService = new tstyche.OutputService({
    stdout: fileWriter('tstyche.stdout.txt'),
    stderr: fileWriter('tstyche.stderr.txt'),
  })

  // Report errors in tstyche's configuration and in finding the test files,
  // and stop on them, as the tstyche command does.
  const eventEmitter = new tstyche.EventEmitter()
  const cancellationToken = new tstyche.CancellationToken()
  eventEmitter.addHandler(new tstyche.SetupReporter(outputService))
  eventEmitter.addHandler(
    new tstyche.CancellationHandler(cancellationToken, 'configError')
  )

  const configService = new tstyche.ConfigService(compiler, storeService)
  await configService.parseCommandLine(['--failFast'])
  if (cancellationToken.isCancellationRequested) {
    return
  }
  await configService.readConfigFile()
  const resolvedConfig = configService.resolveConfig()
  if (cancellationToken.isCancellationRequested) {
    return
  }

  const selectService = new tstyche.SelectService(resolvedConfig)
  const testFiles = await selectService.selectFiles()
  eventEmitter.removeHandlers()
  if (testFiles.length === 0) {
    return
  }

  typeTestProgram = createTypeTestProgram(ts, checkedProgram, testFiles)

  const runner = new tstyche.TSTyche(
    resolvedConfig,
    outputService,
    selectService,
    storeService
  )
  await runner.run(testFiles, cancellationToken)
  runner.close()
}

module.exports = { loadTypeScript, run }
