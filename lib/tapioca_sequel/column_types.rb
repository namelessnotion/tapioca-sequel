# typed: strict
# frozen_string_literal: true

module TapiocaSequel
  # The Ruby type a column's value arrives as, read from its entry in Sequel's
  # `db_schema`.
  module ColumnTypes
    extend T::Sig

    UNTYPED = 'T.untyped'

    # Sequel's `db_schema[:type]` vocabulary — see `Sequel::Database#schema_column_type`.
    # Anything absent (`:interval`, `:composite`, custom PG types) falls back to T.untyped.
    RUBY_TYPES = T.let(
      {
        integer: 'Integer',
        string: 'String',
        boolean: 'T::Boolean',
        float: 'Float',
        decimal: 'BigDecimal',
        date: 'Date',
        time: 'Time',
        blob: 'String', # Sequel::SQL::Blob subclasses String
        enum: 'String'
      }.freeze,
      T::Hash[Symbol, String]
    )

    # Database types Sequel has no `:type` for (it reports `type: nil`), keyed by
    # the column's `db_type`. The pg adapter returns a uuid as its String form.
    DB_TYPES = T.let({ 'uuid' => 'String' }.freeze, T::Hash[String, String])

    # A `db_schema` entry. Its values are whatever the adapter reports — a
    # Symbol, a String, a Boolean, a default — so there is no one type for them.
    Info = T.type_alias { T::Hash[Symbol, T.untyped] }

    # What the column's reader returns: nilable when the column allows null.
    sig { params(info: Info).returns(String) }
    def self.reader(info)
      type = base(info)
      info[:allow_null] ? nilable(type) : type
    end

    # What the column's writer takes and returns. Always nilable: Sequel sets
    # any column to nil and leaves the constraint to the database.
    sig { params(info: Info).returns(String) }
    def self.writer(info)
      nilable(base(info))
    end

    # The type of the column's values, before nullability.
    sig { params(info: Info).returns(String) }
    def self.base(info)
      # `Time` by default; `DateTime` if Sequel.datetime_class was reconfigured.
      return ::Sequel.datetime_class.name.to_s if info[:type] == :datetime

      RUBY_TYPES.fetch(info[:type]) { DB_TYPES.fetch(info[:db_type].to_s, UNTYPED) }
    end

    sig { params(type: String).returns(String) }
    def self.nilable(type)
      type == UNTYPED ? type : "T.nilable(#{type})"
    end
    private_class_method :nilable
  end
end
