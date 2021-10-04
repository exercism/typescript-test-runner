declare namespace jest {
  interface It {
    task: (taskId: number, ...args: Parameters<jest.It>) => ReturnType<jest.It>
  }
}
