// The runner keeps @types/node at the version used to type-check solutions
// (see tsconfig.solutions.json). That version is older than these two
// functions of node:module, so this file describes them.
declare module 'node:module' {
  interface ResolveContext {
    conditions: string[]
    importAttributes: Record<string, string>
    parentURL?: string
  }

  interface ResolveResult {
    url: string
    format?: string | null
    shortCircuit?: boolean
  }

  function registerHooks(hooks: {
    resolve?: (
      specifier: string,
      context: ResolveContext,
      nextResolve: (
        specifier: string,
        context?: ResolveContext
      ) => ResolveResult
    ) => ResolveResult
  }): void

  function stripTypeScriptTypes(code: string): string
}
