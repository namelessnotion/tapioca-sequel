# typed: strict
# frozen_string_literal: true

module TapiocaSequel
  # The finders and query methods Sequel gives a model class and its datasets,
  # typed so a chain that starts at `Model.where` keeps returning the model's
  # `PrivateDataset`, and reading from it returns the model.
  #
  # Each table below lists one generated method per line as
  # `name => [parameters, return type]`. Parameters name an entry in
  # PARAMETERS; in types, `%<model>s` and `%<dataset>s` stand for the model
  # and its `PrivateDataset`.
  class QueryMethods
    extend T::Sig
    include Tapioca::RBIHelper

    # [kind, name, type] for each parameter of a method.
    Param = T.type_alias { [Symbol, String, String] }

    PARAMETERS = T.let(
      {
        none: [],
        rest: [[:rest, 'args', 'T.untyped']],
        block: [[:block, 'block', 'T.untyped']],
        rest_block: [[:rest, 'args', 'T.untyped'], [:block, 'block', 'T.untyped']],
        pk: [[:req, 'pk', 'T.untyped']],
        # `create` is `new(values, &block).save`.
        create: [[:opt, 'values', 'T::Hash[Symbol, T.untyped]'],
                 [:block, 'block', 'T.nilable(T.proc.params(arg0: %<model>s).void)']],
        each: [[:block, 'block', 'T.proc.params(arg0: %<model>s).void']],
        map: [[:block, 'block', 'T.proc.params(arg0: %<model>s).returns(T.type_parameter(:U))']]
      }.freeze,
      T::Hash[Symbol, T::Array[Param]]
    )

    # Query methods that return a new dataset, so chaining stays typed.
    # `select` deliberately shadows `Enumerable#select` here — Sequel overrides it
    # with the SQL builder, so this matches runtime.
    #
    # `eager` lives on `Sequel::Model::Associations::DatasetMethods`, a module
    # `extend`ed onto a model's dataset instance at runtime rather than included
    # in `Sequel::Dataset` itself — the exact reason it's invisible to Sorbet
    # unless listed here explicitly.
    CHAINABLE = T.let(
      %w[where exclude filter order order_by reverse limit offset select
         select_append distinct group group_by having eager for_update].freeze,
      T::Array[String]
    )

    Methods = T.type_alias { T::Hash[String, [Symbol, String]] }

    # With the default raise_on_save_failure, `create` either returns the
    # model or raises.
    CLASS_METHODS = T.let(
      {
        '[]' => [:rest, 'T.nilable(%<model>s)'],
        'with_pk' => [:pk, 'T.nilable(%<model>s)'],
        'with_pk!' => [:pk, '%<model>s'],
        'create' => [:create, '%<model>s'],
        'first' => [:rest_block, 'T.nilable(%<model>s)'],
        'first!' => [:rest_block, '%<model>s'],
        'last' => [:rest_block, 'T.nilable(%<model>s)'],
        'all' => [:block, 'T::Array[%<model>s]'],
        'count' => [:rest_block, 'Integer'],
        'empty?' => [:none, 'T::Boolean'],
        'dataset' => [:none, '%<dataset>s']
      }.freeze,
      Methods
    )

    # `Sequel::Dataset` includes ::Enumerable without declaring `Elem`, so the
    # `Elem` fixed on PrivateDataset doesn't flow into inherited Enumerable
    # methods. `each`, `map` and `flat_map` are typed explicitly; tapioca infers
    # the `type_parameters(:U)` clause from the parameter and return types.
    DATASET_METHODS = T.let(
      {
        'first' => [:rest_block, 'T.nilable(%<model>s)'],
        'first!' => [:rest_block, '%<model>s'],
        'last' => [:rest_block, 'T.nilable(%<model>s)'],
        'single_record' => [:none, 'T.nilable(%<model>s)'],
        'with_pk' => [:pk, 'T.nilable(%<model>s)'],
        'with_pk!' => [:pk, '%<model>s'],
        'all' => [:block, 'T::Array[%<model>s]'],
        'to_a' => [:none, 'T::Array[%<model>s]'],
        'each' => [:each, '%<dataset>s'],
        'map' => [:map, 'T::Array[T.type_parameter(:U)]'],
        'flat_map' => [:map, 'T::Array[T.type_parameter(:U)]'],
        'count' => [:rest_block, 'Integer'],
        'empty?' => [:none, 'T::Boolean']
      }.freeze,
      Methods
    )

    sig { params(model: String, dataset: String).void }
    def initialize(model:, dataset:)
      @model = model
      @dataset = dataset
    end

    sig { params(mod: RBI::Scope).void }
    def add_class_methods(mod)
      add(mod, CLASS_METHODS)
    end

    sig { params(mod: RBI::Scope).void }
    def add_dataset_methods(mod)
      add(mod, DATASET_METHODS)
    end

    private

    sig { params(mod: RBI::Scope, methods: Methods).void }
    def add(mod, methods)
      methods.merge(chainables).each do |name, (shape, return_type)|
        parameters = PARAMETERS.fetch(shape).map { |kind, param, type| parameter(kind, param, expand(type)) }
        mod.create_method(name, parameters: parameters, return_type: expand(return_type))
      end
    end

    sig { returns(Methods) }
    def chainables
      CHAINABLE.to_h { |name| [name, [:rest_block, '%<dataset>s']] }
    end

    sig { params(kind: Symbol, name: String, type: String).returns(RBI::TypedParam) }
    def parameter(kind, name, type)
      case kind
      when :req then create_param(name, type: type)
      when :opt then create_opt_param(name, type: type, default: 'T.unsafe(nil)')
      when :rest then create_rest_param(name, type: type)
      when :block then create_block_param(name, type: type)
      else raise ArgumentError, "unknown parameter kind #{kind.inspect}"
      end
    end

    sig { params(type: String).returns(String) }
    def expand(type)
      format(type, model: @model, dataset: @dataset)
    end
  end
end
