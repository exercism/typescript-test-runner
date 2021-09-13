type Options = {
    minFactor?: number;
    maxFactor?: number;
    sum: number;
  };
  class Triplet {
    static isTriplet(a: number, b: number, c: number): boolean {
      return a ** 2 + b ** 2 === c ** 2;
    }
    static isMaxOk(a: number, b: number, c: number): boolean {
      return a ** 2 + b ** 2 <= c ** 2;
    }
    constructor(private a: number, private b: number, private c: number) {}
    toArray(): [number, number, number] {
      return [this.a, this.b, this.c];
    }
  }
  export const tripletsFor = ({
    minFactor = 1,
    maxFactor: maxy,
    sum,
  }: Options): Triplet | undefined => {
    let maxFactor = Math.min(maxy || sum, sum - minFactor - minFactor - 1);
    let mid = sum - maxFactor - minFactor;
    while (
      maxFactor > mid &&
      mid > minFactor &&
      Triplet.isMaxOk(minFactor, mid, maxFactor)
    ) {
      if (Triplet.isTriplet(minFactor, mid, maxFactor)) {
        return new Triplet(minFactor, mid, maxFactor);
      }
      maxFactor -= 1;
      mid += 1;
    }
    return undefined;
  };
  export const triplets = ({
    minFactor = 1,
    maxFactor: maxy,
    sum,
  }: Options): Triplet[] => {
    let results: Triplet[] = [];
    for (let i = minFactor; i < Math.floor(sum / 3); i++) {
      const nextStep = tripletsFor({
        sum,
        minFactor: i,
        maxFactor: maxy,
      });
      if (nextStep !== undefined) {
        results.push(nextStep);
      }
    }
    return results;
  };
  