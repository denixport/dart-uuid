## 1.1.0
- Utility class for convinient UUID string generation and comparison

## 1.0.2
  Release 

## 1.0.0-beta
- More tests and documentation

## 0.9.0-beta
- Time-based generator is refactored to use `Stopwatch` instead of `DateTime` calls.
  Parameter `clockSequence` is now deprecated in `TimeBasedUuidGenerator` constructor
- Comparison is refactored to treat v1 UUIDs differently
- Abstract `Uuid` class now has `compareTo` method implemented  

## 0.8.0-beta
- Refactored string parsing (does not affect API)
- Added comparison operators `>` `>=` `<` `<=` 

## 0.7.0-dev
- Dart 2.0 is a minimum required version 

## 0.6.0-dev
- `toBytes()` method was renamed to `bytes` getter 

## 0.5.2-dev
- Initial package documentation

## 0.5.1-dev
- Initial relase, and tests
