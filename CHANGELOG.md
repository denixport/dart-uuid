
## 2.0.0
Stable null safety release

### Changed
- `bytes` getter replaced with `toBytes()` method
- Generators renamed
- `NameUuidGenerator` now has separate `generateFromString()` and `generateFromBytes()` methods

### Added
- `NameUuidGenerator` now has separate `generateFromString()` and `generateFromBytes()` methods

### Removed
- `Uuid()` constructor with string param
- `generate()` method from `NameUuidGenerator`

## 1.1.1
Small refactoring of time-based generator

## 1.1.0

### Added
Utility class for convenient UUID string generation and comparison

## 1.0.2
Release

## 1.0.0-beta
More tests and documentation

## 0.9.0-beta

### Added
- Abstract `Uuid` class now has `compareTo` method implemented

### Changed
- Time-based generator is refactored to use `Stopwatch` instead of `DateTime` calls.
  Parameter `clockSequence` is now deprecated in `TimeBasedUuidGenerator` constructor
- Comparison is refactored to treat v1 UUIDs differently

## 0.8.0-beta

### Added
- Added comparison operators `>` `>=` `<` `<=`

### Changed
- Refactored string parsing

## 0.7.0-dev
- Dart 2.0 is a minimum required version

## 0.6.0-dev
- `toBytes()` method was renamed to `bytes` getter

## 0.5.2-dev
- Initial package documentation

## 0.5.1-dev
- Initial release, and tests