type MethodLike = (...args: any) => any;

export type MethodLikeKeys<T> = keyof {
  [K in keyof T as T[K] extends MethodLike ? K : never]: T[K];
};