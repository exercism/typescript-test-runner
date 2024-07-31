import { describe, test, expect } from "tstyche";
import type { MethodLikeKeys } from "../fire.js";

interface Sample {
  description: string;
  getLength: () => number;
  getWidth?: () => number;
}

describe('fire', () => {
  test('all method keys are found', () => {
    expect<MethodLikeKeys<Sample>>().type.toBe<"getLength" | "getWidth">();
  })
})
