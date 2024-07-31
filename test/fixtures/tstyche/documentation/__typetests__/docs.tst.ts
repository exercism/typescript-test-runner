import { expect, test } from "tstyche";

function firstItem<T>(target: Array<T>): T | undefined {
  return target[0];
}

test("first item requires a parameter", () => {
  expect(firstItem(["a", "b", "c"])).type.toBe<string | undefined>();

  expect(firstItem()).type.toRaiseError("Expected 1 argument");
});

function secondItem<T>(target: Array<T>): T | undefined {
  return target[1];
}

test("handles numbers", () => {
  expect(secondItem([1, 2, 3])).type.toBe<number | undefined>();
});