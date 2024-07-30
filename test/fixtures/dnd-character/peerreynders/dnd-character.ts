import * as AbilityScores from './dnd-ability-scores.ts';
const { roll, rollToScores, toModifier } = AbilityScores;

const HITPOINTS_INITIAL = 10;

const ABILITIES_ORDERED = [
  'strength',
  'dexterity',
  'constitution',
  'intelligence',
  'wisdom',
  'charisma',
] as const;

type AbilityKey = typeof ABILITIES_ORDERED[number];
type Abilities = Record<AbilityKey, number>;
type AbilityTarget = Partial<Abilities>;

function rollAbilities(): Abilities {
  const scores = rollToScores(roll());
  return ABILITIES_ORDERED.reduce<AbilityTarget>((target, key, i) => {
    target[key] = scores[i];
    return target;
  }, {}) as Abilities;
}

class DnDCharacter {
  #abilities: Abilities;
  #hitpoints: number;

  constructor() {
    const abilities = rollAbilities();
    this.#hitpoints = HITPOINTS_INITIAL + toModifier(abilities.constitution);
    this.#abilities = abilities;
  }

  get strength(): number {
    return this.#abilities.strength;
  }

  get dexterity(): number {
    return this.#abilities.dexterity;
  }

  get constitution(): number {
    return this.#abilities.constitution;
  }

  get intelligence(): number {
    return this.#abilities.intelligence;
  }

  get wisdom(): number {
    return this.#abilities.wisdom;
  }

  get charisma(): number {
    return this.#abilities.charisma;
  }

  get hitpoints(): number {
    return this.#hitpoints;
  }

  static generateAbilityScore(): number {
    return AbilityScores.getScore(roll(), AbilityScores.SCORE_MAX_INDEX);
  }

  static getModifierFor(abilityValue: number): number {
    return toModifier(abilityValue);
  }
}

export { DnDCharacter };
