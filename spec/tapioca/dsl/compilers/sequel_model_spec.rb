# frozen_string_literal: true

RSpec.describe Tapioca::Dsl::Compilers::SequelModel do
  describe 'which models it compiles' do
    it 'gathers every named model that has a dataset' do
      expect(gathered_constants).to include(
        'Fixtures::Account', 'Fixtures::Entity', 'Fixtures::Label', 'Fixtures::Profile', 'Fixtures::Tag'
      )
    end

    it 'skips a base class that has no dataset' do
      expect(gathered_constants).not_to include('Fixtures::Abstract')
    end

    it 'skips the anonymous class `Sequel::Model(:table)` creates' do
      expect(described_class.gather_constants.map(&:name)).not_to include(nil)
    end
  end

  describe 'the model' do
    subject(:rbi) { rbi_for('Fixtures::Entity') }

    it 'fixes the Elem type template that Enumerable demands, to the model' do
      expect(rbi).to include('Elem = type_template { { fixed: ::Fixtures::Entity } }')
    end

    it 'mixes the generated modules into the model and its class' do
      expect(rbi).to include('include GeneratedAttributeMethods', 'include GeneratedAssociationMethods',
                             'extend GeneratedClassMethods')
    end

    it 'declares a PrivateDataset class for the model’s datasets' do
      expect(rbi).to include('class PrivateDataset < ::Sequel::Dataset', 'include GeneratedDatasetMethods',
                             'Elem = type_member { { fixed: ::Fixtures::Entity } }')
    end
  end

  describe 'column readers, nilable when the column allows null' do
    it_behaves_like 'generated signatures', 'Fixtures::Entity', 'GeneratedAttributeMethods',
                    'id' => '() -> Integer',
                    'name' => '() -> String',
                    'nickname' => '() -> T.nilable(String)',
                    'active' => '() -> T.nilable(T::Boolean)',
                    'balance' => '() -> T.nilable(BigDecimal)',
                    'score' => '() -> T.nilable(Float)',
                    'born_on' => '() -> T.nilable(Date)',
                    'created_at' => '() -> Time',
                    'avatar' => '() -> T.nilable(String)',
                    # Sequel reports a uuid without a type; its db_type identifies it.
                    'holder_uuid' => '() -> String',
                    # A type with no mapping stays untyped rather than guessed.
                    'metadata' => '() -> T.untyped'

    it 'follows Sequel.datetime_class for datetime columns' do
      Sequel.datetime_class = DateTime
      expect(signatures_for('Fixtures::Entity')).to include('GeneratedAttributeMethods#created_at' => '() -> DateTime')
    ensure
      Sequel.datetime_class = Time
    end
  end

  describe 'column writers, which accept nil since a new model starts out empty' do
    it_behaves_like 'generated signatures', 'Fixtures::Entity', 'GeneratedAttributeMethods',
                    'name=' => '(value: T.nilable(String)) -> T.nilable(String)',
                    'metadata=' => '(value: T.untyped) -> T.untyped'
  end

  describe 'class methods' do
    it_behaves_like 'generated signatures', 'Fixtures::Entity', 'GeneratedClassMethods',
                    '[]' => '(args: T.untyped) -> T.nilable(::Fixtures::Entity)',
                    'with_pk' => '(pk: T.untyped) -> T.nilable(::Fixtures::Entity)',
                    'with_pk!' => '(pk: T.untyped) -> ::Fixtures::Entity',
                    'first' => '(args: T.untyped, block: T.untyped) -> T.nilable(::Fixtures::Entity)',
                    'first!' => '(args: T.untyped, block: T.untyped) -> ::Fixtures::Entity',
                    'last' => '(args: T.untyped, block: T.untyped) -> T.nilable(::Fixtures::Entity)',
                    'all' => '(block: T.untyped) -> T::Array[::Fixtures::Entity]',
                    'create' => '(values: T::Hash[Symbol, T.untyped], ' \
                                'block: T.nilable(T.proc.params(arg0: ::Fixtures::Entity).void)) -> ::Fixtures::Entity',
                    'count' => '(args: T.untyped, block: T.untyped) -> Integer',
                    'empty?' => '() -> T::Boolean',
                    'dataset' => '() -> ::Fixtures::Entity::PrivateDataset',
                    'where' => '(args: T.untyped, block: T.untyped) -> ::Fixtures::Entity::PrivateDataset',
                    'eager' => '(args: T.untyped, block: T.untyped) -> ::Fixtures::Entity::PrivateDataset',
                    'for_update' => '(args: T.untyped, block: T.untyped) -> ::Fixtures::Entity::PrivateDataset'
  end

  describe 'dataset methods, which keep a chain typed until it is read' do
    it_behaves_like 'generated signatures', 'Fixtures::Entity', 'GeneratedDatasetMethods',
                    'where' => '(args: T.untyped, block: T.untyped) -> ::Fixtures::Entity::PrivateDataset',
                    'order' => '(args: T.untyped, block: T.untyped) -> ::Fixtures::Entity::PrivateDataset',
                    'select' => '(args: T.untyped, block: T.untyped) -> ::Fixtures::Entity::PrivateDataset',
                    'first' => '(args: T.untyped, block: T.untyped) -> T.nilable(::Fixtures::Entity)',
                    'single_record' => '() -> T.nilable(::Fixtures::Entity)',
                    'with_pk!' => '(pk: T.untyped) -> ::Fixtures::Entity',
                    'all' => '(block: T.untyped) -> T::Array[::Fixtures::Entity]',
                    'to_a' => '() -> T::Array[::Fixtures::Entity]',
                    'each' => '(block: T.proc.params(arg0: ::Fixtures::Entity).void) -> ::Fixtures::Entity::PrivateDataset',
                    'map' => '(block: T.proc.params(arg0: ::Fixtures::Entity).returns(T.type_parameter(:U))) ' \
                             '-> T::Array[T.type_parameter(:U)]'
  end

  describe 'associations' do
    # An association reader takes Sequel's dynamic options (`reload: true`) and
    # an optional callback that narrows the dataset it loads from.
    def self.reader(returns, associated)
      '(opts: T::Hash[Symbol, T.untyped], ' \
        "block: T.nilable(T.proc.params(dataset: #{associated}::PrivateDataset).returns(::Sequel::Dataset))) " \
        "-> #{returns}"
    end

    describe 'many_to_one: the associated model or nil' do
      it_behaves_like 'generated signatures', 'Fixtures::Account', 'GeneratedAssociationMethods',
                      'entity' => reader('T.nilable(::Fixtures::Entity)', '::Fixtures::Entity'),
                      'entity=' => '(value: T.nilable(::Fixtures::Entity)) -> T.nilable(::Fixtures::Entity)',
                      'entity_dataset' => '() -> ::Fixtures::Entity::PrivateDataset'
    end

    describe 'one_to_one: the associated model or nil' do
      it_behaves_like 'generated signatures', 'Fixtures::Entity', 'GeneratedAssociationMethods',
                      'profile' => reader('T.nilable(::Fixtures::Profile)', '::Fixtures::Profile'),
                      'profile=' => '(value: T.nilable(::Fixtures::Profile)) -> T.nilable(::Fixtures::Profile)'
    end

    describe 'one_through_one: the associated model or nil' do
      it_behaves_like 'generated signatures', 'Fixtures::Account', 'GeneratedAssociationMethods',
                      'first_tag' => reader('T.nilable(::Fixtures::Tag)', '::Fixtures::Tag'),
                      'first_tag=' => '(value: T.nilable(::Fixtures::Tag)) -> T.nilable(::Fixtures::Tag)'
    end

    # Adding takes the model, the attributes to create one from, or an
    # existing one's primary key; removing, the model or its key. Removing all
    # returns the removed models only when the association was loaded.
    describe 'one_to_many: an array, added to and removed from by model, attributes, or primary key' do
      it_behaves_like 'generated signatures', 'Fixtures::Entity', 'GeneratedAssociationMethods',
                      'accounts' => reader('T::Array[::Fixtures::Account]', '::Fixtures::Account'),
                      'accounts_dataset' => '() -> ::Fixtures::Account::PrivateDataset',
                      'add_account' => '(object: T.any(::Fixtures::Account, T::Hash[Symbol, T.untyped], Integer)) ' \
                                       '-> T.nilable(::Fixtures::Account)',
                      'remove_account' => '(object: T.any(::Fixtures::Account, Integer)) -> T.nilable(::Fixtures::Account)',
                      'remove_all_accounts' => '() -> T.nilable(T::Array[::Fixtures::Account])'
    end

    describe 'many_to_many: an array, like one_to_many' do
      it_behaves_like 'generated signatures', 'Fixtures::Account', 'GeneratedAssociationMethods',
                      'tags' => reader('T::Array[::Fixtures::Tag]', '::Fixtures::Tag'),
                      'add_tag' => '(object: T.any(::Fixtures::Tag, T::Hash[Symbol, T.untyped], Integer)) ' \
                                   '-> T.nilable(::Fixtures::Tag)',
                      'remove_all_tags' => '() -> T.nilable(T::Array[::Fixtures::Tag])'
    end

    describe 'read_only' do
      subject(:methods) { signatures_for('Fixtures::Account').keys }

      it 'still reads' do
        expect(methods).to include('GeneratedAssociationMethods#owner', 'GeneratedAssociationMethods#siblings_dataset')
      end

      it 'generates nothing that writes' do
        expect(methods).to exclude('GeneratedAssociationMethods#owner=', 'GeneratedAssociationMethods#add_sibling',
                                   'GeneratedAssociationMethods#remove_sibling',
                                   'GeneratedAssociationMethods#remove_all_siblings')
      end
    end

    it 'generates no association module for a model without associations' do
      expect(rbi_for('Fixtures::Tag')).not_to include('GeneratedAssociationMethods')
    end
  end
end
