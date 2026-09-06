# Changelog

## Unreleased

### Changed

- Made conversational sentences the default output of `explain_in_english`, with no style option.
- Added contextual wording for familiar booleans, names, ages, dates, ordering and pagination.
- Preserved logical grouping, missing-value distinctions, table ownership and join multiplicity in explanations.
- Added association-aware wording for simple joins and clearer aggregate, alias and distinct-result descriptions.
- Labelled raw SQL explicitly and delegated bind quoting to Active Record.
- Updated examples and regression specs for the new returned strings and punctuation.

### Fixed

- Excluded built `.gem` archives from the package file list so Bundler can load the gemspec.

## 0.1.0 - 2026-04-25

### Added

- Added `explain_in_english` to `ActiveRecord::Relation`.
- Added plain-English descriptions for common Arel relation shapes, including filters, ordering, limits, offsets, selected columns, distinct queries, joins, grouping, having clauses, raw SQL fragments, aliases, aggregate functions, and named functions.
- Added RSpec coverage for simple relations and multi-model complex queries.
