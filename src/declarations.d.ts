// Required for jest-util to not break during compilation. Normally this is not
// necessary when using jest, but jest-util is imported in the test runner code
// which makes it a requirement.
declare type Window = unknown

// Extensions for jest, as declared in the jest setup (after env) file.
declare namespace jest {
  interface It {
    task: (taskId: number, ...args: Parameters<jest.It>) => ReturnType<jest.It>
  }
}
