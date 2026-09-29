# Changelog

## 0.1.0 (unreleased)

- Tapioca DSL compiler for `Sequel::Model`: typed column readers and writers,
  finders, a typed `PrivateDataset` for query chains, and the `Elem` type
  template `Sequel::Model`'s `extend Enumerable` requires.
- Association methods: readers, `_dataset` methods, singular writers, and
  `add_`/`remove_`/`remove_all_` for plural associations, generated only when
  the model defines them.
