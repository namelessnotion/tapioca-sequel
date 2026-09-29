# typed: strict
# frozen_string_literal: true

require_relative 'column_types'

module TapiocaSequel
  # The instance methods Sequel's association DSL defines on a model: a reader
  # and a dataset for every association, a writer for a singular one, and
  # adders and removers for a plural one.
  #
  # Only methods the model really defines are generated, so the options that
  # suppress some — `read_only: true`, `no_dataset_method: true`, a
  # one_through_one having no writer — are honoured without restating Sequel's
  # rules here.
  class AssociationMethods
    extend T::Sig
    include Tapioca::RBIHelper

    Reflection = T.type_alias { ::Sequel::Model::Associations::AssociationReflection }

    sig { params(model: T.class_of(::Sequel::Model)).void }
    def initialize(model)
      @model = model
    end

    sig { returns(T::Boolean) }
    def any?
      reflections.any?
    end

    sig { params(mod: RBI::Scope).void }
    def add_to(mod)
      reflections.each do |reflection|
        associated = associated_class(reflection)
        next if associated.nil?

        add_reader(mod, reflection, associated)
        if reflection.returns_array?
          add_plural_writers(mod, reflection, associated)
        else
          add_singular_writer(mod, reflection, associated)
        end
      end
    end

    private

    sig { returns(T::Array[Reflection]) }
    def reflections
      @model.all_association_reflections
    end

    # The associated model, or nil when there is no name to refer to it by in
    # an RBI: an anonymous class, or one that cannot be resolved at all — a
    # misconfigured association, which is the application's to report, not
    # this compiler's.
    sig { params(reflection: Reflection).returns(T.nilable(T.class_of(::Sequel::Model))) }
    def associated_class(reflection)
      associated = reflection.associated_class
      associated unless Tapioca::Runtime::Reflection.name_of(associated).nil?
    rescue NameError
      nil
    end

    # The reader takes Sequel's dynamic options (`reload: true`) and an
    # optional callback that narrows the dataset it loads from.
    sig { params(mod: RBI::Scope, reflection: Reflection, associated: T.class_of(::Sequel::Model)).void }
    def add_reader(mod, reflection, associated)
      model = name(associated)
      returns = reflection.returns_array? ? "T::Array[#{model}]" : "T.nilable(#{model})"
      callback = "T.nilable(T.proc.params(dataset: #{model}::PrivateDataset).returns(::Sequel::Dataset))"

      define(mod, reflection[:name], returns,
             create_opt_param('opts', type: 'T::Hash[Symbol, T.untyped]', default: 'T.unsafe(nil)'),
             create_block_param('block', type: callback))
      define(mod, reflection.dataset_method, "#{model}::PrivateDataset")
    end

    sig { params(mod: RBI::Scope, reflection: Reflection, associated: T.class_of(::Sequel::Model)).void }
    def add_singular_writer(mod, reflection, associated)
      type = "T.nilable(#{name(associated)})"
      define(mod, reflection.setter_method, type, create_param('value', type: type))
    end

    # Adding accepts the model, the attributes to create one from, or the
    # primary key of an existing one; removing, the model or its key. Both
    # return the object, or nil when a before hook cancels.
    sig { params(mod: RBI::Scope, reflection: Reflection, associated: T.class_of(::Sequel::Model)).void }
    def add_plural_writers(mod, reflection, associated)
      model = name(associated)
      key = primary_key_type(associated)
      returns = "T.nilable(#{model})"

      define(mod, reflection.add_method, returns,
             create_param('object', type: any_of(model, 'T::Hash[Symbol, T.untyped]', key)))
      define(mod, reflection.remove_method, returns, create_param('object', type: any_of(model, key)))
      # Returns the removed objects only when the association was loaded.
      define(mod, reflection.remove_all_method, "T.nilable(T::Array[#{model}])")
    end

    sig do
      params(mod: RBI::Scope, method: T.nilable(Symbol), return_type: String, parameters: RBI::TypedParam).void
    end
    def define(mod, method, return_type, *parameters)
      return if method.nil? || !@model.public_method_defined?(method)

      mod.create_method(method.to_s, parameters: parameters, return_type: return_type)
    end

    # The type of a model's primary key: its column's type, an Array for a
    # composite key, or nil when the model has none.
    sig { params(model: T.class_of(::Sequel::Model)).returns(T.nilable(String)) }
    def primary_key_type(model)
      key = model.primary_key
      return 'T::Array[T.untyped]' if key.is_a?(Array)

      info = model.db_schema[key] unless key.nil?
      ColumnTypes.base(info) unless info.nil?
    end

    sig { params(types: T.nilable(String)).returns(String) }
    def any_of(*types)
      present = types.compact
      return ColumnTypes::UNTYPED if present.include?(ColumnTypes::UNTYPED)

      present.one? ? present.fetch(0) : "T.any(#{present.join(', ')})"
    end

    sig { params(model: T.class_of(::Sequel::Model)).returns(String) }
    def name(model)
      "::#{Tapioca::Runtime::Reflection.name_of(model)}"
    end
  end
end
