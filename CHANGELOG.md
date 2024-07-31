# Changelog

## 5.1.0

- Add support for type-tests
- Rework `run.sh` for console friendly output

## 5.0.0

- Use Yarn 4
- Use ESLint 9 (Flat Config)
- Enable PnP for both this workspace as well as the runner
- Update chalk to higher version (ESM only)

## 4.0.0

- Add missing features from javascript-test-runner
- Add proper corejs (and babel) support for mismatching solutions
- Change implementation to support jest 29
- Change package of `chalk` to lower major
- Use Yarn 3

## 3.0.0

- Rewritten for jest 17

## 2.3.0

- Update dependencies
- Use Node 16.x as LTS

## 2.2.0

- Update dependencies
- Only test against LTS and current (nodejs)

## 2.1.0

- Allow skipping/pending tests (`test.skip`)

## 2.0.3

- Disable compilation of `.test.ts` files when running in test-runner

## 2.0.2

- Copy development packages to input directory

## 2.0.1

- Add development packages (types) so it can compile the tests

## 2.0.0

- Implement `tsc` compilation

## 1.0.2

- Fix output's conditional assignment

## 1.0.1

- Update dependencies

## 1.0.0

Initial release
