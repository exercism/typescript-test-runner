declare type Window = unknown

declare namespace jest {
  interface It {
    task: (
      taskId: number,
      name: string,
      fn?: ProvidesCallback,
      timeout?: number
    ) => void
  }
}
