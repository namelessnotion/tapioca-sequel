# tapioca-sequel

A [Tapioca](https://github.com/Shopify/tapioca) DSL compiler for
[Sequel](https://sequel.jeremyevans.net/) models. `bin/tapioca dsl` reads each
`Sequel::Model`'s database schema and association reflections and writes a
Sorbet RBI for it, so this type-checks at `typed: strict`:

```ruby
entity = Models::Entity.where(role: 'investor').order(:name).first!  # Models::Entity
entity.name                                                           # String
entity.accounts                                                       # T::Array[Models::Account]
entity.accounts_dataset.where(currency: 'USD').all                    # T::Array[Models::Account]
```

## What it generates

For every named model that has a dataset:

| Module | Contents |
| --- | --- |
| `GeneratedAttributeMethods` | A reader and writer per column, typed from `db_schema`. Readers are nilable when the column allows null; writers always accept nil. |
| `GeneratedAssociationMethods` | For each association the model really defines: the reader, the `_dataset` method, the writer for a singular association, and `add_`/`remove_`/`remove_all_` for a plural one. `read_only: true` and similar options are honoured, because only methods the model defines are generated. |
| `GeneratedClassMethods` | `[]`, `with_pk`, `with_pk!`, `create`, `first`, `first!`, `last`, `all`, `count`, `empty?`, `dataset`, and the chainable query methods (`where`, `order`, `eager`, `for_update`, …) returning the model's `PrivateDataset`. |
| `PrivateDataset` | A `Sequel::Dataset` subclass whose finders return the model and whose query methods return itself, so a chain stays typed until it is read. |

It also declares the `Elem` type template that `Sequel::Model`'s
`extend Enumerable` requires at `typed: strict`. That declaration belongs only
in an RBI. `extend T::Generic` in Ruby source puts `T::Generic#[]` ahead of
Sequel's `Model.[]` and breaks primary-key lookup at runtime.

Column types map from Sequel's `db_schema[:type]` (`integer`, `string`,
`boolean`, `float`, `decimal`, `date`, `datetime`, `time`, `blob`, `enum`).
A `uuid` column, which Sequel reports without a type, becomes a `String`, and
`datetime` follows `Sequel.datetime_class`. Anything else, such as `json`,
arrays or custom types, is `T.untyped` rather than a guess.

## Installation

```ruby
group :development, :test do
  gem 'tapioca', require: false
  gem 'tapioca-sequel', require: false
end
```

Tapioca finds the compiler in any bundled gem, so nothing needs requiring.

## Booting a non-Rails application

Loading a model issues a real schema query, so `tapioca dsl` needs your
application loaded and connected to a migrated database before it gathers
models. Tapioca only knows how to boot Rails, and `dsl` has no `--require`
flag. Load the application from a Tapioca *extension* instead. Tapioca
requires `sorbet/tapioca/extensions/*.rb` before the compilers, so every
compiler sees the loaded models, including Tapioca's own compilers, which are
guarded by checks like `defined?(Google::Protobuf)`.

```ruby
# sorbet/tapioca/extensions/load_app.rb
# typed: false
# frozen_string_literal: true

require_relative '../../../config/environment' # whatever connects Sequel and defines your models
```

Then pin Tapioca to one worker. Its parallel executor forks, and forking with a
live database connection is a footgun:

```yaml
# sorbet/tapioca/config.yml
dsl:
  workers: 1
```

## `PrivateDataset` exists only in RBIs

Like Tapioca's ActiveRecord `PrivateRelation`, `Model::PrivateDataset` is a
static-only fiction. At runtime `where` returns a plain `Sequel::Dataset`, and
no constant by that name exists. A runtime-checked `sig` that names it raises
`NameError` the first time it runs. Use `T::Sig::WithoutRuntime.sig`, which
Sorbet still checks statically:

```ruby
T::Sig::WithoutRuntime.sig { params(dataset: Models::Entity::PrivateDataset).returns(Models::Entity::PrivateDataset) }
def self.investors(dataset) = dataset.where(role: 'investor')
```

## Development

```bash
bundle install
bundle exec rake   # rspec, rubocop, srb tc
```

The specs build their models on an in-memory SQLite database and run the
compiler through Tapioca's own DSL test context, which also syntax-checks every
generated RBI with Sorbet.

## License

MIT. See [LICENSE.txt](LICENSE.txt).
