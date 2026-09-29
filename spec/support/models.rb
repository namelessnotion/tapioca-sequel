# frozen_string_literal: true

module Fixtures
  class Entity < Sequel::Model
    one_to_many :accounts, class: 'Fixtures::Account'
    one_to_one :profile, class: 'Fixtures::Profile'
  end

  class Profile < Sequel::Model
    many_to_one :entity, class: 'Fixtures::Entity'
  end

  class Account < Sequel::Model
    many_to_one :entity, class: 'Fixtures::Entity'
    many_to_many :tags, class: 'Fixtures::Tag'
    one_through_one :first_tag, class: 'Fixtures::Tag', join_table: :accounts_tags

    # Read-only associations get a reader and a dataset, and nothing that
    # writes.
    many_to_one :owner, class: 'Fixtures::Entity', key: :entity_id, read_only: true
    one_to_many :siblings, class: 'Fixtures::Account', key: :entity_id, primary_key: :entity_id, read_only: true
  end

  class Tag < Sequel::Model
  end

  # A base with no dataset of its own, for models to share behaviour. Built
  # with Class.new because the `class` keyword would name it first, and Sequel
  # would then look for an `abstracts` table.
  Abstract = Class.new(Sequel::Model) do
    def describe = "#{self.class.name}(#{pk})"
  end

  # A model defined through `Sequel::Model(:table)`, whose anonymous
  # intermediate class has a dataset but no name.
  class Label < Sequel::Model(:tags)
  end
end
