import { format } from 'node:util'
import type { ConsoleEntry } from '../output.js'

export const consoleEntries: ConsoleEntry[] = []

const TYPES = ['log', 'info', 'warn', 'error', 'debug'] as const

// Buffer everything the tests and the solution print, instead of writing it
// out. The reporter puts each message on the test that printed it.
export function captureConsole(): void {
  for (const type of TYPES) {
    console[type] = (...args: unknown[]): void => {
      const origin = { stack: '' }
      Error.captureStackTrace(origin, console[type])
      consoleEntries.push({
        type,
        message: format(...args),
        origin: origin.stack,
      })
    }
  }
}
