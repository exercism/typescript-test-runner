import crypto from 'node:crypto';

declare const abilitiesRollBrand: unique symbol;

type AbilitiesRoll = number & {
  [abilitiesRollBrand]: true;
};

const SCORE_COUNT = 6;
const SCORE_MAX_INDEX = SCORE_COUNT - 1;

const SCORE_BITS = 4;
const SCORE_MASK = ((): number => {
  let mask = 1;
  for (let i = 1; i < SCORE_BITS; i += 1, mask = (mask << 1) | 1);
  return mask;
})();

const SCORE_MIN = 3;
const SCORE_MAX = toScore(SCORE_MASK);

function errorScoreIndex(index: number): Error {
  return new Error(`'${index}' is not a valid score index`);
}

function toScore(value: number): number {
  return (SCORE_MASK & value) + SCORE_MIN;
}

function getScore(rollValues: AbilitiesRoll, index: number): number {
  if (index < 0 || SCORE_MAX_INDEX < index) throw errorScoreIndex(index);

  return toScore(rollValues >>> (index * SCORE_BITS));
}

function rollToScores(rollValues: AbilitiesRoll): number[] {
  const scores: number[] = [];
  for (
    let i = 0, values = rollValues as number;
    i < SCORE_COUNT;
    i += 1, values >>>= SCORE_BITS
  )
    scores[i] = toScore(values);

  return scores;
}

const targetBuffer = new Uint32Array(1);

function roll(): AbilitiesRoll {
  crypto.randomFillSync(targetBuffer);
  return targetBuffer[0] as AbilitiesRoll;
}

function toModifier(value: number): number {
  return (value - 10) >> 1;
}

export {
  roll,
  rollToScores,
  SCORE_MIN,
  SCORE_MAX,
  toModifier,
  getScore,
  SCORE_MAX_INDEX,
};
