import { run, SqValueTag } from "../../src/js";
export { SqValueTag };

expect.extend({
  toEqualSqValue(x, y) {
    // hack via https://github.com/facebook/jest/issues/10329#issuecomment-820656061
    const { getMatchers } = require("expect/build/jestMatchersObject");
    return getMatchers().toEqual.call(this, x.toString(), y.toString());
  },
});

export function testRun(x: string) {
  const { result, bindings } = run(x, {
    environment: {
      sampleCount: 1000,
      xyPointLength: 100,
    },
  });

  if (result.tag === "Ok") {
    return result.value;
  } else {
    throw new Error(
      `Expected squiggle expression to evaluate but got error: ${result.value}`
    );
  }
}

/**
 * This appears also in `TestHelpers.res`. According to https://www.math.net/percent-error, it computes
 * absolute error when numerical stability concerns make me not want to compute relative error.
 * */
export function expectErrorToBeBounded(
  received: number,
  expected: number,
  epsilon: number,
  digits: number
) {
  let distance = Math.abs(received - expected);
  let expectedAbs = Math.abs(expected);
  let normalizingDenom = Math.max(expectedAbs, 1);
  let error = distance / normalizingDenom;
  expect(Math.round(10 ** digits * error) / 10 ** digits).toBeLessThanOrEqual(
    epsilon
  );
}
