# typed: strict
# frozen_string_literal: true

# `tapioca dsl` loads every compiler it finds, whether or not the application
# uses Sequel.
return unless defined?(Sequel::Model)

require_relative '../../../tapioca_sequel/association_methods'
require_relative '../../../tapioca_sequel/column_types'
require_relative '../../../tapioca_sequel/query_methods'

module Tapioca
  module Dsl
    module Compilers
      # Generates typed column accessors, association methods, finders, and a
      # typed dataset class for `Sequel::Model` subclasses.
      #
      # Also emits the `Elem` type template that `Sequel::Model`'s `extend ::Enumerable`
      # forces every subclass to re-declare at `typed: strict`. That declaration lives
      # *only* here, never in Ruby source: `extend T::Generic` in source puts
      # `T::Generic#[]` (which returns `self`) ahead of `Sequel::Model::ClassMethods#[]`
      # in the singleton ancestry, silently breaking primary-key lookup at runtime. RBI
      # files are never loaded by Ruby, so there's no runtime effect here.
      #
      # `fixed:` is load-bearing: it keeps bare `Model` legal in type position, and it
      # keeps `Model[pk]` dispatching to the real `[]` method rather than being read as
      # a generic type application.
      #
      # Same technique tapioca itself uses in `dsl/compilers/config.rb` for `Config::Options`.
      class SequelModel < Tapioca::Dsl::Compiler
        extend T::Sig

        ConstantType = type_member { { fixed: T.class_of(::Sequel::Model) } }

        class << self
          extend T::Sig

          sig { override.returns(T::Enumerable[T::Module[T.anything]]) }
          def gather_constants
            descendants_of(::Sequel::Model).select { |klass| concrete_model?(klass) }
          end

          private

          # Anonymous classes (the intermediates `Sequel::Model(:table)` creates) have no
          # name for tapioca to derive a filename from. Dataset-less classes are abstract
          # bases — `Model.dataset` raises `Sequel::Error` when unset.
          sig { params(klass: T.class_of(::Sequel::Model)).returns(T::Boolean) }
          def concrete_model?(klass)
            return false if Tapioca::Runtime::Reflection.name_of(klass).nil?

            !klass.dataset.nil?
          rescue ::Sequel::Error
            false
          end
        end

        sig { override.void }
        def decorate
          schema = T.let(constant.db_schema, T.nilable(T::Hash[Symbol, TapiocaSequel::ColumnTypes::Info]))
          return if schema.nil? || schema.empty?

          root.create_path(constant) do |klass|
            add_element_type(klass)
            add_instance_methods(klass, schema)
            add_query_methods(klass)
          end
        end

        private

        sig { returns(String) }
        def model
          "::#{name_of(constant)}"
        end

        sig { returns(String) }
        def dataset
          "#{model}::PrivateDataset"
        end

        sig { params(klass: RBI::Scope).void }
        def add_element_type(klass)
          klass.create_extend('T::Generic')
          klass.create_type_variable('Elem', type: 'type_template', fixed: model)
        end

        sig { params(klass: RBI::Scope, schema: T::Hash[Symbol, TapiocaSequel::ColumnTypes::Info]).void }
        def add_instance_methods(klass, schema)
          klass.create_module('GeneratedAttributeMethods') { |mod| add_columns(mod, schema) }
          klass.create_include('GeneratedAttributeMethods')

          associations = TapiocaSequel::AssociationMethods.new(constant)
          return unless associations.any?

          klass.create_module('GeneratedAssociationMethods') { |mod| associations.add_to(mod) }
          klass.create_include('GeneratedAssociationMethods')
        end

        sig { params(klass: RBI::Scope).void }
        def add_query_methods(klass)
          queries = TapiocaSequel::QueryMethods.new(model: model, dataset: dataset)

          klass.create_module('GeneratedClassMethods') { |mod| queries.add_class_methods(mod) }
          klass.create_extend('GeneratedClassMethods')
          klass.create_module('GeneratedDatasetMethods') { |mod| queries.add_dataset_methods(mod) }

          # Static-only fiction: no such class exists at runtime, where `where` returns a
          # plain Sequel::Dataset. Mirrors tapioca's ActiveRecord `PrivateRelation` — the
          # name signals "never reference this directly from Ruby source".
          klass.create_class('PrivateDataset', superclass_name: '::Sequel::Dataset') do |ds|
            ds.create_extend('T::Generic')
            ds.create_type_variable('Elem', type: 'type_member', fixed: model)
            ds.create_include('GeneratedDatasetMethods')
          end
        end

        sig { params(mod: RBI::Scope, schema: T::Hash[Symbol, TapiocaSequel::ColumnTypes::Info]).void }
        def add_columns(mod, schema)
          schema.each do |column, info|
            writer = TapiocaSequel::ColumnTypes.writer(info)

            mod.create_method(column.to_s, return_type: TapiocaSequel::ColumnTypes.reader(info))
            mod.create_method("#{column}=", parameters: [create_param('value', type: writer)], return_type: writer)
          end
        end
      end
    end
  end
end
